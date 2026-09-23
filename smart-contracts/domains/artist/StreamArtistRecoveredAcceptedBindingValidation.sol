// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import { StreamArtistBindingCorrectionState as CS } from "./StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistBindingCorrectionTypes as BC
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import { StreamArtistCollaboratorHashes as H } from "./StreamArtistCollaboratorHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistBindingCorrectionHashes as CorrectionHash
} from "./StreamArtistBindingCorrectionHashes.sol";

/// @notice Complete original proposal/termination clocks across imports, including accepted revocations.
/// @dev This codec admits governed44/46 causes only. Their complete original owner4 evidence is
/// independently joined by preparation; neither a current grant nor a caller-supplied generation is authority.
library StreamArtistRecoveredAcceptedBindingValidation {
    bytes32 private constant PROPOSAL = keccak256("binding_lifecycle.replay.proposal_key");
    bytes32 private constant REFUSAL = keccak256("binding_lifecycle.replay.refusal_uniqueness");
    bytes32 private constant WITHDRAWAL =
        keccak256("binding_lifecycle.replay.proposal_terminal_transition_key");

    function validate(CB.Bundle memory c, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
        returns (A.Generation[] memory generations)
    {
        G.Bundle memory b = c.bindings;
        if (P.validateOwner(p, 0) != b.provenanceCommitment) _invalid();
        uint256 n = b.rows.length;
        if (
            n < 2 || n > 128 || c.corrections.length != n || q.artistId == 0 || q.collectionId == 0
                || q.bindingHash == 0 || b.artistId != q.artistId
                || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                || !b.current.accepted || b.current.bindingHash != q.bindingHash
                || keccak256(abi.encode(b.current)) != keccak256(abi.encode(b.rows[n - 1].item))
        ) _invalid();
        generations = new A.Generation[](n);
        uint256[] memory counts = new uint256[](p.eras.length);
        uint256[] memory nativeCounts = new uint256[](p.eras.length);
        uint256[] memory addedGuards = new uint256[](p.eras.length);
        uint256 cursor;
        uint256 previousEra;
        uint256 acceptedFormer;
        for (uint256 i; i < n; ++i) {
            if (cursor >= p.journal.length) _invalid();
            RH.JournalEntry memory native_ = p.journal[cursor++];
            uint256 e = A.era(p, native_.position.point.environmentHash);
            if (e < previousEra) _invalid();
            previousEra = e;
            uint64 revision = uint64((e == 0 ? 0 : 1) + 2 * counts[e] + 1);
            G.Row memory row = b.rows[i];
            _row(row, q, uint64(i + 1), p.origins[e]);
            _native(native_, q, 1, row.item.bindingHash, revision);
            generations[i] = A.Generation(
                row.item.bindingHash, uint64(i + 1), row.item.accepted, native_.position.point
            );
            ++counts[e];
            ++nativeCounts[e];
            ++addedGuards[e];
            if (!row.item.accepted) {
                if (
                    i + 1 == n || row.terminal.reasonHash == 0
                        || (row.terminal.kind != 1 && row.terminal.kind != 2)
                ) _invalid();
                if (row.terminal.kind == 1) {
                    if (cursor >= p.journal.length || row.terminal.recordHash == 0) _invalid();
                    RH.JournalEntry memory refusal = p.journal[cursor++];
                    if (refusal.position.point.environmentHash != p.eras[e].originHash) _invalid();
                    _native(refusal, q, 3, row.terminal.recordHash, revision + 1);
                    ++nativeCounts[e];
                } else if (row.terminal.recordHash != 0) {
                    _invalid();
                }
                ++addedGuards[e];
            } else {
                L.Terminal memory empty;
                if (keccak256(abi.encode(row.terminal)) != keccak256(abi.encode(empty))) {
                    _invalid();
                }
                if (i + 1 < n) ++acceptedFormer;
            }
            if (_correction(c, q, i, p.origins[e])) ++addedGuards[e];
        }
        if (cursor != p.journal.length || acceptedFormer == 0) _invalid();
        // Original op60 imports require an accepted current collection. A pending generation
        // cannot cross an import boundary and finish later under a different original domain.
        for (uint256 i; i + 1 < n; ++i) {
            if (
                generations[i].proposal.environmentHash
                        != generations[i + 1].proposal.environmentHash && !generations[i].accepted
            ) _invalid();
        }
        uint256 guards;
        for (uint256 e; e < p.eras.length; ++e) {
            guards += addedGuards[e];
            RH.OwnerEra memory era_ = p.eras[e];
            if (
                era_.lowerRevision != (e == 0 ? 0 : 1) || era_.nativeCount != nativeCounts[e]
                    || era_.checkpoint.ownerState.revision != era_.lowerRevision + 2 * counts[e]
                    || era_.checkpoint.replayCount != guards || era_.checkpoint.nonceIndexCount != 0
                    || era_.checkpoint.nonceRoot != 0
            ) _invalid();
        }
        _guards(c, generations, p);
    }

    function _row(
        G.Row memory r,
        AH.Query memory q,
        uint64 generation,
        RH.OriginEnvironment memory o
    ) private pure {
        if (
            r.item.artistId != q.artistId || r.item.artistAddress == address(0)
                || r.item.identityRecordHash == 0 || r.item.proposer == address(0)
                || r.item.generation != generation
                || (r.item.consentMode != 1 && r.item.consentMode != 2)
                || r.item.saleConsentScope > 1 || r.item.registryImmutabilityElection > 1
                || r.terms.count != 0 || r.terms.mode != 0 || r.terms.threshold != 0
                || r.terms.collaboratorSetHash != Hashes.emptyCollaborators()
                || r.terms.capabilityPolicySetHash != Hashes.emptyCapabilities()
                || H.binding(
                        Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                        q.collectionId,
                        r.item,
                        new T.CollaboratorRecord[](0)
                    ) != r.item.bindingHash
        ) _invalid();
    }

    function _correction(
        CB.Bundle memory c,
        AH.Query memory q,
        uint256 i,
        RH.OriginEnvironment memory o
    ) private pure returns (bool) {
        CS.Correction memory row = c.corrections[i];
        if (row.recordHash == 0) {
            CS.Correction memory empty;
            if (
                keccak256(abi.encode(row)) != keccak256(abi.encode(empty))
                    || (i != 0 && c.bindings.rows[i - 1].item.accepted)
            ) _invalid();
            return false;
        }
        if (i == 0) _invalid();
        BC.Approval memory a = row.approval;
        G.Row memory previous = c.bindings.rows[i - 1];
        if (
            keccak256(abi.encode(a.previous)) != keccak256(abi.encode(previous.item))
                || a.proposalHash == 0 || a.proposedArtistId != q.artistId
                || a.registrationNonce != 0 || a.approvedAt == 0 || a.governance.actionId == 0
                || a.governance.proposer == address(0) || a.governance.actionClass != 2
        ) _invalid();
        if (previous.item.accepted) {
            if (a.cause != 4) _invalid();
            (
                L.Terminal memory terminal,
                AD.Head memory head,
                AD.Record memory opening,
                AD.Resolution memory resolution
            ) = abi.decode(a.causeData, (L.Terminal, AD.Head, AD.Record, AD.Resolution));
            if (
                keccak256(a.causeData) != keccak256(abi.encode(terminal, head, opening, resolution))
                    || keccak256(abi.encode(terminal)) != keccak256(abi.encode(previous.terminal))
                    || head.open || head.revocationReason != 4 || head.resolutionActionId == 0
                    || resolution.actionId != head.resolutionActionId
                    || a.causeRecord != resolution.actionId || resolution.actionClass != 2
                    || resolution.terms.resolution != 2 || resolution.restoredState != 5
                    || resolution.terms.collectionId != q.collectionId
                    || resolution.terms.bindingGeneration != previous.item.generation
                    || resolution.terms.disputeRecordHash != head.disputeRecordHash
                    || opening.recordHash != head.disputeRecordHash
                    || opening.bindingHash != previous.item.bindingHash
                    || opening.artistId != q.artistId
            ) _invalid();
        } else {
            AD.Head memory emptyHead;
            if (
                a.cause != previous.terminal.kind || (a.cause != 1 && a.cause != 2)
                    || a.causeRecord
                        != (a.cause == 1 ? previous.terminal.recordHash : previous.item.bindingHash)
                    || keccak256(a.causeData) != keccak256(abi.encode(previous.terminal, emptyHead))
            ) _invalid();
        }
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_SCOPE_V1"),
                o.chainId,
                o.registry,
                o.core,
                o.manager,
                q.collectionId,
                previous.item.generation
            )
        );
        bytes32 oldValue =
            keccak256(abi.encode(a.previous, uint8(5), a.cause, a.causeRecord, a.causeData));
        if (
            a.governance.scopeHash != scope || a.governance.oldValueHash != oldValue
                || a.governance.newValueHash
                    != keccak256(
                        abi.encode(
                            scope, oldValue, a.proposalHash, a.proposedArtistId, a.registrationNonce
                        )
                    )
                || row.recordHash
                    != CorrectionHash.hash(
                        Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                        q.collectionId,
                        c.bindings.rows[i].item.bindingHash,
                        a
                    )
        ) _invalid();
        for (uint256 j; j < i; ++j) {
            if (
                c.corrections[j].recordHash != 0
                    && (c.corrections[j].recordHash == row.recordHash
                        || c.corrections[j].approval.governance.actionId == a.governance.actionId)
            ) _invalid();
        }
        return true;
    }

    function _native(
        RH.JournalEntry memory row,
        AH.Query memory q,
        uint16 op,
        bytes32 hash,
        uint64 revision
    ) private pure {
        if (
            row.receipt.operation != op || row.receipt.recordHash != hash
                || row.receipt.artistId != q.artistId || row.receipt.collectionId != q.collectionId
                || row.position.point.ownerIndex != 0
                || row.position.point.ownerRevision != revision
        ) _invalid();
    }

    function _guards(CB.Bundle memory c, A.Generation[] memory gs, RH.OwnerProvenance memory p)
        private
        pure
    {
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            bool found;
            for (uint256 j; j < gs.length; ++j) {
                bytes32 expected;
                uint64 revision = gs[j].proposal.ownerRevision;
                if (a.surface == CB.ACTION) {
                    if (
                        c.corrections[j].recordHash == 0
                            || a.scope != c.corrections[j].approval.governance.actionId
                    ) continue;
                    expected = c.corrections[j].recordHash;
                } else {
                    if (a.scope != keccak256(abi.encode(c.bindings.collectionId, uint64(j + 1)))) {
                        continue;
                    }
                    if (a.surface == PROPOSAL) {
                        expected = gs[j].bindingHash;
                    } else if (
                        !gs[j].accepted && c.bindings.rows[j].terminal.kind == 1
                            && a.surface == REFUSAL
                    ) {
                        expected = c.bindings.rows[j].terminal.recordHash;
                        ++revision;
                    } else if (
                        !gs[j].accepted && c.bindings.rows[j].terminal.kind == 2
                            && a.surface == WITHDRAWAL
                    ) {
                        expected = gs[j].bindingHash;
                        ++revision;
                    } else {
                        _invalid();
                    }
                }
                if (
                    a.cell.kind != 1 || a.cell.status != 2 || a.cell.commitment != expected
                        || a.admittedAt.environmentHash != gs[j].proposal.environmentHash
                        || a.admittedAt.ownerRevision != revision
                ) _invalid();
                found = true;
                break;
            }
            if (!found) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
