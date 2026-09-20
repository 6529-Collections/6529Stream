// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    IStreamCollectionViews as D
} from "../../interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamPreservationRecords as P
} from "../../interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as Facts
} from "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamRendererRegistry as Registry
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import { IStreamRenderer as Renderer } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamStaticMetadataRouter as Static
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    StreamCollectionRecordHashes as Hashes
} from "../records/StreamCollectionRecordHashes.sol";
import { StreamViewAdoptionReads as Read } from "./StreamViewAdoptionReads.sol";
import { StreamViewPayloadBytes as PayloadBytes } from "./StreamViewPayloadBytes.sol";
import { StreamViewPayloadV1 as Payload } from "./StreamViewPayloadV1.sol";
import { StreamViewRendererFormat as Output } from "./StreamViewRendererFormat.sol";
import {
    IStreamViewRendererV1 as ViewRenderer
} from "../../interfaces/stream/metadata/IStreamViewRendererV1.sol";
import { StreamCollectionViewFormat as Format } from "./StreamCollectionViewFormat.sol";

/// @notice Authenticates the original declaration, full bytes and separately governed renderer.
library StreamViewAdoptionDocuments {
    function load(V.Route memory route, V.Input memory p, address authority)
        public
        view
        returns (V.Source memory s)
    {
        s.route = route;
        _declaration(s, p);
        s.renderer = _renderer(route, p, authority);
    }

    function _declaration(V.Source memory s, V.Input memory p) private view {
        address host = s.route.binding.views;
        uint256 cap = s.route.binding.sourceGas;
        (bytes32 current,) = abi.decode(
            Read.read(
                host,
                abi.encodeCall(D.selectedViewRecord, (p.scope.collectionId, p.viewId)),
                64,
                s.route.binding.readGas
            ),
            (bytes32, bool)
        );
        if (current == 0 || current != p.viewRecordHash) revert V.InvalidViewAdoption();
        bytes memory raw =
            Read.bounded(host, abi.encodeCall(D.viewRecord, (current)), 16384, cap, false);
        (
            D.CollectionViewManifest memory m,
            D.ViewReceipt memory receipt,
            P.CollectionRecord memory record
        ) = abi.decode(raw, (D.CollectionViewManifest, D.ViewReceipt, P.CollectionRecord));
        if (
            keccak256(raw) != keccak256(abi.encode(m, receipt, record))
                || receipt.collectionId != p.scope.collectionId || receipt.viewId != p.viewId
                || m.viewId != p.viewId || receipt.revision == 0 || receipt.recorder == address(0)
                || receipt.grantRevision == 0
                || (receipt.authorizationClass != 7 && receipt.authorizationClass != 8)
                || (receipt.grantCollectionId != 0
                    && receipt.grantCollectionId != p.scope.collectionId)
                || receipt.recordedAt > block.timestamp || m.schemaId != Payload.SCHEMA_ID
                || keccak256(bytes(m.mimeType)) != keccak256("application/octet-stream")
        ) revert V.InvalidViewAdoption();
        s.schemaHash =
            _definition(s.route, m.schemaId, Schema.DocumentKind.SCHEMA, Payload.schemaHash());
        s.manifestSchemaHash =
            _definition(s.route, Format.SCHEMA_ID, Schema.DocumentKind.SCHEMA, Format.hash());
        s.canonicalizationHash =
            _definition(s.route, keccak256("RAW_BYTES"), Schema.DocumentKind.CANONICALIZATION, 0);
        if (
            receipt.viewSchemaDefinitionHash != s.schemaHash
                || receipt.manifestSchemaDefinitionHash != s.manifestSchemaHash
                || receipt.canonicalizationDefinitionHash != s.canonicalizationHash
        ) revert V.InvalidViewAdoption();
        bytes memory carrier =
            abi.encode(p.scope.collectionId, receipt.revision, receipt.previousRecordHash, m);
        s.manifestPayloadHash = keccak256(carrier);
        if (
            record.recordType != keccak256("DISPLAY_VIEW_MANIFEST")
                || record.subjectId
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SUBJECT_SCOPE_V1"),
                            block.chainid,
                            s.route.core,
                            p.scope.collectionId,
                            uint8(4),
                            p.viewId
                        )
                    ) || record.schemaId != Format.SCHEMA_ID || record.contentHash.algorithm != 1
                || record.contentHash.canonicalizationId != keccak256("RAW_BYTES")
                || keccak256(record.contentHash.digest)
                    != keccak256(abi.encode(s.manifestPayloadHash))
                || keccak256(bytes(record.uri)) != keccak256(bytes(m.uri))
                || record.signatureScheme != 0 || record.signatureHash.algorithm != 0
                || record.signatureHash.digest.length != 0
                || record.signatureHash.canonicalizationId != 0 || record.effectiveAt != 0
        ) revert V.InvalidViewAdoption();
        Hashes.Preimage memory q = Hashes.Preimage(
            Hashes.RECORD_DOMAIN,
            block.chainid,
            host,
            s.route.core,
            receipt.recorder,
            p.scope.collectionId,
            record.recordType,
            record.subjectId,
            Hashes.hashRef(
                record.contentHash.algorithm,
                record.contentHash.digest,
                record.contentHash.canonicalizationId
            ),
            keccak256(bytes(record.uri)),
            record.schemaId,
            0,
            Hashes.hashRef(0, bytes(""), 0),
            0
        );
        if (
            keccak256(abi.encode(q)) != current
                || bytes32(
                        Read.word(
                            host,
                            abi.encodeCall(
                                D.recordHashAt, (p.scope.collectionId, receipt.recordIndex)
                            ),
                            s.route.binding.readGas
                        )
                    ) != current
        ) revert V.InvalidViewAdoption();
        bytes memory encoded =
            Read.bounded(host, abi.encodeCall(D.manifestPayload, (current)), 8320, cap, false);
        (address pointer, bytes memory saved) = abi.decode(encoded, (address, bytes));
        if (
            keccak256(encoded) != keccak256(abi.encode(pointer, saved))
                || keccak256(saved) != s.manifestPayloadHash || saved.length != carrier.length
        ) revert V.InvalidViewAdoption();
        PayloadBytes.verify(pointer, s.manifestPayloadHash, saved.length);
        encoded =
            Read.bounded(
            host, abi.encodeCall(D.viewPayload, (current)), V.MAX_PAYLOAD + 128, cap, false
        );
        (pointer, saved) = abi.decode(encoded, (address, bytes));
        if (
            keccak256(encoded) != keccak256(abi.encode(pointer, saved))
                || keccak256(saved) != m.contentHash
        ) revert V.InvalidViewAdoption();
        Payload.requireAdmissible(saved);
        PayloadBytes.capture(s.route.store, saved, s);
        if (pointer != s.payloadPointers[0]) revert V.InvalidViewAdoption();
        s.viewReceiptHash = keccak256(abi.encode(receipt));
    }

    function _definition(V.Route memory r, bytes32 id, Schema.DocumentKind kind, bytes32 expected)
        private
        view
        returns (bytes32)
    {
        bytes memory raw =
            Read.read(r.schemas, abi.encodeCall(Facts.documentFacts, (id)), 288, r.binding.readGas);
        Facts.DocumentFacts memory f = abi.decode(raw, (Facts.DocumentFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || !f.exists
                || f.status != Schema.DocumentStatus.ACTIVE || f.kind != kind || f.contentHash == 0
                || f.totalBytes == 0 || f.totalBytes > 8192
                || (expected != 0 && f.contentHash != expected)
                || (kind == Schema.DocumentKind.SCHEMA
                    && f.canonicalizationId != keccak256("RAW_BYTES"))
        ) revert V.InvalidViewAdoption();
        raw = Read.bounded(
            r.schemas, abi.encodeCall(Schema.documentBytes, (id)), 8288, r.binding.sourceGas, false
        );
        bytes memory body = abi.decode(raw, (bytes));
        if (
            keccak256(raw) != keccak256(abi.encode(body)) || body.length != f.totalBytes
                || keccak256(body) != f.contentHash
        ) revert V.InvalidViewAdoption();
        return f.contentHash;
    }

    function _renderer(V.Route memory r, V.Input memory p, address authority)
        private
        view
        returns (Static.Selection memory s)
    {
        uint256 cap = r.binding.readGas;
        Read.pin(p.rendererRegistry, p.rendererRegistry.codehash);
        (address modules,) = Read.selected(r.core, keccak256("MODULE_REGISTRY"), cap);
        Read.eligible(
            modules,
            p.rendererRegistry,
            keccak256("RENDERER_REGISTRY"),
            type(Registry).interfaceId,
            cap
        );
        if (
            Read.addr(p.rendererRegistry, abi.encodeWithSignature("governanceAuthority()"), cap)
                    != authority
                || Read.addr(p.rendererRegistry, abi.encodeWithSignature("schemaRegistry()"), cap)
                    != r.schemas
        ) revert V.InvalidViewAdoption();
        bytes memory raw = Read.read(
            p.rendererRegistry, abi.encodeCall(Registry.version, (p.rendererVersionKey)), 288, cap
        );
        Registry.Version memory v = abi.decode(raw, (Registry.Version));
        if (
            keccak256(raw) != keccak256(abi.encode(v)) || !v.exists || v.deprecated
                || v.registrationHash == 0 || v.readSetHash == 0
        ) revert V.InvalidViewAdoption();
        Read.pin(v.renderer, v.runtimeHash);
        if (
            Read.word(
                    v.renderer,
                    abi.encodeCall(IERC165.supportsInterface, (type(ViewRenderer).interfaceId)),
                    cap
                ) != 1
        ) revert V.InvalidViewAdoption();
        bytes memory bindingRaw =
            Read.read(v.renderer, abi.encodeCall(ViewRenderer.sourceBindings, ()), 256, cap);
        (address[4] memory targets, bytes32[4] memory pins) =
            abi.decode(bindingRaw, (address[4], bytes32[4]));
        if (
            keccak256(bindingRaw) != keccak256(abi.encode(targets, pins)) || targets[0] != r.core
                || targets[1] != r.router || pins[0] != r.coreCodeHash
                || pins[1] != r.routerCodeHash
        ) revert V.InvalidViewAdoption();
        for (uint256 i; i < 4; ++i) {
            Read.pin(targets[i], pins[i]);
        }
        raw = Read.bounded(
            p.rendererRegistry,
            abi.encodeCall(Registry.registration, (p.rendererVersionKey)),
            9216,
            r.binding.sourceGas,
            false
        );
        Registry.Registration memory saved = abi.decode(raw, (Registry.Registration));
        if (keccak256(raw) != keccak256(abi.encode(saved)) || saved.renderer != v.renderer) {
            revert V.InvalidViewAdoption();
        }
        raw = Read.bounded(
            v.renderer, abi.encodeCall(Renderer.rendererManifest, ()), 4576, cap, false
        );
        Renderer.RendererManifest memory m = abi.decode(raw, (Renderer.RendererManifest));
        if (
            keccak256(raw) != keccak256(abi.encode(m))
                || keccak256(abi.encode(m)) != keccak256(abi.encode(saved.manifest))
                || m.rendererClass != keccak256("STATIC") || m.deprecated
                || m.contextVersion != V.CONTEXT || m.schemaHash != Output.schemaHash()
                || p.rendererVersionKey
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDERER_VERSION_V1"),
                            m.rendererId,
                            m.rendererVersion
                        )
                    )
        ) revert V.InvalidViewAdoption();
        (address renderer, bytes32 hash) = abi.decode(
            Read.read(
                p.rendererRegistry,
                abi.encodeCall(Registry.requireAssignable, (p.rendererVersionKey)),
                64,
                cap
            ),
            (address, bytes32)
        );
        if (renderer != v.renderer || hash != v.runtimeHash) revert V.InvalidViewAdoption();
        s = Static.Selection(
            p.rendererRegistry,
            p.rendererRegistry.codehash,
            p.rendererVersionKey,
            v.renderer,
            v.runtimeHash,
            m.rendererId,
            m.rendererVersion,
            m.contextVersion,
            m.schemaHash,
            v.readSetHash,
            v.registrationHash
        );
    }
}
