// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    IStreamReferenceModePayloadPreparation as P
} from "../../interfaces/stream/preservation/IStreamReferenceModePayloadPreparation.sol";

/// @notice Original payload ABI assembled from already authenticated canonical tuple encodings.
library StreamReferenceModePayloadEncoding {
    struct Components {
        bytes32 publicationHash;
        uint32 publicationBytes;
        bytes32 receiptHash;
        uint32 receiptBytes;
        bytes32 sourceHash;
        uint32 sourceBytes;
        bytes32 evidenceHash;
        uint32 evidenceBytes;
        bytes32 factsHash;
        uint32 factsBytes;
        bytes32 environmentHash;
        uint32 environmentBytes;
    }

    function normalize(R.Receipt memory r) internal pure {
        r.recordHash = 0;
        r.recordChainHash = 0;
        r.payloadHash = 0;
        r.payloadBytes = 0;
        r.recordedAt = 0;
    }

    function publicationId(bytes32 hash, uint32 size) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_PUBLICATION_PREPARATION_V1"),
                block.chainid,
                address(this),
                hash,
                size
            )
        );
    }

    function components(
        P.PublicationDescriptor memory p,
        bytes memory receipt,
        bytes memory source,
        bytes memory evidence,
        bytes memory facts
    ) internal pure returns (Components memory c) {
        c = Components(
            p.publicationHash,
            p.publicationBytes,
            keccak256(receipt),
            uint32(receipt.length),
            keccak256(source),
            uint32(source.length),
            keccak256(evidence),
            uint32(evidence.length),
            keccak256(facts),
            uint32(facts.length),
            p.environmentHash,
            p.environmentBytes
        );
        if (
            receipt.length != 640 || source.length > 524288 || evidence.length > 524288
                || facts.length > 524288
        ) {
            revert M.InvalidModeEvidence();
        }
    }

    function payloadId(Components memory c) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_PAYLOAD_PREPARATION_V1"),
                block.chainid,
                address(this),
                c
            )
        );
    }

    /// @dev Each dynamic tuple is the compiler's abi.encode(tuple): its leading offset is 32.
    /// Receipt is exactly twenty static words. The original payload head is therefore 26 words:
    /// domain, Publication offset, Receipt, SourceFacts/Evidence/Facts/environment offsets.
    function assemble(bytes memory receipt, bytes[5] memory tails)
        internal
        pure
        returns (bytes memory out)
    {
        if (receipt.length != 640) revert M.InvalidModeEvidence();
        uint256 length = 832;
        for (uint256 i; i < 5; ++i) {
            bytes memory tail = tails[i];
            uint256 offset;
            assembly ("memory-safe") { offset := mload(add(tail, 32)) }
            if (tail.length < 64 || tail.length % 32 != 0 || offset != 32) {
                revert M.InvalidModeEvidence();
            }
            length += tail.length - 32;
        }
        if (length > 524288) revert M.InvalidModeEvidence();
        out = new bytes(length);
        bytes32 domain = keccak256("6529STREAM_REFERENCE_MODE_PAYLOAD_V1");
        assembly ("memory-safe") { mstore(add(out, 32), domain) }
        _copy(out, 64, receipt, 0, 640);
        uint256 cursor = 832;
        for (uint256 i; i < 5; ++i) {
            uint256 word = i == 0 ? 1 : 21 + i;
            assembly ("memory-safe") { mstore(add(add(out, 32), mul(word, 32)), cursor) }
            uint256 size = tails[i].length - 32;
            _copy(out, cursor, tails[i], 32, size);
            cursor += size;
        }
    }

    /// @dev All copied spans are complete ABI words inside newly allocated, length-checked bytes.
    function _copy(bytes memory out, uint256 at, bytes memory source, uint256 skip, uint256 size)
        private
        pure
    {
        assembly ("memory-safe") {
            let dest := add(add(out, 32), at)
            let src := add(add(source, 32), skip)
            let end := add(dest, size)
            for { } lt(dest, end) {
                dest := add(dest, 32)
                src := add(src, 32)
            } {
                mstore(dest, mload(src))
            }
        }
    }
}
