// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import {
    StreamArtistRecoveryStagingHistory as Stages
} from "./StreamArtistRecoveryStagingHistory.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";

/// @notice Current original ACTIVE1 compromise facts after an admitted living recovery.
/// @dev The caller supplies its fixed owner and authenticates the current principal, executed
/// ancestry, maturity and any pending rotation's predecessor. This reader does not dismiss the
/// cause, synthesize a closure or replay historical authorization.
import {
    StreamArtistCurrentCompromiseReadsKernel as Kernel
} from "./StreamArtistCurrentCompromiseReadsKernel.sol";

library StreamArtistCurrentCompromiseReads {
    error UnsupportedIdentityRecoveryProfile(bytes32 artistId);

    struct Facts {
        C.Record contest;
        R.RotationRecord pending;
        bytes32 proof;
    }

    struct Environment {
        address owner;
        address registry;
        uint256 chainId;
    }

    function read(
        address owner,
        address registry,
        uint256 chainId,
        D.Cause memory current,
        R.TransitionState memory executed
    ) public view returns (Facts memory f) {
        return Kernel.readOriginal(owner, registry, chainId, current, executed);
    }

    /// @notice Read an original current compromise or standing veto for living or estate recovery.
    /// @dev The caller authenticates the first/repeated recovery profile, actual authority origin,
    /// ancestry and maturity. Only living authority may have no executed predecessor. Standing
    /// vetoes retain an empty Contest: their original cause and rotation-veto replay are the proof.
    function readFamily(
        address owner,
        address registry,
        uint256 chainId,
        D.Cause memory current,
        R.TransitionState memory executed
    ) public view returns (Facts memory f) {
        return Kernel.readFamily(owner, registry, chainId, current, executed, true, false);
    }

    /// @notice Original cause consumed by a caller-authenticated admitted operation35.
    /// @dev The caller must prove that recovery's native consumption replay. No live head is
    /// substituted for the original captured execution or pending transition.
    function readConsumed(
        address owner,
        address registry,
        uint256 chainId,
        D.Cause memory current,
        R.TransitionState memory executed
    ) public view returns (Facts memory f) {
        return Kernel.readFamily(owner, registry, chainId, current, executed, false, false);
    }

    /// @dev The fixed notice reader separately authenticates the original phase1/2 lifecycle.
    function readNotice(
        address owner,
        address registry,
        uint256 chainId,
        D.Cause memory current,
        R.TransitionState memory executed
    ) public view returns (Facts memory) {
        return Kernel.readFamily(owner, registry, chainId, current, executed, true, true);
    }

    /// @dev The caller also proves the original35 consumption and notice cancellation.
    function readConsumedNotice(
        address owner,
        address registry,
        uint256 chainId,
        D.Cause memory current,
        R.TransitionState memory executed
    ) public view returns (Facts memory) {
        return Kernel.readFamily(owner, registry, chainId, current, executed, false, true);
    }
}
