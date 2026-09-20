// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./PreservationReferenceFixture.sol";
import "../../helpers/ArtistArtifactCreate.sol";
import {
    StreamReferenceModePublication
} from "../../../smart-contracts/domains/preservation/StreamReferenceModePublication.sol";
import {
    StreamReferenceModeTypes as Mode
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceMetricTypes as Metric
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceMetricTypes.sol";
import {
    StreamReferenceMetricProof
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricProof.sol";
import {
    StreamReferenceModeDefinitions as D
} from "../../../smart-contracts/domains/records/StreamReferenceModeDefinitions.sol";
import {
    StreamReferenceMetricDefinitions as MD
} from "../../../smart-contracts/domains/records/StreamReferenceMetricDefinitions.sol";
import {
    StreamReferenceModeInventory
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeInventory.sol";
import {
    StreamRenderCriticalSourceTypes as Critical
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as I
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

interface MetricPublicationVm {
    function readFileBinary(string calldata path) external view returns (bytes memory);
    function writeFileBinary(string calldata path, bytes calldata data) external;
}

contract MetricPublicationInventoryProbe {
    function items(Critical.Dependencies memory d, Critical.Context memory c)
        external
        view
        returns (I.Item[] memory rows)
    {
        (, rows) = StreamReferenceModeInventory.stage(d, c, 2);
    }
}

/// @notice Actual Metadata/Schema/Store/Archive/threshold Safe, original browser bytes, and restored metric replay.
/// @dev Core/Artist/network are the inherited named typed boundaries. Fixture timestamps are not
/// browser timestamps. Export and replay phases use this SAME contract/setup, without source edits.
contract StreamReferenceMetricPublicationTest is
    PreservationReferenceFixture,
    ArtistArtifactCreate
{
    MetricPublicationVm private constant metricVm =
        MetricPublicationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint64 private constant CAPTURE_TIME = 1789516800;
    uint64 private constant FIXTURE_TIME = 1790121600; // Explicit test time: 2026-09-23 UTC.
    uint256 private constant TX_CAP = 16777216;
    StreamReferenceModePublication private modes;
    PreservationReferenceConsumer private consumer;
    Mode.Evidence private modeEvidence;
    bool private refreshedReceipts;
    uint256 private largestPartGas;
    uint256 private largestInventoryGas;
    uint256 private environmentPreparationGas;

    function setUp() public override {
        super.setUp();
        vm.warp(FIXTURE_TIME);
        refreshedReceipts = true;
        _combinedEnvironment();
        _definitions();
        StreamReferenceRenderTypes.Dependencies memory d = referenceHost.dependencies();
        IStreamGasParameterHost.GasParameterConfig[4] memory configs;
        configs[0] = _gas("REFERENCE_READ_GAS", d.readGas, 1);
        configs[1] = _gas("REFERENCE_SOURCE_GAS", d.sourceGas, 1);
        configs[2] = _gas("REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 1);
        configs[3] = _gas("REFERENCE_ARCHIVE_GAS", d.archiveGas, 1);
        Mode.Dependencies memory bindings;
        modes = StreamReferenceModePublication(
            _artistArtifactCreate(
                "StreamReferenceModePublication.sol:StreamReferenceModePublication",
                abi.encode(d, address(executor), configs, bindings)
            )
        );
        _metric();
        StreamFinalityReferenceReads.Dependencies memory f;
        f.core = address(core);
        f.metadata = address(metadata);
        f.referencePublisher = address(modes);
        f.metadataRouter = address(router);
        f.snapshots = address(snapshots);
        f.coreCodeHash = address(core).codehash;
        f.metadataCodeHash = address(metadata).codehash;
        f.referenceCodeHash = address(modes).codehash;
        f.routerCodeHash = address(router).codehash;
        f.snapshotsCodeHash = address(snapshots).codehash;
        f.chainId = block.chainid;
        f.readGas = 500000;
        f.validationGas = 14000000;
        consumer = new PreservationReferenceConsumer(f);
    }

    function _prepareEnvironment() private {
        // Cooling a newly created carrier in setUp loses its code at this Foundry version's
        // setup-to-test snapshot. Keep actual retention and its cold envelope in the test body.
        _prepareFiles(terms.environment.packageFiles, true);
        _prepareFiles(terms.environment.platformPrerequisites, false);
        bytes memory environmentBytes = StreamReferenceEnvironmentJson.manifest(terms.environment);
        _upload(environmentBytes);
        (, environmentPreparationGas) = _prepareBounded(
            abi.encodeCall(modes.prepareEnvironment, (terms.environment)), environmentBytes
        );
    }

    function _prepareFiles(StreamReferenceRenderTypes.PackageFile[] memory rows, bool relative)
        private
    {
        for (uint256 start; start < rows.length; start += 64) {
            uint256 count = rows.length - start;
            if (count > 64) count = 64;
            StreamReferenceRenderTypes.PackageFile[] memory part =
                new StreamReferenceRenderTypes.PackageFile[](count);
            for (uint256 i; i < count; ++i) {
                part[i] = rows[start + i];
            }
            bytes memory partBytes = bytes(StreamReferenceEnvironmentJson.files(part, relative));
            _upload(partBytes);
            (, uint256 used) = _prepareBounded(
                abi.encodeCall(modes.prepareFileInventoryPart, (part, relative)), partBytes
            );
            if (used > largestPartGas) largestPartGas = used;
        }
        bytes memory raw = bytes(StreamReferenceEnvironmentJson.files(rows, relative));
        (, uint256 used) = _prepareBounded(
            abi.encodeCall(modes.prepareFileInventoryFromParts, (rows, relative)), raw
        );
        if (used > largestInventoryGas) largestInventoryGas = used;
    }

    function _prepareBounded(bytes memory input, bytes memory raw)
        private
        returns (bytes32 id, uint256 total)
    {
        uint256 intrinsic = _intrinsic(input);
        for (uint256 i; i < (raw.length + 8191) / 8192; ++i) {
            (address pointer,) = store.chunk(keccak256(_part(raw, i)));
            safeVm.cool(pointer);
        }
        safeVm.cool(address(store));
        safeVm.cool(address(modes));
        uint256 before = gasleft();
        (bool ok, bytes memory returned) =
            address(modes).call{ gas: TX_CAP - intrinsic - 5000 }(input);
        total = before - gasleft() + intrinsic;
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        require(total <= TX_CAP);
        id = abi.decode(returned, (bytes32));
        require(keccak256(modes.preparedFileInventory(id)) == keccak256(raw));
        // Actual host, Store and these retained chunks are cooled. This does not claim a fresh
        // RPC transaction or that all transitive linked accounts and storage slots are cold.
    }

    function testActualHostStagedEnvironmentPreparationEnvelopes() public {
        _prepareEnvironment();
        require(largestPartGas != 0 && largestPartGas <= TX_CAP);
        require(largestInventoryGas != 0 && largestInventoryGas <= TX_CAP);
        require(environmentPreparationGas != 0 && environmentPreparationGas <= TX_CAP);
        emit log_named_uint("actualHostLargestPartWithIntrinsic", largestPartGas);
        emit log_named_uint("actualHostLargestInventoryWithIntrinsic", largestInventoryGas);
        emit log_named_uint(
            "actualHostEnvironmentPreparationWithIntrinsic", environmentPreparationGas
        );
    }

    function _combinedEnvironment() private {
        string memory json =
            vm.readFile("test/fixtures/preservation/reference-combined-native-v1.json");
        StreamReferenceRenderTypes.Environment memory env = terms.environment;
        (env.objectHash, env.coverageHash) = _loadObject(
            vm.readFile("test/fixtures/preservation/reference-combined-object-v1.json"), "", true
        );
        env.packageFiles = abi.decode(
            safeVm.parseJsonBytes(json, ".packageFilesABI"),
            (StreamReferenceRenderTypes.PackageFile[])
        );
        env.platformPrerequisites = abi.decode(
            safeVm.parseJsonBytes(json, ".platformPrerequisitesABI"),
            (StreamReferenceRenderTypes.PackageFile[])
        );
        require(env.packageFiles.length == 1048 && env.platformPrerequisites.length == 102);
        env.licenseNote = fixtureVm.parseJsonString(json, ".licenseNote");
        bytes memory raw = StreamReferenceEnvironmentJson.manifest(env);
        env.manifestHash = keccak256(raw);
        env.manifestBytes = uint32(raw.length);
        _upload(bytes(StreamReferenceEnvironmentJson.files(env.packageFiles, true)));
        _upload(bytes(StreamReferenceEnvironmentJson.files(env.platformPrerequisites, false)));
        terms.environment = env;
        terms.effectiveAt = CAPTURE_TIME;
        terms.referenceId = keccak256("actual combined browser and isolated metric reference");
        for (uint256 i; i < 2; ++i) {
            string memory prefix = i == 0 ? ".capture1" : ".capture2";
            bytes memory html = safeVm.parseJsonBytes(json, string.concat(prefix, ".html"));
            require(keccak256(html) == terms.captures[i].htmlHash);
            terms.captures[i].coverageHash =
                _refreshCaptureCoverage(json, prefix, terms.captures[i].objectHash);
            E.Coverage memory c = archiveHost.coverage(terms.captures[i].coverageHash);
            terms.captures[i].repeatCaptureSha256 = [c.sha256Digest, c.sha256Digest];
            terms.captures[i].environmentManifestHash = env.manifestHash;
            terms.captures[i].capturedAt = CAPTURE_TIME;
        }
    }

    function _refreshCaptureCoverage(string memory json, string memory prefix, bytes32 hash)
        private
        returns (bytes32)
    {
        // The repeated browser run produced the same PNG bytes. Reuse their exact original
        // immutable object; only the new checkpoint, signed receipts and fixity are new facts.
        E.ObjectIdentity memory expected = E.ObjectIdentity(
            keccak256("artist"),
            StreamReferenceRenderDefinitions.PNG_SCHEMA_ID,
            keccak256("RAW_BYTES"),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".contentHash"))),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".sha256Digest"))),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".arweaveDataRoot"))),
            uint64(fixtureVm.parseJsonUint(json, string.concat(prefix, ".byteSize"))),
            keccak256("IANA:image/png"),
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_ID,
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_HASH
        );
        archiveObject = archiveHost.objectIdentity(hash);
        require(keccak256(abi.encode(archiveObject)) == keccak256(abi.encode(expected)));
        archiveObjectHash = hash;
        archiveFirstPath = safeVm.parseJsonBytes(json, string.concat(prefix, ".firstDataPath"));
        archiveLastPath = safeVm.parseJsonBytes(json, string.concat(prefix, ".lastDataPath"));
        A.Checkpoint memory cp = _extCheckpointTerms();
        cp.transactionId = keccak256(abi.encode("actual reference object", hash));
        archiveTransactionId = cp.transactionId;
        archiveCheckpointHash = archiveVerifier.recordCheckpoint(
            cp,
            abi.encode(cp.dataRoot, uint256(cp.dataSize)),
            archiveFirstPath,
            archiveLastPath,
            _extCertificate(cp)
        );
        bytes32 first = _extRecordReceipt(true, uint256(hash));
        bytes32 second = _extRecordReceipt(false, uint256(hash));
        _extRecordFixity(first, 1, false);
        _extRecordFixity(second, 1, false);
        return archiveHost.recordCoverage(first, second);
    }

    function _extReceipt(bool first_, uint256 nonce)
        internal
        override
        returns (E.Receipt memory r, bytes memory id)
    {
        (r, id) = super._extReceipt(first_, nonce);
        if (refreshedReceipts) {
            r.nonce = uint256(keccak256(abi.encode("combined fixture receipt", nonce)));
            if (!first_) r.proofRecordHash = archiveHost.possessionHash(r);
        }
    }

    function _definitions() private {
        string[8] memory names = [
            "STREAM_SOLIDITY_ABI_V1",
            "STREAM_REFERENCE_MODE_ABI_V1",
            "STREAM_REFERENCE_MODE_PROFILE_V1",
            "STREAM_REFERENCE_MODE_ABI_V2",
            "STREAM_REFERENCE_CURATED_CONDITION_ABI_V1",
            "STREAM_REFERENCE_SIGNIFICANT_PROPERTIES_ABI_V1",
            "STREAM_REFERENCE_METRIC_SUPPLEMENT_ABI_V1",
            "STREAM_REFERENCE_METRIC_SUPPLEMENT_PROFILE_V1"
        ];
        for (uint256 i; i < names.length; ++i) {
            _snapshotDocument(
                names[i],
                i == 0
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : (i == 2 || i == 7)
                        ? IStreamSchemaRegistry.DocumentKind.CATALOG
                        : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                bytes(vm.readFile(string.concat("schemas/records/", names[i], ".json")))
            );
        }
    }

    function _metric() private {
        Mode.Metric memory metric = Mode.Metric(
            keccak256("STREAM_METRIC_SSIM_V1"),
            keccak256("STREAM_SSIM_RGB8_INTEGER_GAUSSIAN11_V1"),
            "6529Stream integer SSIM",
            "1.0.0",
            0xdf70cb98b947f970bd117c6e7343c1471c9059efa9e36a8248e33c0e59b51aff,
            0x1284b35afa316cb69d790a354cefdeb19d00a37116b1ec25e2ded88a1f59add3,
            1000000000
        );
        bytes memory raw = abi.encode(metric);
        bytes32[] memory chunks = _upload(raw);
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            "STREAM_METRIC_SSIM_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            keccak256(raw),
            D.CANON_ID,
            0,
            "",
            uint32(raw.length)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 next) =
            schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas),
            abi.encodeCall(schemas.registerDocument, (spec, chunks)),
            scope,
            oldHash,
            next
        );
        modeEvidence.mode = Mode.Mode.PERCEPTUAL_TOLERANCE;
        modeEvidence.perceptual.metric = metric;
        modeEvidence.perceptual.threshold = 990000000;
        modeEvidence.perceptual.evaluatedAt = CAPTURE_TIME;
        modeEvidence.perceptual.reportURI = "ipfs://retained-combined-metric-report";
        modeEvidence.perceptual.scores = new int64[](2);
        modeEvidence.repeats = new Mode.Repeat[](2);
        for (uint256 i; i < 2; ++i) {
            modeEvidence.perceptual.scores[i] = 1000000000;
            modeEvidence.repeats[i] =
                Mode.Repeat(terms.captures[i].objectHash, terms.captures[i].coverageHash);
        }
        modeEvidence.perceptual.reportHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PERCEPTUAL_REPORT_V1"),
                modes.modeContextHash(terms),
                metric,
                modeEvidence.perceptual.threshold,
                modeEvidence.perceptual.scores,
                modeEvidence.perceptual.evaluatedAt
            )
        );
    }

    function testCurrentOriginalAnchorMatchesLockedIdentityAndHistoricalRead() public {
        (address durable, bytes32 durableCode) = router.servingOriginalFinalityAnchor();
        (address locked, bytes32 lockedCode) = router.originalFinalityAnchor(1);
        require(durable == address(finality) && durableCode == address(finality).codehash);
        require(locked == durable && lockedCode == durableCode);
        require(
            keccak256(bytes(router.historicalTokenMetadataJSON(address(core), 1)))
                == terms.captures[0].metadataJSONHash
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.OriginalFinalityAnchorAlreadyInitialized.selector
            )
        );
        router.initializeOriginalFinalityAnchor();
    }

    function testRepeatedPngRetainsOriginalObjectAndFreshCoverage() public {
        for (uint256 i; i < terms.captures.length; ++i) {
            bytes32 hash = terms.captures[i].objectHash;
            E.Coverage memory fresh = archiveHost.requireCoverage(
                terms.captures[i].coverageHash, keccak256("artist"), hash
            );
            require(
                fresh.firstReceiptHash != originalFirstReceipts[i + 1]
                    && fresh.secondReceiptHash != originalSecondReceipts[i + 1]
            );
            (E.Receipt memory originalFirst,,) = archiveHost.receipt(originalFirstReceipts[i + 1]);
            (E.Receipt memory originalSecond,,) = archiveHost.receipt(originalSecondReceipts[i + 1]);
            require(originalFirst.objectHash == hash && originalSecond.objectHash == hash);
            (E.Receipt memory currentFirst,,) = archiveHost.receipt(fresh.firstReceiptHash);
            require(
                currentFirst.observedAt == FIXTURE_TIME && originalFirst.observedAt < FIXTURE_TIME
            );
            E.ObjectIdentity memory original = archiveHost.objectIdentity(hash);
            vm.expectRevert(abi.encodeWithSelector(A.ArchivalRecordExists.selector, hash));
            archiveHost.recordObject(original);
        }
    }

    function testDifferentLockedOriginalAnchorStillRejectsHistoricalRead() public {
        StreamMetadataRouter shadow = StreamMetadataRouter(
            _artistArtifactCreate(
                "StreamMetadataRouter.sol:StreamMetadataRouter",
                abi.encode(
                    address(core),
                    address(this),
                    keccak256("mismatch deployment"),
                    "ipfs://mismatch-fixture",
                    keccak256("mismatch manifest"),
                    IStreamArtistAttribution(address(artist))
                )
            )
        );
        shadow.initializeOriginalFinalityAnchor();
        RootFinalityBoundary changed = new RootFinalityBoundary(
            address(core), address(artist), address(metadata), provider, artifactTarget
        );
        artist.configure(address(shadow), address(changed));
        shadow.lockArtistIdentity(1);
        (address durable,) = shadow.servingOriginalFinalityAnchor();
        (address locked,) = shadow.originalFinalityAnchor(1);
        require(durable == address(finality) && locked == address(changed) && locked != durable);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRecoveryRoutes.MetadataRecoveryBindingInvalid.selector,
                address(changed)
            )
        );
        shadow.historicalTokenMetadataJSON(address(core), 1);
    }

    /// @dev First phase only. Exact original bytes are exported for B's restored offline command.
    /// This succeeds without a supplement and is NOT a finality acceptance test.
    function testExportExactCombinedMetricContext() public {
        bytes32 context = modes.modeContextHash(terms);
        metricVm.writeFileBinary("metric-phase-one/environment.abi", abi.encode(terms.environment));
        metricVm.writeFileBinary(
            "metric-phase-one/environment.json",
            StreamReferenceEnvironmentJson.manifest(terms.environment)
        );
        metricVm.writeFileBinary(
            "metric-phase-one/coverage.abi",
            abi.encode(archiveHost.coverage(terms.environment.coverageHash))
        );
        metricVm.writeFileBinary(
            "metric-phase-one/metric.abi", abi.encode(modeEvidence.perceptual.metric)
        );
        metricVm.writeFileBinary(
            "metric-phase-one/input-manifest.json",
            StreamReferenceMetricProof.inputManifest(terms, modeEvidence.perceptual, context)
        );
        metricVm.writeFileBinary(
            "metric-phase-one/context.abi",
            abi.encode(
                context,
                modeEvidence.perceptual.reportHash,
                address(modes),
                address(core),
                address(metadata),
                block.chainid
            )
        );
        require(
            keccak256(StreamReferenceEnvironmentJson.manifest(terms.environment))
                == terms.environment.manifestHash
        );
    }

    function _publish() private returns (bytes32 hash) {
        bytes memory canonical;
        (terms.expectedSourcesHash, canonical) =
            modes.previewModeReference(terms, modeEvidence, address(this));
        _upload(canonical);
        _upload(abi.encode(terms));
        _upload(abi.encode(modeEvidence));
        bytes memory input = abi.encodeCall(modes.publishModeReference, (terms, modeEvidence));
        uint256 intrinsic = _intrinsic(input);
        uint256 before = gasleft();
        (bool ok, bytes memory returned) =
            address(modes).call{ gas: TX_CAP - intrinsic - 5000 }(input);
        uint256 total = before - gasleft() + intrinsic;
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        require(total <= TX_CAP);
        hash = abi.decode(returned, (bytes32));
        emit log_named_uint("combinedModePublicationWithIntrinsic", total);
    }

    function _supplement() private view returns (Metric.Supplement memory s, bytes memory raw) {
        raw = metricVm.readFileBinary("test/fixtures/preservation/reference-metric-combined-v1.abi");
        s = abi.decode(raw, (Metric.Supplement));
        require(keccak256(abi.encode(s)) == keccak256(raw));
        require(s.replay.contextHash == modes.modeContextHash(terms));
        require(s.replay.reportHash == modeEvidence.perceptual.reportHash);
        require(
            s.runtime.environmentObjectHash == terms.environment.objectHash
                && s.runtime.environmentManifestHash == terms.environment.manifestHash
        );
    }

    function testFullSupplementAdmissionConsumerAndOriginalClassTwoLock() public {
        _prepareEnvironment();
        bytes32 hash = _publish();
        bytes32 originalPayload = keccak256(modes.referencePayload(hash));
        vm.expectRevert();
        consumer.read(_scope(), hash, 1, false);
        vm.expectRevert();
        modes.lockTransition(1);
        (Metric.Supplement memory s, bytes memory raw) = _supplement();
        _upload(raw);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamReferenceRenderTypes.ReferenceAuthority.selector, address(0x618899)
            )
        );
        vm.prank(address(0x618899));
        modes.publishMetricSupplement(hash, s);
        bytes32 supplementHash = modes.publishMetricSupplement(hash, s);
        vm.expectRevert(
            abi.encodeWithSelector(Metric.MetricSupplementAlreadyPublished.selector, hash)
        );
        modes.publishMetricSupplement(hash, s);
        (bytes memory saved, Metric.Receipt memory r) = modes.metricSupplement(hash);
        require(keccak256(saved) == keccak256(raw) && r.supplementHash == supplementHash);
        require(
            r.referenceRecordHash == hash && r.schemaHash == MD.SCHEMA_HASH
                && r.profileHash == MD.PROFILE_HASH
        );
        require(modes.requireMetricSupplement(hash).supplementHash == supplementHash);
        require(consumer.read(_scope(), hash, 1, false).payloadHash == originalPayload);
        (bytes32 scope, bytes32 oldHash, bytes32 next) = modes.lockTransition(1);
        cheat.mockCall(
            address(executor),
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
            abi.encode(true, keccak256("metric lock"), uint8(2), scope, oldHash, next)
        );
        vm.prank(address(executor));
        modes.lockReference(1);
        StreamFinalityReferenceEvidence memory accepted = consumer.read(_scope(), hash, 1, true);
        require(accepted.locked);
        bytes32 originalComponent = keccak256(
            abi.encode(
                keccak256("6529STREAM_LOCKED_REFERENCE_COMPONENT_V1"),
                block.chainid,
                address(modes),
                address(core),
                uint256(1),
                modes.currentReference(1),
                modes.referenceLock(1)
            )
        );
        bytes32 expectedComponent = keccak256(
            abi.encode(
                keccak256("6529STREAM_LOCKED_METRIC_REFERENCE_COMPONENT_V1"),
                originalComponent,
                supplementHash
            )
        );
        require(
            accepted.componentDataHash == expectedComponent
                && modes.finalityState(1).dataHash == expectedComponent
        );
        require(keccak256(modes.referencePayload(hash)) == originalPayload);
        vm.expectRevert();
        modes.publishMetricSupplement(hash, s);
    }

    function testMissingLastChunkSafeRollbackAndIdenticalAuthorizedRetry() public {
        _prepareEnvironment();
        bytes32 hash = _publish();
        (Metric.Supplement memory s, bytes memory raw) = _supplement();
        uint256 count = (raw.length + 8191) / 8192;
        for (uint256 i; i + 1 < count; ++i) {
            store.publishChunk(_part(raw, i));
        }
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x618821;
        keys[1] = 0x618822;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 891);
        _curator(address(account), 3, true);
        bytes memory callData = abi.encodeCall(modes.publishMetricSupplement, (hash, s));
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(modes), 0, callData, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(modes), 0, callData, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(account.nonce() == nonce);
        vm.expectRevert();
        modes.metricSupplement(hash);
        store.publishChunk(_part(raw, count - 1));
        require(
            account.execTransaction(
                address(modes), 0, callData, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            )
        );
        require(
            account.nonce() == nonce + 1
                && modes.requireMetricSupplement(hash).recorder == address(account)
        );
    }

    function testSupplementFinalBindingTransactionEnvelope() public {
        _prepareEnvironment();
        bytes32 hash = _publish();
        (Metric.Supplement memory s, bytes memory raw) = _supplement();
        bytes32[] memory chunks = _upload(raw);
        bytes memory input = abi.encodeCall(modes.publishMetricSupplement, (hash, s));
        uint256 intrinsic = _intrinsic(input);
        _cool();
        StreamReferenceRenderTypes.Dependencies memory d = modes.dependencies();
        for (uint256 i; i < 7; ++i) {
            safeVm.cool(d.targets[i]);
        }
        for (uint256 i; i < chunks.length; ++i) {
            (address pointer,) = store.chunk(chunks[i]);
            safeVm.cool(pointer);
        }
        // Looking up chunk pointers above warms the Store and its index slots again.
        safeVm.cool(address(store));
        safeVm.cool(address(modes));
        uint256 before = gasleft();
        (bool ok, bytes memory returned) =
            address(modes).call{ gas: TX_CAP - intrinsic - 5000 }(input);
        uint256 total = before - gasleft() + intrinsic;
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        require(total <= TX_CAP && abi.decode(returned, (bytes32)) != 0);
        emit log_named_uint("metricSupplementFinalBindingWithIntrinsic", total);
        // These accounts/chunks are explicitly cooled; this is not an RPC block or whole graph claim.
    }

    function testOriginalInventoryIncludesEverySupplementByteRole() public {
        _prepareEnvironment();
        bytes32 hash = _publish();
        (Metric.Supplement memory s, bytes memory raw) = _supplement();
        _upload(raw);
        bytes32 supplementHash = modes.publishMetricSupplement(hash, s);
        Critical.Dependencies memory d;
        d.targets[2] = address(schemas);
        d.codeHashes[2] = address(schemas).codehash;
        d.targets[3] = address(store);
        d.codeHashes[3] = address(store).codehash;
        d.targets[6] = address(modes);
        d.codeHashes[6] = address(modes).codehash;
        d.readGas = 1000000;
        d.referenceGas = 14000000;
        Critical.Context memory c;
        c.referenceRender = modes.currentReference(1);
        I.Item[] memory rows = new MetricPublicationInventoryProbe().items(d, c);
        require(rows.length == 22);
        require(
            rows[11].sourceRecord == supplementHash && bytes32(rows[11].digest) == keccak256(raw)
        );
        require(bytes32(rows[20].digest) == keccak256(s.replay.transcript));
        require(rows[20].byteSize == s.replay.transcript.length);
    }

    function _part(bytes memory raw, uint256 index) private pure returns (bytes memory out) {
        uint256 start = index * 8192;
        uint256 size = raw.length - start;
        if (size > 8192) size = 8192;
        out = new bytes(size);
        for (uint256 j; j < size; j += 32) {
            assembly ("memory-safe") {
                mstore(add(add(out, 32), j), mload(add(add(raw, 32), add(start, j))))
            }
        }
    }

    function _intrinsic(bytes memory input) private pure returns (uint256 result) {
        result = 21000;
        for (uint256 i; i < input.length; ++i) {
            result += input[i] == 0 ? 4 : 16;
        }
    }
}
