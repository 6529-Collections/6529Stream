// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeAdmission.sol";
import "./StreamArtistGovernanceWitness.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

/// @notice Canonical44/45/46 recipes; called only from the pinned guarded Coordinator.
library StreamArtistDisputeOperations {
    function file(
        D.CoordinatorContext memory x,
        address actor,
        AD.Filing memory p,
        AD.Standing memory standing_,
        T.Authorization memory a,
        uint16 op
    ) public returns (bytes32 record) {
        StreamArtistDisputeHashes.validate(p);
        if ((op != 44 && op != 45) || p.disputeAction != (op == 44 ? 1 : 3)) revert T.InvalidOperation(op);
        T.Snapshot[7] memory before_ = _snapshots(x.suite, op);
        AD.Admission memory admission;
        T.SignerApproval memory proof;
        Contest.GovernanceWitness memory g;
        address authority =
            StreamArtistTimingState.canonicalAuthority(x.suite.core, x.suite.mintManager);
        AD.Context memory context;
        AD.Head memory head;
        if (actor == authority) {
            AD.Standing memory empty;
            if (
                op != 44 || keccak256(abi.encode(standing_)) != keccak256(abi.encode(empty))
                    || a.nonce != 0 || a.time != 0 || a.signature.length != 0
            ) revert AD.DisputeGovernanceRequired();
            context = StreamArtistDisputeAdmission.openingContext(x.suite, p);
            g = StreamArtistGovernanceWitness.read(
                x,
                authority,
                p.reasonHash,
                context.scopeHash,
                context.oldValueHash,
                context.newValueHash
            );
            (admission.binding_,, head) =
                StreamArtistDisputeAdmission.binding(x.suite, p.collectionId, p.bindingGeneration);
            if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
            admission.signer = g.proposer;
            admission.recordedAt = uint64(block.timestamp);
        } else {
            admission = StreamArtistDisputeAdmission.standing(x.suite, p, standing_);
            head = IStreamArtistAttributionDisputesOwner(x.suite.owners[4])
                .attributionDispute(p.collectionId, p.bindingGeneration);
            admission.digest = StreamArtistDisputeHashes.digest(_environment(x.suite), p, a);
            proof = StreamArtistDisputeAdmission.verify(
                x.suite, actor, admission.signer, admission.digest, a
            );
        }
        bytes32 parent = head.disputeRecordHash;
        bytes32 ep = StreamArtistDisputeAdmission.evidence(
            x.suite, admission.binding_, p.collectionId, parent, p.evidenceHash
        );
        bytes32 rp = StreamArtistDisputeAdmission.evidence(
            x.suite, admission.binding_, p.collectionId, parent, p.reasonHash
        );
        if (g.actionId == 0) {
            record = IStreamArtistDisputeIdentityOwner(x.suite.owners[2])
                .consumeAttributionDispute(
                    T.ActionContext(op, actor, before_[2]),
                    p,
                    admission.binding_,
                    standing_,
                    a,
                    proof
                );
        }
        bytes32 actual = IStreamArtistAttributionDisputesOwner(x.suite.owners[4])
            .applyDispute(T.ActionContext(op, actor, before_[4]), p, admission, a.nonce, g);
        if (g.actionId == 0 && actual != record) revert T.InvalidRecord();
        record = actual;
        _archive(
            x,
            op,
            actor,
            record,
            before_,
            abi.encode(p, standing_, a, admission, proof, context, g, head, ep, rp)
        );
    }

    function resolve(D.CoordinatorContext memory x, address actor, AD.ResolutionRequest memory p)
        public
        returns (bytes32 action)
    {
        address authority =
            StreamArtistTimingState.canonicalAuthority(x.suite.core, x.suite.mintManager);
        if (actor != authority) revert T.Unauthorized(actor);
        AD.Context memory context = StreamArtistDisputeAdmission.resolutionContext(x.suite, p);
        Contest.GovernanceWitness memory g = StreamArtistGovernanceWitness.read(
            x,
            authority,
            p.reasonHash,
            context.scopeHash,
            context.oldValueHash,
            context.newValueHash
        );
        if (g.actionClass < context.requiredClass) revert AD.DisputeGovernanceRequired();
        (T.Binding memory b,,) =
            StreamArtistDisputeAdmission.binding(x.suite, p.collectionId, p.bindingGeneration);
        bytes32 ep = StreamArtistDisputeAdmission.evidence(
            x.suite, b, p.collectionId, p.disputeRecordHash, p.evidenceHash
        );
        bytes32 rp = StreamArtistDisputeAdmission.evidence(
            x.suite, b, p.collectionId, p.disputeRecordHash, p.reasonHash
        );
        T.Snapshot[7] memory before_ = _snapshots(x.suite, 46);
        action = IStreamArtistAttributionDisputesOwner(x.suite.owners[4])
            .applyDisputeResolution(T.ActionContext(46, actor, before_[4]), p, b, g);
        if (action != g.actionId) revert T.InvalidRecord();
        _archive(x, 46, actor, action, before_, abi.encode(p, b, context, g, ep, rp));
    }

    function _snapshots(T.SuiteConfiguration memory s, uint16 op)
        private
        view
        returns (T.Snapshot[7] memory before_)
    {
        // Original snapshot/read masks44=0x15,45=0x17,46=0x11; semantic writes44/45=0x14,46=0x10.
        uint256 mask = op == 44 ? 0x15 : op == 45 ? 0x17 : 0x11;
        for (uint256 i; i < 7; ++i) {
            if ((mask & (1 << i)) != 0) {
                before_[i] = IStreamArtistOwner(s.owners[i]).ownerStateSnapshotV2();
            }
        }
    }

    function _archive(
        D.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 record,
        T.Snapshot[7] memory before_,
        bytes memory detail
    ) private {
        T.Snapshot[7] memory after_ = _snapshots(x.suite, op);
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
        bytes memory payload =
            abi.encode(uint16(1), x.configurationHash, op, actor, record, before_, after_, detail);
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, payload);
        if (!appended || hash != keccak256(payload)) revert T.InvalidRecord();
    }

    function _environment(T.SuiteConfiguration memory s)
        private
        view
        returns (StreamArtistHashes.Environment memory)
    {
        return StreamArtistHashes.Environment(block.chainid, s.registry, s.core, s.mintManager);
    }
}
