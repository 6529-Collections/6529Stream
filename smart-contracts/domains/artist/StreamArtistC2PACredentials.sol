// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistPersonhoodSummary } from "./StreamArtistPersonhoodSummary.sol";
import {
    StreamArtistC2PATypes as C2PA,
    IStreamArtistC2PAReads
} from "../../interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Schema-specific derived heads, written only inside the original op24 owner commit.
/// @dev No independent authorization, nonce, record domain, owner callback or external writer.
library StreamArtistC2PACredentials {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_C2PA_CREDENTIAL_HEADS_V1");

    struct Store {
        mapping(bytes32 => bytes32) latest;
        mapping(bytes32 => C2PA.Head) records;
        mapping(bytes32 => bytes32) personhood;
    }

    event ArtistC2PACredentialsRecorded(
        uint16 schemaVersion, bytes32 indexed artistId, bytes32 indexed recordHash, C2PA.Head head
    );

    function state() internal pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function isPersonhood(bytes32 schema) internal pure returns (bool) {
        return schema == keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
            || schema == keccak256("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1");
    }

    function decode(bytes memory statement, bytes32 artistId, bytes32 identity)
        public
        pure
        returns (C2PA.Payload memory p)
    {
        p = abi.decode(statement, (C2PA.Payload));
        if (
            keccak256(statement) != keccak256(abi.encode(p)) || p.schemaVersion != 1
                || p.artistId != artistId || p.artistId == 0 || p.identityRecordHash != identity
                || identity == 0 || p.credentials.length > 48
        ) revert T.InvalidRecord();
        bytes32 previous;
        for (uint256 i; i < p.credentials.length; ++i) {
            C2PA.Credential memory c = p.credentials[i];
            bytes32 key = keccak256(abi.encode(c));
            if (
                c.kind == 0 || c.fingerprint == 0 || c.keyId == 0
                    || (c.validUntil != 0 && c.validUntil <= c.validFrom)
                    || (i != 0 && key <= previous)
            ) revert T.InvalidRecord();
            previous = key;
        }
    }

    /// @dev Also used when complete original receipts are replayed by fixed op60 import.
    function note(
        address origin,
        bytes32 artistId,
        bytes32 bindingHash,
        T.Attestation memory terms,
        T.AttestationRecord memory record,
        bytes memory statement,
        bool emitEvent
    ) public {
        if (terms.subjectKind != 10) return;
        Store storage s = state();
        if (isPersonhood(terms.schemaId)) {
            StreamArtistPersonhoodSummary.note(origin, artistId, bindingHash, terms, record, statement, emitEvent);
            s.personhood[keccak256(abi.encode(terms.collectionId, artistId))] = record.recordHash;
            return;
        }
        if (terms.schemaId != SCHEMA) return;
        C2PA.Payload memory p = decode(statement, artistId, terms.subjectStateHash);
        bytes32 previous = s.latest[artistId];
        if (
            origin == address(0) || bindingHash == 0 || terms.subjectId != artistId
                || p.previousRecordHash != previous || s.records[record.recordHash].recordHash != 0
                || record.recordHash == 0 || record.statementHash != keccak256(statement)
                || record.schemaId != SCHEMA || record.subjectStateHash != p.identityRecordHash
                || record.generation == 0
        ) revert T.InvalidRecord();
        C2PA.Head memory h = C2PA.Head(
            s.records[previous].revision + 1,
            record.recordHash,
            previous,
            artistId,
            terms.collectionId,
            bindingHash,
            record.generation,
            p.identityRecordHash,
            record.statementHash,
            origin
        );
        s.records[record.recordHash] = h;
        s.latest[artistId] = record.recordHash;
        if (emitEvent) emit ArtistC2PACredentialsRecorded(1, artistId, record.recordHash, h);
    }

    function head(bytes32 artistId) internal view returns (C2PA.Head memory) {
        Store storage s = state();
        return s.records[s.latest[artistId]];
    }

    function personhoodKey(uint256 collectionId, bytes32 artistId) internal view returns (bytes32) {
        return state().personhood[keccak256(abi.encode(collectionId, artistId))];
    }
}
