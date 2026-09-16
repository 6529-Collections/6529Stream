// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract StreamNativeClearingAuthorizationTest is ClearingSaleTestBase {
    function _golden(
        IStreamNativeClearingSale.ClearingAuthorization memory a,
        uint256 chain,
        address verifier
    ) private pure returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeClearingSale"),
                keccak256("1"),
                chain,
                verifier
            )
        );
        // Every named field is independently placed in the permanent typehash order.
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "ClearingAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 purchaseNonce,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice,bool hasPriceOverride,uint256 priceOverride,bytes32 windowPolicyHash,uint64 maximumNominalFinalizeBy,uint64 absoluteEscapeDeadline)"
                ),
                a.saleId,
                a.saleConfigHash,
                a.payer,
                a.executor,
                a.recipient,
                a.artist,
                a.tokenDataHash,
                a.mintCommitment,
                a.purchaseNonce,
                a.executionNonce,
                a.nonce,
                a.deadline,
                a.expectedPrimaryPolicyHash,
                a.unitPrice,
                a.hasPriceOverride,
                a.priceOverride,
                a.windowPolicyHash,
                a.maximumNominalFinalizeBy,
                a.absoluteEscapeDeadline
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function testIndependentNineteenFieldsDomainIdentityAndFullManagerAuthorization() external {
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        bytes32 expected = _golden(d.authorization, block.chainid, address(clearingSale));
        require(
            clearingSale.authorizationDigest(d.authorization) == expected,
            "independent named digest"
        );
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chain,
            address verifier,
            bytes32 salt,
            uint256[] memory ext
        ) = clearingSale.eip712Domain();
        require(
            fields == 0x0f && keccak256(bytes(name)) == keccak256("6529StreamNativeClearingSale")
                && keccak256(bytes(version)) == keccak256("1") && chain == block.chainid
                && verifier == address(clearingSale) && salt == 0 && ext.length == 0,
            "exact sole domain discovery"
        );
        IStreamNativeClearingSale.ClearingSaleRecord memory r = clearingSale.saleRecord(clearingId);
        require(
            clearingId
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SALE_V1"),
                        chain,
                        verifier,
                        uint8(4),
                        uint256(1),
                        PHASE,
                        uint256(1)
                    )
                ),
            "literal kind4 identity"
        );
        require(
            r.windowPolicyHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CLEARING_WINDOW_POLICY_V1"),
                        uint64(1100),
                        uint64(100),
                        uint64(1500),
                        keccak256("OBSERVED_GLOBAL_OR_LOCAL_PAUSE_UNION"),
                        keccak256("ABSOLUTE_ESCAPE_PAUSED_EQUALITY_UNPAUSED_FINALIZE_EQUALITY")
                    )
                ),
            "signed windows independent"
        );
        for (uint256 i; i < 19; ++i) {
            IStreamNativeClearingSale.ClearingAuthorization memory changed = abi.decode(
                abi.encode(d.authorization), (IStreamNativeClearingSale.ClearingAuthorization)
            );
            // Each static ABI word is mutated once, with bool kept canonical.
            assembly ("memory-safe") {
                let p := add(changed, mul(i, 32))
                mstore(p, add(mload(p), 1))
            }
            require(clearingSale.authorizationDigest(changed) != expected, "all19 fields bind");
        }
        d.platformSignature = _sign(PLATFORM_KEY, _golden(d.authorization, chain + 1, verifier));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingSignatureInvalid.selector, vm.addr(PLATFORM_KEY)
            )
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        d.platformSignature = _sign(PLATFORM_KEY, _golden(d.authorization, chain, address(0xBAD)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingSignatureInvalid.selector, vm.addr(PLATFORM_KEY)
            )
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        d.platformSignature = _sign(PLATFORM_KEY, expected);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1020 }(d);
        require(
            p.purchaseId
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SALE_PURCHASE_V1"),
                        chain,
                        verifier,
                        clearingId,
                        payer,
                        uint256(1)
                    )
                ),
            "canonical purchase id"
        );
        require(
            clearingManager.lastAuthorizationId()
                    == keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), expected)
                    ) && clearingManager.lastContextHash() == expected,
            "full original digest reaches Manager"
        );
    }

    function testBothMaximaAndDelayedSameProofKeepSignedMaximumUnchanged() external {
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        d.authorization.unitPrice = 640;
        _signClearing(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingPriceAboveMaximum.selector,
                uint256(640),
                uint256(1000)
            )
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        bytes32 digest = clearingSale.authorizationDigest(d.authorization);
        vm.warp(1040);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingPriceAboveMaximum.selector,
                uint256(639),
                uint256(640)
            )
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 659 }(d);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 660 }(d);
        require(
            p.chargedAmount == 640 && clearingManager.lastContextHash() == digest
                && p.heldOverage == 540,
            "same delayed proof exact price"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingAuthorizationUsed.selector,
                artist,
                bytes32(uint256(1))
            )
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 660 }(d);
    }

    function testFullWidthOverrideIsAuthenticatedAndOnlyAggregateKeyIsClamped() external {
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        d.authorization.hasPriceOverride = true;
        d.authorization.priceOverride = type(uint256).max;
        _signClearing(d);
        bytes32 digest = clearingSale.authorizationDigest(d.authorization);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1020 }(d);
        require(
            clearingSale.purchaseRecord(p.purchaseId).priceOverride == type(uint256).max
                && clearingManager.lastContextHash() == digest,
            "raw256 never truncated"
        );
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        require(
            clearingSale.refundableBalance(clearingId, payer) == 360
                && clearingSale.financialSale(clearingId).scheduledSupplement == 540,
            "normalized maximum mathematically equal"
        );
        StreamNativeSupplementalTypes.NativeSupplementalResult memory result =
            clearingSale.settlePurchaseSupplement(p.purchaseId);
        require(
            result.amount == 540
                && clearingSale.clearingPurchaseFacts(p.purchaseId).priceOverride
                    == type(uint256).max,
            "original override in official facts"
        );
    }

    function testExactPerBuyerCounterAndIndependentCommercialExecutionLanes() external {
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        d.authorization.purchaseNonce = 2;
        _signClearing(d);
        vm.prank(payer);
        (bool ok,) =
            address(clearingSale).call{ value: 1020 }(abi.encodeCall(clearingSale.purchase, (d)));
        require(
            !ok && clearingSale.nextPurchaseNonce(clearingId, payer) == 1 && wallet.balance == 0,
            "gap rejects atomically"
        );
        d.authorization.purchaseNonce = 1;
        _signClearing(d);
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        d = _clearingData(2, payer, payer);
        d.authorization.executionNonce = 1;
        _signClearing(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingExecutionUsed.selector, clearingId, uint256(1)
            )
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        require(
            clearingSale.nextPurchaseNonce(clearingId, payer) == 2,
            "execution lane failure no counter advance"
        );
        d.authorization.executionNonce = 2;
        _signClearing(d);
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        bytes32 firstSale = clearingId;
        clearingId = clearingSale.registerClearingSale(_clearingConfig());
        require(clearingSale.nextPurchaseNonce(clearingId, payer) == 1, "independent sale counter");
        address other = address(0xBEEF);
        vm.deal(other, 1020);
        d = _clearingData(3, other, other);
        vm.prank(other);
        clearingSale.purchase{ value: 1020 }(d);
        require(
            clearingSale.nextPurchaseNonce(clearingId, other) == 2
                && clearingSale.nextPurchaseNonce(clearingId, payer) == 1
                && clearingSale.nextPurchaseNonce(firstSale, payer) == 3,
            "buyer and sale isolation"
        );
    }
}
