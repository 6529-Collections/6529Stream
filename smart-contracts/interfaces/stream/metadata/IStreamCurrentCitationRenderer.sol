// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamRenderer as R } from "./IStreamRenderer.sol";

/// @notice Additive current output. Original renderer selectors retain their original bytes.
interface IStreamCurrentCitationRenderer {
    function currentCitationProfile() external pure returns (bytes32);
    function renderCurrent(R.RenderRequest calldata request, uint8 mode)
        external
        view
        returns (string memory);
    function encodingBinding() external view returns (address encoding, bytes32 runtimeHash);
}
