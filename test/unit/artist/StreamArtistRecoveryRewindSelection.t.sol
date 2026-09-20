// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    RewindEvidenceBoundaryStub,
    RewindEvidenceOwnerStub,
    RewindEvidenceCoordinatorStub
} from "./StreamArtistRecoveryRewindEvidence.t.sol";
import {
    StreamArtistRecoveryRewindSelection
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindSelection.sol";
import {
    StreamArtistRecoveryRewindEvidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindEvidence.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistHistoryTypes as N
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

contract RewindSelectionCoordinatorStub is RewindEvidenceCoordinatorStub {
    function seal(
        StreamArtistRecoveryRewindSelection worker,
        bytes32 manifest,
        bytes32 action,
        bytes32 association
    ) external returns (bytes32) {
        return worker.sealPreparationV3(manifest, action, association);
    }
}

/// @dev Deliberately synthetic fixed-owner boundary. It supplies original reader tuples, not real
/// Artist/Safe admissions; the separate actual host covers original producers and all six families.
contract RewindSelectionOwnerStub is RewindEvidenceOwnerStub {
    address private _publisher;
    T.Snapshot private _snapshot;
    N.Receipt[] private _rows;
    W.IdentityBasisV3 private _basis;
    W.IdentityInventoryV3 private _inventory;
    W.PayoutInventoryV3 private _payoutInventory;
    GH.Head private _head;
    mapping(uint64 => GH.Entry) private _entries;
    mapping(bytes32 => R.GuardianRecord) private _guardians;
    mapping(bytes32 => R.TransitionState) private _transitions;
    mapping(bytes32 => W.StatusV3) private _statuses;
    A.Association private _action;
    A.Veto private _veto;
    bytes32 private _executed;
    W.EvidenceStateV3 private _evidence;

    constructor(
        address registry,
        address coordinator,
        address archive,
        address core_,
        address manager,
        bytes32 domain
    ) RewindEvidenceOwnerStub(registry, coordinator, archive, core_, manager, domain) { }

    function setPublisher(address publisher) external {
        _publisher = publisher;
    }

    function setSnapshot(T.Snapshot calldata snapshot) external {
        _snapshot = snapshot;
    }

    function ownerStateSnapshotV2() external view returns (T.Snapshot memory) {
        return _snapshot;
    }

    function append(N.Receipt calldata row) external {
        _rows.push(row);
    }

    function artistNativeReceiptCount() external view returns (uint256) {
        return _rows.length;
    }

    function artistNativeReceiptAt(uint256 index) external view returns (N.Receipt memory) {
        return _rows[index];
    }

    function setBasis(W.IdentityBasisV3 calldata basis) external {
        _basis = basis;
        _inventory = basis.inventory;
    }

    function recoveryRewindBasisV3(bytes32) external view returns (W.IdentityBasisV3 memory) {
        return _basis;
    }

    function recoveryRewindInventoryV3(bytes32)
        external
        view
        returns (W.IdentityInventoryV3 memory)
    {
        return _inventory;
    }

    function payoutRewindInventoryV3(bytes32) external view returns (W.PayoutInventoryV3 memory) {
        return _payoutInventory;
    }

    function recoveryRewindEvidenceBinding() external view returns (address, bytes32) {
        return (_publisher, _publisher.codehash);
    }

    function setGuardian(
        GH.Head calldata head,
        GH.Entry calldata entry,
        R.GuardianRecord calldata record
    ) external {
        _head = head;
        _entries[entry.index] = entry;
        _guardians[record.recordHash] = record;
    }

    function setEntry(GH.Entry calldata entry) external {
        _entries[entry.index] = entry;
    }

    function setTransition(R.TransitionState calldata transition) external {
        _transitions[transition.recordHash] = transition;
    }

    function setStatus(bytes32 hash, W.StatusV3 calldata status) external {
        _statuses[hash] = status;
    }

    function recoveryRecordStatusV3(W.RecordKind, bytes32 hash)
        external
        view
        returns (W.StatusV3 memory)
    {
        return _statuses[hash];
    }

    function guardianHistoryState(bytes32, uint64 index, address, bytes32)
        external
        view
        returns (GH.Head memory, GH.Entry memory, GH.Snapshot memory empty, uint64)
    {
        return (_head, _entries[index], empty, 0);
    }

    function guardianSetRecord(bytes32 hash) external view returns (R.GuardianRecord memory) {
        return _guardians[hash];
    }

    function artistTransitionState(bytes32 hash) external view returns (R.TransitionState memory) {
        return _transitions[hash];
    }

    function setPreparation(A.Association calldata action, W.EvidenceStateV3 calldata evidence)
        external
    {
        _action = action;
        _evidence = evidence;
    }

    function setTerminal(A.Veto calldata veto, bytes32 executed) external {
        _veto = veto;
        _executed = executed;
    }

    function identityRecoveryActionState(bytes32, bytes32)
        external
        view
        returns (A.Association memory, A.Veto memory, bytes32, uint64)
    {
        return (_action, _veto, _executed, _snapshot.revision);
    }

    function identityRecoveryEvidenceStateV3(bytes32, bytes32)
        external
        view
        returns (W.EvidenceStateV3 memory)
    {
        return _evidence;
    }
}

contract StreamArtistRecoveryRewindSelectionTest {
    bytes32 private constant ID = bytes32(uint256(1));
    address private registry;
    address private archive;
    address private core;
    address private manager;
    RewindSelectionCoordinatorStub private coordinator;
    RewindSelectionOwnerStub private identity;
    RewindSelectionOwnerStub private payout;
    StreamArtistRecoveryRewindEvidence private publisher;
    StreamArtistRecoveryRewindSelection private worker;
    GH.Head private head;
    W.ResolutionManifestV3 private manifest;
    W.IdentityBasisV3 private identityBasis;

    function setUp() public {
        registry = address(new RewindEvidenceBoundaryStub());
        archive = address(new RewindEvidenceBoundaryStub());
        core = address(new RewindEvidenceBoundaryStub());
        manager = address(new RewindEvidenceBoundaryStub());
        coordinator = new RewindSelectionCoordinatorStub();
        identity = new RewindSelectionOwnerStub(
            registry,
            address(coordinator),
            archive,
            core,
            manager,
            keccak256("domain:identity_authority")
        );
        payout = new RewindSelectionOwnerStub(
            registry,
            address(coordinator),
            archive,
            core,
            manager,
            keccak256("domain:payout_lifecycle")
        );
        T.SuiteConfiguration memory suite;
        suite.registry = registry;
        suite.archive = archive;
        suite.core = core;
        suite.mintManager = manager;
        suite.owners[2] = address(identity);
        suite.owners[5] = address(payout);
        coordinator.setSuite(suite);
        publisher = new StreamArtistRecoveryRewindEvidence(
            address(identity), registry, address(coordinator), archive, core, manager
        );
        worker = new StreamArtistRecoveryRewindSelection(
            address(identity), registry, address(coordinator)
        );
        identity.setPublisher(address(publisher));
        identity.setSnapshot(
            T.Snapshot(
                keccak256("domain:identity_authority"), 20, bytes32(uint256(2)), bytes32(uint256(3))
            )
        );
        payout.setSnapshot(
            T.Snapshot(
                keccak256("domain:payout_lifecycle"), 4, bytes32(uint256(4)), bytes32(uint256(5))
            )
        );
    }

    function _publish(W.RecordReference[] memory exclusions) private returns (bytes32 hash) {
        manifest.artistId = ID;
        manifest.identity =
            W.ReceiptPrefix(identity.ownerStateSnapshotV2(), identity.artistNativeReceiptCount());
        manifest.payout =
            W.ReceiptPrefix(payout.ownerStateSnapshotV2(), payout.artistNativeReceiptCount());
        manifest.causeHash = bytes32(uint256(6));
        manifest.basis = E.VestingBasis.NO_CONTESTED_VESTING;
        manifest.requestCommitment = bytes32(uint256(7));
        manifest.resolutionEvidenceHash = bytes32(uint256(8));
        manifest.supersededRecords = exclusions;
        hash = publisher.publishResolutionManifestV3(manifest);
        identityBasis.manifestHash = hash;
        identityBasis.artistId = ID;
        identityBasis.ownerCodeHash = address(identity).codehash;
        identityBasis.identity = manifest.identity;
        identityBasis.guardianHistory = head;
        identityBasis.sourceCommitment = keccak256("synthetic owner-authenticated stable source");
        identity.setBasis(identityBasis);
    }

    function _empty() private pure returns (W.RecordReference[] memory) {
        return new W.RecordReference[](0);
    }

    function _guardian(bytes32 hash, uint256 nonce, address actor, bool eligible)
        private
        returns (GH.Entry memory entry)
    {
        R.GuardianRecord memory r;
        r.recordHash = hash;
        r.terms.artistId = ID;
        r.terms.guardians = new address[](1);
        r.terms.guardians[0] = actor;
        r.terms.approvalThreshold = 1;
        r.terms.minContestSeconds = 1;
        r.signer = address(0x100);
        r.authorityClass = 1;
        r.nonce = nonce;
        r.signedAt = 1;
        if (!eligible) {
            bytes32 transition = keccak256(abi.encode(hash, "abandoned original association"));
            r.provisional = R.ProvisionalAssociation(transition, 1);
            identity.setTransition(R.TransitionState(ID, transition, 1, 1, 1, 1, 1, 3));
        }
        entry = GH.Entry(
            ID,
            head.count + 1,
            head.ownerRevision + 1,
            hash,
            keccak256(abi.encode(r)),
            head.commitment,
            0
        );
        entry.commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                block.chainid,
                registry,
                address(identity),
                ID,
                entry.index,
                entry.ownerRevision,
                hash,
                entry.recordDataHash,
                entry.previousCommitment
            )
        );
        head = GH.Head(entry.index, entry.ownerRevision, entry.commitment);
        identity.setGuardian(head, entry, r);
        identity.append(N.Receipt(28, ID, 0, hash));
    }

    function _complete(bytes32 hash) private returns (bytes32 key, W.ResultV3 memory result) {
        key = worker.beginSelectionV3(hash);
        uint256 total = manifest.identity.receiptCount + manifest.payout.receiptCount;
        for (uint256 i; i <= total; ++i) {
            W.ProgressV3 memory p = worker.continueSelectionV3(key, 1);
            if (p.complete) break;
        }
        result = worker.requireSelectionV3(hash);
    }

    function _failure(bytes memory callData, bytes32 key) private {
        (bool ok, bytes memory data) = address(worker).call(callData);
        require(
            !ok
                && keccak256(data)
                    == keccak256(
                        abi.encodeWithSelector(W.InvalidRecoveryRewindSelection.selector, key)
                    ),
            "exact worker failure"
        );
    }

    function testRewindSelectionEmptyRequiresExplicitCompletionAndLiteralResult() public {
        bytes32 hash = _publish(_empty());
        bytes32 key = worker.beginSelectionV3(hash);
        _failure(abi.encodeCall(worker.requireSelectionV3, (hash)), key);
        W.ProgressV3 memory p = worker.continueSelectionV3(key, 1);
        require(
            p.complete && p.identityProcessed == 0 && p.payoutProcessed == 0,
            "explicit empty completion"
        );
        W.ResultV3 memory r = worker.requireSelectionV3(hash);
        require(
            r.guardians.selectedRecordHash == 0 && r.guardians.commitment != 0 && r.commitment != 0,
            "empty differs from missing"
        );
        W.EnvironmentV3 memory e = _environment();
        bytes32 commitment = r.commitment;
        r.commitment = 0;
        require(
            commitment
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_SELECTION_RESULT_V3"),
                        uint16(3),
                        e,
                        r
                    )
                ),
            "literal result domain"
        );
        require(!worker.retainedMemberV3(key, address(0)), "zero never member");
    }

    function testRewindSelectionOneRowChunksIncludeEveryUnrelatedOwnerRow() public {
        identity.append(N.Receipt(25, bytes32(uint256(99)), 0, bytes32(uint256(90))));
        _guardian(bytes32(uint256(11)), 4, address(0x11), true);
        payout.append(N.Receipt(18, bytes32(uint256(99)), 0, bytes32(uint256(91))));
        bytes32 hash = _publish(_empty());
        bytes32 key = worker.beginSelectionV3(hash);
        for (uint256 i; i < 3; ++i) {
            W.ProgressV3 memory p = worker.continueSelectionV3(key, 1);
            require(
                p.identityProcessed + p.payoutProcessed == i + 1, "one actual receipt per chunk"
            );
            require(p.complete == (i == 2), "complete entire owner prefixes");
        }
        W.ResultV3 memory r = worker.requireSelectionV3(hash);
        require(
            r.guardians.selectedRecordHash == bytes32(uint256(11)),
            "unrelated rows skipped semantically"
        );
        (, W.ProgressV3 memory p) = worker.selectionV3(key);
        require(
            p.identityScanCommitment != 0 && p.payoutScanCommitment != 0, "both prefixes committed"
        );
    }

    function testRewindSelectionRetainedMembershipExcludesPriorAndCurrentSupersession() public {
        _guardian(bytes32(uint256(11)), 8, address(0x11), true);
        _guardian(bytes32(uint256(12)), 9, address(0x12), true);
        _guardian(bytes32(uint256(13)), 7, address(0x13), false);
        _guardian(bytes32(uint256(14)), 2, address(0x14), true);
        identity.setStatus(
            bytes32(uint256(11)),
            W.StatusV3(ID, W.RecordKind.GUARDIAN_SET, bytes32(uint256(50)), bytes32(uint256(51)), 0)
        );
        W.RecordReference[] memory x = new W.RecordReference[](1);
        x[0] = W.RecordReference(W.RecordKind.GUARDIAN_SET, bytes32(uint256(12)));
        (bytes32 key, W.ResultV3 memory r) = _complete(_publish(x));
        require(r.guardians.selectedRecordHash == bytes32(uint256(14)), "highest retained eligible");
        require(
            !worker.retainedMemberV3(key, address(0x11))
                && !worker.retainedMemberV3(key, address(0x12)),
            "superseded actors excluded"
        );
        require(
            worker.retainedMemberV3(key, address(0x13))
                && worker.retainedMemberV3(key, address(0x14)),
            "unselected retained still vetoes"
        );
        (W.RecordKind kind, W.SelectedRecordV3 memory record, bool retained, bool eligible) =
            worker.selectionRecordV3(key, bytes32(uint256(13)));
        require(
            kind == W.RecordKind.GUARDIAN_SET && record.nativeIndex == 2 && retained && !eligible,
            "frozen per-record fact"
        );
    }

    function testRewindSelectionMissingAndWrongKindExclusionsFailClosed() public {
        _guardian(bytes32(uint256(11)), 1, address(0x11), true);
        W.RecordReference[] memory x = new W.RecordReference[](1);
        x[0] = W.RecordReference(W.RecordKind.GUARDIAN_SET, bytes32(uint256(12)));
        bytes32 key = worker.beginSelectionV3(_publish(x));
        _failure(abi.encodeCall(worker.continueSelectionV3, (key, uint64(10))), key);
        x[0] = W.RecordReference(W.RecordKind.ESTATE_DIRECTIVE, bytes32(uint256(11)));
        key = worker.beginSelectionV3(_publish(x));
        _failure(abi.encodeCall(worker.continueSelectionV3, (key, uint64(10))), key);
    }

    function testRewindSelectionCorruptGuardianJoinRollsBackThenIdenticalRetry() public {
        GH.Entry memory good = _guardian(bytes32(uint256(11)), 1, address(0x11), true);
        bytes32 hash = _publish(_empty());
        bytes32 key = worker.beginSelectionV3(hash);
        GH.Entry memory bad = abi.decode(abi.encode(good), (GH.Entry));
        bad.previousCommitment = bytes32(uint256(77));
        identity.setEntry(bad);
        _failure(abi.encodeCall(worker.continueSelectionV3, (key, uint64(1))), key);
        (, W.ProgressV3 memory beforeRetry) = worker.selectionV3(key);
        require(beforeRetry.identityProcessed == 0 && !beforeRetry.complete, "failed visit atomic");
        identity.setEntry(good);
        worker.continueSelectionV3(key, 1);
        require(
            worker.requireSelectionV3(hash).guardians.selectedRecordHash == good.recordHash,
            "same key retry"
        );
    }

    function testRewindSelectionOwnerDriftRejectsCurrentButRetainsHistoricalResult() public {
        _guardian(bytes32(uint256(11)), 1, address(0x11), true);
        bytes32 hash = _publish(_empty());
        (bytes32 key, W.ResultV3 memory original) = _complete(hash);
        T.Snapshot memory before = identity.ownerStateSnapshotV2();
        T.Snapshot memory changed = abi.decode(abi.encode(before), (T.Snapshot));
        ++changed.revision;
        changed.stateRoot = keccak256("unrelated change");
        identity.setSnapshot(changed);
        _failure(abi.encodeCall(worker.requireSelectionV3, (hash)), key);
        _failure(abi.encodeCall(worker.continueSelectionV3, (key, uint64(1))), key);
        require(
            worker.selectionResultV3(key).commitment == original.commitment
                && worker.retainedMemberV3(key, address(0x11)),
            "historical frozen proof survives"
        );
        identity.setSnapshot(before);
        require(
            worker.requireSelectionV3(hash).commitment == original.commitment,
            "exact restored source"
        );
    }

    function testRewindSelectionPayoutDriftBeforeBeginUsesManifestAndAfterBeginUsesKey() public {
        bytes32 hash = _publish(_empty());
        T.Snapshot memory before = payout.ownerStateSnapshotV2();
        T.Snapshot memory changed = abi.decode(abi.encode(before), (T.Snapshot));
        ++changed.revision;
        payout.setSnapshot(changed);
        _failure(abi.encodeCall(worker.beginSelectionV3, (hash)), hash);
        payout.setSnapshot(before);
        bytes32 key = worker.beginSelectionV3(hash);
        payout.append(N.Receipt(18, bytes32(uint256(99)), 0, bytes32(uint256(91))));
        _failure(abi.encodeCall(worker.continueSelectionV3, (key, uint64(1))), key);
    }

    function testRewindSelectionSameSnapshotChangedOwnerBasisCannotResume() public {
        bytes32 hash = _publish(_empty());
        bytes32 key = worker.beginSelectionV3(hash);
        identityBasis.sourceCommitment = keccak256("different cause or ancestry");
        identity.setBasis(identityBasis);
        _failure(abi.encodeCall(worker.continueSelectionV3, (key, uint64(1))), key);
    }

    function testRewindSelectionExactPreparationSealAndLaterHistoryRead() public {
        bytes32 hash = _publish(_empty());
        (bytes32 key, W.ResultV3 memory result) = _complete(hash);
        (
            A.Association memory a,
            W.EvidenceStateV3 memory evidence,
            T.Snapshot memory afterPreparation
        ) = _prepare(key, result);
        (bool ok, bytes memory data) = address(worker)
            .call(
                abi.encodeCall(
                    worker.sealPreparationV3, (hash, a.action.actionId, a.associationHash)
                )
            );
        require(
            !ok
                && keccak256(data)
                    == keccak256(
                        abi.encodeWithSelector(
                            W.InvalidRecoveryRewindPreparation.selector, a.action.actionId
                        )
                    ),
            "only fixed coordinator"
        );
        _failure(abi.encodeCall(worker.requireSelectionV3, (hash)), key);
        bytes32 seal = coordinator.seal(worker, hash, a.action.actionId, a.associationHash);
        require(
            seal != 0
                && worker.preparationSealV3(key).identityAfterPreparation.stateRoot
                    == afterPreparation.stateRoot,
            "observed post-root saved separately"
        );
        require(
            worker.requireSelectionV3(hash).commitment == result.commitment, "sealed exact delta"
        );
        require(
            worker.preparationSealV3(key).evidenceStateHash == keccak256(abi.encode(evidence)),
            "original evidence sealed"
        );
        require(
            coordinator.seal(worker, hash, a.action.actionId, a.associationHash) == seal,
            "same seal idempotent"
        );
        ++afterPreparation.revision;
        identity.setSnapshot(afterPreparation);
        identity.setTerminal(A.Veto(address(0x51), bytes32(uint256(52)), 1), 0);
        _failure(abi.encodeCall(worker.requireSelectionV3, (hash)), key);
        require(
            worker.selectionResultV3(key).commitment == result.commitment,
            "veto leaves historical scan"
        );
    }

    function testRewindSelectionBadPreparedAssociationCannotSealAndRestoresExactly() public {
        bytes32 hash = _publish(_empty());
        (bytes32 key, W.ResultV3 memory result) = _complete(hash);
        (A.Association memory a, W.EvidenceStateV3 memory evidence,) = _prepare(key, result);
        W.EvidenceStateV3 memory bad = abi.decode(abi.encode(evidence), (W.EvidenceStateV3));
        bad.sources.associationHash = bytes32(uint256(0xbad));
        identity.setPreparation(a, bad);
        (bool ok,) = address(coordinator)
            .call(
                abi.encodeCall(
                    coordinator.seal, (worker, hash, a.action.actionId, a.associationHash)
                )
            );
        require(!ok && worker.preparationSealV3(key).commitment == 0, "bad association never seals");
        identity.setPreparation(a, evidence);
        require(
            coordinator.seal(worker, hash, a.action.actionId, a.associationHash) != 0,
            "same preparation retry"
        );
    }

    function _prepare(bytes32 key, W.ResultV3 memory result)
        private
        returns (
            A.Association memory a,
            W.EvidenceStateV3 memory evidence,
            T.Snapshot memory afterPreparation
        )
    {
        a.associationHash = keccak256("actual synthetic association");
        a.artistId = ID;
        a.requestHash = bytes32(uint256(41));
        a.acceptanceHash = bytes32(uint256(42));
        a.contextHash = bytes32(uint256(43));
        a.action.actionId = bytes32(uint256(44));
        a.preparedBy = address(0x45);
        a.preparedAt = 1;
        afterPreparation = manifest.identity.snapshot;
        ++afterPreparation.revision;
        afterPreparation.stateRoot = keccak256("actual committed preparation root");
        afterPreparation.recordChainTip = keccak256("actual committed preparation tip");
        a.ownerRevision = afterPreparation.revision;
        evidence.manifestHash = result.manifestHash;
        evidence.sourceKey = key;
        evidence.sourceCommitment = result.sourceCommitment;
        evidence.selectionCommitment = result.commitment;
        evidence.policyCommitment = bytes32(uint256(46));
        evidence.requiredRole = bytes32(uint256(47));
        evidence.associationHash = a.associationHash;
        evidence.sources =
            W.PreparedSourcesV3(manifest.identity, manifest.payout, a.associationHash);
        identity.setSnapshot(afterPreparation);
        identity.setPreparation(a, evidence);
    }

    function _environment() private view returns (W.EnvironmentV3 memory) {
        return W.EnvironmentV3(
            block.chainid,
            registry,
            address(identity),
            address(identity).codehash,
            address(payout),
            address(payout).codehash,
            address(coordinator),
            archive,
            core,
            manager
        );
    }
}
