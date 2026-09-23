// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRecordJson.sol";
import "./StreamConservationDefinitions.sol";
import "../../interfaces/stream/metadata/StreamConservationRecordTypes.sol";

/// @notice Closed conservation fields; references are commitments, never verified external facts.
library StreamConservationRecordFields {
    error InvalidConservationWitness();

    function referenceJSON(StreamConservationRecordTypes.Reference memory r)
        public
        pure
        returns (string memory)
    {
        if (r.canonicalizationId == 0 || r.algorithm == 0 || r.algorithm > 6) {
            revert InvalidConservationWitness();
        }
        if (r.algorithm == 4 || r.algorithm == 5) {
            if (r.digest.length == 0 || r.digest.length > 128) revert InvalidConservationWitness();
        } else if (r.digest.length != 32) {
            revert InvalidConservationWitness();
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "CONSERVATION_REFERENCE", r.uri, 2048, false
        );
        return string.concat(
            '{"hash":{"algorithm":',
            string(abi.encodePacked(bytes1(uint8(48 + r.algorithm)))),
            ',"canonicalizationId":',
            StreamRecordJson.hexValue(r.canonicalizationId),
            ',"digest":',
            _hexBytes(r.digest),
            '},"uri":',
            StreamRecordJson.quote(r.uri, 2048, false),
            "}"
        );
    }

    function requireEmptyReference(StreamConservationRecordTypes.Reference memory r) public pure {
        if (
            r.algorithm != 0 || r.canonicalizationId != 0 || r.digest.length != 0
                || bytes(r.uri).length != 0
        ) {
            revert InvalidConservationWitness();
        }
    }

    function requireHeader(bytes32 subjectId, bytes32 profileHash, bytes32 expectedProfile)
        public
        pure
    {
        if (subjectId == 0 || profileHash != expectedProfile) {
            revert InvalidConservationWitness();
        }
    }

    function artistJSON(StreamConservationRecordTypes.ArtistClaim memory a)
        public
        pure
        returns (string memory)
    {
        if (a.artistId == 0 || a.bindingGeneration == 0 || a.bindingHash == 0) {
            revert InvalidConservationWitness();
        }
        return string.concat(
            '{"artistId":',
            StreamRecordJson.hexValue(a.artistId),
            ',"bindingGeneration":',
            StreamRecordJson.unsigned(a.bindingGeneration),
            ',"bindingHash":',
            StreamRecordJson.hexValue(a.bindingHash),
            ',"statementOrigin":',
            a.origin == StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
                ? '"artist_intent"'
                : '"estate_statement"',
            "}"
        );
    }

    function interviewJSON(StreamConservationRecordTypes.InterviewEntry memory e)
        public
        pure
        returns (string memory)
    {
        StreamConservationRecordTypes.InterviewRecord memory r = e.record;
        if (e.status == StreamConservationRecordTypes.InterviewStatus.PRESENT) {
            requireEmptyReference(e.waiverStatement);
            if (
                r.chainId == 0 || r.core == address(0) || r.host == address(0) || r.recordHash == 0
                    || r.schemaId != StreamConservationDefinitions.INTERVIEW_SCHEMA_ID
                    || r.profileHash != StreamConservationDefinitions.INTERVIEW_PROFILE_HASH
            ) revert InvalidConservationWitness();
            string memory locator = string.concat(
                '{"chainId":',
                StreamRecordJson.unsigned(r.chainId),
                ',"core":',
                StreamRecordJson.account(r.core),
                ',"host":',
                StreamRecordJson.account(r.host),
                ',"profileHash":',
                StreamRecordJson.hexValue(r.profileHash),
                ',"recordHash":',
                StreamRecordJson.hexValue(r.recordHash),
                ',"schemaId":',
                StreamRecordJson.hexValue(r.schemaId),
                "}"
            );
            return string.concat(
                '{"kind":"present","payload":', referenceJSON(r.payload), ',"record":', locator, "}"
            );
        }
        if (
            r.chainId != 0 || r.core != address(0) || r.host != address(0) || r.recordHash != 0
                || r.schemaId != 0 || r.profileHash != 0
        ) revert InvalidConservationWitness();
        requireEmptyReference(r.payload);
        return string.concat(
            '{"kind":"interview_waived","statement":', referenceJSON(e.waiverStatement), "}"
        );
    }

    /// @notice Preserve every row and its order with one bounded output allocation.
    function arrayJSON(bytes[] memory rows) public pure returns (string memory) {
        uint256 size = 2;
        for (uint256 i; i < rows.length; ++i) {
            size += rows[i].length + (i == 0 ? 0 : 1);
            if (size > 8192) revert InvalidConservationWitness();
        }
        bytes memory out = new bytes(size);
        out[0] = "[";
        uint256 offset = 1;
        for (uint256 i; i < rows.length; ++i) {
            if (i != 0) out[offset++] = ",";
            _copyRow(rows[i], out, offset);
            offset += rows[i].length;
        }
        out[offset] = "]";
        return string(out);
    }

    function requirePayloadSize(bytes memory value) public pure returns (bytes memory) {
        if (value.length == 0 || value.length > 8192) revert InvalidConservationWitness();
        return value;
    }

    function _hexBytes(bytes memory input) private pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory out = new bytes(4 + input.length * 2);
        out[0] = '"';
        out[1] = "0";
        out[2] = "x";
        out[out.length - 1] = '"';
        for (uint256 i; i < input.length; ++i) {
            out[3 + i * 2] = alphabet[uint8(input[i]) >> 4];
            out[4 + i * 2] = alphabet[uint8(input[i]) & 15];
        }
        return string(out);
    }

    function _copyRow(bytes memory row, bytes memory out, uint256 offset) private pure {
        assembly ("memory-safe") {
            let size := mload(row)
            let source := add(row, 32)
            let target := add(add(out, 32), offset)
            let cursor := 0
            for { } iszero(gt(add(cursor, 32), size)) { cursor := add(cursor, 32) } {
                mstore(add(target, cursor), mload(add(source, cursor)))
            }
            if lt(cursor, size) {
                let tail := mload(add(source, cursor))
                let index := 0
                for { } lt(cursor, size) {
                    cursor := add(cursor, 1)
                    index := add(index, 1)
                } { mstore8(add(target, cursor), byte(index, tail)) }
            }
        }
    }
}
