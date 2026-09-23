// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";

contract StreamRefundWindowFeesTest is RefundWindowTestBase {
    function testAdmittedRevealRevertOOGAndMalformedReturnsPreserveMintAndFundedEscrow() public {
        refundEntropy.setPolicy(true, 0, 100);
        bytes32[4] memory purchases;
        for (uint256 i; i < 4; ++i) {
            purchases[i] = _purchase(i + 1, 1100);
        }
        _atRefundEnd(purchases[0]);
        for (uint256 mode = 1; mode <= 4; ++mode) {
            refundEntropy.setModes(0, mode);
            vm.recordLogs();
            IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
                refundSale.finalizeRefundWindow(purchases[mode - 1]);
            _attemptEvent(vm.getRecordedLogs(), r.tokenId, false, mode);
            require(
                r.revealFeeForwarded == 100
                    && refundSale.refundPurchaseRecord(purchases[mode - 1]).status == 2
                    && wallet.balance == 1000 * mode
                    && refundEntropy.revealFeeEscrow(1) == 100 * mode,
                "admitted external request failure preserves paid mint and fee"
            );
        }
        require(
            refundSale.totalBuyerLiabilities() == 0 && refundManager.nonce() == 4
                && recorder.totalOfficialSettled(address(0)) == 4000,
            "all four official finalizations persist"
        );
    }

    function testAdmittedSuccessfulRevealEmitsExactRequestIdentity() public {
        refundEntropy.setPolicy(true, 0, 100);
        bytes32 id = _purchase(1, 1100);
        _atRefundEnd(id);
        vm.recordLogs();
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
            refundSale.finalizeRefundWindow(id);
        _attemptEvent(vm.getRecordedLogs(), r.tokenId, true, 0);
        require(
            refundEntropy.requestCount() == 1 && r.revealFeeForwarded == 100,
            "actual successful typed request"
        );
    }

    function _attemptEvent(Vm.Log[] memory logs, uint256 tokenId, bool success, uint256 mode)
        private
        view
    {
        uint256 count;
        bytes32 topic = keccak256(
            "RefundRevealAttempt(uint16,uint256,uint256,bool,bytes32,uint256,uint256,bytes)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(refundSale) || logs[i].topics[0] != topic) continue;
            ++count;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == bytes32(tokenId),
                "exact collection and minted token"
            );
            (
                uint16 schema,
                bool ok,
                bytes32 key,
                uint256 providerId,
                uint256 size,
                bytes memory prefix
            ) = abi.decode(logs[i].data, (uint16, bool, bytes32, uint256, uint256, bytes));
            require(schema == 1 && ok == success, "schema and actual call outcome");
            if (success) {
                require(
                    key == keccak256(abi.encode(tokenId)) && providerId == block.number
                        && size == 64 && prefix.length == 0,
                    "exact request result"
                );
            } else {
                require(
                    key == 0 && providerId == 0 && prefix.length <= 256
                        && prefix.length == (size > 256 ? 256 : size),
                    "bounded failure evidence"
                );
                if (mode == 1) {
                    require(
                        keccak256(prefix)
                            == keccak256(
                                abi.encodeWithSignature("Error(string)", "provider rejected")
                            ),
                        "exact revert bytes"
                    );
                }
                if (mode == 2) require(size == 0, "OOG has no invented reason");
                if (mode == 3) {
                    require(
                        size == 32 && keccak256(prefix) == keccak256(abi.encode(uint256(1))),
                        "exact malformed word"
                    );
                }
                if (mode == 4) {
                    require(size == 65536 && prefix.length == 256, "return bomb bounded");
                }
            }
        }
        require(count == 1, "one attempt event");
    }

    function testFeeFundingRevertNoopAndMalformedReturnRevertEntireFinalization() public {
        bytes32 id = _purchase(1, 1100);
        _atRefundEnd(id);
        for (uint256 mode = 1; mode <= 3; ++mode) {
            refundEntropy.setModes(mode, 0);
            if (mode == 2) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IStreamNativeRefundWindowSale.RefundAccountingMismatch.selector
                    )
                );
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IStreamNativeRefundWindowSale.RefundDependencyInvalid.selector,
                        address(refundEntropy)
                    )
                );
            }
            refundSale.finalizeRefundWindow(id);
            _pending(id, 1100, 0);
            require(
                !recorder.deferredPurchaseConsumed(
                    recorder.deferredPurchaseKey(address(refundSale), id)
                ),
                "failed fee funding rolls back official key"
            );
        }
        refundEntropy.setModes(0, 0);
        refundSale.finalizeRefundWindow(id);
        require(
            wallet.balance == 1000 && refundEntropy.revealFeeEscrow(1) == 100,
            "same purchase healthy fee control"
        );
    }

    function testInsufficientParentRevealAdmissionRollsBackAndAdequateBudgetRetries() public {
        refundEntropy.setPolicy(true, 0, 100);
        bytes32 id = _purchase(1, 1100);
        _atRefundEnd(id);
        bytes32 parameter = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
        for (uint256 next = 400_000; next <= 3_200_000; next *= 2) {
            _raise(parameter, next);
        }
        (bool ok, bytes memory out) = address(refundSale).call{ gas: 1_000_000 }(
            abi.encodeCall(IStreamNativeRefundWindowSale.finalizeRefundWindow, (id))
        );
        bytes4 selector;
        uint256 cap;
        uint256 available;
        assembly ("memory-safe") {
            selector := mload(add(out, 32))
            cap := mload(add(out, 36))
            available := mload(add(out, 68))
        }
        require(
            !ok && out.length == 68
                && selector == StreamRefundWindowSupport.InsufficientRefundCallGas.selector
                && cap == 3_200_000 && available < cap,
            "exact current governed reveal cap admission"
        );
        _pending(id, 1100, 0);
        require(
            !recorder.deferredPurchaseConsumed(
                    recorder.deferredPurchaseKey(address(refundSale), id)
                ) && refundEntropy.requestCount() == 0,
            "no partial official/fee effects"
        );
        refundSale.finalizeRefundWindow(id);
        require(
            refundManager.nonce() == 1 && refundEntropy.requestCount() == 1
                && wallet.balance == 1000,
            "adequate outer budget exact retry"
        );
    }

    function _raise(bytes32 id, uint256 next) private {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            refundSale.gasParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(refundSale),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        _context(
            scope,
            keccak256(abi.encode(domain, scope, value, floor, failureClass, revision)),
            keccak256(abi.encode(domain, scope, next, floor, failureClass, revision + 1)),
            1
        );
        vm.prank(address(revenueAuthority));
        refundSale.raiseGasParameter(id, next);
        _clearContext();
        require(refundSale.gasParameter(id) == next, "real target-side governed update");
    }
}
