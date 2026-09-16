// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtworkFinalityComponents.sol";
import "./IStreamFinalityEntropySourceSet.sol";

/// @notice Append-only, fixed-graph discovery of the complete original entropy route for a scope.
/// @dev This is the entropy-family projection, not the whole finality component discovery.
interface IStreamFinalityEntropySourceFactory is IERC165 {
    event EntropySourceSetPrepared(
        bytes32 indexed planId,
        address indexed sourceSet,
        bytes32 indexed scopeSubject,
        bytes32 sourceSetCodeHash,
        bytes32 dataHash
    );
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function scopeMembershipHost() external view returns (address);
    function coordinatorInventory() external view returns (address);
    function currentInventoryPlan(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32);
    function prepareSourceSet(StreamFinalityScope calldata scope) external returns (address);
    function sourceSetForPlan(bytes32 planId)
        external
        view
        returns (address sourceSet, bytes32 codeHash);
    function requireCurrentComponent(StreamFinalityScope calldata scope)
        external
        view
        returns (StreamFinalityComponentExpectation memory);
}
