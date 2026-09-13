// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistRecoveryApprovalState.sol";
import "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";

interface RecoveryApprovalVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function warp(uint256 time) external;
    function expectRevert(bytes calldata reason) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev State/owner-commit harness. Current authority and companion observations are fixture inputs.
contract RecoveryApprovalOwnerHarness is StreamArtistOwner {
    StreamArtistRecoveryApprovalState.State private _approvals;
    bool private _failTail;

    constructor()
        StreamArtistOwner(
            address(0x101),
            msg.sender,
            address(0x202),
            keccak256("domain:consent_finality"),
            address(0x303),
            address(0x404)
        )
    { }

    function setFailTail(bool value) external {
        _failTail = value;
    }

    function recordRecoveryApproval(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Recovery.ApprovalRecord calldata r,
        R.AuthorityFact calldata authority,
        Approval.Admission calldata admission
    ) external returns (bytes32) {
        _check(c, 22);
        StreamArtistRecoveryApprovalState.Mutation memory m =
            StreamArtistRecoveryApprovalState.recordEncoded(
                _approvals,
                _replay,
                StreamArtistRecoveryApprovalState.OwnerContext(
                    _environment(),
                    operationCoordinator,
                    archiveV2,
                    domainId,
                    _revision,
                    uint64(block.timestamp)
                ),
                msg.data
            );
        _commit(c, m.action, m.state, m.replay, m.record);
        require(!_failTail, "late append fixture");
        return m.record;
    }

    function saved(bytes32 hash)
        external
        view
        returns (Recovery.ApprovalRecord memory, Approval.Admission memory)
    {
        return abi.decode(
            StreamArtistRecoveryApprovalState.recordEncodedRead(_approvals, hash),
            (Recovery.ApprovalRecord, Approval.Admission)
        );
    }

    function selected(
        bytes32 artistId,
        uint64 generation,
        bytes32 bindingHash,
        Recovery.ApprovalTerms calldata terms
    ) external view returns (bytes32) {
        return _approvals.associationRecords[
            StreamArtistRecoveryApprovalState.associationKey(
                artistId, generation, bindingHash, terms
            )
        ];
    }
}

contract StreamArtistRecoveryApprovalStateTest {
    RecoveryApprovalVm private constant vm =
        RecoveryApprovalVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RecoveryApprovalOwnerHarness private owner;

    function setUp() public {
        vm.warp(1000);
        owner = new RecoveryApprovalOwnerHarness();
    }

    function _environment() private view returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(
            block.chainid, address(0x101), address(0x303), address(0x404)
        );
    }

    function _input() private view returns (StreamArtistRecoveryApprovalState.Input memory x) {
        x.binding_ = T.Binding(
            bytes32(uint256(1)),
            address(0x505),
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            1,
            1,
            1,
            0,
            address(0x606),
            true
        );
        x.authority = R.AuthorityFact(bytes32(uint256(1)), address(0x505), 1, 1);
        x.record.terms =
            Recovery.ApprovalTerms(address(0x707), 7, bytes32(uint256(4)), bytes32(uint256(5)));
        x.record.artistId = x.binding_.artistId;
        x.record.signer = x.authority.authorityAddress;
        x.record.authorityClass = 1;
        x.record.signedAt = 1000;
        x.record.deadline = 2000;
        x.record.bindingGeneration = 1;
        x.record.bindingHash = x.binding_.bindingHash;
        x.admission = Approval.Admission(
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0),
            address(0x808),
            bytes32(uint256(6)),
            bytes32(uint256(7)),
            IStreamArtistRecoveryIntent.Facts(
                bytes32(uint256(8)), bytes32(uint256(9)), bytes32(uint256(10)), bytes32(uint256(11))
            )
        );
        return _rehash(x);
    }

    function _rehash(StreamArtistRecoveryApprovalState.Input memory x)
        private
        view
        returns (StreamArtistRecoveryApprovalState.Input memory)
    {
        x.record.recordHash = StreamArtistRecoveryHashes.approvalRecord(_environment(), x.record);
        x.record.digest = StreamArtistRecoveryHashes.approvalDigest(
            _environment(), x.record.terms, x.record.nonce, x.record.deadline
        );
        return x;
    }

    function _context() private view returns (T.ActionContext memory) {
        return T.ActionContext(22, address(this), owner.ownerStateSnapshotV2());
    }

    function _record(StreamArtistRecoveryApprovalState.Input memory x) private returns (bytes32) {
        return
            owner.recordRecoveryApproval(_context(), x.binding_, x.record, x.authority, x.admission);
    }

    function _snapshot() private view returns (bytes32) {
        return keccak256(abi.encode(owner.ownerStateSnapshotV2()));
    }

    function _scope(StreamArtistRecoveryApprovalState.Input memory x)
        private
        pure
        returns (bytes32)
    {
        bytes32[8] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_RECOVERY_APPROVAL_KEY_V1");
        w[1] = x.record.artistId;
        w[2] = bytes32(uint256(x.record.bindingGeneration));
        w[3] = x.record.bindingHash;
        w[4] = bytes32(uint256(uint160(x.record.terms.finalityRegistry)));
        w[5] = bytes32(x.record.terms.collectionId);
        w[6] = x.record.terms.finalityRecordHash;
        w[7] = x.record.terms.recoveryManifestHash;
        return keccak256(abi.encode(w));
    }

    function _key(StreamArtistRecoveryApprovalState.Input memory x) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(0x101),
                address(this),
                address(0x202),
                address(owner),
                keccak256("domain:consent_finality"),
                keccak256("consent_finality.replay.recovery_approval_key"),
                _scope(x)
            )
        );
    }

    function _literalRecord(Recovery.ApprovalRecord memory r) private view returns (bytes32) {
        bytes32[12] memory w;
        w[0] = keccak256("6529STREAM_ARTIST_RECOVERY_APPROVAL_RECORD_V1");
        w[1] = bytes32(block.chainid);
        w[2] = bytes32(uint256(0x101));
        w[3] = bytes32(uint256(uint160(r.terms.finalityRegistry)));
        w[4] = bytes32(r.terms.collectionId);
        w[5] = r.terms.finalityRecordHash;
        w[6] = r.terms.recoveryManifestHash;
        w[7] = r.artistId;
        w[8] = bytes32(uint256(uint160(r.signer)));
        w[9] = bytes32(uint256(r.authorityClass));
        w[10] = bytes32(r.nonce);
        w[11] = bytes32(uint256(r.signedAt));
        return keccak256(abi.encode(w));
    }

    function testRecordExactPermanentEventReplayAndEncodedRead() public {
        StreamArtistRecoveryApprovalState.Input memory x = _input();
        T.Snapshot memory prior = owner.ownerStateSnapshotV2();
        vm.recordLogs();
        bytes32 hash = _record(x);
        RecoveryApprovalVm.Log[] memory logs = vm.getRecordedLogs();
        (Recovery.ApprovalRecord memory r, Approval.Admission memory a) = owner.saved(hash);
        require(hash == _literalRecord(r), "literal12");
        require(
            keccak256(abi.encode(r, a)) == keccak256(abi.encode(x.record, x.admission)),
            "exact saved tuple"
        );
        require(logs.length == 1 && logs[0].emitter == address(owner), "owner event");
        require(
            logs[0].topics[0]
                == keccak256(
                    "ArtistRecoveryApprovalRecorded(uint16,uint256,bytes32,address,bytes32,uint8,uint256,uint64,bytes32)"
                ),
            "topic"
        );
        require(
            logs[0].topics[1] == bytes32(uint256(7))
                && logs[0].topics[2] == r.terms.recoveryManifestHash
                && logs[0].topics[3] == bytes32(uint256(uint160(r.signer))),
            "indexed words"
        );
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(
                        uint16(1),
                        r.terms.finalityRecordHash,
                        r.authorityClass,
                        r.nonce,
                        r.signedAt,
                        hash
                    )
                ),
            "event words"
        );
        T.ReplayCell memory cell = owner.replayCell(_key(x));
        require(
            cell.commitment == hash && cell.touchedRevision == 1 && cell.kind == 1
                && cell.status == 2,
            "exact replay"
        );
        T.Snapshot memory after_ = owner.ownerStateSnapshotV2();
        require(
            after_.revision == prior.revision + 1 && after_.recordChainTip != prior.recordChainTip,
            "one primary commit"
        );
    }

    function testDuplicateAssociationRejectsFreshNonceAndManifestSeparates() public {
        StreamArtistRecoveryApprovalState.Input memory x = _input();
        bytes32 original = _record(x);
        bytes32 before_ = _snapshot();
        ++x.record.nonce;
        x = _rehash(x);
        T.ActionContext memory c = _context();
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, _key(x)));
        owner.recordRecoveryApproval(c, x.binding_, x.record, x.authority, x.admission);
        require(_snapshot() == before_, "duplicate rollback");
        x.record.terms.recoveryManifestHash = bytes32(uint256(99));
        x = _rehash(x);
        require(_record(x) != original, "distinct manifest");
    }

    function testAssociationLookupNeverShadowsEarlierEvidence() public {
        StreamArtistRecoveryApprovalState.Input memory first = _input();
        bytes32 firstHash = _record(first);
        StreamArtistRecoveryApprovalState.Input memory next = _input();
        next.binding_.generation = 2;
        next.binding_.bindingHash = bytes32(uint256(100));
        next.record.bindingGeneration = 2;
        next.record.bindingHash = next.binding_.bindingHash;
        next.record.nonce = 1;
        next = _rehash(next);
        bytes32 secondHash = _record(next);
        require(firstHash != secondHash, "fresh nonce record");
        require(
            owner.selected(first.record.artistId, 1, first.record.bindingHash, first.record.terms)
                == firstHash,
            "first fixed"
        );
        require(
            owner.selected(next.record.artistId, 2, next.record.bindingHash, next.record.terms)
                == secondHash,
            "exact second"
        );
        require(
            owner.selected(next.record.artistId, 3, next.record.bindingHash, next.record.terms)
                == 0,
            "no other association reuse"
        );
        // The fixture supplies a second association; this is no proof of adjudicated supersession.
    }

    function testRawHistoryNeedsNoCurrentSignerOrUnexpiredDeadline() public {
        StreamArtistRecoveryApprovalState.Input memory x = _input();
        bytes32 hash = _record(x);
        bytes32 before_ = _snapshot();
        vm.warp(3000);
        (Recovery.ApprovalRecord memory r, Approval.Admission memory a) = owner.saved(hash);
        require(
            keccak256(abi.encode(r, a)) == keccak256(abi.encode(x.record, x.admission)),
            "historical tuple fixed"
        );
        require(
            owner.selected(r.artistId, r.bindingGeneration, r.bindingHash, r.terms) == hash
                && _snapshot() == before_,
            "raw lookup only"
        );
        // Actual current-authority rotation/estate and companion consumption belong to ingress tests.
    }

    function testBadAdmissionDigestAuthorityAndLateFailureRollBack() public {
        StreamArtistRecoveryApprovalState.Input memory x = _input();
        bytes32 before_ = _snapshot();
        x.admission.scope.tokenId = 1;
        _reject(x, before_);
        x = _input();
        x.record.digest = bytes32(uint256(101));
        _reject(x, before_);
        x = _input();
        x.authority.authorityAddress = address(0x999);
        _reject(x, before_);
        x = _input();
        x.record.bindingGeneration = 2;
        _reject(x, before_);
        x = _input();
        owner.setFailTail(true);
        _reject(x, before_);
        require(owner.replayCell(_key(x)).status == 0, "replay rolled back");
        (Recovery.ApprovalRecord memory missing,) = owner.saved(x.record.recordHash);
        require(
            missing.recordHash == 0
                && owner.selected(x.record.artistId, 1, x.record.bindingHash, x.record.terms) == 0,
            "record and lookup rolled back"
        );
        owner.setFailTail(false);
        require(_record(x) == x.record.recordHash, "identical callback retry");
    }

    function _reject(StreamArtistRecoveryApprovalState.Input memory x, bytes32 before_) private {
        (bool ok,) = address(owner)
            .call(
                abi.encodeCall(
                    owner.recordRecoveryApproval,
                    (_context(), x.binding_, x.record, x.authority, x.admission)
                )
            );
        require(!ok && _snapshot() == before_, "negative state unchanged");
    }

    function testFuzzStaticRecordAndScopedAdmission(uint256 nonce, bytes32 manifest, uint8 scope)
        public
    {
        if (manifest == 0) manifest = bytes32(uint256(1));
        StreamArtistRecoveryApprovalState.Input memory x = _input();
        x.record.nonce = nonce;
        x.record.terms.recoveryManifestHash = manifest;
        x.admission.scope.scopeType = StreamFinalityScopeType(scope % 5);
        if (scope % 5 == 1) x.admission.scope.tokenId = 123;
        if (scope % 5 > 1) x.admission.scope.scopeId = bytes32(uint256(456));
        x = _rehash(x);
        require(_record(x) == _literalRecord(x.record), "literal scoped record");
    }
}
