// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSettlementContext.sol";
import "./StreamPrimarySettlementHash.sol";
import "./StreamNativeSettlementHash.sol";
import "./StreamNativeSettlementAdmission.sol";
import "./StreamNativeSettlementSupport.sol";
import "./StreamPrimarySettlementEmission.sol";
import "./StreamPrimarySettlementRights.sol";
import "./StreamDeferredNativeSettlementValidation.sol";
import "../../interfaces/stream/revenue/IStreamDeferredNativePrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamNativePrimarySaleSettlement.sol";
import "../mint/StreamSaleTemplate.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../../vendor/openzeppelin/ERC165.sol";

/// @notice Shared official recorder for typed native and ERC20 single-step profiles.
/// @dev Registered sale adapters call directly. The ERC20 path is funded only by its bound contract20;
///      native adapters supply exact value. No owner, payer allowance or arbitrary transfer route.
contract StreamPrimarySaleSettlement is
    IStreamPrimarySaleSettlement,
    IStreamNativePrimarySaleSettlement,
    IStreamDeferredNativePrimarySaleSettlement,
    StreamSettlementContext,
    ReentrancyGuard,
    ERC165
{
    // Retain decoding for the same error now bubbled through the linked rights helper.
    error UnsupportedSaleTemplate();

    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant _TOTAL = keccak256("6529STREAM_OFFICIAL_PRIMARY_SETTLED_V1");
    IStreamRevenueEscrow public immutable override revenueEscrow;
    bytes32 public immutable escrowCodeHash;
    bytes32 public immutable walletCodeHash;
    mapping(bytes32 => bool) public override settlementConsumed;
    mapping(bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult) private _results;
    mapping(bytes32 => uint256) private _officialSettled;
    mapping(address => uint256) public override totalOfficialSettled;
    mapping(bytes32 => bool) public deferredPurchaseConsumed;

    constructor(IStreamRevenueResolver resolver, address registry, IStreamRevenueEscrow escrow)
        StreamSettlementContext(resolver, registry)
    {
        if (
            !StreamSettlementAdmission.isContract(address(escrow))
                || _read(address(escrow), abi.encodeWithSignature("splitFactory()"), gasleft())
                    != uint256(uint160(address(splitFactory)))
                || _read(
                        address(escrow), abi.encodeWithSignature("assetPolicyRegistry()"), gasleft()
                    ) != uint256(uint160(address(assetPolicyRegistry)))
                || _read(address(escrow), abi.encodeWithSignature("factoryCodeHash()"), gasleft())
                    != uint256(factoryCodeHash)
                || escrow.governanceAuthority() != splitFactory.governanceAuthority()
        ) revert InvalidSettlementContext(address(escrow));
        revenueEscrow = escrow;
        escrowCodeHash = address(escrow).codehash;
        walletCodeHash = splitFactory.splitWalletRuntimeCodeHash();
        if (
            _read(address(escrow), abi.encodeWithSignature("walletCodeHash()"), gasleft())
                != uint256(walletCodeHash)
        ) {
            revert InvalidSettlementContext(address(escrow));
        }
    }

    function isStreamPrimarySaleSettlement() external pure override returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamPrimarySaleSettlement).interfaceId
            || id == type(IStreamNativePrimarySaleSettlement).interfaceId
            || id == type(IStreamDeferredNativePrimarySaleSettlement).interfaceId
            || super.supportsInterface(id);
    }

    function settlementKey(address saleAdapter, bytes32 executionId)
        public
        view
        override
        returns (bytes32)
    {
        return StreamPrimarySettlementHash.settlementKey(address(this), saleAdapter, executionId);
    }

    function settlementResult(bytes32 key)
        external
        view
        override
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory)
    {
        return _results[key];
    }

    function officialSettled(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        external
        view
        override
        returns (uint256)
    {
        return _officialSettled[_totalKey(revenueClass, profileId, wallet, asset)];
    }

    function settleERC20PrimarySaleFromAdapter(
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate
    )
        external
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c = candidate;
        _validate(paymentAdapter, c);
        bytes32 key = settlementKey(c.saleAdapter, c.executionBinding.executionId);
        if (settlementConsumed[key]) revert SettlementAlreadyConsumed(key);
        StreamSaleTemplate.Selection memory rights = _resolve(c);
        StreamSaleTemplate.materialize(revenueResolver, c.sale.collectionId, rights);
        _requireWallet(rights);
        settlementConsumed[key] = true;
        uint256 cap = _gas(_DEPOSIT_GAS);
        uint256 original = _balance(c.asset, address(this), cap);
        bytes32 commitment =
            StreamPrimarySettlementHash.candidateCommitment(paymentAdapter, address(this), c);
        IStreamERC20PrimarySettlementAdapter(paymentAdapter)
            .fundERC20PrimarySale(commitment, key, c.asset, c.sale.amount);
        if (_balance(c.asset, address(this), cap) != original + c.sale.amount) {
            revert SettlementAmountMismatch(c.asset);
        }
        _requireContext();
        _requireActive(c.asset);
        StreamSettlementAdmission.requireAdmission(moduleRegistry, paymentAdapter, c);
        _requireCurrent(c, rights);
        bool escrowed = _route(c, rights, cap);
        if (_balance(c.asset, address(this), cap) != original) {
            revert SettlementAmountMismatch(c.asset);
        }
        _requireContext();
        _requireActive(c.asset);
        StreamSettlementAdmission.requireAdmission(moduleRegistry, paymentAdapter, c);
        _requireCurrent(c, rights);
        result = StreamPrimarySettlementTypes.PrimarySettlementResult(
            commitment,
            key,
            rights.profileId,
            rights.wallet,
            c.asset,
            c.sale.amount,
            c.executor,
            c.executionBinding.executionId,
            escrowed,
            c.operationIdentityCommitment,
            c.currentPolicyHash,
            c.boundPolicyHash
        );
        _results[key] = result;
        _officialSettled[
            _totalKey(c.sale.revenueClass, rights.profileId, rights.wallet, c.asset)
        ] += c.sale.amount;
        totalOfficialSettled[c.asset] += c.sale.amount;
        StreamPrimarySettlementEmission.emitSettlement(
            c, result, paymentAdapter, c.sale.expectedPrimaryPolicyHash
        );
    }

    function settleNativePrimarySaleFromAdapter(
        StreamNativeSettlementTypes.NativeSettlementCandidate calldata candidate
    )
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        StreamNativeSettlementTypes.NativeSettlementCandidate memory n = candidate;
        _validateNative(n);
        bytes32 key = settlementKey(n.saleAdapter, n.executionBinding.executionId);
        if (settlementConsumed[key]) revert SettlementAlreadyConsumed(key);
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c =
            StreamNativeSettlementHash.accountingContext(n);
        StreamSaleTemplate.Selection memory selected = _resolve(c);
        settlementConsumed[key] = true;
        uint256 original = address(this).balance - msg.value;
        StreamSaleTemplate.materialize(revenueResolver, c.sale.collectionId, selected);
        _requireWallet(selected);
        bool escrowed = StreamNativeSettlementSupport.fundNative(
            revenueEscrow,
            escrowCodeHash,
            selected,
            c.sale.amount,
            StreamNativeSettlementSupport.gasParameter(splitFactory, factoryCodeHash, _DEPOSIT_GAS)
        );
        if (address(this).balance != original) revert SettlementAmountMismatch(address(0));
        _requireNativeContext();
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, n);
        _requireCurrent(c, selected);
        result = StreamPrimarySettlementTypes.PrimarySettlementResult(
            StreamNativeSettlementHash.candidateCommitment(address(this), n),
            key,
            selected.profileId,
            selected.wallet,
            address(0),
            c.sale.amount,
            c.executor,
            c.executionBinding.executionId,
            escrowed,
            c.operationIdentityCommitment,
            c.currentPolicyHash,
            c.boundPolicyHash
        );
        _results[key] = result;
        _officialSettled[
            _totalKey(_CLASS, selected.profileId, selected.wallet, address(0))
        ] += c.sale.amount;
        totalOfficialSettled[address(0)] += c.sale.amount;
        StreamPrimarySettlementEmission.emitSettlement(
            c, result, address(0), c.sale.expectedPrimaryPolicyHash
        );
    }

    function deferredPurchaseKey(address adapter, bytes32 purchaseId)
        public
        view
        returns (bytes32)
    {
        return StreamDeferredNativeSettlementHash.purchaseKey(address(this), adapter, purchaseId);
    }

    function settleDeferredNativePrimarySaleFromAdapter(
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate calldata candidate
    )
        external
        payable
        override
        nonReentrant
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d = candidate;
        _requireNativeContext();
        StreamDeferredNativeSettlementValidation.validate(
            StreamDeferredNativeSettlementValidation.Bindings(
                core, moduleRegistry, address(revenueResolver), address(revenueEscrow)
            ),
            d
        );
        bytes32 purchaseKey = deferredPurchaseKey(d.execution.saleAdapter, d.purchaseId);
        if (deferredPurchaseConsumed[purchaseKey]) revert SettlementAlreadyConsumed(purchaseKey);
        bytes32 key =
            settlementKey(d.execution.saleAdapter, d.execution.executionBinding.executionId);
        if (settlementConsumed[key]) revert SettlementAlreadyConsumed(key);
        deferredPurchaseConsumed[purchaseKey] = true;
        settlementConsumed[key] = true;
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c =
            StreamNativeSettlementHash.accountingContext(d.execution);
        StreamSaleTemplate.Selection memory selected = _resolve(c);
        uint256 original = address(this).balance - msg.value;
        StreamSaleTemplate.materialize(revenueResolver, c.sale.collectionId, selected);
        _requireWallet(selected);
        bool escrowed = StreamNativeSettlementSupport.fundNative(
            revenueEscrow,
            escrowCodeHash,
            selected,
            c.sale.amount,
            StreamNativeSettlementSupport.gasParameter(splitFactory, factoryCodeHash, _DEPOSIT_GAS)
        );
        if (address(this).balance != original) revert SettlementAmountMismatch(address(0));
        _requireNativeContext();
        StreamDeferredNativeSettlementAdmission.requireAdmission(moduleRegistry, d.execution);
        _requireCurrent(c, selected);
        result = StreamPrimarySettlementTypes.PrimarySettlementResult(
            StreamDeferredNativeSettlementHash.candidateCommitment(address(this), d),
            key,
            selected.profileId,
            selected.wallet,
            address(0),
            c.sale.amount,
            c.executor,
            c.executionBinding.executionId,
            escrowed,
            c.operationIdentityCommitment,
            c.currentPolicyHash,
            c.boundPolicyHash
        );
        _results[key] = result;
        _officialSettled[
            _totalKey(_CLASS, selected.profileId, selected.wallet, address(0))
        ] += c.sale.amount;
        totalOfficialSettled[address(0)] += c.sale.amount;
        StreamPrimarySettlementEmission.emitSettlement(
            c, result, address(0), d.originalPrimaryPolicyHash
        );
    }

    function _validateNative(StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
        private
        view
    {
        if (
            msg.sender != c.saleAdapter || c.saleAdapter == address(0) || c.executor == address(0)
                || c.sale.settlementId == 0 || c.sale.revenueClass != _CLASS
                || c.sale.policyMode != 0 || c.sale.collectionId == 0 || c.sale.tokenId != 0
                || c.sale.saleNonce == 0 || c.sale.payer == address(0)
                || c.sale.payer == address(this) || c.sale.payer == c.saleAdapter
                || c.sale.payer == c.rights.wallet || c.sale.payer == address(revenueEscrow)
                || c.sale.payer != c.executor || c.sale.beneficiary == address(0)
                || c.sale.amount == 0 || msg.value != c.sale.amount
                || c.sale.expectedPrimaryPolicyHash == 0 || c.orchestrationOrder != 1
                || c.executionBinding.authorityMode != 1 || c.executionBinding.executionNonce == 0
                || c.executionBinding.saleAuthorizationDigest == 0
                || c.operationIdentityCommitment == 0 || c.operationId == 0
                || c.currentPolicyHash == 0 || c.boundPolicyHash == 0 || c.saleExecutionHash == 0
                || c.executionBinding.executionId != StreamNativeSettlementHash.executionId(c)
        ) revert InvalidPrimarySale();
        _requireNativeContext();
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
        if (
            _read(c.saleAdapter, abi.encodeWithSignature("primarySaleSettlement()"), gasleft())
                    != uint256(uint160(address(this)))
                || _read(c.saleAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(core))
                || _read(c.saleAdapter, abi.encodeWithSignature("moduleRegistry()"), gasleft())
                    != uint256(uint160(moduleRegistry))
                || _read(c.saleAdapter, abi.encodeWithSignature("revenueResolver()"), gasleft())
                    != uint256(uint160(address(revenueResolver)))
                || _read(c.saleAdapter, abi.encodeWithSignature("mintManager()"), gasleft())
                    != uint256(uint160(c.mintManager))
                || !StreamSettlementAdmission.isContract(c.mintManager)
                || _read(c.mintManager, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(core))
                || _read(c.mintManager, abi.encodeWithSignature("moduleRegistry()"), gasleft())
                    != uint256(uint160(moduleRegistry))
        ) revert InvalidPrimarySale();
    }

    /// @dev Native payments do not consult ERC20 status or permit-policy availability.
    function _requireNativeContext() private view {
        StreamSettlementAdmission.requireRegistry(
            core, coreCodeHash, moduleRegistry, moduleRegistryCodeHash
        );
        if (address(revenueResolver).codehash != resolverCodeHash) {
            revert InvalidSettlementContext(address(revenueResolver));
        }
        if (address(splitFactory).codehash != factoryCodeHash) {
            revert InvalidSettlementContext(address(splitFactory));
        }
    }

    function _validate(
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view {
        if (
            msg.sender != c.saleAdapter || c.saleAdapter == address(0) || c.executor == address(0)
                || c.sale.settlementId == 0 || c.sale.revenueClass != _CLASS
                || c.sale.policyMode != 0 || c.sale.collectionId == 0 || c.sale.tokenId != 0
                || c.sale.saleNonce == 0 || c.sale.payer == address(0)
                || c.sale.payer == address(this) || c.sale.payer == paymentAdapter
                || c.sale.payer == c.rights.wallet || c.sale.payer == address(revenueEscrow)
                || c.sale.beneficiary == address(0) || c.sale.amount == 0
                || c.sale.expectedPrimaryPolicyHash == 0 || c.orchestrationOrder != 1
                || c.executionBinding.authorityMode != 1 || c.executionBinding.executionNonce == 0
                || c.executionBinding.saleAuthorizationDigest == 0
                || c.operationIdentityCommitment == 0 || c.operationId == 0
                || c.currentPolicyHash == 0 || c.boundPolicyHash == 0 || c.saleExecutionHash == 0
                || c.executionBinding.executionId != StreamPrimarySettlementHash.executionId(c)
        ) {
            revert InvalidPrimarySale();
        }
        _requireContext();
        _requireActive(c.asset);
        StreamSettlementAdmission.requireAdmission(moduleRegistry, paymentAdapter, c);
        if (
            _read(paymentAdapter, abi.encodeWithSignature("primarySaleSettlement()"), gasleft())
                    != uint256(uint160(address(this)))
                || _read(paymentAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(core))
                || _read(paymentAdapter, abi.encodeWithSignature("moduleRegistry()"), gasleft())
                    != uint256(uint160(moduleRegistry))
                || _read(paymentAdapter, abi.encodeWithSignature("revenueResolver()"), gasleft())
                    != uint256(uint160(address(revenueResolver)))
                || _read(
                        c.saleAdapter, abi.encodeWithSignature("primarySaleSettlement()"), gasleft()
                    ) != uint256(uint160(address(this)))
                || _read(c.saleAdapter, abi.encodeWithSignature("core()"), gasleft())
                    != uint256(uint160(core))
                || _read(c.saleAdapter, abi.encodeWithSignature("mintManager()"), gasleft())
                    != uint256(uint160(c.mintManager))
        ) {
            revert PrimarySettlementPaymentBindingInvalid(paymentAdapter);
        }
    }

    function _rightsContext() private view returns (StreamPrimarySettlementRights.Context memory) {
        return StreamPrimarySettlementRights.Context(revenueResolver, splitFactory, walletCodeHash);
    }

    function _resolve(StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
        private
        view
        returns (StreamSaleTemplate.Selection memory)
    {
        return StreamPrimarySettlementRights.resolve(
            _rightsContext(), c.sale.collectionId, c.rights, c.sale.expectedPrimaryPolicyHash
        );
    }

    function _requireCurrent(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamSaleTemplate.Selection memory rights
    ) private view {
        StreamPrimarySettlementRights.requireCurrent(
            _rightsContext(),
            c.sale.collectionId,
            c.rights,
            c.sale.expectedPrimaryPolicyHash,
            rights
        );
    }

    function _requireWallet(StreamSaleTemplate.Selection memory rights) private view {
        StreamPrimarySettlementRights.requireWallet(_rightsContext(), rights);
    }

    function _route(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamSaleTemplate.Selection memory rights,
        uint256 cap
    ) private returns (bool escrowed) {
        _requireWallet(rights);
        if (
            rights.wallet.code.length != 0
                && _transfer(c.asset, rights.wallet, c.sale.amount, cap, true)
        ) return false;
        if (address(revenueEscrow).codehash != escrowCodeHash) {
            revert InvalidSettlementContext(address(revenueEscrow));
        }
        uint256 beforeEscrow = _balance(c.asset, address(revenueEscrow), cap);
        uint256 beforeWallet = _balance(c.asset, rights.wallet, cap);
        uint256 owed = revenueEscrow.escrowOwed(_CLASS, rights.profileId, rights.wallet, c.asset);
        if (_allowance(c.asset, address(this), address(revenueEscrow), cap) != 0) {
            revert PrimarySettlementEscrowMismatch();
        }
        _tokenCall(
            c.asset,
            abi.encodeCall(IERC20.approve, (address(revenueEscrow), c.sale.amount)),
            cap,
            false
        );
        if (_allowance(c.asset, address(this), address(revenueEscrow), cap) != c.sale.amount) {
            revert PrimarySettlementEscrowMismatch();
        }
        revenueEscrow.creditERC20(
            _CLASS, rights.profileId, rights.wallet, c.asset, c.sale.amount, rights.templateId != 0
        );
        if (
            _allowance(c.asset, address(this), address(revenueEscrow), cap) != 0
                || _balance(c.asset, address(revenueEscrow), cap) != beforeEscrow + c.sale.amount
                || _balance(c.asset, rights.wallet, cap) != beforeWallet
                || revenueEscrow.escrowOwed(_CLASS, rights.profileId, rights.wallet, c.asset)
                    != owed + c.sale.amount
        ) {
            revert PrimarySettlementEscrowMismatch();
        }
        return true;
    }

    function _totalKey(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_TOTAL, revenueClass, profileId, wallet, asset));
    }
}
