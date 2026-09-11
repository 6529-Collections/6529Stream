// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface Permit2FixtureVm {
    function readFile(string calldata path) external view returns (string memory);
    function parseJson(string calldata json, string calldata key)
        external
        pure
        returns (bytes memory);
    function parseJsonBytes(string calldata json, string calldata key)
        external
        pure
        returns (bytes memory);
}

/// @dev Exact upstream creation code. Only the two constructor immutable words are patched
///      in the expected runtime; the complete deployed bytes must then match.
abstract contract OfficialPermit2Fixture {
    Permit2FixtureVm private constant permitVm =
        Permit2FixtureVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function deployOfficialPermit2() internal returns (address deployed) {
        string memory json = permitVm.readFile("test/fixtures/permit2/permit2.json");
        bytes memory creation = permitVm.parseJsonBytes(json, ".creationBytecode");
        assembly ("memory-safe") { deployed := create(0, add(creation, 32), mload(creation)) }
        require(deployed != address(0), "official Permit2 deployment");
        bytes memory expected = permitVm.parseJsonBytes(json, ".deployedBytecode");
        uint256[] memory chainOffsets =
            abi.decode(permitVm.parseJson(json, ".chainIdOffsets"), (uint256[]));
        uint256[] memory domainOffsets =
            abi.decode(permitVm.parseJson(json, ".domainOffsets"), (uint256[]));
        require(chainOffsets.length == 1 && domainOffsets.length == 1, "exact immutable inventory");
        _patchPermitWord(expected, chainOffsets[0], bytes32(block.chainid));
        _patchPermitWord(expected, domainOffsets[0], permit2Domain(deployed));
        require(keccak256(deployed.code) == keccak256(expected), "official Permit2 full runtime");
        (bool ok, bytes memory value) =
            deployed.staticcall(abi.encodeWithSignature("DOMAIN_SEPARATOR()"));
        require(
            ok && value.length == 32 && abi.decode(value, (bytes32)) == permit2Domain(deployed),
            "official Permit2 domain"
        );
    }

    function permit2Domain(address deployed) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
                keccak256("Permit2"),
                block.chainid,
                deployed
            )
        );
    }

    function _patchPermitWord(bytes memory data, uint256 offset, bytes32 word) private pure {
        require(offset + 32 <= data.length, "immutable within runtime");
        assembly ("memory-safe") { mstore(add(add(data, 32), offset), word) }
    }
}
