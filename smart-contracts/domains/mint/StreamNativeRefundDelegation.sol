// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamNativeRefundReadEncoding } from "./StreamNativeRefundReadEncoding.sol";
import "../../interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import {
    StreamNativeAuctionDelegation as RefundDelegation
} from "../auctions/StreamNativeAuctionDelegation.sol";

/// @notice Immutable, storage-free deployment context shared by native refund hosts.
/// @dev Existing host guards and ledgers own all effects. No payment or signature authority is added.
abstract contract StreamNativeRefundDelegation is IStreamNativeRefundDelegatedClaims {
    uint256 private immutable _refundChain;
    address private immutable _refundCore;
    address private immutable _refundRegistry;
    bytes32 private immutable _refundRegistryHash;
    uint256 private immutable _refundUsecase;
    bytes32 private immutable _refundBaseManifest;
    address private immutable _refundModules;
    bytes32 private immutable _refundModulesHash;

    constructor(address core_, address modules_, DelegationDeployment memory d) {
        if (d.registry == address(0)) {
            if (
                d.usecase != 0 || d.baseManifestHash != 0 || bytes(d.gas.name).length != 0
                    || d.gas.genesisValue != 0 || d.gas.floor != 0 || d.gas.failureClass != 0
            ) {
                revert RefundDelegation.DelegationConfigurationInvalid();
            }
        } else {
            if (
                keccak256(bytes(d.gas.name)) != keccak256("DELEGATE_REGISTRY_GAS_LIMIT")
                    || d.gas.failureClass != 2
            ) revert RefundDelegation.DelegationConfigurationInvalid();
            RefundDelegation.validateConfiguration(
                RefundDelegation.Configuration(
                    block.chainid,
                    core_,
                    d.registry,
                    d.registry.codehash,
                    d.usecase,
                    d.baseManifestHash,
                    modules_,
                    modules_.codehash
                )
            );
        }
        _refundChain = block.chainid;
        _refundCore = core_;
        _refundRegistry = d.registry;
        _refundRegistryHash = d.registry == address(0) ? bytes32(0) : d.registry.codehash;
        _refundUsecase = d.usecase;
        _refundBaseManifest = d.baseManifestHash;
        _refundModules = modules_;
        _refundModulesHash = modules_.codehash;
    }

    function refundDelegationConfiguration()
        public
        view
        override
        returns (DelegationConfiguration memory)
    {
        bytes memory out = StreamNativeRefundReadEncoding.read(_refundDelegation(), msg.sig);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function refundDelegationManifest() public view override returns (bytes memory) {
        bytes memory out = StreamNativeRefundReadEncoding.read(_refundDelegation(), msg.sig);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function refundDelegationManifestHash() external view override returns (bytes32) {
        bytes memory out = StreamNativeRefundReadEncoding.read(_refundDelegation(), msg.sig);
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }

    function _refundDelegationSupported(bytes4 id) internal view returns (bool) {
        return
            _refundRegistry != address(0)
                && id == type(IStreamNativeRefundDelegatedClaims).interfaceId;
    }

    /// @dev Admission pins the optional declaration before any sale nonce or credit can be created.
    function _requireRefundDelegationManifest() internal view {
        if (_refundRegistry != address(0)) {
            RefundDelegation.requireManifest(
                _refundDelegation(),
                IStreamGasParameterHost(address(this)).gasParameter(RefundDelegation.GAS_PARAMETER)
            );
        }
    }

    /// @dev No module status, pause, Artist, phase, entropy or sale admission is repeated on earned credits.
    function _requireRefundDelegate(address account, DelegationWitness calldata witness)
        internal
        view
    {
        if (_refundRegistry == address(0)) {
            revert RefundDelegation.DelegationConfigurationInvalid();
        }
        RefundDelegation.claimRecipient(
            _refundDelegation(),
            account,
            msg.sender,
            account,
            RefundDelegation.Witness(witness.walletWide, witness.index),
            IStreamGasParameterHost(address(this)).gasParameter(RefundDelegation.GAS_PARAMETER)
        );
    }

    function _refundDelegation() private view returns (RefundDelegation.Configuration memory) {
        return RefundDelegation.Configuration(
            _refundChain,
            _refundCore,
            _refundRegistry,
            _refundRegistryHash,
            _refundUsecase,
            _refundBaseManifest,
            _refundModules,
            _refundModulesHash
        );
    }
}
