// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamRendererV1 } from "../../../smart-contracts/domains/metadata/StreamRendererV1.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamStaticMetadataSource as Raw
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataSource.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamScriptBundles as B
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScriptBundles.sol";
import { ManifestArtistBoundary } from "./StreamCollectionManifests.t.sol";
import "./StreamCollectionMetadataV1.t.sol";
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";

interface StaticRouteVm {
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract StaticRouteCore is MetadataCoreBoundary {
    address public entropy;
    bool public frozen;
    uint256 public minted;

    function setEntropy(address a) external {
        entropy = a;
    }

    function setFrozen(bool value) external {
        frozen = value;
    }

    function setMinted(uint256 value) external {
        minted = value;
    }

    function collectionFreezeStatus(uint256) external view returns (bool) {
        return frozen;
    }

    function collectionMintedEver(uint256) external view returns (uint256) {
        return minted;
    }

    function collectionSupplyMode(uint256) external pure returns (uint8) {
        return 0;
    }

    function collectionStatus(uint256) external pure returns (uint8) {
        return 0;
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return entropy;
    }

    function tokenData(uint256) external pure returns (bytes memory) {
        return hex"00ff6529";
    }
}

contract StaticRouteEntropy {
    bool public finalized = true;

    function setFinalized(bool value) external {
        finalized = value;
    }

    function staticTokenRenderFacts(uint256) external view returns (uint8, bytes32, address) {
        return (
            finalized ? 5 : 4,
            finalized ? keccak256("real boundary seed") : bytes32(0),
            address(this)
        );
    }

    function tokenSeed(uint256) external view returns (bytes32, bool) {
        return (keccak256("real boundary seed"), finalized);
    }

    function tokenEntropy(uint256)
        external
        view
        returns (uint8, bytes32, address, uint32, bytes32, bytes32, uint256, uint16)
    {
        return (
            finalized ? 5 : 4,
            finalized ? keccak256("real boundary seed") : bytes32(0),
            address(this),
            1,
            0,
            0,
            0,
            0
        );
    }
}

/// @dev Explicit source-role boundary; the genuine full AA-DISPLAY transport is a separate source suite.
contract StaticRouteAttribution {
    address public core;
    address public router;
    bool public fail;
    string public state = "disputed";

    constructor(address c, address r) {
        core = c;
        router = r;
    }

    function setFail(bool value) external {
        fail = value;
    }

    function attribution(uint256, uint256) external view returns (bytes memory) {
        require(!fail);
        return abi.encodePacked('{"state":"', state, '"}');
    }
}

/// @dev Admitted-version storage boundary only. The actual registry gate has its own tests.
contract StaticRouteVersions {
    address public governanceAuthority;
    address public schemaRegistry;
    V.Registration private registered;
    V.Version private saved;
    bytes32 public key;

    constructor(address executor, address schemas, address renderer) {
        governanceAuthority = executor;
        schemaRegistry = schemas;
        registered.renderer = renderer;
        registered.manifest = R(renderer).rendererManifest();
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_VERSION_V1"),
                registered.manifest.rendererId,
                registered.manifest.rendererVersion
            )
        );
        saved = V.Version(
            true,
            false,
            renderer,
            renderer.codehash,
            keccak256("registered original"),
            keccak256("declared reads"),
            keccak256("analysis"),
            keccak256("golden"),
            keccak256("action")
        );
    }

    function version(bytes32 k) external view returns (V.Version memory) {
        require(k == key);
        return saved;
    }

    function registration(bytes32 k) external view returns (V.Registration memory) {
        require(k == key);
        return registered;
    }

    function requireAssignable(bytes32 k) external view returns (address, bytes32) {
        require(k == key && !saved.deprecated);
        return (saved.renderer, saved.runtimeHash);
    }

    function requireRetained(bytes32 k) external view returns (address, bytes32) {
        require(k == key);
        return (saved.renderer, saved.runtimeHash);
    }

    function deprecate() external {
        saved.deprecated = true;
    }
}

contract StaticRouteModules {
    address public metadata;
    address public versions;
    bool public enabled = true;

    constructor(address m, address v) {
        metadata = m;
        versions = v;
    }

    function setEnabled(bool value) external {
        enabled = value;
    }

    function isModuleEligible(address a, bytes32 kind, bytes4 id) external view returns (bool) {
        return enabled
            && ((a == metadata
                    && kind == keccak256("COLLECTION_METADATA")
                    && id == type(IStreamCollectionMetadataV1).interfaceId)
                || (a == versions
                    && kind == keccak256("RENDERER_REGISTRY")
                    && id == type(V).interfaceId));
    }
}

/// @notice Actual Router/Renderer/Metadata/Schema/SSTORE2 and threshold Safe; typed source boundaries named above.
/// @dev Authored only until executed. These cases are not current-Core mint, true Artist, registry static-analysis,
/// finality, or transitive source conformance acceptance. The actual registry mechanics have a separate suite.
contract StreamStaticMetadataRoutingTest is CharacterizationTestBase, OfficialSafeFixture {
    StaticRouteCore private core;
    StaticRouteEntropy private entropy;
    ManifestArtistBoundary private artist;
    MetadataExecutorBoundary private executor;
    StreamSchemaRegistry private schemas;
    StreamCollectionMetadataV1 private metadata;
    StreamMetadataRouter private router;
    StreamRendererV1 private renderer;
    StaticRouteAttribution private attribution;
    StaticRouteVersions private versions;
    StaticRouteModules private modules;
    bytes32 private constant FAMILY = keccak256("RENDERER_CONFIG");

    function setUp() public {
        core = new StaticRouteCore();
        entropy = new StaticRouteEntropy();
        core.setEntropy(address(entropy));
        executor = new MetadataExecutorBoundary();
        artist = new ManifestArtistBoundary(address(core));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(artist));
        router = new StreamMetadataRouter(
            address(core),
            address(executor),
            keccak256("deployment"),
            "ipfs://router",
            keccak256("manifest"),
            IStreamArtistAttribution(address(artist))
        );
        artist.setRouter(address(router));
        core.setPointer(keccak256("METADATA_ROUTER"), address(router));
        schemas = new StreamSchemaRegistry(address(executor));
        StreamCollectionMetadataV1.Configuration memory mc;
        mc.core = address(core);
        mc.executor = address(executor);
        mc.schemas = address(schemas);
        mc.artistRegistry = address(artist);
        mc.deploymentManifestHash = keccak256("deployment");
        mc.manifestHash = keccak256("metadata");
        mc.manifestURI = "ipfs://metadata";
        mc.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        mc.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(mc);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        _admin(
            abi.encodeCall(
                router.setCollectionMetadata, (1, "Static work", "Exact source", "ipfs://image", "")
            )
        );
        _admin(
            abi.encodeCall(router.setCollectionScript, (1, "document.body.textContent = tokenId;"))
        );
        attribution = new StaticRouteAttribution(address(core), address(router));
        StreamRendererV1.Deployment memory d;
        d.executor = address(executor);
        d.sources = StreamRendererV1.Sources(
            address(core),
            address(router),
            address(metadata),
            address(entropy),
            address(0),
            address(attribution)
        );
        d.readGas = mc.dependencyReadGas;
        d.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        d.manifest = R.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256("schema"),
            "ipfs://schema",
            "ipfs://renderer",
            keccak256("manifest"),
            16777216,
            16777216,
            false
        );
        renderer = new StreamRendererV1(d);
        versions = new StaticRouteVersions(address(executor), address(schemas), address(renderer));
        modules = new StaticRouteModules(address(metadata), address(versions));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(modules));
        _grant(address(this), 8);
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

    function _activate() private {
        bytes32 key = router.setDefaultMetadataConfig(_input(R.MetadataMode.ONCHAIN, false));
        router.activateStaticMetadata(1, key);
    }

    function _mint() private {
        core.setToken(91, address(this), 2);
        core.setMinted(1);
    }

    function _input(R.MetadataMode mode, bool frozen)
        private
        view
        returns (S.ConfigInput memory input)
    {
        input.registry = address(versions);
        input.versionKey = versions.key();
        input.config = R.MetadataConfig(
            mode,
            address(renderer),
            mode == R.MetadataMode.ONCHAIN ? "" : "https://example.test/",
            "",
            R.OffchainURIIdMode.TOKEN_ID,
            frozen
        );
    }

    function _approve(uint256 token, S.ConfigInput memory input, bytes32 evidence) private {
        artist.approve(1, FAMILY, router.previewStaticMetadataConfig(1, token, input), evidence);
    }

    function _admin(bytes memory data) private {
        executor.execute(address(router), data, 0, 0, 0);
    }

    function _grant(address who, uint8 kind) private {
        (bytes32 scope, bytes32 oldHash, bytes32 next) = metadata.familyWriterTransition(
            0, keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1"), kind, who, true
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter,
                (0, keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1"), kind, who, true)
            ),
            scope,
            oldHash,
            next
        );
    }

    function _has(string memory haystack, string memory needle) private pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i; i <= h.length - n.length; ++i) {
            bool match_ = true;
            for (uint256 j; j < n.length; ++j) {
                if (h[i + j] != n[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) return true;
        }
        return false;
    }
}
