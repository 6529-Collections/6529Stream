// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";

/// @notice Fixed-size canonical artist reads for a presentation snapshot or separate live diagnostics.
/// @dev Linked read helper; caller owns lock authority/storage. Trusted immutable Core and its actual
///      selected facade use available gas. All copied return buffers and accepted shapes are fixed.
library StreamMetadataArtistPresentation {
    error InvalidPresentationRegistry(address registry);
    error InvalidPresentationAssociation(uint256 collectionId);
    error PresentationReadFailed(address target);

    function snapshot(address core, address registry, uint256 collectionId)
        public
        view
        returns (IStreamMetadataServingFacts.ArtistPresentation memory result)
    {
        (
            IStreamMetadataServingFacts.LiveArtistStatus memory state,
            IStreamCollectionArtistRegistry.Attribution memory attribution
        ) = _facts(core, registry, collectionId);
        if (
            (state.attributionState != 2 && state.attributionState != 3)
                || state.artistId == bytes32(0) || state.bindingGeneration == 0
                || state.bindingHash == bytes32(0) || attribution.nominatedArtist == address(0)
                || attribution.identityHash == bytes32(0)
                || attribution.acceptanceHash == bytes32(0) || block.timestamp > type(uint64).max
        ) revert InvalidPresentationAssociation(collectionId);
        result.locked = true;
        result.registry = registry;
        result.registryCodeHash = registry.codehash;
        result.artistId = state.artistId;
        result.bindingGeneration = state.bindingGeneration;
        result.bindingHash = state.bindingHash;
        result.nominatedArtist = attribution.nominatedArtist;
        result.identityRecordHash = attribution.identityHash;
        result.acceptanceRecordHash = attribution.acceptanceHash;
        result.acceptedAt = attribution.acceptedAt;
        result.lockedAt = uint64(block.timestamp);
        result.snapshotHash = _hash(core, collectionId, result);
    }

    function _hash(
        address core,
        uint256 collectionId,
        IStreamMetadataServingFacts.ArtistPresentation memory p
    ) private view returns (bytes32) {
        bytes32[15] memory words;
        words[0] = keccak256("6529STREAM_ROUTER_ARTIST_PRESENTATION_V1");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(core)));
        words[3] = bytes32(uint256(uint160(address(this))));
        words[4] = bytes32(collectionId);
        words[5] = bytes32(uint256(uint160(p.registry)));
        words[6] = p.registryCodeHash;
        words[7] = p.artistId;
        words[8] = bytes32(uint256(p.bindingGeneration));
        words[9] = p.bindingHash;
        words[10] = bytes32(uint256(uint160(p.nominatedArtist)));
        words[11] = p.identityRecordHash;
        words[12] = p.acceptanceRecordHash;
        words[13] = bytes32(uint256(p.acceptedAt));
        words[14] = bytes32(uint256(p.lockedAt));
        return keccak256(abi.encode(words));
    }

    function live(address core, address registry, uint256 collectionId)
        public
        view
        returns (IStreamMetadataServingFacts.LiveArtistStatus memory result)
    {
        (result,) = _facts(core, registry, collectionId);
    }

    function _facts(address core, address registry, uint256 collectionId)
        private
        view
        returns (
            IStreamMetadataServingFacts.LiveArtistStatus memory result,
            IStreamCollectionArtistRegistry.Attribution memory attribution
        )
    {
        _registry(core, registry);
        result.registry = registry;
        (
            result.attributionState,
            result.bindingGeneration,
            result.artistId,
            result.authorityStatus,
            result.bindingHash
        ) =
            abi.decode(
                _read(
                    registry,
                    abi.encodeCall(
                        IStreamArtistAttributionState.collectionArtistState, (collectionId)
                    ),
                    160
                ),
                (uint8, uint64, bytes32, uint8, bytes32)
            );
        attribution = abi.decode(
            _read(
                registry, abi.encodeCall(IStreamArtistAttribution.attribution, (collectionId)), 224
            ),
            (IStreamCollectionArtistRegistry.Attribution)
        );
        if (
            result.attributionState > 5 || result.bindingHash != attribution.nominationHash
                || result.bindingGeneration != attribution.nominationRevision
        ) revert InvalidPresentationAssociation(collectionId);
        result.currentAuthority = attribution.artist;
    }

    function _registry(address core, address registry) private view {
        bytes memory pointer = _read(
            core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("ARTIST_REGISTRY"))),
            320
        );
        uint256 selected;
        bytes32 codeHash;
        assembly ("memory-safe") {
            selected := mload(add(pointer, 32))
            codeHash := mload(add(pointer, 64))
        }
        if (
            registry.code.length == 0 || selected != uint256(uint160(registry))
                || codeHash != registry.codehash
                || abi.decode(
                        _read(registry, abi.encodeCall(IStreamArtistAttribution.core, ()), 32),
                        (address)
                    ) != core
        ) revert InvalidPresentationRegistry(registry);
        if (
            abi.decode(
                    _read(
                        registry,
                        abi.encodeCall(
                            IERC165.supportsInterface,
                            (type(IStreamArtistAttributionState).interfaceId)
                        ),
                        32
                    ),
                    (uint256)
                ) != 1
        ) revert InvalidPresentationRegistry(registry);
    }

    function _read(address target, bytes memory input, uint256 length)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(length);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(input, 32), mload(input), add(output, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert PresentationReadFailed(target);
    }
}
