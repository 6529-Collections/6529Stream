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
    StreamArtistRecoveredPlatformBindingSource as Original
} from "./StreamArtistRecoveredPlatformBindingSource.sol";

library StreamArtistRecoveredHistoryRecordBindingProof {
    function validate(bytes memory raw, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
    {
        bytes[5] memory members = Parts.members(raw);
        CB.Bundle memory binding = abi.decode(members[3], (CB.Bundle));
        D.Bundle memory history = abi.decode(members[0], (D.Bundle));
        P.Platform memory platform = abi.decode(members[2], (P.Platform));
        if (keccak256(members[3]) != keccak256(abi.encode(binding))) _invalid();
        Original.requireMatches(binding, history.generations, platform.collectionId, q, p);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
