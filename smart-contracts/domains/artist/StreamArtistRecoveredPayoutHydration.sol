// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
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
    IStreamArtistRecoveryPayoutOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";
import {
    IStreamArtistRecoveredPayoutHydration
} from "../../interfaces/stream/artist/IStreamArtistRecoveredPayoutHydration.sol";
import {
    StreamArtistRecoveredPayoutEvidenceReads as EvidenceReads
} from "./StreamArtistRecoveredPayoutEvidenceReads.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";

/// @notice Complete recovered Payout transport over an authenticated flattened source prefix.
/// @dev The common profile authenticates provenance and source checkpoints before collection.
/// Identity's paired collector authenticates original35, vesting,58 and their retained closures.
/// This codec never installs authority, appends a receipt, or changes an original revision.
library StreamArtistRecoveredPayoutHydration {
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant APPLY = keccak256("payout_lifecycle.replay.recovery_rewind");
    bytes32 private constant ADMISSION = keccak256("payout_lifecycle.replay.recovery_continuation");

    function collect(address source, bytes32 artistId, RH.Provenance memory provenance)
        public
        view
        returns (P.Bundle memory bundle)
    {
        Provenance.validate(provenance);
        bundle = collectLocal(source, artistId, RH.ownerProvenance(provenance, 5));
        validate(bundle, provenance);
    }

    /// @notice Own-prefix inventory only, for the fixed Payout export getter.
    /// @dev The Coordinator MUST run full validate(bundle, allOwnerProvenance) before encoding.
    function collectLocal(address source, bytes32 artistId, RH.OwnerProvenance memory provenance)
        public
        view
        returns (P.Bundle memory bundle)
    {
        Provenance.validateOwner(provenance, 5);
        uint256 last = provenance.origins.length - 1;
        if (artistId == 0 || provenance.origins[last].owners[5] != source) {
            revert P.InvalidRecoveredPayout(artistId);
        }
        bundle.artistId = artistId;
        bundle.sourceSnapshot = IStreamArtistOwner(source).ownerStateSnapshotV2();
        IStreamArtistRecoveryPayoutOwnerV3 owner = IStreamArtistRecoveryPayoutOwnerV3(source);
        bundle.inventory = owner.payoutRewindInventoryV3(artistId);
        uint256 count;
        for (uint256 i; i < provenance.journal.length; ++i) {
            if (provenance.journal[i].receipt.artistId == artistId) ++count;
        }
        bundle.records = new P.RecordRow[](count);
        count = 0;
        for (uint256 i; i < provenance.journal.length; ++i) {
            RH.JournalEntry memory row = provenance.journal[i];
            if (row.receipt.artistId != artistId) continue;
            P.RecordRow memory r;
            r.position = row.position;
            (r.original, r.evidenceHash) = _original(
                _environment(provenance, row.position.point.environmentHash), row.receipt.recordHash
            );
            if (
                keccak256(abi.encode(r.original.terms))
                    != keccak256(
                        abi.encode(
                            IStreamArtistPayoutOwner(source)
                                .designationRecord(row.receipt.recordHash)
                        )
                    )
            ) revert P.InvalidRecoveredPayout(row.receipt.recordHash);
            r.association = IStreamArtistPayoutTransitionOwner(source)
                .payoutDesignationProvisionalAssociation(row.receipt.recordHash);
            r.abandonedUnder = IStreamArtistPayoutResolutionOwner(source)
                .payoutAbandonment(row.receipt.recordHash);
            r.status = owner.payoutRecoveryRecordStatusV3(row.receipt.recordHash);
            r.continuationHash =
                owner.payoutDesignationRecoveryContinuationV3(row.receipt.recordHash);
            bundle.records[count++] = r;
        }
        bundle.continuations = _collectContinuations(source, bundle, provenance);
        validateLocal(bundle, provenance);
    }

    function encode(P.Bundle memory bundle, RH.Provenance memory provenance)
        public
        pure
        returns (bytes memory)
    {
        validate(bundle, provenance);
        return abi.encode(P.SCHEMA, bundle);
    }

    function decode(bytes memory raw, RH.Provenance memory provenance)
        public
        pure
        returns (P.Bundle memory bundle)
    {
        bytes32 schema;
        (schema, bundle) = abi.decode(raw, (bytes32, P.Bundle));
        if (schema != P.SCHEMA || keccak256(raw) != keccak256(abi.encode(schema, bundle))) {
            revert P.InvalidRecoveredPayout(bytes32(0));
        }
        validate(bundle, provenance);
    }

    /// @notice Source-phase joined validation, including original Identity nonce and35 evidence.
    /// @dev The Coordinator must use this complete proof before binding the owner payload in op60.
    function validate(P.Bundle memory b, RH.Provenance memory p) public pure returns (bytes32) {
        Provenance.validate(p);
        bytes32 commitment = validateLocal(b, RH.ownerProvenance(p, 5));
        _identityLinks(b, p);
        return commitment;
    }

    /// @notice Destination codec for an already source-authenticated fixed-Coordinator payload.
    /// @dev This validates only Payout facts. It is not a complete cross-owner source certificate.
    function decodeLocal(bytes memory raw, RH.OwnerProvenance memory p)
        public
        pure
        returns (P.Bundle memory b)
    {
        bytes32 schema;
        (schema, b) = abi.decode(raw, (bytes32, P.Bundle));
        if (schema != P.SCHEMA || keccak256(raw) != keccak256(abi.encode(schema, b))) {
            revert P.InvalidRecoveredPayout(bytes32(0));
        }
        validateLocal(b, p);
    }

    function validateLocal(P.Bundle memory b, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes32)
    {
        Provenance.validateOwner(p, 5);
        if (
            b.artistId == 0
                || keccak256(abi.encode(b.sourceSnapshot))
                    != keccak256(abi.encode(p.eras[p.eras.length - 1].checkpoint.ownerState))
        ) revert P.InvalidRecoveredPayout(b.artistId);
        _records(b, p);
        _continuations(b, p);
        _pointer(b, b.inventory.stable);
        _pointer(b, b.inventory.candidate);
        if (
            b.inventory.candidate.recordHash != 0
                && b.inventory.candidate.recordHash == b.inventory.stable.recordHash
        ) revert P.InvalidRecoveredPayout(b.inventory.candidate.recordHash);
        if (_statuses(b, p) != b.inventory.supersessionStateCommitment) {
            revert P.InvalidRecoveredPayout(b.artistId);
        }
        _admissions(b, p);
        return keccak256(abi.encode(P.SCHEMA, b));
    }

    function _records(P.Bundle memory b, RH.OwnerProvenance memory p) private pure {
        uint256 cursor;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory entry = p.journal[i];
            if (
                entry.receipt.operation != 18 || entry.receipt.collectionId != 0
                    || entry.receipt.recordHash == 0
            ) revert P.InvalidRecoveredPayout(entry.receipt.recordHash);
            if (entry.receipt.artistId != b.artistId) continue;
            if (cursor >= b.records.length) {
                revert P.InvalidRecoveredPayout(entry.receipt.recordHash);
            }
            P.RecordRow memory r = b.records[cursor];
            W.EnvironmentV3 memory e = _environment(p, r.position.point.environmentHash);
            if (
                r.original.recordHash != entry.receipt.recordHash
                    || keccak256(abi.encode(r.position)) != keccak256(abi.encode(entry.position))
                    || r.original.terms.artistId != b.artistId || r.original.signer == address(0)
                    || r.original.terms.payoutAccount == address(0) || r.original.signedAt == 0
                    || (r.original.authorityClass != 1 && r.original.authorityClass != 3)
                    || r.evidenceHash != W.payoutOriginalHash(e, r.original)
                    || r.original.recordHash
                        != H.payoutRecordForAuthority(
                            H.Environment(e.chainId, e.registry, e.core, e.manager),
                            r.original.terms,
                            r.original.signer,
                            r.original.authorityClass,
                            r.original.nonce,
                            r.original.signedAt
                        )
                    || (r.association.transitionRecordHash == 0)
                        != (r.association.windowEndsAt == 0)
                    || (r.abandonedUnder != 0 && r.association.transitionRecordHash == 0)
            ) {
                revert P.InvalidRecoveredPayout(r.original.recordHash);
            }
            bool foundParent = r.original.terms.previousDesignationRecordHash == 0;
            for (uint256 j; j < cursor; ++j) {
                if (b.records[j].original.recordHash == r.original.recordHash) {
                    revert P.InvalidRecoveredPayout(r.original.recordHash);
                }
                if (
                    b.records[j].original.recordHash
                        == r.original.terms.previousDesignationRecordHash
                ) {
                    if (b.records[j].original.terms.payoutAccount == r.original.terms.payoutAccount)
                    {
                        revert P.InvalidRecoveredPayout(r.original.recordHash);
                    }
                    foundParent = true;
                }
            }
            if (!foundParent) revert P.InvalidRecoveredPayout(r.original.recordHash);
            ++cursor;
        }
        if (cursor != b.records.length) revert P.InvalidRecoveredPayout(b.artistId);
    }

    function _collectContinuations(address source, P.Bundle memory b, RH.OwnerProvenance memory p)
        private
        view
        returns (P.ContinuationRow[] memory rows)
    {
        P.ContinuationRow[] memory reverse = new P.ContinuationRow[](b.records.length);
        bytes32 cursor = b.inventory.continuationCommitment;
        uint256 count;
        while (cursor != 0) {
            if (count == reverse.length) revert P.InvalidRecoveredPayout(cursor);
            W.PayoutContinuationV3 memory c =
                IStreamArtistRecoveryPayoutOwnerV3(source).payoutRecoveryContinuationV3(cursor);
            if (c.continuationHash != cursor) revert P.InvalidRecoveredPayout(cursor);
            for (uint256 j; j < count; ++j) {
                if (reverse[j].continuation.continuationHash == cursor) {
                    revert P.InvalidRecoveredPayout(cursor);
                }
            }
            RH.Point memory point;
            for (uint256 j; j < p.origins.length; ++j) {
                bytes32 origin = RH.originHash(p.origins[j]);
                if (W.payoutContinuationHash(_environment(p, origin), c) == cursor) {
                    if (point.environmentHash != 0) revert P.InvalidRecoveredPayout(cursor);
                    point = RH.Point(origin, 5, c.payoutOwnerRevision);
                }
            }
            if (point.environmentHash == 0) revert P.InvalidRecoveredPayout(cursor);
            reverse[count++] = P.ContinuationRow(
                point,
                c,
                IStreamArtistRecoveredPayoutHydration(source)
                    .payoutRecoveryAppliedCommitmentV3(c.recoveryRecordHash)
            );
            cursor = c.previousContinuationHash;
        }
        rows = new P.ContinuationRow[](count);
        for (uint256 i; i < count; ++i) {
            rows[i] = reverse[count - i - 1];
        }
    }

    function _continuations(P.Bundle memory b, RH.OwnerProvenance memory p) private pure {
        if (b.continuations.length > b.records.length) revert P.InvalidRecoveredPayout(b.artistId);
        bytes32 prior;
        for (uint256 i; i < b.continuations.length; ++i) {
            P.ContinuationRow memory row = b.continuations[i];
            W.PayoutContinuationV3 memory c = row.continuation;
            Chronology.validateOwnerPoint(p, 5, row.point);
            if (
                row.point.ownerIndex != 5 || row.point.ownerRevision != c.payoutOwnerRevision
                    || c.artistId != b.artistId || c.continuationHash == 0
                    || c.recoveryRecordHash == 0 || c.actionId == 0 || c.manifestHash == 0
                    || c.planCommitment == 0 || row.appliedCommitment == 0
                    || c.previousContinuationHash != prior
                    || c.continuationHash
                        != W.payoutContinuationHash(_environment(p, row.point.environmentHash), c)
                    || (i != 0
                        && !Chronology.beforeOwner(p, 5, b.continuations[i - 1].point, row.point))
            ) {
                revert P.InvalidRecoveredPayout(c.continuationHash);
            }
            RH.ReplayAlias memory applied =
                _localAlias(p, row.point.environmentHash, APPLY, c.recoveryRecordHash);
            if (
                applied.cell.commitment != c.planCommitment
                    || keccak256(abi.encode(applied.admittedAt)) != keccak256(abi.encode(row.point))
            ) {
                revert P.InvalidRecoveredPayout(c.continuationHash);
            }
            _pointerBefore(b, p, c.stable, row.point);
            _pointerBefore(b, p, c.candidate, row.point);
            if (c.candidate.recordHash != 0 && c.candidate.recordHash == c.stable.recordHash) {
                revert P.InvalidRecoveredPayout(c.continuationHash);
            }
            if (c.releasedChildRecordHash != 0) {
                P.RecordRow memory released = b.records[_recordIndex(b, c.releasedChildRecordHash)];
                if (released.status.recoveryRecordHash != c.recoveryRecordHash) {
                    revert P.InvalidRecoveredPayout(c.releasedChildRecordHash);
                }
            }
            for (uint256 j; j < i; ++j) {
                if (b.continuations[j].continuation.recoveryRecordHash == c.recoveryRecordHash) {
                    revert P.InvalidRecoveredPayout(c.recoveryRecordHash);
                }
            }
            prior = c.continuationHash;
        }
        if (prior != b.inventory.continuationCommitment) revert P.InvalidRecoveredPayout(prior);
    }

    function _statuses(P.Bundle memory b, RH.OwnerProvenance memory p)
        private
        pure
        returns (bytes32 state)
    {
        uint256 total;
        for (uint256 i; i < b.records.length; ++i) {
            W.StatusV3 memory s = b.records[i].status;
            if (s.recoveryRecordHash == 0) {
                W.StatusV3 memory empty;
                if (keccak256(abi.encode(s)) != keccak256(abi.encode(empty))) {
                    revert P.InvalidRecoveredPayout(b.records[i].original.recordHash);
                }
            } else {
                ++total;
            }
        }
        uint256 seen;
        for (uint256 i; i < b.continuations.length; ++i) {
            P.ContinuationRow memory row = b.continuations[i];
            W.PayoutContinuationV3 memory c = row.continuation;
            bytes32[] memory hashes = new bytes32[](b.records.length);
            uint256 count;
            for (uint256 j; j < b.records.length; ++j) {
                P.RecordRow memory r = b.records[j];
                if (r.status.recoveryRecordHash != c.recoveryRecordHash) continue;
                if (
                    r.status.artistId != b.artistId
                        || r.status.kind != W.RecordKind.PAYOUT_DESIGNATION
                        || r.status.actionId != c.actionId
                        || r.status.planCommitment != c.planCommitment
                        || !Chronology.beforeOwner(p, 5, r.position.point, row.point)
                ) {
                    revert P.InvalidRecoveredPayout(r.original.recordHash);
                }
                uint256 at = count;
                while (at != 0 && hashes[at - 1] > r.original.recordHash) {
                    hashes[at] = hashes[at - 1];
                    --at;
                }
                hashes[at] = r.original.recordHash;
                ++count;
            }
            if (count == 0) revert P.InvalidRecoveredPayout(c.recoveryRecordHash);
            W.EnvironmentV3 memory e = _environment(p, row.point.environmentHash);
            for (uint256 j; j < count; ++j) {
                state = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_STATUS_V3"),
                        uint16(3),
                        e,
                        state,
                        hashes[j],
                        b.records[_recordIndex(b, hashes[j])].status
                    )
                );
            }
            seen += count;
        }
        if (seen != total) revert P.InvalidRecoveredPayout(b.artistId);
        if (
            b.inventory.stable.recordHash != 0
                && b.records[_recordIndex(b, b.inventory.stable.recordHash)].status
                    .recoveryRecordHash != 0
        ) {
            revert P.InvalidRecoveredPayout(b.inventory.stable.recordHash);
        }
        if (
            b.inventory.candidate.recordHash != 0
                && b.records[_recordIndex(b, b.inventory.candidate.recordHash)].status
                    .recoveryRecordHash != 0
        ) {
            revert P.InvalidRecoveredPayout(b.inventory.candidate.recordHash);
        }
    }

    function _admissions(P.Bundle memory b, RH.OwnerProvenance memory p) private pure {
        for (uint256 i; i < b.records.length; ++i) {
            P.RecordRow memory r = b.records[i];
            if (r.continuationHash == 0) continue;
            bool found;
            for (uint256 j; j < b.continuations.length; ++j) {
                P.ContinuationRow memory row = b.continuations[j];
                W.PayoutContinuationV3 memory c = row.continuation;
                if (c.continuationHash != r.continuationHash) continue;
                if (
                    found || c.candidate.recordHash != 0 || c.candidate.account != address(0)
                        || c.stable.recordHash != r.original.terms.previousDesignationRecordHash
                        || !Chronology.beforeOwner(p, 5, row.point, r.position.point)
                ) {
                    revert P.InvalidRecoveredPayout(r.original.recordHash);
                }
                RH.ReplayAlias memory admitted = _localAlias(
                    p,
                    r.position.point.environmentHash,
                    ADMISSION,
                    keccak256(abi.encode(b.artistId, c.continuationHash, c.stable.recordHash))
                );
                if (
                    admitted.cell.commitment != r.original.recordHash
                        || keccak256(abi.encode(admitted.admittedAt))
                            != keccak256(abi.encode(r.position.point))
                ) {
                    revert P.InvalidRecoveredPayout(r.original.recordHash);
                }
                found = true;
            }
            if (!found) revert P.InvalidRecoveredPayout(r.original.recordHash);
        }
    }

    function _identityLinks(P.Bundle memory b, RH.Provenance memory p) private pure {
        for (uint256 i; i < b.records.length; ++i) {
            P.RecordRow memory r = b.records[i];
            W.EnvironmentV3 memory e = _environment(p, r.position.point.environmentHash);
            RH.ReplayAlias memory nonce = _alias(
                p,
                r.position.point.environmentHash,
                2,
                NONCE,
                keccak256(abi.encode(b.artistId, r.original.nonce))
            );
            if (
                nonce.cell.commitment
                    != H.payoutDigest(
                        H.Environment(e.chainId, e.registry, e.core, e.manager),
                        r.original.terms,
                        T.Authorization(r.original.nonce, r.original.signedAt, new bytes(0))
                    )
            ) revert P.InvalidRecoveredPayout(r.original.recordHash);
            if (r.continuationHash == 0) continue;
            for (uint256 j; j < b.continuations.length; ++j) {
                P.ContinuationRow memory row = b.continuations[j];
                if (row.continuation.continuationHash != r.continuationHash) continue;
                if (!Chronology.before(
                        p,
                        RH.Point(
                            row.point.environmentHash, 2, row.continuation.identityOwnerRevision
                        ),
                        nonce.admittedAt
                    )) revert P.InvalidRecoveredPayout(r.original.recordHash);
            }
        }
        for (uint256 i; i < b.continuations.length; ++i) {
            P.ContinuationRow memory row = b.continuations[i];
            W.PayoutContinuationV3 memory c = row.continuation;
            bool foundRecovery;
            for (uint256 j; j < p.journals[2].length; ++j) {
                RH.JournalEntry memory r = p.journals[2][j];
                if (
                    r.receipt.operation == 35 && r.receipt.artistId == b.artistId
                        && r.receipt.collectionId == 0
                        && r.receipt.recordHash == c.recoveryRecordHash
                        && r.position.point.environmentHash == row.point.environmentHash
                        && r.position.point.ownerRevision == c.identityOwnerRevision
                ) foundRecovery = true;
            }
            if (!foundRecovery) revert P.InvalidRecoveredPayout(c.recoveryRecordHash);
        }
    }

    function _pointer(P.Bundle memory b, T.Payout memory value) private pure {
        if (value.recordHash == 0) {
            if (value.account != address(0)) revert P.InvalidRecoveredPayout(bytes32(0));
        } else if (
            b.records[_recordIndex(b, value.recordHash)].original.terms.payoutAccount
                != value.account
        ) {
            revert P.InvalidRecoveredPayout(value.recordHash);
        }
    }

    function _pointerBefore(
        P.Bundle memory b,
        RH.OwnerProvenance memory p,
        T.Payout memory value,
        RH.Point memory point
    ) private pure {
        _pointer(b, value);
        if (
            value.recordHash != 0
                && !Chronology.beforeOwner(
                    p, 5, b.records[_recordIndex(b, value.recordHash)].position.point, point
                )
        ) {
            revert P.InvalidRecoveredPayout(value.recordHash);
        }
    }

    function _recordIndex(P.Bundle memory b, bytes32 record) private pure returns (uint256) {
        for (uint256 i; i < b.records.length; ++i) {
            if (b.records[i].original.recordHash == record) return i;
        }
        revert P.InvalidRecoveredPayout(record);
    }

    function _alias(
        RH.Provenance memory p,
        bytes32 origin,
        uint8 owner,
        bytes32 surface,
        bytes32 scope
    ) private pure returns (RH.ReplayAlias memory result) {
        bool found;
        for (uint256 i; i < p.aliases[owner].length; ++i) {
            RH.ReplayAlias memory a = p.aliases[owner][i];
            if (a.originHash != origin || a.surface != surface || a.scope != scope) continue;
            if (
                found || a.ownerIndex != owner || a.cell.kind != 1 || a.cell.status != 2
                    || a.cell.commitment == 0 || a.cell.touchedRevision == 0
                    || a.admittedAt.environmentHash != origin || a.admittedAt.ownerIndex != owner
                    || a.admittedAt.ownerRevision != a.cell.touchedRevision
            ) {
                revert P.InvalidRecoveredPayout(scope);
            }
            Chronology.validatePoint(p, a.admittedAt);
            result = a;
            found = true;
        }
        if (!found) revert P.InvalidRecoveredPayout(scope);
    }

    function _localAlias(
        RH.OwnerProvenance memory p,
        bytes32 origin,
        bytes32 surface,
        bytes32 scope
    ) private pure returns (RH.ReplayAlias memory result) {
        bool found;
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (a.originHash != origin || a.surface != surface || a.scope != scope) continue;
            if (
                found || a.ownerIndex != 5 || a.cell.kind != 1 || a.cell.status != 2
                    || a.cell.commitment == 0 || a.cell.touchedRevision == 0
                    || a.admittedAt.environmentHash != origin || a.admittedAt.ownerIndex != 5
                    || a.admittedAt.ownerRevision != a.cell.touchedRevision
            ) revert P.InvalidRecoveredPayout(scope);
            Chronology.validateOwnerPoint(p, 5, a.admittedAt);
            result = a;
            found = true;
        }
        if (!found) revert P.InvalidRecoveredPayout(scope);
    }

    function _environment(RH.OwnerProvenance memory p, bytes32 origin)
        private
        pure
        returns (W.EnvironmentV3 memory e)
    {
        for (uint256 i; i < p.origins.length; ++i) {
            if (RH.originHash(p.origins[i]) != origin) continue;
            RH.OriginEnvironment memory o = p.origins[i];
            return W.EnvironmentV3(
                o.chainId,
                o.registry,
                o.owners[2],
                o.ownerCodeHashes[2],
                o.owners[5],
                o.ownerCodeHashes[5],
                o.coordinator,
                o.archive,
                o.core,
                o.manager
            );
        }
        revert P.InvalidRecoveredPayout(origin);
    }

    function _environment(RH.Provenance memory p, bytes32 origin)
        private
        pure
        returns (W.EnvironmentV3 memory e)
    {
        RH.OriginEnvironment memory o = Provenance.environment(p, origin);
        return W.EnvironmentV3(
            o.chainId,
            o.registry,
            o.owners[2],
            o.ownerCodeHashes[2],
            o.owners[5],
            o.ownerCodeHashes[5],
            o.coordinator,
            o.archive,
            o.core,
            o.manager
        );
    }

    function _original(W.EnvironmentV3 memory e, bytes32 record)
        private
        view
        returns (W.PayoutOriginalV3 memory original, bytes32 evidenceHash)
    {
        return EvidenceReads.original(e, record);
    }
}
