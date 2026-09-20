// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH,
    IStreamArtistEconomicsAuthorityHydrationOwner as Source
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import {
    IStreamArtistEconomicsEvidence as Evidence
} from "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistEconomicsHydration as Original } from "./StreamArtistEconomicsHydration.sol";
import {
    StreamArtistRecoveredCollectionHydration as Collection
} from "./StreamArtistRecoveredCollectionHydration.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

interface IStreamRecoveredEconomicsDelegation {
    function recordDelegation(bytes32 record) external view returns (bytes32);
}

/// @notice Complete direct14/15 transport for one accepted generation-one recovered binding.
/// @dev The original fixed owner authenticates record hashes through its actual payload/maps,
/// native occurrences and replay cells. EH.Row does not retain signer, class, nonce or time;
/// this codec never invents those preimages or reauthorizes historical signatures. The joined
/// Coordinator separately transports complete Identity admissions and Payout state and checks
/// resolver bindings. Destination decode makes no source calls or current eligibility decisions.
library StreamArtistRecoveredEconomicsHydration {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_DIRECT_ECONOMICS_V1");
    bytes32 private constant POLICY = keccak256("consent_finality.replay.policy_consent_key");
    bytes32 private constant ECONOMICS = keccak256("consent_finality.replay.consent_key");

    struct Bundle {
        bytes32 provenance;
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
        AH.PolicyKey[] policies;
        EH.Bundle original;
    }

    function isState(bytes memory raw) public pure returns (bool) {
        if (raw.length < 32) return false;
        bytes32 tag;
        assembly ("memory-safe") { tag := mload(add(raw, 32)) }
        return tag == SCHEMA;
    }

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory terms
    ) public view returns (Bundle memory b) {
        Provenance.validateOwnerSource(p, 6, source);
        if (terms.length == 0 || terms.length > 128) _invalid();
        bytes memory raw = Source(source).authorityEconomicsHydrationState(q, terms);
        b = Bundle(
            RH.ownerProvenanceHash(p, 6),
            q.artistId,
            q.collectionId,
            q.bindingHash,
            q.policies,
            Original.decode(raw)
        );
        if (keccak256(raw) != keccak256(_original(b.original))) _invalid();
        if (b.original.records.length != terms.length) _invalid();
        for (uint256 i; i < terms.length; ++i) {
            if (
                keccak256(abi.encode(terms[i]))
                    != keccak256(abi.encode(b.original.records[i].terms))
            ) {
                _invalid();
            }
        }
        // The original typed export checks economics delegation and association maps. Also
        // check every policy; a native14 alone does not distinguish delegated authority.
        for (uint256 i; i < p.journal.length; ++i) {
            if (
                IStreamRecoveredEconomicsDelegation(source)
                        .recordDelegation(p.journal[i].receipt.recordHash) != 0
            ) {
                _invalid();
            }
        }
        validate(b, q, p);
    }

    function encode(Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes memory)
    {
        validate(b, q, p);
        return abi.encode(SCHEMA, RH.VERSION, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (Bundle memory b)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, b) = abi.decode(raw, (bytes32, uint16, Bundle));
        if (
            tag != SCHEMA || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, b))
        ) _invalid();
        validate(b, q, p);
    }

    /// @notice The concrete Consent host keeps its original pristine-owner and op60 checks.
    /// @dev The feature bit chooses a typed codec; neither route accepts the other's tag.
    function importEither(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage economics,
        mapping(bytes32 => bytes32) storage associated,
        mapping(bytes32 => Evidence.Association) storage associations,
        mapping(bytes32 => bytes32) storage delegations,
        AH.Query memory q,
        bytes memory raw
    ) public {
        (RH.ExportHeader memory header,) = Payload.decode(raw, 6);
        if ((header.requiredFeatures & RH.DIRECT_ECONOMICS) != 0) {
            importState(policies, economics, associated, associations, delegations, q, raw);
        } else {
            Collection.importPolicies(policies, delegations, q, raw);
        }
    }

    function importState(
        mapping(bytes32 => bytes32) storage policies,
        mapping(bytes32 => bytes32) storage economics,
        mapping(bytes32 => bytes32) storage associated,
        mapping(bytes32 => Evidence.Association) storage associations,
        mapping(bytes32 => bytes32) storage delegations,
        AH.Query memory q,
        bytes memory raw
    ) public {
        (RH.ExportHeader memory header, Payload.Payload memory payload) = Payload.decode(raw, 6);
        if (payload.nonces.length != 0 || (header.requiredFeatures & RH.DIRECT_ECONOMICS) == 0) {
            _invalid();
        }
        Bundle memory b = decode(q, payload.provenance, payload.semanticState);
        for (uint256 i; i < payload.provenance.journal.length; ++i) {
            if (delegations[payload.provenance.journal[i].receipt.recordHash] != 0) _invalid();
        }
        Original.importState(
            policies, economics, associated, associations, q, _original(b.original)
        );
    }

    function validate(Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p) public pure {
        Provenance.validateOwner(p, 6);
        if (
            b.provenance != RH.ownerProvenanceHash(p, 6) || q.artistId == 0
                || b.artistId != q.artistId || q.collectionId == 0
                || b.collectionId != q.collectionId || q.bindingHash == 0
                || b.bindingHash != q.bindingHash || b.policies.length > 128
                || b.original.policies.length != b.policies.length
                || keccak256(abi.encode(b.policies)) != keccak256(abi.encode(q.policies))
                || b.original.schema != Original.SCHEMA || b.original.records.length == 0
                || b.original.records.length > 128
                || p.journal.length != b.policies.length + b.original.records.length
        ) _invalid();
        _rows(b, q);
        (bytes32[] memory surfaces, bytes32[] memory scopes) = _journal(b, p);
        _eras(p);
        _aliases(p, surfaces, scopes);
    }

    function _rows(Bundle memory b, AH.Query memory q) private pure {
        for (uint256 i; i < b.policies.length; ++i) {
            if (
                b.policies[i].phaseId == 0 || b.policies[i].policyHash == 0
                    || b.original.policies[i] == 0
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    b.original.policies[j] == b.original.policies[i]
                        || _scope(q.collectionId, b.policies[j])
                            == _scope(q.collectionId, b.policies[i])
                ) _invalid();
            }
        }
        for (uint256 i; i < b.original.records.length; ++i) {
            EH.Row memory r = b.original.records[i];
            T.EconomicsConsent memory t = r.terms;
            Evidence.Association memory a = r.association;
            if (
                r.recordHash == 0 || t.collectionId != q.collectionId || t.resolver == address(0)
                    || t.revenueClass == 0 || t.scope > 2
                    || (t.scope == 0 && (t.scopeId != 0 || t.assignmentHash == 0))
                    || (t.scope == 1 && t.scopeId != q.collectionId)
                    || (t.scope == 2 && t.scopeId == 0) || a.artistId != q.artistId
                    || a.bindingGeneration != 1 || a.bindingHash != q.bindingHash
                    || a.payloadHash != keccak256(abi.encode(t)) || a.originalRecord != r.recordHash
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (
                    b.original.records[j].recordHash == r.recordHash
                        || b.original.records[j].association.payloadHash == a.payloadHash
                ) _invalid();
            }
            for (uint256 j; j < b.original.policies.length; ++j) {
                if (b.original.policies[j] == r.recordHash) _invalid();
            }
        }
    }

    function _journal(Bundle memory b, RH.OwnerProvenance memory p)
        private
        pure
        returns (bytes32[] memory surfaces, bytes32[] memory scopes)
    {
        surfaces = new bytes32[](p.journal.length);
        scopes = new bytes32[](p.journal.length);
        uint256 economics;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory row = p.journal[i];
            if (row.receipt.artistId != b.artistId || row.receipt.collectionId != b.collectionId) {
                _invalid();
            }
            for (uint256 j; j < i; ++j) {
                if (p.journal[j].receipt.recordHash == row.receipt.recordHash) _invalid();
            }
            if (row.receipt.operation == 14) {
                bool found;
                for (uint256 j; j < b.original.policies.length; ++j) {
                    if (b.original.policies[j] != row.receipt.recordHash) continue;
                    surfaces[i] = POLICY;
                    scopes[i] = _scope(b.collectionId, b.policies[j]);
                    found = true;
                }
                if (!found) _invalid();
            } else if (row.receipt.operation == 15) {
                if (economics >= b.original.records.length) _invalid();
                EH.Row memory r = b.original.records[economics++];
                if (r.recordHash != row.receipt.recordHash) _invalid();
                surfaces[i] = ECONOMICS;
                scopes[i] = r.association.payloadHash;
            } else {
                _invalid();
            }
        }
        if (economics != b.original.records.length) _invalid();
    }

    function _eras(RH.OwnerProvenance memory p) private pure {
        uint256 total;
        uint256 cursor;
        for (uint256 i; i < p.eras.length; ++i) {
            RH.OwnerEra memory era = p.eras[i];
            total += era.nativeCount;
            if (
                era.lowerRevision != (i == 0 ? 0 : 1)
                    || uint256(era.checkpoint.ownerState.revision)
                        != uint256(era.lowerRevision) + era.nativeCount
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
                    || era.checkpoint.replayCount != total
                    || (total == 0 && era.checkpoint.replayRoot != 0)
            ) _invalid();
            for (uint256 j; j < era.nativeCount; ++j) {
                // Direct14/15 each commits once and emits exactly one native occurrence.
                if (
                    uint256(p.journal[cursor++].position.point.ownerRevision)
                        != uint256(era.lowerRevision) + j + 1
                ) _invalid();
            }
        }
    }

    function _aliases(
        RH.OwnerProvenance memory p,
        bytes32[] memory surfaces,
        bytes32[] memory scopes
    ) private pure {
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (a.cell.kind != 1 || a.cell.status != 2) _invalid();
            bool found;
            for (uint256 j; j < p.journal.length; ++j) {
                if (
                    a.surface != surfaces[j] || a.scope != scopes[j]
                        || a.cell.commitment != p.journal[j].receipt.recordHash
                ) continue;
                if (
                    keccak256(abi.encode(a.admittedAt))
                        != keccak256(abi.encode(p.journal[j].position.point))
                ) _invalid();
                found = true;
            }
            if (!found) _invalid();
        }
        // Provenance requires unique sorted original keys, forbids an alias before admission,
        // and checks each era's replayCount. With cumulative direct-record counts above and one
        // immutable scope per journal row, every row must have one alias in every later era.
    }

    function _original(EH.Bundle memory b) private pure returns (bytes memory) {
        return abi.encode(b.schema, b.policies, b.records);
    }

    function _scope(uint256 collectionId, AH.PolicyKey memory key) private pure returns (bytes32) {
        return keccak256(abi.encode(collectionId, key.phaseId, key.policyHash));
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
