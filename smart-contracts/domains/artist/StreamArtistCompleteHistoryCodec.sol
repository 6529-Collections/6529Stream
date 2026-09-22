// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryTypes as C } from "./StreamArtistCompleteHistoryTypes.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistCompleteHistoryBindingTypes as Bindings
} from "./StreamArtistCompleteHistoryBindingTypes.sol";
import {
    StreamArtistCompleteHistoryPlatformTypes as Platform
} from "./StreamArtistCompleteHistoryPlatformTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
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
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice Canonical stage envelope for the separate complete-history representation.
/// @dev Inventory is presently a partial source phase. This codec proves canonical bytes,
/// membership and provenance joins, not the opaque owner row semantics or missing family
/// proofs. It must never authorize import by itself. Existing codecs and features are unchanged.
library StreamArtistCompleteHistoryCodec {
    function encode(
        uint8 owner,
        M.State memory s,
        RH.OwnerProvenance memory local,
        bytes memory auxiliary
    ) public pure returns (bytes memory) {
        C.Inventory memory proof = inventory(owner, auxiliary, local);
        validate(owner, s, proof);
        return abi.encode(C.SCHEMA, C.VERSION, owner, s, auxiliary);
    }

    function decode(uint8 owner, bytes memory raw, RH.OwnerProvenance memory local)
        public
        pure
        returns (M.State memory s)
    {
        (s,) = decodeAuxiliary(owner, raw, local);
    }

    function decodeAuxiliary(uint8 owner, bytes memory raw, RH.OwnerProvenance memory local)
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
            tag != C.SCHEMA || version != C.VERSION || actual != owner
                || keccak256(raw) != keccak256(abi.encode(tag, version, actual, s, auxiliary))
        ) _invalid();
        C.Inventory memory proof = inventory(owner, auxiliary, local);
        validate(owner, s, proof);
    }

    function inventory(uint8 owner, bytes memory raw, RH.OwnerProvenance memory local)
        public
        pure
        returns (C.Inventory memory proof)
    {
        if (owner >= 7 || raw.length == 0) _invalid();
        proof = abi.decode(raw, (C.Inventory));
        if (
            keccak256(raw) != keccak256(abi.encode(proof))
                || keccak256(abi.encode(local))
                    != keccak256(abi.encode(RH.ownerProvenance(proof.provenance, owner)))
        ) _invalid();
        Provenance.validate(proof.provenance);
    }

    /// @dev The existing outer decoder intentionally rejects the reserved bit until the
    /// integrator activates its known-feature/capability contract with a complete importer.
    function selected(bytes memory raw, uint8 owner) public pure returns (bool) {
        (RH.ExportHeader memory h,) = Payload.decode(raw, owner);
        return (h.requiredFeatures & C.FEATURE) != 0;
    }

    function outer(uint8 owner, AH.Query memory anchor, bytes memory raw)
        public
        pure
        returns (M.State memory s, Payload.Payload memory payload)
    {
        RH.ExportHeader memory h;
        (h, payload) = Payload.decode(raw, owner);
        if ((h.requiredFeatures & C.FEATURE) == 0 || (h.requiredFeatures & ~C.ALLOWED) != 0) {
            _invalid();
        }
        s = decode(owner, payload.semanticState, payload.provenance);
        if (keccak256(abi.encode(anchor)) != keccak256(abi.encode(anchorQuery(s)))) _invalid();
        if (owner != 2 && payload.nonces.length != 0) _invalid();
    }

    function anchorQuery(M.State memory s) public pure returns (AH.Query memory q) {
        if (s.collections.length == 0) _invalid();
        AH.Query memory first = s.collections[0];
        return AH.Query(
            first.artistId,
            first.collectionId,
            first.bindingHash,
            first.policies,
            first.artistId == 0 ? first.records : s.artists[Scope.artist(s, first.artistId)].records
        );
    }

    function validate(uint8 owner, M.State memory s, C.Inventory memory proof) public pure {
        if (
            owner >= 7 || s.artists.length > 128 || s.collections.length == 0
                || s.collections.length > 128
        ) _invalid();
        uint256 rows =
            owner == 1 ? 0 : (owner == 2 || owner == 5) ? s.artists.length : s.collections.length;
        if (
            s.rows.length != rows || proof.bindings.bindings.length != s.collections.length
                || proof.platforms.length != s.collections.length
                || proof.accepted.length != s.collections.length
        ) {
            _invalid();
        }
        MH.Request memory request;
        request.artistIds = new bytes32[](s.artists.length);
        for (uint256 i; i < s.artists.length; ++i) {
            request.artistIds[i] = s.artists[i].artistId;
        }
        request.collections = new MH.Collection[](s.collections.length);
        T.Binding[] memory heads = new T.Binding[](s.collections.length);
        for (uint256 k; k < s.collections.length; ++k) {
            AH.Query memory q = s.collections[k];
            request.collections[k] = MH.Collection(q.artistId, q.collectionId, q.policies);
            heads[k] = proof.bindings.bindings[k].bindings.current;
        }
        M.State memory expected = Scope.partition(request, heads, proof.provenance);
        if (
            keccak256(abi.encode(s.artists, s.collections))
                != keccak256(abi.encode(expected.artists, expected.collections))
        ) _invalid();
        Bindings.validate(
            s, proof.bindings, RH.ownerProvenanceHash(RH.ownerProvenance(proof.provenance, 0), 0)
        );
        RH.OwnerProvenance memory owner4 = RH.ownerProvenance(proof.provenance, 4);
        bytes32 owner3 = RH.ownerProvenanceHash(RH.ownerProvenance(proof.provenance, 3), 3);
        for (uint256 k; k < s.collections.length; ++k) {
            AH.Query memory q = s.collections[k];
            P.Platform memory platform = proof.platforms[k];
            Platform.requireRow(platform, owner4);
            A.AcceptanceBundle memory acceptance = proof.accepted[k];
            if (
                platform.collectionId != q.collectionId || acceptance.provenance != owner3
                    || acceptance.artistId != q.artistId
                    || acceptance.collectionId != q.collectionId
                    || acceptance.bindingHash != q.bindingHash
                    || acceptance.rows.length != proof.bindings.generations[k].length
            ) _invalid();
            if (
                q.artistId == 0
                    && (P.nativeCount(platform) == 0
                        || platform.state.correction.correctiveGeneration != 0
                        || platform.state.correction.accepted
                        || platform.continuations.length != 0)
            ) _invalid();
            for (uint256 g; g < acceptance.rows.length; ++g) {
                if (
                    acceptance.rows[g].bindingHash != proof.bindings.generations[k][g].bindingHash
                        || acceptance.rows[g].generation != g + 1
                ) _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
