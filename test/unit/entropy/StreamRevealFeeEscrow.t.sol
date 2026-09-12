// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamEntropySubjectIdentity.t.sol";
import "../../helpers/OfficialSafeFixture.sol";

contract RevealRejectingReceiver {
    bool public rejecting = true;

    function accept() external {
        rejecting = false;
    }

    function reject() external {
        rejecting = true;
    }

    receive() external payable {
        require(!rejecting, "recipient unavailable");
    }
}

contract ProviderWithoutCollectionFeeCapability is MockStreamEntropyProvider {
    constructor(address target) MockStreamEntropyProvider(target) { }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id != type(IStreamEntropyProviderFeeQuote).interfaceId && super.supportsInterface(id);
    }
}

contract ProviderWithMalformedCollectionFee is MockStreamEntropyProvider {
    constructor(address target) MockStreamEntropyProvider(target) { }

    function contextIndependentRequestFee() public pure override returns (uint256) {
        assembly ("memory-safe") {
            mstore(0, 0)
            mstore(32, 0)
            return(0, 64)
        }
    }
}

/// @notice Escrow behavior with real Safe callers and explicit Core/role/provider domain doubles.
contract StreamRevealFeeEscrowTest is CharacterizationTestBase, OfficialSafeFixture {
    bytes32 private constant MANIFEST = keccak256("reveal fee fixture");
    bytes32 private constant REVEAL_OWNER = keccak256("ROLE_ENTROPY_REVEAL_OWNER");
    bytes32 private constant ADMIN = keccak256("ROLE_ENTROPY_ADMIN");
    bytes32 private constant TREASURY = keccak256("ROLE_TREASURY");
    EntropySubjectCoreFixture private core;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    MockStreamEntropyProvider private otherProvider;
    MockEntropyRoleRegistry public roleRegistry;
    OfficialSafe private safe;
    uint256[] private keys;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 171);
        core = new EntropySubjectCoreFixture();
        core.setModuleRegistry(address(new MockEntropyModuleRegistry(address(this))));
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        roleRegistry.setHolder(TREASURY, address(safe));
        entropy = new StreamEntropyCoordinator(
            address(core),
            address(this),
            address(roleRegistry),
            MANIFEST,
            "urn:stream:fixture:reveal",
            MANIFEST
        );
        core.setCoordinator(entropy);
        provider = new MockStreamEntropyProvider(address(entropy));
        provider.setFee(100);
        otherProvider = new MockStreamEntropyProvider(address(entropy));
        entropy.configureCollection(1, address(provider), keccak256("one"), true, 10);
        entropy.configureCollection(2, address(otherProvider), keccak256("two"), true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, REVEAL_OWNER, 10, 100);
        vm.deal(address(this), 1 ether);
        vm.deal(address(safe), 1 ether);
    }

    function testMissingPolicyIsNotZeroAndDeclarationIsRequiredBeforeRegistration() public {
        require(!entropy.collectionRevealPolicy(2).declared, "missing policy");
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealPolicyUndeclared.selector, 2)
        );
        entropy.fundRevealFeeEscrow(2);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealPolicyUndeclared.selector, 2)
        );
        core.registerTokenInCollection(2, 21, keccak256("two"));
        entropy.configureCollectionRevealPolicy(2, 1, REVEAL_OWNER, 20, 0);
        IStreamRevealFeeEscrow.CollectionRevealPolicy memory policy =
            entropy.collectionRevealPolicy(2);
        require(
            policy.declared && policy.revealFeePerTokenWei == 0 && policy.requestMode == 1,
            "explicit declared zero"
        );
        core.registerTokenInCollection(2, 21, keccak256("two"));
        require(
            entropy.nonterminalTokenCount(2) == 1 && entropy.registeredAtBlock(21) == block.number,
            "first registration counted"
        );
        require(
            entropy.supportsInterface(type(IStreamRevealFeeEscrow).interfaceId)
                && entropy.supportsInterface(type(IStreamRevealPolicyAdmin).interfaceId),
            "complete typed capabilities"
        );
    }

    function testFrozenPromisesAllowFeeRetuneWithoutRestatingEscrow() public {
        entropy.fundRevealFeeEscrow{ value: 150 }(1);
        _mint(1);
        core.freezeCollection(1);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 1));
        entropy.configureCollectionRevealPolicy(1, 1, REVEAL_OWNER, 50, 100);
        provider.setFee(200);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealFeeBelowQuote.selector, 199, 200)
        );
        entropy.updateRevealFeePerToken(1, 199);
        entropy.updateRevealFeePerToken(1, 200);
        IStreamRevealFeeEscrow.CollectionRevealPolicy memory policy =
            entropy.collectionRevealPolicy(1);
        require(
            policy.declared && policy.requestMode == 0 && policy.requestSLOBlocks == 10
                && policy.revealOwnerRole == REVEAL_OWNER && policy.revealFeePerTokenWei == 200
                && entropy.revealFeeEscrow(1) == 150,
            "only operational fee changed"
        );
    }

    function testPolicyRequiresTypedExactQuoteAndRechecksChangedProvider() public {
        MockStreamEntropyProvider absent =
            new ProviderWithoutCollectionFeeCapability(address(entropy));
        entropy.configureCollection(2, address(absent), 0, true, 10);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.RevealFeeQuoteUnavailable.selector, address(absent)
            )
        );
        entropy.configureCollectionRevealPolicy(2, 0, REVEAL_OWNER, 10, 0);
        MockStreamEntropyProvider malformed =
            new ProviderWithMalformedCollectionFee(address(entropy));
        entropy.configureCollection(2, address(malformed), 0, true, 10);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.RevealFeeQuoteUnavailable.selector, address(malformed)
            )
        );
        entropy.configureCollectionRevealPolicy(2, 0, REVEAL_OWNER, 10, 0);
        otherProvider.setFee(101);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealFeeBelowQuote.selector, 100, 101)
        );
        entropy.configureCollection(1, address(otherProvider), 0, true, 10);
        (address retained,,,,,,) = entropy.collectionEntropyConfig(1);
        require(retained == address(provider), "underfunded replacement rolled back");
    }

    function testSafeEscrowFirstAndFullCallerExcessBecomesSeparateCredit() public {
        _mint(1);
        require(
            executeSafe(
                safe,
                keys,
                address(entropy),
                150,
                abi.encodeCall(entropy.fundRevealFeeEscrow, (1)),
                0
            ),
            "Safe funds collection"
        );
        require(
            executeSafe(
                safe, keys, address(entropy), 25, abi.encodeCall(entropy.requestEntropy, (1)), 0
            ),
            "Safe requests from escrow"
        );
        require(
            entropy.revealFeeEscrow(1) == 50 && entropy.totalRevealFeeEscrows() == 50
                && entropy.entropyFeeCredit(address(safe)) == 25 && entropy.totalFeeCredits() == 25
                && address(provider).balance == 100,
            "independent escrow and credit ledgers"
        );
        _solvent();
        uint256 before_ = address(safe).balance;
        require(
            executeSafe(
                safe,
                keys,
                address(entropy),
                0,
                abi.encodeCall(entropy.claimEntropyFeeCredit, (payable(address(safe)))),
                0
            ),
            "Safe claims its excess"
        );
        require(
            address(safe).balance == before_ + 25 && entropy.revealFeeEscrow(1) == 50,
            "claim cannot touch collection funds"
        );
        _solvent();
    }

    function testPartialEmptyAndOtherCollectionEscrowsUseExactFundingEquation() public {
        entropy.configureCollectionRevealPolicy(2, 0, REVEAL_OWNER, 10, 0);
        entropy.fundRevealFeeEscrow{ value: 300 }(2);
        entropy.fundRevealFeeEscrow{ value: 60 }(1);
        _mint(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InsufficientRevealFee.selector, 100, 60, 39
            )
        );
        entropy.requestEntropy{ value: 39 }(1);
        entropy.requestEntropy{ value: 55 }(1);
        require(
            entropy.entropyFeeCredit(address(this)) == 15 && entropy.revealFeeEscrow(1) == 0
                && entropy.revealFeeEscrow(2) == 300,
            "partial escrow draws no other collection"
        );
        _mint(2);
        entropy.requestEntropy{ value: 100 }(2);
        require(
            address(provider).balance == 200 && entropy.entropyFeeCredit(address(this)) == 15
                && entropy.totalRevealFeeEscrows() == 300,
            "empty escrow caller pays exact quote"
        );
        _solvent();
    }

    function testScopeNeverSpendsCollectionRevealEscrow() public {
        entropy.fundRevealFeeEscrow{ value: 300 }(1);
        bytes32 scope = entropy.registerEntropyScope(1, 0, keccak256("allocation"));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.InsufficientEntropyFee.selector, 100, 0)
        );
        entropy.requestScopeEntropy(scope, keccak256("entries"));
        entropy.requestScopeEntropy{ value: 120 }(scope, keccak256("entries"));
        require(
            entropy.revealFeeEscrow(1) == 300 && entropy.totalRevealFeeEscrows() == 300
                && entropy.entropyFeeCredit(address(this)) == 20
                && entropy.nonterminalTokenCount(1) == 0,
            "scope is caller funded and not a token obligation"
        );
        _solvent();
    }

    function testProviderReentryRollsBackEscrowCreditsAndRequestThenSameCallRetries() public {
        entropy.fundRevealFeeEscrow{ value: 75 }(1);
        _mint(1);
        provider.setReenterOnRequest(true);
        uint256 before_ = address(this).balance;
        (bool ok,) = address(entropy).call{ value: 40 }(abi.encodeCall(entropy.requestEntropy, (1)));
        require(
            !ok && entropy.revealFeeEscrow(1) == 75 && entropy.totalFeeCredits() == 0
                && entropy.pendingRequestCount() == 0 && entropy.nonterminalTokenCount(1) == 1
                && provider.nextRequestId() == 1 && address(provider).balance == 0
                && address(this).balance == before_,
            "complete rejected request rollback"
        );
        provider.setReenterOnRequest(false);
        entropy.requestEntropy{ value: 40 }(1);
        require(
            entropy.revealFeeEscrow(1) == 0 && entropy.entropyFeeCredit(address(this)) == 15
                && entropy.pendingRequestCount() == 1 && provider.nextRequestId() == 2,
            "identical funding succeeds"
        );
        _solvent();
    }

    function testProviderIdCollisionRestoresSecondTokenFundingAndCredits() public {
        entropy.fundRevealFeeEscrow{ value: 250 }(1);
        _mint(1);
        _mint(2);
        entropy.requestEntropy(1);
        provider.setNextRequestId(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.ProviderRequestCollision.selector, address(provider), 1
            )
        );
        entropy.requestEntropy{ value: 20 }(2);
        require(
            entropy.revealFeeEscrow(1) == 150 && entropy.totalFeeCredits() == 0
                && entropy.pendingRequestCount() == 1
                && entropy.tokenEntropyStatus(2) == StreamEntropyStatus.REGISTERED
                && entropy.nonterminalTokenCount(1) == 2,
            "collision cannot consume second token funds"
        );
        provider.setNextRequestId(2);
        entropy.requestEntropy{ value: 20 }(2);
        require(
            entropy.revealFeeEscrow(1) == 50 && entropy.entropyFeeCredit(address(this)) == 20,
            "exact collision retry"
        );
        _solvent();
    }

    function testRegisteredAndRequestedTokensBlockWithdrawalUntilFirstTerminalTransition() public {
        entropy.fundRevealFeeEscrow{ value: 250 }(1);
        _mint(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealEscrowUnavailable.selector, 1)
        );
        entropy.withdrawRevealFeeEscrow(1, 250);
        entropy.requestEntropy(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealEscrowUnavailable.selector, 1)
        );
        entropy.withdrawRevealFeeEscrow(1, 150);
        provider.fulfill(1, keccak256("raw"));
        provider.fulfill(1, keccak256("raw"));
        require(
            entropy.nonterminalTokenCount(1) == 0 && entropy.pendingRequestCount() == 0,
            "duplicate finalization cannot decrement again"
        );
        roleRegistry.setHolder(ADMIN, address(safe));
        uint256 before_ = address(safe).balance;
        require(
            executeSafe(
                safe,
                keys,
                address(entropy),
                0,
                abi.encodeCall(entropy.withdrawRevealFeeEscrow, (1, 150)),
                0
            ),
            "Safe admin withdraws residual to current Safe treasury"
        );
        require(
            address(safe).balance == before_ + 150 && entropy.totalRevealFeeEscrows() == 0,
            "exact residual transfer"
        );
        _solvent();
    }

    function testBurnedRegistrationRemainsNonterminalAndCannotReleaseResidual() public {
        entropy.fundRevealFeeEscrow{ value: 100 }(1);
        _mint(1);
        core.burnToken(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.RevealEscrowUnavailable.selector, 1)
        );
        entropy.withdrawRevealFeeEscrow(1, 100);
        require(
            entropy.nonterminalTokenCount(1) == 1, "burn is not an invented entropy terminal event"
        );
    }

    function testRejectingTreasuryAndCreditRecipientPreserveSeparateLiabilities() public {
        RevealRejectingReceiver receiver = new RevealRejectingReceiver();
        roleRegistry.setHolder(TREASURY, address(receiver));
        entropy.fundRevealFeeEscrow{ value: 100 }(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.CreditTransferFailed.selector)
        );
        entropy.withdrawRevealFeeEscrow(1, 25);
        require(
            entropy.revealFeeEscrow(1) == 100 && entropy.totalRevealFeeEscrows() == 100,
            "withdrawal failure restores escrow"
        );
        receiver.accept();
        entropy.withdrawRevealFeeEscrow(1, 25);
        require(
            entropy.revealFeeEscrow(1) == 75 && entropy.totalRevealFeeEscrows() == 75
                && address(receiver).balance == 25,
            "same withdrawal retries after treasury recovers"
        );
        receiver.reject();
        _mint(1);
        entropy.requestEntropy{ value: 50 }(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.CreditTransferFailed.selector)
        );
        entropy.claimEntropyFeeCredit(payable(address(receiver)));
        require(
            entropy.entropyFeeCredit(address(this)) == 25 && entropy.totalFeeCredits() == 25,
            "claim failure restores caller credit"
        );
        receiver.accept();
        entropy.claimEntropyFeeCredit(payable(address(receiver)));
        require(
            address(receiver).balance == 50 && entropy.totalFeeCredits() == 0,
            "same credit claim retries"
        );
        _solvent();
    }

    function testOutageDoesNotBlockTopupRegistrationOrResidualWithdrawal() public {
        provider.setQuoteUnavailable(true);
        entropy.fundRevealFeeEscrow{ value: 200 }(1);
        entropy.withdrawRevealFeeEscrow(1, 50);
        _mint(1);
        require(
            entropy.revealFeeEscrow(1) == 150 && entropy.nonterminalTokenCount(1) == 1
                && provider.nextRequestId() == 1,
            "no provider call in funding withdrawal or registration"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.RevealFeeQuoteUnavailable.selector, address(provider)
            )
        );
        entropy.updateRevealFeePerToken(1, 100);
        _solvent();
    }

    function testCurrentRoleRotationAndCanonicalRegistryPinRejectImpostor() public {
        roleRegistry.setHolder(ADMIN, address(safe));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.Unauthorized.selector, address(this))
        );
        entropy.updateRevealFeePerToken(1, 150);
        require(
            executeSafe(
                safe,
                keys,
                address(entropy),
                0,
                abi.encodeCall(entropy.updateRevealFeePerToken, (1, 150)),
                0
            ),
            "current Safe role holder"
        );
        vm.prank(vm.addr(keys[0]));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.Unauthorized.selector, vm.addr(keys[0]))
        );
        entropy.updateRevealFeePerToken(1, 160);
        address pinned = address(roleRegistry);
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.InvalidDependency.selector, pinned)
        );
        entropy.updateRevealFeePerToken(1, 160);
    }

    function testFuzzEscrowAndCreditLiabilitiesAreConserved(uint96 topup, uint96 attached) public {
        uint256 fee = uint256(topup) % 1000;
        provider.setFee(fee);
        entropy.updateRevealFeePerToken(1, fee);
        _mint(1);
        uint256 funding = uint256(topup) % 2000;
        uint256 caller = uint256(attached) % 2000 + fee;
        entropy.fundRevealFeeEscrow{ value: funding }(1);
        entropy.requestEntropy{ value: caller }(1);
        uint256 draw = funding < fee ? funding : fee;
        require(
            entropy.revealFeeEscrow(1) == funding - draw
                && entropy.entropyFeeCredit(address(this)) == caller - (fee - draw)
                && address(provider).balance == fee,
            "independent funding equation"
        );
        _solvent();
    }

    function testAllRevealEventsUseExactSchemaTopicsAndBalances() public {
        vm.recordLogs();
        entropy.configureCollectionRevealPolicy(2, 1, REVEAL_OWNER, 20, 0);
        _oneEvent(
            abi.encode(
                keccak256("RevealPolicyConfigured(uint16,uint256,uint8,bytes32,uint64,uint256)"),
                uint256(2)
            ),
            abi.encode(uint16(1), uint8(1), REVEAL_OWNER, uint64(20), uint256(0))
        );
        vm.recordLogs();
        entropy.updateRevealFeePerToken(1, 150);
        _oneEvent(
            abi.encode(
                keccak256("RevealFeePerTokenUpdated(uint16,uint256,uint256,uint256)"), uint256(1)
            ),
            abi.encode(uint16(1), uint256(100), uint256(150))
        );
        vm.recordLogs();
        entropy.fundRevealFeeEscrow{ value: 250 }(1);
        _oneEvent(
            abi.encode(
                keccak256("RevealFeeEscrowFunded(uint16,uint256,address,uint256,uint256)"),
                uint256(1),
                address(this)
            ),
            abi.encode(uint16(1), uint256(250), uint256(250))
        );
        _mint(1);
        vm.recordLogs();
        entropy.requestEntropy(1);
        _oneEvent(
            abi.encode(
                keccak256("RevealFeeEscrowSpent(uint16,uint256,uint256,uint256,uint256)"),
                uint256(1),
                uint256(1)
            ),
            abi.encode(uint16(1), uint256(100), uint256(150))
        );
        provider.fulfill(1, keccak256("raw"));
        vm.recordLogs();
        entropy.withdrawRevealFeeEscrow(1, 150);
        _oneEvent(
            abi.encode(
                keccak256("RevealFeeEscrowWithdrawn(uint16,uint256,address,uint256)"),
                uint256(1),
                address(safe)
            ),
            abi.encode(uint16(1), uint256(150))
        );
    }

    function testHistoricalCoordinatorCanFinishAndSettleItsOwnObligationAfterPointerChange()
        public
    {
        _mint(1);
        core.setCoordinator(StreamEntropyCoordinator(address(otherProvider)));
        require(core.coordinatorAtMint(1) == address(entropy), "historical coordinator is pinned");
        entropy.fundRevealFeeEscrow{ value: 150 }(1);
        entropy.requestEntropy{ value: 25 }(1);
        provider.fulfill(1, keccak256("historical raw"));
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.FINALIZED
                && core.metadataNotifications() == 1 && entropy.nonterminalTokenCount(1) == 0,
            "old request and metadata completion survive pointer change"
        );
        uint256 before_ = address(safe).balance;
        entropy.claimEntropyFeeCredit(payable(address(safe)));
        entropy.withdrawRevealFeeEscrow(1, 50);
        require(address(safe).balance == before_ + 75, "old ledgers settle independently");
        _solvent();
    }

    function testStaleTransitionReleasesOnlyItsCollectionObligationExactlyOnce() public {
        entropy.configureCollectionRevealPolicy(2, 0, REVEAL_OWNER, 10, 0);
        core.registerTokenInCollection(2, 21, keccak256("other collection"));
        entropy.fundRevealFeeEscrow{ value: 150 }(1);
        _mint(1);
        (bytes32 key,) = entropy.requestEntropy(1);
        vm.roll(block.number + 10);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.RequestNotExpired.selector));
        entropy.markRequestStale(key);
        vm.roll(block.number + 1);
        entropy.markRequestStale(key);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.STALE
            )
        );
        entropy.markRequestStale(key);
        require(provider.fulfill(1, keccak256("late raw")) == 1, "late output stays stale");
        require(
            entropy.nonterminalTokenCount(1) == 0 && entropy.nonterminalTokenCount(2) == 1
                && entropy.pendingRequestCount() == 0,
            "only first terminal transition releases its collection"
        );
        entropy.withdrawRevealFeeEscrow(1, 50);
        _solvent();
    }

    function testProvenFailureReleasesObligationExactlyOnce() public {
        entropy.fundRevealFeeEscrow{ value: 150 }(1);
        _mint(1);
        (bytes32 key,) = entropy.requestEntropy(1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.ProviderFailureUnproven.selector)
        );
        entropy.markRequestFailed(key);
        require(entropy.nonterminalTokenCount(1) == 1, "unproven failure remains owed");
        provider.fail(1);
        entropy.markRequestFailed(key);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.FAILED
            )
        );
        entropy.markRequestFailed(key);
        require(
            entropy.nonterminalTokenCount(1) == 0 && entropy.pendingRequestCount() == 0,
            "first proven failure releases token obligation"
        );
        entropy.withdrawRevealFeeEscrow(1, 50);
        _solvent();
    }

    function _oneEvent(bytes memory topics, bytes memory data) private {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 signature;
        assembly ("memory-safe") { signature := mload(add(topics, 32)) }
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(entropy) || logs[i].topics.length == 0
                    || logs[i].topics[0] != signature
            ) continue;
            ++matches;
            require(
                keccak256(abi.encodePacked(logs[i].topics)) == keccak256(topics)
                    && keccak256(logs[i].data) == keccak256(data),
                "normative event emitter topics data"
            );
        }
        require(matches == 1, "exactly one event of this type");
    }

    function _mint(uint256 token) private {
        core.registerToken(token, keccak256(abi.encode("reveal", token)));
    }

    function _solvent() private view {
        require(
            address(entropy).balance >= entropy.totalRevealFeeEscrows() + entropy.totalFeeCredits(),
            "escrow and credit liabilities covered"
        );
    }
}
