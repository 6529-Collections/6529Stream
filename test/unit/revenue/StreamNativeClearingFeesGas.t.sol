// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract StreamNativeClearingFeesGasTest is ClearingSaleTestBase {
    event log_named_uint(string key, uint256 value);

    function _raise(bytes32 id, uint256 next) private {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            clearingSale.gasParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(clearingSale),
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
        clearingSale.raiseGasParameter(id, next);
        _clearContext();
    }

    function testAdmittedRevealFailureKeepsFloorMintOverageAndSavedFee() external {
        refundEntropy.setPolicy(true, 0, 20);
        for (uint256 mode = 1; mode <= 4; ++mode) {
            refundEntropy.setModes(0, mode);
            IStreamNativeClearingSale.ClearingPurchaseData memory d =
                _clearingData(mode, payer, payer);
            vm.recordLogs();
            vm.prank(payer);
            IStreamNativeClearingSale.ClearingPurchaseResult memory p =
                clearingSale.purchase{ value: 1020 }(d);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 count;
            for (uint256 i; i < logs.length; ++i) {
                if (
                    logs[i].emitter == address(clearingSale)
                        && logs[i].topics[0]
                            == keccak256(
                                "DutchRevealAttempt(uint16,uint256,uint256,bool,bytes32,uint256,uint256,bytes)"
                            )
                ) {
                    ++count;
                    (
                        uint16 schema,
                        bool ok,
                        bytes32 key,
                        uint256 providerId,
                        uint256 size,
                        bytes memory prefix
                    ) = abi.decode(logs[i].data, (uint16, bool, bytes32, uint256, uint256, bytes));
                    require(
                        logs[i].topics.length == 3 && logs[i].topics[1] == bytes32(uint256(1))
                            && logs[i].topics[2] == bytes32(p.tokenId) && schema == 1 && !ok
                            && key == 0 && providerId == 0
                            && prefix.length == (size > 256 ? 256 : size),
                        "bounded actual failure event"
                    );
                    if (mode == 1) {
                        require(
                            keccak256(prefix)
                                == keccak256(
                                    abi.encodeWithSignature("Error(string)", "provider rejected")
                                ),
                            "exact provider revert"
                        );
                    }
                    if (mode == 2) require(size == 0, "actual exhausted request frame");
                    if (mode == 3) require(size == 32, "malformed result");
                    if (mode == 4) {
                        require(size == 65536 && prefix.length == 256, "bounded return bomb");
                    }
                }
            }
            require(
                count == 1 && wallet.balance == 100 * mode && clearingManager.nonce() == mode
                    && refundEntropy.revealFeeEscrow(1) == 20 * mode
                    && clearingSale.totalBuyerLiabilities() == 900 * mode,
                "completed purchase despite admitted request failure"
            );
        }
        refundEntropy.setModes(0, 0);
        _buy(5, 1020);
        require(
            refundEntropy.requestCount() == 3 && clearingManager.nonce() == 5,
            "healthy request plus successful malformed frames counted; reverted frames roll back"
        );
    }

    function testParentPreflightRejectsInsufficientGovernedCapAndIdenticalProofSucceeds() external {
        refundEntropy.setPolicy(true, 0, 20);
        bytes32 id = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
        for (uint256 cap = 400000; cap <= 3200000; cap *= 2) {
            _raise(id, cap);
        }
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        vm.prank(payer);
        (bool ok, bytes memory out) = address(clearingSale).call{ gas: 1000000, value: 1020 }(
            abi.encodeCall(clearingSale.purchase, (d))
        );
        bytes4 selector;
        uint256 required;
        uint256 available;
        assembly ("memory-safe") {
            selector := mload(add(out, 32))
            required := mload(add(out, 36))
            available := mload(add(out, 68))
        }
        require(
            !ok && out.length == 68
                && selector == StreamDutchSaleSupport.InsufficientDutchCallGas.selector
                && required == 3200000 && available < required,
            "exact governed parent admission"
        );
        require(
            wallet.balance == 0 && clearingManager.nonce() == 0
                && clearingSale.totalBuyerLiabilities() == 0
                && clearingSale.nextPurchaseNonce(clearingId, payer) == 1
                && recorder.totalOfficialSettled(address(0)) == 0,
            "preflight rollback all lanes"
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        require(
            wallet.balance == 100 && clearingSale.totalBuyerLiabilities() == 900
                && refundEntropy.requestCount() == 1,
            "same proof with sufficient parent"
        );
    }

    function testFeeFailuresAndBelowFeeHaveExactControlsWithoutLosingSavedCustody() external {
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.SaleRevealFeeBelowRequired.selector,
                uint256(19),
                uint256(20)
            )
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 19 }(d);
        for (uint256 mode = 1; mode <= 3; ++mode) {
            refundEntropy.setModes(mode, 0);
            vm.expectRevert(
                mode == 2
                    ? abi.encodeWithSelector(
                        IStreamNativeDutchSale.DutchAccountingMismatch.selector
                    )
                    : abi.encodeWithSelector(
                            IStreamNativeDutchSale.DutchDependencyInvalid.selector,
                            address(refundEntropy)
                        )
            );
            vm.prank(payer);
            clearingSale.purchase{ value: 1020 }(d);
            require(
                wallet.balance == 0 && clearingManager.nonce() == 0
                    && clearingSale.totalBuyerLiabilities() == 0
                    && refundEntropy.revealFeeEscrow(1) == 0,
                "fee transfer effect entirely rolled back"
            );
        }
        refundEntropy.setModes(0, 0);
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        require(
            wallet.balance == 100 && clearingSale.totalBuyerLiabilities() == 900
                && refundEntropy.revealFeeEscrow(1) == 20,
            "same fee snapshot healthy retry"
        );
    }

    function testMeasureComposedPurchaseWithTwoFreshTreesAndRealFloorMint() external {
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        SafeFixtureVm(address(vm)).cool(address(clearingSale));
        SafeFixtureVm(address(vm)).cool(address(recorder));
        SafeFixtureVm(address(vm)).cool(wallet);
        SafeFixtureVm(address(vm)).cool(address(clearingManager));
        vm.prank(payer);
        uint256 beforeGas = gasleft();
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1020 }(d);
        uint256 first = beforeGas - gasleft();
        emit log_named_uint("COMPOSED_FIRST_BUY_TWO_FRESH_AGGREGATES_PARTIALLY_COOLED", first);
        d = _clearingData(2, payer, payer);
        vm.prank(payer);
        beforeGas = gasleft();
        clearingSale.purchase{ value: 1020 }(d);
        uint256 repeat = beforeGas - gasleft();
        emit log_named_uint("COMPOSED_REPEAT_BUY_TWO_EXISTING_PATHS_WARM", repeat);
        require(
            first < 6843542 && repeat < first && wallet.balance == 200
                && clearingManager.nonce() == 2 && p.floorRevenue == 100
                && clearingSale.totalBuyerLiabilities() == 1800,
            "full composed price/fee/mint and paired aggregates"
        );
    }
}
