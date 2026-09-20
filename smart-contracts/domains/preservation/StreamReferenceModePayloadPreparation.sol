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
import {
    StreamReferenceModePayloadEncoding as Encoding
} from "./StreamReferenceModePayloadEncoding.sol";
import {
    StreamReferenceRenderPreparation as Environment
} from "./StreamReferenceRenderPreparation.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import { StreamSchemaDocumentStore as Store } from "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Permissionless immutable preparation. Final publication still performs every live check.
library StreamReferenceModePayloadPreparation {
    struct PublicationCarrier {
        P.PublicationDescriptor descriptor;
        Bytes.Manifest canonical;
    }

    struct State {
        mapping(bytes32 => PublicationCarrier) publications;
        mapping(bytes32 => Bytes.Manifest) payloads;
    }

    event ReferenceModePublicationPrepared(
        uint16 schemaVersion, bytes32 indexed preparationId, P.PublicationDescriptor descriptor
    );
    event ReferenceModePayloadPrepared(
        uint16 schemaVersion,
        bytes32 indexed preparationId,
        bytes32 indexed publicationPreparationId,
        bytes32 payloadHash,
        uint32 payloadBytes
    );

    function preparePublication(
        State storage state,
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        address store,
        bytes32 storeHash,
        bytes calldata original
    ) public returns (bytes32 id) {
        _pin(store, storeHash);
        R.Publication memory p = abi.decode(original[4:], (R.Publication));
        bytes memory raw = abi.encode(p);
        if (raw.length == 0 || raw.length > 524288) revert M.InvalidModeEvidence();
        bytes32 hash = keccak256(raw);
        id = Encoding.publicationId(hash, uint32(raw.length));
        PublicationCarrier storage saved = state.publications[id];
        if (saved.canonical.contentHash != 0) {
            _publication(saved, hash, uint32(raw.length));
            Bytes.requireIntact(saved.canonical);
            _environment(inventories, saved.descriptor);
            return id;
        }
        P.PublicationDescriptor memory descriptor = P.PublicationDescriptor(
            hash,
            uint32(raw.length),
            Environment.environmentIdInternal(p.environment),
            p.environment.manifestHash,
            p.environment.manifestBytes
        );
        _environment(inventories, descriptor);
        for (uint256 i; i < p.captures.length; ++i) {
            if (p.captures[i].environmentManifestHash != descriptor.environmentHash) {
                revert M.InvalidModeEvidence();
            }
        }
        Bytes.retain(saved.canonical, store, raw);
        saved.descriptor = descriptor;
        emit ReferenceModePublicationPrepared(1, id, descriptor);
    }

    function preparePayload(
        State storage state,
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        address store,
        bytes32 storeHash,
        bytes calldata original
    ) public returns (bytes32 id) {
        _pin(store, storeHash);
        (
            bytes32 publicationId,
            R.Receipt memory receipt,
            R.SourceFacts memory source,
            M.Evidence memory evidence,
            M.Facts memory facts
        ) = abi.decode(original[4:], (bytes32, R.Receipt, R.SourceFacts, M.Evidence, M.Facts));
        PublicationCarrier storage saved = state.publications[publicationId];
        P.PublicationDescriptor memory descriptor = saved.descriptor;
        if (
            publicationId
                != Encoding.publicationId(descriptor.publicationHash, descriptor.publicationBytes)
        ) revert M.InvalidModeEvidence();
        _publication(saved, descriptor.publicationHash, descriptor.publicationBytes);
        Encoding.normalize(receipt);
        bytes memory encodedReceipt = abi.encode(receipt);
        bytes[5] memory tails;
        tails[0] = Bytes.read(saved.canonical);
        tails[1] = abi.encode(source);
        tails[2] = abi.encode(evidence);
        tails[3] = abi.encode(facts);
        tails[4] = abi.encode(_environment(inventories, descriptor));
        id = Encoding.payloadId(
            Encoding.components(descriptor, encodedReceipt, tails[1], tails[2], tails[3])
        );
        if (state.payloads[id].contentHash != 0) {
            Bytes.requireIntact(state.payloads[id]);
            return id;
        }
        bytes memory canonical = Encoding.assemble(encodedReceipt, tails);
        bytes32 hash = _retain(state.payloads[id], store, canonical);
        emit ReferenceModePayloadPrepared(1, id, publicationId, hash, uint32(canonical.length));
    }

    /// @dev Only the actual publication worker calls this with hashes derived from its full typed
    /// input and newly validated facts. A cache miss preserves the original monolithic behavior.
    function lookup(
        State storage state,
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        bytes32 publicationHash,
        uint32 publicationBytes,
        R.Receipt memory receipt,
        R.SourceFacts memory source,
        M.Evidence memory evidence,
        M.Facts memory facts
    ) public view returns (bytes memory) {
        PublicationCarrier storage saved = state.publications[
            Encoding.publicationId(publicationHash, publicationBytes)
        ];
        if (saved.canonical.contentHash == 0) return new bytes(0);
        _publication(saved, publicationHash, publicationBytes);
        Encoding.normalize(receipt);
        bytes32 id = Encoding.payloadId(
            Encoding.components(
                saved.descriptor,
                abi.encode(receipt),
                abi.encode(source),
                abi.encode(evidence),
                abi.encode(facts)
            )
        );
        if (state.payloads[id].contentHash == 0) return new bytes(0);
        Bytes.requireIntact(saved.canonical);
        _environment(inventories, saved.descriptor);
        return Bytes.read(state.payloads[id]);
    }

    function publicationEncoded(State storage state, bytes32 id)
        public
        view
        returns (bytes memory)
    {
        PublicationCarrier storage saved = state.publications[id];
        _publication(saved, saved.descriptor.publicationHash, saved.descriptor.publicationBytes);
        if (
            id
                != Encoding.publicationId(
                    saved.descriptor.publicationHash, saved.descriptor.publicationBytes
                )
        ) revert M.InvalidModeEvidence();
        return abi.encode(saved.descriptor, Bytes.read(saved.canonical));
    }

    function payload(State storage state, bytes32 id) public view returns (bytes memory) {
        return Bytes.read(state.payloads[id]);
    }

    function _publication(PublicationCarrier storage saved, bytes32 hash, uint32 size)
        private
        view
    {
        if (
            hash == 0 || size == 0 || saved.descriptor.publicationHash != hash
                || saved.descriptor.publicationBytes != size || saved.canonical.contentHash != hash
                || saved.canonical.byteLength != size
        ) revert M.InvalidModeEvidence();
    }

    function _environment(
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        P.PublicationDescriptor memory p
    ) private view returns (bytes memory raw) {
        Bytes.Manifest storage saved = inventories[p.environmentId];
        if (
            p.environmentHash == 0 || p.environmentBytes == 0
                || saved.contentHash != p.environmentHash || saved.byteLength != p.environmentBytes
        ) revert M.InvalidModeEvidence();
        raw = Bytes.read(saved);
    }

    function _pin(address store, bytes32 hash) private view {
        if (store.code.length == 0 || store.codehash != hash) revert R.ReferenceDependency(store);
    }

    /// @dev Same fixed-maximum retention checks and writes as Bytes.retain. Keep the assembled
    /// payload in this frame and reuse one chunk scratch buffer instead of copying the full
    /// payload through the public library ABI and allocating a new buffer for every chunk.
    function _retain(Bytes.Manifest storage saved, address store, bytes memory canonical)
        private
        returns (bytes32 hash)
    {
        uint256 length = canonical.length;
        if (saved.byteLength != 0 || length == 0 || length > 524288) {
            revert Bytes.InvalidSnapshotManifest();
        }
        hash = keccak256(canonical);
        bytes memory scratch = new bytes(8193);
        for (uint256 offset; offset < length; offset += 8192) {
            uint256 size = length - offset;
            if (size > 8192) size = 8192;
            bytes32 chunkHash;
            assembly ("memory-safe") {
                chunkHash := keccak256(add(add(canonical, 32), offset), size)
            }
            (address pointer, uint32 storedLength) = Store(store).chunk(chunkHash);
            if (pointer == address(0) || storedLength != size) {
                revert Bytes.SnapshotChunkUnavailable(chunkHash);
            }
            if (pointer.code.length != size + 1) revert Bytes.SnapshotChunkChanged(pointer);
            bytes32 actual;
            assembly ("memory-safe") {
                extcodecopy(pointer, add(scratch, 32), 0, add(size, 1))
                actual := keccak256(add(scratch, 33), size)
            }
            if (scratch[0] != 0 || actual != chunkHash) {
                revert Bytes.SnapshotChunkChanged(pointer);
            }
            saved.pointers.push(pointer);
            saved.chunkHashes.push(chunkHash);
        }
        saved.contentHash = hash;
        saved.byteLength = uint32(length);
    }
}
