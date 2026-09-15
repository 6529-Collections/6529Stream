// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistDormancyReconstructionEvents as D
} from "./IStreamArtistDormancyReconstructionEvents.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";
import { StreamArtistEstateTypes as E } from "./StreamArtistEstateTypes.sol";

/// @notice Supplemental execution facts, separate from the already complete original hash events.
interface IStreamArtistAuthorityReconstructionEvents {
    event ArtistRotationExecutionContext(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recordHash,
        D.Context context,
        R.TransitionState transition,
        uint8 vestedAuthorityClass
    );
    event ArtistEstateExecutionContext(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recordHash,
        D.Context context,
        address incumbent,
        R.TransitionState transition,
        E.ExecutionFacts execution
    );
}
