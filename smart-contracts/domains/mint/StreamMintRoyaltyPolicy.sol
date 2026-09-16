// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamModuleRegistry,
    StreamModuleRecord
} from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import { IStreamRoyaltyResolver } from "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import { IStreamRoyaltySnapshot } from "../../interfaces/stream/revenue/IStreamRoyaltySnapshot.sol";
import {
    IStreamArtistSnapshotRoyaltyFacts
} from "../../interfaces/stream/artist/IStreamArtistSnapshotRoyaltyFacts.sol";
import {
    IStreamMintRoyaltyPolicy
} from "../../interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol";
import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { StreamRoyaltyPreparedProof } from "../revenue/StreamRoyaltyPreparedProof.sol";

/// @notice One fixed policy implementation shared by transcript admission and every prepared site.
library StreamMintRoyaltyPolicy {
    struct Context {
        address core;
        address registry;
    }
    event MintPhaseRoyaltyPolicyRegistered(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed configHash,
        IStreamMintRoyaltyPolicy.Policy policy
    );

    function context(address core) public view returns (Context memory) {
        return Context(
            core,
            abi.decode(
                _read(address(this), abi.encodeWithSignature("moduleRegistry()"), 32), (address)
            )
        );
    }

    function configHash(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintRoyaltyPolicy.Policy memory p
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_PHASE_ROYALTY_CONFIG_V1"),
                block.chainid,
                address(this),
                collectionId,
                phaseId,
                p.applicationConfigHash,
                p.resolver,
                p.resolverRuntimeHash,
                uint8(2),
                p.electionHash,
                p.expectedModeAssignmentHash,
                p.expectedSourceRoyaltyPolicyHash
            )
        );
    }

    function register(
        IStreamMintRoyaltyPolicy.Policy storage stored,
        Context memory x,
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintRoyaltyPolicy.Policy memory p
    ) public returns (bytes32 hash) {
        if (stored.configured) {
            revert IStreamMintRoyaltyPolicy.MintRoyaltyPolicyAlreadyConfigured(
                collectionId, phaseId
            );
        }
        if (
            !p.configured || p.applicationConfigHash == 0 || p.resolver == address(0)
                || p.resolverRuntimeHash == 0 || p.electionHash == 0
                || p.expectedModeAssignmentHash == 0 || p.expectedSourceRoyaltyPolicyHash == 0
        ) revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
        hash = configHash(collectionId, phaseId, p);
        requireCurrent(p, x, collectionId, phaseId, hash, false);
        stored.configured = p.configured;
        stored.applicationConfigHash = p.applicationConfigHash;
        stored.resolver = p.resolver;
        stored.resolverRuntimeHash = p.resolverRuntimeHash;
        stored.electionHash = p.electionHash;
        stored.expectedModeAssignmentHash = p.expectedModeAssignmentHash;
        stored.expectedSourceRoyaltyPolicyHash = p.expectedSourceRoyaltyPolicyHash;
        emit MintPhaseRoyaltyPolicyRegistered(1, collectionId, phaseId, hash, p);
    }

    function requireCurrent(
        IStreamMintRoyaltyPolicy.Policy memory p,
        Context memory x,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 actualConfigHash,
        bool singleStep
    ) public view returns (bool snapshotRequired) {
        StreamRoyaltyPreparedProof.Pointer memory pointer = abi.decode(
            _read(
                x.core,
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("ROYALTY_RESOLVER"))
                ),
                320
            ),
            (StreamRoyaltyPreparedProof.Pointer)
        );
        if (pointer.target == address(0)) {
            if (p.configured) revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
            return false;
        }
        if (pointer.target.code.length == 0 || pointer.target.codehash != pointer.runtimeHash) {
            revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
        }
        bool capable = abi.decode(
            _read(
                pointer.target,
                abi.encodeCall(
                    IERC165.supportsInterface, (type(IStreamArtistSnapshotRoyaltyFacts).interfaceId)
                ),
                32
            ),
            (bool)
        );
        if (!capable) {
            if (p.configured) revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
            return false;
        }
        (uint8 mode, bytes32 election) = abi.decode(
            _read(
                pointer.target,
                abi.encodeCall(
                    IStreamArtistSnapshotRoyaltyFacts.collectionRoyaltyMode, (collectionId)
                ),
                64
            ),
            (uint8, bytes32)
        );
        if (mode == 1) {
            if (p.configured) revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
            return false;
        }
        if (mode != 2 || election == 0) revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
        if (singleStep) {
            revert IStreamMintRoyaltyPolicy.PreparedRoyaltySnapshotRequired(collectionId);
        }
        if (
            !p.configured || p.resolver != pointer.target
                || p.resolverRuntimeHash != pointer.runtimeHash || p.electionHash != election
                || actualConfigHash != configHash(collectionId, phaseId, p)
        ) {
            revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
        }
        _activeResolver(x, pointer);
        IStreamRoyaltySnapshot.Source memory source = abi.decode(
            _read(
                pointer.target,
                abi.encodeCall(IStreamRoyaltySnapshot.currentRoyaltySnapshotSource, (collectionId)),
                352
            ),
            (IStreamRoyaltySnapshot.Source)
        );
        if (
            source.collectionId != collectionId || source.electionHash != election
                || source.modeAssignmentHash != p.expectedModeAssignmentHash
                || source.sourceRoyaltyPolicyHash != p.expectedSourceRoyaltyPolicyHash
        ) {
            revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
        }
        return true;
    }

    /// @dev Called only by fixed execution libraries in Manager context, immediately after prepare.
    function snapshot(
        Context memory x,
        uint256 collectionId,
        bytes32 phaseId,
        uint256 tokenId,
        bytes32 root,
        bytes32 operationId
    ) public {
        (IStreamMintRoyaltyPolicy.Policy memory p, bool required) =
            _current(x, collectionId, phaseId);
        if (!required) return;
        bytes32 returned = IStreamRoyaltySnapshot(p.resolver)
            .snapshotTokenRoyaltyAtMint(
                tokenId,
                collectionId,
                root,
                operationId,
                keccak256("ROYALTY_ERC2981"),
                p.expectedSourceRoyaltyPolicyHash
            );
        if (returned == 0) revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
        _snapshot(p, collectionId, tokenId, root, operationId, returned);
        _current(x, collectionId, phaseId);
    }

    /// @dev Rechecks current phase/source and retained result after callbacks; never snapshots twice.
    function completed(
        Context memory x,
        uint256 collectionId,
        bytes32 phaseId,
        uint256 tokenId,
        bytes32 root,
        bytes32 operationId
    ) public view {
        (IStreamMintRoyaltyPolicy.Policy memory p, bool required) =
            _current(x, collectionId, phaseId);
        if (required) _snapshot(p, collectionId, tokenId, root, operationId, bytes32(0));
    }

    function _current(Context memory x, uint256 collectionId, bytes32 phaseId)
        private
        view
        returns (IStreamMintRoyaltyPolicy.Policy memory p, bool required)
    {
        // Fixed self-reads preserve the single original Manager-owned policy, with no callback facts.
        p = IStreamMintRoyaltyPolicy(address(this)).phaseRoyaltyPolicy(collectionId, phaseId);
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            IStreamMintManager(address(this)).phase(collectionId, phaseId);
        if (!exists) revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
        required = requireCurrent(p, x, collectionId, phaseId, phase.configHash, false);
    }

    function _snapshot(
        IStreamMintRoyaltyPolicy.Policy memory p,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 root,
        bytes32 operationId,
        bytes32 returned
    ) private view {
        IStreamRoyaltySnapshot.Snapshot memory s = abi.decode(
            _read(
                p.resolver, abi.encodeCall(IStreamRoyaltySnapshot.royaltySnapshot, (tokenId)), 448
            ),
            (IStreamRoyaltySnapshot.Snapshot)
        );
        if (
            !s.exists || s.collectionId != collectionId || s.tokenId != tokenId
                || s.manager != address(this) || s.operationRoot != root
                || s.operationId != operationId || s.preparedProofHash == 0
                || s.electionHash != p.electionHash
                || s.modeAssignmentHash != p.expectedModeAssignmentHash
                || s.sourceRoyaltyPolicyHash != p.expectedSourceRoyaltyPolicyHash
                || s.sourceAssignmentHash == 0 || s.tokenAssignmentHash == 0
                || s.tokenRoyaltyPolicyHash == 0 || s.tokenConfigHash == 0
                || (returned != 0 && s.tokenRoyaltyPolicyHash != returned)
        ) {
            revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
        }
    }

    function _activeResolver(Context memory x, StreamRoyaltyPreparedProof.Pointer memory p)
        private
        view
    {
        if (
            p.registry != x.registry || p.status != 1
                || p.moduleType != keccak256("REVENUE_RESOLVER")
                || p.interfaceId != type(IStreamRoyaltyResolver).interfaceId
                || p.moduleManifest == 0 || p.deploymentManifest == 0 || p.revision == 0
                || !IStreamModuleRegistry(x.registry)
                    .isModuleEligible(p.target, p.moduleType, p.interfaceId)
                || !abi.decode(
                    _read(
                        p.target,
                        abi.encodeCall(
                            IERC165.supportsInterface, (type(IStreamRoyaltySnapshot).interfaceId)
                        ),
                        32
                    ),
                    (bool)
                )
        ) {
            revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
        }
        StreamModuleRecord memory record = IStreamModuleRegistry(x.registry).moduleRecord(p.target);
        if (
            uint8(record.status) != 1 || record.runtimeCodeHash != p.runtimeHash
                || record.moduleManifestHash != p.moduleManifest
                || record.deploymentManifestHash != p.deploymentManifest
                || record.moduleType != p.moduleType || record.interfaceId != p.interfaceId
        ) {
            revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
        }
    }

    function _read(address target, bytes memory data, uint256 width)
        private
        view
        returns (bytes memory raw)
    {
        raw = new bytes(width);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(raw, 32), width)
            size := returndatasize()
        }
        if (!ok || size != width) revert IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy();
    }
}
