// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistIdentityState.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";

/// @notice Linked operation-25 mechanics over the sole Identity owner's storage.
library StreamArtistIdentityRevisionState {
    struct State {
        mapping(bytes32 => bytes32) latestRecord;
        mapping(bytes32 => StreamArtistIdentityRevisionTypes.Record) records;
    }

    event ArtistIdentityRevisionRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed signer,
        bytes32 previousRecordHash,
        bytes32 revisedRecordHash,
        string identityRecordURI,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 revisionRecordHash
    );
    event ArtistIdentityDisplayNameStored(
        bytes32 indexed artistId, bytes32 indexed identityRecordHash, string displayName
    );

    function digest(
        StreamArtistHashes.Environment memory e,
        StreamArtistIdentityRevisionTypes.Revision memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0xbfb7a5d3bc248c8eefbe4f8dfc2ea7d75d18c5cb3f2ab0d56000fd87f4b58603),
                    p.artistId,
                    p.previousRecordHash,
                    p.revisedRecordHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function operative(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        bytes32 artistId
    ) internal view returns (bytes32) {
        bytes32 registration = identity.identities[artistId].identityRecordHash;
        if (registration == bytes32(0)) revert T.InvalidIdentity(artistId);
        bytes32 latest = s.latestRecord[artistId];
        return latest == bytes32(0) ? registration : s.records[latest].revisedRecordHash;
    }

    function metadata(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        bytes32 artistId
    ) public view returns (bytes32 documentHash, string memory uri, string memory displayName) {
        documentHash = operative(s, identity, artistId);
        bytes32 latest = s.latestRecord[artistId];
        if (latest == bytes32(0)) {
            T.Identity storage original = identity.identities[artistId];
            return (documentHash, original.identityRecordURI, original.displayName);
        }
        StreamArtistIdentityRevisionTypes.Record storage r = s.records[latest];
        return (documentHash, r.identityRecordURI, r.displayName);
    }

    function revise(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        StreamArtistIdentityRevisionTypes.Revision memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes memory document,
        string memory displayName
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        if (
            p.previousRecordHash != operative(s, identity, p.artistId)
                || p.revisedRecordHash == bytes32(0) || p.revisedRecordHash == p.previousRecordHash
                || document.length == 0 || keccak256(document) != p.revisedRecordHash
                || bytes(displayName).length == 0 || a.time == 0 || a.time > block.timestamp
                || (proof.direct && a.time != block.timestamp)
        ) revert T.InvalidRecord();
        if (document.length > 8192) revert T.BoundExceeded(document.length, 8192);
        if (bytes(p.identityRecordURI).length > 2048) {
            revert T.BoundExceeded(bytes(p.identityRecordURI).length, 2048);
        }
        if (bytes(displayName).length > 256) {
            revert T.BoundExceeded(bytes(displayName).length, 256);
        }
        bytes32 previousRevision = s.latestRecord[p.artistId];
        bytes32 record = keccak256(
            abi.encode(
                bytes32(0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4),
                o.environment.chainId,
                o.environment.registry,
                p.artistId,
                p.previousRecordHash,
                p.revisedRecordHash,
                proof.signer,
                uint8(1),
                a.nonce,
                a.time
            )
        );
        bytes32 chainKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                keccak256("identity_authority.replay.identity_revision_chain"),
                keccak256(abi.encode(p.artistId, previousRevision, p.previousRecordHash))
            )
        );
        if (replay[chainKey].status != 0) revert T.Replay(chainKey);
        if (s.records[record].recordHash != bytes32(0)) revert T.InvalidRecord();
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            a,
            proof,
            digest(o.environment, p, a),
            record,
            identity.identities[p.artistId].authorityAddress
        );
        StreamArtistIdentityRevisionTypes.Record memory item =
            StreamArtistIdentityRevisionTypes.Record(
                record,
                p.artistId,
                p.previousRecordHash,
                p.revisedRecordHash,
                previousRevision,
                proof.signer,
                1,
                a.nonce,
                a.time,
                p.identityRecordURI,
                displayName
            );
        s.records[record] = item;
        s.latestRecord[p.artistId] = record;
        if (identity.documents[p.revisedRecordHash].length == 0) {
            identity.documents[p.revisedRecordHash] = document;
        }
        replay[chainKey] = T.ReplayCell(record, o.revision + 1, 1, 2);
        m.record = record;
        m.action = keccak256(abi.encode(p, a, proof, keccak256(document), displayName));
        m.state = keccak256(abi.encode(m.state, previousRevision, item));
        m.replay = keccak256(abi.encode(m.replay, chainKey, record));
        emit ArtistIdentityRevisionRecorded(
            1,
            p.artistId,
            proof.signer,
            p.previousRecordHash,
            p.revisedRecordHash,
            p.identityRecordURI,
            1,
            a.nonce,
            a.time,
            record
        );
        emit ArtistIdentityDisplayNameStored(p.artistId, p.revisedRecordHash, displayName);
    }
}
