// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSettlementContext.sol";
import "./StreamPrimarySettlementHash.sol";
import "./StreamPermitExecution.sol";
import "./StreamERC20PaymentRead.sol";
import "./StreamERC20DutchPaymentRead.sol";
import {
    IStreamERC20DutchPayments as D
} from "../../interfaces/stream/revenue/IStreamERC20DutchPayments.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamAssetPermitPolicy.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Contract20 is the sole first-pull authorization boundary for universal ERC20 sales.
/// @dev A phase latch allows exactly one funding return from immutable contract9. There is no
///      owner, approval writer, arbitrary executor, fallback route, or persistent payment custody.
contract StreamERC20PrimarySettlementAdapter is
    IStreamERC20PrimarySettlementAdapter,
    D,
    StreamSettlementContext,
    ERC165
{
    bytes32 public constant PAYMENT_INTENT_TYPEHASH = keccak256(
        "StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)"
    );
    bytes32 public constant PAYMENT_INTENT_REVOCATION_TYPEHASH =
        keccak256("StreamPaymentIntentRevocation(address payer,bytes32 nonce,uint64 deadline)");
    bytes32 private constant _DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    address public immutable override primarySaleSettlement;
    bytes32 public immutable settlementCodeHash;
    address public immutable permit2;
    bytes32 public immutable permit2CodeHash;
    uint256 public immutable permit2ChainId;
    enum Phase {
        IDLE,
        LOCKED,
        AUTHENTICATED,
        SALE_CALLBACK,
        FUNDING,
        FUNDED
    }
    Phase public phase;

    struct ActiveFunding {
        bytes32 commitment;
        bytes32 key;
        bytes32 inputHash;
        bytes32 permitPolicyHash;
        bytes4 selector;
        uint8 mode;
        address payer;
        address asset;
        uint256 amount;
        uint256 originalSelf;
        uint256 originalRecorder;
    }
    ActiveFunding private _active;
    bytes private _permitInput;
    mapping(address => mapping(bytes32 => bool)) private _used;

    error PaymentOperationActive();
    error InvalidPaymentCandidate();
    error InvalidPaymentIntent();
    error PaymentIntentExpired(uint64 deadline);
    error PaymentIntentNonceUsed(address payer, bytes32 nonce);
    error InvalidPaymentSignature(address payer);
    error UnauthorizedFundingReturn();
    error PaymentCallbackFailed();
    error PaymentCallbackMalformed(uint256 length);
    error PaymentResultMismatch();
    error PaymentNativeBalanceMismatch();
    error PermitCapabilityUnavailable(address asset);
    error PermitAuthorizationFailed();

    // Original surfaced worker errors retained in the host ABI.
    error SaleLifecycleMismatch(address saleAdapter, bytes32 saleId);
    error SaleLifecycleReadFailed(address saleAdapter);
    error SaleLifecycleReadMalformed(address saleAdapter, uint256 length);
    error SettlementModuleNotAdmitted(address module);
    error SettlementModuleReadFailed(address module);
    error SettlementModuleReadMalformed(address module, uint256 length);

    constructor(
        IStreamPrimarySaleSettlement recorder,
        address permit2_,
        bytes32 expectedPermit2CodeHash
    ) StreamSettlementContext(recorder.revenueResolver(), recorder.moduleRegistry()) {
        if (
            !StreamSettlementAdmission.isContract(address(recorder))
                || !recorder.isStreamPrimarySaleSettlement() || recorder.core() != core
                || address(recorder.splitFactory()) != address(splitFactory)
                || address(recorder.assetPolicyRegistry()) != address(assetPolicyRegistry)
        ) revert InvalidSettlementContext(address(recorder));
        if (permit2_ == address(0)) {
            if (expectedPermit2CodeHash != 0) revert InvalidSettlementContext(permit2_);
        } else if (
            !StreamSettlementAdmission.isContract(permit2_) || expectedPermit2CodeHash == 0
                || permit2_.codehash != expectedPermit2CodeHash
        ) {
            revert InvalidSettlementContext(permit2_);
        }
        primarySaleSettlement = address(recorder);
        settlementCodeHash = address(recorder).codehash;
        permit2 = permit2_;
        permit2CodeHash = expectedPermit2CodeHash;
        permit2ChainId = block.chainid;
    }

    function isStreamERC20PrimarySettlementAdapter() external pure override returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamERC20PrimarySettlementAdapter).interfaceId
            || id == type(D).interfaceId || super.supportsInterface(id);
    }

    function settleERC20PrimarySaleByPayer(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        bytes calldata data
    )
        external
        payable
        override
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult calldata)
    {
        _fixedEntry();
    }

    function settleERC20PrimarySaleWithIntent(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        StreamPrimarySettlementTypes.PaymentIntent calldata intent,
        bytes calldata signature,
        bytes calldata data
    )
        external
        payable
        override
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult calldata)
    {
        _fixedEntry();
    }

    function settleERC20PrimarySaleWithEIP2612Permit(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization calldata permit,
        bytes calldata data
    )
        external
        payable
        override
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult calldata)
    {
        _fixedEntry();
    }

    function settleERC20PrimarySaleWithPermit2(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        StreamPrimarySettlementTypes.Permit2TransferAuthorization calldata permit,
        bytes calldata data
    )
        external
        payable
        override
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult calldata)
    {
        _fixedEntry();
    }

    function _fixedEntry() private {
        StreamERC20PaymentRead.FixedPlan memory p = StreamERC20PaymentRead.prepareFixed(msg.data);
        _begin(p.candidate, p.executionData, p.mode, p.permitInput);
        if (p.mode == 1) {
            _authenticatePaymentIntent(p.candidate, p.intent, p.signature, true);
        } else {
            if (
                msg.sender != p.candidate.sale.payer
                    || (p.mode != 0 && block.timestamp > p.deadline)
            ) {
                revert InvalidPaymentCandidate();
            }
            if (p.mode != 0) {
                _active.permitPolicyHash = keccak256(abi.encode(_permitPolicy(p.candidate.asset)));
            }
        }
        bytes memory encoded = abi.encode(_execute(p.candidate, p.executionData));
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function _authenticatePaymentIntent(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamPrimarySettlementTypes.PaymentIntent memory intent,
        bytes memory signature,
        bool consume
    ) private {
        if (
            intent.payer != c.sale.payer || intent.asset != c.asset
                || intent.maxAmount < c.sale.amount || intent.saleRef != c.sale.settlementId
                || intent.expectedPrimaryPolicyHash != c.sale.expectedPrimaryPolicyHash
        ) revert InvalidPaymentIntent();
        _unused(intent.payer, intent.nonce);
        if (block.timestamp > intent.deadline) revert PaymentIntentExpired(intent.deadline);
        if (!_validSignature(
                intent.payer,
                _digest(keccak256(abi.encode(PAYMENT_INTENT_TYPEHASH, intent))),
                signature
            )) revert InvalidPaymentSignature(intent.payer);
        _unused(intent.payer, intent.nonce);
        if (consume) {
            _used[intent.payer][intent.nonce] = true;
            emit PaymentIntentConsumed(
                intent.payer, intent.saleRef, intent.nonce, 1, c.asset, c.sale.amount
            );
        }
    }

    function settleERC20DutchSaleByPayer(D.Request calldata)
        external
        payable
        override
        returns (D.Result calldata)
    {
        _dutchEntry();
    }

    function settleERC20DutchSaleWithIntent(
        D.Request calldata,
        StreamPrimarySettlementTypes.PaymentIntent calldata,
        bytes calldata
    ) external payable override returns (D.Result calldata) {
        _dutchEntry();
    }

    function settleERC20DutchSaleWithEIP2612Permit(D.Request calldata, D.EIP2612Maximum calldata)
        external
        payable
        override
        returns (D.Result calldata)
    {
        _dutchEntry();
    }

    function settleERC20DutchSaleWithPermit2(D.Request calldata, D.Permit2Maximum calldata)
        external
        payable
        override
        returns (D.Result calldata)
    {
        _dutchEntry();
    }

    function _dutchEntry() private {
        _lock();
        _requirePaymentContext();
        StreamERC20DutchPaymentRead.Plan memory p =
            StreamERC20DutchPaymentRead.prepare(moduleRegistry, primarySaleSettlement, msg.data);
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c = p.candidate;
        if (c.executionBinding.authorityMode == 2 && c.sale.payer != msg.sender) {
            revert InvalidPaymentCandidate();
        }
        _requireActive(c.asset);
        if (p.mode == 1) {
            _authenticatePaymentIntent(c, p.intent, p.signature, c.sale.amount != 0);
        } else {
            if (msg.sender != c.sale.payer) revert InvalidPaymentCandidate();
            if (
                c.sale.amount != 0 && (p.mode == 4 || p.mode == 5)
                    && (p.permittedAmount < c.sale.amount || block.timestamp > p.deadline)
            ) revert InvalidPaymentCandidate();
        }
        D.Result memory result = _finishDutch(p.executionData, c, p.mode, p.permitInput);
        bytes memory encoded = abi.encode(result);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function _finishDutch(
        bytes memory executionData,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        uint8 mode,
        bytes memory permitInput
    ) private returns (D.Result memory r) {
        r.executionId = c.executionBinding.executionId;
        if (c.sale.amount == 0) {
            uint256 originalNativeBalance = address(this).balance - msg.value;
            uint256 cap = _gas(_DEPOSIT_GAS);
            uint256 selfBalance = _balance(c.asset, address(this), cap);
            uint256 recorderBalance = _balance(c.asset, primarySaleSettlement, cap);
            uint256 payerBalance = _balance(c.asset, c.sale.payer, cap);
            phase = Phase.AUTHENTICATED;
            StreamERC20DutchPaymentRead.executeFree(c, executionData);
            _requirePaymentContext();
            _requireActive(c.asset);
            StreamSettlementAdmission.requireDutchAdmission(moduleRegistry, address(this), c);
            if (
                phase != Phase.AUTHENTICATED || _balance(c.asset, address(this), cap) != selfBalance
                    || _balance(c.asset, primarySaleSettlement, cap) != recorderBalance
                    || _balance(c.asset, c.sale.payer, cap) != payerBalance
            ) revert PaymentResultMismatch();
            if (address(this).balance != originalNativeBalance) {
                revert PaymentNativeBalanceMismatch();
            }
            phase = Phase.IDLE;
            r.revenueOutcome = 1;
            return r;
        }
        _open(c, executionData, mode, permitInput);
        if (mode == 4 || mode == 5) {
            _active.permitPolicyHash = keccak256(abi.encode(_permitPolicy(c.asset)));
        }
        r.settlement = _execute(c, executionData);
        r.revenueOutcome = 2;
    }

    function _begin(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        bytes memory data,
        uint8 mode,
        bytes memory permitInput
    ) private {
        _lock();
        _open(c, data, mode, permitInput);
    }

    function _open(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        bytes memory data,
        uint8 mode,
        bytes memory permitInput
    ) private {
        if (
            c.executor != msg.sender || c.lifecycleBinding.paymentAdapter != address(this)
                || c.sale.payer == address(0) || c.sale.payer == address(this)
                || c.sale.payer == primarySaleSettlement || c.sale.amount == 0
                || c.sale.settlementId == 0 || c.sale.expectedPrimaryPolicyHash == 0
                || c.saleExecutionHash != keccak256(data) || c.orchestrationOrder != 1
                || (_isDutchEntry()
                        ? (c.executionBinding.authorityMode != 1
                            && c.executionBinding.authorityMode != 2)
                        : c.executionBinding.authorityMode != 1)
                || c.operationIdentityCommitment == 0 || c.operationId == 0
                || c.executionBinding.executionId != StreamPrimarySettlementHash.executionId(c)
        ) revert InvalidPaymentCandidate();
        _requirePaymentContext();
        _requireActive(c.asset);
        _requireCandidateAdmission(c);
        uint256 cap = _gas(_DEPOSIT_GAS);
        _active = ActiveFunding(
            StreamPrimarySettlementHash.candidateCommitment(
                address(this), primarySaleSettlement, c
            ),
            StreamPrimarySettlementHash.settlementKey(
                primarySaleSettlement, c.saleAdapter, c.executionBinding.executionId
            ),
            keccak256(abi.encode(msg.sig, mode, keccak256(permitInput))),
            bytes32(0),
            msg.sig,
            mode,
            c.sale.payer,
            c.asset,
            c.sale.amount,
            _balance(c.asset, address(this), cap),
            _balance(c.asset, primarySaleSettlement, cap)
        );
        _permitInput = permitInput;
    }

    function _isDutchEntry() private view returns (bool) {
        return msg.sig == D.settleERC20DutchSaleByPayer.selector
            || msg.sig == D.settleERC20DutchSaleWithIntent.selector
            || msg.sig == D.settleERC20DutchSaleWithEIP2612Permit.selector
            || msg.sig == D.settleERC20DutchSaleWithPermit2.selector;
    }

    function _requireCandidateAdmission(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view {
        if (_isDutchEntry()) {
            StreamSettlementAdmission.requireDutchAdmission(moduleRegistry, address(this), c);
        } else {
            StreamERC20PaymentRead.requireAdmission(moduleRegistry, address(this), c);
        }
    }

    function _execute(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        bytes memory executionData
    ) private returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        uint256 originalNativeBalance = address(this).balance - msg.value;
        phase = Phase.AUTHENTICATED;
        bytes memory data = abi.encodeCall(
            IStreamERC20SaleExecution.executeERC20PreRevenueSingleStep, (c, executionData)
        );
        phase = Phase.SALE_CALLBACK;
        bytes memory response = new bytes(416);
        bool ok;
        uint256 size;
        address target = c.saleAdapter;
        assembly ("memory-safe") {
            ok := call(
                gas(),
                target,
                callvalue(),
                add(data, 32),
                mload(data),
                add(response, 32),
                416
            )
            size := returndatasize()
        }
        if (!ok) revert PaymentCallbackFailed();
        if (size != 416) revert PaymentCallbackMalformed(size);
        bytes4 magic;
        (magic, result) =
            abi.decode(response, (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            phase != Phase.FUNDED
                || magic != IStreamERC20SaleExecution.executeERC20PreRevenueSingleStep.selector
                || result.candidateCommitment != _active.commitment
                || result.settlementKey != _active.key || result.profileId != c.rights.profileId
                || result.wallet != c.rights.wallet || result.asset != c.asset
                || result.amount != c.sale.amount || result.executor != c.executor
                || result.executionId != c.executionBinding.executionId
                || result.operationIdentityCommitment != c.operationIdentityCommitment
                || result.currentPolicyHash != c.currentPolicyHash
                || result.boundPolicyHash != c.boundPolicyHash
        ) revert PaymentResultMismatch();
        _requirePaymentContext();
        _requireActive(c.asset);
        _requireCandidateAdmission(c);
        _checkStoredResult(result);
        uint256 cap = _gas(_DEPOSIT_GAS);
        if (
            _balance(c.asset, address(this), cap) != _active.originalSelf
                || _balance(c.asset, primarySaleSettlement, cap) != _active.originalRecorder
        ) revert SettlementAmountMismatch(c.asset);
        if (address(this).balance != originalNativeBalance) {
            revert PaymentNativeBalanceMismatch();
        }
        delete _active;
        delete _permitInput;
        phase = Phase.IDLE;
    }

    function fundERC20PrimarySale(bytes32 commitment, bytes32 key, address asset, uint256 amount)
        external
        override
    {
        if (
            msg.sender != primarySaleSettlement || phase != Phase.SALE_CALLBACK
                || commitment != _active.commitment || key != _active.key || asset != _active.asset
                || amount != _active.amount
        ) revert UnauthorizedFundingReturn();
        phase = Phase.FUNDING;
        if (
            _active.inputHash
                != keccak256(abi.encode(_active.selector, _active.mode, keccak256(_permitInput)))
        ) revert UnauthorizedFundingReturn();
        _requirePaymentContext();
        _requireActive(asset);
        uint256 cap = _gas(_DEPOSIT_GAS);
        uint256 beforePayer = _balance(asset, _active.payer, cap);
        if (
            beforePayer < amount || _balance(asset, address(this), cap) != _active.originalSelf
                || _balance(asset, primarySaleSettlement, cap) != _active.originalRecorder
        ) revert SettlementAmountMismatch(asset);
        if (_active.mode == 3 || _active.mode == 5) {
            if (_active.mode == 5) _pullPermit2Maximum(asset, amount, cap);
            else _pullPermit2(asset, amount, cap);
        } else {
            uint256 maximum;
            if (_active.mode == 2) _useEIP2612(asset, amount, cap);
            else if (_active.mode == 4) maximum = _useEIP2612Maximum(asset, amount, cap);
            _tokenCall(
                asset,
                abi.encodeCall(IERC20.transferFrom, (_active.payer, address(this), amount)),
                cap,
                false
            );
            if (_active.mode == 2 && _allowance(asset, _active.payer, address(this), cap) != 0) {
                revert PermitAuthorizationFailed();
            }
            if (_active.mode == 4) {
                uint256 remaining = _allowance(asset, _active.payer, address(this), cap);
                if (
                    remaining != maximum - amount
                        && !(maximum == type(uint256).max && remaining == maximum)
                ) revert PermitAuthorizationFailed();
            }
        }
        if (
            _balance(asset, _active.payer, cap) != beforePayer - amount
                || _balance(asset, address(this), cap) != _active.originalSelf + amount
        ) revert SettlementAmountMismatch(asset);
        _requireActive(asset);
        _transfer(asset, primarySaleSettlement, amount, cap, false);
        _requireActive(asset);
        if (
            _balance(asset, address(this), cap) != _active.originalSelf
                || _balance(asset, primarySaleSettlement, cap) != _active.originalRecorder + amount
        ) revert SettlementAmountMismatch(asset);
        phase = Phase.FUNDED;
    }

    function _useEIP2612(address asset, uint256 amount, uint256 cap) private {
        if (keccak256(abi.encode(_permitPolicy(asset))) != _active.permitPolicyHash) {
            revert PermitCapabilityUnavailable(asset);
        }
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p =
            abi.decode(_permitInput, (StreamPrimarySettlementTypes.EIP2612PermitAuthorization));
        StreamPermitExecution.permitEIP2612(_active.payer, asset, amount, p, cap);
    }

    function _pullPermit2(address asset, uint256 amount, uint256 cap) private {
        IStreamAssetPermitPolicy.AssetPermitPolicy memory policy = _permitPolicy(asset);
        if (keccak256(abi.encode(policy)) != _active.permitPolicyHash) {
            revert PermitCapabilityUnavailable(asset);
        }
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p =
            abi.decode(_permitInput, (StreamPrimarySettlementTypes.Permit2TransferAuthorization));
        StreamPermitExecution.pull(
            _active.payer, asset, amount, permit2, policy.permit2AllowanceMode, p, cap
        );
    }

    function _useEIP2612Maximum(address asset, uint256 amount, uint256 cap)
        private
        returns (uint256 maximum)
    {
        if (keccak256(abi.encode(_permitPolicy(asset))) != _active.permitPolicyHash) {
            revert PermitCapabilityUnavailable(asset);
        }
        D.EIP2612Maximum memory p = abi.decode(_permitInput, (D.EIP2612Maximum));
        maximum = p.permittedAmount;
        if (maximum < amount) revert PermitAuthorizationFailed();
        StreamPermitExecution.permitEIP2612(_active.payer, asset, maximum, p.authorization, cap);
    }

    function _pullPermit2Maximum(address asset, uint256 amount, uint256 cap) private {
        IStreamAssetPermitPolicy.AssetPermitPolicy memory policy = _permitPolicy(asset);
        if (keccak256(abi.encode(policy)) != _active.permitPolicyHash) {
            revert PermitCapabilityUnavailable(asset);
        }
        D.Permit2Maximum memory p = abi.decode(_permitInput, (D.Permit2Maximum));
        StreamPermitExecution.pullMaximum(
            _active.payer,
            asset,
            amount,
            p.permittedAmount,
            permit2,
            policy.permit2AllowanceMode,
            p.authorization,
            cap
        );
    }

    function _permitPolicy(address asset)
        private
        view
        returns (IStreamAssetPermitPolicy.AssetPermitPolicy memory)
    {
        _requireActive(asset);
        uint256 cap = _gas(_ASSET_GAS);
        return StreamERC20PaymentRead.permitPolicy(
            address(assetPolicyRegistry),
            asset,
            _active.mode,
            permit2,
            permit2CodeHash,
            permit2ChainId,
            cap
        );
    }

    function _checkStoredResult(StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
        private
        view
    {
        StreamERC20PaymentRead.checkStoredResult(primarySaleSettlement, result);
    }

    function _requirePaymentContext() private view {
        _requireContext();
        if (primarySaleSettlement.codehash != settlementCodeHash) {
            revert InvalidSettlementContext(primarySaleSettlement);
        }
    }

    function _lock() private {
        if (phase != Phase.IDLE) revert PaymentOperationActive();
        phase = Phase.LOCKED;
    }

    function _unused(address payer, bytes32 nonce) private view {
        if (payer == address(0)) revert InvalidPaymentIntent();
        if (_used[payer][nonce]) revert PaymentIntentNonceUsed(payer, nonce);
    }

    function isPaymentIntentNonceUsed(address payer, bytes32 nonce)
        external
        view
        override
        returns (bool)
    {
        return _used[payer][nonce];
    }

    function paymentIntentDigest(StreamPrimarySettlementTypes.PaymentIntent calldata intent)
        public
        view
        override
        returns (bytes32)
    {
        return _digest(keccak256(abi.encode(PAYMENT_INTENT_TYPEHASH, intent)));
    }

    function paymentIntentRevocationDigest(
        StreamPrimarySettlementTypes.PaymentIntentRevocation calldata revocation
    ) public view override returns (bytes32) {
        return _digest(keccak256(abi.encode(PAYMENT_INTENT_REVOCATION_TYPEHASH, revocation)));
    }

    function _digest(bytes32 hash) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                _DOMAIN_TYPEHASH,
                keccak256("6529StreamPaymentIntentVerifier"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, hash));
    }

    function revokePaymentIntent(bytes32 nonce) external override {
        _lock();
        _unused(msg.sender, nonce);
        _used[msg.sender][nonce] = true;
        emit PaymentIntentRevoked(msg.sender, nonce, 1);
        phase = Phase.IDLE;
    }

    function revokePaymentIntentWithSignature(
        StreamPrimarySettlementTypes.PaymentIntentRevocation calldata r,
        bytes calldata signature
    ) external override {
        _lock();
        _unused(r.payer, r.nonce);
        if (block.timestamp > r.deadline) revert PaymentIntentExpired(r.deadline);
        if (!_validSignature(r.payer, paymentIntentRevocationDigest(r), signature)) {
            revert InvalidPaymentSignature(r.payer);
        }
        _unused(r.payer, r.nonce);
        _used[r.payer][r.nonce] = true;
        emit PaymentIntentRevoked(r.payer, r.nonce, 1);
        phase = Phase.IDLE;
    }

    function eip712Domain()
        external
        view
        override
        returns (bytes1, string memory, string memory, uint256, address, bytes32, uint256[] memory)
    {
        return (
            0x0f,
            "6529StreamPaymentIntentVerifier",
            "1",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }
}
