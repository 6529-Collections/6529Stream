// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamReferenceSourceExport.t.sol";
import {
    StreamRenderCriticalTokenReads as TokenSources
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalTokenReads.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as PreservationInventory
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamReferenceRenderSourceReads as ReferenceSources
} from "../../../smart-contracts/domains/preservation/StreamReferenceRenderSourceReads.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamExternalArtifactCurrentPair
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    StreamReferenceRenderTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceRenderDefinitions
} from "../../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamReferenceRendererCatalog
} from "../../../smart-contracts/domains/records/StreamReferenceRendererCatalog.sol";
import {
    StreamSnapshotSourceReads
} from "../../../smart-contracts/domains/records/StreamSnapshotSourceReads.sol";

/// @dev Attributed external-object coverage is the boundary for source-reader tests.
/// No browser execution, external file retrieval, or publication is asserted here.
contract SparseSourceArchiveBoundary {
    address public immutable core;
    address public immutable archiveCoverage;
    mapping(bytes32 => E.Coverage) private _coverages;
    mapping(bytes32 => E.ObjectIdentity) private _objects;

    constructor(address value) {
        core = value;
        archiveCoverage = address(this);
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamExternalArtifactCurrentPair).interfaceId;
    }

    function configure(bytes32 key, bool runtime) external returns (E.Coverage memory e) {
        E.ObjectIdentity memory o;
        o.artistId = keccak256("artist");
        o.schemaId = runtime
            ? StreamReferenceRenderDefinitions.ZIP_SCHEMA_ID
            : StreamReferenceRenderDefinitions.PNG_SCHEMA_ID;
        o.canonicalizationId = keccak256("RAW_BYTES");
        o.contentHash = keccak256(abi.encode(key, "content"));
        o.sha256Digest = sha256(abi.encode(key, "external object"));
        o.arweaveDataRoot = keccak256(abi.encode(key, "root"));
        o.byteSize = 100;
        o.formatId = runtime ? keccak256("IANA:application/zip") : keccak256("IANA:image/png");
        o.formatCatalogId = StreamReferenceRenderDefinitions.FORMAT_CATALOG_ID;
        o.formatCatalogHash = StreamReferenceRenderDefinitions.FORMAT_CATALOG_HASH;
        e.coverageHash = keccak256(abi.encode(key, "coverage"));
        e.objectHash = keccak256(abi.encode(o));
        e.artistId = o.artistId;
        e.contentHash = o.contentHash;
        e.sha256Digest = o.sha256Digest;
        e.arweaveDataRoot = o.arweaveDataRoot;
        e.byteSize = o.byteSize;
        _coverages[e.coverageHash] = e;
        _objects[e.objectHash] = o;
    }

    function requireCoverage(bytes32 hash, bytes32 artist, bytes32 object)
        external
        view
        returns (E.Coverage memory e)
    {
        e = _coverages[hash];
        require(e.coverageHash == hash && e.artistId == artist && e.objectHash == object);
    }

    function objectIdentity(bytes32 hash) external view returns (E.ObjectIdentity memory) {
        return _objects[hash];
    }
}

/// @notice Real PreservationInventory/Router/checkpoint/leaf manifest/Snapshot with retained IDs/serials 2,5.
/// @dev The Core boundary has two completed mints and allocation frontier 5. The gaps model
/// incident-aborted identities; the Core incident itself is covered by Core/PreservationInventory tests.
contract StreamSparsePreservationSourceReadsTest is ReferenceSourceExportFixture {
    S.Dependencies private nativeDependencies;
    S.Context private nativeContext;
    StreamReferenceRenderTypes.Dependencies private referenceDependencies;
    ReferenceSources.SourceInput private referenceInput;

    function _sourceTokenIds() internal pure override returns (uint256[2] memory) {
        return [uint256(2), uint256(5)];
    }

    function setUp() public override {
        super.setUp();
        (bytes32 snapshotHash,) = _publish(address(this));
        StreamSnapshotTypes.NativeFacts memory n =
            StreamSnapshotSourceReads.requireCurrent(_dependencies(), 1);
        SparseSourceArchiveBoundary objects = new SparseSourceArchiveBoundary(address(core));
        _nativeContext(n, address(objects));
        _referenceContext(n, objects, snapshotHash);
    }

    function tokenRead(uint64 index, IStreamOnchainContentCheckpoint.TokenPayload memory payload)
        external
        view
        returns (PreservationInventory.Item[] memory)
    {
        return TokenSources.tokenItems(nativeDependencies, nativeContext, index, payload);
    }

    function referenceRead(ReferenceSources.SourceInput memory input)
        external
        view
        returns (StreamReferenceRenderTypes.SourceFacts memory)
    {
        return ReferenceSources.requireSourceInputs(referenceDependencies, input, false);
    }

    function testTokenRowsResolveActualSerialTwoAtOrdinalZeroAndInteriorGaps() public {
        require(inventory.collectionTokenAt(1, 0) == 2 && inventory.collectionTokenAt(1, 1) == 5);
        require(inventory.collectionTokenBySerial(1, 1) == 0);
        require(inventory.collectionTokenBySerial(1, 3) == 0);
        require(core.collectionMintedEver(1) == 2 && core.lastAllocatedTokenId() == 5);
        PreservationInventory.Item[] memory firstRows = this.tokenRead(0, _payload(2));
        PreservationInventory.Item[] memory lastRows = this.tokenRead(1, _payload(5));
        require(firstRows.length == 4 && lastRows.length == 4, "both actual completed members");
        require(firstRows[0].sourceIndex == 2 && lastRows[0].sourceIndex == 5);
        core.setToken(5, address(0), 3);
        require(
            keccak256(abi.encode(this.tokenRead(1, _payload(5))))
                == keccak256(abi.encode(lastRows)),
            "burn retains source bytes at dense endpoint ordinal"
        );
    }

    function testSparseTokenRowsKeepIdentityOrdinalAndLeafByteChecks() public {
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.tokenRead, (0, _payload(5))));
        require(!ok, "last retained token cannot replace first ordinal");
        IStreamOnchainContentCheckpoint.TokenPayload memory payload = _payload(2);
        payload.animation[0] ^= bytes1(uint8(1));
        (ok,) = address(this).staticcall(abi.encodeCall(this.tokenRead, (0, payload)));
        require(!ok, "sparse membership does not weaken original leaf hash");
        cheat.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (uint256(2))),
            abi.encode(true, uint256(1), uint256(3), false)
        );
        (ok,) = address(this).staticcall(abi.encodeCall(this.tokenRead, (0, _payload(2))));
        require(!ok, "actual serial must still join the indexed identity");
    }

    function testReferenceEndpointsCarryActualSerialsAcrossLeadingAndInteriorGaps() public {
        StreamReferenceRenderTypes.SourceFacts memory facts = this.referenceRead(referenceInput);
        require(facts.mintedEver == 2 && facts.samples.length == 2);
        require(facts.samples[0].tokenId == 2 && facts.samples[0].collectionSerial == 2);
        require(facts.samples[1].tokenId == 5 && facts.samples[1].collectionSerial == 5);
        core.setToken(5, address(0), 3);
        require(
            keccak256(abi.encode(this.referenceRead(referenceInput)))
                == keccak256(abi.encode(facts)),
            "burned last endpoint preserves exact original source facts"
        );
    }

    function testReferenceSparseEndpointsRejectDenseSerialClaimsAndChangedSources() public {
        ReferenceSources.SourceInput memory input = referenceInput;
        input.captures[0].collectionSerial = 1;
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.referenceRead, (input)));
        require(!ok, "ordinal plus one is not the first actual serial");
        input = referenceInput;
        input.captures[1].collectionSerial = 2;
        (ok,) = address(this).staticcall(abi.encodeCall(this.referenceRead, (input)));
        require(!ok, "completed count is not the last actual serial");
        input = referenceInput;
        input.captures[0].tokenId = 1;
        (ok,) = address(this).staticcall(abi.encodeCall(this.referenceRead, (input)));
        require(!ok, "aborted identity cannot replace a checkpoint endpoint");
        input = referenceInput;
        input.captures[1].animationHTML[0] ^= bytes1(uint8(1));
        (ok,) = address(this).staticcall(abi.encodeCall(this.referenceRead, (input)));
        require(!ok, "exact source bytes remain committed");
        core.setMinted(3);
        (ok,) = address(this).staticcall(abi.encodeCall(this.referenceRead, (referenceInput)));
        require(!ok, "minted-ever completeness remains required");
    }

    function _nativeContext(StreamSnapshotTypes.NativeFacts memory n, address other) private {
        nativeDependencies.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(router),
            address(snapshots),
            other,
            other,
            other,
            other,
            address(archive),
            other
        ];
        for (uint256 i; i < 12; ++i) {
            nativeDependencies.codeHashes[i] = nativeDependencies.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            nativeDependencies.artistTargets[i] = other;
            nativeDependencies.artistCodeHashes[i] = other.codehash;
        }
        nativeDependencies.artistContentOwner = other;
        nativeDependencies.artistContentOwnerCodeHash = other.codehash;
        nativeDependencies.chainId = block.chainid;
        nativeDependencies.readGas = 500000;
        nativeDependencies.sourceGas = 4000000;
        nativeDependencies.selectionGas = 4000000;
        nativeDependencies.snapshotGas = 6000000;
        nativeDependencies.referenceGas = 8000000;
        nativeContext.collectionId = 1;
        nativeContext.subject = n.subject;
        nativeContext.artistId = n.artist.artistId;
        nativeContext.snapshot = snapshots.currentSnapshot(1);
        nativeContext.nativeHash = keccak256(abi.encode(n));
        nativeContext.rootRecordHash = n.contentRootRecordHash;
        nativeContext.checkpointHash = n.leafManifest.checkpointHash;
        nativeContext.tokenInventoryHash = n.checkpoint.inventoryHash;
        nativeContext.tokenCount = n.checkpoint.tokenCount;
    }

    function _referenceContext(
        StreamSnapshotTypes.NativeFacts memory n,
        SparseSourceArchiveBoundary objects,
        bytes32 snapshotHash
    ) private {
        _snapshotDocument(
            "STREAM_RENDERER_CLASS_DECLARATION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_RENDERER_CLASS_DECLARATION_V1.json"))
        );
        _snapshotDocument(
            "STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(
                vm.readFile(
                    "schemas/records/STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1.json"
                )
            )
        );
        bytes memory catalog = StreamReferenceRendererCatalog.declarationJSON(
            StreamReferenceRenderTypes.RendererDeclaration(
                n.serving.renderer,
                n.serving.rendererCodeHash,
                n.routerVersion,
                n.routerManifestHash,
                n.presentationProfile,
                n.rendererContext,
                n.dependencyProfile,
                keccak256("STATIC")
            )
        );
        _snapshotDocument(
            "STREAM_SPARSE_SOURCE_RENDERER_FIXTURE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            catalog
        );
        referenceDependencies.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(router),
            address(snapshots),
            address(objects)
        ];
        for (uint256 i; i < 7; ++i) {
            referenceDependencies.codeHashes[i] = referenceDependencies.targets[i].codehash;
        }
        referenceDependencies.chainId = block.chainid;
        referenceDependencies.rendererCatalogId =
            keccak256("STREAM_SPARSE_SOURCE_RENDERER_FIXTURE_V1");
        referenceDependencies.rendererCatalogHash = keccak256(catalog);
        referenceDependencies.rendererCatalogBytes = uint32(catalog.length);
        referenceDependencies.readGas = 500000;
        referenceDependencies.sourceGas = 4000000;
        referenceDependencies.snapshotGas = 6000000;
        referenceDependencies.archiveGas = 2000000;
        referenceInput.collectionId = 1;
        referenceInput.snapshotRecordHash = snapshotHash;
        referenceInput.snapshotRevision = 1;
        E.Coverage memory e = objects.configure(keccak256("runtime"), true);
        referenceInput.environmentCoverageHash = e.coverageHash;
        referenceInput.environmentObjectHash = e.objectHash;
        for (uint256 i; i < 2; ++i) {
            uint256 id = _sourceTokenIds()[i];
            StreamReferenceRenderTypes.Capture memory c;
            c.tokenId = id;
            c.collectionSerial = id;
            c.animationHTML = _payload(id).animation;
            c.htmlHash = keccak256(c.animationHTML);
            c.htmlBytes = uint32(c.animationHTML.length);
            c.sourceSha256 = sha256(c.animationHTML);
            c.metadataJSONHash =
                keccak256(bytes(router.historicalTokenMetadataJSON(address(core), id)));
            e = objects.configure(bytes32(id), false);
            c.coverageHash = e.coverageHash;
            c.objectHash = e.objectHash;
            c.repeatCaptureSha256 = [e.sha256Digest, e.sha256Digest];
            c.capturedAt = uint64(block.timestamp);
            referenceInput.captures.push(c);
        }
    }

    function _payload(uint256 id)
        private
        view
        returns (IStreamOnchainContentCheckpoint.TokenPayload memory p)
    {
        p.tokenId = id;
        p.image = imageBytes;
        p.animation = abi.encodePacked(
            "<html><head></head><body><script>const tokenId=",
            Strings.toString(id),
            ";const tokenHash='",
            Strings.toHexString(uint256(77), 32),
            "';const tokenDataBase64='AP8=';",
            router.collectionServingSource(1).script,
            "</script></body></html>"
        );
    }
}
