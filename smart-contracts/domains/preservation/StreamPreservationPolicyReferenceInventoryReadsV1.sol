// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyReferenceDefinitionsV2 as DefinitionsV2
} from "../records/StreamPreservationPolicyReferenceDefinitionsV2.sol";
import {
    StreamPreservationPolicyInventoryFamilyV2 as FamilyRead
} from "./StreamPreservationPolicyInventoryFamilyV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamPreservationPolicyReferencePublicationV1 as Publisher
} from "../../interfaces/stream/preservation/IStreamPreservationPolicyReferencePublicationV1.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as Ref
} from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as Context
} from "../../interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationPolicyReferenceDefinitionsV1 as Definitions
} from "../records/StreamPreservationPolicyReferenceDefinitionsV1.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import "./StreamRenderCriticalSourceReads.sol";

/// @notice Full original reference environment and captures, with every ordered package row.
/// @dev ZIP coverage does not prove child membership. Each declared non-OS package member has
/// its own correspondence/coverage obligation. Native OS prerequisites are explicitly declared
/// execution preconditions under this profile, not archived Windows binaries.
library StreamPreservationPolicyReferenceInventoryReadsV1 {
    function items(S.Dependencies memory d, Context.Context memory c)
        public
        view
        returns (T.Item[] memory result)
    {
        return items(d, c, Family.ORIGINAL_PROFILE);
    }

    function items(S.Dependencies memory d, Context.Context memory c, bytes32 family)
        public
        view
        returns (T.Item[] memory result)
    {
        if (!FamilyRead.valid(family)) revert T.InventorySourceChanged();
        StreamRenderCriticalSourceReads.bindings(d);
        if (
            abi.decode(
                        IO.fixedRead(
                            d.targets[6],
                            abi.encodeWithSignature(
                                "supportsInterface(bytes4)", type(Publisher).interfaceId
                            ),
                            32,
                            d.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        IO.fixedRead(
                            d.targets[6],
                            abi.encodeCall(Publisher.preservationPolicyReferenceProfile, ()),
                            32,
                            d.readGas
                        ),
                        (bytes32)
                    )
                    != (family == Family.FAMILY_PROFILE
                            ? keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V2")
                            : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V1"))
        ) revert T.InventorySourceChanged();
        bytes memory raw = IO.read(
            d.targets[6],
            abi.encodeCall(Publisher.referenceRecord, (c.referenceRender.observation.recordHash)),
            1048576,
            d.sourceGas
        );
        (Ref.Publication memory declared, Ref.Receipt memory received) =
            abi.decode(raw, (Ref.Publication, Ref.Receipt));
        IO.canonical(d.targets[6], raw, abi.encode(declared, received));
        R.Publication memory p = declared.observation;
        R.Receipt memory receipt = received.observation;
        if (
            keccak256(abi.encode(received)) != keccak256(abi.encode(c.referenceRender))
                || keccak256(abi.encode(declared.scope)) != keccak256(abi.encode(c.source.scope))
                || receipt.schemaHash
                    != (family == Family.FAMILY_PROFILE
                            ? DefinitionsV2.SCHEMA_HASH
                            : Definitions.SCHEMA_HASH)
                || receipt.profileHash
                    != (family == Family.FAMILY_PROFILE
                            ? DefinitionsV2.PROFILE_HASH
                            : Definitions.PROFILE_HASH)
                || receipt.canonicalizationHash
                    != (family == Family.FAMILY_PROFILE
                            ? DefinitionsV2.CANON_HASH
                            : Definitions.CANON_HASH) || p.collectionId != c.records.collectionId
                || p.snapshotRecordHash != c.snapshot.recordHash
                || p.snapshotRevision != c.snapshot.revision
        ) revert T.InventorySourceChanged();
        raw = IO.read(
            d.targets[6],
            abi.encodeCall(Publisher.referencePayload, (c.referenceRender.observation.recordHash)),
            524352,
            d.sourceGas
        );
        bytes memory payload = abi.decode(raw, (bytes));
        IO.canonical(d.targets[6], raw, abi.encode(payload));
        if (
            payload.length != c.referenceRender.observation.payloadBytes
                || keccak256(payload) != c.referenceRender.observation.payloadHash
        ) {
            revert T.InventorySourceChanged();
        }
        uint256 count = 3 + p.environment.packageFiles.length
            + p.environment.platformPrerequisites.length + p.captures.length * 2;
        // Each slot below receives a complete row before it is read or returned. Avoid
        // constructing default structs which those assignments would immediately replace.
        uint256 start;
        assembly ("memory-safe") { start := mload(0x40) }
        uint256 end = start + (count + 1) * 32;
        assembly ("memory-safe") {
            result := start
            mstore(result, count)
            mstore(0x40, end)
        }
        result[0] = Items.bytesItem(
            T.Kind.ORIGINAL_PAYLOAD,
            keccak256("REFERENCE_MANIFEST"),
            d.targets[6],
            receipt.recordHash,
            0,
            payload
        );
        result[0].schemaId =
        (family == Family.FAMILY_PROFILE ? DefinitionsV2.SCHEMA_ID : Definitions.SCHEMA_ID);
        result[0].canonicalizationId =
        (family == Family.FAMILY_PROFILE ? DefinitionsV2.CANON_ID : Definitions.CANON_ID);
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
        Context.Context memory c,
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
            identity.artistId != c.records.artistId || identity.contentHash == 0
                || identity.byteSize == 0 || coverage.coverageHash != coverageHash
                || coverage.objectHash != objectHash || coverage.artistId != c.records.artistId
                || coverage.contentHash != identity.contentHash
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
