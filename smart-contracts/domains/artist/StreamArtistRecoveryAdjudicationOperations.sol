// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryActionReads as Reads } from "./StreamArtistRecoveryActionReads.sol";
import { StreamArtistRecoveryActionOperations } from "./StreamArtistRecoveryActionOperations.sol";
import {
    StreamArtistIdentityRecoveryGovernance
} from "./StreamArtistIdentityRecoveryGovernance.sol";
import { StreamArtistGuardianAppealGovernance } from "./StreamArtistGuardianAppealGovernance.sol";
import { StreamArtistGuardianAppealAuthority } from "./StreamArtistGuardianAppealAuthority.sol";
import { StreamArtistRegistryValidatorBase } from "./StreamArtistRegistryValidatorBase.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as R
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistRotationTypes as Rotation
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    StreamArtistSuccessionTypes as Succession
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    IStreamArtistSuccessionReads
} from "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV2
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV2.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    IStreamArtistGuardianSelectionOwner
} from "../../interfaces/stream/artist/IStreamArtistGuardianSelectionPreparation.sol";
import {
    IStreamArtistRecoveryEvidence,
    IStreamArtistRecoveryEvidenceBinding
} from "../../interfaces/stream/artist/IStreamArtistRecoveryEvidence.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import { IStreamArtistArchiveV2 } from "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { GovernanceCall } from "../../interfaces/stream/governance/StreamGovernanceTypes.sol";

/// @notice Additive adjudication recipes inside the original fixed Coordinator operation lock.
/// @dev Preparation remains auxiliary operation65534. Recovery retains the original operation35
/// semantic record and owner receipt pair; the manifest is only supplemental Archive evidence.
library StreamArtistRecoveryAdjudicationOperations {
    struct Evidence {
        bytes32 manifestHash;
        E.ResolutionManifest manifest;
        E.AppealDocumentV2 appeal;
        Appeal.Authority appealAuthority;
        Succession.DirectiveRecord directive;
    }

    /// @dev Fixed decoder avoids copying the variable batch twice in the Coordinator facade.
    function prepare(D.CoordinatorContext memory x, bytes calldata data) public returns (bytes32) {
        (
            address actor,
            bytes32 actionId,
            GovernanceCall[] memory calls,
            R.Request memory p,
            T.Authorization memory acceptance,
            bytes32 manifestHash
        ) = abi.decode(
            data[4:], (address, bytes32, GovernanceCall[], R.Request, T.Authorization, bytes32)
        );
        return _prepare(x, actor, actionId, calls, p, acceptance, manifestHash);
    }

    function _prepare(
        D.CoordinatorContext memory x,
        address actor,
        bytes32 actionId,
        GovernanceCall[] memory calls,
        R.Request memory p,
        T.Authorization memory acceptance,
        bytes32 manifestHash
    ) private returns (bytes32 association) {
        address identity = x.suite.owners[2];
        T.Snapshot[7] memory before_;
        before_[2] = IStreamArtistOwner(identity).ownerStateSnapshotV2();
        IStreamArtistIdentityRecoveryOwnerV2 owner = IStreamArtistIdentityRecoveryOwnerV2(identity);
        R.Context memory context = owner.identityRecoveryContextV2(p, acceptance, manifestHash);
        bytes32 role = _role(owner, p, acceptance, manifestHash);
        Evidence memory evidence = _evidence(x, identity, p, manifestHash, role);
        IStreamArtistRecoveryActionOwner actionOwner = IStreamArtistRecoveryActionOwner(identity);
        (address executor, bytes32 codeHash) = actionOwner.recoveryExecutorBinding();
        A.Witness memory witness = Reads.prepareV2(
            A.Environment(x.suite.registry, executor, codeHash, x.suite.roleRegistry),
            actionId,
            calls,
            p,
            acceptance,
            context,
            role == Appeal.APPEAL,
            manifestHash
        );
        (A.Association memory previous,,,) = actionOwner.identityRecoveryActionState(p.artistId, 0);
        bool terminal = previous.associationHash == 0 || Reads.terminal(previous.action);
        association = owner.prepareIdentityRecoveryActionV2(
            T.ActionContext(A.PREPARE_OPERATION, actor, before_[2]),
            p,
            acceptance,
            witness,
            previous.associationHash,
            terminal,
            manifestHash
        );
        (A.Association memory saved, A.Veto memory veto, bytes32 executed, uint64 count) =
            actionOwner.identityRecoveryActionState(p.artistId, actionId);
        if (
            association == 0 || saved.associationHash != association || veto.vetoer != address(0)
                || executed != 0 || saved.action.actionId != actionId
        ) revert T.InvalidRecord();
        (GH.Head memory head,, GH.Snapshot memory history,) = IStreamArtistGuardianHistory(identity)
            .guardianHistoryState(p.artistId, 0, address(0), actionId);
        if (
            history.associationHash != association || history.artistId != p.artistId
                || history.count != count || head.count != count
                || history.historyCommitment != head.commitment
        ) revert T.InvalidRecord();
        E.EvidenceStateV2 memory state = _state(owner, p.artistId, actionId, evidence, role);
        if (state.associationHash != association) revert T.InvalidRecord();
        (Selection.Result memory selection, Rotation.GuardianRecord memory restored) =
            IStreamArtistGuardianSelectionOwner(identity).guardianRecoverySelection(actionId);
        if (
            selection.commitment != state.selectionCommitment
                || selection.selectedRecordHash != restored.recordHash
        ) revert T.InvalidRecord();
        bytes memory payload = abi.encode(
            p, acceptance, context, saved, count, history, selection, restored, state, evidence
        );
        _archive(x, actor, A.PREPARE_OPERATION, association, before_, payload);
    }

    function recover(
        D.CoordinatorContext memory x,
        address actor,
        R.Request memory p,
        T.Authorization memory acceptance,
        bytes32 manifestHash
    ) public returns (bytes32 record) {
        address identity = x.suite.owners[2];
        T.Snapshot[7] memory before_;
        before_[2] = IStreamArtistOwner(identity).ownerStateSnapshotV2();
        IStreamArtistIdentityRecoveryOwnerV2 owner = IStreamArtistIdentityRecoveryOwnerV2(identity);
        _requireNotVetoed(identity, owner, p.artistId, manifestHash);
        R.Context memory context = owner.identityRecoveryContextV2(p, acceptance, manifestHash);
        bytes32 role = _role(owner, p, acceptance, manifestHash);
        Evidence memory evidence = _evidence(x, identity, p, manifestHash, role);
        address authority = IStreamArtistIdentityContestOwner(identity).artistWindowAuthority();
        Contest.GovernanceWitness memory governance = role == Appeal.APPEAL
            ? StreamArtistGuardianAppealGovernance.read(x, authority, actor, p.reasonHash, context)
            : StreamArtistIdentityRecoveryGovernance.read(
                x, authority, actor, p.reasonHash, context
            );
        StreamArtistRecoveryActionOperations.requireExecution(
            identity, p.artistId, governance.actionId
        );
        E.EvidenceStateV2 memory state =
            _state(owner, p.artistId, governance.actionId, evidence, role);
        (A.Association memory prepared,,,) = IStreamArtistRecoveryActionOwner(identity)
            .identityRecoveryActionState(p.artistId, governance.actionId);
        if (prepared.associationHash != state.associationHash) revert T.InvalidRecord();
        T.SignerApproval memory proof = _verify(x, actor, p, acceptance, context.incumbent);
        record = owner.recoverIdentityV2(
            T.ActionContext(35, actor, before_[2]), p, acceptance, proof, governance, manifestHash
        );
        IStreamArtistIdentityRecoveryOwner original = IStreamArtistIdentityRecoveryOwner(identity);
        R.Record memory item = original.identityRecoveryRecord(record);
        if (item.recordHash != record || original.latestIdentityRecovery(p.artistId) != record) {
            revert T.InvalidRecord();
        }
        _archive(
            x,
            actor,
            35,
            record,
            before_,
            abi.encode(p, acceptance, proof, governance, context, item, state, evidence)
        );
    }

    function _requireNotVetoed(
        address identity,
        IStreamArtistIdentityRecoveryOwnerV2 owner,
        bytes32 artistId,
        bytes32 manifestHash
    ) private view {
        (A.Association memory prepared, A.Veto memory veto, bytes32 executed,) = IStreamArtistRecoveryActionOwner(
                identity
            ).identityRecoveryActionState(artistId, 0);
        if (prepared.associationHash == 0 || manifestHash == 0 || veto.vetoer == address(0)) {
            return;
        }
        E.EvidenceStateV2 memory state =
            owner.identityRecoveryEvidenceState(artistId, prepared.action.actionId);
        // A veto advances the owner revision. Preserve its specific error before reading the
        // now-stale context, only for this exact pending V2 preparation and its manifest.
        if (
            prepared.artistId == artistId && executed == 0 && state.manifestHash == manifestHash
                && state.associationHash == prepared.associationHash
        ) revert A.RecoveryActionVetoed(prepared.action.actionId);
    }

    function _role(
        IStreamArtistIdentityRecoveryOwnerV2 owner,
        R.Request memory p,
        T.Authorization memory acceptance,
        bytes32 manifestHash
    ) private view returns (bytes32 role) {
        role = owner.guardianRecoveryAuthorityRoleV2(p, acceptance, manifestHash);
        if (role != Appeal.ARBITER && role != Appeal.APPEAL) {
            revert R.InvalidIdentityRecoveryGovernance();
        }
    }

    function _state(
        IStreamArtistIdentityRecoveryOwnerV2 owner,
        bytes32 artistId,
        bytes32 actionId,
        Evidence memory evidence,
        bytes32 role
    ) private view returns (E.EvidenceStateV2 memory state) {
        state = owner.identityRecoveryEvidenceState(artistId, actionId);
        if (
            state.manifestHash != evidence.manifestHash || state.basisCommitment == 0
                || state.selectionCommitment == 0 || state.associationHash == 0
                || state.requiredRole != role
                || state.preparedFromOwnerRevision != evidence.manifest.ownerRevision
        ) revert T.InvalidRecord();
    }

    function _evidence(
        D.CoordinatorContext memory x,
        address identity,
        R.Request memory p,
        bytes32 manifestHash,
        bytes32 role
    ) private view returns (Evidence memory saved) {
        (address target, bytes32 codeHash) =
            IStreamArtistRecoveryEvidenceBinding(identity).recoveryEvidenceBinding();
        if (target.code.length == 0 || codeHash == 0 || target.codehash != codeHash) {
            revert T.InvalidBinding();
        }
        IStreamArtistRecoveryEvidence publisher = IStreamArtistRecoveryEvidence(target);
        if (
            publisher.owner() != identity || publisher.artistRegistry() != x.suite.registry
                || publisher.deploymentChainId() != block.chainid
                || publisher.coordinator() != address(this)
                || publisher.archive() != x.suite.archive || publisher.core() != x.suite.core
                || publisher.mintManager() != x.suite.mintManager
        ) revert T.InvalidBinding();
        bytes32 observed;
        saved.manifestHash = manifestHash;
        (saved.manifest, observed) = publisher.resolutionManifest(manifestHash);
        if (
            observed != identity.codehash || saved.manifest.artistId != p.artistId
                || saved.manifest.requestCommitment != E.requestCommitment(p)
                || E.manifestHash(
                        block.chainid,
                        x.suite.registry,
                        identity,
                        observed,
                        address(this),
                        x.suite.archive,
                        x.suite.core,
                        x.suite.mintManager,
                        saved.manifest
                    ) != manifestHash
        ) revert E.InvalidRecoveryManifest(manifestHash);
        bytes32 directive =
            IStreamArtistSuccessionReads(identity).operativeEstateDirective(p.artistId);
        if (directive != 0) {
            saved.directive =
                IStreamArtistSuccessionReads(identity).estateDirectiveRecord(directive);
            if (
                saved.directive.recordHash != directive
                    || saved.directive.terms.artistId != p.artistId
            ) {
                revert T.InvalidRecord();
            }
        }
        if (role == Appeal.APPEAL) {
            (saved.appeal, observed) = publisher.appealEvidenceV2(p.evidenceHash);
            if (
                observed != identity.codehash || saved.appeal.resolutionManifestHash != manifestHash
                    || E.appealHash(block.chainid, x.suite.registry, identity, saved.appeal)
                        != p.evidenceHash
            ) revert E.InvalidRecoveryAppealEvidence(p.evidenceHash);
            saved.appealAuthority = StreamArtistGuardianAppealAuthority.current(
                IStreamArtistIdentityContestOwner(identity).artistWindowAuthority(),
                x.suite.roleRegistry
            );
        }
    }

    function _verify(
        D.CoordinatorContext memory x,
        address actor,
        R.Request memory p,
        T.Authorization memory a,
        address incumbent
    ) private view returns (T.SignerApproval memory) {
        if (a.signature.length > 4096) {
            revert T.BoundExceeded(a.signature.length, 4096);
        }
        if (block.timestamp > a.time) revert T.ExpiredAuthorization(a.time);
        bytes32 digest = StreamArtistRotationHashes.acceptanceDigest(
            StreamArtistHashes.Environment(
                block.chainid, x.suite.registry, x.suite.core, x.suite.mintManager
            ),
            Rotation.Rotation(p.artistId, incumbent, p.newAddress, p.reasonHash, bytes32(0)),
            a
        );
        bool direct = actor == p.newAddress && a.signature.length == 0;
        if (!direct) {
            (uint256 cap,, uint8 failureClass, uint64 revision) = IStreamGasParameterHost(
                    x.suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                revision == 0 || failureClass != 2
                    || !StreamArtistRegistryValidatorBase(x.suite.validator)
                        .validateSignerProof(p.newAddress, digest, a.signature, cap)
            ) revert T.InvalidSignature();
        }
        return T.SignerApproval(p.newAddress, digest, direct);
    }

    function _archive(
        D.CoordinatorContext memory x,
        address actor,
        uint16 operation,
        bytes32 commitment,
        T.Snapshot[7] memory before_,
        bytes memory payload
    ) private {
        T.Snapshot[7] memory after_;
        after_[2] = IStreamArtistOwner(x.suite.owners[2]).ownerStateSnapshotV2();
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                operation,
                actor,
                commitment
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1),
            x.configurationHash,
            operation,
            actor,
            operation == 35 ? commitment : bytes32(0),
            before_,
            after_,
            payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
