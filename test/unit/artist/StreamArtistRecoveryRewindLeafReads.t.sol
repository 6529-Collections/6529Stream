// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindRevisionReads as RevisionReads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindRevisionReads.sol";
import {
    StreamArtistRecoveryRewindStandingReads as StandingReads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindStandingReads.sol";
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindRecordReads.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistIdentityRevisionTypes as Doc,
    IStreamArtistIdentityRevisionReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistIdentityOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistRotationReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistEstateOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistDormancyOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistHashes as H
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistRotationHashes as RH
} from "../../../smart-contracts/domains/artist/StreamArtistRotationHashes.sol";
import {
    StreamArtistRecoveryRewindAdmission as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindAdmission.sol";
import {
    StreamArtistRecoveryRewindContinuations as C
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindContinuations.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRuntimeReads.sol";

interface RewindLeafVm {
    function warp(uint256 timestamp) external;
}
error RewindLeafOwnerFailure(bytes32 callHash);
error RewindLeafWrongCaller(address caller);

/// @dev Original structs and seven private bodies from Records at
/// 611be306bac07cc264370ed3b27f906b0f14efd6, with typed public test entry points.
library RewindLeafFrozenOriginal {
    struct Source {
        bool imported;
        W.EnvironmentV3 original;
        Runtime.ReceiptFact occurrence;
    }

    struct Facts {
        W.SelectedRecordV3 selected;
        R.ProvisionalAssociation association;
        R.TransitionState transition;
        uint64 admissionRevision;
        uint8 authorityClass;
        bool eligible;
        bytes32 previousRecordHash;
        bytes32 previousValueHash;
        bytes32 valueHash;
        bytes32 pairedDirective;
        address account;
        bytes32 retirementHash;
        uint32 grantedCapabilities;
        uint32 forbiddenCapabilities;
        bool granted;
        bytes32 abandonmentHash;
    }

    function _revision(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 hash,
        bytes32 originalContinuation,
        Source memory source
    ) private view returns (Facts memory f) {
        Doc.Record memory r = IStreamArtistIdentityRevisionReads(e.identityOwner)
            .identityRevisionRecord(hash);
        bytes memory document = IStreamArtistIdentityRevisionReads(e.identityOwner)
            .identityDocumentBytes(r.revisedRecordHash);
        bool living = _revisionHash(source.original, r, 1) == hash;
        bool estate = _revisionHash(source.original, r, 3) == hash;
        if (
            r.recordHash != hash || r.artistId != artistId || r.signer == address(0)
                || r.signedAt == 0 || r.signedAt > block.timestamp || living == estate
                || (r.authorityClass != 1 && r.authorityClass != 3)
                || (living && r.authorityClass != 1) || r.previousRecordHash == 0
                || r.revisedRecordHash == r.previousRecordHash || document.length == 0
                || document.length > 8192 || keccak256(document) != r.revisedRecordHash
                || bytes(r.displayName).length == 0 || bytes(r.displayName).length > 256
                || bytes(r.identityRecordURI).length > 2048
        ) revert W.InvalidRecoveryRewindRecord(hash);
        _revisionParent(e, r);
        bytes32 digest = H.typed(
            A.hashes(source.original),
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistIdentityRevision(bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,uint256 nonce,uint64 signedAt)"
                    ),
                    artistId,
                    r.previousRecordHash,
                    r.revisedRecordHash,
                    r.nonce,
                    r.signedAt
                )
            )
        );
        T.ReplayCell memory n = _nonce(e, source, artistId, r.nonce, digest);
        bytes32 chainProof;
        if (source.imported) {
            Runtime.ReplayFact memory nonce = A.nonceAt(
                e, source.occurrence.position.point.environmentHash, artistId, r.nonce, digest
            );
            chainProof = C.revisionAt(e, r, originalContinuation, nonce, source.occurrence);
        } else {
            chainProof = C.revision(e, r, originalContinuation, n);
        }
        f.selected.originalDataHash = keccak256(abi.encode(r, document));
        f.selected.nonce = r.nonce;
        f.association = IStreamArtistRotationReads(e.identityOwner)
            .identityRevisionProvisionalAssociation(hash);
        f.admissionRevision = n.touchedRevision;
        f.authorityClass = living ? 1 : 3;
        f.previousRecordHash = r.previousRevisionRecord;
        f.previousValueHash = r.previousRecordHash;
        f.valueHash = r.revisedRecordHash;
        _association(e, source, artistId, r.signer, f);
        f.selected.admissionProof =
            keccak256(abi.encode(f.selected.admissionProof, n, chainProof, f.authorityClass));
    }

    function _revisionHash(W.EnvironmentV3 memory e, Doc.Record memory r, uint8 class_)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_RECORD_V1"),
                e.chainId,
                e.registry,
                r.artistId,
                r.previousRecordHash,
                r.revisedRecordHash,
                r.signer,
                class_,
                r.nonce,
                r.signedAt
            )
        );
    }

    function _revisionParent(W.EnvironmentV3 memory e, Doc.Record memory r) private view {
        if (r.previousRevisionRecord == 0) {
            if (
                IStreamArtistIdentityOwner(e.identityOwner).identity(r.artistId).identityRecordHash
                    != r.previousRecordHash
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        } else {
            Doc.Record memory p = IStreamArtistIdentityRevisionReads(e.identityOwner)
                .identityRevisionRecord(r.previousRevisionRecord);
            if (
                p.recordHash != r.previousRevisionRecord || p.artistId != r.artistId
                    || p.revisedRecordHash != r.previousRecordHash || p.recordHash == r.recordHash
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        }
    }

    function _nonce(
        W.EnvironmentV3 memory e,
        Source memory source,
        bytes32 artistId,
        uint256 nonce,
        bytes32 digest
    ) private view returns (T.ReplayCell memory) {
        if (!source.imported) return A.nonce(e, artistId, nonce, digest);
        Runtime.ReplayFact memory f =
            A.nonceAt(e, source.occurrence.position.point.environmentHash, artistId, nonce, digest);
        if (!Recovered.samePoint(f.admission.point, source.occurrence.position.point)) {
            revert W.InvalidRecoveryRewindRecord(source.occurrence.receipt.recordHash);
        }
        return f.cell;
    }

    function _association(
        W.EnvironmentV3 memory e,
        Source memory source,
        bytes32 artistId,
        address signer,
        Facts memory f
    ) private view {
        if (source.imported) {
            (f.transition, f.eligible, f.selected.admissionProof) = A.associationAt(
                e,
                artistId,
                f.association,
                signer,
                f.authorityClass,
                source.occurrence.position.point
            );
            return;
        }
        (f.transition, f.eligible, f.selected.admissionProof) = A.association(
            e, artistId, f.association, signer, f.authorityClass, f.admissionRevision
        );
    }

    function _standing(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 hash,
        Source memory source
    ) private view returns (Facts memory f) {
        R.StandingRecord memory r =
            IStreamArtistRotationReads(e.identityOwner).standingRevocationRecord(hash);
        if (
            r.recordHash != hash || r.terms.artistId != artistId || r.signer == address(0)
                || (r.authorityClass != 1 && r.authorityClass != 3) || r.signedAt == 0
                || r.signedAt > block.timestamp || r.terms.revokedAddress == address(0)
                || r.terms.retiredTransitionRecordHash == 0
                || RH.standingRecordForAuthority(
                        A.hashes(source.original),
                        r.terms,
                        r.signer,
                        r.authorityClass,
                        r.nonce,
                        r.signedAt
                    ) != hash
        ) revert W.InvalidRecoveryRewindRecord(hash);
        T.ReplayCell memory admitted;
        T.ReplayCell memory n;
        bytes32 admission;
        V.Snapshot memory v;
        R.TransitionState memory t;
        if (source.imported) {
            Runtime.ReplayFact memory admittedAt;
            (admittedAt, admission) = C.standingAt(e, r, source.occurrence);
            Runtime.Context memory clock = Runtime.load(e, 2);
            Runtime.ReplayFact memory nonce = Runtime.replay(
                clock,
                source.occurrence.position.point.environmentHash,
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(artistId, r.nonce))
            );
            if (
                nonce.cell.commitment == 0 || nonce.cell.status != 2 || nonce.cell.kind != 1
                    || !Recovered.samePoint(nonce.admission.point, admittedAt.admission.point)
            ) {
                revert W.InvalidRecoveryRewindRecord(hash);
            }
            Runtime.OriginFact memory vesting;
            (v, t, vesting) = A.vestingAt(e, artistId, r.terms.retiredTransitionRecordHash);
            if (!Runtime.before(clock, vesting.point, admittedAt.admission.point)) {
                revert W.InvalidRecoveryRewindRecord(hash);
            }
            admitted = admittedAt.cell;
            n = nonce.cell;
            admission = keccak256(abi.encode(admission, admittedAt, nonce, vesting));
        } else {
            (admitted, admission) = C.standing(e, r);
            // Original51 stores inclusion time rather than the signed authorization deadline.
            n = IStreamArtistOwner(e.identityOwner)
                .replayCell(
                    A.key(
                        e,
                        keccak256("identity_authority.replay.nonce_allocator"),
                        keccak256(abi.encode(artistId, r.nonce))
                    )
                );
            if (
                n.commitment == 0 || n.status != 2 || n.kind != 1
                    || n.touchedRevision != admitted.touchedRevision
            ) {
                revert W.InvalidRecoveryRewindRecord(hash);
            }
            (v, t) = A.vesting(e, artistId, r.terms.retiredTransitionRecordHash);
        }
        (address prior, bytes32 guardian, uint64 tail) = _standingTerms(e, v);
        if (
            prior != r.terms.revokedAddress || v.oldAddress != prior || tail < 30 days
                || uint256(t.postWindowEndsAt) + tail > r.signedAt
                || (!source.imported && admitted.touchedRevision <= v.ownerRevision)
        ) revert W.InvalidRecoveryRewindRecord(hash);
        // Later retirements and later compromise markers do not erase this original admission.
        // The selector resolves its exact retirement scope against the current standing inventory.
        f.selected.originalDataHash = keccak256(abi.encode(r));
        f.selected.nonce = r.nonce;
        f.selected.admissionProof = keccak256(abi.encode(admission, n, v, t, prior, guardian, tail));
        f.transition = t;
        f.admissionRevision = admitted.touchedRevision;
        f.authorityClass = r.authorityClass;
        f.eligible = true;
        f.account = r.terms.revokedAddress;
        f.retirementHash = r.terms.retiredTransitionRecordHash;
        f.valueHash = r.terms.reasonHash;
    }

    function _standingTerms(W.EnvironmentV3 memory e, V.Snapshot memory v)
        private
        view
        returns (address prior, bytes32 guardian, uint64 tail)
    {
        if (v.operationId == 32) {
            R.RotationRecord memory r =
                IStreamArtistRotationReads(e.identityOwner).rotationRecord(v.transitionRecordHash);
            if (r.recordHash != v.transitionRecordHash || r.terms.artistId != v.artistId) {
                revert W.InvalidRecoveryRewindRecord(v.transitionRecordHash);
            }
            return (r.terms.oldAddress, r.guardianSetRecordHash, r.standingTail);
        }
        if (v.operationId == 35) {
            return IStreamArtistIdentityRecoveryOwner(e.identityOwner)
                .recoveryTransitionStanding(v.transitionRecordHash);
        }
        if (v.operationId == 40) {
            return IStreamArtistEstateOwner(e.identityOwner)
                .estateTransitionStanding(v.transitionRecordHash);
        }
        if (v.operationId == 43) {
            return IStreamArtistDormancyOwner(e.identityOwner)
                .dormancyTransitionStanding(v.transitionRecordHash);
        }
        revert W.InvalidRecoveryRewindRecord(v.transitionRecordHash);
    }

    function revision(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 hash,
        bytes32 originalContinuation,
        Source memory source
    ) public view returns (Facts memory) {
        return _revision(e, artistId, hash, originalContinuation, source);
    }

    function standing(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 hash,
        Source memory source
    ) public view returns (Facts memory) {
        return _standing(e, artistId, hash, source);
    }
}

contract RewindLeafComparisonHost {
    function revision(
        bool original,
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 hash,
        Records.Source memory source
    ) external view returns (bytes memory) {
        if (original) {
            return abi.encode(
                RewindLeafFrozenOriginal.revision(
                    e,
                    artistId,
                    hash,
                    0,
                    RewindLeafFrozenOriginal.Source(
                        source.imported, source.original, source.occurrence
                    )
                )
            );
        }
        return abi.encode(RevisionReads.revision(e, artistId, hash, 0, source));
    }

    function standing(
        bool original,
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 hash,
        Records.Source memory source
    ) external view returns (bytes memory) {
        if (original) {
            return abi.encode(
                RewindLeafFrozenOriginal.standing(
                    e,
                    artistId,
                    hash,
                    RewindLeafFrozenOriginal.Source(
                        source.imported, source.original, source.occurrence
                    )
                )
            );
        }
        return abi.encode(StandingReads.standing(e, artistId, hash, source));
    }
}

/// @dev Explicit typed owner boundary; records/replay cells are synthetic test data.
/// Every read checks the same host caller. No signatures or retained provenance are fabricated.
contract RewindLeafOwnerProbe {
    address private _host;
    bytes32 private _failure;
    mapping(bytes32 => Doc.Record) private _revisions;
    mapping(bytes32 => bytes) private _documents;
    mapping(bytes32 => T.ReplayCell) private _cells;
    T.Identity private _identity;
    R.ProvisionalAssociation private _association;
    R.TransitionState private _transition;
    V.Snapshot private _vesting;
    R.StandingRecord private _standing;
    R.RotationRecord private _rotation;
    address private _prior;
    bytes32 private _guardian;
    uint64 private _tail;

    function setHost(address host) external {
        _host = host;
    }

    function setFailure(bytes32 callHash) external {
        _failure = callHash;
    }

    function setRevision(bytes32 key, Doc.Record calldata value) external {
        _revisions[key] = value;
    }

    function setDocument(bytes32 key, bytes calldata value) external {
        _documents[key] = value;
    }

    function setCell(bytes32 key, T.ReplayCell calldata value) external {
        _cells[key] = value;
    }

    function setIdentity(bytes32 document) external {
        _identity.identityRecordHash = document;
    }

    function setAssociation(R.ProvisionalAssociation calldata value) external {
        _association = value;
    }

    function setVesting(V.Snapshot calldata v, R.TransitionState calldata t) external {
        _vesting = v;
        _transition = t;
    }

    function setStanding(R.StandingRecord calldata r) external {
        _standing = r;
    }

    function setRotation(R.RotationRecord calldata r) external {
        _rotation = r;
    }

    function setTerms(address prior, bytes32 guardian, uint64 tail) external {
        _prior = prior;
        _guardian = guardian;
        _tail = tail;
    }

    function identityRevisionRecord(bytes32 hash) external view returns (Doc.Record memory) {
        _probe();
        return _revisions[hash];
    }

    function identityDocumentBytes(bytes32 hash) external view returns (bytes memory) {
        _probe();
        return _documents[hash];
    }

    function identity(bytes32) external view returns (T.Identity memory) {
        _probe();
        return _identity;
    }

    function replayCell(bytes32 key) external view returns (T.ReplayCell memory) {
        _probe();
        return _cells[key];
    }

    function ownerStateSnapshotV2() external view returns (T.Snapshot memory) {
        _probe();
        return T.Snapshot(bytes32(uint256(1)), 20, bytes32(uint256(2)), bytes32(uint256(3)));
    }

    function identityRevisionRecoveryContinuationV3(bytes32) external view returns (bytes32) {
        _probe();
        return 0;
    }

    function identityRevisionProvisionalAssociation(bytes32)
        external
        view
        returns (R.ProvisionalAssociation memory)
    {
        _probe();
        return _association;
    }

    function guardianVestingSnapshot(bytes32, bytes32) external view returns (V.Snapshot memory) {
        _probe();
        return _vesting;
    }

    function artistTransitionState(bytes32) external view returns (R.TransitionState memory) {
        _probe();
        return _transition;
    }

    function identityTransitionClosure(bytes32, bytes32)
        external
        view
        returns (D.Closure memory empty)
    {
        _probe();
        return empty;
    }

    function standingRevocationRecord(bytes32) external view returns (R.StandingRecord memory) {
        _probe();
        return _standing;
    }

    function standingRevocationRecoveryContinuationV3(bytes32) external view returns (bytes32) {
        _probe();
        return 0;
    }

    function rotationRecord(bytes32) external view returns (R.RotationRecord memory) {
        _probe();
        return _rotation;
    }

    function recoveryTransitionStanding(bytes32) external view returns (address, bytes32, uint64) {
        _probe();
        return (_prior, _guardian, _tail);
    }

    function estateTransitionStanding(bytes32) external view returns (address, bytes32, uint64) {
        _probe();
        return (_prior, _guardian, _tail);
    }

    function dormancyTransitionStanding(bytes32) external view returns (address, bytes32, uint64) {
        _probe();
        return (_prior, _guardian, _tail);
    }

    /// @dev The deliberately unavailable imported-runtime suite is an explicit refusal
    /// boundary, never a synthetic successful retained-history certificate.
    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        _probe();
        revert RewindLeafOwnerFailure(keccak256(msg.data));
    }

    function _probe() private view {
        if (msg.sender != _host) revert RewindLeafWrongCaller(msg.sender);
        if (keccak256(msg.data) == _failure) revert RewindLeafOwnerFailure(_failure);
    }
}

/// @notice Leaf-byte/proof and refusal parity only. The actual Admission and Continuation
/// dependencies execute against typed synthetic owner reads; original journal admission,
/// successful imported provenance and end-to-end Artist execution are outside this fixture.
contract StreamArtistRecoveryRewindLeafReadsTest {
    RewindLeafVm private constant vm =
        RewindLeafVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = bytes32(uint256(77));
    bytes32 private constant RETIREMENT = bytes32(uint256(88));
    bytes32 private constant NONCE_SURFACE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant REVISION_SURFACE =
        keccak256("identity_authority.replay.identity_revision_chain");
    bytes32 private constant STANDING_SURFACE =
        keccak256("identity_authority.replay.standing_revocation_key");
    RewindLeafComparisonHost private host;
    RewindLeafOwnerProbe private owner;

    struct RevisionFixture {
        W.EnvironmentV3 environment;
        Records.Source source;
        Doc.Record record;
        bytes document;
        R.ProvisionalAssociation association;
        V.Snapshot vesting;
        R.TransitionState transition;
        T.ReplayCell nonce;
        T.ReplayCell admitted;
        bytes32 nonceKey;
        bytes32 chainKey;
        uint8 effectiveClass;
    }

    struct StandingFixture {
        W.EnvironmentV3 environment;
        Records.Source source;
        R.StandingRecord record;
        V.Snapshot vesting;
        R.TransitionState transition;
        T.ReplayCell nonce;
        T.ReplayCell admitted;
        bytes32 nonceKey;
        bytes32 admissionKey;
        address prior;
        bytes32 guardian;
        uint64 tail;
    }

    function setUp() public {
        vm.warp(40 days);
        host = new RewindLeafComparisonHost();
        owner = new RewindLeafOwnerProbe();
        owner.setHost(address(host));
    }

    function testNativeRevisionLivingEstateAndLegacyStoredClassOneHaveExactFacts() public {
        _goodRevision(_revisionFixture(1, 1, false, false));
        _goodRevision(_revisionFixture(3, 3, false, false));
        // The original25 estate hash may retain literal1 in the stored record.
        // The leaf must preserve the bytes and derive class3 from the original hash.
        _goodRevision(_revisionFixture(3, 1, false, false));
    }

    function testRevisionParentAndNonzeroAssociationOutputsSurviveMemoryMutation() public {
        RevisionFixture memory f = _revisionFixture(3, 1, true, true);
        require(
            f.association.transitionRecordHash != 0 && f.transition.recordHash != 0,
            "nondefault association fixture"
        );
        _goodRevision(f);
        f.transition.contestedAt = 80;
        owner.setVesting(f.vesting, f.transition);
        _goodRevision(f);
    }

    function testRevisionMalformedRecordAndDocumentBoundsPreserveExactRefusals() public {
        for (uint256 variant; variant < 14; ++variant) {
            RevisionFixture memory f = _revisionFixture(1, 1, false, false);
            Doc.Record memory bad = _copyRevision(f.record);
            if (variant == 0) bad.recordHash = 0;
            if (variant == 1) bad.artistId = bytes32(uint256(999));
            if (variant == 2) bad.signer = address(0);
            if (variant == 3) bad.signedAt = 0;
            if (variant == 4) bad.authorityClass = 4;
            if (variant == 5) bad.authorityClass = 3;
            if (variant == 6) bad.previousRecordHash = 0;
            if (variant == 7) owner.setDocument(f.record.revisedRecordHash, hex"");
            if (variant == 8) owner.setDocument(f.record.revisedRecordHash, hex"deadbeef");
            if (variant == 9) owner.setDocument(f.record.revisedRecordHash, new bytes(8193));
            if (variant == 10) bad.displayName = "";
            if (variant == 11) bad.displayName = string(new bytes(257));
            if (variant == 12) bad.identityRecordURI = string(new bytes(2049));
            if (variant == 13) bad.revisedRecordHash = bad.previousRecordHash;
            owner.setRevision(f.record.recordHash, bad);
            _badRevision(f, _recordError(f.record.recordHash));
            owner.setRevision(f.record.recordHash, f.record);
            owner.setDocument(f.record.revisedRecordHash, f.document);
            _goodRevision(f);
        }
    }

    function testRevisionParentNonceChainAndAssociationGuardsRejectAndRetry() public {
        for (uint256 variant; variant < 5; ++variant) {
            RevisionFixture memory f = _revisionFixture(1, 1, variant == 1, false);
            bytes memory expected = _recordError(f.record.recordHash);
            if (variant == 0) owner.setIdentity(bytes32(uint256(999)));
            if (variant == 1) {
                Doc.Record memory bad;
                bad.recordHash = f.record.previousRevisionRecord;
                bad.artistId = bytes32(uint256(999));
                bad.revisedRecordHash = f.record.previousRecordHash;
                owner.setRevision(bad.recordHash, bad);
            }
            if (variant == 2) {
                T.ReplayCell memory bad = _copyCell(f.nonce);
                bad.commitment = 0;
                owner.setCell(f.nonceKey, bad);
                expected =
                    abi.encodeWithSelector(A.InvalidRewindRecord.selector, f.nonce.commitment);
            }
            if (variant == 3) {
                T.ReplayCell memory bad = _copyCell(f.admitted);
                bad.touchedRevision = 11;
                owner.setCell(f.chainKey, bad);
            }
            if (variant == 4) {
                owner.setAssociation(R.ProvisionalAssociation(0, 1));
                expected = abi.encodeWithSelector(A.InvalidRewindRecord.selector, bytes32(0));
            }
            _badRevision(f, expected);
            _goodRevision(_revisionFixture(1, 1, variant == 1, false));
        }
    }

    function testRevisionDocumentParentNonceAndContinuationReadOrderIsUnchanged() public {
        for (uint256 stage; stage < 5; ++stage) {
            RevisionFixture memory f = _revisionFixture(1, 1, false, false);
            bytes memory input;
            if (stage == 0) {
                input = abi.encodeCall(owner.identityDocumentBytes, (f.record.revisedRecordHash));
                Doc.Record memory bad = _copyRevision(f.record);
                bad.recordHash = 0;
                owner.setRevision(f.record.recordHash, bad);
            }
            if (stage == 1) {
                input = abi.encodeCall(owner.identity, (ARTIST));
                T.ReplayCell memory bad;
                owner.setCell(f.nonceKey, bad);
            }
            if (stage == 2) input = abi.encodeCall(owner.replayCell, (f.nonceKey));
            if (stage == 3) {
                input = abi.encodeCall(
                    owner.identityRevisionRecoveryContinuationV3, (f.record.recordHash)
                );
                owner.setAssociation(R.ProvisionalAssociation(0, 1));
            }
            if (stage == 4) {
                input = abi.encodeCall(
                    owner.identityRevisionProvisionalAssociation, (f.record.recordHash)
                );
            }
            owner.setFailure(keccak256(input));
            _badRevision(f, _ownerError(input));
        }
    }

    function testNativeStandingAllFourRetirementFamiliesHaveExactAdmissionProof() public {
        uint16[4] memory operations = [uint16(32), uint16(35), uint16(40), uint16(43)];
        for (uint256 i; i < operations.length; ++i) {
            _goodStanding(_standingFixture(operations[i]));
        }
    }

    function testStandingRecordAndNonceRefusalsPreserveOriginalErrors() public {
        for (uint256 variant; variant < 8; ++variant) {
            StandingFixture memory f = _standingFixture(35);
            R.StandingRecord memory bad = _copyStanding(f.record);
            if (variant == 0) bad.recordHash = 0;
            if (variant == 1) bad.signer = address(0);
            if (variant == 2) bad.signedAt = uint64(block.timestamp + 1);
            if (variant == 3) bad.terms.revokedAddress = address(0);
            if (variant < 4) {
                owner.setStanding(bad);
            } else {
                T.ReplayCell memory n = _copyCell(f.nonce);
                if (variant == 4) n.commitment = 0;
                if (variant == 5) n.status = 1;
                if (variant == 6) n.kind = 2;
                if (variant == 7) n.touchedRevision = 11;
                owner.setCell(f.nonceKey, n);
            }
            _badStanding(f, _recordError(f.record.recordHash));
            owner.setStanding(f.record);
            owner.setCell(f.nonceKey, f.nonce);
            _goodStanding(f);
        }
    }

    function testStandingTermsTailTimeRevisionAndRotationBindingRefusals() public {
        for (uint256 variant; variant < 6; ++variant) {
            StandingFixture memory f = _standingFixture(variant >= 4 ? 32 : 35);
            bytes32 badRecord = f.record.recordHash;
            if (variant == 0) owner.setTerms(address(0xBAD), f.guardian, f.tail);
            if (variant == 1) owner.setTerms(f.prior, f.guardian, 29 days);
            if (variant == 2) {
                f.record.signedAt = 30 days + 99;
                f.record.recordHash = _standingHash(f.environment, f.record);
                f.admitted.commitment = f.record.recordHash;
                badRecord = f.record.recordHash;
                owner.setStanding(f.record);
                owner.setCell(f.admissionKey, f.admitted);
            }
            if (variant == 3) {
                T.ReplayCell memory admitted = _copyCell(f.admitted);
                T.ReplayCell memory nonce = _copyCell(f.nonce);
                admitted.touchedRevision = 5;
                nonce.touchedRevision = 5;
                owner.setCell(f.admissionKey, admitted);
                owner.setCell(f.nonceKey, nonce);
            }
            if (variant >= 4) {
                R.RotationRecord memory bad;
                bad.recordHash = variant == 4 ? bytes32(uint256(999)) : RETIREMENT;
                bad.terms.artistId = variant == 4 ? ARTIST : bytes32(uint256(999));
                owner.setRotation(bad);
                badRecord = RETIREMENT;
            }
            _badStanding(f, _recordError(badRecord));
            _goodStanding(_standingFixture(variant >= 4 ? 32 : 35));
        }
    }

    function testStandingOrderedOwnerFailuresAndCallerContextArePreserved() public {
        for (uint256 stage; stage < 4; ++stage) {
            StandingFixture memory f = _standingFixture(35);
            bytes memory input;
            if (stage == 0) {
                input = abi.encodeCall(
                    owner.standingRevocationRecoveryContinuationV3, (f.record.recordHash)
                );
            }
            if (stage == 1) input = abi.encodeCall(owner.replayCell, (f.nonceKey));
            if (stage == 2) {
                input = abi.encodeCall(owner.guardianVestingSnapshot, (ARTIST, RETIREMENT));
            }
            if (stage == 3) input = abi.encodeCall(owner.recoveryTransitionStanding, (RETIREMENT));
            owner.setFailure(keccak256(input));
            _badStanding(f, _ownerError(input));
        }
        StandingFixture memory healthy = _standingFixture(43);
        _goodStanding(healthy);
        (bool ok, bytes memory error) = address(owner)
            .staticcall(abi.encodeCall(owner.standingRevocationRecord, (healthy.record.recordHash)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(RewindLeafWrongCaller.selector, address(this))
                    ),
            "caller-sensitive owner probe active"
        );
    }

    function testImportedRoutesFailAtOriginalRuntimeSuiteBoundaryWithoutNativeFallback() public {
        bytes memory suite = abi.encodeCall(owner.suiteConfiguration, ());
        RevisionFixture memory revision = _revisionFixture(3, 1, false, false);
        revision.source.imported = true;
        owner.setIdentity(bytes32(uint256(999)));
        _badRevision(revision, _recordError(revision.record.recordHash));
        owner.setIdentity(revision.record.previousRecordHash);
        _badRevision(revision, _ownerError(suite));
        StandingFixture memory standing = _standingFixture(35);
        standing.source.imported = true;
        // A native-only continuation failure would win if the imported flag were lost.
        owner.setFailure(
            keccak256(
                abi.encodeCall(
                    owner.standingRevocationRecoveryContinuationV3, (standing.record.recordHash)
                )
            )
        );
        _badStanding(standing, _ownerError(suite));
    }

    // Memory struct assignment aliases its source. Mutation cases need independent
    // tuples so the expected error key and subsequent healthy retry stay original.
    function _copyCell(T.ReplayCell memory c) private pure returns (T.ReplayCell memory) {
        return T.ReplayCell(c.commitment, c.touchedRevision, c.kind, c.status);
    }

    function _copyRevision(Doc.Record memory r) private pure returns (Doc.Record memory) {
        return Doc.Record(
            r.recordHash,
            r.artistId,
            r.previousRecordHash,
            r.revisedRecordHash,
            r.previousRevisionRecord,
            r.signer,
            r.authorityClass,
            r.nonce,
            r.signedAt,
            r.identityRecordURI,
            r.displayName
        );
    }

    function _copyStanding(R.StandingRecord memory r)
        private
        pure
        returns (R.StandingRecord memory)
    {
        return R.StandingRecord(
            r.recordHash,
            R.StandingRevocation(
                r.terms.artistId,
                r.terms.revokedAddress,
                r.terms.reasonHash,
                r.terms.retiredTransitionRecordHash
            ),
            r.signer,
            r.authorityClass,
            r.nonce,
            r.signedAt
        );
    }

    function _revisionFixture(
        uint8 effectiveClass,
        uint8 storedClass,
        bool parent,
        bool provisional
    ) private returns (RevisionFixture memory f) {
        owner.setFailure(0);
        f.environment = _environment();
        f.source.original = f.environment;
        f.effectiveClass = effectiveClass;
        f.document = hex"00112233445566778899aabbccddeeff102030405060708090a0b0c0d0e0f0";
        f.record = Doc.Record({
            recordHash: 0,
            artistId: ARTIST,
            previousRecordHash: bytes32(uint256(101)),
            revisedRecordHash: keccak256(f.document),
            previousRevisionRecord: parent ? bytes32(uint256(102)) : bytes32(0),
            signer: address(0xBEEF),
            authorityClass: storedClass,
            nonce: 17,
            signedAt: 30 days + 101,
            identityRecordURI: "ipfs://original-revision-document-with-a-distinct-long-uri",
            displayName: "original display name crossing a single word"
        });
        f.record.recordHash = _revisionHash(f.environment, f.record, effectiveClass);
        owner.setRevision(f.record.recordHash, f.record);
        owner.setDocument(f.record.revisedRecordHash, f.document);
        owner.setIdentity(f.record.previousRecordHash);
        if (parent) {
            Doc.Record memory p;
            p.recordHash = f.record.previousRevisionRecord;
            p.artistId = ARTIST;
            p.revisedRecordHash = f.record.previousRecordHash;
            owner.setRevision(p.recordHash, p);
        }
        f.nonce = T.ReplayCell(_revisionDigest(f.environment, f.record), 12, 1, 2);
        f.admitted = T.ReplayCell(f.record.recordHash, 12, 1, 2);
        f.nonceKey =
            _key(f.environment, NONCE_SURFACE, keccak256(abi.encode(ARTIST, f.record.nonce)));
        f.chainKey = _key(
            f.environment,
            REVISION_SURFACE,
            keccak256(
                abi.encode(ARTIST, f.record.previousRevisionRecord, f.record.previousRecordHash)
            )
        );
        owner.setCell(f.nonceKey, f.nonce);
        owner.setCell(f.chainKey, f.admitted);
        if (provisional) {
            (f.vesting, f.transition) =
                _vesting(f.environment, effectiveClass == 3 ? 40 : 32, effectiveClass);
            f.association = R.ProvisionalAssociation(RETIREMENT, f.transition.postWindowEndsAt);
            owner.setVesting(f.vesting, f.transition);
        }
        owner.setAssociation(f.association);
    }

    function _standingFixture(uint16 operation) private returns (StandingFixture memory f) {
        owner.setFailure(0);
        f.environment = _environment();
        f.source.original = f.environment;
        uint8 class_ = operation == 40 ? 3 : 1;
        (f.vesting, f.transition) = _vesting(f.environment, operation, class_);
        f.prior = f.vesting.oldAddress;
        f.guardian = bytes32(uint256(201));
        f.tail = 30 days;
        f.record = R.StandingRecord(
            0,
            R.StandingRevocation(ARTIST, f.prior, bytes32(uint256(202)), RETIREMENT),
            address(0xBEEF),
            class_,
            19,
            30 days + 101
        );
        f.record.recordHash = _standingHash(f.environment, f.record);
        f.nonce = T.ReplayCell(bytes32(uint256(203)), 12, 1, 2);
        f.admitted = T.ReplayCell(f.record.recordHash, 12, 1, 2);
        f.nonceKey =
            _key(f.environment, NONCE_SURFACE, keccak256(abi.encode(ARTIST, f.record.nonce)));
        f.admissionKey = _key(
            f.environment, STANDING_SURFACE, keccak256(abi.encode(ARTIST, f.prior, RETIREMENT))
        );
        owner.setStanding(f.record);
        owner.setCell(f.nonceKey, f.nonce);
        owner.setCell(f.admissionKey, f.admitted);
        owner.setVesting(f.vesting, f.transition);
        owner.setTerms(f.prior, f.guardian, f.tail);
        R.RotationRecord memory rotation;
        rotation.recordHash = RETIREMENT;
        rotation.terms.artistId = ARTIST;
        rotation.terms.oldAddress = f.prior;
        rotation.guardianSetRecordHash = f.guardian;
        rotation.standingTail = f.tail;
        owner.setRotation(rotation);
    }

    function _vesting(W.EnvironmentV3 memory e, uint16 operation, uint8 class_)
        private
        pure
        returns (V.Snapshot memory v, R.TransitionState memory t)
    {
        v = V.Snapshot(
            ARTIST,
            RETIREMENT,
            operation,
            5,
            50,
            address(0xCAFE),
            address(0xBEEF),
            class_,
            GH.Head(3, 2, bytes32(uint256(301))),
            0,
            0,
            0
        );
        v.commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                e.chainId,
                e.registry,
                e.identityOwner,
                v.artistId,
                v.transitionRecordHash,
                v.operationId,
                v.ownerRevision,
                v.executedAt,
                v.oldAddress,
                v.newAddress,
                v.authorityClass,
                v.guardians,
                v.previousTransitionRecordHash,
                v.previousCommitment
            )
        );
        t = R.TransitionState(ARTIST, RETIREMENT, 10, 40, 50, 100, 0, 2);
    }

    function _expectedRevision(RevisionFixture memory f)
        private
        pure
        returns (Records.Facts memory expected)
    {
        expected.selected.originalDataHash = keccak256(abi.encode(f.record, f.document));
        expected.selected.nonce = f.record.nonce;
        expected.association = f.association;
        expected.transition = f.transition;
        expected.admissionRevision = 12;
        expected.authorityClass = f.effectiveClass;
        expected.previousRecordHash = f.record.previousRevisionRecord;
        expected.previousValueHash = f.record.previousRecordHash;
        expected.valueHash = f.record.revisedRecordHash;
        expected.eligible = f.transition.contestedAt == 0;
        bytes32 association = keccak256(abi.encode(f.association));
        if (f.association.transitionRecordHash != 0) {
            D.Closure memory closure;
            association =
                keccak256(abi.encode(f.association, f.vesting, f.transition, closure, bytes32(0)));
        }
        bytes32 chain = keccak256(
            abi.encode(
                bytes32(0),
                REVISION_SURFACE,
                keccak256(
                    abi.encode(ARTIST, f.record.previousRevisionRecord, f.record.previousRecordHash)
                ),
                f.admitted
            )
        );
        expected.selected.admissionProof =
            keccak256(abi.encode(association, f.nonce, chain, f.effectiveClass));
        // selected.recordHash/nativeIndex are filled by the unchanged outer Records reader.
    }

    function _expectedStanding(StandingFixture memory f)
        private
        pure
        returns (Records.Facts memory expected)
    {
        expected.selected.originalDataHash = keccak256(abi.encode(f.record));
        expected.selected.nonce = f.record.nonce;
        bytes32 admission = keccak256(
            abi.encode(
                bytes32(0),
                STANDING_SURFACE,
                keccak256(abi.encode(ARTIST, f.prior, RETIREMENT)),
                f.admitted
            )
        );
        expected.selected.admissionProof = keccak256(
            abi.encode(admission, f.nonce, f.vesting, f.transition, f.prior, f.guardian, f.tail)
        );
        expected.transition = f.transition;
        expected.admissionRevision = 12;
        expected.authorityClass = f.record.authorityClass;
        expected.eligible = true;
        expected.account = f.prior;
        expected.retirementHash = RETIREMENT;
        expected.valueHash = f.record.terms.reasonHash;
    }

    function _parity(
        bool revision,
        W.EnvironmentV3 memory e,
        bytes32 hash,
        Records.Source memory source,
        bool expectedOK,
        bytes memory expected
    ) private view {
        bytes memory actualCall = revision
            ? abi.encodeCall(host.revision, (false, e, ARTIST, hash, source))
            : abi.encodeCall(host.standing, (false, e, ARTIST, hash, source));
        bytes memory originalCall = revision
            ? abi.encodeCall(host.revision, (true, e, ARTIST, hash, source))
            : abi.encodeCall(host.standing, (true, e, ARTIST, hash, source));
        (bool actualOK, bytes memory actual) = address(host).staticcall(actualCall);
        (bool originalOK, bytes memory original) = address(host).staticcall(originalCall);
        require(actualOK == expectedOK && originalOK == expectedOK, "original leaf status");
        require(keccak256(actual) == keccak256(original), "complete Facts or raw error parity");
        require(keccak256(actual) == keccak256(expected), "independent leaf oracle");
    }

    function _goodRevision(RevisionFixture memory f) private view {
        _parity(
            true,
            f.environment,
            f.record.recordHash,
            f.source,
            true,
            abi.encode(abi.encode(_expectedRevision(f)))
        );
    }

    function _goodStanding(StandingFixture memory f) private view {
        _parity(
            false,
            f.environment,
            f.record.recordHash,
            f.source,
            true,
            abi.encode(abi.encode(_expectedStanding(f)))
        );
    }

    function _badRevision(RevisionFixture memory f, bytes memory error) private view {
        _parity(true, f.environment, f.record.recordHash, f.source, false, error);
    }

    function _badStanding(StandingFixture memory f, bytes memory error) private view {
        _parity(false, f.environment, f.record.recordHash, f.source, false, error);
    }

    function _recordError(bytes32 hash) private pure returns (bytes memory) {
        return abi.encodeWithSelector(W.InvalidRecoveryRewindRecord.selector, hash);
    }

    function _ownerError(bytes memory input) private pure returns (bytes memory) {
        return abi.encodeWithSelector(RewindLeafOwnerFailure.selector, keccak256(input));
    }

    function _environment() private view returns (W.EnvironmentV3 memory) {
        return W.EnvironmentV3(
            block.chainid,
            address(0x401),
            address(owner),
            address(owner).codehash,
            address(host),
            address(host).codehash,
            address(owner),
            address(0x402),
            address(0x403),
            address(0x404)
        );
    }

    function _key(W.EnvironmentV3 memory e, bytes32 surface, bytes32 scope)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                e.coordinator,
                e.archive,
                e.identityOwner,
                keccak256("domain:identity_authority"),
                surface,
                scope
            )
        );
    }

    function _revisionHash(W.EnvironmentV3 memory e, Doc.Record memory r, uint8 class_)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_RECORD_V1"),
                e.chainId,
                e.registry,
                r.artistId,
                r.previousRecordHash,
                r.revisedRecordHash,
                r.signer,
                class_,
                r.nonce,
                r.signedAt
            )
        );
    }

    function _revisionDigest(W.EnvironmentV3 memory e, Doc.Record memory r)
        private
        pure
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                e.chainId,
                e.registry
            )
        );
        bytes32 fields = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistIdentityRevision(bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,uint256 nonce,uint64 signedAt)"
                ),
                ARTIST,
                r.previousRecordHash,
                r.revisedRecordHash,
                r.nonce,
                r.signedAt
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, fields));
    }

    function _standingHash(W.EnvironmentV3 memory e, R.StandingRecord memory r)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                bytes32(0xc62769083037c111cec5a5f8d100e5c4064db79bec694312e35e53acc7256d0e),
                e.chainId,
                e.registry,
                r.terms.artistId,
                r.terms.revokedAddress,
                r.terms.retiredTransitionRecordHash,
                r.signer,
                r.authorityClass,
                r.terms.reasonHash,
                r.nonce,
                r.signedAt
            )
        );
    }
}
