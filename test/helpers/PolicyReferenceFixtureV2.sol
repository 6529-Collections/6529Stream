// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./PolicySnapshotFixtureV2.sol";
import {
    IStreamFinalityEntropyPolicySourceSet
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamPolicyReferencePublicationV2
} from "../../smart-contracts/domains/preservation/StreamPolicyReferencePublicationV2.sol";
import {
    StreamPolicyReferenceTypesV2 as T
} from "../../smart-contracts/interfaces/stream/preservation/StreamPolicyReferenceTypesV2.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamFinalityPolicyReferenceReadsV2 as ReferenceReads
} from "../../smart-contracts/domains/finality/StreamFinalityPolicyReferenceReadsV2.sol";
import "../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import "../../smart-contracts/vendor/openzeppelin/Base64.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamExternalArtifactCoverage as Archive
} from "../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    IStreamExternalArtifactCurrentPair
} from "../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamRendererRegistry as Registry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    StreamReferenceRenderDefinitions as OriginalDefinitions
} from "../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";

/// @dev Actual Membership/inventories/Metadata/Schema/Store/scoped Snapshot/reference host and
/// official Safe. Core/Artist/Renderer/output/Router root/archive/governed-action facts are named
/// typed test boundaries. No browser execution, complete archive or current-Core ceremony claim.
abstract contract PolicyReferenceFixtureV2 is PolicySnapshotFixtureV2 {
    StreamPolicyReferencePublicationV2 internal referenceHost;
    PolicySnapshotReadBoundaryV2 internal externalArchive;
    PolicySnapshotReadBoundaryV2 internal rendererRegistry;
    PolicySnapshotReadBoundaryV2 internal renderer;
    T.Publication internal referenceInput;

    function _reference(bool terminal) internal {
        _initializePolicySnapshot();
        bytes32 snapshotHash = _publishSnapshot();
        externalArchive = new PolicySnapshotReadBoundaryV2();
        _setAddress(externalArchive, "core()", address(core));
        rendererRegistry = new PolicySnapshotReadBoundaryV2();
        renderer = new PolicySnapshotReadBoundaryV2();
        Registry.Registration memory registration;
        registration.renderer = address(renderer);
        registration.manifest.rendererClass = keccak256("STATIC");
        registration.manifest.rendererId = keccak256("renderer");
        registration.manifest.rendererVersion = keccak256("v1");
        registration.manifest.contextVersion = keccak256("context");
        registration.manifest.schemaHash = keccak256("schema");
        rendererRegistry.set(
            "requireRetained(bytes32)", abi.encode(address(renderer), address(renderer).codehash)
        );
        rendererRegistry.set("registration(bytes32)", abi.encode(registration));
        referenceInput.scope = publication.scope;
        referenceInput.observation.collectionId = 1;
        referenceInput.observation.referenceId = keccak256("scoped reference");
        referenceInput.observation.snapshotRecordHash = snapshotHash;
        referenceInput.observation.snapshotRevision = 1;
        referenceInput.observation.effectiveAt = uint64(block.timestamp);
        referenceInput.observation.reasonHash = keccak256("reference reason");
        _environment();
        uint256 count = selectionPlan.tokenCount;
        uint256 n = count == 1 ? 1 : 2;
        referenceInput.observation.captures = new R.Capture[](n);
        for (uint256 i; i < n; ++i) {
            _sample(i, i == 0 ? 0 : count - 1, registration, terminal);
        }
        _registerReferenceDefinitions();
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(this), true);
        T.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(route),
            address(host),
            address(externalArchive)
        ];
        for (uint256 i; i < 7; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        IStreamGasParameterHost.GasParameterConfig[4] memory configs;
        configs[0] = IStreamGasParameterHost.GasParameterConfig(
            "POLICY_REFERENCE_READ_GAS", 1000000, 50000, 1
        );
        configs[1] = IStreamGasParameterHost.GasParameterConfig(
            "POLICY_REFERENCE_SOURCE_GAS", 2000000, 50000, 1
        );
        configs[2] = IStreamGasParameterHost.GasParameterConfig(
            "POLICY_REFERENCE_SNAPSHOT_GAS", 8000000, 50000, 1
        );
        configs[3] = IStreamGasParameterHost.GasParameterConfig(
            "POLICY_REFERENCE_ARCHIVE_GAS", 500000, 50000, 1
        );
        // Fixture allowance covers Membership's own 500,000-gas forwarding admission.
        // It is not a production minimum or whole-operation capacity acceptance.
        referenceHost = StreamPolicyReferencePublicationV2(
            _policyArtifactCreate(
                "StreamPolicyReferencePublicationV2.sol:StreamPolicyReferencePublicationV2",
                "out/StreamPolicyReferencePublicationV2.sol/StreamPolicyReferencePublicationV2.json",
                abi.encode(d, address(executor), configs),
                8
            )
        );
        require(
            referenceHost.core() == d.targets[0] && referenceHost.metadataHost() == d.targets[1]
                && referenceHost.metadataRouter() == d.targets[4]
                && referenceHost.snapshots() == d.targets[5]
                && referenceHost.archiveCoverage() == d.targets[6]
                && referenceHost.deploymentChainId() == d.chainId
                && referenceHost.governanceAuthority() == address(executor)
                && referenceHost.executorCodeHash() == address(executor).codehash,
            "actual reference constructor immutables"
        );
        _uploadSnapshot(
            bytes(
                StreamReferenceEnvironmentJson.files(
                    referenceInput.observation.environment.packageFiles, true
                )
            ),
            false
        );
        _uploadSnapshot(
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

    function _environment() internal {
        R.Environment memory e;
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
        e.packageFiles = new R.PackageFile[](2);
        e.packageFiles[0] = R.PackageFile(e.engineExecutablePath, 10, e.engineExecutableSha256);
        e.packageFiles[1] = R.PackageFile(e.toolchainPath, 11, e.toolchainSha256);
        e.platformPrerequisites = new R.PackageFile[](1);
        e.platformPrerequisites[0] = R.PackageFile(
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
        _archive(e.objectHash, e.coverageHash, keccak256("ZIP SHA boundary"), true);
    }

    function _sample(
        uint256 ordinal,
        uint256 index,
        Registry.Registration memory registration,
        bool terminal
    ) internal {
        uint256 token = membership.scopeTokenAt(publication.scope, index);
        (,, uint256 serial,) = core.tokenCollectionIdentity(token);
        bytes memory html = bytes("<!doctype html><title>explicit test output</title>");
        bytes memory json = terminal
            ? abi.encodePacked(
                '{"name":"terminal","token_data_base64":"EjQ=","properties":{"stream":{"entropy_status":1}},"animation_url":"data:text/html;base64,',
                Base64.encode(html),
                '"}'
            )
            : abi.encodePacked(
                '{"animation_url":"data:text/html;base64,', Base64.encode(html), '"}'
            );
        R.Capture memory c;
        c.tokenId = token;
        c.collectionSerial = serial;
        c.metadataJSONHash = keccak256(json);
        c.htmlHash = keccak256(html);
        c.htmlBytes = uint32(html.length);
        c.animationHTML = html;
        c.objectHash = keccak256(abi.encode("PNG object", token));
        c.coverageHash = keccak256(abi.encode("PNG coverage", token));
        c.sourceSha256 = sha256(html);
        c.repeatCaptureSha256 =
            [keccak256("same PNG SHA boundary"), keccak256("same PNG SHA boundary")];
        c.environmentManifestHash = referenceInput.observation.environment.manifestHash;
        c.capturedAt = uint64(block.timestamp);
        referenceInput.observation.captures[ordinal] = c;
        Selection.TokenSelection memory row;
        row.tokenId = token;
        row.selection.registry = address(rendererRegistry);
        row.selection.registryCodeHash = address(rendererRegistry).codehash;
        row.selection.versionKey = keccak256("retained version");
        row.selection.renderer = address(renderer);
        row.selection.rendererCodeHash = address(renderer).codehash;
        row.selection.rendererId = registration.manifest.rendererId;
        row.selection.rendererVersion = registration.manifest.rendererVersion;
        row.selection.contextVersion = registration.manifest.contextVersion;
        row.selection.schemaHash = registration.manifest.schemaHash;
        row.sources[3] = address(entropy);
        row.sourceCodeHashes[3] = address(entropy).codehash;
        Content.Output memory output;
        output.leaf.tokenId = token;
        output.leaf.metadataHash = c.metadataJSONHash;
        output.leaf.animationHash = c.htmlHash;
        output.leaf.tokenDataHash = keccak256(hex"1234");
        output.selectionRowHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                block.chainid,
                address(core),
                address(route),
                row
            )
        );
        output.htmlHash = c.htmlHash;
        output.entropy = IStreamFinalityEntropyPolicySourceSet.TokenReadiness(
            address(entropy),
            address(entropy).codehash,
            policyRow.policyHash,
            terminal ? 1 : 5,
            terminal ? 0 : 2,
            0,
            terminal ? 1 : 0,
            terminal,
            !terminal,
            terminal ? bytes32(0) : keccak256("original finalized seed")
        );
        output.terminalAdmissionHash =
            terminal ? keccak256("explicit actual-profile admission boundary") : bytes32(0);
        svm.mockCall(
            address(core),
            abi.encodeWithSignature("coordinatorAtMint(uint256)", token),
            abi.encode(address(entropy))
        );
        svm.mockCall(
            address(entropy),
            abi.encodeCall(IStreamFinalityEntropyPolicySourceSet.tokenEntropyReadiness, (token)),
            abi.encode(output.entropy)
        );
        svm.mockCall(
            address(selected),
            abi.encodeCall(Selection.selectionAt, (contentPlan.selectionId, index)),
            abi.encode(row)
        );
        svm.mockCall(
            address(content),
            abi.encodeCall(Content.outputAt, (outputManifest.checkpointHash, index)),
            abi.encode(output)
        );
        svm.mockCall(
            address(core),
            abi.encodeWithSignature("tokenData(uint256)", token),
            abi.encode(bytes(hex"1234"))
        );
        svm.mockCall(
            address(route), abi.encodeWithSignature("tokenJSON(uint256)", token), abi.encode(json)
        );
        svm.mockCall(
            address(route), abi.encodeWithSignature("tokenHTML(uint256)", token), abi.encode(html)
        );
        // Compact historical output is deliberately different; it cannot satisfy full output.
        svm.mockCall(
            address(route),
            abi.encodeWithSignature(
                "historicalTokenMetadataJSON(address,uint256)", address(core), token
            ),
            abi.encode(bytes("compact historical"))
        );
        _archive(c.objectHash, c.coverageHash, c.repeatCaptureSha256[0], false);
    }

    function _archive(bytes32 object, bytes32 cover, bytes32 sha, bool runtime) internal {
        E.Coverage memory e;
        e.coverageHash = cover;
        e.objectHash = object;
        e.artistId = keccak256("artist");
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
        E.ObjectIdentity memory o = E.ObjectIdentity(
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
        E.CurrentPair memory pair = E.CurrentPair(
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
        svm.mockCall(
            address(externalArchive),
            abi.encodeCall(Archive.requireCoverage, (cover, e.artistId, object)),
            abi.encode(e)
        );
        svm.mockCall(
            address(externalArchive), abi.encodeCall(Archive.coverage, (cover)), abi.encode(e)
        );
        svm.mockCall(
            address(externalArchive),
            abi.encodeCall(Archive.objectIdentity, (object)),
            abi.encode(o)
        );
        svm.mockCall(
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
            "STREAM_POLICY_COLLECTION_REFERENCE_ABI_V2",
            "STREAM_POLICY_COLLECTION_REFERENCE_PROFILE_V2",
            "STREAM_ABI_POLICY_COLLECTION_REFERENCE_V2"
        ];
        string[3] memory files = [
            "policy-collection-reference-v2.schema.json",
            "policy-collection-reference-v2.profile.json",
            "policy-collection-reference-v2.abi.json"
        ];
        for (uint256 i; i < 3; ++i) {
            _registerReference(
                names[i],
                i == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : i == 1
                        ? IStreamSchemaRegistry.DocumentKind.CATALOG
                        : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
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
            _registerReference(
                originals[i],
                i == 3
                    ? IStreamSchemaRegistry.DocumentKind.CATALOG
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                bytes(vm.readFile(string.concat("schemas/records/", originals[i], ".json")))
            );
        }
    }

    function _registerReference(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw
    ) internal {
        bytes32[] memory chunks = new bytes32[]((raw.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 size = raw.length - i * 8192;
            if (size > 8192) size = 8192;
            bytes memory chunk = new bytes(size);
            for (uint256 j; j < size; ++j) {
                chunk[j] = raw[i * 8192 + j];
            }
            (chunks[i],) = store.publishChunk(chunk);
        }
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, keccak256(raw), schemas.RAW_BYTES(), 0, "", uint32(raw.length)
        );
        (bytes32 scope, bytes32 oldState, bytes32 next) =
            schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas),
            abi.encodeCall(schemas.registerDocument, (spec, chunks)),
            scope,
            oldState,
            next
        );
    }

    function _referenceBytes(address writer) internal returns (bytes memory raw) {
        (bytes32 hash, bytes memory canonical) =
            referenceHost.previewReference(referenceInput, writer);
        referenceInput.observation.expectedSourcesHash = hash;
        _uploadSnapshot(abi.encode(referenceInput), false);
        return canonical;
    }

    function _publishReference() internal returns (bytes32) {
        _uploadSnapshot(_referenceBytes(address(this)), false);
        return referenceHost.publishReference(referenceInput);
    }

    function _reader() internal view returns (ReferenceReads.Dependencies memory d) {
        d.targets = [
            address(core), address(metadata), address(route), address(host), address(referenceHost)
        ];
        for (uint256 i; i < 5; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 12000000;
    }
}
