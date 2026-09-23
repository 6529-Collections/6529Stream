// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PolicySnapshotFixtureV2.sol";
import {
    StreamFinalityPolicyStaticComponentsV2 as Adapter
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicyStaticComponentsV2.sol";
import {
    StreamFinalityStaticComponentFacts as Facts
} from "../../../smart-contracts/domains/finality/StreamFinalityStaticComponentFacts.sol";
import {
    StreamFinalityPolicySnapshotReadsV2 as Snapshots
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicySnapshotReadsV2.sol";
import {
    StreamFinalityPolicyStaticSourceV2 as Projection
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicyStaticSourceV2.sol";
import {
    IStreamStaticMetadataRouter as RouterStatic
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as Renderer
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    StreamFinalityDomains
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

contract PolicyStaticComponentsProbeV2 {
    function facts(
        Snapshots.Dependencies calldata d,
        address router,
        bytes32 runtime,
        StreamFinalityScope calldata scope,
        bytes32 family
    ) external view returns (bool, bytes32) {
        return Adapter.facts(d, router, runtime, scope, family);
    }

    function direct(
        Facts.Config calldata c,
        Facts.AuthenticatedSelection calldata a,
        bytes32 family
    ) external view returns (bool, bytes32) {
        return Facts.facts(c, a, family);
    }
}

/// @notice Actual V2 Snapshot/Metadata grants/Store/Schema/membership and its class-2 lock;
/// Core/Artist, Router/root/output/source-set and indexed STATIC rows are explicit typed fixtures.
/// No actual combined-provider, renderer-admission or completed finality ceremony is asserted.
contract StreamFinalityPolicyStaticComponentsV2Test is PolicySnapshotFixtureV2 {
    PolicyStaticComponentsProbeV2 private probe;
    Snapshots.Dependencies private dependencies;
    Facts.Config private config;
    Facts.AuthenticatedSelection private authenticated;
    RouterStatic.RawSource private rawSource;
    RouterStatic.ConfigRecord private record;
    bytes32 private savedRecord;

    function _ready(bool lock_) private {
        _initializePolicySnapshot();
        RouterStatic.RawSource memory raw;
        raw.chainId = block.chainid;
        raw.configured = true;
        raw.name = "Typed STATIC source";
        raw.description = "Original bytes for the V2 adapter boundary";
        raw.script = "/* exact source */";
        raw.imageURI = "ipfs://bafkreigh2akiscaildcxgkc2o6ek7kpx3et467sqwyn3exuy7bm4kc47au";
        RouterStatic.ConfigRecord memory c;
        c.collectionId = 1;
        c.revision = 1;
        c.defaultRevision = 1;
        c.config.mode = Renderer.MetadataMode.ONCHAIN;
        c.config.frozen = true;
        c.config.renderer = address(route);
        c.selection.renderer = address(route);
        c.selection.rendererCodeHash = address(route).codehash;
        c.selection.registry = address(selected);
        c.selection.registryCodeHash = address(selected).codehash;
        c.selection.versionKey = keccak256("typed renderer version");
        c.selection.rendererId = keccak256("typed renderer");
        c.selection.rendererVersion = bytes32(uint256(1));
        c.selection.contextVersion = bytes32(uint256(1));
        c.selection.schemaHash = keccak256("typed renderer schema");
        c.selection.registrationHash = keccak256("typed registration");
        c.selection.readSetHash = keccak256("typed retained read set");
        c.sourceSnapshotHash =
            keccak256(abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), raw));
        c.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1"),
                address(core),
                address(route),
                c
            )
        );
        bytes32 root;
        for (uint256 i; i < selectionPlan.tokenCount; ++i) {
            Selection.TokenSelection memory row;
            row.tokenId = membership.scopeTokenAt(publication.scope, i);
            row.configRecordHash = c.recordHash;
            row.configHash = keccak256(abi.encode(c));
            row.sourceSnapshotHash = c.sourceSnapshotHash;
            row.rawSourceHash = keccak256(abi.encode(raw));
            row.selection = c.selection;
            bytes32 leaf = keccak256(
                abi.encode(
                    keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                    block.chainid,
                    address(core),
                    address(route),
                    row
                )
            );
            root = keccak256(
                abi.encode(keccak256("6529STREAM_STATIC_SELECTION_CHAIN_V1"), root, i, leaf)
            );
            svm.mockCall(
                address(selected),
                abi.encodeCall(Selection.selectionAt, (contentPlan.selectionId, i)),
                abi.encode(row)
            );
        }
        selectionPlan.selectionRoot = root;
        contentPlan.selectionHash = keccak256(abi.encode(selectionPlan));
        outputManifest.checkpointStateHash = keccak256(abi.encode(contentPlan));
        rootBinding.checkpointStateHash = outputManifest.checkpointStateHash;
        _refreshPlans();
        _refreshRoot();
        selected.set("requireCurrentCheckpoint(bytes32)", abi.encode(selectionPlan));
        route.set("metadataConfigRecord(bytes32)", abi.encode(c));
        route.set("staticRenderSourceForConfig(uint256,bytes32)", abi.encode(raw, c.config));
        rawSource = raw;
        record = c;
        savedRecord = _publishSnapshot();
        dependencies = Snapshots.Dependencies(
            address(core),
            address(metadata),
            address(host),
            address(core).codehash,
            address(metadata).codehash,
            address(host).codehash,
            block.chainid,
            1000000,
            6000000
        );
        config = Facts.Config(
            address(core),
            address(metadata),
            address(route),
            address(selected),
            address(core).codehash,
            address(metadata).codehash,
            address(route).codehash,
            address(selected).codehash,
            block.chainid,
            1000000,
            6000000
        );
        Scoped.Receipt memory receipt = host.currentSnapshot(publication.scope);
        authenticated = Facts.AuthenticatedSelection(
            publication.scope,
            receipt.profileHash,
            contentPlan.selectionId,
            selectionPlan.membershipHash,
            selectionPlan.selectionRoot,
            selectionPlan.tokenCount,
            keccak256("locked presentation")
        );
        probe = new PolicyStaticComponentsProbeV2();
        if (lock_) _lock();
    }

    function _lock() private {
        (bytes32 scope, bytes32 oldState, bytes32 next) = host.lockTransition(publication.scope);
        svm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("V2 component class2 lock"), uint8(2), scope, oldState, next)
        );
        vm.prank(address(executor));
        host.lockSnapshot(publication.scope);
        require(host.snapshotLock(publication.scope).recordHash == savedRecord);
    }

    function _facts(bytes32 family) private view returns (bool, bytes32) {
        return probe.facts(
            dependencies, address(route), address(route).codehash, publication.scope, family
        );
    }

    function testActualLockedSnapshotMapsAllSixFamiliesToExactIndependentProjection() public {
        _ready(true);
        bytes32[6] memory families = [
            StreamFinalityDomains.COMPONENT_RENDERER,
            StreamFinalityDomains.COMPONENT_RENDER_CONTEXT,
            StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE,
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE,
            StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST,
            StreamFinalityDomains.COMPONENT_METADATA_ROUTER
        ];
        for (uint256 i; i < families.length; ++i) {
            (bool frozen, bytes32 value) = _facts(families[i]);
            (bool directFrozen, bytes32 directValue) =
                probe.direct(config, authenticated, families[i]);
            require(frozen && directFrozen && value != 0 && value == directValue);
        }
    }

    function testCurrentSnapshotWithoutClassTwoLockRefusesThenIdenticalSourceSucceeds() public {
        _ready(false);
        require(host.requireCurrent(publication.scope, savedRecord, 1).recordHash == savedRecord);
        vm.expectRevert(abi.encodeWithSelector(Adapter.PolicyStaticSnapshotUnlocked.selector));
        probe.facts(
            dependencies,
            address(route),
            address(route).codehash,
            publication.scope,
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE
        );
        _lock();
        (bool frozen, bytes32 value) = _facts(StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
        require(
            frozen && value != 0
                && host.currentSnapshot(publication.scope).recordHash == savedRecord
        );
    }

    function testCurrentSelectionAndRawSourceDriftRefuseAndExactRestoreRetries() public {
        _ready(true);
        (, bytes32 expected) = _facts(StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
        Selection.Plan memory changed = selectionPlan;
        changed.selectionRoot = keccak256("foreign current selection");
        selected.set("requireCurrentCheckpoint(bytes32)", abi.encode(changed));
        vm.expectRevert(abi.encodeWithSelector(Facts.StaticComponentSource.selector));
        probe.facts(
            dependencies,
            address(route),
            address(route).codehash,
            publication.scope,
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE
        );
        selected.set("requireCurrentCheckpoint(bytes32)", abi.encode(selectionPlan));
        RouterStatic.RawSource memory raw = rawSource;
        raw.script = "different bytes";
        route.set("staticRenderSourceForConfig(uint256,bytes32)", abi.encode(raw, record.config));
        vm.expectRevert(abi.encodeWithSelector(Facts.StaticComponentSource.selector));
        probe.facts(
            dependencies,
            address(route),
            address(route).codehash,
            publication.scope,
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE
        );
        route.set(
            "staticRenderSourceForConfig(uint256,bytes32)", abi.encode(rawSource, record.config)
        );
        (, bytes32 restored) = _facts(StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
        require(
            restored == expected
                && host.currentSnapshot(publication.scope).recordHash == savedRecord
        );
    }

    function testWrongSnapshotPinAndForeignScopeCannotBecomeCollectionEvidence() public {
        _ready(true);
        Snapshots.Dependencies memory d = dependencies;
        d.snapshotsCodeHash = keccak256("foreign runtime");
        vm.expectRevert(abi.encodeWithSelector(Snapshots.InvalidPolicySnapshotEvidence.selector));
        probe.facts(
            d,
            address(route),
            address(route).codehash,
            publication.scope,
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE
        );
        StreamFinalityScope memory scope = publication.scope;
        scope.scopeType = StreamFinalityScopeType.RELEASE;
        scope.scopeId = keccak256("same collection different scope");
        vm.expectRevert();
        probe.facts(
            dependencies,
            address(route),
            address(route).codehash,
            scope,
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE
        );
        (, bytes32 expected) = _facts(StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
        require(expected != 0);
    }

    function testOriginalSnapshotPayloadCorruptionRefusesWithoutChangingSavedReceipt() public {
        _ready(true);
        bytes memory original = host.snapshotPayload(savedRecord);
        bytes memory malformed = abi.decode(abi.encode(original), (bytes));
        malformed[malformed.length - 1] = bytes1(uint8(malformed[malformed.length - 1]) ^ 1);
        svm.mockCall(
            address(host),
            abi.encodeCall(host.snapshotPayload, (savedRecord)),
            abi.encode(malformed)
        );
        vm.expectRevert(abi.encodeWithSelector(Projection.InvalidPolicyStaticSource.selector));
        probe.facts(
            dependencies,
            address(route),
            address(route).codehash,
            publication.scope,
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE
        );
        svm.mockCall(
            address(host), abi.encodeCall(host.snapshotPayload, (savedRecord)), abi.encode(original)
        );
        (bool frozen, bytes32 value) = _facts(StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
        require(
            frozen && value != 0 && host.snapshotLock(publication.scope).recordHash == savedRecord
        );
    }
}
