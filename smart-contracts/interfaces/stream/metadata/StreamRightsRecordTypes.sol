// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Untrusted field witnesses for the explicitly versioned STREAM_RIGHTS_V1 JSON profile.
/// @dev These types neither authorize publication nor choose a current finality record.
library StreamRightsRecordTypes {
    enum Basis {
        UNSPECIFIED,
        COPYRIGHT,
        LICENSE,
        STATUTE,
        PUBLIC_DOMAIN,
        CONTRACT
    }
    enum Status {
        UNSPECIFIED,
        GRANTED,
        GRANTED_WITH_CONDITIONS,
        DENIED
    }
    enum LicensorKind {
        ARTIST,
        ESTATE,
        INSTITUTION,
        ACCOUNT
    }
    enum ConditionKind {
        NONE,
        TEXT,
        DOCUMENT
    }

    /// @dev Only algorithm1/32-byte keccak256 of RAW_BYTES is admitted in this profile.
    struct Document {
        bool exists;
        string uri;
        bytes32 digest;
    }

    struct Licensor {
        LicensorKind kind;
        bytes32 artistId;
        string name;
        address account;
        bytes32 instrumentDigest;
    }

    struct Conditions {
        ConditionKind kind;
        string text;
        Document document;
    }

    struct Grant {
        Status status;
        Conditions conditions;
        string extension;
    }

    /// @dev Named fields prevent missing, duplicated or reordered use-class witnesses.
    struct Grants {
        Grant aiTraining;
        Grant derivative;
        Grant exhibition;
        Grant print;
        Grant publication;
        Grant reproduction;
    }

    struct Statement {
        bytes32 subjectId;
        bytes32 profileHash;
        Basis basis;
        Licensor licensor;
        Grants grants;
        // Exact Gregorian dates encoded YYYYMMDD; open end requires endDate=0.
        uint32 startDate;
        uint32 endDate;
        bool openEnd;
        Document instrument;
        bool hasAiTrainingPermission;
        Status aiTrainingPermission;
        // Zero is an explicit first statement; nonzero lineage needs an authenticated consumer.
        bytes32 predecessor;
    }
}
