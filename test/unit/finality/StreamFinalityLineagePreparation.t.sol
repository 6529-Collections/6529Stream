// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityCurrentDiscovery.t.sol";
import {
    StreamFinalityPreparation as Legacy
} from "../../../smart-contracts/domains/finality/StreamFinalityPreparation.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityLineagePreparation.sol";
import {
    StreamArtistCurrentAuthorityTypes as CA
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";

contract LineagePreparationHarness {
    Legacy.Dependencies private deps;
    CA.Route private route;

    function configure(Legacy.Dependencies memory d, CA.Route memory r) external {
        deps = d;
        route = r;
    }

    function currentAuthorityProfile() external pure returns (bytes32) {
        return CA.PROFILE;
    }

    function currentArtistAuthority(uint256) external view returns (CA.Route memory) {
        return route;
    }

    function probe(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest,
        bool legacy
    ) external view {
        if (legacy) Legacy.prepareSanction(deps, scope, components, manifest);
        else StreamFinalityLineagePreparation.prepareSanction(deps, scope, components, manifest);
    }
}

/// @dev Binding boundary: a distinct component-type rejection proves which sanction owner is
/// reached. This does not claim complete preparation, finalization, or migration execution.
contract StreamFinalityLineagePreparationTest is CharacterizationTestBase {
    LineagePreparationHarness private host;
    Legacy.Dependencies private deps;
    CA.Route private route;
    address private original;
    address private current;
    bytes32 private constant CURRENT_TYPE = keccak256("current authority boundary sentinel");

    function _new() private returns (address) {
        return address(new DiscoveryReadTable());
    }

    function _put(address target, bytes memory input, bytes memory output) private {
        DiscoveryReadTable(target).put(input, output);
    }

    function _address(address target, string memory signature, address result) private {
        _put(target, abi.encodeWithSignature(signature), abi.encode(result));
    }

    function _selected(bytes32 kind, address target) private {
        _put(
            address(deps.coreReads),
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)),
            abi.encode(
                target,
                target.codehash,
                false,
                bytes32(0),
                bytes4(0),
                address(0),
                uint8(0),
                bytes32(0),
                bytes32(0),
                uint64(0)
            )
        );
    }

    function setUp() public {
        host = new LineagePreparationHarness();
        deps.coreReads = IStreamCoreFinalitySource(_new());
        deps.coreFinalityAdapter = IStreamCoreFinalityAdapter(_new());
        deps.metadataReads = IStreamFinalityMetadataReads(_new());
        deps.metadataHost = _new();
        original = _new();
        current = _new();
        deps.sanctionReads = IStreamFinalitySanctionReads(original);
        deps.finalityDiscovery = _new();
        deps._coreCodeHash = address(deps.coreReads).codehash;
        deps._metadataCodeHash = deps.metadataHost.codehash;
        deps._providerCodeHash = address(deps.metadataReads).codehash;
        deps._adapterCodeHash = address(deps.coreFinalityAdapter).codehash;
        deps._discoveryCodeHash = deps.finalityDiscovery.codehash;
        deps.readGas = 1000000;
        _selected(keccak256("ARTWORK_FINALITY_REGISTRY"), address(host));
        _selected(keccak256("COLLECTION_METADATA"), deps.metadataHost);
        _selected(keccak256("ARTIST_REGISTRY"), current);
        _address(deps.metadataHost, "core()", address(deps.coreReads));
        _address(address(deps.metadataReads), "core()", address(deps.coreReads));
        _address(address(deps.metadataReads), "metadataHost()", deps.metadataHost);
        _address(deps.finalityDiscovery, "scopeEvidenceProvider()", address(deps.metadataReads));
        _address(original, "core()", address(deps.coreReads));
        _address(original, "finalityRegistry()", address(host));
        _put(
            original,
            abi.encodeWithSignature("finalityRegistryCodeHash()"),
            abi.encode(address(host).codehash)
        );
        _address(address(deps.coreFinalityAdapter), "core()", address(deps.coreReads));
        _address(address(deps.coreFinalityAdapter), "collectionMetadata()", deps.metadataHost);
        _address(
            address(deps.coreFinalityAdapter), "evidenceProvider()", address(deps.metadataReads)
        );
        address coordinator = _new();
        route = CA.Route(
            address(host),
            address(host).codehash,
            address(deps.metadataReads),
            deps._providerCodeHash,
            current,
            current.codehash,
            coordinator,
            coordinator.codehash,
            keccak256("selection"),
            keccak256("presentation")
        );
        host.configure(deps, route);
        _put(
            original,
            abi.encodeCall(
                IStreamFinalitySanctionReads.collectionSanctionComponentType, (uint256(7))
            ),
            abi.encode(StreamFinalityDomains.COMPONENT_ARTIST_SANCTION)
        );
        _put(
            current,
            abi.encodeCall(
                IStreamFinalitySanctionReads.collectionSanctionComponentType, (uint256(7))
            ),
            abi.encode(CURRENT_TYPE)
        );
    }

    function _probe(bool legacy) private view {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0);
        StreamFinalityComponentExpectation[] memory components =
            new StreamFinalityComponentExpectation[](0);
        StreamFinalityManifestRef memory manifest;
        host.probe(scope, components, manifest, legacy);
    }

    function _currentReached() private {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityLineagePreparation.FinalitySanctionComponentWrongType.selector,
                StreamFinalityDomains.COMPONENT_ARTIST_SANCTION,
                CURRENT_TYPE
            )
        );
        _probe(false);
    }

    function testNewPreparationReachesCurrentOwnerWhileLegacyRemainsStrict() public {
        _currentReached();
        vm.expectRevert(
            abi.encodeWithSelector(Legacy.FinalityCurrentBindingInvalid.selector, address(host))
        );
        _probe(true);
    }

    function testOriginalArtistReciprocityRemainsRequired() public {
        _address(original, "finalityRegistry()", current);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityLineagePreparation.FinalityCurrentBindingInvalid.selector, original
            )
        );
        _probe(false);
        _address(original, "finalityRegistry()", address(host));
        _currentReached();
    }

    function testCurrentRuntimeAndSelectedPointerMustMatchFullRoute() public {
        route.registryCodeHash = keccak256("wrong code");
        host.configure(deps, route);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityLineagePreparation.FinalityCurrentBindingInvalid.selector, current
            )
        );
        _probe(false);
        route.registryCodeHash = current.codehash;
        host.configure(deps, route);
        _selected(keccak256("ARTIST_REGISTRY"), _new());
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityLineagePreparation.FinalityCurrentBindingInvalid.selector, current
            )
        );
        _probe(false);
    }

    function testProviderAndSelectionCannotBeSubstituted() public {
        route.provider = current;
        route.providerCodeHash = current.codehash;
        host.configure(deps, route);
        vm.expectRevert();
        _probe(false);
        route.provider = address(deps.metadataReads);
        route.providerCodeHash = deps._providerCodeHash;
        route.selectionHash = 0;
        host.configure(deps, route);
        vm.expectRevert();
        _probe(false);
    }

    function testUnpredictedSecondSuccessorUsesItsOwnSanctionReader() public {
        current = _new();
        route.registry = current;
        route.registryCodeHash = current.codehash;
        route.selectionHash = keccak256("second successor");
        host.configure(deps, route);
        _selected(keccak256("ARTIST_REGISTRY"), current);
        _put(
            current,
            abi.encodeCall(
                IStreamFinalitySanctionReads.collectionSanctionComponentType, (uint256(7))
            ),
            abi.encode(CURRENT_TYPE)
        );
        _currentReached();
    }
}
