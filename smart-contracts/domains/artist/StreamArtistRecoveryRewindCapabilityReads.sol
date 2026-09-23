// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveryRewindCapabilityBounds as Fixed } from "./StreamArtistRecoveryRewindCapabilityBounds.sol";
import { StreamArtistRecoveryRewindCurrentCapabilities as Worker } from "./StreamArtistRecoveryRewindCurrentCapabilities.sol";

import { StreamArtistRecoveryRewindState as Rewind } from "./StreamArtistRecoveryRewindState.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistEstateState as Estate } from "./StreamArtistEstateState.sol";
import { StreamArtistDormancyState as Dormancy } from "./StreamArtistDormancyState.sol";
import { StreamArtistHashes as H } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryFamilyAncestry as Ancestry
} from "./StreamArtistRecoveryFamilyAncestry.sol";
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistRecoveryRewindEnvironment as Environment
} from "./StreamArtistRecoveryRewindEnvironment.sol";
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "./StreamArtistRecoveryRewindRecordReads.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistEstateTypes as E
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecoveryActionTypes as Action
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    IStreamArtistRecoveryRewindEvidence
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistRecoveryRewindSelection
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice Current estate bounds restored by an actual V3 recovery, with the original origin intact.
/// @dev The cheap owner read uses its own committed state. The full history proof independently
/// joins the original35 and its immutable completed plan; it never re-runs a current selection.
library StreamArtistRecoveryRewindCapabilityReads {
    // Retain the original error ABI entry now raised by the fixed worker.
    error InvalidIdentity(bytes32 artistId);
    struct SavedPlan {
        W.CapabilityContinuationV3 continuation;
        W.EvidenceStateV3 evidence;
        W.ResolutionManifestV3 manifest;
        W.ResultV3 selected;
        W.BasisV3 basis;
        W.ProgressV3 progress;
        Living.Facts recovered;
        Runtime.OriginFact original;
        Runtime.OriginFact preparation;
        W.EnvironmentV3 sourceEnvironment;
        bool imported;
    }

    function current(
        Rewind.State storage rewind,
        Identity.State storage identity,
        Estate.State storage estate,
        Dormancy.State storage dormancy,
        bytes32 artistId
    ) public view returns (E.AuthorityCapabilities memory f) {
        return Worker.current(rewind, identity, estate, dormancy, artistId);
    }

    function proof(
        H.Environment memory originalEnvironment,
        bytes32 artistId,
        V.Snapshot memory origin,
        uint32 originalMask,
        E.AuthorityCapabilities memory live,
        Ancestry.Member[] memory members
    ) public view returns (bytes32) {
        IStreamArtistIdentityRecoveryOwnerV3 owner =
            IStreamArtistIdentityRecoveryOwnerV3(address(this));
        bytes32 head = owner.latestRecoveryCapabilityContinuationV3(artistId);
        uint256 member = Fixed._latest(artistId, head, members);
        if (head == 0) {
            if (live.effectiveCapabilities != originalMask) {
                revert W.InvalidRecoveryRewindRecord(origin.transitionRecordHash);
            }
            return 0;
        }
        W.EnvironmentV3 memory e = Worker._environment();
        if (
            originalEnvironment.chainId != e.chainId || originalEnvironment.registry != e.registry
                || originalEnvironment.core != e.core || originalEnvironment.manager != e.manager
                || origin.artistId != artistId || origin.authorityClass != 3
                || (origin.operationId != 40 && origin.operationId != 43)
                || live.authorityClass != 3
                || live.activationRecordHash != origin.transitionRecordHash
        ) {
            revert W.InvalidRecoveryRewindRecord(head);
        }
        SavedPlan memory s;
        s.imported = Imported.commitment() != 0;
        s.sourceEnvironment = e;
        if (s.imported) {
            s.original = Worker._origin(e, head);
            s.sourceEnvironment = Runtime.rewindEnvironment(s.original.environment);
        }
        s.continuation = owner.recoveryCapabilityContinuationV3(head);
        W.CapabilityContinuationV3 memory c = s.continuation;
        s.recovered = Living.readFamily(address(this), e.registry, e.chainId, artistId, head);
        if (
            c.artistId != artistId || c.recoveryRecordHash != head
                || c.originalActivationRecordHash != origin.transitionRecordHash
                || c.originalActivationCapabilities != originalMask
                || c.authorityAddress != s.recovered.record.fields.newAddress
                || c.actionId != s.recovered.record.fields.governanceActionId
                || s.recovered.record.fields.vestedAuthorityClass != 3 || c.commitment == 0
                || c.commitment != W.capabilityContinuationHash(s.sourceEnvironment, c)
                || c.effectiveCapabilities != live.effectiveCapabilities
                || c.effectiveCapabilities & ~uint32(4095) != 0 || !Fixed._afterOrigin(e, s, origin)
                || keccak256(abi.encode(s.recovered.vesting, s.recovered.transition))
                    != keccak256(abi.encode(members[member].vesting, members[member].transition))
        ) {
            revert W.InvalidRecoveryRewindRecord(head);
        }
        s.evidence = owner.identityRecoveryEvidenceStateV3(artistId, c.actionId);
        _saved(s.sourceEnvironment, s);
        bytes32 selectedProof = Fixed._bounds(e, s);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_CAPABILITY_HISTORY_V3"),
                uint16(3),
                e,
                origin,
                originalMask,
                c,
                s.evidence,
                s.manifest,
                s.selected,
                s.basis,
                s.progress,
                s.recovered.proof,
                selectedProof
            )
        );
    }

    function _saved(W.EnvironmentV3 memory e, SavedPlan memory s) private view {
        W.CapabilityContinuationV3 memory c = s.continuation;
        W.EvidenceStateV3 memory evidence = s.evidence;
        if (
            evidence.manifestHash != c.manifestHash
                || evidence.selectionCommitment != c.planCommitment || evidence.sourceKey == 0
                || evidence.sourceCommitment == 0 || evidence.associationHash == 0
                || evidence.effectiveCapabilities != c.effectiveCapabilities
        ) revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        (Action.Association memory association,, bytes32 executed,) = IStreamArtistRecoveryActionOwner(
                address(this)
            ).identityRecoveryActionState(c.artistId, c.actionId);
        if (
            association.associationHash != evidence.associationHash
                || executed != c.recoveryRecordHash
                || evidence.sources.associationHash != evidence.associationHash
        ) revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        if (s.imported) {
            Runtime.Context memory clock =
                Recovered.load(address(this), Worker._environment().registry, e.chainId);
            s.preparation = Recovered.preparation(clock, association);
            if (
                s.preparation.point.environmentHash != s.original.point.environmentHash
                    || !Runtime.before(clock, s.preparation.point, s.original.point)
            ) {
                revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
            }
        }
        if (e.identityOwner.code.length == 0 || e.identityOwner.codehash != e.identityCodeHash) {
            revert W.RecoveryRewindDependencyChanged(e.identityOwner);
        }
        (address target, bytes32 pin) =
            IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner).recoveryRewindSelectionBinding();
        if (target.code.length == 0 || pin == 0 || target.codehash != pin) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
        IStreamArtistRecoveryRewindSelection selector = IStreamArtistRecoveryRewindSelection(target);
        if (
            selector.owner() != e.identityOwner || selector.payoutOwner() != e.payoutOwner
                || selector.artistRegistry() != e.registry
                || selector.deploymentChainId() != e.chainId
                || selector.coordinator() != e.coordinator
        ) revert W.RecoveryRewindDependencyChanged(target);
        s.selected = selector.selectionResultV3(evidence.sourceKey);
        (s.basis, s.progress) = selector.selectionV3(evidence.sourceKey);
        if (
            s.selected.sourceKey != evidence.sourceKey || s.selected.manifestHash != c.manifestHash
                || s.selected.sourceCommitment != evidence.sourceCommitment
                || s.selected.commitment != c.planCommitment
                || s.selected.commitment != W.selectionResultHash(e, s.selected)
                || s.selected.sourceKey != W.selectionKey(e, s.basis)
                || s.selected.inventoryCommitment
                    != W.selectionInventoryHash(
                        e, s.basis.identity.inventory, s.basis.payoutInventory
                    ) || !s.progress.complete || s.progress.resultCommitment != c.planCommitment
                || s.progress.identityProcessed != s.basis.identity.identity.receiptCount
                || s.progress.payoutProcessed != s.basis.payout.receiptCount
                || s.progress.guardiansProcessed != s.basis.identity.guardianHistory.count
                || s.basis.identity.artistId != c.artistId
                || s.basis.identity.manifestHash != c.manifestHash
                || s.basis.sourceCommitment != evidence.sourceCommitment
                || s.basis.sourceCommitment != W.selectionSourceHash(e, s.basis)
                || s.basis.identity.ownerCodeHash != e.identityCodeHash
                || s.basis.payoutCodeHash != e.payoutCodeHash
                || keccak256(abi.encode(s.basis.identity.identity, s.basis.payout))
                    != keccak256(
                        abi.encode(evidence.sources.identityBefore, evidence.sources.payout)
                    )
        ) {
            revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        }
        IStreamArtistRecoveryRewindEvidence publisher = Worker._publisher(e);
        bytes32 identityPin;
        bytes32 payoutPin;
        (s.manifest, identityPin, payoutPin) = publisher.resolutionManifestV3(c.manifestHash);
        if (
            identityPin != e.identityCodeHash || payoutPin != e.payoutCodeHash
                || W.manifestHash(e, s.manifest) != c.manifestHash
                || s.manifest.artistId != c.artistId
                || s.manifest.requestCommitment != W.requestCommitment(s.recovered.record.terms)
                || s.manifest.causeHash != s.recovered.record.terms.expectedCauseHash
                || s.manifest.resolutionHash != s.recovered.record.terms.expectedResolutionHash
                || s.manifest.executedHead != s.recovered.vesting.previousTransitionRecordHash
                || association.ownerRevision != s.manifest.identity.snapshot.revision + 1
                || s.manifest.identity.snapshot.revision >= s.recovered.vesting.ownerRevision
                || keccak256(abi.encode(s.manifest.identity, s.manifest.payout))
                    != keccak256(abi.encode(s.basis.identity.identity, s.basis.payout))
        ) {
            revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        }
    }

}
