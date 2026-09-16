// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/preservation/StreamArweaveObjectInclusion.sol";

interface NativeObjectVm {
    function readFile(string calldata path) external view returns (string memory);
    function parseJsonString(string calldata json, string calldata key)
        external
        pure
        returns (string memory);
    function parseBytes(string calldata text) external pure returns (bytes memory);
    function parseJsonUint(string calldata json, string calldata key)
        external
        pure
        returns (uint256);
    function toString(uint256 value) external pure returns (string memory);
}

/// @notice Literal upstream chunking vectors, independent of the Solidity implementation.
contract StreamArweaveObjectInclusionTest {
    NativeObjectVm private constant vm =
        NativeObjectVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testAllElevenUpstreamBoundaryRootsAndEndpointPaths() public view {
        string memory json =
            vm.readFile("test/fixtures/preservation/arweave-external-native-v1.json");
        for (uint256 i; i < 11; ++i) {
            string memory prefix = string.concat(".vectors[", vm.toString(i), "]");
            uint256 size = vm.parseJsonUint(json, string.concat(prefix, ".size"));
            bytes32 root = bytes32(_bytes(json, string.concat(prefix, ".dataRoot")));
            uint256 count = size == 1 || size == 4 || size == 262143 || size == 262144
                ? 1
                : size <= 524288 ? 2 : 3;
            // 524289 is balanced into three leaves; 786439 has four nonempty leaves.
            if (size == 524289) count = 3;
            if (size == 786439) count = 4;
            bytes memory first = _bytes(json, string.concat(prefix, ".chunks[0].path"));
            bytes memory last =
                _bytes(json, string.concat(prefix, ".chunks[", vm.toString(count - 1), "].path"));
            A.Checkpoint memory c = _checkpoint(root, uint64(size));
            (bytes32 a, bytes32 b) = this.verify(c, abi.encode(root, size), first, last);
            require(a == bytes32(_bytes(json, string.concat(prefix, ".chunks[0].sha256"))));
            require(
                b
                    == bytes32(
                        _bytes(
                            json,
                            string.concat(prefix, ".chunks[", vm.toString(count - 1), "].sha256")
                        )
                    )
            );
        }
    }

    function testSingleLeafLiteralSHA256BytesAndFullSize() public view {
        bytes32 digest = 0xba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;
        bytes32 root = _leaf(digest, 3);
        A.Checkpoint memory c = _checkpoint(root, 3);
        (bytes32 first, bytes32 last) = this.verify(
            c,
            abi.encode(root, uint256(3)),
            abi.encode(digest, uint256(3)),
            abi.encode(digest, uint256(3))
        );
        require(first == digest && last == digest);
    }

    function testFuzzMutatedNativeRootCannotBorrowOriginalPath(bytes32 root) public {
        bytes32 digest = sha256(bytes("public literal"));
        bytes32 actual = _leaf(digest, 14);
        if (root == actual || root == 0) return;
        A.Checkpoint memory c = _checkpoint(root, 14);
        _fails(
            abi.encodeCall(
                this.verify,
                (
                    c,
                    abi.encode(root, uint256(14)),
                    abi.encode(digest, uint256(14)),
                    abi.encode(digest, uint256(14))
                )
            )
        );
    }

    function testFuzzFixedArrayAndOriginalThreeHashABIHaveIdenticalPreimage(
        bytes32 a,
        bytes32 b,
        bytes32 c
    ) public view {
        A.Checkpoint memory checkpoint = _checkpoint(keccak256("root"), 3);
        bytes32[3] memory hashes = [a, b, c];
        bytes memory original = abi.encode(
            keccak256("domain"),
            block.chainid,
            address(this),
            checkpoint,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            a,
            b,
            c
        );
        bytes memory extracted = abi.encode(
            keccak256("domain"),
            block.chainid,
            address(this),
            checkpoint,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            hashes
        );
        require(keccak256(original) == keccak256(extracted) && original.length == extracted.length);
    }

    function testEmptyAndOversizedLeafRejectBeforeAnyWholeObjectClaim() public {
        bytes32 digest = sha256(bytes("declared bytes"));
        for (uint256 i; i < 2; ++i) {
            uint64 size = i == 0 ? 0 : 262145;
            bytes32 root = _leaf(digest, size);
            A.Checkpoint memory c = _checkpoint(root, size);
            _fails(
                abi.encodeCall(
                    this.verify,
                    (
                        c,
                        abi.encode(root, uint256(size)),
                        abi.encode(digest, uint256(size)),
                        abi.encode(digest, uint256(size))
                    )
                )
            );
        }
    }

    function verify(
        A.Checkpoint calldata c,
        bytes calldata txPath,
        bytes calldata first,
        bytes calldata last
    ) external pure returns (bytes32, bytes32) {
        return StreamArweaveObjectInclusion.verify(c, txPath, first, last);
    }

    function _bytes(string memory json, string memory path) private pure returns (bytes memory) {
        return vm.parseBytes(string.concat("0x", vm.parseJsonString(json, path)));
    }

    function _checkpoint(bytes32 root, uint64 size) private pure returns (A.Checkpoint memory c) {
        c.dataRoot = root;
        c.dataSize = size;
        c.transactionRoot = _leaf(root, size);
        c.transactionEnd = size;
        c.blockDataSize = size;
    }

    function _leaf(bytes32 digest, uint256 end) private pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(abi.encodePacked(digest)), sha256(abi.encode(end))));
    }

    function _fails(bytes memory data) private {
        (bool ok,) = address(this).call(data);
        require(!ok, "expected rejection");
    }
}
