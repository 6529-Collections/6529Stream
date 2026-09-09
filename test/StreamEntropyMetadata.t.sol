// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    PermanentTargetGovernanceExecutor,
    PermanentTargetModuleRegistry,
    PermanentTargetCoreHarness
} from "./StreamCorePermanentTarget.t.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./mocks/MockStreamEntropyProvider.sol";
import "../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../smart-contracts/core/StreamCore.sol";
import "../smart-contracts/core/StreamCoreExternalReads.sol";
import "../smart-contracts/interfaces/stream/IStreamMintManager.sol";

/// @notice Domain tests use the real permanent Core; only external actors/registry are fixtures.
contract StreamEntropyMetadataTest is CharacterizationTestBase {
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
    MockStreamEntropyProvider private provider;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamMintManager).interfaceId || id == 0x01ffc9a7;
    }
    receive() external payable { }

    function setUp() public {
        executor = new PermanentTargetGovernanceExecutor();
        registry = new PermanentTargetModuleRegistry();
        StreamCore.GasParameterGenesisConfig[] memory gasConfigs =
            new StreamCore.GasParameterGenesisConfig[](4);
        gasConfigs[0] = StreamCore.GasParameterGenesisConfig(
            0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda, 50000, 25000, 1
        );
        gasConfigs[1] = StreamCore.GasParameterGenesisConfig(
            0x0af6f5a1a5059e398191fa0af185be12fee6d609933826603244c7f247793be7, 2910000, 1460000, 1
        );
        gasConfigs[2] = StreamCore.GasParameterGenesisConfig(
            0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93, 2000000, 250000, 1
        );
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
        entropy = new StreamEntropyCoordinator(
            address(core), address(this), MANIFEST, "ipfs://local-test", MANIFEST
        );
        router = new StreamMetadataRouter(
            address(core), address(this), MANIFEST, "ipfs://local-test", MANIFEST
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
        entropy.configureCollection(1, address(provider), keccak256("collection-salt"), true, 10);
        router.setCollectionMetadata(
            1, 'Artist "Collection"', "Description", "ipfs://image", "https://example.test/art/"
        );
        vm.deal(address(this), 1 ether);
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
        StreamEntropyCoordinator next = new StreamEntropyCoordinator(
            address(core), address(this), MANIFEST, "ipfs://next", MANIFEST
        );
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
