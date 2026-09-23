// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityNativeAssemblyFixture
} from "./StreamCurrentAuthorityNativeAssemblyFixture.sol";
import { OfficialSafe } from "./OfficialSafeFixture.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistContentTypes as RecoveryContent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Readiness
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistIdentityOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistBindingOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as AuthorityRecovery
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistRotationTypes as AuthorityRotation
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecoveryActionTypes as AuthorityAction
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    IStreamArtistIdentityRecovery as AuthorityRecoveryRegistry
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistRecoveryAction as AuthorityActionRegistry
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    IStreamArtistNativeReceipts as AuthorityNative
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import {
    GovernanceCall,
    GovernanceActionStatus,
    GovernanceActionPolicyEntry
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import { StreamCurrentStackPlan } from "../../script/current/StreamCurrentStackPlan.sol";

/// @notice Actual original Safe recovery and source-authored replay witnesses for the new graph.
/// @dev This helper does not execute55/56/57/60, omit unsupported source operations, or claim
/// recovered codec admission. The parent recipe must enumerate and match every actual CP key.
abstract contract StreamCurrentAuthorityRecoveryRecipe is
    StreamCurrentAuthorityNativeAssemblyFixture
{
    AH.Origin[][7] internal authorityCandidates;
    AH.PolicyKey[] internal authorityPolicies;
    T.EconomicsConsent[] internal authorityEconomics;
    Readiness.AttestationInput[] internal authorityAttestations;
    bytes32 internal authoritySourceRecovery;
    string internal constant AUTHORITY_REASON_URI =
        "https://fixtures.example.invalid/current-authority/source-recovery";
    bytes32 internal constant AUTHORITY_REASON = keccak256(bytes(AUTHORITY_REASON_URI));
    OfficialSafe internal authorityOriginalArtistSafe;
    OfficialSafe internal authorityRecoveredSafe;
    uint256[] internal authorityOriginalArtistKeys;
    uint256[] internal authorityRecoveredKeys;
    bytes32 internal authoritySourceGuardian;
    bytes32 internal authoritySourceAction;

    function _authorityRecoverOriginal() internal returns (bytes32 record) {
        require(authoritySourceRecovery == 0, "one original source recovery");
        authorityOriginalArtistSafe = assemblyArtist;
        authorityOriginalArtistKeys = assemblyArtistKeys;
        authorityRecoveredKeys = new uint256[](2);
        authorityRecoveredKeys[0] = 0x65295801;
        authorityRecoveredKeys[1] = 0x65295802;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        authorityRecoveredSafe =
            createOfficialSafe(components, safeOwnerAddresses(authorityRecoveredKeys), 2, 32001);
        T.Identity memory principal =
            IStreamArtistIdentityOwner(assemblySuite.owners[2]).identity(assemblyArtistId);
        require(
            principal.authorityAddress == address(authorityOriginalArtistSafe)
                && principal.authorityClass == 1 && principal.status == 1
                && address(authorityRecoveredSafe) != address(authorityOriginalArtistSafe),
            "original live class1 Safe source"
        );
        _authorityGrantArbiter();
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](2);
        additions[0] = GovernanceActionPolicyEntry(
            1,
            address(assemblyArtists),
            assemblyArtists.contestArtistIdentity.selector,
            address(assemblyArtists).codehash,
            keccak256(abi.encode(ASSEMBLY_DEPLOYMENT, address(assemblyArtists))),
            1,
            0,
            0,
            0
        );
        additions[1] = GovernanceActionPolicyEntry(
            2,
            address(assemblyArtists),
            AuthorityRecoveryRegistry.recoverArtistIdentity.selector,
            address(assemblyArtists).codehash,
            keccak256(abi.encode(ASSEMBLY_DEPLOYMENT, address(assemblyArtists))),
            1,
            0,
            0,
            0
        );
        _admitAssemblyPolicies(additions);
        _authorityGuardian();
        _authorityCompromise();
        record = _authorityRecovery();
        authoritySourceRecovery = record;
        // Adopt the recovered signer only after all exact original35 assertions succeed.
        assemblyArtist = authorityRecoveredSafe;
        assemblyArtistKeys = authorityRecoveredKeys;
        assemblyArtistNonce =
        IStreamArtistIdentityOwner(assemblySuite.owners[2]).identity(assemblyArtistId).nonceHint;
    }

    function _authorityGuardian() private {
        address[] memory members = new address[](1);
        members[0] = address(assemblyRoot);
        AuthorityRotation.GuardianSet memory terms =
            AuthorityRotation.GuardianSet(assemblyArtistId, members, 1, 10 days);
        T.Authorization memory authorization = T.Authorization(
            IStreamArtistIdentityOwner(assemblySuite.owners[2])
            .identity(assemblyArtistId)
            .nonceHint,
            uint64(block.timestamp),
            ""
        );
        bytes32 digest = assemblyArtists.guardianSetDigest(terms, authorization);
        _authorityAuthorization(digest, authorization.nonce);
        authorization.signature = safeThresholdSignature(
            authorityOriginalArtistKeys,
            safeMessageDigest(authorityOriginalArtistSafe, abi.encode(digest))
        );
        require(
            executeSafe(
                authorityOriginalArtistSafe,
                authorityOriginalArtistKeys,
                address(assemblyArtists),
                0,
                abi.encodeCall(assemblyArtists.setArtistGuardians, (terms, authorization)),
                0
            ),
            "actual source Safe guardian28"
        );
        (,,, authoritySourceGuardian) = assemblyArtists.guardianSet(assemblyArtistId);
        AuthorityRotation.GuardianRecord memory stored =
            assemblyArtists.guardianSetRecord(authoritySourceGuardian);
        require(
            stored.recordHash != 0 && stored.signer == address(authorityOriginalArtistSafe)
                && stored.nonce == authorization.nonce && stored.authorityClass == 1,
            "exact source guardian record"
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.guardian_set_chain",
            keccak256(abi.encode(assemblyArtistId, authorization.nonce))
        );
    }

    function _authorityCompromise() private {
        bytes32 evidence = keccak256("current authority source compromise");
        (bytes32 scope, bytes32 oldState, bytes32 newState) = assemblyArtists.identityContestGovernanceContext(
            assemblyArtistId, bytes32(0), evidence, AUTHORITY_REASON
        );
        GenesisBatch memory batch = _authorityBatch(
            1,
            abi.encodeCall(
                assemblyArtists.contestArtistIdentity,
                (assemblyArtistId, bytes32(0), evidence, AUTHORITY_REASON)
            ),
            scope,
            oldState,
            newState
        );
        _assemblyGovernance(batch, AUTHORITY_REASON_URI);
        bytes32 contest =
            assemblyArtists.currentIdentityContestCause(assemblyArtistId).facts.referenceHash;
        require(
            contest != 0
                && IStreamArtistIdentityOwner(assemblySuite.owners[2])
                    .identity(assemblyArtistId)
                    .status == 4,
            "actual Executor compromise33"
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(
                abi.encode(
                    keccak256("subject"), assemblyArtistId, bytes32(0), evidence, AUTHORITY_REASON
                )
            )
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("record"), contest))
        );
    }

    function _authorityRecovery() private returns (bytes32 record) {
        AuthorityRecovery.Request memory request = AuthorityRecovery.Request(
            assemblyArtistId,
            address(authorityRecoveredSafe),
            1,
            assemblyArtists.currentIdentityContestCause(assemblyArtistId).causeHash,
            assemblyArtists.latestIdentityContestDismissal(assemblyArtistId),
            keccak256("current authority source recovery"),
            AUTHORITY_REASON,
            new bytes32[](0)
        );
        (, uint256 acceptanceNonce) = assemblyArtists.rotationAcceptanceNonceState(
            assemblyArtistId, address(authorityRecoveredSafe), 0
        );
        T.Authorization memory acceptance = T.Authorization(
            acceptanceNonce, uint64(block.timestamp + assemblyExecutor.minimumDelay(2) + 7 days), ""
        );
        bytes32 digest = assemblyArtists.rotationAcceptanceDigest(
            AuthorityRotation.Rotation(
                assemblyArtistId,
                address(authorityOriginalArtistSafe),
                address(authorityRecoveredSafe),
                AUTHORITY_REASON,
                bytes32(0)
            ),
            acceptance
        );
        acceptance.signature = safeThresholdSignature(
            authorityRecoveredKeys, safeMessageDigest(authorityRecoveredSafe, abi.encode(digest))
        );
        AuthorityRecovery.Context memory context_ =
            assemblyArtists.identityRecoveryContext(request, acceptance);
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] =
            abi.encodeCall(AuthorityRecoveryRegistry.recoverArtistIdentity, (request, acceptance));
        calls[0] = StreamCurrentStackPlan.call(
            address(assemblyArtists),
            data[0],
            context_.scopeHash,
            context_.oldValueHash,
            context_.newValueHash
        );
        GenesisBatch memory batch = GenesisBatch(2, calls, data);
        authoritySourceAction = _assemblyScheduleGovernance(batch, AUTHORITY_REASON_URI);
        require(
            assemblyExecutor.governanceAction(authoritySourceAction).reasonHash == AUTHORITY_REASON,
            "exact scheduled recovery reason"
        );

        // Permissionless preparation is submitted by the real Safe. It authenticates
        // the actual still-SCHEDULED batch, complete calls hash and proposer role.
        _authorityRootCall(
            address(assemblyArtists),
            abi.encodeCall(
                AuthorityActionRegistry.registerIdentityRecoveryAction,
                (authoritySourceAction, calls, request, acceptance)
            )
        );
        _authorityCandidate(
            2, "identity_authority.replay.recovery_preparation", authoritySourceAction
        );
        (AuthorityAction.Association memory association,, bytes32 execution, uint64 count) =
            assemblyArtists.identityRecoveryActionState(assemblyArtistId, authoritySourceAction);
        require(
            association.associationHash != 0 && association.action.actionId == authoritySourceAction
                && association.action.proposer == address(assemblyRoot)
                && association.guardian.recordHash == authoritySourceGuardian && execution == 0
                && count == 1,
            "actual registered source recovery and guardian snapshot"
        );
        // Do not change assemblyRoles/guardians/request/call bytes after registration.
        assemblyVm.warp(assemblyExecutor.governanceAction(authoritySourceAction).notBefore);
        _authorityRootCall(
            address(assemblyExecutor),
            abi.encodeCall(
                assemblyExecutor.executeGovernanceBatch, (authoritySourceAction, calls, data)
            )
        );
        require(
            assemblyExecutor.governanceAction(authoritySourceAction).status
                == GovernanceActionStatus.EXECUTED,
            "actual delayed recovery batch executed"
        );
        record = assemblyArtists.latestIdentityRecovery(assemblyArtistId);
        _authorityRecoveryResult(record, context_, acceptance.nonce, digest);
    }

    function _authorityRecoveryResult(
        bytes32 record,
        AuthorityRecovery.Context memory context_,
        uint256 acceptanceNonce,
        bytes32 digest
    ) private {
        AuthorityRecovery.Record memory stored = assemblyArtists.identityRecoveryRecord(record);
        require(
            record != 0 && stored.fields.vestedAuthorityClass == 1
                && stored.fields.newAddress == address(authorityRecoveredSafe)
                && stored.executor == address(assemblyExecutor)
                && stored.proposer == address(assemblyRoot) && stored.acceptanceDigest == digest
                && stored.acceptanceNonce == acceptanceNonce,
            "actual class1 recovery35 of original Safe"
        );
        T.Identity memory principal =
            IStreamArtistIdentityOwner(assemblySuite.owners[2]).identity(assemblyArtistId);
        require(
            principal.authorityAddress == address(authorityRecoveredSafe)
                && principal.authorityClass == 1 && principal.status == 1,
            "recovered Safe owns original current identity"
        );
        (,, bytes32 execution,) =
            assemblyArtists.identityRecoveryActionState(assemblyArtistId, authoritySourceAction);
        require(execution == record, "registered action consumed by exact original35");
        uint256 count = AuthorityNative(assemblySuite.owners[2]).artistNativeReceiptCount();
        require(
            count >= 2
                && AuthorityNative(assemblySuite.owners[2])
                    .artistNativeReceiptAt(count - 2)
                    .operation == 35
                && AuthorityNative(assemblySuite.owners[2])
                .artistNativeReceiptAt(count - 2)
                .recordHash == record
                && AuthorityNative(assemblySuite.owners[2])
                .artistNativeReceiptAt(count - 1)
                .operation == 35
                && AuthorityNative(assemblySuite.owners[2])
                .artistNativeReceiptAt(count - 1)
                .recordHash == stored.fields.supersededRecordsHash,
            "original paired35 native occurrences"
        );

        // Recovery consumes a distinct rotation-acceptance nonce lane. Calling the
        // ordinary _authorityAuthorization here would add an incorrect artist nonce key.
        _authorityCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(assemblyArtistId, digest))
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    keccak256("rotation_acceptance"),
                    assemblyArtistId,
                    address(authorityRecoveredSafe),
                    acceptanceNonce
                )
            )
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.contest_resolution",
            keccak256(abi.encode(assemblyArtistId, context_.causeHash))
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.recovery_action",
            keccak256(
                abi.encode(
                    authoritySourceAction,
                    context_.scopeHash,
                    context_.oldValueHash,
                    context_.newValueHash
                )
            )
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(assemblyArtistId, context_.incumbent, record))
        );
        // The migration driver adds one_way_cutover_latch only when it performs op57.
        // Do not replace inherited artist/authorityOriginalArtistSafe before capturing the original state;
        // the outer helper adopts the recovered Safe only after these assertions.
    }

    function _authorityCandidate(uint8 owner, string memory surface, bytes32 scope) internal {
        require(owner < 7, "original owner index");
        bytes32 hash = keccak256(bytes(surface));
        for (uint256 i; i < authorityCandidates[owner].length; ++i) {
            AH.Origin memory old = authorityCandidates[owner][i];
            if (old.surface == hash && old.scope == scope) return;
        }
        authorityCandidates[owner].push(AH.Origin(hash, scope));
    }

    function _authorityAuthorization(bytes32 digest, uint256 nonce) internal override {
        _authorityCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(assemblyArtistId, digest))
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(assemblyArtistId, nonce))
        );
    }

    function _afterAssemblyOnboard() internal override {
        T.Binding memory b = IStreamArtistBindingOwner(assemblySuite.owners[0]).binding(1);
        require(
            b.generation == 1 && b.accepted && b.artistId == assemblyArtistId,
            "actual original accepted binding"
        );
        _authorityCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(uint256(1), b.generation))
        );
        _authorityCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        _authorityCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), b.generation, uint8(1), address(assemblyArtist)))
        );
        _authorityCandidate(
            5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(assemblyArtistId))
        );
    }

    function _authorityEconomicsConsent(T.EconomicsConsent memory input, bytes32 record)
        internal
        override
    {
        require(record != 0, "actual economics record");
        authorityEconomics.push(input);
        _authorityCandidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(input)));
    }

    function _authorityRatification(T.Ratification memory input, bytes32 record) internal override {
        require(record != 0, "actual ratification record");
        _authorityCandidate(
            6,
            "consent_finality.replay.ratification_key",
            keccak256(abi.encode(input.collectionId, record))
        );
    }

    function _authorityPolicyConsent(T.PolicyConsent memory input, bytes32 record)
        internal
        override
    {
        require(record != 0, "actual policy record");
        authorityPolicies.push(AH.PolicyKey(input.phaseId, input.policyHash));
        _authorityCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(input.collectionId, input.phaseId, input.policyHash))
        );
    }

    function _authorityAttestation(T.Attestation memory input, uint256 nonce, bytes32 record)
        internal
        override
    {
        require(record != 0, "actual attestation record");
        authorityAttestations.push(Readiness.AttestationInput(input, nonce));
        _authorityCandidate(
            2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record))
        );
    }

    function _authorityContentConsent(RecoveryContent.Consent memory input, bytes32 record)
        internal
        override
    {
        require(record != 0, "actual content consent record");
        T.Binding memory b =
            IStreamArtistBindingOwner(assemblySuite.owners[0]).binding(input.collectionId);
        bytes32 scope = keccak256(abi.encode(input, b.generation));
        _authorityCandidate(
            6, "consent_finality.replay.content_consent_key", keccak256(abi.encode(scope, record))
        );
    }

    function _authorityContentFreeze(RecoveryContent.Freeze memory input, bytes32 record)
        internal
        override
    {
        require(record != 0, "actual op21 freeze record");
        T.Binding memory b =
            IStreamArtistBindingOwner(assemblySuite.owners[0]).binding(input.collectionId);
        _authorityCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(keccak256("CONTENT"), input.collectionId, b.generation, record))
        );
    }

    function _authorityBatch(
        uint8 actionClass,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private view returns (GenesisBatch memory batch) {
        batch.actionClass = actionClass;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = data;
        batch.calls[0] =
            StreamCurrentStackPlan.call(address(assemblyArtists), data, scope, oldHash, newHash);
    }

    function _authorityRootCall(address target, bytes memory data) private {
        uint256 nonce = assemblyRoot.nonce();
        require(
            executeSafe(assemblyRoot, assemblyRootKeys, target, 0, data, 0),
            "actual root threshold Safe call"
        );
        require(assemblyRoot.nonce() == nonce + 1, "actual root Safe nonce consumed once");
    }

    function _authorityGrantArbiter() private {
        bytes32 role = keccak256("ROLE_ATTRIBUTION_ARBITER");
        address holder = address(assemblyRoot);
        if (assemblyRoles.hasRole(role, holder)) return;
        (bytes32 chain, uint64 revision) = assemblyRoles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = assemblyRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(assemblyRoles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                globalRevision + 1
            )
        );
        bytes32 domain = keccak256("6529STREAM_ROLE_MUTATION_STATE_V1");
        bytes32 oldHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(assemblyRoles),
                scope,
                false,
                chain,
                revision,
                globalChain,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(assemblyRoles),
                scope,
                true,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        _assemblyGovernanceCall(
            1,
            address(assemblyRoles),
            abi.encodeCall(assemblyRoles.grantRole, (role, holder)),
            scope,
            oldHash,
            newHash
        );
        require(assemblyRoles.hasRole(role, holder), "actual root arbiter role admission");
    }
}
