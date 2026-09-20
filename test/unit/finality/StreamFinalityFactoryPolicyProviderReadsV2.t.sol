// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityCoordinatorPolicyReadsTest
} from "./StreamFinalityCoordinatorPolicyReads.t.sol";
import { PolicyProviderTableV2 } from "./StreamFinalityPolicyProviderReadsV2.t.sol";
import {
    StreamFinalityFactoryPolicyProviderReadsV2 as Reader
} from "../../../smart-contracts/domains/finality/StreamFinalityFactoryPolicyProviderReadsV2.sol";
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
    StreamPolicyOutputSchemasV2 as OutputDefinitions
} from "../../../smart-contracts/domains/finality/StreamPolicyOutputSchemasV2.sol";
import {
    StreamPolicySnapshotDefinitionsV2 as SnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamPolicySnapshotDefinitionsV2.sol";
import {
    StreamPolicyReferenceDefinitionsV2 as ReferenceDefinitions
} from "../../../smart-contracts/domains/records/StreamPolicyReferenceDefinitionsV2.sol";
import {
    StreamFinalityEntropyPolicySourceFactoryV2 as Factory
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityEntropyPolicySourceSet as SourceSet
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamFinalityBoundedReads as Bounded
} from "../../../smart-contracts/domains/finality/StreamFinalityBoundedReads.sol";
import {
    StreamCoreCollectionFinalityFacts
} from "../../../smart-contracts/interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains,
    StreamFinalityComponentExpectation
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Fixed test-only probe invokes the production reader, including its private _entropy path.
/// The budget variant copies the same saved configuration and changes only the outer source cap.
contract FactoryPolicyReaderProbeV2 {
    N.Config private configuration;
    address private output;
    bytes32 private outputCodeHash;

    function initialize(N.Config calldata c, address manifest) external {
        require(configuration.chainId == 0);
        configuration = c;
        output = manifest;
        outputCodeHash = manifest.codehash;
    }

    function statement(StreamFinalityScope calldata scope)
        external
        view
        returns (M.Statement memory)
    {
        return Reader.statement(
            configuration,
            scope,
            new StreamFinalityComponentExpectation[](0),
            output,
            outputCodeHash
        );
    }

    function statementWithSourceBudget(StreamFinalityScope calldata scope, uint256 budget)
        external
        view
        returns (M.Statement memory)
    {
        N.Config memory c = configuration;
        c.sourceGas = budget;
        return Reader.statement(
            c, scope, new StreamFinalityComponentExpectation[](0), output, outputCodeHash
        );
    }
}

/// @notice Production statement and private entropy reads against genuine factory, membership,
/// token/coordinator inventories, native frozen policies and the original immutable source set.
/// @dev Core identities/selection, governance and external randomness inherit named fixture
/// boundaries. Finality headers, complete render inventory/coverage, Router root and Core finality
/// projection remain exact typed tables. They are not admitted publication or full-finality facts.
/// No factory, membership, policy or source-set getter is mocked in positive or low-budget cases.
/// Reverting production currentInventoryPlan to scalar readGas makes the positive statement fail
/// at the genuine factory's strict 3m membership forwarding gate, even with unlimited caller gas.
contract StreamFinalityFactoryPolicyProviderReadsV2Test is
    StreamFinalityCoordinatorPolicyReadsTest
{
    N.Config private c;
    PolicyProviderTableV2[22] private tables;
    PolicyProviderTableV2 private selection;
    PolicyProviderTableV2 private checkpoint;
    PolicyProviderTableV2 private output;
    Factory private factory;
    SourceSet private sourceSet;
    FactoryPolicyReaderProbeV2 private probe;
    Fixture private actual;
    S.Dependencies private sd;
    StreamPreservationInventoryTypes.Evidence private evidence;
    StreamPreservationInventoryTypes.BundleEvidence private bundle;
    S.Receipt private snapshot;
    R.Receipt private referenceReceipt;
    Root.Binding private binding_;
    StreamFinalityScope private scope;

    function _fixture() private {
        actual = _setup(3, true);
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(actual.second));
        Policies.Dependencies memory d;
        d.targets = [address(core), address(metadata), address(membership), address(actual.sources)];
        for (uint256 i; i < 4; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 150000;
        d.inventoryGas = 3000000;
        factory = new Factory(d);
        scope = _scope();
        require(factory.currentInventoryPlan(scope) == actual.plan);
        sourceSet = SourceSet(factory.prepareSourceSet(scope));
        require(factory.requireCurrentRoute(scope).component == address(sourceSet));
        require(sourceSet.sourceCount() == 2);
        c.chainId = block.chainid;
        c.readGas = 500000;
        c.componentSourceGas = 500000;
        c.sourceGas = 24000000;
        for (uint256 i; i < 22; ++i) {
            tables[i] = new PolicyProviderTableV2();
            c.targets[i] = address(tables[i]);
        }
        c.targets[0] = address(core);
        c.targets[1] = address(metadata);
        c.targets[3] = address(membership);
        c.targets[4] = address(schemas);
        c.targets[5] = address(store);
        c.targets[10] = address(factory);
        for (uint256 i; i < 22; ++i) {
            c.codeHashes[i] = c.targets[i].codehash;
        }
        selection = new PolicyProviderTableV2();
        checkpoint = new PolicyProviderTableV2();
        output = new PolicyProviderTableV2();
        probe = new FactoryPolicyReaderProbeV2();
        _config();
        _facts();
        probe.initialize(c, address(output));
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
        snapshot.manifestHash = keccak256("typed snapshot bytes");
        snapshot.profileHash = SnapshotDefinitions.PROFILE_HASH;
        tables[8].set("currentSnapshot((uint8,uint256,uint256,bytes32))", abi.encode(snapshot));
        referenceReceipt.scopeSubject = evidence.scopeSubject;
        referenceReceipt.observation.recordHash = evidence.originals.referenceRenderRecordHash;
        referenceReceipt.observation.collectionId = 1;
        referenceReceipt.observation.payloadHash = keccak256("typed reference bytes");
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
        binding_.inventoryHash = sourceSet.originalInventoryHash();
        binding_.policyChainHash = sourceSet.originalPolicyChainHash();
        tables[2].set("policyContentRootBinding(bytes32)", abi.encode(binding_));
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
        cheat.mockCall(
            address(core),
            abi.encodeWithSignature("collectionBurnsBlocked(uint256)", 1),
            abi.encode(true)
        );
        cheat.mockCall(
            address(core),
            abi.encodeWithSignature("collectionFreezeStatus(uint256)", 1),
            abi.encode(true)
        );
    }

    function _assertStatement() private view returns (bytes32 resultHash) {
        M.Statement memory s = probe.statement(scope);
        require(s.inputs.rootRecordHash == evidence.originals.rootRecordHash);
        require(s.inputs.snapshotRecordHash == snapshot.recordHash);
        require(s.inputs.referenceRenderRecordHash == referenceReceipt.observation.recordHash);
        require(s.inputs.bundleCoverageHash == bundle.bundleCoverageHash);
        require(s.inputs.renderCriticalEvidenceHash == evidence.renderCriticalEvidenceHash);
        require(s.entropy.sourceSet == address(sourceSet));
        require(s.entropy.sourceSetCodeHash == address(sourceSet).codehash);
        require(s.entropy.inventoryPlan == actual.plan && s.entropy.policyCount == 2);
        require(s.entropy.inventoryHash == sourceSet.originalInventoryHash());
        require(s.entropy.policyChainHash == sourceSet.originalPolicyChainHash());
        require(s.snapshotManifestHash == snapshot.manifestHash);
        require(s.referenceRenderManifestHash == referenceReceipt.observation.payloadHash);
        require(s.coreFactsHash != 0 && s.leafCount == 3);
        require(c.targets[6] != address(selection) && c.targets[7] != address(checkpoint));
        resultHash = keccak256(abi.encode(s));
    }

    function testFactoryReaderStatementUsesAggregateBudgetForGenuineMembership() public {
        _fixture();
        bytes memory callData =
            abi.encodeWithSignature("currentInventoryPlan((uint8,uint256,uint256,bytes32))", scope);
        // Independent preflight establishes that the real factory cannot run inside scalar gas.
        (bool low, bytes memory lowResult) = address(factory).staticcall{ gas: c.readGas }(callData);
        require(!low && lowResult.length != 32);
        (bool high, bytes memory highResult) =
            address(factory).staticcall{ gas: c.sourceGas }(callData);
        require(high && highResult.length == 32 && abi.decode(highResult, (bytes32)) == actual.plan);
        bytes32 saved = _assertStatement();
        require(saved == _assertStatement(), "repeat full production statement is identical");
    }

    function testFactoryReaderLowAggregateBudgetFailsThenExactOriginalStatementRecovers() public {
        _fixture();
        bytes32 saved = _assertStatement();
        uint256 budget = 2000000;
        require(budget > c.componentSourceGas + c.componentSourceGas / 63 + 100000);
        require(budget < factory.dependencies().inventoryGas);
        vm.expectRevert(
            abi.encodeWithSelector(Bounded.FinalityReadFailed.selector, address(factory))
        );
        probe.statementWithSourceBudget(scope, budget);
        require(saved == _assertStatement(), "failed read changes no retained source facts");
    }

    function testFactoryReaderRejectsRootPolicyDriftThenRestoresLiteralOriginalFacts() public {
        _fixture();
        bytes32 saved = _assertStatement();
        bytes memory original = abi.encode(binding_);
        Root.Binding memory altered = abi.decode(original, (Root.Binding));
        altered.policyChainHash ^= bytes32(uint256(1));
        tables[2].set("policyContentRootBinding(bytes32)", abi.encode(altered));
        vm.expectRevert(abi.encodeWithSelector(Reader.NativeProviderSource.selector));
        probe.statement(scope);
        tables[2].set("policyContentRootBinding(bytes32)", original);
        require(saved == _assertStatement());
    }

    function testFactoryReaderRejectsChangedMembershipWithoutReusingHistoricalSourcePlan() public {
        _fixture();
        _assertStatement();
        bytes32 oldPlan = actual.plan;
        bytes32 oldPolicy = sourceSet.originalPolicyChainHash();
        core.setToken(12, 1, 4, 2);
        uint256[] memory next = new uint256[](1);
        next[0] = 12;
        inventory.appendCollectionTokens(1, next);
        bytes32 changed = factory.currentInventoryPlan(scope);
        require(changed != oldPlan && changed != 0);
        (address absent, bytes32 absentCode) = factory.sourceSetForPlan(changed);
        require(absent == address(0) && absentCode == 0);
        vm.expectRevert(abi.encodeWithSelector(Reader.NativeProviderSource.selector));
        probe.statement(scope);
        (address retained, bytes32 retainedCode) = factory.sourceSetForPlan(oldPlan);
        require(retained == address(sourceSet) && retainedCode == address(sourceSet).codehash);
        require(sourceSet.originalPolicyChainHash() == oldPolicy);
    }
}
