// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamEntropySubjectIdentity.t.sol";
import "../../helpers/OfficialSafeFixture.sol";

/// @notice Actual coordinator timing and real Safe callers; Core, roles, provider and
///         in-flight governance context are explicit unit boundaries.
contract StreamEntropySLOTest is
    CharacterizationTestBase,
    OfficialSafeFixture,
    EntropyTimeAuthorityFixture
{
    bytes32 private constant MANIFEST = keccak256("entropy timing fixture");
    bytes32 private constant SLO = keccak256("6529STREAM_GTP_ENTROPY_REVEAL_SLO_BLOCKS");
    bytes32 private constant TIMEOUT = keccak256("6529STREAM_GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS");
    bytes32 private constant RECOVERY =
        keccak256("6529STREAM_GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS");
    bytes32 private constant OWNER_ROLE = keccak256("ROLE_ENTROPY_REVEAL_OWNER");
    EntropySubjectCoreFixture private core;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    MockEntropyRoleRegistry public roleRegistry;
    OfficialSafe private keeper;
    uint256[] private keys;

    function setUp() public {
        vm.roll(100);
        core = new EntropySubjectCoreFixture();
        core.setModuleRegistry(address(new MockEntropyModuleRegistry(address(this))));
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        entropy = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                MANIFEST,
                "urn:stream:fixture:timing",
                MANIFEST
            )
        );
        core.setCoordinator(entropy);
        provider = new MockStreamEntropyProvider(address(entropy));
        provider.setFee(100);
        entropy.configureCollection(1, address(provider), MANIFEST, false, 10);
        entropy.configureCollectionRevealPolicy(1, 1, OWNER_ROLE, 10, 100);
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        keeper = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 181);
        vm.deal(address(this), 1 ether);
        vm.deal(address(keeper), 1 ether);
    }

    function testCanonicalThreeParametersAndUnknownCollectionsHaveExactReads() public {
        bytes32[] memory ids = entropy.timeParameterIds();
        require(
            ids.length == 3 && ids[0] == TIMEOUT && ids[1] == SLO && ids[2] == RECOVERY,
            "closed ordered parameter inventory"
        );
        (uint256 value, uint256 floor, uint64 wallFloor, uint64 revision) =
            entropy.timeParameterInfo(SLO);
        require(
            value == 10 && floor == 5 && wallFloor == 60 && revision == 1,
            "immutable genesis intent"
        );
        require(entropy.governanceAuthority() == address(this), "same canonical authority");
        require(
            entropy.supportsInterface(type(IStreamTimeParameterHost).interfaceId)
                && entropy.supportsInterface(type(IStreamEntropyTiming).interfaceId),
            "complete capabilities"
        );
        require(
            executeSafe(
                keeper,
                keys,
                address(entropy),
                0,
                abi.encodeCall(entropy.effectiveRevealSLOBlocks, (1)),
                0
            ),
            "Safe timing read"
        );
        require(
            executeSafe(
                keeper,
                keys,
                address(entropy),
                0,
                abi.encodeCall(entropy.effectiveRequestTimeoutBlocks, (1)),
                0
            ),
            "Safe timeout read"
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealPolicyUndeclared.selector, 2)
        );
        entropy.effectiveRevealSLOBlocks(2);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.InvalidCollection.selector, 2)
        );
        entropy.effectiveRequestTimeoutBlocks(2);
    }

    function testMissingOrReorderedTimeConfigurationCannotDeploy() public {
        IStreamTimeParameterHost.TimeParameterConfig[3] memory configs =
            EntropyTimeTestConfigs.parameters();
        (configs[0], configs[1]) = (configs[1], configs[0]);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterInvalidConfig.selector, SLO
            )
        );
        new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                configs,
                MANIFEST,
                "urn:stream:fixture:wrong-timing",
                MANIFEST
            )
        );
        configs = EntropyTimeTestConfigs.parameters();
        configs[2].genesisValue = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTimeParameterHost.TimeParameterInvalidConfig.selector, RECOVERY
            )
        );
        new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                configs,
                MANIFEST,
                "urn:stream:fixture:missing-timing",
                MANIFEST
            )
        );
    }

    function testSafePermissionlessFallbackIsStrictlyAfterSLOAndUsesOnlyCollectionFunds() public {
        _register(1);
        entropy.fundRevealFeeEscrow{ value: 100 }(1);
        uint256 balance = address(keeper).balance;
        uint256 nonce = keeper.nonce();
        vm.roll(110);
        _expectKeeperRejection(1, 0);
        require(
            keeper.nonce() == nonce
                && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REGISTERED
                && provider.nextRequestId() == 1 && entropy.revealFeeEscrow(1) == 100,
            "equality is too early"
        );
        vm.roll(111);
        this.requestThroughKeeper(1, 0);
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REQUESTED
                && provider.nextRequestId() == 2 && entropy.revealFeeEscrow(1) == 0
                && address(keeper).balance == balance && address(provider).balance == 100,
            "unprivileged Safe requests at no value when collection covers quote"
        );
        provider.fulfill(1, keccak256("original raw"));
        (bytes32 seed, bool final_) = entropy.tokenSeed(1);
        require(final_ && seed != 0 && entropy.nonterminalTokenCount(1) == 0, "ordinary completion");
        _expectKeeperRejection(1, 0);
        require(provider.nextRequestId() == 2, "terminal subject cannot redraw");
    }

    function testLiveRaiseAfterRegistrationDelaysFallbackWithoutChangingFrozenPromise() public {
        _register(1);
        entropy.fundRevealFeeEscrow{ value: 100 }(1);
        vm.roll(109);
        _raise(SLO, 20);
        require(
            entropy.effectiveRevealSLOBlocks(1) == 20
                && entropy.collectionRevealPolicy(1).requestSLOBlocks == 10
                && entropy.registeredAtBlock(1) == 100,
            "operational raise preserves frozen identity"
        );
        vm.roll(111);
        _expectKeeperRejection(1, 0);
        vm.roll(120);
        _expectKeeperRejection(1, 0);
        vm.roll(121);
        this.requestThroughKeeper(1, 0);
        require(provider.nextRequestId() == 2, "new live window evaluated at request time");
    }

    function testMaturedFallbackSurvivesRoleOutageAndOriginalCoordinatorReplacement() public {
        _register(1);
        entropy.fundRevealFeeEscrow{ value: 100 }(1);
        core.setCoordinator(StreamEntropyCoordinator(address(provider)));
        core.setModuleRegistry(address(0));
        vm.roll(110);
        _expectKeeperRejection(1, 0);
        vm.roll(111);
        this.requestThroughKeeper(1, 0);
        provider.fulfill(1, keccak256("historical obligation"));
        (, bool final_) = entropy.tokenSeed(1);
        require(
            final_ && core.coordinatorAtMint(1) == address(entropy)
                && core.metadataNotifications() == 1,
            "historical pinned coordinator completes without role service"
        );
    }

    function testFallbackShortfallAndExcessKeepRequesterCreditsSeparate() public {
        _register(1);
        entropy.fundRevealFeeEscrow{ value: 60 }(1);
        vm.roll(111);
        _expectKeeperRejection(1, 39);
        require(
            entropy.revealFeeEscrow(1) == 60 && provider.nextRequestId() == 1, "underpayment atomic"
        );
        uint256 balance = address(keeper).balance;
        this.requestThroughKeeper(1, 55);
        require(
            entropy.revealFeeEscrow(1) == 0 && entropy.entropyFeeCredit(address(keeper)) == 15
                && entropy.totalFeeCredits() == 15 && address(entropy).balance == 15
                && address(provider).balance == 100 && address(keeper).balance == balance - 55,
            "fallback spends exact quote and credits only caller excess"
        );
        _expectKeeperRejection(1, 100);
        require(
            provider.nextRequestId() == 2 && entropy.totalFeeCredits() == 15,
            "requested token cannot redraw"
        );
    }

    function testLiveTimeoutRaiseAppliesToAlreadyRequestedTokensAndScopes() public {
        _register(1);
        entropy.fundRevealFeeEscrow{ value: 100 }(1);
        (bytes32 tokenKey,) = entropy.requestEntropy(1);
        bytes32 scope = entropy.registerEntropyScope(1, 0, keccak256("scope"));
        (bytes32 scopeKey,) =
            entropy.requestScopeEntropy{ value: 100 }(scope, keccak256("scope inputs"));
        _raise(TIMEOUT, 20);
        require(entropy.effectiveRequestTimeoutBlocks(1) == 20, "live timeout");
        vm.roll(120);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.RequestNotExpired.selector));
        entropy.markRequestStale(tokenKey);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.RequestNotExpired.selector));
        entropy.markRequestStale(scopeKey);
        vm.roll(121);
        entropy.markRequestStale(tokenKey);
        entropy.markRequestStale(scopeKey);
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.STALE
                && entropy.scopeEntropy(scope).status == StreamEntropyStatus.STALE
                && entropy.pendingRequestCount() == 0 && entropy.nonterminalTokenCount(1) == 0,
            "both identities use the same live timeout without fresh draws"
        );
    }

    function testFuzzFrozenCollectionWindowRemainsFloor(uint64 declared) public {
        uint64 window = uint64(uint256(declared) % 100_000 + 1);
        entropy.configureCollectionRevealPolicy(1, 1, OWNER_ROLE, window, 100);
        _register(1);
        _raise(SLO, 20);
        uint256 effective = window > 20 ? window : 20;
        require(
            entropy.effectiveRevealSLOBlocks(1) == effective, "max of declaration and live host"
        );
        entropy.fundRevealFeeEscrow{ value: 100 }(1);
        vm.roll(100 + effective);
        _expectKeeperRejection(1, 0);
        vm.roll(101 + effective);
        this.requestThroughKeeper(1, 0);
        require(provider.nextRequestId() == 2, "one draw only after both floors");
    }

    function testRequestBlockOverflowRejectsTokenAndScopeBeforeSpending() public {
        _register(1);
        bytes32 scope = entropy.registerEntropyScope(1, 0, keccak256("overflow scope"));
        entropy.fundRevealFeeEscrow{ value: 100 }(1);
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.EntropyBlockNumberOverflow.selector)
        );
        entropy.requestEntropy(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.EntropyBlockNumberOverflow.selector)
        );
        entropy.requestScopeEntropy{ value: 100 }(scope, keccak256("must roll back"));
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REGISTERED
                && entropy.scopeEntropy(scope).status == StreamEntropyStatus.REGISTERED
                && entropy.scopeEntropy(scope).inputsHash == 0 && entropy.pendingRequestCount() == 0
                && entropy.revealFeeEscrow(1) == 100 && provider.nextRequestId() == 1
                && address(provider).balance == 0 && entropy.totalFeeCredits() == 0,
            "unrepresentable request time rolls back every request and fee effect"
        );
    }

    function testMaximumLiveWindowNeverOverflowsOrStopsAuthorizedRequests() public {
        IStreamTimeParameterHost.TimeParameterConfig[3] memory configs =
            EntropyTimeTestConfigs.parameters();
        configs[1].genesisValue = type(uint256).max;
        entropy = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                configs,
                MANIFEST,
                "urn:stream:fixture:maximum-slo",
                MANIFEST
            )
        );
        core.setCoordinator(entropy);
        provider = new MockStreamEntropyProvider(address(entropy));
        provider.setFee(100);
        entropy.configureCollection(1, address(provider), MANIFEST, false, 10);
        entropy.configureCollectionRevealPolicy(1, 1, OWNER_ROLE, 10, 100);
        _register(1);
        entropy.fundRevealFeeEscrow{ value: 100 }(1);
        vm.roll(type(uint64).max);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.Unauthorized.selector, address(0xCAFE))
        );
        vm.prank(address(0xCAFE));
        entropy.requestEntropy(1);
        (bytes32 key,) = entropy.requestEntropy(1);
        (,,,, uint64 requestedAt,,) = entropy.requests(key);
        require(
            entropy.effectiveRevealSLOBlocks(1) == type(uint256).max
                && requestedAt == type(uint64).max && provider.nextRequestId() == 2,
            "large live window has no addition overflow and preserves authorized request time"
        );
    }

    function _register(uint256 tokenId) private {
        core.registerToken(tokenId, keccak256(abi.encode("commitment", tokenId)));
    }

    function _expectKeeperRejection(uint256 tokenId, uint256 value) private {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.requestThroughKeeper(tokenId, value);
    }

    function requestThroughKeeper(uint256 tokenId, uint256 value) external {
        require(msg.sender == address(this), "fixture caller");
        require(
            executeSafe(
                keeper,
                keys,
                address(entropy),
                value,
                abi.encodeCall(entropy.requestEntropy, (tokenId)),
                0
            ),
            "Safe request"
        );
    }

    function _raise(bytes32 id, uint256 next) private {
        (uint256 value, uint256 floor, uint64 wall, uint64 revision) = entropy.timeParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0xd14cc3d71aa1ccb50b6f723d516042b10a7ef31958f86ccb049a09dbcfefff24),
                block.chainid,
                address(entropy),
                id
            )
        );
        bytes32 domain = 0x26290762a61f3dda3fad05a62e5a95dcb1c59db2eaf506cb363c2aa2ab7b8384;
        bytes32 oldState = keccak256(abi.encode(domain, scope, value, floor, wall, revision));
        bytes32 newState = keccak256(abi.encode(domain, scope, next, floor, wall, revision + 1));
        this.setCurrentAction(
            true, keccak256(abi.encode(id, next, revision)), 1, scope, oldState, newState
        );
        entropy.raiseTimeParameter(id, next);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }
}
