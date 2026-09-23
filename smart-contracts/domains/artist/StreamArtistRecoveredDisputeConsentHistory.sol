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

import { StreamArtistRecoveredDisputeConsentValidation as Validation } from "./StreamArtistRecoveredDisputeConsentValidation.sol";

/// @notice Complete original14/15/16 state across every accepted dispute-history generation.
/// @dev Policy/economics original hashes come from the fixed owner's retained maps, never guessed
/// signer/nonce/time fields. Sale has a full original preimage and is checked in its ultimate era.
/// The enclosing Coordinator joins every grant/use to the complete Identity bundle and binding;
/// this owner-local codec neither reauthorizes old signatures nor applies current grant liveness.
library StreamArtistRecoveredDisputeConsentHistory {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_DISPUTE_CONSENTS_V1");
    uint256 private constant MAX_ROWS = 128;

    struct Bundle {
        Base.Bundle original;
        T.Binding[] bindings;
    }

    /// @dev Only a canonical recovered outer envelope may select this additional codec.
    function selected(bytes memory outer) public pure returns (bool) {
        (RH.ExportHeader memory h,) = Payload.decode(outer, 6);
        return (h.requiredFeatures & RH.DISPUTE_HISTORY) != 0;
    }

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms,
        G.Bundle memory bindings
    ) public view returns (Bundle memory b) {
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
            if (op == 16) ++count;
            else if (op != 14 && op != 15) revert T.UnsupportedProfile();
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
        validate(b, q, p);
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
    ) public returns (Base.Bundle memory imported) {
        (RH.ExportHeader memory header, Payload.Payload memory payload) = Payload.decode(outer, 6);
        if (payload.nonces.length != 0 || (header.requiredFeatures & RH.DISPUTE_HISTORY) == 0) {
            _invalid();
        }
        Bundle memory b = decode(q, payload.provenance, payload.semanticState);
        if (
            (header.requiredFeatures & (RH.CONTENT_CONSENTS | RH.RATIFICATIONS | RH.ATTESTATIONS))
                    != 0
                || ((header.requiredFeatures & RH.BINDING_GENERATIONS) != 0)
                    != (b.bindings.length > 1)
        ) _invalid();
        if (
            ((header.requiredFeatures & RH.DIRECT_ECONOMICS) != 0)
                != (b.original.economics.length != 0)
        ) {
            _invalid();
        }
        for (uint256 i; i < b.original.policies.length; ++i) {
            bytes32 key = _policyScope(q.collectionId, b.original.keys[i]);
            DH.Policy memory r = b.original.policies[i];
            if (policies[key] != 0 || delegations[r.recordHash] != 0) _invalid();
            policies[key] = r.recordHash;
            delegations[r.recordHash] = r.grant;
        }
        Evidence.Association memory emptyAssociation;
        for (uint256 i; i < b.original.economics.length; ++i) {
            Base.Economics memory row = b.original.economics[i];
            EH.Row memory r = row.item;
            bytes32 key = Association.key(
                r.terms, q.artistId, r.association.bindingGeneration, r.association.bindingHash
            );
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
        for (uint256 i; i < b.original.sales.length; ++i) {
            Sale.Record memory r = b.original.sales[i].item;
            if (
                keccak256(abi.encode(sales[r.recordHash])) != keccak256(abi.encode(emptySale))
                    || delegations[r.recordHash] != 0 || latest[_lookup(r.terms)] != 0
            ) _invalid();
        }
        for (uint256 i; i < b.original.sales.length; ++i) {
            DH.Sale memory r = b.original.sales[i];
            sales[r.item.recordHash] = r.item;
            delegations[r.item.recordHash] = r.grant;
            latest[_lookup(r.item.terms)] = r.current;
        }
        return b.original;
    }

    function validate(Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p) public pure {
        Validation.validate(b, q, p);
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
