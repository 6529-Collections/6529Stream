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

/// @notice Full source proof shared by the fixed preparation and per-owner import paths.
/// @dev No caller supplies a reduced global journal, historical timestamp or current authority.
library StreamArtistPrimaryCollaboratorSourceProof {
    struct Result {
        Clocks.Result clocks;
        G.Inventory generations;
    }

    function collect(M.State memory scope, RH.Provenance memory p)
        public
        view
        returns (PC.Proof memory proof, Result memory result)
    {
        if (p.origins.length == 0) _invalid();
        RH.OriginEnvironment memory source = p.origins[p.origins.length - 1];
        proof.provenance = p;
        proof.bindings = Bindings.collect(source.owners[0], scope, RH.ownerProvenance(p, 0));
        (proof.archive.catalogues, proof.archive.operations) = Catalogue.collect(p);
        proof.archive = Records.collect(p, proof.archive.catalogues, proof.archive.operations);
        result = _clocks(scope, proof);
        proof.accepted = Acceptance.collect(
            source.owners[3], scope, p, proof.bindings, proof.archive, result.clocks
        );
        proof.accounts = Accounts.collect(p, proof.archive);
    }

    function requireCurrent(M.State memory scope, PC.Proof memory proof)
        public
        view
        returns (Result memory result)
    {
        (PC.Proof memory actual, Result memory observed) = collect(scope, proof.provenance);
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(proof))) _invalid();
        return observed;
    }

    function _clocks(M.State memory scope, PC.Proof memory proof)
        private
        view
        returns (Result memory result)
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
        result.clocks = Clocks.validate(scope, proof.provenance, proof.bindings, proof.archive);
        BindingProof.validate(
            scope,
            RH.ownerProvenance(proof.provenance, 0),
            proof.bindings,
            proof.archive,
            result.clocks
        );
        for (uint256 i; i < proof.archive.proposals.length; ++i) {
            bytes32 id = proof.archive.proposals[i].state.acceptedArtistId;
            if (id != 0) Scope.artist(scope, id);
        }
        for (uint256 i; i < proof.archive.accepted.length; ++i) {
            Scope.artist(scope, proof.archive.accepted[i].join.artistId);
        }
        result.generations.catalogues = proof.archive.catalogues;
        result.generations.operations = proof.archive.operations;
        result.generations.bindings = proof.bindings.bindings;
        result.generations.generations = proof.bindings.generations;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
