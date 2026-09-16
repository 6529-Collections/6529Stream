// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../metadata/StreamConservationRecordTypes.sol";
import "./StreamReferenceRenderTypes.sol";

/// @notice Versioned non-byte-exact evidence; identities/measurements remain attributed facts.
library StreamReferenceModeTypes {
    enum Mode {
        INVALID,
        PERCEPTUAL_TOLERANCE,
        CURATED_EQUIVALENCE
    }

    struct Dependencies {
        address attestations;
        bytes32 attestationsCodeHash;
        address conservation;
        bytes32 conservationCodeHash;
    }

    struct Repeat {
        bytes32 objectHash;
        bytes32 coverageHash;
    }

    /// @dev Closed registered metric definition. scale=1e9; higher scores are better.
    struct Metric {
        bytes32 metricId;
        bytes32 algorithm;
        string tool;
        string version;
        bytes32 implementationHash;
        bytes32 parametersHash;
        uint64 scale;
    }

    struct Perceptual {
        Metric metric;
        int64 threshold;
        int64[] scores;
        bytes32 reportHash;
        string reportURI;
        uint64 evaluatedAt;
    }

    struct Property {
        bytes32 id;
        string name;
        string significantValue;
    }

    struct Assessment {
        bytes32 propertyId;
        bool conforms;
        string observation;
    }

    /// @dev Signed by the original INDEPENDENT_CONDITION attestor, not by a caller-supplied name.
    struct Condition {
        bytes32 contextHash;
        bytes32 intentRecordHash;
        bytes32 intentSelectionHash;
        bytes32 propertiesHash;
        address examiner;
        string examinerName;
        StreamConservationRecordTypes.Reference institution;
        StreamConservationRecordTypes.Reference credentials;
        uint64 examinedAt;
        // Capture-major, then exact property-document order. Every row must be present.
        Assessment[] assessments;
    }

    struct Curated {
        bytes32 conditionRecordHash;
        bytes32 intentRecordHash;
        uint64 intentRevision;
        StreamConservationRecordTypes.Intent intent;
        Property[] properties;
        Condition condition;
    }

    struct Evidence {
        Mode mode;
        Repeat[] repeats;
        Perceptual perceptual;
        Curated curated;
    }

    struct Facts {
        Mode mode;
        bytes32 evidenceHash;
        bytes32 interpretationHash;
        bytes32 conditionRecordHash;
        bytes32 conditionReceiptHash;
        bytes32 intentSelectionHash;
        E.Coverage[] repeats;
    }
    error InvalidModeEvidence();
    error ModeRead(address target);
    error ModeParentGas(uint256 available, uint256 required);
}
