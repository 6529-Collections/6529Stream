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

import {
    StreamArtistRecoveredHistoryContentTypes as HC
} from "./StreamArtistRecoveredHistoryContentTypes.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as Content
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";

/// @notice Fixed-source collection of complete history rows, before the separate full validator.
/// @dev Never projects the provenance. Royalty generations are found only among the complete
/// authenticated binding rows and matched to the original native record, not the current binding.
library StreamArtistRecoveredHistoryContentSource {
    uint256 private constant MAX_ROWS = 128;

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms,
        T.RoyaltyFreeze[] memory royalties,
        G.Bundle memory bindings,
        H.Inventory memory sanctions
    ) public view returns (HC.Bundle memory b) {
        b.base = _base(source, q, p, terms, bindings);
        b.sanctions = sanctions;
        uint256 cc;
        uint256 rc;
        uint256 fc;
        uint256 rat;
        for (uint256 i; i < p.journal.length; ++i) {
            uint16 op = p.journal[i].receipt.operation;
            if (op == 17) ++cc;
            else if (op == 20) ++rc;
            else if (op == 21) ++fc;
            else if (op == 52) ++rat;
        }
        if (
            cc > MAX_ROWS || rc > MAX_ROWS || fc > MAX_ROWS || rat > MAX_ROWS
                || royalties.length != rc
        ) {
            revert T.UnsupportedProfile();
        }
        b.consents = new ContentOwner.ConsentRecord[](cc);
        b.royalties = new ContentH.Royalty[](rc);
        b.freezes = new Content.FreezeRecord[](fc);
        b.ratifications = new T.RatificationRecord[](rat);
        cc = 0;
        rc = 0;
        fc = 0;
        rat = 0;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory n = p.journal[i];
            bytes32 hash = n.receipt.recordHash;
            if (n.receipt.operation == 17) {
                b.consents[cc++] = ContentOwner(source).contentConsentRecord(hash);
                if (Delegated(source).recordDelegation(hash) != 0) _invalid();
            } else if (n.receipt.operation == 20) {
                T.RoyaltyFreezeRecord memory item;
                uint256 matches;
                for (uint256 g; g < b.base.bindings.length; ++g) {
                    if (!b.base.bindings[g].accepted) continue;
                    T.RoyaltyFreezeRecord memory candidate = Consent(source)
                        .royaltyFreezeRecord(
                            royalties[rc], q.artistId, b.base.bindings[g].generation
                        );
                    if (candidate.recordHash != hash) continue;
                    if (
                        candidate.artistId != q.artistId
                            || candidate.bindingGeneration != b.base.bindings[g].generation
                    ) _invalid();
                    item = candidate;
                    ++matches;
                }
                if (matches != 1) _invalid();
                b.royalties[rc] =
                    ContentH.Royalty(royalties[rc], item, Delegated(source).recordDelegation(hash));
                ++rc;
            } else if (n.receipt.operation == 21) {
                b.freezes[fc++] = ContentOwner(source).contentFreezeRecord(hash);
                if (Delegated(source).recordDelegation(hash) != 0) _invalid();
            } else if (n.receipt.operation == 52) {
                T.RatificationRecord memory r = Consent(source).ratificationRecord(hash);
                if (r.recordHash != hash || Delegated(source).recordDelegation(hash) != 0) {
                    _invalid();
                }
                b.ratifications[rat++] = r;
            }
        }
    }

    /// @dev Called only after complete row/journal/era validation, in the original read order.
    function requireHeads(address source, HC.Bundle memory b) public view {
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            uint256 last = i;
            for (uint256 j = i + 1; j < b.consents.length; ++j) {
                if (
                    _contentScope(b.consents[j].terms, b.consents[j].bindingGeneration)
                        == _contentScope(r.terms, r.bindingGeneration)
                ) last = j;
            }
            if (
                keccak256(
                        abi.encode(
                            ContentOwner(source).contentConsentAt(r.terms, r.bindingGeneration)
                        )
                    ) != keccak256(abi.encode(b.consents[last]))
            ) _invalid();
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            for (uint256 k; k < r.lockClasses.length; ++k) {
                uint256 last = i;
                for (uint256 j = i + 1; j < b.freezes.length; ++j) {
                    if (
                        b.freezes[j].bindingGeneration != r.bindingGeneration
                            || b.freezes[j].metadataContract != r.metadataContract
                    ) continue;
                    for (uint256 l; l < b.freezes[j].lockClasses.length; ++l) {
                        if (b.freezes[j].lockClasses[l] == r.lockClasses[k]) last = j;
                    }
                }
                if (
                    keccak256(
                            abi.encode(
                                ContentOwner(source)
                                    .contentFreezeAt(
                                        b.base.original.collectionId,
                                        r.bindingGeneration,
                                        r.metadataContract,
                                        r.lockClasses[k]
                                    )
                            )
                        ) != keccak256(abi.encode(b.freezes[last]))
                ) _invalid();
            }
        }
        T.RatificationRecord memory expected;
        if (b.ratifications.length != 0) expected = b.ratifications[b.ratifications.length - 1];
        if (
            keccak256(
                    abi.encode(
                        Consent(source).firstReleaseRatification(b.base.original.collectionId)
                    )
                ) != keccak256(abi.encode(expected))
        ) _invalid();
    }

    function _contentScope(Content.Consent memory terms, uint64 generation)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(terms, generation));
    }

    function _base(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms,
        G.Bundle memory bindings
    ) private view returns (History.Bundle memory b) {
        Provenance.validateOwnerSource(p, 6, source);
        if (q.policies.length > MAX_ROWS || terms.length > MAX_ROWS) revert T.UnsupportedProfile();
        b.original.provenance = RH.ownerProvenanceHash(p, 6);
        b.original.artistId = q.artistId;
        b.original.collectionId = q.collectionId;
        b.original.bindingHash = q.bindingHash;
        b.bindings = new T.Binding[](bindings.rows.length);
        for (uint256 i; i < bindings.rows.length; ++i) {
            b.bindings[i] = bindings.rows[i].item;
        }
        b.original.keys = q.policies;
        b.original.policies = new DH.Policy[](q.policies.length);
        for (uint256 i; i < b.original.policies.length; ++i) {
            bytes32 record = Consent(source)
                .policyRecord(q.collectionId, q.policies[i].phaseId, q.policies[i].policyHash);
            b.original.policies[i] = DH.Policy(record, Delegated(source).recordDelegation(record));
        }
        b.original.economics = new Base.Economics[](terms.length);
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
            b.original.economics[i] = Base.Economics(
                EH.Row(record, terms[i], Evidence(source).economicsRecordAssociation(record)),
                Delegated(source).recordDelegation(record)
            );
        }
        uint256 count;
        for (uint256 i; i < p.journal.length; ++i) {
            uint16 op = p.journal[i].receipt.operation;
            if (op == 16) {
                ++count;
            } else if (
                op != 14 && op != 15 && op != 12 && op != 17 && op != 20 && op != 21 && op != 52
            ) {
                revert T.UnsupportedProfile();
            }
        }
        if (count > MAX_ROWS) revert T.UnsupportedProfile();
        b.original.sales = new DH.Sale[](count);
        count = 0;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.operation != 16) continue;
            bytes32 record = p.journal[i].receipt.recordHash;
            Sale.Record memory item = Sales(source).saleConsentRecord(record);
            b.original.sales[count++] = DH.Sale(
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
