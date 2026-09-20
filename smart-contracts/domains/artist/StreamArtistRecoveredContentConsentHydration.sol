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
    StreamArtistContentTypes as Content
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";

import {
    StreamArtistRecoveredContentConsentReads as Reads
} from "./StreamArtistRecoveredContentConsentReads.sol";
import {
    StreamArtistRecoveredContentConsentValidation as Validation
} from "./StreamArtistRecoveredContentConsentValidation.sol";

import {
    StreamArtistRecoveredGenerationConsents as Generation
} from "./StreamArtistRecoveredGenerationConsents.sol";

/// @notice Complete recovered singleton Consent14/15/16/17/20/21 history.
/// @dev Original17/20/21 records omit signer/nonce/time. Their fixed-owner maps, native entries
/// and replay admissions are retained without inventing missing preimages or current eligibility.
library StreamArtistRecoveredContentConsentHydration {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_CONTENT_CONSENTS_V1");

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
        b = Reads.collectRows(source, q, p, economics, royalties);
        validate(b, q, p);
        Reads.requireHeads(source, b);
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
        uint64 generation = 1;
        if (Generation.tagged(payload.semanticState)) {
            if ((header.requiredFeatures & RH.BINDING_GENERATIONS) == 0) _invalid();
            (result, generation) = Generation.decode(q, payload.provenance, payload.semanticState);
        } else {
            result = decode(q, payload.provenance, payload.semanticState);
        }
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
            bytes32 key = Association.key(r.terms, q.artistId, generation, q.bindingHash);
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
        uint64 generation = Generation.generation(b);
        ContentOwner.ConsentRecord memory emptyConsent;
        T.RoyaltyFreezeRecord memory emptyRoyalty;
        Content.FreezeRecord memory emptyFreeze;
        // Precheck every shared head before writing: repeated exact17 terms and overlapping21
        // lock sets are genuine producer histories, not duplicate inventory errors.
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            if (
                keccak256(abi.encode(consents[r.recordHash])) != keccak256(abi.encode(emptyConsent))
                    || latestConsents[_contentScope(r.terms, generation)] != 0
                    || delegations[r.recordHash] != 0
            ) _invalid();
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            Royalty memory r = b.royalties[i];
            if (
                keccak256(
                            abi.encode(
                                royalties[_royaltyScope(r.terms, b.original.artistId, generation)]
                            )
                        ) != keccak256(abi.encode(emptyRoyalty))
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
                                b.original.collectionId,
                                generation,
                                r.metadataContract,
                                r.lockClasses[j]
                            )
                        ] != 0
                ) _invalid();
            }
        }
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            consents[r.recordHash] = r;
            latestConsents[_contentScope(r.terms, generation)] = r.recordHash;
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            Royalty memory r = b.royalties[i];
            royalties[_royaltyScope(r.terms, b.original.artistId, generation)] = r.item;
            delegations[r.item.recordHash] = r.grant;
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            freezes[r.recordHash] = r;
            for (uint256 j; j < r.lockClasses.length; ++j) {
                latestFreezes[
                    _freezeLookup(
                        b.original.collectionId, generation, r.metadataContract, r.lockClasses[j]
                    )
                ] = r.recordHash;
            }
        }
    }

    function validate(Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p) public pure {
        Validation.validate(b, q, p);
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

    function _freezeLookup(
        uint256 collection,
        uint64 generation,
        address metadata,
        bytes32 lockClass
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(collection, generation, metadata, lockClass));
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
