// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamFinalityViewSourceReads as Reader
} from "../../../smart-contracts/domains/finality/StreamFinalityViewSourceReads.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamViewAdoptionState as State
} from "../../../smart-contracts/domains/metadata/StreamViewAdoptionState.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamViewPayloadBytes as Bytes
} from "../../../smart-contracts/domains/metadata/StreamViewPayloadBytes.sol";
import {
    StreamViewPayloadV1 as Payload
} from "../../../smart-contracts/domains/metadata/StreamViewPayloadV1.sol";
import {
    StreamCollectionViewFormat as Format
} from "../../../smart-contracts/domains/metadata/StreamCollectionViewFormat.sol";
import {
    StreamViewRendererFormat as Output
} from "../../../smart-contracts/domains/metadata/StreamViewRendererFormat.sol";
import {
    IStreamCollectionViews as Views
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamRendererRegistry as Registry
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as Facts
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamPreservationRecords as P
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamViewRendererV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamViewRendererV1.sol";
import {
    IStreamViewSourceBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewSourceBinding.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamStaticMetadataRouter
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamCollectionMetadataV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

/// @dev Exact-input read boundary for Core/Artist/Metadata/Views/Registry/Schema/Membership.
/// No actual admission, publisher authority, Artist signature or complete governance claim.
contract ViewSourceCallBoundary {
    mapping(bytes32 => bytes) private data;

    function answer(bytes memory input, bytes memory output) external {
        data[keccak256(input)] = output;
    }

    fallback() external {
        bytes memory out = data[keccak256(msg.data)];
        require(out.length != 0, "unconfigured source read");
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }
}

/// @dev Actual original State.commit and Store carrier, with explicit adversarial test setters.
contract ViewSourceCarrierBoundary {
    address public immutable core;
    Store public immutable store;

    constructor(address c, Store s) {
        core = c;
        store = s;
    }

    function commit(V.Record memory r) external returns (bytes32) {
        return State.commit(core, r, keccak256("typed original op17 receipt"));
    }

    function viewAdoptionCarrier(bytes32 key) external view returns (address, bytes32, uint32) {
        State.Carrier storage c = State.state().records[key];
        return (c.pointer, c.hash, c.size);
    }

    function viewAdoptionHead(StreamFinalityScope memory scope) external view returns (bytes32) {
        return State.state().heads[State.subject(core, scope)];
    }

    function encoded(bytes32 key) external view returns (bytes memory) {
        return State.encoded(key);
    }

    function forceHead(StreamFinalityScope memory scope, bytes32 key) external {
        State.state().heads[State.subject(core, scope)] = key;
    }

    function substitute(bytes32 key, bytes memory raw) external {
        (bytes32 h, address p) = store.publishChunk(raw);
        State.state().records[key] = State.Carrier(p, h, uint32(raw.length));
    }
}

/// @notice Actual reader/Documents/State/Store, literal preimages and exact typed dependency
/// replies. This is source-join coverage, not actual governed declaration/renderer admission.
contract StreamFinalityViewSourceReadsTest is CharacterizationTestBase {
    ViewSourceCallBoundary private graph;
    ViewSourceCarrierBoundary private router;
    Store private store;
    Reader.Dependencies private deps;
    V.Record private original;
    bytes32 private key;
    bytes private originalBytes;

    function setUp() public {
        vm.warp(1000);
        graph = new ViewSourceCallBoundary();
        store = new Store();
        router = new ViewSourceCarrierBoundary(address(graph), store);
        Reader.Dependencies memory d;
        for (uint256 i; i < 7; ++i) {
            d.targets[i] = i == 1 ? address(router) : address(graph);
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.binding = V.Binding(
            address(graph),
            address(graph).codehash,
            address(graph),
            address(graph).codehash,
            500000,
            3000000
        );
        deps = d;
        V.Record memory r;
        r.input.scope = StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 1, 0, keccak256("sealed VIEW membership")
        );
        r.input.viewId = keccak256("independent original view declaration id");
        r.input.rendererRegistry = address(graph);
        r.source.route = _route(d);
        _roster(d);
        _documents(r);
        r.source.membership.scopeSubject = _subject(r.input.scope);
        r.source.membership.scopeManifestHash = keccak256("scope manifest");
        r.source.membership.sourceRecordHash = keccak256("scope original record");
        r.source.membership.tokenCount = 2;
        r.source.membership.tokenListHash = keccak256(abi.encode(uint256(3), uint256(9)));
        r.source.membership.membershipHash = keccak256("complete sealed membership");
        _answer(
            "requireScopeMembership((uint8,uint256,uint256,bytes32))",
            abi.encode(r.input.scope),
            abi.encode(r.source.membership)
        );
        r.sourceHash = _sourceHash(r);
        r.input.expectedSourceHash = r.sourceHash;
        r.actor = address(this);
        r.authorizationClass = 7;
        r.grantCollectionId = 1;
        r.grantRevision = 2;
        key = router.commit(r);
        originalBytes = router.encoded(key);
        original = abi.decode(originalBytes, (V.Record));
    }

    function testExactOriginalRecordSourceAndCurrentWholeSourceJoin() public view {
        V.Record memory saved = Reader.retained(deps, key);
        require(keccak256(abi.encode(saved)) == keccak256(originalBytes));
        require(saved.sourceHash == _sourceHash(saved));
        saved.recordHash = 0;
        require(
            key
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_ADOPTION_RECORD_V1"),
                        block.chainid,
                        address(router),
                        address(graph),
                        saved
                    )
                )
        );
        V.Record memory current = Reader.requireCurrent(deps, original.input.scope);
        require(keccak256(abi.encode(current)) == keccak256(originalBytes));
        // collectionFreezeStatus/familyWriter are intentionally unconfigured. Current reading
        // authenticates the adopted immutable source without trying a new mutable publication.
    }

    function testRetainedCarrierSurvivesHeadDriftButCannotBecomeCurrent() public {
        router.forceHead(original.input.scope, keccak256("missing new current head"));
        vm.expectRevert();
        Reader.requireCurrent(deps, original.input.scope);
        require(Reader.retained(deps, key).recordHash == key);
        router.forceHead(original.input.scope, key);
        Reader.requireCurrent(deps, original.input.scope);
    }

    function testCanonicalCarrierAndOriginalConsentPreimageCannotBeSubstituted() public {
        V.Record memory changed = abi.decode(originalBytes, (V.Record));
        changed.artistConsent ^= bytes32(uint256(1));
        router.substitute(key, abi.encode(changed));
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        Reader.retained(deps, key);
        router.substitute(key, bytes.concat(originalBytes, abi.encode(uint256(0))));
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        Reader.retained(deps, key);
        router.substitute(key, originalBytes);
        Reader.requireCurrent(deps, original.input.scope);
    }

    function testMembershipAndDeclarationChangesRefuseWhileOriginalBytesRemain() public {
        V.Record memory saved = abi.decode(originalBytes, (V.Record));
        saved.source.membership.tokenCount += 1;
        _answer(
            "requireScopeMembership((uint8,uint256,uint256,bytes32))",
            abi.encode(saved.input.scope),
            abi.encode(saved.source.membership)
        );
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        Reader.requireCurrent(deps, saved.input.scope);
        _answer(
            "requireScopeMembership((uint8,uint256,uint256,bytes32))",
            abi.encode(saved.input.scope),
            abi.encode(original.source.membership)
        );
        _answer(
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), saved.input.viewId),
            abi.encode(keccak256("later declaration"), false)
        );
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        Reader.requireCurrent(deps, saved.input.scope);
        require(keccak256(abi.encode(Reader.retained(deps, key))) == keccak256(originalBytes));
        _answer(
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), saved.input.viewId),
            abi.encode(saved.input.viewRecordHash, false)
        );
        Reader.requireCurrent(deps, saved.input.scope);
    }

    function testCurrentSelectedArtistAndSchemaDriftFailAndRestore() public {
        _selected(keccak256("ARTIST_REGISTRY"), address(store));
        vm.expectRevert();
        Reader.requireCurrent(deps, original.input.scope);
        _selected(keccak256("ARTIST_REGISTRY"), address(graph));
        _definition(Payload.SCHEMA_ID, Schema.DocumentKind.SCHEMA, bytes("substituted schema"));
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        Reader.requireCurrent(deps, original.input.scope);
        _definition(Payload.SCHEMA_ID, Schema.DocumentKind.SCHEMA, bytes(Payload.DEFINITION));
        Reader.requireCurrent(deps, original.input.scope);
    }

    function testRendererRegistrationAndRecordHostChainDomainsCannotSubstitute() public {
        Registry.Version memory v = _version();
        v.readSetHash ^= bytes32(uint256(1));
        _answer("version(bytes32)", abi.encode(original.input.rendererVersionKey), abi.encode(v));
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        Reader.requireCurrent(deps, original.input.scope);
        _answer(
            "version(bytes32)",
            abi.encode(original.input.rendererVersionKey),
            abi.encode(_version())
        );
        Reader.Dependencies memory d = deps;
        d.targets[1] = address(graph);
        d.codeHashes[1] = address(graph).codehash;
        vm.expectRevert();
        Reader.retained(d, key);
        uint256 chain = deps.chainId; // Captured before cheatcode chain mutation, in fixture storage.
        vm.chainId(chain + 1);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        Reader.retained(deps, key);
        vm.chainId(chain);
        Reader.requireCurrent(deps, original.input.scope);
    }

    function _documents(V.Record memory r) private {
        bytes memory payload = abi.encode(
            V.Payload(V.CONTEXT, "view", "description", "", bytes("window.view = tokenId;"))
        );
        (bytes32 payloadHash, address payloadPointer) = store.publishChunk(payload);
        Bytes.capture(address(store), payload, r.source);
        _definition(Payload.SCHEMA_ID, Schema.DocumentKind.SCHEMA, bytes(Payload.DEFINITION));
        _definition(Format.SCHEMA_ID, Schema.DocumentKind.SCHEMA, Format.definition());
        bytes memory rawDefinition = bytes("typed RAW_BYTES definition");
        _definition(keccak256("RAW_BYTES"), Schema.DocumentKind.CANONICALIZATION, rawDefinition);
        r.source.schemaHash = Payload.schemaHash();
        r.source.manifestSchemaHash = Format.hash();
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
            1000,
            0,
            keccak256("history"),
            Payload.schemaHash(),
            Format.hash(),
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
                address(graph),
                uint256(1),
                uint8(4),
                r.input.viewId
            )
        );
        record.contentHash = P.HashRef(1, abi.encode(carrierHash), keccak256("RAW_BYTES"));
        record.schemaId = Format.SCHEMA_ID;
        r.input.viewRecordHash = keccak256(
            abi.encode(
                keccak256("6529stream.preservation-record.v2"),
                block.chainid,
                address(graph),
                address(graph),
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
                Format.SCHEMA_ID,
                bytes32(0),
                keccak256(abi.encode(uint16(0), keccak256(bytes("")), bytes32(0))),
                uint64(0)
            )
        );
        r.source.manifestPayloadHash = carrierHash;
        r.source.viewReceiptHash = keccak256(abi.encode(receipt));
        _answer(
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), r.input.viewId),
            abi.encode(r.input.viewRecordHash, false)
        );
        _answer(
            "viewRecord(bytes32)",
            abi.encode(r.input.viewRecordHash),
            abi.encode(m, receipt, record)
        );
        _answer(
            "recordHashAt(uint256,uint256)",
            abi.encode(uint256(1), uint256(0)),
            abi.encode(r.input.viewRecordHash)
        );
        _answer(
            "manifestPayload(bytes32)",
            abi.encode(r.input.viewRecordHash),
            abi.encode(pointer, carrier)
        );
        _answer(
            "viewPayload(bytes32)",
            abi.encode(r.input.viewRecordHash),
            abi.encode(payloadPointer, payload)
        );
        R.RendererManifest memory manifest = R.RendererManifest(
            Output.ID,
            Output.VERSION,
            V.CONTEXT,
            keccak256("STATIC"),
            Output.schemaHash(),
            "",
            "",
            keccak256("renderer manifest"),
            262144,
            262144,
            false
        );
        r.input.rendererVersionKey = keccak256(
            abi.encode(keccak256("6529STREAM_RENDERER_VERSION_V1"), Output.ID, Output.VERSION)
        );
        Registry.Version memory version = _version();
        Registry.Registration memory reg;
        reg.renderer = address(graph);
        reg.manifest = manifest;
        _answer("version(bytes32)", abi.encode(r.input.rendererVersionKey), abi.encode(version));
        _answer("registration(bytes32)", abi.encode(r.input.rendererVersionKey), abi.encode(reg));
        _answer("rendererManifest()", bytes(""), abi.encode(manifest));
        _answer(
            "requireAssignable(bytes32)",
            abi.encode(r.input.rendererVersionKey),
            abi.encode(address(graph), address(graph).codehash)
        );
        _answer(
            "sourceBindings()",
            bytes(""),
            abi.encode(
                [address(graph), address(router), address(graph), address(graph)],
                [
                    address(graph).codehash,
                    address(router).codehash,
                    address(graph).codehash,
                    address(graph).codehash
                ]
            )
        );
        r.source.renderer = IStreamStaticMetadataRouter.Selection(
            address(graph),
            address(graph).codehash,
            r.input.rendererVersionKey,
            address(graph),
            address(graph).codehash,
            Output.ID,
            Output.VERSION,
            V.CONTEXT,
            Output.schemaHash(),
            version.readSetHash,
            version.registrationHash
        );
    }

    function _version() private view returns (Registry.Version memory) {
        return Registry.Version(
            true,
            false,
            address(graph),
            address(graph).codehash,
            keccak256("registration"),
            keccak256("reads"),
            keccak256("analysis"),
            keccak256("golden"),
            keccak256("action")
        );
    }

    function _definition(bytes32 id, Schema.DocumentKind kind, bytes memory body) private {
        _answer(
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
                    keccak256("registered declaration")
                )
            )
        );
        _answer("documentBytes(bytes32)", abi.encode(id), abi.encode(body));
    }

    function _roster(Reader.Dependencies memory d) private {
        _selected(keccak256("ARTIST_REGISTRY"), address(graph));
        _selected(keccak256("ARTWORK_FINALITY_REGISTRY"), address(graph));
        _selected(keccak256("METADATA_ROUTER"), address(router));
        _selected(keccak256("COLLECTION_METADATA"), address(graph));
        _selected(keccak256("MODULE_REGISTRY"), address(graph));
        _answer("finalityRegistry()", bytes(""), abi.encode(address(graph)));
        _answer("finalityRegistryCodeHash()", bytes(""), abi.encode(address(graph).codehash));
        _answer(
            "gasParameter(bytes32)",
            abi.encode(keccak256("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS")),
            abi.encode(uint256(500000))
        );
        string[7] memory getters = [
            "coreReads()",
            "sanctionReads()",
            "scopeEvidenceProvider()",
            "metadataReads()",
            "metadataHost()",
            "governanceAuthority()",
            "core()"
        ];
        for (uint256 i; i < getters.length; ++i) {
            _answer(getters[i], bytes(""), abi.encode(address(graph)));
        }
        _answer("scopeEvidenceProviderCodeHash()", bytes(""), abi.encode(address(graph).codehash));
        _answer("viewSourceBinding()", bytes(""), abi.encode(d.binding));
        _answer(
            "supportsInterface(bytes4)",
            abi.encode(type(IStreamViewSourceBinding).interfaceId),
            abi.encode(true)
        );
        _answer(
            "supportsInterface(bytes4)",
            abi.encode(type(IStreamViewRendererV1).interfaceId),
            abi.encode(true)
        );
        _answer("schemaRegistry()", bytes(""), abi.encode(address(graph)));
        _answer("chunkStore()", bytes(""), abi.encode(address(store)));
        _answer("collectionExists(uint256)", abi.encode(uint256(1)), abi.encode(true));
        _answer(
            "isModuleEligible(address,bytes32,bytes4)",
            abi.encode(
                address(graph),
                keccak256("COLLECTION_METADATA"),
                type(IStreamCollectionMetadataV1).interfaceId
            ),
            abi.encode(true)
        );
        _answer(
            "isModuleEligible(address,bytes32,bytes4)",
            abi.encode(address(graph), keccak256("COLLECTION_VIEWS"), type(Views).interfaceId),
            abi.encode(true)
        );
        _answer(
            "isModuleEligible(address,bytes32,bytes4)",
            abi.encode(address(graph), keccak256("RENDERER_REGISTRY"), type(Registry).interfaceId),
            abi.encode(true)
        );
    }

    function _selected(bytes32 role, address target) private {
        _answer(
            "getSatellitePointer(bytes32)",
            abi.encode(role),
            abi.encode(
                target,
                target.codehash,
                false,
                role,
                bytes4(0),
                address(graph),
                uint8(1),
                bytes32(uint256(1)),
                bytes32(uint256(2)),
                uint64(1)
            )
        );
    }

    function _answer(string memory signature, bytes memory args, bytes memory out) private {
        graph.answer(bytes.concat(bytes4(keccak256(bytes(signature))), args), out);
    }

    function _route(Reader.Dependencies memory d) private view returns (V.Route memory r) {
        r.core = address(graph);
        r.coreCodeHash = address(graph).codehash;
        r.router = address(router);
        r.routerCodeHash = address(router).codehash;
        r.artist = address(graph);
        r.artistCodeHash = address(graph).codehash;
        r.finality = address(graph);
        r.finalityCodeHash = address(graph).codehash;
        r.provider = address(graph);
        r.providerCodeHash = address(graph).codehash;
        r.metadata = address(graph);
        r.metadataCodeHash = address(graph).codehash;
        r.schemas = address(graph);
        r.schemasCodeHash = address(graph).codehash;
        r.store = address(store);
        r.storeCodeHash = address(store).codehash;
        r.binding = d.binding;
    }

    function _subject(StreamFinalityScope memory s) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_SCOPE_V1"),
                block.chainid,
                address(graph),
                s.collectionId,
                uint8(4),
                s.scopeId
            )
        );
    }

    function _sourceHash(V.Record memory r) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_ADOPTION_SOURCE_V1"),
                block.chainid,
                address(router),
                r.input.scope,
                r.input.viewId,
                r.input.viewRecordHash,
                r.source
            )
        );
    }
}
