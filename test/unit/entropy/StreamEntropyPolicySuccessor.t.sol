// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "./EntropyPolicySuccessorFixtures.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyProviderInstant.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyOriginRelay as O
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";

/// @notice Actual Coordinators, import/relay workers and production INSTANT provider.
/// @dev Core pointers, Artist receipts, ModuleRegistry eligibility and executing governance are typed
/// unit seams. This suite does not prove actual Core replacement, Safe or Artist signature flows.
contract StreamEntropyPolicySuccessorTest is CharacterizationTestBase, EntropyTimeAuthorityFixture {
    bytes32 private constant HASH = keccak256("successor unit manifest");
    bytes32 private constant SALT = keccak256("successor collection salt");
    bytes32 private constant COMMITMENT = keccak256("original delivery commitment");
    bytes32 private constant AUTH = keccak256("6529STREAM_GGP_ENTROPY_RELAY_AUTH_READ_GAS_LIMIT");
    bytes32 private constant INSTANT_RELAY =
        keccak256("6529STREAM_GGP_ENTROPY_RELAY_INSTANT_READ_GAS_LIMIT");
    bytes32 private constant DELIVERY =
        keccak256("6529STREAM_GGP_ENTROPY_RELAY_DELIVERY_GAS_LIMIT");
    EntropyPolicySuccessorCoreFixture private core;
    EntropyCollectionPolicyArtistFixture private artist;
    EntropySuccessorModuleFixture private modules;
    MockEntropyRoleRegistry public roleRegistry;
    StreamEntropyCoordinator private source;
    StreamEntropyCoordinator private successor;
    StreamEntropyProviderInstant private instant;
    MockStreamEntropyProvider private asyncProvider;
    uint256 private _actionNonce;

    event log_named_uint(string key, uint256 value);

    function setUp() public {
        vm.roll(100);
        vm.deal(address(this), 100 ether);
        core = new EntropyPolicySuccessorCoreFixture();
        artist = new EntropyCollectionPolicyArtistFixture(address(core));
        modules = new EntropySuccessorModuleFixture(address(this));
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        source = _deploy();
        core.wire(source, address(artist), address(modules));
        instant = new StreamEntropyProviderInstant(address(source));
        asyncProvider = new MockStreamEntropyProvider(address(source));
        _admitEntropyProvider(address(source), address(instant));
        _admitEntropyProvider(address(source), address(asyncProvider));
        successor = _candidate();
    }

    function testExactExplicitImportRetainsPolicyArtistAndReceipts() public {
        _configure(1, P.Mode.INSTANT);
        C.PolicyExport memory original = C(address(source)).exportEntropyPolicy(1);
        _begin(source, successor);
        C(address(successor)).importNextEntropyPolicy(0);
        C.PolicyExport memory copied = C(address(successor)).exportEntropyPolicy(1);
        require(keccak256(abi.encode(copied)) == keccak256(abi.encode(original)), "exact export");
        _admitRoute(source, successor, 1);
        C(address(successor)).confirmEntropyRelayRoute(1);
        _seal(successor);
        _activate(successor);
        P.PolicyRecord memory p = P(address(successor)).collectionEntropyPolicy(1);
        require(
            keccak256(abi.encode(p)) == keccak256(abi.encode(original.record)), "original receipts"
        );
        require(C(address(successor)).entropyPolicyImport().state == C.ImportState.ACTIVE);
    }

    function testExactLegacyImportDoesNotInventExplicitArtistOrAction() public {
        _legacy(1, true);
        C.PolicyExport memory original = C(address(source)).exportEntropyPolicy(1);
        _migrate(source, successor);
        C.PolicyExport memory p = C(address(successor)).exportEntropyPolicy(1);
        require(keccak256(abi.encode(p)) == keccak256(abi.encode(original)), "legacy exact bytes");
        require(
            p.profile == C.PolicyProfile.LEGACY && !p.record.explicitPolicy
                && p.record.revision == 0 && p.record.lastActionId == 0
                && p.record.artistConsentRecord == 0 && p.record.policyHash != 0,
            "faithful legacy record"
        );
        core.registerToken(1, 1, COMMITMENT);
        (bytes32 key, uint256 id) = successor.requestEntropy(1);
        require(asyncProvider.fulfill(id, HASH) == 0, "legacy source callback captured");
        _assertFinal(successor, 1, key, id, HASH);
    }

    function testLegacyUndeclaredImportKeepsUnavailableHashAndMissingDeclaration() public {
        _legacy(1, false);
        _migrate(source, successor);
        C.PolicyExport memory p = C(address(successor)).exportEntropyPolicy(1);
        require(p.record.policyHash == 0 && !p.policy.reveal.declared, "legacy H0 retained");
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealPolicyUndeclared.selector, 1)
        );
        core.registerToken(1, 1, COMMITMENT);
        require(core.coordinatorAtMint(1) == address(0), "failed mint rolled back");
    }

    function testSourceSerialDriftBeforeNextCopyFailsWithoutPartialInstall() public {
        _legacy(1, true);
        _begin(source, successor);
        source.updateRevealFeePerToken(1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(C.EntropyPolicyImportSourceChanged.selector, address(source))
        );
        C(address(successor)).importNextEntropyPolicy(0);
        require(C(address(successor)).entropyPolicyImport().nextIndex == 0);
        (uint256 count,,) = C(address(successor)).entropyPolicyInventory();
        require(count == 0, "stale copy absent");
    }

    function testFirstSourceRegistrationInvalidatesAlreadyCopiedSession() public {
        _configure(1, P.Mode.INSTANT);
        _begin(source, successor);
        C(address(successor)).importNextEntropyPolicy(0);
        _admitRoute(source, successor, 1);
        C(address(successor)).confirmEntropyRelayRoute(1);
        core.registerToken(1, 1, COMMITMENT);
        vm.expectRevert(
            abi.encodeWithSelector(C.EntropyPolicyImportSourceChanged.selector, address(source))
        );
        C(address(successor)).entropyPolicyImportSealTransition();
        require(C(address(successor)).entropyPolicyImport().state == C.ImportState.STAGING);
    }

    function testOmissionAndDuplicateIndexCannotSealOrAppendTwice() public {
        _configure(1, P.Mode.DISABLED);
        _configure(2, P.Mode.DISABLED);
        _begin(source, successor);
        C(address(successor)).importNextEntropyPolicy(0);
        vm.expectRevert(abi.encodeWithSelector(C.EntropyPolicyImportIndex.selector, 0, 1));
        C(address(successor)).importNextEntropyPolicy(0);
        _fails(address(successor), abi.encodeCall(C.entropyPolicyImportSealTransition, ()));
        require(C(address(successor)).entropyPolicyImport().nextIndex == 1);
        C(address(successor)).importNextEntropyPolicy(1);
        _seal(successor);
        _activate(successor);
        (uint256 count,,) = C(address(successor)).entropyPolicyInventory();
        require(count == 2, "both authoritative IDs once");
    }

    function testNonfreshCandidateCannotBeginEvenAfterConfigurationWithoutRequests() public {
        _configure(1, P.Mode.DISABLED);
        successor.configureCollection(2, address(asyncProvider), SALT, true, 10);
        vm.expectRevert(abi.encodeWithSelector(C.EntropyPolicyImportNotFresh.selector));
        C(address(successor)).entropyPolicyImportTransition(address(source), HASH);
    }

    function testStagingBlocksOrdinaryMutationAndTokenRegistration() public {
        _legacy(1, true);
        _begin(source, successor);
        C(address(successor)).importNextEntropyPolicy(0);
        _fails(
            address(successor),
            abi.encodeCall(
                successor.configureCollection, (2, address(asyncProvider), SALT, true, 10)
            )
        );
        _fails(address(successor), abi.encodeCall(successor.updateRevealFeePerToken, (1, 9)));
        _failsValue(address(successor), abi.encodeCall(successor.fundRevealFeeEscrow, (1)), 1);
        vm.prank(address(core));
        vm.expectRevert(abi.encodeWithSelector(C.InvalidEntropyPolicyImport.selector));
        successor.onTokenMinted(1, 9, address(this), COMMITMENT);
        require(successor.revealFeeEscrow(1) == 0 && successor.registeredAtBlock(9) == 0);
    }

    function testRelayConfirmationAndCorrectGovernanceClassAreRequired() public {
        _configure(1, P.Mode.INSTANT);
        _begin(source, successor);
        C(address(successor)).importNextEntropyPolicy(0);
        _fails(address(successor), abi.encodeCall(C.confirmEntropyRelayRoute, (1)));
        _fails(address(successor), abi.encodeCall(C.entropyPolicyImportSealTransition, ()));
        bytes32 importHash = C(address(successor)).entropyPolicyImport().importHash;
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            O(address(source)).entropyRelayAdmissionTransition(1, address(successor), importHash);
        _action(scope, oldHash, newHash, 3);
        _fails(
            address(source),
            abi.encodeCall(O.admitEntropyRelay, (1, address(successor), importHash))
        );
        _clearAction();
        _admitRoute(source, successor, 1);
        C(address(successor)).confirmEntropyRelayRoute(1);
        _fails(address(successor), abi.encodeCall(C.confirmEntropyRelayRoute, (1)));
        require(C(address(successor)).entropyPolicyImport().confirmedRelayCount == 1);
    }

    function testActivationRequiresExactNextPointerAndClassThree() public {
        _configure(1, P.Mode.DISABLED);
        _begin(source, successor);
        C(address(successor)).importNextEntropyPolicy(0);
        _seal(successor);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            C(address(successor)).entropyPolicyImportActivationTransition();
        _action(scope, oldHash, newHash, 3);
        _fails(address(successor), abi.encodeCall(C.activateEntropyPolicyImport, ()));
        core.select(successor, 3);
        _fails(address(successor), abi.encodeCall(C.activateEntropyPolicyImport, ()));
        core.select(successor, 2);
        _action(scope, oldHash, newHash, 1);
        _fails(address(successor), abi.encodeCall(C.activateEntropyPolicyImport, ()));
        _action(scope, oldHash, newHash, 3);
        C(address(successor)).activateEntropyPolicyImport();
        _clearAction();
        require(C(address(successor)).entropyPolicyImport().activationActionId != 0);
    }

    function testInstantNewTokenUsesOriginalOnlyProviderAndOldTokenStaysOriginal() public {
        _configure(1, P.Mode.INSTANT);
        core.registerToken(1, 1, COMMITMENT);
        _migrate(source, successor);
        core.registerToken(1, 2, keccak256("new delivery"));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InstantEntropyBeforeDelivery.selector, 2
            )
        );
        successor.requestEntropy(2);
        vm.roll(block.number + 1);
        uint256 before = gasleft();
        (bytes32 key, uint256 id) = successor.requestEntropy{ value: 7 }(2);
        emit log_named_uint(
            "INSTANT successor total request gas (provisional envelopes)", before - gasleft()
        );
        bytes memory context = _context(successor, 1, 2, key);
        bytes32 raw = keccak256(
            abi.encode(
                instant.RAW_DOMAIN(),
                key,
                keccak256(context),
                block.number - 1,
                blockhash(block.number - 1)
            )
        );
        _assertFinal(successor, 2, key, id, raw);
        require(instant.coordinator() == address(source), "real provider only accepts origin");
        require(
            source.tokenEntropyStatus(2) == StreamEntropyStatus.NONE,
            "no origin subject for new token"
        );
        require(
            core.coordinatorAtMint(1) == address(source)
                && core.coordinatorAtMint(2) == address(successor)
        );
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.InvalidToken.selector, 1));
        successor.requestEntropy(1);
        source.requestEntropy(1);
        require(source.tokenEntropyStatus(1) == StreamEntropyStatus.FINALIZED);
        require(successor.entropyFeeCredit(address(this)) == 7 && address(source).balance == 0);
        _budgets();
    }

    function testAsyncRelayPreservesActualIdContextSeedAndSeparatedBookkeeping() public {
        _legacy(1, true);
        _migrate(source, successor);
        core.registerToken(1, 2, COMMITMENT);
        uint256 before = gasleft();
        (bytes32 key, uint256 id) = successor.requestEntropy(2);
        emit log_named_uint(
            "ASYNC successor submit gas (provisional envelopes)", before - gasleft()
        );
        bytes32 relayId = _relayId(source, successor, 1, 2, key);
        O.RelayResult memory result = O(address(source)).entropyRelayResult(relayId);
        require(
            result.submitted && result.providerRequestId == id && result.successorRequestKey == key
        );
        require(
            result.contextHash == keccak256(_context(successor, 1, 2, key)),
            "canonical provider context"
        );
        (bytes32 providerKey,,,,) = asyncProvider.results(id);
        require(
            providerKey == key && successor.providerRequestKeys(address(asyncProvider), id) == key
        );
        require(
            source.providerRequestKeys(address(asyncProvider), id) == 0
                && source.pendingRequestCount() == 0
        );
        before = gasleft();
        require(asyncProvider.fulfill(id, HASH) == 0);
        emit log_named_uint("ASYNC source capture plus delivery gas", before - gasleft());
        _assertFinal(successor, 2, key, id, HASH);
        result = O(address(source)).entropyRelayResult(relayId);
        require(result.rawReceived && result.delivered && result.raw == HASH);
        require(successor.pendingRequestCount() == 0 && successor.nonterminalTokenCount(1) == 0);
        _budgets();
    }

    function testAsyncExactFeeEscrowAndExcessCreditNeverRemainOnOrigin() public {
        asyncProvider.setFee(5);
        _legacy(1, true);
        source.fundRevealFeeEscrow{ value: 11 }(1);
        _migrate(source, successor);
        successor.fundRevealFeeEscrow{ value: 3 }(1);
        core.registerToken(1, 2, COMMITMENT);
        uint256 sourceBalance = address(source).balance;
        (, uint256 id) = successor.requestEntropy{ value: 9 }(2);
        require(successor.revealFeeEscrow(1) == 0 && successor.totalRevealFeeEscrows() == 0);
        require(successor.entropyFeeCredit(address(this)) == 7 && successor.totalFeeCredits() == 7);
        require(address(successor).balance == 7 && address(asyncProvider).balance == 5);
        require(
            address(source).balance == sourceBalance && sourceBalance == 11, "old escrow untouched"
        );
        require(source.revealFeeEscrow(1) == 11 && source.entropyFeeCredit(address(this)) == 0);
        require(asyncProvider.fulfill(id, HASH) == 0);
    }

    function testRawZeroCaptureRetriesActualDeliveryWithoutRequestOrDoubleCounters() public {
        _legacy(1, true);
        _migrate(source, successor);
        core.registerToken(1, 2, COMMITMENT);
        (bytes32 key, uint256 id) = successor.requestEntropy(2);
        bytes32 relayId = _relayId(source, successor, 1, 2, key);
        EntropySuccessorVm(address(vm))
            .mockCallRevert(
                address(successor),
                abi.encodeCall(O.fulfillRelayedEntropy, (key, relayId, bytes32(0))),
                abi.encodeWithSignature("TransportUnavailable()")
            );
        require(asyncProvider.fulfill(id, bytes32(0)) == 0, "origin durably acknowledges raw");
        O.RelayResult memory pending = O(address(source)).entropyRelayResult(relayId);
        require(pending.rawReceived && pending.raw == 0 && !pending.delivered);
        require(successor.pendingRequestCount() == 1 && successor.nonterminalTokenCount(1) == 1);
        EntropySuccessorVm(address(vm)).clearMockedCalls();
        uint256 requestsBefore = asyncProvider.nextRequestId();
        (bool delivered, uint8 outcome) = O(address(source)).retryEntropyRelay(relayId);
        require(delivered && outcome == 0 && asyncProvider.nextRequestId() == requestsBefore);
        _assertFinal(successor, 2, key, id, bytes32(0));
        O(address(source)).retryEntropyRelay(relayId);
        require(successor.pendingRequestCount() == 0 && successor.nonterminalTokenCount(1) == 0);
        require(core.metadataNotifications() == 1, "notify and count once");
    }

    function testOriginRevocationCapturesRawUntilReactivationAndPermissionlessRetry() public {
        _legacy(1, true);
        _migrate(source, successor);
        core.registerToken(1, 2, COMMITMENT);
        (bytes32 key, uint256 id) = successor.requestEntropy(2);
        bytes32 relayId = _relayId(source, successor, 1, 2, key);
        _setEntropyProviderRevoked(address(source), address(asyncProvider), true);
        require(
            IStreamEntropyProviderLifecycle(address(source))
            .entropyProviderRecord(address(asyncProvider))
            .state == EntropyProviderState.INCIDENT_REVOKED
        );
        require(
            IStreamEntropyProviderLifecycle(address(successor))
            .entropyProviderRecord(address(asyncProvider))
            .state == EntropyProviderState.ACTIVE
        );
        require(asyncProvider.fulfill(id, HASH) == 0, "origin durably acknowledges raw");
        O.RelayResult memory result = O(address(source)).entropyRelayResult(relayId);
        require(result.rawReceived && result.raw == HASH && !result.delivered);
        require(result.lastOutcome == 5, "original lifecycle blocks delivery");
        require(successor.tokenEntropyStatus(2) == StreamEntropyStatus.REQUESTED);
        require(successor.pendingRequestCount() == 1 && successor.nonterminalTokenCount(1) == 1);
        require(core.metadataNotifications() == 0);
        uint256 requestsBefore = asyncProvider.nextRequestId();
        _admitEntropyProvider(address(source), address(asyncProvider));
        vm.prank(address(0xBEEF));
        (bool delivered, uint8 outcome) = O(address(source)).retryEntropyRelay(relayId);
        require(delivered && outcome == 0 && asyncProvider.nextRequestId() == requestsBefore);
        _assertFinal(successor, 2, key, id, HASH);
        result = O(address(source)).entropyRelayResult(relayId);
        require(result.rawReceived && result.raw == HASH && result.delivered);
        vm.prank(address(0xCAFE));
        O(address(source)).retryEntropyRelay(relayId);
        require(successor.pendingRequestCount() == 0 && successor.nonterminalTokenCount(1) == 0);
        require(core.metadataNotifications() == 1, "notify and count once");
    }

    function testOnwardSuccessorUsesSameUltimateOriginAfterZeroPendingHandoff() public {
        _configure(1, P.Mode.INSTANT);
        _migrate(source, successor);
        core.registerToken(1, 2, COMMITMENT);
        vm.roll(block.number + 1);
        successor.requestEntropy(2);
        require(successor.pendingRequestCount() == 0);
        StreamEntropyCoordinator third = _candidate();
        C.PolicyExport memory original = C(address(successor)).exportEntropyPolicy(1);
        _migrate(successor, third);
        C.PolicyExport memory copied = C(address(third)).exportEntropyPolicy(1);
        require(
            copied.policyOrigin == address(source)
                && keccak256(abi.encode(copied)) == keccak256(abi.encode(original))
        );
        core.registerToken(1, 3, keccak256("onward commitment"));
        vm.roll(block.number + 1);
        third.requestEntropy(3);
        require(third.tokenEntropyStatus(3) == StreamEntropyStatus.FINALIZED);
        require(
            successor.tokenEntropyStatus(3) == StreamEntropyStatus.NONE
                && source.tokenEntropyStatus(3) == StreamEntropyStatus.NONE
        );
        require(
            core.coordinatorAtMint(2) == address(successor)
                && core.coordinatorAtMint(3) == address(third)
        );
    }

    function testActiveImportRemainsUsableAfterOriginalOperationalFeeChanges() public {
        _legacy(1, true);
        _migrate(source, successor);
        bytes32 historical = C(address(successor)).entropyPolicyImport().importHash;
        source.updateRevealFeePerToken(1, 99);
        core.registerToken(1, 2, COMMITMENT);
        (bytes32 key, uint256 id) = successor.requestEntropy(2);
        require(asyncProvider.fulfill(id, HASH) == 0);
        _assertFinal(successor, 2, key, id, HASH);
        require(C(address(successor)).entropyPolicyImport().importHash == historical);
        require(successor.collectionRevealPolicy(1).revealFeePerTokenWei == 0);
    }

    function testChangedOriginRuntimeRollsBackRequestEscrowCreditAndCounters() public {
        asyncProvider.setFee(5);
        _legacy(1, true);
        _migrate(source, successor);
        successor.fundRevealFeeEscrow{ value: 3 }(1);
        core.registerToken(1, 2, COMMITMENT);
        bytes memory originalRuntime = address(source).code;
        vm.etch(address(source), hex"00");
        _failsValue(address(successor), abi.encodeCall(successor.requestEntropy, (2)), 9);
        vm.etch(address(source), originalRuntime);
        require(successor.revealFeeEscrow(1) == 3 && successor.totalRevealFeeEscrows() == 3);
        require(successor.totalFeeCredits() == 0 && successor.entropyFeeCredit(address(this)) == 0);
        require(successor.pendingRequestCount() == 0 && successor.nonterminalTokenCount(1) == 1);
        require(successor.tokenEntropyStatus(2) == StreamEntropyStatus.REGISTERED);
        require(asyncProvider.nextRequestId() == 1 && address(source).balance == 0);
        (, uint256 id) = successor.requestEntropy{ value: 2 }(2);
        require(asyncProvider.fulfill(id, HASH) == 0, "retry after exact runtime restored");
    }

    function _deploy() private returns (StreamEntropyCoordinator target) {
        target = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                HASH,
                "urn:test:policy-successor",
                HASH
            )
        );
        modules.setEligible(address(target), true);
    }

    function _candidate() private returns (StreamEntropyCoordinator target) {
        target = _deploy();
        _admitEntropyProvider(address(target), address(instant));
        _admitEntropyProvider(address(target), address(asyncProvider));
    }

    function _configure(uint256 id, P.Mode mode) private {
        P.PolicyInput memory p;
        p.mode = mode;
        p.renderRequirement = mode == P.Mode.DISABLED
            ? P.RenderRequirement.NOT_REQUIRED
            : P.RenderRequirement.REQUIRED;
        if (mode == P.Mode.INSTANT) {
            p.securityClass = P.SecurityClass.LOW_SECURITY;
            p.provider = address(instant);
            p.collectionSalt = SALT;
            p.publicRequests = true;
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 state) =
            P(address(source)).collectionEntropyPolicyTransition(id, p);
        bytes32 consent = keccak256(abi.encode("original Artist receipt", id, state));
        artist.approve(
            id, address(source), keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), state, consent
        );
        _action(scope, oldHash, newHash, 1);
        P(address(source)).configureCollectionEntropyPolicy(id, p);
        _clearAction();
    }

    function _legacy(uint256 id, bool declared) private {
        source.configureCollection(id, address(asyncProvider), SALT, true, 10);
        if (declared) {
            source.configureCollectionRevealPolicy(
                id, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, asyncProvider.fee()
            );
        }
    }

    function _begin(StreamEntropyCoordinator prior, StreamEntropyCoordinator candidate) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            C(address(candidate)).entropyPolicyImportTransition(address(prior), HASH);
        _action(scope, oldHash, newHash, 1);
        C(address(candidate)).beginEntropyPolicyImport(address(prior), HASH);
        _clearAction();
    }

    function _admitRoute(
        StreamEntropyCoordinator origin,
        StreamEntropyCoordinator candidate,
        uint256 id
    ) private {
        bytes32 importHash = C(address(candidate)).entropyPolicyImport().importHash;
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            O(address(origin)).entropyRelayAdmissionTransition(id, address(candidate), importHash);
        _action(scope, oldHash, newHash, 1);
        O(address(origin)).admitEntropyRelay(id, address(candidate), importHash);
        _clearAction();
    }

    function _seal(StreamEntropyCoordinator candidate) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            C(address(candidate)).entropyPolicyImportSealTransition();
        _action(scope, oldHash, newHash, 1);
        C(address(candidate)).sealEntropyPolicyImport();
        _clearAction();
    }

    function _activate(StreamEntropyCoordinator candidate) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            C(address(candidate)).entropyPolicyImportActivationTransition();
        core.select(candidate, core.pointerRevision() + 1);
        _action(scope, oldHash, newHash, 3);
        C(address(candidate)).activateEntropyPolicyImport();
        _clearAction();
    }

    function _migrate(StreamEntropyCoordinator prior, StreamEntropyCoordinator candidate) private {
        _begin(prior, candidate);
        (uint256 count,,) = C(address(prior)).entropyPolicyInventory();
        for (uint256 i; i < count; ++i) {
            C(address(candidate)).importNextEntropyPolicy(i);
            uint256 id = C(address(prior)).entropyPolicyCollectionAt(i);
            C.PolicyExport memory p = C(address(prior)).exportEntropyPolicy(id);
            if (
                p.policy.mode != P.Mode.DISABLED
                    && !(p.policy.mode == P.Mode.INSTANT
                        && p.policy.renderRequirement == P.RenderRequirement.NOT_REQUIRED)
            ) {
                _admitRoute(StreamEntropyCoordinator(payable(p.policyOrigin)), candidate, id);
                C(address(candidate)).confirmEntropyRelayRoute(id);
            }
        }
        _seal(candidate);
        _activate(candidate);
    }

    function _action(bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 cls) private {
        this.setCurrentAction(
            true,
            keccak256(abi.encode("successor action", ++_actionNonce)),
            cls,
            scope,
            oldHash,
            newHash
        );
    }

    function _clearAction() private {
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _context(StreamEntropyCoordinator host, uint256 cid, uint256 tokenId, bytes32 key)
        private
        view
        returns (bytes memory)
    {
        IStreamEntropyEpochs.RequestPolicySnapshot memory p = host.requestPolicySnapshot(key);
        return abi.encode(
            uint16(1),
            address(core),
            cid,
            tokenId,
            bytes32(0),
            p.providerEpoch,
            p.providerConfigHash,
            p.requestAttempt,
            p.inputsHash
        );
    }

    function _relayId(
        StreamEntropyCoordinator origin,
        StreamEntropyCoordinator host,
        uint256 cid,
        uint256 tokenId,
        bytes32 key
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_RELAY_V1"),
                block.chainid,
                address(origin),
                address(host),
                address(host).codehash,
                C(address(host)).entropyPolicyImport().importHash,
                cid,
                key,
                keccak256(_context(host, cid, tokenId, key))
            )
        );
    }

    function _assertFinal(
        StreamEntropyCoordinator host,
        uint256 tokenId,
        bytes32 key,
        uint256 id,
        bytes32 raw
    ) private view {
        IStreamEntropyEpochs.RequestPolicySnapshot memory p = host.requestPolicySnapshot(key);
        StreamEntropyCoordinator.SeedInputs memory expected = StreamEntropyCoordinator.SeedInputs(
            keccak256("6529STREAM_ENTROPY_SEED_V1"),
            block.chainid,
            address(host),
            address(core),
            1,
            bytes32(tokenId),
            p.provider,
            p.providerEpoch,
            p.providerConfigHash,
            key,
            id,
            raw,
            p.collectionSalt,
            p.inputsHash
        );
        (bytes32 seed, bool finalized) = host.tokenSeed(tokenId);
        require(finalized && seed == keccak256(abi.encode(expected)), "exact original seed recipe");
    }

    function _budgets() private view {
        require(source.gasParameter(AUTH) == 100000 && successor.gasParameter(AUTH) == 100000);
        require(
            successor.gasParameter(INSTANT_RELAY) == 750000
                && source.gasParameter(DELIVERY) == 500000
        );
    }

    function _fails(address target, bytes memory data) private {
        (bool ok,) = target.call(data);
        require(!ok, "expected rejected operation");
    }

    function _failsValue(address target, bytes memory data, uint256 value) private {
        (bool ok,) = target.call{ value: value }(data);
        require(!ok, "expected rejected payable operation");
    }

    receive() external payable { }
}
