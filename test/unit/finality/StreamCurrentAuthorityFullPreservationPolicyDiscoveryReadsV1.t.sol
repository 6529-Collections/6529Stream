// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityLineageDiscovery.t.sol";
import {
    StreamCurrentAuthorityFullPreservationPolicyDiscoveryReadsV1 as ExtractionReads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyDiscoveryReadsV1.sol";
import {
    IStreamFinalityPreservationFactoryProfileSourcesV1 as ExtractionCatalogue
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityPreservationFactoryProfileSourcesV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyDiscoveryFactoryReadsV1 as ExtractionScopedFactoryReads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyDiscoveryFactoryReadsV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyDiscoveryFactoryReadsV1 as ExtractionCollectionFactoryReads
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyDiscoveryFactoryReadsV1.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as ExtractionScopedDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV2 as ExtractionCollectionDefinitions
} from "../../../smart-contracts/domains/records/StreamPreservationPolicySnapshotDefinitionsV2.sol";

interface DiscoveryReadsBoundaryVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

/// @dev Explicit source-table boundary with a real caller check. Delegate extraction must
/// retain the discovery host as the caller, including reciprocal Finality reads.
contract DiscoveryReadsCallerTable {
    mapping(bytes32 => bytes) private values;
    mapping(bytes32 => bool) private present;
    address public expectedCaller;

    function expectCaller(address caller) external {
        expectedCaller = caller;
    }

    function put(bytes calldata input, bytes calldata output) external {
        values[keccak256(input)] = output;
        present[keccak256(input)] = true;
    }

    function remove(bytes calldata input) external {
        delete present[keccak256(input)];
    }

    fallback() external {
        require(msg.sender == expectedCaller, "same discovery caller");
        bytes32 key = keccak256(msg.data);
        require(present[key], "known typed finality read");
        bytes memory output = values[key];
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }
}

/// @dev Actual linked worker and compiler-typed nonzero storage roots. Setup deliberately
/// supplies synthetic constructor facts; production constructor coverage remains in the
/// existing StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1Test cohort.
contract CurrentPreservationDiscoveryReadsHarness {
    bytes32 private prefix = keccak256("prefix canary");
    StreamFinalityDiscoveryTypes.Configuration private original;
    mapping(address => bytes32) private pins;
    ExtractionReads.Context private context;
    bytes32 private suffix = keccak256("suffix canary");

    constructor(
        StreamFinalityDiscoveryTypes.Configuration memory c,
        ExtractionReads.Context memory x
    ) {
        original = c;
        context = x;
        address[9] memory targets = [
            c.core,
            c.metadata,
            c.router,
            c.provider,
            c.membership,
            c.entropyFactory,
            c.metadataAdapter,
            c.referenceRender,
            c.artist
        ];
        for (uint256 i; i < targets.length; ++i) {
            pins[targets[i]] = targets[i].codehash;
        }
        for (uint256 i; i < 6; ++i) {
            pins[c.routerAdapters[i]] = c.routerAdapters[i].codehash;
        }
        for (uint256 i; i < 2; ++i) {
            pins[x.profiles[i].snapshots] = x.profiles[i].snapshotsCodeHash;
            pins[x.profiles[i].referenceRender] = x.profiles[i].referenceRenderCodeHash;
            pins[x.profiles[i].entropyFactory] = x.profiles[i].entropyFactoryCodeHash;
        }
    }

    function configuration()
        external
        view
        returns (StreamFinalityDiscoveryTypes.Configuration memory)
    {
        return original;
    }

    function fingerprint() public view returns (bytes32) {
        return keccak256(abi.encode(prefix, original, context, suffix, pins[original.provider]));
    }

    function current(StreamFinalityScope memory scope)
        external
        view
        returns (CA.Route memory route)
    {
        bytes memory left = abi.encode(scope, bytes("unaligned left memory canary"));
        bytes memory right = abi.encode(bytes("right memory canary"), scope, address(this));
        bytes32 leftHash = keccak256(left);
        bytes32 rightHash = keccak256(right);
        bytes32 before_ = fingerprint();
        route = ExtractionReads.current(original, pins, context, scope, original);
        require(keccak256(left) == leftHash && keccak256(right) == rightHash, "memory preserved");
        require(fingerprint() == before_, "all constructor state preserved");
    }

    function selected(StreamFinalityScope memory scope)
        external
        view
        returns (StreamFinalityDiscoveryTypes.Configuration memory)
    {
        return ExtractionReads.scopeConfiguration(original, pins, context, scope);
    }

    function pinReference(StreamFinalityScope memory scope, address target) external view {
        ExtractionReads.pinReference(original, pins, context, scope, target);
    }
}

/// @dev Actual extracted current/profile/serving/authority logic; original Core/Finality,
/// provider and static profile sources are the inherited explicit tables. Factory.current
/// alone is mocked at its full typed public-library ABI in the two factory cases. This
/// proves extraction boundaries, not real factory publication or an Artist/finality ceremony.
contract StreamCurrentAuthorityFullPreservationPolicyDiscoveryReadsV1Test is
    LineageDiscoveryFixture
{
    DiscoveryReadsBoundaryVm private constant boundaryVm =
        DiscoveryReadsBoundaryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    CurrentPreservationDiscoveryReadsHarness private subject;
    DiscoveryReadsCallerTable private finality;
    ExtractionReads.Context private x;
    Profiles.Profile private chosen;
    bytes32 private constant SOURCE_HASH = keccak256("frozen discovery source configuration");

    function setUp() public override {
        super.setUp();
        c.readGas = 500000;
        c.componentGas = 8000000;
        finality = new DiscoveryReadsCallerTable();
        c.finalityRegistry = address(finality);
        c.finalityRegistryCodeHash = address(finality).codehash;
        authority.finalityRegistry = c.finalityRegistry;
        authority.finalityCodeHash = c.finalityRegistryCodeHash;
        x.core = c.core;
        x.scopeEvidenceProvider = c.provider;
        x.deploymentChainId = block.chainid;
        x.sourceConfigurationHash = SOURCE_HASH;
        address snapshots = IStreamFinalityDiscoverySources(c.provider).snapshotHost();
        x.profiles[0] = Profiles.Profile(
            ProfileReads.profileHash(0),
            c.referenceRender,
            c.referenceRender.codehash,
            snapshots,
            snapshots.codehash,
            c.entropyFactory,
            c.entropyFactory.codehash,
            keccak256("old collection config")
        );
        address pinReference = _new();
        address scopedSnapshots = _new();
        address entropyFactory = _new();
        x.profiles[1] = Profiles.Profile(
            ProfileReads.profileHash(1),
            pinReference,
            pinReference.codehash,
            scopedSnapshots,
            scopedSnapshots.codehash,
            entropyFactory,
            entropyFactory.codehash,
            keccak256("old scoped config")
        );
        x.collectionBinding.factory = _new();
        x.collectionBinding.factoryCodeHash = x.collectionBinding.factory.codehash;
        x.collectionBinding.recipeHash = keccak256("collection recipe");
        x.collectionBinding.sourceFactoryDependenciesHash = keccak256("collection source pins");
        x.collectionBinding.graphGas = 4000000;
        x.collectionBinding.configurationHash = keccak256("collection factory configuration");
        x.collectionEntropyFactory = c.entropyFactory;
        x.collectionEntropyCodeHash = c.entropyFactory.codehash;
        x.publicationBinding.factory = _new();
        x.publicationBinding.factoryCodeHash = x.publicationBinding.factory.codehash;
        x.publicationBinding.recipeHash = keccak256("scoped recipe");
        x.publicationBinding.sourceFactoryDependenciesHash = keccak256("scoped source pins");
        x.publicationBinding.graphGas = 4000000;
        x.publicationBinding.configurationHash = keccak256("scoped factory configuration");
        x.scopedPolicyEntropyFactory = c.entropyFactory;
        x.scopedPolicyEntropyCodeHash = c.entropyFactory.codehash;
        subject = new CurrentPreservationDiscoveryReadsHarness(c, x);
        finality.expectCaller(address(subject));
        _address(c.finalityRegistry, "scopeEvidenceProvider()", c.provider);
        _address(c.finalityRegistry, "finalityDiscovery()", address(subject));
        _address(c.finalityRegistry, "coreReads()", c.core);
        _address(c.finalityRegistry, "metadataReads()", c.metadata);
        _address(c.finalityRegistry, "sanctionReads()", c.artist);
        _support(c.finalityRegistry, type(IStreamFinalityCurrentAuthority).interfaceId);
        _put(
            c.finalityRegistry,
            abi.encodeCall(IStreamFinalityCurrentAuthority.currentAuthorityProfile, ()),
            abi.encode(CA.PROFILE)
        );
        _routeValue(authority);
        _put(
            c.provider,
            abi.encodeCall(
                IStreamFinalityRouterEvidenceBinding.requireCurrentRouterCandidate,
                (scope.collectionId, c.finalityRegistry)
            ),
            bytes("")
        );
        _put(
            c.provider,
            abi.encodeCall(ExtractionCatalogue.finalitySourceConfigurationHash, ()),
            abi.encode(SOURCE_HASH)
        );
        chosen = x.profiles[0];
        _source();
    }

    function _source() private {
        _put(
            c.provider,
            abi.encodeCall(ExtractionCatalogue.finalitySourcesForScope, (scope)),
            abi.encode(Profiles.Sources(scope, chosen))
        );
    }

    function _currentExact() private view {
        require(
            keccak256(abi.encode(subject.current(scope))) == keccak256(abi.encode(authority)),
            "full current route bytes"
        );
    }

    function _refuse(bytes memory call_, bytes memory reason) private view {
        bytes32 before_ = subject.fingerprint();
        (bool ok, bytes memory raw) = address(subject).staticcall(call_);
        require(
            !ok && raw.length == reason.length && keccak256(raw) == keccak256(reason),
            "exact original refusal"
        );
        require(subject.fingerprint() == before_, "failed read keeps constructor state");
    }

    function _unsupported() private pure returns (bytes memory) {
        return abi.encodeWithSelector(ExtractionReads.DiscoveryUnsupportedProfile.selector);
    }

    function _staticServing() private {
        IStreamMetadataServingFacts.ServingFacts memory serving;
        serving.configured = true;
        serving.mode = keccak256("ONCHAIN");
        serving.presentationProfile = keccak256("6529STREAM_STATIC_METADATA_SELECTION_V1");
        _put(
            c.router,
            abi.encodeCall(
                IStreamMetadataServingFacts.collectionServingFacts, (scope.collectionId)
            ),
            abi.encode(serving)
        );
        _put(
            c.router,
            abi.encodeCall(StaticRouter.staticMetadataActivation, (scope.collectionId)),
            abi.encode(keccak256("activation"), uint64(1), keccak256("activation head"))
        );
    }

    function _token() private {
        scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 42, bytes32(0));
        chosen = x.profiles[1];
        _source();
        StreamScopeMembershipFacts memory members;
        members.scopeSubject = StreamMetadataSubjects.scopeSubject(block.chainid, c.core, scope);
        members.membershipHash = keccak256("one exact token");
        members.tokenCount = 1;
        _put(
            c.membership,
            abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (scope)),
            abi.encode(members)
        );
        _staticServing();
    }

    function _factoryProfile(bool collection) private {
        if (!collection) _token();
        chosen.profileHash = collection
            ? ExtractionCollectionDefinitions.PROFILE_HASH
            : ExtractionScopedDefinitions.PROFILE_HASH;
        chosen.referenceRender = _new();
        chosen.referenceRenderCodeHash = chosen.referenceRender.codehash;
        chosen.snapshots = _new();
        chosen.snapshotsCodeHash = chosen.snapshots.codehash;
        chosen.entropyFactory = c.entropyFactory;
        chosen.entropyFactoryCodeHash = c.entropyFactory.codehash;
        chosen.configurationHash = collection
            ? x.collectionBinding.configurationHash
            : x.publicationBinding.configurationHash;
        if (collection) {
            boundaryVm.mockCall(
                address(ExtractionCollectionFactoryReads),
                abi.encodeWithSelector(
                    ExtractionCollectionFactoryReads.current.selector,
                    x.collectionBinding,
                    x.collectionEntropyFactory,
                    x.collectionEntropyCodeHash,
                    scope
                ),
                abi.encode(chosen)
            );
        } else {
            boundaryVm.mockCall(
                address(ExtractionScopedFactoryReads),
                abi.encodeWithSelector(
                    ExtractionScopedFactoryReads.current.selector,
                    x.publicationBinding,
                    x.scopedPolicyEntropyFactory,
                    x.scopedPolicyEntropyCodeHash,
                    scope
                ),
                abi.encode(chosen)
            );
        }
        _address(chosen.snapshots, "core()", c.core);
        _address(chosen.snapshots, "metadataHost()", c.metadata);
        _address(chosen.referenceRender, "core()", c.core);
        _address(chosen.referenceRender, "metadataHost()", c.metadata);
        _address(chosen.referenceRender, "metadataRouter()", c.router);
        _address(chosen.referenceRender, "snapshots()", chosen.snapshots);
        _support(chosen.referenceRender, type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _support(chosen.referenceRender, type(IStreamArtworkFinalityComponent).interfaceId);
        _source();
        _staticServing();
    }

    function testWorkerRetainsHostCallerAndOriginalConfigurationAcrossCurrentSuccessor() public {
        bytes32 before_ = subject.fingerprint();
        _currentExact();
        require(
            keccak256(abi.encode(subject.configuration())) == keccak256(abi.encode(c)),
            "original configuration bytes"
        );
        _successor(_new());
        _currentExact();
        require(
            subject.fingerprint() == before_ && subject.configuration().artist == c.artist,
            "authority changes never replace original anchor"
        );
    }

    function testScopedSelectionCopiesNeverAliasOriginalConfiguration() public {
        _token();
        bytes32 before_ = subject.fingerprint();
        StreamFinalityDiscoveryTypes.Configuration memory selected = subject.selected(scope);
        require(
            selected.referenceRender == chosen.referenceRender
                && selected.entropyFactory == chosen.entropyFactory,
            "selected exact scoped endpoints"
        );
        require(
            selected.referenceRender != c.referenceRender
                && selected.entropyFactory != c.entropyFactory,
            "fixture actually distinguishes original endpoints"
        );
        _currentExact();
        subject.pinReference(scope, chosen.referenceRender);
        require(
            subject.fingerprint() == before_
                && keccak256(abi.encode(subject.configuration())) == keccak256(abi.encode(c)),
            "no memory-to-storage alias"
        );
    }

    function testSourceHashRefusesBeforeMalformedProfileAndRestores() public {
        _put(
            c.provider,
            abi.encodeCall(ExtractionCatalogue.finalitySourceConfigurationHash, ()),
            abi.encode(keccak256("changed"))
        );
        _put(
            c.provider,
            abi.encodeCall(ExtractionCatalogue.finalitySourcesForScope, (scope)),
            hex"01"
        );
        _refuse(
            abi.encodeCall(subject.current, (scope)),
            abi.encodeWithSelector(ExtractionReads.DiscoveryDependency.selector, c.provider)
        );
        _put(
            c.provider,
            abi.encodeCall(ExtractionCatalogue.finalitySourceConfigurationHash, ()),
            abi.encode(SOURCE_HASH)
        );
        _refuse(
            abi.encodeCall(subject.current, (scope)),
            abi.encodeWithSelector(
                StreamFinalityRouterEvidence.RouterEvidenceRead.selector,
                c.provider,
                ExtractionCatalogue.finalitySourcesForScope.selector
            )
        );
        _source();
        _currentExact();
    }

    function testCatalogueFullScopeAndConfigurationEqualityRejectThenRestore() public {
        Profiles.Profile memory original = chosen;
        chosen.configurationHash = keccak256("foreign configuration");
        _source();
        _refuse(abi.encodeCall(subject.current, (scope)), _unsupported());
        chosen = original;
        StreamFinalityScope memory wrong = scope;
        wrong.collectionId = 2;
        _put(
            c.provider,
            abi.encodeCall(ExtractionCatalogue.finalitySourcesForScope, (scope)),
            abi.encode(Profiles.Sources(wrong, chosen))
        );
        _refuse(abi.encodeCall(subject.current, (scope)), _unsupported());
        _source();
        _currentExact();
    }

    function testCollectionFactoryFullEqualityAndReciprocalFailureRemainDistinct() public {
        _factoryProfile(true);
        _currentExact();
        subject.pinReference(scope, chosen.referenceRender);
        _address(chosen.referenceRender, "snapshots()", c.core);
        _refuse(
            abi.encodeCall(subject.current, (scope)),
            abi.encodeWithSelector(
                ExtractionReads.DiscoveryConfiguration.selector, chosen.referenceRender
            )
        );
        _address(chosen.referenceRender, "snapshots()", chosen.snapshots);
        bytes32 old = chosen.configurationHash;
        chosen.configurationHash = keccak256("substituted factory declaration");
        _source();
        _refuse(abi.encodeCall(subject.current, (scope)), _unsupported());
        chosen.configurationHash = old;
        _source();
        _currentExact();
    }

    function testScopedFactoryUnpinnedReferenceRequiresSelectedExactChildAndRestores() public {
        _factoryProfile(false);
        _currentExact();
        subject.pinReference(scope, chosen.referenceRender);
        address foreign = _new();
        _refuse(
            abi.encodeCall(subject.pinReference, (scope, foreign)),
            abi.encodeWithSelector(ExtractionReads.DiscoveryDependency.selector, foreign)
        );
        _address(chosen.snapshots, "metadataHost()", c.core);
        _refuse(
            abi.encodeCall(subject.current, (scope)),
            abi.encodeWithSelector(
                ExtractionReads.DiscoveryConfiguration.selector, chosen.snapshots
            )
        );
        _address(chosen.snapshots, "metadataHost()", c.metadata);
        _currentExact();
    }

    function testOriginalFinalityReciprocityPrecedesMembershipAndAuthorityReads() public {
        _address(c.finalityRegistry, "finalityDiscovery()", address(ExtractionReads));
        DiscoveryReadTable(c.membership)
            .remove(abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (scope)));
        finality.remove(
            abi.encodeCall(
                IStreamFinalityCurrentAuthority.currentArtistAuthority, (scope.collectionId)
            )
        );
        _refuse(
            abi.encodeCall(subject.current, (scope)),
            abi.encodeWithSelector(
                ExtractionReads.DiscoveryConfiguration.selector, c.finalityRegistry
            )
        );
        _address(c.finalityRegistry, "finalityDiscovery()", address(subject));
        _refuse(
            abi.encodeCall(subject.current, (scope)),
            abi.encodeWithSelector(
                StreamFinalityRouterEvidence.RouterEvidenceRead.selector,
                c.membership,
                IStreamFinalityScopeMembership.requireScopeMembership.selector
            )
        );
        StreamScopeMembershipFacts memory members;
        members.scopeSubject = StreamMetadataSubjects.scopeSubject(block.chainid, c.core, scope);
        members.membershipHash = keccak256("members");
        members.tokenCount = 2;
        _put(
            c.membership,
            abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (scope)),
            abi.encode(members)
        );
        _refuse(
            abi.encodeCall(subject.current, (scope)),
            abi.encodeWithSelector(
                StreamFinalityRouterEvidence.RouterEvidenceRead.selector,
                c.finalityRegistry,
                IStreamFinalityCurrentAuthority.currentArtistAuthority.selector
            )
        );
        _routeValue(authority);
        _currentExact();
    }
}
