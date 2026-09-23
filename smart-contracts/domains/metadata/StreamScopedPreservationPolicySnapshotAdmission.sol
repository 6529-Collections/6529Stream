// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicySnapshotFamiliesV2 as SnapshotFamilies
} from "../records/StreamPreservationPolicySnapshotFamiliesV2.sol";

import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";

import {
    IStreamCollectionMetadataV1 as Metadata
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    StreamScopedPreservationPolicySnapshotSourceReadsV1 as Sources
} from "../records/StreamScopedPreservationPolicySnapshotSourceReadsV1.sol";

import { StreamRecordFamilies as Families } from "../records/StreamRecordFamilies.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import { StreamMetadataRenderer } from "./StreamMetadataRenderer.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamScopedPreservationPolicySnapshotAdmission {
    function prepare(
        S.Dependencies storage _fixed,
        mapping(bytes32 => S.Lock) storage _locks,
        mapping(
            bytes32 => mapping(bytes32 => bytes32)
        ) storage _ids,
        mapping(bytes32 => bytes32[]) storage _history,
        address metadataHost,
        uint256 readGas,
        S.Publication memory p,
        address publisher,
        bytes32 _family
    ) public view returns (S.Receipt memory) {
        _candidate(_fixed, _locks, _ids, _history, p);
        return _receipt(_fixed, metadataHost, readGas, p, publisher, _family);
    }

    function _candidate(
        S.Dependencies storage _fixed,
        mapping(bytes32 => S.Lock) storage _locks,
        mapping(
            bytes32 => mapping(bytes32 => bytes32)
        ) storage _ids,
        mapping(bytes32 => bytes32[]) storage _history,
        S.Publication memory p
    ) private view {
        bytes32 subject = Sources.scopeSubject(_fixed, p.scope);
        if (_locks[subject].actionId != 0) revert S.ScopedPolicySnapshotLocked(subject);
        if (
            p.snapshotId == 0 || p.reasonHash == 0 || p.effectiveAt == 0
                || p.effectiveAt > block.timestamp || block.timestamp > type(uint64).max
                || p.expectedRevision == type(uint64).max || _ids[subject][p.snapshotId] != 0
        ) revert S.InvalidScopedPolicySnapshot();
        if (
            _head(_history, subject) != p.expectedHead
                || _history[subject].length != p.expectedRevision
        ) {
            revert S.ScopedPolicySnapshotLineage(p.expectedHead, _head(_history, subject));
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "snapshotManifestURI", p.manifestURI, 2048, true
        );
    }

    function _receipt(
        S.Dependencies storage _fixed,
        address metadataHost,
        uint256 readGas,
        S.Publication memory p,
        address publisher,
        bytes32 _family
    ) private view returns (S.Receipt memory r) {
        r.scopeSubject = Sources.scopeSubject(_fixed, p.scope);
        r.predecessor = p.expectedHead;
        r.revision = p.expectedRevision + 1;
        r.publisher = publisher;
        (r.authorizationClass, r.grantRevision) =
            _authority(metadataHost, readGas, p.scope.collectionId, Families.SNAPSHOT, publisher);
        (r.displayAuthorizationClass, r.displayGrantRevision) =
            _authority(metadataHost, readGas, p.scope.collectionId, Families.IDENTITY, publisher);
        bytes32[3] memory hashes = SnapshotFamilies.hashes(_family, true);
        r.schemaHash = hashes[0];
        r.profileHash = hashes[1];
        r.canonicalizationHash = hashes[2];
    }

    function _authority(
        address metadataHost,
        uint256 readGas,
        uint256 cid,
        bytes32 family,
        address actor
    ) private view returns (uint8, uint64) {
        if (actor == address(0)) revert S.ScopedPolicySnapshotAuthority(actor);
        for (uint8 i; i < 2; ++i) {
            uint8 cls = i == 0 ? 7 : 8;
            bytes memory raw = Reads.read(
                metadataHost,
                abi.encodeCall(Metadata.familyWriter, (i == 0 ? cid : 0, family, cls, actor)),
                64,
                readGas
            );
            (bool enabled, uint64 rev) = abi.decode(raw, (bool, uint64));
            if (keccak256(raw) != keccak256(abi.encode(enabled, rev))) {
                revert S.InvalidScopedPolicySnapshot();
            }
            if (enabled && rev != 0) return (cls, rev);
        }
        revert S.ScopedPolicySnapshotAuthority(actor);
    }

    function _head(mapping(bytes32 => bytes32[]) storage _history, bytes32 subject)
        private
        view
        returns (bytes32)
    {
        uint256 n = _history[subject].length;
        return n == 0 ? bytes32(0) : _history[subject][n - 1];
    }
}
