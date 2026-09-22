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
    StreamArtistContentTypes as Content
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";
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
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "./StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistCompleteHistoryConsentValidation as Validation
} from "./StreamArtistCompleteHistoryConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentSource as Heads
} from "./StreamArtistRecoveredMultipleGenerationConsentSource.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Rows
} from "./StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAggregateSanctionRows as Sanctions
} from "./StreamArtistRecoveredAggregateSanctionRows.sol";
import {
    StreamArtistRecoveredAggregateSanctionConsentTransport as Transport
} from "./StreamArtistRecoveredAggregateSanctionConsentTransport.sol";

/// @notice Complete original Consent rows selected by collection and authentic historical principal.
/// @dev The enclosing profile authenticates CT's full Binding/Archive/Identity inventory first.
/// Collection selectors name only current heads. No owner certificate is filtered or renumbered.
library StreamArtistCompleteHistoryConsentSource {
    uint256 private constant MAX_ROWS = 128;

    struct Context {
        address source;
        M.State scope;
        CT.Inventory inventory;
        T.EconomicsConsent[][] economics;
        T.RoyaltyFreeze[][] royalties;
    }

    function collect(Context memory x) public view returns (bytes[] memory encoded) {
        RH.OwnerProvenance memory p = RH.ownerProvenance(x.inventory.provenance, 6);
        Provenance.validateOwnerSource(p, 6, x.source);
        uint256 n = x.scope.collections.length;
        if (
            n == 0 || n > MAX_ROWS || x.inventory.bindings.bindings.length != n
                || x.economics.length != n || x.royalties.length != n
        ) _invalid();
        G.Consents[] memory all = new G.Consents[](n);
        T.RatificationRecord[][] memory ratifications = new T.RatificationRecord[][](n);
        for (uint256 k; k < n; ++k) {
            AH.Query memory q = x.scope.collections[k];
            if (q.collectionId == 0) _invalid();
            for (uint256 j; j < k; ++j) {
                if (x.scope.collections[j].collectionId == q.collectionId) _invalid();
            }
            uint256 generations = x.inventory.bindings.bindings[k].bindings.rows.length;
            if (generations > MAX_ROWS) _invalid();
            all[k].bindings = new T.Binding[](generations);
            for (uint256 g; g < generations; ++g) {
                all[k].bindings[g] = x.inventory.bindings.bindings[k].bindings.rows[g].item;
            }
            (all[k].rows, ratifications[k]) =
                _collection(x.source, q, p, x.economics[k], x.royalties[k], all[k].bindings);
        }
        // Native12 is mandatory for any retained sanction/confirmation history. Original13
        // has no native receipt and is collected from the complete real Archive catalogue.
        bool sanctioned;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            Scope.collection(x.scope, row.receipt.collectionId);
            Scope.artist(x.scope, row.receipt.artistId);
            if (row.receipt.operation == 12) sanctioned = true;
        }
        H.Inventory memory sanctions;
        bytes memory sanctionInventory;
        if (sanctioned) {
            sanctions = Sanctions.collect(
                x.source, x.scope.collections, x.inventory.provenance, x.inventory.bindings.bindings
            );
            sanctionInventory = abi.encode(sanctions);
        }
        Validation.validate(all, ratifications, x.scope, x.inventory, sanctionInventory);
        encoded = new bytes[](n);
        for (uint256 k; k < n; ++k) {
            Heads.requireHeads(x.source, all[k].rows);
            _ratificationHead(x.source, x.scope.collections[k].collectionId, ratifications[k]);
            encoded[k] = Rows.encode(all[k], ratifications[k]);
        }
        if (sanctioned) encoded = Transport.encode(encoded, sanctions);
    }

    /// @notice Re-read the complete fixed-source rows and original heads without applying state.
    function requireCurrent(Context memory x, bytes[] memory expected) public view {
        if (keccak256(abi.encode(collect(x))) != keccak256(abi.encode(expected))) _invalid();
    }

    function _collection(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        T.Binding[] memory bindings
    ) private view returns (ContentH.Bundle memory b, T.RatificationRecord[] memory ratifications) {
        uint256[6] memory counts;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            if (row.receipt.collectionId != q.collectionId) continue;
            uint16 op = row.receipt.operation;
            if (op == 15) ++counts[0];
            else if (op == 16) ++counts[1];
            else if (op == 17) ++counts[2];
            else if (op == 20) ++counts[3];
            else if (op == 21) ++counts[4];
            else if (op == 52) ++counts[5];
            else if (op != 14 && op != 12) revert T.UnsupportedProfile();
        }
        if (
            q.policies.length > MAX_ROWS || economics.length != counts[0]
                || royalties.length != counts[3]
        ) _invalid();
        for (uint256 i; i < counts.length; ++i) {
            if (counts[i] > MAX_ROWS) revert T.UnsupportedProfile();
        }
        b.original.provenance = RH.ownerProvenanceHash(p, 6);
        b.original.artistId = q.artistId;
        b.original.collectionId = q.collectionId;
        b.original.bindingHash = q.bindingHash;
        b.original.keys = q.policies;
        b.original.policies = new DH.Policy[](q.policies.length);
        for (uint256 i; i < q.policies.length; ++i) {
            bytes32 record = Consent(source)
                .policyRecord(q.collectionId, q.policies[i].phaseId, q.policies[i].policyHash);
            b.original.policies[i] = DH.Policy(record, Delegated(source).recordDelegation(record));
        }
        b.original.economics = new Base.Economics[](counts[0]);
        b.original.sales = new DH.Sale[](counts[1]);
        b.consents = new ContentOwner.ConsentRecord[](counts[2]);
        b.royalties = new ContentH.Royalty[](counts[3]);
        b.freezes = new Content.FreezeRecord[](counts[4]);
        ratifications = new T.RatificationRecord[](counts[5]);
        uint256[6] memory cursor;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            if (row.receipt.collectionId != q.collectionId) continue;
            bytes32 record = row.receipt.recordHash;
            uint16 op = row.receipt.operation;
            if (op == 15) {
                uint256 at = cursor[0]++;
                b.original.economics[at] = _economics(source, row, economics[at]);
            } else if (op == 16) {
                Sale.Record memory item = Sales(source).saleConsentRecord(record);
                b.original.sales[cursor[1]++] = DH.Sale(
                    item,
                    Delegated(source).recordDelegation(record),
                    Sales(source)
                        .saleConsentAt(
                            item.terms.collectionId, item.terms.saleId, item.terms.saleConfigHash
                        )
                );
            } else if (op == 17) {
                b.consents[cursor[2]++] = ContentOwner(source).contentConsentRecord(record);
                if (Delegated(source).recordDelegation(record) != 0) _invalid();
            } else if (op == 20) {
                uint256 at = cursor[3]++;
                b.royalties[at] = _royalty(source, row, royalties[at], bindings);
            } else if (op == 21) {
                b.freezes[cursor[4]++] = ContentOwner(source).contentFreezeRecord(record);
                if (Delegated(source).recordDelegation(record) != 0) _invalid();
            } else if (op == 52) {
                T.RatificationRecord memory item = Consent(source).ratificationRecord(record);
                if (
                    record == 0 || item.recordHash != record || item.contentStateHash == 0
                        || item.metadataContract == address(0)
                        || Delegated(source).recordDelegation(record) != 0
                ) _invalid();
                ratifications[cursor[5]++] = item;
            }
        }
    }

    function _economics(address source, RH.JournalEntry memory row, T.EconomicsConsent memory terms)
        private
        view
        returns (Base.Economics memory)
    {
        bytes32 record = row.receipt.recordHash;
        Evidence.Association memory association =
            Evidence(source).economicsRecordAssociation(record);
        if (
            association.artistId != row.receipt.artistId
                || Consent(source).economicsRecord(terms) != association.originalRecord
                || association.originalRecord == 0
                || Evidence(source)
                        .economicsRecordForBinding(
                            terms,
                            row.receipt.artistId,
                            association.bindingGeneration,
                            association.bindingHash
                        ) != record
        ) _invalid();
        return Base.Economics(
            EH.Row(record, terms, association), Delegated(source).recordDelegation(record)
        );
    }

    function _royalty(
        address source,
        RH.JournalEntry memory row,
        T.RoyaltyFreeze memory terms,
        T.Binding[] memory bindings
    ) private view returns (ContentH.Royalty memory) {
        T.RoyaltyFreezeRecord memory item;
        bool found;
        for (uint256 g; g < bindings.length; ++g) {
            T.Binding memory binding_ = bindings[g];
            if (!binding_.accepted || binding_.artistId != row.receipt.artistId) continue;
            T.RoyaltyFreezeRecord memory candidate = Consent(source)
                .royaltyFreezeRecord(terms, row.receipt.artistId, binding_.generation);
            if (candidate.recordHash != row.receipt.recordHash) continue;
            if (found) _invalid();
            found = true;
            item = candidate;
        }
        if (!found) _invalid();
        return ContentH.Royalty(terms, item, Delegated(source).recordDelegation(item.recordHash));
    }

    function _ratificationHead(
        address source,
        uint256 collectionId,
        T.RatificationRecord[] memory rows
    ) private view {
        T.RatificationRecord memory expected;
        if (rows.length != 0) expected = rows[rows.length - 1];
        if (
            keccak256(abi.encode(Consent(source).firstReleaseRatification(collectionId)))
                != keccak256(abi.encode(expected))
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
