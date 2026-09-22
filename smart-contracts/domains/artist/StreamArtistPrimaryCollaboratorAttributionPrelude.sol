// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAggregateSanctionLocalProof as SanctionLocal
} from "./StreamArtistRecoveredAggregateSanctionLocalProof.sol";
import {
    StreamArtistRecoveredAggregateSanctionAttributionTransport as SanctionTransport
} from "./StreamArtistRecoveredAggregateSanctionAttributionTransport.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
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

/// @notice Original row and owner checks followed by complete fresh source re-observation.
library StreamArtistPrimaryCollaboratorAttributionPrelude {
    struct Result {
        Rows.Result rows;
        Source.Result source;
        M.State scope;
        H.Inventory sanctions;
    }

    function prepare(bytes calldata raw) public view returns (bytes memory) {
        (
            M.State calldata scope,
            RH.OwnerProvenance calldata provenance,
            PC.Proof calldata inventory
        ) = FrameArgs.attribution(raw);
        Result memory r;
        (r.scope, r.sanctions) = SanctionTransport.decode(scope);
        if (r.sanctions.sanctions.length != 0) {
            SanctionLocal.validate(provenance, 4, r.scope.collections, r.sanctions);
        }
        r.rows = Rows.project(r.scope);
        if (
            keccak256(abi.encode(provenance))
                != keccak256(abi.encode(RH.ownerProvenance(inventory.provenance, 4)))
        ) revert RH.InvalidRecoveredHydrationProfile();
        r.source.clocks = CurrentClocks.requireEncoded(r.scope, abi.encode(inventory));
        return abi.encode(r);
    }
}
