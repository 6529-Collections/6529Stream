// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    ViewFinalityConfigurationFixture,
    ViewConfigurationBoundary
} from "../unit/finality/StreamFinalityViewPreservationConfigurationV1.t.sol";
import {
    ViewInputManifestGovernanceBoundary
} from "../unit/finality/StreamFinalityViewPreservationInputReadsV1.t.sol";
import { ScopedBundleArchiveFixture } from "./ScopedBundleArchiveFixture.sol";
import {
    StreamSchemaRegistry
} from "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamSchemaDocumentStore
} from "../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamSchemaRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationConfigurationV1 as Configuration
} from "../../smart-contracts/domains/finality/StreamFinalityViewPreservationConfigurationV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Selection
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../../smart-contracts/domains/preservation/StreamPreservationInventoryIO.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityViewPreservationInputTypesV1 as S
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationInputTypesV1.sol";
import {
    StreamFinalityViewMediaReviewV1 as Media
} from "../../smart-contracts/domains/finality/StreamFinalityViewMediaReviewV1.sol";
import {
    StreamFinalityViewPreservationSanctionReviewV1 as Review
} from "../../smart-contracts/domains/finality/StreamFinalityViewPreservationSanctionReviewV1.sol";
import {
    StreamFinalityViewSanctionProfileV1 as Profile
} from "../../smart-contracts/domains/finality/StreamFinalityViewSanctionProfileV1.sol";
import {
    StreamFinalityNativeSanctionProfile as OriginalProfile
} from "../../smart-contracts/domains/finality/StreamFinalityNativeSanctionProfile.sol";
import {
    IStreamFinalitySanctionReview
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as V
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    IStreamViewPreservationRenderCriticalInventoryV1 as Inventory
} from "../../smart-contracts/interfaces/stream/preservation/IStreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    IStreamViewPreservationBundleArchiveCoverageV1 as Coverage
} from "../../smart-contracts/interfaces/stream/preservation/IStreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    StreamViewPreservationBundleArchiveCoverageV1 as Bundle
} from "../../smart-contracts/domains/preservation/StreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    StreamRenderCriticalSourceTypes as I
} from "../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamExternalArtifactCoverage
} from "../../smart-contracts/domains/preservation/StreamExternalArtifactCoverage.sol";
import {
    StreamBundleArchiveReads as Archive
} from "../../smart-contracts/domains/preservation/StreamBundleArchiveReads.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamViewPreservationRenderCriticalArtworkReadsV1 as Artwork
} from "../../smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalArtworkReadsV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as R
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as O
} from "../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    IStreamViewPreservationReferencePublicationV1 as Reference
} from "../../smart-contracts/interfaces/stream/preservation/IStreamViewPreservationReferencePublicationV1.sol";
import {
    StreamViewPreservationReferenceDefinitionsV1 as Definitions
} from "../../smart-contracts/domains/records/StreamViewPreservationReferenceDefinitionsV1.sol";
import {
    StreamReferenceRenderDefinitions as PNG
} from "../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamViewAdoptionTypes as A
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamViewPayloadBytes as PayloadBytes
} from "../../smart-contracts/domains/metadata/StreamViewPayloadBytes.sol";
import {
    StreamViewPayloadV2 as Payload
} from "../../smart-contracts/domains/metadata/StreamViewPayloadV2.sol";
import {
    IStreamCollectionViews as Declaration
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamPreservationRecords as Records
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamMetadataServingFacts
} from "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamMetadataSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";

/// @dev Actual original Archive, verifier, role registry and two real Safe signer sets.
/// The upstream full browser-package fixture supplies native data paths. Network/storage
/// attestations are local fixture statements, not a real upload or an image-decoder proof.
contract ViewReviewArchiveFixture is ScopedBundleArchiveFixture {
    bytes32 public completeCoverage;

    function familyStatus(uint8 status) external {
        _status(firstFamily, status);
    }

    function initialize()
        external
        returns (address, address, E.ObjectIdentity memory, B.Proof memory)
    {
        _setupArchive();
        object.canonicalizationId = keccak256("RAW_BYTES");
        objectHash = host.recordObject(object);
        (,, completeCoverage) = _covered();
        return (address(core), address(host), object, B.Proof(1, completeCoverage, objectHash));
    }
}

contract ViewReviewCompositionHost {
    Native.Config private original;
    Selection.Receipt private saved;
    address private snapshot;
    address private factory;

    function configure(
        Native.Config memory c,
        Selection.Selection memory selection,
        address snap,
        address entropy
    ) external {
        original = c;
        snapshot = snap;
        factory = entropy;
        saved.selection = selection;
        saved.referenceDependenciesHash = keccak256("initial reference dependencies");
        saved.inventoryDependenciesHash = keccak256("initial inventory dependencies");
        saved.bundleDependenciesHash = keccak256("initial bundle dependencies");
        saved.basicBindingRecordHash = keccak256("actual basic record fixture");
        saved.actionId = keccak256("class2 action fixture");
        saved.boundAt = uint64(block.timestamp);
        saved.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"),
                c.chainId,
                address(this),
                selection,
                saved.referenceDependenciesHash,
                saved.inventoryDependenciesHash,
                saved.bundleDependenciesHash,
                saved.basicBindingRecordHash,
                saved.actionId,
                saved.boundAt
            )
        );
    }

    function viewFinalitySources() external view returns (Selection.Selection memory) {
        return saved.selection;
    }

    function viewFinalitySourcesReceipt() external view returns (Selection.Receipt memory) {
        return saved;
    }

    function viewPreservationSnapshotHost() external view returns (address) {
        return snapshot;
    }

    function viewPreservationSnapshotCodeHash() external view returns (bytes32) {
        return snapshot.codehash;
    }

    function viewPreservationSnapshotValidationGas() external view returns (uint256) {
        return 16000000;
    }

    function viewPolicySourceFactoryV2() external view returns (address) {
        return factory;
    }

    function viewPolicySourceFactoryV2CodeHash() external view returns (bytes32) {
        return factory.codehash;
    }

    function media(S.Statement memory s) external view returns (bytes32[] memory) {
        return Media.hashes(original, s);
    }

    function review(S.Statement memory s)
        external
        view
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        return Review.review(original, s);
    }
}

/// @notice Actual three composed workers, Store carriers, SchemaRegistry and external Archive.
/// @dev Selection/governance, sealed inventory/bundle and reference publication are explicit
/// typed boundaries. This does not execute provider authority, current source sealing, a real
/// browser capture, full finality, onchain media, or a transaction-cap acceptance ceremony.
abstract contract ViewReviewCompositionFixture is ViewFinalityConfigurationFixture {
    ViewReviewCompositionHost internal consumer;
    ViewReviewArchiveFixture internal archiveFixture;
    StreamExternalArtifactCoverage internal archive;
    StreamSchemaRegistry internal schemas;
    StreamSchemaDocumentStore internal store;
    ViewInputManifestGovernanceBoundary internal gov;
    Native.Config internal config;
    S.Statement internal statement;
    V.Context internal context;
    V.Evidence internal evidence;
    V.BundleEvidence internal coverage;
    R.SourceFacts internal source;
    R.Publication internal publication;
    R.Receipt internal receipt;
    E.ObjectIdentity internal mediaObject;
    B.Proof internal proof;
    B.Admission internal admitted;
    T.Item[] internal rows;
    T.Segment internal artworkSegment;
    ViewConfigurationBoundary internal declarations;
    uint256 internal observedAt;
    bytes32 internal pngHash;
    bytes32 internal pngDigest;
    bytes32 internal pngObject;
    bool internal skipAdmission;
    string internal constant IMAGE =
        "ipfs://bafkreigs5k6x377o2tzxmmxj5dk2qyox7zo7miownzrm2qzdj3fzuvzec4";
    string internal constant OTHER_IMAGE =
        "ipfs://bafkreifjghpwdjrr5mgxn5pdwr52mivwmzphuoo7oy7qxajv27di3hggj4";
    bytes32 internal constant PROFILE_ID = keccak256("6529STREAM_ARTIST_SANCTION_VIEW_MEDIA_V1");

    function setUp() public virtual override {
        super.setUp();
        archiveFixture = new ViewReviewArchiveFixture();
        address actualCore;
        address actualArchive;
        (actualCore, actualArchive, mediaObject, proof) = archiveFixture.initialize();
        archive = StreamExternalArtifactCoverage(actualArchive);
        observedAt = block.timestamp;
        gov = new ViewInputManifestGovernanceBoundary();
        schemas = new StreamSchemaRegistry(address(gov));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "6529STREAM_ARTIST_SANCTION_VIEW_MEDIA_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            Profile.document()
        );
        _register(
            "6529STREAM_ARTIST_SANCTION_NATIVE_CAPTURES_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            OriginalProfile.document()
        );
        expected.targets[0] = actualCore;
        expected.codeHashes[0] = actualCore.codehash;
        expected.targets[2] = address(schemas);
        expected.codeHashes[2] = address(schemas).codehash;
        expected.targets[3] = address(store);
        expected.codeHashes[3] = address(store).codehash;
        expected.targets[11] = actualArchive;
        expected.codeHashes[11] = actualArchive.codehash;
        uint256[7] memory positions = [uint256(0), 1, 2, 3, 4, 5, 11];
        for (uint256 i; i < 7; ++i) {
            referenceDeps.targets[i] = expected.targets[positions[i]];
            referenceDeps.codeHashes[i] = expected.codeHashes[positions[i]];
        }
        _reference();
        _address(selected.referencePublication, "core()", actualCore);
        _address(selected.referencePublication, "archiveCoverage()", actualArchive);
        inventory.targets = expected.targets;
        inventory.codeHashes = expected.codeHashes;
        _inventory();
        _address(selected.renderCriticalInventory, "core()", actualCore);
        _address(selected.renderCriticalInventory, "externalCoverage()", actualArchive);
        bundle.targets[0] = actualCore;
        bundle.codeHashes[0] = actualCore.codehash;
        bundle.targets[4] = actualArchive;
        bundle.codeHashes[4] = actualArchive.codehash;
        _bundle();
        _address(selected.bundleArchiveCoverage, "core()", actualCore);
        _address(selected.bundleArchiveCoverage, "externalCoverage()", actualArchive);
        _word(selected.bundleArchiveCoverage, "coreCodeHash()", actualCore.codehash);
        consumer = new ViewReviewCompositionHost();
        for (uint256 i; i < 22; ++i) {
            config.targets[i] = address(new ViewConfigurationBoundary());
            config.codeHashes[i] = config.targets[i].codehash;
        }
        uint256[12] memory roles = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            config.targets[roles[i]] = expected.targets[i];
            config.codeHashes[roles[i]] = expected.codeHashes[i];
        }
        config.targets[8] = address(new ViewConfigurationBoundary());
        config.codeHashes[8] = config.targets[8].codehash;
        config.targets[9] = address(new ViewConfigurationBoundary());
        config.codeHashes[9] = config.targets[9].codehash;
        config.targets[11] = expected.artistTargets[0];
        config.codeHashes[11] = expected.artistCodeHashes[0];
        I.Dependencies memory prior = abi.decode(abi.encode(inventory), (I.Dependencies));
        prior.targets[5] = config.targets[8];
        prior.codeHashes[5] = config.codeHashes[8];
        prior.targets[6] = config.targets[9];
        prior.codeHashes[6] = config.codeHashes[9];
        config.chainId = originalChain;
        config.readGas = 2000000;
        config.componentSourceGas = 4000000;
        config.sourceGas = 8000000;
        config.inventoryDependencyHash = keccak256(abi.encode(prior));
        ViewConfigurationBoundary(config.targets[18])
            .set(abi.encodeWithSignature("dependencies()"), abi.encode(prior));
        _address(config.targets[12], "scopeEvidenceProvider()", address(consumer));
        _address(config.targets[13], "scopeEvidenceProvider()", address(consumer));
        _address(config.targets[14], "evidenceProvider()", address(consumer));
        consumer.configure(
            config, selected, expected.targets[5], address(new ViewConfigurationBoundary())
        );
        declarations = new ViewConfigurationBoundary();
        _png();
        _prepare(IMAGE, 2);
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory value
    ) internal {
        (bytes32 hash,) = store.publishChunk(value);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory p = IStreamSchemaRegistry.DocumentSpec(
            name,
            kind,
            hash,
            keccak256("RAW_BYTES"),
            0,
            "ipfs://fixture/definition",
            uint32(value.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(p, chunks);
        gov.run(address(schemas), abi.encodeCall(schemas.registerDocument, (p, chunks)), s, o, n);
    }

    function _png() private {
        // Fixed complete one-pixel PNG bytes; object recording is genuine, capture authority
        // remains the typed reference boundary rather than an invented browser execution.
        bytes memory png =
            hex"89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000b49444154789c6360000200000500017a5eab3f0000000049454e44ae426082";
        pngHash = keccak256(png);
        pngDigest = sha256(png);
        E.ObjectIdentity memory o = E.ObjectIdentity(
            mediaObject.artistId,
            PNG.PNG_SCHEMA_ID,
            keccak256("RAW_BYTES"),
            pngHash,
            pngDigest,
            keccak256("typed capture data root"),
            uint64(png.length),
            keccak256("IANA:image/png"),
            PNG.FORMAT_CATALOG_ID,
            PNG.FORMAT_CATALOG_HASH
        );
        pngObject = archive.recordObject(o);
        IStreamMetadataServingFacts.ArtistPresentation memory p;
        p.artistId = mediaObject.artistId;
        p.registry = config.targets[11];
        p.registryCodeHash = config.codeHashes[11];
        p.bindingGeneration = 1;
        p.bindingHash = keccak256("binding");
        p.identityRecordHash = keccak256("identity");
        p.acceptanceRecordHash = keccak256("acceptance");
        p.snapshotHash = keccak256("Artist snapshot");
        p.locked = true;
        ViewConfigurationBoundary(config.targets[2])
            .set(
                abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (uint256(7))),
                abi.encode(p)
            );
    }

    function _prepare(string memory image, uint256 count) internal {
        delete source;
        delete context;
        delete publication;
        delete receipt;
        delete statement;
        delete evidence;
        delete coverage;
        statement.scope = StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 7, 0, keccak256("complete view membership")
        );
        statement.contentRoot = keccak256("authorized root boundary");
        source.scopeSubject =
            StreamMetadataSubjects.scopeSubject(originalChain, config.targets[0], statement.scope);
        source.snapshot.recordHash = keccak256("snapshot record boundary");
        source.snapshot.revision = 1;
        source.contentRootRecordHash = keccak256("root record boundary");
        A.Record memory adopted;
        adopted.input.scope = statement.scope;
        adopted.input.viewId = keccak256("declared view");
        adopted.input.viewRecordHash = keccak256("view declaration record");
        adopted.recordHash = keccak256("adopted record boundary");
        adopted.source.route.binding.views = address(declarations);
        adopted.source.route.binding.viewsCodeHash = address(declarations).codehash;
        bytes memory payload = abi.encode(
            A.Payload(
                keccak256("STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2"),
                "composition",
                "complete inline script",
                image,
                bytes("document.body.dataset.test='complete';")
            )
        );
        store.publishChunk(payload);
        PayloadBytes.capture(address(store), payload, adopted.source);
        Declaration.CollectionViewManifest memory d = Declaration.CollectionViewManifest(
            adopted.input.viewId,
            Payload.SCHEMA_ID,
            "ipfs://typed/declaration",
            keccak256(payload),
            "application/octet-stream",
            false
        );
        Declaration.ViewReceipt memory r;
        r.collectionId = 7;
        r.viewId = d.viewId;
        r.revision = 1;
        Records.CollectionRecord memory record;
        declarations.set(
            abi.encodeCall(Declaration.viewRecord, (adopted.input.viewRecordHash)),
            abi.encode(d, r, record)
        );
        adopted.source.viewReceiptHash = keccak256(abi.encode(r));
        adopted.source.manifestPayloadHash =
            keccak256(abi.encode(uint256(7), r.revision, r.previousRecordHash, d));
        source.snapshotSource.adoption.adoption = adopted;
        source.snapshotSource.adoption.contextHash = keccak256("source context boundary");
        source.snapshotSource.outputs.header.checkpointId =
            keccak256("complete checkpoint boundary");
        context.scope = statement.scope;
        context.subject = source.scopeSubject;
        context.artistId = mediaObject.artistId;
        context.snapshot = source.snapshot;
        context.nativeHash = keccak256(abi.encode(source.snapshotSource));
        context.rootRecordHash = source.contentRootRecordHash;
        context.adoptionRecord = adopted.recordHash;
        context.checkpointHash = source.snapshotSource.outputs.header.checkpointId;
        context.sourceContextHash = source.snapshotSource.adoption.contextHash;
        context.viewId = d.viewId;
        context.payloadHash = keccak256(payload);
        publication.scope = statement.scope;
        publication.observation.collectionId = 7;
        publication.observation.referenceId = keccak256("reference");
        publication.observation.snapshotRecordHash = source.snapshot.recordHash;
        publication.observation.snapshotRevision = 1;
        publication.observation.expectedSourcesHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_SOURCES_V1"),
                originalChain,
                selected.referencePublication,
                referenceDeps.targets,
                referenceDeps.codeHashes,
                source
            )
        );
        publication.observation.effectiveAt = uint64(observedAt);
        publication.observation.reasonHash = keccak256("reason");
        for (uint256 i; i < count; ++i) {
            O.Capture memory c;
            c.tokenId = 11 + i;
            c.collectionSerial = 7 + i;
            c.objectHash = pngObject;
            c.coverageHash = keccak256("typed original capture coverage");
            c.repeatCaptureSha256 = [pngDigest, pngDigest];
            publication.observation.captures.push(c);
        }
        _saveReference();
        ViewConfigurationBoundary(selected.referencePublication)
            .set(
                abi.encodeCall(Reference.referenceSource, (receipt.observation.recordHash)),
                abi.encode(source)
            );
        context.referenceRender = receipt;
        delete rows;
        T.Item[] memory actual = Artwork.items(inventory, context);
        for (uint256 i; i < actual.length; ++i) {
            rows.push(actual[i]);
        }
        evidence.scope = statement.scope;
        evidence.inventory.artistId = mediaObject.artistId;
        evidence.inventory.collectionId = 7;
        evidence.inventory.scopeSubject = source.scopeSubject;
        evidence.inventory.planId = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_PLAN_V1"),
                originalChain,
                selected.renderCriticalInventory,
                keccak256(abi.encode(inventory)),
                context
            )
        );
        evidence.inventory.renderCriticalEvidenceHash =
            keccak256("typed complete inventory evidence");
        evidence.inventory.itemCount = 9;
        evidence.inventory.segmentCount = 2;
        bytes32 witness = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_OUTPUT_INVENTORY_SOURCE_V1"),
                context.adoptionRecord,
                context.checkpointHash,
                context.sourceContextHash,
                uint16(8),
                uint64(0),
                uint64(7)
            )
        );
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_SEGMENT_V1"),
                evidence.inventory.planId,
                uint64(1)
            )
        );
        artworkSegment = Chains.segmentInMemory(key, witness, actual);
        T.Segment memory prefix;
        prefix.key = keccak256("previous actual stage boundary");
        prefix.sourceWitnessHash = keccak256("prefix witness");
        prefix.itemCount = 2;
        _segment(0, prefix);
        _segment(1, artworkSegment);
        coverage.scope = statement.scope;
        coverage.coverage.inventoryPlan = evidence.inventory.planId;
        coverage.coverage.renderCriticalEvidenceHash = evidence.inventory.renderCriticalEvidenceHash;
        coverage.coverage.itemCount = 9;
        coverage.coverage.bundleCoverageHash = keccak256("typed complete bundle evidence");
        statement.inputs.renderCriticalEvidenceHash = evidence.inventory.renderCriticalEvidenceHash;
        statement.inputs.bundleCoverageHash = coverage.coverage.bundleCoverageHash;
        ViewConfigurationBoundary(selected.renderCriticalInventory)
            .set(abi.encodeCall(Inventory.requireCurrent, (statement.scope)), abi.encode(evidence));
        ViewConfigurationBoundary(selected.renderCriticalInventory)
            .set(
                abi.encodeCall(Inventory.sourceContext, (evidence.inventory.planId)),
                abi.encode(context)
            );
        ViewConfigurationBoundary(selected.bundleArchiveCoverage)
            .set(
                abi.encodeCall(
                    Coverage.requireCoverage,
                    (
                        statement.scope,
                        evidence.inventory.planId,
                        evidence.inventory.renderCriticalEvidenceHash
                    )
                ),
                abi.encode(coverage)
            );
        if (bytes(image).length != 0) {
            if (!skipAdmission) {
                (admitted,) = Archive.admit(bundle, mediaObject.artistId, rows[5], proof);
            }
            _admitted(rows[5], admitted);
        }
    }

    function _saveReference() internal {
        O.Publication memory p = publication.observation;
        receipt.scopeSubject = source.scopeSubject;
        O.Receipt memory r;
        r.collectionId = 7;
        r.referenceId = p.referenceId;
        r.revision = 1;
        r.payloadHash = keccak256(abi.encode(publication));
        r.payloadBytes = uint32(abi.encode(publication).length);
        r.sourcesHash = p.expectedSourcesHash;
        r.snapshotRecordHash = p.snapshotRecordHash;
        r.snapshotRevision = 1;
        r.recorder = address(this);
        r.authorizationClass = 3;
        r.grantRevision = 1;
        r.effectiveAt = p.effectiveAt;
        r.recordedAt = uint64(observedAt);
        r.reasonHash = p.reasonHash;
        r.schemaHash = Definitions.SCHEMA_HASH;
        r.profileHash = Definitions.PROFILE_HASH;
        r.canonicalizationHash = Definitions.CANON_HASH;
        receipt.observation = r;
        r.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_RECORD_V1"),
                originalChain,
                selected.referencePublication,
                config.targets[0],
                config.targets[1],
                publication,
                receipt
            )
        );
        r.recordChainHash = keccak256("original reference chain boundary");
        receipt.observation = r;
        statement.inputs.snapshotRecordHash = r.snapshotRecordHash;
        statement.inputs.referenceRenderRecordHash = r.recordHash;
        statement.referenceRenderManifestHash = r.payloadHash;
        statement.entropy.referenceProfileHash = r.profileHash;
        ViewConfigurationBoundary(selected.referencePublication)
            .set(abi.encodeCall(Reference.currentReference, (statement.scope)), abi.encode(receipt));
        ViewConfigurationBoundary(selected.referencePublication)
            .set(
                abi.encodeCall(Reference.referenceRecord, (r.recordHash)),
                abi.encode(publication, receipt)
            );
    }

    function _segment(uint64 ordinal, T.Segment memory value) internal {
        ViewConfigurationBoundary(selected.renderCriticalInventory)
            .set(
                abi.encodeCall(Inventory.inventorySegment, (evidence.inventory.planId, ordinal)),
                abi.encode(value)
            );
    }

    function _admitted(T.Item memory item, B.Admission memory value) internal {
        ViewConfigurationBoundary(selected.bundleArchiveCoverage)
            .set(
                abi.encodeCall(Bundle.admittedItem, (evidence.inventory.planId, uint64(7))),
                abi.encode(item, value)
            );
    }

    function _mediaHash() internal view returns (bytes32) {
        return keccak256(abi.encode(consumer.media(statement)));
    }

    function _reviewHash() internal view returns (bytes32) {
        return keccak256(abi.encode(consumer.review(statement)));
    }

    function _mediaRefuses(bytes memory expectedError) internal {
        (bool ok, bytes memory out) =
            address(consumer).staticcall(abi.encodeCall(consumer.media, (statement)));
        require(!ok, "media unexpectedly accepted");
        if (expectedError.length != 0) {
            require(keccak256(out) == keccak256(expectedError), "exact media refusal");
        }
    }

    function _reviewRefuses(bytes memory expectedError) internal {
        (bool ok, bytes memory out) =
            address(consumer).staticcall(abi.encodeCall(consumer.review, (statement)));
        require(!ok, "review unexpectedly accepted");
        if (expectedError.length != 0) {
            require(keccak256(out) == keccak256(expectedError), "exact review refusal");
        }
    }
}
