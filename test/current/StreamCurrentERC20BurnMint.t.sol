// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/NativeCuratedSaleFixture.sol";
import {
    StreamERC20BurnMintSale
} from "../../smart-contracts/domains/mint/StreamERC20BurnMintSale.sol";
import {
    StreamERC20BurnMintGate
} from "../../smart-contracts/domains/mint/StreamERC20BurnMintGate.sol";
import {
    StreamERC20BurnMintTypes as E,
    U,
    S
} from "../../smart-contracts/interfaces/stream/mint/StreamERC20BurnMintTypes.sol";
import {
    IStreamBurnMintGate as B
} from "../../smart-contracts/interfaces/stream/mint/IStreamBurnMintGate.sol";
import {
    StreamERC20PrimarySettlementAdapter
} from "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import {
    IStreamERC20PrimarySettlementAdapter
} from "../../smart-contracts/interfaces/stream/revenue/IStreamERC20PrimarySettlementAdapter.sol";
import {
    IStreamERC20SaleExecution
} from "../../smart-contracts/interfaces/stream/revenue/IStreamERC20SaleExecution.sol";
import {
    StreamPrimarySettlementHash
} from "../../smart-contracts/domains/revenue/StreamPrimarySettlementHash.sol";
import { MockStreamPaymentToken } from "../mocks/MockStreamPaymentToken.sol";
import { UniversalPermitToken } from "../helpers/UniversalSettlementTestMocks.sol";
import { OfficialPermit2Fixture } from "../helpers/OfficialPermit2Fixture.sol";
import {
    IStreamPinnedPermit2
} from "../../smart-contracts/interfaces/stream/revenue/IStreamPinnedPermit2.sol";

interface CurrentERC20BurnEventVm {
    function expectCall(address target, uint256 value, bytes calldata input, uint64 count) external;
    function expectEmit(bool, bool, bool, bool, address) external;
}

/// @dev Controlled final receiver; actual threshold Safe ownership and signatures are tested below.
contract CurrentERC20BurnReceiver is IERC721Receiver {
    StreamERC20BurnMintSale private carrier;
    StreamCore private core;
    address private artist;
    bytes32 private nonce;
    uint256 private source;
    bool public rejects;
    bool public sawConsumedAndBurned;
    bool public callbackSucceeded;
    bytes private continuation;

    function configure(
        StreamERC20BurnMintSale carrier_,
        StreamCore core_,
        address artist_,
        bytes32 nonce_,
        uint256 source_,
        bool reject_,
        bytes calldata callback
    ) external {
        carrier = carrier_;
        core = core_;
        artist = artist_;
        nonce = nonce_;
        source = source_;
        rejects = reject_;
        continuation = callback;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        (,,, bool burned) = core.tokenCollectionIdentity(source);
        sawConsumedAndBurned = carrier.authorizationUsed(artist, nonce) && burned;
        if (continuation.length != 0) (callbackSucceeded,) = address(carrier).call(continuation);
        require(!rejects, "ERC20 burn receiver rejected");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual current Core, Manager, Ledger, Registry, contract20, recorder, Resolver and wallet.
/// @dev Artist exact-consent, entropy and governance-context boundaries are inherited explicitly.
///      Source tokens are actually minted and burned on Core; no mint/burn/payment mocks are used.
contract StreamCurrentERC20BurnMintTest is NativeCuratedSaleFixture, OfficialPermit2Fixture {
    StreamERC20BurnMintSale private burnSale;
    StreamERC20BurnMintGate private burnGate;
    StreamERC20PrimarySettlementAdapter private payment;
    MockStreamPaymentToken private token;
    bytes32 private constant SEED_PHASE = keccak256("current ERC20 burn seed");
    bytes32 private constant BURN_PHASE = keccak256("current ERC20 paid burn");
    uint256 private constant EXECUTOR_KEY = 0xE320B;
    uint256 private seedNonce;
    bytes32 private saleId;

    event BurnMintExecuted(
        uint16 schemaVersion,
        uint256 indexed sourceTokenId,
        uint256 indexed mintedTokenId,
        uint256 indexed targetCollectionId,
        bytes32 burnNullifier,
        address redeemer
    );

    function setUp() public override {
        super.setUp();
        entropy.configure(0, 1, false, false);
        token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("current ERC20 burn token"), 0);
        payment = new StreamERC20PrimarySettlementAdapter(recorder, address(0), 0);
        _registerPayment();
        burnSale = new StreamERC20BurnMintSale(
            manager,
            recorder,
            vm.addr(AUCTION_PLATFORM_KEY),
            artists,
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig("REVEAL_ATTEMPT_GAS_LIMIT", 200000, 50000, 2)
        );
        _register(
            address(burnSale),
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        burnGate = new StreamERC20BurnMintGate(
            StreamERC20BurnMintGate.Configuration(
                address(core),
                address(registry),
                address(burnSale),
                address(revenueAuthority),
                address(this),
                MANIFEST,
                MANIFEST,
                "urn:current:erc20-burn",
                IStreamGasParameterHost.GasParameterConfig(
                    "BURN_DEPENDENCY_READ_GAS", 300000, 100000, 2
                ),
                IStreamGasParameterHost.GasParameterConfig("BURN_EXECUTION_GAS", 2000000, 200000, 2)
            )
        );
        StreamModuleRegistration memory registration = StreamModuleRegistration(
            address(burnGate),
            burnGate.streamModuleType(),
            burnGate.streamModuleVersion(),
            type(IStreamMintGate).interfaceId,
            800000,
            address(burnGate).codehash,
            MANIFEST,
            MANIFEST,
            "urn:current:erc20-burn"
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(registration);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        registry.registerModule(registration);
        _clearContext();
        uint256[] memory collections = new uint256[](1);
        collections[0] = 1;
        bytes32 configHash = burnGate.configureProgram(
            B.ProgramConfig(
                address(manager), 1, BURN_PHASE, collections, 1, 0, 0, false, address(0)
            )
        );
        _configurePhase(SEED_PHASE, address(this), address(0), 0);
        _configurePhase(BURN_PHASE, address(burnSale), address(burnGate), configHash);
        token.mint(payer, 10000);
        vm.prank(payer);
        token.approve(address(payment), 10000);
    }

    function testBurnRejectsNativeValueAndSameSignedPaymentSucceedsWithZeroValue() public {
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        bytes memory exact = abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, abi.encode(e)));
        vm.deal(payer, 1);
        vm.deal(address(payment), 17);
        vm.deal(address(burnSale), 23);
        CurrentERC20BurnEventVm(address(vm)).expectCall(address(token), 0,
            abi.encodeCall(token.transferFrom, (payer, address(payment), uint256(1000))), 1);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(burnSale).call{value: 1}(
            abi.encodeCall(burnSale.executeERC20PreRevenueSingleStep, (c, abi.encode(e))));
        require(!ok && reason.length == 0, "original nonpayable callback empty revert");
        _assertUnused(e, c, 0);
        vm.prank(payer);
        (ok, reason) = address(payment).call{value: 1}(exact);
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(
            StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector)), "unsupported callback value");
        _assertUnused(e, c, 0);
        require(payer.balance == 1 && address(payment).balance == 17 && address(burnSale).balance == 23,
            "no value retained or source burned; original surplus preserved");
        vm.prank(payer);
        (ok, reason) = address(payment).call(exact);
        require(ok, "same signed payment accepts original zero-value burn route");
        _assertExecuted(e, c, abi.decode(reason, (S.PrimarySettlementResult)));
        require(payer.balance == 1 && address(payment).balance == 17 && address(burnSale).balance == 23,
            "zero-value burn preserves native balances");
    }

    function testActualPaidBurnRetainsOriginalProgramAuthorizationAndOfficialReceipt() public {
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        B.Program memory program = burnGate.program(1);
        require(
            program.configHash == burnGate.programConfigHash(program.config)
                && !program.config.prepared && program.config.nativeSaleAdapter == address(0)
                && burnGate.erc20SaleAdapter() == address(burnSale)
                && burnGate.erc20SaleCodeHash() == address(burnSale).codehash,
            "original immutable program and dedicated carrier identity"
        );
        require(
            c.saleExecutionHash == keccak256(abi.encode(e)) && c.orchestrationOrder == 1
                && c.sale.tokenId == 0 && c.sale.policyMode == 0
                && c.executionBinding.executionId == StreamPrimarySettlementHash.executionId(c),
            "original execution and source commitment"
        );
        require(
            _independentDigest(e.sale.authorization)
                == burnSale.authorizationDigest(e.sale.authorization),
            "original universal EIP712 domain and fields"
        );
        CurrentERC20BurnEventVm(address(vm)).expectEmit(true, true, true, true, address(burnGate));
        emit BurnMintExecuted(
            1, e.sourceTokenIds[0], 2, 1, burnGate.burnNullifier(e.sourceTokenIds[0]), payer
        );
        vm.prank(payer);
        S.PrimarySettlementResult memory r = payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        _assertExecuted(e, c, r);
    }

    function testPreviewLeavesNoBurnReplayOrReusableMintProof() public {
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory first = burnSale.previewExecution(e);
        S.ERC20SettlementCandidate memory second = burnSale.previewExecution(e);
        require(
            keccak256(abi.encode(first)) == keccak256(abi.encode(second)), "stable simulated result"
        );
        _assertUnused(e, first, 0);
        vm.expectRevert();
        burnSale.previewBurnExecution(e);
        vm.expectRevert();
        burnSale.executeBurnMint(e);
        IStreamMintManager.MintBatch memory batch = _burnBatch(e);
        vm.expectRevert();
        vm.prank(address(burnSale));
        manager.executeSingleStepMint(batch, "");
        _assertUnused(e, first, 0);
    }

    function testSignedExecutorNeedsSourceAuthoritySeparatelyFromGateApproval() public {
        E.Execution memory e = _open(payer, vm.addr(EXECUTOR_KEY), payer);
        vm.expectRevert();
        burnSale.previewExecution(e);
        address actor = e.sale.authorization.executor;
        vm.prank(payer);
        core.setApprovalForAll(actor, true);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        S.PaymentIntent memory intent = _intent(e, 1);
        bytes memory signature = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        vm.expectRevert();
        vm.prank(actor);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        vm.prank(actor);
        S.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleWithIntent(c, intent, signature, abi.encode(e));
        _assertExecuted(e, c, r);
        require(
            payment.isPaymentIntentNonceUsed(payer, intent.nonce),
            "payer intent consumed independently"
        );
    }

    function testRevokedExecutorApprovalRestoresIntentAndAllBurnMintEffects() public {
        E.Execution memory e = _open(payer, vm.addr(EXECUTOR_KEY), payer);
        address actor = e.sale.authorization.executor;
        vm.prank(payer);
        core.setApprovalForAll(actor, true);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        S.PaymentIntent memory intent = _intent(e, 2);
        bytes memory sig = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        vm.prank(payer);
        core.setApprovalForAll(actor, false);
        vm.expectRevert();
        vm.prank(actor);
        payment.settleERC20PrimarySaleWithIntent(c, intent, sig, abi.encode(e));
        _assertUnused(e, c, intent.nonce);
        vm.prank(payer);
        core.setApprovalForAll(actor, true);
        vm.prank(actor);
        _assertExecuted(
            e, c, payment.settleERC20PrimarySaleWithIntent(c, intent, sig, abi.encode(e))
        );
    }

    function testMissingGateApprovalFailsBeforePullAndBurn() public {
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        vm.prank(payer);
        core.setApprovalForAll(address(burnGate), false);
        vm.expectRevert();
        burnSale.previewExecution(e);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        _assertUnused(e, c, 0);
        require(token.transferCalls() == 0, "no transfer before source validation");
    }

    function testChangedSourcesRecipientExecutorAndCandidateCannotUseQuotedExecution() public {
        E.Execution memory original = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(original);
        uint256 other = _seed(payer);
        for (uint256 i; i < 5; ++i) {
            E.Execution memory e = abi.decode(abi.encode(original), (E.Execution));
            S.ERC20SettlementCandidate memory changed =
                abi.decode(abi.encode(c), (S.ERC20SettlementCandidate));
            if (i == 0) e.sourceTokenIds[0] = other;
            if (i == 1) e.sale.authorization.recipient = address(0xBAD);
            if (i == 2) e.sale.authorization.executor = address(0xBAD);
            if (i == 3) changed.sale.amount++;
            if (i == 4) changed.saleExecutionHash = keccak256("changed source commitment");
            vm.expectRevert();
            vm.prank(payer);
            payment.settleERC20PrimarySaleByPayer(changed, abi.encode(e));
            require(
                core.ownerOf(original.sourceTokenIds[0]) == payer && core.ownerOf(other) == payer
                    && !burnSale.authorizationUsed(
                        e.sale.authorization.artist, e.sale.authorization.nonce
                    ) && recorder.totalOfficialSettled(address(token)) == 0,
                "changed transcript rolled back"
            );
        }
    }

    function testPreburnWrongInputCountAndUnknownSourceIdsCannotQualify() public {
        E.Execution memory e = _open(payer, payer, payer);
        uint256 source = e.sourceTokenIds[0];
        vm.prank(payer);
        core.burn(source);
        vm.expectRevert();
        burnSale.previewExecution(e);
        e.sourceTokenIds = new uint256[](2);
        e.sourceTokenIds[0] = 2;
        e.sourceTokenIds[1] = 1;
        vm.expectRevert();
        burnSale.previewExecution(e);
        e.sourceTokenIds[1] = 2;
        vm.expectRevert();
        burnSale.previewExecution(e);
        e.sourceTokenIds = new uint256[](1);
        e.sourceTokenIds[0] = type(uint256).max;
        vm.expectRevert();
        burnSale.previewExecution(e);
        require(
            !manager.isNullifierUsed(burnGate.burnNullifier(source))
                && token.balanceOf(payer) == 10000,
            "preburn creates no entitlement or payment"
        );
    }

    function testTransferredSourceAfterPreviewRejectsEvenWithPayerIntent() public {
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        S.PaymentIntent memory intent = _intent(e, 6);
        bytes memory sig = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        address newOwner = address(0xB0B);
        uint256 source = e.sourceTokenIds[0];
        vm.prank(payer);
        core.transferFrom(payer, newOwner, source);
        vm.prank(newOwner);
        core.setApprovalForAll(address(burnGate), true);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithIntent(c, intent, sig, abi.encode(e));
        require(
            core.ownerOf(source) == newOwner && core.lastAllocatedTokenId() == 1
                && !manager.isNullifierUsed(burnGate.burnNullifier(source))
                && !burnSale.authorizationUsed(
                    e.sale.authorization.artist, e.sale.authorization.nonce
                ) && !payment.isPaymentIntentNonceUsed(payer, intent.nonce)
                && token.balanceOf(payer) == 10000,
            "payment authority cannot spend new owner's source"
        );
    }

    function testSaleReplayCannotBurnFreshSourceOrMoveAnotherPayment() public {
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        uint256 freshSource = _seed(payer);
        e.sourceTokenIds[0] = freshSource;
        vm.expectRevert();
        burnSale.previewExecution(e);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        require(
            core.ownerOf(freshSource) == payer && core.lastAllocatedTokenId() == 3
                && !manager.isNullifierUsed(burnGate.burnNullifier(freshSource))
                && token.balanceOf(payer) == 9000
                && recorder.totalOfficialSettled(address(token)) == 1000,
            "consumed original authorization cannot spend fresh burn inputs"
        );
    }

    function testReceiverFailureRestoresBurnPaymentEveryReplayAndIdenticalRetry() public {
        CurrentERC20BurnReceiver receiver = new CurrentERC20BurnReceiver();
        E.Execution memory e = _open(payer, payer, address(receiver));
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        S.PaymentIntent memory intent = _intent(e, 3);
        bytes memory sig = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        bytes memory callback = abi.encodeCall(burnSale.executeBurnMint, (e));
        receiver.configure(
            burnSale,
            core,
            e.sale.authorization.artist,
            e.sale.authorization.nonce,
            e.sourceTokenIds[0],
            true,
            callback
        );
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithIntent(c, intent, sig, abi.encode(e));
        _assertUnused(e, c, intent.nonce);
        receiver.configure(
            burnSale,
            core,
            e.sale.authorization.artist,
            e.sale.authorization.nonce,
            e.sourceTokenIds[0],
            false,
            callback
        );
        vm.prank(payer);
        _assertExecuted(
            e, c, payment.settleERC20PrimarySaleWithIntent(c, intent, sig, abi.encode(e))
        );
        require(
            receiver.sawConsumedAndBurned() && !receiver.callbackSucceeded(),
            "outbound receiver sees reserved sale and completed burns but cannot reenter continuation"
        );
    }

    function testNonzeroNativeFeeRejectsBeforePullOrBurnAndSameCandidateRetries() public {
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        // Only the healthy retry may reach the first payer-to-payment token pull.
        CurrentERC20BurnEventVm(address(vm)).expectCall(address(token), 0,
            abi.encodeCall(token.transferFrom, (payer, address(payment), uint256(1000))), 1);
        entropy.configure(7, 1, false, false);
        vm.expectRevert();
        burnSale.previewExecution(e);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        _assertUnused(e, c, 0);
        require(token.transferCalls() == 0, "fee refusal rolls token state back");
        entropy.configure(0, 1, false, false);
        vm.prank(payer);
        _assertExecuted(e, c, payment.settleERC20PrimarySaleByPayer(c, abi.encode(e)));
    }

    function testTokenExactDeltaFailureRestoresBurnAndAuthorizationForIdenticalRetry() public {
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        S.PaymentIntent memory intent = _intent(e, 4);
        bytes memory sig = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        token.configure(3, 1);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithIntent(c, intent, sig, abi.encode(e));
        _assertUnused(e, c, intent.nonce);
        token.configure(0, 0);
        vm.prank(payer);
        _assertExecuted(
            e, c, payment.settleERC20PrimarySaleWithIntent(c, intent, sig, abi.encode(e))
        );
    }

    function testFeeRaisedByTokenCallbackRollsBackAlreadyBurnedSourceAndPayment() public {
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        token.configureCallback(
            address(entropy),
            abi.encodeCall(entropy.configure, (uint256(7), uint8(1), false, false)),
            1
        );
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        _assertUnused(e, c, 0);
        token.configureCallback(address(0), "", 0);
        vm.prank(payer);
        _assertExecuted(e, c, payment.settleERC20PrimarySaleByPayer(c, abi.encode(e)));
    }

    function testCancelledArtistAuthorizationAndSaleCannotConsumeBurnInputs() public {
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        address artist = e.sale.authorization.artist;
        vm.prank(artist);
        burnSale.cancelAuthorization(e.sale.authorization.nonce);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        require(
            core.ownerOf(e.sourceTokenIds[0]) == payer && token.balanceOf(payer) == 10000,
            "artist cancellation never spends payer assets"
        );
        e.sale.authorization.nonce = keccak256("fresh artist nonce");
        _sign(e);
        c = burnSale.previewExecution(e);
        burnSale.cancelSale(saleId);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        _assertUnused(e, c, 0);
    }

    function testActualTwoOfTwoSafeSourceOwnerArtistAndPayerExactTransactionRetry() public {
        (OfficialSafe buyer, uint256[] memory buyerKeys) = _safe(840);
        (OfficialSafe artist, uint256[] memory artistKeys) = _safe(841);
        NativeCuratedArtistBoundary(address(artists)).accept(address(artist));
        token.mint(address(buyer), 10000);
        require(
            executeSafe(
                buyer,
                buyerKeys,
                address(token),
                0,
                abi.encodeCall(token.approve, (address(payment), 10000)),
                0
            ),
            "Safe payment approval"
        );
        E.Execution memory e = _open(address(buyer), address(buyer), address(buyer));
        e.sale.artistSignature = safeThresholdSignature(
            artistKeys,
            safeMessageDigest(
                artist, abi.encode(burnSale.authorizationDigest(e.sale.authorization))
            )
        );
        _approveSafeSources(buyer, buyerKeys, address(burnGate));
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        bytes memory exact = _safePayload(
            buyer,
            buyerKeys,
            address(payment),
            abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, abi.encode(e)))
        );
        uint256 beforeNonce = buyer.nonce();
        entropy.configure(0, 1, true, false);
        (bool ok,) = address(buyer).call(exact);
        require(
            !ok && buyer.nonce() == beforeNonce && artist.nonce() == 0, "all Safe nonces restored"
        );
        _assertUnused(e, c, 0);
        entropy.configure(0, 1, false, false);
        bytes memory raw;
        (ok, raw) = address(buyer).call(exact);
        require(
            ok && abi.decode(raw, (bool)) && buyer.nonce() == beforeNonce + 1,
            "byte-identical threshold Safe transaction retries"
        );
        _assertExecuted(e, c, recorder.settlementResult(_settlementKey(c)));
    }

    function testActualSafePayerIntentDoesNotSubstituteForSourceExecutorAuthority() public {
        (OfficialSafe buyer, uint256[] memory keys) = _safe(842);
        address actor = vm.addr(EXECUTOR_KEY);
        token.mint(address(buyer), 10000);
        require(
            executeSafe(
                buyer,
                keys,
                address(token),
                0,
                abi.encodeCall(token.approve, (address(payment), 10000)),
                0
            ),
            "Safe allowance"
        );
        E.Execution memory e = _open(address(buyer), actor, address(buyer));
        _approveSafeSources(buyer, keys, address(burnGate));
        vm.expectRevert();
        burnSale.previewExecution(e);
        _approveSafeSources(buyer, keys, actor);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        S.PaymentIntent memory intent = _intent(e, 5);
        bytes memory sig = safeThresholdSignature(
            keys, safeMessageDigest(buyer, abi.encode(payment.paymentIntentDigest(intent)))
        );
        uint256 nonce = buyer.nonce();
        vm.prank(actor);
        _assertExecuted(
            e, c, payment.settleERC20PrimarySaleWithIntent(c, intent, sig, abi.encode(e))
        );
        require(
            buyer.nonce() == nonce
                && payment.isPaymentIntentNonceUsed(address(buyer), intent.nonce),
            "actual Safe1271 payer proof consumes only payment nonce"
        );
    }

    function testEIP2612LateMintFailureRestoresPermitSourceAndAllReplayForRetry() public {
        UniversalPermitToken permitToken = new UniversalPermitToken();
        token = MockStreamPaymentToken(address(permitToken));
        _setAssetPolicy(policy, address(token), 1, keccak256("ERC20 burn EIP2612"), 0);
        _permitPolicy(1, 0, address(0));
        token.mint(payer, 10000);
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        uint64 deadline = e.sale.authorization.deadline;
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(PAYER_KEY, permitToken.permitDigest(payer, address(payment), 1000, deadline));
        S.EIP2612PermitAuthorization memory permit = S.EIP2612PermitAuthorization(deadline, v, r, s);
        entropy.configure(0, 1, true, false);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithEIP2612Permit(c, permit, abi.encode(e));
        _assertUnused(e, c, 0);
        require(
            permitToken.nonces(payer) == 0 && permitToken.allowance(payer, address(payment)) == 0,
            "exact permit nonce and allowance restored"
        );
        entropy.configure(0, 1, false, false);
        vm.prank(payer);
        _assertExecuted(
            e, c, payment.settleERC20PrimarySaleWithEIP2612Permit(c, permit, abi.encode(e))
        );
        require(
            permitToken.nonces(payer) == 1 && permitToken.allowance(payer, address(payment)) == 0,
            "one exact permit consumed"
        );
    }

    function testPinnedOfficialPermit2LateFailureAndExactFiniteAllowanceRetry() public {
        address permit2 = deployOfficialPermit2();
        payment = new StreamERC20PrimarySettlementAdapter(recorder, permit2, permit2.codehash);
        _registerPayment();
        _permitPolicy(2, 1, permit2);
        vm.prank(payer);
        token.approve(permit2, 4000);
        E.Execution memory e = _open(payer, payer, payer);
        S.ERC20SettlementCandidate memory c = burnSale.previewExecution(e);
        S.Permit2TransferAuthorization memory permit;
        permit.nonce = 34;
        permit.deadline = e.sale.authorization.deadline;
        bytes32 permissions = keccak256(
            abi.encode(
                keccak256("TokenPermissions(address token,uint256 amount)"),
                address(token),
                uint256(1000)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
                ),
                permissions,
                address(payment),
                permit.nonce,
                permit.deadline
            )
        );
        permit.signature = _curatedSignature(
            PAYER_KEY, keccak256(abi.encodePacked(hex"1901", permit2Domain(permit2), body))
        );
        entropy.configure(0, 1, true, false);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithPermit2(c, permit, abi.encode(e));
        _assertUnused(e, c, 0);
        require(
            IStreamPinnedPermit2(permit2).nonceBitmap(payer, 0) == 0
                && token.allowance(payer, permit2) == 4000,
            "Permit2 state fully restored"
        );
        entropy.configure(0, 1, false, false);
        vm.prank(payer);
        _assertExecuted(e, c, payment.settleERC20PrimarySaleWithPermit2(c, permit, abi.encode(e)));
        require(
            IStreamPinnedPermit2(permit2).nonceBitmap(payer, 0) == uint256(1) << 34
                && token.allowance(payer, permit2) == 3000,
            "finite exact original Permit2 allowance"
        );
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithPermit2(c, permit, abi.encode(e));
        require(
            token.balanceOf(payer) == 9000 && core.lastAllocatedTokenId() == 2,
            "payment replay cannot burn or mint again"
        );
    }

    function _registerPayment() private {
        _register(
            address(payment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
    }

    function _configurePhase(bytes32 phase, address executor_, address gate, bytes32 hash) private {
        IStreamMintManager.MintGateConfig memory g;
        g.gate = gate;
        g.gateConfigHash = hash;
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = keccak256(abi.encode("ERC20 burn cap", phase));
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            100,
            1,
            MANIFEST
        );
        manager.configurePhase(
            1,
            phase,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            g,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, phase, executor_, true);
    }

    function _seed(address owner) private returns (uint256 source) {
        IStreamMintManager.MintBatch memory b;
        b.collectionId = 1;
        b.phaseId = SEED_PHASE;
        b.payer = owner;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = owner;
        b.beneficiaries = b.initialRecipients;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = bytes("actual original burn source");
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = keccak256(abi.encode("source commitment", ++seedNonce));
        b.authorizationId = keccak256(abi.encode("source authorization", seedNonce));
        b.expectedPolicyHash = manager.phasePolicyHash(1, SEED_PHASE);
        (uint256[] memory ids,,) = manager.executeSingleStepMint(b, "");
        source = ids[0];
    }

    function _open(address payer_, address actor, address recipient)
        private
        returns (E.Execution memory e)
    {
        U.SaleConfig memory config = U.SaleConfig(
            address(payment),
            1,
            BURN_PHASE,
            address(token),
            1000,
            uint64(this.burnTime()),
            uint64(this.burnTime() + 1 days),
            manager.phasePolicyHash(1, BURN_PHASE),
            StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1)
        );
        saleId = burnSale.registerSale(config);
        U.SaleRecord memory record = burnSale.saleRecord(saleId);
        _bindCuratedConsent(saleId, record.configHash);
        e.sourceTokenIds = new uint256[](1);
        e.sourceTokenIds[0] = _seed(payer_);
        if (payer_.code.length == 0) {
            vm.prank(payer_);
            core.setApprovalForAll(address(burnGate), true);
        }
        e.sale.tokenData = bytes("actual new paid burn work");
        e.sale.authorization = U.SaleAuthorization(
            saleId,
            record.configHash,
            payer_,
            actor,
            recipient,
            artists.acceptedArtist(1),
            keccak256(e.sale.tokenData),
            keccak256("paid burn commitment"),
            1,
            keccak256(abi.encode("paid burn authorization", saleId)),
            config.endsAt
        );
        _sign(e);
    }

    function _sign(E.Execution memory e) private {
        bytes32 digest = burnSale.authorizationDigest(e.sale.authorization);
        e.sale.platformSignature = _curatedSignature(AUCTION_PLATFORM_KEY, digest);
        e.sale.artistSignature = _curatedSignature(SIGNER_KEY, digest);
    }

    function _intent(E.Execution memory e, uint256 nonce)
        private
        view
        returns (S.PaymentIntent memory)
    {
        U.SaleConfig memory config = burnSale.saleRecord(e.sale.authorization.saleId).config;
        return S.PaymentIntent(
            e.sale.authorization.payer,
            config.asset,
            config.price,
            e.sale.authorization.saleId,
            config.expectedPrimaryPolicyHash,
            bytes32(nonce),
            config.endsAt
        );
    }

    function _authorizationId(E.Execution memory e) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
                burnSale.authorizationDigest(e.sale.authorization)
            )
        );
    }

    function _burnBatch(E.Execution memory e)
        private
        view
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = 1;
        b.phaseId = BURN_PHASE;
        b.payer = e.sale.authorization.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = e.sale.authorization.recipient;
        b.beneficiaries = b.initialRecipients;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = e.sale.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = e.sale.authorization.mintCommitment;
        b.expectedPolicyHash = manager.phasePolicyHash(1, BURN_PHASE);
        b.authorizationId = _authorizationId(e);
        b.contextHash = burnSale.authorizationDigest(e.sale.authorization);
    }

    function _settlementKey(S.ERC20SettlementCandidate memory c) private view returns (bytes32) {
        return StreamPrimarySettlementHash.settlementKey(
            address(recorder), address(burnSale), c.executionBinding.executionId
        );
    }

    function _assertUnused(
        E.Execution memory e,
        S.ERC20SettlementCandidate memory c,
        bytes32 intentNonce
    ) private view {
        require(
            core.ownerOf(e.sourceTokenIds[0]) == e.sale.authorization.payer
                && core.lastAllocatedTokenId() == 1 && core.collectionMintedEver(1) == 1
                && !manager.isNullifierUsed(burnGate.burnNullifier(e.sourceTokenIds[0]))
                && !manager.isAuthorizationUsed(_authorizationId(e))
                && !manager.isOperationRootUsed(c.operationIdentityCommitment)
                && !burnSale.authorizationUsed(
                    e.sale.authorization.artist, e.sale.authorization.nonce
                )
                && burnSale.executionIdByNonce(
                    e.sale.authorization.saleId, e.sale.authorization.executionNonce
                ) == 0 && burnSale.executionStatus(c.executionBinding.executionId) == 0,
            "source and every mint/sale replay store unchanged"
        );
        require(
            !payment.isPaymentIntentNonceUsed(e.sale.authorization.payer, intentNonce)
                && token.balanceOf(e.sale.authorization.payer) == 10000
                && token.balanceOf(wallet) == 0
                && recorder.totalOfficialSettled(address(token)) == 0
                && recorder.settlementResult(_settlementKey(c)).amount == 0
                && payment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
            "payment receipt funds and intent rolled back"
        );
    }

    function _assertExecuted(
        E.Execution memory e,
        S.ERC20SettlementCandidate memory c,
        S.PrimarySettlementResult memory r
    ) private view {
        (bool exists, uint256 collection,, bool burned) =
            core.tokenCollectionIdentity(e.sourceTokenIds[0]);
        require(
            exists && collection == 1 && burned && core.lastAllocatedTokenId() == 2
                && core.collectionMintedEver(1) == 2
                && core.ownerOf(2) == e.sale.authorization.recipient
                && keccak256(core.tokenData(2)) == e.sale.authorization.tokenDataHash,
            "actual source burn and exact fresh recipient mint"
        );
        require(
            manager.isNullifierUsed(burnGate.burnNullifier(e.sourceTokenIds[0]))
                && manager.isAuthorizationUsed(_authorizationId(e))
                && manager.isOperationRootUsed(c.operationIdentityCommitment)
                && burnSale.authorizationUsed(
                    e.sale.authorization.artist, e.sale.authorization.nonce
                )
                && burnSale.executionIdByNonce(
                    e.sale.authorization.saleId, e.sale.authorization.executionNonce
                ) == c.executionBinding.executionId
                && burnSale.executionStatus(c.executionBinding.executionId) == 2,
            "original burn and sale replay identities consumed once"
        );
        require(
            r.settlementKey == _settlementKey(c) && r.amount == 1000 && r.asset == address(token)
                && r.wallet == wallet && r.executor == e.sale.authorization.executor
                && r.operationIdentityCommitment == c.operationIdentityCommitment
                && r.executionId == c.executionBinding.executionId
                && r.candidateCommitment
                    == StreamPrimarySettlementHash.candidateCommitment(
                        address(payment), address(recorder), c
                    )
                && keccak256(abi.encode(recorder.settlementResult(r.settlementKey)))
                    == keccak256(abi.encode(r)),
            "exact official original settlement receipt"
        );
        require(
            token.balanceOf(e.sale.authorization.payer) == 9000 && token.balanceOf(wallet) == 1000
                && token.balanceOf(address(burnSale)) == 0
                && token.balanceOf(address(burnGate)) == 0 && token.balanceOf(address(payment)) == 0
                && token.balanceOf(address(recorder)) == 0
                && recorder.totalOfficialSettled(address(token)) == 1000
                && payment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
            "exact funded economics and no temporary custody"
        );
    }

    function _independentDigest(U.SaleAuthorization memory a) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamUniversalFixedPriceSaleAdapter"),
                keccak256("1"),
                block.chainid,
                address(burnSale)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "UniversalSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline)"
                ),
                a.saleId,
                a.saleConfigHash,
                a.payer,
                a.executor,
                a.recipient,
                a.artist,
                a.tokenDataHash,
                a.mintCommitment,
                a.executionNonce,
                a.nonce,
                a.deadline
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function _permitPolicy(uint8 mode, uint8 version, address permit2) private {
        bytes32 hash = permit2 == address(0) ? bytes32(0) : permit2.codehash;
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            policy.assetPermitPolicyTransitionHashes(address(token), mode, version, permit2, hash);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(token), mode, version, permit2, hash);
        _clearContext();
    }

    function _safe(uint256 salt) private returns (OfficialSafe account, uint256[] memory keys) {
        keys = new uint256[](2);
        keys[0] = 0x5AFE731 + salt;
        keys[1] = 0x5AFE732 + salt;
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, salt);
    }

    function _approveSafeSources(OfficialSafe account, uint256[] memory keys, address spender)
        private
    {
        require(
            executeSafe(
                account,
                keys,
                address(core),
                0,
                abi.encodeCall(core.setApprovalForAll, (spender, true)),
                0
            ),
            "actual Safe source approval"
        );
    }

    function _safePayload(
        OfficialSafe account,
        uint256[] memory keys,
        address target,
        bytes memory data
    ) private returns (bytes memory) {
        bytes32 digest = account.getTransactionHash(
            target, 0, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
        );
        return abi.encodeCall(
            account.execTransaction,
            (
                target,
                uint256(0),
                data,
                uint8(0),
                uint256(0),
                uint256(0),
                uint256(0),
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
    }

    function burnTime() external view returns (uint256) {
        return block.timestamp;
    }
}
