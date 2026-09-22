// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Native
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Original retained documents and signatures for all authentic selected binding generations.
library StreamArtistRecoveredMultipleDisputeIdentityFacts {
    struct IdentityRows {
        bytes32 artistId;
        IH.DocumentRow[] documents;
        IH.SignatureRow[] signatures;
    }

    struct Context {
        bytes[] identities;
        M.State scope;
        G.Inventory inventory;
        A.AcceptanceBundle[] accepted;
        RH.Provenance provenance;
    }

    function validate(Context calldata x) public pure {
        if (
            x.identities.length != x.scope.artists.length
                || x.inventory.bindings.length != x.scope.collections.length
                || x.accepted.length != x.scope.collections.length
        ) _invalid();
        for (uint256 a; a < x.identities.length; ++a) {
            IH.Bundle calldata original = Frame.bundle(x.identities[a]);
            if (original.artistId != x.scope.artists[a].artistId) _invalid();
            IdentityRows memory id =
                IdentityRows(original.artistId, original.documents, original.signatures);
            for (uint256 k; k < x.scope.collections.length; ++k) {
                AH.Query memory q = x.scope.collections[k];
                if (q.artistId != id.artistId) continue;
                uint256 cursor;
                for (uint256 g; g < x.inventory.generations[k].length; ++g) {
                    A.Generation memory generation = x.inventory.generations[k][g];
                    _document(id, x.inventory.bindings[k].bindings.rows[g].item.identityRecordHash);
                    if (generation.accepted) {
                        if (cursor >= x.accepted[k].rows.length) _invalid();
                        A.Acceptance memory r = x.accepted[k].rows[cursor++];
                        if (
                            r.generation != generation.generation
                                || r.bindingHash != generation.bindingHash
                        ) _invalid();
                        RH.JournalEntry memory native_ = Native.occurrence(
                            RH.ownerProvenance(x.provenance, 3), q, 2, r.recordHash
                        );
                        if (
                            native_.position.point.environmentHash
                                != generation.proposal.environmentHash
                        ) _invalid();
                        _signature(id, r.recordHash);
                    } else if (x.inventory.bindings[k].bindings.rows[g].terminal.kind == 1) {
                        bytes32 hash = x.inventory.bindings[k].bindings.rows[g].terminal.recordHash;
                        RH.JournalEntry memory refused =
                            Native.occurrence(RH.ownerProvenance(x.provenance, 0), q, 3, hash);
                        if (!Clock.before(
                                x.provenance, generation.proposal, refused.position.point
                            )) _invalid();
                        _signature(id, hash);
                    } else if (x.inventory.bindings[k].bindings.rows[g].terminal.kind != 2) {
                        // No acceptance/refusal signature is invented for an original
                        // pending generation closed by an authenticated arbiter revocation.
                        if (
                            x.inventory.bindings[k].bindings.rows[g].terminal.kind != 0
                                || g + 1 >= x.inventory.generations[k].length
                                || x.inventory.bindings[k].corrections[g + 1].recordHash == 0
                                || x.inventory.bindings[k].corrections[g + 1].approval.cause != 4
                        ) _invalid();
                    }
                }
                if (cursor != x.accepted[k].rows.length) _invalid();
            }
        }
        for (uint256 i; i < x.provenance.journals[2].length; ++i) {
            uint16 op = x.provenance.journals[2][i].receipt.operation;
            if (op == 2 || op == 3 || op == 4 || op == 44 || op == 45 || op == 47) _invalid();
        }
    }

    function _document(IdentityRows memory identity, bytes32 hash) private pure {
        if (hash == 0) _invalid();
        bool found;
        for (uint256 i; i < identity.documents.length; ++i) {
            if (identity.documents[i].documentHash != hash) continue;
            if (found || keccak256(identity.documents[i].document) != hash) _invalid();
            found = true;
        }
        // The original registration document and every previous/revised original25 document
        // survive in this exact source-authenticated set, even when no longer operative.
        if (!found) _invalid();
    }

    function _signature(IdentityRows memory identity, bytes32 record) private pure {
        bool found;
        for (uint256 i; i < identity.signatures.length; ++i) {
            if (identity.signatures[i].recordHash != record) continue;
            if (found || identity.signatures[i].signature.length > 4096) _invalid();
            found = true;
        }
        // Empty direct/Safe evidence and nonempty opaque signatures are both retained exactly.
        if (!found) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
