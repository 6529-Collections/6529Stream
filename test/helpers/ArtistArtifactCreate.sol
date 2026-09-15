// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ArtistArtifactVm {
    function getCode(string calldata artifact) external returns (bytes memory);
}

/// @dev Test-only artifact loading. Forge links the exact compiled production artifact
/// before this helper executes normal CREATE in the original fixture caller context.
/// Use source:contract names, not physical unlinked JSON files. Constructors, values,
/// nonce order and production factory checks remain on the ordinary EVM path.
abstract contract ArtistArtifactCreate {
    function _artistArtifactCreate(string memory artifact, bytes memory arguments)
        internal
        returns (address deployed)
    {
        ArtistArtifactVm vm =
            ArtistArtifactVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        bytes memory creation = vm.getCode(artifact);
        require(creation.length != 0, "missing production creation artifact");
        bytes memory init = bytes.concat(creation, arguments);
        assembly ("memory-safe") {
            deployed := create(0, add(init, 32), mload(init))
            if iszero(deployed) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }
}
