// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentArtistERC20OfferFixture.sol";

interface CurrentArtistERC20OfferFaultVm {
    function mockCallRevert(address target, bytes calldata data, bytes calldata reason) external;
    function clearMockedCalls() external;
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Original dual offer signatures and payer spending authority joined to the actual Artist.
/// @dev Native runtime validation is pending. The third case injects only an ERC721 receiver-call
/// fault at the buyer Safe, after real payment and Ledger consumption. It makes no cold-gas claim.
contract StreamCurrentArtistERC20OfferTest is CurrentArtistERC20OfferFixture {
    function setUp() public {
        _deployArtistERC20Offers();
    }

    function testActualArtistSelectedERC20OfferRequiresConsentAndOriginalSafeProofDomains() public {
        (ERC20OfferPlan memory p, OfferE20.Acceptance memory q) = _openArtistERC20Offer(true, false);
        _previewFails(q);
        require(
            core.totalSupply() == 0
                && !artistOffers.digestConsumed(_erc20SellerDigest(q.authorization))
                && !ledger.isManagerAuthorizationUsed(
                    address(manager),
                    StreamMintTicketHash.authorizationId(_erc20BuyerDigest(q.offer))
                ),
            "seller and buyer proofs do not replace actual Artist operation16"
        );
        _erc20ArtistConsent(p);
        bytes memory originalSeller = q.sellerProof.signature;
        q.sellerProof.signature =
            safeThresholdSignature(joinedKeys, _erc20SellerDigest(q.authorization));
        _previewFails(q);
        q.sellerProof.signature = _joinedProof(joinedArtist, _erc20SellerDigest(q.authorization));
        _previewFails(q);
        q.sellerProof.signature = originalSeller;
        bytes memory originalBuyer = q.buyerProof.signature;
        q.buyerProof.signature = _joinedProof(joinedCollector, _erc20BuyerDigest(q.offer));
        _previewFails(q);
        q.buyerProof.signature = originalBuyer;
        q.selection.tokenData = bytes("unpublished bytes");
        _previewFails(q);
        q.selection.tokenData = bytes("");
        PrimaryE20.ERC20SettlementCandidate memory c = artistOffers.previewExecution(q);
        _assertERC20OfferUnused(p, q, c, bytes32(0));
        vm.recordLogs();
        _erc20SafeSuccess(
            joinedBuyer,
            _erc20SafePayload(
                joinedBuyer,
                abi.encodeCall(offerPayment.settleERC20PrimarySaleByPayer, (c, abi.encode(q)))
            )
        );
        _assertERC20OfferExecuted(p, q, c);
        _assertPaymentEvent(vm.getRecordedLogs(), c);
        require(
            p.config.contentId == 0 && p.leaf != 0 && core.tokenData(1).length == 0
                && joinedCollector.nonce() == 0 && joinedBuyer.nonce() == 2,
            "valid selected zero-id empty work, seller1271 and payer Safe approve plus CALL"
        );
        (, uint256 request) = entropy.requestEntropy(1);
        provider.fulfill(request, keccak256("actual ERC20 selected offer seed"));
        (, bool revealed) = entropy.tokenSeed(1);
        require(
            revealed && bytes(core.tokenURI(1)).length != 0,
            "actual coordinator reveals the selected token"
        );
        _erc20SafeFailure(
            joinedBuyer,
            _erc20SafePayload(
                joinedBuyer,
                abi.encodeCall(offerPayment.settleERC20PrimarySaleByPayer, (c, abi.encode(q)))
            )
        );
        require(
            core.totalSupply() == 1 && offerToken.balanceOf(address(joinedBuyer)) == 9000
                && offerToken.allowance(address(joinedBuyer), address(offerPayment)) == 9000,
            "terminal replay cannot mint or debit again"
        );
    }

    function testActualCollectionERC20OfferFeeRepairPreservesIdenticalSignedSafeTransaction()
        public
    {
        (ERC20OfferPlan memory p, OfferE20.Acceptance memory q) = _openArtistERC20Offer(false, true);
        PrimaryE20.ERC20SettlementCandidate memory c = artistOffers.previewExecution(q);
        bytes memory exact = _erc20SafePayload(
            joinedBuyer,
            abi.encodeCall(offerPayment.settleERC20PrimarySaleByPayer, (c, abi.encode(q)))
        );
        entropy.updateRevealFeePerToken(1, 1);
        _erc20SafeFailure(joinedBuyer, exact);
        _assertERC20OfferUnused(p, q, c, bytes32(0));
        entropy.updateRevealFeePerToken(1, 0);
        vm.recordLogs();
        _erc20SafeSuccess(joinedBuyer, exact);
        _assertERC20OfferExecuted(p, q, c);
        _assertPaymentEvent(vm.getRecordedLogs(), c);
        OfferE20.SaleRecord memory record = artistOffers.saleRecord(p.id);
        require(
            q.offer.tokenId == 0 && q.offer.contentSelectionHash == 0
                && q.authorization.contentSelectionHash == 0 && p.leaf == 0
                && record.gate == address(0) && record.contentCounterId == 0
                && record.manifestHash == 0
                && keccak256(core.tokenData(1))
                    == keccak256("actual Artist collection-level ERC20 offer bytes")
                && core.pendingPreparedMintTokenId() == 0,
            "collection offer signs original bytes and uses ordinary recipient counter without invented content identity"
        );
    }

    function testActualDelegatedSafeERC20OfferNeedsPayerIntentAndRestoresLateReceiverFailure()
        public
    {
        (ERC20OfferPlan memory p, OfferE20.Acceptance memory q) = _openArtistERC20Offer(true, true);
        _erc20DelegateExecutor(p, q);
        PrimaryE20.ERC20SettlementCandidate memory c = artistOffers.previewExecution(q);
        PrimaryE20.PaymentIntent memory intent = _erc20Intent(p);
        bytes32 digest = _erc20IntentDigest(intent);
        uint256 payerNonce = joinedBuyer.nonce();
        _erc20SafeFailure(
            joinedCollaborator,
            _erc20SafePayload(
                joinedCollaborator,
                abi.encodeCall(offerPayment.settleERC20PrimarySaleByPayer, (c, abi.encode(q)))
            )
        );
        bytes memory wrong = _joinedProof(joinedCollaborator, digest);
        _erc20SafeFailure(
            joinedCollaborator,
            _erc20SafePayload(
                joinedCollaborator,
                abi.encodeCall(
                    offerPayment.settleERC20PrimarySaleWithIntent, (c, intent, wrong, abi.encode(q))
                )
            )
        );
        _assertERC20OfferUnused(p, q, c, intent.nonce);
        bytes memory proof = _joinedProof(joinedBuyer, digest);
        bytes memory data = abi.encodeCall(
            offerPayment.settleERC20PrimarySaleWithIntent, (c, intent, proof, abi.encode(q))
        );
        bytes memory exact = _erc20SafePayload(joinedCollaborator, data);
        CurrentArtistERC20OfferFaultVm fault = CurrentArtistERC20OfferFaultVm(address(vm));
        bytes memory callback = abi.encodeWithSelector(IERC721Receiver.onERC721Received.selector);
        fault.mockCallRevert(
            address(joinedBuyer),
            callback,
            abi.encodeWithSignature("Error(string)", "injected buyer Safe receiver failure")
        );
        fault.expectCall(address(joinedBuyer), callback, 2);
        vm.recordLogs();
        _erc20SafeFailure(joinedCollaborator, exact);
        // These reverted trace logs locate failure after actual price routing, not durable receipts.
        _assertPaymentEvent(vm.getRecordedLogs(), c);
        _assertERC20OfferUnused(p, q, c, intent.nonce);
        require(
            joinedBuyer.nonce() == payerNonce && joinedCollector.nonce() == 0,
            "payer and seller SafeMessage signatures consume no Safe transaction nonce"
        );
        fault.clearMockedCalls();
        vm.recordLogs();
        _erc20SafeSuccess(joinedCollaborator, exact);
        _assertERC20OfferExecuted(p, q, c);
        _assertPaymentEvent(vm.getRecordedLogs(), c);
        require(
            offerPayment.isPaymentIntentNonceUsed(address(joinedBuyer), intent.nonce)
                && joinedBuyer.nonce() == payerNonce && joinedCollector.nonce() == 0
                && c.executor == address(joinedCollaborator) && c.sale.payer == address(joinedBuyer)
                && c.sale.beneficiary == address(joinedBuyer)
                && offerToken.balanceOf(address(joinedCollaborator)) == 0,
            "original buyer payment authority stays separate from delegated executor CALL and original seller proof"
        );
        _erc20SafeFailure(joinedCollaborator, _erc20SafePayload(joinedCollaborator, data));
        require(
            offerToken.balanceOf(address(joinedBuyer)) == 9000 && core.lastAllocatedTokenId() == 1
                && joinedRecorder.totalOfficialSettled(address(offerToken)) == 1000,
            "all original signatures and payment nonce replay only once"
        );
    }

    function testActualBuyerSafeVoidRetainsOriginalOfferKeyAndNoSellerOrTokenConsumption() public {
        (ERC20OfferPlan memory p, OfferE20.Acceptance memory q) = _openArtistERC20Offer(false, true);
        PrimaryE20.ERC20SettlementCandidate memory c = artistOffers.previewExecution(q);
        bytes32 offerId = StreamMintTicketHash.authorizationId(_erc20BuyerDigest(q.offer));
        _joinedSafe(
            joinedBuyer,
            address(manager),
            0,
            abi.encodeCall(manager.voidMintOffer, (q.offer, uint8(2), bytes("")))
        );
        _erc20SafeFailure(
            joinedBuyer,
            _erc20SafePayload(
                joinedBuyer,
                abi.encodeCall(offerPayment.settleERC20PrimarySaleByPayer, (c, abi.encode(q)))
            )
        );
        require(
            ledger.isManagerAuthorizationUsed(address(manager), offerId)
                && !artistOffers.digestConsumed(_erc20SellerDigest(q.authorization))
                && !joinedRecorder.settlementConsumed(_erc20OfferKey(c))
                && ledger.counterValue(_erc20Counter(p)) == 0 && core.totalSupply() == 0
                && manager.nextOperationNonce() == 0
                && offerToken.balanceOf(address(joinedBuyer)) == 10000
                && offerToken.allowance(address(joinedBuyer), address(offerPayment)) == 10000
                && offerToken.balanceOf(wallet) == 0 && offerToken.transferCalls() == 0
                && joinedBuyer.nonce() == 2 && joinedCollector.nonce() == 0,
            "actual buyer void uses original canonical offer key and never grants seller or token authority"
        );
    }

    function _previewFails(OfferE20.Acceptance memory q) private view {
        (bool ok,) =
            address(artistOffers).staticcall(abi.encodeCall(artistOffers.previewExecution, (q)));
        require(!ok, "original offer preview rejects missing authority or changed terms");
    }

    function _assertPaymentEvent(Vm.Log[] memory logs, PrimaryE20.ERC20SettlementCandidate memory c)
        private
        view
    {
        bytes32 eventId = keccak256(
            "PrimaryRevenueExecutionBound(bytes32,address,bytes32,uint16,address,address,bytes32,bytes32,bytes32)"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(joinedRecorder) || logs[i].topics.length != 4
                    || logs[i].topics[0] != eventId
            ) continue;
            bytes32 commitment = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2"),
                    block.chainid,
                    address(offerPayment),
                    address(joinedRecorder),
                    c
                )
            );
            require(
                logs[i].topics[1] == _erc20OfferKey(c)
                    && address(uint160(uint256(logs[i].topics[2]))) == address(artistOffers)
                    && logs[i].topics[3] == c.executionBinding.executionId
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                c.executor,
                                address(offerPayment),
                                commitment,
                                c.currentPolicyHash,
                                c.boundPolicyHash
                            )
                        ),
                "exact original complete payment event identity and commitment"
            );
            ++count;
        }
        require(count == 1, "one exact original payment event");
    }
}
