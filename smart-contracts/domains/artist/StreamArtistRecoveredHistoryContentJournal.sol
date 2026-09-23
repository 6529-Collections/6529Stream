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

/// @notice One complete original owner6 journal/clock; confirmations keep their independent zero-native positions.
library StreamArtistRecoveredHistoryContentJournal {
    bytes32 private constant POLICY = keccak256("consent_finality.replay.policy_consent_key");
    bytes32 private constant ECONOMICS = keccak256("consent_finality.replay.consent_key");
    bytes32 private constant SALE = keccak256("consent_finality.replay.sale_consent_key");
    bytes32 private constant CONTENT = keccak256("consent_finality.replay.content_consent_key");
    bytes32 private constant FREEZE = keccak256("consent_finality.replay.freeze_key");

    function validate(HC.Bundle memory full, RH.OwnerProvenance memory p) public pure {
        (bytes32[] memory surfaces, bytes32[] memory scopes) = _journal(full, p);
        _eras(p, full.sanctions.confirmations);
        _aliases(p, surfaces, scopes, full.sanctions.confirmations);
    }

    function _journal(HC.Bundle memory full, RH.OwnerProvenance memory p)
        private
        pure
        returns (bytes32[] memory surfaces, bytes32[] memory scopes)
    {
        History.Bundle memory b = full.base;
        H.SanctionRow[] memory sanctions = full.sanctions.sanctions;
        uint256 consents;
        uint256 royalties;
        uint256 freezes;
        uint256 ratifications;
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
            } else if (row.receipt.operation == 17) {
                if (consents >= full.consents.length) _invalid();
                ContentOwner.ConsentRecord memory r = full.consents[consents++];
                if (r.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = CONTENT;
                scopes[i] = keccak256(
                    abi.encode(keccak256(abi.encode(r.terms, r.bindingGeneration)), r.recordHash)
                );
            } else if (row.receipt.operation == 20) {
                if (royalties >= full.royalties.length) _invalid();
                ContentH.Royalty memory r = full.royalties[royalties++];
                if (r.item.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = FREEZE;
                scopes[i] =
                    keccak256(abi.encode(r.terms, b.original.artistId, r.item.bindingGeneration));
            } else if (row.receipt.operation == 21) {
                if (freezes >= full.freezes.length) _invalid();
                Content.FreezeRecord memory r = full.freezes[freezes++];
                if (r.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = FREEZE;
                scopes[i] = keccak256(
                    abi.encode(
                        keccak256("CONTENT"),
                        b.original.collectionId,
                        r.bindingGeneration,
                        r.recordHash
                    )
                );
            } else if (row.receipt.operation == 52) {
                if (ratifications >= full.ratifications.length) _invalid();
                T.RatificationRecord memory r = full.ratifications[ratifications++];
                if (r.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = keccak256("consent_finality.replay.ratification_key");
                scopes[i] = keccak256(abi.encode(b.original.collectionId, r.recordHash));
            } else {
                revert T.UnsupportedProfile();
            }
        }
        if (
            economics != b.original.economics.length || sales != b.original.sales.length
                || sanction != sanctions.length || consents != full.consents.length
                || royalties != full.royalties.length || freezes != full.freezes.length
                || ratifications != full.ratifications.length
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

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
