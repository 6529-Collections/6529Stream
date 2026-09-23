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
    StreamArtistPrimaryCollaboratorAttributionFinish as Finish
} from "./StreamArtistPrimaryCollaboratorAttributionFinish.sol";

import {
    StreamArtistPrimaryCollaboratorPipelineCanonical as Canonical
} from "./StreamArtistPrimaryCollaboratorPipelineCanonical.sol";

/// @notice Complete canonical owner4 rows, original clocks, revocations and attestations.
/// @dev Keeps the original semantic rows for clock/revocation validation and a fresh
/// attestation row view. Neither validation consumes or alters the original row bytes.
library StreamArtistPrimaryCollaboratorAttributionProof {
    error InvalidRecoveredHydrationProfile();

    struct Result {
        A.AttributionBundle[] histories;
        Original.Bundle[] all;
    }

    /// @dev External library entry only: preserve the complete original return tuple.
    function validate(
        M.State calldata scope,
        RH.OwnerProvenance calldata provenance,
        PC.Proof calldata inventory
    ) public view returns (Result memory result) {
        bytes memory output = _run(msg.data[4:]);
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }

    function requireValid(
        M.State calldata scope,
        RH.OwnerProvenance calldata provenance,
        PC.Proof calldata inventory
    ) public view {
        _run(msg.data[4:]);
    }

    /// @dev The fixed caller has completed the original full canonical/local proof checks.
    function validateEncoded(
        M.State calldata scope,
        RH.OwnerProvenance calldata provenance,
        bytes calldata raw
    ) public view returns (Result memory) {
        bytes[] memory fields = new bytes[](3);
        fields[0] = abi.encode(scope);
        fields[1] = abi.encode(provenance);
        fields[2] = raw;
        bytes memory output = _run(FrameArgs.join(fields, false));
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }

    function encoded(
        M.State calldata scope,
        RH.OwnerProvenance calldata provenance,
        bytes calldata raw
    ) public view returns (bytes memory) {
        bytes[] memory fields = new bytes[](3);
        fields[0] = abi.encode(scope);
        fields[1] = abi.encode(provenance);
        fields[2] = raw;
        return _run(FrameArgs.join(fields, false));
    }

    function _run(bytes memory arguments) private view returns (bytes memory) {
        arguments = Canonical.attribution(arguments);
        bytes memory prepared = Prelude.prepare(arguments);
        return Finish.finish(arguments, prepared);
    }
}
