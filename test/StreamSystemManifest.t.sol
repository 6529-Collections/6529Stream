// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/vendor/openzeppelin/IERC165.sol";
import "../smart-contracts/interfaces/stream/IStreamGovernanceExecutor.sol";
import "../smart-contracts/interfaces/stream/IStreamSystemManifest.sol";
import "../smart-contracts/libraries/SSTORE2.sol";
import "../smart-contracts/domains/governance/StreamSystemManifest.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";

contract SystemManifestTargetMock { }

contract SystemManifestCoreMock is IStreamSystemManifestCore {
    struct StoredPointer {
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

    mapping(bytes32 => StoredPointer) private _pointers;

    function setPointer(
        bytes32 pointerType,
        address target,
        bool frozen,
        bytes32 moduleType,
        bytes4 interfaceId,
        address registry
    ) external {
        _pointers[pointerType] = StoredPointer({
            target: target,
            codeHash: target.codehash,
            frozen: frozen,
            moduleType: moduleType,
            interfaceId: interfaceId,
            registry: registry,
            registryStatus: 1,
            moduleManifestHash: keccak256(abi.encode("module-manifest", pointerType)),
            deploymentManifestHash: keccak256(abi.encode("deployment-manifest", pointerType)),
            revision: 1
        });
    }

    function clearPointer(bytes32 pointerType) external {
        delete _pointers[pointerType];
    }

    function setPointerCodeHash(bytes32 pointerType, bytes32 codeHash) external {
        _pointers[pointerType].codeHash = codeHash;
    }

    function setPointerFrozen(bytes32 pointerType, bool frozen) external {
        _pointers[pointerType].frozen = frozen;
    }

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
        )
    {
        StoredPointer storage pointer = _pointers[pointerType];
        return (
            pointer.target,
            pointer.codeHash,
            pointer.frozen,
            pointer.moduleType,
            pointer.interfaceId,
            pointer.registry,
            pointer.registryStatus,
            pointer.moduleManifestHash,
            pointer.deploymentManifestHash,
            pointer.revision
        );
    }
}

contract SystemManifestExecutorMock {
    bool private _executing;
    bytes32 private _actionId;
    uint8 private _actionClass;
    bytes32 private _scopeHash;
    bytes32 private _oldValueHash;
    bytes32 private _newValueHash;

    function currentAction()
        external
        view
        returns (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 scopeHash,
            bytes32 oldValueHash,
            bytes32 newValueHash
        )
    {
        return (_executing, _actionId, _actionClass, _scopeHash, _oldValueHash, _newValueHash);
    }

    function executePublication(
        IStreamSystemManifest manifest,
        address payloadPointer,
        StreamSystemManifestUpdate calldata update,
        bytes32 actionId,
        uint8 actionClass,
        bytes32 scopeHash,
        bytes32 oldValueHash,
        bytes32 newValueHash
    ) external {
        _executing = true;
        _actionId = actionId;
        _actionClass = actionClass;
        _scopeHash = scopeHash;
        _oldValueHash = oldValueHash;
        _newValueHash = newValueHash;
        manifest.publishStreamSystemManifest(payloadPointer, update);
        _clear();
    }

    function publishWithoutAction(
        IStreamSystemManifest manifest,
        address payloadPointer,
        StreamSystemManifestUpdate calldata update
    ) external {
        manifest.publishStreamSystemManifest(payloadPointer, update);
    }

    function _clear() private {
        _executing = false;
        _actionId = bytes32(0);
        _actionClass = 0;
        _scopeHash = bytes32(0);
        _oldValueHash = bytes32(0);
        _newValueHash = bytes32(0);
    }
}

contract SystemManifestSSTORE2Harness {
    function write(bytes calldata data) external returns (address) {
        return SSTORE2.write(data);
    }
}

contract StreamSystemManifestTest is CharacterizationTestBase {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for string;
    using Assertions for uint256;

    bytes32 private constant SCOPE_DOMAIN =
        0xf73b4d7b4d260fce0823707f836fdf29a1767a2a2a9cfbce14ec8c5e49e47841;
    bytes32 private constant STATE_DOMAIN =
        0x3764ccb415d0aac07f1bddb8d4841ad6d4c2f9b2fe7ce7d221c586bc056aaf60;
    bytes32 private constant PAYLOAD_V1 =
        0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81;
    bytes32 private constant JCS =
        0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044;
    bytes32 private constant PAYLOAD_ROOT_V1 =
        0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b;
    bytes32 private constant PAYLOAD_LEAF_V1 =
        0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5;
    bytes32 private constant PAYLOAD_LIST_V1 =
        0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839;
    bytes4 private constant ROOT_MAGIC = 0x6c9d2530;
    bytes32 private constant ACTION_ID = keccak256("system-manifest-action");

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

    struct ManifestChunk {
        address pointer;
        uint32 payloadLength;
        bytes32 payloadHash;
    }

    struct ExpectedModules {
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

    SystemManifestCoreMock private core;
    SystemManifestExecutorMock private executor;
    StreamSystemManifest private manifest;
    SystemManifestSSTORE2Harness private writer;
    SystemManifestTargetMock private registry;
    SystemManifestTargetMock private sharedTarget;
    SystemManifestTargetMock private replacementTarget;

    function setUp() public {
        core = new SystemManifestCoreMock();
        executor = new SystemManifestExecutorMock();
        writer = new SystemManifestSSTORE2Harness();
        registry = new SystemManifestTargetMock();
        sharedTarget = new SystemManifestTargetMock();
        replacementTarget = new SystemManifestTargetMock();
        manifest = new StreamSystemManifest(address(core), address(executor));
        _configurePointers(address(sharedTarget));
    }

    function testPinsSelectorsInterfaceBindingsAndInitialState() public view {
        uint256(uint32(IStreamSystemManifest.streamSystemManifest.selector))
            .assertEq(uint256(uint32(0x97c93f10)), "aggregate selector");
        uint256(uint32(IStreamSystemManifest.streamSystemManifestPointer.selector))
            .assertEq(uint256(uint32(0x7b3a36b1)), "current pointer selector");
        uint256(uint32(IStreamSystemManifest.streamSystemManifestPointerCount.selector))
            .assertEq(uint256(uint32(0x5b1e1cba)), "pointer count selector");
        uint256(uint32(IStreamSystemManifest.streamSystemManifestPointerAt.selector))
            .assertEq(uint256(uint32(0x893aae03)), "pointer at selector");
        uint256(uint32(IStreamSystemManifest.publishStreamSystemManifest.selector))
            .assertEq(uint256(uint32(0x09b1b5c6)), "publication selector");
        uint256(uint32(type(IStreamSystemManifest).interfaceId))
            .assertEq(uint256(uint32(0x37660ede)), "manifest interface id");

        manifest.core().assertEq(address(core), "core binding");
        manifest.governanceExecutor().assertEq(address(executor), "executor binding");
        manifest.supportsInterface(0x37660ede).assertTrue("manifest ERC165 support");
        manifest.supportsInterface(type(IERC165).interfaceId).assertTrue("IERC165 support");
        manifest.supportsInterface(0xffffffff).assertFalse("invalid ERC165 id");
        manifest.streamSystemManifestPointer().assertEq(address(0), "empty current pointer");
        manifest.streamSystemManifestPointerCount().assertEq(0, "empty pointer history");

        (bool ok, bytes memory data) =
            address(manifest).staticcall(abi.encodeCall(manifest.streamSystemManifest, ()));
        ok.assertTrue("initial aggregate read");
        _word(data, 0).assertEq(bytes32(0), "empty manifest hash");
        uint256(_word(data, 20)).assertEq(0, "empty revision");
    }

    function testConstructorRejectsInvalidAndDuplicateBindings() public {
        vm.expectRevert(
            abi.encodeWithSelector(StreamSystemManifest.InvalidCore.selector, address(0))
        );
        new StreamSystemManifest(address(0), address(executor));

        address codeLessCore = address(0xC0DE);
        vm.expectRevert(
            abi.encodeWithSelector(StreamSystemManifest.InvalidCore.selector, codeLessCore)
        );
        new StreamSystemManifest(codeLessCore, address(executor));

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.InvalidGovernanceExecutor.selector, address(0)
            )
        );
        new StreamSystemManifest(address(core), address(0));

        address codeLessExecutor = address(0xE0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.InvalidGovernanceExecutor.selector, codeLessExecutor
            )
        );
        new StreamSystemManifest(address(core), codeLessExecutor);

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.DuplicateImmutableBinding.selector, address(core)
            )
        );
        new StreamSystemManifest(address(core), address(core));
    }

    function testFirstPublicationCachesStorageOnlyAggregateAndEmitsExactEvent() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("first", "ipfs://manifest/\xF0\x9F\x8C\x8A");
        bytes32 oldValueHash = _emptyStateHash();
        bytes32 newValueHash = _newStateHash(payloadPointer, update, _expectedModules(), 1);
        vm.warp(1_234_567);
        vm.recordLogs();
        _execute(3, payloadPointer, update, oldValueHash, newValueHash);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        logs.length.assertEq(1, "one publication event");
        logs[0].emitter.assertEq(address(manifest), "event emitter");
        logs[0].topics[0].assertEq(
            keccak256("StreamSystemManifestPublished(uint16,bytes32,address,bytes32)"),
            "event topic"
        );
        logs[0].topics[1].assertEq(update.manifestHash, "indexed manifest hash");
        logs[0].topics[2].assertEq(bytes32(uint256(uint160(payloadPointer))), "indexed pointer");
        logs[0].topics[3].assertEq(ACTION_ID, "indexed action id");
        uint256(abi.decode(logs[0].data, (uint16))).assertEq(1, "event schema");

        manifest.streamSystemManifestPointer().assertEq(payloadPointer, "current pointer");
        manifest.streamSystemManifestPointerCount().assertEq(1, "history count");
        (address storedPointer, bytes32 storedHash, uint64 updatedAt) =
            manifest.streamSystemManifestPointerAt(0);
        storedPointer.assertEq(payloadPointer, "history pointer");
        storedHash.assertEq(update.manifestHash, "history hash");
        uint256(updatedAt).assertEq(1_234_567, "history timestamp");

        (bool ok, bytes memory data) =
            address(manifest).staticcall(abi.encodeCall(manifest.streamSystemManifest, ()));
        ok.assertTrue("aggregate read");
        _word(data, 0).assertEq(update.manifestHash, "aggregate manifest hash");
        _wordAddress(data, 2).assertEq(address(sharedTarget), "revenue resolver");
        _wordAddress(data, 9).assertEq(address(executor), "governance aggregate");
        _wordAddress(data, 11).assertEq(address(registry), "module registry");
        _wordAddress(data, 12).assertEq(address(executor), "state export publisher");
        _word(data, 13).assertEq(update.eventCatalogHash, "event catalog");
        uint256(_word(data, 20)).assertEq(1, "aggregate revision");

        core.setPointer(
            METADATA_ROUTER_POINTER,
            address(replacementTarget),
            false,
            keccak256("METADATA_ROUTER"),
            bytes4(0x11111111),
            address(registry)
        );
        (ok, data) = address(manifest).staticcall(abi.encodeCall(manifest.streamSystemManifest, ()));
        ok.assertTrue("storage-only aggregate reread");
        _wordAddress(data, 3).assertEq(address(sharedTarget), "cached metadata router");
    }

    function testRejectsUnauthorizedMissingActionAndUnknownClass() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("authority", "ipfs://authority");

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.UnauthorizedGovernanceExecutor.selector, address(this)
            )
        );
        manifest.publishStreamSystemManifest(payloadPointer, update);

        vm.expectRevert(
            abi.encodeWithSelector(StreamSystemManifest.NoExecutingGovernanceAction.selector)
        );
        executor.publishWithoutAction(manifest, payloadPointer, update);

        vm.expectRevert(
            abi.encodeWithSelector(StreamSystemManifest.InvalidGovernanceActionClass.selector, 4)
        );
        _execute(4, payloadPointer, update, bytes32(0), bytes32(0));

        vm.expectRevert(
            abi.encodeWithSelector(StreamSystemManifest.InvalidGovernanceActionClass.selector, 6)
        );
        _execute(6, payloadPointer, update, bytes32(0), bytes32(0));
    }

    function testRejectsEveryForgedPerCallCommitment() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("context", "ipfs://context");
        bytes32 scopeHash = _scopeHash();
        bytes32 oldValueHash = _emptyStateHash();
        bytes32 newValueHash = _newStateHash(payloadPointer, update, _expectedModules(), 1);
        bytes32 wrong = keccak256("wrong");

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.GovernanceScopeHashMismatch.selector, scopeHash, wrong
            )
        );
        executor.executePublication(
            manifest, payloadPointer, update, ACTION_ID, 3, wrong, oldValueHash, newValueHash
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.GovernanceOldValueHashMismatch.selector, oldValueHash, wrong
            )
        );
        executor.executePublication(
            manifest, payloadPointer, update, ACTION_ID, 3, scopeHash, wrong, newValueHash
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.GovernanceNewValueHashMismatch.selector, newValueHash, wrong
            )
        );
        executor.executePublication(
            manifest, payloadPointer, update, ACTION_ID, 3, scopeHash, oldValueHash, wrong
        );
        manifest.streamSystemManifestPointerCount().assertEq(0, "forged context rollback");
    }

    function testClassesZeroOneTwoMayRefreshPayloadButNotAggregate() public {
        (address priorPointer, StreamSystemManifestUpdate memory priorUpdate) =
            _publishFirst("class-three");
        ExpectedModules memory modules = _expectedModules();
        for (uint8 actionClass = 0; actionClass < 3; actionClass++) {
            (address nextPointer, StreamSystemManifestUpdate memory nextUpdate) = _payloadAndUpdate(
                string(abi.encodePacked("class-", bytes1(uint8(0x30 + actionClass)))),
                string(abi.encodePacked("ipfs://class/", bytes1(uint8(0x30 + actionClass))))
            );
            _copyDiscovery(priorUpdate, nextUpdate);
            bytes32 oldValueHash = _stateHashFor(
                priorPointer,
                priorUpdate,
                _moduleAddressesHash(modules),
                _discoveryHashesHash(priorUpdate),
                uint64(actionClass + 1)
            );
            bytes32 newValueHash =
                _newStateHash(nextPointer, nextUpdate, modules, uint64(actionClass + 2));
            _execute(actionClass, nextPointer, nextUpdate, oldValueHash, newValueHash);
            priorPointer = nextPointer;
            priorUpdate = nextUpdate;
        }
        manifest.streamSystemManifestPointerCount().assertEq(4, "all closed classes published");
    }

    function testOnlyClassThreeMayChangePointerDerivedAggregate() public {
        (address firstPointer, StreamSystemManifestUpdate memory firstUpdate) =
            _publishFirst("aggregate-before");
        ExpectedModules memory oldModules = _expectedModules();
        core.setPointer(
            METADATA_ROUTER_POINTER,
            address(replacementTarget),
            false,
            keccak256("METADATA_ROUTER"),
            bytes4(0x11111111),
            address(registry)
        );
        ExpectedModules memory newModules = _expectedModules();
        newModules.metadataRouter = address(replacementTarget);
        (address nextPointer, StreamSystemManifestUpdate memory nextUpdate) =
            _payloadAndUpdate("aggregate-after", "ipfs://aggregate-after");
        _copyDiscovery(firstUpdate, nextUpdate);
        bytes32 oldValueHash = _stateHashFor(
            firstPointer,
            firstUpdate,
            _moduleAddressesHash(oldModules),
            _discoveryHashesHash(firstUpdate),
            1
        );
        bytes32 newValueHash = _newStateHash(nextPointer, nextUpdate, newModules, 2);

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.AggregateMutationRequiresReplacement.selector, 0
            )
        );
        _execute(0, nextPointer, nextUpdate, oldValueHash, newValueHash);
        _execute(3, nextPointer, nextUpdate, oldValueHash, newValueHash);

        (bool ok, bytes memory data) =
            address(manifest).staticcall(abi.encodeCall(manifest.streamSystemManifest, ()));
        ok.assertTrue("post-replacement aggregate");
        _wordAddress(data, 3).assertEq(address(replacementTarget), "replaced metadata router");
    }

    function testOnlyClassThreeMayChangeDiscoveryHashes() public {
        (address firstPointer, StreamSystemManifestUpdate memory firstUpdate) =
            _publishFirst("catalog-before");
        ExpectedModules memory modules = _expectedModules();
        (address nextPointer, StreamSystemManifestUpdate memory nextUpdate) =
            _payloadAndUpdate("catalog-after", "ipfs://catalog-after");
        nextUpdate.eventCatalogHash = keccak256("replacement-event-catalog");
        bytes32 oldValueHash = _stateHashFor(
            firstPointer,
            firstUpdate,
            _moduleAddressesHash(modules),
            _discoveryHashesHash(firstUpdate),
            1
        );
        bytes32 newValueHash = _newStateHash(nextPointer, nextUpdate, modules, 2);

        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.AggregateMutationRequiresReplacement.selector, 2
            )
        );
        _execute(2, nextPointer, nextUpdate, oldValueHash, newValueHash);
        _execute(3, nextPointer, nextUpdate, oldValueHash, newValueHash);
    }

    function testRejectsEmptyOversizedAndMalformedUtf8URI() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("uri", "ipfs://valid");

        update.manifestURI = "";
        vm.expectRevert(abi.encodeWithSelector(StreamSystemManifest.ManifestURIEmpty.selector));
        _execute(3, payloadPointer, update, bytes32(0), bytes32(0));

        bytes memory oversized = new bytes(2_049);
        for (uint256 i = 0; i < oversized.length; i++) {
            oversized[i] = "a";
        }
        update.manifestURI = string(oversized);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.ManifestURITooLarge.selector, uint256(2_049), uint256(2_048)
            )
        );
        _execute(3, payloadPointer, update, bytes32(0), bytes32(0));

        bytes memory invalidUtf8 = new bytes(8);
        invalidUtf8[0] = "i";
        invalidUtf8[1] = "p";
        invalidUtf8[2] = "f";
        invalidUtf8[3] = "s";
        invalidUtf8[4] = ":";
        invalidUtf8[5] = "/";
        invalidUtf8[6] = bytes1(uint8(0xc0));
        invalidUtf8[7] = bytes1(uint8(0x80));
        update.manifestURI = string(invalidUtf8);
        vm.expectRevert(
            abi.encodeWithSelector(StreamSystemManifest.ManifestURIInvalidUTF8.selector)
        );
        _execute(3, payloadPointer, update, bytes32(0), bytes32(0));
    }

    function testAcceptsMaximumLengthValidUtf8URI() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("max-uri", "ipfs://placeholder");
        bytes memory uri = new bytes(2_048);
        for (uint256 i = 0; i < uri.length; i++) {
            uri[i] = "a";
        }
        update.manifestURI = string(uri);
        _execute(
            3,
            payloadPointer,
            update,
            _emptyStateHash(),
            _newStateHash(payloadPointer, update, _expectedModules(), 1)
        );
    }

    function testRejectsZeroDiscoveryCommitmentAndWrongPayloadRoot() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("fields", "ipfs://fields");
        update.schemaCatalogHash = bytes32(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.ManifestFieldZero.selector, keccak256("schemaCatalogHash")
            )
        );
        _execute(3, payloadPointer, update, bytes32(0), bytes32(0));

        update.schemaCatalogHash = keccak256("schema");
        update.manifestHash = keccak256("wrong-root");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.InvalidManifestTail.selector)
        );
        _execute(3, payloadPointer, update, bytes32(0), bytes32(0));
    }

    function testAllowsUninstalledOptionalPointerWithoutPlaceholder() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("missing", "ipfs://missing");
        core.clearPointer(METADATA_ROUTER_POINTER);
        ExpectedModules memory modules = _expectedModules();
        modules.metadataRouter = address(0);
        _execute(
            3,
            payloadPointer,
            update,
            _emptyStateHash(),
            _newStateHash(payloadPointer, update, modules, 1)
        );
        (bool ok, bytes memory data) =
            address(manifest).staticcall(abi.encodeCall(manifest.streamSystemManifest, ()));
        require(ok && _wordAddress(data, 3) == address(0), "absence is discoverable");
    }

    function testRejectsStaleInstalledPointerRecords() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("stale", "ipfs://stale");
        core.setPointer(
            METADATA_ROUTER_POINTER,
            address(sharedTarget),
            false,
            keccak256("METADATA_ROUTER"),
            bytes4(0x11111111),
            address(registry)
        );
        core.setPointerCodeHash(METADATA_ROUTER_POINTER, keccak256("stale"));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.InvalidSatellitePointer.selector, METADATA_ROUTER_POINTER
            )
        );
        _execute(3, payloadPointer, update, bytes32(0), bytes32(0));
    }

    function testStillRequiresCanonicalRegistryWhenOtherPointersAreOptional() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("registry", "ipfs://registry");
        core.clearPointer(MODULE_REGISTRY_POINTER);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSystemManifest.InvalidSatellitePointer.selector, MODULE_REGISTRY_POINTER
            )
        );
        _execute(3, payloadPointer, update, bytes32(0), bytes32(0));
    }

    function testHistoricalRegistryFieldsRemainAuditEvidenceAcrossRegistrySuccessor() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("registry-successor", "ipfs://registry-successor");
        core.setPointer(
            MODULE_REGISTRY_POINTER,
            address(replacementTarget),
            false,
            keccak256("MODULE_REGISTRY"),
            bytes4(0x11111111),
            address(registry)
        );
        ExpectedModules memory modules = _expectedModules();
        modules.moduleRegistry = address(replacementTarget);
        _execute(
            3,
            payloadPointer,
            update,
            _emptyStateHash(),
            _newStateHash(payloadPointer, update, modules, 1)
        );

        (bool ok, bytes memory data) =
            address(manifest).staticcall(abi.encodeCall(manifest.streamSystemManifest, ()));
        ok.assertTrue("registry-successor aggregate");
        _wordAddress(data, 11).assertEq(address(replacementTarget), "live registry target");
    }

    function testRejectsMutableSystemPointer() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("pointer-bindings", "ipfs://pointer-bindings");
        core.setPointerFrozen(SYSTEM_MANIFEST_POINTER, false);
        vm.expectRevert(
            abi.encodeWithSelector(StreamSystemManifest.InvalidSystemManifestPointer.selector)
        );
        _execute(3, payloadPointer, update, bytes32(0), bytes32(0));
    }

    function testAcceptsDedicatedStateExportPublisher() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("publisher", "ipfs://publisher");
        core.setPointer(
            STATE_EXPORT_PUBLISHER_POINTER,
            address(sharedTarget),
            false,
            keccak256("STATE_EXPORT_PUBLISHER"),
            bytes4(0x77faad4f),
            address(registry)
        );
        ExpectedModules memory modules = _expectedModules();
        modules.stateExportPublisher = address(sharedTarget);
        _execute(
            3,
            payloadPointer,
            update,
            _emptyStateHash(),
            _newStateHash(payloadPointer, update, modules, 1)
        );
    }

    function testRejectsStateExportPublisherWithWrongInterface() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("publisher-interface", "ipfs://publisher-interface");
        core.setPointer(
            STATE_EXPORT_PUBLISHER_POINTER,
            address(sharedTarget),
            false,
            keccak256("STATE_EXPORT_PUBLISHER"),
            bytes4(0x11111111),
            address(registry)
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamSystemManifest.InvalidStateExportPublisherPointer.selector)
        );
        _execute(3, payloadPointer, update, bytes32(0), bytes32(0));
    }

    function testRejectsStateExportPublisherFromUnrelatedModuleFamily() public {
        (address payloadPointer, StreamSystemManifestUpdate memory update) =
            _payloadAndUpdate("publisher-family", "ipfs://publisher-family");
        core.setPointer(
            STATE_EXPORT_PUBLISHER_POINTER,
            address(sharedTarget),
            false,
            keccak256("UNRELATED_MODULE"),
            bytes4(0x77faad4f),
            address(registry)
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamSystemManifest.InvalidStateExportPublisherPointer.selector)
        );
        _execute(3, payloadPointer, update, bytes32(0), bytes32(0));
    }

    function testHistoryIsAppendOnlyAndExactNoOpRejects() public {
        (address firstPointer, StreamSystemManifestUpdate memory firstUpdate) =
            _publishFirst("history-one");
        ExpectedModules memory modules = _expectedModules();
        bytes32 oldValueHash = _stateHashFor(
            firstPointer,
            firstUpdate,
            _moduleAddressesHash(modules),
            _discoveryHashesHash(firstUpdate),
            1
        );
        bytes32 noOpNewValueHash = _stateHashFor(
            firstPointer,
            firstUpdate,
            _moduleAddressesHash(modules),
            _discoveryHashesHash(firstUpdate),
            2
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamSystemManifest.NoOpManifestPublication.selector)
        );
        _execute(0, firstPointer, firstUpdate, oldValueHash, noOpNewValueHash);

        (address secondPointer, StreamSystemManifestUpdate memory secondUpdate) =
            _payloadAndUpdate("history-two", "ipfs://history-two");
        _copyDiscovery(firstUpdate, secondUpdate);
        bytes32 secondNewValueHash = _newStateHash(secondPointer, secondUpdate, modules, 2);
        _execute(0, secondPointer, secondUpdate, oldValueHash, secondNewValueHash);

        manifest.streamSystemManifestPointerCount().assertEq(2, "two immutable entries");
        (address storedPointer, bytes32 storedHash,) = manifest.streamSystemManifestPointerAt(0);
        storedPointer.assertEq(firstPointer, "first pointer retained");
        storedHash.assertEq(firstUpdate.manifestHash, "first hash retained");
        (storedPointer, storedHash,) = manifest.streamSystemManifestPointerAt(1);
        storedPointer.assertEq(secondPointer, "second pointer appended");
        storedHash.assertEq(secondUpdate.manifestHash, "second hash appended");
    }

    function testMaximumPayloadWithRepeatedCanonicalChunkStaysWithinWriterGasCeiling() public {
        (address payloadPointer, bytes32 manifestHash) = _repeatedMaximumPayload(32);
        StreamSystemManifestUpdate memory update =
            _update(manifestHash, "ipfs://maximum-repeated-chunk");
        uint256 gasBefore = gasleft();
        _execute(
            3,
            payloadPointer,
            update,
            _emptyStateHash(),
            _newStateHash(payloadPointer, update, _expectedModules(), 1)
        );
        uint256 used = gasBefore - gasleft();
        used.assertGte(1, "gas measured");
        require(used <= 12_000_000, "writer gas ceiling");
    }

    function _configurePointers(address commonTarget) private {
        address registryAddress = address(registry);
        core.setPointer(
            MODULE_REGISTRY_POINTER,
            registryAddress,
            false,
            keccak256("MODULE_REGISTRY"),
            bytes4(0x11111111),
            registryAddress
        );
        core.setPointer(
            ROYALTY_RESOLVER_POINTER,
            commonTarget,
            false,
            keccak256("REVENUE_RESOLVER"),
            bytes4(0x11111111),
            registryAddress
        );
        core.setPointer(
            METADATA_ROUTER_POINTER,
            commonTarget,
            false,
            keccak256("METADATA_ROUTER"),
            bytes4(0x11111111),
            registryAddress
        );
        core.setPointer(
            COLLECTION_METADATA_POINTER,
            commonTarget,
            false,
            keccak256("COLLECTION_METADATA"),
            bytes4(0x11111111),
            registryAddress
        );
        core.setPointer(
            ENTROPY_COORDINATOR_POINTER,
            commonTarget,
            false,
            keccak256("ENTROPY_COORDINATOR"),
            bytes4(0x11111111),
            registryAddress
        );
        core.setPointer(
            MINT_MANAGER_POINTER,
            commonTarget,
            false,
            keccak256("MINT_MANAGER"),
            bytes4(0x11111111),
            registryAddress
        );
        core.setPointer(
            MINT_LEDGER_POINTER,
            commonTarget,
            false,
            keccak256("MINT_LEDGER"),
            bytes4(0x11111111),
            registryAddress
        );
        core.setPointer(
            ARTIST_REGISTRY_POINTER,
            commonTarget,
            false,
            keccak256("ARTIST_REGISTRY"),
            bytes4(0x11111111),
            registryAddress
        );
        core.setPointer(
            ARTWORK_FINALITY_REGISTRY_POINTER,
            commonTarget,
            false,
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            bytes4(0x11111111),
            registryAddress
        );
        core.setPointer(
            STATE_EXPORT_PUBLISHER_POINTER,
            address(executor),
            false,
            keccak256("GOVERNANCE_LAYER"),
            bytes4(0x77faad4f),
            registryAddress
        );
        core.setPointer(
            SYSTEM_MANIFEST_POINTER,
            address(manifest),
            true,
            keccak256("STREAM_SYSTEM_MANIFEST"),
            bytes4(0x37660ede),
            registryAddress
        );
    }

    function _publishFirst(string memory seed)
        private
        returns (address payloadPointer, StreamSystemManifestUpdate memory update)
    {
        (payloadPointer, update) =
            _payloadAndUpdate(seed, string(abi.encodePacked("ipfs://", seed)));
        _execute(
            3,
            payloadPointer,
            update,
            _emptyStateHash(),
            _newStateHash(payloadPointer, update, _expectedModules(), 1)
        );
    }

    function _execute(
        uint8 actionClass,
        address payloadPointer,
        StreamSystemManifestUpdate memory update,
        bytes32 oldValueHash,
        bytes32 newValueHash
    ) private {
        executor.executePublication(
            manifest,
            payloadPointer,
            update,
            ACTION_ID,
            actionClass,
            _scopeHash(),
            oldValueHash,
            newValueHash
        );
    }

    function _payloadAndUpdate(string memory seed, string memory uri)
        private
        returns (address payloadPointer, StreamSystemManifestUpdate memory update)
    {
        bytes memory segment = abi.encodePacked(
            "{\"schema\":\"STREAM_SYSTEM_MANIFEST_PAYLOAD_V1\",\"seed\":\"", seed, "\"}"
        );
        address chunkPointer = writer.write(segment);
        ManifestChunk[] memory chunks = new ManifestChunk[](1);
        chunks[0] = ManifestChunk({
            pointer: chunkPointer,
            payloadLength: uint32(segment.length),
            payloadHash: keccak256(segment)
        });
        (payloadPointer, update.manifestHash) = _root(chunks, uint32(segment.length));
        update = _update(update.manifestHash, uri);
    }

    function _repeatedMaximumPayload(uint16 chunkCount)
        private
        returns (address payloadPointer, bytes32 manifestHash)
    {
        bytes memory segment = new bytes(24_575);
        address chunkPointer = writer.write(segment);
        bytes32 payloadHash = keccak256(segment);
        ManifestChunk[] memory chunks = new ManifestChunk[](chunkCount);
        for (uint256 i = 0; i < chunkCount; i++) {
            chunks[i] = ManifestChunk({
                pointer: chunkPointer, payloadLength: 24_575, payloadHash: payloadHash
            });
        }
        return _root(chunks, uint32(uint256(chunkCount) * 24_575));
    }

    function _root(ManifestChunk[] memory chunks, uint32 totalBytes)
        private
        returns (address payloadPointer, bytes32 manifestHash)
    {
        bytes32[] memory leaves = new bytes32[](chunks.length);
        for (uint256 i = 0; i < chunks.length; i++) {
            leaves[i] = keccak256(
                abi.encode(PAYLOAD_LEAF_V1, i, chunks[i].payloadLength, chunks[i].payloadHash)
            );
        }
        bytes32 listHash = keccak256(abi.encode(PAYLOAD_LIST_V1, totalBytes, leaves));
        manifestHash = keccak256(
            abi.encode(
                PAYLOAD_ROOT_V1,
                uint16(1),
                PAYLOAD_V1,
                JCS,
                totalBytes,
                uint16(chunks.length),
                listHash
            )
        );
        bytes memory descriptor = abi.encode(
            ROOT_MAGIC, uint16(1), PAYLOAD_V1, JCS, totalBytes, uint16(chunks.length), chunks
        );
        payloadPointer = writer.write(descriptor);
    }

    function _update(bytes32 manifestHash, string memory uri)
        private
        pure
        returns (StreamSystemManifestUpdate memory update)
    {
        update = StreamSystemManifestUpdate({
            manifestHash: manifestHash,
            manifestURI: uri,
            eventCatalogHash: keccak256("event-catalog"),
            compatibilityMatrixHash: keccak256("compatibility-matrix"),
            numericIdCatalogHash: keccak256("numeric-id-catalog"),
            schemaCatalogHash: keccak256("schema-catalog"),
            canonicalizationCatalogHash: keccak256("canonicalization-catalog"),
            specBundleHash: keccak256("spec-bundle"),
            reconstructionClientHash: keccak256("reconstruction-client")
        });
    }

    function _copyDiscovery(
        StreamSystemManifestUpdate memory source,
        StreamSystemManifestUpdate memory target
    ) private pure {
        target.eventCatalogHash = source.eventCatalogHash;
        target.compatibilityMatrixHash = source.compatibilityMatrixHash;
        target.numericIdCatalogHash = source.numericIdCatalogHash;
        target.schemaCatalogHash = source.schemaCatalogHash;
        target.canonicalizationCatalogHash = source.canonicalizationCatalogHash;
        target.specBundleHash = source.specBundleHash;
        target.reconstructionClientHash = source.reconstructionClientHash;
    }

    function _expectedModules() private view returns (ExpectedModules memory modules) {
        modules = ExpectedModules({
            revenueResolver: address(sharedTarget),
            metadataRouter: address(sharedTarget),
            collectionMetadata: address(sharedTarget),
            entropyCoordinator: address(sharedTarget),
            mintManager: address(sharedTarget),
            mintLedger: address(sharedTarget),
            artistRegistry: address(sharedTarget),
            streamAdminsOrGovernance: address(executor),
            artworkFinalityRegistry: address(sharedTarget),
            moduleRegistry: address(registry),
            stateExportPublisher: address(executor)
        });
    }

    function _emptyStateHash() private view returns (bytes32) {
        ExpectedModules memory empty;
        StreamSystemManifestUpdate memory update;
        return _stateHashFor(
            address(0), update, _moduleAddressesHash(empty), _discoveryHashesHash(update), 0
        );
    }

    function _newStateHash(
        address payloadPointer,
        StreamSystemManifestUpdate memory update,
        ExpectedModules memory modules,
        uint64 revision
    ) private view returns (bytes32) {
        return _stateHashFor(
            payloadPointer,
            update,
            _moduleAddressesHash(modules),
            _discoveryHashesHash(update),
            revision
        );
    }

    function _stateHashFor(
        address payloadPointer,
        StreamSystemManifestUpdate memory update,
        bytes32 moduleAddressesHash,
        bytes32 discoveryHashesHash,
        uint64 revision
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                STATE_DOMAIN,
                _scopeHash(),
                update.manifestHash,
                keccak256(bytes(update.manifestURI)),
                payloadPointer,
                moduleAddressesHash,
                discoveryHashesHash,
                revision
            )
        );
    }

    function _scopeHash() private view returns (bytes32) {
        return keccak256(abi.encode(SCOPE_DOMAIN, uint256(block.chainid), address(manifest)));
    }

    function _moduleAddressesHash(ExpectedModules memory modules) private pure returns (bytes32) {
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

    function _discoveryHashesHash(StreamSystemManifestUpdate memory update)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                update.eventCatalogHash,
                update.compatibilityMatrixHash,
                update.numericIdCatalogHash,
                update.schemaCatalogHash,
                update.canonicalizationCatalogHash,
                update.specBundleHash,
                update.reconstructionClientHash
            )
        );
    }

    function _word(bytes memory data, uint256 index) private pure returns (bytes32 value) {
        assembly ("memory-safe") {
            value := mload(add(add(data, 0x20), mul(index, 0x20)))
        }
    }

    function _wordAddress(bytes memory data, uint256 index) private pure returns (address) {
        return address(uint160(uint256(_word(data, index))));
    }
}
