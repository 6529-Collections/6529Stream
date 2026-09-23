// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistPrimaryCollaboratorIdentitySource as Identity
} from "./StreamArtistPrimaryCollaboratorIdentitySource.sol";
import {
    StreamArtistRecoveredPreparationPayout as Payout
} from "./StreamArtistRecoveredPreparationPayout.sol";
import {
    StreamArtistRecoveredPreparationEvidence as Evidence
} from "./StreamArtistRecoveredPreparationEvidence.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";
import {
    StreamArtistRecoveredExternalGuards as External
} from "./StreamArtistRecoveredExternalGuards.sol";
import {
    StreamArtistRecoveredMultipleObservations as Observations
} from "./StreamArtistRecoveredMultipleObservations.sol";
import {
    StreamArtistUnboundPlatformEmptyIdentity as EmptyIdentity
} from "./StreamArtistUnboundPlatformEmptyIdentity.sol";
import {
    StreamArtistUnboundPlatformCollectionRows as EmptyOwners
} from "./StreamArtistUnboundPlatformCollectionRows.sol";
import { StreamArtistUnboundPlatformTypes as U } from "./StreamArtistUnboundPlatformTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice Fixed actual-state principal collection before complete-history family joins.
/// @dev Class1/3 and ordinary zero-recovery principals use the unchanged canonical Identity
/// collector. A zero-Artist graph has a separate empty certificate, never a synthetic principal.
library StreamArtistCompleteHistoryPreparationPrincipals {
    struct Result {
        CT.Principals principals;
        bytes emptyIdentity;
        TM.Checkpoint timing;
        External.Snapshot externalGuards;
        uint256 features;
    }

    function collectEncoded(Admission.Certificate memory c) public view returns (bytes memory) {
        return abi.encode(collect(c));
    }

    function collect(Admission.Certificate memory c) public view returns (Result memory result) {
        uint256 count = c.artists.length;
        if (
            count > 128 || c.collections.length == 0 || c.collections.length > 128
                || c.provenance.eras.length == 0 || c.provenance.eras.length > RH.MAX_ERAS
        ) _invalid();
        result.principals.identities = new bytes[](count);
        result.principals.payouts = new bytes[](count);
        result.principals.authoritySupplement = new bytes[](count);
        result.features = CT.FEATURE;
        if (c.provenance.eras.length > 1) result.features |= RH.REPEATED_IMPORT;
        if (count == 0) return _empty(c, result);
        M.State memory scope;
        scope.artists = c.artists;
        scope.collections = c.collections;
        RH.OwnerProvenance memory p = RH.ownerProvenance(c.provenance, 2);
        Identity.preparationOwners(c.source.owners[2], scope, p);
        External.Snapshot[] memory observations = new External.Snapshot[](count);
        for (uint256 i; i < count; ++i) {
            if (
                c.artists[i].artistId == 0
                    || (i != 0 && c.artists[i].artistId <= c.artists[i - 1].artistId)
            ) _invalid();
            result.principals.identities[i] = _identity(c, p, i);
            (bytes memory payout, bool continuations) =
                Payout.collect(c.source.owners[5], c.artists[i].artistId, c.provenance);
            result.principals.payouts[i] = Payout.encode(payout, c.provenance);
            TM.Checkpoint memory timing;
            uint256 features;
            bool delegated;
            (observations[i], timing, features, delegated) = Evidence.collect(
                result.principals.identities[i], c.provenance, c.source.owners[2], continuations
            );
            if (i != 0 && keccak256(abi.encode(timing)) != keccak256(abi.encode(result.timing))) {
                _invalid();
            }
            result.timing = timing;
            result.features |= features;
            if (delegated) result.features |= RH.DELEGATED_CONSENT;
        }
        result.externalGuards = Observations.collect(observations);
    }

    /// @notice Recollects every supplied principal through fixed collectors and compares exact bytes.
    /// @dev Supplied bytes are assertions, never authority. Future authority-family support must
    /// extend the fixed Identity/evidence adapter; this entry cannot bypass class or source checks.
    function collectValidated(Admission.Certificate memory c, CT.Principals memory supplied)
        public
        view
        returns (Result memory result)
    {
        result = collect(c);
        if (keccak256(abi.encode(supplied)) != keccak256(abi.encode(result.principals))) {
            _invalid();
        }
    }

    function _identity(Admission.Certificate memory c, RH.OwnerProvenance memory p, uint256 index)
        private
        view
        returns (bytes memory raw)
    {
        bool ok;
        (ok, raw) = address(Identity)
            .staticcall(
                abi.encodeWithSelector(
                    Identity.collect.selector, c.source.owners[2], c.artists[index], p
                )
            );
        raw = Tuple.result(ok, raw);
        Tuple.requireSingle(raw);
    }

    function _empty(Admission.Certificate memory c, Result memory result)
        private
        view
        returns (Result memory)
    {
        for (uint256 i; i < c.collections.length; ++i) {
            if (
                c.collections[i].artistId != 0 || c.collections[i].bindingHash != 0
                    || c.collections[i].policies.length != 0
            ) _invalid();
        }
        (result.emptyIdentity, result.timing) = EmptyIdentity.collect(
            c.source.owners[2], RH.ownerProvenance(c.provenance, 2), c.collections
        );
        RH.OwnerProvenance memory payout = RH.ownerProvenance(c.provenance, 5);
        Provenance.validateOwnerSource(payout, 5, c.source.owners[5]);
        EmptyOwners.empty(payout, 5);
        // Preserve the existing explicit no-principal observation convention. The final
        // complete-history recheck must validate this empty form, as UnboundPlatformCurrent
        // does, instead of passing a zero Artist to External.requireCurrent.
        result.externalGuards.schema = U.TAG;
        result.externalGuards.provenanceCommitment = RH.provenanceHash(c.provenance);
        return result;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
