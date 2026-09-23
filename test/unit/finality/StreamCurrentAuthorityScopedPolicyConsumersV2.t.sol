// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedPolicyRenderCriticalInventoryV2 as LegacyInventoryI
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyRenderCriticalInventoryV2.sol";

import "./StreamCurrentAuthorityConfiguration.t.sol";
import {
    StreamFinalityScopedPolicyProviderReadsV2 as P
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyProviderReadsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyProviderReadsV2 as Reads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyProviderReadsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyProviderOperationsV2 as Operations
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyProviderOperationsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicySanctionReviewV2 as Review
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicySanctionReviewV2.sol";
import {
    IStreamMultiOriginScopedPolicyRenderCriticalInventoryV2 as InventoryI
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamMultiOriginScopedPolicyRenderCriticalInventoryV2.sol";
import {
    IStreamCurrentAuthorityInventory as AuthorityInventoryI
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    IStreamScopedBundleArchiveCoverage as BundleI
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedBundleArchiveCoverage.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as ScopedPolicy
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedRenderCriticalTypes as CoverageTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamPreservationInventoryTypes as InventoryTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedFinalityInputManifestTypes as Manifest
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedFinalityInputManifestTypes.sol";
import {
    IStreamFinalitySanctionReview as Sanction
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as OutputsI
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as CheckpointI
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as SnapshotI
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as SnapshotTypes
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedPolicyReferencePublicationV2 as ReferenceI
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as ReferenceTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as FactoryI
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as SourceSetI
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamMetadataSubjects as Subjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";

/// @dev Config is caller-supplied only in this probe; production hosts store the constructor
/// catalogue and derive scopedPolicy Config exclusively from their fixed genuine factory.
contract CurrentAuthorityScopedPolicyConsumerProbeV2 {
    function pins(P.Config memory c) external view {
        Reads.requirePins(c);
    }

    function legacyPins(P.Config memory c) external view {
        P.requirePins(c);
    }

    function statement(P.Config memory c, StreamFinalityScope memory scope)
        external
        view
        returns (Manifest.Statement memory)
    {
        return Reads.statement(c, scope, new StreamFinalityComponentExpectation[](0));
    }

    function prepared(P.Config memory c, StreamFinalityScope memory scope) external view {
        Operations.prepared(
            c, scope, bytes32(uint256(1)), new StreamFinalityComponentExpectation[](0), false
        );
    }

    function review(P.Config memory c, Manifest.Statement memory s)
        external
        view
        returns (Sanction.ReviewFacts memory)
    {
        return Review.review(c, s);
    }

    function independent(StreamFinalityComponentExpectation[] calldata rows)
        external
        pure
        returns (StreamFinalityComponentExpectation[] memory)
    {
        return Reads.independentComponents(rows);
    }
}

/// @notice Actual new configuration/selection/projection and scopedPolicy consumer workers.
/// @dev Resolver, source dependencies, inventory completion and coverage are typed read-table
/// boundaries. These cases do not assert genuine publication, Archive, signature or Finality
/// execution; original scopedPolicy publication/header tests and the composed fixture are separate.
contract StreamCurrentAuthorityScopedPolicyConsumersV2Test is CurrentAuthorityConsumerFixture {
    CurrentAuthorityScopedPolicyConsumerProbeV2 private probe;
    FinalityMultiOriginReadTable private sourceSet;
    StreamFinalityScope private scope;

    function setUp() public override {
        super.setUp();
        probe = new CurrentAuthorityScopedPolicyConsumerProbeV2();
        uint256[8] memory distinct = [uint256(6), 7, 8, 9, 10, 12, 13, 14];
        for (uint256 i; i < distinct.length; ++i) {
            uint256 slot = distinct[i];
            c.targets[slot] = address(new FinalityMultiOriginReadTable());
            c.codeHashes[slot] = c.targets[slot].codehash;
        }
        uint256[12] memory indexes = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            sd.targets[i] = c.targets[indexes[i]];
            sd.codeHashes[i] = c.codeHashes[indexes[i]];
        }
        anchors.targets[4] = address(probe);
        anchors.codeHashes[4] = address(probe).codehash;
        anchors.finalityRegistry = c.targets[12];
        resolver.set(abi.encodeCall(Resolver.anchors, ()), abi.encode(anchors));
        _select(address(new FinalityMultiOriginReadTable()));
        _publishCurrent(D.SCOPED_POLICY_INVENTORY_PROFILE);
        _sourceBindings();
        _lateBindings();
        scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 7, 9, 0);
    }

    function _sourceBindings() private {
        _profile(
            6,
            type(OutputsI).interfaceId,
            "scopedOutputProfile()",
            keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
        );
        _profile(
            7,
            type(CheckpointI).interfaceId,
            "scopedPolicyProfile()",
            keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
        );
        _profile(
            8,
            type(SnapshotI).interfaceId,
            "scopedPolicySnapshotProfile()",
            keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2")
        );
        _profile(
            9,
            type(ReferenceI).interfaceId,
            "scopedPolicyReferenceProfile()",
            keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_V2")
        );
        _profile(
            10,
            type(FactoryI).interfaceId,
            "scopedPolicyFactoryProfile()",
            keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        );
        _profile(
            18,
            type(InventoryI).interfaceId,
            "scopedPolicyInventoryProfile()",
            D.SCOPED_POLICY_INVENTORY_PROFILE
        );
        _support(c.targets[18], type(AuthorityInventoryI).interfaceId);
        _set(
            18,
            abi.encodeCall(IERC165.supportsInterface, (type(LegacyInventoryI).interfaceId)),
            abi.encode(false)
        );
        _addr(6, "core()", 0);
        _addr(6, "contentCheckpoint()", 7);
        _addr(6, "artifactCoverage()", 20);
        _addr(7, "core()", 0);
        _addr(7, "metadataRouter()", 2);
        _addr(7, "sourceFactory()", 10);
        _addr(18, "snapshots()", 8);
        _addr(18, "referencePublisher()", 9);
        sourceSet = new FinalityMultiOriginReadTable();
        _support(address(sourceSet), type(SourceSetI).interfaceId);
        sourceSet.set(
            abi.encodeWithSignature("SOURCE_SET_PROFILE()"),
            abi.encode(keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"))
        );
        sourceSet.set(abi.encodeCall(SourceSetI.factory, ()), abi.encode(c.targets[10]));
        sourceSet.set(abi.encodeWithSignature("core()"), abi.encode(c.targets[0]));
        SnapshotTypes.Dependencies memory snap;
        uint256[10] memory slots = [uint256(0), 1, 4, 5, 2, 3, 3, 7, 6, 20];
        for (uint256 i; i < 10; ++i) {
            snap.targets[i] = c.targets[slots[i]];
            snap.codeHashes[i] = c.codeHashes[slots[i]];
        }
        snap.targets[10] = address(sourceSet);
        snap.codeHashes[10] = address(sourceSet).codehash;
        snap.chainId = c.chainId;
        snap.readGas = c.readGas;
        snap.sourceGas = c.sourceGas;
        snap.inventoryGas = c.componentSourceGas;
        _set(8, abi.encodeCall(SnapshotI.dependencies, ()), abi.encode(snap));
        _addr(7, "selectionCheckpoint()", 3);
        _set(7, abi.encodeWithSignature("entropySourceSet()"), abi.encode(address(sourceSet)));
        Policies.Dependencies memory policies;
        uint256[4] memory pi = [uint256(0), 1, 3, 10];
        for (uint256 i; i < 4; ++i) {
            policies.targets[i] = c.targets[pi[i]];
            policies.codeHashes[i] = c.codeHashes[pi[i]];
        }
        policies.chainId = c.chainId;
        policies.readGas = uint32(c.readGas);
        policies.inventoryGas = uint32(c.sourceGas);
        _set(10, abi.encodeCall(FactoryI.dependencies, ()), abi.encode(policies));
        _set(
            7,
            abi.encodeWithSignature("factoryDependenciesHash()"),
            abi.encode(keccak256(abi.encode(policies)))
        );
        _set(7, abi.encodeWithSignature("sourceFactoryCodeHash()"), abi.encode(c.codeHashes[10]));
        ReferenceTypes.Dependencies memory reference_;
        uint256[7] memory ri = [uint256(0), 1, 4, 5, 2, 8, 21];
        for (uint256 i; i < 7; ++i) {
            reference_.targets[i] = c.targets[ri[i]];
            reference_.codeHashes[i] = c.codeHashes[ri[i]];
        }
        reference_.chainId = c.chainId;
        reference_.readGas = c.readGas;
        reference_.sourceGas = c.sourceGas;
        reference_.snapshotGas = c.sourceGas;
        reference_.archiveGas = c.sourceGas;
        _set(9, abi.encodeCall(ReferenceI.dependencies, ()), abi.encode(reference_));
    }

    function _lateBindings() private {
        _addr(19, "core()", 0);
        _addr(19, "metadataHost()", 1);
        _addr(19, "renderCriticalInventory()", 18);
        _addr(19, "artifactCoverage()", 20);
        _addr(19, "externalCoverage()", 21);
        _addr(14, "core()", 0);
        _addr(14, "collectionMetadata()", 1);
        _addr(12, "coreReads()", 0);
        _addr(12, "metadataReads()", 1);
        _addr(12, "coreFinalityAdapter()", 14);
        _addr(13, "core()", 0);
        _addr(13, "metadataHost()", 1);
        _set(12, abi.encodeWithSignature("scopeEvidenceProvider()"), abi.encode(address(probe)));
        _set(13, abi.encodeWithSignature("scopeEvidenceProvider()"), abi.encode(address(probe)));
        _set(14, abi.encodeWithSignature("evidenceProvider()"), abi.encode(address(probe)));
    }

    function _profile(uint256 i, bytes4 id, string memory getter, bytes32 profile) private {
        _support(c.targets[i], id);
        _set(i, abi.encodeWithSignature(getter), abi.encode(profile));
    }

    function _set(uint256 i, bytes memory input, bytes memory output) private {
        FinalityMultiOriginReadTable(c.targets[i]).set(input, output);
    }

    function _addr(uint256 from, string memory getter, uint256 to) private {
        _set(from, abi.encodeWithSignature(getter), abi.encode(c.targets[to]));
    }

    function _config() private view returns (P.Config memory) {
        return abi.decode(abi.encode(c), (P.Config));
    }

    function _rejectConsumer(bytes memory input, bytes4 selector) private {
        (bool ok, bytes memory result) = address(probe).call(input);
        require(!ok && result.length >= 4 && bytes4(result) == selector, "exact consumer rejection");
    }

    function _evidence(StreamFinalityScope memory actual)
        private
        view
        returns (ScopedPolicy.Evidence memory e)
    {
        e.scope = actual;
        e.inventory.planId = PLAN;
        e.inventory.collectionId = actual.collectionId;
        e.inventory.scopeSubject = Subjects.scopeSubject(c.chainId, c.targets[0], actual);
        e.inventory.artistId = keccak256("artist");
        e.inventory.sourceContextHash = keccak256("context");
        e.inventory.tokenInventoryHash = keccak256("membership");
        e.inventory.tokenCount = 1;
        e.inventory.segmentCount = 1;
        e.inventory.itemCount = 1;
        e.inventory.segmentChainHash = keccak256("segments");
        e.inventory.renderCriticalEvidenceHash = keccak256("completed inventory boundary");
    }

    function testExactCurrentScopedPolicyConfigurationAdmitsAndLegacyProfileRejects() public {
        probe.pins(_config());
        _rejectConsumer(
            abi.encodeCall(probe.legacyPins, (_config())), P.NativeProviderDependency.selector
        );
    }

    function testUnplannedSuccessorProjectsCurrentPinsWithoutChangingOriginalConfiguration()
        public
    {
        bytes32 fixedHash = c.inventoryDependencyHash;
        address original = sd.artistTargets[0];
        _select(address(new FinalityMultiOriginReadTable()));
        probe.pins(_config());
        require(c.inventoryDependencyHash == fixedHash && sd.artistTargets[0] == original);
        require(captured.dependencies.artistTargets[0] != original);
    }

    function testOtherThreeAuthorityInventoryProfilesCannotAliasScopedPolicy() public {
        bytes32[3] memory profiles =
            [D.INVENTORY_PROFILE, D.SCOPED_INVENTORY_PROFILE, D.POLICY_INVENTORY_PROFILE];
        for (uint256 i; i < 3; ++i) {
            _publishCurrent(profiles[i]);
            _rejectConsumer(
                abi.encodeCall(probe.pins, (_config())),
                CurrentConfiguration.InvalidFinalityArchiveConfiguration.selector
            );
        }
        _publishCurrent(D.SCOPED_POLICY_INVENTORY_PROFILE);
        probe.pins(_config());
    }

    function testLegacyBaseHashCannotReplaceCompleteAuthorityDependencyHash() public {
        c.inventoryDependencyHash = keccak256(abi.encode(sd));
        _set(18, abi.encodeWithSignature("dependencyHash()"), abi.encode(c.inventoryDependencyHash));
        _rejectConsumer(
            abi.encodeCall(probe.pins, (_config())),
            CurrentConfiguration.InvalidFinalityArchiveConfiguration.selector
        );
    }

    function testResolverAndBundleOriginMismatchRejectWithoutProfileFallback() public {
        D.Dependencies memory wrong = ad;
        wrong.resolverCodeHash = keccak256("other runtime");
        _set(19, abi.encodeWithSignature("authorityDependencies()"), abi.encode(wrong));
        _rejectConsumer(
            abi.encodeCall(probe.pins, (_config())),
            CurrentConfiguration.InvalidFinalityArchiveConfiguration.selector
        );
        _publishCurrent(D.SCOPED_POLICY_INVENTORY_PROFILE);
        O.Dependencies memory other = od;
        other.workerCodeHash = keccak256("other origin worker");
        _set(19, abi.encodeWithSignature("originDependencies()"), abi.encode(other));
        _rejectConsumer(
            abi.encodeCall(probe.pins, (_config())),
            CurrentConfiguration.InvalidFinalityArchiveConfiguration.selector
        );
    }

    function testExplicitAuthorityCapabilityAndInvalid165ResponseAreRequired() public {
        _set(
            18,
            abi.encodeCall(IERC165.supportsInterface, (type(AuthorityInventoryI).interfaceId)),
            abi.encode(false)
        );
        _rejectConsumer(
            abi.encodeCall(probe.pins, (_config())), Reads.NativeProviderDependency.selector
        );
        _support(c.targets[18], type(AuthorityInventoryI).interfaceId);
        _set(18, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(true));
        _rejectConsumer(
            abi.encodeCall(probe.pins, (_config())), Reads.NativeProviderDependency.selector
        );
    }

    function testCollectionScopeCannotEnterScopedPolicyStatement() public {
        scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        _rejectConsumer(
            abi.encodeCall(probe.statement, (_config(), scope)), Reads.NativeProviderScope.selector
        );
    }

    function testExactInventoryScopeAnd736ByteEvidenceAreRequired() public {
        ScopedPolicy.Evidence memory e = _evidence(scope);
        e.scope.tokenId = 10;
        _set(18, abi.encodeCall(InventoryI.requireCurrent, (scope)), abi.encode(e));
        _rejectConsumer(
            abi.encodeCall(probe.statement, (_config(), scope)), Reads.NativeProviderSource.selector
        );
        _set(18, abi.encodeCall(InventoryI.requireCurrent, (scope)), abi.encode(e.inventory));
        _rejectConsumer(
            abi.encodeCall(probe.statement, (_config(), scope)),
            bytes4(keccak256("FinalityReadFailed(address)"))
        );
    }

    function testCoverageCannotSubstituteAnotherScopeOrInventoryCommitment() public {
        ScopedPolicy.Evidence memory e = _evidence(scope);
        _set(18, abi.encodeCall(InventoryI.requireCurrent, (scope)), abi.encode(e));
        CoverageTypes.BundleEvidence memory b = CoverageTypes.BundleEvidence(
            scope,
            InventoryTypes.BundleEvidence(
                PLAN,
                e.inventory.renderCriticalEvidenceHash,
                1,
                keccak256("chain"),
                keccak256("coverage")
            )
        );
        b.scope.tokenId = 10;
        bytes memory call_ = abi.encodeCall(
            BundleI.requireCoverage, (scope, PLAN, e.inventory.renderCriticalEvidenceHash)
        );
        _set(19, call_, abi.encode(b));
        _rejectConsumer(
            abi.encodeCall(probe.statement, (_config(), scope)), Reads.NativeProviderSource.selector
        );
        b.scope = scope;
        b.coverage.renderCriticalEvidenceHash = keccak256("other inventory commitment");
        _set(19, call_, abi.encode(b));
        _rejectConsumer(
            abi.encodeCall(probe.statement, (_config(), scope)), Reads.NativeProviderSource.selector
        );
    }

    function testPreparedPathRequiresExactOriginalRegistryBeforeSourceReads() public {
        _rejectConsumer(
            abi.encodeCall(probe.prepared, (_config(), scope)),
            Operations.ScopedProviderRegistryOnly.selector
        );
    }

    function testReviewUsesExactScopedPolicyAuthorityConfiguration() public {
        Manifest.Statement memory s;
        s.scope = scope;
        s.contentRoot = keccak256("root");
        s.inputs.referenceRenderRecordHash = keccak256("reference");
        s.inputs.snapshotRecordHash = keccak256("snapshot");
        s.referenceRenderManifestHash = keccak256("manifest");
        _publishCurrent(D.SCOPED_INVENTORY_PROFILE);
        _rejectConsumer(
            abi.encodeCall(probe.review, (_config(), s)),
            CurrentConfiguration.InvalidFinalityArchiveConfiguration.selector
        );
    }

    function testIndependentProjectionRejectsDuplicateSanctionRows() public {
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](10);
        for (uint256 i; i < 9; ++i) {
            rows[i].componentType = bytes32(i + 1);
        }
        rows[9].componentType = StreamFinalityDomains.COMPONENT_ARTIST_SANCTION;
        require(probe.independent(rows).length == 9);
        rows[8].componentType = StreamFinalityDomains.COMPONENT_ARTIST_SANCTION;
        _rejectConsumer(
            abi.encodeCall(probe.independent, (rows)), Reads.NativeProviderSource.selector
        );
    }
}
