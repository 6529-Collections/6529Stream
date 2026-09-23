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
    StreamArtistRecoveredRatificationHydration as Ratified
} from "./StreamArtistRecoveredRatificationHydration.sol";

/// @notice Complete original ratification and consent source maps under one provenance.
/// @dev Only the facade authenticates the returned rows with the full pure validator, then
/// calls requireHeads in the original order. These workers never install or authorize state.
library StreamArtistRecoveredRatificationReads {
    uint256 private constant MAX_ROWS = 128;

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        uint64 generation
    ) public view returns (Ratified.Bundle memory full) {
        if (generation == 0 || generation > 128) revert T.UnsupportedProfile();
        full.consent = _collectRows(source, q, p, economics, royalties, generation);
        uint256 count;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.operation == 52) ++count;
        }
        if (count == 0 || count > 128) revert T.UnsupportedProfile();
        full.ratifications = new T.RatificationRecord[](count);
        count = 0;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.operation != 52) continue;
            bytes32 record = p.journal[i].receipt.recordHash;
            T.RatificationRecord memory r = Consent(source).ratificationRecord(record);
            if (r.recordHash != record || Delegated(source).recordDelegation(record) != 0) _invalid();
            full.ratifications[count++] = r;
        }
    }

    function requireAllHeads(address source, Ratified.Bundle memory full, uint64 generation)
        public
        view
    {
        if (full.ratifications.length == 0) _invalid();
        if (
            keccak256(
                    abi.encode(
                        Consent(source).firstReleaseRatification(full.consent.original.collectionId)
                    )
                ) != keccak256(abi.encode(full.ratifications[full.ratifications.length - 1]))
        ) _invalid();
        _requireHeads(source, full.consent, generation);
    }

    function _collectRows(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        uint64 generation
    ) private view returns (ContentH.Bundle memory b) {
        Provenance.validateOwnerSource(p, 6, source);
        uint256 cc;
        uint256 rc;
        uint256 fc;
        for (uint256 i; i < p.journal.length; ++i) {
            uint16 op = p.journal[i].receipt.operation;
            if (op == 17) ++cc;
            else if (op == 20) ++rc;
            else if (op == 21) ++fc;
            else if (op != 14 && op != 15 && op != 16 && op != 52) revert T.UnsupportedProfile();
        }
        if (cc > MAX_ROWS || rc > MAX_ROWS || fc > MAX_ROWS || royalties.length != rc) {
            revert T.UnsupportedProfile();
        }
        b.original = _base(source, q, p, economics, generation);
        b.consents = new ContentOwner.ConsentRecord[](cc);
        b.royalties = new ContentH.Royalty[](rc);
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
                    Consent(source).royaltyFreezeRecord(terms, q.artistId, generation);
                if (item.recordHash != n.receipt.recordHash) _invalid();
                b.royalties[rc++] = ContentH.Royalty(
                    terms, item, Delegated(source).recordDelegation(item.recordHash)
                );
            } else if (n.receipt.operation == 21) {
                b.freezes[fc++] = ContentOwner(source).contentFreezeRecord(n.receipt.recordHash);
                if (Delegated(source).recordDelegation(n.receipt.recordHash) != 0) _invalid();
            }
        }
    }

    function requireHeads(address source, ContentH.Bundle memory b) public view {
        _requireHeads(source, b, 1);
    }

    function requireHeadsAt(address source, ContentH.Bundle memory b, uint64 generation)
        public
        view
    {
        if (generation < 2 || generation > 128) revert T.UnsupportedProfile();
        _requireHeads(source, b, generation);
    }

    function _requireHeads(address source, ContentH.Bundle memory b, uint64 generation)
        private
        view
    {
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            uint256 last = i;
            for (uint256 j = i + 1; j < b.consents.length; ++j) {
                if (
                    _contentScope(b.consents[j].terms, generation)
                        == _contentScope(r.terms, generation)
                ) last = j;
            }
            if (
                keccak256(abi.encode(ContentOwner(source).contentConsentAt(r.terms, generation)))
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
                                        generation,
                                        r.metadataContract,
                                        r.lockClasses[k]
                                    )
                            )
                        ) != keccak256(abi.encode(b.freezes[last]))
                ) _invalid();
            }
        }
    }

    function _base(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms,
        uint64 generation
    ) private view returns (Base.Bundle memory b) {
        if (q.policies.length > MAX_ROWS || terms.length > MAX_ROWS) {
            revert T.UnsupportedProfile();
        }
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
                Evidence(source)
                        .economicsRecordForBinding(terms[i], q.artistId, generation, q.bindingHash)
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
            } else if (op != 14 && op != 15 && op != 17 && op != 20 && op != 21 && op != 52) {
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

    function _contentScope(Content.Consent memory terms, uint64 generation)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(terms, generation));
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
