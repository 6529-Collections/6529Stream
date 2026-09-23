// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Additive selector capability anchored to its original Metadata deployment.
/// @dev These original selector deployments preserve their own histories and locks through
/// authenticated Artist succession. They do not import a deployed legacy selector's storage.
interface IStreamRecordCurrentAuthority is IERC165 {
    function currentAuthorityProfile() external pure returns (bytes32);

    /// @return targets Current facade, Coordinator, Identity, Binding and Attribution owners.
    /// @return codeHashes Exact runtimes authenticated during this read, in the same order.
    function currentArtistContext()
        external
        view
        returns (address[5] memory targets, bytes32[5] memory codeHashes);
}
