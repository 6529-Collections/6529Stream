// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredHistoryOrder as Order
} from "./StreamArtistRecoveredHistoryOrder.sol";

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistEstateState as EstateState } from "./StreamArtistEstateState.sol";
import { StreamArtistEstateHashes } from "./StreamArtistEstateHashes.sol";
import {
    StreamArtistIdentityContestState as ContestState
} from "./StreamArtistIdentityContestState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistRecoveryEstateGuardians as EstateGuardians
} from "./StreamArtistRecoveryEstateGuardians.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryEstateHistory as EstateHistory
} from "./StreamArtistRecoveryEstateHistory.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

import {
    StreamArtistRecoveryEstateEvidence as Evidence
} from "./StreamArtistRecoveryEstateEvidence.sol";

/// @notice Fixed typed recovery read worker; preserves the original host context and checks.
library StreamArtistRecoveryEstatePlan {
    function _directive(
        StreamArtistRotationState.State storage rotations,
        StreamArtistHashes.Environment memory e,
        Estate.RequestRecord memory request,
        Succ.DirectiveRecord memory d,
        bytes32 hash,
        bool hasAncestry
    ) public view {
        if (hash == 0) {
            Succ.DirectiveRecord memory empty;
            if (keccak256(abi.encode(d)) != keccak256(abi.encode(empty))) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(request.terms.artistId);
            }
            return;
        }
        if (
            d.recordHash != hash || d.terms.artistId != request.terms.artistId
                || d.authorityClass != 1 || d.signer == address(0)
                || (!hasAncestry && d.signer != request.incumbent)
                || d.signedAt > request.requestedAt
                || !_planAssociation(rotations, request.terms.artistId, d.provisional, hasAncestry)
                || StreamArtistSuccessionHashes.directiveRecord(
                        Evidence._recordEnvironment(e, 37, d.terms.artistId, d.recordHash),
                        d.terms,
                        T.Authorization(d.nonce, d.signedAt, bytes(""))
                    ) != hash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(request.terms.artistId);
    }

    function _planAssociation(
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId,
        R.ProvisionalAssociation memory a,
        bool hasAncestry
    ) public view returns (bool) {
        if (!hasAncestry) {
            return a.transitionRecordHash == 0 && a.windowEndsAt == 0;
        }
        return StreamArtistRotationState.eligible(rotations, artistId, a);
    }
}
