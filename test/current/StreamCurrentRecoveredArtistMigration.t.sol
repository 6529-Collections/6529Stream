// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCurrentGraphKinds } from "../../script/current/StreamCurrentGraphKinds.sol";
import {
    StreamArtistExtensionFactory
} from "../../smart-contracts/domains/artist/StreamArtistExtensionFactory.sol";
import {
    StreamArtistIdentityCreationPart
} from "../../smart-contracts/domains/artist/StreamArtistIdentityCreationPart.sol";
import {
    StreamArtistEstateCreationPart
} from "../../smart-contracts/domains/artist/StreamArtistEstateCreationPart.sol";
import {
    StreamArtistArchiveV2
} from "../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import {
    IStreamWorkRecordSelection as MigrationWork
} from "../../smart-contracts/interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import {
    IStreamRightsRecordSelection as MigrationRights
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRightsRecordSelection.sol";
import {
    IStreamConservationRecordSelection as MigrationConservation
} from "../../smart-contracts/interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import {
    StreamArtistRecoveredHydrationTypes as MigrationHydration
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydration as MigrationRecovered,
    IStreamArtistRecoveredHydrationOwner as RecoveredOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistOwner as Owner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
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
import {
    IStreamArtistRecoveredTimingInventory
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as MigrationRecovery
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistRotationTypes as MigrationRotation
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecoveryActionTypes as MigrationAction
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    IStreamArtistIdentityRecovery as MigrationRecoveryRegistry
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistRecoveryAction as MigrationActionRegistry
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    IStreamArtistNativeReceipts as MigrationNative
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

/// @dev Original source recovery uses the real sealed Executor and threshold Safes.
abstract contract CurrentRecoveredSourceRecipe is StreamCurrentSafeGovernanceFixture {
    OfficialSafe internal artistSafe;
    OfficialSafe internal recoveredSafe;
    uint256[] internal artistKeys;
    uint256[] internal recoveredKeys;
    bytes32 internal migrationSourceGuardian;
    bytes32 internal migrationSourceAction;

    function _candidate(uint8 owner, string memory surface, bytes32 scope) internal virtual;
    function _authorizationCandidate(bytes32 digest, uint256 nonce) internal virtual;

    function _recoverSource() internal returns (bytes32 record) {
        T.Identity memory principal =
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId);
        require(
            principal.authorityAddress == address(artistSafe) && principal.authorityClass == 1
                && principal.status == 1 && address(recoveredSafe) != address(artistSafe),
            "original live class1 Safe source"
        );
        bytes32 arbiter = keccak256("ROLE_ATTRIBUTION_ARBITER");
        if (!roles.hasRole(arbiter, address(governorSafe))) {
            _setRole(arbiter, address(governorSafe), true);
        }
        _migrationGuardian();
        _migrationCompromise();
        return _migrationRecovery();
    }

    function _migrationGuardian() private {
        address[] memory members = new address[](1);
        members[0] = address(governorSafe);
        MigrationRotation.GuardianSet memory terms =
            MigrationRotation.GuardianSet(fixtureArtistId, members, 1, 10 days);
        T.Authorization memory authorization = T.Authorization(
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        bytes32 digest = artists.guardianSetDigest(terms, authorization);
        _authorizationCandidate(digest, authorization.nonce);
        authorization.signature =
            safeThresholdSignature(artistKeys, safeMessageDigest(artistSafe, abi.encode(digest)));
        require(
            executeSafe(
                artistSafe,
                artistKeys,
                address(artists),
                0,
                abi.encodeCall(artists.setArtistGuardians, (terms, authorization)),
                0
            ),
            "actual source Safe guardian28"
        );
        (,,, migrationSourceGuardian) = artists.guardianSet(fixtureArtistId);
        MigrationRotation.GuardianRecord memory stored =
            artists.guardianSetRecord(migrationSourceGuardian);
        require(
            stored.recordHash != 0 && stored.signer == address(artistSafe)
                && stored.nonce == authorization.nonce && stored.authorityClass == 1,
            "exact source guardian record"
        );
        _candidate(
            2,
            "identity_authority.replay.guardian_set_chain",
            keccak256(abi.encode(fixtureArtistId, authorization.nonce))
        );
    }

    function _migrationCompromise() private {
        bytes32 evidence = keccak256("current recovered migration source compromise");
        (bytes32 scope, bytes32 oldState, bytes32 newState) = artists.identityContestGovernanceContext(
            fixtureArtistId, bytes32(0), evidence, GOVERNANCE_REASON
        );
        _govern(
            _governanceRequest(
                1,
                address(artists),
                abi.encodeCall(
                    artists.contestArtistIdentity,
                    (fixtureArtistId, bytes32(0), evidence, GOVERNANCE_REASON)
                ),
                scope,
                oldState,
                newState
            )
        );
        bytes32 contest = artists.currentIdentityContestCause(fixtureArtistId).facts.referenceHash;
        require(
            contest != 0
                && IStreamArtistIdentityOwner(artistSuite.owners[2])
                    .identity(fixtureArtistId)
                    .status == 4,
            "actual Executor compromise33"
        );
        _candidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(
                abi.encode(
                    keccak256("subject"), fixtureArtistId, bytes32(0), evidence, GOVERNANCE_REASON
                )
            )
        );
        _candidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("record"), contest))
        );
    }

    function _migrationRecovery() private returns (bytes32 record) {
        MigrationRecovery.Request memory request = MigrationRecovery.Request(
            fixtureArtistId,
            address(recoveredSafe),
            1,
            artists.currentIdentityContestCause(fixtureArtistId).causeHash,
            artists.latestIdentityContestDismissal(fixtureArtistId),
            keccak256("current recovered migration source recovery"),
            GOVERNANCE_REASON,
            new bytes32[](0)
        );
        (, uint256 acceptanceNonce) =
            artists.rotationAcceptanceNonceState(fixtureArtistId, address(recoveredSafe), 0);
        T.Authorization memory acceptance = T.Authorization(
            acceptanceNonce, uint64(block.timestamp + executor.minimumDelay(2) + 7 days), ""
        );
        bytes32 digest = artists.rotationAcceptanceDigest(
            MigrationRotation.Rotation(
                fixtureArtistId,
                address(artistSafe),
                address(recoveredSafe),
                GOVERNANCE_REASON,
                bytes32(0)
            ),
            acceptance
        );
        acceptance.signature = safeThresholdSignature(
            recoveredKeys, safeMessageDigest(recoveredSafe, abi.encode(digest))
        );
        MigrationRecovery.Context memory context_ =
            artists.identityRecoveryContext(request, acceptance);
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] =
            abi.encodeCall(MigrationRecoveryRegistry.recoverArtistIdentity, (request, acceptance));
        calls[0] = StreamCurrentStackPlan.call(
            address(artists),
            data[0],
            context_.scopeHash,
            context_.oldValueHash,
            context_.newValueHash
        );
        uint64 ready;
        (migrationSourceAction, ready) = _scheduleBatchAsGovernor(2, calls, data);

        // Permissionless preparation is submitted by the real Safe. It authenticates
        // the actual still-SCHEDULED batch, complete calls hash and proposer role.
        this.executeCurrentGovernorCall(
            address(artists),
            abi.encodeCall(
                MigrationActionRegistry.registerIdentityRecoveryAction,
                (migrationSourceAction, calls, request, acceptance)
            )
        );
        _candidate(2, "identity_authority.replay.recovery_preparation", migrationSourceAction);
        (MigrationAction.Association memory association,, bytes32 execution, uint64 count) =
            artists.identityRecoveryActionState(fixtureArtistId, migrationSourceAction);
        require(
            association.associationHash != 0 && association.action.actionId == migrationSourceAction
                && association.action.proposer == address(governorSafe)
                && association.guardian.recordHash == migrationSourceGuardian && execution == 0
                && count == 1,
            "actual registered source recovery and guardian snapshot"
        );
        // Do not change roles/guardians/request/call bytes after registration.
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (migrationSourceAction, calls, data))
        );
        require(
            executor.governanceAction(migrationSourceAction).status
                == GovernanceActionStatus.EXECUTED,
            "actual delayed recovery batch executed"
        );
        record = artists.latestIdentityRecovery(fixtureArtistId);
        _migrationRecoveryResult(record, context_, acceptance.nonce, digest);
    }

    function _migrationRecoveryResult(
        bytes32 record,
        MigrationRecovery.Context memory context_,
        uint256 acceptanceNonce,
        bytes32 digest
    ) private {
        MigrationRecovery.Record memory stored = artists.identityRecoveryRecord(record);
        require(
            record != 0 && stored.fields.vestedAuthorityClass == 1
                && stored.fields.newAddress == address(recoveredSafe)
                && stored.executor == address(executor) && stored.proposer == address(governorSafe)
                && stored.acceptanceDigest == digest && stored.acceptanceNonce == acceptanceNonce,
            "actual class1 recovery35 of original Safe"
        );
        T.Identity memory principal =
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId);
        require(
            principal.authorityAddress == address(recoveredSafe) && principal.authorityClass == 1
                && principal.status == 1,
            "recovered Safe owns original current identity"
        );
        (,, bytes32 execution,) =
            artists.identityRecoveryActionState(fixtureArtistId, migrationSourceAction);
        require(execution == record, "registered action consumed by exact original35");
        uint256 count = MigrationNative(artistSuite.owners[2]).artistNativeReceiptCount();
        require(
            count >= 2
                && MigrationNative(artistSuite.owners[2]).artistNativeReceiptAt(count - 2).operation
                    == 35
                && MigrationNative(artistSuite.owners[2])
                .artistNativeReceiptAt(count - 2)
                .recordHash == record
                && MigrationNative(artistSuite.owners[2]).artistNativeReceiptAt(count - 1).operation
                == 35
                && MigrationNative(artistSuite.owners[2])
                .artistNativeReceiptAt(count - 1)
                .recordHash == stored.fields.supersededRecordsHash,
            "original paired35 native occurrences"
        );

        // Recovery consumes a distinct rotation-acceptance nonce lane. Calling the
        // ordinary _authorizationCandidate here would add an incorrect artist nonce key.
        _candidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(fixtureArtistId, digest))
        );
        _candidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    keccak256("rotation_acceptance"),
                    fixtureArtistId,
                    address(recoveredSafe),
                    acceptanceNonce
                )
            )
        );
        _candidate(
            2,
            "identity_authority.replay.contest_resolution",
            keccak256(abi.encode(fixtureArtistId, context_.causeHash))
        );
        _candidate(
            2,
            "identity_authority.replay.recovery_action",
            keccak256(
                abi.encode(
                    migrationSourceAction,
                    context_.scopeHash,
                    context_.oldValueHash,
                    context_.newValueHash
                )
            )
        );
        _candidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(fixtureArtistId, context_.incumbent, record))
        );
        // The migration driver adds one_way_cutover_latch only when it performs op57.
        // Do not replace inherited artist/artistSafe before capturing the original state;
        // subsequent successor writes must explicitly use recoveredSafe/recoveredKeys.
    }
}

/// @notice Separate construction state preserves the original fixture and every external suite dependency.
contract CurrentRecoveredSuccessorGraph is StreamCurrentFinalityGraph {
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
            "urn:current:recovered-successor",
            keccak256("current recovered successor module")
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
        _bindSuccessorArtistGraph(
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
        _completeSuccessorFinalityGraph(_currentGraphRendererCatalog(1));
        return (s, assemblyCoordinator);
    }

    function finishSelectedGraph() external returns (address[5] memory products) {
        require(msg.sender == caller, "test graph caller");
        _completeSelectedSuccessorGraph();
        products = [
            address(assemblyWork),
            address(assemblyRights),
            address(assemblyConservation),
            address(assemblyInventory),
            address(assemblyBundle)
        ];
    }
}

/// @notice Source-authored real Core, Executor, Safe and seven-owner recovered operation60 recipe.
/// @dev Native execution remains pending. Selector completion additionally requires the separately
/// owned authenticated current-Metadata Artist reader. Construction and operation60 assertions
/// below do not claim complete finality/content readiness or preservation-record continuity.
abstract contract StreamCurrentRecoveredArtistMigrationFixture is CurrentRecoveredSourceRecipe {
    bytes32 internal constant POINTER = keccak256("ARTIST_REGISTRY");
    AH.Origin[][7] private candidates;
    AH.PolicyKey[] private policyKeys;
    T.SuiteConfiguration internal destination;
    StreamArtistOnboardingRegistry internal successor;
    StreamArtistOnboardingCoordinator internal successorCoordinator;
    CurrentRecoveredSuccessorGraph internal successorGraph;
    bytes32 private sourceRecovery;

    struct SignedCall {
        address target;
        bytes data;
        bytes signatures;
        bytes32 hash;
        uint256 nonce;
    }

    function setUp() public {
        artistKeys.push(0x5AFE601);
        artistKeys.push(0x5AFE602);
        recoveredKeys.push(0x5AFE611);
        recoveredKeys.push(0x5AFE612);
        uint256[] memory governanceKeys = new uint256[](2);
        governanceKeys[0] = 0x5AFE621;
        governanceKeys[1] = 0x5AFE622;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(artistKeys), 2, 60601);
        recoveredSafe = createOfficialSafe(components, safeOwnerAddresses(recoveredKeys), 2, 60602);
        OfficialSafe governor =
            createOfficialSafe(components, safeOwnerAddresses(governanceKeys), 2, 60603);
        vm.recordLogs();
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        _collectPolicies(vm.getRecordedLogs());
        _installGovernorSafe(governor, governanceKeys);
        sourceRecovery = _recoverSource();
        successorGraph = new CurrentRecoveredSuccessorGraph();
        (destination, successorCoordinator) = successorGraph.construct(
            artistSuite,
            address(registry),
            address(executor),
            address(manifest),
            address(artistArchivalCoverage),
            address(artistArchivalCheckpoint),
            DEPLOYMENT_HASH
        );
        successor = StreamArtistOnboardingRegistry(payable(destination.registry));
        _admitSuccessor();
        require(
            StreamCurrentStackPlan.readPointer(core, POINTER).target == address(artists),
            "constructor never selects successor"
        );
    }

    function _additionalOperatingPolicies()
        internal
        view
        virtual
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](1);
        rows[0] =
            _policy(2, address(artists), MigrationRecoveryRegistry.recoverArtistIdentity.selector);
    }

    function _onboardFixtureArtist(address account) internal override {
        bytes memory document = bytes("current recovered migration original identity");
        T.BindingProposal memory p;
        p.artistAddress = account;
        p.identityRecordHash = keccak256(document);
        p.identityRecordURI = "urn:current:recovered-original";
        p.consentMode = 1;
        p.collaborators = new T.CollaboratorRecord[](0);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
        (fixtureArtistId,) =
            artists.proposeArtistBinding(1, p, document, "Current recovered artist");
        _candidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _candidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.acceptanceDigest(1, a));
        artists.acceptArtistBinding(1, a);
        _candidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(1), uint8(1), account))
        );
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        _authorizationCandidate(
            digest,
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint
        );
        return safeThresholdSignature(artistKeys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _candidate(uint8 owner, string memory surface, bytes32 scope) internal override {
        candidates[owner].push(AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _authorizationCandidate(bytes32 digest, uint256 nonce) internal override {
        _candidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(fixtureArtistId, digest))
        );
        _candidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(fixtureArtistId, nonce))
        );
    }

    function _collectPolicies(Vm.Log[] memory logs) private {
        bytes32 event_ = keccak256(
            "ArtistPolicyConsentRecorded(uint16,uint256,bytes32,address,bytes32,uint8,uint256,uint64,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory row = logs[i];
            if (
                row.emitter != artistSuite.owners[6] || row.topics.length != 4
                    || row.topics[0] != event_
            ) continue;
            (
                uint16 version,
                bytes32 phase,
                uint8 class_,
                uint256 nonce,
                uint64 time,
                bytes32 record
            ) = abi.decode(row.data, (uint16, bytes32, uint8, uint256, uint64, bytes32));
            require(
                version == 1 && class_ == 1 && uint256(row.topics[1]) == 1 && record != 0
                    && time != 0,
                "original policy event"
            );
            policyKeys.push(AH.PolicyKey(phase, row.topics[2]));
            _candidate(
                6,
                "consent_finality.replay.policy_consent_key",
                keccak256(abi.encode(uint256(1), phase, row.topics[2]))
            );
            // The inherited signer hook already retained the complete nonce/digest preimages.
            require(
                nonce
                    < IStreamArtistIdentityOwner(artistSuite.owners[2])
                    .identity(fixtureArtistId)
                    .nonceHint,
                "consumed original policy nonce"
            );
        }
        require(policyKeys.length == 4, "both original and replacement policies for two phases");
    }

    function _policy(uint8 cls, address target, bytes4 selector)
        internal
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            cls,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            0
        );
    }

    function _publication(string memory purpose)
        private
        returns (address payload, StreamSystemManifestUpdate memory update)
    {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        bytes32 hash;
        (payload, hash) =
            StreamGenesisManifestPlan.writePayload(abi.encode(purpose, address(successor)));
        update = StreamSystemManifestUpdate(
            hash,
            "urn:current:recovered-migration",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
    }

    function _admitSuccessor() private {
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](1);
        additions[0] =
            _policy(1, address(successor), History.commitArtistHistoryImportRoot.selector);
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(executor, additions);
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("successor history admission");
        (GenesisBatch memory batch, uint256 completed) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            manifest,
            payload,
            update
        );
        require(completed == 1, "one exact history selector admission");
        _run(3, batch.calls, batch.callDatas);
        StreamModuleRegistration[] memory modules = new StreamModuleRegistration[](1);
        modules[0] = _successorRecord();
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, modules);
        _run(1, calls, data);
    }

    function _successorRecord() private view returns (StreamModuleRegistration memory) {
        (, bytes32 moduleHash) = successor.streamModuleManifest();
        return StreamModuleRegistration(
            address(successor),
            POINTER,
            moduleHash,
            type(IStreamArtistMintConsent).interfaceId,
            500000,
            address(successor).codehash,
            DEPLOYMENT_HASH,
            keccak256("current recovered migration reconstruction"),
            "urn:current:recovered-reconstruction"
        );
    }

    function _run(uint8 cls, GovernanceCall[] memory calls, bytes[] memory data)
        private
        returns (bytes32 action)
    {
        uint64 ready;
        (action, ready) = _scheduleBatchAsGovernor(cls, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "actual delayed batch"
        );
    }

    function _pointerBatch() internal returns (GovernanceCall[] memory calls, bytes[] memory data) {
        StreamCorePointerState memory old = StreamCurrentStackPlan.readPointer(core, POINTER);
        StreamCorePointerState memory next = StreamCurrentStackPlan.pointerState(
            address(registry), _successorRecord(), false, old.revision + 1
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            StreamCurrentStackPlan.pointerTransitionHashes(core, POINTER, old, next);
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        data[0] = abi.encodeCall(core.updateSatellitePointer, (POINTER, address(successor)));
        calls[0] = StreamCurrentStackPlan.call(address(core), data[0], scope, before_, after_);
        StreamSystemManifest.AggregateState memory aggregate =
            StreamGenesisManifestPlan.readAggregate(manifest);
        aggregate.modules.artistRegistry = address(successor);
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("governed recovered Artist pointer");
        (calls[1], data[1]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, aggregate.modules);
    }

    function _bindHistory() internal returns (HT.Leaf[] memory leaves) {
        leaves = _leaves();
        (bytes32 root,) = _proof(leaves, 0);
        HT.Context memory context_ = History(address(successor))
            .artistHistoryImportContext(
                address(artists), uint64(block.number), root, GOVERNANCE_REASON
            );
        GovernanceActionRequest memory request = _governanceRequest(
            1,
            address(successor),
            abi.encodeCall(
                History.commitArtistHistoryImportRoot,
                (address(artists), uint64(block.number), root, GOVERNANCE_REASON)
            ),
            context_.scopeHash,
            context_.oldValueHash,
            context_.newValueHash
        );
        bytes32 action = _govern(request);
        (bool committed, bytes32 hash, uint256 count) =
            History(address(successor)).artistHistoryPredecessorBinding(address(artists));
        require(
            committed && hash == address(artists).codehash && count == 1,
            "actual governed55 binding"
        );
        require(
            executor.governanceAction(action).reasonHash == GOVERNANCE_REASON,
            "exact original manifest reason"
        );
    }

    function _verifyAndObserve(HT.Leaf[] memory leaves) internal {
        (, uint64 artistCount) = History(address(artists)).artistHistoryLane(1, fixtureArtistId);
        (, bytes32[] memory proof) = _proof(leaves, artistCount - 1);
        _safeCall(
            address(successor),
            abi.encodeCall(
                History.verifyImportedLaneTip, (uint256(0), leaves[artistCount - 1], proof)
            )
        );
        (, proof) = _proof(leaves, leaves.length - 1);
        _safeCall(
            address(successor),
            abi.encodeCall(
                History.verifyImportedLaneTip, (uint256(0), leaves[leaves.length - 1], proof)
            )
        );
        _safeCall(address(artists), abi.encodeCall(History.observeRegistryCutover, ()));
        _candidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        (bool observed, address next,) = History(address(artists)).artistRegistryCutover();
        require(observed && next == address(successor), "actual original57 source latch");
    }

    function _cutover() internal {
        HT.Leaf[] memory leaves = _bindHistory();
        (GovernanceCall[] memory calls, bytes[] memory data) = _pointerBatch();
        _run(3, calls, data);
        _assertPointer();
        _verifyAndObserve(leaves);
    }

    function _assertPointer() internal view {
        StreamCorePointerState memory pointer = StreamCurrentStackPlan.readPointer(core, POINTER);
        require(
            pointer.target == address(successor) && pointer.codeHash == address(successor).codehash
                && pointer.registryStatus == 1,
            "actual admitted current Core successor"
        );
        require(
            StreamGenesisManifestPlan.readAggregate(manifest).modules.artistRegistry
                == address(successor),
            "actual manifest tail agrees"
        );
    }

    function _request() internal view virtual returns (MigrationHydration.Request memory p) {
        p.records.authority.artistIds = new bytes32[](1);
        p.records.authority.artistIds[0] = fixtureArtistId;
        p.records.authority.collections = new MH.Collection[](1);
        p.records.authority.collections[0] = MH.Collection(fixtureArtistId, 1, policyKeys);
        for (uint8 i; i < 7; ++i) {
            p.expectedCapabilities[i] =
                RecoveredOwner(artistSuite.owners[i]).recoveredAuthorityHydrationCapability();
            CP.Checkpoint memory cp = CP(artistSuite.owners[i]).authorityCheckpoint();
            p.records.authority.expectedSource[i] = cp;
            p.records.authority.replayOrigins[i] = new AH.Origin[](cp.replayCount);
            for (uint256 j; j < cp.replayCount; ++j) {
                (bytes32 key,) = CP(artistSuite.owners[i]).authorityReplayAt(j);
                bool found;
                for (uint256 k; k < candidates[i].length; ++k) {
                    AH.Origin memory origin = candidates[i][k];
                    bytes32 predicted = keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                            block.chainid,
                            address(artists),
                            address(artistCoordinator),
                            artistSuite.archive,
                            artistSuite.owners[i],
                            Owner(artistSuite.owners[i]).domainId(),
                            origin.surface,
                            origin.scope
                        )
                    );
                    if (predicted == key) {
                        p.records.authority.replayOrigins[i][j] = origin;
                        found = true;
                        break;
                    }
                }
                require(found, "every actual source replay key has its writer preimage");
            }
        }
    }

    function _prepared()
        internal
        view
        returns (MigrationHydration.Request memory request, Commit.Prepared memory prepared)
    {
        request = _request();
        prepared = Prepared.prepare(destination, request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
    }

    function _state(T.SuiteConfiguration memory suite) internal view returns (bytes32 hash) {
        for (uint8 i; i < 7; ++i) {
            address owner = suite.owners[i];
            CP.Checkpoint memory cp = CP(owner).authorityCheckpoint();
            hash = keccak256(
                abi.encode(
                    hash,
                    cp,
                    Publications.collect(owner, i),
                    Guards.collectNonces(owner, cp),
                    MigrationNative(owner).artistNativeReceiptCount(),
                    HydrationOwner(owner).authorityHydrationCommitment()
                )
            );
            (MigrationHydration.OwnerProvenance memory prefix, bytes32 value, uint64 revision) =
                RecoveredOwner(owner).recoveredHydrationImportedPrefix();
            hash = keccak256(abi.encode(hash, prefix, value, revision));
        }
        return keccak256(
            abi.encode(
                hash,
                History(suite.owners[2]).artistHistoryContinuityCommitment(),
                IStreamArtistIdentityOwner(suite.owners[2]).identity(fixtureArtistId),
                IStreamArtistRecoveredTimingInventory(suite.owners[2]).recoveredTimingCheckpoint(),
                ArtistSuiteVm(address(vm)).getNonce(suite.archive)
            )
        );
    }

    function _signed(address target, bytes memory data) internal returns (SignedCall memory s) {
        s.target = target;
        s.data = data;
        s.nonce = recoveredSafe.nonce();
        s.hash = recoveredSafe.getTransactionHash(
            target, 0, data, 0, 0, 0, 0, address(0), address(0), s.nonce
        );
        s.signatures = safeThresholdSignature(recoveredKeys, s.hash);
    }

    function submitSigned(SignedCall calldata s) external {
        require(msg.sender == address(this), "test caller");
        require(
            recoveredSafe.execTransaction(
                s.target, 0, s.data, 0, 0, 0, 0, address(0), payable(address(0)), s.signatures
            ),
            "actual recovered Safe execution"
        );
    }

    function _safeCall(address target, bytes memory data) internal {
        this.submitSigned(_signed(target, data));
    }

    function _safeFailure(SignedCall memory call_) internal {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.submitSigned(call_);
        require(
            recoveredSafe.nonce() == call_.nonce, "failed Safe transaction preserves exact nonce"
        );
    }

    function _assertImported(Commit.Prepared memory prepared) internal view {
        bytes32 value = HydrationOwner(destination.owners[2]).authorityHydrationCommitment();
        require(value != 0, "real op60 commitment");
        for (uint8 i; i < 7; ++i) {
            address owner = destination.owners[i];
            T.Snapshot memory now_ = Owner(owner).ownerStateSnapshotV2();
            require(
                now_.revision == prepared.admission.before_[i].revision + 1
                    && now_.recordChainTip == prepared.admission.before_[i].recordChainTip,
                "exact single owner commit"
            );
            require(
                HydrationOwner(owner).authorityHydrationCommitment() == value
                    && MigrationNative(owner).artistNativeReceiptCount() == 0,
                "seven imports create no original native receipts"
            );
            (MigrationHydration.OwnerProvenance memory prefix, bytes32 imported, uint64 revision) =
                RecoveredOwner(owner).recoveredHydrationImportedPrefix();
            require(
                imported == value && revision == now_.revision
                    && keccak256(abi.encode(prefix))
                        == keccak256(
                            abi.encode(
                                MigrationHydration.ownerProvenance(prepared.admission.provenance, i)
                            )
                        ),
                "lossless original prefix"
            );
            (, Payload.Payload memory payload) = Payload.decode(prepared.data[i].typedState, i);
            require(
                keccak256(abi.encode(Publications.collect(owner, i)))
                    == keccak256(abi.encode(payload.publications)),
                "exact original payload catalogs"
            );
            require(
                keccak256(abi.encode(Guards.collectNonces(owner, CP(owner).authorityCheckpoint())))
                    == keccak256(abi.encode(payload.nonces)),
                "complete retained nonce words and hints"
            );
            _assertImportedGuards(i, prepared.data[i]);
        }
        require(
            keccak256(abi.encode(successor.identityRecoveryRecord(sourceRecovery)))
                == keccak256(abi.encode(artists.identityRecoveryRecord(sourceRecovery))),
            "original35 record unchanged"
        );
        require(
            keccak256(abi.encode(successor.guardianSetRecord(migrationSourceGuardian)))
                == keccak256(abi.encode(artists.guardianSetRecord(migrationSourceGuardian))),
            "original28 record unchanged"
        );
        require(
            keccak256(
                abi.encode(
                    IStreamArtistIdentityOwner(destination.owners[2]).identity(fixtureArtistId)
                )
            )
            == keccak256(
                abi.encode(
                    IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId)
                )
            ),
            "exact recovered principal and nonce hint"
        );
    }

    function _assertImportedGuards(uint8 index, AH.OwnerData memory data) private view {
        MigrationHydration.OriginEnvironment memory environment;
        environment.chainId = block.chainid;
        environment.registry = destination.registry;
        environment.coordinator = address(successorCoordinator);
        environment.archive = destination.archive;
        environment.owners = destination.owners;
        for (uint256 i; i < data.origins.length; ++i) {
            bytes32 key = Guards.replayKey(environment, index, data.origins[i]);
            T.ReplayCell memory cell = Owner(destination.owners[index]).replayCell(key);
            if (
                index == 2
                    && data.origins[i].surface
                        == keccak256("identity_authority.replay.one_way_cutover_latch")
            ) {
                require(
                    cell.status == 0, "source cutover is historical, successor latch stays unused"
                );
            } else {
                require(
                    keccak256(abi.encode(cell)) == keccak256(abi.encode(data.cells[i])),
                    "exact rekeyed replay cell"
                );
            }
        }
    }

    function _freshGuardian() internal {
        address[] memory members = new address[](1);
        members[0] = address(artistSafe);
        MigrationRotation.GuardianSet memory terms =
            MigrationRotation.GuardianSet(fixtureArtistId, members, 1, 0);
        uint256 nonce =
            IStreamArtistIdentityOwner(destination.owners[2]).identity(fixtureArtistId).nonceHint;
        _safeCall(
            address(successor),
            abi.encodeCall(successor.setArtistGuardians, (terms, T.Authorization(nonce, 0, "")))
        );
        require(
            MigrationNative(destination.owners[2]).artistNativeReceiptCount() == 1,
            "actual recovered Safe creates first native suffix"
        );
        HT.Receipt memory receipt = MigrationNative(destination.owners[2]).artistNativeReceiptAt(0);
        require(
            receipt.operation == 28 && receipt.artistId == fixtureArtistId
                && receipt.recordHash != 0 && receipt.recordHash != migrationSourceGuardian,
            "fresh successor-domain guardian receipt"
        );
        MigrationRotation.GuardianRecord memory guardian =
            successor.guardianSetRecord(receipt.recordHash);
        require(
            guardian.signer == address(recoveredSafe)
                && guardian.provisional.transitionRecordHash == sourceRecovery,
            "fresh provisional guardian preserves original recovery35 association"
        );
    }

    function _leaves() private view returns (HT.Leaf[] memory rows) {
        History h = History(address(artists));
        (, uint64 a) = h.artistHistoryLane(1, fixtureArtistId);
        (, uint64 b) = h.artistHistoryLane(2, bytes32(uint256(1)));
        rows = new HT.Leaf[](uint256(a) + b);
        for (uint64 i; i < a; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(1, fixtureArtistId, i);
            rows[i] = HT.Leaf(1, fixtureArtistId, i, r, c);
        }
        for (uint64 i; i < b; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(2, bytes32(uint256(1)), i);
            rows[uint256(a) + i] = HT.Leaf(2, bytes32(uint256(1)), i, r, c);
        }
    }

    function _proof(HT.Leaf[] memory leaves, uint256 index)
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
                            address(artists),
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

/// @notice The original four actual-current migration assertions, using the shared recipe.
contract StreamCurrentRecoveredArtistMigrationTest is StreamCurrentRecoveredArtistMigrationFixture {
    function testCurrentRecoveredMigrationLateArchiveFailureRetriesIdenticalSignedSafeCall()
        public
    {
        _cutover();
        (MigrationHydration.Request memory request, Commit.Prepared memory prepared) = _prepared();
        SignedCall memory saved = _signed(
            address(successor),
            abi.encodeCall(MigrationRecovered.hydrateRecoveredArtistAuthority, (request))
        );
        bytes32 sourceBefore = _state(artistSuite);
        bytes32 before_ = _state(destination);
        uint256 originalBlock = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistArchiveV2.ArtistArchiveBlockNumberOverflow.selector,
                uint256(type(uint64).max) + 1
            )
        );
        MigrationRecovered(address(successor)).hydrateRecoveredArtistAuthority(request);
        require(
            _state(destination) == before_,
            "exact late original Archive error restores seven owners"
        );
        _safeFailure(saved);
        require(
            _state(destination) == before_ && _state(artistSuite) == sourceBefore,
            "Safe failure restores imports, catalogs, nonce words and Archive CREATE nonce"
        );
        vm.roll(originalBlock);
        this.submitSigned(saved);
        require(recoveredSafe.nonce() == saved.nonce + 1, "one exact signed Safe transaction");
        _assertImported(prepared);
        require(_state(artistSuite) == sourceBefore, "migration preserves complete source state");
        _freshGuardian();
        require(_state(artistSuite) == sourceBefore, "fresh successor suffix preserves source");
    }

    function testCurrentRecoveredMigrationStaleCertificateAndDuplicateHaveExactOracles() public {
        _cutover();
        (MigrationHydration.Request memory request, Commit.Prepared memory prepared) = _prepared();
        bytes32 before_ = _state(destination);
        bytes32 sourceBefore = _state(artistSuite);
        ++request.records.authority.expectedSource[2].ownerState.revision;
        vm.expectRevert(
            abi.encodeWithSelector(MigrationHydration.InvalidRecoveredHydrationProvenance.selector)
        );
        MigrationRecovered(address(successor)).hydrateRecoveredArtistAuthority(request);
        _safeFailure(
            _signed(
                address(successor),
                abi.encodeCall(MigrationRecovered.hydrateRecoveredArtistAuthority, (request))
            )
        );
        require(
            _state(destination) == before_ && _state(artistSuite) == sourceBefore,
            "stale certificate changes nothing"
        );
        --request.records.authority.expectedSource[2].ownerState.revision;
        _safeCall(
            address(successor),
            abi.encodeCall(MigrationRecovered.hydrateRecoveredArtistAuthority, (request))
        );
        _assertImported(prepared);
        before_ = _state(destination);
        vm.expectRevert(
            abi.encodeWithSelector(MigrationHydration.InvalidRecoveredHydrationProvenance.selector)
        );
        MigrationRecovered(address(successor)).hydrateRecoveredArtistAuthority(request);
        _safeFailure(
            _signed(
                address(successor),
                abi.encodeCall(MigrationRecovered.hydrateRecoveredArtistAuthority, (request))
            )
        );
        require(
            _state(destination) == before_ && _state(artistSuite) == sourceBefore,
            "one-use import preserves completed state"
        );
    }

    function testCurrentPointerNeedsGoverned55ThenRetriesSameSavedSafeAndRunsRecovered60() public {
        (GovernanceCall[] memory calls, bytes[] memory data) = _pointerBatch();
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(3, calls, data);
        vm.warp(ready);
        SignedCall memory saved = _signed(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        bytes32 before_ = keccak256(
            abi.encode(
                StreamCurrentStackPlan.readPointer(core, POINTER),
                StreamGenesisManifestPlan.readAggregate(manifest),
                _state(destination),
                _state(artistSuite)
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.InvalidSatellitePointer.selector, POINTER, address(successor)
            )
        );
        executor.executeGovernanceBatch(action, calls, data);
        _safeFailure(saved);
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "failed pointer action stays scheduled"
        );
        require(
            keccak256(
                abi.encode(
                    StreamCurrentStackPlan.readPointer(core, POINTER),
                    StreamGenesisManifestPlan.readAggregate(manifest),
                    _state(destination),
                    _state(artistSuite)
                )
            ) == before_,
            "Core, manifest and owners rollback"
        );
        HT.Leaf[] memory leaves = _bindHistory();
        require(
            block.timestamp <= executor.governanceAction(action).expiresAfter,
            "same scheduled pointer remains live"
        );
        this.submitSigned(saved);
        _assertPointer();
        _verifyAndObserve(leaves);
        (MigrationHydration.Request memory request, Commit.Prepared memory prepared) = _prepared();
        _safeCall(
            address(successor),
            abi.encodeCall(MigrationRecovered.hydrateRecoveredArtistAuthority, (request))
        );
        _assertImported(prepared);
    }

    function testCurrentRecoveredMigrationFinishesOriginalSelectorsOnlyAfterSevenOwnerImport()
        public
    {
        _cutover();
        bytes32 sourceBefore = _state(artistSuite);
        bytes32 before_ = _state(destination);
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "complete actual successor owner import")
        );
        successorGraph.finishSelectedGraph();
        require(
            _state(artistSuite) == sourceBefore && _state(destination) == before_,
            "pending selector completion cannot mutate Artist state"
        );
        (MigrationHydration.Request memory request, Commit.Prepared memory prepared) = _prepared();
        _safeCall(
            address(successor),
            abi.encodeCall(MigrationRecovered.hydrateRecoveredArtistAuthority, (request))
        );
        _assertImported(prepared);
        before_ = _state(destination);
        address[5] memory products = successorGraph.finishSelectedGraph();
        for (uint256 i; i < products.length; ++i) {
            require(
                products[i].code.length != 0 && products[i].code.length <= 24576,
                "all five remaining genuine products deployed and fit"
            );
        }
        require(
            MigrationWork(products[0]).metadata() == address(assemblyMetadata)
                && MigrationRights(products[1]).metadata() == address(assemblyMetadata)
                && MigrationConservation(products[2]).metadata() == address(assemblyMetadata)
                && assemblyMetadata.artistRegistry() == address(artists),
            "current successor selectors retain exact original Metadata binding"
        );
        _assertPointer();
        require(
            _state(artistSuite) == sourceBefore && _state(destination) == before_,
            "selector constructors preserve original and imported Artist state"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "pending successor selectors"));
        successorGraph.finishSelectedGraph();
    }
}
