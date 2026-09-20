// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as T
} from "./StreamScopedPolicyPublicationGraphTypesV2.sol";

interface IStreamScopedPolicyPublicationFactoryV2 is IERC165 {
    event ScopedPolicyPublicationChildPrepared(
        uint16 schemaVersion,
        bytes32 indexed graphId,
        bytes32 indexed inventoryPlan,
        uint8 indexed childIndex,
        address child,
        bytes32 codeHash
    );
    function scopedPolicyPublicationFactoryProfile() external pure returns (bytes32);
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function entropySourceFactory() external view returns (address);
    function recipeHash() external view returns (bytes32);
    function sourceFactoryDependenciesHash() external view returns (bytes32);
    function recipe() external view returns (T.Recipe memory);
    function prepareGraph(StreamFinalityScope calldata scope, uint8 maximumChildren)
        external
        returns (T.Graph memory);
    function graphForPlan(bytes32 inventoryPlan) external view returns (T.Graph memory);
    /// @notice Requires genuine current source and the complete immutable constructor graph.
    /// @dev Does not require publications, roots or finality; those follow deployment.
    function requireCurrentGraph(StreamFinalityScope calldata scope)
        external
        view
        returns (T.Graph memory);
}
