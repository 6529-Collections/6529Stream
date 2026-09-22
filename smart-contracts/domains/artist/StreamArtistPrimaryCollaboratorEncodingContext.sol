// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorProofCanonical as Proof
} from "./StreamArtistPrimaryCollaboratorProofCanonical.sol";
import {
    StreamArtistPrimaryCollaboratorAcceptanceContext as Acceptance
} from "./StreamArtistPrimaryCollaboratorAcceptanceContext.sol";
import {
    StreamArtistPrimaryCollaboratorConsentRowsContext as Consents
} from "./StreamArtistPrimaryCollaboratorConsentRowsContext.sol";
import {
    StreamArtistPrimaryCollaboratorHistoryContext as History
} from "./StreamArtistPrimaryCollaboratorHistoryContext.sol";

/// @notice Full eager domain of the original seven-field Encoding.Context.
/// @dev The same first nominal argument occurs in both original public encoders.
library StreamArtistPrimaryCollaboratorEncodingContext {
    function requireValid(bytes calldata arguments) public pure returns (bytes32) {
        if (arguments.length < 32) assembly ("memory-safe") { revert(0, 0) }
        uint256 at;
        assembly ("memory-safe") { at := calldataload(arguments.offset) }
        if (at > arguments.length) assembly ("memory-safe") { revert(0, 0) }
        bytes calldata body = arguments[at:];
        if (body.length < 224) assembly ("memory-safe") { revert(0, 0) }
        // count/features are full uint256. Every remaining declaration-order
        // field is decoded completely, even rows beyond collectionCount.
        bytes32[5] memory fields;
        fields[0] = keccak256(Proof.canonical(_part(body, 2)));
        fields[1] = keccak256(Acceptance.canonical(_part(body, 3)));
        fields[2] = keccak256(Consents.canonical(_part(body, 4)));
        fields[3] = keccak256(abi.encode(abi.decode(_part(body, 5), (bytes[]))));
        fields[4] = keccak256(History.canonical(_part(body, 6)));
        return keccak256(abi.encode(fields));
    }

    function _part(bytes calldata body, uint256 index) private pure returns (bytes memory) {
        uint256 at;
        assembly ("memory-safe") { at := calldataload(add(body.offset, mul(index, 32))) }
        if (at > body.length) assembly ("memory-safe") { revert(0, 0) }
        return bytes.concat(bytes32(uint256(32)), body[at:]);
    }
}
