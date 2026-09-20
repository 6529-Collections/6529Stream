// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { ScopedBundleArchiveFixture } from "../../helpers/ScopedBundleArchiveFixture.sol";
import {
    StreamScopedPolicyBundleArchiveCoverageV2
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyBundleArchiveCoverageV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyBundleArchiveTypesV2 as PB
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyBundleArchiveTypesV2.sol";
import {
    IStreamScopedPolicyRenderCriticalInventoryV2 as IV2
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyRenderCriticalInventoryV2.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamPreservationInventoryItems as Items
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol";

/// @dev Explicit complete-V2-inventory boundary; archive observations, original byte proofs and Safes are real.
/// No complete inventory materialization or finality acceptance is claimed by this component host.
contract ScopedPolicyBundleInventoryBoundaryV2 {
    address public core;
    address public metadataHost;
    address public artifactCoverage;
    address public externalCoverage;
    bytes32 public dependencyHash = keccak256("typed scoped source configuration");
    Scoped.Evidence private evidence;
    T.Segment[] private segments;

    constructor(address c, address m, address a, address x) {
        core = c;
        metadataHost = m;
        artifactCoverage = a;
        externalCoverage = x;
    }

    bool public admittedProfile = true;

    function setProfile(bool value) external {
        admittedProfile = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IV2).interfaceId;
    }

    function scopedPolicyInventoryProfile() external view returns (bytes32) {
        return admittedProfile ? Scoped.PROFILE : keccak256("6529STREAM_SCOPED_RENDER_CRITICAL_V1");
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

contract ScopedPolicyBundleEnvironmentBoundaryV2 {
    uint64 public epoch = 1;

    function currentArtifactEnvironment() external view returns (bytes32, uint64) {
        return (keccak256("typed whole byte environment"), epoch);
    }

    function advance() external {
        ++epoch;
    }
}

contract StreamScopedPolicyBundleArchiveCoverageV2Test is ScopedBundleArchiveFixture {
    StreamScopedPolicyBundleArchiveCoverageV2 private bundle;
    ScopedPolicyBundleInventoryBoundaryV2 private inventory;
    ScopedPolicyBundleEnvironmentBoundaryV2 private onchain;
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
        onchain = new ScopedPolicyBundleEnvironmentBoundaryV2();
        inventory = new ScopedPolicyBundleInventoryBoundaryV2(
            address(core), address(agentSafe), address(onchain), address(host)
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
        bundle = new StreamScopedPolicyBundleArchiveCoverageV2(d);
        scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 37, 0);
        planId = keccak256("typed original TOKEN plan");
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
                keccak256("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_EVIDENCE_V2"),
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

    function _complete() private returns (PB.BundleEvidence memory) {
        bundle.beginCoverage(planId);
        _next(0);
        _next(1);
        bundle.coverEmptySegment(planId);
        _next(2);
        _next(3);
        return bundle.requireCoverage(scope, planId, renderHash);
    }

    function testFullScopedCoveragePreservesActualOriginalBytesAndSeparateDomain() public {
        PB.BundleEvidence memory e = _complete();
        require(
            e.scope.tokenId == 37 && e.coverage.itemCount == 4 && e.coverage.bundleCoverageHash != 0
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
                        keccak256("6529STREAM_SCOPED_POLICY_BUNDLE_ARCHIVE_COVERAGE_V2"),
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
        source.scope.tokenId = 38;
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
        changed.tokenId = 38;
        _fails(
            address(bundle), abi.encodeCall(bundle.requireCoverage, (changed, planId, renderHash))
        );
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (scope, planId, bytes32(0))));
        require(bundle.bundleEvidence(planId).scope.tokenId == 37);
    }

    function testReleaseAndSeasonAreDistinctAndCollectionViewAreRefused() public {
        source.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        source.inventory.scopeSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, address(core), source.scope);
        _saveSource();
        _fails(address(bundle), abi.encodeCall(bundle.beginCoverage, (planId)));
        source.scope = StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, keccak256("view"));
        source.inventory.scopeSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, address(core), source.scope);
        _saveSource();
        _fails(address(bundle), abi.encodeCall(bundle.beginCoverage, (planId)));
        source.scope =
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, keccak256("release"));
        scope = source.scope;
        source.inventory.scopeSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, address(core), scope);
        _saveSource();
        PB.BundleEvidence memory e = _complete();
        StreamFinalityScope memory season = scope;
        season.scopeType = StreamFinalityScopeType.SEASON;
        _fails(
            address(bundle), abi.encodeCall(bundle.requireCoverage, (season, planId, renderHash))
        );
        require(e.scope.scopeType == StreamFinalityScopeType.RELEASE);
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

    function testNewBundleRejectsV1ProfileAndEvidenceDomainBeforeProgress() public {
        inventory.setProfile(false);
        _fails(address(bundle), abi.encodeCall(bundle.beginCoverage, (planId)));
        require(bundle.progress(planId).segmentIndex == 0 && bundle.progress(planId).itemCount == 0);
        inventory.setProfile(true);
        source.inventory.renderCriticalEvidenceHash = 0;
        source.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_RENDER_CRITICAL_EVIDENCE_V1"),
                block.chainid,
                address(inventory),
                inventory.dependencyHash(),
                source
            )
        );
        inventory.configure(source, segments);
        _fails(address(bundle), abi.encodeCall(bundle.beginCoverage, (planId)));
        _saveSource();
        PB.BundleEvidence memory result = _complete();
        require(
            abi.encode(result).length == 288
                && bundle.scopedPolicyBundleArchiveProfile() == PB.PROFILE
        );
    }
}
