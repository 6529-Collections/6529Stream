// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMetadataRecoveryRoutes.sol";
import "./StreamMetadataTokenReads.sol";
import "./StreamMetadataRenderPreparation.sol";
import "../../interfaces/stream/metadata/IStreamMetadataTokenRendering.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRenderingProfile.sol";

/// @notice Nonrecursive serving of independently selected finality families.
/// @dev First profile is the existing stable presentation/linked renderer ABI. Unsupported
///      mixed context/dependency profiles fail closed. Raw source reads never call tokenURI.
library StreamMetadataFinalityServing {
    bytes32 private constant PROFILE = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
    // Complete cold storage reads include up to 16 KiB token data and 14,592 bytes
    // of Router source fields. Do not rely on a provider incidentally warming them.
    uint256 private constant SOURCE_GAS = 2000000;
    uint256 private constant RENDER_GAS = 8000000;

    struct Sources {
        address display;
        address renderer;
        IStreamMetadataServingFacts.ServingSource metadata;
        bytes artist;
    }
    error MetadataFrozenProfileUnsupported(address target);
    error MetadataFrozenBytesInvalid(address target);
    error InvalidToken(uint256 tokenId);
    error TokenEntropyNotFinalized(uint256 tokenId);

    function token(
        mapping(uint256 => IStreamMetadataServingFacts.ArtistPresentation) storage presentations,
        mapping(uint256 => StreamMetadataRecoveryRoutes.OriginalAnchor) storage anchors,
        StreamMetadataRecoveryRoutes.Environment memory e,
        uint256 id,
        bool allowBurned,
        bool asURI
    ) public view returns (bool frozen, string memory result) {
        (uint256 collection, uint256 serial) = _identity(e.core, id, allowBurned);
        (StreamMetadataRecoveryRoutes.Context memory c, bool active) = StreamMetadataRecoveryRoutes.context(
            e,
            presentations[collection].locked,
            anchors[collection],
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, collection, id, 0)
        );
        if (!active) return (false, "");
        Sources memory s = _sources(c, true);
        return (true, _render(c, serial, s, asURI));
    }

    function _render(
        StreamMetadataRecoveryRoutes.Context memory c,
        uint256 serial,
        Sources memory s,
        bool asURI
    ) private view returns (string memory result) {
        uint256 id = c.scope.tokenId;
        address entropy = StreamMetadataRecoveryRoutes.host(
            c, StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR
        );
        (bytes32 seed, bool finalized) = abi.decode(
            StreamMetadataRecoveryRoutes.read(
                entropy, abi.encodeCall(IStreamEntropyView.tokenSeed, (id)), 64, 150000
            ),
            (bytes32, bool)
        );
        if (!finalized) revert TokenEntropyNotFinalized(id);
        bytes memory encodedData =
            _dynamic(c.core, abi.encodeCall(IStreamCoreMint.tokenData, (id)), 16448, SOURCE_GAS);
        bytes memory data = abi.decode(encodedData, (bytes));
        if (keccak256(encodedData) != keccak256(abi.encode(data))) {
            revert MetadataFrozenBytesInvalid(c.core);
        }
        StreamMetadataRenderTypes.Token memory input = StreamMetadataRenderTypes.Token(
            id, c.scope.collectionId, serial, seed, true, "final", data, true
        );
        bytes memory callData = abi.encodeCall(
            IStreamMetadataTokenRendering.renderForFinality,
            (asURI, abi.encode(input, s.metadata, s.artist))
        );
        bytes memory raw = _dynamic(s.renderer, callData, 65536, RENDER_GAS);
        result = abi.decode(raw, (string));
        if (keccak256(raw) != keccak256(abi.encode(result))) {
            revert MetadataFrozenBytesInvalid(s.renderer);
        }
        return result;
    }

    function collection(
        mapping(uint256 => IStreamMetadataServingFacts.ArtistPresentation) storage presentations,
        mapping(uint256 => StreamMetadataRecoveryRoutes.OriginalAnchor) storage anchors,
        StreamMetadataRecoveryRoutes.Environment memory e,
        uint256 id
    ) public view returns (bool frozen, string memory result) {
        (StreamMetadataRecoveryRoutes.Context memory c, bool active) = StreamMetadataRecoveryRoutes.context(
            e,
            presentations[id].locked,
            anchors[id],
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, id, 0, 0)
        );
        if (!active) return (false, "");
        Sources memory s = _sources(c, false);
        result = StreamMetadataRenderPreparation.collectionURI(
            s.metadata.name, s.metadata.description, s.metadata.imageURI
        );
        return (true, result);
    }

    function _sources(StreamMetadataRecoveryRoutes.Context memory c, bool tokenView)
        private
        view
        returns (Sources memory s)
    {
        uint256 id = c.scope.collectionId;
        s.display =
            StreamMetadataRecoveryRoutes.host(c, StreamFinalityDomains.COMPONENT_METADATA_ROUTER);
        IStreamMetadataServingFacts.ServingFacts memory display = _facts(s.display, id);
        if (!display.displayMetadataLocked || !display.artistIdentityLocked) {
            revert MetadataFrozenProfileUnsupported(s.display);
        }
        IStreamMetadataServingFacts.ServingSource memory d = _source(s.display, id);
        address mediaHost =
            StreamMetadataRecoveryRoutes.host(c, StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST);
        IStreamMetadataServingFacts.ServingFacts memory media = _facts(mediaHost, id);
        IStreamMetadataServingFacts.ServingSource memory m = _source(mediaHost, id);
        if (
            !media.mediaLocked || !media.baseURILocked
                || media.imageURIHash != keccak256(bytes(m.imageURI))
                || media.animationBaseURIHash != keccak256(bytes(m.animationBaseURI))
        ) {
            revert MetadataFrozenProfileUnsupported(mediaHost);
        }
        s.metadata = StreamMetadataRenderPreparation.prepareMetadata(
            d.name, d.description, m.imageURI, m.animationBaseURI
        );
        if (!tokenView) return s;
        s.renderer = _renderer(c, id);
        if (display.mode == keccak256("ONCHAIN")) {
            s.metadata.script = _script(c, id, s.renderer);
        } else if (display.mode != keccak256("OFFCHAIN")) {
            revert MetadataFrozenProfileUnsupported(s.display);
        }
        IStreamMetadataServingFacts.ArtistPresentation memory a = abi.decode(
            StreamMetadataRecoveryRoutes.read(
                s.display,
                abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (id)),
                384,
                150000
            ),
            (IStreamMetadataServingFacts.ArtistPresentation)
        );
        if (
            !a.locked || a.registry == address(0) || a.registryCodeHash == 0 || a.artistId == 0
                || a.bindingGeneration == 0 || a.bindingHash == 0 || a.nominatedArtist == address(0)
                || a.identityRecordHash == 0 || a.acceptanceRecordHash == 0 || a.snapshotHash == 0
        ) {
            revert MetadataFrozenProfileUnsupported(s.display);
        }
        s.artist = StreamMetadataRenderPreparation.artistFields(
            a.nominatedArtist, a.identityRecordHash, a.acceptanceRecordHash
        );
    }

    function _renderer(StreamMetadataRecoveryRoutes.Context memory c, uint256 id)
        private
        view
        returns (address renderer)
    {
        address rendererHost =
            StreamMetadataRecoveryRoutes.host(c, StreamFinalityDomains.COMPONENT_RENDERER);
        IStreamMetadataServingFacts.ServingFacts memory rendering = _facts(rendererHost, id);
        renderer = rendering.renderer;
        if (renderer.code.length == 0 || rendering.rendererCodeHash != renderer.codehash) {
            revert MetadataFrozenProfileUnsupported(rendererHost);
        }
        (bytes32 contextHash,) = _profile(renderer);
        address contextHost =
            StreamMetadataRecoveryRoutes.host(c, StreamFinalityDomains.COMPONENT_RENDER_CONTEXT);
        (bytes32 selectedContext,) = _profile(contextHost);
        if (selectedContext != contextHash) revert MetadataFrozenProfileUnsupported(contextHost);
    }

    function _script(StreamMetadataRecoveryRoutes.Context memory c, uint256 id, address renderer)
        private
        view
        returns (string memory)
    {
        address scriptHost =
            StreamMetadataRecoveryRoutes.host(c, StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
        IStreamMetadataServingFacts.ServingFacts memory script = _facts(scriptHost, id);
        string memory rawScript = _source(scriptHost, id).script;
        if (
            !script.scriptLocked || script.scriptBytes != bytes(rawScript).length
                || bytes(rawScript).length == 0 || script.scriptHash != keccak256(bytes(rawScript))
        ) {
            revert MetadataFrozenProfileUnsupported(scriptHost);
        }
        address dependencyHost =
            StreamMetadataRecoveryRoutes.host(c, StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE);
        IStreamMetadataServingFacts.ServingFacts memory dependencies = _facts(dependencyHost, id);
        (, bytes32 selectedDependencies) = _profile(dependencyHost);
        (, bytes32 dependencyHash) = _profile(renderer);
        if (!dependencies.dependenciesLocked || selectedDependencies != dependencyHash) {
            revert MetadataFrozenProfileUnsupported(dependencyHost);
        }
        return StreamMetadataRenderPreparation.prepareScript(rawScript);
    }

    function _profile(address target)
        private
        view
        returns (bytes32 contextHash, bytes32 dependencyHash)
    {
        bytes32 presentation;
        (presentation, contextHash, dependencyHash) = abi.decode(
            StreamMetadataRecoveryRoutes.read(
                target,
                abi.encodeCall(IStreamMetadataRenderingProfile.renderingProfile, ()),
                96,
                150000
            ),
            (bytes32, bytes32, bytes32)
        );
        if (presentation != PROFILE || contextHash == 0 || dependencyHash == 0) {
            revert MetadataFrozenProfileUnsupported(target);
        }
    }

    function _facts(address host, uint256 id)
        private
        view
        returns (IStreamMetadataServingFacts.ServingFacts memory f)
    {
        f = abi.decode(
            StreamMetadataRecoveryRoutes.read(
                host,
                abi.encodeCall(IStreamMetadataServingFacts.collectionServingFacts, (id)),
                512,
                SOURCE_GAS
            ),
            (IStreamMetadataServingFacts.ServingFacts)
        );
        if (f.presentationProfile != PROFILE || !f.configured) {
            revert MetadataFrozenProfileUnsupported(host);
        }
    }

    function _source(address host, uint256 id)
        private
        view
        returns (IStreamMetadataServingFacts.ServingSource memory s)
    {
        bytes memory raw = _dynamic(
            host,
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingSource, (id)),
            14944,
            SOURCE_GAS
        );
        s = abi.decode(raw, (IStreamMetadataServingFacts.ServingSource));
        if (
            keccak256(raw) != keccak256(abi.encode(s)) || bytes(s.name).length > 256
                || bytes(s.description).length > 2048 || bytes(s.imageURI).length > 2048
                || bytes(s.animationBaseURI).length > 2048 || bytes(s.script).length > 8192
        ) {
            revert MetadataFrozenBytesInvalid(host);
        }
    }

    function _identity(address core, uint256 id, bool allowBurned)
        private
        view
        returns (uint256 cid, uint256 serial)
    {
        bool exists;
        bool burned;
        (exists, cid, serial, burned) = abi.decode(
            StreamMetadataRecoveryRoutes.read(
                core, abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (id)), 128, 150000
            ),
            (bool, uint256, uint256, bool)
        );
        uint8 lifecycle = abi.decode(
            StreamMetadataRecoveryRoutes.read(
                core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (id)), 32, 150000
            ),
            (uint8)
        );
        if (
            !exists || cid == 0 || serial == 0 || (burned && !allowBurned)
                || (burned ? lifecycle != 3 : lifecycle != 2)
        ) revert InvalidToken(id);
    }

    function _dynamic(address target, bytes memory input, uint256 limit, uint256 cap)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(limit);
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) {
            revert StreamMetadataRecoveryRoutes.MetadataRecoveryParentGas(gasleft(), required);
        }
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), limit)
            returned := returndatasize()
        }
        if (!ok || returned > limit || returned < 64) revert MetadataFrozenBytesInvalid(target);
        assembly ("memory-safe") { mstore(output, returned) }
    }
}
