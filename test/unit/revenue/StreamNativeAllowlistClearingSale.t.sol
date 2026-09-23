// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ClearingSaleTestBase.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamNativeAllowlistClearingSale.sol";
import "../../../smart-contracts/domains/mint/StreamMintSaleAllowlist.sol";

interface ClearingAllowlistVm {
    function mockCall(address target, bytes calldata callData, bytes calldata returnData) external;
}

/// @dev Actual clearing consumer/book/recorder/registry/wallet/escrow; existing typed Core,
///      Manager, Artist and governance seams. Only the Manager's counter reads are mocked;
///      its original mint execution still commits the complete supplied MintBatch.
contract StreamNativeAllowlistClearingSaleTest is ClearingSaleTestBase {
    bytes32 private constant PRICE_COUNTER = keccak256("clearing allowlist ceiling");

    function _allowlist() private view returns (IStreamNativeAllowlistClearingSale) {
        return IStreamNativeAllowlistClearingSale(address(clearingSale));
    }

    function _proof(bool hasOverride, uint256 value)
        private
        pure
        returns (IStreamMintCounterPolicy.AllowlistProof memory)
    {
        return IStreamMintCounterPolicy.AllowlistProof(7, hasOverride, value, new bytes32[](0));
    }

    function _data(IStreamMintCounterPolicy.AllowlistProof memory proof)
        private
        pure
        returns (bytes memory)
    {
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        groups[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        groups[0][0] = proof;
        return abi.encode(groups);
    }

    function _leaf(IStreamMintCounterPolicy.AllowlistProof memory proof, address account)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        address(clearingManager),
                        uint256(1),
                        PHASE,
                        PRICE_COUNTER,
                        account,
                        proof.maxCount,
                        proof.hasPriceOverride,
                        proof.priceOverride
                    )
                )
            )
        );
    }

    function _bindRoot(bytes32 root, IStreamMintManager.CounterKeyMode keyMode) private {
        ClearingAllowlistVm calls = ClearingAllowlistVm(address(vm));
        address target = address(clearingManager);
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = PRICE_COUNTER;
        IStreamMintCounterPolicy.Definition memory definition = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.PHASE, keyMode, root, 0
        );
        bytes32 definitionHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition));
        IStreamMintManager.MintCounterConfig memory counter = IStreamMintManager.MintCounterConfig(
            true,
            keyMode,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            definitionHash
        );
        calls.mockCall(
            target,
            abi.encodeWithSelector(IStreamMintReads.phaseCounterIds.selector, uint256(1), PHASE),
            abi.encode(ids)
        );
        calls.mockCall(
            target, abi.encodeWithSelector(IStreamMintReads.mintLedger.selector), abi.encode(target)
        );
        calls.mockCall(
            target,
            abi.encodeWithSelector(
                IStreamMintReads.counterConfig.selector, uint256(1), PHASE, PRICE_COUNTER
            ),
            abi.encode(counter)
        );
        calls.mockCall(
            target,
            abi.encodeWithSelector(
                IStreamMintCounterPolicy.counterDefinitionForManager.selector,
                target,
                definitionHash
            ),
            abi.encode(true, definition)
        );
    }

    function _register(IStreamMintCounterPolicy.AllowlistProof memory proof) private {
        _bindRoot(_leaf(proof, payer), IStreamMintManager.CounterKeyMode.PAYER);
        clearingId = _allowlist().registerAllowlistClearingSale(_clearingConfig(), PRICE_COUNTER);
    }

    function _signed(uint256 number, bool hasOverride, uint256 value)
        private
        returns (IStreamNativeClearingSale.ClearingPurchaseData memory d)
    {
        d = _clearingData(number, payer, payer);
        d.authorization.hasPriceOverride = hasOverride;
        d.authorization.priceOverride = value;
        _signClearing(d);
    }

    function _purchase(
        IStreamNativeClearingSale.ClearingPurchaseData memory d,
        bytes memory data,
        uint256 value
    ) private returns (IStreamNativeClearingSale.ClearingPurchaseResult memory) {
        vm.prank(payer);
        return _allowlist().purchaseWithAllowlist{ value: value }(d, data);
    }

    function _expectedRoot(
        IStreamNativeClearingSale.ClearingPurchaseData memory d,
        bytes memory data
    ) private view returns (bytes32) {
        bytes32 digest = clearingSale.authorizationDigest(d.authorization);
        IStreamMintManager.MintBatch memory batch;
        batch.collectionId = 1;
        batch.phaseId = PHASE;
        batch.payer = d.authorization.payer;
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = d.authorization.recipient;
        batch.beneficiaries = new address[](1);
        batch.beneficiaries[0] = d.authorization.recipient;
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = d.tokenData;
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = d.authorization.mintCommitment;
        batch.expectedPolicyHash = clearingManager.currentPolicy();
        batch.contextHash = digest;
        batch.authorizationId =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
        batch.resolverData = data;
        return keccak256(abi.encode(batch, address(clearingSale), clearingManager.nonce()));
    }

    function _assertUnused(uint256 beforeBalance) private view {
        require(
            clearingManager.nonce() == 0 && payer.balance == beforeBalance, "mint/payment rollback"
        );
        require(
            clearingSale.nextPurchaseNonce(clearingId, payer) == 1
                && clearingSale.financialSale(clearingId).purchasedQuantity == 0,
            "purchase indexes unchanged"
        );
        require(
            !clearingSale.authorizationUsed(artist, bytes32(uint256(1)))
                && clearingSale.executionIdByNonce(clearingId, 1) == 0,
            "replay domains unchanged"
        );
        require(
            wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && refundEntropy.revealFeeEscrow(1) == 0,
            "floor and reveal fee unchanged"
        );
        require(
            clearingSale.totalBuyerLiabilities() == 0 && address(clearingSale).balance == 0
                && clearingSale.refundableBalance(clearingId, payer) == 0,
            "buyer book unchanged"
        );
    }

    function testSameAuthenticatedCeilingBelowThenAboveSchedulePreservesFullBatch() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 500);
        _register(proof);
        bytes memory data = _data(proof);
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, true, 500);
        bytes32 expected = _expectedRoot(d, data);
        IStreamNativeClearingSale.ClearingPurchaseResult memory first = _purchase(d, data, 527);
        require(
            first.chargedAmount == 500 && first.floorRevenue == 100 && first.heldOverage == 400
                && first.revealFeeForwarded == 20 && first.excessCredited == 7,
            "proof ceiling below schedule"
        );
        require(first.operationRoot == expected, "all original signed fields and resolver bytes");
        require(clearingManager.isOperationRootUsed(expected), "same batch executed");
        vm.warp(1070);
        d = _signed(2, true, 500);
        expected = _expectedRoot(d, data);
        IStreamNativeClearingSale.ClearingPurchaseResult memory second = _purchase(d, data, 390);
        require(
            second.chargedAmount == 370 && second.heldOverage == 270, "same leaf above schedule"
        );
        require(
            second.operationRoot == expected && clearingManager.nonce() == 2, "fresh signed mint"
        );
        require(
            wallet.balance == 200 && clearingSale.totalBuyerLiabilities() == 677
                && address(clearingSale).balance == 677,
            "floors overages excess conserved"
        );
    }

    function testValidProofMustMatchBothSignedPriceFieldsAndWritesNothing() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 500);
        _register(proof);
        bytes memory data = _data(proof);
        uint256 beforeBalance = payer.balance;
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, false, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistClearingSale.ClearingAllowlistPriceMismatch.selector,
                true,
                uint256(500),
                false,
                uint256(0)
            )
        );
        _purchase(d, data, 1020);
        _assertUnused(beforeBalance);
        d = _signed(1, true, 501);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistClearingSale.ClearingAllowlistPriceMismatch.selector,
                true,
                uint256(500),
                true,
                uint256(501)
            )
        );
        _purchase(d, data, 521);
        _assertUnused(beforeBalance);
        d = _signed(1, true, 500);
        _purchase(d, data, 520);
        require(clearingManager.nonce() == 1, "fresh exact signature succeeds");
    }

    function testAuthenticatedCapOnlyFallbackRequiresSignedFalseZero() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(false, 0);
        _register(proof);
        bytes memory data = _data(proof);
        uint256 beforeBalance = payer.balance;
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, true, 500);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistClearingSale.ClearingAllowlistPriceMismatch.selector,
                false,
                uint256(0),
                true,
                uint256(500)
            )
        );
        _purchase(d, data, 520);
        _assertUnused(beforeBalance);
        d = _signed(1, false, 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeClearingSale.InvalidClearingSale.selector)
        );
        _purchase(d, data, 1020);
        _assertUnused(beforeBalance);
        d = _signed(1, false, 0);
        d.authorization.unitPrice = 999;
        _signClearing(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingPriceAboveMaximum.selector,
                uint256(999),
                uint256(1000)
            )
        );
        _purchase(d, data, 1020);
        _assertUnused(beforeBalance);
        d.authorization.unitPrice = 1000;
        _signClearing(d);
        IStreamNativeClearingSale.ClearingPurchaseResult memory result = _purchase(d, data, 1020);
        require(result.chargedAmount == 1000 && result.heldOverage == 900, "schedule fallback");
        require(!clearingSale.purchaseRecord(result.purchaseId).hasPriceOverride, "stored absence");
    }

    function testRecipientProofUsesGiftRecipientWhilePayerAndFullBatchRemainBound() public {
        address recipient = address(0xBEEF);
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 500);
        _bindRoot(_leaf(proof, recipient), IStreamMintManager.CounterKeyMode.RECIPIENT);
        clearingId = _allowlist().registerAllowlistClearingSale(_clearingConfig(), PRICE_COUNTER);
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, true, 500);
        bytes memory data = _data(proof);
        uint256 beforeBalance = payer.balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE_COUNTER, payer
            )
        );
        _purchase(d, data, 520);
        _assertUnused(beforeBalance);
        d.authorization.recipient = recipient;
        _signClearing(d);
        bytes32 expected = _expectedRoot(d, data);
        IStreamNativeClearingSale.ClearingPurchaseResult memory result = _purchase(d, data, 520);
        require(
            result.operationRoot == expected && clearingManager.ownerOf(result.tokenId) == recipient
                && clearingManager.lastPayer() == payer,
            "gift subject and payer preserved"
        );
    }

    function testAuthenticatedZeroAndBelowFloorPricesCannotMakeClearingFree() public {
        uint256 beforeBalance = payer.balance;
        for (uint256 i; i < 2; ++i) {
            uint256 price = i == 0 ? 0 : 99;
            IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, price);
            _register(proof);
            IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, true, price);
            vm.expectRevert(
                abi.encodeWithSelector(IStreamNativeClearingSale.InvalidClearingSale.selector)
            );
            _purchase(d, _data(proof), price + 20);
            _assertUnused(beforeBalance);
        }
    }

    function testAuthenticatedFloorPriceHasNoOverageOrSupplement() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 100);
        _register(proof);
        IStreamNativeClearingSale.ClearingPurchaseResult memory result =
            _purchase(_signed(1, true, 100), _data(proof), 120);
        require(result.chargedAmount == 100 && result.heldOverage == 0, "positive floor allowed");
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        require(
            clearingSale.financialSale(clearingId).clearingPrice == 640
                && clearingSale.financialSale(clearingId).scheduledSupplement == 0
                && clearingSale.refundableBalance(clearingId, payer) == 0,
            "floor ceiling preserves schedule reference"
        );
        require(
            wallet.balance == 100 && clearingSale.totalBuyerLiabilities() == 0,
            "floor-only accounting"
        );
    }

    function testAuthenticatedCeilingReplacesSignedMaximumWithExactProofFundingRetry() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 500);
        _register(proof);
        bytes memory data = _data(proof);
        uint256 beforeBalance = payer.balance;
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, true, 500);
        d.authorization.unitPrice = 499;
        _signClearing(d);
        bytes32 exactPurchase = keccak256(abi.encode(d, data));
        bytes32 digest = clearingSale.authorizationDigest(d.authorization);
        bytes32 expected = _expectedRoot(d, data);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingPriceAboveMaximum.selector,
                uint256(499),
                uint256(500)
            )
        );
        _purchase(d, data, 519);
        _assertUnused(beforeBalance);
        IStreamNativeClearingSale.ClearingPurchaseResult memory r = _purchase(d, data, 527);
        require(
            keccak256(abi.encode(d, data)) == exactPurchase && d.authorization.unitPrice == 499,
            "retry must retain every signed and proven byte"
        );
        require(
            r.operationRoot == expected && clearingManager.isOperationRootUsed(expected)
                && clearingManager.lastContextHash() == digest
                && clearingManager.lastAuthorizationId()
                    == keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest)
                    ),
            "original signed ceiling remains in digest and mint request"
        );
        require(
            r.chargedAmount == 500 && r.floorRevenue == 100 && r.heldOverage == 400
                && r.revealFeeForwarded == 20 && r.excessCredited == 7 && wallet.balance == 100
                && recorder.totalOfficialSettled(address(0)) == 100
                && refundEntropy.revealFeeEscrow(1) == 20
                && clearingSale.totalBuyerLiabilities() == 407
                && clearingSale.refundableBalance(clearingId, payer) == 7
                && clearingManager.nonce() == 1,
            "floor, refundable overage, live fee and excess remain separate"
        );
    }

    function testAuthenticatedCeilingDoesNotPermitMutatingTheSignedMaximum() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 500);
        _register(proof);
        bytes memory data = _data(proof);
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, true, 500);
        d.authorization.unitPrice = 499;
        _signClearing(d);
        bytes32 exactPurchase = keccak256(abi.encode(d, data));
        uint256 beforeBalance = payer.balance;
        d.authorization.unitPrice = 498;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingSignatureInvalid.selector, vm.addr(PLATFORM_KEY)
            )
        );
        _purchase(d, data, 520);
        _assertUnused(beforeBalance);
        d.authorization.unitPrice = 499;
        require(keccak256(abi.encode(d, data)) == exactPurchase, "restore original signed bytes");
        require(_purchase(d, data, 520).chargedAmount == 500, "original signature retry");
    }

    function testOrdinarySignedOverrideWithoutMerklePolicyRetainsBothCeilings() public {
        require(_allowlist().allowlistPriceCounter(clearingId) == 0, "ordinary sale profile");
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, true, 500);
        d.authorization.unitPrice = 499;
        _signClearing(d);
        uint256 beforeBalance = payer.balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingPriceAboveMaximum.selector,
                uint256(499),
                uint256(500)
            )
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 520 }(d);
        _assertUnused(beforeBalance);
        d.authorization.unitPrice = 500;
        _signClearing(d);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory r =
            clearingSale.purchase{ value: 520 }(d);
        require(
            r.chargedAmount == 500 && r.floorRevenue == 100 && r.heldOverage == 400,
            "ordinary signed override and signed cap retained"
        );
    }

    function testTamperedProofRejectsThenExactBytesSucceedAndReplayRejects() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 500);
        _register(proof);
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, true, 500);
        bytes memory exact = _data(proof);
        proof.priceOverride = 499;
        uint256 beforeBalance = payer.balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE_COUNTER, payer
            )
        );
        _purchase(d, _data(proof), 520);
        _assertUnused(beforeBalance);
        _purchase(d, exact, 520);
        uint256 afterBalance = payer.balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingAuthorizationUsed.selector,
                artist,
                bytes32(uint256(1))
            )
        );
        _purchase(d, exact, 520);
        require(payer.balance == afterBalance && clearingManager.nonce() == 1, "replay unchanged");
    }

    function testLateMintFailureRollsBackProofBoundFloorBookFeeAndExactRetry() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 500);
        _register(proof);
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, true, 500);
        bytes memory data = _data(proof);
        bytes32 expected = _expectedRoot(d, data);
        uint256 beforeBalance = payer.balance;
        clearingManager.setMode(1);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "mint rejected"));
        _purchase(d, data, 527);
        _assertUnused(beforeBalance);
        require(!clearingManager.isOperationRootUsed(expected), "operation reservation restored");
        clearingManager.setMode(0);
        IStreamNativeClearingSale.ClearingPurchaseResult memory result = _purchase(d, data, 527);
        require(result.operationRoot == expected && result.excessCredited == 7, "exact proof retry");
        require(
            wallet.balance == 100 && clearingSale.totalBuyerLiabilities() == 407,
            "one completed purchase"
        );
    }

    function testPriceFixUsesScheduleAndAuthenticatedCeilingsConserveRebateAndRevenue() public {
        IStreamMintCounterPolicy.AllowlistProof memory first = _proof(true, type(uint256).max);
        IStreamMintCounterPolicy.AllowlistProof memory second = _proof(true, 400);
        bytes32 left = _leaf(first, payer);
        bytes32 right = _leaf(second, payer);
        bytes32 root =
            left < right ? keccak256(abi.encode(left, right)) : keccak256(abi.encode(right, left));
        first.proof = new bytes32[](1);
        first.proof[0] = right;
        second.proof = new bytes32[](1);
        second.proof[0] = left;
        _bindRoot(root, IStreamMintManager.CounterKeyMode.PAYER);
        IStreamNativeClearingSale.ClearingSaleConfig memory config = _clearingConfig();
        config.maxSaleQuantity = 2;
        clearingId = _allowlist().registerAllowlistClearingSale(config, PRICE_COUNTER);
        uint256 beforeBalance = payer.balance;
        IStreamNativeClearingSale.ClearingPurchaseData memory firstData =
            _signed(1, true, type(uint256).max);
        firstData.authorization.unitPrice = 999;
        _signClearing(firstData);
        IStreamNativeClearingSale.ClearingPurchaseResult memory a =
            _purchase(firstData, _data(first), 1027);
        vm.warp(1040);
        IStreamNativeClearingSale.ClearingPurchaseData memory secondData = _signed(2, true, 400);
        secondData.authorization.unitPrice = 399;
        _signClearing(secondData);
        IStreamNativeClearingSale.ClearingPurchaseResult memory b =
            _purchase(secondData, _data(second), 420);
        vm.warp(1050);
        clearingSale.fixClearingPrice(clearingId);
        require(
            clearingSale.financialSale(clearingId).clearingPrice == 640,
            "sold-out schedule reference"
        );
        require(clearingSale.financialSale(clearingId).scheduledSupplement == 840, "540 plus 300");
        require(clearingSale.refundableBalance(clearingId, payer) == 367, "rebate360 plus excess7");
        require(
            clearingSale.purchaseRecord(a.purchaseId).priceOverride == type(uint256).max
                && clearingSale.purchaseRecord(b.purchaseId).priceOverride == 400,
            "authenticated original full-width ceilings retained"
        );
        vm.prank(payer);
        require(clearingSale.claimRefund(clearingId, payer) == 367, "permanent rebate claimed");
        require(
            clearingSale.settlePurchaseSupplement(a.purchaseId).amount == 540, "first supplement"
        );
        require(
            clearingSale.settlePurchaseSupplement(b.purchaseId).amount == 300, "second supplement"
        );
        require(
            wallet.balance == 1040 && recorder.totalOfficialSettled(address(0)) == 1040
                && refundEntropy.revealFeeEscrow(1) == 40 && clearingManager.nonce() == 2,
            "actual revenue and one fee per mint"
        );
        require(
            clearingSale.totalBuyerLiabilities() == 0 && address(clearingSale).balance == 0
                && beforeBalance - payer.balance == 1080,
            "paid equals revenue plus reveal fees after rebate"
        );
    }

    function testAllowlistConfigHashAndEntryBoundariesPreventUnprovenPriceBypass() public {
        bytes32 ordinaryId = clearingId;
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 500);
        _register(proof);
        IStreamNativeClearingSale.ClearingSaleRecord memory record =
            clearingSale.saleRecord(clearingId);
        bytes32 original = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_CONFIG_V1"),
                clearingId,
                record.config,
                record.priceScheduleHash,
                record.windowPolicyHash,
                record.expectedPrimaryPolicyHash,
                address(0)
            )
        );
        require(
            record.configHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_ALLOWLIST_CLEARING_CONFIG_V1"),
                        original,
                        PRICE_COUNTER
                    )
                ),
            "exact wrapped original configuration"
        );
        require(
            _allowlist().allowlistPriceCounter(clearingId) == PRICE_COUNTER,
            "counter policy retained"
        );
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _signed(1, true, 500);
        uint256 beforeBalance = payer.balance;
        vm.expectRevert();
        vm.prank(payer);
        clearingSale.purchase{ value: 520 }(d);
        _assertUnused(beforeBalance);
        vm.expectRevert();
        _purchase(d, "", 520);
        _assertUnused(beforeBalance);
        IStreamNativeClearingSale.ClearingSaleConfig memory config = _clearingConfig();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistClearingSale.InvalidClearingAllowlistPolicy.selector
            )
        );
        _allowlist().registerAllowlistClearingSale(config, 0);
        clearingId = ordinaryId;
        d = _signed(1, true, 500);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistClearingSale.InvalidClearingAllowlistPolicy.selector
            )
        );
        _purchase(d, _data(proof), 520);
        _assertUnused(beforeBalance);
        vm.prank(payer);
        clearingSale.purchase{ value: 520 }(d);
        require(clearingManager.nonce() == 1, "original signed sale remains supported");
    }
}
