// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

import {
    StreamArtistRecoveredIdentityExportCollect as Collect
} from "./StreamArtistRecoveredIdentityExportCollect.sol";
import {
    StreamArtistRecoveredIdentityExportReads as Reads
} from "./StreamArtistRecoveredIdentityExportReads.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityHydrationExportRows {
    error InvalidRecoveredIdentity(bytes32 key);

    function exportEncoded(
        uint256[17] memory roots,
        AH.Query memory query,
        RH.OwnerProvenance memory local
    ) public view returns (bytes memory) {
        return Collect.collect(roots, query, local);
    }

    function exportBundle(
        uint256[17] memory roots,
        AH.Query memory query,
        RH.OwnerProvenance memory local
    ) public view returns (IH.Bundle memory b) {
        bytes memory encoded = Collect.collect(roots, query, local);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function actionArtist(uint256[17] memory roots, bytes32 action) public view returns (bytes32) {
        return Reads.actionArtist(roots, action);
    }

    function auxiliaryPoint(
        uint256[17] memory roots,
        bytes32 kind,
        bytes32 key,
        bytes32 currentOriginHash
    ) public view returns (RH.Point memory) {
        return Reads.auxiliaryPoint(roots, kind, key, currentOriginHash);
    }

    function timingCheckpoint(uint256[17] memory roots) public view returns (TM.Checkpoint memory) {
        return Reads.timingCheckpoint(roots);
    }

    function configuration(uint256[17] memory roots)
        public
        view
        returns (TM.Configuration memory c)
    {
        return Reads.configuration(roots);
    }
}
