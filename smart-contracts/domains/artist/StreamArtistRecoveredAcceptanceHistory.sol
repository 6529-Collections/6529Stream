// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredDisputeAcceptanceHistory as DisputeHistory } from "./StreamArtistRecoveredDisputeAcceptanceHistory.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice Every actual accepted binding's original record/time; no guessed signer preimage.
library StreamArtistRecoveredAcceptanceHistory {
    bytes32 private constant KEY = keccak256("acceptance_lifecycle.replay.record_uniqueness");

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        G.Bundle memory bindings
    ) public view returns (A.AcceptanceBundle memory b) {
        P.validateOwnerSource(p, 3, source);
        b.provenance = RH.ownerProvenanceHash(p, 3);
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.bindingHash = q.bindingHash;
        uint256 n;
        for (uint256 i; i < bindings.rows.length; ++i) {
            if (bindings.rows[i].item.accepted) ++n;
        }
        b.rows = new A.Acceptance[](n);
        n = 0;
        for (uint256 i; i < bindings.rows.length; ++i) {
            if (!bindings.rows[i].item.accepted) continue;
            bytes32 h = bindings.rows[i].item.bindingHash;
            b.rows[n++] = A.Acceptance(
                h,
                uint64(i + 1),
                Acceptance(source).acceptanceRecord(h),
                Acceptance(source).acceptedAt(h)
            );
        }
        validate(b, q, p);
    }

    function validate(A.AcceptanceBundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
    {
        if (
            P.validateOwner(p, 3) != b.provenance || b.artistId != q.artistId
                || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                || q.artistId == 0 || q.collectionId == 0 || q.bindingHash == 0 || b.rows.length < 2
                || b.rows.length > 128 || b.rows.length != p.journal.length
                || b.rows[b.rows.length - 1].bindingHash != q.bindingHash
        ) _invalid();
        uint256[] memory counts = new uint256[](p.eras.length);
        uint256 previousEra;
        for (uint256 i; i < b.rows.length; ++i) {
            A.Acceptance memory r = b.rows[i];
            RH.JournalEntry memory j = p.journal[i];
            uint256 e = A.era(p, j.position.point.environmentHash);
            if (
                r.bindingHash == 0 || r.recordHash == 0 || r.acceptedAt == 0 || r.generation == 0
                    || (i != 0 && b.rows[i - 1].generation >= r.generation) || e < previousEra
                    || j.receipt.operation != 2 || j.receipt.recordHash != r.recordHash
                    || j.receipt.artistId != q.artistId || j.receipt.collectionId != q.collectionId
                    || j.position.point.ownerRevision != (e == 0 ? 0 : 1) + counts[e] + 1
            ) _invalid();
            previousEra = e;
            ++counts[e];
            for (uint256 k; k < i; ++k) {
                if (b.rows[k].recordHash == r.recordHash || b.rows[k].bindingHash == r.bindingHash)
                {
                    _invalid();
                }
            }
        }
        uint256 total;
        for (uint256 e; e < p.eras.length; ++e) {
            total += counts[e];
            RH.OwnerEra memory era_ = p.eras[e];
            if (
                era_.nativeCount != counts[e] || era_.lowerRevision != (e == 0 ? 0 : 1)
                    || era_.checkpoint.ownerState.revision != era_.lowerRevision + counts[e]
                    || era_.checkpoint.replayCount != total || era_.checkpoint.nonceIndexCount != 0
                    || era_.checkpoint.nonceRoot != 0
            ) _invalid();
        }
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (a.surface != KEY || a.scope == 0 || a.cell.kind != 1 || a.cell.status != 2) _invalid();
            bool found;
            for (uint256 j; j < b.rows.length; ++j) {
                if (a.cell.commitment == b.rows[j].recordHash) {
                    if (
                        keccak256(abi.encode(a.admittedAt))
                            != keccak256(abi.encode(p.journal[j].position.point))
                    ) _invalid();
                    found = true;
                    break;
                }
            }
            if (!found) _invalid();
        }
        // One distinct logical guard for every admitted record in every later era. Counts alone
        // cannot distinguish a duplicate arbitrary acceptance scope from an omitted record.
        for (uint256 j; j < b.rows.length; ++j) {
            uint256 first = A.era(p, p.journal[j].position.point.environmentHash);
            bytes32 originalScope;
            for (uint256 e = first; e < p.eras.length; ++e) {
                uint256 matches;
                for (uint256 i; i < p.aliases.length; ++i) {
                    RH.ReplayAlias memory a = p.aliases[i];
                    if (
                        a.originHash == p.eras[e].originHash
                            && a.cell.commitment == b.rows[j].recordHash
                    ) {
                        if (originalScope == 0) originalScope = a.scope;
                        else if (a.scope != originalScope) _invalid();
                        ++matches;
                    }
                }
                if (matches != 1) _invalid();
            }
        }
    }

    function encode(A.AcceptanceBundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes memory)
    {
        validate(b, q, p);
        return abi.encode(A.ACCEPTANCE, RH.VERSION, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (A.AcceptanceBundle memory b)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, b) = abi.decode(raw, (bytes32, uint16, A.AcceptanceBundle));
        if (
            tag != A.ACCEPTANCE || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, b))
        ) _invalid();
        validate(b, q, p);
    }

    function importIfSelected(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => uint64) storage times,
        AH.Query memory q,
        bytes memory outer
    ) public returns (bool) {
        (RH.ExportHeader memory h, Payload.Payload memory p) = Payload.decode(outer, 3);
        if ((h.requiredFeatures & RH.DISPUTE_HISTORY) != 0) return DisputeHistory.importIfSelected(records, times, q, outer);
        if ((h.requiredFeatures & RH.ACCEPTED_GENERATIONS) == 0) return false;
        if (p.nonces.length != 0) _invalid();
        A.AcceptanceBundle memory b = decode(q, p.provenance, p.semanticState);
        for (uint256 i; i < b.rows.length; ++i) {
            if (records[b.rows[i].bindingHash] != 0 || times[b.rows[i].bindingHash] != 0) {
                revert T.InvalidRecord();
            }
        }
        for (uint256 i; i < b.rows.length; ++i) {
            records[b.rows[i].bindingHash] = b.rows[i].recordHash;
            times[b.rows[i].bindingHash] = b.rows[i].acceptedAt;
        }
        return true;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
