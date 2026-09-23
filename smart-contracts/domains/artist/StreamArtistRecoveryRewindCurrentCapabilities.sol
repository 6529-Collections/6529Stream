// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

/// @notice Fixed typed worker preserving the original validation and caller context.
library StreamArtistRecoveryRewindCurrentCapabilities {
    function current(
        Rewind.State storage rewind,
        Identity.State storage identity,
        Estate.State storage estate,
        Dormancy.State storage dormancy,
        bytes32 artistId
    ) public view returns (E.AuthorityCapabilities memory f) {
        T.Identity storage p = identity.identities[artistId];
        if (
            p.authorityClass != 3 || (p.status != 3 && p.status != 4)
                || p.authorityAddress == address(0)
                || identity.activeIdentity[p.authorityAddress] != artistId
        ) {
            revert T.InvalidIdentity(artistId);
        }
        f = E.AuthorityCapabilities(p.authorityAddress, 3, p.status, 0, bytes32(0));
        bytes32 origin = dormancy.activation[artistId];
        if (origin != 0) {
            Dorm.Terminal storage terminal = dormancy.terminals[origin];
            Dorm.Notice storage notice = dormancy.notices[terminal.noticeHash];
            if (
                terminal.recordHash != origin || terminal.authorityClass != 3
                    || terminal.plan.authorityClass != 3 || terminal.plan.authority == address(0)
                    || notice.terms.artistId != artistId
                    || dormancy.phases[terminal.noticeHash] != 3
                    || dormancy.terminalForNotice[terminal.noticeHash] != origin
                    || terminal.observedAt == 0 || terminal.delegationEpoch == 0
            ) revert T.InvalidIdentity(artistId);
            f.effectiveCapabilities = terminal.plan.capabilities;
        } else {
            origin = estate.authorityActivation[artistId];
            E.RequestRecord storage request = estate.requests[origin];
            E.ExecutionFacts storage execution = estate.executions[origin];
            if (
                origin == 0 || estate.phases[origin] != 2 || request.recordHash != origin
                    || request.terms.artistId != artistId
                    || execution.activationRecordHash != origin || execution.executedAt == 0
                    || execution.delegationEpoch == 0
            ) revert T.InvalidIdentity(artistId);
            f.effectiveCapabilities = execution.effectiveCapabilities;
        }
        f.activationRecordHash = origin;
        bytes32 head = rewind.capabilityHead[artistId];
        if (head == 0) return f;
        W.CapabilityContinuationV3 memory c = rewind.capabilityContinuations[head];
        W.EnvironmentV3 memory e = _environment();
        if (Imported.commitment() != 0) {
            e = Runtime.rewindEnvironment(_origin(e, head).environment);
        }
        if (
            c.artistId != artistId || c.recoveryRecordHash != head || c.actionId == 0
                || c.manifestHash == 0 || c.planCommitment == 0 || c.designationRecordHash == 0
                || c.originalActivationRecordHash != origin
                || c.originalActivationCapabilities != f.effectiveCapabilities
                || c.effectiveCapabilities & ~uint32(4095) != 0 || c.authorityAddress == address(0)
                || c.commitment == 0 || W.capabilityContinuationHash(e, c) != c.commitment
        ) {
            revert W.InvalidRecoveryRewindRecord(head);
        }
        // A later rotation changes the live address, not the restored capability ceiling.
        f.effectiveCapabilities = c.effectiveCapabilities;
    }

    function _origin(W.EnvironmentV3 memory e, bytes32 head)
        public
        view
        returns (Runtime.OriginFact memory original)
    {
        Runtime.Context memory clock = Runtime.load(e, 2);
        original = Runtime.auxiliary(
            clock, keccak256("identity_authority.hydration.capability_continuation_v3"), head
        );
        Recovery.Record memory r =
            IStreamArtistIdentityRecoveryOwner(address(this)).identityRecoveryRecord(head);
        Runtime.ReceiptFact memory receipt =
            Recovered.nativeFact(clock, 35, r.fields.artistId, head);
        if (!Recovered.samePoint(receipt.position.point, original.point)) {
            revert W.InvalidRecoveryRewindRecord(head);
        }
    }

    function _environment() public view returns (W.EnvironmentV3 memory) {
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        return Environment.fromFixed(
            address(this),
            owner.artistRegistry(),
            owner.operationCoordinator(),
            owner.archiveV2(),
            owner.core(),
            owner.mintManager()
        );
    }

    function _publisher(W.EnvironmentV3 memory e)
        public
        view
        returns (IStreamArtistRecoveryRewindEvidence p)
    {
        (address target, bytes32 pin) = IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner)
            .recoveryRewindEvidenceBinding();
        if (target.code.length == 0 || pin == 0 || target.codehash != pin) {
            revert W.RecoveryRewindDependencyChanged(target);
        }
        p = IStreamArtistRecoveryRewindEvidence(target);
        if (
            p.owner() != e.identityOwner || p.payoutOwner() != e.payoutOwner
                || p.artistRegistry() != e.registry || p.deploymentChainId() != e.chainId
                || p.coordinator() != e.coordinator || p.archive() != e.archive
                || p.core() != e.core || p.mintManager() != e.manager
        ) revert W.RecoveryRewindDependencyChanged(target);
    }
}
