// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

/// @dev Literal prior physical slots are an encoding bridge, not an upgrade/deployment claim.
contract StreamNativeClearingSparseRecordsTest is ClearingSaleTestBase {
    function _expected(
        IStreamNativeClearingSale.ClearingPurchaseData memory d,
        IStreamNativeClearingSale.ClearingPurchaseResult memory p
    ) private view returns (IStreamNativeClearingSale.ClearingPurchaseRecord memory e) {
        IStreamNativeClearingSale.ClearingSaleRecord memory s = clearingSale.saleRecord(clearingId);
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c;
        c.saleAdapter = address(clearingSale);
        c.executor = d.authorization.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            clearingId,
            CLASS,
            0,
            s.config.collectionId,
            0,
            s.saleNonce,
            d.authorization.payer,
            address(0),
            d.authorization.recipient,
            s.config.schedule.restingPrice,
            d.authorization.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = s.lifecycle;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            p.executionId,
            d.authorization.executionNonce,
            1,
            clearingSale.authorizationDigest(d.authorization)
        );
        c.orchestrationOrder = 1;
        c.mintManager = address(clearingManager);
        c.operationIdentityCommitment = p.operationRoot;
        c.operationId = p.operationId;
        c.currentPolicyHash = s.config.mintPolicyHash;
        c.boundPolicyHash = s.config.mintPolicyHash;
        StreamSaleTemplate.Selection memory selected =
            StreamNativeSettlementSupport.rights(resolver, 1);
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            selected.profileId,
            selected.wallet,
            selected.templateId,
            selected.assignmentHash,
            selected.entriesHash
        );
        c.saleExecutionHash = keccak256(abi.encode(d));
        bytes32 commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SETTLEMENT_CANDIDATE_V1"),
                block.chainid,
                address(recorder),
                c
            )
        );
        e = IStreamNativeClearingSale.ClearingPurchaseRecord(
            c,
            p.settlementKey,
            commitment,
            p.tokenId,
            d.authorization.purchaseNonce,
            uint64(block.timestamp),
            d.authorization.hasPriceOverride,
            d.authorization.priceOverride
        );
    }

    function _base(bytes32 purchaseId) private pure returns (uint256) {
        // Accepted32199: _state slot5 + State.purchases offset9.
        return uint256(keccak256(abi.encode(purchaseId, uint256(14))));
    }

    function _word(uint256 base, uint256 offset, uint256 value) private {
        vm.store(address(clearingSale), bytes32(base + offset), bytes32(value));
    }

    function testSparseFullTupleAndOfficialCommitmentRemainHistoricalWithUnavailableProviders()
        external
    {
        address beneficiary = address(0xBEEF);
        IStreamNativeClearingSale.ClearingPurchaseData memory d =
            _clearingData(71, payer, beneficiary);
        d.authorization.hasPriceOverride = true;
        d.authorization.priceOverride = type(uint256).max - 7;
        _signClearing(d);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1027 }(d);
        IStreamNativeClearingSale.ClearingPurchaseRecord memory expected = _expected(d, p);
        bytes32 recordHash = keccak256(abi.encode(expected));
        require(
            keccak256(abi.encode(clearingSale.purchaseRecord(p.purchaseId))) == recordHash,
            "every full field reconstructed exactly"
        );
        require(
            recorder.settlementResult(p.settlementKey).candidateCommitment
                == expected.floorCandidateCommitment,
            "independent candidate preimage equals official stored floor"
        );
        require(
            vm.load(address(clearingSale), bytes32(_base(p.purchaseId))) == 0
                && vm.load(address(clearingSale), bytes32(_base(p.purchaseId) + 32)) == 0,
            "explicit sparse discriminator and omitted duplicate nonce"
        );
        require(
            clearingSale.clearingPurchaseFacts(p.purchaseId).purchaseNonce == 1
                && expected.priceOverride > type(uint96).max
                && expected.originalFloor.sale.beneficiary != payer,
            "wide signed fact and distinct beneficiary preserved"
        );
        uint256 snapshot = vm.snapshotState();
        clearingManager.setUnavailable(true);
        clearingManager.setPolicy(keccak256("later policy"), 0, 0);
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(0));
        refundCore.setPointer(keccak256("MODULE_REGISTRY"), address(0));
        refundEntropy.setModes(1, 1);
        vm.warp(1700);
        require(
            keccak256(abi.encode(clearingSale.purchaseRecord(p.purchaseId))) == recordHash,
            "no providers current policy or clock in historical reconstruction"
        );
        IStreamNativeClearingSale.ClearingPurchaseRecord memory absent;
        require(
            keccak256(abi.encode(clearingSale.purchaseRecord(bytes32(uint256(999)))))
                == keccak256(abi.encode(absent)),
            "unknown record remains wholly zero"
        );
        require(vm.revertToState(snapshot), "restore dependency control");
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(clearingSale.totalBuyerLiabilities() == 540, "permanent rebate and excess claimed");
        refundCore.setPointer(keccak256("MODULE_REGISTRY"), address(0));
        vm.expectRevert();
        clearingSale.settlePurchaseSupplement(p.purchaseId);
        require(
            clearingSale.totalBuyerLiabilities() == 540 && wallet.balance == 100
                && !recorder.supplementalPurchaseConsumed(
                    recorder.supplementalPurchaseKey(address(clearingSale), p.purchaseId)
                ),
            "failed same leg restores credit and official replay"
        );
        refundCore.setPointer(keccak256("MODULE_REGISTRY"), address(registry));
        clearingSale.settlePurchaseSupplement(p.purchaseId);
        require(
            wallet.balance == 640 && clearingSale.totalBuyerLiabilities() == 0
                && keccak256(abi.encode(clearingSale.purchaseRecord(p.purchaseId))) == recordHash,
            "identical leg succeeds and terminal history remains exact"
        );
    }

    function testLiteralPriorFullEncodingReturnsVerbatimAndSettlesSameOfficialFloor() external {
        IStreamNativeClearingSale.ClearingPurchaseData memory d =
            _clearingData(19, payer, address(0xBEEF));
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1020 }(d);
        IStreamNativeClearingSale.ClearingPurchaseRecord memory e = _expected(d, p);
        uint256 base = _base(p.purchaseId);
        _word(base, 0, uint160(address(clearingSale)));
        _word(base, 1, uint160(payer));
        _word(base, 3, uint256(CLASS));
        _word(base, 5, e.originalFloor.sale.collectionId);
        _word(base, 7, e.originalFloor.sale.saleNonce);
        _word(base, 8, uint160(payer));
        _word(base, 11, e.originalFloor.sale.amount);
        _word(
            base,
            13,
            uint256(e.originalFloor.lifecycleBinding.saleCreatedAt)
                | (uint256(e.originalFloor.lifecycleBinding.saleAdapterRegistryRevision) << 64)
        );
        _word(base, 16, 1);
        _word(base, 18, 1 | (uint256(uint160(address(clearingManager))) << 8));
        _word(base, 21, uint256(e.originalFloor.currentPolicyHash));
        _word(base, 22, uint256(e.originalFloor.boundPolicyHash));
        _word(base, 32, e.purchaseNonce);
        require(
            keccak256(abi.encode(clearingSale.purchaseRecord(p.purchaseId)))
                == keccak256(abi.encode(e)),
            "literal old full slot catalog and new sparse tuple exact"
        );
        require(
            recorder.settlementResult(p.settlementKey).candidateCommitment
                == e.floorCandidateCommitment,
            "same original official commitment across storage encodings"
        );
        _word(base, 1, uint160(address(0xCAFE)));
        require(
            clearingSale.purchaseRecord(p.purchaseId).originalFloor.executor == address(0xCAFE),
            "legacy full returned verbatim rather than reconstructed"
        );
        _word(base, 1, uint160(payer));
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        clearingSale.settlePurchaseSupplement(p.purchaseId);
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(
            wallet.balance == 640 && clearingSale.totalBuyerLiabilities() == 0
                && clearingSale.clearingPurchaseFacts(p.purchaseId).purchaseNonce == 1,
            "old full encoding financial and refund conservation"
        );
    }
}
