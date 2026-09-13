// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/entropy/IStreamEntropyProviderARRNG.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProviderFeeQuote.sol";
import "../../integrations/arrng/IStreamARRNGController.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../modules/StreamModuleBase.sol";

/// @notice Pinned ARRNG adapter with stored-output retry and governed operational custody.
/// @dev ARRNG supplies the incoming callback gas. This host's governed cap bounds only its
///      coordinator subcall. Failure before raw persistence remains unknown, never a new draw.
contract StreamEntropyProviderARRNG is
    StreamModuleBase,
    StreamGasParameterHost,
    ReentrancyGuard,
    IStreamEntropyProviderARRNG
{
    bytes32 public constant RAW_DOMAIN = keccak256("6529STREAM_ARRNG_RAW_V1");
    bytes32 public constant GGP_CALLBACK_GAS_LIMIT =
        keccak256("6529STREAM_GGP_VRF_CALLBACK_GAS_LIMIT");
    uint256 public constant CALLBACK_GAS_FLOOR = 300_000;
    uint256 private constant _DELIVERY_RESERVE = 55_000;
    bytes32 private constant _OPERATION_SCOPE = keccak256("6529STREAM_ARRNG_OPERATION_SCOPE_V1");
    bytes32 private constant _OPERATION_STATE = keccak256("6529STREAM_ARRNG_OPERATION_STATE_V1");

    struct Config {
        address coordinator;
        address authority;
        address controller;
        bytes32 controllerCodeHash;
        address controllerOwner;
        address controllerOracle;
        address treasury;
        uint256 paymentWei;
        uint256 deliveryGasLimit;
    }

    struct ProviderResult {
        bytes32 requestKey;
        bytes32 rawRandomness;
        StreamProviderResultStatus status;
        uint64 receivedAtBlock;
        uint64 deliveredAtBlock;
        uint256 deliveryGasLimit;
    }

    address public immutable coordinator;
    IStreamARRNGController public immutable arrngController;
    bytes32 public immutable controllerCodeHash;
    address public controllerOwner;
    address public immutable controllerOracle;
    address public immutable override withdrawalDestination;
    uint256 public override requestPaymentWei;
    uint64 public paymentRevision = 1;
    uint64 public ownerPinRevision = 1;
    uint64 public withdrawalRevision = 1;
    uint256 public totalRefundsReceived;
    uint256 public totalWithdrawn;
    mapping(uint256 => ProviderResult) public results;
    mapping(bytes32 => uint256) public keyToArrngRequest;
    bytes32 private _lastPaymentAction;
    bytes32 private _lastOwnerPinAction;
    bytes32 private _lastWithdrawalAction;
    bool private _submitting;

    constructor(
        Config memory config,
        bytes32 deploymentHash,
        string memory manifestURI,
        bytes32 manifestHash
    )
        StreamModuleBase(
            keccak256("6529stream.entropy-provider-arrng.schema.v1"),
            address(0),
            deploymentHash,
            manifestURI,
            manifestHash
        )
        StreamGasParameterHost(config.authority)
    {
        if (
            config.coordinator.code.length == 0 || config.authority == address(0)
                || config.controller.code.length == 0 || config.controllerCodeHash == 0
                || config.controller.codehash != config.controllerCodeHash
                || config.controllerOwner == address(0) || config.controllerOracle == address(0)
                || config.treasury.code.length == 0 || config.paymentWei == 0 || deploymentHash == 0
                || manifestHash == 0
        ) revert ARRNGInvalidConfiguration();
        coordinator = config.coordinator;
        arrngController = IStreamARRNGController(config.controller);
        controllerCodeHash = config.controllerCodeHash;
        controllerOwner = config.controllerOwner;
        controllerOracle = config.controllerOracle;
        withdrawalDestination = config.treasury;
        requestPaymentWei = config.paymentWei;
        _registerGasParameter(
            GasParameterConfig(
                "VRF_CALLBACK_GAS_LIMIT",
                config.deliveryGasLimit,
                CALLBACK_GAS_FLOOR,
                FAILURE_CLASS_FORWARDING_CAP
            )
        );
        _requireUpstream();
        _requireFundedQuote();
    }

    /// @notice Controller refunds are treasury surplus, never a second caller-credit ledger.
    receive() external payable {
        if (msg.sender != address(arrngController)) revert ARRNGUnauthorized(msg.sender);
        if (_submitting) revert ARRNGSubmissionRefund();
        _recordRefund();
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("ENTROPY_PROVIDER");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.entropy-provider-arrng.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamEntropyProvider).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamEntropyProvider).interfaceId
            || id == type(IStreamEntropyProviderFeeQuote).interfaceId
            || id == type(IStreamEntropyProviderARRNG).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
    }

    function isStreamEntropyProvider() external pure override returns (bool) {
        return true;
    }

    function streamEntropyProviderFamily() external pure override returns (bytes32) {
        return keccak256("6529STREAM_ENTROPY_PROVIDER_ARRNG");
    }

    function streamEntropyProviderVersion() external pure override returns (bytes32) {
        return streamModuleVersion();
    }

    function streamEntropyProviderConfigHash() external view override returns (bytes32) {
        return keccak256(
            abi.encode(
                streamModuleVersion(),
                block.chainid,
                coordinator,
                address(arrngController),
                controllerCodeHash,
                controllerOracle,
                uint256(1)
            )
        );
    }

    function quoteRequest(bytes calldata) external view override returns (uint256) {
        return contextIndependentRequestFee();
    }

    /// @notice Live ARRNG payment shared by actual request quotes and reveal policy funding.
    function contextIndependentRequestFee() public view returns (uint256) {
        _requireUpstream();
        _requireFundedQuote();
        return requestPaymentWei;
    }

    function requestEntropy(bytes32 requestKey, bytes calldata context)
        external
        payable
        override
        nonReentrant
        returns (uint256 providerRequestId)
    {
        if (msg.sender != coordinator) revert ARRNGUnauthorized(msg.sender);
        if (requestKey == 0 || keyToArrngRequest[requestKey] != 0) {
            revert ARRNGInvalidRequest(requestKey);
        }
        _requireUpstream();
        _requireFundedQuote();
        uint256 payment = requestPaymentWei;
        if (msg.value != payment) revert ARRNGPaymentMismatch(payment, msg.value);
        uint256 beforeCounter = arrngController.arrngRequestId();
        if (beforeCounter == type(uint64).max) revert ARRNGInvalidRequest(requestKey);
        uint256 budget = gasParameter(GGP_CALLBACK_GAS_LIMIT);
        _submitting = true;
        providerRequestId = arrngController.requestRandomWords{ value: payment }(1, address(this));
        _submitting = false;
        uint256 afterCounter = arrngController.arrngRequestId();
        if (providerRequestId != beforeCounter + 1 || afterCounter != providerRequestId) {
            revert ARRNGRequestCounterMismatch(beforeCounter + 1, providerRequestId, afterCounter);
        }
        _requireUpstream();
        if (results[providerRequestId].requestKey != 0) revert ARRNGInvalidRequest(requestKey);
        keyToArrngRequest[requestKey] = providerRequestId;
        results[providerRequestId] =
            ProviderResult(requestKey, 0, StreamProviderResultStatus.REQUESTED, 0, 0, budget);
        emit ARRNGEntropyRequested(1, requestKey, providerRequestId, 1, payment);
        emit ARRNGRequestContext(1, providerRequestId, budget, keccak256(context), controllerOwner);
        emit ProviderEntropyRequested(1, requestKey, providerRequestId, coordinator, 1);
    }

    /// @notice Authenticated refunds and exactly one word; no successful discard before persistence.
    function receiveRandomness(uint256 requestId, uint256[] calldata randomNumbers)
        external
        payable
        override
        nonReentrant
    {
        if (msg.sender != address(arrngController)) revert ARRNGUnauthorized(msg.sender);
        _requireUpstream();
        ProviderResult storage result = results[requestId];
        if (result.requestKey == 0 || randomNumbers.length != 1) {
            revert ARRNGInvalidCallback(requestId);
        }
        _recordRefund();
        if (result.status != StreamProviderResultStatus.REQUESTED) {
            emit ARRNGCallbackIgnored(1, requestId);
            return;
        }
        result.rawRandomness =
            keccak256(abi.encode(RAW_DOMAIN, result.requestKey, requestId, randomNumbers));
        result.receivedAtBlock = uint64(block.number);
        result.status = StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED;
        emit ARRNGEntropyReceived(1, result.requestKey, requestId, result.rawRandomness);
        emit ProviderEntropyReceived(1, result.requestKey, requestId, result.rawRandomness);
        _deliver(requestId, result, result.deliveryGasLimit, false);
    }

    /// @notice Uses the retained output even after upstream authority drift; no new upstream call.
    function retryCoordinatorFulfillment(uint256 requestId) external override nonReentrant {
        ProviderResult storage result = results[requestId];
        if (result.status != StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED) {
            revert ARRNGResultNotRetryable(requestId);
        }
        _deliver(requestId, result, gasParameter(GGP_CALLBACK_GAS_LIMIT), true);
    }

    function _deliver(uint256 requestId, ProviderResult storage result, uint256 cap, bool retry)
        private
    {
        bytes memory data = abi.encodeCall(
            IStreamEntropyCoordinator.fulfillEntropy, (result.requestKey, result.rawRandomness)
        );
        uint256 available = gasleft();
        uint256 eip150 = cap / 63 + (cap % 63 == 0 ? 0 : 1);
        if (
            available <= _DELIVERY_RESERVE || cap > available - _DELIVERY_RESERVE
                || eip150 > available - _DELIVERY_RESERVE - cap
        ) {
            emit ARRNGDeliveryBudgetUsed(1, requestId, retry, cap, 0);
            emit ProviderCoordinatorFulfillmentAttempted(1, result.requestKey, requestId, false, "");
            return;
        }
        address target = coordinator;
        bool success;
        uint256 size;
        uint256 outcome;
        assembly ("memory-safe") {
            let response := mload(0x40)
            mstore(response, 0)
            success := call(cap, target, 0, add(data, 32), mload(data), response, 32)
            size := returndatasize()
            outcome := mload(response)
        }
        emit ARRNGDeliveryBudgetUsed(1, requestId, retry, cap, cap);
        if (!success || size != 32 || outcome > 5) {
            emit ProviderCoordinatorFulfillmentAttempted(1, result.requestKey, requestId, false, "");
            return;
        }
        if (outcome == 0 || outcome == 3) {
            result.status = StreamProviderResultStatus.DELIVERED;
            result.deliveredAtBlock = uint64(block.number);
        } else if (outcome == 1 || outcome == 2) {
            result.status = StreamProviderResultStatus.TERMINAL_STALE;
        }
        emit ProviderCoordinatorFulfillmentAttempted(
            1, result.requestKey, requestId, true, abi.encode(uint8(outcome))
        );
    }

    function providerResultStatus(uint256 requestId)
        external
        view
        override
        returns (
            StreamProviderResultStatus status,
            bytes32 requestKey,
            bytes32 rawRandomnessHash,
            bool rawRandomnessReceived,
            bool delivered
        )
    {
        ProviderResult storage result = results[requestId];
        status = result.status;
        requestKey = result.requestKey;
        rawRandomnessReceived = status == StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED
            || status == StreamProviderResultStatus.DELIVERED
            || status == StreamProviderResultStatus.TERMINAL_STALE;
        rawRandomnessHash =
            rawRandomnessReceived ? keccak256(abi.encode(result.rawRandomness)) : bytes32(0);
        delivered = status == StreamProviderResultStatus.DELIVERED;
    }

    function paymentTransitionHashes(uint256 next)
        public
        view
        override
        returns (bytes32 scope, bytes32 oldState, bytes32 newState)
    {
        if (next == 0 || next == requestPaymentWei || paymentRevision == type(uint64).max) {
            revert ARRNGInvalidAction();
        }
        scope = keccak256(
            abi.encode(
                _OPERATION_SCOPE, block.chainid, address(this), this.updateRequestPayment.selector
            )
        );
        oldState =
            keccak256(abi.encode(_OPERATION_STATE, scope, requestPaymentWei, paymentRevision));
        newState = keccak256(abi.encode(_OPERATION_STATE, scope, next, paymentRevision + 1));
    }

    function updateRequestPayment(uint256 next) external override {
        (bytes32 scope, bytes32 oldState, bytes32 newState) = paymentTransitionHashes(next);
        bytes32 actionId = _requireAction(scope, oldState, newState, _lastPaymentAction);
        uint256 old = requestPaymentWei;
        requestPaymentWei = next;
        ++paymentRevision;
        _lastPaymentAction = actionId;
        emit ARRNGPaymentUpdated(1, old, next);
        emit ARRNGPaymentUpdateContext(1, actionId, paymentRevision);
    }

    /// @notice A delayed owner-custody refresh changes no provider randomness input or request.
    function ownerPinTransitionHashes(address next)
        public
        view
        override
        returns (bytes32 scope, bytes32 oldState, bytes32 newState)
    {
        if (next == address(0) || next == controllerOwner || ownerPinRevision == type(uint64).max) {
            revert ARRNGInvalidAction();
        }
        scope = keccak256(
            abi.encode(
                _OPERATION_SCOPE,
                block.chainid,
                address(this),
                this.updateControllerOwnerPin.selector
            )
        );
        oldState = keccak256(abi.encode(_OPERATION_STATE, scope, controllerOwner, ownerPinRevision));
        newState = keccak256(abi.encode(_OPERATION_STATE, scope, next, ownerPinRevision + 1));
    }

    function updateControllerOwnerPin(address next) external override {
        (bytes32 scope, bytes32 oldState, bytes32 newState) = ownerPinTransitionHashes(next);
        bytes32 actionId = _requireAction(scope, oldState, newState, _lastOwnerPinAction);
        if (
            address(arrngController).codehash != controllerCodeHash
                || arrngController.oracleAddress() != controllerOracle
                || arrngController.owner() != next
        ) {
            revert ARRNGUpstreamDrift();
        }
        address old = controllerOwner;
        controllerOwner = next;
        ++ownerPinRevision;
        _lastOwnerPinAction = actionId;
        emit ARRNGControllerOwnerPinUpdated(1, actionId, old, next, ownerPinRevision);
    }

    function withdrawalTransitionHashes(uint256 amount)
        public
        view
        override
        returns (bytes32 scope, bytes32 oldState, bytes32 newState)
    {
        if (amount == 0 || amount > address(this).balance || withdrawalRevision == type(uint64).max)
        {
            revert ARRNGInvalidAction();
        }
        scope = keccak256(
            abi.encode(
                _OPERATION_SCOPE,
                block.chainid,
                address(this),
                this.withdrawFunds.selector,
                withdrawalDestination
            )
        );
        oldState =
            keccak256(abi.encode(_OPERATION_STATE, scope, totalWithdrawn, withdrawalRevision));
        newState = keccak256(
            abi.encode(_OPERATION_STATE, scope, totalWithdrawn + amount, withdrawalRevision + 1)
        );
    }

    function withdrawFunds(uint256 amount) external override nonReentrant {
        (bytes32 scope, bytes32 oldState, bytes32 newState) = withdrawalTransitionHashes(amount);
        bytes32 actionId = _requireAction(scope, oldState, newState, _lastWithdrawalAction);
        totalWithdrawn += amount;
        ++withdrawalRevision;
        _lastWithdrawalAction = actionId;
        (bool success,) = withdrawalDestination.call{ value: amount }("");
        if (!success) revert ARRNGWithdrawalFailed();
        emit ProviderFundsWithdrawn(1, withdrawalDestination, amount);
        emit ARRNGWithdrawalContext(1, actionId, withdrawalRevision);
    }

    function _requireAction(bytes32 scope, bytes32 oldState, bytes32 newState, bytes32 previous)
        private
        view
        returns (bytes32)
    {
        if (msg.sender != governanceAuthority) revert ARRNGUnauthorized(msg.sender);
        bytes memory data = abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ());
        bytes memory response = new bytes(192);
        address authority = governanceAuthority;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), authority, add(data, 32), mload(data), add(response, 32), 192)
            size := returndatasize()
        }
        if (!ok || size != 192) revert ARRNGInvalidAction();
        (bool executing, bytes32 id, uint8 class_, bytes32 scope_, bytes32 old_, bytes32 new_) =
            abi.decode(response, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            !executing || id == 0 || id == previous || class_ != 1 || scope_ != scope
                || old_ != oldState || new_ != newState
        ) revert ARRNGInvalidAction();
        return id;
    }

    function _requireUpstream() private view {
        if (
            address(arrngController).codehash != controllerCodeHash
                || arrngController.owner() != controllerOwner
                || arrngController.oracleAddress() != controllerOracle
        ) revert ARRNGUpstreamDrift();
    }

    function _requireFundedQuote() private view {
        uint256 minimum = arrngController.minimumNativeToken();
        if (requestPaymentWei < minimum) {
            revert ARRNGPaymentBelowMinimum(requestPaymentWei, minimum);
        }
    }

    function _recordRefund() private {
        if (msg.value != 0) {
            totalRefundsReceived += msg.value;
            emit ProviderRefundReceived(1, msg.value);
        }
    }
}
