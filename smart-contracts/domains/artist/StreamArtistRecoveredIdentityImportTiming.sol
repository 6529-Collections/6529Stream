// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";
import {
    StreamArtistRecoveredIdentityHydrationExportRows as Export
} from "./StreamArtistRecoveredIdentityHydrationExportRows.sol";
import {
    StreamArtistRecoveredTimingInventory as Timing
} from "./StreamArtistRecoveredTimingInventory.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed timing phase of the original recovered Identity import.
/// @dev The fixed importer passes the complete canonical Bundle after SourceCodec validation.
/// Linked library calls retain the host's 17 declared roots and storage context.
library StreamArtistRecoveredIdentityImportTiming {
    struct Repudiation {
        uint64 seconds_;
        uint64 revision;
        mapping(bytes32 => bool) actions;
    }

    function install(uint256[17] memory roots, bytes calldata canonical) public {
        IH.Bundle calldata b = Frame.bundle(canonical);
        _timing(roots, b.timing);
    }

    function _timing(uint256[17] memory r, TM.Bundle memory b) private {
        TM.Configuration memory old = Export.configuration(r);
        TM.Configuration memory zero;
        if (
            keccak256(abi.encode(old)) != keccak256(abi.encode(zero))
                && keccak256(abi.encode(old)) != keccak256(abi.encode(b.configuration))
        ) revert TM.RecoveredTimingUnavailable();
        Timing.install(b);
        X.rotations(r).rotationContestSeconds = b.configuration.values[0];
        X.rotations(r).priorStandingTailSeconds = b.configuration.values[1];
        X.estate(r).noticeSeconds = b.configuration.values[2];
        X.dormancy(r).inactivitySeconds = b.configuration.values[3];
        X.dormancy(r).noticeSeconds = b.configuration.values[4];
        X.findings(r).noticeSeconds = b.configuration.values[5];
        _repudiation().seconds_ = b.configuration.values[6];
        X.rotations(r).timingRevision = b.configuration.revisions[0];
        X.estate(r).noticeRevision = b.configuration.revisions[1];
        X.dormancy(r).timingRevision = b.configuration.revisions[2];
        X.findings(r).timingRevision = b.configuration.revisions[3];
        _repudiation().revision = b.configuration.revisions[4];
        for (uint256 i; i < b.entries.length; ++i) {
            TM.Input memory c = b.entries[i].change;
            (, uint8 group,) = Timing.parameter(c.parameter);
            if (group == 0) X.rotations(r).timingActions[c.actionKey] = true;
            else if (group == 1) X.estate(r).timingActions[c.actionKey] = true;
            else if (group == 2) X.dormancy(r).timingActions[c.actionKey] = true;
            else if (group == 3) X.findings(r).timingActions[c.actionKey] = true;
            else _repudiation().actions[c.actionKey] = true;
        }
    }

    function _repudiation() private pure returns (Repudiation storage s) {
        bytes32 slot = keccak256("6529STREAM_ARTIST_REPUDIATION_TIMING_V1");
        assembly ("memory-safe") { s.slot := slot }
    }
}
