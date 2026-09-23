// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";

/// @notice Exact retained NFTDelegation grants for bid-for-vault and delegate-triggered claims.
/// @dev The host owns immutable configuration, GGP selection, original sale admission and
/// deposit/claim effects. This helper never spends funds or writes a delivery binding.
library StreamNativeAuctionDelegation {
    address internal constant ALL_COLLECTIONS = 0x8888888888888888888888888888888888888888;
    bytes32 internal constant GAS_PARAMETER =
        keccak256("6529STREAM_GGP_DELEGATE_REGISTRY_GAS_LIMIT");
    bytes32 private constant MANIFEST =
        keccak256("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1");
    bytes4 private constant ROW = bytes4(keccak256("globalDelegationHashes(bytes32,uint256)"));

    struct Configuration {
        uint256 chainId;
        address core;
        address delegateRegistry;
        bytes32 delegateRegistryCodeHash;
        uint256 delegationUsecase;
        bytes32 baseManifestHash;
        address moduleRegistry;
        bytes32 moduleRegistryCodeHash;
    }

    /// @dev A locator into the pinned original registry, never caller-supplied authority facts.
    struct Witness {
        bool walletWide;
        uint256 index;
    }

    error DelegationConfigurationInvalid();
    error DelegationRegistryUnavailable(address registry);
    error DelegationReadGas(uint256 available, uint256 required);
    error DelegationReadFailed(address registry);
    error DelegationReadMalformed(address registry, uint256 length);
    error DelegationNotFound(address vault, address delegate);
    error DelegationManifestMismatch();
    error BidDeliveryAlreadyBound(address originalRecipient, address suppliedRecipient);

    /// @notice Complete compact declaration bytes committed by this profile's module record.
    /// @dev baseManifestHash retains the rest of the module's original declared meaning.
    function manifestBytes(Configuration memory c) public view returns (bytes memory) {
        return abi.encode(
            MANIFEST,
            c.chainId,
            address(this),
            c.baseManifestHash,
            c.core,
            c.delegateRegistry,
            c.delegateRegistryCodeHash,
            c.delegationUsecase
        );
    }

    function validateConfiguration(Configuration memory c) public view {
        if (
            c.chainId != block.chainid || c.core == address(0) || c.core == ALL_COLLECTIONS
                || c.baseManifestHash == 0 || c.delegationUsecase == 0
                || (c.delegationUsecase == 998 || c.delegationUsecase == 999)
                || c.moduleRegistry == address(0) || c.moduleRegistryCodeHash == 0
                || c.moduleRegistry.codehash != c.moduleRegistryCodeHash
        ) revert DelegationConfigurationInvalid();
        _registry(c);
    }

    /// @notice Resolve a bid recipient before the host atomically writes its original binding.
    /// @dev Exact repeat bids use the saved binding without reauthorizing it. The host must
    /// retain its ordinary current sale/module checks and emit/write only after a valid bid.
    function resolveDelivery(
        mapping(bytes32 => mapping(address => address)) storage bindings,
        Configuration memory c,
        bytes32 auctionId,
        address bidder,
        address requested,
        Witness memory witness,
        uint256 readGas
    ) public view returns (address recipient) {
        if (auctionId == 0 || bidder == address(0) || bidder == address(this)) {
            revert DelegationConfigurationInvalid();
        }
        recipient = requested == address(0) ? bidder : requested;
        if (recipient == address(this)) revert DelegationConfigurationInvalid();
        address original = bindings[auctionId][bidder];
        if (original != address(0)) {
            if (original != recipient) revert BidDeliveryAlreadyBound(original, recipient);
            return original;
        }
        if (recipient == bidder) return recipient;
        requireManifest(c, readGas);
        requireDelegated(c, recipient, bidder, witness, readGas);
    }

    /// @notice Live delegate authority can trigger a claim only to the credited account itself.
    /// @dev Own-account claims keep their existing caller-chosen destination. No module
    /// status, pause, artist, phase or payment authorization is replayed on this claim read.
    function claimRecipient(
        Configuration memory c,
        address account,
        address caller,
        address requested,
        Witness memory witness,
        uint256 readGas
    ) public view returns (address recipient) {
        if (account == address(0) || caller == address(0)) {
            revert DelegationConfigurationInvalid();
        }
        if (caller == account) {
            if (requested == address(0) || requested == address(this)) {
                revert DelegationConfigurationInvalid();
            }
            return requested;
        }
        if (requested != account || account == address(this)) {
            revert DelegationNotFound(account, caller);
        }
        requireDelegated(c, account, caller, witness, readGas);
        return account;
    }

    /// @notice Check one actual still-retained all-token grant, including its expiry and scope.
    /// @dev NFTDelegation's boolean global getter checks only array length, so it cannot
    /// replace this full record check. Its packed key is an exact upstream protocol preimage.
    function requireDelegated(
        Configuration memory c,
        address vault,
        address delegate,
        Witness memory witness,
        uint256 readGas
    ) public view {
        _registry(c);
        if (vault == address(0) || delegate == address(0) || vault == delegate) {
            revert DelegationNotFound(vault, delegate);
        }
        address scope = witness.walletWide ? ALL_COLLECTIONS : c.core;
        bytes32 key = keccak256(abi.encodePacked(vault, scope, delegate, c.delegationUsecase));
        bytes memory data = abi.encodeWithSelector(ROW, key, witness.index);
        uint256[6] memory row;
        bool ok;
        uint256 size;
        address target = c.delegateRegistry;
        _gas(readGas);
        assembly ("memory-safe") {
            ok := staticcall(readGas, target, add(data, 32), mload(data), row, 192)
            size := returndatasize()
        }
        if (!ok) revert DelegationReadFailed(target);
        if (size != 192) revert DelegationReadMalformed(target, size);
        if (
            row[0] != uint256(uint160(vault)) || row[1] != uint256(uint160(delegate))
                || row[2] > block.timestamp || row[3] <= block.timestamp || row[4] != 1
                || row[5] != 0
        ) revert DelegationNotFound(vault, delegate);
    }

    /// @notice Bind registry address/runtime/usecase to the actual adapter's registered manifest.
    /// @dev Ordinary original-sale lifecycle admission remains the host's responsibility.
    function requireManifest(Configuration memory c, uint256 readGas) public view {
        validateConfiguration(c);
        bytes memory data = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (address(this)));
        uint256[14] memory words;
        bool ok;
        uint256 size;
        address target = c.moduleRegistry;
        _gas(readGas);
        assembly ("memory-safe") {
            ok := staticcall(readGas, target, add(data, 32), mload(data), words, 448)
            size := returndatasize()
        }
        if (!ok) revert DelegationReadFailed(target);
        if (
            size < 448 || words[0] != 32 || words[1] > 3 || words[5] > type(uint32).max
                || words[9] != 384 || words[10] > type(uint64).max || words[11] > type(uint64).max
                || words[12] > type(uint64).max || words[13] > size - 448
                || size - 448 != ((words[13] + 31) / 32) * 32
        ) revert DelegationReadMalformed(target, size);
        if (
            words[1] != 1 || bytes32(words[6]) != address(this).codehash || words[7] == 0
                || bytes32(words[8]) != keccak256(manifestBytes(c)) || words[10] == 0
                || words[10] > block.timestamp || words[11] < words[10]
                || words[11] > block.timestamp || words[12] == 0
        ) revert DelegationManifestMismatch();
    }

    function _registry(Configuration memory c) private view {
        if (
            c.chainId != block.chainid || c.core == address(0) || c.core == ALL_COLLECTIONS
                || c.delegationUsecase == 0
                || (c.delegationUsecase == 998 || c.delegationUsecase == 999)
        ) revert DelegationConfigurationInvalid();
        if (
            c.delegateRegistry == address(0) || c.delegateRegistry.code.length == 0
                || c.delegateRegistryCodeHash == 0
                || c.delegateRegistry.codehash != c.delegateRegistryCodeHash
        ) revert DelegationRegistryUnavailable(c.delegateRegistry);
    }

    function _gas(uint256 cap) private view {
        uint256 available = gasleft();
        if (
            cap == 0 || cap > available
                || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30000
        ) {
            revert DelegationReadGas(available, cap);
        }
    }
}
