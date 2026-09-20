// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/StaticMetadataRoutingFixture.sol";

contract StreamStaticMetadataRoutingTest is StaticMetadataRoutingFixture {
    function setUp() public override {
        super.setUp();
        _optInCurrentCitationAdmissionBoundary();
    }

    function testFrozenDefaultCannotChangeButCapturesEachNewActivation() public {
        S.ConfigInput memory input = _input(R.MetadataMode.ONCHAIN, true);
        input.config.frozen = true;
        bytes32 frozenDefault = router.setDefaultMetadataConfig(input);
        input.config.frozen = false;
        vm.expectRevert();
        router.setDefaultMetadataConfig(input);
        require(router.defaultMetadataConfig().recordHash == frozenDefault);
        router.activateStaticMetadata(1, frozenDefault);
        S.ConfigRecord memory activation = router.collectionMetadataConfig(1);
        require(activation.previous == frozenDefault && activation.config.frozen);
        require(activation.sourceSnapshotHash != 0, "original source captured at activation");
    }

    function testActivationPinsDefaultAndIndependentFullRecord() public {
        S.ConfigInput memory input = _input(R.MetadataMode.ONCHAIN, false);
        bytes32 global = router.setDefaultMetadataConfig(input);
        bytes32 expectedFamily = router.previewStaticMetadataActivation(1, global);
        router.activateStaticMetadata(1, global);
        S.ConfigRecord memory record = router.collectionMetadataConfig(1);
        bytes32 actual = record.recordHash;
        record.recordHash = 0;
        require(
            actual
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1"),
                        address(core),
                        address(router),
                        record
                    )
                ),
            "independent full preimage"
        );
        (bool supported, bytes32 family) = router.artistContentFamilyState(1, FAMILY);
        require(supported && family == expectedFamily);
        input.config.mode = R.MetadataMode.HYBRID;
        input.config.baseURI = "https://example.test/";
        router.setDefaultMetadataConfig(input);
        require(router.collectionMetadataConfig(1).recordHash == actual, "no floating old scope");
        (bytes32 savedDefault, uint64 revision,) = router.staticMetadataActivation(1);
        require(savedDefault == global && revision == 1);
        _admin(abi.encodeCall(router.setCollectionMetadata, (2, "Second", "", "ipfs://second", "")));
        bytes32 next = router.defaultMetadataConfig().recordHash;
        router.activateStaticMetadata(2, next);
        require(
            router.collectionMetadataConfig(2).defaultRevision == 2,
            "new activation captures new default"
        );
    }

    function testRealRendererOpaqueContextVersionsAndDisputeDisclosure() public {
        _activate();
        _mint();
        string memory json = router.tokenJSON(91);
        string memory html = router.tokenHTML(91);
        require(_has(json, '"state":"disputed"') && _has(json, '"token_data_base64":"AP9lKQ=="'));
        require(
            _has(html, "window.__STREAM_TOKEN__") && _has(html, '"tokenData":"0x00ff6529"')
                && _has(html, "const tokenId")
        );
        require(_has(json, '"rendererVersion"') && _has(json, '"renderContextVersion"'));
        require(bytes(router.tokenURI(address(core), 91)).length <= 24576);
    }

    function testFrozenTokenRetainsRawSourceWhileMutableCollectionChanges() public {
        _activate();
        _mint();
        S.ConfigInput memory input = _input(R.MetadataMode.ONCHAIN, true);
        _approve(91, input, keccak256("freeze token consent"));
        router.setTokenMetadataConfig(91, input);
        string memory prior = router.tokenHTML(91);
        bytes32 snapshot = router.resolvedMetadataConfig(91).sourceSnapshotHash;
        require(snapshot != 0);
        string memory replacement = "document.body.textContent = 'new';";
        artist.approve(
            1,
            keccak256("SCRIPT"),
            router.previewArtistScriptState(1, replacement),
            keccak256("script consent")
        );
        _admin(abi.encodeCall(router.setCollectionScript, (1, replacement)));
        require(
            keccak256(bytes(prior)) == keccak256(bytes(router.tokenHTML(91))),
            "frozen bytes retained"
        );
        S.ConfigInput memory next = _input(R.MetadataMode.HYBRID, false);
        vm.expectRevert(
            abi.encodeWithSelector(S.StaticMetadataLocked.selector, uint256(1), uint256(91))
        );
        router.setTokenMetadataConfig(91, next);
    }

    function testOriginalConsentConsumedOnceAndDeniedRetryUnchanged() public {
        _activate();
        _mint();
        S.ConfigInput memory input = _input(R.MetadataMode.HYBRID, false);
        bytes32 consent = keccak256("original op17");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, uint256(1)
            )
        );
        router.setTokenMetadataConfig(91, input);
        _approve(91, input, consent);
        router.setTokenMetadataConfig(91, input);
        require(router.consumedArtistContentConsent(consent));
        input.config.baseURI = "https://example.test/changed/";
        _approve(91, input, consent);
        bytes32 prior = router.resolvedMetadataConfig(91).recordHash;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentConsentConsumed.selector, consent
            )
        );
        router.setTokenMetadataConfig(91, input);
        require(router.resolvedMetadataConfig(91).recordHash == prior);
    }

    function testRealSafeCallerFailureAndByteIdenticalRetry() public {
        _activate();
        _mint();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0x6530;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 989);
        _grant(address(account), 7);
        S.ConfigInput memory input = _input(R.MetadataMode.HYBRID, false);
        bytes32 consent = keccak256("safe consent");
        _approve(91, input, consent);
        bytes memory callData = abi.encodeCall(router.setTokenMetadataConfig, (91, input));
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            address(router), 0, callData, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        modules.setEnabled(false);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(router), 0, callData, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(account.nonce() == nonce && !router.consumedArtistContentConsent(consent));
        modules.setEnabled(true);
        require(
            account.execTransaction(
                address(router),
                0,
                callData,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
        require(account.nonce() == nonce + 1 && router.consumedArtistContentConsent(consent));
        S.Authorization memory authorization =
            router.metadataConfigAuthorization(router.resolvedMetadataConfig(91).recordHash);
        require(
            authorization.actor == address(account) && authorization.authorityClass == 7
                && authorization.metadata == address(metadata)
        );
    }

    function testPendingOffchainSerialModeAndBurnedFullDisclosure() public {
        S.ConfigInput memory input = _input(R.MetadataMode.OFFCHAIN, false);
        input.config.offchainURIIdMode = R.OffchainURIIdMode.COLLECTION_SERIAL;
        input.config.pendingURI = "ipfs://pending";
        bytes32 key = router.setDefaultMetadataConfig(input);
        router.activateStaticMetadata(1, key);
        _mint();
        entropy.setFinalized(false);
        require(keccak256(bytes(router.tokenURI(address(core), 91))) == keccak256("ipfs://pending"));
        entropy.setFinalized(true);
        require(
            keccak256(bytes(router.tokenURI(address(core), 91)))
                == keccak256("https://example.test/91")
        );
        core.setToken(91, address(this), 3);
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.InvalidToken.selector, uint256(91))
        );
        router.tokenURI(address(core), 91);
        require(_has(router.tokenJSON(91), '"metadata_state":"burned"'));
    }

    function testDeprecatedRetainedVersionServesButNewAssignmentRefuses() public {
        _activate();
        _mint();
        versions.deprecate();
        require(bytes(router.tokenJSON(91)).length != 0);
        S.ConfigInput memory input = _input(R.MetadataMode.HYBRID, false);
        vm.expectRevert(abi.encodeWithSelector(S.InvalidStaticMetadataConfig.selector));
        router.previewStaticMetadataConfig(1, 91, input);
    }

    function testLateActivationAndRendererFamilyFreezeRefuse() public {
        bytes32 key = router.setDefaultMetadataConfig(_input(R.MetadataMode.ONCHAIN, false));
        core.setMinted(1);
        vm.expectRevert(abi.encodeWithSelector(S.InvalidStaticMetadataConfig.selector));
        router.activateStaticMetadata(1, key);
        core.setMinted(0);
        router.activateStaticMetadata(1, key);
        _mint();
        artist.freeze(FAMILY, router.artistContentFreezeState(1));
        router.applyArtistContentFreeze(1, keccak256("manifest freeze"));
        S.ConfigInput memory next = _input(R.MetadataMode.HYBRID, false);
        vm.expectRevert(
            abi.encodeWithSelector(S.StaticMetadataLocked.selector, uint256(1), uint256(0))
        );
        router.setTokenMetadataConfig(91, next);
    }

    function testFullLogicalSstoreChunkUsesActualRawPointersAndCompactDefault() public {
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
        B.Plan memory plan =
            B.Plan(hashes[0], M.PayloadSourceType.SSTORE2, hashes, lengths, 0, false);
        bytes32 bundle = metadata.beginScriptBundle(plan);
        metadata.appendScriptBundle(bundle, 0, program);
        metadata.finalizeScriptBundle(bundle);
        Raw.Chunk memory chunk = metadata.staticBundleChunk(bundle, 0);
        require(
            chunk.length == 24576 && chunk.first.code.length == 24576 && chunk.tail.code.length == 2
        );
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
        _activate();
        _mint();
        require(
            keccak256(renderer.scriptBundleChunk(bundle, 0)) == keccak256(program),
            "paged and assembled source bytes"
        );
        require(
            renderer.scriptBundleFacts(bundle).payloadHash == keccak256(program),
            "full reconstruction commitment"
        );
        vm.expectRevert();
        renderer.scriptBundleChunk(bundle, 1);
        require(_has(router.tokenHTML(91), string(program)));
        string memory json = router.tokenMetadataJSON(address(core), 91);
        require(
            _has(json, '"render_mode":"compact"')
                && _has(router.tokenJSON(91), '"render_mode":"full"')
        );
        StaticRouteVm(address(vm))
            .mockCallRevert(
                address(metadata), abi.encodeCall(Raw.staticBundleChunk, (bundle, 0)), "missing"
            );
        vm.expectRevert();
        router.tokenHTML(91);
    }

    function testEmptySourceGoldenIsExplicitInputAndAttributionFailureIsVisible() public {
        R.RenderRequest memory request = R.RenderRequest(
            address(core),
            0,
            2,
            0,
            0,
            R.TokenRenderState.PENDING_RANDOMNESS,
            R.MetadataMode.ONCHAIN,
            0,
            0,
            0,
            0,
            0
        );
        require(bytes(renderer.tokenURI(request)).length != 0, "registration before minted token");
        _activate();
        _mint();
        attribution.setFail(true);
        require(_has(router.tokenJSON(91), '"state":"attribution_unavailable"'));
    }
}
