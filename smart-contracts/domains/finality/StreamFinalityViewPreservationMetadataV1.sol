// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import "../metadata/StreamMetadataSubjects.sol";

import {
    IStreamViewPreservationContentRootV1 as Binding
} from "../../interfaces/stream/metadata/IStreamViewPreservationContentRootV1.sol";
import {
    StreamViewPreservationContentDefinitionsV1 as Definitions
} from "../records/StreamViewPreservationContentDefinitionsV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as SnapshotDefinitions
} from "../records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as OutputDefinitions
} from "../finality/StreamViewPreservationOutputSchemasV1.sol";
import { StreamViewPolicyTypesV2 as Policy } from "../metadata/StreamViewPolicyTypesV2.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";

import {
    StreamViewPreservationReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamExternalArtifactCoverage as Archive
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    IStreamExternalArtifactCurrentPair
} from "../../interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    StreamFinalityViewPreservationSnapshotReadsV1 as SnapRead
} from "../finality/StreamFinalityViewPreservationSnapshotReadsV1.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    StreamViewPreservationReferenceSampleReadsV1 as Samples
} from "../preservation/StreamViewPreservationReferenceSampleReadsV1.sol";
import {
    StreamReferenceRenderSourceReads as Archives
} from "../preservation/StreamReferenceRenderSourceReads.sol";
import {
    StreamReferenceRenderDefinitions as D
} from "../records/StreamReferenceRenderDefinitions.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";

import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationConfigurationV1 as Configuration
} from "./StreamFinalityViewPreservationConfigurationV1.sol";
import {
    StreamFinalityViewPreservationSnapshotReadsV1 as Snapshots
} from "./StreamFinalityViewPreservationSnapshotReadsV1.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1 as SnapshotHost
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    StreamViewPreservationRenderCriticalSourceReadsV1 as InventorySources
} from "../preservation/StreamViewPreservationRenderCriticalSourceReadsV1.sol";

import {
    StreamFinalityViewPreservationMetadataCurrentV1 as Current
} from "./StreamFinalityViewPreservationMetadataCurrentV1.sol";

/// @notice Exact VIEW metadata projections; no reference, inventory or component-current callback.
library StreamFinalityViewPreservationMetadataV1 {
    struct Evidence {
        Snapshots.Evidence snapshot;
        T.SourceFacts root;
    }

    function current(Native.Config memory c, StreamFinalityScope memory scope, bool locked)
        public
        view
        returns (Evidence memory e)
    {
        return Current.current(c, scope, locked);
    }

    function root(Native.Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32, uint64, bytes32)
    {
        Evidence memory e = current(c, scope, false);
        bytes memory raw = Reads.read(
            c.targets[2], abi.encodeCall(Root.scopedTokenContentRoot, (scope)), 96, c.readGas
        );
        (bytes32 value, uint64 count, bytes32 schema) = abi.decode(raw, (bytes32, uint64, bytes32));
        _canonical(c.targets[2], raw, abi.encode(value, count, schema));
        if (
            value != e.root.contentRoot.contentRoot || count != e.root.contentRoot.leafCount
                || schema != OutputDefinitions.LEAF
        ) {
            revert T.InvalidViewPreservationReference();
        }
        return (value, count, schema);
    }

    function snapshot(Native.Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32)
    {
        return current(c, scope, false).snapshot.receipt.manifestHash;
    }

    function manifest(Native.Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bool, bytes32)
    {
        Configuration.requireScope(c, scope);
        Configuration.resolve(c);
        bytes memory raw = Reads.read(
            c.targets[3],
            abi.encodeWithSignature(
                "requireScopeMembership((uint8,uint256,uint256,bytes32))", scope
            ),
            256,
            c.componentSourceGas
        );
        StreamScopeMembershipFacts memory f = abi.decode(raw, (StreamScopeMembershipFacts));
        _canonical(c.targets[3], raw, abi.encode(f));
        if (
            f.scopeSubject != StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], scope)
                || f.tokenCount == 0 || f.membershipHash == 0 || f.sourceRecordHash == 0
                || f.scopeManifestHash == 0
        ) {
            revert T.InvalidViewPreservationReference();
        }
        return (true, f.scopeManifestHash);
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) {
            revert T.ViewPreservationReferenceDependency(target);
        }
    }
}
