// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/DutchSaleTestBase.sol";

contract DutchSaleReceiver {
    bool public rejects;

    function setReject(bool value) external {
        rejects = value;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        view
        returns (bytes4)
    {
        require(!rejects, "recipient rejects");
        return 0x150b7a02;
    }

    receive() external payable {
        require(!rejects, "claim rejects");
    }
}

contract StreamNativeDutchSaleTest is DutchSaleTestBase {
    function testExecutionChargesCurrentPriceKeepsSignedMaximumAndCreditsOnlyExcess() public {
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        bytes32 originalDigest = dutchSale.authorizationDigest(d.authorization);
        vm.warp(1005);
        vm.deal(address(dutchSale), 77);
        uint256 beforePayer = payer.balance;
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory r = dutchSale.purchase{ value: 1500 }(d);
        require(
            r.revenueOutcome == 2 && r.chargedAmount == 550 && r.revealFeeForwarded == 100
                && r.excessCredited == 850 && r.tokenId != 0 && r.settlementKey != 0,
            "typed execution"
        );
        require(
            payer.balance == beforePayer - 1500 && wallet.balance == 550
                && recorder.totalOfficialSettled(address(0)) == 550
                && refundEntropy.revealFeeEscrow(1) == 100,
            "money"
        );
        require(
            dutchSale.refundableBalance(dutchId, payer) == 850
                && dutchSale.refundCredit(payer) == 850 && dutchSale.refundLiability() == 850
                && address(dutchSale).balance == 927,
            "credit plus surplus"
        );
        require(
            dutchSale.authorizationDigest(d.authorization) == originalDigest
                && refundManager.lastAuthorizationId()
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), originalDigest
                        )
                    ),
            "full unchanged maximum digest"
        );
        vm.prank(payer);
        dutchSale.claimRefund(dutchId, payer);
        require(
            payer.balance == beforePayer - 650 && address(dutchSale).balance == 77
                && dutchSale.refundLiability() == 0,
            "net exact charge plus fee"
        );
    }

    function testBothSignedAndFundedMaximumRejectBelowPriceWithSameProofRetry() public {
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        d.authorization.unitPrice = 999;
        _signDutch(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchPaymentBelowPrice.selector, uint256(999), uint256(1000)
            )
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1200 }(d);
        d.authorization.unitPrice = 1000;
        _signDutch(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchPaymentBelowPrice.selector, uint256(999), uint256(1000)
            )
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1099 }(d);
        require(
            dutchSale.executionIdByNonce(dutchId, 1) == 0
                && !dutchSale.authorizationUsed(artist, bytes32(uint256(1)))
                && refundManager.nonce() == 0 && wallet.balance == 0,
            "failed maxima retain execution"
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(
            wallet.balance == 1000 && dutchSale.refundLiability() == 0,
            "same proof exact funded control"
        );
    }

    function testDeclaredZeroSkipsPoisonedRightsAndOfficialLanesButFundsFee() public {
        IStreamNativeDutchSale.DutchSaleConfig memory config = _dutchConfig();
        config.schedule.restingPrice = 0;
        config.declaredFree = true;
        dutchId = dutchSale.registerDutchSale(config);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        uint256 count = factory.profileCount();
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                address(resolver),
                0,
                abi.encodeCall(
                    IStreamRevenueResolver.resolvePrimaryAssignment, (uint256(1), uint256(0), CLASS)
                ),
                hex"cafe"
            );
        vm.expectRevert(hex"cafe");
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        vm.warp(1010);
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory r = dutchSale.purchase{ value: 200 }(d);
        require(
            r.revenueOutcome == 1 && r.chargedAmount == 0 && r.settlementKey == 0 && !r.escrowed
                && r.revealFeeForwarded == 100 && r.excessCredited == 100 && r.tokenId != 0,
            "free outcome"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 0 && wallet.balance == 0
                && factory.profileCount() == count && refundEntropy.revealFeeEscrow(1) == 100,
            "free fee only"
        );
        require(
            dutchSale.executionIdByNonce(dutchId, 1) == r.executionId,
            "zero consumed same execution"
        );
    }

    function testRejectedNFTAndClaimRestoreOriginalSaleCreditAndExactRetry() public {
        DutchSaleReceiver receiver = new DutchSaleReceiver();
        receiver.setReject(true);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, address(receiver));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "recipient rejects"));
        vm.prank(payer);
        dutchSale.purchase{ value: 1200 }(d);
        require(
            wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && refundManager.nonce() == 0 && dutchSale.refundLiability() == 0,
            "failed mint fully restored"
        );
        receiver.setReject(false);
        vm.prank(payer);
        dutchSale.purchase{ value: 1200 }(d);
        receiver.setReject(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchTransferFailed.selector, address(receiver)
            )
        );
        vm.prank(payer);
        dutchSale.claimRefund(dutchId, address(receiver));
        require(
            dutchSale.refundableBalance(dutchId, payer) == 100
                && dutchSale.refundCredit(payer) == 100 && dutchSale.refundLiability() == 100
                && address(dutchSale).balance == 100,
            "rejected claim restored"
        );
        receiver.setReject(false);
        vm.prank(payer);
        dutchSale.claimRefund(dutchId, address(receiver));
        require(
            address(receiver).balance == 100 && dutchSale.refundLiability() == 0, "same claim retry"
        );
    }

    function testImmediateFeeQuoteSurvivesCallbackRepricingThenNextPurchaseUsesNewFee() public {
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        refundEntropy.setCallback(
            address(refundEntropy),
            abi.encodeCall(RefundRuntimeEntropy.setPolicy, (true, uint8(1), uint256(700)))
        );
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory first = dutchSale.purchase{ value: 1100 }(
            d
        );
        require(
            first.revealFeeForwarded == 100 && refundEntropy.revealFeeEscrow(1) == 100,
            "one captured quote"
        );
        refundEntropy.setCallback(address(0), "");
        d = _dutchData(2, payer, payer);
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory second =
            dutchSale.purchase{ value: 1700 }(d);
        require(
            second.revealFeeForwarded == 700 && refundEntropy.revealFeeEscrow(1) == 800
                && wallet.balance == 2000,
            "next purchase fresh quote"
        );
    }

    function testRequiredConsentInertRegistrationAndCurrentStatusGateBeforeMoney() public {
        refundArtist.configureSaleConsent(true, 0);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchDependencyInvalid.selector, address(refundArtist)
            )
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        refundArtist.recordTestSaleConsent(
            address(dutchSale), 1, dutchId, d.authorization.saleConfigHash, true
        );
        refundArtist.setAssociation(2, 1, refundArtist.identity(), 4, refundArtist.binding());
        vm.expectRevert(abi.encodeWithSelector(IStreamNativeDutchSale.InvalidDutchSale.selector));
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(
            refundManager.nonce() == 0 && wallet.balance == 0
                && !dutchSale.authorizationUsed(artist, bytes32(uint256(1))),
            "no new deposit in contest"
        );
        refundArtist.setAssociation(2, 1, refundArtist.identity(), 1, refundArtist.binding());
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(wallet.balance == 1000, "same proof active consent control");
    }
}
