// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistUnboundPlatformPreparation as Unbound } from "./StreamArtistUnboundPlatformPreparation.sol";
import { StreamArtistUnboundPlatformSelectors as UnboundSelectors } from "./StreamArtistUnboundPlatformSelectors.sol";
import { StreamArtistPrimaryCollaboratorSelection as PrimarySelection } from "./StreamArtistPrimaryCollaboratorSelection.sol";
import { StreamArtistPrimaryCollaboratorPreparation as PrimaryPreparation } from "./StreamArtistPrimaryCollaboratorPreparation.sol";
import { StreamArtistRecoveredMultiplePreparation as Multiple } from "./StreamArtistRecoveredMultiplePreparation.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredPreparation as Preparation
} from "./StreamArtistRecoveredPreparation.sol";

import {
    StreamArtistRecoveredPreparationInventory as Inventory
} from "./StreamArtistRecoveredPreparationInventory.sol";

/// @notice Complete seven-owner certificate for the admitted recovered-authority graphs.
/// @dev One recovered class1/class3 subject and one accepted binding without collaborators.
/// Reproposed generations have their own bounded base-Attribution/direct-policy composition.
/// Fixed typed exporters reject unsupported histories; every native occurrence, replay cell and
/// nonce tree must be accounted for. No request witness can replace original producer state.
library StreamArtistRecoveredHydrationPrepared {
    // Preserve the original error ABI; these errors now bubble from the fixed stages.
    error InvalidRecord();
    error InvalidRecoveredHydrationProvenance();

    function collect(T.SuiteConfiguration memory destination, RH.Request memory request)
        public
        view
        returns (Commit.Prepared memory prepared)
    {
        _return(_encode(destination, request, new T.RoyaltyFreeze[](0), true));
    }

    function collect(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory royaltyFreezes
    ) public view returns (Commit.Prepared memory prepared) {
        _return(_encode(destination, request, royaltyFreezes, true));
    }

    /// @notice Read-only certificate construction so callers can compute the expected inventory.
    /// @dev Performs the same complete source checks. The mutation route always calls collect,
    /// which additionally requires the caller's exact nonzero expected inventory.
    function prepare(T.SuiteConfiguration memory destination, RH.Request memory request)
        public
        view
        returns (Commit.Prepared memory prepared)
    {
        _return(_encode(destination, request, new T.RoyaltyFreeze[](0), false));
    }

    /// @notice Additional exact original royalty-freeze terms without changing the old Request.
    /// @dev Complete source history selects the codec; caller witnesses cannot select a subset.
    function prepare(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory royaltyFreezes
    ) public view returns (Commit.Prepared memory prepared) {
        _return(_encode(destination, request, royaltyFreezes, false));
    }

    /// @notice Canonical inventory identifier, independent of the caller's expected value.
    /// @dev Includes complete typed payloads, nonce words, source guards and the timing checkpoint.
    function inventory(Commit.Prepared calldata p) public pure returns (bytes32) {
        return Inventory.inventory(p);
    }

    /// @dev The fixed preparation worker returns abi.encode(Commit.Prepared), exactly the
    /// declared single-tuple return ABI. Forwarding those bytes avoids decoding and re-encoding
    /// the complete certificate in all four entry points. This terminates only this library call;
    /// collect's inventory check has already run inside the fixed worker before it returns.
    function _return(bytes memory encoded) private pure {
        assembly ("memory-safe") {
            return(add(encoded, 0x20), mload(encoded))
        }
    }

    function _encode(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory royalties,
        bool requireInventory
    ) private view returns (bytes memory) {
        if (UnboundSelectors.selected(request.records.authority)) return Unbound.encode(destination, request, royalties, requireInventory);
        if (PrimarySelection.required(destination, request)) {
            return PrimaryPreparation.encode(destination, request, royalties, requireInventory);
        }
        if (
            request.records.authority.artistIds.length > 1
                || request.records.authority.collections.length > 1
        ) {
            return Multiple.encode(destination, request, royalties, requireInventory);
        }
        return Preparation.encode(destination, request, royalties, requireInventory);
    }

    function requiredFeatures(IH.Bundle calldata identity, P.Bundle calldata payout, uint256 eras)
        public
        pure
        returns (uint256 features)
    {
        features = _class(identity.identity.authorityClass);
        for (uint256 i; i < identity.recoveries.length; ++i) {
            features |= _class(identity.recoveries[i].record.fields.vestedAuthorityClass);
        }
        for (uint256 i; i < identity.actions.length; ++i) {
            if (identity.actions[i].evidenceV2.manifestHash != 0) features |= RH.ADJUDICATION_V2;
            if (identity.actions[i].evidenceV3.manifestHash != 0) features |= RH.REWINDS_V3;
        }
        if (
            identity.revisionContinuations.length != 0 || identity.standingContinuations.length != 0
                || identity.capabilityContinuations.length != 0 || payout.continuations.length != 0
        ) {
            features |= RH.REWINDS_V3;
        }
        if (eras > 1) features |= RH.REPEATED_IMPORT;
        if (eras == 0 || eras > RH.MAX_ERAS) revert RH.InvalidRecoveredHydrationProfile();
    }

    function _class(uint8 authorityClass) private pure returns (uint256) {
        if (authorityClass == 1) return RH.CLASS_ONE;
        if (authorityClass == 3) return RH.CLASS_THREE;
        revert T.UnsupportedProfile();
    }
}
