// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativePricePrograms.t.sol";

contract ImmediateRefundRejector {
    receive() external payable {
        revert("reject refund");
    }
}

/// @notice Revenue/fee separation, provider isolation and Safe-owned refunds on immediate native kinds.
/// @dev Entropy policy/provider is explicit here; the current-stack suite exercises the real coordinator.
contract StreamNativeImmediateRevealTest is NativePriceProgramTestBase {
    function _entropy() private view returns (ImmediateRevealFixture) {
        return ImmediateRevealFixture(core.entropy());
    }

    function testLiveFeeDriftChargesOnlyCurrentFeeAndAccumulatesExcess() public {
        _entropy().configure(true, 0, 5, 0);
        IStreamImmediateSaleReveal.RevealQuote memory oldQuote =
            nativeSale.saleRevealQuote(nativeId);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        bytes32 fixedHash = e.authorization.saleConfigHash;
        _entropy().configure(true, 0, 12, 0);
        vm.prank(payer);
        nativeSale.purchase{ value: 1020 }(e);
        require(
            oldQuote.policy.revealFeePerTokenWei == 5
                && nativeSale.refundableBalance(nativeId, payer) == 8,
            "quote drift within allowance"
        );
        _entropy().configure(true, 0, 3, 0);
        (e,) = _nativeExecution(payer, payer, 2);
        vm.prank(payer);
        nativeSale.purchase{ value: 1020 }(e);
        require(
            nativeSale.saleRecord(nativeId).configHash == fixedHash,
            "operational fee not signed sale identity"
        );
        require(
            _entropy().revealFeeEscrow(1) == 15 && _entropy().requests() == 2
                && _entropy().lastRequestedToken() == 2,
            "separate fee funding and requests"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 2000 && wallet.balance == 2000,
            "revenue excludes fee and allowance"
        );
        require(
            nativeSale.refundLiability() == 25
                && nativeSale.refundableBalance(nativeId, payer) == 25
                && address(nativeSale).balance == 25,
            "all residual value owed to payer"
        );
        require(nativeSale.refundAccountCount() == 1, "one append-only payer row");
        (bytes32 id, address account) = nativeSale.refundAccountAt(0);
        require(id == nativeId && account == payer, "state-only discovery");
    }

    function testInsufficientAllowanceRollsBackThenSameAuthorizationSucceeds() public {
        _entropy().configure(true, 0, 11, 0);
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamImmediateSaleReveal.SaleRevealFeeBelowRequired.selector,
                uint256(10),
                uint256(11)
            )
        );
        vm.prank(payer);
        nativeSale.purchase{ value: 1010 }(e);
        _unchanged(c, 10 ether);
        vm.prank(payer);
        nativeSale.purchase{ value: 1011 }(e);
        require(
            _entropy().revealFeeEscrow(1) == 11 && nativeSale.refundLiability() == 0
                && manager.nonce() == 1,
            "identical proof retries"
        );
    }

    function testProviderRevertLargeReturnGasExhaustionAndMalformedReturnNeverUndoMint() public {
        for (uint8 fault = 1; fault <= 4; ++fault) {
            _entropy().configure(true, 0, 7, fault);
            (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
                _nativeExecution(payer, payer, fault);
            vm.recordLogs();
            vm.prank(payer);
            (, uint256 tokenId) = nativeSale.purchase{ value: 1010 }(e);
            _failedAttempt(vm.getRecordedLogs(), tokenId, fault);
            require(
                tokenId == fault && manager.ownerOf(tokenId) == payer, "provider cannot undo mint"
            );
            require(
                nativeSale.authorizationUsed(artist, bytes32(uint256(fault))),
                "successful purchase consumes replay"
            );
        }
        require(
            recorder.totalOfficialSettled(address(0)) == 4000
                && _entropy().revealFeeEscrow(1) == 28,
            "revenue and retained coordinator funding"
        );
        require(
            nativeSale.refundLiability() == 12 && _entropy().requests() == 0,
            "no completed provider request"
        );
    }

    function _failedAttempt(Vm.Log[] memory logs, uint256 tokenId, uint8 fault) private view {
        bytes32 topic = keccak256(
            "ImmediateRevealAttempt(uint16,uint256,uint256,bool,bytes32,uint256,uint256,bytes)"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(nativeSale) || logs[i].topics[0] != topic) continue;
            ++count;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == bytes32(tokenId),
                "attempt identifies minted token"
            );
            (
                uint16 schema,
                bool ok,
                bytes32 key,
                uint256 providerId,
                uint256 size,
                bytes memory prefix
            ) = abi.decode(logs[i].data, (uint16, bool, bytes32, uint256, uint256, bytes));
            require(
                schema == 1 && !ok && key == 0 && providerId == 0 && prefix.length <= 256,
                "failed outcome and bounded prefix"
            );
            if (fault == 2) {
                require(size == 16384 && prefix.length == 256, "large failure is truncated");
            }
            if (fault == 3) require(size == 0 && prefix.length == 0, "out of stipend has no data");
            if (fault == 4) {
                require(size == 32 && prefix.length == 32, "malformed return is isolated");
            }
        }
        require(count == 1, "one attempt per minted token");
    }

    function testOwnerWindowFundsFeeWithoutCallingProvider() public {
        _entropy().configure(true, 1, 9, 1);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        vm.prank(payer);
        nativeSale.purchase{ value: 1012 }(e);
        require(
            _entropy().requests() == 0 && _entropy().revealFeeEscrow(1) == 9
                && nativeSale.refundLiability() == 3,
            "owner window only funds"
        );
    }

    function testZeroPriceClaimChargesRevealFeeWithoutOfficialSettlement() public {
        _entropy().configure(true, 0, 7, 0);
        bytes32 id = _program(12, 0, 0, 2);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 0, 0);
        vm.prank(payer);
        IStreamNativePricePrograms.PriceProgramResult memory result =
            nativeSale.executePriceProgram{ value: 11 }(e);
        require(
            result.revenueOutcome == 1 && result.settlementKey == 0 && result.tokenId == 1,
            "declared zero-price outcome"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 0 && _entropy().revealFeeEscrow(1) == 7,
            "fee is not a sale"
        );
        require(
            nativeSale.refundableBalance(id, payer) == 4 && _entropy().requests() == 1,
            "free mint reveal and excess"
        );
    }

    function testFixedOpenEditionAndPwywPriceProgramsFundOnlyChosenRevenue() public {
        _entropy().configure(true, 0, 5, 0);
        uint8[3] memory kinds = [uint8(0), uint8(1), uint8(13)];
        for (uint256 i; i < kinds.length; ++i) {
            bytes32 id = _program(kinds[i], 777, kinds[i] == 13 ? 1000 : 777, kinds[i] == 1 ? 0 : 2);
            IStreamNativePricePrograms.PriceProgramExecution memory e =
                _execution(id, i + 1, 777, 777);
            vm.prank(payer);
            nativeSale.executePriceProgram{ value: 790 }(e);
            require(
                nativeSale.refundableBalance(id, payer) == 8, "each program owns its excess row"
            );
        }
        require(
            recorder.totalOfficialSettled(address(0)) == 2331
                && _entropy().revealFeeEscrow(1) == 15,
            "all immediate price families separate fee"
        );
        require(
            nativeSale.refundLiability() == 24 && _entropy().requests() == 3, "all three attempted"
        );
    }

    function testUndeclaredPolicyRejectsConfigurationAndPurchase() public {
        _entropy().configure(false, 0, 0, 0);
        IStreamNativePricePrograms.PriceProgramConfig memory config = _config(12, 0, 0, 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamImmediateSaleReveal.SaleRevealDependencyInvalid.selector, address(_entropy())
            )
        );
        nativeSale.registerPriceProgram(config);
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamImmediateSaleReveal.SaleRevealDependencyInvalid.selector, address(_entropy())
            )
        );
        vm.prank(payer);
        nativeSale.purchase{ value: 1000 }(e);
        _unchanged(c, 10 ether);
    }

    function testIncorrectEscrowFundingRollsBackMintRevenueAndReplay() public {
        _entropy().configure(true, 0, 7, 5);
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamImmediateSaleReveal.SaleRevealAccountingMismatch.selector)
        );
        vm.prank(payer);
        nativeSale.purchase{ value: 1007 }(e);
        _unchanged(c, 10 ether);
        require(address(_entropy()).balance == 0, "invalid funding also reverted");
        _entropy().configure(true, 0, 7, 0);
        vm.prank(payer);
        nativeSale.purchase{ value: 1007 }(e);
        require(manager.nonce() == 1, "same proof succeeds after correction");
    }

    function testReceiverFeeMutationKeepsPreMintQuoteAndProviderCannotReenterRefund() public {
        _entropy().configure(true, 0, 7, 0);
        NativeSettlementReceiver recipient = new NativeSettlementReceiver();
        recipient.configure(
            false,
            address(_entropy()),
            abi.encodeCall(_entropy().configure, (true, uint8(0), uint256(99), uint8(0))),
            wallet
        );
        _entropy()
            .configureCallback(
                address(nativeSale), abi.encodeCall(nativeSale.claimRefund, (nativeId, payer))
            );
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, address(recipient), 1);
        vm.prank(payer);
        nativeSale.purchase{ value: 1010 }(e);
        require(
            recipient.callbackSucceeded() && !_entropy().callbackSucceeded(),
            "receiver can retune test policy; provider cannot enter adapter"
        );
        require(
            keccak256(_entropy().callbackReason())
                == keccak256(
                    abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
                ),
            "actual adapter reentrancy guard"
        );
        require(
            _entropy().revealFeeEscrow(1) == 7
                && nativeSale.refundableBalance(nativeId, payer) == 3,
            "captured quote governs this transaction"
        );
        require(
            nativeSale.saleRevealQuote(nativeId).policy.revealFeePerTokenWei == 99,
            "next mint sees live retune"
        );
    }

    function executeImmediateRefundSafe(
        OfficialSafe safe,
        uint256[] calldata keys,
        address recipient
    ) external returns (bool) {
        require(msg.sender == address(this), "fixture caller");
        return executeSafe(
            safe,
            keys,
            address(nativeSale),
            0,
            abi.encodeCall(nativeSale.claimRefund, (nativeId, recipient)),
            0
        );
    }

    function testActualSafeOwnsRefundAndCanRetryRejectedDestinationWhilePaused() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 797);
        vm.deal(address(safe), 1 ether);
        _entropy().configure(true, 1, 7, 0);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(address(safe), address(safe), 1);
        require(
            executeSafe(
                safe, keys, address(nativeSale), 1020, abi.encodeCall(nativeSale.purchase, (e)), 0
            ),
            "real Safe purchase"
        );
        ImmediateRefundRejector rejector = new ImmediateRefundRejector();
        (bool stolen,) = address(nativeSale)
            .call(abi.encodeCall(nativeSale.claimRefund, (nativeId, address(this))));
        require(!stolen, "only payer can withdraw");
        uint256 nonceBefore = safe.nonce();
        (bool refunded, bytes memory reason) = address(this)
            .call(abi.encodeCall(this.executeImmediateRefundSafe, (safe, keys, address(rejector))));
        require(
            !refunded
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual Safe failure boundary"
        );
        require(safe.nonce() == nonceBefore, "failed Safe transaction preserves nonce");
        require(
            nativeSale.refundableBalance(nativeId, address(safe)) == 13
                && nativeSale.refundLiability() == 13,
            "claim restored"
        );
        nativeSale.setPaused(true);
        require(
            executeSafe(
                safe,
                keys,
                address(nativeSale),
                0,
                abi.encodeCall(nativeSale.claimRefund, (nativeId, address(safe))),
                0
            ),
            "Safe retries while paused"
        );
        require(
            address(safe).balance == 1 ether - 1007 && nativeSale.refundLiability() == 0
                && address(nativeSale).balance == 0,
            "Safe net price plus fee"
        );
        require(
            nativeSale.refundAccountCount() == 1
                && nativeSale.refundableBalance(nativeId, address(safe)) == 0,
            "discovery retained after withdrawal"
        );
    }
}
