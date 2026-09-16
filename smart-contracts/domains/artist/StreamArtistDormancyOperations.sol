// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistGovernanceWitness.sol";
import "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

/// @notice Original 41/42/43 recipes in the immutable, locked Artist Coordinator.
library StreamArtistDormancyOperations {
    function initiate(D.CoordinatorContext memory x, address actor, Dorm.Initiation memory p)
        public
        returns (bytes32 record)
    {
        T.Snapshot[7] memory before_ = _snapshots(x);
        IStreamArtistDormancyOwner owner = IStreamArtistDormancyOwner(x.suite.owners[2]);
        address executor = IStreamArtistIdentityContestOwner(address(owner)).artistWindowAuthority();
        if (actor != executor) revert T.Unauthorized(actor);
        Dorm.Context memory context = owner.dormancyInitiationContext(p);
        Contest.GovernanceWitness memory g = StreamArtistGovernanceWitness.readDormancy(
            x,
            executor,
            p.evidenceHash,
            context.scopeHash,
            context.oldValueHash,
            context.newValueHash
        );
        record = owner.initiateDormancy(T.ActionContext(41, actor, before_[2]), p, g);
        (Dorm.Notice memory saved, uint8 phase, Dorm.Terminal memory terminal) =
            owner.dormancyRecord(record);
        _archive(x, 41, actor, record, before_, abi.encode(p, context, g, saved, phase, terminal));
    }

    function cancel(
        D.CoordinatorContext memory x,
        address actor,
        bytes32 id,
        bytes32 expected,
        bytes32 grant
    ) public {
        T.Snapshot[7] memory before_ = _snapshots(x);
        IStreamArtistDormancyOwner owner = IStreamArtistDormancyOwner(x.suite.owners[2]);
        owner.cancelDormancy(T.ActionContext(42, actor, before_[2]), id, expected, grant);
        (Dorm.Notice memory saved, uint8 phase, Dorm.Terminal memory terminal) =
            owner.dormancyRecord(expected);
        _archive(
            x,
            42,
            actor,
            terminal.recordHash,
            before_,
            abi.encode(id, expected, grant, saved, phase, terminal)
        );
    }

    function complete(D.CoordinatorContext memory x, address actor, Dorm.Completion memory p)
        public
        returns (bytes32 record)
    {
        T.Snapshot[7] memory before_ = _snapshots(x);
        IStreamArtistDormancyOwner owner = IStreamArtistDormancyOwner(x.suite.owners[2]);
        address executor = IStreamArtistIdentityContestOwner(address(owner)).artistWindowAuthority();
        if (actor != executor) revert T.Unauthorized(actor);
        (Dorm.Context memory context, Dorm.Plan memory plan) = owner.dormancyCompletionContext(p);
        bytes memory evidence = owner.dormancyCompletionEvidence(p);
        // The full typed document is subsequently retained in the original operation archive.
        if (
            keccak256(evidence)
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_EVIDENCE_V1"),
                        uint16(1),
                        p,
                        plan
                    )
                )
        ) revert T.InvalidRecord();
        Contest.GovernanceWitness memory g = StreamArtistGovernanceWitness.readDormancy(
            x,
            executor,
            keccak256(evidence),
            context.scopeHash,
            context.oldValueHash,
            context.newValueHash
        );
        record = owner.completeDormancy(T.ActionContext(43, actor, before_[2]), p, g);
        (Dorm.Notice memory saved, uint8 phase, Dorm.Terminal memory terminal) =
            owner.dormancyRecord(p.expectedNoticeHash);
        _archive(
            x,
            43,
            actor,
            record,
            before_,
            abi.encode(p, context, plan, evidence, g, saved, phase, terminal)
        );
    }

    function _snapshots(D.CoordinatorContext memory x)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        result[2] = IStreamArtistOwner(x.suite.owners[2]).ownerStateSnapshotV2();
    }

    function _archive(
        D.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 record,
        T.Snapshot[7] memory before_,
        bytes memory payload
    ) private {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                op,
                actor,
                record
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, op, actor, record, before_, _snapshots(x), payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
