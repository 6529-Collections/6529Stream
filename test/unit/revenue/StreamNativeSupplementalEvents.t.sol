// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/NativeSupplementalTestBase.sol";

contract StreamNativeSupplementalEventsTest is NativeSupplementalTestBase {
    function testIndependentCanonicalKeysAllEventPayloadsAndExactlyOneOfficialCredit() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        bytes32 pid = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(clearing),
                c.originalFloor.sale.settlementId,
                payer,
                uint256(1)
            )
        );
        require(pid == c.purchaseId, "canonical purchase preimage");
        bytes32 purchaseKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_SUPPLEMENT_LANE_V1"),
                block.chainid,
                address(recorder),
                address(clearing),
                pid
            )
        );
        bytes32 floorKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_FLOOR_LANE_V1"),
                block.chainid,
                address(recorder),
                c.purchase.floorSettlementKey
            )
        );
        bytes32 executionId = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_SUPPLEMENT_EXECUTION_V1"),
                block.chainid,
                address(recorder),
                address(clearing),
                pid,
                c.purchase.floorSettlementKey,
                address(this),
                c.purchase,
                c.currentRights,
                c.currentPrimaryPolicyHash
            )
        );
        bytes32 key = recorder.settlementKey(address(clearing), executionId);
        bytes32 commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_SUPPLEMENT_CANDIDATE_V1"),
                block.chainid,
                address(recorder),
                c
            )
        );
        vm.recordLogs();
        StreamNativeSupplementalTypes.NativeSupplementalResult memory result = _submit(c);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            result.settlementKey == key && result.executionId == executionId
                && result.candidateCommitment == commitment,
            "independent keys"
        );
        require(
            recorder.supplementalPurchaseConsumed(purchaseKey)
                && recorder.supplementalFloorConsumed(floorKey) && recorder.settlementConsumed(key),
            "all three lanes"
        );
        uint256 count;
        uint256 mask;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(recorder)) continue;
            ++count;
            require(logs[i].topics.length == 4, "exact topic count");
            bytes32 topic = logs[i].topics[0];
            if (
                topic
                    == keccak256(
                        "NativeSupplementalRevenueSettled(uint16,bytes32,bytes32,address,(bytes32,bytes32,bytes32,bytes32,uint256,bytes32,address,uint256,address,bytes32,bool,bytes32,bytes32,bytes32,bytes32,bool))"
                    )
            ) {
                mask |= 1;
                require(
                    logs[i].topics[1] == c.originalFloor.sale.settlementId
                        && logs[i].topics[2] == pid
                        && logs[i].topics[3] == bytes32(uint256(uint160(payer))),
                    "supplement topics"
                );
                require(
                    keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), result)),
                    "full sixteen result words"
                );
            } else {
                require(logs[i].topics[1] == key, "official exact key");
                if (
                    topic
                        == keccak256(
                            "PrimaryRevenueSettlementPolicy(bytes32,bytes32,bytes32,uint16,bytes32,bytes32,bytes32,bytes32)"
                        )
                ) {
                    mask |= 2;
                    require(
                        logs[i].topics[2] == CLASS
                            && logs[i].topics[3] == c.currentRights.profileId,
                        "policy indexed class/profile"
                    );
                    require(
                        keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    c.originalFloor.sale.expectedPrimaryPolicyHash,
                                    c.currentPrimaryPolicyHash,
                                    c.currentRights.assignmentHash,
                                    c.currentRights.templateId
                                )
                            ),
                        "policy original vs token current"
                    );
                } else if (
                    topic
                        == keccak256(
                            "PrimaryRevenueSettlementContext(bytes32,bytes32,bytes32,uint16,address,bytes32,uint8,uint256,uint256,bytes32,bytes32,uint256,address,address,bytes32)"
                        )
                ) {
                    mask |= 4;
                    require(
                        logs[i].topics[2] == CLASS
                            && logs[i].topics[3] == c.currentRights.profileId,
                        "context indexed class/profile"
                    );
                    require(
                        keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    address(clearing),
                                    c.originalFloor.sale.settlementId,
                                    uint8(1),
                                    uint256(1),
                                    uint256(1),
                                    c.originalFloor.operationIdentityCommitment,
                                    c.originalFloor.operationId,
                                    uint256(1),
                                    payer,
                                    payer,
                                    bytes32(0)
                                )
                            ),
                        "named twelve words context"
                    );
                } else if (
                    topic
                        == keccak256(
                            "PrimaryRevenueExecutionBound(bytes32,address,bytes32,uint16,address,address,bytes32,bytes32,bytes32)"
                        )
                ) {
                    mask |= 8;
                    require(
                        logs[i].topics[2] == bytes32(uint256(uint160(address(clearing))))
                            && logs[i].topics[3] == executionId,
                        "execution topics"
                    );
                    require(
                        keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    address(this),
                                    address(0),
                                    commitment,
                                    c.originalFloor.currentPolicyHash,
                                    c.originalFloor.boundPolicyHash
                                )
                            ),
                        "historical mint policy only"
                    );
                } else if (
                    topic
                        == keccak256(
                            "PrimaryRevenueSettled(bytes32,bytes32,bytes32,uint16,address,address,address,uint256,bytes32,bool,uint8)"
                        )
                ) {
                    mask |= 16;
                    require(
                        logs[i].topics[2] == CLASS
                            && logs[i].topics[3] == c.currentRights.profileId,
                        "settled indexed class/profile"
                    );
                    StreamPrimarySettlementTypes.PrimarySale memory saleContext =
                        StreamPrimarySettlementTypes.PrimarySale(
                            c.originalFloor.sale.settlementId,
                            CLASS,
                            1,
                            1,
                            1,
                            1,
                            payer,
                            payer,
                            payer,
                            2000,
                            c.currentPrimaryPolicyHash
                        );
                    require(
                        keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    wallet,
                                    address(0),
                                    payer,
                                    uint256(2000),
                                    keccak256(abi.encode(saleContext)),
                                    true,
                                    uint8(1)
                                )
                            ),
                        "settled exact delta and drift"
                    );
                } else {
                    revert("unexpected recorder event");
                }
            }
        }
        require(
            count == 5 && mask == 31 && supplementalManager.nonce() == 1,
            "one supplemental financial transcript"
        );
    }
}
