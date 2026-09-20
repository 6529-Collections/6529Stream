// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistRecoveredHydrationOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistNativeReceipts
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";

/// @notice Logical original occurrences for new V3 source manifests; snapshots stay local.
library StreamArtistRecoveredReceiptCount {
    function count(W.EnvironmentV3 memory e, uint8 ownerIndex) public view returns (uint256) {
        if (ownerIndex != 2 && ownerIndex != 5) revert W.InvalidRecoveryRewindManifest(bytes32(0));
        address owner = ownerIndex == 2 ? e.identityOwner : e.payoutOwner;
        (, bytes32 imported,) =
            IStreamArtistRecoveredHydrationOwner(owner).recoveredHydrationImportedPrefix();
        if (imported == 0) return IStreamArtistNativeReceipts(owner).artistNativeReceiptCount();
        return Runtime.logicalCount(Runtime.load(e, ownerIndex));
    }
}
