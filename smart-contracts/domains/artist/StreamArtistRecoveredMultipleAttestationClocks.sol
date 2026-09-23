// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
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
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Collections
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistCurrentAuthorityFacts as Authority
} from "./StreamArtistCurrentAuthorityFacts.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

/// @notice Authentic original owner4 proposal/acceptance clocks across interleaved collections.
/// @dev One complete Archive catalogue is carried with owner4. Cross-owner revisions are never ordered.
library StreamArtistRecoveredMultipleAttestationClocks {
    struct Inventory {
        P.Catalogue[] catalogues;
        H.OperationEvidence[] operations;
    }

    struct Context {
        RH.Point[] proposals;
        RH.Point[] completions;
        uint256[] counts;
        uint256 previousEra;
        uint64 previousRevision;
    }

    function collect(RH.Provenance memory p, M.State memory scope)
        public
        view
        returns (bytes memory raw)
    {
        Inventory memory inventory;
        (inventory.catalogues, inventory.operations) = Catalogue.collect(p);
        validateLocal(scope, RH.ownerProvenance(p, 4), inventory);
        // Join each authenticated outer envelope to the actual original owner's occurrence,
        // preserving both original clocks instead of treating them as interchangeable.
        for (uint256 i; i < inventory.operations.length; ++i) {
            H.OperationEvidence memory row = inventory.operations[i];
            uint256 e = Collections.era(RH.ownerProvenance(p, 4), row.originHash);
            H.Envelope memory envelope =
                Catalogue.read(p.origins[e], inventory.catalogues[e], row.evidence);
            uint256 id = envelope.operation == 1
                ? Payload.proposal(envelope.payload).id
                : _acceptedId(envelope.payload);
            AH.Query memory q = scope.collections[Scope.collection(scope, id)];
            uint8 owner = envelope.operation == 1 ? 0 : 3;
            RH.JournalEntry memory native_ = Collections.occurrence(
                RH.ownerProvenance(p, owner), q, envelope.operation, envelope.value
            );
            if (
                native_.position.point.environmentHash != row.originHash
                    || native_.position.point.ownerRevision != envelope.after_[owner].revision
            ) _invalid();
        }
        raw = abi.encode(inventory);
    }

    function decode(bytes memory raw) public pure returns (Inventory memory inventory) {
        inventory = abi.decode(raw, (Inventory));
        if (keccak256(raw) != keccak256(abi.encode(inventory))) _invalid();
    }

    function validateLocal(
        M.State memory scope,
        RH.OwnerProvenance memory p,
        Inventory memory inventory
    ) public view returns (RH.Point[] memory completions) {
        Catalogue.requireLocal(p, 4, inventory.catalogues, inventory.operations);
        if (inventory.operations.length != 2 * scope.collections.length) _invalid();
        Context memory c;
        c.proposals = new RH.Point[](scope.collections.length);
        c.completions = new RH.Point[](scope.collections.length);
        c.counts = new uint256[](p.eras.length);
        for (uint256 i; i < inventory.operations.length; ++i) {
            H.OperationEvidence memory row = inventory.operations[i];
            uint256 era = Collections.era(p, row.originHash);
            H.Envelope memory e =
                Catalogue.read(p.origins[era], inventory.catalogues[era], row.evidence);
            if (
                row.operation != e.operation || (e.operation != 1 && e.operation != 2)
                    || era < c.previousEra
                    || (i != 0
                        && era == c.previousEra
                        && e.after_[4].revision <= c.previousRevision)
            ) _invalid();
            c.previousEra = era;
            c.previousRevision = e.after_[4].revision;
            _snapshots(inventory.catalogues[era], e);
            uint256 id = e.operation == 1 ? Payload.proposal(e.payload).id : _acceptedId(e.payload);
            uint256 k = Scope.collection(scope, id);
            AH.Query memory q = scope.collections[k];
            RH.Point memory point =
                e.operation == 1 ? _proposal(p, era, e, q) : _acceptance(p, era, e, q);
            if (e.operation == 1) {
                if (c.proposals[k].environmentHash != 0 || c.completions[k].environmentHash != 0) {
                    _invalid();
                }
                c.proposals[k] = point;
            } else {
                if (
                    c.completions[k].environmentHash != 0
                        || c.proposals[k].environmentHash != point.environmentHash
                        || !Clock.beforeOwner(p, 4, c.proposals[k], point)
                ) _invalid();
                c.completions[k] = point;
            }
            ++c.counts[era];
            for (uint256 j; j < p.journal.length; ++j) {
                RH.Point memory other = p.journal[j].position.point;
                if (
                    point.environmentHash == other.environmentHash
                        && point.ownerRevision == other.ownerRevision
                ) _invalid();
            }
        }
        for (uint256 k; k < scope.collections.length; ++k) {
            if (c.completions[k].environmentHash == 0) _invalid();
        }
        for (uint256 e; e < p.eras.length; ++e) {
            RH.OwnerEra memory era = p.eras[e];
            if (
                era.lowerRevision != (e == 0 ? 0 : 1)
                    || era.checkpoint.ownerState.revision
                        != era.lowerRevision + c.counts[e] + era.nativeCount
                    || era.checkpoint.replayCount != 0 || era.checkpoint.replayRoot != 0
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
            ) _invalid();
        }
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            uint256 k = Scope.collection(scope, j.receipt.collectionId);
            if (
                j.receipt.operation != 24 || j.receipt.artistId != scope.collections[k].artistId
                    || !Clock.beforeOwner(p, 4, c.completions[k], j.position.point)
            ) _invalid();
            if (
                i != 0
                    && !Clock.beforeOwner(p, 4, p.journal[i - 1].position.point, j.position.point)
            ) {
                _invalid();
            }
        }
        return c.completions;
    }

    function _binding(RH.OriginEnvironment memory o, AH.Query memory q)
        private
        view
        returns (T.Binding memory b)
    {
        b = Binding(o.owners[0]).bindingAt(q.collectionId, 1);
        if (
            b.artistId != q.artistId || b.bindingHash != q.bindingHash || b.generation != 1
                || !b.accepted
        ) _invalid();
        b.accepted = false;
    }

    function _proposal(
        RH.OwnerProvenance memory p,
        uint256 era,
        H.Envelope memory e,
        AH.Query memory q
    ) private view returns (RH.Point memory) {
        T.Binding memory b = _binding(p.origins[era], q);
        Payload.Proposal memory data = Payload.proposal(e.payload);
        T.BindingProposal memory proposal = data.proposal;
        if (
            e.value != b.bindingHash || e.actor != b.proposer || data.id != q.collectionId
                || data.reused != (proposal.artistId != 0)
        ) _invalid();
        _proposalFields(proposal, b);
        return Transition.validateWithRecords(
            p.origins[era],
            p,
            era,
            e,
            keccak256(abi.encode(q.collectionId, b, proposal.reasonHash, proposal.reasonURI)),
            keccak256(abi.encode(q.collectionId, uint8(1), b.generation)),
            0,
            0
        );
    }

    function _acceptance(
        RH.OwnerProvenance memory p,
        uint256 era,
        H.Envelope memory e,
        AH.Query memory q
    ) private view returns (RH.Point memory) {
        RH.OriginEnvironment memory o = p.origins[era];
        T.Binding memory b = _binding(o, q);
        (Payload.Acceptance memory a, R.AuthorityFact memory authority) =
            Payload.acceptance(e.payload);
        if (a.id != q.collectionId || keccak256(abi.encode(a.binding_)) != keccak256(abi.encode(b)))
        {
            _invalid();
        }
        Authority.requirePrincipal(b.artistId, a.proof.signer, authority, false);
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
        return Transition.validateWithRecords(
            o,
            p,
            era,
            e,
            keccak256(abi.encode(a.id, b, e.value)),
            keccak256(abi.encode(a.id, AS.Attribution(2, b.generation))),
            0,
            0
        );
    }

    function _acceptedId(bytes memory raw) private pure returns (uint256 id) {
        (Payload.Acceptance memory a,) = Payload.acceptance(raw);
        return a.id;
    }

    function _snapshots(P.Catalogue memory c, H.Envelope memory e) private pure {
        uint256 mask = e.operation == 2 ? 0x1f : e.operation == 4 ? 0x11 : 0x15;
        T.Snapshot memory zero;
        for (uint8 i; i < 7; ++i) {
            T.Snapshot memory before_ = e.before_[i];
            T.Snapshot memory after_ = e.after_[i];
            if ((mask & (1 << i)) == 0) {
                if (
                    keccak256(abi.encode(before_)) != keccak256(abi.encode(zero))
                        || keccak256(abi.encode(after_)) != keccak256(abi.encode(zero))
                ) _invalid();
            } else {
                if (
                    before_.domainId != RH.ownerDomain(i) || after_.domainId != RH.ownerDomain(i)
                        || before_.stateRoot == 0 || before_.recordChainTip == 0
                        || after_.stateRoot == 0 || after_.recordChainTip == 0
                        || before_.revision < c.lower[i] || after_.revision > c.upper[i]
                        || after_.revision < before_.revision
                        || after_.revision > before_.revision + 1
                ) {
                    _invalid();
                }
                if (i == 1 || (i == 2 && e.operation == 1 && after_.revision == before_.revision)) {
                    if (keccak256(abi.encode(before_)) != keccak256(abi.encode(after_))) {
                        _invalid();
                    }
                } else if (after_.revision != before_.revision + 1) {
                    _invalid();
                }
            }
        }
    }

    function _proposalFields(T.BindingProposal memory p, T.Binding memory b) private pure {
        if (
            (p.artistId != 0 && p.artistId != b.artistId) || p.artistAddress != b.artistAddress
                || p.identityRecordHash != b.identityRecordHash || p.consentMode != b.consentMode
                || p.saleConsentScope != b.saleConsentScope
                || p.registryImmutabilityElection != b.registryImmutabilityElection
                || p.collabPolicyMode != 0 || p.collabThreshold != 0 || p.collaborators.length != 0
                || p.capabilityPolicyOverrides.length != 0 || bytes(p.reasonURI).length > 2048
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
