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

import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAggregateSanctionConsentTypes as F
} from "./StreamArtistAggregateSanctionConsentTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAggregateSanctionConsentTransport as SanctionTransport
} from "./StreamArtistRecoveredAggregateSanctionConsentTransport.sol";
import {
    StreamArtistRecoveredAggregateSanctionConsentFacts as SanctionFacts
} from "./StreamArtistRecoveredAggregateSanctionConsentFacts.sol";

/// @notice One complete owner6 proof across original historical principals and collection heads.
/// @dev The fixed caller authenticates CompleteHistory inventory, binding chronology, Identity and
/// original sanction Archive evidence. Current selectors anchor wrappers only. No local revisions
/// from different owners are compared, and no generation is invented for original14 or52.
library StreamArtistCompleteHistoryConsentValidation {
    bytes32 private constant POLICY = keccak256("consent_finality.replay.policy_consent_key");
    bytes32 private constant ECONOMICS = keccak256("consent_finality.replay.consent_key");
    bytes32 private constant SALE = keccak256("consent_finality.replay.sale_consent_key");
    bytes32 private constant CONTENT = keccak256("consent_finality.replay.content_consent_key");
    bytes32 private constant FREEZE = keccak256("consent_finality.replay.freeze_key");
    uint256 private constant MAX_ROWS = 128;

    function validate(
        G.Consents[] memory all,
        T.RatificationRecord[][] memory ratifications,
        M.State memory scope,
        CT.Inventory memory inventory,
        bytes memory sanctionInventory
    ) public pure {
        RH.OwnerProvenance memory p = RH.ownerProvenance(inventory.provenance, 6);
        bytes32 provenance = Provenance.validateOwner(p, 6);
        if (
            all.length == 0 || all.length != scope.collections.length || all.length > MAX_ROWS
                || ratifications.length != all.length || scope.artists.length > MAX_ROWS
                || inventory.bindings.bindings.length != all.length
                || inventory.bindings.generations.length != all.length
        ) _invalid();
        for (uint256 i; i < scope.artists.length; ++i) {
            if (
                scope.artists[i].artistId == 0
                    || (i != 0 && scope.artists[i].artistId <= scope.artists[i - 1].artistId)
            ) _invalid();
        }
        F.Facts memory facts = _sanctions(sanctionInventory);
        uint256 rows = facts.sanctions.length;
        for (uint256 i; i < all.length; ++i) {
            ContentH.Bundle memory b = all[i].rows;
            AH.Query memory q = scope.collections[i];
            Base.Bundle memory old = b.original;
            if (
                old.keys.length > MAX_ROWS || old.economics.length > MAX_ROWS
                    || old.sales.length > MAX_ROWS || b.consents.length > MAX_ROWS
                    || b.royalties.length > MAX_ROWS || b.freezes.length > MAX_ROWS
                    || ratifications[i].length > MAX_ROWS
            ) revert T.UnsupportedProfile();
            if (
                old.provenance != provenance || old.artistId != q.artistId || q.collectionId == 0
                    || old.collectionId != q.collectionId || old.bindingHash != q.bindingHash
                    || old.policies.length != old.keys.length
                    || keccak256(abi.encode(old.keys)) != keccak256(abi.encode(q.policies))
                    || (i != 0 && q.collectionId <= scope.collections[i - 1].collectionId)
            ) _invalid();
            uint256 count = old.policies.length + old.economics.length + old.sales.length
                + b.consents.length + b.royalties.length + b.freezes.length
                + ratifications[i].length;
            rows += count;
            _bindings(all[i].bindings, scope, inventory, i);
            if (all[i].bindings.length == 0 && count != 0) _invalid();
            _baseRows(old, all[i].bindings);
            _contentRows(b, all[i].bindings);
        }
        if (p.journal.length != rows) _invalid();
        (bytes32[] memory surfaces, bytes32[] memory scopes) =
            _journal(all, ratifications, scope, p);
        if (facts.sanctions.length != 0) SanctionFacts.validate(all, scope.collections, p, facts);
        SanctionFacts.nativeRows(p, facts);
        // One global census, including original zero-native13 mutations and every era alias.
        SanctionFacts.clocksAndAliases(p, surfaces, scopes, facts);
    }

    function _sanctions(bytes memory raw) private pure returns (F.Facts memory facts) {
        if (raw.length == 0) {
            facts.sanctions = new F.Record[](0);
            facts.confirmations = new H.ConfirmationRow[](0);
            return facts;
        }
        H.Inventory memory history = abi.decode(raw, (H.Inventory));
        if (
            keccak256(raw) != keccak256(abi.encode(history)) || history.sanctions.length == 0
                || history.operations.length == 0 || history.catalogues.length == 0
        ) _invalid();
        return SanctionTransport.facts(history);
    }

    function _contentRows(ContentH.Bundle memory b, T.Binding[] memory bindings) private pure {
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            if (
                r.recordHash == 0 || !_accepted(bindings, r.bindingGeneration, r.artistId)
                    || (r.authorityClass != 1 && r.authorityClass != 3)
                    || r.terms.collectionId != b.original.collectionId
                    || r.terms.metadataContract == address(0) || r.terms.familyId == 0
                    || r.terms.newStateHash == 0
            ) _invalid();
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            ContentH.Royalty memory r = b.royalties[i];
            if (
                r.item.recordHash == 0
                    || !_accepted(bindings, r.item.bindingGeneration, r.item.artistId)
                    || r.terms.resolver == address(0)
                    || r.terms.collectionId != b.original.collectionId
                    || r.terms.revenueClass != keccak256("ROYALTY_ERC2981")
                    || r.terms.expectedAssignmentHash == 0
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    _royaltyScope(
                            b.royalties[j].terms,
                            b.royalties[j].item.artistId,
                            b.royalties[j].item.bindingGeneration
                        ) == _royaltyScope(r.terms, r.item.artistId, r.item.bindingGeneration)
                ) _invalid();
            }
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            if (
                r.recordHash == 0 || !_accepted(bindings, r.bindingGeneration, r.artistId)
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
        M.State memory scope,
        RH.OwnerProvenance memory p
    ) private pure returns (bytes32[] memory surfaces, bytes32[] memory scopes) {
        surfaces = new bytes32[](p.journal.length);
        scopes = new bytes32[](p.journal.length);
        uint256[6][] memory counts = new uint256[6][](all.length);
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            uint256 selected = Scope.collection(scope, row.receipt.collectionId);
            Scope.artist(scope, row.receipt.artistId);
            ContentH.Bundle memory b = all[selected].rows;
            for (uint256 j; j < i; ++j) {
                if (p.journal[j].receipt.recordHash == row.receipt.recordHash) _invalid();
            }
            if (row.receipt.operation == 12) {
                surfaces[i] = H.SANCTION;
                scopes[i] = keccak256(abi.encode(row.receipt.recordHash));
            } else if (row.receipt.operation == 14) {
                if (!_historicalArtist(all[selected].bindings, row.receipt.artistId)) _invalid();
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
                if (
                    r.recordHash != row.receipt.recordHash
                        || r.association.artistId != row.receipt.artistId
                ) _invalid();
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
                    r.recordHash != row.receipt.recordHash || r.artistId != row.receipt.artistId
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
                if (r.recordHash != row.receipt.recordHash || r.artistId != row.receipt.artistId) {
                    _invalid();
                }
                surfaces[i] = CONTENT;
                scopes[i] = keccak256(
                    abi.encode(_contentScope(r.terms, r.bindingGeneration), r.recordHash)
                );
            } else if (row.receipt.operation == 20) {
                if (counts[selected][3] >= b.royalties.length) _invalid();
                ContentH.Royalty memory r = b.royalties[counts[selected][3]++];
                if (
                    r.item.recordHash != row.receipt.recordHash
                        || r.item.artistId != row.receipt.artistId
                ) _invalid();
                surfaces[i] = FREEZE;
                scopes[i] = _royaltyScope(r.terms, r.item.artistId, r.item.bindingGeneration);
            } else if (row.receipt.operation == 21) {
                if (counts[selected][4] >= b.freezes.length) _invalid();
                Content.FreezeRecord memory r = b.freezes[counts[selected][4]++];
                if (r.recordHash != row.receipt.recordHash || r.artistId != row.receipt.artistId) {
                    _invalid();
                }
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
                if (!_historicalArtist(all[selected].bindings, row.receipt.artistId)) _invalid();
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
                    || (t.scope == 2 && t.scopeId == 0)
                    || !_binding(bindings, a.bindingGeneration, a.bindingHash, a.artistId, false)
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
                r.recordHash == 0 || r.terms.collectionId != b.collectionId
                    || r.terms.saleAdapter == address(0) || r.terms.saleId == 0
                    || r.terms.saleConfigHash == 0 || r.signer == address(0) || r.signedAt == 0
                    || !_binding(
                        bindings, r.bindingGeneration, r.bindingHash, r.artistId, row.grant != 0
                    )
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

    function _bindings(
        T.Binding[] memory bindings,
        M.State memory scope,
        CT.Inventory memory inventory,
        uint256 k
    ) private pure {
        AH.Query memory q = scope.collections[k];
        uint256 n = bindings.length;
        if (
            n > MAX_ROWS || inventory.bindings.bindings[k].bindings.rows.length != n
                || inventory.bindings.generations[k].length != n
        ) _invalid();
        T.Binding memory head = inventory.bindings.bindings[k].bindings.current;
        if (n == 0) {
            T.Binding memory empty;
            if (
                q.artistId != 0 || q.bindingHash != 0
                    || keccak256(abi.encode(head)) != keccak256(abi.encode(empty))
            ) _invalid();
            return;
        }
        if (
            keccak256(abi.encode(head)) != keccak256(abi.encode(bindings[n - 1]))
                || head.artistId != q.artistId || head.bindingHash != q.bindingHash
        ) _invalid();
        for (uint256 i; i < n; ++i) {
            T.Binding memory row = bindings[i];
            Scope.artist(scope, row.artistId);
            if (
                row.generation != i + 1 || row.bindingHash == 0
                    || (row.consentMode != 1 && row.consentMode != 2)
                    || keccak256(abi.encode(row))
                        != keccak256(
                            abi.encode(inventory.bindings.bindings[k].bindings.rows[i].item)
                        ) || inventory.bindings.generations[k][i].generation != row.generation
                    || inventory.bindings.generations[k][i].bindingHash != row.bindingHash
                    || inventory.bindings.generations[k][i].accepted != row.accepted
            ) _invalid();
        }
    }

    function _historicalArtist(T.Binding[] memory bindings, bytes32 artist)
        private
        pure
        returns (bool)
    {
        for (uint256 i; i < bindings.length; ++i) {
            if (bindings[i].artistId == artist && bindings[i].accepted) return true;
        }
        return false;
    }

    function _accepted(T.Binding[] memory bindings, uint64 generation, bytes32 artist)
        private
        pure
        returns (bool)
    {
        return artist != 0 && generation != 0 && generation <= bindings.length
            && bindings[generation - 1].accepted && bindings[generation - 1].artistId == artist;
    }

    function _binding(
        T.Binding[] memory bindings,
        uint64 generation,
        bytes32 hash,
        bytes32 artist,
        bool delegatedSale
    ) private pure returns (bool) {
        if (!_accepted(bindings, generation, artist)) return false;
        T.Binding memory row = bindings[generation - 1];
        return row.bindingHash == hash && (!delegatedSale || row.consentMode == 2);
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
