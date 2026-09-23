// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistHistory,
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Exact bounded reads and original double-hashed sorted-pair AA-IMPORT proofs.
library StreamArtistHistoryProof {
    error InvalidArtistHistory();
    error ArtistHistoryReadFailed(address target);

    function cap(address registry) public view returns (uint256 value) {
        uint8 failure;
        uint64 revision;
        (value,, failure, revision) = IStreamGasParameterHost(registry)
            .gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS"));
        if (value == 0 || value == type(uint256).max || failure != 2 || revision == 0) {
            revert InvalidArtistHistory();
        }
    }

    function fixedRead(address target, bytes memory input, uint256 length, uint256 gasCap)
        public
        view
        returns (bytes memory output)
    {
        output = new bytes(length);
        uint256 available = gasleft();
        if (
            available <= 105000 || target.code.length == 0 || gasCap == 0
                || gasCap == type(uint256).max
        ) revert ArtistHistoryReadFailed(target);
        uint256 forwarded = available - 105000;
        if (forwarded > gasCap) forwarded = gasCap;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(
                forwarded,
                target,
                add(input, 32),
                mload(input),
                add(output, 32),
                length
            )
            size := returndatasize()
        }
        if (!ok || size != length) revert ArtistHistoryReadFailed(target);
    }

    function pointer(address core, uint256 gasCap)
        public
        view
        returns (address target, bytes32 hash)
    {
        bytes memory raw = fixedRead(
            core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("ARTIST_REGISTRY"))),
            320,
            gasCap
        );
        (
            address a,
            bytes32 b,
            bool c,
            bytes32 d,
            bytes4 e,
            address f,
            uint8 g,
            bytes32 h,
            bytes32 i,
            uint64 j
        ) = abi.decode(
            raw, (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (
            keccak256(raw) != keccak256(abi.encode(a, b, c, d, e, f, g, h, i, j)) || a == address(0)
                || a.codehash != b || b == 0 || j == 0
        ) revert InvalidArtistHistory();
        return (a, b);
    }

    function predecessor(
        address core,
        address registry,
        address source,
        bytes32 expected,
        uint256 gasCap
    ) public view {
        if (
            source == address(0) || source == registry || source.code.length == 0
                || source.codehash != expected
        ) revert InvalidArtistHistory();
        if (
            abi.decode(fixedRead(source, abi.encodeWithSignature("core()"), 32, gasCap), (address))
                != core
        ) revert InvalidArtistHistory();
        if (
            !abi.decode(
                    fixedRead(
                        source,
                        abi.encodeWithSignature(
                            "supportsInterface(bytes4)", type(IStreamArtistHistory).interfaceId
                        ),
                        32,
                        gasCap
                    ),
                    (bool)
                )
                || abi.decode(
                    fixedRead(
                        source,
                        abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0xffffffff)),
                        32,
                        gasCap
                    ),
                    (bool)
                )
        ) revert InvalidArtistHistory();
    }

    function lane(address source, uint8 kind, bytes32 key, uint256 gasCap)
        public
        view
        returns (bytes32 tip, uint64 count)
    {
        validLane(kind, key);
        bytes memory raw = fixedRead(
            source, abi.encodeCall(IStreamArtistHistory.artistHistoryLane, (kind, key)), 64, gasCap
        );
        (tip, count) = abi.decode(raw, (bytes32, uint64));
        if ((tip == 0) != (count == 0) || keccak256(raw) != keccak256(abi.encode(tip, count))) {
            revert InvalidArtistHistory();
        }
        bytes memory data = kind == 1
            ? abi.encodeCall(IStreamArtistHistory.artistRecordChainHash, (key))
            : abi.encodeCall(IStreamArtistHistory.collectionRecordChainHash, (uint256(key)));
        if (abi.decode(fixedRead(source, data, 32, gasCap), (bytes32)) != tip) {
            revert InvalidArtistHistory();
        }
    }

    function leaf(address source, H.Leaf memory p) public view returns (bytes32) {
        validLane(p.laneKind, p.laneKey);
        if (p.recordHash == 0 || p.recordChainHash == 0) revert InvalidArtistHistory();
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        bytes32(0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d),
                        block.chainid,
                        source,
                        p.laneKind,
                        p.laneKey,
                        p.sequence,
                        p.recordHash,
                        p.recordChainHash
                    )
                )
            )
        );
    }

    function verify(bytes32 root, address source, H.Leaf memory p, bytes32[] memory proof)
        public
        view
        returns (bool)
    {
        if (root == 0 || proof.length > 64) revert InvalidArtistHistory();
        bytes32 h = leaf(source, p);
        for (uint256 i; i < proof.length; ++i) {
            h = h < proof[i]
                ? keccak256(abi.encode(h, proof[i]))
                : keccak256(abi.encode(proof[i], h));
        }
        return h == root;
    }

    function validLane(uint8 kind, bytes32 key) public pure {
        if ((kind != 1 && kind != 2) || key == 0) revert InvalidArtistHistory();
    }
}
