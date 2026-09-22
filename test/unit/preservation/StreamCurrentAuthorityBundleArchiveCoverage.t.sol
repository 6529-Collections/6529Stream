// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../finality/StreamCurrentAuthorityConfiguration.t.sol";
import {
    StreamCurrentAuthorityBundleArchiveCoverage
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityBundleArchiveCoverage.sol";
import {
    StreamCurrentAuthorityScopedBundleArchiveCoverage
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedBundleArchiveCoverage.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";

/// @dev Actual coverage progress/cache with an ABSENT item isolates the newly added authority
/// capture/seal boundary. Genuine multi-origin byte admission is covered in its unchanged reader tests.
contract StreamCurrentAuthorityBundleArchiveCoverageTest is CurrentAuthorityConsumerFixture {
    StreamCurrentAuthorityBundleArchiveCoverage private coverage;
    T.Evidence private evidence;
    T.Item private item;
    T.Segment private segment;
    bytes32 private originRoot;

    function setUp() public override {
        super.setUp();
        coverage = new StreamCurrentAuthorityBundleArchiveCoverage(bd, od, ad, D.INVENTORY_PROFILE);
        item.kind = T.Kind.ABSENT;
        item.role = keccak256("absent field");
        item.source = c.targets[0];
        item.sourceRecord = keccak256("authenticated absence");
        T.Item[] memory items = new T.Item[](1);
        items[0] = item;
        segment = Chains.segment(keccak256("segment"), keccak256("witness"), items);
        evidence.planId = PLAN;
        evidence.artistId = keccak256("artist");
        evidence.collectionId = 1;
        evidence.scopeSubject = keccak256("collection subject");
        evidence.sourceContextHash = keccak256("captured typed context");
        evidence.tokenCount = 1;
        evidence.tokenInventoryHash = keccak256("token inventory");
        evidence.segmentCount = 1;
        evidence.itemCount = 1;
        evidence.segmentChainHash = Chains.append(0, 0, segment);
        table.set(
            abi.encodeWithSignature("currentArtifactEnvironment()"),
            abi.encode(keccak256("artifact"), uint64(1))
        );
        table.set(
            abi.encodeWithSignature("currentExternalArtifactEnvironment()"),
            abi.encode(keccak256("external"), uint64(1))
        );
        inventory.set(
            abi.encodeWithSignature("inventorySegment(bytes32,uint64)", PLAN, uint64(0)),
            abi.encode(segment)
        );
        originRoot = O.sealedOriginSetHash(1, O.appendOrigin(0, 0, captured.selection.origin));
        inventory.set(abi.encodeWithSignature("originCount(bytes32)", PLAN), abi.encode(uint256(1)));
        inventory.set(
            abi.encodeWithSignature("originSetHash(bytes32)", PLAN), abi.encode(originRoot)
        );
        inventory.set(
            abi.encodeWithSignature("originAt(bytes32,uint256)", PLAN, uint256(0)),
            abi.encode(captured.selection.origin)
        );
        _seal(captured.selection.selectionHash);
    }

    function _seal(bytes32 selectionHash) private {
        evidence.renderCriticalEvidenceHash = 0;
        evidence.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                D.INVENTORY_PROFILE,
                block.chainid,
                address(inventory),
                c.inventoryDependencyHash,
                selectionHash,
                evidence,
                originRoot,
                uint256(1)
            )
        );
        inventory.set(
            abi.encodeWithSignature("inventoryEvidence(bytes32)", PLAN), abi.encode(evidence)
        );
    }

    function _complete() private returns (T.BundleEvidence memory) {
        coverage.beginCoverage(PLAN);
        coverage.coverNext(PLAN, item, 0, B.Proof(0, 0, 0));
        return coverage.requireCoverage(PLAN, evidence.renderCriticalEvidenceHash);
    }

    function _fails(address target, bytes memory input) private {
        (bool ok,) = target.call(input);
        require(!ok, "authority boundary must fail closed");
    }

    function testCurrentCaptureSupportsAdmissionCacheAndFullDiagnostic() public {
        T.BundleEvidence memory result = _complete();
        require(result.itemCount == 1 && result.bundleCoverageHash != 0);
        require(
            coverage.requireFullCurrentCoverage(PLAN).bundleCoverageHash
                == result.bundleCoverageHash
        );
        require(coverage.authorityDependencies().resolver == address(resolver));
        require(coverage.dependencies().targets[5] == sd.artistTargets[4]);
    }

    function testLaterSelectionCannotReuseAdmissionCacheRefreshOrFullDiagnostic() public {
        _complete();
        _select(address(new FinalityMultiOriginReadTable()));
        _fails(
            address(coverage),
            abi.encodeCall(coverage.requireCoverage, (PLAN, evidence.renderCriticalEvidenceHash))
        );
        _fails(address(coverage), abi.encodeCall(coverage.beginRefresh, (PLAN)));
        _fails(address(coverage), abi.encodeCall(coverage.requireFullCurrentCoverage, (PLAN)));
    }

    function testSelectionChangeDuringAdmissionDoesNotAdvanceProgress() public {
        coverage.beginCoverage(PLAN);
        _select(address(new FinalityMultiOriginReadTable()));
        _fails(
            address(coverage),
            abi.encodeCall(coverage.coverNext, (PLAN, item, bytes32(0), B.Proof(0, 0, 0)))
        );
        require(coverage.progress(PLAN).itemCount == 0);
    }

    function testSealMustContainExactCapturedSelection() public {
        _seal(keccak256("other selection"));
        _fails(address(coverage), abi.encodeCall(coverage.beginCoverage, (PLAN)));
        _seal(captured.selection.selectionHash);
        require(_complete().bundleCoverageHash != 0);
    }

    function testArtifactEpochStillRequiresRefreshUnderSameCurrentAuthority() public {
        T.BundleEvidence memory result = _complete();
        table.set(
            abi.encodeWithSignature("currentArtifactEnvironment()"),
            abi.encode(keccak256("artifact"), uint64(2))
        );
        _fails(
            address(coverage),
            abi.encodeCall(coverage.requireCoverage, (PLAN, evidence.renderCriticalEvidenceHash))
        );
        bytes32 refreshId = coverage.beginRefresh(PLAN);
        coverage.refreshNext(PLAN, 0);
        require(coverage.refresh(refreshId).complete);
        require(
            coverage.requireCoverage(PLAN, evidence.renderCriticalEvidenceHash).bundleCoverageHash
                == result.bundleCoverageHash
        );
    }

    function deployScopedForTest(B.Dependencies memory depend) external returns (address) {
        return address(new StreamCurrentAuthorityScopedBundleArchiveCoverage(
            depend, od, ad, D.SCOPED_POLICY_INVENTORY_PROFILE
        ));
    }

    function testScopedConstructorRejectsEachMissingDependencyIncludingLast() public {
        for (uint256 i; i < 6; ++i) {
            address originalTarget = bd.targets[i];
            bytes32 originalHash = bd.codeHashes[i];
            bd.targets[i] = address(0);
            _fails(address(this), abi.encodeCall(this.deployScopedForTest, (bd)));
            bd.targets[i] = originalTarget;
            bd.codeHashes[i] = 0;
            _fails(address(this), abi.encodeCall(this.deployScopedForTest, (bd)));
            bd.codeHashes[i] = originalHash;
        }
        StreamCurrentAuthorityScopedBundleArchiveCoverage scoped =
            new StreamCurrentAuthorityScopedBundleArchiveCoverage(
                bd, od, ad, D.SCOPED_POLICY_INVENTORY_PROFILE
            );
        require(scoped.INVENTORY_PROFILE() == D.SCOPED_POLICY_INVENTORY_PROFILE);
        require(keccak256(abi.encode(scoped.dependencies())) == keccak256(abi.encode(bd)));
    }

    function testScopedProfileRequiresFullScopeAndCurrentSelectionSeal() public {
        _publishCurrent(D.SCOPED_INVENTORY_PROFILE);
        StreamCurrentAuthorityScopedBundleArchiveCoverage scoped = new StreamCurrentAuthorityScopedBundleArchiveCoverage(
            bd, od, ad, D.SCOPED_INVENTORY_PROFILE
        );
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 42, 0);
        evidence.scopeSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, bd.targets[0], scope);
        evidence.renderCriticalEvidenceHash = 0;
        Scoped.Evidence memory full = Scoped.Evidence(scope, evidence);
        full.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                D.SCOPED_INVENTORY_PROFILE,
                block.chainid,
                address(inventory),
                c.inventoryDependencyHash,
                captured.selection.selectionHash,
                full,
                originRoot,
                uint256(1)
            )
        );
        inventory.set(abi.encodeWithSignature("inventoryEvidence(bytes32)", PLAN), abi.encode(full));
        scoped.beginCoverage(PLAN);
        scoped.coverNext(PLAN, item, 0, B.Proof(0, 0, 0));
        Scoped.BundleEvidence memory result =
            scoped.requireCoverage(scope, PLAN, full.inventory.renderCriticalEvidenceHash);
        require(result.coverage.bundleCoverageHash != 0);
        require(
            scoped.requireFullCurrentCoverage(PLAN).coverage.bundleCoverageHash
                == result.coverage.bundleCoverageHash,
            "full diagnostic checks the admitted item"
        );
        StreamFinalityScope memory wrong = scope;
        wrong.tokenId += 1;
        _fails(
            address(scoped),
            abi.encodeCall(
                scoped.requireCoverage, (wrong, PLAN, full.inventory.renderCriticalEvidenceHash)
            )
        );
        _select(address(new FinalityMultiOriginReadTable()));
        _fails(
            address(scoped), abi.encodeCall(scoped.requireFullCurrentCoverage, (PLAN))
        );
        _fails(
            address(scoped),
            abi.encodeCall(
                scoped.requireCoverage, (scope, PLAN, full.inventory.renderCriticalEvidenceHash)
            )
        );
    }
}
