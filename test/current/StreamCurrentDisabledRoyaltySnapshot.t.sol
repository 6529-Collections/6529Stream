// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/NativeRoyaltySnapshotFixture.sol";
import "./StreamCurrentRoyaltySnapshot.t.sol";

interface DisabledSnapshotVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @dev Actual Core/Manager/Ledger/Resolver/recorder/house/Safe; original Artist consent
/// is exercised separately by StreamArtistSnapshotRoyaltyConsentTest.
contract StreamCurrentDisabledRoyaltySnapshotTest is NativeRoyaltySnapshotFixture {
    SnapshotTestVm private constant check = SnapshotTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant DISABLED_PHASE = keccak256("configured disabled prepared royalty phase");
    bytes32 private constant ROYALTY = keccak256("ROYALTY_ERC2981");

    function setUp() public override {
        super.setUp();
        royalty.configureDefaultRoyalty(profile, 900);
        _forbidZeroProfileObservations();
        bytes32 approved = royalty.previewArtistSnapshotRoyaltyAssignment(1, 0, 0, false).assignmentHash;
        snapshotArtist.approveRoyalty(address(royalty), approved);
        royalty.configureCollectionRoyalty(1, 0, 0);
        originalRoyalty = royalty.currentRoyaltySnapshotSource(1);
        _snapshotPhase(DISABLED_PHASE, 2, address(this));
    }

    function testDisabledSourceHasOriginalNonzeroHashesAndRejectsMixedMissingAndSingleStep() public {
        require(originalRoyalty.config.configured && !originalRoyalty.config.frozen
            && originalRoyalty.config.profileId == 0 && originalRoyalty.config.wallet == address(0)
            && originalRoyalty.config.royaltyBps == 0, "configured disabled is not an empty assignment");
        bytes32 assignment = _zeroAssignment(1, 1, false);
        require(assignment != 0 && assignment == originalRoyalty.sourceAssignmentHash
            && originalRoyalty.sourceRoyaltyPolicyHash == _zeroPolicy(0, assignment)
            && originalRoyalty.modeAssignmentHash == keccak256(abi.encode(
                keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"), block.chainid, address(royalty),
                address(core), uint256(1), originalRoyalty.electionHash, assignment)), "exact independent zero source and mode preimages");
        bytes memory bad = abi.encodeCall(royalty.previewArtistSnapshotRoyaltyAssignment, (uint256(1), profile, uint16(0), false));
        (bool ok,) = address(royalty).staticcall(bad); require(!ok, "nonzero profile zero rate rejects");
        bad = abi.encodeCall(royalty.previewArtistSnapshotRoyaltyAssignment, (uint256(1), bytes32(0), uint16(1), false));
        (ok,) = address(royalty).staticcall(bad); require(!ok, "zero profile positive rate rejects");
        snapshotArtist.approveRoyalty(address(royalty), assignment);
        (ok,) = address(royalty).call(abi.encodeCall(royalty.configureCollectionRoyalty, (uint256(1), bytes32(0), uint16(0))));
        require(!ok && royalty.collectionRoyalty(1).revision == 2, "live zero approval does not authorize elected source");
        snapshotArtist.approveRoyalty(address(royalty), originalRoyalty.modeAssignmentHash);
        IStreamMintManager.MintBatch memory b = _snapshotBatch(DISABLED_PHASE, payer, 1);
        bytes memory why;
        (ok, why) = address(manager).staticcall(abi.encodeCall(manager.previewSingleStepMintOperation, (b, bytes(""))));
        require(!ok && bytes4(why) == IStreamMintRoyaltyPolicy.PreparedRoyaltySnapshotRequired.selector, "disabled still requires prepared preview");
        (ok, why) = address(manager).call(abi.encodeCall(manager.executeSingleStepMint, (b, bytes(""))));
        require(!ok && bytes4(why) == IStreamMintRoyaltyPolicy.PreparedRoyaltySnapshotRequired.selector
            && manager.nextOperationNonce() == 0 && core.lastAllocatedTokenId() == 0, "zero rate cannot bypass prepared execution");
        StreamRoyaltyResolver missing = new StreamRoyaltyResolver(core, factory, address(revenueAuthority), artists);
        vm.prank(address(revenueAuthority)); missing.configureDefaultRoyalty(profile, 900);
        vm.prank(address(revenueAuthority)); missing.electCollectionRoyaltyMode(1, 2);
        (ok, why) = address(missing).staticcall(abi.encodeCall(missing.currentRoyaltySnapshotSource, (uint256(1))));
        require(!ok && bytes4(why) == IStreamRoyaltySnapshot.InvalidRoyaltySnapshot.selector,
            "missing collection is not disabled or an implemented default snapshot");
    }

    function testDisabledBatchEmitsFullCanonicalReceiptsAndFrozenZeroSurvivesFuturePositiveTerms() public {
        SnapshotReceiver receiver = new SnapshotReceiver(royalty, core);
        IStreamMintManager.MintBatch memory b = _snapshotBatch(DISABLED_PHASE, address(receiver), 2);
        check.recordLogs();
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ops) = manager.executePreparedMint(b, "");
        require(tokens.length == 2 && tokens[0] == 1 && tokens[1] == 2 && ops[0] != ops[1] && receiver.seen() == 2,
            "two original snapshots precede actual receiver callbacks");
        SnapshotTestVm.Log[] memory logs = check.getRecordedLogs(); uint256 count;
        for (uint256 n; n < logs.length; ++n) {
            if (logs[n].emitter != address(royalty) || logs[n].topics[0] != keccak256(
                "TokenRoyaltySnapshotted(uint16,bytes32,uint256,bytes32,uint256,bytes32,bytes32)")) continue;
            require(count < 2 && logs[n].topics.length == 4 && logs[n].topics[1] == ops[count]
                && uint256(logs[n].topics[2]) == tokens[count] && logs[n].topics[3] == root, "original indexed identities");
            IStreamRoyaltySnapshot.Snapshot memory s = _assertDisabled(tokens[count]);
            require(s.operationRoot == root && s.operationId == ops[count] && logs[n].data.length == 128
                && keccak256(logs[n].data) == keccak256(abi.encode(uint16(1), uint256(1), ROYALTY, s.tokenRoyaltyPolicyHash)),
                "full canonical zero snapshot event"); ++count;
        }
        require(count == 2, "exactly one fact per token");
        IStreamRoyaltySnapshot.Snapshot memory saved = royalty.royaltySnapshot(1);
        bytes32 next = royalty.previewArtistSnapshotRoyaltyAssignment(1, profile, 700, false).assignmentHash;
        snapshotArtist.approveRoyalty(address(royalty), next); royalty.configureCollectionRoyalty(1, profile, 700);
        royalty.configureDefaultRoyalty(profile, 1000);
        snapshotArtist.approveRoyalty(address(royalty), bytes32(0));
        (address recipient, uint256 amount) = core.royaltyInfo(1, 1 ether);
        require(recipient == address(0) && amount == 0 && keccak256(abi.encode(royalty.royaltySnapshot(1))) == keccak256(abi.encode(saved)),
            "frozen configured zero suppresses later positive collection/default despite lost consent");
        (bool ok,) = address(manager).call(abi.encodeCall(manager.executePreparedMint, (b, bytes(""))));
        require(!ok && core.lastAllocatedTokenId() == 2 && manager.nextOperationNonce() == 2, "old authorization cannot replay");
        b.authorizationId = keccak256("fresh authorization still cannot use stale zero phase");
        (ok,) = address(manager).call(abi.encodeCall(manager.executePreparedMint, (b, bytes(""))));
        require(!ok && core.lastAllocatedTokenId() == 2, "read-only frozen zero does not authorize new mint after source drift");
    }

    function testDisabledSecondTokenFailureRollsBackAllStateAndIdenticalBatchRetries() public {
        SnapshotReceiver receiver = new SnapshotReceiver(royalty, core);
        IStreamMintManager.MintBatch memory b = _snapshotBatch(DISABLED_PHASE, address(receiver), 2);
        bytes memory exact = abi.encodeCall(manager.executePreparedMint, (b, bytes("")));
        snapshotArtist.rejectSnapshot(2, address(0)); (bool ok,) = address(manager).call(exact);
        require(!ok && receiver.seen() == 0 && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
            && manager.nextOperationNonce() == 0 && !manager.isAuthorizationUsed(b.authorizationId)
            && !royalty.royaltySnapshot(1).exists && !royalty.royaltySnapshot(2).exists
            && !royalty.tokenRoyalty(1).configured && !royalty.tokenRoyalty(2).frozen, "zero economics still rolls back complete first-token state");
        snapshotArtist.rejectSnapshot(0, address(0)); (ok,) = address(manager).call(exact);
        require(ok && receiver.seen() == 2 && core.collectionNextSerial(1) == 3, "same original batch retries");
        _assertDisabled(1); _assertDisabled(2);
    }

    function testDisabledPaidSafeLateFundingFailureAndExactRetryPreserveOfficialPayment() public {
        bytes32 phase = keccak256("disabled royalty actual paid phase"); _snapshotPhase(phase, 1, address(house));
        bytes32 id = _openSnapshot(_snapshotConfiguration(phase));
        uint256[] memory keys = new uint256[](2); keys[0] = 0xD15001; keys[1] = 0xD15002;
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
            "post-payment consent failure rolls back configured-zero snapshot and original signed Safe nonce");
        snapshotArtist.rejectSnapshot(0, address(0)); (ok,) = address(safe).call(exact);
        require(ok && safe.nonce() == nonce + 1 && core.ownerOf(1) == address(safe) && wallet.balance == 1000
            && recorder.totalOfficialSettled(address(0)) == 1000, "identical signed Safe call pays primary proceeds once");
        _assertDisabled(1);
        (address recipient, uint256 amount) = core.royaltyInfo(1, 1 ether);
        require(recipient == address(0) && amount == 0, "primary payment does not invent a zero-rate royalty recipient");
    }

    function testDisabledCurrentPreparedProofIsSilentNoopAndConflictsRemainRejected() public {
        bytes32 root = keccak256("controlled disabled original Ledger root"); bytes32 operation = keccak256("controlled disabled Core operation");
        bytes32 policyHash = manager.phasePolicyHash(1, DISABLED_PHASE);
        IStreamMintLedger.CounterConsumption[] memory counters = new IStreamMintLedger.CounterConsumption[](0);
        bytes32[] memory nullifiers = new bytes32[](0);
        vm.prank(address(manager)); ledger.consume(1, DISABLED_PHASE, counters, keccak256("controlled disabled authorization"), nullifiers, policyHash, root);
        bytes memory data = bytes("controlled disabled prepared bytes"); bytes32 dataHash = keccak256(data);
        vm.prank(address(manager)); (uint256 token,) = core.prepareMintFromManager(1, data, dataHash, operation);
        bytes memory exact = abi.encodeCall(royalty.snapshotTokenRoyaltyAtMint,
            (token, uint256(1), root, operation, ROYALTY, originalRoyalty.sourceRoyaltyPolicyHash));
        vm.prank(address(manager)); (bool ok, bytes memory first) = address(royalty).call(exact); require(ok, "first controlled snapshot");
        IStreamRoyaltySnapshot.Snapshot memory saved = _assertDisabled(token);
        check.recordLogs(); vm.prank(address(manager)); (ok, data) = address(royalty).call(exact);
        require(ok && data.length == 32 && keccak256(data) == keccak256(first) && check.getRecordedLogs().length == 0
            && keccak256(abi.encode(royalty.royaltySnapshot(token))) == keccak256(abi.encode(saved))
            && royalty.tokenRoyalty(token).revision == 1, "zero economics retains full idempotence without duplicate writes/events");
        bytes memory wrong = abi.encodeCall(royalty.snapshotTokenRoyaltyAtMint, (token, uint256(1), root, operation, ROYALTY, bytes32(0)));
        vm.prank(address(manager)); (ok,) = address(royalty).call(wrong); require(!ok, "zero expected policy is not a disabled policy");
        vm.prank(address(manager)); core.completePreparedMintFromManager(token, payer, operation, keccak256("disabled controlled mint"));
        vm.prank(address(manager)); (ok,) = address(royalty).call(exact);
        require(!ok && core.ownerOf(token) == payer && keccak256(abi.encode(royalty.royaltySnapshot(token))) == keccak256(abi.encode(saved)),
            "historical root cannot repeat disabled snapshot proof");
    }

    function _assertDisabled(uint256 token) private view returns (IStreamRoyaltySnapshot.Snapshot memory s) {
        s = royalty.royaltySnapshot(token); IStreamRoyaltyResolver.RoyaltyConfig memory c = royalty.tokenRoyalty(token);
        require(s.exists && s.collectionId == 1 && s.tokenId == token && s.manager == address(manager)
            && s.operationId != 0 && s.preparedProofHash != 0 && ledger.isManagerOperationRootUsed(address(manager), s.operationRoot)
            && s.electionHash == originalRoyalty.electionHash && s.modeAssignmentHash == originalRoyalty.modeAssignmentHash
            && s.sourceAssignmentHash == originalRoyalty.sourceAssignmentHash && s.sourceRoyaltyPolicyHash == originalRoyalty.sourceRoyaltyPolicyHash
            && c.configured && c.frozen && c.revision == 1 && c.profileId == 0 && c.wallet == address(0) && c.royaltyBps == 0
            && s.tokenConfigHash == keccak256(abi.encode(c)), "full configured-disabled token and provenance");
        bytes32 assignment = _zeroAssignment(2, token, true);
        require(s.tokenAssignmentHash == assignment && assignment != 0 && s.tokenRoyaltyPolicyHash == _zeroPolicy(token, assignment)
            && s.tokenRoyaltyPolicyHash != originalRoyalty.sourceRoyaltyPolicyHash, "scope2 frozen zero has its own canonical nonzero hashes");
    }

    function _forbidZeroProfileObservations() private {
        bytes memory reason = abi.encodeWithSignature("Error(string)", "no profile-specific P(0) observation");
        check.mockCallRevert(address(factory), abi.encodeCall(factory.splitWalletExists, (bytes32(0))), reason);
        check.mockCallRevert(address(factory), abi.encodeCall(factory.walletFor, (bytes32(0))), reason);
        check.mockCallRevert(address(factory), abi.encodeCall(factory.profileEntriesHash, (bytes32(0))), reason);
        check.mockCallRevert(address(factory), abi.encodeCall(factory.profileMetadataURIHash, (bytes32(0))), reason);
    }

    function _zeroAssignment(uint8 scope, uint256 scopeId, bool frozen) private view returns (bytes32) {
        bytes32 resolverContext = keccak256(abi.encode(keccak256("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1"),
            address(royalty), address(factory), address(factory.assetPolicyRegistry()), factory.splitWalletRuntimeCodeHash()));
        bytes32 scopeContext = keccak256(abi.encode(keccak256("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1"), ROYALTY, scope, scopeId, uint8(1)));
        bytes32 profileContext = keccak256(abi.encode(keccak256("6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1"), address(0), bytes32(0), bytes32(0)));
        bytes32 pointerContext = keccak256(abi.encode(keccak256("6529STREAM_ROYALTY_ASSIGNMENT_POINTER_CONTEXT_V1"), bytes32(0), profileContext, uint16(0)));
        return keccak256(abi.encode(keccak256("6529STREAM_PRIMARY_ASSIGNMENT_V1"), block.chainid, resolverContext, scopeContext, pointerContext, bytes32(0), frozen));
    }

    function _zeroPolicy(uint256 token, bytes32 assignment) private view returns (bytes32) {
        return keccak256(abi.encode(keccak256("6529STREAM_ROYALTY_POLICY_V1"), block.chainid, address(royalty), uint256(1), token,
            bytes32(0), address(0), uint16(0), assignment));
    }
}
