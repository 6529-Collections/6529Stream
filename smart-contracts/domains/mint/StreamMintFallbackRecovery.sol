// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/mint/IStreamMintFallbackRecovery.sol";
import "../../interfaces/stream/mint/IStreamMintGovernanceRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import "../revenue/StreamSettlementAdmission.sol";
import {
    IStreamMintFallbackBinding
} from "../../interfaces/stream/mint/IStreamMintFallbackBinding.sol";

/// @notice Typed incident-only worker executed in the dedicated fallback Manager's context.
library StreamMintFallbackRecovery {
    bytes32 private constant SCOPE = keccak256("6529STREAM_MINT_FALLBACK_RECOVERY_SCOPE_V1");
    bytes32 private constant STATE = keccak256("6529STREAM_MINT_FALLBACK_RECOVERY_STATE_V1");

    error InvalidFallbackRecoveryBinding();
    error InvalidFallbackRecoveryContext();
    error InvalidFallbackPreparation();
    error FallbackRecoveryPostcondition();

    event MintFallbackPreparedRecovered(
        uint16 schemaVersion,
        bytes32 indexed actionId,
        uint256 indexed tokenId,
        bytes32 indexed operationId,
        uint256 collectionId
    );

    struct PreparedState {
        uint256 collectionId;
        uint256 serial;
        uint256 lastTokenId;
        uint256 nextSerial;
        uint256 mintedEver;
        uint256 supply;
        bytes32 tokenDataHash;
        address coordinator;
    }

    /// @notice Planning read may precede pointer replacement; no execution authority is granted.
    function transition(address manager, uint256 tokenId, bytes32 operationId)
        public
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        IStreamCore core = IStreamCore(IStreamMintFallbackBinding(manager).core());
        return
            _transition(core, manager, tokenId, operationId, _prepared(core, tokenId, operationId));
    }

    /// @dev The derived facade supplies its inherited nonReentrant guard. This worker only aborts.
    function recover(uint256 tokenId, bytes32 operationId) external {
        IStreamMintFallbackBinding host = IStreamMintFallbackBinding(address(this));
        IStreamCore core = IStreamCore(host.core());
        address authority = host.governanceAuthority();
        if (
            msg.sender != authority || host.owner() != authority
                || !StreamSettlementAdmission.isContract(authority)
                || !StreamSettlementAdmission.isContract(address(core))
        ) revert InvalidFallbackRecoveryBinding();
        _selected(core, keccak256("MINT_MANAGER"), address(this));
        address registry = host.moduleRegistry();
        _selected(core, keccak256("MODULE_REGISTRY"), registry);
        if (IStreamMintGovernanceRegistry(registry).governanceExecutor() != authority) {
            revert InvalidFallbackRecoveryBinding();
        }
        PreparedState memory before_ = _prepared(core, tokenId, operationId);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            _transition(core, address(this), tokenId, operationId, before_);
        bytes32 actionId = _action(authority, scope, oldHash, newHash);
        core.abortPreparedMintFromManager(tokenId, operationId);
        _after(core, tokenId, before_);
        emit MintFallbackPreparedRecovered(1, actionId, tokenId, operationId, before_.collectionId);
    }

    function _selected(IStreamCore core, bytes32 kind, address expected) private view {
        bytes memory raw =
            _read(address(core), abi.encodeCall(core.getSatellitePointer, (kind)), 320);
        (address target, bytes32 hash) = abi.decode(raw, (address, bytes32));
        if (
            !StreamSettlementAdmission.isContract(expected) || target != expected
                || hash != expected.codehash
        ) {
            revert InvalidFallbackRecoveryBinding();
        }
    }

    function _prepared(IStreamCore core, uint256 tokenId, bytes32 operationId)
        private
        view
        returns (PreparedState memory s)
    {
        StreamPreparedMintRecord memory p = core.preparedMint(tokenId);
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(tokenId);
        if (
            tokenId == 0 || operationId == 0 || !p.exists || p.operationId != operationId
                || core.pendingPreparedMintTokenId() != tokenId || !exists || burned
                || collection == 0 || collection != p.collectionId || serial == 0
        ) revert InvalidFallbackPreparation();
        s = PreparedState(
            collection,
            serial,
            core.lastAllocatedTokenId(),
            core.collectionNextSerial(collection),
            core.collectionMintedEver(collection),
            core.totalSupply(),
            keccak256(core.tokenData(tokenId)),
            core.coordinatorAtMint(tokenId)
        );
    }

    function _transition(
        IStreamCore core,
        address manager,
        uint256 tokenId,
        bytes32 operationId,
        PreparedState memory s
    ) private view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        scope = keccak256(
            abi.encode(SCOPE, block.chainid, address(core), manager, tokenId, operationId)
        );
        bytes32 retained = keccak256(
            abi.encode(
                s.collectionId, s.serial, s.lastTokenId, s.nextSerial, s.mintedEver, s.supply
            )
        );
        oldHash =
            keccak256(abi.encode(STATE, scope, true, retained, s.tokenDataHash, s.coordinator));
        newHash =
            keccak256(abi.encode(STATE, scope, false, retained, keccak256(bytes("")), address(0)));
    }

    function _action(address authority, bytes32 scope, bytes32 oldHash, bytes32 newHash)
        private
        view
        returns (bytes32 actionId)
    {
        bytes memory raw = _read(
            authority, abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()), 192
        );
        (
            bool executing,
            bytes32 id,
            uint8 actionClass,
            bytes32 actualScope,
            bytes32 old_,
            bytes32 new_
        ) = abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            !executing || id == 0 || actionClass != 3 || actualScope != scope || old_ != oldHash
                || new_ != newHash
                || keccak256(raw)
                    != keccak256(abi.encode(executing, id, actionClass, actualScope, old_, new_))
        ) revert InvalidFallbackRecoveryContext();
        return id;
    }

    function _after(IStreamCore core, uint256 tokenId, PreparedState memory s) private view {
        StreamPreparedMintRecord memory p = core.preparedMint(tokenId);
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(tokenId);
        if (
            p.exists || p.operationId != 0 || p.collectionId != 0
                || core.pendingPreparedMintTokenId() != 0 || exists || collection != 0
                || serial != 0 || burned || core.tokenData(tokenId).length != 0
                || core.coordinatorAtMint(tokenId) != address(0)
                || core.lastAllocatedTokenId() != s.lastTokenId
                || core.collectionNextSerial(s.collectionId) != s.nextSerial
                || core.collectionMintedEver(s.collectionId) != s.mintedEver
                || core.totalSupply() != s.supply
        ) revert FallbackRecoveryPostcondition();
    }

    function _read(address target, bytes memory input, uint256 expected)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(expected);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(
                150000,
                target,
                add(input, 32),
                mload(input),
                add(output, 32),
                expected
            )
            size := returndatasize()
        }
        if (!ok || size != expected) revert InvalidFallbackRecoveryBinding();
    }
}
