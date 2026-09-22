// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformPayload as Payload
} from "./StreamArtistRecoveredPlatformPayload.sol";
import {
    StreamArtistRecoveredPlatformTransitionProof as Transition
} from "./StreamArtistRecoveredPlatformTransitionProof.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistPlatformCorrectionState as State
} from "./StreamArtistPlatformCorrectionState.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";

import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistCollaboratorHashes as Collaborators
} from "./StreamArtistCollaboratorHashes.sol";

/// @notice Fixed shared original/record-history validation body; all full typed inputs are retained.
library StreamArtistPrimaryCollaboratorProposalProof {
    function advance(
        P.Platform memory platform,
        CB.Bundle memory bindings,
        A.Generation[] memory generations,
        P.Cursor memory cursor,
        RH.OwnerProvenance memory p,
        uint256 era,
        H.Envelope memory e,
        bool includeRecords
    ) public pure returns (P.Cursor memory) {
        uint256 index = cursor.generation;
        if (e.operation != 1 || index >= bindings.bindings.rows.length) _invalid();
        if (
            index != 0
                && cursor.completed
                    != (bindings.bindings.rows[index - 1].item.accepted
                            || bindings.bindings.rows[index - 1].terminal.kind != 0)
        ) _invalid();
        T.Binding memory b = abi.decode(abi.encode(bindings.bindings.rows[index].item), (T.Binding));
        b.accepted = false;
        A.Generation memory generation = generations[index];
        if (
            e.value != b.bindingHash || b.proposer != e.actor
                || generation.proposal.environmentHash != p.eras[era].originHash
                || e.after_[0].revision != generation.proposal.ownerRevision
                || e.before_[0].revision + 1 != e.after_[0].revision
        ) _invalid();
        T.BindingProposal memory proposal;
        bytes32 action;
        bytes32 nextState;
        if (bindings.corrections[index].recordHash == 0) {
            Payload.Proposal memory data = Payload.proposal(e.payload);
            if (data.id != platform.collectionId || data.reused != (data.proposal.artistId != 0)) {
                _invalid();
            }
            proposal = data.proposal;
        } else {
            Payload.Correction memory data = Payload.correction(e.payload);
            if (
                data.id != platform.collectionId || data.reused != (data.proposal.artistId != 0)
                    || keccak256(abi.encode(data.approval))
                        != keccak256(abi.encode(bindings.corrections[index].approval))
                    || data.approval.proposalHash
                        != keccak256(
                            abi.encode(data.id, data.proposal, data.document, data.displayName)
                        ) || data.context.scopeHash != data.approval.governance.scopeHash
                    || data.context.oldValueHash != data.approval.governance.oldValueHash
                    || data.context.newValueHash != data.approval.governance.newValueHash
                    || data.repudiation
                        != (data.approval.cause == 3 ? data.approval.causeRecord : bytes32(0))
            ) {
                _invalid();
            }
            proposal = data.proposal;
            if (State.tagged(data.approval.causeData)) {
                PL.Witness memory witness = State.decode(data.approval.causeData);
                if (
                    index == 0 || cursor.continuations >= platform.continuations.length
                        || cursor.state.declaration.recordHash == 0
                        || cursor.state.contestState != 3
                        || cursor.state.correction.correctiveGeneration == 0
                        || keccak256(abi.encode(witness.platform))
                            != keccak256(abi.encode(State.pins(cursor.state)))
                        || keccak256(abi.encode(witness.prior))
                            != keccak256(abi.encode(cursor.status))
                ) _invalid();
                PL.Record memory r = platform.continuations[cursor.continuations].record;
                if (cursor.continuations == 0) {
                    if (cursor.generation != cursor.state.correction.correctiveGeneration) {
                        _invalid();
                    }
                } else if (
                    platform.continuations[cursor.continuations - 1].record.generation
                        != cursor.generation
                ) {
                    _invalid();
                }
                PL.Record memory expected = PL.Record(
                    0,
                    platform.collectionId,
                    cursor.state.declaration.recordHash,
                    cursor.state.correction.recordHash,
                    cursor.status.latestLineageRecord,
                    data.approval.previous.bindingHash,
                    uint64(index),
                    b.bindingHash,
                    b.generation,
                    b.artistId,
                    b.artistAddress,
                    bindings.corrections[index].recordHash,
                    data.approval.governance.actionId,
                    data.approval.approvedAt
                );
                RH.OriginEnvironment memory o = p.origins[era];
                expected.recordHash = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_BINDING_CONTINUATION_RECORD_V1"),
                        o.chainId,
                        o.registry,
                        o.core,
                        o.manager,
                        o.owners[4],
                        expected
                    )
                );
                if (keccak256(abi.encode(r)) != keccak256(abi.encode(expected))) _invalid();
                ++cursor.continuations;
                cursor.status = PL.Status(
                    cursor.state.correction.recordHash,
                    r.recordHash,
                    b.generation,
                    uint64(cursor.continuations),
                    cursor.status.effectiveAccepted,
                    cursor.status.latestAcceptanceRecord
                );
                action = keccak256(
                    abi.encode(
                        platform.collectionId,
                        b,
                        proposal.reasonHash,
                        proposal.reasonURI,
                        bindings.corrections[index].recordHash,
                        r.recordHash
                    )
                );
                nextState = keccak256(
                    abi.encode(
                        platform.collectionId, uint8(1), b.generation, r.recordHash, cursor.status
                    )
                );
            }
        }
        _proposal(proposal, b, bindings.bindings.rows[index].terms);
        if (nextState == 0) {
            if (cursor.state.declaration.recordHash != 0) {
                if (
                    cursor.state.contestState != 3 || cursor.state.correction.recordHash == 0
                        || cursor.state.correction.correctiveGeneration != 0
                        || b.artistAddress != cursor.state.correction.proposedArtist
                ) _invalid();
                cursor.state.correction.correctiveGeneration = b.generation;
            }
            action = keccak256(
                abi.encode(platform.collectionId, b, proposal.reasonHash, proposal.reasonURI)
            );
            nextState = keccak256(abi.encode(platform.collectionId, uint8(1), b.generation));
        }
        if (includeRecords) {
            Transition.validateWithRecords(p.origins[era], p, era, e, action, nextState, 0, 0);
        } else {
            Transition.validate(p.origins[era], p, era, e, action, nextState, 0, 0);
        }
        ++cursor.generation;
        cursor.completed = false;
        return cursor;
    }

    function _proposal(T.BindingProposal memory p, T.Binding memory b, C.BindingTerms memory terms)
        private
        pure
    {
        if (
            (p.artistId != 0 && p.artistId != b.artistId) || p.artistAddress != b.artistAddress
                || p.identityRecordHash != b.identityRecordHash || p.consentMode != b.consentMode
                || p.saleConsentScope != b.saleConsentScope
                || p.registryImmutabilityElection != b.registryImmutabilityElection
                || p.collabPolicyMode != 0 || p.collabThreshold != 0
                || p.collaborators.length != terms.count
                || Collaborators.collaboratorSetHash(p.collaborators) != terms.collaboratorSetHash
                || p.capabilityPolicyOverrides.length != 0 || bytes(p.reasonURI).length > 2048
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
