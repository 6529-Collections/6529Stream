// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./PreservationReferenceFixture.sol";
import {
    StreamReferenceModePublication
} from "../../../smart-contracts/domains/preservation/StreamReferenceModePublication.sol";
import {
    StreamReferenceModeTypes as Mode
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceModeDefinitions as Def
} from "../../../smart-contracts/domains/records/StreamReferenceModeDefinitions.sol";
import {
    StreamReferenceModeInventory
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeInventory.sol";
import {
    StreamRenderCriticalSourceTypes as Critical
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

contract ReferenceModeInventoryProbe {
    function items(Critical.Dependencies memory d, Critical.Context memory c)
        external
        view
        returns (Inventory.Item[] memory)
    {
        (, Inventory.Item[] memory rows) = StreamReferenceModeInventory.stage(d, c, 2);
        return rows;
    }
}

/// @notice Actual publication/schema/archive/threshold Safe and typed finality consumer.
/// @dev Inherited Core/Artist/governance/network assertions are explicit boundaries; metric scores
/// are test-recorder assertions, not a claim that a browser or SSIM ran inside Ethereum.
contract StreamReferenceModePublicationTest is PreservationReferenceFixture {
    StreamReferenceModePublication private modes;
    Mode.Evidence private proof;
    PreservationReferenceConsumer private consumer;

    function setUp() public override {
        super.setUp();
        _snapshotDocument(
            "STREAM_SOLIDITY_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(Def.CANON_DOCUMENT)
        );
        _snapshotDocument(
            "STREAM_REFERENCE_MODE_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(Def.SCHEMA_DOCUMENT)
        );
        _snapshotDocument(
            "STREAM_REFERENCE_MODE_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(Def.PROFILE_DOCUMENT)
        );
        _snapshotDocument(
            "STREAM_REFERENCE_MODE_ABI_V2",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(Def.DECODE_DOCUMENT)
        );
        _snapshotDocument(
            "STREAM_REFERENCE_CURATED_CONDITION_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(Def.CONDITION_DOCUMENT)
        );
        _snapshotDocument(
            "STREAM_REFERENCE_SIGNIFICANT_PROPERTIES_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(Def.PROPERTIES_DOCUMENT)
        );
        StreamReferenceRenderTypes.Dependencies memory d = referenceHost.dependencies();
        IStreamGasParameterHost.GasParameterConfig[4] memory configs;
        configs[0] = _gas("REFERENCE_READ_GAS", d.readGas, 1);
        configs[1] = _gas("REFERENCE_SOURCE_GAS", d.sourceGas, 1);
        configs[2] = _gas("REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 1);
        configs[3] = _gas("REFERENCE_ARCHIVE_GAS", d.archiveGas, 1);
        Mode.Dependencies memory empty;
        modes = new StreamReferenceModePublication(d, address(executor), configs, empty);
        modes.prepareFileInventory(terms.environment.packageFiles, true);
        modes.prepareFileInventory(terms.environment.platformPrerequisites, false);
        Mode.Metric memory metric = Mode.Metric(
            keccak256("STREAM_METRIC_SSIM_V1"),
            keccak256("SSIM_RGB8_GAUSSIAN_11_V1"),
            "6529Stream SSIM",
            "1",
            keccak256("fixture implementation"),
            keccak256("fixture exact parameters"),
            1000000000
        );
        bytes memory raw = abi.encode(metric);
        bytes32[] memory chunks = _upload(raw);
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            "STREAM_METRIC_SSIM_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            keccak256(raw),
            Def.CANON_ID,
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
        proof.mode = Mode.Mode.PERCEPTUAL_TOLERANCE;
        proof.repeats = new Mode.Repeat[](terms.captures.length);
        proof.perceptual.metric = metric;
        proof.perceptual.threshold = 990000000;
        proof.perceptual.scores = new int64[](terms.captures.length);
        proof.perceptual.reportURI = "ipfs://fixture-measured-report";
        proof.perceptual.evaluatedAt = terms.effectiveAt;
        for (uint256 i; i < terms.captures.length; ++i) {
            proof.repeats[i] =
                Mode.Repeat(terms.captures[i].objectHash, terms.captures[i].coverageHash);
            proof.perceptual.scores[i] = 1000000000;
        }
        _report();
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

    function _report() private {
        proof.perceptual.reportHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PERCEPTUAL_REPORT_V1"),
                modes.modeContextHash(terms),
                proof.perceptual.metric,
                proof.perceptual.threshold,
                proof.perceptual.scores,
                proof.perceptual.evaluatedAt
            )
        );
    }

    function _prepared(address actor) private returns (bytes memory input) {
        bytes memory canonical;
        (terms.expectedSourcesHash, canonical) = modes.previewModeReference(terms, proof, actor);
        _upload(canonical);
        _upload(abi.encode(terms));
        _upload(abi.encode(proof));
        input = abi.encodeCall(modes.publishModeReference, (terms, proof));
    }

    function _publishMode() private returns (bytes32 hash) {
        _prepared(address(this));
        return modes.publishModeReference(terms, proof);
    }

    function testActualModePublicationCurrentConsumerAndExactClassTwoLock() public {
        bytes32 hash = _publishMode();
        StreamReferenceRenderTypes.Receipt memory r = modes.currentReference(1);
        require(
            r.recordHash == hash && r.schemaHash == Def.SCHEMA_HASH
                && r.profileHash == Def.PROFILE_HASH
        );
        require(consumer.read(_scope(), hash, 1, false).payloadHash == r.payloadHash);
        vm.expectRevert();
        consumer.read(_scope(), hash, 1, true);
        (bytes32 scope, bytes32 oldHash, bytes32 next) = modes.lockTransition(1);
        cheat.mockCall(
            address(executor),
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
            abi.encode(true, keccak256("mode lock"), uint8(2), scope, oldHash, next)
        );
        vm.prank(address(executor));
        modes.lockReference(1);
        require(consumer.read(_scope(), hash, 1, true).locked);
        (Mode.Evidence memory saved, Mode.Facts memory facts) = modes.referenceModeEvidence(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(proof))
                && facts.evidenceHash == keccak256(abi.encode(proof))
        );
        vm.expectRevert();
        modes.publishReference(terms);
    }

    function testUnregisteredChangedMetricThresholdAndReportRefuse() public {
        Mode.Evidence memory changed = proof;
        changed.perceptual.metric.metricId = keccak256("unregistered metric");
        vm.expectRevert();
        modes.previewModeReference(terms, changed, address(this));
        changed = proof;
        changed.perceptual.metric.version = "substituted";
        vm.expectRevert();
        modes.previewModeReference(terms, changed, address(this));
        changed = proof;
        changed.perceptual.scores[0] = 980000000;
        vm.expectRevert();
        modes.previewModeReference(terms, changed, address(this));
        changed = proof;
        changed.perceptual.reportHash = keccak256("invented report");
        vm.expectRevert();
        modes.previewModeReference(terms, changed, address(this));
        require(modes.referenceCount(1) == 0);
    }

    function testNonExactSecondCaptureNeedsExactOriginalCoverageAndLegacyRemainsExact() public {
        require(terms.captures.length == 2);
        terms.captures[0].repeatCaptureSha256[1] = terms.captures[1].repeatCaptureSha256[0];
        _report();
        vm.expectRevert();
        modes.previewModeReference(terms, proof, address(this));
        proof.repeats[0] = Mode.Repeat(terms.captures[1].objectHash, terms.captures[1].coverageHash);
        _report();
        _publishMode();
        vm.expectRevert();
        referenceHost.previewReference(terms, address(this));
    }

    function testModeIsNotASetterForExistingByteExactRecord() public {
        bytes32 exact = _referencePublish(address(this));
        require(
            referenceHost.currentReference(1).profileHash
                == StreamReferenceRenderDefinitions.PROFILE_HASH
        );
        vm.expectRevert();
        modes.referenceMode(exact);
        _publishMode();
        require(referenceHost.currentReference(1).recordHash == exact);
    }

    function testModeInventoryRetainsCompleteRegisteredDefinitionsAndMetric() public {
        bytes32 hash = _publishMode();
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
        ReferenceModeInventoryProbe probe = new ReferenceModeInventoryProbe();
        Inventory.Item[] memory rows = probe.items(d, c);
        require(
            rows.length == 8 && bytes32(rows[0].digest) == Def.SCHEMA_HASH
                && rows[0].byteSize == Def.SCHEMA_BYTES
        );
        require(bytes32(rows[6].digest) == keccak256(abi.encode(proof.perceptual.metric)));
        require(rows[5].sourceRecord == hash);
        bytes memory code = address(store).code;
        vm.etch(address(store), hex"fe");
        vm.expectRevert();
        probe.items(d, c);
        vm.etch(address(store), code);
        require(bytes32(probe.items(d, c)[0].digest) == Def.SCHEMA_HASH);
    }

    function testSafeLateArchiveFailureRollsBackAndRetriesIdenticalPublication() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x45291;
        keys[1] = 0x45292;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 773);
        _curator(address(account), 3, true);
        bytes memory input = _prepared(address(account));
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            address(modes), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        bytes memory code = address(archiveHost).code;
        vm.etch(address(archiveHost), hex"fe");
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(modes), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(account.nonce() == nonce && modes.referenceCount(1) == 0);
        vm.etch(address(archiveHost), code);
        require(
            account.execTransaction(
                address(modes), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            )
        );
        require(
            account.nonce() == nonce + 1 && modes.currentReference(1).recorder == address(account)
        );
    }
}
