// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Shared read-only artist admission for new commercial authorizations.
/// @dev Accrued payments, refunds and historical reads do not depend on this guard.
library StreamSaleArtist {
    error ArtistRegistryBindingChanged(address selected);
    error IncompleteArtistAttribution(uint256 collectionId);

    function supportsAttribution(IStreamArtistAttribution registry) internal view returns (bool) {
        address target = address(registry);
        return target.code.length != 0
            && IERC165(target).supportsInterface(type(IStreamArtistAttribution).interfaceId)
            && !IERC165(target).supportsInterface(0xffffffff);
    }

    function requireArtist(
        IStreamArtistAttribution registry,
        bytes32 admittedCodeHash,
        uint256 collectionId,
        address suppliedArtist
    ) internal view {
        (address selected, bytes32 codeHash,,,,,,,,) = IStreamCorePointers(registry.core())
            .getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (
            selected != address(registry) || codeHash != admittedCodeHash
                || selected.codehash != admittedCodeHash
        ) revert ArtistRegistryBindingChanged(selected);
        address accepted = registry.acceptedArtist(collectionId);
        if (accepted == address(0) || accepted != suppliedArtist) {
            revert IStreamCollectionArtistRegistry.ArtistRegistryArtistMismatch(
                collectionId, accepted, suppliedArtist
            );
        }
        IStreamCollectionArtistRegistry.Attribution memory facts =
            registry.attribution(collectionId);
        if (
            facts.artist != accepted || facts.nominationHash == bytes32(0)
                || facts.acceptanceHash == bytes32(0)
        ) revert IncompleteArtistAttribution(collectionId);
    }
}
