// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/NativeSettlementTestBase.sol";

contract StreamNativeSettlementEventsTest is NativeSettlementTestBase {
    function testNativeManagerRootCommitsCanonicalFullDigestTicket() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeFixedPriceSaleAdapter"),
                keccak256("1"),
                block.chainid,
                address(nativeSale)
            )
        );
        bytes32 typeHash = keccak256(
            "NativeSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash)"
        );
        bytes32 digest = keccak256(
            abi.encodePacked(hex"1901", domain, keccak256(abi.encode(typeHash, e.authorization)))
        );
        require(
            digest == c.executionBinding.saleAuthorizationDigest,
            "independent full native EIP712 digest"
        );
        IStreamMintManager.MintBatch memory b;
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = payer;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = payer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = e.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = e.authorization.mintCommitment;
        b.expectedPolicyHash = manager.POLICY();
        b.authorizationId =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
        b.contextHash = digest;
        require(
            c.operationIdentityCommitment
                == keccak256(abi.encode(b, address(nativeSale), uint256(0))),
            "exact manager ticket/root preimage"
        );
        _buy(e);
        require(manager.ownerOf(1) == payer, "same canonical ticket executes");
    }

    function testExactNativeExecutionAndFourCanonicalRecorderEvents() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        bytes32 expectedExecution = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SALE_EXECUTION_V1"),
                block.chainid,
                address(nativeSale),
                nativeId,
                payer,
                payer,
                uint256(1),
                uint8(1),
                c.executionBinding.saleAuthorizationDigest,
                c.currentPolicyHash,
                c.boundPolicyHash,
                c.operationIdentityCommitment
            )
        );
        require(
            c.executionBinding.executionId == expectedExecution,
            "independent native execution identity"
        );
        vm.recordLogs();
        (StreamPrimarySettlementTypes.PrimarySettlementResult memory r,) = _buy(e);
        _contextLog(vm.getRecordedLogs(), c, r);
    }

    function _contextLog(
        Vm.Log[] memory logs,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r
    ) private view {
        bytes32 topic = keccak256(
            "PrimaryRevenueSettlementContext(bytes32,bytes32,bytes32,uint16,address,bytes32,uint8,uint256,uint256,bytes32,bytes32,uint256,address,address,bytes32)"
        );
        bytes memory expected = abi.encode(
            uint16(1),
            address(nativeSale),
            nativeId,
            uint8(0),
            uint256(1),
            uint256(0),
            c.operationIdentityCommitment,
            c.operationId,
            uint256(1),
            address(0),
            c.sale.beneficiary,
            bytes32(0)
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(recorder) || logs[i].topics[0] != topic) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == r.settlementKey
                    && logs[i].topics[2] == CLASS && logs[i].topics[3] == profile,
                "exact context topics"
            );
            require(
                keccak256(logs[i].data) == keccak256(expected), "independent twelve word context"
            );
            ++count;
        }
        require(count == 1, "one canonical context");
        _event(
            logs,
            keccak256(
                "PrimaryRevenueSettled(bytes32,bytes32,bytes32,uint16,address,address,address,uint256,bytes32,bool,uint8)"
            ),
            r.settlementKey,
            CLASS,
            profile,
            abi.encode(
                uint16(1),
                wallet,
                address(0),
                payer,
                uint256(1000),
                keccak256(abi.encode(c.sale)),
                false,
                uint8(1)
            )
        );
        _event(
            logs,
            keccak256(
                "PrimaryRevenueSettlementPolicy(bytes32,bytes32,bytes32,uint16,bytes32,bytes32,bytes32,bytes32)"
            ),
            r.settlementKey,
            CLASS,
            profile,
            abi.encode(
                uint16(1),
                c.sale.expectedPrimaryPolicyHash,
                c.sale.expectedPrimaryPolicyHash,
                c.rights.assignmentHash,
                bytes32(0)
            )
        );
        _event(
            logs,
            keccak256(
                "PrimaryRevenueExecutionBound(bytes32,address,bytes32,uint16,address,address,bytes32,bytes32,bytes32)"
            ),
            r.settlementKey,
            bytes32(uint256(uint160(address(nativeSale)))),
            c.executionBinding.executionId,
            abi.encode(
                uint16(1),
                payer,
                address(0),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_SETTLEMENT_CANDIDATE_V1"),
                        block.chainid,
                        address(recorder),
                        c
                    )
                ),
                c.currentPolicyHash,
                c.boundPolicyHash
            )
        );
    }

    function _event(
        Vm.Log[] memory logs,
        bytes32 signature,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes memory data
    ) private view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(recorder) || logs[i].topics[0] != signature) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == a && logs[i].topics[2] == b
                    && logs[i].topics[3] == c,
                "exact official event topics"
            );
            require(
                keccak256(logs[i].data) == keccak256(data),
                "independent exact official event payload"
            );
            ++count;
        }
        require(count == 1, "one event per official transition");
    }
}
