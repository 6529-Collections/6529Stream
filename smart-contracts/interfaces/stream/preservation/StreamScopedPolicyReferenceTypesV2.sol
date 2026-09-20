// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamReferenceRenderTypes as R } from "./StreamReferenceRenderTypes.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as S
} from "../metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as RootV2
} from "../metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    IStreamFinalityEntropyPolicySourceSet
} from "../finality/IStreamFinalityEntropyPolicySourceSet.sol";
import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import { IStreamStaticSelectionCheckpoint } from "../finality/IStreamStaticSelectionCheckpoint.sol";
import { StreamExternalArtifactTypes } from "./StreamExternalArtifactTypes.sol";

/// @notice Distinct reference observations for complete TOKEN, RELEASE and SEASON scopes.
/// @dev Samples demonstrate repeated observations, never complete archive inventory. Membership
/// does not authorize a VIEW. Original COLLECTION records retain their original definitions.
library StreamScopedPolicyReferenceTypesV2 {
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
    }

    struct SourceFacts {
        bytes32 scopeSubject;
        S.Receipt snapshot;
        S.Source snapshotSource;
        bytes32 contentRootRecordHash;
        Root.Record contentRoot;
        RootV2.Binding contentRootBinding;
        StreamExternalArtifactTypes.Coverage environmentCoverage;
        Sample[] samples;
    }

    struct Receipt {
        bytes32 scopeSubject;
        R.Receipt observation;
    }

    error InvalidScopedPolicyReference();
    error ScopedPolicyReferenceDependency(address target);
    error ScopedPolicyReferenceAuthority(address actor);
    error ScopedPolicyReferenceLineage(bytes32 expected, bytes32 actual);
    error ScopedPolicyReferenceLocked(bytes32 subject);
    error ScopedPolicyReferenceUnknown(bytes32 recordHash);
}
