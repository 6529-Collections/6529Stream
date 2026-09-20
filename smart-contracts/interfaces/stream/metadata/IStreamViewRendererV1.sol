// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "./IStreamRenderer.sol";

interface IStreamViewRendererV1 {
    function sourceBindings() external view returns (address[4] memory, bytes32[4] memory);
    function renderView(R.RenderRequest calldata request, uint8 mode)
        external
        view
        returns (string memory);
}
