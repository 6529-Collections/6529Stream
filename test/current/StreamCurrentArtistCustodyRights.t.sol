// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentArtistCustodyRightsFixture.sol";

interface ArtistCustodyFaultVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
    function mockCallRevert(
        address target,
        uint256 value,
        bytes calldata data,
        bytes calldata reason
    ) external;
    function clearMockedCalls() external;
}

contract StreamCurrentArtistCustodyRightsTest is CurrentArtistCustodyRightsFixture {
    ArtistCustodyFaultVm private constant fault =
        ArtistCustodyFaultVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setUp() public {
        _deployArtistCustody();
    }

    function testActualArtistTokenProfilePaysAfterOriginalPreparedSnapshotWithoutRemint() public {
        bytes32 id = this.custodyAcquire();
        (bytes32 p, address w) = this.custodyProfile(500000);
        bytes32 hash = this.custodyInstall(acquiredOrigin.tokenId, p, false);
        bytes32 originalAuction = keccak256(abi.encode(joinedHouse.auction(id)));
        this.custodyActivateProfile(id);
        require(
            keccak256(abi.encode(joinedHouse.auction(id))) == originalAuction
                && joinedHouse.tokenProfileCustodyActivation(id).authorization.assignmentHash
                    == hash && p != profile && w != wallet,
            "exact token override and append-only approval"
        );
        _custodyBid(id, false);
        StreamSaleTemplate.Selection memory s = _custodyProfileSelection(acquiredOrigin.tokenId);
        _custodyFinish(id, false, s);
        bytes32 key = joinedHouse.auction(id).settlementKey;
        _joinedSafe(joinedCollector, address(joinedHouse), 0, _custodySettleData(id, false));
        require(
            joinedHouse.auction(id).settlementKey == key && w.balance == JOINED_PRICE,
            "idempotent terminal without payment replay"
        );
        (bool old,) = address(joinedHouse).call(abi.encodeCall(joinedHouse.settle, (id)));
        require(
            !old && wallet.balance == 0, "old collection-only route cannot spend activated sale"
        );
    }

    function testActualDynamicTokenTemplateUsesOriginalPosterAndAcceptedCollaboratorThenEscrow()
        public
    {
        bytes32 id = this.custodyAcquire();
        bytes32 tid = this.joinedCreateTemplate();
        this.custodyInstall(acquiredOrigin.tokenId, tid, true);
        this.custodyActivateDynamic(id);
        (StreamSaleTemplate.Selection memory s, bytes32 beforeWitness) =
            _custodyDynamicSelection(acquiredOrigin.tokenId);
        require(
            s.templateId == tid && s.wallet.code.length == 0 && beforeWitness == _joinedWitness(),
            "actual accepted binding/payout witness and undeployed concrete wallet"
        );
        _custodyBid(id, true);
        _custodyFinish(id, true, s);
        revenueEscrow.flushEscrow(PRIMARY_REVENUE_CLASS, s.profileId, s.wallet, address(0));
        require(
            s.wallet.code.length != 0 && s.wallet.balance == JOINED_PRICE
                && revenueEscrow.totalOwed(address(0)) == 0
                && factory.profileEntryCount(s.profileId) == 4,
            "actual escrow materializes original concrete template"
        );
        _row(s.profileId, address(joinedArtist), keccak256("artist"), 300000);
        _row(s.profileId, address(joinedCollaborator), COLLAB_LABEL, 200000);
        _row(s.profileId, address(this), keccak256("poster"), 300000);
        _row(s.profileId, PROTOCOL, keccak256("protocol"), 200000);
        require(
            address(this) != address(joinedBuyer) && address(this) != address(joinedCollector),
            "neither acquisition executor nor current payer impersonates original poster"
        );
        _custodyOriginal(id, false);
    }

    function testScopeTwoNeedsActualSafeConsentAndSameScheduledOwnerActionRetries() public {
        bytes32 id = this.custodyAcquire();
        bytes memory inheritedCall = _custodyProfileCall(this.custodyProfileAuthorization(id));
        (bool inherited,) = address(joinedHouse).call(inheritedCall);
        require(
            !inherited && joinedHouse.tokenProfileCustodyConfigurationHash(id) == 0,
            "collection consent and inherited selection never authorize scope2 activation"
        );
        (bytes32 p,) = this.custodyProfile(500000);
        (bool nonexistent,) = address(primaryResolver)
            .staticcall(
                abi.encodeCall(
                    primaryResolver.previewArtistPrimaryAssignmentForScope,
                    (uint256(1), uint8(2), uint256(2), p, bytes32(0), false)
                )
            );
        require(!nonexistent, "actual Core token identity required before prospective approval");
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory datas = new bytes[](1);
        datas[0] = _custodySetCall(acquiredOrigin.tokenId, p, false);
        calls[0] = StreamCurrentStackPlan.call(
            address(primaryResolver),
            datas[0],
            keccak256(abi.encode(address(primaryResolver), datas[0])),
            0,
            keccak256(datas[0])
        );
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(1, calls, datas);
        vm.warp(ready);
        uint256 nonce = governorSafe.nonce();
        bytes memory exact = _custodySafeCall(
            governorSafe,
            address(executor),
            0,
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, datas))
        );
        fault.expectCall(address(primaryResolver), 0, datas[0], 2);
        (bool before_, bytes memory reason) = address(governorSafe).call(exact);
        require(
            !before_
                && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && governorSafe.nonce() == nonce
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED
                && _custodyProfileSelection(acquiredOrigin.tokenId).profileId == profile,
            "missing actual op15 rolls back full delayed Safe action"
        );
        this.custodyApprove(acquiredOrigin.tokenId, p, false);
        (bool after_, bytes memory result) = address(governorSafe).call(exact);
        require(
            after_ && abi.decode(result, (bool)) && governorSafe.nonce() == nonce + 1
                && executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "same signed Safe bytes and same original scheduled action succeed after actual Artist consent"
        );
        this.custodyActivateProfile(id);
        _custodyBid(id, false);
        _custodyFinish(id, false, _custodyProfileSelection(acquiredOrigin.tokenId));
    }

    function testOldSignedBidCannotCrossActivationAndOriginalSafeBidNonceIsShared() public {
        bytes32 id = this.custodyAcquire();
        IStreamNativeEnglishAuction.BidAuthorization memory b =
            IStreamNativeEnglishAuction.BidAuthorization(
                id,
                joinedHouse.auction(id).configHash,
                address(joinedCollector),
                address(this),
                address(joinedCollector),
                JOINED_PRICE,
                0,
                keccak256("actual Safe custody bid"),
                uint64(block.timestamp + 45 days),
                0
            );
        (, b.finalizeBy,,) = joinedHouse.auctionDeadlines(id);
        bytes memory signature =
            _joinedProof(joinedCollector, joinedHouse.bidAuthorizationDigest(b));
        bytes memory old = abi.encodeCall(joinedHouse.bidSigned, (b, signature));
        bytes memory oldNewEntry =
            abi.encodeCall(joinedHouse.bidSignedTokenProfileCustody, (b, signature));
        (bool noActivation,) = address(joinedHouse).call{ value: JOINED_PRICE }(oldNewEntry);
        require(
            !noActivation && joinedHouse.totalLiveBidDeposits() == 0,
            "new entry requires prior activation"
        );
        (bytes32 p,) = this.custodyProfile(500000);
        this.custodyInstall(acquiredOrigin.tokenId, p, false);
        this.custodyActivateProfile(id);
        (bool legacy,) = address(joinedHouse).call{ value: JOINED_PRICE }(old);
        (bool wrongConfig,) = address(joinedHouse).call{ value: JOINED_PRICE }(oldNewEntry);
        require(
            !legacy && !wrongConfig && joinedHouse.totalLiveBidDeposits() == 0,
            "old signed config closed through both families"
        );
        b.configHash = joinedHouse.tokenProfileCustodyConfigurationHash(id);
        signature = _joinedProof(joinedCollector, joinedHouse.bidAuthorizationDigest(b));
        bytes memory exact =
            abi.encodeCall(joinedHouse.bidSignedTokenProfileCustody, (b, signature));
        (bool ok,) = address(joinedHouse).call{ value: JOINED_PRICE }(exact);
        require(
            ok && joinedHouse.auction(id).winner.signed
                && joinedHouse.auction(id).winner.payer == address(joinedCollector)
                && joinedHouse.auction(id).winner.executor == address(this)
                && joinedHouse.auction(id).winner.authorizationDigest
                    == joinedHouse.bidAuthorizationDigest(b),
            "actual Safe principal and distinct funded executor with exact original bid domain"
        );
        (bool replay,) = address(joinedHouse).call{ value: JOINED_PRICE }(exact);
        require(
            !replay && joinedHouse.totalLiveBidDeposits() == JOINED_PRICE,
            "same original bid nonce consumed only on success"
        );
        _custodyFinish(id, false, _custodyProfileSelection(acquiredOrigin.tokenId));
    }

    function testActualDynamicEscrowFailurePreservesCompleteSignedSafeRetry() public {
        bytes32 id = this.custodyAcquire();
        bytes32 tid = this.joinedCreateTemplate();
        this.custodyInstall(acquiredOrigin.tokenId, tid, true);
        this.custodyActivateDynamic(id);
        (StreamSaleTemplate.Selection memory s,) = _custodyDynamicSelection(acquiredOrigin.tokenId);
        _custodyBid(id, true);
        _custodyEnd(id);
        uint256 nonce = joinedCollector.nonce();
        bytes memory exact = _custodySafeCall(
            joinedCollector, address(joinedHouse), 0, _custodySettleData(id, true)
        );
        bytes memory credit = abi.encodeCall(
            revenueEscrow.creditNative, (PRIMARY_REVENUE_CLASS, s.profileId, s.wallet, true)
        );
        require(
            address(revenueEscrow).balance == 0 && s.wallet.code.length == 0,
            "zero escrow funding baseline"
        );
        bytes32 beforeAuction = keccak256(abi.encode(joinedHouse.auction(id)));
        uint256 beforeHouse = address(joinedHouse).balance;
        fault.expectCall(address(revenueEscrow), JOINED_PRICE, credit, 2);
        fault.mockCallRevert(
            address(revenueEscrow),
            JOINED_PRICE,
            credit,
            abi.encodeWithSignature("Error(string)", "injected escrow funding failure")
        );
        (bool failed, bytes memory reason) = address(joinedCollector).call(exact);
        require(
            !failed
                && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && joinedCollector.nonce() == nonce
                && keccak256(abi.encode(joinedHouse.auction(id))) == beforeAuction
                && address(joinedHouse).balance == beforeHouse
                && core.ownerOf(acquiredOrigin.tokenId) == address(joinedHouse)
                && revenueEscrow.escrowOwed(
                    PRIMARY_REVENUE_CLASS, s.profileId, s.wallet, address(0)
                ) == 0 && joinedRecorder.totalOfficialSettled(address(0)) == 0
                && s.wallet.code.length == 0,
            "actual escrow funding denial rolls back NFT, official ledger, auction and Safe replay"
        );
        _custodyOriginal(id, true);
        fault.clearMockedCalls();
        IStreamNativeEnglishAuction.Auction memory sale = joinedHouse.auction(id);
        sale.status = 2;
        StreamNativeCustodySettlementTypes.Facts memory facts =
            StreamNativeCustodySettlementTypes.Facts(id, sale, acquiredOrigin);
        vm.recordLogs();
        (bool success, bytes memory result) = address(joinedCollector).call(exact);
        require(
            success && abi.decode(result, (bool)) && joinedCollector.nonce() == nonce + 1,
            "byte-identical signed Safe retry"
        );
        _custodyReceipt(id, true, s, facts, vm.getRecordedLogs());
    }

    function testAllowCurrentRequiresNewActualScopeTwoConsentWhileFrozenRoyaltyPersists() public {
        bytes32 id = this.custodyAcquire();
        (bytes32 first, address firstWallet) = this.custodyProfile(500000);
        this.custodyInstall(acquiredOrigin.tokenId, first, false);
        this.custodyActivateProfile(id);
        bytes32 activation = keccak256(abi.encode(joinedHouse.tokenProfileCustodyActivation(id)));
        _custodyBid(id, false);
        (bytes32 next, address nextWallet) = this.custodyProfile(400000);
        this.custodyInstall(acquiredOrigin.tokenId, next, false);
        require(
            keccak256(abi.encode(joinedHouse.tokenProfileCustodyActivation(id))) == activation,
            "original ALLOW_CURRENT activation not rewritten by approved current override"
        );
        _custodyFinish(id, false, _custodyProfileSelection(acquiredOrigin.tokenId));
        require(
            firstWallet.balance == 0 && nextWallet.balance == JOINED_PRICE
                && royalties.tokenRoyalty(acquiredOrigin.tokenId).royaltyBps == 600,
            "new primary terms are independent from original frozen token royalty"
        );
    }

    function testNoBidOriginalPosterExitSurvivesCurrentTemplateFamilyLoss() public {
        bytes32 id = this.custodyAcquire();
        bytes32 tid = this.joinedCreateTemplate();
        this.custodyInstall(acquiredOrigin.tokenId, tid, true);
        this.custodyActivateDynamic(id);
        (bytes32 p,) = this.custodyProfile(500000);
        this.custodyInstall(acquiredOrigin.tokenId, p, false);
        (bool current,) = address(this)
            .staticcall(abi.encodeCall(this.custodyRequireDynamic, (acquiredOrigin.tokenId)));
        require(!current, "actual PROFILE no longer satisfies activated TEMPLATE family");
        _custodyEnd(id);
        joinedHouse.settle(id);
        require(
            core.ownerOf(acquiredOrigin.tokenId) == address(this)
                && joinedRecorder.totalOfficialSettled(address(0)) == 0
                && joinedHouse.auction(id).winner.amount == 0
                && joinedHouse.refundableBalance(
                    joinedHouse.auction(id).saleId, address(joinedBuyer)
                ) == 50,
            "original no-bid return independent of current payment admission; reveal excess still belongs to executor"
        );
        _custodyOriginal(id, false);
    }

    function custodyRequireDynamic(uint256 token) external view {
        _custodyDynamicSelection(token);
    }

    function _row(bytes32 p, address account, bytes32 label, uint32 share) private view {
        uint256 found;
        for (uint256 i; i < factory.profileEntryCount(p); ++i) {
            IStreamSplitWallet.SplitEntry memory r;
            (r.account, r.sharePpm, r.labelId) = factory.profileEntry(p, i);
            if (r.account == account && r.labelId == label && r.sharePpm == share) ++found;
        }
        require(found == 1, "exact materialized source row");
    }
}
