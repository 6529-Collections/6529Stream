// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ScopedPolicyContentFixtureV2
} from "../finality/StreamScopedPolicyContentCheckpointV2.t.sol";
import { StaticRouteVm } from "../../helpers/StaticMetadataRoutingFixture.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { LeafManifestVm } from "../finality/StreamContentLeafManifest.t.sol";
import {
    LeafManifestArchiveBoundary,
    LeafManifestFinalityBoundary
} from "../../helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol";
import {
    StreamScopedPolicySnapshotPublicationV2 as Snapshot
} from "../../../smart-contracts/domains/metadata/StreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as SnapshotInterface
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedSnapshotPublication as OriginalScopedSnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedSnapshotPublication.sol";
import {
    IStreamPolicySnapshotPublicationV2 as CollectionPolicySnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicyContentCheckpointV2 as ContentHost
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    StreamScopedPolicyOutputManifestV2 as OutputHost
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputManifestV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as Outputs
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputDocuments
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol";
import {
    StreamFinalityArtifactCoverage
} from "../../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import {
    StreamFinalityArtifactTypes as Artifacts
} from "../../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamMetadataServingFacts as Serving
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamMetadataRouter
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    IStreamCorePointers
} from "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as SourceSet
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamEntropyCollectionPolicy as EntropyPolicy
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamRecordFamilies as Families
} from "../../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as SnapshotDocuments
} from "../../../smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as SnapshotReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicySnapshotReadsV2.sol";
import {
    StreamFinalitySnapshotEvidence
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalitySnapshotTypes.sol";
import {
    IStreamFinalityEntropySourceFactory as FactoryReads
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityScopeMembership as MembershipReads
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    StreamScopeMembershipFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    IStreamScopedPolicyContentRootEvidenceBindingV2 as RootProvider
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentRootEvidenceBindingV2.sol";
import {
    IStreamScopedContentRootPublication as ScopedRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as PolicyRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    StreamScopedPolicyContentRootSchemasV2 as RootDocuments
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyContentRootSchemasV2.sol";

import {
    ScopedPolicySnapshotRootProviderBoundaryV2
} from "../metadata/StreamScopedPolicySnapshotPublicationV2.t.sol";
import {
    StreamScopedPolicyReferencePublicationV2 as Ref
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyReferencePublicationV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as RefT
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    StreamReferenceRenderTypes as RefR
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamFinalityScopedPolicyReferenceReadsV2 as RefReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyReferenceReadsV2.sol";
import {
    IStreamScopedPolicyReferencePublicationV2 as RefInterface
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import {
    IStreamScopedReferencePublication as RefV1
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedReferencePublication.sol";
import {
    IStreamReferenceModePublication as MetricInterface
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamReferenceModePublication.sol";
import {
    StreamScopedPolicyReferenceDefinitionsV2 as RefDocuments
} from "../../../smart-contracts/domains/records/StreamScopedPolicyReferenceDefinitionsV2.sol";
import {
    StreamReferenceRenderDefinitions as OriginalDefinitions
} from "../../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamReferenceEnvironmentJson
} from "../../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamExternalArtifactTypes as External
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamExternalArtifactCoverage as ExternalArchive
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    IStreamExternalArtifactCurrentPair
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    StreamSnapshotManifestBytes as StoredBytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import {
    StreamFinalityComponentState
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Named external-object/fixity boundary, not an actual archival ceremony. Full scoped
/// snapshot/output/factory/Router/reference and immutable Store are genuine producers below.
contract ScopedPolicyReferenceExternalBoundaryV2 {
    address public immutable core;

    constructor(address value) {
        core = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamExternalArtifactCurrentPair).interfaceId;
    }
}

contract ScopedPolicyReferenceReaderProbeV2 {
    function original(
        RefReads.Dependencies calldata d,
        StreamFinalityScope calldata scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (RefT.Publication memory, RefT.Receipt memory) {
        return RefReads.original(d, scope, hash, revision);
    }

    function current(
        RefReads.Dependencies calldata d,
        StreamFinalityScope calldata scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (RefT.Receipt memory) {
        return RefReads.requireCurrent(d, scope, hash, revision);
    }

    function locked(
        RefReads.Dependencies calldata d,
        StreamFinalityScope calldata scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (RefT.Receipt memory, RefR.Lock memory) {
        return RefReads.requireLocked(d, scope, hash, revision);
    }

    function component(
        RefReads.Dependencies calldata d,
        StreamFinalityScope calldata scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (StreamFinalityComponentState memory) {
        return RefReads.component(d, scope, hash, revision);
    }
}

/// @notice Actual native policy/finalization, scoped factory, complete output/snapshot, original
/// Router V2 root, reference lifecycle, Metadata grants, schemas/Store and threshold Safe.
/// @dev Core identity, original Artist consent/presentation, renderer admission, governance action
/// and external capture archive are explicit boundaries inherited or named here. BYTE_EXACT only;
/// no metric proof, browser execution, current-stack finality or gas/capacity acceptance is claimed.
abstract contract ScopedPolicyReferenceFixtureV2 is ScopedPolicyContentFixtureV2 {
    bytes32 internal constant SNAPSHOT_ARTIST = keccak256("scoped snapshot locked artist boundary");
    StaticRouteVm internal constant snapshotVm = StaticRouteVm(address(vm));
    LeafManifestVm internal constant createVm = LeafManifestVm(address(vm));
    StreamSchemaDocumentStore internal snapshotStore;
    StreamFinalityArtifactCoverage internal snapshotCoverage;
    LeafManifestArchiveBoundary internal snapshotArchive;
    ContentHost internal snapshotContent;
    OutputHost internal snapshotOutputs;
    Snapshot internal snapshotHost;
    Snap.Publication internal publication;
    Serving.ArtistPresentation internal lockedArtistBoundary;

    Ref internal referenceHost;
    RefT.Publication internal referenceInput;
    ScopedPolicyReferenceExternalBoundaryV2 internal externalArchive;
    bytes32 internal adoptedRoot;
    bytes32 internal adoptedSnapshot;

    function _reference(uint8 terminalStatus, uint8 scopeKind) internal {
        _initialize(terminalStatus);
        _prepare(scopeKind);
        _configureJoinedRootBoundary();
        adoptedSnapshot = _publish();
        adoptedRoot = _adopt(adoptedSnapshot, 1);
        externalArchive = new ScopedPolicyReferenceExternalBoundaryV2(address(core));
        referenceInput.scope = publication.scope;
        referenceInput.observation.collectionId = publication.scope.collectionId;
        referenceInput.observation.referenceId = keccak256("scoped policy exact reference");
        referenceInput.observation.snapshotRecordHash = adoptedSnapshot;
        referenceInput.observation.snapshotRevision = 1;
        referenceInput.observation.effectiveAt = uint64(block.timestamp);
        referenceInput.observation.reasonHash = keccak256("repeat actual full-policy rendering");
        referenceInput.observation.manifestURI = "ipfs://scoped-policy-reference";
        _environment();
        uint256 count = scopedMembership.requireScopeMembership(publication.scope).tokenCount;
        referenceInput.observation.captures = new RefR.Capture[](count == 1 ? 1 : 2);
        for (uint256 i; i < referenceInput.observation.captures.length; ++i) {
            uint256 token = scopedMembership.scopeTokenAt(publication.scope, i == 0 ? 0 : count - 1);
            (,, uint256 serial,) = core.tokenCollectionIdentity(token);
            bytes memory html = bytes(router.tokenHTML(token));
            RefR.Capture memory c;
            c.tokenId = token;
            c.collectionSerial = serial;
            c.metadataJSONHash = keccak256(bytes(router.tokenJSON(token)));
            c.htmlHash = keccak256(html);
            c.htmlBytes = uint32(html.length);
            c.animationHTML = html;
            c.objectHash = keccak256(abi.encode("typed PNG object", token));
            c.coverageHash = keccak256(abi.encode("typed PNG coverage", token));
            c.sourceSha256 = sha256(html);
            c.repeatCaptureSha256 = [
                keccak256(abi.encode("same PNG", token)), keccak256(abi.encode("same PNG", token))
            ];
            c.environmentManifestHash = referenceInput.observation.environment.manifestHash;
            c.capturedAt = uint64(block.timestamp);
            referenceInput.observation.captures[i] = c;
            _external(c.objectHash, c.coverageHash, c.repeatCaptureSha256[0], false);
        }
        _registerReferenceDefinitions();
        _familyGrant(1, Families.CURATOR, 3, address(this), true);
        RefT.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(snapshotStore),
            address(router),
            address(snapshotHost),
            address(externalArchive)
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        referenceHost = new Ref(d, address(executor), _referenceGas());
        _upload(
            bytes(
                StreamReferenceEnvironmentJson.files(
                    referenceInput.observation.environment.packageFiles, true
                )
            ),
            false
        );
        _upload(
            bytes(
                StreamReferenceEnvironmentJson.files(
                    referenceInput.observation.environment.platformPrerequisites, false
                )
            ),
            false
        );
        referenceHost.prepareFileInventory(
            referenceInput.observation.environment.packageFiles, true
        );
        referenceHost.prepareFileInventory(
            referenceInput.observation.environment.platformPrerequisites, false
        );
    }

    function _referenceGas() internal pure returns (Gas.GasParameterConfig[4] memory configs) {
        // Parent reservations intentionally cover the genuine nested whole-scope producers.
        // They are fixture caps, not transaction/gas acceptance evidence.
        configs[0] = Gas.GasParameterConfig("SCOPED_POLICY_REFERENCE_READ_GAS", 2000000, 50000, 1);
        configs[1] = Gas.GasParameterConfig("SCOPED_POLICY_REFERENCE_SOURCE_GAS", 8000000, 50000, 1);
        configs[2] =
            Gas.GasParameterConfig("SCOPED_POLICY_REFERENCE_SNAPSHOT_GAS", 128000000, 50000, 1);
        configs[3] =
            Gas.GasParameterConfig("SCOPED_POLICY_REFERENCE_ARCHIVE_GAS", 2000000, 50000, 1);
    }

    function _adopt(bytes32 snapshot, uint64 revision) internal returns (bytes32) {
        ScopedRoot.Publication memory p = ScopedRoot.Publication(
            publication.scope,
            router.scopedContentRootHead(publication.scope),
            snapshot,
            revision,
            "ipfs://scoped-policy-reference-root"
        );
        bytes32 next = router.previewScopedPolicyContentRootPublication(p, address(this));
        artist.approve(
            1,
            keccak256("CONTENT_ROOT"),
            next,
            keccak256(abi.encode("explicit original Artist op17", next))
        );
        return router.publishScopedPolicyContentRootPublication(p);
    }

    function _referenceBytes(address recorder) internal returns (bytes memory raw) {
        (bytes32 sources, bytes memory payload) =
            referenceHost.previewReference(referenceInput, recorder);
        referenceInput.observation.expectedSourcesHash = sources;
        _upload(abi.encode(referenceInput), false);
        return payload;
    }

    function _publishReference() internal returns (bytes32) {
        _upload(_referenceBytes(address(this)), false);
        return referenceHost.publishReference(referenceInput);
    }

    function _assertReferencePayload(bytes memory raw, RefT.SourceFacts memory expected)
        internal
        view
    {
        (
            bytes32 domain,
            uint256 chain,
            address host,
            RefT.Publication memory p,
            RefT.Receipt memory r,
            RefT.SourceFacts memory f,
            bytes memory environment
        ) = abi.decode(
            raw,
            (bytes32, uint256, address, RefT.Publication, RefT.Receipt, RefT.SourceFacts, bytes)
        );
        require(
            domain == keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_PAYLOAD_V2")
                && chain == block.chainid && host == address(referenceHost)
        );
        require(keccak256(raw) == keccak256(abi.encode(domain, chain, host, p, r, f, environment)));
        require(keccak256(abi.encode(f)) == keccak256(abi.encode(expected)));
        require(
            p.observation.expectedSourcesHash == 0
                && r.observation.sourcesHash == referenceInput.observation.expectedSourcesHash
        );
        require(
            r.observation.recordHash == 0 && r.observation.recordChainHash == 0
                && r.observation.payloadHash == 0 && r.observation.payloadBytes == 0
                && r.observation.recordedAt == 0
        );
        require(
            keccak256(environment) == referenceInput.observation.environment.manifestHash
                && environment.length == referenceInput.observation.environment.manifestBytes
        );
        require(keccak256(abi.encode(p.scope)) == keccak256(abi.encode(referenceInput.scope)));
    }

    function _referenceHistory(bytes32 hash) internal view returns (bytes32) {
        (RefT.Publication memory p, RefT.Receipt memory r) = referenceHost.referenceRecord(hash);
        return keccak256(
            abi.encode(
                p, r, referenceHost.referencePayload(hash), referenceHost.referenceSource(hash)
            )
        );
    }

    function _referenceReader() internal view returns (RefReads.Dependencies memory d) {
        d.targets = [
            address(core),
            address(metadata),
            address(router),
            address(snapshotHost),
            address(referenceHost)
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 2000000;
        d.sourceGas = 256000000;
    }

    function _referenceAction(uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) internal {
        snapshotVm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(
                true, keccak256("exact scoped policy reference lock"), cls, scope, oldHash, newHash
            )
        );
    }

    function _environment() internal {
        RefR.Environment memory e;
        e.objectHash = keccak256("runtime object");
        e.coverageHash = keccak256("runtime coverage");
        e.engineName = "Google Chrome";
        e.engineVersion = "fixture";
        e.engineExecutableSha256 = keccak256("engine bytes boundary");
        e.toolchainName = "reference_capture.py; Python; websockets";
        e.toolchainVersion = "fixture";
        e.toolchainSha256 = keccak256("tool bytes boundary");
        e.engineExecutablePath = "engine/chrome.exe";
        e.toolchainPath = "tool/reference_capture.py";
        e.packageFiles = new RefR.PackageFile[](2);
        e.packageFiles[0] = RefR.PackageFile(e.engineExecutablePath, 10, e.engineExecutableSha256);
        e.packageFiles[1] = RefR.PackageFile(e.toolchainPath, 11, e.toolchainSha256);
        e.platformPrerequisites = new RefR.PackageFile[](1);
        e.platformPrerequisites[0] = RefR.PackageFile(
            "C:/Windows/system32/kernel32.dll", 12, keccak256("explicit OS boundary")
        );
        e.operatingSystem = "Windows";
        e.operatingSystemVersion = "fixture";
        e.architecture = "AMD64";
        e.viewportWidth = 64;
        e.viewportHeight = 64;
        e.devicePixelRatio = 1;
        e.colorSpace = "srgb";
        e.softwareRasterization = true;
        e.captureProfile = keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1");
        e.licenseNote = "undetermined";
        bytes memory raw = StreamReferenceEnvironmentJson.manifest(e);
        e.manifestHash = keccak256(raw);
        e.manifestBytes = uint32(raw.length);
        referenceInput.observation.environment = e;
        _external(e.objectHash, e.coverageHash, keccak256("ZIP SHA boundary"), true);
    }

    function _external(bytes32 object, bytes32 cover, bytes32 sha, bool runtime) internal {
        External.Coverage memory e;
        e.coverageHash = cover;
        e.objectHash = object;
        e.artistId = SNAPSHOT_ARTIST;
        e.contentHash = keccak256(abi.encode("content", object));
        e.sha256Digest = sha;
        e.arweaveDataRoot = keccak256(abi.encode("archive", object));
        e.byteSize = 55;
        e.firstFamilyRecordHash = bytes32(uint256(1));
        e.secondFamilyRecordHash = bytes32(uint256(2));
        e.firstReceiptHash = keccak256(abi.encode("receipt1", object));
        e.secondReceiptHash = keccak256(abi.encode("receipt2", object));
        e.firstFixityHash = bytes32(uint256(3));
        e.secondFixityHash = bytes32(uint256(4));
        e.checkpointHash = keccak256("archive checkpoint boundary");
        e.profileHash = keccak256("archive profile boundary");
        External.ObjectIdentity memory o = External.ObjectIdentity(
            e.artistId,
            runtime ? OriginalDefinitions.ZIP_SCHEMA_ID : OriginalDefinitions.PNG_SCHEMA_ID,
            keccak256("RAW_BYTES"),
            e.contentHash,
            sha,
            e.arweaveDataRoot,
            e.byteSize,
            runtime ? keccak256("IANA:application/zip") : keccak256("IANA:image/png"),
            OriginalDefinitions.FORMAT_CATALOG_ID,
            OriginalDefinitions.FORMAT_CATALOG_HASH
        );
        External.CurrentPair memory pair = External.CurrentPair(
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
        snapshotVm.mockCall(
            address(externalArchive),
            abi.encodeCall(ExternalArchive.requireCoverage, (cover, e.artistId, object)),
            abi.encode(e)
        );
        snapshotVm.mockCall(
            address(externalArchive),
            abi.encodeCall(ExternalArchive.coverage, (cover)),
            abi.encode(e)
        );
        snapshotVm.mockCall(
            address(externalArchive),
            abi.encodeCall(ExternalArchive.objectIdentity, (object)),
            abi.encode(o)
        );
        snapshotVm.mockCall(
            address(externalArchive),
            abi.encodeCall(
                IStreamExternalArtifactCurrentPair.currentReceiptPair,
                (e.firstReceiptHash, e.secondReceiptHash, e.artistId, object)
            ),
            abi.encode(pair)
        );
    }

    function _registerReferenceDefinitions() internal {
        string[3] memory names = [
            "STREAM_SCOPED_POLICY_REFERENCE_ABI_V2",
            "STREAM_SCOPED_POLICY_REFERENCE_PROFILE_V2",
            "STREAM_ABI_SCOPED_POLICY_REFERENCE_V2"
        ];
        string[3] memory files = [
            "scoped-policy-reference-v2.schema.json",
            "scoped-policy-reference-v2.profile.json",
            "scoped-policy-reference-v2.abi.json"
        ];
        for (uint256 i; i < 3; ++i) {
            _register(
                names[i],
                i == 0
                    ? Schema.DocumentKind.SCHEMA
                    : i == 1 ? Schema.DocumentKind.CATALOG : Schema.DocumentKind.CANONICALIZATION,
                bytes(vm.readFile(string.concat("docs/schemas/preservation/", files[i])))
            );
        }
        string[4] memory originals = [
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1"
        ];
        for (uint256 i; i < 4; ++i) {
            _register(
                originals[i],
                i == 3 ? Schema.DocumentKind.CATALOG : Schema.DocumentKind.SCHEMA,
                bytes(vm.readFile(string.concat("schemas/records/", originals[i], ".json")))
            );
        }
    }

    function _configureJoinedRootBoundary() internal {
        _register(
            "STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2",
            Schema.DocumentKind.SCHEMA,
            OutputDocuments.document(OutputDocuments.LEAF_SCHEMA)
        );
        _register(
            "STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
            Schema.DocumentKind.SCHEMA,
            RootDocuments.document(RootDocuments.ROOT_SCHEMA)
        );
        _register(
            "STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
            Schema.DocumentKind.CANONICALIZATION,
            RootDocuments.document(RootDocuments.ROOT_CANON)
        );
        ScopedPolicySnapshotRootProviderBoundaryV2 provider = new ScopedPolicySnapshotRootProviderBoundaryV2(
            address(snapshotHost), publication.scope
        );
        // Keep the coverage constructor's original selected Finality and runtime pin. Only these
        // missing deployment/read capabilities of that explicitly named boundary are supplied.
        address finality = _joinedFinalityAddress();
        _mockWord(finality, "scopeEvidenceProvider()", abi.encode(address(provider)));
        _mockWord(
            finality, "scopeEvidenceProviderCodeHash()", abi.encode(address(provider).codehash)
        );
        _mockWord(finality, "coreReads()", abi.encode(address(core)));
        _mockWord(finality, "metadataReads()", abi.encode(address(metadata)));
        _mockWord(finality, "sanctionReads()", abi.encode(address(artist)));
        snapshotVm.mockCall(
            finality,
            abi.encodeCall(
                Gas.gasParameter, (keccak256("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS"))
            ),
            abi.encode(uint256(2000000))
        );
        snapshotVm.mockCall(
            finality,
            abi.encodeWithSignature(
                "artworkFreezeMode((uint8,uint256,uint256,bytes32))", publication.scope
            ),
            abi.encode(uint8(0))
        );
        _mockWord(address(artist), "finalityRegistry()", abi.encode(finality));
        _mockWord(address(artist), "finalityRegistryCodeHash()", abi.encode(finality.codehash));
        snapshotVm.mockCall(
            address(artist),
            abi.encodeWithSignature("collectionArtistState(uint256)", uint256(1)),
            abi.encode(
                uint8(2),
                lockedArtistBoundary.bindingGeneration,
                SNAPSHOT_ARTIST,
                uint8(1),
                lockedArtistBoundary.bindingHash
            )
        );
    }

    function _joinedFinalityAddress() internal view returns (address finality) {
        (finality,,,,,,,,,) = core.getSatellitePointer(keccak256("ARTWORK_FINALITY_REGISTRY"));
    }

    function _mockWord(address target, string memory selector, bytes memory value) internal {
        snapshotVm.mockCall(target, abi.encodeWithSignature(selector), value);
    }

    function _initialize(uint8 terminalStatus) internal {
        _scopedFixture(terminalStatus, true);
        snapshotStore = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            Schema.DocumentKind.SCHEMA,
            OutputDocuments.document(OutputDocuments.SCHEMA)
        );
        _register(
            "STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            Schema.DocumentKind.CANONICALIZATION,
            OutputDocuments.document(OutputDocuments.CANON)
        );
        _register(
            "STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2",
            Schema.DocumentKind.SCHEMA,
            SnapshotDocuments.document(SnapshotDocuments.SCHEMA_ID)
        );
        _register(
            "STREAM_SCOPED_POLICY_SNAPSHOT_PROFILE_V2",
            Schema.DocumentKind.CATALOG,
            SnapshotDocuments.document(SnapshotDocuments.PROFILE_ID)
        );
        _register(
            "STREAM_ABI_SCOPED_POLICY_SNAPSHOT_V2",
            Schema.DocumentKind.CANONICALIZATION,
            SnapshotDocuments.document(SnapshotDocuments.CANON_ID)
        );
        _familyGrant(1, Families.SNAPSHOT, 7, address(this), true);
        _familyGrant(1, Families.IDENTITY, 7, address(this), true);
        // Explicitly extend the fixture's typed module admission to the genuine Router.
        snapshotVm.mockCall(
            address(scopedModules),
            abi.encodeWithSignature(
                "isModuleEligible(address,bytes32,bytes4)",
                address(router),
                keccak256("METADATA_ROUTER"),
                type(IStreamMetadataRouter).interfaceId
            ),
            abi.encode(true)
        );
        lockedArtistBoundary = Serving.ArtistPresentation(
            true,
            address(artist),
            address(artist).codehash,
            SNAPSHOT_ARTIST,
            1,
            keccak256("locked Artist binding boundary"),
            address(0xA11CE),
            keccak256("locked Artist identity boundary"),
            keccak256("locked Artist acceptance boundary"),
            900,
            950,
            keccak256("locked Artist presentation boundary")
        );
        _setLockedArtistBoundary();
        snapshotArchive = new LeafManifestArchiveBoundary(address(core), address(executor));
        address predicted = createVm.computeCreateAddress(
            address(this), uint256(createVm.getNonce(address(this))) + 1
        );
        snapshotCoverage = new StreamFinalityArtifactCoverage(
            address(core),
            address(snapshotArchive),
            address(schemas),
            address(snapshotStore),
            predicted,
            address(executor),
            Gas.GasParameterConfig("FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 300000, 300000, 2)
        );
        address finality =
            address(new LeafManifestFinalityBoundary(address(core), address(snapshotCoverage)));
        require(finality == predicted);
        snapshotVm.mockCall(
            address(core),
            abi.encodeCall(
                IStreamCorePointers.getSatellitePointer, (keccak256("ARTWORK_FINALITY_REGISTRY"))
            ),
            abi.encode(
                finality,
                finality.codehash,
                false,
                keccak256("ARTWORK_FINALITY_REGISTRY"),
                bytes4(0),
                address(0),
                uint8(1),
                bytes32(0),
                bytes32(0),
                uint64(1)
            )
        );
    }

    function _prepare(uint8 kind) internal {
        StreamFinalityScope memory scope = _scopedScope(kind);
        bytes32 selected;
        (snapshotContent, selected) = _scopedCapture(scope);
        bytes32 checkpoint =
            snapshotContent.begin(selected, keccak256("original scoped snapshot output"));
        snapshotContent.append(checkpoint, _scopedPayload(scope));
        Content.Plan memory p = snapshotContent.requireCurrentCheckpoint(checkpoint);
        Content.Output[] memory rows = new Content.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = snapshotContent.outputAt(checkpoint, i);
        }
        bytes memory raw = abi.encode(
            OutputDocuments.SCHEMA,
            block.chainid,
            address(core),
            address(snapshotContent),
            checkpoint,
            keccak256(abi.encode(p)),
            snapshotContent.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            rows
        );
        (bytes32 artifact, bytes32 coverage) = _archive(raw);
        snapshotOutputs = new OutputHost(
            address(core),
            address(snapshotContent),
            address(snapshotCoverage),
            address(executor),
            Gas.GasParameterConfig("STATIC_OUTPUT_MANIFEST_READ_GAS", 32000000, 100000, 2)
        );
        bytes32 plan =
            snapshotOutputs.beginManifest(checkpoint, artifact, coverage, SNAPSHOT_ARTIST);
        bytes32 output = snapshotOutputs.verifyNextOutputs(plan, p.tokenCount);
        require(output != 0 && snapshotOutputs.schemaRegistry() == address(schemas));
        Snap.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(snapshotStore),
            address(router),
            address(scopedMembership),
            address(scopedSelections),
            address(snapshotContent),
            address(snapshotOutputs),
            address(snapshotCoverage),
            snapshotContent.entropySourceSet()
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        snapshotHost = new Snapshot(d, address(executor), _snapshotGas());
        publication = Snap.Publication(
            scope,
            keccak256(abi.encode("scoped snapshot", kind)),
            0,
            0,
            output,
            SourceSet(d.targets[10]).inventoryPlan(),
            0,
            "ipfs://scoped-policy-snapshot",
            1000,
            keccak256("complete original native policies and output")
        );
    }

    function _snapshotGas() internal pure returns (Gas.GasParameterConfig[3] memory configs) {
        // Reserve genuine nested checkpoint/render reads; these caps are not a gas acceptance claim.
        configs[0] = Gas.GasParameterConfig("SCOPED_POLICY_SNAPSHOT_READ_GAS", 2000000, 50000, 2);
        configs[1] = Gas.GasParameterConfig("SCOPED_POLICY_SNAPSHOT_SOURCE_GAS", 64000000, 50000, 2);
        configs[2] =
            Gas.GasParameterConfig("SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS", 8000000, 50000, 2);
    }

    function _source(bytes memory raw) internal pure returns (Snap.Source memory f) {
        (,,,,,,, f) = abi.decode(
            raw,
            (
                bytes32,
                uint256,
                address,
                address[11],
                bytes32[11],
                Snap.Publication,
                Snap.Receipt,
                Snap.Source
            )
        );
    }

    function _historyHash(bytes32 hash) internal view returns (bytes32) {
        (Snap.Publication memory p, Snap.Receipt memory r) = snapshotHost.snapshotRecord(hash);
        return keccak256(abi.encode(p, r, snapshotHost.snapshotPayload(hash)));
    }

    function _setLockedArtistBoundary() internal {
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(Serving.artistPresentation, (uint256(1))),
            abi.encode(lockedArtistBoundary)
        );
    }

    function _familyGrant(
        uint256 collection,
        bytes32 family,
        uint8 cls,
        address account,
        bool enabled
    ) internal {
        (bytes32 scope, bytes32 old, bytes32 next) = metadata.familyWriterTransition(
            collection, family, cls, account, enabled
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(metadata.setFamilyWriter, (collection, family, cls, account, enabled)),
            scope,
            old,
            next
        );
    }

    function _preview(address publisher) internal returns (bytes memory raw) {
        (bytes32 source, bytes memory canonical) =
            snapshotHost.previewSnapshot(publication, publisher);
        publication.expectedSourceHash = source;
        return canonical;
    }

    function _publish() internal returns (bytes32) {
        _upload(_preview(address(this)), false);
        return snapshotHost.publishSnapshot(publication);
    }

    function _upload(bytes memory raw, bool omitLast) internal {
        uint256 count = (raw.length + 8191) / 8192;
        for (uint256 i; i < count - (omitLast ? 1 : 0); ++i) {
            snapshotStore.publishChunk(_chunk(raw, i));
        }
    }

    function _archive(bytes memory raw) internal returns (bytes32 artifact, bytes32 coverage) {
        Artifacts.Artifact memory a;
        a.artistId = SNAPSHOT_ARTIST;
        a.schemaId = OutputDocuments.SCHEMA;
        a.canonicalizationId = OutputDocuments.CANON;
        a.hashAlgorithm = 1;
        a.contentHash = keccak256(raw);
        a.byteLength = uint64(raw.length);
        uint256 count = (raw.length + 8191) / 8192;
        a.chunkHashes = new bytes32[](count);
        a.chunkLengths = new uint32[](count);
        for (uint256 i; i < count; ++i) {
            bytes memory part = _chunk(raw, i);
            address pointer;
            (a.chunkHashes[i], pointer) = snapshotStore.publishChunk(part);
            a.chunkLengths[i] = uint32(part.length);
            snapshotArchive.add(a.chunkHashes[i], pointer);
        }
        artifact = snapshotCoverage.recordArtifact(a);
        bytes32 plan = snapshotCoverage.beginCoverage(
            artifact, keccak256("archive family A"), keccak256("archive family B")
        );
        for (uint32 i; i < count; ++i) {
            coverage = snapshotCoverage.coverNextChunk(plan, i, a.chunkHashes[i]);
        }
    }

    function _register(string memory name, Schema.DocumentKind kind, bytes memory raw) internal {
        bytes32[] memory chunks = new bytes32[]((raw.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            (chunks[i],) = snapshotStore.publishChunk(_chunk(raw, i));
        }
        Schema.DocumentSpec memory spec = Schema.DocumentSpec(
            name, kind, keccak256(raw), schemas.RAW_BYTES(), 0, "", uint32(raw.length)
        );
        (bytes32 scope, bytes32 old, bytes32 next) = schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas),
            abi.encodeCall(schemas.registerDocument, (spec, chunks)),
            scope,
            old,
            next
        );
    }

    function _chunk(bytes memory raw, uint256 index) internal pure returns (bytes memory part) {
        uint256 take = raw.length - index * 8192;
        if (take > 8192) take = 8192;
        part = new bytes(take);
        for (uint256 i; i < take; ++i) {
            part[i] = raw[index * 8192 + i];
        }
    }
}

contract StreamScopedPolicyReferencePublicationV2Test is ScopedPolicyReferenceFixtureV2 {
    function testActualReleaseReferenceBindsOriginalRootFactoryAndMixedPolicySamples() public {
        _reference(1, 2);
        bytes memory raw = _referenceBytes(address(this));
        _upload(raw, false);
        vm.recordLogs();
        bytes32 hash = referenceHost.publishReference(referenceInput);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(referenceHost));
        (uint16 version, RefT.Receipt memory eventReceipt, string memory uri) =
            abi.decode(logs[0].data, (uint16, RefT.Receipt, string));
        RefT.Receipt memory r = referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(version == 2 && logs[0].topics.length == 4);
        require(
            logs[0].topics[1] == r.scopeSubject
                && logs[0].topics[2] == referenceInput.observation.referenceId
                && logs[0].topics[3] == hash
        );
        require(keccak256(bytes(uri)) == keccak256(bytes(referenceInput.observation.manifestURI)));
        require(keccak256(abi.encode(eventReceipt)) == keccak256(abi.encode(r)));
        require(
            r.observation.payloadHash == keccak256(raw)
                && keccak256(referenceHost.referencePayload(hash)) == keccak256(raw)
        );
        RefT.SourceFacts memory f = referenceHost.referenceSource(hash);
        _assertReferencePayload(raw, f);
        require(
            r.observation.recordChainHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_CHAIN_V2"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        r.scopeSubject,
                        bytes32(0),
                        uint64(1),
                        hash
                    )
                )
        );
        require(f.contentRootRecordHash == adoptedRoot && f.snapshot.recordHash == adoptedSnapshot);
        require(
            keccak256(abi.encode(f.contentRoot))
                == keccak256(abi.encode(router.scopedContentRootRecord(adoptedRoot)))
        );
        require(
            keccak256(abi.encode(f.contentRootBinding))
                == keccak256(abi.encode(router.scopedPolicyContentRootBinding(adoptedRoot)))
        );
        require(
            f.contentRootBinding.profileId == RootDocuments.PROFILE
                && f.contentRootBinding.sourceFactory == address(scopedFactory)
        );
        require(
            f.contentRootBinding.factoryDependenciesHash
                == keccak256(abi.encode(_scopedDependencies()))
        );
        require(
            f.samples.length == 2 && f.samples[0].membershipIndex == 0
                && f.samples[1].membershipIndex == 1
        );
        require(
            f.samples[0].observation.tokenId == 91 && f.samples[0].observation.collectionSerial == 1
        );
        require(
            f.samples[1].observation.tokenId == 92 && f.samples[1].observation.collectionSerial == 2
        );
        require(
            f.samples[0].entropy.terminal && !f.samples[0].entropy.finalized
                && f.samples[0].entropy.seed == 0 && f.samples[0].terminalAdmissionHash != 0
        );
        require(
            !f.samples[1].entropy.terminal && f.samples[1].entropy.finalized
                && f.samples[1].entropy.seed == scopedFinalizedSeed
                && f.samples[1].terminalAdmissionHash == 0
        );
        require(
            r.observation.sourcesHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_SOURCES_V2"),
                        block.chainid,
                        address(referenceHost),
                        referenceHost.dependencies().targets,
                        referenceHost.dependencies().codeHashes,
                        f
                    )
                )
        );
        RefT.Receipt memory fields = abi.decode(abi.encode(r), (RefT.Receipt));
        fields.observation.recordHash = 0;
        fields.observation.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_RECORD_V2"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        address(metadata),
                        referenceInput,
                        fields
                    )
                )
        );
        require(
            snapshotHost.requireCurrent(publication.scope, adoptedSnapshot, 1).recordHash
                == adoptedSnapshot
        );
        require(
            snapshotOutputs.requireCurrentManifest(
                publication.outputManifestRecord, SNAPSHOT_ARTIST
            )
            .manifestHash == f.snapshotSource.outputs.manifestHash
        );
    }

    function testActualSeasonNotRequiredRowStaysTerminalAndFinalizedRowKeepsSeed() public {
        _reference(2, 3);
        bytes32 hash = _publishReference();
        RefT.SourceFacts memory f = referenceHost.referenceSource(hash);
        require(f.snapshotSource.scope.scopeType == StreamFinalityScopeType.SEASON);
        require(
            f.samples[0].entropy.status == 2 && f.samples[0].entropy.mode == 2
                && f.samples[0].entropy.renderRequirement == 1
        );
        require(
            f.samples[0].entropy.terminal && !f.samples[0].entropy.finalized
                && f.samples[0].observation.seed == 0
        );
        require(
            f.samples[1].entropy.status == 5 && f.samples[1].observation.seed == scopedFinalizedSeed
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
    }

    function testTokenFullTupleCannotAliasCurrentHistoricalOrLockCalls() public {
        _reference(1, 1);
        bytes32 hash = _publishReference();
        require(referenceHost.referenceSource(hash).samples.length == 1);
        bytes32 saved = _referenceHistory(hash);
        StreamFinalityScope memory wrong = referenceInput.scope;
        wrong.collectionId = 2;
        ScopedPolicyReferenceReaderProbeV2 probe = new ScopedPolicyReferenceReaderProbeV2();
        RefReads.Dependencies memory d = _referenceReader();
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.currentReference(wrong);
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.requireCurrent(wrong, hash, 1);
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.lockTransition(wrong);
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.referenceAt(wrong, 0);
        vm.expectRevert(
            abi.encodeWithSelector(RefReads.InvalidScopedPolicyReferenceEvidence.selector)
        );
        probe.original(d, wrong, hash, 1);
        require(
            _referenceHistory(hash) == saved
                && referenceHost.referenceCount(referenceInput.scope) == 1
        );
        (, RefT.Receipt memory original) = probe.original(d, referenceInput.scope, hash, 1);
        require(original.observation.recordHash == hash);
    }

    function testActualRootSuccessorStalesCurrentReferenceButNeverHistoricalOriginal() public {
        _reference(1, 2);
        bytes32 first = _publishReference();
        bytes32 saved = _referenceHistory(first);
        bytes32 priorRoot = adoptedRoot;
        adoptedRoot = _adopt(adoptedSnapshot, 1);
        require(
            adoptedRoot != priorRoot
                && router.scopedContentRootRecord(adoptedRoot).publication.expectedPredecessor
                    == priorRoot
        );
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.requireCurrent(referenceInput.scope, first, 1);
        ScopedPolicyReferenceReaderProbeV2 probe = new ScopedPolicyReferenceReaderProbeV2();
        RefReads.Dependencies memory d = _referenceReader();
        (, RefT.Receipt memory retained) = probe.original(d, referenceInput.scope, first, 1);
        require(retained.observation.recordHash == first && _referenceHistory(first) == saved);
        referenceInput.observation.referenceId = keccak256("reference after actual root successor");
        referenceInput.observation.expectedHead = first;
        referenceInput.observation.expectedRevision = 1;
        bytes32 second = _publishReference();
        require(
            referenceHost.requireCurrent(referenceInput.scope, second, 2).observation.predecessor
                == first
        );
        require(referenceHost.referenceSource(second).contentRootRecordHash == adoptedRoot);
        require(
            _referenceHistory(first) == saved
                && referenceHost.referenceAt(referenceInput.scope, 0) == first
        );
    }

    function testEveryDeclaredRootInterpretationRemainsExact() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        bytes32 saved = _referenceHistory(hash);
        PolicyRoot.Binding memory original = router.scopedPolicyContentRootBinding(adoptedRoot);
        for (uint256 i; i < 4; ++i) {
            PolicyRoot.Binding memory bad = abi.decode(abi.encode(original), (PolicyRoot.Binding));
            if (i == 0) bad.profileId = 0;
            else if (i == 1) bad.factoryDependenciesHash ^= bytes32(uint256(1));
            else if (i == 2) bad.snapshotProfileHash ^= bytes32(uint256(1));
            else bad.outputRoot ^= bytes32(uint256(1));
            snapshotVm.mockCall(
                address(router),
                abi.encodeCall(PolicyRoot.scopedPolicyContentRootBinding, (adoptedRoot)),
                abi.encode(bad)
            );
            vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
            referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        }
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(PolicyRoot.scopedPolicyContentRootBinding, (adoptedRoot)),
            abi.encode(original)
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        require(_referenceHistory(hash) == saved);
    }

    function testSnapshotDeclaredOutputReceiptCannotBeReplacedByDifferentOriginalTuple() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        bytes32 saved = _referenceHistory(hash);
        Outputs.Manifest memory original =
            snapshotOutputs.manifestRecord(publication.outputManifestRecord);
        Outputs.Manifest memory changed = original;
        changed.artifactHash ^= bytes32(uint256(1));
        snapshotVm.mockCall(
            address(snapshotOutputs),
            abi.encodeCall(Outputs.manifestRecord, (publication.outputManifestRecord)),
            abi.encode(changed)
        );
        // Snapshot currentness reads requireCurrentManifest and still authenticates the actual tuple.
        // The separate exact original-record join in Reference catches this conflicting getter.
        require(
            snapshotHost.requireCurrent(publication.scope, adoptedSnapshot, 1).recordHash
                == adoptedSnapshot
        );
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        changed.artifactHash ^= bytes32(uint256(1));
        snapshotVm.mockCall(
            address(snapshotOutputs),
            abi.encodeCall(Outputs.manifestRecord, (publication.outputManifestRecord)),
            abi.encode(changed)
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        require(_referenceHistory(hash) == saved);
    }

    function testArchiveCurrentPairFailurePreservesOriginalAndNewNonzeroFixityCanRefresh() public {
        _reference(1, 1);
        bytes32 hash = _publishReference();
        bytes32 saved = _referenceHistory(hash);
        RefR.Capture memory capture = referenceInput.observation.captures[0];
        External.Coverage memory e =
            ExternalArchive(address(externalArchive)).coverage(capture.coverageHash);
        External.CurrentPair memory pair = External.CurrentPair(
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
            bytes32(0),
            e.secondFixityHash,
            e.checkpointHash,
            e.profileHash
        );
        bytes memory input = abi.encodeCall(
            IStreamExternalArtifactCurrentPair.currentReceiptPair,
            (e.firstReceiptHash, e.secondReceiptHash, e.artistId, e.objectHash)
        );
        snapshotVm.mockCall(address(externalArchive), input, abi.encode(pair));
        vm.expectRevert(abi.encodeWithSelector(RefR.InvalidReferenceRender.selector));
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(_referenceHistory(hash) == saved);
        pair.firstFixityHash = keccak256("new current nonzero fixity boundary");
        snapshotVm.mockCall(address(externalArchive), input, abi.encode(pair));
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        require(_referenceHistory(hash) == saved);
    }

    function testByteExactSamplesDoNotAcceptMetricLikeDriftOrWrongOrdinal() public {
        _reference(1, 2);
        _referenceBytes(address(this));
        require(!referenceHost.supportsInterface(type(MetricInterface).interfaceId));
        bytes32 repeat = referenceInput.observation.captures[0].repeatCaptureSha256[1];
        referenceInput.observation.captures[0].repeatCaptureSha256[1] ^= bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].repeatCaptureSha256[1] = repeat;
        uint256 token = referenceInput.observation.captures[0].tokenId;
        referenceInput.observation.captures[0].tokenId =
        referenceInput.observation.captures[1].tokenId;
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].tokenId = token;
        referenceInput.observation.captures[0].collectionSerial += 1;
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].collectionSerial -= 1;
        bytes32 hash = _publishReference();
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
    }

    function testCanonicalCaptureBytesAndEnvironmentCannotBeSubstituted() public {
        _reference(1, 2);
        _referenceBytes(address(this));
        bytes memory html = referenceInput.observation.captures[0].animationHTML;
        referenceInput.observation.captures[0].animationHTML = bytes.concat(html, hex"20");
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].animationHTML = html;
        bytes32 environment = referenceInput.observation.captures[1].environmentManifestHash;
        referenceInput.observation.captures[1].environmentManifestHash ^= bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[1].environmentManifestHash = environment;
        bytes32 hash = _publishReference();
        require(referenceHost.referenceSource(hash).environmentCoverage.artistId == SNAPSHOT_ARTIST);
    }

    function testLiveFullHtmlDriftRejectsButRetainedPayloadRemainsReadable() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        bytes32 saved = _referenceHistory(hash);
        uint256 token = referenceInput.observation.captures[0].tokenId;
        bytes memory original = bytes(router.tokenHTML(token));
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenHTML(uint256)", token),
            abi.encode("changed full HTML")
        );
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(_referenceHistory(hash) == saved);
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenHTML(uint256)", token),
            abi.encode(original)
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
    }

    function testReferenceAuthorityIsCuratorWithOriginalCollectionPrecedence() public {
        _reference(1, 1);
        address recorder = address(0xA117);
        _familyGrant(1, Families.SNAPSHOT, 7, recorder, true);
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceAuthority.selector, recorder)
        );
        referenceHost.previewReference(referenceInput, recorder);
        _familyGrant(0, Families.CURATOR, 8, recorder, true);
        _familyGrant(1, Families.CURATOR, 3, recorder, true);
        _upload(_referenceBytes(recorder), false);
        vm.prank(recorder);
        bytes32 hash = referenceHost.publishReference(referenceInput);
        RefT.Receipt memory r = referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(
            r.observation.recorder == recorder && r.observation.authorizationClass == 3
                && r.observation.grantRevision == 1
        );
        _familyGrant(1, Families.CURATOR, 3, recorder, false);
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        referenceInput.observation.referenceId = keccak256("global curator successor");
        referenceInput.observation.expectedHead = hash;
        referenceInput.observation.expectedRevision = 1;
        _upload(_referenceBytes(recorder), false);
        vm.prank(recorder);
        bytes32 second = referenceHost.publishReference(referenceInput);
        require(
            referenceHost.requireCurrent(referenceInput.scope, second, 2).observation
                .authorizationClass == 8
        );
    }

    function testClassTwoLockHasExactPreimageCurrentnessEventAndNoReplay() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            referenceHost.lockTransition(referenceInput.scope);
        RefT.Receipt memory r = referenceHost.currentReference(referenceInput.scope);
        require(
            scope
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_LOCK_SCOPE_V2"),
                        block.chainid,
                        address(referenceHost),
                        address(core),
                        referenceInput.scope,
                        r.scopeSubject
                    )
                )
        );
        require(
            oldHash == keccak256(abi.encode(scope, hash, uint64(1), false))
                && newHash == keccak256(abi.encode(scope, hash, uint64(1), true))
        );
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceAuthority.selector, address(this))
        );
        referenceHost.lockReference(referenceInput.scope);
        _referenceAction(1, scope, oldHash, newHash);
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceAuthority.selector, address(executor))
        );
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        _referenceAction(2, scope, oldHash, newHash ^ bytes32(uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceAuthority.selector, address(executor))
        );
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        require(referenceHost.referenceLock(referenceInput.scope).actionId == 0);
        _referenceAction(2, scope, oldHash, newHash);
        vm.recordLogs();
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (uint16 version, RefR.Lock memory l) = abi.decode(logs[0].data, (uint16, RefR.Lock));
        require(logs.length == 1 && version == 2 && l.recordHash == hash && l.revision == 1);
        require(logs[0].emitter == address(referenceHost) && logs[0].topics[1] == r.scopeSubject);
        require(
            l.actionId == keccak256("exact scoped policy reference lock")
                && keccak256(abi.encode(l))
                    == keccak256(abi.encode(referenceHost.referenceLock(referenceInput.scope)))
        );
        ScopedPolicyReferenceReaderProbeV2 probe = new ScopedPolicyReferenceReaderProbeV2();
        StreamFinalityComponentState memory c =
            probe.component(_referenceReader(), referenceInput.scope, hash, 1);
        require(
            c.frozen
                && c.dataHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_LOCKED_SCOPED_POLICY_REFERENCE_COMPONENT_V2"),
                            block.chainid,
                            address(referenceHost),
                            address(core),
                            referenceInput.scope,
                            r,
                            l
                        )
                    )
        );
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceLocked.selector, r.scopeSubject)
        );
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        referenceInput.observation.referenceId = keccak256("forbidden locked successor");
        referenceInput.observation.expectedHead = hash;
        referenceInput.observation.expectedRevision = 1;
        vm.expectRevert(
            abi.encodeWithSelector(RefT.ScopedPolicyReferenceLocked.selector, r.scopeSubject)
        );
        referenceHost.previewReference(referenceInput, address(this));
    }

    function testOfficialSafeLateMissingChunkRollsBackAndRetriesIdenticalEnvelope() public {
        _reference(1, 3);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x819131;
        keys[1] = 0x819132;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1912);
        _familyGrant(1, Families.CURATOR, 3, address(account), true);
        bytes memory raw = _referenceBytes(address(account));
        _upload(raw, true);
        bytes32 missing = keccak256(_chunk(raw, (raw.length - 1) / 8192));
        (address pointer,) = snapshotStore.chunk(missing);
        require(pointer == address(0), "genuinely absent final payload chunk");
        bytes32 rootSaved = keccak256(
            abi.encode(
                router.scopedContentRootRecord(adoptedRoot),
                router.scopedPolicyContentRootBinding(adoptedRoot)
            )
        );
        bytes32 snapshotSaved = _historyHash(adoptedSnapshot);
        bytes memory input = abi.encodeCall(referenceHost.publishReference, (referenceInput));
        vm.expectRevert(
            abi.encodeWithSelector(StoredBytes.SnapshotChunkUnavailable.selector, missing)
        );
        vm.prank(address(account));
        referenceHost.publishReference(referenceInput);
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(referenceHost), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        bytes32 envelope = keccak256(abi.encode(input, signatures, nonce));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(referenceHost),
            0,
            input,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signatures
        );
        require(
            account.nonce() == nonce && referenceHost.referenceCount(referenceInput.scope) == 0
                && referenceHost.currentReference(referenceInput.scope).observation.recordHash == 0
        );
        require(
            _historyHash(adoptedSnapshot) == snapshotSaved
                && keccak256(
                    abi.encode(
                        router.scopedContentRootRecord(adoptedRoot),
                        router.scopedPolicyContentRootBinding(adoptedRoot)
                    )
                ) == rootSaved
        );
        _upload(raw, false);
        require(keccak256(abi.encode(input, signatures, nonce)) == envelope);
        require(
            account.execTransaction(
                address(referenceHost),
                0,
                input,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
        RefT.Receipt memory r = referenceHost.currentReference(referenceInput.scope);
        require(account.nonce() == nonce + 1 && r.observation.recorder == address(account));
        require(
            keccak256(referenceHost.referencePayload(r.observation.recordHash)) == keccak256(raw)
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, r.observation.recordHash, 1)
                .observation.recordHash == r.observation.recordHash
        );
    }

    function testDistinctProfileAndDefinitionsCannotBorrowOriginalScopedOrMetricReader() public {
        _reference(1, 1);
        bytes32 hash = _publishReference();
        require(
            referenceHost.supportsInterface(type(RefInterface).interfaceId)
                && !referenceHost.supportsInterface(type(RefV1).interfaceId)
        );
        require(!referenceHost.supportsInterface(type(MetricInterface).interfaceId));
        require(
            referenceHost.scopedPolicyReferenceProfile()
                == keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_V2")
        );
        ScopedPolicyReferenceReaderProbeV2 probe = new ScopedPolicyReferenceReaderProbeV2();
        RefReads.Dependencies memory d = _referenceReader();
        probe.original(d, referenceInput.scope, hash, 1);
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeCall(RefInterface.scopedPolicyReferenceProfile, ()),
            abi.encode(keccak256("old profile"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(RefReads.InvalidScopedPolicyReferenceEvidence.selector)
        );
        probe.original(d, referenceInput.scope, hash, 1);
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeCall(RefInterface.scopedPolicyReferenceProfile, ()),
            abi.encode(keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_V2"))
        );
        require(probe.current(d, referenceInput.scope, hash, 1).observation.recordHash == hash);
    }
}
