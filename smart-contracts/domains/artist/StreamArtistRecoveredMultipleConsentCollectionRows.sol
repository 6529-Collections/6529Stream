// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredSimpleHydrationTypes as S
} from "../../interfaces/stream/artist/StreamArtistRecoveredSimpleHydrationTypes.sol";
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
    StreamArtistRecoveredMultipleConsentCodec as Codec
} from "./StreamArtistRecoveredMultipleConsentCodec.sol";
import {
    StreamArtistRecoveredSimpleHydration as Simple
} from "./StreamArtistRecoveredSimpleHydration.sol";
import {
    StreamArtistRecoveredCollectionHydration as Original
} from "./StreamArtistRecoveredCollectionHydration.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistCollaboratorHashes as Collaborators
} from "./StreamArtistCollaboratorHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle as Lifecycle
} from "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistDelegatedConsentOwner as Delegated
} from "../../interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";

/// @notice Complete accepted-generation-one collection rows with global owner clocks and guards.
library StreamArtistRecoveredMultipleConsentCollectionRows {
    struct AttributionRow {
        Original.AttributionBundle state;
        bytes32 proposalOrigin;
    }

    function validate(uint8 owner, M.State memory s, RH.OwnerProvenance memory p) public pure {
        Codec.validate(owner, s, p);
        Provenance.validateOwner(p, owner);
        if (owner == 1) {
            AH.Query memory q = s.collections[0];
            Simple.validateCollaborator(
                q, p, S.EmptyCollaborator(Simple.scope(q), RH.ownerProvenanceHash(p, 1))
            );
            return;
        }
        if (owner != 0 && owner != 3 && owner != 4) _invalid();
        uint256[] memory counts = new uint256[](p.eras.length);
        uint256 records;
        for (uint256 i; i < s.rows.length; ++i) {
            AH.Query memory q = s.collections[i];
            if (owner == 0) {
                S.Binding memory b = abi.decode(s.rows[i], (S.Binding));
                if (keccak256(s.rows[i]) != keccak256(abi.encode(b))) _invalid();
                RH.JournalEntry memory j = occurrence(p, q, 1, q.bindingHash);
                uint256 e = era(p, j.position.point.environmentHash);
                ++counts[e];
                ++records;
                L.Terminal memory empty;
                if (
                    keccak256(abi.encode(b.scope)) != keccak256(abi.encode(Simple.scope(q)))
                        || b.provenanceCommitment != RH.ownerProvenanceHash(p, 0)
                        || b.item.artistId != q.artistId || b.item.bindingHash != q.bindingHash
                        || b.item.artistAddress == address(0) || b.item.identityRecordHash == 0
                        || b.item.proposer == address(0) || b.item.generation != 1
                        || !b.item.accepted || (b.item.consentMode != 1 && b.item.consentMode != 2)
                        || b.item.saleConsentScope > 1 || b.item.registryImmutabilityElection > 1
                        || keccak256(abi.encode(b.item)) != keccak256(abi.encode(b.history))
                        || keccak256(abi.encode(b.terminal)) != keccak256(abi.encode(empty))
                        || b.terms.count != 0 || b.terms.mode != 0 || b.terms.threshold != 0
                        || b.terms.collaboratorSetHash != Hashes.emptyCollaborators()
                        || b.terms.capabilityPolicySetHash != Hashes.emptyCapabilities()
                ) _invalid();
                RH.OriginEnvironment memory o = p.origins[e];
                if (
                    Collaborators.binding(
                            Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                            q.collectionId,
                            b.item,
                            new T.CollaboratorRecord[](0)
                        ) != q.bindingHash
                ) _invalid();
                guards(
                    p,
                    j,
                    keccak256("binding_lifecycle.replay.proposal_key"),
                    keccak256(abi.encode(q.collectionId, uint64(1))),
                    q.bindingHash
                );
            } else if (owner == 3) {
                S.Acceptance memory b = abi.decode(s.rows[i], (S.Acceptance));
                if (
                    keccak256(s.rows[i]) != keccak256(abi.encode(b))
                        || keccak256(abi.encode(b.scope)) != keccak256(abi.encode(Simple.scope(q)))
                        || b.provenanceCommitment != RH.ownerProvenanceHash(p, 3) || b.record == 0
                        || b.acceptedAt == 0
                ) _invalid();
                RH.JournalEntry memory j = occurrence(p, q, 2, b.record);
                ++counts[era(p, j.position.point.environmentHash)];
                ++records;
                guards(
                    p, j, keccak256("acceptance_lifecycle.replay.record_uniqueness"), 0, b.record
                );
            } else if (owner == 4) {
                AttributionRow memory b = abi.decode(s.rows[i], (AttributionRow));
                if (
                    keccak256(s.rows[i]) != keccak256(abi.encode(b))
                        || b.state.provenance != RH.ownerProvenanceHash(p, 4)
                        || b.state.artistId != q.artistId || b.state.collectionId != q.collectionId
                        || b.state.bindingHash != q.bindingHash || b.state.item.state != 2
                        || b.state.item.generation != 1
                ) _invalid();
                ++counts[era(p, b.proposalOrigin)];
            } else {
                Original.PolicyBundle memory b = abi.decode(s.rows[i], (Original.PolicyBundle));
                if (
                    keccak256(s.rows[i]) != keccak256(abi.encode(b))
                        || b.provenance != RH.ownerProvenanceHash(p, 6) || b.artistId != q.artistId
                        || b.collectionId != q.collectionId
                        || keccak256(abi.encode(b.policies)) != keccak256(abi.encode(q.policies))
                        || b.records.length != q.policies.length
                ) _invalid();
                for (uint256 k; k < b.records.length; ++k) {
                    if (b.records[k] == 0) _invalid();
                    for (uint256 j; j < k; ++j) {
                        if (b.records[j] == b.records[k]) _invalid();
                    }
                    RH.JournalEntry memory j = occurrence(p, q, 14, b.records[k]);
                    ++counts[era(p, j.position.point.environmentHash)];
                    ++records;
                    guards(
                        p,
                        j,
                        keccak256("consent_finality.replay.policy_consent_key"),
                        keccak256(
                            abi.encode(
                                q.collectionId, q.policies[k].phaseId, q.policies[k].policyHash
                            )
                        ),
                        b.records[k]
                    );
                }
            }
        }
        if (p.journal.length != records || (owner == 4 && p.aliases.length != 0)) _invalid();
        uint256 total;
        uint256 aliases;
        for (uint256 e; e < p.eras.length; ++e) {
            total += counts[e];
            RH.OwnerEra memory r = p.eras[e];
            uint256 nativeCount = owner == 4 ? 0 : counts[e];
            uint256 commits = (owner == 0 || owner == 4) ? 2 * counts[e] : counts[e];
            uint256 replayCount = owner == 4 ? 0 : total;
            if (
                r.lowerRevision != (e == 0 ? 0 : 1) || r.nativeCount != nativeCount
                    || r.checkpoint.ownerState.revision != r.lowerRevision + commits
                    || r.checkpoint.replayCount != replayCount
                    || (replayCount == 0 && r.checkpoint.replayRoot != 0)
                    || r.checkpoint.nonceIndexCount != 0 || r.checkpoint.nonceRoot != 0
            ) _invalid();
            aliases += replayCount;
        }
        if (p.aliases.length != aliases) _invalid();
    }

    function occurrence(RH.OwnerProvenance memory p, AH.Query memory q, uint16 op, bytes32 record)
        public
        pure
        returns (RH.JournalEntry memory result)
    {
        uint256 matches;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (j.receipt.recordHash != record) continue;
            if (
                j.receipt.operation != op || j.receipt.artistId != q.artistId
                    || j.receipt.collectionId != q.collectionId
            ) _invalid();
            result = j;
            ++matches;
        }
        if (matches != 1) _invalid();
    }

    function era(RH.OwnerProvenance memory p, bytes32 origin) public pure returns (uint256) {
        for (uint256 i; i < p.eras.length; ++i) {
            if (p.eras[i].originHash == origin) return i;
        }
        _invalid();
        return 0;
    }

    function guards(
        RH.OwnerProvenance memory p,
        RH.JournalEntry memory j,
        bytes32 surface,
        bytes32 scope,
        bytes32 record
    ) private pure {
        uint256 start = era(p, j.position.point.environmentHash);
        bytes32 actualScope = scope;
        for (uint256 e = start; e < p.eras.length; ++e) {
            uint256 matches;
            for (uint256 i; i < p.aliases.length; ++i) {
                RH.ReplayAlias memory a = p.aliases[i];
                if (
                    a.originHash != p.eras[e].originHash || a.surface != surface
                        || a.cell.commitment != record
                ) continue;
                if (actualScope == 0) actualScope = a.scope;
                if (
                    a.scope == 0 || a.scope != actualScope || a.cell.kind != 1 || a.cell.status != 2
                        || keccak256(abi.encode(a.admittedAt))
                            != keccak256(abi.encode(j.position.point))
                ) _invalid();
                ++matches;
            }
            if (matches != 1) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
