// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentArtistNativeOfferFixture.sol";

interface CurrentArtistNativeOfferFaultVm {
    function mockCallRevert(
        address target,
        uint256 value,
        bytes calldata data,
        bytes calldata reason
    ) external;
    function clearMockedCalls() external;
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice Original seller and buyer Safe signatures with actual Artist consent and native offer settlement.
/// @dev Native acceptance remains pending matched-source execution. The last case explicitly injects
/// only a wallet-deposit failure; it proves atomic repair, not natural wallet failure or cold gas capacity.
contract StreamCurrentArtistNativeOfferTest is CurrentArtistNativeOfferFixture {
    function setUp() public {
        _deployArtistNativeOffers();
    }

    function testActualSelectedOfferArtistConsentRepairsIdenticalBuyerSafeAndOriginalRevenue()
        public
    {
        (ArtistNativeOfferPlan memory p, NativeOffer.Acceptance memory q) =
            _openArtistNativeOffer(true, false);
        uint256 balance = address(joinedBuyer).balance;
        uint256 artistNonce = joinedArtist.nonce();
        uint256 ownerNonce = joinedCollaborator.nonce();
        uint256 governorNonce = governorSafe.nonce();
        bytes memory exact = _nativeOfferSafePayload(q, ARTIST_NATIVE_OFFER_PRICE + 117);
        _nativeOfferFailed(exact);
        _nativeOfferUnused(p, q);
        _nativeOfferConsent(p);
        require(
            joinedArtist.nonce() == artistNonce + 1 && joinedCollector.nonce() == 0
                && joinedCollaborator.nonce() == ownerNonce
                && governorSafe.nonce() == governorNonce,
            "only original Artist records missing operation16 consent"
        );
        vm.recordLogs();
        _nativeOfferSucceeded(exact);
        ArtistNativeOfferReceipt memory r = _nativeOfferReceipt(p, q, vm.getRecordedLogs(), false);
        require(
            q.offer.tokenId == 0 && p.config.contentId == 0 && p.leaf != 0
                && q.selection.tokenData.length == 0 && r.content.tokenDataHash == keccak256("")
                && r.content.contentLeaf != r.content.tokenDataHash && joinedBuyer.nonce() == 1
                && joinedCollector.nonce() == 0 && joinedCollector.getThreshold() == 2
                && joinedBuyer.getThreshold() == 2,
            "empty selected work remains genuine content and seller signature consumes no Safe nonce"
        );
        require(
            artistNativeOffers.refundableBalance(p.id, address(joinedBuyer)) == 17
                && artistNativeOffers.totalBuyerLiabilities() == 17
                && address(artistNativeOffers).balance == 17,
            "original buyer owns excess allowance"
        );
        _joinedSafe(
            joinedBuyer,
            address(artistNativeOffers),
            0,
            abi.encodeCall(artistNativeOffers.claimRefund, (p.id, address(joinedBuyer)))
        );
        require(
            address(joinedBuyer).balance == balance - ARTIST_NATIVE_OFFER_PRICE - 100
                && artistNativeOffers.totalBuyerLiabilities() == 0
                && address(artistNativeOffers).balance == 0,
            "actual Safe pulls own excess without changing price or reveal fee"
        );
        (, uint256 request) = entropy.requestEntropy(1);
        provider.fulfill(request, keccak256("actual native offer entropy"));
        (, bool revealed) = entropy.tokenSeed(1);
        require(
            revealed && bytes(core.tokenURI(1)).length != 0,
            "actual coordinator and metadata reveal original token"
        );
        uint256 artistBalance = address(joinedArtist).balance;
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
            wallet.balance == 300 && address(joinedArtist).balance == artistBalance + 700,
            "actual Artist withdraws original PROFILE seventy percent share"
        );
        // A newly signed transaction still presents the original consumed seller and buyer payloads.
        uint256 nonce = joinedBuyer.nonce();
        _nativeOfferFailed(_nativeOfferSafePayload(q, ARTIST_NATIVE_OFFER_PRICE + 100));
        require(
            joinedBuyer.nonce() == nonce && core.totalSupply() == 1
                && manager.nextOperationNonce() == 1
                && ledger.counterValue(_nativeOfferCounter(p)) == 1
                && joinedRecorder.totalOfficialSettled(address(0)) == ARTIST_NATIVE_OFFER_PRICE,
            "terminal replay neither remints nor repays"
        );
    }

    function testActualCollectionOfferRequiresBothOriginalSafeDomainsAndSignedRawArtwork() public {
        (ArtistNativeOfferPlan memory p, NativeOffer.Acceptance memory original) =
            _openArtistNativeOffer(false, true);
        require(
            p.leaf == 0 && address(p.gate) == address(0) && original.offer.tokenId == 0
                && original.offer.contentSelectionHash == 0
                && original.authorization.contentSelectionHash == 0,
            "collection offer carries no content reservation"
        );
        NativeOffer.Acceptance memory q = abi.decode(abi.encode(original), (NativeOffer.Acceptance));
        q.sellerProof.signature =
            safeThresholdSignature(joinedKeys, _nativeOfferSellerDigest(q.authorization));
        _nativeOfferFailed(_nativeOfferSafePayload(q, ARTIST_NATIVE_OFFER_PRICE + 100));
        q.sellerProof.signature =
            _joinedProof(joinedArtist, _nativeOfferSellerDigest(q.authorization));
        _nativeOfferFailed(_nativeOfferSafePayload(q, ARTIST_NATIVE_OFFER_PRICE + 100));
        q.sellerProof = original.sellerProof;
        q.buyerProof.signature = _joinedProof(joinedCollector, _nativeOfferBuyerDigest(q.offer));
        _nativeOfferFailed(_nativeOfferSafePayload(q, ARTIST_NATIVE_OFFER_PRICE + 100));
        q.buyerProof.signature =
            safeThresholdSignature(joinedKeys, _nativeOfferBuyerDigest(q.offer));
        _nativeOfferFailed(_nativeOfferSafePayload(q, ARTIST_NATIVE_OFFER_PRICE + 100));
        q.buyerProof = original.buyerProof;
        q.selection.tokenData = "unapproved collection artwork";
        _nativeOfferFailed(_nativeOfferSafePayload(q, ARTIST_NATIVE_OFFER_PRICE + 100));
        _nativeOfferUnused(p, original);
        vm.recordLogs();
        _nativeOfferSucceeded(_nativeOfferSafePayload(original, ARTIST_NATIVE_OFFER_PRICE + 100));
        ArtistNativeOfferReceipt memory r =
            _nativeOfferReceipt(p, original, vm.getRecordedLogs(), false);
        require(
            r.content.gate == address(0) && r.content.manifestRoot == 0
                && r.content.manifestHash == 0 && r.content.contentId == 0
                && r.content.contentLeaf == 0 && r.content.counterId == 0
                && r.content.contextHash != 0
                && r.content.tokenDataHash == keccak256(original.selection.tokenData)
                && joinedCollector.nonce() == 0 && joinedBuyer.nonce() == 1
                && artistNativeOffers.totalBuyerLiabilities() == 0
                && address(artistNativeOffers).balance == 0,
            "original collection artwork and buyer-recipient debit preserve separate seller and buyer Safe identities"
        );
    }

    function testActualSelectedOfferLateInjectedDepositFailureRestoresBothDigestsAndExactSafeRetry()
        public
    {
        (ArtistNativeOfferPlan memory p, NativeOffer.Acceptance memory q) =
            _openArtistNativeOffer(true, true);
        bytes memory exact = _nativeOfferSafePayload(q, ARTIST_NATIVE_OFFER_PRICE + 109);
        uint256 balance = address(joinedBuyer).balance;
        uint256 governorNonce = governorSafe.nonce();
        this.artistNativeOfferRecorderAdmission(false);
        CurrentArtistNativeOfferFaultVm fault = CurrentArtistNativeOfferFaultVm(address(vm));
        fault.mockCallRevert(
            wallet,
            ARTIST_NATIVE_OFFER_PRICE,
            bytes(""),
            abi.encodeWithSignature("Error(string)", "explicit native offer wallet deposit fault")
        );
        // Failed deposit, retried deposit and eventual real escrow flush all have the exact same call shape.
        fault.expectCall(wallet, ARTIST_NATIVE_OFFER_PRICE, bytes(""), 3);
        fault.expectCall(
            address(revenueEscrow),
            ARTIST_NATIVE_OFFER_PRICE,
            abi.encodeCall(
                revenueEscrow.creditNative, (PRIMARY_REVENUE_CLASS, profile, wallet, false)
            ),
            2
        );
        vm.recordLogs();
        _nativeOfferFailed(exact);
        // These reverted trace events identify the reached preparation; they are not committed receipts.
        (bytes32 root, bytes32 operation) = _nativeOfferFailedTrace(p, q, vm.getRecordedLogs());
        _nativeOfferUnused(p, q);
        bytes32 key = _nativeOfferFailedKey(p, q, root, operation);
        bytes32 purchase = artistNativeOffers.purchaseIdFor(p.id, address(joinedBuyer), 1);
        require(
            !ledger.isManagerOperationRootUsed(address(manager), root)
                && !manager.isOperationRootUsed(root) && !joinedRecorder.settlementConsumed(key)
                && joinedRecorder.preparedNativeFactsHash(key) == 0
                && joinedRecorder.preparedNativeContentHash(key) == 0
                && joinedRecorder.settlementResult(key).candidateCommitment == 0
                && !IStreamPreparedNativeOfferSettlement(address(joinedRecorder))
                    .preparedNativeOfferConsumed(address(artistNativeOffers), purchase)
                && artistNativeOffers.executionRecord(purchase).operationRoot == 0
                && address(joinedRecorder).balance == 0 && address(revenueEscrow).balance == 0
                && address(joinedBuyer).balance == balance,
            "exact failed root receipt identities and funded Safe value all roll back"
        );
        this.artistNativeOfferRecorderAdmission(true);
        require(
            this.artistNativeOfferTime() < p.config.sale.endsAt
                && this.artistNativeOfferTime() < q.offer.deadline
                && governorSafe.nonce() == governorNonce + 2 && joinedBuyer.nonce() == 0
                && joinedCollector.nonce() == 0,
            "real delayed repair preserves original terms signatures and separate buyer Safe envelope"
        );
        vm.recordLogs();
        _nativeOfferSucceeded(exact);
        ArtistNativeOfferReceipt memory r = _nativeOfferReceipt(p, q, vm.getRecordedLogs(), true);
        require(
            r.execution.operationRoot == root && r.execution.operationId == operation
                && r.execution.settlementKey == key
                && address(joinedBuyer).balance == balance - ARTIST_NATIVE_OFFER_PRICE - 109
                && artistNativeOffers.refundableBalance(p.id, address(joinedBuyer)) == 9
                && artistNativeOffers.totalBuyerLiabilities() == 9
                && address(artistNativeOffers).balance == 9,
            "byte-identical Safe retry uses original operation and creates only the original buyer excess credit"
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
            wallet.balance == ARTIST_NATIVE_OFFER_PRICE && revenueEscrow.totalOwed(address(0)) == 0
                && address(revenueEscrow).balance == 0,
            "real PROFILE wallet receives original escrow after external fault removal"
        );
        _joinedSafe(
            joinedBuyer,
            address(artistNativeOffers),
            0,
            abi.encodeCall(artistNativeOffers.claimRefund, (p.id, address(joinedBuyer)))
        );
        require(
            address(joinedBuyer).balance == balance - ARTIST_NATIVE_OFFER_PRICE - 100
                && artistNativeOffers.totalBuyerLiabilities() == 0
                && address(artistNativeOffers).balance == 0,
            "original buyer alone owns and withdraws excess after repaired execution"
        );
    }

    function _nativeOfferFailedTrace(
        ArtistNativeOfferPlan memory p,
        NativeOffer.Acceptance memory q,
        Vm.Log[] memory logs
    ) private view returns (bytes32 root, bytes32 operation) {
        uint256 sellers;
        uint256 authorizations;
        uint256 prepared;
        for (uint256 n; n < logs.length; ++n) {
            if (logs[n].topics.length == 0) continue;
            if (
                logs[n].emitter == address(artistNativeOffers)
                    && logs[n].topics[0]
                        == keccak256("SaleAuthorizationConsumed(uint16,bytes32,bytes32,address)")
            ) {
                require(
                    logs[n].topics.length == 3 && logs[n].topics[1] == p.id
                        && logs[n].topics[2] == _nativeOfferSellerDigest(q.authorization)
                        && keccak256(logs[n].data)
                            == keccak256(abi.encode(uint16(1), address(joinedCollector))),
                    "original seller consumed before downstream trace"
                );
                ++sellers;
            } else if (
                logs[n].emitter == address(ledger)
                    && logs[n].topics[0]
                        == keccak256(
                            "MintLedgerAuthorizationConsumed(uint16,bytes32,bytes32,address,bytes32)"
                        )
            ) {
                require(
                    sellers == 1 && logs[n].topics.length == 4
                        && logs[n].topics[1] == _nativeOfferId(p.config.offerDigest)
                        && address(uint160(uint256(logs[n].topics[3]))) == address(manager)
                        && keccak256(logs[n].data)
                            == keccak256(abi.encode(uint16(1), p.config.sale.mintPolicyHash)),
                    "original buyer Ledger authorization after seller"
                );
                root = logs[n].topics[2];
                ++authorizations;
            } else if (
                logs[n].emitter == address(manager)
                    && logs[n].topics[0]
                        == keccak256(
                            "PreparedMintStarted(uint16,bytes32,uint256,uint256,bytes32,uint256,address,bytes32,bytes32)"
                        )
            ) {
                require(
                    authorizations == 1 && logs[n].topics.length == 4
                        && uint256(logs[n].topics[2]) == 1 && uint256(logs[n].topics[3]) == 1
                        && keccak256(logs[n].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    root,
                                    uint256(1),
                                    address(joinedBuyer),
                                    keccak256(q.selection.tokenData),
                                    q.selection.mintCommitment
                                )
                            ),
                    "real prepared token before denied payment"
                );
                operation = logs[n].topics[1];
                ++prepared;
            }
        }
        require(
            sellers == 1 && authorizations == 1 && prepared == 1 && root != 0 && operation != 0,
            "one reverted full preparation trace"
        );
    }

    function _nativeOfferFailedKey(
        ArtistNativeOfferPlan memory p,
        NativeOffer.Acceptance memory q,
        bytes32 root,
        bytes32 operation
    ) private view returns (bytes32) {
        NativeOfferPrepared.Intent memory intent = _nativeOfferIntent(p, q);
        NativeOfferPrepared.Facts memory facts;
        facts.saleAdapter = address(artistNativeOffers);
        facts.intentHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_OFFER_INTENT_V1"),
                block.chainid,
                address(artistNativeOffers),
                address(joinedRecorder),
                intent
            )
        );
        facts.currentPolicyHash = p.config.sale.mintPolicyHash;
        facts.boundPolicyHash = p.config.sale.mintPolicyHash;
        facts.operationRoot = root;
        facts.operationId = operation;
        return StreamPrimarySettlementHash.settlementKey(
            address(joinedRecorder),
            address(artistNativeOffers),
            StreamPreparedNativeSettlementHash.executionId(facts, intent)
        );
    }
}
