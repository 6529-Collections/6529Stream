// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistCollaboratorRecordsOwner as Collaborator
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCatalogue as Catalogue
} from "./StreamArtistPrimaryCollaboratorCatalogue.sol";
import {
    StreamArtistPrimaryCollaboratorBindingSource as Bindings
} from "./StreamArtistPrimaryCollaboratorBindingSource.sol";
import {
    StreamArtistPrimaryCollaboratorBindingProof as BindingProof
} from "./StreamArtistPrimaryCollaboratorBindingProof.sol";
import {
    StreamArtistPrimaryCollaboratorRecords as Records
} from "./StreamArtistPrimaryCollaboratorRecords.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistPrimaryCollaboratorAcceptance as Acceptance
} from "./StreamArtistPrimaryCollaboratorAcceptance.sol";
import {
    StreamArtistPrimaryCollaboratorAccountNonces as Accounts
} from "./StreamArtistPrimaryCollaboratorAccountNonces.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";

import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";

/// @notice Exact full clock and binding validation in the original source-read order.
library StreamArtistPrimaryCollaboratorSourceClocks {
    function validate(M.State memory scope, PC.Proof memory proof)
        public
        view
        returns (Clocks.Result memory result)
    {
        bool nonempty =
            proof.archive.proposals.length != 0 || proof.archive.accepted.length != 0;
        for (uint256 k; k < proof.bindings.bindings.length; ++k) {
            for (uint256 g; g < proof.bindings.generations[k].length; ++g) {
                if (proof.bindings.bindings[k].bindings.rows[g].terms.count != 0) nonempty = true;
                bytes32 binding = proof.bindings.generations[k][g].bindingHash;
                uint256 count;
                for (uint256 i; i < proof.archive.accepted.length; ++i) {
                    if (proof.archive.accepted[i].acceptance.bindingHash == binding) ++count;
                }
                if (
                    Collaborator(
                                proof.provenance
                                .origins[proof.provenance.origins.length - 1].owners[1]
                            ).acceptedCount(binding) != count
                ) _invalid();
            }
        }
        if (!nonempty) _invalid();
        result = Clocks.validate(scope, proof.provenance, proof.bindings, proof.archive);
        BindingProof.validate(
            scope, RH.ownerProvenance(proof.provenance, 0), proof.bindings, proof.archive, result
        );
        for (uint256 i; i < proof.archive.proposals.length; ++i) {
            bytes32 id = proof.archive.proposals[i].state.acceptedArtistId;
            if (id != 0) Scope.artist(scope, id);
        }
        for (uint256 i; i < proof.archive.accepted.length; ++i) {
            Scope.artist(scope, proof.archive.accepted[i].join.artistId);
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
