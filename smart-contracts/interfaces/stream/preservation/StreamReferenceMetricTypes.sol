// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamReferenceRenderTypes as R } from "./StreamReferenceRenderTypes.sol";

/// @notice Additive executable-closure evidence; the original Metric and report remain unchanged.
/// @dev A recorded replay is an attributed execution observation, never an EVM execution of Python.
library StreamReferenceMetricTypes {
    struct SourceFile {
        string path;
        bytes content;
    }

    struct Runtime {
        bytes32 environmentObjectHash;
        bytes32 environmentManifestHash;
        string entrypoint;
        string interpreter;
        string launcher;
        string sourceRoot;
        string[] argv;
        R.PackageFile[] members;
    }

    struct Replay {
        bytes32 runtimeHash;
        bytes32 contextHash;
        bytes32 reportHash;
        bytes32 inputsHash;
        bytes inputManifest;
        bytes transcript;
        uint64 executedAt;
        uint32 exitCode;
    }

    struct Supplement {
        bytes implementationIndex;
        bytes parameters;
        SourceFile[4] sources;
        Runtime runtime;
        Replay replay;
    }

    struct Receipt {
        bytes32 supplementHash;
        bytes32 referenceRecordHash;
        bytes32 payloadHash;
        uint32 payloadBytes;
        bytes32 runtimeHash;
        bytes32 replayHash;
        bytes32 schemaHash;
        bytes32 profileHash;
        bytes32 canonicalizationHash;
        address recorder;
        uint8 authorizationClass;
        uint64 grantRevision;
        uint64 recordedAt;
    }
    error InvalidMetricSupplement();
    error MetricSupplementAlreadyPublished(bytes32 referenceRecordHash);
}
