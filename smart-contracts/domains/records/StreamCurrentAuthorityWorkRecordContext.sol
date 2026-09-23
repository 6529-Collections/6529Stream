// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamWorkRecordContext as Original } from "./StreamWorkRecordContext.sol";

/// @notice Fixed original non-Artist graph plus the authenticated currently selected Artist.
/// @dev Empty Artist slots enter only the original base-graph validator; pinArtists then
/// resolves Metadata's immutable original ancestry and all required completion markers.
/// The returned tuple is fresh on every use and never a caller-provided replacement graph.
library StreamCurrentAuthorityWorkRecordContext {
    function currentContext(
        address[4] memory targets,
        bytes32[4] memory codeHashes,
        uint256 chainId
    ) public view returns (Original.Dependencies memory d) {
        d.targets = targets;
        d.codeHashes = codeHashes;
        d.chainId = chainId;
        d = Original.currentContext(d);
        return Original.pinArtists(d);
    }
}
