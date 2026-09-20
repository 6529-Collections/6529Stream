// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./StreamConservationFloorTypes.sol";

/// @notice Exact native source interpretation, admitted once per immutable graph by delayed governance.
/// @dev Unsupported prospective scope, media class or documentary proof must revert, never return
/// fabricated success. configurationHash commits the complete original source/interpretation graph.
interface IStreamConservationFloorProvider is IERC165 {
    function core() external view returns (address);
    function coreCodeHash() external view returns (bytes32);
    function metadata() external view returns (address);
    function metadataCodeHash() external view returns (bytes32);
    function configurationHash() external view returns (bytes32);
    function deploymentChainId() external view returns (uint256);

    function requireCollectionFloor(uint256 collectionId, bytes32 tier)
        external
        view
        returns (StreamConservationFloorTypes.CollectionFacts memory);
    function saleRelease(StreamConservationFloorTypes.SaleContext calldata sale)
        external
        view
        returns (StreamConservationFloorTypes.ReleaseContext memory);
    function requireReleaseFloor(
        StreamConservationFloorTypes.SaleContext calldata sale,
        StreamConservationFloorTypes.ReleaseContext calldata release,
        bytes32 tier
    ) external view returns (StreamConservationFloorTypes.ReleaseFacts memory);
}
