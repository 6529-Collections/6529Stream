// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";

contract StreamRefundWindowAuthorizationTest is RefundWindowTestBase {
    function testNewEnvelopeHashIncludesEveryFieldAndIsConsumerAndChainBound() public {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        bytes32 domain = _discoveredDomain();
        bytes32 typehash = keccak256(
            "RefundPurchaseAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 purchaseNonce,bytes32 nonce,uint256 price,uint64 deadline,bytes32 windowPolicyHash,uint64 maximumNominalFinalizeBy,uint64 absoluteEscapeDeadline,bytes32 expectedPrimaryPolicyHash)"
        );
        bytes32 structHash = keccak256(
            abi.encode(
                typehash,
                d.authorization.saleId,
                d.authorization.saleConfigHash,
                d.authorization.payer,
                d.authorization.recipient,
                d.authorization.artist,
                d.authorization.tokenDataHash,
                d.authorization.mintCommitment,
                d.authorization.purchaseNonce,
                d.authorization.nonce,
                d.authorization.price,
                d.authorization.deadline,
                d.authorization.windowPolicyHash,
                d.authorization.maximumNominalFinalizeBy,
                d.authorization.absoluteEscapeDeadline,
                d.authorization.expectedPrimaryPolicyHash
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), domain, structHash));
        require(
            refundSale.refundPurchaseAuthorizationDigest(d.authorization) == digest,
            "independent full static-tuple EIP712 preimage"
        );
        for (uint256 i; i < 2; ++i) {
            bytes32 wrongDomain = keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256("6529StreamNativeRefundWindowSale"),
                    keccak256("1"),
                    i == 0 ? block.chainid + 1 : block.chainid,
                    i == 0 ? address(refundSale) : address(0xBADD)
                )
            );
            d.platformSignature = _sign(
                PLATFORM_KEY, keccak256(abi.encodePacked(bytes2(0x1901), wrongDomain, structHash))
            );
            vm.prank(payer);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamNativeRefundWindowSale.RefundPurchaseSignatureInvalid.selector,
                    vm.addr(PLATFORM_KEY)
                )
            );
            refundSale.purchaseRefundWindow{ value: 1100 }(d);
        }
        d.platformSignature = _sign(PLATFORM_KEY, digest);
        d.authorization.recipient = address(0xFEED);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundPurchaseSignatureInvalid.selector,
                vm.addr(PLATFORM_KEY)
            )
        );
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
        require(
            !refundSale.purchaseAuthorizationUsed(artist, d.authorization.nonce)
                && refundSale.totalBuyerLiabilities() == 0,
            "signed recipient drift rejected before custody"
        );
        d.authorization.recipient = payer;
        vm.prank(payer);
        bytes32 id = refundSale.purchaseRefundWindow{ value: 1100 }(d);
        require(
            refundSale.refundPurchaseRecord(id).authorizationDigest == digest,
            "same proof healthy after domain and field controls"
        );
    }

    function _discoveredDomain() private view returns (bytes32) {
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifier,
            bytes32 salt,
            uint256[] memory extensions
        ) = refundSale.eip712Domain();
        require(
            fields == hex"0f"
                && keccak256(bytes(name)) == keccak256("6529StreamNativeRefundWindowSale")
                && keccak256(bytes(version)) == keccak256("1") && chainId == block.chainid
                && verifier == address(refundSale) && salt == 0 && extensions.length == 0,
            "exact ERC5267 sole-domain discovery"
        );
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifier
            )
        );
    }

    function testSignedMaximumNominalAndAbsoluteBoundsAllowEqualityButRejectOnePast() public {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        d.authorization.maximumNominalFinalizeBy = 90999;
        _signPurchase(d);
        _invalid(d);
        d.authorization.maximumNominalFinalizeBy = 91000;
        d.authorization.absoluteEscapeDeadline = 90999;
        _signPurchase(d);
        _invalid(d);
        d.authorization.absoluteEscapeDeadline = 91000;
        _signPurchase(d);
        vm.prank(payer);
        bytes32 id = refundSale.purchaseRefundWindow{ value: 1100 }(d);
        require(
            refundSale.refundPurchaseRecord(id).nominalFinalizeBy == 91000,
            "exact inclusion bound accepted"
        );
        IStreamNativeRefundWindowSale.RefundPurchaseData memory other =
            _purchaseData(2, payer, payer);
        vm.warp(1001);
        _invalid(other);
        require(
            refundSale.totalPendingDeposits() == 1100,
            "later inclusion cannot exceed signed maximum"
        );
    }

    function testBothPurchaseIdentityAndCommercialNonceRejectChangedAuthenticatedReplay() public {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        vm.prank(payer);
        bytes32 id = refundSale.purchaseRefundWindow{ value: 1100 }(d);
        d.authorization.recipient = address(0xABCD);
        d.authorization.nonce = bytes32(uint256(2));
        _signPurchase(d);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundPurchaseAlreadyUsed.selector, id
            )
        );
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
        d.authorization.nonce = bytes32(uint256(1));
        d.authorization.purchaseNonce = 2;
        _signPurchase(d);
        bytes32 otherId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(refundSale),
                refundId,
                payer,
                uint256(2)
            )
        );
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundPurchaseAlreadyUsed.selector, otherId
            )
        );
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
        _pending(id, 1100, 0);
    }

    function testMissingFeeDeclarationAndStrictModeRejectInsteadOfInferringZero() public {
        IStreamNativeRefundWindowSale.RefundSaleConfig memory c = _refundConfig();
        c.primaryPolicyMode = 0;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.SaleEnvelopeModeInvalid.selector)
        );
        refundSale.registerRefundSale(c);
        c.primaryPolicyMode = 1;
        refundEntropy.setPolicy(false, 1, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundDependencyReadMalformed.selector,
                address(refundEntropy),
                uint256(160)
            )
        );
        refundSale.registerRefundSale(c);
        refundEntropy.setPolicy(true, 1, 0);
        refundId = refundSale.registerRefundSale(c);
        bytes32 id = _purchase(1, 1000);
        require(
            refundSale.refundPurchaseRecord(id).savedRevealFee == 0
                && refundSale.totalPendingDeposits() == 1000,
            "declared zero is distinct from absent policy"
        );
    }

    function testRequiredConsentCapabilityAndFeeBudgetRejectBeforePendingState() public {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        artists.configureSaleConsent(true, 0);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSaleConsent.SaleConsentNotSatisfied.selector,
                address(artists),
                uint256(1),
                refundId
            )
        );
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
        artists.recordTestSaleConsent(
            address(refundSale), 1, refundId, d.authorization.saleConfigHash, true
        );
        artists.configureSaleCapability(1);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSaleConsent.SaleConsentNotSatisfied.selector,
                address(artists),
                uint256(1),
                refundId
            )
        );
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
        artists.configureSaleCapability(0);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.SaleRevealFeeBelowRequired.selector,
                uint256(99),
                uint256(100)
            )
        );
        refundSale.purchaseRefundWindow{ value: 1099 }(d);
        require(
            refundSale.totalPendingDeposits() == 0
                && !refundSale.purchaseAuthorizationUsed(artist, d.authorization.nonce),
            "failed admission leaves buyer/replay untouched"
        );
        vm.prank(payer);
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
        require(refundSale.totalPendingDeposits() == 1100, "same proof healthy exact funding");
    }

    function testFuzzPrincipalFeeRefundConservation(uint64 sample) public {
        uint256 price = uint256(sample) + 1;
        IStreamNativeRefundWindowSale.RefundSaleConfig memory c = _refundConfig();
        c.price = price;
        refundId = refundSale.registerRefundSale(c);
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        d.authorization.price = price;
        _signPurchase(d);
        vm.deal(payer, price + 100);
        vm.deal(address(refundSale), 73);
        vm.prank(payer);
        bytes32 id = refundSale.purchaseRefundWindow{ value: price + 100 }(d);
        require(
            refundSale.totalPendingDeposits() == price + 100
                && refundSale.totalBuyerLiabilities() == price + 100 && payer.balance == 0,
            "exact full deposit"
        );
        vm.prank(payer);
        refundSale.refundPurchase(id);
        vm.prank(payer);
        refundSale.claimRefund(refundId, payable(payer));
        require(
            payer.balance == price + 100 && address(refundSale).balance == 73
                && refundSale.totalBuyerLiabilities() == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "full amount returned and surplus excluded"
        );
    }

    function _invalid(IStreamNativeRefundWindowSale.RefundPurchaseData memory d) private {
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
        );
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
    }
}
