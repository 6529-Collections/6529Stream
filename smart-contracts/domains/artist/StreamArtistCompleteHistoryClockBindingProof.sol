// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistCompleteHistoryBindingLeaves as BindingLeaves
} from "./StreamArtistCompleteHistoryBindingLeaves.sol";
import {
    StreamArtistPrimaryCollaboratorProposalProof as Proposal
} from "./StreamArtistPrimaryCollaboratorProposalProof.sol";
import {
    StreamArtistCompleteHistoryPlatformProof as Platform
} from "./StreamArtistCompleteHistoryPlatformProof.sol";
import {
    StreamArtistRecoveredPlatformPayload as Payload
} from "./StreamArtistRecoveredPlatformPayload.sol";
import {
    StreamArtistRecoveredPlatformTransitionProof as Transition
} from "./StreamArtistRecoveredPlatformTransitionProof.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import {
    StreamArtistCurrentAuthorityFacts as Authority
} from "./StreamArtistCurrentAuthorityFacts.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

/// @notice Original binding transitions across complete principal and Platform histories.
/// @dev A pending head may cross a verified import boundary. Its original proposal and
/// later completion are compared only on their own authenticated owner clocks.
library StreamArtistCompleteHistoryClockBindingProof {
    struct Context {
        AH.Query query;
        CB.Bundle binding;
        A.Generation[] generations;
        T.CollaboratorRecord[] collaborators;
        P.Platform platform;
        P.Cursor cursor;
        RH.OwnerProvenance owner0;
        RH.OwnerProvenance owner4;
        uint256 era;
        H.Envelope envelope;
        uint256 generation;
    }

    struct Completion {
        P.Platform platform;
        P.Cursor cursor;
        uint256 collectionId;
        T.Binding binding;
        RH.OwnerProvenance owner4;
        uint256 era;
        H.Envelope envelope;
        uint256 generation;
        RH.Point proposal;
    }

    function proposal(Context memory x) public pure returns (P.Cursor memory) {
        A.Generation memory generation = x.generations[x.generation];
        if (
            x.generation != x.cursor.generation
                || (x.generation != 0
                    && !x.cursor.completed
                    && x.binding.corrections[x.generation].approval.cause != 4)
                || generation.generation != x.generation + 1
                || generation.bindingHash != x.binding.bindings.rows[x.generation].item.bindingHash
                || generation.accepted != x.binding.bindings.rows[x.generation].item.accepted
                || generation.proposal.ownerIndex != 0
                || x.platform.collectionId != x.query.collectionId
        ) _invalid();
        BindingLeaves.row(
            x.binding.bindings.rows[x.generation],
            x.query,
            uint64(x.generation + 1),
            x.owner4.origins[x.era],
            x.collaborators
        );
        BindingLeaves.correction(x.binding, x.query, x.generation, x.owner4.origins[x.era]);
        _registration(x);
        _fixedFrames(
            x.envelope,
            0x15,
            x.envelope.after_[2].revision == x.envelope.before_[2].revision ? 0x11 : 0x15
        );
        return Proposal.advance(
            x.platform, x.binding, x.generations, x.cursor, x.owner4, x.era, x.envelope, true
        );
    }

    function _registration(Context memory x) private pure {
        T.Binding memory b = x.binding.bindings.rows[x.generation].item;
        if (x.binding.corrections[x.generation].recordHash == 0) return;
        Payload.Correction memory data = Payload.correction(x.envelope.payload);
        if (data.reused) {
            if (data.approval.registrationNonce != 0 || data.proposal.artistId != b.artistId) {
                _invalid();
            }
        } else {
            RH.OriginEnvironment memory o = x.owner4.origins[x.era];
            if (
                data.proposal.artistId != 0
                    || Hashes.identity(
                            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                            b.artistAddress,
                            b.identityRecordHash,
                            data.approval.registrationNonce
                        ) != b.artistId
                    || x.envelope.after_[2].revision != x.envelope.before_[2].revision + 1
            ) _invalid();
        }
    }

    function terminal(Context memory x) public pure returns (P.Cursor memory) {
        H.Envelope memory e = x.envelope;
        if (
            (e.operation != 3 && e.operation != 4) || x.cursor.generation == 0 || x.cursor.completed
                || x.cursor.generation != x.generation + 1 || x.generations[x.generation].accepted
                || !Clock.beforeOwner(
                    x.owner0,
                    0,
                    x.generations[x.generation].proposal,
                    RH.Point(x.owner4.eras[x.era].originHash, 0, e.after_[0].revision)
                )
        ) _invalid();
        _fixedFrames(e, e.operation == 3 ? 0x15 : 0x11, e.operation == 3 ? 0x15 : 0x11);
        T.Binding memory b =
            abi.decode(abi.encode(x.binding.bindings.rows[x.generation].item), (T.Binding));
        b.accepted = false;
        L.Termination memory terms;
        address signer;
        uint8 authority;
        uint256 nonce;
        L.Terminal memory saved = x.binding.bindings.rows[x.generation].terminal;
        if (e.operation == 3) {
            Payload.Refusal memory r = Payload.refusal(e.payload);
            if (
                keccak256(abi.encode(r.binding_)) != keccak256(abi.encode(b)) || saved.kind != 1
                    || saved.recordHash != e.value
            ) _invalid();
            Authority.requirePrincipal(b.artistId, r.proof.signer, r.authority, false);
            terms = r.terms;
            signer = r.proof.signer;
            authority = r.authority.authorityClass;
            nonce = r.authorization.nonce;
        } else {
            T.Binding memory original;
            (original, terms) = abi.decode(e.payload, (T.Binding, L.Termination));
            if (
                keccak256(e.payload) != keccak256(abi.encode(original, terms))
                    || keccak256(abi.encode(original)) != keccak256(abi.encode(b))
                    || saved.kind != 2 || e.value != b.bindingHash || e.actor != b.proposer
            ) _invalid();
            signer = e.actor;
        }
        if (
            terms.collectionId != x.query.collectionId || terms.generation != b.generation
                || terms.bindingHash != b.bindingHash || terms.reasonHash == 0
                || terms.reasonHash != saved.reasonHash
        ) _invalid();
        Transition.validateWithRecords(
            x.owner4.origins[x.era],
            x.owner4,
            x.era,
            e,
            keccak256(abi.encode(b, terms, signer, authority, nonce, e.value)),
            keccak256(abi.encode(x.query.collectionId, AS.Attribution(5, b.generation))),
            0,
            0
        );
        x.cursor.completed = true;
        return x.cursor;
    }

    function complete(Completion memory x) public pure returns (P.Cursor memory) {
        RH.Point memory point =
            RH.Point(x.owner4.eras[x.era].originHash, 4, x.envelope.after_[4].revision);
        if (!Clock.beforeOwner(x.owner4, 4, x.proposal, point)) _invalid();
        T.Binding memory pending = abi.decode(abi.encode(x.binding), (T.Binding));
        pending.accepted = false;
        bytes32 continuation;
        (x.cursor, continuation) = Platform.complete(
            x.platform, x.cursor, pending, x.envelope.value, x.owner4.origins[x.era]
        );
        bytes32 nextState = continuation == 0
            ? keccak256(abi.encode(x.collectionId, AS.Attribution(2, uint64(x.generation + 1))))
            : keccak256(
                abi.encode(
                    x.collectionId, AS.Attribution(2, uint64(x.generation + 1)), continuation
                )
            );
        Transition.validateWithRecords(
            x.owner4.origins[x.era],
            x.owner4,
            x.era,
            x.envelope,
            keccak256(abi.encode(x.collectionId, pending, x.envelope.value)),
            nextState,
            0,
            0
        );
        x.cursor.completed = true;
        return x.cursor;
    }

    function _fixedFrames(H.Envelope memory e, uint256 observed, uint256 changed) private pure {
        T.Snapshot memory zero;
        for (uint8 i; i < 7; ++i) {
            if ((observed & (1 << i)) == 0) {
                if (
                    keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(zero))
                        || keccak256(abi.encode(e.after_[i])) != keccak256(abi.encode(zero))
                ) _invalid();
            } else if ((changed & (1 << i)) != 0) {
                if (e.after_[i].revision != e.before_[i].revision + 1) _invalid();
            } else if (keccak256(abi.encode(e.before_[i])) != keccak256(abi.encode(e.after_[i]))) {
                _invalid();
            }
        }
    }

    function bounds(uint64[7] memory lower, uint64[7] memory upper, H.Envelope memory e)
        public
        pure
    {
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory a = e.before_[i];
            T.Snapshot memory b = e.after_[i];
            if (a.domainId == 0 && b.domainId == 0) continue;
            if (
                a.domainId != RH.ownerDomain(i) || b.domainId != a.domainId || a.stateRoot == 0
                    || b.stateRoot == 0 || a.recordChainTip == 0 || b.recordChainTip == 0
                    || a.revision < lower[i] || b.revision > upper[i] || b.revision < a.revision
                    || b.revision > a.revision + 1
            ) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
