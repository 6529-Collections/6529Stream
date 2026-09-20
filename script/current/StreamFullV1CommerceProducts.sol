// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeCommerceDeployment.sol";
import {
    StreamGovernanceExecutor
} from "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import { StreamMintManager } from "../../smart-contracts/domains/mint/StreamMintManager.sol";
import {
    StreamNativeFixedPriceSaleAdapter
} from "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";
import {
    StreamNativeDutchSale
} from "../../smart-contracts/domains/mint/StreamNativeDutchSale.sol";
import {
    StreamPrivateSaleAdapter
} from "../../smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol";
import { StreamBurnMintGate } from "../../smart-contracts/domains/mint/StreamBurnMintGate.sol";
import {
    StreamERC20PrimarySettlementAdapter
} from "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";

/// @notice Original role9/14/15/16/17/18/20 constructors on one current graph.
/// @dev PrivateSaleAdapter is the original secondary custody product; primary private
/// offers remain a separate sale surface. No constructor admits a phase or pays for a mint.
library StreamFullV1CommerceProducts {
    struct Configuration {
        IStreamRevenueResolver resolver;
        StreamModuleRegistry registry;
        IStreamRevenueEscrow escrow;
        StreamNativeEnglishAuction.DeploymentConfig auction;
        StreamNativeDutchSale.DeploymentConfig dutch;
        StreamPrivateSaleAdapter.DeploymentConfig privateSale;
        StreamBurnMintGate.Configuration burn;
        IStreamGasParameterHost.GasParameterConfig fixedRevealGas;
        IStreamNativeRefundDelegatedClaims.DelegationDeployment fixedDelegation;
        address permit2;
        bytes32 permit2CodeHash;
        bytes32 deploymentHash;
        bytes32 commerceManifestHash;
    }

    struct Products {
        StreamNativeCommerceDeployment.Products native;
        StreamNativeFixedPriceSaleAdapter fixedSale;
        StreamNativeDutchSale dutch;
        StreamPrivateSaleAdapter privateSale;
        StreamBurnMintGate burn;
        StreamERC20PrimarySettlementAdapter erc20;
        bytes32[5] codeHashes;
        bytes32 configurationHash;
    }

    function deploy(Configuration memory c) internal returns (Products memory p) {
        _configuration(c);
        p.configurationHash = keccak256(abi.encode(c));
        // The original pair planner injects its new recorder into its memory argument.
        // Preserve the reviewed zero-recorder configuration instead of aliasing it.
        StreamNativeEnglishAuction.DeploymentConfig memory auction =
            abi.decode(abi.encode(c.auction), (StreamNativeEnglishAuction.DeploymentConfig));
        p.native = StreamNativeCommerceDeployment.deploy(
            c.resolver, c.registry, c.escrow, auction, c.deploymentHash, c.commerceManifestHash
        );
        p.fixedSale = new StreamNativeFixedPriceSaleAdapter(
            c.auction.manager,
            p.native.recorder,
            c.auction.platform,
            c.auction.artists,
            c.fixedRevealGas,
            c.fixedDelegation
        );
        p.fixedSale.transferOwnership(c.auction.authority);
        StreamNativeDutchSale.DeploymentConfig memory dutch =
            abi.decode(abi.encode(c.dutch), (StreamNativeDutchSale.DeploymentConfig));
        dutch.recorder = p.native.recorder;
        p.dutch = new StreamNativeDutchSale(dutch);
        p.privateSale = new StreamPrivateSaleAdapter(c.privateSale);
        p.burn = new StreamBurnMintGate(c.burn);
        p.erc20 = new StreamERC20PrimarySettlementAdapter(
            p.native.recorder, c.permit2, c.permit2CodeHash
        );
        address[5] memory hosts = addresses(p);
        for (uint256 i; i < hosts.length; ++i) {
            p.codeHashes[i] = hosts[i].codehash;
        }
        validate(c, p);
    }

    function addresses(Products memory p) internal pure returns (address[5] memory) {
        return [
            address(p.fixedSale),
            address(p.dutch),
            address(p.privateSale),
            address(p.burn),
            address(p.erc20)
        ];
    }

    function validate(Configuration memory c, Products memory p) internal view {
        _configuration(c);
        require(p.configurationHash == keccak256(abi.encode(c)), "saved commerce configuration");
        StreamNativeCommerceDeployment.validate(p.native);
        address[5] memory hosts = addresses(p);
        for (uint256 i; i < hosts.length; ++i) {
            require(
                hosts[i].code.length != 0 && hosts[i].codehash == p.codeHashes[i],
                "retained commerce runtime"
            );
            for (uint256 j; j < i; ++j) {
                require(hosts[i] != hosts[j], "distinct commerce products");
            }
        }
        address core = p.native.recorder.core();
        address recorder = address(p.native.recorder);
        address manager = address(c.auction.manager);
        address authority = c.auction.authority;
        require(
            p.fixedSale.core() == core && p.dutch.core() == core && p.erc20.core() == core
                && p.privateSale.core() == core && p.burn.core() == core,
            "one commerce Core"
        );
        require(
            p.fixedSale.primarySaleSettlement() == recorder
                && p.dutch.primarySaleSettlement() == recorder
                && p.erc20.primarySaleSettlement() == recorder
                && p.fixedSale.settlementCodeHash() == p.native.recorderCodeHash
                && p.erc20.settlementCodeHash() == p.native.recorderCodeHash,
            "one original settlement recorder"
        );
        require(
            address(p.fixedSale.mintManager()) == manager
                && address(p.dutch.mintManager()) == manager
                && address(p.native.house.mintManager()) == manager,
            "one primary Manager"
        );
        require(
            p.fixedSale.owner() == authority && p.privateSale.owner() == authority
                && p.burn.owner() == authority && p.fixedSale.governanceAuthority() == authority
                && p.dutch.governanceAuthority() == authority
                && p.privateSale.governanceAuthority() == authority
                && p.burn.governanceAuthority() == authority,
            "original configuration authority handoff"
        );
        require(
            p.privateSale.moduleRegistry() == address(c.registry)
                && p.burn.moduleRegistry() == address(c.registry)
                && p.erc20.moduleRegistry() == address(c.registry) && p.erc20.permit2() == c.permit2
                && p.erc20.permit2CodeHash() == c.permit2CodeHash,
            "original registry and optional permit dependency"
        );
    }

    function _configuration(Configuration memory c) private view {
        address core = c.resolver.core();
        address authority = c.auction.authority;
        require(
            core.code.length != 0 && authority.code.length != 0
                && address(c.registry.governanceExecutor()) == authority
                && address(c.auction.roles)
                    == address(StreamGovernanceExecutor(payable(authority)).roleRegistry())
                && address(StreamMintManager(address(c.auction.manager)).core()) == core
                && c.auction.artists.core() == core && address(c.auction.recorder) == address(0)
                && address(c.dutch.recorder) == address(0),
            "original graph and unbound recorder inputs"
        );
        require(
            address(c.dutch.manager) == address(c.auction.manager)
                && c.dutch.platform == c.auction.platform
                && address(c.dutch.artists) == address(c.auction.artists)
                && address(c.dutch.entropy) == address(c.auction.entropy)
                && address(c.dutch.roles) == address(c.auction.roles)
                && c.dutch.authority == authority,
            "Dutch current graph"
        );
        require(
            c.privateSale.core == core && c.privateSale.moduleRegistry == address(c.registry)
                && c.privateSale.platformSigner == c.auction.platform
                && c.privateSale.configurationOwner == authority
                && c.privateSale.governanceAuthority == authority
                && c.privateSale.roleRegistry == address(c.auction.roles),
            "private custody current graph"
        );
        require(
            c.burn.core == core && c.burn.registry == address(c.registry)
                && c.burn.governance == authority && c.burn.operator == authority
                && c.burn.deploymentManifestHash == c.deploymentHash,
            "burn current graph"
        );
    }
}
