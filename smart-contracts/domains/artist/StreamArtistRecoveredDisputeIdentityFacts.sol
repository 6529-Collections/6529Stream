// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistDelegationState as Delegation } from "./StreamArtistDelegationState.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";

/// @notice Original signature/nonce admission and exact saved dispute-grant associations.
/// @dev The complete Identity source has already checked every bundle byte and nonce word.
/// Deadline is not stored in the old Record: no current signer or invented deadline is used
/// to reconstruct a historical signature. Its original consumed digest remains the authority.
library StreamArtistRecoveredDisputeIdentityFacts {
    struct IdentityRows {
        bytes32 artistId;
        IH.SignatureRow[] signatures;
        IH.NonceLane[] nonces;
        IH.DelegationRow[] delegations;
        IH.ContestRow[] contests;
        IH.CauseRow[] causes;
        IH.GuardianRow[] guardians;
    }
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant DELEGATE_NONCE =
        keccak256("identity_authority.replay.delegated_nonce");
    bytes32 private constant OBSERVED =
        keccak256("identity_authority.replay.authorization_consumed_digest");

    function validate(
        IdentityRows memory identity,
        D.Bundle memory b,
        AH.Query memory q,
        RH.Provenance memory p
    ) public pure returns (uint256[] memory uses) {
        uses = validateRows(identity, b, q, p);
        uint256 vetoes;
        for (uint256 i; i < b.repudiations.length; ++i) {
            if (b.repudiations[i].terminal.phase == 2) ++vetoes;
        }
        uint256 nativeVetoes;
        for (uint256 i; i < p.journals[2].length; ++i) {
            if (p.journals[2][i].receipt.operation == 48) ++nativeVetoes;
        }
        if (nativeVetoes != 2 * vetoes) _invalid();
        // Original44/45/47/61 authorization commits do not append Identity native records.
        for (uint256 i; i < p.journals[2].length; ++i) {
            uint16 op = p.journals[2][i].receipt.operation;
            if (op == 44 || op == 45 || op == 47 || op == 49 || op == 50 || op == 61) _invalid();
        }
    }

    /// @notice Original row facts without a singleton-wide native veto count.
    /// @dev Aggregate callers must check the complete owner2 veto inventory once across every collection.
    function validateRows(
        IdentityRows memory identity,
        D.Bundle memory b,
        AH.Query memory q,
        RH.Provenance memory p
    ) public pure returns (uint256[] memory uses) {
        if (
            identity.artistId != q.artistId || b.artistId != q.artistId
                || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
        ) _invalid();
        uses = new uint256[](identity.delegations.length);
        for (uint256 i; i < b.disputes.length; ++i) {
            D.DisputeRow memory row = b.disputes[i];
            AD.Record memory record = row.record;
            if (record.governanceActionId != 0) continue;
            _signature(identity, record.recordHash);
            bytes32 lane = record.standing.delegation == 0
                ? q.artistId
                : Delegation.lane(q.artistId, record.signer);
            RH.Point memory admitted = _nonce(
                identity,
                p,
                record.standing.delegation == 0 ? uint8(1) : uint8(2),
                lane,
                record.nonce,
                row.point.environmentHash
            );
            if (record.standing.delegation != 0) {
                uint256 at = _grant(identity, p, record, admitted);
                ++uses[at];
            }
        }
        for (uint256 i; i < b.repudiations.length; ++i) {
            D.RepudiationRow memory row = b.repudiations[i];
            _signature(identity, row.record.recordHash);
            _nonce(identity, p, 1, q.artistId, row.record.nonce, row.point.environmentHash);
            if (row.terminal.phase == 2) {
                _veto(identity, p, row);
            }
        }
    }

    /// @notice Original signature, nonce and grant predicates for an explicit standing principal.
    /// @dev Identity signatures are a global record-hash map. Native partitioning can carry
    /// these bytes in the bound Artist's bundle while nonce/grant authority belongs to a
    /// former Artist or collaborator. Both inputs must come from canonical actual source rows.
    function disputeUse(
        IdentityRows memory identity,
        IH.SignatureRow[] memory sourceSignatures,
        D.DisputeRow memory row,
        RH.Provenance memory p
    ) public pure returns (uint256 grantIndexPlusOne) {
        AD.Record memory record = row.record;
        if (record.governanceActionId != 0 || identity.artistId != record.standing.artistId) {
            _invalid();
        }
        _signatureRows(sourceSignatures, record.recordHash);
        bytes32 lane = record.standing.delegation == 0
            ? identity.artistId
            : Delegation.lane(identity.artistId, record.signer);
        RH.Point memory admitted = _nonce(
            identity,
            p,
            record.standing.delegation == 0 ? uint8(1) : uint8(2),
            lane,
            record.nonce,
            row.point.environmentHash
        );
        if (record.standing.delegation != 0) return _grant(identity, p, record, admitted) + 1;
    }

    /// @notice Original repudiation nonce/signature and paired-veto predicates for its Artist.
    /// @dev Aggregate callers perform the native48 census once over the full owner2 journal.
    function repudiationUse(
        IdentityRows memory identity,
        D.RepudiationRow memory row,
        RH.Provenance memory p
    ) public pure {
        if (identity.artistId != row.record.artistId) _invalid();
        _signature(identity, row.record.recordHash);
        _nonce(identity, p, 1, identity.artistId, row.record.nonce, row.point.environmentHash);
        if (row.terminal.phase == 2) _veto(identity, p, row);
    }

    function _nonce(
        IdentityRows memory identity,
        RH.Provenance memory p,
        uint8 kind,
        bytes32 lane,
        uint256 nonce,
        bytes32 environment
    ) private pure returns (RH.Point memory admitted) {
        bytes32 surface = kind == 1 ? NONCE : DELEGATE_NONCE;
        bytes32 scope = keccak256(abi.encode(lane, nonce));
        bytes32 digest;
        bool found;
        for (uint256 i; i < p.aliases[2].length; ++i) {
            RH.ReplayAlias memory a = p.aliases[2][i];
            if (a.surface != surface || a.scope != scope) continue;
            if (
                a.cell.kind != 1 || a.cell.status != 2 || a.cell.commitment == 0
                    || a.admittedAt.environmentHash != environment
                    || (found
                        && (!D.samePoint(admitted, a.admittedAt) || digest != a.cell.commitment))
            ) _invalid();
            digest = a.cell.commitment;
            admitted = a.admittedAt;
            found = true;
        }
        if (!found) _invalid();
        bool observed;
        for (uint256 i; i < p.aliases[2].length; ++i) {
            RH.ReplayAlias memory a = p.aliases[2][i];
            if (
                a.surface != OBSERVED || a.scope != keccak256(abi.encode(identity.artistId, digest))
            ) continue;
            if (
                a.cell.kind != 1 || a.cell.status != 2 || a.cell.commitment != digest
                    || Clock.compare(p, a.admittedAt, admitted) > 0
            ) _invalid();
            observed = true;
        }
        bool consumed;
        for (uint256 i; i < identity.nonces.length; ++i) {
            IH.NonceLane memory row = identity.nonces[i];
            if (row.kind != kind || row.key != lane) continue;
            for (uint256 j; j < row.words.length; ++j) {
                if (
                    row.words[j].prefix == nonce >> 8
                        && (row.words[j].words[0] & (uint256(1) << uint8(nonce))) != 0
                ) consumed = true;
            }
        }
        if (!observed || !consumed) _invalid();
    }

    function _grant(
        IdentityRows memory identity,
        RH.Provenance memory p,
        AD.Record memory record,
        RH.Point memory admitted
    ) private pure returns (uint256 index) {
        bool found;
        for (uint256 i; i < identity.delegations.length; ++i) {
            IH.DelegationRow memory row = identity.delegations[i];
            if (row.recordHash != record.standing.delegation) continue;
            if (
                found || row.record.grant.artistId != identity.artistId
                    || row.record.grant.delegate != record.signer
                    || (row.record.grant.collectionId != 0
                        && row.record.grant.collectionId != record.terms.collectionId)
                    || (row.record.grant.capabilities & 16) == 0
                    || record.recordedAt < row.record.grant.notBefore
                    || record.recordedAt >= row.record.grant.expiresAt
                    || !Clock.before(p, row.position.point, admitted)
            ) _invalid();
            if (
                row.record.revoked
                    && !Clock.before(p, admitted, _revocation(p, row.record.revocationRecordHash))
            ) _invalid();
            for (uint256 j = i + 1; j < identity.delegations.length; ++j) {
                if (
                    identity.delegations[j].record.grant.delegate == row.record.grant.delegate
                        && !Clock.before(p, admitted, identity.delegations[j].position.point)
                ) _invalid();
            }
            index = i;
            found = true;
        }
        if (!found) _invalid();
    }

    function _revocation(RH.Provenance memory p, bytes32 hash)
        private
        pure
        returns (RH.Point memory)
    {
        for (uint256 i; i < p.journals[2].length; ++i) {
            if (
                p.journals[2][i].receipt.operation == 27
                    && p.journals[2][i].receipt.recordHash == hash
            ) return p.journals[2][i].position.point;
        }
        _invalid();
    }

    function _veto(
        IdentityRows memory identity,
        RH.Provenance memory p,
        D.RepudiationRow memory row
    ) private pure {
        uint256 matches;
        for (uint256 i; i < identity.contests.length; ++i) {
            IH.ContestRow memory c = identity.contests[i];
            if (c.record.terms.evidenceHash != row.record.recordHash) continue;
            Contest.Record memory r = c.record;
            if (
                r.terms.artistId != identity.artistId || r.terms.subjectRecordHash != 0
                    || r.terms.reasonHash != row.terminal.reasonHash
                    || r.contester != row.terminal.actor || r.contestedAt != row.terminal.recordedAt
                    || (!_member(identity, row.record.capturedGuardianSet, row.terminal.actor)
                        && !_member(identity, r.guardianSetRecordHash, row.terminal.actor))
                    || c.position.point.environmentHash != row.terminalPoint.environmentHash
            ) _invalid();
            uint256 occurrences;
            for (uint256 j; j < p.journals[2].length; ++j) {
                RH.JournalEntry memory n = p.journals[2][j];
                if (
                    n.receipt.operation == 48 && n.receipt.recordHash == r.recordHash
                        && n.receipt.collectionId == row.record.terms.collectionId
                        && D.samePoint(n.position.point, c.position.point)
                ) ++occurrences;
            }
            if (occurrences != 1) _invalid();
            uint256 causes;
            for (uint256 j; j < identity.causes.length; ++j) {
                IH.CauseRow memory cause = identity.causes[j];
                if (cause.cause.facts.referenceHash != r.recordHash) continue;
                if (
                    cause.cause.facts.kind != 1 || cause.cause.facts.artistId != identity.artistId
                        || cause.cause.facts.actor != row.terminal.actor
                        || cause.cause.facts.evidenceHash != row.record.recordHash
                        || cause.cause.facts.reasonHash != row.terminal.reasonHash
                        || cause.cause.facts.enteredAt != row.terminal.recordedAt
                        || !D.samePoint(cause.point, c.position.point)
                ) _invalid();
                ++causes;
            }
            if (causes != 1) _invalid();
            ++matches;
        }
        if (matches != 1) _invalid();
    }

    function _member(IdentityRows memory identity, bytes32 hash, address actor)
        private
        pure
        returns (bool)
    {
        if (hash == 0) return false;
        for (uint256 i; i < identity.guardians.length; ++i) {
            if (identity.guardians[i].record.recordHash != hash) continue;
            if (identity.guardians[i].record.terms.artistId != identity.artistId) _invalid();
            for (uint256 j; j < identity.guardians[i].record.terms.guardians.length; ++j) {
                if (identity.guardians[i].record.terms.guardians[j] == actor) return true;
            }
        }
        return false;
    }

    function _signature(IdentityRows memory identity, bytes32 hash) private pure {
        _signatureRows(identity.signatures, hash);
    }

    function _signatureRows(IH.SignatureRow[] memory signatures, bytes32 hash) private pure {
        uint256 found;
        for (uint256 i; i < signatures.length; ++i) {
            if (signatures[i].recordHash != hash) continue;
            if (signatures[i].signature.length > 4096) _invalid();
            ++found;
        }
        if (found != 1) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
