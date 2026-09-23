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
    StreamArtistPrimaryCollaboratorSourceClocks as ClockValidation
} from "./StreamArtistPrimaryCollaboratorSourceClocks.sol";
import {
    StreamArtistPrimaryCollaboratorProofPart0 as ProvenanceField
} from "./StreamArtistPrimaryCollaboratorProofPart0.sol";

import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";

/// @notice Exact full original source collection, returning both complete typed encodings.
library StreamArtistPrimaryCollaboratorSourceCollection {
    struct Context {
        PC.Proof proof;
        Source.Result result;
        RH.OriginEnvironment source;
    }

    function encoded(M.State memory scope, RH.Provenance memory p)
        public
        view
        returns (bytes memory proofBytes, bytes memory resultBytes)
    {
        Context memory c;
        if (p.origins.length == 0) _invalid();
        c.source = p.origins[p.origins.length - 1];
        c.proof.provenance = p;
        c.proof.bindings = Bindings.collect(c.source.owners[0], scope, RH.ownerProvenance(p, 0));
        (c.proof.archive.catalogues, c.proof.archive.operations) = Catalogue.collect(p);
        c.proof.archive = Records.collect(p, c.proof.archive.catalogues, c.proof.archive.operations);
        c.result.clocks = ClockValidation.validate(scope, c.proof);
        c.result.generations.catalogues = c.proof.archive.catalogues;
        c.result.generations.operations = c.proof.archive.operations;
        c.result.generations.bindings = c.proof.bindings.bindings;
        c.result.generations.generations = c.proof.bindings.generations;
        c.proof.accepted = Acceptance.collect(
            c.source.owners[3], scope, p, c.proof.bindings, c.proof.archive, c.result.clocks
        );
        c.proof.accounts = Accounts.collect(p, c.proof.archive);
        proofBytes = abi.encode(c.proof);
        resultBytes = abi.encode(c.result);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
