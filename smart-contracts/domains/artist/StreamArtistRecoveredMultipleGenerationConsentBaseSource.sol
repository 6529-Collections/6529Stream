// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistDelegatedConsentOwner as Delegated
} from "../../interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";
import {
    IStreamArtistEconomicsEvidence as Evidence
} from "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    IStreamArtistSaleConsentOwner as Sales
} from "../../interfaces/stream/artist/IStreamArtistSaleOwner.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "./StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistContentTypes as Content
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";

import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";

/// @notice Fixed complete original policy, economics and sale source reads.
library StreamArtistRecoveredMultipleGenerationConsentBaseSource {
    uint256 private constant MAX_ROWS = 128;

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms,
        bool allowRatifications,
        bool allowSanctions
    ) public view returns (Base.Bundle memory b) {
        if (q.policies.length > MAX_ROWS || terms.length > MAX_ROWS) {
            revert T.UnsupportedProfile();
        }
        b.provenance = RH.ownerProvenanceHash(p, 6);
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.bindingHash = q.bindingHash;
        b.keys = q.policies;
        b.policies = new DH.Policy[](q.policies.length);
        for (uint256 i; i < b.policies.length; ++i) {
            bytes32 record = Consent(source)
                .policyRecord(q.collectionId, q.policies[i].phaseId, q.policies[i].policyHash);
            b.policies[i] = DH.Policy(record, Delegated(source).recordDelegation(record));
        }
        b.economics = new Base.Economics[](terms.length);
        uint256 economic;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory n = p.journal[i];
            if (
                n.receipt.artistId != q.artistId || n.receipt.collectionId != q.collectionId
                    || n.receipt.operation != 15
            ) continue;
            if (economic == terms.length) _invalid();
            T.EconomicsConsent memory t = terms[economic];
            bytes32 record = n.receipt.recordHash;
            Evidence.Association memory association =
                Evidence(source).economicsRecordAssociation(record);
            if (
                Consent(source).economicsRecord(t) != association.originalRecord
                    || association.originalRecord == 0
                    || Evidence(source)
                            .economicsRecordForBinding(
                                t,
                                q.artistId,
                                association.bindingGeneration,
                                association.bindingHash
                            ) != record
            ) _invalid();
            b.economics[economic++] = Base.Economics(
                EH.Row(record, t, association), Delegated(source).recordDelegation(record)
            );
        }
        if (economic != terms.length) _invalid();
        uint256 count;
        for (uint256 i; i < p.journal.length; ++i) {
            if (
                p.journal[i].receipt.artistId != q.artistId
                    || p.journal[i].receipt.collectionId != q.collectionId
            ) continue;
            uint16 op = p.journal[i].receipt.operation;
            if (op == 16) {
                ++count;
            } else if (
                op != 14 && op != 15 && op != 17 && op != 20 && op != 21
                    && (!allowRatifications || op != 52) && (!allowSanctions || op != 12)
            ) {
                revert T.UnsupportedProfile();
            }
        }
        if (count > MAX_ROWS) revert T.UnsupportedProfile();
        b.sales = new DH.Sale[](count);
        count = 0;
        for (uint256 i; i < p.journal.length; ++i) {
            if (
                p.journal[i].receipt.artistId != q.artistId
                    || p.journal[i].receipt.collectionId != q.collectionId
            ) continue;
            if (p.journal[i].receipt.operation != 16) continue;
            bytes32 record = p.journal[i].receipt.recordHash;
            Sale.Record memory item = Sales(source).saleConsentRecord(record);
            b.sales[count++] = DH.Sale(
                item,
                Delegated(source).recordDelegation(record),
                Sales(source)
                    .saleConsentAt(
                        item.terms.collectionId, item.terms.saleId, item.terms.saleConfigHash
                    )
            );
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
