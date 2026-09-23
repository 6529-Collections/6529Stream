// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamEntropyCoordinatorContinuity as V
} from "../../interfaces/stream/entropy/IStreamEntropyCoordinatorContinuity.sol";
import { StreamEntropyRecoveryPolicies } from "./StreamEntropyRecoveryPolicies.sol";
import { StreamEntropyCollectionRecovery } from "./StreamEntropyCollectionRecovery.sol";
import {
    IStreamEntropyCollectionRecovery as C
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionRecovery.sol";

/// @notice Fixed O(1) pending coverage. All storage belongs to the calling coordinator.
library StreamEntropyContinuity {
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_CONTINUITY_STORAGE_V1");

    struct Pending {
        bytes32 targetKey;
        bool active;
    }

    struct Store {
        mapping(bytes32 => Pending) requests;
        mapping(bytes32 => uint256) covered;
    }

    function store() private pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function admit(uint256 collectionId, bytes32 requestKey) public {
        Store storage s = store();
        if (s.requests[requestKey].active) revert V.InvalidEntropyContinuity();
        C.CollectionRecovery memory bound = StreamEntropyCollectionRecovery.record(collectionId);
        bytes32 target =
            StreamEntropyRecoveryPolicies.replacementKey(bound.policyId, bound.policyHash);
        s.requests[requestKey] = Pending(target, true);
        if (target != 0) ++s.covered[target];
    }

    /// @dev Call with the pre-finalization ACTIVE key, including for late-original fulfillment.
    function close(bytes32 requestKey) public {
        Store storage s = store();
        Pending storage p = s.requests[requestKey];
        if (!p.active) revert V.InvalidEntropyContinuity();
        p.active = false;
        if (p.targetKey != 0) --s.covered[p.targetKey];
    }

    function uncovered(uint256 total, address successor, bytes32 codeHash)
        public
        view
        returns (uint256)
    {
        uint256 covered = store().covered[keccak256(abi.encode(successor, codeHash))];
        if (covered > total) revert V.InvalidEntropyContinuity();
        return total - covered;
    }
}
