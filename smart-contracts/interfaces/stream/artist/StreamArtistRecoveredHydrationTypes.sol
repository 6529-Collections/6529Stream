// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamArtistAuthorityCheckpoint as CP } from "./IStreamArtistAuthorityCheckpoint.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistHistoryTypes as H } from "./IStreamArtistHistory.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "./IStreamArtistMultipleRecordsHydration.sol";
import { StreamArtistAuthorityHydrationTypes as AH } from "./IStreamArtistAuthorityHydration.sol";

/// @notice Additive recovered-authority transport. Original records and clocks are never rewritten.
library StreamArtistRecoveredHydrationTypes {
    uint16 internal constant VERSION = 1;
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1");
    bytes32 internal constant CHECKPOINT = keccak256("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1");
    uint256 internal constant CLASS_ONE = 1;
    uint256 internal constant CLASS_THREE = 2;
    uint256 internal constant ADJUDICATION_V2 = 4;
    uint256 internal constant REWINDS_V3 = 8;
    uint256 internal constant REPEATED_IMPORT = 16;
    uint256 internal constant DIRECT_ECONOMICS = 32;
    uint256 internal constant DELEGATED_CONSENT = 64;
    uint256 internal constant ATTESTATIONS = 128;
    uint256 internal constant CONTENT_CONSENTS = 256;
    uint256 internal constant BINDING_GENERATIONS = 512;
    uint256 internal constant RATIFICATIONS = 1024;
    uint256 internal constant BINDING_CORRECTIONS = 2048;
    uint256 internal constant ACCEPTED_GENERATIONS = 4096;
    uint256 internal constant DISPUTE_HISTORY = 8192;
    uint256 internal constant SANCTION_HISTORY = 16384;
    uint256 internal constant HISTORY_CONTENT = 32768;
    uint256 internal constant HISTORY_PLATFORM = 65536;
    uint256 internal constant KNOWN_FEATURES = 131071;
    // Reviewed recovered graph only; typed exporters still reject broader collection profiles.
    // Keep this explicit so adding a future known feature does not advertise it automatically.
    uint256 internal constant FIRST_GRAPH_FEATURES =
        CLASS_ONE | CLASS_THREE | ADJUDICATION_V2 | REWINDS_V3 | REPEATED_IMPORT;
    uint256 internal constant ECONOMICS_GRAPH_FEATURES = FIRST_GRAPH_FEATURES | DIRECT_ECONOMICS;
    uint256 internal constant DELEGATION_GRAPH_FEATURES =
        ECONOMICS_GRAPH_FEATURES | DELEGATED_CONSENT;
    uint256 internal constant ATTESTATION_GRAPH_FEATURES = DELEGATION_GRAPH_FEATURES | ATTESTATIONS;
    uint256 internal constant CONTENT_GRAPH_FEATURES = ATTESTATION_GRAPH_FEATURES
        | CONTENT_CONSENTS;
    uint256 internal constant BINDING_GRAPH_FEATURES = CONTENT_GRAPH_FEATURES | BINDING_GENERATIONS;
    uint256 internal constant RATIFICATION_GRAPH_FEATURES = BINDING_GRAPH_FEATURES | RATIFICATIONS;
    uint256 internal constant CORRECTION_GRAPH_FEATURES =
        RATIFICATION_GRAPH_FEATURES | BINDING_CORRECTIONS;
    uint256 internal constant ACCEPTED_GRAPH_FEATURES = CORRECTION_GRAPH_FEATURES | ACCEPTED_GENERATIONS;
    uint256 internal constant DISPUTE_GRAPH_FEATURES = ACCEPTED_GRAPH_FEATURES | DISPUTE_HISTORY;
    uint256 internal constant SANCTION_GRAPH_FEATURES = DISPUTE_GRAPH_FEATURES | SANCTION_HISTORY;
    uint256 internal constant HISTORY_CONTENT_GRAPH_FEATURES = SANCTION_GRAPH_FEATURES | HISTORY_CONTENT;
    uint256 internal constant PLATFORM_GRAPH_FEATURES = HISTORY_CONTENT_GRAPH_FEATURES | HISTORY_PLATFORM;
    // Finite transport-profile limits, not limits on validity of original lifetime history.
    uint256 internal constant MAX_ERAS = 16;
    uint256 internal constant MAX_JOURNAL_ENTRIES = 4096;
    uint256 internal constant MAX_REPLAY_ALIASES = 8192;
    uint256 internal constant MAX_NONCE_INDICES = 128;
    uint256 internal constant MAX_NONCE_PREFIXES = 256;

    struct Capability {
        bytes32 profile;
        uint16 version;
        uint8 ownerIndex;
        bytes32 ownerDomain;
        bytes32 checkpointSchema;
        bytes32 stateSchema;
        uint256 supportedFeatures;
    }

    struct Request {
        MR.Request records;
        Capability[7] expectedCapabilities;
        bytes32 expectedSourceImportCommitment;
        bytes32 expectedSemanticInventory;
    }

    struct ExportHeader {
        bytes32 profile;
        uint16 version;
        uint8 ownerIndex;
        bytes32 sourceOrigin;
        bytes32 priorImportCommitment;
        bytes32 semanticInventory;
        bytes32 provenanceCommitment;
        bytes32 replayAliasesCommitment;
        uint256 requiredFeatures;
        uint256 semanticRecordCount;
        uint256 replayAliasCount;
        uint256 eraCount;
    }

    struct OriginEnvironment {
        uint256 chainId;
        address registry;
        address coordinator;
        address archive;
        address[7] owners;
        bytes32[7] ownerCodeHashes;
        address core;
        address manager;
        bytes32 suiteConfigurationHash;
    }

    /// @dev Eras are flattened in import order. Each origin appears exactly once. The last
    /// era is the actual current source, not an arbitrary ancestor supplied by a caller.
    /// lowerRevisions is zero for the first era and the original local import revision
    /// for each later owner. It is an exclusive lower bound for that era's native rows.
    struct Era {
        bytes32 originHash;
        CP.Checkpoint[7] checkpoints;
        uint256[7] nativeCounts;
        uint64[7] lowerRevisions;
        bytes32 priorImportCommitment;
    }

    /// @notice An original local-clock coordinate, including records without a native receipt.
    /// @dev Revisions from different owners or environments are not directly comparable.
    struct Point {
        bytes32 environmentHash;
        uint8 ownerIndex;
        uint64 ownerRevision;
    }

    /// @notice Exact original occurrence. Repeated secondary35 hashes retain distinct positions.
    struct Position {
        Point point;
        uint256 nativeIndex;
    }

    struct JournalEntry {
        Position position;
        H.Receipt receipt;
    }

    /// @dev Historical aliases retain their actual original key and original local clock.
    /// Rekeyed live cells are separately authenticated by the immediate source checkpoint.
    struct ReplayAlias {
        bytes32 originHash;
        uint8 ownerIndex;
        bytes32 surface;
        bytes32 scope;
        bytes32 originalKey;
        T.ReplayCell cell;
        Point admittedAt;
    }

    struct Provenance {
        OriginEnvironment[] origins;
        Era[] eras;
        JournalEntry[][7] journals;
        ReplayAlias[][7] aliases;
    }

    /// @dev A fixed owner exports only its own mutable facts. The Coordinator joins all seven
    /// slices against an identical immutable origin table to construct complete Provenance.
    struct OwnerEra {
        bytes32 originHash;
        CP.Checkpoint checkpoint;
        uint256 nativeCount;
        uint64 lowerRevision;
        bytes32 priorImportCommitment;
    }

    struct OwnerProvenance {
        OriginEnvironment[] origins;
        OwnerEra[] eras;
        JournalEntry[] journal;
        ReplayAlias[] aliases;
    }

    struct NonceInventory {
        CP.NonceIndex index;
        AH.NonceWord[] words;
    }

    /// @dev The outer codec validates this envelope; each owner must decode and canonically
    /// re-encode payload using its one fixed typed bundle. Bytes never designate storage or calls.
    struct Envelope {
        ExportHeader header;
        bytes payload;
    }

    error InvalidRecoveredHydrationProfile();
    error InvalidRecoveredHydrationProvenance();
    error InvalidRecoveredHydrationPoint(
        bytes32 environmentHash, uint8 ownerIndex, uint64 revision
    );

    function ownerDomain(uint8 index) internal pure returns (bytes32) {
        if (index == 0) return keccak256("domain:binding_lifecycle");
        if (index == 1) return keccak256("domain:collaborator_lifecycle");
        if (index == 2) return keccak256("domain:identity_authority");
        if (index == 3) return keccak256("domain:acceptance_lifecycle");
        if (index == 4) return keccak256("domain:attribution_lifecycle");
        if (index == 5) return keccak256("domain:payout_lifecycle");
        if (index == 6) return keccak256("domain:consent_finality");
        revert InvalidRecoveredHydrationProfile();
    }

    function ownerTag(uint8 index) internal pure returns (bytes32) {
        if (index == 0) return keccak256("6529STREAM_ARTIST_RECOVERED_BINDING_STATE_V1");
        if (index == 1) return keccak256("6529STREAM_ARTIST_RECOVERED_COLLABORATOR_STATE_V1");
        if (index == 2) return keccak256("6529STREAM_ARTIST_RECOVERED_IDENTITY_STATE_V1");
        if (index == 3) return keccak256("6529STREAM_ARTIST_RECOVERED_ACCEPTANCE_STATE_V1");
        if (index == 4) return keccak256("6529STREAM_ARTIST_RECOVERED_ATTRIBUTION_STATE_V1");
        if (index == 5) return keccak256("6529STREAM_ARTIST_RECOVERED_PAYOUT_STATE_V1");
        if (index == 6) return keccak256("6529STREAM_ARTIST_RECOVERED_CONSENT_STATE_V1");
        revert InvalidRecoveredHydrationProfile();
    }

    function originHash(OriginEnvironment memory origin) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_ORIGIN_V1"), VERSION, origin
            )
        );
    }

    function provenanceHash(Provenance memory provenance) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_PROVENANCE_V1"),
                VERSION,
                provenance
            )
        );
    }

    function ownerProvenance(Provenance memory p, uint8 index)
        internal
        pure
        returns (OwnerProvenance memory result)
    {
        if (index >= 7) revert InvalidRecoveredHydrationProfile();
        result.origins = p.origins;
        result.eras = new OwnerEra[](p.eras.length);
        for (uint256 i; i < p.eras.length; ++i) {
            result.eras[i] = OwnerEra(
                p.eras[i].originHash,
                p.eras[i].checkpoints[index],
                p.eras[i].nativeCounts[index],
                p.eras[i].lowerRevisions[index],
                p.eras[i].priorImportCommitment
            );
        }
        result.journal = p.journals[index];
        result.aliases = p.aliases[index];
    }

    function ownerProvenanceHash(Provenance memory p, uint8 index) internal pure returns (bytes32) {
        return ownerProvenanceHash(ownerProvenance(p, index), index);
    }

    function ownerProvenanceHash(OwnerProvenance memory p, uint8 index)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_V1"),
                VERSION,
                ownerDomain(index),
                p
            )
        );
    }

    function aliasesHash(uint8 index, ReplayAlias[] memory aliases)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_ALIASES_V1"),
                VERSION,
                ownerDomain(index),
                aliases
            )
        );
    }
}
