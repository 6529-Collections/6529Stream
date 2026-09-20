// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/UniversalSettlementTestBase.sol";

interface UniversalRevealVm {
    function expectCall(address target, uint256 value, bytes calldata input, uint64 count) external;
}
contract UniversalRefundReceiver {
    bool public rejecting = true;
    function accept() external { rejecting = false; }
    receive() external payable { require(!rejecting, "refund rejected"); }
}

/// @dev Actual Safe/payment/recorder/Permit2; Core/Manager/Artist/entropy are explicit typed fixtures.
contract StreamUniversalRevealTest is UniversalSettlementTestBase {
    UniversalRevealVm private constant check =
        UniversalRevealVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    function _entropy() private view returns (ImmediateRevealFixture) {
        return ImmediateRevealFixture(core.entropy());
    }
    function _buy(uint256 n, uint256 value) private returns (bytes32 key) {
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
         StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) =
            _execution(payer, payer, payer, n);
        vm.prank(payer);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleByPayer{value: value}(c, abi.encode(e));
        require(r.amount == 1000 && r.asset == address(token) && r.executor == payer, "token receipt units");
        return r.settlementKey;
    }
    function _call(uint256 n) private returns (bytes memory callData) {
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
         StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) =
            _execution(payer, payer, payer, n);
        return abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, abi.encode(e)));
    }
    function _safeCall(OfficialSafe account, uint256[] memory keys, address target, uint256 value, bytes memory input)
        private returns (bytes memory)
    {
        bytes32 digest = account.getTransactionHash(target, value, input, 0, 0, 0, 0,
            address(0), address(0), account.nonce());
        return abi.encodeCall(OfficialSafe.execTransaction, (target, value, input, uint8(0),
            uint256(0), uint256(0), uint256(0), address(0), payable(address(0)),
            safeThresholdSignature(keys, digest)));
    }

    function testZeroFeeOwnerWindowAndAtMintKeepOriginalTokenUnits() public {
        _buy(1, 0);
        require(_entropy().requests() == 0 && sale.refundLiability() == 0, "owner-window zero fee");
        _entropy().configure(true, 0, 0, 0);
        _buy(2, 0);
        require(_entropy().requests() == 1 && _entropy().lastRequestedToken() == 2, "zero-fee AT_MINT");
        require(token.balanceOf(payer) == 8000 && token.balanceOf(wallet) == 2000
            && recorder.totalOfficialSettled(address(token)) == 2000, "only token revenue");
    }

    function testTwoSafesIntentTokenPayerDiffersFromNativeExecutorAndExactLateRetry() public {
        uint256[] memory payerKeys = new uint256[](2); payerKeys[0] = 0x171; payerKeys[1] = 0x172;
        uint256[] memory executorKeys = new uint256[](2); executorKeys[0] = 0x181; executorKeys[1] = 0x182;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        OfficialSafe tokenPayer = createOfficialSafe(components, safeOwnerAddresses(payerKeys), 2, 901);
        OfficialSafe executor = createOfficialSafe(components, safeOwnerAddresses(executorKeys), 2, 902);
        token.mint(address(tokenPayer), 1000);
        require(executeSafe(tokenPayer, payerKeys, address(token), 0,
            abi.encodeCall(token.approve, (address(payment), uint256(1000))), 0), "payer allowance");
        vm.deal(address(executor), 175);
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
         StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) =
            _execution(address(tokenPayer), address(executor), address(tokenPayer), 1);
        StreamPrimarySettlementTypes.PaymentIntent memory intent = StreamPrimarySettlementTypes.PaymentIntent(
            address(tokenPayer), address(token), 1000, saleId, _primaryPolicy(), keccak256("native separate"), 9000);
        bytes memory proof = safeThresholdSignature(payerKeys,
            safeMessageDigest(tokenPayer, abi.encode(payment.paymentIntentDigest(intent))));
        bytes memory inner = abi.encodeCall(payment.settleERC20PrimarySaleWithIntent, (c, intent, proof, abi.encode(e)));
        bytes memory exact = _safeCall(executor, executorKeys, address(payment), 175, inner);
        ImmediateRevealFixture entropy = _entropy();
        entropy.configure(true, 0, 100, 5); // Accept ETH but falsify the escrow delta after token funding/mint.
        check.expectCall(address(entropy), 100,
            abi.encodeCall(IStreamRevealFeeEscrow.fundRevealFeeEscrow, (uint256(1))), 2);
        check.expectCall(address(token), 0, abi.encodeCall(token.transfer, (wallet, uint256(1000))), 2);
        (bool ok,) = address(executor).call(exact);
        require(!ok && executor.nonce() == 0 && tokenPayer.nonce() == 1, "both Safe nonces retained");
        require(token.balanceOf(address(tokenPayer)) == 1000 && token.balanceOf(wallet) == 0
            && token.allowance(address(tokenPayer), address(payment)) == 1000, "token rollback");
        require(!payment.isPaymentIntentNonceUsed(address(tokenPayer), intent.nonce)
            && sale.executionIdByNonce(saleId, 1) == 0 && recorder.totalOfficialSettled(address(token)) == 0,
            "intent, sale and official revenue rollback");
        require(address(executor).balance == 175 && address(payment).balance == 0
            && address(sale).balance == 0 && sale.refundLiability() == 0 && entropy.revealFeeEscrow(1) == 0,
            "all native balances rollback");
        entropy.configure(true, 0, 100, 0);
        (ok,) = address(executor).call(exact);
        require(ok && executor.nonce() == 1 && tokenPayer.nonce() == 1, "byte-identical Safe retry");
        require(token.balanceOf(address(tokenPayer)) == 0 && token.balanceOf(wallet) == 1000
            && recorder.totalOfficialSettled(address(token)) == 1000, "maxAmount stays 1000 tokens");
        require(entropy.revealFeeEscrow(1) == 100 && entropy.requests() == 1
            && sale.refundableBalance(saleId, address(executor)) == 75
            && sale.refundableBalance(saleId, address(tokenPayer)) == 0 && sale.refundLiability() == 75,
            "native executor owns all excess");
        bytes memory wrongClaim = _safeCall(tokenPayer, payerKeys, address(sale), 0,
            abi.encodeCall(sale.claimRefund, (saleId, address(tokenPayer))));
        (ok,) = address(tokenPayer).call(wrongClaim);
        require(!ok && tokenPayer.nonce() == 1, "token payer cannot claim native credit");
        require(executeSafe(executor, executorKeys, address(sale), 0,
            abi.encodeCall(sale.claimRefund, (saleId, address(executor))), 0), "executor Safe refund");
        require(address(executor).balance == 75 && sale.refundLiability() == 0, "native pull accounting");
        (bytes32 id, address account) = sale.refundAccountAt(0);
        require(sale.refundAccountCount() == 1 && id == saleId && account == address(executor), "retained inventory");
        (ok,) = address(executor).call(exact);
        require(!ok && recorder.totalOfficialSettled(address(token)) == 1000, "obsolete Safe envelope cannot replay");
        // Fund the executor and sign the same inner payment at its current Safe nonce.
        // The direct boundary probe identifies the target error hidden by the Safe's GS013.
        vm.deal(address(executor), 175);
        vm.prank(address(executor));
        (ok, proof) = address(payment).call{value: 175}(inner);
        require(!ok && keccak256(proof) == keccak256(abi.encodeWithSelector(
            StreamERC20PrimarySettlementAdapter.PaymentIntentNonceUsed.selector,
            address(tokenPayer), intent.nonce)), "original payment intent nonce rejects replay");
        exact = _safeCall(executor, executorKeys, address(payment), 175, inner);
        uint256 currentNonce = executor.nonce();
        (ok, proof) = address(executor).call(exact);
        require(!ok && keccak256(proof) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
            && executor.nonce() == currentNonce && tokenPayer.nonce() == 1
            && address(executor).balance == 175 && address(payment).balance == 0
            && address(sale).balance == 0 && sale.refundLiability() == 0
            && entropy.revealFeeEscrow(1) == 100 && entropy.requests() == 1
            && token.balanceOf(wallet) == 1000 && recorder.totalOfficialSettled(address(token)) == 1000,
            "fresh funded Safe envelope reaches refused payment without repeating token or native effects");
    }

    function testLiveFeeDriftRejectsBeforeTokenPullThenSameCallRetries() public {
        vm.deal(payer, 125);
        _entropy().configure(true, 0, 100, 0);
        require(sale.saleRevealQuote(saleId).policy.revealFeePerTokenWei == 100, "initial quote");
        bytes memory exact = _call(1);
        // Hostile at the first payer-to-payment transfer; balance/signature reads still work.
        token.configure(address(payment), 1);
        // Across the underfunded call and healthy retry, only the retry may reach token funding.
        check.expectCall(address(token), 0,
            abi.encodeCall(token.transferFrom, (payer, address(payment), uint256(1000))), 1);
        _entropy().configure(true, 0, 126, 0);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(payment).call{value: 125}(exact);
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(
            StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector)), "callback rejection");
        require(token.balanceOf(payer) == 10000 && payer.balance == 125
            && token.allowance(payer, address(payment)) == 10000
            && sale.executionIdByNonce(saleId, 1) == 0, "insufficient allowance atomic");
        token.configure(address(payment), 0);
        _entropy().configure(true, 0, 100, 0);
        vm.prank(payer);
        (ok,) = address(payment).call{value: 125}(exact);
        require(ok && sale.refundableBalance(saleId, payer) == 25
            && sale.refundLiability() == 25 && address(sale).balance == 25
            && address(payment).balance == 0 && _entropy().revealFeeEscrow(1) == 100
            && token.balanceOf(wallet) == 1000 && recorder.totalOfficialSettled(address(token)) == 1000,
            "identical signed bytes; exact separate token and wei accounting");
    }

    /// @dev Isolates the authenticated callback to observe the preflight error that payment wraps.
    /// This is a boundary oracle, not a substitute for the complete payment/retry test above.
    function testUnderfundedAuthenticatedCallbackReturnsExactPreflightError() public {
        _entropy().configure(true, 0, 126, 0);
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
         StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) =
            _execution(payer, payer, payer, 1);
        token.configure(address(payment), 1);
        vm.deal(address(payment), 125);
        vm.expectRevert(abi.encodeWithSelector(
            IStreamImmediateSaleReveal.SaleRevealFeeBelowRequired.selector, uint256(125), uint256(126)));
        vm.prank(address(payment));
        sale.executeERC20PreRevenueSingleStep{value: 125}(c, abi.encode(e));
        require(sale.executionIdByNonce(saleId, 1) == 0 && sale.refundLiability() == 0
            && token.balanceOf(payer) == 10000, "preflight before sale replay or funding");
    }

    function testSufficientAllowanceReachesHostileTokenPullThenSameCallRetries() public {
        vm.deal(payer, 125);
        _entropy().configure(true, 0, 100, 0);
        bytes memory exact = _call(1);
        token.configure(address(payment), 1);
        // The armed-token failure and repaired retry must both reach the actual transferFrom.
        check.expectCall(address(token), 0,
            abi.encodeCall(token.transferFrom, (payer, address(payment), uint256(1000))), 2);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(payment).call{value: 125}(exact);
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(
            StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector)), "hostile pull rejected");
        require(token.balanceOf(payer) == 10000 && token.allowance(payer, address(payment)) == 10000
            && payer.balance == 125 && sale.executionIdByNonce(saleId, 1) == 0
            && sale.refundLiability() == 0, "late token failure atomic");
        token.configure(address(payment), 0);
        vm.prank(payer);
        (ok,) = address(payment).call{value: 125}(exact);
        require(ok && token.balanceOf(wallet) == 1000 && sale.refundableBalance(saleId, payer) == 25,
            "identical healthy retry reaches the same funding boundary");
    }

    function testProviderFailuresAreBoundedAndNeverUndoPaidMint() public {
        vm.deal(payer, 500);
        for (uint8 fault = 1; fault <= 4; ++fault) {
            _entropy().configure(true, 0, 100, fault);
            vm.recordLogs(); _buy(fault, 125); Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 count;
            for (uint256 i; i < logs.length; ++i) {
                if (logs[i].emitter != address(sale) || logs[i].topics[0] != keccak256(
                    "ImmediateRevealAttempt(uint16,uint256,uint256,bool,bytes32,uint256,uint256,bytes)")) continue;
                ++count;
                (uint16 schema, bool success, bytes32 key, uint256 request, uint256 size, bytes memory prefix) =
                    abi.decode(logs[i].data, (uint16,bool,bytes32,uint256,uint256,bytes));
                require(schema == 1 && !success && key == 0 && request == 0 && prefix.length <= 256,
                    "failure result and bounded prefix");
                require(logs[i].topics.length == 3 && logs[i].topics[1] == bytes32(uint256(1))
                    && logs[i].topics[2] == bytes32(uint256(fault)), "actual minted token event");
                if (fault == 2) require(size == 16384 && prefix.length == 256, "large revert bounded");
            }
            require(count == 1 && manager.ownerOf(fault) == payer, "one failure attempt after surviving mint");
        }
        require(token.balanceOf(wallet) == 4000 && recorder.totalOfficialSettled(address(token)) == 4000
            && _entropy().revealFeeEscrow(1) == 400 && sale.refundLiability() == 100,
            "provider failures preserve separate revenue fee and refund");
    }

    function testCapturedFeeSurvivesTokenCallbackAndProviderReentryIsBlocked() public {
        vm.deal(payer, 125);
        ImmediateRevealFixture entropy = _entropy(); entropy.configure(true, 0, 100, 0);
        bytes memory exact = _call(1);
        token.setCallback(address(entropy), abi.encodeCall(entropy.configure, (true, uint8(0), uint256(999), uint8(0))));
        entropy.configureCallback(address(payment), exact);
        vm.prank(payer); (bool ok,) = address(payment).call{value: 125}(exact);
        require(ok && token.callbackSuccess() && !entropy.callbackSucceeded(), "state callback and blocked payment reentry");
        require(keccak256(entropy.callbackReason()) == keccak256(
            abi.encodeWithSelector(StreamERC20PrimarySettlementAdapter.PaymentOperationActive.selector)), "exact reentry refusal");
        require(entropy.revealFeeEscrow(1) == 100 && sale.refundableBalance(saleId, payer) == 25
            && sale.saleRevealQuote(saleId).policy.revealFeePerTokenWei == 999, "fee captured before token calls");
    }

    function testProviderPointerDriftRollsBackThenIdenticalCallRetries() public {
        vm.deal(payer, 125); ImmediateRevealFixture entropy = _entropy();
        entropy.configure(true, 0, 100, 0);
        ImmediateRevealFixture replacement = new ImmediateRevealFixture(address(core));
        entropy.configureCallback(address(core), abi.encodeCall(core.setEntropy, (address(replacement))));
        bytes memory exact = _call(1);
        check.expectCall(address(entropy), 0, abi.encodeCall(IStreamEntropyCoordinator.requestEntropy, (uint256(1))), 2);
        vm.prank(payer); (bool ok,) = address(payment).call{value: 125}(exact);
        require(!ok && core.entropy() == address(entropy) && token.balanceOf(wallet) == 0
            && payer.balance == 125 && entropy.revealFeeEscrow(1) == 0 && sale.refundLiability() == 0,
            "post-request pointer drift rolls back whole graph");
        entropy.configureCallback(address(0), "");
        vm.prank(payer); (ok,) = address(payment).call{value: 125}(exact);
        require(ok && token.balanceOf(wallet) == 1000 && sale.refundLiability() == 25, "exact authorized call retry");
    }

    function testRefundEscapesPauseRetirementAndFailedRecipientPreservingSurplus() public {
        vm.deal(payer, 125); vm.deal(address(payment), 17); vm.deal(address(sale), 23);
        _entropy().configure(true, 1, 100, 0); _buy(1, 125);
        require(address(payment).balance == 17 && address(sale).balance == 48 && sale.refundLiability() == 25,
            "passive native surplus not charged");
        sale.setPaused(true); sale.cancelSale(saleId); _status(address(sale), ModuleRegistryStatus.INCIDENT_REVOKED);
        UniversalRefundReceiver recipient = new UniversalRefundReceiver();
        bytes memory exact = abi.encodeCall(sale.claimRefund, (saleId, address(recipient)));
        vm.prank(payer); (bool ok,) = address(sale).call(exact);
        require(!ok && sale.refundLiability() == 25 && sale.refundableBalance(saleId, payer) == 25, "failed recipient retains credit");
        recipient.accept();
        vm.prank(payer); (ok,) = address(sale).call(exact);
        require(ok && address(recipient).balance == 25 && address(sale).balance == 23
            && sale.refundLiability() == 0 && sale.refundAccountCount() == 1, "escape independent of retired sale admission");
    }
}
