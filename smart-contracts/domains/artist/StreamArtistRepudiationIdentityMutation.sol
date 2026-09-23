// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRepudiationAdmission.sol";
import "./StreamArtistEstateOwnerMutation.sol";

/// @notice Original Identity authorization and canonical compromise composition for47/48.
library StreamArtistRepudiationIdentityMutation {
    function consume(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        (
            T.ActionContext memory c,
            AD.Filing memory p,
            RP.Admission memory admission,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(
            data, (T.ActionContext, AD.Filing, RP.Admission, T.Authorization, T.SignerApproval)
        );
        StreamArtistRepudiationHashes.validate(p);
        T.Identity storage actual = identity.identities[admission.binding_.artistId];
        if (
            c.operationId != 47 || p.bindingGeneration != admission.binding_.generation
                || actual.authorityAddress != admission.authorityHead.principal
                || actual.authorityClass != admission.authorityHead.authorityClass
                || admission.stagedAt != block.timestamp || (!proof.direct && a.time == 0)
                || (a.time != 0 && block.timestamp > a.time)
        ) revert T.InvalidRecord();
        RP.Record memory r = RP.Record(
            0,
            p,
            admission.binding_.artistId,
            actual.authorityAddress,
            actual.authorityClass,
            a.nonce,
            admission.stagedAt,
            admission.executableAt,
            admission.binding_.bindingHash,
            admission.authorityHead,
            admission.guardianSet,
            admission.windowRevision
        );
        record = StreamArtistRepudiationHashes.recordHash(o.environment, r);
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            r.artistId,
            a,
            proof,
            StreamArtistRepudiationHashes.digest(o.environment, p, a),
            record,
            r.signer
        );
    }

    function contest(
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityContestState.State storage contests,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistIdentityRecoveryState.State storage recovery,
        StreamArtistDormancyState.State storage dormancy,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata data
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 artistId) {
        (T.ActionContext memory c, RP.GuardianProof memory proof) =
            abi.decode(data, (T.ActionContext, RP.GuardianProof));
        T.SuiteConfiguration memory s =
            StreamArtistRepudiationAdmission.suite(o.environment.registry, o.coordinator);
        (RP.Record memory r, bytes32 guardians) = StreamArtistRepudiationAdmission.veto(s, c, proof);
        artistId = r.artistId;
        Contest.Request memory p = Contest.Request(artistId, 0, r.recordHash, proof.reasonHash);
        m = StreamArtistIdentityCauseState.fileRepudiation(
            resolutions, identity, rotations, contests, replay, o, c, p, guardians
        );
        (bytes32 estateDelta, bytes32 replayDelta) = StreamArtistEstateState.contest(
            estate,
            replay,
            o,
            artistId,
            0,
            rotations.latestExecution[artistId],
            false,
            resolutions.closures[rotations.latestExecution[artistId]].dismissalRecordHash != 0
        );
        if (estateDelta != 0) m.state = keccak256(abi.encode(m.state, estateDelta));
        if (replayDelta != 0) m.replay = keccak256(abi.encode(m.replay, replayDelta));
        bytes32 recoveryDelta = StreamArtistIdentityRecoveryState.contest(
            recovery,
            artistId,
            0,
            rotations.latestExecution[artistId],
            false,
            resolutions.closures[rotations.latestExecution[artistId]].dismissalRecordHash != 0
        );
        if (recoveryDelta != 0) m.state = keccak256(abi.encode(m.state, recoveryDelta));
        bytes32 dormancyDelta = StreamArtistDormancyState.contest(
            dormancy, resolutions, artistId, rotations.latestExecution[artistId]
        );
        if (dormancyDelta != 0) m.state = keccak256(abi.encode(m.state, dormancyDelta));
        m.state = keccak256(abi.encode(m.state, proof, r.recordHash));
    }
}
