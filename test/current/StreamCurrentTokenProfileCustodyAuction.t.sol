// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeTokenProfileCustodyFixture.sol";

interface TokenProfileFaultVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

contract StreamCurrentTokenProfileCustodyAuctionTest is NativeTokenProfileCustodyFixture {
    TokenProfileFaultVm private constant checks =
        TokenProfileFaultVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testTokenProfilePrecedencePreservesOriginalAcquisitionAndCompleteReceipt() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        bytes32 originalAuction = keccak256(abi.encode(house.auction(id)));
        StreamNativeCustodySettlementTypes.Origin memory origin = house.custodyOrigin(id);
        (bytes32 tokenProfile, address tokenWallet) = _tokenProfile(address(0x7001));
        bytes32 hash = _tokenAssignment(1, tokenProfile);
        StreamTokenProfileCustodyTypes.Activation memory activation =
            _activateToken(id, bytes32(uint256(1)));
        require(
            keccak256(abi.encode(house.auction(id))) == originalAuction
                && keccak256(abi.encode(house.custodyOrigin(id))) == keccak256(abi.encode(origin))
                && activation.authorization.assignmentHash == hash && tokenProfile != profile
                && tokenWallet != wallet,
            "append-only original custody identity"
        );
        _bidToken(id, payer, 1000);
        _custodyEnd(id);
        IStreamNativeEnglishAuction.Auction memory sale = house.auction(id);
        sale.status = 2;
        StreamNativeCustodySettlementTypes.Facts memory facts =
            StreamNativeCustodySettlementTypes.Facts(id, sale, origin);
        vm.recordLogs();
        (uint256 token, bytes32 key) = house.settleTokenProfileCustody(id);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            recorder.settlementResult(key);
        require(
            token == 1 && core.ownerOf(1) == payer && tokenWallet.balance == 1000
                && wallet.balance == 0 && result.profileId == tokenProfile
                && result.wallet == tokenWallet && result.amount == 1000 && !result.escrowed
                && result.operationIdentityCommitment == 0 && result.currentPolicyHash == 0
                && result.boundPolicyHash == 0 && manager.nextOperationNonce() == 1
                && core.collectionNextSerial(1) == 2 && core.lastAllocatedTokenId() == 1
                && _custodyCounter(p) == 1 && entropy.revealFeeEscrow(1) == 100
                && !house.custodyOrigin(id).eligible,
            "actual token-specific paid transfer has no second mint"
        );
        bytes32 factsHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_TOKEN_PROFILE_CUSTODY_FACTS_V1"),
                block.chainid,
                address(recorder),
                address(house),
                facts,
                activation
            )
        );
        bytes32 saleKey =
            recorder.preparedNativeSaleKey(address(house), sale.saleId, sale.saleNonce);
        require(
            recorder.nativeCustodyFactsHash(key) == factsHash
                && recorder.preparedNativeSaleConsumed(saleKey),
            "original sale replay and new full facts"
        );
        _receipt(logs, key, saleKey, factsHash, facts, activation, result);
        (uint256 same, bytes32 sameKey) = house.settleTokenProfileCustody(id);
        require(
            same == token && sameKey == key && tokenWallet.balance == 1000,
            "new terminal idempotence"
        );
        (bool legacy,) = address(house).call(abi.encodeCall(house.settle, (id)));
        require(
            !legacy && tokenWallet.balance == 1000, "old settlement cannot enter activated sale"
        );
    }

    function testActivationDomainModeOriginAndUsedNonceRemainExact() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        (bytes32 selected,) = _tokenProfile(address(0x7002));
        _tokenAssignment(1, selected);
        StreamTokenProfileCustodyTypes.Authorization memory a =
            _tokenAuthorization(id, bytes32(uint256(2)));
        for (uint256 i; i < 6; ++i) {
            StreamTokenProfileCustodyTypes.Authorization memory bad =
                abi.decode(abi.encode(a), (StreamTokenProfileCustodyTypes.Authorization));
            if (i == 0) bad.primaryPolicyMode = 0;
            if (i == 1) bad.originHash = keccak256("wrong origin");
            if (i == 2) bad.baseConfigHash = keccak256("wrong original config");
            if (i == 3) bad.tokenId = 2;
            bytes32 digest =
                _literalActivationDigest(i == 4 ? address(0xDEAD) : address(house), bad);
            bytes memory data = abi.encodeCall(
                house.activateTokenProfileCustody,
                (
                    bad,
                    _custodyProof(AUCTION_PLATFORM_KEY, digest),
                    _custodyProof(i == 5 ? PAYER_KEY : SIGNER_KEY, digest)
                )
            );
            (bool ok,) = address(house).call(data);
            require(
                !ok && !house.tokenProfileCustodyNonceUsed(a.artist, a.nonce)
                    && house.tokenProfileCustodyConfigurationHash(id) == 0,
                "invalid activation has no effects"
            );
        }
        bytes memory exact = _activationCall(a);
        (bool ok,) = address(house).call(exact);
        require(
            ok && house.tokenProfileCustodyNonceUsed(a.artist, a.nonce), "original exact activation"
        );
        (ok,) = address(house).call(exact);
        require(!ok, "same activation replay refused");
        Plan memory second = _custodyPlan(false, address(this), address(this));
        bytes32 id2 = _openCustody(second);
        _tokenAssignment(2, selected);
        StreamTokenProfileCustodyTypes.Authorization memory fresh =
            _tokenAuthorization(id2, a.nonce);
        (ok,) = address(house).call(_activationCall(fresh));
        require(
            !ok && house.tokenProfileCustodyConfigurationHash(id2) == 0,
            "fresh token with used artist nonce refused"
        );
        fresh.nonce = bytes32(uint256(3));
        (ok,) = address(house).call(_activationCall(fresh));
        require(ok, "same current coordinates and fresh signed nonce succeed");
    }

    function testOldSignedBidsCannotCrossActivationAndNewSignedBidSharesReplay() public {
        _bindCustody();
        bytes32 id = _openCustody(_custodyPlan(false, address(this), address(this)));
        IStreamNativeEnglishAuction.BidAuthorization memory bid =
            IStreamNativeEnglishAuction.BidAuthorization(
                id,
                house.auction(id).configHash,
                payer,
                address(this),
                payer,
                1000,
                0,
                keccak256("token signed bid"),
                this.custodyFixtureTime() + 500,
                0
            );
        (, bid.finalizeBy,,) = house.auctionDeadlines(id);
        bytes memory oldProof = _custodyProof(PAYER_KEY, house.bidAuthorizationDigest(bid));
        bytes memory original = abi.encodeCall(house.bidSigned, (bid, oldProof));
        (bool ok,) = address(house).call{ value: 1000 }(
            abi.encodeCall(house.bidSignedTokenProfileCustody, (bid, oldProof))
        );
        require(!ok && house.totalLiveBidDeposits() == 0, "new family requires activation");
        (bytes32 selected,) = _tokenProfile(address(0x7003));
        _tokenAssignment(1, selected);
        _activateToken(id, bytes32(uint256(4)));
        (ok,) = address(house).call{ value: 1000 }(original);
        require(!ok, "presigned old entry refused after activation");
        (ok,) = address(house).call{ value: 1000 }(
            abi.encodeCall(house.bidSignedTokenProfileCustody, (bid, oldProof))
        );
        require(!ok, "old config not admitted through new entry");
        bid.configHash = house.tokenProfileCustodyConfigurationHash(id);
        bytes memory proof = _custodyProof(PAYER_KEY, house.bidAuthorizationDigest(bid));
        bytes memory exact = abi.encodeCall(house.bidSignedTokenProfileCustody, (bid, proof));
        (ok,) = address(house).call{ value: 1000 }(exact);
        require(
            ok && house.auction(id).winner.payer == payer && house.auction(id).winner.signed
                && house.auction(id).winner.authorizationDigest
                    == house.bidAuthorizationDigest(bid),
            "same nonce remains usable after rejected old bids"
        );
        (ok,) = address(house).call{ value: 1000 }(exact);
        require(!ok && house.totalLiveBidDeposits() == 1000, "signed bid replay no extra deposit");
        _custodyEnd(id);
        house.settleTokenProfileCustody(id);
        require(core.ownerOf(1) == payer, "new signed family completes");
    }

    function testOnlyExactTokenConsentAndApprovedCurrentProfileMayFund() public {
        _bindCustody();
        bytes32 id = _openCustody(_custodyPlan(false, address(this), address(this)));
        StreamTokenProfileCustodyTypes.Authorization memory missing =
            _tokenAuthorization(id, bytes32(uint256(5)));
        (bool ok,) = address(house).call(_activationCall(missing));
        require(!ok, "collection fallback cannot activate token route");
        (bytes32 selected, address destination) = _tokenProfile(address(0x7004));
        StreamArtistOnboardingTypes.AssignmentFact memory fact =
            resolver.previewArtistPrimaryAssignmentForScope(1, 2, 1, selected, 0, false);
        _tokenArtist().approveToken(1, 2, fact.assignmentHash, true);
        (ok,) = address(resolver)
            .call(
                abi.encodeCall(
                    resolver.setPrimaryProfileAssignment,
                    (CLASS, uint8(2), uint256(1), selected, bytes32(0))
                )
            );
        require(!ok, "wrong token approval never installs actual token key");
        _tokenArtist().approveToken(2, 1, fact.assignmentHash, true);
        (ok,) = address(resolver)
            .call(
                abi.encodeCall(
                    resolver.setPrimaryProfileAssignment,
                    (CLASS, uint8(2), uint256(1), selected, bytes32(0))
                )
            );
        require(!ok, "wrong collection approval never installs actual token key");
        bytes32 hash = _tokenAssignment(1, selected);
        _activateToken(id, bytes32(uint256(5)));
        _tokenArtist().approveToken(1, 1, hash, false);
        (ok,) = address(house).call{ value: 1000 }(
            abi.encodeCall(house.bidTokenProfileCustody, (id, address(0)))
        );
        require(!ok && house.totalLiveBidDeposits() == 0, "current exact consent loss blocks bid");
        _tokenArtist().approveToken(1, 1, hash, true);
        _bidToken(id, payer, 1000);
        (bytes32 next, address nextWallet) = _tokenProfile(address(0x7005));
        _tokenAssignment(1, next);
        _custodyEnd(id);
        (, bytes32 key) = house.settleTokenProfileCustody(id);
        require(
            nextWallet.balance == 1000 && destination.balance == 0
                && recorder.settlementResult(key).profileId == next
                && house.tokenProfileCustodyActivation(id).authorization.assignmentHash == hash,
            "signed ALLOW_CURRENT admits approved pre-payment drift without rewriting original terms"
        );
    }

    function testSafeLateTokenConsentFailureRollsBackFundingAndIdenticalRetry() public {
        _bindCustody();
        Plan memory p = _custodyPlan(false, address(this), address(this));
        bytes32 id = _openCustody(p);
        (bytes32 selected, address destination) = _tokenProfile(address(0x7006));
        _tokenAssignment(1, selected);
        _activateToken(id, bytes32(uint256(6)));
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFF11;
        keys[1] = 0x5AFF12;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1211);
        vm.deal(address(safe), 1 ether);
        (bool ok, bytes memory raw) = address(safe)
            .call(
                _tokenSafeCall(
                    safe, keys, 1000, abi.encodeCall(house.bidTokenProfileCustody, (id, address(0)))
                )
            );
        require(ok && abi.decode(raw, (bool)), "threshold Safe original bid");
        _custodyEnd(id);
        bytes memory exact =
            _tokenSafeCall(safe, keys, 0, abi.encodeCall(house.settleTokenProfileCustody, (id)));
        bytes32 saleKey = recorder.preparedNativeSaleKey(
            address(house), house.auction(id).saleId, house.auction(id).saleNonce
        );
        require(destination.balance == 0, "zero funding trigger baseline");
        _tokenArtist().fundingFault(destination, true);
        checks.expectCall(destination, 1000, bytes(""), uint64(2));
        (ok,) = address(safe).call(exact);
        require(
            !ok && safe.nonce() == 1 && destination.balance == 0 && house.auction(id).status == 1
                && house.totalLiveBidDeposits() == 1000 && house.totalBuyerLiabilities() == 1050
                && core.ownerOf(1) == address(house) && manager.nextOperationNonce() == 1
                && _custodyCounter(p) == 1 && !recorder.preparedNativeSaleConsumed(saleKey)
                && recorder.totalOfficialSettled(address(0)) == 0,
            "actual post-wallet consent fault rolls back every payment effect"
        );
        _tokenArtist().fundingFault(destination, false);
        (ok, raw) = address(safe).call(exact);
        require(
            ok && abi.decode(raw, (bool)) && safe.nonce() == 2 && safe.getThreshold() == 2
                && destination.balance == 1000 && core.ownerOf(1) == address(safe)
                && recorder.preparedNativeSaleConsumed(saleKey) && manager.nextOperationNonce() == 1
                && _custodyCounter(p) == 1,
            "byte-identical threshold Safe retry preserves acquisition"
        );
    }

    function testMissingTokenClearedFallbackAndTokenTemplateCannotSubstituteProfile() public {
        (bytes32 selected,) = _tokenProfile(address(0x7008));
        (bool ok,) = address(resolver)
            .staticcall(
                abi.encodeCall(
                    resolver.previewArtistPrimaryAssignmentForScope,
                    (uint256(1), uint8(2), uint256(1), selected, bytes32(0), false)
                )
            );
        require(
            !ok && core.lastAllocatedTokenId() == 0,
            "actual Core identity required before token approval"
        );
        _bindCustody();
        bytes32 id = _openCustody(_custodyPlan(false, address(this), address(this)));
        _tokenAssignment(1, selected);
        _activateToken(id, bytes32(uint256(8)));
        _tokenArtist().approveToken(1, 1, bytes32(0), true);
        resolver.clearPrimaryAssignment(CLASS, 2, 1);
        require(
            resolver.resolvePrimaryAssignment(1, 1, CLASS).scope == 1,
            "real cleared token falls back"
        );
        (ok,) = address(house).call{ value: 1000 }(
            abi.encodeCall(house.bidTokenProfileCustody, (id, address(0)))
        );
        require(
            !ok && house.totalLiveBidDeposits() == 0, "activated route refuses inherited profile"
        );
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 1000000, keccak256("artist")
        );
        bytes32 template =
            resolver.createPrimaryTemplate(entries, keccak256("unsupported token template"));
        // Actual bound Resolver refuses token TEMPLATE SET. The following unbound fixture setup
        // additionally proves current admission cannot reuse a pre-existing unsupported key.
        (ok,) = address(resolver)
            .call(
                abi.encodeCall(
                    resolver.setPrimaryTemplateAssignment,
                    (CLASS, uint8(2), uint256(1), template, bytes32(0))
                )
            );
        require(!ok, "current Artist token TEMPLATE authority remains closed");
        address accepted = artists.artist();
        artists.accept(address(0));
        resolver.setPrimaryTemplateAssignment(CLASS, 2, 1, template, 0);
        artists.accept(accepted);
        (ok,) = address(house).call{ value: 1000 }(
            abi.encodeCall(house.bidTokenProfileCustody, (id, address(0)))
        );
        require(
            !ok && house.totalLiveBidDeposits() == 0,
            "pre-existing token template cannot substitute PROFILE"
        );
        _tokenAssignment(1, selected);
        _bidToken(id, payer, 1000);
        _custodyEnd(id);
        house.settleTokenProfileCustody(id);
        require(core.ownerOf(1) == payer, "exact approved token PROFILE repair completes");
    }

    function testActivatedNoBidCancellationAndDeadlineRefundSurviveConsentLoss() public {
        _bindCustody();
        for (uint256 n; n < 3; ++n) {
            bytes32 id = _openCustody(_custodyPlan(false, address(this), address(this)));
            (bytes32 selected,) = _tokenProfile(address(uint160(0x7100 + n)));
            _tokenAssignment(n + 1, selected);
            _activateToken(id, bytes32(20 + n));
            if (n == 2) _bidToken(id, payer, 1000);
            artists.setConsent(false);
            if (n == 0) {
                _custodyEnd(id);
                house.settle(id);
            }
            if (n == 1) house.cancel(id, keccak256("poster cancellation"));
            if (n == 2) {
                (, uint64 deadline,,) = house.auctionDeadlines(id);
                vm.warp(deadline + 1);
                house.unlockCustodySale(id, 0);
                bytes32 sale = house.auction(id).saleId;
                require(
                    house.refundableBalance(sale, payer) == 1000, "buyer retains original refund"
                );
                vm.prank(payer);
                house.claimRefund(sale, payable(payer));
            }
            require(
                core.ownerOf(n + 1) == address(this) && !house.custodyOrigin(id).eligible,
                "original poster escape despite token consent loss"
            );
            house.claimRefund(house.auction(id).saleId, payable(address(this)));
            artists.setConsent(true);
        }
        require(
            house.totalBuyerLiabilities() == 0 && recorder.totalOfficialSettled(address(0)) == 0,
            "terminal exits do not create revenue or strand funds"
        );
    }

    function testActivatedHostileRecipientClaimPreservesOfficialPaymentAndBlocksReentry() public {
        _bindCustody();
        bytes32 id = _openCustody(_custodyPlan(false, address(this), address(this)));
        (bytes32 selected, address destination) = _tokenProfile(address(0x7007));
        _tokenAssignment(1, selected);
        _activateToken(id, bytes32(uint256(7)));
        TokenProfileCustodyReceiver receiver = new TokenProfileCustodyReceiver(house, recorder, id);
        receiver.placeBid{ value: 1000 }();
        _custodyEnd(id);
        (, bytes32 key) = house.settleTokenProfileCustody(id);
        require(
            core.ownerOf(1) == address(house) && house.auction(id).nftClaimant == address(receiver)
                && destination.balance == 1000 && recorder.settlementConsumed(key),
            "failed delivery retains paid claimant"
        );
        artists.setConsent(false);
        receiver.claim();
        require(
            core.ownerOf(1) == address(receiver) && receiver.sawPayment()
                && receiver.reentryRejected() && !house.custodyOrigin(id).eligible
                && manager.nextOperationNonce() == 1,
            "own claim needs no renewed sale consent"
        );
    }

    function _receipt(
        Vm.Log[] memory logs,
        bytes32 key,
        bytes32 saleKey,
        bytes32 factsHash,
        StreamNativeCustodySettlementTypes.Facts memory facts,
        StreamTokenProfileCustodyTypes.Activation memory activation,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result
    ) private view {
        // The exact ABI-derived event selector is populated by the source-only ABI freeze.
        bytes32 topic = 0x13000ba63a7428760618ad3721e5a23b74d6f2e8dadaacb7e7ccdfcf9dfc9f63;
        uint256 count;
        for (uint256 n; n < logs.length; ++n) {
            if (
                logs[n].emitter == address(recorder) && logs[n].topics.length == 4
                    && logs[n].topics[0] == topic
            ) {
                require(
                    logs[n].topics[1] == key && logs[n].topics[2] == saleKey
                        && logs[n].topics[3] == factsHash
                        && keccak256(logs[n].data)
                            == keccak256(abi.encode(uint16(1), facts, activation, result)),
                    "exact schema1 activation receipt including all indexed facts"
                );
                ++count;
            }
        }
        require(count == 1, "exactly one token-profile custody receipt");
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c;
        c.saleAdapter = address(house);
        c.executor = facts.auction.winner.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            facts.auction.saleId,
            CLASS,
            1,
            1,
            facts.auction.tokenId,
            facts.auction.saleNonce,
            facts.auction.winner.payer,
            facts.auction.config.poster,
            facts.auction.winner.deliverTo,
            facts.auction.winner.amount,
            _tokenPolicy(
                facts.auction.tokenId,
                result.profileId,
                result.wallet,
                activation.authorization.assignmentHash
            )
        );
        c.lifecycleBinding.saleCreatedAt = facts.auction.lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision =
        facts.auction.lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_TOKEN_PROFILE_CUSTODY_EXECUTION_V1"),
                    block.chainid,
                    address(recorder),
                    address(house),
                    facts,
                    activation
                )
            ),
            facts.auction.winner.bidIndex,
            2,
            facts.auction.winner.authorizationDigest
        );
        c.orchestrationOrder = 3;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            result.profileId,
            result.wallet,
            0,
            activation.authorization.assignmentHash,
            factory.profileEntriesHash(result.profileId)
        );
        c.saleExecutionHash = factsHash;
        require(
            result.executionId == c.executionBinding.executionId
                && result.candidateCommitment
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_TOKEN_PROFILE_CUSTODY_CANDIDATE_V1"),
                            block.chainid,
                            address(recorder),
                            address(house),
                            facts,
                            activation,
                            c
                        )
                    ),
            "complete independently reconstructed actual-token policy and candidate"
        );
    }
}

contract TokenProfileCustodyReceiver is IERC721Receiver {
    StreamNativeEnglishAuction private immutable house;
    StreamPrimarySaleSettlement private immutable recorder;
    bytes32 private immutable id;
    bool private accepting;
    bool public sawPayment;
    bool public reentryRejected;

    constructor(StreamNativeEnglishAuction h, StreamPrimarySaleSettlement r, bytes32 value) {
        house = h;
        recorder = r;
        id = value;
    }

    function placeBid() external payable {
        house.bidTokenProfileCustody{ value: msg.value }(id, address(0));
    }

    function claim() external {
        accepting = true;
        house.claimNFT(id, address(this));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(accepting, "deliberate receiver rejection");
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        sawPayment = a.status == 3 && recorder.settlementConsumed(a.settlementKey)
            && recorder.settlementResult(a.settlementKey).amount == 1000;
        (bool ok,) = address(house).call(abi.encodeCall(house.settleTokenProfileCustody, (id)));
        reentryRejected = !ok;
        return IERC721Receiver.onERC721Received.selector;
    }
}
