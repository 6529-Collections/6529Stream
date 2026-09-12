// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCoreMint.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import { StreamCorePointerState } from "../../core/StreamCoreExternalReads.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRouterBinding.sol";
import "../../interfaces/stream/finality/IStreamCollectionTokenInventory.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../metadata/StreamTokenContentTree.sol";
import "../parameters/StreamGasParameterHost.sol";
import "./StreamOnchainContentBytes.sol";

/// @notice Incremental, permissionless verification of complete inline ONCHAIN content roots.
/// @dev All artwork fields are locked before a plan starts. The plan is computation evidence;
///      an authoritative record and preserved leaf manifest are separate publication requirements.
contract StreamOnchainContentCheckpoint is
    IStreamOnchainContentCheckpoint,
    StreamGasParameterHost,
    IERC165
{
    address public immutable override core;
    address public immutable override metadataRouter;
    address public immutable override tokenInventory;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable routerCodeHash;
    bytes32 public immutable inventoryCodeHash;
    uint256 public immutable deploymentChainId;

    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_CONTENT_CHECKPOINT_READ_GAS");
    bytes32 public constant RENDER_READ_GAS =
        keccak256("6529STREAM_GGP_CONTENT_CHECKPOINT_RENDER_GAS");
    bytes32 public constant PROFILE = keccak256("6529STREAM_CONTENT_INLINE_ONCHAIN_V1");
    uint256 public constant MAX_APPEND_BATCH = 8;
    bytes32 private constant _ROUTER = keccak256("METADATA_ROUTER");
    bytes32 private constant _PRESENTATION = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
    bytes32 private constant _PLAN = keccak256("6529STREAM_CONTENT_CHECKPOINT_V1");
    bytes32 private constant _CHAIN = keccak256("6529STREAM_CONTENT_CHECKPOINT_LEAVES_V1");

    mapping(bytes32 => Plan) private _plans;
    mapping(bytes32 => mapping(uint256 => StreamTokenContentLeaf)) private _leaves;
    mapping(bytes32 => mapping(uint256 => bytes32)) private _frontier;

    constructor(
        address core_,
        address router_,
        address inventory_,
        address executor,
        GasParameterConfig memory readGas,
        GasParameterConfig memory renderGas
    ) StreamGasParameterHost(executor) {
        if (
            core_.code.length == 0 || router_.code.length == 0 || inventory_.code.length == 0
                || _registerGasParameter(readGas) != DEPENDENCY_READ_GAS
                || _registerGasParameter(renderGas) != RENDER_READ_GAS || readGas.failureClass != 1
                || renderGas.failureClass != 1
        ) {
            revert InvalidCheckpointConfiguration();
        }
        core = core_;
        metadataRouter = router_;
        tokenInventory = inventory_;
        coreCodeHash = core_.codehash;
        routerCodeHash = router_.codehash;
        inventoryCodeHash = inventory_.codehash;
        deploymentChainId = block.chainid;
        if (
            abi.decode(
                        _read(
                            inventory_,
                            abi.encodeCall(IStreamCollectionTokenInventory.core, ()),
                            32,
                            false
                        ),
                        (address)
                    ) != core_
                || abi.decode(
                        _read(
                            router_,
                            abi.encodeCall(IStreamMetadataRouterBinding.core, ()),
                            32,
                            false
                        ),
                        (address)
                    ) != core_
                || abi.decode(
                        _read(
                            router_,
                            abi.encodeCall(
                                IERC165.supportsInterface,
                                (type(IStreamMetadataServingFacts).interfaceId)
                            ),
                            32,
                            false
                        ),
                        (uint256)
                    ) != 1
        ) {
            revert InvalidCheckpointConfiguration();
        }
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamGasParameterHost).interfaceId
            || id == type(IStreamOnchainContentCheckpoint).interfaceId;
    }

    /// @inheritdoc IStreamOnchainContentCheckpoint
    function beginCollectionCheckpoint(uint256 collectionId)
        external
        override
        returns (bytes32 id)
    {
        _requireBindings();
        (uint256 count, bytes32 inventoryHash) = _inventory(collectionId);
        if (count == 0 || count > type(uint64).max) revert CheckpointUnsupportedPresentation();
        (bytes32 servingHash,) = _serving(collectionId);
        id = keccak256(
            abi.encode(
                _PLAN,
                deploymentChainId,
                address(this),
                PROFILE,
                core,
                metadataRouter,
                tokenInventory,
                collectionId,
                count,
                inventoryHash,
                servingHash
            )
        );
        if (_plans[id].tokenCount == 0) {
            _plans[id] = Plan(collectionId, uint64(count), 0, inventoryHash, servingHash, 0, 0);
            emit ContentCheckpointStarted(id, _plans[id]);
        }
    }

    /// @inheritdoc IStreamOnchainContentCheckpoint
    function appendCheckpointTokens(bytes32 id, TokenPayload[] calldata payloads)
        external
        override
    {
        Plan storage plan = _plans[id];
        string memory imageURI = _requireCurrent(id, plan);
        uint256 size = payloads.length;
        if (size == 0 || size > MAX_APPEND_BATCH || size > plan.tokenCount - plan.nextIndex) {
            revert CheckpointBatchSize(size);
        }
        for (uint256 i; i < size; ++i) {
            uint256 index = plan.nextIndex;
            uint256 expected = abi.decode(
                _read(
                    tokenInventory,
                    abi.encodeCall(
                        IStreamCollectionTokenInventory.collectionTokenAt,
                        (plan.collectionId, index)
                    ),
                    32,
                    false
                ),
                (uint256)
            );
            if (payloads[i].tokenId != expected) {
                revert CheckpointTokenMismatch(expected, payloads[i].tokenId);
            }
            StreamTokenContentLeaf memory leaf = _leaf(payloads[i], imageURI);
            bytes32 leafHash = StreamTokenContentTree.leafHash(deploymentChainId, core, leaf);
            _leaves[id][index] = leaf;
            _appendFrontier(id, index, leafHash);
            plan.leafChainHash = keccak256(abi.encode(_CHAIN, plan.leafChainHash, index, leafHash));
            ++plan.nextIndex;
            emit ContentCheckpointLeafVerified(id, uint64(index), leaf, leafHash);
        }
        if (plan.nextIndex == plan.tokenCount) {
            plan.contentRoot = _root(id, plan.tokenCount);
            emit ContentCheckpointCompleted(id, plan.contentRoot, plan.tokenCount);
        }
    }

    function checkpoint(bytes32 id) external view override returns (Plan memory) {
        return _plans[id];
    }

    function checkpointLeaf(bytes32 id, uint256 index)
        external
        view
        override
        returns (StreamTokenContentLeaf memory)
    {
        if (index >= _plans[id].nextIndex) revert CheckpointIndexOutOfBounds(id, index);
        return _leaves[id][index];
    }

    function requireCurrentCheckpoint(bytes32 id) external view override returns (Plan memory) {
        Plan storage plan = _plans[id];
        _requireCurrent(id, plan);
        if (plan.nextIndex != plan.tokenCount || plan.contentRoot == 0) {
            revert CheckpointInputChanged(id);
        }
        return plan;
    }

    function _requireCurrent(bytes32 id, Plan storage plan)
        private
        view
        returns (string memory imageURI)
    {
        if (plan.tokenCount == 0) revert CheckpointUnknown(id);
        _requireBindings();
        (uint256 count, bytes32 inventoryHash) = _inventory(plan.collectionId);
        (bytes32 servingHash, string memory uri) = _serving(plan.collectionId);
        if (
            count != plan.tokenCount || inventoryHash != plan.inventoryHash
                || servingHash != plan.servingStateHash
        ) revert CheckpointInputChanged(id);
        return uri;
    }

    function _requireBindings() private view {
        if (core.codehash != coreCodeHash || block.chainid != deploymentChainId) {
            revert CheckpointDependencyChanged(core);
        }
        if (metadataRouter.codehash != routerCodeHash) {
            revert CheckpointDependencyChanged(metadataRouter);
        }
        if (tokenInventory.codehash != inventoryCodeHash) {
            revert CheckpointDependencyChanged(tokenInventory);
        }
        StreamCorePointerState memory pointer = abi.decode(
            _read(
                core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (_ROUTER)), 320, false
            ),
            (StreamCorePointerState)
        );
        if (
            pointer.target != metadataRouter || pointer.codeHash != routerCodeHash
                || pointer.moduleType != _ROUTER
                || pointer.interfaceId != type(IStreamMetadataRouter).interfaceId
                || pointer.registry == address(0) || pointer.registryStatus != 1
                || pointer.moduleManifestHash == 0 || pointer.deploymentManifestHash == 0
                || pointer.revision == 0
        ) {
            revert CheckpointRouterNotSelected();
        }
    }

    function _inventory(uint256 collectionId) private view returns (uint256, bytes32) {
        return abi.decode(
            _read(
                tokenInventory,
                abi.encodeCall(
                    IStreamCollectionTokenInventory.requireCompleteCollection, (collectionId)
                ),
                64,
                false
            ),
            (uint256, bytes32)
        );
    }

    function _serving(uint256 collectionId) private view returns (bytes32, string memory) {
        IStreamMetadataServingFacts.ServingFacts memory facts = abi.decode(
            _read(
                metadataRouter,
                abi.encodeCall(IStreamMetadataServingFacts.collectionServingFacts, (collectionId)),
                512,
                false
            ),
            (IStreamMetadataServingFacts.ServingFacts)
        );
        if (
            !facts.configured || facts.presentationProfile != _PRESENTATION
                || facts.mode != keccak256("ONCHAIN") || facts.scriptBytes == 0
                || facts.renderer.code.length == 0
                || facts.renderer.codehash != facts.rendererCodeHash
        ) {
            revert CheckpointUnsupportedPresentation();
        }
        if (
            !facts.scriptLocked || !facts.mediaLocked || !facts.baseURILocked
                || !facts.dependenciesLocked || !facts.artistIdentityLocked
                || !facts.displayMetadataLocked
        ) {
            revert CheckpointContentUnlocked();
        }
        IStreamMetadataServingFacts.ServingSource memory source = abi.decode(
            _read(
                metadataRouter,
                abi.encodeCall(IStreamMetadataServingFacts.collectionServingSource, (collectionId)),
                16_384,
                true
            ),
            (IStreamMetadataServingFacts.ServingSource)
        );
        if (
            bytes(source.name).length > 256 || bytes(source.description).length > 2048
                || bytes(source.imageURI).length > 2048
                || bytes(source.animationBaseURI).length > 2048
                || bytes(source.script).length != facts.scriptBytes || facts.scriptBytes > 8192
                || keccak256(bytes(source.script)) != facts.scriptHash
                || keccak256(bytes(source.imageURI)) != facts.imageURIHash
                || keccak256(bytes(source.animationBaseURI)) != facts.animationBaseURIHash
        ) {
            revert CheckpointUnsupportedPresentation();
        }
        // Core freeze is a lifecycle fact; changing it does not change the locked artwork bytes.
        facts.coreFrozen = false;
        return (keccak256(abi.encode(PROFILE, facts, source)), source.imageURI);
    }

    function _leaf(TokenPayload calldata payload, string memory imageURI)
        private
        view
        returns (StreamTokenContentLeaf memory leaf)
    {
        address coordinator = abi.decode(
            _read(
                core,
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (payload.tokenId)),
                32,
                false
            ),
            (address)
        );
        if (
            coordinator.code.length == 0
                || abi.decode(
                        _read(
                            coordinator,
                            abi.encodeCall(
                                IStreamEntropyView.tokenEntropyStatus, (payload.tokenId)
                            ),
                            32,
                            false
                        ),
                        (uint256)
                    ) != uint256(StreamEntropyStatus.FINALIZED)
        ) {
            revert CheckpointPayloadMismatch(payload.tokenId);
        }
        if (
            payload.animation.length == 0 || payload.animation.length > 40_960
                || payload.image.length > 2048
        ) {
            revert CheckpointPayloadMismatch(payload.tokenId);
        }
        bytes memory json = abi.decode(
            _read(
                metadataRouter,
                abi.encodeCall(
                    IStreamMetadataServingFacts.historicalTokenMetadataJSON, (core, payload.tokenId)
                ),
                65_600,
                true
            ),
            (bytes)
        );
        bytes memory tokenData = abi.decode(
            _read(core, abi.encodeCall(IStreamCoreMint.tokenData, (payload.tokenId)), 16_448, true),
            (bytes)
        );
        if (
            json.length > 65_536 || tokenData.length > 16_384
                || !StreamOnchainContentBytes.matchesAnimation(json, payload.animation)
                || !StreamOnchainContentBytes.matchesImage(json, imageURI, payload.image)
        ) {
            revert CheckpointPayloadMismatch(payload.tokenId);
        }
        return StreamTokenContentLeaf(
            payload.tokenId,
            keccak256(json),
            payload.image.length == 0 ? bytes32(0) : keccak256(payload.image),
            keccak256(payload.animation),
            bytes32(0),
            keccak256(tokenData)
        );
    }

    function _appendFrontier(bytes32 id, uint256 index, bytes32 value) private {
        uint256 level;
        while (index & 1 != 0) {
            value = StreamTokenContentTree.nodeHash(_frontier[id][level], value);
            delete _frontier[id][level];
            index >>= 1;
            ++level;
        }
        _frontier[id][level] = value;
    }

    function _root(bytes32 id, uint256 count) private view returns (bytes32 value) {
        uint256 level;
        while (count != 0) {
            if (count & 1 != 0) {
                bytes32 left = _frontier[id][level];
                value = value == 0 ? left : StreamTokenContentTree.nodeHash(left, value);
            }
            count >>= 1;
            ++level;
        }
    }

    function _read(address target, bytes memory input, uint256 bound, bool dynamic)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(bound);
        uint256 cap =
            _gasParameterValue(target == metadataRouter ? RENDER_READ_GAS : DEPENDENCY_READ_GAS);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), bound)
            size := returndatasize()
        }
        if (!ok || size > bound || (dynamic ? size < 64 : size != bound)) {
            revert CheckpointReadFailed(target, bytes4(input));
        }
        assembly ("memory-safe") { mstore(output, size) }
    }
}
