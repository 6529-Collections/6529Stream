// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityInputManifestSchemas.sol";
import "./StreamFinalityRouterEvidence.sol";
import "../../interfaces/stream/finality/StreamFinalityInputManifestTypes.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Exact registered interpretation and two-store admission of an independent manifest.
/// @dev The consuming provider supplies fixed dependencies and independently derived current
/// facts. No caller-selected input list, new latest pointer, publication authority or readiness
/// interface is introduced. This joins bytes; actual source/coverage/authority validation stays
/// mandatory in the provider, while sanction and manifest archival evidence are separate joins.
library StreamFinalityInputManifestReads {
    struct Dependencies {
        // Core, actual generic Metadata, schemas, schema Store, original Finality Registry.
        address[5] targets;
        bytes32[5] codeHashes;
        uint256 chainId;
        uint256 readGas;
    }
    error InvalidInputManifest();
    error InputManifestDependency(address target);
    error InputManifestDefinition(bytes32 id);
    error InputManifestBytes(bytes32 hash);

    function encode(Dependencies memory d, StreamFinalityInputManifestTypes.Statement memory s)
        public
        pure
        returns (bytes memory payload)
    {
        _shape(s);
        if (
            d.chainId == 0 || d.targets[0] == address(0) || d.targets[1] == address(0)
                || d.targets[4] == address(0)
        ) revert InvalidInputManifest();
        payload = abi.encode(
            StreamFinalityInputManifestSchemas.SCHEMA_ID,
            StreamFinalityInputManifestSchemas.CANON_ID,
            d.chainId,
            d.targets[0],
            d.targets[1],
            d.targets[4],
            s
        );
        if (payload.length > 8192) revert InvalidInputManifest();
    }

    function scopeInputsHash(
        Dependencies memory d,
        StreamFinalityInputManifestTypes.Statement memory s
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_SCOPE_INPUTS_V1"),
                d.chainId,
                d.targets[0],
                d.targets[1],
                s.scope,
                s.inputs
            )
        );
    }

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityInputManifestTypes.Statement memory expected,
        bytes32 contentHash
    ) public view returns (bytes32 schemaId, bytes32 canonicalizationId) {
        _bindings(d);
        bytes memory payload = encode(d, expected);
        if (contentHash == 0 || keccak256(payload) != contentHash) {
            revert InputManifestBytes(contentHash);
        }
        schemaId = StreamFinalityInputManifestSchemas.SCHEMA_ID;
        canonicalizationId = StreamFinalityInputManifestSchemas.CANON_ID;
        _definition(d, schemaId, IStreamSchemaRegistry.DocumentKind.SCHEMA);
        _definition(d, canonicalizationId, IStreamSchemaRegistry.DocumentKind.CANONICALIZATION);
        _same(
            d.targets[3],
            abi.encodeCall(StreamSchemaDocumentStore.readChunk, (contentHash)),
            payload,
            contentHash,
            d.readGas
        );
        _same(
            d.targets[4],
            abi.encodeCall(IStreamArtworkFinalityRegistry.finalityManifestBytes, (contentHash)),
            payload,
            contentHash,
            d.readGas
        );
    }

    function _same(
        address target,
        bytes memory input,
        bytes memory expected,
        bytes32 hash,
        uint256 cap
    ) private view {
        bytes memory raw = StreamFinalityRouterEvidence.dynamicRead(target, input, 8256, cap);
        bytes memory actual = abi.decode(raw, (bytes));
        if (
            keccak256(raw) != keccak256(abi.encode(actual)) || actual.length != expected.length
                || keccak256(actual) != hash
        ) revert InputManifestBytes(hash);
        // Both whole-byte digests must match the independently encoded expected document.
        if (keccak256(expected) != hash) revert InputManifestBytes(hash);
    }

    function _bindings(Dependencies memory d) private view {
        if (d.chainId != block.chainid || d.readGas < 50000 || d.readGas > type(uint256).max / 64) {
            revert InvalidInputManifest();
        }
        for (uint256 i; i < 5; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert InputManifestDependency(d.targets[i]);
            }
        }
        _address(d, 1, "core()", 0);
        _address(d, 1, "schemaRegistry()", 2);
        _address(d, 2, "chunkStore()", 3);
        _address(d, 4, "coreReads()", 0);
        _address(d, 4, "metadataReads()", 1);
    }

    function _address(Dependencies memory d, uint256 source, string memory signature, uint256 dest)
        private
        view
    {
        bytes memory raw = StreamFinalityRouterEvidence.read(
            d.targets[source], abi.encodeWithSignature(signature), 32, d.readGas
        );
        if (abi.decode(raw, (uint256)) != uint256(uint160(d.targets[dest]))) {
            revert InputManifestDependency(d.targets[source]);
        }
    }

    function _definition(Dependencies memory d, bytes32 id, IStreamSchemaRegistry.DocumentKind kind)
        private
        view
    {
        bytes memory expected = StreamFinalityInputManifestSchemas.document(id);
        bytes memory raw = StreamFinalityRouterEvidence.read(
            d.targets[2],
            abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id)),
            288,
            d.readGas
        );
        IStreamSchemaDocumentFacts.DocumentFacts memory f =
            abi.decode(raw, (IStreamSchemaDocumentFacts.DocumentFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || !f.exists || f.kind != kind
                || f.status != IStreamSchemaRegistry.DocumentStatus.ACTIVE
                || f.contentHash != keccak256(expected) || f.totalBytes != expected.length
                || f.canonicalizationId != keccak256("RAW_BYTES") || f.chunkCount != 1
                || f.declarationHash == 0
        ) revert InputManifestDefinition(id);
        _same(
            d.targets[2],
            abi.encodeCall(IStreamSchemaRegistry.documentBytes, (id)),
            expected,
            keccak256(expected),
            d.readGas
        );
    }

    function _shape(StreamFinalityInputManifestTypes.Statement memory s) private pure {
        if (
            s.scope.scopeType != StreamFinalityScopeType.COLLECTION || s.scope.collectionId == 0
                || s.scope.tokenId != 0 || s.scope.scopeId != 0 || s.coreFactsHash == 0
                || s.contentRoot == 0 || s.leafCount == 0 || s.contentRootSchemaId == 0
                || s.snapshotManifestHash == 0 || s.referenceRenderManifestHash == 0
                || s.entropyPolicy != 1 || s.postFreezePolicy != 1 || s.sanctionPolicy != 1
                || s.nonSanctionComponents.length != 9
        ) revert InvalidInputManifest();
        StreamFinalityScopeInputs memory e = s.inputs;
        if (
            e.rootRecordHash == 0 || e.snapshotRecordHash == 0 || e.referenceRenderRecordHash == 0
                || e.interviewEvidenceHash == 0 || e.rightsStatementRecordHash == 0
                || e.workDescriptionRecordHash == 0 || e.renderCriticalEvidenceHash == 0
                || e.bundleCoverageHash == 0
                || ((e.intentRecordHash == 0) == (e.intentWaiverRecordHash == 0))
        ) {
            revert InvalidInputManifest();
        }
        uint256 seen;
        for (uint256 i; i < 9; ++i) {
            StreamFinalityComponentExpectation memory c = s.nonSanctionComponents[i];
            if (
                c.component == address(0) || c.codeHash == 0 || c.interfaceId == 0
                    || c.moduleVersion == 0 || c.manifestHash == 0 || c.dataHash == 0
                    || (i != 0 && c.componentType <= s.nonSanctionComponents[i - 1].componentType)
            ) {
                revert InvalidInputManifest();
            }
            uint256 bit = _familyBit(c.componentType);
            if ((seen & bit) != 0) revert InvalidInputManifest();
            seen |= bit;
        }
        if (seen != 511) revert InvalidInputManifest();
    }

    function _familyBit(bytes32 id) private pure returns (uint256) {
        if (id == StreamFinalityDomains.COMPONENT_METADATA_ROUTER) return 1;
        if (id == StreamFinalityDomains.COMPONENT_RENDERER) return 2;
        if (id == StreamFinalityDomains.COMPONENT_RENDER_CONTEXT) return 4;
        if (id == StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST) return 8;
        if (id == StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE) return 16;
        if (id == StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE) return 32;
        if (id == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) return 64;
        if (id == StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR) return 128;
        if (id == StreamFinalityDomains.COMPONENT_REFERENCE_RENDER) return 256;
        revert InvalidInputManifest();
    }
}
