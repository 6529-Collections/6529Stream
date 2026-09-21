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
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistEconomicsAssociation as Association
} from "./StreamArtistEconomicsAssociation.sol";
import { StreamArtistSaleHashes } from "./StreamArtistSaleHashes.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "./StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";

import {
    StreamArtistRecoveredSanctionConsentValidation as Validation
} from "./StreamArtistRecoveredSanctionConsentValidation.sol";
import {
    StreamArtistRecoveredDisputeConsentHistory as History
} from "./StreamArtistRecoveredDisputeConsentHistory.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionLocalProof as Local
} from "./StreamArtistRecoveredSanctionLocalProof.sol";
import { StreamArtistSanctionState as Sanctions } from "./StreamArtistSanctionState.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    IStreamArtistSanctionArchiveFacts as ArchiveFacts
} from "../../interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";

import {
    StreamArtistRecoveredSanctionConsentHistory as Original
} from "./StreamArtistRecoveredSanctionConsentHistory.sol";

/// @notice Original base-consent source collection plus the complete op12/op13 inventory.
library StreamArtistRecoveredSanctionConsentCollection {
    uint256 private constant MAX_ROWS = 128;

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms,
        G.Bundle memory bindings,
        H.Inventory memory history
    ) public view returns (Original.Bundle memory b) {
        Provenance.validateOwnerSource(p, 6, source);
        b.history = history;
        if (q.policies.length > MAX_ROWS || terms.length > MAX_ROWS) revert T.UnsupportedProfile();
        b.base.original.provenance = RH.ownerProvenanceHash(p, 6);
        b.base.original.artistId = q.artistId;
        b.base.original.collectionId = q.collectionId;
        b.base.original.bindingHash = q.bindingHash;
        b.base.bindings = new T.Binding[](bindings.rows.length);
        for (uint256 i; i < bindings.rows.length; ++i) {
            b.base.bindings[i] = bindings.rows[i].item;
        }
        b.base.original.keys = q.policies;
        b.base.original.policies = new DH.Policy[](q.policies.length);
        for (uint256 i; i < b.base.original.policies.length; ++i) {
            bytes32 record = Consent(source)
                .policyRecord(q.collectionId, q.policies[i].phaseId, q.policies[i].policyHash);
            b.base.original.policies[i] =
                DH.Policy(record, Delegated(source).recordDelegation(record));
        }
        b.base.original.economics = new Base.Economics[](terms.length);
        for (uint256 i; i < terms.length; ++i) {
            bytes32 record = Consent(source).economicsRecord(terms[i]);
            if (
                Evidence(source)
                        .economicsRecordForBinding(
                            terms[i],
                            q.artistId,
                            Evidence(source).economicsRecordAssociation(record).bindingGeneration,
                            Evidence(source).economicsRecordAssociation(record).bindingHash
                        ) != record
            ) _invalid();
            b.base.original.economics[i] = Base.Economics(
                EH.Row(record, terms[i], Evidence(source).economicsRecordAssociation(record)),
                Delegated(source).recordDelegation(record)
            );
        }
        uint256 count;
        for (uint256 i; i < p.journal.length; ++i) {
            uint16 op = p.journal[i].receipt.operation;
            if (op == 16) ++count;
            else if (op != 14 && op != 15 && op != 12) revert T.UnsupportedProfile();
        }
        if (count > MAX_ROWS) revert T.UnsupportedProfile();
        b.base.original.sales = new DH.Sale[](count);
        count = 0;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.operation != 16) continue;
            bytes32 record = p.journal[i].receipt.recordHash;
            Sale.Record memory item = Sales(source).saleConsentRecord(record);
            b.base.original.sales[count++] = DH.Sale(
                item,
                Delegated(source).recordDelegation(record),
                Sales(source)
                    .saleConsentAt(
                        item.terms.collectionId, item.terms.saleId, item.terms.saleConfigHash
                    )
            );
        }
        Original.validate(b, q, p);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
