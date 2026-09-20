// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ViewCheckpointFixtureV2.sol";
import {
    StreamViewPolicyContentCheckpointV2 as Checkpoint
} from "../../smart-contracts/domains/finality/StreamViewPolicyContentCheckpointV2.sol";
import {
    StreamViewPolicyCheckpointTypesV2 as CT
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPolicyCheckpointTypesV2.sol";
import {
    StreamViewCheckpointServingV2 as Serving
} from "../../smart-contracts/domains/metadata/StreamViewCheckpointServingV2.sol";
import {
    IStreamViewCheckpointServingV2 as ServingAPI
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewCheckpointServingV2.sol";
import {
    StreamViewPayloadV2 as Payload
} from "../../smart-contracts/domains/metadata/StreamViewPayloadV2.sol";
import {
    StreamCollectionViewFormat as ViewFormat
} from "../../smart-contracts/domains/metadata/StreamCollectionViewFormat.sol";
import {
    IStreamCollectionViews as Views
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamRendererRegistry as Registry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as Facts
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamPreservationRecords as P
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamCollectionMetadataV1 as Metadata
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamViewSourceBinding as VB
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    IStreamViewPolicySourceBindingV2 as PB
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPolicySourceBindingV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as PolicyReads
} from "../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamViewAdoptionReads as Read
} from "../../smart-contracts/domains/metadata/StreamViewAdoptionReads.sol";

contract OutputViewRecordProbe is CheckpointViewRecordProbe {
    constructor(address c, Store s) CheckpointViewRecordProbe(c, s) { }

    function governanceAuthority() external view returns (address) {
        return core;
    }
}

/// @dev Actual checkpoint/current reader/Documents/State/Store/Renderer/serving adapter.
/// Core, Artist, Metadata, Schema, Registry, Membership and factory/set remain exact-input
/// typed replies. This does not prove their governance, publication or complete ceremony.
abstract contract ViewOutputCheckpointFixtureV2 is ViewCheckpointFixtureV2 {
    Checkpoint internal checkpointHost;
    Serving internal serving;
    Renderer internal renderer;
    CT.Configuration internal config;
    bytes32 internal adopted;
    bytes32 internal declared;

    function _build(uint256 count, uint256 burnedToken) internal {
        records = new OutputViewRecordProbe(address(core), store);
        membership.tokenCount = count;
        membership.tokenListHash = count == 1
            ? keccak256(abi.encode(uint256(11)))
            : keccak256(abi.encode(uint256(11), uint256(22), uint256(33)));
        _answer(sourceSet, "scopeMembershipFacts()", "", abi.encode(membership));
        for (uint256 i; i < count; ++i) {
            _token(11 * (i + 1), i, 11 * (i + 1) == burnedToken);
        }
        (renderer, adopted) = _renderer();
        V.Record memory r = abi.decode(records.encoded(adopted), (V.Record));
        r.recordHash = 0;
        r.input.expectedPrevious = adopted;
        r.source.route.schemas = address(core);
        r.source.route.schemasCodeHash = address(core).codehash;
        _roster(r);
        _documents(r);
        r.sourceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_ADOPTION_SOURCE_V2"),
                T.PROFILE,
                block.chainid,
                address(records),
                r.input.scope,
                r.input.viewId,
                r.input.viewRecordHash,
                r.source,
                renderer.policyViewBinding()
            )
        );
        r.input.expectedSourceHash = r.sourceHash;
        adopted =
            records.write(r, keccak256("typed original op17 consent with complete source"), true);
        serving = new Serving(
            ServingAPI.Binding(
                address(core),
                address(core).codehash,
                address(records),
                address(records).codehash,
                block.chainid,
                8000000
            )
        );
        config = CT.Configuration(
            address(core),
            address(core).codehash,
            address(records),
            address(records).codehash,
            address(core),
            address(core).codehash,
            address(serving),
            address(serving).codehash,
            serving.configurationHash(),
            block.chainid,
            1000000,
            10000000
        );
        checkpointHost = new Checkpoint(config);
    }

    function _token(uint256 token, uint256 index, bool burned) internal {
        _answer(
            core,
            "scopeTokenAt((uint8,uint256,uint256,bytes32),uint256)",
            abi.encode(scope, index),
            abi.encode(token)
        );
        _answer(
            core,
            "scopeCoversToken((uint8,uint256,uint256,bytes32),uint256)",
            abi.encode(scope, token),
            abi.encode(true)
        );
        _answer(
            core,
            "tokenCollectionIdentity(uint256)",
            abi.encode(token),
            abi.encode(true, uint256(1), uint256(7 + index * 3), burned)
        );
        _answer(
            core, "tokenLifecycle(uint256)", abi.encode(token), abi.encode(uint8(burned ? 3 : 2))
        );
        _answer(
            core, "coordinatorAtMint(uint256)", abi.encode(token), abi.encode(address(coordinator))
        );
        _answer(core, "tokenData(uint256)", abi.encode(token), abi.encode(hex"00f1ff00"));
        uint8 status =
            rule.collectionPolicy.renderRequirement == 0
            ? 5
            : rule.collectionPolicy.mode == 0 ? 1 : 2;
        bytes32 seed =
            status == 5 ? keccak256(abi.encode("genuine typed finalized seed", token)) : bytes32(0);
        _answer(
            coordinator,
            "staticTerminalEntropyFacts(uint256)",
            abi.encode(token),
            abi.encode(uint256(1), rule.collectionPolicy, status, seed, bytes32(0))
        );
        _answer(
            coordinator,
            "staticTokenRenderFacts(uint256)",
            abi.encode(token),
            abi.encode(status, seed, address(0x992))
        );
        _answer(
            attribution,
            "attribution(uint256,uint256)",
            abi.encode(uint256(1), token),
            abi.encode(bytes('{"state":"typed_live"}'))
        );
    }

    function _roster(V.Record memory r) private {
        _pointer("MODULE_REGISTRY", address(core));
        _answer(core, "finalityRegistry()", "", abi.encode(address(core)));
        _answer(core, "finalityRegistryCodeHash()", "", abi.encode(address(core).codehash));
        _answer(
            core,
            "gasParameter(bytes32)",
            abi.encode(keccak256("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS")),
            abi.encode(uint256(1000000))
        );
        string[8] memory getters = [
            "coreReads()",
            "sanctionReads()",
            "scopeEvidenceProvider()",
            "metadataReads()",
            "metadataHost()",
            "governanceAuthority()",
            "core()",
            "schemaRegistry()"
        ];
        for (uint256 i; i < getters.length; ++i) {
            _answer(core, getters[i], "", abi.encode(address(core)));
        }
        _answer(core, "chunkStore()", "", abi.encode(address(store)));
        _answer(core, "collectionExists(uint256)", abi.encode(uint256(1)), abi.encode(true));
        _answer(
            core,
            "requireScopeMembership((uint8,uint256,uint256,bytes32))",
            abi.encode(scope),
            abi.encode(membership)
        );
        _answer(
            core, "supportsInterface(bytes4)", abi.encode(type(VB).interfaceId), abi.encode(true)
        );
        _answer(
            core, "supportsInterface(bytes4)", abi.encode(type(PB).interfaceId), abi.encode(true)
        );
        _answer(core, "viewPolicySourceFactoryV2()", "", abi.encode(address(factory)));
        _answer(
            core, "viewPolicySourceFactoryV2CodeHash()", "", abi.encode(address(factory).codehash)
        );
        PolicyReads.Dependencies memory d;
        for (uint256 i; i < 4; ++i) {
            d.targets[i] = address(core);
            d.codeHashes[i] = address(core).codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 1000000;
        d.inventoryGas = 2000000;
        _answer(factory, "dependencies()", "", abi.encode(d));
        _answer(
            core,
            "isModuleEligible(address,bytes32,bytes4)",
            abi.encode(address(core), keccak256("COLLECTION_METADATA"), type(Metadata).interfaceId),
            abi.encode(true)
        );
        _answer(
            core,
            "isModuleEligible(address,bytes32,bytes4)",
            abi.encode(address(core), keccak256("COLLECTION_VIEWS"), type(Views).interfaceId),
            abi.encode(true)
        );
        _answer(
            core,
            "isModuleEligible(address,bytes32,bytes4)",
            abi.encode(address(core), keccak256("RENDERER_REGISTRY"), type(Registry).interfaceId),
            abi.encode(true)
        );
        _answer(core, "viewSourceBinding()", "", abi.encode(r.source.route.binding));
    }

    function _documents(V.Record memory r) private {
        bytes memory payload = abi.encode(
            V.Payload(
                T.CONTEXT,
                "policy view",
                "full source",
                "",
                bytes("window.done=stream.entropy.terminal;")
            )
        );
        (bytes32 payloadHash, address payloadPointer) = store.publishChunk(payload);
        _definition(Payload.SCHEMA_ID, Schema.DocumentKind.SCHEMA, bytes(Payload.DEFINITION));
        _definition(ViewFormat.SCHEMA_ID, Schema.DocumentKind.SCHEMA, ViewFormat.definition());
        bytes memory rawDefinition = bytes("typed RAW_BYTES definition");
        _definition(keccak256("RAW_BYTES"), Schema.DocumentKind.CANONICALIZATION, rawDefinition);
        r.source.schemaHash = Payload.schemaHash();
        r.source.manifestSchemaHash = ViewFormat.hash();
        r.source.canonicalizationHash = keccak256(rawDefinition);
        Views.CollectionViewManifest memory m = Views.CollectionViewManifest(
            r.input.viewId, Payload.SCHEMA_ID, "", payloadHash, "application/octet-stream", false
        );
        Views.ViewReceipt memory receipt = Views.ViewReceipt(
            1,
            r.input.viewId,
            1,
            0,
            address(this),
            7,
            1,
            1,
            uint64(block.timestamp),
            0,
            keccak256("history"),
            Payload.schemaHash(),
            ViewFormat.hash(),
            keccak256(rawDefinition)
        );
        bytes memory carrier = abi.encode(uint256(1), uint64(1), bytes32(0), m);
        (bytes32 carrierHash, address pointer) = store.publishChunk(carrier);
        P.CollectionRecord memory record;
        record.recordType = keccak256("DISPLAY_VIEW_MANIFEST");
        record.subjectId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_SCOPE_V1"),
                block.chainid,
                address(core),
                uint256(1),
                uint8(4),
                r.input.viewId
            )
        );
        record.contentHash = P.HashRef(1, abi.encode(carrierHash), keccak256("RAW_BYTES"));
        record.schemaId = ViewFormat.SCHEMA_ID;
        declared = keccak256(
            abi.encode(
                keccak256("6529stream.preservation-record.v2"),
                block.chainid,
                address(core),
                address(core),
                address(this),
                uint256(1),
                record.recordType,
                record.subjectId,
                keccak256(
                    abi.encode(
                        uint16(1), keccak256(record.contentHash.digest), keccak256("RAW_BYTES")
                    )
                ),
                keccak256(bytes("")),
                ViewFormat.SCHEMA_ID,
                bytes32(0),
                keccak256(abi.encode(uint16(0), keccak256(bytes("")), bytes32(0))),
                uint64(0)
            )
        );
        r.input.viewRecordHash = declared;
        r.source.manifestPayloadHash = carrierHash;
        r.source.viewReceiptHash = keccak256(abi.encode(receipt));
        _answer(
            core,
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), r.input.viewId),
            abi.encode(declared, false)
        );
        _answer(core, "viewRecord(bytes32)", abi.encode(declared), abi.encode(m, receipt, record));
        _answer(
            core,
            "recordHashAt(uint256,uint256)",
            abi.encode(uint256(1), uint256(0)),
            abi.encode(declared)
        );
        _answer(
            core, "manifestPayload(bytes32)", abi.encode(declared), abi.encode(pointer, carrier)
        );
        _answer(
            core, "viewPayload(bytes32)", abi.encode(declared), abi.encode(payloadPointer, payload)
        );
        R.RendererManifest memory manifest = renderer.rendererManifest();
        r.input.rendererRegistry = address(core);
        r.input.rendererVersionKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_VERSION_V1"),
                manifest.rendererId,
                manifest.rendererVersion
            )
        );
        Registry.Version memory version = Registry.Version(
            true,
            false,
            address(renderer),
            address(renderer).codehash,
            keccak256("registration"),
            keccak256("reads"),
            keccak256("analysis"),
            keccak256("golden"),
            keccak256("action")
        );
        Registry.Registration memory reg;
        reg.renderer = address(renderer);
        reg.manifest = manifest;
        _answer(
            core, "version(bytes32)", abi.encode(r.input.rendererVersionKey), abi.encode(version)
        );
        _answer(
            core, "registration(bytes32)", abi.encode(r.input.rendererVersionKey), abi.encode(reg)
        );
        _answer(
            core,
            "requireAssignable(bytes32)",
            abi.encode(r.input.rendererVersionKey),
            abi.encode(address(renderer), address(renderer).codehash)
        );
        _answer(
            core,
            "requireRetained(bytes32)",
            abi.encode(r.input.rendererVersionKey),
            abi.encode(address(renderer), address(renderer).codehash)
        );
        r.source.renderer.versionKey = r.input.rendererVersionKey;
        r.source.renderer.rendererId = manifest.rendererId;
        r.source.renderer.rendererVersion = manifest.rendererVersion;
        r.source.renderer.schemaHash = manifest.schemaHash;
        r.source.renderer.readSetHash = version.readSetHash;
        r.source.renderer.registrationHash = version.registrationHash;
    }

    function _definition(bytes32 id, Schema.DocumentKind kind, bytes memory body) private {
        _answer(
            core,
            "documentFacts(bytes32)",
            abi.encode(id),
            abi.encode(
                Facts.DocumentFacts(
                    true,
                    kind,
                    Schema.DocumentStatus.ACTIVE,
                    keccak256(body),
                    keccak256("RAW_BYTES"),
                    0,
                    uint32(body.length),
                    1,
                    keccak256("typed active document")
                )
            )
        );
        _answer(core, "documentBytes(bytes32)", abi.encode(id), abi.encode(body));
    }

    function _payload(uint256 token, bool burned)
        internal
        view
        returns (bytes memory json, bytes memory html)
    {
        string memory j;
        string memory h;
        if (burned) {
            (, j) = serving.historicalOutput(adopted, token, 2);
            (, h) = serving.historicalOutput(adopted, token, 3);
        } else {
            (, j) = serving.currentOutput(scope, token, 2);
            (, h) = serving.currentOutput(scope, token, 3);
        }
        return (bytes(j), bytes(h));
    }

    function _append(bytes32 id, uint256 token, bool burned) internal {
        (bytes memory json, bytes memory html) = _payload(token, burned);
        checkpointHost.append(id, token, json, html);
    }
}
