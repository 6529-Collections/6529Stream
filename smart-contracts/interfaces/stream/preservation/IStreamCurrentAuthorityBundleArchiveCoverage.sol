// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import { StreamBundleArchiveTypes as B } from "./StreamBundleArchiveTypes.sol";
import { StreamArtistArchiveOriginTypes as O } from "./StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "./StreamCurrentAuthorityInventoryTypes.sol";

/// @notice Read-only captured-authority and original-Archive coverage capability.
/// @dev Compose with the applicable collection/scoped bundle read interface and exact profile.
/// This capability makes no claim about an inventory's publication or append selectors.
interface IStreamCurrentAuthorityBundleArchiveCoverage is IERC165 {
    function dependencies() external view returns (B.Dependencies memory);
    function originDependencies() external view returns (O.Dependencies memory);
    function authorityDependencies() external view returns (D.Dependencies memory);
    function originProfile() external pure returns (bytes32);
    function admittedOriginHash(bytes32 id, uint64 index) external view returns (bytes32);
}
