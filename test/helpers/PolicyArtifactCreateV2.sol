// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface PolicyArtifactVmV2 {
    function getCode(string calldata artifact) external returns (bytes memory);
    function getDeployedCode(string calldata artifact) external returns (bytes memory);
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
    function readFile(string calldata path) external view returns (string memory);
    function parseJsonKeys(string calldata json, string calldata path)
        external
        pure
        returns (string[] memory);
    function parseJson(string calldata json, string calldata path)
        external
        pure
        returns (bytes memory);
}

/// @dev Only the two owned V2 fixtures use this loader. Forge links genuine source:contract
/// artifacts; constructors still run through ordinary CREATE at the original fixture nonce.
/// Frozen runners retain the source/compiler/artifact binding and grant read access to out/.
abstract contract PolicyArtifactCreateV2 {
    struct ImmutableRange {
        uint256 length;
        uint256 start;
    }

    function _policyArtifactCreate(
        string memory artifact,
        string memory path,
        bytes memory arguments,
        uint256 immutableCount
    ) internal returns (address deployed) {
        PolicyArtifactVmV2 cheat = PolicyArtifactVmV2(
            address(uint160(uint256(keccak256("hevm cheat code"))))
        );
        bytes memory creation = cheat.getCode(artifact);
        require(creation.length != 0, "missing genuine creation artifact");
        bytes memory init = bytes.concat(creation, arguments);
        uint64 nonce = cheat.getNonce(address(this));
        address predicted = cheat.computeCreateAddress(address(this), nonce);
        assembly ("memory-safe") {
            deployed := create(0, add(init, 32), mload(init))
            if iszero(deployed) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
        require(
            deployed == predicted && cheat.getNonce(address(this)) == nonce + 1,
            "one original-context CREATE"
        );
        bytes memory expected = cheat.getDeployedCode(artifact);
        bytes memory actual = deployed.code;
        require(actual.length != 0 && actual.length == expected.length, "genuine runtime length");
        string memory json = cheat.readFile(path);
        string[] memory ids = cheat.parseJsonKeys(json, ".deployedBytecode.immutableReferences");
        require(ids.length == immutableCount, "complete immutable declaration inventory");
        bytes memory covered = new bytes(actual.length);
        for (uint256 i; i < ids.length; ++i) {
            ImmutableRange[] memory ranges = abi.decode(
                cheat.parseJson(
                    json, string.concat('.deployedBytecode.immutableReferences["', ids[i], '"]')
                ),
                (ImmutableRange[])
            );
            require(ranges.length != 0, "empty immutable declaration");
            bytes32 first;
            for (uint256 j; j < ranges.length; ++j) {
                uint256 start = ranges[j].start;
                require(
                    ranges[j].length == 32 && start + 32 <= actual.length, "exact immutable range"
                );
                bytes32 value;
                assembly ("memory-safe") { value := mload(add(add(actual, 32), start)) }
                if (j == 0) first = value;
                else require(value == first, "immutable occurrences agree");
                for (uint256 k; k < 32; ++k) {
                    require(
                        covered[start + k] == 0 && expected[start + k] == 0,
                        "closed unpatched immutable template"
                    );
                    covered[start + k] = 0x01;
                    expected[start + k] = actual[start + k];
                }
            }
        }
        // The callers independently assert every constructor immutable through its actual getter.
        require(
            keccak256(actual) == keccak256(expected),
            "all actual runtime bytes match linked artifact"
        );
    }
}
