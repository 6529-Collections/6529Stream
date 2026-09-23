// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import { StreamNativeAuctionDelegation as D } from "../auctions/StreamNativeAuctionDelegation.sol";

/// @notice Immutable live offer-signing and execution delegates; grants never authorize token pulls.
abstract contract StreamERC20PrimaryOfferDelegation {
    uint256 private immutable _offerChain;
    address private immutable _offerCore;
    address private immutable _offerRegistry;
    bytes32 private immutable _offerRegistryHash;
    uint256 private immutable _offerUsecase;
    bytes32 private immutable _offerBaseManifest;
    address private immutable _offerModules;
    bytes32 private immutable _offerModulesHash;

    constructor(
        address core_,
        address modules_,
        IStreamNativeRefundDelegatedClaims.DelegationDeployment memory d
    ) {
        if (d.registry == address(0)) {
            if (
                d.usecase != 0 || d.baseManifestHash != 0 || bytes(d.gas.name).length != 0
                    || d.gas.genesisValue != 0 || d.gas.floor != 0 || d.gas.failureClass != 0
            ) revert D.DelegationConfigurationInvalid();
        } else {
            if (
                keccak256(bytes(d.gas.name)) != keccak256("DELEGATE_REGISTRY_GAS_LIMIT")
                    || d.gas.failureClass != 2
            ) revert D.DelegationConfigurationInvalid();
            D.validateConfiguration(
                D.Configuration(
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
        _offerChain = block.chainid;
        _offerCore = core_;
        _offerRegistry = d.registry;
        _offerRegistryHash = d.registry == address(0) ? bytes32(0) : d.registry.codehash;
        _offerUsecase = d.usecase;
        _offerBaseManifest = d.baseManifestHash;
        _offerModules = modules_;
        _offerModulesHash = modules_.codehash;
    }

    function offerDelegationConfiguration()
        public
        view
        virtual
        returns (IStreamNativeRefundDelegatedClaims.DelegationConfiguration memory)
    {
        return IStreamNativeRefundDelegatedClaims.DelegationConfiguration(
            _offerChain,
            _offerCore,
            _offerRegistry,
            _offerRegistryHash,
            _offerUsecase,
            _offerBaseManifest,
            _offerModules,
            _offerModulesHash
        );
    }

    function offerDelegationManifest() public view returns (bytes memory) {
        return D.manifestBytes(_offerDelegation());
    }

    function offerDelegationManifestHash() external view returns (bytes32) {
        return keccak256(offerDelegationManifest());
    }

    function _requireOfferDelegationManifest() internal view {
        if (_offerRegistry != address(0)) {
            D.requireManifest(_offerDelegation(), _offerDelegationGas());
        }
    }

    function _requireOfferDelegate(
        address buyer,
        address actor,
        IStreamNativeRefundDelegatedClaims.DelegationWitness memory witness
    ) internal view {
        if (actor == buyer) {
            return;
        }
        D.Configuration memory c = _offerDelegation();
        uint256 cap = _offerDelegationGas();
        D.requireManifest(c, cap);
        D.requireDelegated(c, buyer, actor, D.Witness(witness.walletWide, witness.index), cap);
    }

    function _offerDelegationGas() private view returns (uint256) {
        if (_offerRegistry == address(0)) revert D.DelegationConfigurationInvalid();
        return IStreamGasParameterHost(address(this)).gasParameter(D.GAS_PARAMETER);
    }

    function _offerDelegation() private view returns (D.Configuration memory) {
        return D.Configuration(
            _offerChain,
            _offerCore,
            _offerRegistry,
            _offerRegistryHash,
            _offerUsecase,
            _offerBaseManifest,
            _offerModules,
            _offerModulesHash
        );
    }
}
