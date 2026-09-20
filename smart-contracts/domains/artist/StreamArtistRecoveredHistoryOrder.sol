// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityRuntime as Identity
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Original Identity producer coordinates for retained Estate history comparisons.
/// @dev Call only from the recovered branch of a fixed owner. These helpers do not authorize writes.
library StreamArtistRecoveredHistoryOrder {
    function nativeEnvironment(
        Hashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 key
    ) public view returns (Hashes.Environment memory) {
        Runtime.ReceiptFact memory row = Identity.nativeFact(_load(e), operation, artistId, key);
        return Identity.hashes(row.environment);
    }

    function vesting(Hashes.Environment memory e, V.Snapshot memory item)
        public
        view
        returns (bytes32)
    {
        Identity.vesting(_load(e), item);
        return item.commitment;
    }

    function before(Hashes.Environment memory e, V.Snapshot memory a, V.Snapshot memory b)
        public
        view
        returns (bool)
    {
        Runtime.Context memory c = _load(e);
        return Runtime.before(c, Identity.vesting(c, a).point, Identity.vesting(c, b).point);
    }

    function guardianBefore(Hashes.Environment memory e, GH.Entry memory a, V.Snapshot memory b)
        public
        view
        returns (bool)
    {
        Runtime.Context memory c = _load(e);
        return Runtime.before(c, Identity.guardianEntry(c, a).point, Identity.vesting(c, b).point);
    }

    function vestingBefore(Hashes.Environment memory e, V.Snapshot memory a, GH.Entry memory b)
        public
        view
        returns (bool)
    {
        Runtime.Context memory c = _load(e);
        return Runtime.before(c, Identity.vesting(c, a).point, Identity.guardianEntry(c, b).point);
    }

    function _load(Hashes.Environment memory e) private view returns (Runtime.Context memory c) {
        c = Identity.load(address(this), e.registry, e.chainId);
        if (c.importCommitment == 0 || c.current.core != e.core || c.current.manager != e.manager) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
    }
}
