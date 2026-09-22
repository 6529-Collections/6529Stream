// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDelegatedConsentHydration as Base
} from "./StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistEconomicsAssociation as Association
} from "./StreamArtistEconomicsAssociation.sol";
import { StreamArtistSaleHashes } from "./StreamArtistSaleHashes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import {
    IStreamArtistEconomicsEvidence as Evidence
} from "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistContentTypes as Content
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";

/// @notice Original Consent maps with separate all-target checks and historical principal keys.
/// @dev The caller proves complete original rows first, checks every collection through both
/// check functions, then installs. Per-record association/item Artists are already bound to
/// genuine saved generations; the current bundle header does not select their storage keys.
library StreamArtistCompleteHistoryConsentWrites {
    function checkBase(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage economics,
        mapping(bytes32 => bytes32) storage associated,
        mapping(bytes32 => Evidence.Association) storage associations,
        mapping(bytes32 => bytes32) storage delegations,
        mapping(bytes32 => Sale.Record) storage sales,
        mapping(bytes32 => bytes32) storage latest,
        AH.Query memory q,
        Base.Bundle memory b
    ) public view {
        if (b.keys.length != b.policies.length || b.collectionId != q.collectionId) _invalid();
        for (uint256 i; i < b.policies.length; ++i) {
            if (
                policies[_policyScope(q.collectionId, b.keys[i])] != 0
                    || delegations[b.policies[i].recordHash] != 0
            ) _invalid();
        }
        Evidence.Association memory emptyAssociation;
        for (uint256 i; i < b.economics.length; ++i) {
            EH.Row memory r = b.economics[i].item;
            bytes32 key = Association.key(
                r.terms,
                r.association.artistId,
                r.association.bindingGeneration,
                r.association.bindingHash
            );
            if (
                economics[r.association.payloadHash] != 0 || associated[key] != 0
                    || delegations[r.recordHash] != 0
                    || keccak256(abi.encode(associations[r.recordHash]))
                        != keccak256(abi.encode(emptyAssociation))
            ) _invalid();
        }
        Sale.Record memory emptySale;
        for (uint256 i; i < b.sales.length; ++i) {
            Sale.Record memory r = b.sales[i].item;
            if (
                keccak256(abi.encode(sales[r.recordHash])) != keccak256(abi.encode(emptySale))
                    || delegations[r.recordHash] != 0 || latest[_lookup(r.terms)] != 0
            ) _invalid();
        }
    }

    function installBase(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage economics,
        mapping(bytes32 => bytes32) storage associated,
        mapping(bytes32 => Evidence.Association) storage associations,
        mapping(bytes32 => bytes32) storage delegations,
        mapping(bytes32 => Sale.Record) storage sales,
        mapping(bytes32 => bytes32) storage latest,
        AH.Query memory q,
        Base.Bundle memory b
    ) public {
        for (uint256 i; i < b.policies.length; ++i) {
            DH.Policy memory r = b.policies[i];
            policies[_policyScope(q.collectionId, b.keys[i])] = r.recordHash;
            delegations[r.recordHash] = r.grant;
        }
        for (uint256 i; i < b.economics.length; ++i) {
            Base.Economics memory row = b.economics[i];
            EH.Row memory r = row.item;
            bytes32 key = Association.key(
                r.terms,
                r.association.artistId,
                r.association.bindingGeneration,
                r.association.bindingHash
            );
            economics[r.association.payloadHash] = r.association.originalRecord;
            associated[key] = r.recordHash;
            associations[r.recordHash] = r.association;
            delegations[r.recordHash] = row.grant;
        }
        for (uint256 i; i < b.sales.length; ++i) {
            DH.Sale memory r = b.sales[i];
            sales[r.item.recordHash] = r.item;
            delegations[r.item.recordHash] = r.grant;
            latest[_lookup(r.item.terms)] = r.current;
        }
    }

    function checkContent(
        mapping(bytes32 => ContentOwner.ConsentRecord) storage consents,
        mapping(bytes32 => bytes32) storage latestConsents,
        mapping(bytes32 => T.RoyaltyFreezeRecord) storage royalties,
        mapping(bytes32 => Content.FreezeRecord) storage freezes,
        mapping(bytes32 => bytes32) storage latestFreezes,
        mapping(bytes32 => bytes32) storage delegations,
        ContentH.Bundle memory b
    ) public view {
        ContentOwner.ConsentRecord memory emptyConsent;
        T.RoyaltyFreezeRecord memory emptyRoyalty;
        Content.FreezeRecord memory emptyFreeze;
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            if (
                keccak256(abi.encode(consents[r.recordHash])) != keccak256(abi.encode(emptyConsent))
                    || latestConsents[_contentScope(r.terms, r.bindingGeneration)] != 0
                    || delegations[r.recordHash] != 0
            ) _invalid();
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            ContentH.Royalty memory r = b.royalties[i];
            if (
                keccak256(
                            abi.encode(
                                royalties[_royaltyScope(
                                        r.terms, r.item.artistId, r.item.bindingGeneration
                                    )]
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
                                r.bindingGeneration,
                                r.metadataContract,
                                r.lockClasses[j]
                            )
                        ] != 0
                ) _invalid();
            }
        }
    }

    function installContent(
        mapping(bytes32 => ContentOwner.ConsentRecord) storage consents,
        mapping(
            bytes32 => bytes32
        ) storage latestConsents,
        mapping(bytes32 => T.RoyaltyFreezeRecord) storage royalties,
        mapping(
            bytes32 => Content.FreezeRecord
        ) storage freezes,
        mapping(bytes32 => bytes32) storage latestFreezes,
        mapping(bytes32 => bytes32) storage delegations,
        ContentH.Bundle memory b
    ) public {
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            consents[r.recordHash] = r;
            latestConsents[_contentScope(r.terms, r.bindingGeneration)] = r.recordHash;
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            ContentH.Royalty memory r = b.royalties[i];
            royalties[_royaltyScope(r.terms, r.item.artistId, r.item.bindingGeneration)] = r.item;
            delegations[r.item.recordHash] = r.grant;
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            freezes[r.recordHash] = r;
            for (uint256 j; j < r.lockClasses.length; ++j) {
                latestFreezes[
                    _freezeLookup(
                        b.original.collectionId,
                        r.bindingGeneration,
                        r.metadataContract,
                        r.lockClasses[j]
                    )
                ] = r.recordHash;
            }
        }
    }

    function _policyScope(uint256 id, AH.PolicyKey memory key) private pure returns (bytes32) {
        return keccak256(abi.encode(id, key.phaseId, key.policyHash));
    }

    function _lookup(Sale.Consent memory p) private pure returns (bytes32) {
        return StreamArtistSaleHashes.lookup(p.collectionId, p.saleId, p.saleConfigHash);
    }

    function _contentScope(Content.Consent memory p, uint64 generation)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(p, generation));
    }

    function _royaltyScope(T.RoyaltyFreeze memory p, bytes32 artist, uint64 generation)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(p, artist, generation));
    }

    function _freezeLookup(uint256 id, uint64 generation, address metadata, bytes32 lockClass)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(id, generation, metadata, lockClass));
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
