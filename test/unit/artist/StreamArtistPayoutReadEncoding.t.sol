// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistPayoutLifecycle
} from "../../../smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol";
import {
    StreamArtistPayoutReadEncoding as Encoding
} from "../../../smart-contracts/domains/artist/StreamArtistPayoutReadEncoding.sol";
import {
    StreamArtistPayoutRecoveryState as S
} from "../../../smart-contracts/domains/artist/StreamArtistPayoutRecoveryState.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistPayoutOwner as P
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    IStreamArtistPayoutTransitionOwner as PT
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3 as V3
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";

interface PayoutReadVm {
    function prank(address) external;
    function warp(uint256) external;
}

/// @dev Typed synthetic storage only; does not claim recovery35 or import admission.
contract PayoutReadStorageProbe {
    uint256 private guard = 19;
    mapping(bytes32 => T.Payout) private stable;
    mapping(bytes32 => T.Payout) private pending;
    mapping(bytes32 => T.PayoutDesignation) private records;
    mapping(bytes32 => R.ProvisionalAssociation) private associations;
    S.State private recovery;

    function install(bytes32 key, address a, address b, uint64 revision) external {
        stable[key] = T.Payout(a, bytes32(uint256(21)));
        pending[key] = T.Payout(b, bytes32(uint256(22)));
        records[key] = T.PayoutDesignation(key, a, bytes32(uint256(23)));
        associations[key] = R.ProvisionalAssociation(bytes32(uint256(24)), revision);
        associations[bytes32(uint256(22))] =
            R.ProvisionalAssociation(bytes32(uint256(25)), revision);
        recovery.statusCommitments[key] = bytes32(uint256(26));
        recovery.continuationHeads[key] = bytes32(uint256(27));
        recovery.statuses[key] = W.StatusV3(
            key,
            W.RecordKind.PAYOUT_DESIGNATION,
            bytes32(uint256(28)),
            bytes32(uint256(29)),
            bytes32(uint256(30))
        );
        recovery.continuations[key] = W.PayoutContinuationV3(
            key,
            bytes32(uint256(31)),
            bytes32(uint256(32)),
            bytes32(uint256(33)),
            bytes32(uint256(34)),
            revision,
            T.Payout(a, bytes32(uint256(35))),
            T.Payout(b, bytes32(uint256(36))),
            bytes32(uint256(37)),
            bytes32(uint256(38)),
            revision,
            bytes32(uint256(39))
        );
    }

    function read(bytes calldata data) external view returns (bytes memory) {
        require(guard == 19, "unrelated root retained");
        return Encoding.read(stable, pending, records, associations, recovery, data);
    }
}

/// @notice Literal return-word checks and actual Payout18 writes around the six read-only routes.
/// @dev The test is the typed Coordinator; no signature/Safe/Archive ingress or recovery35 claim.
contract StreamArtistPayoutReadEncodingTest {
    PayoutReadVm private constant vm =
        PayoutReadVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamArtistPayoutLifecycle private owner;
    bytes32 private constant ARTIST = keccak256("payout encoding artist");
    address private constant REGISTRY = address(0x101);
    address private constant ARCHIVE = address(0x202);
    error LateFailure();

    function setUp() public {
        vm.warp(1000);
        owner = new StreamArtistPayoutLifecycle(
            REGISTRY, address(this), ARCHIVE, address(0x303), address(0x404)
        );
        require(address(owner).code.length <= 24576, "actual owner admission");
    }

    function _assertRead(address target, bytes memory callData, bytes memory expected)
        private
        view
    {
        (bool ok, bytes memory raw) = target.staticcall(callData);
        require(
            ok && raw.length == expected.length && keccak256(raw) == keccak256(expected),
            "exact original outer ABI"
        );
    }

    function testActualOwnerEmptySixReadsHaveOriginalShapes() public view {
        _assertRead(
            address(owner),
            abi.encodeCall(P.designationRecord, (ARTIST)),
            abi.encode(bytes32(0), uint256(0), bytes32(0))
        );
        _assertRead(
            address(owner),
            abi.encodeCall(PT.payoutDesignationProvisionalAssociation, (ARTIST)),
            abi.encode(bytes32(0), uint256(0))
        );
        bytes32[6] memory six;
        _assertRead(address(owner), abi.encodeCall(PT.payoutCandidates, (ARTIST)), abi.encode(six));
        _assertRead(
            address(owner), abi.encodeCall(V3.payoutRewindInventoryV3, (ARTIST)), abi.encode(six)
        );
        bytes32[5] memory five;
        _assertRead(
            address(owner),
            abi.encodeCall(V3.payoutRecoveryRecordStatusV3, (ARTIST)),
            abi.encode(five)
        );
        bytes32[14] memory fourteen;
        _assertRead(
            address(owner),
            abi.encodeCall(V3.payoutRecoveryContinuationV3, (ARTIST)),
            abi.encode(fourteen)
        );
    }

    function _context() private view returns (T.ActionContext memory) {
        return T.ActionContext(18, address(this), owner.ownerStateSnapshotV2());
    }

    function _record(T.PayoutDesignation memory p, uint256 nonce) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_PAYOUT_DESIGNATION_RECORD_V1"),
                block.chainid,
                REGISTRY,
                p.artistId,
                p.payoutAccount,
                p.previousDesignationRecordHash,
                address(this),
                uint8(1),
                nonce,
                uint64(1000)
            )
        );
    }

    function testActualStableWriteRetainsRecordInventoryAndCallerIndependentReads() public {
        T.PayoutDesignation memory p = T.PayoutDesignation(ARTIST, address(0xB001), 0);
        bytes32 record = owner.recordDesignation(_context(), p, address(this), 1, 1000);
        require(record == _record(p, 1), "literal original record");
        bytes memory expected = abi.encode(ARTIST, p.payoutAccount, bytes32(0));
        _assertRead(address(owner), abi.encodeCall(P.designationRecord, (record)), expected);
        vm.prank(address(0xBEEF));
        require(
            keccak256(abi.encode(owner.designationRecord(record))) == keccak256(expected),
            "independent caller"
        );
        _assertRead(
            address(owner),
            abi.encodeCall(PT.payoutCandidates, (ARTIST)),
            abi.encode(p.payoutAccount, record, uint256(0), bytes32(0), bytes32(0), uint256(0))
        );
        _assertRead(
            address(owner),
            abi.encodeCall(V3.payoutRewindInventoryV3, (ARTIST)),
            abi.encode(p.payoutAccount, record, uint256(0), bytes32(0), bytes32(0), bytes32(0))
        );
        require(
            owner.ownerStateSnapshotV2().revision == 1 && owner.artistNativeReceiptCount() == 1,
            "one original commit/native row"
        );
    }

    function testActualProvisionalWriteUsesCandidateRecordForAssociation() public {
        T.PayoutDesignation memory p = T.PayoutDesignation(ARTIST, address(0xB002), 0);
        R.TransitionState memory current;
        current.artistId = ARTIST;
        current.recordHash = bytes32(uint256(41));
        current.phase = 2;
        current.executedAt = 900;
        current.postWindowEndsAt = 1100;
        R.TransitionState memory absent;
        bytes32 record = owner.recordDesignationWithTransition(
            _context(), p, address(this), 2, 1000, current, absent
        );
        _assertRead(
            address(owner),
            abi.encodeCall(PT.payoutCandidates, (ARTIST)),
            abi.encode(
                uint256(0), bytes32(0), p.payoutAccount, record, current.recordHash, uint256(1100)
            )
        );
        _assertRead(
            address(owner),
            abi.encodeCall(PT.payoutDesignationProvisionalAssociation, (record)),
            abi.encode(current.recordHash, uint256(1100))
        );
        (bool ok,) = address(owner).staticcall(abi.encodeCall(P.artistPayoutAccount, (ARTIST)));
        require(!ok, "original authority-context refusal retained");
    }

    function testUnauthorizedAndStaleWritesLeaveReadStateUntouched() public {
        T.ActionContext memory c = _context();
        T.PayoutDesignation memory p = T.PayoutDesignation(ARTIST, address(0xB003), 0);
        bytes memory data =
            abi.encodeCall(P.recordDesignation, (c, p, address(this), 3, uint64(1000)));
        vm.prank(address(0xBEEF));
        (bool ok,) = address(owner).call(data);
        require(!ok && owner.ownerStateSnapshotV2().revision == 0, "caller guard");
        (ok,) = address(owner).call(data);
        require(ok, "same original request succeeds");
        bytes32 after_ =
            keccak256(abi.encode(owner.ownerStateSnapshotV2(), owner.authorityCheckpoint()));
        (ok,) = address(owner).call(data);
        require(
            !ok
                && keccak256(abi.encode(owner.ownerStateSnapshotV2(), owner.authorityCheckpoint()))
                    == after_,
            "stale guard and exact checkpoint"
        );
    }

    function writeThenFail(T.ActionContext calldata c, T.PayoutDesignation calldata p) external {
        require(msg.sender == address(this));
        owner.recordDesignation(c, p, address(this), 4, 1000);
        revert LateFailure();
    }

    function testLateRollbackRestoresReadsAndSameRequestRetries() public {
        T.ActionContext memory c = _context();
        T.PayoutDesignation memory p = T.PayoutDesignation(ARTIST, address(0xB004), 0);
        bytes32 before_ =
            keccak256(abi.encode(owner.ownerStateSnapshotV2(), owner.authorityCheckpoint()));
        (bool ok, bytes memory reason) =
            address(this).call(abi.encodeCall(this.writeThenFail, (c, p)));
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSelector(LateFailure.selector)),
            "late failure reached"
        );
        require(
            keccak256(abi.encode(owner.ownerStateSnapshotV2(), owner.authorityCheckpoint()))
                    == before_ && owner.artistNativeReceiptCount() == 0,
            "atomic old roots and journal"
        );
        bytes32 record = owner.recordDesignation(c, p, address(this), 4, 1000);
        _assertRead(
            address(owner),
            abi.encodeCall(P.designationRecord, (record)),
            abi.encode(ARTIST, p.payoutAccount, bytes32(0))
        );
    }

    function testHostRejectsShortArgumentsAndUnknownSelector() public view {
        (bool ok,) =
            address(owner).staticcall(abi.encodePacked(P.designationRecord.selector, bytes31(0)));
        require(!ok, "original short calldata decoder");
        (ok,) = address(owner).staticcall(abi.encodePacked(bytes4(0xffffffff), ARTIST));
        require(!ok, "no public generic dispatch");
    }

    function _probe(address a, address b, uint64 revision) private {
        PayoutReadStorageProbe probe = new PayoutReadStorageProbe();
        probe.install(ARTIST, a, b, revision);
        require(
            keccak256(probe.read(abi.encodeCall(P.designationRecord, (ARTIST))))
                == keccak256(abi.encode(ARTIST, a, uint256(23))),
            "record3"
        );
        require(
            keccak256(
                    probe.read(abi.encodeCall(PT.payoutDesignationProvisionalAssociation, (ARTIST)))
                ) == keccak256(abi.encode(uint256(24), uint256(revision))),
            "association2"
        );
        require(
            keccak256(probe.read(abi.encodeCall(PT.payoutCandidates, (ARTIST))))
                == keccak256(
                    abi.encode(a, uint256(21), b, uint256(22), uint256(25), uint256(revision))
                ),
            "candidate6 independent key"
        );
        require(
            keccak256(probe.read(abi.encodeCall(V3.payoutRewindInventoryV3, (ARTIST))))
                == keccak256(abi.encode(a, uint256(21), b, uint256(22), uint256(26), uint256(27))),
            "inventory6"
        );
        require(
            keccak256(probe.read(abi.encodeCall(V3.payoutRecoveryRecordStatusV3, (ARTIST))))
                == keccak256(
                    abi.encode(
                        ARTIST,
                        uint256(W.RecordKind.PAYOUT_DESIGNATION),
                        uint256(28),
                        uint256(29),
                        uint256(30)
                    )
                ),
            "status5"
        );
        bytes32[14] memory words = [
            ARTIST,
            bytes32(uint256(31)),
            bytes32(uint256(32)),
            bytes32(uint256(33)),
            bytes32(uint256(34)),
            bytes32(uint256(revision)),
            bytes32(uint256(uint160(a))),
            bytes32(uint256(35)),
            bytes32(uint256(uint160(b))),
            bytes32(uint256(36)),
            bytes32(uint256(37)),
            bytes32(uint256(38)),
            bytes32(uint256(revision)),
            bytes32(uint256(39))
        ];
        require(
            keccak256(probe.read(abi.encodeCall(V3.payoutRecoveryContinuationV3, (ARTIST))))
                == keccak256(abi.encode(words)),
            "continuation14"
        );
    }

    function testTypedNonemptyRootsKeepLiteralSixResults() public {
        _probe(address(0x1234), address(0x5678), type(uint64).max);
    }

    function testFuzzTypedReadWords(address a, address b, uint64 revision) public {
        _probe(a, b, revision);
    }

    function testWorkerRejectsSelectorOutsideOriginalClosedSix() public {
        PayoutReadStorageProbe probe = new PayoutReadStorageProbe();
        (bool ok, bytes memory reason) = address(probe)
            .staticcall(
                abi.encodeCall(probe.read, (abi.encodePacked(P.recordDesignation.selector, ARTIST)))
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            Encoding.UnknownPayoutReadSelector.selector,
                            P.recordDesignation.selector
                        )
                    ),
            "no worker mutation route"
        );
    }
}
