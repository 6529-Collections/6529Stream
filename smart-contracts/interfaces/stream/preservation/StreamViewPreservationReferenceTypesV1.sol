// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamReferenceRenderTypes as R } from "./StreamReferenceRenderTypes.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamViewPreservationContentRootV1 as Binding
} from "../metadata/IStreamViewPreservationContentRootV1.sol";
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import { StreamExternalArtifactTypes as E } from "./StreamExternalArtifactTypes.sol";

/// @notice BYTE_EXACT observations of explicitly admitted, non-sanction adopted VIEW output.
/// @dev Full checkpoint/manifest coverage is independent of the bounded first/last captures.
library StreamViewPreservationReferenceTypesV1 {
    struct Dependencies {
        // Core, selected Metadata, Schema, Store, selected Router, new VIEW snapshots, external coverage.
        address[7] targets;
        bytes32[7] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 sourceGas;
        uint256 snapshotGas;
        uint256 archiveGas;
    }

    struct Publication {
        StreamFinalityScope scope;
        R.Publication observation;
    }

    struct Sample {
        uint64 membershipIndex;
        C.Output output;
        E.Coverage captureCoverage;
    }

    struct SourceFacts {
        bytes32 scopeSubject;
        S.Receipt snapshot;
        S.Source snapshotSource;
        bytes32 contentRootRecordHash;
        Root.Record contentRoot;
        Binding.Binding contentBinding;
        E.Coverage environmentCoverage;
        Sample[] samples;
    }

    struct Receipt {
        bytes32 scopeSubject;
        R.Receipt observation;
    }
    error InvalidViewPreservationReference();
    error ViewPreservationReferenceDependency(address target);
    error ViewPreservationReferenceAuthority(address actor);
    error ViewPreservationReferenceLineage(bytes32 expected, bytes32 actual);
    error ViewPreservationReferenceLocked(bytes32 subject);
    error ViewPreservationReferenceUnknown(bytes32 recordHash);
}
