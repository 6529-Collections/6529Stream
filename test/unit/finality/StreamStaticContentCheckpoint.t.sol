// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamTokenContentLeaf
} from "../../../smart-contracts/interfaces/stream/metadata/StreamTokenContentTypes.sol";
import "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    StreamStaticContentCheckpoint
} from "../../../smart-contracts/domains/finality/StreamStaticContentCheckpoint.sol";
import {
    IStreamStaticContentCheckpoint as O
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    StreamStaticSelectionCheckpoint
} from "../../../smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol";
import {
    StreamFinalityScopeMembership
} from "../../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import {
    StreamCollectionTokenInventory
} from "../../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamTokenContentTree
} from "../../../smart-contracts/domains/metadata/StreamTokenContentTree.sol";
import {
    IStreamCorePointers
} from "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamStaticEntropySource
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticEntropySource.sol";

/// @notice Genuine Router/Renderer/Metadata/inventory/membership and threshold Safe; named typed
/// Core/Artist/version-admission/governance boundaries remain inherited. Source recipes, not runtime acceptance.
contract StreamStaticContentCheckpointTest is StaticMetadataRoutingFixture {
    StreamCollectionTokenInventory private inventory;
    StreamStaticSelectionCheckpoint private selections;
    StreamStaticContentCheckpoint private outputs;

    function setUp() public override {
        super.setUp();
        inventory = new StreamCollectionTokenInventory(
            address(core), address(executor), _gas("TOKEN_INVENTORY_CORE_READ_GAS", 100000)
        );
        StreamFinalityScopeMembership membership = new StreamFinalityScopeMembership(
            address(core),
            address(metadata),
            address(inventory),
            address(executor),
            _gas("SCOPE_MEMBERSHIP_READ_GAS", 500000)
        );
        selections = new StreamStaticSelectionCheckpoint(
            address(core),
            address(router),
            address(membership),
            address(executor),
            _gas("STATIC_CHECKPOINT_READ_GAS", 2000000)
        );
        outputs = new StreamStaticContentCheckpoint(
            address(selections),
            address(executor),
            _gas("STATIC_CONTENT_READ_GAS", 8000000),
            _gas("STATIC_CONTENT_RENDER_GAS", 30000000)
        );
        _pointer();
        // Canonical PNG signature admission fixture; no complete image-decoder claim.
        _admin(
            abi.encodeCall(
                router.setCollectionMetadata,
                (1, "Static work", "Exact source", "data:image/png;base64,iVBORw0KGgo=", "")
            )
        );
    }

    function testExactOriginalLeafTreeAndSeparateOutputChainForCompleteOrderedScope() public {
        bytes32 selection = _prepare(3, R.MetadataMode.ONCHAIN);
        bytes32 id = outputs.begin(selection, keccak256("first capture"));
        outputs.append(id, _payloads(1, 1));
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
        outputs.append(id, _payloads(2, 2));
        O.Plan memory done = outputs.requireCurrentCheckpoint(id);
        StreamTokenContentLeaf[] memory leaves = new StreamTokenContentLeaf[](3);
        bytes32 chain;
        for (uint256 i; i < 3; ++i) {
            O.Output memory row = outputs.outputAt(id, i);
            leaves[i] = row.leaf;
            require(
                row.leaf.tokenId == i + 1
                    && row.leaf.metadataHash == keccak256(bytes(router.tokenJSON(i + 1)))
                    && row.leaf.imageHash == keccak256(hex"89504e470d0a1a0a")
                    && row.leaf.animationHash == keccak256(bytes(router.tokenHTML(i + 1)))
                    && row.leaf.contentHash == 0
                    && row.leaf.tokenDataHash == keccak256(core.tokenData(i + 1))
            );
            chain = keccak256(abi.encode(outputs.OUTPUT_CHAIN(), chain, i, row));
        }
        require(
            done.contentRoot == StreamTokenContentTree.root(block.chainid, address(core), leaves)
                && done.outputRoot == chain && done.nextIndex == 3
        );
        require(outputs.begin(selection, keccak256("first capture")) == id);
        vm.expectRevert();
        outputs.outputAt(id, 3);
    }

    function testWrongOrderedTokenAndWrongImageOrAnimationDoNotWritePartialRows() public {
        bytes32 selection = _prepare(2, R.MetadataMode.ONCHAIN);
        bytes32 id = outputs.begin(selection, 0);
        O.Payload[] memory payload = _payloads(1, 2);
        payload[1].tokenId = 1;
        vm.expectRevert();
        outputs.append(id, payload);
        require(outputs.checkpoint(id).nextIndex == 0);
        payload = _payloads(1, 2);
        payload[1].image = hex"01";
        vm.expectRevert();
        outputs.append(id, payload);
        require(outputs.checkpoint(id).nextIndex == 0);
        payload = _payloads(1, 2);
        payload[1].animation = bytes("caller-invented HTML");
        vm.expectRevert();
        outputs.append(id, payload);
        require(outputs.checkpoint(id).nextIndex == 0 && outputs.checkpoint(id).outputRoot == 0);
        outputs.append(id, _payloads(1, 2));
        require(outputs.requireCurrentCheckpoint(id).nextIndex == 2);
    }

    function testLiveArtistOutputChangeInvalidatesCompletedAndPartlyAppendedCapture() public {
        bytes32 selection = _prepare(2, R.MetadataMode.ONCHAIN);
        bytes32 id = outputs.begin(selection, 0);
        outputs.append(id, _payloads(1, 1));
        O.Output memory old = outputs.outputAt(id, 0);
        attribution.setFail(true); // Exact optional-source failure now serializes explicit unavailable.
        O.Payload[] memory changed = _payloads(2, 1);
        vm.expectRevert();
        outputs.append(id, changed);
        require(
            outputs.checkpoint(id).nextIndex == 1
                && outputs.outputAt(id, 0).leaf.metadataHash == old.leaf.metadataHash
        );
        bytes32 next = outputs.begin(selection, keccak256("new actual bytes"));
        outputs.append(next, _payloads(1, 2));
        require(outputs.requireCurrentCheckpoint(next).contentRoot != 0);
        attribution.setFail(false);
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(next);
        outputs.append(id, _payloads(2, 1));
        require(outputs.requireCurrentCheckpoint(id).nextIndex == 2);
    }

    function testBurnIsVisibleAndCannotBeSilentlyNormalizedAsUnchangedCurrentOutput() public {
        bytes32 selection = _prepare(1, R.MetadataMode.ONCHAIN);
        bytes32 id = outputs.begin(selection, 0);
        outputs.append(id, _payloads(1, 1));
        bytes32 old = outputs.outputAt(id, 0).leaf.metadataHash;
        core.setToken(1, address(this), 3);
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
        require(outputs.outputAt(id, 0).leaf.metadataHash == old);
        bytes32 next = outputs.begin(selection, keccak256("burned capture"));
        outputs.append(next, _payloads(1, 1));
        require(
            outputs.requireCurrentCheckpoint(next).contentRoot != 0
                && outputs.outputAt(next, 0).leaf.metadataHash != old
        );
    }

    function testOffchainSelectionCannotBecomeOnchainByteEvidence() public {
        bytes32 selection = _prepare(1, R.MetadataMode.OFFCHAIN);
        bytes32 id = outputs.begin(selection, 0);
        O.Payload[] memory payload = new O.Payload[](1);
        payload[0] = O.Payload(1, hex"89504e470d0a1a0a", bytes("not a full render"));
        vm.expectRevert();
        outputs.append(id, payload);
        require(outputs.checkpoint(id).nextIndex == 0);
    }

    function testOriginalEntropyRuntimeAndSelectionCompletenessRemainRequired() public {
        bytes32 selection = _prepare(1, R.MetadataMode.ONCHAIN);
        bytes32 id = outputs.begin(selection, 0);
        O.Payload[] memory payload = _payloads(1, 1);
        entropy.setFinalized(false);
        vm.expectRevert();
        outputs.append(id, payload);
        entropy.setFinalized(true);
        outputs.append(id, payload);
        bytes memory code = address(entropy).code;
        vm.etch(address(entropy), hex"fe");
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
        vm.etch(address(entropy), code);
        require(outputs.requireCurrentCheckpoint(id).nextIndex == 1);
        core.setToken(2, address(this), 2);
        core.setMinted(2);
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
        require(outputs.checkpoint(id).nextIndex == 1);
    }

    function testActualSafeLateFailureRollsBackAllLeavesAndRetriesIdenticalBytes() public {
        bytes32 selection = _prepare(2, R.MetadataMode.ONCHAIN);
        bytes32 id = outputs.begin(selection, 0);
        O.Payload[] memory payload = _payloads(1, 2);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0x6530;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 998);
        bytes memory input = abi.encodeCall(outputs.append, (id, payload));
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            address(outputs), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signature = safeThresholdSignature(keys, digest);
        StaticRouteVm(address(vm))
            .mockCall(
                address(entropy),
                abi.encodeCall(IStreamStaticEntropySource.staticTokenRenderFacts, (uint256(2))),
                abi.encode(uint8(4), bytes32(0), address(entropy))
            );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(outputs), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
        require(
            account.nonce() == nonce && outputs.checkpoint(id).nextIndex == 0
                && outputs.checkpoint(id).outputRoot == 0
        );
        vm.expectRevert();
        outputs.outputAt(id, 0);
        StaticRouteVm(address(vm)).clearMockedCalls();
        _pointer();
        require(
            account.execTransaction(
                address(outputs), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signature
            )
        );
        require(account.nonce() == nonce + 1 && outputs.requireCurrentCheckpoint(id).nextIndex == 2);
    }

    function testDistinctFrozenTokenOverrideIsIncludedInActualOutput() public {
        _activate();
        core.setToken(1, address(this), 2);
        core.setToken(2, address(this), 2);
        core.setMinted(2);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        inventory.appendCollectionTokens(1, ids);
        S.ConfigInput memory override_ = _input(R.MetadataMode.ONCHAIN, true);
        override_.config.pendingURI = "ipfs://distinct-original-config";
        _approve(2, override_, keccak256("token config"));
        router.setTokenMetadataConfig(2, override_);
        S.ConfigInput memory collection = _input(R.MetadataMode.ONCHAIN, true);
        _approve(0, collection, keccak256("collection config"));
        router.setCollectionMetadataConfig(1, collection);
        bytes32 selection =
            selections.begin(StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0));
        selections.append(selection, 2);
        bytes32 id = outputs.begin(selection, 0);
        outputs.append(id, _payloads(1, 2));
        require(outputs.requireCurrentCheckpoint(id).nextIndex == 2);
        require(
            outputs.outputAt(id, 0).selectionRowHash != outputs.outputAt(id, 1).selectionRowHash
        );
        require(
            router.resolvedMetadataConfig(2).recordHash
                != router.collectionMetadataConfig(1).recordHash
        );
    }

    function testActualChunkedPayloadHashesFullOutputInsteadOfCompactReference() public {
        bytes memory program = new bytes(24576);
        program[0] = 0x2f;
        program[1] = 0x2a;
        for (uint256 i = 2; i < program.length - 2; ++i) {
            program[i] = 0x61;
        }
        program[program.length - 2] = 0x2a;
        program[program.length - 1] = 0x2f;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(program);
        uint32[] memory lengths = new uint32[](1);
        lengths[0] = uint32(program.length);
        bytes32 bundle = metadata.beginScriptBundle(
            B.Plan(hashes[0], M.PayloadSourceType.SSTORE2, hashes, lengths, 0, false)
        );
        metadata.appendScriptBundle(bundle, 0, program);
        metadata.finalizeScriptBundle(bundle);
        M.ScriptManifest memory manifest = M.ScriptManifest(
            hashes[0],
            keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1"),
            M.PayloadSourceType.SSTORE2,
            "",
            "ipfs://mirror",
            Strings.toHexString(uint256(bundle), 32),
            "application/javascript",
            1,
            true
        );
        _admin(abi.encodeCall(router.setCollectionScriptManifest, (1, manifest)));
        bytes32 selection = _prepare(1, R.MetadataMode.ONCHAIN);
        bytes32 id = outputs.begin(selection, 0);
        outputs.append(id, _payloads(1, 1));
        require(_has(router.tokenHTML(1), string(program)));
        require(_has(router.tokenMetadataJSON(address(core), 1), '"render_mode":"compact"'));
        require(outputs.outputAt(id, 0).leaf.metadataHash == keccak256(bytes(router.tokenJSON(1))));
        require(
            outputs.outputAt(id, 0).leaf.metadataHash
                != keccak256(bytes(router.tokenMetadataJSON(address(core), 1)))
        );
        require(outputs.requireCurrentCheckpoint(id).nextIndex == 1);
    }

    function _prepare(uint256 count, R.MetadataMode mode) private returns (bytes32 selection) {
        _activate();
        uint256[] memory ids = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            core.setToken(i + 1, address(this), 2);
            ids[i] = i + 1;
        }
        core.setMinted(count);
        inventory.appendCollectionTokens(1, ids);
        S.ConfigInput memory input = _input(mode, true);
        _approve(0, input, keccak256("actual collection freeze"));
        router.setCollectionMetadataConfig(1, input);
        selection =
            selections.begin(StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0));
        selections.append(selection, count);
    }

    function _payloads(uint256 first, uint256 count) private view returns (O.Payload[] memory p) {
        p = new O.Payload[](count);
        for (uint256 i; i < count; ++i) {
            p[i] = O.Payload(first + i, hex"89504e470d0a1a0a", bytes(router.tokenHTML(first + i)));
        }
    }

    function _gas(string memory name, uint256 value)
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        uint8 failure = keccak256(bytes(name)) == keccak256("STATIC_CONTENT_READ_GAS")
            || keccak256(bytes(name)) == keccak256("STATIC_CONTENT_RENDER_GAS")
            ? 2
            : 1;
        return IStreamGasParameterHost.GasParameterConfig(name, value, 50000, failure);
    }

    function _pointer() private {
        StaticRouteVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("METADATA_ROUTER"))
                ),
                abi.encode(
                    address(router),
                    address(router).codehash,
                    false,
                    keccak256("METADATA_ROUTER"),
                    type(IStreamMetadataRouter).interfaceId,
                    address(modules),
                    uint8(1),
                    keccak256("manifest"),
                    keccak256("deployment"),
                    uint64(1)
                )
            );
    }
}
