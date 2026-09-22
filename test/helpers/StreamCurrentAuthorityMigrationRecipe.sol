// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCurrentGraphKinds } from "../../script/current/StreamCurrentGraphKinds.sol";
import "./StreamCurrentAuthorityNativeAssemblyFixture.sol";
import {
    IStreamRightsRecordCurrentAuthority as MigrationRightsAuthority
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRightsRecordCurrentAuthority.sol";
import { StreamCurrentAuthorityRecoveryRecipe } from "./StreamCurrentAuthorityRecoveryRecipe.sol";
import {
    StreamCurrentAuthoritySuccessorCoordinatorGraph
} from "../../script/current/StreamCurrentAuthoritySuccessorCoordinatorGraph.sol";
import {
    StreamArtistCurrentAuthorityTypes as CA
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as AuthorityOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as AuthorityRecoveredTypes
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydration as AuthorityRecoveredEntry,
    IStreamArtistRecoveredHydrationOwner as RecoveredOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistHistory as History,
    StreamArtistHistoryTypes as HT
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @dev Actual ordinary successor Finality/Coordinator prefix. Preservation products remain original.
contract CurrentAuthoritySuccessorGraph is StreamCurrentAuthoritySuccessorCoordinatorGraph {
    address private immutable caller = msg.sender;

    function _graphCreation(StreamCurrentGraphKinds.Kind kind)
        internal
        view
        override
        returns (bytes memory)
    {
        return StreamNativeAssemblyCreation.creation(
            StreamNativeAssemblyCreation.Kind(uint256(kind))
        );
    }

    function construct(
        T.SuiteConfiguration memory s,
        address modules,
        address executor_,
        address manifest_,
        address coverage,
        address checkpoint,
        bytes32 deployment
    ) external returns (T.SuiteConfiguration memory, StreamArtistOnboardingCoordinator) {
        require(msg.sender == caller, "test graph caller");
        address predecessor = s.registry;
        address coordinator = _reserveCurrentCoordinator(address(this));
        StreamArtistExtensionFactory extensions = new StreamArtistExtensionFactory(
            [
                address(new StreamArtistIdentityCreationPart(0)),
                address(new StreamArtistIdentityCreationPart(1)),
                address(new StreamArtistEstateCreationPart(0)),
                address(new StreamArtistEstateCreationPart(1))
            ]
        );
        StreamArtistOnboardingRegistry successor = _deploySplitArtistFacade(
            _graphCreation(StreamCurrentGraphKinds.Kind.StreamArtistOnboardingRegistry),
            address(this),
            address(extensions),
            [s.core, s.mintManager, coordinator, executor_, coverage],
            deployment,
            "urn:current:authority-successor",
            keccak256("current authority successor module")
        );
        s.registry = address(successor);
        s.archive = address(new StreamArtistArchiveV2(s.registry, coordinator));
        s.owners[0] = address(
            new StreamArtistBindingLifecycle(
                s.registry, coordinator, s.archive, s.core, s.mintManager
            )
        );
        s.owners[1] = address(
            new StreamArtistCollaboratorLifecycle(
                s.registry, coordinator, s.archive, s.core, s.mintManager
            )
        );
        s.owners[2] = _deploySplitArtistIdentity(
            _graphCreation(StreamCurrentGraphKinds.Kind.StreamArtistIdentityAuthority),
            address(this),
            address(extensions),
            [s.registry, coordinator, s.archive, s.core, s.mintManager]
        );
        s.owners[3] = address(
            new StreamArtistAcceptanceLifecycle(
                s.registry, coordinator, s.archive, s.core, s.mintManager
            )
        );
        s.owners[4] = address(
            new StreamArtistAttributionLifecycle(
                s.registry, coordinator, s.archive, s.core, s.mintManager
            )
        );
        s.owners[5] = address(
            new StreamArtistPayoutLifecycle(
                s.registry, coordinator, s.archive, s.core, s.mintManager
            )
        );
        s.owners[6] = address(
            new StreamArtistConsentFinalityLifecycle(
                s.registry, coordinator, s.archive, s.core, s.mintManager
            )
        );
        _bindCurrentAuthoritySuccessorGraph(
            s,
            predecessor,
            predecessor.codehash,
            modules,
            executor_,
            manifest_,
            coverage,
            checkpoint,
            deployment
        );
        _completeCurrentAuthoritySuccessorCoordinator(_currentGraphRendererCatalog(1));
        return (s, assemblyCoordinator);
    }
}

/// @notice Actual repeated history admission, governed selection and complete seven-owner import.
/// @dev Native execution is required before claiming this composed recipe works. The original
/// assembly's ratification52 requires the separately owned explicit recovered ratification codec.
abstract contract StreamCurrentAuthorityMigrationRecipe is StreamCurrentAuthorityRecoveryRecipe {
    bytes32 internal constant AUTHORITY_POINTER = keccak256("ARTIST_REGISTRY");
    string internal constant AUTHORITY_MIGRATION_URI =
        "urn:current:authority-preservation-migration";
    bytes32 internal constant AUTHORITY_MIGRATION_REASON =
        keccak256(bytes(AUTHORITY_MIGRATION_URI));
    T.SuiteConfiguration internal authorityOriginalSuite;
    bytes32 internal authorityOriginalAnchorsHash;
    bytes32 internal authorityOriginalSelectionsHash;
    bytes32 internal authorityOriginalPresentationHash;
    address[3] internal authorityRegistries;
    address[3] internal authorityCoordinators;
    bytes32[3] internal authorityConfigurations;
    address[3] internal authorityOwnFinalities;
    address[3] internal authorityOwnProviders;
    uint256 internal authorityEra;

    function _authorityPrepareOriginalPreservation() internal {
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        _authorityRecoverOriginal();
        _assemblyPrepareDescriptionDefinitions();
        _assemblyPublishOriginalRoot();
        _assemblySelectDescriptionsAndWaiver();
        _assemblyPublishAndLockSnapshot();
        _assemblyPrepareReferenceDefinitions();
        _assemblyPublishReference(
            assemblyVm.readFile("test/fixtures/native-assembly/reference-environment.json"),
            assemblyVm.readFile("test/fixtures/native-assembly/reference-browser-endpoints.json"),
            assemblyVm.readFile("test/fixtures/native-assembly/reference-captures.json")
        );
        _assemblyPrepareCeremonyDefinitions();
        _authorityCaptureOriginalPreservation();
    }

    /// @dev Other genuine publication profiles retain these same collection selector invariants.
    function _authorityCaptureOriginalPreservation() internal {
        authorityOriginalSuite = assemblySuite;
        authorityOriginalAnchorsHash = keccak256(abi.encode(assemblyAuthorityResolver.anchors()));
        authorityOriginalSelectionsHash = _authoritySelectionsHash();
        authorityOriginalPresentationHash =
            keccak256(abi.encode(assemblyRouter.artistPresentation(1)));
        _authorityRememberCoordinator(0);
        _authorityRequireOriginals();
        _authorityRequireRoute();
    }

    function _authorityRememberCoordinator(uint256 era) private {
        authorityRegistries[era] = address(assemblyArtists);
        authorityCoordinators[era] = address(assemblyCoordinator);
        authorityConfigurations[era] = assemblyCoordinator.configurationHash();
        authorityOwnFinalities[era] = assemblyCoordinator.finalityRegistry();
        authorityOwnProviders[era] = assemblyCoordinator.finalityEvidenceProvider();
        require(
            authorityOwnFinalities[era] != address(0) && authorityOwnProviders[era] != address(0),
            "actual immutable private Finality admission"
        );
    }

    function _authorityMigrateNext() internal {
        require(authorityEra < 2, "two real unpredicted successors");
        T.SuiteConfiguration memory source = assemblySuite;
        // C is allocated only after B completed and became the actual selected authority.
        // No original resolver, selector, inventory or provider receives this new address.
        CurrentAuthoritySuccessorGraph graph = new CurrentAuthoritySuccessorGraph();
        (T.SuiteConfiguration memory destination, StreamArtistOnboardingCoordinator coordinator) = graph.construct(
            source,
            address(assemblyModules),
            address(assemblyExecutor),
            address(assemblyManifest),
            address(assemblyArchive),
            address(assemblyCheckpointVerifier),
            ASSEMBLY_DEPLOYMENT
        );
        require(
            destination.registry != source.registry && destination.registry.code.length != 0
                && StreamCurrentStackPlan.readPointer(assemblyCore, AUTHORITY_POINTER).target
                    == source.registry,
            "actual successor constructed without selecting it"
        );
        _authorityRegister(destination.registry);
        HT.Leaf[] memory leaves = _authorityBindHistory(source.registry, destination.registry);
        _authoritySelect(destination.registry);
        _authorityVerifyAndObserve(source.registry, destination.registry, leaves);
        (bool selected,) = address(assemblyAuthorityResolver)
            .staticcall(abi.encodeCall(assemblyAuthorityResolver.currentSelection, ()));
        require(!selected, "actual pointer alone cannot authorize incomplete successor");

        AuthorityRecoveredTypes.Request memory request = _authorityRequest(source);
        Commit.Prepared memory prepared = Prepared.prepare(destination, request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 sourceBefore = _authorityOwnerState(source);
        _authoritySafeCall(
            destination.registry,
            abi.encodeCall(AuthorityRecoveredEntry.hydrateRecoveredArtistAuthority, (request))
        );
        require(
            _authorityOwnerState(source) == sourceBefore, "import leaves actual source unchanged"
        );
        _authorityAssertImport(destination, prepared);
        assemblySuite = destination;
        assemblyArtists = StreamArtistOnboardingRegistry(payable(destination.registry));
        assemblyCoordinator = coordinator;
        assemblyArtistNonce =
        IStreamArtistIdentityOwner(destination.owners[2]).identity(assemblyArtistId).nonceHint;
        ++authorityEra;
        _authorityRememberCoordinator(authorityEra);
        require(
            authorityOwnFinalities[authorityEra] != address(assemblyFinality)
                && authorityOwnProviders[authorityEra] != address(assemblyProvider),
            "successor immutable F/P remain its own original counterparts"
        );
        _authorityRequireOriginals();
        _authorityRequireRoute();
    }

    function _authorityRegister(address successor) private {
        StreamModuleRegistration[] memory rows = new StreamModuleRegistration[](1);
        rows[0] = _authorityModule(successor);
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(assemblyModules, rows);
        _authorityRun(GenesisBatch(1, calls, data));
    }

    function _authorityModule(address successor)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        return _assemblyModule(
            successor,
            AUTHORITY_POINTER,
            type(IStreamArtistMintConsent).interfaceId,
            keccak256(abi.encode("current authority successor", successor))
        );
    }

    function _authorityRun(GenesisBatch memory batch) private returns (bytes32 action) {
        _admitAssemblyBatch(batch);
        action = _assemblyGovernance(batch, AUTHORITY_MIGRATION_URI);
    }

    function _authoritySelect(address successor) private {
        StreamCorePointerState memory old =
            StreamCurrentStackPlan.readPointer(assemblyCore, AUTHORITY_POINTER);
        StreamCorePointerState memory next = StreamCurrentStackPlan.pointerState(
            address(assemblyModules), _authorityModule(successor), false, old.revision + 1
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) = StreamCurrentStackPlan.pointerTransitionHashes(
            assemblyCore, AUTHORITY_POINTER, old, next
        );
        GenesisBatch memory batch;
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        batch.callDatas[0] =
            abi.encodeCall(assemblyCore.updateSatellitePointer, (AUTHORITY_POINTER, successor));
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(assemblyCore), batch.callDatas[0], scope, before_, after_
        );
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(assemblyManifest).modules;
        modules.artistRegistry = successor;
        (batch.calls[1], batch.callDatas[1]) =
            _assemblyPublishManifest(modules, AUTHORITY_MIGRATION_REASON);
        _authorityRun(batch);
        StreamCorePointerState memory actual =
            StreamCurrentStackPlan.readPointer(assemblyCore, AUTHORITY_POINTER);
        require(
            actual.target == successor && actual.codeHash == successor.codehash
                && actual.registryStatus == 1,
            "actual admitted Core pointer selected successor"
        );
        require(
            StreamGenesisManifestPlan.readAggregate(assemblyManifest).modules.artistRegistry
                == successor,
            "actual manifest tail agrees with cutover"
        );
    }

    function _authorityBindHistory(address source, address destination)
        private
        returns (HT.Leaf[] memory leaves)
    {
        leaves = _authorityLeaves(source);
        (bytes32 root,) = _authorityProof(source, leaves, 0);
        HT.Binding memory binding_ =
            HT.Binding(source, uint64(block.number), root, AUTHORITY_MIGRATION_REASON);
        HT.Context memory context_ = History(destination)
            .artistHistoryImportContext(
                source, binding_.snapshotBlock, root, AUTHORITY_MIGRATION_REASON
            );
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = abi.encodeCall(
            History.commitArtistHistoryImportRoot,
            (source, binding_.snapshotBlock, root, AUTHORITY_MIGRATION_REASON)
        );
        batch.calls[0] = StreamCurrentStackPlan.call(
            destination,
            batch.callDatas[0],
            context_.scopeHash,
            context_.oldValueHash,
            context_.newValueHash
        );
        bytes32 action = _authorityRun(batch);
        (bool committed, bytes32 hash, uint256 count) =
            History(destination).artistHistoryPredecessorBinding(source);
        require(
            committed && hash == source.codehash && count == 1,
            "actual original55 predecessor admission"
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.governance_action",
            keccak256(
                abi.encode(action, context_.scopeHash, context_.oldValueHash, context_.newValueHash)
            )
        );
        _authorityCandidate(
            2, "identity_authority.replay.import_binding_key", keccak256(abi.encode(binding_))
        );
    }

    function _authorityVerifyAndObserve(
        address source,
        address destination,
        HT.Leaf[] memory leaves
    ) private {
        (, uint64 count) = History(source).artistHistoryLane(1, assemblyArtistId);
        _authorityVerify(destination, source, leaves, count - 1);
        _authorityVerify(destination, source, leaves, leaves.length - 1);
        _authoritySafeCall(source, abi.encodeCall(History.observeRegistryCutover, ()));
        _authorityCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        (bool observed, address next,) = History(source).artistRegistryCutover();
        require(observed && next == destination, "actual source57 terminal cutover");
    }

    function _authorityVerify(
        address destination,
        address source,
        HT.Leaf[] memory leaves,
        uint256 index
    ) private {
        (, bytes32[] memory proof) = _authorityProof(source, leaves, index);
        HT.Leaf memory row = leaves[index];
        _authoritySafeCall(
            destination, abi.encodeCall(History.verifyImportedLaneTip, (uint256(0), row, proof))
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.verified_lane_key",
            keccak256(abi.encode(row.laneKind, row.laneKey))
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.import_binding",
            keccak256(abi.encode(uint256(0), row.laneKind, row.laneKey))
        );
    }

    function _authoritySafeCall(address target, bytes memory data) private {
        uint256 nonce = assemblyArtist.nonce();
        require(
            executeSafe(assemblyArtist, assemblyArtistKeys, target, 0, data, 0),
            "actual recovered threshold Safe call"
        );
        require(assemblyArtist.nonce() == nonce + 1, "exact actual Safe transaction consumed");
    }

    function _authorityRequest(T.SuiteConfiguration memory source)
        private
        view
        returns (AuthorityRecoveredTypes.Request memory p)
    {
        p.records.authority.artistIds = new bytes32[](1);
        p.records.authority.artistIds[0] = assemblyArtistId;
        p.records.authority.collections = new MH.Collection[](1);
        p.records.authority.collections[0] = MH.Collection(assemblyArtistId, 1, authorityPolicies);
        p.records.witnesses = new MR.CollectionWitness[](1);
        p.records.witnesses[0] = MR.CollectionWitness(1, authorityEconomics, authorityAttestations);
        p.expectedSourceImportCommitment =
            AuthorityOwner(source.owners[2]).authorityHydrationCommitment();
        AuthorityRecoveredTypes.OriginEnvironment memory environment = _authorityEnvironment(source);
        for (uint8 i; i < 7; ++i) {
            p.expectedCapabilities[i] =
                RecoveredOwner(source.owners[i]).recoveredAuthorityHydrationCapability();
            CP.Checkpoint memory cp = CP(source.owners[i]).authorityCheckpoint();
            p.records.authority.expectedSource[i] = cp;
            p.records.authority.replayOrigins[i] = new AH.Origin[](cp.replayCount);
            for (uint256 j; j < cp.replayCount; ++j) {
                (bytes32 key,) = CP(source.owners[i]).authorityReplayAt(j);
                bool found;
                for (uint256 k; k < authorityCandidates[i].length; ++k) {
                    AH.Origin memory origin = authorityCandidates[i][k];
                    if (Guards.replayKey(environment, i, origin) != key) continue;
                    p.records.authority.replayOrigins[i][j] = origin;
                    found = true;
                    break;
                }
                require(found, "every actual source guard has its literal writer preimage");
            }
        }
    }

    function _authorityEnvironment(T.SuiteConfiguration memory suite)
        private
        view
        returns (AuthorityRecoveredTypes.OriginEnvironment memory e)
    {
        e.chainId = block.chainid;
        e.registry = suite.registry;
        e.coordinator =
            StreamArtistOnboardingRegistry(payable(suite.registry)).operationCoordinator();
        e.archive = suite.archive;
        e.owners = suite.owners;
        for (uint256 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        e.core = suite.core;
        e.manager = suite.mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(suite));
    }

    function _authorityOwnerState(T.SuiteConfiguration memory suite)
        private
        view
        returns (bytes32 value)
    {
        for (uint8 i; i < 7; ++i) {
            CP.Checkpoint memory cp = CP(suite.owners[i]).authorityCheckpoint();
            value = keccak256(
                abi.encode(
                    value,
                    cp,
                    Publications.collect(suite.owners[i], i),
                    Guards.collectNonces(suite.owners[i], cp),
                    IStreamArtistNativeReceipts(suite.owners[i]).artistNativeReceiptCount(),
                    AuthorityOwner(suite.owners[i]).authorityHydrationCommitment()
                )
            );
        }
        return keccak256(
            abi.encode(value, History(suite.owners[2]).artistHistoryContinuityCommitment())
        );
    }

    function _authorityAssertImport(
        T.SuiteConfiguration memory destination,
        Commit.Prepared memory prepared
    ) private view {
        bytes32 completion = AuthorityOwner(destination.owners[2]).authorityHydrationCommitment();
        require(completion != 0, "actual atomic recovered completion");
        for (uint8 i; i < 7; ++i) {
            address owner = destination.owners[i];
            T.Snapshot memory now_ = IStreamArtistOwner(owner).ownerStateSnapshotV2();
            require(
                now_.revision == prepared.admission.before_[i].revision + 1
                    && now_.recordChainTip == prepared.admission.before_[i].recordChainTip
                    && AuthorityOwner(owner).authorityHydrationCommitment() == completion,
                "seven exact original owner commits"
            );
            require(
                IStreamArtistNativeReceipts(owner).artistNativeReceiptCount() == 0,
                "import does not fabricate native receipts"
            );
            (
                AuthorityRecoveredTypes.OwnerProvenance memory prefix,
                bytes32 imported,
                uint64 revision
            ) = RecoveredOwner(owner).recoveredHydrationImportedPrefix();
            require(
                imported == completion && revision == now_.revision
                    && keccak256(abi.encode(prefix))
                        == keccak256(
                            abi.encode(
                                AuthorityRecoveredTypes.ownerProvenance(
                                    prepared.admission.provenance, i
                                )
                            )
                        ),
                "exact original flattened provenance"
            );
            (, Payload.Payload memory payload) = Payload.decode(prepared.data[i].typedState, i);
            require(
                keccak256(abi.encode(Publications.collect(owner, i)))
                    == keccak256(abi.encode(payload.publications)),
                "all original publication catalogs retained"
            );
        }
    }

    function _authorityRequireRoute() internal view {
        CA.Route memory original = assemblyAuthorityResolver.currentFinalityRoute(1);
        CA.Route memory finality = assemblyFinality.currentArtistAuthority(1);
        CA.Route memory coordinator = assemblyCoordinator.currentFinalityRoute(1);
        require(
            keccak256(abi.encode(original)) == keccak256(abi.encode(finality))
                && keccak256(abi.encode(original)) == keccak256(abi.encode(coordinator)),
            "actual resolver Finality and current Coordinator agree without recursion"
        );
        require(
            original.registry == address(assemblyArtists)
                && original.coordinator == address(assemblyCoordinator)
                && original.finalityRegistry == address(assemblyFinality)
                && original.provider == address(assemblyProvider),
            "fresh current route uses original preserved F/P"
        );
        for (uint256 i; i <= authorityEra; ++i) {
            StreamArtistOnboardingCoordinator saved =
                StreamArtistOnboardingCoordinator(authorityCoordinators[i]);
            require(
                saved.configurationHash() == authorityConfigurations[i]
                    && saved.finalityRegistry() == authorityOwnFinalities[i]
                    && saved.finalityEvidenceProvider() == authorityOwnProviders[i],
                "every Coordinator retains its original immutable getters and configuration"
            );
        }
    }

    function _authorityRequireOriginals() internal view {
        require(
            keccak256(abi.encode(assemblyAuthorityResolver.anchors()))
                == authorityOriginalAnchorsHash,
            "no original anchor configuration rewritten"
        );
        require(
            assemblyMetadata.artistRegistry() == authorityOriginalSuite.registry
                && address(assemblyFinality.sanctionReads()) == authorityOriginalSuite.registry
                && assemblyArtifact.finalityRegistry() == address(assemblyFinality)
                && assemblyFinality.scopeEvidenceProvider() == address(assemblyProvider),
            "Metadata Finality Artifact and provider original reciprocals retained"
        );
        require(
            keccak256(abi.encode(assemblyRouter.artistPresentation(1)))
                == authorityOriginalPresentationHash,
            "locked original Router presentation bytes unchanged"
        );
        require(
            _authoritySelectionsHash() == authorityOriginalSelectionsHash,
            "same-instance original selector history catalogs seals and hashes retained"
        );
        assemblyWork.requireCurrent(1, _assemblySubject(), assemblyWorkRecord, 1);
        assemblyRights.requireCurrent(1, _assemblySubject(), assemblyRightsRecord, 1);
        require(
            assemblyRights.currentAuthorityProfile()
                    == keccak256("6529STREAM_CURRENT_AUTHORITY_RIGHTS_SELECTION_V1")
                && assemblyRights.supportsInterface(type(MigrationRightsAuthority).interfaceId)
                && address(assemblyRights) == assemblyLate[uint256(Late.RIGHTS)]
                && address(assemblyRights).codehash
                    == keccak256(assemblyRuntimes[uint256(Late.RIGHTS)]),
            "original graph bound the admitted current-authority RIGHTS runtime at genesis"
        );
        (address[3] memory rightsTargets, bytes32[3] memory rightsCodeHashes) =
            assemblyRights.currentArtistIdentityContext();
        address[3] memory expectedRightsTargets =
            [address(assemblyArtists), address(assemblyCoordinator), assemblySuite.owners[2]];
        for (uint256 i; i < 3; ++i) {
            require(
                rightsTargets[i] == expectedRightsTargets[i]
                    && rightsCodeHashes[i] == expectedRightsTargets[i].codehash,
                "same original RIGHTS selector authenticates actual current A/B/C identity"
            );
        }
        assemblyConservation.requireCurrent(
            1,
            _assemblySubject(),
            StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT,
            assemblyWaiverRecord,
            1
        );
    }

    function _authoritySelectionsHash() private view returns (bytes32 value) {
        bytes32 subject = _assemblySubject();
        StreamConservationRecordTypes.StatementOrigin origin =
        StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT;
        value = keccak256(
            abi.encode(
                address(assemblyWork),
                address(assemblyRights),
                address(assemblyConservation),
                assemblyWork.currentWork(1, subject),
                assemblyWork.workSelectionAt(1, subject, 1),
                assemblyWork.selectionLock(1, subject),
                assemblyRights.currentRights(1, subject),
                assemblyRights.rightsSelectionAt(1, subject, 1),
                assemblyRights.selectionLock(1, subject),
                assemblyConservation.currentConservation(1, subject, origin),
                assemblyConservation.conservationSelectionAt(1, subject, origin, 1),
                assemblyConservation.intentLock(1, subject)
            )
        );
        uint256 count = assemblyConservation.selectionCatalogCount(1, subject, origin, 1);
        value = keccak256(abi.encode(value, count));
        for (uint256 i; i < count; ++i) {
            value = keccak256(
                abi.encode(value, assemblyConservation.selectionCatalogAt(1, subject, origin, 1, i))
            );
        }
    }

    function _authorityLeaves(address source) private view returns (HT.Leaf[] memory rows) {
        History h = History(source);
        (, uint64 a) = h.artistHistoryLane(1, assemblyArtistId);
        (, uint64 b) = h.artistHistoryLane(2, bytes32(uint256(1)));
        require(a != 0 && b != 0, "actual nonempty artist and collection histories");
        rows = new HT.Leaf[](uint256(a) + b);
        for (uint64 i; i < a; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(1, assemblyArtistId, i);
            rows[i] = HT.Leaf(1, assemblyArtistId, i, r, c);
        }
        for (uint64 i; i < b; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(2, bytes32(uint256(1)), i);
            rows[uint256(a) + i] = HT.Leaf(2, bytes32(uint256(1)), i, r, c);
        }
    }

    function _authorityProof(address source, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            HT.Leaf memory p = leaves[i];
            layer[i] = keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            bytes32(
                                0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d
                            ),
                            block.chainid,
                            source,
                            p.laneKind,
                            p.laneKey,
                            p.sequence,
                            p.recordHash,
                            p.recordChainHash
                        )
                    )
                )
            );
        }
        while (n > 1) {
            if ((index ^ 1) < n) proof[used++] = layer[index ^ 1];
            uint256 nextN = (n + 1) / 2;
            for (uint256 i; i < nextN; ++i) {
                uint256 j = i * 2;
                if (j + 1 == n) {
                    layer[i] = layer[j];
                } else {
                    bytes32 a = layer[j];
                    bytes32 b = layer[j + 1];
                    layer[i] = a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
                }
            }
            index /= 2;
            n = nextN;
        }
        root = layer[0];
        assembly ("memory-safe") { mstore(proof, used) }
    }
}
