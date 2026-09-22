// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAggregateSanctionAttributionTransport as SanctionTransport
} from "./StreamArtistRecoveredAggregateSanctionAttributionTransport.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as G
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
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
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

import {
    StreamArtistPrimaryCollaboratorProofDecode as ProofDecode
} from "./StreamArtistPrimaryCollaboratorProofDecode.sol";

/// @notice Canonical aggregate scope and complete whole-owner membership; no projected provenance.
library StreamArtistPrimaryCollaboratorCodec {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_PRIMARY_COLLABORATOR_HYDRATION_V1");

    function selected(bytes memory outer, uint8 owner) public pure returns (bool) {
        (RH.ExportHeader memory h,) = Payload.decode(outer, owner);
        return (h.requiredFeatures & G.FEATURE) != 0;
    }

    function encode(
        uint8 owner,
        M.State memory s,
        RH.OwnerProvenance memory p,
        bytes memory auxiliary
    ) public pure returns (bytes memory) {
        validate(owner, s, p);
        if (auxiliary.length == 0) _invalid();
        ProofDecode.requireValid(ProofDecode.Context(owner, auxiliary, p));
        return abi.encode(SCHEMA, M.VERSION, owner, s, auxiliary);
    }

    function decode(uint8 owner, bytes memory raw, RH.OwnerProvenance memory p)
        public
        pure
        returns (M.State memory s)
    {
        bytes memory auxiliary;
        (s, auxiliary) = decodeAuxiliary(owner, raw, p);
    }

    function decodeAuxiliary(uint8 owner, bytes memory raw, RH.OwnerProvenance memory p)
        public
        pure
        returns (M.State memory s, bytes memory auxiliary)
    {
        bytes32 tag;
        uint16 version;
        uint8 actual;
        (tag, version, actual, s, auxiliary) =
            abi.decode(raw, (bytes32, uint16, uint8, M.State, bytes));
        if (
            tag != SCHEMA || version != M.VERSION || actual != owner
                || keccak256(raw) != keccak256(abi.encode(tag, version, actual, s, auxiliary))
                || auxiliary.length == 0
        ) _invalid();
        validate(owner, s, p);
        ProofDecode.requireValid(ProofDecode.Context(owner, auxiliary, p));
    }

    function outer(uint8 owner, AH.Query memory anchor, bytes memory raw)
        public
        pure
        returns (M.State memory s, Payload.Payload memory payload)
    {
        RH.ExportHeader memory h;
        (h, payload) = Payload.decode(raw, owner);
        if (
            (h.requiredFeatures & (G.FEATURE | RH.BINDING_GENERATIONS))
                    != (G.FEATURE | RH.BINDING_GENERATIONS)
                || (h.requiredFeatures & ~G.ALLOWED) != 0
        ) _invalid();
        s = decode(owner, payload.semanticState, payload.provenance);
        AH.Query memory expected = anchorQuery(s);
        if (keccak256(abi.encode(anchor)) != keccak256(abi.encode(expected))) _invalid();
        if (owner != 2 && payload.nonces.length != 0) _invalid();
    }

    /// @dev A new struct prevents the envelope anchor from rewriting the first collection query.
    function anchorQuery(M.State memory s) public pure returns (AH.Query memory q) {
        AH.Query memory first = s.collections[0];
        q = AH.Query(
            first.artistId,
            first.collectionId,
            first.bindingHash,
            first.policies,
            s.artists[artist(s, first.artistId)].records
        );
    }

    function validate(uint8 owner, M.State memory s, RH.OwnerProvenance memory p) public pure {
        if (
            owner >= 7 || s.artists.length == 0 || s.artists.length > 128
                || s.collections.length == 0 || s.collections.length > 128
        ) _invalid();
        uint256 count =
            owner == 1 ? 0 : ((owner == 2 || owner == 5) ? s.artists.length : s.collections.length);
        if (s.rows.length != count) _invalid();
        for (uint256 i; i < s.artists.length; ++i) {
            AH.Query memory q = s.artists[i];
            if (
                q.artistId == 0 || q.collectionId != 0 || q.bindingHash != 0
                    || q.policies.length != 0 || (i != 0 && q.artistId <= s.artists[i - 1].artistId)
            ) _invalid();
        }
        uint256 policies;
        for (uint256 i; i < s.collections.length; ++i) {
            AH.Query memory q = s.collections[i];
            if (
                q.collectionId == 0 || q.bindingHash == 0 || q.policies.length > 128
                    || (i != 0 && q.collectionId <= s.collections[i - 1].collectionId)
            ) _invalid();
            artist(s, q.artistId);
            policies += q.policies.length;
            for (uint256 j; j < q.policies.length; ++j) {
                if (q.policies[j].phaseId == 0 || q.policies[j].policyHash == 0) _invalid();
                for (uint256 k; k < j; ++k) {
                    if (
                        q.policies[k].phaseId == q.policies[j].phaseId
                            && q.policies[k].policyHash == q.policies[j].policyHash
                    ) _invalid();
                }
            }
        }
        if (policies > 128) _invalid();
        // Every global native occurrence remains present at its original index and local clock.
        // Scope checks are against the full journal, never a synthetic filtered OwnerProvenance.
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            artist(s, j.receipt.artistId);
            if (j.receipt.collectionId != 0) {
                uint256 at = collection(s, j.receipt.collectionId);
                if (
                    s.collections[at].artistId != j.receipt.artistId
                        && !(owner == 3 && j.receipt.operation == 7)
                ) _invalid();
            }
        }
    }

    function artist(M.State memory s, bytes32 id) public pure returns (uint256) {
        for (uint256 i; i < s.artists.length; ++i) {
            if (s.artists[i].artistId == id) return i;
        }
        _invalid();
        return 0;
    }

    function collection(M.State memory s, uint256 id) public pure returns (uint256) {
        for (uint256 i; i < s.collections.length; ++i) {
            if (s.collections[i].collectionId == id) return i;
        }
        _invalid();
        return 0;
    }

    function proof(uint8 owner, bytes memory raw, RH.OwnerProvenance memory local)
        public
        pure
        returns (G.Proof memory result)
    {
        ProofDecode.requireValid(ProofDecode.Context(owner, raw, local));
        // The original ABI result is exactly the complete canonical abi.encode(G.Proof).
        // Terminal return avoids re-decoding and copying its deeply nested memory tuple.
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    /// @notice Exact import prelude with complete typed scope/payload bytes retained.
    /// @dev In particular the original 34-word NonceWord tuples are not decoded again
    /// in the caller; no nonce field, publication or owner provenance is omitted.
    function prepareSource(uint8 owner, AH.Query memory anchor, bytes memory raw)
        public
        pure
        returns (bytes memory scopeBytes, bytes memory payloadBytes, bytes memory proofBytes)
    {
        (M.State memory s, Payload.Payload memory p) = outer(owner, anchor, raw);
        (, proofBytes) = decodeAuxiliary(owner, p.semanticState, p.provenance);
        ProofDecode.requireValid(ProofDecode.Context(owner, proofBytes, p.provenance));
        scopeBytes = abi.encode(s);
        payloadBytes = abi.encode(p);
    }

    /// @notice Exact owner4 import prelude. The complete original payload is decoded
    /// and validated here before projecting its only consumed field, provenance.
    function prepareAttribution(AH.Query memory anchor, bytes memory raw)
        public
        pure
        returns (M.State memory s, RH.OwnerProvenance memory provenance, bytes memory auxiliary)
    {
        Payload.Payload memory p;
        (s, p) = outer(4, anchor, raw);
        SanctionTransport.requireFeature(s.rows, raw);
        (, auxiliary) = decodeAuxiliary(4, p.semanticState, p.provenance);
        provenance = p.provenance;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
