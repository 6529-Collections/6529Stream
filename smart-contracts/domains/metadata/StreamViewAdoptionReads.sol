// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewRouteReadBudgetV1 as ViewBudget
} from "../finality/StreamViewRouteReadBudgetV1.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import "../../interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    IStreamViewAdoptionRouter as ViewRouter
} from "../../interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import { StreamViewPayloadBytes as ViewBytes } from "./StreamViewPayloadBytes.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/metadata/IStreamCollectionViews.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Fixed selected-provider route and full-cap bounded reads for VIEW adoption.
library StreamViewAdoptionReads {
    function route(address core, address artist, address authority)
        public
        view
        returns (V.Route memory r)
    {
        r.core = core;
        r.coreCodeHash = core.codehash;
        r.router = address(this);
        r.routerCodeHash = address(this).codehash;
        r.artist = artist;
        r.artistCodeHash = artist.codehash;
        (r.finality, r.finalityCodeHash) =
            selected(core, keccak256("ARTWORK_FINALITY_REGISTRY"), 100000);
        if (
            addr(artist, abi.encodeCall(IStreamArtistFinalityBinding.finalityRegistry, ()), 100000)
                    != r.finality
                || bytes32(
                        word(
                            artist,
                            abi.encodeCall(
                                IStreamArtistFinalityBinding.finalityRegistryCodeHash, ()
                            ),
                            100000
                        )
                    ) != r.finalityCodeHash
        ) {
            revert V.ViewAdoptionDependency(artist);
        }
        uint256 cap = word(
            r.finality,
            abi.encodeCall(
                IStreamGasParameterHost.gasParameter,
                (keccak256("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS"))
            ),
            100000
        );
        if (cap < 50000 || cap > type(uint32).max) revert V.InvalidViewAdoption();
        bool governedBudget;
        (cap, governedBudget) = ViewBudget.select(r.finality, cap);
        (address router, bytes32 routerHash) = selected(core, keccak256("METADATA_ROUTER"), cap);
        if (
            router != address(this) || routerHash != address(this).codehash
                || addr(
                        r.finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()),
                        cap
                    ) != core
                || addr(
                        r.finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.sanctionReads, ()),
                        cap
                    ) != artist
        ) {
            revert V.InvalidViewAdoption();
        }
        r.provider = addr(
            r.finality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProvider, ()),
            cap
        );
        r.providerCodeHash = bytes32(
            word(
                r.finality,
                abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProviderCodeHash, ()),
                cap
            )
        );
        pin(r.provider, r.providerCodeHash);
        if (
            word(
                    r.provider,
                    abi.encodeCall(
                        IERC165.supportsInterface, (type(IStreamViewSourceBinding).interfaceId)
                    ),
                    cap
                ) != 1
        ) {
            revert V.ViewAdoptionDependency(r.provider);
        }
        bytes memory raw = read(
            r.provider, abi.encodeCall(IStreamViewSourceBinding.viewSourceBinding, ()), 192, cap
        );
        r.binding = abi.decode(raw, (V.Binding));
        if (
            keccak256(raw) != keccak256(abi.encode(r.binding)) || r.binding.readGas < 50000
                || r.binding.sourceGas < r.binding.readGas
                || (governedBudget && r.binding.readGas != cap)
        ) {
            revert V.InvalidViewAdoption();
        }
        pin(r.binding.views, r.binding.viewsCodeHash);
        pin(r.binding.membership, r.binding.membershipCodeHash);
        (r.metadata, r.metadataCodeHash) = selected(core, keccak256("COLLECTION_METADATA"), cap);
        if (
            addr(
                        r.finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.metadataReads, ()),
                        cap
                    ) != r.metadata
                || addr(
                        r.provider,
                        abi.encodeCall(IStreamFinalityEvidenceProvider.metadataHost, ()),
                        cap
                    ) != r.metadata
                || addr(
                        r.metadata,
                        abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ()),
                        cap
                    ) != authority
        ) {
            revert V.ViewAdoptionDependency(r.metadata);
        }
        r.schemas =
            addr(r.metadata, abi.encodeCall(IStreamCollectionMetadataV1.schemaRegistry, ()), cap);
        r.schemasCodeHash = r.schemas.codehash;
        r.store = addr(r.metadata, abi.encodeWithSignature("chunkStore()"), cap);
        r.storeCodeHash = r.store.codehash;
        pin(r.schemas, r.schemasCodeHash);
        pin(r.store, r.storeCodeHash);
        if (
            addr(r.binding.views, abi.encodeCall(IStreamCollectionViews.core, ()), cap) != core
                || addr(
                        r.binding.views,
                        abi.encodeCall(IStreamCollectionViews.metadataHost, ()),
                        cap
                    ) != r.metadata
                || addr(
                        r.binding.views,
                        abi.encodeCall(IStreamCollectionViews.schemaRegistry, ()),
                        cap
                    ) != r.schemas
                || addr(r.binding.views, abi.encodeCall(IStreamCollectionViews.chunkStore, ()), cap)
                    != r.store
                || addr(
                        r.binding.membership,
                        abi.encodeCall(IStreamFinalityScopeMembership.core, ()),
                        cap
                    ) != core
                || addr(
                        r.binding.membership,
                        abi.encodeCall(IStreamFinalityScopeMembership.metadataHost, ()),
                        cap
                    ) != r.metadata
        ) {
            revert V.InvalidViewAdoption();
        }
        (address modules,) = selected(core, keccak256("MODULE_REGISTRY"), cap);
        eligible(
            modules,
            r.metadata,
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            cap
        );
        eligible(
            modules,
            r.binding.views,
            keccak256("COLLECTION_VIEWS"),
            type(IStreamCollectionViews).interfaceId,
            cap
        );
    }

    function recordBytes(address router, bytes32 key, uint256 cap)
        internal
        view
        returns (bytes memory raw)
    {
        (address pointer, bytes32 hash, uint32 size) = abi.decode(
            read(router, abi.encodeCall(ViewRouter.viewAdoptionCarrier, (key)), 96, cap),
            (address, bytes32, uint32)
        );
        if (pointer == address(0)) revert V.UnknownViewAdoption(key);
        ViewBytes.verify(pointer, hash, size);
        raw = new bytes(size);
        assembly ("memory-safe") { extcodecopy(pointer, add(raw, 32), 1, mload(raw)) }
    }

    function eligible(address modules, address target, bytes32 role, bytes4 id, uint256 cap)
        internal
        view
    {
        if (
            word(
                    modules,
                    abi.encodeCall(IStreamModuleRegistry.isModuleEligible, (target, role, id)),
                    cap
                ) != 1
        ) revert V.ViewAdoptionDependency(target);
    }

    function selected(address core, bytes32 key, uint256 cap)
        internal
        view
        returns (address target, bytes32 hash)
    {
        uint8 status;
        uint64 revision;
        (target, hash,,,,, status,,, revision) = abi.decode(
            read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)), 320, cap),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        pin(target, hash);
        if (status != 1 || revision == 0) revert V.ViewAdoptionDependency(target);
    }

    function pin(address target, bytes32 hash) internal view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert V.ViewAdoptionDependency(target);
        }
    }

    function addr(address target, bytes memory input, uint256 cap) internal view returns (address) {
        uint256 v = word(target, input, cap);
        if (v == 0 || v > type(uint160).max) revert V.ViewAdoptionRead(target, bytes4(input));
        return address(uint160(v));
    }

    function word(address target, bytes memory input, uint256 cap) internal view returns (uint256) {
        return abi.decode(read(target, input, 32, cap), (uint256));
    }

    function read(address target, bytes memory input, uint256 size, uint256 cap)
        internal
        view
        returns (bytes memory out)
    {
        return bounded(target, input, size, cap, true);
    }

    function bounded(address target, bytes memory input, uint256 limit, uint256 cap, bool exact)
        internal
        view
        returns (bytes memory out)
    {
        if (target.code.length == 0) revert V.ViewAdoptionDependency(target);
        uint256 required = cap + cap / 63 + 10000;
        if (cap < 50000 || gasleft() <= required) revert V.ViewAdoptionGas(gasleft(), required);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size > limit || (exact && size != limit)) {
            revert V.ViewAdoptionRead(target, bytes4(input));
        }
        out = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(out, 32), 0, size) }
    }
}
