// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    NativeImmediateSalesFixture,
    ImmediateSalesArtistBoundary
} from "../../helpers/NativeImmediateSalesFixture.sol";
import { NativeAuctionReceiver } from "../../helpers/NativeEnglishAuctionMocks.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    IStreamNativeImmediateSales as S
} from "../../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import {
    StreamPrivateSaleTypes as A
} from "../../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    StreamNativeSettlementTypes as N
} from "../../../smart-contracts/interfaces/stream/revenue/StreamNativeSettlementTypes.sol";
import {
    StreamPrimarySettlementTypes as T
} from "../../../smart-contracts/interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import {
    IStreamMintImmediateSaleAuthorizationRevocation
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintImmediateSaleAuthorizationRevocation.sol";
import {
    IStreamMintCounterPolicy
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintCounterPolicy.sol";
import {
    IStreamMintManager
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamMintLedger
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol";
import {
    IStreamMintGate
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol";
import {
    IStreamPrivateSaleAdapter
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    IStreamImmediateSaleReveal
} from "../../../smart-contracts/interfaces/stream/mint/IStreamImmediateSaleReveal.sol";
import {
    IStreamRevenueResolver
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamRevenueResolver.sol";
import {
    StreamModuleRegistration
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    StreamConservationFloorTypes
} from "../../../smart-contracts/interfaces/stream/metadata/StreamConservationFloorTypes.sol";
import {
    StreamMintTicketGate
} from "../../../smart-contracts/domains/mint/StreamMintTicketGate.sol";

/// @notice Current production mint/settlement/floor composition under explicit typed Artist,
/// entropy and executing-governance boundaries. This is not the full current Artist/Executor graph.
contract StreamNativeImmediateSalesTest is NativeImmediateSalesFixture {
    function testCanonicalSignedLiteralDigestActualLedgerAndOfficialFloorReceipt() public {
        bytes32 id = _registerImmediate(_configuration(1, 0, vm.addr(SIGNER_KEY), 1));
        S.Purchase memory p = _purchase(id, payer, 1);
        A.SaleAuthorization memory a = _authorization(p, 101);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        require(
            immediate.authorizationDigest(a) == _literalDigest(a),
            "literal original 24-field domain/type"
        );
        N.NativeSettlementCandidate memory c = immediate.previewSignedPurchase(p, a, proof);
        bytes32 authorizationId = _id(_literalDigest(a));
        uint256 payerBefore = payer.balance;
        vm.recordLogs();
        vm.prank(payer);
        S.Receipt memory r = immediate.purchaseSigned{ value: PRICE }(p, a, proof);
        _executionEvents(vm.getRecordedLogs(), r);
        _assertReceipt(p, c, r, authorizationId, _literalDigest(a));
        require(payer.balance == payerBefore - PRICE, "literal native payer pays");
        require(
            core.ownerOf(r.tokenId) == p.initialRecipient && c.sale.beneficiary == p.beneficiary,
            "recipient distinct from beneficiary and payer"
        );
        require(
            _payerCount(payer) == 1 && _payerCount(p.initialRecipient) == 0, "actual PAYER counter"
        );
        bytes32 before_ = _state(p, c, authorizationId);
        _rejectSigned(p, a, proof, PRICE);
        require(_state(p, c, authorizationId) == before_, "successful authorization cannot replay");
        // A fresh issued execution nonce and therefore a new operation root do not reset Ledger authority.
        p.executionNonce = immediate.nextExecutionNonce(id, payer);
        _rejectSigned(p, a, proof, PRICE);
        require(
            manager.nextOperationNonce() == 1 && core.collectionMintedEver(1) == 1,
            "Ledger owns replay across execution nonce"
        );
    }

    function testEveryCanonicalAuthorizationWordIsBound() public {
        bytes32 id = _registerImmediate(_configuration(1, 0, vm.addr(SIGNER_KEY), 1));
        S.Purchase memory p = _purchase(id, payer, 2);
        A.SaleAuthorization memory original = _authorization(p, 102);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(original);
        bytes memory encoded = abi.encode(original);
        require(encoded.length == 24 * 32, "permanent twenty-four words");
        for (uint256 i; i < 24; ++i) {
            bytes memory changed = abi.encode(original);
            assembly ("memory-safe") {
                let word := add(add(changed, 32), mul(i, 32))
                mstore(word, add(mload(word), 1))
            }
            A.SaleAuthorization memory a = abi.decode(changed, (A.SaleAuthorization));
            require(_literalDigest(a) != _literalDigest(original), "every field contributes");
            (bool ok,) = address(immediate)
                .staticcall(abi.encodeCall(immediate.previewSignedPurchase, (p, a, proof)));
            require(!ok, "mutated signed word rejected");
        }
        require(
            core.collectionMintedEver(1) == 0 && recorder.totalOfficialSettled(address(0)) == 0,
            "tampering has no progress"
        );
    }

    function testClaimedKindAndCanonicalECDSASignatureAreExplicit() public {
        bytes32 id = _registerImmediate(_configuration(1, 0, vm.addr(SIGNER_KEY), 1));
        S.Purchase memory p = _purchase(id, payer, 3);
        A.SaleAuthorization memory a = _authorization(p, 103);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        proof.kind = 2;
        _rejectSigned(p, a, proof, PRICE);
        proof.kind = 1;
        proof.authorizer = payer;
        _rejectSigned(p, a, proof, PRICE);
        proof = _sign(a);
        (uint8 v, bytes32 r, bytes32 lowS) = vm.sign(SIGNER_KEY, _literalDigest(a));
        bytes32 highS = bytes32(
            uint256(0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141)
                - uint256(lowS)
        );
        proof.signature = abi.encodePacked(r, highS, v == 27 ? uint8(28) : uint8(27));
        _rejectSigned(p, a, proof, PRICE);
        proof.signature = abi.encodePacked(r, lowS, uint8(0));
        _rejectSigned(p, a, proof, PRICE);
        proof.signature = new bytes(0);
        _rejectSigned(p, a, proof, PRICE);
        // ERC2098 is independently presented from the literal digest; code presence is not a kind switch.
        bytes32 vs = bytes32(uint256(lowS) | (uint256(v - 27) << 255));
        proof.signature = abi.encodePacked(r, vs);
        vm.etch(proof.authorizer, hex"60006000fd");
        vm.prank(payer);
        S.Receipt memory receipt = immediate.purchaseSigned{ value: PRICE }(p, a, proof);
        require(
            receipt.saleAuthorizationDigest == _literalDigest(a),
            "explicit code-bearing ECDSA signer"
        );
    }

    function testOfficialSafeThreshold1271SignerIsClaimedAccount() public {
        (OfficialSafe signer, uint256[] memory keys) = _safe(711);
        bytes32 id = _registerImmediate(_configuration(1, 0, address(signer), 2));
        S.Purchase memory p = _purchase(id, payer, 4);
        A.SaleAuthorization memory a = _authorization(p, 104);
        IStreamPrivateSaleAdapter.Signature memory proof = IStreamPrivateSaleAdapter.Signature(
            address(signer),
            2,
            safeThresholdSignature(keys, safeMessageDigest(signer, abi.encode(_literalDigest(a))))
        );
        IStreamPrivateSaleAdapter.Signature memory wrong =
            IStreamPrivateSaleAdapter.Signature(vm.addr(keys[0]), 1, proof.signature);
        _rejectSigned(p, a, wrong, PRICE);
        vm.prank(payer);
        S.Receipt memory r = immediate.purchaseSigned{ value: PRICE }(p, a, proof);
        require(
            manager.isAuthorizationUsed(_id(_literalDigest(a)))
                && r.saleAuthorizationDigest == _literalDigest(a),
            "Safe account authorizes canonical digest"
        );
    }

    function testPublicUnsignedRepeatedPurchasesUseDistinctLedgerIdsAndZeroSalesDigest() public {
        bytes32 id = _registerImmediate(_configuration(2, 1, address(0), 0));
        S.Purchase memory p = _purchase(id, payer, 5);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = immediate.previewPublicPurchase(p);
        require(
            c.executionBinding.authorityMode == 2
                && c.executionBinding.saleAuthorizationDigest == 0,
            "genuine unsigned mode"
        );
        vm.prank(payer);
        S.Receipt memory first = immediate.purchasePublic{ value: PRICE }(p);
        _assertReceipt(p, c, first, auth, 0);
        S.Purchase memory second = _purchase(id, payer, 6);
        (c, auth) = immediate.previewPublicPurchase(second);
        require(
            auth != first.authorizationId && c.executionBinding.executionId != first.executionId,
            "issued nonce separates public requests"
        );
        vm.prank(payer);
        S.Receipt memory r = immediate.purchasePublic{ value: PRICE }(second);
        _assertReceipt(second, c, r, auth, 0);
        require(
            immediate.saleRecord(id).soldQuantity == 2 && _payerCount(payer) == 2,
            "program remains open, actual counter advances"
        );
        require(
            immediateFloor.settlementReceipt(first.settlementKey).firstSaleReceiptHash
                == immediateFloor.settlementReceipt(r.settlementKey).firstSaleReceiptHash,
            "immutable first sale reused"
        );
    }

    function testPublicSafeBuyerUsesActualWalletCallerAndCannotNameAnotherPayer() public {
        (OfficialSafe buyer, uint256[] memory keys) = _safe(712);
        bytes32 id = _registerImmediate(_configuration(2, 0, address(0), 0));
        S.Purchase memory p = _purchase(id, address(buyer), 7);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = immediate.previewPublicPurchase(p);
        bytes memory callData = abi.encodeCall(immediate.purchasePublic, (p));
        uint256 before_ = address(buyer).balance;
        require(
            executeSafe(buyer, keys, address(immediate), PRICE, callData, 0),
            "real threshold wallet CALL"
        );
        S.Receipt memory receipt = immediate.executionReceipt(c.executionBinding.executionId);
        _assertReceipt(p, c, receipt, auth, 0);
        require(
            address(buyer).balance == before_ - PRICE && _payerCount(address(buyer)) == 1,
            "Safe is economic payer"
        );
        p = _purchase(id, payer, 8);
        callData = abi.encodeCall(immediate.purchasePublic, (p));
        bytes32 digest = buyer.getTransactionHash(
            address(immediate), PRICE, callData, 0, 0, 0, 0, address(0), address(0), buyer.nonce()
        );
        bytes memory sig = safeThresholdSignature(keys, digest);
        uint256 nonce = buyer.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        buyer.execTransaction(
            address(immediate), PRICE, callData, 0, 0, 0, 0, address(0), payable(address(0)), sig
        );
        require(
            buyer.nonce() == nonce && _payerCount(payer) == 0, "failed Safe cannot spoof EOA payer"
        );
    }

    function testSignedNativePayerExecutorMustBeLiteralCaller() public {
        bytes32 id = _registerImmediate(_configuration(1, 0, vm.addr(SIGNER_KEY), 1));
        S.Purchase memory p = _purchase(id, payer, 9);
        A.SaleAuthorization memory a = _authorization(p, 109);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        immediate.previewSignedPurchase(p, a, proof); // An arbitrary reader can preview.
        vm.deal(address(this), PRICE);
        (bool ok,) = address(immediate).call{ value: PRICE }(
            abi.encodeCall(immediate.purchaseSigned, (p, a, proof))
        );
        require(!ok, "seller proof cannot spend as a named payer");
        p.executor = address(this);
        a = _authorization(p, 110);
        _rejectSigned(p, a, _sign(a), PRICE);
        require(
            _payerCount(payer) == 0 && manager.nextOperationNonce() == 0,
            "caller denial leaves mint untouched"
        );
    }

    function testFixedCapAndOpenEditionConfigurationAndClosure() public {
        S.Configuration memory c = _configuration(2, 0, address(0), 0);
        c.saleSupplyLimit = 0;
        _rejectConfiguration(c);
        c.saleKind = 1;
        c.saleSupplyLimit = 2;
        _rejectConfiguration(c);
        c.saleKind = 0;
        c.saleSupplyLimit = 1;
        bytes32 fixedId = _registerImmediate(c);
        S.Purchase memory p = _purchase(fixedId, payer, 10);
        vm.prank(payer);
        immediate.purchasePublic{ value: PRICE }(p);
        p = _purchase(fixedId, payer, 11);
        _rejectPublic(p, PRICE);
        c.saleKind = 1;
        c.saleSupplyLimit = 0;
        c.manualClose = true;
        c.endsAt = 0;
        bytes32 openId = _registerImmediate(c);
        p = _purchase(openId, payer, 12);
        vm.prank(payer);
        immediate.purchasePublic{ value: PRICE }(p);
        vm.prank(address(revenueAuthority));
        immediate.closeSale(openId);
        p = _purchase(openId, payer, 13);
        _rejectPublic(p, PRICE);
        require(
            immediate.saleRecord(openId).closed && immediate.saleRecord(openId).soldQuantity == 1,
            "manual terminal close"
        );
    }

    function testPublicAndSignedAuthorityModesCannotBeInterchanged() public {
        bytes32 pub = _registerImmediate(_configuration(2, 0, address(0), 0));
        S.Purchase memory p = _purchase(pub, payer, 14);
        A.SaleAuthorization memory a = _authorization(p, 114);
        _rejectSigned(p, a, _sign(a), PRICE);
        bytes32 signedId = _registerImmediate(_configuration(1, 0, vm.addr(SIGNER_KEY), 1));
        _rejectPublic(_purchase(signedId, payer, 15), PRICE);
        require(core.collectionMintedEver(1) == 0, "no authority fallback");
    }

    function testDisabledExactValueAndDeclaredZeroFeeCreditsRemainDifferent() public {
        immediateEntropy.configure(true, 0);
        bytes32 id = _registerImmediate(_configuration(2, 0, address(0), 0));
        S.Purchase memory p = _purchase(id, payer, 16);
        require(!immediate.saleRevealQuote(id).policy.declared, "explicit no-reveal quote");
        _rejectPublic(p, PRICE + 1);
        vm.prank(payer);
        S.Receipt memory first = immediate.purchasePublic{ value: PRICE }(p);
        require(first.revealCredit == 0 && first.revealFee == 0, "no undeclared ETH line item");
        immediateEntropy.configure(false, 17);
        require(
            immediate.saleRevealQuote(id).policy.revealFeePerTokenWei == 17,
            "live operational quote"
        );
        bytes32 configHash = immediate.saleRecord(id).configHash;
        immediateEntropy.configure(false, 0);
        require(
            immediate.saleRecord(id).configHash == configHash
                && immediate.saleRevealQuote(id).policy.declared,
            "declared fee drift does not rewrite sale"
        );
        p = _purchase(id, payer, 17);
        vm.prank(payer);
        S.Receipt memory second = immediate.purchasePublic{ value: PRICE + 17 }(p);
        require(
            second.revealFee == 0 && second.revealCredit == 17,
            "zero live fee retains declared allowance as pull credit"
        );
        require(
            immediate.refundableBalance(id, payer) == 17 && immediate.refundLiability() == 17
                && address(immediate).balance == 17,
            "fully backed excess"
        );
        uint256 before_ = payer.balance;
        vm.prank(payer);
        immediate.claimRefund(id, payer);
        require(
            payer.balance == before_ + 17 && immediate.refundLiability() == 0
                && address(immediate).balance == 0,
            "payer alone claims credit"
        );
    }

    function testDeclaredFeeShortfallRollsBackAndExactAuthorizationRetries() public {
        immediateEntropy.configure(false, 12);
        bytes32 id = _registerImmediate(_configuration(1, 0, vm.addr(SIGNER_KEY), 1));
        S.Purchase memory p = _purchase(id, payer, 18);
        A.SaleAuthorization memory a = _authorization(p, 118);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        N.NativeSettlementCandidate memory c = immediate.previewSignedPurchase(p, a, proof);
        bytes32 before_ = _state(p, c, _id(_literalDigest(a)));
        _rejectSigned(p, a, proof, PRICE + 11);
        require(_state(p, c, _id(_literalDigest(a))) == before_, "fee denial no progress");
        vm.prank(payer);
        S.Receipt memory r = immediate.purchaseSigned{ value: PRICE + 20 }(p, a, proof);
        require(
            r.revealFee == 12 && r.revealCredit == 8 && immediateEntropy.revealFeeEscrow(1) == 12,
            "captured fee and excess conserve value"
        );
    }

    function testRefundRejectsStrangerAndHostileRecipientThenExactClaimRetries() public {
        bytes32 id = _registerImmediate(_configuration(2, 0, address(0), 0));
        S.Purchase memory p = _purchase(id, payer, 180);
        vm.recordLogs();
        vm.prank(payer);
        S.Receipt memory receipt = immediate.purchasePublic{ value: PRICE + 19 }(p);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 credited = keccak256("SalePaymentExcessCredited(uint16,bytes32,address,uint256)");
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(immediate) || logs[i].topics[0] != credited) continue;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == id
                    && logs[i].topics[2] == bytes32(uint256(uint160(payer))),
                "credit indexes actual native payer"
            );
            (uint16 schema, uint256 amount) = abi.decode(logs[i].data, (uint16, uint256));
            require(schema == 1 && amount == 19, "exact credit event");
            ++found;
        }
        require(
            found == 1 && receipt.revealCredit == 19 && immediate.refundAccountCount() == 1,
            "one append-only credited account"
        );
        (bytes32 indexedSale, address indexedPayer) = immediate.refundAccountAt(0);
        require(indexedSale == id && indexedPayer == payer, "exact discovery index");
        vm.prank(address(revenueAuthority));
        immediate.closeSale(id);
        NativeAuctionReceiver receiver = new NativeAuctionReceiver();
        receiver.configure(false, true, address(0), "", address(0));
        bytes memory claim = abi.encodeCall(immediate.claimRefund, (id, address(receiver)));
        vm.prank(address(0xBAD));
        (bool ok, bytes memory reason) = address(immediate).call(claim);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamImmediateSaleReveal.SaleRefundEmpty.selector, id, address(0xBAD)
                        )
                    ),
            "stranger cannot select another payer's credit"
        );
        vm.prank(payer);
        (ok, reason) = address(immediate).call(claim);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamImmediateSaleReveal.SaleRefundTransferFailed.selector,
                            address(receiver)
                        )
                    ),
            "hostile native receiver fails atomically"
        );
        require(
            immediate.refundableBalance(id, payer) == 19 && immediate.refundLiability() == 19
                && address(immediate).balance == 19 && address(receiver).balance == 0
                && immediate.refundAccountCount() == 1,
            "failed claim keeps exact credit and discovery"
        );
        receiver.configure(false, false, address(0), "", address(0));
        vm.recordLogs();
        vm.prank(payer);
        (ok, reason) = address(immediate).call(claim);
        require(ok && reason.length == 0, "identical claim payload retries after receiver repair");
        require(
            immediate.refundableBalance(id, payer) == 0 && immediate.refundLiability() == 0
                && address(immediate).balance == 0 && address(receiver).balance == 19,
            "exact native credit paid once"
        );
        (indexedSale, indexedPayer) = immediate.refundAccountAt(0);
        require(
            immediate.refundAccountCount() == 1 && indexedSale == id && indexedPayer == payer,
            "zero balance remains in original index"
        );
        logs = vm.getRecordedLogs();
        bytes32 claimed = keccak256("SaleRefundClaimed(uint16,bytes32,address,address,uint256)");
        found = 0;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(immediate) || logs[i].topics[0] != claimed) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == id
                    && logs[i].topics[2] == bytes32(uint256(uint160(payer)))
                    && logs[i].topics[3] == bytes32(uint256(uint160(address(receiver)))),
                "claim indexes payer and selected recipient separately"
            );
            (uint16 schema, uint256 amount) = abi.decode(logs[i].data, (uint16, uint256));
            require(schema == 1 && amount == 19, "exact final claim event");
            ++found;
        }
        require(
            found == 1
                && keccak256(abi.encode(immediate.executionReceipt(receipt.executionId)))
                    == keccak256(abi.encode(receipt)),
            "closed sale retains original successful purchase receipt"
        );
    }

    function testArtistConsentAndStrictPrimaryPolicyRejectWithoutPayment() public {
        S.Configuration memory config = _configuration(2, 0, address(0), 0);
        config.expectedPrimaryPolicyHash = keccak256("unrelated economics");
        _rejectConfiguration(config);
        config = _configuration(2, 0, address(0), 0);
        config.primaryPolicyMode = 1;
        _rejectConfiguration(config);
        config.primaryPolicyMode = 0;
        bytes32 id = _registerImmediate(config);
        S.Purchase memory p = _purchase(id, payer, 19);
        artists.setConsent(false);
        _rejectPublic(p, PRICE);
        require(
            payer.balance == 1 ether && recorder.totalOfficialSettled(address(0)) == 0,
            "typed Artist denial before payment"
        );
        artists.setConsent(true);
        vm.prank(payer);
        immediate.purchasePublic{ value: PRICE }(p);
    }

    function testLateReceiverFailureRollsBackRecorderFloorLedgerAndExactSignedRetry() public {
        NativeAuctionReceiver receiver = new NativeAuctionReceiver();
        receiver.configure(true, false, address(0), "", address(0));
        bytes32 id = _registerImmediate(_configuration(1, 0, vm.addr(SIGNER_KEY), 1));
        S.Purchase memory p = _purchase(id, payer, 20);
        p.initialRecipient = address(receiver);
        A.SaleAuthorization memory a = _authorization(p, 120);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        N.NativeSettlementCandidate memory c = immediate.previewSignedPurchase(p, a, proof);
        bytes32 auth = _id(_literalDigest(a));
        bytes32 before_ = _state(p, c, auth);
        _rejectSigned(p, a, proof, PRICE);
        require(_state(p, c, auth) == before_, "late receiver atomic rollback");
        receiver.configure(false, false, address(0), "", address(0));
        vm.prank(payer);
        S.Receipt memory r = immediate.purchaseSigned{ value: PRICE }(p, a, proof);
        _assertReceipt(p, c, r, auth, _literalDigest(a));
        require(
            core.ownerOf(r.tokenId) == address(receiver),
            "identical signed content delivers on retry"
        );
    }

    function testHistoricalSignerDisableAndCloseStillPermitExactLedgerVoid() public {
        address signer = vm.addr(SIGNER_KEY);
        bytes32 id = _registerImmediate(_configuration(1, 0, signer, 1));
        S.Purchase memory p = _purchase(id, payer, 21);
        A.SaleAuthorization memory a = _authorization(p, 121);
        bytes32 auth = _id(_literalDigest(a));
        vm.prank(address(revenueAuthority));
        immediate.configureCollectionSigner(1, signer, 1, keccak256("disabled signer"), false);
        vm.prank(address(revenueAuthority));
        immediate.closeSale(id);
        vm.warp(uint256(a.deadline) + 1);
        vm.prank(signer);
        bytes32 actual = IStreamMintImmediateSaleAuthorizationRevocation(address(manager))
            .voidMintImmediateSaleAuthorization(a, signer, 1, "");
        require(
            actual == auth && manager.isAuthorizationUsed(auth),
            "same original full-payload Ledger id"
        );
        require(
            manager.nextOperationNonce() == 0 && core.collectionMintedEver(1) == 0
                && _payerCount(payer) == 0,
            "void consumes no operation or counter"
        );
    }

    function testRelayedOriginalDomainVoidBlocksStillLiveSignedExecution() public {
        address signer = vm.addr(SIGNER_KEY);
        bytes32 id = _registerImmediate(_configuration(1, 0, signer, 1));
        S.Purchase memory p = _purchase(id, payer, 22);
        A.SaleAuthorization memory a = _authorization(p, 122);
        IStreamPrivateSaleAdapter.Signature memory purchaseProof = _sign(a);
        bytes32 auth = _id(_literalDigest(a));
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(immediate)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "MintTicketRevocation(uint256 chainId,address manager,address ledger,bytes32 authorizationId)"
                ),
                block.chainid,
                address(manager),
                address(ledger),
                auth
            )
        );
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(SIGNER_KEY, keccak256(abi.encodePacked(hex"1901", domain, body)));
        IStreamMintImmediateSaleAuthorizationRevocation(address(manager))
            .voidMintImmediateSaleAuthorization(a, signer, 1, abi.encodePacked(r, s, v));
        _rejectSigned(p, a, purchaseProof, PRICE);
        require(
            manager.isAuthorizationUsed(auth) && manager.nextOperationNonce() == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "voided live sale cannot mint or pay"
        );
    }

    function testNativeMerklePriceUsesBeneficiaryAndSameProofAsManager() public {
        (bytes32 phase, bytes32 counter, bytes memory resolverData) =
            _merklePhase(address(0xCAFE), 700);
        S.Configuration memory config = _configuration(2, 0, address(0), 0);
        config.phaseId = phase;
        config.mintPolicyHash = manager.phasePolicyHash(1, phase);
        _rejectConfiguration(config); // A Merkle counter cannot be hidden by a zero priceCounterId.
        config.priceCounterId = counter;
        bytes32 id = _registerImmediate(config);
        S.Purchase memory p = _purchase(id, payer, 23);
        p.resolverData = resolverData;
        (N.NativeSettlementCandidate memory c, bytes32 auth) = immediate.previewPublicPurchase(p);
        require(
            c.sale.amount == 700 && c.sale.beneficiary != p.initialRecipient,
            "authenticated leaf is beneficiary keyed"
        );
        S.Purchase memory wrong = p;
        wrong.beneficiary = p.initialRecipient;
        _rejectPublic(wrong, 700);
        p.beneficiary = address(0xCAFE);
        vm.prank(payer);
        S.Receipt memory r = immediate.purchasePublic{ value: 700 }(p);
        _assertReceipt(p, c, r, auth, 0);
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            phase,
            counter,
            payer,
            p.beneficiary,
            address(immediate),
            address(0),
            0
        );
        require(
            ledger.counterValue(manager.previewCounterValueKey(1, phase, counter, subject)) == 1,
            "same authenticated leaf consumed by actual Ledger"
        );
    }

    function testExplicitZeroMerklePriceIsRejectedByPaidOnlyFamily() public {
        (bytes32 phase, bytes32 counter, bytes memory proof) = _merklePhase(address(0xCAFE), 0);
        S.Configuration memory config = _configuration(2, 0, address(0), 0);
        config.phaseId = phase;
        config.mintPolicyHash = manager.phasePolicyHash(1, phase);
        config.priceCounterId = counter;
        bytes32 id = _registerImmediate(config);
        S.Purchase memory p = _purchase(id, payer, 24);
        p.resolverData = proof;
        _rejectPublic(p, 0);
        require(
            core.collectionMintedEver(1) == 0 && recorder.totalOfficialSettled(address(0)) == 0,
            "no synthetic zero paid receipt"
        );
    }

    function testSignedImmutableBaselineAllowsAuthenticatedLowerAndHigherLeafPrices() public {
        for (uint256 i; i < 2; ++i) {
            uint256 price = i == 0 ? 700 : 1300;
            (bytes32 phase, bytes32 counter, bytes memory proof) =
                _merklePhase(address(0xCAFE), price);
            S.Configuration memory config = _configuration(1, 0, vm.addr(SIGNER_KEY), 1);
            config.phaseId = phase;
            config.mintPolicyHash = manager.phasePolicyHash(1, phase);
            config.priceCounterId = counter;
            bytes32 id = _registerImmediate(config);
            S.Purchase memory p = _purchase(id, payer, 300 + i);
            p.resolverData = proof;
            A.SaleAuthorization memory a = _authorization(p, 300 + i);
            require(a.unitPrice == 1000, "signed immutable program baseline");
            IStreamPrivateSaleAdapter.Signature memory signature = _sign(a);
            N.NativeSettlementCandidate memory c = immediate.previewSignedPurchase(p, a, signature);
            require(c.sale.amount == price, "selected original native leaf replaces baseline");
            vm.prank(payer);
            S.Receipt memory r = immediate.purchaseSigned{ value: price }(p, a, signature);
            _assertReceipt(p, c, r, _id(_literalDigest(a)), _literalDigest(a));
        }
        require(
            recorder.totalOfficialSettled(address(0)) == 2000,
            "lower and higher actual charges conserve value"
        );
    }

    function testUnsyncedArtistContestAndUnavailableReadRejectRegistration() public {
        S.Configuration memory config = _configuration(2, 0, address(0), 0);
        ImmediateSalesArtistBoundary boundary = ImmediateSalesArtistBoundary(address(artists));
        uint256 nonce = immediate.nextSaleNonce();
        boundary.setContest(1, false);
        _rejectConfiguration(config);
        boundary.setContest(3, false);
        _rejectConfiguration(config);
        boundary.setContest(0, true);
        _rejectConfiguration(config);
        require(
            immediate.nextSaleNonce() == nonce, "unsynced contest and read failure allocate no sale"
        );
        boundary.setContest(0, false);
        bytes32 id = _registerImmediate(config);
        require(
            immediate.saleRecord(id).saleNonce == nonce,
            "original configuration retries after typed contest clears"
        );
    }

    function testActualConfiguredTicketGateIsOutsideImmediateFamily() public {
        StreamMintTicketGate gate =
            new StreamMintTicketGate(address(revenueAuthority), vm.addr(SIGNER_KEY), 1);
        StreamModuleRegistration memory registration = StreamModuleRegistration(
            address(gate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            MANIFEST,
            type(IStreamMintGate).interfaceId,
            100000,
            address(gate).codehash,
            MANIFEST,
            MANIFEST,
            "urn:immediate:ticket-gate"
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) = _registrationTransition(registration);
        _context(scope, before_, after_, 1);
        vm.prank(address(revenueAuthority));
        registry.registerModule(registration);
        _clearContext();
        bytes32 phase = keccak256("actual gated phase is unsupported");
        manager.configurePhase(
            1,
            phase,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            IStreamMintManager.MintGateConfig(address(gate), gate.gateConfigHash(), 0, 0, 0, 0),
            new bytes32[](0),
            new IStreamMintManager.MintCounterConfig[](0)
        );
        manager.setPhaseExecutor(1, phase, address(immediate), true);
        S.Configuration memory config = _configuration(2, 0, address(0), 0);
        config.phaseId = phase;
        config.mintPolicyHash = manager.phasePolicyHash(1, phase);
        _rejectConfiguration(config);
        require(
            manager.phaseGate(1, phase).gate == address(gate) && core.collectionMintedEver(1) == 0,
            "real configured gate rejected before payment"
        );
    }

    function testSupportedCollectionTemplateMaterializesOriginalWalletAndEscrow() public {
        // Model the pre-association setup window in the explicit Artist fixture. This is not
        // evidence that the actual Artist can erase a nomination or reset its binding.
        artists.accept(address(0));
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 900000, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xC011AB), 0, 100000, keccak256("collaborator")
        );
        bytes32 template =
            resolver.createPrimaryTemplate(entries, keccak256("immutable template terms"));
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, template, 0);
        artists.accept(vm.addr(SIGNER_KEY));
        (profile, wallet,) = resolver.previewCollectionPrimaryProfile(template, 1, address(0));
        require(wallet.code.length == 0, "counterfactual genuine template wallet");
        bytes32 id = _registerImmediate(_configuration(2, 0, address(0), 0));
        S.Purchase memory p = _purchase(id, payer, 310);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = immediate.previewPublicPurchase(p);
        require(
            c.rights.templateId == template && c.rights.profileId == profile
                && c.rights.wallet == wallet,
            "actual template materialization preview"
        );
        vm.prank(payer);
        S.Receipt memory r = immediate.purchasePublic{ value: PRICE }(p);
        _assertReceipt(p, c, r, auth, 0);
        T.PrimarySettlementResult memory result = recorder.settlementResult(r.settlementKey);
        require(
            result.escrowed && escrow.escrowOwed(CLASS, profile, wallet, address(0)) == PRICE
                && wallet.balance == 0,
            "official template amount retained by genuine escrow"
        );
        require(factory.profileExists(profile), "Recorder registered concrete template profile");
    }

    function testExistingPauseRolesBlockAndExactAuthorizationRetriesAfterUnpause() public {
        bytes32 id = _registerImmediate(_configuration(1, 0, vm.addr(SIGNER_KEY), 1));
        S.Purchase memory p = _purchase(id, payer, 311);
        A.SaleAuthorization memory a = _authorization(p, 311);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        N.NativeSettlementCandidate memory c = immediate.previewSignedPurchase(p, a, proof);
        bytes32 before_ = _state(p, c, _id(_literalDigest(a)));
        vm.prank(address(0xA11));
        immediate.setSalePause(id, true, keccak256("actual role pause"));
        _rejectSigned(p, a, proof, PRICE);
        require(
            _state(p, c, _id(_literalDigest(a))) == before_, "pause does not consume paid state"
        );
        vm.prank(address(0xB22));
        immediate.setSalePause(id, false, keccak256("actual role resume"));
        vm.prank(payer);
        S.Receipt memory r = immediate.purchaseSigned{ value: PRICE }(p, a, proof);
        _assertReceipt(p, c, r, _id(_literalDigest(a)), _literalDigest(a));
    }

    function _executionEvents(Vm.Log[] memory logs, S.Receipt memory expected) private view {
        bytes32 topic = keccak256(
            "ImmediateSaleExecution(bytes32,bytes32,bytes32,uint8,(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint256,bytes32,uint256,uint256,uint256))"
        );
        uint256 seen;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(immediate) || logs[i].topics[0] != topic) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == expected.saleId
                    && logs[i].topics[2] == expected.executionId
                    && logs[i].topics[3] == expected.operationRoot,
                "original indexed execution identity"
            );
            (uint8 status, S.Receipt memory receipt) = abi.decode(logs[i].data, (uint8, S.Receipt));
            if (seen++ == 0) {
                require(
                    status == 1 && receipt.tokenId == 0 && receipt.settlementKey == 0,
                    "committed pending record before external calls"
                );
            } else {
                require(
                    status == 2
                        && keccak256(abi.encode(receipt)) == keccak256(abi.encode(expected)),
                    "complete exact finalized event"
                );
            }
        }
        require(
            seen == 2 && immediate.executionStatus(expected.executionId) == 2,
            "one start and one completed execution"
        );
    }

    function _merklePhase(address account, uint256 price)
        private
        returns (bytes32 phase, bytes32 counter, bytes memory data)
    {
        phase = keccak256(abi.encode("immediate price phase", price));
        counter = keccak256("immediate beneficiary allowlist");
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        address(manager),
                        uint256(1),
                        phase,
                        counter,
                        account,
                        uint64(3),
                        true,
                        price
                    )
                )
            )
        );
        bytes32 definition = IStreamMintCounterPolicy(address(ledger))
            .registerCounterDefinition(
                IStreamMintCounterPolicy.Definition(
                    IStreamMintCounterPolicy.CounterScope.PHASE,
                    IStreamMintManager.CounterKeyMode.RECIPIENT,
                    leaf,
                    MANIFEST
                )
            );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = counter;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            3,
            1,
            definition
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            phase,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            gate,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, phase, address(immediate), true);
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        proofs[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        proofs[0][0] = IStreamMintCounterPolicy.AllowlistProof(3, true, price, new bytes32[](0));
        data = abi.encode(proofs);
    }

    function _assertReceipt(
        S.Purchase memory p,
        N.NativeSettlementCandidate memory c,
        S.Receipt memory r,
        bytes32 auth,
        bytes32 digest
    ) internal view {
        require(
            r.saleId == p.saleId && r.executionId == c.executionBinding.executionId
                && r.authorizationId == auth && r.saleAuthorizationDigest == digest,
            "exact sale/authorization receipt"
        );
        require(
            r.operationRoot == c.operationIdentityCommitment && r.operationId == c.operationId
                && r.operationRoot != 0 && r.operationId != 0 && r.tokenId != 0
                && r.chargedAmount == c.sale.amount,
            "exact single token transcript"
        );
        require(
            keccak256(abi.encode(immediate.executionReceipt(r.executionId)))
                == keccak256(abi.encode(r)),
            "full retained adapter receipt"
        );
        require(
            manager.isAuthorizationUsed(auth) && manager.isOperationRootUsed(r.operationRoot),
            "real Ledger replay consumption"
        );
        T.PrimarySettlementResult memory result = recorder.settlementResult(r.settlementKey);
        require(
            recorder.settlementConsumed(r.settlementKey)
                && result.candidateCommitment
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_NATIVE_SETTLEMENT_CANDIDATE_V1"),
                            block.chainid,
                            address(recorder),
                            c
                        )
                    ),
            "original native recorder commitment"
        );
        require(
            result.amount == c.sale.amount && result.asset == address(0)
                && result.executor == p.executor && result.wallet == wallet
                && result.profileId == profile
                && result.operationIdentityCommitment == r.operationRoot,
            "official payer/profile/root tuple"
        );
        StreamConservationFloorTypes.SettlementReceipt memory floor =
            immediateFloor.settlementReceipt(r.settlementKey);
        require(
            floor.receiptHash != 0 && floor.recorder == address(recorder)
                && floor.settlementKey == r.settlementKey
                && floor.candidateCommitment == result.candidateCommitment
                && floor.resultHash == keccak256(abi.encode(result))
                && floor.effectiveTier == WAIVED && floor.releaseReceiptHash == 0,
            "actual permanent WAIVED floor receipt"
        );
        StreamConservationFloorTypes.FirstSaleReceipt memory first = immediateFloor.firstSale(1);
        StreamConservationFloorTypes.CollectionFacts memory emptyFacts;
        bytes32 initialHead = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1"),
                block.chainid,
                address(core),
                address(immediateFloor)
            )
        );
        require(
            first.receiptHash == floor.firstSaleReceiptHash && first.sourceSetHash == initialHead
                && initialHead == immediateFloor.sourceSetHashAt(0) && first.sourceId == 0
                && keccak256(abi.encode(first.facts)) == keccak256(abi.encode(emptyFacts)),
            "waiver retains original source head without documentary facts"
        );
        require(
            immediateFloor.directPrimarySaleFloorReceipt(r.settlementKey).receiptHash == 0,
            "one official payment never creates DIRECT history"
        );
    }

    function _state(S.Purchase memory p, N.NativeSettlementCandidate memory c, bytes32 auth)
        internal
        view
        returns (bytes32)
    {
        bytes32 key = recorder.settlementKey(address(immediate), c.executionBinding.executionId);
        return keccak256(
            abi.encode(
                p.payer.balance,
                wallet.balance,
                address(escrow).balance,
                address(immediate).balance,
                recorder.totalOfficialSettled(address(0)),
                recorder.settlementConsumed(key),
                immediateFloor.settlementReceipt(key),
                immediateFloor.firstSale(1),
                immediate.executionReceipt(c.executionBinding.executionId),
                immediate.nextExecutionNonce(p.saleId, p.payer),
                immediate.saleRecord(p.saleId).soldQuantity,
                immediate.refundLiability(),
                immediateEntropy.mintCalls(),
                immediateEntropy.revealFeeEscrow(1),
                manager.nextOperationNonce(),
                manager.isAuthorizationUsed(auth),
                manager.isOperationRootUsed(c.operationIdentityCommitment),
                core.collectionMintedEver(1),
                _payerCount(p.payer)
            )
        );
    }

    function _id(bytes32 digest) internal pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
    }

    function _payerCount(address account) internal view returns (uint64) {
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.PAYER,
            1,
            PHASE,
            COUNTER,
            account,
            address(0),
            address(immediate),
            address(0),
            0
        );
        return ledger.counterValue(manager.previewCounterValueKey(1, PHASE, COUNTER, subject));
    }

    function _rejectConfiguration(S.Configuration memory c) internal {
        vm.prank(address(revenueAuthority));
        (bool ok,) = address(immediate).call(abi.encodeCall(immediate.registerSale, (c)));
        require(!ok, "unsupported configuration rejects");
    }

    function _rejectSigned(
        S.Purchase memory p,
        A.SaleAuthorization memory a,
        IStreamPrivateSaleAdapter.Signature memory proof,
        uint256 value
    ) internal {
        vm.prank(p.payer);
        (bool ok,) = address(immediate).call{ value: value }(
            abi.encodeCall(immediate.purchaseSigned, (p, a, proof))
        );
        require(!ok, "signed purchase must reject");
    }

    function _rejectPublic(S.Purchase memory p, uint256 value) internal {
        vm.prank(p.payer);
        (bool ok,) =
            address(immediate).call{ value: value }(abi.encodeCall(immediate.purchasePublic, (p)));
        require(!ok, "public purchase must reject");
    }
}

/// @dev Same actual permanent Floor, deliberately undeclared Core tier until the exact retry.
contract StreamNativeImmediateSalesLateFloorTest is NativeImmediateSalesFixture {
    function _declareWaiverAtSetup() internal pure override returns (bool) {
        return false;
    }

    function testMissingFloorEvidenceRollsBackAndExactSignedBytesRetry() public {
        bytes32 id = _registerImmediate(_configuration(1, 0, vm.addr(SIGNER_KEY), 1));
        S.Purchase memory p = _purchase(id, payer, 201);
        A.SaleAuthorization memory a = _authorization(p, 201);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        N.NativeSettlementCandidate memory c = immediate.previewSignedPurchase(p, a, proof);
        bytes memory data = abi.encodeCall(immediate.purchaseSigned, (p, a, proof));
        bytes32 auth = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), _literalDigest(a))
        );
        bytes32 before_ = _floorState(p, c, auth);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(immediate).call{ value: PRICE }(data);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(S.ImmediateSaleResultMismatch.selector)),
            "actual Recorder/floor failure"
        );
        require(
            _floorState(p, c, auth) == before_, "payment/escrow/recorders/nonce/counters roll back"
        );
        require(core.declaredConservationTier(1) == 0, "no implicit waiver after denial");
        _declareWaiver();
        vm.prank(payer);
        (ok, reason) = address(immediate).call{ value: PRICE }(data);
        require(ok, "identical complete signed payload retries");
        S.Receipt memory r = abi.decode(reason, (S.Receipt));
        require(
            r.authorizationId == auth && r.operationRoot == c.operationIdentityCommitment
                && r.operationId == c.operationId,
            "same preview identity after real waiver repair"
        );
        require(
            manager.isAuthorizationUsed(auth) && manager.isOperationRootUsed(r.operationRoot)
                && recorder.totalOfficialSettled(address(0)) == PRICE,
            "one actual official sale"
        );
        require(
            immediateFloor.settlementReceipt(r.settlementKey).effectiveTier == WAIVED
                && immediateFloor.firstSale(1).receiptHash != 0,
            "actual permanent receipt after retry"
        );
    }

    function testMissingFloorEvidencePreservesSafeNonceForExactThresholdRetry() public {
        (OfficialSafe buyer, uint256[] memory keys) = _safe(713);
        bytes32 id = _registerImmediate(_configuration(2, 0, address(0), 0));
        S.Purchase memory p = _purchase(id, address(buyer), 202);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = immediate.previewPublicPurchase(p);
        bytes memory data = abi.encodeCall(immediate.purchasePublic, (p));
        uint256 nonce = buyer.nonce();
        bytes32 digest = buyer.getTransactionHash(
            address(immediate), PRICE, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        bytes32 before_ = _floorState(p, c, auth);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        buyer.execTransaction(
            address(immediate), PRICE, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(
            buyer.nonce() == nonce && _floorState(p, c, auth) == before_,
            "Safe envelope and all paid state roll back"
        );
        _declareWaiver();
        require(
            buyer.execTransaction(
                address(immediate),
                PRICE,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            ),
            "same nonce, payload and threshold signature bytes"
        );
        S.Receipt memory r = immediate.executionReceipt(c.executionBinding.executionId);
        require(
            buyer.nonce() == nonce + 1 && r.authorizationId == auth
                && r.saleAuthorizationDigest == 0 && r.tokenId != 0,
            "Safe public receipt retains literal payer and unsigned mode"
        );
        require(
            recorder.settlementResult(r.settlementKey).executor == address(buyer)
                && immediateFloor.settlementReceipt(r.settlementKey).effectiveTier == WAIVED,
            "real Recorder/Floor joins Safe execution"
        );
    }

    function _floorState(S.Purchase memory p, N.NativeSettlementCandidate memory c, bytes32 auth)
        private
        view
        returns (bytes32)
    {
        bytes32 key = recorder.settlementKey(address(immediate), c.executionBinding.executionId);
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.PAYER,
            1,
            PHASE,
            COUNTER,
            p.payer,
            address(0),
            address(immediate),
            address(0),
            0
        );
        return keccak256(
            abi.encode(
                p.payer.balance,
                wallet.balance,
                address(escrow).balance,
                address(immediate).balance,
                recorder.totalOfficialSettled(address(0)),
                recorder.settlementResult(key),
                immediateFloor.settlementReceipt(key),
                immediateFloor.firstSale(1),
                immediate.executionReceipt(c.executionBinding.executionId),
                immediate.executionStatus(c.executionBinding.executionId),
                immediate.nextExecutionNonce(p.saleId, p.payer),
                immediate.saleRecord(p.saleId).soldQuantity,
                immediate.refundLiability(),
                immediateEntropy.mintCalls(),
                manager.nextOperationNonce(),
                manager.isAuthorizationUsed(auth),
                manager.isOperationRootUsed(c.operationIdentityCommitment),
                core.collectionMintedEver(1),
                ledger.counterValue(manager.previewCounterValueKey(1, PHASE, COUNTER, subject))
            )
        );
    }
}
