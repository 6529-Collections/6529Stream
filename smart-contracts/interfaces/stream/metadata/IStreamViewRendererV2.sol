// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "./IStreamRenderer.sol";
import {
    StreamViewPolicyTypesV2 as T
} from "../../../domains/metadata/StreamViewPolicyTypesV2.sol";

/// @notice Closed V2 adopted VIEW renderer with a constructor-authenticated full policy roster.
interface IStreamViewRendererV2 {
    /// @dev Core, Router, actual scoped policy source set, original live attribution companion.
    function sourceBindings() external view returns (address[4] memory, bytes32[4] memory);
    /// @dev Fixed formatter target and constructor-retained runtime; include both formatter reads in STATIC admission.
    function encodingBinding() external view returns (address, bytes32);
    function policyViewBinding() external view returns (T.Binding memory);
    function renderPolicyView(R.RenderRequest calldata request, uint8 mode)
        external
        view
        returns (string memory);
}
