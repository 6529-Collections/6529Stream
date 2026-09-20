// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentFullPolicyReferenceFixture.sol";
import "./StreamCurrentFullPolicyPublicationBase.sol";
import {
    IStreamPolicyContentCheckpointV2
} from "../../smart-contracts/interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamRenderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    StreamPolicyRenderCriticalInventoryV2
} from "../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalInventoryV2.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as PolicyInventory
} from "../../smart-contracts/interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamPolicyRenderCriticalTokenReadsV2 as PolicyTokens
} from "../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalTokenReadsV2.sol";
import {
    IStreamScopedContentRootPublication as ScopedRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

/// @notice Materializes and covers every genuine V2 source occurrence, including all STATIC stages.
/// @dev Browser observations and package endpoint witnesses are caller-supplied fixture inputs.
abstract contract StreamCurrentFullPolicyInventoryFixture is
    StreamCurrentFullPolicyReferenceFixture
{
    StreamPolicyRenderCriticalInventoryV2 internal publicationInventory;
    StreamBundleArchiveCoverage internal publicationBundle;
    bytes32 internal assemblyRenderInventoryPlan;
    AssemblyInventory.Evidence internal assemblyRenderInventoryEvidence;
    AssemblyInventory.BundleEvidence internal assemblyCompleteBundle;
    mapping(bytes32 => bytes) private publicationSourceBytes;
    string internal publicationPackageMembersDirectory;

    function _publicationMaterializeInventory()
        internal
        returns (AssemblyInventory.Item[][] memory rows)
    {
        require(
            assemblyReferenceRecord != 0 && assemblyRootConsentObservedAt != 0,
            "original producers precede inventory"
        );
        publicationInventory = StreamPolicyRenderCriticalInventoryV2(publicationGraph.children[5]);
        publicationBundle = StreamBundleArchiveCoverage(publicationGraph.children[6]);
        bytes32 id = publicationInventory.beginInventory(1);
        assemblyVm.recordLogs();
        publicationInventory.appendNative(id);
        publicationInventory.appendReference(id);
        publicationInventory.appendWork(id, assemblyWorkDescription, address(0));
        publicationInventory.appendRights(id, assemblyRightsStatement);
        publicationInventory.appendIntentWaiver(id, assemblyIntentWaiver, address(this));
        publicationInventory.appendInterviewWaiver(id);
        // No scoped roots were authored by this fixture. The actual original aggregate is zero.
        ScopedRoot.Aggregate memory aggregate;
        publicationInventory.appendRootAuthorization(
            id, address(this), assemblyRootConsentObservedAt, aggregate
        );
        for (uint256 i; i < 31; ++i) {
            publicationInventory.appendDefinition(id);
        }
        for (uint256 i; i < fullPolicyTokens.length; ++i) {
            uint256 tokenId = fullPolicyTokens[i];
            publicationInventory.appendToken(
                id,
                IStreamPolicyContentCheckpointV2.Payload(
                    tokenId, bytes(""), publicationHTML[tokenId]
                )
            );
            publicationInventory.appendScript(id);
            publicationInventory.appendLibrary(id);
            uint256 stages;
            while (publicationInventory.tokenProgress(id).phase == 3) {
                require(++stages <= 77, "bounded complete renderer roster");
                publicationInventory.appendRenderer(id);
            }
            stages = 0;
            while (publicationInventory.plan(id).nextToken == i) {
                require(
                    publicationInventory.tokenProgress(id).phase == 4 && ++stages <= 8,
                    "bounded complete current profile"
                );
                publicationInventory.appendCurrentProfile(id);
            }
            require(publicationInventory.plan(id).nextToken == i + 1, "every token stage complete");
        }
        NativeAssemblyVm.Log[] memory logs = assemblyVm.getRecordedLogs();
        uint64 count = publicationInventory.plan(id).segmentCount;
        rows = new AssemblyInventory.Item[][](count);
        uint256 index;
        uint256 itemCount;
        bytes32 signature = keccak256(
            "InventorySegmentRecorded(bytes32,uint64,(bytes32,uint64,bytes32,bytes32),(uint8,bytes32,address,bytes32,uint256,uint16,bytes32,bytes,string,uint64,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)[])"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(publicationInventory)) continue;
            require(
                index < count && logs[i].topics.length == 3 && logs[i].topics[0] == signature
                    && logs[i].topics[1] == id && uint256(logs[i].topics[2]) == index,
                "actual ordered inventory stage event"
            );
            (AssemblyInventory.Segment memory segment, AssemblyInventory.Item[] memory items) =
                abi.decode(logs[i].data, (AssemblyInventory.Segment, AssemblyInventory.Item[]));
            require(
                keccak256(abi.encode(segment))
                        == keccak256(
                            abi.encode(publicationInventory.inventorySegment(id, uint64(index)))
                        ) && items.length == segment.itemCount,
                "exact retained event segment"
            );
            rows[index++] = items;
            itemCount += items.length;
        }
        require(index == count && count > 40, "V2 full STATIC stages are not two V1 token rows");
        AssemblyInventory.Evidence memory evidence = publicationInventory.sealInventory(id);
        require(
            evidence.itemCount == itemCount && evidence.segmentCount == count
                && evidence.tokenCount == 2 && evidence.planId == id
                && evidence.artistId == assemblyArtistId
                && evidence.renderCriticalEvidenceHash != 0,
            "complete actual inventory totals"
        );
        require(
            evidence.originals.rootRecordHash == assemblyOriginalContentRoot
                && evidence.originals.snapshotRecordHash == assemblySnapshotRecord
                && evidence.originals.referenceRenderRecordHash == assemblyReferenceRecord
                && evidence.originals.intentRecordHash == 0
                && evidence.originals.intentWaiverRecordHash == assemblyWaiverRecord
                && evidence.originals.workDescriptionRecordHash == assemblyWorkRecord
                && evidence.originals.rightsStatementRecordHash == assemblyRightsRecord
                && evidence.originals.interviewEvidenceHash != 0,
            "all original authority joins"
        );
        assemblyRenderInventoryPlan = id;
        assemblyRenderInventoryEvidence = evidence;
        _publicationRetainSourceBytes(id, rows);
    }

    function _publicationRemember(bytes memory raw) private {
        if (raw.length != 0) publicationSourceBytes[keccak256(raw)] = raw;
    }

    function _publicationRawRead(address target, bytes memory input)
        private
        view
        returns (bytes memory raw)
    {
        bool ok;
        (ok, raw) = target.staticcall{ gas: PUBLICATION_RENDER_GAS }(input);
        require(ok, "actual retained source read");
    }

    function _publicationRetainSourceBytes(bytes32 id, AssemblyInventory.Item[][] memory rows)
        private
    {
        PolicyInventory.Context memory c = publicationInventory.sourceContext(id);
        _publicationRemember(publicationSnapshots.snapshotPayload(c.snapshot.recordHash));
        _publicationRemember(abi.encode(c.source));
        _publicationRemember(abi.encode(c.source.root, c.source.rootBinding));
        _publicationRemember(abi.encode(c.source.entropy));
        _publicationRemember(abi.encode(c.source.outputs));
        for (uint256 i; i < c.source.entropy.policies.length; ++i) {
            _publicationRemember(abi.encode(c.source.entropy.policies[i]));
        }
        _publicationRemember(publicationReference.referencePayload(assemblyReferenceRecord));
        _publicationRemember(abi.encode(publicationReferencePublication.observation.environment));
        for (uint256 i; i < publicationReferencePublication.observation.captures.length; ++i) {
            _publicationRemember(
                abi.encode(publicationReferencePublication.observation.captures[i])
            );
        }
        bytes32[3] memory originals =
            [assemblyWorkRecord, assemblyRightsRecord, assemblyWaiverRecord];
        for (uint256 i; i < 3; ++i) {
            (
                IStreamPreservationRecords.CollectionRecord memory record,
                IStreamCollectionMetadataV1.RecordReceipt memory receipt
            ) = assemblyMetadata.collectionRecord(originals[i]);
            _publicationRemember(abi.encode(record, receipt));
            (, bytes memory payload) = assemblyMetadata.recordPayload(originals[i]);
            _publicationRemember(payload);
        }
        _publicationRemember(bytes(assemblyIntentWaiver.waiverStatement.uri));
        _publicationRemember(bytes(assemblyIntentWaiver.interview.waiverStatement.uri));
        for (uint64 i; i < 2; ++i) {
            (uint256 token, PolicyTokens.Original memory original) =
                PolicyTokens.sourceAt(publicationInventory.dependencies(), c, i);
            _publicationRemember(assemblyCore.tokenData(token));
            _publicationRemember(publicationJSON[token]);
            _publicationRemember(publicationHTML[token]);
            _publicationRemember(original.identity);
            _publicationRemember(original.entropy);
            _publicationRemember(abi.encode(original.selection));
            _publicationRemember(abi.encode(original.output));
            _publicationRemember(original.config);
            _publicationRemember(original.source);
            (StaticRouter.RawSource memory source,) = abi.decode(
                original.source, (StaticRouter.RawSource, IStreamRenderer.MetadataConfig)
            );
            // This authored artwork uses an inline script and no executable library.
            require(source.scriptManifest.manifestHash == 0, "fixture inline script profile");
            _publicationRemember(bytes(source.script));
            address registry = original.selection.selection.registry;
            bytes32 key = original.selection.selection.versionKey;
            _publicationRemember(
                _publicationRawRead(registry, abi.encodeCall(Versions.version, (key)))
            );
            _publicationRemember(
                _publicationRawRead(registry, abi.encodeCall(Versions.registration, (key)))
            );
            _publicationRemember(
                _publicationRawRead(registry, abi.encodeCall(Versions.reads, (key)))
            );
            Versions.Target[] memory targets =
                new Versions.Target[](Versions(registry).targetCount());
            for (uint256 j; j < targets.length; ++j) {
                targets[j] = Versions(registry).targetAt(j);
            }
            _publicationRemember(abi.encode(targets));
            _publicationRemember(
                _publicationRawRead(
                    original.selection.selection.renderer,
                    abi.encodeWithSignature("sourceBindings()")
                )
            );
            _publicationRemember(
                _publicationRawRead(
                    registry, abi.encodeCall(TokenCitationRegistry.currentCitationRecord, (key))
                )
            );
            _publicationRemember(
                _publicationRawRead(
                    registry, abi.encodeCall(TokenCitationRegistry.currentCitationReads, (key))
                )
            );
        }
        // Independently retrieve every runtime and complete schema payload named by actual events.
        for (uint256 i; i < rows.length; ++i) {
            for (uint256 j; j < rows[i].length; ++j) {
                AssemblyInventory.Item memory item = rows[i][j];
                if (item.kind == AssemblyInventory.Kind.CONTRACT_RUNTIME) {
                    _publicationRemember(item.source.code);
                }
                if (item.kind == AssemblyInventory.Kind.REGISTERED_DOCUMENT) {
                    IStreamSchemaDocumentFacts.DocumentFacts memory facts =
                        assemblySchemas.documentFacts(item.sourceRecord);
                    bytes memory raw;
                    for (uint256 k; k < facts.chunkCount; ++k) {
                        raw = bytes.concat(
                            raw,
                            assemblyStore.readChunk(
                                assemblySchemas.documentChunkHashAt(item.sourceRecord, k)
                            )
                        );
                    }
                    require(
                        raw.length == item.byteSize
                            && keccak256(raw) == abi.decode(item.digest, (bytes32)),
                        "exact registered bytes"
                    );
                    _publicationRemember(raw);
                }
            }
        }
    }

    function _assemblyInventoryExternalProof(
        AssemblyInventory.Item memory item,
        AxE.ObjectIdentity memory object,
        bytes memory firstPath,
        bytes memory lastPath,
        bytes memory firstRaw,
        bytes memory lastRaw
    ) private returns (StreamBundleArchiveTypes.Proof memory) {
        object.artistId = assemblyArtistId;
        object.schemaId = item.schemaId != 0
            ? item.schemaId
            : keccak256("PRESERVATION_ORIGINAL_BYTES_DECLARATION");
        object.canonicalizationId = item.canonicalizationId;
        object.formatId =
            item.formatId != 0 ? item.formatId : keccak256("DECLARED_APPLICATION_OCTET_STREAM");
        object.formatCatalogId = item.kind != AssemblyInventory.Kind.REGISTERED_DOCUMENT
            && item.catalogId != 0
            ? item.catalogId
            : keccak256("PRESERVATION_BYTE_OBJECT_DECLARATION");
        object.formatCatalogHash = item.kind != AssemblyInventory.Kind.REGISTERED_DOCUMENT
            && item.catalogHash != 0
            ? item.catalogHash
            : keccak256(
                "declared object metadata; interpretation comes from actual original source"
            );
        AxE.Coverage memory cover =
            _assemblyCoverExternal(object, firstPath, lastPath, firstRaw, lastRaw);
        return StreamBundleArchiveTypes.Proof(1, cover.coverageHash, cover.objectHash);
    }

    function coverAssemblyPackageMember(AssemblyInventory.Item calldata item)
        external
        returns (StreamBundleArchiveTypes.Proof memory)
    {
        require(
            msg.sender == address(this) && item.kind == AssemblyInventory.Kind.EXTERNAL_REFERENCE
                && item.role == keccak256("RUNNABLE_PACKAGE_MEMBER"),
            "fixture-only current member"
        );
        StreamReferenceRenderTypes.PackageFile memory member =
            publicationReferencePublication.observation.environment.packageFiles[item.sourceIndex];
        string memory json = assemblyVm.readFile(
            string.concat(
                publicationPackageMembersDirectory, "/", Strings.toString(item.sourceIndex), ".json"
            )
        );
        AxE.ObjectIdentity memory object;
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
            "exact ordered uncompressed original package member"
        );
        return _assemblyInventoryExternalProof(
            item,
            object,
            safeVm.parseJsonBytes(json, ".firstDataPath"),
            safeVm.parseJsonBytes(json, ".lastDataPath"),
            safeVm.parseJsonBytes(json, ".firstChunkRaw"),
            safeVm.parseJsonBytes(json, ".lastChunkRaw")
        );
    }

    function coverAssemblySourceBytes(AssemblyInventory.Item calldata item)
        external
        returns (StreamBundleArchiveTypes.Proof memory)
    {
        require(msg.sender == address(this), "fixture-only exact original bytes");
        bytes32 digest = abi.decode(item.digest, (bytes32));
        bytes memory raw = publicationSourceBytes[digest];
        require(
            raw.length != 0 && keccak256(raw) == digest && raw.length < 262144,
            "exact independently retained single-leaf source bytes"
        );
        AxE.ObjectIdentity memory object;
        object.contentHash = digest;
        object.sha256Digest = sha256(raw);
        object.byteSize = uint64(raw.length);
        object.arweaveDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(object.sha256Digest)),
                sha256(abi.encode(uint256(raw.length)))
            )
        );
        bytes memory path = abi.encode(object.sha256Digest, uint256(raw.length));
        return _assemblyInventoryExternalProof(item, object, path, path, raw, raw);
    }

    function _assemblyCoverCompleteBundle(AssemblyInventory.Item[][] memory rows) internal {
        bytes32 id = assemblyRenderInventoryPlan;
        AssemblyInventory.Evidence memory e = assemblyRenderInventoryEvidence;
        // Exact original source preimages were retained immediately after materialization.
        StreamBundleArchiveTypes.Proof[][] memory proofs =
            new StreamBundleArchiveTypes.Proof[][](rows.length);
        uint256 emptyMembers;
        uint256 externalMembers;
        uint256 stateBundles;
        for (uint256 i; i < rows.length; ++i) {
            proofs[i] = new StreamBundleArchiveTypes.Proof[](rows[i].length);
            for (uint256 j; j < rows[i].length; ++j) {
                AssemblyInventory.Item memory item = rows[i][j];
                if (item.kind == AssemblyInventory.Kind.EMPTY_PACKAGE_MEMBER) {
                    ++emptyMembers;
                    StreamReferenceRenderTypes.PackageFile memory member = publicationReferencePublication.observation
                    .environment
                    .packageFiles[item.sourceIndex];
                    require(
                        member.byteSize == 0 && member.sha256Digest == sha256(bytes(""))
                            && keccak256(bytes(member.path)) == keccak256(bytes(item.uri)),
                        "original empty member identity"
                    );
                } else if (item.kind == AssemblyInventory.Kind.STATE_BUNDLE) {
                    ++stateBundles;
                } else if (
                    item.kind == AssemblyInventory.Kind.EXTERNAL_REFERENCE
                        && item.role == keccak256("RUNNABLE_PACKAGE_MEMBER")
                ) {
                    ++externalMembers;
                    proofs[i][j] = this.coverAssemblyPackageMember(item);
                } else if (item.kind == AssemblyInventory.Kind.EXTERNAL_OBJECT) {
                    proofs[i][j] = StreamBundleArchiveTypes.Proof(
                        1, item.originalCoverageHash, item.objectHash
                    );
                } else if (item.kind == AssemblyInventory.Kind.ONCHAIN_OBJECT) {
                    proofs[i][j] = StreamBundleArchiveTypes.Proof(
                        2, item.originalCoverageHash, item.objectHash
                    );
                } else if (
                    item.kind != AssemblyInventory.Kind.ABSENT
                        && item.kind != AssemblyInventory.Kind.EMPTY_BYTES
                        && item.kind != AssemblyInventory.Kind.NATIVE_OS_PREREQUISITE
                ) {
                    proofs[i][j] = this.coverAssemblySourceBytes(item);
                }
            }
        }
        require(
            emptyMembers + externalMembers
                    == publicationReferencePublication.observation.environment.packageFiles.length
                && stateBundles == 2,
            "complete original package and both actual original authorizations"
        );
        // Every receipt/fixity admission precedes this one frozen archive environment.
        publicationBundle.beginCoverage(id);
        uint256 processed;
        for (uint64 i; i < rows.length; ++i) {
            AssemblyInventory.Segment memory segment = publicationInventory.inventorySegment(id, i);
            bytes32[] memory next = new bytes32[](rows[i].length);
            bytes32 chain;
            for (uint256 j = rows[i].length; j > 0; --j) {
                next[j - 1] = chain;
                chain = StreamPreservationInventoryChains.link(
                    segment.key, segment.itemCount, uint64(j - 1), rows[i][j - 1], chain
                );
            }
            require(chain == segment.firstLink, "complete actual original segment witness");
            if (rows[i].length == 0) publicationBundle.coverEmptySegment(id);
            for (uint256 j; j < rows[i].length; ++j) {
                if (processed == 0) {
                    (bool ok,) = address(publicationBundle)
                        .call(
                            abi.encodeCall(
                                publicationBundle.coverNext,
                                (id, rows[i][j], next[j], StreamBundleArchiveTypes.Proof(0, 0, 0))
                            )
                        );
                    require(
                        !ok && publicationBundle.progress(id).itemCount == 0,
                        "actual nonempty source cannot skip coverage"
                    );
                }
                publicationBundle.coverNext(id, rows[i][j], next[j], proofs[i][j]);
                ++processed;
            }
        }
        require(
            processed == e.itemCount && publicationBundle.progress(id).complete,
            "every actual occurrence covered"
        );
        AssemblyInventory.BundleEvidence memory covered =
            publicationBundle.requireCoverage(id, e.renderCriticalEvidenceHash);
        require(
            covered.itemCount == e.itemCount && covered.bundleCoverageHash != 0
                && covered.bundleCoverageHash != e.renderCriticalEvidenceHash,
            "independent actual full bundle"
        );
        require(
            keccak256(abi.encode(publicationBundle.requireFullCurrentCoverage(id)))
                == keccak256(abi.encode(covered)),
            "complete original per-entry diagnostic agrees"
        );
        assemblyCompleteBundle = covered;
    }
}
