// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StaticRouteVm } from "../../helpers/StaticMetadataRoutingFixture.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    LeafManifestArchiveBoundary,
    LeafManifestFinalityBoundary,
    LeafManifestVm
} from "../finality/StreamContentLeafManifest.t.sol";
import {
    StreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../../smart-contracts/domains/metadata/StreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as SnapshotInterface
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamScopedSnapshotPublication as OriginalScopedSnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedSnapshotPublication.sol";
import {
    IStreamPolicySnapshotPublicationV2 as CollectionPolicySnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPreservationPolicyContentCheckpointV1 as ContentHost
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamPreservationPolicyOutputManifestV1 as OutputHost
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputDocuments
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV1.sol";
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
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as SnapshotDocuments
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";
import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as SnapshotReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
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
    IStreamScopedPreservationPolicyContentRootEvidenceBindingV1 as RootProvider
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyContentRootEvidenceBindingV1.sol";
import {
    IStreamScopedContentRootPublication as ScopedRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PolicyRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as RootDocuments
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentRootSchemasV1.sol";

import {
    StreamScopedPreservationPolicyReferencePublicationV1 as Ref
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as RefT
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as RefR
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    IStreamScopedPreservationPolicyReferencePublicationV1 as RefInterface
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    IStreamScopedReferencePublication as RefV1
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedReferencePublication.sol";
import {
    IStreamReferenceModePublication as MetricInterface
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamReferenceModePublication.sol";
import {
    StreamScopedPreservationPolicyReferenceDefinitionsV1 as RefDocuments
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicyReferenceDefinitionsV1.sol";
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

import {
    ScopedPreservationSnapshotFixtureV1
} from "../metadata/StreamScopedPreservationPolicySnapshotPublicationV1.t.sol";
import {
    IStreamScopedPolicyReferencePublicationV2 as OldRefInterface
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import {
    StreamScopedPreservationPolicyReferenceSampleReadsV1 as Samples
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferenceSampleReadsV1.sol";
import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";

import {
    StreamFinalityScopedPreservationPolicyReferenceReadsV1 as ReferenceReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyReferenceReadsV1.sol";
import {
    StreamScopedPreservationPolicyReferenceInventoryReadsV1 as ReferenceInventory
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferenceInventoryReadsV1.sol";
import {
    StreamRenderCriticalSourceTypes as InventorySources
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

contract PreservationSnapshotRootProviderBoundary is RootProvider {
    address public immutable metadataHost;
    address private immutable snapshots;
    bytes32 private immutable snapshotRuntime;
    bytes32 private immutable selectedScope;

    constructor(address host, StreamFinalityScope memory scope) {
        snapshots = host;
        snapshotRuntime = host.codehash;
        metadataHost = SnapshotInterface(host).metadataHost();
        selectedScope = keccak256(abi.encode(scope));
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(RootProvider).interfaceId;
    }

    function scopedPreservationPolicySnapshotProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1");
    }

    function scopedPreservationPolicySnapshotHost(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (address)
    {
        require(keccak256(abi.encode(scope)) == selectedScope);
        return snapshots;
    }

    function scopedPreservationPolicySnapshotCodeHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        require(keccak256(abi.encode(scope)) == selectedScope);
        return snapshotRuntime;
    }

    function scopedPreservationPolicySnapshotValidationGas(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        require(keccak256(abi.encode(scope)) == selectedScope);
        return 128000000;
    }
}

/// @dev Explicit external ZIP/PNG identity, archival pair and repeated-capture observation boundary.
contract ScopedPreservationReferenceExternalBoundary {
    address public immutable core;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamExternalArtifactCurrentPair).interfaceId;
    }
}

contract PreservationReferenceSampleProbe {
    function sample(
        RefT.Dependencies calldata d,
        Snap.Dependencies calldata source,
        StreamFinalityScope calldata scope,
        Snap.Source calldata facts,
        uint64 index,
        RefR.Capture calldata capture
    ) external view returns (RefT.Sample memory) {
        return Samples.requireSample(d, source, scope, facts, index, capture, true);
    }
}

/// @notice Actual preservation checkpoint/output/snapshot, original Router root writer and new reference host.
/// @dev Inherited producer/Registry/Artist/governance boundaries remain explicit; PNG/ZIP receipts,
/// browser environment and repeat-capture hashes are typed observations, not freshly executed browsers.
/// No ADR0054 producer projection, current-stack ceremony or native runtime acceptance is claimed.
abstract contract ScopedPreservationReferenceFixtureV1 is ScopedPreservationSnapshotFixtureV1 {
    Ref internal referenceHost;
    RefT.Publication internal referenceInput;
    ScopedPreservationReferenceExternalBoundary internal externalArchive;
    bytes32 internal adoptedRoot;
    bytes32 internal adoptedSnapshot;

    function _reference(uint8 terminalStatus, uint8 scopeKind) internal {
        _initialize(terminalStatus);
        _prepare(scopeKind);
        _configureJoinedRootBoundary();
        adoptedSnapshot = _publish();
        adoptedRoot = _adopt(adoptedSnapshot, 1);
        externalArchive = new ScopedPreservationReferenceExternalBoundary(address(core));
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
            bytes memory html = bytes(
                snapshotCapture.producers[i == 0 ? 0 : count - 1].preservationTokenHTML(token)
            );
            RefR.Capture memory c;
            c.tokenId = token;
            c.collectionSerial = serial;
            c.metadataJSONHash = keccak256(
                bytes(
                    snapshotCapture.producers[i == 0 ? 0 : count - 1].preservationTokenJSON(token)
                )
            );
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
        bytes32 next = PolicyRoot(address(router))
            .previewScopedPreservationPolicyContentRootPublication(p, address(this));
        artist.approve(
            1,
            keccak256("CONTENT_ROOT"),
            next,
            keccak256(abi.encode("explicit original Artist op17", next))
        );
        return PolicyRoot(address(router)).publishScopedPreservationPolicyContentRootPublication(p);
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
            domain == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V1")
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

    function _readerDependencies() internal view returns (ReferenceReads.Dependencies memory d) {
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
        // Nested fixture proof budget; no native transaction-size or gas acceptance claim.
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
            "STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V1",
            "STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PROFILE_V1",
            "STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V1"
        ];
        string[3] memory files = [
            "scoped-preservation-policy-reference-v1.schema.json",
            "scoped-preservation-policy-reference-v1.profile.json",
            "scoped-preservation-policy-reference-v1.abi.json"
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
            "STREAM_PRESERVATION_POLICY_TOKEN_CONTENT_LEAF_V1",
            Schema.DocumentKind.SCHEMA,
            OutputDocuments.document(OutputDocuments.LEAF_SCHEMA)
        );
        _register(
            "STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1",
            Schema.DocumentKind.SCHEMA,
            RootDocuments.document(RootDocuments.ROOT_SCHEMA)
        );
        _register(
            "STREAM_ABI_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1",
            Schema.DocumentKind.CANONICALIZATION,
            RootDocuments.document(RootDocuments.ROOT_CANON)
        );
        PreservationSnapshotRootProviderBoundary provider = new PreservationSnapshotRootProviderBoundary(
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
}

contract StreamScopedPreservationPolicyReferencePublicationV1Test is
    ScopedPreservationReferenceFixtureV1
{
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
        require(version == 1 && logs[0].topics.length == 4);
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
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_CHAIN_V1"),
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
            abi.encode(f.contentRootBinding).length == 800
                && f.contentRootBinding.metadataRouter == address(router)
                && f.contentRootBinding.preservationOutputProfile
                    == keccak256("6529STREAM_PRESERVATION_RENDER_V1")
        );
        for (uint256 i; i < f.samples.length; ++i) {
            require(abi.encode(f.samples[i]).length == 2560);
            Content.Output memory row = snapshotContent.outputAt(snapshotCapture.id, i);
            require(
                keccak256(abi.encode(f.samples[i].preservation, f.samples[i].preservationAdmission))
                    == keccak256(abi.encode(row.preservation, row.preservationAdmission))
            );
        }
        require(
            f.samples[0].preservation.producer != f.samples[1].preservation.producer
                && f.samples[0].preservation.liveRenderer != f.samples[1].preservation.liveRenderer
        );
        require(
            keccak256(abi.encode(f.contentRoot))
                == keccak256(abi.encode(router.scopedContentRootRecord(adoptedRoot)))
        );
        require(
            keccak256(abi.encode(f.contentRootBinding))
                == keccak256(
                    abi.encode(
                        PolicyRoot(address(router))
                            .scopedPreservationPolicyContentRootBinding(adoptedRoot)
                    )
                )
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
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V1"),
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
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_RECORD_V1"),
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

    function testEveryDeclaredRootInterpretationRemainsExact() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        bytes32 saved = _referenceHistory(hash);
        PolicyRoot.Binding memory original =
            PolicyRoot(address(router)).scopedPreservationPolicyContentRootBinding(adoptedRoot);
        for (uint256 i; i < 6; ++i) {
            PolicyRoot.Binding memory bad = abi.decode(abi.encode(original), (PolicyRoot.Binding));
            if (i == 0) bad.profileId = 0;
            else if (i == 1) bad.factoryDependenciesHash ^= bytes32(uint256(1));
            else if (i == 2) bad.snapshotProfileHash ^= bytes32(uint256(1));
            else if (i == 3) bad.outputRoot ^= bytes32(uint256(1));
            else if (i == 4) bad.metadataRouter = address(snapshotContent);
            else bad.preservationOutputProfile = keccak256("wrong projection");
            snapshotVm.mockCall(
                address(router),
                abi.encodeCall(
                    PolicyRoot.scopedPreservationPolicyContentRootBinding, (adoptedRoot)
                ),
                abi.encode(bad)
            );
            vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
            referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        }
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(PolicyRoot.scopedPreservationPolicyContentRootBinding, (adoptedRoot)),
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
                PolicyRoot(address(router)).scopedPreservationPolicyContentRootBinding(adoptedRoot)
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
                        PolicyRoot(address(router))
                            .scopedPreservationPolicyContentRootBinding(adoptedRoot)
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
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_LOCK_SCOPE_V1"),
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
        require(logs.length == 1 && version == 1 && l.recordHash == hash && l.revision == 1);
        require(logs[0].emitter == address(referenceHost) && logs[0].topics[1] == r.scopeSubject);
        require(
            l.actionId == keccak256("exact scoped policy reference lock")
                && keccak256(abi.encode(l))
                    == keccak256(abi.encode(referenceHost.referenceLock(referenceInput.scope)))
        );
        StreamFinalityComponentState memory c =
            referenceHost.finalityStateForScope(referenceInput.scope);
        require(
            c.frozen
                && c.dataHash
                    == keccak256(
                        abi.encode(
                            keccak256(
                                "6529STREAM_LOCKED_SCOPED_PRESERVATION_POLICY_REFERENCE_COMPONENT_V1"
                            ),
                            block.chainid,
                            address(referenceHost),
                            address(core),
                            referenceInput.scope,
                            r,
                            l
                        )
                    )
        );
        StreamFinalityComponentState memory typedState =
            ReferenceReads.component(_readerDependencies(), referenceInput.scope, hash, 1);
        require(keccak256(abi.encode(typedState)) == keccak256(abi.encode(c)));
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

    function testTokenTupleProfileAndDefinitionsDoNotBorrowOldRecords() public {
        _reference(1, 1);
        bytes32 hash = _publishReference();
        require(
            referenceHost.supportsInterface(type(RefInterface).interfaceId)
                && !referenceHost.supportsInterface(type(OldRefInterface).interfaceId)
                && !referenceHost.supportsInterface(type(RefV1).interfaceId)
                && !referenceHost.supportsInterface(type(MetricInterface).interfaceId)
        );
        require(
            referenceHost.scopedPreservationPolicyReferenceProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V1")
        );
        StreamFinalityScope memory wrong = referenceInput.scope;
        wrong.collectionId = 2;
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.currentReference(wrong);
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.requireCurrent(wrong, hash, 1);
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.lockTransition(wrong);
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.referenceAt(wrong, 0);
        (RefT.Publication memory p, RefT.Receipt memory r) = referenceHost.referenceRecord(hash);
        require(r.observation.recordHash == hash && p.scope.collectionId == 1);
    }

    function testActualRootSuccessorStalesCurrentButPreservesOriginalReference() public {
        _reference(1, 2);
        bytes32 first = _publishReference();
        bytes32 original = _referenceHistory(first);
        bytes32 prior = adoptedRoot;
        adoptedRoot = _adopt(adoptedSnapshot, 1);
        require(
            adoptedRoot != prior
                && router.scopedContentRootRecord(adoptedRoot).publication.expectedPredecessor
                    == prior
        );
        vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
        referenceHost.requireCurrent(referenceInput.scope, first, 1);
        require(_referenceHistory(first) == original);
        referenceInput.observation.referenceId = keccak256("reference following new root");
        referenceInput.observation.expectedHead = first;
        referenceInput.observation.expectedRevision = 1;
        bytes32 second = _publishReference();
        require(
            referenceHost.requireCurrent(referenceInput.scope, second, 2).observation.predecessor
                == first
        );
        require(
            referenceHost.referenceSource(second).contentRootRecordHash == adoptedRoot
                && _referenceHistory(first) == original
        );
    }

    function testPreservationBytesStaySeparateFromLiveRouterAndProducerDriftStalesCurrent() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        bytes32 original = _referenceHistory(hash);
        uint256 token = referenceInput.observation.captures[0].tokenId;
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenJSON(uint256)", token),
            abi.encode("independent changed live JSON")
        );
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenHTML(uint256)", token),
            abi.encode("independent changed live HTML")
        );
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        string memory json = snapshotCapture.producers[0].preservationTokenJSON(token);
        string memory html = snapshotCapture.producers[0].preservationTokenHTML(token);
        snapshotCapture.producers[0].setBytes(token, string.concat(json, " "), html);
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(_referenceHistory(hash) == original);
        snapshotCapture.producers[0].setBytes(token, json, html);
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
    }

    function testSampleIndependentlyRejoinsEverySavedAdmissionWord() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        RefT.SourceFacts memory facts = referenceHost.referenceSource(hash);
        PreservationReferenceSampleProbe probe = new PreservationReferenceSampleProbe();
        RefT.Dependencies memory d = referenceHost.dependencies();
        Snap.Dependencies memory source = snapshotHost.dependencies();
        Content.Output memory original = snapshotContent.outputAt(snapshotCapture.id, 1);
        bytes memory input = abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1)));
        for (uint256 i; i < 7; ++i) {
            bytes memory encoded = abi.encode(original.preservationAdmission);
            encoded[i * 32 + 31] ^= 0x01;
            Content.Output memory bad = abi.decode(abi.encode(original), (Content.Output));
            bad.preservationAdmission = abi.decode(encoded, (P.Admission));
            snapshotVm.mockCall(address(snapshotContent), input, abi.encode(bad));
            vm.expectRevert(abi.encodeWithSelector(RefT.InvalidScopedPolicyReference.selector));
            probe.sample(
                d,
                source,
                referenceInput.scope,
                facts.snapshotSource,
                1,
                referenceInput.observation.captures[1]
            );
        }
        snapshotVm.mockCall(address(snapshotContent), input, abi.encode(original));
        RefT.Sample memory sample = probe.sample(
            d,
            source,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1]
        );
        require(
            keccak256(abi.encode(sample.preservationAdmission))
                == keccak256(abi.encode(original.preservationAdmission))
        );
    }

    function testSampleRejectsOtherMembersProducerAndMalformedAdmissionReturn() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        RefT.SourceFacts memory facts = referenceHost.referenceSource(hash);
        PreservationReferenceSampleProbe probe = new PreservationReferenceSampleProbe();
        RefT.Dependencies memory d = referenceHost.dependencies();
        Snap.Dependencies memory source = snapshotHost.dependencies();
        Content.Output memory original = snapshotContent.outputAt(snapshotCapture.id, 1);
        Content.Output memory bad = abi.decode(abi.encode(original), (Content.Output));
        bad.preservation = snapshotContent.outputAt(snapshotCapture.id, 0).preservation;
        bytes memory input = abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1)));
        snapshotVm.mockCall(address(snapshotContent), input, abi.encode(bad));
        vm.expectRevert(abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        probe.sample(
            d,
            source,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1]
        );
        snapshotVm.mockCall(address(snapshotContent), input, abi.encode(original));
        Capture memory c = snapshotCapture;
        _setAdmission(c, 1, new bytes(480));
        vm.expectRevert();
        probe.sample(
            d,
            source,
            referenceInput.scope,
            facts.snapshotSource,
            1,
            referenceInput.observation.captures[1]
        );
        _setAdmission(c, 1, abi.encode(_binding(c, 1), _admission(c, 1)));
        require(
            probe.sample(
                    d,
                    source,
                    referenceInput.scope,
                    facts.snapshotSource,
                    1,
                    referenceInput.observation.captures[1]
                ).observation.tokenId == 92
        );
    }

    function testTypedReferenceReaderPreservesOriginalAfterRootDriftAndRejectsWrongCapability()
        public
    {
        _reference(1, 1);
        bytes32 hash = _publishReference();
        ReferenceReads.Dependencies memory d = _readerDependencies();
        (RefT.Publication memory p, RefT.Receipt memory saved) =
            ReferenceReads.original(d, referenceInput.scope, hash, 1);
        require(keccak256(abi.encode(p)) == keccak256(abi.encode(referenceInput)));
        require(
            ReferenceReads.requireCurrent(d, referenceInput.scope, hash, 1).observation.recordHash
                == hash
        );
        StreamFinalityScope memory wrong = referenceInput.scope;
        wrong.collectionId = 2;
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceReads.InvalidScopedPreservationPolicyReferenceEvidence.selector
            )
        );
        ReferenceReads.original(d, wrong, hash, 1);
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSignature("supportsInterface(bytes4)", type(RefInterface).interfaceId),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceReads.InvalidScopedPreservationPolicyReferenceEvidence.selector
            )
        );
        ReferenceReads.original(d, referenceInput.scope, hash, 1);
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeWithSignature("supportsInterface(bytes4)", type(RefInterface).interfaceId),
            abi.encode(true)
        );
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeCall(RefInterface.scopedPreservationPolicyReferenceProfile, ()),
            abi.encode(keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_V2"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                ReferenceReads.InvalidScopedPreservationPolicyReferenceEvidence.selector
            )
        );
        ReferenceReads.original(d, referenceInput.scope, hash, 1);
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeCall(RefInterface.scopedPreservationPolicyReferenceProfile, ()),
            abi.encode(keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V1"))
        );
        _adopt(adoptedSnapshot, 1);
        (, RefT.Receipt memory historical) =
            ReferenceReads.original(d, referenceInput.scope, hash, 1);
        require(keccak256(abi.encode(historical)) == keccak256(abi.encode(saved)));
        vm.expectRevert(
            abi.encodeWithSignature(
                "RouterEvidenceRead(address,bytes4)",
                address(referenceHost),
                RefInterface.requireCurrent.selector
            )
        );
        ReferenceReads.requireCurrent(d, referenceInput.scope, hash, 1);
    }

    function testReferenceInventoryTraversesEveryOriginalMemberAndCaptureInExactOrder() public {
        _reference(1, 2);
        bytes32 hash = _publishReference();
        RefT.SourceFacts memory f = referenceHost.referenceSource(hash);
        ReferenceInventory.Context memory c = ReferenceInventory.Context(
            referenceInput.scope,
            f.scopeSubject,
            SNAPSHOT_ARTIST,
            f.snapshot,
            referenceHost.currentReference(referenceInput.scope)
        );
        InventorySources.Dependencies memory d;
        d.targets[6] = address(referenceHost);
        d.targets[11] = address(externalArchive);
        d.readGas = 2000000;
        d.sourceGas = 8000000;
        (Inventory.Item[] memory rows, uint64 total) = ReferenceInventory.items(d, c, 0, 64);
        require(total == 10 && rows.length == total);
        require(
            rows[0].role == keccak256("SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST")
                && rows[0].schemaId == RefDocuments.SCHEMA_ID
        );
        require(rows[1].role == keccak256("REFERENCE_ENVIRONMENT_DECLARATION"));
        require(rows[2].role == keccak256("RUNNABLE_ENGINE_TOOLCHAIN_ZIP"));
        require(
            rows[3].role == keccak256("RUNNABLE_PACKAGE_MEMBER")
                && rows[4].role == keccak256("RUNNABLE_PACKAGE_MEMBER")
        );
        require(rows[5].role == keccak256("NATIVE_OS_PREREQUISITE"));
        for (uint64 i; i < total; ++i) {
            (Inventory.Item[] memory page, uint64 count) = ReferenceInventory.items(d, c, i, 1);
            require(
                count == total && page.length == 1
                    && keccak256(abi.encode(page[0])) == keccak256(abi.encode(rows[i]))
            );
            if (i >= 6) {
                require(
                    rows[i].role
                        == (i % 2 == 0
                                ? keccak256("REFERENCE_CAPTURE")
                                : keccak256("REFERENCE_CAPTURE_DECLARATION"))
                );
            }
        }
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventorySegment.selector));
        ReferenceInventory.items(d, c, total, 1);
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventorySegment.selector));
        ReferenceInventory.items(d, c, 0, 65);
        c.scope.collectionId = 2;
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventorySourceChanged.selector));
        ReferenceInventory.items(d, c, 0, 1);
    }
}
