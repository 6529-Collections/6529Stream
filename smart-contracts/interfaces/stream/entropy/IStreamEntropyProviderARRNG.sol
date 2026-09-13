// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamEntropyProvider.sol";
import "../parameters/IStreamGasParameterHost.sol";

/// @notice ARRNG operations in addition to the permanent provider request/result interface.
interface IStreamEntropyProviderARRNG is IStreamEntropyProvider, IStreamGasParameterHost {
    error ARRNGInvalidConfiguration();
    error ARRNGUnauthorized(address caller);
    error ARRNGUpstreamDrift();
    error ARRNGInvalidRequest(bytes32 requestKey);
    error ARRNGPaymentMismatch(uint256 expected, uint256 received);
    error ARRNGPaymentBelowMinimum(uint256 payment, uint256 minimum);
    error ARRNGRequestCounterMismatch(uint256 expected, uint256 returnedId, uint256 actual);
    error ARRNGInvalidCallback(uint256 requestId);
    error ARRNGSubmissionRefund();
    error ARRNGResultNotRetryable(uint256 requestId);
    error ARRNGInvalidAction();
    error ARRNGWithdrawalFailed();

    event ProviderEntropyRequested(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed providerRequestId,
        address indexed coordinator,
        uint32 providerEpoch
    );
    event ProviderEntropyReceived(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed providerRequestId,
        bytes32 rawRandomness
    );
    event ARRNGEntropyRequested(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed requestId,
        uint32 providerEpoch,
        uint256 paymentWei
    );
    event ARRNGRequestContext(
        uint16 schemaVersion,
        uint256 indexed requestId,
        uint256 deliveryGasLimit,
        bytes32 contextHash,
        address controllerOwner
    );
    event ARRNGControllerOwnerPinUpdated(
        uint16 schemaVersion,
        bytes32 indexed actionId,
        address oldOwner,
        address newOwner,
        uint64 revision
    );
    event ARRNGEntropyReceived(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed requestId,
        bytes32 rawRandomness
    );
    event ARRNGCallbackIgnored(uint16 schemaVersion, uint256 indexed requestId);
    event ARRNGDeliveryBudgetUsed(
        uint16 schemaVersion,
        uint256 indexed requestId,
        bool retry,
        uint256 configuredGas,
        uint256 forwardedGas
    );
    event ProviderCoordinatorFulfillmentAttempted(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed providerRequestId,
        bool success,
        bytes returnData
    );
    event ARRNGPaymentUpdated(uint16 schemaVersion, uint256 oldPaymentWei, uint256 newPaymentWei);
    event ARRNGPaymentUpdateContext(
        uint16 schemaVersion, bytes32 indexed actionId, uint64 revision
    );
    event ProviderRefundReceived(uint16 schemaVersion, uint256 amountWei);
    event ProviderFundsWithdrawn(uint16 schemaVersion, address indexed to, uint256 amountWei);
    event ARRNGWithdrawalContext(uint16 schemaVersion, bytes32 indexed actionId, uint64 revision);

    function receiveRandomness(uint256 requestId, uint256[] calldata randomNumbers) external payable;
    function requestPaymentWei() external view returns (uint256);
    function withdrawalDestination() external view returns (address);
    function updateRequestPayment(uint256 newPaymentWei) external;
    function updateControllerOwnerPin(address newOwner) external;
    function ownerPinTransitionHashes(address newOwner)
        external
        view
        returns (bytes32 scope, bytes32 oldState, bytes32 newState);
    function withdrawFunds(uint256 amountWei) external;
    function paymentTransitionHashes(uint256 newPaymentWei)
        external
        view
        returns (bytes32 scope, bytes32 oldState, bytes32 newState);
    function withdrawalTransitionHashes(uint256 amountWei)
        external
        view
        returns (bytes32 scope, bytes32 oldState, bytes32 newState);
}
