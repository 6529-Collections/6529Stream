// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @dev One explicit host-owned layout. Linked stages receive its actual storage reference.
library StreamRenderCriticalInventoryState {
    struct DocumentPin {
        bytes32 id;
        bytes32 factsHash;
    }

    struct State {
        S.Dependencies dependencies;
        bytes32 dependencyHash;
        mapping(bytes32 => S.Context) contexts;
        mapping(bytes32 => T.Plan) plans;
        mapping(bytes32 => mapping(uint64 => T.Segment)) segments;
        mapping(bytes32 => uint64) definitionCursor;
        mapping(bytes32 => T.Evidence) completed;
        mapping(bytes32 => DocumentPin[]) documents;
    }
}
