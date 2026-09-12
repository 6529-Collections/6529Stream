// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    PermanentTargetGovernanceExecutor,
    PermanentTargetModuleRegistry,
    PermanentTargetCoreHarness
} from "../core/StreamCorePermanentTarget.t.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockVRFCoordinatorV2Plus.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../mocks/StreamMetadataArtistBoundary.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/core/StreamCore.sol";
import "../../../smart-contracts/core/StreamCoreExternalReads.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";

interface EntropyGasMeasurementVm {
    function cool(address account) external;
}

contract UnavailableEntropyMetadataEmitter {
    fallback() external {
        revert("metadata emitter temporarily unavailable");
    }
}

contract NativeMetadataEncodingHarness is StreamMetadataRouter {
    constructor(
        address core_,
        address authority_,
        bytes32 manifest_,
        IStreamArtistAttribution artist_
    )
        StreamMetadataRouter(core_, authority_, manifest_, "ipfs://local-test", manifest_, artist_)
    { }

    function prepareScript(string memory raw) external pure returns (string memory) {
        return _prepareScript(raw);
    }
}

/// @notice Real Core, entropy and rendering with explicit governance and artist read boundaries.
/// @dev Direct Core minting isolates entropy/metadata; current-stack tests prove artist eligibility.
contract StreamEntropyMetadataTest is CharacterizationTestBase, OfficialSafeFixture, EntropyTimeAuthorityFixture {
    event NativeVRFCallbackGasMeasured(uint256 gasUsed);
    event log_named_uint(string key, uint256 value);
    bytes32 private constant MANAGER =
        0x136326f089f522351128a5fb79275bd12b2d84fe5bb50d5e46c9f5508d6df7e2;
    bytes32 private constant ENTROPY =
        0xb3b3ef20764c647bdeda70b21ab009ff2783106d6995be14389ec6f42ea6dfbb;
    bytes32 private constant ROUTER =
        0x7024d3e2544fc48a261933c43d901dca0ee3fc26ea2b857748ab0c295a16f20a;
    bytes32 private constant REGISTRY =
        0xde86dd5f33a5b2bd22cfbe7752609f5086a946f705768f7e2e6cb501157a41c4;
    bytes32 private constant MANIFEST = keccak256("local-test-manifest");
    address private constant RECIPIENT = address(0xbeef);
    PermanentTargetCoreHarness private core;
    PermanentTargetGovernanceExecutor private executor;
    PermanentTargetModuleRegistry private registry;
    StreamEntropyCoordinator private entropy;
    StreamMetadataRouter private router;
    StreamMetadataArtistBoundary private artistRegistry;
    MockStreamEntropyProvider private provider;
    MockEntropyRoleRegistry public roleRegistry;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamMintManager).interfaceId || id == 0x01ffc9a7;
    }
    receive() external payable { }

    function setUp() public {
        executor = new PermanentTargetGovernanceExecutor();
        registry = new PermanentTargetModuleRegistry();
        registry.setGovernanceExecutor(address(this));
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        StreamCore.GasParameterGenesisConfig[] memory gasConfigs =
            new StreamCore.GasParameterGenesisConfig[](4);
        gasConfigs[0] = StreamCore.GasParameterGenesisConfig(
            0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda, 50000, 25000, 1
        );
        gasConfigs[1] = StreamCore.GasParameterGenesisConfig(
            0x0af6f5a1a5059e398191fa0af185be12fee6d609933826603244c7f247793be7, 2910000, 1460000, 1
        );
        // Full 16 KiB token data plus 8 KiB script requires nested Base64 encoding. The cold
        // maximum-content test below measures this budget and Core's 64 KiB response ceiling.
        gasConfigs[2] = StreamCore.GasParameterGenesisConfig(
            0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93, 12000000, 250000, 1
        );
        // Cold first registration writes coordinator-owned identity; Core's atomic mint must
        // provide at least the measured registration envelope. This product fixture grants 200k.
        gasConfigs[3] = StreamCore.GasParameterGenesisConfig(
            0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17, 200000, 120000, 2
        );
        core = new PermanentTargetCoreHarness(
            "Stream",
            "STREAM",
            address(executor),
            StreamCore.GenesisModuleRegistryConfig(
                address(registry), address(registry).codehash, MANIFEST, MANIFEST
            ),
            gasConfigs
        );
        registry.setRecord(
            address(registry), REGISTRY, type(IStreamModuleRegistry).interfaceId, MANIFEST, MANIFEST
        );
        entropy = new StreamEntropyCoordinator(StreamEntropyCoordinator.DeploymentConfig(
            address(core),
            address(this),
            address(roleRegistry),
            EntropyTimeTestConfigs.parameters(),
            MANIFEST,
            "ipfs://local-test",
            MANIFEST
        ));
        artistRegistry = new StreamMetadataArtistBoundary(address(core), address(this), RECIPIENT);
        router = new NativeMetadataEncodingHarness(
            address(core), address(this), MANIFEST, artistRegistry
        );
        provider = new MockStreamEntropyProvider(address(entropy));
        _install(MANAGER, address(this), type(IStreamMintManager).interfaceId);
        _install(ENTROPY, address(entropy), type(IStreamEntropyCoordinator).interfaceId);
        _install(ROUTER, address(router), type(IStreamMetadataRouter).interfaceId);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                block.chainid,
                address(core),
                uint256(1)
            )
        );
        bytes32 oldState = keccak256(
            abi.encode(
                bytes32(0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5),
                scope,
                false,
                uint8(0),
                uint8(0),
                false,
                uint256(0)
            )
        );
        bytes32 newState = keccak256(
            abi.encode(
                bytes32(0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5),
                scope,
                true,
                uint8(2),
                uint8(0),
                false,
                uint256(0)
            )
        );
        executor.setAction(1, scope, oldState, newState);
        executor.execute(address(core), abi.encodeCall(core.createCollection, (2, false, 0, 0)));
        _install(
            keccak256("ARTIST_REGISTRY"),
            address(artistRegistry),
            type(IStreamArtistMintConsent).interfaceId
        );
        entropy.configureCollection(1, address(provider), keccak256("collection-salt"), true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        router.setCollectionMetadata(
            1, 'Artist "Collection"', "Description", "ipfs://image", "https://example.test/art/"
        );
        vm.deal(address(this), 1 ether);
    }

    function testArtistContentFamiliesSeparateArtworkFromDisplayAndMatchPreviews() public {
        router.setCollectionScript(1, "document.body.textContent=tokenHash;");
        (, bytes32 fullBefore) = router.currentArtistContentState(1);
        (bool scriptSupported, bytes32 scriptBefore) =
            router.artistContentFamilyState(1, keccak256("SCRIPT"));
        (bool mediaSupported, bytes32 mediaBefore) =
            router.artistContentFamilyState(1, keccak256("MEDIA_MANIFEST"));
        require(scriptSupported && mediaSupported, "actual artwork families");
        require(scriptBefore != mediaBefore, "family separation");
        router.setCollectionMetadata(
            1, "New display title", "New description", "ipfs://image", "https://example.test/art/"
        );
        (, bytes32 afterDisplay) = router.currentArtistContentState(1);
        require(afterDisplay == fullBefore, "display text does not change artwork");
        bytes32 nextScript = router.previewArtistScriptState(1, "document.body.textContent='new';");
        router.setCollectionScript(1, "document.body.textContent='new';");
        (, bytes32 scriptAfter) = router.artistContentFamilyState(1, keccak256("SCRIPT"));
        (, bytes32 mediaAfterScript) =
            router.artistContentFamilyState(1, keccak256("MEDIA_MANIFEST"));
        require(scriptAfter == nextScript && scriptAfter != scriptBefore, "script preview");
        require(mediaAfterScript == mediaBefore, "script does not modify media family");
        bytes32 nextMedia = router.previewArtistMediaState(1, "ipfs://new", "https://new.test/art/");
        router.setCollectionMetadata(
            1, "Title", "Description", "ipfs://new", "https://new.test/art/"
        );
        (, bytes32 mediaAfter) = router.artistContentFamilyState(1, keccak256("MEDIA_MANIFEST"));
        (, bytes32 scriptAfterMedia) = router.artistContentFamilyState(1, keccak256("SCRIPT"));
        require(mediaAfter == nextMedia && mediaAfter != mediaBefore, "media pair preview");
        require(scriptAfterMedia == scriptAfter, "media does not modify script family");
    }

    function testDefensiveContentFactsDoNotGrantMintReadinessOrUnknownFamilies() public {
        bytes32 defensive = router.artistContentFreezeState(1);
        require(defensive != bytes32(0), "empty script can be defensively frozen");
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.UnconfiguredOnchainContent.selector, 1)
        );
        router.currentArtistContentState(1);
        (bool supported, bytes32 hash) = router.artistContentFamilyState(1, keccak256("UNKNOWN"));
        require(!supported && hash == bytes32(0), "unknown family");
        (bool knownLock, bool locked) = router.artistContentLockState(1, keccak256("METADATA_ALL"));
        require(!knownLock && !locked, "artist cannot freeze unrelated metadata");
        (knownLock, locked) = router.artistContentLockState(1, keccak256("DEPENDENCIES"));
        require(knownLock && locked, "linked renderer dependency is immutable");
        (knownLock, locked) = router.artistContentLockState(1, keccak256("BASE_URI"));
        require(knownLock && !locked, "explicit base URI classification");
        (bytes32 ratification, bytes32 content) = router.artistContentEvolution(1);
        require(
            ratification == bytes32(0) && content == bytes32(0), "no invented evolution witness"
        );
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRouter.InvalidCollection.selector, 2));
        router.artistContentFreezeState(2);
    }

    function testContentConsentAppliesExactStateOnceAndExtendsRatification() public {
        router.setCollectionScript(1, "A");
        (, bytes32 initial) = router.currentArtistContentState(1);
        artistRegistry.setRatification(initial);
        bytes32 first = keccak256("consent to B");
        artistRegistry.setContentConsent(
            1, keccak256("SCRIPT"), router.previewArtistScriptState(1, "B"), first
        );
        router.setCollectionScript(1, "B");
        (, bytes32 afterB) = router.currentArtistContentState(1);
        (,, bytes32 ratification) = artistRegistry.firstReleaseRatification(1);
        (bytes32 witnessRatification, bytes32 witnessState) = router.artistContentEvolution(1);
        require(witnessRatification == ratification && witnessState == afterB, "actual evolution");
        require(router.consumedArtistContentConsent(first), "exact record consumed");
        bytes32 second = keccak256("consent to A");
        artistRegistry.setContentConsent(
            1, keccak256("SCRIPT"), router.previewArtistScriptState(1, "A"), second
        );
        router.setCollectionScript(1, "A");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentConsentConsumed.selector, first
            )
        );
        router.setCollectionScript(1, "B");
        (, bytes32 afterFailure) = router.currentArtistContentState(1);
        require(afterFailure == initial, "repeat consent cannot change content");
        bytes32 third = keccak256("fresh consent to B");
        artistRegistry.setContentConsent(
            1, keccak256("SCRIPT"), router.previewArtistScriptState(1, "B"), third
        );
        router.setCollectionScript(1, "B");
        require(
            router.consumedArtistContentConsent(third), "fresh authorization permits same result"
        );
    }

    function testContentNoOpsDoNotConsumeAndStaleBaselineCannotBecomeValid() public {
        router.setCollectionScript(1, "A");
        (, bytes32 initial) = router.currentArtistContentState(1);
        artistRegistry.setRatification(initial);
        bytes32 unused = keccak256("no-op approval");
        artistRegistry.setContentConsent(
            1, keccak256("SCRIPT"), router.previewArtistScriptState(1, "A"), unused
        );
        router.setCollectionScript(1, "A");
        require(!router.consumedArtistContentConsent(unused), "no-op does not consume");
        bytes32 change = keccak256("otherwise valid approval");
        artistRegistry.setContentConsent(
            1, keccak256("SCRIPT"), router.previewArtistScriptState(1, "B"), change
        );
        artistRegistry.setRatification(keccak256("different operative baseline"));
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.ArtistContentEvolutionBroken.selector, 1)
        );
        router.setCollectionScript(1, "B");
        require(
            !router.consumedArtistContentConsent(change),
            "invalid predecessor keeps approval unused"
        );
    }

    function testConsentedEmptyScriptDoesNotInventMintReadyContent() public {
        router.setCollectionScript(1, "A");
        (, bytes32 initial) = router.currentArtistContentState(1);
        artistRegistry.setRatification(initial);
        bytes32 approval = keccak256("consent empty script");
        artistRegistry.setContentConsent(
            1, keccak256("SCRIPT"), router.previewArtistScriptState(1, ""), approval
        );
        router.setCollectionScript(1, "");
        require(router.consumedArtistContentConsent(approval), "approved write applied");
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.UnconfiguredOnchainContent.selector, 1)
        );
        router.currentArtistContentState(1);
    }

    function testFirstMintClosesUnratifiedOperatorContentWindow() public {
        _mint();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, 1
            )
        );
        router.setCollectionScript(1, "not approved");
    }

    function testArtistDefensiveFreezeIsPermissionlessBeforeContentIsReady() public {
        bytes32 freeze =
            _fixtureContentFreeze(keccak256("SCRIPT"), router.artistContentFreezeState(1));
        vm.prank(address(0xBEEF123));
        router.applyArtistContentFreeze(1, freeze);
        (bool supported, bool locked) = router.artistContentLockState(1, keccak256("SCRIPT"));
        require(supported && locked, "actual lock");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentLocked.selector, 1, keccak256("SCRIPT")
            )
        );
        router.setCollectionScript(1, "late artwork");
        router.setCollectionMetadata(
            1, "Editorial title", "Editorial text", "ipfs://image", "https://example.test/art/"
        );
        vm.prank(address(0xCAFE));
        router.applyArtistContentFreeze(1, freeze);
    }

    function testBaseURIFreezeCannotBeBypassedByCombinedMetadataWrite() public {
        bytes32 freeze =
            _fixtureContentFreeze(keccak256("BASE_URI"), router.artistContentFreezeState(1));
        router.applyArtistContentFreeze(1, freeze);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentLocked.selector, 1, keccak256("BASE_URI")
            )
        );
        router.setCollectionMetadata(
            1, "Title", "Description", "ipfs://different", "https://different.test/"
        );
        router.setCollectionMetadata(
            1, "Title", "Description", "ipfs://different", "https://example.test/art/"
        );
        require(
            keccak256(bytes(router.collectionMetadata(1).image)) == keccak256("ipfs://different"),
            "base lock is scoped"
        );
    }

    function testStaleOrUnknownFreezeAppliesNoLock() public {
        bytes32 stale =
            _fixtureContentFreeze(keccak256("SCRIPT"), router.artistContentFreezeState(1));
        router.setCollectionScript(1, "new content");
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.InvalidArtistContentFreeze.selector, stale)
        );
        router.applyArtistContentFreeze(1, stale);
        (, bool locked) = router.artistContentLockState(1, keccak256("SCRIPT"));
        require(!locked, "stale freeze did not lock");
        bytes32 unknown =
            _fixtureContentFreeze(keccak256("METADATA_ALL"), router.artistContentFreezeState(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.InvalidArtistContentFreeze.selector, unknown
            )
        );
        router.applyArtistContentFreeze(1, unknown);
    }

    function testContentApplicationAndFreezeEventsCarryExactEvidence() public {
        router.setCollectionScript(1, "A");
        (, bytes32 initial) = router.currentArtistContentState(1);
        artistRegistry.setRatification(initial);
        bytes32 approval = keccak256("event approval");
        bytes32 family = keccak256("SCRIPT");
        artistRegistry.setContentConsent(
            1, family, router.previewArtistScriptState(1, "B"), approval
        );
        vm.recordLogs();
        router.setCollectionScript(1, "B");
        (, bytes32 resulting) = router.currentArtistContentState(1);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(router)
                    || logs[i].topics[0]
                        != keccak256(
                            "ArtistContentConsentApplied(uint256,bytes32,bytes32,bytes32,uint16)"
                        )
            ) continue;
            ++matches;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == family && logs[i].topics[3] == approval,
                "consent event identity"
            );
            require(
                keccak256(logs[i].data) == keccak256(abi.encode(resulting, uint16(1))),
                "consent event result and schema"
            );
        }
        require(matches == 1, "one consent event");
        bytes32 freeze = _fixtureContentFreeze(family, resulting);
        vm.recordLogs();
        vm.prank(RECIPIENT);
        router.applyArtistContentFreeze(1, freeze);
        logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(router), "one host freeze event");
        require(
            logs[0].topics.length == 3
                && logs[0].topics[0]
                    == keccak256(
                        "CollectionMetadataLocked(uint256,bytes32,address,uint8,bytes32,uint16)"
                    ) && logs[0].topics[1] == bytes32(uint256(1)) && logs[0].topics[2] == family,
            "freeze event identity"
        );
        require(
            keccak256(logs[0].data)
                == keccak256(abi.encode(RECIPIENT, uint8(1), freeze, uint16(1))),
            "freeze actor authority evidence and schema"
        );
    }

    function testSafeAdminContentCallsAndSeparateSafeDefensiveFreeze() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA1101;
        keys[1] = 0xA1102;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        OfficialSafe admin = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 1);
        OfficialSafe relayer = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 2);
        router = new StreamMetadataRouter(
            address(core), address(admin), MANIFEST, "ipfs://local-test", MANIFEST, artistRegistry
        );
        _install(ROUTER, address(router), type(IStreamMetadataRouter).interfaceId);
        _safeContentCall(
            admin,
            keys,
            abi.encodeCall(
                router.setCollectionMetadata, (1, "Safe artist", "Description", "ipfs://safe", "")
            )
        );
        _safeContentCall(admin, keys, abi.encodeCall(router.setCollectionScript, (1, "A")));
        (, bytes32 initial) = router.currentArtistContentState(1);
        artistRegistry.setRatification(initial);
        bytes32 consent = keccak256("Safe content consent");
        artistRegistry.setContentConsent(
            1, keccak256("SCRIPT"), router.previewArtistScriptState(1, "B"), consent
        );
        _safeContentCall(admin, keys, abi.encodeCall(router.setCollectionScript, (1, "B")));
        require(router.consumedArtistContentConsent(consent), "Safe consumes exact consent");
        require(
            keccak256(bytes(router.collectionMetadata(1).animationScript)) == keccak256("B"),
            "Safe changed actual script"
        );
        _safeContentCall(
            relayer, keys, abi.encodeCall(router.artistContentFamilyState, (1, keccak256("SCRIPT")))
        );
        _safeContentCall(
            relayer, keys, abi.encodeCall(router.artistContentLockState, (1, keccak256("SCRIPT")))
        );
        _safeContentCall(relayer, keys, abi.encodeCall(router.artistContentFreezeState, (1)));
        _safeContentCall(relayer, keys, abi.encodeCall(router.artistContentEvolution, (1)));
        _safeContentCall(relayer, keys, abi.encodeCall(router.previewArtistScriptState, (1, "C")));
        _safeContentCall(
            relayer, keys, abi.encodeCall(router.previewArtistMediaState, (1, "ipfs://next", ""))
        );
        bytes32 freeze =
            _fixtureContentFreeze(keccak256("SCRIPT"), router.artistContentFreezeState(1));
        _safeContentCall(
            relayer, keys, abi.encodeCall(router.applyArtistContentFreeze, (1, freeze))
        );
        (, bool locked) = router.artistContentLockState(1, keccak256("SCRIPT"));
        require(locked, "separate Safe applies actual defensive lock");
    }

    function _safeContentCall(OfficialSafe account, uint256[] memory keys, bytes memory data)
        private
    {
        require(executeSafe(account, keys, address(router), 0, data, 0), "Safe content CALL");
    }

    function _fixtureContentFreeze(bytes32 lockClass, bytes32 expected)
        private
        returns (bytes32 hash)
    {
        hash = keccak256(abi.encode("metadata boundary freeze", lockClass, expected));
        bytes32[] memory locks = new bytes32[](1);
        locks[0] = lockClass;
        artistRegistry.setContentFreeze(
            1,
            StreamArtistContentTypes.FreezeRecord(
                hash, keccak256("artist"), 1, address(router), locks, expected, 1
            )
        );
    }

    function testRealCoreMintRequestFulfillAndMetadata() public {
        uint256 tokenId = _mint();
        require(core.ownerOf(tokenId) == RECIPIENT, "real ERC721 minted");
        require(
            entropy.tokenEntropyStatus(tokenId) == StreamEntropyStatus.REGISTERED,
            "registered before external provider"
        );
        require(provider.nextRequestId() == 1, "registration never calls provider");
        _assertState(tokenId, "pending");
        provider.setFee(3);
        (bytes32 key, uint256 requestId) = entropy.requestEntropy{ value: 10 }(tokenId);
        require(
            entropy.entropyFeeCredit(address(this)) == 7 && entropy.totalFeeCredits() == 7,
            "excess remains payer credit"
        );
        require(provider.fulfill(requestId, bytes32(uint256(42))) == 0, "finalized");
        (bytes32 seed, bool finalized) = entropy.tokenSeed(tokenId);
        require(
            finalized && seed != 0 && entropy.pendingRequestCount() == 0,
            "final seed stored outside Core"
        );
        require(
            key != 0 && core.coordinatorAtMint(tokenId) == address(entropy),
            "request belongs to original coordinator"
        );
        _assertState(tokenId, "final");
        string memory json = router.tokenMetadataJSON(address(core), tokenId);
        require(
            keccak256(bytes(abi.decode(vm.parseJson(json, ".animation_url"), (string))))
                == keccak256("https://example.test/art/1"),
            "final animation"
        );
        require(
            keccak256(bytes(core.tokenURI(tokenId)))
                == keccak256(bytes(router.tokenURI(address(core), tokenId))),
            "real Core routes metadata"
        );
        entropy.claimEntropyFeeCredit(payable(address(this)));
        require(entropy.totalFeeCredits() == 0 && address(entropy).balance == 0, "credits cleared");
    }

    function testUnauthorizedCallbackAndReplayCannotChangeSeed() public {
        uint256 id = _mint();
        (bytes32 key, uint256 requestId) = entropy.requestEntropy(id);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.Unauthorized.selector, address(this))
        );
        entropy.fulfillEntropy(key, bytes32(uint256(4)));
        provider.fulfill(requestId, bytes32(0));
        (bytes32 original, bool finalized) = entropy.tokenSeed(id);
        require(finalized, "zero provider output is valid");
        require(provider.fulfill(requestId, bytes32(0)) == 3, "benign duplicate");
        (bytes32 afterSeed,) = entropy.tokenSeed(id);
        require(original == afterSeed, "seed immutable");
        vm.expectRevert();
        entropy.requestEntropy(id);
    }

    function testProviderIdCollisionRollsBackSecondRequest() public {
        entropy.requestEntropy(_mint());
        uint256 second = _mint();
        provider.setNextRequestId(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.ProviderRequestCollision.selector,
                address(provider),
                uint256(1)
            )
        );
        entropy.requestEntropy(second);
        require(
            entropy.tokenEntropyStatus(second) == StreamEntropyStatus.REGISTERED,
            "collision rollback"
        );
        require(entropy.pendingRequestCount() == 1, "pending unchanged");
        require(provider.fulfill(1, bytes32(uint256(42))) == 0, "first request survives");
    }

    function testRequestWindowRejectsSynchronousCallback() public {
        uint256 id = _mint();
        provider.setReenterOnRequest(true);
        vm.expectRevert();
        entropy.requestEntropy(id);
        require(
            entropy.tokenEntropyStatus(id) == StreamEntropyStatus.REGISTERED
                && entropy.pendingRequestCount() == 0,
            "atomic rollback"
        );
    }

    function testStaleAndFailureStatesDoNotAuthorizeReroll() public {
        uint256 staleId = _mint();
        (bytes32 staleKey, uint256 requestId) = entropy.requestEntropy(staleId);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.RequestNotExpired.selector));
        entropy.markRequestStale(staleKey);
        vm.roll(block.number + 11);
        entropy.markRequestStale(staleKey);
        _assertState(staleId, "stale");
        require(provider.fulfill(requestId, bytes32(uint256(1))) == 1, "late stale response");
        vm.expectRevert();
        entropy.requestEntropy(staleId);
        uint256 failedId = _mint();
        (bytes32 failedKey, uint256 failedRequest) = entropy.requestEntropy(failedId);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.ProviderFailureUnproven.selector)
        );
        entropy.markRequestFailed(failedKey);
        provider.fail(failedRequest);
        entropy.markRequestFailed(failedKey);
        _assertState(failedId, "failed");
        vm.expectRevert();
        entropy.requestEntropy(failedId);
    }

    function testRevokedProviderRetainsOutputAndCanDeliverSameResultAfterRestore() public {
        uint256 id = _mint();
        (bytes32 key, uint256 requestId) = entropy.requestEntropy(id);
        entropy.setProviderRevoked(address(provider), true);
        require(provider.fulfill(requestId, bytes32(uint256(7))) == 5, "revocation outcome");
        vm.roll(block.number + 11);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.ProviderOutputAlreadyReceived.selector)
        );
        entropy.markRequestStale(key);
        entropy.setProviderRevoked(address(provider), false);
        provider.retryCoordinatorFulfillment(requestId);
        _assertState(id, "final");
    }

    function testRouterUsesCoordinatorAtMintAfterPointerReplacementAndBurnKeepsSeed() public {
        uint256 id = _mint();
        (, uint256 requestId) = entropy.requestEntropy(id);
        StreamEntropyCoordinator next = new StreamEntropyCoordinator(StreamEntropyCoordinator.DeploymentConfig(
            address(core), address(this), address(roleRegistry), EntropyTimeTestConfigs.parameters(),
            MANIFEST, "ipfs://next", MANIFEST
        ));
        _install(ENTROPY, address(next), type(IStreamEntropyCoordinator).interfaceId);
        provider.fulfill(requestId, bytes32(uint256(12)));
        _assertState(id, "final");
        vm.prank(RECIPIENT);
        core.burn(id);
        (, bool finalized) = entropy.tokenSeed(id);
        require(finalized, "burn preserves canonical seed");
        vm.expectRevert();
        router.tokenURI(address(core), id);
    }

    function testScopeEntropySharesLifecycleButNotTokenIdentity() public {
        bytes32 scopeId = entropy.registerEntropyScope(1, 0, keccak256("sale-1"));
        (, uint256 requestId) = entropy.requestScopeEntropy(scopeId, keccak256("entries"));
        provider.fulfill(requestId, bytes32(uint256(15)));
        (bytes32 seed, bool finalized) = entropy.scopeSeed(scopeId);
        require(seed != 0 && finalized && core.totalSupply() == 0, "scope is not token");
        vm.expectRevert();
        entropy.requestScopeEntropy(scopeId, keccak256("changed entries"));
    }

    function testAuthorityAndPolicyFreezeAndWrongCore() public {
        _mint();
        vm.expectRevert();
        entropy.configureCollection(1, address(provider), 0, true, 10);
        vm.prank(RECIPIENT);
        vm.expectRevert();
        router.setCollectionScript(1, "bad");
        vm.expectRevert();
        entropy.onTokenMinted(1, 2, RECIPIENT, 0);
        vm.expectRevert();
        router.tokenURI(address(1), 1);
        require(
            !router.supportsInterface(0xffffffff) && !entropy.supportsInterface(0xffffffff),
            "ERC165 invalid"
        );
        require(
            router.supportsInterface(type(IStreamModule).interfaceId)
                && entropy.supportsInterface(type(IStreamEntropyView).interfaceId),
            "module and view interfaces"
        );
    }

    function testOnchainScriptOnlyAppearsAfterFinalEntropy() public {
        router.setCollectionScript(1, "document.body.textContent=tokenHash;");
        uint256 id = _mint();
        (, uint256 requestId) = entropy.requestEntropy(id);
        provider.fulfill(requestId, bytes32(uint256(4)));
        string memory json = router.tokenMetadataJSON(address(core), id);
        string memory animation = abi.decode(vm.parseJson(json, ".animation_url"), (string));
        require(bytes(animation).length > 100, "actual onchain HTML");
    }

    function testRatificationBlocksRenderMutationButKeepsExactContentAndEditorialEdits() public {
        router.setCollectionScript(1, "document.body.textContent=tokenHash;");
        (, bytes32 beforeHash) = router.currentArtistContentState(1);
        artistRegistry.setRatification(beforeHash);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, 1
            )
        );
        router.setCollectionScript(1, "document.body.textContent='changed';");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, 1
            )
        );
        router.setCollectionMetadata(1, "Name", "Description", "ipfs://changed", "");
        router.setCollectionScript(1, "document.body.textContent=tokenHash;");
        router.setCollectionMetadata(
            1, "Edited name", "Edited description", "ipfs://image", "https://example.test/art/"
        );
        (, bytes32 afterHash) = router.currentArtistContentState(1);
        require(afterHash == beforeHash, "ratified rendering inputs unchanged");
    }

    function testArtistBoundaryCannotStandInForActualMintConsent() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataArtistBoundary.MintConsentOutsideMetadataFixture.selector
            )
        );
        artistRegistry.requireMintConsent(1, keccak256("phase"), keccak256("policy"));
    }

    function testMetadataExposesAcceptedArtistEvidence() public {
        uint256 id = _mint();
        string memory json = router.tokenMetadataJSON(address(core), id);
        require(
            abi.decode(vm.parseJson(json, ".artist"), (address)) == RECIPIENT,
            "accepted artist address"
        );
        require(
            abi.decode(vm.parseJson(json, ".artist_acceptance_hash"), (bytes32))
                == artistRegistry.attribution(1).acceptanceHash,
            "artist acceptance evidence"
        );
        require(
            keccak256(bytes(core.tokenURI(id)))
                == keccak256(bytes(router.tokenURI(address(core), id))),
            "Core serves attributed metadata within configured gas"
        );
    }

    function testMaximumOnchainScriptFitsCoreMetadataBudget() public {
        bytes memory script = new bytes(8192);
        for (uint256 i; i < script.length; ++i) {
            script[i] = 0x20;
        }
        uint256 configurationGas = gasleft();
        router.setCollectionScript(1, string(script));
        configurationGas -= gasleft();
        emit log_named_uint("maximum ASCII script configuration gas", configurationGas);
        require(
            configurationGas < 14000000, "maximum script leaves configuration transaction headroom"
        );
        uint256 id = _mint();
        (, uint256 requestId) = entropy.requestEntropy(id);
        provider.fulfill(requestId, bytes32(uint256(4)));
        _coolMetadata();
        uint256 startGas = gasleft();
        string memory expected = router.tokenURI(address(core), id);
        emit log_named_uint("cold metadata gas", startGas - gasleft());
        emit log_named_uint("metadata URI bytes", bytes(expected).length);
        _coolMetadata();
        require(
            keccak256(bytes(core.tokenURI(id))) == keccak256(bytes(expected)),
            "largest admitted script must render through Core instead of fallback"
        );
    }

    function _coolMetadata() private {
        EntropyGasMeasurementVm(address(vm)).cool(address(router));
        EntropyGasMeasurementVm(address(vm)).cool(address(entropy));
        EntropyGasMeasurementVm(address(vm)).cool(address(artistRegistry));
        EntropyGasMeasurementVm(address(vm)).cool(address(core));
    }

    function testMaximumTokenDataScriptAndEscapedIdentityFitCoreResponse() public {
        // This is a real Core mint at its 16 KiB input maximum, with the largest router script
        // and admitted escaped identity. Compare Core's bounded read to the complete URI;
        // checking the router alone would miss either gas exhaustion or oversized fallback.
        string memory name = string(_repeatedByte(256, 0x4e));
        string memory description = string(_repeatedByte(2048, 0x22));
        string memory image = string(abi.encodePacked("ipfs://", _repeatedByte(761, 0x61)));
        router.setCollectionMetadata(1, name, description, image, "");
        bytes memory script = _repeatedByte(8192, 0x20);
        bytes memory endTag = bytes("</script");
        for (uint256 i; i < 1024; ++i) {
            for (uint256 j; j < 8; ++j) {
                script[i * 8 + j] = endTag[j];
            }
        }
        uint256 scriptConfigurationGas = gasleft();
        router.setCollectionScript(1, string(script));
        scriptConfigurationGas -= gasleft();
        emit log_named_uint("maximum escaped script configuration gas", scriptConfigurationGas);
        require(
            scriptConfigurationGas < 15000000, "escaped script fits one configuration transaction"
        );
        bytes memory data = _repeatedByte(16384, 0x31);
        (uint256 id,) =
            core.mintFromManager(1, RECIPIENT, data, keccak256(data), keccak256("maximum"));
        (, uint256 requestId) = entropy.requestEntropy(id);
        provider.fulfill(requestId, bytes32(uint256(4)));
        _coolMetadata();
        uint256 startGas = gasleft();
        string memory expected = router.tokenURI(address(core), id);
        uint256 gasUsed = startGas - gasleft();
        emit log_named_uint("maximum cold metadata gas", gasUsed);
        emit log_named_uint("maximum metadata URI bytes", bytes(expected).length);
        (uint256 metadataBudget,,,) = core.gasParameterInfo(
            0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93
        );
        require(gasUsed < metadataBudget, "maximum content fits the configured metadata budget");
        require(abi.encode(expected).length <= 65536, "complete URI fits Core response ceiling");
        _coolMetadata();
        startGas = gasleft();
        // Core reserves the full router allocation, EIP-150 overhead and its shared 2.91m
        // return buffer before calling the router. Exercise that complete bounded outer read.
        string memory actual = core.tokenURI{ gas: 16000000 }(id);
        emit log_named_uint("maximum cold Core tokenURI gas", startGas - gasleft());
        require(
            keccak256(bytes(actual)) == keccak256(bytes(expected)),
            "maximum content must reach collectors instead of Core fallback"
        );
        string memory json = router.tokenMetadataJSON(address(core), id);
        require(
            keccak256(bytes(abi.decode(vm.parseJson(json, ".description"), (string))))
                == keccak256(bytes(description)),
            "prepared identity round trips through valid JSON"
        );
        require(
            keccak256(bytes(abi.decode(vm.parseJson(json, ".token_data_location"), (string))))
                == keccak256("animation_url:tokenDataBase64"),
            "complete token data remains in onchain animation"
        );
    }

    function testEscapedIdentityAboveResponseEnvelopeRevertsAtomically() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.MetadataJSONLimitExceeded.selector,
                uint256(12289),
                uint256(5120)
            )
        );
        router.setCollectionMetadata(1, "n", string(_repeatedByte(2048, 0x01)), "", "");
        require(
            keccak256(bytes(router.collectionMetadata(1).description)) == keccak256("Description"),
            "configuration rollback"
        );
    }

    function _repeatedByte(uint256 length, bytes1 value)
        private
        pure
        returns (bytes memory result)
    {
        result = new bytes(length);
        for (uint256 i; i < length; ++i) {
            result[i] = value;
        }
    }

    function testFuzzPreparedScriptMatchesEstablishedEscaping(bytes memory data) public view {
        if (data.length > 512) return;
        string memory raw = string(abi.encodePacked(data, "</ScRiPt", data, "</script></scrip"));
        require(
            keccak256(bytes(NativeMetadataEncodingHarness(address(router)).prepareScript(raw)))
                == keccak256(bytes(StreamMetadataRenderer.escapeScriptElementEndTags(raw))),
            "optimized preparation preserves established escaping for mixed case and boundaries"
        );
    }

    function testRealCoreNativeVRFRequestCallbackAndFinalMetadata() public {
        MockVRFCoordinatorV2Plus upstream = new MockVRFCoordinatorV2Plus();
        StreamEntropyProviderVRF vrf = new StreamEntropyProviderVRF(
            StreamEntropyProviderVRF.Config({
                coordinator: address(entropy),
                authority: address(this),
                vrfCoordinator: address(upstream),
                subscriptionId: 1,
                keyHash: keccak256("VRF key"),
                requestConfirmations: 3,
                callbackGasLimit: 500000,
                maximumCallbackGasLimit: 2500000,
                nativePayment: true
            }),
            MANIFEST,
            "ipfs://local-vrf",
            MANIFEST
        );
        entropy.configureCollection(1, address(vrf), keccak256("collection-salt"), true, 10);
        uint256 tokenId = _mint();
        entropy.requestEntropy(tokenId);
        _assertState(tokenId, "pending");
        // Simulate a later upstream callback transaction with cold accounts and storage slots.
        EntropyGasMeasurementVm(address(vm)).cool(address(vrf));
        EntropyGasMeasurementVm(address(vm)).cool(address(entropy));
        EntropyGasMeasurementVm(address(vm)).cool(address(core));
        (bool callbackSucceeded, uint256 gasUsed) = upstream.fulfill(1, 42);
        require(callbackSucceeded, "actual provider callback budget");
        _assertState(tokenId, "final");
        (bytes32 seed, bool finalized) = entropy.tokenSeed(tokenId);
        require(
            finalized && seed != 0 && entropy.pendingRequestCount() == 0, "current Core finalized"
        );
        // The complete adapter persistence + coordinator + Core refresh callback must fit below
        // two-thirds of 500k, reserving headroom. This is local evidence, not fork-repricing proof.
        require(gasUsed < 333333, "VRF callback headroom");
        emit NativeVRFCallbackGasMeasured(gasUsed);
    }

    function testTerminalMetadataNotificationCanRetryAfterEmitterRecovery() public {
        uint256 tokenId = _mint();
        (bytes32 requestKey,) = entropy.requestEntropy(tokenId);
        bytes memory coreCode = address(core).code;
        UnavailableEntropyMetadataEmitter unavailable = new UnavailableEntropyMetadataEmitter();
        vm.etch(address(core), address(unavailable).code);
        vm.roll(block.number + 11);
        entropy.markRequestStale(requestKey);
        require(entropy.metadataNotificationPending(tokenId), "terminal refresh retained for retry");
        vm.etch(address(core), coreCode);
        entropy.retryMetadataNotification(tokenId);
        require(!entropy.metadataNotificationPending(tokenId), "terminal refresh delivered");
        _assertState(tokenId, "stale");
        require(entropy.pendingRequestCount() == 0, "retry cannot reactivate randomness");
    }

    function _mint() private returns (uint256 id) {
        (id,) = core.mintFromManager(
            1,
            RECIPIENT,
            bytes("artist-input"),
            keccak256("artist-input"),
            keccak256("mint-commitment")
        );
    }

    function _assertState(uint256 id, string memory expected) private view {
        string memory json = router.tokenMetadataJSON(address(core), id);
        require(
            keccak256(bytes(abi.decode(vm.parseJson(json, ".metadata_state"), (string))))
                == keccak256(bytes(expected)),
            "metadata state"
        );
    }

    function _install(bytes32 pointerType, address target, bytes4 interfaceId) private {
        registry.setRecord(target, pointerType, interfaceId, MANIFEST, MANIFEST);
        StreamCorePointerState memory previous = core.pointerState(pointerType);
        StreamCorePointerState memory candidate = StreamCorePointerState(
            target,
            target.codehash,
            false,
            pointerType,
            interfaceId,
            address(registry),
            uint8(ModuleRegistryStatus.ACTIVE),
            MANIFEST,
            MANIFEST,
            previous.revision + 1
        );
        (bytes32 scope, bytes32 oldValue, bytes32 newValue) =
            core.pointerTransitionHashes(pointerType, previous, candidate);
        executor.setAction(3, scope, oldValue, newValue);
        executor.execute(
            address(core), abi.encodeCall(core.updateSatellitePointer, (pointerType, target))
        );
    }
}
