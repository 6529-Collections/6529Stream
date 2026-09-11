// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSettlementAdmission.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySettlementBindings.sol";
import "../../interfaces/standards/IERC20.sol";

/// @notice Pinned context and bounded exact token operations for universal settlement.
abstract contract StreamSettlementContext is IStreamPrimarySettlementBindings {
    bytes32 internal constant _DEPOSIT_GAS = keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT");
    bytes32 internal constant _ASSET_GAS = keccak256("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT");
    bytes32 internal constant _SIGNATURE_GAS = keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT");
    address public immutable override core;
    address public immutable override moduleRegistry;
    IStreamRevenueResolver public immutable override revenueResolver;
    IStreamSplitFactory public immutable override splitFactory;
    IStreamAssetPolicyRegistry public immutable override assetPolicyRegistry;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable moduleRegistryCodeHash;
    bytes32 public immutable resolverCodeHash;
    bytes32 public immutable factoryCodeHash;
    bytes32 public immutable assetRegistryCodeHash;

    error InvalidSettlementContext(address target);
    error InsufficientSettlementCallGas(uint256 requiredCap);
    error SettlementReadFailed(address target, bytes4 selector);
    error SettlementTokenCallFailed(address target, bytes4 selector);
    error SettlementAssetNotActive(address asset);
    error SettlementAmountMismatch(address asset);

    constructor(IStreamRevenueResolver resolver, address registry) {
        if (
            !StreamSettlementAdmission.isContract(address(resolver))
                || !resolver.isStreamRevenueResolver()
        ) {
            revert InvalidSettlementContext(address(resolver));
        }
        address core_ = resolver.core();
        IStreamSplitFactory factory = IStreamSplitFactory(resolver.splitFactory());
        if (
            !StreamSettlementAdmission.isContract(core_)
                || !StreamSettlementAdmission.isContract(registry)
                || !StreamSettlementAdmission.isContract(address(factory))
        ) revert InvalidSettlementContext(registry);
        IStreamAssetPolicyRegistry assets = factory.assetPolicyRegistry();
        if (
            !StreamSettlementAdmission.isContract(address(assets))
                || assets.governanceAuthority() != factory.governanceAuthority()
                || resolver.coreCodeHash() != core_.codehash
        ) revert InvalidSettlementContext(address(assets));
        // Canonical registry and factory must share the same actual governance executor.
        uint256 authority =
            _read(registry, abi.encodeWithSignature("governanceExecutor()"), gasleft());
        if (authority != uint256(uint160(factory.governanceAuthority()))) {
            revert InvalidSettlementContext(registry);
        }
        core = core_;
        moduleRegistry = registry;
        revenueResolver = resolver;
        splitFactory = factory;
        assetPolicyRegistry = assets;
        coreCodeHash = core_.codehash;
        moduleRegistryCodeHash = registry.codehash;
        resolverCodeHash = address(resolver).codehash;
        factoryCodeHash = address(factory).codehash;
        assetRegistryCodeHash = address(assets).codehash;
    }

    function _requireContext() internal view {
        StreamSettlementAdmission.requireRegistry(
            core, coreCodeHash, moduleRegistry, moduleRegistryCodeHash
        );
        if (address(revenueResolver).codehash != resolverCodeHash) {
            revert InvalidSettlementContext(address(revenueResolver));
        }
        _requireAssetBindings();
    }

    function _requireAssetBindings() internal view {
        if (address(splitFactory).codehash != factoryCodeHash) {
            revert InvalidSettlementContext(address(splitFactory));
        }
        if (address(assetPolicyRegistry).codehash != assetRegistryCodeHash) {
            revert InvalidSettlementContext(address(assetPolicyRegistry));
        }
    }

    function _gas(bytes32 id) internal view returns (uint256 cap) {
        _requireAssetBindings();
        // Exact-code trusted factory is the canonical repricing host; no cached fallback cap.
        cap = _read(
            address(splitFactory),
            abi.encodeCall(IStreamGasParameterHost.gasParameter, (id)),
            gasleft()
        );
        if (cap == 0 || cap > type(uint64).max) {
            revert InvalidSettlementContext(address(splitFactory));
        }
    }

    function _requireActive(address asset) internal view {
        _requireAssetBindings();
        uint256 cap = _gas(_ASSET_GAS);
        _admitGas(cap);
        if (
            !StreamSettlementAdmission.isContract(asset)
                || _read(
                        address(assetPolicyRegistry),
                        abi.encodeCall(IStreamAssetPolicyRegistry.assetStatus, (asset)),
                        cap
                    ) != 1
        ) {
            revert SettlementAssetNotActive(asset);
        }
    }

    function _admitGas(uint256 cap) internal view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 40_000) {
            revert InsufficientSettlementCallGas(cap);
        }
    }

    /// @dev Callers admit bounded gas first, or use the exact-code infrastructure exception.
    function _read(address target, bytes memory data, uint256 cap)
        internal
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
        if (!ok || size != 32) revert SettlementReadFailed(target, bytes4(data));
    }

    function _tokenRead(address asset, bytes memory data, uint256 cap)
        internal
        view
        returns (uint256)
    {
        _admitGas(cap);
        return _read(asset, data, cap);
    }

    function _balance(address asset, address account, uint256 cap) internal view returns (uint256) {
        return _tokenRead(asset, abi.encodeCall(IERC20.balanceOf, (account)), cap);
    }

    function _allowance(address asset, address owner, address spender, uint256 cap)
        internal
        view
        returns (uint256)
    {
        return _tokenRead(asset, abi.encodeCall(IERC20.allowance, (owner, spender)), cap);
    }

    function _tokenCall(address asset, bytes memory data, uint256 cap, bool allowFailedCall)
        internal
        returns (bool)
    {
        _admitGas(cap);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := call(cap, asset, 0, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok && allowFailedCall) return false;
        if (!ok || size != 32 || word != 1) revert SettlementTokenCallFailed(asset, bytes4(data));
        return true;
    }

    function _transfer(address asset, address to, uint256 amount, uint256 cap, bool allowFailedCall)
        internal
        returns (bool)
    {
        uint256 beforeSelf = _balance(asset, address(this), cap);
        uint256 beforeTo = _balance(asset, to, cap);
        if (beforeSelf < amount || to == address(this)) revert SettlementAmountMismatch(asset);
        bool ok =
            _tokenCall(asset, abi.encodeCall(IERC20.transfer, (to, amount)), cap, allowFailedCall);
        if (!ok) return false;
        if (
            _balance(asset, address(this), cap) != beforeSelf - amount
                || _balance(asset, to, cap) != beforeTo + amount
        ) {
            revert SettlementAmountMismatch(asset);
        }
        return true;
    }

    function _validSignature(address signer, bytes32 digest, bytes memory signature)
        internal
        view
        returns (bool)
    {
        if (signer == address(0)) return false;
        if (signer.code.length == 0 || !StreamSettlementAdmission.isContract(signer)) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            if (signature.length == 65) {
                assembly ("memory-safe") {
                    r := mload(add(signature, 32))
                    s := mload(add(signature, 64))
                    v := byte(0, mload(add(signature, 96)))
                }
            } else if (signature.length == 64) {
                bytes32 vs;
                assembly ("memory-safe") {
                    r := mload(add(signature, 32))
                    vs := mload(add(signature, 64))
                }
                s = vs & bytes32(type(uint256).max >> 1);
                v = uint8(uint256(vs) >> 255) + 27;
            }
            if (
                uint256(s) <= 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0
                    && (v == 27 || v == 28) && ecrecover(digest, v, r, s) == signer
            ) return true;
            if (signer.code.length == 0) return false;
        }
        bytes memory data = abi.encodeWithSelector(bytes4(0x1626ba7e), digest, signature);
        uint256 cap = _gas(_SIGNATURE_GAS);
        _admitGas(cap);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(cap, signer, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        return ok && size == 32 && word == uint256(uint32(0x1626ba7e)) << 224;
    }
}
