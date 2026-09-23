// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistCompleteHistoryHydrationFixture.sol";
import {
    IStreamArtistEstateOwner as CHC3EstateOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistRotationReads as CHC3RotationReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistSuccessionReads as CHC3SuccessionReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    StreamArtistGuardianVestingTypes as CHC3Vesting
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    IStreamArtistEstateActivation as CHC3Activation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEstateActivation.sol";

/// @notice Original Class3 activation and contest on the complete rich Class1 source.
/// @dev Preserves the registered collaborator and historical grant. The inherited Core,
/// documentary network data and scoped governance are explicit unit boundaries; every
/// Artist receipt, Safe authorization, replay cell, transition and Archive write is real.
/// V3 recovery and payout continuation are composed by the caller after the contest seam.
abstract contract ArtistCompleteHistoryClassThreeFixture is ArtistCompleteHistoryHydrationFixture {
    bytes32 internal chClassThreeActivation;
    OfficialSafe internal chClassThreeEstateSafe;
    uint256[] internal chClassThreeEstateKeys;

    function _chClassThreeHash(T.SuiteConfiguration memory selected)
        internal
        view
        returns (bytes32 hash)
    {
        address owner = selected.owners[2];
        (Estate.RequestRecord memory request, uint8 phase, Estate.ExecutionFacts memory facts) =
            CHC3EstateOwner(owner).estateActivationRecord(chClassThreeActivation);
        CHC3Vesting.Snapshot memory vesting;
        R.TransitionState memory transition;
        if (request.recordHash != 0) {
            vesting = IStreamArtistGuardianVestingHistory(owner)
                .guardianVestingSnapshot(artistId, chClassThreeActivation);
            transition = CHC3RotationReads(owner).artistTransitionState(chClassThreeActivation);
        }
        T.Identity memory identity = IStreamArtistIdentityOwner(owner).identity(artistId);
        Estate.AuthorityCapabilities memory capabilities;
        if (identity.authorityAddress != address(0)) {
            capabilities = CHC3EstateOwner(owner).currentAuthorityCapabilities(artistId);
        }
        hash = keccak256(abi.encode(request, phase, facts));
        hash = keccak256(
            abi.encode(
                hash,
                CHC3SuccessionReads(owner)
                    .successorDesignationRecord(request.designationRecordHash),
                CHC3RotationReads(owner).guardianSetRecord(request.guardianRecordHash),
                IStreamArtistIdentityOwner(owner).signatureBundle(request.designationRecordHash),
                IStreamArtistIdentityOwner(owner).signatureBundle(request.guardianRecordHash)
            )
        );
        hash = keccak256(
            abi.encode(
                hash,
                vesting,
                transition,
                CHRepudiationOwner(selected.owners[4])
                    .attributionRepudiationRecord(chRepudiation.recordHash),
                CHRepudiationOwner(selected.owners[4])
                    .attributionRepudiationTerminal(chRepudiation.recordHash)
            )
        );
        return keccak256(
            abi.encode(
                hash,
                identity,
                capabilities,
                CHC3RotationReads(owner).lastArtistTransition(artistId)
            )
        );
    }

    function _chAssertClassThree(T.SuiteConfiguration memory target) internal view {
        require(
            _chClassThreeHash(target) == _chClassThreeHash(suite),
            "original Class3 activation records and current head survive import"
        );
        Estate.AuthorityCapabilities memory rights =
            CHC3EstateOwner(target.owners[2]).currentAuthorityCapabilities(artistId);
        require(
            rights.authorityClass == 3 && rights.status == 3
                && rights.authorityAddress == address(artist)
                && IStreamArtistIdentityOwner(target.owners[2]).activeIdentity(address(artist))
                    == artistId
                && IStreamArtistIdentityOwner(target.owners[2])
                    .activeIdentity(address(delegateSafe)) == collaboratorId,
            "current real Class3 Safe and ordinary collaborator are retained"
        );
        // The current transition can be original40 or the caller's later original35.
        // Its exact source value is compared above rather than reset to the activation.
    }

    function _chClassThreeActivate(uint32 capabilities) internal returns (bytes32 activation) {
        require(chClassThreeActivation == 0, "one original Class3 activation");
        _chClassThreeCancelRepudiation();
        _chClassThreeGuardians();
        _chClassThreeFreshEstateSafe();
        Estate.Execution memory execution = _chClassThreeRequest(capabilities);
        activation = execution.expectedActivationRecordHash;
        (Estate.RequestRecord memory request,,) = ingress.estateActivationRecord(activation);
        uint256 nativeBefore = Native(suite.owners[2]).artistNativeReceiptCount();
        vm.warp(request.noticeEndsAt);
        ingress.executeEstateActivation(execution);
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == nativeBefore,
            "original40 does not add a normative native receipt"
        );
        require(
            _snapshot(activation).operationId == 40 && _snapshot(activation).authorityClass == 3
                && _snapshot(activation).guardians.count == 1,
            "original40 freezes the real living guardian prefix"
        );
        Estate.AuthorityCapabilities memory rights = ingress.currentAuthorityCapabilities(artistId);
        require(
            rights.authorityAddress == address(chClassThreeEstateSafe) && rights.authorityClass == 3
                && rights.status == 3 && rights.effectiveCapabilities == capabilities
                && rights.activationRecordHash == activation,
            "original40 installs only the designated Class3 capabilities"
        );
        _rhCandidate(2, "identity_authority.replay.activation_execution_key", activation);
        _rhCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(artistId, request.incumbent, activation))
        );
        chClassThreeActivation = activation;
        artist = chClassThreeEstateSafe;
        keys = chClassThreeEstateKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).activeIdentity(address(delegateSafe))
                == collaboratorId,
            "ordinary collaborator keeps its original registered Safe"
        );
        // Stay at the original execution time. The caller can write actual provisional
        // Class3 payouts/attestations before producing the compromise and V3 recovery.
    }

    function _chClassThreeContest() internal returns (Dismissal.Cause memory cause) {
        bytes32 subject = chClassThreeActivation;
        require(subject != 0, "original40 precedes the Class3 contest");
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(abi.encode("complete Class3 actual compromise", subject));
        bytes32 reason = keccak256(abi.encode("complete Class3 compromise reason", subject));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:complete:class3:33"
        );
        (bytes32 scope, bytes32 oldValue, bytes32 newValue) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        authority.executeModuleContextWithAction(
            keccak256(abi.encode("complete Class3 original33", subject)),
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, subject, evidence, reason)
            ),
            1,
            scope,
            oldValue,
            newValue
        );
        cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.executedTransitionHash == subject
                && cause.facts.incumbent == address(artist),
            "original33 records the actual Class3 principal and transition"
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("subject"), artistId, subject, evidence, reason))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("record"), cause.facts.referenceHash))
        );
        (bool active, bytes32 action, uint8 kind, bytes32 scope_, bytes32 old_, bytes32 new_) =
            authority.currentAction();
        require(
            !active && action == 0 && kind == 0 && scope_ == 0 && old_ == 0 && new_ == 0,
            "scoped original33 governance context restored"
        );
    }

    function _chClassThreeCancelRepudiation() private {
        bytes32 record = chRepudiation.recordHash;
        require(
            record != 0 && chRepudiation.artistId == artistId
                && chRepudiation.signer == address(artist)
                && CHRepudiationOwner(suite.owners[4]).rawPendingRepudiation(1) == record,
            "original Class1 signer cancels its actual pending47"
        );
        uint256 identityBefore = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 attributionBefore = Native(suite.owners[4]).artistNativeReceiptCount();
        require(
            this.executeTargetSafe(
                address(ingress),
                abi.encodeCall(CHRepudiation.cancelAttributionRepudiation, (uint256(1), record))
            ),
            "actual original signer Safe cancellation49"
        );
        CHRP.Terminal memory terminal =
            CHRepudiationOwner(suite.owners[4]).attributionRepudiationTerminal(record);
        require(
            terminal.phase == 3 && terminal.actor == address(artist)
                && CHRepudiationOwner(suite.owners[4]).rawPendingRepudiation(1) == 0,
            "original49 retains the canceled47 cohort"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == identityBefore
                && Native(suite.owners[4]).artistNativeReceiptCount() == attributionBefore,
            "original49 does not append native identity or attribution receipts"
        );
        _rhCandidate(4, "attribution_lifecycle.replay.repudiation_cancellation_key", record);
    }

    function _chClassThreeGuardians() private {
        address[] memory members = new address[](1);
        members[0] = address(artist);
        R.GuardianSet memory terms = R.GuardianSet(artistId, members, 1, 10 days);
        T.Authorization memory authorization = _chAuthorization(true);
        bytes32 digest = ingress.guardianSetDigest(terms, authorization);
        authorization.signature = _signature(digest);
        bytes32 record = ingress.setArtistGuardians(terms, authorization);
        _pcRemember(artistId, record, digest, authorization);
        _rhCandidate(
            2,
            "identity_authority.replay.guardian_set_chain",
            keccak256(abi.encode(artistId, authorization.nonce))
        );
    }

    function _chClassThreeFreshEstateSafe() private {
        chClassThreeEstateKeys = new uint256[](2);
        chClassThreeEstateKeys[0] = 0xC3E5701;
        chClassThreeEstateKeys[1] = 0xC3E5702;
        chClassThreeEstateSafe = createOfficialSafe(
            safeComponents, safeOwnerAddresses(chClassThreeEstateKeys), 2, 0xC3E5700
        );
        require(
            address(chClassThreeEstateSafe) != address(artist)
                && address(chClassThreeEstateSafe) != address(delegateSafe)
                && IStreamArtistIdentityOwner(suite.owners[2])
                    .activeIdentity(address(chClassThreeEstateSafe)) == 0,
            "genuinely unregistered estate successor Safe"
        );
    }

    function _chClassThreeRequest(uint32 capabilities)
        private
        returns (Estate.Execution memory execution)
    {
        Succ.Designation memory terms = _successorTerms(address(chClassThreeEstateSafe), 2);
        terms.grantedCapabilities = capabilities;
        T.Authorization memory authorization = _chAuthorization(true);
        bytes32 digest = ingress.successorDesignationDigest(terms, authorization);
        authorization.signature = _signature(digest);
        bytes32 designation = ingress.recordSuccessorDesignation(terms, authorization);
        _pcRemember(artistId, designation, digest, authorization);
        _rhCandidate(
            2, "identity_authority.replay.succession_chain", keccak256(abi.encode(designation))
        );
        (bytes32 evidence, bytes32 coverage) = _estateArchiveEvidence(artistId);
        Estate.Request memory request = Estate.Request(
            artistId, address(chClassThreeEstateSafe), evidence, designation, coverage
        );
        authorization = T.Authorization(
            ingress.estateActivationNonceHint(artistId, address(chClassThreeEstateSafe)),
            uint64(block.timestamp + 1 days),
            ""
        );
        require(
            executeSafe(
                chClassThreeEstateSafe,
                chClassThreeEstateKeys,
                address(ingress),
                0,
                abi.encodeCall(CHC3Activation.requestEstateActivation, (request, authorization)),
                0
            ),
            "original38 requested by the fresh estate Safe"
        );
        (,, bytes32 activation) = ingress.estateActivationState(artistId);
        require(activation != 0, "real original38 request record");
        digest = ingress.estateActivationDigest(request, authorization);
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    "estate_activation",
                    artistId,
                    address(chClassThreeEstateSafe),
                    authorization.nonce
                )
            )
        );
        _rhCandidate(2, "identity_authority.replay.activation_request_key", activation);
        return Estate.Execution(artistId, activation, coverage);
    }
}
