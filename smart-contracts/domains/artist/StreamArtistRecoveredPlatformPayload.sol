// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistBindingCorrectionTypes as BC
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Canonical original Archive payloads; no new producer encoding or inferred actor.
library StreamArtistRecoveredPlatformPayload {
    struct Claim {
        uint256 id;
        bytes32 evidence;
        bytes32 reason;
        string uri;
        PW.Evidence evidenceDocument;
        PW.Evidence reasonDocument;
        bytes32 evidenceProof;
        bytes32 reasonProof;
    }

    struct ContestPayload {
        uint256 id;
        uint8 state;
        bytes32 claim;
        bytes32 evidence;
        bytes32 reason;
        bool correction;
        PW.Context context;
        Contest.GovernanceWitness governance;
        PW.Evidence evidenceDocument;
        PW.Evidence reasonDocument;
        bytes32 evidenceProof;
        bytes32 reasonProof;
    }

    struct Proposal {
        uint256 id;
        T.BindingProposal proposal;
        bytes document;
        string displayName;
        bool reused;
        bytes32 roleHash;
        uint64 roleRevision;
    }

    struct Correction {
        bytes32 tag;
        uint16 version;
        uint256 id;
        T.BindingProposal proposal;
        bytes document;
        string displayName;
        bool reused;
        bytes32 roleHash;
        uint64 roleRevision;
        bytes32 repudiation;
        BC.Context context;
        BC.Approval approval;
    }

    struct Acceptance {
        uint256 id;
        T.Binding binding_;
        T.Authorization authorization;
        T.SignerApproval proof;
    }

    struct ExpectedAcceptance {
        uint256 id;
        T.Binding binding_;
        T.Authorization authorization;
        T.SignerApproval proof;
        uint64 generation;
        bytes32 hash;
    }

    struct Refusal {
        T.Binding binding_;
        L.Termination terms;
        T.Authorization authorization;
        T.SignerApproval proof;
        R.AuthorityFact authority;
    }

    function claim(bytes memory raw) public pure returns (Claim memory r) {
        r = abi.decode(_tuple(raw), (Claim));
        if (
            keccak256(raw)
                != keccak256(
                    abi.encode(
                        r.id,
                        r.evidence,
                        r.reason,
                        r.uri,
                        r.evidenceDocument,
                        r.reasonDocument,
                        r.evidenceProof,
                        r.reasonProof
                    )
                )
        ) _invalid();
    }

    function contest(bytes memory raw) public pure returns (ContestPayload memory r) {
        // This tuple is entirely static and therefore has no outer offset.
        r = abi.decode(raw, (ContestPayload));
        if (keccak256(raw) != keccak256(abi.encode(r))) _invalid();
    }

    function proposal(bytes memory raw) public pure returns (Proposal memory r) {
        r = abi.decode(_tuple(raw), (Proposal));
        if (
            keccak256(raw)
                != keccak256(
                    abi.encode(
                        r.id,
                        r.proposal,
                        r.document,
                        r.displayName,
                        r.reused,
                        r.roleHash,
                        r.roleRevision
                    )
                )
        ) _invalid();
    }

    function correction(bytes memory raw) public pure returns (Correction memory r) {
        r = abi.decode(_tuple(raw), (Correction));
        if (
            r.tag != BC.DETAIL || r.version != 1
                || keccak256(raw)
                    != keccak256(
                        abi.encode(
                            r.tag,
                            r.version,
                            r.id,
                            r.proposal,
                            r.document,
                            r.displayName,
                            r.reused,
                            r.roleHash,
                            r.roleRevision,
                            r.repudiation,
                            r.context,
                            r.approval
                        )
                    )
        ) _invalid();
    }

    function acceptance(bytes memory raw)
        public
        pure
        returns (Acceptance memory a, R.AuthorityFact memory authority)
    {
        bytes memory inner;
        (inner, authority) = abi.decode(raw, (bytes, R.AuthorityFact));
        if (keccak256(raw) != keccak256(abi.encode(inner, authority))) _invalid();
        // The authorization offset is after exactly id, Binding and the tuple's other heads.
        // Decode the common prefix, then choose by canonical equality; no trailing data accepted.
        a = abi.decode(_tuple(inner), (Acceptance));
        if (keccak256(inner) == keccak256(abi.encode(a.id, a.binding_, a.authorization, a.proof))) {
            return (a, authority);
        }
        ExpectedAcceptance memory e = abi.decode(_tuple(inner), (ExpectedAcceptance));
        if (
            e.generation != e.binding_.generation || e.hash != e.binding_.bindingHash
                || keccak256(inner)
                    != keccak256(
                        abi.encode(e.id, e.binding_, e.authorization, e.proof, e.generation, e.hash)
                    )
        ) _invalid();
        a = Acceptance(e.id, e.binding_, e.authorization, e.proof);
    }

    function refusal(bytes memory raw) public pure returns (Refusal memory r) {
        r = abi.decode(_tuple(raw), (Refusal));
        if (
            keccak256(raw)
                != keccak256(abi.encode(r.binding_, r.terms, r.authorization, r.proof, r.authority))
        ) _invalid();
    }

    function _tuple(bytes memory raw) private pure returns (bytes memory) {
        return bytes.concat(bytes32(uint256(32)), raw);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
