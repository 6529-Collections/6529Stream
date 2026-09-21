// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveryRewindCurrentCapabilities as Worker
} from "./StreamArtistRecoveryRewindCurrentCapabilities.sol";

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

import {
    StreamArtistRecoveryRewindCapabilityReads as Original
} from "./StreamArtistRecoveryRewindCapabilityReads.sol";

/// @notice Fixed typed historical checks at their original call positions.
library StreamArtistRecoveryRewindCapabilityBounds {
    function _bounds(W.EnvironmentV3 memory e, Original.SavedPlan memory s)
        public
        view
        returns (bytes32)
    {
        W.CapabilityContinuationV3 memory c = s.continuation;
        if (
            c.designationRecordHash == 0
                || s.selected.designation.operative.recordHash != c.designationRecordHash
                || s.selected.directive.operative.recordHash != c.forbiddenDirectiveRecordHash
        ) revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        Records.Facts memory designation =
            _selected(e, s, W.RecordKind.SUCCESSOR_DESIGNATION, s.selected.designation.operative);
        if (designation.pairedDirective != c.pairedDirectiveRecordHash) {
            revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        }
        uint32 caps = designation.grantedCapabilities;
        bytes32 pairedProof;
        if (c.pairedDirectiveRecordHash != 0) {
            (uint32 granted, bytes32 p) = _paired(e, s, c.pairedDirectiveRecordHash);
            caps &= granted;
            pairedProof = p;
        }
        Records.Facts memory forbidden;
        if (c.forbiddenDirectiveRecordHash != 0) {
            forbidden =
                _selected(e, s, W.RecordKind.ESTATE_DIRECTIVE, s.selected.directive.operative);
            caps &= ~forbidden.forbiddenCapabilities;
        } else {
            W.SelectedRecordV3 memory empty;
            if (
                keccak256(abi.encode(s.selected.directive.operative))
                    != keccak256(abi.encode(empty))
            ) revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        }
        if (caps != c.effectiveCapabilities || caps & ~uint32(4095) != 0) {
            revert W.InvalidRecoveryRewindRecord(c.recoveryRecordHash);
        }
        return keccak256(
            abi.encode(
                designation.selected.originalDataHash,
                pairedProof,
                forbidden.selected.originalDataHash,
                caps
            )
        );
    }

    function _selected(
        W.EnvironmentV3 memory e,
        Original.SavedPlan memory s,
        W.RecordKind kind,
        W.SelectedRecordV3 memory expected
    ) private view returns (Records.Facts memory f) {
        if (
            expected.recordHash == 0 || expected.admissionProof == 0
                || expected.nativeIndex >= s.manifest.identity.receiptCount
        ) {
            revert W.InvalidRecoveryRewindRecord(expected.recordHash);
        }
        f = Records.read(e, kind, s.continuation.artistId, expected.nativeIndex);
        if (
            f.selected.recordHash != expected.recordHash
                || f.selected.originalDataHash != expected.originalDataHash
                || f.selected.nonce != expected.nonce
                || !_admittedBefore(e, s, expected.nativeIndex, f.admissionRevision)
                || !R.eligible(
                    s.continuation.artistId,
                    f.association,
                    f.transition,
                    s.recovered.record.fields.recoveredAt
                )
        ) revert W.InvalidRecoveryRewindRecord(expected.recordHash);
        // Mutable later closures are authenticated by Records.read, but do not alter the frozen
        // admissionProof in this historical completed result or select a different old winner.
    }

    function _paired(W.EnvironmentV3 memory e, Original.SavedPlan memory s, bytes32 hash)
        private
        view
        returns (uint32 granted, bytes32 proof_)
    {
        (address target,) = IStreamArtistIdentityRecoveryOwnerV3(s.sourceEnvironment.identityOwner)
            .recoveryRewindSelectionBinding();
        (W.RecordKind kind, W.SelectedRecordV3 memory selected, bool retained, bool eligible) = IStreamArtistRecoveryRewindSelection(
                target
            ).selectionRecordV3(s.selected.sourceKey, hash);
        if (
            kind != W.RecordKind.ESTATE_DIRECTIVE || selected.recordHash != hash || !retained
                || !eligible
        ) revert W.InvalidRecoveryRewindRecord(hash);
        Records.Facts memory f = _selected(e, s, kind, selected);
        return (f.grantedCapabilities, keccak256(abi.encode(kind, selected, retained, eligible)));
    }

    function _admittedBefore(
        W.EnvironmentV3 memory e,
        Original.SavedPlan memory s,
        uint256 index,
        uint64 revision
    ) private view returns (bool) {
        if (!s.imported) return revision <= s.manifest.identity.snapshot.revision;
        // A complete imported prefix keeps every original logical index unchanged.
        // The original preparation immediately follows its saved before-snapshot.
        Runtime.Context memory clock = Runtime.load(e, 2);
        Runtime.ReceiptFact memory receipt = Runtime.receiptAt(clock, index);
        return receipt.position.point.ownerRevision == revision
            && Runtime.before(clock, receipt.position.point, s.preparation.point);
    }

    function _latest(bytes32 artistId, bytes32 head, Ancestry.Member[] memory members)
        public
        view
        returns (uint256 chosen)
    {
        IStreamArtistIdentityRecoveryOwnerV3 owner =
            IStreamArtistIdentityRecoveryOwnerV3(address(this));
        bool found;
        for (uint256 i; i < members.length; ++i) {
            V.Snapshot memory v = members[i].vesting;
            if (v.operationId != 35 || v.authorityClass != 3) continue;
            W.CapabilityContinuationV3 memory c =
                owner.recoveryCapabilityContinuationV3(v.transitionRecordHash);
            Recovery.Record memory r = IStreamArtistIdentityRecoveryOwner(address(this))
                .identityRecoveryRecord(v.transitionRecordHash);
            W.EvidenceStateV3 memory evidence =
                owner.identityRecoveryEvidenceStateV3(artistId, r.fields.governanceActionId);
            if (c.commitment == 0) {
                W.CapabilityContinuationV3 memory empty;
                if (
                    keccak256(abi.encode(c)) != keccak256(abi.encode(empty))
                        || evidence.manifestHash != 0
                ) revert W.InvalidRecoveryRewindRecord(v.transitionRecordHash);
                continue;
            }
            if (
                evidence.manifestHash == 0 || c.artistId != artistId
                    || c.recoveryRecordHash != v.transitionRecordHash
            ) revert W.InvalidRecoveryRewindRecord(v.transitionRecordHash);
            if (!found) {
                if (head != v.transitionRecordHash) revert W.InvalidRecoveryRewindRecord(head);
                chosen = i;
                found = true;
            }
        }
        if ((head != 0) != found) revert W.InvalidRecoveryRewindRecord(head);
    }

    function _afterOrigin(
        W.EnvironmentV3 memory e,
        Original.SavedPlan memory s,
        V.Snapshot memory origin
    ) public view returns (bool) {
        if (!s.imported) {
            return s.recovered.vesting.ownerRevision > origin.ownerRevision;
        }
        Runtime.Context memory clock = Runtime.load(e, 2);
        return Runtime.before(clock, Recovered.vesting(clock, origin).point, s.original.point);
    }
}
