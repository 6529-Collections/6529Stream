// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHistoryRecordParts as Parts
} from "./StreamArtistRecoveredHistoryRecordParts.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredPlatformTimeline as Original
} from "./StreamArtistRecoveredPlatformTimeline.sol";

library StreamArtistRecoveredHistoryRecordTimeline {
    function validate(bytes memory raw, RH.OwnerProvenance memory p)
        public
        view
        returns (RH.Point[] memory proposals, RH.Point[] memory completions)
    {
        bytes[5] memory members = Parts.members(raw);
        CB.Bundle memory binding = abi.decode(members[3], (CB.Bundle));
        D.Bundle memory history = abi.decode(members[0], (D.Bundle));
        P.Platform memory platform = abi.decode(members[2], (P.Platform));
        return Original.validateWithRecords(platform, binding, history.generations, p);
    }
}
