// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamReferenceRenderTypes as R } from "./StreamReferenceRenderTypes.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamContentRootPublication as Root
} from "../metadata/IStreamContentRootPublication.sol";
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import { IStreamStaticSelectionCheckpoint } from "../finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamFinalityEntropyPolicySourceSet
} from "../finality/IStreamFinalityEntropyPolicySourceSet.sol";
import { StreamExternalArtifactTypes } from "./StreamExternalArtifactTypes.sol";

import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    IStreamPreservationPolicyContentRootPublicationV1 as PreservationRoot
} from "../metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";

/// @notice Distinct reference observations for complete COLLECTION preservation V1 policy/output scopes.
/// @dev Samples demonstrate repeated observations, never complete archive inventory. Membership
/// does not authorize a VIEW. All original V1 records retain their original definitions.
library StreamPreservationPolicyReferenceTypesV1 {
    struct Dependencies {
        // Core, selected Metadata, schemas, Store, selected Router, scoped snapshots, external coverage.
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
        R.SampleFacts observation;
        IStreamStaticSelectionCheckpoint.TokenSelection selection;
        IStreamFinalityEntropyPolicySourceSet.TokenReadiness entropy;
        bytes32 terminalAdmissionHash;
        P.Binding preservation;
        P.Admission preservationAdmission;
    }

    struct SourceFacts {
        bytes32 scopeSubject;
        S.Receipt snapshot;
        S.Source snapshotSource;
        bytes32 contentRootRecordHash;
        Root.Record contentRoot;
        PreservationRoot.Binding contentRootBinding;
        StreamExternalArtifactTypes.Coverage environmentCoverage;
        Sample[] samples;
    }

    struct Receipt {
        bytes32 scopeSubject;
        R.Receipt observation;
    }

    error InvalidPolicyReference();
    error PolicyReferenceDependency(address target);
    error PolicyReferenceAuthority(address actor);
    error PolicyReferenceLineage(bytes32 expected, bytes32 actual);
    error PolicyReferenceLocked(bytes32 subject);
    error PolicyReferenceUnknown(bytes32 recordHash);
}
