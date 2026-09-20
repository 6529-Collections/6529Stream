// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
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
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle as Lifecycle
} from "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistCollaboratorHashes as Collaborators
} from "./StreamArtistCollaboratorHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

import {
    StreamArtistRecoveredBindingGenerations as Original
} from "./StreamArtistRecoveredBindingGenerations.sol";

import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistBindingCorrectionTypes as BC
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistBindingCorrectionState as State
} from "./StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistBindingCorrectionHashes as CorrectionHash
} from "./StreamArtistBindingCorrectionHashes.sol";

/// @notice Complete original pending-generation approval/history validation before op60 writes.
/// @dev This additive codec preserves legacy empty approval rows, but authenticates every
/// nonempty class2 approval and its extra replay key. Accepted former generations and Platform
/// declaration histories require their complete separate Attribution/Acceptance composition.
library StreamArtistRecoveredBindingCorrectionValidation {
    uint256 internal constant MAX_GENERATIONS = 128;
    bytes32 private constant PROPOSAL = keccak256("binding_lifecycle.replay.proposal_key");
    bytes32 private constant REFUSAL = keccak256("binding_lifecycle.replay.refusal_uniqueness");
    bytes32 private constant WITHDRAWAL =
        keccak256("binding_lifecycle.replay.proposal_terminal_transition_key");

    function validate(CB.Bundle memory corrected, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
    {
        Original.Bundle memory b = corrected.bindings;
        if (Provenance.validateOwner(p, 0) != b.provenanceCommitment) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        uint256 count = b.rows.length;
        if (count < 2 || count > MAX_GENERATIONS) revert T.UnsupportedProfile();
        if (
            q.artistId == 0 || q.collectionId == 0 || q.bindingHash == 0 || b.artistId != q.artistId
                || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                || b.current.bindingHash != q.bindingHash
                || keccak256(abi.encode(b.current)) != keccak256(abi.encode(b.rows[count - 1].item))
        ) _invalid();
        uint256 cursor;
        RH.OriginEnvironment memory origin = p.origins[0];
        for (uint256 i; i < count; ++i) {
            Original.Row memory r = b.rows[i];
            _row(r, q, uint64(i + 1), i + 1 == count, origin);
            _native(p, cursor++, q, 1, r.item.bindingHash, uint64(2 * i + 1));
            if (r.terminal.kind == 1) {
                _native(p, cursor++, q, 3, r.terminal.recordHash, uint64(2 * i + 2));
            }
        }
        if (cursor != p.journal.length) _invalid();
        uint256 corrections = _corrections(corrected, q, p);
        if (corrections == 0) _invalid();
        uint256 guards = 2 * count - 1 + corrections;
        for (uint256 i; i < p.eras.length; ++i) {
            RH.OwnerEra memory era = p.eras[i];
            if (
                era.nativeCount != (i == 0 ? cursor : 0) || era.lowerRevision != (i == 0 ? 0 : 1)
                    || era.checkpoint.ownerState.revision != (i == 0 ? 2 * count : 1)
                    || era.checkpoint.replayCount != guards || era.checkpoint.nonceIndexCount != 0
                    || era.checkpoint.nonceRoot != 0
            ) _invalid();
        }
        if (p.aliases.length != guards * p.eras.length) _invalid();
        _guards(corrected, p);
    }

    function _row(
        Original.Row memory r,
        AH.Query memory q,
        uint64 generation,
        bool last,
        RH.OriginEnvironment memory o
    ) private pure {
        if (
            r.item.artistId != q.artistId || r.item.artistAddress == address(0)
                || r.item.identityRecordHash == 0 || r.item.proposer == address(0)
                || r.item.generation != generation || r.item.accepted != last
                || (r.item.consentMode != 1 && r.item.consentMode != 2)
                || r.item.saleConsentScope > 1 || r.item.registryImmutabilityElection > 1
                || r.terms.count != 0 || r.terms.mode != 0 || r.terms.threshold != 0
                || r.terms.collaboratorSetHash != Hashes.emptyCollaborators()
                || r.terms.capabilityPolicySetHash != Hashes.emptyCapabilities()
        ) _invalid();
        if (
            Collaborators.binding(
                    Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                    q.collectionId,
                    r.item,
                    new T.CollaboratorRecord[](0)
                ) != r.item.bindingHash
        ) _invalid();
        if (last) {
            L.Terminal memory empty;
            if (keccak256(abi.encode(r.terminal)) != keccak256(abi.encode(empty))) _invalid();
        } else if (
            r.terminal.reasonHash == 0 || (r.terminal.kind != 1 && r.terminal.kind != 2)
                || (r.terminal.kind == 1 && r.terminal.recordHash == 0)
                || (r.terminal.kind == 2 && r.terminal.recordHash != 0)
        ) {
            _invalid();
        }
    }

    function _native(
        RH.OwnerProvenance memory p,
        uint256 at,
        AH.Query memory q,
        uint16 operation,
        bytes32 record,
        uint64 revision
    ) private pure {
        if (at >= p.journal.length) _invalid();
        RH.JournalEntry memory row = p.journal[at];
        if (
            row.receipt.operation != operation || row.receipt.recordHash != record
                || row.receipt.artistId != q.artistId || row.receipt.collectionId != q.collectionId
                || row.position.point.environmentHash != p.eras[0].originHash
                || row.position.point.ownerRevision != revision
        ) _invalid();
        for (uint256 i; i < at; ++i) {
            if (p.journal[i].receipt.recordHash == record) _invalid();
        }
    }

    function _guards(CB.Bundle memory corrected, RH.OwnerProvenance memory p) private pure {
        Original.Bundle memory b = corrected.bindings;
        // Provenance validates canonical sorted unique keys and the count in EVERY era.
        // Original proposal/terminal keys plus every distinct original corrective action
        // cover the complete rekeyed set. No caller-selected alias subset is projected.
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            bool found;
            for (uint256 j; j < b.rows.length; ++j) {
                if (a.surface == CB.ACTION) {
                    State.Correction memory correction = corrected.corrections[j];
                    if (
                        correction.recordHash == 0
                            || a.scope != correction.approval.governance.actionId
                    ) continue;
                    if (
                        a.cell.kind != 1 || a.cell.status != 2
                            || a.cell.commitment != correction.recordHash
                            || a.admittedAt.environmentHash != p.eras[0].originHash
                            || a.admittedAt.ownerRevision != uint64(2 * j + 1)
                    ) _invalid();
                    found = true;
                    break;
                }
                if (a.scope != keccak256(abi.encode(b.collectionId, uint64(j + 1)))) continue;
                Original.Row memory r = b.rows[j];
                bool proposal = a.surface == PROPOSAL;
                bytes32 record = proposal ? r.item.bindingHash : r.terminal.recordHash;
                if (!proposal) {
                    if (r.terminal.kind == 1 && a.surface == REFUSAL) { } else if (
                        r.terminal.kind == 2 && a.surface == WITHDRAWAL
                    ) {
                        record = r.item.bindingHash;
                    } else {
                        _invalid();
                    }
                }
                if (
                    a.cell.kind != 1 || a.cell.status != 2 || a.cell.commitment != record
                        || a.admittedAt.environmentHash != p.eras[0].originHash
                        || a.admittedAt.ownerRevision != uint64(2 * j + (proposal ? 1 : 2))
                ) _invalid();
                found = true;
                break;
            }
            if (!found) _invalid();
        }
    }

    function _corrections(
        CB.Bundle memory corrected,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) private pure returns (uint256 count) {
        Original.Bundle memory b = corrected.bindings;
        if (corrected.corrections.length != b.rows.length) _invalid();
        State.Correction memory empty;
        AD.Head memory noDispute;
        RH.OriginEnvironment memory o = p.origins[0];
        for (uint256 i; i < corrected.corrections.length; ++i) {
            State.Correction memory row = corrected.corrections[i];
            if (row.recordHash == 0) {
                if (keccak256(abi.encode(row)) != keccak256(abi.encode(empty))) _invalid();
                continue;
            }
            if (i == 0) _invalid();
            BC.Approval memory a = row.approval;
            Original.Row memory previous = b.rows[i - 1];
            if (
                a.previous.accepted || (a.cause != 1 && a.cause != 2)
                    || keccak256(abi.encode(a.previous)) != keccak256(abi.encode(previous.item))
                    || a.cause != previous.terminal.kind
                    || a.causeRecord
                        != (a.cause == 1 ? previous.terminal.recordHash : previous.item.bindingHash)
                    || keccak256(a.causeData) != keccak256(abi.encode(previous.terminal, noDispute))
                    || a.proposalHash == 0 || a.proposedArtistId != q.artistId
                    || a.registrationNonce != 0 || a.approvedAt == 0 || a.governance.actionId == 0
                    || a.governance.proposer == address(0) || a.governance.actionClass != 2
            ) _invalid();
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
            bytes32 newValue = keccak256(
                abi.encode(scope, oldValue, a.proposalHash, a.proposedArtistId, a.registrationNonce)
            );
            if (
                a.governance.scopeHash != scope || a.governance.oldValueHash != oldValue
                    || a.governance.newValueHash != newValue
                    || row.recordHash
                        != CorrectionHash.hash(
                            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                            q.collectionId,
                            b.rows[i].item.bindingHash,
                            a
                        )
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    corrected.corrections[j].recordHash != 0
                        && (corrected.corrections[j].recordHash == row.recordHash
                            || corrected.corrections[j].approval.governance.actionId
                                == a.governance.actionId)
                ) _invalid();
            }
            ++count;
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
