// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamFinalityHostAdapter.sol";
import "./StreamFinalityCoordinatorPolicyTypes.sol";
import "./StreamScopeMembershipTypes.sol";

/// @notice One complete original-entropy route with independently inspectable native sources.
/// @dev A source set is a finality adapter/resolver, not a native entropy coordinator.
interface IStreamFinalityEntropySourceSet is IStreamFinalityHostAdapter {
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
        returns (StreamFinalityCoordinatorPolicy memory);
    /// @notice Validate current complete membership and all original locked policies.
    function requireCurrentSourceSet() external view;
    /// @notice Resolve only a token covered by this retained scope, through coordinatorAtMint.
    /// @dev Native pending/terminal status is preserved; callers decide required completion.
    function tokenSeedForFinality(uint256 tokenId) external view returns (bytes32, bool);
}
