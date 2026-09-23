// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorSanctionContext as Sanction
} from "./StreamArtistPrimaryCollaboratorSanctionContext.sol";
import {
    StreamArtistPrimaryCollaboratorCompositionContext as Composition
} from "./StreamArtistPrimaryCollaboratorCompositionContext.sol";
import {
    StreamArtistPrimaryCollaboratorSourceContext as Source
} from "./StreamArtistPrimaryCollaboratorSourceContext.sol";
import {
    StreamArtistPrimaryCollaboratorHistoryContext as History
} from "./StreamArtistPrimaryCollaboratorHistoryContext.sol";
import {
    StreamArtistPrimaryCollaboratorArgumentContext as Arguments
} from "./StreamArtistPrimaryCollaboratorArgumentContext.sol";
import {
    StreamArtistPrimaryCollaboratorProofCanonical as Proof
} from "./StreamArtistPrimaryCollaboratorProofCanonical.sol";
import {
    StreamArtistPrimaryCollaboratorCallFrames as Frames
} from "./StreamArtistPrimaryCollaboratorCallFrames.sol";

/// @notice Full original eager ABI domain before any source/semantic phase reads.
/// @dev Padding accepted by the original typed decoder is normalized, not rejected.
library StreamArtistPrimaryCollaboratorPipelineCanonical {
    function family(bytes calldata raw) public pure returns (bytes memory) {
        if (raw.length < 32) assembly ("memory-safe") { revert(0, 0) }
        uint256 at;
        assembly ("memory-safe") { at := calldataload(raw.offset) }
        if (at > raw.length) assembly ("memory-safe") { revert(0, 0) }
        return _familyBody(raw[at:]);
    }

    function supplemented(bytes calldata raw)
        public
        pure
        returns (bytes memory context, bytes memory sanctions)
    {
        if (raw.length < 64) assembly ("memory-safe") { revert(0, 0) }
        uint256 at;
        assembly ("memory-safe") { at := calldataload(raw.offset) }
        if (at > raw.length) assembly ("memory-safe") { revert(0, 0) }
        context = _familyBody(raw[at:]);
        sanctions = Sanction.canonical(_part(raw, 1, 2));
    }

    function _familyBody(bytes calldata body) private pure returns (bytes memory) {
        if (body.length < 128) assembly ("memory-safe") { revert(0, 0) }
        bytes[] memory fields = new bytes[](4);
        fields[0] = Composition.canonical(_part(body, 0, 4));
        fields[1] = Proof.canonical(_part(body, 1, 4));
        fields[2] = Source.canonical(_part(body, 2, 4));
        fields[3] = History.canonical(_part(body, 3, 4));
        return Frames.join(fields, true);
    }

    function attribution(bytes calldata raw) public pure returns (bytes memory) {
        bytes[] memory fields = new bytes[](3);
        fields[0] = Arguments.scope(_part(raw, 0, 3));
        fields[1] = Arguments.owner(_part(raw, 1, 3));
        fields[2] = Proof.canonical(_part(raw, 2, 3));
        return Frames.join(fields, false);
    }

    function _part(bytes calldata body, uint256 index, uint256 count)
        private
        pure
        returns (bytes memory)
    {
        if (body.length < count * 32) assembly ("memory-safe") { revert(0, 0) }
        uint256 at;
        assembly ("memory-safe") { at := calldataload(add(body.offset, mul(index, 32))) }
        if (at > body.length) assembly ("memory-safe") { revert(0, 0) }
        return bytes.concat(bytes32(uint256(32)), body[at:]);
    }
}
