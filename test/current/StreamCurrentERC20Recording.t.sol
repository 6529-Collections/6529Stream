// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeEnglishAuctionFixture.sol";
import "../mocks/MockStreamPaymentToken.sol";
import "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import "../../smart-contracts/domains/mint/StreamUniversalFixedPriceSaleAdapter.sol";

interface RecordingFaultVM {
    function expectCall(address, uint256, bytes calldata) external;
}

/// @notice Actual current Core/Manager/Recorder regression for the extracted ERC20 worker.
/// @dev Token and the inherited Artist/entropy/governance boundaries remain explicit fixtures.
contract StreamCurrentERC20RecordingTest is NativeEnglishAuctionFixture {
    bytes32 private constant ERC_PHASE = keccak256("current extracted ERC20 phase");
    StreamERC20PrimarySettlementAdapter private payment;
    StreamUniversalFixedPriceSaleAdapter private sale;
    MockStreamPaymentToken private token;
    bytes32 private saleId;
    RecordingFaultVM private constant faults =
        RecordingFaultVM(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setUp() public override {
        super.setUp();
        token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("actual current exact ERC20"), 0);
        payment = new StreamERC20PrimarySettlementAdapter(recorder, address(0), 0);
        sale = new StreamUniversalFixedPriceSaleAdapter(
            manager, recorder, vm.addr(AUCTION_PLATFORM_KEY), artists
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
        entropy.configure(100, 1, true, false);
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
        entropy.configure(100, 1, false, false);
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
}
