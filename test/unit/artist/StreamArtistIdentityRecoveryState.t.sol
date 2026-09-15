// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistHashes } from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistIdentityRecoveryState as S
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryState.sol";
import {
    StreamArtistIdentityState as I
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityState.sol";
import {
    StreamArtistRotationState as Rotation
} from "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistEstateState as Estate
} from "../../../smart-contracts/domains/artist/StreamArtistEstateState.sol";
import {
    StreamArtistIdentityRecoveryReceipts as Receipts
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryReceipts.sol";
import {
    StreamArtistRotationHashes as RotationHashes
} from "../../../smart-contracts/domains/artist/StreamArtistRotationHashes.sol";
import {
    StreamArtistIdentityRecoveryHashes as H
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryHashes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityRecoveryTypes as Permanent
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

interface RecoveryStateVm {
    function warp(uint256 timestamp) external;
}

/// @dev Prepared storage and verified-proof boundary. No signature, arbiter or Archive ingress is mocked as actual.
contract IdentityRecoveryStateHarness is StreamArtistOwner {
    I.State private identity;
    Rotation.State private rotations;
    Resolution.State private resolutions;
    Estate.State private estate;
    S.State private recovery;
    error LateFixtureFailure();

    constructor(address coordinator)
        StreamArtistOwner(
            address(0x11),
            coordinator,
            address(0x33),
            keccak256("domain:identity_authority"),
            address(0x44),
            address(0x55)
        )
    { }

    function ownerContext() public view returns (I.OwnerContext memory) {
        return I.OwnerContext(
            StreamArtistHashes.Environment(deploymentChainId, artistRegistry, core, mintManager),
            operationCoordinator,
            archiveV2,
            domainId,
            _revision
        );
    }

    function seed(bytes32 artist, address oldAddress, bytes32 causeHash, bytes32 dismissal)
        external
    {
        identity.identities[artist] = T.Identity(
            oldAddress, 1, 4, 10, 20, bytes32(uint256(0x81)), "ar://identity", "original", 17
        );
        identity.activeIdentity[oldAddress] = artist;
        Dismissal.CauseFacts memory facts;
        facts.artistId = artist;
        facts.kind = 1;
        facts.referenceHash = bytes32(uint256(0x91));
        facts.actor = address(0x92);
        facts.reasonHash = bytes32(uint256(0x93));
        facts.evidenceHash = bytes32(uint256(0x94));
        facts.enteredAt = 30;
        facts.incumbent = oldAddress;
        facts.authorityClass = 1;
        facts.priorStatus = 1;
        facts.previousResolutionHash = dismissal;
        resolutions.causes[causeHash] = Dismissal.Cause(causeHash, facts);
        resolutions.currentCause[artist] = causeHash;
        resolutions.latestResolution[artist] = dismissal;
    }

    function context(Recovery.Request calldata p, T.Authorization calldata a)
        external
        view
        returns (Recovery.Context memory)
    {
        return S.context(recovery, identity, rotations, resolutions, estate, ownerContext(), p, a);
    }

    function digest(Recovery.Request calldata p, T.Authorization calldata a)
        public
        view
        returns (bytes32)
    {
        return RotationHashes.acceptanceDigest(
            ownerContext().environment,
            R.Rotation(
                p.artistId,
                identity.identities[p.artistId].authorityAddress,
                p.newAddress,
                p.reasonHash,
                bytes32(0)
            ),
            a
        );
    }

    function recover(
        T.ActionContext calldata c,
        Recovery.Request calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        Contest.GovernanceWitness calldata g,
        bool fail
    ) external returns (Receipts.Pair memory pair) {
        _check(c, 35);
        I.Mutation memory m = S.recover(
            recovery,
            identity,
            rotations,
            resolutions,
            estate,
            _replay,
            S.Input(ownerContext(), c, p, a, proof, g, address(0x99))
        );
        Recovery.Record memory item = recovery.records[m.record];
        pair = _commitIdentityRecovery(
            recovery.receipts, c, m.action, m.state, m.replay, item.fields, p.supersededRecordHashes
        );
        require(pair.primaryHash == m.record, "owner recomputation");
        if (fail) revert LateFixtureFailure();
    }

    function facts(bytes32 artist, address oldAddress, address newAddress)
        external
        view
        returns (T.Identity memory, bytes32, bytes32, bytes32, bytes32, bytes32, uint64)
    {
        return (
            identity.identities[artist],
            identity.activeIdentity[oldAddress],
            identity.activeIdentity[newAddress],
            rotations.latestExecution[artist],
            rotations.latestTransition[artist],
            rotations.retirement[artist][oldAddress],
            estate.delegationEpoch[artist]
        );
    }

    function record(bytes32 hash) external view returns (Recovery.Record memory) {
        return recovery.records[hash];
    }

    function transition(bytes32 hash) external view returns (R.TransitionState memory) {
        return recovery.transitions[hash];
    }

    function preserved(bytes32 artist) external view returns (bytes32, bytes32) {
        return (resolutions.currentCause[artist], resolutions.latestResolution[artist]);
    }

    function sequence() external view returns (uint64) {
        return _recordSequence;
    }

    function nonce(bytes32 artist, address account, uint256 value)
        external
        view
        returns (bool, uint256)
    {
        return Rotation.acceptanceNonceState(
            rotations, _replay, ownerContext(), artist, account, value
        );
    }

    function key(bytes32 surface, bytes32 scope) external view returns (bytes32) {
        return _replayKey(surface, scope);
    }

    function secondary(bytes32 occurrence) external view returns (bytes32) {
        return recovery.receipts.secondaryOccurrences[occurrence];
    }

    function primary(bytes32 hash) external view returns (bytes32) {
        return recovery.receipts.receipts[Receipts.PRIMARY][hash];
    }

    function seedSecondary(bytes32 occurrence, bytes32 value) external {
        recovery.receipts.secondaryOccurrences[occurrence] = value;
    }

    function seedReplay(bytes32 replayKey, bytes32 value) external {
        _replay[replayKey] = T.ReplayCell(value, _revision, 1, 2);
    }

    function setEpoch(bytes32 artist, uint64 value) external {
        estate.delegationEpoch[artist] = value;
    }

    function setTiming(uint64 post, uint64 tail) external {
        rotations.rotationContestSeconds = post;
        rotations.priorStandingTailSeconds = tail;
    }

    function perturb(bytes32 artist, uint8 which, bytes32 value) external {
        if (which == 0) rotations.latestExecution[artist] = value;
        if (which == 1) rotations.latestTransition[artist] = value;
        if (which == 2) rotations.pending[artist] = value;
        if (which == 3) rotations.stableGuardian[artist] = value;
        if (which == 4) rotations.provisionalGuardian[artist] = value;
        if (which == 5) {
            resolutions.causes[resolutions.currentCause[artist]].facts.pendingTransitionHash = value;
        }
        if (which == 6) {
            resolutions.causes[resolutions.currentCause[artist]].facts.executedTransitionHash =
            value;
        }
        if (which == 7) {
            resolutions.causes[resolutions.currentCause[artist]].facts.priorStatus =
                uint8(uint256(value));
        }
        if (which == 8) identity.activeIdentity[address(0x77)] = value;
    }
}

contract StreamArtistIdentityRecoveryStateTest {
    RecoveryStateVm private constant vm =
        RecoveryStateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = bytes32(uint256(1));
    address private constant OLD = address(0x66);
    address private constant NEW = address(0x77);
    IdentityRecoveryStateHarness private host;

    function setUp() public {
        vm.warp(1_000_000);
        host = new IdentityRecoveryStateHarness(address(this));
        host.seed(ARTIST, OLD, bytes32(uint256(0xa1)), bytes32(uint256(0xa2)));
    }

    function _request() private pure returns (Recovery.Request memory) {
        return Recovery.Request(
            ARTIST,
            NEW,
            1,
            bytes32(uint256(0xa1)),
            bytes32(uint256(0xa2)),
            bytes32(uint256(0xa3)),
            bytes32(uint256(0xa4)),
            new bytes32[](0)
        );
    }

    function _authorization() private pure returns (T.Authorization memory) {
        return T.Authorization(0, 2_000_000, hex"01");
    }

    function _action() private view returns (T.ActionContext memory) {
        return T.ActionContext(35, address(0x99), host.ownerStateSnapshotV2());
    }

    function _witness(Recovery.Request memory p, T.Authorization memory a)
        private
        view
        returns (Contest.GovernanceWitness memory)
    {
        Recovery.Context memory c = host.context(p, a);
        return Contest.GovernanceWitness(
            bytes32(uint256(0xb1)),
            address(0xb2),
            2,
            bytes32(uint256(0xb3)),
            1,
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
    }

    function _proof(Recovery.Request memory p, T.Authorization memory a)
        private
        view
        returns (T.SignerApproval memory)
    {
        return T.SignerApproval(NEW, host.digest(p, a), false);
    }

    function _snapshot() private view returns (bytes32) {
        (
            T.Identity memory principal,
            bytes32 oldIndex,
            bytes32 newIndex,
            bytes32 execution,
            bytes32 latest,
            bytes32 retirement,
            uint64 epoch
        ) = host.facts(ARTIST, OLD, NEW);
        (bool used, uint256 hint) = host.nonce(ARTIST, NEW, 0);
        return keccak256(
            abi.encode(
                host.ownerStateSnapshotV2(),
                host.sequence(),
                principal,
                oldIndex,
                newIndex,
                execution,
                latest,
                retirement,
                epoch,
                used,
                hint
            )
        );
    }

    function _reject(bytes memory callData, bytes memory expected) private {
        (bool ok, bytes memory returned) = address(host).call(callData);
        require(!ok && keccak256(returned) == keccak256(expected), "exact rejection");
    }

    function _primary(Recovery.Request memory p, Contest.GovernanceWitness memory g)
        private
        view
        returns (bytes32)
    {
        bytes32[12] memory words;
        words[0] = 0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff;
        words[1] = bytes32(host.deploymentChainId());
        words[2] = bytes32(uint256(uint160(host.artistRegistry())));
        words[3] = ARTIST;
        words[4] = bytes32(uint256(uint160(OLD)));
        words[5] = bytes32(uint256(uint160(NEW)));
        words[6] = bytes32(uint256(1));
        words[7] = p.evidenceHash;
        words[8] = p.reasonHash;
        words[9] = keccak256(
            abi.encode(
                bytes32(0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae),
                p.supersededRecordHashes
            )
        );
        words[10] = g.actionId;
        words[11] = bytes32(block.timestamp);
        return keccak256(abi.encode(words));
    }

    function testInitialLivingRecoveryStoresExactRecordTransitionAndOneOwnerRevision() public {
        Recovery.Request memory p = _request();
        T.Authorization memory a = _authorization();
        Contest.GovernanceWitness memory g = _witness(p, a);
        bytes32 primary = _primary(p, g);
        bytes32 acceptedDigest = host.digest(p, a);
        Receipts.Pair memory pair = host.recover(_action(), p, a, _proof(p, a), g, false);
        require(
            pair.primaryHash == primary && host.sequence() == 2
                && host.ownerStateSnapshotV2().revision == 1
        );
        require(
            host.primary(primary) == pair.primaryCommitment
                && host.secondary(pair.occurrenceKey) == pair.secondaryCommitment
        );
        Recovery.Record memory item = host.record(primary);
        require(
            item.recordHash == primary && item.fields.oldAddress == OLD
                && item.fields.newAddress == NEW && item.fields.vestedAuthorityClass == 1
                && item.fields.recoveredAt == 1_000_000
        );
        require(
            keccak256(abi.encode(item.terms)) == keccak256(abi.encode(p))
                && item.acceptanceDigest == acceptedDigest
        );
        require(
            item.acceptanceNonce == 0 && item.acceptanceDeadline == 2_000_000
                && item.proposer == address(0xb2) && item.executor == address(0x99)
        );
        require(item.governanceWitnessHash == keccak256(abi.encode(g)) && item.delegationEpoch == 1);
        R.TransitionState memory t = host.transition(primary);
        require(
            keccak256(abi.encode(t))
                == keccak256(
                    abi.encode(
                        R.TransitionState(
                            ARTIST, primary, 1_000_000, 1_000_000, 1_000_000, 1_604_800, 0, 2
                        )
                    )
                )
        );
        (
            T.Identity memory principal,
            bytes32 oldIndex,
            bytes32 newIndex,
            bytes32 execution,
            bytes32 latest,
            bytes32 retirement,
            uint64 epoch
        ) = host.facts(ARTIST, OLD, NEW);
        require(
            principal.authorityAddress == NEW && principal.authorityClass == 1
                && principal.status == 1 && oldIndex == bytes32(0) && newIndex == ARTIST
        );
        require(
            principal.registeredAt == 10 && principal.lastAuthorityActionAt == 20
                && principal.nonceHint == 17
                && principal.identityRecordHash == bytes32(uint256(0x81))
        );
        require(execution == primary && latest == primary && retirement == primary && epoch == 1);
        (bytes32 cause, bytes32 dismissal) = host.preserved(ARTIST);
        require(cause == p.expectedCauseHash && dismissal == p.expectedResolutionHash);
        (bool used, uint256 hint) = host.nonce(ARTIST, NEW, 0);
        require(used && hint == 1);
    }

    function testEveryExcludedHistoryAndNonLivingCauseRejectsBeforeMutation() public {
        Recovery.Request memory p = _request();
        T.Authorization memory a = _authorization();
        for (uint8 which; which < 7; ++which) {
            host.perturb(ARTIST, which, bytes32(uint256(1)));
            bytes32 before = _snapshot();
            _reject(
                abi.encodeCall(host.context, (p, a)),
                abi.encodeWithSelector(Recovery.UnsupportedIdentityRecoveryProfile.selector, ARTIST)
            );
            require(before == _snapshot());
            host.perturb(ARTIST, which, bytes32(0));
        }
        host.perturb(ARTIST, 7, bytes32(uint256(2)));
        _reject(
            abi.encodeCall(host.context, (p, a)),
            abi.encodeWithSelector(Recovery.UnsupportedIdentityRecoveryProfile.selector, ARTIST)
        );
        host.perturb(ARTIST, 7, bytes32(uint256(1)));
        p.supersededRecordHashes = new bytes32[](1);
        p.supersededRecordHashes[0] = bytes32(uint256(1));
        _reject(
            abi.encodeCall(host.context, (p, a)),
            abi.encodeWithSelector(Recovery.UnsupportedIdentityRecoveryProfile.selector, ARTIST)
        );
        p = _request();
        host.perturb(ARTIST, 8, bytes32(uint256(2)));
        _reject(
            abi.encodeCall(host.context, (p, a)),
            abi.encodeWithSelector(T.AddressAlreadyRegistered.selector, NEW)
        );
        host.perturb(ARTIST, 8, bytes32(0));
        host.context(p, a);
    }

    function testExactGovernanceSnapshotAndAcceptanceProofRequired() public {
        Recovery.Request memory p = _request();
        T.Authorization memory a = _authorization();
        Contest.GovernanceWitness memory g = _witness(p, a);
        T.SignerApproval memory proof = _proof(p, a);
        bytes32 before = _snapshot();
        g.actionClass = 1;
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, proof, g, false)),
            abi.encodeWithSelector(Recovery.InvalidIdentityRecoveryGovernance.selector)
        );
        g = _witness(p, a);
        g.newValueHash = bytes32(uint256(7));
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, proof, g, false)),
            abi.encodeWithSelector(Recovery.InvalidIdentityRecoveryGovernance.selector)
        );
        g = _witness(p, a);
        proof.digest = bytes32(uint256(7));
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, proof, g, false)),
            abi.encodeWithSelector(T.InvalidSignature.selector)
        );
        proof = _proof(p, a);
        proof.direct = true;
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, proof, g, false)),
            abi.encodeWithSelector(T.InvalidSignature.selector)
        );
        require(before == _snapshot());
        host.recover(_action(), p, a, _proof(p, a), g, false);
    }

    function testSharedAcceptanceRevocationAndNonceReplayRollBack() public {
        Recovery.Request memory p = _request();
        T.Authorization memory a = _authorization();
        Contest.GovernanceWitness memory g = _witness(p, a);
        T.SignerApproval memory proof = _proof(p, a);
        bytes32 deny = host.key(
            keccak256("identity_authority.replay.digest_revocation"),
            keccak256(abi.encode(ARTIST, proof.digest))
        );
        host.seedReplay(deny, proof.digest);
        bytes32 before = _snapshot();
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, proof, g, false)),
            abi.encodeWithSelector(T.Replay.selector, deny)
        );
        require(before == _snapshot());
        // A different admitted signed nonce has a different original digest and can still be consumed.
        a.nonce = 3;
        g = _witness(p, a);
        proof = _proof(p, a);
        bytes32 nonceKey = host.key(
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode(keccak256("rotation_acceptance"), ARTIST, NEW, uint256(3)))
        );
        host.seedReplay(nonceKey, bytes32(uint256(1)));
        before = _snapshot();
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, proof, g, false)),
            abi.encodeWithSelector(T.Replay.selector, nonceKey)
        );
        require(before == _snapshot());
        a.nonce = 4;
        g = _witness(p, a);
        host.recover(_action(), p, a, _proof(p, a), g, false);
        (bool used, uint256 hint) = host.nonce(ARTIST, NEW, 4);
        require(used && hint == 0);
    }

    function testLatePairFailureRollsIdentityEpochNonceAndReceiptsBackThenRetries() public {
        Recovery.Request memory p = _request();
        T.Authorization memory a = _authorization();
        Contest.GovernanceWitness memory g = _witness(p, a);
        T.SignerApproval memory proof = _proof(p, a);
        bytes32 primary = _primary(p, g);
        bytes32 occurrence =
            Receipts.occurrenceKey(primary, H.supersession(p.supersededRecordHashes));
        host.seedSecondary(occurrence, bytes32(uint256(1)));
        bytes32 before = _snapshot();
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, proof, g, false)),
            abi.encodeWithSelector(Receipts.DuplicateRecoveryReceipt.selector, occurrence)
        );
        require(
            before == _snapshot() && host.primary(primary) == bytes32(0)
                && host.record(primary).recordHash == bytes32(0)
        );
        host.seedSecondary(occurrence, bytes32(0));
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, proof, g, true)),
            abi.encodeWithSelector(IdentityRecoveryStateHarness.LateFixtureFailure.selector)
        );
        require(
            before == _snapshot() && host.secondary(occurrence) == bytes32(0)
                && host.record(primary).recordHash == bytes32(0)
        );
        host.recover(_action(), p, a, proof, g, false);
    }

    function testTerminalMarkerPreventsSecondFirstProfileRecovery() public {
        Recovery.Request memory p = _request();
        T.Authorization memory a = _authorization();
        host.recover(_action(), p, a, _proof(p, a), _witness(p, a), false);
        // Seed only a new authentic-cause-shaped boundary; never clear the permanent transition marker.
        host.seed(ARTIST, NEW, bytes32(uint256(0xc1)), bytes32(uint256(0xa2)));
        p.newAddress = address(0x88);
        p.expectedCauseHash = bytes32(uint256(0xc1));
        _reject(
            abi.encodeCall(host.context, (p, a)),
            abi.encodeWithSelector(Recovery.UnsupportedIdentityRecoveryProfile.selector, ARTIST)
        );
    }

    function testTimingExpiryAndEpochOverflowRollback() public {
        Recovery.Request memory p = _request();
        T.Authorization memory a = _authorization();
        host.setTiming(1, 90 days);
        Contest.GovernanceWitness memory g = _witness(p, a);
        bytes32 before = _snapshot();
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, _proof(p, a), g, false)),
            abi.encodeWithSelector(Recovery.InvalidIdentityRecovery.selector, ARTIST)
        );
        require(before == _snapshot());
        host.setTiming(7 days, 90 days);
        a.time = 999_999;
        g = _witness(p, a);
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, _proof(p, a), g, false)),
            abi.encodeWithSelector(T.ExpiredAuthorization.selector, uint64(999_999))
        );
        require(before == _snapshot());
        a = _authorization();
        host.setEpoch(ARTIST, type(uint64).max);
        g = _witness(p, a);
        before = _snapshot();
        _reject(
            abi.encodeCall(host.recover, (_action(), p, a, _proof(p, a), g, false)),
            abi.encodeWithSignature("Panic(uint256)", uint256(0x11))
        );
        require(before == _snapshot());
        host.setEpoch(ARTIST, 0);
        g = _witness(p, a);
        host.recover(_action(), p, a, _proof(p, a), g, false);
    }
}
