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
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice Canonical aggregate scope and complete whole-owner membership; no projected provenance.
library StreamArtistRecoveredMultipleCodec {
    function selected(bytes memory outer, uint8 owner) public pure returns (bool) {
        (RH.ExportHeader memory h,) = Payload.decode(outer, owner);
        return (h.requiredFeatures & RH.MULTIPLE_BASE) != 0;
    }

    function encode(uint8 owner, M.State memory s, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes memory)
    {
        validate(owner, s, p);
        return abi.encode(M.SCHEMA, M.VERSION, owner, s);
    }

    function decode(uint8 owner, bytes memory raw, RH.OwnerProvenance memory p)
        public
        pure
        returns (M.State memory s)
    {
        bytes32 tag;
        uint16 version;
        uint8 actual;
        (tag, version, actual, s) = abi.decode(raw, (bytes32, uint16, uint8, M.State));
        if (
            tag != M.SCHEMA || version != M.VERSION || actual != owner
                || keccak256(raw) != keccak256(abi.encode(tag, version, actual, s))
        ) _invalid();
        validate(owner, s, p);
    }

    function outer(uint8 owner, AH.Query memory anchor, bytes memory raw)
        public
        pure
        returns (M.State memory s, Payload.Payload memory payload)
    {
        RH.ExportHeader memory h;
        (h, payload) = Payload.decode(raw, owner);
        if (
            (h.requiredFeatures & RH.MULTIPLE_BASE) == 0
                || (h.requiredFeatures & ~(RH.FIRST_GRAPH_FEATURES | RH.MULTIPLE_BASE)) != 0
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
                || (s.artists.length == 1 && s.collections.length == 1)
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
            bool found;
            for (uint256 j; j < s.collections.length; ++j) {
                if (s.collections[j].artistId == q.artistId) found = true;
            }
            if (!found) _invalid();
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
                if (s.collections[at].artistId != j.receipt.artistId) _invalid();
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

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
