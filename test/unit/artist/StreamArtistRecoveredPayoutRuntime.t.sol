// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredRuntimeReadsTest,
    RecoveredRuntimeBoundary
} from "./StreamArtistRecoveredRuntimeReads.t.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredHydrationGuards as Keys
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveryRewindPayoutReads as PayoutReads
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindPayoutReads.sol";
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindRecordReads.sol";
import {
    StreamArtistPayoutRecovery as Recovery
} from "../../../smart-contracts/domains/artist/StreamArtistPayoutRecovery.sol";
import {
    StreamArtistPayoutRecoveryState as State
} from "../../../smart-contracts/domains/artist/StreamArtistPayoutRecoveryState.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

interface RecoveredPayoutRuntimeVm {
    function etch(address target, bytes calldata code) external;
    function warp(uint256 time) external;
}

contract RecoveredPayoutRuntimeHarness {
    State.State private state;
    mapping(bytes32 => T.ReplayCell) private cells;

    function payoutAt(
        W.EnvironmentV3 memory e,
        bytes32 artist,
        bytes32 hash,
        Runtime.ReceiptFact memory receipt
    ) external view returns (Records.Facts memory) {
        return PayoutReads.payoutAt(e, artist, hash, receipt);
    }

    /// @dev Explicit fixture state; source admission is tested in the separate transport host.
    function seed(
        RH.OwnerProvenance memory prefix,
        bytes32 commitment,
        W.PayoutContinuationV3 memory c
    ) external {
        Imported.installOwnerPrefix(prefix, 5, commitment, 1);
        state.continuations[c.continuationHash] = c;
        state.continuationHeads[c.artistId] = c.continuationHash;
        state.appliedRecoveries[c.recoveryRecordHash] = bytes32(uint256(901));
    }

    function admission(
        W.EnvironmentV3 memory e,
        uint64 revision,
        T.PayoutDesignation calldata p,
        bytes32 record
    ) external returns (bytes32) {
        return Recovery.noteAdmission(state, cells, e, revision, p, record);
    }

    function cell(bytes32 key) external view returns (T.ReplayCell memory) {
        return cells[key];
    }

    function mappingAt(bytes32 record) external view returns (bytes32) {
        return state.recordContinuations[record];
    }
}

/// @notice Source-authored Payout consumer regressions over the same explicit mock boundary.
/// @dev Inherits the12 reader controls; adds five Payout cases. The actual current signature and
/// threshold-Safe op18/35 admission remain owned by the end-to-end integration host.
contract StreamArtistRecoveredPayoutRuntimeTest is StreamArtistRecoveredRuntimeReadsTest {
    RecoveredPayoutRuntimeVm private constant payoutVm =
        RecoveredPayoutRuntimeVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testRecoveredPayoutOriginal18UsesOldPublisherAndCurrentRetainedOwner() public {
        (
            RecoveredPayoutRuntimeHarness target,
            W.PayoutOriginalV3 memory r,
            Runtime.ReceiptFact memory row
        ) = _original();
        Records.Facts memory f = target.payoutAt(e, ARTIST, r.recordHash, row);
        require(
            f.account == r.terms.payoutAccount && f.eligible && f.admissionRevision == 90,
            "retained original admitted under original clock"
        );
        require(
            f.selected.originalDataHash
                == keccak256(
                    abi.encode(
                        r.terms,
                        r,
                        W.payoutOriginalHash(Runtime.rewindEnvironment(row.environment), r)
                    )
                ),
            "original publisher evidence bytes"
        );
        require(row.environment.registry != e.registry, "current authority remains separate");
    }

    function testRecoveredPayoutWrongOriginalPublisherPinRejects() public {
        (
            RecoveredPayoutRuntimeHarness target,
            W.PayoutOriginalV3 memory r,
            Runtime.ReceiptFact memory row
        ) = _original();
        address bad = address(new RecoveredRuntimeBoundary());
        vm.mockCall(
            row.environment.owners[2],
            abi.encodeWithSignature("recoveryRewindEvidenceBinding()"),
            abi.encode(bad, bytes32(uint256(9)))
        );
        _rejectPayout(
            target, r, row, abi.encodeWithSelector(W.RecoveryRewindDependencyChanged.selector, bad)
        );
    }

    function testRecoveredPayoutOriginalOccurrenceCannotBeRelabeledCurrent() public {
        (
            RecoveredPayoutRuntimeHarness target,
            W.PayoutOriginalV3 memory r,
            Runtime.ReceiptFact memory row
        ) = _original();
        row.environment = Runtime.load(e, 5).current;
        row.position.point.environmentHash = RH.originHash(row.environment);
        _rejectPayout(
            target,
            r,
            row,
            abi.encodeWithSelector(W.InvalidRecoveryRewindRecord.selector, r.recordHash)
        );
    }

    function testRecoveredPayoutContinuationConsumesFreshCurrentKeyAtRealLowRevision() public {
        (
            RecoveredPayoutRuntimeHarness target,
            W.PayoutContinuationV3 memory c,
            RH.OwnerProvenance memory old
        ) = _continuation();
        T.PayoutDesignation memory p =
            T.PayoutDesignation(ARTIST, address(991), c.stable.recordHash);
        bytes32 record = bytes32(uint256(992));
        require(target.admission(e, 8, p, record) != 0, "old revision90 admitted at real local9");
        Runtime.Context memory current = Runtime.load(e, 5);
        AH.Origin memory scope = AH.Origin(
            keccak256("payout_lifecycle.replay.recovery_continuation"),
            keccak256(abi.encode(ARTIST, c.continuationHash, c.stable.recordHash))
        );
        bytes32 key = Keys.replayKey(current.current, 5, scope);
        bytes32 oldKey = Keys.replayKey(old.origins[0], 5, scope);
        T.ReplayCell memory cell = target.cell(key);
        require(
            cell.commitment == record && cell.touchedRevision == 9 && cell.kind == 1
                && cell.status == 2,
            "fresh destination consumption"
        );
        require(
            target.cell(oldKey).status == 0 && target.mappingAt(record) == c.continuationHash,
            "original domain untouched"
        );
        require(
            target.admission(e, 8, p, bytes32(uint256(993))) == 0, "current scope remains one-use"
        );
    }

    function testRecoveredPayoutContinuationWrongOriginFailsBeforeCurrentConsumption() public {
        (RecoveredPayoutRuntimeHarness target, W.PayoutContinuationV3 memory c,) = _continuation();
        Runtime.Context memory current = Runtime.load(e, 5);
        _aux(RH.Point(RH.originHash(current.current), 5, 8));
        // An actual but unrelated current APPLY cannot relabel the old canonical continuation.
        bytes32 applyKey =
            Keys.replayKey(current.current, 5, AH.Origin(SURFACE, c.recoveryRecordHash));
        _replay(
            applyKey,
            T.ReplayCell(c.planCommitment, 8, 1, 2),
            RH.Point(RH.originHash(current.current), 5, 8)
        );
        vm.mockCall(
            e.payoutOwner,
            abi.encodeWithSignature(
                "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)", AUX, c.continuationHash
            ),
            abi.encode(RH.Point(RH.originHash(current.current), 5, 8))
        );
        T.PayoutDesignation memory p =
            T.PayoutDesignation(ARTIST, address(991), c.stable.recordHash);
        bytes32 record = bytes32(uint256(994));
        (bool ok, bytes memory error) =
            address(target).call(abi.encodeCall(target.admission, (e, uint64(8), p, record)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(W.InvalidRecoveryRewindRecord.selector, record)
                    ),
            "exact origin rejection"
        );
        bytes32 key = Keys.replayKey(
            current.current,
            5,
            AH.Origin(
                keccak256("payout_lifecycle.replay.recovery_continuation"),
                keccak256(abi.encode(ARTIST, c.continuationHash, c.stable.recordHash))
            )
        );
        require(
            target.cell(key).status == 0 && target.mappingAt(record) == 0,
            "failed proof leaves current scope empty"
        );
    }

    function _original()
        private
        returns (
            RecoveredPayoutRuntimeHarness target,
            W.PayoutOriginalV3 memory r,
            Runtime.ReceiptFact memory row
        )
    {
        payoutVm.warp(100);
        target = new RecoveredPayoutRuntimeHarness();
        RH.OwnerProvenance memory payout = _fixture(5);
        RH.OwnerProvenance memory identity = _fixture(2);
        W.EnvironmentV3 memory original = Runtime.rewindEnvironment(payout.origins[0]);
        r.terms = T.PayoutDesignation(ARTIST, address(888), 0);
        r.signer = address(889);
        r.authorityClass = 1;
        r.nonce = 7;
        r.signedAt = 1;
        Hashes.Environment memory domain = Hashes.Environment(
            original.chainId, original.registry, original.core, original.manager
        );
        r.recordHash = Hashes.payoutRecordForAuthority(domain, r.terms, r.signer, 1, 7, 1);
        payout.journal[0].receipt.recordHash = r.recordHash;
        _prefix(5, payout, IMPORT, 1);
        bytes32 nonceSurface = keccak256("identity_authority.replay.nonce_allocator");
        bytes32 nonceScope = keccak256(abi.encode(ARTIST, r.nonce));
        identity.aliases[0] = RH.ReplayAlias(
            identity.eras[0].originHash,
            2,
            nonceSurface,
            nonceScope,
            Keys.replayKey(identity.origins[0], 2, AH.Origin(nonceSurface, nonceScope)),
            T.ReplayCell(
                Hashes.payoutDigest(domain, r.terms, T.Authorization(7, 1, new bytes(0))), 90, 1, 2
            ),
            RH.Point(identity.eras[0].originHash, 2, 90)
        );
        _prefix(2, identity, IMPORT, 1);
        address publisher = address(new RecoveredRuntimeBoundary());
        payoutVm.etch(original.identityOwner, hex"00");
        vm.mockCall(
            original.identityOwner,
            abi.encodeWithSignature("recoveryRewindEvidenceBinding()"),
            abi.encode(publisher, publisher.codehash)
        );
        vm.mockCall(
            publisher, abi.encodeWithSignature("owner()"), abi.encode(original.identityOwner)
        );
        vm.mockCall(
            publisher, abi.encodeWithSignature("payoutOwner()"), abi.encode(original.payoutOwner)
        );
        vm.mockCall(
            publisher, abi.encodeWithSignature("artistRegistry()"), abi.encode(original.registry)
        );
        vm.mockCall(
            publisher, abi.encodeWithSignature("deploymentChainId()"), abi.encode(original.chainId)
        );
        vm.mockCall(
            publisher, abi.encodeWithSignature("coordinator()"), abi.encode(original.coordinator)
        );
        vm.mockCall(publisher, abi.encodeWithSignature("archive()"), abi.encode(original.archive));
        vm.mockCall(publisher, abi.encodeWithSignature("core()"), abi.encode(original.core));
        vm.mockCall(
            publisher, abi.encodeWithSignature("mintManager()"), abi.encode(original.manager)
        );
        vm.mockCall(
            publisher,
            abi.encodeWithSignature("payoutOriginalV3(bytes32)", r.recordHash),
            abi.encode(
                r,
                W.payoutOriginalHash(original, r),
                original.identityCodeHash,
                original.payoutCodeHash
            )
        );
        vm.mockCall(
            e.payoutOwner,
            abi.encodeWithSignature("designationRecord(bytes32)", r.recordHash),
            abi.encode(r.terms)
        );
        R.ProvisionalAssociation memory empty;
        vm.mockCall(
            e.payoutOwner,
            abi.encodeWithSignature(
                "payoutDesignationProvisionalAssociation(bytes32)", r.recordHash
            ),
            abi.encode(empty)
        );
        vm.mockCall(
            e.payoutOwner,
            abi.encodeWithSignature("payoutAbandonment(bytes32)", r.recordHash),
            abi.encode(bytes32(0))
        );
        vm.mockCall(
            e.payoutOwner,
            abi.encodeWithSignature(
                "payoutDesignationRecoveryContinuationV3(bytes32)", r.recordHash
            ),
            abi.encode(bytes32(0))
        );
        row = Runtime.receiptAt(Runtime.load(e, 5), 0);
    }

    function _continuation()
        private
        returns (
            RecoveredPayoutRuntimeHarness target,
            W.PayoutContinuationV3 memory c,
            RH.OwnerProvenance memory old
        )
    {
        target = new RecoveredPayoutRuntimeHarness();
        suite.owners[5] = address(target);
        e.payoutOwner = address(target);
        e.payoutCodeHash = address(target).codehash;
        vm.mockCall(
            e.coordinator, abi.encodeWithSignature("suiteConfiguration()"), abi.encode(suite)
        );
        old = _fixture(5);
        c.artistId = ARTIST;
        c.recoveryRecordHash = SCOPE;
        c.actionId = bytes32(uint256(881));
        c.manifestHash = bytes32(uint256(882));
        c.planCommitment = old.aliases[0].cell.commitment;
        c.identityOwnerRevision = 70;
        c.payoutOwnerRevision = 90;
        c.stable = T.Payout(address(883), bytes32(uint256(884)));
        c.continuationHash = W.payoutContinuationHash(Runtime.rewindEnvironment(old.origins[0]), c);
        target.seed(old, IMPORT, c);
        vm.mockCall(
            e.payoutOwner,
            abi.encodeWithSignature(
                "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)", AUX, c.continuationHash
            ),
            abi.encode(RH.Point(old.eras[0].originHash, 5, 90))
        );
    }

    function _rejectPayout(
        RecoveredPayoutRuntimeHarness target,
        W.PayoutOriginalV3 memory r,
        Runtime.ReceiptFact memory row,
        bytes memory expected
    ) private {
        (bool ok, bytes memory error) = address(target)
            .call(abi.encodeCall(target.payoutAt, (e, ARTIST, r.recordHash, row)));
        require(!ok && keccak256(error) == keccak256(expected), "exact payout original rejection");
    }
}
