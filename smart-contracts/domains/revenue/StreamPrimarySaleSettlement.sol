// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSettlementContext.sol";
import "./StreamNativeSupplementalExecution.sol";
import "./StreamNativePrimaryExecution.sol";
import "./StreamPrimaryTokenRouting.sol";
import "./StreamPrimarySettlementValidation.sol";
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

/// @notice Official recorder for typed mint payments and native clearing supplemental revenue.
/// @dev Registered sale adapters call directly. The ERC20 path is funded only by its bound contract20;
///      native adapters supply exact value. No owner, payer allowance or arbitrary transfer route.
contract StreamPrimarySaleSettlement is
    IStreamPrimarySaleSettlement,
    IStreamNativePrimarySaleSettlement,
    IStreamDeferredNativePrimarySaleSettlement,
    IStreamNativeSupplementalSettlement,
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
    mapping(bytes32 => bool) public supplementalPurchaseConsumed;
    mapping(bytes32 => bool) public supplementalFloorConsumed;
    mapping(bytes32 => StreamNativeSupplementalTypes.NativeSupplementalResult) private
        _supplementalResults;

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
            || id == type(IStreamNativeSupplementalSettlement).interfaceId
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
        bool escrowed = StreamNativePrimaryExecution.fund(
            StreamNativePrimaryExecution.Context(
                _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
            ),
            c.sale.collectionId,
            c.sale.amount,
            selected
        );
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
        bool escrowed = StreamNativePrimaryExecution.fund(
            StreamNativePrimaryExecution.Context(
                _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
            ),
            c.sale.collectionId,
            c.sale.amount,
            selected
        );
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

    function supplementalPurchaseKey(address adapter, bytes32 id) public view returns (bytes32) {
        return StreamNativeSupplementalHash.purchaseKey(address(this), adapter, id);
    }

    function supplementalFloorKey(bytes32 originalKey) public view returns (bytes32) {
        return StreamNativeSupplementalHash.floorKey(address(this), originalKey);
    }

    function nativeSupplementalResult(bytes32 key)
        external
        view
        override
        returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory)
    {
        return _supplementalResults[key];
    }

    function settleNativeSupplementalRevenueFromAdapter(
        StreamNativeSupplementalTypes.NativeSupplementalCandidate calldata candidate
    )
        external
        payable
        override
        nonReentrant
        returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory result)
    {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = candidate;
        if (msg.sender != c.originalFloor.saleAdapter) {
            revert InvalidNativeSupplementalSettlement();
        }
        bytes32 purchaseKey = supplementalPurchaseKey(c.originalFloor.saleAdapter, c.purchaseId);
        if (supplementalPurchaseConsumed[purchaseKey]) {
            revert SupplementalPurchaseAlreadyConsumed(purchaseKey);
        }
        bytes32 floorKey = supplementalFloorKey(c.purchase.floorSettlementKey);
        if (supplementalFloorConsumed[floorKey]) revert SupplementalFloorAlreadyConsumed(floorKey);
        bytes32 key = settlementKey(
            c.originalFloor.saleAdapter, StreamNativeSupplementalHash.executionId(address(this), c)
        );
        if (settlementConsumed[key]) revert SettlementAlreadyConsumed(key);
        _requireNativeContext();
        if (!settlementConsumed[c.purchase.floorSettlementKey]) {
            revert InvalidNativeSupplementalSettlement();
        }
        StreamDeferredNativeSettlementValidation.Bindings memory bindings =
            StreamDeferredNativeSettlementValidation.Bindings(
                core, moduleRegistry, address(revenueResolver), address(revenueEscrow)
            );
        uint256 amount = StreamNativeSupplementalValidation.validate(
            bindings, c, _results[c.purchase.floorSettlementKey]
        );
        supplementalPurchaseConsumed[purchaseKey] = true;
        supplementalFloorConsumed[floorKey] = true;
        settlementConsumed[key] = true;
        result = StreamNativeSupplementalExecution.fund(
            StreamNativeSupplementalExecution.Context(
                _rightsContext(), revenueEscrow, escrowCodeHash, factoryCodeHash
            ),
            c,
            key,
            amount
        );
        _requireNativeContext();
        StreamNativeSupplementalValidation.requireCurrent(bindings, c);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory common =
            StreamNativeSupplementalExecution.commonResult(c, result);
        _results[key] = common;
        _supplementalResults[key] = result;
        _officialSettled[_totalKey(_CLASS, result.profileId, result.wallet, address(0))] += amount;
        totalOfficialSettled[address(0)] += amount;
        StreamNativeSupplementalExecution.emitResult(c, result, common);
    }

    function _validateNative(StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
        private
        view
    {
        StreamPrimarySettlementValidation.nativeFields(_validationBindings(), c);
        _requireNativeContext();
        StreamNativeSettlementAdmission.requireAdmission(moduleRegistry, c);
        StreamPrimarySettlementValidation.nativeBindings(_validationBindings(), c);
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
        StreamPrimarySettlementValidation.erc20Fields(_validationBindings(), paymentAdapter, c);
        _requireContext();
        _requireActive(c.asset);
        StreamSettlementAdmission.requireAdmission(moduleRegistry, paymentAdapter, c);
        StreamPrimarySettlementValidation.erc20Bindings(_validationBindings(), paymentAdapter, c);
    }

    function _validationBindings()
        private
        view
        returns (StreamPrimarySettlementValidation.Bindings memory)
    {
        return StreamPrimarySettlementValidation.Bindings(
            core, moduleRegistry, address(revenueResolver), address(revenueEscrow)
        );
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
    ) private returns (bool) {
        return StreamPrimaryTokenRouting.route(
            StreamPrimaryTokenRouting.Context(_rightsContext(), revenueEscrow, escrowCodeHash),
            c,
            rights,
            cap
        );
    }

    function _totalKey(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_TOTAL, revenueClass, profileId, wallet, asset));
    }
}
