// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCurrentAuthorityTypes as C
} from "../artist/StreamArtistCurrentAuthorityTypes.sol";

/// @notice Capability of a new original Finality anchor; sanctionReads remains historical.
interface IStreamFinalityCurrentAuthority {
    function currentAuthorityProfile() external view returns (bytes32);
    function currentAuthorityResolver() external view returns (address);
    function currentAuthorityResolverCodeHash() external view returns (bytes32);
    function currentArtistAuthority(uint256 collectionId) external view returns (C.Route memory);
}
