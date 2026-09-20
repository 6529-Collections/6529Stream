// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamSchemaAdmissionPlan as Admission
} from "../../script/current/StreamSchemaAdmissionPlan.sol";
import {
    IStreamSchemaRegistry as S
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";

interface MuseumSourceVm {
    function readFile(string calldata path) external view returns (string memory);
    function parseJsonString(string calldata json, string calldata key)
        external
        pure
        returns (string memory);
    function parseJsonBytes32(string calldata json, string calldata key)
        external
        pure
        returns (bytes32);
    function parseJsonBytes32Array(string calldata json, string calldata key)
        external
        pure
        returns (bytes32[] memory);
    function parseJsonStringArray(string calldata json, string calldata key)
        external
        pure
        returns (string[] memory);
    function parseUint(string calldata value) external pure returns (uint256);
    function toString(uint256 value) external pure returns (string memory);
}

/// @notice Frozen source loader; updating the reviewed artifact requires an explicit hash change.
library StreamMuseumGenesisSource {
    MuseumSourceVm private constant vm =
        MuseumSourceVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 internal constant SOURCE_SHA256 =
        0x34d563faddc07919be05b8ede917b955b0d2430fb7cf1c16273dc1d4ba2aa700;

    function load()
        internal
        view
        returns (Admission.Document[] memory rows, string[] memory paths, bytes32 sourceHash)
    {
        string memory json = vm.readFile("schemas/museum/genesis/admission-plan.json");
        require(
            bytes(json).length == 62014 && sha256(bytes(json)) == SOURCE_SHA256,
            "frozen Museum source plan"
        );
        sourceHash = keccak256(bytes(json));
        rows = new Admission.Document[](51);
        paths = new string[](51);
        uint256 totalBytes;
        uint256 totalChunks;
        for (uint256 i; i < rows.length; ++i) {
            string memory key = string.concat(".documents[", vm.toString(i), "]");
            string memory spec = string.concat(key, ".specification");
            rows[i].specification = S.DocumentSpec(
                _string(json, spec, ".name"),
                S.DocumentKind(_number(json, spec, ".kind")),
                _hash(json, spec, ".contentHash"),
                _hash(json, spec, ".canonicalizationId"),
                _hash(json, spec, ".supersedesId"),
                _string(json, spec, ".uri"),
                uint32(_number(json, spec, ".totalBytes"))
            );
            require(
                keccak256(bytes(rows[i].specification.name)) == _hash(json, key, ".documentId"),
                "exact named identity"
            );
            rows[i].chunkHashes = vm.parseJsonBytes32Array(json, string.concat(key, ".chunkHashes"));
            string[] memory lengths =
                vm.parseJsonStringArray(json, string.concat(key, ".chunkByteLengths"));
            rows[i].chunkLengths = new uint32[](lengths.length);
            for (uint256 j; j < lengths.length; ++j) {
                rows[i].chunkLengths[j] = uint32(vm.parseUint(lengths[j]));
            }
            paths[i] = _string(json, key, ".sourcePath");
            bytes memory raw = bytes(vm.readFile(paths[i]));
            require(
                sha256(raw) == _hash(json, key, ".transportSha256")
                    && raw.length == rows[i].specification.totalBytes
                    && keccak256(raw) == rows[i].specification.contentHash,
                "exact Museum source file"
            );
            totalBytes += raw.length;
            totalChunks += rows[i].chunkHashes.length;
        }
        require(totalBytes == 401717 && totalChunks == 78, "complete frozen source inventory");
    }

    function _string(string memory json, string memory prefix, string memory field)
        private
        pure
        returns (string memory)
    {
        return vm.parseJsonString(json, string.concat(prefix, field));
    }

    function _hash(string memory json, string memory prefix, string memory field)
        private
        pure
        returns (bytes32)
    {
        return vm.parseJsonBytes32(json, string.concat(prefix, field));
    }

    function _number(string memory json, string memory prefix, string memory field)
        private
        pure
        returns (uint256)
    {
        return vm.parseUint(_string(json, prefix, field));
    }
}
