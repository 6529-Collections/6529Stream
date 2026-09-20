// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentERC20EntropyModesFixture.sol";
import "../mocks/MockStreamPaymentToken.sol";
import "../mocks/MockStreamEntropyProvider.sol";
import { StreamERC20PrimarySettlementAdapter } from "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import "../../smart-contracts/domains/mint/StreamUniversalFixedPriceSaleAdapter.sol";
import {
    IStreamEntropyCollectionPolicy as ModePolicy
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";

interface ERC20EntropyCallsVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice ERC20 payment and real current mint/entropy composition for explicit non-ASYNC-required modes.
/// @dev Artist op17 evidence and the governance execution context are typed boundaries. ASYNC's
/// external provider is a fixture and never requested here; INSTANT uses its production provider.
contract StreamCurrentERC20EntropyModesTest is CurrentERC20EntropyModesFixture {
    bytes32 private constant ERC_PHASE = keccak256("actual ERC20 entropy modes phase");
    bytes32 private constant COMMITMENT = keccak256("actual ERC20 entropy modes mint");
    uint256 private constant PRICE = 1000;
    uint256 private constant FEE = 100;
    uint256 private constant EXCESS = 37;
    uint256 private constant EXECUTOR_KEY = 0xECE2001;
    StreamERC20PrimarySettlementAdapter private payment;
    StreamUniversalFixedPriceSaleAdapter private sale;
    MockStreamPaymentToken private token;
    MockStreamEntropyProvider private asyncProvider;
    StreamEntropyProviderInstant private instantProvider;
    address private executor;
    bytes32 private saleId;
    ERC20EntropyCallsVm private constant calls =
        ERC20EntropyCallsVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Packet {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData execution;
        StreamPrimarySettlementTypes.ERC20SettlementCandidate candidate;
        StreamPrimarySettlementTypes.PaymentIntent intent;
        bytes input;
    }

    function setUp() public override {
        super.setUp();
        executor = vm.addr(EXECUTOR_KEY);
        instantProvider = new StreamEntropyProviderInstant(address(actualEntropy));
        asyncProvider = new MockStreamEntropyProvider(address(actualEntropy));
        asyncProvider.setFee(FEE);
        _admit(address(instantProvider));
        _admit(address(asyncProvider));
        token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("exact ERC20 mode policy"), 0);
        payment = new StreamERC20PrimarySettlementAdapter(recorder, address(0), 0);
        sale = new StreamUniversalFixedPriceSaleAdapter(
            manager,
            recorder,
            vm.addr(AUCTION_PLATFORM_KEY),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "REVEAL_ATTEMPT_GAS_LIMIT", 2_000_000, 100_000, 2
            )
        );
        _register(
            address(payment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        _register(
            address(sale),
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("ERC20 entropy mode counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            ERC_PHASE,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            gate,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, ERC_PHASE, address(sale), true);
        saleId = sale.registerSale(
            IStreamUniversalFixedPriceSaleAdapter.SaleConfig(
                address(payment),
                1,
                ERC_PHASE,
                address(token),
                PRICE,
                0,
                100000,
                manager.phasePolicyHash(1, ERC_PHASE),
                StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1)
            )
        );
        token.mint(payer, 10000);
        vm.prank(payer);
        token.approve(address(payment), 10000);
        vm.deal(payer, 73);
        require(
            address(payment).code.length <= 24576 && address(sale).code.length <= 24576
                && address(instantProvider).code.length <= 24576,
            "reached ERC20 and Instant products fit"
        );
    }

    function _admit(address provider_) private {
        string memory reason = "urn:erc20:entropy-mode-provider";
        (bytes32 scope, bytes32 old_, bytes32 next, uint8 cls) =
            actualEntropy.entropyProviderTransition(provider_, EntropyProviderState.ACTIVE, reason);
        _context(scope, old_, next, cls);
        vm.prank(address(revenueAuthority));
        actualEntropy.activateEntropyProvider(provider_, reason);
        _clearContext();
    }

    function _configure(ModePolicy.Mode mode, bool required) private returns (uint256 nativeFee) {
        ModePolicy.PolicyInput memory p;
        p.mode = mode;
        p.renderRequirement = required
            ? ModePolicy.RenderRequirement.REQUIRED
            : ModePolicy.RenderRequirement.NOT_REQUIRED;
        if (mode != ModePolicy.Mode.DISABLED) {
            p.provider =
                mode == ModePolicy.Mode.INSTANT ? address(instantProvider) : address(asyncProvider);
            p.collectionSalt = keccak256("declared ERC20 entropy salt");
            p.publicRequests = true;
        }
        if (mode == ModePolicy.Mode.INSTANT) {
            p.securityClass = ModePolicy.SecurityClass.LOW_SECURITY;
        }
        if (mode == ModePolicy.Mode.ASYNC) {
            p.timeoutBlocks = 100;
            p.reveal = IStreamRevealFeeEscrow.CollectionRevealPolicy(
                true, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, FEE
            );
            nativeFee = FEE;
        }
        (bytes32 scope, bytes32 old_, bytes32 next, bytes32 content) =
            actualEntropy.collectionEntropyPolicyTransition(1, p);
        bytes32 consent =
            keccak256(abi.encode("typed original op17 receipt", address(actualEntropy), content));
        CurrentERC20EntropyArtist(address(artists))
            .approveEntropyContent(address(actualEntropy), content, consent);
        _context(scope, old_, next, 1);
        vm.prank(address(revenueAuthority));
        actualEntropy.configureCollectionEntropyPolicy(1, p);
        _clearContext();
        ModePolicy.PolicyRecord memory record = actualEntropy.collectionEntropyPolicy(1);
        require(
            record.configured && record.explicitPolicy && !record.frozen && record.revision == 1
                && record.mode == mode && record.renderRequirement == p.renderRequirement
                && record.policyHash != 0 && record.contentStateHash == content
                && record.artistConsentRecord == consent && record.lastActionId != 0,
            "real Coordinator consumes exact typed Artist and governance inputs"
        );
    }

    function _proof(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _packet(address recipient) private returns (Packet memory p) {
        p.execution.tokenData = abi.encode("actual ERC20 explicit entropy modes");
        p.execution.authorization = IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization(
            saleId,
            sale.saleRecord(saleId).configHash,
            payer,
            executor,
            recipient,
            vm.addr(SIGNER_KEY),
            keccak256(p.execution.tokenData),
            COMMITMENT,
            1,
            bytes32(uint256(1)),
            10000
        );
        bytes32 digest = sale.authorizationDigest(p.execution.authorization);
        p.execution.platformSignature = _proof(AUCTION_PLATFORM_KEY, digest);
        p.execution.artistSignature = _proof(SIGNER_KEY, digest);
        p.candidate = sale.previewExecution(p.execution);
        p.intent = StreamPrimarySettlementTypes.PaymentIntent(
            payer,
            address(token),
            PRICE,
            saleId,
            p.candidate.sale.expectedPrimaryPolicyHash,
            keccak256("original ERC20 modes intent"),
            10000
        );
        p.input = abi.encodeCall(
            payment.settleERC20PrimarySaleWithIntent,
            (
                p.candidate,
                p.intent,
                _proof(PAYER_KEY, payment.paymentIntentDigest(p.intent)),
                abi.encode(p.execution)
            )
        );
    }

    function _counter() private view returns (bytes32) {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.PAYER,
            1,
            ERC_PHASE,
            COUNTER,
            payer,
            payer,
            address(sale),
            address(0),
            0
        );
        return manager.previewCounterValueKey(1, ERC_PHASE, COUNTER, subject);
    }

    function _noDraw(StreamEntropyStatus expected) private view {
        ModePolicy.PolicyRecord memory p = actualEntropy.collectionEntropyPolicy(1);
        (
            StreamEntropyStatus status,
            bytes32 seed,
            address provider_,
            uint32 epoch,
            bytes32 config,
            bytes32 key,
            uint256 id,
            uint16 attempt
        ) = actualEntropy.tokenEntropy(1);
        address wanted = p.mode == ModePolicy.Mode.DISABLED
            ? address(0)
            : p.mode == ModePolicy.Mode.INSTANT ? address(instantProvider) : address(asyncProvider);
        bytes32 wantedConfig = wanted == address(0)
            ? bytes32(0)
            : wanted == address(instantProvider)
                ? instantProvider.streamEntropyProviderConfigHash()
                : asyncProvider.streamEntropyProviderConfigHash();
        require(
            p.frozen && p.explicitPolicy && status == expected
                && actualEntropy.tokenEntropyStatus(1) == expected && seed == 0 && key == 0
                && id == 0 && attempt == 0 && provider_ == wanted && config == wantedConfig
                && epoch == p.providerEpoch,
            "exact original Coordinator tuple has no draw or manufactured seed"
        );
        (bytes32 seedRead, bool finalized) = actualEntropy.tokenSeed(1);
        require(
            seedRead == 0 && !finalized && actualEntropy.registeredAtBlock(1) == block.number
                && actualEntropy.pendingRequestCount() == 0
                && actualEntropy.nonterminalTokenCount(1)
                    == (expected == StreamEntropyStatus.REGISTERED ? 1 : 0)
                && asyncProvider.nextRequestId() == 1,
            "registration and terminal counters without provider request"
        );
    }

    function _mintEvents(Vm.Log[] memory logs, StreamEntropyStatus status) private view {
        bytes32 registered =
            keccak256("TokenEntropyPolicyRegistered(uint16,uint256,uint256,bytes32,uint8)");
        bytes32 attempted = keccak256(
            "ImmediateRevealAttempt(uint16,uint256,uint256,bool,bytes32,uint256,uint256,bytes)"
        );
        uint256 registrations;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 0) continue;
            require(
                logs[i].emitter != address(sale) || logs[i].topics[0] != attempted,
                "sale never attempts an at-mint entropy request"
            );
            if (logs[i].emitter != address(actualEntropy) || logs[i].topics[0] != registered) {
                continue;
            }
            ++registrations;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == bytes32(uint256(1))
                    && logs[i].topics[3] == actualEntropy.collectionEntropyPolicy(1).policyHash
                    && keccak256(logs[i].data) == keccak256(abi.encode(uint16(2), uint8(status))),
                "one genuine Coordinator policy registration receipt"
            );
        }
        require(registrations == 1, "exactly one actual token registration");
    }

    function _paid(Packet memory p, uint256 nativeFee, StreamEntropyStatus status)
        private
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        vm.recordLogs();
        vm.prank(executor);
        (bool ok, bytes memory raw) = address(payment).call{ value: nativeFee + EXCESS }(p.input);
        require(ok && raw.length == 384, "original signed ERC20 intent executes");
        result = abi.decode(raw, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        _mintEvents(vm.getRecordedLogs(), status);
        _noDraw(status);
        require(
            core.ownerOf(1) == p.execution.authorization.recipient && core.totalSupply() == 1
                && core.collectionNextSerial(1) == 2
                && core.coordinatorAtMint(1) == address(actualEntropy)
                && manager.nextOperationNonce() == 1 && ledger.counterValue(_counter()) == 1
                && ledger.isManagerOperationRootUsed(
                    address(manager), p.candidate.operationIdentityCommitment
                ),
            "genuine Core Manager and Ledger operation"
        );
        require(
            result.asset == address(token) && result.amount == PRICE && result.executor == executor
                && result.operationIdentityCommitment == p.candidate.operationIdentityCommitment
                && result.settlementKey
                    == recorder.settlementKey(
                        address(sale), p.candidate.executionBinding.executionId
                    ) && !result.escrowed && recorder.settlementConsumed(result.settlementKey)
                && keccak256(abi.encode(recorder.settlementResult(result.settlementKey)))
                == keccak256(abi.encode(result)) && token.rawBalance(payer) == 9000
                && token.rawBalance(wallet) == PRICE && token.rawBalance(address(payment)) == 0
                && token.rawBalance(address(recorder)) == 0
                && token.allowance(payer, address(payment)) == 9000 && token.transferCalls() == 3
                && recorder.totalOfficialSettled(address(token)) == PRICE
                && recorder.officialSettled(CLASS, profile, wallet, address(token)) == PRICE,
            "full token-only receipt and exact original revenue"
        );
        require(
            actualEntropy.revealFeeEscrow(1) == nativeFee
                && actualEntropy.totalRevealFeeEscrows() == nativeFee
                && address(actualEntropy).balance == nativeFee
                && actualEntropy.totalFeeCredits() == 0 && address(instantProvider).balance == 0
                && address(asyncProvider).balance == 0
                && sale.refundableBalance(saleId, executor) == EXCESS
                && sale.refundableBalance(saleId, payer) == 0 && sale.refundLiability() == EXCESS
                && address(sale).balance == EXCESS && address(payment).balance == 0
                && payer.balance == 73 && executor.balance == 0,
            "native fee escrow and executor-only excess are separate from token payer revenue"
        );
        require(
            payment.isPaymentIntentNonceUsed(payer, p.intent.nonce)
                && sale.authorizationUsed(vm.addr(SIGNER_KEY), p.execution.authorization.nonce)
                && sale.executionStatus(p.candidate.executionBinding.executionId) == 2,
            "original payment and sale replay guards consumed"
        );
    }

    function _claim() private {
        vm.prank(executor);
        sale.claimRefund(saleId, executor);
        require(
            executor.balance == EXCESS && payer.balance == 73 && sale.refundLiability() == 0
                && address(sale).balance == 0 && sale.refundableBalance(saleId, executor) == 0,
            "only native executor pulls full excess"
        );
    }

    function _success(ModePolicy.Mode mode, bool required) private {
        uint256 fee = _configure(mode, required);
        vm.deal(executor, fee + EXCESS);
        StreamEntropyStatus status = mode == ModePolicy.Mode.DISABLED
            ? StreamEntropyStatus.DISABLED
            : required ? StreamEntropyStatus.REGISTERED : StreamEntropyStatus.NOT_REQUIRED;
        _paid(_packet(payer), fee, status);
        _claim();
    }

    function testActualERC20DisabledRegistersTerminalAndReturnsAllNativeAllowance() public {
        _success(ModePolicy.Mode.DISABLED, false);
    }

    function testActualERC20InstantNotRequiredHasNoRequestSeedOrNativeFee() public {
        _success(ModePolicy.Mode.INSTANT, false);
    }

    function testActualERC20AsyncNotRequiredFundsExactEscrowWithoutAtMintRequest() public {
        _success(ModePolicy.Mode.ASYNC, false);
    }

    function testActualERC20InstantRegistersThenOriginalProviderFinalizesOnlyInLaterBlock() public {
        _success(ModePolicy.Mode.INSTANT, true);
        bytes memory request = abi.encodeCall(actualEntropy.requestEntropy, (uint256(1)));
        vm.prank(executor);
        (bool ok, bytes memory reason) = address(actualEntropy).call(request);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamEntropyCoordinator.InstantEntropyBeforeDelivery.selector,
                            uint256(1)
                        )
                    ),
            "real same-block request refuses"
        );
        _noDraw(StreamEntropyStatus.REGISTERED);
        vm.roll(block.number + 1);
        calls.expectCall(
            address(instantProvider),
            0,
            abi.encodeWithSelector(IStreamInstantEntropyProvider.instantEntropy.selector),
            1
        );
        vm.prank(executor);
        (ok, reason) = address(actualEntropy).call(request);
        require(
            ok && reason.length == 64,
            "identical later-block request calls original Instant provider"
        );
        (bytes32 key, uint256 id) = abi.decode(reason, (bytes32, uint256));
        (
            StreamEntropyStatus status,
            bytes32 seed,
            address provider_,,,,
            uint256 storedId,
            uint16 attempt
        ) = actualEntropy.tokenEntropy(1);
        (bytes32 seedRead, bool finalized) = actualEntropy.tokenSeed(1);
        require(
            key != 0 && id != 0 && status == StreamEntropyStatus.FINALIZED && seed != 0
                && seedRead == seed && finalized && provider_ == address(instantProvider)
                && storedId == id && attempt == 1
                && actualEntropy.providerRequestKeys(address(instantProvider), id) == key
                && actualEntropy.pendingRequestCount() == 0
                && actualEntropy.nonterminalTokenCount(1) == 0,
            "production Instant draw finalizes the same actual ERC20 token"
        );
        require(
            token.rawBalance(wallet) == PRICE
                && recorder.totalOfficialSettled(address(token)) == PRICE
                && manager.nextOperationNonce() == 1 && executor.balance == EXCESS
                && payer.balance == 73 && actualEntropy.totalFeeCredits() == 0
                && actualEntropy.totalRevealFeeEscrows() == 0,
            "later draw preserves paid token revenue and closed native refund"
        );
    }

    function _recipientRollback(ModePolicy.Mode mode, bool required) private {
        uint256 fee = _configure(mode, required);
        StreamEntropyStatus status =
            required ? StreamEntropyStatus.REGISTERED : StreamEntropyStatus.NOT_REQUIRED;
        CurrentERC20EntropyReceiver receiver = new CurrentERC20EntropyReceiver(
            core, actualEntropy, actualEntropy.collectionEntropyPolicy(1).policyHash, status
        );
        Packet memory p = _packet(address(receiver));
        vm.deal(executor, fee + EXCESS);
        calls.expectCall(
            address(receiver),
            0,
            abi.encodeWithSelector(IERC721Receiver.onERC721Received.selector),
            2
        );
        calls.expectCall(address(token), 0, abi.encodeCall(token.transfer, (wallet, PRICE)), 2);
        vm.prank(executor);
        (bool ok,) = address(payment).call{ value: fee + EXCESS }(p.input);
        bytes32 key =
            recorder.settlementKey(address(sale), p.candidate.executionBinding.executionId);
        require(
            !ok && receiver.deliveries() == 0 && core.lastAllocatedTokenId() == 0
                && core.collectionNextSerial(1) == 1 && core.totalSupply() == 0
                && core.coordinatorAtMint(1) == address(0) && manager.nextOperationNonce() == 0
                && ledger.counterValue(_counter()) == 0
                && !ledger.isManagerOperationRootUsed(
                    address(manager), p.candidate.operationIdentityCommitment
                ),
            "actual recipient rejection rolls back real Core Manager and Ledger"
        );
        require(
            actualEntropy.tokenEntropyStatus(1) == StreamEntropyStatus.NONE
                && actualEntropy.registeredAtBlock(1) == 0
                && actualEntropy.pendingRequestCount() == 0
                && actualEntropy.nonterminalTokenCount(1) == 0
                && !actualEntropy.collectionEntropyPolicy(1).frozen
                && actualEntropy.revealFeeEscrow(1) == 0
                && actualEntropy.totalRevealFeeEscrows() == 0 && address(actualEntropy).balance == 0
                && asyncProvider.nextRequestId() == 1,
            "actual Coordinator registration and automatic policy lock roll back"
        );
        require(
            !payment.isPaymentIntentNonceUsed(payer, p.intent.nonce)
                && !sale.authorizationUsed(vm.addr(SIGNER_KEY), p.execution.authorization.nonce)
                && sale.executionIdByNonce(saleId, 1) == 0
                && sale.executionStatus(p.candidate.executionBinding.executionId) == 0
                && !recorder.settlementConsumed(key)
                && recorder.totalOfficialSettled(address(token)) == 0
                && token.rawBalance(payer) == 10000 && token.rawBalance(wallet) == 0
                && token.allowance(payer, address(payment)) == 10000
                && token.rawBalance(address(payment)) == 0
                && token.rawBalance(address(recorder)) == 0 && executor.balance == fee + EXCESS
                && payer.balance == 73 && sale.refundLiability() == 0 && address(sale).balance == 0
                && address(payment).balance == 0,
            "all original token native receipt and replay state rolls back"
        );
        receiver.accept();
        _paid(p, fee, status);
        require(
            receiver.deliveries() == 1 && token.transferCalls() == 3,
            "byte-identical signed intent retries with one effective payment and delivery"
        );
        _claim();
        vm.deal(executor, fee + EXCESS);
        vm.prank(executor);
        bytes memory replayReason;
        (ok, replayReason) = address(payment).call{ value: fee + EXCESS }(p.input);
        require(
            !ok
                && keccak256(replayReason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamERC20PrimarySettlementAdapter.PaymentIntentNonceUsed.selector,
                            payer,
                            p.intent.nonce
                        )
                    ) && receiver.deliveries() == 1 && token.rawBalance(wallet) == PRICE
                && manager.nextOperationNonce() == 1 && executor.balance == fee + EXCESS,
            "funded identical replay reaches the consumed payment-intent guard"
        );
    }

    function testActualERC20InstantRecipientRejectionRollsBackRegistrationAndSameIntentRetries()
        public
    {
        _recipientRollback(ModePolicy.Mode.INSTANT, true);
    }

    function testActualERC20AsyncNotRequiredRecipientRejectionRollsBackAndSameIntentRetries()
        public
    {
        _recipientRollback(ModePolicy.Mode.ASYNC, false);
    }
}
