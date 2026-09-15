// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistDormancyTypes as D } from "./IStreamArtistDormancy.sol";
import { StreamArtistStewardCapabilityTypes as S } from "./IStreamArtistStewardCapabilities.sol";

/// @notice Additive typed event context; no authority, mutation or read selectors.
interface IStreamArtistDormancyReconstructionEvents {
    struct Context {
        uint256 chainId;
        address registry;
        address identityOwner;
        address recorder;
        uint8 recorderAuthorityClass;
    }
    event ArtistDormancyNoticeContext(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recordHash,
        Context context,
        D.Notice notice
    );
    event ArtistDormancyCancellationContext(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recordHash,
        Context context,
        D.Terminal terminal,
        uint256 activityCount
    );
    event ArtistDormancyCompletionContext(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recordHash,
        Context context,
        D.Terminal terminal
    );
    event ArtistStewardCapabilityContext(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recordHash,
        Context context,
        S.Record record
    );
}
