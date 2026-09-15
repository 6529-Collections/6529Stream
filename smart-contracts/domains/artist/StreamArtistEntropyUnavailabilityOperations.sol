// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/entropy/IStreamEntropyArtistUnavailability.sol";
import "./StreamArtistEntropyUnavailabilityAdmission.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

/// @notice Explicit entropy operation23 profile, one original Identity commit and atomic Archive.
library StreamArtistEntropyUnavailabilityOperations {
    function recordEncoded(D.CoordinatorContext memory x, bytes calldata encoded)
        public
        returns (bytes32 hash)
    {
        (address actor, Recovery.FindingRequest memory request, EU.Target memory target) =
            abi.decode(encoded[4:], (address, Recovery.FindingRequest, EU.Target));
        T.Snapshot[7] memory before_ = _snapshots(x.suite);
        StreamArtistEntropyUnavailabilityAdmission.Prepared memory p =
            StreamArtistEntropyUnavailabilityAdmission.prepare(x.suite, request, target);
        if (actor != p.executor) revert T.Unauthorized(actor);
        p.input.governance = StreamArtistEntropyUnavailabilityAdmission.governance(x.suite, p);
        StreamArtistEntropyUnavailabilityAdmission.Prepared memory check =
            StreamArtistEntropyUnavailabilityAdmission.prepare(x.suite, request, target);
        check.input.governance =
            StreamArtistEntropyUnavailabilityAdmission.governance(x.suite, check);
        if (keccak256(abi.encode(check)) != keccak256(abi.encode(p))) revert T.InvalidBinding();
        _unchanged(before_, _snapshots(x.suite));
        IStreamArtistEntropyUnavailabilityOwner owner =
            IStreamArtistEntropyUnavailabilityOwner(x.suite.owners[2]);
        hash = owner.recordEntropyUnavailability(T.ActionContext(23, actor, before_[2]), p.input);
        T.Snapshot[7] memory after_ = _snapshots(x.suite);
        if (
            keccak256(abi.encode(before_[0], before_[4]))
                != keccak256(abi.encode(after_[0], after_[4]))
        ) {
            revert T.InvalidBinding();
        }
        (Recovery.FindingRecord memory saved, EU.Admission memory admission) =
            owner.entropyUnavailabilityFindingRecord(hash);
        _append(x, actor, hash, before_, after_, abi.encode(EU.PROFILE, p, saved, admission));
    }

    function prepareEncoded(T.SuiteConfiguration memory suite, bytes calldata encoded)
        public
        view
        returns (bytes memory)
    {
        (Recovery.FindingRequest memory request, EU.Target memory target) =
            abi.decode(encoded[4:], (Recovery.FindingRequest, EU.Target));
        return abi.encode(
            StreamArtistEntropyUnavailabilityAdmission.prepare(suite, request, target).context_
        );
    }

    function verifyEncoded(T.SuiteConfiguration memory suite, bytes calldata encoded)
        public
        view
        returns (bytes memory)
    {
        (
            address coordinator,
            IStreamEntropyFreshRecovery.RecoveryInput memory input,
            bytes32 intentHash,
            bytes32 expectedFinding
        ) = abi.decode(
            encoded[4:], (address, IStreamEntropyFreshRecovery.RecoveryInput, bytes32, bytes32)
        );
        (bool valid, bytes32 hash, bytes32 artistId, uint64 noticeEndsAt) = StreamArtistEntropyUnavailabilityAdmission.verify(
            suite, coordinator, input, intentHash, expectedFinding
        );
        return abi.encode(valid, hash, artistId, noticeEndsAt);
    }

    function _snapshots(T.SuiteConfiguration memory suite)
        private
        view
        returns (T.Snapshot[7] memory s)
    {
        s[0] = IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2();
        s[2] = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        s[4] = IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2();
    }

    function _unchanged(T.Snapshot[7] memory a, T.Snapshot[7] memory b) private pure {
        if (keccak256(abi.encode(a)) != keccak256(abi.encode(b))) revert T.InvalidBinding();
    }

    function _append(
        D.CoordinatorContext memory x,
        address actor,
        bytes32 recordHash,
        T.Snapshot[7] memory before_,
        T.Snapshot[7] memory after_,
        bytes memory payload
    ) private {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(23),
                actor,
                recordHash
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, uint16(23), actor, recordHash, before_, after_, payload
        );
        (bytes32 actual,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || actual != keccak256(evidence)) revert T.InvalidRecord();
    }
}
