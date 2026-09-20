// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ScopedReferenceSnapshotFixture.sol";
import {
    StreamScopedReferencePublication
} from "../../../smart-contracts/domains/preservation/StreamScopedReferencePublication.sol";
import {
    StreamScopedReferenceTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedReferenceTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamFinalityScopedReferenceReads as ReferenceReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedReferenceReads.sol";
import "../../../smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol";
import "../../../smart-contracts/vendor/openzeppelin/Base64.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    IStreamExternalArtifactCoverage as Archive
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import {
    IStreamExternalArtifactCurrentPair
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamRendererRegistry as Registry
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    StreamReferenceRenderDefinitions as OriginalDefinitions
} from "../../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";

/// @dev Actual Membership/inventories/Metadata/Schema/Store/scoped Snapshot/reference host and
/// official Safe. Core/Artist/Renderer/output/Router root/archive/governed-action facts are named
/// typed test boundaries. No browser execution, complete archive or current-Core ceremony claim.
contract StreamScopedReferencePublicationTest is ScopedReferenceSnapshotFixture {
    StreamScopedReferencePublication private referenceHost;
    ScopedReferenceReadBoundary private externalArchive;
    ScopedReferenceReadBoundary private rendererRegistry;
    ScopedReferenceReadBoundary private renderer;
    T.Publication private referenceInput;

    function _reference(uint8 kind) private {
        _initialize(kind);
        bytes32 snapshotHash = _publishSnapshot();
        Scoped.Receipt memory snapshot = host.currentSnapshot(publication.scope);
        Root.Record memory root;
        root.publication.scope = publication.scope;
        root.publication.snapshotRecordHash = snapshotHash;
        root.publication.snapshotRevision = 1;
        root.snapshotHost = address(host);
        root.snapshotCodeHash = address(host).codehash;
        root.snapshotManifestHash = snapshot.manifestHash;
        root.snapshotSourceHash = snapshot.sourceHash;
        root.contentRoot = contentPlan.contentRoot;
        root.leafCount = contentPlan.tokenCount;
        root.outputManifestHash = outputManifest.manifestHash;
        root.artistId = keccak256("artist");
        root.bindingGeneration = 1;
        root.bindingHash = keccak256("binding");
        root.publisher = address(this);
        root.authorizationClass = 7;
        root.grantRevision = 1;
        root.routeHash = keccak256("actual typed root route boundary");
        root.stateHash = keccak256("approved content family");
        root.artistConsent = keccak256("original op17 receipt boundary");
        root.publishedAt = uint64(block.timestamp);
        route.set(
            "scopedContentRootHead((uint8,uint256,uint256,bytes32))",
            abi.encode(keccak256("scoped root"))
        );
        route.set("scopedContentRootRecord(bytes32)", abi.encode(root));
        externalArchive = new ScopedReferenceReadBoundary();
        _setAddress(externalArchive, "core()", address(core));
        rendererRegistry = new ScopedReferenceReadBoundary();
        renderer = new ScopedReferenceReadBoundary();
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
        entropy.set("tokenSeed(uint256)", abi.encode(keccak256("seed"), true));
        entropy.set("tokenEntropyStatus(uint256)", abi.encode(uint8(5)));
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
            _sample(i, i == 0 ? 0 : count - 1, registration);
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
            "SCOPED_REFERENCE_READ_GAS", 500000, 50000, 1
        );
        configs[1] = IStreamGasParameterHost.GasParameterConfig(
            "SCOPED_REFERENCE_SOURCE_GAS", 2000000, 50000, 1
        );
        configs[2] = IStreamGasParameterHost.GasParameterConfig(
            "SCOPED_REFERENCE_SNAPSHOT_GAS", 8000000, 50000, 1
        );
        configs[3] = IStreamGasParameterHost.GasParameterConfig(
            "SCOPED_REFERENCE_ARCHIVE_GAS", 500000, 50000, 1
        );
        referenceHost = new StreamScopedReferencePublication(d, address(executor), configs);
    }

    function _environment() private {
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

    function _sample(uint256 ordinal, uint256 index, Registry.Registration memory registration)
        private
    {
        uint256 token = membership.scopeTokenAt(publication.scope, index);
        (,, uint256 serial,) = core.tokenCollectionIdentity(token);
        bytes memory html = bytes("<!doctype html><title>explicit test output</title>");
        bytes memory json = abi.encodePacked(
            "{\"animation_url\":\"data:text/html;base64,", Base64.encode(html), "\"}"
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
            address(route),
            abi.encodeWithSignature(
                "historicalTokenMetadataJSON(address,uint256)", address(core), token
            ),
            abi.encode(json)
        );
        _archive(c.objectHash, c.coverageHash, c.repeatCaptureSha256[0], false);
    }

    function _archive(bytes32 object, bytes32 cover, bytes32 sha, bool runtime) private {
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

    function _registerReferenceDefinitions() private {
        string[6] memory names = [
            "STREAM_SCOPED_REFERENCE_RENDER_ABI_V1",
            "STREAM_SCOPED_REFERENCE_RENDER_PROFILE_V1",
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1"
        ];
        for (uint256 i; i < names.length; ++i) {
            _registerReference(
                names[i],
                i == 1 || i == 5
                    ? IStreamSchemaRegistry.DocumentKind.CATALOG
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                bytes(vm.readFile(string.concat("schemas/records/", names[i], ".json")))
            );
        }
    }

    function _registerReference(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw
    ) private {
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

    function _referenceBytes(address writer) private returns (bytes memory raw) {
        (bytes32 hash, bytes memory canonical) =
            referenceHost.previewReference(referenceInput, writer);
        referenceInput.observation.expectedSourcesHash = hash;
        _uploadSnapshot(abi.encode(referenceInput), false);
        return canonical;
    }

    function _publishReference() private returns (bytes32) {
        _uploadSnapshot(_referenceBytes(address(this)), false);
        return referenceHost.publishReference(referenceInput);
    }

    function testTokenAndBurnedIdentityExactOriginalRecord() public {
        _reference(1);
        uint256 token = referenceInput.scope.tokenId;
        core.setToken(token, 1, 2, 3);
        bytes memory raw = _referenceBytes(address(this));
        _uploadSnapshot(raw, false);
        bytes32 hash = referenceHost.publishReference(referenceInput);
        T.Receipt memory receipt = referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(
            receipt.observation.recordHash == hash
                && receipt.observation.payloadHash == keccak256(raw)
        );
        T.SourceFacts memory f = referenceHost.referenceSource(hash);
        require(
            f.samples.length == 1 && f.samples[0].membershipIndex == 0
                && f.samples[0].observation.tokenId == token
                && f.samples[0].observation.collectionSerial == 2
        );
        (T.Publication memory p, T.Receipt memory r) = referenceHost.referenceRecord(hash);
        require(
            keccak256(abi.encode(p)) == keccak256(abi.encode(referenceInput))
                && keccak256(abi.encode(r)) == keccak256(abi.encode(receipt))
        );
        require(keccak256(referenceHost.referencePayload(hash)) == keccak256(raw));
    }

    function testReleaseCompleteMembershipAndFirstLastOrder() public {
        _reference(2);
        uint256 saved = referenceInput.observation.captures[0].tokenId;
        referenceInput.observation.captures[0].tokenId =
        referenceInput.observation.captures[1].tokenId;
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.observation.captures[0].tokenId = saved;
        bytes32 hash = _publishReference();
        T.SourceFacts memory f = referenceHost.referenceSource(hash);
        require(
            f.snapshotSource.membership.tokenCount == 3 && f.samples.length == 2
                && f.samples[0].membershipIndex == 0 && f.samples[1].membershipIndex == 2
        );
    }

    function testSeasonScopeSubstitutionCurrentRefusalPreservesHistory() public {
        _reference(3);
        bytes32 hash = _publishReference();
        bytes32 payload = keccak256(referenceHost.referencePayload(hash));
        StreamFinalityScope memory different = referenceInput.scope;
        different.scopeId = keccak256("different season");
        vm.expectRevert();
        referenceHost.requireCurrent(different, hash, 1);
        contentPlan.contentRoot = keccak256("changed complete output");
        _refreshPlans();
        vm.expectRevert();
        referenceHost.requireCurrent(referenceInput.scope, hash, 1);
        require(keccak256(referenceHost.referencePayload(hash)) == payload);
    }

    function testViewAndCollectionNeverBorrowScopedReference() public {
        _reference(1);
        referenceInput.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
        referenceInput.scope =
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, keccak256("view"));
        vm.expectRevert();
        referenceHost.previewReference(referenceInput, address(this));
    }

    function testExactClassTwoScopedLockAndReplay() public {
        _reference(2);
        bytes32 hash = _publishReference();
        (bytes32 scope, bytes32 oldState, bytes32 next) =
            referenceHost.lockTransition(referenceInput.scope);
        svm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("lock"), uint8(2), scope, oldState, bytes32(0))
        );
        vm.expectRevert();
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        svm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("lock"), uint8(2), scope, oldState, next)
        );
        vm.prank(address(executor));
        referenceHost.lockReference(referenceInput.scope);
        require(referenceHost.referenceLock(referenceInput.scope).recordHash == hash);
        require(referenceHost.finalityStateForScope(referenceInput.scope).frozen);
        ReferenceReads.Dependencies memory reader = _reader();
        require(ReferenceReads.component(reader, referenceInput.scope, hash, 1).frozen);
        reader.targets[3] = address(route);
        reader.codeHashes[3] = address(route).codehash;
        vm.expectRevert();
        ReferenceReads.requireCurrent(reader, referenceInput.scope, hash, 1);
        vm.expectRevert();
        referenceHost.publishReference(referenceInput);
    }

    function _reader() private view returns (ReferenceReads.Dependencies memory d) {
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

    function testActualCuratorGrantAndExactSourceHash() public {
        _reference(1);
        bytes memory raw = _referenceBytes(address(this));
        _uploadSnapshot(raw, false);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(this), false);
        vm.expectRevert();
        referenceHost.publishReference(referenceInput);
        _grant(0, StreamRecordFamilies.CURATOR, 8, address(this), true);
        // The new recorder grant is itself part of the original canonical receipt bytes.
        raw = _referenceBytes(address(this));
        _uploadSnapshot(raw, false);
        bytes32 expected = referenceInput.observation.expectedSourcesHash;
        referenceInput.observation.expectedSourcesHash = keccak256("caller claim");
        vm.expectRevert();
        referenceHost.publishReference(referenceInput);
        require(referenceHost.referenceCount(referenceInput.scope) == 0);
        referenceInput.observation.expectedSourcesHash = expected;
        bytes32 hash = referenceHost.publishReference(referenceInput);
        require(
            referenceHost.requireCurrent(referenceInput.scope, hash, 1).observation
                    .authorizationClass == 8
        );
    }

    function testOfficialSafeMissingChunkRollbackAndIdenticalRetry() public {
        _reference(2);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x818131;
        keys[1] = 0x818132;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 903);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(account), true);
        bytes memory raw = _referenceBytes(address(account));
        _uploadSnapshot(raw, true);
        bytes memory input = abi.encodeCall(referenceHost.publishReference, (referenceInput));
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(referenceHost), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
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
        require(account.nonce() == nonce && referenceHost.referenceCount(referenceInput.scope) == 0);
        _uploadSnapshot(raw, false);
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
        require(
            account.nonce() == nonce + 1
                && referenceHost.currentReference(referenceInput.scope).observation.recorder
                    == address(account)
        );
    }
}
