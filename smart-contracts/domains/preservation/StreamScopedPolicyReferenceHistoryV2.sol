// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPolicyReferenceTypesV2 as T
} from "../../interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";

import {
    IStreamArtworkScopedFinalityComponent,
    StreamFinalityComponentState,
    StreamFinalityScope,
    StreamFinalityDomains
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";

import {
    StreamScopedPolicyReferenceRecordsV2 as Records
} from "./StreamScopedPolicyReferenceRecordsV2.sol";

import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamScopedPolicyReferenceHistoryV2 {
    function requireExactScope(Bytes.Manifest storage publication, StreamFinalityScope memory scope)
        public
        view
    {
        T.Publication memory p = Records.publication(publication);
        if (keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))) {
            revert T.InvalidScopedPolicyReference();
        }
    }
}
