// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/FinalityServingProviderBoundary.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

contract StreamFinalityServingHostAdapterTest is CharacterizationTestBase {
    MetadataRecoveryCoreBoundary private core;
    MetadataRecoveryRegistryBoundary private registry;
    FinalityServingProfileHostBoundary private host;
    FinalityServingMetadataHostBoundary private metadata;
    FinalityServingProviderBoundary private provider;
    StreamFinalityServingHostAdapter private adapter;
    bytes32 private constant FAMILY = keccak256("SCRIPT_SOURCE");

    function setUp() public {
        core = new MetadataRecoveryCoreBoundary();
        registry = new MetadataRecoveryRegistryBoundary();
        host = new FinalityServingProfileHostBoundary(address(core));
        metadata = new FinalityServingMetadataHostBoundary(address(core));
        provider =
            new FinalityServingProviderBoundary(address(core), address(metadata), address(host));
        adapter = new StreamFinalityServingHostAdapter(
            address(core), address(host), address(provider), FAMILY
        );
    }

    function _select() private {
        core.setPointer(
            keccak256("MODULE_REGISTRY"),
            _pointer(address(registry), keccak256("MODULE_REGISTRY"), 0)
        );
        core.setPointer(
            keccak256("METADATA_ROUTER"),
            _pointer(
                address(host), keccak256("METADATA_ROUTER"), type(IStreamMetadataRouter).interfaceId
            )
        );
        core.setPointer(
            keccak256("COLLECTION_METADATA"),
            _pointer(
                address(metadata),
                keccak256("COLLECTION_METADATA"),
                type(IStreamCollectionMetadataV1).interfaceId
            )
        );
    }

    function _pointer(address t, bytes32 kind, bytes4 id)
        private
        view
        returns (StreamMetadataRecoveryRoutes.Pointer memory)
    {
        return StreamMetadataRecoveryRoutes.Pointer(
            t,
            t.codehash,
            false,
            kind,
            id,
            address(registry),
            1,
            keccak256("module"),
            keccak256("deployment"),
            1
        );
    }

    function testFixedProviderSeparatesActualHostAndExactComponentState() public {
        StreamFinalityComponentState memory s = adapter.finalityState(1);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        StreamFinalityHostComponentFacts memory f = provider.finalityComponentFacts(FAMILY, scope);
        require(
            s.frozen && s.component == address(adapter) && s.componentType == FAMILY
                && s.interfaceId == type(IStreamArtworkFinalityComponent).interfaceId
                && s.codeHash == address(adapter).codehash && s.dataHash == f.dataHash,
            "exact current facts under adapter identity"
        );
        require(
            adapter.host() == address(host) && adapter.evidenceProvider() == address(provider)
                && adapter.metadataHost() == address(metadata),
            "distinct immutable targets"
        );
        scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 9, 0);
        s = adapter.finalityStateForScope(scope);
        require(
            s.interfaceId == type(IStreamArtworkScopedFinalityComponent).interfaceId,
            "scoped component interface"
        );
    }

    function testCurrentSelectionAndLiveEligibilitySeparateFromHistoricalState() public {
        (bool ok,) =
            address(adapter).staticcall(abi.encodeCall(adapter.requireCurrentSelection, ()));
        require(!ok, "unselected");
        _select();
        adapter.requireCurrentSelection();
        bytes32 beforeHash = keccak256(abi.encode(adapter.finalityState(1)));
        registry.setEligible(false);
        (ok,) = address(adapter).staticcall(abi.encodeCall(adapter.requireCurrentSelection, ()));
        require(!ok, "live incident eligibility");
        require(
            keccak256(abi.encode(adapter.finalityState(1))) == beforeHash,
            "history not current eligibility"
        );
        registry.setEligible(true);
        adapter.requireCurrentSelection();
    }

    function testPointerReplacementRetainsHistoricalHostAndRejectsCurrentDiscovery() public {
        _select();
        adapter.requireCurrentSelection();
        bytes32 beforeHash = keccak256(abi.encode(adapter.finalityState(1)));
        FinalityServingProfileHostBoundary successor =
            new FinalityServingProfileHostBoundary(address(core));
        core.setPointer(
            keccak256("METADATA_ROUTER"),
            _pointer(
                address(successor),
                keccak256("METADATA_ROUTER"),
                type(IStreamMetadataRouter).interfaceId
            )
        );
        (bool ok,) =
            address(adapter).staticcall(abi.encodeCall(adapter.requireCurrentSelection, ()));
        require(!ok, "wrong selected host");
        require(
            keccak256(abi.encode(adapter.finalityState(1))) == beforeHash,
            "old pinned host remains exact"
        );
    }

    function testProviderRuntimeAndReciprocalHostDriftRejectThenRestore() public {
        bytes memory code = address(provider).code;
        vm.etch(address(provider), hex"00");
        (bool ok,) = address(adapter).staticcall(abi.encodeCall(adapter.finalityState, (1)));
        require(!ok, "provider runtime");
        vm.etch(address(provider), code);
        adapter.finalityState(1);
        provider.changeHost(address(metadata));
        (ok,) = address(adapter).staticcall(abi.encodeCall(adapter.finalityState, (1)));
        require(!ok, "provider host join");
        provider.changeHost(address(host));
        adapter.finalityState(1);
    }

    function testConstructorRejectsWrongHostAndFamilyWithHealthyControl() public {
        vm.expectRevert();
        new StreamFinalityServingHostAdapter(
            address(core), address(metadata), address(provider), FAMILY
        );
        vm.expectRevert();
        new StreamFinalityServingHostAdapter(
            address(core), address(host), address(provider), keccak256("UNKNOWN")
        );
        new StreamFinalityServingHostAdapter(
            address(core), address(host), address(provider), FAMILY
        );
    }

    function testProviderOwnsFrozenAndScopeInventoryRatherThanAdapterReadiness() public {
        provider.setFrozen(false);
        require(!adapter.finalityState(1).frozen, "actual provider false");
        provider.setFrozen(true);
        require(adapter.finalityState(1).frozen, "provider restored");
        vm.expectRevert();
        adapter.finalityState(2);
        adapter.finalityState(1);
    }
}
