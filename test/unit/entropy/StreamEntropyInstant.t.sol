// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "./EntropyInstantFixtures.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyProviderInstant.sol";
import {
    StreamEntropyInstantProviderReads as InstantReads
} from "../../../smart-contracts/domains/entropy/StreamEntropyInstantProviderReads.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamInstantEntropyProviderIdentity as II
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamInstantEntropyProviderIdentity.sol";
import {
    IStreamEntropyRecoveryPolicies as RP
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import {
    IStreamEntropyFreshRecovery as FR
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";
import {
    IStreamEntropyTerminalFacts as TerminalFacts
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyTerminalFacts.sol";

/// @notice Actual Coordinator/workers and optional production instant provider, with explicit typed
///         Core, Artist-evidence and executing-governance seams. No actual-current graph claim.
/// @dev The adversarial observer fixture has external reads; it is not a production provider candidate.
contract StreamEntropyInstantTest is CharacterizationTestBase, EntropyTimeAuthorityFixture {
    bytes32 private constant HASH = keccak256("instant entropy unit");
    bytes32 private constant SALT = keccak256("instant collection salt");
    bytes32 private constant COMMITMENT = keccak256("original signed mint commitment");
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
    EntropyCollectionPolicyCoreFixture private core;
    EntropyCollectionPolicyArtistFixture private artist;
    StreamEntropyCoordinator private entropy;
    StreamEntropyProviderInstant private instant;
    EntropyInstantProviderFixture private probe;
    MockEntropyRoleRegistry public roleRegistry;
    P private policy;

    event InstantEntropyProduced(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed providerRequestId,
        bytes32 rawRandomness,
        bytes32 provenanceHash,
        II.InstantMode mode,
        bytes32 assumptionsHash
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
                "urn:test:instant-entropy",
                HASH
            )
        );
        core.wire(entropy, address(artist), address(new MockEntropyModuleRegistry(address(this))));
        policy = P(address(entropy));
        instant = new StreamEntropyProviderInstant(address(entropy));
        probe = new EntropyInstantProviderFixture(entropy);
        _admitEntropyProvider(address(entropy), address(instant));
        _admitEntropyProvider(address(entropy), address(probe));
    }

    function testProductionInstantIdentityAndLowSecurityPolicyNeedNoAsyncRevealOrFee() public {
        require(
            instant.supportsInterface(type(IStreamInstantEntropyProvider).interfaceId),
            "instant capability"
        );
        require(instant.supportsInterface(type(II).interfaceId), "identity capability");
        require(
            !instant.supportsInterface(type(IStreamEntropyProvider).interfaceId),
            "no async capability claim"
        );
        require(!instant.supportsInterface(0xffffffff), "ERC165 invalid sentinel");
        (II.InstantMode mode, bytes32 assumptions) = instant.instantEntropyProfile();
        require(
            mode == II.InstantMode.DELAYED_BLOCKHASH && assumptions == instant.ASSUMPTIONS_HASH(),
            "explicit low-security assumptions"
        );
        _declare(address(instant), true);
        P.PolicyRecord memory p = policy.collectionEntropyPolicy(1);
        require(
            p.frozen && p.mode == P.Mode.INSTANT && p.securityClass == P.SecurityClass.LOW_SECURITY,
            "frozen low-security declaration"
        );
        require(
            p.policyHash != 0 && !entropy.collectionRevealPolicy(1).declared,
            "V2 H without async reveal"
        );
        P.PolicyInput memory changed = _input(address(instant), false);
        changed.collectionSalt = HASH;
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 1));
        policy.configureCollectionEntropyPolicy(1, changed);
        (bool frozen, bytes32 legacy, address provider, uint32 epoch, bytes32 salt) =
            entropy.entropyPolicyFrozen(1);
        require(
            !frozen && legacy == 0 && provider == address(0) && epoch == 0 && salt == 0,
            "legacy reader unavailable for V2"
        );
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
            entropy.gasParameterInfo(keccak256("6529STREAM_GGP_ENTROPY_INSTANT_READ_GAS_LIMIT"));
        require(
            value == 100000 && floor == 100000 && failure == 2 && revision == 1,
            "Coordinator hard-fail instant GGP"
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealPolicyUndeclared.selector, 1)
        );
        entropy.updateRevealFeePerToken(1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealPolicyUndeclared.selector, 1)
        );
        entropy.fundRevealFeeEscrow(1);
    }

    function testInstantPolicyRejectsEachAsyncTimeoutRevealAndRecoveryField() public {
        for (uint256 field; field < 8; ++field) {
            P.PolicyInput memory input = _input(address(instant), true);
            if (field == 0) input.timeoutBlocks = 1;
            if (field == 1) input.reveal.declared = true;
            if (field == 2) input.reveal.requestMode = 1;
            if (field == 3) input.reveal.revealOwnerRole = HASH;
            if (field == 4) input.reveal.requestSLOBlocks = 1;
            if (field == 5) input.reveal.revealFeePerTokenWei = 1;
            if (field == 6) input.maxFreshRecoveryAttempts = 1;
            if (field == 7) input.recoveryPolicyId = HASH;
            vm.expectRevert(abi.encodeWithSelector(P.InvalidCollectionPolicy.selector, 1));
            policy.configureCollectionEntropyPolicy(1, input);
        }
        require(!policy.collectionEntropyPolicy(1).configured, "invalid fields never declared");
    }

    function testOnlyDelayedBlockhashProfileIsAdmitted() public {
        P.PolicyInput memory input = _input(address(probe), true);
        for (uint256 mode; mode < 4; ++mode) {
            if (mode == 1) continue;
            probe.setProfile(mode, HASH);
            vm.expectRevert(
                abi.encodeWithSelector(InstantReads.InvalidInstantProvider.selector, address(probe))
            );
            policy.configureCollectionEntropyPolicy(1, input);
        }
        probe.setProfile(1, 0);
        vm.expectRevert(
            abi.encodeWithSelector(InstantReads.InvalidInstantProvider.selector, address(probe))
        );
        policy.configureCollectionEntropyPolicy(1, input);
        probe.setProfile(1, probe.ASSUMPTIONS());
        _declare(address(probe), true);
    }

    function testMintOnlyRegistersAndSameRegistrationBlockCannotRequestInstantEntropy() public {
        _declare(address(probe), true);
        probe.setResponse(EntropyInstantProviderFixture.Response.Reverting);
        (bytes32 expectedKey, uint256 expectedId, bytes memory context) = _identity(address(probe));
        probe.armObserver(expectedKey, 1, expectedId, keccak256(context));
        core.registerToken(1, 1, COMMITMENT);
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REGISTERED,
            "mint does not call instant provider"
        );
        require(
            entropy.nonterminalTokenCount(1) == 1 && entropy.pendingRequestCount() == 0,
            "registration counters only"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InstantEntropyBeforeDelivery.selector, 1
            )
        );
        entropy.requestEntropy(1);
        _assertPristine(address(probe));
        vm.roll(block.number + 1);
        probe.setResponse(EntropyInstantProviderFixture.Response.Normal);
        (bytes32 key, uint256 id) = entropy.requestEntropy(1);
        _assertFinal(address(probe), key, id, _fixtureRaw(address(probe)));
    }

    function testProductionProviderUsesExactOriginalRequestKeyAllocatedIdContextAndSeed() public {
        _register(address(instant));
        (bytes32 key, uint256 id, bytes memory context) = _identity(address(instant));
        uint256 sourceBlock = block.number - 1;
        bytes32 sourceHash = blockhash(sourceBlock);
        bytes32 raw = keccak256(
            abi.encode(
                keccak256("6529STREAM_INSTANT_BLOCKHASH_RAW_V1"),
                key,
                keccak256(context),
                sourceBlock,
                sourceHash
            )
        );
        bytes32 provenance = keccak256(
            abi.encode(
                keccak256("6529STREAM_INSTANT_BLOCKHASH_PROVENANCE_V1"),
                instant.streamEntropyProviderConfigHash(),
                key,
                keccak256(context),
                sourceBlock,
                sourceHash,
                instant.ASSUMPTIONS_HASH()
            )
        );
        vm.expectEmit(true, true, false, true);
        emit InstantEntropyProduced(
            1,
            key,
            id,
            raw,
            provenance,
            II.InstantMode.DELAYED_BLOCKHASH,
            instant.ASSUMPTIONS_HASH()
        );
        (bytes32 actualKey, uint256 actualId) = entropy.requestEntropy(1);
        require(actualKey == key && actualId == id, "literal request identity");
        _assertFinal(address(instant), key, id, raw);
        require(core.metadataNotifications() == 1, "successful synchronous metadata notification");
        require(
            entropy.scopeEntropy(keccak256(abi.encode("TOKEN", uint256(1)))).inputsHash
                == COMMITMENT,
            "original subject commitment retained"
        );
    }

    function testObserverSeesCompleteRequestedStateBeforeProfileAndEntropyStaticReads() public {
        _register(address(probe));
        (bytes32 key, uint256 id, bytes memory context) = _identity(address(probe));
        probe.armObserver(key, 1, id, keccak256(context));
        (bytes32 actualKey, uint256 actualId) = entropy.requestEntropy(1);
        require(actualKey == key && actualId == id, "observer request identity");
        _assertFinal(address(probe), key, id, _fixtureRaw(address(probe)));
    }

    function testMalformedFailedAndGasExhaustedInstantReadsRollbackAndExactRequestRetries() public {
        _register(address(probe));
        vm.deal(address(this), 2 ether);
        bytes memory callData = abi.encodeCall(entropy.requestEntropy, (1));
        for (
            uint256 mode = 1;
            mode <= uint256(EntropyInstantProviderFixture.Response.GasHeavy);
            ++mode
        ) {
            probe.setResponse(EntropyInstantProviderFixture.Response(mode));
            (bool ok, bytes memory result) = address(entropy).call{ value: 1 ether }(callData);
            require(
                !ok
                    && keccak256(result)
                        == keccak256(
                            abi.encodeWithSelector(
                                InstantReads.InstantEntropyReadFailed.selector, address(probe)
                            )
                        ),
                "exact malformed-read failure"
            );
            _assertPristine(address(probe));
        }
        probe.setResponse(EntropyInstantProviderFixture.Response.Normal);
        (bool accepted, bytes memory result) = address(entropy).call{ value: 1 ether }(callData);
        require(accepted, "byte-identical request retry");
        (bytes32 key, uint256 id) = abi.decode(result, (bytes32, uint256));
        _assertFinal(address(probe), key, id, _fixtureRaw(address(probe)));
        require(
            entropy.entropyFeeCredit(address(this)) == 1 ether
                && entropy.totalFeeCredits() == 1 ether,
            "only successful attempt credits"
        );
    }

    function testInvalidRequestTimeProfileRollsBackPrewrittenRequestIdentity() public {
        _register(address(probe));
        probe.setProfile(2, HASH);
        vm.expectRevert(
            abi.encodeWithSelector(InstantReads.InvalidInstantProvider.selector, address(probe))
        );
        entropy.requestEntropy(1);
        _assertPristine(address(probe));
        probe.setProfile(1, probe.ASSUMPTIONS());
        (bytes32 key, uint256 id) = entropy.requestEntropy(1);
        _assertFinal(address(probe), key, id, _fixtureRaw(address(probe)));
    }

    function testZeroRawRandomnessFinalizesAndDoesNotMeanMissingResult() public {
        _register(address(probe));
        probe.setZeroRaw(true);
        (bytes32 key, uint256 id) = entropy.requestEntropy(1);
        _assertFinal(address(probe), key, id, 0);
        (bytes32 seed, bool finalized) = entropy.tokenSeed(1);
        require(finalized && seed != 0, "zero raw is a finalized sample");
    }

    function testNoAsyncSubmissionOrCallbackIsNeededAndTerminalRequestsCannotRepeat() public {
        _register(address(probe));
        probe.setAttemptCallback(true);
        (bytes32 key, uint256 id) = entropy.requestEntropy(1);
        bytes32 raw = _fixtureRaw(address(probe));
        _assertFinal(address(probe), key, id, raw);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.FINALIZED
            )
        );
        entropy.requestEntropy(1);
        vm.prank(address(probe));
        require(
            entropy.fulfillEntropy(key, HASH) == 3, "late provider callback is a benign duplicate"
        );
        vm.expectRevert(abi.encodeWithSelector(FR.FreshRecoveryUnavailable.selector, key));
        entropy.requestFreshEntropy(FR.RecoveryInput(key, "urn:test:instant-no-reroll", HASH));
        _assertFinal(address(probe), key, id, raw);
        require(core.metadataNotifications() == 1, "no duplicate finality notification");
    }

    function testInstantCannotRegisterOrRequestScopeEntropy() public {
        _declare(address(instant), true);
        vm.expectRevert(abi.encodeWithSelector(P.UnsupportedEntropyMode.selector, P.Mode.INSTANT));
        entropy.registerEntropyScope(1, 0, HASH);
        core.registerToken(1, 1, COMMITMENT);
        bytes32 tokenKey = keccak256(abi.encode("TOKEN", uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.InvalidSubject.selector, tokenKey)
        );
        entropy.requestScopeEntropy(tokenKey, HASH);
        require(
            entropy.scopeEntropy(tokenKey).inputsHash == COMMITMENT,
            "scope entry cannot rewrite token inputs"
        );
    }

    function testFrozenProviderCodeConfigurationAndActiveStateRemainPinned() public {
        _register(address(probe));
        P.PolicyRecord memory original = policy.collectionEntropyPolicy(1);
        bytes32 originalConfig = probe.streamEntropyProviderConfigHash();
        probe.setConfigHash(HASH);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.ProviderConfigurationChanged.selector, address(probe)
            )
        );
        entropy.requestEntropy(1);
        probe.setConfigHash(originalConfig);
        _assertPristine(address(probe));
        bytes memory originalCode = address(probe).code;
        vm.etch(address(probe), hex"60006000fd");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEntropyProviderLifecycle.EntropyProviderUnavailable.selector,
                address(probe),
                EntropyProviderState.ACTIVE
            )
        );
        entropy.requestEntropy(1);
        vm.etch(address(probe), originalCode);
        _setEntropyProviderRevoked(address(entropy), address(probe), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEntropyProviderLifecycle.EntropyProviderUnavailable.selector,
                address(probe),
                EntropyProviderState.INCIDENT_REVOKED
            )
        );
        entropy.requestEntropy(1);
        _setEntropyProviderRevoked(address(entropy), address(probe), false);
        require(
            keccak256(abi.encode(policy.collectionEntropyPolicy(1)))
                == keccak256(abi.encode(original)),
            "operational admission failures never rewrite frozen H"
        );
        _assertPristine(address(probe));
        (bytes32 key, uint256 id) = entropy.requestEntropy(1);
        _assertFinal(address(probe), key, id, _fixtureRaw(address(probe)));
    }

    function testAllSuppliedValueIsPullCreditAndProviderReceivesZero() public {
        _register(address(instant));
        vm.deal(address(this), 2 ether);
        entropy.requestEntropy{ value: 2 ether }(1);
        require(
            entropy.entropyFeeCredit(address(this)) == 2 ether
                && entropy.totalFeeCredits() == 2 ether,
            "full zero-fee credit"
        );
        require(
            address(entropy).balance == 2 ether && address(instant).balance == 0,
            "no provider payment"
        );
        require(
            entropy.revealFeeEscrow(1) == 0 && entropy.totalRevealFeeEscrows() == 0,
            "no async escrow draw"
        );
        address payable destination = payable(address(0xcafe));
        uint256 prior = destination.balance;
        entropy.claimEntropyFeeCredit(destination);
        require(
            destination.balance == prior + 2 ether && entropy.entropyFeeCredit(address(this)) == 0
                && entropy.totalFeeCredits() == 0,
            "pull credit settles once"
        );
        require(address(entropy).balance == 0, "coordinator liabilities discharged");
    }

    function testRequestAccessUsesPublicOrRegisteredCallerWithoutAsyncRevealFallback() public {
        _declare(address(instant), false);
        core.registerToken(1, 1, COMMITMENT);
        vm.roll(block.number + 100);
        address requester = address(0x1234);
        vm.prank(requester);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.Unauthorized.selector, requester)
        );
        entropy.requestEntropy(1);
        entropy.setRequester(requester, true);
        vm.prank(requester);
        entropy.requestEntropy(1);
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.FINALIZED,
            "registered caller needs no reveal policy"
        );
    }

    function testOriginalCoordinatorFinalizesAndRetainsReadsAfterCoreSelectionChanges() public {
        _register(address(instant));
        P.PolicyRecord memory original = policy.collectionEntropyPolicy(1);
        StreamEntropyCoordinator next = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                HASH,
                "urn:test:instant-successor",
                HASH
            )
        );
        core.setCoordinator(next);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.InvalidToken.selector, 1));
        next.requestEntropy(1);
        (bytes32 key, uint256 id) = entropy.requestEntropy(1);
        (,,,,,, bytes32 raw) = entropy.requests(key);
        _assertFinal(address(instant), key, id, raw);
        require(core.coordinatorAtMint(1) == address(entropy), "original token host");
        require(
            keccak256(abi.encode(policy.collectionEntropyPolicy(1)))
                == keccak256(abi.encode(original)),
            "original policy H retained"
        );
        require(
            next.tokenEntropyStatus(1) == StreamEntropyStatus.NONE, "new host has no token record"
        );
        (uint8 status, bytes32 seed, address provider) = entropy.staticTokenRenderFacts(1);
        require(
            status == uint8(StreamEntropyStatus.FINALIZED)
                && seed == _seed(address(instant), key, id, raw) && provider == address(instant),
            "original static facts retained"
        );
    }

    function testChangingMintCommitmentCannotChangeInstantContextRawIdentityOrSeed() public {
        _declare(address(probe), true);
        uint256 snapshot = vm.snapshotState();
        core.registerToken(1, 1, COMMITMENT);
        vm.roll(block.number + 1);
        (bytes32 firstKey, uint256 firstId) = entropy.requestEntropy(1);
        (bytes32 firstSeed,) = entropy.tokenSeed(1);
        (,,,,,, bytes32 firstRaw) = entropy.requests(firstKey);
        require(
            firstRaw == _fixtureRaw(address(probe)), "literal normalized first provider context"
        );
        require(
            entropy.requestPolicySnapshot(firstKey).inputsHash == 0,
            "snapshot excludes original commitment"
        );
        require(vm.revertToState(snapshot), "paired same-token scenario");
        bytes32 changed = keccak256("executor chosen alternate mint commitment");
        core.registerToken(1, 1, changed);
        vm.roll(block.number + 1);
        (bytes32 secondKey, uint256 secondId) = entropy.requestEntropy(1);
        (bytes32 secondSeed,) = entropy.tokenSeed(1);
        (,,,,,, bytes32 secondRaw) = entropy.requests(secondKey);
        require(
            firstKey == secondKey && firstId == secondId && firstRaw == secondRaw
                && firstSeed == secondSeed,
            "commitment cannot grind instant result"
        );
        require(
            entropy.requestPolicySnapshot(secondKey).inputsHash == 0, "normalized second snapshot"
        );
        require(
            entropy.scopeEntropy(keccak256(abi.encode("TOKEN", uint256(1)))).inputsHash == changed,
            "original subject still records changed commitment"
        );
    }

    function testMetadataFailurePreservesFinalityAndRetryNeverCallsProviderAgain() public {
        _register(address(probe));
        (bytes32 key, uint256 id,) = _identity(address(probe));
        EntropyInstantVm(address(vm))
            .mockCallRevert(
                address(core),
                abi.encodeCall(core.emitMetadataUpdate, (1, key)),
                abi.encodeWithSignature("Error(string)", "metadata unavailable")
            );
        entropy.requestEntropy(1);
        bytes32 raw = _fixtureRaw(address(probe));
        _assertFinal(address(probe), key, id, raw);
        require(
            entropy.metadataNotificationPending(1) && core.metadataNotifications() == 0,
            "only metadata remains pending"
        );
        probe.setResponse(EntropyInstantProviderFixture.Response.Reverting);
        EntropyInstantVm(address(vm)).clearMockedCalls();
        entropy.retryMetadataNotification(1);
        require(
            !entropy.metadataNotificationPending(1) && core.metadataNotifications() == 1,
            "metadata repair succeeds without entropy reread"
        );
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.InvalidToken.selector, 1));
        entropy.retryMetadataNotification(1);
        _assertFinal(address(probe), key, id, raw);
    }

    function testAsyncFreshRecoveryPolicyCannotAdmitAnInstantProviderStep() public {
        bytes32 id = keccak256("async policy cannot select instant fallback");
        bytes32 role = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
        RP.FreshRecoveryStep[] memory steps = new RP.FreshRecoveryStep[](1);
        steps[0] = RP.FreshRecoveryStep(
            address(instant), 2, instant.streamEntropyProviderConfigHash(), 10, false
        );
        bytes32 h = keccak256(
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
        this.setCurrentAction(true, HASH, 1, scope, oldHash, newHash);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidDependency.selector, address(instant)
            )
        );
        entropy.configureFreshRecoveryPolicy(id, 1, role, HASH, HASH, steps);
        (RP.FreshRecoveryPolicy memory result,,,) = entropy.freshRecoveryPolicy(id);
        require(!result.exists, "instant fallback was not admitted as async");
    }

    function testClassTwoReadRejectsLowParentBudgetEvenWhenCheapProviderWouldSucceed() public {
        EntropyInstantReadBudgetHarness harness = new EntropyInstantReadBudgetHarness(address(this));
        EntropyInstantCheapReadFixture cheap = new EntropyInstantCheapReadFixture();
        bytes memory context = abi.encode(HASH);
        (bool directOK, bytes memory directResult) = address(cheap).staticcall{ gas: 60000 }(
            abi.encodeCall(cheap.instantEntropy, (HASH, context))
        );
        require(
            directOK && keccak256(directResult) == keccak256(abi.encode(HASH, keccak256(context))),
            "cheap provider succeeds under the small budget"
        );
        bytes memory query = abi.encodeCall(harness.read, (address(cheap), HASH, context));
        (bool lowOK, bytes memory lowResult) = address(harness).staticcall{ gas: 60000 }(query);
        require(
            !lowOK
                && keccak256(lowResult)
                    == keccak256(
                        abi.encodeWithSelector(
                            InstantReads.InstantEntropyReadFailed.selector, address(cheap)
                        )
                    ),
            "class-two shortfall is a typed failure before cheap read"
        );
        (bool healthyOK, bytes memory healthyResult) =
            address(harness).staticcall{ gas: 300000 }(query);
        require(
            healthyOK && keccak256(healthyResult) == keccak256(directResult),
            "complete current cap can be forwarded"
        );
    }

    function testNearUint256GovernedReadCapFailsClosedWithoutArithmeticOverflow() public {
        EntropyInstantReadBudgetHarness harness = new EntropyInstantReadBudgetHarness(address(this));
        EntropyInstantCheapReadFixture cheap = new EntropyInstantCheapReadFixture();
        bytes32 parameterId = keccak256("6529STREAM_GGP_ENTROPY_INSTANT_READ_GAS_LIMIT");
        bytes32 namespace = keccak256("6529STREAM_ENTROPY_INCIDENT_PARAMETERS_STORAGE_V1");
        // Numeric-boundary fixture only: seed the prior value, then exercise one real governed raise.
        // This does not claim to traverse the sequence of permitted raises from genesis.
        vm.store(
            address(harness),
            keccak256(abi.encode(parameterId, namespace)),
            bytes32(uint256(1) << 255)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = harness.transition(type(uint256).max);
        this.setCurrentAction(
            true, keccak256("near-uint governed read cap"), 1, scope, oldHash, newHash
        );
        harness.raise(type(uint256).max);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = harness.parameter();
        require(
            value == type(uint256).max && floor == 100000 && failure == 2 && revision == 2,
            "governed boundary value committed"
        );
        (bool ok, bytes memory result) = address(harness).staticcall{ gas: 300000 }(
            abi.encodeCall(harness.read, (address(cheap), HASH, bytes("")))
        );
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            InstantReads.InstantEntropyReadFailed.selector, address(cheap)
                        )
                    ),
            "near-uint cap fails closed without Panic"
        );
    }

    function testStaticTerminalFactsTruthfullyReturnInstantRegisteredAndFinalizedStates() public {
        _register(address(instant));
        P.PolicyRecord memory p = policy.collectionEntropyPolicy(1);
        bytes memory query = abi.encodeCall(TerminalFacts.staticTerminalEntropyFacts, (1));
        (bool ok, bytes memory beforeRequest) = address(entropy).staticcall(query);
        require(
            ok && beforeRequest.length == 512
                && keccak256(beforeRequest)
                    == keccak256(
                        abi.encode(
                            uint256(1),
                            p,
                            uint8(StreamEntropyStatus.REGISTERED),
                            bytes32(0),
                            bytes32(0)
                        )
                    ),
            "truthful REGISTERED static facts"
        );
        (bytes32 key,) = entropy.requestEntropy(1);
        (bytes32 seed, bool finalized) = entropy.tokenSeed(1);
        require(finalized, "instant request finalized");
        (ok, beforeRequest) = address(entropy).staticcall(query);
        require(
            ok && beforeRequest.length == 512
                && keccak256(beforeRequest)
                    == keccak256(
                        abi.encode(uint256(1), p, uint8(StreamEntropyStatus.FINALIZED), seed, key)
                    ),
            "truthful FINALIZED static facts without status filtering"
        );
    }

    function _input(address provider, bool publicRequests)
        private
        pure
        returns (P.PolicyInput memory p)
    {
        p.mode = P.Mode.INSTANT;
        p.securityClass = P.SecurityClass.LOW_SECURITY;
        p.renderRequirement = P.RenderRequirement.REQUIRED;
        p.provider = provider;
        p.collectionSalt = SALT;
        p.publicRequests = publicRequests;
    }

    function _declare(address provider, bool publicRequests) private {
        P.PolicyInput memory p = _input(provider, publicRequests);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 content) =
            policy.collectionEntropyPolicyTransition(1, p);
        artist.approve(
            1, address(entropy), FAMILY, content, keccak256("instant op17 configuration receipt")
        );
        this.setCurrentAction(
            true, keccak256("instant configure action"), 1, scope, oldHash, newHash
        );
        policy.configureCollectionEntropyPolicy(1, p);
        (scope, oldHash, newHash, content) = policy.freezeCollectionEntropyPolicyTransition(1);
        artist.approve(
            1, address(entropy), FAMILY, content, keccak256("instant op17 freeze receipt")
        );
        this.setCurrentAction(true, keccak256("instant freeze action"), 2, scope, oldHash, newHash);
        policy.freezeCollectionEntropyPolicy(1);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _register(address provider) private {
        _declare(provider, true);
        core.registerToken(1, 1, COMMITMENT);
        vm.roll(block.number + 1);
    }

    function _identity(address provider)
        private
        view
        returns (bytes32 key, uint256 id, bytes memory context)
    {
        bytes32 config = II(provider).streamEntropyProviderConfigHash();
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_REQUEST_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                uint256(1),
                provider,
                uint32(1),
                config,
                uint16(1)
            )
        );
        id = uint256(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_INSTANT_PROVIDER_REQUEST_V1"),
                    key,
                    uint16(1),
                    provider,
                    uint32(1),
                    config
                )
            )
        );
        context = abi.encode(
            uint16(1),
            address(core),
            uint256(1),
            uint256(1),
            bytes32(0),
            uint32(1),
            config,
            uint16(1),
            bytes32(0)
        );
    }

    function _fixtureRaw(address provider) private view returns (bytes32) {
        (bytes32 key,, bytes memory context) = _identity(provider);
        return keccak256(abi.encode(probe.RAW_DOMAIN(), key, keccak256(context)));
    }

    function _seed(address provider, bytes32 key, uint256 id, bytes32 raw)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SEED_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                bytes32(uint256(1)),
                provider,
                uint32(1),
                II(provider).streamEntropyProviderConfigHash(),
                key,
                id,
                raw,
                SALT,
                bytes32(0)
            )
        );
    }

    function _assertFinal(address provider, bytes32 key, uint256 id, bytes32 raw) private view {
        (bytes32 expectedKey, uint256 expectedId,) = _identity(provider);
        require(key == expectedKey && id == expectedId, "deterministic request ID");
        (
            StreamEntropyStatus status,
            bytes32 seed,
            address selected,
            uint32 epoch,
            bytes32 config,
            bytes32 savedKey,
            uint256 savedId,
            uint16 attempt
        ) = entropy.tokenEntropy(1);
        require(
            status == StreamEntropyStatus.FINALIZED && seed == _seed(provider, key, id, raw),
            "single synchronous final seed"
        );
        require(
            selected == provider && epoch == 1
                && config == II(provider).streamEntropyProviderConfigHash() && savedKey == key
                && savedId == id && attempt == 1,
            "original final token tuple"
        );
        IStreamEntropyEpochs.RequestPolicySnapshot memory p = entropy.requestPolicySnapshot(key);
        require(
            p.provider == provider && p.providerCodeHash == provider.codehash && p.inputsHash == 0
                && p.collectionSalt == SALT,
            "frozen normalized policy snapshot"
        );
        (,,,,, uint256 requestId, bytes32 savedRaw) = entropy.requests(key);
        require(
            requestId == id && savedRaw == raw && entropy.providerRequestKeys(provider, id) == key,
            "request and reverse binding"
        );
        require(
            entropy.pendingRequestCount() == 0 && entropy.nonterminalTokenCount(1) == 0,
            "synchronous terminal counters"
        );
    }

    function _assertPristine(address provider) private view {
        (bytes32 key, uint256 id,) = _identity(provider);
        (
            StreamEntropyStatus status,
            bytes32 seed,,,,
            bytes32 savedKey,
            uint256 savedId,
            uint16 attempt
        ) = entropy.tokenEntropy(1);
        require(
            status == StreamEntropyStatus.REGISTERED && seed == 0 && savedKey == 0 && savedId == 0
                && attempt == 0,
            "pre-request token restored"
        );
        (
            bytes32 subject,
            uint256 tokenId,
            bytes32 scope,
            address selected,
            uint64 requestedAt,
            uint256 requestId,
            bytes32 raw
        ) = entropy.requests(key);
        require(
            subject == 0 && tokenId == 0 && scope == 0 && selected == address(0) && requestedAt == 0
                && requestId == 0 && raw == 0,
            "request fields unwound"
        );
        IStreamEntropyEpochs.RequestPolicySnapshot memory empty;
        require(
            keccak256(abi.encode(entropy.requestPolicySnapshot(key)))
                == keccak256(abi.encode(empty)),
            "snapshot unwound"
        );
        require(
            entropy.providerRequestKeys(provider, id) == 0 && entropy.pendingRequestCount() == 0
                && entropy.nonterminalTokenCount(1) == 1,
            "reverse binding and counters unwound"
        );
        require(
            entropy.entropyFeeCredit(address(this)) == 0 && entropy.totalFeeCredits() == 0
                && address(entropy).balance == 0,
            "failed call carries no fee liability"
        );
        require(
            !entropy.metadataNotificationPending(1) && core.metadataNotifications() == 0,
            "failed read did not notify metadata"
        );
    }
}
