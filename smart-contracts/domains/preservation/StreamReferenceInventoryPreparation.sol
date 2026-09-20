// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceEnvironmentJson as Json
} from "../records/StreamReferenceEnvironmentJson.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";

/// @notice Permissionless bounded preparation; exact original rows still determine the final identity.
/// @dev The host passes its compiler-declared inventory mapping. Parts and whole inventories use
/// disjoint hash domains in that same mapping; neither preparation grants publication authority.
library StreamReferenceInventoryPreparation {
    uint256 private constant PART_ROWS = 64;
    uint256 private constant MAX = 524288;

    error InvalidInventoryPart();
    error InventoryPartUnavailable(bytes32 partId);
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

    function preparePart(
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        address store,
        bytes32 storeCodeHash,
        bytes calldata original
    ) public returns (bytes32 id) {
        _store(store, storeCodeHash);
        (R.PackageFile[] memory rows, bool relative) =
            abi.decode(original[4:], (R.PackageFile[], bool));
        if (rows.length == 0 || rows.length > PART_ROWS) revert InvalidInventoryPart();
        id = _partId(rows, relative);
        if (inventories[id].contentHash != 0) {
            Bytes.requireIntact(inventories[id]);
            return id;
        }
        bytes memory raw = bytes(Json.files(rows, relative));
        bytes32 hash = Bytes.retain(inventories[id], store, raw);
        emit ReferenceInventoryPartPrepared(
            1, id, relative, uint16(rows.length), hash, uint32(raw.length)
        );
    }

    function assemble(
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        address store,
        bytes32 storeCodeHash,
        bytes calldata original
    ) public returns (bytes32 id) {
        _store(store, storeCodeHash);
        (R.PackageFile[] memory rows, bool relative) =
            abi.decode(original[4:], (R.PackageFile[], bool));
        // Exact unchanged StreamReferenceRenderPreparation.inventoryId preimage.
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_FILE_INVENTORY_V1"),
                block.chainid,
                address(this),
                relative,
                rows
            )
        );
        if (inventories[id].contentHash != 0) {
            Bytes.requireIntact(inventories[id]);
            return id;
        }
        uint256 count = (rows.length + PART_ROWS - 1) / PART_ROWS;
        bytes[] memory pieces = new bytes[](count);
        uint256 length = 2;
        for (uint256 i; i < count; ++i) {
            uint256 offset = i * PART_ROWS;
            uint256 n = rows.length - offset;
            if (n > PART_ROWS) n = PART_ROWS;
            // Within-part validation is authenticated by the exact typed part identity.
            // The only remaining global ordering check is at each fixed boundary.
            if (offset != 0 && !_less(bytes(rows[offset - 1].path), bytes(rows[offset].path))) {
                revert R.InvalidReferenceRender();
            }
            R.PackageFile[] memory part = new R.PackageFile[](n);
            for (uint256 j; j < n; ++j) {
                part[j] = rows[offset + j];
            }
            bytes32 partId = _partId(part, relative);
            if (inventories[partId].contentHash == 0) revert InventoryPartUnavailable(partId);
            bytes memory raw = Bytes.read(inventories[partId]);
            if (raw.length < 2 || raw[0] != "[" || raw[raw.length - 1] != "]") {
                revert InvalidInventoryPart();
            }
            pieces[i] = raw;
            length += raw.length - 2 + (i == 0 ? 0 : 1);
            if (length - 1 > MAX) revert R.InvalidReferenceRender();
        }
        bytes memory canonical = new bytes(length);
        canonical[0] = "[";
        uint256 cursor = 1;
        for (uint256 i; i < count; ++i) {
            if (i != 0) canonical[cursor++] = ",";
            bytes memory part = pieces[i];
            uint256 size = part.length - 2;
            _copy(canonical, cursor, part, size);
            cursor += size;
        }
        canonical[cursor] = "]";
        bytes32 hash = Bytes.retain(inventories[id], store, canonical);
        emit ReferenceInventoryAssembled(
            1, id, relative, rows.length, hash, uint32(canonical.length)
        );
    }

    function _partId(R.PackageFile[] memory rows, bool relative) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_FILE_INVENTORY_PART_V1"),
                block.chainid,
                address(this),
                relative,
                rows
            )
        );
    }

    function _store(address store, bytes32 expected) private view {
        if (store.code.length == 0 || store.codehash != expected) {
            revert R.ReferenceDependency(store);
        }
    }

    /// @dev Source skips only '['; size excludes both brackets. No memory outside the output is written.
    function _copy(bytes memory out, uint256 cursor, bytes memory part, uint256 size) private pure {
        if (cursor + size > out.length) revert InvalidInventoryPart();
        assembly ("memory-safe") {
            let target := add(add(out, 32), cursor)
            let source := add(part, 33)
            let i := 0
            for { } iszero(gt(add(i, 32), size)) { i := add(i, 32) } {
                mstore(add(target, i), mload(add(source, i)))
            }
            if lt(i, size) {
                let tail := mload(add(source, i))
                for { let j := 0 } lt(j, sub(size, i)) { j := add(j, 1) } {
                    mstore8(add(add(target, i), j), byte(j, tail))
                }
            }
        }
    }

    function _less(bytes memory a, bytes memory b) private pure returns (bool result) {
        uint256 length = a.length < b.length ? a.length : b.length;
        for (uint256 i; i < length; ++i) {
            if (a[i] != b[i]) return a[i] < b[i];
        }
        return a.length < b.length;
    }
}
