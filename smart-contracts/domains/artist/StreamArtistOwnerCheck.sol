// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOwnerCommit } from "./StreamArtistOwnerCommit.sol";
import { StreamArtistOnboardingTypes as T } from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Original owner admission over the unchanged declared accumulator prefix.
library StreamArtistOwnerCheck {
    function check(
        StreamArtistOwnerCommit.Prefix storage s,
        address coordinator,
        bytes32 domain,
        T.ActionContext calldata context,
        uint16 operation
    ) public view {
        if (msg.sender != coordinator) revert T.Unauthorized(msg.sender);
        if (context.actor == address(0)) revert T.Unauthorized(context.actor);
        if (context.operationId != operation) revert T.InvalidOperation(context.operationId);
        T.Snapshot calldata prior = context.expected;
        if (
            prior.domainId != domain || prior.revision != s.revision
                || prior.stateRoot != s.stateRoot || prior.recordChainTip != s.recordChainTip
        ) revert T.StaleOwnerSnapshot(domain);
    }
}
