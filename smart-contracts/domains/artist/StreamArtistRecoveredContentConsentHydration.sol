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

/// @notice Complete recovered singleton Consent14/15/16/17/20/21 history.
/// @dev Original17/20/21 records omit signer/nonce/time. Their fixed-owner maps, native entries
/// and replay admissions are retained without inventing missing preimages or current eligibility.
library StreamArtistRecoveredContentConsentHydration {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_CONTENT_CONSENTS_V1");
    bytes32 private constant POLICY = keccak256("consent_finality.replay.policy_consent_key");
    bytes32 private constant ECONOMICS = keccak256("consent_finality.replay.consent_key");
    bytes32 private constant SALE = keccak256("consent_finality.replay.sale_consent_key");
    bytes32 private constant CONTENT = keccak256("consent_finality.replay.content_consent_key");
    bytes32 private constant FREEZE = keccak256("consent_finality.replay.freeze_key");
    uint256 private constant MAX_ROWS = 128;

    struct Royalty {
        T.RoyaltyFreeze terms;
        T.RoyaltyFreezeRecord item;
        bytes32 grant;
    }

    struct Bundle {
        Base.Bundle original;
        ContentOwner.ConsentRecord[] consents;
        Royalty[] royalties;
        Content.FreezeRecord[] freezes;
    }

    function selected(bytes memory outer) public pure returns (bool) {
        (RH.ExportHeader memory h,) = Payload.decode(outer, 6);
        return (h.requiredFeatures & RH.CONTENT_CONSENTS) != 0;
    }

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties
    ) public view returns (Bundle memory b) {
        Provenance.validateOwnerSource(p, 6, source);
        uint256 cc;
        uint256 rc;
        uint256 fc;
        for (uint256 i; i < p.journal.length; ++i) {
            uint16 op = p.journal[i].receipt.operation;
            if (op == 17) ++cc;
            else if (op == 20) ++rc;
            else if (op == 21) ++fc;
            else if (op != 14 && op != 15 && op != 16) revert T.UnsupportedProfile();
        }
        if (cc > MAX_ROWS || rc > MAX_ROWS || fc > MAX_ROWS || royalties.length != rc) {
            revert T.UnsupportedProfile();
        }
        b.original = _base(source, q, p, economics);
        b.consents = new ContentOwner.ConsentRecord[](cc);
        b.royalties = new Royalty[](rc);
        b.freezes = new Content.FreezeRecord[](fc);
        cc = 0;
        rc = 0;
        fc = 0;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory n = p.journal[i];
            if (n.receipt.operation == 17) {
                b.consents[cc++] = ContentOwner(source).contentConsentRecord(n.receipt.recordHash);
                if (Delegated(source).recordDelegation(n.receipt.recordHash) != 0) _invalid();
            } else if (n.receipt.operation == 20) {
                T.RoyaltyFreeze memory terms = royalties[rc];
                T.RoyaltyFreezeRecord memory item =
                    Consent(source).royaltyFreezeRecord(terms, q.artistId, 1);
                if (item.recordHash != n.receipt.recordHash) _invalid();
                b.royalties[rc++] =
                    Royalty(terms, item, Delegated(source).recordDelegation(item.recordHash));
            } else if (n.receipt.operation == 21) {
                b.freezes[fc++] = ContentOwner(source).contentFreezeRecord(n.receipt.recordHash);
                if (Delegated(source).recordDelegation(n.receipt.recordHash) != 0) _invalid();
            }
        }
        validate(b, q, p);
        _sourceHeads(source, b);
    }

    function encode(Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes memory)
    {
        validate(b, q, p);
        return abi.encode(SCHEMA, RH.VERSION, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (Bundle memory b)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, b) = abi.decode(raw, (bytes32, uint16, Bundle));
        if (
            tag != SCHEMA || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, b))
        ) _invalid();
        validate(b, q, p);
    }

    /// @notice First half of one atomic fixed-owner import; returns its validated content rows.
    function importState(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage economics,
        mapping(bytes32 => bytes32) storage associated,
        mapping(bytes32 => Evidence.Association) storage associations,
        mapping(bytes32 => bytes32) storage delegations,
        mapping(bytes32 => Sale.Record) storage sales,
        mapping(bytes32 => bytes32) storage latest,
        AH.Query memory q,
        bytes memory outer
    ) public returns (Bundle memory result) {
        (RH.ExportHeader memory header, Payload.Payload memory payload) = Payload.decode(outer, 6);
        if (payload.nonces.length != 0 || (header.requiredFeatures & RH.CONTENT_CONSENTS) == 0) {
            _invalid();
        }
        result = decode(q, payload.provenance, payload.semanticState);
        Base.Bundle memory b = result.original;
        if (((header.requiredFeatures & RH.DIRECT_ECONOMICS) != 0) != (b.economics.length != 0)) {
            _invalid();
        }
        for (uint256 i; i < b.policies.length; ++i) {
            bytes32 key = _policyScope(q.collectionId, b.keys[i]);
            DH.Policy memory r = b.policies[i];
            if (policies[key] != 0 || delegations[r.recordHash] != 0) _invalid();
            policies[key] = r.recordHash;
            delegations[r.recordHash] = r.grant;
        }
        Evidence.Association memory emptyAssociation;
        for (uint256 i; i < b.economics.length; ++i) {
            Base.Economics memory row = b.economics[i];
            EH.Row memory r = row.item;
            bytes32 key = Association.key(r.terms, q.artistId, 1, q.bindingHash);
            if (
                economics[r.association.payloadHash] != 0 || associated[key] != 0
                    || delegations[r.recordHash] != 0
                    || keccak256(abi.encode(associations[r.recordHash]))
                        != keccak256(abi.encode(emptyAssociation))
            ) _invalid();
            economics[r.association.payloadHash] = r.recordHash;
            associated[key] = r.recordHash;
            associations[r.recordHash] = r.association;
            delegations[r.recordHash] = row.grant;
        }
        Sale.Record memory emptySale;
        // Check every original row and lookup before any sale write, including repeated lookups.
        for (uint256 i; i < b.sales.length; ++i) {
            Sale.Record memory r = b.sales[i].item;
            if (
                keccak256(abi.encode(sales[r.recordHash])) != keccak256(abi.encode(emptySale))
                    || delegations[r.recordHash] != 0 || latest[_lookup(r.terms)] != 0
            ) _invalid();
        }
        for (uint256 i; i < b.sales.length; ++i) {
            DH.Sale memory r = b.sales[i];
            sales[r.item.recordHash] = r.item;
            delegations[r.item.recordHash] = r.grant;
            latest[_lookup(r.item.terms)] = r.current;
        }
    }

    /// @notice Second half; only called with the bundle returned by importState in this transaction.
    function importContent(
        mapping(bytes32 => ContentOwner.ConsentRecord) storage consents,
        mapping(bytes32 => bytes32) storage latestConsents,
        mapping(bytes32 => T.RoyaltyFreezeRecord) storage royalties,
        mapping(bytes32 => Content.FreezeRecord) storage freezes,
        mapping(bytes32 => bytes32) storage latestFreezes,
        mapping(bytes32 => bytes32) storage delegations,
        Bundle memory b
    ) public {
        ContentOwner.ConsentRecord memory emptyConsent;
        T.RoyaltyFreezeRecord memory emptyRoyalty;
        Content.FreezeRecord memory emptyFreeze;
        // Precheck every shared head before writing: repeated exact17 terms and overlapping21
        // lock sets are genuine producer histories, not duplicate inventory errors.
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            if (
                keccak256(abi.encode(consents[r.recordHash])) != keccak256(abi.encode(emptyConsent))
                    || latestConsents[_contentScope(r.terms)] != 0 || delegations[r.recordHash] != 0
            ) _invalid();
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            Royalty memory r = b.royalties[i];
            if (
                keccak256(abi.encode(royalties[_royaltyScope(r.terms, b.original.artistId)]))
                        != keccak256(abi.encode(emptyRoyalty))
                    || delegations[r.item.recordHash] != 0
            ) _invalid();
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            if (
                keccak256(abi.encode(freezes[r.recordHash])) != keccak256(abi.encode(emptyFreeze))
                    || delegations[r.recordHash] != 0
            ) _invalid();
            for (uint256 j; j < r.lockClasses.length; ++j) {
                if (
                    latestFreezes[
                            _freezeLookup(
                                b.original.collectionId, r.metadataContract, r.lockClasses[j]
                            )
                        ] != 0
                ) _invalid();
            }
        }
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            consents[r.recordHash] = r;
            latestConsents[_contentScope(r.terms)] = r.recordHash;
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            Royalty memory r = b.royalties[i];
            royalties[_royaltyScope(r.terms, b.original.artistId)] = r.item;
            delegations[r.item.recordHash] = r.grant;
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            freezes[r.recordHash] = r;
            for (uint256 j; j < r.lockClasses.length; ++j) {
                latestFreezes[
                    _freezeLookup(b.original.collectionId, r.metadataContract, r.lockClasses[j])
                ] = r.recordHash;
            }
        }
    }

    function validate(Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p) public pure {
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

    function _contentRows(Bundle memory b) private pure {
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
            Royalty memory r = b.royalties[i];
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

    function _sourceHeads(address source, Bundle memory b) private view {
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            uint256 last = i;
            for (uint256 j = i + 1; j < b.consents.length; ++j) {
                if (_contentScope(b.consents[j].terms) == _contentScope(r.terms)) last = j;
            }
            if (
                keccak256(abi.encode(ContentOwner(source).contentConsentAt(r.terms, 1)))
                    != keccak256(abi.encode(b.consents[last]))
            ) _invalid();
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            for (uint256 k; k < r.lockClasses.length; ++k) {
                uint256 last = i;
                for (uint256 j = i + 1; j < b.freezes.length; ++j) {
                    if (b.freezes[j].metadataContract != r.metadataContract) continue;
                    for (uint256 l; l < b.freezes[j].lockClasses.length; ++l) {
                        if (b.freezes[j].lockClasses[l] == r.lockClasses[k]) last = j;
                    }
                }
                if (
                    keccak256(
                            abi.encode(
                                ContentOwner(source)
                                    .contentFreezeAt(
                                        b.original.collectionId,
                                        1,
                                        r.metadataContract,
                                        r.lockClasses[k]
                                    )
                            )
                        ) != keccak256(abi.encode(b.freezes[last]))
                ) _invalid();
            }
        }
    }

    function _journal(Bundle memory b, RH.OwnerProvenance memory p)
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
                Royalty memory r = b.royalties[royalties++];
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

    function _freezeLookup(uint256 collection, address metadata, bytes32 lockClass)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(collection, uint64(1), metadata, lockClass));
    }

    function _base(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms
    ) private view returns (Base.Bundle memory b) {
        if (q.policies.length > MAX_ROWS || terms.length > MAX_ROWS) revert T.UnsupportedProfile();
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
        for (uint256 i; i < terms.length; ++i) {
            bytes32 record = Consent(source).economicsRecord(terms[i]);
            if (
                Evidence(source).economicsRecordForBinding(terms[i], q.artistId, 1, q.bindingHash)
                    != record
            ) _invalid();
            b.economics[i] = Base.Economics(
                EH.Row(record, terms[i], Evidence(source).economicsRecordAssociation(record)),
                Delegated(source).recordDelegation(record)
            );
        }
        uint256 count;
        for (uint256 i; i < p.journal.length; ++i) {
            uint16 op = p.journal[i].receipt.operation;
            if (op == 16) {
                ++count;
            } else if (op != 14 && op != 15 && op != 17 && op != 20 && op != 21) {
                revert T.UnsupportedProfile();
            }
        }
        if (count > MAX_ROWS) revert T.UnsupportedProfile();
        b.sales = new DH.Sale[](count);
        count = 0;
        for (uint256 i; i < p.journal.length; ++i) {
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
