// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamScopeMembershipReads as Reads } from "../finality/StreamScopeMembershipReads.sol";
import {
    StreamScopeMembershipEncoding as Encoding
} from "../finality/StreamScopeMembershipEncoding.sol";
import { StreamMetadataSubjects } from "./StreamMetadataSubjects.sol";
import {
    StreamScopeMembershipManifest
} from "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Reuses the actual membership producer's original publication grammar and checks.
/// @dev Linked execution retains the Metadata host. Caller-supplied hosts or scope tuples are absent.
library StreamMetadataPublishedScopeSubject {
    function derive(
        address core,
        address schemas,
        address store,
        uint256 readGas,
        bytes32 recordHash
    ) public view returns (bytes32 subjectId, StreamFinalityScope memory scope) {
        (StreamScopeMembershipManifest memory manifest,) = Reads.publication(
            Reads.Inputs(block.chainid, core, address(this), schemas, store, readGas), recordHash
        );
        scope = StreamFinalityScope(
            StreamFinalityScopeType(manifest.scopeType),
            manifest.collectionId,
            0,
            Encoding.scopeId(
                block.chainid, core, manifest.collectionId, manifest.scopeType, recordHash
            )
        );
        subjectId = StreamMetadataSubjects.scopeSubject(block.chainid, core, scope);
    }
}
