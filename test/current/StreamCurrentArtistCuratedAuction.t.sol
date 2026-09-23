// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentArtistCuratedAuctionFixture.sol";

interface CurrentArtistCuratedAuctionFaultVm {
    function mockCallRevert(
        address target,
        uint256 value,
        bytes calldata data,
        bytes calldata reason
    ) external;
    function clearMockedCalls() external;
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice Actual Artist/Manager/Ledger/Core content auction with original threshold Safe roles.
/// @dev Native execution remains pending matched-source validation. Only the last case injects
/// a production-call fault, explicitly limited to the native wallet deposit; it is not a cold-gas
/// or naturally occurring wallet-failure claim. All authority and settlement contracts stay real.
contract StreamCurrentArtistCuratedAuctionTest is CurrentArtistCuratedAuctionFixture {
    function setUp() public {
        _deployJoinedCommerce();
    }

    function testActualCuratedArtistConsentRepairsSameSafeBidAndRecordsEmptySelectedWork() public {
        CuratedAuctionPlan memory p = _curatedAuctionPlan(true);
        bytes32 id = _curatedAuctionOpen(p);
        uint256 nonce = joinedCollector.nonce();
        uint256 balance = address(joinedCollector).balance;
        bytes memory exactBid = _curatedAuctionSafeCall(
            joinedCollector,
            address(joinedHouse),
            JOINED_PRICE + 100,
            abi.encodeCall(joinedHouse.bid, (id, address(0)))
        );
        (bool ok, bytes memory reason) = address(joinedCollector).call(exactBid);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && joinedCollector.nonce() == nonce && address(joinedCollector).balance == balance
                && joinedHouse.totalBuyerLiabilities() == 0
                && joinedHouse.auction(id).winner.amount == 0,
            "original Artist creation proof does not replace required sale consent"
        );
        _curatedAuctionNoMint(p, bytes32(0));
        _curatedAuctionSaleConsent(p, id);
        (ok, reason) = address(joinedCollector).call(exactBid);
        require(
            ok && abi.decode(reason, (bool)) && joinedCollector.nonce() == nonce + 1
                && address(joinedCollector).balance == balance - JOINED_PRICE - 100,
            "actual operation16 repairs the byte-identical funded Safe bid"
        );
        IStreamNativeEnglishAuction.WinningBid memory winner = joinedHouse.auction(id).winner;
        require(
            winner.payer == address(joinedCollector) && winner.executor == address(joinedCollector)
                && winner.deliverTo == address(joinedCollector) && !winner.signed,
            "public Safe bid retains all original principal roles"
        );
        (uint64 end,,,) = joinedHouse.auctionDeadlines(id);
        vm.warp(end);
        uint256 bidderNonce = joinedCollector.nonce();
        vm.recordLogs();
        _joinedSafe(joinedBuyer, address(joinedHouse), 0, abi.encodeCall(joinedHouse.settle, (id)));
        CuratedAuctionReceipt memory receipt =
            _curatedAuctionReceipt(p, id, vm.getRecordedLogs(), false);
        require(
            receipt.intent.executor == address(joinedCollector)
                && joinedCollector.nonce() == bidderNonce && p.selection.contentId == 0
                && core.tokenData(1).length == 0,
            "different settling Safe preserves winner intent and valid zero-id empty artwork"
        );
        (, uint256 request) = entropy.requestEntropy(1);
        provider.fulfill(request, keccak256("actual curated auction seed"));
        (, bool revealed) = entropy.tokenSeed(1);
        require(
            revealed && bytes(core.tokenURI(1)).length != 0,
            "actual coordinator and metadata reveal selected work"
        );
        _joinedSafe(
            joinedArtist,
            wallet,
            0,
            abi.encodeCall(
                IStreamSplitWallet.release,
                (address(0), address(joinedArtist), payable(address(joinedArtist)))
            )
        );
        require(
            wallet.balance == JOINED_PRICE * 3 / 10,
            "original actual Artist share is withdrawn from exact PROFILE wallet"
        );
    }

    function testActualCuratedCreationRejectsOtherSafeSignatureAndSelectionThenOriginalMints()
        public
    {
        CuratedAuctionPlan memory p = _curatedAuctionPlan(false);
        (
            IStreamNativeEnglishAuction.CreationAuthorization memory a,
            bytes memory platform,
            bytes memory artistProof
        ) = _curatedAuctionCreation(p);
        uint256 posterNonce = joinedCollaborator.nonce();
        bytes memory wrongSignature =
            _joinedProof(joinedCollector, joinedHouse.creationAuthorizationDigest(a));
        bytes memory data = abi.encodeCall(
            joinedHouse.registerCuratedAuction,
            (p.config, p.artwork, p.selection, p.nonce, a, platform, wrongSignature)
        );
        _failedPosterCall(data, posterNonce);
        AuctionContent.Selection memory wrong =
            abi.decode(abi.encode(p.selection), (AuctionContent.Selection));
        wrong.proof[0] = keccak256("unpublished sibling");
        data = abi.encodeCall(
            joinedHouse.registerCuratedAuction,
            (p.config, p.artwork, wrong, p.nonce, a, platform, artistProof)
        );
        _failedPosterCall(data, posterNonce);
        (uint256 next, bytes32 sale) = joinedHouse.nextCuratedSaleId(1, CURATED_AUCTION_PHASE);
        require(
            next == p.nonce && sale == p.saleId,
            "failed originals reserve no sale nonce or identity"
        );
        _curatedAuctionNoMint(p, bytes32(0));
        _joinedSafe(
            joinedCollaborator,
            address(joinedHouse),
            0,
            abi.encodeCall(
                joinedHouse.registerCuratedAuction,
                (p.config, p.artwork, p.selection, p.nonce, a, platform, artistProof)
            )
        );
        bytes32 id = _curatedAuctionId(p);
        require(
            joinedHouse.auction(id).creationDigest == joinedHouse.creationAuthorizationDigest(a)
                && joinedCollaborator.nonce() == posterNonce + 1,
            "original complete Artist signature and selection survive both failures"
        );
        _curatedAuctionSaleConsent(p, id);
        _joinedSafe(
            joinedCollector,
            address(joinedHouse),
            JOINED_PRICE + 100,
            abi.encodeCall(joinedHouse.bid, (id, address(0)))
        );
        (uint64 end,,,) = joinedHouse.auctionDeadlines(id);
        vm.warp(end);
        vm.recordLogs();
        _joinedSafe(joinedBuyer, address(joinedHouse), 0, abi.encodeCall(joinedHouse.settle, (id)));
        _curatedAuctionReceipt(p, id, vm.getRecordedLogs(), false);
    }

    function _failedPosterCall(bytes memory data, uint256 nonce) private {
        bytes memory exact =
            _curatedAuctionSafeCall(joinedCollaborator, address(joinedHouse), 0, data);
        (bool ok, bytes memory reason) = address(joinedCollaborator).call(exact);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && joinedCollaborator.nonce() == nonce,
            "wrong original creation proof reverts actual poster Safe envelope"
        );
    }

    function testActualSignedCuratedBidLateInjectedDepositFailureRestoresExactSafeSettlement()
        public
    {
        CuratedAuctionPlan memory p = _curatedAuctionPlan(false);
        bytes32 id = _curatedAuctionOpen(p);
        _curatedAuctionSaleConsent(p, id);
        uint256 payerNonce = joinedCollector.nonce();
        uint256 payerBalance = address(joinedCollector).balance;
        uint256 executorBalance = address(joinedBuyer).balance;
        (, uint64 deadline,,) = joinedHouse.auctionDeadlines(id);
        IStreamNativeEnglishAuction.BidAuthorization memory bid =
            IStreamNativeEnglishAuction.BidAuthorization(
                id,
                joinedHouse.auction(id).configHash,
                address(joinedCollector),
                address(joinedBuyer),
                address(joinedCollector),
                JOINED_PRICE,
                100,
                keccak256("actual curated signed bid"),
                this.curatedAuctionTime() + 1800,
                deadline
            );
        bytes32 bidDigest = _curatedAuctionTyped(
            keccak256(
                abi.encode(
                    keccak256(
                        "NativeAuctionBid(bytes32 auctionId,bytes32 configHash,address payer,address executor,address deliverTo,uint256 amount,uint256 maxRevealFee,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                    ),
                    bid
                )
            )
        );
        require(
            bidDigest == joinedHouse.bidAuthorizationDigest(bid),
            "original independent bid signature domain"
        );
        _joinedSafe(
            joinedBuyer,
            address(joinedHouse),
            JOINED_PRICE + 100,
            abi.encodeCall(joinedHouse.bidSigned, (bid, _joinedProof(joinedCollector, bidDigest)))
        );
        IStreamNativeEnglishAuction.Auction memory before_ = joinedHouse.auction(id);
        require(
            before_.winner.signed && before_.winner.authorizationDigest == bidDigest
                && before_.winner.payer == address(joinedCollector)
                && before_.winner.executor == address(joinedBuyer)
                && before_.winner.deliverTo == address(joinedCollector)
                && joinedCollector.nonce() == payerNonce
                && address(joinedCollector).balance == payerBalance
                && address(joinedBuyer).balance == executorBalance - JOINED_PRICE - 100,
            "Safe ERC1271 payer proof remains separate from funded executor CALL and delivery"
        );
        bytes32 authorization = _curatedAuctionIntentHash(id);
        uint256 settlementNonce = governorSafe.nonce();
        // Governance repairs themselves use Governor Safe; a separate settling Safe keeps its envelope stable.
        bytes memory exact = _curatedAuctionSafeCall(
            joinedCollector, address(joinedHouse), 0, abi.encodeCall(joinedHouse.settle, (id))
        );
        this.curatedAuctionRecorderAdmission(false);
        CurrentArtistCuratedAuctionFaultVm fault = CurrentArtistCuratedAuctionFaultVm(address(vm));
        fault.mockCallRevert(
            wallet,
            JOINED_PRICE,
            bytes(""),
            abi.encodeWithSignature("Error(string)", "injected curated deposit failure")
        );
        // Two recorder attempts, then the real escrow flush after removing the fault.
        fault.expectCall(wallet, JOINED_PRICE, bytes(""), 3);
        fault.expectCall(
            address(revenueEscrow),
            JOINED_PRICE,
            abi.encodeCall(
                revenueEscrow.creditNative, (PRIMARY_REVENUE_CLASS, profile, wallet, false)
            ),
            2
        );
        vm.recordLogs();
        (bool ok, bytes memory reason) = address(joinedCollector).call(exact);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && joinedCollector.nonce() == payerNonce,
            "late actual escrow denial restores original signed settlement"
        );
        // Reverted trace logs prove the reached preparation; only post-retry logs are receipts.
        (bytes32 failedRoot, bytes32 failedOperation) = _failedPreparedTrace(vm.getRecordedLogs());
        _curatedAuctionNoMint(p, authorization);
        bytes32 failedKey = _failedSettlementKey(
            p, authorization, failedRoot, failedOperation, before_.winner.bidIndex
        );
        bytes32 saleKey = StreamPreparedNativeSettlementHash.saleKey(
            address(joinedRecorder), address(joinedHouse), p.saleId, p.nonce
        );
        require(
            !manager.isOperationRootUsed(failedRoot)
                && !ledger.isManagerOperationRootUsed(address(manager), failedRoot)
                && !joinedRecorder.preparedNativeSaleConsumed(saleKey)
                && !joinedRecorder.settlementConsumed(failedKey)
                && joinedRecorder.preparedNativeContentHash(failedKey) == 0
                && joinedRecorder.preparedNativeFactsHash(failedKey) == 0
                && joinedRecorder.settlementResult(failedKey).candidateCommitment == 0
                && keccak256(abi.encode(joinedHouse.auction(id))) == keccak256(abi.encode(before_))
                && joinedHouse.totalBuyerLiabilities() == JOINED_PRICE + 100
                && address(joinedHouse).balance == JOINED_PRICE + 100
                && address(revenueEscrow).balance == 0 && address(joinedRecorder).balance == 0,
            "all original root content receipt and payment effects roll back while winner deposit remains"
        );
        this.curatedAuctionRecorderAdmission(true);
        require(
            this.curatedAuctionTime() > bid.deadline && this.curatedAuctionTime() < deadline
                && governorSafe.nonce() == settlementNonce + 2,
            "two real governance delays preserve original signed bid settlement horizon"
        );
        vm.recordLogs();
        (ok, reason) = address(joinedCollector).call(exact);
        require(
            ok && abi.decode(reason, (bool)) && joinedCollector.nonce() == payerNonce + 1,
            "byte-identical complete signed Safe settlement succeeds after actual governance repair"
        );
        CuratedAuctionReceipt memory receipt =
            _curatedAuctionReceipt(p, id, vm.getRecordedLogs(), true);
        require(
            receipt.mint.operationRoot == failedRoot && receipt.mint.operationId == failedOperation
                && receipt.key == failedKey && receipt.intent.executor == address(joinedBuyer)
                && address(joinedCollector).balance == payerBalance,
            "retry preserves exact operation and original funded executor rather than settling caller"
        );
        fault.clearMockedCalls();
        _joinedSafe(
            joinedBuyer,
            address(revenueEscrow),
            0,
            abi.encodeCall(
                revenueEscrow.flushEscrow, (PRIMARY_REVENUE_CLASS, profile, wallet, address(0))
            )
        );
        require(
            wallet.balance == JOINED_PRICE && revenueEscrow.totalOwed(address(0)) == 0
                && address(revenueEscrow).balance == 0,
            "actual original PROFILE wallet receives real escrow after fault removal"
        );
        bytes32 saved = keccak256(abi.encode(joinedRecorder.settlementResult(receipt.key)));
        _joinedSafe(joinedBuyer, address(joinedHouse), 0, abi.encodeCall(joinedHouse.settle, (id)));
        require(
            keccak256(abi.encode(joinedRecorder.settlementResult(receipt.key))) == saved
                && core.totalSupply() == 1 && manager.nextOperationNonce() == 1
                && ledger.counterValue(_curatedAuctionCounterKey(p)) == 1
                && wallet.balance == JOINED_PRICE
                && joinedRecorder.totalOfficialSettled(address(0)) == JOINED_PRICE,
            "terminal replay cannot remint double-debit or pay twice"
        );
    }

    function _failedPreparedTrace(Vm.Log[] memory logs)
        private
        view
        returns (bytes32 root, bytes32 operation)
    {
        uint256 found;
        for (uint256 n; n < logs.length; ++n) {
            if (
                logs[n].emitter != address(manager) || logs[n].topics.length != 4
                    || logs[n].topics[0]
                        != keccak256(
                            "PreparedMintStarted(uint16,bytes32,uint256,uint256,bytes32,uint256,address,bytes32,bytes32)"
                        )
            ) continue;
            (
                uint16 schema,
                bytes32 originalRoot,
                uint256 serial,
                address beneficiary,
                bytes32 dataHash,
                bytes32 commitment
            ) = abi.decode(logs[n].data, (uint16, bytes32, uint256, address, bytes32, bytes32));
            require(
                schema == 1 && originalRoot != 0 && logs[n].topics[1] != 0
                    && uint256(logs[n].topics[2]) == 1 && uint256(logs[n].topics[3]) == 1
                    && serial == 1 && beneficiary == address(joinedCollector)
                    && dataHash == keccak256("actual curated work")
                    && commitment == keccak256("actual curated mint commitment"),
                "actual preparation reached before payment denial"
            );
            root = originalRoot;
            operation = logs[n].topics[1];
            ++found;
        }
        require(found == 1, "one reverted preparation trace, not a committed receipt");
    }

    function _failedSettlementKey(
        CuratedAuctionPlan memory p,
        bytes32 authorization,
        bytes32 root,
        bytes32 operation,
        uint256 bidIndex
    ) private view returns (bytes32) {
        PN.Facts memory f;
        f.saleAdapter = address(joinedHouse);
        f.intentHash = authorization;
        f.currentPolicyHash = p.config.mintPolicyHash;
        f.boundPolicyHash = p.config.mintPolicyHash;
        f.operationRoot = root;
        f.operationId = operation;
        PN.Intent memory i;
        i.executionNonce = bidIndex;
        return StreamPrimarySettlementHash.settlementKey(
            address(joinedRecorder),
            address(joinedHouse),
            StreamPreparedNativeSettlementHash.executionId(f, i)
        );
    }
}
