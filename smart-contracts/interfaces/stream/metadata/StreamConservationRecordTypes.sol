// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Complete untrusted witnesses for the versioned conservation JSON interpretations.
/// @dev Claimed association/origin never proves authorship, current selection or archive coverage.
library StreamConservationRecordTypes {
    enum StatementOrigin {
        ARTIST_INTENT,
        ESTATE_STATEMENT
    }
    enum InterviewStatus {
        PRESENT,
        WAIVED
    }
    enum InstrumentKind {
        VARIABLE_MEDIA_QUESTIONNAIRE,
        NAMED_DERIVATIVE
    }
    enum ParticipantRole {
        ARTIST,
        INTERVIEWER,
        OTHER
    }
    enum CaptureKind {
        AUDIO,
        VIDEO
    }
    enum FormatKind {
        PRONOM,
        CATALOG
    }
    enum MappingKind {
        PRONOM,
        SPECIFICATION
    }

    /// @dev Algorithms1/2/3/6 require32 bytes;4/5 preserve opaque1..128 bytes.
    struct Reference {
        uint16 algorithm;
        bytes32 canonicalizationId;
        bytes digest;
        string uri;
    }

    /// @dev Actual original carrier evidence must corroborate every claimed field.
    /// An estate statement cannot become retroactive artist intent through this enum.
    struct ArtistClaim {
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        StatementOrigin origin;
    }

    /// @dev A concrete original record, distinct from its archived payload reference.
    /// The consumer resolves host/chain/Core/schema/record and full original payload externally.
    struct InterviewRecord {
        uint256 chainId;
        address core;
        address host;
        bytes32 recordHash;
        bytes32 schemaId;
        bytes32 profileHash;
        Reference payload;
    }

    /// @dev PRESENT requires an empty waiver. WAIVED requires every record field zero/empty.
    struct InterviewEntry {
        InterviewStatus status;
        InterviewRecord record;
        Reference waiverStatement;
    }

    struct Display {
        Reference scale;
        Reference timing;
        Reference color;
        Reference interaction;
        Reference motion;
        Reference frameRate;
    }

    struct Intent {
        bytes32 subjectId;
        bytes32 profileHash;
        bytes32 predecessor;
        ArtistClaim artist;
        Display display;
        Reference variabilityTolerances;
        // The referenced statement covers migration/emulation/reinterpretation preferences.
        Reference dependencyAging;
        Reference significantProperties;
        InterviewEntry interview;
    }

    struct IntentWaiver {
        bytes32 subjectId;
        bytes32 profileHash;
        bytes32 predecessor;
        ArtistClaim artist;
        Reference waiverStatement;
        // An intent waiver never manufactures an interview waiver or absent interview entry.
        InterviewEntry interview;
    }

    struct Instrument {
        InstrumentKind kind;
        string name;
        Reference document;
    }

    struct Participant {
        ParticipantRole role;
        // Required for OTHER; empty for the two named roles.
        string otherRole;
        Reference identity;
    }

    struct CatalogEntry {
        bytes32 entryId;
        MappingKind kind;
        string puid;
        Reference specification;
    }

    /// @dev Complete ordered document, including all unselected entries. No item-count cap.
    struct Catalog {
        string name;
        CatalogEntry[] entries;
        bytes32 selectedEntryId;
    }

    /// @dev PRONOM requires an empty catalog; CATALOG requires empty puid.
    struct Format {
        FormatKind kind;
        bytes32 formatId;
        string puid;
        Catalog catalog;
    }

    struct Payload {
        Reference content;
        Format format;
    }

    struct Capture {
        CaptureKind kind;
        Payload payload;
    }

    struct Interview {
        bytes32 subjectId;
        bytes32 profileHash;
        bytes32 predecessor;
        Instrument instrument;
        Participant[] participants;
        // Exact Gregorian YYYYMMDD, using the shared date interpretation.
        uint32 interviewDate;
        // Exact case/order; contract grammar and dated offline registry validity are distinct.
        string[] languages;
        Payload transcript;
        // Explicitly empty or all declared audio/video captures, in their original order.
        Capture[] captures;
    }
}
