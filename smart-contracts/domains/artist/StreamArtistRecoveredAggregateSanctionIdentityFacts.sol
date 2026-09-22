// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as Catalogue
} from "./StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredSanctionEvidenceCodec as Codec
} from "./StreamArtistRecoveredSanctionEvidenceCodec.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import { StreamArtistSanctionHashes as Hashes } from "./StreamArtistSanctionHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";

/// @notice Original op12 Identity joins across the complete aggregate sanction catalogue.
/// @dev The enclosing profile authenticates each canonical complete Identity bundle, the global
/// provenance and catalogue, and all owner clocks/guards. This leaf never substitutes the
/// collection's current artist or the artist's current principal for a historical signer.
library StreamArtistRecoveredAggregateSanctionIdentityFacts {
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant OBSERVED =
        keccak256("identity_authority.replay.authorization_consumed_digest");
    bytes32 private constant CANCEL =
        keccak256("identity_authority.replay.dormancy_cancellation_key");

    function validate(
        bytes[] calldata identities,
        M.State calldata scope,
        H.Inventory calldata history,
        RH.Provenance calldata p
    ) public view {
        if (
            identities.length != scope.artists.length || p.origins.length != p.eras.length
                || history.catalogues.length != p.eras.length
        ) _invalid();
        for (uint256 i; i < identities.length; ++i) {
            IH.Bundle calldata b = Frame.bundle(identities[i]);
            if (b.artistId == 0 || b.artistId != scope.artists[i].artistId) _invalid();
            for (uint256 j; j < i; ++j) {
                if (scope.artists[j].artistId == b.artistId) _invalid();
            }
        }
        uint256 count;
        for (uint256 i; i < history.operations.length; ++i) {
            H.OperationEvidence calldata op = history.operations[i];
            if (op.operation != 12) continue;
            if (count == history.sanctions.length) _invalid();
            uint256 era = _era(p, op.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], history.catalogues[era], op.evidence);
            H.SanctionPayload memory s = Codec.sanction(e.payload);
            H.SanctionRow calldata row = history.sanctions[count++];
            _record(p.origins[era], op, e, s, row);
            bool collection;
            for (uint256 j; j < scope.collections.length; ++j) {
                if (scope.collections[j].collectionId == s.record.terms.collectionId) {
                    collection = true;
                }
            }
            if (!collection) _invalid();
            // The binding may since have changed artists. Its historical sanction chooses
            // the matching original Identity, independently of the current collection query.
            IH.Bundle calldata b = Frame.bundle(identities[_artist(scope, s.record.artistId)]);
            RH.Point memory point = RH.Point(op.originHash, 2, e.after_[2].revision);
            Clock.validatePoint(p, point);
            if (
                e.before_[2].domainId != RH.ownerDomain(2)
                    || e.after_[2].domainId != RH.ownerDomain(2)
                    || e.before_[2].revision < p.eras[era].lowerRevisions[2]
                    || e.before_[2].revision == type(uint64).max
                    || point.ownerRevision != e.before_[2].revision + 1
                    || e.before_[2].recordChainTip != e.after_[2].recordChainTip
            ) _invalid();
            // authorize returns Mutation.record=0 and _noteLiving changes only state/replay.
            // That preserves this owner accumulator even if the separate native journal
            // gains an original42 cancellation at the same revision; validate both facts.
            _signature(b, s);
            _nonce(b, p, point, s.record.nonce, s.record.digest);
            _activity(b, p, point, s, p.origins[era]);
        }
        if (count != history.sanctions.length) _invalid();
        // consumeSanction commits record zero. Its activity recipe may emit an original42,
        // but never creates a synthetic Identity op12/op13 receipt.
        for (uint256 i; i < p.journals[2].length; ++i) {
            uint16 op = p.journals[2][i].receipt.operation;
            if (op == 12 || op == 13) _invalid();
        }
    }

    function _record(
        RH.OriginEnvironment calldata o,
        H.OperationEvidence calldata op,
        H.Envelope memory e,
        H.SanctionPayload memory s,
        H.SanctionRow calldata row
    ) private pure {
        if (
            e.operation != 12 || e.value == 0 || e.value != s.record.recordHash
                || keccak256(abi.encode(row.record)) != keccak256(abi.encode(s.record))
                || keccak256(abi.encode(row.evidence)) != keccak256(abi.encode(op.evidence))
                || !D.samePoint(row.point, RH.Point(op.originHash, 6, e.after_[6].revision))
                || s.record.artistId != s.binding_.artistId || !s.binding_.accepted
                || s.record.bindingHash != s.binding_.bindingHash
                || s.record.bindingGeneration != s.binding_.generation
                || (s.record.authorityClass != 1
                    && s.record.authorityClass != 3
                    && s.record.authorityClass != 4) || s.record.signer == address(0)
                || s.record.signer != s.approval.signer
                || s.record.signer != s.authority.authorityAddress
                || s.record.authorityClass != s.authority.authorityClass || s.approval.direct
                || s.record.nonce != s.authorization.nonce
                || s.record.deadline != s.authorization.time || s.record.signedAt == 0
                || s.record.deadline < s.record.signedAt
                || keccak256(abi.encode(s.record.terms)) != keccak256(abi.encode(s.request.terms))
        ) _invalid();
        StreamArtistHashes.Environment memory env =
            StreamArtistHashes.Environment(o.chainId, o.registry, o.core, o.manager);
        if (
            Hashes.record(env, s.record) != e.value
                || Hashes.digest(env, s.record.terms, s.authorization) != s.record.digest
                || s.approval.digest != s.record.digest
        ) _invalid();
    }

    function _signature(IH.Bundle calldata b, H.SanctionPayload memory s) private pure {
        if (s.authorization.signature.length == 0 || s.authorization.signature.length > 4096) {
            _invalid();
        }
        uint256 matched;
        for (uint256 i; i < b.signatures.length; ++i) {
            if (b.signatures[i].recordHash != s.record.recordHash) continue;
            if (keccak256(b.signatures[i].signature) != keccak256(s.authorization.signature)) {
                _invalid();
            }
            ++matched;
        }
        if (matched != 1) _invalid();
    }

    function _nonce(
        IH.Bundle calldata b,
        RH.Provenance calldata p,
        RH.Point memory point,
        uint256 nonce,
        bytes32 digest
    ) private pure {
        _guard(p, NONCE, keccak256(abi.encode(b.artistId, nonce)), digest, point, false);
        _guard(p, OBSERVED, keccak256(abi.encode(b.artistId, digest)), digest, point, true);
        bool consumed;
        for (uint256 i; i < b.nonces.length; ++i) {
            IH.NonceLane calldata lane = b.nonces[i];
            if (lane.kind != 1 || lane.key != b.artistId) continue;
            for (uint256 j; j < lane.words.length; ++j) {
                if (
                    lane.words[j].prefix == nonce >> 8
                        && (lane.words[j].words[0] & (uint256(1) << uint8(nonce))) != 0
                ) consumed = true;
            }
        }
        if (!consumed) _invalid();
    }

    function _guard(
        RH.Provenance calldata p,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment,
        RH.Point memory point,
        bool earlier
    ) private pure {
        bool found;
        for (uint256 i; i < p.aliases[2].length; ++i) {
            RH.ReplayAlias calldata a = p.aliases[2][i];
            if (a.surface != surface || a.scope != scope) continue;
            if (
                a.ownerIndex != 2 || a.cell.kind != 1 || a.cell.status != 2
                    || a.cell.commitment != commitment
                    || (earlier
                            ? Clock.compare(p, a.admittedAt, point) > 0
                            : !D.samePoint(a.admittedAt, point))
            ) _invalid();
            found = true;
        }
        if (!found || commitment == 0) _invalid();
    }

    function _activity(
        IH.Bundle calldata b,
        RH.Provenance calldata p,
        RH.Point memory point,
        H.SanctionPayload memory s,
        RH.OriginEnvironment calldata o
    ) private pure {
        bytes32 cancellation;
        for (uint256 i; i < p.journals[2].length; ++i) {
            RH.JournalEntry calldata j = p.journals[2][i];
            if (!D.samePoint(j.position.point, point)) continue;
            if (
                cancellation != 0 || j.receipt.operation != 42 || j.receipt.artistId != b.artistId
                    || j.receipt.collectionId != 0 || j.receipt.recordHash == 0
                    || s.record.authorityClass != 1
            ) _invalid();
            cancellation = j.receipt.recordHash;
        }
        uint256 matched;
        if (s.record.authorityClass == 1) {
            for (uint256 i; i < b.notices.length; ++i) {
                IH.NoticeRow calldata n = b.notices[i];
                if (!Clock.before(p, n.position.point, point)) continue;
                // A class1 sanction is genuine principal activity. Any previously open
                // notice must close here, even when its deadline has already elapsed.
                if (n.phase == 1) _invalid();
                RH.Point memory terminal = _terminalPoint(p, b.artistId, n);
                if (Clock.before(p, terminal, point)) continue;
                if (!D.samePoint(terminal, point) || n.phase != 2) _invalid();
                _cancellation(n, s, o, cancellation);
                _guard(p, CANCEL, n.notice.recordHash, cancellation, point, false);
                ++matched;
            }
        }
        if (matched != (cancellation == 0 ? 0 : 1)) _invalid();
        // Estate livingAction can cancel a pending38 and change activity/replay, without
        // emitting native39. Finding activity likewise changes retained state only. Their
        // complete source getter/guard checks belong to the enclosing Identity validators.
        // Native42 and those effects are not inferred from the separate owner record tip.
    }

    function _terminalPoint(RH.Provenance calldata p, bytes32 artist, IH.NoticeRow calldata n)
        private
        pure
        returns (RH.Point memory point)
    {
        if (n.phase != 2 && n.phase != 3) _invalid();
        bool found;
        for (uint256 i; i < p.journals[2].length; ++i) {
            RH.JournalEntry calldata j = p.journals[2][i];
            if (j.receipt.recordHash != n.terminal.recordHash) continue;
            if (
                found || j.receipt.artistId != artist || j.receipt.collectionId != 0
                    || j.receipt.operation != (n.phase == 2 ? 42 : 43)
            ) _invalid();
            point = j.position.point;
            found = true;
        }
        if (!found) _invalid();
    }

    function _cancellation(
        IH.NoticeRow calldata n,
        H.SanctionPayload memory s,
        RH.OriginEnvironment calldata o,
        bytes32 expected
    ) private pure {
        Dorm.Terminal memory t;
        t.noticeHash = n.notice.recordHash;
        t.actor = s.record.signer;
        t.authorityClass = 1;
        t.observedAt = s.record.signedAt;
        if (n.notice.priorActivity == type(uint256).max) _invalid();
        t.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                o.chainId,
                o.registry,
                o.owners[2],
                t,
                n.notice.priorActivity + 1
            )
        );
        if (
            expected == 0 || t.recordHash != expected || n.notice.incumbent != s.record.signer
                || n.notice.terms.artistId != s.record.artistId
                || keccak256(abi.encode(t)) != keccak256(abi.encode(n.terminal))
        ) _invalid();
    }

    function _artist(M.State calldata scope, bytes32 artist) private pure returns (uint256) {
        for (uint256 i; i < scope.artists.length; ++i) {
            if (scope.artists[i].artistId == artist) return i;
        }
        _invalid();
    }

    function _era(RH.Provenance calldata p, bytes32 origin) private pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
