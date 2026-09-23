// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/UniversalAllowlistPriceFixture.sol";

interface PriceRevealVm {
    function expectCall(address target, uint256 value, bytes calldata input, uint64 count) external;
}
contract PriceRefundReceiver {
    bool public rejecting = true;
    function accept() external { rejecting = false; }
    receive() external payable { require(!rejecting, "refund rejected"); }
}

/// @dev Actual Safe/payment/recorder/Permit2; Core/Manager/Artist/entropy are explicit typed fixtures.
contract StreamUniversalAllowlistRevealTest is UniversalAllowlistPriceFixture {
    PriceRevealVm private constant check =
        PriceRevealVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    function _priceExecution(address who,address executor,address recipient,uint256 n)
        private returns(IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
    {
        e=_e(who,executor,recipient,n); (c,)=priceSale.previewAllowlistExecution(e,proofData);
    }
    function _entropy() private view returns (ImmediateRevealFixture) {
        return ImmediateRevealFixture(core.entropy());
    }
    function _buy(uint256 n, uint256 value) private returns (bytes32 key) {
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
         StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) =
            _priceExecution(payer, payer, payer, n);
        bytes memory data = StreamUniversalAllowlistPrice.encode(e,c.sale.amount,proofData);
        vm.prank(payer);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleByPayer{value: value}(c, data);
        require(r.amount == 375 && r.asset == address(token) && r.executor == payer, "token receipt units");
        return r.settlementKey;
    }
    function _call(uint256 n) private returns (bytes memory callData) {
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
         StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) =
            _priceExecution(payer, payer, payer, n);
        return abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, StreamUniversalAllowlistPrice.encode(e,c.sale.amount,proofData)));
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
        require(_entropy().requests() == 0 && priceSale.refundLiability() == 0, "owner-window zero fee");
        _entropy().configure(true, 0, 0, 0);
        _buy(2, 0);
        require(_entropy().requests() == 1 && _entropy().lastRequestedToken() == 2, "zero-fee AT_MINT");
        require(token.balanceOf(payer) == 9250 && token.balanceOf(wallet) == 750
            && recorder.totalOfficialSettled(address(token)) == 750, "only token revenue");
    }

    function testTwoSafesIntentTokenPayerDiffersFromNativeExecutorAndExactLateRetry() public {
        uint256[] memory payerKeys = new uint256[](2); payerKeys[0] = 0x171; payerKeys[1] = 0x172;
        uint256[] memory executorKeys = new uint256[](2); executorKeys[0] = 0x181; executorKeys[1] = 0x182;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        OfficialSafe tokenPayer = createOfficialSafe(components, safeOwnerAddresses(payerKeys), 2, 901);
        OfficialSafe executor = createOfficialSafe(components, safeOwnerAddresses(executorKeys), 2, 902);
        token.mint(address(tokenPayer), 375);
        require(executeSafe(tokenPayer, payerKeys, address(token), 0,
            abi.encodeCall(token.approve, (address(payment), uint256(375))), 0), "payer allowance");
        vm.deal(address(executor), 175);
        _bind(address(tokenPayer),IStreamMintManager.CounterKeyMode.PAYER,true,375);
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
         StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) =
            _priceExecution(address(tokenPayer), address(executor), address(tokenPayer), 1);
        StreamPrimarySettlementTypes.PaymentIntent memory intent = StreamPrimarySettlementTypes.PaymentIntent(
            address(tokenPayer), address(token), 375, saleId, _primaryPolicy(), keccak256("native separate"), 9000);
        bytes memory proof = safeThresholdSignature(payerKeys,
            safeMessageDigest(tokenPayer, abi.encode(payment.paymentIntentDigest(intent))));
        bytes memory inner = abi.encodeCall(payment.settleERC20PrimarySaleWithIntent, (c, intent, proof, StreamUniversalAllowlistPrice.encode(e,c.sale.amount,proofData)));
        bytes memory exact = _safeCall(executor, executorKeys, address(payment), 175, inner);
        ImmediateRevealFixture entropy = _entropy();
        entropy.configure(true, 0, 100, 5); // Accept ETH but falsify the escrow delta after token funding/mint.
        check.expectCall(address(entropy), 100,
            abi.encodeCall(IStreamRevealFeeEscrow.fundRevealFeeEscrow, (uint256(1))), 2);
        check.expectCall(address(token), 0, abi.encodeCall(token.transfer, (wallet, uint256(375))), 2);
        (bool ok,) = address(executor).call(exact);
        require(!ok && executor.nonce() == 0 && tokenPayer.nonce() == 1, "both Safe nonces retained");
        require(token.balanceOf(address(tokenPayer)) == 375 && token.balanceOf(wallet) == 0
            && token.allowance(address(tokenPayer), address(payment)) == 375, "token rollback");
        require(!payment.isPaymentIntentNonceUsed(address(tokenPayer), intent.nonce)
            && priceSale.executionIdByNonce(saleId, 1) == 0 && recorder.totalOfficialSettled(address(token)) == 0,
            "intent, priceSale and official revenue rollback");
        require(address(executor).balance == 175 && address(payment).balance == 0
            && address(priceSale).balance == 0 && priceSale.refundLiability() == 0 && entropy.revealFeeEscrow(1) == 0,
            "all native balances rollback");
        entropy.configure(true, 0, 100, 0);
        (ok,) = address(executor).call(exact);
        require(ok && executor.nonce() == 1 && tokenPayer.nonce() == 1, "byte-identical Safe retry");
        require(token.balanceOf(address(tokenPayer)) == 0 && token.balanceOf(wallet) == 375
            && recorder.totalOfficialSettled(address(token)) == 375, "maxAmount stays 375 tokens");
        require(entropy.revealFeeEscrow(1) == 100 && entropy.requests() == 1
            && priceSale.refundableBalance(saleId, address(executor)) == 75
            && priceSale.refundableBalance(saleId, address(tokenPayer)) == 0 && priceSale.refundLiability() == 75,
            "native executor owns all excess");
        bytes memory wrongClaim = _safeCall(tokenPayer, payerKeys, address(priceSale), 0,
            abi.encodeCall(priceSale.claimRefund, (saleId, address(tokenPayer))));
        (ok,) = address(tokenPayer).call(wrongClaim);
        require(!ok && tokenPayer.nonce() == 1, "token payer cannot claim native credit");
        require(executeSafe(executor, executorKeys, address(priceSale), 0,
            abi.encodeCall(priceSale.claimRefund, (saleId, address(executor))), 0), "executor Safe refund");
        require(address(executor).balance == 75 && priceSale.refundLiability() == 0, "native pull accounting");
        (bytes32 id, address account) = priceSale.refundAccountAt(0);
        require(priceSale.refundAccountCount() == 1 && id == saleId && account == address(executor), "retained inventory");
        (ok,) = address(executor).call(exact);
        require(!ok && recorder.totalOfficialSettled(address(token)) == 375, "obsolete Safe envelope cannot replay");
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
            && address(priceSale).balance == 0 && priceSale.refundLiability() == 0
            && entropy.revealFeeEscrow(1) == 100 && entropy.requests() == 1
            && token.balanceOf(wallet) == 375 && recorder.totalOfficialSettled(address(token)) == 375,
            "fresh funded Safe envelope reaches refused payment without repeating token or native effects");
    }

    function testLiveFeeDriftRejectsBeforeTokenPullThenSameCallRetries() public {
        vm.deal(payer, 125);
        _entropy().configure(true, 0, 100, 0);
        require(priceSale.saleRevealQuote(saleId).policy.revealFeePerTokenWei == 100, "initial quote");
        bytes memory exact = _call(1);
        // Hostile at the first payer-to-payment transfer; balance/signature reads still work.
        token.configure(address(payment), 1);
        // Across the underfunded call and healthy retry, only the retry may reach token funding.
        check.expectCall(address(token), 0,
            abi.encodeCall(token.transferFrom, (payer, address(payment), uint256(375))), 1);
        _entropy().configure(true, 0, 126, 0);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(payment).call{value: 125}(exact);
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(
            StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector)), "callback rejection");
        require(token.balanceOf(payer) == 10000 && payer.balance == 125
            && token.allowance(payer, address(payment)) == 10000
            && priceSale.executionIdByNonce(saleId, 1) == 0, "insufficient allowance atomic");
        token.configure(address(payment), 0);
        _entropy().configure(true, 0, 100, 0);
        vm.prank(payer);
        (ok,) = address(payment).call{value: 125}(exact);
        require(ok && priceSale.refundableBalance(saleId, payer) == 25
            && priceSale.refundLiability() == 25 && address(priceSale).balance == 25
            && address(payment).balance == 0 && _entropy().revealFeeEscrow(1) == 100
            && token.balanceOf(wallet) == 375 && recorder.totalOfficialSettled(address(token)) == 375,
            "identical signed bytes; exact separate token and wei accounting");
    }

    /// @dev Isolates the authenticated callback to observe the preflight error that payment wraps.
    /// This is a boundary oracle, not a substitute for the complete payment/retry test above.
    function testUnderfundedAuthenticatedCallbackReturnsExactPreflightError() public {
        _entropy().configure(true, 0, 126, 0);
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
         StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) =
            _priceExecution(payer, payer, payer, 1);
        token.configure(address(payment), 1);
        vm.deal(address(payment), 125);
        bytes memory data = StreamUniversalAllowlistPrice.encode(e,c.sale.amount,proofData);
        vm.expectRevert(abi.encodeWithSelector(
            IStreamImmediateSaleReveal.SaleRevealFeeBelowRequired.selector, uint256(125), uint256(126)));
        vm.prank(address(payment));
        priceSale.executeERC20PreRevenueSingleStep{value: 125}(c, data);
        require(priceSale.executionIdByNonce(saleId, 1) == 0 && priceSale.refundLiability() == 0
            && token.balanceOf(payer) == 10000, "preflight before priceSale replay or funding");
    }

    function testSufficientAllowanceReachesHostileTokenPullThenSameCallRetries() public {
        vm.deal(payer, 125);
        _entropy().configure(true, 0, 100, 0);
        bytes memory exact = _call(1);
        token.configure(address(payment), 1);
        // The armed-token failure and repaired retry must both reach the actual transferFrom.
        check.expectCall(address(token), 0,
            abi.encodeCall(token.transferFrom, (payer, address(payment), uint256(375))), 2);
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(payment).call{value: 125}(exact);
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(
            StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector)), "hostile pull rejected");
        require(token.balanceOf(payer) == 10000 && token.allowance(payer, address(payment)) == 10000
            && payer.balance == 125 && priceSale.executionIdByNonce(saleId, 1) == 0
            && priceSale.refundLiability() == 0, "late token failure atomic");
        token.configure(address(payment), 0);
        vm.prank(payer);
        (ok,) = address(payment).call{value: 125}(exact);
        require(ok && token.balanceOf(wallet) == 375 && priceSale.refundableBalance(saleId, payer) == 25,
            "identical healthy retry reaches the same funding boundary");
    }

    function testProviderFailuresAreBoundedAndNeverUndoPaidMint() public {
        vm.deal(payer, 500);
        for (uint8 fault = 1; fault <= 4; ++fault) {
            _entropy().configure(true, 0, 100, fault);
            vm.recordLogs(); _buy(fault, 125); Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 count;
            for (uint256 i; i < logs.length; ++i) {
                if (logs[i].emitter != address(priceSale) || logs[i].topics[0] != keccak256(
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
        require(token.balanceOf(wallet) == 1500 && recorder.totalOfficialSettled(address(token)) == 1500
            && _entropy().revealFeeEscrow(1) == 400 && priceSale.refundLiability() == 100,
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
        require(entropy.revealFeeEscrow(1) == 100 && priceSale.refundableBalance(saleId, payer) == 25
            && priceSale.saleRevealQuote(saleId).policy.revealFeePerTokenWei == 999, "fee captured before token calls");
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
            && payer.balance == 125 && entropy.revealFeeEscrow(1) == 0 && priceSale.refundLiability() == 0,
            "post-request pointer drift rolls back whole graph");
        entropy.configureCallback(address(0), "");
        vm.prank(payer); (ok,) = address(payment).call{value: 125}(exact);
        require(ok && token.balanceOf(wallet) == 375 && priceSale.refundLiability() == 25, "exact authorized call retry");
    }

    function testRefundEscapesPauseRetirementAndFailedRecipientPreservingSurplus() public {
        vm.deal(payer, 125); vm.deal(address(payment), 17); vm.deal(address(priceSale), 23);
        _entropy().configure(true, 1, 100, 0); _buy(1, 125);
        require(address(payment).balance == 17 && address(priceSale).balance == 48 && priceSale.refundLiability() == 25,
            "passive native surplus not charged");
        priceSale.setPaused(true); priceSale.cancelSale(saleId); _status(address(priceSale), ModuleRegistryStatus.INCIDENT_REVOKED);
        PriceRefundReceiver recipient = new PriceRefundReceiver();
        bytes memory exact = abi.encodeCall(priceSale.claimRefund, (saleId, address(recipient)));
        vm.prank(payer); (bool ok,) = address(priceSale).call(exact);
        require(!ok && priceSale.refundLiability() == 25 && priceSale.refundableBalance(saleId, payer) == 25, "failed recipient retains credit");
        recipient.accept();
        vm.prank(payer); (ok,) = address(priceSale).call(exact);
        require(ok && address(recipient).balance == 25 && address(priceSale).balance == 23
            && priceSale.refundLiability() == 0 && priceSale.refundAccountCount() == 1, "escape independent of retired priceSale admission");
    }

    function testDeclaredFreeTierFundsNativeFeeAndCreditsOnlyExecutor() public {
        _bind(payer,IStreamMintManager.CounterKeyMode.PAYER,true,0); _registerPrice(true);
        ImmediateRevealFixture entropy=_entropy(); entropy.configure(true,1,100,0);
        address executor=address(0xE0); vm.deal(executor,175);
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,executor,payer,1);
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,bytes memory data)=priceSale.previewAllowlistExecution(e,proofData);
        require(c.sale.amount==0 && priceSale.saleRevealQuote(saleId).policy.revealFeePerTokenWei==100 &&
            keccak256(abi.encode(priceSale.saleRevealQuote(saleId)))==keccak256(abi.encode(priceSale.allowlistRevealQuote(saleId))),"tier and wei quotes are independent");
        require(priceSale.supportsInterface(type(IStreamImmediateSaleReveal).interfaceId),"existing native-credit capability");
        // Use a valid payer/executor identity so only the zero ERC20 amount rejects payment.
        {
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory paidExecution=_e(payer,payer,payer,1);
            (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory paidCandidate,bytes memory paidData)=
                priceSale.previewAllowlistExecution(paidExecution,proofData);
            require(paidCandidate.sale.amount==0 && paidCandidate.executor==payer && paidCandidate.sale.payer==payer,
                "zero-tier candidate has valid payer authority");
            vm.deal(payer,175);
            check.expectCall(address(token),0,abi.encodeWithSelector(token.transferFrom.selector),0);
            vm.recordLogs(); vm.prank(payer);
            (bool paid,bytes memory reason)=address(payment).call{value:175}(
                abi.encodeCall(payment.settleERC20PrimarySaleByPayer,(paidCandidate,paidData)));
            require(!paid && keccak256(reason)==keccak256(abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.InvalidPaymentCandidate.selector)),"exact zero-amount payment refusal");
            require(vm.getRecordedLogs().length==0 && manager.nonce()==0 && manager.ownerOf(1)==address(0)
                && priceSale.executionIdByNonce(saleId,1)==0 && priceSale.refundLiability()==0
                && priceSale.refundAccountCount()==0 && entropy.revealFeeEscrow(1)==0 && entropy.requests()==0,
                "refused paid route has no mint, replay, official or reveal effects");
            require(payer.balance==175 && executor.balance==175 && address(payment).balance==0
                && address(priceSale).balance==0 && token.balanceOf(payer)==10000
                && token.balanceOf(address(payment))==0 && token.balanceOf(address(recorder))==0
                && token.balanceOf(wallet)==0 && token.allowance(payer,address(payment))==10000
                && recorder.totalOfficialSettled(address(token))==0,"no native loss or token pull");
        }
        vm.recordLogs(); vm.prank(executor);
        (uint256 id,bytes32 root,bytes32 execution)=priceSale.executeAllowlistFreeMint{value:175}(e,proofData);
        Vm.Log[] memory logs=vm.getRecordedLogs();
        for(uint256 i;i<logs.length;++i) require(logs[i].emitter!=address(payment) && logs[i].emitter!=address(recorder),"no zero-value official settlement");
        require(id==1 && root==c.operationIdentityCommitment && execution==c.executionBinding.executionId && manager.ownerOf(id)==payer,"original free mint identity");
        require(token.balanceOf(payer)==10000 && token.balanceOf(wallet)==0 && token.allowance(payer,address(payment))==10000 && recorder.totalOfficialSettled(address(token))==0,"no ERC20 effect");
        require(entropy.revealFeeEscrow(1)==100 && entropy.requests()==0 && executor.balance==0 && address(priceSale).balance==75 && priceSale.refundLiability()==75,"captured native fee plus excess");
        require(priceSale.refundableBalance(saleId,executor)==75 && priceSale.refundableBalance(saleId,payer)==0,"executor owns credit independent of payer");
        vm.expectRevert(); vm.prank(payer); priceSale.claimRefund(saleId,payer);
        vm.prank(executor); priceSale.claimRefund(saleId,executor);
        require(executor.balance==75 && priceSale.refundLiability()==0,"free executor can escape credit");
    }

    function testFreeUnderfundedRefusesBeforeReplayAndSameBytesRetry() public {
        _bind(payer,IStreamMintManager.CounterKeyMode.PAYER,true,0); _registerPrice(true);
        _entropy().configure(true,0,126,0); vm.deal(payer,125);
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        bytes memory exact=abi.encodeCall(priceSale.executeAllowlistFreeMint,(e,proofData));
        vm.prank(payer); (bool ok,bytes memory reason)=address(priceSale).call{value:125}(exact);
        require(!ok && keccak256(reason)==keccak256(abi.encodeWithSelector(IStreamImmediateSaleReveal.SaleRevealFeeBelowRequired.selector,uint256(125),uint256(126))),"exact native preflight refusal");
        _unused(); require(payer.balance==125 && priceSale.refundLiability()==0 && _entropy().revealFeeEscrow(1)==0,"all wei retained");
        _entropy().configure(true,0,100,0);
        vm.prank(payer); (ok,)=address(priceSale).call{value:125}(exact);
        require(ok && manager.nonce()==1 && _entropy().requests()==1 && priceSale.refundLiability()==25 && recorder.totalOfficialSettled(address(token))==0,"identical free input succeeds once");
    }

    function testFreeLateFundingFailureReachesReceiverThenRestoresAllState() public {
        _bind(payer,IStreamMintManager.CounterKeyMode.PAYER,true,0); _registerPrice(true);
        ImmediateRevealFixture entropy=_entropy(); entropy.configure(true,0,100,5); vm.deal(payer,125);
        PriceMintReceiver recipient=new PriceMintReceiver();
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,address(recipient),1);
        bytes memory exact=abi.encodeCall(priceSale.executeAllowlistFreeMint,(e,proofData));
        check.expectCall(address(recipient),0,abi.encodeCall(IERC721Receiver.onERC721Received,(address(priceSale),address(0),uint256(1),bytes(""))),2);
        check.expectCall(address(entropy),100,abi.encodeCall(IStreamRevealFeeEscrow.fundRevealFeeEscrow,(uint256(1))),2);
        vm.prank(payer); (bool ok,)=address(priceSale).call{value:125}(exact);
        require(!ok,"escrow delta mismatch must undo minted receiver callback"); _unused();
        require(payer.balance==125 && manager.ownerOf(1)==address(0) && priceSale.refundAccountCount()==0 && entropy.revealFeeEscrow(1)==0 && address(entropy).balance==0,"replay receiver and native rollback");
        entropy.configure(true,0,100,0);
        vm.prank(payer); (ok,)=address(priceSale).call{value:125}(exact);
        require(ok && manager.ownerOf(1)==address(recipient) && priceSale.refundLiability()==25 && entropy.requests()==1,"same nonce and exact bytes retry");
        require(token.balanceOf(wallet)==0 && recorder.totalOfficialSettled(address(token))==0,"retry still not official ERC20 revenue");
    }

    function testFreeProviderFailureIsIsolatedWithExactTokenAndBoundedEvent() public {
        _bind(payer,IStreamMintManager.CounterKeyMode.PAYER,true,0); _registerPrice(true);
        _entropy().configure(true,0,100,2); vm.deal(payer,125);
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        vm.recordLogs(); vm.prank(payer); priceSale.executeAllowlistFreeMint{value:125}(e,proofData);
        Vm.Log[] memory logs=vm.getRecordedLogs(); uint256 count;
        for(uint256 i;i<logs.length;++i) {
            if(logs[i].emitter!=address(priceSale) || logs[i].topics[0]!=keccak256("ImmediateRevealAttempt(uint16,uint256,uint256,bool,bytes32,uint256,uint256,bytes)"))continue;
            (uint16 schema,bool success,bytes32 key,uint256 request,uint256 size,bytes memory prefix)=abi.decode(logs[i].data,(uint16,bool,bytes32,uint256,uint256,bytes));
            require(schema==1 && !success && key==0 && request==0 && size==16384 && prefix.length==256,"bounded original failure event");
            require(logs[i].topics.length==3 && logs[i].topics[1]==bytes32(uint256(1)) && logs[i].topics[2]==bytes32(uint256(1)),"actual collection and minted token"); ++count;
        }
        require(count==1 && manager.ownerOf(1)==payer && _entropy().revealFeeEscrow(1)==100 && priceSale.refundLiability()==25 && recorder.totalOfficialSettled(address(token))==0,"failed request never fabricates ERC20 revenue");
    }

    function testRefundInventoryDeduplicatesAndRecipientReentryCannotDoubleClaim() public {
        vm.deal(payer,250); _entropy().configure(true,1,100,0); _buy(1,125); _buy(2,125);
        require(priceSale.refundAccountCount()==1 && priceSale.refundLiability()==50 && priceSale.refundableBalance(saleId,payer)==50,"one inventory row per sale and executor");
        PriceReentrantRefundReceiver recipient=new PriceReentrantRefundReceiver(priceSale,saleId);
        vm.prank(payer); priceSale.claimRefund(saleId,address(recipient));
        require(recipient.attempted() && !recipient.succeeded() && keccak256(recipient.reason())==keccak256(abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)),"original guard blocks nested claim");
        require(address(recipient).balance==50 && priceSale.refundLiability()==0 && priceSale.refundableBalance(saleId,payer)==0 && priceSale.refundAccountCount()==1,"single claim preserves retained enumeration");
    }

    function testPositiveTierCannotUseFreePathAndZeroAllowanceCreatesNoRefundRow() public {
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e=_e(payer,payer,payer,1);
        vm.deal(payer,125); vm.expectRevert(abi.encodeWithSelector(IStreamUniversalAllowlistPriceSale.InvalidUniversalPriceProfile.selector));
        vm.prank(payer); priceSale.executeAllowlistFreeMint{value:125}(e,proofData); _unused();
        _buy(1,0);
        require(priceSale.refundLiability()==0 && priceSale.refundAccountCount()==0 && payer.balance==125 && token.balanceOf(wallet)==375,"zero native allowance independent of positive tier");
    }
}

contract PriceMintReceiver is IERC721Receiver {
    function onERC721Received(address,address,uint256,bytes calldata) external pure returns(bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
contract PriceReentrantRefundReceiver {
    StreamUniversalAllowlistPriceSale private immutable target;
    bytes32 private immutable saleId;
    bool public attempted;
    bool public succeeded;
    bytes public reason;
    constructor(StreamUniversalAllowlistPriceSale t,bytes32 id) { target=t; saleId=id; }
    receive() external payable {
        attempted=true;
        (succeeded,reason)=address(target).call(abi.encodeCall(target.claimRefund,(saleId,address(this))));
    }
}
