// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeCustodyAuctionFixture.sol";

interface CustodyFaultVM {
    function mockCallRevert(
        address target,
        uint256 value,
        bytes calldata data,
        bytes calldata result
    ) external;
    function expectCall(address target, uint256 value, bytes calldata data) external;
    function clearMockedCalls() external;
}

contract StreamCurrentNativeCustodyAuctionTest is NativeCustodyAuctionFixture {
    CustodyFaultVM private constant faults =
        CustodyFaultVM(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testUnpaidAcquisitionThenOfficialTransferConsumesOneMintAndPreservesOriginalReceipt()
        public
    {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        StreamNativeCustodySettlementTypes.Origin memory o = house.custodyOrigin(id);
        require(
            o.eligible && o.manager == address(manager)
                && o.managerCodeHash == address(manager).codehash && o.tokenId == 1
                && o.collectionSerial == 1 && o.operationNonce == 0
                && o.authorizationId == house.custodyAcquisitionDigest(p.auth)
                && o.tokenDataHash == keccak256(p.artwork) && o.operationRoot != 0
                && o.operationId != 0 && manager.isOperationRootUsed(o.operationRoot)
                && manager.isAuthorizationUsed(o.authorizationId)
                && core.ownerOf(1) == address(house) && manager.nextOperationNonce() == 1
                && core.collectionNextSerial(1) == 2 && _custodyCounter(p) == 1,
            "actual original singleton acquisition"
        );
        require(
            wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && entropy.revealFeeEscrow(1) == 100 && o.revealFeeForwarded == 100
                && house.refundableBalance(house.auction(id).saleId, address(this)) == 50,
            "operator funded reveal only; remainder belongs to operator"
        );
        _custodyBid(id, payer, 1000);
        _custodyEnd(id);
        IStreamNativeEnglishAuction.Auction memory activeAuction = house.auction(id);
        activeAuction.status = 2;
        StreamNativeCustodySettlementTypes.Facts memory originalFacts =
            StreamNativeCustodySettlementTypes.Facts(id, activeAuction, o);
        vm.recordLogs();
        (uint256 token, bytes32 key) = house.settle(id);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            recorder.settlementResult(key);
        require(
            token == 1 && core.ownerOf(1) == payer && wallet.balance == 1000
                && recorder.totalOfficialSettled(address(0)) == 1000 && r.amount == 1000
                && r.executor == payer && r.operationIdentityCommitment == 0
                && r.currentPolicyHash == 0 && r.boundPolicyHash == 0
                && recorder.nativeCustodyFactsHash(key) != 0 && manager.nextOperationNonce() == 1
                && core.collectionNextSerial(1) == 2 && core.lastAllocatedTokenId() == 1
                && _custodyCounter(p) == 1 && !house.custodyOrigin(id).eligible,
            "paid transfer has no second mint"
        );
        bytes32 expectedFacts = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CUSTODY_TRANSFER_FACTS_V1"),
                block.chainid,
                address(recorder),
                address(house),
                originalFacts
            )
        );
        require(
            recorder.nativeCustodyFactsHash(key) == expectedFacts,
            "original full acquisition/payment facts"
        );
        bytes32 originalSaleKey = recorder.preparedNativeSaleKey(
            address(house), originalFacts.auction.saleId, originalFacts.auction.saleNonce
        );
        uint256 found;
        // Exact ABI-derived NativeCustodyRevenueRecorded topic, not another four-topic revenue event.
        bytes32 topic = 0x82113188b64cd0cfbe54448fa01fe114ef7e47d59f943d28e971d6e4a2b5e8d9;
        for (uint256 n; n < logs.length; ++n) {
            if (
                logs[n].emitter == address(recorder) && logs[n].topics.length == 4
                    && logs[n].topics[0] == topic
            ) {
                require(
                    logs[n].topics[1] == key && logs[n].topics[2] == originalSaleKey
                        && logs[n].topics[3] == expectedFacts
                        && keccak256(logs[n].data) == keccak256(abi.encode(originalFacts, r)),
                    "complete original custody event bytes"
                );
                ++found;
            }
        }
        require(found == 1, "one custody receipt");
        require(
            recorder.preparedNativeSaleConsumed(
                recorder.preparedNativeSaleKey(
                    address(house), house.auction(id).saleId, house.auction(id).saleNonce
                )
            ),
            "original sale consumed"
        );
        (uint256 again, bytes32 same) = house.settle(id);
        require(again == token && same == key && wallet.balance == 1000, "terminal idempotence");
        house.claimRefund(house.auction(id).saleId, payable(address(this)));
        require(
            house.totalBuyerLiabilities() == 0 && address(house).balance == 0,
            "operator remainder separate from winner"
        );
        Plan memory second = _custodyPlan(false, address(this), address(this));
        bytes32 next = _openCustody(second);
        _custodyBid(next, payer, 1100);
        _custodyEnd(next);
        (uint256 nextToken, bytes32 nextKey) = house.settle(next);
        require(
            nextToken == 2 && nextKey != key && core.ownerOf(2) == payer
                && manager.nextOperationNonce() == 2 && core.collectionNextSerial(1) == 3
                && _custodyCounter(second) == 1 && _custodyCounter(p) == 1 && wallet.balance == 2100
                && recorder.totalOfficialSettled(address(0)) == 2100
                && recorder.nativeCustodyFactsHash(key) == expectedFacts,
            "second distinct original acquisition and payment release both guards without rewriting first receipt"
        );
    }

    function testCanonicalPinRequiresOriginalGovernanceContextAndCannotRebindOrAdmitRuntimeSubstitute()
        public
    {
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes memory exact = _custodyCall(p);
        (bool ok,) = address(house).call{ value: 150 }(exact);
        require(!ok && core.lastAllocatedTokenId() == 0, "unbound custody unavailable");
        (bytes32 scope, bytes32 old_, bytes32 next) =
            recorder.custodyHouseTransition(address(house));
        _context(scope, old_, next, 1);
        (ok,) = address(recorder)
            .call(abi.encodeCall(recorder.bindCanonicalCustodyHouse, (address(house))));
        require(!ok, "context alone is not original caller");
        for (uint8 mode; mode < 4; ++mode) {
            _context(
                mode == 1 ? bytes32(uint256(1)) : scope,
                mode == 2 ? bytes32(uint256(1)) : old_,
                mode == 3 ? bytes32(uint256(1)) : next,
                mode == 0 ? 0 : 1
            );
            vm.prank(address(revenueAuthority));
            (ok,) = address(recorder)
                .call(abi.encodeCall(recorder.bindCanonicalCustodyHouse, (address(house))));
            require(
                !ok && recorder.canonicalCustodyHouse().house == address(0),
                "full context atomically checked"
            );
        }
        _clearContext();
        _bindCustody();
        require(
            recorder.canonicalCustodyHouse().house == address(house)
                && recorder.canonicalCustodyHouse().codeHash == address(house).codehash,
            "actual selected implementation"
        );
        vm.prank(address(revenueAuthority));
        (ok,) = address(recorder)
            .call(abi.encodeCall(recorder.bindCanonicalCustodyHouse, (address(house))));
        require(!ok, "once-only binding");
        bytes memory original = address(house).code;
        vm.etch(address(house), hex"60006000fd");
        (ok,) = address(recorder)
            .staticcall(abi.encodeCall(recorder.requireCanonicalCustodyHouse, (address(house))));
        require(!ok, "pinned original runtime cannot be replaced");
        vm.etch(address(house), original);
        recorder.requireCanonicalCustodyHouse(address(house));
    }

    function testFuzzWrongAcquisitionCoordinateRollsBackThenIdenticalOriginalOpening(uint8 choice)
        public
    {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes memory exact = _custodyCall(p);
        uint8 n = choice % 8;
        if (n == 0) p.artwork = bytes("different work");
        else if (n == 1) ++p.auth.expectedTokenId;
        else if (n == 2) ++p.auth.expectedCollectionSerial;
        else if (n == 3) ++p.auth.expectedOperationNonce;
        else if (n == 4) ++p.auth.expectedSaleNonce;
        else if (n == 5) p.auth.contextHash = bytes32(uint256(3));
        else if (n == 6) p.auth.executor = payer;
        else p.auth.revealFeeDeposit = 149;
        (bool ok,) = address(house).call{ value: 150 }(_custodyCall(p));
        require(
            !ok && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && manager.nextOperationNonce() == 0 && house.totalBuyerLiabilities() == 0
                && address(house).balance == 0 && entropy.revealFeeEscrow(1) == 0,
            "wrong coordinate leaves entire acquisition untouched"
        );
        (ok,) = address(house).call{ value: 150 }(exact);
        require(
            ok && core.ownerOf(1) == address(house) && manager.nextOperationNonce() == 1,
            "identical original signed opening retries"
        );
        (ok,) = address(house).call{ value: 150 }(exact);
        require(!ok && manager.nextOperationNonce() == 1, "original acquisition replay rejected");
    }

    function testRecipientAndPayerCountersRejectButConsumedMintPhaseNeverGatesPaidTransfer()
        public
    {
        _bindCustody();
        for (uint8 n; n < 2; ++n) {
            bytes32 phase = keccak256(abi.encode("forbidden custody phase", n));
            _custodyPhase(
                phase,
                n == 0
                    ? IStreamMintManager.CounterKeyMode.RECIPIENT
                    : IStreamMintManager.CounterKeyMode.PAYER
            );
            Plan memory wrong = _custodyPlan(false, address(this), address(this));
            wrong.config.phaseId = phase;
            wrong.config.mintPolicyHash = manager.phasePolicyHash(1, phase);
            _signCustody(wrong);
            (bool ok,) = address(house).call{ value: 150 }(_custodyCall(wrong));
            require(
                !ok && manager.nextOperationNonce() == 0, "forbidden custody counter cannot mint"
            );
        }
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        manager.setPhasePaused(1, CUSTODY_PHASE, true);
        manager.setPhaseExecutor(1, CUSTODY_PHASE, address(house), false);
        _custodyBid(id, payer, 1000);
        _custodyEnd(id);
        house.settle(id);
        require(
            core.ownerOf(1) == payer && manager.nextOperationNonce() == 1
                && _custodyCounter(p) == 1,
            "original phase is not replayed by custody transfer"
        );
    }

    function testNoBidAndCancelKeepPosterClaimsUsableAfterAdmissionLossAndNeverReviveOrigin()
        public
    {
        _bindCustody();
        NativeAuctionReceiver poster = new NativeAuctionReceiver();
        poster.configure(true, false, address(0), "", address(0));
        Plan memory p = _custodyPlan(false, address(poster), address(this));
        bytes32 id = _openCustody(p);
        _custodyEnd(id);
        house.settle(id);
        require(
            house.auction(id).status == 5 && house.auction(id).nftClaimant == address(poster)
                && core.ownerOf(1) == address(house) && wallet.balance == 0,
            "no-bid poster pull claim"
        );
        _status(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
        poster.callTarget(address(house), 0, abi.encodeCall(house.claimNFT, (id, payer)));
        require(
            core.ownerOf(1) == payer && !house.custodyOrigin(id).eligible,
            "poster escape ignores admission loss"
        );
        vm.prank(payer);
        core.transferFrom(payer, address(house), 1);
        require(
            !house.custodyOrigin(id).eligible, "unsafe later return never revives original custody"
        );
        _status(address(recorder), ModuleRegistryStatus.ACTIVE);
        Plan memory second = _custodyPlan(true, address(this), address(this));
        bytes32 next = _openCustody(second);
        house.cancel(next, keccak256("poster cancel"));
        require(
            house.auction(next).status == 4 && core.ownerOf(2) == address(this)
                && !house.custodyOrigin(next).eligible
                && recorder.totalOfficialSettled(address(0)) == 0,
            "unstarted first-bid cancellation releases second original token without revenue"
        );
    }

    function testSignedCeilingRefundsWinnerAndReturnsPosterCustodyDuringIncidentAndPause() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        (, uint64 deadline,,) = house.auctionDeadlines(id);
        IStreamNativeEnglishAuction.BidAuthorization memory bid =
            IStreamNativeEnglishAuction.BidAuthorization(
                id,
                house.auction(id).configHash,
                payer,
                address(this),
                payer,
                1000,
                0,
                keccak256("signed custody winner"),
                uint64(block.timestamp + 100),
                deadline
            );
        bytes memory proof = _custodyProof(PAYER_KEY, house.bidAuthorizationDigest(bid));
        house.bidSigned{ value: 1000 }(bid, proof);
        vm.prank(address(0xA11));
        house.pauseAdapter(keccak256("pause"));
        _status(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.warp(deadline + 1);
        house.unlockCustodySale(id, 0);
        require(
            house.auction(id).status == 6 && core.ownerOf(1) == address(this)
                && house.refundableBalance(house.auction(id).saleId, payer) == 1000
                && house.refundableBalance(house.auction(id).saleId, address(this)) == 50
                && !house.custodyOrigin(id).eligible && wallet.balance == 0,
            "signed ceiling preserves distinct payer refund and poster custody"
        );
        bytes32 sale = house.auction(id).saleId;
        vm.prank(payer);
        house.claimRefund(sale, payable(payer));
        house.claimRefund(sale, payable(address(this)));
        require(
            house.totalBuyerLiabilities() == 0 && address(house).balance == 0,
            "all original liabilities escape"
        );
    }

    function testSafeAcquisitionLateCoreFailureRollsBackThenExactSignedRetrySucceeds() public {
        _bindCustody();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE91;
        keys[1] = 0x5AFE92;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 991);
        vm.deal(address(safe), 1 ether);
        Plan memory p = _custodyPlan(false, address(safe), address(safe));
        bytes memory callData = _custodyCall(p);
        bytes memory exact = _safeCustodyCall(safe, keys, 150, callData);
        entropy.configure(100, 1, true, false);
        (bool ok,) = address(safe).call(exact);
        require(
            !ok && safe.nonce() == 0 && core.lastAllocatedTokenId() == 0
                && manager.nextOperationNonce() == 0 && _custodyCounter(p) == 0
                && entropy.revealFeeEscrow(1) == 0 && house.totalBuyerLiabilities() == 0,
            "late actual Core endpoint rejection rolls back mint and Safe nonce"
        );
        entropy.configure(100, 1, false, false);
        bytes memory raw;
        (ok, raw) = address(safe).call(exact);
        require(
            ok && raw.length == 32 && abi.decode(raw, (bool)) && safe.nonce() == 1
                && safe.getThreshold() == 2 && core.ownerOf(1) == address(house)
                && _custodyCounter(p) == 1 && entropy.revealFeeEscrow(1) == 100,
            "identical Safe signature completes original unpaid acquisition"
        );
    }

    function testSafePaidTransferFundingFailureRollsBackReplayAndIdenticalRetryKeepsMintUntouched()
        public
    {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE93;
        keys[1] = 0x5AFE94;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 992);
        vm.deal(address(safe), 1 ether);
        (bool ok, bytes memory raw) = address(safe)
            .call(_safeCustodyCall(safe, keys, 1000, abi.encodeCall(house.bid, (id, address(0)))));
        require(ok && abi.decode(raw, (bool)), "Safe zero-fee custody bid");
        _custodyEnd(id);
        bytes memory exact = _safeCustodyCall(safe, keys, 0, abi.encodeCall(house.settle, (id)));
        (bytes32 scope, bytes32 old_, bytes32 next) =
            escrow.creditProducerTransitionHashes(address(recorder), false);
        _context(scope, old_, next, 1);
        vm.prank(address(revenueAuthority));
        escrow.setCreditProducer(address(recorder), false);
        _clearContext();
        // Inject only the wallet deposit CALL failure; the actual escrow producer guard then rejects.
        faults.mockCallRevert(
            wallet, 1000, "", abi.encodeWithSignature("Error(string)", "deposit fault")
        );
        require(factory.splitWalletExists(profile), "zero-value wallet verification remains actual");
        faults.expectCall(wallet, 1000, "");
        faults.expectCall(
            address(escrow),
            1000,
            abi.encodeCall(escrow.creditNative, (keccak256("PRIMARY_SALE"), profile, wallet, false))
        );
        (ok,) = address(safe).call(exact);
        require(
            !ok && safe.nonce() == 1 && house.auction(id).status == 1
                && house.totalLiveBidDeposits() == 1000 && house.totalBuyerLiabilities() == 1050
                && core.ownerOf(1) == address(house) && manager.nextOperationNonce() == 1
                && _custodyCounter(p) == 1 && recorder.totalOfficialSettled(address(0)) == 0
                && !recorder.preparedNativeSaleConsumed(
                    recorder.preparedNativeSaleKey(
                        address(house), house.auction(id).saleId, house.auction(id).saleNonce
                    )
                ),
            "actual late escrow rejection preserves original sale"
        );
        faults.clearMockedCalls();
        (scope, old_, next) = escrow.creditProducerTransitionHashes(address(recorder), true);
        _context(scope, old_, next, 1);
        vm.prank(address(revenueAuthority));
        escrow.setCreditProducer(address(recorder), true);
        _clearContext();
        (ok, raw) = address(safe).call(exact);
        require(
            ok && abi.decode(raw, (bool)) && safe.nonce() == 2 && core.ownerOf(1) == address(safe)
                && wallet.balance == 1000 && manager.nextOperationNonce() == 1
                && _custodyCounter(p) == 1,
            "same signed payment retry consumes no additional mint"
        );
    }

    function testHostileDeliveryRecordsPaymentBeforeClaimAndBlocksCallbackReplay() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        CustodyObservingReceiver receiver = new CustodyObservingReceiver(house, recorder);
        receiver.configure(id, true);
        receiver.placeBid{ value: 1000 }();
        _custodyEnd(id);
        (, bytes32 key) = house.settle(id);
        require(
            core.ownerOf(1) == address(house) && house.auction(id).status == 3
                && house.auction(id).nftClaimant == address(receiver) && wallet.balance == 1000
                && recorder.settlementConsumed(key) && house.custodyOrigin(id).eligible,
            "rejecting NFT receiver cannot revert official payment"
        );
        receiver.configure(id, false);
        receiver.claim();
        require(
            core.ownerOf(1) == address(receiver) && receiver.sawPayment()
                && receiver.reentryRejected() && !house.custodyOrigin(id).eligible
                && house.auction(id).nftClaimant == address(0) && manager.nextOperationNonce() == 1,
            "claim observes original payment and cannot replay settlement"
        );
        (bool ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.onERC721Received, (address(manager), address(0), uint256(1), bytes(""))
                )
            );
        require(!ok, "unscoped receiver callback rejected");
    }

    function _safeCustodyCall(
        OfficialSafe safe,
        uint256[] memory keys,
        uint256 value,
        bytes memory data
    ) private returns (bytes memory) {
        bytes32 hash = safe.getTransactionHash(
            address(house), value, data, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        return abi.encodeCall(
            safe.execTransaction,
            (
                address(house),
                value,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, hash)
            )
        );
    }
}

contract CustodyObservingReceiver is IERC721Receiver {
    StreamNativeEnglishAuction private immutable house;
    StreamPrimarySaleSettlement private immutable recorder;
    bytes32 private id;
    bool private reject;
    bool public sawPayment;
    bool public reentryRejected;

    constructor(StreamNativeEnglishAuction h, StreamPrimarySaleSettlement r) {
        house = h;
        recorder = r;
    }

    function configure(bytes32 value, bool failure) external {
        id = value;
        reject = failure;
    }

    function placeBid() external payable {
        house.bid{ value: msg.value }(id, address(0));
    }

    function claim() external {
        house.claimNFT(id, address(this));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(!reject, "deliberate receiver rejection");
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        sawPayment = a.status == 3 && recorder.settlementConsumed(a.settlementKey)
            && recorder.settlementResult(a.settlementKey).amount == 1000;
        (bool ok,) = address(house).call(abi.encodeCall(house.settle, (id)));
        reentryRejected = !ok;
        return IERC721Receiver.onERC721Received.selector;
    }
}
