// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeDynamicRightsAuctionFixture.sol";
import {
    StreamDynamicPrimaryBeneficiaries as DB
} from "../../smart-contracts/domains/revenue/StreamDynamicPrimaryBeneficiaries.sol";

interface DynamicRightsVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
    function mockCall(address target, bytes calldata data, bytes calldata returned) external;
    function clearMockedCalls() external;
}

/// @notice Actual current commerce; Artist, governance and entropy remain explicit typed boundaries.
contract StreamCurrentDynamicNativeRightsAuctionTest is NativeDynamicRightsAuctionFixture {
    receive() external payable { }
    DynamicRightsVm private constant check =
        DynamicRightsVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant RECEIPT = keccak256(
        "PreparedNativeRightsRevenueRecorded(bytes32,bytes32,bytes32,((address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,bytes32)),((uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,bytes32)),bytes32)"
    );

    function _witness(address primaryPayout, address first, address second)
        private
        view
        returns (bytes32)
    {
        DB.Witness memory w;
        w.artistId = keccak256("native auction artist");
        w.payout = primaryPayout;
        w.designation = keccak256(abi.encode("designation", primaryPayout));
        w.generation = 1;
        w.bindingHash = keccak256("native auction binding");
        w.authority = artists.artist();
        w.rows = _rows();
        w.payouts = new address[](2);
        w.designations = new bytes32[](2);
        w.payouts[0] = first;
        w.payouts[1] = second;
        w.designations[0] = keccak256(abi.encode("collaborator designation", COLLAB_ONE, first));
        w.designations[1] = keccak256(abi.encode("collaborator designation", COLLAB_TWO, second));
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DYNAMIC_PRIMARY_BENEFICIARIES_V1"),
                block.chainid,
                address(resolver),
                uint256(1),
                w
            )
        );
    }

    function _receipt(
        bytes32 id,
        bytes32 key,
        StreamSaleTemplate.Selection memory selected,
        bytes32 witness,
        Vm.Log[] memory logs
    ) private view {
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        uint256 receiptCount;
        uint256 dynamicCount;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(recorder)) continue;
            if (logs[i].topics[0] == RECEIPT) {
                ++receiptCount;
                require(
                    logs[i].topics.length == 4 && logs[i].data.length == 1376,
                    "original full43-word receipt"
                );
                (
                    StreamPreparedNativeRightsTypes.Facts memory f,
                    StreamPreparedNativeRightsTypes.Intent memory o,
                    bytes32 policy_
                ) = abi.decode(
                    logs[i].data,
                    (
                        StreamPreparedNativeRightsTypes.Facts,
                        StreamPreparedNativeRightsTypes.Intent,
                        bytes32
                    )
                );
                bytes32 hash = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_FACTS_V1"), block.chainid, f
                    )
                );
                require(
                    logs[i].topics[1] == key
                        && logs[i].topics[2]
                            == recorder.preparedNativeSaleKey(address(house), a.saleId, a.saleNonce)
                        && logs[i].topics[3] == hash
                        && recorder.preparedNativeRightsFactsHash(key) == hash,
                    "all indexed receipt identities"
                );
                require(
                    f.original.mode == 3
                        && keccak256(abi.encode(f.original))
                            == keccak256(abi.encode(house.originalAuctionRights(id)))
                        && keccak256(abi.encode(o.original)) == keccak256(abi.encode(f.original)),
                    "original signed mode and assignment retained"
                );
                require(
                    f.mint.saleAdapter == address(house) && f.mint.mintManager == address(manager)
                        && f.mint.recorder == address(recorder) && f.mint.tokenId == a.tokenId
                        && f.mint.collectionSerial == a.tokenId && f.mint.collectionId == 1
                        && f.mint.tokenDataHash == keccak256("rights artwork")
                        && o.sale.poster == a.config.poster && o.sale.saleId == a.saleId
                        && o.sale.saleNonce == a.saleNonce && o.sale.payer == a.winner.payer
                        && o.sale.executor == a.winner.executor
                        && o.sale.originalPrimaryPolicyHash == a.config.expectedPrimaryPolicyHash,
                    "original context and actual prepared fields"
                );
                require(
                    policy_ == _policy(a.tokenId, selected) && policy_ != _policy(0, selected)
                        && ledger.isManagerOperationRootUsed(address(manager), f.mint.operationRoot)
                        && recorder.settlementResult(key).operationIdentityCommitment
                            == f.mint.operationRoot,
                    "actual token policy and canonical root"
                );
            }
            if (
                logs[i].topics[0]
                    == keccak256(
                        "DynamicPreparedPrimaryBeneficiariesBound(uint16,bytes32,bytes32,bytes32,address)"
                    )
            ) {
                ++dynamicCount;
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == key
                        && logs[i].topics[2] == selected.templateId
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), witness, a.config.poster)),
                    "full independently reconstructed beneficiary witness"
                );
            }
        }
        require(receiptCount == 1 && dynamicCount == 1, "one of each original and additive receipt");
    }

    function testDynamicPosterCollaboratorsAggregateAndPayTwoActualTokensWithFullReceipts() public {
        StreamSaleTemplate.Selection memory selected = _selected();
        (,, uint32 artistShare, bytes32 witness) = resolver.dynamicPrimaryTemplateFacts(1, template);
        require(
            artistShare == 300000
                && witness == _witness(address(0xA77157), address(0xA77157), address(0xC0B2)),
            "artist labels counted separately from arbitrary collaborator labels"
        );
        for (uint256 n; n < 2; ++n) {
            bytes32 id = _createRights(_rightsConfig());
            _rightsBid(id, payer);
            _endRights(id);
            vm.recordLogs();
            (uint256 token, bytes32 key) = house.settle(id);
            _receipt(id, key, selected, witness, vm.getRecordedLogs());
            require(
                token == n + 1 && core.ownerOf(token) == payer
                    && recorder.settlementResult(key).profileId == selected.profileId,
                "actual token and deterministic shared profile"
            );
            if (n == 0) {
                require(
                    recorder.settlementResult(key).escrowed
                        && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                            == 1000,
                    "actual deferred wallet credit"
                );
                require(
                    factory.profileEntryCount(selected.profileId) == 4,
                    "same artist account and label aggregate"
                );
                _share(selected.profileId, address(0xA77157), keccak256("artist"), 300000);
                _share(selected.profileId, address(0xC0B2), keccak256("composer-share"), 300000);
                _share(selected.profileId, address(this), keccak256("poster"), 300000);
                escrow.flushEscrow(CLASS, selected.profileId, selected.wallet, address(0));
            } else {
                require(
                    !recorder.settlementResult(key).escrowed,
                    "existing actual wallet direct funding"
                );
            }
            (uint256 same, bytes32 sameKey) = house.settle(id);
            require(
                same == token && sameKey == key
                    && recorder.totalOfficialSettled(address(0)) == (n + 1) * 1000,
                "terminal replay has no extra funding"
            );
        }
        require(
            selected.wallet.balance == 2000 && manager.nextOperationNonce() == 2
                && core.collectionNextSerial(1) == 3 && house.totalBuyerLiabilities() == 0
                && escrow.totalOwed(address(0)) == 0,
            "two clean original operations"
        );
        uint256 primaryBefore = address(0xA77157).balance;
        uint256 collaboratorBefore = address(0xC0B2).balance;
        uint256 posterBefore = address(this).balance;
        IStreamSplitWallet split = IStreamSplitWallet(selected.wallet);
        require(
            split.release(address(0), address(0xA77157), payable(address(0xA77157))) == 600
                && split.release(address(0), address(0xC0B2), payable(address(0xC0B2))) == 600
                && split.release(address(0), address(this), payable(address(this))) == 600
                && split.release(address(0), address(0xFEE), payable(address(0xFEE))) == 200,
            "actual beneficiaries pull original aggregate shares"
        );
        require(
            address(0xA77157).balance == primaryBefore + 600
                && address(0xC0B2).balance == collaboratorBefore + 600
                && address(this).balance == posterBefore + 600 && selected.wallet.balance == 0,
            "poster and typed collaborator accounts receive the payment"
        );
    }

    function _share(bytes32 id, address account, bytes32 label, uint32 expected) private view {
        uint256 found;
        for (uint256 i; i < factory.profileEntryCount(id); ++i) {
            (address a, uint32 amount, bytes32 l) = factory.profileEntry(id, i);
            if (a == account && l == label) {
                require(amount == expected, "exact concrete share");
                ++found;
            }
        }
        require(found == 1, "one canonical concrete identity");
    }

    function testDynamicPayoutRotationRetainsOriginalSourceConsentAndUsesCurrentPoster() public {
        StreamSaleTemplate.Selection memory old = _selected();
        bytes32 id = _createRights(_rightsConfig());
        _rightsBid(id, payer);
        rightsArtist.setPayout(address(0xA772));
        dynamicArtist.setCollaboratorPayout(COLLAB_ONE, address(0xC0111));
        dynamicArtist.setCollaboratorPayout(COLLAB_TWO, address(0xC0122));
        StreamSaleTemplate.Selection memory selected = _selected();
        require(
            selected.assignmentHash == old.assignmentHash && selected.templateId == old.templateId
                && selected.profileId != old.profileId,
            "designation rotation without source identity or consent rewrite"
        );
        _endRights(id);
        vm.recordLogs();
        (, bytes32 key) = house.settle(id);
        _receipt(
            id,
            key,
            selected,
            _witness(address(0xA772), address(0xC0111), address(0xC0122)),
            vm.getRecordedLogs()
        );
        _share(selected.profileId, address(this), keccak256("poster"), 300000);
        _share(selected.profileId, address(0xC0111), keccak256("artist"), 200000);
        require(
            !factory.profileExists(old.profileId)
                && escrow.escrowOwed(CLASS, old.profileId, old.wallet, address(0)) == 0,
            "unselected preview never funded"
        );
        escrow.flushEscrow(CLASS, selected.profileId, selected.wallet, address(0));
        require(
            selected.wallet.balance == 1000 && old.wallet.balance == 0,
            "only current concrete terms paid"
        );
    }

    function testDynamicSafeLateCollaboratorChangeRollsBackAndIdenticalSignedRetryPays() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE1351;
        keys[1] = 0x5AFE1352;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1351);
        StreamSaleTemplate.Selection memory selected = _selected();
        bytes32 id = _createRights(_rightsConfig());
        _rightsBid(id, address(safe));
        _endRights(id);
        require(
            address(escrow).balance == 0 && escrow.totalOwed(address(0)) == 0,
            "zero funding baseline"
        );
        dynamicArtist.changeCollaboratorAfterFunding(address(escrow), COLLAB_TWO, address(0xBAD));
        bytes memory data = abi.encodeCall(house.settle, (id));
        uint256 nonce = safe.nonce();
        bytes32 digest = safe.getTransactionHash(
            address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory call_ = abi.encodeCall(
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
        check.expectCall(
            address(escrow),
            1000,
            abi.encodeCall(escrow.creditNative, (CLASS, selected.profileId, selected.wallet, true)),
            2
        );
        (bool ok,) = address(safe).call(call_);
        require(
            !ok && safe.nonce() == nonce && core.lastAllocatedTokenId() == 0
                && core.collectionNextSerial(1) == 1 && manager.nextOperationNonce() == 0
                && core.pendingPreparedMintTokenId() == 0
                && manager.activePreparedNativeRights().mint.operationRoot == 0,
            "whole Safe and prepared mint rollback"
        );
        require(
            !factory.profileExists(selected.profileId) && selected.wallet.code.length == 0
                && address(escrow).balance == 0 && escrow.totalOwed(address(0)) == 0
                && recorder.totalOfficialSettled(address(0)) == 0 && house.auction(id).status == 1
                && house.totalBuyerLiabilities() == 1100,
            "late materialization payment sale and liability rollback"
        );
        dynamicArtist.changeCollaboratorAfterFunding(address(0), COLLAB_TWO, address(0));
        vm.recordLogs();
        bytes memory out;
        (ok, out) = address(safe).call(call_);
        require(
            ok && abi.decode(out, (bool)) && safe.nonce() == nonce + 1
                && core.ownerOf(1) == address(safe),
            "same signed Safe bytes succeed"
        );
        _receipt(
            id,
            house.auction(id).settlementKey,
            selected,
            _witness(address(0xA77157), address(0xA77157), address(0xC0B2)),
            vm.getRecordedLogs()
        );
        require(
            escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 1000
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "one actual official payment"
        );
    }

    function testDynamicPaidRowCoverageIdentityAndDesignationFailClosedBeforeBid() public {
        bytes32 id = _createRights(_rightsConfig());
        uint256 value = 1000 + entropy.fee();
        vm.deal(payer, 1 ether);
        for (uint256 n; n < 5; ++n) {
            C.Row[] memory rows = _rows();
            if (n == 0) rows[0].accepted = false;
            if (n == 1) rows[1].collaboratorArtistId = 0;
            if (n == 2) rows[1].acceptanceRecordHash = 0;
            if (n == 3) rows[1].role = keccak256("different source identity");
            if (n == 4) rows[1].shareLabelId = keccak256("artist");
            dynamicArtist.setRows(rows);
            vm.prank(payer);
            (bool ok,) =
                address(house).call{ value: value }(abi.encodeCall(house.bid, (id, address(0))));
            require(
                !ok && house.totalBuyerLiabilities() == 0
                    && house.auction(id).winner.payer == address(0),
                "each actual row needs its own original source"
            );
        }
        dynamicArtist.setRows(_rows());
        dynamicArtist.setCollaboratorPayout(COLLAB_TWO, address(0));
        vm.prank(payer);
        (bool ok,) =
            address(house).call{ value: value }(abi.encodeCall(house.bid, (id, address(0))));
        require(
            !ok && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0,
            "missing payout has no fallback"
        );
        dynamicArtist.setCollaboratorPayout(COLLAB_TWO, address(0xC0B2));
        check.mockCall(
            address(dynamicArtist),
            abi.encodeCall(dynamicArtist.collaboratorPayoutAccount, (COLLAB_TWO, address(0xC012))),
            abi.encode(uint256(type(uint160).max) + 1, bytes32(uint256(1)))
        );
        vm.prank(payer);
        (ok,) = address(house).call{ value: value }(abi.encodeCall(house.bid, (id, address(0))));
        require(!ok, "malformed typed payout rejected");
        check.clearMockedCalls();
        for (uint256 n; n < 2; ++n) {
            check.mockCall(
                address(dynamicArtist),
                abi.encodeWithSignature("collectionArtistState(uint256)", 1),
                abi.encode(
                    n == 0 ? uint8(1) : uint8(2),
                    n == 0 ? uint64(1) : uint64(2),
                    keccak256("native auction artist"),
                    uint8(0),
                    keccak256("native auction binding")
                )
            );
            vm.prank(payer);
            (ok,) = address(house).call{ value: value }(abi.encodeCall(house.bid, (id, address(0))));
            require(
                !ok && house.totalBuyerLiabilities() == 0,
                "unaccepted binding and mismatched row generation fail closed"
            );
            check.clearMockedCalls();
        }
        _rightsBid(id, payer);
        require(house.auction(id).winner.payer == payer, "same sale admits repaired original rows");
    }

    function testDynamicModeAndConcretePosterCannotBeSubstitutedUnderSignatures() public {
        IStreamNativeEnglishAuction.Configuration memory c = _rightsConfig();
        StreamPreparedNativeRightsTypes.OriginalPolicy memory o = _original();
        IStreamNativeEnglishAuction.CreationAuthorization memory a =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.rightsConfigurationHash(c, o),
                vm.addr(SIGNER_KEY),
                bytes32(uint256(3135)),
                this.rightsFixtureTime() + 1000
            );
        bytes32 digest = house.creationAuthorizationDigest(a);
        bytes memory platform = _proof(AUCTION_PLATFORM_KEY, digest);
        bytes memory artistSig = _proof(SIGNER_KEY, digest);
        bytes memory original = abi.encodeCall(
            house.registerRightsAuction, (c, o, bytes("rights artwork"), a, platform, artistSig)
        );
        o.mode = 2;
        (bool ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.registerRightsAuction,
                    (c, o, bytes("rights artwork"), a, platform, artistSig)
                )
            );
        require(!ok, "signed mode immutable");
        o.mode = 3;
        c.poster = payer;
        vm.prank(payer);
        (ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.registerRightsAuction,
                    (c, o, bytes("rights artwork"), a, platform, artistSig)
                )
            );
        require(!ok, "signed poster immutable");
        (ok,) = address(resolver)
            .staticcall(
                abi.encodeCall(
                    resolver.previewDynamicCollectionPrimaryProfile,
                    (template, 1, vm.addr(SIGNER_KEY))
                )
            );
        require(!ok, "accepted artist must use COLLECTION_ARTIST rather than SALE_POSTER");
        (ok,) = address(resolver)
            .staticcall(abi.encodeCall(resolver.primaryTemplateConsentFacts, (template)));
        require(!ok, "old consent facts grammar stays strict");
        (ok,) = address(house).call(original);
        require(ok, "original mode3 request remains usable");
        (ok,) = address(house).call(original);
        require(!ok, "original creator nonce one use");
    }

    function testDynamicReferenceBijectionAndEveryPositiveShareRequireExactConsent() public {
        D.CollaboratorReference[] memory refs = _references();
        require(
            resolver.collaboratorAccountSource(refs[0]) == _source(refs[0]),
            "zero-role original source hash"
        );
        for (uint256 n; n < 4; ++n) {
            refs = _references();
            IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries = _entries();
            if (n == 0) refs[1] = refs[0];
            if (n == 1) refs[0].account = address(0);
            if (n == 2) entries[1].labelId = keccak256("wrong label");
            if (n == 3) entries[3].labelId = keccak256("composer-share");
            (bool ok,) = address(resolver)
                .call(
                    abi.encodeCall(
                        resolver.createDynamicPrimaryTemplate, (entries, bytes32(n), refs)
                    )
                );
            require(!ok, "invalid reference or paid-label substitution cannot register");
        }
        StreamSaleTemplate.Selection memory s = _selected();
        bytes32 id = _createRights(_rightsConfig());
        dynamicArtist.approve(address(resolver), s.assignmentHash, false);
        (bool ok,) = address(resolver)
            .staticcall(abi.encodeCall(resolver.resolvePrimaryAssignment, (1, 0, CLASS)));
        require(!ok, "dynamic collection read always needs exact current consent");
        dynamicArtist.approve(address(resolver), s.assignmentHash, true);
        _rightsBid(id, payer);
        _endRights(id);
        dynamicArtist.approve(address(resolver), s.assignmentHash, false);
        bytes memory call_ = abi.encodeCall(house.settle, (id));
        (ok,) = address(house).call(call_);
        require(
            !ok && core.lastAllocatedTokenId() == 0 && house.totalBuyerLiabilities() == 1100,
            "current consent loss blocks whole settlement"
        );
        dynamicArtist.approve(address(resolver), s.assignmentHash, true);
        (ok,) = address(house).call(call_);
        require(ok && core.ownerOf(1) == payer, "identical original request retries");
    }

    function testDynamicSameLabelSamePayoutRowsEachNeedTheirOwnImmutableSource() public {
        C.Row[] memory rows = _rows();
        rows[1].shareLabelId = keccak256("artist");
        dynamicArtist.setRows(rows);
        dynamicArtist.setCollaboratorPayout(COLLAB_TWO, address(0xA77157));
        D.CollaboratorReference[] memory refs = _references();
        refs[1].shareLabelId = rows[1].shareLabelId;
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries = _entries();
        entries[2].accountSource = _source(refs[1]);
        entries[2].labelId = rows[1].shareLabelId;
        bytes32 id = resolver.createDynamicPrimaryTemplate(
            entries, keccak256("same label same payout"), refs
        );
        bytes32 assignment =
            resolver.previewArtistDynamicPrimaryTemplateAssignment(1, id, 0, false).assignmentHash;
        dynamicArtist.approve(address(resolver), assignment, true);
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, id, 0);
        StreamSaleTemplate.Selection memory s = _selected();
        bytes32 auctionId = _createRights(_rightsConfig());
        _rightsBid(auctionId, payer);
        _endRights(auctionId);
        house.settle(auctionId);
        require(
            factory.profileEntryCount(s.profileId) == 3,
            "three source identities aggregate only after independent coverage"
        );
        _share(s.profileId, address(0xA77157), keccak256("artist"), 600000);
        // Equal final shares/account/label are insufficient when a distinct paid source is omitted.
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory missing =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](4);
        missing[0] = entries[0];
        missing[0].sharePpm = 400000;
        missing[1] = entries[1];
        missing[2] = entries[3];
        missing[3] = entries[4];
        D.CollaboratorReference[] memory one = new D.CollaboratorReference[](1);
        one[0] = refs[0];
        id = resolver.createDynamicPrimaryTemplate(
            missing, keccak256("missing second distinct row"), one
        );
        (bool ok,) = address(resolver)
            .staticcall(abi.encodeCall(resolver.dynamicPrimaryTemplateFacts, (1, id)));
        require(!ok, "same label and payout never stands in for a different collaborator row");
    }
}
