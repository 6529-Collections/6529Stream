// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "./StreamCurrentAuthorityInventoryTypes.sol";
import { StreamRenderCriticalSourceTypes as S } from "./StreamRenderCriticalSourceTypes.sol";

/// @notice Fixed original anchors and immutable per-plan current authority captures.
interface IStreamCurrentAuthorityInventory {
    function originalAnchor() external view returns (S.Dependencies memory);
    function authorityDependencies() external view returns (D.Dependencies memory);
    function authoritySelection(bytes32 planId) external view returns (D.Capture memory);
}
