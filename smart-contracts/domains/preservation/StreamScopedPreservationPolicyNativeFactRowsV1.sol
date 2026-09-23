// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";

import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as RootBinding
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";

/// @notice Exact original full native-source and root tuple bytes, without source admission.
library StreamScopedPreservationPolicyNativeFactRowsV1 {
    function source(address target, bytes32 original, Snapshot.Source memory nativeSource)
        public
        pure
        returns (T.Item memory row)
    {
        row = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("SCOPED_POLICY_NATIVE_SOURCE_FACTS_V2"),
            target,
            original,
            0,
            abi.encode(nativeSource)
        );
    }

    function root(
        address target,
        bytes32 rootRecordHash,
        Root.Record memory originalRoot,
        RootBinding.Binding memory binding
    ) public pure returns (T.Item memory row) {
        row = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1"),
            target,
            rootRecordHash,
            0,
            abi.encode(originalRoot, binding)
        );
    }
}
