// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Strings } from "../../vendor/openzeppelin/Strings.sol";

/// @notice Canonical work identity only; no record-state or authority claim is inferred.
library StreamMetadataCitation {
    function work(uint256 originalChainId, address originalCore, uint256 globalTokenId)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            "eip155:",
            Strings.toString(originalChainId),
            "/erc721:",
            Strings.toHexString(uint256(uint160(originalCore)), 20),
            "/",
            Strings.toString(globalTokenId)
        );
    }

    /// @dev Input is the fixed encoder's own complete object, never caller JSON.
    function inObject(string memory object, string memory citation)
        internal
        pure
        returns (string memory)
    {
        bytes memory encoded = bytes(object);
        assert(encoded.length >= 2 && encoded[encoded.length - 1] == 0x7d);
        assembly ("memory-safe") { mstore(encoded, sub(mload(encoded), 1)) }
        return string(bytes.concat(encoded, bytes(',"citation":"'), bytes(citation), bytes('"}')));
    }
}
