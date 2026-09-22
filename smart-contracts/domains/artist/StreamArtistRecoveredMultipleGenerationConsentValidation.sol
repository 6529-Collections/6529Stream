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

import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistEconomicsAssociation as Association
} from "./StreamArtistEconomicsAssociation.sol";

/// @notice Complete aggregate Consent journals with original per-record binding generations.
/// @dev Full fixed-owner provenance is retained. The caller authenticates every supplied
/// binding and proves the enclosing generation profile; no op14 generation is invented.
library StreamArtistRecoveredMultipleGenerationConsentValidation {
    bytes32 private constant POLICY = keccak256("consent_finality.replay.policy_consent_key");
    bytes32 private constant ECONOMICS = keccak256("consent_finality.replay.consent_key");
    bytes32 private constant SALE = keccak256("consent_finality.replay.sale_consent_key");
    bytes32 private constant CONTENT = keccak256("consent_finality.replay.content_consent_key");
    bytes32 private constant FREEZE = keccak256("consent_finality.replay.freeze_key");
    uint256 private constant MAX_ROWS = 128;

    function validate(
        G.Consents[] memory all,
        AH.Query[] memory queries,
        RH.OwnerProvenance memory p
    ) public pure {
        T.RatificationRecord[][] memory ratifications = new T.RatificationRecord[][](all.length);
        for (uint256 i; i < all.length; ++i) {
            ratifications[i] = new T.RatificationRecord[](0);
        }
        validate(all, ratifications, queries, p);
    }

    /// @notice Complete Consent validation with original52 rows supplied by the fixed aggregate profile.
    /// @dev The original entry supplies no52 rows and remains strict. These records carry no
    /// generation, signer, nonce or time preimage; the enclosing profile authenticates Identity.
    function validate(
        G.Consents[] memory all,
        T.RatificationRecord[][] memory ratifications,
        AH.Query[] memory queries,
        RH.OwnerProvenance memory p
    ) public pure {
        Provenance.validateOwner(p, 6);
        if (
            all.length == 0 || all.length != queries.length || all.length > 128
                || ratifications.length != all.length
        ) _invalid();
        uint256 rows;
        for (uint256 i; i < all.length; ++i) {
            ContentH.Bundle memory b = all[i].rows;
            AH.Query memory q = queries[i];
            Base.Bundle memory old = b.original;
            if (
                old.keys.length > MAX_ROWS || old.economics.length > MAX_ROWS
                    || old.sales.length > MAX_ROWS || b.consents.length > MAX_ROWS
                    || b.royalties.length > MAX_ROWS || b.freezes.length > MAX_ROWS
                    || ratifications[i].length > MAX_ROWS
            ) revert T.UnsupportedProfile();
            if (
                old.provenance != RH.ownerProvenanceHash(p, 6) || q.artistId == 0
                    || old.artistId != q.artistId || q.collectionId == 0
                    || old.collectionId != q.collectionId || q.bindingHash == 0
                    || old.bindingHash != q.bindingHash || old.policies.length != old.keys.length
                    || keccak256(abi.encode(old.keys)) != keccak256(abi.encode(q.policies))
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (queries[j].collectionId == q.collectionId) _invalid();
            }
            rows += old.policies.length + old.economics.length + old.sales.length
            + b.consents.length + b.royalties.length + b.freezes.length + ratifications[i].length;
            _bindings(all[i].bindings, q);
            _baseRows(old, all[i].bindings);
            _contentRows(b, all[i].bindings);
        }
        if (p.journal.length != rows) _invalid();
        (bytes32[] memory surfaces, bytes32[] memory scopes) = _journal(all, ratifications, p);
        _eras(p);
        _aliases(p, surfaces, scopes);
    }

    function _contentRows(ContentH.Bundle memory b, T.Binding[] memory bindings) private pure {
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            if (
                r.recordHash == 0 || r.artistId != b.original.artistId
                    || !_accepted(bindings, r.bindingGeneration)
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
                    || !_accepted(bindings, r.item.bindingGeneration)
                    || r.terms.resolver == address(0)
                    || r.terms.collectionId != b.original.collectionId
                    || r.terms.revenueClass != keccak256("ROYALTY_ERC2981")
                    || r.terms.expectedAssignmentHash == 0
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    _royaltyScope(
                            b.royalties[j].terms,
                            b.original.artistId,
                            b.royalties[j].item.bindingGeneration
                        ) == _royaltyScope(r.terms, b.original.artistId, r.item.bindingGeneration)
                ) _invalid();
            }
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            if (
                r.recordHash == 0 || r.artistId != b.original.artistId
                    || !_accepted(bindings, r.bindingGeneration)
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

    function _journal(
        G.Consents[] memory all,
        T.RatificationRecord[][] memory ratifications,
        RH.OwnerProvenance memory p
    ) private pure returns (bytes32[] memory surfaces, bytes32[] memory scopes) {
        surfaces = new bytes32[](p.journal.length);
        scopes = new bytes32[](p.journal.length);
        uint256[6][] memory counts = new uint256[6][](all.length);
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            uint256 selected = type(uint256).max;
            for (uint256 k; k < all.length; ++k) {
                if (
                    all[k].rows.original.artistId == row.receipt.artistId
                        && all[k].rows.original.collectionId == row.receipt.collectionId
                ) {
                    if (selected != type(uint256).max) _invalid();
                    selected = k;
                }
            }
            if (selected == type(uint256).max) _invalid();
            ContentH.Bundle memory b = all[selected].rows;
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
                if (counts[selected][0] >= b.original.economics.length) _invalid();
                EH.Row memory r = b.original.economics[counts[selected][0]++].item;
                if (r.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = ECONOMICS;
                scopes[i] = r.association.originalRecord == r.recordHash
                    ? r.association.payloadHash
                    : Association.continuation(
                        r.association.originalRecord,
                        r.terms,
                        all[selected].bindings[r.association.bindingGeneration - 1]
                    );
            } else if (row.receipt.operation == 16) {
                if (counts[selected][1] >= b.original.sales.length) _invalid();
                Sale.Record memory r = b.original.sales[counts[selected][1]++].item;
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
                if (counts[selected][2] >= b.consents.length) _invalid();
                ContentOwner.ConsentRecord memory r = b.consents[counts[selected][2]++];
                if (r.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = CONTENT;
                scopes[i] = keccak256(
                    abi.encode(_contentScope(r.terms, r.bindingGeneration), r.recordHash)
                );
            } else if (row.receipt.operation == 20) {
                if (counts[selected][3] >= b.royalties.length) _invalid();
                ContentH.Royalty memory r = b.royalties[counts[selected][3]++];
                if (r.item.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = FREEZE;
                scopes[i] = _royaltyScope(r.terms, b.original.artistId, r.item.bindingGeneration);
            } else if (row.receipt.operation == 21) {
                if (counts[selected][4] >= b.freezes.length) _invalid();
                Content.FreezeRecord memory r = b.freezes[counts[selected][4]++];
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
                if (counts[selected][5] >= ratifications[selected].length) _invalid();
                T.RatificationRecord memory r = ratifications[selected][counts[selected][5]++];
                if (
                    r.recordHash != row.receipt.recordHash || r.recordHash == 0
                        || r.contentStateHash == 0 || r.metadataContract == address(0)
                ) _invalid();
                surfaces[i] = keccak256("consent_finality.replay.ratification_key");
                scopes[i] = keccak256(abi.encode(b.original.collectionId, r.recordHash));
            } else {
                revert T.UnsupportedProfile();
            }
        }
        for (uint256 selected; selected < all.length; ++selected) {
            ContentH.Bundle memory b = all[selected].rows;
            if (
                counts[selected][0] != b.original.economics.length
                    || counts[selected][1] != b.original.sales.length
                    || counts[selected][2] != b.consents.length
                    || counts[selected][3] != b.royalties.length
                    || counts[selected][4] != b.freezes.length
                    || counts[selected][5] != ratifications[selected].length
            ) _invalid();
        }
    }

    function _baseRows(Base.Bundle memory b, T.Binding[] memory bindings) private pure {
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
                    || !_binding(bindings, a.bindingGeneration, a.bindingHash, false)
                    || a.payloadHash != keccak256(abi.encode(t))
            ) _invalid();
            bytes32 original = r.recordHash;
            uint64 originalGeneration = a.bindingGeneration;
            for (uint256 j; j < i; ++j) {
                EH.Row memory prior = b.economics[j].item;
                if (
                    prior.recordHash == r.recordHash
                        || (prior.association.payloadHash == a.payloadHash
                            && prior.association.bindingGeneration == a.bindingGeneration)
                ) _invalid();
                if (prior.association.payloadHash == a.payloadHash && original == r.recordHash) {
                    original = prior.recordHash;
                    originalGeneration = prior.association.bindingGeneration;
                }
            }
            // Original economics(payload) remains the first record. Later accepted bindings
            // retain distinct original15 records and continuation replay keys; none is deduped.
            // The producer compares against the first association's generation. Full binding
            // and Archive chronology is authenticated by the enclosing profile.
            if (
                a.originalRecord != original
                    || (original != r.recordHash && a.bindingGeneration <= originalGeneration)
            ) _invalid();
        }
        for (uint256 i; i < b.sales.length; ++i) {
            DH.Sale memory row = b.sales[i];
            Sale.Record memory r = row.item;
            if (
                r.recordHash == 0 || r.artistId != b.artistId
                    || r.terms.collectionId != b.collectionId || r.terms.saleAdapter == address(0)
                    || r.terms.saleId == 0 || r.terms.saleConfigHash == 0 || r.signer == address(0)
                    || r.signedAt == 0
                    || !_binding(bindings, r.bindingGeneration, r.bindingHash, row.grant != 0)
                    || (row.grant == 0
                            ? (r.authorityClass != 1 && r.authorityClass != 3)
                            : r.authorityClass != 2)
            ) _invalid();
            // Original16 replay is binding-scoped; identical terms may have later-generation records.
            for (uint256 j; j < i; ++j) {
                Sale.Record memory prior = b.sales[j].item;
                if (
                    prior.recordHash == r.recordHash
                        || keccak256(
                                abi.encode(prior.terms, prior.bindingGeneration, prior.bindingHash)
                            ) == keccak256(abi.encode(r.terms, r.bindingGeneration, r.bindingHash))
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

    function _bindings(T.Binding[] memory bindings, AH.Query memory q) private pure {
        if (
            bindings.length == 0 || bindings.length > 128
                || bindings[bindings.length - 1].bindingHash != q.bindingHash
                || !bindings[bindings.length - 1].accepted
        ) _invalid();
        for (uint256 i; i < bindings.length; ++i) {
            T.Binding memory row = bindings[i];
            if (
                row.generation != i + 1 || row.artistId != q.artistId || row.bindingHash == 0
                    || (row.consentMode != 1 && row.consentMode != 2)
            ) _invalid();
        }
    }

    function _accepted(T.Binding[] memory bindings, uint64 generation) private pure returns (bool) {
        return generation != 0 && generation <= bindings.length && bindings[generation - 1].accepted;
    }

    function _binding(
        T.Binding[] memory bindings,
        uint64 generation,
        bytes32 hash,
        bool delegatedSale
    ) private pure returns (bool) {
        if (!_accepted(bindings, generation)) return false;
        T.Binding memory row = bindings[generation - 1];
        return row.bindingHash == hash && (!delegatedSale || row.consentMode == 2);
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

    function _contentScope(Content.Consent memory terms, uint64 generation)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(terms, generation));
    }

    function _royaltyScope(T.RoyaltyFreeze memory terms, bytes32 artist, uint64 generation)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(terms, artist, generation));
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
