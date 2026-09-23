// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportDocuments {
    function collect(uint256[17] memory r, bytes calldata canonical)
        public
        view
        returns (bytes memory)
    {
        IH.Bundle calldata b = Frame.bundle(canonical);
        bytes32[] memory keys = new bytes32[](1 + b.revisions.length * 2);
        uint256 n = _key(keys, 0, b.identity.identityRecordHash);
        for (uint256 i; i < b.revisions.length; ++i) {
            n = _key(keys, n, b.revisions[i].record.previousRecordHash);
            n = _key(keys, n, b.revisions[i].record.revisedRecordHash);
        }
        IH.DocumentRow[] memory rows = new IH.DocumentRow[](n);
        for (uint256 i; i < n; ++i) {
            rows[i] = IH.DocumentRow(keys[i], X.identity(r).documents[keys[i]]);
        }
        return abi.encode(rows);
    }

    function _key(bytes32[] memory keys, uint256 n, bytes32 value) private pure returns (uint256) {
        if (value == 0) revert IH.InvalidRecoveredIdentity(value);
        uint256 at;
        while (at < n && keys[at] < value) ++at;
        if (at < n && keys[at] == value) return n;
        for (uint256 j = n; j > at; --j) {
            keys[j] = keys[j - 1];
        }
        keys[at] = value;
        return n + 1;
    }
}
