// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol";
import "../../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import "../../../smart-contracts/vendor/openzeppelin/Strings.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

contract CheckpointEntropyBoundary {
    uint8 public status = 5;

    function setStatus(uint8 s) external {
        status = s;
    }

    function tokenEntropyStatus(uint256) external view returns (uint8) {
        return status;
    }
}

/// @dev Explicit read boundaries. Actual Core membership is independently exercised in inventory14.
contract CheckpointCoreBoundary {
    address public selected;
    address public entropy;
    uint256 public minted = 1;
    uint256 public dataLength = 32;
    bool public burned;
    bool public frozen;

    function configure(address router, address e) external {
        selected = router;
        entropy = e;
    }

    function setCount(uint256 count) external {
        minted = count;
    }

    function setBurned(bool value) external {
        burned = value;
    }

    function setFrozen(bool value) external {
        frozen = value;
    }

    function setDataLength(uint256 value) external {
        dataLength = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1;
    }

    function collectionMintedEver(uint256) external view returns (uint256) {
        return minted;
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        bool exists = id > 0 && id <= minted * 2 && id % 2 == 0;
        return (exists, exists ? 1 : 0, exists ? id / 2 : 0, burned);
    }

    function tokenLifecycle(uint256) external view returns (uint8) {
        return burned ? 3 : 2;
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return entropy;
    }

    function tokenData(uint256 id) external view returns (bytes memory) {
        if (dataLength == 32) return abi.encode(id);
        return new bytes(dataLength);
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (StreamCorePointerState memory p)
    {
        p = StreamCorePointerState(
            selected,
            selected.codehash,
            false,
            kind,
            type(IStreamMetadataRouter).interfaceId,
            address(this),
            1,
            keccak256("module"),
            keccak256("deployment"),
            1
        );
    }
}

contract CheckpointRendererBoundary {
    function version() external pure returns (uint256) {
        return 1;
    }
}

contract CheckpointRouterBoundary {
    using Strings for uint256;
    address public immutable core;
    address public immutable renderer;
    string public imageURI;
    string public script = "draw();";
    bool public locked = true;
    bool public wrongProfile;
    bool public trailingJSON;
    bool public wrongImage;

    constructor(address c) {
        core = c;
        renderer = address(new CheckpointRendererBoundary());
    }

    function setImage(string calldata uri) external {
        imageURI = uri;
    }

    function setScript(string calldata s) external {
        script = s;
    }

    function setLocked(bool value) external {
        locked = value;
    }

    function setWrongProfile(bool value) external {
        wrongProfile = value;
    }

    function setTrailingJSON(bool value) external {
        trailingJSON = value;
    }

    function setWrongImage(bool value) external {
        wrongImage = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamMetadataServingFacts).interfaceId;
    }

    function collectionServingFacts(uint256)
        external
        view
        returns (IStreamMetadataServingFacts.ServingFacts memory f)
    {
        f.presentationProfile =
            wrongProfile ? bytes32(0) : keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        f.configured = true;
        f.mode = keccak256("ONCHAIN");
        f.renderer = renderer;
        f.rendererCodeHash = renderer.codehash;
        f.scriptHash = keccak256(bytes(script));
        f.scriptBytes = uint32(bytes(script).length);
        f.imageURIHash = keccak256(bytes(imageURI));
        f.animationBaseURIHash = keccak256("");
        f.scriptLocked = locked;
        f.mediaLocked = locked;
        f.baseURILocked = locked;
        f.dependenciesLocked = locked;
        f.artistIdentityLocked = locked;
        f.displayMetadataLocked = locked;
        f.coreFrozen = CheckpointCoreBoundary(core).frozen();
    }

    function collectionServingSource(uint256)
        external
        view
        returns (IStreamMetadataServingFacts.ServingSource memory)
    {
        return
            IStreamMetadataServingFacts.ServingSource("Artwork", "Preserved", imageURI, "", script);
    }

    function animation(uint256 id) public view returns (bytes memory) {
        return abi.encodePacked(
            "<html><script>const tokenId=", id.toString(), ";", script, "</script></html>"
        );
    }

    function historicalTokenMetadataJSON(address supplied, uint256 id)
        external
        view
        returns (string memory)
    {
        require(supplied == core, "wrong Core");
        return string(
            abi.encodePacked(
                '{"name":"Artwork","image":"',
                wrongImage ? "" : imageURI,
                '","token_id":',
                id.toString(),
                ',"animation_url":"data:text/html;base64,',
                Base64.encode(animation(id)),
                '"}',
                trailingJSON ? " " : ""
            )
        );
    }
}

contract StreamOnchainContentCheckpointTest is CharacterizationTestBase, OfficialSafeFixture {
    CheckpointCoreBoundary private core;
    CheckpointEntropyBoundary private entropy;
    CheckpointRouterBoundary private router;
    StreamCollectionTokenInventory private inventory;
    StreamOnchainContentCheckpoint private producer;
    bytes private imageBytes;

    function setUp() public {
        core = new CheckpointCoreBoundary();
        entropy = new CheckpointEntropyBoundary();
        router = new CheckpointRouterBoundary(address(core));
        core.configure(address(router), address(entropy));
        inventory = new StreamCollectionTokenInventory(
            address(core),
            address(0),
            IStreamGasParameterHost.GasParameterConfig(
                "TOKEN_INVENTORY_CORE_READ_GAS", 100_000, 50_000, 1
            )
        );
        producer = new StreamOnchainContentCheckpoint(
            address(core),
            address(router),
            address(inventory),
            address(0),
            IStreamGasParameterHost.GasParameterConfig(
                "CONTENT_CHECKPOINT_READ_GAS", 250_000, 50_000, 1
            ),
            IStreamGasParameterHost.GasParameterConfig(
                "CONTENT_CHECKPOINT_RENDER_GAS", 2_000_000, 250_000, 1
            )
        );
        _index(1);
    }

    function testSingleLeafExactAllFieldsRootAndEventPreimages() public {
        (uint256 count, bytes32 inventoryHash) = inventory.collectionInventoryState(1);
        IStreamMetadataServingFacts.ServingFacts memory facts = router.collectionServingFacts(1);
        facts.coreFrozen = false;
        bytes32 servingHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_INLINE_ONCHAIN_V1"),
                facts,
                router.collectionServingSource(1)
            )
        );
        bytes32 expectedPlan = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CHECKPOINT_V1"),
                block.chainid,
                address(producer),
                keccak256("6529STREAM_CONTENT_INLINE_ONCHAIN_V1"),
                address(core),
                address(router),
                address(inventory),
                uint256(1),
                count,
                inventoryHash,
                servingHash
            )
        );
        vm.recordLogs();
        bytes32 id = producer.beginCollectionCheckpoint(1);
        Vm.Log[] memory started = vm.getRecordedLogs();
        IStreamOnchainContentCheckpoint.Plan memory initial =
            IStreamOnchainContentCheckpoint.Plan(1, 1, 0, inventoryHash, servingHash, 0, 0);
        require(
            id == expectedPlan && started.length == 1 && started[0].emitter == address(producer),
            "exact plan identity"
        );
        require(
            started[0].topics.length == 2 && started[0].topics[1] == id
                && started[0].topics[0]
                    == keccak256(
                        "ContentCheckpointStarted(bytes32,(uint256,uint64,uint64,bytes32,bytes32,bytes32,bytes32))"
                    ),
            "started topics"
        );
        require(keccak256(started[0].data) == keccak256(abi.encode(initial)), "exact started tuple");
        vm.recordLogs();
        producer.appendCheckpointTokens(id, _payloads(0, 1));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2, "leaf and completion events");
        StreamTokenContentLeaf memory expected = _expected(2);
        StreamTokenContentLeaf memory actual = producer.checkpointLeaf(id, 0);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(expected)), "all six leaf fields"
        );
        bytes32 leafHash = StreamTokenContentTree.leafHash(block.chainid, address(core), expected);
        IStreamOnchainContentCheckpoint.Plan memory p = producer.requireCurrentCheckpoint(id);
        require(p.contentRoot == leafHash && p.tokenCount == 1 && p.nextIndex == 1, "one leaf root");
        require(
            p.leafChainHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_CHECKPOINT_LEAVES_V1"),
                        bytes32(0),
                        uint256(0),
                        leafHash
                    )
                ),
            "exact chain"
        );
        require(
            logs[0].emitter == address(producer)
                && logs[0].topics[0]
                    == keccak256(
                        "ContentCheckpointLeafVerified(bytes32,uint64,(uint256,bytes32,bytes32,bytes32,bytes32,bytes32),bytes32)"
                    ),
            "leaf event"
        );
        require(logs[0].topics[1] == id && logs[0].topics[2] == 0, "indexed plan/index");
        require(
            keccak256(logs[0].data) == keccak256(abi.encode(expected, leafHash)), "leaf event data"
        );
        require(
            keccak256(logs[1].data) == keccak256(abi.encode(leafHash, uint64(1))),
            "completion event data"
        );
    }

    function testOddPromotionCountsAcrossEveryAllowedBatchSize() public {
        uint256[6] memory counts = [uint256(3), 5, 6, 7, 8, 37];
        for (uint256 i; i < counts.length; ++i) {
            for (uint256 split = 1; split <= 8 && split <= counts[i]; ++split) {
                uint256 snap = vm.snapshotState();
                _computeAndCompare(counts[i], split);
                require(vm.revertToState(snap), "restore test input");
            }
        }
    }

    function testFuzzOrderedTreeMatchesFullReductionAcrossBatches(uint8 rawCount, uint8 rawBatch)
        public
    {
        _computeAndCompare(uint256(rawCount) % 65 + 1, uint256(rawBatch) % 8 + 1);
    }

    function testLateInvalidPayloadRollsBackWholeBatchAndStoredLeaves() public {
        _index(3);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory data = _payloads(0, 3);
        data[2].animation = hex"00";
        _rejectAppend(id, data);
        require(producer.checkpoint(id).nextIndex == 0, "no partial progress");
        vm.expectRevert();
        producer.checkpointLeaf(id, 0);
        producer.appendCheckpointTokens(id, _payloads(0, 3));
        producer.requireCurrentCheckpoint(id);
    }

    function testReorderedDuplicateAndSkippedTokensRejected() public {
        _index(3);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        _rejectAppend(id, _payloads(1, 1));
        IStreamOnchainContentCheckpoint.TokenPayload[] memory data = _payloads(0, 2);
        data[1] = data[0];
        _rejectAppend(id, data);
        data = _payloads(0, 2);
        (data[0], data[1]) = (data[1], data[0]);
        _rejectAppend(id, data);
        require(producer.checkpoint(id).nextIndex == 0, "authentic prefix preserved");
    }

    function testInlineImageExactBytesAndAbsentIndependentContent() public {
        imageBytes = hex"89504e47000102";
        router.setImage(string.concat("data:image/png;base64,", Base64.encode(imageBytes)));
        bytes32 id = producer.beginCollectionCheckpoint(1);
        producer.appendCheckpointTokens(id, _payloads(0, 1));
        StreamTokenContentLeaf memory leaf = producer.checkpointLeaf(id, 0);
        require(
            leaf.imageHash == keccak256(imageBytes) && leaf.contentHash == 0,
            "declared image and absent extra content"
        );
    }

    function testImageURIHashAloneCannotSubstituteForPayloadBytes() public {
        imageBytes = hex"010203";
        router.setImage("ipfs://example");
        bytes32 id = producer.beginCollectionCheckpoint(1);
        _rejectAppend(id, _payloads(0, 1));
        router.setImage(string.concat("data:image/png;base64,", Base64.encode(imageBytes)));
        id = producer.beginCollectionCheckpoint(1);
        imageBytes = hex"010204";
        _rejectAppend(id, _payloads(0, 1));
    }

    function testImageMustMatchActualServedFieldAndStrictSubtype() public {
        imageBytes = hex"010203";
        router.setImage(string.concat("data:image/;base64,", Base64.encode(imageBytes)));
        bytes32 id = producer.beginCollectionCheckpoint(1);
        _rejectAppend(id, _payloads(0, 1));
        router.setImage(
            string.concat("data:image/png;charset=utf-8;base64,", Base64.encode(imageBytes))
        );
        id = producer.beginCollectionCheckpoint(1);
        _rejectAppend(id, _payloads(0, 1));
        router.setImage(string.concat("data:image/png;base64,", Base64.encode(imageBytes)));
        router.setWrongImage(true);
        id = producer.beginCollectionCheckpoint(1);
        _rejectAppend(id, _payloads(0, 1));
    }

    function testAnimationRequiresExactFinalFieldAndNoTrailingDocumentBytes() public {
        router.setTrailingJSON(true);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        _rejectAppend(id, _payloads(0, 1));
        router.setTrailingJSON(false);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory data = _payloads(0, 1);
        data[0].animation = bytes.concat(data[0].animation, hex"00");
        _rejectAppend(id, data);
        producer.appendCheckpointTokens(id, _payloads(0, 1));
    }

    function testLocksAndProfileRequiredBeforePlan() public {
        router.setLocked(false);
        vm.expectRevert();
        producer.beginCollectionCheckpoint(1);
        router.setLocked(true);
        router.setWrongProfile(true);
        vm.expectRevert();
        producer.beginCollectionCheckpoint(1);
    }

    function testNewMintOrChangedServingBytesInvalidatesCurrentPlan() public {
        _index(2);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        producer.appendCheckpointTokens(id, _payloads(0, 1));
        router.setScript("changed();");
        _rejectAppend(id, _payloads(1, 1));
        router.setScript("draw();");
        core.setCount(3);
        _rejectAppend(id, _payloads(1, 1));
        _index(3);
        _rejectAppend(id, _payloads(1, 1));
        require(producer.checkpoint(id).nextIndex == 1, "history retained");
    }

    function testCoreFreezeAndBurnDoNotChangeLockedArtworkCommitment() public {
        bytes32 id = producer.beginCollectionCheckpoint(1);
        core.setFrozen(true);
        core.setBurned(true);
        producer.appendCheckpointTokens(id, _payloads(0, 1));
        require(
            producer.requireCurrentCheckpoint(id).contentRoot != 0,
            "lifecycle-independent artwork bytes"
        );
    }

    function testOriginalCoordinatorMustReportFinalizedEntropy() public {
        bytes32 id = producer.beginCollectionCheckpoint(1);
        entropy.setStatus(4);
        _rejectAppend(id, _payloads(0, 1));
        entropy.setStatus(7);
        _rejectAppend(id, _payloads(0, 1));
        entropy.setStatus(5);
        producer.appendCheckpointTokens(id, _payloads(0, 1));
    }

    function testBoundedTokenDataRejectsOversizeReplyWithoutProgress() public {
        bytes32 id = producer.beginCollectionCheckpoint(1);
        core.setDataLength(16_385);
        _rejectAppend(id, _payloads(0, 1));
        require(producer.checkpoint(id).nextIndex == 0, "oversize dependency cannot advance");
    }

    function testHistoricalReadsSurviveSelectionCodeAndChainChanges() public {
        bytes32 id = producer.beginCollectionCheckpoint(1);
        producer.appendCheckpointTokens(id, _payloads(0, 1));
        bytes32 root = producer.checkpoint(id).contentRoot;
        core.configure(address(0), address(entropy));
        vm.expectRevert();
        producer.requireCurrentCheckpoint(id);
        core.configure(address(router), address(entropy));
        uint256 beforeCodeChange = vm.snapshotState();
        vm.etch(address(router), hex"00");
        vm.expectRevert();
        producer.requireCurrentCheckpoint(id);
        require(vm.revertToState(beforeCodeChange), "restore valid router before chain check");
        vm.chainId(block.chainid + 1);
        vm.expectRevert();
        producer.requireCurrentCheckpoint(id);
        require(
            producer.checkpoint(id).contentRoot == root
                && producer.checkpointLeaf(id, 0).tokenId == 2,
            "retained historical evidence"
        );
    }

    function testEmptyUnknownBoundsAndIdempotentPlans() public {
        bytes32 id = producer.beginCollectionCheckpoint(1);
        require(producer.beginCollectionCheckpoint(1) == id, "shared deterministic plan");
        _rejectAppend(id, _payloads(0, 0));
        _rejectAppend(id, _payloads(0, 9));
        vm.expectRevert();
        producer.requireCurrentCheckpoint(id);
        vm.expectRevert();
        producer.requireCurrentCheckpoint(bytes32(0));
        producer.appendCheckpointTokens(id, _payloads(0, 1));
        _rejectAppend(id, _payloads(0, 1));
    }

    function testThresholdSafeCanCreateAdvanceAndReadCheckpoint() public {
        SafeComponents memory c = deploySafeComponents("1.4.1");
        uint256[] memory keys = new uint256[](2);
        keys[0] = 111;
        keys[1] = 222;
        OfficialSafe account = createOfficialSafe(c, safeOwnerAddresses(keys), 2, 6529);
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
            executeSafe(
                account,
                keys,
                address(producer),
                0,
                abi.encodeCall(producer.appendCheckpointTokens, (id, _payloads(0, 1))),
                0
            ),
            "Safe advance"
        );
        require(
            executeSafe(
                account, keys, address(producer), 0, abi.encodeCall(producer.checkpoint, (id)), 0
            ),
            "Safe history"
        );
        require(
            executeSafe(
                account,
                keys,
                address(producer),
                0,
                abi.encodeCall(producer.checkpointLeaf, (id, 0)),
                0
            ),
            "Safe leaf"
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
            "Safe current"
        );
        bytes[] memory reads = new bytes[](21);
        reads[0] = abi.encodeCall(producer.core, ());
        reads[1] = abi.encodeCall(producer.metadataRouter, ());
        reads[2] = abi.encodeCall(producer.tokenInventory, ());
        reads[3] = abi.encodeCall(producer.coreCodeHash, ());
        reads[4] = abi.encodeCall(producer.routerCodeHash, ());
        reads[5] = abi.encodeCall(producer.inventoryCodeHash, ());
        reads[6] = abi.encodeCall(producer.deploymentChainId, ());
        reads[7] = abi.encodeCall(producer.DEPENDENCY_READ_GAS, ());
        reads[8] = abi.encodeCall(producer.RENDER_READ_GAS, ());
        reads[9] = abi.encodeCall(producer.PROFILE, ());
        reads[10] = abi.encodeCall(producer.MAX_APPEND_BATCH, ());
        reads[11] = abi.encodeCall(
            producer.supportsInterface, (type(IStreamOnchainContentCheckpoint).interfaceId)
        );
        reads[12] = abi.encodeCall(producer.gasParameterInfo, (producer.DEPENDENCY_READ_GAS()));
        reads[13] = abi.encodeCall(producer.gasParameter, (producer.RENDER_READ_GAS()));
        reads[14] = abi.encodeCall(producer.gasParameterIds, ());
        reads[15] = abi.encodeCall(producer.governanceAuthority, ());
        reads[16] = abi.encodeCall(producer.GAS_PARAMETER_SCHEMA_VERSION, ());
        reads[17] = abi.encodeCall(producer.FAILURE_CLASS_NONE, ());
        reads[18] = abi.encodeCall(producer.FAILURE_CLASS_FORWARDING_CAP, ());
        reads[19] = abi.encodeCall(producer.FAILURE_CLASS_FAIL_CLOSED_PRECHECK, ());
        reads[20] = abi.encodeCall(producer.FAILURE_CLASS_MIN_GAS_GATE, ());
        for (uint256 i; i < reads.length; ++i) {
            require(
                executeSafe(account, keys, address(producer), 0, reads[i], 0), "Safe public read"
            );
        }
        bytes32 gasId = producer.DEPENDENCY_READ_GAS();
        vm.prank(address(account));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(account)
            )
        );
        producer.raiseGasParameter(gasId, 500_000);
    }

    function _index(uint256 count) private {
        core.setCount(count);
        (uint256 previous,) = inventory.collectionInventoryState(1);
        if (previous == count) return;
        uint256[] memory ids = new uint256[](count - previous);
        for (uint256 i; i < ids.length; ++i) {
            ids[i] = (previous + i + 1) * 2;
        }
        inventory.appendCollectionTokens(1, ids);
    }

    function _payloads(uint256 offset, uint256 count)
        private
        view
        returns (IStreamOnchainContentCheckpoint.TokenPayload[] memory data)
    {
        data = new IStreamOnchainContentCheckpoint.TokenPayload[](count);
        for (uint256 i; i < count; ++i) {
            uint256 token = (offset + i + 1) * 2;
            data[i] = IStreamOnchainContentCheckpoint.TokenPayload(
                token, imageBytes, router.animation(token)
            );
        }
    }

    function _expected(uint256 token) private view returns (StreamTokenContentLeaf memory) {
        return StreamTokenContentLeaf(
            token,
            keccak256(bytes(router.historicalTokenMetadataJSON(address(core), token))),
            imageBytes.length == 0 ? bytes32(0) : keccak256(imageBytes),
            keccak256(router.animation(token)),
            0,
            keccak256(abi.encode(token))
        );
    }

    function _computeAndCompare(uint256 count, uint256 batch) private {
        _index(count);
        bytes32 id = producer.beginCollectionCheckpoint(1);
        StreamTokenContentLeaf[] memory leaves = new StreamTokenContentLeaf[](count);
        for (uint256 i; i < count; ++i) {
            leaves[i] = _expected((i + 1) * 2);
        }
        for (uint256 i; i < count;) {
            uint256 take = count - i < batch ? count - i : batch;
            producer.appendCheckpointTokens(id, _payloads(i, take));
            i += take;
        }
        require(
            producer.requireCurrentCheckpoint(id).contentRoot
                == StreamTokenContentTree.root(block.chainid, address(core), leaves),
            "canonical tree mismatch"
        );
    }

    function _rejectAppend(bytes32 id, IStreamOnchainContentCheckpoint.TokenPayload[] memory data)
        private
    {
        (bool ok,) =
            address(producer).call(abi.encodeCall(producer.appendCheckpointTokens, (id, data)));
        require(!ok, "invalid batch accepted");
    }
}
