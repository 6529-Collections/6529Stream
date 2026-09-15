// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import {
    IStreamArtistAttribution
} from "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamRevenueResolver as R
} from "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";

import { StreamRevenueArtistSelection } from "./StreamRevenueArtistSelection.sol";

/// @notice Fixed identity reads in the actual Resolver delegatecall context.
/// @dev Every graph coordinate and runtime pin is supplied only from host immutables.
library StreamPrimaryIdentityReads {
    function requireSelectedArtistRegistry(
        address core,
        bytes32 coreCodeHash,
        address artistRegistry,
        bytes32 artistRegistryCodeHash
    ) public view returns (address) {
        if (core.codehash != coreCodeHash) {
            revert R.InvalidPrimaryResolverConfiguration();
        }
        (address selected, bytes32 selectedCodeHash,,,,,,,,) =
            IStreamCore(core).getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (selected != artistRegistry) {
            return StreamRevenueArtistSelection.successor(
                StreamRevenueArtistSelection.Context(
                    core,
                    artistRegistry,
                    artistRegistryCodeHash,
                    selected,
                    selectedCodeHash,
                    true,
                    abi.encodeWithSelector(R.InvalidPrimaryArtistRegistry.selector, selected),
                    0
                )
            );
        }
        if (
            selected.codehash != artistRegistryCodeHash
                || selectedCodeHash != artistRegistryCodeHash
                || IStreamArtistAttribution(selected).core() != core
        ) revert R.InvalidPrimaryArtistRegistry(selected);
        return selected;
    }

    function resolveCollectionIdentity(address core, uint256 suppliedCollectionId, uint256 tokenId)
        public
        view
        returns (uint256 collectionId)
    {
        collectionId = suppliedCollectionId;
        if (tokenId != 0) {
            (bool exists, uint256 mappedCollection,,) =
                IStreamCore(core).tokenCollectionIdentity(tokenId);
            if (
                !exists || mappedCollection == 0
                    || (collectionId != 0 && collectionId != mappedCollection)
            ) {
                revert R.InvalidPrimaryTokenIdentity(tokenId, suppliedCollectionId);
            }
            collectionId = mappedCollection;
        }
        if (collectionId != 0 && !IStreamCore(core).collectionExists(collectionId)) {
            revert R.InvalidPrimaryCollection(collectionId);
        }
    }
}
