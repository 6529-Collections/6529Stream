// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/Strings.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";
import "./helpers/StreamFixture.sol";

contract StreamMetadataEncodingTest is CharacterizationTestBase, StreamFixture {
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for string;
    using Strings for uint256;

    bytes32 private constant DEPENDENCY_SCRIPT_CONTENT_TYPEHASH = keccak256(
        "6529StreamDependencyScript(bytes32 dependencyNameAndVersion,uint256 chunkCount,bytes32 chunksHash)"
    );
    bytes32 private constant DEPENDENCY_SCRIPT_CHUNK_TYPEHASH = keccak256(
        "6529StreamDependencyScriptChunk(uint256 index,bytes32 chunkHash,uint256 byteLength)"
    );

    function testDependencyScriptHashSeparatesAmbiguousChunkBoundaries() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        bytes32 dependencyKey = bytes32(0);
        uint256 tokenId = 10_000_000_000;
        string[] memory firstChunks = new string[](2);
        firstChunks[0] = "ab";
        firstChunks[1] = "c";
        string[] memory secondChunks = new string[](2);
        secondChunks[0] = "a";
        secondChunks[1] = "bc";

        deployed.dependencyRegistry.addDependency(dependencyKey, firstChunks);

        vm.prank(address(deployed.minter));
        deployed.core.mint(tokenId, address(0xA11CE), "1,2,3", 7, 1);

        string memory firstRenderedScript = deployed.core.retrieveGenerativeScript(tokenId);
        bytes32 firstContentHash = deployed.core.retrieveDependencyScriptContentHash(tokenId);
        firstRenderedScript.assertEq(
            _expectedGenerativeScript(
                tokenId, keccak256(abi.encode(uint256(1), tokenId, uint256(7))), "abc"
            ),
            "first rendered script"
        );
        firstContentHash.assertEq(_contentHash(dependencyKey, firstChunks), "first content hash");

        deployed.dependencyRegistry.addDependency(dependencyKey, secondChunks);

        deployed.core.retrieveGenerativeScript(tokenId)
            .assertEq(firstRenderedScript, "rendered script compatibility changed");
        bytes32 secondContentHash = deployed.core.retrieveDependencyScriptContentHash(tokenId);
        secondContentHash.assertEq(_contentHash(dependencyKey, secondChunks), "second content hash");
        (firstContentHash == secondContentHash)
        .assertFalse("ambiguous dependency chunks shared hash");
    }

    function testDependencyChunkHashIncludesIndexAndLength() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        bytes32 dependencyKey = keccak256("empty-chunks");
        string[] memory chunks = new string[](2);
        chunks[0] = "";
        chunks[1] = "";

        deployed.dependencyRegistry.addDependency(dependencyKey, chunks);

        bytes32 firstChunkHash =
            deployed.dependencyRegistry.getDependencyScriptChunkHash(dependencyKey, 0);
        bytes32 secondChunkHash =
            deployed.dependencyRegistry.getDependencyScriptChunkHash(dependencyKey, 1);
        firstChunkHash.assertEq(_chunkHash(0, chunks[0]), "first empty chunk hash");
        secondChunkHash.assertEq(_chunkHash(1, chunks[1]), "second empty chunk hash");
        (firstChunkHash == secondChunkHash).assertFalse("empty chunks shared hash");
    }

    function testEmptyDependencyContentHashIsDeterministic() public {
        DeployedStream memory deployed = deployStream(address(0xBEEF), address(0xCAFE));
        bytes32 dependencyKey = keccak256("zero-chunk-dependency");
        string[] memory chunks = new string[](0);

        deployed.dependencyRegistry.addDependency(dependencyKey, chunks);

        deployed.dependencyRegistry.getDependencyScriptContentHash(dependencyKey)
            .assertEq(_contentHash(dependencyKey, chunks), "zero chunk content hash");
    }

    function _contentHash(bytes32 dependencyKey, string[] memory chunks)
        private
        pure
        returns (bytes32)
    {
        bytes32 chunksHash = bytes32(0);

        for (uint256 i = 0; i < chunks.length; i++) {
            chunksHash = keccak256(abi.encode(chunksHash, _chunkHash(i, chunks[i])));
        }

        return keccak256(
            abi.encode(DEPENDENCY_SCRIPT_CONTENT_TYPEHASH, dependencyKey, chunks.length, chunksHash)
        );
    }

    function _chunkHash(uint256 index, string memory chunk) private pure returns (bytes32) {
        bytes memory chunkBytes = bytes(chunk);
        return keccak256(
            abi.encode(
                DEPENDENCY_SCRIPT_CHUNK_TYPEHASH, index, keccak256(chunkBytes), chunkBytes.length
            )
        );
    }

    function _expectedGenerativeScript(uint256 tokenId, bytes32 tokenHash, string memory dependency)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            "let hash='",
            Strings.toHexString(uint256(tokenHash), 32),
            "';let tokenId=",
            tokenId.toString(),
            ";let tokenData=[1,2,3]",
            ";let dependencyScript='",
            dependency,
            "';",
            "function draw(){}"
        );
    }
}
