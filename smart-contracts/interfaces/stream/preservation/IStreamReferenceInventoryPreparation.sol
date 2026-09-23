// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamReferenceRenderTypes as R } from "./StreamReferenceRenderTypes.sol";
import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Additive preparation companion. The original publication interface ID is unchanged.
interface IStreamReferenceInventoryPreparation is IERC165 {
    event ReferenceInventoryPartPrepared(
        uint16 schemaVersion,
        bytes32 indexed partId,
        bool relative,
        uint16 rowCount,
        bytes32 contentHash,
        uint32 byteLength
    );
    event ReferenceInventoryAssembled(
        uint16 schemaVersion,
        bytes32 indexed inventoryId,
        bool relative,
        uint256 rowCount,
        bytes32 contentHash,
        uint32 byteLength
    );
    /// @dev 1..64 consecutive canonical rows; upload the exact part-array Store chunks first.
    function prepareFileInventoryPart(R.PackageFile[] calldata rows, bool relative)
        external
        returns (bytes32 partId);
    /// @dev The full original rows determine all fixed64-row parts and the unchanged inventoryId.
    /// Upload the complete canonical array's Store chunks before this call.
    function prepareFileInventoryFromParts(R.PackageFile[] calldata fullOriginalRows, bool relative)
        external
        returns (bytes32 inventoryId);
}
