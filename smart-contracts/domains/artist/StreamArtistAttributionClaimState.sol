// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistAttributionClaimTypes as AC
} from "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";

/// @notice Permissionless allegations are append-only; no attribution or standing authority changes.
library StreamArtistAttributionClaimState {
    struct Store {
        mapping(uint256 => uint256) counts;
        mapping(uint256 => bytes32) latest;
        mapping(bytes32 => AC.Claim) records;
        mapping(bytes32 => bool) subjects;
    }
    event AttributionClaimFiled(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed claimant,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        string reasonURI,
        uint64 filedAt,
        bytes32 claimRecordHash
    );

    function file(
        Store storage s,
        address registry,
        address core,
        address actor,
        uint256 id,
        bytes32 evidence,
        bytes32 reason,
        string memory uri,
        address proposedArtist
    ) public returns (bytes32 record) {
        bytes32 subject = keccak256(abi.encode(id, actor, evidence, reason));
        if (
            id == 0 || actor == address(0) || evidence == 0 || reason == 0
                || bytes(uri).length > 4096 || s.subjects[subject] || block.timestamp == 0
                || block.timestamp > type(uint64).max
        ) {
            revert AC.InvalidAttributionClaim(id);
        }
        uint64 now_ = uint64(block.timestamp);
        record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1"),
                block.chainid,
                registry,
                core,
                id,
                actor,
                evidence,
                reason,
                now_
            )
        );
        if (s.records[record].recordHash != 0) revert AC.InvalidAttributionClaim(id);
        s.subjects[subject] = true;
        uint256 index = ++s.counts[id];
        s.records[record] = AC.Claim(
            record, id, actor, evidence, reason, uri, now_, proposedArtist, s.latest[id], index
        );
        s.latest[id] = record;
        emit AttributionClaimFiled(1, id, actor, evidence, reason, uri, now_, record);
    }
}
