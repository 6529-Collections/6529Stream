// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistIdentityRevisionReads,
    StreamArtistIdentityRevisionTypes as Doc
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";
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
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "./StreamArtistRecoveryRewindRecordReads.sol";

/// @notice Fixed original revision admission reads for recovery rewind.
/// @dev Preserves the original read and validation order. The caller retains journal
/// admission and final Facts wrapping; this library owns no state or routing choice.
library StreamArtistRecoveryRewindRevisionReads {
    function revision(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 hash,
        bytes32 originalContinuation,
        Records.Source memory source
    ) public view returns (Records.Facts memory f) {
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
        Records.Source memory source,
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
        Records.Source memory source,
        bytes32 artistId,
        address signer,
        Records.Facts memory f
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
}
