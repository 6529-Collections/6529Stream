// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
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
    StreamArtistHistoryTypes as Hist
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistPayoutRecoveryState as S
} from "../../../smart-contracts/domains/artist/StreamArtistPayoutRecoveryState.sol";
import {
    StreamArtistRecoveredPayoutHydration as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayoutHydration.sol";
import {
    StreamArtistRecoveredPayoutImport as Import
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayoutImport.sol";
import {
    StreamArtistHashes as H
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";

interface RecoveredPayoutVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
}

contract RecoveredPayoutBoundaryStub { }

/// @dev Explicitly synthetic storage boundary. No original admission or Safe integration is claimed.
contract RecoveredPayoutCodecHarness {
    mapping(bytes32 => T.Payout) private stable;
    mapping(bytes32 => T.PayoutDesignation) private records;
    mapping(bytes32 => T.Payout) private pending;
    mapping(bytes32 => R.ProvisionalAssociation) private associations;
    mapping(bytes32 => bytes32) private abandoned;
    S.State private recovery;

    function validate(P.Bundle memory b, RH.Provenance memory p) external pure returns (bytes32) {
        return Codec.validate(b, p);
    }

    function validateLocal(P.Bundle memory b, RH.OwnerProvenance memory p)
        external
        pure
        returns (bytes32)
    {
        return Codec.validateLocal(b, p);
    }

    function decodeLocal(bytes memory raw, RH.OwnerProvenance memory p)
        external
        pure
        returns (P.Bundle memory)
    {
        return Codec.decodeLocal(raw, p);
    }

    function collectLocal(address source, bytes32 artistId, RH.OwnerProvenance memory p)
        external
        view
        returns (P.Bundle memory)
    {
        return Codec.collectLocal(source, artistId, p);
    }

    function collect(address source, bytes32 artistId, RH.Provenance memory p)
        external
        view
        returns (P.Bundle memory)
    {
        return Codec.collect(source, artistId, p);
    }

    function decode(bytes memory raw, RH.Provenance memory p)
        external
        pure
        returns (P.Bundle memory)
    {
        return Codec.decode(raw, p);
    }

    function install(bytes32 artistId, bytes memory raw, RH.Provenance memory p)
        external
        returns (bytes32)
    {
        return Import.importState(
            stable,
            records,
            pending,
            associations,
            abandoned,
            recovery,
            artistId,
            raw,
            RH.ownerProvenance(p, 5)
        );
    }

    function digest(P.Bundle memory b) external view returns (bytes32 result) {
        result = keccak256(
            abi.encode(
                stable[b.artistId],
                pending[b.artistId],
                recovery.statusCommitments[b.artistId],
                recovery.continuationHeads[b.artistId]
            )
        );
        for (uint256 i; i < b.records.length; ++i) {
            bytes32 h = b.records[i].original.recordHash;
            result = keccak256(
                abi.encode(
                    result,
                    records[h],
                    associations[h],
                    abandoned[h],
                    recovery.statuses[h],
                    recovery.recordContinuations[h]
                )
            );
        }
        for (uint256 i; i < b.continuations.length; ++i) {
            W.PayoutContinuationV3 memory c = b.continuations[i].continuation;
            result = keccak256(
                abi.encode(
                    result,
                    recovery.continuations[c.continuationHash],
                    recovery.appliedRecoveries[c.recoveryRecordHash]
                )
            );
        }
    }

    function seed(uint8 kind, P.Bundle memory b) external {
        bytes32 r = b.records[0].original.recordHash;
        bytes32 c = b.continuations[0].continuation.continuationHash;
        if (kind == 0) {
            stable[b.artistId].account = address(1);
        } else if (kind == 1) {
            pending[b.artistId].account = address(1);
        } else if (kind == 2) {
            recovery.statusCommitments[b.artistId] = bytes32(uint256(1));
        } else if (kind == 3) {
            recovery.continuationHeads[b.artistId] = bytes32(uint256(1));
        } else if (kind == 4) {
            records[r].payoutAccount = address(1);
        } else if (kind == 5) {
            associations[r].windowEndsAt = 1;
        } else if (kind == 6) {
            abandoned[r] = bytes32(uint256(1));
        } else if (kind == 7) {
            recovery.statuses[r].actionId = bytes32(uint256(1));
        } else if (kind == 8) {
            recovery.recordContinuations[r] = bytes32(uint256(1));
        } else if (kind == 9) {
            recovery.continuations[c].actionId = bytes32(uint256(1));
        } else {
            recovery.appliedRecoveries[b.continuations[0].continuation.recoveryRecordHash] =
                bytes32(uint256(1));
        }
    }
}

/// @notice Codec grammar, complete-prefix controls and exact storage copy only.
/// @dev These two-era fixtures and mocked source reads deliberately do not claim genuine Artist,
/// source-checkpoint, governed cutover, nonce-index or threshold-Safe admission. Actual hosts must
/// independently cover the common authenticated operation60 and subsequent authorized writes.
contract StreamArtistRecoveredPayoutHydrationTest {
    RecoveredPayoutVm private constant vm =
        RecoveredPayoutVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ID = bytes32(uint256(11));
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant APPLY = keccak256("payout_lifecycle.replay.recovery_rewind");
    bytes32 private constant ADMISSION = keccak256("payout_lifecycle.replay.recovery_continuation");
    RecoveredPayoutCodecHarness private harness;
    address[2] private identities;
    address[2] private payouts;
    address[2] private publishers;

    function setUp() public {
        harness = new RecoveredPayoutCodecHarness();
        for (uint256 i; i < 2; ++i) {
            identities[i] = address(new RecoveredPayoutBoundaryStub());
            payouts[i] = address(new RecoveredPayoutBoundaryStub());
            publishers[i] = address(new RecoveredPayoutBoundaryStub());
        }
    }

    function testRecoveredPayoutRoundtripPreservesTwoClocksAndEveryStoredValue() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        require(
            b.continuations[0].continuation.payoutOwnerRevision
                > b.records[2].position.point.ownerRevision,
            "distinct payout clocks"
        );
        require(
            b.continuations[0].continuation.identityOwnerRevision > 2, "distinct identity clocks"
        );
        bytes memory raw = Codec.encode(b, p);
        P.Bundle memory roundtrip = harness.decode(raw, p);
        require(
            keccak256(abi.encode(roundtrip)) == keccak256(abi.encode(b)), "exact typed roundtrip"
        );
        bytes32 installed = harness.install(ID, raw, p);
        require(installed == keccak256(abi.encode(P.SCHEMA, b)), "exact installation commitment");
        require(harness.digest(b) == _digest(b), "all records pointers statuses maps and applies");
        _rejectInstall(harness, b, p, ID);
    }

    function testRecoveredPayoutMissingRecordCannotHideBehindCompleteJournal() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        P.RecordRow[] memory reduced = new P.RecordRow[](2);
        reduced[0] = b.records[0];
        reduced[1] = b.records[2];
        bytes32 missing = b.records[1].original.recordHash;
        b.records = reduced;
        _reject(
            b,
            p,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector, b.records[1].original.recordHash
            )
        );
        require(missing != b.records[1].original.recordHash, "distinct missing original");
    }

    function testRecoveredPayoutOccupiedCandidateIsCopiedWithoutNormalization() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        b.inventory.stable =
            T.Payout(b.records[0].original.terms.payoutAccount, b.records[0].original.recordHash);
        b.inventory.candidate =
            T.Payout(b.records[2].original.terms.payoutAccount, b.records[2].original.recordHash);
        b.records[2].association = R.ProvisionalAssociation(bytes32(uint256(1900)), 2000);
        harness.install(ID, Codec.encode(b, p), p);
        require(harness.digest(b) == _digest(b), "raw occupied candidate and original window");
    }

    function testRecoveredPayoutOmittedJournalRowRejectsOriginalCounts() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        RH.JournalEntry[] memory reduced = new RH.JournalEntry[](2);
        reduced[0] = p.journals[5][0];
        reduced[1] = p.journals[5][2];
        p.journals[5] = reduced;
        _reject(b, p, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector));
    }

    function testRecoveredPayoutWrongOriginalPositionCannotRelabelRevision() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        b.records[1].position.point.environmentHash = p.eras[1].originHash;
        _reject(
            b,
            p,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector, b.records[1].original.recordHash
            )
        );
    }

    function testRecoveredPayoutProjectedAliasCannotBecomeNewAdmission() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        bytes32 scope = keccak256(abi.encode(ID, b.records[2].original.nonce));
        for (uint256 i; i < p.aliases[2].length; ++i) {
            if (p.aliases[2][i].scope == scope) {
                p.aliases[2][i].admittedAt.environmentHash = p.eras[0].originHash;
            }
        }
        _reject(b, p, abi.encodeWithSelector(P.InvalidRecoveredPayout.selector, scope));
    }

    function testRecoveredPayoutStatusPlanAndStatusChainAreExact() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        b.records[1].status.planCommitment = bytes32(uint256(999));
        _reject(
            b,
            p,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector, b.records[1].original.recordHash
            )
        );
        (b, p) = _fixture();
        b.inventory.supersessionStateCommitment = bytes32(uint256(999));
        _reject(b, p, abi.encodeWithSelector(P.InvalidRecoveredPayout.selector, ID));
    }

    function testRecoveredPayoutMissingApplyAndPartialEmptyStatusReject() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        b.continuations[0].appliedCommitment = 0;
        _reject(
            b,
            p,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector, b.continuations[0].continuation.continuationHash
            )
        );
        (b, p) = _fixture();
        b.records[0].status.actionId = bytes32(uint256(999));
        _reject(
            b,
            p,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector, b.records[0].original.recordHash
            )
        );
    }

    function testRecoveredPayoutUnknownContinuationAdmissionRejects() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        b.records[2].continuationHash = bytes32(uint256(999));
        _reject(
            b,
            p,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector, b.records[2].original.recordHash
            )
        );
    }

    function testRecoveredPayoutDuplicateOrCyclicOriginalCannotReplacePredecessor() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        b.records[1] = b.records[0];
        _reject(
            b,
            p,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector, b.records[0].original.recordHash
            )
        );
        (b, p) = _fixture();
        b.records[2].original.terms.previousDesignationRecordHash = b.records[2].original.recordHash;
        _reject(
            b,
            p,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector, b.records[2].original.recordHash
            )
        );
    }

    function testRecoveredPayoutCanonicalCodecRejectsTrailingBytes() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        bytes memory raw = bytes.concat(Codec.encode(b, p), hex"00");
        (bool ok, bytes memory error) =
            address(harness).call(abi.encodeCall(harness.decode, (raw, p)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(P.InvalidRecoveredPayout.selector, bytes32(0))
                    ),
            "canonical bytes"
        );
    }

    function testRecoveredPayoutEveryPartialDestinationSlotRejectsAtomically() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        for (uint8 i; i < 11; ++i) {
            RecoveredPayoutCodecHarness target = new RecoveredPayoutCodecHarness();
            target.seed(i, b);
            bytes32 before_ = target.digest(b);
            bytes32 expected = i < 4
                ? ID
                : (i < 9
                        ? b.records[0].original.recordHash
                        : b.continuations[0].continuation.continuationHash);
            _rejectInstall(target, b, p, expected);
            require(target.digest(b) == before_, "failed import untouched");
        }
    }

    function testRecoveredPayoutCollectorReadsImmediateStateAndUltimateOriginals() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        _mockSource(b, p);
        P.Bundle memory got = harness.collect(payouts[1], ID, p);
        require(
            keccak256(abi.encode(got)) == keccak256(abi.encode(b)), "exact full source collection"
        );
    }

    function testRecoveredPayoutCollectorRejectsStoredOriginalSubstitution() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        _mockSource(b, p);
        T.PayoutDesignation memory changed = b.records[0].original.terms;
        changed.payoutAccount = address(99);
        vm.mockCall(
            payouts[1],
            abi.encodeWithSignature("designationRecord(bytes32)", b.records[0].original.recordHash),
            abi.encode(changed)
        );
        _rejectCollect(payouts[1], p, b.records[0].original.recordHash);
    }

    function testRecoveredPayoutCollectorRejectsMissingApplyReadAndWrongSourceOwner() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        _mockSource(b, p);
        vm.mockCall(
            payouts[1],
            abi.encodeWithSignature(
                "payoutRecoveryAppliedCommitmentV3(bytes32)",
                b.continuations[0].continuation.recoveryRecordHash
            ),
            abi.encode(bytes32(0))
        );
        _rejectCollect(payouts[1], p, b.continuations[0].continuation.continuationHash);
        _rejectCollect(payouts[0], p, ID);
    }

    function testRecoveredPayoutLocalCodecMatchesJoinedBytesWithoutInventedPeerCheckpoints()
        public
    {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        RH.OwnerProvenance memory own = RH.ownerProvenance(p, 5);
        bytes memory raw = Codec.encode(b, p);
        require(harness.validateLocal(b, own) == harness.validate(b, p), "same semantic commitment");
        require(
            keccak256(abi.encode(harness.decodeLocal(raw, own))) == keccak256(abi.encode(b)),
            "same exact bytes"
        );
        require(
            own.eras[0].checkpoint.ownerState.domainId == RH.ownerDomain(5), "only real owner clock"
        );
        require(own.aliases.length == 2 && p.aliases[2].length == 3, "no copied peer aliases");
    }

    function testRecoveredPayoutLocalSuccessIsNotOriginalIdentityNonceProof() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        bytes32 scope = keccak256(abi.encode(ID, b.records[0].original.nonce));
        for (uint256 i; i < p.aliases[2].length; ++i) {
            if (p.aliases[2][i].scope == scope) {
                p.aliases[2][i].cell.commitment = bytes32(uint256(919));
            }
        }
        require(
            harness.validateLocal(b, RH.ownerProvenance(p, 5)) != 0,
            "local boundary intentionally excludes Identity nonce"
        );
        _reject(
            b,
            p,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector, b.records[0].original.recordHash
            )
        );
        _mockSource(b, p);
        require(
            keccak256(abi.encode(harness.collectLocal(payouts[1], ID, RH.ownerProvenance(p, 5))))
                == keccak256(abi.encode(b)),
            "local export inventory only"
        );
        _rejectCollect(payouts[1], p, b.records[0].original.recordHash);
    }

    function testRecoveredPayoutLocalSuccessCannotReplaceCreatingIdentity35() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        p.journals[2][0].receipt.recordHash = bytes32(uint256(1919));
        require(
            harness.validateLocal(b, RH.ownerProvenance(p, 5)) != 0,
            "local boundary intentionally excludes creating35"
        );
        _reject(
            b,
            p,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector,
                b.continuations[0].continuation.recoveryRecordHash
            )
        );
    }

    function testRecoveredPayoutLocalRejectsOmittedOwnPrefixAndApplyAlias() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        RH.OwnerProvenance memory own = RH.ownerProvenance(p, 5);
        own.journal = new RH.JournalEntry[](0);
        _rejectLocal(
            b, own, abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
        own = RH.ownerProvenance(p, 5);
        for (uint256 i; i < own.aliases.length; ++i) {
            if (own.aliases[i].surface == APPLY) {
                own.aliases[i].cell.commitment = bytes32(uint256(929));
            }
        }
        _rejectLocal(
            b,
            own,
            abi.encodeWithSelector(
                P.InvalidRecoveredPayout.selector, b.continuations[0].continuation.continuationHash
            )
        );
    }

    function testRecoveredPayoutLocalCodecRejectsNoncanonicalEnvelope() public {
        (P.Bundle memory b, RH.Provenance memory p) = _fixture();
        bytes memory raw = bytes.concat(Codec.encode(b, p), hex"00");
        (bool ok, bytes memory error) = address(harness)
            .call(abi.encodeCall(harness.decodeLocal, (raw, RH.ownerProvenance(p, 5))));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(P.InvalidRecoveredPayout.selector, bytes32(0))
                    ),
            "local canonical bytes"
        );
    }

    function _rejectLocal(P.Bundle memory b, RH.OwnerProvenance memory own, bytes memory expected)
        private
    {
        (bool ok, bytes memory error) =
            address(harness).call(abi.encodeCall(harness.validateLocal, (b, own)));
        require(!ok && keccak256(error) == keccak256(expected), "exact local rejection");
    }

    function _fixture() private view returns (P.Bundle memory b, RH.Provenance memory p) {
        p.origins = new RH.OriginEnvironment[](2);
        p.eras = new RH.Era[](2);
        for (uint256 era; era < 2; ++era) {
            RH.OriginEnvironment memory o;
            o.chainId = block.chainid;
            o.registry = address(uint160(100 + era));
            o.coordinator = address(uint160(200 + era));
            o.archive = address(uint160(300 + era));
            o.core = address(400);
            o.manager = address(401);
            o.suiteConfigurationHash = bytes32(uint256(402 + era));
            for (uint8 j; j < 7; ++j) {
                o.owners[j] = address(uint160(500 + era * 10 + j));
                o.ownerCodeHashes[j] = bytes32(uint256(uint256(600) + j));
            }
            o.owners[2] = identities[era];
            o.ownerCodeHashes[2] = identities[era].codehash;
            o.owners[5] = payouts[era];
            o.ownerCodeHashes[5] = payouts[era].codehash;
            p.origins[era] = o;
            p.eras[era].originHash = RH.originHash(o);
            if (era != 0) p.eras[era].priorImportCommitment = bytes32(uint256(700));
            for (uint8 j; j < 7; ++j) {
                uint64 revision = era == 0 ? 0 : 1;
                if (j == 2) revision = era == 0 ? 6 : 2;
                if (j == 5) revision = era == 0 ? 3 : 2;
                p.eras[era].checkpoints[j] = CP.Checkpoint(
                    RH.CHECKPOINT,
                    T.Snapshot(
                        RH.ownerDomain(j),
                        revision,
                        bytes32(uint256(uint256(800) + j)),
                        bytes32(uint256(uint256(900) + j))
                    ),
                    0,
                    0,
                    0,
                    0
                );
                p.eras[era].lowerRevisions[j] = era == 0 ? 0 : 1;
            }
        }
        b.artistId = ID;
        b.sourceSnapshot = p.eras[1].checkpoints[5].ownerState;
        b.records = new P.RecordRow[](3);
        b.records[0] = _record(p, 0, 0, 1, address(1001), 0, 0, 1);
        b.records[1] = _record(p, 0, 1, 2, address(1002), b.records[0].original.recordHash, 1, 2);
        b.records[1].association = R.ProvisionalAssociation(bytes32(uint256(1003)), 100);
        b.records[1].abandonedUnder = bytes32(uint256(1004));
        b.records[2] = _record(p, 1, 0, 2, address(1005), b.records[0].original.recordHash, 2, 3);
        W.PayoutContinuationV3 memory c;
        c.artistId = ID;
        c.recoveryRecordHash = bytes32(uint256(1100));
        c.actionId = bytes32(uint256(1101));
        c.manifestHash = bytes32(uint256(1102));
        c.planCommitment = bytes32(uint256(1103));
        c.identityOwnerRevision = 6;
        c.payoutOwnerRevision = 3;
        c.stable =
            T.Payout(b.records[0].original.terms.payoutAccount, b.records[0].original.recordHash);
        c.releasedChildRecordHash = b.records[1].original.recordHash;
        c.continuationHash = W.payoutContinuationHash(_env(p.origins[0]), c);
        b.continuations = new P.ContinuationRow[](1);
        b.continuations[0] =
            P.ContinuationRow(RH.Point(p.eras[0].originHash, 5, 3), c, bytes32(uint256(1104)));
        b.records[1].status = W.StatusV3(
            ID, W.RecordKind.PAYOUT_DESIGNATION, c.recoveryRecordHash, c.actionId, c.planCommitment
        );
        b.records[2].continuationHash = c.continuationHash;
        b.inventory.stable =
            T.Payout(b.records[2].original.terms.payoutAccount, b.records[2].original.recordHash);
        b.inventory.continuationCommitment = c.continuationHash;
        b.inventory.supersessionStateCommitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_STATUS_V3"),
                uint16(3),
                _env(p.origins[0]),
                bytes32(0),
                b.records[1].original.recordHash,
                b.records[1].status
            )
        );
        p.journals[5] = new RH.JournalEntry[](3);
        for (uint256 i; i < 3; ++i) {
            p.journals[5][i] = RH.JournalEntry(
                b.records[i].position, Hist.Receipt(18, ID, 0, b.records[i].original.recordHash)
            );
        }
        p.eras[0].nativeCounts[5] = 2;
        p.eras[1].nativeCounts[5] = 1;
        p.journals[2] = new RH.JournalEntry[](2);
        p.journals[2][0] = RH.JournalEntry(
            RH.Position(RH.Point(p.eras[0].originHash, 2, 6), 0),
            Hist.Receipt(35, ID, 0, c.recoveryRecordHash)
        );
        p.journals[2][1] = RH.JournalEntry(
            RH.Position(RH.Point(p.eras[0].originHash, 2, 6), 1),
            Hist.Receipt(35, ID, 0, bytes32(uint256(1105)))
        );
        p.eras[0].nativeCounts[2] = 2;
        p.aliases[2] = new RH.ReplayAlias[](3);
        for (uint256 i; i < 3; ++i) {
            uint256 era = i == 2 ? 1 : 0;
            W.PayoutOriginalV3 memory r = b.records[i].original;
            bytes32 digest = H.payoutDigest(
                H.Environment(block.chainid, p.origins[era].registry, address(400), address(401)),
                r.terms,
                T.Authorization(r.nonce, r.signedAt, new bytes(0))
            );
            p.aliases[2][i] = _alias(
                p.origins[era], 2, NONCE, keccak256(abi.encode(ID, r.nonce)), digest, i == 1 ? 4 : 2
            );
        }
        p.aliases[5] = new RH.ReplayAlias[](2);
        p.aliases[5][0] = _alias(p.origins[0], 5, APPLY, c.recoveryRecordHash, c.planCommitment, 3);
        p.aliases[5][1] = _alias(
            p.origins[1],
            5,
            ADMISSION,
            keccak256(abi.encode(ID, c.continuationHash, c.stable.recordHash)),
            b.records[2].original.recordHash,
            2
        );
        _sort(p.aliases[2]);
        _sort(p.aliases[5]);
        p.eras[0].checkpoints[2].replayCount = 2;
        p.eras[1].checkpoints[2].replayCount = 1;
        p.eras[0].checkpoints[5].replayCount = 1;
        p.eras[1].checkpoints[5].replayCount = 1;
    }

    function _record(
        RH.Provenance memory p,
        uint256 era,
        uint256 index,
        uint64 revision,
        address account,
        bytes32 previous,
        uint256 nonce,
        uint64 signedAt
    ) private pure returns (P.RecordRow memory r) {
        W.EnvironmentV3 memory e = _env(p.origins[era]);
        r.position = RH.Position(RH.Point(p.eras[era].originHash, 5, revision), index);
        r.original.terms = T.PayoutDesignation(ID, account, previous);
        r.original.signer = address(1200);
        r.original.authorityClass = 1;
        r.original.nonce = nonce;
        r.original.signedAt = signedAt;
        r.original.recordHash = H.payoutRecordForAuthority(
            H.Environment(e.chainId, e.registry, e.core, e.manager),
            r.original.terms,
            r.original.signer,
            1,
            nonce,
            signedAt
        );
        r.evidenceHash = W.payoutOriginalHash(e, r.original);
    }

    function _env(RH.OriginEnvironment memory o) private pure returns (W.EnvironmentV3 memory) {
        return W.EnvironmentV3(
            o.chainId,
            o.registry,
            o.owners[2],
            o.ownerCodeHashes[2],
            o.owners[5],
            o.ownerCodeHashes[5],
            o.coordinator,
            o.archive,
            o.core,
            o.manager
        );
    }

    function _alias(
        RH.OriginEnvironment memory o,
        uint8 owner,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment,
        uint64 revision
    ) private pure returns (RH.ReplayAlias memory a) {
        a.originHash = RH.originHash(o);
        a.ownerIndex = owner;
        a.surface = surface;
        a.scope = scope;
        a.originalKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[owner],
                RH.ownerDomain(owner),
                surface,
                scope
            )
        );
        a.cell = T.ReplayCell(commitment, revision, 1, 2);
        a.admittedAt = RH.Point(a.originHash, owner, revision);
    }

    function _sort(RH.ReplayAlias[] memory rows) private pure {
        for (uint256 i = 1; i < rows.length; ++i) {
            RH.ReplayAlias memory row = rows[i];
            uint256 j = i;
            while (j != 0 && rows[j - 1].originalKey > row.originalKey) {
                rows[j] = rows[j - 1];
                --j;
            }
            rows[j] = row;
        }
    }

    function _digest(P.Bundle memory b) private pure returns (bytes32 result) {
        result = keccak256(
            abi.encode(
                b.inventory.stable,
                b.inventory.candidate,
                b.inventory.supersessionStateCommitment,
                b.inventory.continuationCommitment
            )
        );
        for (uint256 i; i < b.records.length; ++i) {
            P.RecordRow memory r = b.records[i];
            result = keccak256(
                abi.encode(
                    result,
                    r.original.terms,
                    r.association,
                    r.abandonedUnder,
                    r.status,
                    r.continuationHash
                )
            );
        }
        for (uint256 i; i < b.continuations.length; ++i) {
            result = keccak256(
                abi.encode(
                    result, b.continuations[i].continuation, b.continuations[i].appliedCommitment
                )
            );
        }
    }

    function _reject(P.Bundle memory b, RH.Provenance memory p, bytes memory expected) private {
        (bool ok, bytes memory error) =
            address(harness).call(abi.encodeCall(harness.validate, (b, p)));
        require(!ok && keccak256(error) == keccak256(expected), "exact validation rejection");
    }

    function _rejectInstall(
        RecoveredPayoutCodecHarness target,
        P.Bundle memory b,
        RH.Provenance memory p,
        bytes32 expected
    ) private {
        (bool ok, bytes memory error) =
            address(target).call(abi.encodeCall(target.install, (ID, Codec.encode(b, p), p)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(P.InvalidRecoveredPayout.selector, expected)
                    ),
            "exact empty destination rejection"
        );
    }

    function _rejectCollect(address source, RH.Provenance memory p, bytes32 expected) private {
        (bool ok, bytes memory error) =
            address(harness).call(abi.encodeCall(harness.collect, (source, ID, p)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(P.InvalidRecoveredPayout.selector, expected)
                    ),
            "exact collection rejection"
        );
    }

    function _mockSource(P.Bundle memory b, RH.Provenance memory p) private {
        address source = payouts[1];
        vm.mockCall(
            source, abi.encodeWithSignature("ownerStateSnapshotV2()"), abi.encode(b.sourceSnapshot)
        );
        vm.mockCall(
            source,
            abi.encodeWithSignature("payoutRewindInventoryV3(bytes32)", ID),
            abi.encode(b.inventory)
        );
        for (uint256 era; era < 2; ++era) {
            W.EnvironmentV3 memory e = _env(p.origins[era]);
            address pub = publishers[era];
            vm.mockCall(
                identities[era],
                abi.encodeWithSignature("recoveryRewindEvidenceBinding()"),
                abi.encode(pub, pub.codehash)
            );
            vm.mockCall(pub, abi.encodeWithSignature("owner()"), abi.encode(e.identityOwner));
            vm.mockCall(pub, abi.encodeWithSignature("payoutOwner()"), abi.encode(e.payoutOwner));
            vm.mockCall(pub, abi.encodeWithSignature("artistRegistry()"), abi.encode(e.registry));
            vm.mockCall(pub, abi.encodeWithSignature("deploymentChainId()"), abi.encode(e.chainId));
            vm.mockCall(pub, abi.encodeWithSignature("coordinator()"), abi.encode(e.coordinator));
            vm.mockCall(pub, abi.encodeWithSignature("archive()"), abi.encode(e.archive));
            vm.mockCall(pub, abi.encodeWithSignature("core()"), abi.encode(e.core));
            vm.mockCall(pub, abi.encodeWithSignature("mintManager()"), abi.encode(e.manager));
        }
        for (uint256 i; i < b.records.length; ++i) {
            P.RecordRow memory r = b.records[i];
            bytes32 hash = r.original.recordHash;
            uint256 era = i == 2 ? 1 : 0;
            vm.mockCall(
                publishers[era],
                abi.encodeWithSignature("payoutOriginalV3(bytes32)", hash),
                abi.encode(
                    r.original,
                    r.evidenceHash,
                    p.origins[era].ownerCodeHashes[2],
                    p.origins[era].ownerCodeHashes[5]
                )
            );
            vm.mockCall(
                source,
                abi.encodeWithSignature("designationRecord(bytes32)", hash),
                abi.encode(r.original.terms)
            );
            vm.mockCall(
                source,
                abi.encodeWithSignature("payoutDesignationProvisionalAssociation(bytes32)", hash),
                abi.encode(r.association)
            );
            vm.mockCall(
                source,
                abi.encodeWithSignature("payoutAbandonment(bytes32)", hash),
                abi.encode(r.abandonedUnder)
            );
            vm.mockCall(
                source,
                abi.encodeWithSignature("payoutRecoveryRecordStatusV3(bytes32)", hash),
                abi.encode(r.status)
            );
            vm.mockCall(
                source,
                abi.encodeWithSignature("payoutDesignationRecoveryContinuationV3(bytes32)", hash),
                abi.encode(r.continuationHash)
            );
        }
        for (uint256 i; i < b.continuations.length; ++i) {
            P.ContinuationRow memory r = b.continuations[i];
            vm.mockCall(
                source,
                abi.encodeWithSignature(
                    "payoutRecoveryContinuationV3(bytes32)", r.continuation.continuationHash
                ),
                abi.encode(r.continuation)
            );
            vm.mockCall(
                source,
                abi.encodeWithSignature(
                    "payoutRecoveryAppliedCommitmentV3(bytes32)", r.continuation.recoveryRecordHash
                ),
                abi.encode(r.appliedCommitment)
            );
        }
    }
}
