// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryIO.sol";
import {
    StreamPreservationInventoryItems as Items
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import "../../../smart-contracts/interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";
import "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import "../../../smart-contracts/domains/preservation/StreamRenderCriticalSourceReads.sol";

/// @dev Literal pre-allocation-optimization items/_file/_external bodies from source5.
library PreservationReferenceInventoryOracle {
    function items(S.Dependencies memory d, S.Context memory c)
        public
        view
        returns (T.Item[] memory result)
    {
        StreamRenderCriticalSourceReads.bindings(d);
        bytes memory raw = IO.read(
            d.targets[6],
            abi.encodeCall(
                IStreamReferenceRenderPublication.referenceRecord, (c.referenceRender.recordHash)
            ),
            1048576,
            d.sourceGas
        );
        (R.Publication memory p, R.Receipt memory receipt) =
            abi.decode(raw, (R.Publication, R.Receipt));
        IO.canonical(d.targets[6], raw, abi.encode(p, receipt));
        if (
            keccak256(abi.encode(receipt)) != keccak256(abi.encode(c.referenceRender))
                || p.collectionId != c.collectionId || p.snapshotRecordHash != c.snapshot.recordHash
                || p.snapshotRevision != c.snapshot.revision
        ) revert T.InventorySourceChanged();
        raw = IO.read(
            d.targets[6],
            abi.encodeCall(
                IStreamReferenceRenderPublication.referencePayload, (c.referenceRender.recordHash)
            ),
            524352,
            d.sourceGas
        );
        bytes memory payload = abi.decode(raw, (bytes));
        IO.canonical(d.targets[6], raw, abi.encode(payload));
        if (
            payload.length != c.referenceRender.payloadBytes
                || keccak256(payload) != c.referenceRender.payloadHash
        ) {
            revert T.InventorySourceChanged();
        }
        uint256 count = 3 + p.environment.packageFiles.length
            + p.environment.platformPrerequisites.length + p.captures.length * 2;
        result = new T.Item[](count);
        result[0] = Items.bytesItem(
            T.Kind.ORIGINAL_PAYLOAD,
            keccak256("REFERENCE_MANIFEST"),
            d.targets[6],
            receipt.recordHash,
            0,
            payload
        );
        result[0].schemaId = keccak256("STREAM_NATIVE_REFERENCE_RENDER_V1");
        result[0].canonicalizationId = keccak256("RFC8785_JCS");
        result[1] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("REFERENCE_ENVIRONMENT_DECLARATION"),
            d.targets[6],
            receipt.recordHash,
            0,
            abi.encode(p.environment)
        );
        result[2] = _external(
            d,
            c,
            0,
            keccak256("RUNNABLE_ENGINE_TOOLCHAIN_ZIP"),
            p.environment.objectHash,
            p.environment.coverageHash
        );
        uint256 next = 3;
        for (uint256 i; i < p.environment.packageFiles.length; ++i) {
            result[next++] =
                _file(d.targets[6], receipt.recordHash, i, p.environment.packageFiles[i], false);
        }
        for (uint256 i; i < p.environment.platformPrerequisites.length; ++i) {
            result[next++] = _file(
                d.targets[6], receipt.recordHash, i, p.environment.platformPrerequisites[i], true
            );
        }
        for (uint256 i; i < p.captures.length; ++i) {
            result[next++] = _external(
                d,
                c,
                i,
                keccak256("REFERENCE_CAPTURE"),
                p.captures[i].objectHash,
                p.captures[i].coverageHash
            );
            result[next++] = Items.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("REFERENCE_CAPTURE_DECLARATION"),
                d.targets[6],
                receipt.recordHash,
                i,
                abi.encode(p.captures[i])
            );
        }
        if (next != count) revert T.InvalidInventoryItem();
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
        S.Context memory c,
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
        row.sourceRecord = c.referenceRender.recordHash;
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
