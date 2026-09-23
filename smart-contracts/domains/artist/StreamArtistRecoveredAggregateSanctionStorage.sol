// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import { StreamArtistSanctionState as Sanctions } from "./StreamArtistSanctionState.sol";
import { StreamArtistSanctionHashes as Hashes } from "./StreamArtistSanctionHashes.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistSanctionArchiveFacts as ArchiveFacts
} from "../../interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";

/// @notice Exact original sanction maps through the existing owner's typed storage roots.
/// @dev The caller proves the complete original inventory and chronology before installation.
/// Publication bytes and replay state remain with the original guarded owner import pipeline.
library StreamArtistRecoveredAggregateSanctionStorage {
    function install(Sanctions.State storage state, H.Inventory memory x) public {
        if (x.sanctions.length > RH.MAX_JOURNAL_ENTRIES) _invalid();
        S.Record memory emptyRecord;
        ArchiveFacts.Facts memory emptyFacts;
        // All existing keys, including repeated association heads, are checked before any write.
        for (uint256 i; i < x.sanctions.length; ++i) {
            H.SanctionRow memory row = x.sanctions[i];
            bytes32 hash = row.record.recordHash;
            if (
                hash == 0 || row.record.artistId == 0 || row.record.bindingGeneration == 0
                    || row.record.bindingHash == 0 || row.record.terms.collectionId == 0
                    || row.archiveBytes.length == 0 || row.archiveBytes.length > type(uint64).max
                    || row.archiveFacts.sanctionRecordHash != hash
                    || row.archiveFacts.artistId != row.record.artistId
                    || row.archiveFacts.schemaId != Hashes.ARCHIVE_SCHEMA
                    || row.archiveFacts.canonicalizationId != Hashes.ARCHIVE_CANONICALIZATION
                    || row.archiveFacts.contentHash != keccak256(row.archiveBytes)
                    || row.archiveFacts.byteLength != row.archiveBytes.length
                    || keccak256(abi.encode(state.records[hash]))
                        != keccak256(abi.encode(emptyRecord))
                    || state.latest[_association(row.record)] != 0
                    || state.archives[hash].length != 0
                    || keccak256(abi.encode(state.archiveFacts[hash]))
                        != keccak256(abi.encode(emptyFacts))
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (x.sanctions[j].record.recordHash == hash) _invalid();
            }
        }
        for (uint256 i; i < x.sanctions.length; ++i) {
            H.SanctionRow memory row = x.sanctions[i];
            bytes32 hash = row.record.recordHash;
            state.records[hash] = row.record;
            state.archives[hash] = row.archiveBytes;
            state.archiveFacts[hash] = row.archiveFacts;
            state.latest[_association(row.record)] = hash;
        }
    }

    function _association(S.Record memory row) private pure returns (bytes32) {
        return
            Sanctions.associationKey(
                row.artistId, row.bindingGeneration, row.bindingHash, row.terms
            );
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
