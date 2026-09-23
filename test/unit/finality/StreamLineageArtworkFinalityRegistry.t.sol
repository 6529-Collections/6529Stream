// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityCurrentDiscovery.t.sol";
import "../../helpers/FinalityCanonicalReadFixture.sol";
import "../../../smart-contracts/domains/finality/StreamLineageArtworkFinalityRegistry.sol";
import {
    StreamArtistCurrentAuthorityTypes as CA
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";

contract LineageFinalityProviderBoundary is FinalityReadProviderBoundary {
    address public immutable metadataRouter;

    constructor(address core_, address metadata_, address router_)
        FinalityReadProviderBoundary(core_, metadata_)
    {
        metadataRouter = router_;
    }
}

contract LineageFinalityFactory {
    function deploy(address[8] memory dependencies, address resolver_)
        external
        returns (StreamLineageArtworkFinalityRegistry)
    {
        return new StreamLineageArtworkFinalityRegistry(
            dependencies[0],
            dependencies[1],
            dependencies[2],
            dependencies[3],
            dependencies[4],
            dependencies[5],
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_COMPONENT_READ_GAS", 4000000, 50000, 2
            ),
            StreamFinalityDeploymentConfiguration(
                dependencies[6],
                keccak256("lineage deployment"),
                "urn:lineage-finality-boundary",
                keccak256("lineage manifest")
            ),
            resolver_
        );
    }
}

/// @dev Actual Registry constructor/current-authority joins; resolver and Coordinator outputs
/// are typed adversarial boundaries, not claims of actual migration or complete finalization.
contract StreamLineageArtworkFinalityRegistryTest is CharacterizationTestBase {
    LineageFinalityFactory private factory;
    DiscoveryReadTable private resolver;
    DiscoveryReadTable private coordinator;
    CA.Anchors private anchors;
    CA.Route private route;
    address[8] private dependencies;
    address private predicted;
    address private provider;
    StreamLineageArtworkFinalityRegistry private registry;

    function setUp() public {
        dependencies[0] = address(new MockFinalityCore());
        dependencies[1] = address(new MockFinalityMetadata());
        dependencies[3] = address(new MockFinalitySanction());
        dependencies[4] = address(new FinalityReadAuthorityBoundary());
        address router = address(new DiscoveryReadTable());
        provider =
            address(new LineageFinalityProviderBoundary(dependencies[0], dependencies[1], router));
        dependencies[2] =
            address(new StreamCoreFinalityAdapter(dependencies[0], dependencies[1], provider));
        dependencies[5] = address(new FinalityReadDiscoveryBoundary(provider));
        factory = new LineageFinalityFactory();
        FinalityReadFixtureVm cheat = FinalityReadFixtureVm(address(vm));
        predicted = cheat.computeCreateAddress(address(factory), cheat.getNonce(address(factory)));
        dependencies[6] =
            address(new FinalityReadArtifactBoundary(dependencies[0], predicted, dependencies[4]));
        resolver = new DiscoveryReadTable();
        coordinator = new DiscoveryReadTable();
        anchors.targets = [dependencies[0], dependencies[1], router, dependencies[3], provider];
        for (uint256 i; i < 5; ++i) {
            anchors.codeHashes[i] = anchors.targets[i].codehash;
        }
        anchors.finalityRegistry = predicted;
        anchors.chainId = block.chainid;
        anchors.readGas = 100000;
        resolver.put(
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)), abi.encode(true)
        );
        resolver.put(
            abi.encodeCall(IERC165.supportsInterface, (type(AuthorityResolver).interfaceId)),
            abi.encode(true)
        );
        resolver.put(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false)
        );
        resolver.put(
            abi.encodeCall(AuthorityResolver.currentAuthorityProfile, ()), abi.encode(CA.PROFILE)
        );
        _anchors();
    }

    function _anchors() private {
        resolver.put(abi.encodeCall(AuthorityResolver.anchors, ()), abi.encode(anchors));
    }

    function _deploy() private {
        registry = factory.deploy(dependencies, address(resolver));
        require(address(registry) == predicted);
        route = CA.Route(
            address(registry),
            address(registry).codehash,
            provider,
            provider.codehash,
            address(new DiscoveryReadTable()),
            bytes32(0),
            address(coordinator),
            address(coordinator).codehash,
            keccak256("authenticated current selection boundary"),
            keccak256("original A presentation boundary")
        );
        route.registryCodeHash = route.registry.codehash;
        _route();
    }

    function _route() private {
        coordinator.put(
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)), abi.encode(true)
        );
        coordinator.put(
            abi.encodeCall(IERC165.supportsInterface, (type(ArtistCurrentFinality).interfaceId)),
            abi.encode(true)
        );
        coordinator.put(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false)
        );
        resolver.put(
            abi.encodeCall(AuthorityResolver.currentFinalityRoute, (uint256(7))), abi.encode(route)
        );
        coordinator.put(
            abi.encodeCall(ArtistCurrentFinality.currentFinalityRoute, (uint256(7))),
            abi.encode(route)
        );
    }

    function testCurrentRouteAndUnpredictedSuccessorRetainOriginalAnchors() public {
        _deploy();
        require(registry.supportsInterface(type(IStreamFinalityCurrentAuthority).interfaceId));
        require(registry.currentAuthorityProfile() == CA.PROFILE);
        require(address(registry.sanctionReads()) == dependencies[3]);
        require(
            registry.scopeEvidenceProvider() == provider
                && registry.artifactCoverage() == dependencies[6]
        );
        require(
            keccak256(abi.encode(registry.currentArtistAuthority(7)))
                == keccak256(abi.encode(route))
        );
        route.registry = address(new DiscoveryReadTable());
        route.registryCodeHash = route.registry.codehash;
        coordinator = new DiscoveryReadTable();
        route.coordinator = address(coordinator);
        route.coordinatorCodeHash = address(coordinator).codehash;
        route.selectionHash = keccak256("new C selected after original host deployment");
        _route();
        require(registry.currentArtistAuthority(7).registry == route.registry);
        require(address(registry.sanctionReads()) == dependencies[3]);
    }

    function testCoordinatorMustReturnTheByteExactSameRouteAndRetryIsUnchanged() public {
        _deploy();
        CA.Route memory wrong = route;
        wrong.selectionHash = keccak256("other selection");
        coordinator.put(
            abi.encodeCall(ArtistCurrentFinality.currentFinalityRoute, (uint256(7))),
            abi.encode(wrong)
        );
        vm.expectRevert();
        registry.currentArtistAuthority(7);
        _route();
        require(registry.currentArtistAuthority(7).selectionHash == route.selectionHash);
        coordinator.put(
            abi.encodeCall(ArtistCurrentFinality.currentFinalityRoute, (uint256(7))),
            abi.encode(route.registry)
        );
        vm.expectRevert();
        registry.currentArtistAuthority(7);
    }

    function testCoordinatorMustAdvertiseCanonicalCapability() public {
        _deploy();
        coordinator.put(
            abi.encodeCall(IERC165.supportsInterface, (type(ArtistCurrentFinality).interfaceId)),
            abi.encode(false)
        );
        vm.expectRevert();
        registry.currentArtistAuthority(7);
        _route();
        coordinator.put(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(true)
        );
        vm.expectRevert();
        registry.currentArtistAuthority(7);
        _route();
        coordinator.put(
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
            abi.encode(uint256(2))
        );
        vm.expectRevert();
        registry.currentArtistAuthority(7);
    }

    function testResolverCannotChangeFixedConfigurationProfileOrRuntime() public {
        _deploy();
        anchors.readGas += 1;
        _anchors();
        vm.expectRevert();
        registry.currentArtistAuthority(7);
        anchors.readGas -= 1;
        _anchors();
        resolver.put(
            abi.encodeCall(AuthorityResolver.currentAuthorityProfile, ()), abi.encode(bytes32(0))
        );
        vm.expectRevert();
        registry.currentArtistAuthority(7);
        resolver.put(
            abi.encodeCall(AuthorityResolver.currentAuthorityProfile, ()), abi.encode(CA.PROFILE)
        );
        require(registry.currentArtistAuthority(7).registry == route.registry);
        vm.etch(address(resolver), hex"00");
        vm.expectRevert();
        registry.currentArtistAuthority(7);
    }

    function testRouteCannotSubstituteFinalityProviderOrRuntimeEvenIfCoordinatorAgrees() public {
        _deploy();
        address saved = route.provider;
        route.provider = dependencies[3];
        route.providerCodeHash = dependencies[3].codehash;
        _route();
        vm.expectRevert();
        registry.currentArtistAuthority(7);
        route.provider = saved;
        route.providerCodeHash = saved.codehash;
        route.finalityRegistry = dependencies[3];
        _route();
        vm.expectRevert();
        registry.currentArtistAuthority(7);
        route.finalityRegistry = address(registry);
        route.registryCodeHash = keccak256("wrong runtime");
        _route();
        vm.expectRevert();
        registry.currentArtistAuthority(7);
    }

    function testConstructorRejectsWrongAnchorWithoutConsumingPredictedAddress() public {
        anchors.targets[4] = dependencies[3];
        anchors.codeHashes[4] = dependencies[3].codehash;
        _anchors();
        vm.expectRevert();
        factory.deploy(dependencies, address(resolver));
        anchors.targets[4] = provider;
        anchors.codeHashes[4] = provider.codehash;
        _anchors();
        _deploy();
        require(address(registry) == predicted);
    }

    function testConstructorRequiresExactCapabilityAndCanonicalAnchors() public {
        resolver.put(
            abi.encodeCall(IERC165.supportsInterface, (type(AuthorityResolver).interfaceId)),
            abi.encode(false)
        );
        vm.expectRevert();
        factory.deploy(dependencies, address(resolver));
        resolver.put(
            abi.encodeCall(IERC165.supportsInterface, (type(AuthorityResolver).interfaceId)),
            abi.encode(true)
        );
        resolver.put(abi.encodeCall(AuthorityResolver.anchors, ()), abi.encode(anchors.chainId));
        vm.expectRevert();
        factory.deploy(dependencies, address(resolver));
        _anchors();
        _deploy();
        vm.expectRevert();
        registry.currentArtistAuthority(0);
    }
}
