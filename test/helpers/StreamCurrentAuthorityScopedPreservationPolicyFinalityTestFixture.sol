// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentAuthorityScopedPreservationPolicyFinalityFixture.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyBytesFixture
} from "./StreamCurrentAuthorityScopedPreservationPolicyBytesFixture.sol";
import {
    StreamReferenceRenderTypes as CompositionReference
} from "../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    IStreamPreservationRendererV1 as CompositionProducer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRendererV1.sol";
import {
    IStreamCoreIdentity as CompositionCore
} from "../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";

/// @notice Real current contract composition using explicitly synthetic offchain observations.
/// @dev Default tests execute the same internal protocol chain as FinalityLocalRecipe without
/// reading old captures or conditionally skipping. HTML/JSON are the exact current producer bytes.
/// The valid 1x1 PNG is a synthetic observation, NOT a rendering of those bytes. The valid ZIP
/// contains two clearly labelled non-executable text fixtures, NOT a browser distribution.
/// Observer/checkpoint attestations and STATIC analysis are the inherited local fixture evidence.
/// Fresh browser/reproducibility, transitive STATIC conformance, gas and runtime fit remain unproved.
abstract contract StreamCurrentAuthorityScopedPreservationPolicyFinalityTestFixture is
    StreamCurrentAuthorityScopedPreservationPolicyBytesFixture,
    StreamCurrentAuthorityScopedPreservationPolicyFinalityFixture
{
    function _runScopedFinalityComposition(StreamFinalityScopeType kind)
        internal
        returns (AuthorityScopedFinality memory result)
    {
        require(address(assemblyCore) == address(0), "one fresh actual graph per test");
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        _authorityRecoverOriginal();
        _assemblyPrepareDescriptionDefinitions();
        _assemblySelectDescriptionsAndWaiver();
        AuthorityScopedPublication memory p = _authorityPublishScopedPreservationPolicy(kind);
        _authorityCaptureOriginalPreservation();
        (string memory environment, string memory runtime, string memory captures) =
            _compositionObservations(p);
        AuthorityScopedReference memory r = _authorityPublishScopedPreservationPolicyReference(
            p, environment, runtime, captures, true
        );

        _authorityMigrateNext();
        ScopedRecordHeads memory heads;
        heads.contentTag = keccak256("B actual composition scoped records");
        ScopedRecordSet memory records = _publishScopedRecords(p.scope, heads);
        AuthorityScopedRights memory rightsResult = _authorityPublishScopedRights(p.scope);
        heads.workHead = records.workPublication.recordHash;
        heads.workRevision = records.workSelection.revision;
        heads.intentHead = records.intentPublication.recordHash;
        heads.intentRevision = records.intentSelection.revision;
        heads.interviewPredecessor = records.interviewPublication.recordHash;
        heads.contentTag = keccak256("C actual composition successor records");
        _authorityMigrateNext();
        records = _publishScopedRecords(p.scope, heads);
        require(
            authorityEra == 2 && authorityRegistries[2] == address(assemblyArtists),
            "actual complete A to B to C authority selection"
        );
        _authoritySealScopedRecords(records, rightsResult);
        _authorityPrepareScopedFinalityDefinitions();
        AuthorityScopedInventory memory inventoryResult =
            _authorityMaterializeScopedInventory(p, r, records, rightsResult.statement);
        bytes[] memory retained =
            _authorityCollectScopedSourceBytes(p, r, inventoryResult, records, rightsResult);
        for (uint256 i; i < retained.length; ++i) {
            require(
                retained[i].length < 262144,
                "explicit bounded fixture needs no large endpoint input"
            );
        }
        AuthorityScopedBundle memory bundleResult = _authorityCoverScopedBundle(
            p,
            r,
            inventoryResult,
            retained,
            _compositionPackageProofs(),
            new AuthorityScopedEndpoint[](0)
        );
        require(
            bundleResult.packageMembers == 2 && bundleResult.emptyPackageMembers == 0
                && bundleResult.stateBundles != 0,
            "real package members and certified Artist occurrences covered"
        );
        _beforeCompositionSanction(p.scope);
        result = _authorityFinalizeScopedPreservation(p, r, inventoryResult, bundleResult);
        require(
            result.authorityEra == 2 && result.artistRegistry == authorityRegistries[2]
                && result.sanctionRecord != 0 && result.sanctionArchiveHash != 0
                && result.sanctionArtifact != 0 && result.sanctionCoverage != 0
                && result.finalityRecord != 0 && result.actionId != 0,
            "actual C sanction/archive/Finality"
        );
        _authorityRequireOriginals();
        _authorityRequireRoute();
    }

    function _beforeCompositionSanction(StreamFinalityScope memory) internal virtual { }

    function _compositionObservations(AuthorityScopedPublication memory p)
        private
        view
        returns (string memory environment, string memory runtime, string memory captures)
    {
        CompositionReference.Environment memory e;
        bytes memory engine = _compositionEngine();
        bytes memory tool = _compositionTool();
        e.engineName = "Synthetic composition fixture; not an executed browser";
        e.engineVersion = "1";
        e.engineExecutableSha256 = sha256(engine);
        e.toolchainName = "Synthetic observation fixture; no rendering performed";
        e.toolchainVersion = "1";
        e.toolchainSha256 = sha256(tool);
        e.engineExecutablePath = "engine/fixture.txt";
        e.toolchainPath = "tool/fixture.txt";
        e.packageFiles = new CompositionReference.PackageFile[](2);
        e.packageFiles[0] = CompositionReference.PackageFile(
            e.engineExecutablePath, uint64(engine.length), sha256(engine)
        );
        e.packageFiles[1] =
            CompositionReference.PackageFile(e.toolchainPath, uint64(tool.length), sha256(tool));
        e.platformPrerequisites = new CompositionReference.PackageFile[](1);
        bytes memory prerequisite =
            bytes("Synthetic declared platform boundary; no operating system observation.\n");
        e.platformPrerequisites[0] = CompositionReference.PackageFile(
            "C:/fixture/platform.txt", uint64(prerequisite.length), sha256(prerequisite)
        );
        // These fixed vocabulary values select the production schema. They describe the
        // synthetic declared profile, not this Windows host or a measured browser environment.
        e.operatingSystem = "Windows";
        e.operatingSystemVersion = "synthetic declared fixture; not observed";
        e.architecture = "AMD64";
        e.viewportWidth = 1;
        e.viewportHeight = 1;
        e.devicePixelRatio = 1;
        e.colorSpace = "srgb";
        e.softwareRasterization = true;
        e.captureProfile = keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1");
        e.licenseNote = "Synthetic fixture bytes only; no executable browser or capture claim.";
        environment = string.concat('{"environmentABI":"', _compositionHex(abi.encode(e)), '"}');
        runtime = string.concat("{", _compositionEndpointJSON(_compositionZip()), "}");
        captures = string.concat('{"capture1":', _compositionCaptureJSON(p, 0));
        if (p.checkpoint.tokenCount > 1) {
            captures = string.concat(
                captures, ',"capture2":', _compositionCaptureJSON(p, p.checkpoint.tokenCount - 1)
            );
        }
        captures = string.concat(captures, "}");
    }

    function _compositionCaptureJSON(AuthorityScopedPublication memory p, uint256 index)
        private
        view
        returns (string memory)
    {
        uint256 token = assemblyMembership.scopeTokenAt(p.scope, index);
        (bool exists, uint256 collection, uint256 serial,) =
            CompositionCore(address(assemblyCore)).tokenCollectionIdentity(token);
        require(exists && collection == p.scope.collectionId && serial != 0);
        address producer = p.outputRows[index].preservation.producer;
        require(
            token == p.outputRows[index].leaf.tokenId
                && producer.codehash == p.outputRows[index].preservation.producerCodeHash,
            "exact real retained producer"
        );
        bytes memory html = bytes(CompositionProducer(producer).preservationTokenHTML(token));
        bytes memory json = bytes(CompositionProducer(producer).preservationTokenJSON(token));
        require(
            keccak256(html) == p.outputRows[index].htmlHash
                && keccak256(json) == p.outputRows[index].leaf.metadataHash
        );
        bytes memory png = _compositionPNG();
        string memory capture = string.concat(
            '{"tokenId":',
            Strings.toString(token),
            ',"collectionSerial":',
            Strings.toString(serial),
            ',"html":"',
            _compositionHex(html),
            '","metadataJSON":"',
            _compositionHex(json),
            '"'
        );
        capture = string.concat(
            capture,
            ',"repeatCapture0Sha256":"',
            _compositionHex(abi.encodePacked(sha256(png))),
            '","repeatCapture1Sha256":"',
            _compositionHex(abi.encodePacked(sha256(png))),
            '",',
            _compositionEndpointJSON(png),
            "}"
        );
        return capture;
    }

    function _compositionPackageProofs()
        private
        pure
        returns (AuthorityScopedPackageProof[] memory p)
    {
        p = new AuthorityScopedPackageProof[](2);
        p[0] = AuthorityScopedPackageProof(
            0, "engine/fixture.txt", _compositionEndpoint(_compositionEngine())
        );
        p[1] = AuthorityScopedPackageProof(
            1, "tool/fixture.txt", _compositionEndpoint(_compositionTool())
        );
    }

    function _compositionEndpoint(bytes memory raw)
        private
        pure
        returns (AuthorityScopedEndpoint memory e)
    {
        require(raw.length != 0 && raw.length < 262144);
        e.contentHash = keccak256(raw);
        e.sha256Digest = sha256(raw);
        e.byteSize = uint64(raw.length);
        e.arweaveDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(e.sha256Digest)), sha256(abi.encode(uint256(raw.length)))
            )
        );
        e.firstDataPath = abi.encode(e.sha256Digest, uint256(raw.length));
        e.lastDataPath = e.firstDataPath;
        e.firstChunkRaw = raw;
        e.lastChunkRaw = raw;
    }

    function _compositionEndpointJSON(bytes memory raw) private pure returns (string memory out) {
        AuthorityScopedEndpoint memory e = _compositionEndpoint(raw);
        out = string.concat(
            '"contentHash":"',
            _compositionHex(abi.encodePacked(e.contentHash)),
            '","sha256Digest":"',
            _compositionHex(abi.encodePacked(e.sha256Digest)),
            '","arweaveDataRoot":"',
            _compositionHex(abi.encodePacked(e.arweaveDataRoot)),
            '","byteSize":',
            Strings.toString(e.byteSize)
        );
        out = string.concat(
            out,
            ',"firstDataPath":"',
            _compositionHex(e.firstDataPath),
            '","lastDataPath":"',
            _compositionHex(e.lastDataPath),
            '","firstChunkRaw":"',
            _compositionHex(e.firstChunkRaw),
            '","lastChunkRaw":"',
            _compositionHex(e.lastChunkRaw),
            '"'
        );
    }

    function _compositionHex(bytes memory raw) private pure returns (string memory) {
        bytes memory alphabet = bytes("0123456789abcdef");
        bytes memory out = new bytes(2 + 2 * raw.length);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i; i < raw.length; ++i) {
            out[2 + 2 * i] = alphabet[uint8(raw[i]) >> 4];
            out[3 + 2 * i] = alphabet[uint8(raw[i]) & 15];
        }
        return string(out);
    }

    function _compositionEngine() private pure returns (bytes memory) {
        return bytes("Synthetic engine bytes; not executable and never used to render.\n");
    }

    function _compositionTool() private pure returns (bytes memory) {
        return bytes("Synthetic capture tool bytes; no browser execution took place.\n");
    }

    /// @dev Deterministic stored ZIP: exact two named text members above, 1980-01-01 timestamps,
    /// valid CRC32, local records, central directory and end record. No executable/browser bytes.
    function _compositionZip() private pure returns (bytes memory) {
        return hex"504b0304140000000000000021009f49f865410000004100000012000000656e67696e652f666978747572652e74787453796e74686574696320656e67696e652062797465733b206e6f742065786563757461626c6520616e64206e65766572207573656420746f2072656e6465722e0a504b030414000000000000002100c506cc4a3f0000003f00000010000000746f6f6c2f666978747572652e74787453796e746865746963206361707475726520746f6f6c2062797465733b206e6f2062726f7773657220657865637574696f6e20746f6f6b20706c6163652e0a504b01021403140000000000000021009f49f8654100000041000000120000000000000000000000800100000000656e67696e652f666978747572652e747874504b0102140314000000000000002100c506cc4a3f0000003f000000100000000000000000000000800171000000746f6f6c2f666978747572652e747874504b050600000000020002007e000000de0000000000";
    }

    /// @dev Valid transparent 1x1 RGBA PNG with full CRC32/zlib stream. It is deliberately a
    /// synthetic repeated observation, not a browser render or an independently observed result.
    function _compositionPNG() private pure returns (bytes memory) {
        return hex"89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000b49444154789c6360000200000500017a5eab3f0000000049454e44ae426082";
    }
}
