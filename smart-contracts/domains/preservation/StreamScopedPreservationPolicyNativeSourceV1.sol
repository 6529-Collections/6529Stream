// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as R
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "./StreamScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";

import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as RootBinding
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";

/// @notice Fixed transport of the native reader's already-authenticated consumed source fields.
/// @dev The complete original SourceFacts is validated before this projection; no supplied fact is admitted.
library StreamScopedPreservationPolicyNativeSourceV1 {
    struct Facts {
        Snapshot.Source snapshotSource;
        Root.Record contentRoot;
        RootBinding.Binding contentRootBinding;
    }

    function read(S.Dependencies memory d, Scoped.Context memory c, bytes32 family)
        public
        view
        returns (Facts memory consumed)
    {
        R.SourceFacts memory original = Sources.sourceFacts(d, c, family);
        consumed.snapshotSource = original.snapshotSource;
        consumed.contentRoot = original.contentRoot;
        consumed.contentRootBinding = original.contentRootBinding;
    }
}
