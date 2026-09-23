// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoverySelectionPreparation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoverySelectionPreparation.sol";
import {
    StreamArtistRecoverySelectionDeployment
} from "../../../smart-contracts/domains/artist/StreamArtistRecoverySelectionDeployment.sol";
import {
    StreamArtistRecoveryEvidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryEvidence.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistRecoverySelectionTypesV2 as V2
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoverySelectionTypesV2.sol";
import {
    StreamArtistGuardianSelectionTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianSupersessionTypes as Sup
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";

/// @dev Synthetic owner boundary for bounded computation controls, not semantic admission evidence.
contract RecoverySelectionOwnerFixture {
    bytes32 public constant ARTIST = bytes32(uint256(1));
    address public constant artistRegistry = address(2);
    uint256 public immutable deploymentChainId = block.chainid;
    StreamArtistRecoveryEvidence public immutable evidence;
    StreamArtistRecoverySelectionPreparation public immutable worker;
    bytes32 public evidenceCodeHash;
    bytes32 public sourceCommitment = keccak256("authenticated source generation 1");
    H.Head private _head;
    mapping(uint64 => H.Entry) private _entries;
    mapping(bytes32 => R.GuardianRecord) private _records;
    mapping(bytes32 => R.TransitionState) private _transitions;
    mapping(bytes32 => Sup.Status) private _supersessions;

    constructor() {
        evidence = new StreamArtistRecoveryEvidence(
            address(this), artistRegistry, address(3), address(4), address(5), address(6)
        );
        evidenceCodeHash = address(evidence).codehash;
        worker = StreamArtistRecoverySelectionPreparation(
            StreamArtistRecoverySelectionDeployment.deploy(address(this), artistRegistry)
        );
    }

    function recoveryEvidenceBinding() external view returns (address, bytes32) {
        return (address(evidence), evidenceCodeHash);
    }

    function recoverySelectionBasisV2(bytes32 manifestHash)
        external
        view
        returns (V2.Basis memory)
    {
        return V2.Basis(manifestHash, ARTIST, address(this).codehash, _head, sourceCommitment);
    }

    function guardianHistoryState(bytes32 artistId, uint64 index, address, bytes32)
        external
        view
        returns (H.Head memory, H.Entry memory, H.Snapshot memory snapshot, uint64)
    {
        require(artistId == ARTIST);
        return (_head, _entries[index], snapshot, 0);
    }

    function guardianSetRecord(bytes32 record) external view returns (R.GuardianRecord memory) {
        return _records[record];
    }

    function artistTransitionState(bytes32 record)
        external
        view
        returns (R.TransitionState memory)
    {
        return _transitions[record];
    }

    function guardianRecordSupersession(bytes32 record) external view returns (Sup.Status memory) {
        return _supersessions[record];
    }

    function append(uint256 nonce, R.ProvisionalAssociation memory association)
        external
        returns (bytes32 hash)
    {
        return _append(nonce, association, new address[](0));
    }

    function appendMembers(
        uint256 nonce,
        R.ProvisionalAssociation memory association,
        address[] memory guardians
    ) external returns (bytes32 hash) {
        return _append(nonce, association, guardians);
    }

    function _append(
        uint256 nonce,
        R.ProvisionalAssociation memory association,
        address[] memory guardians
    ) private returns (bytes32 hash) {
        uint64 index = _head.count + 1;
        hash = bytes32(uint256(index));
        R.GuardianRecord memory r;
        r.recordHash = hash;
        r.terms = R.GuardianSet(ARTIST, guardians, guardians.length == 0 ? 0 : 1, 0);
        r.signer = address(7);
        r.authorityClass = 1;
        r.nonce = nonce;
        r.provisional = association;
        _records[hash] = r;
        H.Entry memory entry =
            H.Entry(ARTIST, index, index, hash, keccak256(abi.encode(r)), _head.commitment, 0);
        entry.commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                deploymentChainId,
                artistRegistry,
                address(this),
                entry.artistId,
                entry.index,
                entry.ownerRevision,
                entry.recordHash,
                entry.recordDataHash,
                entry.previousCommitment
            )
        );
        _entries[index] = entry;
        _head = H.Head(index, index, entry.commitment);
    }

    function publish(bytes32[] memory excluded) external returns (bytes32) {
        E.ResolutionManifest memory m;
        m.artistId = ARTIST;
        m.ownerRevision = _head.ownerRevision + 1;
        m.causeHash = keccak256("synthetic current native cause");
        m.requestCommitment = keccak256("synthetic original request commitment");
        m.resolutionEvidenceHash = keccak256("synthetic governance evidence");
        m.contestedVestings = new E.VestingReference[](0);
        m.supersededRecordHashes = excluded;
        return evidence.publishResolutionManifest(m);
    }

    function setSource(bytes32 value) external {
        sourceCommitment = value;
    }

    function setEvidenceCodeHash(bytes32 value) external {
        evidenceCodeHash = value;
    }

    function setHead(H.Head calldata value) external {
        _head = value;
    }

    function setEntry(uint64 index, H.Entry calldata value) external {
        _entries[index] = value;
    }

    function setRecord(bytes32 hash, R.GuardianRecord calldata value) external {
        _records[hash] = value;
    }

    function setTransition(bytes32 hash, R.TransitionState calldata value) external {
        _transitions[hash] = value;
    }

    function setSupersession(bytes32 hash, Sup.Status calldata value) external {
        _supersessions[hash] = value;
    }
}

/// @notice Worker controls with a mutable synthetic owner; actual Artist admission has a separate host.
contract StreamArtistRecoverySelectionPreparationTest {
    RecoverySelectionOwnerFixture private owner;
    StreamArtistRecoverySelectionPreparation private worker;

    function setUp() public {
        owner = new RecoverySelectionOwnerFixture();
        worker = owner.worker();
    }

    function _append(uint256 nonce) private returns (bytes32) {
        return owner.append(nonce, R.ProvisionalAssociation(0, 0));
    }

    function _requireFails(bytes32 manifest) private view {
        (bool ok,) =
            address(worker).staticcall(abi.encodeCall(worker.requireSelectionV2, (manifest)));
        require(!ok, "missing, incomplete or stale selection rejected");
    }

    function _continueFails(bytes32 key, uint64 count) private {
        (bool ok,) = address(worker).call(abi.encodeCall(worker.continueSelectionV2, (key, count)));
        require(!ok, "invalid continuation rejected");
    }

    function testEmptyHistoryNeedsExplicitCompletionAndDistinctV2Result() public {
        bytes32 manifest = owner.publish(new bytes32[](0));
        _requireFails(manifest);
        bytes32 key = worker.beginSelectionV2(manifest);
        _requireFails(manifest);
        _continueFails(key, 0);
        _continueFails(bytes32(uint256(999)), 1);
        S.Progress memory p = worker.continueSelectionV2(key, 1);
        require(p.complete && p.processed == 0 && p.selectedRecordHash == 0);
        require(
            !worker.retainedMemberV2(key, address(0)) && !worker.retainedMemberV2(key, address(101))
        );
        S.Result memory result = worker.requireSelectionV2(manifest);
        (V2.Basis memory basis,) = worker.selectionV2(key);
        require(
            key
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_SOURCE_V2"),
                        block.chainid,
                        address(2),
                        address(owner),
                        basis
                    )
                )
        );
        require(
            result.sourceKey == key && result.selectedRecordHash == 0
                && result.selectedDataHash == 0 && result.selectedNonce == 0
                && result.commitment
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_GUARDIAN_SELECTION_RESULT_V2"),
                            key,
                            basis,
                            p
                        )
                    )
        );
        require(worker.beginSelectionV2(manifest) == key);
    }

    function testHighestEligibleNonceExclusionsAndPermanentSupersession() public {
        bytes32 first = _append(20);
        bytes32 second = _append(90);
        bytes32 third = _append(80);
        _append(10);
        bytes32 transition = keccak256("early contested association");
        owner.append(100, R.ProvisionalAssociation(transition, 2));
        owner.setTransition(
            transition, R.TransitionState(owner.ARTIST(), transition, 1, 1, 1, 2, 1, 2)
        );
        owner.setSupersession(
            third, Sup.Status(owner.ARTIST(), keccak256("prior35"), keccak256("action"))
        );
        bytes32[] memory excluded = new bytes32[](1);
        excluded[0] = second;
        bytes32 manifest = owner.publish(excluded);
        bytes32 key = worker.beginSelectionV2(manifest);
        for (uint256 i; i < 5; ++i) {
            worker.continueSelectionV2(key, 1);
        }
        S.Result memory result = worker.requireSelectionV2(manifest);
        require(result.selectedRecordHash == first && result.selectedNonce == 20);
        require(result.selectedDataHash == keccak256(abi.encode(owner.guardianSetRecord(first))));
        (, S.Progress memory p) = worker.selectionV2(key);
        require(p.complete && p.excludedSeen == 1 && p.processed == 5);
    }

    function testEveryExcludedRecordMustAppearAndFailingFinalChunkRollsBack() public {
        _append(1);
        _append(2);
        bytes32[] memory excluded = new bytes32[](1);
        excluded[0] = bytes32(uint256(999));
        bytes32 manifest = owner.publish(excluded);
        bytes32 key = worker.beginSelectionV2(manifest);
        worker.continueSelectionV2(key, 1);
        (, S.Progress memory beforeFailure) = worker.selectionV2(key);
        _continueFails(key, 1);
        (, S.Progress memory afterFailure) = worker.selectionV2(key);
        require(keccak256(abi.encode(beforeFailure)) == keccak256(abi.encode(afterFailure)));
        _requireFails(manifest);
    }

    function testSourceChangeInvalidatesPartialAndCompleteResultsUntilExactRestore() public {
        _append(1);
        _append(2);
        bytes32 manifest = owner.publish(new bytes32[](0));
        bytes32 key = worker.beginSelectionV2(manifest);
        worker.continueSelectionV2(key, 1);
        bytes32 original = owner.sourceCommitment();
        owner.setSource(keccak256("changed native cause or ancestry generation"));
        _continueFails(key, 1);
        _requireFails(manifest);
        owner.setSource(original);
        worker.continueSelectionV2(key, 1);
        S.Result memory result = worker.requireSelectionV2(manifest);
        owner.setSource(keccak256("changed after completion"));
        _continueFails(key, 1);
        _requireFails(manifest);
        owner.setSource(original);
        require(worker.requireSelectionV2(manifest).commitment == result.commitment);
    }

    function testHistoryRecordAssociationAndStatusCorruptionRejectThenExactRetry() public {
        bytes32 transition = keccak256("saved association");
        bytes32 record = owner.append(1, R.ProvisionalAssociation(transition, 2));
        R.TransitionState memory t = R.TransitionState(owner.ARTIST(), transition, 1, 1, 1, 2, 1, 2);
        owner.setTransition(transition, t);
        bytes32 manifest = owner.publish(new bytes32[](0));
        bytes32 key = worker.beginSelectionV2(manifest);
        (H.Head memory h, H.Entry memory entry,,) =
            owner.guardianHistoryState(owner.ARTIST(), 1, address(0), 0);
        H.Entry memory savedEntry = abi.decode(abi.encode(entry), (H.Entry));
        entry.previousCommitment = keccak256("wrong history parent");
        owner.setEntry(1, entry);
        _continueFails(key, 1);
        owner.setEntry(1, savedEntry);
        R.GuardianRecord memory r = owner.guardianSetRecord(record);
        R.GuardianRecord memory savedRecord = abi.decode(abi.encode(r), (R.GuardianRecord));
        ++r.nonce;
        owner.setRecord(record, r);
        _continueFails(key, 1);
        owner.setRecord(record, savedRecord);
        t.postWindowEndsAt = 3;
        owner.setTransition(transition, t);
        _continueFails(key, 1);
        t.postWindowEndsAt = 2;
        owner.setTransition(transition, t);
        owner.setSupersession(record, Sup.Status(owner.ARTIST(), 0, 0));
        _continueFails(key, 1);
        owner.setSupersession(record, Sup.Status(0, 0, 0));
        owner.setHead(H.Head(0, 0, h.commitment));
        _continueFails(key, 1);
        owner.setHead(h);
        S.Progress memory p = worker.continueSelectionV2(key, 1);
        require(
            p.complete && p.selectedRecordHash == 0, "early contested guardian remains ineligible"
        );
        require(worker.requireSelectionV2(manifest).commitment != 0);
    }

    function testAll64ExclusionsAreSeenAndExplicitEmptyWinnerIsComplete() public {
        bytes32[] memory excluded = new bytes32[](64);
        for (uint256 i; i < 64; ++i) {
            excluded[i] = _append(i);
        }
        bytes32 manifest = owner.publish(excluded);
        bytes32 key = worker.beginSelectionV2(manifest);
        S.Progress memory p = worker.continueSelectionV2(key, 64);
        require(p.complete && p.excludedSeen == type(uint64).max && p.selectedRecordHash == 0);
        require(worker.requireSelectionV2(manifest).commitment != 0);
    }

    function testPublisherCodePinIsRecheckedAfterPreparationAndCompletion() public {
        bytes32 manifest = owner.publish(new bytes32[](0));
        bytes32 key = worker.beginSelectionV2(manifest);
        bytes32 original = owner.evidenceCodeHash();
        owner.setEvidenceCodeHash(keccak256("wrong immutable publisher pin"));
        _continueFails(key, 1);
        owner.setEvidenceCodeHash(original);
        worker.continueSelectionV2(key, 1);
        owner.setEvidenceCodeHash(0);
        _requireFails(manifest);
        owner.setEvidenceCodeHash(original);
        require(worker.requireSelectionV2(manifest).commitment != 0);
    }

    function testFrozenRetainedMembersOmitPriorSupersededAndCurrentExcludedOnlyActors() public {
        address[] memory members = new address[](2);
        members[0] = address(101);
        members[1] = address(105);
        bytes32 permanent = owner.appendMembers(10, R.ProvisionalAssociation(0, 0), members);
        members = new address[](1);
        members[0] = address(102);
        bytes32 excluded = owner.appendMembers(20, R.ProvisionalAssociation(0, 0), members);
        members = new address[](2);
        members[0] = address(103);
        members[1] = address(105);
        bytes32 abandoned = keccak256("abandoned executed association");
        owner.appendMembers(100, R.ProvisionalAssociation(abandoned, 2), members);
        owner.setTransition(
            abandoned, R.TransitionState(owner.ARTIST(), abandoned, 1, 1, 1, 2, 1, 2)
        );
        members = new address[](1);
        members[0] = address(104);
        bytes32 winner = owner.appendMembers(30, R.ProvisionalAssociation(0, 0), members);
        owner.setSupersession(
            permanent, Sup.Status(owner.ARTIST(), keccak256("prior35"), keccak256("prior action"))
        );
        bytes32[] memory exclusions = new bytes32[](1);
        exclusions[0] = excluded;
        bytes32 manifest = owner.publish(exclusions);
        bytes32 key = worker.beginSelectionV2(manifest);
        worker.continueSelectionV2(key, 3);
        (bool ok,) =
            address(worker).staticcall(abi.encodeCall(worker.retainedMemberV2, (key, address(103))));
        require(!ok, "partially scanned membership cannot be consumed");
        worker.continueSelectionV2(key, 1);
        require(worker.requireSelectionV2(manifest).selectedRecordHash == winner);
        require(
            !worker.retainedMemberV2(key, address(101)), "permanent exclusion never regains veto"
        );
        require(
            !worker.retainedMemberV2(key, address(102)),
            "current exclusion removes its only membership"
        );
        require(
            worker.retainedMemberV2(key, address(103)), "unselected abandoned record retains veto"
        );
        require(worker.retainedMemberV2(key, address(104)), "elected record retains veto");
        require(
            worker.retainedMemberV2(key, address(105)),
            "another retained admission preserves membership"
        );
        require(
            !worker.retainedMemberV2(key, address(0)) && !worker.retainedMemberV2(key, address(106))
        );
        owner.setSource(keccak256("later owner generation"));
        owner.setSupersession(permanent, Sup.Status(0, 0, 0));
        _requireFails(manifest);
        require(
            !worker.retainedMemberV2(key, address(101))
                && worker.retainedMemberV2(key, address(103)),
            "completed action cohort remains frozen after live owner facts change"
        );
        (ok,) = address(worker)
            .staticcall(
                abi.encodeCall(worker.retainedMemberV2, (bytes32(uint256(999)), address(103)))
            );
        require(!ok, "unknown source is not an empty prepared cohort");
    }
}
