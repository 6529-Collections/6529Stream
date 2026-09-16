// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamEntropyCoordinator.sol";
import "./StreamEntropyCoordinatorReads.sol";
import "./StreamEntropyFreshRecovery.sol";
import "./StreamEntropyProviderLifecycle.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";

/// @notice Fixed callback state worker; counters, original finalization event and metadata notification stay in the host.
library StreamEntropyFulfillment {
    event StaleEntropyFulfillment(
        uint16 schemaVersion,
        uint256 indexed tokenId,
        address indexed provider,
        bytes32 requestKey,
        uint32 providerEpoch,
        string reason
    );
    event EntropyRecoverySuperseded(
        uint16 schemaVersion,
        bytes32 indexed acceptedRequestKey,
        bytes32 indexed displacedRequestKey
    );

    function finalize(
        IStreamCore core,
        StreamEntropyCoordinator.Request storage request,
        StreamEntropyCoordinator.Subject storage subject,
        IStreamEntropyEpochs.RequestPolicySnapshot storage policy,
        bytes32 requestKey,
        bytes32 rawRandomness
    ) public returns (uint8) {
        if (request.provider == address(0)) return 4;
        if (msg.sender != request.provider) {
            revert StreamEntropyCoordinator.Unauthorized(msg.sender);
        }
        if (subject.status == StreamEntropyStatus.FINALIZED) return 3;
        if (!StreamEntropyProviderLifecycle.canFulfill(msg.sender, policy.providerCodeHash)) {
            return 5;
        }
        if (subject.status == StreamEntropyStatus.STALE) return 1;
        if (subject.requestKey != requestKey) {
            if (!StreamEntropyFreshRecovery.mayFulfill(requestKey, subject.requestKey)) {
                if (StreamEntropyFreshRecovery.wasSuperseded(requestKey)) {
                    emit StaleEntropyFulfillment(
                        1,
                        request.tokenId,
                        request.provider,
                        requestKey,
                        policy.providerEpoch,
                        "frozen recovery policy"
                    );
                    return 1;
                }
                return 2;
            }
        }
        if (subject.status != StreamEntropyStatus.REQUESTED) return 2;
        if (subject.requestKey != requestKey) {
            emit EntropyRecoverySuperseded(1, requestKey, subject.requestKey);
            subject.requestKey = requestKey;
        }
        bytes32 seed = StreamEntropyCoordinatorReads.deriveSeed(
            core, requestKey, request, subject, policy, rawRandomness
        );
        request.rawRandomness = rawRandomness;
        subject.seed = seed;
        subject.status = StreamEntropyStatus.FINALIZED;
        return 0;
    }
}
