// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamArtistArchiveV2 } from "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

/// @notice Lossless bounded pages for the recovered operation60 evidence envelope.
/// @dev Evidence only. A page or descriptor never authenticates an import or an original record.
///      The Coordinator appends these pages and the canonical operation60 header atomically.
library StreamArtistRecoveredHydrationEvidence {
    uint256 internal constant PAGE_BYTES = 20_480;
    uint256 internal constant MAX_PAGES = 128;
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_EVIDENCE_V1");

    struct Descriptor {
        bytes32 schema;
        bytes32 payloadHash;
        uint256 payloadLength;
        bytes32[] pageHashes;
    }

    error InvalidRecoveredHydrationEvidence();

    function pageId(
        address registry,
        address coordinator,
        bytes32 importCommitment,
        Descriptor memory descriptor,
        uint256 index
    ) public view returns (bytes32) {
        _validate(descriptor);
        if (
            registry == address(0) || coordinator == address(0) || registry == coordinator
                || importCommitment == 0 || index >= descriptor.pageHashes.length
        ) revert InvalidRecoveredHydrationEvidence();
        return keccak256(
            abi.encode(
                SCHEMA,
                block.chainid,
                registry,
                coordinator,
                importCommitment,
                descriptor.payloadHash,
                descriptor.payloadLength,
                descriptor.pageHashes.length,
                index,
                descriptor.pageHashes[index]
            )
        );
    }

    function describe(bytes memory payload) public pure returns (Descriptor memory descriptor) {
        if (payload.length == 0 || payload.length > PAGE_BYTES * MAX_PAGES) {
            revert InvalidRecoveredHydrationEvidence();
        }
        descriptor.schema = SCHEMA;
        descriptor.payloadHash = keccak256(payload);
        descriptor.payloadLength = payload.length;
        descriptor.pageHashes = new bytes32[]((payload.length + PAGE_BYTES - 1) / PAGE_BYTES);
        for (uint256 i; i < descriptor.pageHashes.length; ++i) {
            descriptor.pageHashes[i] = keccak256(_page(payload, i));
        }
    }

    /// @dev Called through the fixed Coordinator's delegate worker, never a caller-selected host.
    function append(
        address archive,
        address registry,
        bytes32 importCommitment,
        bytes memory payload
    ) public returns (Descriptor memory descriptor) {
        IStreamArtistArchiveV2 target = IStreamArtistArchiveV2(archive);
        if (
            target.artistRegistry() != registry || target.operationCoordinator() != address(this)
                || target.artistArchiveMaxEvidenceBytesV2() < PAGE_BYTES
        ) revert InvalidRecoveredHydrationEvidence();
        descriptor = describe(payload);
        for (uint256 i; i < descriptor.pageHashes.length; ++i) {
            bytes32 id = pageId(registry, address(this), importCommitment, descriptor, i);
            (bytes32 hash,, bool added) = target.appendArtistEvidenceV2(id, 1, _page(payload, i));
            if (!added || hash != descriptor.pageHashes[i]) {
                revert InvalidRecoveredHydrationEvidence();
            }
        }
    }

    /// @notice Reconstructs exactly the bytes bound by an already authenticated operation60 header.
    function read(
        address archive,
        address registry,
        address coordinator,
        bytes32 importCommitment,
        Descriptor memory descriptor
    ) public view returns (bytes memory payload) {
        _validate(descriptor);
        IStreamArtistArchiveV2 source = IStreamArtistArchiveV2(archive);
        if (source.artistRegistry() != registry || source.operationCoordinator() != coordinator) {
            revert InvalidRecoveredHydrationEvidence();
        }
        payload = new bytes(descriptor.payloadLength);
        for (uint256 i; i < descriptor.pageHashes.length; ++i) {
            bytes memory part = source.artistEvidenceBytesV2(
                pageId(registry, coordinator, importCommitment, descriptor, i), 1
            );
            uint256 offset = i * PAGE_BYTES;
            uint256 size = descriptor.payloadLength - offset;
            if (size > PAGE_BYTES) size = PAGE_BYTES;
            if (part.length != size || keccak256(part) != descriptor.pageHashes[i]) {
                revert InvalidRecoveredHydrationEvidence();
            }
            _copy(part, 0, payload, offset, size);
        }
        if (keccak256(payload) != descriptor.payloadHash) {
            revert InvalidRecoveredHydrationEvidence();
        }
    }

    function _validate(Descriptor memory descriptor) private pure {
        if (
            descriptor.schema != SCHEMA || descriptor.payloadHash == 0
                || descriptor.payloadLength == 0
                || descriptor.payloadLength > PAGE_BYTES * MAX_PAGES
                || descriptor.pageHashes.length
                    != (descriptor.payloadLength + PAGE_BYTES - 1) / PAGE_BYTES
        ) revert InvalidRecoveredHydrationEvidence();
        for (uint256 i; i < descriptor.pageHashes.length; ++i) {
            if (descriptor.pageHashes[i] == 0) revert InvalidRecoveredHydrationEvidence();
        }
    }

    function _page(bytes memory payload, uint256 index) private pure returns (bytes memory result) {
        uint256 offset = index * PAGE_BYTES;
        uint256 size = payload.length - offset;
        if (size > PAGE_BYTES) size = PAGE_BYTES;
        result = new bytes(size);
        _copy(payload, offset, result, 0, size);
    }

    /// @dev Allocated bytes have word-padded memory. Only the final padded word may be overwritten.
    function _copy(
        bytes memory source,
        uint256 from,
        bytes memory destination,
        uint256 to,
        uint256 size
    ) private pure {
        assembly ("memory-safe") {
            let input := add(add(source, 0x20), from)
            let output := add(add(destination, 0x20), to)
            for { let i := 0 } lt(i, size) { i := add(i, 0x20) } {
                mstore(add(output, i), mload(add(input, i)))
            }
        }
    }
}
