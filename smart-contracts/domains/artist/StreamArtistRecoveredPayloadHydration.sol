// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistReconstruction as Reconstruction
} from "../../interfaces/stream/artist/IStreamArtistReconstruction.sol";
import { SSTORE2 } from "../../libraries/SSTORE2.sol";
import { StreamArtistPayloadStore as PayloadStore } from "./StreamArtistPayloadStore.sol";

/// @notice Complete original carrier catalogs for the recovered operation60 transport.
/// @dev The caller authenticates the fixed source owner and binds these rows into the import.
/// Carrier bytes grant no authority. Native occurrence and original-domain proofs stay in the
/// semantic journal. A later import reads the flattened current catalog, never an ancestor chain.
library StreamArtistRecoveredPayloadHydration {
    // Explicit transport capacity only. Original producer writes remain unrestricted.
    uint256 internal constant MAX_ROWS = 16_384;

    struct Row {
        address pointer;
        bytes32 payloadType;
        bytes32 payloadHash;
    }

    error InvalidRecoveredPayloadCatalog(uint8 ownerIndex);
    error InvalidRecoveredPayloadRow(uint256 index);

    function collect(address source, uint8 ownerIndex) public view returns (Row[] memory rows) {
        if (ownerIndex >= 7) revert InvalidRecoveredPayloadCatalog(ownerIndex);
        if (!_catalogOwner(ownerIndex)) return new Row[](0);
        if (source.code.length == 0) revert InvalidRecoveredPayloadCatalog(ownerIndex);
        uint256 count = Reconstruction(source).storedPayloadCount();
        if (count > MAX_ROWS) revert InvalidRecoveredPayloadCatalog(ownerIndex);
        rows = new Row[](count);
        for (uint256 i; i < count; ++i) {
            (rows[i].pointer, rows[i].payloadType, rows[i].payloadHash) =
                Reconstruction(source).storedPayloadAt(i);
            _content(rows[i]);
        }
        validateShape(ownerIndex, rows);
    }

    /// @notice Pure envelope validation. Actual carrier reads occur at collect, apply and recheck.
    function validateShape(uint8 ownerIndex, Row[] memory rows) public pure {
        if (
            ownerIndex >= 7 || rows.length > MAX_ROWS
                || (!_catalogOwner(ownerIndex) && rows.length != 0)
        ) revert InvalidRecoveredPayloadCatalog(ownerIndex);
        bytes32[] memory keys = new bytes32[](rows.length);
        for (uint256 i; i < rows.length; ++i) {
            Row memory row = rows[i];
            if (row.pointer == address(0) || row.payloadType == 0 || row.payloadHash == 0) {
                revert InvalidRecoveredPayloadRow(i);
            }
            keys[i] = keccak256(abi.encode(row.payloadType, row.payloadHash));
        }
        // Sort a separate key array: source catalog order and original pointers are untouched.
        keys = _sort(keys);
        for (uint256 i = 1; i < keys.length; ++i) {
            if (keys[i] == keys[i - 1]) revert InvalidRecoveredPayloadCatalog(ownerIndex);
        }
    }

    /// @notice Called by the guarded fixed owner before semantic imports store matching payloads.
    /// @dev registerPointer validates every carrier even when its content key already exists.
    function applyCatalog(uint8 ownerIndex, Row[] memory rows) public {
        validateShape(ownerIndex, rows);
        for (uint256 i; i < rows.length; ++i) {
            _content(rows[i]);
            PayloadStore.registerPointer(rows[i].pointer, rows[i].payloadType, rows[i].payloadHash);
        }
    }

    /// @notice Rechecks the entire source list after destination writes, including carrier bytes.
    function requireSource(address source, uint8 ownerIndex, Row[] memory rows) public view {
        validateShape(ownerIndex, rows);
        if (!_catalogOwner(ownerIndex)) return;
        if (source.code.length == 0 || Reconstruction(source).storedPayloadCount() != rows.length) {
            revert InvalidRecoveredPayloadCatalog(ownerIndex);
        }
        for (uint256 i; i < rows.length; ++i) {
            (address pointer, bytes32 kind, bytes32 hash) =
                Reconstruction(source).storedPayloadAt(i);
            if (
                pointer != rows[i].pointer || kind != rows[i].payloadType
                    || hash != rows[i].payloadHash
            ) revert InvalidRecoveredPayloadRow(i);
            _content(rows[i]);
        }
    }

    function _catalogOwner(uint8 ownerIndex) private pure returns (bool) {
        return ownerIndex == 2 || ownerIndex == 4 || ownerIndex == 6;
    }

    function _content(Row memory row) private view {
        if (row.pointer.code.length > SSTORE2.MAX_DATA_LENGTH + 1) {
            revert SSTORE2.SSTORE2InvalidPointer(row.pointer);
        }
        bytes32 observed = keccak256(SSTORE2.read(row.pointer));
        if (observed != row.payloadHash) {
            revert Reconstruction.ArtistPayloadCorrupted(row.payloadHash, observed);
        }
    }

    function _sort(bytes32[] memory values) private pure returns (bytes32[] memory) {
        if (values.length < 2) return values;
        bytes32[] memory scratch = new bytes32[](values.length);
        for (uint256 width = 1; width < values.length; width *= 2) {
            for (uint256 first; first < values.length; first += width * 2) {
                uint256 middle = first + width;
                if (middle > values.length) middle = values.length;
                uint256 end = middle + width;
                if (end > values.length) end = values.length;
                uint256 left = first;
                uint256 right = middle;
                for (uint256 output = first; output < end; ++output) {
                    if (right == end || (left < middle && values[left] <= values[right])) {
                        scratch[output] = values[left++];
                    } else {
                        scratch[output] = values[right++];
                    }
                }
            }
            (values, scratch) = (scratch, values);
        }
        return values;
    }
}
