// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentStaticTokenRenderingFixture.sol";

/// @notice Five genuine current STATIC lifecycle recipes; native execution is explicitly pending.
contract StreamCurrentStaticTokenRenderingTest is CurrentStaticTokenRenderingFixture {
    function setUp() public {
        _constructStaticTokenRendering();
    }

    function testActualSafeMintPendingThenLiteralFinalizedOutputAndWrongCoreRefusal() public {
        _mintToken();
        string memory pending = router.tokenMetadataJSON(address(core), 1);
        require(
            _has(pending, '"metadata_state":"pending"') && _has(pending, '"animation_url":""')
                && _has(pending, '"token_data_base64":"AP9lKQ=="') && !_has(pending, '"seed":')
                && !_has(pending, '"hash":')
                && _has(pending, _literalContext(0, initialRecord.recordHash, false)),
            "literal pending output never invents seed"
        );
        vm.expectRevert(abi.encodeWithSignature("TokenEntropyNotFinalized(uint256)", 1));
        router.tokenHTML(1);
        vm.expectRevert(abi.encodeWithSignature("TokenEntropyNotFinalized(uint256)", 1));
        router.tokenJSON(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.InvalidCore.selector, address(otherSafe))
        );
        router.tokenURI(address(otherSafe), 1);
        Render.RenderRequest memory wrongCore;
        wrongCore.core = address(otherSafe);
        vm.expectRevert(abi.encodeWithSignature("InvalidStaticRender()"));
        rendering.renderer.tokenURI(wrongCore);
        bytes32 seed = _revealToken();
        _assertOutput(seed, initialRecord.recordHash, "active");
        string memory market = router.tokenMetadataJSON(address(core), 1);
        require(
            _has(market, _literalContext(seed, initialRecord.recordHash, true))
                && _has(market, '"render_mode":"marketplace"')
                && _has(market, '"state":"artist_accepted"'),
            "actual marketplace uses original STATIC output"
        );
        require(
            keccak256(bytes(core.tokenURI(1)))
                == keccak256(
                    bytes(
                        string.concat("data:application/json;base64,", Base64.encode(bytes(market)))
                    )
                ),
            "actual Core dispatch and URI envelope"
        );
    }

    function testCapturedDefaultPreservesMintedTokenWhileFreshCollectionGetsNewDefault() public {
        _mintToken();
        bytes32 seed = _revealToken();
        StaticRouter.ConfigInput memory next = _input();
        next.config.mode = Render.MetadataMode.OFFCHAIN;
        next.config.baseURI = "https://static.example/new/";
        next.config.pendingURI = "ipfs://new-pending";
        _tokenSafe(
            governor, address(router), 0, abi.encodeCall(router.setDefaultMetadataConfig, (next))
        );
        StaticRouter.ConfigRecord memory global = router.defaultMetadataConfig();
        require(
            global.previous == defaultRecord && global.revision == 2 && global.defaultRevision == 2
                && global.level == 0,
            "independent next default revision"
        );
        _assertConfigRecord(global, next);
        require(
            router.resolvedMetadataConfig(1).recordHash == initialRecord.recordHash,
            "minted token retains captured default"
        );
        _assertOutput(seed, initialRecord.recordHash, "active");
        (GovernanceCall memory op, bytes memory data) =
            StreamCurrentStackPlan.createCollectionCall(core, 3, 5);
        _executeStage(_single(op, data), keccak256("fresh control collection three"));
        _tokenSafe(
            governor,
            address(router),
            0,
            abi.encodeCall(router.activateStaticMetadata, (3, global.recordHash))
        );
        StaticRouter.ConfigRecord memory fresh = router.collectionMetadataConfig(3);
        require(
            fresh.previous == global.recordHash && fresh.collectionId == 3 && fresh.revision == 1
                && fresh.defaultRevision == 2 && fresh.level == 3,
            "fresh control takes exact newer default"
        );
        _assertConfigRecord(fresh, next);
        require(
            core.collectionMintedEver(3) == 0 && core.collectionMintedEver(2) == 1,
            "default write never mints"
        );
        _assertOutput(seed, initialRecord.recordHash, "active");
    }

    function testActualArtistConsentWrongAuthorityWrongModuleStaleInputAndExactRetry() public {
        _mintToken();
        bytes32 seed = _revealToken();
        StaticRouter.ConfigInput memory next = _input();
        next.config.mode = Render.MetadataMode.HYBRID;
        next.config.baseURI = "https://static.example/token/";
        bytes32 consent = _configConsent(1, next);
        bytes memory data = abi.encodeCall(router.setTokenMetadataConfig, (1, next));
        bytes memory exact = _tokenPayload(governor, address(router), 0, data);
        _tokenFailure(otherSafe, _tokenPayload(otherSafe, address(router), 0, data));
        _assertUntouchedConsent(consent);
        // Genuine ModuleRegistry has code but is not the admitted RENDERER_REGISTRY module.
        next.registry = address(registry);
        _tokenFailure(
            governor,
            _tokenPayload(
                governor,
                address(router),
                0,
                abi.encodeCall(router.setTokenMetadataConfig, (1, next))
            )
        );
        _assertUntouchedConsent(consent);
        next.registry = address(rendering.versions);
        next.config.baseURI = "https://static.example/unsigned/";
        _tokenFailure(
            governor,
            _tokenPayload(
                governor,
                address(router),
                0,
                abi.encodeCall(router.setTokenMetadataConfig, (1, next))
            )
        );
        _assertUntouchedConsent(consent);
        next.config.baseURI = "https://static.example/token/";
        vm.recordLogs();
        _tokenSuccess(governor, exact);
        StaticRouter.ConfigRecord memory record = router.resolvedMetadataConfig(1);
        require(
            record.collectionId == 2 && record.tokenId == 1 && record.previous == 0
                && record.revision == 2 && record.defaultRevision == 1 && record.level == 2
                && record.sourceSnapshotHash == 0,
            "independent first token override"
        );
        _assertConfigRecord(record, next);
        _configEvent(vm.getRecordedLogs(), record);
        require(
            router.consumedArtistContentConsent(consent),
            "only successful write consumed original op17"
        );
        (bytes32 captured, uint64 defaultRevision, bytes32 head) =
            router.staticMetadataActivation(2);
        require(
            captured == defaultRecord && defaultRevision == 1
                && head
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_STATIC_METADATA_OVERRIDES_V1"),
                            bytes32(0),
                            uint256(2),
                            uint256(1),
                            record.recordHash,
                            uint64(2)
                        )
                    ),
            "independent override chain commitment"
        );
        _assertOutput(seed, record.recordHash, "active");
        require(
            _has(router.tokenJSON(1), '"offchain_metadata_uri":"https://static.example/token/1"'),
            "literal hybrid URI"
        );
        _tokenFailure(governor, _tokenPayload(governor, address(router), 0, data));
        require(
            router.resolvedMetadataConfig(1).recordHash == record.recordHash
                && router.consumedArtistContentConsent(consent),
            "replay leaves exact original receipt"
        );
        _assertOutput(seed, record.recordHash, "active");
    }

    function _assertUntouchedConsent(bytes32 consent) private view {
        require(
            !router.consumedArtistContentConsent(consent)
                && router.resolvedMetadataConfig(1).recordHash == initialRecord.recordHash,
            "denied writes preserve record and Artist consent"
        );
        (bytes32 captured, uint64 revision, bytes32 head) = router.staticMetadataActivation(2);
        require(
            captured == defaultRecord && revision == 1 && head == 0,
            "denied writes preserve activation history"
        );
    }

    function testOriginalBurnKeepsFullStaticIdentityAndRefusesERC721Output() public {
        _mintToken();
        bytes32 seed = _revealToken();
        vm.recordLogs();
        _tokenSafe(tokenBuyer, address(core), 0, abi.encodeCall(core.burn, (uint256(1))));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _oneTokenEvent(
            logs,
            address(core),
            keccak256("Transfer(address,address,uint256)"),
            bytes32(uint256(uint160(address(tokenBuyer)))),
            0,
            bytes32(uint256(1)),
            ""
        );
        uint256 burnReceipts;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(core) || logs[i].topics.length != 3
                    || logs[i].topics[0]
                        != keccak256("StreamTokenBurned(uint256,uint256,uint256,uint16)")
            ) continue;
            require(
                logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == bytes32(uint256(2))
                    && keccak256(logs[i].data) == keccak256(abi.encode(uint256(1), uint16(1))),
                "exact original burn serial receipt"
            );
            ++burnReceipts;
        }
        require(burnReceipts == 1, "one original burn receipt");
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(1);
        require(
            exists && collection == 2 && serial == 1 && burned && core.totalSupply() == 0
                && core.collectionMintedEver(2) == 1 && core.collectionNextSerial(2) == 2,
            "burn preserves lifetime identity and high water"
        );
        vm.expectRevert(bytes("ERC721: invalid token ID"));
        core.tokenURI(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.InvalidToken.selector, uint256(1))
        );
        router.tokenURI(address(core), 1);
        require(
            core.coordinatorAtMint(1) == address(entropy)
                && keccak256(core.tokenData(1)) == keccak256(STATIC_TOKEN_DATA),
            "burn retains original output sources"
        );
        _assertOutput(seed, initialRecord.recordHash, "burned");
        require(
            wallet.balance == PRICE && address(tokenBuyer).balance == 1 ether - PRICE,
            "burn does not undo settled price"
        );
    }

    function testReceiverFailureRestoresRealMintThenIdenticalSafeTransactionRenders() public {
        StaticTokenReceiver receiver = new StaticTokenReceiver(address(core));
        (IStreamFixedPriceSaleAdapter.SaleAuthorization memory a, bytes memory exact) =
            _purchase(address(receiver));
        StaticTokenVm(address(vm))
            .expectCall(address(receiver), abi.encodePacked(receiver.onERC721Received.selector));
        _tokenFailure(tokenBuyer, exact);
        require(
            receiver.calls() == 0 && core.totalSupply() == 0 && core.lastAllocatedTokenId() == 0
                && core.collectionMintedEver(2) == 0 && core.collectionNextSerial(2) == 1
                && manager.nextOperationNonce() == 0 && core.pendingPreparedMintTokenId() == 0
                && !core.preparedMint(1).exists && core.tokenData(1).length == 0
                && core.coordinatorAtMint(1) == address(0),
            "actual receiver rejection restores whole mint"
        );
        require(
            !sale.authorizationUsed(address(tokenArtist), a.nonce) && wallet.balance == 0
                && address(tokenBuyer).balance == 1 ether && provider.nextRequestId() == 1,
            "failed callback restores auth payment and request state"
        );
        _assertMintLedger(false);
        (, bool finalized) = entropy.tokenSeed(1);
        require(!finalized, "no failed seed");
        require(
            router.collectionMetadataConfig(2).recordHash == initialRecord.recordHash,
            "failed mint preserves original activated route"
        );
        receiver.repair();
        vm.recordLogs();
        _tokenSuccess(tokenBuyer, exact);
        _mintEvents(vm.getRecordedLogs(), address(receiver));
        _mintState(address(receiver));
        require(
            receiver.calls() == 1 && sale.authorizationUsed(address(tokenArtist), a.nonce),
            "one original callback and sale consumption"
        );
        bytes32 seed = _revealToken();
        _assertOutput(seed, initialRecord.recordHash, "active");
    }
}
