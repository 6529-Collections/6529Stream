// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationRevocations as Revocations
} from "./StreamArtistRecoveredMultipleGenerationRevocations.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationValidation as Validation
} from "./StreamArtistRecoveredMultipleGenerationAttestationValidation.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";
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
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";

import {
    StreamArtistPrimaryCollaboratorAttributionRows as Rows
} from "./StreamArtistPrimaryCollaboratorAttributionRows.sol";
import {
    StreamArtistPrimaryCollaboratorCurrentClocks as CurrentClocks
} from "./StreamArtistPrimaryCollaboratorCurrentClocks.sol";

import {
    StreamArtistPrimaryCollaboratorAttributionSemantics as Semantics
} from "./StreamArtistPrimaryCollaboratorAttributionSemantics.sol";

import {
    StreamArtistPrimaryCollaboratorProofFrame as Frame
} from "./StreamArtistPrimaryCollaboratorProofFrame.sol";
import {
    StreamArtistPrimaryCollaboratorCallFrames as FrameArgs
} from "./StreamArtistPrimaryCollaboratorCallFrames.sol";
import {
    StreamArtistPrimaryCollaboratorAttributionPrelude as Prelude
} from "./StreamArtistPrimaryCollaboratorAttributionPrelude.sol";
import {
    StreamArtistPrimaryCollaboratorAttributionProof as Proof
} from "./StreamArtistPrimaryCollaboratorAttributionProof.sol";

/// @notice Original revocation then attestation validation using authenticated full source clocks.
library StreamArtistPrimaryCollaboratorAttributionFinish {
    function finish(bytes calldata raw, bytes calldata prepared)
        public
        pure
        returns (bytes memory)
    {
        (
            M.State calldata scope,
            RH.OwnerProvenance calldata provenance,
            PC.Proof calldata inventory
        ) = FrameArgs.attribution(raw);
        if (prepared.length < 96 || prepared.length % 32 != 0) {
            assembly ("memory-safe") {
                revert(0, 0)
            }
        }
        uint256 at;
        assembly ("memory-safe") { at := calldataload(prepared.offset) }
        if (at != 32) assembly ("memory-safe") { revert(0, 0) }
        Prelude.Result calldata r;
        assembly ("memory-safe") { r := add(prepared.offset, 32) }
        G.Inventory memory generations;
        generations.catalogues = inventory.archive.catalogues;
        generations.operations = inventory.archive.operations;
        generations.bindings = inventory.bindings.bindings;
        generations.generations = inventory.bindings.generations;
        Proof.Result memory result;
        result.histories = r.rows.histories;
        result.all = Semantics.validate(
            Semantics.Context(
                r.scope,
                provenance,
                generations,
                r.source.clocks.clocks,
                result.histories,
                r.rows.rows,
                r.sanctions
            )
        );
        return abi.encode(result);
    }
}
