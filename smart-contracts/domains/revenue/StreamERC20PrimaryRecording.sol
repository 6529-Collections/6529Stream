// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimaryTokenRouting.sol";
import "./StreamPrimarySettlementValidation.sol";
import "./StreamPrimarySettlementHash.sol";
import "./StreamPrimarySettlementEmission.sol";
import "./StreamSettlementContext.sol";

/// @notice Original ERC20 recording through a fixed compiler link in the recorder context.
/// @dev Explicit storage references retain replay, funding, result and event order.
/// The host retains its existing public nonReentrant boundary and completes it normally.
library StreamERC20PrimaryRecording {
    bytes32 private constant _DEPOSIT_GAS = keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT");
    bytes32 private constant _ASSET_GAS = keccak256("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT");
    bytes32 private constant _TOTAL = keccak256("6529STREAM_OFFICIAL_PRIMARY_SETTLED_V1");

    struct Context {
        address core;
        address moduleRegistry;
        IStreamRevenueResolver revenueResolver;
        IStreamSplitFactory splitFactory;
        IStreamAssetPolicyRegistry assetPolicyRegistry;
        bytes32 coreCodeHash;
        bytes32 moduleRegistryCodeHash;
        bytes32 resolverCodeHash;
        bytes32 factoryCodeHash;
        bytes32 assetRegistryCodeHash;
        IStreamRevenueEscrow revenueEscrow;
        bytes32 escrowCodeHash;
        bytes32 walletCodeHash;
    }

    function execute(
        Context memory x,
        mapping(bytes32 => bool) storage settlementConsumed,
        mapping(bytes32 => StreamPrimarySettlementTypes.PrimarySettlementResult) storage results,
        mapping(bytes32 => uint256) storage officialSettled,
        mapping(address => uint256) storage totals,
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c = candidate;
        _validate(x, paymentAdapter, c);
        bytes32 key = StreamPrimarySettlementHash.settlementKey(
            address(this), c.saleAdapter, c.executionBinding.executionId
        );
        if (settlementConsumed[key]) {
            revert IStreamPrimarySaleSettlement.SettlementAlreadyConsumed(key);
        }
        StreamSaleTemplate.Selection memory rights = _resolve(x, c);
        StreamSaleTemplate.materialize(x.revenueResolver, c.sale.collectionId, rights);
        _requireWallet(x, rights);
        settlementConsumed[key] = true;
        uint256 cap = _gas(x, _DEPOSIT_GAS);
        uint256 original = _balance(c.asset, address(this), cap);
        bytes32 commitment =
            StreamPrimarySettlementHash.candidateCommitment(paymentAdapter, address(this), c);
        IStreamERC20PrimarySettlementAdapter(paymentAdapter)
            .fundERC20PrimarySale(commitment, key, c.asset, c.sale.amount);
        if (_balance(c.asset, address(this), cap) != original + c.sale.amount) {
            revert StreamSettlementContext.SettlementAmountMismatch(c.asset);
        }
        _requireContext(x);
        _requireActive(x, c.asset);
        StreamSettlementAdmission.requireAdmission(x.moduleRegistry, paymentAdapter, c);
        _requireCurrent(x, c, rights);
        bool escrowed = _route(x, c, rights, cap);
        if (_balance(c.asset, address(this), cap) != original) {
            revert StreamSettlementContext.SettlementAmountMismatch(c.asset);
        }
        _requireContext(x);
        _requireActive(x, c.asset);
        StreamSettlementAdmission.requireAdmission(x.moduleRegistry, paymentAdapter, c);
        _requireCurrent(x, c, rights);
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
        results[key] = result;
        officialSettled[
            _totalKey(c.sale.revenueClass, rights.profileId, rights.wallet, c.asset)
        ] += c.sale.amount;
        totals[c.asset] += c.sale.amount;
        StreamPrimarySettlementEmission.emitSettlement(
            c, result, paymentAdapter, c.sale.expectedPrimaryPolicyHash
        );
    }

    function _validate(
        Context memory x,
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view {
        StreamPrimarySettlementValidation.erc20Fields(_validationBindings(x), paymentAdapter, c);
        _requireContext(x);
        _requireActive(x, c.asset);
        StreamSettlementAdmission.requireAdmission(x.moduleRegistry, paymentAdapter, c);
        StreamPrimarySettlementValidation.erc20Bindings(_validationBindings(x), paymentAdapter, c);
    }

    function _validationBindings(Context memory x)
        private
        view
        returns (StreamPrimarySettlementValidation.Bindings memory)
    {
        return StreamPrimarySettlementValidation.Bindings(
            x.core, x.moduleRegistry, address(x.revenueResolver), address(x.revenueEscrow)
        );
    }

    function _rightsContext(Context memory x)
        private
        view
        returns (StreamPrimarySettlementRights.Context memory)
    {
        return StreamPrimarySettlementRights.Context(
            x.revenueResolver, x.splitFactory, x.walletCodeHash
        );
    }

    function _resolve(
        Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view returns (StreamSaleTemplate.Selection memory) {
        return StreamPrimarySettlementRights.resolve(
            _rightsContext(x), c.sale.collectionId, c.rights, c.sale.expectedPrimaryPolicyHash
        );
    }

    function _requireCurrent(
        Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamSaleTemplate.Selection memory rights
    ) private view {
        StreamPrimarySettlementRights.requireCurrent(
            _rightsContext(x),
            c.sale.collectionId,
            c.rights,
            c.sale.expectedPrimaryPolicyHash,
            rights
        );
    }

    function _requireWallet(Context memory x, StreamSaleTemplate.Selection memory rights)
        private
        view
    {
        StreamPrimarySettlementRights.requireWallet(_rightsContext(x), rights);
    }

    function _route(
        Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamSaleTemplate.Selection memory rights,
        uint256 cap
    ) private returns (bool) {
        return StreamPrimaryTokenRouting.route(
            StreamPrimaryTokenRouting.Context(_rightsContext(x), x.revenueEscrow, x.escrowCodeHash),
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

    function _requireContext(Context memory x) private view {
        StreamSettlementAdmission.requireRegistry(
            x.core, x.coreCodeHash, x.moduleRegistry, x.moduleRegistryCodeHash
        );
        if (address(x.revenueResolver).codehash != x.resolverCodeHash) {
            revert StreamSettlementContext.InvalidSettlementContext(address(x.revenueResolver));
        }
        _requireAssetBindings(x);
    }

    function _requireAssetBindings(Context memory x) private view {
        if (address(x.splitFactory).codehash != x.factoryCodeHash) {
            revert StreamSettlementContext.InvalidSettlementContext(address(x.splitFactory));
        }
        if (address(x.assetPolicyRegistry).codehash != x.assetRegistryCodeHash) {
            revert StreamSettlementContext.InvalidSettlementContext(address(x.assetPolicyRegistry));
        }
    }

    function _gas(Context memory x, bytes32 id) private view returns (uint256 cap) {
        _requireAssetBindings(x);
        // Exact-code trusted factory is the canonical repricing host; no cached fallback cap.
        cap = _read(
            address(x.splitFactory),
            abi.encodeCall(IStreamGasParameterHost.gasParameter, (id)),
            gasleft()
        );
        if (cap == 0 || cap > type(uint64).max) {
            revert StreamSettlementContext.InvalidSettlementContext(address(x.splitFactory));
        }
    }

    function _requireActive(Context memory x, address asset) private view {
        _requireAssetBindings(x);
        uint256 cap = _gas(x, _ASSET_GAS);
        _admitGas(cap);
        if (
            !StreamSettlementAdmission.isContract(asset)
                || _read(
                        address(x.assetPolicyRegistry),
                        abi.encodeCall(IStreamAssetPolicyRegistry.assetStatus, (asset)),
                        cap
                    ) != 1
        ) {
            revert StreamSettlementContext.SettlementAssetNotActive(asset);
        }
    }

    function _admitGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 40_000) {
            revert StreamSettlementContext.InsufficientSettlementCallGas(cap);
        }
    }

    function _read(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 word)
    {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) {
            revert StreamSettlementContext.SettlementReadFailed(target, bytes4(data));
        }
    }

    function _tokenRead(address asset, bytes memory data, uint256 cap)
        private
        view
        returns (uint256)
    {
        _admitGas(cap);
        return _read(asset, data, cap);
    }

    function _balance(address asset, address account, uint256 cap) private view returns (uint256) {
        return _tokenRead(asset, abi.encodeCall(IERC20.balanceOf, (account)), cap);
    }
}
