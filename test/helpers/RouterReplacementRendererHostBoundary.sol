// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./RouterOriginalCompositionBoundaries.sol";

/// @dev Explicit replacement Router-shaped host; returned source is deliberately different.
/// Only its renderer family is selected, so display/media/script remain on the actual old Router.
contract RouterReplacementRendererHostBoundary is MetadataRecoverySourceBoundary {
    constructor(address c, address renderer_)
        MetadataRecoverySourceBoundary(c, renderer_, "unused-replacement-source")
    { }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamMetadataRouter).interfaceId;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("METADATA_ROUTER");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamMetadataRouter).interfaceId;
    }
}
