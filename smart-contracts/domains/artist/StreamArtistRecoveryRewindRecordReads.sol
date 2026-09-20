// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveryRewindPayoutReads } from "./StreamArtistRecoveryRewindPayoutReads.sol";

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistSuccessionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as N
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistSuccessionReads
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    IStreamArtistIdentityRevisionReads,
    StreamArtistIdentityRevisionTypes as Doc
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistStewardSanctionGrant as Grant
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    IStreamArtistPayoutOwner
} from "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    IStreamArtistPayoutTransitionOwner
} from "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import {
    IStreamArtistPayoutResolutionOwner
} from "../../interfaces/stream/artist/IStreamArtistPayoutResolutionOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryRewindEvidence
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistDormancyOwner
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";
import { StreamArtistSuccessionHashes as SH } from "./StreamArtistSuccessionHashes.sol";
import { StreamArtistRotationHashes as RH } from "./StreamArtistRotationHashes.sol";
import {
    StreamArtistRecoveryRewindAdmission as A
} from "./StreamArtistRecoveryRewindAdmission.sol";
import {
    StreamArtistRecoveryRewindContinuations as C
} from "./StreamArtistRecoveryRewindContinuations.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";

/// @notice Original six-family admission facts read only from fixed semantic owners.
/// @dev Complete journal traversal, exclusion policy and selected-branch decisions belong to the
/// fixed selector. No caller-provided record body or replacement pointer is accepted here.
library StreamArtistRecoveryRewindRecordReads {
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

    function read(
        W.EnvironmentV3 memory e,
        W.RecordKind kind,
        bytes32 artistId,
        uint256 nativeIndex
    ) public view returns (Facts memory) {
        return _read(e, kind, artistId, nativeIndex, bytes32(0));
    }

    /// @dev The selector derives this head from each preceding same-artist native58, in receipt
    /// order. The continuation body and both original replay admissions are still checked here.
    function readWithRevisionContinuation(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        uint256 nativeIndex,
        bytes32 originalContinuation
    ) public view returns (Facts memory) {
        return _read(e, W.RecordKind.IDENTITY_REVISION, artistId, nativeIndex, originalContinuation);
    }

    function _read(
        W.EnvironmentV3 memory e,
        W.RecordKind kind,
        bytes32 artistId,
        uint256 nativeIndex,
        bytes32 originalContinuation
    ) private view returns (Facts memory f) {
        A.environment(e);
        if (artistId == 0 || kind == W.RecordKind.GUARDIAN_SET) {
            revert W.InvalidRecoveryRewindRecord(artistId);
        }
        address owner = kind == W.RecordKind.PAYOUT_DESIGNATION ? e.payoutOwner : e.identityOwner;
        Source memory source;
        source.original = e;
        source.imported = Recovered.active(owner);
        N.Receipt memory row;
        if (source.imported) {
            Runtime.Context memory clock =
                Runtime.load(e, kind == W.RecordKind.PAYOUT_DESIGNATION ? 5 : 2);
            source.occurrence = Runtime.receiptAt(clock, nativeIndex);
            source.original = Runtime.rewindEnvironment(source.occurrence.environment);
            row = source.occurrence.receipt;
        } else {
            if (nativeIndex >= IStreamArtistNativeReceipts(owner).artistNativeReceiptCount()) {
                revert W.InvalidRecoveryRewindRecord(bytes32(nativeIndex));
            }
            row = IStreamArtistNativeReceipts(owner).artistNativeReceiptAt(nativeIndex);
        }
        if (
            row.artistId != artistId || row.collectionId != 0 || row.recordHash == 0
                || row.operation != _operation(kind)
        ) {
            revert W.InvalidRecoveryRewindRecord(row.recordHash);
        }
        if (kind == W.RecordKind.SUCCESSOR_DESIGNATION) {
            f = _designation(e, artistId, row.recordHash, source);
        } else if (kind == W.RecordKind.ESTATE_DIRECTIVE) {
            f = _directive(e, artistId, row.recordHash, source);
        } else if (kind == W.RecordKind.IDENTITY_REVISION) {
            f = _revision(e, artistId, row.recordHash, originalContinuation, source);
        } else if (kind == W.RecordKind.PAYOUT_DESIGNATION) {
            f = source.imported
                ? StreamArtistRecoveryRewindPayoutReads.payoutAt(
                    e, artistId, row.recordHash, source.occurrence
                )
                : StreamArtistRecoveryRewindPayoutReads.payout(e, artistId, row.recordHash);
        } else if (kind == W.RecordKind.STEWARD_SANCTION_GRANT) {
            f = _grant(e, artistId, row.recordHash, source);
        } else {
            f = _standing(e, artistId, row.recordHash, source);
        }
        f.selected.recordHash = row.recordHash;
        f.selected.nativeIndex = nativeIndex;
        f.selected.admissionProof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_RECORD_FACTS_V3"),
                uint16(3),
                e,
                kind,
                row,
                nativeIndex,
                f
            )
        );
        if (source.imported) {
            f.selected.admissionProof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERED_REWIND_RECORD_FACTS_V1"),
                    source.occurrence,
                    f.selected.admissionProof
                )
            );
        }
    }

    function _designation(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 hash,
        Source memory source
    ) private view returns (Facts memory f) {
        S.DesignationRecord memory r = IStreamArtistSuccessionReads(e.identityOwner)
            .successorDesignationRecord(hash);
        T.Authorization memory auth = T.Authorization(r.nonce, r.signedAt, new bytes(0));
        if (
            r.recordHash != hash || r.terms.artistId != artistId || r.signer == address(0)
                || r.authorityClass != 1 || r.signedAt == 0 || r.signedAt > block.timestamp
                || r.terms.successor == address(0)
                || (r.terms.successorKind != 1 && r.terms.successorKind != 2)
                || r.terms.grantedCapabilities & ~uint32(4095) != 0
                || SH.designationRecord(A.hashes(source.original), r.terms, auth) != hash
        ) revert W.InvalidRecoveryRewindRecord(hash);
        T.ReplayCell memory n = _nonce(
            e,
            source,
            artistId,
            r.nonce,
            SH.designationDigest(A.hashes(source.original), r.terms, auth)
        );
        T.ReplayCell memory admitted = _consumed(
            e,
            source,
            keccak256("identity_authority.replay.succession_chain"),
            keccak256(abi.encode(hash)),
            hash
        );
        _sameRevision(hash, n, admitted);
        f.selected.originalDataHash = keccak256(abi.encode(r));
        f.selected.nonce = r.nonce;
        f.association = r.provisional;
        f.admissionRevision = n.touchedRevision;
        f.authorityClass = r.authorityClass;
        f.pairedDirective = r.terms.directiveHash;
        f.account = r.terms.successor;
        f.grantedCapabilities = r.terms.grantedCapabilities;
        _association(e, source, artistId, r.signer, f);
        f.selected.admissionProof = keccak256(abi.encode(f.selected.admissionProof, n, admitted));
    }

    function _directive(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 hash,
        Source memory source
    ) private view returns (Facts memory f) {
        S.DirectiveRecord memory r =
            IStreamArtistSuccessionReads(e.identityOwner).estateDirectiveRecord(hash);
        T.Authorization memory auth = T.Authorization(r.nonce, r.signedAt, new bytes(0));
        bytes memory payload =
            IStreamArtistSuccessionReads(e.identityOwner).estateDirectivePayload(hash);
        if (
            r.recordHash != hash || r.terms.artistId != artistId || r.signer == address(0)
                || r.authorityClass != 1 || r.signedAt == 0 || r.signedAt > block.timestamp
                || (r.terms.grantedCapabilities | r.terms.forbiddenCapabilities) & ~uint32(4095)
                    != 0 || r.terms.grantedCapabilities & r.terms.forbiddenCapabilities != 0
                || payload.length == 0 || payload.length > 8192
                || keccak256(payload) != r.terms.directivePayloadHash
                || SH.directiveRecord(A.hashes(source.original), r.terms, auth) != hash
        ) revert W.InvalidRecoveryRewindRecord(hash);
        T.ReplayCell memory n = _nonce(
            e,
            source,
            artistId,
            r.nonce,
            SH.directiveDigest(A.hashes(source.original), r.terms, auth)
        );
        T.ReplayCell memory admitted = _consumed(
            e,
            source,
            keccak256("identity_authority.replay.directive_chain"),
            keccak256(abi.encode(hash)),
            hash
        );
        _sameRevision(hash, n, admitted);
        f.selected.originalDataHash = keccak256(abi.encode(r, payload));
        f.selected.nonce = r.nonce;
        f.association = r.provisional;
        f.admissionRevision = n.touchedRevision;
        f.authorityClass = r.authorityClass;
        f.valueHash = r.terms.directivePayloadHash;
        f.grantedCapabilities = r.terms.grantedCapabilities;
        f.forbiddenCapabilities = r.terms.forbiddenCapabilities;
        _association(e, source, artistId, r.signer, f);
        f.selected.admissionProof = keccak256(abi.encode(f.selected.admissionProof, n, admitted));
    }

    function _grant(W.EnvironmentV3 memory e, bytes32 artistId, bytes32 hash, Source memory source)
        private
        view
        returns (Facts memory f)
    {
        Grant.GrantRecord memory r = Grant(e.identityOwner).stewardSanctionGrantRecord(hash);
        if (
            r.recordHash != hash || r.terms.artistId != artistId || r.signer == address(0)
                || r.authorityClass != 1 || r.signedAt == 0 || r.signedAt > block.timestamp
                || r.terms.statementHash == 0
                || hash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_STEWARD_SANCTION_GRANT_RECORD_V1"),
                            source.original.chainId,
                            source.original.registry,
                            artistId,
                            r.terms.granted,
                            r.terms.statementHash,
                            r.signer,
                            uint8(1),
                            r.nonce,
                            r.signedAt
                        )
                    )
        ) revert W.InvalidRecoveryRewindRecord(hash);
        bytes32 digest = H.typed(
            A.hashes(source.original),
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamStewardSanctionGrant(bytes32 artistId,bool granted,bytes32 statementHash,uint256 nonce,uint64 signedAt)"
                    ),
                    artistId,
                    r.terms.granted,
                    r.terms.statementHash,
                    r.nonce,
                    r.signedAt
                )
            )
        );
        T.ReplayCell memory n = _nonce(e, source, artistId, r.nonce, digest);
        T.ReplayCell memory admitted = _consumed(
            e,
            source,
            keccak256("identity_authority.replay.grant_chain"),
            keccak256(abi.encode(hash)),
            hash
        );
        _sameRevision(hash, n, admitted);
        f.selected.originalDataHash = keccak256(abi.encode(r));
        f.selected.nonce = r.nonce;
        f.association = r.provisional;
        f.admissionRevision = n.touchedRevision;
        f.authorityClass = 1;
        f.granted = r.terms.granted;
        f.valueHash = r.terms.statementHash;
        _association(e, source, artistId, r.signer, f);
        f.selected.admissionProof = keccak256(abi.encode(f.selected.admissionProof, n, admitted));
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

    function _consumed(
        W.EnvironmentV3 memory e,
        Source memory source,
        bytes32 surface,
        bytes32 scope,
        bytes32 expected
    ) private view returns (T.ReplayCell memory) {
        if (!source.imported) return A.consumed(e, surface, scope, expected);
        Runtime.ReplayFact memory f = A.consumedAt(
            e, source.occurrence.position.point.environmentHash, surface, scope, expected
        );
        if (!Recovered.samePoint(f.admission.point, source.occurrence.position.point)) {
            revert W.InvalidRecoveryRewindRecord(expected);
        }
        return f.cell;
    }

    function _sameRevision(bytes32 hash, T.ReplayCell memory a, T.ReplayCell memory b)
        private
        pure
    {
        if (a.touchedRevision != b.touchedRevision) revert W.InvalidRecoveryRewindRecord(hash);
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

    function _operation(W.RecordKind kind) private pure returns (uint16) {
        if (kind == W.RecordKind.SUCCESSOR_DESIGNATION) return 36;
        if (kind == W.RecordKind.ESTATE_DIRECTIVE) return 37;
        if (kind == W.RecordKind.IDENTITY_REVISION) return 25;
        if (kind == W.RecordKind.PAYOUT_DESIGNATION) return 18;
        if (kind == W.RecordKind.STEWARD_SANCTION_GRANT) return 19;
        if (kind == W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION) return 51;
        revert W.InvalidRecoveryRewindRecord(bytes32(0));
    }
}
