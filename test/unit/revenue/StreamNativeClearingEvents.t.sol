// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract StreamNativeClearingEventsTest is ClearingSaleTestBase {
    function _count(Vm.Log[] memory logs, bytes32 topic) private view returns (uint256 n) {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(clearingSale) && logs[i].topics[0] == topic) ++n;
        }
    }

    function testNamedConfigurationAndPurchasePayloadBindCompleteNativeTranscript() external {
        IStreamNativeClearingSale.ClearingSaleConfig memory c = _clearingConfig();
        uint256 nonce = clearingSale.nextSaleNonce();
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(clearingSale),
                uint8(4),
                uint256(1),
                PHASE,
                nonce
            )
        );
        bytes32 schedule = keccak256(
            abi.encode(
                bytes32(0xf22d2e97f1de4a74f3f96b4bd6c3dc8bd6a378980328e92785afa57f0c3957ad),
                block.chainid,
                address(clearingSale),
                id,
                uint96(1000),
                uint96(100),
                uint64(1000),
                uint64(1100),
                uint8(0),
                uint32(0),
                uint96(0)
            )
        );
        bytes32 windows = keccak256(
            abi.encode(
                keccak256("6529STREAM_CLEARING_WINDOW_POLICY_V1"),
                uint64(1100),
                uint64(100),
                uint64(1500),
                keccak256("OBSERVED_GLOBAL_OR_LOCAL_PAUSE_UNION"),
                keccak256("ABSOLUTE_ESCAPE_PAUSED_EQUALITY_UNPAUSED_FINALIZE_EQUALITY")
            )
        );
        bytes32 baseline = _primaryPolicy();
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_CONFIG_V1"),
                id,
                uint256(1),
                PHASE,
                uint96(1000),
                uint96(100),
                uint64(1000),
                uint64(1100),
                uint8(0),
                uint32(0),
                uint96(0),
                uint64(10),
                uint64(1100),
                uint64(100),
                uint64(1500),
                uint8(1),
                clearingManager.currentPolicy(),
                schedule,
                windows,
                baseline,
                address(0)
            )
        );
        vm.recordLogs();
        clearingId = clearingSale.registerClearingSale(c);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 baseCount;
        uint256 configCount;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(clearingSale)) continue;
            if (
                logs[i].topics[0]
                    == keccak256(
                        "SaleConfigured(uint16,bytes32,uint256,bytes32,uint8,address,bytes32,bytes32,uint8)"
                    )
            ) {
                ++baseCount;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == id
                        && logs[i].topics[2] == bytes32(uint256(1)) && logs[i].topics[3] == PHASE,
                    "canonical config topics"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(uint16(1), uint8(4), address(0), hash, baseline, uint8(1))
                        ),
                    "canonical config complete payload"
                );
            } else if (
                logs[i].topics[0]
                    == keccak256(
                        "ClearingSaleConfigured(uint16,bytes32,uint256,bytes32,bytes32,(uint256,bytes32,(uint96,uint96,uint64,uint64,uint8,uint32,uint96),uint64,uint64,uint64,uint64,uint8,bytes32))"
                    )
            ) {
                ++configCount;
                require(
                    logs[i].topics.length == 2 && logs[i].topics[1] == id
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), nonce, schedule, windows, c)),
                    "full config and exact windows"
                );
            }
        }
        require(
            baseCount == 1 && configCount == 1 && clearingId == id
                && clearingSale.saleRecord(id).configHash == hash,
            "named preimages and counts"
        );
        refundArtist.configureSaleConsent(true, 0);
        refundArtist.recordTestSaleConsent(address(clearingSale), 1, id, hash, true);
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        vm.recordLogs();
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1027 }(d);
        logs = vm.getRecordedLogs();
        uint256 purchaseCount;
        uint256 excessCount;
        uint256 consentCount;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(clearingSale)) continue;
            bytes32 topic = logs[i].topics[0];
            if (
                topic
                    == keccak256(
                        "ClearingPurchaseCompleted(uint16,bytes32,bytes32,address,(bytes32,uint256,uint256,uint256,uint256,uint256,uint256,bytes32,bytes32,bytes32,bytes32,bool),bool,uint256,uint256)"
                    )
            ) {
                ++purchaseCount;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == id
                        && logs[i].topics[2] == p.purchaseId
                        && logs[i].topics[3] == bytes32(uint256(uint160(payer)))
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), p, false, uint256(0), uint256(1))),
                    "purchase full result/raw ceiling/nonce"
                );
            } else if (
                topic == keccak256("SalePaymentExcessCredited(uint16,bytes32,address,uint256)")
            ) {
                ++excessCount;
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == id
                        && logs[i].topics[2] == bytes32(uint256(uint160(payer)))
                        && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), uint256(7))),
                    "excess native per sale"
                );
            } else if (
                topic == keccak256("SaleConsentRecorded(uint16,bytes32,uint256,bytes32,bytes32)")
            ) {
                ++consentCount;
                bytes32 key = keccak256(abi.encode(address(clearingSale), uint256(1), id, hash));
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == id
                        && logs[i].topics[2] == bytes32(uint256(1))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1), hash, keccak256(abi.encode("Dutch consent", key))
                                )
                            ),
                    "exact current facade evidence"
                );
            }
        }
        require(
            purchaseCount == 1 && excessCount == 1 && consentCount == 1, "one each purchase event"
        );
    }

    function testScheduledAmountIsNotOfficialAndRebateEventIsPermissionlessOnceAndClaimIndependent()
        external
    {
        _buy(1, 1027);
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        vm.recordLogs();
        clearingSale.fixClearingPrice(clearingId);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 fixedTopic =
            keccak256("DutchClearingFinalized(uint16,bytes32,uint256,uint256,uint256)");
        uint256 fixedCount;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(clearingSale) && logs[i].topics[0] == fixedTopic) {
                ++fixedCount;
                require(
                    logs[i].topics.length == 2 && logs[i].topics[1] == clearingId
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(uint16(1), uint256(640), uint256(1), uint256(540))
                            ),
                    "scheduled exact aggregate event"
                );
            }
        }
        bytes32 rebateTopic = keccak256("DutchRebateCredited(uint16,bytes32,address,uint256)");
        require(
            fixedCount == 1 && _count(logs, rebateTopic) == 0
                && clearingSale.refundableBalance(clearingId, payer) == 367
                && recorder.totalOfficialSettled(address(0)) == 100,
            "rebate immediate without buyer loop or official supplement"
        );
        vm.recordLogs();
        vm.prank(address(0xCAFE));
        require(clearingSale.synchronizeRebate(clearingId, payer) == 360);
        logs = vm.getRecordedLogs();
        require(
            _count(logs, rebateTopic) == 1 && logs.length == 1 && logs[0].topics.length == 3
                && logs[0].topics[1] == clearingId
                && logs[0].topics[2] == bytes32(uint256(uint160(payer)))
                && keccak256(logs[0].data) == keccak256(abi.encode(uint16(1), uint256(360))),
            "exact one-time rebate announcement"
        );
        vm.recordLogs();
        require(clearingSale.synchronizeRebate(clearingId, payer) == 0);
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        logs = vm.getRecordedLogs();
        require(
            _count(logs, rebateTopic) == 0 && clearingSale.totalBuyerLiabilities() == 540,
            "idempotency and claim independence"
        );
        vm.warp(1501);
        vm.recordLogs();
        clearingSale.unlockRefunds(clearingId, 0);
        logs = vm.getRecordedLogs();
        bytes32 unlockTopic = keccak256("DutchClearingRefundUnlocked(uint16,bytes32,bytes32)");
        uint256 unlockCount;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(clearingSale) && logs[i].topics[0] == unlockTopic) {
                ++unlockCount;
                require(
                    logs[i].topics.length == 2 && logs[i].topics[1] == clearingId
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(uint16(1), keccak256("CLEARING_ABSOLUTE_ESCAPE"))
                            ),
                    "exact unconditional escape reason"
                );
            }
        }
        vm.recordLogs();
        clearingSale.synchronizeRebate(clearingId, payer);
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        logs = vm.getRecordedLogs();
        require(
            unlockCount == 1 && _count(logs, rebateTopic) == 0
                && clearingSale.totalBuyerLiabilities() == 0 && wallet.balance == 100,
            "unsettled release not relabeled as original rebate"
        );
    }
}
