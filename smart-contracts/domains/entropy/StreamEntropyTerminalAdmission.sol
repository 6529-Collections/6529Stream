// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamEntropyCoordinator } from "./StreamEntropyCoordinator.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
import { StreamEntropyStatus } from "../../interfaces/stream/entropy/IStreamEntropyView.sol";

/// @notice Original stale/failed request admission only. The host keeps authority, guard,
/// terminal state/counters/events and notification in their original order.
library StreamEntropyTerminalAdmission {
    function stale(
        StreamEntropyCoordinator.Request storage request,
        StreamEntropyCoordinator.Subject storage subject,
        bytes32 requestKey
    ) public view {
        if (subject.requestKey != requestKey) {
            revert StreamEntropyCoordinator.InvalidSubject(request.subjectKey);
        }
        if (subject.status != StreamEntropyStatus.REQUESTED) {
            revert StreamEntropyCoordinator.InvalidStatus(subject.status);
        }
        if (
            block.number <= request.requestedAtBlock
                || block.number - request.requestedAtBlock
                    <= StreamEntropyCoordinator(payable(address(this)))
                        .effectiveRequestTimeoutBlocks(subject.collectionId)
        ) {
            revert StreamEntropyCoordinator.RequestNotExpired();
        }
        (, bytes32 boundKey,, bool received,) =
            IStreamEntropyProvider(request.provider).providerResultStatus(request.providerRequestId);
        if (boundKey != requestKey || received) {
            revert StreamEntropyCoordinator.ProviderOutputAlreadyReceived();
        }
    }

    function failed(
        StreamEntropyCoordinator.Request storage request,
        StreamEntropyCoordinator.Subject storage subject,
        bytes32 requestKey
    ) public view {
        if (subject.requestKey != requestKey) {
            revert StreamEntropyCoordinator.InvalidSubject(request.subjectKey);
        }
        if (subject.status != StreamEntropyStatus.REQUESTED) {
            revert StreamEntropyCoordinator.InvalidStatus(subject.status);
        }
        (StreamProviderResultStatus status, bytes32 boundKey,, bool received,) =
            IStreamEntropyProvider(request.provider).providerResultStatus(request.providerRequestId);
        if (
            boundKey != requestKey || received
                || status != StreamProviderResultStatus.TERMINAL_FAILED
        ) {
            revert StreamEntropyCoordinator.ProviderFailureUnproven();
        }
    }
}
