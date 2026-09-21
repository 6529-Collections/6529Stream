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
    StreamArtistRecoveredHistoryRecordFacts as Facts
} from "./StreamArtistRecoveredHistoryRecordFacts.sol";
import {
    StreamArtistRecoveredAttestationHydration as Attest
} from "./StreamArtistRecoveredAttestationHydration.sol";

library StreamArtistRecoveredHistoryRecordFactsFrame {
    function frame(
        bytes memory raw,
        bytes memory consent,
        AH.Query memory q,
        RH.Provenance memory p
    ) public pure returns (bytes memory) {
        bytes[5] memory members = Parts.members(raw);
        CB.Bundle memory binding = abi.decode(members[3], (CB.Bundle));
        D.Bundle memory history = abi.decode(members[0], (D.Bundle));
        Attest.Bundle memory records = abi.decode(members[4], (Attest.Bundle));
        return abi.encode(
            Facts.Context(binding.bindings, history, consent, abi.encode(records.records), q, p)
        );
    }
}
