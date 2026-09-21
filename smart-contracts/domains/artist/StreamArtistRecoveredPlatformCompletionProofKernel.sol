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
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistCurrentAuthorityFacts as Authority
} from "./StreamArtistCurrentAuthorityFacts.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

/// @notice Fixed shared original/record-history validation body; all full typed inputs are retained.
library StreamArtistRecoveredPlatformCompletionProofKernel {
    function advance(
        P.Platform memory platform,
        CB.Bundle memory bindings,
        A.Generation[] memory generations,
        P.Cursor memory cursor,
        RH.OwnerProvenance memory p,
        uint256 era,
        H.Envelope memory e,
        bool includeRecords
    ) public view returns (P.Cursor memory) {
        if (cursor.generation == 0 || cursor.completed || e.operation < 2 || e.operation > 4) {
            _invalid();
        }
        uint256 index = cursor.generation - 1;
        A.Generation memory generation = generations[index];
        if (
            generation.proposal.environmentHash != p.eras[era].originHash
                || e.before_[0].revision != generation.proposal.ownerRevision
                || e.after_[0].revision != generation.proposal.ownerRevision + 1
        ) _invalid();
        T.Binding memory b = abi.decode(abi.encode(bindings.bindings.rows[index].item), (T.Binding));
        b.accepted = false;
        bytes32 action;
        bytes32 nextState;
        if (e.operation == 2) {
            if (!generation.accepted) _invalid();
            (Payload.Acceptance memory a, R.AuthorityFact memory authority) =
                Payload.acceptance(e.payload);
            if (
                a.id != platform.collectionId
                    || keccak256(abi.encode(a.binding_)) != keccak256(abi.encode(b))
            ) {
                _invalid();
            }
            Authority.requirePrincipal(b.artistId, a.proof.signer, authority, false);
            RH.OriginEnvironment memory o = p.origins[era];
            uint64 at = Acceptance(o.owners[3]).acceptedAt(b.bindingHash);
            if (
                at == 0 || Acceptance(o.owners[3]).acceptanceRecord(b.bindingHash) != e.value
                    || a.proof.digest
                        != Hashes.acceptanceDigest(
                            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                            a.id,
                            b,
                            a.authorization
                        )
                    || a.proof.direct
                        != (e.actor == a.proof.signer && a.authorization.signature.length == 0)
                    || e.value
                        != Hashes.acceptanceRecordForAuthority(
                            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                            a.id,
                            b,
                            a.proof.signer,
                            authority.authorityClass,
                            a.authorization.nonce,
                            at
                        )
            ) _invalid();
            bytes32 continuation;
            if (cursor.status.latestLineageRecord != 0 && cursor.status.generation == b.generation)
            {
                P.ContinuationRow memory row = platform.continuations[cursor.continuations - 1];
                PL.Acceptance memory expected = PL.Acceptance(0, row.record.recordHash, e.value, at);
                expected.recordHash = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_BINDING_CONTINUATION_ACCEPTANCE_V1"),
                        o.chainId,
                        o.owners[4],
                        a.id,
                        b.generation,
                        expected
                    )
                );
                if (keccak256(abi.encode(row.acceptance)) != keccak256(abi.encode(expected))) {
                    _invalid();
                }
                continuation = expected.recordHash;
                cursor.status.latestAcceptanceRecord = continuation;
                cursor.status.effectiveAccepted = true;
            } else if (cursor.state.declaration.recordHash != 0) {
                if (
                    cursor.state.correction.correctiveGeneration != b.generation
                        || cursor.state.correction.accepted
                ) _invalid();
                cursor.state.correction.accepted = true;
                cursor.status.effectiveAccepted = true;
            }
            action = keccak256(abi.encode(a.id, b, e.value));
            nextState = continuation == 0
                ? keccak256(abi.encode(a.id, AS.Attribution(2, b.generation)))
                : keccak256(abi.encode(a.id, AS.Attribution(2, b.generation), continuation));
        } else {
            if (generation.accepted) _invalid();
            L.Termination memory terms;
            address signer;
            uint8 authority;
            uint256 nonce;
            if (e.operation == 3) {
                Payload.Refusal memory r = Payload.refusal(e.payload);
                if (
                    keccak256(abi.encode(r.binding_)) != keccak256(abi.encode(b))
                        || bindings.bindings.rows[index].terminal.kind != 1
                        || bindings.bindings.rows[index].terminal.recordHash != e.value
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
                        || bindings.bindings.rows[index].terminal.kind != 2
                        || e.value != b.bindingHash || e.actor != b.proposer
                ) _invalid();
                signer = e.actor;
            }
            if (
                terms.collectionId != platform.collectionId || terms.generation != b.generation
                    || terms.bindingHash != b.bindingHash || terms.reasonHash == 0
                    || terms.reasonHash != bindings.bindings.rows[index].terminal.reasonHash
            ) _invalid();
            action = keccak256(abi.encode(b, terms, signer, authority, nonce, e.value));
            nextState =
                keccak256(abi.encode(platform.collectionId, AS.Attribution(5, b.generation)));
        }
        if (includeRecords) {
            Transition.validateWithRecords(p.origins[era], p, era, e, action, nextState, 0, 0);
        } else {
            Transition.validate(p.origins[era], p, era, e, action, nextState, 0, 0);
        }
        cursor.completed = true;
        return cursor;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
