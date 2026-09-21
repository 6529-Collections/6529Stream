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

import {
    StreamArtistRecoveredSanctionConsentValidation as Validation
} from "./StreamArtistRecoveredSanctionConsentValidation.sol";
import {
    StreamArtistRecoveredDisputeConsentHistory as History
} from "./StreamArtistRecoveredDisputeConsentHistory.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionLocalProof as Local
} from "./StreamArtistRecoveredSanctionLocalProof.sol";
import { StreamArtistSanctionState as Sanctions } from "./StreamArtistSanctionState.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    IStreamArtistSanctionArchiveFacts as ArchiveFacts
} from "../../interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";

import {
    StreamArtistRecoveredSanctionConsentHistory as Original
} from "./StreamArtistRecoveredSanctionConsentHistory.sol";

/// @notice Original typed base maps then exact sanction records, within the host op60 guard.
library StreamArtistRecoveredSanctionConsentImport {
    function importState(
        Sanctions.State storage sanctions,
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
        if (payload.nonces.length != 0 || (header.requiredFeatures & RH.SANCTION_HISTORY) == 0) {
            _invalid();
        }
        Original.Bundle memory b = Original.decode(q, payload.provenance, payload.semanticState);
        if (
            (header.requiredFeatures & (RH.CONTENT_CONSENTS | RH.RATIFICATIONS | RH.ATTESTATIONS))
                    != 0
                || ((header.requiredFeatures & RH.BINDING_GENERATIONS) != 0)
                    != (b.base.bindings.length > 1)
        ) _invalid();
        if (
            ((header.requiredFeatures & RH.DIRECT_ECONOMICS) != 0)
                != (b.base.original.economics.length != 0)
        ) {
            _invalid();
        }
        S.Record memory emptySanction;
        ArchiveFacts.Facts memory emptyFacts;
        for (uint256 i; i < b.history.sanctions.length; ++i) {
            H.SanctionRow memory row = b.history.sanctions[i];
            bytes32 key = Sanctions.associationKey(
                row.record.artistId,
                row.record.bindingGeneration,
                row.record.bindingHash,
                row.record.terms
            );
            if (
                keccak256(abi.encode(sanctions.records[row.record.recordHash]))
                        != keccak256(abi.encode(emptySanction)) || sanctions.latest[key] != 0
                    || sanctions.archives[row.record.recordHash].length != 0
                    || keccak256(abi.encode(sanctions.archiveFacts[row.record.recordHash]))
                        != keccak256(abi.encode(emptyFacts))
            ) _invalid();
        }
        for (uint256 i; i < b.base.original.policies.length; ++i) {
            bytes32 key = _policyScope(q.collectionId, b.base.original.keys[i]);
            DH.Policy memory r = b.base.original.policies[i];
            if (policies[key] != 0 || delegations[r.recordHash] != 0) _invalid();
            policies[key] = r.recordHash;
            delegations[r.recordHash] = r.grant;
        }
        Evidence.Association memory emptyAssociation;
        for (uint256 i; i < b.base.original.economics.length; ++i) {
            Base.Economics memory row = b.base.original.economics[i];
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
        for (uint256 i; i < b.base.original.sales.length; ++i) {
            Sale.Record memory r = b.base.original.sales[i].item;
            if (
                keccak256(abi.encode(sales[r.recordHash])) != keccak256(abi.encode(emptySale))
                    || delegations[r.recordHash] != 0 || latest[_lookup(r.terms)] != 0
            ) _invalid();
        }
        for (uint256 i; i < b.base.original.sales.length; ++i) {
            DH.Sale memory r = b.base.original.sales[i];
            sales[r.item.recordHash] = r.item;
            delegations[r.item.recordHash] = r.grant;
            latest[_lookup(r.item.terms)] = r.current;
        }
        // The original publication inventory was imported by the outer owner pipeline.
        // Retain exact original rows; association heads follow the authenticated chronology.
        for (uint256 i; i < b.history.sanctions.length; ++i) {
            H.SanctionRow memory row = b.history.sanctions[i];
            bytes32 hash = row.record.recordHash;
            sanctions.records[hash] = row.record;
            sanctions.archives[hash] = row.archiveBytes;
            sanctions.archiveFacts[hash] = row.archiveFacts;
            sanctions.latest[
                Sanctions.associationKey(
                    row.record.artistId,
                    row.record.bindingGeneration,
                    row.record.bindingHash,
                    row.record.terms
                )
            ] = hash;
        }
        return b.base.original;
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
