// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistPublicationHydrationTypes as PH
} from "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistRecoveredRatificationHydration as Ratified
} from "./StreamArtistRecoveredRatificationHydration.sol";
import {
    StreamArtistRecoveredContentConsentFactRows as ContentRows
} from "./StreamArtistRecoveredContentConsentFactRows.sol";
import {
    StreamArtistRecoveredAttestationFactRows as AttestationRows
} from "./StreamArtistRecoveredAttestationFactRows.sol";
import {
    StreamArtistRecoveredDelegationConsentFactRows as BaseRows
} from "./StreamArtistRecoveredDelegationConsentFactRows.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Complete original52 signature inventory alongside every historical grant use.
/// @dev Original52 retains no signer/nonce/time preimage and emits no Identity native receipt.
/// Full Identity source/nonce/replay authentication precedes this join. Never invent a clock or
/// reauthorize against a current principal. Ratification consumes no delegation capability.
library StreamArtistRecoveredRatificationFacts {
    function validate(
        IH.Bundle calldata identity,
        bytes calldata raw,
        AH.Query calldata q,
        RH.Provenance calldata p,
        uint8 expectedMode,
        PH.Row[] calldata rows
    ) public pure {
        (Ratified.Bundle memory b, uint64 generation, uint8 mode) =
            Ratified.decode(q, RH.ownerProvenance(p, 6), raw);
        if (mode != expectedMode || identity.artistId != q.artistId) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        uint256 count;
        for (uint256 i; i < p.journals[6].length; ++i) {
            RH.JournalEntry memory n = p.journals[6][i];
            if (n.receipt.operation != 52) continue;
            if (
                count >= b.ratifications.length
                    || n.receipt.recordHash != b.ratifications[count++].recordHash
                    || n.receipt.artistId != q.artistId || n.receipt.collectionId != q.collectionId
                    || n.position.point.ownerIndex != 6
            ) revert RH.InvalidRecoveredHydrationProfile();
            Chronology.validatePoint(p, n.position.point);
            uint256 found;
            for (uint256 j; j < identity.signatures.length; ++j) {
                if (identity.signatures[j].recordHash != n.receipt.recordHash) continue;
                if (identity.signatures[j].signature.length > 4096) {
                    revert RH.InvalidRecoveredHydrationProfile();
                }
                ++found;
            }
            if (found != 1) revert RH.InvalidRecoveredHydrationProfile();
        }
        if (count != b.ratifications.length) revert RH.InvalidRecoveredHydrationProfile();
        uint256[] memory uses = ContentRows.validateRatifiedRows(
            ContentRows.IdentityRows(identity.artistId, identity.signatures, identity.delegations),
            ContentRows.ConsentRows(
                b.consent.original.artistId,
                b.consent.original.collectionId,
                b.consent.original.bindingHash,
                b.consent.consents,
                b.consent.royalties,
                b.consent.freezes
            ),
            ContentRows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p,
            generation
        );
        AttestationRows.IdentityRows memory ai = AttestationRows.IdentityRows(
            identity.artistId, identity.signatures, identity.delegations
        );
        AttestationRows.Scope memory scope =
            AttestationRows.Scope(q.artistId, q.collectionId, q.bindingHash);
        uint256[] memory attestations = generation == 1
            ? AttestationRows.validateRows(ai, rows, scope, p)
            : AttestationRows.validateGenerationRowsWithGrants(ai, rows, scope, p, generation);
        for (uint256 i; i < uses.length; ++i) {
            uses[i] += attestations[i];
        }
        BaseRows.validateRows(
            BaseRows.IdentityRows(identity.artistId, identity.delegations),
            BaseRows.ConsentRows(
                b.consent.original.artistId,
                b.consent.original.collectionId,
                b.consent.original.bindingHash,
                b.consent.original.policies,
                b.consent.original.economics,
                b.consent.original.sales
            ),
            BaseRows.Scope(q.artistId, q.collectionId, q.bindingHash),
            p,
            mode,
            uses
        );
    }
}
