// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamPreservationInventoryTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamRenderCriticalSourceTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    IStreamArtworkFinalityComponent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import "../../../smart-contracts/domains/records/StreamPolicySnapshotDefinitionsV2.sol";
import "../../../smart-contracts/domains/records/StreamPolicyReferenceDefinitionsV2.sol";
import {
    StreamPolicyOutputSchemasV2 as OutputDefinitions
} from "../../../smart-contracts/domains/finality/StreamPolicyOutputSchemasV2.sol";
import {
    StreamPolicySnapshotDefinitionsV2 as SnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamPolicySnapshotDefinitionsV2.sol";
import {
    StreamPolicyReferenceDefinitionsV2 as ReferenceDefinitions
} from "../../../smart-contracts/domains/records/StreamPolicyReferenceDefinitionsV2.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityPolicyProviderOperationsV2.sol";
import {
    StreamFinalityPolicyProviderReadsV2 as P
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicyProviderReadsV2.sol";
import {
    StreamFinalityNativeProviderReads as N
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityPolicyInputManifestTypesV2 as M
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityPolicyInputManifestTypesV2.sol";
import {
    StreamPolicySnapshotTypesV2 as S
} from "../../../smart-contracts/interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    StreamPolicyReferenceTypesV2 as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPolicyReferenceTypesV2.sol";
import {
    IStreamPolicyContentRootPublicationV2 as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";

/// @dev Exact native tuple source boundary; no counterfeit actual producer or accepted inventory claim.
contract PolicyProviderTableV2 {
    mapping(bytes4 => bytes) private rows;

    function set(string calldata signature, bytes calldata value) external {
        rows[bytes4(keccak256(bytes(signature)))] = value;
    }

    fallback() external {
        bytes memory value = rows[msg.sig];
        require(value.length != 0, "missing original read");
        assembly ("memory-safe") { return(add(value, 32), mload(value)) }
    }
}

contract PolicyProviderProjectionProbeV2 {
    N.Config private config;
    address public immutable policyOutputManifestV2;
    bytes32 public immutable policyOutputManifestV2CodeHash;

    constructor(address output) {
        policyOutputManifestV2 = output;
        policyOutputManifestV2CodeHash = output.codehash;
    }

    function initialize(N.Config calldata c) external {
        require(config.chainId == 0);
        config = c;
    }

    function statement(StreamFinalityScope calldata scope)
        external
        view
        returns (M.Statement memory)
    {
        return P.statement(config, scope, new StreamFinalityComponentExpectation[](0));
    }

    function prepared(StreamFinalityScope calldata scope) external view {
        StreamFinalityComponentExpectation[] memory empty =
            new StreamFinalityComponentExpectation[](0);
        this.preparedRows(scope, empty);
    }

    function preparedRows(
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata rows
    ) external view {
        StreamFinalityPolicyProviderOperationsV2.prepared(
                config, scope, bytes32(uint256(1)), rows, false
            );
    }

    function requireCurrentRouterCandidate(uint256 cid, address registry) external view {
        require(msg.sender == address(this) && cid == 1 && registry == config.targets[12]);
    }
}

/// @notice Source/interface substitution oracles for the exact V2 provider worker.
/// @dev All original facts are typed read tables. Actual Snapshot/reference and dual component
/// entries have their own actual-product tests; these controls do not prove producer admission,
/// complete inventory, Discovery, registry ceremony, or any gas-cap acceptance.
contract StreamFinalityPolicyProviderReadsV2Test is CharacterizationTestBase {
    N.Config private c;
    PolicyProviderTableV2[22] private tables;
    PolicyProviderTableV2 private selection;
    PolicyProviderTableV2 private checkpoint;
    PolicyProviderTableV2 private output;
    PolicyProviderTableV2 private sourceSet;
    PolicyProviderTableV2 private coordinatorInventory;
    PolicyProviderProjectionProbeV2 private probe;
    S.Dependencies private sd;
    StreamFinalityCoordinatorPolicyReadsV2.Dependencies private fd;
    StreamPreservationInventoryTypes.Evidence private evidence;
    StreamPreservationInventoryTypes.BundleEvidence private bundle;
    S.Receipt private snapshot;
    R.Receipt private referenceReceipt;
    Root.Binding private binding_;
    StreamFinalityScope private scope;
    bytes32 private constant SOURCE_PLAN = keccak256("actual complete source plan");

    function setUp() public {
        c.chainId = block.chainid;
        c.readGas = 1000000;
        c.componentSourceGas = 1000000;
        c.sourceGas = 10000000;
        for (uint256 i; i < 22; ++i) {
            tables[i] = new PolicyProviderTableV2();
            c.targets[i] = address(tables[i]);
            c.codeHashes[i] = address(tables[i]).codehash;
        }
        selection = new PolicyProviderTableV2();
        checkpoint = new PolicyProviderTableV2();
        output = new PolicyProviderTableV2();
        sourceSet = new PolicyProviderTableV2();
        coordinatorInventory = new PolicyProviderTableV2();
        probe = new PolicyProviderProjectionProbeV2(address(output));
        scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        _config();
        _facts();
        probe.initialize(c);
    }

    function _addr(uint256 from, string memory sig, uint256 to) private {
        tables[from].set(sig, abi.encode(c.targets[to]));
    }

    function _config() private {
        _addr(18, "core()", 0);
        _addr(18, "metadataHost()", 1);
        _addr(18, "metadataRouter()", 2);
        _addr(18, "snapshots()", 8);
        _addr(18, "referencePublisher()", 9);
        _addr(18, "artifactCoverage()", 20);
        _addr(18, "externalCoverage()", 21);
        StreamRenderCriticalSourceTypes.Dependencies memory d;
        uint256[12] memory index = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = c.targets[index[i]];
            d.codeHashes[i] = c.codeHashes[index[i]];
        }
        d.artistTargets[0] = c.targets[11];
        d.artistCodeHashes[0] = c.codeHashes[11];
        d.chainId = block.chainid;
        c.inventoryDependencyHash = keccak256(abi.encode(d));
        tables[18].set("dependencies()", abi.encode(d));
        tables[18].set("dependencyHash()", abi.encode(c.inventoryDependencyHash));
        tables[18].set(
            "policyInventoryProfile()",
            abi.encode(keccak256("6529STREAM_POLICY_COLLECTION_RENDER_CRITICAL_V2"))
        );
        tables[10].set(
            "policyFactoryProfile()",
            abi.encode(keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_FACTORY_V2"))
        );
        uint256[6] memory first = [uint256(0), 1, 4, 5, 2, 3];
        for (uint256 i; i < 6; ++i) {
            sd.targets[i] = c.targets[first[i]];
            sd.codeHashes[i] = c.codeHashes[first[i]];
        }
        sd.targets[6] = address(selection);
        sd.targets[7] = address(checkpoint);
        sd.targets[8] = address(output);
        sd.targets[9] = c.targets[20];
        sd.targets[10] = address(sourceSet);
        for (uint256 i = 6; i < 11; ++i) {
            sd.codeHashes[i] = sd.targets[i].codehash;
        }
        sd.chainId = block.chainid;
        sd.readGas = c.readGas;
        sd.sourceGas = c.sourceGas;
        sd.inventoryGas = c.sourceGas;
        tables[8].set("dependencies()", abi.encode(sd));
        output.set("contentCheckpoint()", abi.encode(address(checkpoint)));
        checkpoint.set("selectionCheckpoint()", abi.encode(address(selection)));
        checkpoint.set("entropySourceSet()", abi.encode(address(sourceSet)));
        fd.targets = [c.targets[0], c.targets[1], c.targets[3], address(coordinatorInventory)];
        for (uint256 i; i < 4; ++i) {
            fd.codeHashes[i] = fd.targets[i].codehash;
        }
        fd.chainId = block.chainid;
        fd.readGas = uint32(c.readGas);
        fd.inventoryGas = uint32(c.sourceGas);
        tables[10].set("dependencies()", abi.encode(fd));
        tables[10].set("coordinatorInventory()", abi.encode(address(coordinatorInventory)));
        sourceSet.set("factory()", abi.encode(c.targets[10]));
        sourceSet.set("core()", abi.encode(c.targets[0]));
        _addr(19, "core()", 0);
        _addr(19, "metadataHost()", 1);
        _addr(19, "renderCriticalInventory()", 18);
        _addr(19, "artifactCoverage()", 20);
        _addr(19, "externalCoverage()", 21);
        _addr(14, "core()", 0);
        _addr(14, "collectionMetadata()", 1);
        _addr(12, "coreReads()", 0);
        _addr(12, "metadataReads()", 1);
        tables[12].set("scopeEvidenceProvider()", abi.encode(address(probe)));
        tables[13].set("scopeEvidenceProvider()", abi.encode(address(probe)));
        tables[14].set("evidenceProvider()", abi.encode(address(probe)));
    }

    function _facts() private {
        evidence.planId = keccak256("inventory plan");
        evidence.collectionId = 1;
        evidence.scopeSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, c.targets[0], scope);
        evidence.artistId = keccak256("artist");
        evidence.originals = StreamPreservationInventoryTypes.OriginalInputs(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            bytes32(uint256(4)),
            0,
            bytes32(uint256(6)),
            bytes32(uint256(7)),
            bytes32(uint256(8))
        );
        evidence.sourceContextHash = keccak256("source context");
        evidence.tokenInventoryHash = keccak256("token inventory");
        evidence.tokenCount = 3;
        evidence.segmentCount = 41;
        evidence.itemCount = 88;
        evidence.segmentChainHash = keccak256("segments");
        evidence.renderCriticalEvidenceHash = keccak256("complete evidence");
        tables[18].set("requireCurrent(uint256)", abi.encode(evidence));
        bundle = StreamPreservationInventoryTypes.BundleEvidence(
            evidence.planId,
            evidence.renderCriticalEvidenceHash,
            88,
            keccak256("coverage chain"),
            keccak256("bundle")
        );
        tables[19].set("requireCoverage(bytes32,bytes32)", abi.encode(bundle));
        tables[2].set(
            "collectionContentRootHead(uint256)", abi.encode(evidence.originals.rootRecordHash)
        );
        tables[2].set(
            "tokenContentRoot(uint256,bytes32)",
            abi.encode(keccak256("root"), uint64(3), OutputDefinitions.LEAF_SCHEMA)
        );
        snapshot.recordHash = evidence.originals.snapshotRecordHash;
        snapshot.scopeSubject = evidence.scopeSubject;
        snapshot.revision = 2;
        snapshot.manifestHash = keccak256("actual snapshot bytes");
        snapshot.profileHash = SnapshotDefinitions.PROFILE_HASH;
        tables[8].set("currentSnapshot((uint8,uint256,uint256,bytes32))", abi.encode(snapshot));
        referenceReceipt.scopeSubject = evidence.scopeSubject;
        referenceReceipt.observation.recordHash = evidence.originals.referenceRenderRecordHash;
        referenceReceipt.observation.collectionId = 1;
        referenceReceipt.observation.payloadHash = keccak256("actual reference bytes");
        referenceReceipt.observation.snapshotRecordHash = snapshot.recordHash;
        referenceReceipt.observation.snapshotRevision = 2;
        referenceReceipt.observation.profileHash = ReferenceDefinitions.PROFILE_HASH;
        tables[9].set(
            "currentReference((uint8,uint256,uint256,bytes32))", abi.encode(referenceReceipt)
        );
        binding_.profileId = keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2");
        binding_.outputManifest = address(output);
        binding_.outputManifestCodeHash = address(output).codehash;
        binding_.checkpoint = address(checkpoint);
        binding_.checkpointCodeHash = address(checkpoint).codehash;
        binding_.entropySourceSet = address(sourceSet);
        binding_.entropySourceSetCodeHash = address(sourceSet).codehash;
        binding_.inventoryHash = keccak256("full original inventory");
        binding_.policyChainHash = keccak256("all full twelve-word policies");
        tables[2].set("policyContentRootBinding(bytes32)", abi.encode(binding_));
        tables[10].set(
            "currentInventoryPlan((uint8,uint256,uint256,bytes32))", abi.encode(SOURCE_PLAN)
        );
        tables[10].set(
            "sourceSetForPlan(bytes32)", abi.encode(address(sourceSet), address(sourceSet).codehash)
        );
        tables[10].set(
            "requireCurrentRoute((uint8,uint256,uint256,bytes32))",
            abi.encode(
                StreamFinalityCurrentComponentRoute(
                    StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR,
                    address(sourceSet),
                    type(IStreamArtworkFinalityComponent).interfaceId,
                    address(sourceSet).codehash
                )
            )
        );
        sourceSet.set(
            "SOURCE_SET_PROFILE()", abi.encode(keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"))
        );
        sourceSet.set("originalInventoryHash()", abi.encode(binding_.inventoryHash));
        sourceSet.set("originalPolicyChainHash()", abi.encode(binding_.policyChainHash));
        sourceSet.set("sourceCount()", abi.encode(uint256(2)));
        StreamCoreCollectionFinalityFacts memory f = StreamCoreCollectionFinalityFacts(
            true,
            true,
            StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED,
            0,
            3,
            3,
            0,
            4,
            keccak256("immutable core config")
        );
        tables[14].set("coreCollectionFinalityFacts(uint256)", abi.encode(f));
        tables[0].set("collectionBurnsBlocked(uint256)", abi.encode(true));
        tables[0].set("collectionFreezeStatus(uint256)", abi.encode(uint256(1)));
    }

    function _fails() private {
        vm.expectRevert();
        probe.statement(scope);
    }

    function testExactTypedHeadersPolicyFactoryAndCoverageJoin() public view {
        M.Statement memory s = probe.statement(scope);
        require(
            s.inputs.rootRecordHash == evidence.originals.rootRecordHash
                && s.inputs.snapshotRecordHash == snapshot.recordHash
                && s.inputs.referenceRenderRecordHash == referenceReceipt.observation.recordHash
        );
        require(
            s.inputs.bundleCoverageHash == bundle.bundleCoverageHash
                && s.inputs.renderCriticalEvidenceHash == evidence.renderCriticalEvidenceHash
        );
        require(
            s.entropy.sourceSet == address(sourceSet) && s.entropy.inventoryPlan == SOURCE_PLAN
                && s.entropy.policyCount == 2
                && s.entropy.policyChainHash == binding_.policyChainHash
                && s.entropy.inventoryHash == binding_.inventoryHash
        );
        require(
            s.snapshotManifestHash == snapshot.manifestHash
                && s.referenceRenderManifestHash == referenceReceipt.observation.payloadHash
        );
        require(
            c.targets[6] != address(selection) && c.targets[7] != address(checkpoint),
            "old6/7 never reinterpreted"
        );
        require(s.coreFactsHash != 0 && s.leafCount == 3);
    }

    function testForeignFactoryPlanRuntimeAndCurrentRouteRejectThenRestore() public {
        sourceSet.set("factory()", abi.encode(c.targets[6]));
        _fails();
        sourceSet.set("factory()", abi.encode(c.targets[10]));
        tables[10].set(
            "currentInventoryPlan((uint8,uint256,uint256,bytes32))", abi.encode(bytes32(0))
        );
        _fails();
        tables[10].set(
            "currentInventoryPlan((uint8,uint256,uint256,bytes32))", abi.encode(SOURCE_PLAN)
        );
        tables[10].set(
            "sourceSetForPlan(bytes32)", abi.encode(address(sourceSet), bytes32(uint256(1)))
        );
        _fails();
        _facts();
        tables[10].set(
            "requireCurrentRoute((uint8,uint256,uint256,bytes32))",
            abi.encode(
                StreamFinalityCurrentComponentRoute(
                    StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR,
                    c.targets[6],
                    type(IStreamArtworkFinalityComponent).interfaceId,
                    c.codeHashes[6]
                )
            )
        );
        _fails();
        _facts();
        probe.statement(scope);
    }

    function testFullPolicyChainAndInventoryCannotDriftFromCanonicalRoot() public {
        sourceSet.set(
            "originalPolicyChainHash()", abi.encode(keccak256("changed one original field"))
        );
        _fails();
        _facts();
        sourceSet.set("originalInventoryHash()", abi.encode(keccak256("changed member")));
        _fails();
        _facts();
        sourceSet.set("sourceCount()", abi.encode(uint256(0)));
        _fails();
        _facts();
        probe.statement(scope);
    }

    function testScopeAndBothReceiptProfilesRefuseLegacyOrForeignHeaders() public {
        S.Receipt memory bad = snapshot;
        bad.profileHash = keccak256("V1 profile");
        tables[8].set("currentSnapshot((uint8,uint256,uint256,bytes32))", abi.encode(bad));
        _fails();
        _facts();
        R.Receipt memory r = referenceReceipt;
        r.observation.snapshotRevision = 3;
        tables[9].set("currentReference((uint8,uint256,uint256,bytes32))", abi.encode(r));
        _fails();
        _facts();
        scope.tokenId = 1;
        _fails();
        scope.tokenId = 0;
        probe.statement(scope);
    }

    function testBundleCountAndCoreFreezeEachRemainIndependentRequirements() public {
        StreamPreservationInventoryTypes.BundleEvidence memory b = bundle;
        b.itemCount = 87;
        tables[19].set("requireCoverage(bytes32,bytes32)", abi.encode(b));
        _fails();
        _facts();
        tables[0].set("collectionBurnsBlocked(uint256)", abi.encode(false));
        _fails();
        _facts();
        tables[0].set("collectionFreezeStatus(uint256)", abi.encode(uint256(0)));
        _fails();
        _facts();
        probe.statement(scope);
    }

    function testMissingMalformedAndStaleSourcePinsFailClosedWithExactRetry() public {
        bytes memory code = address(sourceSet).code;
        vm.etch(address(sourceSet), hex"00");
        _fails();
        vm.etch(address(sourceSet), code);
        probe.statement(scope);
        tables[8].set("dependencies()", abi.encodePacked(abi.encode(sd), bytes32(0)));
        _fails();
        tables[8].set("dependencies()", abi.encode(sd));
        checkpoint.set("selectionCheckpoint()", abi.encode(c.targets[6]));
        _fails();
        checkpoint.set("selectionCheckpoint()", abi.encode(address(selection)));
        probe.statement(scope);
    }

    function testPreparedRegistryGuardPrecedesScopeAndSourceReads() public {
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](0);
        scope.tokenId = 1;
        bytes memory code = c.targets[0].code;
        vm.etch(c.targets[0], hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityPolicyProviderOperationsV2.PolicyProviderRegistryOnly.selector
            )
        );
        probe.preparedRows(scope, rows);
        vm.etch(c.targets[0], code);
        scope.tokenId = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityPolicyProviderOperationsV2.PolicyProviderRegistryOnly.selector
            )
        );
        probe.preparedRows(scope, rows);
    }
}
