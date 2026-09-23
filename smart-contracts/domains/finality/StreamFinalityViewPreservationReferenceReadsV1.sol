// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPreservationReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    IStreamViewPreservationReferencePublicationV1 as P
} from "../../interfaces/stream/preservation/IStreamViewPreservationReferencePublicationV1.sol";
import {
    StreamViewPreservationReferenceDefinitionsV1 as D
} from "../records/StreamViewPreservationReferenceDefinitionsV1.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains,
    StreamFinalityComponentState,
    IStreamArtworkScopedFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";

/// @notice Exact admitted VIEW preservation reference records and current terminal lock for fixed providers.
/// @dev Caller supplies its constructor-pinned dependency configuration, never a per-request host.
/// These observations do not replace the complete scoped render-critical inventory or archive.
library StreamFinalityViewPreservationReferenceReadsV1 {
    struct Dependencies {
        // Core, selected Metadata, Router, VIEW preservation snapshots, VIEW reference publisher.
        address[5] targets;
        bytes32[5] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 sourceGas;
    }
    error InvalidViewPreservationReferenceEvidence();
    error ViewPreservationReferenceDependency(address source);

    function requireBindings(Dependencies memory d) public view {
        if (d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas) {
            revert InvalidViewPreservationReferenceEvidence();
        }
        for (uint256 i; i < 5; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert ViewPreservationReferenceDependency(d.targets[i]);
            }
        }
        bytes memory raw =
            Reads.read(d.targets[4], abi.encodeCall(P.dependencies, ()), 608, d.readGas);
        T.Dependencies memory source = abi.decode(raw, (T.Dependencies));
        _canonical(d.targets[4], raw, abi.encode(source));
        if (source.chainId != d.chainId) revert InvalidViewPreservationReferenceEvidence();
        uint256[4] memory indexes = [uint256(0), 1, 4, 5];
        // Publisher runtime is already pinned above; its first four shared roles match exactly.
        for (uint256 i; i < 4; ++i) {
            if (
                source.targets[indexes[i]] != d.targets[i]
                    || source.codeHashes[indexes[i]] != d.codeHashes[i]
            ) {
                revert ViewPreservationReferenceDependency(d.targets[4]);
            }
        }
    }

    function original(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (T.Publication memory p, T.Receipt memory receipt) {
        requireBindings(d);
        bytes32 subject = _subject(d, scope);
        bytes memory raw = Reads.dynamicRead(
            d.targets[4], abi.encodeCall(P.referenceRecord, (hash)), 524960, d.sourceGas
        );
        (p, receipt) = abi.decode(raw, (T.Publication, T.Receipt));
        _canonical(d.targets[4], raw, abi.encode(p, receipt));
        R.Receipt memory r = receipt.observation;
        R.Publication memory o = p.observation;
        if (
            hash == 0 || revision == 0 || receipt.scopeSubject != subject
                || keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))
                || o.collectionId != scope.collectionId || r.collectionId != scope.collectionId
                || r.recordHash != hash || r.revision != revision || o.referenceId != r.referenceId
                || r.referenceId == 0 || o.expectedHead != r.predecessor
                || o.expectedRevision == type(uint64).max || o.expectedRevision + 1 != revision
                || o.expectedSourcesHash != r.sourcesHash || r.sourcesHash == 0
                || o.snapshotRecordHash != r.snapshotRecordHash || r.snapshotRecordHash == 0
                || o.snapshotRevision != r.snapshotRevision || r.snapshotRevision == 0
                || r.payloadHash == 0 || r.payloadBytes == 0 || r.payloadBytes > 524288
                || r.recordChainHash == 0 || r.recorder == address(0)
                || (r.authorizationClass != 3 && r.authorizationClass != 8) || r.grantRevision == 0
                || o.effectiveAt != r.effectiveAt || r.effectiveAt == 0
                || o.reasonHash != r.reasonHash || r.reasonHash == 0 || r.recordedAt == 0
                || r.effectiveAt > r.recordedAt || r.recordedAt > block.timestamp
                || r.schemaHash != D.SCHEMA_HASH || r.profileHash != D.PROFILE_HASH
                || r.canonicalizationHash != D.CANON_HASH
        ) revert InvalidViewPreservationReferenceEvidence();
        // Original producer hashes the complete receipt before assigning these two final fields.
        T.Receipt memory fields = abi.decode(abi.encode(receipt), (T.Receipt));
        fields.observation.recordHash = 0;
        fields.observation.recordChainHash = 0;
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_RECORD_V1"),
                        d.chainId,
                        d.targets[4],
                        d.targets[0],
                        d.targets[1],
                        p,
                        fields
                    )
                ) != hash
        ) {
            revert InvalidViewPreservationReferenceEvidence();
        }
    }

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (T.Receipt memory receipt) {
        (, receipt) = original(d, scope, hash, revision);
        bytes memory raw = Reads.read(
            d.targets[4],
            abi.encodeCall(P.requireCurrent, (scope, hash, revision)),
            672,
            d.sourceGas
        );
        T.Receipt memory current = abi.decode(raw, (T.Receipt));
        _canonical(d.targets[4], raw, abi.encode(current));
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(receipt))) {
            revert InvalidViewPreservationReferenceEvidence();
        }
    }

    function requireLocked(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (T.Receipt memory receipt, R.Lock memory locked) {
        receipt = requireCurrent(d, scope, hash, revision);
        bytes memory raw =
            Reads.read(d.targets[4], abi.encodeCall(P.referenceLock, (scope)), 128, d.readGas);
        locked = abi.decode(raw, (R.Lock));
        _canonical(d.targets[4], raw, abi.encode(locked));
        if (
            locked.actionId == 0 || locked.recordHash != hash || locked.revision != revision
                || locked.lockedAt < receipt.observation.recordedAt
                || locked.lockedAt > block.timestamp
        ) {
            revert InvalidViewPreservationReferenceEvidence();
        }
    }

    function component(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (StreamFinalityComponentState memory state) {
        (T.Receipt memory receipt, R.Lock memory locked) = requireLocked(d, scope, hash, revision);
        bytes memory raw = Reads.read(
            d.targets[4],
            abi.encodeCall(IStreamArtworkScopedFinalityComponent.finalityStateForScope, (scope)),
            256,
            d.sourceGas
        );
        state = abi.decode(raw, (StreamFinalityComponentState));
        _canonical(d.targets[4], raw, abi.encode(state));
        if (
            !state.frozen || state.componentType != StreamFinalityDomains.COMPONENT_REFERENCE_RENDER
                || state.component != d.targets[4] || state.codeHash != d.codeHashes[4]
                || state.interfaceId != type(IStreamArtworkScopedFinalityComponent).interfaceId
                || state.moduleVersion
                    != keccak256("STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_IMPLEMENTATION_V1")
                || state.manifestHash != D.PROFILE_HASH
                || state.dataHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_LOCKED_VIEW_PRESERVATION_REFERENCE_COMPONENT_V1"),
                            d.chainId,
                            d.targets[4],
                            d.targets[0],
                            scope,
                            receipt,
                            locked
                        )
                    )
        ) revert InvalidViewPreservationReferenceEvidence();
    }

    function _subject(Dependencies memory d, StreamFinalityScope memory scope)
        private
        pure
        returns (bytes32)
    {
        if (scope.scopeType != StreamFinalityScopeType.VIEW) {
            revert InvalidViewPreservationReferenceEvidence();
        }
        return StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
    }

    function _canonical(address source, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) {
            revert ViewPreservationReferenceDependency(source);
        }
    }
}
