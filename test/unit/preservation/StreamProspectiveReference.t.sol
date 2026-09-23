// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamProspectiveReferencePublication as Host
} from "../../../smart-contracts/domains/preservation/StreamProspectiveReferencePublication.sol";
import {
    StreamProspectiveReferenceTypes as P
} from "../../../smart-contracts/interfaces/stream/preservation/StreamProspectiveReferenceTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamConservationFloorTypes as F
} from "../../../smart-contracts/interfaces/stream/metadata/StreamConservationFloorTypes.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamMetadataServingFacts as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamReferenceRendererCatalog as Catalog
} from "../../../smart-contracts/domains/records/StreamReferenceRendererCatalog.sol";
import {
    StreamProspectiveReferenceEncoding as Encoding
} from "../../../smart-contracts/domains/preservation/StreamProspectiveReferenceEncoding.sol";
import {
    StreamProspectiveReferenceRecords as Records
} from "../../../smart-contracts/domains/preservation/StreamProspectiveReferenceRecords.sol";
import {
    StreamProspectiveReferenceDefinitions as D
} from "../../../smart-contracts/domains/records/StreamProspectiveReferenceDefinitions.sol";
import {
    StreamReferenceRenderDefinitions as RD
} from "../../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamReferenceEnvironmentJson as Environment
} from "../../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamMetadataTokenRenderer
} from "../../../smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts as Facts
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { EntropyTimeAuthorityFixture } from "../../helpers/EntropyTimeTestMocks.sol";
import {
    IStreamGasParameterHost
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamSnapshotManifestBytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";

interface ProspectiveVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function warp(uint256) external;
    function expectRevert(bytes calldata) external;
    function expectRevert() external;
    function prank(address) external;
}

/// @dev Typed Core/Floor/provider/Metadata/Router/Schema/Archive boundary, actual Store and publisher.
/// This fixture does not assert current Core governance or actual ZIP/browser/native receipt execution.
contract ProspectiveGraph {
    Store public immutable store;
    address public immutable authority;
    address public immutable renderer;
    string private _script = "document.body.dataset.vector=STREAM_PROSPECTIVE.name;";
    mapping(bytes32 => Facts.DocumentFacts) private _docs;
    mapping(bytes32 => bytes32[]) private _chunks;
    mapping(bytes32 => E.ObjectIdentity) private _objects;
    mapping(bytes32 => E.Coverage) private _coverage;
    mapping(bytes32 => bytes32) private _receiptCoverage;
    bool public collectionGrant = true;
    bool public globalGrant;
    bool public liveArchive = true;
    bool public selected = true;
    bool public wrongMembership;
    bool public wrongScript;
    uint64 public generation = 1;

    constructor(Store s, address a, address r) {
        store = s;
        authority = a;
        renderer = r;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }

    function core() external view returns (address) {
        return address(this);
    }

    function coreCodeHash() external view returns (bytes32) {
        return address(this).codehash;
    }

    function metadata() external view returns (address) {
        return address(this);
    }

    function metadataCodeHash() external view returns (bytes32) {
        return address(this).codehash;
    }

    function schemaRegistry() external view returns (address) {
        return address(this);
    }

    function chunkStore() external view returns (address) {
        return address(store);
    }

    function governanceAuthority() external view returns (address) {
        return authority;
    }

    function executorCodeHash() external view returns (bytes32) {
        return authority.codehash;
    }

    function deploymentChainId() external view returns (uint256) {
        return block.chainid;
    }

    function configurationHash() public pure returns (bytes32) {
        return keccak256("typed-config");
    }

    function conservationFloor() external view returns (address, bytes32) {
        return (address(this), address(this).codehash);
    }

    function collectionExists(uint256 cid) external pure returns (bool) {
        return cid == 1;
    }

    // Deliberately zero: no producer path may synthesize a minted endpoint from this fixture.
    function collectionMintedEver(uint256) external pure returns (uint256) {
        return 0;
    }

    function sourceSetHead() external view returns (uint64, bytes32) {
        return (1, keccak256(abi.encode(generation)));
    }

    function sourceSetHashAt(uint64) external view returns (bytes32) {
        return keccak256(abi.encode(generation));
    }

    function sourceCount() external pure returns (uint64) {
        return 1;
    }

    function sourceAt(uint64) external view returns (F.Source memory) {
        return F.Source(
            address(this),
            address(this).codehash,
            address(this),
            address(this).codehash,
            configurationHash(),
            0,
            1,
            bytes32(uint256(1))
        );
    }

    function getSatellitePointer(bytes32 role)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        return (
            address(this),
            address(this).codehash,
            false,
            role,
            bytes4(0),
            address(0),
            selected ? 1 : 2,
            bytes32(uint256(1)),
            bytes32(uint256(1)),
            1
        );
    }

    function streamModuleVersion() external pure returns (bytes32) {
        return keccak256("typed-version");
    }

    function streamModuleManifest() external pure returns (string memory, bytes32) {
        return ("", keccak256("typed-manifest"));
    }

    function renderingProfile() external pure returns (bytes32, bytes32, bytes32) {
        return (
            keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1"),
            keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1"),
            keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")
        );
    }

    function collectionServingFacts(uint256) public view returns (V.ServingFacts memory f) {
        f.presentationProfile = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        f.configured = true;
        f.mode = keccak256("ONCHAIN");
        f.renderer = renderer;
        f.rendererCodeHash = renderer.codehash;
        f.scriptHash = keccak256(bytes(_script));
        f.scriptBytes = uint32(bytes(_script).length);
        f.imageURIHash = keccak256("");
        f.animationBaseURIHash = keccak256("");
    }

    function collectionServingSource(uint256) external view returns (V.ServingSource memory) {
        return V.ServingSource("Prospective", "Named simulation", "", "", _script);
    }

    function collectionLiveArtistStatus(uint256) external view returns (V.LiveArtistStatus memory) {
        return V.LiveArtistStatus(
            address(this), bytes32(uint256(7)), 1, bytes32(uint256(8)), 1, 1, authority
        );
    }

    function scriptManifestHash(uint256) public pure returns (bytes32) {
        return keccak256("script-original-receipt");
    }

    function mediaManifestHash(uint256) public pure returns (bytes32) {
        return keccak256("media-original-receipt");
    }

    function scriptManifest(uint256) public view returns (M.ScriptManifest memory) {
        return M.ScriptManifest(
            wrongScript ? bytes32(uint256(1)) : keccak256(bytes(_script)),
            keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1"),
            M.PayloadSourceType.INLINE_CHUNKS,
            "",
            "",
            "",
            "application/javascript",
            1,
            true
        );
    }

    function mediaManifest(uint256) public pure returns (M.MediaManifest memory m) {
        return m;
    }

    function scriptChunk(uint256, uint256) external view returns (bytes memory) {
        return bytes(_script);
    }

    function currentReleaseContext(uint256 cid) external view returns (F.ReleaseContext memory r) {
        r.scopeSubject = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(this),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0)
        );
        r.mediaInventoryHash = keccak256(
            abi.encode(keccak256("6529STREAM_MEDIA_MASTER_INVENTORY_V1"), mediaManifest(cid))
        );
        V.ServingFacts memory f = collectionServingFacts(cid);
        r.scriptSourceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_NATIVE_SCRIPT_V1"),
                scriptManifest(cid),
                f.scriptBytes,
                renderer,
                renderer.codehash
            )
        );
        r.membershipHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_COLLECTION_RELEASE_V1"),
                block.chainid,
                address(this),
                cid,
                r.scopeSubject,
                r.mediaInventoryHash,
                r.scriptSourceHash
            )
        );
        if (wrongMembership) r.membershipHash = bytes32(uint256(99));
        r.sourceContextHash = keccak256(
            abi.encode(
                configurationHash(),
                mediaManifestHash(cid),
                scriptManifestHash(cid),
                uint8(0),
                f,
                r.membershipHash
            )
        );
        r.scriptWork = true;
    }

    function familyWriter(uint256 cid, bytes32, uint8 cls, address actor)
        external
        view
        returns (bool, uint64)
    {
        return (
            actor == authority
                && (cls == 3 && cid == 1 ? collectionGrant : cls == 8 && cid == 0 && globalGrant),
            1
        );
    }

    function controls(uint8 field, bool value) external {
        if (field == 0) collectionGrant = value;
        else if (field == 1) globalGrant = value;
        else if (field == 2) liveArchive = value;
        else if (field == 3) selected = value;
        else if (field == 4) wrongMembership = value;
        else wrongScript = value;
    }

    function advanceSource() external {
        generation++;
    }

    function addDocument(bytes32 id, Schema.DocumentKind kind, bytes memory raw) external {
        _docs[id] = Facts.DocumentFacts(
            true,
            kind,
            Schema.DocumentStatus.ACTIVE,
            keccak256(raw),
            keccak256("RAW_BYTES"),
            0,
            uint32(raw.length),
            (raw.length + 8191) / 8192,
            keccak256(abi.encode(id))
        );
        for (uint256 start; start < raw.length; start += 8192) {
            uint256 count = raw.length - start;
            if (count > 8192) count = 8192;
            bytes memory part = new bytes(count);
            for (uint256 j; j < count; ++j) {
                part[j] = raw[start + j];
            }
            (bytes32 h,) = store.publishChunk(part);
            _chunks[id].push(h);
        }
    }

    function documentFacts(bytes32 id) external view returns (Facts.DocumentFacts memory) {
        return _docs[id];
    }

    function documentChunkHashAt(bytes32 id, uint256 i) external view returns (bytes32) {
        return _chunks[id][i];
    }

    function setCoverage(
        bytes32 id,
        bytes32 object,
        bool runtime,
        bytes32 content,
        bytes32 sha,
        uint64 size
    ) external {
        _objects[object] = E.ObjectIdentity(
            bytes32(uint256(7)),
            runtime ? RD.ZIP_SCHEMA_ID : RD.PNG_SCHEMA_ID,
            keccak256("RAW_BYTES"),
            content,
            sha,
            keccak256(abi.encode("root", object)),
            size,
            runtime ? keccak256("IANA:application/zip") : keccak256("IANA:image/png"),
            RD.FORMAT_CATALOG_ID,
            RD.FORMAT_CATALOG_HASH
        );
        E.Coverage memory e = E.Coverage(
            id,
            object,
            bytes32(uint256(7)),
            content,
            sha,
            _objects[object].arweaveDataRoot,
            size,
            keccak256(abi.encode(id, 1)),
            keccak256(abi.encode(id, 2)),
            keccak256(abi.encode(id, 3)),
            keccak256(abi.encode(id, 4)),
            keccak256(abi.encode(id, 5)),
            keccak256(abi.encode(id, 6)),
            keccak256(abi.encode(id, 7)),
            keccak256("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1")
        );
        _coverage[id] = e;
        _receiptCoverage[e.firstReceiptHash] = id;
    }

    function coverage(bytes32 id) external view returns (E.Coverage memory) {
        return _coverage[id];
    }

    function objectIdentity(bytes32 id) external view returns (E.ObjectIdentity memory) {
        return _objects[id];
    }

    function currentReceiptPair(bytes32 first, bytes32 second, bytes32 artist, bytes32 object)
        external
        view
        returns (E.CurrentPair memory)
    {
        E.Coverage memory e = _coverage[_receiptCoverage[first]];
        require(
            liveArchive && second == e.secondReceiptHash && artist == e.artistId
                && object == e.objectHash,
            "typed current pair"
        );
        return E.CurrentPair(
            e.objectHash,
            e.artistId,
            e.contentHash,
            e.sha256Digest,
            e.arweaveDataRoot,
            e.byteSize,
            e.firstFamilyRecordHash,
            e.secondFamilyRecordHash,
            e.firstReceiptHash,
            e.secondReceiptHash,
            e.firstFixityHash,
            e.secondFixityHash,
            e.checkpointHash,
            e.profileHash
        );
    }
}

contract StreamProspectiveReferenceTest is EntropyTimeAuthorityFixture {
    ProspectiveVm private constant vm =
        ProspectiveVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Host private host;
    Store private store;
    ProspectiveGraph private graph;

    function setUp() public {
        vm.warp(200);
        store = new Store();
        graph = new ProspectiveGraph(store, address(this), address(StreamMetadataTokenRenderer));
        P.Dependencies memory d;
        d.targets = [
            address(graph),
            address(graph),
            address(graph),
            address(store),
            address(graph),
            address(Encoding)
        ];
        for (uint256 i; i < 6; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 2000000;
        d.sourceGas = 4000000;
        d.archiveGas = 2000000;
        R.RendererDeclaration memory declaration = R.RendererDeclaration(
            address(StreamMetadataTokenRenderer),
            address(StreamMetadataTokenRenderer).codehash,
            keccak256("typed-version"),
            keccak256("typed-manifest"),
            keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1"),
            keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1"),
            keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1"),
            keccak256("STATIC")
        );
        bytes memory catalog = Catalog.declarationJSON(declaration);
        d.rendererCatalogId = keccak256("prospective-test-renderer");
        d.rendererCatalogHash = keccak256(catalog);
        d.rendererCatalogBytes = uint32(catalog.length);
        graph.addDocument(d.rendererCatalogId, Schema.DocumentKind.CATALOG, catalog);
        _doc(
            RD.RENDERER_SCHEMA_ID,
            Schema.DocumentKind.SCHEMA,
            "schemas/records/STREAM_RENDERER_CLASS_DECLARATION_V1.json"
        );
        _doc(
            RD.RENDERER_PROFILE_ID,
            Schema.DocumentKind.CATALOG,
            "schemas/records/STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1.json"
        );
        _doc(
            D.SCHEMA_ID,
            Schema.DocumentKind.SCHEMA,
            "schemas/preservation/prospective/STREAM_PROSPECTIVE_REFERENCE_ABI_V1.json"
        );
        _doc(
            D.PROFILE_ID,
            Schema.DocumentKind.CATALOG,
            "schemas/preservation/prospective/STREAM_PROSPECTIVE_NAMED_SIMULATION_PROFILE_V1.json"
        );
        _doc(
            D.CANON_ID,
            Schema.DocumentKind.CANONICALIZATION,
            "schemas/preservation/prospective/STREAM_ABI_PROSPECTIVE_REFERENCE_V1.json"
        );
        _doc(
            RD.ENVIRONMENT_SCHEMA_ID,
            Schema.DocumentKind.SCHEMA,
            "schemas/records/STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1.json"
        );
        _doc(
            RD.PNG_SCHEMA_ID,
            Schema.DocumentKind.SCHEMA,
            "schemas/records/STREAM_REFERENCE_PNG_OBJECT_V1.json"
        );
        _doc(
            RD.ZIP_SCHEMA_ID,
            Schema.DocumentKind.SCHEMA,
            "schemas/records/STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1.json"
        );
        _doc(
            RD.FORMAT_CATALOG_ID,
            Schema.DocumentKind.CATALOG,
            "schemas/records/STREAM_REFERENCE_NATIVE_FORMATS_V1.json"
        );
        _doc(
            RD.CANON_ID,
            Schema.DocumentKind.CANONICALIZATION,
            "schemas/museum/account-profile/RFC8785_JCS.json"
        );
        IStreamGasParameterHost.GasParameterConfig[3] memory configs;
        configs[0] = IStreamGasParameterHost.GasParameterConfig(
            "PROSPECTIVE_REFERENCE_READ_GAS", 2000000, 2000000, 2
        );
        configs[1] = IStreamGasParameterHost.GasParameterConfig(
            "PROSPECTIVE_REFERENCE_SOURCE_GAS", 4000000, 4000000, 2
        );
        configs[2] = IStreamGasParameterHost.GasParameterConfig(
            "PROSPECTIVE_REFERENCE_ARCHIVE_GAS", 2000000, 2000000, 2
        );
        host = new Host(d, address(this), configs);
    }

    function _doc(bytes32 id, Schema.DocumentKind kind, string memory path) private {
        graph.addDocument(id, kind, vm.readFileBinary(path));
    }

    function _publication() private returns (P.Publication memory p) {
        p.collectionId = 1;
        p.referenceId = keccak256("named-vector-publication");
        p.effectiveAt = 200;
        p.reasonHash = keccak256("curator-observation");
        (P.Source memory s, bytes32 hash) = host.currentSource(1);
        p.expectedSourceHash = hash;
        p.captures = new P.Capture[](1);
        p.captures[0].vector = P.Vector("genesis", bytes32(uint256(123)), hex"010203");
        p.captures[0].animationHTML = host.simulationHTML(1, p.captures[0].vector);
        p.captures[0].capturedAt = 100;
        p.captures[0].objectHash = keccak256("capture-object");
        p.captures[0].coverageHash = keccak256("capture-coverage");
        p.captures[0].repeatCaptureSha256 =
            [keccak256("synthetic-png-sha"), keccak256("synthetic-png-sha")];
        R.Environment memory e;
        e.objectHash = keccak256("environment-object");
        e.coverageHash = keccak256("environment-coverage");
        e.engineName = "typed browser";
        e.engineVersion = "1";
        e.engineExecutablePath = "engine/browser.exe";
        e.engineExecutableSha256 = keccak256("browser");
        e.toolchainName = "typed capture";
        e.toolchainVersion = "1";
        e.toolchainPath = "tools/capture.py";
        e.toolchainSha256 = keccak256("capture");
        e.operatingSystem = "Windows";
        e.operatingSystemVersion = "typed";
        e.architecture = "AMD64";
        e.viewportWidth = 64;
        e.viewportHeight = 64;
        e.devicePixelRatio = 1;
        e.colorSpace = "srgb";
        e.softwareRasterization = true;
        e.captureProfile = keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1");
        e.licenseNote = "Synthetic unit evidence; no actual runtime/ZIP claim.";
        e.packageFiles = new R.PackageFile[](5);
        e.packageFiles[0] = R.PackageFile(e.engineExecutablePath, 1, e.engineExecutableSha256);
        e.packageFiles[1] = R.PackageFile(
            "prospective/genesis.html",
            uint64(p.captures[0].animationHTML.length),
            sha256(p.captures[0].animationHTML)
        );
        bytes memory media = abi.encode(s.mediaManifest);
        e.packageFiles[2] =
            R.PackageFile("prospective/media.abi", uint64(media.length), sha256(media));
        e.packageFiles[3] =
            R.PackageFile("prospective/script.js", uint64(s.script.length), sha256(s.script));
        e.packageFiles[4] = R.PackageFile(e.toolchainPath, 1, e.toolchainSha256);
        e.platformPrerequisites = new R.PackageFile[](1);
        e.platformPrerequisites[0] =
            R.PackageFile("C:/Windows/typed.dll", 1, keccak256("typed-prerequisite"));
        bytes memory environment = Environment.manifest(e);
        e.manifestHash = keccak256(environment);
        e.manifestBytes = uint32(environment.length);
        p.environment = e;
        p.captures[0].execution = abi.encode(
            P.Execution(
                Encoding.PROFILE,
                hash,
                Encoding.vectorHash(p.captures[0].vector),
                e.manifestHash,
                sha256(p.captures[0].animationHTML),
                p.captures[0].repeatCaptureSha256,
                100,
                0
            )
        );
        graph.setCoverage(
            e.coverageHash,
            e.objectHash,
            true,
            keccak256("synthetic-zip"),
            keccak256("synthetic-zip-sha"),
            99
        );
        graph.setCoverage(
            p.captures[0].coverageHash,
            p.captures[0].objectHash,
            false,
            keccak256("synthetic-png"),
            p.captures[0].repeatCaptureSha256[0],
            88
        );
        // Original preparation is mandatory even for this small typed fixture.
        // Uploads alone do not populate the host's authenticated inventory namespace.
        _upload(bytes(Environment.files(e.packageFiles, true)), false);
        host.prepareFileInventory(e.packageFiles, true);
        _upload(bytes(Environment.files(e.platformPrerequisites, false)), false);
        host.prepareFileInventory(e.platformPrerequisites, false);
    }

    function _upload(bytes memory raw, bool omitLast) private returns (bytes32 missing) {
        for (uint256 start; start < raw.length; start += 8192) {
            uint256 count = raw.length - start;
            if (count > 8192) count = 8192;
            bytes memory part = new bytes(count);
            for (uint256 j; j < count; ++j) {
                part[j] = raw[start + j];
            }
            if (omitLast && start + count == raw.length) missing = keccak256(part);
            else store.publishChunk(part);
        }
    }

    function _prepared(P.Publication memory p) private returns (bytes memory payload) {
        (, payload) = host.previewProspectiveReference(p, address(this));
        _upload(payload, false);
        _upload(abi.encode(p), false);
    }

    function testProspectiveZeroMintAndLiteralRecordDomain() public {
        P.Publication memory p = _publication();
        bytes memory payload = _prepared(p);
        bytes32 hash = host.publishProspectiveReference(p);
        (P.Publication memory saved, P.Receipt memory r) = host.prospectiveRecord(hash);
        require(
            graph.collectionMintedEver(1) == 0 && r.revision == 1 && r.authorizationClass == 3,
            "actual prospective boundary"
        );
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(p))
                && keccak256(host.prospectivePayload(hash)) == keccak256(payload),
            "exact retained originals"
        );
        bytes32 chain = r.chainHash;
        r.recordHash = 0;
        r.chainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PROSPECTIVE_REFERENCE_RECORD_V1"),
                        block.chainid,
                        address(host),
                        address(graph),
                        address(graph),
                        p,
                        r
                    )
                ),
            "literal record"
        );
        r.recordHash = hash;
        r.chainHash = chain;
        require(
            host.requireProspectiveCollectionReference(1, r.subject, r.membershipHash)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PROSPECTIVE_COLLECTION_REFERENCE_EVIDENCE_V1"),
                        block.chainid,
                        address(host),
                        address(graph),
                        address(graph),
                        uint256(1),
                        r.subject,
                        r.membershipHash,
                        r
                    )
                ),
            "literal evidence"
        );
    }

    function testSourceDriftRefusesCurrentButRetainsHistory() public {
        P.Publication memory p = _publication();
        bytes memory payload = _prepared(p);
        bytes32 h = host.publishProspectiveReference(p);
        P.Receipt memory r = host.currentProspectiveReference(1);
        graph.advanceSource();
        vm.expectRevert();
        host.requireProspectiveCollectionReference(1, r.subject, r.membershipHash);
        require(keccak256(host.prospectivePayload(h)) == keccak256(payload), "historical bytes");
    }

    function testCompleteSemanticMembershipAndScriptMismatchRefuse() public {
        graph.controls(4, true);
        vm.expectRevert();
        host.currentSource(1);
        graph.controls(4, false);
        graph.controls(5, true);
        vm.expectRevert();
        host.currentSource(1);
        graph.controls(5, false);
        (, bytes32 hash) = host.currentSource(1);
        require(hash != 0, "restore");
    }

    function testNoCurrentPointerFallbackAndNoFinalityCapability() public {
        graph.controls(3, false);
        vm.expectRevert();
        host.currentSource(1);
        graph.controls(3, true);
        (, bytes32 hash) = host.currentSource(1);
        require(
            hash != 0 && !host.supportsInterface(bytes4(keccak256("finalityState(uint256)"))),
            "prospective-only capability"
        );
    }

    function testCollectionGrantPrecedesGlobalAndUnauthorisedCannotPublish() public {
        P.Publication memory p = _publication();
        _prepared(p);
        graph.controls(1, true);
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(P.ProspectiveAuthority.selector, address(0x123)));
        host.publishProspectiveReference(p);
        bytes32 first = host.publishProspectiveReference(p);
        (, P.Receipt memory primary) = host.prospectiveRecord(first);
        require(primary.authorizationClass == 3, "collection precedes simultaneous global grant");
        graph.controls(0, false);
        p.referenceId = keccak256("second-global-reference");
        p.expectedHead = first;
        p.expectedRevision = 1;
        _prepared(p);
        bytes32 h = host.publishProspectiveReference(p);
        (, P.Receipt memory r) = host.prospectiveRecord(h);
        require(r.authorizationClass == 8, "global exact class");
    }

    function testMissingLastOriginalChunkRollsBackAndExactRetry() public {
        P.Publication memory p = _publication();
        (, bytes memory payload) = host.previewProspectiveReference(p, address(this));
        _upload(payload, false);
        bytes32 missing = _upload(abi.encode(p), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSnapshotManifestBytes.SnapshotChunkUnavailable.selector, missing
            )
        );
        host.publishProspectiveReference(p);
        require(
            host.prospectiveCount(1) == 0 && host.currentProspectiveReference(1).recordHash == 0,
            "atomic rollback"
        );
        _upload(abi.encode(p), false);
        host.publishProspectiveReference(p);
        require(host.prospectiveCount(1) == 1, "identical retry");
    }

    function testCaptureInputEnvironmentAndTranscriptSubstitutionRefuse() public {
        P.Publication memory p = _publication();
        p.captures[0].vector.seed = bytes32(uint256(9));
        vm.expectRevert();
        host.previewProspectiveReference(p, address(this));
        p = _publication();
        p.environment.packageFiles[3].sha256Digest = bytes32(uint256(8));
        vm.expectRevert();
        host.previewProspectiveReference(p, address(this));
        p = _publication();
        P.Execution memory x = abi.decode(p.captures[0].execution, (P.Execution));
        x.sourceHash = bytes32(uint256(9));
        p.captures[0].execution = abi.encode(x);
        vm.expectRevert();
        host.previewProspectiveReference(p, address(this));
    }

    function testArchiveCurrentnessAndWrongSubjectRefuseThenRestore() public {
        P.Publication memory p = _publication();
        _prepared(p);
        host.publishProspectiveReference(p);
        P.Receipt memory r = host.currentProspectiveReference(1);
        vm.expectRevert();
        host.requireProspectiveCollectionReference(1, bytes32(uint256(999)), r.membershipHash);
        graph.controls(2, false);
        vm.expectRevert();
        host.requireProspectiveCollectionReference(1, r.subject, r.membershipHash);
        graph.controls(2, true);
        require(
            host.requireProspectiveCollectionReference(1, r.subject, r.membershipHash) != 0,
            "same originals restore"
        );
    }

    function testDuplicateIdAndStaleHeadRefuse() public {
        P.Publication memory p = _publication();
        _prepared(p);
        host.publishProspectiveReference(p);
        vm.expectRevert();
        host.publishProspectiveReference(p);
        p.referenceId = keccak256("new-id");
        vm.expectRevert();
        host.publishProspectiveReference(p);
        require(host.prospectiveCount(1) == 1, "no replay");
    }

    function testSimulationEscapesEndTagAndHasNoTokenIdentityClaim() public pure {
        bytes memory html = Encoding.html(
            1,
            address(2),
            3,
            bytes32(uint256(4)),
            P.Vector("named", bytes32(0), hex"0001"),
            bytes("/* </ScRiPtX */")
        );
        require(
            _has(html, bytes("<\\/ScRiPtX"))
                && _has(html, bytes('data-stream-render-state="prospective"')),
            "exact script escaping"
        );
        require(
            !_has(html, bytes("tokenId")) && !_has(html, bytes("finalized"))
                && !_has(html, bytes("Coordinator")),
            "no invented token claims"
        );
    }

    function testFuzzVectorHashLiteral(bytes32 seed, bytes memory input) public pure {
        if (input.length > 4096) return;
        P.Vector memory v = P.Vector("named", seed, input);
        require(
            Encoding.vectorHash(v)
                == keccak256(
                    abi.encode(keccak256("6529STREAM_PROSPECTIVE_NAMED_SIMULATION_V1"), v)
                ),
            "literal vector"
        );
    }

    function _has(bytes memory data, bytes memory needle) private pure returns (bool) {
        for (uint256 i; i + needle.length <= data.length; ++i) {
            bool found = true;
            for (uint256 j; j < needle.length; ++j) {
                if (data[i + j] != needle[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
