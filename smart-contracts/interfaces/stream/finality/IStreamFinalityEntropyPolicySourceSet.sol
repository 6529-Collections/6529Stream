// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamFinalityHostAdapter.sol";
import "./StreamFinalityCoordinatorPolicyTypesV2.sol";
import "./StreamScopeMembershipTypes.sol";

/// @notice V2 policy/status evidence, never a claim that every renderer is entropy-independent.
interface IStreamFinalityEntropyPolicySourceSet is IStreamFinalityHostAdapter {
    struct TokenReadiness {
        address coordinator;
        bytes32 coordinatorCodeHash;
        bytes32 policyHash;
        uint8 status;
        uint8 mode;
        uint8 securityClass;
        uint8 renderRequirement;
        bool terminal;
        bool finalized;
        bytes32 seed;
    }
    function factory() external view returns (address);
    function inventoryPlan() external view returns (bytes32);
    function originalInventoryHash() external view returns (bytes32);
    function originalPolicyChainHash() external view returns (bytes32);
    function sourceScope() external view returns (StreamFinalityScope memory);
    function scopeMembershipFacts() external view returns (StreamScopeMembershipFacts memory);
    function sourceCount() external view returns (uint256);
    function sourcePolicyAt(uint256 index)
        external
        view
        returns (StreamFinalityCoordinatorPolicyV2 memory);
    function requireCurrentSourceSet() external view;
    function tokenEntropyReadiness(uint256 tokenId) external view returns (TokenReadiness memory);
}
