// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentitySourceValidation as Validation
} from "./StreamArtistRecoveredIdentitySourceValidation.sol";
import {
    StreamArtistRecoveredIdentitySourceCanonical as Canonical
} from "./StreamArtistRecoveredIdentitySourceCanonical.sol";
import {
    StreamArtistRecoveredIdentitySourceTuple as Tuple
} from "./StreamArtistRecoveredIdentitySourceTuple.sol";

/// @notice Original canonical envelope and fixed source return normalization.
library StreamArtistRecoveredIdentitySourceCodec {
    function encode(IH.Bundle calldata b) public pure returns (bytes memory) {
        return abi.encode(IH.SCHEMA, b);
    }

    /// @dev Exactly the original typed return decoder followed by its typed encoder:
    /// complete values survive, harmless trailing bytes and noncanonical offsets normalize.
    function transport(bytes calldata raw) public pure returns (bytes memory) {
        return Canonical.canonical(raw, false);
    }

    function decode(bytes calldata raw, RH.OwnerProvenance calldata p)
        public
        pure
        returns (bytes memory)
    {
        // Decode the complete Bundle before schema/canonicality checks, like the original.
        bytes32 schema = abi.decode(raw, (bytes32));
        bytes memory single = Canonical.canonical(raw, true);
        bytes memory envelope = bytes.concat(abi.encode(schema, uint256(64)), Tuple.body(single));
        if (schema != IH.SCHEMA || keccak256(raw) != keccak256(envelope)) {
            revert IH.InvalidRecoveredIdentity(bytes32(0));
        }
        Validation.validateEncoded(single, p);
        return single;
    }
}
