// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistGovernanceWitness.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

/// @notice Explicit operation58 recipe in the immutable guarded Coordinator.
library StreamArtistIdentityDismissalOperations {
    function dismiss(D.CoordinatorContext memory x, address actor, Dismissal.Request memory p)
        public
        returns (bytes32 record)
    {
        IStreamArtistIdentityDismissalOwner owner =
            IStreamArtistIdentityDismissalOwner(x.suite.owners[2]);
        address executor = IStreamArtistIdentityContestOwner(address(owner)).artistWindowAuthority();
        if (actor != executor) revert T.Unauthorized(actor);
        T.Snapshot[7] memory before_;
        before_[2] = IStreamArtistOwner(address(owner)).ownerStateSnapshotV2();
        Dismissal.Context memory context_ = owner.identityContestDismissalContext(p);
        Dismissal.Cause memory cause = owner.currentIdentityContestCause(p.artistId);
        Contest.GovernanceWitness memory g = StreamArtistGovernanceWitness.read(
            x,
            executor,
            p.reasonHash,
            context_.scopeHash,
            context_.oldValueHash,
            context_.newValueHash
        );
        record = owner.dismissIdentityContest(T.ActionContext(58, actor, before_[2]), p, g);
        T.Snapshot[7] memory after_;
        after_[2] = IStreamArtistOwner(address(owner)).ownerStateSnapshotV2();
        Dismissal.Record memory item = owner.identityContestDismissalRecord(record);
        bytes memory payload = abi.encode(
            p,
            g,
            cause,
            context_,
            item,
            owner.identityRevisionContinuation(item.revisionContinuationHead),
            owner.identityTransitionClosure(p.artistId, cause.facts.pendingTransitionHash),
            owner.identityTransitionClosure(p.artistId, cause.facts.executedTransitionHash)
        );
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(58),
                actor,
                record
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, uint16(58), actor, record, before_, after_, payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
