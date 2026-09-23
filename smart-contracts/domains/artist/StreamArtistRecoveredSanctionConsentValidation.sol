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

/// @notice Original base consent predicates plus complete authenticated op12/op13 clocks and cells.
/// @dev Archive proof and full seven-owner composition run before these owner-local predicates.
library StreamArtistRecoveredSanctionConsentValidation {
    bytes32 private constant POLICY = keccak256("consent_finality.replay.policy_consent_key");
    bytes32 private constant ECONOMICS = keccak256("consent_finality.replay.consent_key");
    bytes32 private constant SALE = keccak256("consent_finality.replay.sale_consent_key");
    uint256 private constant MAX_ROWS = 128;

    function validate(
        History.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        H.SanctionRow[] memory sanctions,
        H.ConfirmationRow[] memory confirmations
    ) public pure {
        Provenance.validateOwner(p, 6);
        if (
            b.original.keys.length > MAX_ROWS || b.original.economics.length > MAX_ROWS
                || b.original.sales.length > MAX_ROWS
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
                        + b.original.sales.length + sanctions.length
        ) _invalid();
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
        (bytes32[] memory surfaces, bytes32[] memory scopes) = _journal(b, p, sanctions);
        _eras(p, confirmations);
        _aliases(p, surfaces, scopes, confirmations);
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

    function _journal(
        History.Bundle memory b,
        RH.OwnerProvenance memory p,
        H.SanctionRow[] memory sanctions
    ) private pure returns (bytes32[] memory surfaces, bytes32[] memory scopes) {
        surfaces = new bytes32[](p.journal.length);
        scopes = new bytes32[](p.journal.length);
        uint256 economics;
        uint256 sales;
        uint256 sanction;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            if (
                row.receipt.artistId != b.original.artistId
                    || row.receipt.collectionId != b.original.collectionId
            ) {
                _invalid();
            }
            for (uint256 j; j < i; ++j) {
                if (p.journal[j].receipt.recordHash == row.receipt.recordHash) _invalid();
            }
            if (row.receipt.operation == 12) {
                if (
                    sanction >= sanctions.length
                        || sanctions[sanction].record.recordHash != row.receipt.recordHash
                        || !D.samePoint(sanctions[sanction].point, row.position.point)
                ) _invalid();
                surfaces[i] = H.SANCTION;
                scopes[i] = keccak256(abi.encode(row.receipt.recordHash));
                ++sanction;
            } else if (row.receipt.operation == 14) {
                bool found;
                for (uint256 j; j < b.original.policies.length; ++j) {
                    if (b.original.policies[j].recordHash != row.receipt.recordHash) continue;
                    surfaces[i] = POLICY;
                    scopes[i] = _policyScope(b.original.collectionId, b.original.keys[j]);
                    found = true;
                }
                if (!found) _invalid();
            } else if (row.receipt.operation == 15) {
                if (economics >= b.original.economics.length) _invalid();
                EH.Row memory r = b.original.economics[economics++].item;
                if (r.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = ECONOMICS;
                scopes[i] = r.association.payloadHash;
            } else if (row.receipt.operation == 16) {
                if (sales >= b.original.sales.length) _invalid();
                Sale.Record memory r = b.original.sales[sales++].item;
                if (
                    r.recordHash != row.receipt.recordHash
                        || StreamArtistSaleHashes.record(
                                _environment(p, row.position.point.environmentHash),
                                r.terms,
                                r.artistId,
                                r.signer,
                                r.authorityClass,
                                r.nonce,
                                r.signedAt
                            ) != r.recordHash
                ) _invalid();
                surfaces[i] = SALE;
                scopes[i] = keccak256(abi.encode(r.terms, r.bindingGeneration, r.bindingHash));
            } else {
                revert T.UnsupportedProfile();
            }
        }
        if (
            economics != b.original.economics.length || sales != b.original.sales.length
                || sanction != sanctions.length
        ) {
            _invalid();
        }
    }

    function _eras(RH.OwnerProvenance memory p, H.ConfirmationRow[] memory confirmations)
        private
        pure
    {
        uint256 total;
        uint256 cursor;
        uint256 earlierConfirmations;
        for (uint256 i; i < p.eras.length; ++i) {
            RH.OwnerEra memory era = p.eras[i];
            uint256 confirmationsHere;
            for (uint256 k; k < confirmations.length; ++k) {
                RH.Point memory point = confirmations[k].consentPoint;
                Clock.validateOwnerPoint(p, 6, point);
                if (point.environmentHash == era.originHash) {
                    if (point.ownerRevision <= era.lowerRevision) _invalid();
                    ++confirmationsHere;
                }
            }
            total += era.nativeCount;
            earlierConfirmations += confirmationsHere;
            if (
                era.lowerRevision != (i == 0 ? 0 : 1)
                    || era.checkpoint.ownerState.revision
                        != era.lowerRevision + era.nativeCount + confirmationsHere
                    || era.checkpoint.replayCount != total + earlierConfirmations
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
                    || (total + earlierConfirmations == 0 && era.checkpoint.replayRoot != 0)
            ) _invalid();
            // Every original commit position is occupied exactly once. An op13 confirmation
            // has no native receipt; its own Archive-derived point fills only its own gap.
            for (
                uint256 revision = uint256(era.lowerRevision) + 1;
                revision <= era.checkpoint.ownerState.revision;
                ++revision
            ) {
                uint256 matches;
                for (uint256 j; j < era.nativeCount; ++j) {
                    if (p.journal[cursor + j].position.point.ownerRevision == revision) ++matches;
                }
                for (uint256 k; k < confirmations.length; ++k) {
                    if (
                        confirmations[k].consentPoint.environmentHash == era.originHash
                            && confirmations[k].consentPoint.ownerRevision == revision
                    ) ++matches;
                }
                if (matches != 1) _invalid();
            }
            cursor += era.nativeCount;
        }
    }

    function _aliases(
        RH.OwnerProvenance memory p,
        bytes32[] memory surfaces,
        bytes32[] memory scopes,
        H.ConfirmationRow[] memory confirmations
    ) private pure {
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (a.cell.kind != 1 || a.cell.status != 2) _invalid();
            bool found;
            for (uint256 j; j < p.journal.length; ++j) {
                if (
                    a.surface != surfaces[j] || a.scope != scopes[j]
                        || a.cell.commitment != p.journal[j].receipt.recordHash
                ) continue;
                if (
                    keccak256(abi.encode(a.admittedAt))
                        != keccak256(abi.encode(p.journal[j].position.point))
                ) _invalid();
                found = true;
            }
            for (uint256 j; j < confirmations.length; ++j) {
                H.ConfirmationRow memory c = confirmations[j];
                if (a.surface != H.CONFIRMATION || a.scope != Confirmation.scope(c.transition)) {
                    continue;
                }
                if (
                    a.cell.commitment != c.transition.sanctionRecordHash
                        || !D.samePoint(a.admittedAt, c.consentPoint)
                ) _invalid();
                found = true;
            }
            if (!found) _invalid();
        }
        // Unique original keys, immutable scopes, each era's complete replayCount and no alias
        // before its admission jointly retain every historical row and all later rekeyed cells.
    }

    function _environment(RH.OwnerProvenance memory p, bytes32 origin)
        private
        pure
        returns (StreamArtistHashes.Environment memory e)
    {
        for (uint256 i; i < p.origins.length; ++i) {
            if (p.eras[i].originHash == origin) {
                RH.OriginEnvironment memory o = p.origins[i];
                return StreamArtistHashes.Environment(o.chainId, o.registry, o.core, o.manager);
            }
        }
        _invalid();
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
