// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewRetrievalConfigurationFixture.sol";
import "../../helpers/ScopedBundleArchiveFixture.sol";
import "../../../smart-contracts/domains/preservation/StreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    StreamPreservationInventoryItems as Items
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol";

/// @dev Explicit VIEW inventory boundary; original actual archive observations, native proofs and Safes.
/// No source/adoption/current inventory authority is fabricated by this archival test boundary.
contract ViewBundleInventoryBoundary {
    address public core;
    address public metadataHost;
    address public artifactCoverage;
    address public externalCoverage;
    bytes32 public dependencyHash;
    RetrievalInventoryTypes.Dependencies private configured;
    address private witness;
    Scoped.Evidence private evidence;
    T.Segment[] private segments;

    constructor(address c, address m, address a, address x, address artistArchive) {
        core = c;
        metadataHost = m;
        artifactCoverage = a;
        externalCoverage = x;
        configured.targets[0] = c;
        configured.targets[1] = m;
        configured.targets[4] = address(new ViewRetrievalConfigurationBoundary());
        configured.targets[5] = address(new ViewRetrievalConfigurationBoundary());
        configured.targets[10] = a;
        configured.targets[11] = x;
        for (uint256 i; i < 12; ++i) {
            configured.codeHashes[i] = configured.targets[i].codehash;
        }
        configured.artistTargets[4] = artistArchive;
        configured.artistCodeHashes[4] = artistArchive.codehash;
        configured.chainId = block.chainid;
        dependencyHash = keccak256(abi.encode(configured));
        witness = ViewRetrievalConfigurationFixture.configure(configured, false);
    }

    function dependencies() external view returns (RetrievalInventoryTypes.Dependencies memory) {
        return configured;
    }

    function retrievalWitnessBinding() external view returns (address, bytes32) {
        return (witness, witness.codehash);
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(RetrievalCompanionInterface).interfaceId;
    }

    function inventoryProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1");
    }

    function configure(Scoped.Evidence memory e, T.Segment[] memory s) external {
        evidence = e;
        delete segments;
        for (uint256 i; i < s.length; ++i) {
            segments.push(s[i]);
        }
    }

    function inventoryEvidence(bytes32 id) external view returns (Scoped.Evidence memory) {
        require(id == evidence.inventory.planId);
        return evidence;
    }

    function inventorySegment(bytes32 id, uint64 index) external view returns (T.Segment memory) {
        require(id == evidence.inventory.planId);
        return segments[index];
    }
}

contract ViewBundleEnvironmentBoundary {
    uint64 public epoch = 1;

    function currentArtifactEnvironment() external view returns (bytes32, uint64) {
        return (keccak256("typed whole byte environment"), epoch);
    }

    function advance() external {
        ++epoch;
    }
}

contract StreamViewPreservationBundleArchiveCoverageV1Test is ScopedBundleArchiveFixture {
    StreamViewPreservationBundleArchiveCoverageV1 private bundle;
    ViewBundleInventoryBoundary private inventory;
    ViewBundleEnvironmentBoundary private onchain;
    T.Item[] private rows;
    bytes32[] private suffix;
    T.Segment[] private segments;
    Scoped.Evidence private source;
    StreamFinalityScope private scope;
    bytes32 private planId;
    bytes32 private renderHash;
    bytes32 private originalCoverage;
    bytes32 private firstReceipt;
    bytes32 private secondReceipt;

    function setUp() public {
        _setupArchive();
        (firstReceipt, secondReceipt, originalCoverage) = _covered();
        onchain = new ViewBundleEnvironmentBoundary();
        inventory = new ViewBundleInventoryBoundary(
            address(core), address(agentSafe), address(onchain), address(host), address(fixitySafe)
        );
        B.Dependencies memory d;
        d.targets = [
            address(core),
            address(agentSafe),
            address(inventory),
            address(onchain),
            address(host),
            address(fixitySafe)
        ];
        for (uint256 i; i < 6; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.archiveGas = 3000000;
        bundle = new StreamViewPreservationBundleArchiveCoverageV1(d);
        scope = StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 1, 0, keccak256("sealed view membership")
        );
        planId = keccak256("typed original VIEW plan");
        T.Item memory row;
        row.kind = T.Kind.EXTERNAL_OBJECT;
        row.role = keccak256("FIRST_SOURCE_ROLE");
        row.source = address(inventory);
        row.sourceRecord = keccak256("original scoped reference");
        row.algorithm = 1;
        row.canonicalizationId = object.canonicalizationId;
        row.digest = abi.encodePacked(object.contentHash);
        row.byteSize = object.byteSize;
        row.schemaId = object.schemaId;
        row.formatId = object.formatId;
        row.catalogId = object.formatCatalogId;
        row.catalogHash = object.formatCatalogHash;
        row.objectHash = objectHash;
        row.originalCoverageHash = originalCoverage;
        rows.push(row);
        row.role = keccak256("SECOND_DISTINCT_ROLE_SAME_BYTES");
        rows.push(row);
        rows.push(
            Items.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("EMPTY_FIELD"),
                address(core),
                keccak256("source"),
                0,
                bytes("")
            )
        );
        rows.push(Items.absent(keccak256("ABSENT_FIELD"), address(core), keccak256("source"), 0));
        T.Item[] memory pair = new T.Item[](2);
        pair[0] = rows[0];
        pair[1] = rows[1];
        segments.push(Chains.segment(keccak256("scoped first"), keccak256("first witness"), pair));
        suffix.push(Chains.link(segments[0].key, 2, 1, rows[1], 0));
        suffix.push(0);
        T.Item[] memory empty = new T.Item[](0);
        segments.push(
            Chains.segment(keccak256("explicit empty middle"), keccak256("empty witness"), empty)
        );
        pair[0] = rows[2];
        pair[1] = rows[3];
        segments.push(Chains.segment(keccak256("scoped last"), keccak256("last witness"), pair));
        suffix.push(Chains.link(segments[2].key, 2, 1, rows[3], 0));
        suffix.push(0);
        source.scope = scope;
        T.Evidence memory e;
        e.planId = planId;
        e.collectionId = 1;
        e.scopeSubject = StreamMetadataSubjects.scopeSubject(block.chainid, address(core), scope);
        e.artistId = object.artistId;
        e.sourceContextHash = keccak256("exact typed current context");
        e.tokenInventoryHash = keccak256("complete one-token membership");
        e.tokenCount = 1;
        e.segmentCount = 3;
        e.itemCount = 4;
        for (uint64 i; i < 3; ++i) {
            e.segmentChainHash = Chains.append(e.segmentChainHash, i, segments[i]);
        }
        source.inventory = e;
        _saveSource();
    }

    function _saveSource() private {
        source.inventory.renderCriticalEvidenceHash = 0;
        renderHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_EVIDENCE_V1"),
                block.chainid,
                address(inventory),
                inventory.dependencyHash(),
                source
            )
        );
        source.inventory.renderCriticalEvidenceHash = renderHash;
        inventory.configure(source, segments);
    }

    function _proof(uint256 i) private view returns (B.Proof memory) {
        return i < 2 ? B.Proof(1, originalCoverage, objectHash) : B.Proof(0, 0, 0);
    }

    function _next(uint256 i) private {
        bundle.coverNext(planId, rows[i], suffix[i], _proof(i));
    }

    function _complete() private returns (Scoped.BundleEvidence memory) {
        bundle.beginCoverage(planId);
        _next(0);
        _next(1);
        bundle.coverEmptySegment(planId);
        _next(2);
        _next(3);
        return bundle.requireCoverage(scope, planId, renderHash);
    }

    function testFullViewCoveragePreservesActualOriginalBytesAndSeparateDomain() public {
        Scoped.BundleEvidence memory e = _complete();
        require(
            e.scope.scopeId == keccak256("sealed view membership") && e.coverage.itemCount == 4
                && e.coverage.bundleCoverageHash != 0
        );
        (, B.Admission memory first) = bundle.admittedItem(planId, 0);
        (, B.Admission memory repeated) = bundle.admittedItem(planId, 1);
        require(
            first.externalOriginal.firstReceiptHash == firstReceipt
                && first.externalOriginal.secondReceiptHash == secondReceipt
        );
        require(repeated.externalOriginal.coverageHash == originalCoverage);
        bytes32 saved = e.coverage.bundleCoverageHash;
        e.coverage.bundleCoverageHash = 0;
        require(
            saved
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_BUNDLE_ARCHIVE_COVERAGE_V1"),
                        block.chainid,
                        address(bundle),
                        bundle.dependencyHash(),
                        bundle.PROFILE(),
                        source,
                        e
                    )
                )
        );
        require(
            saved
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_BUNDLE_ARCHIVE_COVERAGE_V1"),
                        block.chainid,
                        address(bundle),
                        bundle.dependencyHash(),
                        bundle.PROFILE(),
                        source.inventory,
                        e.coverage
                    )
                )
        );
        require(bundle.requireFullCurrentCoverage(planId).coverage.bundleCoverageHash == saved);
    }

    function testScopeIdentityAndInventoryHashCannotBeSubstituted() public {
        source.scope.scopeId = keccak256("foreign view membership");
        inventory.configure(source, segments);
        _fails(address(bundle), abi.encodeCall(bundle.beginCoverage, (planId)));
        require(bundle.progress(planId).itemCount == 0);
        source.scope = scope;
        source.inventory.renderCriticalEvidenceHash =
            keccak256("collection-shaped or arbitrary hash");
        inventory.configure(source, segments);
        _fails(address(bundle), abi.encodeCall(bundle.beginCoverage, (planId)));
        _saveSource();
        _complete();
        StreamFinalityScope memory changed = scope;
        changed.scopeId = keccak256("foreign view membership");
        _fails(
            address(bundle), abi.encodeCall(bundle.requireCoverage, (changed, planId, renderHash))
        );
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (scope, planId, bytes32(0))));
        require(bundle.bundleEvidence(planId).scope.scopeId == keccak256("sealed view membership"));
    }

    function testOtherScopeKindsCannotReuseViewInventoryAndViewMembershipIsDistinct() public {
        for (uint8 kind; kind < 4; ++kind) {
            source.scope = StreamFinalityScope(
                StreamFinalityScopeType(kind),
                1,
                kind == 1 ? 37 : 0,
                kind > 1 ? keccak256("sealed view membership") : bytes32(0)
            );
            source.inventory.scopeSubject =
                StreamMetadataSubjects.scopeSubject(block.chainid, address(core), source.scope);
            _saveSource();
            _fails(address(bundle), abi.encodeCall(bundle.beginCoverage, (planId)));
        }
        source.scope = scope;
        source.inventory.scopeSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, address(core), scope);
        _saveSource();
        Scoped.BundleEvidence memory e = _complete();
        StreamFinalityScope memory other = StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 1, 0, keccak256("other complete membership")
        );
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (other, planId, renderHash)));
        require(
            e.scope.scopeType == StreamFinalityScopeType.VIEW && e.scope.scopeId == scope.scopeId
        );
    }

    function testNoOmissionReorderOrEmptySegmentSkipAndLateCountRollback() public {
        source.inventory.itemCount = 3;
        _saveSource();
        bundle.beginCoverage(planId);
        _fails(
            address(bundle),
            abi.encodeCall(bundle.coverNext, (planId, rows[1], suffix[0], _proof(0)))
        );
        _fails(address(bundle), abi.encodeCall(bundle.coverEmptySegment, (planId)));
        _next(0);
        _next(1);
        _fails(
            address(bundle),
            abi.encodeCall(bundle.coverNext, (planId, rows[2], suffix[2], _proof(2)))
        );
        bundle.coverEmptySegment(planId);
        _next(2);
        _fails(
            address(bundle),
            abi.encodeCall(bundle.coverNext, (planId, rows[3], suffix[3], _proof(3)))
        );
        require(bundle.progress(planId).itemCount == 3 && !bundle.progress(planId).complete);
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (scope, planId, renderHash)));
    }

    function testActualCurrentFixityRequiresCompleteFreshRefreshAndKeepsHistory() public {
        bytes32 saved = _complete().coverage.bundleCoverageHash;
        _recordFixity(firstReceipt, 2, false);
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (scope, planId, renderHash)));
        bundle.beginRefresh(planId);
        _fails(address(bundle), abi.encodeCall(bundle.refreshNext, (planId, uint64(0))));
        _recordFixity(firstReceipt, 1, true);
        bytes32 key = bundle.beginRefresh(planId);
        bundle.refreshNext(planId, 0);
        require(bundle.beginRefresh(planId) == key && bundle.refresh(key).nextIndex == 1);
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (scope, planId, renderHash)));
        for (uint64 i = 1; i < 4; ++i) {
            bundle.refreshNext(planId, i);
        }
        require(
            bundle.requireCoverage(scope, planId, renderHash).coverage.bundleCoverageHash == saved
        );
        onchain.advance();
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (scope, planId, renderHash)));
        require(bundle.bundleEvidence(planId).coverage.bundleCoverageHash == saved);
    }

    function testExactSignedSafeCallRollsBackOnArchiveStatusThenRetries() public {
        bundle.beginCoverage(planId);
        bytes memory input =
            abi.encodeCall(bundle.coverNext, (planId, rows[0], suffix[0], _proof(0)));
        uint256 nonce = agentSafe.nonce();
        bytes32 digest = agentSafe.getTransactionHash(
            address(bundle), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(agentKeys, digest);
        bytes memory saved = abi.encodeCall(
            agentSafe.execTransaction,
            (address(bundle), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures)
        );
        _status(firstFamily, 2);
        (bool ok, bytes memory reason) = address(agentSafe).call(saved);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
        );
        require(agentSafe.nonce() == nonce && bundle.progress(planId).itemCount == 0);
        _status(firstFamily, 1);
        (ok, reason) = address(agentSafe).call(saved);
        require(
            ok && abi.decode(reason, (bool)) && agentSafe.nonce() == nonce + 1
                && bundle.progress(planId).itemCount == 1
        );
        _next(1);
        bundle.coverEmptySegment(planId);
        _next(2);
        _next(3);
        bundle.requireCoverage(scope, planId, renderHash);
    }

    /// @dev Original actual fixture archive bytes, never represented as a VIEW publication.
    /// The separate output projection oracle authenticates actual VIEW schema/payload rows.
    function _firstPayload(T.Item memory item) private {
        rows[0] = item;
        T.Item[] memory pair = new T.Item[](2);
        pair[0] = rows[0];
        pair[1] = rows[1];
        segments[0] = Chains.segment(keccak256("scoped first"), keccak256("first witness"), pair);
        suffix[0] = Chains.link(segments[0].key, 2, 1, rows[1], 0);
        source.inventory.segmentChainHash = 0;
        for (uint64 i; i < 3; ++i) {
            source.inventory.segmentChainHash =
                Chains.append(source.inventory.segmentChainHash, i, segments[i]);
        }
        _saveSource();
    }

    function testOriginalPayloadWholeRawBytesUsesActualArchiveWithoutWideningCanonicalizations()
        public
    {
        bytes32 oldCoverage = originalCoverage;
        T.Item memory row = rows[0];
        row.kind = T.Kind.ORIGINAL_PAYLOAD;
        row.role = keccak256("ACTUAL_FIXTURE_WHOLE_PAYLOAD");
        _firstPayload(row);
        bundle.beginCoverage(planId);
        (bool ok, bytes memory error) = address(bundle)
            .call(abi.encodeCall(bundle.coverNext, (planId, rows[0], suffix[0], _proof(0))));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(
                            T.UnsupportedInventoryCorrespondence.selector,
                            uint8(1),
                            keccak256("BINARY_EXACT_V1")
                        )
                    ),
            "arbitrary declared ABI/binary profile remains unsupported"
        );
        require(bundle.progress(planId).itemCount == 0, "failed correspondence rolled back");
        // Register the same independently observed bytes under literal RAW_BYTES, then create
        // genuine fresh signed receipt/fixity/coverage records for that distinct object.
        object.canonicalizationId = keccak256("RAW_BYTES");
        objectHash = host.recordObject(object);
        firstReceipt = _recordReceipt(true, 1);
        secondReceipt = _recordReceipt(false, 1);
        _recordFixity(firstReceipt, 1, false);
        _recordFixity(secondReceipt, 1, false);
        originalCoverage = host.recordCoverage(firstReceipt, secondReceipt);
        require(originalCoverage != oldCoverage, "new genuine object/coverage identity");
        // A new immutable plan is necessary because the first plan bound the prior exact rows.
        planId = keccak256("raw whole-payload correspondence plan");
        source.inventory.planId = planId;
        row.canonicalizationId = keccak256("RAW_BYTES");
        row.objectHash = objectHash;
        row.originalCoverageHash = originalCoverage;
        rows[1].canonicalizationId = row.canonicalizationId;
        rows[1].objectHash = objectHash;
        rows[1].originalCoverageHash = originalCoverage;
        _firstPayload(row);
        _complete();
        (T.Item memory saved, B.Admission memory admission) = bundle.admittedItem(planId, 0);
        require(
            saved.kind == T.Kind.ORIGINAL_PAYLOAD && saved.byteSize == object.byteSize
                && saved.canonicalizationId == keccak256("RAW_BYTES")
                && saved.schemaId == object.schemaId,
            "exact whole bytes/schema correspondence"
        );
        require(
            keccak256(saved.digest) == keccak256(abi.encodePacked(object.contentHash))
                && admission.externalOriginal.coverageHash == originalCoverage,
            "literal digest and genuine current archive proof"
        );
    }
}
