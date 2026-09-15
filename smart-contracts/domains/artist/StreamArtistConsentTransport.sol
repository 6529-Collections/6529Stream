// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistConsentState.sol";
import "./StreamArtistContentHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";

/// @notice Fixed decoding of original Consent writer calls after their host authority checks.
/// @dev No ledger, signature or receipt policy is introduced; fixed state workers remain authoritative.
library StreamArtistConsentTransport {
    function saleEncoded(
        mapping(bytes32 => Sale.Record) storage records,
        mapping(bytes32 => bytes32) storage latest,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistConsentState.Context memory o,
        bytes calldata encoded,
        uint8 principalClass
    ) public returns (StreamArtistConsentState.Mutation memory) {
        (, T.Binding memory b, Sale.Consent memory p, address signer, uint256 nonce) =
            abi.decode(encoded[4:], (T.ActionContext, T.Binding, Sale.Consent, address, uint256));
        return StreamArtistConsentState.saleConsentForAuthority(
            records, latest, replay, o, b, p, signer, principalClass, nonce
        );
    }

    function policyEncoded(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistConsentState.Context memory o,
        bytes calldata encoded,
        uint8 principalClass
    ) public returns (StreamArtistConsentState.Mutation memory) {
        (, T.Binding memory b, T.PolicyConsent memory p, address signer, uint256 nonce) =
            abi.decode(encoded[4:], (T.ActionContext, T.Binding, T.PolicyConsent, address, uint256));
        return StreamArtistConsentState.policyForAuthority(
            records, replay, o, b, p, signer, principalClass, nonce
        );
    }

    function economicsEncoded(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => bytes32) storage delegations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        mapping(bytes32 => EconomicsEvidence.Association) storage associations,
        mapping(bytes32 => bytes32) storage associatedRecords,
        StreamArtistConsentState.Context memory o,
        bytes calldata encoded,
        uint8 principalClass,
        bytes32 grant
    ) public returns (StreamArtistConsentState.Mutation memory) {
        (
            ,
            T.Binding memory b,
            T.EconomicsConsent memory p,
            T.Payout memory designation,
            address signer,
            uint256 nonce
        ) = abi.decode(
            encoded[4:],
            (T.ActionContext, T.Binding, T.EconomicsConsent, T.Payout, address, uint256)
        );
        return StreamArtistConsentState.economicsAssociatedForAuthority(
            records,
            delegations,
            replay,
            associations,
            associatedRecords,
            o,
            b,
            p,
            designation,
            signer,
            principalClass,
            nonce,
            grant
        );
    }

    function ratificationEncoded(
        mapping(uint256 => T.RatificationRecord) storage records,
        mapping(bytes32 => T.RatificationRecord) storage history,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistConsentState.Context memory o,
        bytes calldata encoded,
        uint8 principalClass
    ) public returns (StreamArtistConsentState.Mutation memory) {
        (, T.Binding memory b, T.Ratification memory p, address signer, uint256 nonce) =
            abi.decode(encoded[4:], (T.ActionContext, T.Binding, T.Ratification, address, uint256));
        return StreamArtistConsentState.ratificationForAuthority(
            records, history, replay, o, b, p, signer, principalClass, nonce
        );
    }

    event ArtistContentConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed familyId,
        address indexed signer,
        bytes32 newStateHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 consentRecordHash
    );
    event ArtistContentRecordContext(
        uint16 schemaVersion, bytes32 indexed recordHash, address metadataContract, bytes32 artistId
    );

    function contentConsentEncoded(
        mapping(bytes32 => IStreamArtistContentRecordsOwner.ConsentRecord) storage records,
        mapping(bytes32 => bytes32) storage latest,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistConsentState.Context memory o,
        bytes calldata encoded,
        uint8 authorityClass
    ) public returns (StreamArtistConsentState.Mutation memory m) {
        (, T.Binding memory b, Content.Consent memory p, address signer, uint256 nonce) =
            abi.decode(encoded[4:], (T.ActionContext, T.Binding, Content.Consent, address, uint256));
        m.record = StreamArtistContentHashes.consentRecord(
            o.environment, p, b.artistId, signer, authorityClass, nonce, o.observedAt
        );
        bytes32 scope = keccak256(abi.encode(p, b.generation));
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                keccak256("consent_finality.replay.content_consent_key"),
                keccak256(abi.encode(scope, m.record))
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(m.record, o.revision + 1, 1, 2);
        StreamArtistAuthorityCheckpoint.noteReplay(key, replay[key]);
        IStreamArtistContentRecordsOwner.ConsentRecord memory item =
            IStreamArtistContentRecordsOwner.ConsentRecord(
                m.record, b.artistId, b.generation, p, authorityClass
            );
        records[m.record] = item;
        latest[scope] = m.record;
        m.action = keccak256(abi.encode(b, p, signer, nonce));
        m.state = keccak256(abi.encode(scope, item));
        m.replay = keccak256(abi.encode(key, m.record));
    }

    /// @dev Called only after the host's original commit and native receipt append.
    function emitContentConsentEncoded(
        bytes calldata encoded,
        bytes32 record,
        uint8 authorityClass,
        uint64 observedAt
    ) public {
        (, T.Binding memory b, Content.Consent memory p, address signer, uint256 nonce) = abi.decode(
            encoded[4:], (T.ActionContext, T.Binding, Content.Consent, address, uint256)
        );
        emit ArtistContentConsentRecorded(
            1,
            p.collectionId,
            p.familyId,
            signer,
            p.newStateHash,
            authorityClass,
            nonce,
            observedAt,
            record
        );
        emit ArtistContentRecordContext(1, record, p.metadataContract, b.artistId);
    }

    event ArtistContentFreezeAuthorized(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed signer,
        bytes32[] lockClasses,
        bytes32 expectedStateHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 freezeRecordHash
    );

    function contentFreezeEncoded(
        mapping(bytes32 => Content.FreezeRecord) storage records,
        mapping(bytes32 => bytes32) storage latest,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistConsentState.Context memory o,
        bytes calldata encoded,
        uint8 authorityClass
    ) public returns (StreamArtistConsentState.Mutation memory m) {
        (, T.Binding memory b, Content.Freeze memory p, address signer, uint256 nonce) =
            abi.decode(encoded[4:], (T.ActionContext, T.Binding, Content.Freeze, address, uint256));
        m.record = StreamArtistContentHashes.freezeRecord(
            o.environment, p, b.artistId, signer, authorityClass, nonce, o.observedAt
        );
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                keccak256("consent_finality.replay.freeze_key"),
                keccak256(abi.encode(keccak256("CONTENT"), p.collectionId, b.generation, m.record))
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(m.record, o.revision + 1, 1, 2);
        StreamArtistAuthorityCheckpoint.noteReplay(key, replay[key]);
        Content.FreezeRecord memory item = Content.FreezeRecord(
            m.record,
            b.artistId,
            b.generation,
            p.metadataContract,
            p.lockClasses,
            p.expectedStateHash,
            authorityClass
        );
        records[m.record] = item;
        for (uint256 i; i < p.lockClasses.length; ++i) {
            latest[
                keccak256(
                    abi.encode(p.collectionId, b.generation, p.metadataContract, p.lockClasses[i])
                )
            ] = m.record;
        }
        m.action = keccak256(abi.encode(b, p, signer, nonce));
        m.state = keccak256(abi.encode(p.collectionId, item));
        m.replay = keccak256(abi.encode(key, m.record));
    }

    /// @dev Called only after the host's original commit and native receipt append.
    function emitContentFreezeEncoded(
        bytes calldata encoded,
        bytes32 record,
        uint8 authorityClass,
        uint64 observedAt
    ) public {
        (, T.Binding memory b, Content.Freeze memory p, address signer, uint256 nonce) = abi.decode(
            encoded[4:], (T.ActionContext, T.Binding, Content.Freeze, address, uint256)
        );
        emit ArtistContentFreezeAuthorized(
            1,
            p.collectionId,
            signer,
            p.lockClasses,
            p.expectedStateHash,
            authorityClass,
            nonce,
            observedAt,
            record
        );
        emit ArtistContentRecordContext(1, record, p.metadataContract, b.artistId);
    }
}
