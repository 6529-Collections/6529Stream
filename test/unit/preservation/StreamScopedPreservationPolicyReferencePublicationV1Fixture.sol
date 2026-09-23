// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as CapacityReferenceGraph454
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamScopedPreservationPolicyPublicationReferenceDeploymentV2 as CapacityReferenceDeploy454
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyPublicationReferenceDeploymentV2.sol";
import {
    LeafManifestVm as CapacityReferenceCreateVm454
} from "../../helpers/scoped-preservation-boundaries/StreamContentLeafManifestVm.sol";
import {
    IStreamGasParameterHost as CapacityReferenceGas454
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamScopedPreservationPolicyReferencePublicationV2 as CapacityReferenceV2
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferencePublicationV2.sol";

import {
    PreservationSnapshotRootProviderBoundary,
    ScopedPreservationReferenceExternalBoundary
} from "../../helpers/scoped-preservation-boundaries/StreamScopedPreservationPolicyReferencePublicationV1Boundaries.sol";

import { StaticRouteVm } from "../../helpers/StaticMetadataRoutingFixture.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { LeafManifestVm } from "../finality/StreamContentLeafManifest.t.sol";
import {
    LeafManifestArchiveBoundary,
    LeafManifestFinalityBoundary
} from "../../helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol";
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
        externalArchive = ScopedPreservationReferenceExternalBoundary(
            _artistArtifactCreate(
                "test/helpers/scoped-preservation-boundaries/StreamScopedPreservationPolicyReferencePublicationV1Boundaries.sol:ScopedPreservationReferenceExternalBoundary",
                abi.encode(address(core))
            )
        );
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
        referenceHost = Ref(
            _artistArtifactCreate(
                "smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferencePublicationV1.sol:StreamScopedPreservationPolicyReferencePublicationV1",
                abi.encode(d, address(executor), _referenceGas())
            )
        );
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
        PreservationSnapshotRootProviderBoundary provider = PreservationSnapshotRootProviderBoundary(
            _artistArtifactCreate(
                "test/helpers/scoped-preservation-boundaries/StreamScopedPreservationPolicyReferencePublicationV1Boundaries.sol:PreservationSnapshotRootProviderBoundary",
                abi.encode(address(snapshotHost), publication.scope)
            )
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
