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
    IStreamArtistEconomicsEvidence as Evidence
} from "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";

import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

import { StreamArtistSaleHashes } from "./StreamArtistSaleHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";

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

/// @notice Complete pure validation for the unchanged recovered content codec.
/// @dev The facade retains canonical encoding and the fixed-owner import boundary. This
/// linked worker preserves every original row, native journal, era and replay-alias check.
library StreamArtistRecoveredContentConsentValidation {
    bytes32 private constant POLICY = keccak256("consent_finality.replay.policy_consent_key");
    bytes32 private constant ECONOMICS = keccak256("consent_finality.replay.consent_key");
    bytes32 private constant SALE = keccak256("consent_finality.replay.sale_consent_key");
    bytes32 private constant CONTENT = keccak256("consent_finality.replay.content_consent_key");
    bytes32 private constant FREEZE = keccak256("consent_finality.replay.freeze_key");
    uint256 private constant MAX_ROWS = 128;

    function validate(ContentH.Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
    {
        Provenance.validateOwner(p, 6);
        Base.Bundle memory old = b.original;
        if (
            old.keys.length > MAX_ROWS || old.economics.length > MAX_ROWS
                || old.sales.length > MAX_ROWS || b.consents.length > MAX_ROWS
                || b.royalties.length > MAX_ROWS || b.freezes.length > MAX_ROWS
        ) revert T.UnsupportedProfile();
        if (
            old.provenance != RH.ownerProvenanceHash(p, 6) || q.artistId == 0
                || old.artistId != q.artistId || q.collectionId == 0
                || old.collectionId != q.collectionId || q.bindingHash == 0
                || old.bindingHash != q.bindingHash || old.policies.length != old.keys.length
                || keccak256(abi.encode(old.keys)) != keccak256(abi.encode(q.policies))
                || b.consents.length + b.royalties.length + b.freezes.length == 0
                || p.journal.length
                    != old.policies.length + old.economics.length + old.sales.length
                        + b.consents.length + b.royalties.length + b.freezes.length
        ) _invalid();
        _baseRows(old);
        _contentRows(b);
        (bytes32[] memory surfaces, bytes32[] memory scopes) = _journal(b, p);
        _eras(p);
        _aliases(p, surfaces, scopes);
    }

    function _contentRows(ContentH.Bundle memory b) private pure {
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            if (
                r.recordHash == 0 || r.artistId != b.original.artistId || r.bindingGeneration != 1
                    || (r.authorityClass != 1 && r.authorityClass != 3)
                    || r.terms.collectionId != b.original.collectionId
                    || r.terms.metadataContract == address(0) || r.terms.familyId == 0
                    || r.terms.newStateHash == 0
            ) _invalid();
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            ContentH.Royalty memory r = b.royalties[i];
            if (
                r.item.recordHash == 0 || r.item.artistId != b.original.artistId
                    || r.item.bindingGeneration != 1 || r.terms.resolver == address(0)
                    || r.terms.collectionId != b.original.collectionId
                    || r.terms.revenueClass != keccak256("ROYALTY_ERC2981")
                    || r.terms.expectedAssignmentHash == 0
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    _royaltyScope(b.royalties[j].terms, b.original.artistId)
                        == _royaltyScope(r.terms, b.original.artistId)
                ) _invalid();
            }
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            if (
                r.recordHash == 0 || r.artistId != b.original.artistId || r.bindingGeneration != 1
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
    }

    function _journal(ContentH.Bundle memory b, RH.OwnerProvenance memory p)
        private
        pure
        returns (bytes32[] memory surfaces, bytes32[] memory scopes)
    {
        surfaces = new bytes32[](p.journal.length);
        scopes = new bytes32[](p.journal.length);
        uint256 economics;
        uint256 sales;
        uint256 consents;
        uint256 royalties;
        uint256 freezes;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            if (
                row.receipt.artistId != b.original.artistId
                    || row.receipt.collectionId != b.original.collectionId
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (p.journal[j].receipt.recordHash == row.receipt.recordHash) _invalid();
            }
            if (row.receipt.operation == 14) {
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
                if (consents >= b.consents.length) _invalid();
                ContentOwner.ConsentRecord memory r = b.consents[consents++];
                if (r.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = CONTENT;
                scopes[i] = keccak256(abi.encode(_contentScope(r.terms), r.recordHash));
            } else if (row.receipt.operation == 20) {
                if (royalties >= b.royalties.length) _invalid();
                ContentH.Royalty memory r = b.royalties[royalties++];
                if (r.item.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = FREEZE;
                scopes[i] = _royaltyScope(r.terms, b.original.artistId);
            } else if (row.receipt.operation == 21) {
                if (freezes >= b.freezes.length) _invalid();
                Content.FreezeRecord memory r = b.freezes[freezes++];
                if (r.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = FREEZE;
                scopes[i] = keccak256(
                    abi.encode(
                        keccak256("CONTENT"), b.original.collectionId, uint64(1), r.recordHash
                    )
                );
            } else {
                revert T.UnsupportedProfile();
            }
        }
        if (
            economics != b.original.economics.length || sales != b.original.sales.length
                || consents != b.consents.length || royalties != b.royalties.length
                || freezes != b.freezes.length
        ) _invalid();
    }

    function _baseRows(Base.Bundle memory b) private pure {
        for (uint256 i; i < b.policies.length; ++i) {
            if (
                b.policies[i].recordHash == 0 || b.keys[i].phaseId == 0 || b.keys[i].policyHash == 0
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    b.policies[j].recordHash == b.policies[i].recordHash
                        || _policyScope(b.collectionId, b.keys[j])
                            == _policyScope(b.collectionId, b.keys[i])
                ) _invalid();
            }
        }
        for (uint256 i; i < b.economics.length; ++i) {
            EH.Row memory r = b.economics[i].item;
            T.EconomicsConsent memory t = r.terms;
            Evidence.Association memory a = r.association;
            if (
                r.recordHash == 0 || t.collectionId != b.collectionId || t.resolver == address(0)
                    || t.revenueClass == 0 || t.scope > 2
                    || (t.scope == 0 && (t.scopeId != 0 || t.assignmentHash == 0))
                    || (t.scope == 1 && t.scopeId != b.collectionId)
                    || (t.scope == 2 && t.scopeId == 0) || a.artistId != b.artistId
                    || a.bindingGeneration != 1 || a.bindingHash != b.bindingHash
                    || a.payloadHash != keccak256(abi.encode(t)) || a.originalRecord != r.recordHash
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    b.economics[j].item.recordHash == r.recordHash
                        || b.economics[j].item.association.payloadHash == a.payloadHash
                ) _invalid();
            }
        }
        for (uint256 i; i < b.sales.length; ++i) {
            DH.Sale memory row = b.sales[i];
            Sale.Record memory r = row.item;
            if (
                r.recordHash == 0 || r.artistId != b.artistId
                    || r.terms.collectionId != b.collectionId || r.terms.saleAdapter == address(0)
                    || r.terms.saleId == 0 || r.terms.saleConfigHash == 0 || r.signer == address(0)
                    || r.signedAt == 0 || r.bindingGeneration != 1 || r.bindingHash != b.bindingHash
                    || (row.grant == 0
                            ? (r.authorityClass != 1 && r.authorityClass != 3)
                            : r.authorityClass != 2)
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    b.sales[j].item.recordHash == r.recordHash
                        || keccak256(abi.encode(b.sales[j].item.terms))
                            == keccak256(abi.encode(r.terms))
                ) _invalid();
            }
            bytes32 current = r.recordHash;
            for (uint256 j = i + 1; j < b.sales.length; ++j) {
                if (_lookup(b.sales[j].item.terms) == _lookup(r.terms)) {
                    current = b.sales[j].item.recordHash;
                }
            }
            if (row.current != current) _invalid();
        }
    }

    function _eras(RH.OwnerProvenance memory p) private pure {
        uint256 total;
        uint256 cursor;
        for (uint256 i; i < p.eras.length; ++i) {
            RH.OwnerEra memory era = p.eras[i];
            total += era.nativeCount;
            if (
                era.lowerRevision != (i == 0 ? 0 : 1)
                    || uint256(era.checkpoint.ownerState.revision)
                        != uint256(era.lowerRevision) + era.nativeCount
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
                    || era.checkpoint.replayCount != total
                    || (total == 0 && era.checkpoint.replayRoot != 0)
            ) _invalid();
            for (uint256 j; j < era.nativeCount; ++j) {
                // Each admitted original Consent operation commits once and appends one native occurrence.
                if (
                    uint256(p.journal[cursor++].position.point.ownerRevision)
                        != uint256(era.lowerRevision) + j + 1
                ) _invalid();
            }
        }
    }

    function _aliases(
        RH.OwnerProvenance memory p,
        bytes32[] memory surfaces,
        bytes32[] memory scopes
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

    function _contentScope(Content.Consent memory terms) private pure returns (bytes32) {
        return keccak256(abi.encode(terms, uint64(1)));
    }

    function _royaltyScope(T.RoyaltyFreeze memory terms, bytes32 artist)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(terms, artist, uint64(1)));
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
