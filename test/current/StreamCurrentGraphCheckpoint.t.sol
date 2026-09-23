// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentGraphCheckpoint
} from "../../script/current/StreamCurrentGraphCheckpoint.sol";
import {
    StreamSchemaDocumentStore
} from "../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";

interface CheckpointTestVm {
    function expectRevert(bytes4) external;
}

contract OtherCheckpointOperator {
    function create(address[] memory chunks, bytes32 hash, uint256 size)
        external
        returns (StreamCurrentGraphCheckpoint)
    {
        return new StreamCurrentGraphCheckpoint(chunks, hash, size);
    }
}

/// @notice Checkpoint byte retention and provenance only; the full constructor graph is separate.
contract StreamCurrentGraphCheckpointTest {
    CheckpointTestVm private constant vm =
        CheckpointTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testActualMultiChunkCheckpointRetainsExactBytesAndOperator() public {
        StreamSchemaDocumentStore store = new StreamSchemaDocumentStore();
        bytes memory first = new bytes(8192);
        bytes memory last = new bytes(731);
        for (uint256 i; i < first.length; ++i) {
            first[i] = bytes1(uint8(i));
        }
        for (uint256 i; i < last.length; ++i) {
            last[i] = bytes1(uint8(255 - (i % 256)));
        }
        address[] memory parts = new address[](2);
        (, parts[0]) = store.publishChunk(first);
        (, parts[1]) = store.publishChunk(last);
        bytes memory raw = bytes.concat(first, last);
        StreamCurrentGraphCheckpoint record =
            new StreamCurrentGraphCheckpoint(parts, keccak256(raw), raw.length);
        require(
            record.operator() == address(this) && record.deploymentChainId() == block.chainid,
            "original creator domain"
        );
        require(
            record.SCHEMA_VERSION() == 3 && record.payloadBytes() == raw.length,
            "explicit checkpoint schema"
        );
        require(
            keccak256(record.payload()) == keccak256(raw) && record.payloadHash() == keccak256(raw),
            "full original byte equality"
        );
        require(
            address(record).codehash == keccak256(type(StreamCurrentGraphCheckpoint).runtimeCode),
            "portable exact runtime identity"
        );
        (address[] memory retained, bytes32[] memory hashes) = record.chunks();
        require(retained.length == 2 && hashes.length == 2, "exact original chunks");
        for (uint256 i; i < 2; ++i) {
            require(
                retained[i] == parts[i] && hashes[i] == parts[i].codehash, "original chunk pins"
            );
        }
    }

    function testCheckpointRejectsWrongHashAndLengthWithHealthyRetry() public {
        StreamSchemaDocumentStore store = new StreamSchemaDocumentStore();
        bytes memory raw = bytes("original saved operator deployment");
        address[] memory parts = new address[](1);
        (, parts[0]) = store.publishChunk(raw);
        vm.expectRevert(StreamCurrentGraphCheckpoint.InvalidCheckpoint.selector);
        new StreamCurrentGraphCheckpoint(parts, keccak256("substitution"), raw.length);
        vm.expectRevert(StreamCurrentGraphCheckpoint.InvalidCheckpoint.selector);
        new StreamCurrentGraphCheckpoint(parts, keccak256(raw), raw.length + 1);
        StreamCurrentGraphCheckpoint retry =
            new StreamCurrentGraphCheckpoint(parts, keccak256(raw), raw.length);
        require(keccak256(retry.payload()) == keccak256(raw), "identical valid retry");
    }

    function testCheckpointRecordsActualCreatorWithoutConferringProtocolAuthority() public {
        StreamSchemaDocumentStore store = new StreamSchemaDocumentStore();
        address[] memory parts = new address[](1);
        bytes memory raw = bytes("public byte retention has no Stream authority");
        (, parts[0]) = store.publishChunk(raw);
        OtherCheckpointOperator creator = new OtherCheckpointOperator();
        StreamCurrentGraphCheckpoint record = creator.create(parts, keccak256(raw), raw.length);
        require(
            record.operator() == address(creator) && record.operator() != address(this),
            "actual constructor sender"
        );
    }

    function testCheckpointRejectsMissingChunksAndOversizedPayloadDeclaration() public {
        address[] memory absent = new address[](0);
        vm.expectRevert(StreamCurrentGraphCheckpoint.InvalidCheckpoint.selector);
        new StreamCurrentGraphCheckpoint(absent, keccak256("empty"), 1);
        address[] memory nonCode = new address[](1);
        nonCode[0] = address(0x1234);
        vm.expectRevert(StreamCurrentGraphCheckpoint.InvalidCheckpoint.selector);
        new StreamCurrentGraphCheckpoint(nonCode, keccak256("not retained"), 1);
        vm.expectRevert(StreamCurrentGraphCheckpoint.InvalidCheckpoint.selector);
        new StreamCurrentGraphCheckpoint(nonCode, keccak256("too large"), 524289);
    }
}
