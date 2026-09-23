// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistMultipleHydrationCodec.sol";
import "./StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

/// @notice Writes only the typed original baseline cells after the host's unchanged operation60 guard.
library StreamArtistMultipleCollectionHydration {
    function _rows(bytes memory raw) private pure returns (MH.Row[] memory rows) {
        MH.Bundle memory b = StreamArtistMultipleHydrationCodec.decode(raw);
        if (b.artistIds.length != 0 || b.collectionIds.length != 0 || b.registrationCount != 0) {
            revert T.InvalidRecord();
        }
        rows = b.rows;
        for (uint256 i; i < rows.length; ++i) {
            if (
                rows[i].query.artistId == 0 || rows[i].query.collectionId == 0
                    || rows[i].query.bindingHash == 0 || rows[i].nonces.length != 0
                    || rows[i].query.records.length != 0
                    || (i != 0 && rows[i].query.collectionId <= rows[i - 1].query.collectionId)
            ) revert T.InvalidRecord();
        }
    }

    function bindings(
        mapping(uint256 => T.Binding) storage current,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        bytes memory raw
    ) public {
        MH.Row[] memory rows = _rows(raw);
        for (uint256 i; i < rows.length; ++i) {
            AH.Query memory q = rows[i].query;
            AH.Binding memory b = abi.decode(rows[i].state, (AH.Binding));
            if (
                current[q.collectionId].generation != 0 || b.item.artistId != q.artistId
                    || b.item.bindingHash != q.bindingHash || b.item.generation != 1
                    || !b.item.accepted || b.item.consentMode != 1 || b.terms.count != 0
                    || b.terms.mode != 0 || b.terms.threshold != 0
            ) {
                revert T.InvalidRecord();
            }
            current[q.collectionId] = b.item;
            history[q.collectionId][1] = b.item;
            terms[q.collectionId][1] = b.terms;
        }
    }

    function acceptances(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => uint64) storage times,
        bytes memory raw
    ) public {
        MH.Row[] memory rows = _rows(raw);
        for (uint256 i; i < rows.length; ++i) {
            bytes32 hash = rows[i].query.bindingHash;
            AH.Acceptance memory a = abi.decode(rows[i].state, (AH.Acceptance));
            if (records[hash] != 0 || a.record == 0 || a.acceptedAt == 0) revert T.InvalidRecord();
            records[hash] = a.record;
            times[hash] = a.acceptedAt;
        }
    }

    function attributions(AS.State storage s, bytes memory raw) public {
        MH.Row[] memory rows = _rows(raw);
        for (uint256 i; i < rows.length; ++i) {
            uint256 id = rows[i].query.collectionId;
            AS.Attribution memory a = abi.decode(rows[i].state, (AS.Attribution));
            if (s.attributions[id].generation != 0 || a.generation != 1 || a.state != 2) {
                revert T.InvalidRecord();
            }
            s.attributions[id] = a;
        }
    }

    function policies(mapping(bytes32 => bytes32) storage current, bytes memory raw) public {
        MH.Row[] memory rows = _rows(raw);
        for (uint256 i; i < rows.length; ++i) {
            AH.Query memory q = rows[i].query;
            bytes32[] memory records = abi.decode(rows[i].state, (bytes32[]));
            if (records.length != q.policies.length) revert T.InvalidRecord();
            for (uint256 j; j < records.length; ++j) {
                bytes32 key = keccak256(
                    abi.encode(q.collectionId, q.policies[j].phaseId, q.policies[j].policyHash)
                );
                if (current[key] != 0 || records[j] == 0) revert T.InvalidRecord();
                current[key] = records[j];
            }
        }
    }
}
