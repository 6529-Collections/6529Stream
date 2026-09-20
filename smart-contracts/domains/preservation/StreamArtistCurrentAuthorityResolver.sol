// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistCurrentAuthorityResolver
} from "../../interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";
import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamArtistCurrentAuthorityReads as Reads
} from "./StreamArtistCurrentAuthorityReads.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";

/// @notice Immutable original anchors; no successor allowlist and no mutable route binding.
/// @dev Deploy after the original provider and before the predicted original Finality.
contract StreamArtistCurrentAuthorityResolver is IStreamArtistCurrentAuthorityResolver {
    C.Anchors private _anchors;

    constructor(C.Anchors memory a) {
        if (
            a.chainId != block.chainid || a.finalityRegistry == address(0) || a.readGas < 50000
                || a.readGas > type(uint64).max
        ) revert C.InvalidCurrentAuthority();
        for (uint256 i; i < 5; ++i) {
            IO.pin(a.targets[i], a.codeHashes[i]);
        }
        _anchors = a;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamArtistCurrentAuthorityResolver).interfaceId;
    }

    function currentAuthorityProfile() external pure override returns (bytes32) {
        return C.PROFILE;
    }

    function anchors() external view override returns (C.Anchors memory) {
        return _anchors;
    }

    function currentSelection() external view override returns (C.Selection memory) {
        return Reads.selection(_anchors);
    }

    function currentFinalityRoute(uint256 collectionId)
        external
        view
        override
        returns (C.Route memory)
    {
        return Reads.route(_anchors, collectionId);
    }
}
