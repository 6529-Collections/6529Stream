// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Explicit current-authority capability for an original RIGHTS selector deployment.
/// @dev Preserves that deployment's own selection history and permanent seals through
/// authenticated Artist succession. It cannot import a legacy selector's state or grant rights.
interface IStreamRightsRecordCurrentAuthority is IERC165 {
    function currentAuthorityProfile() external pure returns (bytes32);

    /// @return targets Current Artist facade, operation Coordinator and Identity owner.
    /// @return codeHashes Current runtimes authenticated through Metadata's immutable ancestry.
    /// @dev Each read applies the complete current-authority proof. These three Identity pins
    /// are distinct from the five-target WORK/CONSERVATION currentArtistContext() capability.
    function currentArtistIdentityContext()
        external
        view
        returns (address[3] memory targets, bytes32[3] memory codeHashes);
}
