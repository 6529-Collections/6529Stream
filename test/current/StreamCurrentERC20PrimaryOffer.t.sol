// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/NativeCuratedSaleFixture.sol";
import { MockStreamPaymentToken } from "../mocks/MockStreamPaymentToken.sol";
import { UniversalPermitToken } from "../helpers/UniversalSettlementTestMocks.sol";
import { OfficialPermit2Fixture } from "../helpers/OfficialPermit2Fixture.sol";
import {
    IStreamPinnedPermit2
} from "../../smart-contracts/interfaces/stream/revenue/IStreamPinnedPermit2.sol";
import {
    StreamERC20PrimaryOfferSale
} from "../../smart-contracts/domains/mint/StreamERC20PrimaryOfferSale.sol";
import { StreamERC20OfferGate } from "../../smart-contracts/domains/mint/StreamERC20OfferGate.sol";
import {
    StreamERC20PrimarySettlementAdapter
} from "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import {
    StreamPrimarySettlementHash
} from "../../smart-contracts/domains/revenue/StreamPrimarySettlementHash.sol";
import { StreamMintTicketHash } from "../../smart-contracts/domains/mint/StreamMintTicketHash.sol";
import {
    StreamERC20PrimaryOfferTypes as OfferT
} from "../../smart-contracts/interfaces/stream/mint/StreamERC20PrimaryOfferTypes.sol";
import {
    StreamPrivateSaleTypes as Sale
} from "../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter as Private
} from "../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    IStreamNativeRefundDelegatedClaims as Delegated
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import {
    IStreamERC20PrimarySettlementAdapter
} from "../../smart-contracts/interfaces/stream/revenue/IStreamERC20PrimarySettlementAdapter.sol";
import {
    IStreamERC20SaleExecution
} from "../../smart-contracts/interfaces/stream/revenue/IStreamERC20SaleExecution.sol";
import {
    StreamPrimarySettlementTypes as Primary
} from "../../smart-contracts/interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import {
    DelegationManagementContract
} from "../../smart-contracts/integrations/delegation/NFTdelegation.sol";

interface CurrentERC20OfferEventVm {
    function expectCall(address target, uint256 value, bytes calldata input, uint64 count) external;
    function expectEmit(bool, bool, bool, bool, address) external;
}

/// @dev Controlled NFT receiver and ERC-1271 buyer; actual Safe tests are separate below.
contract CurrentERC20OfferBuyer is IERC721Receiver {
    address private immutable signer;
    bool public rejects;
    bool public sawSellerConsumed;
    StreamERC20PrimaryOfferSale private host;
    bytes32 private sellerDigest;

    constructor(address signer_) {
        signer = signer_;
    }

    function configure(StreamERC20PrimaryOfferSale h, bytes32 digest, bool reject_) external {
        host = h;
        sellerDigest = digest;
        rejects = reject_;
    }

    function callTarget(address target, bytes calldata data) external returns (bytes memory raw) {
        bool ok;
        (ok, raw) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(raw, 32), mload(raw)) }
    }

    function isValidSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        if (signature.length != 65) return 0xffffffff;
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        return ecrecover(digest, v, r, s) == signer ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        sawSellerConsumed = host.digestConsumed(sellerDigest);
        require(!rejects, "ERC20 offer NFT rejected");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual current Core/Manager/Ledger/Registry/contract20/recorder/Resolver/wallet/escrow.
/// @dev Token, Artist, entropy and target-context governance retain explicit fixture boundaries.
contract StreamCurrentERC20PrimaryOfferTest is NativeCuratedSaleFixture, OfficialPermit2Fixture {
    StreamERC20PrimaryOfferSale private offers;
    StreamERC20PrimarySettlementAdapter private payment;
    MockStreamPaymentToken private token;
    DelegationManagementContract private delegates;
    uint256 private planNumber;
    uint256 private constant DELEGATE_KEY = 0xD320;
    uint256 private constant EXECUTOR_KEY = 0xE320;
    bytes32 private constant SIGNER_EVIDENCE = keccak256("current ERC20 offer seller");

    event SaleAuthorizationConsumed(
        uint16 schemaVersion, bytes32 indexed saleId, bytes32 indexed digest, address authorizer
    );
    event OfferAccepted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 offerDigest,
        uint256 price,
        address asset
    );
    event ImmediateRevealAttempt(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bool succeeded,
        bytes32 requestKey,
        uint256 providerRequestId,
        uint256 returnDataSize,
        bytes failurePrefix
    );

    struct Plan {
        bytes32 id;
        bytes32 counter;
        bytes32 leaf;
        uint256 nonce;
        OfferT.Configuration config;
    }

    function setUp() public override {
        super.setUp();
        entropy.configure(0, 1, false, false);
        token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("current ERC20 offer exact token"), 0);
        payment = new StreamERC20PrimarySettlementAdapter(recorder, address(0), 0);
        _register(
            address(payment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        _deployOffers(false);
        token.mint(payer, 10000);
        vm.prank(payer);
        token.approve(address(payment), 10000);
    }

    function testOfferRejectsNativeValueAndSameSignedPaymentSucceedsWithZeroValue() public {
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(true, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        bytes memory exact = abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, abi.encode(q)));
        vm.deal(payer, 1);
        vm.deal(address(payment), 17);
        vm.deal(address(offers), 23);
        CurrentERC20OfferEventVm(address(vm)).expectCall(address(token), 0,
            abi.encodeCall(token.transferFrom, (payer, address(payment), uint256(1000))), 1);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(offers).call{value: 1}(
            abi.encodeCall(offers.executeERC20PreRevenueSingleStep, (c, abi.encode(q))));
        require(!ok && reason.length == 0, "original nonpayable callback empty revert");
        _assertUnused(p, q, c, 0);
        vm.prank(payer);
        (ok, reason) = address(payment).call{value: 1}(exact);
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(
            StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector)), "unsupported callback value");
        _assertUnused(p, q, c, 0);
        require(payer.balance == 1 && address(payment).balance == 17 && address(offers).balance == 23,
            "no value retained; original native surplus preserved");
        vm.prank(payer);
        (ok, reason) = address(payment).call(exact);
        require(ok, "same signed payment accepts original zero-value route");
        _assertExecuted(p, q, c, abi.decode(reason, (Primary.PrimarySettlementResult)));
        require(payer.balance == 1 && address(payment).balance == 17 && address(offers).balance == 23,
            "zero-value execution preserves native balances");
    }

    function testSelectedDirectPayerFundsActualRevenueAndMintsOriginalWork() public {
        entropy.configure(0, 0, false, false);
        vm.expectRevert(
            abi.encodeWithSelector(StreamERC20PrimaryOfferSale.InvalidERC20PrimaryOffer.selector)
        );
        offers.primaryOfferSettlementBinding(keccak256("absent ERC20 offer"));
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(true, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        require(
            c.orchestrationOrder == 1 && c.sale.payer == payer && c.sale.beneficiary == payer
                && c.executionBinding.executionId == StreamPrimarySettlementHash.executionId(c),
            "original atomic identity"
        );
        bytes32 sellerDigest = offers.authorizationDigest(q.authorization);
        bytes32 buyerDigest = offers.offerDigest(q.offer);
        CurrentERC20OfferEventVm(address(vm)).expectEmit(true, true, false, true, address(offers));
        emit SaleAuthorizationConsumed(1, p.id, sellerDigest, p.config.signer);
        CurrentERC20OfferEventVm(address(vm)).expectEmit(true, true, false, true, address(offers));
        emit OfferAccepted(1, p.id, payer, buyerDigest, 1000, address(token));
        vm.prank(payer);
        Primary.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleByPayer(c, abi.encode(q));
        _assertExecuted(p, q, c, r);
        require(
            ledger.counterValue(_counterKey(p, payer)) == 1 && entropy.requestCalls() == 1
                && entropy.revealFeeEscrow(1) == 0,
            "content cap and zero fee request"
        );
    }

    function testCollectionOfferKeepsZeroArtworkIdentityAndSignedRawBytes() public {
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        vm.prank(payer);
        Primary.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleByPayer(c, abi.encode(q));
        _assertExecuted(p, q, c, r);
        OfferT.SaleRecord memory s = offers.saleRecord(p.id);
        require(
            q.offer.tokenId == 0 && q.offer.contentSelectionHash == 0
                && q.authorization.contentSelectionHash == 0 && s.gate == address(0)
                && s.contentCounterId == 0 && s.manifestHash == 0,
            "no invented artwork gate or reservation"
        );
        require(
            ledger.counterValue(_counterKey(p, payer)) == 1,
            "ordinary recipient accounting remains real"
        );
    }

    function testDelegatedSignerAndDistinctExecutorStillNeedPayersOwnPaymentIntent() public {
        _deployOffers(true);
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(true, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        address signer = vm.addr(DELEGATE_KEY);
        address executor = vm.addr(EXECUTOR_KEY);
        _grantDelegate(payer, signer);
        _grantDelegate(payer, executor);
        q.buyerProof = Private.Signature(
            signer, 1, _curatedSignature(DELEGATE_KEY, offers.offerDigest(q.offer))
        );
        q.authorization.executor = executor;
        q.sellerProof.signature =
            _curatedSignature(SIGNER_KEY, offers.authorizationDigest(q.authorization));
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        Primary.PaymentIntent memory intent = _intent(p, 1);
        bytes memory wrong = _curatedSignature(DELEGATE_KEY, payment.paymentIntentDigest(intent));
        vm.expectRevert();
        vm.prank(executor);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(q));
        vm.expectRevert();
        vm.prank(executor);
        payment.settleERC20PrimarySaleWithIntent(c, intent, wrong, abi.encode(q));
        _assertUnused(p, q, c, intent.nonce);
        bytes memory proof = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        vm.prank(executor);
        Primary.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleWithIntent(c, intent, proof, abi.encode(q));
        _assertExecuted(p, q, c, r);
        require(
            payment.isPaymentIntentNonceUsed(payer, intent.nonce) && token.balanceOf(executor) == 0
                && token.balanceOf(signer) == 0,
            "delegate authority is not payer spending authority"
        );
    }

    function testRevokedLiveOfferDelegateRollsBackAnAlreadyVerifiedPayerIntent() public {
        _deployOffers(true);
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        address signer = vm.addr(DELEGATE_KEY);
        _grantDelegate(payer, signer);
        q.buyerProof = Private.Signature(
            signer, 1, _curatedSignature(DELEGATE_KEY, offers.offerDigest(q.offer))
        );
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        Primary.PaymentIntent memory intent = _intent(p, 2);
        bytes memory proof = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        vm.prank(payer);
        delegates.revokeDelegationAddress(address(core), signer, 2);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithIntent(c, intent, proof, abi.encode(q));
        _assertUnused(p, q, c, intent.nonce);
        _grantDelegate(payer, signer);
        vm.prank(payer);
        _assertExecuted(
            p, q, c, payment.settleERC20PrimarySaleWithIntent(c, intent, proof, abi.encode(q))
        );
    }

    function testBuyerLedgerVoidUsesExactOfferKeyAndNeverConsumesSellerOrPaymentIntent() public {
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        Primary.PaymentIntent memory intent = _intent(p, 3);
        bytes memory proof = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        bytes32 offerId = _offerId(q.offer);
        vm.prank(payer);
        require(manager.voidMintOffer(q.offer, 1, "") == offerId, "same canonical Ledger void key");
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithIntent(c, intent, proof, abi.encode(q));
        require(
            ledger.isManagerAuthorizationUsed(address(manager), offerId)
                && !offers.digestConsumed(offers.authorizationDigest(q.authorization))
                && !payment.isPaymentIntentNonceUsed(payer, intent.nonce),
            "buyer void is independent of other two stores"
        );
        _assertNoMintOrMoney(payer);
        q.offer.nonce = keccak256("unused historical buyer offer");
        bytes32 historicalId = _offerId(q.offer);
        _disableHistorical(p);
        vm.prank(payer);
        require(
            manager.voidMintOffer(q.offer, 1, "") == historicalId,
            "expired buyer void requires no live carrier"
        );
    }

    function testSellerHistoricalVoidNeverConsumesBuyerOfferOrPaymentIntent() public {
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(true, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        Primary.PaymentIntent memory intent = _intent(p, 4);
        bytes memory proof = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        vm.prank(p.config.signer);
        offers.revokeAuthorization(q.authorization, Private.Signature(p.config.signer, 1, ""));
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithIntent(c, intent, proof, abi.encode(q));
        require(
            offers.digestRevoked(offers.authorizationDigest(q.authorization))
                && !ledger.isManagerAuthorizationUsed(address(manager), _offerId(q.offer))
                && !payment.isPaymentIntentNonceUsed(payer, intent.nonce),
            "seller void is independent of buyer and payment"
        );
        _assertNoMintOrMoney(payer);
        q.authorization.nonce = keccak256("unused historical seller authorization");
        _disableHistorical(p);
        vm.prank(p.config.signer);
        offers.revokeAuthorization(q.authorization, Private.Signature(p.config.signer, 1, ""));
        require(
            offers.digestRevoked(offers.authorizationDigest(q.authorization)),
            "seller historical void survives provider loss"
        );
    }

    function testConsumedOfferCannotExecuteFreshSellerAuthorizationAndSellerCannotServeNewOffer()
        public
    {
        (Plan memory first, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(q));
        Sale.SaleOffer memory original = abi.decode(abi.encode(q.offer), (Sale.SaleOffer));
        q.offer.nonce = keccak256("second buyer offer under same seller auth");
        q.buyerProof.signature = _curatedSignature(PAYER_KEY, offers.offerDigest(q.offer));
        bytes32 secondOfferId = _offerId(q.offer);
        vm.expectRevert();
        offers.previewExecution(q);
        require(
            !ledger.isManagerAuthorizationUsed(address(manager), secondOfferId),
            "seller consumption precedes changed offer"
        );
        (Plan memory second, OfferT.Acceptance memory fresh) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, original);
        require(
            first.id != second.id && _offerId(original) == _offerId(fresh.offer),
            "new sale does not change original buyer key"
        );
        Primary.ERC20SettlementCandidate memory retry = offers.previewExecution(fresh);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(retry, abi.encode(fresh));
        require(
            !offers.digestConsumed(offers.authorizationDigest(fresh.authorization))
                && offers.nextExecutionNonce(second.id, payer) == 1
                && core.lastAllocatedTokenId() == 1
                && recorder.totalOfficialSettled(address(token)) == 1000,
            "fresh seller auth cannot revive consumed offer"
        );
    }

    function testLiveNonzeroRevealFeeRejectsBeforePullAndZeroFeeProviderFailureIsIsolated() public {
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        Primary.PaymentIntent memory intent = _intent(p, 5);
        bytes memory proof = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        // Only the healthy retry may reach the first payer-to-payment token pull.
        CurrentERC20OfferEventVm(address(vm)).expectCall(address(token), 0,
            abi.encodeCall(token.transferFrom, (payer, address(payment), uint256(1000))), 1);
        entropy.configure(7, 1, false, false);
        vm.expectRevert();
        offers.previewExecution(q);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithIntent(c, intent, proof, abi.encode(q));
        _assertUnused(p, q, c, intent.nonce);
        require(token.transferCalls() == 0, "fee refusal rolls token state back");
        entropy.configure(0, 0, false, true);
        bytes memory failure = abi.encodeWithSignature("Error(string)", "provider rejected");
        CurrentERC20OfferEventVm(address(vm)).expectEmit(true, true, false, true, address(offers));
        emit ImmediateRevealAttempt(1, 1, 1, false, 0, 0, failure.length, failure);
        vm.prank(payer);
        Primary.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleWithIntent(c, intent, proof, abi.encode(q));
        _assertExecuted(p, q, c, r);
        require(
            entropy.mintCalls() == 1 && entropy.requestCalls() == 0
                && entropy.revealFeeEscrow(1) == 0,
            "failed zero fee provider request does not roll back purchase"
        );
    }

    function testNonstandardTokenEconomicsRollbackAllThreeStoresAndExactRetry() public {
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(true, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        Primary.PaymentIntent memory intent = _intent(p, 6);
        bytes memory proof = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        uint8[5] memory modes = [uint8(1), 2, 3, 4, 6];
        for (uint256 i; i < modes.length; ++i) {
            token.configure(modes[i], 1);
            vm.expectRevert();
            vm.prank(payer);
            payment.settleERC20PrimarySaleWithIntent(c, intent, proof, abi.encode(q));
            _assertUnused(p, q, c, intent.nonce);
        }
        token.configure(0, 0);
        vm.prank(payer);
        _assertExecuted(
            p, q, c, payment.settleERC20PrimarySaleWithIntent(c, intent, proof, abi.encode(q))
        );
    }

    function testMalformedSaleProofArtworkAndAssetFailBeforePull() public {
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(true, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        Primary.PaymentIntent memory intent = _intent(p, 7);
        bytes memory proof = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        bytes memory original = abi.encode(q);
        for (uint256 i; i < 4; ++i) {
            OfferT.Acceptance memory bad = abi.decode(original, (OfferT.Acceptance));
            if (i == 0) {
                bad.buyerProof.signature = hex"01";
            } else if (i == 1) {
                bad.selection.tokenData = "unsigned replacement artwork";
            } else if (i == 2) {
                bad.offer.asset = address(0);
            } else {
                bad.selection.content.proof = new bytes32[](1);
                bad.selection.content.proof[0] = keccak256("invalid sibling");
            }
            c.saleExecutionHash = keccak256(abi.encode(bad));
            vm.expectRevert();
            vm.prank(payer);
            payment.settleERC20PrimarySaleWithIntent(c, intent, proof, abi.encode(bad));
            _assertUnused(p, q, c, intent.nonce);
        }
        require(
            token.transferCalls() == 0, "invalid sale authority and artwork cannot reach first pull"
        );
        c.saleExecutionHash = keccak256(original);
        vm.prank(payer);
        _assertExecuted(
            p, q, c, payment.settleERC20PrimarySaleWithIntent(c, intent, proof, original)
        );
    }

    function testFinalNFTFailureRestoresPayerIntentSellerAndLedgerForByteIdenticalRetry() public {
        CurrentERC20OfferBuyer buyer = new CurrentERC20OfferBuyer(payer);
        token.mint(address(buyer), 10000);
        buyer.callTarget(address(token), abi.encodeCall(token.approve, (address(payment), 10000)));
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(true, address(buyer), vm.addr(SIGNER_KEY), 1, _emptyOffer());
        buyer.configure(offers, offers.authorizationDigest(q.authorization), true);
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        Primary.PaymentIntent memory intent = _intent(p, 8);
        bytes memory proof = _curatedSignature(PAYER_KEY, payment.paymentIntentDigest(intent));
        bytes memory exact = abi.encodeCall(
            payment.settleERC20PrimarySaleWithIntent, (c, intent, proof, abi.encode(q))
        );
        vm.expectRevert();
        buyer.callTarget(address(payment), exact);
        _assertUnused(p, q, c, intent.nonce);
        buyer.configure(offers, offers.authorizationDigest(q.authorization), false);
        Primary.PrimarySettlementResult memory r = abi.decode(
            buyer.callTarget(address(payment), exact), (Primary.PrimarySettlementResult)
        );
        _assertExecuted(p, q, c, r);
        require(
            buyer.sawSellerConsumed()
                && payment.isPaymentIntentNonceUsed(address(buyer), intent.nonce),
            "consumed authority visible at final receiver"
        );
    }

    function testActualTwoOfTwoSafeBuyerSellerCallAndExactFailedTransactionRetry() public {
        (OfficialSafe buyer, uint256[] memory buyerKeys) = _safe(820);
        (OfficialSafe seller, uint256[] memory sellerKeys) = _safe(821);
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
            "actual Safe payer approval"
        );
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(true, address(buyer), address(seller), 2, _emptyOffer());
        _safeProofs(q, buyer, buyerKeys, seller, sellerKeys);
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        uint256 beforeNonce = buyer.nonce();
        bytes memory exact = _safePayload(
            buyer,
            buyerKeys,
            address(payment),
            abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, abi.encode(q)))
        );
        entropy.configure(0, 1, true, false);
        (bool ok,) = address(buyer).call(exact);
        require(
            !ok && buyer.nonce() == beforeNonce && seller.nonce() == 0,
            "failed actual Safe transaction restores nonce"
        );
        _assertUnused(p, q, c, 0);
        entropy.configure(0, 1, false, false);
        bytes memory raw;
        (ok, raw) = address(buyer).call(exact);
        require(
            ok && abi.decode(raw, (bool)) && buyer.nonce() == beforeNonce + 1,
            "identical threshold transaction succeeds"
        );
        _assertExecuted(p, q, c, recorder.settlementResult(_settlementKey(c)));
        (p, q) = _open(false, address(buyer), address(seller), 2, _emptyOffer());
        offers.configureCollectionSigner(1, address(seller), 2, SIGNER_EVIDENCE, false);
        vm.warp(p.config.endsAt + 1);
        Private.Signature memory direct = Private.Signature(address(seller), 2, "");
        require(
            executeSafe(
                seller,
                sellerKeys,
                address(offers),
                0,
                abi.encodeCall(offers.revokeAuthorization, (q.authorization, direct)),
                0
            ),
            "actual seller Safe historical direct void"
        );
        require(
            seller.nonce() == 1 && seller.getThreshold() == 2 && buyer.getThreshold() == 2
                && offers.digestRevoked(offers.authorizationDigest(q.authorization)),
            "actual threshold seller and buyer"
        );
    }

    function testActualSafePayer1271IntentRemainsSeparateFromDelegatedOfferExecution() public {
        _deployOffers(true);
        (OfficialSafe buyer, uint256[] memory buyerKeys) = _safe(822);
        (OfficialSafe seller, uint256[] memory sellerKeys) = _safe(823);
        address executor = vm.addr(EXECUTOR_KEY);
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
            "Safe allowance"
        );
        require(
            executeSafe(
                buyer,
                buyerKeys,
                address(delegates),
                0,
                abi.encodeCall(
                    delegates.registerDelegationAddress,
                    (
                        address(core),
                        executor,
                        this.offerScenarioTime() + 1 days,
                        uint256(2),
                        true,
                        uint256(0)
                    )
                ),
                0
            ),
            "actual Safe grants offer executor"
        );
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(false, address(buyer), address(seller), 2, _emptyOffer());
        q.authorization.executor = executor;
        _safeProofs(q, buyer, buyerKeys, seller, sellerKeys);
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        Primary.PaymentIntent memory intent = _intent(p, 9);
        bytes memory sig = safeThresholdSignature(
            buyerKeys, safeMessageDigest(buyer, abi.encode(payment.paymentIntentDigest(intent)))
        );
        uint256 beforeNonce = buyer.nonce();
        vm.prank(executor);
        Primary.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleWithIntent(c, intent, sig, abi.encode(q));
        _assertExecuted(p, q, c, r);
        require(
            payment.isPaymentIntentNonceUsed(address(buyer), intent.nonce)
                && buyer.nonce() == beforeNonce && seller.nonce() == 0
                && token.balanceOf(executor) == 0,
            "separate actual1271 proofs spend only vault tokens"
        );
    }

    function testPayerCalledEIP2612RestoresPermitAndAllEffectsOnLateMintFailure() public {
        UniversalPermitToken permitToken = new UniversalPermitToken();
        token = MockStreamPaymentToken(address(permitToken));
        _setAssetPolicy(policy, address(token), 1, keccak256("current offer EIP2612 token"), 0);
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            policy.assetPermitPolicyTransitionHashes(address(token), 1, 0, address(0), 0);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(token), 1, 0, address(0), 0);
        _clearContext();
        token.mint(payer, 10000);
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        uint64 deadline = p.config.endsAt;
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(PAYER_KEY, permitToken.permitDigest(payer, address(payment), 1000, deadline));
        Primary.EIP2612PermitAuthorization memory permit =
            Primary.EIP2612PermitAuthorization(deadline, v, r, s);
        entropy.configure(0, 1, true, false);
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithEIP2612Permit(c, permit, abi.encode(q));
        require(
            permitToken.nonces(payer) == 0 && permitToken.allowance(payer, address(payment)) == 0
                && permitToken.balanceOf(payer) == 10000
                && !offers.digestConsumed(offers.authorizationDigest(q.authorization))
                && !ledger.isManagerAuthorizationUsed(address(manager), _offerId(q.offer))
                && recorder.totalOfficialSettled(address(token)) == 0,
            "late failure restores exact permit and both sale stores"
        );
        entropy.configure(0, 1, false, false);
        vm.prank(payer);
        Primary.PrimarySettlementResult memory result =
            payment.settleERC20PrimarySaleWithEIP2612Permit(c, permit, abi.encode(q));
        _assertExecuted(p, q, c, result);
        require(
            permitToken.nonces(payer) == 1 && permitToken.allowance(payer, address(payment)) == 0,
            "exact permit consumed once"
        );
    }

    function testActualPinnedPermit2PayerOfferUsesExactFiniteAllowanceAndOriginalReplayKey()
        public
    {
        address permit2 = deployOfficialPermit2();
        payment = new StreamERC20PrimarySettlementAdapter(recorder, permit2, permit2.codehash);
        _register(
            address(payment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) = policy.assetPermitPolicyTransitionHashes(
            address(token), 2, 1, permit2, permit2.codehash
        );
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(token), 2, 1, permit2, permit2.codehash);
        _clearContext();
        vm.prank(payer);
        token.approve(permit2, 4000);
        (Plan memory p, OfferT.Acceptance memory q) =
            _open(false, payer, vm.addr(SIGNER_KEY), 1, _emptyOffer());
        Primary.ERC20SettlementCandidate memory c = offers.previewExecution(q);
        Primary.Permit2TransferAuthorization memory permit;
        permit.nonce = 33;
        permit.deadline = p.config.endsAt;
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
        vm.prank(payer);
        Primary.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleWithPermit2(c, permit, abi.encode(q));
        _assertExecuted(p, q, c, r);
        require(
            token.allowance(payer, permit2) == 3000 && token.allowance(payer, address(payment)) == 0
                && IStreamPinnedPermit2(permit2).nonceBitmap(payer, 0) == uint256(1) << 33
                && ledger.isManagerAuthorizationUsed(address(manager), _offerId(q.offer)),
            "exact original Permit2 nonce allowance and offer consumption"
        );
        vm.expectRevert();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithPermit2(c, permit, abi.encode(q));
        require(
            token.balanceOf(payer) == 9000 && token.allowance(payer, permit2) == 3000
                && core.lastAllocatedTokenId() == 1
                && recorder.totalOfficialSettled(address(token)) == 1000,
            "Permit2 replay cannot create another mint or pull"
        );
    }

    function _deployOffers(bool delegation) private {
        StreamERC20PrimaryOfferSale.DeploymentConfig memory d;
        d.manager = manager;
        d.recorder = recorder;
        d.artists = artists;
        d.roles = auctionRoles;
        d.authority = address(revenueAuthority);
        d.parameters[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 300000, 50000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200000, 50000, 2
        );
        if (delegation) {
            delegates = new DelegationManagementContract();
            d.delegation = Delegated.DelegationDeployment(
                address(delegates),
                2,
                MANIFEST,
                IStreamGasParameterHost.GasParameterConfig(
                    "DELEGATE_REGISTRY_GAS_LIMIT", 150000, 50000, 2
                )
            );
        }
        offers = new StreamERC20PrimaryOfferSale(d);
        _register(
            address(offers),
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
        );
    }

    function _open(
        bool selected,
        address buyer,
        address seller,
        uint8 kind,
        Sale.SaleOffer memory repeated
    ) private returns (Plan memory p, OfferT.Acceptance memory q) {
        p.nonce = offers.nextSaleNonce();
        p.config.phaseId = keccak256(abi.encode("current ERC20 offer phase", ++planNumber));
        p.id = offers.saleIdFor(1, p.config.phaseId, p.nonce);
        p.counter = keccak256(abi.encode("current ERC20 offer cap", p.id));
        p.config.collectionId = 1;
        p.config.asset = address(token);
        p.config.paymentAdapter = address(payment);
        p.config.price = 1000;
        p.config.poster = address(this);
        p.config.startsAt = uint64(this.offerScenarioTime() + 10);
        p.config.endsAt = p.config.startsAt + 1000;
        p.config.expectedPrimaryPolicyHash =
            StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
        p.config.buyer = buyer;
        q.selection.tokenData = bytes("original ERC20 primary offer artwork");
        q.selection.mintCommitment = keccak256(abi.encode("ERC20 offer mint", p.id));
        q.selection.executionNonce = 1;
        IStreamMintManager.MintGateConfig memory gate;
        if (selected) {
            p.config.contentId = keccak256("ERC20 selected work");
            p.config.tokenDataHash = keccak256(q.selection.tokenData);
            p.leaf = _curatedLeaf(address(offers), p.id, p.config.contentId, p.config.tokenDataHash);
            p.config.contentManifestRoot = p.leaf;
            StreamPreparedNativeContentTypes.Row[] memory rows =
                new StreamPreparedNativeContentTypes.Row[](1);
            rows[0] = StreamPreparedNativeContentTypes.Row(
                p.config.contentId, p.config.tokenDataHash, "urn:erc20-offer:original-work"
            );
            StreamERC20OfferGate g = new StreamERC20OfferGate(
                address(manager), address(offers), p.id, 1, p.config.phaseId, p.counter, rows
            );
            _registerGate(g);
            gate.gate = address(g);
            gate.gateConfigHash = g.gateConfigHash();
            q.selection.content.contentId = p.config.contentId;
            q.selection.content.tokenDataHash = p.config.tokenDataHash;
        }
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = p.counter;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            selected
                ? IStreamMintManager.CounterKeyMode.CONTEXT
                : IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            selected ? 1 : 5,
            1,
            keccak256(abi.encode("ERC20 offer static counter", p.id))
        );
        manager.configurePhase(
            1,
            p.config.phaseId,
            IStreamMintManager.MintPhaseConfig(
                false, p.config.startsAt, p.config.endsAt, 1, MANIFEST, MANIFEST
            ),
            gate,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, p.config.phaseId, address(offers), true);
        p.config.mintPolicyHash = manager.phasePolicyHash(1, p.config.phaseId);
        OfferT.CollectionSigner memory member = offers.collectionSigner(1, seller, kind);
        if (member.revision == 0 || !member.enabled) {
            offers.configureCollectionSigner(1, seller, kind, SIGNER_EVIDENCE, true);
            member = offers.collectionSigner(1, seller, kind);
        }
        p.config.signer = seller;
        p.config.signerKind = kind;
        p.config.signerEvidenceHash = member.evidenceHash;
        p.config.signerRevision = member.revision;
        p.config.signerAuthority = member.authority;
        q.offer = repeated.saleAdapter == address(0)
            ? Sale.SaleOffer(
                block.chainid,
                address(offers),
                address(core),
                1,
                0,
                p.leaf,
                buyer,
                address(token),
                1000,
                keccak256(abi.encode("original ERC20 buyer nonce", p.id)),
                p.config.endsAt,
                0
            )
            : repeated;
        p.config.offerDigest = offers.offerDigest(q.offer);
        require(
            offers.registerPrimaryOffer(p.config, q.selection.content.proof) == p.id,
            "canonical kind6 sale"
        );
        bytes32 configHash = offers.primaryOfferConfigurationHash(p.config);
        require(
            offers.saleRecord(p.id).configHash == configHash,
            "full immutable original configuration"
        );
        _bindCuratedConsent(p.id, configHash);
        q.authorization = _authorization(p, q.selection);
        q.sellerProof = Private.Signature(
            seller, kind, _curatedSignature(SIGNER_KEY, offers.authorizationDigest(q.authorization))
        );
        q.buyerProof = Private.Signature(
            buyer, buyer == payer ? 1 : 2, _curatedSignature(PAYER_KEY, offers.offerDigest(q.offer))
        );
        vm.warp(p.config.startsAt);
    }

    function _authorization(Plan memory p, OfferT.Selection memory selected)
        private
        view
        returns (Sale.SaleAuthorization memory a)
    {
        address[] memory buyer = new address[](1);
        buyer[0] = p.config.buyer;
        bytes[] memory data = new bytes[](1);
        data[0] = selected.tokenData;
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = selected.mintCommitment;
        a.chainId = block.chainid;
        a.saleAdapter = address(offers);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = p.config.phaseId;
        a.saleId = p.id;
        a.saleKind = 6;
        a.revenueClass = CLASS;
        a.expectedPrimaryPolicyHash = p.config.expectedPrimaryPolicyHash;
        a.initialRecipientsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), buyer));
        a.beneficiariesHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), buyer));
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), data));
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = p.config.buyer;
        a.executor = p.config.buyer;
        a.asset = p.config.asset;
        a.unitPrice = p.config.price;
        a.quantity = 1;
        a.contentSelectionHash = p.leaf;
        a.policyHash = p.config.mintPolicyHash;
        a.nonce = keccak256(abi.encode("original ERC20 seller nonce", p.id));
        a.deadline = p.config.endsAt;
    }

    function _registerGate(StreamERC20OfferGate gate) private {
        StreamModuleRegistration memory r = StreamModuleRegistration(
            address(gate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1"),
            type(IStreamMintGate).interfaceId,
            800000,
            address(gate).codehash,
            MANIFEST,
            gate.gateConfigHash(),
            "urn:erc20-offer:complete-manifest"
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(r);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        registry.registerModule(r);
        _clearContext();
    }

    function _intent(Plan memory p, uint256 nonce)
        private
        pure
        returns (Primary.PaymentIntent memory)
    {
        return Primary.PaymentIntent(
            p.config.buyer,
            p.config.asset,
            p.config.price,
            p.id,
            p.config.expectedPrimaryPolicyHash,
            bytes32(nonce),
            p.config.endsAt + 1 days
        );
    }

    function _offerId(Sale.SaleOffer memory offer) private view returns (bytes32) {
        return StreamMintTicketHash.authorizationId(offers.offerDigest(offer));
    }

    function _settlementKey(Primary.ERC20SettlementCandidate memory c)
        private
        view
        returns (bytes32)
    {
        return StreamPrimarySettlementHash.settlementKey(
            address(recorder), address(offers), c.executionBinding.executionId
        );
    }

    function _counterKey(Plan memory p, address buyer) private view returns (bytes32) {
        bytes32 context = p.leaf == 0
            ? bytes32(0)
            : keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                    block.chainid,
                    address(offers),
                    p.id,
                    p.config.contentId
                )
            );
        bytes32 subject = manager.previewSubjectKey(
            p.leaf == 0
                ? IStreamMintManager.CounterKeyMode.RECIPIENT
                : IStreamMintManager.CounterKeyMode.CONTEXT,
            1,
            p.config.phaseId,
            p.counter,
            buyer,
            buyer,
            address(offers),
            buyer,
            context
        );
        return manager.previewCounterValueKey(1, p.config.phaseId, p.counter, subject);
    }

    function _assertExecuted(
        Plan memory p,
        OfferT.Acceptance memory q,
        Primary.ERC20SettlementCandidate memory c,
        Primary.PrimarySettlementResult memory r
    ) private view {
        OfferT.ExecutionRecord memory e = offers.executionRecord(c.executionBinding.executionId);
        bytes32 sellerDigest = offers.authorizationDigest(q.authorization);
        require(
            e.saleId == p.id && e.buyer == p.config.buyer && e.executor == q.authorization.executor
                && e.executionNonce == 1 && e.tokenId != 0
                && e.offerDigest == offers.offerDigest(q.offer)
                && e.authorizationDigest == sellerDigest && e.authorizationId == _offerId(q.offer)
                && e.contentLeaf == p.leaf && e.tokenDataHash == keccak256(q.selection.tokenData)
                && e.operationRoot == c.operationIdentityCommitment
                && e.operationId == c.operationId && core.ownerOf(e.tokenId) == p.config.buyer
                && keccak256(core.tokenData(e.tokenId)) == keccak256(q.selection.tokenData),
            "actual direct buyer mint and original execution"
        );
        require(
            offers.digestConsumed(sellerDigest) && !offers.digestRevoked(sellerDigest)
                && ledger.isManagerAuthorizationUsed(address(manager), _offerId(q.offer))
                && !ledger.isManagerAuthorizationUsed(
                    address(manager), StreamMintTicketHash.authorizationId(sellerDigest)
                ) && ledger.isManagerOperationRootUsed(address(manager), e.operationRoot),
            "distinct durable replay stores"
        );
        require(
            r.settlementKey == _settlementKey(c) && e.settlementKey == r.settlementKey
                && r.candidateCommitment
                    == StreamPrimarySettlementHash.candidateCommitment(
                        address(payment), address(recorder), c
                    ) && r.executionId == c.executionBinding.executionId
                && r.operationIdentityCommitment == c.operationIdentityCommitment
                && r.amount == 1000 && r.asset == address(token) && r.executor == c.executor
                && r.wallet == wallet
                && keccak256(abi.encode(recorder.settlementResult(r.settlementKey)))
                    == keccak256(abi.encode(r)),
            "exact official receipt and universal execution key"
        );
        require(
            token.balanceOf(p.config.buyer) == 9000 && token.balanceOf(wallet) == 1000
                && token.balanceOf(address(payment)) == 0 && token.balanceOf(address(recorder)) == 0
                && token.balanceOf(address(offers)) == 0
                && recorder.totalOfficialSettled(address(token)) == 1000
                && offers.nextExecutionNonce(p.id, p.config.buyer) == 2
                && offers.saleRecord(p.id).status == 4
                && payment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE
                && core.pendingPreparedMintTokenId() == 0,
            "one funded execution without payment or NFT custody"
        );
        _assertSettlementBinding(p, 4);
    }

    function _assertSettlementBinding(Plan memory p, uint8 status) private view {
        (uint256 nonce, address poster, bytes32 configHash) =
            offers.primaryOfferSettlementBinding(p.id);
        require(
            nonce == p.nonce && poster == p.config.poster
                && configHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ERC20_PRIMARY_OFFER_CONFIG_V1"),
                            block.chainid,
                            address(offers),
                            p.config
                        )
                    ) && offers.saleRecord(p.id).status == status,
            "terminal settlement binding retains all three immutable fields"
        );
    }

    function _assertUnused(
        Plan memory p,
        OfferT.Acceptance memory q,
        Primary.ERC20SettlementCandidate memory c,
        bytes32 intentNonce
    ) private view {
        require(
            !offers.digestConsumed(offers.authorizationDigest(q.authorization))
                && !ledger.isManagerAuthorizationUsed(address(manager), _offerId(q.offer))
                && !payment.isPaymentIntentNonceUsed(p.config.buyer, intentNonce)
                && !recorder.settlementConsumed(_settlementKey(c))
                && offers.nextExecutionNonce(p.id, p.config.buyer) == 1
                && offers.saleRecord(p.id).status == 1
                && offers.executionRecord(c.executionBinding.executionId).saleId == 0,
            "all three authority stores and execution roll back"
        );
        require(
            token.allowance(p.config.buyer, address(payment)) == 10000
                && ledger.counterValue(_counterKey(p, p.config.buyer)) == 0,
            "allowance and counters unchanged"
        );
        _assertNoMintOrMoney(p.config.buyer);
    }

    function _assertNoMintOrMoney(address buyer) private view {
        require(
            core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && manager.nextOperationNonce() == 0
                && recorder.totalOfficialSettled(address(token)) == 0
                && token.balanceOf(buyer) == 10000 && token.balanceOf(wallet) == 0
                && token.balanceOf(address(payment)) == 0 && token.balanceOf(address(recorder)) == 0
                && token.balanceOf(address(offers)) == 0 && entropy.mintCalls() == 0
                && entropy.requestCalls() == 0 && entropy.revealFeeEscrow(1) == 0
                && payment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE
                && core.pendingPreparedMintTokenId() == 0,
            "no partial mint payment fee or callback state"
        );
    }

    function _disableHistorical(Plan memory p) private {
        offers.configureCollectionSigner(
            1, p.config.signer, p.config.signerKind, SIGNER_EVIDENCE, false
        );
        manager.setPhasePaused(1, p.config.phaseId, true);
        NativeCuratedArtistBoundary(address(artists)).setConsent(false);
        _status(address(offers), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.warp(p.config.endsAt + 1);
        offers.expirePrimaryOffer(p.id);
        vm.etch(address(entropy), hex"60006000fd");
        _assertSettlementBinding(p, 3);
    }

    function _grantDelegate(address buyer, address actor) private {
        uint256 expiry = this.offerScenarioTime() + 1 days;
        vm.prank(buyer);
        delegates.registerDelegationAddress(address(core), actor, expiry, 2, true, 0);
    }

    function _moduleManifest(address module) internal view override returns (bytes32) {
        return module == address(offers) && address(delegates) != address(0)
            ? keccak256(offers.offerDelegationManifest())
            : MANIFEST;
    }

    function _safe(uint256 salt) private returns (OfficialSafe account, uint256[] memory keys) {
        keys = new uint256[](2);
        keys[0] = 0x5AFE731 + salt;
        keys[1] = 0x5AFE732 + salt;
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, salt);
    }

    function _safeProofs(
        OfferT.Acceptance memory q,
        OfficialSafe buyer,
        uint256[] memory buyerKeys,
        OfficialSafe seller,
        uint256[] memory sellerKeys
    ) private {
        q.buyerProof = Private.Signature(
            address(buyer),
            2,
            safeThresholdSignature(
                buyerKeys, safeMessageDigest(buyer, abi.encode(offers.offerDigest(q.offer)))
            )
        );
        q.sellerProof = Private.Signature(
            address(seller),
            2,
            safeThresholdSignature(
                sellerKeys,
                safeMessageDigest(seller, abi.encode(offers.authorizationDigest(q.authorization)))
            )
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

    function offerScenarioTime() external view returns (uint256) {
        return block.timestamp;
    }
    function _emptyOffer() private pure returns (Sale.SaleOffer memory offer) { }
}
