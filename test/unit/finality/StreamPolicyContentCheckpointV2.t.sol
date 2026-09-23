// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyPublicationGraphTypesV2 as CapacityGraph446
} from "../../../smart-contracts/interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";
import {
    StreamPolicyPublicationCheckpointDeploymentV2 as CapacityDeploy446
} from "../../../smart-contracts/domains/finality/StreamPolicyPublicationCheckpointDeploymentV2.sol";

import "../metadata/StreamTerminalEntropyRouting.t.sol";
import {
    StreamPolicyOutputManifestV2
} from "../../../smart-contracts/domains/finality/StreamPolicyOutputManifestV2.sol";
import {
    StreamPolicyOutputSchemasV2 as PolicyDocs
} from "../../../smart-contracts/domains/finality/StreamPolicyOutputSchemasV2.sol";
import {
    StreamFinalityArtifactCoverage
} from "../../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import {
    StreamFinalityArtifactTypes as Coverage
} from "../../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";
import { LeafManifestVm } from "./StreamContentLeafManifest.t.sol";
import {
    LeafManifestArchiveBoundary,
    LeafManifestFinalityBoundary
} from "../../helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol";
import {
    StreamPolicyContentCheckpointV2
} from "../../../smart-contracts/domains/finality/StreamPolicyContentCheckpointV2.sol";
import {
    IStreamPolicyContentCheckpointV2 as O
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamStaticContentCheckpoint as Old
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamCurrentCitationRegistry as C
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamCurrentCitationRenderer as Current
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    StreamTerminalEntropyReadiness
} from "../../../smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol";
import {
    StreamStaticSelectionCheckpoint
} from "../../../smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol";
import {
    StreamFinalityScopeMembership
} from "../../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import {
    StreamCollectionTokenInventory
} from "../../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import {
    StreamTokenContentTree as Tree
} from "../../../smart-contracts/domains/metadata/StreamTokenContentTree.sol";
import {
    IStreamCorePointers
} from "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamCoreIdentity
} from "../../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    StreamScopeMembershipFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamTokenContentLeaf
} from "../../../smart-contracts/interfaces/stream/metadata/StreamTokenContentTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Explicit complete-policy evidence boundary; actual policy-set production has its own tests.
contract PolicyOutputSourceBoundary {
    address public immutable core;
    address public immutable source;
    StreamFinalityScopeMembership public immutable membership;
    bytes32 public constant SOURCE_SET_PROFILE =
        keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2");
    bytes32 public originalInventoryHash = keccak256("complete original fixture inventory");
    bytes32 public originalPolicyChainHash = keccak256("full twelve-word fixture policy set");
    bool public current = true;
    uint8 public shape;
    uint256 public scopeCollection = 1;

    constructor(address c, address e, StreamFinalityScopeMembership m) {
        core = c;
        source = e;
        membership = m;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(E).interfaceId;
    }

    function sourceScope() public view returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, scopeCollection, 0, 0);
    }

    function scopeMembershipFacts() external view returns (StreamScopeMembershipFacts memory) {
        return membership.requireScopeMembership(sourceScope());
    }

    function requireCurrentSourceSet() external view {
        require(current, "stale complete policy inventory");
    }

    function change(bool c, bytes32 policy, uint8 s, uint256 cid) external {
        current = c;
        originalPolicyChainHash = policy;
        shape = s;
        scopeCollection = cid;
    }

    function tokenEntropyReadiness(uint256 token)
        external
        view
        returns (E.TokenReadiness memory e)
    {
        (, Policy.Policy memory p, uint8 status,,) = TerminalRouteEntropy(source)
            .staticTerminalEntropyFacts(token);
        e = E.TokenReadiness(
            source,
            source.codehash,
            p.policyHash,
            status,
            p.mode,
            p.securityClass,
            p.renderRequirement,
            true,
            false,
            0
        );
        if (shape == 1) e.finalized = true;
        if (shape == 2) e.seed = bytes32(uint256(1));
        if (shape == 3) e.renderRequirement = 0;
        if (shape == 4) {
            e = E.TokenReadiness(
                source, source.codehash, p.policyHash, 5, 2, 0, 0, false, true, bytes32(uint256(7))
            );
        }
    }
}

contract PolicyOutputVersionsBoundary is TerminalRouteVersions {
    address private immutable actualRenderer;

    constructor(address e, address s, address r) TerminalRouteVersions(e, s, r) {
        actualRenderer = r;
    }

    function requireCurrentCitation(bytes32 k)
        external
        view
        override
        returns (address, bytes32, bytes32, bytes4)
    {
        require(admitted && k == key, "separate current citation admission");
        return (
            actualRenderer,
            actualRenderer.codehash,
            keccak256("6529STREAM_CURRENT_BASE_CITATION_V1"),
            Current.renderCurrent.selector
        );
    }

    function terminalEntropyRecord(bytes32 k) external view returns (C.CurrentRecord memory r) {
        require(admitted && k == key, "separate record");
        r.registration.versionKey = k;
        r.registrationHash = keccak256("exact separately admitted fixture profile");
    }
}

/// @notice Actual Router/Renderer/Metadata/Schema/Store, selection/inventory/membership and readiness.
/// Core/Artist/governance/terminal producer/complete-policy set and version admission are named typed
/// boundaries. These cases do not establish complete V2 snapshot/reference publication or conformance.
contract StreamPolicyContentCheckpointV2Test is StaticMetadataRoutingFixture {
    TerminalRouteEntropy private terminal;
    PolicyOutputVersionsBoundary private admittedVersions;
    PolicyOutputSourceBoundary private sourceSet;
    StreamTerminalEntropyReadiness private readiness;
    StreamCollectionTokenInventory private inventory;
    StreamStaticSelectionCheckpoint private selections;
    StreamPolicyContentCheckpointV2 private outputs;
    bytes32 private selection;

    function setUp() public override {
        super.setUp();
        terminal = new TerminalRouteEntropy(address(core));
        core.setEntropy(address(terminal));
        StreamRendererV1.Deployment memory d;
        (d.sources,) = renderer.sourceBindings();
        d.sources.entropy = address(terminal);
        d.executor = address(executor);
        d.manifest = renderer.rendererManifest();
        d.readGas = _gas("METADATA_DEPENDENCY_READ_GAS", 2000000, 2);
        d.attributionGas = _gas("STATIC_ATTRIBUTION_GAS", 8000000, 1);
        renderer = new StreamRendererV1(d);
        admittedVersions = new PolicyOutputVersionsBoundary(
            address(executor), address(schemas), address(renderer)
        );
        versions = admittedVersions;
        modules = new StaticRouteModules(address(metadata), address(versions));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(modules));
        _admin(
            abi.encodeCall(
                router.setCollectionMetadata,
                (1, "Policy output", "Exact source", "data:image/png;base64,iVBORw0KGgo=", "")
            )
        );
        _activate();
        _mint();
        StaticRouteVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (91)),
                abi.encode(true, uint256(1), uint256(1), false)
            );
        StaticRouteVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("METADATA_ROUTER"))
                ),
                abi.encode(
                    address(router),
                    address(router).codehash,
                    false,
                    keccak256("METADATA_ROUTER"),
                    type(IStreamMetadataRouter).interfaceId,
                    address(modules),
                    uint8(1),
                    keccak256("manifest"),
                    keccak256("deployment"),
                    uint64(1)
                )
            );
        inventory = new StreamCollectionTokenInventory(
            address(core), address(executor), _gas("TOKEN_INVENTORY_CORE_READ_GAS", 100000, 1)
        );
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 91;
        inventory.appendCollectionTokens(1, tokens);
        StreamFinalityScopeMembership members = new StreamFinalityScopeMembership(
            address(core),
            address(metadata),
            address(inventory),
            address(executor),
            _gas("SCOPE_MEMBERSHIP_READ_GAS", 500000, 1)
        );
        selections = new StreamStaticSelectionCheckpoint(
            address(core),
            address(router),
            address(members),
            address(executor),
            _gas("STATIC_CHECKPOINT_READ_GAS", 2000000, 1)
        );
        S.ConfigInput memory input = _input(R.MetadataMode.ONCHAIN, true);
        _approve(0, input, keccak256("original config consent"));
        router.setCollectionMetadataConfig(1, input);
        selection =
            selections.begin(StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0));
        selections.append(selection, 1);
        sourceSet = new PolicyOutputSourceBoundary(address(core), address(terminal), members);
        readiness = new StreamTerminalEntropyReadiness(
            address(core), address(router), address(sourceSet), 2000000, 6000000
        );
        outputs = new StreamPolicyContentCheckpointV2(
            address(selections),
            address(sourceSet),
            address(readiness),
            address(executor),
            _gas("STATIC_CONTENT_READ_GAS", 8000000, 2),
            _gas("STATIC_CONTENT_RENDER_GAS", 16000000, 2)
        );
    }

    function testCapacityCheckpointConstructorKeepsHostCreateArgumentsAndIndependentPlan() public {
        admittedVersions.setAdmitted(true);
        CapacityGraph446.Recipe memory r;
        CapacityGraph446.Graph memory g;
        r.targets[1] = address(selections);
        r.targets[3] = address(executor);
        r.checkpointGas[0] = _gas("STATIC_CONTENT_READ_GAS", 8000000, 2);
        r.checkpointGas[1] = _gas("STATIC_CONTENT_RENDER_GAS", 16000000, 2);
        g.sourceSet = address(sourceSet);
        g.children[0] = address(readiness);
        uint64 nonce = LeafManifestVm(address(vm)).getNonce(address(this));
        StreamPolicyContentCheckpointV2 child =
            StreamPolicyContentCheckpointV2(CapacityDeploy446.deploy(r, g));
        require(
            address(child)
                == LeafManifestVm(address(vm)).computeCreateAddress(address(this), nonce),
            "original CREATE host"
        );
        require(LeafManifestVm(address(vm)).getNonce(address(this)) == nonce + 1, "one CREATE");
        require(
            child.core() == address(core) && child.metadataRouter() == address(router)
                && child.selectionCheckpoint() == address(selections)
                && child.entropySourceSet() == address(sourceSet)
                && child.terminalReadiness() == address(readiness)
                && child.governanceAuthority() == address(executor),
            "six original constructor arguments"
        );
        require(
            child.gasParameter(keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS")) == 8000000
                && child.gasParameter(keccak256("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS"))
                    == 16000000,
            "original registered caps"
        );
        bytes32 oldId = outputs.begin(selection, keccak256("capacity constructor"));
        bytes32 id = child.begin(selection, keccak256("capacity constructor"));
        require(id != oldId, "checkpoint domain keeps actual new host");
        child.append(id, _payload());
        require(
            child.requireCurrentCheckpoint(id).nextIndex == 1
                && outputs.checkpoint(oldId).nextIndex == 0,
            "real child observation and independent storage"
        );
    }

    function testCapacityObservationRerendersBytesButRetainsOriginalOutput() public {
        admittedVersions.setAdmitted(true);
        bytes32 id = outputs.begin(selection, keccak256("capacity observation"));
        O.Payload[] memory payload = _payload();
        bytes32 inputHash = keccak256(abi.encode(payload));
        outputs.append(id, payload);
        O.Output memory row = outputs.outputAt(id, 0);
        require(
            row.leaf.metadataHash == keccak256(bytes(router.tokenJSON(91)))
                && row.leaf.animationHash == keccak256(payload[0].animation)
                && row.leaf.imageHash == keccak256(payload[0].image)
                && row.leaf.tokenDataHash == keccak256(core.tokenData(91))
                && row.htmlHash == row.leaf.animationHash && row.terminalAdmissionHash != 0,
            "all returned observation values retained"
        );
        bytes32 saved = keccak256(abi.encode(outputs.checkpoint(id), row));
        string memory html = router.tokenHTML(91);
        StaticRouteVm(address(vm))
            .mockCall(
                address(router),
                abi.encodeCall(router.tokenHTML, (uint256(91))),
                abi.encode(string(abi.encodePacked(html, " ")))
            );
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentChanged.selector, id));
        outputs.requireCurrentCheckpoint(id);
        require(
            keccak256(abi.encode(outputs.checkpoint(id), outputs.outputAt(id, 0))) == saved,
            "re-observation does not rewrite history"
        );
        require(keccak256(abi.encode(payload)) == inputHash, "caller payload unchanged");
        StaticRouteVm(address(vm))
            .mockCall(
                address(router), abi.encodeCall(router.tokenHTML, (uint256(91))), abi.encode(html)
            );
        require(
            outputs.requireCurrentCheckpoint(id).nextIndex == 1, "exact bytes restore currentness"
        );
    }

    function testCapacityObservationRenderPreflightRefusesWithoutPartialAppendThenRetries() public {
        admittedVersions.setAdmitted(true);
        bytes32 id = outputs.begin(selection, keccak256("capacity gas preflight"));
        O.Payload[] memory payload = _payload();
        bytes32 before = keccak256(abi.encode(outputs.checkpoint(id)));
        uint256 cap = outputs.gasParameter(keccak256("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS"));
        (bool ok, bytes memory failure) =
            address(outputs).call{ gas: cap }(abi.encodeCall(outputs.append, (id, payload)));
        require(
            !ok && failure.length == 68, "preflight returns original typed error, not empty OOG"
        );
        bytes4 selector;
        uint256 available;
        uint256 required;
        assembly ("memory-safe") {
            selector := mload(add(failure, 32))
            available := mload(add(failure, 36))
            required := mload(add(failure, 68))
        }
        require(
            selector == O.StaticContentParentGas.selector && required == cap + cap / 63 + 100000
                && available <= required,
            "original render budget is never clamped"
        );
        require(
            keccak256(abi.encode(outputs.checkpoint(id))) == before,
            "preflight leaves plan and frontier unchanged"
        );
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentIndex.selector, uint256(0)));
        outputs.outputAt(id, 0);
        outputs.append(id, payload);
        require(
            outputs.requireCurrentCheckpoint(id).nextIndex == 1,
            "healthy budget permits exact retry"
        );
    }

    function testPolicyOutputRequiresNewCapabilityAndSeparateTerminalAdmission() public {
        require(
            outputs.supportsInterface(type(O).interfaceId)
                && !outputs.supportsInterface(type(Old).interfaceId),
            "distinct capability"
        );
        bytes32 id = outputs.begin(selection, 0);
        O.Payload[] memory p = new O.Payload[](1);
        p[0] = O.Payload(91, hex"89504e470d0a1a0a", bytes("unadmitted"));
        vm.expectRevert();
        outputs.append(id, p);
        require(outputs.checkpoint(id).nextIndex == 0);
        admittedVersions.setAdmitted(true);
        outputs.append(id, _payload());
        require(outputs.requireCurrentCheckpoint(id).contentRoot != 0);
    }

    function testPolicyOutputOriginalLeafTreeAndLiteralV2OutputChain() public {
        admittedVersions.setAdmitted(true);
        bytes32 id = outputs.begin(selection, keccak256("capture"));
        outputs.append(id, _payload());
        O.Plan memory p = outputs.requireCurrentCheckpoint(id);
        O.Output memory row = outputs.outputAt(id, 0);
        require(
            row.entropy.terminal && !row.entropy.finalized && row.entropy.seed == 0
                && row.entropy.status == 1
        );
        require(
            row.terminalAdmissionHash != 0
                && row.leaf.metadataHash == keccak256(bytes(router.tokenJSON(91)))
                && row.leaf.animationHash == keccak256(bytes(router.tokenHTML(91)))
        );
        StreamTokenContentLeaf[] memory leaves = new StreamTokenContentLeaf[](1);
        leaves[0] = row.leaf;
        require(
            p.contentRoot == Tree.root(block.chainid, address(core), leaves),
            "original six-field tree"
        );
        require(
            p.outputRoot
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_FULL_OUTPUTS_V2"), bytes32(0), uint256(0), row
                    )
                ),
            "literal new output chain"
        );
        require(
            p.policyChainHash == sourceSet.originalPolicyChainHash()
                && p.inventoryHash == sourceSet.originalInventoryHash()
        );
        require(outputs.begin(selection, keccak256("capture")) == id, "same immutable plan");
    }

    function testPolicyOutputFullPolicyOrInventoryStalenessCannotStayCurrent() public {
        admittedVersions.setAdmitted(true);
        bytes32 id = outputs.begin(selection, 0);
        outputs.append(id, _payload());
        bytes32 old = sourceSet.originalPolicyChainHash();
        bytes32 saved = outputs.checkpoint(id).contentRoot;
        sourceSet.change(true, keccak256("same visible status different full H"), 0, 1);
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
        require(outputs.checkpoint(id).contentRoot == saved);
        sourceSet.change(false, old, 0, 1);
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
        sourceSet.change(true, old, 0, 1);
        outputs.requireCurrentCheckpoint(id);
    }

    function testPolicyOutputFalseFinalizedSeedAndWrongRequirementRollback() public {
        admittedVersions.setAdmitted(true);
        bytes32 id = outputs.begin(selection, 0);
        O.Payload[] memory p = _payload();
        bytes32 chain = sourceSet.originalPolicyChainHash();
        for (uint8 shape = 1; shape <= 4; ++shape) {
            sourceSet.change(true, chain, shape, 1);
            vm.expectRevert();
            outputs.append(id, p);
            require(outputs.checkpoint(id).nextIndex == 0 && outputs.checkpoint(id).outputRoot == 0);
        }
        sourceSet.change(true, chain, 0, 1);
        outputs.append(id, p);
        outputs.requireCurrentCheckpoint(id);
    }

    function testPolicyOutputExactHTMLImageAndTokenOrderFailureThenRetry() public {
        admittedVersions.setAdmitted(true);
        bytes32 id = outputs.begin(selection, 0);
        O.Payload[] memory p = _payload();
        p[0].tokenId = 92;
        vm.expectRevert();
        outputs.append(id, p);
        p[0].tokenId = 91;
        p[0].image = hex"01";
        vm.expectRevert();
        outputs.append(id, p);
        p = _payload();
        p[0].animation = bytes("substituted html");
        vm.expectRevert();
        outputs.append(id, p);
        require(outputs.checkpoint(id).nextIndex == 0);
        outputs.append(id, _payload());
        outputs.requireCurrentCheckpoint(id);
    }

    function testPolicyOutputLiveFullJSONDriftPreservesHistoricalRow() public {
        admittedVersions.setAdmitted(true);
        bytes32 id = outputs.begin(selection, 0);
        outputs.append(id, _payload());
        bytes32 saved = outputs.outputAt(id, 0).leaf.metadataHash;
        attribution.setFail(true);
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
        require(outputs.outputAt(id, 0).leaf.metadataHash == saved);
        attribution.setFail(false);
        outputs.requireCurrentCheckpoint(id);
        admittedVersions.setAdmitted(false);
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
    }

    function testPolicyOutputScopeAndReadinessBindingsCannotBeSubstituted() public {
        bytes32 chain = sourceSet.originalPolicyChainHash();
        sourceSet.change(true, chain, 0, 2);
        vm.expectRevert();
        outputs.begin(selection, 0);
        sourceSet.change(true, chain, 0, 1);
        vm.expectRevert();
        new StreamPolicyContentCheckpointV2(
            address(selections),
            address(sourceSet),
            address(terminal),
            address(executor),
            _gas("STATIC_CONTENT_READ_GAS", 8000000, 2),
            _gas("STATIC_CONTENT_RENDER_GAS", 16000000, 2)
        );
        require(outputs.begin(selection, 0) != 0);
    }

    function testPolicyOutputExplicitNotRequiredDoesNotUseFinalizedProfile() public {
        terminal.setStatus(2);
        admittedVersions.setAdmitted(true);
        bytes32 id = outputs.begin(selection, 0);
        outputs.append(id, _payload());
        O.Output memory row = outputs.outputAt(id, 0);
        require(
            row.entropy.status == 2 && row.entropy.mode == 2 && row.entropy.terminal
                && !row.entropy.finalized && row.entropy.seed == 0
        );
        vm.expectRevert();
        router.historicalTokenMetadataJSON(address(core), 91);
        outputs.requireCurrentCheckpoint(id);
    }

    function testPolicyOutputFinalizedSourceRequiresExactOriginalNativeSeed() public {
        // The complete policy SourceSet is a named typed boundary here; genuine mixed policy
        // inventory construction is exercised separately in StreamTerminalEntropySourceSetTest.
        terminal.setStatus(5);
        terminal.setInvalid(bytes32(uint256(7)), 0);
        admittedVersions.setAdmitted(true);
        sourceSet.change(true, sourceSet.originalPolicyChainHash(), 4, 1);
        bytes32 id = outputs.begin(selection, 0);
        outputs.append(id, _payload());
        O.Output memory row = outputs.outputAt(id, 0);
        require(
            row.entropy.finalized && !row.entropy.terminal
                && row.entropy.seed == bytes32(uint256(7)) && row.terminalAdmissionHash == 0
        );
        terminal.setInvalid(bytes32(uint256(8)), 0);
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
        terminal.setInvalid(bytes32(uint256(7)), 0);
        outputs.requireCurrentCheckpoint(id);
    }

    function testPolicyOutputDependencyRuntimeDriftLeavesHistoricalEvidence() public {
        admittedVersions.setAdmitted(true);
        bytes32 id = outputs.begin(selection, 0);
        outputs.append(id, _payload());
        bytes32 saved = outputs.outputAt(id, 0).sourceFactsHash;
        vm.etch(address(readiness), hex"00");
        vm.expectRevert();
        outputs.requireCurrentCheckpoint(id);
        require(outputs.outputAt(id, 0).sourceFactsHash == saved);
    }

    function testPolicyOutputActualCheckpointToPreservedManifestAndCurrentDrift() public {
        admittedVersions.setAdmitted(true);
        bytes32 id = outputs.begin(selection, 0);
        outputs.append(id, _payload());
        _outputDocument("RAW_BYTES", true, bytes(schemas.RAW_BYTES_DEFINITION()));
        _outputDocument(
            "STREAM_POLICY_OUTPUT_MANIFEST_V2", false, PolicyDocs.document(PolicyDocs.SCHEMA)
        );
        _outputDocument(
            "STREAM_ABI_POLICY_OUTPUT_MANIFEST_V2", true, PolicyDocs.document(PolicyDocs.CANON)
        );
        StreamSchemaDocumentStore store = StreamSchemaDocumentStore(schemas.chunkStore());
        LeafManifestArchiveBoundary archive =
            new LeafManifestArchiveBoundary(address(core), address(executor));
        LeafManifestVm mvm = LeafManifestVm(address(vm));
        address predicted =
            mvm.computeCreateAddress(address(this), uint256(mvm.getNonce(address(this))) + 1);
        StreamFinalityArtifactCoverage coverage = new StreamFinalityArtifactCoverage(
            address(core),
            address(archive),
            address(schemas),
            address(store),
            predicted,
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 300000, 300000, 2
            )
        );
        require(
            address(new LeafManifestFinalityBoundary(address(core), address(coverage))) == predicted
        );
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), predicted);
        StreamPolicyOutputManifestV2 manifest = new StreamPolicyOutputManifestV2(
            address(core),
            address(outputs),
            address(coverage),
            address(executor),
            // Fund the existing 16m render cap (the 8m cap is only dependency reads),
            // its full EIP-150/parent reserve, and the preceding one-row validation work.
            // The retained 10m negative stops at StaticContentParentGas before tokenJSON.
            // This 20m focused-fixture cap is not a production or transaction-cap claim.
            _gas("STATIC_OUTPUT_MANIFEST_READ_GAS", 20000000, 2)
        );
        O.Plan memory p = outputs.requireCurrentCheckpoint(id);
        O.Output[] memory rows = new O.Output[](1);
        rows[0] = outputs.outputAt(id, 0);
        bytes memory raw = abi.encode(
            PolicyDocs.SCHEMA,
            block.chainid,
            address(core),
            address(outputs),
            id,
            keccak256(abi.encode(p)),
            address(sourceSet),
            p.inventoryHash,
            p.policyChainHash,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            rows
        );
        (bytes32 chunk, address pointer) = store.publishChunk(raw);
        archive.add(chunk, pointer);
        Coverage.Artifact memory a;
        a.artistId = keccak256("artist");
        a.schemaId = PolicyDocs.SCHEMA;
        a.canonicalizationId = PolicyDocs.CANON;
        a.hashAlgorithm = 1;
        a.contentHash = keccak256(raw);
        a.byteLength = uint64(raw.length);
        a.chunkHashes = new bytes32[](1);
        a.chunkHashes[0] = chunk;
        a.chunkLengths = new uint32[](1);
        a.chunkLengths[0] = uint32(raw.length);
        bytes32 artifact = coverage.recordArtifact(a);
        bytes32 coverPlan = coverage.beginCoverage(
            artifact, keccak256("archive family A"), keccak256("archive family B")
        );
        bytes32 covered = coverage.coverNextChunk(coverPlan, 0, chunk);
        bytes32 plan = manifest.beginManifest(id, artifact, covered, a.artistId);
        bytes32 record = manifest.verifyNextOutputs(plan, 1);
        require(manifest.requireCurrentManifest(record, a.artistId).contentRoot == p.contentRoot);
        bytes32 historical = keccak256(abi.encode(manifest.manifestRecord(record)));
        admittedVersions.setAdmitted(false);
        vm.expectRevert();
        manifest.requireCurrentManifest(record, a.artistId);
        require(historical == keccak256(abi.encode(manifest.manifestRecord(record))));
        admittedVersions.setAdmitted(true);
        manifest.requireCurrentManifest(record, a.artistId);
    }

    function _outputDocument(string memory name, bool canon, bytes memory raw) private {
        StreamSchemaDocumentStore store = StreamSchemaDocumentStore(schemas.chunkStore());
        (bytes32 hash,) = store.publishChunk(raw);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name,
            canon
                ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                : IStreamSchemaRegistry.DocumentKind.SCHEMA,
            hash,
            schemas.RAW_BYTES(),
            0,
            "",
            uint32(raw.length)
        );
        (bytes32 scope, bytes32 old, bytes32 next) = schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas),
            abi.encodeCall(schemas.registerDocument, (spec, chunks)),
            scope,
            old,
            next
        );
    }

    function _payload() private view returns (O.Payload[] memory p) {
        p = new O.Payload[](1);
        p[0] = O.Payload(91, hex"89504e470d0a1a0a", bytes(router.tokenHTML(91)));
    }

    function _gas(string memory name, uint256 value, uint8 failure)
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(name, value, 50000, failure);
    }
}
