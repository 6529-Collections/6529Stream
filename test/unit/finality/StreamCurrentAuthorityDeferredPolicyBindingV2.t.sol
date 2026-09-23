// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentAuthorityConfiguration.t.sol";
import {
    IStreamFinalityCoordinatorInventory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCoordinatorInventory.sol";
import {
    IStreamFinalityScopeMembership
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    StreamScopeMembershipFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    IStreamEntropyCoordinator
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import {
    IStreamEntropyFinalityPolicy
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyFinalityPolicy.sol";
import {
    IStreamModule
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModule.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    IStreamArtworkFinalityComponent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    IStreamArtworkScopedFinalityComponent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as T
} from "../../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyGovernanceV2 as Governance
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityDeferredPolicyGovernanceV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyValidationV2 as Validation
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityDeferredPolicyValidationV2.sol";
import {
    StreamFinalityEntropyPolicySourceFactoryV2 as SourceFactory
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityEntropyPolicySourceSet as SourceSet
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamPolicySnapshotTypesV2 as Snapshot
} from "../../../smart-contracts/interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    StreamPolicyReferenceTypesV2 as Reference
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPolicyReferenceTypesV2.sol";
import {
    IStreamPolicySnapshotPublicationV2 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    IStreamPolicyReferencePublicationV2 as Ref
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPolicyReferencePublicationV2.sol";
import {
    IStreamPolicyOutputManifestV2 as Output
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyOutputManifestV2.sol";
import {
    IStreamPolicyContentCheckpointV2 as Checkpoint
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamStaticSelectionCheckpoint as Static
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPolicyRenderCriticalInventoryV2 as CurrentInventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPolicyRenderCriticalInventoryV2.sol";
import {
    IStreamArtistArchiveOriginInventory as OriginInventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";
import {
    IStreamCurrentAuthorityInventory as AuthorityInventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    IStreamBundleArchiveCoverage as Bundle
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamBundleArchiveCoverage.sol";
import {
    IStreamGovernedParameterAuthority as Authority
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import {
    StreamEntropyPolicyConsumerTypes as Explicit
} from "../../../smart-contracts/interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";

/// @dev Target-side context fixture, not a GovernanceV2 scheduling implementation.
contract DeferredPolicyExecutorBoundary is FinalityMultiOriginReadTable {
    function run(address target, bytes calldata input) external returns (bool, bytes memory) {
        return target.call(input);
    }
}

/// @dev Real linked validation followed by a single commit. No pending output self-getters exist.
contract DeferredPolicyBindingHarness {
    Validation.Context private _context;
    T.Receipt private _receipt;

    function initialize(
        Native.Config memory original,
        O.Dependencies memory od,
        D.Dependencies memory ad
    ) external {
        require(_context.capability.capabilityHash == 0);
        _context = Validation.Context(
            original,
            Governance.initialize(
                original, keccak256("scoped configuration"), keccak256("factory configuration")
            ),
            od,
            ad
        );
    }

    function capability() external view returns (T.Capability memory) {
        return _context.capability;
    }

    function bindingHash() external view returns (bytes32) {
        return _receipt.bindingHash;
    }

    function receipt() external view returns (T.Receipt memory) {
        if (_receipt.bindingHash == 0) revert T.CollectionPolicyPending();
        return _receipt;
    }

    function candidate(Native.Config memory policy, address output, bytes32 outputHash)
        external
        view
        returns (T.Receipt memory)
    {
        return Validation.candidate(_context, policy, output, outputHash);
    }

    function transition(Native.Config memory policy, address output, bytes32 outputHash)
        external
        view
        returns (T.Transition memory)
    {
        return Validation.transition(_context, policy, output, outputHash);
    }

    function bind(Native.Config memory policy, address output, bytes32 outputHash) external {
        if (_receipt.bindingHash != 0) revert T.CollectionPolicyAlreadyBound();
        T.Receipt memory admitted = Validation.bind(_context, policy, output, outputHash);
        _receipt = admitted;
    }
}

/// @notice Real candidate/Governance libraries, source factory/source-set and complete policy kernel.
/// @dev Core, membership, original Coordinator, publication, resolver and executor facts are typed
/// boundaries. No mocks replace the libraries. This proves their joins and target-side atomicity,
/// not authentic Safe scheduling, Metadata ancestry/publication, or a complete Finality graph.
contract StreamCurrentAuthorityDeferredPolicyBindingV2Test is CurrentAuthorityConsumerFixture {
    DeferredPolicyBindingHarness private binding;
    DeferredPolicyExecutorBoundary private executor;
    FinalityMultiOriginReadTable private coordinator;
    FinalityMultiOriginReadTable private sourceInventory;
    FinalityMultiOriginReadTable private tokens;
    FinalityMultiOriginReadTable private output;
    FinalityMultiOriginReadTable private checkpoint;
    FinalityMultiOriginReadTable private staticSelection;
    FinalityMultiOriginReadTable private readiness;
    SourceFactory private sourceFactory;
    SourceSet private sourceSet;
    Native.Config private original;
    Policies.Dependencies private policyDependencies;
    IStreamFinalityCoordinatorInventory.Progress private progress;
    StreamScopeMembershipFacts private facts;
    Snapshot.Dependencies private snapshot;
    bytes32 private sourcePlan;
    bytes32 private constant ACTION = keccak256("governed action boundary");

    function setUp() public override {
        super.setUp();
        original = c;
        executor = new DeferredPolicyExecutorBoundary();
        _set(c.targets[1], "governanceAuthority()", abi.encode(address(executor)));
        _set(c.targets[1], "executorCodeHash()", abi.encode(address(executor).codehash));
        _set(address(executor), "isStreamGovernedParameterAuthority()", abi.encode(true));
        binding = new DeferredPolicyBindingHarness();
        binding.initialize(original, od, ad);
        c.targets[8] = address(new FinalityMultiOriginReadTable());
        c.targets[9] = address(new FinalityMultiOriginReadTable());
        _policySource();
        for (uint256 i = 8; i <= 10; ++i) {
            c.codeHashes[i] = c.targets[i].codehash;
        }
        sd.targets[5] = c.targets[8];
        sd.codeHashes[5] = c.codeHashes[8];
        sd.targets[6] = c.targets[9];
        sd.codeHashes[6] = c.codeHashes[9];
        anchors.targets[4] = address(binding);
        anchors.codeHashes[4] = address(binding).codehash;
        resolver.set(abi.encodeCall(Resolver.anchors, ()), abi.encode(anchors));
        _select(captured.dependencies.artistTargets[0]);
        _publishCurrent(D.POLICY_INVENTORY_PROFILE);
        _set(address(inventory), "snapshots()", abi.encode(c.targets[8]));
        _set(address(inventory), "referencePublisher()", abi.encode(c.targets[9]));
        _set(address(inventory), "policyInventoryProfile()", abi.encode(D.POLICY_INVENTORY_PROFILE));
        _support(address(inventory), type(CurrentInventory).interfaceId);
        _support(address(inventory), type(OriginInventory).interfaceId);
        _support(address(inventory), type(AuthorityInventory).interfaceId);
        _support(address(bundle), type(Bundle).interfaceId);
        _set(address(bundle), "core()", abi.encode(c.targets[0]));
        _set(address(bundle), "metadataHost()", abi.encode(c.targets[1]));
        _set(address(bundle), "renderCriticalInventory()", abi.encode(c.targets[18]));
        _set(address(bundle), "artifactCoverage()", abi.encode(c.targets[20]));
        _set(address(bundle), "externalCoverage()", abi.encode(c.targets[21]));
        _set(c.targets[14], "collectionMetadata()", abi.encode(c.targets[1]));
        _set(c.targets[12], "coreReads()", abi.encode(c.targets[0]));
        _set(c.targets[12], "metadataReads()", abi.encode(c.targets[1]));
        _set(c.targets[12], "scopeEvidenceProvider()", abi.encode(address(binding)));
        _set(c.targets[14], "evidenceProvider()", abi.encode(address(binding)));
        _publications();
    }

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _set(address target, string memory signature, bytes memory value) private {
        FinalityMultiOriginReadTable(target).set(abi.encodeWithSignature(signature), value);
    }

    function _addr(address target, string memory signature, address value) private {
        _set(target, signature, abi.encode(value));
    }

    function _policySource() private {
        sourceInventory = new FinalityMultiOriginReadTable();
        tokens = new FinalityMultiOriginReadTable();
        coordinator = new FinalityMultiOriginReadTable();
        policyDependencies.targets =
            [c.targets[0], c.targets[1], c.targets[3], address(sourceInventory)];
        for (uint256 i; i < 4; ++i) {
            policyDependencies.codeHashes[i] = policyDependencies.targets[i].codehash;
        }
        policyDependencies.chainId = block.chainid;
        policyDependencies.readGas = 500000;
        policyDependencies.inventoryGas = 2000000;
        _support(c.targets[0], 0x80ac58cd);
        _support(c.targets[3], type(IStreamFinalityScopeMembership).interfaceId);
        _support(address(sourceInventory), type(IStreamFinalityCoordinatorInventory).interfaceId);
        for (uint256 i = 1; i < 4; ++i) {
            _addr(policyDependencies.targets[i], "core()", c.targets[0]);
        }
        _addr(c.targets[3], "metadataHost()", c.targets[1]);
        _addr(c.targets[3], "tokenInventory()", address(tokens));
        _addr(address(tokens), "core()", c.targets[0]);
        _addr(address(sourceInventory), "scopeMembershipHost()", c.targets[3]);
        _set(address(sourceInventory), "deploymentChainId()", abi.encode(block.chainid));
        _set(address(sourceInventory), "coreCodeHash()", abi.encode(c.codeHashes[0]));
        _set(address(sourceInventory), "scopeMembershipCodeHash()", abi.encode(c.codeHashes[3]));
        facts.scopeSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, c.targets[0], _scope());
        facts.tokenCount = 1;
        facts.membershipHash = keccak256("membership boundary");
        facts.inventoryCount = 1;
        facts.inventoryPrefixHash = keccak256("token prefix");
        FinalityMultiOriginReadTable(c.targets[3])
            .set(
                abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (_scope())),
                abi.encode(facts)
            );
        sourcePlan = keccak256(
            abi.encode(
                keccak256("6529STREAM_COORDINATOR_INVENTORY_PLAN_V1"),
                block.chainid,
                address(sourceInventory),
                c.targets[0],
                c.codeHashes[0],
                c.targets[3],
                c.codeHashes[3],
                _scope(),
                facts
            )
        );
        IStreamFinalityCoordinatorInventory.Coordinator memory row =
            IStreamFinalityCoordinatorInventory.Coordinator(
                address(coordinator), address(coordinator).codehash, 0
            );
        progress = IStreamFinalityCoordinatorInventory.Progress(
            true, true, 1, 1, 1, keccak256("token chain"), bytes32(0), bytes32(0)
        );
        progress.coordinatorChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_COORDINATOR_SOURCE_APPEND_V1"),
                keccak256(
                    abi.encode(keccak256("6529STREAM_COORDINATOR_SOURCE_CHAIN_V1"), sourcePlan)
                ),
                uint256(0),
                row
            )
        );
        progress.commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_COORDINATOR_INVENTORY_COMPLETE_V1"),
                sourcePlan,
                uint256(1),
                uint256(1),
                progress.tokenChain,
                progress.coordinatorChain
            )
        );
        _progress(progress);
        sourceInventory.set(
            abi.encodeCall(IStreamFinalityCoordinatorInventory.inventoryScope, (sourcePlan)),
            abi.encode(_scope(), facts)
        );
        sourceInventory.set(
            abi.encodeCall(IStreamFinalityCoordinatorInventory.requireCoordinator, (sourcePlan, 0)),
            abi.encode(row)
        );
        _support(address(coordinator), type(IStreamEntropyCoordinator).interfaceId);
        _support(address(coordinator), type(IStreamEntropyFinalityPolicy).interfaceId);
        _support(address(coordinator), type(IStreamModule).interfaceId);
        _addr(address(coordinator), "core()", c.targets[0]);
        _set(
            address(coordinator), "streamModuleType()", abi.encode(keccak256("ENTROPY_COORDINATOR"))
        );
        _set(
            address(coordinator),
            "streamModuleInterfaceId()",
            abi.encode(type(IStreamEntropyCoordinator).interfaceId)
        );
        _set(
            address(coordinator),
            "streamModuleCodeHash()",
            abi.encode(address(coordinator).codehash)
        );
        _set(address(coordinator), "streamModuleVersion()", abi.encode(keccak256("version")));
        _set(
            address(coordinator),
            "streamModuleManifest()",
            abi.encode("boundary://original", keccak256("manifest"))
        );
        _set(address(coordinator), "streamModuleSchemaHash()", abi.encode(keccak256("schema")));
        _set(
            address(coordinator),
            "streamModuleDeploymentManifestHash()",
            abi.encode(keccak256("deployment"))
        );
        coordinator.set(
            abi.encodeCall(IERC165.supportsInterface, (Explicit.CAPABILITY)), abi.encode(false)
        );
        _frozen(true);
        sourceFactory = new SourceFactory(policyDependencies);
        c.targets[10] = address(sourceFactory);
        sourceSet = SourceSet(sourceFactory.prepareSourceSet(_scope()));
    }

    function _progress(IStreamFinalityCoordinatorInventory.Progress memory value) private {
        sourceInventory.set(
            abi.encodeCall(
                IStreamFinalityCoordinatorInventory.requireCompleteInventory, (sourcePlan)
            ),
            abi.encode(value)
        );
    }

    function _frozen(bool value) private {
        coordinator.set(
            abi.encodeCall(IStreamEntropyFinalityPolicy.entropyPolicyFrozen, (1)),
            abi.encode(value, keccak256("policy"), address(tokens), uint32(1), keccak256("salt"))
        );
    }

    function _publications() private {
        output = new FinalityMultiOriginReadTable();
        checkpoint = new FinalityMultiOriginReadTable();
        staticSelection = new FinalityMultiOriginReadTable();
        readiness = new FinalityMultiOriginReadTable();
        snapshot.targets = [
            c.targets[0],
            c.targets[1],
            c.targets[4],
            c.targets[5],
            c.targets[2],
            c.targets[3],
            address(staticSelection),
            address(checkpoint),
            address(output),
            c.targets[20],
            address(sourceSet)
        ];
        for (uint256 i; i < 11; ++i) {
            snapshot.codeHashes[i] = snapshot.targets[i].codehash;
        }
        snapshot.chainId = block.chainid;
        snapshot.readGas = 500000;
        snapshot.sourceGas = 2000000;
        snapshot.inventoryGas = 2000000;
        _set(c.targets[8], "dependencies()", abi.encode(snapshot));
        Reference.Dependencies memory ref;
        ref.targets = [
            c.targets[0],
            c.targets[1],
            c.targets[4],
            c.targets[5],
            c.targets[2],
            c.targets[8],
            c.targets[21]
        ];
        for (uint256 i; i < 7; ++i) {
            ref.codeHashes[i] = ref.targets[i].codehash;
        }
        ref.chainId = block.chainid;
        ref.readGas = 500000;
        ref.sourceGas = 2000000;
        ref.snapshotGas = 4000000;
        ref.archiveGas = 2000000;
        _set(c.targets[9], "dependencies()", abi.encode(ref));
        _addr(c.targets[9], "core()", c.targets[0]);
        _addr(c.targets[9], "metadataHost()", c.targets[1]);
        _addr(c.targets[9], "metadataRouter()", c.targets[2]);
        _addr(c.targets[9], "snapshots()", c.targets[8]);
        _addr(c.targets[9], "archiveCoverage()", c.targets[21]);
        _addr(c.targets[8], "core()", c.targets[0]);
        _addr(c.targets[8], "metadataHost()", c.targets[1]);
        _support(c.targets[9], type(IStreamArtworkFinalityComponent).interfaceId);
        _support(c.targets[9], type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _support(c.targets[8], type(Snap).interfaceId);
        _support(c.targets[9], type(Ref).interfaceId);
        _support(address(output), type(Output).interfaceId);
        _support(address(checkpoint), type(Checkpoint).interfaceId);
        _support(address(staticSelection), type(Static).interfaceId);
        _set(
            address(output),
            "outputProfile()",
            abi.encode(keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2"))
        );
        _set(
            address(checkpoint),
            "PROFILE()",
            abi.encode(keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2"))
        );
        _addr(address(output), "core()", c.targets[0]);
        _addr(address(output), "artifactCoverage()", c.targets[20]);
        _addr(address(output), "schemaRegistry()", c.targets[4]);
        _addr(address(output), "contentCheckpoint()", address(checkpoint));
        _set(address(output), "checkpointCodeHash()", abi.encode(address(checkpoint).codehash));
        _set(address(output), "coverageCodeHash()", abi.encode(c.codeHashes[20]));
        _set(address(output), "schemaCodeHash()", abi.encode(c.codeHashes[4]));
        _set(
            address(staticSelection),
            "PROFILE()",
            abi.encode(keccak256("6529STREAM_STATIC_SELECTION_CHECKPOINT_V1"))
        );
        _addr(address(staticSelection), "core()", c.targets[0]);
        _addr(address(staticSelection), "metadataRouter()", c.targets[2]);
        _addr(address(staticSelection), "scopeMembership()", c.targets[3]);
        _addr(address(staticSelection), "metadataHost()", c.targets[1]);
        _set(address(staticSelection), "coreCodeHash()", abi.encode(c.codeHashes[0]));
        _set(address(staticSelection), "routerCodeHash()", abi.encode(c.codeHashes[2]));
        _set(address(staticSelection), "membershipCodeHash()", abi.encode(c.codeHashes[3]));
        _set(address(staticSelection), "metadataCodeHash()", abi.encode(c.codeHashes[1]));
        _addr(address(checkpoint), "core()", c.targets[0]);
        _addr(address(checkpoint), "metadataRouter()", c.targets[2]);
        _addr(address(checkpoint), "selectionCheckpoint()", address(staticSelection));
        _addr(address(checkpoint), "entropySourceSet()", address(sourceSet));
        _addr(address(checkpoint), "terminalReadiness()", address(readiness));
        _set(address(checkpoint), "coreCodeHash()", abi.encode(c.codeHashes[0]));
        _set(address(checkpoint), "routerCodeHash()", abi.encode(c.codeHashes[2]));
        _set(
            address(checkpoint),
            "selectionCodeHash()",
            abi.encode(address(staticSelection).codehash)
        );
        _set(
            address(checkpoint),
            "entropySourceSetCodeHash()",
            abi.encode(address(sourceSet).codehash)
        );
        _set(
            address(checkpoint),
            "terminalReadinessCodeHash()",
            abi.encode(address(readiness).codehash)
        );
        _addr(address(readiness), "core()", c.targets[0]);
        _addr(address(readiness), "metadataRouter()", c.targets[2]);
        _addr(address(readiness), "entropySourceSet()", address(sourceSet));
        _set(address(readiness), "coreCodeHash()", abi.encode(c.codeHashes[0]));
        _set(address(readiness), "metadataRouterCodeHash()", abi.encode(c.codeHashes[2]));
        _set(
            address(readiness),
            "entropySourceSetCodeHash()",
            abi.encode(address(sourceSet).codehash)
        );
        address[5] memory governed = [
            c.targets[8],
            c.targets[9],
            address(output),
            address(checkpoint),
            address(staticSelection)
        ];
        for (uint256 i; i < governed.length; ++i) {
            _addr(governed[i], "governanceAuthority()", address(executor));
        }
        _set(c.targets[8], "authorityCodeHash()", abi.encode(address(executor).codehash));
        _set(c.targets[9], "executorCodeHash()", abi.encode(address(executor).codehash));
    }

    function _candidate() private view returns (T.Receipt memory) {
        return binding.candidate(c, address(output), address(output).codehash);
    }

    function _input() private view returns (bytes memory) {
        return abi.encodeCall(binding.bind, (c, address(output), address(output).codehash));
    }

    function _action(T.Transition memory t, bool executing, bytes32 id, uint8 kind) private {
        executor.set(
            abi.encodeCall(Authority.currentAction, ()),
            abi.encode(executing, id, kind, t.scopeHash, t.oldValueHash, t.newValueHash)
        );
    }

    function _correctAction() private {
        _action(
            binding.transition(c, address(output), address(output).codehash),
            true,
            ACTION,
            T.ACTION_CLASS
        );
    }

    function _refuse(bytes memory input, bytes4 errorId) private {
        (bool ok, bytes memory out) = executor.run(address(binding), input);
        require(!ok && out.length >= 4 && bytes4(out) == errorId, "exact refusal");
        require(binding.bindingHash() == 0, "no partial receipt");
    }

    function _bind() private {
        _correctAction();
        (bool ok, bytes memory out) = executor.run(address(binding), _input());
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
    }

    function testCandidateCanonicalFramingAndActualSourceFactoryReceipt() public view {
        T.Capability memory cap = binding.capability();
        T.Receipt memory r = _candidate();
        require(abi.encode(cap).length == 192 && abi.encode(r).length == 2272);
        require(
            cap.authority == address(executor)
                && cap.originalHash == keccak256(abi.encode(original))
        );
        require(r.capabilityHash == cap.capabilityHash && r.bindingHash == 0 && r.actionId == 0);
        require(r.inventoryPlan == sourcePlan && r.sourceSet == address(sourceSet));
        require(
            r.sourceSetCodeHash == address(sourceSet).codehash
                && r.sourceFactoryDependenciesHash == keccak256(abi.encode(policyDependencies))
        );
        require(
            r.sourceSetDataHash == sourceSet.sourceSetDataHash() && sourceSet.sourceCount() == 1
        );
        require(keccak256(abi.encode(r.scope)) == keccak256(abi.encode(_scope())));
        require(
            keccak256(abi.encode(r.policy)) == keccak256(abi.encode(c))
                && binding.bindingHash() == 0
        );
    }

    function testExactGovernedCommitAndPermanentSecondBindRefusal() public {
        T.Receipt memory proposed = _candidate();
        T.Transition memory t = binding.transition(c, address(output), address(output).codehash);
        _bind();
        T.Receipt memory r = binding.receipt();
        require(r.actionId == ACTION && r.bindingHash == T.receiptHash(r));
        require(T.proposalHash(r) == t.newValueHash && T.proposalHash(proposed) == t.newValueHash);
        bytes32 saved = keccak256(abi.encode(r));
        (bool ok, bytes memory out) = executor.run(address(binding), _input());
        require(
            !ok
                && keccak256(out)
                    == keccak256(abi.encodeWithSelector(T.CollectionPolicyAlreadyBound.selector))
        );
        require(saved == keccak256(abi.encode(binding.receipt())));
    }

    function testLateGovernanceFailureRollsBackThenIdenticalCalldataRetries() public {
        bytes memory input = _input();
        T.Transition memory t = binding.transition(c, address(output), address(output).codehash);
        bytes32 capabilityBefore = keccak256(abi.encode(binding.capability()));
        t.newValueHash = keccak256("wrong scheduled candidate");
        _action(t, true, ACTION, T.ACTION_CLASS);
        _refuse(input, T.CollectionPolicyBindingGovernance.selector);
        require(keccak256(abi.encode(binding.capability())) == capabilityBefore);
        _correctAction();
        (bool ok,) = executor.run(address(binding), input);
        require(ok && binding.receipt().actionId == ACTION);
    }

    function testEveryGovernanceContextFieldIsExactAndSenderAloneInsufficient() public {
        T.Transition memory t = binding.transition(c, address(output), address(output).codehash);
        _action(t, false, ACTION, T.ACTION_CLASS);
        _refuse(_input(), T.CollectionPolicyBindingGovernance.selector);
        _action(t, true, bytes32(0), T.ACTION_CLASS);
        _refuse(_input(), T.CollectionPolicyBindingGovernance.selector);
        _action(t, true, ACTION, 1);
        _refuse(_input(), T.CollectionPolicyBindingGovernance.selector);
        T.Transition memory wrong = t;
        wrong.scopeHash = keccak256("other scope");
        _action(wrong, true, ACTION, T.ACTION_CLASS);
        _refuse(_input(), T.CollectionPolicyBindingGovernance.selector);
        wrong = binding.transition(c, address(output), address(output).codehash);
        wrong.oldValueHash = keccak256("other old state");
        _action(wrong, true, ACTION, T.ACTION_CLASS);
        _refuse(_input(), T.CollectionPolicyBindingGovernance.selector);
        _bind();
    }

    function testCorrectContextFromWrongCallerStillRejects() public {
        _correctAction();
        (bool ok, bytes memory out) = address(binding).call(_input());
        require(
            !ok
                && keccak256(out)
                    == keccak256(
                        abi.encodeWithSelector(T.CollectionPolicyBindingGovernance.selector)
                    )
        );
        require(binding.bindingHash() == 0);
        _bind();
    }

    function testFixedRoleGasAndOutputRuntimeSwapsRejectedBeforeCommit() public {
        Native.Config memory wrong = abi.decode(abi.encode(c), (Native.Config));
        wrong.targets[0] = address(output);
        wrong.codeHashes[0] = address(output).codehash;
        _refuse(
            abi.encodeCall(binding.bind, (wrong, address(output), address(output).codehash)),
            T.InvalidCollectionPolicyBinding.selector
        );
        wrong = abi.decode(abi.encode(c), (Native.Config));
        wrong.readGas += 1;
        _refuse(
            abi.encodeCall(binding.bind, (wrong, address(output), address(output).codehash)),
            T.InvalidCollectionPolicyBinding.selector
        );
        _refuse(
            abi.encodeCall(binding.bind, (c, address(output), keccak256("wrong runtime"))),
            T.CollectionPolicyBindingDependency.selector
        );
        _bind();
    }

    function testMissingInterfaceAndWrongOutputCheckpointJoinRejectRetry() public {
        output.set(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(true)
        );
        _refuse(_input(), T.CollectionPolicyBindingDependency.selector);
        _support(address(output), type(Output).interfaceId);
        _addr(address(output), "contentCheckpoint()", address(staticSelection));
        _refuse(_input(), Validation.NativeProviderSource.selector);
        _addr(address(output), "contentCheckpoint()", address(checkpoint));
        _bind();
    }

    function testFullOriginalAuthorityAndOriginCapabilitiesCannotSwap() public {
        D.Dependencies memory changed = ad;
        changed.resolverGas += 1;
        inventory.set(abi.encodeWithSignature("authorityDependencies()"), abi.encode(changed));
        _refuse(_input(), T.InvalidCollectionPolicyBinding.selector);
        inventory.set(abi.encodeWithSignature("authorityDependencies()"), abi.encode(ad));
        O.Dependencies memory origin = od;
        origin.originGas += 1;
        inventory.set(abi.encodeWithSignature("originDependencies()"), abi.encode(origin));
        _refuse(_input(), T.InvalidCollectionPolicyBinding.selector);
        inventory.set(abi.encodeWithSignature("originDependencies()"), abi.encode(od));
        _bind();
    }

    function testMutableOriginalPolicyOrIncompleteInventoryCannotBind() public {
        _correctAction();
        _frozen(false);
        (bool ok,) = executor.run(address(binding), _input());
        require(!ok && binding.bindingHash() == 0);
        _frozen(true);
        IStreamFinalityCoordinatorInventory.Progress memory incomplete = progress;
        incomplete.complete = false;
        _progress(incomplete);
        (ok,) = executor.run(address(binding), _input());
        require(!ok && binding.bindingHash() == 0);
        _progress(progress);
        _bind();
    }

    function testWrongReadinessAndOriginalCoordinatorRuntimeRefuse() public {
        _addr(address(readiness), "entropySourceSet()", address(sourceFactory));
        _refuse(_input(), T.CollectionPolicyBindingDependency.selector);
        _addr(address(readiness), "entropySourceSet()", address(sourceSet));
        _correctAction();
        vm.etch(address(coordinator), hex"00");
        (bool ok,) = executor.run(address(binding), _input());
        require(!ok && binding.bindingHash() == 0);
    }

    function testMalformedActionReturnDoesNotPublishReceipt() public {
        T.Transition memory t = binding.transition(c, address(output), address(output).codehash);
        executor.set(
            abi.encodeCall(Authority.currentAction, ()),
            abi.encode(
                true,
                ACTION,
                T.ACTION_CLASS,
                t.scopeHash,
                t.oldValueHash,
                t.newValueHash,
                uint256(0)
            )
        );
        (bool ok,) = executor.run(address(binding), _input());
        require(!ok && binding.bindingHash() == 0);
        executor.set(
            abi.encodeCall(Authority.currentAction, ()),
            abi.encode(
                uint256(2), ACTION, T.ACTION_CLASS, t.scopeHash, t.oldValueHash, t.newValueHash
            )
        );
        (ok,) = executor.run(address(binding), _input());
        require(!ok && binding.bindingHash() == 0);
        _bind();
    }

    function testFuzzReceiptActionAvoidsCircularStateHashButBindsReceipt(bytes32 actionId)
        public
        view
    {
        T.Receipt memory r = _candidate();
        bytes32 proposal = T.proposalHash(r);
        bytes32 previousReceipt = T.receiptHash(r);
        r.actionId = actionId;
        r.bindingHash = keccak256("irrelevant stored digest");
        require(T.proposalHash(r) == proposal);
        require(T.receiptHash(r) == keccak256(abi.encode(T.RECEIPT_DOMAIN, proposal, actionId)));
        if (actionId != 0) require(T.receiptHash(r) != previousReceipt);
        r.sourceSetDataHash = keccak256(abi.encode(r.sourceSetDataHash, uint256(1)));
        require(T.proposalHash(r) != proposal);
    }
}
