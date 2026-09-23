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
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Strict chronology precondition inside the original fixed Identity writers.
/// @dev The next mutation is not a retained fact or a synthetic checkpoint. Its revision must
/// be exactly actual current+1; every predecessor is separately proved at or before current.
library StreamArtistRecoveredIdentityWriteChronology {
    function guardian(Hashes.Environment memory e, GH.Entry memory prior, uint64 nextRevision)
        public
        view
    {
        Runtime.Context memory c = _current(e, nextRevision);
        Identity.guardianEntry(c, prior);
    }

    function vesting(Hashes.Environment memory e, V.Snapshot memory prior, uint64 nextRevision)
        public
        view
    {
        Runtime.Context memory c = _current(e, nextRevision);
        Identity.vesting(c, prior);
    }

    function next(Hashes.Environment memory e, uint64 nextRevision) public view {
        _current(e, nextRevision);
    }

    function _current(Hashes.Environment memory e, uint64 nextRevision)
        private
        view
        returns (Runtime.Context memory c)
    {
        c = Identity.load(address(this), e.registry, e.chainId);
        if (
            c.importCommitment == 0 || c.current.core != e.core || c.current.manager != e.manager
                || c.checkpoint.ownerState.revision == type(uint64).max
                || nextRevision != c.checkpoint.ownerState.revision + 1
        ) revert RH.InvalidRecoveredHydrationProvenance();
    }
}
