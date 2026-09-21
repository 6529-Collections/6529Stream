// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentFullPreservationPolicyViewRecordsFixture
} from "./StreamCurrentFullPreservationPolicyViewRecordsFixture.sol";
import { NativeAssemblyVm } from "./StreamNativeFinalityAssemblyFixture.sol";
import {
    StreamViewPreservationRenderCriticalInventoryV1
} from "../../smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    StreamViewPreservationBundleArchiveCoverageV1
} from "../../smart-contracts/domains/preservation/StreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as ViewInventory
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamViewPreservationRenderCriticalDefinitionsV1 as VIDefinitions
} from "../../smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalDefinitionsV1.sol";
import {
    StreamPreservationInventoryTypes as VI
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamBundleArchiveTypes as VIBundle
} from "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryChains as VIChains
} from "../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamViewPreservationReferenceTypesV1 as VIReference
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as VIObservation
} from "../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as VIContent
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewAdoptionTypes as VIAdoption
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamViewPayloadV2 as VIPayload
} from "../../smart-contracts/domains/metadata/StreamViewPayloadV2.sol";
import {
    IStreamCollectionViews as VIDeclaration
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamRendererRegistry as VIRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamPreservationRegistryV1 as VIPreservation
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamViewPreservationRendererV1 as VIServing
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    IStreamPreservationRecords as VIRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamCollectionMetadataV1 as VIMetadata
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamSchemaRegistry as VISchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as VIDocuments
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    StreamReferenceRenderDefinitions as VICommonDefinitions
} from "../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamExternalArtifactTypes as VIExternal
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import { Strings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @notice Materializes every genuine VIEW source occurrence and covers its complete bytes.
/// @dev Hosts must be deployed and bound by the complete construction fixture. This helper
/// supplies no observation defaults and makes no browser, transaction-fit or runtime claim.
/// Exact source bytes use the original onchain archive product; package objects retain the
/// caller-supplied archive observation boundary. No digest is treated as its own preimage.
abstract contract StreamCurrentFullPreservationPolicyViewInventoryFixture is
    StreamCurrentFullPreservationPolicyViewRecordsFixture
{
    StreamViewPreservationRenderCriticalInventoryV1 internal viewInventory;
    StreamViewPreservationBundleArchiveCoverageV1 internal viewBundle;
    bytes32 internal viewRenderInventoryPlan;
    ViewInventory.Evidence internal viewRenderInventoryEvidence;
    ViewInventory.BundleEvidence internal viewCompleteBundle;
    string internal viewPackageMembersDirectory;
    mapping(bytes32 => bytes) private viewInventorySourceBytes;

    error ViewInventorySourceUnavailable(
        bytes32 role, address source, uint256 index, bytes32 digest
    );
    error ViewInventoryUnsupportedReference(bytes32 role, uint256 index);

    function _viewMaterializeInventory() internal returns (VI.Item[][] memory rows) {
        _viewRequireInventoryHosts();
        require(
            assemblyViewReferenceRecord != 0 && viewRootConsentObservedAt != 0
                && viewOriginalRootAggregate.revision != 0 && viewOriginalLegacyFamilyHash != 0
                && viewWorkRecord != 0 && viewRightsRecord != 0 && viewWaiverRecord != 0,
            "actual VIEW originals precede materialization"
        );
        _viewPrepareInventoryDefinitions();
        bytes32 id = viewInventory.beginInventory(fullPolicyViewScope);
        require(viewInventory.plan(id).progress.segmentCount == 0, "fresh inventory log capture");
        assemblyVm.recordLogs();
        uint256 steps;
        while (viewInventory.plan(id).progress.completedStages == 0) {
            require(++steps <= 1024, "bounded complete native pages");
            viewInventory.appendNative(id, 64);
        }
        steps = 0;
        while (viewInventory.plan(id).progress.completedStages == 1) {
            require(++steps <= 1024, "bounded complete reference pages");
            viewInventory.appendReference(id, 64);
        }
        viewInventory.appendWork(id, viewWorkDescription, address(0));
        viewInventory.appendRights(id, viewRightsStatement);
        viewInventory.appendIntentWaiver(id, viewIntentWaiver, address(this));
        viewInventory.appendInterviewWaiver(id);
        viewInventory.appendRootAuthorization(
            id,
            address(this),
            viewRootConsentObservedAt,
            viewOriginalRootAggregate,
            viewOriginalLegacyFamilyHash
        );
        for (uint256 i; i < 36; ++i) {
            viewInventory.appendDefinition(id);
        }
        viewInventory.appendArtwork(id);
        steps = 0;
        while (viewInventory.plan(id).progress.completedStages == 9) {
            require(++steps <= 82, "complete renderer and maximum 64 targets");
            viewInventory.appendRenderer(id);
        }
        steps = 0;
        while (viewInventory.plan(id).progress.completedStages == 10) {
            require(++steps <= 78, "complete preservation admission and maximum 64 targets");
            viewInventory.appendPreservationAdmission(id);
        }
        uint64 tokenCount = viewInventory.plan(id).progress.tokenCount;
        require(tokenCount == fullPolicyTokens.length, "all actual VIEW members");
        for (uint64 i; i < tokenCount; ++i) {
            require(viewInventory.plan(id).progress.nextToken == i, "ordered token cursor");
            viewInventory.appendTokenOutput(id);
            require(viewInventory.plan(id).progress.nextToken == i + 1, "whole token completed");
        }
        NativeAssemblyVm.Log[] memory logs = assemblyVm.getRecordedLogs();
        rows = _viewInventoryEventRows(id, logs);
        ViewInventory.Plan memory p = viewInventory.plan(id);
        ViewInventory.TokenProgress memory token = viewInventory.tokenProgress(id);
        require(
            p.progress.completedStages == 11 && token.phase == 0 && token.row == 0
                && token.count == 0 && p.nativeCursor == p.nativeCount
                && p.referenceCursor == p.referenceCount,
            "all shared VIEW stages and full ordered token outputs"
        );
        ViewInventory.Evidence memory e = viewInventory.sealInventory(id);
        require(
            keccak256(abi.encode(e.scope)) == keccak256(abi.encode(fullPolicyViewScope))
                && e.inventory.planId == id && e.inventory.scopeSubject == _viewRecordsSubject()
                && e.inventory.collectionId == 1 && e.inventory.artistId == assemblyArtistId
                && e.inventory.tokenCount == tokenCount
                && e.inventory.segmentCount == p.progress.segmentCount
                && e.inventory.itemCount == p.progress.itemCount
                && e.inventory.segmentChainHash == p.progress.segmentChainHash
                && e.inventory.renderCriticalEvidenceHash != 0,
            "exact complete VIEW evidence and totals"
        );
        require(
            e.inventory.originals.rootRecordHash == assemblyViewOriginalContentRoot
                && e.inventory.originals.snapshotRecordHash == assemblyViewSnapshotRecord
                && e.inventory.originals.referenceRenderRecordHash == assemblyViewReferenceRecord
                && e.inventory.originals.intentRecordHash == 0
                && e.inventory.originals.intentWaiverRecordHash == viewWaiverRecord
                && e.inventory.originals.workDescriptionRecordHash == viewWorkRecord
                && e.inventory.originals.rightsStatementRecordHash == viewRightsRecord
                && e.inventory.originals.interviewEvidenceHash != 0,
            "exact VIEW originals, never COLLECTION substitutes"
        );
        bytes32 hash = e.inventory.renderCriticalEvidenceHash;
        e.inventory.renderCriticalEvidenceHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_EVIDENCE_V1"),
                        block.chainid,
                        address(viewInventory),
                        viewInventory.dependencyHash(),
                        e
                    )
                ),
            "independent VIEW evidence domain and full preimage"
        );
        e.inventory.renderCriticalEvidenceHash = hash;
        require(
            keccak256(abi.encode(viewInventory.requireCurrent(fullPolicyViewScope)))
                == keccak256(abi.encode(e)),
            "same complete current source"
        );
        viewInventory.requireFullDefinitionBytes(id);
        viewRenderInventoryPlan = id;
        viewRenderInventoryEvidence = e;
        _viewRetainInventoryBytes(id, rows);
    }

    function _viewRequireInventoryHosts() private view {
        require(
            address(viewInventory).code.length != 0 && address(viewBundle).code.length != 0
                && viewInventory.inventoryProfile()
                    == keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_V1")
                && viewBundle.bundleProfile()
                    == keccak256("6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1")
                && viewInventory.core() == address(assemblyCore)
                && viewInventory.metadataHost() == address(assemblyMetadata)
                && viewInventory.metadataRouter() == address(assemblyRouter)
                && viewInventory.snapshots() == address(assemblyViewPreservationSnapshot)
                && viewInventory.referencePublisher() == address(viewReference)
                && viewInventory.artifactCoverage() == address(assemblyArtifact)
                && viewInventory.externalCoverage() == address(assemblyExternal)
                && viewBundle.core() == address(assemblyCore)
                && viewBundle.metadataHost() == address(assemblyMetadata)
                && viewBundle.renderCriticalInventory() == address(viewInventory)
                && viewBundle.artifactCoverage() == address(assemblyArtifact)
                && viewBundle.externalCoverage() == address(assemblyExternal),
            "predeployed actual VIEW inventory and bundle graph"
        );
    }

    function _viewPrepareInventoryDefinitions() private {
        // All other fixed definitions are already admitted by description, declaration,
        // output, snapshot, root and reference preparation. These two are common vocabulary.
        string[2] memory names = [
            "STREAM_RENDERER_CLASS_DECLARATION_V1",
            "STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1"
        ];
        bytes32[2] memory hashes =
            [VICommonDefinitions.RENDERER_SCHEMA_HASH, VICommonDefinitions.RENDERER_PROFILE_HASH];
        for (uint256 i; i < names.length; ++i) {
            bytes32 id = keccak256(bytes(names[i]));
            if (!assemblySchemas.document(id).exists) {
                bytes memory raw = bytes(
                    assemblyVm.readFile(string.concat("schemas/records/", names[i], ".json"))
                );
                require(keccak256(raw) == hashes[i], "literal common renderer definition");
                _assemblyRegisterDocument(
                    names[i],
                    i == 0 ? VISchema.DocumentKind.SCHEMA : VISchema.DocumentKind.CATALOG,
                    raw,
                    assemblySchemas.RAW_BYTES()
                );
            }
        }
        for (uint64 i; i < 36; ++i) {
            (bytes32 id, bytes32 hash) = VIDefinitions.definition(i);
            VIDocuments.DocumentFacts memory facts = assemblySchemas.documentFacts(id);
            require(
                facts.exists && facts.status == VISchema.DocumentStatus.ACTIVE
                    && facts.contentHash == hash && facts.totalBytes != 0,
                "all 36 original interpretation definitions admitted"
            );
        }
    }

    function _viewInventoryEventRows(bytes32 id, NativeAssemblyVm.Log[] memory logs)
        private
        view
        returns (VI.Item[][] memory rows)
    {
        VI.Plan memory p = viewInventory.plan(id).progress;
        rows = new VI.Item[][](p.segmentCount);
        uint256 index;
        uint256 itemCount;
        bytes32 chain;
        bytes32 signature = keccak256(
            "ViewPreservationInventorySegmentRecorded(uint16,bytes32,uint64,(bytes32,uint64,bytes32,bytes32),(uint8,bytes32,address,bytes32,uint256,uint16,bytes32,bytes,string,uint64,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)[])"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(viewInventory)) continue;
            require(
                index < rows.length && logs[i].topics.length == 3 && logs[i].topics[0] == signature
                    && logs[i].topics[1] == id && uint256(logs[i].topics[2]) == index,
                "actual ordered schema-versioned VIEW inventory segment"
            );
            (uint16 version, VI.Segment memory segment, VI.Item[] memory items) =
                abi.decode(logs[i].data, (uint16, VI.Segment, VI.Item[]));
            require(
                version == 1
                    && keccak256(logs[i].data) == keccak256(abi.encode(version, segment, items))
                    && keccak256(abi.encode(segment))
                        == keccak256(abi.encode(viewInventory.inventorySegment(id, uint64(index))))
                    && items.length == segment.itemCount,
                "canonical materialized segment and complete item occurrences"
            );
            require(
                segment.key
                        == keccak256(
                            abi.encode(
                                keccak256(
                                    "6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_SEGMENT_V1"
                                ),
                                id,
                                uint64(index)
                            )
                        ) && segment.sourceWitnessHash != 0,
                "exact original VIEW segment domain"
            );
            bytes32 link;
            for (uint256 j = items.length; j > 0; --j) {
                link = VIChains.link(
                    segment.key, segment.itemCount, uint64(j - 1), items[j - 1], link
                );
            }
            require(link == segment.firstLink, "full event rows reconstruct original segment");
            chain = VIChains.append(chain, uint64(index), segment);
            rows[index++] = items;
            itemCount += items.length;
        }
        require(
            index == rows.length && itemCount == p.itemCount && chain == p.segmentChainHash,
            "complete independently reconstructed inventory chain"
        );
    }

    function _viewRememberInventoryBytes(bytes memory raw) private {
        if (raw.length != 0) viewInventorySourceBytes[keccak256(raw)] = raw;
    }

    function _viewInventoryRawRead(address target, bytes memory input)
        private
        view
        returns (bytes memory raw)
    {
        bool ok;
        (ok, raw) = target.staticcall(input);
        require(ok, "actual original source read; no substitute bytes");
    }

    function _viewRetainInventoryBytes(bytes32 id, VI.Item[][] memory rows) private {
        ViewInventory.Context memory c = viewInventory.sourceContext(id);
        VIReference.SourceFacts memory f =
            viewReference.referenceSource(assemblyViewReferenceRecord);
        _viewRememberInventoryBytes(
            _viewInventoryRawRead(
                address(assemblyViewPreservationSnapshot),
                abi.encodeWithSignature("snapshotRecord(bytes32)", assemblyViewSnapshotRecord)
            )
        );
        _viewRememberInventoryBytes(
            assemblyViewPreservationSnapshot.snapshotPayload(assemblyViewSnapshotRecord)
        );
        _viewRememberInventoryBytes(abi.encode(f.snapshotSource));
        _viewRememberInventoryBytes(abi.encode(f.contentRoot));
        _viewRememberInventoryBytes(abi.encode(f.contentBinding));
        _viewRememberInventoryBytes(abi.encode(f.snapshotSource.adoption.adoption));
        _viewRememberInventoryBytes(abi.encode(f.snapshotSource.adoption.policy));
        _viewRememberInventoryBytes(abi.encode(f.snapshotSource.adoption.preservation));
        _viewRememberInventoryBytes(abi.encode(f.snapshotSource.adoption.admission));
        _viewRememberInventoryBytes(abi.encode(f.snapshotSource.checkpoint));
        _viewRememberInventoryBytes(abi.encode(f.snapshotSource.outputs));
        _viewRememberInventoryBytes(abi.encode(f.snapshotSource.entropy));
        for (uint256 i; i < f.snapshotSource.entropy.policies.length; ++i) {
            _viewRememberInventoryBytes(abi.encode(f.snapshotSource.entropy.policies[i]));
        }
        for (uint256 i; i < f.snapshotSource.outputs.partCount; ++i) {
            _viewRememberInventoryBytes(
                abi.encode(
                    assemblyViewPreservationManifest.manifestPart(viewPublicationOutputManifest, i)
                )
            );
        }
        _viewRememberInventoryBytes(viewReference.referencePayload(assemblyViewReferenceRecord));
        _viewRememberInventoryBytes(abi.encode(viewReferencePublication.observation.environment));
        for (uint256 i; i < viewReferencePublication.observation.captures.length; ++i) {
            _viewRememberInventoryBytes(
                abi.encode(viewReferencePublication.observation.captures[i])
            );
        }
        bytes32[3] memory originals = [viewWorkRecord, viewRightsRecord, viewWaiverRecord];
        for (uint256 i; i < originals.length; ++i) {
            (VIRecords.CollectionRecord memory record, VIMetadata.RecordReceipt memory receipt) =
                assemblyMetadata.collectionRecord(originals[i]);
            _viewRememberInventoryBytes(abi.encode(record, receipt));
            (, bytes memory payload) = assemblyMetadata.recordPayload(originals[i]);
            _viewRememberInventoryBytes(payload);
        }
        // These fixture references explicitly hash the URI text itself, not content fetched
        // from the URL. A different documentary reference must supply its real preimage.
        _viewRememberInventoryBytes(bytes(viewIntentWaiver.waiverStatement.uri));
        _viewRememberInventoryBytes(bytes(viewIntentWaiver.interview.waiverStatement.uri));
        _viewRetainArtworkBytes();
        _viewRetainRendererBytes(f);
        for (uint64 i; i < c.tokenCount; ++i) {
            VIContent.Output memory output =
                assemblyViewPreservationCheckpoint.outputAt(c.checkpointHash, i);
            require(
                output.tokenId == fullPolicyTokens[i] && output.index == i,
                "same actual ordered output"
            );
            bytes memory json = _viewCurrentPreservationBytes(output.tokenId, false);
            bytes memory html = _viewCurrentPreservationBytes(output.tokenId, true);
            require(
                keccak256(json) == output.jsonHash && json.length == output.jsonBytes
                    && keccak256(html) == output.htmlHash && html.length == output.htmlBytes
                    && keccak256(json) == keccak256(viewPublicationJSON[output.tokenId])
                    && keccak256(html) == keccak256(viewPublicationHTML[output.tokenId]),
                "every complete current output equals checkpoint and original capture input"
            );
            _viewRememberInventoryBytes(
                abi.encode(
                    output.tokenId,
                    c.scope.collectionId,
                    output.collectionSerial,
                    output.burned,
                    output.lifecycle,
                    i
                )
            );
            _viewRememberInventoryBytes(assemblyCore.tokenData(output.tokenId));
            _viewRememberInventoryBytes(abi.encode(output));
            _viewRememberInventoryBytes(json);
            _viewRememberInventoryBytes(html);
        }
        for (uint256 i; i < rows.length; ++i) {
            for (uint256 j; j < rows[i].length; ++j) {
                VI.Item memory item = rows[i][j];
                if (item.kind == VI.Kind.CONTRACT_RUNTIME) {
                    _viewRememberInventoryBytes(item.source.code);
                }
                if (item.kind == VI.Kind.REGISTERED_DOCUMENT) {
                    // A typed record's catalogue keeps that record in sourceRecord;
                    // catalogId is the authoritative document coordinate in both profiles.
                    require(item.catalogId != 0, "actual registered catalogue identity");
                    VIDocuments.DocumentFacts memory facts =
                        assemblySchemas.documentFacts(item.catalogId);
                    bytes memory raw;
                    for (uint256 k; k < facts.chunkCount; ++k) {
                        raw = bytes.concat(
                            raw,
                            assemblyStore.readChunk(
                                assemblySchemas.documentChunkHashAt(item.catalogId, k)
                            )
                        );
                    }
                    require(
                        raw.length == item.byteSize
                            && keccak256(raw) == abi.decode(item.digest, (bytes32)),
                        "exact complete registered interpretation bytes"
                    );
                    _viewRememberInventoryBytes(raw);
                }
                if (_viewNeedsSourceBytes(item)) _viewRetainedInventoryBytes(item);
            }
        }
    }

    function _viewRetainArtworkBytes() private {
        (
            VIDeclaration.CollectionViewManifest memory declaration,
            VIDeclaration.ViewReceipt memory receipt,
            VIRecords.CollectionRecord memory record
        ) = assemblyViewDeclarations.viewRecord(fullPolicyViewDeclaration);
        _viewRememberInventoryBytes(abi.encode(declaration, receipt, record));
        _viewRememberInventoryBytes(
            abi.encode(uint256(1), receipt.revision, receipt.previousRecordHash, declaration)
        );
        _viewRememberInventoryBytes(fullPolicyViewPayload);
        VIAdoption.Payload memory p = VIPayload.decode(fullPolicyViewPayload);
        _viewRememberInventoryBytes(p.script);
        _viewRememberInventoryBytes(bytes(p.imageURI));
        require(
            bytes(p.imageURI).length == 0,
            "this authored artwork has no external image; no fake coverage"
        );
    }

    function _viewRetainRendererBytes(VIReference.SourceFacts memory f) private {
        address registry = f.snapshotSource.adoption.adoption.source.renderer.registry;
        bytes32 key = f.snapshotSource.adoption.adoption.source.renderer.versionKey;
        address renderer = f.snapshotSource.adoption.adoption.source.renderer.renderer;
        _viewRememberInventoryBytes(
            _viewInventoryRawRead(registry, abi.encodeCall(VIRegistry.version, (key)))
        );
        _viewRememberInventoryBytes(
            _viewInventoryRawRead(registry, abi.encodeCall(VIRegistry.registration, (key)))
        );
        _viewRememberInventoryBytes(
            _viewInventoryRawRead(registry, abi.encodeCall(VIRegistry.reads, (key)))
        );
        VIRegistry.Target[] memory targets =
            new VIRegistry.Target[](VIRegistry(registry).targetCount());
        for (uint256 i; i < targets.length; ++i) {
            targets[i] = VIRegistry(registry).targetAt(i);
        }
        _viewRememberInventoryBytes(abi.encode(targets));
        _viewRememberInventoryBytes(
            _viewInventoryRawRead(renderer, abi.encodeWithSignature("sourceBindings()"))
        );
        _viewRememberInventoryBytes(abi.encode(f.snapshotSource.adoption.policy));
        address producer = f.contentBinding.preservationRenderer;
        bytes32 preservationKey =
            VIPreservation(registry).preservationKey(key, producer, VIContent.OUTPUT_PROFILE);
        // Profile is read from the genuine producer as well, so a mistaken fixture literal
        // cannot silently select a different declaration.
        require(
            VIServing(producer).preservationProfile() == VIContent.OUTPUT_PROFILE,
            "exact VIEW producer profile"
        );
        _viewRememberInventoryBytes(
            _viewInventoryRawRead(
                registry, abi.encodeCall(VIPreservation.preservationRecord, (preservationKey))
            )
        );
        _viewRememberInventoryBytes(
            _viewInventoryRawRead(
                registry, abi.encodeCall(VIPreservation.preservationReads, (preservationKey))
            )
        );
        _viewRememberInventoryBytes(abi.encode(VIServing(producer).configuration()));
        _viewRememberInventoryBytes(
            abi.encode(VIServing(producer).preservationViewBinding(fullPolicyViewAdoption))
        );
        _viewRememberInventoryBytes(
            _viewInventoryRawRead(producer, abi.encodeCall(VIServing.workerBinding, ()))
        );
        _viewRememberInventoryBytes(
            _viewInventoryRawRead(producer, abi.encodeCall(VIServing.encodingBinding, ()))
        );
    }

    function _viewNeedsSourceBytes(VI.Item memory item) private pure returns (bool) {
        return item.kind == VI.Kind.NATIVE_BYTES || item.kind == VI.Kind.CONTRACT_RUNTIME
            || item.kind == VI.Kind.ORIGINAL_PAYLOAD || item.kind == VI.Kind.REGISTERED_DOCUMENT
            || (item.kind == VI.Kind.EXTERNAL_REFERENCE
                && item.role != keccak256("RUNNABLE_PACKAGE_MEMBER"));
    }

    function _viewRetainedInventoryBytes(VI.Item memory item)
        private
        view
        returns (bytes memory raw)
    {
        if (item.algorithm != 1 || item.digest.length != 32) {
            revert ViewInventoryUnsupportedReference(item.role, item.sourceIndex);
        }
        bytes32 digest = abi.decode(item.digest, (bytes32));
        raw = viewInventorySourceBytes[digest];
        if (
            raw.length == 0 || keccak256(raw) != digest
                || (item.byteSize != 0 && raw.length != item.byteSize)
        ) {
            revert ViewInventorySourceUnavailable(item.role, item.source, item.sourceIndex, digest);
        }
    }

    function _viewCoverCompleteBundle(VI.Item[][] memory rows) internal {
        bytes32 id = viewRenderInventoryPlan;
        VI.Evidence memory e = viewRenderInventoryEvidence.inventory;
        require(id != 0 && rows.length == e.segmentCount, "same materialized VIEW inventory");
        VIBundle.Proof[][] memory proofs = new VIBundle.Proof[][](rows.length);
        uint256 packageMembers;
        uint256 stateBundles;
        for (uint256 i; i < rows.length; ++i) {
            proofs[i] = new VIBundle.Proof[](rows[i].length);
            for (uint256 j; j < rows[i].length; ++j) {
                VI.Item memory item = rows[i][j];
                if (item.kind == VI.Kind.EMPTY_PACKAGE_MEMBER) {
                    ++packageMembers;
                    VIObservation.PackageFile memory member = viewReferencePublication.observation
                    .environment
                    .packageFiles[item.sourceIndex];
                    require(
                        member.byteSize == 0 && member.sha256Digest == sha256(bytes(""))
                            && keccak256(bytes(member.path)) == keccak256(bytes(item.uri)),
                        "original empty package member"
                    );
                } else if (item.kind == VI.Kind.STATE_BUNDLE) {
                    ++stateBundles; // Original Archive op24/op17 immutable STOP bundles validate inside coverNext.
                } else if (
                    item.kind == VI.Kind.EXTERNAL_REFERENCE
                        && item.role == keccak256("RUNNABLE_PACKAGE_MEMBER")
                ) {
                    ++packageMembers;
                    proofs[i][j] = this.coverViewPackageMember(item);
                } else if (item.kind == VI.Kind.EXTERNAL_OBJECT) {
                    proofs[i][j] = VIBundle.Proof(1, item.originalCoverageHash, item.objectHash);
                } else if (item.kind == VI.Kind.ONCHAIN_OBJECT) {
                    proofs[i][j] = VIBundle.Proof(2, item.originalCoverageHash, item.objectHash);
                } else if (_viewNeedsSourceBytes(item)) {
                    bytes memory raw = _viewRetainedInventoryBytes(item);
                    (bytes32 artifact, bytes32 coverage) = _ocCover(
                        raw,
                        item.schemaId == 0
                            ? keccak256("PRESERVATION_ORIGINAL_BYTES_DECLARATION")
                            : item.schemaId,
                        item.canonicalizationId
                    );
                    proofs[i][j] = VIBundle.Proof(2, coverage, artifact);
                } else {
                    require(
                        item.kind == VI.Kind.ABSENT || item.kind == VI.Kind.EMPTY_BYTES
                            || item.kind == VI.Kind.NATIVE_OS_PREREQUISITE,
                        "no unhandled source occurrence"
                    );
                }
            }
        }
        require(
            packageMembers == viewReferencePublication.observation.environment.packageFiles.length
                && stateBundles == 2,
            "every package member and original VIEW op24/op17"
        );
        // Finish all new receipt/fixity admissions before freezing the bundle environment.
        viewBundle.beginCoverage(id);
        uint256 processed;
        for (uint64 i; i < rows.length; ++i) {
            VI.Segment memory segment = viewInventory.inventorySegment(id, i);
            bytes32[] memory next = new bytes32[](rows[i].length);
            bytes32 link;
            for (uint256 j = rows[i].length; j > 0; --j) {
                next[j - 1] = link;
                link = VIChains.link(
                    segment.key, segment.itemCount, uint64(j - 1), rows[i][j - 1], link
                );
            }
            require(link == segment.firstLink, "same complete materialized rows");
            if (rows[i].length == 0) viewBundle.coverEmptySegment(id);
            for (uint256 j; j < rows[i].length; ++j) {
                if (processed == 0) {
                    (bool ok,) = address(viewBundle)
                        .call(
                            abi.encodeCall(
                                viewBundle.coverNext,
                                (id, rows[i][j], next[j], VIBundle.Proof(0, 0, 0))
                            )
                        );
                    require(
                        !ok && viewBundle.progress(id).itemCount == 0,
                        "cannot skip first actual source coverage"
                    );
                }
                viewBundle.coverNext(id, rows[i][j], next[j], proofs[i][j]);
                ++processed;
            }
        }
        require(
            processed == e.itemCount && viewBundle.progress(id).complete,
            "every original occurrence covered"
        );
        ViewInventory.BundleEvidence memory covered =
            viewBundle.requireCoverage(fullPolicyViewScope, id, e.renderCriticalEvidenceHash);
        require(
            keccak256(abi.encode(covered.scope)) == keccak256(abi.encode(fullPolicyViewScope))
                && covered.coverage.inventoryPlan == id && covered.coverage.itemCount == e.itemCount
                && covered.coverage.renderCriticalEvidenceHash == e.renderCriticalEvidenceHash
                && covered.coverage.bundleCoverageHash != 0
                && covered.coverage.bundleCoverageHash != e.renderCriticalEvidenceHash,
            "independent original VIEW bundle coverage"
        );
        require(
            keccak256(abi.encode(viewBundle.requireFullCurrentCoverage(id)))
                == keccak256(abi.encode(covered)),
            "full per-entry diagnostic agrees with immutable STOP aggregate"
        );
        require(
            keccak256(abi.encode(viewInventory.requireCurrent(fullPolicyViewScope)))
                == keccak256(abi.encode(viewRenderInventoryEvidence)),
            "archive work preserves current VIEW source"
        );
        viewCompleteBundle = covered;
    }

    function coverViewPackageMember(VI.Item calldata item)
        external
        returns (VIBundle.Proof memory)
    {
        require(
            msg.sender == address(this) && item.kind == VI.Kind.EXTERNAL_REFERENCE
                && item.role == keccak256("RUNNABLE_PACKAGE_MEMBER")
                && bytes(viewPackageMembersDirectory).length != 0,
            "supplied package member observations only"
        );
        VIObservation.PackageFile memory member =
            viewReferencePublication.observation.environment.packageFiles[item.sourceIndex];
        string memory json = assemblyVm.readFile(
            string.concat(
                viewPackageMembersDirectory, "/", Strings.toString(item.sourceIndex), ".json"
            )
        );
        VIExternal.ObjectIdentity memory object;
        object.contentHash = bytes32(safeVm.parseJsonBytes(json, ".contentHash"));
        object.sha256Digest = bytes32(safeVm.parseJsonBytes(json, ".sha256Digest"));
        object.arweaveDataRoot = bytes32(safeVm.parseJsonBytes(json, ".arweaveDataRoot"));
        object.byteSize = uint64(assemblyVm.parseJsonUint(json, ".byteSize"));
        string memory path = assemblyVm.parseJsonString(json, ".path");
        require(
            object.byteSize != 0 && object.byteSize == item.byteSize
                && member.byteSize == item.byteSize && object.sha256Digest == member.sha256Digest
                && keccak256(abi.encodePacked(object.sha256Digest)) == keccak256(item.digest)
                && keccak256(bytes(path)) == keccak256(bytes(item.uri))
                && keccak256(bytes(member.path)) == keccak256(bytes(path)),
            "exact ordered uncompressed package member identity"
        );
        object.artistId = assemblyArtistId;
        object.schemaId = keccak256("PRESERVATION_ORIGINAL_BYTES_DECLARATION");
        object.canonicalizationId = item.canonicalizationId;
        object.formatId = keccak256("DECLARED_APPLICATION_OCTET_STREAM");
        object.formatCatalogId = keccak256("PRESERVATION_BYTE_OBJECT_DECLARATION");
        object.formatCatalogHash =
            keccak256("declared object metadata; interpretation comes from actual original source");
        VIExternal.Coverage memory coverage = _assemblyCoverExternal(
            object,
            safeVm.parseJsonBytes(json, ".firstDataPath"),
            safeVm.parseJsonBytes(json, ".lastDataPath"),
            safeVm.parseJsonBytes(json, ".firstChunkRaw"),
            safeVm.parseJsonBytes(json, ".lastChunkRaw")
        );
        return VIBundle.Proof(1, coverage.coverageHash, coverage.objectHash);
    }
}
