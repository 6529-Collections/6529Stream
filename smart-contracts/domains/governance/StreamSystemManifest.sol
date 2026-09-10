// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/IERC165.sol";
import "../../interfaces/stream/IStreamGovernanceExecutor.sol";
import "../../interfaces/stream/IStreamSystemManifest.sol";
import "./StreamGovernanceEvidence.sol";

interface IStreamSystemManifestCore {
    function getSatellitePointer(bytes32 pointerType)
        external
        view
        returns (
            address target,
            bytes32 codeHash,
            bool frozen,
            bytes32 moduleType,
            bytes4 interfaceId,
            address registry,
            uint8 registryStatus,
            bytes32 moduleManifestHash,
            bytes32 deploymentManifestHash,
            uint64 revision
        );
}

/// @notice Permanent, state-only aggregate and append-only onchain payload
///         history for Stream deployment discovery.
/// @dev The sole writer is the immutable Governance V2 Executor. Every write
///      verifies the Executor's exact in-flight per-call transition, derives
///      the post-batch address set from Core, and validates the chunked
///      SSTORE2 root through the shared governance-evidence verifier.
contract StreamSystemManifest is IStreamSystemManifest {
    uint16 private constant SCHEMA_VERSION = 1;
    uint8 private constant REPLACEMENT_ACTION_CLASS = 3;
    uint8 private constant MODULE_STATUS_ACTIVE = 1;
    uint256 private constant MAX_MANIFEST_URI_BYTES = 2_048;

    bytes32 private constant STREAM_SYSTEM_MANIFEST_SCOPE_V1 =
        0xf73b4d7b4d260fce0823707f836fdf29a1767a2a2a9cfbce14ec8c5e49e47841;
    bytes32 private constant STREAM_SYSTEM_MANIFEST_STATE_V1 =
        0x3764ccb415d0aac07f1bddb8d4841ad6d4c2f9b2fe7ce7d221c586bc056aaf60;

    bytes32 private constant ROYALTY_RESOLVER_POINTER = keccak256("ROYALTY_RESOLVER");
    bytes32 private constant METADATA_ROUTER_POINTER = keccak256("METADATA_ROUTER");
    bytes32 private constant COLLECTION_METADATA_POINTER = keccak256("COLLECTION_METADATA");
    bytes32 private constant ENTROPY_COORDINATOR_POINTER = keccak256("ENTROPY_COORDINATOR");
    bytes32 private constant MINT_MANAGER_POINTER = keccak256("MINT_MANAGER");
    bytes32 private constant MINT_LEDGER_POINTER = keccak256("MINT_LEDGER");
    bytes32 private constant ARTIST_REGISTRY_POINTER = keccak256("ARTIST_REGISTRY");
    bytes32 private constant ARTWORK_FINALITY_REGISTRY_POINTER =
        keccak256("ARTWORK_FINALITY_REGISTRY");
    bytes32 private constant MODULE_REGISTRY_POINTER = keccak256("MODULE_REGISTRY");
    bytes32 private constant STATE_EXPORT_PUBLISHER_POINTER = keccak256("STATE_EXPORT_PUBLISHER");
    bytes32 private constant SYSTEM_MANIFEST_POINTER = keccak256("SYSTEM_MANIFEST");

    bytes32 private constant REVENUE_RESOLVER_MODULE = keccak256("REVENUE_RESOLVER");
    bytes32 private constant METADATA_ROUTER_MODULE = keccak256("METADATA_ROUTER");
    bytes32 private constant COLLECTION_METADATA_MODULE = keccak256("COLLECTION_METADATA");
    bytes32 private constant ENTROPY_COORDINATOR_MODULE = keccak256("ENTROPY_COORDINATOR");
    bytes32 private constant MINT_MANAGER_MODULE = keccak256("MINT_MANAGER");
    bytes32 private constant MINT_LEDGER_MODULE = keccak256("MINT_LEDGER");
    bytes32 private constant ARTIST_REGISTRY_MODULE = keccak256("ARTIST_REGISTRY");
    bytes32 private constant ARTWORK_FINALITY_REGISTRY_MODULE =
        keccak256("ARTWORK_FINALITY_REGISTRY");
    bytes32 private constant MODULE_REGISTRY_MODULE = keccak256("MODULE_REGISTRY");
    bytes32 private constant GOVERNANCE_LAYER_MODULE = keccak256("GOVERNANCE_LAYER");
    bytes32 private constant STATE_EXPORT_PUBLISHER_MODULE = keccak256("STATE_EXPORT_PUBLISHER");
    bytes32 private constant STREAM_SYSTEM_MANIFEST_MODULE =
        0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6;

    bytes4 private constant SYSTEM_MANIFEST_INTERFACE_ID = 0x37660ede;
    bytes4 private constant STATE_EXPORT_PUBLISHER_INTERFACE_ID = 0x77faad4f;

    bytes32 private constant FIELD_MANIFEST_HASH = keccak256("manifestHash");
    bytes32 private constant FIELD_EVENT_CATALOG_HASH = keccak256("eventCatalogHash");
    bytes32 private constant FIELD_COMPATIBILITY_MATRIX_HASH = keccak256("compatibilityMatrixHash");
    bytes32 private constant FIELD_NUMERIC_ID_CATALOG_HASH = keccak256("numericIdCatalogHash");
    bytes32 private constant FIELD_SCHEMA_CATALOG_HASH = keccak256("schemaCatalogHash");
    bytes32 private constant FIELD_CANONICALIZATION_CATALOG_HASH =
        keccak256("canonicalizationCatalogHash");
    bytes32 private constant FIELD_SPEC_BUNDLE_HASH = keccak256("specBundleHash");
    bytes32 private constant FIELD_RECONSTRUCTION_CLIENT_HASH =
        keccak256("reconstructionClientHash");

    error InvalidCore(address core);
    error InvalidGovernanceExecutor(address executor);
    error DuplicateImmutableBinding(address binding);
    error UnauthorizedGovernanceExecutor(address caller);
    error NoExecutingGovernanceAction();
    error InvalidGovernanceActionClass(uint8 actionClass);
    error GovernanceScopeHashMismatch(bytes32 expected, bytes32 actual);
    error GovernanceOldValueHashMismatch(bytes32 expected, bytes32 actual);
    error GovernanceNewValueHashMismatch(bytes32 expected, bytes32 actual);
    error AggregateMutationRequiresReplacement(uint8 actionClass);
    error ManifestFieldZero(bytes32 field);
    error ManifestURIEmpty();
    error ManifestURITooLarge(uint256 actual, uint256 maximum);
    error ManifestURIInvalidUTF8();
    error InvalidSatellitePointer(bytes32 pointerType);
    error InvalidSystemManifestPointer();
    error InvalidStateExportPublisherPointer();
    error NoOpManifestPublication();
    error ManifestRevisionOverflow();
    error ManifestTimestampOverflow(uint256 timestamp);

    struct PointerFacts {
        address target;
        bytes32 codeHash;
        bool frozen;
        bytes32 moduleType;
        bytes4 interfaceId;
        address registry;
        uint8 registryStatus;
        bytes32 moduleManifestHash;
        bytes32 deploymentManifestHash;
        uint64 revision;
    }

    struct ModuleAddresses {
        address revenueResolver;
        address metadataRouter;
        address collectionMetadata;
        address entropyCoordinator;
        address mintManager;
        address mintLedger;
        address artistRegistry;
        address streamAdminsOrGovernance;
        address artworkFinalityRegistry;
        address moduleRegistry;
        address stateExportPublisher;
    }

    struct DiscoveryHashes {
        bytes32 eventCatalogHash;
        bytes32 compatibilityMatrixHash;
        bytes32 numericIdCatalogHash;
        bytes32 schemaCatalogHash;
        bytes32 canonicalizationCatalogHash;
        bytes32 specBundleHash;
        bytes32 reconstructionClientHash;
    }

    struct AggregateState {
        bytes32 manifestHash;
        string manifestURI;
        ModuleAddresses modules;
        DiscoveryHashes discovery;
        uint64 revision;
    }

    struct ManifestPointerEntry {
        address payloadPointer;
        bytes32 manifestHash;
        uint64 updatedAt;
    }

    struct ActionContext {
        bytes32 actionId;
        uint8 actionClass;
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }

    address public immutable core;
    address public immutable governanceExecutor;

    AggregateState private _aggregate;
    ManifestPointerEntry[] private _pointerHistory;

    constructor(address core_, address governanceExecutor_) {
        if (core_ == address(0) || core_.code.length == 0 || _isDelegatedEOA(core_)) {
            revert InvalidCore(core_);
        }
        if (
            governanceExecutor_ == address(0) || governanceExecutor_.code.length == 0
                || _isDelegatedEOA(governanceExecutor_)
        ) {
            revert InvalidGovernanceExecutor(governanceExecutor_);
        }
        if (core_ == governanceExecutor_) {
            revert DuplicateImmutableBinding(core_);
        }
        core = core_;
        governanceExecutor = governanceExecutor_;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IStreamSystemManifest).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    /// @inheritdoc IStreamSystemManifest
    function streamSystemManifest()
        external
        view
        override
        returns (
            bytes32 manifestHash,
            string memory manifestURI,
            address revenueResolver,
            address metadataRouter,
            address collectionMetadata,
            address entropyCoordinator,
            address mintManager,
            address mintLedger,
            address artistRegistry,
            address streamAdminsOrGovernance,
            address artworkFinalityRegistry,
            address moduleRegistry,
            address stateExportPublisher,
            bytes32 eventCatalogHash,
            bytes32 compatibilityMatrixHash,
            bytes32 numericIdCatalogHash,
            bytes32 schemaCatalogHash,
            bytes32 canonicalizationCatalogHash,
            bytes32 specBundleHash,
            bytes32 reconstructionClientHash,
            uint64 revision
        )
    {
        AggregateState storage aggregate = _aggregate;
        manifestHash = aggregate.manifestHash;
        manifestURI = aggregate.manifestURI;
        revenueResolver = aggregate.modules.revenueResolver;
        metadataRouter = aggregate.modules.metadataRouter;
        collectionMetadata = aggregate.modules.collectionMetadata;
        entropyCoordinator = aggregate.modules.entropyCoordinator;
        mintManager = aggregate.modules.mintManager;
        mintLedger = aggregate.modules.mintLedger;
        artistRegistry = aggregate.modules.artistRegistry;
        streamAdminsOrGovernance = aggregate.modules.streamAdminsOrGovernance;
        artworkFinalityRegistry = aggregate.modules.artworkFinalityRegistry;
        moduleRegistry = aggregate.modules.moduleRegistry;
        stateExportPublisher = aggregate.modules.stateExportPublisher;
        eventCatalogHash = aggregate.discovery.eventCatalogHash;
        compatibilityMatrixHash = aggregate.discovery.compatibilityMatrixHash;
        numericIdCatalogHash = aggregate.discovery.numericIdCatalogHash;
        schemaCatalogHash = aggregate.discovery.schemaCatalogHash;
        canonicalizationCatalogHash = aggregate.discovery.canonicalizationCatalogHash;
        specBundleHash = aggregate.discovery.specBundleHash;
        reconstructionClientHash = aggregate.discovery.reconstructionClientHash;
        revision = aggregate.revision;
    }

    /// @inheritdoc IStreamSystemManifest
    function streamSystemManifestPointer() external view override returns (address payloadPointer) {
        uint256 count = _pointerHistory.length;
        if (count != 0) {
            payloadPointer = _pointerHistory[count - 1].payloadPointer;
        }
    }

    /// @inheritdoc IStreamSystemManifest
    function streamSystemManifestPointerCount() external view override returns (uint256) {
        return _pointerHistory.length;
    }

    /// @inheritdoc IStreamSystemManifest
    function streamSystemManifestPointerAt(uint256 index)
        external
        view
        override
        returns (address payloadPointer, bytes32 manifestHash, uint64 updatedAt)
    {
        ManifestPointerEntry storage entry = _pointerHistory[index];
        return (entry.payloadPointer, entry.manifestHash, entry.updatedAt);
    }

    /// @inheritdoc IStreamSystemManifest
    function publishStreamSystemManifest(
        address payloadPointer,
        StreamSystemManifestUpdate calldata update
    ) external override {
        if (msg.sender != governanceExecutor) {
            revert UnauthorizedGovernanceExecutor(msg.sender);
        }
        ActionContext memory action = _readActionContext();
        _validateUpdate(update);
        StreamGovernanceEvidence.verifyManifestPayload(payloadPointer, update.manifestHash);

        ModuleAddresses memory nextModules = _deriveModuleAddresses();
        DiscoveryHashes memory nextDiscovery = _discoveryFrom(update);
        bytes32 currentModuleAddressesHash = _moduleAddressesHash(_aggregate.modules);
        bytes32 nextModuleAddressesHash = _moduleAddressesHash(nextModules);
        bytes32 currentDiscoveryHashesHash = _discoveryHashesHash(_aggregate.discovery);
        bytes32 nextDiscoveryHashesHash = _discoveryHashesHash(nextDiscovery);
        if (
            action.actionClass != REPLACEMENT_ACTION_CLASS
                && (currentModuleAddressesHash != nextModuleAddressesHash
                    || currentDiscoveryHashesHash != nextDiscoveryHashesHash)
        ) {
            revert AggregateMutationRequiresReplacement(action.actionClass);
        }

        uint256 historyCount = _pointerHistory.length;
        if (historyCount == type(uint64).max) revert ManifestRevisionOverflow();
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 nextRevision = uint64(historyCount + 1);
        address currentPayloadPointer =
            historyCount == 0 ? address(0) : _pointerHistory[historyCount - 1].payloadPointer;
        bytes32 expectedScopeHash = _scopeHash();
        bytes32 expectedOldValueHash = _stateHash(
            expectedScopeHash,
            _aggregate.manifestHash,
            keccak256(bytes(_aggregate.manifestURI)),
            currentPayloadPointer,
            currentModuleAddressesHash,
            currentDiscoveryHashesHash,
            _aggregate.revision
        );
        bytes32 expectedNewValueHash = _stateHash(
            expectedScopeHash,
            update.manifestHash,
            keccak256(bytes(update.manifestURI)),
            payloadPointer,
            nextModuleAddressesHash,
            nextDiscoveryHashesHash,
            nextRevision
        );
        if (action.scopeHash != expectedScopeHash) {
            revert GovernanceScopeHashMismatch(expectedScopeHash, action.scopeHash);
        }
        if (action.oldValueHash != expectedOldValueHash) {
            revert GovernanceOldValueHashMismatch(expectedOldValueHash, action.oldValueHash);
        }
        if (action.newValueHash != expectedNewValueHash) {
            revert GovernanceNewValueHashMismatch(expectedNewValueHash, action.newValueHash);
        }
        if (
            currentPayloadPointer == payloadPointer
                && _aggregate.manifestHash == update.manifestHash
                && keccak256(bytes(_aggregate.manifestURI)) == keccak256(bytes(update.manifestURI))
                && currentModuleAddressesHash == nextModuleAddressesHash
                && currentDiscoveryHashesHash == nextDiscoveryHashesHash
        ) {
            revert NoOpManifestPublication();
        }
        if (block.timestamp > type(uint64).max) {
            revert ManifestTimestampOverflow(block.timestamp);
        }
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 updatedAt = uint64(block.timestamp);

        _storeAggregate(update, nextModules, nextDiscovery, nextRevision);
        _pointerHistory.push(
            ManifestPointerEntry({
                payloadPointer: payloadPointer,
                manifestHash: update.manifestHash,
                updatedAt: updatedAt
            })
        );
        emit StreamSystemManifestPublished(
            SCHEMA_VERSION, update.manifestHash, payloadPointer, action.actionId
        );
    }

    function _readActionContext() private view returns (ActionContext memory action) {
        (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 scopeHash,
            bytes32 oldValueHash,
            bytes32 newValueHash
        ) = IStreamGovernanceExecutor(governanceExecutor).currentAction();
        if (!executing || actionId == bytes32(0)) revert NoExecutingGovernanceAction();
        if (actionClass > REPLACEMENT_ACTION_CLASS) {
            revert InvalidGovernanceActionClass(actionClass);
        }
        action = ActionContext({
            actionId: actionId,
            actionClass: actionClass,
            scopeHash: scopeHash,
            oldValueHash: oldValueHash,
            newValueHash: newValueHash
        });
    }

    function _validateUpdate(StreamSystemManifestUpdate calldata update) private pure {
        if (update.manifestHash == bytes32(0)) revert ManifestFieldZero(FIELD_MANIFEST_HASH);
        if (update.eventCatalogHash == bytes32(0)) {
            revert ManifestFieldZero(FIELD_EVENT_CATALOG_HASH);
        }
        if (update.compatibilityMatrixHash == bytes32(0)) {
            revert ManifestFieldZero(FIELD_COMPATIBILITY_MATRIX_HASH);
        }
        if (update.numericIdCatalogHash == bytes32(0)) {
            revert ManifestFieldZero(FIELD_NUMERIC_ID_CATALOG_HASH);
        }
        if (update.schemaCatalogHash == bytes32(0)) {
            revert ManifestFieldZero(FIELD_SCHEMA_CATALOG_HASH);
        }
        if (update.canonicalizationCatalogHash == bytes32(0)) {
            revert ManifestFieldZero(FIELD_CANONICALIZATION_CATALOG_HASH);
        }
        if (update.specBundleHash == bytes32(0)) {
            revert ManifestFieldZero(FIELD_SPEC_BUNDLE_HASH);
        }
        if (update.reconstructionClientHash == bytes32(0)) {
            revert ManifestFieldZero(FIELD_RECONSTRUCTION_CLIENT_HASH);
        }
        uint256 uriLength = bytes(update.manifestURI).length;
        if (uriLength == 0) revert ManifestURIEmpty();
        if (uriLength > MAX_MANIFEST_URI_BYTES) {
            revert ManifestURITooLarge(uriLength, MAX_MANIFEST_URI_BYTES);
        }
        if (!_isValidUtf8(update.manifestURI)) revert ManifestURIInvalidUTF8();
    }

    function _deriveModuleAddresses() private view returns (ModuleAddresses memory modules) {
        PointerFacts memory moduleRegistryFacts =
            _readPointer(MODULE_REGISTRY_POINTER, MODULE_REGISTRY_MODULE);
        address canonicalRegistry = moduleRegistryFacts.target;

        PointerFacts memory facts = _readPointer(ROYALTY_RESOLVER_POINTER, REVENUE_RESOLVER_MODULE);
        modules.revenueResolver = facts.target;

        facts = _readPointer(METADATA_ROUTER_POINTER, METADATA_ROUTER_MODULE);
        modules.metadataRouter = facts.target;

        facts = _readPointer(COLLECTION_METADATA_POINTER, COLLECTION_METADATA_MODULE);
        modules.collectionMetadata = facts.target;

        facts = _readPointer(ENTROPY_COORDINATOR_POINTER, ENTROPY_COORDINATOR_MODULE);
        modules.entropyCoordinator = facts.target;

        facts = _readPointer(MINT_MANAGER_POINTER, MINT_MANAGER_MODULE);
        modules.mintManager = facts.target;

        facts = _readPointer(MINT_LEDGER_POINTER, MINT_LEDGER_MODULE);
        modules.mintLedger = facts.target;

        facts = _readPointer(ARTIST_REGISTRY_POINTER, ARTIST_REGISTRY_MODULE);
        modules.artistRegistry = facts.target;

        facts = _readPointer(ARTWORK_FINALITY_REGISTRY_POINTER, ARTWORK_FINALITY_REGISTRY_MODULE);
        modules.artworkFinalityRegistry = facts.target;

        facts = _readPointer(STATE_EXPORT_PUBLISHER_POINTER, bytes32(0));
        if (
            facts.target != address(0)
                && (facts.interfaceId != STATE_EXPORT_PUBLISHER_INTERFACE_ID
                    || (facts.moduleType != STATE_EXPORT_PUBLISHER_MODULE
                        && (facts.moduleType != GOVERNANCE_LAYER_MODULE
                            || facts.target != governanceExecutor)))
        ) {
            revert InvalidStateExportPublisherPointer();
        }
        modules.stateExportPublisher = facts.target;

        facts = _readPointer(SYSTEM_MANIFEST_POINTER, STREAM_SYSTEM_MANIFEST_MODULE);
        if (
            facts.target != address(this) || !facts.frozen
                || facts.interfaceId != SYSTEM_MANIFEST_INTERFACE_ID
        ) {
            revert InvalidSystemManifestPointer();
        }

        modules.streamAdminsOrGovernance = governanceExecutor;
        modules.moduleRegistry = canonicalRegistry;
    }

    function _readPointer(bytes32 pointerType, bytes32 expectedModuleType)
        private
        view
        returns (PointerFacts memory facts)
    {
        (
            facts.target,
            facts.codeHash,
            facts.frozen,
            facts.moduleType,
            facts.interfaceId,
            facts.registry,
            facts.registryStatus,
            facts.moduleManifestHash,
            facts.deploymentManifestHash,
            facts.revision
        ) = IStreamSystemManifestCore(core).getSatellitePointer(pointerType);
        // Discovery describes the installed stack. Uninstalled product satellites
        // are zero addresses, rather than placeholder contracts. The canonical
        // registry and this frozen publication pointer are always required.
        if (
            facts.target == address(0) && pointerType != MODULE_REGISTRY_POINTER
                && pointerType != SYSTEM_MANIFEST_POINTER
        ) {
            if (
                facts.codeHash != bytes32(0) || facts.frozen || facts.moduleType != bytes32(0)
                    || facts.interfaceId != bytes4(0) || facts.registry != address(0)
                    || facts.registryStatus != 0 || facts.moduleManifestHash != bytes32(0)
                    || facts.deploymentManifestHash != bytes32(0) || facts.revision != 0
            ) revert InvalidSatellitePointer(pointerType);
            return facts;
        }
        if (
            facts.target == address(0) || facts.target.code.length == 0
                || _isDelegatedEOA(facts.target) || facts.codeHash == bytes32(0)
                || facts.target.codehash != facts.codeHash || facts.moduleType == bytes32(0)
                || (expectedModuleType != bytes32(0) && facts.moduleType != expectedModuleType)
                || facts.interfaceId == bytes4(0) || facts.registry == address(0)
                || facts.registry.code.length == 0 || _isDelegatedEOA(facts.registry)
                || facts.registryStatus != MODULE_STATUS_ACTIVE
                || facts.moduleManifestHash == bytes32(0)
                || facts.deploymentManifestHash == bytes32(0) || facts.revision == 0
        ) {
            revert InvalidSatellitePointer(pointerType);
        }
    }

    function _discoveryFrom(StreamSystemManifestUpdate calldata update)
        private
        pure
        returns (DiscoveryHashes memory discovery)
    {
        discovery = DiscoveryHashes({
            eventCatalogHash: update.eventCatalogHash,
            compatibilityMatrixHash: update.compatibilityMatrixHash,
            numericIdCatalogHash: update.numericIdCatalogHash,
            schemaCatalogHash: update.schemaCatalogHash,
            canonicalizationCatalogHash: update.canonicalizationCatalogHash,
            specBundleHash: update.specBundleHash,
            reconstructionClientHash: update.reconstructionClientHash
        });
    }

    function _storeAggregate(
        StreamSystemManifestUpdate calldata update,
        ModuleAddresses memory modules,
        DiscoveryHashes memory discovery,
        uint64 revision
    ) private {
        _aggregate.manifestHash = update.manifestHash;
        _aggregate.manifestURI = update.manifestURI;
        _aggregate.modules = modules;
        _aggregate.discovery = discovery;
        _aggregate.revision = revision;
    }

    function _scopeHash() private view returns (bytes32) {
        return keccak256(
            abi.encode(STREAM_SYSTEM_MANIFEST_SCOPE_V1, uint256(block.chainid), address(this))
        );
    }

    function _stateHash(
        bytes32 scopeHash,
        bytes32 manifestHash,
        bytes32 manifestURIHash,
        address payloadPointer,
        bytes32 moduleAddressesHash,
        bytes32 discoveryHashesHash,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                STREAM_SYSTEM_MANIFEST_STATE_V1,
                scopeHash,
                manifestHash,
                manifestURIHash,
                payloadPointer,
                moduleAddressesHash,
                discoveryHashesHash,
                revision
            )
        );
    }

    function _moduleAddressesHash(ModuleAddresses memory modules) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                modules.revenueResolver,
                modules.metadataRouter,
                modules.collectionMetadata,
                modules.entropyCoordinator,
                modules.mintManager,
                modules.mintLedger,
                modules.artistRegistry,
                modules.streamAdminsOrGovernance,
                modules.artworkFinalityRegistry,
                modules.moduleRegistry,
                modules.stateExportPublisher
            )
        );
    }

    function _discoveryHashesHash(DiscoveryHashes memory discovery) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                discovery.eventCatalogHash,
                discovery.compatibilityMatrixHash,
                discovery.numericIdCatalogHash,
                discovery.schemaCatalogHash,
                discovery.canonicalizationCatalogHash,
                discovery.specBundleHash,
                discovery.reconstructionClientHash
            )
        );
    }

    function _isDelegatedEOA(address account) private view returns (bool delegated) {
        if (account.code.length != 23) return false;
        bytes3 prefix;
        assembly ("memory-safe") {
            extcodecopy(account, 0x00, 0x00, 0x03)
            prefix := mload(0x00)
        }
        return prefix == 0xef0100;
    }

    function _isValidUtf8(string calldata raw) private pure returns (bool valid) {
        assembly ("memory-safe") {
            let cursor := raw.offset
            let end := add(cursor, raw.length)
            valid := 1

            for { } lt(cursor, end) { cursor := add(cursor, 1) } {
                let lead := byte(0, calldataload(cursor))

                if iszero(lt(lead, 0x80)) {
                    if or(lt(lead, 0xc2), gt(lead, 0xf4)) {
                        valid := 0
                        break
                    }

                    cursor := add(cursor, 1)
                    if iszero(lt(cursor, end)) {
                        valid := 0
                        break
                    }

                    let second := byte(0, calldataload(cursor))
                    if iszero(eq(and(second, 0xc0), 0x80)) {
                        valid := 0
                        break
                    }

                    if lt(lead, 0xe0) { continue }

                    if or(
                        and(eq(lead, 0xe0), lt(second, 0xa0)),
                        and(eq(lead, 0xed), gt(second, 0x9f))
                    ) {
                        valid := 0
                        break
                    }

                    cursor := add(cursor, 1)
                    if iszero(lt(cursor, end)) {
                        valid := 0
                        break
                    }
                    if iszero(eq(and(byte(0, calldataload(cursor)), 0xc0), 0x80)) {
                        valid := 0
                        break
                    }

                    if lt(lead, 0xf0) { continue }

                    if or(
                        and(eq(lead, 0xf0), lt(second, 0x90)),
                        and(eq(lead, 0xf4), gt(second, 0x8f))
                    ) {
                        valid := 0
                        break
                    }

                    cursor := add(cursor, 1)
                    if iszero(lt(cursor, end)) {
                        valid := 0
                        break
                    }
                    if iszero(eq(and(byte(0, calldataload(cursor)), 0xc0), 0x80)) {
                        valid := 0
                        break
                    }
                }
            }
        }
    }
}
