// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamSaleFunding.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/standards/IERC20.sol";

/// @dev Exact existing escrow getter ABI; not a spending or arbitrary execution interface.
interface IStreamSaleEscrowBinding {
    function splitFactory() external view returns (address);
    function assetPolicyRegistry() external view returns (address);
    function factoryCodeHash() external view returns (bytes32);
    function walletCodeHash() external view returns (bytes32);
}

/// @notice Internal fixed-profile funding for current sale adapters.
/// @dev The embedding adapter owns its guard, authorization, preview and final mint comparison.
///      ERC20 payer pulls remain in that adapter's frame; only producer funds enter escrow.
abstract contract StreamSaleFunding is IStreamSaleFunding {
    bytes32 private constant _DEPOSIT_GAS = keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT");
    bytes32 private constant _ASSET_GAS = keccak256("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT");
    uint256 private constant _RETURN_RESERVE = 40_000;
    IStreamSplitFactory private immutable _fundingFactory;
    IStreamAssetPolicyRegistry private immutable _fundingAssets;
    bytes32 private immutable _fundingAssetCodeHash;
    bytes32 private immutable _fundingWalletCodeHash;
    IStreamRevenueEscrow public immutable override revenueEscrow;
    bytes32 public immutable override fundingFactoryCodeHash;
    bytes32 public immutable override fundingEscrowCodeHash;

    constructor(IStreamSplitFactory factory, IStreamRevenueEscrow escrow) {
        if (
            address(factory).code.length == 0 || address(escrow).code.length == 0
                || _isDelegated(address(factory)) || _isDelegated(address(escrow))
        ) {
            revert InvalidSaleFundingConfiguration();
        }
        IStreamSaleEscrowBinding binding = IStreamSaleEscrowBinding(address(escrow));
        IStreamAssetPolicyRegistry assets = factory.assetPolicyRegistry();
        bytes32 runtime = factory.splitWalletRuntimeCodeHash();
        if (
            binding.splitFactory() != address(factory)
                || binding.factoryCodeHash() != address(factory).codehash
                || binding.walletCodeHash() != runtime
                || binding.assetPolicyRegistry() != address(assets)
                || escrow.governanceAuthority() != factory.governanceAuthority()
                || address(assets).code.length == 0 || _isDelegated(address(assets))
                || factory.gasParameter(_DEPOSIT_GAS) == 0 || factory.gasParameter(_ASSET_GAS) == 0
        ) {
            revert InvalidSaleFundingConfiguration();
        }
        _fundingFactory = factory;
        _fundingAssets = assets;
        _fundingAssetCodeHash = address(assets).codehash;
        _fundingWalletCodeHash = runtime;
        revenueEscrow = escrow;
        fundingFactoryCodeHash = address(factory).codehash;
        fundingEscrowCodeHash = address(escrow).codehash;
    }

    function _requireFundingWallet(bytes32 profile, address wallet) internal view {
        _requireFundingBindings();
        if (
            _fundingFactory.walletFor(profile) != wallet
                || wallet.codehash != _fundingWalletCodeHash
                || !_fundingFactory.splitWalletExists(profile)
        ) revert SaleFundingProfileInvalid(profile, wallet);
    }

    function _fundNative(bytes32 revenueClass, bytes32 profile, address wallet, uint256 amount)
        internal
        returns (bool escrowed)
    {
        _requireFundingWallet(profile, wallet);
        if (amount == 0) return false;
        uint256 beforeBalance = address(this).balance;
        uint256 walletBefore = wallet.balance;
        uint256 cap = _fundingGas(_DEPOSIT_GAS);
        _requireFundingGas(cap);
        if (cap < 2300) revert InsufficientSaleFundingGas(cap, gasleft());
        uint256 forwarded = cap - 2300;
        bool ok;
        assembly ("memory-safe") { ok := call(forwarded, wallet, amount, 0, 0, 0, 0) }
        if (ok) {
            if (
                wallet.balance != walletBefore + amount
                    || address(this).balance != beforeBalance - amount
            ) {
                revert SaleFundingAmountMismatch(address(0));
            }
            return false;
        }
        // Failed CALL rolled all wallet-frame effects back before this alternate route.
        uint256 owed = revenueEscrow.escrowOwed(revenueClass, profile, wallet, address(0));
        uint256 escrowBefore = address(revenueEscrow).balance;
        revenueEscrow.creditNative{ value: amount }(revenueClass, profile, wallet, false);
        if (
            address(this).balance != beforeBalance - amount || wallet.balance != walletBefore
                || address(revenueEscrow).balance != escrowBefore + amount
                || revenueEscrow.escrowOwed(revenueClass, profile, wallet, address(0))
                    != owed + amount
        ) {
            revert SaleFundingEscrowMismatch(address(0));
        }
        return true;
    }

    function _fundERC20(
        address payer,
        bytes32 revenueClass,
        bytes32 profile,
        address wallet,
        address asset,
        uint256 amount
    ) internal returns (bool escrowed) {
        _requireFundingWallet(profile, wallet);
        uint256 cap = _fundingGas(_DEPOSIT_GAS);
        uint256 initial = _fundingBalance(asset, address(this), cap);
        uint256 payerBefore = _fundingBalance(asset, payer, cap);
        if (payerBefore < amount) revert SaleFundingAmountMismatch(asset);
        _fundingTokenCall(
            asset, abi.encodeCall(IERC20.transferFrom, (payer, address(this), amount)), cap, false
        );
        if (
            _fundingBalance(asset, payer, cap) != payerBefore - amount
                || _fundingBalance(asset, address(this), cap) != initial + amount
        ) {
            revert SaleFundingAmountMismatch(asset);
        }
        uint256 walletBefore = _fundingBalance(asset, wallet, cap);
        bool deposited =
            _fundingTokenCall(asset, abi.encodeCall(IERC20.transfer, (wallet, amount)), cap, true);
        if (deposited) {
            if (
                _fundingBalance(asset, wallet, cap) != walletBefore + amount
                    || _fundingBalance(asset, address(this), cap) != initial
            ) {
                revert SaleFundingAmountMismatch(asset);
            }
            return false;
        }
        // Only CALL failure reaches fallback. Successful false/malformed/no-op/fee behavior
        // reverts the whole purchase instead of preserving any partial wallet payment.
        _creditTokenEscrow(revenueClass, profile, wallet, asset, amount, cap);
        if (
            _fundingBalance(asset, address(this), cap) != initial
                || _fundingBalance(asset, wallet, cap) != walletBefore
        ) revert SaleFundingAmountMismatch(asset);
        return true;
    }

    function _creditTokenEscrow(
        bytes32 revenueClass,
        bytes32 profile,
        address wallet,
        address asset,
        uint256 amount,
        uint256 cap
    ) private {
        uint256 owed = revenueEscrow.escrowOwed(revenueClass, profile, wallet, asset);
        uint256 beforeBalance = _fundingBalance(asset, address(revenueEscrow), cap);
        _requireEscrowAllowance(asset, 0, cap);
        _fundingTokenCall(
            asset, abi.encodeCall(IERC20.approve, (address(revenueEscrow), amount)), cap, false
        );
        _requireEscrowAllowance(asset, amount, cap);
        revenueEscrow.creditERC20(revenueClass, profile, wallet, asset, amount, false);
        _requireEscrowAllowance(asset, 0, cap);
        if (
            _fundingBalance(asset, address(revenueEscrow), cap) != beforeBalance + amount
                || revenueEscrow.escrowOwed(revenueClass, profile, wallet, asset) != owed + amount
        ) {
            revert SaleFundingEscrowMismatch(asset);
        }
    }

    function _requireEscrowAllowance(address asset, uint256 expected, uint256 cap) private view {
        uint256 actual = _fundingRead(
            asset, abi.encodeCall(IERC20.allowance, (address(this), address(revenueEscrow))), cap
        );
        if (actual != expected) revert SaleFundingAllowanceMismatch(asset, actual, expected);
    }

    function _requireFundingAsset(address asset) internal view {
        _requireFundingBindings();
        if (asset.code.length == 0 || address(_fundingAssets).codehash != _fundingAssetCodeHash) {
            revert SaleFundingAssetInactive(asset);
        }
        uint256 status = _fundingRead(
            address(_fundingAssets),
            abi.encodeCall(IStreamAssetPolicyRegistry.assetStatus, (asset)),
            _fundingGas(_ASSET_GAS)
        );
        if (status != 1) revert SaleFundingAssetInactive(asset);
    }

    function _fundingGas(bytes32 id) private view returns (uint256) {
        _requireFundingBindings();
        uint256 value = _fundingFactory.gasParameter(id);
        if (value == 0) revert InvalidSaleFundingConfiguration();
        return value;
    }

    function _requireFundingBindings() private view {
        if (address(_fundingFactory).codehash != fundingFactoryCodeHash) {
            revert SaleFundingBindingChanged(address(_fundingFactory));
        }
        if (address(revenueEscrow).codehash != fundingEscrowCodeHash) {
            revert SaleFundingBindingChanged(address(revenueEscrow));
        }
    }

    function _requireFundingGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (
            cap > available
                || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + _RETURN_RESERVE
        ) {
            revert InsufficientSaleFundingGas(cap, available);
        }
    }

    function _fundingBalance(address asset, address account, uint256 cap)
        private
        view
        returns (uint256)
    {
        return _fundingRead(asset, abi.encodeCall(IERC20.balanceOf, (account)), cap);
    }

    function _fundingRead(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 word)
    {
        _requireFundingGas(cap);
        bool ok;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := staticcall(cap, target, add(data, 32), mload(data), ptr, 32)
            ok := and(ok, eq(returndatasize(), 32))
            word := mload(ptr)
        }
        // Casting to bytes4 reads an internally ABI-encoded selector.
        // forge-lint: disable-next-line(unsafe-typecast)
        if (!ok) revert SaleFundingTokenReadFailed(target, bytes4(data));
    }

    function _fundingTokenCall(
        address asset,
        bytes memory data,
        uint256 cap,
        bool mayRevertToEscrow
    ) private returns (bool) {
        _requireFundingGas(cap);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := call(cap, asset, 0, add(data, 32), mload(data), ptr, 32)
            size := returndatasize()
            word := mload(ptr)
        }
        if (!ok && mayRevertToEscrow) return false;
        // Casting to bytes4 reads an internally ABI-encoded selector.
        // forge-lint: disable-next-line(unsafe-typecast)
        if (!ok || size != 32 || word != 1) revert SaleFundingTokenCallFailed(asset, bytes4(data));
        return true;
    }

    function _isDelegated(address target) private view returns (bool) {
        if (target.code.length != 23) return false;
        uint256 prefix;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            extcodecopy(target, ptr, 0, 3)
            prefix := shr(232, mload(ptr))
        }
        return prefix == 0xef0100;
    }
}
