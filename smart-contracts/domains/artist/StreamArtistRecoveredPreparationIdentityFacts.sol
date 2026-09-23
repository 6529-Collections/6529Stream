// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";

/// @notice Exact original preparation projections without copying unrelated Identity records.
/// @dev These pure controls do not authenticate source state; the fixed collector does that first.
library StreamArtistRecoveredPreparationIdentityFacts {
    function timing(IH.Bundle calldata identity) public pure returns (TM.Checkpoint memory) {
        return identity.timing.checkpoint;
    }

    function features(IH.Bundle calldata identity, bool payoutContinuations, uint256 eras)
        public
        pure
        returns (uint256 value, bool hasDelegations)
    {
        value = _class(identity.identity.authorityClass);
        for (uint256 i; i < identity.recoveries.length; ++i) {
            value |= _class(identity.recoveries[i].record.fields.vestedAuthorityClass);
        }
        for (uint256 i; i < identity.actions.length; ++i) {
            if (identity.actions[i].evidenceV2.manifestHash != 0) value |= RH.ADJUDICATION_V2;
            if (identity.actions[i].evidenceV3.manifestHash != 0) value |= RH.REWINDS_V3;
        }
        if (
            identity.revisionContinuations.length != 0 || identity.standingContinuations.length != 0
                || identity.capabilityContinuations.length != 0 || payoutContinuations
        ) {
            value |= RH.REWINDS_V3;
        }
        if (eras > 1) value |= RH.REPEATED_IMPORT;
        if (eras == 0 || eras > RH.MAX_ERAS) revert RH.InvalidRecoveredHydrationProfile();
        hasDelegations = identity.delegations.length != 0;
    }

    function _class(uint8 authorityClass) private pure returns (uint256) {
        if (authorityClass == 1) return RH.CLASS_ONE;
        if (authorityClass == 3) return RH.CLASS_THREE;
        revert T.UnsupportedProfile();
    }

    function nonces(IH.Bundle calldata b, RH.NonceInventory[] calldata nonces) public pure {
        if (b.nonces.length != nonces.length) revert RH.InvalidRecoveredHydrationProvenance();
        for (uint256 i; i < nonces.length; ++i) {
            if (
                b.nonces[i].kind != nonces[i].index.kind || b.nonces[i].key != nonces[i].index.key
                    || keccak256(abi.encode(b.nonces[i].words))
                        != keccak256(abi.encode(nonces[i].words))
            ) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
        }
    }
}
