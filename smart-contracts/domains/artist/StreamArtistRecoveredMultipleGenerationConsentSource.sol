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

import { StreamArtistRecoveredMultipleGenerationConsentBaseSource as BaseSource } from "./StreamArtistRecoveredMultipleGenerationConsentBaseSource.sol";

/// @notice Fixed-source rows for one collection over the complete original owner provenance.
/// @dev Selection never rebuilds, renumbers or filters the provenance certificate itself.
/// @dev Only the facade authenticates the returned rows with the full pure validator, then
/// calls requireHeads in the original order. These workers never install or authorize state.
library StreamArtistRecoveredMultipleGenerationConsentSource {
    uint256 private constant MAX_ROWS = 128;

    function collectRows(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        T.Binding[] memory bindings
    ) public view returns (ContentH.Bundle memory b) {
        return _collectRows(source, q, p, economics, royalties, bindings, false, false);
    }

    function collectRatifiedRows(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        T.Binding[] memory bindings
    ) public view returns (ContentH.Bundle memory b) {
        return _collectRows(source, q, p, economics, royalties, bindings, true, false);
    }

    /// @dev Only the enclosing global supplement proof may admit the additional original12 rows.
    function collectSupplementedRows(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        T.Binding[] memory bindings
    ) public view returns (ContentH.Bundle memory) {
        return _collectRows(source, q, p, economics, royalties, bindings, true, true);
    }

    function _collectRows(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        T.Binding[] memory bindings,
        bool allowRatifications,
        bool allowSanctions
    ) private view returns (ContentH.Bundle memory b) {
        Provenance.validateOwnerSource(p, 6, source);
        uint256 cc;
        uint256 rc;
        uint256 fc;
        for (uint256 i; i < p.journal.length; ++i) {
            if (
                p.journal[i].receipt.artistId != q.artistId
                    || p.journal[i].receipt.collectionId != q.collectionId
            ) continue;
            uint16 op = p.journal[i].receipt.operation;
            if (op == 17) {
                ++cc;
            } else if (op == 20) {
                ++rc;
            } else if (op == 21) {
                ++fc;
            } else if (
                op != 14 && op != 15 && op != 16 && (!allowRatifications || op != 52)
                    && (!allowSanctions || op != 12)
            ) {
                revert T.UnsupportedProfile();
            }
        }
        if (cc > MAX_ROWS || rc > MAX_ROWS || fc > MAX_ROWS || royalties.length != rc) {
            revert T.UnsupportedProfile();
        }
        b.original = BaseSource.collect(source, q, p, economics, allowRatifications, allowSanctions);
        b.consents = new ContentOwner.ConsentRecord[](cc);
        b.royalties = new ContentH.Royalty[](rc);
        b.freezes = new Content.FreezeRecord[](fc);
        cc = 0;
        rc = 0;
        fc = 0;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory n = p.journal[i];
            if (n.receipt.artistId != q.artistId || n.receipt.collectionId != q.collectionId) {
                continue;
            }
            if (n.receipt.operation == 17) {
                b.consents[cc++] = ContentOwner(source).contentConsentRecord(n.receipt.recordHash);
                if (Delegated(source).recordDelegation(n.receipt.recordHash) != 0) _invalid();
            } else if (n.receipt.operation == 20) {
                T.RoyaltyFreeze memory terms = royalties[rc];
                T.RoyaltyFreezeRecord memory item;
                bool found;
                for (uint256 g; g < bindings.length; ++g) {
                    if (!bindings[g].accepted) continue;
                    T.RoyaltyFreezeRecord memory candidate = Consent(source)
                        .royaltyFreezeRecord(terms, q.artistId, bindings[g].generation);
                    if (candidate.recordHash != n.receipt.recordHash) continue;
                    if (found) _invalid();
                    found = true;
                    item = candidate;
                }
                if (!found) _invalid();
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
        for (uint256 i; i < b.consents.length; ++i) {
            ContentOwner.ConsentRecord memory r = b.consents[i];
            uint256 last = i;
            for (uint256 j = i + 1; j < b.consents.length; ++j) {
                if (
                    _contentScope(b.consents[j].terms, b.consents[j].bindingGeneration)
                        == _contentScope(r.terms, r.bindingGeneration)
                ) last = j;
            }
            if (
                keccak256(
                        abi.encode(
                            ContentOwner(source).contentConsentAt(r.terms, r.bindingGeneration)
                        )
                    ) != keccak256(abi.encode(b.consents[last]))
            ) _invalid();
        }
        for (uint256 i; i < b.freezes.length; ++i) {
            Content.FreezeRecord memory r = b.freezes[i];
            for (uint256 k; k < r.lockClasses.length; ++k) {
                uint256 last = i;
                for (uint256 j = i + 1; j < b.freezes.length; ++j) {
                    if (
                        b.freezes[j].metadataContract != r.metadataContract
                            || b.freezes[j].bindingGeneration != r.bindingGeneration
                    ) continue;
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
                                        r.bindingGeneration,
                                        r.metadataContract,
                                        r.lockClasses[k]
                                    )
                            )
                        ) != keccak256(abi.encode(b.freezes[last]))
                ) _invalid();
            }
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
