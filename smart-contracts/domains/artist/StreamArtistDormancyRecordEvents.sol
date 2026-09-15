// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistDormancyReconstructionEvents as E
} from "../../interfaces/stream/artist/IStreamArtistDormancyReconstructionEvents.sol";
import {
    StreamArtistDormancyTypes as D
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistStewardCapabilityTypes as S
} from "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";

/// @notice Fixed emission worker. DELEGATECALL preserves the actual Identity event emitter.
/// @dev Called after the original event and state writes; never decides admission or changes state.
library StreamArtistDormancyRecordEvents {
    event ArtistDormancyNoticeContext(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recordHash,
        E.Context context,
        D.Notice notice
    );
    event ArtistDormancyCancellationContext(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recordHash,
        E.Context context,
        D.Terminal terminal,
        uint256 activityCount
    );
    event ArtistDormancyCompletionContext(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recordHash,
        E.Context context,
        D.Terminal terminal
    );
    event ArtistStewardCapabilityContext(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed recordHash,
        E.Context context,
        S.Record record
    );

    function notice(H.Environment memory e, D.Notice memory n, address recorder) public {
        emit ArtistDormancyNoticeContext(
            1,
            n.terms.artistId,
            n.recordHash,
            E.Context(e.chainId, e.registry, address(this), recorder, 0),
            n
        );
    }

    function cancellation(
        H.Environment memory e,
        bytes32 artistId,
        D.Terminal memory t,
        uint256 count
    ) public {
        emit ArtistDormancyCancellationContext(
            1,
            artistId,
            t.recordHash,
            E.Context(e.chainId, e.registry, address(this), t.actor, t.authorityClass),
            t,
            count
        );
    }

    function completion(H.Environment memory e, bytes32 artistId, D.Terminal memory t) public {
        emit ArtistDormancyCompletionContext(
            1,
            artistId,
            t.recordHash,
            E.Context(e.chainId, e.registry, address(this), t.actor, 0),
            t
        );
    }

    function grant(H.Environment memory e, S.Record memory r) public {
        emit ArtistStewardCapabilityContext(
            1,
            r.terms.artistId,
            r.recordHash,
            E.Context(e.chainId, e.registry, address(this), r.executor, 0),
            r
        );
    }
}
