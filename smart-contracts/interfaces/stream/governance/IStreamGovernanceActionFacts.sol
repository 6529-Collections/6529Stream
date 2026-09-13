// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceTypes.sol";

/// @notice Bounded scheduled-action facts without copying the governance reason URI.
/// @dev Consumers authenticate a complete call-array witness against callHash. The first
///      target/selector of a batch is not sufficient evidence of any later recovery call.
interface IStreamGovernanceActionFacts {
    struct ActionFacts {
        GovernanceActionStatus status;
        uint8 actionClass;
        bytes32 callHash;
        uint64 notBefore;
        uint64 expiresAfter;
    }

    /// @dev Exactly five ABI words. Unknown action IDs return zero-valued NONE facts.
    function governanceActionFacts(bytes32 actionId) external view returns (ActionFacts memory);
}
