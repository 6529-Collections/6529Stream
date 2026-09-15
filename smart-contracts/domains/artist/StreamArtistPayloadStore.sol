// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistReconstruction.sol";
import "../../libraries/SSTORE2.sol";

/// @notice Append-only content carriers in the calling fixed host's separate storage namespace.
library StreamArtistPayloadStore {
    bytes32 internal constant RECORD = keccak256("ARTIST_RECORD_PREIMAGE");
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_PAYLOAD_CATALOG_STORAGE_V1");

    struct Row {
        address pointer;
        bytes32 payloadType;
        bytes32 payloadHash;
    }

    struct State {
        Row[] rows;
        mapping(bytes32 => address) pointers;
    }
    event ArtistStoredPayload(
        uint16 schemaVersion,
        uint256 indexed index,
        bytes32 indexed payloadType,
        bytes32 indexed payloadHash,
        address pointer
    );

    function _state() private pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function store(bytes32 kind, bytes memory payload) public returns (address pointer) {
        bytes32 hash = keccak256(payload);
        pointer = _state().pointers[keccak256(abi.encode(kind, hash))];
        if (pointer != address(0)) {
            _read(pointer, hash);
            return pointer;
        }
        pointer = SSTORE2.write(payload);
        _append(pointer, kind, hash);
    }

    function preimage(bytes32 recordHash, bytes memory payload) public {
        bytes32 hash = keccak256(payload);
        if (recordHash == 0 || hash != recordHash) {
            revert IStreamArtistReconstruction.ArtistPayloadCorrupted(recordHash, hash);
        }
        store(RECORD, payload);
    }

    function registerPointer(address pointer, bytes32 kind, bytes32 hash) public {
        if (kind == 0 || hash == 0 || pointer == address(0)) {
            revert IStreamArtistReconstruction.ArtistPayloadUnavailable(hash);
        }
        _read(pointer, hash);
        address old = _state().pointers[keccak256(abi.encode(kind, hash))];
        if (old != address(0)) {
            _read(old, hash);
            return;
        }
        _append(pointer, kind, hash);
    }

    function _append(address pointer, bytes32 kind, bytes32 hash) private {
        State storage s = _state();
        uint256 index = s.rows.length;
        s.pointers[keccak256(abi.encode(kind, hash))] = pointer;
        s.rows.push(Row(pointer, kind, hash));
        emit ArtistStoredPayload(1, index, kind, hash, pointer);
    }

    function count() public view returns (uint256) {
        return _state().rows.length;
    }

    function at(uint256 index) public view returns (address, bytes32, bytes32) {
        State storage s = _state();
        if (index >= s.rows.length) {
            revert IStreamArtistReconstruction.ArtistPayloadIndexOutOfBounds(index, s.rows.length);
        }
        Row storage r = s.rows[index];
        return (r.pointer, r.payloadType, r.payloadHash);
    }

    function recordBytes(bytes32 hash) public view returns (bytes memory) {
        address pointer = _state().pointers[keccak256(abi.encode(RECORD, hash))];
        if (pointer == address(0)) {
            revert IStreamArtistReconstruction.ArtistPayloadUnavailable(hash);
        }
        return _read(pointer, hash);
    }

    function _read(address pointer, bytes32 hash) private view returns (bytes memory data) {
        data = SSTORE2.read(pointer);
        bytes32 observed = keccak256(data);
        if (observed != hash) {
            revert IStreamArtistReconstruction.ArtistPayloadCorrupted(hash, observed);
        }
    }
}
