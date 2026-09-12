// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionTokenInventory.t.sol";
import "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../../smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../../smart-contracts/vendor/openzeppelin/Base64.sol";
import "../../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @dev Explicit external entropy-service boundary; original-coordinator lookup is actual Core.
contract CheckpointCompositionEntropyBoundary is PermanentTargetEntropyCoordinator {
    mapping(uint256 => bool) public pending;

    function setPending(uint256 token, bool value) external {
        pending[token] = value;
    }

    function tokenSeed(uint256 token) external view returns (bytes32, bool) {
        return (keccak256(abi.encode("checkpoint.seed", token)), !pending[token]);
    }

    function tokenEntropyStatus(uint256 token) external view returns (StreamEntropyStatus) {
        return pending[token] ? StreamEntropyStatus.REQUESTED : StreamEntropyStatus.FINALIZED;
    }
}

/// @dev Explicit artist-read/authorization boundary. This does not prove artist consent issuance.
contract CheckpointCompositionArtistBoundary {
    address public immutable core;
    StreamArtistContentTypes.FreezeRecord private _freeze;

    constructor(address core_) {
        core = core_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistMintConsent).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId
            || id == type(IStreamArtistAttributionState).interfaceId || id == 0x01ffc9a7;
    }

    function collectionArtistState(uint256)
        external
        pure
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        return (2, 4, keccak256("artist"), 1, keccak256("binding"));
    }

    function attribution(uint256)
        external
        pure
        returns (IStreamCollectionArtistRegistry.Attribution memory)
    {
        return IStreamCollectionArtistRegistry.Attribution(
            address(0xA11CE),
            address(0xA11CE),
            keccak256("identity"),
            keccak256("binding"),
            keccak256("acceptance"),
            4,
            0
        );
    }

    function firstReleaseRatification(uint256) external pure returns (bool, bytes32, bytes32) {
        return (false, 0, 0);
    }

    function configureFreeze(address router, bytes32 state, bytes32[] calldata locks)
        external
        returns (bytes32 id)
    {
        id = keccak256(abi.encode(router, state, locks));
        _freeze = StreamArtistContentTypes.FreezeRecord(
            id, keccak256("artist"), 4, router, locks, state, 1
        );
    }

    function contentFreezeAuthorization(bytes32 id)
        external
        view
        returns (StreamArtistContentTypes.FreezeRecord memory)
    {
        require(id == _freeze.recordHash, "unknown fixture freeze");
        return _freeze;
    }

    function isContentFreezeAuthorized(uint256, bytes32 lockClass)
        external
        view
        returns (bool, bytes32)
    {
        for (uint256 i; i < _freeze.lockClasses.length; ++i) {
            if (_freeze.lockClasses[i] == lockClass) return (true, _freeze.recordHash);
        }
        return (false, 0);
    }
}

/// @notice Actual Core, metadata router, inventory and checkpoint composition.
/// @dev Governance, module registry, Manager, artist and entropy remain explicit boundaries.
contract StreamOnchainContentCompositionTest is CharacterizationTestBase, OfficialSafeFixture {
    using Strings for uint256;
    StreamCollectionTokenInventory private inventory;
    StreamOnchainContentCheckpoint private producer;
    address private constant OWNER = address(0xA11CE);

    function testActualOddRootIncludesBurnedAndInterleavedTokens() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = _mint(1, hex"00ff");
        _mint(2, "other collection");
        ids[1] = _mint(1, "");
        ids[2] = _mint(1, hex"010203");
        string memory beforeBurn = _router.tokenMetadataJSON(address(_core), ids[0]);
        vm.prank(OWNER);
        _core.burn(ids[0]);
        require(
            keccak256(bytes(beforeBurn))
                == keccak256(bytes(_router.historicalTokenMetadataJSON(address(_core), ids[0]))),
            "burn changes artwork"
        );
        _lockCollection(true);
        inventory.appendCollectionTokens(1, ids);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payloads =
            _payloads(ids, "draw();", "");
        producer.appendCheckpointTokens(id, payloads);
        IStreamOnchainContentCheckpoint.Plan memory plan = producer.requireCurrentCheckpoint(id);
        bytes32 a = _assertLeaf(id, 0, payloads[0]);
        bytes32 b = _assertLeaf(id, 1, payloads[1]);
        bytes32 c = _assertLeaf(id, 2, payloads[2]);
        require(plan.contentRoot == _node(_node(a, b), c), "actual ordered odd root");
        require(plan.tokenCount == 3 && ids[1] == ids[0] + 2, "interleaved complete membership");
    }

    function testActualLateUnfinalizedEntropyRollsBackAndRetrySucceeds() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = _mint(1, "one");
        ids[1] = _mint(1, "two");
        _lockCollection(true);
        inventory.appendCollectionTokens(1, ids);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payloads =
            _payloads(ids, "draw();", "");
        _entropy.setPending(ids[1], true);
        (bool ok,) =
            address(producer).call(abi.encodeCall(producer.appendCheckpointTokens, (id, payloads)));
        require(
            !ok && producer.checkpoint(id).nextIndex == 0,
            "late entropy failure must roll back prefix"
        );
        _entropy.setPending(ids[1], false);
        producer.appendCheckpointTokens(id, payloads);
        require(producer.requireCurrentCheckpoint(id).nextIndex == 2, "identical retry");
    }

    function testActualMissingDisplayLockRejectsThenOneWayLocksHold() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = _mint(1, "");
        inventory.appendCollectionTokens(1, ids);
        _lockCollection(false);
        (bool ok,) = address(producer).call(abi.encodeCall(producer.beginCollectionCheckpoint, (1)));
        require(!ok, "unlocked display accepted");
        _router.lockDisplayMetadata(1);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        require(id != 0, "all actual locks accepted");
        (ok,) =
            address(_router).call(abi.encodeCall(_router.setCollectionScript, (1, "changed();")));
        require(!ok, "script changed after lock");
        (ok,) = address(_router)
            .call(abi.encodeCall(_router.setCollectionMetadata, (1, "changed", "", "", "")));
        require(!ok, "display changed after lock");
    }

    function testActualLateBadPayloadDoesNotLeaveVerifiedLeaf() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = _mint(1, "a");
        ids[1] = _mint(1, "b");
        _lockCollection(true);
        inventory.appendCollectionTokens(1, ids);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payloads =
            _payloads(ids, "draw();", "");
        bytes memory original = payloads[1].animation;
        payloads[1].animation = bytes.concat(original, bytes(" "));
        (bool ok,) =
            address(producer).call(abi.encodeCall(producer.appendCheckpointTokens, (id, payloads)));
        require(!ok && producer.checkpoint(id).nextIndex == 0, "late payload rollback");
        payloads[1].animation = original;
        producer.appendCheckpointTokens(id, payloads);
        require(
            producer.requireCurrentCheckpoint(id).tokenCount == 2, "exact original payload retry"
        );
    }

    function testActualMaximumScriptAndTokenDataAndInlineImage() public {
        bytes memory script = new bytes(8192);
        for (uint256 i; i < script.length; ++i) {
            script[i] = 0x20;
        }
        bytes memory data = new bytes(16384);
        for (uint256 i; i < data.length; ++i) {
            data[i] = bytes1(uint8(i));
        }
        bytes memory image = hex"89504e470d0a1a0a"; // Signature admission fixture; no image decoder claim.
        _router.setCollectionMetadata(
            1, "Checkpoint", "Actual maximum bytes", "data:image/png;base64,iVBORw0KGgo=", ""
        );
        _router.setCollectionScript(1, string(script));
        uint256[] memory ids = new uint256[](1);
        ids[0] = _mint(1, data);
        _lockCollection(true);
        inventory.appendCollectionTokens(1, ids);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payloads =
            _payloads(ids, string(script), image);
        producer.appendCheckpointTokens(id, payloads);
        _assertLeaf(id, 0, payloads[0]);
        require(producer.requireCurrentCheckpoint(id).tokenCount == 1, "actual maximum payload");
    }

    function testActualLaterMintInvalidatesCurrentButPreservesCompletedHistory() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = _mint(1, "");
        _lockCollection(true);
        inventory.appendCollectionTokens(1, ids);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        producer.appendCheckpointTokens(id, _payloads(ids, "draw();", ""));
        bytes32 oldRoot = producer.requireCurrentCheckpoint(id).contentRoot;
        _mint(1, "later");
        (bool ok,) =
            address(producer).staticcall(abi.encodeCall(producer.requireCurrentCheckpoint, (id)));
        require(
            !ok && producer.checkpoint(id).contentRoot == oldRoot,
            "new mint invalidates current only"
        );
    }

    function testActualThresholdSafeCustodyBurnAndCheckpointCalls() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 65291;
        keys[1] = 65292;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 777);
        (uint256 token,) =
            _manager.mint(_core, 1, address(account), hex"00ff", keccak256("safe mint"));
        uint256[] memory ids = new uint256[](1);
        ids[0] = token;
        _lockCollection(true);
        require(
            executeSafe(
                account,
                keys,
                address(inventory),
                0,
                abi.encodeCall(inventory.appendCollectionTokens, (1, ids)),
                0
            ),
            "Safe inventory"
        );
        require(
            executeSafe(
                account,
                keys,
                address(producer),
                0,
                abi.encodeCall(producer.beginCollectionCheckpoint, (1)),
                0
            ),
            "Safe begin"
        );
        bytes32 id = producer.beginCollectionCheckpoint(1);
        require(
            executeSafe(account, keys, address(_core), 0, abi.encodeCall(_core.burn, (token)), 0),
            "Safe actual burn"
        );
        require(
            executeSafe(
                account,
                keys,
                address(producer),
                0,
                abi.encodeCall(
                    producer.appendCheckpointTokens, (id, _payloads(ids, "draw();", ""))
                ),
                0
            ),
            "Safe append"
        );
        require(
            executeSafe(
                account,
                keys,
                address(producer),
                0,
                abi.encodeCall(producer.requireCurrentCheckpoint, (id)),
                0
            ),
            "Safe current read"
        );
        require(
            producer.requireCurrentCheckpoint(id).tokenCount == 1,
            "Safe completed actual checkpoint"
        );
    }

    function _mint(uint256 collectionId, bytes memory data) private returns (uint256 token) {
        (token,) = _manager.mint(
            _core, collectionId, OWNER, data, keccak256(abi.encode(collectionId, data))
        );
    }

    function _config() private pure returns (IStreamGasParameterHost.GasParameterConfig memory) {
        return IStreamGasParameterHost.GasParameterConfig(
            "TOKEN_INVENTORY_CORE_READ_GAS", 100_000, 50_000, 1
        );
    }

    function _lockCollection(bool display) private {
        bytes32[] memory locks = new bytes32[](3);
        locks[0] = _router.CONTENT_SCRIPT();
        locks[1] = _router.CONTENT_MEDIA();
        locks[2] = _router.LOCK_BASE_URI();
        for (uint256 i; i < locks.length; ++i) {
            for (uint256 j = i + 1; j < locks.length; ++j) {
                if (locks[j] < locks[i]) (locks[i], locks[j]) = (locks[j], locks[i]);
            }
        }
        bytes32 record =
            _artist.configureFreeze(address(_router), _router.artistContentFreezeState(1), locks);
        _router.applyArtistContentFreeze(1, record);
        _router.lockArtistIdentity(1);
        if (display) _router.lockDisplayMetadata(1);
    }

    function _payloads(uint256[] memory ids, string memory script, bytes memory image)
        private
        view
        returns (IStreamOnchainContentCheckpoint.TokenPayload[] memory p)
    {
        p = new IStreamOnchainContentCheckpoint.TokenPayload[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            uint256 token = ids[i];
            (bytes32 seed,) = _entropy.tokenSeed(token);
            bytes memory html = abi.encodePacked(
                "<html><head></head><body><script>const tokenId=",
                token.toString(),
                ";const tokenHash='",
                uint256(seed).toHexString(32),
                "';const tokenDataBase64='",
                Base64.encode(_core.tokenData(token)),
                "';",
                script,
                "</script></body></html>"
            );
            p[i] = IStreamOnchainContentCheckpoint.TokenPayload(token, image, html);
        }
    }

    function _assertLeaf(
        bytes32 id,
        uint256 index,
        IStreamOnchainContentCheckpoint.TokenPayload memory payload
    ) private view returns (bytes32) {
        StreamTokenContentLeaf memory leaf = producer.checkpointLeaf(id, index);
        bytes32 metadataHash =
            keccak256(bytes(_router.historicalTokenMetadataJSON(address(_core), payload.tokenId)));
        bytes32 imageHash = payload.image.length == 0 ? bytes32(0) : keccak256(payload.image);
        require(
            leaf.tokenId == payload.tokenId && leaf.metadataHash == metadataHash
                && leaf.imageHash == imageHash && leaf.animationHash == keccak256(payload.animation)
                && leaf.contentHash == 0
                && leaf.tokenDataHash == keccak256(_core.tokenData(payload.tokenId)),
            "actual six leaf fields"
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_TOKEN_CONTENT_LEAF_V1"),
                block.chainid,
                address(_core),
                leaf.tokenId,
                leaf.metadataHash,
                leaf.imageHash,
                leaf.animationHash,
                leaf.contentHash,
                leaf.tokenDataHash
            )
        );
    }

    function _node(bytes32 left, bytes32 right) private pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_TOKEN_CONTENT_NODE_V1"), left, right));
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
    CheckpointCompositionEntropyBoundary private _entropy;
    StreamMetadataRouter private _router;
    CheckpointCompositionArtistBoundary private _artist;

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
            genesisValue: 12_000_000,
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
        _entropy = new CheckpointCompositionEntropyBoundary();
        _artist = new CheckpointCompositionArtistBoundary(address(_core));
        _router = new StreamMetadataRouter(
            address(_core),
            address(this),
            _DEPLOYMENT_MANIFEST,
            "ipfs://checkpoint-router",
            _MODULE_MANIFEST,
            IStreamArtistAttribution(address(_artist))
        );
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
        _installPointer(
            _POINTER_ARTIST_REGISTRY,
            address(_artist),
            _POINTER_ARTIST_REGISTRY,
            type(IStreamArtistMintConsent).interfaceId
        );
        _installPointer(
            _POINTER_METADATA_ROUTER,
            address(_router),
            _POINTER_METADATA_ROUTER,
            type(IStreamMetadataRouter).interfaceId
        );
        _createCollection(2, false, 0, 0);
        _createCollection(2, false, 0, 0);
        _router.setCollectionMetadata(1, "Checkpoint", "Actual Core and router", "", "");
        _router.setCollectionScript(1, "draw();");
        inventory =
            new StreamCollectionTokenInventory(address(_core), address(_executor), _config());
        producer = new StreamOnchainContentCheckpoint(
            address(_core),
            address(_router),
            address(inventory),
            address(_executor),
            IStreamGasParameterHost.GasParameterConfig(
                "CONTENT_CHECKPOINT_READ_GAS", 2_000_000, 50_000, 1
            ),
            IStreamGasParameterHost.GasParameterConfig(
                "CONTENT_CHECKPOINT_RENDER_GAS", 14_000_000, 250_000, 1
            )
        );
        require(address(_router).code.length <= 24_576, "actual Router runtime exceeds EIP170");
        require(address(producer).code.length <= 24_576, "checkpoint runtime exceeds EIP170");
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
