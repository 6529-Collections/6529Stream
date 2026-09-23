// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamCurrentStackPlan } from "./StreamCurrentStackPlan.sol";
import {
    GenesisBatch,
    GovernanceCall
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import {
    StreamSchemaRegistry
} from "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamSchemaDocumentStore
} from "../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamSchemaRegistry as S
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";

/// @notice Exact supplied interpretation documents, permissionless uploads and original governance calls.
/// @dev A retained plan hash is a caller-reviewed commitment, not publisher authentication or admission.
library StreamSchemaAdmissionPlan {
    struct Document {
        S.DocumentSpec specification;
        bytes32[] chunkHashes;
        uint32[] chunkLengths;
    }

    struct Plan {
        uint256 chainId;
        StreamSchemaRegistry registry;
        bytes32 registryCodeHash;
        StreamSchemaDocumentStore store;
        bytes32 storeCodeHash;
        address executor;
        bytes32 executorCodeHash;
        bytes32 sourcePlanHash;
        Document[] documents;
    }

    function capture(StreamSchemaRegistry registry, bytes32 sourcePlanHash, Document[] memory rows)
        internal
        view
        returns (Plan memory p)
    {
        require(address(registry).code.length != 0 && sourcePlanHash != 0, "reviewed source plan");
        require(rows.length != 0 && rows.length <= 64, "bounded document inventory");
        for (uint256 i; i < rows.length; ++i) {
            _shape(rows[i]);
            bytes32 id = keccak256(bytes(rows[i].specification.name));
            for (uint256 j; j < i; ++j) {
                require(
                    id != keccak256(bytes(rows[j].specification.name)),
                    "duplicate document identity"
                );
            }
        }
        p.chainId = block.chainid;
        p.registry = registry;
        p.registryCodeHash = address(registry).codehash;
        p.store = StreamSchemaDocumentStore(registry.chunkStore());
        p.storeCodeHash = address(p.store).codehash;
        p.executor = registry.governanceAuthority();
        p.executorCodeHash = p.executor.codehash;
        p.sourcePlanHash = sourcePlanHash;
        p.documents = rows;
        _unchanged(p, planHash(p));
    }

    function planHash(Plan memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode("STREAM_SCHEMA_ADMISSION_PLAN_V1", p));
    }

    /// @notice Upload exact source bytes. Ordered repeated chunks remain repeated in the plan.
    /// @dev Does not register a document, authorize a writer or execute governance.
    function publish(Plan memory p, bytes32 retainedHash, uint256 index, bytes memory raw)
        internal
    {
        _unchanged(p, retainedHash);
        Document memory row = p.documents[index];
        require(
            raw.length == row.specification.totalBytes
                && keccak256(raw) == row.specification.contentHash,
            "exact source bytes"
        );
        uint256 offset;
        for (uint256 i; i < row.chunkHashes.length; ++i) {
            bytes memory part = new bytes(row.chunkLengths[i]);
            for (uint256 j; j < part.length; ++j) {
                part[j] = raw[offset + j];
            }
            require(keccak256(part) == row.chunkHashes[i], "ordered chunk source");
            (bytes32 hash,) = p.store.publishChunk(part);
            require(hash == row.chunkHashes[i], "published chunk hash");
            offset += part.length;
        }
        _published(p.store, row);
    }

    /// @notice Return one original class-1 call, or an empty batch after exact ACTIVE readback.
    /// @dev Callers append their reviewed manifest tail and use the original delayed Executor.
    function next(Plan memory p, bytes32 retainedHash, uint256 index)
        internal
        view
        returns (GenesisBatch memory batch)
    {
        _unchanged(p, retainedHash);
        Document memory row = p.documents[index];
        if (_existing(p, row)) return batch;
        _published(p.store, row);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            p.registry.registrationTransition(row.specification, row.chunkHashes);
        bytes memory data =
            abi.encodeCall(p.registry.registerDocument, (row.specification, row.chunkHashes));
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] =
            StreamCurrentStackPlan.call(address(p.registry), data, scope, oldHash, newHash);
        batch.callDatas[0] = data;
    }

    function pending(Plan memory p, bytes32 retainedHash) internal view returns (uint256 count) {
        _unchanged(p, retainedHash);
        for (uint256 i; i < p.documents.length; ++i) {
            if (!_existing(p, p.documents[i])) ++count;
        }
    }

    function requireRegistered(Plan memory p, bytes32 retainedHash) internal view {
        require(pending(p, retainedHash) == 0, "document admission incomplete");
    }

    function _existing(Plan memory p, Document memory row) private view returns (bool) {
        bytes32 id = keccak256(bytes(row.specification.name));
        S.DocumentView memory found = p.registry.document(id);
        if (!found.exists) return false;
        require(
            found.status == S.DocumentStatus.ACTIVE
                && found.declarationHash
                    == keccak256(abi.encode(row.specification, row.chunkHashes))
                && keccak256(abi.encode(found.specification, found.chunkHashes))
                    == keccak256(abi.encode(row.specification, row.chunkHashes)),
            "conflicting or retired document"
        );
        _published(p.store, row);
        bytes memory raw = p.registry.documentBytes(id);
        require(
            raw.length == row.specification.totalBytes
                && keccak256(raw) == row.specification.contentHash,
            "registered source bytes"
        );
        return true;
    }

    function _published(StreamSchemaDocumentStore store, Document memory row) private view {
        for (uint256 i; i < row.chunkHashes.length; ++i) {
            bytes memory raw = store.readChunk(row.chunkHashes[i]);
            require(
                raw.length == row.chunkLengths[i] && keccak256(raw) == row.chunkHashes[i],
                "stored ordered chunk"
            );
        }
    }

    function _shape(Document memory row) private pure {
        require(
            bytes(row.specification.name).length != 0 && row.specification.totalBytes != 0
                && row.chunkHashes.length != 0 && row.chunkHashes.length <= 64
                && row.chunkHashes.length == row.chunkLengths.length,
            "document shape"
        );
        uint256 total;
        for (uint256 i; i < row.chunkLengths.length; ++i) {
            require(row.chunkLengths[i] != 0 && row.chunkLengths[i] <= 8192, "original chunk bound");
            require(
                i + 1 == row.chunkLengths.length || row.chunkLengths[i] == 8192,
                "full nonfinal chunk"
            );
            total += row.chunkLengths[i];
        }
        require(total == row.specification.totalBytes, "document length");
    }

    function _unchanged(Plan memory p, bytes32 retainedHash) private view {
        require(planHash(p) == retainedHash && p.chainId == block.chainid, "changed retained plan");
        require(
            address(p.registry).code.length != 0 && address(p.store).code.length != 0
                && p.executor.code.length != 0 && address(p.registry).codehash == p.registryCodeHash
                && address(p.store).codehash == p.storeCodeHash
                && p.executor.codehash == p.executorCodeHash
                && p.registry.chunkStore() == address(p.store)
                && p.registry.governanceAuthority() == p.executor
                && p.registry.governanceAuthorityCodeHash() == p.executorCodeHash,
            "changed schema graph"
        );
    }
}
