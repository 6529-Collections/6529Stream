// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamC2PAReconciliation as C } from "./IStreamC2PAReconciliation.sol";

/// @notice Optional typed extension of the immutable STATIC attribution source.
interface IStreamStaticC2PAAttribution {
    function attributionWithC2PA(uint256 collectionId, uint256 tokenId)
        external
        view
        returns (bytes memory attribution, C.Display memory c2pa, bytes32 subjectId);
}
