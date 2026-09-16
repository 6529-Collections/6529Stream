// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./helpers/NativeCuratedSaleFixture.sol";

/// @dev Late callback actor only. It checks actual Core ownership and recorder payment before acting.
contract CuratedSettlementReceiver {
    address private immutable core;
    address private immutable recorder;
    address private immutable adapter;
    address private immutable artistBoundary;
    bytes32 private immutable purchase;
    uint256 private immutable price;
    uint8 public mode;
    bool public observed;

    constructor(address c, address r, address sale, address artist, bytes32 id, uint256 amount) {
        core = c;
        recorder = r;
        adapter = sale;
        artistBoundary = artist;
        purchase = id;
        price = amount;
    }

    function setMode(uint8 value) external {
        mode = value;
    }

    function onERC721Received(address, address, uint256 token, bytes calldata)
        external
        returns (bytes4)
    {
        require(
            msg.sender == core && IStreamCore(core).ownerOf(token) == address(this),
            "actual delivered ownership"
        );
        require(
            IStreamPreparedNativeContentPurchaseSettlement(recorder)
                .preparedNativeContentPurchaseConsumed(adapter, purchase),
            "actual purchase debit first"
        );
        require(
            StreamPrimarySaleSettlement(recorder).totalOfficialSettled(address(0)) == price,
            "actual official revenue first"
        );
        if (mode == 1) revert("late receiver refusal");
        if (mode == 2) NativeCuratedArtistBoundary(artistBoundary).setConsent(false);
        observed = true;
        return 0x150b7a02;
    }
}

/// @notice Actual current Core/Manager/Ledger/recorder, split wallet and Safe composition.
/// @dev Inherited explicit Artist/entropy/governance boundaries remain; this is not full onboarding.
contract StreamCurrentCuratedPurchaseSettlementTest is NativeCuratedSaleFixture {
    function _purchase(CuratedPlan memory p, address buyer, uint256 nonce)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                p.adapter,
                p.saleId,
                buyer,
                nonce
            )
        );
    }

    function _oldSale(CuratedPlan memory p) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_SALE_KEY_V1"),
                block.chainid,
                address(recorder),
                p.adapter,
                p.saleId,
                p.nonce
            )
        );
    }

    function _publicPlan() private returns (CuratedPlan memory p) {
        _deployCuratedFixed();
        p = _curatedPlan(address(fixedSale), 0, Curated.SelectionMode.PUBLIC);
        _openCuratedFixed(p, Curated.SelectionMode.PUBLIC);
        vm.warp(p.config.startsAt);
    }

    function _assertOriginalRecords(
        Vm.Log[] memory logs,
        CuratedPlan memory p,
        Curated.ExecutionRecord memory e,
        bytes32 purchase
    ) private view {
        bytes32 originalTopic = keccak256(
            "PreparedNativeRevenueRecorded(bytes32,bytes32,bytes32,(address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32))"
        );
        bytes32 purchaseTopic = keccak256(
            "PreparedNativeContentPurchaseRecorded(uint16,address,bytes32,bytes32,bytes32,uint256)"
        );
        uint256 originals;
        uint256 purchases;
        for (uint256 n; n < logs.length; ++n) {
            if (logs[n].emitter != address(recorder) || logs[n].topics.length != 4) continue;
            if (logs[n].topics[0] == originalTopic && logs[n].topics[1] == e.settlementKey) {
                (
                    StreamPreparedNativeSettlementTypes.Facts memory f,
                    StreamPreparedNativeSettlementTypes.Intent memory i
                ) = abi.decode(
                    logs[n].data,
                    (
                        StreamPreparedNativeSettlementTypes.Facts,
                        StreamPreparedNativeSettlementTypes.Intent
                    )
                );
                require(
                    logs[n].data.length == 1152 && logs[n].topics[2] == _oldSale(p),
                    "original record width/sale identity"
                );
                require(
                    i.saleId == p.saleId && i.saleNonce == p.nonce
                        && i.executionNonce == e.purchaseNonce && i.payer == e.buyer
                        && i.beneficiary == e.recipient,
                    "creation and purchase identities separate"
                );
                require(
                    f.saleAdapter == p.adapter && f.mintManager == address(manager)
                        && f.recorder == address(recorder) && f.tokenId == e.tokenId
                        && f.operationRoot == e.operationRoot && f.operationId == e.operationId,
                    "actual original facts"
                );
                bytes32 execution = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_EXECUTION_V1"),
                        block.chainid,
                        p.adapter,
                        f.intentHash,
                        i.executionNonce,
                        f.currentPolicyHash,
                        f.boundPolicyHash,
                        f.operationRoot,
                        f.operationId
                    )
                );
                StreamPrimarySettlementTypes.PrimarySettlementResult memory receipt =
                    recorder.settlementResult(e.settlementKey);
                require(
                    receipt.executionId == execution && execution != purchase
                        && receipt.operationIdentityCommitment == e.operationRoot,
                    "original execution domain never replaced with purchase ID"
                );
                bytes32 factsHash = keccak256(
                    abi.encode(keccak256("6529STREAM_PREPARED_NATIVE_FACTS_V1"), block.chainid, f)
                );
                require(
                    logs[n].topics[3] == factsHash
                        && recorder.preparedNativeFactsHash(e.settlementKey) == factsHash,
                    "original facts hash"
                );
                ++originals;
            }
            if (logs[n].topics[0] == purchaseTopic && logs[n].topics[3] == e.settlementKey) {
                (uint16 schema, bytes32 saleId, uint256 saleNonce) =
                    abi.decode(logs[n].data, (uint16, bytes32, uint256));
                require(
                    schema == 1 && logs[n].topics[1] == bytes32(uint256(uint160(p.adapter)))
                        && logs[n].topics[2] == purchase && saleId == p.saleId
                        && saleNonce == p.nonce,
                    "exact additive purchase event"
                );
                ++purchases;
            }
        }
        require(originals == 1 && purchases == 1, "one original and one purchase record");
    }

    function testOneImmutableManifestRecordsTwoPurchasesWithoutConsumingWholeSale() public {
        CuratedPlan memory p = _publicPlan();
        uint256 payment = p.config.price + entropy.fee();
        Curated.SaleRecord memory original = fixedSale.saleRecord(p.saleId);
        Curated.Selection memory first = _curatedSelection(p, 0, payer, 1);
        Curated.Selection memory second = _curatedSelection(p, 2, payer, 2);
        vm.recordLogs();
        vm.prank(payer);
        Curated.ExecutionRecord memory one =
            fixedSale.purchaseSelectedContent{ value: payment }(p.saleId, first);
        Vm.Log[] memory firstLogs = vm.getRecordedLogs();
        vm.recordLogs();
        vm.prank(payer);
        Curated.ExecutionRecord memory two =
            fixedSale.purchaseSelectedContent{ value: payment }(p.saleId, second);
        Vm.Log[] memory secondLogs = vm.getRecordedLogs();
        bytes32 id1 = _purchase(p, payer, 1);
        bytes32 id2 = _purchase(p, payer, 2);
        _assertCuratedExecution(p, 0, one);
        _assertCuratedExecution(p, 2, two);
        _assertOriginalRecords(firstLogs, p, one, id1);
        _assertOriginalRecords(secondLogs, p, two, id2);
        require(
            one.tokenId == 1 && two.tokenId == 2 && one.settlementKey != two.settlementKey
                && one.authorizationId != two.authorizationId,
            "distinct actual mint/ledger/settlement identities"
        );
        require(
            recorder.preparedNativeContentPurchaseConsumed(p.adapter, id1)
                && recorder.preparedNativeContentPurchaseConsumed(p.adapter, id2)
                && !recorder.preparedNativeSaleConsumed(_oldSale(p)),
            "nested purchase replay only"
        );
        require(
            keccak256(abi.encode(fixedSale.saleRecord(p.saleId)))
                == keccak256(abi.encode(original)),
            "immutable full sale record"
        );
        require(
            wallet.balance == 2 * p.config.price
                && recorder.totalOfficialSettled(address(0)) == 2 * p.config.price
                && manager.nextOperationNonce() == 2,
            "exact two paid operations"
        );
    }

    function testDuplicateLeafWithFreshPurchaseNonceRollsBackOnlyNewAttempt() public {
        CuratedPlan memory p = _publicPlan();
        uint256 payment = p.config.price + entropy.fee();
        Curated.Selection memory chosen = _curatedSelection(p, 1, payer, 1);
        vm.prank(payer);
        Curated.ExecutionRecord memory first =
            fixedSale.purchaseSelectedContent{ value: payment }(p.saleId, chosen);
        bytes32 receiptHash = keccak256(abi.encode(recorder.settlementResult(first.settlementKey)));
        chosen.purchaseNonce = 2;
        bytes memory data = abi.encodeCall(fixedSale.purchaseSelectedContent, (p.saleId, chosen));
        vm.prank(payer);
        (bool ok,) = address(fixedSale).call{ value: payment }(data);
        require(
            !ok && core.lastAllocatedTokenId() == 1 && core.collectionNextSerial(1) == 2
                && manager.nextOperationNonce() == 1,
            "failed duplicate keeps sequential identity"
        );
        require(
            ledger.counterValue(_curatedCounterKey(p, 1)) == 1
                && !recorder.preparedNativeContentPurchaseConsumed(
                    p.adapter, _purchase(p, payer, 2)
                ),
            "content cap and new replay rollback"
        );
        require(
            fixedSale.nextPurchaseNonce(p.saleId, payer) == 2
                && fixedSale.executionRecord(_purchase(p, payer, 2)).saleId == 0,
            "new carrier attempt rollback"
        );
        require(
            keccak256(abi.encode(recorder.settlementResult(first.settlementKey))) == receiptHash
                && wallet.balance == p.config.price
                && recorder.totalOfficialSettled(address(0)) == p.config.price,
            "prior exact paid receipt retained"
        );
    }

    function testLateDeliveryAndPostDeliveryAuthorityFailuresPermitIdenticalSafeRetry() public {
        CuratedPlan memory p = _publicPlan();
        uint256 payment = p.config.price + entropy.fee();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xCA01;
        keys[1] = 0xCA02;
        OfficialSafe buyer =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 921);
        bytes32 purchase = _purchase(p, address(buyer), 1);
        CuratedSettlementReceiver recipient = new CuratedSettlementReceiver(
            address(core), address(recorder), p.adapter, address(artists), purchase, p.config.price
        );
        Curated.Selection memory chosen = _curatedSelection(p, 1, address(recipient), 1);
        bytes memory data = abi.encodeCall(fixedSale.purchaseSelectedContent, (p.saleId, chosen));
        uint256 nonce = buyer.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            buyer.getTransactionHash(
                p.adapter, payment, data, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        bytes memory saved = abi.encodeCall(
            buyer.execTransaction,
            (p.adapter, payment, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures)
        );
        vm.deal(address(buyer), payment);
        for (uint8 mode = 1; mode <= 2; ++mode) {
            recipient.setMode(mode);
            (bool ok, bytes memory returned) = address(buyer).call(saved);
            require(
                !ok
                    && keccak256(returned)
                        == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
                "exact saved Safe failure"
            );
            require(
                buyer.nonce() == nonce && address(buyer).balance == payment
                    && !recipient.observed(),
                "Safe/payment/callback rollback"
            );
            require(
                core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                    && manager.nextOperationNonce() == 0 && core.pendingPreparedMintTokenId() == 0,
                "complete mint identity rollback"
            );
            require(
                !recorder.preparedNativeContentPurchaseConsumed(p.adapter, purchase)
                    && wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                    && ledger.counterValue(_curatedCounterKey(p, 1)) == 0,
                "official funds/counters/replay rollback"
            );
            require(entropy.revealFeeEscrow(1) == 0, "funded fee also rolls back");
            require(
                NativeCuratedArtistBoundary(address(artists)).consent()
                    && manager.preparedNativeContentAdmission() == 0
                    && fixedSale.nextPurchaseNonce(p.saleId, address(buyer)) == 1,
                "authority/admission/purchase nonce rollback"
            );
        }
        recipient.setMode(0);
        (bool success, bytes memory result) = address(buyer).call(saved);
        require(
            success && result.length == 32 && abi.decode(result, (bool)),
            "identical original signed Safe CALL succeeds"
        );
        Curated.ExecutionRecord memory e = fixedSale.executionRecord(purchase);
        _assertCuratedExecution(p, 1, e);
        require(
            buyer.nonce() == nonce + 1 && recipient.observed()
                && core.ownerOf(e.tokenId) == address(recipient),
            "original buyer and separate recipient complete"
        );
    }

    function testStrictOriginalPolicyRefusesDriftWhileCommittedCurrentProfileSettlesCurrentWallet()
        public
    {
        _deployCuratedFixed();
        CuratedPlan memory strict =
            _curatedPlan(address(fixedSale), 0, Curated.SelectionMode.PUBLIC);
        _openCuratedFixed(strict, Curated.SelectionMode.PUBLIC);
        CuratedPlan memory current =
            _curatedPlan(address(fixedSale), 0, Curated.SelectionMode.COMMIT_REVEAL);
        _openCuratedFixed(current, Curated.SelectionMode.COMMIT_REVEAL);
        Curated.Selection memory chosen = _curatedSelection(current, 1, payer, 1);
        bytes32 salt = keccak256("original full-price commitment");
        bytes32 commitment =
            fixedSale.selectionCommitment(current.saleId, payer, current.leaves[1], salt);
        vm.warp(current.windows.commitOpen);
        vm.prank(payer);
        fixedSale.commitSelection{ value: current.config.price }(current.saleId, commitment, 1);
        (uint256 pending, uint256 refunded, uint256 total) = fixedSale.selectionLiabilities();
        require(
            pending == current.config.price && refunded == 0 && total == pending
                && recorder.totalOfficialSettled(address(0)) == 0
                && core.lastAllocatedTokenId() == 0,
            "deposit is not mint revenue"
        );
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(
            vm.addr(SIGNER_KEY), 1000000, keccak256("current artist")
        );
        (bytes32 replacement, address replacementWallet) =
            factory.createProfile(entries, keccak256("different current profile"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, replacement, 0);
        Curated.Selection memory strictChoice = _curatedSelection(strict, 0, payer, 1);
        uint256 strictPayment = strict.config.price + entropy.fee();
        bytes memory strictData =
            abi.encodeCall(fixedSale.purchaseSelectedContent, (strict.saleId, strictChoice));
        vm.prank(payer);
        (bool ok,) = address(fixedSale).call{ value: strictPayment }(strictData);
        require(
            !ok && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "strict policy mismatch cannot silently become current mode"
        );
        entropy.configure(125, 1, false, false);
        vm.warp(current.windows.revealOpen);
        vm.recordLogs();
        vm.prank(payer);
        Curated.ExecutionRecord memory e =
            fixedSale.revealSelection{ value: 125 }(current.saleId, chosen, salt);
        _assertOriginalRecords(vm.getRecordedLogs(), current, e, _purchase(current, payer, 1));
        StreamPrimarySettlementTypes.PrimarySettlementResult memory receipt =
            recorder.settlementResult(e.settlementKey);
        require(
            receipt.profileId == replacement && receipt.wallet == replacementWallet
                && replacementWallet.balance == current.config.price && wallet.balance == 0,
            "current admitted collection PROFILE wallet"
        );
        (pending, refunded, total) = fixedSale.selectionLiabilities();
        require(
            pending == 0 && refunded == 0 && total == 0 && core.ownerOf(e.tokenId) == payer
                && ledger.counterValue(_curatedCounterKey(current, 1)) == 1,
            "committed price settled once"
        );
        require(entropy.revealFeeEscrow(1) == 125, "separate live fee at actual mint");
        require(
            !recorder.preparedNativeSaleConsumed(_oldSale(strict))
                && !recorder.preparedNativeSaleConsumed(_oldSale(current)),
            "old auction flags untouched"
        );
    }
}
