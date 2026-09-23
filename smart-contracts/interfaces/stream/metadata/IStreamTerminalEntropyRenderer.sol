// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "./IStreamRenderer.sol";

interface IStreamTerminalEntropyRenderer {
    function terminalEntropyProfile() external pure returns (bytes32);
    function terminalEncodingBinding() external view returns (address encoding, bytes32 runtimeHash);
    function terminalPolicyBinding()
        external
        view
        returns (address core, address coordinator, bytes32 runtimeHash);
    function terminalValidationBinding()
        external
        view
        returns (address validation, bytes32 runtimeHash);
    function renderTerminal(R.RenderRequest calldata request, uint8 mode)
        external
        view
        returns (string memory);
}
