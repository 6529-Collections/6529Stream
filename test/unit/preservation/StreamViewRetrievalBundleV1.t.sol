// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewRetrievalWitnessFixture.sol";
import {
    StreamViewPreservationBundleArchiveCoverageV1 as Bundle
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    StreamViewPreservationRenderCriticalInventoryV1 as ActualInventory
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as VRC
} from "../../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as Snapshot
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamPreservationInventoryTypes as P
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationInventoryItems as Items
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamViewRetrievalObligationV1 as Obligation
} from "../../../smart-contracts/domains/preservation/StreamViewRetrievalObligationV1.sol";
import {
    StreamViewRetrievalConsumerV1 as Consumer
} from "../../../smart-contracts/domains/preservation/StreamViewRetrievalConsumerV1.sol";
import {
    IStreamViewRetrievalInventoryBindingV1 as Companion
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamViewRetrievalInventoryBindingV1.sol";
import {
    IStreamViewPreservationRenderCriticalInventoryV1 as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    StreamMetadataSubjects as Subjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamViewPreservationMediaCorrespondenceV1 as OriginalMedia
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationMediaCorrespondenceV1.sol";

contract RetrievalSnapshotBoundary {
    Snapshot.Dependencies private _d;

    constructor(Snapshot.Dependencies memory d) {
        _d = d;
    }

    function dependencies() external view returns (Snapshot.Dependencies memory) {
        return _d;
    }
}

contract RetrievalEnvironmentBoundary {
    function currentArtifactEnvironment() external pure returns (bytes32, uint64) {
        return (keccak256("typed unchanged artifact environment"), 1);
    }
}

/// @dev Inventory admission/selection remains an explicit typed boundary; actual satellite,
/// Archive, signatures, carrier bytes and Bundle state machine are composed below.
contract RetrievalInventoryBoundary {
    S.Dependencies private _d;
    VRC.Evidence private _e;
    VRC.Context private _c;
    P.Segment private _s;
    address private immutable _w;
    bytes32 private immutable _pin;
    bool public closed = true;

    constructor(S.Dependencies memory d, address w) {
        _d = d;
        _w = w;
        _pin = w.codehash;
    }

    function dependencies() external view returns (S.Dependencies memory) {
        return _d;
    }

    function dependencyHash() external view returns (bytes32) {
        return keccak256(abi.encode(_d));
    }

    function core() external view returns (address) {
        return _d.targets[0];
    }

    function metadataHost() external view returns (address) {
        return _d.targets[1];
    }

    function artifactCoverage() external view returns (address) {
        return _d.targets[10];
    }

    function externalCoverage() external view returns (address) {
        return _d.targets[11];
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return closed && (id == type(Companion).interfaceId || id == type(Inventory).interfaceId);
    }

    function inventoryProfile() external view returns (bytes32) {
        return closed ? VRC.PROFILE : keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_V1");
    }

    function retrievalWitnessBinding() external view returns (address, bytes32) {
        return (_w, _pin);
    }

    function configure(VRC.Context memory c, VRC.Evidence memory e, P.Segment memory s) external {
        _c = c;
        _e = e;
        _s = s;
    }

    function setClosed(bool v) external {
        closed = v;
    }

    function sourceContext(bytes32) external view returns (VRC.Context memory) {
        return _c;
    }

    function inventoryEvidence(bytes32 id) external view returns (VRC.Evidence memory) {
        require(id == _e.inventory.planId);
        return _e;
    }

    function inventorySegment(bytes32 id, uint64 index) external view returns (P.Segment memory) {
        require(id == _e.inventory.planId && index == 0);
        return _s;
    }
}

contract RetrievalConsumerProbe {
    function admit(B.Dependencies memory d, VRC.Context memory c, P.Item memory item, bytes32 h)
        external
        view
        returns (B.Admission memory, bytes32)
    {
        return Consumer.admit(d, c, item, h);
    }
}

contract StreamViewRetrievalBundleV1Test is ViewRetrievalWitnessFixture {
    Bundle private bundle;
    RetrievalInventoryBoundary private inventory;
    RetrievalConsumerProbe private consumer;
    S.Dependencies private sourceDeps;
    B.Dependencies private deps;
    VRC.Context private context;
    VRC.Evidence private evidence;
    P.Segment private segment;
    P.Item private row;
    bytes32 private plan;
    bytes32 private retrieval;

    function setUp() public {
        _setUpRetrieval();
        retrieval = _publish(_request(41));
        (T.Source memory s,,) = witness.requireCorrespondence(retrieval);
        row = Obligation.item(s);
        require(row.role == T.ROLE);
        RetrievalEnvironmentBoundary onchain = new RetrievalEnvironmentBoundary();
        Snapshot.Dependencies memory sd;
        sd.targets[0] = address(core);
        sd.codeHashes[0] = address(core).codehash;
        sd.targets[4] = address(router);
        sd.codeHashes[4] = address(router).codehash;
        sd.targets[6] = address(checkpoint);
        sd.codeHashes[6] = address(checkpoint).codehash;
        sd.chainId = configuration.chainId;
        RetrievalSnapshotBoundary snap = new RetrievalSnapshotBoundary(sd);
        for (uint256 i; i < 12; ++i) {
            sourceDeps.targets[i] = address(checkpoint);
            sourceDeps.codeHashes[i] = address(checkpoint).codehash;
        }
        sourceDeps.targets[0] = address(core);
        sourceDeps.targets[1] = address(agentSafe);
        sourceDeps.targets[4] = address(router);
        sourceDeps.targets[5] = address(snap);
        sourceDeps.targets[10] = address(onchain);
        sourceDeps.targets[11] = address(host);
        for (uint256 i; i < 12; ++i) {
            sourceDeps.codeHashes[i] = sourceDeps.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            sourceDeps.artistTargets[i] = address(fixitySafe);
            sourceDeps.artistCodeHashes[i] = address(fixitySafe).codehash;
        }
        sourceDeps.artistContentOwner = address(agentSafe);
        sourceDeps.artistContentOwnerCodeHash = address(agentSafe).codehash;
        sourceDeps.chainId = configuration.chainId;
        sourceDeps.readGas = 300000;
        sourceDeps.sourceGas = 2000000;
        sourceDeps.selectionGas = 300000;
        sourceDeps.snapshotGas = 2000000;
        sourceDeps.referenceGas = 2000000;
        inventory = new RetrievalInventoryBoundary(sourceDeps, address(witness));
        consumer = new RetrievalConsumerProbe();
        deps.targets = [
            address(core),
            address(agentSafe),
            address(inventory),
            address(onchain),
            address(host),
            address(fixitySafe)
        ];
        for (uint256 i; i < 6; ++i) {
            deps.codeHashes[i] = deps.targets[i].codehash;
        }
        deps.chainId = configuration.chainId;
        deps.readGas = 300000;
        deps.archiveGas = 8000000;
        bundle = new Bundle(deps);
        _configure(s, row);
    }

    function _configure(T.Source memory s, P.Item memory item) private {
        context.scope = s.scope;
        context.artistId = object.artistId;
        context.adoptionRecord = s.adoptionRecord;
        context.payloadHash = s.payloadHash;
        context.sourceContextHash = s.checkpointContextHash;
        context.tokenCount = 1;
        plan = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_PLAN_V1"),
                deps.chainId,
                address(inventory),
                inventory.dependencyHash(),
                context
            )
        );
        P.Item[] memory rows = new P.Item[](1);
        rows[0] = item;
        segment = Chains.segment(
            keccak256("complete typed one-item segment"), keccak256("typed source witness"), rows
        );
        evidence.scope = context.scope;
        evidence.inventory.planId = plan;
        evidence.inventory.collectionId = context.scope.collectionId;
        evidence.inventory.scopeSubject =
            Subjects.scopeSubject(deps.chainId, address(core), context.scope);
        evidence.inventory.artistId = object.artistId;
        evidence.inventory.sourceContextHash = keccak256(abi.encode(context));
        evidence.inventory.tokenInventoryHash = keccak256("complete typed selected token inventory");
        evidence.inventory.tokenCount = 1;
        evidence.inventory.segmentCount = 1;
        evidence.inventory.itemCount = 1;
        evidence.inventory.segmentChainHash = Chains.append(0, 0, segment);
        evidence.inventory.renderCriticalEvidenceHash = 0;
        evidence.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_EVIDENCE_V1"),
                deps.chainId,
                address(inventory),
                inventory.dependencyHash(),
                evidence
            )
        );
        inventory.configure(context, evidence, segment);
    }

    function _complete() private returns (bytes32 hash) {
        bundle.beginCoverage(plan);
        bundle.coverRetrievalNext(plan, row, 0, retrieval);
        hash =
        bundle.requireCoverage(scope, plan, evidence.inventory.renderCriticalEvidenceHash).coverage
            .bundleCoverageHash;
    }

    function testActualBundleRetainsExplicitWitnessAndExactOriginalAdmission() public {
        bytes32 complete = _complete();
        require(bundle.retrievalWitnessForItem(plan, 0) == retrieval && complete != 0);
        (P.Item memory stored, B.Admission memory admitted) = bundle.admittedItem(plan, 0);
        require(keccak256(abi.encode(stored)) == keccak256(abi.encode(row)));
        (T.Source memory s, T.Receipt memory receipt, B.Admission memory original) =
            witness.requireCorrespondence(retrieval);
        require(s.adoptionRecord == context.adoptionRecord);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_RETRIEVAL_ADMITTED_BUNDLE_V1"),
                original.originalBundleHash,
                address(witness),
                address(witness).codehash,
                witness.configurationHash(),
                retrieval,
                receipt.payloadHash
            )
        );
        require(
            admitted.originalBundleHash == expected && admitted.proof.objectHash == objectHash
                && admitted.proof.coverageHash == completeCoverage
        );
        require(bundle.requireFullCurrentCoverage(plan).coverage.bundleCoverageHash == complete);
    }

    function testGenericProofCannotBypassWitnessAndEarlyRefusalPreservesSameIndex() public {
        bundle.beginCoverage(plan);
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        bundle.coverNext(plan, row, 0, B.Proof(1, completeCoverage, objectHash));
        _status(firstFamily, 2);
        rv.expectRevert();
        bundle.coverRetrievalNext(plan, row, 0, retrieval);
        require(
            bundle.progress(plan).itemCount == 0 && bundle.retrievalWitnessForItem(plan, 0) == 0
        );
        _status(firstFamily, 1);
        bundle.coverRetrievalNext(plan, row, 0, retrieval);
        bundle.requireFullCurrentCoverage(plan);
    }

    function testCompleteScopeArtistPayloadAndLocatorCoordinatesAreMandatory() public {
        VRC.Context memory changed = context;
        changed.artistId = keccak256("different actual Artist");
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        consumer.admit(deps, changed, row, retrieval);
        changed = context;
        changed.scope.scopeId = bytes32(uint256(9));
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        consumer.admit(deps, changed, row, retrieval);
        changed = context;
        changed.payloadHash = keccak256("different full payload");
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        consumer.admit(deps, changed, row, retrieval);
        P.Item memory other = row;
        other.uri = "https://other.invalid/";
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        consumer.admit(deps, context, other, retrieval);
        consumer.admit(deps, context, row, retrieval);
    }

    function testHistoricalInventoryContextCannotBeRelabeledUnderSamePlan() public {
        bundle.beginCoverage(plan);
        VRC.Context memory original = context;
        context.adoptionRecord = keccak256("substituted head");
        inventory.configure(context, evidence, segment);
        rv.expectRevert(abi.encodeWithSelector(T.InvalidViewRetrieval.selector));
        bundle.coverRetrievalNext(plan, row, 0, retrieval);
        require(bundle.progress(plan).itemCount == 0);
        context = original;
        inventory.configure(context, evidence, segment);
        bundle.coverRetrievalNext(plan, row, 0, retrieval);
    }

    function testSameScopeRevocationInvalidatesBoundedRefreshButOtherScopeDoesNot() public {
        bytes32 complete = _complete();
        C.Source memory original = selected;
        StreamFinalityScope memory originalScope = scope;
        scope.scopeId = bytes32(uint256(88));
        selected.adoption.input.scope = scope;
        selected.adoption.recordHash = keccak256("another scope");
        checkpoint.set(selected);
        bytes32 other = _publish(_request(42));
        vm.prank(safeVm.addr(SECOND_AGENT));
        witness.revoke(other, keccak256("unrelated scope withdrawal"));
        scope = originalScope;
        selected = original;
        checkpoint.set(selected);
        require(
            bundle.requireCoverage(scope, plan, evidence.inventory.renderCriticalEvidenceHash)
                .coverage.bundleCoverageHash == complete
        );
        bundle.requireFullCurrentCoverage(plan);
        bytes memory historical = witness.encoded(retrieval);
        vm.prank(safeVm.addr(SECOND_AGENT));
        witness.revoke(retrieval, keccak256("same scope withdrawal"));
        rv.expectRevert(abi.encodeWithSelector(P.InventoryIncomplete.selector));
        bundle.requireCoverage(scope, plan, evidence.inventory.renderCriticalEvidenceHash);
        bundle.beginRefresh(plan);
        rv.expectRevert();
        bundle.refreshNext(plan, 0);
        require(
            bundle.bundleEvidence(plan).coverage.bundleCoverageHash == complete
                && keccak256(witness.encoded(retrieval)) == keccak256(historical)
        );
    }

    function testArchiveRefreshAndSourceCurrentnessRemainDistinctAndRestore() public {
        bytes32 complete = _complete();
        _status(firstFamily, 2);
        rv.expectRevert();
        bundle.requireFullCurrentCoverage(plan);
        _status(firstFamily, 1);
        bytes32 key = bundle.beginRefresh(plan);
        bundle.refreshNext(plan, 0);
        require(bundle.refresh(key).complete);
        require(
            bundle.requireCoverage(scope, plan, evidence.inventory.renderCriticalEvidenceHash)
                .coverage.bundleCoverageHash == complete
        );
        C.Source memory original = selected;
        selected.contextHash = keccak256("fresh source drift");
        checkpoint.set(selected);
        rv.expectRevert();
        bundle.requireFullCurrentCoverage(plan);
        // Bounded archive currentness explicitly does not assert inventory/source currentness.
        require(
            bundle.requireCoverage(scope, plan, evidence.inventory.renderCriticalEvidenceHash)
                .coverage.bundleCoverageHash == complete
        );
        selected = original;
        checkpoint.set(selected);
        bundle.requireFullCurrentCoverage(plan);
    }

    function testOrdinaryHttpsOriginKeepsOldRowAndCanUseExplicitFreshWitness() public {
        string memory uri = "https://origin.example.invalid/ordinary.png";
        _setURI(uri);
        T.Request memory q = _request(43);
        q.steps[0].fromURI = uri;
        retrieval = _publish(q);
        (T.Source memory s,,) = witness.requireCorrespondence(retrieval);
        row = Obligation.item(s);
        P.Item memory old = OriginalMedia.item(s.declaration, s.declarationRecord, uri);
        require(
            row.role == keccak256("VIEW_ARCHIVE_LOCATOR_IMAGE")
                && keccak256(abi.encode(row)) == keccak256(abi.encode(old))
        );
        _configure(s, row);
        bundle.beginCoverage(plan);
        rv.expectRevert();
        bundle.coverNext(plan, row, 0, B.Proof(1, completeCoverage, objectHash));
        bundle.coverRetrievalNext(plan, row, 0, retrieval);
        bundle.requireFullCurrentCoverage(plan);
    }

    function testActualInventoryConstructorPinsCompanionAndOldProfileCannotPretendSupport() public {
        ActualInventory actual =
            new ActualInventory(sourceDeps, address(witness), address(witness).codehash);
        (address target, bytes32 hash) = actual.retrievalWitnessBinding();
        require(
            target == address(witness) && hash == address(witness).codehash
                && actual.dependencyHash() == keccak256(abi.encode(sourceDeps))
                && actual.inventoryProfile()
                    == keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1")
        );
        inventory.setClosed(false);
        rv.expectRevert();
        bundle.beginCoverage(plan);
        inventory.setClosed(true);
        _complete();
    }

    function _twoRows() private returns (P.Item memory absent, bytes32 next) {
        absent = Items.absent(
            keccak256("explicit second occurrence absent"),
            address(inventory),
            keccak256("second source"),
            0
        );
        P.Item[] memory both = new P.Item[](2);
        both[0] = row;
        both[1] = absent;
        segment = Chains.segment(
            keccak256("two rows for partial progress"), keccak256("complete typed source"), both
        );
        next = Chains.link(segment.key, 2, 1, absent, 0);
        evidence.inventory.itemCount = 2;
        evidence.inventory.segmentChainHash = Chains.append(0, 0, segment);
        evidence.inventory.renderCriticalEvidenceHash = 0;
        evidence.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_EVIDENCE_V1"),
                deps.chainId,
                address(inventory),
                inventory.dependencyHash(),
                evidence
            )
        );
        inventory.configure(context, evidence, segment);
    }

    function testRevocationMidCoverCannotCreateFreshCompletedRefresh() public {
        (P.Item memory absent, bytes32 next) = _twoRows();
        bundle.beginCoverage(plan);
        bundle.coverRetrievalNext(plan, row, next, retrieval);
        require(bundle.progress(plan).itemCount == 1);
        vm.prank(safeVm.addr(SECOND_AGENT));
        witness.revoke(retrieval, keccak256("withdraw between rows"));
        bundle.coverNext(plan, absent, 0, B.Proof(0, 0, 0));
        require(bundle.progress(plan).complete && bundle.progress(plan).environmentHash == 0);
        rv.expectRevert(abi.encodeWithSelector(P.InventoryIncomplete.selector));
        bundle.requireCoverage(scope, plan, evidence.inventory.renderCriticalEvidenceHash);
        bundle.beginRefresh(plan);
        rv.expectRevert();
        bundle.refreshNext(plan, 0);
        require(bundle.retrievalWitnessForItem(plan, 0) == retrieval);
    }

    function testRevocationMidRefreshCannotReuseEarlierScopeEpochProgress() public {
        (P.Item memory absent, bytes32 next) = _twoRows();
        bundle.beginCoverage(plan);
        bundle.coverRetrievalNext(plan, row, next, retrieval);
        bundle.coverNext(plan, absent, 0, B.Proof(0, 0, 0));
        bundle.requireCoverage(scope, plan, evidence.inventory.renderCriticalEvidenceHash);
        _status(firstFamily, 2);
        _status(firstFamily, 1);
        bytes32 originalRefresh = bundle.beginRefresh(plan);
        bundle.refreshNext(plan, 0);
        require(
            bundle.refresh(originalRefresh).nextIndex == 1
                && !bundle.refresh(originalRefresh).complete
        );
        vm.prank(safeVm.addr(SECOND_AGENT));
        witness.revoke(retrieval, keccak256("withdraw during refresh"));
        rv.expectRevert(abi.encodeWithSelector(P.InventoryIncomplete.selector));
        bundle.refreshNext(plan, 1);
        bytes32 currentRefresh = bundle.beginRefresh(plan);
        require(currentRefresh != originalRefresh && bundle.refresh(currentRefresh).nextIndex == 0);
        rv.expectRevert();
        bundle.refreshNext(plan, 0);
        rv.expectRevert(abi.encodeWithSelector(P.InventoryIncomplete.selector));
        bundle.requireCoverage(scope, plan, evidence.inventory.renderCriticalEvidenceHash);
    }

    function testFinalSegmentFailureRollsBackWitnessMapItemsAndExactRetry() public {
        bundle.beginCoverage(plan);
        bytes32 beforeProgress = keccak256(abi.encode(bundle.progress(plan)));
        P.Segment memory changed = segment;
        changed.sourceWitnessHash = keccak256("wrong final source witness but same item link");
        inventory.configure(context, evidence, changed);
        rv.expectRevert(abi.encodeWithSelector(P.InventoryIncomplete.selector));
        bundle.coverRetrievalNext(plan, row, 0, retrieval);
        require(
            bundle.retrievalWitnessForItem(plan, 0) == 0
                && keccak256(abi.encode(bundle.progress(plan))) == beforeProgress
        );
        inventory.configure(context, evidence, segment);
        bundle.coverRetrievalNext(plan, row, 0, retrieval);
        require(bundle.retrievalWitnessForItem(plan, 0) == retrieval);
        bundle.requireFullCurrentCoverage(plan);
    }
}
