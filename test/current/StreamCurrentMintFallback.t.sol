// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamMintFallbackFixture.sol";

/// @notice Actual current Core/Artist/Manager/Ledger/Registry/Manifest and threshold-two Safe.
/// @dev External entropy and lifetime eligibility remain the fixture's stated boundaries.
/// Native acceptance is pending the coordinator's matched-source capture.
contract StreamCurrentMintFallbackTest is StreamMintFallbackFixture {
    function testGenesisDistinctReserveHasCommonLedgerAndIndependentGasInventory() public {
        _setupFallback();
        StreamMintFallbackPlan.requireReserveReady(reserve);
        (bool classified, bytes32 classifierHash, uint64 classifierRevision,) =
            executor.tighteningCallConfig(address(ledger), ledger.retireLedgerWriter.selector);
        require(
            classified && classifierHash == address(ledger).codehash && classifierRevision == 1,
            "genesis exact-code retirement tightening classifier"
        );
        require(address(manager) != address(successor), "distinct deployed reserve");
        require(
            address(manager.mintLedger()) == address(ledger)
                && address(successor.mintLedger()) == address(ledger),
            "one authoritative Ledger"
        );
        require(
            StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target == address(manager),
            "reserve admission never changes primary"
        );
        require(
            StreamCurrentStackPlan.readPointer(core, keccak256("MINT_MANAGER_FALLBACK")).target
                == address(0),
            "fallback inventory role is not another pointer family"
        );
        bytes32 parameter = successor.GGP_ARTIST_AUTHORITY_GAS_LIMIT();
        uint256 originalValue = manager.gasParameter(parameter);
        _raiseSuccessorArtistBudget(300_000);
        require(
            successor.gasParameter(parameter) == 300_000
                && manager.gasParameter(parameter) == originalValue,
            "host-local independent gas profile"
        );
    }

    function testReservePlannerRejectsAliasedManagerAndChangedDependencyPins() public {
        _setupFallback();
        StreamMintFallbackPlan.Configuration memory altered = reserve;
        altered.fallbackManager = manager;
        altered.fallbackCodeHash = address(manager).codehash;
        vm.expectRevert();
        this.validateReserve(altered);
        altered = reserve;
        altered.coreCodeHash ^= bytes32(uint256(1));
        vm.expectRevert();
        this.validateReserve(altered);
        altered = reserve;
        altered.chainId += 1;
        vm.expectRevert();
        this.validateReserve(altered);
        StreamMintFallbackPlan.requireReserveReady(reserve);
    }

    function validateReserve(StreamMintFallbackPlan.Configuration calldata c) external view {
        StreamMintFallbackPlan.requireReserveReady(c);
    }

    function testIncidentSafeSchedulingRealImportAndPermissionlessClass3Activation() public {
        _setupFallback();
        _activateFallback();
        StreamMintFallbackPlan.Configuration memory reversed = reserve;
        reversed.primary = successor;
        reversed.primaryCodeHash = address(successor).codehash;
        reversed.fallbackManager = manager;
        reversed.fallbackCodeHash = address(manager).codehash;
        vm.expectRevert();
        this.validateReserve(reversed);
        require(
            ledger.ledgerWriterRetiredAt(address(manager)) != 0, "one-way retirement is durable"
        );
        require(
            !ledger.isMintSuccessorReady(address(ledger), address(successor), address(manager)),
            "old Manager cannot borrow its descendant's import for a return"
        );
        // Exercise the real owner path: the permanently retired writer cannot be re-enabled.
        bytes memory data = abi.encodeCall(ledger.setLedgerWriter, (address(manager), true));
        GovernanceActionRequest memory request = _governanceRequest(
            1,
            address(ledger),
            data,
            keccak256(abi.encode(address(ledger), data)),
            0,
            keccak256(data)
        );
        bytes32 action = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        uint256 nonce = continuitySafe.nonce();
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        require(
            !ledger.ledgerWriter(address(manager)) && continuitySafe.nonce() == nonce
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "real retired-writer return rejects and rolls back the Safe envelope"
        );
    }

    function testFallbackFreshConsentReplayCapsAndExactSafeDeliveryRetry() public {
        _exerciseFallbackMint(false);
    }

    function testFallbackPreparedMintLateFailureRollsBackAndClearsSentinelOnExactSafeRetry()
        public
    {
        _exerciseFallbackMint(true);
    }

    function testPredecessorAuctionCustodyCreditsAndLateSettlementRollbackSurviveFallback() public {
        _setupFallback();
        (bytes32 policy,,) = auction.primaryPolicy(1);
        IStreamEnglishAuctionHouse.AuctionAuthorization memory a =
            IStreamEnglishAuctionHouse.AuctionAuthorization({
                collectionId: 1,
                phaseId: AUCTION_PHASE,
                artist: artist,
                profileId: profile,
                expectedPrimaryPolicyHash: policy,
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("predecessor custody obligation"),
                mintPolicyHash: manager.phasePolicyHash(1, AUCTION_PHASE),
                reservePrice: 0.01 ether,
                startTime: uint64(block.timestamp),
                endTime: uint64(block.timestamp + 1 days),
                extensionWindow: 0,
                minBidIncrementBps: 500,
                nonce: keccak256("original auction before incident"),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: auction.signerEpoch()
            });
        bytes32 digest = auction.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        pendingAuctionToken =
            auction.createAuction(a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest));
        require(
            pendingAuctionToken == 3 && core.ownerOf(3) == address(auction),
            "real predecessor auction holds a completed NFT"
        );
        address firstBidder = address(0xB1D1);
        vm.deal(firstBidder, 1 ether);
        vm.prank(firstBidder);
        auction.bid{ value: 0.02 ether }(3, firstBidder);
        CurrentContinuityReceiver receiver = new CurrentContinuityReceiver();
        vm.deal(BUYER, 1 ether);
        vm.prank(BUYER);
        auction.bid{ value: 0.03 ether }(3, address(receiver));
        IStreamEnglishAuctionHouse.Auction memory original = auction.auction(3);
        require(
            auction.refundCredit(firstBidder) == 0.02 ether && auction.totalOwed() == 0.05 ether,
            "live escrow and original pull credit exist before switch"
        );
        _activateFallback();
        require(
            keccak256(abi.encode(auction.auction(3))) == keccak256(abi.encode(original))
                && core.ownerOf(3) == address(auction)
                && ledger.isManagerOperationRootUsed(address(manager), original.operationRoot),
            "fallback preserves original custody and operation receipt"
        );
        uint256 proceeds = wallet.balance;
        vm.expectRevert();
        auction.settle(3);
        require(
            keccak256(abi.encode(auction.auction(3))) == keccak256(abi.encode(original))
                && wallet.balance == proceeds && auction.totalOwed() == 0.05 ether
                && core.ownerOf(3) == address(auction),
            "late delivery failure rolls back original escrow settlement after fallback"
        );
        receiver.accept();
        auction.settle(3);
        require(
            core.ownerOf(3) == address(receiver) && wallet.balance == proceeds + 0.03 ether
                && auction.totalOwed() == 0.02 ether,
            "old custody obligation settles exactly once"
        );
        uint256 balance = firstBidder.balance;
        vm.prank(firstBidder);
        auction.withdrawRefund(payable(firstBidder));
        require(
            firstBidder.balance == balance + 0.02 ether && auction.totalOwed() == 0
                && auction.refundCredit(firstBidder) == 0,
            "old pull refund survives writer retirement"
        );
        vm.expectRevert();
        auction.settle(3);
        require(
            ledger.isManagerOperationRootUsed(address(manager), original.operationRoot)
                && manager.nextOperationNonce() == 3 && successor.nextOperationNonce() == 0,
            "liability settlement never rewrites mint receipts or successor nonce"
        );
    }

    function _exerciseFallbackMint(bool prepared) internal {
        _setupFallback();
        _activateFallback();
        preparedExecution = prepared;
        _configureSuccessorWithFreshConsent();
        (IStreamMintManager.MintBatch memory spent, bytes memory spentData) =
            _mintRequest(successor, CLAIM, keccak256("new authorization for spent entitlement"));
        require(
            spent.authorizationId != originalAuthorization
                && !nextLedger.isManagerAuthorizationUsed(address(successor), spent.authorizationId)
                && nextLedger.isManagerNullifierUsed(
                    address(successor), gate.claimNullifier(CLAIM)
                ),
            "fresh successor authorization with actually imported spent nullifier"
        );
        bytes32 before_ = _baseline();
        uint256 safeNonce = continuitySafe.nonce();
        (bool ok,) = address(continuitySafe).call(_signedSuccessorCall(spent, spentData));
        require(!ok, "imported lifetime entitlement cannot be spent again");
        _assertSuccessorFailure(spent, before_, safeNonce, 0);
        _assertImported();

        CurrentContinuityReceiver recipient = new CurrentContinuityReceiver();
        bytes32 freshClaim = keccak256("remaining lifetime entitlement");
        bytes32 freshNonce = keccak256("fresh successor authorization");
        (IStreamMintManager.MintBatch memory fresh, bytes memory freshData) =
            _mintRequest(successor, freshClaim, freshNonce);
        // Counter subject remains the original beneficiary while initial delivery may fail.
        fresh.initialRecipients[0] = address(recipient);
        fresh.authorizationId = gate.authorization(
            address(successor), address(continuitySafe), fresh, freshClaim, freshNonce
        );
        bytes memory savedCall = _signedSuccessorCall(fresh, freshData);
        (ok,) = address(continuitySafe).call(savedCall);
        require(!ok, "receiver rejection rolls back successor mint and prior accounting");
        _assertSuccessorFailure(fresh, before_, safeNonce, freshClaim);
        require(
            core.pendingPreparedMintTokenId() == 0, "failed whole prepared call leaves no liability"
        );
        StreamPreparedMintRecord memory pending = core.preparedMint(3);
        require(!pending.exists, "late failure removes prepared record");
        _assertImported();
        recipient.accept();
        (ok,) = address(continuitySafe).call(savedCall);
        require(
            ok && continuitySafe.nonce() == safeNonce + 1,
            "byte-identical signed Safe retry succeeds"
        );
        require(
            core.lastAllocatedTokenId() == 3 && core.collectionMintedEver(1) == 3
                && core.totalSupply() == 3 && core.ownerOf(1) == BUYER && core.ownerOf(2) == BUYER
                && core.ownerOf(3) == address(recipient),
            "actual successor mint preserves lifetime IDs and prior owners"
        );
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(3);
        require(
            exists && collection == 1 && serial == 3 && !burned,
            "original Core allocates next collection serial"
        );
        require(
            manager.nextOperationNonce() == 2 && successor.nextOperationNonce() == 1
                && nextLedger.isManagerAuthorizationUsed(address(successor), fresh.authorizationId)
                && nextLedger.isManagerNullifierUsed(
                    address(successor), gate.claimNullifier(freshClaim)
                ) && wallet.balance == 0.01 ether,
            "new Manager domain, retained proceeds and real replay consumption"
        );
        for (uint256 i; i < leaves.length; ++i) {
            require(
                _value(ledger, manager, leaves[i]) == 1, "retired predecessor counters never change"
            );
            require(
                _value(nextLedger, successor, leaves[i]) == (i == 0 ? 1 : 2),
                "imported global and collection floors increment without reset"
            );
        }

        require(
            core.pendingPreparedMintTokenId() == 0,
            "successful fallback completes preparation atomically"
        );

        bytes32 excessClaim = keccak256("claim beyond remaining imported cap");
        (IStreamMintManager.MintBatch memory excess, bytes memory excessData) =
            _mintRequest(successor, excessClaim, keccak256("over-cap authorization"));
        before_ = _baseline();
        safeNonce = continuitySafe.nonce();
        (ok,) = address(continuitySafe).call(_signedSuccessorCall(excess, excessData));
        require(!ok, "imported two-token cap is exhausted after exactly one successor mint");
        _assertSuccessorFailure(excess, before_, safeNonce, excessClaim);
        for (uint256 i; i < leaves.length; ++i) {
            require(
                _value(ledger, manager, leaves[i]) == 1
                    && _value(nextLedger, successor, leaves[i]) == (i == 0 ? 1 : 2),
                "rejected excess leaves predecessor and successor floors unchanged"
            );
        }
    }
}
