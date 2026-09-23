// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPreservationManifestTypesV1 as T
} from "../../interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import {
    IStreamFinalityArtifactCoverage as Coverage,
    F
} from "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as Facts
} from "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import { StreamViewAdoptionReads as Read } from "../metadata/StreamViewAdoptionReads.sol";
import {
    StreamViewPreservationOutputSchemasV1 as Definitions
} from "./StreamViewPreservationOutputSchemasV1.sol";
import {
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Closed, pinned original checkpoint, schema and full covered carrier reads.
library StreamViewPreservationManifestReadsV1 {
    function pins(T.Configuration memory c) public view {
        if (
            c.chainId != block.chainid || c.readGas < 50000 || c.checkpointGas < c.readGas
                || c.checkpointGas > 16777216 || c.checkpointConfigurationHash == 0
        ) revert T.InvalidViewManifest();
        Read.pin(c.core, c.coreCodeHash);
        Read.pin(c.checkpoint, c.checkpointCodeHash);
        Read.pin(c.coverage, c.coverageCodeHash);
        Read.pin(c.schemas, c.schemasCodeHash);
        if (
            Read.word(
                        c.checkpoint,
                        abi.encodeCall(IERC165.supportsInterface, (type(Checkpoint).interfaceId)),
                        c.readGas
                    ) != 1
                || bytes32(
                        Read.word(
                            c.checkpoint,
                            abi.encodeCall(Checkpoint.checkpointProfile, ()),
                            c.readGas
                        )
                    ) != C.PROFILE
                || bytes32(
                        Read.word(
                            c.checkpoint,
                            abi.encodeCall(Checkpoint.configurationHash, ()),
                            c.readGas
                        )
                    ) != c.checkpointConfigurationHash
                || Read.addr(c.coverage, abi.encodeCall(Coverage.core, ()), c.readGas) != c.core
                || Read.addr(c.coverage, abi.encodeCall(Coverage.schemaRegistry, ()), c.readGas)
                    != c.schemas
        ) revert T.InvalidViewManifest();
        bytes memory raw =
            Read.read(c.checkpoint, abi.encodeCall(Checkpoint.configuration, ()), 384, c.readGas);
        C.Configuration memory d = abi.decode(raw, (C.Configuration));
        if (
            keccak256(raw) != keccak256(abi.encode(d)) || d.core != c.core
                || d.coreCodeHash != c.coreCodeHash || d.chainId != c.chainId
        ) revert T.InvalidViewManifest();
    }

    function header(T.Configuration memory c, bytes32 id) public view returns (T.Header memory h) {
        bytes memory raw = Read.read(
            c.checkpoint,
            abi.encodeCall(Checkpoint.requireCurrentCheckpoint, (id)),
            416,
            c.checkpointGas
        );
        C.Plan memory p = abi.decode(raw, (C.Plan));
        if (
            id == 0 || keccak256(raw) != keccak256(abi.encode(p))
                || p.scope.scopeType != StreamFinalityScopeType.VIEW || p.scope.collectionId == 0
                || p.scope.tokenId != 0 || p.scope.scopeId == 0 || p.tokenCount == 0
                || p.tokenCount > T.MAX_ROWS || p.nextIndex != p.tokenCount || p.outputRoot == 0
                || p.contentRoot == 0 || p.adoptionRecord == 0 || p.sourceContextHash == 0
                || p.membershipHash == 0 || p.policyChainHash == 0
        ) revert T.InvalidViewManifest();
        h = T.Header(
            id,
            keccak256(raw),
            p.scope,
            p.adoptionRecord,
            p.sourceContextHash,
            p.membershipHash,
            p.policyChainHash,
            p.tokenCount,
            p.outputRoot,
            p.contentRoot
        );
    }

    function rows(T.Configuration memory c, bytes32 id, uint64 first, uint16 count)
        public
        view
        returns (C.Output[] memory result)
    {
        if (count == 0 || count > T.PART_ROWS) revert T.InvalidViewManifest();
        result = new C.Output[](count);
        uint256 previous;
        for (uint256 i; i < count; ++i) {
            bytes memory raw = Read.read(
                c.checkpoint,
                abi.encodeCall(Checkpoint.outputAt, (id, uint256(first) + i)),
                992,
                c.readGas
            );
            C.Output memory row = abi.decode(raw, (C.Output));
            if (
                keccak256(raw) != keccak256(abi.encode(row)) || row.index != uint256(first) + i
                    || row.tokenId == 0 || (i != 0 && row.tokenId <= previous)
            ) revert T.ViewManifestOrder(uint256(first) + i);
            previous = row.tokenId;
            result[i] = row;
        }
    }

    function carrier(
        T.Configuration memory c,
        bytes32 artifact,
        bytes32 coverage,
        bytes32 artist,
        bytes32 schema,
        bytes32 canon,
        uint256 length
    ) public view returns (T.Carrier memory saved, bytes memory raw) {
        if (artist == 0 || artifact == 0 || coverage == 0 || length == 0 || length > T.MAX_BYTES) revert T.InvalidViewManifest();
        bytes memory data = Read.read(
            c.coverage,
            abi.encodeCall(Coverage.requireArtifactCoverage, (coverage, artist, artifact)),
            384,
            c.readGas
        );
        F.Coverage memory f = abi.decode(data, (F.Coverage));
        if (
            keccak256(data) != keccak256(abi.encode(f)) || f.completionHash != coverage
                || f.artifactHash != artifact || f.artistId != artist || f.schemaId != schema
                || f.canonicalizationId != canon || f.contentHash == 0 || f.byteLength != length
                || f.chunkCount != (length + 8191) / 8192 || f.firstFamilyRecordHash == 0
                || f.secondFamilyRecordHash == 0
                || f.firstFamilyRecordHash == f.secondFamilyRecordHash
        ) revert T.InvalidViewManifest();
        raw = new bytes(length);
        uint256 copied;
        for (uint32 i; i < f.chunkCount; ++i) {
            data = Read.read(
                c.coverage, abi.encodeCall(Coverage.artifactChunk, (artifact, i)), 64, c.readGas
            );
            (address pointer, bytes32 hash) = abi.decode(data, (address, bytes32));
            uint256 take = length - copied;
            if (take > 8192) take = 8192;
            if (
                keccak256(data) != keccak256(abi.encode(pointer, hash))
                    || pointer.code.length != take + 1 || hash == 0 || pointer.codehash != hash
            ) revert T.ViewManifestChunk(pointer);
            uint256 prefix;
            assembly ("memory-safe") {
                extcodecopy(pointer, 0, 0, 1)
                prefix := byte(0, mload(0))
            }
            if (prefix != 0) revert T.ViewManifestChunk(pointer);
            assembly ("memory-safe") { extcodecopy(pointer, add(add(raw, 32), copied), 1, take) }
            copied += take;
        }
        if (copied != length || keccak256(raw) != f.contentHash) revert T.InvalidViewManifest();
        saved = T.Carrier(artifact, coverage, artist, f.contentHash, uint64(length));
    }

    function documents(T.Configuration memory c) public view {
        bytes32[5] memory ids = [
            Definitions.PART,
            Definitions.PART_CANON,
            Definitions.INDEX,
            Definitions.INDEX_CANON,
            Definitions.LEAF
        ];
        for (uint256 i; i < 5; ++i) {
            bytes memory raw =
                Read.read(c.schemas, abi.encodeCall(Facts.documentFacts, (ids[i])), 288, c.readGas);
            Facts.DocumentFacts memory f = abi.decode(raw, (Facts.DocumentFacts));
            bytes memory expected = Definitions.document(ids[i]);
            if (
                keccak256(raw) != keccak256(abi.encode(f)) || !f.exists
                    || f.status != Schema.DocumentStatus.ACTIVE || uint8(f.kind) != i % 2
                    || f.canonicalizationId != keccak256("RAW_BYTES")
                    || f.totalBytes != expected.length || f.contentHash != keccak256(expected)
            ) revert T.InvalidViewManifest();
            raw = Read.bounded(
                c.schemas, abi.encodeCall(Schema.documentBytes, (ids[i])), 8288, c.readGas, false
            );
            bytes memory actual = abi.decode(raw, (bytes));
            if (
                keccak256(raw) != keccak256(abi.encode(actual))
                    || keccak256(actual) != keccak256(expected)
            ) revert T.InvalidViewManifest();
        }
    }
}
