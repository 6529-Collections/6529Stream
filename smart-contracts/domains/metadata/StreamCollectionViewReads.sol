// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCollectionViews as V
} from "../../interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamCollectionMetadataV1 as M
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamCoreCollectionView
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import { IStreamModuleRegistry } from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamSchemaRegistry as S
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as F
} from "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import { StreamRecordFamilies } from "../records/StreamRecordFamilies.sol";
import { StreamCollectionViewFormat } from "./StreamCollectionViewFormat.sol";

/// @notice Fixed bounded current-source reads. Historical records do not invoke these checks.
library StreamCollectionViewReads {
    struct Context {
        address core;
        bytes32 coreHash;
        address metadata;
        bytes32 metadataHash;
        address schemas;
        bytes32 schemasHash;
        uint256 cap;
    }

    function code(address target, bytes32 expected) internal view {
        if (target.code.length == 0 || target.codehash != expected) {
            revert V.ViewDependencyChanged(target);
        }
    }

    function live(Context memory c, uint256 collectionId) public view {
        code(c.core, c.coreHash);
        code(c.metadata, c.metadataHash);
        code(c.schemas, c.schemasHash);
        (address metadata, bytes32 hash) = pointer(c, keccak256("COLLECTION_METADATA"));
        if (metadata != c.metadata || hash != c.metadataHash) revert V.ViewHostNotSelected();
        (address registry, bytes32 registryHash) = pointer(c, keccak256("MODULE_REGISTRY"));
        code(registry, registryHash);
        if (!abi.decode(
                read(
                    registry,
                    abi.encodeCall(
                        IStreamModuleRegistry.isModuleEligible,
                        (address(this), keccak256("COLLECTION_VIEWS"), type(V).interfaceId)
                    ),
                    32,
                    c.cap
                ),
                (bool)
            )) {
            revert V.ViewHostNotSelected();
        }
        if (!abi.decode(
                read(
                    registry,
                    abi.encodeCall(
                        IStreamModuleRegistry.isModuleEligible,
                        (c.metadata, keccak256("COLLECTION_METADATA"), type(M).interfaceId)
                    ),
                    32,
                    c.cap
                ),
                (bool)
            )) {
            revert V.ViewHostNotSelected();
        }
        if (
            collectionId == 0
                || !abi.decode(
                    read(
                        c.core,
                        abi.encodeCall(IStreamCoreCollectionView.collectionExists, (collectionId)),
                        32,
                        c.cap
                    ),
                    (bool)
                )
        ) {
            revert V.InvalidViewManifest();
        }
        if (abi.decode(
                read(
                    c.core,
                    abi.encodeCall(
                        IStreamCoreCollectionView.collectionFreezeStatus, (collectionId)
                    ),
                    32,
                    c.cap
                ),
                (bool)
            )) revert V.ViewLocked(collectionId, 0);
    }

    function authority(Context memory c, uint256 collectionId, address actor, bool globalOnly)
        public
        view
        returns (uint8 kind, uint256 grantCollectionId, uint64 revision)
    {
        // Reuse the original selected Metadata host's delayed, family-scoped grants.
        // Numeric classes retain their original meaning: 7 metadata admin, 8 global admin.
        for (uint8 k = globalOnly ? 8 : 7; k <= 8; ++k) {
            for (uint256 i = 0; i < 2; ++i) {
                uint256 scope = i == 0 ? collectionId : 0;
                (bool enabled, uint64 rev) = abi.decode(
                    read(
                        c.metadata,
                        abi.encodeCall(
                            M.familyWriter, (scope, StreamRecordFamilies.IDENTITY, k, actor)
                        ),
                        64,
                        c.cap
                    ),
                    (bool, uint64)
                );
                if (enabled && rev != 0) return (k, scope, rev);
            }
        }
        revert V.ViewAuthorityRequired();
    }

    function schemas(Context memory c, bytes32 viewSchema)
        public
        view
        returns (bytes32 viewHash, bytes32 manifestHash, bytes32 canonHash)
    {
        F.DocumentFacts memory viewFacts = facts(c, viewSchema);
        F.DocumentFacts memory manifest = facts(c, StreamCollectionViewFormat.SCHEMA_ID);
        F.DocumentFacts memory canon = facts(c, keccak256("RAW_BYTES"));
        if (
            !viewFacts.exists || viewFacts.status != S.DocumentStatus.ACTIVE
                || viewFacts.kind != S.DocumentKind.SCHEMA || viewFacts.contentHash == 0
        ) revert V.ViewSchemaUnavailable(viewSchema);
        if (
            !manifest.exists || manifest.status != S.DocumentStatus.ACTIVE
                || manifest.kind != S.DocumentKind.SCHEMA
                || manifest.contentHash != StreamCollectionViewFormat.hash()
                || manifest.canonicalizationId != keccak256("RAW_BYTES")
        ) revert V.ViewSchemaUnavailable(StreamCollectionViewFormat.SCHEMA_ID);
        if (
            !canon.exists || canon.status != S.DocumentStatus.ACTIVE
                || canon.kind != S.DocumentKind.CANONICALIZATION || canon.contentHash == 0
        ) revert V.ViewSchemaUnavailable(keccak256("RAW_BYTES"));
        return (viewFacts.contentHash, manifest.contentHash, canon.contentHash);
    }

    function facts(Context memory c, bytes32 id) private view returns (F.DocumentFacts memory) {
        return abi.decode(
            read(c.schemas, abi.encodeCall(F.documentFacts, (id)), 288, c.cap), (F.DocumentFacts)
        );
    }

    function pointer(Context memory c, bytes32 kind)
        private
        view
        returns (address target, bytes32 hash)
    {
        bytes memory data = read(
            c.core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, c.cap
        );
        (target, hash,,,,,,,,) = abi.decode(
            data,
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
    }

    function read(address target, bytes memory input, uint256 size, uint256 cap)
        internal
        view
        returns (bytes memory output)
    {
        if (gasleft() <= cap + cap / 63 + 10000) revert V.ViewReadFailed(target);
        output = new bytes(size);
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual != size) revert V.ViewReadFailed(target);
    }
}
