// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
import {
    StreamArtistRecoveredPlatformNativeProof as Native
} from "./StreamArtistRecoveredPlatformNativeProof.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";

/// @notice Original declaration, claim and governance transitions without a fictitious binding.
library StreamArtistUnboundPlatformTimeline {
    function validate(P.Platform memory b, RH.OwnerProvenance memory p) public view {
        Catalogue.requireLocal(p, 4, b.catalogues, b.operations);
        PW.State memory current;
        uint256 count;
        uint256 previousEra;
        uint64 previousRevision;
        for (uint256 i; i < b.operations.length; ++i) {
            H.OperationEvidence memory row = b.operations[i];
            uint256 era = A.era(p, row.originHash);
            H.Envelope memory e = Catalogue.read(p.origins[era], b.catalogues[era], row.evidence);
            if (
                row.operation != e.operation || era < previousEra
                    || (i != 0 && era == previousEra && e.after_[4].revision <= previousRevision)
            ) _invalid();
            previousEra = era;
            previousRevision = e.after_[4].revision;
            // Every original Platform payload starts with the collection ID. The complete
            // canonical payload, actor, governance and owner transition are checked by Native.
            if (!P.nativeOperation(e.operation)) continue;
            uint256 id = abi.decode(e.payload, (uint256));
            if (id != b.collectionId) continue;
            current = Native.advance(b, current, p, era, e);
            ++count;
        }
        PL.Status memory expected;
        expected.originalCorrectionRecord = current.correction.recordHash;
        if (
            count != P.nativeCount(b) || b.continuations.length != 0
                || current.correction.correctiveGeneration != 0 || current.correction.accepted
                || keccak256(abi.encode(current)) != keccak256(abi.encode(b.state))
                || keccak256(abi.encode(expected)) != keccak256(abi.encode(b.status))
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
