// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../metadata/StreamViewPreservationSnapshotTypesV1.sol";

import { StreamViewAdoptionTypes as D } from "../metadata/StreamViewAdoptionTypes.sol";

/// @notice One irreversible VIEW snapshot-source binding, separate from finality readiness.
library StreamFinalityViewPreservationBindingTypesV1 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_BINDING_V1");
    uint8 internal constant ACTION_CLASS = 2;

    struct Configuration {
        address snapshotHost;
        bytes32 snapshotCodeHash;
        uint256 validationGas;
        address checkpointHost;
        bytes32 checkpointCodeHash;
        address manifestHost;
        bytes32 manifestCodeHash;
    }

    struct Capability {
        address authority;
        bytes32 authorityCodeHash;
        bytes32 originalHash;
        bytes32 capabilityHash;
    }

    struct Receipt {
        bytes32 capabilityHash;
        Configuration configuration;
        D.Binding declaration;
        S.Dependencies dependencies;
        bytes32 dependenciesHash;
        bytes32 workersHash;
        bytes32 actionId;
        uint64 boundAt;
        bytes32 recordHash;
    }

    struct Transition {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }
    error ViewPreservationPending();
    error ViewPreservationAlreadyBound();
    error InvalidViewPreservationBinding();
    error ViewPreservationBindingDependency(address target);
    error ViewPreservationBindingGovernance();

    function hashCapability(uint256 chainId, address provider, Capability memory c)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(PROFILE, chainId, provider, c.authority, c.authorityCodeHash, c.originalHash)
        );
    }

    /// @dev A scheduled proposal cannot contain its own action ID or future execution time.
    function proposalHash(Receipt memory r) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_PROPOSAL_V1"),
                r.capabilityHash,
                r.configuration,
                r.declaration,
                r.dependencies,
                r.dependenciesHash,
                r.workersHash
            )
        );
    }

    function receiptHash(Receipt memory r) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_RECEIPT_V1"),
                proposalHash(r),
                r.actionId,
                r.boundAt
            )
        );
    }

    function transition(uint256 chainId, address provider, Receipt memory r)
        internal
        pure
        returns (Transition memory t)
    {
        t.scopeHash = keccak256(abi.encode(PROFILE, chainId, provider, r.capabilityHash));
        t.oldValueHash = keccak256(abi.encode(PROFILE, r.capabilityHash, false));
        t.newValueHash = proposalHash(r);
    }
}
