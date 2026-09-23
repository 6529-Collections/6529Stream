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
    StreamArtistPrimaryCollaboratorSourceCollection as Collection
} from "./StreamArtistPrimaryCollaboratorSourceCollection.sol";

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
        (bytes memory proofBytes, bytes memory resultBytes) = Collection.encoded(scope, p);
        bytes memory output = _pair(proofBytes, resultBytes);
        // External library entry only; original two complete dynamic tuple outputs.
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }

    function requireCurrent(M.State memory scope, PC.Proof memory proof)
        public
        view
        returns (Result memory result)
    {
        (bytes memory actual, bytes memory observed) = Collection.encoded(scope, proof.provenance);
        if (keccak256(actual) != keccak256(abi.encode(proof))) _invalid();
        // Exact original Result bytes, already generated from the complete original source.
        assembly ("memory-safe") { return(add(observed, 32), mload(observed)) }
    }

    function requireEncoded(M.State memory scope, bytes memory raw) public view {
        RH.Provenance memory p = abi.decode(ProvenanceField.decode(raw), (RH.Provenance));
        (bytes memory actual,) = Collection.encoded(scope, p);
        if (keccak256(actual) != keccak256(raw)) _invalid();
    }

    function _pair(bytes memory first, bytes memory second)
        private
        pure
        returns (bytes memory out)
    {
        out = new bytes(first.length + second.length);
        uint256 firstTail = first.length - 32;
        assembly ("memory-safe") {
            mstore(add(out, 32), 64)
            mstore(add(out, 64), add(64, firstTail))
        }
        uint256 at = 64;
        for (uint256 i = 32; i < first.length; i += 32) {
            assembly ("memory-safe") {
                mstore(add(add(out, 32), at), mload(add(add(first, 32), i)))
            }
            at += 32;
        }
        for (uint256 i = 32; i < second.length; i += 32) {
            assembly ("memory-safe") {
                mstore(add(add(out, 32), at), mload(add(add(second, 32), i)))
            }
            at += 32;
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
