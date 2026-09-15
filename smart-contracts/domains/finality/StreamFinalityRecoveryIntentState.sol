// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityRecoveryHashes.sol";
import "../../libraries/SSTORE2.sol";
import "../../interfaces/stream/finality/IStreamFinalityRecoveryIntentStorage.sol";
import {
    StreamFinalityManifestRef
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Content-addressed staging and immutable full-request availability for the fixed owner.
/// @dev This library validates bytes and canonical shape only. The companion independently
///      authenticates current scope, lineage, component, evidence and execution context.
library StreamFinalityRecoveryIntentState {
    error FinalityRecoveryManifestBytesInvalid();
    error FinalityRecoveryManifestBytesMissing(bytes32 contentHash);
    error FinalityRecoveryManifestIntentMismatch(bytes32 expected, bytes32 actual);
    error FinalityRecoveryManifestInvalid();
    error FinalityRecoveryReasonHashZero();
    error FinalityRecoveryScopeShapeInvalid();
    error FinalityRecoveryIntentRequestMissing(bytes32 contentHash);
    error FinalityRecoveryIntentRequestMismatch(bytes32 contentHash);

    event FinalityRecoveryManifestStaged(
        uint16 schemaVersion, bytes32 indexed manifestContentHash, uint256 byteLength, address actor
    );
    event FinalityRecoveryIntentRegistered(
        uint16 schemaVersion,
        bytes32 indexed manifestContentHash,
        bytes32 indexed requestHash,
        address requestPointer,
        address actor
    );

    struct Payload {
        address pointer;
        bytes32 codeHash;
        bytes32 contentHash;
    }

    struct State {
        mapping(bytes32 => Payload) manifests;
        mapping(bytes32 => Payload) requests;
    }

    function stage(State storage self, bytes memory data) public returns (bytes32 hash) {
        if (data.length == 0 || data.length > 24575) revert FinalityRecoveryManifestBytesInvalid();
        hash = keccak256(data);
        if (self.manifests[hash].pointer == address(0)) {
            self.manifests[hash] = _write(data, hash);
            emit FinalityRecoveryManifestStaged(1, hash, data.length, msg.sender);
        } else {
            _read(self.manifests[hash]);
        }
    }

    function manifestBytes(State storage self, bytes32 hash) public view returns (bytes memory) {
        if (self.manifests[hash].pointer == address(0)) return bytes("");
        return _read(self.manifests[hash]);
    }

    function register(
        State storage self,
        StreamFinalityRecoveryHashes.Environment memory environment,
        StreamFinalityRecoveryRequest memory request
    ) public returns (bytes32 hash) {
        bytes memory data = validate(self, environment, request);
        hash = keccak256(data);
        bytes32 key = request.recoveryManifest.contentHash;
        if (self.requests[key].pointer == address(0)) {
            self.requests[key] = _write(data, hash);
            emit FinalityRecoveryIntentRegistered(
                1, key, hash, self.requests[key].pointer, msg.sender
            );
        } else if (keccak256(_read(self.requests[key])) != hash) {
            revert FinalityRecoveryIntentRequestMismatch(key);
        }
    }

    function requestFor(State storage self, bytes32 hash)
        public
        view
        returns (StreamFinalityRecoveryRequest memory request)
    {
        if (self.requests[hash].pointer == address(0)) {
            revert FinalityRecoveryIntentRequestMissing(hash);
        }
        bytes memory data = _read(self.requests[hash]);
        request = abi.decode(data, (StreamFinalityRecoveryRequest));
        if (
            request.recoveryManifest.contentHash != hash
                || keccak256(abi.encode(request)) != keccak256(data)
        ) {
            revert FinalityRecoveryIntentRequestMismatch(hash);
        }
    }

    /// @notice Revalidates the staged preimage at every operative preparation or execution.
    function validate(
        State storage self,
        StreamFinalityRecoveryHashes.Environment memory environment,
        StreamFinalityRecoveryRequest memory request
    ) public view returns (bytes memory encoded) {
        shape(request.scope);
        StreamFinalityManifestRef memory m = request.recoveryManifest;
        if (
            bytes(m.uri).length == 0 || m.uriHash != keccak256(bytes(m.uri)) || m.contentHash == 0
                || m.schemaId == 0 || m.canonicalizationHash == 0 || !_utf8(bytes(m.uri))
                || !_utf8(bytes(request.reasonURI))
        ) revert FinalityRecoveryManifestInvalid();
        if (request.reasonHash == 0) revert FinalityRecoveryReasonHashZero();
        encoded = abi.encode(request);
        // A canonical ABI payload is word-aligned. Its complete STOP-prefixed object must fit.
        if (encoded.length > 24575) revert FinalityRecoveryManifestBytesInvalid();
        bytes memory expected = StreamFinalityRecoveryHashes.intentBytes(environment, request);
        bytes32 actual = keccak256(expected);
        if (actual != m.contentHash) {
            revert FinalityRecoveryManifestIntentMismatch(m.contentHash, actual);
        }
        if (self.manifests[m.contentHash].pointer == address(0)) {
            revert FinalityRecoveryManifestBytesMissing(m.contentHash);
        }
        bytes memory stored = _read(self.manifests[m.contentHash]);
        if (stored.length != 704 || keccak256(stored) != actual) {
            revert FinalityRecoveryManifestBytesInvalid();
        }
    }

    function shape(StreamFinalityScope memory scope) public pure {
        if (scope.collectionId == 0) revert FinalityRecoveryScopeShapeInvalid();
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            if (scope.tokenId != 0 || scope.scopeId != 0) {
                revert FinalityRecoveryScopeShapeInvalid();
            }
        } else if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            if (scope.tokenId == 0 || scope.scopeId != 0) {
                revert FinalityRecoveryScopeShapeInvalid();
            }
        } else if (scope.tokenId != 0 || scope.scopeId == 0) {
            revert FinalityRecoveryScopeShapeInvalid();
        }
    }

    function _write(bytes memory data, bytes32 hash) private returns (Payload memory p) {
        p.pointer = SSTORE2.write(data);
        p.codeHash = p.pointer.codehash;
        p.contentHash = hash;
    }

    function _read(Payload storage p) private view returns (bytes memory data) {
        if (p.pointer.code.length == 0 || p.pointer.codehash != p.codeHash) {
            revert FinalityRecoveryManifestBytesInvalid();
        }
        data = SSTORE2.read(p.pointer);
        if (keccak256(data) != p.contentHash) revert FinalityRecoveryManifestBytesInvalid();
    }

    function _utf8(bytes memory data) private pure returns (bool) {
        uint256 i;
        while (i < data.length) {
            uint8 a = uint8(data[i++]);
            if (a < 0x80) continue;
            if (a < 0xc2 || a > 0xf4 || i == data.length) return false;
            uint8 b = uint8(data[i++]);
            if (b < 0x80 || b > 0xbf) return false;
            if (a < 0xe0) continue;
            if ((a == 0xe0 && b < 0xa0) || (a == 0xed && b >= 0xa0) || i == data.length) {
                return false;
            }
            b = uint8(data[i++]);
            if (b < 0x80 || b > 0xbf) return false;
            if (a < 0xf0) continue;
            uint8 second = uint8(data[i - 2]);
            if ((a == 0xf0 && second < 0x90) || (a == 0xf4 && second >= 0x90) || i == data.length) {
                return false;
            }
            b = uint8(data[i++]);
            if (b < 0x80 || b > 0xbf) return false;
        }
        return true;
    }
}
