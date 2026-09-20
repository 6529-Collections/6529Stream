// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { NativeDutchSalesFixture } from "../../helpers/NativeDutchSalesFixture.sol";
import { ImmediateSalesArtistBoundary } from "../../helpers/NativeImmediateSalesFixture.sol";
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
    IStreamNativeDutchSales as D
} from "../../../smart-contracts/interfaces/stream/mint/IStreamNativeDutchSales.sol";
import {
    IStreamNativePublicSaleBinding
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamNativePublicSaleBinding.sol";
import {
    IStreamImmediateSaleAuthorizationBinding
} from "../../../smart-contracts/interfaces/stream/mint/IStreamImmediateSaleAuthorizationBinding.sol";
import { IERC721Receiver } from "../../../smart-contracts/vendor/openzeppelin/IERC721Receiver.sol";

/// @dev Actual Core callback observes pending Dutch state; no typed Recorder or mint substitution.
contract DutchDeliveryObserver is IERC721Receiver {
    D public immutable dutch;
    address public immutable core;
    IStreamMintManager public immutable manager;
    bytes32 public executionId;
    bytes32 public authorizationId;
    bool public fail;
    bool public sawPending;
    bool public reentryRejected;
    bytes private retry;

    constructor(D c, address core_, IStreamMintManager m) {
        dutch = c;
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

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(msg.sender == core, "actual Core delivery");
        S.Receipt memory r = dutch.executionReceipt(executionId);
        require(
            dutch.executionStatus(executionId) == 1 && r.tokenId == 0 && r.settlementKey == 0
                && r.authorizationId == authorizationId
                && manager.isAuthorizationUsed(authorizationId),
            "mint follows pending receipt and Ledger consumption"
        );
        require(
            IStreamNativePublicSaleBinding(address(dutch)).activePublicNativeCandidate(executionId)
                == 0,
            "free Dutch mint has no paid public witness"
        );
        sawPending = true;
        (bool ok, bytes memory failure) = address(dutch).call(retry);
        reentryRejected = !ok
            && keccak256(failure)
                == keccak256(abi.encodeWithSignature("ReentrancyGuardReentrantCall()"));
        require(reentryRejected, "exact host reentrancy guard rejects before payer checks");
        require(!fail, "Dutch delivery rejected");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Actual current Core/Manager/Ledger/native Recorder/Floor with typed Artist, entropy,
/// and target-side governance boundaries. This is not the complete current Artist/Executor graph.
abstract contract NativeDutchSalesTestSupport is NativeDutchSalesFixture {
    function _assertFreeReceipt(
        S.Purchase memory p,
        N.NativeSettlementCandidate memory c,
        S.Receipt memory r,
        bytes32 auth,
        bytes32 digest
    ) internal view {
        require(
            r.saleId == p.saleId && r.executionId == c.executionBinding.executionId
                && r.authorizationId == auth && r.saleAuthorizationDigest == digest
                && r.tokenId != 0 && r.operationRoot == c.operationIdentityCommitment
                && r.operationId == c.operationId,
            "exact free mint receipt"
        );
        require(
            r.chargedAmount == 0 && r.settlementKey == 0
                && dutch.executionStatus(r.executionId) == 2
                && keccak256(abi.encode(dutch.executionReceipt(r.executionId)))
                    == keccak256(abi.encode(r)),
            "free final receipt retained"
        );
        require(
            core.ownerOf(r.tokenId) == p.initialRecipient && manager.isAuthorizationUsed(auth)
                && manager.isOperationRootUsed(r.operationRoot),
            "actual Core identity and Ledger replay"
        );
        bytes32 key = recorder.settlementKey(address(dutch), r.executionId);
        require(
            !recorder.settlementConsumed(key)
                && recorder.settlementResult(key).candidateCommitment == 0
                && dutchFloor.settlementReceipt(key).receiptHash == 0
                && dutchFloor.directPrimarySaleFloorReceipt(key).receiptHash == 0,
            "no official or DIRECT record for this free Dutch mint"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 0
                && dutchFloor.firstSale(1).receiptHash == 0 && wallet.balance == 0
                && address(escrow).balance == 0,
            "free mint cannot establish revenue or conservation floor"
        );
        require(
            dutch.activePublicNativeCandidate(r.executionId) == 0,
            "no lingering paid public witness"
        );
    }

    function _freeEvents(Vm.Log[] memory logs, S.Receipt memory r) internal view {
        uint256 seen;
        bytes32 eventId = keccak256("FreeDutchExecuted(bytes32,bytes32,uint256,bytes32)");
        for (uint256 i; i < logs.length; ++i) {
            require(
                logs[i].emitter != address(recorder) && logs[i].emitter != address(dutchFloor),
                "no paid recorder or conservation events on zero path"
            );
            if (logs[i].emitter == address(dutch) && logs[i].topics[0] == eventId) {
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
        require(seen == 1, "one explicit free Dutch event");
    }

    function _merklePhase(address account, uint256 price, bool hasOverride)
        internal
        returns (bytes32 phase, bytes32 counter, bytes memory data)
    {
        phase = keccak256(abi.encode("Dutch price phase", price, hasOverride));
        counter = keccak256("dutch beneficiary allowlist");
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
                        hasOverride,
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
        manager.setPhaseExecutor(1, phase, address(dutch), true);
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        proofs[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        proofs[0][0] =
            IStreamMintCounterPolicy.AllowlistProof(3, hasOverride, price, new bytes32[](0));
        data = abi.encode(proofs);
    }

    function _assertPaidReceipt(
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
            keccak256(abi.encode(dutch.executionReceipt(r.executionId)))
                == keccak256(abi.encode(r)),
            "full retained adapter receipt"
        );
        require(
            manager.isAuthorizationUsed(auth) && manager.isOperationRootUsed(r.operationRoot)
                && core.ownerOf(r.tokenId) == p.initialRecipient
                && dutch.executionStatus(r.executionId) == 2,
            "actual Core owner, completed execution and Ledger replay consumption"
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
            dutchFloor.settlementReceipt(r.settlementKey);
        require(
            floor.receiptHash != 0 && floor.recorder == address(recorder)
                && floor.settlementKey == r.settlementKey
                && floor.candidateCommitment == result.candidateCommitment
                && floor.resultHash == keccak256(abi.encode(result))
                && floor.effectiveTier == WAIVED && floor.releaseReceiptHash == 0,
            "actual permanent WAIVED floor receipt"
        );
        StreamConservationFloorTypes.FirstSaleReceipt memory first = dutchFloor.firstSale(1);
        StreamConservationFloorTypes.CollectionFacts memory emptyFacts;
        bytes32 initialHead = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1"),
                block.chainid,
                address(core),
                address(dutchFloor)
            )
        );
        require(
            first.receiptHash == floor.firstSaleReceiptHash && first.sourceSetHash == initialHead
                && initialHead == dutchFloor.sourceSetHashAt(0) && first.sourceId == 0
                && keccak256(abi.encode(first.facts)) == keccak256(abi.encode(emptyFacts)),
            "waiver retains original source head without documentary facts"
        );
        require(
            dutchFloor.directPrimarySaleFloorReceipt(r.settlementKey).receiptHash == 0,
            "one official payment never creates DIRECT history"
        );
    }

    function _state(S.Purchase memory p, N.NativeSettlementCandidate memory c, bytes32 auth)
        internal
        view
        returns (bytes32)
    {
        bytes32 key = recorder.settlementKey(address(dutch), c.executionBinding.executionId);
        bytes32 balances = keccak256(
            abi.encode(
                p.payer.balance,
                wallet.balance,
                address(escrow).balance,
                address(dutch).balance,
                recorder.totalOfficialSettled(address(0)),
                recorder.settlementConsumed(key)
            )
        );
        bytes32 receipts = keccak256(
            abi.encode(
                dutchFloor.settlementReceipt(key),
                dutchFloor.firstSale(1),
                dutch.executionReceipt(c.executionBinding.executionId)
            )
        );
        bytes32 counters = keccak256(
            abi.encode(
                dutch.nextExecutionNonce(p.saleId, p.payer),
                dutch.saleRecord(p.saleId).sale.soldQuantity,
                dutch.refundLiability(),
                dutchEntropy.mintCalls(),
                dutchEntropy.revealFeeEscrow(1),
                manager.nextOperationNonce(),
                manager.isAuthorizationUsed(auth),
                manager.isOperationRootUsed(c.operationIdentityCommitment),
                core.collectionMintedEver(1),
                _payerCount(p.payer)
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
            address(dutch),
            address(0),
            0
        );
        return ledger.counterValue(manager.previewCounterValueKey(1, PHASE, COUNTER, subject));
    }

    function _rejectConfiguration(D.Configuration memory c) internal {
        vm.prank(address(revenueAuthority));
        (bool ok,) = address(dutch).call(abi.encodeCall(dutch.registerSale, (c)));
        require(!ok, "unsupported configuration rejects");
    }

    function _rejectSigned(
        S.Purchase memory p,
        A.SaleAuthorization memory a,
        IStreamPrivateSaleAdapter.Signature memory proof,
        uint256 value
    ) internal {
        vm.prank(p.payer);
        (bool ok,) = address(dutch).call{ value: value }(
            abi.encodeCall(dutch.purchaseSigned, (p, a, proof))
        );
        require(!ok, "signed purchase must reject");
    }

    function _rejectPublic(S.Purchase memory p, uint256 value) internal {
        vm.prank(p.payer);
        (bool ok,) = address(dutch).call{ value: value }(abi.encodeCall(dutch.purchasePublic, (p)));
        require(!ok, "public purchase must reject");
    }
}

contract StreamNativeDutchSalesTest is NativeDutchSalesTestSupport {
    function testDutchConfigurationPinsScheduleIdentityAndOriginalBindingTuples() public {
        D.Configuration memory c = _configuration(2, false, address(0), 0);
        bytes32 configHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_DUTCH_SALES_CONFIG_V1"),
                block.chainid,
                address(dutch),
                c
            )
        );
        require(dutch.saleConfigurationHash(c) == configHash, "literal configuration");
        bytes32 expectedId = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_DUTCH_SALES_ID_V1"),
                block.chainid,
                address(dutch),
                uint256(1),
                PHASE,
                uint256(1)
            )
        );
        require(dutch.saleIdFor(1, PHASE, 1) == expectedId, "literal family identity");
        bytes32 id = _registerDutch(c);
        D.Record memory r = dutch.saleRecord(id);
        bytes32 priceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_DUTCH_SCHEDULE_V1"),
                block.chainid,
                address(dutch),
                id,
                c.schedule.startPrice,
                c.schedule.restingPrice,
                c.schedule.startTime,
                c.schedule.endTime,
                c.schedule.decayKind,
                c.schedule.stepSeconds,
                c.schedule.stepAmount
            )
        );
        require(
            id == expectedId && r.sale.configHash == configHash && r.priceScheduleHash == priceHash
                && keccak256(abi.encode(r.schedule)) == keccak256(abi.encode(c.schedule))
                && !r.declaredFree,
            "full immutable Dutch record"
        );
        (bool ok, bytes memory data) = address(dutch)
            .staticcall(
                abi.encodeCall(
                    IStreamImmediateSaleAuthorizationBinding.immediateSaleAuthorizationBinding, (id)
                )
            );
        require(ok && data.length == 224, "exact historical binding");
        (ok, data) = address(dutch)
            .staticcall(
                abi.encodeCall(IStreamNativePublicSaleBinding.publicNativeSaleBinding, (id))
            );
        require(ok && data.length == 128, "exact public binding");
        (ok, data) = address(dutch).staticcall(abi.encodeCall(D.saleRecord, (id)));
        require(
            ok && data.length == 1152 && keccak256(data) == keccak256(abi.encode(r)),
            "populated record exact fixed ABI framing"
        );
        D.Record memory decoded = abi.decode(data, (D.Record));
        require(
            keccak256(abi.encode(decoded.sale.config)) == keccak256(abi.encode(c.sale))
                && decoded.sale.saleNonce == 1 && decoded.sale.soldQuantity == 0
                && !decoded.sale.closed && decoded.priceScheduleHash == priceHash
                && !decoded.declaredFree,
            "decoded record matches independently configured original fields"
        );
        (ok, data) =
            address(dutch).staticcall(abi.encodeCall(D.saleRecord, (bytes32(uint256(999)))));
        D.Record memory absent;
        require(
            ok && data.length == 1152 && keccak256(data) == keccak256(abi.encode(absent)),
            "absent record preserves complete allzero fixed tuple"
        );
        c.schedule.restingPrice = 101;
        require(dutch.saleConfigurationHash(c) != configHash, "curve fields are committed");
        require(dutch.schedulePrice(id) == 1000, "raw schedule read before admission");
        S.Purchase memory request = _purchase(id, payer, 1);
        _rejectPublic(request, 1000);
        _start(id);
        vm.prank(payer);
        dutch.purchasePublic{ value: 1000 }(request);
    }

    function testRegistrationRejectsLateStartOpenSupplyAndNonStrictScheduleMismatch() public {
        D.Configuration memory c = _configuration(2, false, address(0), 0);
        c.sale.saleSupplyLimit = 0;
        _rejectConfiguration(c);
        c.sale.saleSupplyLimit = 8;
        c.sale.saleKind = 0;
        _rejectConfiguration(c);
        c.sale.saleKind = 3;
        c.sale.primaryPolicyMode = 1;
        _rejectConfiguration(c);
        c.sale.primaryPolicyMode = 0;
        c.sale.unitPrice = 999;
        _rejectConfiguration(c);
        c.sale.unitPrice = 1000;
        ++c.sale.startsAt;
        _rejectConfiguration(c);
        --c.sale.startsAt;
        c.sale.endsAt = c.schedule.endTime - 1;
        _rejectConfiguration(c);
        c.sale.endsAt = c.schedule.endTime;
        c.schedule.restingPrice = 0;
        _rejectConfiguration(c);
        c.schedule.restingPrice = 100;
        vm.warp(c.sale.startsAt);
        _rejectConfiguration(c);
        require(dutch.nextSaleNonce() == 1, "every invalid declaration is atomic");
    }

    function testRawLinearAndSteppedPricesUseOriginalRoundingAndClamp() public {
        D.Configuration memory c = _configuration(2, false, address(0), 0);
        c.schedule.restingPrice = 101;
        bytes32 linear = _registerDutch(c);
        c.schedule.decayKind = 1;
        c.schedule.stepSeconds = 30;
        c.schedule.stepAmount = 400;
        bytes32 stepped = _registerDutch(c);
        vm.warp(c.schedule.startTime + 1);
        require(
            dutch.schedulePrice(linear) == 992 && dutch.schedulePrice(stepped) == 1000,
            "linear charge rounds up; incomplete step does not decay"
        );
        vm.warp(c.schedule.startTime + 30);
        require(
            dutch.schedulePrice(linear) == 731 && dutch.schedulePrice(stepped) == 600,
            "exact elapsed-time and completed-step pricing"
        );
        vm.warp(c.schedule.startTime + 90);
        require(dutch.schedulePrice(stepped) == 101, "stepped reduction clamps without underflow");
        vm.warp(c.schedule.endTime);
        require(
            dutch.schedulePrice(linear) == 101 && dutch.schedulePrice(stepped) == 101,
            "both curves reach declared resting price at end"
        );
    }

    function testPublicDutchDisabledRevealCreditsWholeSurplusAndRetainsOfficialFloor() public {
        bytes32 id = _registerDutch(_configuration(2, false, address(0), 0));
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 2);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = dutch.previewPublicPurchase(p);
        uint256 before_ = payer.balance;
        vm.prank(payer);
        S.Receipt memory r = dutch.purchasePublic{ value: 1500 }(p);
        _assertPaidReceipt(p, c, r, auth, 0);
        require(
            r.chargedAmount == 1000 && r.revealFee == 0 && r.revealCredit == 500
                && payer.balance == before_ - 1500 && dutch.refundableBalance(id, payer) == 500
                && dutch.refundLiability() == 500 && address(dutch).balance == 500,
            "undeclared reveal surplus is pull credit, not official revenue"
        );
        vm.prank(payer);
        dutch.claimRefund(id, payer);
        require(
            payer.balance == before_ - 1000 && dutch.refundLiability() == 0,
            "buyer maximum is reduced to actual curve charge"
        );
    }

    function testSignedDutchLiteral24FieldAuthorizationSurvivesFundingFailureAndCannotReplay()
        public
    {
        bytes32 id = _registerDutch(_configuration(1, false, vm.addr(SIGNER_KEY), 1));
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 3);
        A.SaleAuthorization memory a = _authorization(p, 301);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        bytes32 digest = _literalDigest(a);
        require(
            abi.encode(a).length == 768 && dutch.authorizationDigest(a) == digest,
            "original literal24-field Sales v1 digest"
        );
        N.NativeSettlementCandidate memory c = dutch.previewSignedPurchase(p, a, proof);
        bytes32 before_ = _state(p, c, _id(digest));
        proof.authorizer = address(0xDEAD);
        vm.expectRevert(
            abi.encodeWithSelector(
                S.ImmediateSaleSignerUnavailable.selector, address(0xDEAD), uint8(1)
            )
        );
        vm.prank(payer);
        dutch.purchaseSigned{ value: 1000 }(p, a, proof);
        proof.authorizer = vm.addr(SIGNER_KEY);
        bytes memory signature = proof.signature;
        proof.signature = hex"01";
        vm.expectRevert(
            abi.encodeWithSelector(S.ImmediateSaleSignatureInvalid.selector, proof.authorizer)
        );
        vm.prank(payer);
        dutch.purchaseSigned{ value: 1000 }(p, a, proof);
        proof.signature = signature;
        require(
            _state(p, c, _id(digest)) == before_,
            "claimed account and bad signature leave original request unused"
        );
        vm.expectRevert(
            abi.encodeWithSelector(D.DutchPaymentBelowPrice.selector, uint256(999), uint256(1000))
        );
        vm.prank(payer);
        dutch.purchaseSigned{ value: 999 }(p, a, proof);
        require(_state(p, c, _id(digest)) == before_, "funding failure rolls every stage back");
        vm.prank(payer);
        S.Receipt memory r = dutch.purchaseSigned{ value: 1300 }(p, a, proof);
        _assertPaidReceipt(p, c, r, _id(digest), digest);
        p.executionNonce = dutch.nextExecutionNonce(id, payer);
        _rejectSigned(p, a, proof, 1300);
        require(
            manager.nextOperationNonce() == 1 && core.collectionMintedEver(1) == 1,
            "fresh execution nonce cannot replay original signed authority"
        );
    }

    function testSignedMaximumWithoutOverrideRejectsThenSameSignatureSucceedsAfterDecay() public {
        bytes32 id = _registerDutch(_configuration(1, false, vm.addr(SIGNER_KEY), 1));
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 4);
        A.SaleAuthorization memory a = _authorization(p, 302);
        a.unitPrice = 550;
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        vm.expectRevert(
            abi.encodeWithSelector(
                D.DutchSignedMaximumBelowPrice.selector, uint256(550), uint256(1000)
            )
        );
        vm.prank(payer);
        dutch.purchaseSigned{ value: 1000 }(p, a, proof);
        vm.warp(dutch.saleRecord(id).schedule.startTime + 50);
        N.NativeSettlementCandidate memory c = dutch.previewSignedPurchase(p, a, proof);
        vm.prank(payer);
        S.Receipt memory r = dutch.purchaseSigned{ value: 1000 }(p, a, proof);
        _assertPaidReceipt(p, c, r, _id(_literalDigest(a)), _literalDigest(a));
        require(
            r.chargedAmount == 550 && r.revealCredit == 450 && a.unitPrice == 550,
            "decay honors original signer ceiling without rewriting authorization"
        );
    }

    function testGenuineHigherLeafReplacesStaleSignedMaximumButBuyerMustFundCurvePrice() public {
        _overridePurchase(2000, 1000, 5);
    }

    function testGenuineLowerLeafReplacesStaleSignedMaximumAndClampsCurveCharge() public {
        _overridePurchase(700, 700, 6);
    }

    function _overridePurchase(uint256 proven, uint256 charged, uint256 tag) private {
        (bytes32 phase, bytes32 counter, bytes memory data) =
            _merklePhase(address(0xCAFE), proven, true);
        D.Configuration memory config = _configuration(1, false, vm.addr(SIGNER_KEY), 1);
        config.sale.phaseId = phase;
        config.sale.mintPolicyHash = manager.phasePolicyHash(1, phase);
        config.sale.priceCounterId = counter;
        bytes32 id = _registerDutch(config);
        _start(id);
        S.Purchase memory p = _purchase(id, payer, tag);
        p.resolverData = data;
        A.SaleAuthorization memory a = _authorization(p, 300 + tag);
        a.unitPrice = 1;
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        N.NativeSettlementCandidate memory c = dutch.previewSignedPurchase(p, a, proof);
        require(
            c.sale.amount == charged && a.unitPrice == 1,
            "proven leaf replaces original signed ceiling"
        );
        bytes32 before_ = _state(p, c, _id(_literalDigest(a)));
        vm.expectRevert(
            abi.encodeWithSelector(D.DutchPaymentBelowPrice.selector, charged - 1, charged)
        );
        vm.prank(payer);
        dutch.purchaseSigned{ value: charged - 1 }(p, a, proof);
        require(_state(p, c, _id(_literalDigest(a))) == before_, "leaf funding failure is atomic");
        vm.prank(payer);
        S.Receipt memory r = dutch.purchaseSigned{ value: charged }(p, a, proof);
        _assertPaidReceipt(p, c, r, _id(_literalDigest(a)), _literalDigest(a));
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            phase,
            counter,
            payer,
            p.beneficiary,
            address(dutch),
            address(0),
            0
        );
        require(
            ledger.counterValue(manager.previewCounterValueKey(1, phase, counter, subject)) == 1,
            "same authenticated beneficiary leaf consumes real Ledger cap"
        );
    }

    function testMembershipOnlyLeafCannotReplaceSignedMaximumOrSpoofBeneficiary() public {
        (bytes32 phase, bytes32 counter, bytes memory data) =
            _merklePhase(address(0xCAFE), 0, false);
        D.Configuration memory config = _configuration(1, false, vm.addr(SIGNER_KEY), 1);
        config.sale.phaseId = phase;
        config.sale.mintPolicyHash = manager.phasePolicyHash(1, phase);
        _rejectConfiguration(config);
        config.sale.priceCounterId = counter;
        bytes32 id = _registerDutch(config);
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 7);
        p.resolverData = data;
        A.SaleAuthorization memory a = _authorization(p, 307);
        a.unitPrice = 1;
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        vm.expectRevert(
            abi.encodeWithSelector(
                D.DutchSignedMaximumBelowPrice.selector, uint256(1), uint256(1000)
            )
        );
        vm.prank(payer);
        dutch.purchaseSigned{ value: 1000 }(p, a, proof);
        a.unitPrice = 1000;
        proof = _sign(a);
        p.beneficiary = address(0xBEEF);
        _rejectSigned(p, a, proof, 1000);
        p.beneficiary = address(0xCAFE);
        vm.prank(payer);
        dutch.purchaseSigned{ value: 1000 }(p, a, proof);
    }

    function testZeroLeafNeedsExplicitFreeDeclarationAndPreservesFreeMintCounter() public {
        (bytes32 phase, bytes32 counter, bytes memory data) = _merklePhase(address(0xCAFE), 0, true);
        D.Configuration memory config = _configuration(2, false, address(0), 0);
        config.sale.phaseId = phase;
        config.sale.mintPolicyHash = manager.phasePolicyHash(1, phase);
        config.sale.priceCounterId = counter;
        bytes32 paidOnly = _registerDutch(config);
        config.declaredFree = true;
        bytes32 free = _registerDutch(config);
        _start(free);
        S.Purchase memory p = _purchase(paidOnly, payer, 8);
        p.resolverData = data;
        vm.expectRevert(
            abi.encodeWithSelector(D.SalePriceOverrideZeroUndeclared.selector, paidOnly)
        );
        vm.prank(payer);
        dutch.purchasePublic(p);
        p.saleId = free;
        (N.NativeSettlementCandidate memory c, bytes32 auth) = dutch.previewPublicPurchase(p);
        vm.prank(payer);
        S.Receipt memory r = dutch.purchasePublic{ value: 800 }(p);
        _assertFreeReceipt(p, c, r, auth, 0);
        require(
            r.revealCredit == 800 && dutch.refundableBalance(free, payer) == 800,
            "all funding is buyer credit on declared zero override"
        );
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            phase,
            counter,
            payer,
            p.beneficiary,
            address(dutch),
            address(0),
            0
        );
        require(
            ledger.counterValue(manager.previewCounterValueKey(1, phase, counter, subject)) == 1,
            "zero does not bypass actual Merkle counter"
        );
    }

    function testDeclaredFreeRestingPriceMintsWithPendingReceiptAndNoOfficialEvents() public {
        bytes32 id = _registerDutch(_configuration(2, true, address(0), 0));
        vm.warp(dutch.saleRecord(id).schedule.endTime);
        S.Purchase memory p = _purchase(id, payer, 9);
        DutchDeliveryObserver receiver = new DutchDeliveryObserver(
            D(address(dutch)), address(core), IStreamMintManager(address(manager))
        );
        p.initialRecipient = address(receiver);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = dutch.previewPublicPurchase(p);
        receiver.configure(
            c.executionBinding.executionId, auth, false, abi.encodeCall(dutch.purchasePublic, (p))
        );
        vm.recordLogs();
        vm.prank(payer);
        S.Receipt memory r = dutch.purchasePublic{ value: 123 }(p);
        _freeEvents(vm.getRecordedLogs(), r);
        _assertFreeReceipt(p, c, r, auth, 0);
        require(
            receiver.sawPending() && receiver.reentryRejected() && r.revealCredit == 123
                && dutch.refundLiability() == 123,
            "real free callback and complete surplus credit"
        );
    }

    function testPausesTollAdmissionButNeverShiftCommittedRawTimeCurve() public {
        D.Configuration memory config = _configuration(2, false, address(0), 0);
        config.sale.endsAt = config.schedule.endTime;
        bytes32 id = _registerDutch(config);
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 10);
        vm.prank(address(0xA11));
        dutch.setSalePause(id, true, keccak256("temporary incident"));
        vm.warp(config.schedule.startTime + 20);
        _rejectPublic(p, 1000);
        require(dutch.schedulePrice(id) == 820, "paused raw clock continues to decay");
        vm.prank(address(0xB22));
        dutch.setSalePause(id, false, keccak256("incident cleared"));
        vm.warp(config.schedule.endTime + 10);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = dutch.previewPublicPurchase(p);
        vm.prank(payer);
        S.Receipt memory r = dutch.purchasePublic{ value: 500 }(p);
        _assertPaidReceipt(p, c, r, auth, 0);
        require(
            r.chargedAmount == 100 && r.revealCredit == 400,
            "toll extends close while raw price remains resting"
        );
        vm.warp(config.schedule.endTime + 20);
        p = _purchase(id, payer, 11);
        _rejectPublic(p, 100);
    }

    function testLiteralCallerSupplyAndArtistConsentRemainIndependentMintChecks() public {
        D.Configuration memory config = _configuration(2, false, address(0), 0);
        config.sale.saleSupplyLimit = 1;
        bytes32 id = _registerDutch(config);
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 12);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = dutch.previewPublicPurchase(p);
        bytes32 before_ = _state(p, c, auth);
        (bool ok,) = address(dutch).call{ value: 1000 }(abi.encodeCall(dutch.purchasePublic, (p)));
        require(!ok, "outsider cannot submit a named payer purchase");
        p.executor = address(this);
        _rejectPublic(p, 1000);
        p.executor = payer;
        artists.setConsent(false);
        _rejectPublic(p, 1000);
        artists.setConsent(true);
        require(_state(p, c, auth) == before_, "caller and Artist denials make no progress");
        vm.prank(payer);
        S.Receipt memory r = dutch.purchasePublic{ value: 1000 }(p);
        _assertPaidReceipt(p, c, r, auth, 0);
        p = _purchase(id, payer, 13);
        _rejectPublic(p, 1000);
        require(
            dutch.saleRecord(id).sale.closed && _payerCount(payer) == 1
                && _payerCount(p.beneficiary) == 0,
            "finite supply and original literal PAYER counter"
        );
    }

    function testUnsyncedActualContestBlocksRegistrationAndGlobalPauseBlocksPurchase() public {
        D.Configuration memory config = _configuration(2, false, address(0), 0);
        ImmediateSalesArtistBoundary(address(artists)).setContest(1, false);
        _rejectConfiguration(config);
        ImmediateSalesArtistBoundary(address(artists)).setContest(3, false);
        _rejectConfiguration(config);
        ImmediateSalesArtistBoundary(address(artists)).setContest(0, true);
        _rejectConfiguration(config);
        ImmediateSalesArtistBoundary(address(artists)).setContest(0, false);
        bytes32 id = _registerDutch(config);
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 14);
        vm.prank(address(0xA11));
        dutch.setGlobalPause(true, keccak256("global incident"));
        _rejectPublic(p, 1000);
        vm.prank(address(0xB22));
        dutch.setGlobalPause(false, keccak256("global cleared"));
        vm.prank(payer);
        dutch.purchasePublic{ value: 1000 }(p);
    }

    function testLiveFeeNetMaximumErrorsAndIdenticalSignedRetryPreserveSeparateCredit() public {
        dutchEntropy.configure(false, 12);
        bytes32 id = _registerDutch(_configuration(1, false, vm.addr(SIGNER_KEY), 1));
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 15);
        A.SaleAuthorization memory a = _authorization(p, 315);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        N.NativeSettlementCandidate memory c = dutch.previewSignedPurchase(p, a, proof);
        bytes32 before_ = _state(p, c, _id(_literalDigest(a)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamImmediateSaleReveal.SaleRevealFeeBelowRequired.selector,
                uint256(11),
                uint256(12)
            )
        );
        vm.prank(payer);
        dutch.purchaseSigned{ value: 11 }(p, a, proof);
        vm.expectRevert(
            abi.encodeWithSelector(D.DutchPaymentBelowPrice.selector, uint256(999), uint256(1000))
        );
        vm.prank(payer);
        dutch.purchaseSigned{ value: 1011 }(p, a, proof);
        require(
            _state(p, c, _id(_literalDigest(a))) == before_,
            "fee and net maximum failures preserve exact request"
        );
        dutchEntropy.configure(false, 7);
        vm.prank(payer);
        S.Receipt memory r = dutch.purchaseSigned{ value: 1020 }(p, a, proof);
        _assertPaidReceipt(p, c, r, _id(_literalDigest(a)), _literalDigest(a));
        require(
            r.revealFee == 7 && r.revealCredit == 13 && dutchEntropy.revealFeeEscrow(1) == 7
                && dutch.refundLiability() == 13
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "captured live fee and funded maximum remain separate from revenue"
        );
    }

    function testCapturedRevealFeeSurvivesReceiverFeeChangeAndEarlierUnpaidCredit() public {
        dutchEntropy.configure(false, 0);
        bytes32 id = _registerDutch(_configuration(2, false, address(0), 0));
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 16);
        vm.prank(payer);
        dutch.purchasePublic{ value: 1500 }(p);
        require(dutch.refundableBalance(id, payer) == 500, "first zero-fee allowance retained");
        dutchEntropy.configure(false, 12);
        NativeAuctionReceiver receiver = new NativeAuctionReceiver();
        receiver.configure(
            false,
            false,
            address(dutchEntropy),
            abi.encodeCall(dutchEntropy.configure, (false, uint256(99))),
            address(0)
        );
        p = _purchase(id, payer, 17);
        p.initialRecipient = address(receiver);
        vm.prank(payer);
        S.Receipt memory r = dutch.purchasePublic{ value: 1040 }(p);
        require(
            !receiver.callbackRejected() && dutchEntropy.fee() == 99 && r.revealFee == 12
                && r.revealCredit == 28 && dutchEntropy.revealFeeEscrow(1) == 12
                && dutch.refundableBalance(id, payer) == 528 && address(dutch).balance == 528,
            "callback cannot reprice captured fee or spend earlier refunds"
        );
    }

    function testOfficialSafe1271SignerAndPublicSafePayerUseOriginalAccounts() public {
        (OfficialSafe account, uint256[] memory keys) = _safe(930);
        bytes32 id = _registerDutch(_configuration(1, false, address(account), 2));
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 18);
        A.SaleAuthorization memory a = _authorization(p, 318);
        IStreamPrivateSaleAdapter.Signature memory proof = IStreamPrivateSaleAdapter.Signature(
            address(account),
            2,
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(_literalDigest(a))))
        );
        N.NativeSettlementCandidate memory c = dutch.previewSignedPurchase(p, a, proof);
        vm.prank(payer);
        S.Receipt memory signed = dutch.purchaseSigned{ value: 1000 }(p, a, proof);
        _assertPaidReceipt(p, c, signed, _id(_literalDigest(a)), _literalDigest(a));
        id = _registerDutch(_configuration(2, false, address(0), 0));
        _start(id);
        p = _purchase(id, address(account), 19);
        bytes32 auth;
        (c, auth) = dutch.previewPublicPurchase(p);
        require(
            executeSafe(
                account, keys, address(dutch), 1200, abi.encodeCall(dutch.purchasePublic, (p)), 0
            ),
            "upstream Safe makes literal payer/executor CALL"
        );
        S.Receipt memory publicReceipt = dutch.executionReceipt(c.executionBinding.executionId);
        _assertPaidReceipt(p, c, publicReceipt, auth, 0);
        require(
            dutch.refundableBalance(id, address(account)) == 200
                && _payerCount(address(account)) == 1,
            "credits and mint counter belong to actual Safe"
        );
    }

    function testSafeLateReceiverFailurePreservesPriorCreditAndExactEnvelopeRetry() public {
        (OfficialSafe buyer, uint256[] memory keys) = _safe(931);
        bytes32 id = _registerDutch(_configuration(2, false, address(0), 0));
        _start(id);
        S.Purchase memory first = _purchase(id, address(buyer), 20);
        require(
            executeSafe(
                buyer, keys, address(dutch), 1250, abi.encodeCall(dutch.purchasePublic, (first)), 0
            ),
            "first Safe purchase"
        );
        NativeAuctionReceiver receiver = new NativeAuctionReceiver();
        receiver.configure(true, false, address(0), "", address(0));
        S.Purchase memory p = _purchase(id, address(buyer), 21);
        p.initialRecipient = address(receiver);
        (N.NativeSettlementCandidate memory c, bytes32 auth) = dutch.previewPublicPurchase(p);
        bytes memory data = abi.encodeCall(dutch.purchasePublic, (p));
        uint256 nonce = buyer.nonce();
        bytes memory sig = safeThresholdSignature(
            keys,
            buyer.getTransactionHash(
                address(dutch), 1300, data, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        bytes32 before_ = _state(p, c, auth);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        buyer.execTransaction(
            address(dutch), 1300, data, 0, 0, 0, 0, address(0), payable(address(0)), sig
        );
        require(
            buyer.nonce() == nonce && _state(p, c, auth) == before_
                && dutch.refundableBalance(id, address(buyer)) == 250
                && dutch.activePublicNativeCandidate(c.executionBinding.executionId) == 0,
            "failed late callback restores original credit, official record, nonce and replay"
        );
        receiver.configure(false, false, address(0), "", address(0));
        require(
            buyer.execTransaction(
                address(dutch), 1300, data, 0, 0, 0, 0, address(0), payable(address(0)), sig
            ),
            "byte-identical threshold Safe retry"
        );
        _assertPaidReceipt(p, c, dutch.executionReceipt(c.executionBinding.executionId), auth, 0);
        require(
            dutch.refundableBalance(id, address(buyer)) == 550 && dutch.refundLiability() == 550,
            "retry adds only new surplus to previous unspent credit"
        );
    }

    function testHistoricalDutchSignerCanVoidAfterCloseWithoutLiveEconomics() public {
        bytes32 id = _registerDutch(_configuration(1, false, vm.addr(SIGNER_KEY), 1));
        S.Purchase memory p = _purchase(id, payer, 22);
        A.SaleAuthorization memory a = _authorization(p, 106);
        bytes32 auth = _id(_literalDigest(a));
        vm.prank(address(revenueAuthority));
        dutch.closeSale(id);
        vm.prank(address(revenueAuthority));
        dutch.configureCollectionSigner(
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
                address(dutch)
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
        _rejectSigned(p, a, _sign(a), 1000);
    }

    function testRefundHostileRecipientRollsBackCreditAndExactClaimRetries() public {
        bytes32 id = _registerDutch(_configuration(2, false, address(0), 0));
        _start(id);
        S.Purchase memory p = _purchase(id, payer, 23);
        vm.prank(payer);
        dutch.purchasePublic{ value: 1500 }(p);
        NativeAuctionReceiver receiver = new NativeAuctionReceiver();
        receiver.configure(false, true, address(0), "", address(0));
        (bool ok,) = address(dutch).call(abi.encodeCall(dutch.claimRefund, (id, address(receiver))));
        require(
            !ok && dutch.refundableBalance(id, payer) == 500,
            "outsider cannot direct original payer credit"
        );
        vm.prank(payer);
        (ok,) = address(dutch).call(abi.encodeCall(dutch.claimRefund, (id, address(receiver))));
        require(
            !ok && dutch.refundableBalance(id, payer) == 500 && dutch.refundLiability() == 500
                && address(dutch).balance == 500,
            "failed recipient restores exact liability"
        );
        receiver.configure(false, false, address(0), "", address(0));
        vm.prank(payer);
        dutch.claimRefund(id, address(receiver));
        require(
            address(receiver).balance == 500 && dutch.refundableBalance(id, payer) == 0
                && dutch.refundLiability() == 0,
            "exact original claim succeeds after recipient repair"
        );
    }
}

/// @dev The actual permanent Floor starts without a tier/source. Repair is a genuine pre-mint
/// Metadata declaration; production mint/settlement/recording are never replaced with test doubles.
contract StreamNativeDutchSalesLateFloorTest is NativeDutchSalesTestSupport {
    function _declareWaiverAtSetup() internal pure override returns (bool) {
        return false;
    }

    function testLateActualFloorFailureRollsBackAndIdenticalSignedSafeTransactionRetries() public {
        (OfficialSafe buyer, uint256[] memory keys) = _safe(940);
        bytes32 id = _registerDutch(_configuration(1, false, vm.addr(SIGNER_KEY), 1));
        _start(id);
        S.Purchase memory p = _purchase(id, address(buyer), 40);
        A.SaleAuthorization memory a = _authorization(p, 340);
        IStreamPrivateSaleAdapter.Signature memory proof = _sign(a);
        N.NativeSettlementCandidate memory c = dutch.previewSignedPurchase(p, a, proof);
        bytes32 digest = _literalDigest(a);
        bytes memory data = abi.encodeCall(dutch.purchaseSigned, (p, a, proof));
        uint256 nonce = buyer.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            buyer.getTransactionHash(
                address(dutch), 1500, data, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        bytes32 before_ = _state(p, c, _id(digest));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        buyer.execTransaction(
            address(dutch), 1500, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(
            _state(p, c, _id(digest)) == before_ && buyer.nonce() == nonce
                && core.collectionMintedEver(1) == 0 && dutch.saleRecord(id).sale.soldQuantity == 0
                && dutch.activePublicNativeCandidate(c.executionBinding.executionId) == 0,
            "actual Floor refusal restores all sale, funding, escrow, mint and Safe state"
        );
        _declareWaiver();
        require(
            buyer.execTransaction(
                address(dutch), 1500, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            ),
            "exact original sale and Safe signatures retry after actual Metadata declaration"
        );
        S.Receipt memory r = dutch.executionReceipt(c.executionBinding.executionId);
        _assertPaidReceipt(p, c, r, _id(digest), digest);
        require(
            dutch.refundableBalance(id, address(buyer)) == 500,
            "only funded surplus is buyer credit"
        );
    }
}
