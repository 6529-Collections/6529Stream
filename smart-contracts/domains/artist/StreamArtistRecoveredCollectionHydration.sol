// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice Explicit base collection dependencies for recovered-authority graphs.
/// @dev One accepted attribution and complete direct policy14 history. Pending-generation
/// history has a distinct tag and complete Binding-owner join; generation-one bytes are unchanged.
/// Other collection histories require their typed extension; none is represented as empty here.
library StreamArtistRecoveredCollectionHydration {
    bytes32 internal constant ATTRIBUTION =
        keccak256("6529STREAM_ARTIST_RECOVERED_ATTRIBUTION_BASE_V1");
    bytes32 internal constant GENERATIONS_ATTRIBUTION =
        keccak256("6529STREAM_ARTIST_RECOVERED_ATTRIBUTION_GENERATIONS_V1");
    bytes32 internal constant POLICIES =
        keccak256("6529STREAM_ARTIST_RECOVERED_DIRECT_POLICIES_V1");
    bytes32 private constant POLICY_KEY = keccak256("consent_finality.replay.policy_consent_key");

    struct AttributionBundle {
        bytes32 provenance;
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
        AS.Attribution item;
    }

    struct PolicyBundle {
        bytes32 provenance;
        bytes32 artistId;
        uint256 collectionId;
        AH.PolicyKey[] policies;
        bytes32[] records;
    }

    function exportAttribution(AS.State storage s, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
        returns (bytes memory)
    {
        Provenance.validateOwnerSource(p, 4, address(this));
        AttributionBundle memory b = AttributionBundle(
            RH.ownerProvenanceHash(p, 4),
            q.artistId,
            q.collectionId,
            q.bindingHash,
            s.attributions[q.collectionId]
        );
        if (b.item.generation > 1) {
            validateGenerationsAttribution(b, q, p);
            return abi.encode(GENERATIONS_ATTRIBUTION, b);
        }
        validateAttribution(b, q, p);
        return abi.encode(ATTRIBUTION, b);
    }

    function importAttribution(AS.State storage s, AH.Query memory q, bytes memory raw) public {
        (RH.ExportHeader memory header, Payload.Payload memory payload) = Payload.decode(raw, 4);
        (bytes32 tag, AttributionBundle memory b) =
            abi.decode(payload.semanticState, (bytes32, AttributionBundle));
        if (
            keccak256(payload.semanticState) != keccak256(abi.encode(tag, b))
                || payload.nonces.length != 0
        ) revert RH.InvalidRecoveredHydrationProfile();
        if (tag == GENERATIONS_ATTRIBUTION) {
            if ((header.requiredFeatures & RH.BINDING_GENERATIONS) == 0) {
                revert RH.InvalidRecoveredHydrationProfile();
            }
            validateGenerationsAttribution(b, q, payload.provenance);
        } else {
            if (tag != ATTRIBUTION) revert RH.InvalidRecoveredHydrationProfile();
            validateAttribution(b, q, payload.provenance);
        }
        if (
            s.attributions[q.collectionId].state != 0
                || s.attributions[q.collectionId].generation != 0
        ) revert RH.InvalidRecoveredHydrationProfile();
        s.attributions[q.collectionId] = b.item;
    }

    function validateAttribution(
        AttributionBundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) public pure {
        _validateAttribution(b, q, p, 1);
    }

    /// @notice All pending generations terminate before the sole final acceptance.
    /// @dev Prepared joins the exact generation to the complete Binding-owner history.
    /// Each original proposal and termination/acceptance mutates Attribution exactly once.
    function validateGenerationsAttribution(
        AttributionBundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) public pure {
        if (b.item.generation < 2 || b.item.generation > 128) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        _validateAttribution(b, q, p, b.item.generation);
    }

    function _validateAttribution(
        AttributionBundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint64 generation
    ) private pure {
        Provenance.validateOwner(p, 4);
        if (
            b.provenance != RH.ownerProvenanceHash(p, 4) || b.artistId == 0
                || b.artistId != q.artistId || b.collectionId == 0
                || b.collectionId != q.collectionId || b.bindingHash == 0
                || b.bindingHash != q.bindingHash || b.item.state != 2
                || b.item.generation != generation || p.journal.length != 0 || p.aliases.length != 0
        ) revert RH.InvalidRecoveredHydrationProfile();
        for (uint256 i; i < p.eras.length; ++i) {
            if (
                p.eras[i].checkpoint.ownerState.revision != (i == 0 ? 2 * generation : 1)
                    || p.eras[i].lowerRevision != (i == 0 ? 0 : 1) || p.eras[i].nativeCount != 0
                    || p.eras[i].checkpoint.replayCount != 0 || p.eras[i].checkpoint.replayRoot != 0
                    || p.eras[i].checkpoint.nonceIndexCount != 0
                    || p.eras[i].checkpoint.nonceRoot != 0
            ) {
                revert RH.InvalidRecoveredHydrationProfile();
            }
        }
    }

    function exportPolicies(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage delegations,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) public view returns (bytes memory) {
        Provenance.validateOwnerSource(p, 6, address(this));
        PolicyBundle memory b;
        b.provenance = RH.ownerProvenanceHash(p, 6);
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.policies = q.policies;
        b.records = new bytes32[](q.policies.length);
        for (uint256 i; i < b.records.length; ++i) {
            b.records[i] = policies[_scope(q.collectionId, q.policies[i])];
            if (delegations[b.records[i]] != 0) revert RH.InvalidRecoveredHydrationProfile();
        }
        validatePolicies(b, q, p);
        return abi.encode(POLICIES, b);
    }

    function importPolicies(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage delegations,
        AH.Query memory q,
        bytes memory raw
    ) public {
        (, Payload.Payload memory payload) = Payload.decode(raw, 6);
        (bytes32 tag, PolicyBundle memory b) =
            abi.decode(payload.semanticState, (bytes32, PolicyBundle));
        if (
            tag != POLICIES || keccak256(payload.semanticState) != keccak256(abi.encode(tag, b))
                || payload.nonces.length != 0
        ) revert RH.InvalidRecoveredHydrationProfile();
        validatePolicies(b, q, payload.provenance);
        for (uint256 i; i < b.records.length; ++i) {
            bytes32 scope = _scope(q.collectionId, b.policies[i]);
            if (policies[scope] != 0 || delegations[b.records[i]] != 0) {
                revert RH.InvalidRecoveredHydrationProfile();
            }
            policies[scope] = b.records[i];
        }
    }

    function validatePolicies(PolicyBundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
    {
        Provenance.validateOwner(p, 6);
        if (
            b.provenance != RH.ownerProvenanceHash(p, 6) || b.artistId == 0
                || b.artistId != q.artistId || b.collectionId == 0
                || b.collectionId != q.collectionId || b.policies.length > 128
                || b.records.length != b.policies.length || b.records.length != p.journal.length
                || keccak256(abi.encode(b.policies)) != keccak256(abi.encode(q.policies))
        ) revert RH.InvalidRecoveredHydrationProfile();
        for (uint256 i; i < b.records.length; ++i) {
            if (b.records[i] == 0 || b.policies[i].phaseId == 0 || b.policies[i].policyHash == 0) {
                revert RH.InvalidRecoveredHydrationProfile();
            }
            for (uint256 j; j < i; ++j) {
                if (
                    b.records[j] == b.records[i]
                        || _scope(b.collectionId, b.policies[j])
                            == _scope(b.collectionId, b.policies[i])
                ) revert RH.InvalidRecoveredHydrationProfile();
            }
            uint256 matches;
            for (uint256 j; j < p.journal.length; ++j) {
                RH.JournalEntry memory row = p.journal[j];
                if (row.receipt.recordHash != b.records[i]) continue;
                if (
                    row.receipt.operation != 14 || row.receipt.artistId != b.artistId
                        || row.receipt.collectionId != b.collectionId
                ) revert RH.InvalidRecoveredHydrationProfile();
                ++matches;
            }
            if (matches != 1) revert RH.InvalidRecoveredHydrationProfile();
        }
        uint256 total;
        for (uint256 i; i < p.eras.length; ++i) {
            total += p.eras[i].nativeCount;
            if (
                p.eras[i].checkpoint.ownerState.revision
                        != p.eras[i].lowerRevision + p.eras[i].nativeCount
                    || p.eras[i].lowerRevision != (i == 0 ? 0 : 1)
                    || p.eras[i].checkpoint.nonceIndexCount != 0
                    || p.eras[i].checkpoint.nonceRoot != 0
                    || p.eras[i].checkpoint.replayCount != total
                    || (total == 0 && p.eras[i].checkpoint.replayRoot != 0)
            ) revert RH.InvalidRecoveredHydrationProfile();
        }
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (a.surface != POLICY_KEY || a.cell.kind != 1 || a.cell.status != 2) {
                revert RH.InvalidRecoveredHydrationProfile();
            }
            bool found;
            for (uint256 j; j < b.records.length; ++j) {
                if (
                    a.scope != _scope(b.collectionId, b.policies[j])
                        || a.cell.commitment != b.records[j]
                ) continue;
                for (uint256 k; k < p.journal.length; ++k) {
                    if (
                        p.journal[k].receipt.recordHash == b.records[j]
                            && keccak256(abi.encode(a.admittedAt))
                                == keccak256(abi.encode(p.journal[k].position.point))
                    ) found = true;
                }
            }
            if (!found) revert RH.InvalidRecoveredHydrationProfile();
        }
    }

    function _scope(uint256 collectionId, AH.PolicyKey memory key) private pure returns (bytes32) {
        return keccak256(abi.encode(collectionId, key.phaseId, key.policyHash));
    }
}
