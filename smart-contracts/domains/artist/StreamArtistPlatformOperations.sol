// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPlatformEvidence.sol";
import "./StreamArtistGovernanceWitness.sol";
import "./StreamArtistTimingState.sol";
import "../../interfaces/stream/mint/IStreamMintPhaseHistory.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";

/// @notice Original ops 8/9/11/53, run only by the fixed guarded Coordinator.
library StreamArtistPlatformOperations {
    function declare(D.CoordinatorContext memory x, address actor, uint256 id, bytes32 statement)
        public
        returns (bytes32 record)
    {
        _collection(x, id);
        bytes32 role = keccak256("ROLE_ARTIST_REGISTRY_ADMIN");
        if (!IStreamRoleRegistry(x.suite.roleRegistry).hasRole(role, actor)) {
            revert T.Unauthorized(actor);
        }
        if (
            IStreamMintPhaseHistory(x.suite.mintManager).hasRegisteredPhasePolicy(id)
                || IStreamArtistBindingOwner(x.suite.owners[0]).binding(id).generation != 0
        ) revert PW.InvalidPlatformWorks(id);
        (bytes32 roleHash, uint64 roleRevision) =
            IStreamRoleRegistry(x.suite.roleRegistry).roleMutationState(role);
        T.Snapshot[7] memory prior = _snapshots(x, 8);
        record = IStreamArtistPlatformOwner(x.suite.owners[4])
            .declarePlatformWorks(T.ActionContext(8, actor, prior[4]), id, statement);
        _archive(x, 8, actor, record, prior, abi.encode(id, statement, roleHash, roleRevision));
    }

    function claim(
        D.CoordinatorContext memory x,
        address actor,
        uint256 id,
        bytes32 evidence,
        bytes32 reason,
        string memory uri
    ) public returns (bytes32 record) {
        _collection(x, id);
        T.Snapshot[7] memory prior = _snapshots(x, 9);
        (PW.Evidence memory e, bytes32 ep) =
            StreamArtistPlatformEvidence.read(x.suite, id, evidence);
        (PW.Evidence memory r, bytes32 rp) = StreamArtistPlatformEvidence.read(x.suite, id, reason);
        if (
            r.proposedArtist != e.proposedArtist || e.claimRecordHash != 0 || r.claimRecordHash != 0
        ) {
            revert PW.InvalidPlatformEvidence(evidence);
        }
        record = IStreamArtistPlatformOwner(x.suite.owners[4])
            .filePlatformWorksClaim(
                T.ActionContext(9, actor, prior[4]), id, evidence, reason, uri, e.proposedArtist
            );
        _archive(x, 9, actor, record, prior, abi.encode(id, evidence, reason, uri, e, r, ep, rp));
    }

    function context(
        D.CoordinatorContext memory x,
        uint256 id,
        uint8 state,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bool correction
    ) public view returns (PW.Context memory c) {
        PW.State memory p = IStreamArtistPlatformOwner(x.suite.owners[4]).platformWorksState(id);
        c.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_WORKS_GOVERNANCE_SCOPE_V1"),
                block.chainid,
                x.suite.registry,
                x.suite.core,
                id,
                correction
            )
        );
        // Unrelated permissionless claims cannot invalidate a scheduled adjudication.
        c.oldValueHash = keccak256(
            abi.encode(p.declaration, p.contestState, p.contestClaim, p.contestRecord, p.correction)
        );
        c.newValueHash =
            keccak256(abi.encode(c.scopeHash, c.oldValueHash, state, claim_, evidence, reason));
    }

    function resolve(
        D.CoordinatorContext memory x,
        address actor,
        uint256 id,
        uint8 state,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bool correction
    ) public returns (bytes32 record) {
        _collection(x, id);
        address authority =
            StreamArtistTimingState.canonicalAuthority(x.suite.core, x.suite.mintManager);
        if (actor != authority) revert T.Unauthorized(actor);
        PW.Context memory c = context(x, id, state, claim_, evidence, reason, correction);
        Contest.GovernanceWitness memory g = StreamArtistGovernanceWitness.read(
            x, authority, reason, c.scopeHash, c.oldValueHash, c.newValueHash
        );
        if (g.actionClass != (correction ? 2 : 1)) revert Contest.InvalidContestGovernance();
        (PW.Evidence memory e, bytes32 ep) =
            StreamArtistPlatformEvidence.read(x.suite, id, evidence);
        (PW.Evidence memory r, bytes32 rp) = StreamArtistPlatformEvidence.read(x.suite, id, reason);
        PW.Claim memory original =
            IStreamArtistPlatformOwner(x.suite.owners[4]).platformWorksClaimRecord(claim_);
        if (
            original.collectionId != id || original.recordHash != claim_
                || e.claimRecordHash != claim_ || r.claimRecordHash != claim_
                || r.proposedArtist != e.proposedArtist
        ) revert PW.InvalidPlatformEvidence(evidence);
        if (
            correction
                && e.proposedArtist
                    != IStreamArtistPlatformOwner(x.suite.owners[4])
                    .platformWorksContestRecord(
                        IStreamArtistPlatformOwner(x.suite.owners[4])
                        .platformWorksState(id)
                        .contestRecord
                    )
                    .adjudicatedArtist
        ) revert PW.InvalidPlatformEvidence(evidence);
        uint16 op = correction ? 53 : 11;
        T.Snapshot[7] memory prior = _snapshots(x, op);
        if (correction) {
            record = IStreamArtistPlatformOwner(x.suite.owners[4])
                .approvePlatformWorksCorrection(
                    T.ActionContext(op, actor, prior[4]), id, claim_, evidence, reason, g.actionId
                );
        } else {
            record = IStreamArtistPlatformOwner(x.suite.owners[4])
                .setPlatformWorksContest(
                    T.ActionContext(op, actor, prior[4]),
                    id,
                    state,
                    claim_,
                    evidence,
                    reason,
                    g.actionId,
                    e.proposedArtist
                );
        }
        _archive(
            x,
            op,
            actor,
            record,
            prior,
            abi.encode(id, state, claim_, evidence, reason, correction, c, g, e, r, ep, rp)
        );
    }

    function _collection(D.CoordinatorContext memory x, uint256 id) private view {
        if (id == 0 || !IStreamCoreCollectionView(x.suite.core).collectionExists(id)) {
            revert PW.InvalidPlatformWorks(id);
        }
    }

    function _snapshots(D.CoordinatorContext memory x, uint16 op)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        uint256 mask = op == 8 ? 0x51 : 0x10;
        for (uint256 i; i < 7; ++i) {
            if ((mask & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }

    function _archive(
        D.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 record,
        T.Snapshot[7] memory prior,
        bytes memory payload
    ) private {
        T.Snapshot[7] memory after_ = _snapshots(x, op);
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
        bytes memory evidence =
            abi.encode(uint16(1), x.configurationHash, op, actor, record, prior, after_, payload);
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
