// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyOutputSchemasV2 as OutputV2
} from "../finality/StreamPreservationPolicyOutputSchemasV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputSchemas
} from "../finality/StreamPreservationPolicyOutputSchemasV1.sol";

import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Output
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamFinalityCoordinatorPolicyV2,
    StreamFinalityCoordinatorPolicyEvidenceV2
} from "../../interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";

/// @notice Exact typed plan/output/policy item bytes, with original family domains.
library StreamScopedPreservationPolicyNativePlanRowsV1 {
    function selection(address target, bytes32 recordHash, Selection.Plan memory value)
        public
        pure
        returns (T.Item memory row)
    {
        row = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("STATIC_SELECTION_PLAN"),
            target,
            recordHash,
            0,
            abi.encode(value)
        );
    }

    function content(address target, bytes32 recordHash, Content.Plan memory value)
        public
        pure
        returns (T.Item memory row)
    {
        row = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("SCOPED_POLICY_CONTENT_PLAN_V2"),
            target,
            recordHash,
            0,
            abi.encode(value)
        );
    }

    function outputs(address target, bytes32 recordHash, Output.Manifest memory value)
        public
        pure
        returns (T.Item memory row)
    {
        row = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("SCOPED_POLICY_OUTPUT_MANIFEST_V2"),
            target,
            recordHash,
            0,
            abi.encode(value)
        );
    }

    function outputRows(
        address target,
        bytes32 recordHash,
        Output.Manifest memory value,
        bytes32 family
    ) public pure returns (T.Item memory row) {
        row.kind = T.Kind.ONCHAIN_OBJECT;
        row.role = keccak256("COMPLETE_SCOPED_POLICY_OUTPUT_HASH_ROWS_V2");
        row.source = target;
        row.sourceRecord = recordHash;
        row.algorithm = 1;
        row.canonicalizationId =
        (family == Family.FAMILY_PROFILE ? OutputV2.CANON : OutputSchemas.CANON);
        row.digest = abi.encodePacked(value.manifestHash);
        row.byteSize = value.byteLength;
        row.schemaId = (family == Family.FAMILY_PROFILE ? OutputV2.SCHEMA : OutputSchemas.SCHEMA);
        row.objectHash = value.artifactHash;
        row.originalCoverageHash = value.coverageHash;
    }

    function entropy(
        address target,
        bytes32 recordHash,
        StreamFinalityCoordinatorPolicyEvidenceV2 memory value
    ) public pure returns (T.Item memory row) {
        row = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_COMPLETE_COORDINATOR_POLICIES_V2"),
            target,
            recordHash,
            0,
            abi.encode(value)
        );
    }
}
