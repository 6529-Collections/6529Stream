// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamStaticArtistReads } from "./StreamStaticArtistReads.sol";
import { StreamMetadataDisplayParameters as Gas } from "./StreamMetadataDisplayParameters.sol";

/// @notice Named read-only Metadata companion for the original complete AA-DISPLAY facts.
/// @dev Its own code path uses only bounded STATICCALLs and internal pure encoding. These
/// constructor pins and every transitive read target belong in the renderer admission read set.
/// A failed canonical read reverts here; only the renderer's bounded outer frame reports
/// attribution_unavailable. No state is inferred from a failed read or preserved display name.
contract StreamStaticAttributionCompanion {
    address public immutable core;
    address public immutable router;
    address public immutable artist;
    bytes32 public immutable artistCodeHash;
    address public immutable originalFinality;
    bytes32 public immutable originalFinalityCodeHash;
    uint256 public immutable sourceChainId;

    constructor(
        address core_,
        address router_,
        address artist_,
        address finality_,
        address executor
    ) {
        require(
            core_.code.length != 0 && router_.code.length != 0 && artist_.code.length != 0
                && finality_.code.length != 0
        );
        core = core_;
        router = router_;
        artist = artist_;
        artistCodeHash = artist_.codehash;
        originalFinality = finality_;
        originalFinalityCodeHash = finality_.codehash;
        sourceChainId = block.chainid;
        Gas.initialize(executor);
    }

    function attribution(uint256 collectionId, uint256 tokenId)
        external
        view
        returns (bytes memory)
    {
        return StreamStaticArtistReads.object(
            router,
            sourceChainId,
            core,
            artist,
            artistCodeHash,
            originalFinality,
            originalFinalityCodeHash,
            collectionId,
            tokenId
        );
    }
}
