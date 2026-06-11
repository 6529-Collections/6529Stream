// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/DependencyRegistry.sol";
import "../smart-contracts/StreamMetadataRenderer.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";

contract StreamMetadataUtf8Test is CharacterizationTestBase, StreamFixture {
    using Assertions for bool;
    using Assertions for string;

    bytes32 private constant DEPENDENCY_SCRIPT_FIELD = "dependency.script";
    bytes32 private constant DEPENDENCY_PROVENANCE_FIELD = "dependency.provenance";

    function testRendererAcceptsValidAsciiAndMultibyteUtf8() public pure {
        StreamMetadataRenderer.isValidUtf8("").assertTrue("empty rejected");
        StreamMetadataRenderer.isValidUtf8("plain ascii").assertTrue("ascii rejected");
        StreamMetadataRenderer.isValidUtf8(_raw(bytes.concat(bytes1(0xc2), bytes1(0xa9))))
            .assertTrue("two-byte utf8 rejected");
        StreamMetadataRenderer.isValidUtf8(
                _raw(bytes.concat(bytes1(0xe2), bytes1(0x98), bytes1(0x83)))
            ).assertTrue("three-byte utf8 rejected");
        StreamMetadataRenderer.isValidUtf8(
                _raw(bytes.concat(bytes1(0xf0), bytes1(0x9f), bytes1(0x8c), bytes1(0x80)))
            ).assertTrue("four-byte utf8 rejected");
    }

    function testRendererRejectsInvalidUtf8Sequences() public pure {
        _assertInvalid(bytes.concat(bytes1(0x80)), "lone continuation accepted");
        _assertInvalid(bytes.concat(bytes1(0xc0), bytes1(0xaf)), "overlong two-byte accepted");
        _assertInvalid(
            bytes.concat(bytes1(0xe2), bytes1(0x28), bytes1(0xa1)), "bad continuation accepted"
        );
        _assertInvalid(bytes.concat(bytes1(0xed), bytes1(0xa0), bytes1(0x80)), "surrogate accepted");
        _assertInvalid(
            bytes.concat(bytes1(0xf4), bytes1(0x90), bytes1(0x80), bytes1(0x80)),
            "out-of-range code point accepted"
        );
        _assertInvalid(
            bytes.concat(bytes1(0xf0), bytes1(0x90), bytes1(0x80)), "truncated sequence accepted"
        );
    }

    function testDependencyRegistryAcceptsValidMultibyteUtf8Metadata() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        bytes32 dependencyKey = keccak256("utf8-valid-library");
        string[] memory chunks = new string[](1);
        chunks[0] = string.concat(
            "const label = '", _raw(bytes.concat(bytes1(0xe2), bytes1(0x98), bytes1(0x83))), "';"
        );
        string memory provenance =
            string.concat("created by ", _raw(bytes.concat(bytes1(0xc2), bytes1(0xa9))));

        deployed.dependencyRegistry.addDependencyWithProvenance(dependencyKey, chunks, provenance);

        deployed.dependencyRegistry.getDependencyScript(dependencyKey, 0)
            .assertEq(chunks[0], "valid utf8 script not stored");
        deployed.dependencyRegistry.getDependencyVersionProvenance(dependencyKey, 1)
            .assertEq(provenance, "valid utf8 provenance not stored");
    }

    function testDependencyRegistryRejectsInvalidUtf8ScriptChunk() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        string[] memory chunks = new string[](1);
        chunks[0] = _raw(bytes.concat(bytes1(0xc0), bytes1(0xaf)));

        vm.expectRevert(
            abi.encodeWithSelector(
                DependencyRegistry.DependencyFieldInvalidUTF8.selector, DEPENDENCY_SCRIPT_FIELD
            )
        );
        deployed.dependencyRegistry.addDependency(keccak256("utf8-invalid-script"), chunks);
    }

    function testDependencyRegistryRejectsInvalidUtf8Provenance() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        string[] memory chunks = new string[](1);
        chunks[0] = "function draw(){}";

        vm.expectRevert(
            abi.encodeWithSelector(
                DependencyRegistry.DependencyFieldInvalidUTF8.selector, DEPENDENCY_PROVENANCE_FIELD
            )
        );
        deployed.dependencyRegistry
            .addDependencyWithProvenance(
                keccak256("utf8-invalid-provenance"), chunks, _raw(bytes.concat(bytes1(0x80)))
            );
    }

    function testDependencyRegistryReportsSizeBeforeUtf8Validity() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        uint256 maximum = deployed.dependencyRegistry.MAX_DEPENDENCY_SCRIPT_CHUNK_BYTES();
        string[] memory chunks = new string[](1);
        chunks[0] = _oversizedInvalidUtf8(maximum + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                DependencyRegistry.DependencyFieldTooLarge.selector,
                DEPENDENCY_SCRIPT_FIELD,
                maximum + 1,
                maximum
            )
        );
        deployed.dependencyRegistry.addDependency(keccak256("utf8-oversized-script"), chunks);
    }

    function _assertInvalid(bytes memory raw, string memory message) private pure {
        StreamMetadataRenderer.isValidUtf8(_raw(raw)).assertFalse(message);
    }

    function _raw(bytes memory rawBytes) private pure returns (string memory) {
        return string(rawBytes);
    }

    function _oversizedInvalidUtf8(uint256 size) private pure returns (string memory) {
        bytes memory rawBytes = new bytes(size);
        for (uint256 i = 0; i < size; i++) {
            rawBytes[i] = 0x61;
        }
        rawBytes[size - 1] = 0x80;
        return string(rawBytes);
    }
}
