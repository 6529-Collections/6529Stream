// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../core/StreamCorePermanentTarget.t.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";

/// @dev Core execution is actual. Governance, module inventory, Manager and entropy use
///      explicit boundaries from the retained Core fixture; no full-stack acceptance claim.
contract InventoryGovernanceBoundary is PermanentTargetGovernanceExecutor {
    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }
}

contract InventoryMintCallbackBoundary {
    StreamCollectionTokenInventory public immutable inventory;
    bool public rejectReceiver;
    bool public entropyRejectedIncomplete;

    constructor(StreamCollectionTokenInventory inventory_) {
        inventory = inventory_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamEntropyCoordinator).interfaceId || id == 0x01ffc9a7;
    }

    function setRejectReceiver(bool value) external {
        rejectReceiver = value;
    }

    function onTokenMinted(uint256 collectionId, uint256 tokenId, address, bytes32) external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        (bool ok, bytes memory reason) = address(inventory)
            .call(abi.encodeCall(inventory.appendCollectionTokens, (collectionId, ids)));
        require(
            !ok
                && bytes4(reason)
                    == IStreamCollectionTokenInventory.InventoryTokenMismatch.selector,
            "entropy callback must reject incomplete identity"
        );
        entropyRejectedIncomplete = true;
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        returns (bytes4)
    {
        (bool exists, uint256 collectionId,,) =
            IStreamCoreIdentity(msg.sender).tokenCollectionIdentity(tokenId);
        require(exists, "actual callback identity");
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        inventory.appendCollectionTokens(collectionId, ids);
        inventory.requireCompleteCollection(collectionId);
        require(!rejectReceiver, "receiver rejects after indexing");
        return 0x150b7a02;
    }
}

contract StreamCollectionTokenInventoryTest is CharacterizationTestBase, OfficialSafeFixture {
    StreamCollectionTokenInventory private inventory;
    address private constant OWNER = address(0xA11CE);

    function testKnownEmptyCollectionAndUnknownCollection() public {
        (uint256 count, bytes32 prefix) = inventory.requireCompleteCollection(1);
        require(count == 0 && prefix == _emptyPrefix(1), "known empty collection");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionTokenInventory.InventoryCollectionUnknown.selector, 3
            )
        );
        inventory.requireCompleteCollection(3);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionTokenInventory.InventoryCollectionUnknown.selector, 0
            )
        );
        inventory.requireCompleteCollection(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionTokenInventory.InventoryIndexOutOfBounds.selector, 1, 0
            )
        );
        inventory.collectionTokenAt(1, 0);
    }

    function testActualInterleavedMintsExactInventoryHashAndEvents() public {
        uint256 first = _mint(1);
        uint256 other = _mint(2);
        uint256 second = _mint(1);
        uint256[] memory ids = _pair(first, second);
        vm.recordLogs();
        inventory.appendCollectionTokens(1, ids);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2, "two append events");
        bytes32 prefix = _emptyPrefix(1);
        for (uint256 i; i < 2; ++i) {
            prefix = keccak256(abi.encode(inventory.APPEND_DOMAIN(), prefix, i + 1, ids[i]));
            require(logs[i].emitter == address(inventory), "event emitter");
            require(logs[i].topics.length == 3, "indexed topic count");
            require(
                logs[i].topics[0]
                    == keccak256("CollectionTokenIndexed(uint256,uint256,uint256,bytes32)"),
                "event signature"
            );
            require(
                logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == bytes32(ids[i]),
                "event subject"
            );
            require(
                keccak256(logs[i].data) == keccak256(abi.encode(i + 1, prefix)),
                "event serial and prefix"
            );
            require(inventory.collectionTokenAt(1, i) == ids[i], "permanent order");
        }
        (uint256 count, bytes32 actual) = inventory.requireCompleteCollection(1);
        require(count == 2 && actual == prefix, "complete exact prefix");
        inventory.appendCollectionTokens(2, _one(other));
        (count,) = inventory.requireCompleteCollection(2);
        require(count == 1, "isolated other collection");
    }

    function testBurnBeforeAndAfterIndexRetainsEveryCompletedMint() public {
        uint256 first = _mint(1);
        uint256 second = _mint(1);
        vm.prank(OWNER);
        _core.burn(first);
        inventory.appendCollectionTokens(1, _pair(first, second));
        (, bytes32 beforeBurn) = inventory.requireCompleteCollection(1);
        vm.prank(OWNER);
        _core.burn(second);
        (uint256 count, bytes32 afterBurn) = inventory.requireCompleteCollection(1);
        require(count == 2 && beforeBurn == afterBurn, "burn must retain membership");
        require(
            _core.totalSupplyOfCollection(1) == 0 && _core.collectionMintedEver(1) == 2,
            "actual Core burn accounting"
        );
    }

    function testIncompletePrefixAndLaterMintInvalidateCompleteness() public {
        uint256 first = _mint(1);
        uint256 second = _mint(1);
        inventory.appendCollectionTokens(1, _one(first));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionTokenInventory.InventoryIncomplete.selector, 1, 1, 2
            )
        );
        inventory.requireCompleteCollection(1);
        inventory.appendCollectionTokens(1, _one(second));
        inventory.requireCompleteCollection(1);
        uint256 third = _mint(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionTokenInventory.InventoryIncomplete.selector, 1, 2, 3
            )
        );
        inventory.requireCompleteCollection(1);
        inventory.appendCollectionTokens(1, _one(third));
        (uint256 count,) = inventory.requireCompleteCollection(1);
        require(count == 3, "append catches up");
    }

    function testPoisoningByWrongCollectionSkipDuplicateAndReverseRollsBack() public {
        uint256 first = _mint(1);
        uint256 other = _mint(2);
        uint256 second = _mint(1);
        _reject(1, _one(other));
        _reject(1, _one(second));
        _reject(1, _pair(second, first));
        _reject(1, _pair(first, first));
        _reject(1, _pair(first, other));
        (uint256 count, bytes32 prefix) = inventory.collectionInventoryState(1);
        require(count == 0 && prefix == _emptyPrefix(1), "atomic failed batches");
        inventory.appendCollectionTokens(1, _pair(first, second));
        _reject(1, _one(first));
        (count,) = inventory.requireCompleteCollection(1);
        require(count == 2, "hostile attempts cannot poison honest prefix");
    }

    function testPreparedMintExcludedAbortAndReuseCannotPoisonInventory() public {
        bytes32 operation = keccak256("inventory preparation");
        (uint256 prepared,) = _manager.prepare(_core, 1, hex"1234", operation);
        require(_core.tokenLifecycle(prepared) == 1, "actual prepared identity");
        _reject(1, _one(prepared));
        (uint256 count,) = inventory.requireCompleteCollection(1);
        require(count == 0, "prepared does not count as completed");
        _replaceManagerAndAbort(prepared, operation);
        _reject(1, _one(prepared));
        uint256 reused = _mint(1);
        require(reused == prepared, "actual abort reuses allocation");
        inventory.appendCollectionTokens(1, _one(reused));
        (count,) = inventory.requireCompleteCollection(1);
        require(count == 1, "completed reused identity indexed once");
    }

    function testPreparedMintBecomesEligibleOnlyAfterCompletion() public {
        bytes32 operation = keccak256("inventory completion");
        (uint256 prepared,) = _manager.prepare(_core, 1, hex"abcd", operation);
        _reject(1, _one(prepared));
        _manager.complete(_core, prepared, OWNER, operation, keccak256("commit"));
        inventory.appendCollectionTokens(1, _one(prepared));
        (uint256 count,) = inventory.requireCompleteCollection(1);
        require(count == 1, "completed actual prepared mint");
    }

    function testAbortedGlobalIdCanBeReusedByDifferentCollection() public {
        bytes32 operation = keccak256("cross collection abort");
        (uint256 prepared,) = _manager.prepare(_core, 1, hex"1234", operation);
        _reject(1, _one(prepared));
        _replaceManagerAndAbort(prepared, operation);
        uint256 reused = _mint(2);
        require(reused == prepared, "global allocation reused by collection two");
        _reject(1, _one(reused));
        inventory.appendCollectionTokens(2, _one(reused));
        (uint256 count,) = inventory.requireCompleteCollection(1);
        require(count == 0, "original collection remains empty");
        (count,) = inventory.requireCompleteCollection(2);
        require(count == 1, "actual new membership");
    }

    function testEntropyAndReceiverCallbacksUseActualCompletionAndAtomicRollback() public {
        InventoryMintCallbackBoundary callback = new InventoryMintCallbackBoundary(inventory);
        _installPointer(
            _POINTER_ENTROPY_COORDINATOR,
            address(callback),
            _POINTER_ENTROPY_COORDINATOR,
            type(IStreamEntropyCoordinator).interfaceId
        );
        callback.setRejectReceiver(true);
        (bool ok,) = address(_manager)
            .call(
                abi.encodeCall(
                    _manager.mint,
                    (_core, 1, address(callback), hex"1234", keccak256("callback mint"))
                )
            );
        require(!ok, "receiver rejected mint");
        (uint256 count, bytes32 prefix) = inventory.requireCompleteCollection(1);
        require(count == 0 && prefix == _emptyPrefix(1), "callback append rolled back with Core");
        require(
            _core.collectionMintedEver(1) == 0 && !callback.entropyRejectedIncomplete(),
            "whole mint and entropy callback rolled back"
        );
        callback.setRejectReceiver(false);
        (uint256 token,) =
            _manager.mint(_core, 1, address(callback), hex"1234", keccak256("callback mint"));
        require(
            callback.entropyRejectedIncomplete(),
            "actual entropy callback rejected prepared identity"
        );
        (count,) = inventory.requireCompleteCollection(1);
        require(
            count == 1 && inventory.collectionTokenAt(1, 0) == token,
            "receiver appended only after actual mint completion"
        );
    }

    function testCoreCodeChangeRejectsCurrentChecksButPreservesHistory() public {
        uint256 token = _mint(1);
        inventory.appendCollectionTokens(1, _one(token));
        (, bytes32 beforeChange) = inventory.collectionInventoryState(1);
        vm.etch(address(_core), hex"00");
        (uint256 count, bytes32 afterChange) = inventory.collectionInventoryState(1);
        require(
            count == 1 && beforeChange == afterChange && inventory.collectionTokenAt(1, 0) == token,
            "historical identity retained"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionTokenInventory.InventoryCoreChanged.selector)
        );
        inventory.requireCompleteCollection(1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionTokenInventory.InventoryCoreChanged.selector)
        );
        inventory.appendCollectionTokens(1, _one(token));
    }

    function testChainChangeRejectsCurrentChecksAndPreservesEmptyHash() public {
        (, bytes32 beforeChange) = inventory.collectionInventoryState(1);
        vm.chainId(block.chainid + 1);
        (, bytes32 afterChange) = inventory.collectionInventoryState(1);
        require(beforeChange == afterChange, "empty hash uses original chain");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionTokenInventory.InventoryCoreChanged.selector)
        );
        inventory.requireCompleteCollection(1);
    }

    function testBatchBoundsAndWrongGasConfiguration() public {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionTokenInventory.InventoryBatchSize.selector, 0)
        );
        inventory.appendCollectionTokens(1, new uint256[](0));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionTokenInventory.InventoryBatchSize.selector, 257)
        );
        inventory.appendCollectionTokens(1, new uint256[](257));
        IStreamGasParameterHost.GasParameterConfig memory config = _config();
        config.failureClass = 2;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionTokenInventory.InvalidInventoryConfiguration.selector
            )
        );
        new StreamCollectionTokenInventory(address(_core), address(_executor), config);
    }

    function testFuzzInterleavedMembershipAndBatchPartitionAreExact(uint8 rawCount, uint8 rawSplit)
        public
    {
        uint256 count = uint256(rawCount) % 16 + 1;
        uint256 split = uint256(rawSplit) % count + 1;
        uint256[] memory first = new uint256[](split);
        uint256[] memory second = new uint256[](count - split);
        bytes32 prefix = _emptyPrefix(1);
        for (uint256 i; i < count; ++i) {
            if (i % 2 == 0) _mint(2);
            uint256 token = _mint(1);
            if (i < split) first[i] = token;
            else second[i - split] = token;
            prefix = keccak256(abi.encode(inventory.APPEND_DOMAIN(), prefix, i + 1, token));
        }
        inventory.appendCollectionTokens(1, first);
        if (second.length != 0) inventory.appendCollectionTokens(1, second);
        (uint256 indexedCount, bytes32 actual) = inventory.requireCompleteCollection(1);
        require(indexedCount == count && actual == prefix, "partition independent exact prefix");
    }

    function testThresholdSafeAppendAndEveryPublicRead() public {
        uint256 token = _mint(1);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        uint256[] memory owners = new uint256[](3);
        owners[0] = 101;
        owners[1] = 202;
        owners[2] = 303;
        OfficialSafe account = createOfficialSafe(components, safeOwnerAddresses(owners), 2, 6529);
        uint256[] memory signers = new uint256[](2);
        signers[0] = owners[0];
        signers[1] = owners[2];
        require(
            executeSafe(
                account,
                signers,
                address(inventory),
                0,
                abi.encodeCall(inventory.appendCollectionTokens, (1, _one(token))),
                0
            ),
            "Safe permissionless append"
        );
        bytes[] memory reads = new bytes[](20);
        reads[0] = abi.encodeCall(inventory.core, ());
        reads[1] = abi.encodeCall(inventory.coreCodeHash, ());
        reads[2] = abi.encodeCall(inventory.deploymentChainId, ());
        reads[3] = abi.encodeCall(inventory.MAX_INDEX_BATCH, ());
        reads[4] = abi.encodeCall(inventory.CORE_READ_GAS, ());
        reads[5] = abi.encodeCall(inventory.INVENTORY_DOMAIN, ());
        reads[6] = abi.encodeCall(inventory.APPEND_DOMAIN, ());
        reads[7] = abi.encodeCall(
            inventory.supportsInterface, (type(IStreamCollectionTokenInventory).interfaceId)
        );
        reads[8] = abi.encodeCall(inventory.collectionInventoryState, (1));
        reads[9] = abi.encodeCall(inventory.collectionTokenAt, (1, 0));
        reads[10] = abi.encodeCall(inventory.requireCompleteCollection, (1));
        reads[11] = abi.encodeCall(inventory.gasParameterInfo, (inventory.CORE_READ_GAS()));
        reads[12] = abi.encodeCall(inventory.gasParameter, (inventory.CORE_READ_GAS()));
        reads[13] = abi.encodeCall(inventory.gasParameterIds, ());
        reads[14] = abi.encodeCall(inventory.governanceAuthority, ());
        reads[15] = abi.encodeCall(inventory.GAS_PARAMETER_SCHEMA_VERSION, ());
        reads[16] = abi.encodeCall(inventory.FAILURE_CLASS_NONE, ());
        reads[17] = abi.encodeCall(inventory.FAILURE_CLASS_FORWARDING_CAP, ());
        reads[18] = abi.encodeCall(inventory.FAILURE_CLASS_FAIL_CLOSED_PRECHECK, ());
        reads[19] = abi.encodeCall(inventory.FAILURE_CLASS_MIN_GAS_GATE, ());
        for (uint256 i; i < reads.length; ++i) {
            require(
                executeSafe(account, signers, address(inventory), 0, reads[i], 0),
                "Safe public read"
            );
        }
        bytes32 gasId = inventory.CORE_READ_GAS();
        vm.prank(address(account));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(account)
            )
        );
        inventory.raiseGasParameter(gasId, 200_000);
    }

    function _config() private pure returns (IStreamGasParameterHost.GasParameterConfig memory) {
        return IStreamGasParameterHost.GasParameterConfig(
            "TOKEN_INVENTORY_CORE_READ_GAS", 100_000, 50_000, 1
        );
    }

    function _mint(uint256 collectionId) private returns (uint256 tokenId) {
        (tokenId,) =
            _manager.mint(_core, collectionId, OWNER, hex"1234", keccak256("inventory mint"));
    }

    function _replaceManagerAndAbort(uint256 tokenId, bytes32 operation) private {
        _manager = new PermanentTargetMintManager();
        _installPointer(
            _POINTER_MINT_MANAGER,
            address(_manager),
            _POINTER_MINT_MANAGER,
            type(IStreamMintManager).interfaceId
        );
        _manager.abort(_core, tokenId, operation);
    }

    function _one(uint256 token) private pure returns (uint256[] memory ids) {
        ids = new uint256[](1);
        ids[0] = token;
    }

    function _pair(uint256 first, uint256 second) private pure returns (uint256[] memory ids) {
        ids = new uint256[](2);
        ids[0] = first;
        ids[1] = second;
    }

    function _emptyPrefix(uint256 collectionId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                inventory.INVENTORY_DOMAIN(),
                inventory.deploymentChainId(),
                address(inventory),
                address(_core),
                collectionId
            )
        );
    }

    function _reject(uint256 collectionId, uint256[] memory ids) private {
        (bool ok,) = address(inventory)
            .call(abi.encodeCall(inventory.appendCollectionTokens, (collectionId, ids)));
        require(!ok, "invalid token batch accepted");
    }

    bytes32 private constant _POINTER_MINT_MANAGER =
        0x136326f089f522351128a5fb79275bd12b2d84fe5bb50d5e46c9f5508d6df7e2;
    bytes32 private constant _POINTER_METADATA_ROUTER =
        0x7024d3e2544fc48a261933c43d901dca0ee3fc26ea2b857748ab0c295a16f20a;
    bytes32 private constant _POINTER_ENTROPY_COORDINATOR =
        0xb3b3ef20764c647bdeda70b21ab009ff2783106d6995be14389ec6f42ea6dfbb;
    bytes32 private constant _POINTER_ARTIST_REGISTRY =
        0xaef5244b535c06d7f8e259ec85024ebdfc2d95b38d64f6570dc627a2684749f4;
    bytes32 private constant _POINTER_MODULE_REGISTRY =
        0xde86dd5f33a5b2bd22cfbe7752609f5086a946f705768f7e2e6cb501157a41c4;
    bytes32 private constant _POINTER_ROYALTY_RESOLVER =
        0xafcd60ac064e6f5b3428ca05e721b02c16a658af3989d079e29e38df5fab9c91;

    bytes32 private constant _GGP_ROYALTY_RESOLVER_GAS_LIMIT =
        0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda;
    bytes32 private constant _GGP_ROYALTY_RETURN_GAS_BUFFER =
        0x0af6f5a1a5059e398191fa0af185be12fee6d609933826603244c7f247793be7;
    bytes32 private constant _GGP_METADATA_ROUTER_GAS_LIMIT =
        0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93;
    bytes32 private constant _GGP_ENTROPY_REGISTRATION_GAS_LIMIT =
        0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17;

    bytes32 private constant _COLLECTION_SCOPE_DOMAIN =
        0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16;
    bytes32 private constant _COLLECTION_STATE_DOMAIN =
        0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;

    bytes32 private constant _REGISTRY_MANIFEST = keccak256("target.registry.manifest");
    bytes32 private constant _DEPLOYMENT_MANIFEST = keccak256("target.deployment.manifest");
    bytes32 private constant _MODULE_MANIFEST = keccak256("target.module.manifest");
    bytes32 private constant _TOKEN_ROUTE_HASH = keccak256("ipfs://permanent-target/token");
    bytes32 private constant _CONTRACT_ROUTE_HASH = keccak256("ipfs://permanent-target/contract");

    InventoryGovernanceBoundary private _executor;
    PermanentTargetModuleRegistry private _registry;
    PermanentTargetCoreHarness private _core;
    PermanentTargetMintManager private _manager;
    PermanentTargetEntropyCoordinator private _entropy;
    PermanentTargetMetadataRouter private _router;

    function setUp() public {
        _executor = new InventoryGovernanceBoundary();
        _registry = new PermanentTargetModuleRegistry();

        StreamCore.GenesisModuleRegistryConfig memory registryConfig =
            StreamCore.GenesisModuleRegistryConfig({
                registry: address(_registry),
                runtimeCodeHash: address(_registry).codehash,
                moduleManifestHash: _REGISTRY_MANIFEST,
                deploymentManifestHash: _DEPLOYMENT_MANIFEST
            });
        StreamCore.GasParameterGenesisConfig[] memory gasConfigs =
            new StreamCore.GasParameterGenesisConfig[](4);
        gasConfigs[0] = StreamCore.GasParameterGenesisConfig({
            parameterId: _GGP_ROYALTY_RESOLVER_GAS_LIMIT,
            genesisValue: 50_000,
            floor: 25_000,
            failureClass: 1
        });
        gasConfigs[1] = StreamCore.GasParameterGenesisConfig({
            parameterId: _GGP_ROYALTY_RETURN_GAS_BUFFER,
            genesisValue: 2_910_000,
            floor: 1_460_000,
            failureClass: 1
        });
        gasConfigs[2] = StreamCore.GasParameterGenesisConfig({
            parameterId: _GGP_METADATA_ROUTER_GAS_LIMIT,
            genesisValue: 500_000,
            floor: 250_000,
            failureClass: 1
        });
        gasConfigs[3] = StreamCore.GasParameterGenesisConfig({
            parameterId: _GGP_ENTROPY_REGISTRATION_GAS_LIMIT,
            genesisValue: 120_000,
            floor: 120_000,
            failureClass: 2
        });
        _core = new PermanentTargetCoreHarness(
            "6529 Stream", "STREAM", address(_executor), registryConfig, gasConfigs
        );
        _registry.setRecord(
            address(_registry),
            _POINTER_MODULE_REGISTRY,
            type(IStreamModuleRegistry).interfaceId,
            _REGISTRY_MANIFEST,
            _DEPLOYMENT_MANIFEST
        );

        _manager = new PermanentTargetMintManager();
        _entropy = new PermanentTargetEntropyCoordinator();
        _router = new PermanentTargetMetadataRouter();
        _installPointer(
            _POINTER_MINT_MANAGER,
            address(_manager),
            _POINTER_MINT_MANAGER,
            type(IStreamMintManager).interfaceId
        );
        _installPointer(
            _POINTER_ENTROPY_COORDINATOR,
            address(_entropy),
            _POINTER_ENTROPY_COORDINATOR,
            type(IStreamEntropyCoordinator).interfaceId
        );
        _createCollection(2, false, 0, 0);
        _createCollection(2, false, 0, 0);
        inventory =
            new StreamCollectionTokenInventory(address(_core), address(_executor), _config());
    }

    function _installPointer(
        bytes32 pointerType,
        address target,
        bytes32 moduleType,
        bytes4 interfaceId
    ) private {
        _registry.setRecord(target, moduleType, interfaceId, _MODULE_MANIFEST, _DEPLOYMENT_MANIFEST);
        _updatePointerWithCandidate(pointerType, target);
    }

    function _updatePointerWithCandidate(bytes32 pointerType, address target) private {
        StreamCorePointerState memory previous = _core.pointerState(pointerType);
        StreamModuleRecord memory record = _registry.moduleRecord(target);
        StreamCorePointerState memory candidate = StreamCorePointerState({
            target: target,
            codeHash: target.codehash,
            frozen: false,
            moduleType: record.moduleType,
            interfaceId: record.interfaceId,
            registry: address(_registry),
            registryStatus: uint8(record.status),
            moduleManifestHash: record.moduleManifestHash,
            deploymentManifestHash: record.deploymentManifestHash,
            revision: previous.revision + 1
        });
        (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash) =
            _core.pointerTransitionHashes(pointerType, previous, candidate);
        _executor.setAction(3, scopeHash, oldValueHash, newValueHash);
        _executor.execute(
            address(_core), abi.encodeCall(_core.updateSatellitePointer, (pointerType, target))
        );
    }

    function _createCollection(
        uint8 supplyMode,
        bool hasMaxSupply,
        uint256 maxSupply,
        uint8 initialStatus
    ) private {
        uint256 collectionId = _core.lastAllocatedCollectionId() + 1;
        bytes32 scopeHash = keccak256(
            abi.encode(
                _COLLECTION_SCOPE_DOMAIN, uint256(block.chainid), address(_core), collectionId
            )
        );
        bytes32 oldValueHash = keccak256(
            abi.encode(
                _COLLECTION_STATE_DOMAIN, scopeHash, false, uint8(0), uint8(0), false, uint256(0)
            )
        );
        bytes32 newValueHash = keccak256(
            abi.encode(
                _COLLECTION_STATE_DOMAIN,
                scopeHash,
                true,
                supplyMode,
                initialStatus,
                hasMaxSupply,
                maxSupply
            )
        );
        _executor.setAction(1, scopeHash, oldValueHash, newValueHash);
        _executor.execute(
            address(_core),
            abi.encodeCall(
                _core.createCollection, (supplyMode, hasMaxSupply, maxSupply, initialStatus)
            )
        );
    }
}
