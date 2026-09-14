// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityExtensionDeployment.sol";
import "./StreamArtistEstateExtensionDeployment.sol";
import "./StreamArtistRecoveryExtensionDeployment.sol";
import "./StreamArtistRegistryWriterDeployment.sol";
import "./StreamArtistRegistryExtensionDeployment.sol";
import "./StreamArtistFinalityReadDeployment.sol";

/// @notice Permissionless fixed-code creation of immutable Artist extensions.
/// @dev Receipts authenticate actual typed CREATEs; no host-wide reservation or mutable route exists.
contract StreamArtistExtensionFactory {
    struct Birth {
        uint8 kind;
        address host;
        uint256 chainId;
        bytes32 bindingHash;
        bytes32 runtimeCodeHash;
    }
    bytes32 private constant DOMAIN = keccak256("6529STREAM_ARTIST_EXTENSION_BIRTH_V1");
    mapping(address => Birth) private _births;
    error InvalidExtensionBirth();
    event ExtensionCreated(
        address indexed child,
        address indexed host,
        uint8 indexed kind,
        bytes32 bindingHash,
        bytes32 runtimeCodeHash
    );

    function birth(address child) external view returns (Birth memory) {
        return _births[child];
    }

    function identityBinding(uint8 kind, address[6] memory pins) public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN, block.chainid, kind, pins));
    }

    function registryBinding(uint8 kind, address host, address coordinator)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(DOMAIN, block.chainid, kind, host, coordinator));
    }

    /// @param pins Ordered future host, Registry, Coordinator, Archive, Core and Manager.
    function deployIdentity(uint8 kind, address[6] calldata pins) external returns (address child) {
        if (kind == 1) {
            child = StreamArtistIdentityExtensionDeployment.deployWriter(
                pins[0], pins[1], pins[2], pins[3], pins[4], pins[5]
            );
        } else if (kind == 2) {
            child = StreamArtistEstateExtensionDeployment.deployEstateWriter(
                pins[0], pins[1], pins[2], pins[3], pins[4], pins[5]
            );
        } else if (kind == 3) {
            child = StreamArtistRecoveryExtensionDeployment.deployRecoveryWriter(
                pins[0], pins[1], pins[2], pins[3], pins[4], pins[5]
            );
        } else {
            revert InvalidExtensionBirth();
        }
        _record(child, kind, pins[0], identityBinding(kind, pins));
    }

    function deployRegistry(uint8 kind, address host, address coordinator)
        external
        returns (address child)
    {
        if (kind == 4) {
            child = StreamArtistRegistryWriterDeployment.deployWriter(host, coordinator);
        } else if (kind == 5) {
            child = StreamArtistRegistryExtensionDeployment.deployReader(host, coordinator);
        } else if (kind == 6) {
            child = StreamArtistFinalityReadDeployment.deployReader(host, coordinator);
        } else {
            revert InvalidExtensionBirth();
        }
        _record(child, kind, host, registryBinding(kind, host, coordinator));
    }

    function _record(address child, uint8 kind, address host, bytes32 bindingHash) private {
        if (child.code.length == 0 || child.code.length > 24_576 || _births[child].kind != 0) {
            revert InvalidExtensionBirth();
        }
        bytes32 runtime = child.codehash;
        _births[child] = Birth(kind, host, block.chainid, bindingHash, runtime);
        emit ExtensionCreated(child, host, kind, bindingHash, runtime);
    }
}
