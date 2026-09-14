// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentDisabledRoyaltySnapshot.t.sol";

interface DefaultSnapshotVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
}

/// @dev Actual Core/Manager/Resolver/recorder/Safe; Artist/governance/entropy are typed boundaries.
contract StreamCurrentDefaultRoyaltySnapshotTest is NativeRoyaltySnapshotFixture {
    SnapshotTestVm private constant check = SnapshotTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant DEFAULT_PHASE = keccak256("actual default source snapshot phase");
    bytes32 private constant ROYALTY = keccak256("ROYALTY_ERC2981");

    function setUp() public override {
        super.setUp();
        // A new actual Resolver has no collection key; original parent phases remain untouched.
        royalty = new StreamRoyaltyResolver(core, factory, address(revenueAuthority), artists);
        vm.prank(address(revenueAuthority)); royalty.transferOwnership(address(this));
        _register(address(royalty), keccak256("REVENUE_RESOLVER"), type(IStreamRoyaltyResolver).interfaceId, MANIFEST);
        _pointer(keccak256("ROYALTY_RESOLVER"), address(royalty));
        royalty.configureDefaultRoyalty(profile, 350);
        royalty.electCollectionRoyaltyMode(1, 2);
        _approveDefault();
        _snapshotPhase(DEFAULT_PHASE, 2, address(this));
    }

    function testDefaultSourcePreservesScopeZeroHashesAndCollectionSpecificModeAuthority() public {
        (StreamArtistOnboardingTypes.AssignmentFact memory raw, IStreamRoyaltyResolver.RoyaltyConfig memory c) =
            royalty.royaltyEconomicsFacts(1, 0, 0);
        require(!royalty.collectionRoyalty(1).configured && raw.scope == 0 && raw.scopeId == 0
            && raw.assignmentHash == originalRoyalty.sourceAssignmentHash && raw.assignmentHash != 0,
            "only absent collection selects exact configured default");
        bytes32 resolverContext = keccak256(abi.encode(keccak256("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1"),
            address(royalty), address(factory), address(factory.assetPolicyRegistry()), factory.splitWalletRuntimeCodeHash()));
        bytes32 scopeContext = keccak256(abi.encode(keccak256("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1"),
            ROYALTY, uint8(0), uint256(0), uint8(1)));
        bytes32 profileContext = keccak256(abi.encode(keccak256("6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1"),
            c.wallet, factory.profileEntriesHash(c.profileId), factory.profileMetadataURIHash(c.profileId)));
        bytes32 pointerContext = keccak256(abi.encode(keccak256("6529STREAM_ROYALTY_ASSIGNMENT_POINTER_CONTEXT_V1"),
            c.profileId, profileContext, c.royaltyBps));
        require(raw.assignmentHash == keccak256(abi.encode(keccak256("6529STREAM_PRIMARY_ASSIGNMENT_V1"),
            block.chainid, resolverContext, scopeContext, pointerContext, bytes32(0), false)), "independent raw scope-zero assignment preimage");
        require(originalRoyalty.sourceRoyaltyPolicyHash == keccak256(abi.encode(
            keccak256("6529STREAM_ROYALTY_POLICY_V1"), block.chainid, address(royalty), uint256(0), uint256(0),
            c.profileId, c.wallet, c.royaltyBps, raw.assignmentHash)), "canonical default policy zeros both identity coordinates");
        require(originalRoyalty.modeAssignmentHash == keccak256(abi.encode(
            keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"), block.chainid, address(royalty), address(core),
            uint256(1), originalRoyalty.electionHash, raw.assignmentHash)), "mode approval binds actual collection to original scope-zero source");
        bytes32 overrideHash = royalty.previewArtistSnapshotRoyaltyAssignment(1, profile, 350, false).assignmentHash;
        require(overrideHash != originalRoyalty.modeAssignmentHash, "prospective SET remains a collection override");
        (bool ok,) = address(royalty).call(abi.encodeCall(royalty.configureCollectionRoyalty, (uint256(1), profile, uint16(350))));
        require(!ok && !royalty.collectionRoyalty(1).configured, "default approval cannot install identical collection economics");
        _secondCollection(); royalty.electCollectionRoyaltyMode(2, 2);
        StreamArtistOnboardingTypes.AssignmentFact memory second = royalty.currentArtistSnapshotRoyaltyAssignment(2);
        (StreamArtistOnboardingTypes.AssignmentFact memory sameRaw,) = royalty.royaltyEconomicsFacts(2, 0, 0);
        require(sameRaw.assignmentHash == raw.assignmentHash && second.scope == 1 && second.scopeId == 2
            && second.assignmentHash != originalRoyalty.modeAssignmentHash, "one global key yields distinct per-collection authorization");
        // Local keyed approval boundary replaces the original fixture's fixed collection-one rule.
        bytes memory key = abi.encodeWithSelector(IStreamArtistEconomicsAuthority.requireEconomicsConsent.selector,
            uint256(2), ROYALTY, uint8(1), uint256(2));
        check.mockCallRevert(address(snapshotArtist), key, abi.encodeWithSignature("Error(string)", "unapproved collection-specific mode hash"));
        DefaultSnapshotVm(address(check)).mockCall(address(snapshotArtist), bytes.concat(key, abi.encode(originalRoyalty.modeAssignmentHash)), bytes(""));
        (ok,) = address(royalty).staticcall(abi.encodeCall(royalty.currentRoyaltySnapshotSource, (uint256(2))));
        require(!ok, "collection-one approval cannot authorize collection two");
        DefaultSnapshotVm(address(check)).mockCall(address(snapshotArtist), bytes.concat(key, abi.encode(second.assignmentHash)), bytes(""));
        IStreamRoyaltySnapshot.Source memory approvedSecond = royalty.currentRoyaltySnapshotSource(2);
        require(approvedSecond.collectionId == 2 && approvedSecond.modeAssignmentHash == second.assignmentHash
            && approvedSecond.sourceAssignmentHash == raw.assignmentHash
            && approvedSecond.sourceRoyaltyPolicyHash == originalRoyalty.sourceRoyaltyPolicyHash,
            "correct collection-two approval admits the same original global source");
    }

    function testDefaultBatchFullReceiptsRemainFrozenAfterDefaultAndOverrideDrift() public {
        SnapshotReceiver receiver = new SnapshotReceiver(royalty, core);
        IStreamMintManager.MintBatch memory b = _snapshotBatch(DEFAULT_PHASE, address(receiver), 2);
        check.recordLogs();
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ops) = manager.executePreparedMint(b, "");
        require(tokens.length == 2 && tokens[0] == 1 && tokens[1] == 2 && ops[0] != ops[1] && receiver.seen() == 2,
            "actual default snapshots precede both receiver callbacks");
        SnapshotTestVm.Log[] memory logs = check.getRecordedLogs(); uint256 count;
        for (uint256 n; n < logs.length; ++n) {
            if (logs[n].emitter != address(royalty) || logs[n].topics[0] != keccak256(
                "TokenRoyaltySnapshotted(uint16,bytes32,uint256,bytes32,uint256,bytes32,bytes32)")) continue;
            require(count < 2, "no extra snapshot events");
            IStreamRoyaltySnapshot.Snapshot memory s = _assertSnapshot(tokens[count]);
            require(count < 2 && logs[n].topics.length == 4 && logs[n].topics[1] == ops[count]
                && uint256(logs[n].topics[2]) == tokens[count] && logs[n].topics[3] == root
                && logs[n].data.length == 128 && keccak256(logs[n].data) == keccak256(abi.encode(
                    uint16(1), uint256(1), ROYALTY, s.tokenRoyaltyPolicyHash)), "complete original default-derived event");
            ++count;
        }
        require(count == 2, "one snapshot per token");
        bytes32 saved = keccak256(abi.encode(royalty.royaltySnapshot(1)));
        royalty.configureDefaultRoyalty(profile, 900);
        bytes32 next = royalty.previewArtistSnapshotRoyaltyAssignment(1, 0, 0, false).assignmentHash;
        snapshotArtist.approveRoyalty(address(royalty), next); royalty.configureCollectionRoyalty(1, 0, 0);
        snapshotArtist.approveRoyalty(address(royalty), 0);
        (address recipient, uint256 amount) = core.royaltyInfo(1, 1 ether);
        require(recipient == wallet && amount == 0.035 ether && keccak256(abi.encode(royalty.royaltySnapshot(1))) == saved,
            "frozen positive default survives disabled override and current consent loss");
        b.authorizationId = keccak256("fresh stale default policy request");
        (bool ok,) = address(manager).call(abi.encodeCall(manager.executePreparedMint, (b, bytes(""))));
        require(!ok && core.lastAllocatedTokenId() == 2 && manager.nextOperationNonce() == 2,
            "old phase cannot authorize changed selected source");
    }

    function testFrozenDefaultRequiresFreshModeAndPhaseButKeepsOriginalSourceScope() public {
        IStreamMintManager.MintBatch memory old = _snapshotBatch(DEFAULT_PHASE, payer, 1);
        royalty.freezeDefaultRoyalty();
        (bool ok,) = address(manager).call(abi.encodeCall(manager.executePreparedMint, (old, bytes(""))));
        require(!ok && core.lastAllocatedTokenId() == 0, "default freeze changes original signed source");
        _approveDefault();
        require(originalRoyalty.config.frozen && !royalty.collectionRoyalty(1).configured, "frozen ancestor does not materialize collection");
        bytes32 phase = keccak256("frozen default snapshot phase"); _snapshotPhase(phase, 1, address(this));
        manager.executePreparedMint(_snapshotBatch(phase, payer, 1), ""); _assertSnapshot(1);
        (StreamArtistOnboardingTypes.AssignmentFact memory raw,) = royalty.royaltyEconomicsFacts(1, 0, 0);
        require(raw.assignmentHash == originalRoyalty.sourceAssignmentHash, "frozen bit retained in scope-zero source");
    }

    function testDisabledDefaultPreparedNoopAndCollectionOverrideSuppression() public {
        royalty.configureDefaultRoyalty(0, 0); _approveDefault();
        bytes32 phase = keccak256("disabled inherited default phase"); _snapshotPhase(phase, 1, address(this));
        bytes32 root = keccak256("actual default controlled root"); bytes32 operation = keccak256("actual default controlled operation");
        IStreamMintLedger.CounterConsumption[] memory counters = new IStreamMintLedger.CounterConsumption[](0);
        bytes32[] memory nullifiers = new bytes32[](0); bytes32 policyHash = manager.phasePolicyHash(1, phase);
        vm.prank(address(manager)); ledger.consume(1, phase, counters, keccak256("default controlled authorization"), nullifiers, policyHash, root);
        bytes memory artwork = bytes("controlled default bytes"); bytes32 dataHash = keccak256(artwork);
        vm.prank(address(manager)); (uint256 token,) = core.prepareMintFromManager(1, artwork, dataHash, operation);
        bytes memory exact = abi.encodeCall(royalty.snapshotTokenRoyaltyAtMint,
            (token, uint256(1), root, operation, ROYALTY, originalRoyalty.sourceRoyaltyPolicyHash));
        vm.prank(address(manager)); (bool ok, bytes memory first) = address(royalty).call(exact); require(ok, "actual disabled default snapshot");
        IStreamRoyaltySnapshot.Snapshot memory saved = royalty.royaltySnapshot(token);
        check.recordLogs(); vm.prank(address(manager)); (ok, artwork) = address(royalty).call(exact);
        require(ok && keccak256(first) == keccak256(artwork) && check.getRecordedLogs().length == 0
            && keccak256(abi.encode(saved)) == keccak256(abi.encode(royalty.royaltySnapshot(token)))
            && royalty.tokenRoyalty(token).configured && royalty.tokenRoyalty(token).frozen
            && royalty.tokenRoyalty(token).revision == 1 && royalty.tokenRoyalty(token).profileId == 0,
            "configured-zero default full silent idempotence");
        vm.prank(address(manager)); core.completePreparedMintFromManager(token, payer, operation, keccak256("default controlled mint"));
        vm.prank(address(manager)); (ok,) = address(royalty).call(exact); require(!ok, "completed proof is not live proof");
        royalty.configureDefaultRoyalty(profile, 900);
        bytes32 approval = royalty.previewArtistSnapshotRoyaltyAssignment(1, 0, 0, false).assignmentHash;
        snapshotArtist.approveRoyalty(address(royalty), approval); royalty.configureCollectionRoyalty(1, 0, 0);
        IStreamRoyaltySnapshot.Source memory selected = royalty.currentRoyaltySnapshotSource(1);
        (StreamArtistOnboardingTypes.AssignmentFact memory collection,) = royalty.royaltyEconomicsFacts(1, 1, 1);
        require(selected.sourceAssignmentHash == collection.assignmentHash && selected.modeAssignmentHash == approval,
            "configured disabled collection wins over positive default");
        (address receiver, uint256 amount) = core.royaltyInfo(token, 1 ether);
        require(receiver == address(0) && amount == 0, "original default-zero token remains zero");
    }

    function testDefaultSecondTokenFailureRollsBackAndIdenticalBatchRetries() public {
        SnapshotReceiver receiver = new SnapshotReceiver(royalty, core);
        IStreamMintManager.MintBatch memory b = _snapshotBatch(DEFAULT_PHASE, address(receiver), 2);
        bytes memory exact = abi.encodeCall(manager.executePreparedMint, (b, bytes("")));
        snapshotArtist.rejectSnapshot(2, address(0)); (bool ok,) = address(manager).call(exact);
        require(!ok && receiver.seen() == 0 && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
            && manager.nextOperationNonce() == 0 && !manager.isAuthorizationUsed(b.authorizationId)
            && !royalty.royaltySnapshot(1).exists && !royalty.royaltySnapshot(2).exists
            && !royalty.tokenRoyalty(1).configured && !royalty.collectionRoyalty(1).configured,
            "default-derived first token and original replay state roll back");
        snapshotArtist.rejectSnapshot(0, address(0)); (ok,) = address(manager).call(exact);
        require(ok && receiver.seen() == 2, "identical original batch retries"); _assertSnapshot(1); _assertSnapshot(2);
    }

    function testDefaultPaidSafePostFundingFailureAndIdenticalSignedRetry() public {
        bytes32 phase = keccak256("default actual paid phase"); _snapshotPhase(phase, 1, address(house));
        bytes32 id = _openSnapshot(_snapshotConfiguration(phase));
        uint256[] memory keys = new uint256[](2); keys[0] = 0xDEF001; keys[1] = 0xDEF002;
        OfficialSafe safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1500);
        _bidCurated(id, address(safe)); _endCurated(id);
        bytes memory data = abi.encodeCall(house.settle, (id)); uint256 nonce = safe.nonce();
        bytes32 digest = safe.getTransactionHash(address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce);
        bytes memory exact = abi.encodeCall(safe.execTransaction,
            (address(house), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), safeThresholdSignature(keys, digest)));
        require(wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0, "exact funding baseline");
        snapshotArtist.rejectSnapshot(0, wallet);
        DisabledSnapshotVm(address(check)).expectCall(wallet, 1000, bytes(""), 2);
        (bool ok,) = address(safe).call(exact);
        require(!ok && safe.nonce() == nonce && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0
            && !royalty.royaltySnapshot(1).exists && !royalty.tokenRoyalty(1).configured && wallet.balance == 0
            && recorder.totalOfficialSettled(address(0)) == 0 && house.auction(id).status == 1,
            "post-funding default consent failure rolls back mint, payment and Safe nonce");
        snapshotArtist.rejectSnapshot(0, address(0)); (ok,) = address(safe).call(exact);
        require(ok && safe.nonce() == nonce + 1 && core.ownerOf(1) == address(safe) && wallet.balance == 1000
            && recorder.totalOfficialSettled(address(0)) == 1000, "exact same signed Safe call pays once"); _assertSnapshot(1);
    }

    function _approveDefault() private {
        bytes32 approval = royalty.currentArtistSnapshotRoyaltyAssignment(1).assignmentHash;
        snapshotArtist.approveRoyalty(address(royalty), approval);
        originalRoyalty = royalty.currentRoyaltySnapshotSource(1);
    }

    function _secondCollection() private {
        bytes32 scope = keccak256(abi.encode(
            bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
            block.chainid, address(core), uint256(2)));
        bytes32 d = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        _context(scope, keccak256(abi.encode(d, scope, false, uint8(0), uint8(0), false, uint256(0))),
            keccak256(abi.encode(d, scope, true, uint8(2), uint8(0), false, uint256(0))), 1);
        vm.prank(address(revenueAuthority)); core.createCollection(2, false, 0, 0); _clearContext();
    }
}
