// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamReferenceRenderTypes as R } from "./StreamReferenceRenderTypes.sol";
import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Permissionless preparation of deterministic bytes, without reference publication authority.
interface IStreamReferenceEnvironmentPreparation is IERC165 {
    event ReferenceEnvironmentPrepared(
        uint16 schemaVersion, bytes32 indexed environmentId, bytes32 contentHash, uint32 byteLength
    );

    /// @dev Exact full typed input determines the chain/host-bound identity. Prepare both original
    /// file inventories and upload the complete canonical environment's Store chunks first.
    function prepareEnvironment(R.Environment calldata environment)
        external
        returns (bytes32 environmentId);
}
