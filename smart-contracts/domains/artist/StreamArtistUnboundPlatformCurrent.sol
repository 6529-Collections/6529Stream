// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import { StreamArtistUnboundPlatformCodec as Codec } from "./StreamArtistUnboundPlatformCodec.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
import {
    StreamArtistRecoveredExternalGuards as External
} from "./StreamArtistRecoveredExternalGuards.sol";
import { StreamArtistUnboundPlatformTypes as U } from "./StreamArtistUnboundPlatformTypes.sol";
import {
    StreamArtistUnboundPlatformEmptyIdentity as Empty
} from "./StreamArtistUnboundPlatformEmptyIdentity.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";

/// @notice Post-write whole Archive re-observation; zero-principal guard has an explicit new tag.
library StreamArtistUnboundPlatformCurrent {
    function recheck(
        RH.Provenance memory full,
        AH.Query memory q,
        bytes memory attribution,
        bytes memory identity,
        External.Snapshot memory external_
    ) public view returns (bool emptyPrincipal) {
        if (!Codec.selected(attribution, 4)) return false;
        (M.State memory scope,) = Codec.outer(4, q, attribution);
        for (uint256 i; i < scope.collections.length; ++i) {
            if (scope.collections[i].artistId != 0) continue;
            P.Platform memory b = abi.decode(scope.rows[i], (P.Platform));
            Catalogue.requireCurrent(full, b.catalogues, b.operations);
        }
        if (scope.artists.length != 0) return false;
        (M.State memory principal, Payload.Payload memory p) = Codec.outer(2, q, identity);
        if (
            principal.artists.length != 0
                || keccak256(abi.encode(principal.collections))
                    != keccak256(abi.encode(scope.collections))
        ) _invalid();
        Empty.validate(p.provenance, p.nonces, principal.collections, principal.rows[0]);
        if (Identity(full.origins[full.origins.length - 1].owners[2]).nextRegistrationNonce() != 0)
        {
            _invalid();
        }
        External.Snapshot memory expected;
        expected.schema = U.TAG;
        expected.provenanceCommitment = RH.provenanceHash(full);
        if (keccak256(abi.encode(external_)) != keccak256(abi.encode(expected))) _invalid();
        return true;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
