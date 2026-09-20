// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintFallbackPlan.sol";
import "./StreamEntropyFallbackPlan.sol";
import {
    StreamMintManagerFallback
} from "../../smart-contracts/domains/mint/StreamMintManagerFallback.sol";
import { StreamSplitFactory } from "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import {
    IStreamSplitWallet
} from "../../smart-contracts/interfaces/stream/revenue/IStreamSplitWallet.sol";
import {
    StreamEntropyProviderVRF
} from "../../smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol";

/// @notice Actual role6 singleton and distinct role34/35 original fallback products.
/// @dev Creates no wallet template. Backup constructors do not configure collections,
/// admit providers, enable Ledger writers, bind recorders or establish migration readiness.
library StreamFullV1ContinuityProducts {
    error InvalidContinuityComposition();

    struct Manifest {
        bytes32 hash;
        string uri;
    }

    struct Configuration {
        StreamCore core;
        StreamGovernanceExecutor executor;
        StreamModuleRegistry registry;
        StreamMintLedger ledger;
        StreamMintManager manager;
        StreamSplitFactory factory;
        StreamEntropyCoordinator entropy;
        address recorder;
        bytes32 deploymentHash;
        bytes32 mintVersion;
        Manifest mint;
        Manifest entropyBackup;
        Manifest provider;
        uint32 moduleGas;
        IStreamTimeParameterHost.TimeParameterConfig[3] entropyTimes;
        // coordinator must be zero: the exact new backup is injected before construction.
        StreamEntropyProviderVRF.Config backupVRF;
    }

    struct Products {
        uint256 chainId;
        address walletImplementation;
        bytes32 walletImplementationCodeHash;
        StreamMintManagerFallback manager;
        StreamEntropyCoordinator entropy;
        StreamEntropyProviderVRF provider;
        bytes32 managerCodeHash;
        bytes32 entropyCodeHash;
        bytes32 providerCodeHash;
        bytes32 configurationHash;
        bytes32[8] dependencyCodeHashes;
    }

    function deploy(Configuration memory c) internal returns (Products memory p) {
        address[8] memory dependencies = _dependencies(c);
        p.chainId = block.chainid;
        p.configurationHash = keccak256(abi.encode(c));
        for (uint256 i; i < dependencies.length; ++i) {
            p.dependencyCodeHashes[i] = dependencies[i].codehash;
        }
        p.walletImplementation = c.factory.splitWalletImplementation();
        p.walletImplementationCodeHash = c.factory.splitWalletImplementationCodeHash();
        p.entropy = new StreamEntropyCoordinator(
            StreamEntropyFallbackPlan.deploymentConfig(
                c.entropy,
                c.entropyTimes,
                c.deploymentHash,
                c.entropyBackup.uri,
                c.entropyBackup.hash
            )
        );
        StreamEntropyProviderVRF.Config memory provider =
            abi.decode(abi.encode(c.backupVRF), (StreamEntropyProviderVRF.Config));
        provider.coordinator = address(p.entropy);
        p.provider = new StreamEntropyProviderVRF(
            provider, c.deploymentHash, c.provider.uri, c.provider.hash
        );
        p.manager = new StreamMintManagerFallback(c.core, c.ledger, IERC165(address(c.registry)));
        p.manager.transferOwnership(address(c.executor));
        p.managerCodeHash = address(p.manager).codehash;
        p.entropyCodeHash = address(p.entropy).codehash;
        p.providerCodeHash = address(p.provider).codehash;
        validate(c, p);
    }

    function validate(Configuration memory c, Products memory p) internal view {
        address[8] memory dependencies = _dependencies(c);
        require(
            p.chainId == block.chainid && p.configurationHash == keccak256(abi.encode(c)),
            "saved continuity configuration"
        );
        for (uint256 i; i < dependencies.length; ++i) {
            _pin(dependencies[i], p.dependencyCodeHashes[i]);
        }
        _pin(address(p.manager), p.managerCodeHash);
        _pin(address(p.entropy), p.entropyCodeHash);
        _pin(address(p.provider), p.providerCodeHash);
        _pin(p.walletImplementation, p.walletImplementationCodeHash);
        require(
            c.factory.WALLET_VERSION() == 4
                && p.walletImplementation == c.factory.splitWalletImplementation()
                && p.walletImplementationCodeHash == c.factory.splitWalletImplementationCodeHash()
                && IStreamSplitWallet(p.walletImplementation).factory() == address(c.factory)
                && IStreamSplitWallet(p.walletImplementation).initialized()
                && IStreamSplitWallet(p.walletImplementation).profileId() == 0,
            "actual locked factory singleton"
        );
        StreamEntropyFallbackPlan.requirePair(c.entropy, p.entropy);
        require(
            p.provider.coordinator() == address(p.entropy)
                && p.provider.authority() == address(c.executor),
            "backup owns its actual provider"
        );
        StreamMintFallbackPlan.validate(mintConfiguration(c, p));
    }

    /// @notice Feed the exact standing Manager and common recorder to the original fallback plan.
    function mintConfiguration(Configuration memory c, Products memory p)
        internal
        view
        returns (StreamMintFallbackPlan.Configuration memory m)
    {
        m.chainId = p.chainId;
        m.core = c.core;
        m.ledger = c.ledger;
        m.primary = c.manager;
        m.fallbackManager = p.manager;
        m.registry = c.registry;
        m.governance = address(c.executor);
        m.coreCodeHash = p.dependencyCodeHashes[0];
        m.ledgerCodeHash = p.dependencyCodeHashes[3];
        m.primaryCodeHash = p.dependencyCodeHashes[4];
        m.fallbackCodeHash = p.managerCodeHash;
        m.registryCodeHash = p.dependencyCodeHashes[2];
        m.governanceCodeHash = p.dependencyCodeHashes[1];
        m.moduleVersion = c.mintVersion;
        m.deploymentManifestHash = c.deploymentHash;
        m.moduleManifestHash = c.mint.hash;
        m.moduleManifestURI = c.mint.uri;
        m.moduleGasLimit = c.moduleGas;
        m.recorder = c.recorder;
        m.recorderCodeHash = p.dependencyCodeHashes[7];
    }

    /// @dev Two fallback hosts and the backup-specific provider; no second Core pointer kind.
    function registrations(Configuration memory c, Products memory p)
        internal
        view
        returns (StreamModuleRegistration[] memory rows)
    {
        validate(c, p);
        rows = new StreamModuleRegistration[](3);
        rows[0] = StreamMintFallbackPlan.fallbackRegistration(mintConfiguration(c, p));
        rows[1] = StreamEntropyFallbackPlan.record(p.entropy, c.moduleGas);
        rows[2] = StreamModuleRegistration(
            address(p.provider),
            p.provider.streamModuleType(),
            p.provider.streamModuleVersion(),
            p.provider.streamModuleInterfaceId(),
            c.moduleGas,
            p.providerCodeHash,
            c.deploymentHash,
            c.provider.hash,
            c.provider.uri
        );
    }

    /// @notice Stronger than construction: actual ACTIVE reserve, common recorder/writer,
    /// isolated retirement classifier and supplied configured backup collection inventory.
    /// Historical inventory completeness and final current-stack gas sizing remain external evidence.
    function configuredReserveCheckpoint(
        Configuration memory c,
        Products memory p,
        StreamEntropyFallbackPlan.Collection[] memory collections,
        bytes32 historicalSubjectsManifestHash
    ) internal view returns (StreamEntropyFallbackPlan.Checkpoint memory checkpoint) {
        validate(c, p);
        StreamMintFallbackPlan.requireReserveReady(mintConfiguration(c, p));
        (bool enabled, bytes32 codeHash,,) =
            c.executor.tighteningCallConfig(address(c.ledger), c.ledger.retireLedgerWriter.selector);
        require(
            enabled && codeHash == address(c.ledger).codehash, "original retirement classification"
        );
        require(
            c.registry
                .isModuleEligible(
                    address(p.entropy),
                    keccak256("ENTROPY_COORDINATOR"),
                    type(IStreamEntropyCoordinator).interfaceId
                ),
            "ACTIVE backup coordinator"
        );
        for (uint256 i; i < collections.length; ++i) {
            require(
                collections[i].provider == address(p.provider), "original backup provider binding"
            );
        }
        checkpoint = StreamEntropyFallbackPlan.checkpoint(
            c.entropy, p.entropy, collections, historicalSubjectsManifestHash
        );
    }

    function _dependencies(Configuration memory c) private view returns (address[8] memory d) {
        d = [
            address(c.core),
            address(c.executor),
            address(c.registry),
            address(c.ledger),
            address(c.manager),
            address(c.factory),
            address(c.entropy),
            c.recorder
        ];
        for (uint256 i; i < d.length; ++i) {
            require(d[i].code.length != 0, "original continuity dependency");
        }
        if (
            c.deploymentHash == 0 || c.mintVersion == 0 || c.mint.hash == 0
                || c.entropyBackup.hash == 0 || c.provider.hash == 0 || c.moduleGas == 0
                || c.backupVRF.coordinator != address(0)
                || c.backupVRF.authority != address(c.executor)
                || c.factory.governanceAuthority() != address(c.executor)
                || c.entropy.authority() != address(c.executor)
                || address(c.entropy.core()) != address(c.core)
                || address(c.entropy.roleRegistry()) != address(c.executor.roleRegistry())
        ) revert InvalidContinuityComposition();
    }

    function _pin(address target, bytes32 hash) private view {
        require(target.code.length != 0 && target.codehash == hash, "retained continuity runtime");
    }
}
