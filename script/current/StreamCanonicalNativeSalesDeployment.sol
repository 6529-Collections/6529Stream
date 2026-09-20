// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamNativeImmediateSales
} from "../../smart-contracts/domains/mint/StreamNativeImmediateSales.sol";
import {
    StreamNativeClaimSales
} from "../../smart-contracts/domains/mint/StreamNativeClaimSales.sol";
import {
    StreamNativeDutchSales
} from "../../smart-contracts/domains/mint/StreamNativeDutchSales.sol";
import {
    StreamPrimarySaleSettlement
} from "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import {
    StreamSettlementContext
} from "../../smart-contracts/domains/revenue/StreamSettlementContext.sol";
import {
    StreamSettlementAdmission
} from "../../smart-contracts/domains/revenue/StreamSettlementAdmission.sol";
import { StreamRevenueEscrow } from "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import {
    StreamModuleRegistry
} from "../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import {
    StreamGovernanceExecutor
} from "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import {
    StreamRoleRegistry
} from "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import {
    IStreamGovernanceActionFacts
} from "../../smart-contracts/interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import {
    IStreamMintReads
} from "../../smart-contracts/interfaces/stream/mint/IStreamMintReads.sol";
import {
    IStreamNativeImmediateSales
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import {
    IStreamNativeClaimSales
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeClaimSales.sol";
import {
    IStreamNativeDutchSales
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeDutchSales.sol";
import {
    IStreamImmediateSaleAuthorizationBinding
} from "../../smart-contracts/interfaces/stream/mint/IStreamImmediateSaleAuthorizationBinding.sol";
import {
    IStreamImmediateSaleReveal
} from "../../smart-contracts/interfaces/stream/mint/IStreamImmediateSaleReveal.sol";
import {
    IStreamNativeSaleBinding
} from "../../smart-contracts/interfaces/stream/revenue/IStreamNativeSaleBinding.sol";
import {
    IStreamNativePublicSaleBinding
} from "../../smart-contracts/interfaces/stream/revenue/IStreamNativePublicSaleBinding.sol";
import {
    IStreamNativePrimarySaleSettlement
} from "../../smart-contracts/interfaces/stream/revenue/IStreamNativePrimarySaleSettlement.sol";
import {
    IStreamNativePublicPrimarySaleSettlement
} from "../../smart-contracts/interfaces/stream/revenue/IStreamNativePublicPrimarySaleSettlement.sol";
import {
    IStreamSplitWalletImplementation
} from "../../smart-contracts/interfaces/stream/revenue/IStreamSplitWalletImplementation.sol";
import {
    StreamModuleRegistration,
    IStreamModuleRegistry
} from "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { IERC165 } from "../../smart-contracts/vendor/openzeppelin/IERC165.sol";

/// @notice Additive canonical fixed/open, ZERO_PRICE/PWYW and Dutch native sale construction.
/// @dev Uses an existing Recorder. This helper neither selects Core pointers nor registers
/// modules, grants escrow credit, configures signers or mutates Manager phases. Those are
/// separate activation steps. Saved hashes are construction observations, not compiler
/// provenance, a live configuration-owner assertion or current-stack gas acceptance.
library StreamCanonicalNativeSalesDeployment {
    error InvalidCanonicalNativeSalesConfiguration();
    error InvalidCanonicalNativeSalesProducts();
    error CanonicalNativeSalesRuntimeChanged(address target);
    error CanonicalNativeSalesBindingMismatch(address target);
    error CanonicalNativeSalesGasMismatch(address target, bytes32 parameterId);

    bytes32 private constant _TYPE = keccak256("NATIVE_PRIMARY_SALE_ADAPTER");
    bytes32 private constant _VERSION = keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1");
    bytes32 private constant _CONSTRUCTION =
        keccak256("6529STREAM_CANONICAL_NATIVE_SALES_CONSTRUCTION_V1");

    struct Manifest {
        bytes32 hash;
        string uri;
    }

    /// @dev Product-indexed arrays use Immediate, Claim/PWYW, Dutch order. Gas settings and
    /// manifests are supplied explicitly; this helper supplies no deployment gas defaults.
    struct Configuration {
        StreamNativeImmediateSales.DeploymentConfig immediate;
        StreamNativeClaimSales.DeploymentConfig claims;
        StreamNativeDutchSales.DeploymentConfig dutch;
        bytes32 deploymentHash;
        Manifest[3] manifests;
        uint32[3] readGas;
    }

    struct Products {
        uint256 chainId;
        StreamNativeImmediateSales immediate;
        StreamNativeClaimSales claims;
        StreamNativeDutchSales dutch;
        bytes32[3] codeHashes;
        bytes32 configurationHash;
        // Core, Manager, Ledger, Recorder, Resolver, Registry, Factory,
        // AssetPolicyRegistry, Escrow, Artist, Roles, Executor.
        bytes32[12] dependencyCodeHashes;
    }

    /// @notice Construct all three companions and hand their initial Ownable administration
    /// to the explicitly configured Executor. Does not require Recorder admission or credit.
    function deploy(Configuration memory c) internal returns (Products memory p) {
        address[12] memory d = _configuration(c);
        p.chainId = block.chainid;
        p.configurationHash = keccak256(abi.encode(c));
        p.dependencyCodeHashes = _hashes(d);
        p.immediate = new StreamNativeImmediateSales(c.immediate);
        p.claims = new StreamNativeClaimSales(c.claims);
        p.dutch = new StreamNativeDutchSales(c.dutch);
        p.immediate.transferOwnership(c.immediate.authority);
        p.claims.transferOwnership(c.immediate.authority);
        p.dutch.transferOwnership(c.immediate.authority);
        if (
            p.immediate.owner() != c.immediate.authority
                || p.claims.owner() != c.immediate.authority
                || p.dutch.owner() != c.immediate.authority
        ) revert InvalidCanonicalNativeSalesProducts();
        address[3] memory own = addresses(p);
        for (uint256 i; i < own.length; ++i) {
            p.codeHashes[i] = own[i].codehash;
        }
        validate(c, p);
    }

    function addresses(Products memory p) internal pure returns (address[3] memory) {
        return [address(p.immediate), address(p.claims), address(p.dutch)];
    }

    /// @notice Return the twelve explicit dependency coordinates in the saved hash order.
    /// @dev Requires constructor cross-links, not selected Manager/Artist pointers or an
    /// ACTIVE Recorder. Construction can precede the final current-stack activation batch.
    function dependencies(Configuration memory c) internal view returns (address[12] memory) {
        return _configuration(c);
    }

    /// @notice Check the saved construction and fixed bindings against live runtime hashes.
    /// @dev Legitimate later owner transfers and monotonic GGP raises remain valid. Admission
    /// plans must separately observe current owners, Core selection and module/escrow state.
    function validate(Configuration memory c, Products memory p) internal view {
        address[12] memory d = _configuration(c);
        if (p.chainId != block.chainid || p.configurationHash != keccak256(abi.encode(c))) {
            revert InvalidCanonicalNativeSalesProducts();
        }
        for (uint256 i; i < d.length; ++i) {
            _pin(d[i], p.dependencyCodeHashes[i]);
        }
        address[3] memory own = addresses(p);
        bytes4[3] memory capabilities = [
            type(IStreamNativeImmediateSales).interfaceId,
            type(IStreamNativeClaimSales).interfaceId,
            type(IStreamNativeDutchSales).interfaceId
        ];
        for (uint256 i; i < own.length; ++i) {
            _pin(own[i], p.codeHashes[i]);
            for (uint256 j; j < i; ++j) {
                if (own[i] == own[j]) revert InvalidCanonicalNativeSalesProducts();
            }
            for (uint256 j; j < d.length; ++j) {
                if (own[i] == d[j]) revert InvalidCanonicalNativeSalesProducts();
            }
            _product(own[i], d, p.dependencyCodeHashes, capabilities[i]);
        }
        _gas(address(p.immediate), c.immediate.parameters);
        _gas(address(p.claims), c.claims.parameters);
        _gas(address(p.dutch), c.dutch.parameters);
    }

    /// @notice Exactly three canonical Universal-profile native sale registration inputs.
    /// @dev These rows do not admit or replace the existing Recorder. Rebuild the separate
    /// governed registration batch against observed Registry state before scheduling it.
    function registrations(Configuration memory c, Products memory p)
        internal
        view
        returns (StreamModuleRegistration[] memory rows)
    {
        validate(c, p);
        address[3] memory own = addresses(p);
        rows = new StreamModuleRegistration[](3);
        for (uint256 i; i < own.length; ++i) {
            rows[i] = StreamModuleRegistration(
                own[i],
                _TYPE,
                _VERSION,
                type(IStreamNativeSaleBinding).interfaceId,
                c.readGas[i],
                p.codeHashes[i],
                c.deploymentHash,
                c.manifests[i].hash,
                c.manifests[i].uri
            );
        }
    }

    /// @notice Bind the supplied metadata, constructor inputs and saved runtime inventory.
    /// @dev This is not a commitment to future owners, live GGP values or admission state.
    function constructionHash(Configuration memory c, Products memory p)
        internal
        view
        returns (bytes32)
    {
        validate(c, p);
        return keccak256(abi.encode(_CONSTRUCTION, c, p));
    }

    function _configuration(Configuration memory c) private view returns (address[12] memory d) {
        if (
            c.deploymentHash == 0 || address(c.claims.manager) != address(c.immediate.manager)
                || address(c.dutch.manager) != address(c.immediate.manager)
                || address(c.claims.recorder) != address(c.immediate.recorder)
                || address(c.dutch.recorder) != address(c.immediate.recorder)
                || address(c.claims.artists) != address(c.immediate.artists)
                || address(c.dutch.artists) != address(c.immediate.artists)
                || address(c.claims.roles) != address(c.immediate.roles)
                || address(c.dutch.roles) != address(c.immediate.roles)
                || c.claims.authority != c.immediate.authority
                || c.dutch.authority != c.immediate.authority
        ) revert InvalidCanonicalNativeSalesConfiguration();
        for (uint256 i; i < 3; ++i) {
            if (
                c.manifests[i].hash == 0 || bytes(c.manifests[i].uri).length == 0
                    || bytes(c.manifests[i].uri).length > 2048 || c.readGas[i] == 0
            ) {
                revert InvalidCanonicalNativeSalesConfiguration();
            }
        }
        _gasConfiguration(c.immediate.parameters);
        _gasConfiguration(c.claims.parameters);
        _gasConfiguration(c.dutch.parameters);
        _live(address(c.immediate.manager));
        _live(address(c.immediate.recorder));
        _live(address(c.immediate.artists));
        _live(address(c.immediate.roles));
        _live(c.immediate.authority);
        IStreamMintReads manager = IStreamMintReads(address(c.immediate.manager));
        StreamPrimarySaleSettlement recorder =
            StreamPrimarySaleSettlement(address(c.immediate.recorder));
        d = [
            recorder.core(),
            address(c.immediate.manager),
            address(manager.mintLedger()),
            address(recorder),
            address(recorder.revenueResolver()),
            recorder.moduleRegistry(),
            address(recorder.splitFactory()),
            address(recorder.assetPolicyRegistry()),
            address(recorder.revenueEscrow()),
            address(c.immediate.artists),
            address(c.immediate.roles),
            c.immediate.authority
        ];
        for (uint256 i; i < d.length; ++i) {
            _live(d[i]);
        }
        if (
            !manager.isStreamMintManager() || address(manager.core()) != d[0]
                || address(manager.moduleRegistry()) != d[5]
                || !manager.mintLedger().isStreamMintLedger()
                || !recorder.isStreamPrimarySaleSettlement() || c.immediate.artists.core() != d[0]
                || recorder.revenueResolver().core() != d[0]
                || recorder.revenueResolver().artistRegistry() != d[9]
                || recorder.revenueResolver().splitFactory() != d[6]
                || address(recorder.splitFactory().assetPolicyRegistry()) != d[7]
                || recorder.splitFactory().governanceAuthority() != d[11]
                || recorder.assetPolicyRegistry().governanceAuthority() != d[11]
                || recorder.revenueEscrow().governanceAuthority() != d[11]
                || address(StreamModuleRegistry(payable(d[5])).governanceExecutor()) != d[11]
                || address(StreamGovernanceExecutor(payable(d[11])).roleRegistry()) != d[10]
                || StreamRoleRegistry(d[10]).owner() != d[11]
        ) revert InvalidCanonicalNativeSalesConfiguration();
        _erc165(d[5], type(IStreamModuleRegistry).interfaceId);
        _erc165(d[11], type(IStreamGovernanceActionFacts).interfaceId);
        _erc165(d[3], type(IStreamNativePrimarySaleSettlement).interfaceId);
        _erc165(d[3], type(IStreamNativePublicPrimarySaleSettlement).interfaceId);
        bytes32[12] memory hashes = _hashes(d);
        _context(StreamSettlementContext(d[3]), d, hashes);
        _pin(d[0], recorder.revenueResolver().coreCodeHash());
        _pin(d[9], recorder.revenueResolver().artistRegistryCodeHash());
        _pin(d[8], recorder.escrowCodeHash());
        _pin(d[11], recorder.custodyGovernanceAuthorityCodeHash());
        StreamRevenueEscrow escrow = StreamRevenueEscrow(payable(d[8]));
        if (
            recorder.custodyGovernanceAuthority() != d[11] || address(escrow.splitFactory()) != d[6]
                || address(escrow.assetPolicyRegistry()) != d[7]
                || escrow.factoryCodeHash() != hashes[6] || escrow.registryCodeHash() != hashes[7]
                || escrow.walletCodeHash() != recorder.walletCodeHash()
                || recorder.walletCodeHash() != recorder.splitFactory().splitWalletRuntimeCodeHash()
        ) revert InvalidCanonicalNativeSalesConfiguration();
        _pin(
            IStreamSplitWalletImplementation(d[6]).splitWalletImplementation(),
            IStreamSplitWalletImplementation(d[6]).splitWalletImplementationCodeHash()
        );
    }

    function _product(
        address target,
        address[12] memory d,
        bytes32[12] memory hashes,
        bytes4 family
    ) private view {
        _erc165(target, family);
        _erc165(target, type(IStreamNativeSaleBinding).interfaceId);
        _erc165(target, type(IStreamNativePublicSaleBinding).interfaceId);
        _erc165(target, type(IStreamImmediateSaleAuthorizationBinding).interfaceId);
        _erc165(target, type(IStreamImmediateSaleReveal).interfaceId);
        _erc165(target, type(IStreamGasParameterHost).interfaceId);
        _context(StreamSettlementContext(target), d, hashes);
        // These are the shared fixed getter signatures on all three concrete products.
        StreamNativeImmediateSales sale = StreamNativeImmediateSales(target);
        if (
            address(sale.mintManager()) != d[1] || sale.mintManagerCodeHash() != hashes[1]
                || sale.primarySaleSettlement() != d[3] || sale.settlementCodeHash() != hashes[3]
                || address(sale.artistRegistry()) != d[9]
                || sale.artistRegistryCodeHash() != hashes[9]
                || address(sale.roleRegistry()) != d[10]
                || sale.roleRegistryCodeHash() != hashes[10] || sale.governanceAuthority() != d[11]
                || sale.streamModuleType() != _TYPE
                || sale.streamModuleInterfaceId() != type(IStreamNativeSaleBinding).interfaceId
        ) revert CanonicalNativeSalesBindingMismatch(target);
    }

    function _context(StreamSettlementContext context, address[12] memory d, bytes32[12] memory h)
        private
        view
    {
        if (
            context.core() != d[0] || context.coreCodeHash() != h[0]
                || context.moduleRegistry() != d[5] || context.moduleRegistryCodeHash() != h[5]
                || address(context.revenueResolver()) != d[4] || context.resolverCodeHash() != h[4]
                || address(context.splitFactory()) != d[6] || context.factoryCodeHash() != h[6]
                || address(context.assetPolicyRegistry()) != d[7]
                || context.assetRegistryCodeHash() != h[7]
        ) revert CanonicalNativeSalesBindingMismatch(address(context));
    }

    function _gasConfiguration(IStreamGasParameterHost.GasParameterConfig[3] memory parameters)
        private
        pure
    {
        bytes32[3] memory names = [
            keccak256("SALE_ERC1271_GAS_LIMIT"),
            keccak256("SALE_ARTIST_AUTHORITY_GAS_LIMIT"),
            keccak256("REVEAL_ATTEMPT_GAS_LIMIT")
        ];
        for (uint256 i; i < parameters.length; ++i) {
            if (
                keccak256(bytes(parameters[i].name)) != names[i] || parameters[i].floor == 0
                    || parameters[i].genesisValue < parameters[i].floor
                    || parameters[i].failureClass != 2
            ) revert InvalidCanonicalNativeSalesConfiguration();
        }
    }

    function _gas(address target, IStreamGasParameterHost.GasParameterConfig[3] memory parameters)
        private
        view
    {
        bytes32[] memory ids = IStreamGasParameterHost(target).gasParameterIds();
        if (ids.length != parameters.length) revert CanonicalNativeSalesGasMismatch(target, 0);
        for (uint256 i; i < parameters.length; ++i) {
            bytes32 id = keccak256(abi.encodePacked("6529STREAM_GGP_", parameters[i].name));
            (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
                IStreamGasParameterHost(target).gasParameterInfo(id);
            if (
                ids[i] != id || revision == 0 || value < parameters[i].genesisValue
                    || floor != parameters[i].floor || failureClass != parameters[i].failureClass
            ) revert CanonicalNativeSalesGasMismatch(target, id);
        }
    }

    function _hashes(address[12] memory d) private view returns (bytes32[12] memory hashes) {
        for (uint256 i; i < d.length; ++i) {
            hashes[i] = d[i].codehash;
        }
    }

    function _erc165(address target, bytes4 capability) private view {
        if (
            !IERC165(target).supportsInterface(type(IERC165).interfaceId)
                || IERC165(target).supportsInterface(0xffffffff)
                || !IERC165(target).supportsInterface(capability)
        ) revert CanonicalNativeSalesBindingMismatch(target);
    }

    function _live(address target) private view {
        if (!StreamSettlementAdmission.isContract(target) || target.code.length > 24_576) {
            revert CanonicalNativeSalesRuntimeChanged(target);
        }
    }

    function _pin(address target, bytes32 expected) private view {
        _live(target);
        if (expected == 0 || target.codehash != expected) {
            revert CanonicalNativeSalesRuntimeChanged(target);
        }
    }
}
