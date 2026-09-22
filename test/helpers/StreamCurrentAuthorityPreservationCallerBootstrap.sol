// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    FoundryAccountStateExport as Export,
    FoundryAccountStateExportVm
} from "./FoundryAccountStateExport.sol";
import {
    FoundryAccountStatePostRecording as PostRecording
} from "./FoundryAccountStatePostRecording.sol";
import { FoundryAccountStateDump as Dump } from "./FoundryAccountStateDump.sol";
import {
    StreamCurrentAuthorityPreservationCallerBaseline
} from "./StreamCurrentAuthorityPreservationCallerBaseline.sol";
import {
    IStreamCurrentAuthorityPreservationCallerScenario as Scenario
} from "./IStreamCurrentAuthorityPreservationCallerScenario.sol";
import {
    StreamCurrentAuthorityPreservationCallerArtifacts as Artifacts
} from "./StreamCurrentAuthorityPreservationCallerArtifacts.sol";

/// @notice Source-authored local VM preparation and final account export, not an RPC deployment.
/// @dev The runner must authenticate this native source/creation/link closure and a complete fresh
/// prestate manifest before invoking this entrypoint. Supplied facts are checked against live state,
/// never installed. Recording begins before actual scenario CREATE and the genuine Safe setup.
/// The retained files are test-fixture state, not mined client receipts or an accepted Anvil alloc.
/// A completion file is only a candidate: independent successful outer execution, closure, native
/// identity, environment and later import parity remain mandatory. Files survive a later revert.
/// Use this as the outer test/entrypoint itself; an omitted intermediary test caller is not silently
/// allowed. No production callback may depend on omitted runner/default/VM infrastructure.
contract StreamCurrentAuthorityPreservationCallerBootstrap is
    StreamCurrentAuthorityPreservationCallerBaseline
{
    bytes32 private constant CUT_PROFILE = keccak256("6529STREAM_CALLER_BOOTSTRAP_FOUNDRY_171_V1");
    string private constant SCENARIO_ARTIFACT = Artifacts.SCENARIO;
    // Exact genuine Scenario preparation() selector; retain its full raw return bytes below.
    bytes4 private constant SCENARIO_PREPARATION_SELECTOR = 0xb8319ba5;

    struct WriterState {
        address writer;
        address[] owners;
        uint256 threshold;
        uint256 nonce;
    }

    struct Cut {
        bytes32 profile;
        address recorder;
        address caller;
        address origin;
        address scenario;
        uint256 chainId;
        uint256 blockNumber;
        uint256 timestamp;
        uint256 baseFee;
        uint256 gasLimit;
        address coinbase;
        uint256 prevrandao;
        bytes32 scenarioArtifact;
        bytes32 scenarioCreationHash;
        bytes32 scenarioRuntimeHash;
        bytes32 admittedPrestateHash;
        bytes32 initialDumpHash;
        bytes32 finalDumpHash;
        bytes32 snapshotHash;
        bytes32 preparationHash;
        bytes32 writerHash;
        address[] dumpOmissions;
    }

    struct Packet {
        Export.Snapshot snapshot;
        bytes preparation;
        WriterState writer;
        Cut cut;
    }

    error InvalidPrestateEncoding();
    error ScenarioCreationFailed();
    error ScenarioPreparationFailed();
    error ScenarioNotRecorded();
    error PreparationChanged();
    error UnknownFinalAccount(address account);

    // Preserve the existing host ABI for errors bubbled by the fixed post-recording library.
    error UnsupportedForkOrChain(uint256 forkId, uint256 chainId);
    error UnsupportedSelfDestruct(address account);
    error MissingDumpAccount(address account);
    error UnknownDumpAccount(address account);
    error DuplicateAccount(address account);
    error DuplicateSlot(address account, bytes32 slot);
    error MissingDumpSlot(address account, bytes32 slot);
    error UnknownDumpSlot(address account, bytes32 slot);
    error DumpAccountMismatch(address account);
    error DumpSlotMismatch(address account, bytes32 slot);
    error InvalidDumpOmission(address account);
    error CreatedAccountOmitted(address account);
    error InvalidAbsentAccount(address account);

    /// @notice Read the admitted prestate from a fixed local artifact path without a large argv.
    /// @dev Invoke internally through the opt-in outer TEST adapter with an admitted native
    /// context supplying the linked Scenario artifact and its genuinely deployed libraries.
    /// The input file is exactly <artifactPrefix>.admitted-prestate.abi. This internal call preserves
    /// this recorder and the original msg.sender; canonical/live validation and recording order
    /// are the same as exportPreparation. The external runner must require a successful outer
    /// execution result as well as authenticate the retained files; a completion file alone is not
    /// acceptance, and this local entrypoint does not broadcast or establish RPC transport.
    function exportPreparationFile(string memory artifactPrefix) public returns (Cut memory cut) {
        _validateArtifactPrefix(artifactPrefix);
        bytes memory admittedPrestateABI =
            vm.readFileBinary(string.concat(artifactPrefix, ".admitted-prestate.abi"));
        return exportPreparation(admittedPrestateABI, artifactPrefix);
    }

    /// @param admittedPrestateABI Canonical abi.encode(Export.Account[]) from the independently
    /// admitted initial-state manifest. Include native libraries and initially absent recipients.
    /// @param artifactPrefix Fresh ./artifacts/native-assembly/<letters-digits-hyphen-underscore>.
    /// No output is overwritten and no filesystem writes are treated as transaction rollback.
    function exportPreparation(bytes memory admittedPrestateABI, string memory artifactPrefix)
        public
        returns (Cut memory cut)
    {
        _freshPaths(artifactPrefix);
        Export.Account[] memory prestate = abi.decode(admittedPrestateABI, (Export.Account[]));
        if (keccak256(abi.encode(prestate)) != keccak256(admittedPrestateABI)) {
            revert InvalidPrestateEncoding();
        }
        _validatePrestate(prestate);
        // Read the same campaign's linked native artifact before beginning account discovery.
        bytes memory creation = vm.getCode(SCENARIO_ARTIFACT);
        if (creation.length == 0) revert ScenarioCreationFailed();
        Packet memory packet;
        packet.cut.scenarioArtifact = keccak256(bytes(SCENARIO_ARTIFACT));
        packet.cut.scenarioCreationHash = keccak256(creation);
        packet.cut.admittedPrestateHash = keccak256(admittedPrestateABI);

        Export.begin();
        address instance;
        assembly ("memory-safe") {
            instance := create(0, add(creation, 32), mload(creation))
        }
        if (instance == address(0) || instance.code.length == 0) revert ScenarioCreationFailed();
        Scenario scenario = Scenario(instance);
        scenario.prepare();
        if (!scenario.preparationComplete()) revert ScenarioPreparationFailed();
        packet.preparation = _preparation(scenario);
        packet.writer = _writer(scenario);
        if (
            packet.writer.writer.code.length == 0 || packet.writer.threshold == 0
                || packet.writer.threshold > packet.writer.owners.length
        ) revert ScenarioPreparationFailed();

        string memory initialPath = string.concat(artifactPrefix, ".initial-dump.json");
        vm.dumpState(initialPath);
        string memory initialRaw = vm.readFile(initialPath);
        packet.cut.initialDumpHash = keccak256(bytes(initialRaw));
        (address[] memory accounts, Export.SlotSeed[] memory slots) =
            _seeds(prestate, Dump.parse(initialRaw), instance);
        packet.snapshot = _finishSnapshot(accounts, slots);
        if (!_contains(packet.snapshot.createdAccounts, instance)) revert ScenarioNotRecorded();
        _requireClosure(packet.snapshot, prestate);
        _requireScenario(packet.snapshot, instance);

        // These repeat exact read-only calls; they do not resume any client publication stage.
        if (
            !scenario.preparationComplete()
                || keccak256(packet.preparation) != keccak256(_preparation(scenario))
                || keccak256(abi.encode(packet.writer)) != keccak256(abi.encode(_writer(scenario)))
        ) revert PreparationChanged();
        string memory finalPath = string.concat(artifactPrefix, ".final-dump.json");
        vm.dumpState(finalPath);
        string memory finalRaw = vm.readFile(finalPath);
        Export.Account[] memory finalDump = Dump.parse(finalRaw);
        packet.cut.dumpOmissions = _omissions(packet.snapshot, finalDump);
        PostRecording.requireDumpParity(packet.snapshot, finalDump, packet.cut.dumpOmissions);

        packet.cut.profile = CUT_PROFILE;
        packet.cut.recorder = address(this);
        packet.cut.caller = msg.sender;
        packet.cut.origin = tx.origin;
        packet.cut.scenario = instance;
        packet.cut.chainId = block.chainid;
        packet.cut.blockNumber = block.number;
        packet.cut.timestamp = block.timestamp;
        packet.cut.baseFee = block.basefee;
        packet.cut.gasLimit = block.gaslimit;
        packet.cut.coinbase = block.coinbase;
        packet.cut.prevrandao = block.prevrandao;
        packet.cut.scenarioRuntimeHash = instance.codehash;
        packet.cut.finalDumpHash = keccak256(bytes(finalRaw));
        bytes memory snapshotABI = abi.encode(packet.snapshot);
        bytes memory writerABI = abi.encode(packet.writer);
        packet.cut.snapshotHash = keccak256(snapshotABI);
        packet.cut.preparationHash = keccak256(packet.preparation);
        packet.cut.writerHash = keccak256(writerABI);
        bytes memory cutABI = abi.encode(packet.cut);
        vm.writeFileBinary(string.concat(artifactPrefix, ".prestate.abi"), admittedPrestateABI);
        vm.writeFileBinary(string.concat(artifactPrefix, ".snapshot.abi"), snapshotABI);
        vm.writeFileBinary(string.concat(artifactPrefix, ".preparation.abi"), packet.preparation);
        vm.writeFileBinary(string.concat(artifactPrefix, ".writer.abi"), writerABI);
        vm.writeFileBinary(string.concat(artifactPrefix, ".cut.abi"), cutABI);
        // Last write only. A separate observer must also require the outer execution to succeed.
        vm.writeFileBinary(
            string.concat(artifactPrefix, ".complete.abi"),
            abi.encode(CUT_PROFILE, keccak256(cutABI))
        );
        return packet.cut;
    }

    /// @dev Decode the typed diff and stop both recorders in the original Bootstrap frame before
    /// the fixed post-recording DELEGATECALL. Its native library prestate must be admitted too.
    function _finishSnapshot(address[] memory accounts, Export.SlotSeed[] memory slots)
        private
        returns (Export.Snapshot memory)
    {
        FoundryAccountStateExportVm.AccountAccess[] memory diff =
            FoundryAccountStateExportVm(address(vm)).stopAndReturnStateDiff();
        FoundryAccountStateExportVm(address(vm)).stopRecord();
        return PostRecording.finishCaptured(diff, accounts, slots);
    }

    function _seeds(
        Export.Account[] memory prestate,
        Export.Account[] memory initialDump,
        address scenario
    ) private view returns (address[] memory accounts, Export.SlotSeed[] memory slots) {
        (address[] memory dumpedAccounts, Export.SlotSeed[] memory dumpedSlots) =
            Dump.seeds(initialDump);
        accounts = new address[](prestate.length + dumpedAccounts.length + 5);
        uint256 count;
        uint256 slotCount = dumpedSlots.length;
        for (uint256 i; i < prestate.length; ++i) {
            accounts[count++] = prestate[i].account;
            slotCount += prestate[i].slots.length;
        }
        for (uint256 i; i < dumpedAccounts.length; ++i) {
            accounts[count++] = dumpedAccounts[i];
        }
        accounts[count++] = address(this);
        accounts[count++] = msg.sender;
        accounts[count++] = tx.origin;
        accounts[count++] = address(vm);
        accounts[count] = scenario;
        slots = new Export.SlotSeed[](slotCount);
        count = 0;
        for (uint256 i; i < prestate.length; ++i) {
            for (uint256 j; j < prestate[i].slots.length; ++j) {
                slots[count++] = Export.SlotSeed(prestate[i].account, prestate[i].slots[j].slot);
            }
        }
        for (uint256 i; i < dumpedSlots.length; ++i) {
            slots[count++] = dumpedSlots[i];
        }
    }

    function _requireClosure(Export.Snapshot memory saved, Export.Account[] memory prestate)
        private
        view
    {
        for (uint256 i; i < saved.accounts.length; ++i) {
            Export.Account memory a = saved.accounts[i];
            bool nonempty = a.code.length != 0 || a.balance != 0 || a.nonce != 0;
            for (uint256 j; j < a.slots.length; ++j) {
                nonempty = nonempty || a.slots[j].value != 0;
            }
            if (!nonempty) continue;
            if (
                !_contains(saved.createdAccounts, a.account) && !_hasAccount(prestate, a.account)
                    && a.account != address(this) && a.account != msg.sender
                    && a.account != tx.origin && a.account != address(vm)
            ) revert UnknownFinalAccount(a.account);
        }
    }

    function _requireScenario(Export.Snapshot memory saved, address scenario) private view {
        for (uint256 i; i < saved.accounts.length; ++i) {
            if (saved.accounts[i].account != scenario) continue;
            if (
                saved.accounts[i].codeHash != scenario.codehash
                    || saved.accounts[i].code.length == 0 || saved.accounts[i].nonce == 0
            ) revert ScenarioNotRecorded();
            return;
        }
        revert ScenarioNotRecorded();
    }

    function _omissions(Export.Snapshot memory saved, Export.Account[] memory finalDump)
        private
        view
        returns (address[] memory omissions)
    {
        address[3] memory allowed = [address(this), tx.origin, address(vm)];
        omissions = new address[](3);
        uint256 count;
        for (uint256 i; i < allowed.length; ++i) {
            address a = allowed[i];
            bool duplicate;
            for (uint256 j; j < i; ++j) {
                duplicate = duplicate || allowed[j] == a;
            }
            if (!duplicate && _hasAccount(saved.accounts, a) && !_hasAccount(finalDump, a)) {
                omissions[count++] = a;
            }
        }
        assembly ("memory-safe") {
            mstore(omissions, count)
        }
    }

    function _preparation(Scenario scenario) private view returns (bytes memory raw) {
        bool ok;
        (ok, raw) =
            address(scenario).staticcall(abi.encodeWithSelector(SCENARIO_PREPARATION_SELECTOR));
        if (!ok || raw.length == 0) revert ScenarioPreparationFailed();
    }

    function _writer(Scenario scenario) private view returns (WriterState memory w) {
        (w.writer, w.owners, w.threshold, w.nonce) = scenario.writerState();
    }

    function _hasAccount(Export.Account[] memory accounts, address a) private pure returns (bool) {
        for (uint256 i; i < accounts.length; ++i) {
            if (accounts[i].account == a) return true;
        }
        return false;
    }

    function _contains(address[] memory accounts, address a) private pure returns (bool) {
        for (uint256 i; i < accounts.length; ++i) {
            if (accounts[i] == a) return true;
        }
        return false;
    }
}
