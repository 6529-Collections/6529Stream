// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistGovernanceWitness } from "./StreamArtistGovernanceWitness.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    IStreamGovernanceReads
} from "../../interfaces/stream/governance/IStreamGovernanceReads.sol";

/// @notice Operation35 requires the real arbiter witness after the atomic genesis exception ends.
/// @dev Caller supplies the constructor-pinned Identity authority and Coordinator suite context.
library StreamArtistIdentityRecoveryGovernance {
    function read(
        D.CoordinatorContext memory x,
        address authority,
        address actor,
        bytes32 reasonHash,
        Recovery.Context memory c
    ) public view returns (Contest.GovernanceWitness memory g) {
        if (actor != authority || authority == address(0) || reasonHash == bytes32(0)) {
            revert Recovery.InvalidIdentityRecoveryGovernance();
        }
        _requireSealed(authority);
        g = StreamArtistGovernanceWitness.read(
            x, authority, reasonHash, c.scopeHash, c.oldValueHash, c.newValueHash
        );
        if (g.actionClass != 2) revert Recovery.InvalidIdentityRecoveryGovernance();
    }

    /// @dev Only the first two canonical bool words are consumed. The complete current fixed
    ///      29-word return size is required; the pinned Executor authenticates the other facts.
    function _requireSealed(address authority) private view {
        bytes memory data = abi.encodeCall(IStreamGovernanceReads.systemManifestBootstrapState, ());
        bytes memory result = new bytes(928);
        if (gasleft() < 20_000) revert Recovery.InvalidIdentityRecoveryGovernance();
        bool ok;
        uint256 size;
        uint256 bound;
        uint256 sealedWord;
        assembly ("memory-safe") {
            ok := staticcall(
                sub(gas(), 10000),
                authority,
                add(data, 32),
                mload(data),
                add(result, 32),
                928
            )
            size := returndatasize()
            bound := mload(add(result, 32))
            sealedWord := mload(add(result, 64))
        }
        if (!ok || size != 928 || bound != 1 || sealedWord != 1) {
            revert Recovery.InvalidIdentityRecoveryGovernance();
        }
    }
}
