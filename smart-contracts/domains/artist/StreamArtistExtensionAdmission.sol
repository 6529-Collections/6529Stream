// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistExtensionFactory.sol";
import { StreamArtistExtensionFactoryRuntime } from "./StreamArtistExtensionFactoryRuntime.sol";

/// @notice Constructor-only authentication of the compiler-linked factory and its original CREATE receipts.
library StreamArtistExtensionAdmission {
    bytes32 private constant DOMAIN = keccak256("6529STREAM_ARTIST_EXTENSION_BIRTH_V1");
    error InvalidExtensionBinding(address child);

    function identity(address factory, address[3] memory children, address[6] memory pins)
        internal
        view
    {
        _factory(factory);
        for (uint8 i; i < 3; ++i) {
            uint8 kind = i + 1;
            _require(
                factory,
                children[i],
                pins[0],
                kind,
                keccak256(abi.encode(DOMAIN, block.chainid, kind, pins))
            );
        }
    }

    function registry(
        address factory,
        address[3] memory children,
        address host,
        address coordinator
    ) internal view {
        _factory(factory);
        for (uint8 i; i < 3; ++i) {
            uint8 kind = i + 4;
            _require(
                factory,
                children[i],
                host,
                kind,
                keccak256(abi.encode(DOMAIN, block.chainid, kind, host, coordinator))
            );
        }
    }

    function _factory(address factory) private view {
        if (factory.codehash != StreamArtistExtensionFactoryRuntime.expected()) {
            revert InvalidExtensionBinding(factory);
        }
    }

    function _require(address factory, address child, address host, uint8 kind, bytes32 bindingHash)
        private
        view
    {
        StreamArtistExtensionFactory.Birth memory b =
            StreamArtistExtensionFactory(factory).birth(child);
        if (
            child.code.length == 0 || b.kind != kind || b.host != host || b.chainId != block.chainid
                || b.bindingHash != bindingHash || b.runtimeCodeHash != child.codehash
        ) revert InvalidExtensionBinding(child);
    }
}
