// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { NativeClaimSalesFixture } from "../../helpers/NativeClaimSalesFixture.sol";
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

import {
    IStreamNativeClaimSales as C
} from "../../../smart-contracts/interfaces/stream/mint/IStreamNativeClaimSales.sol";
import {
    IStreamNativePublicSaleBinding
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamNativePublicSaleBinding.sol";
import {
    IStreamImmediateSaleAuthorizationBinding
} from "../../../smart-contracts/interfaces/stream/mint/IStreamImmediateSaleAuthorizationBinding.sol";
import { IERC721Receiver } from "../../../smart-contracts/vendor/openzeppelin/IERC721Receiver.sol";
import { ReentrancyGuard } from "../../../smart-contracts/vendor/openzeppelin/ReentrancyGuard.sol";

interface ClaimCallbackVm {
    function expectCall(address target, uint256 value, bytes calldata input, uint64 count) external;
}

/// @dev Actual Core callback observes pending claim state; no typed Recorder or mint substitution.
contract ClaimDeliveryObserver is IERC721Receiver {
    C public immutable claims;
    address public immutable core;
    IStreamMintManager public immutable manager;
    bytes32 public executionId;
    bytes32 public authorizationId;
    bool public fail;
    bool public sawPending;
    bool public reentryRejected;
    bytes public reentryRevertData;
    bytes private retry;

    constructor(C c, address core_, IStreamMintManager m) {
        claims = c;
        core = core_;
        manager = m;
    }

    function configure(bytes32 e, bytes32 a, bool f, bytes memory r) external {
        executionId = e;
        authorizationId = a;
        fail = f;
        retry = r;
    }

    function setFailure(bool f) external {
        fail = f;
    }

    function executeRetry() external returns (S.Receipt memory) {
        (bool ok, bytes memory result) = address(claims).call(retry);
        require(ok, "stored receiver purchase succeeds");
        return abi.decode(result, (S.Receipt));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(msg.sender == core, "actual Core delivery");
        S.Receipt memory r = claims.executionReceipt(executionId);
        require(
            claims.executionStatus(executionId) == 1 && r.tokenId == 0 && r.settlementKey == 0
                && r.authorizationId == authorizationId
                && manager.isAuthorizationUsed(authorizationId),
            "mint follows pending receipt and Ledger consumption"
        );
        require(
            IStreamNativePublicSaleBinding(address(claims)).activePublicNativeCandidate(executionId)
                == 0,
            "free claim has no paid public witness"
        );
        sawPending = true;
        (bool ok, bytes memory result) = address(claims).call(retry);
        reentryRejected = !ok;
        reentryRevertData = result;
        require(!ok, "nested purchase rejected");
        require(!fail, "claim delivery rejected");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual current Core/Manager/Ledger/native Recorder/Floor with typed Artist, entropy,
/// and target-side governance boundaries. This is not the complete current Artist/Executor graph.
contract StreamNativeClaimSalesTest is NativeClaimSalesFixture {
    function testPublicZeroClaimHasRealMintAndNoPaidRecorderOrFloorHistory() public {
        bytes32 id = _registerClaim(_configuration(2, 12, 0, 0, address(0), 0));
        C.Purchase memory p = _purchase(id, payer, 1, 0);
        ClaimDeliveryObserver receiver = new ClaimDeliveryObserver(
            C(address(claims)), address(core), IStreamMintManager(address(manager))
        );
        p.mint.initialRecipient = address(receiver);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        receiver.configure(
            c.executionBinding.executionId, auth, false, abi.encodeCall(claims.purchasePublic, (p))
        );
        uint256 payerBefore = payer.balance;
        vm.recordLogs();
        vm.prank(payer);
        S.Receipt memory r = claims.purchasePublic(p);
        _freeEvents(vm.getRecordedLogs(), r);
        _assertFreeReceipt(p, c, r, auth, 0);
        require(
            receiver.sawPending() && receiver.reentryRejected() && payer.balance == payerBefore,
            "real delivery, nested purchase rejected, no sale payment"
        );
        require(
            _payerCount(payer) == 1 && _payerCount(p.mint.beneficiary) == 0,
            "original PAYER counter"
        );
    }

    function testFreshReceiverPurchaseIsGuardedDuringDeliveryAndSucceedsAfterward() public {
        bytes32 id = _registerClaim(_configuration(2, 12, 0, 0, address(0), 0));
        ClaimDeliveryObserver receiver = new ClaimDeliveryObserver(
            C(address(claims)), address(core), IStreamMintManager(address(manager))
        );
        C.Purchase memory outer = _purchase(id, payer, 31, 0);
        outer.mint.initialRecipient = address(receiver);
        C.Purchase memory nested = _purchase(id, address(receiver), 32, 0);
        require(
            nested.mint.payer == address(receiver) && nested.mint.executor == address(receiver)
                && nested.mint.executionNonce == 1 && _payerCount(address(receiver)) == 0,
            "nested request has its actual caller and unused payer nonce/counter"
        );
        (N.NativeSettlementCandidate memory outerCandidate, bytes32 outerAuth) =
            claims.previewPublicPurchase(outer);
        receiver.configure(
            outerCandidate.executionBinding.executionId,
            outerAuth,
            false,
            abi.encodeCall(claims.purchasePublic, (nested))
        );
        // Claim and Manager share the guard error. Exactly two Manager calls distinguish
        // rejection by Claim from a third nested call rejected later by Manager's guard.
        ClaimCallbackVm(address(vm))
            .expectCall(
                address(manager),
                0,
                abi.encodeWithSelector(IStreamMintManager.executeSingleStepMint.selector),
                2
            );
        vm.prank(payer);
        S.Receipt memory first = claims.purchasePublic(outer);
        _assertFreeReceipt(outer, outerCandidate, first, outerAuth, 0);
        require(
            receiver.sawPending() && receiver.reentryRejected()
                && keccak256(receiver.reentryRevertData())
                    == keccak256(
                        abi.encodeWithSelector(
                            ReentrancyGuard.ReentrancyGuardReentrantCall.selector
                        )
                    ),
            "actual Core delivery captures exact Claim guard rejection"
        );
        // The outer mint advanced the Manager operation nonce. The receiver retains exact calldata;
        // preview its current operation identity without rebuilding the purchase request.
        (N.NativeSettlementCandidate memory nestedCandidate, bytes32 nestedAuth) =
            claims.previewPublicPurchase(nested);
        require(
            claims.nextExecutionNonce(id, address(receiver)) == nested.mint.executionNonce
                && claims.executionStatus(nestedCandidate.executionBinding.executionId) == 0
                && !manager.isAuthorizationUsed(nestedAuth)
                && !manager.isOperationRootUsed(nestedCandidate.operationIdentityCommitment)
                && _payerCount(address(receiver)) == 0 && _payerCount(payer) == 1
                && claims.saleRecord(id).sale.soldQuantity == 1
                && claims.saleRecord(id).sale.config.saleSupplyLimit == 8
                && manager.nextOperationNonce() == 1 && core.collectionMintedEver(1) == 1,
            "nested rejection preserves fresh replay state and counter/supply headroom"
        );
        S.Receipt memory second = receiver.executeRetry();
        _assertFreeReceipt(nested, nestedCandidate, second, nestedAuth, 0);
        require(
            second.tokenId != first.tokenId && claims.nextExecutionNonce(id, address(receiver)) == 2
                && _payerCount(address(receiver)) == 1 && _payerCount(payer) == 1
                && claims.saleRecord(id).sale.soldQuantity == 2 && manager.nextOperationNonce() == 2
                && core.collectionMintedEver(1) == 2,
            "identical receiver request succeeds once after delivery"
        );
    }

    function testSignedZeroClaimUsesLiteral24FieldDomainAndLedgerReplay() public {
        bytes32 id = _registerClaim(_configuration(1, 12, 0, 0, vm.addr(SIGNER_KEY), 1));
        C.Purchase memory p = _purchase(id, payer, 2, 0);
        A.SaleAuthorization memory a = _authorization(p, 101);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        require(
            abi.encode(a).length == 768 && claims.authorizationDigest(a) == _literalDigest(a),
            "original literal24-field Sales domain"
        );
        N.NativeSettlementCandidate memory c = claims.previewSignedPurchase(p, a, proof);
        vm.prank(payer);
        S.Receipt memory r = claims.purchaseSigned(p, a, proof);
        _assertFreeReceipt(p, c, r, _id(_literalDigest(a)), _literalDigest(a));
        p.mint.executionNonce = claims.nextExecutionNonce(id, payer);
        _rejectSigned(p, a, proof, 0);
        require(
            manager.nextOperationNonce() == 1 && core.collectionMintedEver(1) == 1,
            "fresh execution nonce cannot replay seller authorization"
        );
    }

    function testClaimConfigurationPinsKindsPositiveSupplyAndCompleteBand() public {
        C.Configuration memory c = _configuration(2, 12, 0, 0, address(0), 0);
        c.sale.saleSupplyLimit = 0;
        _rejectConfiguration(c);
        c.sale.saleSupplyLimit = 8;
        c.sale.saleKind = 0;
        _rejectConfiguration(c);
        c.sale.saleKind = 12;
        c.maxUnitPrice = 1;
        _rejectConfiguration(c);
        c.maxUnitPrice = 0;
        c.sale.unitPrice = 1;
        _rejectConfiguration(c);
        c.sale.unitPrice = 0;
        c.sale.expectedPrimaryPolicyHash = _primaryPolicyHash();
        _rejectConfiguration(c);
        c = _configuration(2, 13, 1000, 999, address(0), 0);
        _rejectConfiguration(c);
        c.sale.unitPrice = 0;
        c.maxUnitPrice = 0;
        _rejectConfiguration(c);
        c = _configuration(2, 13, 1000, 2000, address(0), 0);
        require(
            claims.saleConfigurationHash(c)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_CLAIM_SALES_CONFIG_V1"),
                        block.chainid,
                        address(claims),
                        c
                    )
                ),
            "literal wrapped configuration hash"
        );
        require(
            claims.saleIdFor(1, PHASE, claims.nextSaleNonce())
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_CLAIM_SALES_ID_V1"),
                        block.chainid,
                        address(claims),
                        uint256(1),
                        PHASE,
                        claims.nextSaleNonce()
                    )
                ),
            "literal claim family identity"
        );
        bytes32 firstHash = claims.saleConfigurationHash(c);
        c.maxUnitPrice = 3000;
        require(
            claims.saleConfigurationHash(c) != firstHash, "immutable price ceiling is committed"
        );
        bytes32 id = _registerClaim(c);
        C.Record memory r = claims.saleRecord(id);
        require(
            r.maxUnitPrice == 3000 && r.sale.config.unitPrice == 1000
                && r.sale.configHash == claims.saleConfigurationHash(c),
            "full retained band"
        );
        (bool ok, bytes memory binding) = address(claims)
            .staticcall(
                abi.encodeCall(
                    IStreamImmediateSaleAuthorizationBinding.immediateSaleAuthorizationBinding, (id)
                )
            );
        require(ok && binding.length == 224, "original exact historical binding geometry");
        (ok, binding) = address(claims)
            .staticcall(
                abi.encodeCall(IStreamNativePublicSaleBinding.publicNativeSaleBinding, (id))
            );
        require(ok && binding.length == 128, "original exact public binding geometry");
    }

    function testPublicPayWhatYouWantSettlesFullChosenAmount() public {
        bytes32 id = _registerClaim(_configuration(2, 13, 1000, 3000, address(0), 0));
        C.Purchase memory p = _purchase(id, payer, 3, 2500);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        require(
            c.sale.amount == 2500 && c.executionBinding.saleAuthorizationDigest == 0,
            "buyer choice and unsigned authority"
        );
        uint256 before_ = payer.balance;
        vm.prank(payer);
        S.Receipt memory r = claims.purchasePublic{ value: 2500 }(p);
        _assertPaidReceipt(p, c, r, auth, 0);
        require(
            payer.balance == before_ - 2500 && recorder.totalOfficialSettled(address(0)) == 2500
                && claims.refundLiability() == 0,
            "whole choice is official revenue, no price change refund"
        );
    }

    function testSignedPayWhatYouWantBindsMinimumAndCompleteChosenRequest() public {
        bytes32 id = _registerClaim(_configuration(1, 13, 1000, 3000, vm.addr(SIGNER_KEY), 1));
        C.Purchase memory p = _purchase(id, payer, 4, 2500);
        A.SaleAuthorization memory a = _authorization(p, 102);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        N.NativeSettlementCandidate memory chosen = claims.previewSignedPurchase(p, a, proof);
        p.chosenUnitPrice = 2000;
        N.NativeSettlementCandidate memory lower = claims.previewSignedPurchase(p, a, proof);
        require(
            chosen.sale.amount == 2500 && lower.sale.amount == 2000
                && chosen.saleExecutionHash != lower.saleExecutionHash
                && chosen.operationIdentityCommitment != lower.operationIdentityCommitment,
            "chosen price changes complete request transcript without rewriting seller minimum"
        );
        p.chosenUnitPrice = 999;
        _rejectSigned(p, a, proof, 999);
        p.chosenUnitPrice = 3001;
        _rejectSigned(p, a, proof, 3001);
        p.chosenUnitPrice = 2500;
        a.unitPrice = 1001;
        _rejectSigned(p, a, proof, 2500);
        a.unitPrice = 1000;
        _rejectSigned(p, a, proof, 2499);
        _rejectSigned(p, a, proof, 2501);
        vm.prank(payer);
        S.Receipt memory r = claims.purchaseSigned{ value: 2500 }(p, a, proof);
        _assertPaidReceipt(p, chosen, r, _id(_literalDigest(a)), _literalDigest(a));
    }

    function testZeroClaimRequiresZeroChoiceAndLiteralCallerWithoutUndeclaredETH() public {
        bytes32 id = _registerClaim(_configuration(2, 12, 0, 0, address(0), 0));
        C.Purchase memory p = _purchase(id, payer, 5, 0);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        bytes32 before_ = _state(p, c, auth);
        _rejectPublic(p, 1);
        p.chosenUnitPrice = 1;
        _rejectPublic(p, 1);
        p.chosenUnitPrice = 0;
        (bool ok,) = address(claims).call(abi.encodeCall(claims.purchasePublic, (p)));
        require(!ok, "outsider cannot execute a named payer");
        p.mint.executor = address(this);
        _rejectPublic(p, 0);
        p.mint.executor = payer;
        require(_state(p, c, auth) == before_, "value and caller denials make no progress");
        vm.prank(payer);
        claims.purchasePublic(p);
    }

    function testZeroClaimSupplyAndSharedPayerFairnessRemainEnforced() public {
        C.Configuration memory c = _configuration(2, 12, 0, 0, address(0), 0);
        c.sale.saleSupplyLimit = 2;
        bytes32 id = _registerClaim(c);
        C.Purchase memory p = _purchase(id, payer, 6, 0);
        vm.prank(payer);
        claims.purchasePublic(p);
        p = _purchase(id, payer, 7, 0);
        vm.prank(payer);
        claims.purchasePublic(p);
        p = _purchase(id, payer, 8, 0);
        _rejectPublic(p, 0);
        require(
            claims.saleRecord(id).sale.closed && claims.saleRecord(id).sale.soldQuantity == 2
                && _payerCount(payer) == 2 && core.collectionMintedEver(1) == 2,
            "free claims close at original positive cap"
        );
    }

    function testZeroClaimArtistConsentFailureRollsBackAndExactRequestRetries() public {
        bytes32 id = _registerClaim(_configuration(2, 12, 0, 0, address(0), 0));
        C.Purchase memory p = _purchase(id, payer, 9, 0);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        bytes32 before_ = _state(p, c, auth);
        artists.setConsent(false);
        _rejectPublic(p, 0);
        require(
            _state(p, c, auth) == before_, "free branch retains genuine Manager/Artist enforcement"
        );
        artists.setConsent(true);
        vm.prank(payer);
        S.Receipt memory r = claims.purchasePublic(p);
        _assertFreeReceipt(p, c, r, auth, 0);
    }

    function testFreeOfficialSafe1271SignerAndPublicSafePayerAreOriginalAccounts() public {
        (OfficialSafe signer, uint256[] memory keys) = _safe(901);
        bytes32 signedId = _registerClaim(_configuration(1, 12, 0, 0, address(signer), 2));
        C.Purchase memory p = _purchase(signedId, payer, 10, 0);
        A.SaleAuthorization memory a = _authorization(p, 103);
        IStreamPrivateSaleAdapter.Signature memory proof = IStreamPrivateSaleAdapter.Signature(
            address(signer),
            2,
            safeThresholdSignature(keys, safeMessageDigest(signer, abi.encode(_literalDigest(a))))
        );
        vm.prank(payer);
        S.Receipt memory first = claims.purchaseSigned(p, a, proof);
        require(
            first.saleAuthorizationDigest == _literalDigest(a),
            "original SafeMessage-wrapped claim authority"
        );
        bytes32 publicId = _registerClaim(_configuration(2, 12, 0, 0, address(0), 0));
        p = _purchase(publicId, address(signer), 11, 0);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        require(
            executeSafe(
                signer, keys, address(claims), 0, abi.encodeCall(claims.purchasePublic, (p)), 0
            ),
            "real Safe CALL claimant"
        );
        S.Receipt memory r = claims.executionReceipt(c.executionBinding.executionId);
        _assertFreeReceipt(p, c, r, auth, 0);
        require(
            _payerCount(address(signer)) == 1 && _payerCount(payer) == 1,
            "each actual payer has its own counter"
        );
    }

    function testFreeSafeLateReceiverFailurePreservesExactEnvelopeForRetry() public {
        (OfficialSafe buyer, uint256[] memory keys) = _safe(902);
        bytes32 id = _registerClaim(_configuration(2, 12, 0, 0, address(0), 0));
        C.Purchase memory p = _purchase(id, address(buyer), 12, 0);
        ClaimDeliveryObserver receiver = new ClaimDeliveryObserver(
            C(address(claims)), address(core), IStreamMintManager(address(manager))
        );
        p.mint.initialRecipient = address(receiver);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        bytes memory callData = abi.encodeCall(claims.purchasePublic, (p));
        receiver.configure(c.executionBinding.executionId, auth, true, callData);
        uint256 nonce = buyer.nonce();
        bytes memory sig = safeThresholdSignature(
            keys,
            buyer.getTransactionHash(
                address(claims), 0, callData, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        bytes32 before_ = _state(p, c, auth);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        buyer.execTransaction(
            address(claims), 0, callData, 0, 0, 0, 0, address(0), payable(address(0)), sig
        );
        require(
            buyer.nonce() == nonce && !receiver.sawPending() && _state(p, c, auth) == before_,
            "whole failed delivery and Safe nonce roll back"
        );
        receiver.setFailure(false);
        require(
            buyer.execTransaction(
                address(claims), 0, callData, 0, 0, 0, 0, address(0), payable(address(0)), sig
            ),
            "byte-identical threshold retry"
        );
        _assertFreeReceipt(p, c, claims.executionReceipt(c.executionBinding.executionId), auth, 0);
    }

    function testFreeDeclaredRevealFeeDriftCreditsOnlyAllowanceAndNeverRevenue() public {
        claimEntropy.configure(false, 12);
        bytes32 id = _registerClaim(_configuration(1, 12, 0, 0, vm.addr(SIGNER_KEY), 1));
        C.Purchase memory p = _purchase(id, payer, 13, 0);
        A.SaleAuthorization memory a = _authorization(p, 104);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        N.NativeSettlementCandidate memory c = claims.previewSignedPurchase(p, a, proof);
        bytes32 before_ = _state(p, c, _id(_literalDigest(a)));
        _rejectSigned(p, a, proof, 11);
        require(
            _state(p, c, _id(_literalDigest(a))) == before_, "reveal underfund makes no progress"
        );
        claimEntropy.configure(false, 7);
        vm.prank(payer);
        S.Receipt memory r = claims.purchaseSigned{ value: 20 }(p, a, proof);
        _assertFreeReceipt(p, c, r, _id(_literalDigest(a)), _literalDigest(a));
        require(
            r.revealFee == 7 && r.revealCredit == 13 && claimEntropy.revealFeeEscrow(1) == 7
                && claims.refundableBalance(id, payer) == 13 && claims.refundLiability() == 13,
            "live fee and unused allowance conserve native value"
        );
        (bool ok,) = address(claims).call(abi.encodeCall(claims.claimRefund, (id, address(this))));
        require(!ok, "stranger cannot direct claimant credit");
        uint256 beforePayer = payer.balance;
        vm.prank(payer);
        claims.claimRefund(id, payer);
        require(
            payer.balance == beforePayer + 13 && claims.refundLiability() == 0
                && address(claims).balance == 0,
            "claimant pull refund"
        );
    }

    function testPublicPayWhatYouWantZeroAndPositiveUseDistinctOfficialPaths() public {
        bytes32 id = _registerClaim(_configuration(2, 13, 0, 2000, address(0), 0));
        C.Purchase memory p = _purchase(id, payer, 14, 0);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        vm.prank(payer);
        S.Receipt memory free = claims.purchasePublic(p);
        _assertFreeReceipt(p, c, free, auth, 0);
        p = _purchase(id, payer, 15, 1200);
        (c, auth) = claims.previewPublicPurchase(p);
        vm.prank(payer);
        S.Receipt memory paid = claims.purchasePublic{ value: 1200 }(p);
        _assertPaidReceipt(p, c, paid, auth, 0);
        require(
            free.settlementKey == 0 && recorder.totalOfficialSettled(address(0)) == 1200
                && claims.saleRecord(id).sale.soldQuantity == 2,
            "free mint does not masquerade as first paid settlement"
        );
    }

    function testMerkleZeroPriceStillAuthenticatesBeneficiaryAndConsumesRealCounter() public {
        (bytes32 phase, bytes32 counter, bytes memory resolverData) =
            _merklePhase(address(0xCAFE), 0);
        C.Configuration memory config = _configuration(2, 13, 0, 2000, address(0), 0);
        config.sale.phaseId = phase;
        config.sale.mintPolicyHash = manager.phasePolicyHash(1, phase);
        _rejectConfiguration(config);
        config.sale.priceCounterId = counter;
        bytes32 id = _registerClaim(config);
        C.Purchase memory p = _purchase(id, payer, 16, 0);
        p.mint.resolverData = resolverData;
        p.mint.beneficiary = address(0xBEEF);
        _rejectPublic(p, 0);
        p.mint.beneficiary = address(0xCAFE);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(p);
        vm.prank(payer);
        S.Receipt memory r = claims.purchasePublic(p);
        _assertFreeReceipt(p, c, r, auth, 0);
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            phase,
            counter,
            payer,
            p.mint.beneficiary,
            address(claims),
            address(0),
            0
        );
        require(
            ledger.counterValue(manager.previewCounterValueKey(1, phase, counter, subject)) == 1,
            "authenticated zero-price leaf is also the actual consumed cap"
        );
    }

    function testMerkleMinimumCannotBypassImmutablePayWhatYouWantBand() public {
        (bytes32 phase, bytes32 counter, bytes memory resolverData) =
            _merklePhase(address(0xCAFE), 0);
        C.Configuration memory config = _configuration(1, 13, 1000, 2000, vm.addr(SIGNER_KEY), 1);
        config.sale.phaseId = phase;
        config.sale.mintPolicyHash = manager.phasePolicyHash(1, phase);
        config.sale.priceCounterId = counter;
        bytes32 id = _registerClaim(config);
        C.Purchase memory p = _purchase(id, payer, 17, 0);
        p.mint.resolverData = resolverData;
        A.SaleAuthorization memory a = _authorization(p, 105);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        _rejectSigned(p, a, proof, 0);
        p.chosenUnitPrice = 1000;
        N.NativeSettlementCandidate memory c = claims.previewSignedPurchase(p, a, proof);
        vm.prank(payer);
        S.Receipt memory r = claims.purchaseSigned{ value: 1000 }(p, a, proof);
        _assertPaidReceipt(p, c, r, _id(_literalDigest(a)), _literalDigest(a));
    }

    function testSignedMinimumAboveBandFloorRemainsAnIndependentAuthorizationLimit() public {
        bytes32 id = _registerClaim(_configuration(1, 13, 0, 2000, vm.addr(SIGNER_KEY), 1));
        C.Purchase memory p = _purchase(id, payer, 19, 999);
        A.SaleAuthorization memory a = _authorization(p, 107);
        a.unitPrice = 1000;
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        _rejectSigned(p, a, proof, 999);
        p.chosenUnitPrice = 1500;
        N.NativeSettlementCandidate memory c = claims.previewSignedPurchase(p, a, proof);
        vm.prank(payer);
        S.Receipt memory r = claims.purchaseSigned{ value: 1500 }(p, a, proof);
        _assertPaidReceipt(p, c, r, _id(_literalDigest(a)), _literalDigest(a));
        require(
            claims.saleRecord(id).sale.config.unitPrice == 0 && a.unitPrice == 1000
                && r.chargedAmount == 1500,
            "band floor, signed minimum, and chosen price stay distinct"
        );
    }

    function testProvenZeroReplacesSignedMinimumButPreservesPinnedZeroFloor() public {
        (bytes32 phase, bytes32 counter, bytes memory resolverData) =
            _merklePhase(address(0xCAFE), 0);
        C.Configuration memory config = _configuration(1, 13, 0, 2000, vm.addr(SIGNER_KEY), 1);
        config.sale.phaseId = phase;
        config.sale.mintPolicyHash = manager.phasePolicyHash(1, phase);
        config.sale.priceCounterId = counter;
        bytes32 id = _registerClaim(config);
        C.Purchase memory p = _purchase(id, payer, 20, 0);
        p.mint.resolverData = resolverData;
        A.SaleAuthorization memory a = _authorization(p, 108);
        a.unitPrice = 1000;
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        N.NativeSettlementCandidate memory c = claims.previewSignedPurchase(p, a, proof);
        vm.prank(payer);
        S.Receipt memory r = claims.purchaseSigned(p, a, proof);
        _assertFreeReceipt(p, c, r, _id(_literalDigest(a)), _literalDigest(a));
        require(
            a.unitPrice == 1000 && r.chargedAmount == 0,
            "genuine zero override of seller minimum executes free semantics"
        );
    }

    function testPureZeroRejectsPositiveSignedMinimumAndPositiveMerkleLeaf() public {
        bytes32 id = _registerClaim(_configuration(1, 12, 0, 0, vm.addr(SIGNER_KEY), 1));
        C.Purchase memory p = _purchase(id, payer, 21, 0);
        A.SaleAuthorization memory a = _authorization(p, 109);
        a.unitPrice = 1;
        _rejectSigned(p, a, _sign(a), 0);
        (bytes32 phase, bytes32 counter, bytes memory resolverData) =
            _merklePhase(address(0xCAFE), 1);
        C.Configuration memory config = _configuration(2, 12, 0, 0, address(0), 0);
        config.sale.phaseId = phase;
        config.sale.mintPolicyHash = manager.phasePolicyHash(1, phase);
        config.sale.priceCounterId = counter;
        id = _registerClaim(config);
        p = _purchase(id, payer, 22, 0);
        p.mint.resolverData = resolverData;
        _rejectPublic(p, 0);
        require(
            core.collectionMintedEver(1) == 0 && manager.nextOperationNonce() == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "pure free declaration cannot carry hidden positive pricing"
        );
    }

    function testPublicClaimAuthorityIdsBindEveryChosenRequestIncludingNonce() public {
        bytes32 id = _registerClaim(_configuration(2, 13, 0, 2000, address(0), 0));
        C.Purchase memory p = _purchase(id, payer, 23, 0);
        (N.NativeSettlementCandidate memory c, bytes32 freeAuth) = claims.previewPublicPurchase(p);
        p.chosenUnitPrice = 1000;
        (N.NativeSettlementCandidate memory paid, bytes32 paidAuth) =
            claims.previewPublicPurchase(p);
        require(
            freeAuth != paidAuth
                && c.executionBinding.executionId != paid.executionBinding.executionId,
            "public authority binds chosen amount"
        );
        p.chosenUnitPrice = 0;
        vm.prank(payer);
        S.Receipt memory first = claims.purchasePublic(p);
        p = _purchase(id, payer, 23, 0);
        (c, freeAuth) = claims.previewPublicPurchase(p);
        require(
            first.authorizationId != freeAuth
                && first.executionId != c.executionBinding.executionId,
            "issued next nonce distinguishes otherwise identical free requests"
        );
        vm.prank(payer);
        S.Receipt memory second = claims.purchasePublic(p);
        _assertFreeReceipt(p, c, second, freeAuth, 0);
        require(
            _payerCount(payer) == 2 && claims.saleRecord(id).sale.soldQuantity == 2,
            "both actual singleton claims progress"
        );
    }

    function testHistoricalClaimSignerCanVoidAfterCloseWithoutLiveEconomics() public {
        bytes32 id = _registerClaim(_configuration(1, 12, 0, 0, vm.addr(SIGNER_KEY), 1));
        C.Purchase memory p = _purchase(id, payer, 18, 0);
        A.SaleAuthorization memory a = _authorization(p, 106);
        bytes32 auth = _id(_literalDigest(a));
        vm.prank(address(revenueAuthority));
        claims.closeSale(id);
        vm.prank(address(revenueAuthority));
        claims.configureCollectionSigner(
            1, vm.addr(SIGNER_KEY), 1, keccak256("historical signer retired"), false
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                address(claims)
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
            .voidMintImmediateSaleAuthorization(
                a, vm.addr(SIGNER_KEY), 1, abi.encodePacked(r, s, v)
            );
        require(
            manager.isAuthorizationUsed(auth) && manager.nextOperationNonce() == 0
                && core.collectionMintedEver(1) == 0,
            "original Ledger void, no economics or mint"
        );
        _rejectSigned(p, a, _sign(a), 0);
    }

    function _assertFreeReceipt(
        C.Purchase memory p,
        N.NativeSettlementCandidate memory c,
        S.Receipt memory r,
        bytes32 auth,
        bytes32 digest
    ) internal view {
        require(
            r.saleId == p.mint.saleId && r.executionId == c.executionBinding.executionId
                && r.authorizationId == auth && r.saleAuthorizationDigest == digest
                && r.tokenId != 0 && r.operationRoot == c.operationIdentityCommitment
                && r.operationId == c.operationId,
            "exact free mint receipt"
        );
        require(
            r.chargedAmount == 0 && r.settlementKey == 0
                && claims.executionStatus(r.executionId) == 2
                && keccak256(abi.encode(claims.executionReceipt(r.executionId)))
                    == keccak256(abi.encode(r)),
            "free final receipt retained"
        );
        require(
            core.ownerOf(r.tokenId) == p.mint.initialRecipient && manager.isAuthorizationUsed(auth)
                && manager.isOperationRootUsed(r.operationRoot),
            "actual Core identity and Ledger replay"
        );
        bytes32 key = recorder.settlementKey(address(claims), r.executionId);
        require(
            !recorder.settlementConsumed(key)
                && recorder.settlementResult(key).candidateCommitment == 0
                && claimFloor.settlementReceipt(key).receiptHash == 0
                && claimFloor.directPrimarySaleFloorReceipt(key).receiptHash == 0,
            "no official or DIRECT record for this free claim"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 0
                && claimFloor.firstSale(1).receiptHash == 0 && wallet.balance == 0
                && address(escrow).balance == 0,
            "free mint cannot establish revenue or conservation floor"
        );
        require(
            claims.activePublicNativeCandidate(r.executionId) == 0,
            "no lingering paid public witness"
        );
    }

    function _freeEvents(Vm.Log[] memory logs, S.Receipt memory r) private view {
        uint256 seen;
        bytes32 eventId = keccak256("FreeClaimExecuted(bytes32,bytes32,uint256,bytes32)");
        for (uint256 i; i < logs.length; ++i) {
            require(
                logs[i].emitter != address(recorder) && logs[i].emitter != address(claimFloor),
                "no paid recorder or conservation events on zero path"
            );
            if (logs[i].emitter == address(claims) && logs[i].topics[0] == eventId) {
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == r.saleId
                        && logs[i].topics[2] == r.executionId
                        && uint256(logs[i].topics[3]) == r.tokenId
                        && abi.decode(logs[i].data, (bytes32)) == r.authorizationId,
                    "exact free-event identity and authorization"
                );
                ++seen;
            }
        }
        require(seen == 1, "one explicit free-claim event");
    }

    function _merklePhase(address account, uint256 price)
        private
        returns (bytes32 phase, bytes32 counter, bytes memory data)
    {
        phase = keccak256(abi.encode("claims price phase", price));
        counter = keccak256("claims beneficiary allowlist");
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
        manager.setPhaseExecutor(1, phase, address(claims), true);
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        proofs[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        proofs[0][0] = IStreamMintCounterPolicy.AllowlistProof(3, true, price, new bytes32[](0));
        data = abi.encode(proofs);
    }

    function _assertPaidReceipt(
        C.Purchase memory p,
        N.NativeSettlementCandidate memory c,
        S.Receipt memory r,
        bytes32 auth,
        bytes32 digest
    ) internal view {
        require(
            r.saleId == p.mint.saleId && r.executionId == c.executionBinding.executionId
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
            keccak256(abi.encode(claims.executionReceipt(r.executionId)))
                == keccak256(abi.encode(r)),
            "full retained adapter receipt"
        );
        require(
            manager.isAuthorizationUsed(auth) && manager.isOperationRootUsed(r.operationRoot),
            "real Ledger replay consumption"
        );
        require(
            core.ownerOf(r.tokenId) == p.mint.initialRecipient
                && claims.executionStatus(r.executionId) == 2,
            "paid mint has its final owner and COMPLETED execution status"
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
                && result.executor == p.mint.executor && result.wallet == wallet
                && result.profileId == profile
                && result.operationIdentityCommitment == r.operationRoot,
            "official payer/profile/root tuple"
        );
        StreamConservationFloorTypes.SettlementReceipt memory floor =
            claimFloor.settlementReceipt(r.settlementKey);
        require(
            floor.receiptHash != 0 && floor.recorder == address(recorder)
                && floor.settlementKey == r.settlementKey
                && floor.candidateCommitment == result.candidateCommitment
                && floor.resultHash == keccak256(abi.encode(result))
                && floor.effectiveTier == WAIVED && floor.releaseReceiptHash == 0,
            "actual permanent WAIVED floor receipt"
        );
        StreamConservationFloorTypes.FirstSaleReceipt memory first = claimFloor.firstSale(1);
        StreamConservationFloorTypes.CollectionFacts memory emptyFacts;
        bytes32 initialHead = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1"),
                block.chainid,
                address(core),
                address(claimFloor)
            )
        );
        require(
            first.receiptHash == floor.firstSaleReceiptHash && first.sourceSetHash == initialHead
                && initialHead == claimFloor.sourceSetHashAt(0) && first.sourceId == 0
                && keccak256(abi.encode(first.facts)) == keccak256(abi.encode(emptyFacts)),
            "waiver retains original source head without documentary facts"
        );
        require(
            claimFloor.directPrimarySaleFloorReceipt(r.settlementKey).receiptHash == 0,
            "one official payment never creates DIRECT history"
        );
    }

    function _state(C.Purchase memory p, N.NativeSettlementCandidate memory c, bytes32 auth)
        internal
        view
        returns (bytes32)
    {
        bytes32 key = recorder.settlementKey(address(claims), c.executionBinding.executionId);
        bytes32 balances = keccak256(
            abi.encode(
                p.mint.payer.balance,
                wallet.balance,
                address(escrow).balance,
                address(claims).balance,
                recorder.totalOfficialSettled(address(0)),
                recorder.settlementConsumed(key)
            )
        );
        bytes32 receipts = keccak256(
            abi.encode(
                claimFloor.settlementReceipt(key),
                claimFloor.firstSale(1),
                claims.executionReceipt(c.executionBinding.executionId)
            )
        );
        bytes32 counters = keccak256(
            abi.encode(
                claims.nextExecutionNonce(p.mint.saleId, p.mint.payer),
                claims.saleRecord(p.mint.saleId).sale.soldQuantity,
                claims.refundLiability(),
                claimEntropy.mintCalls(),
                claimEntropy.revealFeeEscrow(1),
                manager.nextOperationNonce(),
                manager.isAuthorizationUsed(auth),
                manager.isOperationRootUsed(c.operationIdentityCommitment),
                core.collectionMintedEver(1),
                _payerCount(p.mint.payer)
            )
        );
        return keccak256(abi.encode(balances, receipts, counters));
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
            address(claims),
            address(0),
            0
        );
        return ledger.counterValue(manager.previewCounterValueKey(1, PHASE, COUNTER, subject));
    }

    function _rejectConfiguration(C.Configuration memory c) internal {
        vm.prank(address(revenueAuthority));
        (bool ok,) = address(claims).call(abi.encodeCall(claims.registerSale, (c)));
        require(!ok, "unsupported configuration rejects");
    }

    function _rejectSigned(
        C.Purchase memory p,
        A.SaleAuthorization memory a,
        IStreamPrivateSaleAdapter.Signature memory proof,
        uint256 value
    ) internal {
        vm.prank(p.mint.payer);
        (bool ok,) = address(claims).call{ value: value }(
            abi.encodeCall(claims.purchaseSigned, (p, a, proof))
        );
        require(!ok, "signed purchase must reject");
    }

    function _rejectPublic(C.Purchase memory p, uint256 value) internal {
        vm.prank(p.mint.payer);
        (bool ok,) =
            address(claims).call{ value: value }(abi.encodeCall(claims.purchasePublic, (p)));
        require(!ok, "public purchase must reject");
    }
}

/// @dev Actual permanent Floor with no declared tier/source, so zero claims cannot bootstrap paid evidence.
contract StreamNativeClaimSalesLateFloorTest is NativeClaimSalesFixture {
    function _declareWaiverAtSetup() internal pure override returns (bool) {
        return false;
    }

    function testZeroThenPositiveCannotBypassActualPostMintConservationFloor() public {
        bytes32 id = _registerClaim(_configuration(2, 13, 0, 2000, address(0), 0));
        C.Purchase memory free = _purchase(id, payer, 80, 0);
        vm.prank(payer);
        S.Receipt memory r = claims.purchasePublic(free);
        require(
            r.settlementKey == 0 && core.collectionMintedEver(1) == 1
                && core.declaredConservationTier(1) == 0
                && claimFloor.firstSale(1).receiptHash == 0,
            "free delivery does not synthesize conservation evidence"
        );
        C.Purchase memory paid = _purchase(id, payer, 81, 1000);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = claims.previewPublicPurchase(paid);
        bytes32 key = recorder.settlementKey(address(claims), c.executionBinding.executionId);
        uint256 before_ = payer.balance;
        vm.prank(payer);
        (bool ok,) =
            address(claims).call{ value: 1000 }(abi.encodeCall(claims.purchasePublic, (paid)));
        require(
            !ok && payer.balance == before_ && claims.saleRecord(id).sale.soldQuantity == 1
                && claims.nextExecutionNonce(id, payer) == 2 && manager.nextOperationNonce() == 1
                && !manager.isAuthorizationUsed(auth) && core.collectionMintedEver(1) == 1
                && !recorder.settlementConsumed(key)
                && recorder.totalOfficialSettled(address(0)) == 0
                && claimFloor.firstSale(1).receiptHash == 0,
            "positive path still requires actual post-mint floor evidence and rolls back"
        );
        // Core's default after a completed free mint is MUSEUM_GRADE_LITE; a late waiver is not a repair.
        (ok,) = address(claimMetadata)
            .call(abi.encodeCall(claimMetadata.declareConservationTier, (uint256(1), WAIVED)));
        require(
            !ok && core.declaredConservationTier(1) == 0,
            "cannot retrofit waiver after free delivery"
        );
    }
}
