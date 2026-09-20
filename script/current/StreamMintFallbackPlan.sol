// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackPlan.sol";
import "./StreamGenesisManifestPlan.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import {
    StreamMintFallbackRecovery
} from "../../smart-contracts/domains/mint/StreamMintFallbackRecovery.sol";
import {
    IStreamMintFallbackRecovery
} from "../../smart-contracts/interfaces/stream/mint/IStreamMintFallbackRecovery.sol";

/// @notice Stateless planning for a pre-approved, one-way, same-Ledger Manager fallback.
/// @dev No broadcasts, imports, snapshots or payloads are manufactured here. The caller supplies
/// reviewed pins and a complete real snapshot. Core and Ledger enforce readiness at execution.
library StreamMintFallbackPlan {
    bytes32 internal constant MANAGER = keccak256("MINT_MANAGER");
    bytes32 internal constant LEDGER = keccak256("MINT_LEDGER");
    bytes32 private constant REGISTRY = keccak256("MODULE_REGISTRY");

    struct Configuration {
        uint256 chainId;
        StreamCore core;
        StreamMintLedger ledger;
        StreamMintManager primary;
        StreamMintManager fallbackManager;
        StreamModuleRegistry registry;
        address governance;
        bytes32 coreCodeHash;
        bytes32 ledgerCodeHash;
        bytes32 primaryCodeHash;
        bytes32 fallbackCodeHash;
        bytes32 registryCodeHash;
        bytes32 governanceCodeHash;
        bytes32 moduleVersion;
        bytes32 deploymentManifestHash;
        bytes32 moduleManifestHash;
        string moduleManifestURI;
        uint32 moduleGasLimit;
        address recorder;
        bytes32 recorderCodeHash;
    }

    struct Snapshot {
        uint64 snapshotBlock;
        bytes32 importRoot;
        bytes32 manifestHash;
    }

    /// @notice Deployment bindings and host-local gas registrations; no live phase is implied.
    /// @dev May precede initial pointer installation and fallback catalog registration.
    function validate(Configuration memory c) internal view {
        require(c.chainId == block.chainid, "fallback chain");
        require(address(c.primary) != address(c.fallbackManager), "distinct fallback required");
        _code(address(c.core), c.coreCodeHash);
        _code(address(c.ledger), c.ledgerCodeHash);
        _code(address(c.primary), c.primaryCodeHash);
        _code(address(c.fallbackManager), c.fallbackCodeHash);
        _code(address(c.registry), c.registryCodeHash);
        _code(c.governance, c.governanceCodeHash);
        require(
            c.ledger.isStreamMintLedger() && c.ledger.owner() == c.governance
                && address(c.registry.governanceExecutor()) == c.governance,
            "fallback authority"
        );
        StreamCorePointerState memory selected =
            StreamCurrentStackPlan.readPointer(c.core, REGISTRY);
        require(
            selected.target == address(c.registry) && selected.codeHash == c.registryCodeHash,
            "fallback canonical registry"
        );
        _manager(c, c.primary);
        _manager(c, c.fallbackManager);
        require(
            c.moduleVersion != 0 && c.deploymentManifestHash != 0 && c.moduleManifestHash != 0
                && bytes(c.moduleManifestURI).length != 0,
            "fallback registration metadata"
        );
        require((c.recorder == address(0)) == (c.recorderCodeHash == 0), "fallback recorder pin");
    }

    /// @dev MINT_MANAGER_FALLBACK is an inventory role, never a second Core pointer/module type.
    function fallbackRegistration(Configuration memory c)
        internal
        view
        returns (StreamModuleRegistration memory)
    {
        validate(c);
        return StreamModuleRegistration(
            address(c.fallbackManager),
            MANAGER,
            c.moduleVersion,
            type(IStreamMintManager).interfaceId,
            c.moduleGasLimit,
            c.fallbackCodeHash,
            c.deploymentManifestHash,
            c.moduleManifestHash,
            c.moduleManifestURI
        );
    }

    /// @notice ACTIVE reserve readiness is distinct from completed migration readiness.
    function requireReserveReady(Configuration memory c) internal view {
        validate(c);
        _canonicalPointers(c);
        StreamModuleRecord memory r = c.registry.moduleRecord(address(c.fallbackManager));
        require(
            c.registry
                .isModuleEligible(
                    address(c.fallbackManager), MANAGER, type(IStreamMintManager).interfaceId
                ) && r.status == ModuleRegistryStatus.ACTIVE
            && r.runtimeCodeHash == c.fallbackCodeHash && r.moduleVersion == c.moduleVersion
            && r.moduleGasLimit == c.moduleGasLimit
            && r.deploymentManifestHash == c.deploymentManifestHash
            && r.moduleManifestHash == c.moduleManifestHash
            && keccak256(bytes(r.moduleManifestURI)) == keccak256(bytes(c.moduleManifestURI)),
            "fallback ACTIVE reserve"
        );
        require(
            c.ledger.ledgerWriter(address(c.fallbackManager))
                && c.ledger.ledgerWriterRetiredAt(address(c.fallbackManager)) == 0,
            "fallback writer unavailable"
        );
        if (c.recorder != address(0)) {
            _code(c.recorder, c.recorderCodeHash);
            _recorder(c, c.primary);
            _recorder(c, c.fallbackManager);
        }
    }

    /// @notice Original owner call under an explicit class-0 tightening policy in the genesis catalog.
    /// @dev Permanent writer retirement is tightening; Ledger retains its owner check. Resolve old
    /// mint obligations or establish their supported refund exits before freezing the real snapshot.
    function retirementCall(Configuration memory c)
        internal
        view
        returns (GovernanceCall memory operation, bytes memory data)
    {
        requireReserveReady(c);
        _primarySelected(c);
        (bool classified, bytes32 classifiedHash,,) = IStreamGovernanceExecutor(c.governance)
            .tighteningCallConfig(address(c.ledger), c.ledger.retireLedgerWriter.selector);
        require(classified && classifiedHash == c.ledgerCodeHash, "fallback retirement classifier");
        require(c.ledger.ledgerWriterRetiredAt(address(c.primary)) == 0, "primary already retired");
        data = abi.encodeCall(c.ledger.retireLedgerWriter, (address(c.primary)));
        operation = _ordinary(address(c.ledger), data);
    }

    /// @notice Genesis prerequisite: exact isolated class-1 admission of permanent retirement.
    /// @dev A class-0 action catalog row alone does not classify its selector as tightening.
    /// Execute this self-call alone, before operational exposure and any incident SLA starts.
    function retirementClassificationCall(Configuration memory c)
        internal
        view
        returns (GovernanceCall memory operation, bytes memory data)
    {
        validate(c);
        IStreamGovernanceExecutor executor = IStreamGovernanceExecutor(c.governance);
        address target = address(c.ledger);
        bytes4 selector = c.ledger.retireLedgerWriter.selector;
        (bool enabled,, uint64 revision, bytes32 oldHash) =
            executor.tighteningCallConfig(target, selector);
        require(!enabled && revision < type(uint64).max, "fresh retirement classifier");
        bytes32 kind = keccak256("6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"),
                block.chainid,
                c.governance,
                kind,
                target,
                selector
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"),
                block.chainid,
                c.governance,
                kind,
                target,
                selector,
                true,
                c.ledgerCodeHash,
                revision + uint64(1)
            )
        );
        data = abi.encodeCall(executor.setTighteningCall, (target, selector, true));
        operation = StreamCurrentStackPlan.call(c.governance, data, scope, oldHash, next);
    }

    /// @notice Exact original class-1 import commitment, schedulable before writer retirement.
    /// @dev Ledger rechecks permanent retirement and snapshot ordering when this call executes.
    function importCommitCall(Configuration memory c, Snapshot memory s)
        internal
        view
        returns (GovernanceCall memory operation, bytes memory data)
    {
        requireReserveReady(c);
        _primarySelected(c);
        require(s.snapshotBlock != 0 && s.snapshotBlock <= block.number, "fallback snapshot block");
        require(s.importRoot != 0 && s.manifestHash != 0, "fallback snapshot commitment");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_SCOPE_V1"),
                block.chainid,
                address(c.ledger),
                address(c.fallbackManager)
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_IMPORT_COMMITMENT_V1"),
                scope,
                address(c.ledger),
                address(c.primary),
                address(c.fallbackManager),
                s.snapshotBlock,
                s.importRoot,
                s.manifestHash
            )
        );
        data = abi.encodeCall(
            c.ledger.commitCounterImportRoot,
            (
                address(c.ledger),
                address(c.primary),
                address(c.fallbackManager),
                s.snapshotBlock,
                s.importRoot,
                s.manifestHash
            )
        );
        operation = StreamCurrentStackPlan.call(address(c.ledger), data, scope, 0, next);
    }

    /// @notice Original owner-only Manager import call; proofs remain Ledger-verified.
    function importStateCall(
        Configuration memory c,
        IStreamMintManagerImport.ImportBatch memory batch
    ) internal view returns (GovernanceCall memory operation, bytes memory data) {
        requireReserveReady(c);
        uint256 count = batch.counters.length + batch.nullifiers.length;
        require(
            batch.importRoot != 0 && count != 0 && count <= 32
                && batch.counters.length == batch.counterProofs.length
                && batch.nullifiers.length == batch.nullifierProofs.length,
            "fallback import batch"
        );
        _knownRoot(c, batch.importRoot);
        data = abi.encodeCall(c.fallbackManager.importMintState, (abi.encode(batch)));
        operation = _ordinary(address(c.fallbackManager), data);
    }

    /// @notice Permissionless original copying call; no inventory is synthesized.
    function copyDefinitionsCall(Configuration memory c, bytes32 root, uint256 maxCount)
        internal
        view
        returns (GovernanceCall memory operation, bytes memory data)
    {
        _copyInputs(c, root, maxCount);
        data = abi.encodeCall(c.ledger.importCounterDefinitions, (root, maxCount));
        operation = _ordinary(address(c.ledger), data);
    }

    /// @notice Permissionless original bounded ancestry copying call.
    function copyAncestorsCall(Configuration memory c, bytes32 root, uint256 maxCount)
        internal
        view
        returns (GovernanceCall memory operation, bytes memory data)
    {
        _copyInputs(c, root, maxCount);
        data = abi.encodeCall(c.ledger.importMintAncestors, (root, maxCount));
        operation = _ordinary(address(c.ledger), data);
    }

    /// @notice Permissionless completion against the supplied genuine descriptor proof.
    /// @dev Zero counts are not evidence of completeness; only Ledger verifies this descriptor.
    function completeImportCall(
        Configuration memory c,
        bytes32 root,
        uint64 counterCount,
        uint64 nullifierCount,
        bytes32[] memory descriptorProof
    ) internal view returns (GovernanceCall memory operation, bytes memory data) {
        requireReserveReady(c);
        require(root != 0, "fallback import root");
        _knownRoot(c, root);
        data = abi.encodeCall(
            c.ledger.completeCounterImport, (root, counterCount, nullifierCount, descriptorProof)
        );
        operation = _ordinary(address(c.ledger), data);
    }

    /// @notice Exact class-3 Manager pointer and SystemManifest tail; Ledger pointer is unchanged.
    /// @dev Can be scheduled promptly after an incident while actual import is still pending.
    /// A retired primary cannot be reused as the reserve by swapping Configuration addresses.
    function activationCalls(
        Configuration memory c,
        StreamSystemManifest manifest,
        address payloadRoot,
        StreamSystemManifestUpdate memory update
    ) internal view returns (GovernanceCall[] memory calls, bytes[] memory data) {
        requireReserveReady(c);
        _primarySelected(c);
        StreamCorePointerState memory manifestPointer =
            StreamCurrentStackPlan.readPointer(c.core, keccak256("SYSTEM_MANIFEST"));
        require(
            manifestPointer.target == address(manifest)
                && manifestPointer.codeHash == address(manifest).codehash
                && manifest.core() == address(c.core)
                && manifest.governanceExecutor() == c.governance,
            "fallback canonical manifest"
        );
        StreamGovernanceEvidence.verifyManifestPayload(payloadRoot, update.manifestHash);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        require(
            current.modules.mintManager == address(c.primary)
                && current.modules.mintLedger == address(c.ledger)
                && current.modules.moduleRegistry == address(c.registry)
                && current.modules.streamAdminsOrGovernance == c.governance,
            "fallback manifest bindings"
        );
        StreamCorePointerState memory previous = StreamCurrentStackPlan.readPointer(c.core, MANAGER);
        require(!previous.frozen, "fallback pointer frozen");
        StreamCorePointerState memory next = StreamCurrentStackPlan.pointerState(
            address(c.registry), fallbackRegistration(c), false, previous.revision + 1
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            StreamCurrentStackPlan.pointerTransitionHashes(c.core, MANAGER, previous, next);
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        data[0] =
            abi.encodeCall(c.core.updateSatellitePointer, (MANAGER, address(c.fallbackManager)));
        calls[0] = StreamCurrentStackPlan.call(address(c.core), data[0], scope, before_, after_);
        current.modules.mintManager = address(c.fallbackManager);
        (calls[1], data[1]) = StreamGenesisManifestPlan.publicationCall(
            manifest, payloadRoot, update, current.modules
        );
    }

    /// @notice Incident-only class-3 pointer, exact prepared abort, then manifest publication.
    /// @dev Requires the separately reviewed recovery-capable runtime pin and real pending facts.
    /// Existing completed NFTs, sale liabilities and Ledger receipts are never mutated here.
    function incidentActivationCalls(
        Configuration memory c,
        StreamSystemManifest manifest,
        address payloadRoot,
        StreamSystemManifestUpdate memory update,
        uint256 tokenId,
        bytes32 operationId
    ) internal view returns (GovernanceCall[] memory calls, bytes[] memory data) {
        (GovernanceCall[] memory ordinary, bytes[] memory ordinaryData) =
            activationCalls(c, manifest, payloadRoot, update);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamMintFallbackRecovery.transition(
            address(c.fallbackManager), tokenId, operationId
        );
        calls = new GovernanceCall[](3);
        data = new bytes[](3);
        (calls[0], data[0]) = (ordinary[0], ordinaryData[0]);
        data[1] =
            abi.encodeCall(IStreamMintFallbackRecovery.recoverPreparedMint, (tokenId, operationId));
        calls[1] = StreamCurrentStackPlan.call(
            address(c.fallbackManager), data[1], scope, oldHash, newHash
        );
        (calls[2], data[2]) = (ordinary[1], ordinaryData[1]);
    }

    function _manager(Configuration memory c, StreamMintManager manager) private view {
        require(
            manager.isStreamMintManager()
                && manager.supportsInterface(type(IStreamMintManager).interfaceId)
                && address(manager.core()) == address(c.core)
                && address(manager.mintLedger()) == address(c.ledger)
                && address(manager.moduleRegistry()) == address(c.registry)
                && manager.owner() == c.governance && manager.governanceAuthority() == c.governance,
            "fallback Manager binding"
        );
        _gas(manager, keccak256("6529STREAM_GGP_MINT_GATE_GAS_LIMIT"), 400_000);
        _gas(manager, keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT"), 150_000);
    }

    function _gas(StreamMintManager manager, bytes32 id, uint256 expectedFloor) private view {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            manager.gasParameterInfo(id);
        require(
            floor == expectedFloor && value >= floor && failureClass == 2 && revision != 0,
            "fallback gas registration"
        );
    }

    function _recorder(Configuration memory c, StreamMintManager manager) private view {
        (address recorder, bytes32 hash, uint64 boundAt, uint64 revision) =
            manager.preparedNativeRecorder();
        require(recorder == c.recorder && hash == c.recorderCodeHash, "fallback recorder binding");
        StreamPreparedNativeSettlementAdmission.requireRecorder(
            address(c.registry), recorder, boundAt, revision
        );
        require(
            StreamPreparedNativeSettlementValidation.addressWord(recorder, "core()")
                    == address(c.core)
                && StreamPreparedNativeSettlementValidation.addressWord(
                    recorder, "moduleRegistry()"
                ) == address(c.registry)
                && StreamPreparedNativeSettlementValidation.word(recorder, "coreCodeHash()")
                == c.coreCodeHash
                && StreamPreparedNativeSettlementValidation.word(
                    recorder, "moduleRegistryCodeHash()"
                ) == c.registryCodeHash,
            "fallback recorder context"
        );
    }

    function _canonicalPointers(Configuration memory c) private view {
        StreamCorePointerState memory p = StreamCurrentStackPlan.readPointer(c.core, LEDGER);
        require(
            p.target == address(c.ledger) && p.codeHash == c.ledgerCodeHash
                && c.registry
                    .isModuleEligible(
                        address(c.ledger), LEDGER, type(IStreamMintLedger).interfaceId
                    ),
            "fallback canonical Ledger"
        );
        p = StreamCurrentStackPlan.readPointer(c.core, MANAGER);
        require(
            (p.target == address(c.primary) && p.codeHash == c.primaryCodeHash)
                || (p.target == address(c.fallbackManager) && p.codeHash == c.fallbackCodeHash),
            "fallback current Manager"
        );
    }

    function _primarySelected(Configuration memory c) private view {
        require(
            StreamCurrentStackPlan.readPointer(c.core, MANAGER).target == address(c.primary),
            "fallback already selected"
        );
    }

    function _copyInputs(Configuration memory c, bytes32 root, uint256 maxCount) private view {
        requireReserveReady(c);
        require(root != 0 && maxCount != 0 && maxCount <= 32, "fallback copy bounds");
        _knownRoot(c, root);
    }

    /// @dev Unknown supplied roots may be planned before commitment; known roots must be this pair.
    function _knownRoot(Configuration memory c, bytes32 root) private view {
        IStreamMintLedgerImport.ImportCommitment memory saved = c.ledger.mintImportCommitment(root);
        require(
            saved.successorManager == address(0)
                || (saved.predecessorLedger == address(c.ledger)
                    && saved.predecessorManager == address(c.primary)
                    && saved.successorManager == address(c.fallbackManager)),
            "fallback import pair"
        );
    }

    function _ordinary(address target, bytes memory data)
        private
        pure
        returns (GovernanceCall memory)
    {
        return StreamCurrentStackPlan.call(
            target, data, keccak256(abi.encode(target, data)), 0, keccak256(data)
        );
    }

    function _code(address target, bytes32 expected) private view {
        require(
            StreamSettlementAdmission.isContract(target) && expected != 0
                && target.codehash == expected,
            "fallback code pin"
        );
    }
}
