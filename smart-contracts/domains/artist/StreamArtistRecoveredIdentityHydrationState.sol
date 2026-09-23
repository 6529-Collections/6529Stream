// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistIdentityState } from "./StreamArtistIdentityState.sol";
import { StreamArtistDelegationState } from "./StreamArtistDelegationState.sol";
import { StreamArtistCollaboratorIdentityState } from "./StreamArtistCollaboratorIdentityState.sol";
import { StreamArtistIdentityRevisionState } from "./StreamArtistIdentityRevisionState.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistIdentityContestState } from "./StreamArtistIdentityContestState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistIdentityResolutionState } from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistEstateState } from "./StreamArtistEstateState.sol";
import { StreamArtistUnavailabilityState } from "./StreamArtistUnavailabilityState.sol";
import { StreamArtistIdentityRecoveryState } from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistDormancyState } from "./StreamArtistDormancyState.sol";
import { StreamArtistStewardSanctionState } from "./StreamArtistStewardSanctionState.sol";
import { StreamArtistStewardCapabilityState } from "./StreamArtistStewardCapabilityState.sol";
import { StreamArtistRecoveryAdjudicationState } from "./StreamArtistRecoveryAdjudicationState.sol";
import { StreamArtistRecoveryRewindState } from "./StreamArtistRecoveryRewindState.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Declared-root adapters used only by the fixed recovered Identity workers.
/// @dev The host constructs this array from its exact declared .slot values. No external
/// selector accepts these roots and no function infers offsets between nested State layouts.
library StreamArtistRecoveredIdentityHydrationState {
    struct ReplayRoot {
        mapping(bytes32 => T.ReplayCell) cells;
    }

    function identity(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistIdentityState.State storage s)
    {
        uint256 slot = roots[0];
        assembly ("memory-safe") { s.slot := slot }
    }

    function delegations(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistDelegationState.State storage s)
    {
        uint256 slot = roots[1];
        assembly ("memory-safe") { s.slot := slot }
    }

    function collaboratorAccounts(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistCollaboratorIdentityState.State storage s)
    {
        uint256 slot = roots[2];
        assembly ("memory-safe") { s.slot := slot }
    }

    function revisions(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistIdentityRevisionState.State storage s)
    {
        uint256 slot = roots[3];
        assembly ("memory-safe") { s.slot := slot }
    }

    function rotations(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistRotationState.State storage s)
    {
        uint256 slot = roots[4];
        assembly ("memory-safe") { s.slot := slot }
    }

    function contests(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistIdentityContestState.State storage s)
    {
        uint256 slot = roots[5];
        assembly ("memory-safe") { s.slot := slot }
    }

    function succession(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistSuccessionState.State storage s)
    {
        uint256 slot = roots[6];
        assembly ("memory-safe") { s.slot := slot }
    }

    function resolutions(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistIdentityResolutionState.State storage s)
    {
        uint256 slot = roots[7];
        assembly ("memory-safe") { s.slot := slot }
    }

    function estate(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistEstateState.State storage s)
    {
        uint256 slot = roots[8];
        assembly ("memory-safe") { s.slot := slot }
    }

    function findings(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistUnavailabilityState.State storage s)
    {
        uint256 slot = roots[9];
        assembly ("memory-safe") { s.slot := slot }
    }

    function recovery(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistIdentityRecoveryState.State storage s)
    {
        uint256 slot = roots[10];
        assembly ("memory-safe") { s.slot := slot }
    }

    function dormancy(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistDormancyState.State storage s)
    {
        uint256 slot = roots[11];
        assembly ("memory-safe") { s.slot := slot }
    }

    function sanctions(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistStewardSanctionState.State storage s)
    {
        uint256 slot = roots[12];
        assembly ("memory-safe") { s.slot := slot }
    }

    function stewardCapabilities(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistStewardCapabilityState.State storage s)
    {
        uint256 slot = roots[13];
        assembly ("memory-safe") { s.slot := slot }
    }

    function adjudication(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistRecoveryAdjudicationState.State storage s)
    {
        uint256 slot = roots[14];
        assembly ("memory-safe") { s.slot := slot }
    }

    function rewinds(uint256[17] memory roots)
        internal
        pure
        returns (StreamArtistRecoveryRewindState.State storage s)
    {
        uint256 slot = roots[15];
        assembly ("memory-safe") { s.slot := slot }
    }

    function replay(uint256[17] memory roots) internal pure returns (ReplayRoot storage s) {
        uint256 slot = roots[16];
        assembly ("memory-safe") { s.slot := slot }
    }
}
