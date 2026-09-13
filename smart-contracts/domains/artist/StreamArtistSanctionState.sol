// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistConsentState.sol";
import "./StreamArtistSanctionHashes.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistSanctionOwner.sol";

/// @notice Append-only sanction evidence in the existing Consent owner's storage and event context.
library StreamArtistSanctionState {
    struct State {
        mapping(bytes32 => S.Record) records;
        mapping(bytes32 => bytes32) latest;
        mapping(bytes32 => bytes) archives;
        mapping(bytes32 => IStreamArtistSanctionArchiveFacts.Facts) archiveFacts;
    }

    struct Input {
        T.Binding binding_;
        S.Record record;
        R.AuthorityFact authority;
        address finalityRegistry;
        bytes ceremony;
        bytes signature;
    }

    event ArtistSanctionRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed sanctionSubjectHash,
        address indexed signer,
        uint8 scopeType,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 sanctionRecordHash,
        uint8 authorityClass,
        bytes32 statementHash,
        uint256 nonce,
        uint64 signedAt
    );

    /// @dev One hardwired host callback; decoding is extracted to keep the existing owner deployable.
    ///      The host checks its own context before forwarding the original exact calldata.
    function recordEncoded(
        State storage state,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistConsentState.Context memory o,
        bytes calldata callData
    ) public returns (StreamArtistConsentState.Mutation memory) {
        if (bytes4(callData) != IStreamArtistSanctionOwner.recordSanction.selector) revert S.InvalidSanction();
        (
            ,
            T.Binding memory b,
            S.Record memory r,
            R.AuthorityFact memory authority,
            address finality,
            bytes memory ceremony,
            bytes memory signature
        ) = abi.decode(
            callData[4:],
            (T.ActionContext, T.Binding, S.Record, R.AuthorityFact, address, bytes, bytes)
        );
        return record(state, replay, o, Input(b, r, authority, finality, ceremony, signature));
    }

    function recordEncodedRead(State storage state, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(state.records[hash]);
    }

    function archiveEncodedRead(State storage state, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        if (state.records[hash].recordHash == 0) revert S.InvalidSanction();
        return abi.encode(state.archives[hash]);
    }

    function factsEncodedRead(State storage state, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        if (state.records[hash].recordHash == 0) revert S.InvalidSanction();
        return abi.encode(state.archiveFacts[hash]);
    }

    function record(
        State storage state,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistConsentState.Context memory o,
        Input memory x
    ) public returns (StreamArtistConsentState.Mutation memory m) {
        S.Record memory r = x.record;
        StreamArtistCurrentAuthorityFacts.requireAccepted(x.binding_, r.signer, x.authority, false);
        if (
            r.artistId != x.binding_.artistId || r.authorityClass != x.authority.authorityClass
                || r.bindingGeneration != x.binding_.generation
                || r.bindingHash != x.binding_.bindingHash || r.signedAt != o.observedAt
                || r.deadline < o.observedAt || x.finalityRegistry == address(0)
                || r.terms.sanctionSubjectHash == 0 || r.terms.statementHash == 0
                || r.digest
                    != StreamArtistSanctionHashes.digest(
                        o.environment, r.terms, T.Authorization(r.nonce, r.deadline, x.signature)
                    )
        ) revert S.InvalidSanction();
        _scope(r.terms);
        bytes memory archive = StreamArtistSanctionHashes.archiveBytes(
            o.environment, x.finalityRegistry, r, x.ceremony, x.signature
        );
        bytes32 scopeKey = associationKey(r.artistId, r.bindingGeneration, r.bindingHash, r.terms);
        bytes32 replayKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                keccak256("consent_finality.replay.sanction_uniqueness"),
                keccak256(abi.encode(r.recordHash))
            )
        );
        if (replay[replayKey].status != 0) revert T.Replay(replayKey);
        if (state.records[r.recordHash].recordHash != 0) revert S.InvalidSanction();
        replay[replayKey] = T.ReplayCell(r.recordHash, o.revision + 1, 1, 2);
        bytes32 previous = state.latest[scopeKey];
        state.records[r.recordHash] = r;
        state.latest[scopeKey] = r.recordHash;
        state.archives[r.recordHash] = archive;
        IStreamArtistSanctionArchiveFacts.Facts memory facts =
            IStreamArtistSanctionArchiveFacts.Facts(
                r.recordHash,
                r.artistId,
                StreamArtistSanctionHashes.ARCHIVE_SCHEMA,
                StreamArtistSanctionHashes.ARCHIVE_CANONICALIZATION,
                keccak256(archive),
                uint64(archive.length)
            );
        state.archiveFacts[r.recordHash] = facts;
        m.record = r.recordHash;
        m.action = keccak256(
            abi.encode(
                x.binding_, r, x.finalityRegistry, keccak256(x.ceremony), keccak256(x.signature)
            )
        );
        m.state = keccak256(abi.encode(scopeKey, previous, r, facts));
        m.replay = keccak256(abi.encode(replayKey, r.recordHash));
        _emit(r);
    }

    function associationKey(
        bytes32 artistId,
        uint64 generation,
        bytes32 bindingHash,
        S.Terms memory p
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                artistId, generation, bindingHash, p.scopeType, p.collectionId, p.tokenId, p.scopeId
            )
        );
    }

    function _scope(S.Terms memory p) private pure {
        if (
            p.collectionId == 0 || p.scopeType > 4
                || (p.scopeType == 0 && (p.tokenId != 0 || p.scopeId != 0))
                || (p.scopeType == 1 && (p.tokenId == 0 || p.scopeId != 0))
                || (p.scopeType > 1 && (p.tokenId != 0 || p.scopeId == 0))
        ) revert S.InvalidSanction();
    }

    function _emit(S.Record memory r) private {
        emit ArtistSanctionRecorded(
            1,
            r.terms.collectionId,
            r.terms.sanctionSubjectHash,
            r.signer,
            r.terms.scopeType,
            r.terms.tokenId,
            r.terms.scopeId,
            r.recordHash,
            r.authorityClass,
            r.terms.statementHash,
            r.nonce,
            r.signedAt
        );
    }
}
