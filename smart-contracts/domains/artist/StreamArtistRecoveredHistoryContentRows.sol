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

import { StreamArtistHashes } from "./StreamArtistHashes.sol";

import {
    StreamArtistRecoveredDisputeConsentHistory as History
} from "./StreamArtistRecoveredDisputeConsentHistory.sol";

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistSanctionConfirmationTypes as Confirmation
} from "../../interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";

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

/// @notice Row identity across the complete accepted binding history; no current-generation substitution.
library StreamArtistRecoveredHistoryContentRows {
    uint256 private constant MAX_ROWS = 128;

    function validate(HC.Bundle memory full, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
    {
        History.Bundle memory b = full.base;
        Provenance.validateOwner(p, 6);
        if (
            b.original.keys.length > MAX_ROWS || b.original.economics.length > MAX_ROWS
                || b.original.sales.length > MAX_ROWS || full.consents.length > MAX_ROWS
                || full.royalties.length > MAX_ROWS || full.freezes.length > MAX_ROWS
                || full.ratifications.length > MAX_ROWS
        ) revert T.UnsupportedProfile();
        if (
            b.original.provenance != RH.ownerProvenanceHash(p, 6) || q.artistId == 0
                || b.original.artistId != q.artistId || q.collectionId == 0
                || b.original.collectionId != q.collectionId || q.bindingHash == 0
                || b.original.bindingHash != q.bindingHash
                || b.original.policies.length != b.original.keys.length
                || keccak256(abi.encode(b.original.keys)) != keccak256(abi.encode(q.policies))
                || p.journal.length
                    != b.original.policies.length + b.original.economics.length
                        + b.original.sales.length + full.sanctions.sanctions.length
                        + full.consents.length + full.royalties.length + full.freezes.length
                        + full.ratifications.length
        ) _invalid();
        if (!HC.hasContent(full) && full.ratifications.length == 0) _invalid();
        if (
            b.bindings.length == 0 || b.bindings.length > 128
                || b.bindings[b.bindings.length - 1].bindingHash != q.bindingHash
                || !b.bindings[b.bindings.length - 1].accepted
        ) _invalid();
        for (uint256 i; i < b.bindings.length; ++i) {
            T.Binding memory row = b.bindings[i];
            if (
                row.generation != i + 1 || row.artistId != q.artistId || row.bindingHash == 0
                    || (row.consentMode != 1 && row.consentMode != 2)
            ) _invalid();
        }
        _rows(b);
        _contentRows(full);
    }

    function _contentRows(HC.Bundle memory b) private pure {
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            if (
                r.recordHash == 0 || r.artistId != b.base.original.artistId
                    || !_accepted(b.base, r.bindingGeneration)
                    || (r.authorityClass != 1 && r.authorityClass != 3)
                    || r.terms.collectionId != b.base.original.collectionId
                    || r.terms.metadataContract == address(0) || r.terms.familyId == 0
                    || r.terms.newStateHash == 0
                    || r.terms.familyId == keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1")
            ) _invalid();
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            ContentH.Royalty memory r = b.royalties[i];
            if (
                r.item.recordHash == 0 || r.item.artistId != b.base.original.artistId
                    || !_accepted(b.base, r.item.bindingGeneration)
                    || r.terms.resolver == address(0)
                    || r.terms.collectionId != b.base.original.collectionId
                    || r.terms.revenueClass != keccak256("ROYALTY_ERC2981")
                    || r.terms.expectedAssignmentHash == 0
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    _royaltyScope(
                            b.royalties[j].terms,
                            b.base.original.artistId,
                            b.royalties[j].item.bindingGeneration
                        )
                        == _royaltyScope(
                            r.terms, b.base.original.artistId, r.item.bindingGeneration
                        )
                ) _invalid();
            }
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            if (
                r.recordHash == 0 || r.artistId != b.base.original.artistId
                    || !_accepted(b.base, r.bindingGeneration)
                    || (r.authorityClass != 1 && r.authorityClass != 3)
                    || r.metadataContract == address(0) || r.expectedStateHash == 0
                    || r.lockClasses.length == 0 || r.lockClasses.length > 16
            ) _invalid();
            bytes32 prior;
            for (uint256 j; j < r.lockClasses.length; ++j) {
                if (r.lockClasses[j] <= prior) _invalid();
                prior = r.lockClasses[j];
            }
        }
        // The original52 record has no generation, signer, nonce, or time fields. Its complete
        // source-native/signature joins are checked separately without inventing those facts.
        for (uint256 i; i < b.ratifications.length; ++i) {
            T.RatificationRecord memory r = b.ratifications[i];
            if (r.recordHash == 0 || r.contentStateHash == 0 || r.metadataContract == address(0)) {
                _invalid();
            }
        }
    }

    function _accepted(History.Bundle memory b, uint64 generation) private pure returns (bool) {
        return
            generation != 0 && generation <= b.bindings.length
                && b.bindings[generation - 1].accepted;
    }

    function _royaltyScope(T.RoyaltyFreeze memory terms, bytes32 artist, uint64 generation)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(terms, artist, generation));
    }

    function _rows(History.Bundle memory b) private pure {
        for (uint256 i; i < b.original.policies.length; ++i) {
            if (
                b.original.policies[i].recordHash == 0 || b.original.keys[i].phaseId == 0
                    || b.original.keys[i].policyHash == 0
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    b.original.policies[j].recordHash == b.original.policies[i].recordHash
                        || _policyScope(b.original.collectionId, b.original.keys[j])
                            == _policyScope(b.original.collectionId, b.original.keys[i])
                ) _invalid();
            }
        }
        for (uint256 i; i < b.original.economics.length; ++i) {
            EH.Row memory r = b.original.economics[i].item;
            T.EconomicsConsent memory t = r.terms;
            Evidence.Association memory a = r.association;
            if (
                r.recordHash == 0 || t.collectionId != b.original.collectionId
                    || t.resolver == address(0) || t.revenueClass == 0 || t.scope > 2
                    || (t.scope == 0 && (t.scopeId != 0 || t.assignmentHash == 0))
                    || (t.scope == 1 && t.scopeId != b.original.collectionId)
                    || (t.scope == 2 && t.scopeId == 0) || a.artistId != b.original.artistId
                    || !_binding(b, a.bindingGeneration, a.bindingHash, false)
                    || a.payloadHash != keccak256(abi.encode(t)) || a.originalRecord != r.recordHash
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    b.original.economics[j].item.recordHash == r.recordHash
                        || b.original.economics[j].item.association.payloadHash == a.payloadHash
                ) _invalid();
            }
        }
        for (uint256 i; i < b.original.sales.length; ++i) {
            DH.Sale memory row = b.original.sales[i];
            Sale.Record memory r = row.item;
            if (
                r.recordHash == 0 || r.artistId != b.original.artistId
                    || r.terms.collectionId != b.original.collectionId
                    || r.terms.saleAdapter == address(0) || r.terms.saleId == 0
                    || r.terms.saleConfigHash == 0 || r.signer == address(0) || r.signedAt == 0
                    || !_binding(b, r.bindingGeneration, r.bindingHash, row.grant != 0)
                    || (row.grant == 0
                            ? (r.authorityClass != 1 && r.authorityClass != 3)
                            : r.authorityClass != 2)
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    b.original.sales[j].item.recordHash == r.recordHash
                        || keccak256(abi.encode(b.original.sales[j].item.terms))
                            == keccak256(abi.encode(r.terms))
                ) _invalid();
            }
            bytes32 current = r.recordHash;
            for (uint256 j = i + 1; j < b.original.sales.length; ++j) {
                if (_lookup(b.original.sales[j].item.terms) == _lookup(r.terms)) {
                    current = b.original.sales[j].item.recordHash;
                }
            }
            if (row.current != current) _invalid();
        }
    }

    function _binding(History.Bundle memory b, uint64 generation, bytes32 hash, bool delegatedSale)
        private
        pure
        returns (bool)
    {
        if (generation == 0 || generation > b.bindings.length) return false;
        T.Binding memory row = b.bindings[generation - 1];
        return row.accepted && row.bindingHash == hash && (!delegatedSale || row.consentMode == 2);
    }

    function _policyScope(uint256 collectionId, AH.PolicyKey memory key)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(collectionId, key.phaseId, key.policyHash));
    }

    function _lookup(Sale.Consent memory p) private pure returns (bytes32) {
        return StreamArtistSaleHashes.lookup(p.collectionId, p.saleId, p.saleConfigHash);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
