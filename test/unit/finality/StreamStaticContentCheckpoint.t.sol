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
        // This producer explicitly captures current full output; no real Registry proof is claimed here.
        _optInCurrentCitationAdmissionBoundary();
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
            _gas("STATIC_CONTENT_READ_GAS", 4000000),
            _gas("STATIC_CONTENT_RENDER_GAS", 10000000)
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
        O.Payload[] memory payloads = _payloads(1, 1);
        StreamStaticContentCheckpoint insufficient = new StreamStaticContentCheckpoint(
            address(selections),
            address(executor),
            _gas("STATIC_CONTENT_READ_GAS", 8000000),
            _gas("STATIC_CONTENT_RENDER_GAS", 30000000)
        );
        bytes32 refused = insufficient.begin(selection, 0);
        _coolLargeRender(bundle, address(insufficient));
        (bool oversizedBudget,) = _envelope(
            address(insufficient),
            abi.encodeCall(insufficient.append, (refused, payloads)),
            "30m configured admission"
        );
        require(!oversizedBudget && insufficient.checkpoint(refused).nextIndex == 0);
        _coolLargeRender(bundle, address(outputs));
        (bool fits,) = _envelope(
            address(outputs),
            abi.encodeCall(outputs.append, (id, payloads)),
            "24kb append transaction"
        );
        require(fits, "24kb append must fit transaction envelope");
        // Independent high-budget diagnostic on another plan, kept separate from admission proof.
        bytes32 diagnostic = outputs.begin(selection, keccak256("unbounded diagnostic"));
        _coolLargeRender(bundle, address(outputs));
        uint256 beforeAppend = gasleft();
        outputs.append(diagnostic, payloads);
        uint256 appendGas = beforeAppend - gasleft();
        require(outputs.checkpoint(diagnostic).contentRoot == outputs.checkpoint(id).contentRoot);
        require(_has(router.tokenHTML(1), string(program)));
        require(_has(router.tokenMetadataJSON(address(core), 1), '"render_mode":"compact"'));
        require(outputs.outputAt(id, 0).leaf.metadataHash == keccak256(bytes(router.tokenJSON(1))));
        require(
            outputs.outputAt(id, 0).leaf.metadataHash
                != keccak256(bytes(router.tokenMetadataJSON(address(core), 1)))
        );
        _coolLargeRender(bundle, address(outputs));
        (bool currentFits,) = _envelope(
            address(outputs),
            abi.encodeCall(outputs.requireCurrentCheckpoint, (id)),
            "24kb current transaction"
        );
        require(currentFits, "24kb current must fit transaction envelope");
        _coolLargeRender(bundle, address(outputs));
        uint256 beforeCurrent = gasleft();
        require(outputs.requireCurrentCheckpoint(id).nextIndex == 1);
        emit LargeRenderFixtureGas(10000000, appendGas, beforeCurrent - gasleft());
    }

    event LargeRenderFixtureGas(uint256 configuredRenderGas, uint256 appendGas, uint256 currentGas);
    event log_named_uint(string key, uint256 value);
    event CapacityObservation(
        string label, bool success, uint256 intrinsicGas, uint256 executionGas, bytes4 failure
    );

    /// Diagnostic envelope, not a declaration that an unsuccessful workload is supported.
    /// Includes calldata/base intrinsic cost and reserves 5,000 for CALL/measurement overhead.
    function _envelope(address target, bytes memory input, string memory label)
        private
        returns (bool ok, bytes memory result)
    {
        uint256 intrinsic = 21000;
        for (uint256 i; i < input.length; ++i) {
            intrinsic += input[i] == 0 ? 4 : 16;
        }
        uint256 budget = 16777216 - intrinsic - 5000;
        uint256 before_ = gasleft();
        (ok, result) = target.call{ gas: budget }(input);
        uint256 used = before_ - gasleft();
        bytes4 failure;
        if (!ok && result.length >= 4) {
            assembly ("memory-safe") { failure := mload(add(result, 32)) }
        }
        emit CapacityObservation(label, ok, intrinsic, used, failure);
        emit log_named_uint(string.concat(label, " success"), ok ? 1 : 0);
        emit log_named_uint(string.concat(label, " gas+intrinsic"), used + intrinsic);
        if (ok) require(used + intrinsic <= 16777216);
    }

    function testCapacityFourThenTwoRowsAndSixRowCurrentWithinTransactionEnvelope() public {
        bytes32 selection = _prepare(6, R.MetadataMode.ONCHAIN);
        bytes32 id = outputs.begin(selection, 0);
        O.Payload[] memory first = _payloads(1, 4);
        _coolLargeRender(bytes32(0), address(outputs));
        (bool fits,) = _envelope(
            address(outputs),
            abi.encodeCall(outputs.append, (id, first)),
            "four row append transaction"
        );
        require(fits, "four row append must fit");
        O.Payload[] memory second = _payloads(5, 2);
        _coolLargeRender(bytes32(0), address(outputs));
        (bool secondFits,) = _envelope(
            address(outputs),
            abi.encodeCall(outputs.append, (id, second)),
            "two row append after four transaction"
        );
        require(secondFits, "second append includes original four current rows");
        _coolLargeRender(bytes32(0), address(outputs));
        (bool currentFits,) = _envelope(
            address(outputs),
            abi.encodeCall(outputs.requireCurrentCheckpoint, (id)),
            "six row current transaction"
        );
        require(currentFits, "six row current must fit");
        // Admission may not turn actual live attribution into unavailable output.
        for (uint256 i; i < 6; ++i) {
            require(
                outputs.outputAt(id, i).leaf.metadataHash
                    == keccak256(bytes(router.tokenJSON(i + 1))),
                "unrestricted output parity"
            );
        }
        _coolLargeRender(bytes32(0), address(outputs));
        uint256 beforeCurrent = gasleft();
        require(outputs.requireCurrentCheckpoint(id).nextIndex == 6);
        emit log_named_uint("six row high-budget current", beforeCurrent - gasleft());
    }

    function testEightRowsRemainExplicitAdmissionDiagnostic() public {
        bytes32 selection = _prepare(8, R.MetadataMode.ONCHAIN);
        bytes32 id = outputs.begin(selection, 0);
        O.Payload[] memory first = _payloads(1, 4);
        outputs.append(id, first);
        O.Payload[] memory second = _payloads(5, 4);
        _coolLargeRender(bytes32(0), address(outputs));
        (bool fits, bytes memory reason) = _envelope(
            address(outputs),
            abi.encodeCall(outputs.append, (id, second)),
            "eight row second batch diagnostic"
        );
        require(
            !fits && bytes4(reason) == O.StaticContentParentGas.selector
                && outputs.checkpoint(id).nextIndex == 4,
            "no partial or starved append"
        );
        outputs.append(id, second); // High-budget diagnostic only; never a bounded acceptance oracle.
        _coolLargeRender(bytes32(0), address(outputs));
        (fits, reason) = _envelope(
            address(outputs),
            abi.encodeCall(outputs.requireCurrentCheckpoint, (id)),
            "eight row current diagnostic"
        );
        require(
            !fits && bytes4(reason) == O.StaticContentParentGas.selector,
            "oversized current reservation"
        );
        _coolLargeRender(bytes32(0), address(outputs));
        uint256 beforeCurrent = gasleft();
        require(outputs.requireCurrentCheckpoint(id).nextIndex == 8);
        emit log_named_uint("eight row high-budget current", beforeCurrent - gasleft());
        StreamStaticContentCheckpoint reserved = new StreamStaticContentCheckpoint(
            address(selections),
            address(executor),
            _gas("STATIC_CONTENT_READ_GAS", 4000000),
            _gas("STATIC_CONTENT_RENDER_GAS", 14000000)
        );
        bytes32 reservedId = reserved.begin(selection, 0);
        (bool tooWide, bytes memory failure) = _envelope(
            address(reserved),
            abi.encodeCall(reserved.append, (reservedId, first)),
            "14m reservation diagnostic"
        );
        require(
            !tooWide && bytes4(failure) == O.StaticContentParentGas.selector
                && reserved.checkpoint(reservedId).nextIndex == 0,
            "full budget admission retained"
        );
    }

    /// @dev Reset named fixture account/storage access and both SSTORE2 carriers after setup.
    /// This is not a full current-stack or complete transitive cold-readset acceptance claim.
    function _coolLargeRender(bytes32 bundle, address producer) private {
        Raw.Chunk memory chunk;
        if (bundle != bytes32(0)) chunk = metadata.staticBundleChunk(bundle, 0);
        (address encoding,) = renderer.encodingBinding();
        address[17] memory targets = [
            address(core),
            address(router),
            address(metadata),
            address(renderer),
            address(entropy),
            address(attribution),
            producer,
            address(selections),
            selections.scopeMembership(),
            address(inventory),
            address(versions),
            address(modules),
            address(schemas),
            address(executor),
            encoding,
            chunk.first,
            chunk.tail
        ];
        for (uint256 i; i < targets.length; ++i) {
            if (targets[i] != address(0)) safeVm.cool(targets[i]);
        }
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
