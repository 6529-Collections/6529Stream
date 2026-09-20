// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/CurrentERC20ConservationFixture.sol";
import "../mocks/MockStreamPaymentToken.sol";
import "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import "../../smart-contracts/domains/mint/StreamUniversalFixedPriceSaleAdapter.sol";

interface RecordingFaultVM {
    function expectCall(address, uint256, bytes calldata) external;
    function expectCall(address, uint256, bytes calldata, uint64) external;
    function mockCallRevert(address, uint256, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

/// @notice Actual current Core/Manager/Recorder regression for the extracted ERC20 worker.
/// @dev Token and the inherited Artist/entropy/governance boundaries remain explicit fixtures.
contract StreamCurrentERC20RecordingTest is CurrentERC20ConservationFixture {
    bytes32 private constant ERC_PHASE = keccak256("current extracted ERC20 phase");
    StreamERC20PrimarySettlementAdapter private payment;
    StreamUniversalFixedPriceSaleAdapter private sale;
    MockStreamPaymentToken private token;
    bytes32 private saleId;
    RecordingFaultVM private constant faults =
        RecordingFaultVM(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setUp() public override {
        super.setUp();
        _enableCurrentERC20Floor();
        entropy.configure(0, 1, false, false); // Explicit zero-fee regression policy.
        token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("actual current exact ERC20"), 0);
        payment = new StreamERC20PrimarySettlementAdapter(recorder, address(0), 0);
        sale = new StreamUniversalFixedPriceSaleAdapter(
            manager, recorder, vm.addr(AUCTION_PLATFORM_KEY), artists,
            IStreamGasParameterHost.GasParameterConfig("REVEAL_ATTEMPT_GAS_LIMIT", 1_000_000, 100_000, 2)
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
            keccak256("ERC20 counter")
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
                1000,
                0,
                100000,
                manager.phasePolicyHash(1, ERC_PHASE),
                StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1)
            )
        );
        token.mint(payer, 10000);
        vm.prank(payer);
        token.approve(address(payment), 10000);
        require(
            address(payment).code.length <= 24576 && address(sale).code.length <= 24576,
            "actual reached ERC20 products fit"
        );
    }

    function _proof(uint256 k, bytes32 d) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(k, d);
        return abi.encodePacked(r, s, v);
    }

    function _execution(uint256 n)
        private
        returns (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        )
    {
        e.tokenData = abi.encode("actual current ERC20", n);
        e.authorization = IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization(
            saleId,
            sale.saleRecord(saleId).configHash,
            payer,
            payer,
            payer,
            vm.addr(SIGNER_KEY),
            keccak256(e.tokenData),
            keccak256(abi.encode("mint", n)),
            n,
            bytes32(n),
            10000
        );
        bytes32 d = sale.authorizationDigest(e.authorization);
        e.platformSignature = _proof(AUCTION_PLATFORM_KEY, d);
        e.artistSignature = _proof(SIGNER_KEY, d);
        c = sale.previewExecution(e);
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

    function testActualCoreERC20RecorderPreservesContextSurplusAndConsecutiveOperations() public {
        token.mint(address(payment), 17);
        token.mint(address(recorder), 23);
        uint256 originalSaleNonce = sale.saleRecord(saleId).saleNonce;
        require(originalSaleNonce == 1, "one original registered sale");
        for (uint256 n = 1; n <= 2; ++n) {
            (
                IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
                StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
            ) = _execution(n);
            vm.recordLogs();
            vm.prank(payer);
            StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
                payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
            Vm.Log[] memory logs = vm.getRecordedLogs();
            bytes32 eventHash = keccak256(
                "PrimaryRevenueSettlementContext(bytes32,bytes32,bytes32,uint16,address,bytes32,uint8,uint256,uint256,bytes32,bytes32,uint256,address,address,bytes32)"
            );
            uint256 count;
            for (uint256 j; j < logs.length; ++j) {
                if (logs[j].emitter != address(recorder) || logs[j].topics[0] != eventHash) {
                    continue;
                }
                ++count;
                require(
                    logs[j].topics.length == 4 && logs[j].topics[1] == r.settlementKey
                        && logs[j].topics[2] == CLASS && logs[j].topics[3] == profile,
                    "original ERC20 indexed event"
                );
                require(
                    keccak256(logs[j].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                address(sale),
                                saleId,
                                uint8(0),
                                uint256(1),
                                uint256(0),
                                c.operationIdentityCommitment,
                                c.operationId,
                                originalSaleNonce,
                                address(0),
                                payer,
                                bytes32(0)
                            )
                        ),
                    "full original ERC20 context preimage"
                );
            }
            require(
                count == 1
                    && keccak256(abi.encode(recorder.settlementResult(r.settlementKey)))
                        == keccak256(abi.encode(r)),
                "one complete stored result and event"
            );
            require(
                core.ownerOf(n) == payer && core.collectionNextSerial(1) == n + 1
                    && manager.nextOperationNonce() == n && ledger.counterValue(_counter()) == n,
                "actual current mint and counters"
            );
            require(
                ledger.isManagerOperationRootUsed(address(manager), c.operationIdentityCommitment)
                    && r.operationIdentityCommitment == c.operationIdentityCommitment
                    && sale.executionStatus(c.executionBinding.executionId) == 2,
                "full original operation binding"
            );
            require(
                token.rawBalance(payer) == 10000 - 1000 * n && token.rawBalance(wallet) == 1000 * n
                    && recorder.totalOfficialSettled(address(token)) == 1000 * n
                    && recorder.officialSettled(CLASS, profile, wallet, address(token)) == 1000 * n,
                "whole current ERC20 accounting"
            );
            require(
                token.rawBalance(address(payment)) == 17
                    && token.rawBalance(address(recorder)) == 23 && !r.escrowed,
                "passive surplus and direct mode retained"
            );
        }
    }

    function testActualCoreLateMintFailureRollsBackERC20AndSameSignedCallRetriesWithReentryBlocked()
        public
    {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(1);
        bytes memory callData =
            abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, abi.encode(e)));
        token.configureCallback(address(payment), callData, 1);
        entropy.configure(0, 1, true, false);
        faults.expectCall(
            address(token), 0, abi.encodeCall(token.transfer, (wallet, uint256(1000)))
        );
        vm.prank(payer);
        (bool ok,) = address(payment).call(callData);
        require(
            !ok && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && manager.nextOperationNonce() == 0 && ledger.counterValue(_counter()) == 0,
            "late actual Core failure rolls back mint and ledger"
        );
        require(
            token.rawBalance(payer) == 10000 && token.rawBalance(wallet) == 0
                && token.rawBalance(address(payment)) == 0
                && token.rawBalance(address(recorder)) == 0
                && token.allowance(payer, address(payment)) == 10000,
            "all three payment legs and allowance rollback"
        );
        bytes32 key = recorder.settlementKey(address(sale), c.executionBinding.executionId);
        require(
            !recorder.settlementConsumed(key) && recorder.totalOfficialSettled(address(token)) == 0
                && sale.executionStatus(c.executionBinding.executionId) == 0
                && !ledger.isManagerOperationRootUsed(
                    address(manager), c.operationIdentityCommitment
                ),
            "original replay state remains unused"
        );
        entropy.configure(0, 1, false, false);
        bytes memory raw;
        vm.prank(payer);
        (ok, raw) = address(payment).call(callData);
        require(ok && raw.length == 384, "identical original signed bytes retry");
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            abi.decode(raw, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        require(
            result.settlementKey == key && core.ownerOf(1) == payer
                && token.rawBalance(wallet) == 1000
                && recorder.totalOfficialSettled(address(token)) == 1000
                && token.transferCalls() == 3 && !token.callbackSucceeded(),
            "one actual payment and hostile token reentry blocked"
        );
        vm.prank(payer);
        (ok,) = address(payment).call(callData);
        require(
            !ok && token.rawBalance(wallet) == 1000 && ledger.counterValue(_counter()) == 1,
            "successful original call cannot replay"
        );
    }
    function testActualCoreERC20RevealFailureKeepsMintRootAndTokenOnlyReceipt() public {
        entropy.configure(100, 0, false, true);
        vm.deal(payer, 125);
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
         StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) = _execution(1);
        vm.recordLogs();
        vm.prank(payer);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleByPayer{value: 125}(c, abi.encode(e));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(sale) || logs[i].topics[0] != keccak256(
                "ImmediateRevealAttempt(uint16,uint256,uint256,bool,bytes32,uint256,uint256,bytes)")) continue;
            ++count;
            (uint16 schema, bool success, bytes32 key, uint256 request,, bytes memory prefix) =
                abi.decode(logs[i].data, (uint16,bool,bytes32,uint256,uint256,bytes));
            require(schema == 1 && !success && key == 0 && request == 0 && prefix.length <= 256
                && logs[i].topics.length == 3 && logs[i].topics[1] == bytes32(uint256(1))
                && logs[i].topics[2] == bytes32(uint256(1)), "canonical bounded actual-token attempt");
        }
        require(count == 1 && core.ownerOf(1) == payer && core.lastAllocatedTokenId() == 1
            && manager.nextOperationNonce() == 1 && ledger.counterValue(_counter()) == 1
            && ledger.isManagerOperationRootUsed(address(manager), c.operationIdentityCommitment),
            "provider failure preserves actual Core/Manager/Ledger result");
        require(r.asset == address(token) && r.amount == 1000 && r.executor == payer
            && r.operationIdentityCommitment == c.operationIdentityCommitment
            && token.rawBalance(payer) == 9000 && token.rawBalance(wallet) == 1000
            && recorder.totalOfficialSettled(address(token)) == 1000, "original exact token receipt");
        require(entropy.revealFeeEscrow(1) == 100 && entropy.requestCalls() == 0
            && sale.refundableBalance(saleId, payer) == 25 && sale.refundLiability() == 25
            && address(payment).balance == 0 && address(sale).balance == 25, "separate native accounting");
    }

    function testActualCoreSafeExecutorIntentAndExactLateNativeFundingRetry() public {
        uint256[] memory keys = new uint256[](2); keys[0] = 0x1901; keys[1] = 0x1902;
        OfficialSafe executor = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 903);
        vm.deal(address(executor), 125);
        entropy.configure(100, 0, false, false);
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,) = _execution(1);
        e.authorization.executor = address(executor);
        bytes32 digest = sale.authorizationDigest(e.authorization);
        e.platformSignature = _proof(AUCTION_PLATFORM_KEY, digest);
        e.artistSignature = _proof(SIGNER_KEY, digest);
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c = sale.previewExecution(e);
        StreamPrimarySettlementTypes.PaymentIntent memory intent = StreamPrimarySettlementTypes.PaymentIntent(
            payer, address(token), 1000, saleId, c.sale.expectedPrimaryPolicyHash, keccak256("current native allowance"), 10000);
        bytes memory input = abi.encodeCall(payment.settleERC20PrimarySaleWithIntent,
            (c, intent, _proof(PAYER_KEY, payment.paymentIntentDigest(intent)), abi.encode(e)));
        bytes32 txHash = executor.getTransactionHash(address(payment), 125, input, 0, 0, 0, 0,
            address(0), address(0), executor.nonce());
        bytes memory exactSafeCall = abi.encodeCall(OfficialSafe.execTransaction,
            (address(payment), uint256(125), input, uint8(0), uint256(0), uint256(0), uint256(0),
             address(0), payable(address(0)), safeThresholdSignature(keys, txHash)));
        bytes memory fund = abi.encodeCall(IStreamRevealFeeEscrow.fundRevealFeeEscrow, (uint256(1)));
        faults.expectCall(address(entropy), 100, fund, 2);
        faults.expectCall(address(token), 0, abi.encodeCall(token.transfer, (wallet, uint256(1000))), 2);
        faults.mockCallRevert(address(entropy), 100, fund, abi.encodeWithSignature("Error(string)", "late native funding"));
        (bool ok,) = address(executor).call(exactSafeCall);
        require(!ok && executor.nonce() == 0 && address(executor).balance == 125
            && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
            && manager.nextOperationNonce() == 0 && ledger.counterValue(_counter()) == 0
            && !ledger.isManagerOperationRootUsed(address(manager), c.operationIdentityCommitment),
            "actual mint and Safe nonce rollback after funding is reached");
        require(!payment.isPaymentIntentNonceUsed(payer, intent.nonce)
            && !sale.authorizationUsed(vm.addr(SIGNER_KEY), e.authorization.nonce)
            && sale.executionIdByNonce(saleId, 1) == 0 && token.rawBalance(payer) == 10000
            && token.rawBalance(wallet) == 0 && token.allowance(payer, address(payment)) == 10000
            && recorder.totalOfficialSettled(address(token)) == 0 && entropy.revealFeeEscrow(1) == 0
            && sale.refundLiability() == 0 && address(sale).balance == 0, "all payment/replay liabilities roll back");
        faults.clearMockedCalls();
        (ok,) = address(executor).call(exactSafeCall);
        require(ok && executor.nonce() == 1 && core.ownerOf(1) == payer
            && ledger.counterValue(_counter()) == 1 && manager.nextOperationNonce() == 1
            && token.rawBalance(wallet) == 1000 && recorder.totalOfficialSettled(address(token)) == 1000
            && entropy.revealFeeEscrow(1) == 100 && entropy.requestCalls() == 1, "identical complete Safe call succeeds");
        require(sale.refundableBalance(saleId, address(executor)) == 25
            && sale.refundableBalance(saleId, payer) == 0 && sale.refundLiability() == 25,
            "native Safe funder differs from token payer");
        require(executeSafe(executor, keys, address(sale), 0,
            abi.encodeCall(sale.claimRefund, (saleId, address(executor))), 0), "actual Safe pull refund");
        require(address(executor).balance == 25 && sale.refundLiability() == 0, "exact native excess refund");
    }

}
