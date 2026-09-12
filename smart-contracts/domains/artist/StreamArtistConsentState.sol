// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistSaleHashes.sol";

/// @notice Linked typed Consent mechanics; the owner retains its guard and single semantic commit.
/// @dev Mapping references are the owner's existing slots. No new owner or external authorization path.
library StreamArtistConsentState {
    struct Context {
        StreamArtistHashes.Environment environment;
        address coordinator;
        address archive;
        bytes32 domain;
        uint64 revision;
        uint64 observedAt;
    }

    struct Mutation {
        bytes32 record;
        bytes32 action;
        bytes32 state;
        bytes32 replay;
    }

    event ArtistSaleConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed saleConfigHash,
        address indexed signer,
        bytes32 saleId,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 consentRecordHash
    );

    function saleConsent(
        mapping(bytes32 => Sale.Record) storage records,
        mapping(bytes32 => bytes32) storage latest,
        mapping(bytes32 => T.ReplayCell) storage replay,
        Context memory o,
        T.Binding memory b,
        Sale.Consent memory p,
        address signer,
        uint256 nonce
    ) public returns (Mutation memory m) {
        if (
            p.collectionId == 0 || p.saleAdapter == address(0) || p.saleId == bytes32(0)
                || p.saleConfigHash == bytes32(0)
        ) revert T.InvalidRecord();
        m.record = StreamArtistSaleHashes.record(
            o.environment, p, b.artistId, signer, 1, nonce, o.observedAt
        );
        bytes32 scope = keccak256(abi.encode(p, b.generation, b.bindingHash));
        bytes32 key = _consume(
            replay, o, keccak256("consent_finality.replay.sale_consent_key"), scope, m.record
        );
        if (records[m.record].recordHash != bytes32(0)) revert T.InvalidRecord();
        Sale.Record memory item = Sale.Record(
            m.record, p, b.artistId, signer, 1, nonce, o.observedAt, b.generation, b.bindingHash
        );
        bytes32 lookup = StreamArtistSaleHashes.lookup(p.collectionId, p.saleId, p.saleConfigHash);
        records[m.record] = item;
        latest[lookup] = m.record;
        m.action = keccak256(abi.encode(b, p, signer, nonce));
        m.state = keccak256(abi.encode(scope, lookup, item));
        m.replay = keccak256(abi.encode(key, m.record));
        emit ArtistSaleConsentRecorded(
            1, p.collectionId, p.saleConfigHash, signer, p.saleId, 1, nonce, o.observedAt, m.record
        );
    }

    event ArtistPolicyConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed policyHash,
        address indexed signer,
        bytes32 phaseId,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 consentRecordHash
    );
    event ArtistEconomicsConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed assignmentHash,
        address indexed signer,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 payoutDesignationRecordHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 consentRecordHash
    );
    event ArtistRecordDelegation(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed delegationRecordHash,
        bytes32 indexed artistId,
        address resolver,
        bytes32 revenueClass,
        uint8 authorityClass
    );
    event ArtistContentRatificationRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed contentStateHash,
        address indexed signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 ratificationRecordHash
    );

    function policy(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => T.ReplayCell) storage replay,
        Context memory o,
        T.Binding memory b,
        T.PolicyConsent memory p,
        address signer,
        uint256 nonce
    ) public returns (Mutation memory m) {
        if (p.phaseId == bytes32(0) || p.policyHash == bytes32(0)) {
            revert T.InvalidRecord();
        }
        m.record = StreamArtistHashes.policyRecord(
            o.environment, p, b.artistId, signer, nonce, o.observedAt
        );
        bytes32 scope = keccak256(abi.encode(p.collectionId, p.phaseId, p.policyHash));
        bytes32 key = _consume(
            replay, o, keccak256("consent_finality.replay.policy_consent_key"), scope, m.record
        );
        records[scope] = m.record;
        m.action = keccak256(abi.encode(b, p, signer, nonce));
        m.state = keccak256(abi.encode(scope, m.record));
        m.replay = keccak256(abi.encode(key, m.record));
        emit ArtistPolicyConsentRecorded(
            1, p.collectionId, p.policyHash, signer, p.phaseId, 1, nonce, o.observedAt, m.record
        );
    }

    function economics(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => bytes32) storage delegations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        Context memory o,
        T.Binding memory b,
        T.EconomicsConsent memory p,
        T.Payout memory designation,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) public returns (Mutation memory m) {
        if (
            designation.account == address(0) || designation.recordHash == bytes32(0)
                || p.resolver == address(0) || p.assignmentHash == bytes32(0)
                || p.revenueClass == bytes32(0) || p.scope != 1 || p.scopeId != p.collectionId
        ) {
            revert T.InvalidRecord();
        }
        uint8 authorityClass = grant == bytes32(0) ? 1 : 2;
        m.record = StreamArtistEconomicsHashes.economicsRecordForAuthority(
            o.environment,
            p,
            designation.recordHash,
            b.artistId,
            signer,
            authorityClass,
            nonce,
            o.observedAt
        );
        bytes32 scope = keccak256(abi.encode(p));
        bytes32 key =
            _consume(replay, o, keccak256("consent_finality.replay.consent_key"), scope, m.record);
        records[scope] = m.record;
        if (grant != bytes32(0)) delegations[m.record] = grant;
        m.action = grant == bytes32(0)
            ? keccak256(abi.encode(b, p, designation, signer, nonce))
            : keccak256(abi.encode(b, p, designation, signer, nonce, grant));
        m.state = grant == bytes32(0)
            ? keccak256(abi.encode(scope, m.record))
            : keccak256(abi.encode(scope, m.record, grant));
        m.replay = keccak256(abi.encode(key, m.record));
        emit ArtistEconomicsConsentRecorded(
            1,
            p.collectionId,
            p.assignmentHash,
            signer,
            p.revenueClass,
            p.scope,
            p.scopeId,
            designation.recordHash,
            authorityClass,
            nonce,
            o.observedAt,
            m.record
        );
        if (grant != bytes32(0)) {
            emit ArtistRecordDelegation(
                1, m.record, grant, b.artistId, p.resolver, p.revenueClass, 2
            );
        }
    }

    function ratification(
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(bytes32 => T.RatificationRecord) storage records,
        mapping(bytes32 => T.ReplayCell) storage replay,
        Context memory o,
        T.Binding memory b,
        T.Ratification memory p,
        address signer,
        uint256 nonce
    ) public returns (Mutation memory m) {
        if (p.metadataContract == address(0) || p.contentStateHash == bytes32(0)) {
            revert T.InvalidRecord();
        }
        T.RatificationRecord storage prior = current[p.collectionId];
        if (
            prior.contentStateHash == p.contentStateHash
                && prior.metadataContract == p.metadataContract
        ) {
            revert T.InvalidRecord();
        }
        m.record = StreamArtistHashes.ratificationRecord(
            o.environment, p, b.artistId, signer, nonce, o.observedAt
        );
        bytes32 key = _consume(
            replay,
            o,
            keccak256("consent_finality.replay.ratification_key"),
            keccak256(abi.encode(p.collectionId, m.record)),
            m.record
        );
        T.RatificationRecord memory item =
            T.RatificationRecord(m.record, p.contentStateHash, p.metadataContract);
        current[p.collectionId] = item;
        records[m.record] = item;
        m.action = keccak256(abi.encode(b, p, signer, nonce));
        m.state = keccak256(abi.encode(p.collectionId, item));
        m.replay = keccak256(abi.encode(key, m.record));
        emit ArtistContentRatificationRecorded(
            1, p.collectionId, p.contentStateHash, signer, 1, nonce, o.observedAt, m.record
        );
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        Context memory o,
        bytes32 surface,
        bytes32 scope,
        bytes32 record
    ) private returns (bytes32 key) {
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                surface,
                scope
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(record, o.revision + 1, 1, 2);
    }
}
