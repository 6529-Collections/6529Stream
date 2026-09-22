// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyComposition as Family
} from "./StreamArtistPrimaryCollaboratorFamilyComposition.sol";
import {
    StreamArtistPrimaryCollaboratorComposition as Composition
} from "./StreamArtistPrimaryCollaboratorComposition.sol";

import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Views of complete fixed-worker ABI arguments, never an authority or canonicality proof.
/// @dev Public typed entry arguments or complete encodings made by fixed workers only.
library StreamArtistPrimaryCollaboratorCallFrames {
    function _tuple(bytes calldata raw, uint256 minimum) private pure returns (uint256 at) {
        if (raw.length < minimum + 32 || raw.length % 32 != 0) {
            assembly ("memory-safe") {
                revert(0, 0)
            }
        }
        assembly ("memory-safe") { at := calldataload(raw.offset) }
        if (at != 32) assembly ("memory-safe") { revert(0, 0) }
    }

    function family(bytes calldata raw) internal pure returns (Family.Context calldata c) {
        uint256 at = _tuple(raw, 128);
        assembly ("memory-safe") { c := add(raw.offset, at) }
    }

    function composition(bytes calldata raw)
        internal
        pure
        returns (Composition.Context calldata c)
    {
        uint256 at = _tuple(raw, 256);
        assembly ("memory-safe") { c := add(raw.offset, at) }
    }

    function attribution(bytes calldata raw)
        internal
        pure
        returns (M.State calldata s, RH.OwnerProvenance calldata p, PC.Proof calldata proof)
    {
        if (raw.length < 96 || raw.length % 32 != 0) assembly ("memory-safe") { revert(0, 0) }
        uint256 a;
        uint256 b;
        uint256 c;
        assembly ("memory-safe") {
            a := calldataload(raw.offset)
            b := calldataload(add(raw.offset, 32))
            c := calldataload(add(raw.offset, 64))
        }
        if (
            a < 96 || b < 96 || c < 96 || a % 32 != 0 || b % 32 != 0 || c % 32 != 0
                || a > raw.length || b > raw.length || c > raw.length || raw.length - a < 96
                || raw.length - b < 160 || raw.length - c < 160
        ) assembly ("memory-safe") { revert(0, 0) }
        assembly ("memory-safe") {
            s := add(raw.offset, a)
            p := add(raw.offset, b)
            proof := add(raw.offset, c)
        }
    }

    /// @dev All fields are complete abi.encode(dynamic tuple) outputs from fixed typed workers.
    function join(bytes[] memory fields, bool wrapped) internal pure returns (bytes memory out) {
        uint256 head = 32 * fields.length;
        uint256 prefixBytes = wrapped ? 32 : 0;
        uint256 length = head + prefixBytes;
        for (uint256 i; i < fields.length; ++i) {
            length += fields[i].length - 32;
        }
        out = new bytes(length);
        if (wrapped) assembly ("memory-safe") { mstore(add(out, 32), 32) }
        uint256 tail = head;
        for (uint256 i; i < fields.length; ++i) {
            bytes memory field = fields[i];
            assembly ("memory-safe") {
                mstore(add(add(add(out, 32), prefixBytes), mul(i, 32)), tail)
            }
            for (uint256 at = 32; at < field.length; at += 32) {
                assembly ("memory-safe") {
                    mstore(
                        add(add(add(out, 32), prefixBytes), tail),
                        mload(add(add(field, 32), at))
                    )
                }
                tail += 32;
            }
        }
    }
}
