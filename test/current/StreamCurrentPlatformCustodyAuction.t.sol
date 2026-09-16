// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativePlatformCustodyFixture.sol";

interface PlatformCustodyCalls {
    function expectCall(address, uint256, bytes calldata, uint64) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, uint256, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract StreamCurrentPlatformCustodyAuctionTest is NativePlatformCustodyFixture {
    bytes32 private constant ACQUIRED =
        0xddd87ca0826a4709e4c7bdb7cac073a99c3890bb0370bb3fc5f4174a40c8f0a0;
    bytes32 private constant RECORDED =
        0x5c1363e44341557049de1408c1e68be67103614d6f776a23f4da8ec147e24536;
    PlatformCustodyCalls private constant calls =
        PlatformCustodyCalls(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testCollectionAndDefaultAcquisitionSnapshotsOnceAndPaidReceiptUsesActualTokenPolicy()
        public
    {
        for (uint8 mode = 10; mode <= 11; ++mode) {
            (bytes32 profileId, address account) = _fixed(mode, address(uint160(0xDC00 + mode)));
            Plan memory p = _plan(mode, address(this), 150);
            vm.recordLogs();
            bytes32 id = _acquire(p);
            Vm.Log[] memory openingLogs = vm.getRecordedLogs();
            StreamNativeCustodySettlementTypes.Origin memory origin = house.custodyOrigin(id);
            IStreamRoyaltySnapshot.Snapshot memory snapshot =
                royalty.royaltySnapshot(origin.tokenId);
            require(
                origin.eligible && origin.tokenId == mode - 9 && origin.collectionSerial == mode - 9
                    && origin.operationNonce == mode - 10 && origin.manager == address(manager)
                    && origin.managerCodeHash == address(manager).codehash
                    && origin.operationRoot != 0 && origin.operationId != 0
                    && origin.authorizationId == _independentDigest(p.auth)
                    && origin.tokenDataHash == keccak256(p.artwork)
                    && origin.fundingAccount == address(this) && origin.revealFeeForwarded == 100
                    && core.ownerOf(origin.tokenId) == address(house) && snapshot.exists
                    && snapshot.operationRoot == origin.operationRoot
                    && snapshot.operationId == origin.operationId
                    && royalty.tokenRoyalty(origin.tokenId).frozen && _counter() == mode - 9
                    && manager.nextOperationNonce() == mode - 9,
                "exact unpaid prepared origin and snapshot before transfer"
            );
            require(
                account.balance == 0 && house.auction(id).artistId == 0
                    && house.refundableBalance(house.auction(id).saleId, address(this)) == 50
                    && entropy.revealFeeEscrow(origin.tokenId) == 100,
                "no Artist fiction, no primary payment and operator-only fee remainder"
            );
            uint256 opened;
            for (uint256 i; i < openingLogs.length; ++i) {
                if (
                    openingLogs[i].emitter == address(house) && openingLogs[i].topics.length == 4
                        && openingLogs[i].topics[0] == ACQUIRED && openingLogs[i].topics[1] == id
                        && uint256(openingLogs[i].topics[3]) == origin.tokenId
                        && keccak256(openingLogs[i].data)
                            == keccak256(abi.encode(uint16(1), p.auth, origin))
                ) ++opened;
            }
            require(opened == 1, "full original acquisition authorization and origin receipt");
            _custodyBid(id, payer);
            _end(id);
            IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
            a.status = 2;
            StreamNativeCustodySettlementTypes.Facts memory f =
                StreamNativeCustodySettlementTypes.Facts(id, a, origin);
            StreamSaleTemplate.Selection memory selected = _selected(mode);
            IStreamRevenueResolver.ResolvedPrimaryAssignment memory actual =
                resolver.resolvePrimaryAssignment(2, origin.tokenId, CLASS);
            bytes32 witness = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PLATFORM_PRIMARY_PROFILE_WITNESS_V1"),
                    block.chainid,
                    address(resolver),
                    uint256(2),
                    origin.tokenId,
                    mode,
                    p.auth.declarationHash,
                    address(this),
                    actual,
                    selected
                )
            );
            bytes32 factsHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PLATFORM_CUSTODY_FACTS_V1"),
                    block.chainid,
                    address(recorder),
                    address(house),
                    f,
                    p.auth.declarationHash,
                    p.original
                )
            );
            vm.recordLogs();
            (uint256 token, bytes32 key) = house.settle(id);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
                recorder.settlementResult(key);
            require(
                token == origin.tokenId && core.ownerOf(token) == payer && account.balance == 1000
                    && result.profileId == profileId && result.wallet == account && !result.escrowed
                    && result.operationIdentityCommitment == 0 && result.currentPolicyHash == 0
                    && result.boundPolicyHash == 0
                    && recorder.nativeCustodyFactsHash(key) == factsHash
                    && recorder.settlementConsumed(key) && manager.nextOperationNonce() == mode - 9
                    && _counter() == mode - 9
                    && keccak256(abi.encode(royalty.royaltySnapshot(token)))
                        == keccak256(abi.encode(snapshot)),
                "paid transfer never allocates, snapshots or counts a second mint"
            );
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory candidate;
            candidate.saleAdapter = address(house);
            candidate.executor = a.winner.executor;
            candidate.sale = StreamPrimarySettlementTypes.PrimarySale(
                a.saleId,
                CLASS,
                1,
                2,
                token,
                a.saleNonce,
                a.winner.payer,
                address(this),
                a.winner.deliverTo,
                1000,
                _policy(token, selected)
            );
            candidate.lifecycleBinding.saleCreatedAt = a.lifecycle.saleCreatedAt;
            candidate.lifecycleBinding.saleAdapterRegistryRevision =
            a.lifecycle.saleAdapterRegistryRevision;
            candidate.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_CUSTODY_EXECUTION_V1"),
                        block.chainid,
                        address(recorder),
                        address(house),
                        f,
                        p.auth.declarationHash,
                        p.original,
                        witness
                    )
                ),
                a.winner.bidIndex,
                a.winner.signed ? 1 : 2,
                a.winner.authorizationDigest
            );
            candidate.orchestrationOrder = 3;
            candidate.rights = StreamPrimarySettlementTypes.PrimaryRights(
                profileId, account, 0, selected.assignmentHash, selected.entriesHash
            );
            candidate.saleExecutionHash = factsHash;
            require(
                result.candidateCommitment
                        == keccak256(
                            abi.encode(
                                keccak256("6529STREAM_PLATFORM_CUSTODY_CANDIDATE_V1"),
                                block.chainid,
                                address(recorder),
                                address(house),
                                f,
                                p.auth.declarationHash,
                                p.original,
                                candidate,
                                witness
                            )
                        ) && result.executionId == candidate.executionBinding.executionId,
                "independent full candidate commits canonical actual-token policy and original acquisition"
            );
            bytes32 saleKey = recorder.preparedNativeSaleKey(address(house), a.saleId, a.saleNonce);
            uint256 count;
            for (uint256 i; i < logs.length; ++i) {
                if (
                    logs[i].emitter == address(recorder) && logs[i].topics.length == 4
                        && logs[i].topics[0] == RECORDED && logs[i].topics[1] == key
                        && logs[i].topics[2] == saleKey && logs[i].topics[3] == factsHash
                ) {
                    require(
                        keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    p.auth.declarationHash,
                                    p.original,
                                    f,
                                    witness,
                                    result
                                )
                            ),
                        "entire platform payment receipt"
                    );
                    ++count;
                }
            }
            require(
                count == 1 && recorder.preparedNativeSaleConsumed(saleKey)
                    && _policy(token, selected) != p.config.expectedPrimaryPolicyHash,
                "actual-token receipt and shared consumed sale"
            );
            (uint256 again, bytes32 same) = house.settle(id);
            require(
                again == token && same == key && account.balance == 1000,
                "terminal settlement is idempotent"
            );
        }
    }

    function testContestedOriginalAcquisitionRetriesAndFreshCoordinatesCannotReuseCreatorNonce()
        public
    {
        _fixed(10, address(0xDC20));
        Plan memory p = _plan(10, address(this), 150);
        bytes memory original = _call(p);
        platform.contest(1);
        (bool ok,) = address(house).call{ value: 150 }(original);
        require(
            !ok && core.lastAllocatedTokenId() == 0 && _counter() == 0
                && !royalty.royaltySnapshot(1).exists,
            "open contest denies the actual original mint before replay effects"
        );
        platform.contest(2);
        (ok,) = address(house).call{ value: 150 }(original);
        require(ok, "same signed original retries after dismissal");
        (ok,) = address(house).call{ value: 150 }(original);
        require(!ok, "serialized acquisition replay denied");
        Plan memory fresh = _plan(10, address(this), 150);
        fresh.auth.nonce = p.auth.nonce;
        fresh.signature = _proof(AUCTION_PLATFORM_KEY, _independentDigest(fresh.auth));
        require(
            fresh.auth.expectedTokenId == 2 && fresh.auth.expectedOperationNonce == 1
                && fresh.auth.expectedSaleNonce == 2,
            "fresh independent token and operation coordinates"
        );
        bytes memory reason;
        (ok, reason) = address(house).call{ value: 150 }(_call(fresh));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamNativeCustodyAuction.InvalidNativeCustody.selector
                        )
                    ),
            "used creator nonce is the remaining invalid coordinate"
        );
        fresh.auth.nonce = keccak256("fresh platform creator nonce");
        fresh.signature = _proof(AUCTION_PLATFORM_KEY, _independentDigest(fresh.auth));
        _acquire(fresh);
        require(
            core.lastAllocatedTokenId() == 2 && _counter() == 2
                && royalty.royaltySnapshot(2).exists,
            "positive nonce control"
        );
    }

    function testRecorderCapabilityAndWrongSigningDomainCannotSelectNewAcquisition() public {
        _fixed(10, address(0xDC21));
        Plan memory p = _plan(10, address(this), 150);
        bytes memory original = _call(p);
        calls.mockCall(
            address(recorder),
            abi.encodeCall(
                IERC165.supportsInterface,
                (type(IStreamPlatformCustodyPrimarySettlement).interfaceId)
            ),
            abi.encode(false)
        );
        (bool ok,) = address(house).call{ value: 150 }(original);
        require(
            !ok && core.lastAllocatedTokenId() == 0,
            "older deferred-only recorder cannot advertise custody payment"
        );
        calls.clearMockedCalls();
        p.signature = _proof(SIGNER_KEY, _independentDigest(p.auth));
        (ok,) = address(house).call{ value: 150 }(_call(p));
        require(!ok, "an Artist signature is not platform authority");
        p.signature = _proof(AUCTION_PLATFORM_KEY, keccak256("wrong original domain"));
        (ok,) = address(house).call{ value: 150 }(_call(p));
        require(!ok, "different signature domain fails");
        (ok,) = address(house).call{ value: 150 }(original);
        require(ok, "identical valid authorization remains usable");
        require(
            _counter() == 1
                && house.originalAuctionRights(
                    keccak256(
                        abi.encode(
                            keccak256("6529STREAM_AUCTION_V1"),
                            block.chainid,
                            address(house),
                            uint256(2),
                            uint256(1),
                            uint256(1),
                            false
                        )
                    )
                )
                .mode == 10,
            "explicit retained family, one actual acquisition"
        );
    }

    function testDefaultCustodyKeepsActualPrecedenceAndAllowsCurrentProfileChange() public {
        (bytes32 first, address firstWallet) = _fixed(11, address(0xDC22));
        bytes32 id = _acquire(_plan(11, address(this), 150));
        resolver.setPrimaryProfileAssignment(CLASS, 2, 1, first, 0);
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        (bool ok,) = address(house).call{ value: 1000 }(abi.encodeCall(house.bid, (id, payer)));
        require(
            !ok && house.auction(id).winner.amount == 0, "actual token override cannot be skipped"
        );
        resolver.clearPrimaryAssignment(CLASS, 2, 1);
        _fixed(10, address(0xDC23));
        vm.prank(payer);
        (ok,) = address(house).call{ value: 1000 }(abi.encodeCall(house.bid, (id, payer)));
        require(!ok, "collection override cannot be skipped for a default family");
        resolver.clearPrimaryAssignment(CLASS, 1, 2);
        _custodyBid(id, payer);
        _end(id);
        (bytes32 current, address currentWallet) = _fixed(11, address(0xDC24));
        (, bytes32 key) = house.settle(id);
        require(
            current != first && recorder.settlementResult(key).profileId == current
                && firstWallet.balance == 0 && currentWallet.balance == 1000 && _counter() == 1,
            "ALLOW_CURRENT profile drift retains original acquisition"
        );
    }

    function testSafeLateRevealFundingRollbackRestoresMintSnapshotAndOperatorRefundThenExactRetry()
        public
    {
        _fixed(10, address(0xDC25));
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xCC11;
        keys[1] = 0xCC12;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 190);
        vm.deal(address(safe), 1 ether);
        Plan memory p = _plan(10, address(safe), 150);
        bytes memory original = _safeCall(safe, keys, 150, _call(p));
        bytes memory funding = abi.encodeCall(entropy.fundRevealFeeEscrow, (uint256(1)));
        calls.mockCallRevert(
            address(entropy), 100, funding, bytes("late actual reveal funding fails")
        );
        calls.expectCall(address(entropy), 100, funding, 2);
        (bool ok,) = address(safe).call(original);
        require(
            !ok && safe.nonce() == 0 && address(safe).balance == 1 ether
                && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0
                && _counter() == 0 && !royalty.royaltySnapshot(1).exists
                && address(house).balance == 0 && entropy.revealFeeEscrow(1) == 0,
            "late acquisition failure restores full Safe, mint, snapshot and value state"
        );
        calls.clearMockedCalls();
        bytes memory out;
        (ok, out) = address(safe).call(original);
        require(
            ok && abi.decode(out, (bool)) && safe.nonce() == 1
                && address(safe).balance == 1 ether - 150 && core.ownerOf(1) == address(house)
                && _counter() == 1 && royalty.royaltySnapshot(1).exists,
            "exact same threshold Safe bytes acquire only once"
        );
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_AUCTION_V1"),
                block.chainid,
                address(house),
                uint256(2),
                uint256(1),
                uint256(1),
                false
            )
        );
        bytes32 sale = house.auction(id).saleId;
        require(
            house.refundableBalance(sale, address(safe)) == 50
                && house.refundableBalance(sale, address(this)) == 0,
            "native remainder belongs to the signed funding executor, not poster"
        );
        require(
            executeSafe(
                safe,
                keys,
                address(house),
                0,
                abi.encodeCall(house.claimRefund, (sale, payable(address(safe)))),
                0
            ) && address(safe).balance == 1 ether - 100,
            "original executor pull refund"
        );
    }

    function testSafeLatePaymentContestRollsBackAndIdenticalRetryNeverMintsAgain() public {
        (, address account) = _fixed(11, address(0xDC26));
        bytes32 id = _acquire(_plan(11, address(this), 150));
        IStreamRoyaltySnapshot.Snapshot memory snapshot = royalty.royaltySnapshot(1);
        bytes32 originHash = keccak256(abi.encode(house.custodyOrigin(id)));
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xCC21;
        keys[1] = 0xCC22;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 191);
        vm.deal(address(safe), 1 ether);
        require(
            executeSafe(
                safe, keys, address(house), 1000, abi.encodeCall(house.bid, (id, address(safe))), 0
            )
        );
        _end(id);
        uint256 nonce = safe.nonce();
        bytes memory original = _safeCall(safe, keys, 0, abi.encodeCall(house.settle, (id)));
        require(account.balance == 0 && _counter() == 1, "exact post-acquisition baseline");
        platform.failAfterFunding(account);
        calls.expectCall(account, 1000, bytes(""), 2);
        (bool ok,) = address(safe).call(original);
        require(
            !ok && safe.nonce() == nonce && account.balance == 0
                && core.ownerOf(1) == address(house) && manager.nextOperationNonce() == 1
                && _counter() == 1 && house.auction(id).status == 1
                && recorder.totalOfficialSettled(address(0)) == 0
                && keccak256(abi.encode(house.custodyOrigin(id))) == originHash,
            "actual late payment and all settlement effects roll back; original mint remains"
        );
        platform.failAfterFunding(address(0));
        bytes memory out;
        (ok, out) = address(safe).call(original);
        require(
            ok && abi.decode(out, (bool)) && safe.nonce() == nonce + 1
                && core.ownerOf(1) == address(safe) && account.balance == 1000
                && recorder.totalOfficialSettled(address(0)) == 1000
                && manager.nextOperationNonce() == 1 && _counter() == 1
                && core.lastAllocatedTokenId() == 1
                && keccak256(abi.encode(royalty.royaltySnapshot(1)))
                    == keccak256(abi.encode(snapshot)),
            "identical Safe bytes pay once with immutable original snapshot"
        );
    }

    function testContestAndCorrectiveArtistCannotBlockNoBidCancelClaimOrDeadlineEscape() public {
        _fixed(10, address(0xDC27));
        bytes32 empty = _acquire(_plan(10, address(this), 150));
        platform.contest(1);
        _end(empty);
        house.settle(empty);
        require(
            core.ownerOf(1) == address(this),
            "no-bid poster return is independent of current admission"
        );
        platform.contest(2);
        bytes32 cancelled = _acquire(_plan(10, address(this), 150));
        rejectDelivery = true;
        platform.contest(1);
        house.cancel(cancelled, keccak256("poster cancel"));
        require(
            house.auction(cancelled).nftClaimant == address(this)
                && core.ownerOf(2) == address(house),
            "failed poster delivery retains original own claim"
        );
        rejectDelivery = false;
        house.claimNFT(cancelled, address(this));
        require(
            core.ownerOf(2) == address(this),
            "own terminal claim does not need current platform consent"
        );
        platform.contest(2);
        bytes32 paid = _acquire(_plan(10, address(this), 150));
        _custodyBid(paid, payer);
        _end(paid);
        platform.contest(3);
        platform.correct(1, true);
        (bool ok,) = address(house).call(abi.encodeCall(house.settle, (paid)));
        require(
            !ok && recorder.totalOfficialSettled(address(0)) == 0,
            "corrected Artist cannot reuse platform authorization"
        );
        (, uint64 deadline,,) = house.auctionDeadlines(paid);
        vm.warp(uint256(deadline) + 1);
        house.unlockCustodySale(paid, 0);
        bytes32 sale = house.auction(paid).saleId;
        uint256 beforeBalance = payer.balance;
        vm.prank(payer);
        house.claimRefund(sale, payable(payer));
        require(
            payer.balance == beforeBalance + 1000 && core.ownerOf(3) == address(this)
                && _counter() == 3,
            "deadline refunds and returns the original token without another mint"
        );
    }
}
