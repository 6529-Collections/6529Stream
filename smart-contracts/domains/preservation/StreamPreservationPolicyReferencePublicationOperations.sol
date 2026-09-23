// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "./StreamPreservationPolicyReferenceFamiliesV2.sol";

import {
    StreamPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";

import {
    IStreamArtworkFinalityComponent,
    IStreamArtworkScopedFinalityComponent,
    StreamFinalityScopeType,
    StreamFinalityComponentState,
    StreamFinalityScope,
    StreamFinalityDomains
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";

import {
    IStreamCollectionMetadataV1
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

import {
    StreamPreservationPolicyReferenceSourceReadsV1 as Sources
} from "./StreamPreservationPolicyReferenceSourceReadsV1.sol";
import {
    StreamPreservationPolicyReferenceRecordsV1 as Records
} from "./StreamPreservationPolicyReferenceRecordsV1.sol";

import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import { StreamRecordFamilies } from "../records/StreamRecordFamilies.sol";
import { StreamMetadataRenderer } from "../metadata/StreamMetadataRenderer.sol";
import {
    StreamGasParameterHost,
    IStreamGovernedParameterAuthority,
    IStreamGasParameterHost
} from "../parameters/StreamGasParameterHost.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamPreservationPolicyReferencePublicationOperations {
    event PolicyReferencePublished(
        uint16 schemaVersion,
        bytes32 indexed scopeSubject,
        bytes32 indexed referenceId,
        bytes32 indexed recordHash,
        T.Receipt receipt,
        string manifestURI
    );

    struct Context {
        address core;
        address metadataHost;
        uint256 deploymentChainId;
        bytes32 _referenceFamily;
    }
    bytes32 private constant READ_GAS = keccak256("6529STREAM_GGP_POLICY_REFERENCE_READ_GAS");
    bytes32 private constant SOURCE_GAS = keccak256("6529STREAM_GGP_POLICY_REFERENCE_SOURCE_GAS");
    bytes32 private constant SNAPSHOT_GAS =
        keccak256("6529STREAM_GGP_POLICY_REFERENCE_SNAPSHOT_GAS");
    bytes32 private constant ARCHIVE_GAS = keccak256("6529STREAM_GGP_POLICY_REFERENCE_ARCHIVE_GAS");

    function previewReference(
        T.Dependencies storage _fixed,
        mapping(bytes32 => Bytes.Manifest) storage _publications,
        mapping(
            bytes32 => Bytes.Manifest
        ) storage _payloads,
        mapping(bytes32 => T.Receipt) storage _receipts,
        mapping(bytes32 => bytes32[]) storage _history,
        mapping(bytes32 => mapping(bytes32 => bool)) storage _ids,
        mapping(bytes32 => R.Lock) storage _locks,
        mapping(bytes32 => Bytes.Manifest) storage _fileInventories,
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage _gasParameters,
        Context memory context,
        T.Publication calldata p,
        address recorder
    ) public view returns (bytes32 sourceHash, bytes memory canonical) {
        bytes32 subject = _candidate(_fixed, _locks, _ids, _history, p);
        T.Receipt memory r = _receipt(_gasParameters, context, p, subject, recorder);
        return Records.prepare(
            _fileInventories,
            _dependencies(_fixed, _gasParameters),
            p,
            r,
            false,
            context._referenceFamily
        );
    }

    function publishReference(
        T.Dependencies storage _fixed,
        mapping(bytes32 => Bytes.Manifest) storage _publications,
        mapping(
            bytes32 => Bytes.Manifest
        ) storage _payloads,
        mapping(bytes32 => T.Receipt) storage _receipts,
        mapping(bytes32 => bytes32[]) storage _history,
        mapping(bytes32 => mapping(bytes32 => bool)) storage _ids,
        mapping(bytes32 => R.Lock) storage _locks,
        mapping(bytes32 => Bytes.Manifest) storage _fileInventories,
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage _gasParameters,
        Context memory context,
        T.Publication calldata p
    ) public returns (bytes32 hash) {
        bytes32 subject = _candidate(_fixed, _locks, _ids, _history, p);
        T.Receipt memory r = _receipt(_gasParameters, context, p, subject, msg.sender);
        T.Dependencies memory d = _dependencies(_fixed, _gasParameters);
        bytes memory canonical;
        (r.observation.sourcesHash, canonical) =
            Records.prepare(_fileInventories, d, p, r, false, context._referenceFamily);
        if (
            p.observation.expectedSourcesHash == 0
                || p.observation.expectedSourcesHash != r.observation.sourcesHash
        ) revert T.InvalidPolicyReference();
        r.observation.payloadHash = keccak256(canonical);
        r.observation.payloadBytes = uint32(canonical.length);
        r.observation.recordedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                F.recordDomain(context._referenceFamily, false),
                context.deploymentChainId,
                address(this),
                context.core,
                context.metadataHost,
                p,
                r
            )
        );
        r.observation.recordHash = hash;
        r.observation.recordChainHash = keccak256(
            abi.encode(
                F.chainDomain(context._referenceFamily, false),
                context.deploymentChainId,
                address(this),
                context.core,
                subject,
                p.observation.expectedHead == 0
                    ? bytes32(0)
                    : _receipts[p.observation.expectedHead].observation.recordChainHash,
                r.observation.revision,
                hash
            )
        );
        Bytes.retain(_payloads[hash], d.targets[3], canonical);
        Bytes.retain(_publications[hash], d.targets[3], abi.encode(p));
        // Retention calls only the fixed Store's immutable reads. Still recheck the grant and
        // exact scope lineage before accepting the append, retaining atomic late-failure rollback.
        (uint8 cls, uint64 rev) =
            _authority(_gasParameters, context, p.scope.collectionId, msg.sender);
        if (
            cls != r.observation.authorizationClass || rev != r.observation.grantRevision
                || _candidate(_fixed, _locks, _ids, _history, p) != subject
        ) revert T.PolicyReferenceAuthority(msg.sender);
        _receipts[hash] = r;
        _history[subject].push(hash);
        _ids[subject][p.observation.referenceId] = true;
        emit PolicyReferencePublished(
            F.isV2(context._referenceFamily) ? 2 : 1,
            subject,
            p.observation.referenceId,
            hash,
            r,
            p.observation.manifestURI
        );
    }

    function _candidate(
        T.Dependencies storage _fixed,
        mapping(bytes32 => R.Lock) storage _locks,
        mapping(bytes32 => mapping(bytes32 => bool)) storage _ids,
        mapping(bytes32 => bytes32[]) storage _history,
        T.Publication calldata p
    ) private view returns (bytes32 subject) {
        subject = _subject(_fixed, p.scope);
        R.Publication calldata o = p.observation;
        if (
            o.collectionId != p.scope.collectionId || o.referenceId == 0 || o.reasonHash == 0
                || o.effectiveAt == 0 || o.effectiveAt > block.timestamp
                || block.timestamp > type(uint64).max || o.expectedRevision == type(uint64).max
                || _ids[subject][o.referenceId]
        ) revert T.InvalidPolicyReference();
        if (
            _head(_history, subject) != o.expectedHead
                || _history[subject].length != o.expectedRevision
        ) {
            revert T.PolicyReferenceLineage(o.expectedHead, _head(_history, subject));
        }
        if (_locks[subject].actionId != 0) revert T.PolicyReferenceLocked(subject);
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "referenceManifestURI", o.manifestURI, 2048, true
        );
    }

    function _receipt(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage _gasParameters,
        Context memory context,
        T.Publication calldata p,
        bytes32 subject,
        address recorder
    ) private view returns (T.Receipt memory r) {
        r.scopeSubject = subject;
        R.Publication calldata o = p.observation;
        r.observation.collectionId = o.collectionId;
        r.observation.referenceId = o.referenceId;
        r.observation.predecessor = o.expectedHead;
        r.observation.revision = o.expectedRevision + 1;
        r.observation.snapshotRecordHash = o.snapshotRecordHash;
        r.observation.snapshotRevision = o.snapshotRevision;
        r.observation.recorder = recorder;
        (r.observation.authorizationClass, r.observation.grantRevision) =
            _authority(_gasParameters, context, o.collectionId, recorder);
        r.observation.effectiveAt = o.effectiveAt;
        r.observation.reasonHash = o.reasonHash;
        r.observation.schemaHash = F.definition(context._referenceFamily, false).schemaHash;
        r.observation.profileHash = F.definition(context._referenceFamily, false).profileHash;
        r.observation.canonicalizationHash = F.definition(context._referenceFamily, false).canonHash;
    }

    function _authority(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage _gasParameters,
        Context memory context,
        uint256 cid,
        address actor
    ) private view returns (uint8 cls, uint64 rev) {
        if (actor == address(0)) revert T.PolicyReferenceAuthority(actor);
        for (uint8 i; i < 2; ++i) {
            cls = i == 0 ? 3 : 8;
            bytes memory raw = Reads.read(
                context.metadataHost,
                abi.encodeCall(
                    IStreamCollectionMetadataV1.familyWriter,
                    (i == 0 ? cid : 0, StreamRecordFamilies.CURATOR, cls, actor)
                ),
                64,
                _cap(_gasParameters, READ_GAS)
            );
            bool enabled;
            (enabled, rev) = abi.decode(raw, (bool, uint64));
            if (keccak256(raw) != keccak256(abi.encode(enabled, rev))) {
                revert T.PolicyReferenceDependency(context.metadataHost);
            }
            if (enabled && rev != 0) return (cls, rev);
        }
        revert T.PolicyReferenceAuthority(actor);
    }

    function _dependencies(
        T.Dependencies storage _fixed,
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage _gasParameters
    ) private view returns (T.Dependencies memory d) {
        d = _fixed;
        d.readGas = _cap(_gasParameters, READ_GAS);
        d.sourceGas = _cap(_gasParameters, SOURCE_GAS);
        d.snapshotGas = _cap(_gasParameters, SNAPSHOT_GAS);
        d.archiveGas = _cap(_gasParameters, ARCHIVE_GAS);
    }

    function _head(mapping(bytes32 => bytes32[]) storage _history, bytes32 subject)
        private
        view
        returns (bytes32)
    {
        uint256 n = _history[subject].length;
        return n == 0 ? bytes32(0) : _history[subject][n - 1];
    }

    function _subject(T.Dependencies storage _fixed, StreamFinalityScope memory scope)
        private
        view
        returns (bytes32)
    {
        return Sources.subject(_fixed, scope);
    }

    function _cap(
        mapping(bytes32 => StreamGasParameterHost.GasParameterData) storage _gasParameters,
        bytes32 id
    ) private view returns (uint256) {
        StreamGasParameterHost.GasParameterData storage parameter = _gasParameters[id];
        if (parameter.revision == 0) revert IStreamGasParameterHost.GasParameterUnknown(id);
        return parameter.value;
    }
}
