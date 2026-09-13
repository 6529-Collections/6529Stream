// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRenderingProfile.sol";
import "../../interfaces/stream/modules/IStreamModule.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";

/// @notice Actual, family-separated source commitments for the stable Router profile.
/// @dev Callers supply constructor-fixed bindings. No routed tokenURI, adapter or provider is read.
library StreamFinalityRouterEvidence {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
    bytes32 private constant DOMAIN = keccak256("6529STREAM_ROUTER_COMPONENT_EVIDENCE_V1");

    struct Config {
        address core;
        address router;
        uint256 chainId;
        uint256 readGas;
        uint256 sourceGas;
    }

    error RouterEvidenceRead(address target, bytes4 selector);
    error RouterEvidenceGas(uint256 available, uint256 required);
    error RouterEvidenceProfile(address target);
    error RouterEvidenceFamily(bytes32 family);

    function supported(bytes32 family) internal pure returns (bool) {
        return family == StreamFinalityDomains.COMPONENT_METADATA_ROUTER
            || family == StreamFinalityDomains.COMPONENT_RENDERER
            || family == StreamFinalityDomains.COMPONENT_RENDER_CONTEXT
            || family == StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST
            || family == StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE
            || family == StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE;
    }

    /// @notice Read immutable module facts once when constructing the fixed provider.
    /// @dev Copy only the manifest ABI header, not its unbounded informational URI. The call's
    ///      budget is explicit; it is not a claim that all possible URI lengths fit one gas cap.
    function moduleIdentity(address router, uint256 cap)
        public
        view
        returns (bytes32 version, bytes32 manifest)
    {
        version = abi.decode(
            read(router, abi.encodeCall(IStreamModule.streamModuleVersion, ()), 32, cap), (bytes32)
        );
        bytes memory input = abi.encodeCall(IStreamModule.streamModuleManifest, ());
        bytes memory head = new bytes(96);
        _gas(cap);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, router, add(input, 32), mload(input), add(head, 32), 96)
            returned := returndatasize()
        }
        (uint256 offset, bytes32 hash, uint256 length) =
            abi.decode(head, (uint256, bytes32, uint256));
        if (
            !ok || returned < 96 || offset != 64 || length > type(uint256).max - 127
                || returned != 96 + ((length + 31) / 32) * 32 || hash == 0 || version == 0
        ) {
            revert RouterEvidenceRead(router, IStreamModule.streamModuleManifest.selector);
        }
        manifest = hash;
    }

    function facts(Config memory c, bytes32 family, StreamFinalityScope memory scope)
        public
        view
        returns (bool frozen, bytes32 dataHash)
    {
        if (!supported(family)) revert RouterEvidenceFamily(family);
        bytes32 payload;
        if (
            family == StreamFinalityDomains.COMPONENT_RENDER_CONTEXT
                || family == StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE
        ) {
            (bytes32 presentation, bytes32 context, bytes32 dependencies) = abi.decode(
                read(
                    c.router,
                    abi.encodeCall(IStreamMetadataRenderingProfile.renderingProfile, ()),
                    96,
                    c.readGas
                ),
                (bytes32, bytes32, bytes32)
            );
            if (
                presentation != PROFILE
                    || context != keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1")
                    || dependencies != keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")
            ) {
                revert RouterEvidenceProfile(c.router);
            }
            // These exact profiles are immutable and have no configurable external reads.
            frozen = true;
            payload = family == StreamFinalityDomains.COMPONENT_RENDER_CONTEXT
                ? keccak256(abi.encode(presentation, context))
                : keccak256(abi.encode(dependencies));
        } else {
            IStreamMetadataServingFacts.ServingFacts memory f = serving(c, scope.collectionId);
            if (family == StreamFinalityDomains.COMPONENT_RENDERER) {
                frozen = f.dependenciesLocked && f.renderer.code.length != 0;
                payload = keccak256(abi.encode(f.renderer, f.rendererCodeHash));
            } else if (family == StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST) {
                frozen = f.mediaLocked && f.baseURILocked;
                payload = keccak256(abi.encode(f.imageURIHash, f.animationBaseURIHash));
            } else if (family == StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE) {
                frozen = f.scriptLocked;
                payload = keccak256(abi.encode(f.scriptHash, f.scriptBytes));
            } else {
                (frozen, payload) = _display(c, scope.collectionId, f);
            }
        }
        dataHash =
            keccak256(abi.encode(DOMAIN, c.chainId, c.core, c.router, family, scope, payload));
    }

    function serving(Config memory c, uint256 collectionId)
        public
        view
        returns (IStreamMetadataServingFacts.ServingFacts memory f)
    {
        f = abi.decode(
            read(
                c.router,
                abi.encodeCall(IStreamMetadataServingFacts.collectionServingFacts, (collectionId)),
                512,
                c.sourceGas
            ),
            (IStreamMetadataServingFacts.ServingFacts)
        );
        if (
            f.presentationProfile != PROFILE
                || (f.mode != keccak256("ONCHAIN") && f.mode != keccak256("OFFCHAIN"))
                || f.scriptBytes > 8192 || (f.scriptBytes == 0) != (f.mode == keccak256("OFFCHAIN"))
        ) {
            revert RouterEvidenceProfile(c.router);
        }
        // Renderer liveness belongs only to its family, not to media/script/display history.
    }

    function _display(
        Config memory c,
        uint256 collectionId,
        IStreamMetadataServingFacts.ServingFacts memory f
    ) private view returns (bool frozen, bytes32 payload) {
        bytes memory raw = dynamicRead(
            c.router,
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingSource, (collectionId)),
            14976,
            c.sourceGas
        );
        IStreamMetadataServingFacts.ServingSource memory s =
            abi.decode(raw, (IStreamMetadataServingFacts.ServingSource));
        if (
            keccak256(raw) != keccak256(abi.encode(s)) || bytes(s.name).length > 256
                || bytes(s.description).length > 2048 || bytes(s.imageURI).length > 2048
                || bytes(s.animationBaseURI).length > 2048 || bytes(s.script).length > 8192
        ) {
            revert RouterEvidenceProfile(c.router);
        }
        IStreamMetadataServingFacts.ArtistPresentation memory p = abi.decode(
            read(
                c.router,
                abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (collectionId)),
                384,
                c.readGas
            ),
            (IStreamMetadataServingFacts.ArtistPresentation)
        );
        if (
            p.locked != f.artistIdentityLocked
                || (p.locked
                    && (p.snapshotHash == 0
                        || p.registry == address(0)
                        || p.registryCodeHash == 0
                        || p.artistId == 0
                        || p.bindingGeneration == 0
                        || p.bindingHash == 0
                        || p.nominatedArtist == address(0)
                        || p.identityRecordHash == 0
                        || p.acceptanceRecordHash == 0))
        ) {
            revert RouterEvidenceProfile(c.router);
        }
        frozen = f.configured && f.displayMetadataLocked && p.locked;
        payload = keccak256(
            abi.encode(
                PROFILE,
                f.configured,
                f.mode,
                keccak256(bytes(s.name)),
                keccak256(bytes(s.description)),
                p
            )
        );
    }

    function read(address target, bytes memory input, uint256 size, uint256 cap)
        internal
        view
        returns (bytes memory out)
    {
        out = dynamicRead(target, input, size, cap);
        if (out.length != size) revert RouterEvidenceRead(target, bytes4(input));
    }

    function dynamicRead(address target, bytes memory input, uint256 maximum, uint256 cap)
        internal
        view
        returns (bytes memory out)
    {
        _gas(cap);
        out = new bytes(maximum);
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(out, 32), maximum)
            returned := returndatasize()
        }
        if (!ok || returned > maximum) revert RouterEvidenceRead(target, bytes4(input));
        assembly ("memory-safe") { mstore(out, returned) }
    }

    function _gas(uint256 cap) private view {
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) revert RouterEvidenceGas(gasleft(), required);
    }
}
