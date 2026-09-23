// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryDormancyPredecessor as DP
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryDormancyPredecessor.sol";
import {
    StreamArtistRecoveryDormancyRotation as DR
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryDormancyRotation.sol";
import {
    StreamArtistRecoveryEstatePredecessor as EP
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryEstatePredecessor.sol";
import {
    StreamArtistRecoveryEstateRotation as ER
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryEstateRotation.sol";
import {
    StreamArtistRecoveryDormancyEvidence as DE
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryDormancyEvidence.sol";
import {
    StreamArtistRecoveryDormancyPlan as DPlan
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryDormancyPlan.sol";
import {
    StreamArtistRecoveryEstateEvidence as EE
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryEstateEvidence.sol";
import {
    StreamArtistRecoveryEstatePlan as EPlan
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryEstatePlan.sol";
import {
    StreamArtistRecoveryEstateClosure as EC
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryEstateClosure.sol";
import {
    StreamArtistIdentityRecoveryState as RS
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryState.sol";
import {
    StreamArtistRotationState as Rotations
} from "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistIdentityContestState as Contests
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityContestState.sol";
import {
    StreamArtistSuccessionState as Succession
} from "../../../smart-contracts/domains/artist/StreamArtistSuccessionState.sol";
import {
    StreamArtistEstateState as Estates
} from "../../../smart-contracts/domains/artist/StreamArtistEstateState.sol";
import {
    StreamArtistDormancyState as Dormancies
} from "../../../smart-contracts/domains/artist/StreamArtistDormancyState.sol";
import {
    StreamArtistHashes as H
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistEstateTypes.sol";

interface EstateDormancyVm {
    function expectRevert(bytes calldata) external;
    function warp(uint256) external;
}

/// @dev Declared original storage roots with typed test setters. This is a worker-transport
/// fixture, not an admitted Artist history or a governance/Safe recovery ceremony.
contract EstateDormancyWorkerHarness {
    bytes32 public beforeCanary = keccak256("before recovery roots");
    RS.State private recovery;
    Rotations.State private rotations;
    Resolution.State private resolutions;
    Contests.State private contests;
    Succession.State private succession;
    Estates.State private estate;
    Dormancies.State private dormancy;
    bytes32 public afterCanary = keccak256("after recovery roots");

    function save(V.Snapshot memory v, R.RotationRecord memory r) external {
        recovery.vestingHistory.snapshots[v.transitionRecordHash] = v;
        rotations.rotations[r.recordHash] = r;
    }

    function saveClosure(bytes32 key, D.Closure memory c) external {
        resolutions.closures[key] = c;
    }

    function previous(
        H.Environment memory e,
        Dorm.Notice memory n,
        V.Snapshot memory v,
        V.Snapshot memory seed,
        bool resolved
    ) external view returns (V.Snapshot memory result, bytes32 untouched) {
        result = DPlan._previous(recovery, rotations, e, n, v, seed, resolved);
        untouched = keccak256(abi.encode(e, n, v, seed));
    }

    function hashes(H.Environment memory e, V.Snapshot memory v, D.Cause memory c)
        external
        view
        returns (bytes32, bytes32, bytes32, bytes32, bytes32)
    {
        return (
            DE._vestingHash(e, v),
            EE._vestingHash(e, v),
            DE._causeHash(e, c),
            EE._causeHash(e, c),
            keccak256(abi.encode(e, v, c))
        );
    }

    function closure(H.Environment memory e, D.Cause memory c, R.TransitionState memory t)
        external
        view
        returns (bytes32)
    {
        return EC._closure(rotations, resolutions, contests, e, c, t);
    }

    function eligible(bytes32 id, R.ProvisionalAssociation memory p, bool ancestry)
        external
        view
        returns (bool, bool)
    {
        return
            (DPlan._eligible(rotations, id, p), EPlan._planAssociation(rotations, id, p, ancestry));
    }

    function directives(
        H.Environment memory e,
        Dorm.Notice memory n,
        V.Snapshot memory v,
        Estate.RequestRecord memory request,
        Succ.DirectiveRecord memory d,
        bool estatePath
    ) external view {
        if (estatePath) {
            EPlan._directive(rotations, e, request, d, bytes32(0), false);
        } else {
            DPlan._directive(rotations, e, n, v, d, bytes32(0));
        }
    }

    function historyWrapper(uint8 kind, bytes32 artist) external view {
        H.Environment memory e;
        D.Cause memory c;
        Recovery.Request memory p;
        p.artistId = artist;
        if (kind == 0) {
            DP.factsWithHistory(
                recovery,
                dormancy,
                estate,
                rotations,
                resolutions,
                succession,
                contests,
                e,
                c,
                p,
                bytes32(0)
            );
        } else if (kind == 1) {
            DR.factsWithHistory(
                recovery,
                dormancy,
                estate,
                rotations,
                resolutions,
                succession,
                contests,
                e,
                c,
                p,
                bytes32(0)
            );
        } else if (kind == 2) {
            EP.firstEstateWithHistory(
                recovery, estate, rotations, resolutions, succession, contests, e, c, p, bytes32(0)
            );
        } else {
            ER.afterRotationWithHistory(
                recovery, estate, rotations, resolutions, succession, contests, e, c, p, bytes32(0)
            );
        }
    }
}

contract StreamArtistRecoveryEstateDormancyWorkersTest {
    EstateDormancyVm private constant vm =
        EstateDormancyVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = keccak256("typed worker artist");
    EstateDormancyWorkerHarness private a;
    EstateDormancyWorkerHarness private b;

    function setUp() public {
        a = new EstateDormancyWorkerHarness();
        b = new EstateDormancyWorkerHarness();
        vm.warp(1000);
    }

    function _env() private view returns (H.Environment memory) {
        return H.Environment(block.chainid, address(0x1234), address(0x5678), address(0x9ABC));
    }

    function _error() private pure returns (bytes memory) {
        return abi.encodeWithSelector(Recovery.UnsupportedIdentityRecoveryProfile.selector, ARTIST);
    }

    function _vesting(address host, H.Environment memory e, V.Snapshot memory v)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"), e.chainId, e.registry, host
                ),
                abi.encode(
                    v.artistId,
                    v.transitionRecordHash,
                    v.operationId,
                    v.ownerRevision,
                    v.executedAt,
                    v.oldAddress,
                    v.newAddress,
                    v.authorityClass,
                    v.guardians,
                    v.previousTransitionRecordHash,
                    v.previousCommitment
                )
            )
        );
    }

    function _prior()
        private
        view
        returns (
            Dorm.Notice memory n,
            V.Snapshot memory current,
            V.Snapshot memory prior,
            R.RotationRecord memory r
        )
    {
        H.Environment memory e = _env();
        n.terms.artistId = ARTIST;
        n.incumbent = address(0x2222);
        n.initiatedAt = 900;
        r.terms = R.Rotation(ARTIST, address(0x1111), n.incumbent, keccak256("reason"), bytes32(0));
        r.oldNonce = 9;
        r.recordHash = keccak256(
            abi.encode(
                bytes32(0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5),
                e.chainId,
                e.registry,
                ARTIST,
                r.terms.oldAddress,
                r.terms.newAddress,
                r.terms.reasonHash,
                r.oldNonce,
                uint64(100),
                uint64(200)
            )
        );
        r.transition = R.TransitionState(ARTIST, r.recordHash, 100, 200, 300, 800, 0, 2);
        prior.artistId = ARTIST;
        prior.transitionRecordHash = r.recordHash;
        prior.operationId = 32;
        prior.ownerRevision = 5;
        prior.executedAt = 300;
        prior.oldAddress = r.terms.oldAddress;
        prior.newAddress = r.terms.newAddress;
        prior.authorityClass = 1;
        prior.guardians = GH.Head(2, 4, keccak256("guardian prefix"));
        prior.commitment = _vesting(address(a), e, prior);
        current.artistId = ARTIST;
        current.ownerRevision = 6;
        current.guardians = GH.Head(3, 5, keccak256("later prefix"));
        current.previousTransitionRecordHash = prior.transitionRecordHash;
        current.previousCommitment = prior.commitment;
    }

    function testPreviousSnapshotReturnsCompleteMemoryAndPreservesInputs() public {
        (
            Dorm.Notice memory n,
            V.Snapshot memory v,
            V.Snapshot memory p,
            R.RotationRecord memory r
        ) = _prior();
        a.save(p, r);
        V.Snapshot memory seed;
        seed.commitment = keccak256("unrelated caller memory");
        bytes32 inputs = keccak256(abi.encode(_env(), n, v, seed));
        (V.Snapshot memory result, bytes32 unchanged) = a.previous(_env(), n, v, seed, false);
        require(keccak256(abi.encode(result)) == keccak256(abi.encode(p)), "full prior return");
        require(
            unchanged == inputs && seed.commitment == keccak256("unrelated caller memory"),
            "inputs changed"
        );
        require(a.beforeCanary() == keccak256("before recovery roots"), "before root");
        require(a.afterCanary() == keccak256("after recovery roots"), "after root");
    }

    function testPreviousSnapshotRefusalAndExactRestoration() public {
        (
            Dorm.Notice memory n,
            V.Snapshot memory v,
            V.Snapshot memory p,
            R.RotationRecord memory r
        ) = _prior();
        V.Snapshot memory seed;
        a.save(p, r);
        r.transition.contestedAt = 700;
        a.save(p, r);
        vm.expectRevert(_error());
        a.previous(_env(), n, v, seed, false);
        // The authenticated boundary's original resolution flag bypasses only this timing leg.
        (V.Snapshot memory resolved,) = a.previous(_env(), n, v, seed, true);
        require(keccak256(abi.encode(resolved)) == keccak256(abi.encode(p)), "resolved prior");
        r.transition.contestedAt = 0;
        a.save(p, r);
        (V.Snapshot memory restored,) = a.previous(_env(), n, v, seed, false);
        require(keccak256(abi.encode(restored)) == keccak256(abi.encode(p)), "restored prior");
        p.commitment = keccak256("bad stored commitment");
        a.save(p, r);
        vm.expectRevert(_error());
        a.previous(_env(), n, v, seed, true);
    }

    function testAbsentPreviousPreservesExistingMemoryButRejectsStrayCommitment() public {
        Dorm.Notice memory n;
        V.Snapshot memory v;
        V.Snapshot memory seed;
        v.artistId = ARTIST;
        seed.artistId = ARTIST;
        seed.guardians = GH.Head(7, 11, keccak256("memory canary"));
        seed.commitment = keccak256("seed");
        (V.Snapshot memory result,) = a.previous(_env(), n, v, seed, false);
        require(
            keccak256(abi.encode(result)) == keccak256(abi.encode(seed)), "zero branch erased seed"
        );
        v.previousCommitment = bytes32(uint256(1));
        vm.expectRevert(_error());
        a.previous(_env(), n, v, seed, false);
    }

    function testFuzzOriginalHashDomainsKeepDelegateHost(uint64 revision, bytes32 record)
        public
        view
    {
        H.Environment memory e = _env();
        V.Snapshot memory v;
        v.artistId = ARTIST;
        v.transitionRecordHash = record;
        v.ownerRevision = revision;
        v.operationId = 32;
        v.guardians = GH.Head(3, revision, keccak256("prefix"));
        D.Cause memory c;
        c.facts.artistId = ARTIST;
        c.facts.kind = 1;
        c.facts.referenceHash = record;
        (bytes32 dv, bytes32 ev, bytes32 dc, bytes32 ec, bytes32 untouched) = a.hashes(e, v, c);
        require(dv == _vesting(address(a), e, v) && ev == dv, "vesting preimage");
        bytes32 literalCause = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                e.chainId,
                e.registry,
                address(a),
                c.facts
            )
        );
        require(dc == literalCause && ec == dc, "cause preimage");
        require(untouched == keccak256(abi.encode(e, v, c)), "hash mutated inputs");
        (bytes32 other,,,,) = b.hashes(e, v, c);
        require(other == _vesting(address(b), e, v) && other != dv, "worker used own domain");
    }

    function testClosureCanonicalAbsenceKeepsTimingAndStorageChecks() public {
        D.Cause memory c;
        c.facts.artistId = ARTIST;
        c.facts.enteredAt = 900;
        R.TransitionState memory t =
            R.TransitionState(ARTIST, keccak256("transition"), 100, 200, 300, 800, 0, 2);
        require(a.closure(_env(), c, t) == 0, "canonical absence");
        t.contestedAt = 799;
        vm.expectRevert(_error());
        a.closure(_env(), c, t);
        t.contestedAt = 800;
        require(a.closure(_env(), c, t) == 0, "late contest");
        D.Closure memory malformed;
        malformed.artistId = keccak256("foreign artist");
        a.saveClosure(t.recordHash, malformed);
        vm.expectRevert(_error());
        a.closure(_env(), c, t);
        D.Closure memory empty;
        a.saveClosure(t.recordHash, empty);
        require(a.closure(_env(), c, t) == 0, "restore closure");
    }

    function testPlanAssociationKeepsAncestryAndContestationDistinctions() public {
        (,, V.Snapshot memory p, R.RotationRecord memory r) = _prior();
        a.save(p, r);
        R.ProvisionalAssociation memory association = R.ProvisionalAssociation(r.recordHash, 800);
        (bool dormancyOK, bool estateOK) = a.eligible(ARTIST, association, true);
        require(dormancyOK && estateOK, "eligible chain");
        (dormancyOK, estateOK) = a.eligible(ARTIST, association, false);
        require(dormancyOK && !estateOK, "ancestry must stay explicit");
        r.transition.contestedAt = 799;
        a.save(p, r);
        (dormancyOK, estateOK) = a.eligible(ARTIST, association, true);
        require(!dormancyOK && !estateOK, "early contest");
        r.transition.contestedAt = 800;
        a.save(p, r);
        (dormancyOK, estateOK) = a.eligible(ARTIST, association, true);
        require(dormancyOK && estateOK, "same association restoration");
    }

    function testEmptyDirectiveIsWholeTupleCanonicalOnBothPaths() public {
        Dorm.Notice memory n;
        V.Snapshot memory v;
        v.artistId = ARTIST;
        Estate.RequestRecord memory r;
        r.terms.artistId = ARTIST;
        Succ.DirectiveRecord memory d;
        a.directives(_env(), n, v, r, d, false);
        a.directives(_env(), n, v, r, d, true);
        d.nonce = 1;
        vm.expectRevert(_error());
        a.directives(_env(), n, v, r, d, false);
        vm.expectRevert(_error());
        a.directives(_env(), n, v, r, d, true);
        d.nonce = 0;
        a.directives(_env(), n, v, r, d, false);
        a.directives(_env(), n, v, r, d, true);
    }

    function testAllFourOriginalHistoryEntriesRefuseZeroProof() public {
        for (uint8 kind; kind < 4; ++kind) {
            vm.expectRevert(_error());
            a.historyWrapper(kind, ARTIST);
        }
    }
}
