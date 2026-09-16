// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "./StreamMetadataTokenRenderer.sol";

/// @notice Current or burned token identity with the original coordinator's canonical entropy.
library StreamMetadataTokenReads {
    struct TokenFacts {
        uint256 tokenId;
        uint256 collectionId;
        uint256 serial;
        bytes32 seed;
        bool finalized;
        string state;
    }

    error InvalidToken(uint256 tokenId);

    function artistJSON(
        mapping(uint256 => IStreamMetadataServingFacts.ArtistPresentation) storage snapshots,
        address registry,
        uint256 collectionId
    ) public view returns (bytes memory) {
        IStreamMetadataServingFacts.ArtistPresentation storage snapshot = snapshots[collectionId];
        if (snapshot.locked) {
            return StreamMetadataTokenRenderer.artistFields(
                snapshot.nominatedArtist, snapshot.identityRecordHash, snapshot.acceptanceRecordHash
            );
        }
        IStreamCollectionArtistRegistry.Attribution memory record =
            IStreamArtistAttribution(registry).attribution(collectionId);
        if (record.artist == address(0)) return ',"artist_attribution":"unaccepted"';
        return StreamMetadataTokenRenderer.artistFields(
            record.artist, record.identityHash, record.acceptanceHash
        );
    }

    function facts(address coreAddress, uint256 tokenId, bool allowBurned)
        public
        view
        returns (TokenFacts memory)
    {
        IStreamCore core = IStreamCore(coreAddress);
        (bool exists, uint256 collectionId, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(tokenId);
        if (!exists || (burned && !allowBurned)) revert InvalidToken(tokenId);
        uint8 lifecycle = core.tokenLifecycle(tokenId);
        if (burned
                ? lifecycle != uint8(StreamTokenLifecycle.BURNED)
                : lifecycle != uint8(StreamTokenLifecycle.MINTED)) {
            revert InvalidToken(tokenId);
        }
        address coordinator = core.coordinatorAtMint(tokenId);
        (bytes32 seed, bool finalized) = IStreamEntropyView(coordinator).tokenSeed(tokenId);
        StreamEntropyStatus entropyStatus =
            IStreamEntropyView(coordinator).tokenEntropyStatus(tokenId);
        string memory state = finalized
            ? "final"
            : entropyStatus == StreamEntropyStatus.STALE
                ? "stale"
                : entropyStatus == StreamEntropyStatus.FAILED ? "failed" : "pending";
        return TokenFacts(tokenId, collectionId, serial, seed, finalized, state);
    }
}
