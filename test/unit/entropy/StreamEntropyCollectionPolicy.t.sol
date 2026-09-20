// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "./EntropyCollectionPolicyFixtures.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamEntropyFreshRecovery as R
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";
import {
    IStreamEntropyRecoveryPolicies as RP
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import {
    IStreamRevealFeeEscrow as F
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";

/// @notice Actual Coordinator and workers with typed Core, Artist-evidence, role and provider seams.
/// @dev The executing authority models exact target-side context; this is not an actual Governor/Safe
///      or current-stack integration test, and Artist op17 signatures are covered by Artist suites.
contract StreamEntropyCollectionPolicyTest is
    CharacterizationTestBase,
    EntropyTimeAuthorityFixture
{
    bytes32 private constant HASH = keccak256("collection entropy policy unit");
    bytes32 private constant SALT = keccak256("declared collection salt");
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
    bytes32 private constant REVEAL_OWNER = keccak256("ROLE_ENTROPY_REVEAL_OWNER");
    bytes32 private constant ACTION = keccak256("collection policy action");
    bytes32 private constant CONSENT = keccak256("original op17 receipt fixture");

    EntropyCollectionPolicyCoreFixture private core;
    EntropyCollectionPolicyArtistFixture private artist;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    MockEntropyRoleRegistry public roleRegistry;
    P private policy;

    event CollectionEntropyPolicyConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed policyHash,
        uint64 revision,
        uint32 providerEpoch,
        P.PolicyInput input,
        bytes32 providerCodeHash,
        bytes32 providerConfigHash,
        bytes32 recoveryPolicyHash,
        bytes32 actionId,
        bytes32 artistConsentRecord
    );
    event CollectionEntropyPolicyFrozen(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed policyHash,
        uint64 revision,
        bytes32 actionId,
        bytes32 artistConsentRecord
    );
    event TokenEntropyPolicyRegistered(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bytes32 indexed policyHash,
        uint8 status
    );

    function setUp() public {
        vm.roll(100);
        core = new EntropyCollectionPolicyCoreFixture();
        artist = new EntropyCollectionPolicyArtistFixture(address(core));
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        roleRegistry.setHolder(keccak256("ROLE_ENTROPY_INCIDENT_DECLARER"), address(this));
        entropy = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                HASH,
                "urn:test:collection-policy",
                HASH
            )
        );
        core.wire(entropy, address(artist), address(new MockEntropyModuleRegistry(address(this))));
        policy = P(address(entropy));
        provider = new MockStreamEntropyProvider(address(entropy));
        _admitEntropyProvider(address(entropy), address(provider));
    }

    function testLegacyConfigTupleAndEpochOneAndTwoHashesRemainExact() public {
        _legacy(1);
        _assertLegacy(address(provider), 1);
        MockStreamEntropyProvider replacement = new MockStreamEntropyProvider(address(entropy));
        _admitEntropyProvider(address(entropy), address(replacement));
        entropy.configureCollection(1, address(replacement), SALT, true, 10);
        _assertLegacy(address(replacement), 2);
        require(entropy.supportsInterface(type(P).interfaceId), "missing additive capability");
        require(
            entropy.supportsInterface(type(IStreamEntropyCoordinator).interfaceId), "old capability"
        );
    }

    function testDisabledProviderZeroIsExplicitAndAbsentCollectionStillRejectsRegistration()
        public
    {
        P.PolicyRecord memory absent = policy.collectionEntropyPolicy(2);
        require(
            !absent.configured && !absent.explicitPolicy && absent.policyHash == 0,
            "absent declaration"
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.InvalidCollection.selector, 2)
        );
        core.registerToken(2, 2, HASH);
        require(core.collectionMintedEver(2) == 0, "absent mint rollback");

        P.PolicyInput memory input = _disabled();
        _authorize(1, input, ACTION, CONSENT);
        bytes32 h = _explicitHash(1, input, 0);
        vm.expectEmit(true, true, false, true);
        emit CollectionEntropyPolicyConfigured(2, 1, h, 1, 0, input, 0, 0, 0, ACTION, CONSENT);
        policy.configureCollectionEntropyPolicy(1, input);
        P.PolicyRecord memory declared = policy.collectionEntropyPolicy(1);
        require(
            declared.configured && declared.explicitPolicy && declared.policyHash == h,
            "explicit disabled"
        );
        require(
            declared.mode == P.Mode.DISABLED
                && declared.renderRequirement == P.RenderRequirement.NOT_REQUIRED,
            "disabled semantics"
        );
        require(declared.revision == 1 && declared.providerEpoch == 0, "provider-zero epoch");
        _assertLegacyFinalityUnavailable(1);
    }

    function testDisabledTokenRegistersTerminalWithoutProviderRequestOrNonterminalCount() public {
        _configure(1, _disabled(), ACTION, CONSENT);
        bytes32 h = policy.collectionEntropyPolicy(1).policyHash;
        vm.expectEmit(true, true, true, true);
        emit TokenEntropyPolicyRegistered(2, 1, 1, h, uint8(StreamEntropyStatus.DISABLED));
        core.registerToken(1, 1, HASH);
        _assertTerminal(1, StreamEntropyStatus.DISABLED, address(0));
        require(policy.collectionEntropyPolicy(1).frozen, "registration locks policy");
        require(
            provider.nextRequestId() == 1 && entropy.registeredAtBlock(1) == block.number,
            "registration only"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidSubject.selector,
                keccak256(abi.encode("TOKEN", uint256(1)))
            )
        );
        core.registerToken(1, 1, HASH);
        require(core.collectionMintedEver(1) == 1, "duplicate mint rollback");
        vm.expectRevert(abi.encodeWithSelector(P.UnsupportedEntropyMode.selector, P.Mode.DISABLED));
        entropy.registerEntropyScope(1, 0, HASH);
    }

    function testAsyncNotRequiredTokensAreTerminalButScopeStillRequestsAndFinalizes() public {
        P.PolicyInput memory input = _async();
        input.renderRequirement = P.RenderRequirement.NOT_REQUIRED;
        _configure(1, input, ACTION, CONSENT);
        core.registerToken(1, 1, HASH);
        core.registerToken(1, 2, HASH);
        _assertTerminal(1, StreamEntropyStatus.NOT_REQUIRED, address(provider));
        _assertTerminal(2, StreamEntropyStatus.NOT_REQUIRED, address(provider));
        bytes32 scope = entropy.registerEntropyScope(1, 0, HASH);
        require(
            entropy.scopeEntropy(scope).status == StreamEntropyStatus.REGISTERED,
            "scope remains asynchronous"
        );
        (bytes32 key, uint256 requestId) =
            entropy.requestScopeEntropy(scope, keccak256("scope inputs"));
        require(key != 0 && entropy.pendingRequestCount() == 1, "scope request exists");
        require(entropy.nonterminalTokenCount(1) == 0, "scope is not a token");
        require(provider.fulfill(requestId, HASH) == 0, "scope fulfillment");
        (bytes32 seed, bool finalized) = entropy.scopeSeed(scope);
        require(finalized && seed != 0 && entropy.pendingRequestCount() == 0, "scope finality");
        _assertTerminal(1, StreamEntropyStatus.NOT_REQUIRED, address(provider));
    }

    function testExplicitAsyncRequiredRetainsOrdinaryRequestAndTerminalCounterFlow() public {
        _configure(1, _async(), ACTION, CONSENT);
        core.registerToken(1, 1, HASH);
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REGISTERED, "registered async");
        require(entropy.nonterminalTokenCount(1) == 1, "one nonterminal token");
        (, uint256 requestId) = entropy.requestEntropy(1);
        require(provider.fulfill(requestId, HASH) == 0, "token fulfillment");
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.FINALIZED, "token finality");
        require(
            entropy.nonterminalTokenCount(1) == 0 && entropy.pendingRequestCount() == 0,
            "terminal counters"
        );
        _assertLegacyFinalityUnavailable(1);
    }

    function testConfigureRequiresExactExecutingClassOneActionAndOriginalCaller() public {
        P.PolicyInput memory input = _async();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 content) =
            policy.collectionEntropyPolicyTransition(1, input);
        artist.approve(1, address(entropy), FAMILY, content, CONSENT);
        for (uint256 field; field < 6; ++field) {
            this.setCurrentAction(
                field != 0,
                field == 1 ? bytes32(0) : ACTION,
                field == 2 ? 2 : 1,
                field == 3 ? HASH : scope,
                field == 4 ? HASH : oldHash,
                field == 5 ? HASH : newHash
            );
            vm.expectRevert(abi.encodeWithSelector(RP.FreshRecoveryPolicyInvalidContext.selector));
            policy.configureCollectionEntropyPolicy(1, input);
            require(!policy.collectionEntropyPolicy(1).configured, "context failure wrote state");
        }
        this.setCurrentAction(true, ACTION, 1, scope, oldHash, newHash);
        vm.prank(address(0xbad));
        vm.expectRevert(
            abi.encodeWithSelector(RP.FreshRecoveryPolicyUnauthorized.selector, address(0xbad))
        );
        policy.configureCollectionEntropyPolicy(1, input);
        policy.configureCollectionEntropyPolicy(1, input);
        require(policy.collectionEntropyPolicy(1).lastActionId == ACTION, "exact retry succeeds");
    }

    function testConfigureRequiresExactCollectionHostFamilyAndStateArtistReceipt() public {
        P.PolicyInput memory input = _async();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 content) =
            policy.collectionEntropyPolicyTransition(1, input);
        this.setCurrentAction(true, ACTION, 1, scope, oldHash, newHash);
        artist.approve(2, address(entropy), FAMILY, content, CONSENT);
        artist.approve(1, address(this), FAMILY, content, CONSENT);
        artist.approve(
            1, address(entropy), keccak256("6529STREAM_ENTROPY_RECOVERY_V1"), content, CONSENT
        );
        artist.approve(1, address(entropy), FAMILY, HASH, CONSENT);
        vm.expectRevert(abi.encodeWithSelector(P.CollectionPolicyArtistRequired.selector, 1));
        policy.configureCollectionEntropyPolicy(1, input);
        artist.approve(1, address(entropy), FAMILY, content, CONSENT);
        artist.setBound(false);
        vm.expectRevert(abi.encodeWithSelector(P.CollectionPolicyArtistRequired.selector, 1));
        policy.configureCollectionEntropyPolicy(1, input);
        artist.setBound(true);
        policy.configureCollectionEntropyPolicy(1, input);
        require(
            policy.collectionEntropyPolicy(1).artistConsentRecord == CONSENT, "bound exact receipt"
        );
    }

    function testSelectedCoordinatorAndSameCoreArtistAreMandatory() public {
        P.PolicyInput memory input = _async();
        _authorize(1, input, ACTION, CONSENT);
        core.setCoordinator(StreamEntropyCoordinator(payable(address(0))));
        vm.expectRevert(abi.encodeWithSelector(P.CollectionPolicyDependency.selector, address(0)));
        policy.configureCollectionEntropyPolicy(1, input);
        core.setCoordinator(entropy);
        EntropyCollectionPolicyArtistFixture foreignArtist =
            new EntropyCollectionPolicyArtistFixture(address(this));
        core.setArtist(address(foreignArtist));
        vm.expectRevert(
            abi.encodeWithSelector(P.CollectionPolicyDependency.selector, address(foreignArtist))
        );
        policy.configureCollectionEntropyPolicy(1, input);
        core.setArtist(address(artist));
        policy.configureCollectionEntropyPolicy(1, input);
    }

    function testMalformedArtistGasPolicyFailsClosedAndExactActionCanRetry() public {
        P.PolicyInput memory input = _async();
        _authorize(1, input, ACTION, CONSENT);
        artist.setReadBudget(0, 100000, 2, 1);
        _expectArtistDependency(input);
        artist.setReadBudget(type(uint256).max, 100000, 2, 1);
        _expectArtistDependency(input);
        artist.setReadBudget(100000, 200000, 2, 1);
        _expectArtistDependency(input);
        artist.setReadBudget(600000, 100000, 1, 1);
        _expectArtistDependency(input);
        artist.setReadBudget(600000, 100000, 2, 0);
        _expectArtistDependency(input);
        artist.setReadBudget(600000, 100000, 2, 1);
        policy.configureCollectionEntropyPolicy(1, input);
        require(
            policy.collectionEntropyPolicy(1).revision == 1, "failed admission consumed nothing"
        );
    }

    function testActionReplayIsCollectionScopedWhileArtistReceiptsAreGloballyConsumed() public {
        P.PolicyInput memory input = _async();
        _configure(1, input, ACTION, CONSENT);
        input.collectionSalt = HASH;
        bytes32 secondRecord = keccak256("second consent");
        _authorize(1, input, ACTION, secondRecord);
        vm.expectRevert(abi.encodeWithSelector(P.CollectionPolicyReplay.selector, ACTION));
        policy.configureCollectionEntropyPolicy(1, input);
        bytes32 secondAction = keccak256("second action");
        _authorize(1, input, secondAction, CONSENT);
        vm.expectRevert(abi.encodeWithSelector(P.CollectionPolicyReplay.selector, CONSENT));
        policy.configureCollectionEntropyPolicy(1, input);
        _authorize(1, input, secondAction, secondRecord);
        policy.configureCollectionEntropyPolicy(1, input);
        require(policy.collectionEntropyPolicy(1).revision == 2, "new exact receipts succeed");
        _authorize(2, input, ACTION, CONSENT);
        vm.expectRevert(abi.encodeWithSelector(P.CollectionPolicyReplay.selector, CONSENT));
        policy.configureCollectionEntropyPolicy(2, input);
        require(!policy.collectionEntropyPolicy(2).configured, "global receipt replay guard");
        _authorize(2, input, ACTION, keccak256("third consent"));
        policy.configureCollectionEntropyPolicy(2, input);
        require(
            policy.collectionEntropyPolicy(2).lastActionId == ACTION,
            "one governance batch can address distinct collections"
        );
    }

    function testCanonicalModuleRegistryMustSelectTheExecutingAuthority() public {
        P.PolicyInput memory input = _async();
        _authorize(1, input, ACTION, CONSENT);
        MockEntropyModuleRegistry foreignGovernance = new MockEntropyModuleRegistry(address(0xbad));
        core.wire(entropy, address(artist), address(foreignGovernance));
        vm.expectRevert(
            abi.encodeWithSelector(
                P.CollectionPolicyDependency.selector, address(foreignGovernance)
            )
        );
        policy.configureCollectionEntropyPolicy(1, input);
        require(!policy.collectionEntropyPolicy(1).configured, "foreign governance wrote policy");
        core.wire(entropy, address(artist), address(new MockEntropyModuleRegistry(address(this))));
        policy.configureCollectionEntropyPolicy(1, input);
    }

    function testFreezeRequiresClassTwoExactActionAndFreshBoundArtistConsent() public {
        _configure(1, _async(), ACTION, CONSENT);
        P.PolicyRecord memory previous = policy.collectionEntropyPolicy(1);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 content) =
            policy.freezeCollectionEntropyPolicyTransition(1);
        bytes32 freezeAction = keccak256("terminal freeze action");
        bytes32 freezeConsent = keccak256("terminal freeze consent");
        require(
            content == keccak256(abi.encode(FAMILY, previous.policyHash, true)),
            "frozen content commitment"
        );
        this.setCurrentAction(true, freezeAction, 1, scope, oldHash, newHash);
        artist.approve(1, address(entropy), FAMILY, content, freezeConsent);
        vm.expectRevert(abi.encodeWithSelector(RP.FreshRecoveryPolicyInvalidContext.selector));
        policy.freezeCollectionEntropyPolicy(1);
        this.setCurrentAction(true, freezeAction, 2, scope, oldHash, HASH);
        vm.expectRevert(abi.encodeWithSelector(RP.FreshRecoveryPolicyInvalidContext.selector));
        policy.freezeCollectionEntropyPolicy(1);
        this.setCurrentAction(true, freezeAction, 2, scope, oldHash, newHash);
        artist.approve(1, address(entropy), FAMILY, content, 0);
        vm.expectRevert(abi.encodeWithSelector(P.CollectionPolicyArtistRequired.selector, 1));
        policy.freezeCollectionEntropyPolicy(1);
        artist.approve(1, address(entropy), FAMILY, content, CONSENT);
        vm.expectRevert(abi.encodeWithSelector(P.CollectionPolicyReplay.selector, CONSENT));
        policy.freezeCollectionEntropyPolicy(1);
        artist.approve(1, address(entropy), FAMILY, content, freezeConsent);
        vm.expectEmit(true, true, false, true);
        emit CollectionEntropyPolicyFrozen(
            2, 1, previous.policyHash, 2, freezeAction, freezeConsent
        );
        policy.freezeCollectionEntropyPolicy(1);
        P.PolicyRecord memory frozen = policy.collectionEntropyPolicy(1);
        require(
            frozen.frozen && frozen.revision == 2 && frozen.policyHash == previous.policyHash,
            "freeze preserves H"
        );
        require(
            frozen.contentStateHash == content && frozen.lastActionId == freezeAction
                && frozen.artistConsentRecord == freezeConsent,
            "freeze receipt"
        );
        (bool supported, bytes32 current) = entropy.artistContentFamilyState(1, FAMILY);
        require(supported && current == content, "original Artist content read joins freeze");
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 1));
        policy.freezeCollectionEntropyPolicy(1);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 1));
        policy.configureCollectionEntropyPolicy(1, _disabled());
    }

    function testLegacyTokenRegistrationLocksOutExplicitDeclaration() public {
        _legacy(1);
        core.registerToken(1, 1, HASH);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 1));
        policy.configureCollectionEntropyPolicy(1, _async());
        require(!policy.collectionEntropyPolicy(1).explicitPolicy, "legacy identity retained");
    }

    function testLegacyScopeRegistrationLocksOutExplicitDeclaration() public {
        _legacy(1);
        entropy.registerEntropyScope(1, 0, HASH);
        require(core.collectionMintedEver(1) == 0, "scope-only lock");
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 1));
        policy.configureCollectionEntropyPolicy(1, _async());
    }

    function testCoreMintedEverAndCoreFreezeLockVirginCoordinatorPolicy() public {
        core.setMintedEver(1, 1);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 1));
        policy.configureCollectionEntropyPolicy(1, _async());
        core.freezeCollection(2);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 2));
        policy.configureCollectionEntropyPolicy(2, _async());
        require(
            !policy.collectionEntropyPolicy(1).configured
                && !policy.collectionEntropyPolicy(2).configured,
            "virgin state retained"
        );
    }

    function testExplicitPolicyRejectsAllThreeLegacyContentMutationEntrypoints() public {
        _configure(1, _async(), ACTION, CONSENT);
        vm.expectRevert(abi.encodeWithSelector(P.ExplicitCollectionPolicyRequired.selector, 1));
        entropy.configureCollection(1, address(provider), HASH, false, 11);
        vm.expectRevert(abi.encodeWithSelector(P.ExplicitCollectionPolicyRequired.selector, 1));
        entropy.configureCollectionRevealPolicy(1, 1, REVEAL_OWNER, 11, 0);
        vm.expectRevert(abi.encodeWithSelector(P.ExplicitCollectionPolicyRequired.selector, 1));
        entropy.configureCollectionFreshRecovery(1, 0, 0);
        require(policy.collectionEntropyPolicy(1).revision == 1, "legacy writes refused");
    }

    function testFundedRevealEscrowCannotBeStrandedByDisabledTransition() public {
        _configure(1, _async(), ACTION, CONSENT);
        bytes32 h = policy.collectionEntropyPolicy(1).policyHash;
        vm.deal(address(this), 2 ether);
        entropy.fundRevealFeeEscrow{ value: 1 ether }(1);
        vm.expectRevert(abi.encodeWithSelector(P.CollectionPolicyEscrowOutstanding.selector, 1));
        policy.configureCollectionEntropyPolicy(1, _disabled());
        require(policy.collectionEntropyPolicy(1).policyHash == h, "policy unchanged");
        require(
            entropy.revealFeeEscrow(1) == 1 ether && entropy.totalRevealFeeEscrows() == 1 ether,
            "escrow preserved"
        );
        require(address(entropy).balance == 1 ether, "custody preserved");
    }

    function testInstantModeReturnsTypedUnsupportedForBothSecurityClasses() public {
        P.PolicyInput memory input = _async();
        input.mode = P.Mode.INSTANT;
        vm.expectRevert(abi.encodeWithSelector(P.UnsupportedEntropyMode.selector, P.Mode.INSTANT));
        policy.configureCollectionEntropyPolicy(1, input);
        input.securityClass = P.SecurityClass.LOW_SECURITY;
        vm.expectRevert(abi.encodeWithSelector(P.UnsupportedEntropyMode.selector, P.Mode.INSTANT));
        policy.configureCollectionEntropyPolicy(1, input);
        require(!policy.collectionEntropyPolicy(1).configured, "unsupported never configured");
    }

    function testOperationalRevealFeeRetuneLeavesHArtistStateEpochAndFreezeUnchanged() public {
        P.PolicyInput memory input = _async();
        (,,, bytes32 noFeeContent) = policy.collectionEntropyPolicyTransition(1, input);
        input.reveal.revealFeePerTokenWei = 1 ether;
        (,,, bytes32 fundedContent) = policy.collectionEntropyPolicyTransition(1, input);
        require(noFeeContent == fundedContent, "fee excluded from Artist consent H");
        _configure(1, input, ACTION, CONSENT);
        _freeze(1, keccak256("freeze action"), keccak256("freeze consent"));
        P.PolicyRecord memory beforeFee = policy.collectionEntropyPolicy(1);
        provider.setFee(2 ether);
        entropy.updateRevealFeePerToken(1, 2 ether);
        P.PolicyRecord memory afterFee = policy.collectionEntropyPolicy(1);
        require(
            keccak256(abi.encode(beforeFee)) == keccak256(abi.encode(afterFee)),
            "operational fee changed policy record"
        );
        require(entropy.collectionRevealPolicy(1).revealFeePerTokenWei == 2 ether, "fee retuned");
        _assertLegacyFinalityUnavailable(1);
    }

    function testExplicitFreezeRequiresDeclaredPolicyAndDisabledShapeIsCanonical() public {
        _legacy(1);
        vm.expectRevert(abi.encodeWithSelector(P.ExplicitCollectionPolicyRequired.selector, 1));
        policy.freezeCollectionEntropyPolicy(1);
        P.PolicyInput memory input = _disabled();
        input.provider = address(provider);
        vm.expectRevert(abi.encodeWithSelector(P.InvalidCollectionPolicy.selector, 2));
        policy.configureCollectionEntropyPolicy(2, input);
        input = _disabled();
        input.renderRequirement = P.RenderRequirement.REQUIRED;
        vm.expectRevert(abi.encodeWithSelector(P.InvalidCollectionPolicy.selector, 2));
        policy.configureCollectionEntropyPolicy(2, input);
        input = _disabled();
        input.reveal.declared = true;
        vm.expectRevert(abi.encodeWithSelector(P.InvalidCollectionPolicy.selector, 2));
        policy.configureCollectionEntropyPolicy(2, input);
        _configure(2, _disabled(), ACTION, CONSENT);
        _freeze(2, keccak256("disabled freeze action"), keccak256("disabled freeze consent"));
        P.PolicyRecord memory frozen = policy.collectionEntropyPolicy(2);
        require(
            frozen.frozen && frozen.explicitPolicy && frozen.policyHash != 0,
            "disabled has explicit frozen V2 evidence"
        );
        _assertLegacyFinalityUnavailable(2);
    }

    function testConfigureRecoveryRevisionAndFreezeHashesMatchIndependentBeforeAfterPreimages()
        public
    {
        (bytes32 recoveryId, bytes32 recoveryHash) = _prepareRecoveryPolicy();
        P.PolicyInput memory first = _async();
        first.maxFreshRecoveryAttempts = 1;
        first.recoveryPolicyId = recoveryId;
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 content) =
            policy.collectionEntropyPolicyTransition(1, first);
        require(
            scope == _scope(1, P.configureCollectionEntropyPolicy.selector),
            "configure scope domain"
        );
        P.PolicyInput memory empty;
        require(oldHash == _expectedState(scope, empty, 0, 0, false, 0, 0), "virgin old state");
        require(
            newHash == _expectedState(scope, first, 1, 1, false, 1, recoveryHash),
            "first complete resulting state"
        );
        require(
            content
                == keccak256(abi.encode(FAMILY, _explicitHash(1, first, 1, recoveryHash), false)),
            "first content hash"
        );
        _configure(1, first, ACTION, CONSENT);
        require(
            entropy.collectionFreshRecovery(1).policyHash == recoveryHash, "actual recovery binding"
        );

        P.PolicyInput memory next = _async();
        (scope, oldHash, newHash, content) = policy.collectionEntropyPolicyTransition(1, next);
        require(
            oldHash == _expectedState(scope, first, 1, 1, false, 1, recoveryHash),
            "old recovery revision preserved"
        );
        require(
            newHash == _expectedState(scope, next, 2, 2, false, 2, 0),
            "unbound recovery epoch and revision"
        );
        require(oldHash != newHash, "distinct before and after");
        _configure(
            1, next, keccak256("remove recovery action"), keccak256("remove recovery consent")
        );
        require(entropy.collectionFreshRecovery(1).revision == 2, "recovery revision committed");

        (scope, oldHash, newHash, content) = policy.freezeCollectionEntropyPolicyTransition(1);
        require(
            scope == _scope(1, P.freezeCollectionEntropyPolicy.selector), "freeze selector domain"
        );
        require(
            oldHash == _expectedState(scope, next, 2, 2, false, 2, 0),
            "freeze original revision and unlocked config"
        );
        require(
            newHash == _expectedState(scope, next, 2, 3, true, 2, 0),
            "freeze new revision and locked config"
        );
        require(
            content == keccak256(abi.encode(FAMILY, _explicitHash(1, next, 2), true)),
            "frozen content hash"
        );
        _freeze(1, keccak256("independent freeze action"), keccak256("independent freeze consent"));
        require(
            policy.collectionEntropyPolicy(1).revision == 3,
            "one revision per successful transition"
        );
    }

    function testTypedCoreDeliveryCallbackObservesTerminalPolicyAndRejectionRollsBackExactRetry()
        public
    {
        // This drives the typed fixture's actual callback path, not the real Core's safeMint path.
        _configure(1, _disabled(), ACTION, CONSENT);
        _assertCallbackRollbackAndRetry(1, 1, StreamEntropyStatus.DISABLED);
        P.PolicyInput memory input = _async();
        input.renderRequirement = P.RenderRequirement.NOT_REQUIRED;
        _configure(
            2,
            input,
            keccak256("not-required callback action"),
            keccak256("not-required callback consent")
        );
        _assertCallbackRollbackAndRetry(2, 2, StreamEntropyStatus.NOT_REQUIRED);
        require(provider.nextRequestId() == 1, "delivery never requested provider randomness");
    }

    function testOriginalTerminalPolicyAndTokenReadsSurviveSelectedCoordinatorReplacement() public {
        P.PolicyInput memory input = _async();
        input.renderRequirement = P.RenderRequirement.NOT_REQUIRED;
        _configure(1, input, ACTION, CONSENT);
        core.registerToken(1, 1, HASH);
        P.PolicyRecord memory originalPolicy = policy.collectionEntropyPolicy(1);
        bytes memory query = abi.encodeCall(IStreamEntropyView.tokenEntropy, (1));
        (bool readOK, bytes memory originalToken) = address(entropy).staticcall(query);
        require(readOK && originalToken.length == 256, "original token tuple");
        StreamEntropyCoordinator successor = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                HASH,
                "urn:test:collection-policy-successor",
                HASH
            )
        );
        core.setCoordinator(successor);
        P nextPolicy = P(address(successor));
        require(!nextPolicy.collectionEntropyPolicy(1).configured, "new host has no declaration");
        (
            StreamEntropyStatus status,
            bytes32 seed,
            address p,,,
            bytes32 requestKey,
            uint256 requestId,
            uint16 attempt
        ) = successor.tokenEntropy(1);
        require(
            status == StreamEntropyStatus.NONE && seed == 0 && p == address(0) && requestKey == 0
                && requestId == 0 && attempt == 0,
            "new host cannot invent original token entropy"
        );
        (uint8 newRenderStatus, bytes32 newRenderSeed, address newRenderProvider) =
            successor.staticTokenRenderFacts(1);
        require(
            newRenderStatus == uint8(StreamEntropyStatus.NONE) && newRenderSeed == 0
                && newRenderProvider == address(0),
            "new host has no render facts"
        );
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.InvalidToken.selector, 1));
        successor.requestEntropy(1);
        vm.prank(address(core));
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.InvalidToken.selector, 1));
        successor.onTokenMinted(1, 1, address(0xbeef), HASH);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 1));
        nextPolicy.configureCollectionEntropyPolicy(1, _disabled());

        require(
            core.collectionMintedEver(1) == 1 && core.coordinatorAtMint(1) == address(entropy),
            "original mint identity retained"
        );
        require(
            keccak256(abi.encode(policy.collectionEntropyPolicy(1)))
                == keccak256(abi.encode(originalPolicy)),
            "old policy H and receipt retained"
        );
        (readOK, query) = address(entropy).staticcall(query);
        require(
            readOK && keccak256(query) == keccak256(originalToken), "old full token tuple retained"
        );
        (uint8 oldStatus, bytes32 oldSeed, address oldProvider) = entropy.staticTokenRenderFacts(1);
        require(
            oldStatus == uint8(StreamEntropyStatus.NOT_REQUIRED) && oldSeed == 0
                && oldProvider == address(provider),
            "old terminal render facts retained"
        );
        require(
            entropy.registeredAtBlock(1) == block.number && successor.registeredAtBlock(1) == 0,
            "registration belongs only to original host"
        );
    }

    function testArtistGasRevisionAboveUint64FailsClosedAndExactActionRetries() public {
        P.PolicyInput memory input = _async();
        _authorize(1, input, ACTION, CONSENT);
        bytes memory query = abi.encodeWithSignature(
            "gasParameterInfo(bytes32)", keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS")
        );
        EntropyCollectionPolicyVm(address(vm))
            .mockCall(
                address(artist),
                query,
                abi.encode(
                    uint256(600000), uint256(100000), uint256(2), uint256(type(uint64).max) + 1
                )
            );
        _expectArtistDependency(input);
        EntropyCollectionPolicyVm(address(vm))
            .mockCall(
                address(artist),
                query,
                abi.encode(uint256(600000), uint256(100000), uint256(2), uint256(1))
            );
        policy.configureCollectionEntropyPolicy(1, input);
        P.PolicyRecord memory r = policy.collectionEntropyPolicy(1);
        require(
            r.revision == 1 && r.lastActionId == ACTION && r.artistConsentRecord == CONSENT,
            "malformed revision consumed no action or consent"
        );
    }

    function _assertCallbackRollbackAndRetry(
        uint256 id,
        uint256 tokenId,
        StreamEntropyStatus status
    ) private {
        P.PolicyRecord memory beforeDelivery = policy.collectionEntropyPolicy(id);
        require(!beforeDelivery.frozen, "callback starts before registration lock");
        EntropyCollectionPolicyReceiverFixture receiver = new EntropyCollectionPolicyReceiverFixture(
            core, entropy, beforeDelivery.policyHash, status
        );
        bytes memory callData =
            abi.encodeCall(core.registerTokenWithCallback, (id, tokenId, HASH, address(receiver)));
        (bool ok, bytes memory result) = address(core).call(callData);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            EntropyCollectionPolicyReceiverFixture.PolicyReceiverRejected.selector,
                            beforeDelivery.policyHash,
                            uint8(status),
                            tokenId
                        )
                    ),
            "callback observed expected state then rejected"
        );
        require(
            keccak256(abi.encode(policy.collectionEntropyPolicy(id)))
                == keccak256(abi.encode(beforeDelivery)),
            "registration policy lock and H rollback"
        );
        (bool exists, uint256 collection,, bool burned) = core.tokenCollectionIdentity(tokenId);
        require(
            !exists && collection == 0 && !burned && core.coordinatorAtMint(tokenId) == address(0),
            "delivery identity rollback"
        );
        require(
            core.collectionMintedEver(id) == 0
                && core.tokenLifecycle(tokenId) == uint8(StreamTokenLifecycle.UNKNOWN),
            "delivery lifecycle rollback"
        );
        require(
            entropy.tokenEntropyStatus(tokenId) == StreamEntropyStatus.NONE
                && entropy.registeredAtBlock(tokenId) == 0,
            "entropy registration rollback"
        );
        require(
            entropy.nonterminalTokenCount(id) == 0 && entropy.pendingRequestCount() == 0
                && receiver.deliveries() == 0,
            "delivery counters rollback"
        );
        receiver.setReject(false);
        (ok,) = address(core).call(callData);
        require(ok, "byte-identical callback delivery retry");
        P.PolicyRecord memory delivered = policy.collectionEntropyPolicy(id);
        require(
            delivered.frozen && delivered.policyHash == beforeDelivery.policyHash
                && delivered.revision == beforeDelivery.revision,
            "retry locks original declared H"
        );
        require(
            core.collectionMintedEver(id) == 1 && receiver.deliveries() == 1, "retry committed once"
        );
        require(
            entropy.tokenEntropyStatus(tokenId) == status
                && entropy.registeredAtBlock(tokenId) == block.number,
            "retry committed terminal registration"
        );
    }

    function _async() private view returns (P.PolicyInput memory input) {
        input.mode = P.Mode.ASYNC;
        input.securityClass = P.SecurityClass.HIGH_ASSURANCE;
        input.renderRequirement = P.RenderRequirement.REQUIRED;
        input.provider = address(provider);
        input.collectionSalt = SALT;
        input.publicRequests = true;
        input.timeoutBlocks = 10;
        input.reveal = F.CollectionRevealPolicy(true, 0, REVEAL_OWNER, 10, 0);
    }

    function _disabled() private pure returns (P.PolicyInput memory input) {
        input.mode = P.Mode.DISABLED;
        input.securityClass = P.SecurityClass.HIGH_ASSURANCE;
        input.renderRequirement = P.RenderRequirement.NOT_REQUIRED;
    }

    function _legacy(uint256 id) private {
        entropy.configureCollection(id, address(provider), SALT, true, 10);
        entropy.configureCollectionRevealPolicy(id, 0, REVEAL_OWNER, 10, 0);
    }

    function _authorize(uint256 id, P.PolicyInput memory input, bytes32 action, bytes32 receipt)
        private
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 content) =
            policy.collectionEntropyPolicyTransition(id, input);
        artist.approve(id, address(entropy), FAMILY, content, receipt);
        this.setCurrentAction(true, action, 1, scope, oldHash, newHash);
    }

    function _configure(uint256 id, P.PolicyInput memory input, bytes32 action, bytes32 receipt)
        private
    {
        _authorize(id, input, action, receipt);
        policy.configureCollectionEntropyPolicy(id, input);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _freeze(uint256 id, bytes32 action, bytes32 receipt) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 content) =
            policy.freezeCollectionEntropyPolicyTransition(id);
        artist.approve(id, address(entropy), FAMILY, content, receipt);
        this.setCurrentAction(true, action, 2, scope, oldHash, newHash);
        policy.freezeCollectionEntropyPolicy(id);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _expectArtistDependency(P.PolicyInput memory input) private {
        vm.expectRevert(
            abi.encodeWithSelector(P.CollectionPolicyDependency.selector, address(artist))
        );
        policy.configureCollectionEntropyPolicy(1, input);
        require(!policy.collectionEntropyPolicy(1).configured, "malformed read wrote policy");
    }

    function _assertTerminal(
        uint256 tokenId,
        StreamEntropyStatus expected,
        address expectedProvider
    ) private {
        (
            StreamEntropyStatus status,
            bytes32 seed,
            address p,,,
            bytes32 key,
            uint256 requestId,
            uint16 attempt
        ) = entropy.tokenEntropy(tokenId);
        require(status == expected && seed == 0 && p == expectedProvider, "terminal token tuple");
        require(key == 0 && requestId == 0 && attempt == 0, "no terminal request");
        (bytes32 directSeed, bool finalized) = entropy.tokenSeed(tokenId);
        require(directSeed == 0 && !finalized, "terminal is not randomized finality");
        (uint8 renderStatus, bytes32 renderSeed, address renderProvider) =
            entropy.staticTokenRenderFacts(tokenId);
        require(
            renderStatus == uint8(expected) && renderSeed == 0
                && renderProvider == expectedProvider,
            "direct render tuple matches terminal record"
        );
        require(entropy.nonterminalTokenCount(1) == 0, "terminal token count");
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.InvalidStatus.selector, expected)
        );
        entropy.requestEntropy(tokenId);
        R.RecoveryInput memory recovery =
            R.RecoveryInput(key, "urn:test:terminal-not-rerollable", HASH);
        vm.expectRevert(abi.encodeWithSelector(R.FreshRecoveryUnavailable.selector, key));
        entropy.requestFreshEntropy(recovery);
        require(entropy.pendingRequestCount() == 0, "no pending request created");
    }

    function _assertLegacy(address selectedProvider, uint32 epoch) private view {
        (
            address p,
            bool publicRequests,
            bool locked,
            uint64 timeout,
            bytes32 configHash,
            bytes32 codeHash,
            bytes32 salt
        ) = entropy.collectionEntropyConfig(1);
        require(
            p == selectedProvider && publicRequests && !locked && timeout == 10 && salt == SALT,
            "legacy tuple terms"
        );
        require(
            codeHash == p.codehash
                && configHash == MockStreamEntropyProvider(p).streamEntropyProviderConfigHash(),
            "legacy provider identity"
        );
        bytes32 saltCommitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_SALT_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                SALT
            )
        );
        bytes32 providerPolicy = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SINGLE_PROVIDER_POLICY_V1"),
                p,
                codeHash,
                epoch,
                configHash,
                saltCommitment,
                true,
                uint64(10)
            )
        );
        bytes32 reveal = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_DECLARED_REVEAL_POLICY_V1"),
                uint8(0),
                REVEAL_OWNER,
                uint64(10)
            )
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FINALITY_POLICY_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                epoch == 1
                    ? keccak256("6529STREAM_ENTROPY_EPOCH1_NO_FRESH_RECOVERY_V1")
                    : keccak256("6529STREAM_ENTROPY_PREMINT_EPOCHS_NO_FRESH_RECOVERY_V1"),
                providerPolicy,
                reveal
            )
        );
        (
            bool frozen,
            bytes32 manifest,
            address finalProvider,
            uint32 finalEpoch,
            bytes32 finalSalt
        ) = entropy.entropyPolicyFrozen(1);
        require(
            !frozen && manifest == expected && finalProvider == p && finalEpoch == epoch
                && finalSalt == saltCommitment,
            "legacy five-word finality tuple"
        );
        P.PolicyRecord memory record = policy.collectionEntropyPolicy(1);
        require(
            record.configured && !record.explicitPolicy && record.revision == 0
                && record.policyHash == expected,
            "legacy additive read"
        );
        require(
            record.mode == P.Mode.ASYNC && record.securityClass == P.SecurityClass.HIGH_ASSURANCE
                && record.renderRequirement == P.RenderRequirement.REQUIRED,
            "legacy policy defaults"
        );
    }

    function _assertLegacyFinalityUnavailable(uint256 id) private view {
        // The old reader proves only the original legacy preimage. V2 callers must use PolicyRecord.
        (bool frozen, bytes32 h, address p, uint32 epoch, bytes32 salt) =
            entropy.entropyPolicyFrozen(id);
        require(
            !frozen && h == 0 && p == address(0) && epoch == 0 && salt == 0,
            "V2 never masquerades as legacy finality evidence"
        );
    }

    function _explicitHash(uint256 id, P.PolicyInput memory input, uint32 epoch)
        private
        view
        returns (bytes32)
    {
        return _explicitHash(id, input, epoch, bytes32(0));
    }

    function _explicitHash(
        uint256 id,
        P.PolicyInput memory input,
        uint32 epoch,
        bytes32 recoveryHash
    ) private view returns (bytes32) {
        bytes32 providerHash = input.provider == address(0) ? bytes32(0) : input.provider.codehash;
        bytes32 configHash = input.provider == address(0)
            ? bytes32(0)
            : MockStreamEntropyProvider(input.provider).streamEntropyProviderConfigHash();
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"),
                block.chainid,
                address(entropy),
                address(core),
                id,
                input.mode,
                input.securityClass,
                input.renderRequirement,
                input.provider,
                providerHash,
                configHash,
                epoch,
                input.collectionSalt,
                input.publicRequests,
                input.timeoutBlocks,
                input.reveal.declared,
                input.reveal.requestMode,
                input.reveal.revealOwnerRole,
                input.reveal.requestSLOBlocks,
                input.recoveryPolicyId,
                recoveryHash,
                input.maxFreshRecoveryAttempts
            )
        );
    }

    function _scope(uint256 id, bytes4 selector) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_SCOPE_V1"),
                block.chainid,
                address(entropy),
                address(core),
                id,
                selector
            )
        );
    }

    function _expectedState(
        bytes32 scope,
        P.PolicyInput memory input,
        uint32 epoch,
        uint64 revision,
        bool locked,
        uint64 recoveryRevision,
        bytes32 recoveryHash
    ) private view returns (bytes32) {
        StreamEntropyCoordinator.CollectionConfig memory config;
        config.provider = input.provider;
        config.publicRequests = input.publicRequests;
        config.locked = locked;
        config.timeoutBlocks = input.timeoutBlocks;
        config.collectionSalt = input.collectionSalt;
        if (input.provider != address(0)) {
            config.providerConfigHash =
                MockStreamEntropyProvider(input.provider).streamEntropyProviderConfigHash();
            config.providerCodeHash = input.provider.codehash;
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_STATE_V1"),
                scope,
                config,
                epoch,
                input.reveal,
                input.recoveryPolicyId,
                recoveryHash,
                input.maxFreshRecoveryAttempts,
                recoveryRevision,
                revision,
                input.mode,
                input.securityClass,
                input.renderRequirement,
                revision == 0 ? bytes32(0) : _explicitHash(1, input, epoch, recoveryHash)
            )
        );
    }

    function _prepareRecoveryPolicy() private returns (bytes32 id, bytes32 h) {
        id = keccak256("ordered collection recovery policy");
        bytes32 role = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
        RP.FreshRecoveryStep[] memory steps = new RP.FreshRecoveryStep[](1);
        steps[0] = RP.FreshRecoveryStep(
            address(provider), 5, provider.streamEntropyProviderConfigHash(), 10, false
        );
        h = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"),
                block.chainid,
                address(entropy),
                id,
                uint16(1),
                role,
                HASH,
                HASH,
                keccak256(
                    abi.encode(keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), steps)
                )
            )
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            entropy.freshRecoveryPolicyTransition(id, h, false);
        this.setCurrentAction(
            true, keccak256("recovery policy configure"), 1, scope, oldHash, newHash
        );
        entropy.configureFreshRecoveryPolicy(id, 1, role, HASH, HASH, steps);
        (scope, oldHash, newHash) = entropy.freshRecoveryPolicyTransition(id, h, true);
        this.setCurrentAction(true, keccak256("recovery policy freeze"), 1, scope, oldHash, newHash);
        entropy.freezeFreshRecoveryPolicy(id);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }
}
