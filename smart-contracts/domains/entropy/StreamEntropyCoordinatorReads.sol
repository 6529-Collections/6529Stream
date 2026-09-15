// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamEntropyProviderFeeQuote
} from "../../interfaces/stream/entropy/IStreamEntropyProviderFeeQuote.sol";
import "./StreamEntropyCoordinator.sol";
import { StreamEntropyCollectionRecovery } from "./StreamEntropyCollectionRecovery.sol";
import {
    IStreamEntropyCollectionRecovery as C
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionRecovery.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../interfaces/stream/governance/IStreamGovernanceRoleSources.sol";
import "../../interfaces/stream/mint/IStreamMintGovernanceRegistry.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Fixed read/admission worker; preserves the coordinator's original storage, domains and caller context.
library StreamEntropyCoordinatorReads {
    /// @notice Original five-value policy encoded in the fixed worker for the terminal host read.
    function policyEncoded(
        IStreamCore core,
        uint256 collectionId,
        StreamEntropyCoordinator.CollectionConfig storage config,
        IStreamRevealFeeEscrow.CollectionRevealPolicy storage reveal,
        uint32 providerEpoch
    ) public view returns (bytes memory) {
        (bool frozen, bytes32 manifest, address provider, uint32 epoch, bytes32 salt) =
            policy(core, collectionId, config, reveal, providerEpoch);
        return abi.encode(frozen, manifest, provider, epoch, salt);
    }

    function policy(
        IStreamCore core,
        uint256 collectionId,
        StreamEntropyCoordinator.CollectionConfig storage config,
        IStreamRevealFeeEscrow.CollectionRevealPolicy storage reveal,
        uint32 providerEpoch
    )
        public
        view
        returns (
            bool frozen,
            bytes32 policyManifestHash,
            address provider,
            uint32 epoch,
            bytes32 collectionSaltCommitment
        )
    {
        if (config.provider == address(0) || !reveal.declared) {
            return (false, bytes32(0), address(0), 0, bytes32(0));
        }
        collectionSaltCommitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_SALT_V1"),
                block.chainid,
                address(this),
                address(core),
                collectionId,
                config.collectionSalt
            )
        );
        // Retain both original no-recovery commitments when no policy is bound.
        // A positive binding below commits to its complete frozen recovery policy.
        bytes32 providerPolicy = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SINGLE_PROVIDER_POLICY_V1"),
                config.provider,
                config.providerCodeHash,
                providerEpoch,
                config.providerConfigHash,
                collectionSaltCommitment,
                config.publicRequests,
                config.timeoutBlocks
            )
        );
        bytes32 revealPolicy = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_DECLARED_REVEAL_POLICY_V1"),
                reveal.requestMode,
                reveal.revealOwnerRole,
                reveal.requestSLOBlocks
            )
        );
        policyManifestHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FINALITY_POLICY_V1"),
                block.chainid,
                address(this),
                address(core),
                collectionId,
                providerEpoch == 1
                    ? keccak256("6529STREAM_ENTROPY_EPOCH1_NO_FRESH_RECOVERY_V1")
                    : keccak256("6529STREAM_ENTROPY_PREMINT_EPOCHS_NO_FRESH_RECOVERY_V1"),
                providerPolicy,
                revealPolicy
            )
        );
        C.CollectionRecovery memory recovery = StreamEntropyCollectionRecovery.record(collectionId);
        if (recovery.maxFreshRecoveryAttempts != 0) {
            policyManifestHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ENTROPY_FINALITY_FRESH_POLICY_V1"),
                    block.chainid,
                    address(this),
                    address(core),
                    collectionId,
                    providerPolicy,
                    revealPolicy,
                    recovery.policyId,
                    recovery.policyHash,
                    recovery.maxFreshRecoveryAttempts
                )
            );
        }
        return (
            config.locked,
            policyManifestHash,
            config.provider,
            providerEpoch,
            collectionSaltCommitment
        );
    }

    function hasRole(
        IStreamCore core,
        address authority,
        IStreamRoleRegistry roleRegistry,
        bytes32 roleRegistryCodeHash,
        bytes32 role,
        address account
    ) public view returns (bool) {
        (address registry, bytes32 hash,,,,,,,,) =
            core.getSatellitePointer(keccak256("MODULE_REGISTRY"));
        if (
            registry.code.length == 0 || registry.codehash != hash
                || !IERC165(registry).supportsInterface(type(IStreamModuleRegistry).interfaceId)
                || IStreamMintGovernanceRegistry(registry).governanceExecutor() != authority
                || IStreamGovernanceRoleSource(authority).roleRegistry() != address(roleRegistry)
                || address(roleRegistry).codehash != roleRegistryCodeHash
                || IStreamRoleRegistryOwnership(address(roleRegistry)).owner() != authority
        ) {
            revert StreamEntropyCoordinator.InvalidDependency(address(roleRegistry));
        }
        return account.code.length != 0 && roleRegistry.hasRole(role, account);
    }

    function deriveSeed(
        IStreamCore core,
        bytes32 requestKey,
        StreamEntropyCoordinator.Request storage request,
        StreamEntropyCoordinator.Subject storage subject,
        IStreamEntropyEpochs.RequestPolicySnapshot storage policy,
        bytes32 rawRandomness
    ) public view returns (bytes32) {
        StreamEntropyCoordinator.SeedInputs memory inputs;
        inputs.domain = request.scopeId == 0
            ? keccak256("6529STREAM_ENTROPY_SEED_V1")
            : keccak256("6529STREAM_ENTROPY_SCOPE_SEED_V1");
        inputs.chainId = block.chainid;
        inputs.coordinator = address(this);
        inputs.streamCore = address(core);
        inputs.collectionId = subject.collectionId;
        inputs.identity = request.scopeId == 0 ? bytes32(request.tokenId) : request.scopeId;
        inputs.provider = policy.provider;
        inputs.providerEpoch = policy.providerEpoch;
        inputs.providerConfigHash = policy.providerConfigHash;
        inputs.requestKey = requestKey;
        inputs.providerRequestId = request.providerRequestId;
        inputs.rawRandomness = rawRandomness;
        inputs.collectionSalt = policy.collectionSalt;
        inputs.inputsHash = policy.inputsHash;
        return keccak256(abi.encode(inputs));
    }

    function providerConfiguration(address provider, uint64 timeoutBlocks)
        public
        view
        returns (bytes32 configHash)
    {
        if (
            provider.code.length == 0 || timeoutBlocks == 0
                || !IERC165(provider).supportsInterface(type(IStreamEntropyProvider).interfaceId)
                || IERC165(provider).supportsInterface(0xffffffff)
        ) revert StreamEntropyCoordinator.InvalidDependency(provider);
        configHash = IStreamEntropyProvider(provider).streamEntropyProviderConfigHash();
        if (configHash == 0 || !IStreamEntropyProvider(provider).isStreamEntropyProvider()) {
            revert StreamEntropyCoordinator.InvalidDependency(provider);
        }
    }

    /// @notice Original exact fee-quote validation; no custody or payment mutation.
    function validateRevealFee(
        StreamEntropyCoordinator.CollectionConfig storage config,
        uint256 fee
    ) public view {
        address provider = config.provider;
        if (
            provider.code.length == 0 || provider.codehash != config.providerCodeHash
                || IStreamEntropyProvider(provider).streamEntropyProviderConfigHash()
                    != config.providerConfigHash
        ) {
            revert StreamEntropyCoordinator.ProviderConfigurationChanged(provider);
        }
        if (!IERC165(provider).supportsInterface(type(IStreamEntropyProviderFeeQuote).interfaceId))
        {
            revert StreamEntropyCoordinator.RevealFeeQuoteUnavailable(provider);
        }
        bytes memory data =
            abi.encodeCall(IStreamEntropyProviderFeeQuote.contextIndependentRequestFee, ());
        bool success;
        uint256 size;
        uint256 quote;
        assembly ("memory-safe") {
            let result := mload(0x40)
            success := staticcall(gas(), provider, add(data, 32), mload(data), result, 32)
            size := returndatasize()
            quote := mload(result)
        }
        if (!success || size != 32) {
            revert StreamEntropyCoordinator.RevealFeeQuoteUnavailable(provider);
        }
        if (fee < quote) revert StreamEntropyCoordinator.RevealFeeBelowQuote(fee, quote);
    }
}
