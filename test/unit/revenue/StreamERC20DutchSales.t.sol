// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ERC20DutchSalesFixture.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamPinnedPermit2.sol";

interface DutchCallVm {
    function expectCall(address, bytes calldata, uint64) external;
}

/// @notice Real singleton mint/revenue flows; typed boundaries are stated on the fixture.
/// @dev No clearing rebates, original Artist ingress, provider runtime or full-stack claim.
contract StreamERC20DutchSalesTest is ERC20DutchSalesFixture {
    function testPublicCurrentPriceIsResolvedAtInclusionAndConservesExactTokenUnits() public {
        bytes32 id = _registerDutch(_dutchConfig(2, false));
        D.Execution memory e = _dutchExecution(id, payer, 1);
        (PS.ERC20SettlementCandidate memory early,) = dutch.previewDutchExecution(e);
        require(early.sale.amount == 1000);
        DP.Request memory q = _dutchRequest(e, 1000);
        vm.warp(1500);
        vm.prank(payer);
        DP.Result memory out = dutchPayment.settleERC20DutchSaleByPayer(q);
        _assertPaid(e, out, 550);
        require(
            dutchToken.balanceOf(payer) == 9450 && dutchToken.balanceOf(wallet) == 550,
            "only current price moved"
        );
        require(
            dutchToken.balanceOf(address(dutchPayment)) == 0
                && dutchToken.balanceOf(address(recorder)) == 0,
            "no retained token surplus"
        );
        require(
            dutch.executionReceipt(out.executionId).saleAuthorizationDigest == 0,
            "public has no seller signature"
        );
    }

    function testSignedCanonicalSalesDigestAndOriginalManagerAuthorizationId() public {
        bytes32 id = _registerDutch(_dutchConfig(1, false));
        D.Execution memory e = _signDutch(_dutchExecution(id, payer, 2), 1000);
        bytes32 digest_ = _dutchDigest(e.authorization);
        require(dutch.authorizationDigest(e.authorization) == digest_, "literal24 fields");
        vm.warp(1500);
        DP.Result memory out = _dutchBuy(e, 1000, 0);
        _assertPaid(e, out, 550);
        S.Receipt memory r = dutch.executionReceipt(out.executionId);
        require(
            r.saleAuthorizationDigest == digest_
                && r.authorizationId
                    == keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest_)
                    ),
            "original Manager ID"
        );
    }

    function testRequestMaximumRejectsBeforePullThenIdenticalExecutionSucceeds() public {
        bytes32 id = _registerDutch(_dutchConfig(2, false));
        D.Execution memory e = _dutchExecution(id, payer, 3);
        vm.warp(1500);
        DP.Request memory q = _dutchRequest(e, 549);
        vm.expectRevert(abi.encodeWithSelector(DP.DutchPaymentMaximumExceeded.selector, 549, 550));
        vm.prank(payer);
        dutchPayment.settleERC20DutchSaleByPayer(q);
        require(
            dutchToken.balanceOf(payer) == 10000 && dutch.nextExecutionNonce(id, payer) == 1,
            "no payment or sale nonce"
        );
        _assertPaid(e, _dutchBuy(e, 550, 0), 550);
    }

    function testProvenLeafReplacesSignedBaseCeilingButPaymentIntentStillCaps() public {
        D.Configuration memory c = _dutchConfig(1, false);
        (bytes32 phase, bytes32 counter, bytes memory proof) =
            _dutchMerklePhase(address(0xCAFE), 700);
        c.sale.phaseId = phase;
        c.sale.priceCounterId = counter;
        c.sale.mintPolicyHash = manager.phasePolicyHash(1, phase);
        bytes32 id = _registerDutch(c);
        D.Execution memory e = _dutchExecution(id, payer, 4);
        e.purchase.resolverData = proof;
        e = _signDutch(e, 100);
        (PS.ERC20SettlementCandidate memory candidate,) = dutch.previewDutchExecution(e);
        require(
            candidate.sale.amount == 700 && candidate.sale.amount > e.authorization.unitPrice,
            "U6 replacement not second ceiling"
        );
        DP.Request memory q = _dutchRequest(e, 1000);
        PS.PaymentIntent memory intent = _intent(e, 699, 41);
        bytes memory signature = _intentSignature(intent);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.InvalidPaymentIntent.selector
            )
        );
        vm.prank(payer);
        dutchPayment.settleERC20DutchSaleWithIntent(q, intent, signature);
        require(
            !dutchPayment.isPaymentIntentNonceUsed(payer, bytes32(uint256(41)))
                && dutchToken.balanceOf(payer) == 10000,
            "independent cap atomic refusal"
        );
        intent.maxAmount = 700;
        signature = _intentSignature(intent);
        vm.prank(payer);
        DP.Result memory out = dutchPayment.settleERC20DutchSaleWithIntent(q, intent, signature);
        _assertPaid(e, out, 700);
        require(
            dutchPayment.isPaymentIntentNonceUsed(payer, intent.nonce),
            "paid original nonce consumed"
        );
    }

    function testWithoutLeafSignedCeilingCannotBeExceeded() public {
        bytes32 id = _registerDutch(_dutchConfig(1, false));
        D.Execution memory e = _signDutch(_dutchExecution(id, payer, 5), 500);
        vm.expectRevert(abi.encodeWithSelector(S.InvalidImmediateSale.selector));
        dutch.previewDutchExecution(e);
        vm.warp(1600);
        _assertPaid(e, _dutchBuy(e, 500, 0), 460);
    }

    function testDeclaredFreeCrossingUsesNoTokenPermitOrOfficialSettlementAndCannotReplay() public {
        bytes32 id = _registerDutch(_dutchConfig(2, true));
        D.Execution memory e = _dutchExecution(id, payer, 6);
        vm.prank(payer);
        dutchToken.approve(address(dutchPayment), 0);
        vm.warp(2000);
        DP.Request memory q = _dutchRequest(e, 0);
        vm.prank(payer);
        DP.Result memory out = dutchPayment.settleERC20DutchSaleByPayer(q);
        PS.PrimarySettlementResult memory zero;
        require(
            out.revenueOutcome == 1
                && keccak256(abi.encode(out.settlement)) == keccak256(abi.encode(zero)),
            "literal-zero official settlement"
        );
        S.Receipt memory r = dutch.executionReceipt(out.executionId);
        require(
            r.tokenId != 0 && r.chargedAmount == 0 && r.settlementKey == 0
                && core.ownerOf(r.tokenId) == e.purchase.initialRecipient,
            "actual free mint"
        );
        require(
            dutchToken.balanceOf(payer) == 10000 && dutchToken.balanceOf(wallet) == 0
                && dutchToken.nonces(payer) == 0,
            "no pull or permit"
        );
        require(dutch.nextExecutionNonce(id, payer) == 2, "original sale replay advanced");
        vm.expectRevert(
            abi.encodeWithSelector(DP.DutchPaymentResolutionFailed.selector, address(dutch))
        );
        vm.prank(payer);
        dutchPayment.settleERC20DutchSaleByPayer(q);
        require(dutch.dutchSaleRecord(id).soldQuantity == 1, "one actual free execution");
    }

    function testSignedFreeIntentDoesNotConsumeOriginalPaymentNonce() public {
        bytes32 id = _registerDutch(_dutchConfig(1, true));
        D.Execution memory e = _signDutch(_dutchExecution(id, payer, 7), 1000);
        e.purchase.executor = address(this);
        e = _signDutch(e, 1000);
        PS.PaymentIntent memory intent = _intent(e, 1000, 71);
        bytes memory signature = _intentSignature(intent);
        DP.Request memory q = _dutchRequest(e, 1000);
        vm.warp(2000);
        DP.Result memory out = dutchPayment.settleERC20DutchSaleWithIntent(q, intent, signature);
        require(
            out.revenueOutcome == 1 && !dutchPayment.isPaymentIntentNonceUsed(payer, intent.nonce),
            "free does not consume PaymentIntent"
        );
        require(
            dutch.executionStatus(out.executionId) == 2 && dutch.nextExecutionNonce(id, payer) == 2,
            "separate Sales and Manager replay"
        );
    }

    function testUndeclaredZeroScheduleRefusesRegistration() public {
        D.Configuration memory c = _dutchConfig(2, true);
        c.declaredFree = false;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDutchPriceSchedule.DutchScheduleInvalid.selector)
        );
        vm.prank(address(revenueAuthority));
        dutch.registerDutchSale(c);
        c.declaredFree = true;
        require(_registerDutch(c) != 0, "otherwise same healthy declared profile");
    }

    function testPublicSaleWideIntentCannotRedirectPayerRecipientOrExecutor() public {
        bytes32 id = _registerDutch(_dutchConfig(2, false));
        D.Execution memory e = _dutchExecution(id, payer, 8);
        PS.PaymentIntent memory intent = _intent(e, 1000, 81);
        bytes memory signature = _intentSignature(intent);
        e.purchase.executor = address(this);
        e.purchase.initialRecipient = address(0xBAD);
        DP.Request memory stolen = _dutchRequest(e, 1000);
        vm.expectRevert(
            abi.encodeWithSelector(DP.DutchPaymentResolutionFailed.selector, address(dutch))
        );
        dutchPayment.settleERC20DutchSaleWithIntent(stolen, intent, signature);
        require(
            !dutchPayment.isPaymentIntentNonceUsed(payer, intent.nonce)
                && dutchToken.balanceOf(payer) == 10000,
            "stolen sale-wide intent not authority"
        );
        e = _dutchExecution(id, payer, 8);
        DP.Request memory healthy = _dutchRequest(e, 1000);
        vm.prank(payer);
        _assertPaid(
            e, dutchPayment.settleERC20DutchSaleWithIntent(healthy, intent, signature), 1000
        );
    }

    function testThresholdSafeIsActualPublicPayerAndExecutor() public {
        (OfficialSafe buyer, uint256[] memory keys) = _safe(901);
        bytes32 id = _registerDutch(_dutchConfig(2, false));
        dutchToken.mint(address(buyer), 1000);
        require(
            executeSafe(
                buyer,
                keys,
                address(dutchToken),
                0,
                abi.encodeCall(dutchToken.approve, (address(dutchPayment), 1000)),
                0
            )
        );
        D.Execution memory e = _dutchExecution(id, address(buyer), 9);
        DP.Request memory q = _dutchRequest(e, 1000);
        uint256 nonce = buyer.nonce();
        require(
            executeSafe(
                buyer,
                keys,
                address(dutchPayment),
                0,
                abi.encodeCall(dutchPayment.settleERC20DutchSaleByPayer, (q)),
                0
            )
        );
        require(
            buyer.nonce() == nonce + 1 && dutchToken.balanceOf(address(buyer)) == 0
                && dutchToken.balanceOf(wallet) == 1000,
            "genuine Safe paid once"
        );
        require(dutch.nextExecutionNonce(id, address(buyer)) == 2, "Safe is bound sale payer");
    }

    function testEIP2612MaximumSignsCeilingAndPullsOnlyInclusionPrice() public {
        bytes32 id = _registerDutch(_dutchConfig(2, false));
        D.Execution memory e = _dutchExecution(id, payer, 10);
        DP.Request memory q = _dutchRequest(e, 1000);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(PAYER_KEY, dutchToken.permitDigest(payer, address(dutchPayment), 1000, 3000));
        DP.EIP2612Maximum memory permit =
            DP.EIP2612Maximum(1000, PS.EIP2612PermitAuthorization(3000, v, r, s));
        vm.warp(1500);
        vm.prank(payer);
        DP.Result memory out = dutchPayment.settleERC20DutchSaleWithEIP2612Permit(q, permit);
        _assertPaid(e, out, 550);
        require(
            dutchToken.nonces(payer) == 1
                && dutchToken.allowance(payer, address(dutchPayment)) == 450,
            "maximum allowance minus actual pull"
        );
    }

    function testPermit2MaximumActualPullAndNonceUseAreIndependent() public {
        bytes32 id = _registerDutch(_dutchConfig(2, false));
        D.Execution memory e = _dutchExecution(id, payer, 11);
        DP.Request memory q = _dutchRequest(e, 1000);
        vm.prank(payer);
        dutchToken.approve(dutchPermit2, 1000);
        DP.Permit2Maximum memory permit = _permit2Maximum(1000, 255);
        vm.warp(1500);
        vm.prank(payer);
        DP.Result memory out = dutchPayment.settleERC20DutchSaleWithPermit2(q, permit);
        _assertPaid(e, out, 550);
        require(
            IStreamPinnedPermit2(dutchPermit2).nonceBitmap(payer, 0) == uint256(1) << 255,
            "exact original upstream nonce"
        );
        require(
            dutchToken.allowance(payer, dutchPermit2) == 450 && dutchToken.balanceOf(wallet) == 550,
            "permission maximum is not actual transfer"
        );
    }

    function testFreePermitEntryNeverInvokesPermitOrConsumesBitmap() public {
        bytes32 id = _registerDutch(_dutchConfig(2, true));
        D.Execution memory e = _dutchExecution(id, payer, 12);
        DP.Request memory q = _dutchRequest(e, 1000);
        DP.Permit2Maximum memory permit = _permit2Maximum(1000, 255);
        vm.warp(2000);
        vm.prank(payer);
        DP.Result memory out = dutchPayment.settleERC20DutchSaleWithPermit2(q, permit);
        require(
            out.revenueOutcome == 1 && IStreamPinnedPermit2(dutchPermit2).nonceBitmap(payer, 0) == 0
                && dutchToken.allowance(payer, dutchPermit2) == 0,
            "no approval/permit needed for truthful free result"
        );
    }

    function testTransferFailureRollsBackPermitSaleAndManagerThenSameSignatureRetries() public {
        bytes32 id = _registerDutch(_dutchConfig(2, false));
        D.Execution memory e = _dutchExecution(id, payer, 13);
        DP.Request memory q = _dutchRequest(e, 1000);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(PAYER_KEY, dutchToken.permitDigest(payer, address(dutchPayment), 1000, 3000));
        DP.EIP2612Maximum memory permit =
            DP.EIP2612Maximum(1000, PS.EIP2612PermitAuthorization(3000, v, r, s));
        dutchToken.configure(address(dutchPayment), 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector
            )
        );
        vm.prank(payer);
        dutchPayment.settleERC20DutchSaleWithEIP2612Permit(q, permit);
        require(
            dutchToken.nonces(payer) == 0 && dutchToken.balanceOf(payer) == 10000
                && dutch.nextExecutionNonce(id, payer) == 1
                && dutch.dutchSaleRecord(id).soldQuantity == 0,
            "atomic funding refusal"
        );
        dutchToken.configure(address(0), 0);
        vm.prank(payer);
        _assertPaid(e, dutchPayment.settleERC20DutchSaleWithEIP2612Permit(q, permit), 1000);
    }

    function testNativeExcessBelongsToExecutorAndNeverChangesTokenPrice() public {
        immediateEntropy.configure(false, 100);
        bytes32 id = _registerDutch(_dutchConfig(1, false));
        D.Execution memory e = _dutchExecution(id, payer, 14);
        e.purchase.executor = address(this);
        e = _signDutch(e, 1000);
        PS.PaymentIntent memory intent = _intent(e, 1000, 141);
        bytes memory signature = _intentSignature(intent);
        DP.Request memory q = _dutchRequest(e, 1000);
        vm.deal(address(this), 200);
        DP.Result memory out =
            dutchPayment.settleERC20DutchSaleWithIntent{ value: 150 }(q, intent, signature);
        _assertPaid(e, out, 1000);
        require(
            dutch.refundableBalance(id, address(this)) == 50
                && dutch.refundableBalance(id, payer) == 0
                && immediateEntropy.revealFeeEscrow(1) == 100,
            "native executor only accounting"
        );
        vm.prank(payer);
        vm.expectRevert();
        dutch.claimRefund(id, payer);
        dutch.claimRefund(id, address(0xFEED));
        require(
            address(0xFEED).balance == 50 && dutch.refundLiability() == 0,
            "executor chooses refund recipient"
        );
    }

    function testActualThresholdSafeSellerKeepsCanonicalSalesKindTwo() public {
        (OfficialSafe seller, uint256[] memory keys) = _safe(902);
        D.Configuration memory c = _dutchConfig(2, false);
        c.sale.authorityMode = 1;
        vm.prank(address(revenueAuthority));
        dutch.configureCollectionSigner(
            1, address(seller), 2, keccak256("Safe singleton seller"), true
        );
        (c.sale.signer,) = dutch.collectionSigner(1, address(seller), 2);
        bytes32 id = _registerDutch(c);
        D.Execution memory e = _dutchExecution(id, payer, 16);
        e.authorization = _dutchAuthorization(e.purchase, 16);
        bytes32 digest_ = _dutchDigest(e.authorization);
        e.signature = IStreamPrivateSaleAdapter.Signature(
            address(seller),
            2,
            safeThresholdSignature(keys, safeMessageDigest(seller, abi.encode(digest_)))
        );
        _assertPaid(e, _dutchBuy(e, 1000, 0), 1000);
        require(seller.nonce() == 0, "ERC1271 read does not execute seller Safe");
    }

    function testCanonicalSalesAllTwentyFourFieldsAreBoundAndWrongKindCannotPass() public {
        bytes32 id = _registerDutch(_dutchConfig(1, false));
        D.Execution memory e = _signDutch(_dutchExecution(id, payer, 17), 1000);
        dutch.previewDutchExecution(e);
        for (uint256 n; n < 24; ++n) {
            D.Execution memory bad = abi.decode(abi.encode(e), (D.Execution));
            // Every authorization field is one static ABI word. Mutating exactly one word
            // preserves canonical widths, so refusal must be semantic/signature-bound.
            bytes memory encoded = abi.encode(bad.authorization);
            assembly ("memory-safe") {
                let at := add(add(encoded, 32), mul(n, 32))
                mstore(at, xor(mload(at), 1))
            }
            bad.authorization = abi.decode(encoded, (StreamPrivateSaleTypes.SaleAuthorization));
            (bool ok,) =
                address(dutch).staticcall(abi.encodeCall(dutch.previewDutchExecution, (bad)));
            require(!ok, "each exact original Sales field is signed");
        }
        D.Execution memory wrong = abi.decode(abi.encode(e), (D.Execution));
        wrong.signature.kind = 2;
        vm.expectRevert(
            abi.encodeWithSelector(
                S.ImmediateSaleSignerUnavailable.selector, e.signature.authorizer, uint8(2)
            )
        );
        dutch.previewDutchExecution(wrong);
        _assertPaid(e, _dutchBuy(e, 1000, 0), 1000);
    }

    function testReusedPaidPaymentIntentRefusesAtFreshSaleNonceBeforePull() public {
        bytes32 id = _registerDutch(_dutchConfig(1, false));
        D.Execution memory e = _signDutch(_dutchExecution(id, payer, 18), 1000);
        PS.PaymentIntent memory intent = _intent(e, 1000, 181);
        bytes memory signature = _intentSignature(intent);
        DP.Request memory q = _dutchRequest(e, 1000);
        vm.prank(payer);
        dutchPayment.settleERC20DutchSaleWithIntent(q, intent, signature);
        D.Execution memory second = _signDutch(_dutchExecution(id, payer, 19), 1000);
        q = _dutchRequest(second, 1000);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.PaymentIntentNonceUsed.selector,
                payer,
                intent.nonce
            )
        );
        vm.prank(payer);
        dutchPayment.settleERC20DutchSaleWithIntent(q, intent, signature);
        require(
            dutch.nextExecutionNonce(id, payer) == 2 && dutchToken.balanceOf(payer) == 9000,
            "fresh sale request isolates original Payment nonce"
        );
        intent.nonce = bytes32(uint256(182));
        signature = _intentSignature(intent);
        vm.prank(payer);
        _assertPaid(second, dutchPayment.settleERC20DutchSaleWithIntent(q, intent, signature), 1000);
    }

    function testFreeEIP2612DoesNotConsumeSignedTokenNonce() public {
        bytes32 id = _registerDutch(_dutchConfig(2, true));
        D.Execution memory e = _dutchExecution(id, payer, 20);
        DP.Request memory q = _dutchRequest(e, 1000);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(PAYER_KEY, dutchToken.permitDigest(payer, address(dutchPayment), 1000, 3000));
        DP.EIP2612Maximum memory permit =
            DP.EIP2612Maximum(1000, PS.EIP2612PermitAuthorization(3000, v, r, s));
        vm.prank(payer);
        dutchToken.approve(address(dutchPayment), 0);
        vm.warp(2000);
        vm.prank(payer);
        DP.Result memory out = dutchPayment.settleERC20DutchSaleWithEIP2612Permit(q, permit);
        require(
            out.revenueOutcome == 1 && dutchToken.nonces(payer) == 0
                && dutchToken.allowance(payer, address(dutchPayment)) == 0,
            "free token permit untouched"
        );
    }

    function testLateArtistConsentLossReachesTokenPullAndIdenticalCandidateRetries() public {
        bytes32 id = _registerDutch(_dutchConfig(2, false));
        D.Execution memory e = _dutchExecution(id, payer, 21);
        DP.Request memory q = _dutchRequest(e, 1000);
        dutchToken.setCallback(address(artists), abi.encodeCall(artists.setConsent, (false)));
        DutchCallVm(address(vm))
            .expectCall(
                address(dutchToken),
                abi.encodeCall(dutchToken.transferFrom, (payer, address(dutchPayment), 1000)),
                2
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector
            )
        );
        vm.prank(payer);
        dutchPayment.settleERC20DutchSaleByPayer(q);
        require(
            artists.consent() && dutchToken.balanceOf(payer) == 10000
                && dutch.dutchSaleRecord(id).soldQuantity == 0
                && dutch.nextExecutionNonce(id, payer) == 1,
            "late consent and every effect restored"
        );
        dutchToken.setCallback(address(0), "");
        vm.prank(payer);
        _assertPaid(e, dutchPayment.settleERC20DutchSaleByPayer(q), 1000);
    }

    function testRequestRuntimePinCannotSubstituteAndHealthyPinnedRequestRemainsUsable() public {
        bytes32 id = _registerDutch(_dutchConfig(2, false));
        D.Execution memory e = _dutchExecution(id, payer, 22);
        DP.Request memory q = _dutchRequest(e, 1000);
        q.saleAdapterCodeHash ^= bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(DP.InvalidDutchPaymentRequest.selector));
        vm.prank(payer);
        dutchPayment.settleERC20DutchSaleByPayer(q);
        require(
            dutchToken.balanceOf(payer) == 10000 && dutch.nextExecutionNonce(id, payer) == 1,
            "wrong pinned runtime cannot fund"
        );
        _assertPaid(e, _dutchBuy(e, 1000, 0), 1000);
    }

    function _permit2Maximum(uint256 maximum, uint256 nonce)
        private
        returns (DP.Permit2Maximum memory p)
    {
        p.permittedAmount = maximum;
        p.authorization.nonce = nonce;
        p.authorization.deadline = 3000;
        bytes32 tokenHash = keccak256(
            abi.encode(
                keccak256("TokenPermissions(address token,uint256 amount)"),
                address(dutchToken),
                maximum
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
                ),
                tokenHash,
                address(dutchPayment),
                nonce,
                uint256(3000)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            PAYER_KEY, keccak256(abi.encodePacked(hex"1901", permit2Domain(dutchPermit2), body))
        );
        p.authorization.signature = abi.encodePacked(r, s, v);
    }
}
