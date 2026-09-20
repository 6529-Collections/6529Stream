// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as SR
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamScopedPreservationPolicyReferencePublicationV1 as Reference
} from "../../interfaces/stream/preservation/IStreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    IStreamExternalArtifactCoverage
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    StreamScopedPreservationPolicyReferenceDefinitionsV1 as Definitions
} from "../records/StreamScopedPreservationPolicyReferenceDefinitionsV1.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";

/// @notice Bounded ordered traversal of every original package member and capture occurrence.
/// @dev Each call reads the actual retained original, never a caller-provided list/count/root.
/// The ZIP is one object; its complete declared children retain separate coverage obligations.
library StreamScopedPreservationPolicyReferenceInventoryReadsV1 {
    uint64 internal constant MAX_ROWS = 64;

    struct Context {
        StreamFinalityScope scope;
        bytes32 subject;
        bytes32 artistId;
        Snapshot.Receipt snapshot;
        SR.Receipt referenceRender;
    }

    function items(S.Dependencies memory d, Context memory c, uint64 start, uint64 maximum)
        public
        view
        returns (T.Item[] memory result, uint64 total)
    {
        if (maximum == 0 || maximum > MAX_ROWS) revert T.InvalidInventorySegment();
        if (
            abi.decode(
                    IO.fixedRead(
                        d.targets[6],
                        abi.encodeCall(Reference.scopedPreservationPolicyReferenceProfile, ()),
                        32,
                        d.readGas
                    ),
                    (bytes32)
                ) != keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V1")
        ) revert T.InventorySourceChanged();
        bytes memory raw = IO.read(
            d.targets[6],
            abi.encodeCall(Reference.referenceRecord, (c.referenceRender.observation.recordHash)),
            1048576,
            d.sourceGas
        );
        (SR.Publication memory scoped, SR.Receipt memory saved) =
            abi.decode(raw, (SR.Publication, SR.Receipt));
        IO.canonical(d.targets[6], raw, abi.encode(scoped, saved));
        R.Publication memory p = scoped.observation;
        R.Receipt memory receipt = saved.observation;
        if (
            keccak256(abi.encode(saved)) != keccak256(abi.encode(c.referenceRender))
                || keccak256(abi.encode(scoped.scope)) != keccak256(abi.encode(c.scope))
                || saved.scopeSubject != c.subject || p.collectionId != c.scope.collectionId
                || p.snapshotRecordHash != c.snapshot.recordHash
                || p.snapshotRevision != c.snapshot.revision
                || receipt.schemaHash != Definitions.SCHEMA_HASH
                || receipt.profileHash != Definitions.PROFILE_HASH
                || receipt.canonicalizationHash != Definitions.CANON_HASH
        ) revert T.InventorySourceChanged();
        uint256 count = 3 + p.environment.packageFiles.length
            + p.environment.platformPrerequisites.length + p.captures.length * 2;
        if (count > type(uint64).max || start >= count) revert T.InvalidInventorySegment();
        total = uint64(count);
        uint256 length = count - start;
        if (length > maximum) length = maximum;
        result = new T.Item[](length);
        for (uint256 i; i < length; ++i) {
            uint256 at = start + i;
            if (at == 0) {
                raw = IO.read(
                    d.targets[6],
                    abi.encodeCall(Reference.referencePayload, (receipt.recordHash)),
                    524352,
                    d.sourceGas
                );
                bytes memory payload = abi.decode(raw, (bytes));
                IO.canonical(d.targets[6], raw, abi.encode(payload));
                if (
                    payload.length != receipt.payloadBytes
                        || keccak256(payload) != receipt.payloadHash
                ) revert T.InventorySourceChanged();
                result[i] = Items.bytesItem(
                    T.Kind.ORIGINAL_PAYLOAD,
                    keccak256("SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST"),
                    d.targets[6],
                    receipt.recordHash,
                    0,
                    payload
                );
                result[i].schemaId = Definitions.SCHEMA_ID;
                result[i].canonicalizationId = Definitions.CANON_ID;
            } else if (at == 1) {
                result[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("REFERENCE_ENVIRONMENT_DECLARATION"),
                    d.targets[6],
                    receipt.recordHash,
                    0,
                    abi.encode(p.environment)
                );
            } else if (at == 2) {
                result[i] = _external(
                    d,
                    c,
                    0,
                    keccak256("RUNNABLE_ENGINE_TOOLCHAIN_ZIP"),
                    p.environment.objectHash,
                    p.environment.coverageHash
                );
            } else {
                uint256 cursor = at - 3;
                uint256 packageCount = p.environment.packageFiles.length;
                uint256 platformCount = p.environment.platformPrerequisites.length;
                if (cursor < packageCount) {
                    result[i] = _file(
                        d.targets[6],
                        receipt.recordHash,
                        cursor,
                        p.environment.packageFiles[cursor],
                        false
                    );
                } else if (cursor - packageCount < platformCount) {
                    result[i] = _file(
                        d.targets[6],
                        receipt.recordHash,
                        cursor - packageCount,
                        p.environment.platformPrerequisites[cursor - packageCount],
                        true
                    );
                } else {
                    cursor -= packageCount + platformCount;
                    uint256 capture = cursor / 2;
                    if (cursor % 2 == 0) {
                        result[i] = _external(
                            d,
                            c,
                            capture,
                            keccak256("REFERENCE_CAPTURE"),
                            p.captures[capture].objectHash,
                            p.captures[capture].coverageHash
                        );
                    } else {
                        result[i] = Items.bytesItem(
                            T.Kind.NATIVE_BYTES,
                            keccak256("REFERENCE_CAPTURE_DECLARATION"),
                            d.targets[6],
                            receipt.recordHash,
                            capture,
                            abi.encode(p.captures[capture])
                        );
                    }
                }
            }
        }
    }

    function _file(
        address source,
        bytes32 record,
        uint256 index,
        R.PackageFile memory file,
        bool platform
    ) private pure returns (T.Item memory row) {
        row.kind = platform ? T.Kind.NATIVE_OS_PREREQUISITE : T.Kind.EXTERNAL_REFERENCE;
        if (file.byteSize == 0) {
            if (file.sha256Digest != sha256(bytes(""))) revert T.InvalidInventoryItem();
            if (!platform) row.kind = T.Kind.EMPTY_PACKAGE_MEMBER;
        }
        row.role =
            platform ? keccak256("NATIVE_OS_PREREQUISITE") : keccak256("RUNNABLE_PACKAGE_MEMBER");
        row.source = source;
        row.sourceRecord = record;
        row.sourceIndex = index;
        row.algorithm = 2;
        row.canonicalizationId = keccak256("RAW_BYTES");
        row.digest = abi.encodePacked(file.sha256Digest);
        row.byteSize = file.byteSize;
        // This is the exact package path, not a fabricated storage-network locator.
        row.uri = file.path;
    }

    function _external(
        S.Dependencies memory d,
        Context memory c,
        uint256 index,
        bytes32 role,
        bytes32 objectHash,
        bytes32 coverageHash
    ) private view returns (T.Item memory row) {
        bytes memory raw = IO.fixedRead(
            d.targets[11],
            abi.encodeCall(IStreamExternalArtifactCoverage.objectIdentity, (objectHash)),
            320,
            d.readGas
        );
        E.ObjectIdentity memory identity = abi.decode(raw, (E.ObjectIdentity));
        IO.canonical(d.targets[11], raw, abi.encode(identity));
        raw = IO.fixedRead(
            d.targets[11],
            abi.encodeCall(IStreamExternalArtifactCoverage.coverage, (coverageHash)),
            480,
            d.readGas
        );
        E.Coverage memory coverage = abi.decode(raw, (E.Coverage));
        IO.canonical(d.targets[11], raw, abi.encode(coverage));
        if (
            identity.artistId != c.artistId || identity.contentHash == 0 || identity.byteSize == 0
                || coverage.coverageHash != coverageHash || coverage.objectHash != objectHash
                || coverage.artistId != c.artistId || coverage.contentHash != identity.contentHash
                || coverage.sha256Digest != identity.sha256Digest
                || coverage.byteSize != identity.byteSize
                || coverage.arweaveDataRoot != identity.arweaveDataRoot
        ) revert T.InvalidInventoryItem();
        row.kind = T.Kind.EXTERNAL_OBJECT;
        row.role = role;
        row.source = d.targets[6];
        row.sourceRecord = c.referenceRender.observation.recordHash;
        row.sourceIndex = index;
        row.algorithm = 1;
        row.canonicalizationId = identity.canonicalizationId;
        row.digest = abi.encodePacked(identity.contentHash);
        row.byteSize = identity.byteSize;
        row.schemaId = identity.schemaId;
        row.formatId = identity.formatId;
        row.catalogId = identity.formatCatalogId;
        row.catalogHash = identity.formatCatalogHash;
        row.objectHash = objectHash;
        row.originalCoverageHash = coverageHash;
        row.provenanceHash = keccak256(abi.encode(coverage));
    }
}
