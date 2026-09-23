// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";
import { StreamViewPolicyCheckpointTypesV2 as T } from "./StreamViewPolicyCheckpointTypesV2.sol";

/// @notice Complete ordered VIEW output observations under the actual current V2 adoption.
/// @dev Preparation grants no Artist authority. Historical rows are not current evidence.
interface IStreamViewPolicyContentCheckpointV2 {
    event ViewCheckpointStarted(bytes32 indexed id, bytes32 indexed adoptionRecord, bytes32 salt);
    event ViewCheckpointAppended(
        bytes32 indexed id, uint64 index, uint256 indexed tokenId, bytes32 rowHash
    );
    event ViewCheckpointSealed(bytes32 indexed id, bytes32 outputRoot, uint64 tokenCount);
    function configuration() external view returns (T.Configuration memory);
    function configurationHash() external view returns (bytes32);
    function checkpointProfile() external pure returns (bytes32);
    function begin(StreamFinalityScope calldata scope, bytes32 salt) external returns (bytes32);
    function append(bytes32 id, uint256 expectedTokenId, bytes calldata json, bytes calldata html)
        external;
    function seal(bytes32 id) external returns (bytes32 outputRoot);
    function checkpoint(bytes32 id) external view returns (T.Plan memory);
    function outputAt(bytes32 id, uint256 index) external view returns (T.Output memory);
    function requireCurrentCheckpoint(bytes32 id) external view returns (T.Plan memory);
}
