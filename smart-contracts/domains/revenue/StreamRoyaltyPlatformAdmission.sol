// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistPlatformWorks
} from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    IStreamArtistMintConsent
} from "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";
import {
    IStreamArtistAttribution
} from "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import { IStreamRoyaltySnapshot } from "../../interfaces/stream/revenue/IStreamRoyaltySnapshot.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Current PLATFORM_WORKS authority for prepared royalty source use.
/// @dev This proves a declaration, never an Artist consent or narrative's contents.
///      Other modes retain the original bound-Artist economics consumer.
library StreamRoyaltyPlatformAdmission {
    function requireCurrent(
        address core,
        IStreamArtistAttribution artist,
        bytes32 artistRuntime,
        uint256 collectionId
    ) public view returns (bool platform) {
        address target = address(artist);
        if (!IERC165(target).supportsInterface(type(IStreamArtistPlatformWorks).interfaceId)) {
            return false;
        }
        if (IStreamArtistMintConsent(target).consentMode(collectionId) != 3) return false;
        (address selected, bytes32 runtime,,,,,,,,) =
            IStreamCorePointers(core).getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (
            selected != target || runtime == 0 || runtime != artistRuntime
                || target.codehash != runtime || artist.core() != core
                || artist.attribution(collectionId).nominationHash != 0
                || artist.acceptedArtist(collectionId) != address(0)
        ) revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();

        IStreamArtistPlatformWorks registry = IStreamArtistPlatformWorks(target);
        PW.State memory p = registry.platformWorksState(collectionId);
        PW.Correction memory empty;
        (bool declared, bytes32 declaration, uint64 declaredAt) =
            registry.platformWorksDeclaration(collectionId);
        (uint8 contest, bytes32 claim) = registry.platformWorksContest(collectionId);
        (uint64 generation, bytes32 approval) = registry.platformWorksCorrection(collectionId);
        if (
            !declared || declaration == 0 || declaration != p.declaration.recordHash
                || declaredAt != p.declaration.declaredAt || declaredAt > block.timestamp
                || p.declaration.statementHash == 0 || p.declaration.actor == address(0)
                || declaration
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"),
                            block.chainid,
                            target,
                            core,
                            collectionId,
                            p.declaration.statementHash,
                            declaredAt
                        )
                    ) || (p.contestState != 0 && p.contestState != 2) || contest != p.contestState
                || claim != p.contestClaim
                || (contest == 0
                        ? (claim != 0 || p.contestRecord != 0)
                        : (claim == 0 || p.contestRecord == 0)) || generation != 0 || approval != 0
                || keccak256(abi.encode(p.correction)) != keccak256(abi.encode(empty))
        ) revert IStreamRoyaltySnapshot.InvalidRoyaltySnapshot();
        // Permissionless claim count/latest are display facts; filing alone never stops minting.
        return true;
    }
}
