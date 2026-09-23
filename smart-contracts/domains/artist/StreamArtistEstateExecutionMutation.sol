// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistGuardianVestingAdmission } from "./StreamArtistGuardianVestingAdmission.sol";
import { StreamArtistIdentityRecoveryState } from "./StreamArtistIdentityRecoveryState.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import "./StreamArtistIdentityDismissalState.sol";
import "./StreamArtistEstateReads.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";

/// @notice Exact estate execution mutation, delegated by the fixed Identity child after its owner guard.
/// @dev The calling owner retains the one original commit and Archive transaction boundary.
library StreamArtistEstateExecutionMutation {
    function execute(
        StreamArtistIdentityRecoveryState.State storage recovery,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Estate.Execution memory p,
        StreamArchivalTypes.CoverageFacts memory coverage,
        Contest.GovernanceWitness memory governance
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        bytes32 previousVesting = rotations.latestExecution[p.artistId];
        Estate.RequestRecord storage request = estate.requests[p.expectedActivationRecordHash];
        _coverage(coverage, p.currentCoverageHash, p.artistId, request.terms.evidenceHash);
        (uint32 capabilities, Estate.AccelerationContext memory x) = StreamArtistEstateReads.executionFacts(
            estate,
            identity,
            rotations,
            succession,
            resolutions,
            o.environment,
            p,
            coverage.envelopeHash
        );
        bytes32 witness;
        if (governance.actionId != bytes32(0)) {
            address executor =
                IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority();
            if (
                c.actor != executor || governance.actionClass != 1
                    || governance.proposer == address(0) || governance.scopeHash != x.scopeHash
                    || governance.oldValueHash != x.oldValueHash
                    || governance.newValueHash != x.newValueHash
                    || governance.roleMutationHash != bytes32(0) || governance.roleRevision != 0
            ) revert Estate.InvalidEstateAcceleration();
            witness = keccak256(abi.encode(governance));
        } else {
            Contest.GovernanceWitness memory empty;
            if (keccak256(abi.encode(governance)) != keccak256(abi.encode(empty))) {
                revert Estate.InvalidEstateAcceleration();
            }
        }
        m = StreamArtistEstateState.execute(
            estate,
            identity,
            rotations,
            replay,
            o,
            c,
            p,
            capabilities,
            x,
            governance.actionId,
            witness
        );
        bytes32 snapshot = StreamArtistGuardianVestingAdmission.record(
            recovery,
            identity,
            rotations,
            estate,
            o.environment,
            V.Input(p.artistId, p.expectedActivationRecordHash, previousVesting, o.revision + 1, 40)
        );
        m.state = keccak256(abi.encode(m.state, snapshot));
    }

    function _coverage(
        StreamArchivalTypes.CoverageFacts memory f,
        bytes32 record,
        bytes32 artistId,
        bytes32 evidence
    ) private pure {
        if (
            record == bytes32(0) || f.coverageRecordHash != record || f.artistId != artistId
                || f.evidenceHash != evidence || evidence == bytes32(0)
                || f.envelopeHash == bytes32(0)
        ) {
            revert Estate.InvalidEstateCoverage(record);
        }
    }
}
