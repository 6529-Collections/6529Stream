// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativePlatformRightsFixture.sol";

interface PlatformPrimaryCalls {
    function expectCall(address, uint256, bytes calldata, uint64) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

/// @notice Actual Core/Manager/Resolver/house/recorder/Safe with explicit typed Artist/entropy/governance.
contract StreamCurrentPlatformPrimaryAuctionTest is NativePlatformRightsFixture {
    PlatformPrimaryCalls private constant calls =
        PlatformPrimaryCalls(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant PLATFORM_RECEIPT = keccak256(
        "PlatformPreparedPrimaryBound(uint16,bytes32,bytes32,bytes32,uint8,bytes32,address,bytes32)"
    );

    function testCollectionAndDefaultStaticAndPosterTemplatesPayActualPreparedTokens() public {
        uint256 token;
        for (uint8 mode = 8; mode <= 9; ++mode) {
            for (uint8 poster = 0; poster < 2; ++poster) {
                _template(mode, poster == 1);
                StreamSaleTemplate.Selection memory selected = _selected(mode);
                uint256 beforeOwed =
                    escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0));
                bytes32 id = _open(mode);
                IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
                (, bytes32 declaration,) = platform.platformWorksDeclaration(2);
                require(
                    a.artistId == 0 && a.bindingGeneration == 0 && a.bindingHash == 0
                        && house.platformAuctionDeclaration(a.saleId) == declaration,
                    "no fabricated Artist association"
                );
                _bid(id, payer);
                _end(id);
                (uint64 end,,,) = house.auctionDeadlines(id);
                IStreamNativeEnglishAuction.Auction memory currentAuction = house.auction(id);
                (bool configOK, bytes memory configBytes) =
                    address(house).staticcall(abi.encodeCall(house.auctionConfig, (id)));
                require(
                    configOK
                        && keccak256(configBytes)
                            == keccak256(
                                abi.encode(
                                    a.config.minIncrementBps,
                                    a.config.incrementFloorWaived,
                                    a.config.clock.hardClose,
                                    a.config.clock.antiSnipeWindow,
                                    a.config.clock.antiSnipeExtension,
                                    a.config.clock.maxTotalExtension,
                                    uint32(
                                        currentAuction.clock.nominalEnd
                                            - currentAuction.clock.originalEnd
                                    ),
                                    end
                                )
                            ),
                    "original eight-word clock getter survives fixed worker"
                );
                vm.recordLogs();
                (uint256 actual, bytes32 key) = house.settle(id);
                ++token;
                require(
                    actual == token && core.ownerOf(token) == payer
                        && manager.nextOperationNonce() == token,
                    "actual prepared allocation, operation and delivery"
                );
                require(
                    escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                        == beforeOwed + 1000,
                    "forced template escrow exactly once"
                );
                Vm.Log[] memory logs = vm.getRecordedLogs();
                uint256 count;
                for (uint256 i; i < logs.length; ++i) {
                    if (
                        logs[i].emitter == address(recorder) && logs[i].topics.length == 4
                            && logs[i].topics[0] == PLATFORM_RECEIPT
                    ) {
                        ++count;
                        (
                            uint16 schema,
                            uint8 observedMode,
                            bytes32 witness,
                            address observedPoster,
                            bytes32 policyHash
                        ) = abi.decode(logs[i].data, (uint16, uint8, bytes32, address, bytes32));
                        (StreamSaleTemplate.Selection memory current, bytes32 expectedWitness) = StreamPlatformSaleTemplate.resolve(
                            resolver, 2, token, mode, address(this)
                        );
                        require(
                            schema == 1 && observedMode == mode && witness == expectedWitness
                                && witness != 0 && observedPoster == address(this)
                                && policyHash == _policy(token, current)
                                && policyHash != a.config.expectedPrimaryPolicyHash,
                            "canonical token policy and original poster"
                        );
                        require(
                            logs[i].topics[1] == key
                                && logs[i].topics[2]
                                    == recorder.preparedNativeSaleKey(
                                        address(house), a.saleId, a.saleNonce
                                    ) && logs[i].topics[3] == declaration
                                && keccak256(logs[i].data)
                                    == keccak256(
                                        abi.encode(
                                            uint16(1),
                                            mode,
                                            expectedWitness,
                                            address(this),
                                            _policy(token, current)
                                        )
                                    ),
                            "complete indexed and raw platform receipt"
                        );
                    }
                }
                require(
                    count == 1 && recorder.settlementResult(key).amount == 1000
                        && recorder.settlementResult(key).profileId == selected.profileId,
                    "canonical recorder result"
                );
                uint256 represented;
                for (uint256 j; j < factory.profileEntryCount(selected.profileId); ++j) {
                    (address account, uint32 share, bytes32 label) =
                        factory.profileEntry(selected.profileId, j);
                    if (label == keccak256("platform creator")) {
                        require(
                            account == (poster == 1 ? address(this) : address(0xA111))
                                && share == 900000,
                            "concrete SALE_POSTER pays original poster, never payer/executor"
                        );
                        ++represented;
                    }
                }
                require(represented == 1, "one original platform source");
                uint256 walletBefore = selected.wallet.balance;
                factory.deployWallet(selected.profileId);
                escrow.flushEscrow(CLASS, selected.profileId, selected.wallet, address(0));
                require(
                    escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 0,
                    "actual deterministic wallet flush"
                );
                require(
                    selected.wallet.balance == walletBefore + beforeOwed + 1000,
                    "wallet receives original platform split"
                );
            }
        }
    }

    function testOpeningCurrentContestRefusalRepairsWithIdenticalPlatformSignatureAndSharedReplay()
        public
    {
        _template(8, true);
        bytes memory original = _opening(8);
        platform.contest(1);
        (bool ok,) = address(house).call(original);
        require(!ok, "contested opening refuses");
        platform.contest(2);
        platform.fileDisplayClaim();
        bytes memory result;
        (ok, result) = address(house).call(original);
        require(ok, "dismissed current state and display claim admit");
        bytes32 id = abi.decode(result, (bytes32));
        require(house.auction(id).status == 1);
        (ok,) = address(house).call(original);
        require(!ok, "same platform creator nonce is consumed");
        _bid(id, payer);
        _end(id);
        house.settle(id);
        require(core.ownerOf(1) == payer, "same signed opening produces usable paid auction");
    }

    function testOldArtistRegistrationCannotSubstitutePlatformFamilyAndWrongPlatformSignatureFails()
        public
    {
        _template(8, false);
        IStreamNativeEnglishAuction.Configuration memory c = _config(8);
        StreamSaleTemplate.Selection memory s = _selected(8);
        StreamPreparedNativeRightsTypes.OriginalPolicy memory o =
            StreamPreparedNativeRightsTypes.OriginalPolicy(8, s.assignmentHash, s.templateId);
        IStreamNativeEnglishAuction.CreationAuthorization memory old =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.rightsConfigurationHash(c, o),
                vm.addr(SIGNER_KEY),
                keccak256("old creator"),
                this.timeNow() + 1 days
            );
        bytes32 oldDigest = house.creationAuthorizationDigest(old);
        (bool ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.registerRightsAuction,
                    (
                        c,
                        o,
                        bytes("platform primary artwork"),
                        old,
                        _proof(AUCTION_PLATFORM_KEY, oldDigest),
                        _proof(SIGNER_KEY, oldDigest)
                    )
                )
            );
        require(!ok, "old registration rejects explicit new family despite valid old signatures");
        (, bytes32 declaration,) = platform.platformWorksDeclaration(2);
        P.PlatformCreationAuthorization memory a = P.PlatformCreationAuthorization(
            house.platformRightsConfigurationHash(c, o, declaration),
            declaration,
            keccak256("new creator"),
            this.timeNow() + 1 days
        );
        bytes32 digest = house.platformRightsCreationDigest(a);
        (ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.registerPlatformRightsAuction,
                    (c, o, bytes("platform primary artwork"), a, _proof(SIGNER_KEY, digest))
                )
            );
        require(!ok, "Artist signer cannot replace configured platform signer");
        bytes32 id = house.registerPlatformRightsAuction(
            c, o, bytes("platform primary artwork"), a, _proof(AUCTION_PLATFORM_KEY, digest)
        );
        require(
            house.auction(id).status == 1,
            "identical authorization repaired only by proper signature"
        );
    }

    function testActualSourcePrecedenceAndApprovedCurrentDriftRemainWithinSignedFamily() public {
        _template(9, false);
        bytes32 id = _open(9);
        resolver.setPrimaryProfileAssignment(CLASS, 1, 2, profile, 0);
        uint256 value = 1000 + entropy.fee();
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        (bool ok,) =
            address(house).call{ value: value }(abi.encodeCall(house.bid, (id, address(0))));
        require(
            !ok && house.auction(id).winner.amount == 0, "default cannot skip configured collection"
        );
        resolver.clearPrimaryAssignment(CLASS, 1, 2);
        bytes32 originalTemplate = house.originalAuctionRights(id).templateId;
        _template(9, true);
        require(_selected(9).templateId != originalTemplate, "actual ALLOW_CURRENT source changed");
        _bid(id, payer);
        _end(id);
        (uint256 token,) = house.settle(id);
        require(
            core.ownerOf(token) == payer
                && house.originalAuctionRights(id).templateId == originalTemplate,
            "new current profile does not overwrite opening evidence"
        );
        resolver.setPrimaryProfileAssignment(CLASS, 2, token, profile, 0);
        (ok,) = address(this).staticcall(abi.encodeCall(this.project, (token, uint8(9))));
        require(!ok, "actual token override cannot be ignored");
    }

    function project(uint256 token, uint8 mode) external view returns (bytes32) {
        (StreamSaleTemplate.Selection memory s,) =
            StreamPlatformSaleTemplate.resolve(resolver, 2, token, mode, address(this));
        return s.assignmentHash;
    }

    function testPlatformGrammarDoesNotAdmitArtistSourcesOrArtistLabels() public {
        for (uint8 i; i < 2; ++i) {
            IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
                new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
            entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
                i == 0 ? address(0) : address(0xA11),
                i == 0 ? keccak256("COLLECTION_ARTIST") : bytes32(0),
                1000000,
                keccak256("artist")
            );
            bytes32 template = resolver.createPrimaryTemplate(
                entries, keccak256(abi.encode("bad platform source", i))
            );
            resolver.setPrimaryTemplateAssignment(CLASS, 1, 2, template, 0);
            (bool ok,) =
                address(this).staticcall(abi.encodeCall(this.project, (uint256(0), uint8(8))));
            require(!ok, "no zero-Artist fallback or reserved label impersonation");
        }
    }

    function testOpenSustainedAndCorrectiveStatesBlockCurrentBids() public {
        _template(8, true);
        bytes32 id = _open(8);
        uint256 value = 1000 + entropy.fee();
        vm.deal(payer, 1 ether);
        for (uint8 state = 1; state <= 3; state += 2) {
            platform.contest(state);
            vm.prank(payer);
            (bool ok,) =
                address(house).call{ value: value }(abi.encodeCall(house.bid, (id, address(0))));
            require(
                !ok && house.auction(id).winner.amount == 0,
                "current adverse contest blocks deposits"
            );
        }
        platform.contest(2);
        platform.correct(1, false);
        vm.prank(payer);
        (bool ok,) =
            address(house).call{ value: value }(abi.encodeCall(house.bid, (id, address(0))));
        require(!ok, "pending/refused corrective generation cannot regain platform authority");
        platform.correct(1, true);
        vm.prank(payer);
        (ok,) = address(house).call{ value: value }(abi.encodeCall(house.bid, (id, address(0))));
        require(!ok, "accepted Artist correction requires a separately Artist-authorized route");
        house.cancel(id, keccak256("poster cancellation remains"));
        require(house.auction(id).status == 4);
    }

    function testLostPlatformAuthorityBlocksPaymentButDeadlineRefundSurvives() public {
        _template(8, false);
        bytes32 id = _open(8);
        _bid(id, payer);
        _end(id);
        platform.contest(3);
        (bool ok,) = address(house).call(abi.encodeCall(house.settle, (id)));
        require(!ok && core.lastAllocatedTokenId() == 0);
        (, uint64 deadline,,) = house.auctionDeadlines(id);
        vm.warp(uint256(deadline) + 1);
        house.unlockNoMint(id, 0);
        bytes32 saleId = house.auction(id).saleId;
        uint256 beforeBalance = payer.balance;
        vm.prank(payer);
        house.claimRefund(saleId, payable(payer));
        require(
            payer.balance == beforeBalance + 1000 + entropy.fee(),
            "original payer owns amount and fee escape"
        );
    }

    function testNoBidTerminalRemainsAvailableAfterPlatformContest() public {
        _template(8, true);
        bytes32 id = _open(8);
        platform.contest(3);
        _end(id);
        (uint256 token, bytes32 key) = house.settle(id);
        require(
            token == 0 && key == 0 && house.auction(id).status == 5
                && core.lastAllocatedTokenId() == 0,
            "no-bid terminal never fabricates current platform consent"
        );
    }

    function testPostEscrowContestRollsBackActualSafePaymentAndIdenticalTransactionRetries()
        public
    {
        _template(9, true);
        bytes32 id = _open(9);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x18501;
        keys[1] = 0x18502;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 185);
        vm.deal(address(safe), 1 ether);
        uint256 value = 1000 + entropy.fee();
        require(
            executeSafe(
                safe, keys, address(house), value, abi.encodeCall(house.bid, (id, address(safe))), 0
            )
        );
        _end(id);
        StreamSaleTemplate.Selection memory selected = _selected(9);
        uint256 nonce = safe.nonce();
        bytes memory data = abi.encodeCall(house.settle, (id));
        bytes32 digest = safe.getTransactionHash(
            address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory original = abi.encodeCall(
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
                safeThresholdSignature(keys, digest)
            )
        );
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.PAYER,
            2,
            PLATFORM_PHASE,
            COUNTER,
            address(safe),
            address(safe),
            address(house),
            address(0),
            0
        );
        bytes32 counterKey = manager.previewCounterValueKey(2, PLATFORM_PHASE, COUNTER, subject);
        require(ledger.counterValue(counterKey) == 0, "actual zero counter baseline");
        require(address(escrow).balance == 0, "exact funding trigger baseline");
        platform.failAfterFunding(address(escrow));
        calls.expectCall(
            address(escrow),
            1000,
            abi.encodeCall(escrow.creditNative, (CLASS, selected.profileId, selected.wallet, true)),
            2
        );
        (bool ok,) = address(safe).call(original);
        require(
            !ok && safe.nonce() == nonce && core.lastAllocatedTokenId() == 0
                && manager.nextOperationNonce() == 0 && address(escrow).balance == 0
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 0
                && recorder.totalOfficialSettled(address(0)) == 0 && house.auction(id).status == 1
                && ledger.counterValue(counterKey) == 0,
            "actual post-credit current-contest failure rolls back all mint/payment/replay state"
        );
        platform.failAfterFunding(address(0));
        bytes memory out;
        (ok, out) = address(safe).call(original);
        require(
            ok && abi.decode(out, (bool)) && safe.nonce() == nonce + 1
                && core.ownerOf(1) == address(safe)
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 1000
                && recorder.totalOfficialSettled(address(0)) == 1000
                && ledger.counterValue(counterKey) == 1,
            "same signed Safe payment commits once"
        );
    }
}
