// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamViewRendererV1 as Renderer
} from "../../interfaces/stream/metadata/IStreamViewRendererV1.sol";
import {
    IStreamViewAdoptionRouter as Router
} from "../../interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import {
    IStreamRendererRegistry as Registry
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamCollectionViews as Views
} from "../../interfaces/stream/metadata/IStreamCollectionViews.sol";
import { IStreamCoreIdentity as Core } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamCoreCollectionView as Collection
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    IStreamStaticEntropySource as Entropy
} from "../../interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewAdoptionReads as Read } from "./StreamViewAdoptionReads.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Fixed STATIC worker. Caller identity is the actual Router; there is no arbitrary source argument.
library StreamViewAdoptionRouting {
    function serveEncoded(bytes calldata original) public view returns (string memory) {
        bytes4 selector = bytes4(original);
        bool historical;
        uint8 mode;
        if (selector == Router.tokenJSONForView.selector) {
            mode = 2;
        } else if (selector == Router.tokenHTMLForView.selector) {
            mode = 3;
        } else if (selector == Router.historicalTokenJSONForView.selector) {
            mode = 2;
            historical = true;
        } else if (selector == Router.historicalTokenHTMLForView.selector) {
            mode = 3;
            historical = true;
        } else {
            revert V.InvalidViewAdoption();
        }
        (uint256 token, bytes32 key) = abi.decode(original[4:], (uint256, bytes32));
        address core = Read.addr(msg.sender, abi.encodeWithSignature("core()"), 100000);
        uint256 readGas = Read.word(
            msg.sender,
            abi.encodeCall(Gas.gasParameter, (keccak256("6529STREAM_GGP_ROUTER_BUNDLE_READ_GAS"))),
            100000
        );
        return _serve(core, token, key, historical, mode, readGas);
    }

    function _serve(
        address core,
        uint256 token,
        bytes32 key,
        bool historical,
        uint8 mode,
        uint256 readGas
    ) private view returns (string memory) {
        if (mode != 2 && mode != 3) revert V.InvalidViewAdoption();
        address router = msg.sender;
        (bool exists, uint256 cid, uint256 serial, bool burned) = abi.decode(
            Read.read(core, abi.encodeCall(Core.tokenCollectionIdentity, (token)), 128, readGas),
            (bool, uint256, uint256, bool)
        );
        if (
            !exists || (!historical && burned)
                || Read.word(core, abi.encodeCall(Core.tokenLifecycle, (token)), readGas)
                    != (burned ? 3 : 2)
        ) revert V.InvalidViewAdoption();
        bytes32 record = key;
        if (!historical) {
            StreamFinalityScope memory scope =
                StreamFinalityScope(StreamFinalityScopeType.VIEW, cid, 0, key);
            record =
                bytes32(
                Read.word(router, abi.encodeCall(Router.viewAdoptionHead, (scope)), readGas)
            );
        }
        bytes memory encoded = Read.recordBytes(router, record, readGas);
        V.Record memory r = abi.decode(encoded, (V.Record));
        if (
            keccak256(encoded) != keccak256(abi.encode(r)) || r.recordHash != record
                || r.input.scope.collectionId != cid || r.source.route.core != core
                || r.source.route.router != router || r.source.route.coreCodeHash != core.codehash
                || r.source.route.routerCodeHash != router.codehash
        ) revert V.InvalidViewAdoption();
        Read.pin(r.source.renderer.renderer, r.source.renderer.rendererCodeHash);
        Read.pin(r.source.renderer.registry, r.source.renderer.registryCodeHash);
        (address renderer, bytes32 pin) = abi.decode(
            Read.read(
                r.source.renderer.registry,
                abi.encodeCall(Registry.requireRetained, (r.source.renderer.versionKey)),
                64,
                readGas
            ),
            (address, bytes32)
        );
        if (renderer != r.source.renderer.renderer || pin != r.source.renderer.rendererCodeHash) {
            revert V.InvalidViewAdoption();
        }
        if (!historical) {
            Read.pin(r.source.route.binding.views, r.source.route.binding.viewsCodeHash);
            (bytes32 selected,) = abi.decode(
                Read.read(
                    r.source.route.binding.views,
                    abi.encodeCall(Views.selectedViewRecord, (cid, r.input.viewId)),
                    64,
                    readGas
                ),
                (bytes32, bool)
            );
            if (selected != r.input.viewRecordHash || r.input.scope.scopeId != key) {
                revert V.InvalidViewAdoption();
            }
            // Current route cannot silently outlive replacement of its selected source roster.
            _currentRoute(r.source.route, readGas);
        }
        Read.pin(r.source.route.binding.membership, r.source.route.binding.membershipCodeHash);
        if (
            Read.word(
                    r.source.route.binding.membership,
                    abi.encodeCall(Membership.scopeCoversToken, (r.input.scope, token)),
                    readGas
                ) != 1
        ) revert V.InvalidViewAdoption();
        (address[4] memory targets, bytes32[4] memory pins) = abi.decode(
            Read.read(renderer, abi.encodeCall(Renderer.sourceBindings, ()), 256, readGas),
            (address[4], bytes32[4])
        );
        if (
            targets[0] != core || targets[1] != router || pins[0] != core.codehash
                || pins[1] != router.codehash
                || Read.addr(core, abi.encodeCall(Core.coordinatorAtMint, (token)), readGas)
                    != targets[2]
        ) revert V.InvalidViewAdoption();
        Read.pin(targets[2], pins[2]);
        (uint8 status, bytes32 seed,) = abi.decode(
            Read.read(
                targets[2], abi.encodeCall(Entropy.staticTokenRenderFacts, (token)), 96, readGas
            ),
            (uint8, bytes32, address)
        );
        if (status != 5) revert V.InvalidViewAdoption();
        bool frozen =
            Read.word(core, abi.encodeCall(Collection.collectionFreezeStatus, (cid)), readGas) == 1;
        R.RenderRequest memory request = R.RenderRequest(
            core,
            token,
            cid,
            serial,
            seed,
            burned
                ? R.TokenRenderState.BURNED
                : frozen ? R.TokenRenderState.FROZEN : R.TokenRenderState.ACTIVE,
            R.MetadataMode.ONCHAIN,
            uint8(Read.word(core, abi.encodeCall(Collection.collectionSupplyMode, (cid)), readGas)),
            uint8(Read.word(core, abi.encodeCall(Collection.collectionStatus, (cid)), readGas)),
            r.input.viewId,
            r.input.viewRecordHash,
            record
        );
        bytes memory input = abi.encodeCall(Renderer.renderView, (request, mode));
        // The Router's original full-view budget encloses this entire fixed worker. Only the
        // remainder goes to the renderer; its governed dependency caps still admit in full.
        uint256 available = gasleft();
        if (available < 400000) revert V.ViewAdoptionGas(available, 400000);
        uint256 cap = available - available / 64 - 250000;
        bytes memory raw = Read.bounded(renderer, input, 262208, cap, false);
        string memory result = abi.decode(raw, (string));
        if (bytes(result).length > 262144 || keccak256(raw) != keccak256(abi.encode(result))) {
            revert V.InvalidViewAdoption();
        }
        return result;
    }

    function _currentRoute(V.Route memory route, uint256 cap) private view {
        (address finality, bytes32 fh) =
            Read.selected(route.core, keccak256("ARTWORK_FINALITY_REGISTRY"), cap);
        if (finality != route.finality || fh != route.finalityCodeHash) revert V.InvalidViewAdoption();
        (address metadata, bytes32 mh) =
            Read.selected(route.core, keccak256("COLLECTION_METADATA"), cap);
        (address artist, bytes32 ah) = Read.selected(route.core, keccak256("ARTIST_REGISTRY"), cap);
        (address router, bytes32 rh) = Read.selected(route.core, keccak256("METADATA_ROUTER"), cap);
        if (
            metadata != route.metadata || mh != route.metadataCodeHash || artist != route.artist
                || ah != route.artistCodeHash || router != route.router
                || rh != route.routerCodeHash
        ) revert V.InvalidViewAdoption();
        address provider =
            Read.addr(finality, abi.encodeWithSignature("scopeEvidenceProvider()"), cap);
        bytes32 hash = bytes32(
            Read.word(finality, abi.encodeWithSignature("scopeEvidenceProviderCodeHash()"), cap)
        );
        Read.pin(provider, hash);
        if (provider != route.provider || hash != route.providerCodeHash) revert V.InvalidViewAdoption();
        bytes memory raw = Read.read(
            provider, abi.encodeCall(IStreamViewSourceBinding.viewSourceBinding, ()), 192, cap
        );
        if (keccak256(raw) != keccak256(abi.encode(route.binding))) revert V.InvalidViewAdoption();
    }
}
