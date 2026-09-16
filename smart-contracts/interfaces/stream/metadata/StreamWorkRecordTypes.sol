// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Untrusted complete witnesses for the versioned WORK_DESCRIPTION JSON interpretation.
/// @dev No struct proves authorship, current selection, catalog registration or external identity.
library StreamWorkRecordTypes {
    enum Form {
        FULL,
        DESCRIPTION_ABSENT
    }
    enum CreatorKind {
        ARTIST,
        NAMED
    }
    enum DateKind {
        EXACT,
        RANGE
    }
    enum FormatKind {
        NONDIGITAL,
        PRONOM,
        CATALOG
    }
    enum MappingKind {
        PRONOM,
        SPECIFICATION
    }
    enum MeasurementKind {
        MEASURED,
        DIMENSIONLESS_GENERATIVE
    }
    enum EditionKind {
        UNIQUE,
        SERIAL,
        OPEN_SERIES
    }
    enum VariantField {
        TITLE,
        MEDIUM,
        CREDIT,
        INSCRIPTION,
        CREATOR_NAME,
        ALTERNATE_TITLE
    }
    enum AuthorityRole {
        CREATOR,
        MEDIUM,
        TECHNIQUE
    }
    enum Authority {
        ULAN,
        VIAF,
        WIKIDATA,
        GETTY_AAT
    }

    struct Creator {
        CreatorKind kind;
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        string name;
    }

    /// @dev Exact Gregorian YYYYMMDD. EXACT requires end=0; RANGE requires end>=start.
    struct Creation {
        DateKind kind;
        uint32 start;
        uint32 end;
    }

    /// @dev Only nonzero32-byte algorithm1/RAW_BYTES references in this interpretation.
    struct Specification {
        string uri;
        bytes32 digest;
    }

    struct CatalogEntry {
        bytes32 entryId;
        MappingKind kind;
        string puid;
        Specification specification;
    }

    /// @dev Complete ordered document, not a selected-entry-only witness. IDs are unique.
    struct Catalog {
        string name;
        CatalogEntry[] entries;
        bytes32 selectedEntryId;
    }

    struct Format {
        FormatKind kind;
        bytes32 formatId;
        string puid;
        Catalog catalog;
    }

    /// @dev Exact unreduced positive rationals; both uint256 words remain observable.
    struct Rational {
        uint256 numerator;
        uint256 denominator;
    }

    /// @dev Measured fields may coexist, including video pixels/aspect and exact runtime.
    /// Inactive fields must be zero. At least one measured field must be present.
    struct Measurements {
        MeasurementKind kind;
        bool hasPixels;
        uint256 width;
        uint256 height;
        bool hasAspectRatio;
        Rational aspectRatio;
        bool hasDuration;
        Rational durationSeconds;
    }

    struct Edition {
        EditionKind kind;
        uint256 number;
        uint256 total;
        string statement;
    }

    struct LanguageVariant {
        VariantField field;
        // Only ALTERNATE_TITLE uses this index; all other variants require0.
        uint8 alternateTitleIndex;
        string language;
        string value;
    }

    struct AuthorityReference {
        AuthorityRole role;
        Authority authority;
        string identifier;
    }

    struct FullDescription {
        string title;
        Creator creator;
        Creation creation;
        string medium;
        Format format;
        Measurements measurements;
        Edition edition;
        string creditLine;
        bool hasInscription;
        string inscription;
        string[] alternateTitles;
        LanguageVariant[] languageVariants;
        AuthorityReference[] authorityReferences;
    }

    struct Absence {
        string reason;
        uint32 date;
    }

    struct Description {
        bytes32 subjectId;
        bytes32 profileHash;
        bytes32 predecessor;
        Form form;
        FullDescription full;
        Absence absence;
    }
}
