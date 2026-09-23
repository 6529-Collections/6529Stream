// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativePlatformCustodyFixture.sol";

interface PlatformTokenCustodyVm {
    function expectCall(address, uint256, bytes calldata, uint64) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract StreamCurrentPlatformTokenCustodyTest is NativePlatformCustodyFixture {
    PlatformTokenCustodyVm private constant calls =
        PlatformTokenCustodyVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private activationNonce;

    function _open() private returns (bytes32 id) {
        _fixed(10, address(0xAC01));
        return _acquire(_plan(10, address(this), 150));
    }

    function _tokenProfile(uint256 token, address recipient)
        private
        returns (bytes32 profileId, address wallet)
    {
        IStreamSplitWallet.SplitEntry[] memory e = new IStreamSplitWallet.SplitEntry[](1);
        e[0] = IStreamSplitWallet.SplitEntry(recipient, 1000000, keccak256("token platform"));
        (profileId, wallet) =
            factory.createProfile(e, keccak256(abi.encode("token profile", token, recipient)));
        resolver.setPrimaryProfileAssignment(CLASS, 2, token, profileId, 0);
    }

    function _tokenTemplate(uint256 token, bool poster) private returns (bytes32 template) {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory e =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
        e[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            poster ? address(0) : address(0xAC02),
            poster ? keccak256("SALE_POSTER") : bytes32(0),
            1000000,
            keccak256("token platform")
        );
        template = resolver.createPrimaryTemplate(
            e, keccak256(abi.encode("token template", token, poster))
        );
        resolver.setPrimaryTemplateAssignment(CLASS, 2, token, template, 0);
    }

    function _terms(bytes32 id, uint8 mode)
        private
        view
        returns (StreamSaleTemplate.Selection memory selected, bytes32 witness)
    {
        return StreamPlatformTokenPrimary.resolve(
            resolver, 2, house.auction(id).tokenId, mode, address(this)
        );
    }

    function _authorization(bytes32 id, uint8 mode)
        private
        returns (StreamPlatformTokenCustodyTypes.Authorization memory q)
    {
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        (StreamSaleTemplate.Selection memory selected,) = _terms(id, mode);
        q = StreamPlatformTokenCustodyTypes.Authorization(
            id,
            a.configHash,
            keccak256(abi.encode(house.custodyOrigin(id))),
            a.tokenId,
            house.platformAuctionDeclaration(a.saleId),
            mode,
            selected.assignmentHash,
            _policy(a.tokenId, selected),
            1,
            bytes32(++activationNonce),
            this.timeNow() + 1 days
        );
    }

    function _digest(StreamPlatformTokenCustodyTypes.Authorization memory q)
        private
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamPlatformTokenCustodyRights"),
                keccak256("1"),
                block.chainid,
                address(house)
            )
        );
        bytes32 d = keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "PlatformTokenCustodyRights(bytes32 auctionId,bytes32 baseConfigHash,bytes32 originHash,uint256 tokenId,bytes32 declarationHash,uint8 rightsMode,bytes32 assignmentHash,bytes32 primaryPolicyHash,uint8 primaryPolicyMode,bytes32 nonce,uint64 deadline)"
                        ),
                        q
                    )
                )
            )
        );
        require(
            d == house.platformTokenCustodyDigest(q),
            "independent complete activation domain and ordered fields"
        );
        return d;
    }

    function _activationCall(StreamPlatformTokenCustodyTypes.Authorization memory q)
        private
        returns (bytes memory)
    {
        return abi.encodeCall(
            house.activatePlatformTokenCustody, (q, _proof(AUCTION_PLATFORM_KEY, _digest(q)))
        );
    }

    function _activate(StreamPlatformTokenCustodyTypes.Authorization memory q) private {
        bytes memory original = _activationCall(q);
        vm.recordLogs();
        (bool ok,) = address(house).call(original);
        require(ok, "exact platform token activation");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        StreamPlatformTokenCustodyTypes.Activation memory a =
            house.platformTokenCustodyActivation(q.auctionId);
        require(
            a.authorizationDigest == _digest(q)
                && keccak256(abi.encode(a.authorization)) == keccak256(abi.encode(q))
                && a.effectiveConfigHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PLATFORM_TOKEN_CUSTODY_ALLOW_CURRENT_CONFIG_V1"),
                            block.chainid,
                            address(house),
                            q,
                            a.authorizationDigest
                        )
                    )
                && house.platformTokenCustodyConfigurationHash(q.auctionId) == a.effectiveConfigHash
                && house.platformTokenCustodyNonceUsed(q.nonce),
            "original signed tuple and append-only effective commitment"
        );
        bytes32 topic = keccak256(
            "PlatformTokenCustodyActivated(uint16,bytes32,uint256,bytes32,((bytes32,bytes32,bytes32,uint256,bytes32,uint8,bytes32,bytes32,uint8,bytes32,uint64),bytes32,bytes32))"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(house) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(
                    logs[i].topics[1] == q.auctionId && logs[i].topics[2] == bytes32(q.tokenId)
                        && logs[i].topics[3] == a.authorizationDigest
                        && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), a)),
                    "complete schema1 activation event"
                );
                ++count;
            }
        }
        require(count == 1, "one activation fact");
    }

    function _newBid(bytes32 id, address who) private {
        vm.deal(who, 1 ether);
        vm.prank(who);
        house.bidPlatformTokenCustody{ value: 1000 }(id, who);
    }

    function testExactTokenProfileAndPosterTemplatePayWithFullReceiptAndOriginalSnapshot() public {
        for (uint8 mode = 12; mode <= 13; ++mode) {
            bytes32 id = _open();
            uint256 token = house.auction(id).tokenId;
            bytes32 acquisition = keccak256(abi.encode(house.custodyOrigin(id)));
            bytes32 snapshot = keccak256(abi.encode(royalty.royaltySnapshot(token)));
            bytes32 base = house.auction(id).configHash;
            if (mode == 12) _tokenProfile(token, address(0xAC11));
            else _tokenTemplate(token, true);
            (StreamSaleTemplate.Selection memory selected, bytes32 witness) = _terms(id, mode);
            StreamPlatformTokenCustodyTypes.Authorization memory q = _authorization(id, mode);
            _activate(q);
            _newBid(id, payer);
            _end(id);
            IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
            a.status = 2;
            StreamNativeCustodySettlementTypes.Facts memory f =
                StreamNativeCustodySettlementTypes.Facts(id, a, house.custodyOrigin(id));
            vm.recordLogs();
            (, bytes32 key) = house.settlePlatformTokenCustody(id);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
                recorder.settlementResult(key);
            require(
                core.ownerOf(token) == payer && result.profileId == selected.profileId
                    && result.amount == 1000 && result.escrowed == (mode == 13)
                    && keccak256(abi.encode(house.custodyOrigin(id))) == acquisition
                    && keccak256(abi.encode(royalty.royaltySnapshot(token))) == snapshot
                    && house.auction(id).configHash == base && manager.nextOperationNonce() == token
                    && _counter() == token,
                "paid transfer retains the original configuration, mint and snapshot"
            );
            _receipt(logs, key, f, selected, witness, result);
            if (mode == 12) {
                require(selected.wallet.balance == 1000, "exact direct profile wallet amount");
            } else {
                require(
                    factory.profileExists(selected.profileId)
                        && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                            == 1000,
                    "actual token template materialization and canonical escrow"
                );
                (address recipient, uint32 share,) = factory.profileEntry(selected.profileId, 0);
                require(recipient == address(this) && share == 1000000, "signed original poster");
                factory.deployWallet(selected.profileId);
                escrow.flushEscrow(CLASS, selected.profileId, selected.wallet, address(0));
                require(selected.wallet.balance == 1000, "actual retained wallet flush");
            }
            (, bytes32 repeat) = house.settlePlatformTokenCustody(id);
            require(
                repeat == key && recorder.totalOfficialSettled(address(0)) == token * 1000,
                "idempotent result, shared official totals"
            );
        }
    }

    function _receipt(
        Vm.Log[] memory logs,
        bytes32 key,
        StreamNativeCustodySettlementTypes.Facts memory f,
        StreamSaleTemplate.Selection memory selected,
        bytes32 witness,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result
    ) private view {
        StreamPlatformTokenCustodyTypes.Activation memory
            activation = house.platformTokenCustodyActivation(f.auctionId);
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original =
            house.originalAuctionRights(f.auctionId);
        IStreamNativeEnglishAuction.Auction memory a = f.auction;
        bytes32 facts = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_TOKEN_CUSTODY_FACTS_V1"),
                block.chainid,
                address(recorder),
                address(house),
                f,
                activation,
                original
            )
        );
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c;
        c.saleAdapter = address(house);
        c.executor = a.winner.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            a.saleId,
            CLASS,
            1,
            2,
            a.tokenId,
            a.saleNonce,
            a.winner.payer,
            address(this),
            a.winner.deliverTo,
            1000,
            _policy(a.tokenId, selected)
        );
        c.lifecycleBinding.saleCreatedAt = a.lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision = a.lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PLATFORM_TOKEN_CUSTODY_EXECUTION_V1"),
                    block.chainid,
                    address(recorder),
                    address(house),
                    f,
                    activation,
                    original,
                    witness
                )
            ),
            a.winner.bidIndex,
            a.winner.signed ? 1 : 2,
            a.winner.authorizationDigest
        );
        c.orchestrationOrder = 3;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            selected.profileId,
            selected.wallet,
            selected.templateId,
            selected.assignmentHash,
            selected.entriesHash
        );
        c.saleExecutionHash = facts;
        require(
            result.candidateCommitment
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PLATFORM_TOKEN_CUSTODY_CANDIDATE_V1"),
                            block.chainid,
                            address(recorder),
                            address(house),
                            f,
                            activation,
                            original,
                            c,
                            witness
                        )
                    ) && result.executionId == c.executionBinding.executionId
                && recorder.nativeCustodyFactsHash(key) == facts,
            "full original plus activation candidate and canonical actual-token policy"
        );
        bytes32 saleKey = recorder.preparedNativeSaleKey(address(house), a.saleId, a.saleNonce);
        uint256 count;
        // Exact event signature populated from the checked ABI below.
        bytes32 topic = keccak256(
            "PlatformTokenCustodyRevenueRecorded(uint16,bytes32,bytes32,bytes32,((bytes32,bytes32,bytes32,uint256,bytes32,uint8,bytes32,bytes32,uint8,bytes32,uint64),bytes32,bytes32),(uint8,bytes32,bytes32),(bytes32,((uint256,bytes32,uint256,bool,bytes32,bytes32,bytes32,address,uint96,uint16,bool,(uint64,uint64,uint32,uint32,uint32,uint32,bool,bool),bytes32,uint8,uint32,bytes32),bytes32,bytes32,uint256,uint256,uint8,(uint64,uint64,bool),uint64,uint64,uint64,bytes32,bytes32,bytes32,(uint64,uint64),(address,address,address,uint256,uint256,uint256,bytes32,uint64,bool),uint256,bytes32,address),(address,bytes32,bytes32,bytes32,bytes32,bytes32,uint256,uint256,uint256,address,uint256,bool)),bytes32,(bytes32,bytes32,bytes32,address,address,uint256,address,bytes32,bool,bytes32,bytes32,bytes32))"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(recorder) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(
                    logs[i].topics[1] == key && logs[i].topics[2] == saleKey
                        && logs[i].topics[3] == facts
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(uint16(1), activation, original, f, witness, result)
                            ),
                    "full schema1 token-rights payment fact"
                );
                ++count;
            }
        }
        require(
            count == 1 && recorder.preparedNativeSaleConsumed(saleKey)
                && recorder.settlementConsumed(key),
            "one original consumed sale"
        );
    }

    function _signedBid(bytes32 id, bytes32 configuration)
        private
        returns (IStreamNativeEnglishAuction.BidAuthorization memory q, bytes memory sig)
    {
        uint256 key = 0xABCD1;
        address buyer = vm.addr(key);
        vm.deal(address(this), 100 ether);
        (, uint64 finalizeBy,,) = house.auctionDeadlines(id);
        q = IStreamNativeEnglishAuction.BidAuthorization(
            id,
            configuration,
            buyer,
            address(this),
            buyer,
            1000,
            0,
            keccak256("same payer nonce"),
            this.timeNow() + 1 days,
            finalizeBy
        );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeEnglishAuction"),
                keccak256("1"),
                block.chainid,
                address(house)
            )
        );
        sig = _proof(
            key,
            keccak256(
                abi.encodePacked(
                    hex"1901",
                    domain,
                    keccak256(
                        abi.encode(
                            keccak256(
                                "NativeAuctionBid(bytes32 auctionId,bytes32 configHash,address payer,address executor,address deliverTo,uint256 amount,uint256 maxRevealFee,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                            ),
                            q
                        )
                    )
                )
            )
        );
    }

    function testNewEntriesRequireActivationAndOldSignedBidCannotCrossTheEffectiveConfiguration()
        public
    {
        bytes32 id = _open();
        (bool ok,) = address(house).call{ value: 1000 }(
            abi.encodeCall(house.bidPlatformTokenCustody, (id, address(this)))
        );
        require(!ok, "new route needs activation");
        (IStreamNativeEnglishAuction.BidAuthorization memory old, bytes memory sig) =
            _signedBid(id, house.auction(id).configHash);
        _tokenProfile(1, address(0xAC21));
        _activate(_authorization(id, 12));
        (ok,) = address(house).call{ value: 1000 }(abi.encodeCall(house.bidSigned, (old, sig)));
        require(!ok, "pre-signed original bid is refused on activated sale");
        (ok,) = address(house).call{ value: 1000 }(
            abi.encodeCall(house.bidSignedPlatformTokenCustody, (old, sig))
        );
        require(!ok, "old base configuration is not the effective activation");
        (old, sig) = _signedBid(id, house.platformTokenCustodyConfigurationHash(id));
        house.bidSignedPlatformTokenCustody{ value: 1000 }(old, sig);
        require(
            house.auction(id).winner.payer == old.payer && house.auction(id).winner.signed,
            "same original signing type with effective configuration"
        );
        _end(id);
        (ok,) = address(house).call(abi.encodeCall(house.settle, (id)));
        require(!ok, "old paid settle cannot emit legacy receipt");
        house.settlePlatformTokenCustody(id);
        require(core.ownerOf(1) == old.payer && _counter() == 1, "new payment route succeeds once");
    }

    function testActivationGuardsCurrentDeclarationCapabilityPosterAndAppendOnlyNonceWithExactRetry()
        public
    {
        bytes32 id = _open();
        _tokenProfile(1, address(0xAC31));
        StreamPlatformTokenCustodyTypes.Authorization memory q = _authorization(id, 12);
        bytes memory original = _activationCall(q);
        vm.prank(payer);
        (bool ok,) = address(house).call(original);
        require(!ok, "only original poster may append");
        bytes memory bad =
            abi.encodeCall(house.activatePlatformTokenCustody, (q, _proof(SIGNER_KEY, _digest(q))));
        (ok,) = address(house).call(bad);
        require(!ok, "Artist is not platform signer");
        calls.mockCall(
            address(recorder),
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamPlatformTokenCustodySettlement).interfaceId)
            ),
            abi.encode(false)
        );
        (ok,) = address(house).call(original);
        require(!ok, "old recorder cannot promise new receipt");
        calls.clearMockedCalls();
        platform.contest(1);
        (ok,) = address(house).call(original);
        require(
            !ok && !house.platformTokenCustodyNonceUsed(q.nonce), "contest failure preserves nonce"
        );
        platform.contest(2);
        (ok,) = address(house).call(original);
        require(ok, "byte-identical activation after dismissed contest");
        (ok,) = address(house).call(original);
        require(!ok, "append-only activation");
        bytes32 second = _open();
        _tokenProfile(2, address(0xAC32));
        StreamPlatformTokenCustodyTypes.Authorization memory fresh = _authorization(second, 12);
        fresh.nonce = q.nonce;
        (ok,) = address(house).call(_activationCall(fresh));
        require(
            !ok && house.platformTokenCustodyActivation(second).authorizationDigest == 0,
            "fresh coordinates cannot reuse platform activation nonce"
        );
        fresh.nonce = bytes32(++activationNonce);
        _activate(fresh);
        require(
            house.platformTokenCustodyActivation(second).authorizationDigest != 0,
            "otherwise identical fresh nonce succeeds"
        );
    }

    function testActualTokenFallbackFamilyDriftAndCorrectiveGenerationCannotReusePlatformRights()
        public
    {
        bytes32 id = _open();
        (bytes32 first,) = _tokenProfile(1, address(0xAC41));
        _activate(_authorization(id, 12));
        resolver.clearPrimaryAssignment(CLASS, 2, 1);
        (bool ok,) = address(house).call{ value: 1000 }(
            abi.encodeCall(house.bidPlatformTokenCustody, (id, address(this)))
        );
        require(!ok, "collection fallback cannot satisfy scope2");
        resolver.setPrimaryProfileAssignment(CLASS, 2, 1, first, 0);
        _newBid(id, payer);
        _end(id);
        _tokenTemplate(1, true);
        (ok,) = address(house).call(abi.encodeCall(house.settlePlatformTokenCustody, (id)));
        require(!ok, "TEMPLATE cannot replace signed PROFILE family");
        (bytes32 current, address wallet) = _tokenProfile(1, address(0xAC42));
        house.settlePlatformTokenCustody(id);
        require(
            current != first && wallet.balance == 1000 && core.ownerOf(1) == payer,
            "ALLOW_CURRENT pays the actual new token PROFILE"
        );
        bytes32 second = _open();
        _tokenTemplate(2, true);
        _activate(_authorization(second, 13));
        _newBid(second, payer);
        _end(second);
        bytes32 openingTemplate =
            house.platformTokenCustodyActivation(second).authorization.assignmentHash;
        _tokenTemplate(2, false);
        (StreamSaleTemplate.Selection memory staticCurrent,) = _terms(second, 13);
        house.settlePlatformTokenCustody(second);
        require(
            staticCurrent.assignmentHash != openingTemplate && core.ownerOf(2) == payer
                && escrow.escrowOwed(
                        CLASS, staticCurrent.profileId, staticCurrent.wallet, address(0)
                    ) == 1000,
            "ALLOW_CURRENT token TEMPLATE drift materializes exact static terms"
        );
        second = _open();
        _tokenTemplate(3, true);
        _activate(_authorization(second, 13));
        _newBid(second, payer);
        _end(second);
        platform.correct(1, false);
        (ok,) = address(house).call(abi.encodeCall(house.settlePlatformTokenCustody, (second)));
        require(
            !ok && core.ownerOf(3) == address(house),
            "pending/refused corrective generation is not platform admission"
        );
        platform.correct(1, true);
        (ok,) = address(house).call(abi.encodeCall(house.settlePlatformTokenCustody, (second)));
        require(!ok, "accepted Artist needs a separate Artist route");
        (, uint64 deadline,,) = house.auctionDeadlines(second);
        vm.warp(uint256(deadline) + 1);
        house.unlockCustodySale(second, 0);
        bytes32 sale = house.auction(second).saleId;
        uint256 before_ = payer.balance;
        vm.prank(payer);
        house.claimRefund(sale, payable(payer));
        require(
            payer.balance == before_ + 1000 && core.ownerOf(3) == address(this) && _counter() == 3,
            "deadline escape remains provider-independent"
        );
    }

    function testExactSafeLateProfileAndTemplateFundingFailureRetriesWithoutNewMint() public {
        for (uint8 mode = 12; mode <= 13; ++mode) {
            bytes32 id = _open();
            uint256 token = house.auction(id).tokenId;
            if (mode == 12) _tokenProfile(token, address(0xAC51));
            else _tokenTemplate(token, true);
            _activate(_authorization(id, mode));
            (StreamSaleTemplate.Selection memory selected,) = _terms(id, mode);
            bytes32 snapshot = keccak256(abi.encode(royalty.royaltySnapshot(token)));
            uint256 count = factory.profileCount();
            uint256[] memory keys = new uint256[](2);
            keys[0] = 0xCA51;
            keys[1] = 0xCA52;
            OfficialSafe safe = createOfficialSafe(
                deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 250 + mode
            );
            vm.deal(address(safe), 1 ether);
            require(
                executeSafe(
                    safe,
                    keys,
                    address(house),
                    1000,
                    abi.encodeCall(house.bidPlatformTokenCustody, (id, address(safe))),
                    0
                )
            );
            _end(id);
            uint256 nonce = safe.nonce();
            bytes memory original =
                _safeCall(safe, keys, 0, abi.encodeCall(house.settlePlatformTokenCustody, (id)));
            if (mode == 12) {
                require(selected.wallet.balance == 0);
                platform.failAfterFunding(selected.wallet);
                calls.expectCall(selected.wallet, 1000, bytes(""), 2);
            } else {
                require(address(escrow).balance == 0 && !factory.profileExists(selected.profileId));
                platform.failAfterFunding(address(escrow));
                calls.expectCall(
                    address(escrow),
                    1000,
                    abi.encodeCall(
                        escrow.creditNative, (CLASS, selected.profileId, selected.wallet, true)
                    ),
                    2
                );
            }
            (bool ok,) = address(safe).call(original);
            require(
                !ok && safe.nonce() == nonce && core.ownerOf(token) == address(house)
                    && house.auction(id).status == 1 && factory.profileCount() == count
                    && recorder.totalOfficialSettled(address(0)) == (token - 1) * 1000
                    && _counter() == token
                    && keccak256(abi.encode(royalty.royaltySnapshot(token))) == snapshot,
                "late actual funding rollback keeps original token/snapshot and activation"
            );
            require(
                mode == 12
                    ? selected.wallet.balance == 0
                    : escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 0,
                "payment rolled back before retry"
            );
            platform.failAfterFunding(address(0));
            bytes memory out;
            (ok, out) = address(safe).call(original);
            require(
                ok && abi.decode(out, (bool)) && safe.nonce() == nonce + 1
                    && core.ownerOf(token) == address(safe)
                    && recorder.totalOfficialSettled(address(0)) == token * 1000
                    && _counter() == token && manager.nextOperationNonce() == token
                    && keccak256(abi.encode(royalty.royaltySnapshot(token))) == snapshot,
                "same complete Safe bytes pay once without minting"
            );
        }
    }

    function testActivatedNoBidCancellationAndOwnClaimsSurviveContest() public {
        bytes32 id = _open();
        _tokenProfile(1, address(0xAC61));
        _activate(_authorization(id, 12));
        platform.contest(1);
        _end(id);
        house.settle(id);
        require(core.ownerOf(1) == address(this), "original no-bid return");
        platform.contest(2);
        bytes32 second = _open();
        _tokenTemplate(2, true);
        _activate(_authorization(second, 13));
        platform.contest(1);
        rejectDelivery = true;
        house.cancel(second, keccak256("cancel"));
        require(
            core.ownerOf(2) == address(house) && house.auction(second).nftClaimant == address(this),
            "terminal own claimant"
        );
        rejectDelivery = false;
        house.claimNFT(second, address(this));
        require(
            core.ownerOf(2) == address(this) && _counter() == 2,
            "own claim never needs platform admission"
        );
    }

    function testEveryActivationCoordinateIsSignedAndActivationAfterFirstBidIsRefused() public {
        bytes32 id = _open();
        _tokenProfile(1, address(0xAC71));
        StreamPlatformTokenCustodyTypes.Authorization memory q = _authorization(id, 12);
        for (uint8 i; i < 10; ++i) {
            StreamPlatformTokenCustodyTypes.Authorization memory bad =
                abi.decode(abi.encode(q), (StreamPlatformTokenCustodyTypes.Authorization));
            if (i == 0) bad.baseConfigHash = keccak256("wrong base");
            else if (i == 1) bad.originHash = keccak256("wrong original");
            else if (i == 2) bad.tokenId = 2;
            else if (i == 3) bad.declarationHash = keccak256("wrong declaration");
            else if (i == 4) bad.rightsMode = 8;
            else if (i == 5) bad.assignmentHash = keccak256("wrong assignment");
            else if (i == 6) bad.primaryPolicyHash = keccak256("wrong policy");
            else if (i == 7) bad.primaryPolicyMode = 0;
            else if (i == 8) bad.nonce = 0;
            else bad.deadline = 0;
            bytes memory call_ = _activationCall(bad);
            (bool ok,) = address(house).call(call_);
            require(
                !ok && !house.platformTokenCustodyNonceUsed(q.nonce)
                    && house.platformTokenCustodyActivation(id).authorizationDigest == 0,
                "independently re-signed wrong coordinate cannot append"
            );
        }
        _activate(q);
        bytes32 second = _open();
        _custodyBid(second, payer);
        _tokenProfile(2, address(0xAC72));
        StreamPlatformTokenCustodyTypes.Authorization memory later = _authorization(second, 12);
        (bool ok,) = address(house).call(_activationCall(later));
        require(
            !ok && !house.platformTokenCustodyNonceUsed(later.nonce)
                && house.auction(second).winner.amount == 1000,
            "valid current terms cannot activate after the original bid"
        );
    }
}
