// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamNativeAllowlistRefundWindowSale.sol";
import "../../../smart-contracts/domains/mint/StreamMintSaleAllowlist.sol";

interface RefundAllowlistReadVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
}

/// @dev Actual refund book/consumer/recorder/wallet/escrow with the established typed
///      Manager/Core/Artist seams. Exact counter-read mocks do not prove actual mint cap writes.
contract StreamNativeAllowlistRefundWindowSaleTest is RefundWindowTestBase {
    bytes32 private constant PRICE_COUNTER = keccak256("refund saved price counter");
    bytes32 private _boundDefinitionHash;

    function _allowlist() private view returns (IStreamNativeAllowlistRefundWindowSale) {
        return IStreamNativeAllowlistRefundWindowSale(address(refundSale));
    }

    function _proof(bool overridden, uint256 price)
        private
        pure
        returns (IStreamMintCounterPolicy.AllowlistProof memory)
    {
        return IStreamMintCounterPolicy.AllowlistProof(7, overridden, price, new bytes32[](0));
    }

    function _data(IStreamMintCounterPolicy.AllowlistProof memory p)
        private
        pure
        returns (bytes memory)
    {
        IStreamMintCounterPolicy.AllowlistProof[][] memory groups =
            new IStreamMintCounterPolicy.AllowlistProof[][](1);
        groups[0] = new IStreamMintCounterPolicy.AllowlistProof[](1);
        groups[0][0] = p;
        return abi.encode(groups);
    }

    function _bind(IStreamMintCounterPolicy.AllowlistProof memory p)
        private
        returns (bytes32 hash)
    {
        bytes32 root = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
                        block.chainid,
                        address(refundManager),
                        uint256(1),
                        PHASE,
                        PRICE_COUNTER,
                        payer,
                        p.maxCount,
                        p.hasPriceOverride,
                        p.priceOverride
                    )
                )
            )
        );
        IStreamMintCounterPolicy.Definition memory definition = IStreamMintCounterPolicy.Definition(
            IStreamMintCounterPolicy.CounterScope.PHASE,
            IStreamMintManager.CounterKeyMode.PAYER,
            root,
            0
        );
        hash = keccak256(abi.encode(keccak256("6529STREAM_MINT_COUNTER_DEFINITION_V1"), definition));
        _boundDefinitionHash = hash;
        IStreamMintManager.MintCounterConfig memory counter = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.MERKLE_STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            hash
        );
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = PRICE_COUNTER;
        RefundAllowlistReadVm reads = RefundAllowlistReadVm(address(vm));
        address target = address(refundManager);
        reads.mockCall(
            target,
            abi.encodeCall(IStreamMintReads.phaseCounterIds, (uint256(1), PHASE)),
            abi.encode(ids)
        );
        reads.mockCall(target, abi.encodeCall(IStreamMintReads.mintLedger, ()), abi.encode(target));
        reads.mockCall(
            target,
            abi.encodeCall(IStreamMintReads.counterConfig, (uint256(1), PHASE, PRICE_COUNTER)),
            abi.encode(counter)
        );
        reads.mockCall(
            target,
            abi.encodeCall(IStreamMintCounterPolicy.counterDefinitionForManager, (target, hash)),
            abi.encode(true, definition)
        );
    }

    function _register(IStreamMintCounterPolicy.AllowlistProof memory p, bool allowFree) private {
        _bind(p);
        refundId = _allowlist()
            .registerAllowlistRefundSale(
                _refundConfig(),
                IStreamNativeAllowlistRefundWindowSale.AllowlistPricePolicy(
                    PRICE_COUNTER, allowFree
                )
            );
    }

    function _buy(
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d,
        bytes memory data,
        uint256 value
    ) private returns (bytes32) {
        vm.prank(d.authorization.payer);
        return _allowlist().purchaseAllowlistRefundWindow{ value: value }(d, data);
    }

    function _buyOne(IStreamMintCounterPolicy.AllowlistProof memory p, uint256 value)
        private
        returns (bytes32)
    {
        return _buy(_purchaseData(1, payer, payer), _data(p), value);
    }

    function _assertPending(bytes32 id, uint256 price, uint256 excess) private view {
        require(refundSale.refundPurchaseRecord(id).status == 1, "pending status");
        require(refundSale.totalPendingDeposits() == price + 100, "captured price plus saved fee");
        require(
            refundSale.totalBuyerLiabilities() == price + 100 + excess,
            "pending and excess liabilities"
        );
        require(
            address(refundSale).balance == price + 100 + excess
                && refundSale.refundCredit(payer) == excess,
            "pending funds"
        );
        require(
            refundManager.nonce() == 0 && wallet.balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && refundEntropy.revealFeeEscrow(1) == 0,
            "no premature mint revenue or fee"
        );
    }

    function _assertUnused(uint256 balance) private view {
        require(
            payer.balance == balance && refundSale.nextPurchaseNonce(refundId, payer) == 1,
            "no payer debit or nonce"
        );
        require(
            !refundSale.purchaseAuthorizationUsed(artist, bytes32(uint256(1)))
                && refundSale.refundSaleRecord(refundId).purchasedQuantity == 0,
            "no replay or quantity"
        );
        require(
            refundSale.totalBuyerLiabilities() == 0 && refundSale.totalPendingDeposits() == 0
                && address(refundSale).balance == 0,
            "no liabilities"
        );
        require(
            refundManager.nonce() == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && refundEntropy.revealFeeEscrow(1) == 0,
            "no external effects"
        );
    }

    function _expectedRoot(bytes32 id, bytes memory proof) private view returns (bytes32) {
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p =
            refundSale.refundPurchaseRecord(id);
        IStreamMintManager.MintBatch memory b;
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = p.authorization.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = p.authorization.recipient;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = p.authorization.recipient;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = p.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = p.authorization.mintCommitment;
        b.expectedPolicyHash = refundSale.refundSaleRecord(refundId).config.mintPolicyHash;
        b.contextHash = p.authorizationDigest;
        b.authorizationId = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), p.authorizationDigest)
        );
        b.resolverData = proof;
        return keccak256(abi.encode(b, address(refundSale), refundManager.nonce()));
    }

    function _originalRecordHash(
        bytes32 id,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFUND_PURCHASE_RECORD_V1"),
                block.chainid,
                address(refundSale),
                id,
                p.authorization,
                p.authorizationDigest,
                IStreamNativeRefundWindowSale.PurchaseCapture(
                    p.savedRevealFee,
                    p.artistId,
                    p.bindingGeneration,
                    p.bindingHash,
                    p.referencedGate
                ),
                p.purchasedAt,
                p.pauseBaseline,
                p.nominalRefundDeadline,
                p.nominalFinalizeBy
            )
        );
    }

    function testConfigAndPurchaseHashesBindSeparatePriceWithoutChangingAuthorization() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 600);
        _register(proof, false);
        IStreamNativeRefundWindowSale.RefundSaleRecord memory saleRecord =
            refundSale.refundSaleRecord(refundId);
        bytes32 original = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_REFUND_SALE_CONFIG_V1"),
                refundId,
                saleRecord.config,
                saleRecord.expectedPrimaryPolicyHash
            )
        );
        IStreamNativeAllowlistRefundWindowSale.AllowlistPricePolicy memory policy =
            _allowlist().allowlistRefundSalePolicy(refundId);
        require(policy.counterId == PRICE_COUNTER && !policy.allowFree, "immutable price policy");
        require(
            saleRecord.configHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_ALLOWLIST_REFUND_CONFIG_V1"), original, policy
                    )
                ),
            "config wrapper"
        );
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        bytes32 digest = refundSale.refundPurchaseAuthorizationDigest(d.authorization);
        bytes memory data = _data(proof);
        bytes32 id = _buy(d, data, 725);
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p =
            refundSale.refundPurchaseRecord(id);
        require(
            keccak256(abi.encode(p.authorization)) == keccak256(abi.encode(d.authorization))
                && p.authorization.price == 1000 && p.authorizationDigest == digest,
            "original commercial signature unchanged"
        );
        (bool captured, uint256 price, bytes32 proofHash) =
            _allowlist().refundPurchasePriceFacts(id);
        require(captured && price == 600 && proofHash == keccak256(data), "separate captured facts");
        require(
            keccak256(_allowlist().refundPurchaseResolverData(id)) == proofHash, "exact saved bytes"
        );
        require(
            p.purchaseRecordHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_REFUND_ALLOWLIST_PURCHASE_RECORD_V1"),
                        _originalRecordHash(id, p),
                        uint256(600),
                        proofHash
                    )
                ),
            "wrapped complete record"
        );
        _assertPending(id, 600, 25);
    }

    function testExactAbovePublicPriceAndFullWidthValuesRemainRefundable() public {
        uint256[2] memory prices = [uint256(1400), uint256(1) << 200];
        for (uint256 i; i < prices.length; ++i) {
            uint256 price = prices[i];
            IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, price);
            _register(proof, false);
            vm.deal(payer, price + 100);
            bytes32 id = _buy(_purchaseData(i + 1, payer, payer), _data(proof), price + 100);
            (, uint256 charged,) = _allowlist().refundPurchasePriceFacts(id);
            require(
                charged == price && refundSale.refundPurchaseRecord(id).authorization.price == 1000,
                "full-width exact price without signature rewrite"
            );
            vm.prank(payer);
            refundSale.refundPurchase(id);
            vm.prank(payer);
            require(
                refundSale.claimRefund(refundId, payable(payer)) == price + 100,
                "full-width price plus saved fee"
            );
            require(
                refundSale.totalBuyerLiabilities() == 0 && address(refundSale).balance == 0,
                "no narrowed residual"
            );
        }
    }

    function testNoOverrideUsesPublicPriceAndOrdinaryPriceFactsStayAbsent() public {
        bytes32 ordinary = refundId;
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(false, 0);
        _register(proof, false);
        bytes32 id = _buyOne(proof, 1100);
        (bool captured, uint256 price,) = _allowlist().refundPurchasePriceFacts(id);
        require(captured && price == 1000, "cap-only captured fallback");
        _assertPending(id, 1000, 0);
        (captured, price,) = _allowlist().refundPurchasePriceFacts(keccak256("absent"));
        require(
            !captured && price == 0
                && _allowlist().allowlistRefundSalePolicy(ordinary).counterId == 0,
            "optional facts absent"
        );
    }

    function testFinalizationUsesSavedPriceAndProofWithoutAnotherSalePriceRead() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 600);
        _register(proof, false);
        bytes memory data = _data(proof);
        bytes32 id = _buyOne(proof, 725);
        bytes32 expected = _expectedRoot(id, data);
        // The typed Manager independently commits all batch bytes. Its real cap verifier is
        // covered in mint tests; here this poison proves the sale never reruns its price read.
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                address(refundManager),
                0,
                abi.encodeCall(
                    IStreamMintCounterPolicy.counterDefinitionForManager,
                    (address(refundManager), _boundDefinitionHash)
                ),
                hex"cafe"
            );
        vm.expectRevert(hex"cafe");
        IStreamMintCounterPolicy(address(refundManager))
            .counterDefinitionForManager(address(refundManager), _boundDefinitionHash);
        _atRefundEnd(id);
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
            refundSale.finalizeRefundWindow(id);
        require(
            r.amount == 600 && r.operationRoot == expected && wallet.balance == 600,
            "captured exact price and resolver mint"
        );
        require(
            r.revealFeeForwarded == 100 && refundEntropy.revealFeeEscrow(1) == 100
                && refundSale.refundCredit(payer) == 25,
            "fee and excess separate"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 600
                && refundSale.totalPendingDeposits() == 0
                && refundSale.totalBuyerLiabilities() == 25,
            "only actual price official"
        );
        require(
            keccak256(abi.encode(refundSale.finalizeRefundWindow(id))) == keccak256(abi.encode(r))
                && refundManager.nonce() == 1,
            "idempotent stored result"
        );
    }

    function testRefundConservesCapturedPriceFeeExcessAndForcedSurplus() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 600);
        _register(proof, false);
        vm.deal(address(refundSale), 77);
        uint256 beforeBalance = payer.balance;
        bytes32 id = _buyOne(proof, 725);
        vm.prank(payer);
        refundSale.refundPurchase(id);
        require(
            refundSale.refundCredit(payer) == 725 && refundSale.totalPendingDeposits() == 0,
            "all buyer-funded parts credited"
        );
        vm.prank(payer);
        refundSale.refundPurchase(id);
        vm.prank(payer);
        require(refundSale.claimRefund(refundId, payable(payer)) == 725, "once-only full claim");
        require(
            payer.balance == beforeBalance && address(refundSale).balance == 77
                && refundSale.totalBuyerLiabilities() == 0,
            "surplus excluded"
        );
        require(
            wallet.balance == 0 && refundManager.nonce() == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "refund never official"
        );
    }

    function testLateMintFailureRestoresCapturedPriceReplayAndExactRetry() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 600);
        _register(proof, false);
        bytes32 id = _buyOne(proof, 725);
        bytes32 expected = _expectedRoot(id, _data(proof));
        _atRefundEnd(id);
        refundManager.setMode(1);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "mint rejected"));
        refundSale.finalizeRefundWindow(id);
        _assertPending(id, 600, 25);
        require(
            !recorder.deferredPurchaseConsumed(
                    recorder.deferredPurchaseKey(address(refundSale), id)
                ),
            "recorder replay rollback"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundPurchaseUnavailable.selector, id
            )
        );
        refundSale.activeDeferredNativeSettlement(id);
        refundManager.setMode(0);
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
            refundSale.finalizeRefundWindow(id);
        require(
            r.amount == 600 && r.operationRoot == expected && refundManager.nonce() == 1,
            "same purchase/proof exact retry"
        );
    }

    function testUndeclaredZeroAndTamperedProofRejectWithoutCapture() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 0);
        _register(proof, false);
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        uint256 balance = payer.balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistRefundWindowSale.RefundPriceOverrideZeroUndeclared.selector,
                refundId
            )
        );
        _buy(d, _data(proof), 100);
        _assertUnused(balance);
        proof.priceOverride = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE_COUNTER, payer
            )
        );
        _buy(d, _data(proof), 101);
        _assertUnused(balance);
    }

    function testDeclaredFreeCapturesFeeOnlyAndRefundsItWithExcess() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 0);
        _register(proof, true);
        uint256 balance = payer.balance;
        bytes32 id = _buyOne(proof, 125);
        _assertPending(id, 0, 25);
        vm.prank(payer);
        refundSale.refundPurchase(id);
        vm.prank(payer);
        require(
            refundSale.claimRefund(refundId, payable(payer)) == 125, "fee-only purchase refundable"
        );
        require(
            payer.balance == balance && refundSale.totalBuyerLiabilities() == 0,
            "fee-only conservation"
        );
    }

    function testFreeFinalizationSkipsPoisonedRightsAndOfficialRevenueKeepsFeeAndReplay() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 0);
        _register(proof, true);
        bytes32 id = _buyOne(proof, 109);
        bytes32 expected = _expectedRoot(id, _data(proof));
        uint256 profiles = factory.profileCount();
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                address(resolver),
                0,
                abi.encodeCall(
                    IStreamRevenueResolver.resolvePrimaryAssignment, (uint256(1), uint256(0), CLASS)
                ),
                hex"cafe"
            );
        refundEntropy.setPolicy(true, 1, 40);
        _atRefundEnd(id);
        vm.recordLogs();
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
            refundSale.finalizeRefundWindow(id);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            require(logs[i].emitter != address(recorder), "free emits no recorder events");
        }
        require(
            r.amount == 0 && r.settlementKey == 0 && !r.escrowed && r.operationRoot == expected
                && r.tokenId == 1,
            "free mint exact result"
        );
        require(
            r.revealFeeForwarded == 40 && r.revealFeeRefunded == 60
                && refundSale.refundCredit(payer) == 69,
            "fee remainder plus excess"
        );
        require(
            wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && factory.profileCount() == profiles,
            "no official payment or materialization"
        );
        require(
            !recorder.deferredPurchaseConsumed(
                recorder.deferredPurchaseKey(address(refundSale), id)
            ),
            "no official deferred replay lane"
        );
        require(
            keccak256(abi.encode(refundSale.finalizeRefundWindow(id))) == keccak256(abi.encode(r))
                && refundManager.nonce() == 1,
            "free local replay remains closed"
        );
        vm.prank(payer);
        refundSale.claimRefund(refundId, payable(payer));
        require(
            refundSale.totalBuyerLiabilities() == 0 && address(refundSale).balance == 0
                && refundEntropy.revealFeeEscrow(1) == 40,
            "free fee conservation"
        );
    }

    function _breakProviders() private {
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(0));
        refundCore.setPointer(keccak256("MODULE_REGISTRY"), address(0));
        refundCore.setPointer(keccak256("ENTROPY_COORDINATOR"), address(0));
        refundManager.setUnavailable(true);
        refundEntropy.setPolicy(false, 9, type(uint256).max);
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                address(refundManager),
                0,
                abi.encodeCall(
                    IStreamMintCounterPolicy.counterDefinitionForManager,
                    (address(refundManager), _boundDefinitionHash)
                ),
                hex"cafe"
            );
    }

    function testFreeFinalizationRetainsPauseArtistPhaseAndAdmissionGuards() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 0);
        _register(proof, true);
        bytes32 id = _buyOne(proof, 100);
        _atRefundEnd(id);
        _pauseGlobal(true);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.SaleEntryPaused.selector)
        );
        refundSale.finalizeRefundWindow(id);
        _assertPending(id, 0, 0);
        _pauseGlobal(false);
        refundArtist.setAssociation(
            2, 1, keccak256("refund artist identity"), 2, keccak256("refund artist binding")
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
        );
        refundSale.finalizeRefundWindow(id);
        _assertPending(id, 0, 0);
        refundArtist.setAssociation(
            2, 1, keccak256("refund artist identity"), 1, keccak256("refund artist binding")
        );
        refundManager.setPhase(true, 20_000_000, true);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "phase closed"));
        refundSale.finalizeRefundWindow(id);
        _assertPending(id, 0, 0);
        refundManager.setPhase(false, 20_000_000, true);
        _status(address(refundSale), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamDeferredNativeSettlementAdmission.SettlementModuleNotAdmitted.selector,
                address(refundSale)
            )
        );
        refundSale.finalizeRefundWindow(id);
        _assertPending(id, 0, 0);
    }

    function testProviderFailureCannotBlockPaidRefundWithinWindow() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 600);
        _register(proof, false);
        bytes32 id = _buyOne(proof, 725);
        _breakProviders();
        vm.prank(payer);
        refundSale.refundPurchase(id);
        vm.prank(payer);
        require(refundSale.claimRefund(refundId, payable(payer)) == 725, "refund ignores providers");
        require(
            refundSale.totalBuyerLiabilities() == 0 && refundManager.nonce() == 0, "terminal refund"
        );
    }

    function testProviderFailureCannotBlockTimeEscapeOfFreeFeeDeposit() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 0);
        _register(proof, true);
        bytes32 id = _buyOne(proof, 125);
        uint64 escape = refundSale.refundPurchaseRecord(id).authorization.absoluteEscapeDeadline;
        _breakProviders();
        vm.warp(escape + 1);
        refundSale.unlockRefund(id, 0);
        vm.prank(payer);
        require(
            refundSale.claimRefund(refundId, payable(payer)) == 125, "time escape ignores providers"
        );
        require(
            refundSale.refundPurchaseRecord(id).status == 4
                && refundSale.totalBuyerLiabilities() == 0,
            "fee-only terminal unlock"
        );
    }

    function _counterValue(bytes32 id, uint64 value) private {
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p =
            refundSale.refundPurchaseRecord(id);
        bytes32 subject = keccak256("typed saved payer subject");
        bytes32 key = keccak256("typed saved payer counter key");
        RefundAllowlistReadVm reads = RefundAllowlistReadVm(address(vm));
        address target = address(refundManager);
        reads.mockCall(
            target,
            abi.encodeCall(
                IStreamMintReads.previewSubjectKey,
                (
                    IStreamMintManager.CounterKeyMode.PAYER,
                    uint256(1),
                    PHASE,
                    PRICE_COUNTER,
                    payer,
                    payer,
                    address(refundSale),
                    address(0),
                    p.authorizationDigest
                )
            ),
            abi.encode(subject)
        );
        reads.mockCall(
            target,
            abi.encodeCall(
                IStreamMintReads.previewCounterValueKey, (uint256(1), PHASE, PRICE_COUNTER, subject)
            ),
            abi.encode(key)
        );
        reads.mockCall(
            target, abi.encodeCall(IStreamMintLedger.counterValue, (key)), abi.encode(value)
        );
    }

    function testSavedMerkleCapExhaustionUnlocksAtLeafLimitNotStaticCeiling() public {
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 600);
        _register(proof, false);
        bytes32 id = _buyOne(proof, 725);
        _counterValue(id, 6);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundUnlockNotAvailable.selector, id, uint8(2)
            )
        );
        refundSale.unlockRefund(id, 2);
        _assertPending(id, 600, 25);
        _counterValue(id, 7);
        _bind(_proof(true, 601));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintSaleAllowlist.InvalidSaleAllowlistProof.selector, PRICE_COUNTER, payer
            )
        );
        refundSale.unlockRefund(id, 2);
        _assertPending(id, 600, 25);
        _bind(proof);
        refundSale.unlockRefund(id, 2);
        require(
            refundSale.refundPurchaseRecord(id).status == 4 && refundSale.refundCredit(payer) == 725
                && refundSale.totalPendingDeposits() == 0,
            "saved cap seven exhausted before static ten"
        );
    }

    function testProofEntryPolicyBoundaryAndReplayStayClosed() public {
        bytes32 ordinary = refundId;
        IStreamMintCounterPolicy.AllowlistProof memory proof = _proof(true, 600);
        _register(proof, false);
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        uint256 balance = payer.balance;
        vm.expectRevert();
        vm.prank(payer);
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
        _assertUnused(balance);
        vm.expectRevert();
        _buy(d, "", 700);
        _assertUnused(balance);
        bytes32 id = _buy(d, _data(proof), 700);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundPurchaseAlreadyUsed.selector, id
            )
        );
        _buy(d, _data(proof), 700);
        require(
            refundSale.totalPendingDeposits() == 700
                && refundSale.nextPurchaseNonce(refundId, payer) == 2,
            "one capture only"
        );
        refundId = ordinary;
        d = _purchaseData(2, payer, payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistRefundWindowSale.InvalidAllowlistRefundPolicy.selector
            )
        );
        _buy(d, _data(proof), 700);
        IStreamNativeRefundWindowSale.RefundSaleConfig memory config = _refundConfig();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeAllowlistRefundWindowSale.InvalidAllowlistRefundPolicy.selector
            )
        );
        _allowlist()
            .registerAllowlistRefundSale(
                config, IStreamNativeAllowlistRefundWindowSale.AllowlistPricePolicy(0, true)
            );
    }
}
