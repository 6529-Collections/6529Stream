// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRecoveryAdmission.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

/// @notice Operation23 has one Identity commit and no signer nonce or authority activity.
library StreamArtistUnavailabilityOperations {
    function record(
        D.CoordinatorContext memory x,
        address originalFinality,
        address actor,
        Recovery.FindingRequest memory request,
        U.Target memory target
    ) public returns (bytes32 hash) {
        T.Snapshot[7] memory before_ = _snapshots(x.suite);
        StreamArtistRecoveryAdmission.Prepared memory p =
            StreamArtistRecoveryAdmission.prepare(x.suite, originalFinality, request, target);
        if (actor != p.executor) revert T.Unauthorized(actor);
        p.input.governance = StreamArtistRecoveryAdmission.governance(x.suite, p);
        // Repeat all candidate observations under the operation lock immediately before the write.
        StreamArtistRecoveryAdmission.Prepared memory check =
            StreamArtistRecoveryAdmission.prepare(x.suite, originalFinality, request, target);
        check.input.governance = StreamArtistRecoveryAdmission.governance(x.suite, check);
        if (keccak256(abi.encode(check)) != keccak256(abi.encode(p))) revert T.InvalidBinding();
        _unchanged(before_, _snapshots(x.suite));
        IStreamArtistUnavailabilityOwner owner = IStreamArtistUnavailabilityOwner(x.suite.owners[2]);
        hash = owner.recordUnavailability(T.ActionContext(23, actor, before_[2]), p.input);
        T.Snapshot[7] memory after_ = _snapshots(x.suite);
        if (
            keccak256(abi.encode(before_[0], before_[4]))
                != keccak256(abi.encode(after_[0], after_[4]))
        ) {
            revert T.InvalidBinding();
        }
        (Recovery.FindingRecord memory saved, U.Admission memory admission) =
            owner.unavailabilityFindingRecord(hash);
        _append(x, actor, hash, before_, after_, abi.encode(p, saved, admission));
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
