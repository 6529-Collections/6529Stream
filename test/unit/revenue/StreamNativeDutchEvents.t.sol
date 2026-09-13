// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/DutchSaleTestBase.sol";

contract StreamNativeDutchEventsTest is DutchSaleTestBase {
    function testNamedSaleConfigIdentityAndCanonicalConfigurationAndConsentEvents() public {
        IStreamNativeDutchSale.DutchSaleConfig memory config = _dutchConfig();
        uint256 nonce = dutchSale.nextSaleNonce();
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(dutchSale),
                uint8(3),
                uint256(1),
                PHASE,
                nonce
            )
        );
        bytes32 schedule = keccak256(
            abi.encode(
                bytes32(0xf22d2e97f1de4a74f3f96b4bd6c3dc8bd6a378980328e92785afa57f0c3957ad),
                block.chainid,
                address(dutchSale),
                id,
                uint96(1000),
                uint96(100),
                uint64(1000),
                uint64(1010),
                uint8(0),
                uint32(0),
                uint96(0)
            )
        );
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(resolver, 1);
        bytes32 baseline = StreamSaleTemplate.policyHash(resolver, 1, rights);
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_DUTCH_CONFIG_V1"),
                id,
                uint256(1),
                PHASE,
                uint96(1000),
                uint96(100),
                uint64(1000),
                uint64(1010),
                uint8(0),
                uint32(0),
                uint96(0),
                uint64(100),
                uint64(10000),
                false,
                refundManager.currentPolicy(),
                schedule,
                baseline,
                rights.assignmentHash,
                uint8(0),
                address(0)
            )
        );
        vm.recordLogs();
        dutchId = dutchSale.registerDutchSale(config);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 configured;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(dutchSale)
                    || logs[i].topics[0]
                        != keccak256(
                            "SaleConfigured(uint16,bytes32,uint256,bytes32,uint8,address,bytes32,bytes32,uint8)"
                        )
            ) continue;
            ++configured;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == id
                    && logs[i].topics[2] == bytes32(uint256(1)) && logs[i].topics[3] == PHASE,
                "configuration topics"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(
                        abi.encode(uint16(1), uint8(3), address(0), hash, baseline, uint8(0))
                    ),
                "configuration full payload"
            );
        }
        require(
            configured == 1 && dutchId == id && dutchSale.saleRecord(id).configHash == hash
                && dutchSale.saleRecord(id).priceScheduleHash == schedule,
            "named full identity"
        );
        refundArtist.configureSaleConsent(true, 0);
        refundArtist.recordTestSaleConsent(address(dutchSale), 1, id, hash, true);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        vm.recordLogs();
        vm.prank(payer);
        dutchSale.purchase{ value: 1200 }(d);
        logs = vm.getRecordedLogs();
        uint256 consents;
        bytes32 key = keccak256(abi.encode(address(dutchSale), uint256(1), id, hash));
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(dutchSale)
                    || logs[i].topics[0]
                        != keccak256("SaleConsentRecorded(uint16,bytes32,uint256,bytes32,bytes32)")
            ) continue;
            ++consents;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == id
                    && logs[i].topics[2] == bytes32(uint256(1)),
                "consent topics"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(
                        abi.encode(uint16(1), hash, keccak256(abi.encode("Dutch consent", key)))
                    ),
                "exact consent evidence"
            );
        }
        require(consents == 1, "one actual consent event");
    }

    function testDeclaredZeroFullCompletionAndExcessEventsHaveNoOfficialRecorderCounterpart()
        public
    {
        IStreamNativeDutchSale.DutchSaleConfig memory config = _dutchConfig();
        config.declaredFree = true;
        config.schedule.restingPrice = 0;
        dutchId = dutchSale.registerDutchSale(config);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        vm.warp(1010);
        vm.recordLogs();
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory r = dutchSale.purchase{ value: 200 }(d);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 completed;
        uint256 excess;
        for (uint256 i; i < logs.length; ++i) {
            require(
                logs[i].emitter != address(recorder) && logs[i].emitter != address(escrow)
                    && logs[i].emitter != address(factory),
                "free does not emit official/accounting/materialization events"
            );
            if (logs[i].emitter != address(dutchSale)) continue;
            if (
                logs[i].topics[0]
                    == keccak256("SalePaymentExcessCredited(uint16,bytes32,address,uint256)")
            ) {
                ++excess;
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == dutchId
                        && logs[i].topics[2] == bytes32(uint256(uint160(payer)))
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), uint256(100))),
                    "canonical excess event"
                );
            }
            if (
                logs[i].topics[0]
                    == keccak256(
                        "DutchPurchaseCompleted(uint16,bytes32,bytes32,address,(uint8,uint256,uint256,uint256,uint256,bytes32,bytes32,bytes32,bytes32,bool))"
                    )
            ) {
                ++completed;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == dutchId
                        && logs[i].topics[2] == r.executionId
                        && logs[i].topics[3] == bytes32(uint256(uint160(payer)))
                        && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), r)),
                    "full typed free result event"
                );
            }
        }
        bytes32 hypotheticalKey = recorder.settlementKey(address(dutchSale), r.executionId);
        require(
            completed == 1 && excess == 1 && r.revenueOutcome == 1 && r.settlementKey == 0
                && recorder.settlementResult(hypotheticalKey).executionId == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "zero has no official key or totals"
        );
    }
}
