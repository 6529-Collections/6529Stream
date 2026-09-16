// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./PreservationActualInventoryFixture.sol";
import "./PreservationOnchainArchiveFixture.sol";
import {
    StreamBundleArchiveCoverage
} from "../../../smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol";
import {
    StreamBundleArchiveTypes as BundleT
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryChains as InventoryChains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamPreservationDocumentReads
} from "../../../smart-contracts/domains/preservation/StreamPreservationDocumentReads.sol";
import {
    IStreamSchemaDocumentFacts
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    StreamFinalityCoordinatorPolicyReads
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReads.sol";
import {
    StreamFinalityCoordinatorPolicyEvidence
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypes.sol";

interface PreservationBundleVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function computeCreateAddress(address, uint256) external returns (address);
    function getNonce(address) external returns (uint64);
}

/// @dev Actual all-eight inventory, complete 364-member browser package and both archive
/// backends. Native checkpoint/institution/fixity signatures are local fixture observations,
/// not public network delivery. Original Artist semantic owner boundaries remain as named
/// in PreservationActualInventoryFixture; current inventory reads are never mocked.
contract StreamPreservationBundleActualTest is
    PreservationActualInventoryFixture,
    PreservationOnchainArchiveFixture
{
    PreservationBundleVm private constant bundleVm =
        PreservationBundleVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamBundleArchiveCoverage private bundle;
    mapping(bytes32 => bytes) private sourceBytes;
    mapping(bytes32 => bytes32) private observedCoverages;
    bytes32 private leafArtifact;
    bytes32 private leafCoverage;

    struct Member {
        string path;
        uint64 byteSize;
        bytes32 contentHash;
        bytes32 sha256Digest;
        bytes32 dataRoot;
        bytes firstPath;
        bytes lastPath;
    }

    function _createArtifactCoverage() internal override returns (address) {
        _ocSetupArchive(address(core), address(executor), address(artist));
        address predicted = bundleVm.computeCreateAddress(
            address(this), uint256(bundleVm.getNonce(address(this))) + 3
        );
        return _ocDeployArtifact(address(schemas), address(store), predicted);
    }

    function _createArchiveRoles() internal override returns (StreamRoleRegistry) {
        return ocRoles;
    }

    function _leafReadGas() internal pure override returns (uint256) {
        // Actual ArtifactCoverage must forward its 500k dependency cap with
        // EIP-150 reserve and its own graph/read overhead inside this call.
        return 1000000;
    }

    function _ocBindArchiveRoles(address authority, address registry) internal override {
        cheat.mockCall(authority, abi.encodeWithSignature("roleRegistry()"), abi.encode(registry));
        cheat.mockCall(
            core.selected(keccak256("MODULE_REGISTRY")),
            abi.encodeWithSignature("governanceExecutor()"),
            abi.encode(authority)
        );
    }

    function _ocArtistId() internal view override returns (bytes32) {
        return artist.artistId();
    }

    function _extReceipt(bool first, uint256 nonce)
        internal
        override
        returns (E.Receipt memory r, bytes memory locator)
    {
        (r, locator) = super._extReceipt(first, nonce);
        if (!first) {
            locator = bytes(
                string.concat(
                    "https://institution.example.invalid/objects/sha256/",
                    Strings.toHexString(uint256(archiveObject.sha256Digest), 32)
                )
            );
            r.storageIdentifierHash = keccak256(locator);
            r.proofRecordHash = archiveHost.possessionHash(r);
        }
    }

    function _coverOriginalLeaf(bytes memory raw) internal override returns (bytes32, bytes32) {
        cheat.mockCall(
            address(artist),
            abi.encodeWithSignature("archivalCoverage()"),
            abi.encode(address(ocArchive))
        );
        (leafArtifact, leafCoverage) = _ocCover(
            raw,
            keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            keccak256("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1")
        );
        return (leafArtifact, leafCoverage);
    }

    function testCompleteActual547RoleBundleBothBackendsAndBoundedCurrent() public {
        (bytes32 id, InventoryT.Item[][] memory rows) = _materialize();
        InventoryT.Evidence memory e = renderInventory.requireCurrent(1);
        require(e.itemCount == 547 && e.segmentCount == 40, "complete original inventory");
        _retainSourceBytes(id);
        Member[] memory members = abi.decode(
            safeVm.parseJsonBytes(
                vm.readFile("test/fixtures/preservation/inventory-package-objects-v1.json"),
                ".membersABI"
            ),
            (Member[])
        );
        require(members.length == 364, "all original package members");
        BundleT.Proof[][] memory proofs = new BundleT.Proof[][](rows.length);
        uint256 emptyMembers;
        uint256 externalMembers;
        uint256 stateBundles;
        for (uint256 i; i < rows.length; ++i) {
            proofs[i] = new BundleT.Proof[](rows[i].length);
            for (uint256 j; j < rows[i].length; ++j) {
                InventoryT.Item memory item = rows[i][j];
                if (item.kind == InventoryT.Kind.EMPTY_PACKAGE_MEMBER) {
                    ++emptyMembers;
                    Member memory member = members[item.sourceIndex];
                    require(
                        member.byteSize == 0 && member.sha256Digest == sha256(bytes(""))
                            && keccak256(bytes(member.path)) == keccak256(bytes(item.uri)),
                        "original empty path and SHA"
                    );
                } else if (item.kind == InventoryT.Kind.STATE_BUNDLE) {
                    ++stateBundles;
                } else if (
                    item.kind == InventoryT.Kind.EXTERNAL_REFERENCE
                        && item.role == keccak256("RUNNABLE_PACKAGE_MEMBER")
                ) {
                    ++externalMembers;
                    Member memory member = members[item.sourceIndex];
                    require(
                        member.byteSize == item.byteSize
                            && keccak256(abi.encodePacked(member.sha256Digest))
                                == keccak256(item.digest)
                            && keccak256(bytes(member.path)) == keccak256(bytes(item.uri)),
                        "ordered uncompressed original member identity"
                    );
                    proofs[i][j] = _externalProof(
                        item,
                        member.contentHash,
                        member.sha256Digest,
                        member.dataRoot,
                        member.byteSize,
                        member.firstPath,
                        member.lastPath
                    );
                } else if (item.kind == InventoryT.Kind.EXTERNAL_OBJECT) {
                    proofs[i][j] = BundleT.Proof(1, item.originalCoverageHash, item.objectHash);
                } else if (item.kind == InventoryT.Kind.ONCHAIN_OBJECT) {
                    proofs[i][j] = BundleT.Proof(2, item.originalCoverageHash, item.objectHash);
                } else if (
                    item.kind != InventoryT.Kind.ABSENT && item.kind != InventoryT.Kind.EMPTY_BYTES
                        && item.kind != InventoryT.Kind.NATIVE_OS_PREREQUISITE
                ) {
                    bytes32 digest = abi.decode(item.digest, (bytes32));
                    bytes memory raw = sourceBytes[digest];
                    require(
                        raw.length != 0 && keccak256(raw) == digest,
                        "exact independently retained source bytes"
                    );
                    require(raw.length < 262144, "named single-native-leaf fixture capacity");
                    bytes32 sha = sha256(raw);
                    bytes32 nativeRoot = sha256(
                        abi.encodePacked(
                            sha256(abi.encodePacked(sha)), sha256(abi.encode(uint256(raw.length)))
                        )
                    );
                    bytes memory path = abi.encode(sha, uint256(raw.length));
                    proofs[i][j] = _externalProof(
                        item, digest, sha, nativeRoot, uint64(raw.length), path, path
                    );
                }
            }
        }
        require(
            emptyMembers == 3 && externalMembers == 361 && stateBundles == 2,
            "all package objects and both original authorizations"
        );
        BundleT.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(renderInventory),
            artifactTarget,
            address(archiveHost),
            address(artistArchive)
        ];
        for (uint256 i; i < 6; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.archiveGas = 2000000;
        bundle = new StreamBundleArchiveCoverage(d);
        bundle.beginCoverage(id);
        uint256 processed;
        for (uint64 i; i < rows.length; ++i) {
            InventoryT.Segment memory segment = renderInventory.inventorySegment(id, i);
            bytes32[] memory next = new bytes32[](rows[i].length);
            bytes32 chain;
            for (uint256 j = rows[i].length; j > 0; --j) {
                next[j - 1] = chain;
                chain = InventoryChains.link(
                    segment.key, segment.itemCount, uint64(j - 1), rows[i][j - 1], chain
                );
            }
            require(chain == segment.firstLink, "complete actual segment witness");
            if (rows[i].length == 0) bundle.coverEmptySegment(id);
            for (uint256 j; j < rows[i].length; ++j) {
                if (processed == 0) {
                    (bool ok,) = address(bundle)
                        .call(
                            abi.encodeCall(
                                bundle.coverNext, (id, rows[i][j], next[j], BundleT.Proof(0, 0, 0))
                            )
                        );
                    require(
                        !ok && bundle.progress(id).itemCount == 0,
                        "real nonempty source cannot claim no coverage"
                    );
                }
                bundle.coverNext(id, rows[i][j], next[j], proofs[i][j]);
                ++processed;
            }
        }
        require(processed == 547 && bundle.progress(id).complete, "no subset can finish");
        InventoryT.BundleEvidence memory covered =
            bundle.requireCoverage(id, e.renderCriticalEvidenceHash);
        require(
            covered.itemCount == 547 && covered.bundleCoverageHash != 0
                && covered.bundleCoverageHash != e.renderCriticalEvidenceHash,
            "independent bundle commitment"
        );
        require(
            covered.bundleCoverageHash != leafCoverage
                && covered.bundleCoverageHash != leafArtifact,
            "no leaf alias"
        );
        require(
            keccak256(abi.encode(bundle.requireFullCurrentCoverage(id)))
                == keccak256(abi.encode(covered)),
            "full original per-entry diagnostic agrees"
        );
        _boundedCurrent(id, e.renderCriticalEvidenceHash, covered);
        require(
            executeSafe(
                archiveAgentSafe,
                archiveAgentKeys,
                address(bundle),
                0,
                abi.encodeCall(bundle.requireCoverage, (id, e.renderCriticalEvidenceHash)),
                0
            ),
            "actual Safe current CALL"
        );
        vm.warp(block.timestamp + 1);
        _extRecordFixity(originalFirstReceipts[0], 1, false);
        (bool current,) = address(bundle)
            .staticcall(abi.encodeCall(bundle.requireCoverage, (id, e.renderCriticalEvidenceHash)));
        require(!current, "later original-pair fixity invalidates complete cache");
        require(
            keccak256(abi.encode(bundle.bundleEvidence(id))) == keccak256(abi.encode(covered)),
            "original complete bundle stays immutable"
        );
        bytes32 refresh = bundle.beginRefresh(id);
        bundle.refreshNext(id, 0);
        require(
            bundle.refresh(refresh).nextIndex == 1 && !bundle.refresh(refresh).complete,
            "no partial refresh success"
        );
        (current,) = address(bundle)
            .staticcall(abi.encodeCall(bundle.requireCoverage, (id, e.renderCriticalEvidenceHash)));
        require(!current);
        require(
            renderInventory.requireCurrent(1).renderCriticalEvidenceHash
                == e.renderCriticalEvidenceHash,
            "source original identity excludes routine passing fixity churn"
        );
        require(
            bundle.beginRefresh(id) == refresh && bundle.refresh(refresh).nextIndex == 1,
            "permissionless refresh cannot restart completed prefix"
        );
        for (uint64 i = 1; i < covered.itemCount; ++i) {
            bundle.refreshNext(id, i);
        }
        require(
            bundle.refresh(refresh).complete && bundle.refresh(refresh).nextIndex == 547,
            "all original entries refreshed under one environment"
        );
        require(
            keccak256(abi.encode(bundle.requireCoverage(id, e.renderCriticalEvidenceHash)))
                == keccak256(abi.encode(covered)),
            "complete current refresh preserves original bundle"
        );
        require(
            executeSafe(
                archiveAgentSafe,
                archiveAgentKeys,
                address(bundle),
                0,
                abi.encodeCall(bundle.requireCoverage, (id, e.renderCriticalEvidenceHash)),
                0
            ),
            "actual Safe current CALL after complete refresh"
        );
    }

    function _externalProof(
        InventoryT.Item memory item,
        bytes32 content,
        bytes32 sha,
        bytes32 root,
        uint64 size,
        bytes memory firstPath,
        bytes memory lastPath
    ) private returns (BundleT.Proof memory p) {
        archiveObject = E.ObjectIdentity(
            keccak256("artist"),
            item.schemaId != 0
                ? item.schemaId
                : keccak256("PRESERVATION_ORIGINAL_BYTES_DECLARATION"),
            item.canonicalizationId,
            content,
            sha,
            root,
            size,
            item.formatId != 0 ? item.formatId : keccak256("DECLARED_APPLICATION_OCTET_STREAM"),
            item.kind != InventoryT.Kind.REGISTERED_DOCUMENT && item.catalogId != 0
                ? item.catalogId
                : keccak256("PRESERVATION_BYTE_OBJECT_DECLARATION"),
            item.kind != InventoryT.Kind.REGISTERED_DOCUMENT && item.catalogHash != 0
                ? item.catalogHash
                : keccak256(
                    "declared object metadata; interpretation comes from actual original source"
                )
        );
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_OBJECT_V1"),
                block.chainid,
                address(archiveHost),
                address(core),
                archiveObject
            )
        );
        bytes32 covered = observedCoverages[hash];
        if (covered == 0) {
            require(archiveHost.recordObject(archiveObject) == hash, "exact whole external object");
            archiveObjectHash = hash;
            A.Checkpoint memory cp = _extCheckpointTerms();
            cp.transactionId = keccak256(abi.encode("local per-entry archival observation", hash));
            archiveTransactionId = cp.transactionId;
            archiveCheckpointHash = archiveVerifier.recordCheckpoint(
                cp,
                abi.encode(cp.dataRoot, uint256(cp.dataSize)),
                firstPath,
                lastPath,
                _extCertificate(cp)
            );
            bytes32 a = _extRecordReceipt(true, uint256(hash));
            bytes32 b = _extRecordReceipt(false, uint256(hash));
            _extRecordFixity(a, 1, false);
            _extRecordFixity(b, 1, false);
            covered = archiveHost.recordCoverage(a, b);
            observedCoverages[hash] = covered;
        }
        p = BundleT.Proof(1, covered, hash);
    }

    function _materialize() private returns (bytes32 id, InventoryT.Item[][] memory rows) {
        id = renderInventory.beginInventory(1);
        bundleVm.recordLogs();
        renderInventory.appendNative(id);
        renderInventory.appendReference(id);
        renderInventory.appendWork(id, selectedWork, address(0));
        renderInventory.appendRights(id, selectedRights);
        renderInventory.appendIntentWaiver(id, selectedWaiver, address(this));
        renderInventory.appendInterviewWaiver(id);
        renderInventory.appendRootAuthorization(id, address(this), 1000);
        for (uint256 i; i < 31; ++i) {
            renderInventory.appendDefinition(id);
        }
        renderInventory.appendToken(id, _originalTokenPayload(1));
        renderInventory.appendToken(id, _originalTokenPayload(2));
        PreservationBundleVm.Log[] memory logs = bundleVm.getRecordedLogs();
        rows = new InventoryT.Item[][](40);
        uint256 index;
        // During these stages only the fixed inventory emits logs; original getters are view.
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(renderInventory)) {
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == id
                        && uint256(logs[i].topics[2]) == index,
                    "original stage log identity/order"
                );
                (InventoryT.Segment memory segment, InventoryT.Item[] memory items) =
                    abi.decode(logs[i].data, (InventoryT.Segment, InventoryT.Item[]));
                require(
                    keccak256(abi.encode(segment))
                            == keccak256(
                                abi.encode(renderInventory.inventorySegment(id, uint64(index)))
                            ) && items.length == segment.itemCount,
                    "full source event bound to stored segment"
                );
                rows[index++] = items;
            }
        }
        require(index == 40, "all stages retained");
        renderInventory.sealInventory(id);
    }

    function _remember(bytes memory raw) private {
        if (raw.length != 0) sourceBytes[keccak256(raw)] = raw;
    }

    function _retainSourceBytes(bytes32 id) private {
        SourcesT.Context memory c = renderInventory.sourceContext(id);
        StreamSnapshotTypes.NativeFacts memory n =
            StreamSnapshotSourceReads.requireCurrent(_dependencies(), 1);
        _remember(bytes(n.source.script));
        _remember(bytes(n.source.name));
        _remember(bytes(n.source.description));
        _remember(bytes(n.source.imageURI));
        _remember(bytes(n.source.animationBaseURI));
        _remember(abi.encode(n));
        _remember(n.serving.renderer.code);
        _remember(address(router).code);
        _remember(address(core).code);
        _remember(snapshots.snapshotManifestBytes(c.snapshot.recordHash));
        _remember(abi.encode(n.contentRoot));
        _remember(abi.encode(n.leafManifest));
        StreamFinalityCoordinatorPolicyReads.Dependencies memory pd;
        pd.targets = [address(core), address(metadata), address(membership), address(coordinators)];
        for (uint256 i; i < 4; ++i) {
            pd.codeHashes[i] = pd.targets[i].codehash;
        }
        pd.chainId = block.chainid;
        pd.readGas = 500000;
        pd.inventoryGas = 3000000;
        StreamFinalityCoordinatorPolicyEvidence memory policies =
            StreamFinalityCoordinatorPolicyReads.requireCurrent(
                pd, _scope(), c.snapshot.inventoryPlan
            );
        _remember(abi.encode(policies));
        for (uint256 i; i < policies.policies.length; ++i) {
            _remember(policies.policies[i].coordinator.code);
            _remember(abi.encode(policies.policies[i]));
        }
        _remember(referenceHost.referencePayload(c.referenceRender.recordHash));
        _remember(abi.encode(terms.environment));
        for (uint256 i; i < terms.captures.length; ++i) {
            _remember(abi.encode(terms.captures[i]));
        }
        bytes32[3] memory originals = [workRecord, rightsRecord, waiverRecord];
        for (uint256 i; i < 3; ++i) {
            (
                IStreamPreservationRecords.CollectionRecord memory r,
                IStreamCollectionMetadataV1.RecordReceipt memory receipt
            ) = metadata.collectionRecord(originals[i]);
            _remember(abi.encode(r, receipt));
            (, bytes memory payload) = metadata.recordPayload(originals[i]);
            _remember(payload);
        }
        _remember(bytes(selectedWaiver.waiverStatement.uri));
        _remember(bytes(selectedWaiver.interview.waiverStatement.uri));
        for (uint64 i; i < 31; ++i) {
            bytes32 document = i < 30
                ? StreamPreservationDocumentReads.fixedId(i)
                : keccak256("STREAM_REFERENCE_RENDERER_CLASS_FIXTURE_V1");
            IStreamSchemaDocumentFacts.DocumentFacts memory f = schemas.documentFacts(document);
            bytes memory raw;
            for (uint256 j; j < f.chunkCount; ++j) {
                raw = bytes.concat(raw, store.readChunk(schemas.documentChunkHashAt(document, j)));
            }
            _remember(raw);
        }
        for (uint256 i = 1; i <= 2; ++i) {
            _remember(core.tokenData(i));
            _remember(bytes(router.historicalTokenMetadataJSON(address(core), i)));
            _remember(_originalTokenPayload(i).animation);
        }
    }

    function _boundedCurrent(
        bytes32 id,
        bytes32 evidenceHash,
        InventoryT.BundleEvidence memory expected
    ) private {
        bytes memory input = abi.encodeCall(bundle.requireCoverage, (id, evidenceHash));
        address[9] memory targets = [
            address(bundle),
            address(renderInventory),
            artifactTarget,
            address(ocArchive),
            address(archiveHost),
            address(archiveVerifier),
            address(core),
            address(finality),
            address(artist)
        ];
        for (uint256 i; i < targets.length; ++i) {
            safeVm.cool(targets[i]);
        }
        uint256 before_ = gasleft();
        (bool ok, bytes memory raw) = address(bundle).staticcall{ gas: 3000000 }(input);
        uint256 used = before_ - gasleft();
        require(
            ok && raw.length == 160 && keccak256(raw) == keccak256(abi.encode(expected)),
            "exact bounded current five words"
        );
        emit log_named_uint("full547Named9ColdBundleCurrent", used);
    }
}
