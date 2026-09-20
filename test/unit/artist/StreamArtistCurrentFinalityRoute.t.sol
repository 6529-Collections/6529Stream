// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCurrentFinalityRoute as RouteReads
} from "../../../smart-contracts/domains/artist/StreamArtistCurrentFinalityRoute.sol";
import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamFinalityCurrentAuthority as F
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCurrentAuthority.sol";
import {
    IStreamArtistCurrentAuthorityResolver as R
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";

contract CurrentRouteNode { }

contract CurrentRouteCoreBoundary {
    address public selected;

    function select(address target) external {
        selected = target;
    }

    function getSatellitePointer(bytes32)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        return (
            selected,
            selected.codehash,
            true,
            bytes32(0),
            bytes4(0),
            address(0),
            1,
            bytes32(0),
            bytes32(0),
            1
        );
    }
}

contract CurrentRouteRouterBoundary {
    address public finality;

    function set(address target) external {
        finality = target;
    }

    function originalFinalityAnchor(uint256) external view returns (address, bytes32) {
        return (finality, finality.codehash);
    }
}

contract CurrentRouteResolverBoundary {
    C.Anchors private a;
    C.Selection private s;
    C.Route private r;
    bytes32 public currentAuthorityProfile = C.PROFILE;
    bool public fail;

    function configure(C.Anchors memory aa, C.Selection memory ss, C.Route memory rr) external {
        a = aa;
        s = ss;
        r = rr;
    }

    function setProfile(bytes32 value) external {
        currentAuthorityProfile = value;
    }

    function setFail(bool value) external {
        fail = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(R).interfaceId;
    }

    function anchors() external view returns (C.Anchors memory) {
        require(!fail, "resolver explicit failure");
        return a;
    }

    function currentSelection() external view returns (C.Selection memory) {
        require(!fail, "resolver explicit failure");
        return s;
    }

    function currentFinalityRoute(uint256) external view returns (C.Route memory) {
        require(!fail, "resolver explicit failure");
        return r;
    }
}

contract CurrentRouteFinalityBoundary {
    address public currentAuthorityResolver;
    bytes32 public currentAuthorityResolverCodeHash;
    bytes32 public currentAuthorityProfile = C.PROFILE;
    bool public advertised = true;

    constructor(address resolver) {
        currentAuthorityResolver = resolver;
        currentAuthorityResolverCodeHash = resolver.codehash;
    }

    function advertise(bool value) external {
        advertised = value;
    }

    function setProfile(bytes32 value) external {
        currentAuthorityProfile = value;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return id == 0x01ffc9a7 || (advertised && id == type(F).interfaceId);
    }

    function currentArtistAuthority(uint256) external pure returns (C.Route memory) {
        revert("recursive Finality call forbidden");
    }
}

contract CurrentRouteCoordinatorHarness {
    T.SuiteConfiguration private s;
    address public immutable finalityRegistry;
    address public immutable finalityEvidenceProvider;

    constructor(T.SuiteConfiguration memory suite, address oldFinality, address oldProvider) {
        s = suite;
        finalityRegistry = oldFinality;
        finalityEvidenceProvider = oldProvider;
    }

    function resolve(uint256 cid) external view returns (bool, C.Route memory) {
        return RouteReads.resolve(s, block.chainid, cid, 3000000);
    }
}

/// @notice Actual route helper against explicit typed Core/Finality/resolver response boundaries.
/// @dev Does not substitute these boundaries for actual ancestry, original Finality or Safe tests.
contract StreamArtistCurrentFinalityRouteTest {
    CurrentRouteCoreBoundary private core;
    CurrentRouteRouterBoundary private router;
    CurrentRouteResolverBoundary private resolver;
    CurrentRouteFinalityBoundary private finality;
    CurrentRouteCoordinatorHarness private coordinator;
    T.SuiteConfiguration private suite;
    C.Anchors private anchors;
    C.Selection private selection;
    C.Route private route;

    function setUp() public {
        core = new CurrentRouteCoreBoundary();
        router = new CurrentRouteRouterBoundary();
        resolver = new CurrentRouteResolverBoundary();
        finality = new CurrentRouteFinalityBoundary(address(resolver));
        suite.core = address(core);
        suite.metadata = address(router);
        suite.registry = address(new CurrentRouteNode());
        suite.archive = address(new CurrentRouteNode());
        suite.mintManager = address(new CurrentRouteNode());
        for (uint256 i; i < 7; ++i) {
            suite.owners[i] = address(new CurrentRouteNode());
        }
        coordinator = new CurrentRouteCoordinatorHarness(
            suite, address(new CurrentRouteNode()), address(new CurrentRouteNode())
        );
        anchors.targets = [
            address(core),
            address(new CurrentRouteNode()),
            address(router),
            address(new CurrentRouteNode()),
            address(new CurrentRouteNode())
        ];
        for (uint256 i; i < 5; ++i) {
            anchors.codeHashes[i] = anchors.targets[i].codehash;
        }
        anchors.finalityRegistry = address(finality);
        anchors.chainId = block.chainid;
        anchors.readGas = 300000;
        selection.origin.environment.registry = suite.registry;
        selection.origin.registryCodeHash = suite.registry.codehash;
        selection.origin.environment.coordinator = address(coordinator);
        selection.origin.coordinatorCodeHash = address(coordinator).codehash;
        selection.origin.environment.suiteConfigurationHash = keccak256(abi.encode(suite));
        selection.completion = keccak256("explicit completed selected suite response");
        selection.selectionHash = C.hashSelection(anchors, selection.origin, selection.completion);
        route = C.Route(
            address(finality),
            address(finality).codehash,
            anchors.targets[4],
            anchors.codeHashes[4],
            suite.registry,
            suite.registry.codehash,
            address(coordinator),
            address(coordinator).codehash,
            selection.selectionHash,
            keccak256("actual locked presentation response")
        );
        core.select(address(finality));
        router.set(address(finality));
        _configure();
    }

    function _configure() private {
        resolver.configure(anchors, selection, route);
    }

    function _refuses() private view {
        (bool ok,) =
            address(coordinator).staticcall(abi.encodeCall(coordinator.resolve, (uint256(1))));
        require(!ok, "invalid reciprocity must refuse");
    }

    function testExplicitRouteUsesPreservedFinalityWithoutCallingItsRecursiveEndpoint()
        public
        view
    {
        (bool supported, C.Route memory found) = coordinator.resolve(1);
        require(
            supported && keccak256(abi.encode(found)) == keccak256(abi.encode(route)),
            "exact direct-resolver route"
        );
        require(
            coordinator.finalityRegistry() != found.finalityRegistry
                && coordinator.finalityEvidenceProvider() != found.provider,
            "immutable successor constructor getters preserved"
        );
        require(
            RouteReads.isAnchoredCapability(address(router), 1, 3000000),
            "explicit anchored capability"
        );
    }

    function testLegacyProfileSkipsFailingResolverAndPreservesOldPath() public {
        finality.advertise(false);
        resolver.setFail(true);
        (bool supported, C.Route memory found) = coordinator.resolve(1);
        require(
            !supported && found.finalityRegistry == address(0), "legacy no new resolver dependency"
        );
        require(
            !RouteReads.isAnchoredCapability(address(router), 1, 3000000),
            "legacy confirmation stays historical"
        );
    }

    function testAdvertisedFailureCannotFallback() public {
        resolver.setFail(true);
        _refuses();
    }

    function testWrongFinalityProfileRefused() public {
        finality.setProfile(keccak256("wrong"));
        _refuses();
    }

    function testWrongResolverProfileRefused() public {
        resolver.setProfile(keccak256("wrong"));
        _refuses();
    }

    function testWrongReciprocalCoordinatorRefused() public {
        route.coordinator = address(this);
        _configure();
        _refuses();
    }

    function testWrongCompleteSuiteConfigurationRefused() public {
        selection.origin.environment.suiteConfigurationHash = keccak256("wrong suite");
        selection.selectionHash = C.hashSelection(anchors, selection.origin, selection.completion);
        route.selectionHash = selection.selectionHash;
        _configure();
        _refuses();
    }

    function testStaleRouteSelectionAfterCaptureChangeRefused() public {
        selection.completion = keccak256("next completion");
        selection.selectionHash = C.hashSelection(anchors, selection.origin, selection.completion);
        _configure();
        _refuses();
    }

    function testWrongPreservedProviderRefused() public {
        route.provider = address(new CurrentRouteNode());
        _configure();
        _refuses();
    }

    function testWrongSelectedRegistryRuntimeRefused() public {
        route.registryCodeHash = keccak256("wrong runtime");
        _configure();
        _refuses();
    }
}
