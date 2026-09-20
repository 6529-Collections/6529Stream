// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveryRewindActionReads as Reads
} from "./StreamArtistRecoveryRewindActionReads.sol";
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
    StreamArtistRecoveryRewindEnvironment as Environment
} from "./StreamArtistRecoveryRewindEnvironment.sol";
import {
    StreamArtistRecoveryRewindEvidenceReads as EvidenceReads
} from "./StreamArtistRecoveryRewindEvidenceReads.sol";
import { StreamArtistRecoveryRewindPolicy as Policy } from "./StreamArtistRecoveryRewindPolicy.sol";
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
    StreamArtistGuardianAppealTypes as Appeal
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3 as Owner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
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
    IStreamArtistRecoveryRewindSelection as Worker
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    IStreamArtistRecoveryRewindEvidence
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3 as Payout
} from "../../interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistNativeReceipts
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import { IStreamArtistArchiveV2 } from "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    StreamArtistIdentityDismissalTypes as Resolution
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import { GovernanceCall } from "../../interfaces/stream/governance/StreamGovernanceTypes.sol";

import { StreamArtistRecoveryRewindOperations } from "./StreamArtistRecoveryRewindOperations.sol";

/// @notice Original V3 preparation recipe, executed in the fixed Coordinator context.
library StreamArtistRecoveryRewindPreparation {
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
        W.EnvironmentV3 memory env = _environment(x.suite);
        T.Snapshot[7] memory before_ = _snapshots(x.suite);
        Owner owner = Owner(env.identityOwner);
        W.CrossOwnerFactsV3 memory facts = _facts(env, manifestHash);
        R.Context memory c = owner.identityRecoveryContextV3(p, acceptance, manifestHash, facts);
        bytes32 role = _role(owner, p, acceptance, manifestHash, facts);
        StreamArtistRecoveryRewindOperations.Evidence memory evidence =
            _evidence(x, env, p, manifestHash, role, facts);
        IStreamArtistRecoveryActionOwner actionOwner =
            IStreamArtistRecoveryActionOwner(env.identityOwner);
        (address executor, bytes32 pin) = actionOwner.recoveryExecutorBinding();
        A.Witness memory witness = Reads.prepare(
            A.Environment(x.suite.registry, executor, pin, x.suite.roleRegistry),
            actionId,
            calls,
            p,
            acceptance,
            c,
            role == Appeal.APPEAL,
            manifestHash
        );
        (A.Association memory previous,,,) = actionOwner.identityRecoveryActionState(p.artistId, 0);
        bool terminal = previous.associationHash == 0 || Reads.terminal(previous.action);
        association = owner.prepareIdentityRecoveryActionV3(
            T.ActionContext(A.PREPARE_OPERATION, actor, before_[2]),
            p,
            acceptance,
            witness,
            previous.associationHash,
            terminal,
            manifestHash,
            facts
        );
        (A.Association memory saved, A.Veto memory veto, bytes32 executed,) =
            actionOwner.identityRecoveryActionState(p.artistId, actionId);
        W.EvidenceStateV3 memory state = _state(owner, p.artistId, actionId, evidence, role);
        if (
            association == 0 || saved.associationHash != association || veto.vetoer != address(0)
                || executed != 0 || saved.action.actionId != actionId
                || state.associationHash != association
        ) {
            revert T.InvalidRecord();
        }
        Worker worker = EvidenceReads.worker(env);
        bytes32 seal = worker.sealPreparationV3(manifestHash, actionId, association);
        W.PreparationSealV3 memory preparation = worker.preparationSealV3(facts.selection.sourceKey);
        if (
            seal == 0 || seal != preparation.commitment
                || preparation.associationHash != association
        ) {
            revert W.InvalidRecoveryRewindPreparation(actionId);
        }
        _archive(
            x,
            actor,
            A.PREPARE_OPERATION,
            association,
            before_,
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_PREPARATION_EVIDENCE_V3"),
                p,
                acceptance,
                c,
                saved,
                state,
                evidence,
                preparation,
                _notice(env.identityOwner, p.expectedCauseHash)
            )
        );
    }

    function _environment(T.SuiteConfiguration memory suite)
        private
        view
        returns (W.EnvironmentV3 memory)
    {
        return Environment.fromFixed(
            suite.owners[2],
            suite.registry,
            IStreamArtistOwner(suite.owners[2]).operationCoordinator(),
            suite.archive,
            suite.core,
            suite.mintManager
        );
    }

    function _facts(W.EnvironmentV3 memory e, bytes32 manifestHash)
        private
        view
        returns (W.CrossOwnerFactsV3 memory f)
    {
        Worker worker = EvidenceReads.worker(e);
        f.selection = worker.requireSelectionV3(manifestHash);
        (W.BasisV3 memory b, W.ProgressV3 memory progress) =
            worker.selectionV3(f.selection.sourceKey);
        if (!progress.complete || b.identity.manifestHash != manifestHash) {
            revert W.InvalidRecoveryRewindSelection(f.selection.sourceKey);
        }
        f.payout = W.ReceiptPrefix(
            IStreamArtistOwner(e.payoutOwner).ownerStateSnapshotV2(),
            IStreamArtistNativeReceipts(e.payoutOwner).artistNativeReceiptCount()
        );
        f.payoutInventory = Payout(e.payoutOwner).payoutRewindInventoryV3(b.identity.artistId);
        if (
            keccak256(abi.encode(f.payout)) != keccak256(abi.encode(b.payout))
                || keccak256(abi.encode(f.payoutInventory))
                    != keccak256(abi.encode(b.payoutInventory))
        ) {
            revert W.InvalidRecoveryRewindSelection(f.selection.sourceKey);
        }
    }

    function _role(
        Owner owner,
        R.Request memory p,
        T.Authorization memory a,
        bytes32 hash,
        W.CrossOwnerFactsV3 memory facts
    ) private view returns (bytes32 role) {
        role = owner.guardianRecoveryAuthorityRoleV3(p, a, hash, facts);
        if (role != Appeal.ARBITER && role != Appeal.APPEAL) {
            revert R.InvalidIdentityRecoveryGovernance();
        }
    }

    function _state(
        Owner owner,
        bytes32 artistId,
        bytes32 actionId,
        StreamArtistRecoveryRewindOperations.Evidence memory e,
        bytes32 role
    ) private view returns (W.EvidenceStateV3 memory s) {
        s = owner.identityRecoveryEvidenceStateV3(artistId, actionId);
        if (
            s.manifestHash != e.manifestHash || s.policyCommitment == 0 || s.associationHash == 0
                || s.requiredRole != role || s.selectionCommitment != e.facts.selection.commitment
                || s.sourceKey != e.facts.selection.sourceKey
                || s.sourceCommitment != e.facts.selection.sourceCommitment
                || keccak256(abi.encode(s.sources.identityBefore))
                    != keccak256(abi.encode(e.manifest.identity))
                || keccak256(abi.encode(s.sources.payout))
                    != keccak256(abi.encode(e.manifest.payout))
        ) revert T.InvalidRecord();
    }

    function _evidence(
        D.CoordinatorContext memory x,
        W.EnvironmentV3 memory env,
        R.Request memory p,
        bytes32 hash,
        bytes32 role,
        W.CrossOwnerFactsV3 memory facts
    ) private view returns (StreamArtistRecoveryRewindOperations.Evidence memory e) {
        e.manifestHash = hash;
        e.facts = facts;
        IStreamArtistRecoveryRewindEvidence publisher = EvidenceReads.publisher(env);
        bytes32 identityPin;
        bytes32 payoutPin;
        (e.manifest, identityPin, payoutPin) = publisher.resolutionManifestV3(hash);
        if (
            identityPin != env.identityCodeHash || payoutPin != env.payoutCodeHash
                || W.manifestHash(env, e.manifest) != hash || e.manifest.artistId != p.artistId
                || e.manifest.requestCommitment != W.requestCommitment(p)
        ) {
            revert W.InvalidRecoveryRewindManifest(hash);
        }
        if (role == Appeal.APPEAL) {
            (e.appeal, identityPin, payoutPin) = publisher.appealEvidenceV3(p.evidenceHash);
            if (
                identityPin != env.identityCodeHash || payoutPin != env.payoutCodeHash
                    || e.appeal.resolutionManifestHash != hash
                    || W.appealHash(env, e.appeal) != p.evidenceHash
            ) {
                revert W.InvalidRecoveryRewindAppeal(p.evidenceHash);
            }
            e.appealAuthority = StreamArtistGuardianAppealAuthority.current(
                IStreamArtistIdentityContestOwner(env.identityOwner).artistWindowAuthority(),
                x.suite.roleRegistry
            );
        }
    }

    function _notice(address identity, bytes32 causeHash) private view returns (bytes memory) {
        Resolution.Cause memory cause =
            IStreamArtistIdentityDismissalOwner(identity).identityContestCause(causeHash);
        if (cause.facts.priorStatus != 2) return bytes("");
        (bytes32 hash, uint8 phase, bytes32 terminalHash) = IStreamArtistDormancyOwner(identity)
            .dormancyResolutionState(cause.facts.artistId, causeHash);
        (Dorm.Notice memory notice, uint8 actualPhase, Dorm.Terminal memory terminal) =
            IStreamArtistDormancyOwner(identity).dormancyRecord(hash);
        if (
            cause.causeHash != causeHash || hash == 0 || notice.recordHash != hash
                || notice.terms.artistId != cause.facts.artistId || phase != actualPhase
                || terminal.recordHash != terminalHash
        ) {
            revert T.InvalidRecord();
        }
        return abi.encode(cause, notice, phase, terminal);
    }

    function _snapshots(T.SuiteConfiguration memory suite)
        private
        view
        returns (T.Snapshot[7] memory s)
    {
        s[2] = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        s[5] = IStreamArtistOwner(suite.owners[5]).ownerStateSnapshotV2();
    }

    function _archive(
        D.CoordinatorContext memory x,
        address actor,
        uint16 operation,
        bytes32 commitment,
        T.Snapshot[7] memory before_,
        bytes memory payload
    ) private {
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
            _snapshots(x.suite),
            payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
