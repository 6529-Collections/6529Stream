// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamGovernanceStagePlan.sol";
import "./StreamEntropyLifecyclePlan.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";

/// @notice Plans for a distinct configured ordinary backup, not a cheaper registration-only mode.
/// @dev Deployment/configuration is separate from ACTIVE registration and class-3 selection.
library StreamEntropyFallbackPlan {
    bytes32 internal constant ENTROPY = keccak256("ENTROPY_COORDINATOR");

    struct Collection {
        uint256 id;
        address provider;
        bytes32 salt;
        bool publicRequests;
        uint64 timeoutBlocks;
        uint8 requestMode;
        bytes32 revealOwnerRole;
        uint64 requestSLOBlocks;
        uint256 revealFee;
    }

    struct Checkpoint {
        uint16 schemaVersion;
        uint256 chainId;
        address core;
        address authority;
        address primary;
        bytes32 primaryCodeHash;
        address backup;
        bytes32 backupCodeHash;
        bytes32 deploymentManifestHash;
        bytes32 collectionConfigurationHash;
        bytes32 historicalSubjectsManifestHash;
    }

    function deploymentConfig(
        StreamEntropyCoordinator primary,
        IStreamTimeParameterHost.TimeParameterConfig[3] memory times,
        bytes32 deploymentHash,
        string memory uri,
        bytes32 moduleHash
    ) internal view returns (StreamEntropyCoordinator.DeploymentConfig memory) {
        require(address(primary).code.length != 0, "primary absent");
        return StreamEntropyCoordinator.DeploymentConfig(
            address(primary.core()),
            primary.authority(),
            address(primary.roleRegistry()),
            times,
            deploymentHash,
            uri,
            moduleHash
        );
    }

    function requirePair(StreamEntropyCoordinator primary, StreamEntropyCoordinator backup)
        internal
        view
    {
        require(
            address(primary) != address(backup) && address(primary).code.length != 0
                && address(backup).code.length != 0,
            "distinct deployed entropy instances"
        );
        require(
            address(primary.core()) == address(backup.core())
                && primary.authority() == backup.authority()
                && address(primary.roleRegistry()) == address(backup.roleRegistry()),
            "fallback foundation mismatch"
        );
    }

    function record(StreamEntropyCoordinator backup, uint32 moduleGas)
        internal
        view
        returns (StreamModuleRegistration memory)
    {
        (string memory uri, bytes32 hash) = backup.streamModuleManifest();
        return StreamModuleRegistration(
            address(backup),
            ENTROPY,
            backup.streamModuleVersion(),
            type(IStreamEntropyCoordinator).interfaceId,
            moduleGas,
            address(backup).codehash,
            backup.streamModuleDeploymentManifestHash(),
            hash,
            uri
        );
    }

    function registration(
        StreamModuleRegistry registry,
        StreamEntropyCoordinator primary,
        StreamEntropyCoordinator backup,
        uint32 moduleGas
    ) internal view returns (GenesisBatch memory batch) {
        requirePair(primary, backup);
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](1);
        rows[0] = record(backup, moduleGas);
        batch.actionClass = 1;
        (batch.calls, batch.callDatas) = StreamCurrentStackPlan.registrationCalls(registry, rows);
    }

    function configureCollection(StreamEntropyCoordinator backup, Collection memory row)
        internal
        pure
        returns (GovernanceCall memory call_, bytes memory data)
    {
        data = abi.encodeCall(
            backup.configureCollection,
            (row.id, row.provider, row.salt, row.publicRequests, row.timeoutBlocks)
        );
        call_ = StreamCurrentStackPlan.call(
            address(backup), data, keccak256(abi.encode(address(backup), data)), 0, keccak256(data)
        );
    }

    /// @notice The actual current ROLE_ENTROPY_ADMIN calls this after provider/collection admission.
    function revealConfiguration(
        StreamEntropyCoordinator backup,
        Collection memory row,
        address administrator
    ) internal view returns (StreamGovernanceStagePlan.NextCall memory call_) {
        require(
            backup.roleRegistry().hasRole(keccak256("ROLE_ENTROPY_ADMIN"), administrator),
            "current entropy administrator"
        );
        call_ = StreamGovernanceStagePlan.NextCall(
            administrator,
            address(backup),
            0,
            abi.encodeCall(
                backup.configureCollectionRevealPolicy,
                (row.id, row.requestMode, row.revealOwnerRole, row.requestSLOBlocks, row.revealFee)
            )
        );
    }

    function selection(
        StreamCore core,
        StreamModuleRegistry registry,
        StreamEntropyCoordinator primary,
        StreamEntropyCoordinator backup
    ) internal view returns (GenesisBatch memory batch) {
        requirePair(primary, backup);
        require(address(primary.core()) == address(core), "actual Core");
        StreamCorePointerState memory selected = StreamCurrentStackPlan.readPointer(core, ENTROPY);
        require(
            selected.target == address(primary) && selected.codeHash == address(primary).codehash,
            "original selected runtime"
        );
        StreamModuleRecord memory saved = registry.moduleRecord(address(backup));
        require(
            saved.status == ModuleRegistryStatus.ACTIVE
                && saved.runtimeCodeHash == address(backup).codehash,
            "standing ACTIVE backup"
        );
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](1);
        rows[0] = record(backup, saved.moduleGasLimit);
        bytes32[] memory kinds = new bytes32[](1);
        kinds[0] = ENTROPY;
        batch.actionClass = 3;
        (batch.calls, batch.callDatas) =
            StreamCurrentStackPlan.pointerCalls(core, registry, kinds, rows);
    }

    /// @notice Complete the original registry/pointer intent with its mandatory exact manifest tail.
    /// @dev Caller retains the actual payload bytes; no new manifest authority or bypass.
    function withManifestTail(
        GenesisBatch memory intent,
        StreamSystemManifest manifest,
        address payload,
        StreamSystemManifestUpdate memory update
    ) internal view returns (GenesisBatch memory batch) {
        require(intent.calls.length == 1 && intent.callDatas.length == 1, "single entropy intent");
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        GovernanceCall memory first = intent.calls[0];
        if (first.selector == StreamCore.updateSatellitePointer.selector) {
            require(
                first.target == manifest.core() && intent.actionClass == 3, "actual pointer intent"
            );
            bytes memory encoded = intent.callDatas[0];
            (bytes32 pointer, address target) = abi.decode(_arguments(encoded), (bytes32, address));
            require(pointer == ENTROPY && target.code.length != 0, "entropy pointer only");
            current.modules.entropyCoordinator = target;
        } else {
            require(
                first.selector == StreamModuleRegistry.registerModule.selector
                    && first.target == current.modules.moduleRegistry && intent.actionClass == 1,
                "actual registration intent"
            );
        }
        batch.actionClass = intent.actionClass;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        batch.calls[0] = first;
        batch.callDatas[0] = intent.callDatas[0];
        (batch.calls[1], batch.callDatas[1]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
    }

    function _arguments(bytes memory encoded) private pure returns (bytes memory result) {
        require(encoded.length == 68, "exact pointer calldata");
        result = new bytes(64);
        for (uint256 i; i < 64; ++i) {
            result[i] = encoded[i + 4];
        }
    }

    /// @dev Explicit supplied collection inventory; historicalSubjectsManifestHash must enumerate
    ///      all retained original token/scope subjects offchain. No completeness inferred here.
    function checkpoint(
        StreamEntropyCoordinator primary,
        StreamEntropyCoordinator backup,
        Collection[] memory collections,
        bytes32 historicalSubjectsManifestHash
    ) internal view returns (Checkpoint memory c) {
        requirePair(primary, backup);
        require(
            collections.length != 0 && historicalSubjectsManifestHash != 0, "explicit inventory"
        );
        for (uint256 i; i < collections.length; ++i) {
            Collection memory row = collections[i];
            require(row.id != 0 && (i == 0 || collections[i - 1].id < row.id), "sorted collections");
            (address provider, bool public_,, uint64 timeout,,, bytes32 salt) =
                backup.collectionEntropyConfig(row.id);
            IStreamRevealFeeEscrow.CollectionRevealPolicy memory reveal =
                backup.collectionRevealPolicy(row.id);
            require(
                provider == row.provider && public_ == row.publicRequests
                    && timeout == row.timeoutBlocks && salt == row.salt,
                "configured original collection tuple"
            );
            require(
                reveal.declared && reveal.requestMode == row.requestMode
                    && reveal.revealOwnerRole == row.revealOwnerRole
                    && reveal.requestSLOBlocks == row.requestSLOBlocks
                    && reveal.revealFeePerTokenWei == row.revealFee,
                "declared reveal tuple"
            );
            IStreamEntropyProviderLifecycle.ProviderRecord memory admitted =
                backup.entropyProviderRecord(provider);
            require(
                admitted.state == EntropyProviderState.ACTIVE
                    && admitted.runtimeCodeHash == provider.codehash && provider.code.length != 0,
                "active pinned backup provider"
            );
        }
        c = Checkpoint(
            1,
            block.chainid,
            address(primary.core()),
            primary.authority(),
            address(primary),
            address(primary).codehash,
            address(backup),
            address(backup).codehash,
            backup.streamModuleDeploymentManifestHash(),
            keccak256(abi.encode(collections)),
            historicalSubjectsManifestHash
        );
    }
}
