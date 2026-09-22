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
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import { StreamArtistUnboundPlatformCodec as Codec } from "./StreamArtistUnboundPlatformCodec.sol";
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

import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";

import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";

import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistUnboundPlatformNativeRows as PlatformRows
} from "./StreamArtistUnboundPlatformNativeRows.sol";
import {
    StreamArtistUnboundPlatformAccounting as Accounting
} from "./StreamArtistUnboundPlatformAccounting.sol";

import {
    StreamArtistUnboundPlatformReplayRows as ReplayRows
} from "./StreamArtistUnboundPlatformReplayRows.sol";

/// @notice Complete accepted-generation-one collection rows with global owner clocks and guards.
library StreamArtistUnboundPlatformCollectionRows {
    struct AttributionRow {
        Original.AttributionBundle state;
        bytes32 proposalOrigin;
    }

    function validate(uint8 owner, M.State memory s, RH.OwnerProvenance memory p) public pure {
        Codec.validate(owner, s, p);
        Provenance.validateOwner(p, owner);
        if (owner == 1) {
            empty(p, 1);
            return;
        }
        if (owner != 0 && owner != 3 && owner != 4 && owner != 6) _invalid();
        uint256[] memory counts = new uint256[](p.eras.length);
        uint256 records;
        D.Guard[] memory platform = new D.Guard[](owner == 4 ? p.journal.length : 0);
        uint256 platformCount;
        for (uint256 i; i < s.rows.length; ++i) {
            AH.Query memory q = s.collections[i];
            if (q.artistId == 0) {
                if (owner != 4) {
                    if (s.rows[i].length != 0) _invalid();
                } else {
                    P.Platform memory item = abi.decode(s.rows[i], (P.Platform));
                    if (
                        keccak256(s.rows[i]) != keccak256(abi.encode(item))
                            || item.collectionId != q.collectionId
                            || item.state.declaration.recordHash == 0
                            || item.state.correction.correctiveGeneration != 0
                            || item.state.correction.accepted || item.continuations.length != 0
                    ) _invalid();
                    D.Guard[] memory part = PlatformRows.validate(item, p);
                    for (uint256 k; k < part.length; ++k) {
                        if (platformCount == platform.length) _invalid();
                        platform[platformCount++] = part[k];
                    }
                }
                continue;
            }
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
                        || !b.item.accepted || b.item.consentMode != 1
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
                ReplayRows.validate(
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
                ReplayRows.validate(
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
                    ReplayRows.validate(
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
        if (owner == 4) {
            if (platformCount != platform.length) _invalid();
            Accounting.validate(p, counts, platform);
            return;
        }
        if (p.journal.length != records) _invalid();
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

    /// @notice Complete zero-history owner, including original repeated-import revision.
    function empty(RH.OwnerProvenance memory p, uint8 owner) public pure {
        Provenance.validateOwner(p, owner);
        if (p.journal.length != 0 || p.aliases.length != 0) _invalid();
        for (uint256 i; i < p.eras.length; ++i) {
            RH.OwnerEra memory e = p.eras[i];
            if (
                e.lowerRevision != (i == 0 ? 0 : 1) || e.nativeCount != 0
                    || e.checkpoint.ownerState.revision != e.lowerRevision
                    || e.checkpoint.replayCount != 0 || e.checkpoint.replayRoot != 0
                    || e.checkpoint.nonceIndexCount != 0 || e.checkpoint.nonceRoot != 0
            ) _invalid();
        }
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

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
