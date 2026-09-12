// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/DutchSaleTestBase.sol";

contract StreamNativeDutchFeesTest is DutchSaleTestBase {
    function testDeclaredFreeFeeUnderpaymentHasDistinctExactErrorAndSameProofControl() public {
        IStreamNativeDutchSale.DutchSaleConfig memory c = _dutchConfig();
        c.schedule.restingPrice = 0;
        c.declaredFree = true;
        dutchId = dutchSale.registerDutchSale(c);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        vm.warp(1010);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.SaleRevealFeeBelowRequired.selector,
                uint256(99),
                uint256(100)
            )
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 99 }(d);
        require(
            refundManager.nonce() == 0 && dutchSale.executionIdByNonce(dutchId, 1) == 0,
            "fee rejection does not consume"
        );
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory result = dutchSale.purchase{ value: 100 }(
            d
        );
        require(
            result.revenueOutcome == 1 && result.chargedAmount == 0
                && result.revealFeeForwarded == 100
                && recorder.totalOfficialSettled(address(0)) == 0,
            "same proof declared fee-only control"
        );
    }

    function _attemptEvent(Vm.Log[] memory logs, uint256 tokenId, bool success, uint256 mode)
        private
        view
    {
        uint256 count;
        bytes32 topic = keccak256(
            "DutchRevealAttempt(uint16,uint256,uint256,bool,bytes32,uint256,uint256,bytes)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(dutchSale) || logs[i].topics[0] != topic) continue;
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

    function _raise(bytes32 id, uint256 next) private {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            dutchSale.gasParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(dutchSale),
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
        dutchSale.raiseGasParameter(id, next);
        _clearContext();
        require(dutchSale.gasParameter(id) == next, "real target-side governed update");
    }

    function testAdmittedRevealFailureDoesNotRefundOrUndoMintAndHealthyRequestUsesSamePath()
        public
    {
        refundEntropy.setPolicy(true, 0, 100);
        for (uint256 mode = 1; mode <= 4; ++mode) {
            refundEntropy.setModes(0, mode);
            IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(mode, payer, payer);
            vm.recordLogs();
            vm.prank(payer);
            IStreamNativeDutchSale.DutchPurchaseResult memory r =
                dutchSale.purchase{ value: 1100 }(d);
            _attemptEvent(vm.getRecordedLogs(), r.tokenId, false, mode);
            require(
                r.revealFeeForwarded == 100 && dutchSale.executionStatus(r.executionId) == 2
                    && wallet.balance == 1000 * mode
                    && refundEntropy.revealFeeEscrow(1) == 100 * mode,
                "admitted revert/OOG/malformed response keeps completed paid mint"
            );
        }
        refundEntropy.setModes(0, 0);
        IStreamNativeDutchSale.DutchPurchaseData memory healthy = _dutchData(5, payer, payer);
        vm.recordLogs();
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory result =
            dutchSale.purchase{ value: 1100 }(healthy);
        _attemptEvent(vm.getRecordedLogs(), result.tokenId, true, 0);
        require(
            refundManager.nonce() == 5 && recorder.totalOfficialSettled(address(0)) == 5000
                && dutchSale.refundLiability() == 0,
            "one healthy control and four permanent mints"
        );
    }

    function testParentCannotSilentlyUnderforwardGovernedRevealCapAndSameProofRetries() public {
        refundEntropy.setPolicy(true, 0, 100);
        bytes32 parameter = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
        for (uint256 next = 400000; next <= 3200000; next *= 2) {
            _raise(parameter, next);
        }
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        vm.prank(payer);
        (bool ok, bytes memory out) = address(dutchSale).call{ gas: 1000000, value: 1100 }(
            abi.encodeCall(IStreamNativeDutchSale.purchase, (d))
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
                && selector == StreamDutchSaleSupport.InsufficientDutchCallGas.selector
                && cap == 3200000 && available < cap,
            "exact current cap admission"
        );
        require(
            refundManager.nonce() == 0 && wallet.balance == 0
                && refundEntropy.revealFeeEscrow(1) == 0
                && dutchSale.executionIdByNonce(dutchId, 1) == 0
                && dutchSale.refundLiability() == 0,
            "underfunded parent leaves no official, replay, mint or fee effect"
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(
            wallet.balance == 1000 && refundEntropy.requestCount() == 1,
            "same proof adequate parent control"
        );
    }

    function testFeeFundingFailureRevertsFullPaidMintAndSameProofRetries() public {
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        for (uint256 mode = 1; mode <= 3; ++mode) {
            refundEntropy.setModes(mode, 0);
            if (mode == 2) {
                vm.expectRevert(
                    abi.encodeWithSelector(IStreamNativeDutchSale.DutchAccountingMismatch.selector)
                );
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IStreamNativeDutchSale.DutchDependencyInvalid.selector,
                        address(refundEntropy)
                    )
                );
            }
            vm.prank(payer);
            dutchSale.purchase{ value: 1200 }(d);
            require(
                wallet.balance == 0 && refundManager.nonce() == 0
                    && recorder.totalOfficialSettled(address(0)) == 0
                    && dutchSale.executionIdByNonce(dutchId, 1) == 0
                    && dutchSale.refundLiability() == 0,
                "full failed fee rollback"
            );
        }
        refundEntropy.setModes(0, 0);
        vm.prank(payer);
        dutchSale.purchase{ value: 1200 }(d);
        require(
            wallet.balance == 1000 && dutchSale.refundableBalance(dutchId, payer) == 100,
            "same proof healthy fee control"
        );
    }
}
