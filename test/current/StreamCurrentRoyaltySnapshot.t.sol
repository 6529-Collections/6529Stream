// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/NativeRoyaltySnapshotFixture.sol";

interface SnapshotTestVm {
    struct Log { bytes32[] topics; bytes data; address emitter; }
    function expectCall(address target, uint256 value, bytes calldata data) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract StreamCurrentRoyaltySnapshotTest is NativeRoyaltySnapshotFixture {
    SnapshotTestVm private constant check = SnapshotTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testModeConsentAndTypedPhasePreserveCanonicalSourceHashAndRejectOldAuthorization() public {
        (uint8 mode, bytes32 election) = royalty.collectionRoyaltyMode(1);
        require(mode == 2 && election == keccak256(abi.encode(keccak256("6529STREAM_ROYALTY_MODE_ELECTION_V1"),
            block.chainid, address(royalty), address(core), uint256(1), uint8(2))), "exact original mode election");
        StreamArtistOnboardingTypes.AssignmentFact memory raw = royalty.previewArtistRoyaltyAssignmentForScope(1, 1, 1, profile, 350, false);
        require(raw.assignmentHash == originalRoyalty.sourceAssignmentHash && originalRoyalty.modeAssignmentHash == keccak256(abi.encode(
            keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"), block.chainid, address(royalty), address(core),
            uint256(1), election, raw.assignmentHash)), "independent original source and new signed wrapper");
        require(originalRoyalty.sourceRoyaltyPolicyHash == keccak256(abi.encode(keccak256("6529STREAM_ROYALTY_POLICY_V1"),
            block.chainid, address(royalty), uint256(1), uint256(0), profile, wallet, uint16(350), raw.assignmentHash)),
            "canonical source policy retains original per-key hash");
        snapshotArtist.approveRoyalty(address(royalty), raw.assignmentHash);
        (bool ok,) = address(royalty).call(abi.encodeCall(royalty.configureCollectionRoyalty, (uint256(1), profile, uint16(350))));
        require(!ok && royalty.collectionRoyalty(1).revision == 1, "prior live consent cannot authorize mode2 SET");
        snapshotArtist.approveRoyalty(address(royalty), originalRoyalty.modeAssignmentHash);
        (ok,) = address(royalty).call(abi.encodeCall(royalty.electCollectionRoyaltyMode, (uint256(1), uint8(1))));
        require(!ok, "election cannot downgrade");
        (ok,) = address(royalty).call(abi.encodeCall(royalty.currentArtistRoyaltyAssignment, (uint256(1))));
        require(!ok, "old Artist live read cannot masquerade as mode consent");
        (ok,) = address(royalty).call(abi.encodeCall(royalty.freezeCollectionRoyalty, (uint256(1))));
        require(!ok, "unimplemented mode-bound defensive/owner freeze stays explicit");
        IStreamMintRoyaltyPolicy.Policy memory p = _royaltyPolicy();
        bytes32 expected = keccak256(abi.encode(keccak256("6529STREAM_MINT_PHASE_ROYALTY_CONFIG_V1"), block.chainid,
            address(manager), uint256(1), SNAP_PHASE, MANIFEST, address(royalty), address(royalty).codehash, uint8(2),
            election, originalRoyalty.modeAssignmentHash, originalRoyalty.sourceRoyaltyPolicyHash));
        (, IStreamMintManager.MintPhaseConfig memory config) = manager.phase(1, SNAP_PHASE);
        require(expected == config.configHash && manager.phaseRoyaltyConfigHash(1, SNAP_PHASE, p) == expected,
            "standing phase authorization binds both exact source and mode");
        (ok,) = address(manager).call(abi.encodeCall(manager.registerPhaseRoyaltyPolicy, (uint256(1), SNAP_PHASE, p)));
        require(!ok, "configured phase cannot rewrite royalty authorization");
    }

    function testBothSingleStepEntriesAndUntypedExistingPhaseRejectBeforeRootOrTokenAllocation() public {
        IStreamMintManager.MintBatch memory b = _snapshotBatch(SNAP_PHASE, payer, 1);
        (bool ok, bytes memory why) = address(manager).staticcall(abi.encodeCall(manager.previewSingleStepMintOperation, (b, bytes(""))));
        require(!ok && bytes4(why) == IStreamMintRoyaltyPolicy.PreparedRoyaltySnapshotRequired.selector, "preview fails at explicit mode guard");
        (ok, why) = address(manager).call(abi.encodeCall(manager.executeSingleStepMint, (b, bytes(""))));
        require(!ok && bytes4(why) == IStreamMintRoyaltyPolicy.PreparedRoyaltySnapshotRequired.selector, "execution shares exact guard");
        b = _snapshotBatch(PHASE, payer, 1);
        vm.prank(address(house));
        (ok,) = address(manager).call(abi.encodeCall(manager.executePreparedMint, (b, bytes(""))));
        require(!ok && manager.nextOperationNonce() == 0 && core.lastAllocatedTokenId() == 0
            && core.collectionNextSerial(1) == 1 && !manager.isAuthorizationUsed(b.authorizationId),
            "older implicit-live phase cannot mint after mode election");
    }

    function testOrdinaryTwoTokenPreparedBatchSnapshotsBeforeReceiverAndEmitsCanonicalFacts() public {
        SnapshotReceiver receiver = new SnapshotReceiver(royalty, core);
        IStreamMintManager.MintBatch memory b = _snapshotBatch(SNAP_PHASE, address(receiver), 2);
        check.recordLogs();
        (uint256[] memory tokens, bytes32 root, bytes32[] memory operations) = manager.executePreparedMint(b, "");
        require(tokens.length == 2 && tokens[0] == 1 && tokens[1] == 2 && root != 0 && operations[0] != operations[1]
            && receiver.seen() == 2 && manager.nextOperationNonce() == 2 && core.collectionNextSerial(1) == 3,
            "real sequential batch and receiver observation");
        SnapshotTestVm.Log[] memory logs = check.getRecordedLogs();
        uint256 count;
        for (uint256 n; n < logs.length; ++n) {
            if (logs[n].emitter != address(royalty) || logs[n].topics[0] != keccak256(
                "TokenRoyaltySnapshotted(uint16,bytes32,uint256,bytes32,uint256,bytes32,bytes32)")) continue;
            require(count < 2 && logs[n].topics.length == 4 && logs[n].topics[1] == operations[count]
                && uint256(logs[n].topics[2]) == tokens[count] && logs[n].topics[3] == root, "canonical indexed original proof");
            IStreamRoyaltySnapshot.Snapshot memory s = _assertSnapshot(tokens[count]);
            require(s.operationRoot == root && s.operationId == operations[count] && logs[n].data.length == 128
                && keccak256(logs[n].data) == keccak256(abi.encode(uint16(1), uint256(1), keccak256("ROYALTY_ERC2981"), s.tokenRoyaltyPolicyHash)),
                "exact canonical event data and full stored provenance");
            ++count;
        }
        require(count == 2, "one canonical snapshot event per token");
        (bool ok,) = address(manager).call(abi.encodeCall(manager.executePreparedMint, (b, bytes(""))));
        require(!ok && manager.nextOperationNonce() == 2, "original batch authorization replay rejected");
    }

    function testSecondTokenSnapshotFailureRollsBackWholeBatchAndIdenticalCallRetries() public {
        SnapshotReceiver receiver = new SnapshotReceiver(royalty, core);
        IStreamMintManager.MintBatch memory b = _snapshotBatch(SNAP_PHASE, address(receiver), 2);
        bytes memory originalCall = abi.encodeCall(manager.executePreparedMint, (b, bytes("")));
        snapshotArtist.rejectSnapshot(2, address(0));
        (bool ok,) = address(manager).call(originalCall);
        require(!ok && receiver.seen() == 0 && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
            && manager.nextOperationNonce() == 0 && !royalty.royaltySnapshot(1).exists && !royalty.royaltySnapshot(2).exists
            && !royalty.tokenRoyalty(1).configured && !manager.isAuthorizationUsed(b.authorizationId),
            "later snapshot failure rolls back first receiver/token/snapshot and all replay state");
        snapshotArtist.rejectSnapshot(0, address(0));
        (ok,) = address(manager).call(originalCall);
        require(ok && receiver.seen() == 2 && core.collectionNextSerial(1) == 3, "byte-identical original batch succeeds once");
        _assertSnapshot(1); _assertSnapshot(2);
    }

    function testProfileAuctionPaidPreparedPathKeepsSnapshotAndRoyaltyDisclosureStorageOnly() public {
        bytes32 phase = keccak256("snapshot PROFILE auction");
        _snapshotPhase(phase, 1, address(house));
        bytes32 id = _openSnapshot(_snapshotConfiguration(phase));
        _bidCurated(id, payer); _endCurated(id);
        (uint256 token, bytes32 key) = house.settle(id);
        _assertSnapshot(token);
        require(token == 1 && core.ownerOf(token) == payer && recorder.settlementResult(key).amount == 1000
            && wallet.balance == 1000 && recorder.totalOfficialSettled(address(0)) == 1000,
            "actual PROFILE recorder payment and prepared snapshot");
        check.mockCallRevert(address(core), bytes(""), bytes("Core unavailable"));
        check.mockCallRevert(address(factory), bytes(""), bytes("factory unavailable"));
        check.mockCallRevert(address(artists), bytes(""), bytes("Artist unavailable"));
        (address receiver, uint16 bps) = royalty.royaltyReceiverAndBps{gas: 20000}(address(core), token, 1000, 1, true);
        require(receiver == wallet && bps == 350, "royalty marketplace disclosure stays storage only");
        check.clearMockedCalls();
    }

    function testCuratedPaidPreparedPathRetainsOriginalPublishedContentAndSnapshot() public {
        Plan memory p = _snapshotCuratedPlan();
        bytes32 id = _open(p); _bidCurated(id, payer); _endCurated(id);
        (uint256 token, bytes32 key) = house.settle(id);
        _assertSnapshot(token);
        require(token == 1 && keccak256(core.tokenData(token)) == p.selection.tokenDataHash
            && ledger.counterValue(_counterKey(p)) == 1 && manager.preparedNativeContentAdmission() == 0
            && manager.activePreparedNativeContent().operationRoot == 0
            && recorder.settlementResult(key).amount == 1000 && wallet.balance == 1000,
            "actual original curated proof, cap, payment and royalty snapshot all complete");
    }

    function testRightsPaidPathLateRoyaltyFailureRollsBackAndSameSafeTransactionRetries() public {
        // Existing strict collection-template setup; Artist op15 itself is not represented by this typed fixture.
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries = new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(address(0), keccak256("COLLECTION_ARTIST"), 900000, keccak256("artist"));
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(address(0xFEE), 0, 100000, keccak256("protocol"));
        bytes32 template = resolver.createPrimaryTemplate(entries, keccak256("snapshot strict template"));
        artists.accept(address(0)); resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, template, 0); artists.accept(vm.addr(SIGNER_KEY));
        StreamSaleTemplate.Selection memory selected = StreamPreparedNativeRightsProjection.collectionTemplate(resolver, 1);
        bytes32 phase = keccak256("snapshot rights auction"); _snapshotPhase(phase, 1, address(house));
        IStreamNativeEnglishAuction.Configuration memory c;
        c.collectionId = 1; c.phaseId = phase; c.mintAtSettlement = true; c.artworkCommitment = keccak256("snapshot paid artwork");
        c.mintCommitment = keccak256("snapshot rights mint"); c.poster = address(this); c.reservePrice = 1000; c.minIncrementBps = 500;
        uint64 observed = this.snapshotTime();
        c.clock = StreamEnglishAuctionClock.Configuration(observed, observed + 3600, 0, 600, 600, 3600, false, false);
        c.expectedPrimaryPolicyHash = keccak256(abi.encode(keccak256("6529STREAM_PRIMARY_POLICY_V1"), block.chainid,
            address(resolver), CLASS, uint256(1), uint256(0), selected.templateId, selected.profileId, selected.wallet, selected.assignmentHash));
        c.primaryPolicyMode = 1; c.settlementWindow = 86400; c.mintPolicyHash = manager.phasePolicyHash(1, phase);
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original = StreamPreparedNativeRightsTypes.OriginalPolicy(1, selected.assignmentHash, selected.templateId);
        IStreamNativeEnglishAuction.CreationAuthorization memory a = IStreamNativeEnglishAuction.CreationAuthorization(
            house.rightsConfigurationHash(c, original), vm.addr(SIGNER_KEY), bytes32(++snapshotNonce), observed + 1000);
        bytes32 digest = house.creationAuthorizationDigest(a);
        bytes32 id = house.registerRightsAuction(c, original, bytes("snapshot paid artwork"), a, _sig(AUCTION_PLATFORM_KEY, digest), _sig(SIGNER_KEY, digest));
        uint256[] memory keys = new uint256[](2); keys[0] = 0x515001; keys[1] = 0x515002;
        OfficialSafe safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 5150);
        _bidCurated(id, address(safe)); _endCurated(id);
        bytes memory data = abi.encodeCall(house.settle, (id)); uint256 nonce = safe.nonce();
        digest = safe.getTransactionHash(address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce);
        bytes memory exactSafeCall = abi.encodeCall(safe.execTransaction,
            (address(house), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), safeThresholdSignature(keys, digest)));
        require(address(escrow).balance == 0 && escrow.totalOwed(address(0)) == 0, "late funding exact zero baseline");
        snapshotArtist.rejectSnapshot(0, address(escrow));
        check.expectCall(address(escrow), 1000, abi.encodeCall(escrow.creditNative, (CLASS, selected.profileId, selected.wallet, true)));
        (bool ok,) = address(safe).call(exactSafeCall);
        require(!ok && safe.nonce() == nonce && safe.getThreshold() == 2 && core.lastAllocatedTokenId() == 0
            && manager.nextOperationNonce() == 0 && !royalty.royaltySnapshot(1).exists && escrow.totalOwed(address(0)) == 0
            && recorder.totalOfficialSettled(address(0)) == 0 && house.auction(id).status == 1,
            "post-funding royalty change rolls back snapshot, prepare, payment and signed Safe nonce");
        snapshotArtist.rejectSnapshot(0, address(0));
        (ok,) = address(safe).call(exactSafeCall);
        require(ok && safe.nonce() == nonce + 1 && core.lastAllocatedTokenId() == 1
            && recorder.totalOfficialSettled(address(0)) == 1000 && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 1000,
            "identical Safe transaction settles once after correction");
        _assertSnapshot(1);
        escrow.flushEscrow(CLASS, selected.profileId, selected.wallet, address(0));
        require(selected.wallet.balance == 1000 && escrow.totalOwed(address(0)) == 0, "real template payout follows forced escrow");
    }

    function testNoHistoricalRootOrWrongCallerCanRecreateSnapshotAfterComplete() public {
        IStreamMintManager.MintBatch memory b = _snapshotBatch(SNAP_PHASE, payer, 1);
        manager.executePreparedMint(b, "");
        IStreamRoyaltySnapshot.Snapshot memory s = _assertSnapshot(1);
        bytes memory callData = abi.encodeCall(royalty.snapshotTokenRoyaltyAtMint,
            (uint256(1), uint256(1), s.operationRoot, s.operationId, keccak256("ROYALTY_ERC2981"), s.sourceRoyaltyPolicyHash));
        (bool ok,) = address(royalty).call(callData); require(!ok, "foreign caller rejected before saved-state classification");
        vm.prank(address(manager)); (ok,) = address(royalty).call(callData);
        require(!ok && ledger.isManagerOperationRootUsed(address(manager), s.operationRoot),
            "original used root without current prepared record cannot substitute historical proof");
        (ok,) = address(royalty).call(abi.encodeCall(royalty.configureTokenRoyalty, (uint256(1), profile, uint16(100))));
        require(!ok, "old token setter cannot overwrite elected snapshot");
        require(keccak256(abi.encode(royalty.royaltySnapshot(1))) == keccak256(abi.encode(s)), "full retained provenance unchanged");
    }
}
