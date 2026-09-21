// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { FoundryAccountStateExport as Export } from "./FoundryAccountStateExport.sol";
import { FoundryAccountStateDump as Dump } from "./FoundryAccountStateDump.sol";
import {
    StreamCurrentAuthorityPreservationCallerScenario as Scenario
} from "./StreamCurrentAuthorityPreservationCallerScenario.sol";

interface PreservationCallerBootstrapVm {
    function getCode(string calldata artifactPath) external view returns (bytes memory);
    function getNonce(address account) external view returns (uint64);
    function load(address account, bytes32 slot) external view returns (bytes32);
    function dumpState(string calldata path) external;
    function readFile(string calldata path) external view returns (string memory);
    function writeFileBinary(string calldata path, bytes calldata data) external;
    function exists(string calldata path) external view returns (bool);
    function createDir(string calldata path, bool recursive) external;
}

/// @notice Source-authored local VM preparation and final account export, not an RPC deployment.
/// @dev The runner must authenticate this native source/creation/link closure and a complete fresh
/// prestate manifest before invoking this entrypoint. Supplied facts are checked against live state,
/// never installed. Recording begins before actual scenario CREATE and the genuine Safe setup.
/// The retained files are test-fixture state, not mined client receipts or an accepted Anvil alloc.
/// A completion file is only a candidate: independent successful outer execution, closure, native
/// identity, environment and later import parity remain mandatory. Files survive a later revert.
/// Use this as the outer test/entrypoint itself; an omitted intermediary test caller is not silently
/// allowed. No production callback may depend on omitted runner/default/VM infrastructure.
contract StreamCurrentAuthorityPreservationCallerBootstrap {
    PreservationCallerBootstrapVm private constant vm =
        PreservationCallerBootstrapVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant CUT_PROFILE = keccak256("6529STREAM_CALLER_BOOTSTRAP_FOUNDRY_171_V1");
    string private constant SCENARIO_ARTIFACT =
        "test/helpers/StreamCurrentAuthorityPreservationCallerScenario.sol:StreamCurrentAuthorityPreservationCallerScenario";
    string private constant OUTPUT_ROOT = "./artifacts/native-assembly/";

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

    error InvalidArtifactPrefix();
    error ExistingArtifact(string path);
    error InvalidPrestateEncoding();
    error DuplicatePrestateAccount(address account);
    error DuplicatePrestateSlot(address account, bytes32 slot);
    error PrestateAccountMismatch(address account);
    error PrestateSlotMismatch(address account, bytes32 slot);
    error ScenarioCreationFailed();
    error ScenarioPreparationFailed();
    error ScenarioNotRecorded();
    error PreparationChanged();
    error UnknownFinalAccount(address account);

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
        Scenario scenario = Scenario(payable(instance));
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
        packet.snapshot = Export.finish(accounts, slots);
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
        Export.requireDumpParity(packet.snapshot, finalDump, packet.cut.dumpOmissions);

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

    function _validatePrestate(Export.Account[] memory accounts) private view {
        for (uint256 i; i < accounts.length; ++i) {
            Export.Account memory a = accounts[i];
            for (uint256 j; j < i; ++j) {
                if (accounts[j].account == a.account) revert DuplicatePrestateAccount(a.account);
            }
            if (
                a.account.codehash != a.codeHash || keccak256(a.account.code) != keccak256(a.code)
                    || a.account.balance != a.balance || vm.getNonce(a.account) != a.nonce
            ) revert PrestateAccountMismatch(a.account);
            for (uint256 j; j < a.slots.length; ++j) {
                for (uint256 k; k < j; ++k) {
                    if (a.slots[k].slot == a.slots[j].slot) {
                        revert DuplicatePrestateSlot(a.account, a.slots[j].slot);
                    }
                }
                if (vm.load(a.account, a.slots[j].slot) != a.slots[j].value) {
                    revert PrestateSlotMismatch(a.account, a.slots[j].slot);
                }
            }
        }
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
        (ok, raw) = address(scenario).staticcall(abi.encodeCall(Scenario.preparation, ()));
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

    function _freshPaths(string memory prefix) private {
        bytes memory p = bytes(prefix);
        bytes memory root = bytes(OUTPUT_ROOT);
        if (p.length <= root.length || p.length > root.length + 128) {
            revert InvalidArtifactPrefix();
        }
        for (uint256 i; i < root.length; ++i) {
            if (p[i] != root[i]) revert InvalidArtifactPrefix();
        }
        for (uint256 i = root.length; i < p.length; ++i) {
            uint8 ch = uint8(p[i]);
            if (
                !(ch >= 48 && ch <= 57) && !(ch >= 65 && ch <= 90) && !(ch >= 97 && ch <= 122)
                    && ch != 45 && ch != 95
            ) revert InvalidArtifactPrefix();
        }
        string[8] memory suffixes = [
            ".initial-dump.json",
            ".final-dump.json",
            ".prestate.abi",
            ".snapshot.abi",
            ".preparation.abi",
            ".writer.abi",
            ".cut.abi",
            ".complete.abi"
        ];
        for (uint256 i; i < suffixes.length; ++i) {
            string memory path = string.concat(prefix, suffixes[i]);
            if (vm.exists(path)) revert ExistingArtifact(path);
        }
        vm.createDir(OUTPUT_ROOT, true);
    }
}
