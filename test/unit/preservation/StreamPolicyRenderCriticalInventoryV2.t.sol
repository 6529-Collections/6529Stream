// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ScopeMembershipPublicationFixture.sol";
import {
    StreamPolicyRenderCriticalInventoryV2 as Inventory
} from "../../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalInventoryV2.sol";
import {
    StreamPolicyRenderCriticalSourceReadsV2 as Sources
} from "../../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamPolicyRenderCriticalStateV2 as State
} from "../../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamPolicyRenderCriticalDefinitionStagesV2 as Definitions
} from "../../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalDefinitionStagesV2.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as Context
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamRenderCriticalSourceTypes as Dependencies
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPolicySnapshotTypesV2 as Snapshot
} from "../../../smart-contracts/interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    StreamPolicyReferenceTypesV2 as Reference
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPolicyReferenceTypesV2.sol";
import {
    StreamPreservationInventoryTypes as Item
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "../../../smart-contracts/domains/preservation/StreamPreservationDocumentReads.sol";
import {
    StreamBundleArchiveCoverage as Bundle
} from "../../../smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol";
import {
    StreamBundleArchiveTypes as BundleTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";

import {
    StreamPolicyRenderCriticalTokenReadsV2 as Tokens
} from "../../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalTokenReadsV2.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPolicyContentCheckpointV2 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamStaticMetadataRouter as Router
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as Renderer
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Policy
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";

interface PolicyInventoryVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @dev Exact static transport fixture, never a current snapshot/reference producer.
contract PolicyInventoryBindingBoundary {
    mapping(bytes4 => bytes) private responses;

    function set(bytes4 selector, bytes memory value) external {
        responses[selector] = value;
    }

    fallback() external {
        bytes memory value = responses[msg.sig];
        require(value.length != 0, "unconfigured exact read");
        assembly ("memory-safe") { return(add(value, 32), mload(value)) }
    }
}

/// @dev Isolated host-owned state oracle. It seeds no accepted inventory or finality authority.
contract PolicyInventoryStateProbe {
    State.State private state;

    constructor(Dependencies.Dependencies memory d) {
        state.records.dependencies = d;
        state.records.dependencyHash = keccak256(abi.encode(d));
    }

    function bindings() external view {
        Sources.bindings(state.records.dependencies);
    }

    function contextId(Context.Context memory c) external view returns (bytes32) {
        return State.planId(state, c);
    }

    function append(bytes32 id, Item.Item[] memory rows, bytes32 witness) external {
        State.append(state, id, rows, witness);
    }

    function currentDocuments(bytes32 id, bool full) external view {
        State.requireDocuments(state, id, full);
    }

    function counts(bytes32 id) external view returns (uint256, uint64, uint64) {
        return (
            state.records.documents[id].length,
            state.records.plans[id].segmentCount,
            state.records.plans[id].itemCount
        );
    }

    function segment(bytes32 id, uint64 ordinal) external view returns (Item.Segment memory) {
        return state.records.segments[id][ordinal];
    }
}

/// @notice Actual Schema/Store document retention plus independent domains and ABI boundaries.
/// @dev Snapshot/reference/Artist/source bindings below are explicit typed fixtures. Full current
/// inventory materialization, token stages, provider/finality and archive coverage are separate tests.
contract StreamPolicyRenderCriticalInventoryV2Test is ScopeMembershipPublicationFixture {
    Dependencies.Dependencies private d;
    PolicyInventoryBindingBoundary private common;
    PolicyInventoryBindingBoundary private snapshot;
    PolicyInventoryBindingBoundary private reference_;
    Snapshot.Dependencies private sd;
    Reference.Dependencies private rd;
    PolicyInventoryStateProbe private probe;

    function _boundInventory() private {
        common = new PolicyInventoryBindingBoundary();
        snapshot = new PolicyInventoryBindingBoundary();
        reference_ = new PolicyInventoryBindingBoundary();
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(common);
        }
        d.targets[0] = address(core);
        d.targets[1] = address(metadata);
        d.targets[2] = address(schemas);
        d.targets[3] = address(store);
        d.targets[5] = address(snapshot);
        d.targets[6] = address(reference_);
        for (uint256 i; i < 12; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            d.artistTargets[i] = address(common);
            d.artistCodeHashes[i] = address(common).codehash;
        }
        d.artistContentOwner = address(common);
        d.artistContentOwnerCodeHash = address(common).codehash;
        d.chainId = block.chainid;
        d.readGas = 1000000;
        d.sourceGas = 2000000;
        d.selectionGas = 2000000;
        d.snapshotGas = 2000000;
        d.referenceGas = 2000000;
        common.set(bytes4(keccak256("core()")), abi.encode(address(core)));
        reference_.set(bytes4(keccak256("archiveCoverage()")), abi.encode(address(common)));
        for (uint256 i; i < 11; ++i) {
            sd.targets[i] = address(common);
            sd.codeHashes[i] = address(common).codehash;
        }
        for (uint256 i; i < 7; ++i) {
            rd.targets[i] = address(common);
            rd.codeHashes[i] = address(common).codehash;
        }
        for (uint256 i; i < 5; ++i) {
            sd.targets[i] = d.targets[i];
            sd.codeHashes[i] = d.codeHashes[i];
            rd.targets[i] = d.targets[i];
            rd.codeHashes[i] = d.codeHashes[i];
        }
        rd.targets[5] = address(snapshot);
        rd.codeHashes[5] = address(snapshot).codehash;
        sd.chainId = block.chainid;
        rd.chainId = block.chainid;
        snapshot.set(bytes4(keccak256("dependencies()")), abi.encode(sd));
        reference_.set(bytes4(keccak256("dependencies()")), abi.encode(rd));
        probe = new PolicyInventoryStateProbe(d);
    }

    function testNewDependencyShapesAndLegacyReceiptTransportCannotSubstitute() public {
        _boundInventory();
        probe.bindings();
        require(
            abi.encode(sd).length == 832 && abi.encode(rd).length == 608
                && abi.encode(d).length == 1344,
            "literal new dependency sizes"
        );
        snapshot.set(bytes4(keccak256("dependencies()")), new bytes(736));
        vm.expectRevert();
        probe.bindings();
        snapshot.set(bytes4(keccak256("dependencies()")), abi.encode(sd));
        probe.bindings();
    }

    function testForeignReferenceSnapshotAndCoverageBindingsFailClosed() public {
        _boundInventory();
        rd.targets[5] = address(common);
        rd.codeHashes[5] = address(common).codehash;
        reference_.set(bytes4(keccak256("dependencies()")), abi.encode(rd));
        vm.expectRevert(abi.encodeWithSelector(Item.InventorySourceChanged.selector));
        probe.bindings();
        rd.targets[5] = address(snapshot);
        rd.codeHashes[5] = address(snapshot).codehash;
        reference_.set(bytes4(keccak256("dependencies()")), abi.encode(rd));
        reference_.set(bytes4(keccak256("archiveCoverage()")), abi.encode(address(snapshot)));
        vm.expectRevert(abi.encodeWithSelector(Item.InventorySourceChanged.selector));
        probe.bindings();
        reference_.set(bytes4(keccak256("archiveCoverage()")), abi.encode(address(common)));
        probe.bindings();
    }

    function testDependencyRuntimeRestorationPreservesExactAdmission() public {
        _boundInventory();
        bytes memory original = address(common).code;
        vm.etch(address(common), hex"00");
        vm.expectRevert();
        probe.bindings();
        vm.etch(address(common), original);
        probe.bindings();
    }

    function testNewPlanDomainBindsBothV2ReceiptsAndOriginalSlotsStayZero() public {
        _boundInventory();
        Context.Context memory c;
        c.records.collectionId = 1;
        c.records.subject = keccak256("scope");
        c.snapshot.recordHash = keccak256("snapshotV2");
        c.referenceRender.observation.recordHash = keccak256("referenceV2");
        bytes32 original = probe.contextId(c);
        require(
            original
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_RENDER_CRITICAL_PLAN_V2"),
                        block.chainid,
                        address(probe),
                        keccak256(abi.encode(d)),
                        c
                    )
                ),
            "independent full context preimage"
        );
        require(
            c.records.snapshot.recordHash == 0 && c.records.referenceRender.recordHash == 0,
            "no original receipt cast"
        );
        c.referenceRender.observation.recordHash = keccak256("other V2 reference");
        require(probe.contextId(c) != original);
        c.referenceRender.observation.recordHash = keccak256("referenceV2");
        c.snapshot.recordHash = keccak256("other V2 snapshot");
        require(probe.contextId(c) != original);
    }

    function testCompleteDefinitionRosterExcludesOldSnapshotReferenceRoot() public {
        bytes32[31] memory ids;
        for (uint64 i; i < 31; ++i) {
            bytes32 hash;
            (ids[i], hash) = Definitions.definition(i);
            require(ids[i] != 0 && hash != 0);
            for (uint64 j; j < i; ++j) {
                require(ids[i] != ids[j], "complete roster has no repeated definition");
            }
            require(
                ids[i] != keccak256("STREAM_NATIVE_ONCHAIN_SNAPSHOT_V1")
                    && ids[i] != keccak256("STREAM_NATIVE_REFERENCE_RENDER_V1")
                    && ids[i] != keccak256("STREAM_TOKEN_CONTENT_ROOT_RECORD_V1"),
                "no original profile promotion"
            );
        }
        require(
            ids[20] == keccak256("STREAM_POLICY_COLLECTION_SNAPSHOT_ABI_V2")
                && ids[23] == keccak256("STREAM_POLICY_COLLECTION_REFERENCE_ABI_V2")
                && ids[29] == keccak256("STREAM_POLICY_CONTENT_ROOT_RECORD_V2")
        );
        vm.expectRevert(abi.encodeWithSelector(Item.InvalidInventoryItem.selector));
        Definitions.definition(31);
    }

    function _rows() private view returns (Item.Item[] memory rows) {
        rows = new Item.Item[](1);
        rows[0] = Documents.item(d, schemas.RAW_BYTES(), 0);
    }

    function testActualDocumentPinDeduplicatesButEveryOrderedOccurrenceRemains() public {
        _boundInventory();
        bytes32 id = keccak256("plan");
        Item.Item[] memory rows = _rows();
        bytes32 witness = keccak256("original witness");
        probe.append(id, rows, witness);
        probe.append(id, rows, witness);
        (uint256 documents, uint64 segments, uint64 items) = probe.counts(id);
        require(documents == 1 && segments == 2 && items == 2);
        Item.Segment memory first = probe.segment(id, 0);
        Item.Segment memory second = probe.segment(id, 1);
        require(
            first.key
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDER_CRITICAL_SEGMENT_V1"), id, uint64(0)
                        )
                    ) && first.key != second.key
        );
        bytes32 itemHash =
            keccak256(abi.encode(keccak256("6529STREAM_PRESERVATION_ITEM_V1"), rows[0]));
        require(
            first.firstLink
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_ITEM_LINK_V1"),
                        first.key,
                        uint64(1),
                        uint64(0),
                        itemHash,
                        bytes32(0)
                    )
                ),
            "literal original archive link vocabulary"
        );
        probe.currentDocuments(id, false);
        probe.currentDocuments(id, true);
    }

    function testActualCatalogDeprecationStalesCurrentFactsWithoutErasingHistory() public {
        _boundInventory();
        bytes32 id = keccak256("plan");
        probe.append(id, _rows(), keccak256("witness"));
        bytes32 saved = keccak256(abi.encode(probe.segment(id, 0)));
        (bytes32 scope, bytes32 previous, bytes32 next) = schemas.statusTransition(
            schemas.RAW_BYTES(), IStreamSchemaRegistry.DocumentStatus.DEPRECATED
        );
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus,
                (schemas.RAW_BYTES(), IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            scope,
            previous,
            next
        );
        vm.expectRevert(abi.encodeWithSelector(Item.InvalidInventoryItem.selector));
        probe.currentDocuments(id, false);
        require(
            keccak256(abi.encode(probe.segment(id, 0))) == saved,
            "immutable prior segment remains retrievable"
        );
    }

    function testForgedDocumentSizeRollsBackAllStateAndExactBytesRetry() public {
        _boundInventory();
        bytes32 id = keccak256("plan");
        Item.Item[] memory rows = _rows();
        ++rows[0].byteSize;
        vm.expectRevert(abi.encodeWithSelector(Item.InventorySourceChanged.selector));
        probe.append(id, rows, keccak256("witness"));
        (uint256 docs, uint64 segments, uint64 items) = probe.counts(id);
        require(docs == 0 && segments == 0 && items == 0);
        probe.append(id, _rows(), keccak256("witness"));
        probe.currentDocuments(id, true);
    }

    function testFreshGenericBundleConfigurationPinsExactV2Inventory() public {
        _boundInventory();
        Inventory inventoryV2 = new Inventory(d);
        require(
            inventoryV2.policyInventoryProfile()
                == keccak256("6529STREAM_POLICY_COLLECTION_RENDER_CRITICAL_V2")
        );
        require(
            inventoryV2.snapshots() == address(snapshot)
                && inventoryV2.referencePublisher() == address(reference_)
        );
        require(keccak256(abi.encode(inventoryV2.dependencies())) == keccak256(abi.encode(d)));
        BundleTypes.Dependencies memory b;
        b.targets = [
            address(core),
            address(metadata),
            address(inventoryV2),
            address(common),
            address(common),
            address(common)
        ];
        for (uint256 i; i < 6; ++i) {
            b.codeHashes[i] = b.targets[i].codehash;
        }
        b.chainId = block.chainid;
        b.readGas = 1000000;
        b.archiveGas = 2000000;
        Bundle bundle = new Bundle(b);
        require(
            bundle.renderCriticalInventory() == address(inventoryV2)
                && bundle.inventoryCodeHash() == address(inventoryV2).codehash
                && bundle.metadataHost() == address(metadata)
        );
        // Constructor reciprocity is not completed coverage; an unknown plan cannot be read.
        vm.expectRevert();
        bundle.requireCoverage(bytes32(uint256(1)), keccak256("not an accepted V2 evidence"));
    }

    function testTokenSourceUsesLiteralProducerStaticFactsNotDynamicCarrier() public {
        _boundInventory();
        uint256 token = _tokens(1)[0];
        Context.Context memory c;
        c.records.tokenCount = 1;
        c.records.checkpointHash = keccak256("current checkpoint");
        c.source.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        c.source.content.selectionId = keccak256("selection");
        c.source.content.inventoryHash = keccak256("complete source inventory");
        c.source.content.policyChainHash = keccak256("full policy chain");
        Router.RawSource memory rawSource;
        rawSource.chainId = block.chainid;
        rawSource.configured = true;
        rawSource.name = "retained original source";
        Router.ConfigRecord memory config;
        config.collectionId = 1;
        config.revision = 1;
        config.config.frozen = true;
        config.config.mode = Renderer.MetadataMode.ONCHAIN;
        config.sourceSnapshotHash =
            keccak256(abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), rawSource));
        config.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1"),
                address(core),
                address(common),
                config
            )
        );
        Selection.TokenSelection memory row;
        row.tokenId = token;
        row.configRecordHash = config.recordHash;
        row.configHash = keccak256(abi.encode(config));
        row.sourceSnapshotHash = config.sourceSnapshotHash;
        row.rawSourceHash = keccak256(abi.encode(rawSource));
        row.selection = config.selection;
        row.sources[3] = address(common);
        row.sourceCodeHashes[3] = address(common).codehash;
        Policy.TokenReadiness memory facts = Policy.TokenReadiness(
            address(common),
            address(common).codehash,
            keccak256("complete H"),
            5,
            2,
            0,
            0,
            false,
            true,
            keccak256("seed")
        );
        Content.Output memory output;
        output.leaf.tokenId = token;
        output.entropy = facts;
        output.selectionRowHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                block.chainid,
                address(core),
                address(common),
                row
            )
        );
        // This is the producer's literal static tuple, independent of the retained byte carrier.
        bytes memory preimage = abi.encode(
            keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2"),
            row.configHash,
            row.rawSourceHash,
            address(common),
            facts,
            address(common),
            address(common).codehash,
            c.source.content.inventoryHash,
            c.source.content.policyChainHash,
            address(common),
            address(common).codehash,
            bytes32(0)
        );
        require(preimage.length == 21 * 32, "ten static policy words in producer preimage");
        output.sourceFactsHash = keccak256(preimage);
        common.set(
            bytes4(keccak256("scopeTokenAt((uint8,uint256,uint256,bytes32),uint256)")),
            abi.encode(token)
        );
        common.set(Selection.selectionAt.selector, abi.encode(row));
        common.set(Content.outputAt.selector, abi.encode(output));
        common.set(Policy.tokenEntropyReadiness.selector, abi.encode(facts));
        common.set(Content.terminalReadiness.selector, abi.encode(address(common)));
        common.set(
            bytes4(keccak256("staticTokenRenderFacts(uint256)")),
            abi.encode(uint8(5), facts.seed, address(common))
        );
        common.set(Router.metadataConfigRecord.selector, abi.encode(config));
        common.set(
            Router.staticRenderSourceForConfig.selector, abi.encode(rawSource, config.config)
        );
        PolicyInventoryVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeWithSignature("coordinatorAtMint(uint256)", token),
                abi.encode(address(common))
            );
        (uint256 actual, Tokens.Original memory observed) = Tokens.sourceAt(d, c, 0);
        require(
            actual == token && token == 3
                && keccak256(observed.entropy) == keccak256(abi.encode(facts)),
            "actual ordinal and full retained facts"
        );
        bytes32 original = output.sourceFactsHash;
        output.sourceFactsHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2"),
                row.configHash,
                row.rawSourceHash,
                address(common),
                abi.encode(facts),
                address(common),
                address(common).codehash,
                c.source.content.inventoryHash,
                c.source.content.policyChainHash,
                address(common),
                address(common).codehash,
                bytes32(0)
            )
        );
        require(output.sourceFactsHash != original, "dynamic carrier changes original preimage");
        common.set(Content.outputAt.selector, abi.encode(output));
        vm.expectRevert(abi.encodeWithSelector(Item.InvalidInventoryItem.selector));
        Tokens.sourceAt(d, c, 0);
        output.sourceFactsHash = original;
        common.set(Content.outputAt.selector, abi.encode(output));
        Tokens.sourceAt(d, c, 0);
    }
}
