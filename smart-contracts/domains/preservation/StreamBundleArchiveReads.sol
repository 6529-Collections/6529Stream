// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamFinalityArtifactTypes as F
} from "../../interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamInventoryAbiCorrespondence } from "./StreamInventoryAbiCorrespondence.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactEnvironment.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactCheckpointVerifier.sol";
import "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import "../../interfaces/stream/preservation/IStreamArtifactEnvironment.sol";
import "../../interfaces/stream/preservation/IStreamArtifactOriginalEvidence.sol";
import "./StreamPreservationArchiveBundleReads.sol";
import "../../interfaces/stream/preservation/IStreamRenderCriticalInventory.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

/// @notice Per-object genuine correspondence, original evidence retention and current liveness.
library StreamBundleArchiveReads {
    bytes32 private constant RAW = keccak256("RAW_BYTES");
    bytes32 private constant JCS = keccak256("RFC8785_JCS");

    function environment(B.Dependencies memory d) public view returns (bytes32) {
        if (block.chainid != d.chainId) revert T.InventorySourceChanged();
        for (uint256 i; i < 6; ++i) {
            IO.pin(d.targets[i], d.codeHashes[i]);
        }
        if (
            IO.addressWord(
                        d.targets[2],
                        abi.encodeCall(IStreamRenderCriticalInventory.core, ()),
                        d.readGas
                    ) != d.targets[0]
                || IO.addressWord(
                        d.targets[2],
                        abi.encodeCall(IStreamRenderCriticalInventory.metadataHost, ()),
                        d.readGas
                    ) != d.targets[1]
                || IO.addressWord(
                        d.targets[2],
                        abi.encodeCall(IStreamRenderCriticalInventory.artifactCoverage, ()),
                        d.readGas
                    ) != d.targets[3]
                || IO.addressWord(
                        d.targets[2],
                        abi.encodeCall(IStreamRenderCriticalInventory.externalCoverage, ()),
                        d.readGas
                    ) != d.targets[4]
        ) revert T.InventorySourceChanged();
        bytes memory onchain = IO.fixedRead(
            d.targets[3],
            abi.encodeCall(IStreamArtifactEnvironment.currentArtifactEnvironment, ()),
            64,
            d.archiveGas
        );
        (bytes32 onchainHash, uint64 epoch) = abi.decode(onchain, (bytes32, uint64));
        IO.canonical(d.targets[3], onchain, abi.encode(onchainHash, epoch));
        bytes memory external_ = IO.fixedRead(
            d.targets[4],
            abi.encodeCall(
                IStreamExternalArtifactEnvironment.currentExternalArtifactEnvironment, ()
            ),
            64,
            d.archiveGas
        );
        (bytes32 externalHash, uint64 revision) = abi.decode(external_, (bytes32, uint64));
        IO.canonical(d.targets[4], external_, abi.encode(externalHash, revision));
        if (onchainHash == 0 || epoch == 0 || externalHash == 0) revert T.InventorySourceChanged();
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1"),
                d,
                onchainHash,
                epoch,
                externalHash,
                revision
            )
        );
    }

    function admit(
        B.Dependencies memory d,
        bytes32 artist,
        T.Item memory item,
        B.Proof memory proof
    ) public view returns (B.Admission memory result, bytes32 currentObservation) {
        if (item.role == 0 || item.source == address(0) || item.sourceRecord == 0) {
            revert T.InvalidInventoryItem();
        }
        result.proof = proof;
        if (item.kind == T.Kind.STATE_BUNDLE) {
            _noProof(proof);
            result.immutablePartsHash = _stateBundle(d, item);
            result.originalBundleHash = keccak256(
                abi.encode(
                    keccak256("STATE_RETAINED_ORIGINAL_AUTHORIZATION"),
                    item,
                    result.immutablePartsHash
                )
            );
        } else if (
            item.kind == T.Kind.ABSENT || item.kind == T.Kind.EMPTY_BYTES
                || item.kind == T.Kind.NATIVE_OS_PREREQUISITE
                || item.kind == T.Kind.EMPTY_PACKAGE_MEMBER
        ) {
            _noProof(proof);
            _applicability(item);
            result.originalBundleHash =
                keccak256(abi.encode(keccak256("EXPLICIT_INVENTORY_APPLICABILITY"), item));
        } else if (proof.backend == 1 && item.kind != T.Kind.ONCHAIN_OBJECT) {
            (result.externalOriginal, result.originalBundleHash, currentObservation) =
                _external(d, artist, item, proof);
        } else if (proof.backend == 2 && item.kind != T.Kind.EXTERNAL_OBJECT) {
            (result.onchainOriginal, result.immutablePartsHash, result.originalBundleHash) =
                _onchain(d, artist, item, proof);
        } else {
            revert T.InvalidInventoryItem();
        }
        if (result.originalBundleHash == 0) revert T.InvalidInventoryItem();
    }

    function current(
        B.Dependencies memory d,
        bytes32 artist,
        T.Item memory item,
        B.Admission memory original
    ) public view returns (bytes32 observation) {
        if (original.proof.backend == 1) {
            return _pair(d, original.externalOriginal);
        }
        (B.Admission memory now_, bytes32 currentObservation) =
            admit(d, artist, item, original.proof);
        if (keccak256(abi.encode(now_)) != keccak256(abi.encode(original))) {
            revert T.InventorySourceChanged();
        }
        return currentObservation;
    }

    function _external(
        B.Dependencies memory d,
        bytes32 artist,
        T.Item memory item,
        B.Proof memory proof
    ) private view returns (E.Coverage memory c, bytes32 bundles, bytes32 observation) {
        if (
            proof.coverageHash == 0 || proof.objectHash == 0
                || (item.objectHash != 0 && item.objectHash != proof.objectHash)
                || (item.originalCoverageHash != 0
                    && item.originalCoverageHash != proof.coverageHash)
        ) revert T.InvalidInventoryItem();
        bytes memory raw = IO.fixedRead(
            d.targets[4],
            abi.encodeCall(IStreamExternalArtifactCoverage.objectIdentity, (proof.objectHash)),
            320,
            d.readGas
        );
        E.ObjectIdentity memory object = abi.decode(raw, (E.ObjectIdentity));
        IO.canonical(d.targets[4], raw, abi.encode(object));
        _correspondence(
            item,
            object.contentHash,
            object.sha256Digest,
            object.canonicalizationId,
            object.byteSize
        );
        if (
            object.artistId != artist || (item.schemaId != 0 && item.schemaId != object.schemaId)
                || (item.formatId != 0 && item.formatId != object.formatId)
                || (item.kind != T.Kind.REGISTERED_DOCUMENT
                    && item.catalogId != 0
                    && (item.catalogId != object.formatCatalogId
                        || item.catalogHash != object.formatCatalogHash))
        ) revert T.InvalidInventoryItem();
        raw = IO.fixedRead(
            d.targets[4],
            abi.encodeCall(IStreamExternalArtifactCoverage.coverage, (proof.coverageHash)),
            480,
            d.readGas
        );
        c = abi.decode(raw, (E.Coverage));
        IO.canonical(d.targets[4], raw, abi.encode(c));
        if (
            c.coverageHash != proof.coverageHash || c.objectHash != proof.objectHash
                || c.artistId != artist || c.contentHash != object.contentHash
                || c.sha256Digest != object.sha256Digest
                || c.arweaveDataRoot != object.arweaveDataRoot || c.byteSize != object.byteSize
                || c.firstReceiptHash == 0 || c.secondReceiptHash == 0 || c.firstFixityHash == 0
                || c.secondFixityHash == 0
        ) revert T.InvalidInventoryItem();
        observation = _pair(d, c);
        bundles = _externalOriginalBundles(d, c);
    }

    function _externalOriginalBundles(B.Dependencies memory d, E.Coverage memory c)
        private
        view
        returns (bytes32)
    {
        bytes32[5] memory hashes;
        hashes[0] = _externalReceiptBundle(d, c.firstReceiptHash);
        hashes[1] = _externalReceiptBundle(d, c.secondReceiptHash);
        hashes[2] = _externalFixityBundle(d, c.firstFixityHash);
        hashes[3] = _externalFixityBundle(d, c.secondFixityHash);
        hashes[4] = _nativeBundle(d, c.checkpointHash);
        return keccak256(abi.encode(d.targets[4], d.codeHashes[4], c, hashes));
    }

    function _pair(B.Dependencies memory d, E.Coverage memory original)
        private
        view
        returns (bytes32)
    {
        bytes memory raw = IO.fixedRead(
            d.targets[4],
            abi.encodeCall(
                IStreamExternalArtifactCurrentPair.currentReceiptPair,
                (
                    original.firstReceiptHash,
                    original.secondReceiptHash,
                    original.artistId,
                    original.objectHash
                )
            ),
            448,
            d.archiveGas
        );
        E.CurrentPair memory c = abi.decode(raw, (E.CurrentPair));
        IO.canonical(d.targets[4], raw, abi.encode(c));
        if (
            c.objectHash != original.objectHash || c.artistId != original.artistId
                || c.contentHash != original.contentHash || c.sha256Digest != original.sha256Digest
                || c.arweaveDataRoot != original.arweaveDataRoot || c.byteSize != original.byteSize
                || c.firstFamilyRecordHash != original.firstFamilyRecordHash
                || c.secondFamilyRecordHash != original.secondFamilyRecordHash
                || c.firstReceiptHash != original.firstReceiptHash
                || c.secondReceiptHash != original.secondReceiptHash
                || c.checkpointHash != original.checkpointHash
                || c.profileHash != original.profileHash || c.firstFixityHash == 0
                || c.secondFixityHash == 0
        ) revert T.InventorySourceChanged();
        return keccak256(raw);
    }

    function _externalReceiptBundle(B.Dependencies memory d, bytes32 hash)
        private
        view
        returns (bytes32)
    {
        bytes memory raw = IO.read(
            d.targets[4],
            abi.encodeCall(IStreamExternalArtifactCoverage.receipt, (hash)),
            65536,
            d.archiveGas
        );
        (E.Receipt memory record, bytes memory locator, bytes memory signature) =
            abi.decode(raw, (E.Receipt, bytes, bytes));
        IO.canonical(d.targets[4], raw, abi.encode(record, locator, signature));
        if (
            record.writer == address(0) || keccak256(locator) != record.storageIdentifierHash
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_EXTERNAL_RECEIPT_V1"),
                            d.chainId,
                            d.targets[4],
                            record
                        )
                    ) != hash
        ) revert T.InvalidInventoryItem();
        return keccak256(abi.encode(hash, raw));
    }

    function _externalFixityBundle(B.Dependencies memory d, bytes32 hash)
        private
        view
        returns (bytes32)
    {
        bytes memory raw = IO.read(
            d.targets[4],
            abi.encodeCall(IStreamExternalArtifactCoverage.fixity, (hash)),
            65536,
            d.archiveGas
        );
        (E.Fixity memory record, bytes memory signature) = abi.decode(raw, (E.Fixity, bytes));
        IO.canonical(d.targets[4], raw, abi.encode(record, signature));
        if (
            record.verifier == address(0)
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_EXTERNAL_FIXITY_V1"),
                            d.chainId,
                            d.targets[4],
                            record
                        )
                    ) != hash
        ) revert T.InvalidInventoryItem();
        return keccak256(abi.encode(hash, raw));
    }

    function _nativeBundle(B.Dependencies memory d, bytes32 hash) private view returns (bytes32) {
        address verifier = IO.addressWord(
            d.targets[4],
            abi.encodeCall(IStreamExternalArtifactCoverage.checkpointVerifier, ()),
            d.readGas
        );
        bytes memory raw = IO.read(
            verifier,
            abi.encodeCall(IStreamExternalArtifactCheckpointVerifier.checkpointRecord, (hash)),
            65536,
            d.archiveGas
        );
        E.NativeRecord memory record = abi.decode(raw, (E.NativeRecord));
        IO.canonical(verifier, raw, abi.encode(record));
        if (record.recordHash != hash || record.certificate.length == 0 || record.recordedAt == 0) {
            revert T.InvalidInventoryItem();
        }
        return keccak256(abi.encode(verifier, verifier.codehash, hash, raw));
    }

    function _onchain(
        B.Dependencies memory d,
        bytes32 artist,
        T.Item memory item,
        B.Proof memory proof
    ) private view returns (F.Coverage memory c, bytes32 parts, bytes32 bundles) {
        if (
            proof.coverageHash == 0 || proof.objectHash == 0
                || (item.objectHash != 0 && item.objectHash != proof.objectHash)
                || (item.originalCoverageHash != 0
                    && item.originalCoverageHash != proof.coverageHash)
        ) revert T.InvalidInventoryItem();
        bytes memory raw = IO.fixedRead(
            d.targets[3],
            abi.encodeCall(
                IStreamFinalityArtifactCoverage.requireArtifactCoverage,
                (proof.coverageHash, artist, proof.objectHash)
            ),
            384,
            d.archiveGas
        );
        c = abi.decode(raw, (F.Coverage));
        IO.canonical(d.targets[3], raw, abi.encode(c));
        if (
            c.completionHash != proof.coverageHash || c.artifactHash != proof.objectHash
                || c.artistId != artist || item.algorithm != 1
                || (item.schemaId != 0 && item.schemaId != c.schemaId)
        ) revert T.InvalidInventoryItem();
        _correspondence(item, c.contentHash, 0, c.canonicalizationId, c.byteLength);
        raw = IO.read(
            d.targets[3],
            abi.encodeCall(IStreamFinalityArtifactCoverage.artifact, (proof.objectHash)),
            8192,
            d.readGas
        );
        F.Artifact memory a = abi.decode(raw, (F.Artifact));
        IO.canonical(d.targets[3], raw, abi.encode(a));
        if (
            a.chunkHashes.length != c.chunkCount || a.chunkHashes.length != a.chunkLengths.length
                || a.hashAlgorithm != 1 || a.contentHash != c.contentHash
                || a.byteLength != c.byteLength || a.artistId != artist
        ) revert T.InvalidInventoryItem();
        bytes32 bundleChain;
        (parts, bundleChain) = _onchainParts(d, c, a);
        bundles = keccak256(abi.encode(d.targets[3], d.codeHashes[3], c, a, parts, bundleChain));
    }

    function _onchainParts(B.Dependencies memory d, F.Coverage memory c, F.Artifact memory a)
        private
        view
        returns (bytes32 parts, bytes32 bundleChain)
    {
        uint256 total;
        for (uint32 i; i < c.chunkCount; ++i) {
            bytes memory raw = IO.fixedRead(
                d.targets[3],
                abi.encodeCall(IStreamFinalityArtifactCoverage.artifactChunk, (c.artifactHash, i)),
                64,
                d.readGas
            );
            (address pointer, bytes32 codeHash) = abi.decode(raw, (address, bytes32));
            IO.canonical(d.targets[3], raw, abi.encode(pointer, codeHash));
            bytes memory code = pointer.code;
            if (
                codeHash != pointer.codehash || code.length != uint256(a.chunkLengths[i]) + 1
                    || code[0] != 0
            ) revert T.InvalidInventoryItem();
            bytes memory part = new bytes(a.chunkLengths[i]);
            assembly ("memory-safe") { extcodecopy(pointer, add(part, 32), 1, mload(part)) }
            if (keccak256(part) != a.chunkHashes[i]) revert T.InvalidInventoryItem();
            total += part.length;
            parts = keccak256(
                abi.encode(parts, i, pointer, codeHash, a.chunkHashes[i], a.chunkLengths[i])
            );
            bundleChain = keccak256(
                abi.encode(bundleChain, i, _originalPartBundle(d, c, i, a.chunkHashes[i]))
            );
        }
        if (total != c.byteLength) revert T.InvalidInventoryItem();
    }

    function _originalPartBundle(
        B.Dependencies memory d,
        F.Coverage memory c,
        uint32 index,
        bytes32 content
    ) private view returns (bytes32) {
        bytes32 original = IO.word(
            d.targets[3],
            abi.encodeCall(
                IStreamArtifactOriginalEvidence.originalArtifactChunkCoverage,
                (c.completionHash, index)
            ),
            d.readGas
        );
        address archive = IO.addressWord(
            d.targets[3],
            abi.encodeCall(IStreamFinalityArtifactCoverage.archivalCoverage, ()),
            d.readGas
        );
        return StreamPreservationArchiveBundleReads.chunk(
            archive,
            original,
            c.artistId,
            content,
            c.firstFamilyRecordHash,
            c.secondFamilyRecordHash,
            d.archiveGas
        );
    }

    function _stateBundle(B.Dependencies memory d, T.Item memory item)
        private
        view
        returns (bytes32)
    {
        if (
            item.source != d.targets[5] || item.sourceIndex != 1 || item.algorithm != 1
                || item.canonicalizationId != RAW
        ) revert T.InvalidInventoryItem();
        bytes memory raw = IO.read(
            item.source,
            abi.encodeCall(IStreamArtistArchiveV2.artistEvidenceBytesV2, (item.sourceRecord, 1)),
            65600,
            d.archiveGas
        );
        bytes memory payload = abi.decode(raw, (bytes));
        IO.canonical(item.source, raw, abi.encode(payload));
        _correspondence(item, keccak256(payload), 0, RAW, uint64(payload.length));
        raw = IO.fixedRead(
            item.source,
            abi.encodeCall(IStreamArtistArchiveV2.artistEvidenceMetadataV2, (item.sourceRecord, 1)),
            128,
            d.readGas
        );
        (bytes32 hash, address pointer, uint32 size, uint64 blockNumber) =
            abi.decode(raw, (bytes32, address, uint32, uint64));
        IO.canonical(item.source, raw, abi.encode(hash, pointer, size, blockNumber));
        if (
            size != payload.length || hash != keccak256(payload) || blockNumber == 0
                || keccak256(pointer.code) != keccak256(bytes.concat(hex"00", payload))
        ) revert T.InvalidInventoryItem();
        return keccak256(
            abi.encode(
                item.source,
                item.source.codehash,
                item.sourceRecord,
                pointer,
                pointer.codehash,
                hash,
                size,
                blockNumber
            )
        );
    }

    function _correspondence(
        T.Item memory item,
        bytes32 keccakHash,
        bytes32 shaHash,
        bytes32 canon,
        uint64 size
    ) private pure {
        if (
            item.digest.length != 32 || item.canonicalizationId != canon || size == 0
                || (item.byteSize != 0 && item.byteSize != size)
        ) revert T.InvalidInventoryItem();
        if (
            item.kind != T.Kind.EXTERNAL_OBJECT && item.kind != T.Kind.ONCHAIN_OBJECT
                && canon != RAW && canon != JCS
                && !StreamInventoryAbiCorrespondence.supported(item)
        ) {
            revert T.UnsupportedInventoryCorrespondence(item.algorithm, item.canonicalizationId);
        }
        bytes32 digest =
            item.algorithm == 1 ? keccakHash : item.algorithm == 2 ? shaHash : bytes32(0);
        if (digest == 0) {
            revert T.UnsupportedInventoryCorrespondence(item.algorithm, item.canonicalizationId);
        }
        if (keccak256(item.digest) != keccak256(abi.encodePacked(digest))) {
            revert T.InvalidInventoryItem();
        }
    }

    function _noProof(B.Proof memory p) private pure {
        if (p.backend != 0 || p.coverageHash != 0 || p.objectHash != 0) {
            revert T.InvalidInventoryItem();
        }
    }

    function _applicability(T.Item memory item) private pure {
        if (
            item.objectHash != 0 || item.originalCoverageHash != 0 || item.schemaId != 0
                || item.formatId != 0 || item.catalogId != 0 || item.catalogHash != 0
        ) revert T.InvalidInventoryItem();
        if (item.kind == T.Kind.ABSENT) {
            if (
                item.byteSize != 0 || item.algorithm != 0 || item.canonicalizationId != 0
                    || item.digest.length != 0 || bytes(item.uri).length != 0
            ) revert T.InvalidInventoryItem();
        } else if (item.kind == T.Kind.EMPTY_BYTES) {
            if (
                item.byteSize != 0 || item.algorithm != 1 || item.canonicalizationId != RAW
                    || bytes(item.uri).length != 0
                    || keccak256(item.digest) != keccak256(abi.encodePacked(keccak256(bytes(""))))
            ) revert T.InvalidInventoryItem();
        } else if (item.kind == T.Kind.EMPTY_PACKAGE_MEMBER) {
            if (
                item.byteSize != 0 || item.algorithm != 2 || item.canonicalizationId != RAW
                    || bytes(item.uri).length == 0
                    || keccak256(item.digest) != keccak256(abi.encodePacked(sha256(bytes(""))))
            ) revert T.InvalidInventoryItem();
        } else if (
            item.algorithm != 2 || item.canonicalizationId != RAW || item.digest.length != 32
                || bytes(item.uri).length == 0
                || (item.byteSize == 0
                    && keccak256(item.digest) != keccak256(abi.encodePacked(sha256(bytes("")))))
        ) {
            revert T.InvalidInventoryItem();
        }
    }
}
