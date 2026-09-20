// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPolicyBundleFixture
} from "./StreamCurrentAuthorityScopedPolicyBundleFixture.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2 as BytesInventory
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as BytesScoped
} from "../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamRenderCriticalSourceTypes as BytesDependencies
} from "../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as BytesItems
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationInventoryChains as BytesChains
} from "../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamPreservationInventoryItems as BytesRows
} from "../../smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol";
import {
    StreamScopedPolicyRenderCriticalNativeReadsV2 as BytesNative
} from "../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalNativeReadsV2.sol";
import {
    StreamMultiOriginNativeRoles as BytesRoles
} from "../../smart-contracts/domains/preservation/StreamMultiOriginNativeRoles.sol";
import {
    StreamScopedPolicyReferenceInventoryReadsV2 as BytesReferences
} from "../../smart-contracts/domains/preservation/StreamScopedPolicyReferenceInventoryReadsV2.sol";
import {
    StreamPreservationOriginalReads as BytesOriginals
} from "../../smart-contracts/domains/preservation/StreamPreservationOriginalReads.sol";
import {
    StreamPreservationTypedReferences as BytesTyped
} from "../../smart-contracts/domains/preservation/StreamPreservationTypedReferences.sol";
import {
    StreamPreservationDocumentReads as BytesDocuments
} from "../../smart-contracts/domains/preservation/StreamPreservationDocumentReads.sol";
import {
    StreamScopedPolicyRenderCriticalDefinitionsV2 as BytesDefinitions
} from "../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalDefinitionsV2.sol";
import {
    StreamScopedPolicyRenderCriticalTokenReadsV2 as BytesTokens
} from "../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalTokenReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalScriptReadsV2 as BytesScripts
} from "../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalScriptReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalRendererReadsV2 as BytesRenderers
} from "../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalRendererReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalCitationReadsV2 as BytesCitations
} from "../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalCitationReadsV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as BytesSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as BytesSnapshots
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as BytesReference
} from "../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    IStreamScopedPolicyReferencePublicationV2 as BytesReferenceHost
} from "../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import {
    StreamArtistArchiveOriginTypes as BytesOrigins
} from "../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as BytesHydration
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamFinalityScopeMembership as BytesMembership
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    IStreamCoreIdentity as BytesCore
} from "../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamStaticMetadataRouter as BytesRouter
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as BytesRenderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as BytesRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamStaticMetadataSource as BytesScriptHost
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataSource.sol";
import {
    IStreamScriptBundles as BytesBundles
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    IStreamSchemaRegistry as BytesSchemas
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamCollectionMetadataV1 as BytesMetadata
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    StreamConservationRecordTypes as BytesConservation
} from "../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";

/// @notice Reads the complete original byte sources needed by the actual scoped bundle.
/// @dev Bounded to this recipe's one/two-token full-Intent/PRESENT-Interview flow. Original
/// occurrence hashes are regenerated with the production readers and captured current Artist
/// dependencies before source dispatch. Documentary bytes were retained before op24 signing;
/// no URI fetch, native capture fixture or digest-only replacement pool is used. Source and
/// runtime costs are unmeasured; all original currentness/canonicalization guards remain active.
abstract contract StreamCurrentAuthorityScopedPolicyBytesFixture is
    StreamCurrentAuthorityScopedPolicyBundleFixture
{
    struct ScopedBytesFrame {
        BytesInventory inventory;
        bytes32 id;
        BytesDependencies.Dependencies dependencies;
        BytesScoped.Context context;
        BytesSnapshot.Dependencies snapshotDependencies;
        BytesReference.Publication referencePublication;
        BytesReference.SourceFacts referenceSource;
        bytes32[] expected;
        uint256 expectedCount;
    }

    function _authorityCollectScopedSourceBytes(
        AuthorityScopedPublication memory publication,
        AuthorityScopedReference memory referenceResult,
        AuthorityScopedInventory memory inventoryResult,
        ScopedRecordSet memory records,
        AuthorityScopedRights memory rightsResult
    ) internal view returns (bytes[] memory result) {
        ScopedBytesFrame memory f = _scopedBytesFrame(publication, referenceResult, inventoryResult);
        _scopedBytesSegments(f, inventoryResult);
        _scopedBytesExpected(f, publication, records, rightsResult);
        bool[] memory consumed = new bool[](f.expectedCount);
        result = new bytes[](f.expectedCount);
        uint256 count;
        uint256 occurrences;
        uint256 archiveOccurrences;
        for (uint256 i; i < inventoryResult.rows.length; ++i) {
            for (uint256 j; j < inventoryResult.rows[i].length; ++j) {
                BytesItems.Item memory item = inventoryResult.rows[i][j];
                if (item.kind == BytesItems.Kind.STATE_BUNDLE) {
                    uint256 bit = _scopedBytesArchiveOccurrence(f, item, publication, records);
                    require(
                        (archiveOccurrences & bit) == 0, "no duplicate authorization occurrence"
                    );
                    archiveOccurrences |= bit;
                    continue;
                }
                bytes32 itemHash = BytesChains.itemHash(item);
                bool found;
                for (uint256 k; k < f.expectedCount; ++k) {
                    if (!consumed[k] && f.expected[k] == itemHash) {
                        consumed[k] = true;
                        found = true;
                        break;
                    }
                }
                require(found, "exact actual source/record/index/canon/schema occurrence");
                ++occurrences;
                // Applicability, independently covered objects and package members were also
                // matched to their real source. Only the byte-consuming subset enters the pool.
                if (!_scopedBytesNeeded(item)) continue;
                // Every occurrence reads its real original before any byte deduplication.
                bytes memory raw = _scopedSourceBytes(f, item, records);
                require(
                    raw.length != 0 && item.digest.length == 32
                        && (item.algorithm == 1 || item.algorithm == 2)
                        && (item.byteSize == 0 || item.byteSize == raw.length)
                        && keccak256(item.digest)
                            == keccak256(
                                abi.encodePacked(item.algorithm == 1 ? keccak256(raw) : sha256(raw))
                            ),
                    "actual complete bytes match original item without reinterpretation"
                );
                bool duplicate;
                for (uint256 k; k < count; ++k) {
                    if (keccak256(result[k]) == keccak256(raw)) {
                        require(result[k].length == raw.length);
                        duplicate = true;
                        break;
                    }
                }
                if (!duplicate) result[count++] = raw;
            }
        }
        require(
            occurrences == f.expectedCount && archiveOccurrences == 15
                && occurrences + 4 == inventoryResult.evidence.inventory.itemCount,
            "no missing or extra source occurrence"
        );
        for (uint256 i; i < consumed.length; ++i) {
            require(consumed[i]);
        }
        assembly ("memory-safe") { mstore(result, count) }
        require(
            keccak256(abi.encode(f.inventory.requireCurrent(publication.scope)))
                == keccak256(abi.encode(inventoryResult.evidence)),
            "source collection preserves current complete evidence"
        );
    }

    function _scopedBytesFrame(
        AuthorityScopedPublication memory publication,
        AuthorityScopedReference memory referenceResult,
        AuthorityScopedInventory memory inventoryResult
    ) private view returns (ScopedBytesFrame memory f) {
        f.inventory = BytesInventory(publication.graph.children[5]);
        f.id = inventoryResult.planId;
        require(
            publication.graph.preparedChildren == 7 && address(f.inventory) == inventoryResult.host
                && referenceResult.host == publication.graph.children[4] && f.id != 0
                && f.id == inventoryResult.evidence.inventory.planId
                && keccak256(abi.encode(f.inventory.requireCurrent(publication.scope)))
                    == keccak256(abi.encode(inventoryResult.evidence))
                && keccak256(abi.encode(f.inventory.authoritySelection(f.id)))
                    == inventoryResult.authorityCaptureHash,
            "actual sealed inventory and captured current authority"
        );
        for (uint256 i; i < 7; ++i) {
            require(
                publication.graph.children[i].codehash == publication.graph.codeHashes[i]
                    && publication.graph.children[i].code.length != 0
            );
        }
        f.inventory.requireFullDefinitionBytes(f.id);
        f.dependencies = f.inventory.authoritySelection(f.id).dependencies;
        f.context = f.inventory.sourceContext(f.id);
        require(
            f.context.tokenCount != 0 && f.context.tokenCount <= 2
                && keccak256(abi.encode(f.context.scope))
                    == keccak256(abi.encode(publication.scope))
                && f.context.snapshot.recordHash == publication.snapshot.recordHash
                && f.context.referenceRender.observation.recordHash == referenceResult.recordHash
                && f.context.rootRecordHash == publication.rootHash
                && f.dependencies.targets[5] == publication.graph.children[3]
                && f.dependencies.targets[6] == referenceResult.host,
            "one/two-token actual scoped publication coordinates"
        );
        f.snapshotDependencies = BytesSnapshots(f.dependencies.targets[5]).dependencies();
        BytesReference.Receipt memory receipt;
        (f.referencePublication, receipt) = BytesReferenceHost(f.dependencies.targets[6])
            .referenceRecord(referenceResult.recordHash);
        f.referenceSource = BytesReferenceHost(f.dependencies.targets[6])
            .referenceSource(referenceResult.recordHash);
        require(
            keccak256(abi.encode(receipt)) == keccak256(abi.encode(f.context.referenceRender))
                && keccak256(abi.encode(f.referencePublication))
                    == keccak256(abi.encode(referenceResult.publication))
                && keccak256(abi.encode(f.referenceSource.snapshotSource)) == f.context.nativeHash
                && keccak256(abi.encode(f.referenceSource.snapshotSource))
                    == keccak256(abi.encode(f.context.snapshotSource)),
            "read retained reference source before deriving byte candidates"
        );
        f.expected = new bytes32[](inventoryResult.evidence.inventory.itemCount);
    }

    function _scopedBytesSegments(ScopedBytesFrame memory f, AuthorityScopedInventory memory saved)
        private
        view
    {
        require(saved.rows.length == saved.evidence.inventory.segmentCount);
        uint256 total;
        bytes32 chain;
        for (uint64 i; i < saved.rows.length; ++i) {
            BytesItems.Segment memory segment = f.inventory.inventorySegment(f.id, i);
            require(saved.rows[i].length == segment.itemCount);
            bytes32 link;
            for (uint256 j = saved.rows[i].length; j != 0; --j) {
                link = BytesChains.link(
                    segment.key, segment.itemCount, uint64(j - 1), saved.rows[i][j - 1], link
                );
            }
            require(
                link == segment.firstLink,
                "ordered source items match stored segment before dispatch"
            );
            chain = BytesChains.append(chain, i, segment);
            total += saved.rows[i].length;
        }
        require(
            chain == saved.evidence.inventory.segmentChainHash
                && total == saved.evidence.inventory.itemCount
        );
    }

    function _scopedBytesNeeded(BytesItems.Item memory item) private pure returns (bool) {
        if (item.role == keccak256("RUNNABLE_PACKAGE_MEMBER")) {
            require(
                item.kind == BytesItems.Kind.EXTERNAL_REFERENCE
                    || item.kind == BytesItems.Kind.EMPTY_PACKAGE_MEMBER
            );
            return false;
        }
        if (
            item.kind == BytesItems.Kind.STATE_BUNDLE
                || item.kind == BytesItems.Kind.EXTERNAL_OBJECT
                || item.kind == BytesItems.Kind.ONCHAIN_OBJECT
                || item.kind == BytesItems.Kind.ABSENT || item.kind == BytesItems.Kind.EMPTY_BYTES
                || item.kind == BytesItems.Kind.NATIVE_OS_PREREQUISITE
        ) return false;
        require(
            item.kind == BytesItems.Kind.NATIVE_BYTES
                || item.kind == BytesItems.Kind.ORIGINAL_PAYLOAD
                || item.kind == BytesItems.Kind.REGISTERED_DOCUMENT
                || item.kind == BytesItems.Kind.CONTRACT_RUNTIME
                || item.kind == BytesItems.Kind.EXTERNAL_REFERENCE,
            "unsupported source byte kind"
        );
        return true;
    }

    function _scopedBytesRemember(ScopedBytesFrame memory f, BytesItems.Item memory item)
        private
        pure
    {
        require(f.expectedCount < f.expected.length);
        f.expected[f.expectedCount++] = BytesChains.itemHash(item);
    }

    function _scopedBytesArchiveOccurrence(
        ScopedBytesFrame memory f,
        BytesItems.Item memory item,
        AuthorityScopedPublication memory publication,
        ScopedRecordSet memory records
    ) private view returns (uint256) {
        BytesOrigins.RecordOrigin memory original =
            f.inventory.artistArchiveOrigin(f.id, BytesChains.itemHash(item));
        require(
            original.sourceContextHash
                    == f.inventory.inventoryEvidence(f.id).inventory.sourceContextHash
                && original.role == item.role && original.actor != address(0)
                && original.semanticRecordHash != 0 && item.provenanceHash != 0
                && item.source == original.producer.environment.archive
                && item.sourceRecord == BytesOrigins.evidenceId(original) && item.sourceIndex == 1
                && original.occurrence.position.point.environmentHash
                    == BytesHydration.originHash(original.producer.environment),
            "authenticated original Archive occurrence remains a separate coverage path"
        );
        bytes32 receipt = original.occurrence.receipt.recordHash;
        if (item.role == keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_AUTHORIZATION_V2")) {
            require(
                original.occurrence.receipt.operation == 17 && receipt == publication.consentRecord
            );
            return 8;
        }
        require(
            item.role == keccak256("ORIGINAL_ARTIST_PUBLICATION_AUTHORIZATION")
                && original.occurrence.receipt.operation == 24
        );
        if (receipt == records.workPublication.authorizationHash) return 1;
        if (receipt == records.intentPublication.authorizationHash) return 2;
        require(
            receipt == records.interviewPublication.authorizationHash, "known exact op24 occurrence"
        );
        return 4;
    }

    function _scopedBytesRememberAll(ScopedBytesFrame memory f, BytesItems.Item[] memory rows)
        private
        pure
    {
        for (uint256 i; i < rows.length; ++i) {
            _scopedBytesRemember(f, rows[i]);
        }
    }

    function _scopedBytesExpected(
        ScopedBytesFrame memory f,
        AuthorityScopedPublication memory publication,
        ScopedRecordSet memory records,
        AuthorityScopedRights memory rightsResult
    ) private view {
        (BytesItems.Item[] memory rows, uint64 total) =
            BytesNative.items(f.dependencies, f.context, 0, 64);
        require(rows.length == total, "bounded native policy roster");
        // This is exactly the current-authority native-stage adaptation, preserving all other fields.
        BytesRoles.relabel(rows);
        _scopedBytesRememberAll(f, rows);
        BytesReferences.Context memory referenceContext = BytesReferences.Context(
            f.context.scope,
            f.context.subject,
            f.context.artistId,
            f.context.snapshot,
            f.context.referenceRender
        );
        uint64 cursor;
        do {
            (rows, total) = BytesReferences.items(f.dependencies, referenceContext, cursor, 64);
            _scopedBytesRememberAll(f, rows);
            cursor += uint64(rows.length);
        } while (cursor < total);
        _scopedBytesRecordCandidates(f, records, rightsResult);
        for (uint64 i; i < 31; ++i) {
            (bytes32 document, bytes32 expected) = BytesDefinitions.definition(i);
            _scopedBytesRemember(f, BytesDocuments.item(f.dependencies, document, expected));
        }
        require(publication.payloads.length == f.context.tokenCount);
        for (uint64 i; i < f.context.tokenCount; ++i) {
            _scopedBytesRememberAll(
                f, BytesTokens.tokenItems(f.dependencies, f.context, i, publication.payloads[i])
            );
            _scopedBytesRememberAll(f, BytesScripts.items(f.dependencies, f.context, i, false));
            _scopedBytesRememberAll(f, BytesScripts.items(f.dependencies, f.context, i, true));
            uint64 count;
            uint64 at;
            do {
                (BytesItems.Item memory row, uint64 size) =
                    BytesRenderers.item(f.dependencies, f.context, i, at++);
                _scopedBytesRemember(f, row);
                count = size;
            } while (at < count);
            at = 0;
            do {
                (BytesItems.Item memory row, uint64 size) =
                    BytesCitations.item(f.dependencies, f.context, i, at++);
                _scopedBytesRemember(f, row);
                count = size;
            } while (at < count);
        }
        _scopedBytesOriginCandidates(f);
    }

    function _scopedBytesRecordCandidates(
        ScopedBytesFrame memory f,
        ScopedRecordSet memory records,
        AuthorityScopedRights memory rightsResult
    ) private view {
        require(
            records.subject == f.context.subject && rightsResult.subject == f.context.subject
                && records.workPublication.recordHash
                    == f.context.descriptions.workDescriptionRecordHash
                && rightsResult.recordHash == f.context.descriptions.rightsStatementRecordHash
                && records.intentPublication.recordHash == f.context.conservation.record.recordHash
                && records.interviewPublication.recordHash
                    == f.context.conservation.interview.recordHash
                && records.intent.intent.interview.status
                    == BytesConservation.InterviewStatus.PRESENT
                && records.intent.intent.interview.record.chainId == block.chainid
                && records.intent.intent.interview.record.core == f.dependencies.targets[0]
                && records.intent.intent.interview.record.host == f.dependencies.targets[1]
                && records.intent.intent.interview.record.recordHash
                    == records.interviewPublication.recordHash,
            "exact full typed originals and PRESENT locator"
        );
        bytes32[4] memory hashes = [
            records.workPublication.recordHash,
            rightsResult.recordHash,
            records.intentPublication.recordHash,
            records.interviewPublication.recordHash
        ];
        bytes32[4] memory payloads = [
            f.context.descriptions.workPayloadHash,
            f.context.descriptions.rightsPayloadHash,
            f.context.conservation.record.payloadHash,
            f.context.conservation.interview.payloadHash
        ];
        BytesDependencies.Context memory context;
        context.collectionId = f.context.scope.collectionId;
        context.subject = f.context.subject;
        for (uint256 i; i < 4; ++i) {
            _scopedBytesRememberAll(
                f, BytesOriginals.items(f.dependencies, context, hashes[i], payloads[i])
            );
        }
        BytesItems.Item[] memory refs = BytesTyped.work(
            f.dependencies.targets[1], hashes[0], payloads[0], records.work.description
        );
        BytesDocuments.authenticateCatalogs(f.dependencies, refs);
        _scopedBytesRememberAll(f, refs);
        _scopedBytesRememberAll(
            f,
            BytesTyped.rights(
                f.dependencies.targets[1], hashes[1], payloads[1], rightsResult.statement
            )
        );
        _scopedBytesRememberAll(
            f,
            BytesTyped.intent(
                f.dependencies.targets[1], hashes[2], payloads[2], records.intent.intent
            )
        );
        refs = BytesTyped.interview(
            f.dependencies.targets[1], hashes[3], payloads[3], records.intent.interview.interview
        );
        BytesDocuments.authenticateCatalogs(f.dependencies, refs);
        _scopedBytesRememberAll(f, refs);
    }

    function _scopedBytesOriginCandidates(ScopedBytesFrame memory f) private view {
        uint256 count = f.inventory.originCount(f.id);
        require(
            count != 0 && count <= BytesOrigins.MAX_ORIGINS && f.inventory.originSetHash(f.id) != 0
        );
        for (uint256 n; n < count; ++n) {
            BytesOrigins.Origin memory origin = f.inventory.originAt(f.id, n);
            bytes32 original = BytesHydration.originHash(origin.environment);
            bytes32 provenance = BytesOrigins.originPinHash(origin);
            address[10] memory targets;
            targets[0] = origin.environment.registry;
            targets[1] = origin.environment.coordinator;
            targets[2] = origin.environment.archive;
            for (uint256 j; j < 7; ++j) {
                targets[j + 3] = origin.environment.owners[j];
            }
            for (uint256 j; j < 10; ++j) {
                bytes32 role = j == 0
                    ? keccak256("ARTIST_ORIGIN_REGISTRY_RUNTIME")
                    : j == 1
                        ? keccak256("ARTIST_ORIGIN_COORDINATOR_RUNTIME")
                        : j == 2
                            ? keccak256("ARTIST_ORIGIN_ARCHIVE_RUNTIME")
                            : keccak256("ARTIST_ORIGIN_OWNER_RUNTIME");
                BytesItems.Item memory item =
                    BytesRows.runtime(role, targets[j], original, j < 3 ? n : j - 3);
                item.provenanceHash = provenance;
                _scopedBytesRemember(f, item);
            }
        }
    }

    function _scopedSourceBytes(
        ScopedBytesFrame memory f,
        BytesItems.Item memory item,
        ScopedRecordSet memory records
    ) private view returns (bytes memory) {
        if (item.kind == BytesItems.Kind.CONTRACT_RUNTIME) {
            return item.source.code;
        }
        if (item.kind == BytesItems.Kind.REGISTERED_DOCUMENT) {
            return BytesSchemas(f.dependencies.targets[2]).documentBytes(item.catalogId);
        }
        if (item.kind == BytesItems.Kind.EXTERNAL_REFERENCE) {
            return _scopedReferenceDocument(f, item, records);
        }
        bytes32 role = item.role;
        if (role == keccak256("ORIGINAL_SCOPED_POLICY_SNAPSHOT_RECORD_V2")) {
            return _scopedRead(
                item.source, abi.encodeWithSignature("snapshotRecord(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("SCOPED_POLICY_SNAPSHOT_MANIFEST_V2")) {
            return _scopedDynamic(
                item.source, abi.encodeWithSignature("snapshotPayload(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("SCOPED_POLICY_NATIVE_SOURCE_FACTS_V2")) {
            return abi.encode(f.referenceSource.snapshotSource);
        }
        if (role == keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_V2")) {
            return abi.encode(f.referenceSource.contentRoot, f.referenceSource.contentRootBinding);
        }
        if (
            role == keccak256("STATIC_SELECTION_PLAN")
                || role == keccak256("SCOPED_POLICY_CONTENT_PLAN_V2")
        ) {
            return _scopedRead(
                item.source, abi.encodeWithSignature("checkpoint(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("SCOPED_POLICY_OUTPUT_MANIFEST_V2")) {
            return _scopedRead(
                item.source, abi.encodeWithSignature("manifestRecord(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("ORIGINAL_COMPLETE_COORDINATOR_POLICIES_V2")) {
            return abi.encode(f.referenceSource.snapshotSource.entropy);
        }
        if (role == keccak256("SCOPED_POLICY_SOURCE_FACTORY_DEPENDENCIES_V2")) {
            return _scopedRead(item.source, abi.encodeWithSignature("dependencies()"));
        }
        if (role == keccak256("ORIGINAL_COORDINATOR_POLICY_V2")) {
            return _scopedRead(
                f.snapshotDependencies.targets[10],
                abi.encodeWithSignature("sourcePolicyAt(uint256)", item.sourceIndex)
            );
        }
        if (role == keccak256("SCOPED_POLICY_REFERENCE_MANIFEST")) {
            return _scopedDynamic(
                item.source, abi.encodeWithSignature("referencePayload(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("REFERENCE_ENVIRONMENT_DECLARATION")) {
            return abi.encode(f.referencePublication.observation.environment);
        }
        if (role == keccak256("REFERENCE_CAPTURE_DECLARATION")) {
            return abi.encode(f.referencePublication.observation.captures[item.sourceIndex]);
        }
        if (role == keccak256("ORIGINAL_METADATA_RECORD_AND_RECEIPT")) {
            return _scopedRead(
                item.source, abi.encodeWithSignature("collectionRecord(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("ORIGINAL_TYPED_METADATA_PAYLOAD")) {
            (, bytes memory payload) = BytesMetadata(item.source).recordPayload(item.sourceRecord);
            return payload;
        }
        return _scopedTokenBytes(f, item);
    }

    function _scopedReferenceDocument(
        ScopedBytesFrame memory f,
        BytesItems.Item memory item,
        ScopedRecordSet memory records
    ) private view returns (bytes memory) {
        if (item.role == keccak256("PRESENT_INTERVIEW_PAYLOAD")) {
            (, bytes memory payload) = BytesMetadata(f.dependencies.targets[1])
                .recordPayload(records.interviewPublication.recordHash);
            return payload;
        }
        require(_scopedDocumentRole(item.role), "no arbitrary external reference byte fallback");
        for (uint256 i; i < records.references.length; ++i) {
            ScopedReferencePayload memory candidate = records.references[i];
            if (
                candidate.sourceRef.algorithm == item.algorithm
                    && candidate.sourceRef.canonicalizationId == item.canonicalizationId
                    && keccak256(candidate.sourceRef.digest) == keccak256(item.digest)
                    && keccak256(bytes(candidate.sourceRef.uri)) == keccak256(bytes(item.uri))
            ) {
                return candidate.payload;
            }
        }
        revert("missing actual op24 authoring document bytes");
    }

    function _scopedDocumentRole(bytes32 role) private pure returns (bool) {
        return role == keccak256("DISPLAY_SCALE") || role == keccak256("DISPLAY_TIMING")
            || role == keccak256("DISPLAY_COLOR") || role == keccak256("DISPLAY_INTERACTION")
            || role == keccak256("DISPLAY_MOTION") || role == keccak256("DISPLAY_FRAME_RATE")
            || role == keccak256("VARIABILITY_TOLERANCES") || role == keccak256("DEPENDENCY_AGING")
            || role == keccak256("SIGNIFICANT_PROPERTIES")
            || role == keccak256("INTERVIEW_INSTRUMENT")
            || role == keccak256("INTERVIEW_PARTICIPANT")
            || role == keccak256("INTERVIEW_TRANSCRIPT");
    }

    function _scopedTokenBytes(ScopedBytesFrame memory f, BytesItems.Item memory item)
        private
        view
        returns (bytes memory)
    {
        bytes32 role = item.role;
        uint256 token = item.sourceIndex;
        if (role == keccak256("TOKEN_DATA")) {
            return _scopedDynamic(item.source, abi.encodeWithSignature("tokenData(uint256)", token));
        }
        if (role == keccak256("TOKEN_METADATA_JSON")) {
            return _scopedDynamic(item.source, abi.encodeWithSignature("tokenJSON(uint256)", token));
        }
        if (role == keccak256("TOKEN_ANIMATION_HTML")) {
            return _scopedDynamic(item.source, abi.encodeWithSignature("tokenHTML(uint256)", token));
        }
        if (role == keccak256("ORIGINAL_TOKEN_IDENTITY_LIFECYCLE")) {
            (bool exists, uint256 cid, uint256 serial, bool burned) =
                BytesCore(item.source).tokenCollectionIdentity(token);
            require(exists && cid == f.context.scope.collectionId);
            return abi.encode(
                token,
                cid,
                serial,
                burned,
                uint8(BytesCore(item.source).tokenLifecycle(token)),
                uint256(_scopedTokenOrdinal(f, token))
            );
        }
        if (role == keccak256("ORIGINAL_TOKEN_ENTROPY")) {
            return _scopedRead(
                f.snapshotDependencies.targets[10],
                abi.encodeWithSignature("tokenEntropyReadiness(uint256)", token)
            );
        }
        if (role == keccak256("STATIC_SELECTION_ROW")) {
            return _scopedRead(
                item.source,
                abi.encodeWithSignature(
                    "selectionAt(bytes32,uint256)", item.sourceRecord, item.sourceIndex
                )
            );
        }
        if (role == keccak256("STATIC_OUTPUT_ROW")) {
            return _scopedRead(
                item.source,
                abi.encodeWithSignature(
                    "outputAt(bytes32,uint256)", item.sourceRecord, item.sourceIndex
                )
            );
        }
        if (role == keccak256("ORIGINAL_STATIC_CONFIG")) {
            return _scopedRead(
                item.source,
                abi.encodeWithSignature("metadataConfigRecord(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("ORIGINAL_STATIC_RAW_SOURCE")) {
            return _scopedRead(
                item.source,
                abi.encodeWithSignature(
                    "staticRenderSourceForConfig(uint256,bytes32)",
                    f.context.scope.collectionId,
                    item.sourceRecord
                )
            );
        }
        if (role == keccak256("ORIGINAL_TERMINAL_RENDER_ADMISSION")) {
            return _scopedRead(
                item.source, abi.encodeWithSignature("requireTerminalRenderReady(uint256)", token)
            );
        }
        return _scopedScriptOrRendererBytes(f, item);
    }

    function _scopedTokenOrdinal(ScopedBytesFrame memory f, uint256 token)
        private
        view
        returns (uint64)
    {
        for (uint64 i; i < f.context.tokenCount; ++i) {
            if (
                BytesMembership(f.snapshotDependencies.targets[5]).scopeTokenAt(f.context.scope, i)
                    == token
            ) return i;
        }
        revert("actual membership token required");
    }

    function _scopedScriptOrRendererBytes(ScopedBytesFrame memory f, BytesItems.Item memory item)
        private
        view
        returns (bytes memory)
    {
        bytes32 role = item.role;
        if (role == keccak256("INLINE_EXECUTABLE_SCRIPT")) {
            (, BytesTokens.Original memory original) = BytesTokens.sourceAt(
                f.dependencies, f.context, _scopedTokenOrdinal(f, item.sourceIndex)
            );
            (BytesRouter.RawSource memory source,) =
                abi.decode(original.source, (BytesRouter.RawSource, BytesRenderer.MetadataConfig));
            return bytes(source.script);
        }
        if (role == keccak256("ORIGINAL_SCRIPT_MANIFEST")) {
            return _scopedRead(
                item.source,
                abi.encodeWithSignature("staticScriptManifest(bytes32)", item.sourceRecord)
            );
        }
        if (
            role == keccak256("ORIGINAL_SCRIPT_FACTS")
                || role == keccak256("ORIGINAL_LIBRARY_FACTS")
        ) {
            return _scopedRead(
                item.source, abi.encodeWithSignature("staticBundle(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("ORIGINAL_DEPENDENCY_MANIFEST")) {
            return _scopedRead(
                item.source,
                abi.encodeWithSignature("dependencyManifest(bytes32)", item.sourceRecord)
            );
        }
        if (
            role == keccak256("EXECUTABLE_SCRIPT_CHUNK")
                || role == keccak256("EXECUTABLE_LIBRARY_CHUNK")
        ) {
            return _scopedDynamic(
                item.source,
                abi.encodeWithSignature(
                    "scriptBundleChunk(bytes32,uint256)", item.sourceRecord, item.sourceIndex
                )
            );
        }
        if (
            role == keccak256("COMPLETE_EXECUTABLE_SCRIPT")
                || role == keccak256("COMPLETE_EXECUTABLE_LIBRARY")
        ) return _scopedCompleteScript(f, item);
        if (role == keccak256("RENDERER_RETAINED_VERSION")) {
            return _scopedRead(
                item.source, abi.encodeWithSignature("version(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("RENDERER_REGISTRATION")) {
            return _scopedRead(
                item.source, abi.encodeWithSignature("registration(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("RENDERER_DECLARED_READS")) {
            return _scopedRead(
                item.source, abi.encodeWithSignature("reads(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("RENDERER_COMPLETE_TARGETS")) {
            BytesRegistry registry = BytesRegistry(item.source);
            uint256 count = registry.targetCount();
            require(count != 0 && count <= 64);
            BytesRegistry.Target[] memory targets = new BytesRegistry.Target[](count);
            for (uint256 i; i < count; ++i) {
                targets[i] = registry.targetAt(i);
            }
            return abi.encode(targets);
        }
        if (role == keccak256("RENDERER_SOURCE_BINDINGS")) {
            return _scopedRead(item.source, abi.encodeWithSignature("sourceBindings()"));
        }
        if (role == keccak256("CURRENT_BASE_CITATION_ADMISSION")) {
            return _scopedRead(
                item.source,
                abi.encodeWithSignature("currentCitationRecord(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("CURRENT_BASE_CITATION_READS")) {
            return _scopedRead(
                item.source,
                abi.encodeWithSignature("currentCitationReads(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("TERMINAL_ENTROPY_ADMISSION")) {
            return _scopedRead(
                item.source,
                abi.encodeWithSignature("terminalEntropyRecord(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("TERMINAL_ENTROPY_READS")) {
            return _scopedRead(
                item.source,
                abi.encodeWithSignature("terminalEntropyReads(bytes32)", item.sourceRecord)
            );
        }
        if (role == keccak256("TERMINAL_VALIDATION_BINDING")) {
            return _scopedRead(item.source, abi.encodeWithSignature("terminalValidationBinding()"));
        }
        if (role == keccak256("TERMINAL_POLICY_BINDING")) {
            return _scopedRead(item.source, abi.encodeWithSignature("terminalPolicyBinding()"));
        }
        revert("unsupported source role; no caller-invented byte registry");
    }

    function _scopedCompleteScript(ScopedBytesFrame memory f, BytesItems.Item memory item)
        private
        view
        returns (bytes memory result)
    {
        (BytesBundles.Facts memory facts,) =
            BytesScriptHost(f.dependencies.targets[1]).staticBundle(item.sourceRecord);
        require(
            facts.finalized && facts.chunkCount != 0 && facts.chunkCount <= 32
                && facts.totalBytes <= 786432
        );
        for (uint256 i; i < facts.chunkCount; ++i) {
            BytesScriptHost.Chunk memory chunk =
                BytesScriptHost(f.dependencies.targets[1]).staticBundleChunk(item.sourceRecord, i);
            bytes memory raw = _scopedDynamic(
                item.source,
                abi.encodeWithSignature("scriptBundleChunk(bytes32,uint256)", item.sourceRecord, i)
            );
            require(raw.length == chunk.length && keccak256(raw) == chunk.hash);
            result = bytes.concat(result, raw);
        }
        require(result.length == facts.totalBytes && keccak256(result) == facts.payloadHash);
    }

    function _scopedRead(address target, bytes memory input)
        private
        view
        returns (bytes memory raw)
    {
        require(target.code.length != 0);
        bool success;
        (success, raw) = target.staticcall(input);
        require(success && raw.length != 0, "actual original source getter failed");
    }

    function _scopedDynamic(address target, bytes memory input)
        private
        view
        returns (bytes memory value)
    {
        bytes memory raw = _scopedRead(target, input);
        value = abi.decode(raw, (bytes));
        require(keccak256(raw) == keccak256(abi.encode(value)), "canonical dynamic source return");
    }
}
