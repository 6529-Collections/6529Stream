// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/StreamFinalityReferenceTypes.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../records/StreamReferenceRenderDefinitions.sol";
import "../records/StreamReferenceModeDefinitions.sol";
import "../../interfaces/stream/preservation/IStreamReferenceModePublication.sol";
import "./StreamFinalityRouterEvidence.sol";

/// @notice Fixed current reference publication consumption with an explicit local lock gate.
/// @dev The runtime-pinned host authenticates the complete original record and current sources,
///      exact bytes and same-original-receipt liveness. This reader corroborates that receipt;
///      it does not independently reconstruct the full large Publication preimage.
library StreamFinalityReferenceReads {
    struct Dependencies {
        address core;
        address metadata;
        address referencePublisher;
        address metadataRouter;
        address snapshots;
        bytes32 coreCodeHash;
        bytes32 metadataCodeHash;
        bytes32 referenceCodeHash;
        bytes32 routerCodeHash;
        bytes32 snapshotsCodeHash;
        uint256 chainId;
        uint256 readGas;
        uint256 validationGas;
    }
    error InvalidReferenceEvidence();

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision
    ) public view returns (StreamFinalityReferenceEvidence memory e) {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.validationGas < d.readGas
                || scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0 || recordHash == 0 || revision == 0
        ) revert InvalidReferenceEvidence();
        _pin(d.core, d.coreCodeHash);
        _pin(d.metadata, d.metadataCodeHash);
        _pin(d.referencePublisher, d.referenceCodeHash);
        _pin(d.metadataRouter, d.routerCodeHash);
        _pin(d.snapshots, d.snapshotsCodeHash);
        if (
            _word(d, abi.encodeCall(IStreamReferenceRenderPublication.core, ()))
                    != bytes32(uint256(uint160(d.core)))
                || _word(d, abi.encodeCall(IStreamReferenceRenderPublication.metadataHost, ()))
                    != bytes32(uint256(uint160(d.metadata)))
                || _word(d, abi.encodeCall(IStreamReferenceRenderPublication.metadataRouter, ()))
                    != bytes32(uint256(uint160(d.metadataRouter)))
                || _word(d, abi.encodeCall(IStreamReferenceRenderPublication.snapshots, ()))
                    != bytes32(uint256(uint160(d.snapshots)))
        ) revert InvalidReferenceEvidence();
        bytes memory raw = StreamFinalityRouterEvidence.read(
            d.referencePublisher,
            abi.encodeCall(
                IStreamReferenceRenderPublication.requireCurrent,
                (scope.collectionId, recordHash, revision)
            ),
            640,
            d.validationGas
        );
        StreamReferenceRenderTypes.Receipt memory r =
            abi.decode(raw, (StreamReferenceRenderTypes.Receipt));
        if (keccak256(raw) != keccak256(abi.encode(r))) revert InvalidReferenceEvidence();
        if (
            r.recordHash != recordHash || r.collectionId != scope.collectionId
                || r.revision != revision || r.referenceId == 0 || r.recordChainHash == 0
                || r.payloadHash == 0 || r.payloadBytes == 0 || r.payloadBytes > 524288
                || r.sourcesHash == 0 || r.snapshotRecordHash == 0 || r.snapshotRevision == 0
                || r.recorder == address(0)
                || (r.authorizationClass != 3 && r.authorizationClass != 8) || r.grantRevision == 0
                || r.effectiveAt == 0 || r.recordedAt < r.effectiveAt
                || r.recordedAt > block.timestamp || r.reasonHash == 0
                || (revision == 1 ? r.predecessor != 0 : r.predecessor == 0) || !_profile(r)
        ) revert InvalidReferenceEvidence();
        if (r.profileHash == StreamReferenceModeDefinitions.PROFILE_HASH) {
            // requireCurrent above validates the full registered mode proof and original sources.
            bytes memory modeRaw = StreamFinalityRouterEvidence.read(
                d.referencePublisher,
                abi.encodeCall(IStreamReferenceModePublication.referenceMode, (recordHash)),
                64,
                d.readGas
            );
            (StreamReferenceModeTypes.Mode mode, bytes32 evidenceHash) =
                abi.decode(modeRaw, (StreamReferenceModeTypes.Mode, bytes32));
            if (
                keccak256(modeRaw) != keccak256(abi.encode(mode, evidenceHash)) || evidenceHash == 0
                    || (mode != StreamReferenceModeTypes.Mode.PERCEPTUAL_TOLERANCE
                        && mode != StreamReferenceModeTypes.Mode.CURATED_EQUIVALENCE)
            ) {
                revert InvalidReferenceEvidence();
            }
        }
        raw = StreamFinalityRouterEvidence.read(
            d.referencePublisher,
            abi.encodeCall(IStreamReferenceRenderPublication.referenceLock, (scope.collectionId)),
            128,
            d.readGas
        );
        StreamReferenceRenderTypes.Lock memory l =
            abi.decode(raw, (StreamReferenceRenderTypes.Lock));
        if (keccak256(raw) != keccak256(abi.encode(l))) revert InvalidReferenceEvidence();
        bool locked = l.actionId != 0;
        if (locked) {
            if (
                l.recordHash != recordHash || l.revision != revision || l.lockedAt < r.recordedAt
                    || l.lockedAt > block.timestamp
            ) {
                revert InvalidReferenceEvidence();
            }
        } else if (l.recordHash != 0 || l.revision != 0 || l.lockedAt != 0) {
            revert InvalidReferenceEvidence();
        }
        e = StreamFinalityReferenceEvidence(
            0,
            r.recordHash,
            r.payloadHash,
            r.sourcesHash,
            r.snapshotRecordHash,
            r.snapshotRevision,
            r.revision,
            r.payloadBytes,
            r.recorder,
            r.authorizationClass,
            r.grantRevision,
            r.recordedAt,
            r.schemaHash,
            r.profileHash,
            r.canonicalizationHash,
            locked,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_FINALITY_REFERENCE_LOCK_V1"),
                    d.chainId,
                    d.referencePublisher,
                    scope,
                    l
                )
            ),
            locked
                ? keccak256(
                    abi.encode(
                        keccak256("6529STREAM_LOCKED_REFERENCE_COMPONENT_V1"),
                        d.chainId,
                        d.referencePublisher,
                        d.core,
                        scope.collectionId,
                        r,
                        l
                    )
                )
                : bytes32(0)
        );
        e.inputHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_NATIVE_REFERENCE_INPUT_V1"),
                d.chainId,
                d.core,
                d.metadata,
                d.referencePublisher,
                d.referenceCodeHash,
                scope,
                e
            )
        );
    }

    function requireLocked(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 recordHash,
        uint64 revision
    ) public view returns (StreamFinalityReferenceEvidence memory e) {
        e = requireCurrent(d, scope, recordHash, revision);
        if (!e.locked) revert InvalidReferenceEvidence();
    }

    function _profile(StreamReferenceRenderTypes.Receipt memory r) private pure returns (bool) {
        return (r.schemaHash == StreamReferenceRenderDefinitions.SCHEMA_HASH
                && r.profileHash == StreamReferenceRenderDefinitions.PROFILE_HASH
                && r.canonicalizationHash == StreamReferenceRenderDefinitions.CANON_HASH)
            || (r.schemaHash == StreamReferenceModeDefinitions.SCHEMA_HASH
                && r.profileHash == StreamReferenceModeDefinitions.PROFILE_HASH
                && r.canonicalizationHash == StreamReferenceModeDefinitions.CANON_HASH);
    }

    function _word(Dependencies memory d, bytes memory input) private view returns (bytes32) {
        return abi.decode(
            StreamFinalityRouterEvidence.read(d.referencePublisher, input, 32, d.readGas), (bytes32)
        );
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert InvalidReferenceEvidence();
        }
    }
}
