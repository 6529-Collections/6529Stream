// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamERC20DutchSale } from "../../smart-contracts/domains/mint/StreamERC20DutchSale.sol";
import {
    StreamUniversalFixedPriceSaleAdapter
} from "../../smart-contracts/domains/mint/StreamUniversalFixedPriceSaleAdapter.sol";
import {
    StreamUniversalAllowlistPriceSale
} from "../../smart-contracts/domains/mint/StreamUniversalAllowlistPriceSale.sol";
import {
    StreamERC20PrimarySettlementAdapter
} from "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import "./StreamCurrentStackPlan.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../smart-contracts/interfaces/stream/mint/IStreamMintReads.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../smart-contracts/domains/revenue/StreamSettlementAdmission.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamERC20DutchPayments.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamERC20PrimarySettlementAdapter.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamERC20SaleExecution.sol";
import "../../smart-contracts/interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Additive ERC20 products for an existing current Recorder and contract graph.
/// @dev This script helper performs ordinary CREATE, never admission, phase setup or signing.
/// Saved coordinates are operator-verified deployment evidence, not independent code provenance.
library StreamERC20CommerceDeployment {
    error InvalidERC20CommerceDeployment();
    error ERC20CommerceRuntimeChanged(address target);

    struct Configuration {
        IStreamPrimarySaleSettlement recorder;
        IStreamMintManager manager;
        IStreamArtistAttribution artists;
        IStreamRoleRegistry roles;
        address authority;
        address owner;
        address platformSigner;
        address permit2;
        bytes32 permit2CodeHash;
        IStreamGasParameterHost.GasParameterConfig fixedReveal;
        IStreamGasParameterHost.GasParameterConfig priceReveal;
        IStreamGasParameterHost.GasParameterConfig[3] dutchGas;
    }

    struct Products {
        uint256 chainId;
        Configuration configuration;
        bytes32 configurationHash;
        // Closed order: Payment, original Universal fixed, same-leaf Price, canonical Dutch.
        address[4] targets;
        bytes32[4] runtimeCodeHashes;
        // Exact constructor arguments in the same order; creation artifacts are separately pinned.
        bytes32[4] constructorArgumentsHashes;
        bytes32[4] dependencyCodeHashes; // Recorder, Manager, Artist, RoleRegistry
        bytes32 deploymentManifestHash;
        bytes32 moduleManifestHash;
    }

    function constructorArguments(Configuration memory c)
        internal
        pure
        returns (bytes[4] memory args)
    {
        args[0] = abi.encode(c.recorder, c.permit2, c.permit2CodeHash);
        args[1] = abi.encode(c.manager, c.recorder, c.platformSigner, c.artists, c.fixedReveal);
        args[2] = abi.encode(c.manager, c.recorder, c.platformSigner, c.artists, c.priceReveal);
        args[3] = abi.encode(
            StreamERC20DutchSale.DeploymentConfig(
                c.manager, c.recorder, c.artists, c.roles, c.authority, c.dutchGas
            )
        );
    }

    function deploy(Configuration memory c, bytes32 deploymentManifest, bytes32 moduleManifest)
        internal
        returns (Products memory p)
    {
        if (c.owner == address(0) || deploymentManifest == 0 || moduleManifest == 0) {
            revert InvalidERC20CommerceDeployment();
        }
        p.chainId = block.chainid;
        p.configuration = c;
        p.configurationHash = keccak256(abi.encode(c));
        p.deploymentManifestHash = deploymentManifest;
        p.moduleManifestHash = moduleManifest;
        p.targets[0] = address(
            new StreamERC20PrimarySettlementAdapter(c.recorder, c.permit2, c.permit2CodeHash)
        );
        p.targets[1] = address(
            new StreamUniversalFixedPriceSaleAdapter(
                c.manager, c.recorder, c.platformSigner, c.artists, c.fixedReveal
            )
        );
        p.targets[2] = address(
            new StreamUniversalAllowlistPriceSale(
                c.manager, c.recorder, c.platformSigner, c.artists, c.priceReveal
            )
        );
        p.targets[3] = address(
            new StreamERC20DutchSale(
                StreamERC20DutchSale.DeploymentConfig(
                    c.manager, c.recorder, c.artists, c.roles, c.authority, c.dutchGas
                )
            )
        );
        // Payment deliberately has no owner or approval writer.
        for (uint256 i = 1; i < 4; ++i) {
            ERC20CommerceOwner(p.targets[i]).transferOwnership(c.owner);
        }
        bytes[4] memory args = constructorArguments(c);
        for (uint256 i; i < 4; ++i) {
            p.runtimeCodeHashes[i] = p.targets[i].codehash;
            p.constructorArgumentsHashes[i] = keccak256(args[i]);
        }
        p.dependencyCodeHashes = [
            address(c.recorder).codehash,
            address(c.manager).codehash,
            address(c.artists).codehash,
            address(c.roles).codehash
        ];
        validate(p);
    }

    function validate(Products memory p) internal view {
        Configuration memory c = p.configuration;
        if (
            p.chainId != block.chainid || p.configurationHash != keccak256(abi.encode(c))
                || c.owner == address(0) || c.platformSigner == address(0)
                || p.deploymentManifestHash == 0 || p.moduleManifestHash == 0
                || c.authority == address(0)
                || c.authority != c.recorder.splitFactory().governanceAuthority()
        ) {
            revert InvalidERC20CommerceDeployment();
        }
        address[4] memory deps =
            [address(c.recorder), address(c.manager), address(c.artists), address(c.roles)];
        for (uint256 i; i < 4; ++i) {
            _pin(deps[i], p.dependencyCodeHashes[i]);
        }
        StreamERC20PrimarySettlementAdapter payment =
            StreamERC20PrimarySettlementAdapter(payable(p.targets[0]));
        StreamSettlementAdmission.requireRegistry(
            payment.core(),
            payment.coreCodeHash(),
            payment.moduleRegistry(),
            payment.moduleRegistryCodeHash()
        );
        if (
            c.recorder.core() != payment.core()
                || c.recorder.moduleRegistry() != payment.moduleRegistry()
                || address(c.recorder.revenueResolver()) != address(payment.revenueResolver())
                || address(c.recorder.splitFactory()) != address(payment.splitFactory())
                || address(c.recorder.assetPolicyRegistry())
                    != address(payment.assetPolicyRegistry())
                || payment.primarySaleSettlement() != address(c.recorder)
                || payment.settlementCodeHash() != p.dependencyCodeHashes[0]
                || payment.permit2() != c.permit2 || payment.permit2CodeHash() != c.permit2CodeHash
                || payment.permit2ChainId() != block.chainid
                || !payment.supportsInterface(type(IStreamERC20DutchPayments).interfaceId)
        ) {
            revert InvalidERC20CommerceDeployment();
        }
        if (c.permit2 == address(0)) {
            if (c.permit2CodeHash != 0) revert InvalidERC20CommerceDeployment();
        } else {
            _pin(c.permit2, c.permit2CodeHash);
        }
        _pin(address(payment.revenueResolver()), payment.resolverCodeHash());
        _pin(address(payment.splitFactory()), payment.factoryCodeHash());
        _pin(address(payment.assetPolicyRegistry()), payment.assetRegistryCodeHash());
        if (
            address(IStreamMintReads(address(c.manager)).core()) != payment.core()
                || address(IStreamMintReads(address(c.manager)).moduleRegistry())
                    != payment.moduleRegistry() || c.artists.core() != payment.core()
                || payment.revenueResolver().artistRegistry() != address(c.artists)
                || ERC20CommerceOwner(address(c.roles)).owner() != c.authority
        ) revert InvalidERC20CommerceDeployment();
        bytes[4] memory args = constructorArguments(c);
        for (uint256 i; i < 4; ++i) {
            _pin(p.targets[i], p.runtimeCodeHashes[i]);
            if (
                p.targets[i].code.length > 24_576
                    || keccak256(args[i]) != p.constructorArgumentsHashes[i]
            ) revert InvalidERC20CommerceDeployment();
            for (uint256 j; j < i; ++j) {
                if (p.targets[i] == p.targets[j]) revert InvalidERC20CommerceDeployment();
            }
            if (i == 0) continue;
            ERC20CommerceSaleFacts f = ERC20CommerceSaleFacts(p.targets[i]);
            if (
                f.primarySaleSettlement() != address(c.recorder)
                    || f.settlementCodeHash() != p.dependencyCodeHashes[0]
                    || address(f.mintManager()) != address(c.manager)
                    || f.mintManagerCodeHash() != p.dependencyCodeHashes[1]
                    || address(f.artistRegistry()) != address(c.artists)
                    || f.artistRegistryCodeHash() != p.dependencyCodeHashes[2]
                    || f.core() != payment.core() || f.moduleRegistry() != payment.moduleRegistry()
                    || f.governanceAuthority() != c.authority || f.owner() != c.owner
            ) revert InvalidERC20CommerceDeployment();
        }
        if (
            StreamUniversalFixedPriceSaleAdapter(payable(p.targets[1])).platformSigner()
                    != c.platformSigner
                || StreamUniversalAllowlistPriceSale(payable(p.targets[2])).platformSigner()
                    != c.platformSigner
        ) revert InvalidERC20CommerceDeployment();
        StreamERC20DutchSale dutch = StreamERC20DutchSale(payable(p.targets[3]));
        if (
            address(dutch.roleRegistry()) != address(c.roles)
                || dutch.roleRegistryCodeHash() != p.dependencyCodeHashes[3]
                || dutch.dutchResolutionProfile() != keccak256("6529STREAM_ERC20_STANDARD_DUTCH_V1")
        ) revert InvalidERC20CommerceDeployment();
        _gas(p.targets[1], c.fixedReveal);
        _gas(p.targets[2], c.priceReveal);
        for (uint256 i; i < 3; ++i) {
            _gas(p.targets[3], c.dutchGas[i]);
        }
    }

    function registrations(Products memory p)
        internal
        view
        returns (StreamModuleRegistration[] memory rows)
    {
        validate(p);
        rows = new StreamModuleRegistration[](4);
        for (uint256 i; i < 4; ++i) {
            rows[i] = StreamModuleRegistration(
                p.targets[i],
                i == 0
                    ? keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER")
                    : i == 3
                        ? keccak256("DUTCH_AUCTION_ADAPTER")
                        : keccak256("FIXED_PRICE_SALE_ADAPTER"),
                keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
                i == 0
                    ? type(IStreamERC20PrimarySettlementAdapter).interfaceId
                    : type(IStreamERC20SaleExecution).interfaceId,
                500_000,
                p.runtimeCodeHashes[i],
                p.deploymentManifestHash,
                p.moduleManifestHash,
                i == 0
                    ? "urn:6529stream:erc20-commerce:payment:v1"
                    : i == 1
                        ? "urn:6529stream:erc20-commerce:fixed:v1"
                        : i == 2
                            ? "urn:6529stream:erc20-commerce:leaf-price:v1"
                            : "urn:6529stream:erc20-commerce:dutch:v1"
            );
        }
    }

    function _gas(address target, IStreamGasParameterHost.GasParameterConfig memory c)
        private
        view
    {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) = IStreamGasParameterHost(
                target
            ).gasParameterInfo(keccak256(abi.encodePacked("6529STREAM_GGP_", c.name)));
        // Monotonic authorized raises do not alter the saved constructor metadata.
        if (
            value < c.genesisValue || floor != c.floor || failureClass != c.failureClass
                || revision == 0
        ) revert InvalidERC20CommerceDeployment();
    }

    function _pin(address target, bytes32 hash) private view {
        if (!StreamSettlementAdmission.isContract(target) || hash == 0 || target.codehash != hash) {
            revert ERC20CommerceRuntimeChanged(target);
        }
    }
}

interface ERC20CommerceOwner {
    function owner() external view returns (address);
    function transferOwnership(address next) external;
}

interface ERC20CommerceSaleFacts {
    function primarySaleSettlement() external view returns (address);
    function settlementCodeHash() external view returns (bytes32);
    function mintManager() external view returns (IStreamMintManager);
    function mintManagerCodeHash() external view returns (bytes32);
    function artistRegistry() external view returns (IStreamArtistAttribution);
    function artistRegistryCodeHash() external view returns (bytes32);
    function core() external view returns (address);
    function moduleRegistry() external view returns (address);
    function governanceAuthority() external view returns (address);
    function owner() external view returns (address);
}
