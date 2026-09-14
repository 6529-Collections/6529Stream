// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/NativeEnglishAuctionFixture.sol";

/// @notice Actual current paid-PREPARED auction composition; semantic boundaries are in fixture.
contract StreamCurrentNativeEnglishAuctionTest is NativeEnglishAuctionFixture {
    uint256 private creationNonce;

    function _config(bool first)
        private
        view
        returns (IStreamNativeEnglishAuction.Configuration memory c)
    {
        c.collectionId = 1;
        c.phaseId = PHASE;
        c.mintAtSettlement = true;
        c.artworkCommitment = keccak256("auction artwork");
        c.mintCommitment = keccak256("auction mint commitment");
        c.poster = address(this);
        c.reservePrice = 1000;
        c.minIncrementBps = 500;
        c.clock = StreamEnglishAuctionClock.Configuration(
            uint64(block.timestamp),
            first ? 0 : uint64(block.timestamp + 3600),
            first ? 3600 : 0,
            600,
            600,
            3600,
            first,
            false
        );
        c.expectedPrimaryPolicyHash = StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1);
        c.primaryPolicyMode = 1;
        c.settlementWindow = 86400;
        c.mintPolicyHash = manager.phasePolicyHash(1, PHASE);
    }

    function _proof(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _create(IStreamNativeEnglishAuction.Configuration memory c)
        private
        returns (bytes32 id)
    {
        IStreamNativeEnglishAuction.CreationAuthorization memory auth =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.auctionConfigurationHash(c),
                vm.addr(SIGNER_KEY),
                bytes32(++creationNonce),
                uint64(block.timestamp + 1000)
            );
        bytes32 digest = house.creationAuthorizationDigest(auth);
        return house.registerAuction(
            c,
            bytes("auction artwork"),
            auth,
            _proof(AUCTION_PLATFORM_KEY, digest),
            _proof(SIGNER_KEY, digest)
        );
    }

    function _publicBid(bytes32 id, address who, uint256 amount) private {
        vm.deal(who, 1 ether);
        uint256 value = amount + entropy.fee();
        vm.prank(who);
        house.bid{ value: value }(id, address(0));
        IStreamNativeEnglishAuction.WinningBid memory winner = house.auction(id).winner;
        require(
            winner.payer == who && winner.executor == who && winner.deliverTo == who,
            "actual requested public bidder"
        );
    }

    function _end(bytes32 id) private returns (uint64 end) {
        (end,,,) = house.auctionDeadlines(id);
        vm.warp(end);
    }

    function _pause(bytes32 saleId, bool global, bool value) private {
        vm.prank(value ? address(0xA11) : address(0xB22));
        if (global) {
            if (value) house.pauseAdapter(keccak256("pause"));
            else house.unpauseAdapter(keccak256("resume"));
        } else {
            if (value) house.pauseSale(saleId, keccak256("pause"));
            else house.unpauseSale(saleId, keccak256("resume"));
        }
    }

    function testFirstBidStartsOnceAndActualPreparedSettlementKeepsOriginalWorkAndFeeAccounting()
        public
    {
        IStreamNativeEnglishAuction.Configuration memory c = _config(true);
        c.clock.antiSnipeWindow = 7200;
        c.clock.antiSnipeExtension = 7200;
        c.clock.maxTotalExtension = 14400;
        bytes32 id = _create(c);
        vm.prank(payer);
        (bool ok,) = address(house).call{ value: 1099 }(abi.encodeCall(house.bid, (id, address(0))));
        require(
            !ok && house.auction(id).clock.nominalEnd == 0 && house.totalBuyerLiabilities() == 0,
            "failed reserve does not start or fund"
        );
        _publicBid(id, payer, 1000);
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        require(
            a.clock.originalEnd == 4600 && a.clock.nominalEnd == 4600 && a.winner.amount == 1000
                && a.winner.revealFee == 100,
            "first end exact, fee outside bid"
        );
        require(
            id
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_AUCTION_V1"),
                        block.chainid,
                        address(house),
                        uint256(1),
                        a.auctionNonce,
                        uint256(0),
                        false
                    )
                ),
            "permanent auction identity"
        );
        entropy.configure(50, 0, false, true);
        _end(id);
        (uint256 token, bytes32 key) = house.settle(id);
        require(
            token == 1 && key != 0 && core.ownerOf(token) == payer
                && keccak256(core.tokenData(token)) == c.artworkCommitment,
            "actual exact work delivered"
        );
        require(
            core.pendingPreparedMintTokenId() == 0 && core.tokenLifecycle(token) == 2
                && manager.activePreparedNativeMint().tokenId == 0,
            "prepare completed and cleared"
        );
        require(
            wallet.balance == 1000 && recorder.totalOfficialSettled(address(0)) == 1000
                && entropy.revealFeeEscrow(1) == 50,
            "official amount excludes reveal"
        );
        require(
            house.totalBuyerLiabilities() == 50 && house.totalLiveBidDeposits() == 0
                && house.refundableBalance(a.saleId, payer) == 50 && address(house).balance == 50,
            "fee difference pull credit"
        );
        (uint256 again, bytes32 same) = house.settle(id);
        require(
            again == token && same == key && manager.nextOperationNonce() == 1
                && core.collectionMintedEver(1) == 1,
            "idempotent actual settlement"
        );
        vm.prank(payer);
        house.claimRefund(a.saleId, payable(payer));
        require(
            address(house).balance == 0 && house.totalBuyerLiabilities() == 0,
            "claim exact remainder"
        );
    }

    function testOutbidCreditsRejectingPayerAndRecipientCanForwardDuringSuccessfulDelivery()
        public
    {
        bytes32 id = _create(_config(true));
        NativeAuctionReceiver previous = new NativeAuctionReceiver();
        previous.configure(false, true, address(0), "", address(0));
        vm.deal(address(previous), 1 ether);
        previous.callTarget(address(house), 1100, abi.encodeCall(house.bid, (id, address(0))));
        NativeAuctionReceiver winner = new NativeAuctionReceiver();
        address forwarded = address(0xF044);
        winner.configure(
            false, false, address(house), abi.encodeCall(house.settle, (id)), forwarded
        );
        vm.deal(address(winner), 1 ether);
        winner.callTarget(address(house), 1150, abi.encodeCall(house.bid, (id, address(0))));
        bytes32 saleId = house.auction(id).saleId;
        require(
            house.refundableBalance(saleId, address(previous)) == 1100
                && house.totalBuyerLiabilities() == 2250,
            "outbid is pull credit, no push"
        );
        _end(id);
        house.settle(id);
        require(
            core.ownerOf(1) == forwarded && winner.callbackRejected()
                && house.auction(id).nftClaimant == address(0),
            "forwarded NFT does not undo settlement; reentry blocked"
        );
        uint256 before = payer.balance;
        previous.callTarget(
            address(house), 0, abi.encodeCall(house.claimRefund, (saleId, payable(payer)))
        );
        require(
            payer.balance == before + 1100 && house.totalBuyerLiabilities() == 0,
            "rejecting payer chooses receiver"
        );
    }

    function testHostileNFTReceiverBecomesClaimAndCannotReplayPaymentWhilePaused() public {
        bytes32 id = _create(_config(false));
        NativeAuctionReceiver winner = new NativeAuctionReceiver();
        winner.configure(true, false, address(0), "", address(0));
        vm.deal(address(winner), 1 ether);
        winner.callTarget(address(house), 1100, abi.encodeCall(house.bid, (id, address(0))));
        _end(id);
        house.settle(id);
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        require(
            a.status == 3 && a.nftClaimant == address(winner) && core.ownerOf(1) == address(house)
                && wallet.balance == 1000,
            "payment complete, NFT claim retained"
        );
        _pause(a.saleId, true, true);
        winner.callTarget(address(house), 0, abi.encodeCall(house.claimNFT, (id, payer)));
        require(
            core.ownerOf(1) == payer && house.auction(id).nftClaimant == address(0)
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "claim remains live, no replay"
        );
        (bool ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.onPreparedNativeMint,
                    (StreamPreparedNativeSettlementTypes.Facts(
                            address(0),
                            address(0),
                            address(0),
                            0,
                            0,
                            0,
                            0,
                            0,
                            0,
                            0,
                            0,
                            address(0),
                            address(0),
                            address(0),
                            0,
                            0,
                            0,
                            0
                        ))
                )
            );
        require(!ok, "inactive callback rejects");
    }

    function testSafeLateMintFailureRollsBackEverythingAndIdenticalSignedSettlementRetries()
        public
    {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE71;
        keys[1] = 0x5AFE72;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 771);
        bytes32 id = _create(_config(false));
        vm.deal(address(safe), 1 ether);
        bytes memory bidData = abi.encodeCall(house.bid, (id, address(0)));
        bytes32 bidHash = safe.getTransactionHash(
            address(house), 1100, bidData, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        require(
            safe.execTransaction(
                address(house),
                1100,
                bidData,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, bidHash)
            ),
            "Safe public bid"
        );
        _end(id);
        uint256 nonce = safe.nonce();
        bytes memory data = abi.encodeCall(house.settle, (id));
        bytes32 hash = safe.getTransactionHash(
            address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory txData = abi.encodeCall(
            safe.execTransaction,
            (
                address(house),
                0,
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
        entropy.configure(100, 1, true, false);
        (bool ok,) = address(safe).call(txData);
        require(
            !ok && safe.nonce() == nonce && house.auction(id).status == 1
                && house.totalBuyerLiabilities() == 1100 && address(house).balance == 1100,
            "same bid and Safe nonce retained"
        );
        require(
            core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && manager.nextOperationNonce() == 0 && wallet.balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "late prepared/payment rollback"
        );
        entropy.configure(100, 1, false, false);
        bytes memory raw;
        (ok, raw) = address(safe).call(txData);
        require(
            ok && raw.length == 32 && abi.decode(raw, (bool)) && safe.nonce() == nonce + 1
                && safe.getThreshold() == 2,
            "identical signed Safe retry"
        );
        require(
            core.ownerOf(1) == address(safe) && wallet.balance == 1000
                && house.totalBuyerLiabilities() == 0,
            "actual Safe delivery/accounting"
        );
    }

    function testSignedCeilingIsImmutableAndExpiryRefundIgnoresCurrentPinsDuringOngoingPause()
        public
    {
        bytes32 id = _create(_config(true));
        IStreamNativeEnglishAuction.BidAuthorization memory a =
            IStreamNativeEnglishAuction.BidAuthorization(
                id,
                house.auction(id).configHash,
                payer,
                address(this),
                payer,
                1000,
                100,
                keccak256("bid"),
                2000,
                91000
            );
        vm.deal(address(this), 1100);
        house.bidSigned{ value: 1100 }(a, _proof(PAYER_KEY, house.bidAuthorizationDigest(a)));
        bytes32 saleId = house.auction(id).saleId;
        vm.warp(4500);
        _pause(saleId, true, true);
        vm.warp(91001);
        (uint64 end, uint64 deadline, uint64 ceiling,) = house.auctionDeadlines(id);
        require(
            end > block.timestamp && deadline == 91000 && ceiling == 91000
                && house.auction(id).winner.executor == address(this),
            "fixed original executor and signed ceiling"
        );
        vm.etch(address(recorder), hex"60006000fd");
        vm.etch(address(artists), hex"60006000fd");
        house.unlockNoMint(id, 0);
        house.unlockNoMint(id, 0);
        require(
            house.auction(id).status == 6 && house.refundableBalance(saleId, payer) == 1100
                && house.totalLiveBidDeposits() == 0 && wallet.balance == 0,
            "full once-only refund without dependency calls"
        );
        uint256 before = payer.balance;
        vm.prank(payer);
        house.claimRefund(saleId, payable(payer));
        require(
            payer.balance == before + 1100 && address(house).balance == 0,
            "refund remains live while paused and pin-invalid"
        );
    }

    function testPresetStartClipsPauseUnionAndNoBidsHasNoMintAndStableTerminalClock() public {
        IStreamNativeEnglishAuction.Configuration memory c = _config(false);
        c.clock.startTime = 2000;
        c.clock.endTime = 3000;
        bytes32 id = _create(c);
        bytes32 saleId = house.auction(id).saleId;
        _pause(saleId, true, true);
        vm.warp(1500);
        _pause(saleId, true, false);
        vm.warp(1900);
        _pause(saleId, false, true);
        vm.warp(1950);
        _pause(saleId, true, true);
        vm.warp(2050);
        _pause(saleId, true, false);
        vm.warp(2100);
        _pause(saleId, false, false);
        // Same-time checkpoints preserve the final state and do not add elapsed time.
        _pause(saleId, true, true);
        _pause(saleId, true, false);
        vm.warp(2200);
        (uint64 end,,, uint64 toll) = house.auctionDeadlines(id);
        require(end == 3100 && toll == 100, "only union overlap after live start");
        vm.warp(end);
        (uint256 token, bytes32 key) = house.settle(id);
        require(
            token == 0 && key == 0 && house.auction(id).status == 5
                && core.lastAllocatedTokenId() == 0 && house.totalBuyerLiabilities() == 0,
            "NO_BIDS no token/revenue/claim"
        );
        _pause(saleId, true, true);
        vm.warp(4000);
        (uint64 stable,,, uint64 saved) = house.auctionDeadlines(id);
        require(stable == 3100 && saved == 100, "terminal clock immutable");
    }

    function testUnstartedCancellationAndTypedAttributionUnlockPreserveCredits() public {
        bytes32 unstarted = _create(_config(true));
        vm.warp(100000);
        (bool ok,) = address(house).call(abi.encodeCall(house.settle, (unstarted)));
        require(!ok, "unstarted does not expire");
        house.cancel(unstarted, keccak256("poster cancellation"));
        require(house.auction(unstarted).status == 4, "unbid remains cancellable");
        bytes32 id = _create(_config(false));
        _publicBid(id, payer, 1000);
        _end(id);
        (ok,) = address(house).call(abi.encodeCall(house.unlockNoMint, (id, uint8(4))));
        require(!ok, "active attribution not permanent failure");
        artists.setState(4);
        house.unlockNoMint(id, 4);
        require(
            house.auction(id).status == 6
                && house.refundableBalance(house.auction(id).saleId, payer) == 1100
                && wallet.balance == 0,
            "exact disputed original unlock"
        );
    }

    function testFuzzCreationSignatureBindsEveryConfigurationWord(uint8 field) public {
        IStreamNativeEnglishAuction.Configuration memory c = _config(false);
        IStreamNativeEnglishAuction.CreationAuthorization memory a =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.auctionConfigurationHash(c), vm.addr(SIGNER_KEY), bytes32(uint256(44)), 2000
            );
        bytes memory sig = _proof(SIGNER_KEY, house.creationAuthorizationDigest(a));
        bytes memory platformSig =
            _proof(AUCTION_PLATFORM_KEY, house.creationAuthorizationDigest(a));
        // The outer tuple holds the nested clock pointer, so mutate the complete canonical ABI
        // then decode it. Every canonical configuration word, including clock scalars, is tested.
        bytes memory encoded = abi.encode(c);
        uint256 index = uint256(field) % (encoded.length / 32);
        assembly ("memory-safe") {
            let p := add(add(encoded, 32), mul(index, 32))
            mstore(p, xor(mload(p), 1))
        }
        (bool decoded, bytes memory result) =
            address(this).staticcall(abi.encodeCall(this.decodeConfiguration, (encoded)));
        if (decoded) {
            c = abi.decode(result, (IStreamNativeEnglishAuction.Configuration));
            (bool ok,) = address(house)
                .call(
                    abi.encodeCall(
                        house.registerAuction, (c, bytes("auction artwork"), a, platformSig, sig)
                    )
                );
            require(!ok, "signed original config cannot be changed");
        }
        require(
            house.totalBuyerLiabilities() == 0 && core.lastAllocatedTokenId() == 0,
            "failed declaration has no effects"
        );
    }

    function decodeConfiguration(bytes calldata raw)
        external
        pure
        returns (IStreamNativeEnglishAuction.Configuration memory)
    {
        return abi.decode(raw, (IStreamNativeEnglishAuction.Configuration));
    }

    function testSignedBidReplayWrongExecutorAndUnsupportedDeliveryDoNotConsumeValidRetry() public {
        bytes32 id = _create(_config(false));
        IStreamNativeEnglishAuction.BidAuthorization memory a =
            IStreamNativeEnglishAuction.BidAuthorization(
                id,
                house.auction(id).configHash,
                payer,
                address(this),
                payer,
                1000,
                100,
                bytes32(uint256(1)),
                2000,
                91000
            );
        bytes memory sig = _proof(PAYER_KEY, house.bidAuthorizationDigest(a));
        vm.deal(address(this), 3300);
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        (bool ok,) = address(house).call{ value: 1100 }(abi.encodeCall(house.bidSigned, (a, sig)));
        require(!ok, "wrong executor");
        artists.setConsent(false);
        (ok,) = address(house).call{ value: 1100 }(abi.encodeCall(house.bidSigned, (a, sig)));
        require(!ok, "actual sale consent gate");
        artists.setConsent(true);
        house.bidSigned{ value: 1100 }(a, sig);
        (ok,) = address(house).call{ value: 1100 }(abi.encodeCall(house.bidSigned, (a, sig)));
        require(!ok, "original bid replay");
        vm.prank(payer);
        (ok,) = address(house).call{ value: 1200 }(abi.encodeCall(house.bid, (id, address(0xDE1E))));
        require(!ok, "unsupported delivery never assumed delegated");
        require(
            house.auction(id).winner.amount == 1000 && house.totalBuyerLiabilities() == 1100,
            "failed entries preserve one original deposit"
        );
        _end(id);
        vm.prank(address(0xC011));
        (uint256 token, bytes32 key) = house.settle(id);
        require(
            token == 1 && core.ownerOf(token) == payer
                && recorder.settlementResult(key).executor == address(this),
            "permissionless trigger retains original signed executor after bid admission deadline"
        );
    }

    function testActualCappedExtensionEventsAndCurrentProfileDriftKeepOriginalEnvelope() public {
        IStreamNativeEnglishAuction.Configuration memory c = _config(false);
        c.clock.endTime = 2000;
        c.clock.antiSnipeWindow = 600;
        c.clock.antiSnipeExtension = 600;
        c.clock.maxTotalExtension = 600;
        bytes32 id = _create(c);
        _publicBid(id, payer, 1000);
        vm.warp(1999);
        vm.recordLogs();
        _publicBid(id, payer, 1050);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 extended = keccak256("AuctionExtended(bytes32,bytes32,uint64,uint64,uint32)");
        bytes32 warning = keccak256("AuctionExtensionBudgetWarning(bytes32,bytes32,uint32,uint32)");
        uint256 extensions;
        uint256 warnings;
        for (uint256 j; j < logs.length; ++j) {
            if (logs[j].emitter != address(house)) continue;
            if (logs[j].topics[0] == extended) {
                ++extensions;
                require(
                    logs[j].topics[1] == id
                        && keccak256(logs[j].data)
                            == keccak256(abi.encode(uint64(2000), uint64(2599), uint32(599))),
                    "extension exact event"
                );
            }
            if (logs[j].topics[0] == warning) {
                ++warnings;
                require(
                    keccak256(logs[j].data) == keccak256(abi.encode(uint32(599), uint32(1))),
                    "half budget exact event"
                );
            }
        }
        require(extensions == 1 && warnings == 1, "one actual extension and one warning");
        vm.warp(2598);
        _publicBid(id, payer, 1103);
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        require(
            a.clock.originalEnd == 2000 && a.clock.nominalEnd == 2600
                && a.clock.budgetWarningEmitted,
            "cap anchor retained"
        );
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(
            address(0xBEEF), 1000000, keccak256("current beneficiary")
        );
        (bytes32 changed, address newWallet) = factory.createProfile(entries, keccak256("drift"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, changed, 0);
        _end(id);
        house.settle(id);
        require(
            newWallet.balance == 1103 && wallet.balance == 0
                && house.auction(id).config.expectedPrimaryPolicyHash
                    == c.expectedPrimaryPolicyHash,
            "current PROFILE paid; original authorization retained"
        );
        require(
            house.refundableBalance(a.saleId, payer) == 2250,
            "both earlier whole deposits remain credits"
        );
    }

    function testTypedPhasePolicyAndModuleUnlocksRequireActualNonTransientFacts() public {
        bytes32 id = _create(_config(false));
        _publicBid(id, payer, 1000);
        _end(id);
        manager.setPhasePaused(1, PHASE, true);
        (bool ok,) = address(house).call(abi.encodeCall(house.unlockNoMint, (id, uint8(3))));
        require(!ok, "pause alone is transient");
        manager.setPhasePaused(1, PHASE, false);
        manager.setPhaseExecutor(1, PHASE, address(house), false);
        house.unlockNoMint(id, 3);
        require(house.auction(id).status == 6, "actual bound policy no longer matchable");
        manager.setPhaseExecutor(1, PHASE, address(house), true);
        bytes32 incidentId = _create(_config(false));
        _publicBid(incidentId, payer, 1000);
        _end(incidentId);
        _status(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
        house.unlockNoMint(incidentId, 5);
        require(house.auction(incidentId).status == 6, "actual referenced recorder incident");
        require(
            recorder.totalOfficialSettled(address(0)) == 0 && house.totalBuyerLiabilities() == 2200
                && house.totalLiveBidDeposits() == 0,
            "both original refunds preserved"
        );
    }
}
