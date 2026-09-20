// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ViewReferenceSnapshotFixtureV1.sol";
import {
    StreamViewPreservationReferencePublicationV1 as ReferenceHost
} from "../../smart-contracts/domains/preservation/StreamViewPreservationReferencePublicationV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as Ref
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as RR
} from "../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamFinalityViewPreservationReferenceReadsV1 as ReferenceReader
} from "../../smart-contracts/domains/finality/StreamFinalityViewPreservationReferenceReadsV1.sol";
import {
    StreamViewPreservationReferenceDefinitionsV1 as RefDefs
} from "../../smart-contracts/domains/records/StreamViewPreservationReferenceDefinitionsV1.sol";
import {
    StreamReferenceRenderDefinitions as OriginalDefinitions
} from "../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    StreamReferenceEnvironmentJson as EnvironmentJSON
} from "../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import {
    StreamExternalArtifactTypes as EA
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamExternalArtifactCoverage as Archive
} from "../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    IStreamExternalArtifactCurrentPair as Pair
} from "../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamViewPreservationContentRootV1 as RootBinding
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationContentRootV1.sol";
import {
    StreamViewPreservationContentDefinitionsV1 as RootDefs
} from "../../smart-contracts/domains/records/StreamViewPreservationContentDefinitionsV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as OutputDefs
} from "../../smart-contracts/domains/finality/StreamViewPreservationOutputSchemasV1.sol";
import {
    StreamViewPolicyTypesV2 as ViewPolicy
} from "../../smart-contracts/domains/metadata/StreamViewPolicyTypesV2.sol";

contract ViewReferenceFinalityProbe {
    function current(
        ReferenceReader.Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (Ref.Receipt memory) {
        return ReferenceReader.requireCurrent(d, scope, hash, revision);
    }

    function component(
        ReferenceReader.Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (StreamFinalityComponentState memory) {
        return ReferenceReader.component(d, scope, hash, revision);
    }
}

/// @dev Actual Snapshot, current snapshot reader, State/Store/checkpoint/Renderer and reference
/// host. Router root/op17, Metadata grants, Schema facts, manifest/Archive and governance are
/// explicit typed boundaries. The root boundary returns an independently constructed full state
/// preimage; this fixture is not an actual Artist consent or finality acceptance ceremony.
abstract contract ViewPreservationReferenceFixtureV1 is ViewReferenceSnapshotFixtureV1 {
    ReferenceHost internal referenceHost;
    ViewReferenceFinalityProbe internal finalityReader;
    PolicyViewWire internal externalArchive;
    Ref.Publication internal referenceInput;
    Ref.Dependencies internal referenceDependencies;
    Root.Record internal rootRecord;
    RootBinding.Binding internal rootBinding;
    bytes32 internal rootHash;
    bytes32 internal snapshotHash;

    function _referenceInit() internal {
        _init();
        _prepare();
        snapshotHash = snapshots.publishSnapshot(publication);
        Reader.Evidence memory evidence = reader.current(_reader(), scope, snapshotHash, 1);
        SS.Source memory f = evidence.source;
        rootRecord.publication =
            Root.Publication(scope, 0, snapshotHash, 1, "ipfs://original-view-root");
        rootRecord.snapshotHost = address(snapshots);
        rootRecord.snapshotCodeHash = address(snapshots).codehash;
        rootRecord.snapshotManifestHash = evidence.receipt.manifestHash;
        rootRecord.snapshotSourceHash = evidence.receipt.sourceHash;
        rootRecord.contentRoot = f.outputs.header.contentRoot;
        require(f.membership.tokenCount <= type(uint64).max, "fixture count bound");
        rootRecord.leafCount = uint64(f.membership.tokenCount);
        rootRecord.outputManifestHash = f.outputs.carrier.contentHash;
        rootRecord.artistId = f.artist.artistId;
        rootRecord.bindingGeneration = f.artist.bindingGeneration;
        rootRecord.bindingHash = f.artist.bindingHash;
        rootRecord.publisher = address(this);
        rootRecord.authorizationClass = 7;
        rootRecord.grantRevision = 7;
        rootRecord.routeHash = keccak256("typed original op17 route");
        CT.Configuration memory c = checkpointHost.configuration();
        rootBinding = RootBinding.Binding(
            RootDefs.PROFILE,
            CT.OUTPUT_PROFILE,
            adopted,
            ViewPolicy.PROFILE,
            f.membership.membershipHash,
            f.entropy.policyChainHash,
            address(checkpointHost),
            address(checkpointHost).codehash,
            f.outputs.header.checkpointId,
            f.outputs.header.checkpointStateHash,
            address(manifests),
            address(manifests).codehash,
            f.outputs.recordHash,
            f.outputs.carrier.contentHash,
            f.outputs.partChain,
            c.serving,
            c.servingCodeHash,
            c.servingConfigurationHash,
            f.adoption.preservation.liveRenderer,
            f.adoption.preservation.liveRendererRuntimeHash,
            f.adoption.preservation.preservationAttribution,
            f.adoption.preservation.preservationAttributionRuntimeHash,
            keccak256(OutputDefs.document(OutputDefs.LEAF)),
            RootDefs.SCHEMA_HASH,
            RootDefs.CANON_HASH,
            SD.SCHEMA_HASH,
            SD.PROFILE_HASH,
            SD.CANON_HASH
        );
        rootRecord.stateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_ROOT_STATE_V1"),
                savedChain,
                address(records),
                address(core),
                rootRecord,
                rootBinding
            )
        );
        rootRecord.artistConsent = keccak256("typed original consumed Artist op17");
        rootRecord.publishedAt = uint64(block.timestamp);
        Root.Aggregate memory aggregate = Root.Aggregate(1, keccak256("typed original aggregate"));
        rootHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"),
                savedChain,
                address(records),
                address(core),
                rootRecord,
                aggregate
            )
        );
        _rootReplies();
        externalArchive = new PolicyViewWire();
        _answer(externalArchive, "core()", "", abi.encode(address(core)));
        _answer(
            externalArchive,
            "supportsInterface(bytes4)",
            abi.encode(type(Pair).interfaceId),
            abi.encode(true)
        );
        referenceInput.scope = scope;
        referenceInput.observation.collectionId = 1;
        referenceInput.observation.referenceId = keccak256("VIEW preservation reference one");
        referenceInput.observation.snapshotRecordHash = snapshotHash;
        referenceInput.observation.snapshotRevision = 1;
        referenceInput.observation.effectiveAt = uint64(block.timestamp);
        referenceInput.observation.reasonHash = keccak256("reference capture reason");
        referenceInput.observation.manifestURI = "ipfs://view-reference";
        _environment();
        (, string memory html) = serving.preservationViewHTML(scope, 11);
        CT.Output memory output = checkpointHost.outputAt(f.outputs.header.checkpointId, 0);
        RR.Capture memory capture;
        capture.tokenId = 11;
        capture.collectionSerial = 7;
        capture.metadataJSONHash = output.jsonHash;
        capture.htmlHash = output.htmlHash;
        capture.htmlBytes = output.htmlBytes;
        capture.animationHTML = bytes(html);
        capture.objectHash = keccak256("reference PNG object");
        capture.coverageHash = keccak256("reference PNG coverage");
        capture.sourceSha256 = sha256(bytes(html));
        capture.repeatCaptureSha256 = [keccak256("PNG bytes"), keccak256("PNG bytes")];
        capture.environmentManifestHash = referenceInput.observation.environment.manifestHash;
        capture.capturedAt = uint64(block.timestamp);
        referenceInput.observation.captures.push(capture);
        _archive(capture.objectHash, capture.coverageHash, capture.repeatCaptureSha256[0], false);
        _referenceDefinitions();
        _referenceGrants(address(this), true, true);
        referenceDependencies.targets = [
            address(core),
            address(core),
            address(core),
            address(store),
            address(records),
            address(snapshots),
            address(externalArchive)
        ];
        for (uint256 i; i < 7; ++i) {
            referenceDependencies.codeHashes[i] = referenceDependencies.targets[i].codehash;
        }
        referenceDependencies.chainId = savedChain;
        G.GasParameterConfig[4] memory configs;
        configs[0] = G.GasParameterConfig("VIEW_PRESERVATION_REFERENCE_READ_GAS", 1000000, 50000, 1);
        configs[1] =
            G.GasParameterConfig("VIEW_PRESERVATION_REFERENCE_SOURCE_GAS", 16000000, 50000, 1);
        configs[2] =
            G.GasParameterConfig("VIEW_PRESERVATION_REFERENCE_SNAPSHOT_GAS", 16000000, 50000, 1);
        configs[3] =
            G.GasParameterConfig("VIEW_PRESERVATION_REFERENCE_ARCHIVE_GAS", 1000000, 50000, 1);
        referenceHost = new ReferenceHost(referenceDependencies, address(core), configs);
        finalityReader = new ViewReferenceFinalityProbe();
        _uploadReference(
            bytes(EnvironmentJSON.files(referenceInput.observation.environment.packageFiles, true)),
            false
        );
        _uploadReference(
            bytes(
                EnvironmentJSON.files(
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

    function _rootReplies() internal {
        ViewReferenceSnapshotVm(address(vm))
            .mockCall(
                address(records),
                abi.encodeCall(Root.scopedContentRootHead, (scope)),
                abi.encode(rootHash)
            );
        ViewReferenceSnapshotVm(address(vm))
            .mockCall(
                address(records),
                abi.encodeCall(Root.scopedContentRootRecord, (rootHash)),
                abi.encode(rootRecord)
            );
        ViewReferenceSnapshotVm(address(vm))
            .mockCall(
                address(records),
                abi.encodeCall(RootBinding.viewPreservationContentRootBinding, (rootHash)),
                abi.encode(rootBinding)
            );
    }

    function _referenceGrants(address actor, bool local, bool global_) internal {
        _answer(
            core,
            "familyWriter(uint256,bytes32,uint8,address)",
            abi.encode(uint256(1), keccak256("CURATOR"), uint8(3), actor),
            abi.encode(local, uint64(3))
        );
        _answer(
            core,
            "familyWriter(uint256,bytes32,uint8,address)",
            abi.encode(uint256(0), keccak256("CURATOR"), uint8(8), actor),
            abi.encode(global_, uint64(8))
        );
    }

    function _referenceDefinitions() internal {
        _definitionChunks(
            RefDefs.SCHEMA_ID,
            Schema.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/preservation/view-preservation-reference-v1/schema.json"))
        );
        _definitionChunks(
            RefDefs.PROFILE_ID,
            Schema.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/preservation/view-preservation-reference-v1/profile.json"))
        );
        _definitionChunks(
            RefDefs.CANON_ID,
            Schema.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/preservation/view-preservation-reference-v1/canon.json"))
        );
        string[4] memory names = [
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1"
        ];
        for (uint256 i; i < 4; ++i) {
            _definitionChunks(
                keccak256(bytes(names[i])),
                i == 3 ? Schema.DocumentKind.CATALOG : Schema.DocumentKind.SCHEMA,
                bytes(vm.readFile(string.concat("schemas/records/", names[i], ".json")))
            );
        }
    }

    function _uploadReference(bytes memory raw, bool omitLast) internal {
        uint256 count = (raw.length + 8191) / 8192;
        for (uint256 i; i < count - (omitLast ? 1 : 0); ++i) {
            store.publishChunk(_part(raw, i * 8192));
        }
    }

    function _referenceBytes(address writer) internal returns (bytes memory canonical) {
        (bytes32 hash, bytes memory raw) = referenceHost.previewReference(referenceInput, writer);
        referenceInput.observation.expectedSourcesHash = hash;
        _uploadReference(abi.encode(referenceInput), false);
        return raw;
    }

    function _publishReference() internal returns (bytes32) {
        bytes memory raw = _referenceBytes(address(this));
        _uploadReference(raw, false);
        return referenceHost.publishReference(referenceInput);
    }

    function _referenceReader() internal view returns (ReferenceReader.Dependencies memory d) {
        d.targets = [
            address(core),
            address(core),
            address(records),
            address(snapshots),
            address(referenceHost)
        ];
        for (uint256 i; i < 5; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = savedChain;
        d.readGas = 1000000;
        d.sourceGas = 16000000;
    }

    function _environment() internal {
        RR.Environment memory e;
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
        e.packageFiles = new RR.PackageFile[](2);
        e.packageFiles[0] = RR.PackageFile(e.engineExecutablePath, 10, e.engineExecutableSha256);
        e.packageFiles[1] = RR.PackageFile(e.toolchainPath, 11, e.toolchainSha256);
        e.platformPrerequisites = new RR.PackageFile[](1);
        e.platformPrerequisites[0] = RR.PackageFile(
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
        bytes memory raw = EnvironmentJSON.manifest(e);
        e.manifestHash = keccak256(raw);
        e.manifestBytes = uint32(raw.length);
        referenceInput.observation.environment = e;
        _archive(e.objectHash, e.coverageHash, keccak256("ZIP SHA boundary"), true);
    }

    function _archive(bytes32 object, bytes32 cover, bytes32 sha, bool runtime) internal {
        EA.Coverage memory e;
        e.coverageHash = cover;
        e.objectHash = object;
        e.artistId = artist.artistId;
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
        EA.ObjectIdentity memory o = EA.ObjectIdentity(
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
        EA.CurrentPair memory pair = EA.CurrentPair(
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
        ViewReferenceSnapshotVm(address(vm))
            .mockCall(
                address(externalArchive),
                abi.encodeCall(Archive.requireCoverage, (cover, e.artistId, object)),
                abi.encode(e)
            );
        ViewReferenceSnapshotVm(address(vm))
            .mockCall(
                address(externalArchive), abi.encodeCall(Archive.coverage, (cover)), abi.encode(e)
            );
        ViewReferenceSnapshotVm(address(vm))
            .mockCall(
                address(externalArchive),
                abi.encodeCall(Archive.objectIdentity, (object)),
                abi.encode(o)
            );
        ViewReferenceSnapshotVm(address(vm))
            .mockCall(
                address(externalArchive),
                abi.encodeCall(
                    Pair.currentReceiptPair,
                    (e.firstReceiptHash, e.secondReceiptHash, e.artistId, object)
                ),
                abi.encode(pair)
            );
    }
}
