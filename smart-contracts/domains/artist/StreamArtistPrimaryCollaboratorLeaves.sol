// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import { StreamArtistCollaboratorHashes as CH } from "./StreamArtistCollaboratorHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

import {
    StreamArtistRecoveredPlatformPayload as Payload
} from "./StreamArtistRecoveredPlatformPayload.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistCurrentAuthorityFacts as Authority
} from "./StreamArtistCurrentAuthorityFacts.sol";

/// @notice Canonical original ops5/6/7 Archive payloads and their original signer domains.
/// @dev These leaves require authenticated Archive envelopes. They never reauthorize an old
/// signature against a present account or fabricate the unstored op7 timestamp/class. The
/// enclosing proof joins native receipts, original signature/nonce aliases and source maps.
library StreamArtistPrimaryCollaboratorLeaves {
    function proposal(RH.OriginEnvironment memory o, H.Envelope memory e)
        public
        pure
        returns (C.IdentityProposalState memory result)
    {
        (C.IdentityProposal memory p, bytes32 roleHash, uint64 revision) =
            abi.decode(e.payload, (C.IdentityProposal, bytes32, uint64));
        if (
            e.operation != 5 || e.actor == address(0)
                || keccak256(e.payload) != keccak256(abi.encode(p, roleHash, revision))
        ) _invalid();
        if (
            p.account == address(0) || p.identityRecordHash == 0 || p.reasonHash == 0
                || bytes(p.identityRecordURI).length > 2048 || bytes(p.reasonURI).length > 2048
                || CH.proposalHash(_environment(o), p, e.actor) != e.value
        ) _invalid();
        _frames(e, 0x06, 0x02);
        result = C.IdentityProposalState(p, e.actor, e.value, bytes32(0));
    }

    function identity(RH.OriginEnvironment memory o, H.Envelope memory e)
        public
        pure
        returns (PC.IdentityAcceptance memory x)
    {
        // The original producer emits six fields, not abi.encode(one dynamic struct).
        (x.proposal, x.authorization, x.approval, x.document, x.displayName, x.allocationNonce) =
            abi.decode(
                e.payload,
                (C.IdentityProposalState, T.Authorization, T.SignerApproval, bytes, string, uint256)
            );
        if (
            e.operation != 6 || e.actor == address(0)
                || keccak256(e.payload)
                    != keccak256(
                        abi.encode(
                            x.proposal,
                            x.authorization,
                            x.approval,
                            x.document,
                            x.displayName,
                            x.allocationNonce
                        )
                    )
        ) _invalid();
        C.IdentityProposal memory p = x.proposal.proposal;
        if (
            x.proposal.proposalHash == 0 || x.proposal.acceptedArtistId != 0
                || p.account == address(0) || p.identityRecordHash == 0 || x.document.length == 0
                || x.document.length > 8192 || keccak256(x.document) != p.identityRecordHash
                || bytes(x.displayName).length == 0 || bytes(x.displayName).length > 256
                || bytes(p.identityRecordURI).length > 2048
                || Hashes.identity(
                        _environment(o), p.account, p.identityRecordHash, x.allocationNonce
                    ) != e.value
        ) _invalid();
        _approval(
            e.actor,
            p.account,
            CH.identityDigest(_environment(o), p.account, p.identityRecordHash, x.authorization),
            x.authorization,
            x.approval
        );
        _frames(e, 0x06, 0x06);
    }

    function acceptance(RH.OriginEnvironment memory o, H.Envelope memory e)
        public
        pure
        returns (PC.BindingAcceptance memory x)
    {
        (
            x.binding_,
            x.acceptance,
            x.artistId,
            x.authorization,
            x.approval,
            x.terms,
            x.priorCount,
            x.count,
            x.primaryRecord,
            x.complete
        ) =
            abi.decode(
                e.payload,
                (
                    T.Binding,
                    C.BindingAcceptance,
                    bytes32,
                    T.Authorization,
                    T.SignerApproval,
                    C.BindingTerms,
                    uint32,
                    uint32,
                    bytes32,
                    bool
                )
            );
        if (
            e.operation != 7 || e.actor == address(0) || e.value == 0
                || keccak256(e.payload)
                    != keccak256(
                        abi.encode(
                            x.binding_,
                            x.acceptance,
                            x.artistId,
                            x.authorization,
                            x.approval,
                            x.terms,
                            x.priorCount,
                            x.count,
                            x.primaryRecord,
                            x.complete
                        )
                    )
        ) _invalid();
        C.BindingAcceptance memory p = x.acceptance;
        if (
            x.binding_.accepted || x.binding_.bindingHash == 0 || x.artistId == 0
                || p.collectionId == 0 || p.generation == 0 || p.account == address(0)
                || p.bindingHash != x.binding_.bindingHash || p.generation != x.binding_.generation
                || x.terms.mode != 0 || x.terms.threshold != 0
                || x.terms.capabilityPolicySetHash != Hashes.emptyCapabilities()
                || x.terms.count == 0 || x.terms.count > 32 || x.priorCount >= x.terms.count
                || x.count != x.priorCount + 1
                || x.complete != (x.count == x.terms.count && x.primaryRecord != 0)
        ) _invalid();
        _approval(
            e.actor,
            p.account,
            CH.acceptanceDigest(_environment(o), p, x.authorization),
            x.authorization,
            x.approval
        );
        _frames(e, 0x1f, x.complete ? 0x1f : 0x0e);
    }

    /// @notice Original op2 has an additional wrapper iff the authentic binding has collaborators.
    /// @dev A primary may accept without completing the binding; after a legitimate authority
    /// change another op2 can supersede its stored map while both native receipts remain.
    function primary(RH.OriginEnvironment memory o, H.Envelope memory e, uint32 required)
        public
        pure
        returns (PC.PrimaryAcceptance memory x)
    {
        bytes memory inner;
        (inner, x.authority) = abi.decode(e.payload, (bytes, R.AuthorityFact));
        if (
            e.operation != 2 || e.actor == address(0) || e.value == 0
                || keccak256(e.payload) != keccak256(abi.encode(inner, x.authority))
        ) _invalid();
        bytes memory base;
        if (required == 0) {
            base = inner;
            x.complete = true;
        } else {
            (base, x.required, x.accepted, x.complete) =
                abi.decode(inner, (bytes, uint32, uint32, bool));
            if (
                x.required != required || required > 32 || x.accepted > required
                    || x.complete != (x.accepted == required)
                    || keccak256(inner)
                        != keccak256(abi.encode(base, x.required, x.accepted, x.complete))
            ) _invalid();
        }
        (x.acceptance,) = Payload.acceptance(abi.encode(base, x.authority));
        Payload.Acceptance memory a = x.acceptance;
        x.expectedBinding =
            keccak256(base) != keccak256(abi.encode(a.id, a.binding_, a.authorization, a.proof));
        if (
            a.id == 0 || a.binding_.generation == 0 || a.binding_.bindingHash == 0
                || a.binding_.accepted
                || (!x.expectedBinding && a.proof.direct && a.binding_.generation != 1)
        ) _invalid();
        Authority.requirePrincipal(a.binding_.artistId, a.proof.signer, x.authority, false);
        _approval(
            e.actor,
            a.proof.signer,
            Hashes.acceptanceDigest(_environment(o), a.id, a.binding_, a.authorization),
            a.authorization,
            a.proof
        );
        _frames(e, 0x1f, x.complete ? 0x1d : 0x0c);
    }

    function _approval(
        address actor,
        address account,
        bytes32 digest,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) private pure {
        if (
            proof.signer != account || proof.digest != digest || digest == 0
                || proof.direct != (actor == account && a.signature.length == 0)
        ) _invalid();
    }

    function _frames(H.Envelope memory e, uint256 observed, uint256 changed) private pure {
        T.Snapshot memory empty;
        for (uint8 owner; owner < 7; ++owner) {
            T.Snapshot memory before_ = e.before_[owner];
            T.Snapshot memory after_ = e.after_[owner];
            if ((observed & (1 << owner)) == 0) {
                if (
                    keccak256(abi.encode(before_)) != keccak256(abi.encode(empty))
                        || keccak256(abi.encode(after_)) != keccak256(abi.encode(empty))
                ) _invalid();
            } else if ((changed & (1 << owner)) == 0) {
                if (keccak256(abi.encode(before_)) != keccak256(abi.encode(after_))) _invalid();
            } else if (
                before_.domainId != RH.ownerDomain(owner) || after_.domainId != before_.domainId
                    || after_.revision != before_.revision + 1
            ) {
                _invalid();
            }
        }
    }

    function _environment(RH.OriginEnvironment memory o)
        private
        pure
        returns (Hashes.Environment memory)
    {
        return Hashes.Environment(o.chainId, o.registry, o.core, o.manager);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
