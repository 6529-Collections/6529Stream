// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { FoundryAccountStateExport as Export } from "./FoundryAccountStateExport.sol";
import { FoundryAccountStateDump as Dump } from "./FoundryAccountStateDump.sol";

interface PreservationCallerBootstrapVm {
    function getCode(string calldata artifactPath) external view returns (bytes memory);
    function getNonce(address account) external view returns (uint64);
    function load(address account, bytes32 slot) external view returns (bytes32);
    function dumpState(string calldata path) external;
    function readFile(string calldata path) external view returns (string memory);
    function readFileBinary(string calldata path) external view returns (bytes memory);
    function writeFileBinary(string calldata path, bytes calldata data) external;
    function exists(string calldata path) external view returns (bool);
    function createDir(string calldata path, bool recursive) external;
}

/// @notice Shared baseline-only local VM capture; no Scenario or protocol graph preparation.
/// @dev The full Bootstrap inherits these exact bodies without an external forwarding frame.
contract StreamCurrentAuthorityPreservationCallerBaseline {
    PreservationCallerBootstrapVm internal constant vm =
        PreservationCallerBootstrapVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant BASELINE_PROFILE =
        keccak256("6529STREAM_CALLER_PRESTATE_BASELINE_FOUNDRY_171_V1");
    string private constant OUTPUT_ROOT = "./artifacts/native-assembly/";

    struct BaselineCut {
        bytes32 profile;
        address recorder;
        address caller;
        address origin;
        bytes32 recorderCodeHash;
        uint256 recorderBalance;
        uint64 recorderNonce;
        uint256 chainId;
        uint256 blockNumber;
        uint256 timestamp;
        uint256 baseFee;
        uint256 gasLimit;
        address coinbase;
        uint256 prevrandao;
        bytes32 dumpHash;
        bytes32 accountsHash;
    }

    error InvalidArtifactPrefix();
    error ExistingArtifact(string path);
    error InvalidBaselineReadAccountsEncoding();
    error InvalidBaselineReadAccount(address account);
    error BaselineReadAccountMismatch(address account);
    error DuplicatePrestateAccount(address account);
    error DuplicatePrestateSlot(address account, bytes32 slot);
    error PrestateAccountMismatch(address account);
    error PrestateSlotMismatch(address account, bytes32 slot);

    /// @notice Capture a candidate baseline from the actual VM without preparing the protocol.
    /// @dev Invoke from the same compiled outer TEST/caller/context later used for export. The dump
    /// can omit runner or otherwise undiscovered state: this only validates its included accounts
    /// against live code/hash/balance/nonce/slots. No omitted account is invented or appended.
    /// Native library deployment identity, omitted accounts, complete closure, environment and
    /// successful outer execution require independent admission before these bytes may become an
    /// admitted input. This never writes admitted-prestate.abi or the export's complete.abi marker.
    /// Baseline files survive a later revert; their distinct completion marker is not export proof.
    /// An optional <prefix>.baseline-read-accounts.abi contains canonical abi.encode(address[]) of
    /// strictly increasing nonzero accounts observed in independently authenticated prior CREATE or
    /// configuration evidence. The runner pins that input separately. Full ordinary code reads
    /// expose these existing accounts to the journal before dumping; no account or slot is installed
    /// or appended. This grants neither admission nor storage closure. Without it, capture remains
    /// unadmitted discovery and can omit untouched predeployed libraries.
    function capturePrestateFile(string memory artifactPrefix)
        public
        returns (BaselineCut memory cut)
    {
        _freshBaselinePaths(artifactPrefix);
        _observeBaselineAccounts(artifactPrefix);
        string memory path = string.concat(artifactPrefix, ".baseline-dump.json");
        vm.dumpState(path);
        string memory raw = vm.readFile(path);
        Export.Account[] memory accounts = Dump.parse(raw);
        _validatePrestate(accounts);
        bytes memory accountsABI = abi.encode(accounts);

        cut.profile = BASELINE_PROFILE;
        cut.recorder = address(this);
        cut.caller = msg.sender;
        cut.origin = tx.origin;
        cut.recorderCodeHash = address(this).codehash;
        cut.recorderBalance = address(this).balance;
        cut.recorderNonce = vm.getNonce(address(this));
        cut.chainId = block.chainid;
        cut.blockNumber = block.number;
        cut.timestamp = block.timestamp;
        cut.baseFee = block.basefee;
        cut.gasLimit = block.gaslimit;
        cut.coinbase = block.coinbase;
        cut.prevrandao = block.prevrandao;
        cut.dumpHash = keccak256(bytes(raw));
        cut.accountsHash = keccak256(accountsABI);
        bytes memory contextABI = abi.encode(cut);
        vm.writeFileBinary(string.concat(artifactPrefix, ".candidate-prestate.abi"), accountsABI);
        vm.writeFileBinary(string.concat(artifactPrefix, ".baseline-context.abi"), contextABI);
        // Last baseline write only; independent outer success and admission remain mandatory.
        vm.writeFileBinary(
            string.concat(artifactPrefix, ".baseline-complete.abi"),
            abi.encode(BASELINE_PROFILE, keccak256(contextABI))
        );
    }

    function _observeBaselineAccounts(string memory prefix) private view {
        string memory path = string.concat(prefix, ".baseline-read-accounts.abi");
        if (!vm.exists(path)) return;
        bytes memory encoded = vm.readFileBinary(path);
        address[] memory accounts = abi.decode(encoded, (address[]));
        if (keccak256(abi.encode(accounts)) != keccak256(encoded)) {
            revert InvalidBaselineReadAccountsEncoding();
        }
        address previous;
        for (uint256 i; i < accounts.length; ++i) {
            address account = accounts[i];
            if (uint160(account) <= uint160(previous)) {
                revert InvalidBaselineReadAccount(account);
            }
            previous = account;
            bytes memory code = account.code;
            bytes32 codeHash = account.codehash;
            // Existing funded or nonce-bearing code-less accounts retain keccak256(empty).
            // Absent accounts and Foundry's non-EVM VM-codehash exception cannot be admitted here.
            if (codeHash == bytes32(0) || keccak256(code) != codeHash) {
                revert BaselineReadAccountMismatch(account);
            }
        }
    }

    function _validatePrestate(Export.Account[] memory accounts) internal view {
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

    function _freshPaths(string memory prefix) internal {
        _validateArtifactPrefix(prefix);
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

    function _freshBaselinePaths(string memory prefix) private {
        // Preserve all eight export-path guards and the identical restricted prefix validation.
        _freshPaths(prefix);
        string[4] memory suffixes = [
            ".baseline-dump.json",
            ".candidate-prestate.abi",
            ".baseline-context.abi",
            ".baseline-complete.abi"
        ];
        for (uint256 i; i < suffixes.length; ++i) {
            string memory path = string.concat(prefix, suffixes[i]);
            if (vm.exists(path)) revert ExistingArtifact(path);
        }
    }

    function _validateArtifactPrefix(string memory prefix) internal pure {
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
    }
}
