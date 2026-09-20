// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityExtensionDeployment.sol";
import "./StreamArtistEstateExtensionDeployment.sol";
import "./StreamArtistRecoveryExtensionDeployment.sol";
import "./StreamArtistRegistryWriterDeployment.sol";
import "./StreamArtistRegistryExtensionDeployment.sol";
import "./StreamArtistFinalityReadDeployment.sol";
import { StreamArtistIdentityWriterExtension } from "./StreamArtistIdentityWriterExtension.sol";
import { StreamArtistEstateCreationHash } from "./StreamArtistEstateCreationHash.sol";
import { StreamArtistCreationParts } from "./StreamArtistCreationParts.sol";

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

    struct CreationImage {
        address[2] parts;
        bytes32[2] runtimeHashes;
        uint256 length;
        bytes32 imageHash;
    }
    // Constructor-only pins follow the original birth mapping; there is no replacement route.
    mapping(uint8 => CreationImage) private _creationImages;
    error InvalidCreationImage(uint8 kind);
    error InvalidExtensionBirth();
    event ExtensionCreated(
        address indexed child,
        address indexed host,
        uint8 indexed kind,
        bytes32 bindingHash,
        bytes32 runtimeCodeHash
    );

    /// @param parts Identity prefix/tail, then Estate prefix/tail; each starts with STOP.
    constructor(address[4] memory parts) {
        _pin(
            1,
            [parts[0], parts[1]],
            keccak256(type(StreamArtistIdentityWriterExtension).creationCode)
        );
        _pin(2, [parts[2], parts[3]], StreamArtistEstateCreationHash.expected());
    }

    function creationImage(uint8 kind) external view returns (CreationImage memory) {
        if (kind != 1 && kind != 2) revert InvalidCreationImage(kind);
        return _creationImages[kind];
    }

    function extensionCreationCode(uint8 kind) external view returns (bytes memory creation) {
        CreationImage memory image = _creationImages[kind];
        if (image.imageHash == bytes32(0)) revert InvalidCreationImage(kind);
        for (uint256 i; i < 2; ++i) {
            if (image.parts[i].codehash != image.runtimeHashes[i]) {
                revert InvalidCreationImage(kind);
            }
        }
        creation = _image(kind, image.parts);
        if (creation.length != image.length || keccak256(creation) != image.imageHash) {
            revert InvalidCreationImage(kind);
        }
    }

    function _pin(uint8 kind, address[2] memory parts, bytes32 expected) private {
        bytes memory creation = _image(kind, parts);
        if (keccak256(creation) != expected || creation.length + 192 > 49_152) {
            revert InvalidCreationImage(kind);
        }
        _creationImages[kind] = CreationImage(
            parts, [parts[0].codehash, parts[1].codehash], creation.length, expected
        );
    }

    function _image(uint8 kind, address[2] memory parts)
        private
        view
        returns (bytes memory creation)
    {
        uint256 first = parts[0].code.length;
        uint256 second = parts[1].code.length;
        if (
            first != StreamArtistCreationParts.SPLIT + 1 || second <= 1
                || second > StreamArtistCreationParts.SPLIT + 1
        ) revert InvalidCreationImage(kind);
        uint256 prefix0;
        uint256 prefix1;
        assembly ("memory-safe") {
            extcodecopy(mload(parts), 0, 0, 1)
            prefix0 := byte(0, mload(0))
            extcodecopy(mload(add(parts, 32)), 0, 0, 1)
            prefix1 := byte(0, mload(0))
        }
        if (prefix0 != 0 || prefix1 != 0) revert InvalidCreationImage(kind);
        creation = new bytes(first + second - 2);
        assembly ("memory-safe") {
            extcodecopy(mload(parts), add(creation, 32), 1, sub(first, 1))
            extcodecopy(
                mload(add(parts, 32)),
                add(add(creation, 32), sub(first, 1)),
                1,
                sub(second, 1)
            )
        }
    }

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
