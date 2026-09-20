// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintPhaseFreeze.sol";
import "../../interfaces/stream/mint/IStreamMintLedgerPhaseFreeze.sol";
import "../../interfaces/stream/mint/IStreamMintManager.sol";
import "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

interface IStreamMintPhaseFreezeBinding {
    function core() external view returns (address);
    function mintLedger() external view returns (address);
    function governanceAuthority() external view returns (address);
    function owner() external view returns (address);
}

/// @notice Fixed Manager worker for the optional, canonical Ledger-backed freeze.
/// @dev Only the host owns entrypoint guards and executor storage references.
library StreamMintPhaseFreezeControl {
    bytes32 private constant SCOPE = keccak256("6529STREAM_MINT_PHASE_FREEZE_SCOPE_V1");
    bytes32 private constant STATE = keccak256("6529STREAM_MINT_PHASE_FREEZE_STATE_V1");

    event MintPhaseFrozen(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bool frozen,
        bytes32 policyHash
    );

    function frozen(address ledger, address manager, uint256 collectionId, bytes32 phaseId)
        public
        view
        returns (bool)
    {
        bytes memory support = _read(
            ledger,
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamMintLedgerPhaseFreeze).interfaceId)
            ),
            32
        );
        uint256 supported = abi.decode(support, (uint256));
        if (supported > 1) revert IStreamMintPhaseFreeze.MintPhaseFreezeReadFailed(ledger);
        if (supported == 0) return false;
        bytes memory raw = _read(
            ledger,
            abi.encodeCall(
                IStreamMintLedgerPhaseFreeze.phaseFreeze, (manager, collectionId, phaseId)
            ),
            64
        );
        IStreamMintLedgerPhaseFreeze.PhaseFreeze memory record =
            abi.decode(raw, (IStreamMintLedgerPhaseFreeze.PhaseFreeze));
        return record.configurationHash != 0;
    }

    function transition(address manager, uint256 collectionId, bytes32 phaseId)
        public
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        IStreamMintPhaseFreezeBinding host = IStreamMintPhaseFreezeBinding(manager);
        bytes32 policyHash = IStreamMintManager(manager).phasePolicyHash(collectionId, phaseId);
        if (policyHash == 0) {
            revert IStreamMintManager.MintPhaseDoesNotExist(collectionId, phaseId);
        }
        scope = keccak256(
            abi.encode(
                SCOPE, block.chainid, host.core(), manager, host.mintLedger(), collectionId, phaseId
            )
        );
        oldHash = keccak256(abi.encode(STATE, scope, false, policyHash));
        newHash = keccak256(abi.encode(STATE, scope, true, policyHash));
    }

    /// @dev The original Manager facade checks onlyOwner, configured phase and nonReentrant.
    function freeze(uint256 collectionId, bytes32 phaseId) external {
        IStreamMintPhaseFreezeBinding host = IStreamMintPhaseFreezeBinding(address(this));
        address ledger = host.mintLedger();
        if (frozen(ledger, address(this), collectionId, phaseId)) {
            revert IStreamMintPhaseFreeze.MintPhaseAlreadyFrozen(collectionId, phaseId);
        }
        address authority = host.governanceAuthority();
        if (msg.sender != authority || host.owner() != authority || authority.code.length == 0) {
            revert IStreamMintPhaseFreeze.MintPhaseFreezeGovernanceInvalid();
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            transition(address(this), collectionId, phaseId);
        bytes memory raw = _read(
            authority, abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()), 192
        );
        (bool executing, bytes32 id, uint8 cls, bytes32 actualScope, bytes32 old_, bytes32 new_) =
            abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            !executing || id == 0 || cls != 2 || actualScope != scope || old_ != oldHash
                || new_ != newHash
                || keccak256(raw)
                    != keccak256(abi.encode(executing, id, cls, actualScope, old_, new_))
        ) {
            revert IStreamMintPhaseFreeze.MintPhaseFreezeGovernanceInvalid();
        }
        bytes32 policyHash =
            IStreamMintManager(address(this)).phasePolicyHash(collectionId, phaseId);
        IStreamMintLedgerPhaseFreeze(ledger).freezePhase(collectionId, phaseId, policyHash);
        emit MintPhaseFrozen(1, collectionId, phaseId, true, policyHash);
    }

    /// @notice First successor configuration inherits already-frozen rights before hashing/consent.
    /// @dev The Ledger independently checks immutable terms and shrinks its executor ceiling at
    /// registration. Failed configuration rolls these storage writes back with the whole call.
    function inheritExecutors(
        mapping(address => bool) storage authorized,
        address[] storage executors,
        mapping(address => uint256) storage indexPlusOne,
        address ledger,
        uint256 collectionId,
        bytes32 phaseId
    ) external {
        if (!frozen(ledger, address(this), collectionId, phaseId)) return;
        if (executors.length != 0) {
            revert IStreamMintPhaseFreeze.MintPhaseFreezeReadFailed(ledger);
        }
        bytes memory input = abi.encodeCall(
            IStreamMintLedgerPhaseFreeze.frozenPhaseExecutors,
            (address(this), collectionId, phaseId)
        );
        // Original Manager maximum: 64 addresses plus ABI offset and array length.
        bytes memory raw = new bytes(2112);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), ledger, add(input, 32), mload(input), add(raw, 32), 2112)
            size := returndatasize()
        }
        if (!ok || size < 64 || size > 2112) {
            revert IStreamMintPhaseFreeze.MintPhaseFreezeReadFailed(ledger);
        }
        assembly ("memory-safe") { mstore(raw, size) }
        uint256 offset;
        uint256 count;
        assembly ("memory-safe") {
            offset := mload(add(raw, 32))
            count := mload(add(raw, 64))
        }
        if (offset != 32 || count > 64 || size != 64 + count * 32) {
            revert IStreamMintPhaseFreeze.MintPhaseFreezeReadFailed(ledger);
        }
        address[] memory inherited = abi.decode(raw, (address[]));
        if (inherited.length > 64 || keccak256(raw) != keccak256(abi.encode(inherited))) {
            revert IStreamMintPhaseFreeze.MintPhaseFreezeReadFailed(ledger);
        }
        for (uint256 i; i < inherited.length; ++i) {
            address executor = inherited[i];
            if (executor == address(0) || authorized[executor]) {
                revert IStreamMintPhaseFreeze.MintPhaseFreezeReadFailed(ledger);
            }
            authorized[executor] = true;
            executors.push(executor);
            indexPlusOne[executor] = i + 1;
        }
    }

    function _read(address target, bytes memory input, uint256 expected)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(expected);
        bool ok;
        uint256 size;
        // Targets are immutable Ledger/authority bindings, with fixed-size return copying.
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(input, 32), mload(input), add(output, 32), expected)
            size := returndatasize()
        }
        if (!ok || size != expected) {
            revert IStreamMintPhaseFreeze.MintPhaseFreezeReadFailed(target);
        }
    }
}
