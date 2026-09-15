// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistDormancyReconstructionEvents as D
} from "../../interfaces/stream/artist/IStreamArtistDormancyReconstructionEvents.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistEstateTypes as E
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";

/// @notice Fixed emission worker; caller admission and all original state transitions remain outside.
library StreamArtistAuthorityRecordEvents {
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

    function rotation(
        H.Environment memory e,
        address actor,
        R.TransitionState memory t,
        uint8 class_
    ) public {
        emit ArtistRotationExecutionContext(
            1,
            t.artistId,
            t.recordHash,
            D.Context(e.chainId, e.registry, address(this), actor, 0),
            t,
            class_
        );
    }

    function estate(
        H.Environment memory e,
        address actor,
        address incumbent,
        R.TransitionState memory t,
        E.ExecutionFacts memory execution
    ) public {
        emit ArtistEstateExecutionContext(
            1,
            t.artistId,
            t.recordHash,
            D.Context(e.chainId, e.registry, address(this), actor, 0),
            incumbent,
            t,
            execution
        );
    }
}
