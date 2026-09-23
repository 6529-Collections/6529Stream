// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCodec as Codec
} from "./StreamArtistPrimaryCollaboratorCodec.sol";
import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

import {
    StreamArtistPrimaryCollaboratorProofDecode as ProofValidation
} from "./StreamArtistPrimaryCollaboratorProofDecode.sol";

/// @notice Canonical owner envelope and exact local/full provenance relation before source re-observation.
library StreamArtistPrimaryCollaboratorDecode {
    function collect(uint8 owner, AH.Query memory anchor, bytes memory outer)
        public
        view
        returns (M.State memory scope, Payload.Payload memory payload, PC.Proof memory proof)
    {
        bytes[3] memory parts;
        (parts[0], parts[1], parts[2]) = Codec.prepareSource(owner, anchor, outer);
        Source.requireEncoded(abi.decode(parts[0], (M.State)), parts[2]);
        bytes memory output = _returns(parts);
        // Public external library entry only: original three-result ABI, no cross-selector
        // internal callers. All complete proof/source checks ran before this terminal return.
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }

    function _returns(bytes[3] memory parts) private pure returns (bytes memory output) {
        uint256 length = 96;
        for (uint256 i; i < 3; ++i) {
            length += parts[i].length - 32;
        }
        output = new bytes(length);
        uint256 tail = 96;
        for (uint256 i; i < 3; ++i) {
            bytes memory part = parts[i];
            assembly ("memory-safe") { mstore(add(add(output, 32), mul(i, 32)), tail) }
            for (uint256 at = 32; at < part.length; at += 32) {
                assembly ("memory-safe") {
                    mstore(add(add(output, 32), tail), mload(add(add(part, 32), at)))
                }
                tail += 32;
            }
        }
    }
}
