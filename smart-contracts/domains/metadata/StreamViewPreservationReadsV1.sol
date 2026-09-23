// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamViewRendererV2 as Renderer
} from "../../interfaces/stream/metadata/IStreamViewRendererV2.sol";
import {
    IStreamViewAdoptionRouter as Router
} from "../../interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
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
import { StreamViewPolicyTypesV2 as T } from "./StreamViewPolicyTypesV2.sol";
import {
    IStreamViewAdoptionPolicyRouterV2 as PolicyRouter
} from "../../interfaces/stream/metadata/IStreamViewAdoptionPolicyRouterV2.sol";
import { StreamViewAdoptionReads as Read } from "./StreamViewAdoptionReads.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

import {
    IStreamViewPreservationRendererV1 as API
} from "../../interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    IStreamPreservationAttributionV1 as Attribution
} from "../../interfaces/stream/metadata/IStreamPreservationAttributionV1.sol";
import { StreamViewPayloadBytes as Bytes } from "./StreamViewPayloadBytes.sol";
import { StreamViewPayloadV2 as Payload } from "./StreamViewPayloadV2.sol";
import { StreamViewRendererEncodingV2 as Encoding } from "./StreamViewRendererEncodingV2.sol";
import {
    StreamScopeMembershipFacts
} from "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import { StreamMetadataSubjects as Subjects } from "./StreamMetadataSubjects.sol";

/// @notice Original adopted VIEW eligibility with explicit non-sanction output composition.
/// @dev Actual live Renderer executes original HTML/token/policy validation; only attribution differs.
library StreamViewPreservationReadsV1 {
    function serve(
        API.Configuration memory c,
        uint256 token,
        bytes32 key,
        bool historical,
        uint8 mode,
        uint256 readGas
    ) public view returns (bytes32, StreamFinalityScope memory, string memory) {
        address router = c.router;
        address core = c.core;
        if (mode != 2 && mode != 3) revert V.InvalidViewAdoption();
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
            record = bytes32(
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
                || r.source.renderer.contextVersion != T.CONTEXT
                || bytes32(
                        Read.word(
                            router,
                            abi.encodeCall(PolicyRouter.viewAdoptionProfile, (record)),
                            readGas
                        )
                    ) != T.PROFILE
        ) revert V.InvalidViewAdoption();
        r.recordHash = 0;
        bytes32 originalHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"),
                T.PROFILE,
                block.chainid,
                router,
                core,
                r
            )
        );
        r.recordHash = record;
        if (originalHash != record) revert V.InvalidViewAdoption();
        Read.pin(r.source.renderer.renderer, r.source.renderer.rendererCodeHash);
        // This public producer derives actual adopted bytes but does not admit itself.
        // The checkpoint separately validates original Registry and preservation admission.
        // Calling the admitting Registry here would introduce a recursive STATIC read roster.
        address renderer = r.source.renderer.renderer;
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
        ) revert V.InvalidViewAdoption();
        Read.pin(targets[2], pins[2]);
        T.Binding memory binding = abi.decode(
            Read.read(renderer, abi.encodeCall(Renderer.policyViewBinding, ()), 736, readGas),
            (T.Binding)
        );
        if (
            binding.sourceSet != targets[2] || binding.sourceSetCodeHash != pins[2]
                || binding.chainId != block.chainid || binding.core != core
                || binding.coreCodeHash != core.codehash
                || keccak256(abi.encode(binding.scope)) != keccak256(abi.encode(r.input.scope))
                || keccak256(abi.encode(binding.membership))
                    != keccak256(abi.encode(r.source.membership))
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_POLICY_VIEW_ADOPTION_SOURCE_V2"),
                            T.PROFILE,
                            block.chainid,
                            router,
                            r.input.scope,
                            r.input.viewId,
                            r.input.viewRecordHash,
                            r.source,
                            binding
                        )
                    ) != r.sourceHash || r.sourceHash != r.input.expectedSourceHash
        ) revert V.InvalidViewAdoption();
        address coordinator =
            Read.addr(core, abi.encodeCall(Core.coordinatorAtMint, (token)), readGas);
        (uint8 status, bytes32 seed,) = abi.decode(
            Read.read(
                coordinator, abi.encodeCall(Entropy.staticTokenRenderFacts, (token)), 96, readGas
            ),
            (uint8, bytes32, address)
        );
        if (status != 5 && !((status == 1 || status == 2) && seed == 0)) {
            revert V.InvalidViewAdoption();
        }
        // This is only the RenderRequest seed. The pinned renderer independently validates
        // the exact constructor-retained coordinator/full policy and terminal request facts.
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
        // The actual retained renderer validates every original token/policy/payload fact.
        // Mode3 has always omitted attribution; its HTML bytes are unchanged.
        _binding(c, renderer, readGas);
        string memory html = _string(
            renderer, abi.encodeCall(Renderer.renderPolicyView, (request, uint8(3))), c.rendererGas
        );
        if (mode == 3) return (record, r.input.scope, html);
        V.Payload memory payload = Payload.decode(Bytes.read(r.source));
        bytes memory raw = Read.bounded(
            c.preservationAttribution,
            abi.encodeCall(Attribution.preservationAttribution, (cid, token)),
            32864,
            c.attributionGas,
            false
        );
        bytes memory artist = abi.decode(raw, (bytes));
        if (
            artist.length == 0 || artist.length > 32768
                || keccak256(raw) != keccak256(abi.encode(artist))
        ) revert V.InvalidViewAdoption();
        string memory result = _encode(
            abi.encodeWithSelector(
                Encoding.output.selector,
                request,
                payload.name,
                payload.description,
                payload.imageURI,
                html,
                artist,
                uint8(2)
            )
        );
        return (record, r.input.scope, result);
    }

    function binding(API.Configuration memory c, bytes32 record, uint256 readGas)
        public
        view
        returns (API.Binding memory)
    {
        V.Record memory r = _retained(c, record, readGas);
        return _binding(c, r.source.renderer.renderer, readGas);
    }

    /// @dev Identity-only immutable carrier proof. The original Router stamps adoptedAt at its
    /// sole authorized commit. Future-time/current eligibility is still required separately by
    /// the checkpoint's original Current.requireCurrent; this STATIC identity read has no clock.
    function _retained(API.Configuration memory c, bytes32 key, uint256 readGas)
        private
        view
        returns (V.Record memory r)
    {
        if (key == 0) revert V.InvalidViewAdoption();
        if (
            bytes32(
                    Read.word(
                        c.router, abi.encodeCall(PolicyRouter.viewAdoptionProfile, (key)), readGas
                    )
                ) != T.PROFILE
        ) revert V.InvalidViewAdoption();
        bytes memory raw = Read.recordBytes(c.router, key, readGas);
        r = abi.decode(raw, (V.Record));
        if (
            keccak256(raw) != keccak256(abi.encode(r)) || r.recordHash != key || r.revision == 0
                || r.actor == address(0) || (r.authorizationClass != 7 && r.authorizationClass != 8)
                || (r.grantCollectionId != 0 && r.grantCollectionId != r.input.scope.collectionId)
                || r.grantRevision == 0 || r.artistConsent == 0 || r.adoptedAt == 0
                || r.aggregate.revision == 0 || r.aggregate.transitionChain == 0
                || r.input.scope.scopeType != StreamFinalityScopeType.VIEW || r.input.viewId == 0
                || r.input.viewRecordHash == 0 || r.input.rendererVersionKey == 0
                || r.source.route.core != c.core || r.source.route.coreCodeHash != c.coreCodeHash
                || r.source.route.router != c.router
                || r.source.route.routerCodeHash != c.routerCodeHash
                || r.source.renderer.contextVersion != T.CONTEXT
        ) revert V.InvalidViewAdoption();
        bytes32 subject = Subjects.scopeSubject(c.chainId, c.core, r.input.scope);
        StreamScopeMembershipFacts memory m = r.source.membership;
        if (
            m.scopeSubject != subject || m.scopeManifestHash == 0 || m.sourceRecordHash == 0
                || m.tokenListHash == 0 || m.membershipHash == 0 || m.inventoryCount != 0
                || m.inventoryPrefixHash != 0
        ) revert V.InvalidViewAdoption();
        Read.pin(r.source.renderer.renderer, r.source.renderer.rendererCodeHash);
        raw = Read.read(
            r.source.renderer.renderer, abi.encodeCall(Renderer.policyViewBinding, ()), 736, readGas
        );
        T.Binding memory binding = abi.decode(raw, (T.Binding));
        if (
            keccak256(raw) != keccak256(abi.encode(binding)) || binding.chainId != c.chainId
                || binding.core != c.core || binding.coreCodeHash != c.coreCodeHash
                || keccak256(abi.encode(binding.scope)) != keccak256(abi.encode(r.input.scope))
                || keccak256(abi.encode(binding.membership))
                    != keccak256(abi.encode(r.source.membership))
        ) revert V.InvalidViewAdoption();
        bytes32 sourceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_ADOPTION_SOURCE_V2"),
                T.PROFILE,
                c.chainId,
                c.router,
                r.input.scope,
                r.input.viewId,
                r.input.viewRecordHash,
                r.source,
                binding
            )
        );
        if (sourceHash != r.sourceHash || sourceHash != r.input.expectedSourceHash) {
            revert V.InvalidViewAdoption();
        }
        r.recordHash = 0;
        bytes32 original = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"),
                T.PROFILE,
                c.chainId,
                c.router,
                c.core,
                r
            )
        );
        r.recordHash = key;
        if (original != key) revert V.InvalidViewAdoption();
    }

    function _binding(API.Configuration memory c, address renderer, uint256 cap)
        private
        view
        returns (API.Binding memory b)
    {
        (address[4] memory targets, bytes32[4] memory pins) = abi.decode(
            Read.read(renderer, abi.encodeCall(Renderer.sourceBindings, ()), 256, cap),
            (address[4], bytes32[4])
        );
        if (
            targets[0] != c.core || pins[0] != c.coreCodeHash || targets[1] != c.router
                || pins[1] != c.routerCodeHash
        ) revert V.InvalidViewAdoption();
        Read.pin(targets[3], pins[3]);
        Read.pin(c.preservationAttribution, c.preservationAttributionCodeHash);
        if (
            Read.addr(c.preservationAttribution, abi.encodeCall(Attribution.core, ()), cap)
                    != c.core
                || Read.addr(c.preservationAttribution, abi.encodeCall(Attribution.router, ()), cap)
                    != c.router
                || Read.addr(
                        c.preservationAttribution,
                        abi.encodeCall(Attribution.liveAttribution, ()),
                        cap
                    ) != targets[3]
                || bytes32(
                        Read.word(
                            c.preservationAttribution,
                            abi.encodeCall(Attribution.liveAttributionCodeHash, ()),
                            cap
                        )
                    ) != pins[3]
                || bytes32(
                        Read.word(
                            c.preservationAttribution,
                            abi.encodeCall(Attribution.preservationAttributionProfile, ()),
                            cap
                        )
                    ) != keccak256("6529STREAM_NON_SANCTION_ATTRIBUTION_V1")
        ) revert V.InvalidViewAdoption();
        bytes memory raw =
            Read.read(renderer, abi.encodeCall(Renderer.encodingBinding, ()), 64, cap);
        (address encoder, bytes32 pin) = abi.decode(raw, (address, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(encoder, pin)) || encoder != address(Encoding)
                || pin != address(Encoding).codehash
        ) revert V.InvalidViewAdoption();
        b = API.Binding(
            c.core,
            c.router,
            renderer,
            renderer.codehash,
            c.preservationAttribution,
            c.preservationAttributionCodeHash
        );
    }

    /// @dev Same fixed formatter STATIC transport as the original renderer. Returning bytes
    /// are bounded before allocation, then canonically decoded. Governed dependency caps above
    /// remain unchanged; the pure formatter consumes only this call's remaining budget.
    function _encode(bytes memory input) private view returns (string memory result) {
        address target = address(Encoding);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (size > 262208) revert V.InvalidViewAdoption();
        bytes memory raw = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, size) }
        if (!ok) assembly ("memory-safe") { revert(add(raw, 32), mload(raw)) }
        result = abi.decode(raw, (string));
        if (bytes(result).length > 262144 || keccak256(raw) != keccak256(abi.encode(result))) {
            revert V.InvalidViewAdoption();
        }
    }

    function _string(address target, bytes memory input, uint256 cap)
        private
        view
        returns (string memory result)
    {
        bytes memory raw = Read.bounded(target, input, 262208, cap, false);
        result = abi.decode(raw, (string));
        if (bytes(result).length > 262144 || keccak256(raw) != keccak256(abi.encode(result))) {
            revert V.InvalidViewAdoption();
        }
    }

    function _currentRoute(V.Route memory route, uint256 cap) private view {
        (address finality, bytes32 fh) =
            Read.selected(route.core, keccak256("ARTWORK_FINALITY_REGISTRY"), cap);
        if (finality != route.finality || fh != route.finalityCodeHash) {
            revert V.InvalidViewAdoption();
        }
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
        if (provider != route.provider || hash != route.providerCodeHash) {
            revert V.InvalidViewAdoption();
        }
        bytes memory raw = Read.read(
            provider, abi.encodeCall(IStreamViewSourceBinding.viewSourceBinding, ()), 192, cap
        );
        if (keccak256(raw) != keccak256(abi.encode(route.binding))) revert V.InvalidViewAdoption();
    }
}
