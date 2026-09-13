// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityDiagnostics.sol";
import "./StreamFinalityRecordState.sol";

import "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../vendor/openzeppelin/IERC165.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalitySource.sol";
import "../../interfaces/stream/finality/IStreamCanonicalArtworkFinality.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeEvidence.sol";
import "../../interfaces/stream/finality/IStreamArtistSanctionPreparation.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceDiscoveryBinding.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityEvidenceBinding.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../parameters/StreamGasParameterHost.sol";
import "./StreamArtworkFinalityStorage.sol";
import "./StreamFinalityHashes.sol";
import "./StreamFinalityPreparation.sol";
import "./StreamFinalityGovernanceWitness.sol";
import "./StreamFinalitySanctionArchive.sol";
import "../modules/StreamModuleBase.sol";
import "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import "../../interfaces/stream/finality/StreamFinalityDeploymentTypes.sol";
import "../../interfaces/stream/finality/IStreamFinalityMetadataReads.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionReads.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Five-scope artwork finality with the canonical Executor's terminal action lifecycle.
/// @dev Current candidate preparation validates fixed Core, metadata provider, discovery and
///      sanction joins. The Executor owns scheduling, delay and veto; local lifecycle selectors
///      are retired under ADR 0039. Stored records and frozen routes retain historical meaning.
contract StreamArtworkFinalityRegistry is
    StreamArtworkFinalityStorage,
    StreamGasParameterHost,
    StreamModuleBase,
    IStreamArtworkFinalityRegistry,
    IStreamArtworkScopedFrozenRouteRegistry,
    IStreamCanonicalArtworkFinality,
    IStreamArtistSanctionPreparation,
    IStreamFinalitySanctionArchive
{
    error FinalityZeroAddress();
    error FinalityModuleConfigurationInvalid();
    error FinalityDependencyHasNoCode(address dependency);
    error FinalityAdapterInterfaceUnsupported(address adapter);
    error FinalityAdapterBindingMismatch(
        address expectedCore, address actualCore, address expectedMetadata, address actualMetadata
    );
    error FinalityAdapterReturnShapeInvalid(bytes4 selector, uint256 byteLength);
    error FinalityAdapterSemanticProbeInvalid(bytes4 selector);

    /// @notice Event schema version carried by every registry event.
    uint16 public constant FINALITY_EVENT_SCHEMA_VERSION = 1;

    /// @notice Component-count cap ([LTA-FINALITY] planning value, pinned at release).
    uint256 public constant MAX_FINALITY_COMPONENTS = 32;

    /// @notice Calldata cap for finality entries and staged manifest bytes (planning value).
    uint256 public constant MAX_FINALITY_CALLDATA_BYTES = 32_768;

    /// @notice Terminal-freeze veto window floor ([GOV-WINDOWS] rule 2; ADR 0011 decision R10).
    uint64 public constant TERMINAL_FREEZE_VETO_FLOOR = 72 hours;

    /// @notice Open-to-execute window floor for delayed classes ([GOV-WINDOWS] rule 1).
    uint64 public constant TERMINAL_FREEZE_EXECUTION_WINDOW_FLOOR = 7 days;

    /// @notice Legacy diagnostic planning constant retained in the ABI.
    /// @dev Actual bounded reads use the governed parameter identified by the key below.
    uint256 public constant FINALITY_COMPONENT_READ_GAS = 30_000;

    /// @dev Strict reads retain enough gas to decode or emit a typed failure. Capped diagnostics
    ///      retain only the smaller reserve required for their compact false return.
    uint256 private constant FINALITY_STRICT_PARENT_GAS_RESERVE = 100_000;
    uint256 private constant FINALITY_DIAGNOSTIC_PARENT_GAS_RESERVE = 10_000;

    /// @notice Pinned GGP key for the diagnostic read budget.
    bytes32 public constant GGP_FINALITY_COMPONENT_READ_GAS_KEY =
        StreamFinalityDomains.GGP_FINALITY_COMPONENT_READ_GAS;

    IStreamCoreFinalitySource public immutable coreReads;
    IStreamCoreFinalityAdapter public immutable coreFinalityAdapter;
    IStreamFinalityMetadataReads public immutable metadataReads;
    address public immutable scopeEvidenceProvider;
    /// @notice Original provider runtime pin for publication before a content root exists.
    function scopeEvidenceProviderCodeHash() external view returns (bytes32) {
        return _providerCodeHash;
    }
    address public immutable override artifactCoverage;
    bytes32 private immutable _artifactCodeHash;
    IStreamFinalitySanctionReads public immutable sanctionReads;
    address public immutable finalityRoleRegistry;
    bytes32 private immutable _executorCodeHash;
    bytes32 private immutable _rolesCodeHash;
    bytes32 private immutable _coreCodeHash;
    bytes32 private immutable _metadataCodeHash;
    bytes32 private immutable _providerCodeHash;
    bytes32 private immutable _adapterCodeHash;
    bytes32 private immutable _discoveryCodeHash;

    /// @notice Mandatory discovery module (the metadata router).
    address public immutable finalityDiscovery;

    mapping(bytes32 => StreamFinalityExecutionWitness) private _executionWitnesses;
    mapping(bytes32 => StreamFinalitySanctionArchiveWitness) private _archiveWitnesses;

    constructor(
        address coreReads_,
        address metadataReads_,
        address coreFinalityAdapter_,
        address sanctionReads_,
        address governanceAuthority_,
        address finalityDiscovery_,
        GasParameterConfig memory componentReadGas,
        StreamFinalityDeploymentConfiguration memory deployment
    )
        StreamGasParameterHost(governanceAuthority_)
        StreamModuleBase(
            keccak256("6529stream.canonical-artwork-finality.schema.v1"),
            address(0),
            deployment.deploymentManifestHash,
            deployment.manifestURI,
            deployment.manifestHash
        )
    {
        if (
            deployment.deploymentManifestHash == 0 || deployment.manifestHash == 0
                || bytes(deployment.manifestURI).length > 2048
        ) revert FinalityModuleConfigurationInvalid();
        if (
            keccak256(bytes(componentReadGas.name)) != keccak256("FINALITY_COMPONENT_READ_GAS")
                || componentReadGas.floor < 50000 || componentReadGas.failureClass != 2
                || componentReadGas.genesisValue > type(uint256).max / 64
        ) {
            revert GasParameterInvalidConfig(GGP_FINALITY_COMPONENT_READ_GAS_KEY);
        }
        _registerGasParameter(componentReadGas);
        _requireCode(deployment.artifactCoverage);
        if (
            _readExactAddress(
                        deployment.artifactCoverage, IStreamFinalityArtifactCoverage.core.selector
                    ) != coreReads_
                || _readExactAddress(
                        deployment.artifactCoverage,
                        IStreamFinalityArtifactCoverage.finalityRegistry.selector
                    ) != address(this)
                || _readExactAddress(
                        deployment.artifactCoverage,
                        IStreamGasParameterHost.governanceAuthority.selector
                    ) != governanceAuthority_
        ) revert FinalityCurrentBindingInvalid(deployment.artifactCoverage);
        artifactCoverage = deployment.artifactCoverage;
        _artifactCodeHash = deployment.artifactCoverage.codehash;
        if (
            coreReads_ == address(0) || metadataReads_ == address(0)
                || coreFinalityAdapter_ == address(0) || sanctionReads_ == address(0)
                || governanceAuthority_ == address(0) || finalityDiscovery_ == address(0)
        ) {
            revert FinalityZeroAddress();
        }
        _requireCode(coreReads_);
        _requireCode(metadataReads_);
        _requireCode(coreFinalityAdapter_);
        _requireCode(governanceAuthority_);
        _requireCode(finalityDiscovery_);
        _requireAdapter(coreFinalityAdapter_, coreReads_, metadataReads_);
        address provider = _readExactAddress(
            finalityDiscovery_,
            IStreamFinalityEvidenceDiscoveryBinding.scopeEvidenceProvider.selector
        );
        _requireCode(provider);
        if (
            _readExactAddress(provider, IStreamFinalityScopeEvidence.core.selector) != coreReads_
                || _readExactAddress(
                        provider, IStreamFinalityEvidenceProvider.metadataHost.selector
                    ) != metadataReads_
                || _readExactAddress(
                        coreFinalityAdapter_,
                        IStreamCoreFinalityEvidenceBinding.evidenceProvider.selector
                    ) != provider
        ) revert FinalityCurrentBindingInvalid(provider);
        scopeEvidenceProvider = provider;
        coreReads = IStreamCoreFinalitySource(coreReads_);
        metadataReads = IStreamFinalityMetadataReads(metadataReads_);
        coreFinalityAdapter = IStreamCoreFinalityAdapter(coreFinalityAdapter_);
        sanctionReads = IStreamFinalitySanctionReads(sanctionReads_);
        address roles = _readExactAddress(
            governanceAuthority_, IStreamFinalityGovernanceBindings.roleRegistry.selector
        );
        _requireCode(roles);
        if (
            _readExactAddress(roles, IStreamFinalityGovernanceBindings.owner.selector)
                != governanceAuthority_
        ) revert FinalityCurrentBindingInvalid(roles);
        finalityRoleRegistry = roles;
        _executorCodeHash = governanceAuthority_.codehash;
        _rolesCodeHash = roles.codehash;
        _coreCodeHash = coreReads_.codehash;
        _metadataCodeHash = metadataReads_.codehash;
        _providerCodeHash = provider.codehash;
        _adapterCodeHash = coreFinalityAdapter_.codehash;
        _discoveryCodeHash = finalityDiscovery_.codehash;
        finalityDiscovery = finalityDiscovery_;
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("ARTWORK_FINALITY_REGISTRY");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.canonical-artwork-finality.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamArtworkFinalityRegistry).interfaceId;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamArtworkFinalityRegistry).interfaceId
            || id == type(IStreamArtworkScopedFrozenRouteRegistry).interfaceId
            || id == type(IStreamCanonicalArtworkFinality).interfaceId
            || id == type(IStreamArtistSanctionPreparation).interfaceId
            || id == type(IStreamFinalitySanctionArchive).interfaceId || super.supportsInterface(id);
    }

    function _requireCode(address dependency) private view {
        if (dependency.code.length == 0) {
            revert FinalityDependencyHasNoCode(dependency);
        }
    }

    function _requireAdapter(address adapter, address expectedCore, address expectedMetadata)
        private
        view
    {
        if (
            !_readExactInterfaceSupport(adapter, type(IERC165).interfaceId)
                || !_readExactInterfaceSupport(
                    adapter, type(IStreamCoreFinalityAdapter).interfaceId
                ) || _readExactInterfaceSupport(adapter, 0xffffffff)
        ) {
            revert FinalityAdapterInterfaceUnsupported(adapter);
        }
        address actualCore = _readExactAddress(adapter, IStreamCoreFinalityAdapter.core.selector);
        address actualMetadata =
            _readExactAddress(adapter, IStreamCoreFinalityAdapter.collectionMetadata.selector);
        if (actualCore != expectedCore || actualMetadata != expectedMetadata) {
            revert FinalityAdapterBindingMismatch(
                expectedCore, actualCore, expectedMetadata, actualMetadata
            );
        }
        bytes4 collectionSelector = IStreamCoreFinalityAdapter.coreCollectionFinalityFacts.selector;
        bytes memory collectionResult = _readExactAdapterResult(
            adapter,
            collectionSelector,
            abi.encodeWithSelector(collectionSelector, uint256(0)),
            9 * 32
        );
        _requireCanonicalCollectionProbe(collectionSelector, collectionResult);

        bytes4 scopedSelector = IStreamCoreFinalityAdapter.scopedCoreFinalityFacts.selector;
        bytes memory scopedResult = _readExactAdapterResult(
            adapter,
            scopedSelector,
            abi.encodeWithSelector(
                scopedSelector,
                StreamCoreFinalityScopeQuery({
                    scopeType: type(uint8).max, collectionId: 0, tokenId: 0, scopeId: bytes32(0)
                })
            ),
            13 * 32
        );
        _requireCanonicalInvalidScopeProbe(scopedSelector, scopedResult);
    }

    function _readExactInterfaceSupport(address adapter, bytes4 interfaceId)
        private
        view
        returns (bool supported)
    {
        (bool success,, bytes memory result) = _readExactStatic(
            adapter, abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId), 32
        );
        if (!success) {
            revert FinalityAdapterInterfaceUnsupported(adapter);
        }
        uint256 word;
        assembly ("memory-safe") {
            word := mload(add(result, 0x20))
        }
        if (word > 1) {
            revert FinalityAdapterInterfaceUnsupported(adapter);
        }
        return word == 1;
    }

    function _readExactAddress(address adapter, bytes4 selector)
        private
        view
        returns (address value)
    {
        (bool success, uint256 actualLength, bytes memory result) =
            _readExactStatic(adapter, abi.encodeWithSelector(selector), 32);
        if (!success) {
            revert FinalityAdapterReturnShapeInvalid(selector, actualLength);
        }
        uint256 rawAddress = _adapterResultWord(result, 0);
        if (rawAddress > type(uint160).max) {
            revert FinalityAdapterSemanticProbeInvalid(selector);
        }
        value = address(uint160(rawAddress));
    }

    function _readExactAdapterResult(
        address adapter,
        bytes4 selector,
        bytes memory callData,
        uint256 expectedLength
    ) private view returns (bytes memory) {
        (bool success, uint256 actualLength, bytes memory result) =
            _readExactStatic(adapter, callData, expectedLength);
        if (!success) {
            revert FinalityAdapterReturnShapeInvalid(selector, actualLength);
        }
        return result;
    }

    /// @dev Exact fixed-buffer admission read. Returndata beyond `expectedLength` is never copied,
    ///      so an untrusted constructor dependency cannot force attacker-sized memory expansion.
    function _readExactStatic(address target, bytes memory callData, uint256 expectedLength)
        private
        view
        returns (bool readable, uint256 actualLength, bytes memory result)
    {
        result = new bytes(expectedLength);
        uint256 availableGas = gasleft();
        uint256 forwardedGas = _componentReadGas();
        if (
            forwardedGas > type(uint256).max / 64
                || availableGas
                    <= forwardedGas + (forwardedGas + 62) / 63 + FINALITY_STRICT_PARENT_GAS_RESERVE
        ) {
            return (false, 0, result);
        }
        assembly ("memory-safe") {
            readable := staticcall(
                forwardedGas,
                target,
                add(callData, 0x20),
                mload(callData),
                add(result, 0x20),
                expectedLength
            )
            actualLength := returndatasize()
            if iszero(eq(actualLength, expectedLength)) { readable := 0 }
        }
    }

    function _requireCanonicalCollectionProbe(bytes4 selector, bytes memory result) private pure {
        if (
            _adapterResultWord(result, 0) > 1 || _adapterResultWord(result, 1) > 1
                || _adapterResultWord(result, 2) > type(uint8).max
                || _adapterResultWord(result, 3) > type(uint8).max
        ) {
            revert FinalityAdapterSemanticProbeInvalid(selector);
        }
    }

    function _requireCanonicalInvalidScopeProbe(bytes4 selector, bytes memory result) private pure {
        if (_adapterResultWord(result, 0) != 0 || _adapterResultWord(result, 1) != type(uint8).max)
        {
            revert FinalityAdapterSemanticProbeInvalid(selector);
        }
        for (uint256 i = 2; i < 13; i++) {
            if (_adapterResultWord(result, i) != 0) {
                revert FinalityAdapterSemanticProbeInvalid(selector);
            }
        }
    }

    function _adapterResultWord(bytes memory result, uint256 index)
        private
        pure
        returns (uint256 word)
    {
        assembly ("memory-safe") {
            word := mload(add(add(result, 0x20), mul(index, 0x20)))
        }
    }

    /// @notice Returns true for deployment validation.
    function isStreamArtworkFinalityRegistry() external pure returns (bool) {
        return true;
    }

    /// @notice The bound Core address used in every pinned hash preimage.
    function core() public view returns (address) {
        return address(coreReads);
    }

    // ------------------------------------------------------------------
    // Terminal-freeze staging (single governed freeze path)
    // ------------------------------------------------------------------

    /// @notice Stages the irreversible artwork finality for `scope` under the TERMINAL_FREEZE
    ///         class: delay plus an independent veto guardian ([LTA-FREEZE] rule 4).
    function scheduleArtworkTerminalFreeze(
        StreamFinalityScope calldata scope,
        bytes32 expectedFinalityRecordHash,
        uint64 notBefore,
        uint64 expiresAfter
    ) external override {
        revert FinalityLocalLifecycleRetired();
    }

    /// @notice Guardian veto, valid while the action is scheduled and before `notBefore`.
    /// @dev The guardian is re-resolved through the authority at veto time — a role reference,
    ///      never the frozen address captured at scheduling (ADR 0004 execution rules).
    function vetoArtworkTerminalFreeze(StreamFinalityScope calldata scope, bytes32 reasonHash)
        external
        override
    {
        revert FinalityLocalLifecycleRetired();
    }

    /// @notice Cancels a scheduled terminal freeze before execution ([LTA-GOV] rule 3).
    function cancelArtworkTerminalFreeze(StreamFinalityScope calldata scope, bytes32 reasonHash)
        external
        override
    {
        revert FinalityLocalLifecycleRetired();
    }

    /// @notice Anyone may materialize the virtual expiry of an overdue scheduled freeze.
    function materializeExpiredArtworkTerminalFreeze(StreamFinalityScope calldata scope)
        external
        override
    {
        revert FinalityLocalLifecycleRetired();
    }

    /// @notice Stored staged action; a virtually expired action reports SCHEDULED until
    ///         materialized, matching the [GOV-WINDOWS] virtual-expiry model.
    function artworkTerminalFreezeAction(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamTerminalFreezeAction memory)
    {
        revert FinalityLocalLifecycleRetired();
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function artworkFreezeMode(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamArtworkFreezeMode)
    {
        StreamFinalityScope memory scopeMem = scope;
        if (scopeMem.scopeType == StreamFinalityScopeType.COLLECTION) {
            if (
                _collectionRecords[scopeMem.collectionId].finalized
                    && _isCanonicalScopeShape(scopeMem)
            ) {
                return StreamArtworkFreezeMode.INHERITED;
            }
            return StreamArtworkFreezeMode.NONE;
        }
        if (_scopedRecords[_scopeKey(scopeMem)].finalized) {
            return StreamArtworkFreezeMode.EXACT;
        }
        if (_collectionRecords[scopeMem.collectionId].finalized) {
            return StreamArtworkFreezeMode.INHERITED;
        }
        return StreamArtworkFreezeMode.NONE;
    }

    // ------------------------------------------------------------------
    // Manifest byte staging ([LTA-FINALITY] requirement 14)
    // ------------------------------------------------------------------

    /// @notice Stages canonical manifest bytes in registry storage, content-addressed by their
    ///         keccak256 hash; idempotent for already-staged content.
    function stageFinalityManifest(bytes calldata manifestBytes)
        external
        override
        returns (bytes32 contentHash)
    {
        uint256 byteLength = manifestBytes.length;
        if (byteLength == 0 || byteLength > MAX_FINALITY_CALLDATA_BYTES) {
            revert FinalityManifestBytesInvalid();
        }
        contentHash = keccak256(manifestBytes);
        if (_manifestBytes[contentHash].length == 0) {
            _manifestBytes[contentHash] = manifestBytes;
            emit FinalityManifestStaged(
                FINALITY_EVENT_SCHEMA_VERSION, contentHash, byteLength, msg.sender
            );
        }
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityManifestStored(bytes32 contentHash) external view override returns (bool) {
        return _manifestBytes[contentHash].length != 0;
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityManifestBytes(bytes32 contentHash)
        external
        view
        override
        returns (bytes memory)
    {
        return _manifestBytes[contentHash];
    }

    // ------------------------------------------------------------------
    // Finality execution
    // ------------------------------------------------------------------

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalizeCollectionArtwork(
        uint256 collectionId,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest
    ) external override {
        _finalize(
            _collectionScope(collectionId),
            components,
            expectedFinalityRecordHash,
            manifest,
            StreamFinalitySanctionArchiveProof(0, 0, 0),
            false
        );
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalizeArtworkScope(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest
    ) external override {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            revert FinalityScopeUsesCollectionEntry();
        }
        _finalize(
            scope,
            components,
            expectedFinalityRecordHash,
            manifest,
            StreamFinalitySanctionArchiveProof(0, 0, 0),
            false
        );
    }

    function finalizeCollectionArtworkWithArchive(
        uint256 collectionId,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest,
        StreamFinalitySanctionArchiveProof calldata proof
    ) external {
        _finalize(
            _collectionScope(collectionId),
            components,
            expectedFinalityRecordHash,
            manifest,
            proof,
            true
        );
    }

    function finalizeArtworkScopeWithArchive(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest,
        StreamFinalitySanctionArchiveProof calldata proof
    ) external {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            revert FinalityScopeUsesCollectionEntry();
        }
        _finalize(scope, components, expectedFinalityRecordHash, manifest, proof, true);
    }

    function _finalize(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest,
        StreamFinalitySanctionArchiveProof memory proof,
        bool hasArchive
    ) private {
        if (msg.sender != governanceAuthority) {
            revert StreamFinalityGovernanceWitness.FinalityExecutorOnly(msg.sender);
        }
        if (msg.data.length > MAX_FINALITY_CALLDATA_BYTES) {
            revert FinalityCalldataTooLarge(msg.data.length, MAX_FINALITY_CALLDATA_BYTES);
        }
        (
            StreamFinalityPreparation.Prepared memory ctx,
            StreamFinalityExecutionContext memory execution
        ) = _prepareExecution(scope, components, expectedFinalityRecordHash, manifest);
        bytes32 evidenceHash = _prepareArchive(components, execution, proof, hasArchive);
        StreamFinalityGovernanceWitness.Pins memory pins = StreamFinalityGovernanceWitness.Pins(
            governanceAuthority, _executorCodeHash, finalityRoleRegistry, _rolesCodeHash
        );
        StreamFinalityExecutionWitness memory witness =
            StreamFinalityGovernanceWitness.requireExecution(pins, execution, _componentReadGas());
        _executionWitnesses[ctx.finalityRecordHash] = witness;
        if (hasArchive) {
            _archiveWitnesses[ctx.finalityRecordHash] =
                StreamFinalitySanctionArchiveWitness(evidenceHash, proof);
        }
        _storeRecordAndEmit(scope, ctx, components, manifest);
        emit FinalityExecutionWitnessRecorded(
            1,
            ctx.finalityRecordHash,
            witness.actionId,
            witness.proposer,
            witness.reasonHash,
            witness.roleMutationHash,
            witness.roleRevision,
            execution.inputsHash
        );
        if (hasArchive) {
            emit FinalitySanctionArchiveWitnessRecorded(
                1,
                ctx.finalityRecordHash,
                evidenceHash,
                proof.sanctionRecordHash,
                proof.artifactHash,
                proof.completionHash
            );
        }
    }

    function finalityExecutionContext(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest
    ) external view override returns (StreamFinalityExecutionContext memory execution) {
        (, execution) = _prepareExecution(scope, components, expectedFinalityRecordHash, manifest);
        StreamFinalitySanctionArchive.requireAbsent(components);
    }

    function finalityExecutionContextWithArchive(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest,
        StreamFinalitySanctionArchiveProof calldata proof
    ) external view returns (StreamFinalityExecutionContext memory execution) {
        (, execution) = _prepareExecution(scope, components, expectedFinalityRecordHash, manifest);
        _prepareArchive(components, execution, proof, true);
    }

    function finalitySanctionArchiveWitness(bytes32 recordHash)
        external
        view
        returns (StreamFinalitySanctionArchiveWitness memory)
    {
        return _archiveWitnesses[recordHash];
    }

    function _prepareArchive(
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityExecutionContext memory execution,
        StreamFinalitySanctionArchiveProof memory proof,
        bool hasArchive
    ) private view returns (bytes32 evidenceHash) {
        if (!hasArchive) {
            StreamFinalitySanctionArchive.requireAbsent(components);
            return 0;
        }
        evidenceHash = StreamFinalitySanctionArchive.requireProof(
            StreamFinalitySanctionArchive.Pins(
                address(coreReads),
                address(sanctionReads),
                artifactCoverage,
                _artifactCodeHash,
                _componentReadGas()
            ),
            components,
            proof
        );
        execution.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_EXECUTION_ARCHIVED_NEW_V1"),
                execution.scopeHash,
                true,
                execution.finalityRecordHash,
                evidenceHash
            )
        );
    }

    function finalityExecutionWitness(bytes32 finalityRecordHash)
        external
        view
        override
        returns (StreamFinalityExecutionWitness memory)
    {
        return _executionWitnesses[finalityRecordHash];
    }

    /// @inheritdoc IStreamArtistSanctionPreparation
    function prepareSanction(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata nonSanctionComponents,
        StreamFinalityManifestRef calldata manifest
    ) external view override returns (StreamArtistSanctionPreparation memory) {
        if (msg.data.length > MAX_FINALITY_CALLDATA_BYTES) {
            revert FinalityCalldataTooLarge(msg.data.length, MAX_FINALITY_CALLDATA_BYTES);
        }
        _requireCanonicalScopeShape(scope);
        if (_scopeFinalized(scope)) revert FinalityAlreadyFinalized(_scopeKey(scope));
        _requireComponentListWellFormed(nonSanctionComponents);
        _requireManifestValid(manifest);
        return StreamFinalityPreparation.prepareSanction(
            _preparationDependencies(), scope, nonSanctionComponents, manifest
        );
    }

    function _prepareExecution(
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        bytes32 expectedFinalityRecordHash,
        StreamFinalityManifestRef calldata manifest
    )
        private
        view
        returns (
            StreamFinalityPreparation.Prepared memory ctx,
            StreamFinalityExecutionContext memory execution
        )
    {
        _requireCanonicalScopeShape(scope);
        if (_scopeFinalized(scope)) revert FinalityAlreadyFinalized(_scopeKey(scope));
        if (expectedFinalityRecordHash == bytes32(0)) revert FinalityExpectedRecordHashZero();
        _requireComponentListWellFormed(components);
        _requireManifestValid(manifest);
        return StreamFinalityPreparation.prepare(
            _preparationDependencies(), scope, components, expectedFinalityRecordHash, manifest
        );
    }

    function _preparationDependencies()
        private
        view
        returns (StreamFinalityPreparation.Dependencies memory)
    {
        return StreamFinalityPreparation.Dependencies(
            coreReads,
            coreFinalityAdapter,
            IStreamFinalityMetadataReads(scopeEvidenceProvider),
            address(metadataReads),
            sanctionReads,
            finalityDiscovery,
            _coreCodeHash,
            _metadataCodeHash,
            _providerCodeHash,
            _adapterCodeHash,
            _discoveryCodeHash,
            _componentReadGas()
        );
    }

    function _componentReadGas() private view returns (uint256) {
        return _gasParameterValue(GGP_FINALITY_COMPONENT_READ_GAS_KEY);
    }

    // ------------------------------------------------------------------
    // Pinned-preimage computation views (preview and signing-tool seam)
    // ------------------------------------------------------------------

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeComponentsHash(StreamFinalityComponentExpectation[] calldata components)
        external
        pure
        override
        returns (bytes32)
    {
        return _componentsHash(components);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeNonSanctionComponentsHash(StreamFinalityComponentExpectation[] calldata components)
        external
        pure
        override
        returns (bytes32)
    {
        return _nonSanctionComponentsHash(components);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeCollectionCoreFactsHash(uint256 collectionId)
        external
        view
        override
        returns (bytes32)
    {
        return _coreCollectionFactsHash(
            collectionId, coreFinalityAdapter.coreCollectionFinalityFacts(collectionId)
        );
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeScopedCoreFactsHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        return _scopedCoreFactsHash(
            scope, coreFinalityAdapter.scopedCoreFinalityFacts(_adapterScope(scope))
        );
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeFinalityRecordHash(
        StreamFinalityScope calldata scope,
        bytes32 coreFactsHash,
        bytes32 componentsHash,
        StreamFinalityManifestRef calldata manifest
    ) external view override returns (bytes32) {
        return _finalityRecordHash(scope, coreFactsHash, componentsHash, manifest);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function computeSanctionSubjectHash(
        StreamFinalityScope calldata scope,
        bytes32 coreFactsHash,
        bytes32 nonSanctionComponentsHash,
        StreamFinalityManifestRef calldata manifest
    ) external view override returns (bytes32) {
        return _sanctionSubjectHash(scope, coreFactsHash, nonSanctionComponentsHash, manifest);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function contentRootScopeSubject(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        return _contentRootSubject(scope);
    }

    // ------------------------------------------------------------------
    // Required reads and diagnostics
    // ------------------------------------------------------------------

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function collectionFinalityRecord(uint256 collectionId)
        external
        view
        override
        returns (StreamCollectionFinalityRecord memory)
    {
        return _collectionRecords[collectionId];
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityComponentCount(uint256 collectionId) external view override returns (uint256) {
        return _collectionComponents[collectionId].length;
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityComponents(uint256 collectionId, uint256 start, uint256 limit)
        external
        view
        override
        returns (StreamFinalityComponentExpectation[] memory)
    {
        return _sliceComponents(_collectionComponents[collectionId], start, limit);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityStillMatches(uint256 collectionId) external view override returns (bool) {
        (bool matches,,) = _verifyScopeDiagnostic(_collectionScope(collectionId));
        return matches;
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function verifyFinality(uint256 collectionId)
        external
        view
        override
        returns (bool currentRouteMatches, bytes32 finalityRecordHash, bytes32 componentsHash)
    {
        return _verifyScopeDiagnostic(_collectionScope(collectionId));
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function verifyFinalityRange(uint256 collectionId, uint256 start, uint256 limit)
        external
        view
        override
        returns (
            bool rangeMatches,
            bytes32 finalityRecordHash,
            bytes32 expectedRangeHash,
            bytes32 observedRangeHash,
            uint256 nextStart
        )
    {
        return _verifyScopeRange(_collectionScope(collectionId), start, limit);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function artworkScopeFinalityRecord(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamScopedFinalityRecord memory out)
    {
        StreamFinalityScope memory scopeMem = scope;
        if (
            scopeMem.scopeType == StreamFinalityScopeType.COLLECTION
                && _isCanonicalScopeShape(scopeMem)
        ) {
            StreamCollectionFinalityRecord storage record =
                _collectionRecords[scopeMem.collectionId];
            if (!record.finalized) {
                return out;
            }
            out.finalized = true;
            out.scope = scopeMem;
            out.finalityRecordHash = record.finalityRecordHash;
            out.manifestContentHash = record.manifestContentHash;
            out.manifestURIHash = record.manifestURIHash;
            out.componentsHash = record.componentsHash;
            out.finalityManifestURI = record.finalityManifestURI;
            out.manifestPointer = record.manifestPointer;
            out.finalizedAt = record.finalizedAt;
            return out;
        }
        return _scopedRecords[_scopeKey(scopeMem)];
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function verifyArtworkScopeFinality(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bool currentRouteMatches, bytes32 finalityRecordHash, bytes32 componentsHash)
    {
        return _verifyScopeDiagnostic(scope);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function verifyArtworkScopeFinalityRange(
        StreamFinalityScope calldata scope,
        uint256 start,
        uint256 limit
    )
        external
        view
        override
        returns (
            bool rangeMatches,
            bytes32 finalityRecordHash,
            bytes32 expectedRangeHash,
            bytes32 observedRangeHash,
            uint256 nextStart
        )
    {
        return _verifyScopeRange(scope, start, limit);
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityComponentCountForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        (,,, StreamFinalityComponentExpectation[] storage stored) = _storedRecordFor(scope);
        return stored.length;
    }

    /// @inheritdoc IStreamArtworkFinalityRegistry
    function finalityComponentsForScope(
        StreamFinalityScope calldata scope,
        uint256 start,
        uint256 limit
    ) external view override returns (StreamFinalityComponentExpectation[] memory) {
        (,,, StreamFinalityComponentExpectation[] storage stored) = _storedRecordFor(scope);
        return _sliceComponents(stored, start, limit);
    }

    /// @inheritdoc IStreamArtworkScopedFrozenRouteRegistry
    function frozenRouteForScope(bytes32 routeType, StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bool pinned, address module, bytes32 routeHash, bytes32 finalityRecordHash)
    {
        (bool finalized, bytes32 recHash,, StreamFinalityComponentExpectation[] storage stored) =
            _storedRecordFor(scope);
        if (!finalized) {
            return (false, address(0), bytes32(0), bytes32(0));
        }
        uint256 count = stored.length;
        for (uint256 i = 0; i < count; i++) {
            if (stored[i].componentType == routeType) {
                StreamFinalityComponentExpectation memory expectation = stored[i];
                return (true, expectation.component, keccak256(abi.encode(expectation)), recHash);
            }
        }
        return (false, address(0), bytes32(0), recHash);
    }

    // ------------------------------------------------------------------
    // Internal: freeze machinery
    // ------------------------------------------------------------------

    // ------------------------------------------------------------------
    // Internal: scope helpers
    // ------------------------------------------------------------------

    function _collectionScope(uint256 collectionId)
        private
        pure
        returns (StreamFinalityScope memory)
    {
        return StreamFinalityScope({
            scopeType: StreamFinalityScopeType.COLLECTION,
            collectionId: collectionId,
            tokenId: 0,
            scopeId: bytes32(0)
        });
    }

    function _scopeKey(StreamFinalityScope memory scope) private pure returns (bytes32) {
        return keccak256(
            abi.encode(uint8(scope.scopeType), scope.collectionId, scope.tokenId, scope.scopeId)
        );
    }

    function _adapterScope(StreamFinalityScope memory scope)
        private
        pure
        returns (StreamCoreFinalityScopeQuery memory)
    {
        return StreamCoreFinalityScopeQuery({
            scopeType: uint8(scope.scopeType),
            collectionId: scope.collectionId,
            tokenId: scope.tokenId,
            scopeId: scope.scopeId
        });
    }

    function _isCanonicalScopeShape(StreamFinalityScope memory scope) private pure returns (bool) {
        if (scope.collectionId == 0) {
            return false;
        }
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return scope.tokenId == 0 && scope.scopeId == bytes32(0);
        }
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            return scope.tokenId != 0 && scope.scopeId == bytes32(0);
        }
        return scope.tokenId == 0 && scope.scopeId != bytes32(0);
    }

    function _requireCanonicalScopeShape(StreamFinalityScope memory scope) private pure {
        if (!_isCanonicalScopeShape(scope)) {
            revert FinalityScopeShapeInvalid();
        }
    }

    function _scopeFinalized(StreamFinalityScope memory scope) private view returns (bool) {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return _collectionRecords[scope.collectionId].finalized;
        }
        return _scopedRecords[_scopeKey(scope)].finalized;
    }

    function _storedRecordFor(StreamFinalityScope memory scope)
        private
        view
        returns (
            bool finalized,
            bytes32 recHash,
            bytes32 compHash,
            StreamFinalityComponentExpectation[] storage stored
        )
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION && _isCanonicalScopeShape(scope))
        {
            StreamCollectionFinalityRecord storage record = _collectionRecords[scope.collectionId];
            return (
                record.finalized,
                record.finalityRecordHash,
                record.componentsHash,
                _collectionComponents[scope.collectionId]
            );
        }
        bytes32 scopeKey = _scopeKey(scope);
        StreamScopedFinalityRecord storage srecord = _scopedRecords[scopeKey];
        return (
            srecord.finalized,
            srecord.finalityRecordHash,
            srecord.componentsHash,
            _scopedComponents[scopeKey]
        );
    }

    // ------------------------------------------------------------------
    // Internal: execution gates (strict, typed reverts)
    // ------------------------------------------------------------------

    function _requireComponentListWellFormed(StreamFinalityComponentExpectation[] calldata components)
        private
        pure
    {
        uint256 count = components.length;
        if (count == 0 || count > MAX_FINALITY_COMPONENTS) {
            revert FinalityComponentCountInvalid(count, MAX_FINALITY_COMPONENTS);
        }
        for (uint256 i = 1; i < count; i++) {
            if (!_strictlyAscending(components[i - 1], components[i])) {
                revert FinalityComponentsUnsorted(i);
            }
        }
    }

    /// @dev Full-identity-tuple ordering per [LTA-FINALITY]: sorted ascending by
    ///      (componentType, component, interfaceId, codeHash, moduleVersion, manifestHash,
    ///      dataHash) with no duplicates; equal tuples are duplicates and fail.
    function _strictlyAscending(
        StreamFinalityComponentExpectation calldata previous,
        StreamFinalityComponentExpectation calldata next
    ) private pure returns (bool) {
        if (previous.componentType != next.componentType) {
            return previous.componentType < next.componentType;
        }
        if (previous.component != next.component) {
            return previous.component < next.component;
        }
        if (previous.interfaceId != next.interfaceId) {
            return previous.interfaceId < next.interfaceId;
        }
        if (previous.codeHash != next.codeHash) {
            return previous.codeHash < next.codeHash;
        }
        if (previous.moduleVersion != next.moduleVersion) {
            return previous.moduleVersion < next.moduleVersion;
        }
        if (previous.manifestHash != next.manifestHash) {
            return previous.manifestHash < next.manifestHash;
        }
        if (previous.dataHash != next.dataHash) {
            return previous.dataHash < next.dataHash;
        }
        return false;
    }

    function _requireManifestValid(StreamFinalityManifestRef calldata manifest) private view {
        bytes32 recomputedURIHash = keccak256(bytes(manifest.uri));
        if (manifest.uriHash != recomputedURIHash) {
            revert FinalityManifestURIHashMismatch(recomputedURIHash, manifest.uriHash);
        }
        if (
            manifest.contentHash == bytes32(0) || manifest.schemaId == bytes32(0)
                || manifest.canonicalizationHash == bytes32(0)
        ) {
            revert FinalityManifestFieldZero();
        }
        if (_manifestBytes[manifest.contentHash].length == 0) {
            revert FinalityManifestBytesMissing(manifest.contentHash);
        }
    }

    /// @dev Collection scope: existence, CLOSED status, the one-way burn block, and the
    ///      terminal collection freeze. Scoped: scope existence and the TOKEN
    ///      minted-or-burned rule (scope rules 2-3).

    /// @dev [CMC-FINALITY-INPUTS] rule 4 / [CMC-CONTENT-ROOT] rule 4: the recorded token
    ///      content root and leaf count verify at execution. Collection scope binds the exact
    ///      minted-ever count (burned tokens retain archival content, [CMC-BURN] rule 4);
    ///      TOKEN scope binds exactly one leaf; RELEASE/SEASON/VIEW bind a nonzero-leaf root
    ///      whose exact token set is pinned by the metadata scope manifest.

    /// @dev [LTA-FINALITY] requirement 1 / MRR-FINALITY rules 6-9 / [CMC-FINALITY-INPUTS]:
    ///      the mandatory component-type floor enforced ONCHAIN, independent of discovery's
    ///      exact submitted-route check. Delegated to the library so the check does
    ///      not inflate registry bytecode; reverts FinalityMissingRequiredComponent on the first
    ///      missing type.

    /// @dev [LTA-FINALITY] requirement 6 / MRR-FINALITY rule 7 / [CMC-FINALITY-INPUTS] rule 3:
    ///      ONCHAIN and hybrid collections cannot finalize unless an assembled snapshot
    ///      manifest hash was already recorded. OFFCHAIN is unaffected.

    /// @dev [LTA-FINALITY] requirement 9 / [AA-SANCTION] requirement 3: exactly one of
    ///      ARTIST_SANCTION and PLATFORM_WORKS_DECLARATION, matching the artist registry's
    ///      required type; artist-bound scopes verify the sanction over the subject hash and
    ///      bind `sanctionRecordHash` as the component dataHash.

    function _sameExpectation(
        StreamFinalityComponentExpectation memory discovered,
        StreamFinalityComponentExpectation calldata submitted
    ) private pure returns (bool) {
        return discovered.componentType == submitted.componentType
            && discovered.component == submitted.component
            && discovered.interfaceId == submitted.interfaceId
            && discovered.codeHash == submitted.codeHash
            && discovered.moduleVersion == submitted.moduleVersion
            && discovered.manifestHash == submitted.manifestHash
            && discovered.dataHash == submitted.dataHash;
    }

    /// @dev Fail-closed post-finality comparison against the currently discovered route. Unlike
    ///      the strict execution gate above, this path must preserve the diagnostic's never-revert
    ///      contract when discovery has no code, reverts, or returns malformed/oversized data.

    /// @dev Bounded exact-word staticcall. Supplying a fixed output buffer avoids allocating or
    ///      copying attacker-controlled returndata. `gasCap == 0` forwards available gas less the
    ///      parent reserve for strict execution; diagnostics supply their governed nonzero cap.

    // ------------------------------------------------------------------
    // Internal: component observation shared by execution and diagnostics
    // ------------------------------------------------------------------

    // ------------------------------------------------------------------
    // Internal: pinned hash preimages
    // ------------------------------------------------------------------

    function _componentsHash(StreamFinalityComponentExpectation[] calldata components)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components)
        );
    }

    function _componentsHashMemory(StreamFinalityComponentExpectation[] memory components)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, components)
        );
    }

    /// @dev componentsHash over the submitted list with every ARTIST_SANCTION entry excluded
    ///      ([AA-SANCTION]): same domain, same sort order.
    function _nonSanctionComponentsHash(StreamFinalityComponentExpectation[] calldata components)
        private
        pure
        returns (bytes32)
    {
        uint256 count = components.length;
        uint256 kept = 0;
        for (uint256 i = 0; i < count; i++) {
            if (components[i].componentType != StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
                kept++;
            }
        }
        StreamFinalityComponentExpectation[] memory filtered =
            new StreamFinalityComponentExpectation[](kept);
        uint256 cursor = 0;
        for (uint256 i = 0; i < count; i++) {
            if (components[i].componentType != StreamFinalityDomains.COMPONENT_ARTIST_SANCTION) {
                filtered[cursor] = components[i];
                cursor++;
            }
        }
        return _componentsHashMemory(filtered);
    }

    /// @dev Splitting a wide static-arg `abi.encode` into `bytes.concat` halves is
    ///      byte-identical because every argument is a static type occupying exactly one
    ///      32-byte head word; the golden tests recompute each preimage in one encode and
    ///      assert equality. The split keeps legacy codegen under its stack limit.
    function _coreCollectionFactsHash(
        uint256 collectionId,
        StreamCoreCollectionFinalityFacts memory facts
    ) private view returns (bytes32) {
        return StreamFinalityHashes.coreCollectionFactsHash(address(coreReads), collectionId, facts);
    }

    function _scopedCoreFactsHash(
        StreamFinalityScope memory scope,
        StreamScopedCoreFinalityFacts memory facts
    ) private view returns (bytes32) {
        return StreamFinalityHashes.scopedCoreFactsHash(address(coreReads), scope, facts);
    }

    function _finalityRecordHash(
        StreamFinalityScope memory scope,
        bytes32 coreFactsHash,
        bytes32 componentsHash,
        StreamFinalityManifestRef calldata manifest
    ) private view returns (bytes32) {
        return StreamFinalityHashes.finalityRecordHash(
            address(coreReads), scope, coreFactsHash, componentsHash, manifest
        );
    }

    /// @dev Sanction subject preimage ([AA-SANCTION]/[AA-DOMAINS]): the finality record
    ///      preimage without the sanction component itself.
    function _sanctionSubjectHash(
        StreamFinalityScope memory scope,
        bytes32 coreFactsHash,
        bytes32 nonSanctionComponentsHash,
        StreamFinalityManifestRef calldata manifest
    ) private view returns (bytes32) {
        return StreamFinalityHashes.sanctionSubjectHash(
            address(coreReads), scope, coreFactsHash, nonSanctionComponentsHash, manifest
        );
    }

    /// @dev [CMC-SUBJECT-ID] derivations: collection subject for COLLECTION scope, token
    ///      subject for TOKEN scope, scope subject for RELEASE/SEASON/VIEW.
    function _contentRootSubject(StreamFinalityScope memory scope) private view returns (bytes32) {
        return StreamFinalityHashes.contentRootSubject(address(coreReads), scope);
    }

    // ------------------------------------------------------------------
    // Internal: storage effects and diagnostics
    // ------------------------------------------------------------------

    function _storeRecordAndEmit(
        StreamFinalityScope memory scope,
        StreamFinalityPreparation.Prepared memory ctx,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalityManifestRef calldata manifest
    ) private {
        StreamFinalityRecordState.store(
            _collectionRecords,
            _collectionComponents,
            _scopedRecords,
            _scopedComponents,
            scope,
            ctx,
            components,
            manifest
        );
    }

    function _sliceComponents(
        StreamFinalityComponentExpectation[] storage stored,
        uint256 start,
        uint256 limit
    ) private view returns (StreamFinalityComponentExpectation[] memory out) {
        uint256 count = stored.length;
        if (start >= count || limit == 0) {
            return new StreamFinalityComponentExpectation[](0);
        }
        uint256 end = limit >= count - start ? count : start + limit;
        out = new StreamFinalityComponentExpectation[](end - start);
        for (uint256 i = start; i < end; i++) {
            out[i - start] = stored[i];
        }
    }

    function _verifyScopeDiagnostic(StreamFinalityScope memory scope)
        private
        view
        returns (bool currentRouteMatches, bytes32 finalityRecordHash, bytes32 componentsHash)
    {
        (
            bool finalized,
            bytes32 recHash,
            bytes32 compHash,
            StreamFinalityComponentExpectation[] storage stored
        ) = _storedRecordFor(scope);
        if (!finalized) return (false, bytes32(0), bytes32(0));
        return (
            StreamFinalityDiagnostics.matches(
                stored, scope, compHash, finalityDiscovery, _componentReadGas()
            ),
            recHash,
            compHash
        );
    }

    function _verifyScopeRange(StreamFinalityScope memory scope, uint256 start, uint256 limit)
        private
        view
        returns (
            bool rangeMatches,
            bytes32 finalityRecordHash,
            bytes32 expectedRangeHash,
            bytes32 observedRangeHash,
            uint256 nextStart
        )
    {
        (bool finalized, bytes32 recHash,, StreamFinalityComponentExpectation[] storage stored) =
            _storedRecordFor(scope);
        if (!finalized) return (false, bytes32(0), bytes32(0), bytes32(0), 0);
        finalityRecordHash = recHash;
        (rangeMatches, expectedRangeHash, observedRangeHash, nextStart) =
            StreamFinalityDiagnostics.range(stored, scope, start, limit, _componentReadGas());
    }
}
