// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRepudiationFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

/// @notice Original47–50 entry recipes, composing only the fixed semantic owners and Archive.
library StreamArtistRepudiationOperations {
    function stage(
        D.CoordinatorContext memory x,
        address actor,
        AD.Filing memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x.suite, 47);
        RP.Admission memory admission = StreamArtistRepudiationFacts.stage(x.suite, p);
        bytes32 digest = StreamArtistRepudiationHashes.digest(_environment(x.suite), p, a);
        T.SignerApproval memory proof = StreamArtistDisputeAdmission.verify(
            x.suite, actor, admission.authorityHead.principal, digest, a
        );
        record = IStreamArtistRepudiationIdentityOwner(x.suite.owners[2])
            .consumeRepudiation(T.ActionContext(47, actor, before_[2]), p, admission, a, proof);
        bytes32 actual = IStreamArtistRepudiationOwner(x.suite.owners[4])
            .stageRepudiation(T.ActionContext(47, actor, before_[4]), p, admission, a.nonce);
        if (actual != record) revert T.InvalidRecord();
        _archive(x, 47, actor, record, before_, abi.encode(p, a, admission, proof));
    }

    function veto(
        D.CoordinatorContext memory x,
        address actor,
        uint256 id,
        bytes32 expected,
        bytes32 reason
    ) public {
        T.Snapshot[7] memory before_ = _snapshots(x.suite, 48);
        RP.Record memory r = StreamArtistRepudiationFacts.requireLive(x.suite, id, expected, false);
        RP.GuardianProof memory proof =
            StreamArtistRepudiationFacts.guardianProof(x.suite, actor, id, expected, reason);
        IStreamArtistRepudiationOwner(x.suite.owners[4])
            .vetoRepudiation(T.ActionContext(48, actor, before_[4]), r, proof);
        bytes32 contest = IStreamArtistRepudiationIdentityOwner(x.suite.owners[2])
            .contestRepudiation(T.ActionContext(48, actor, before_[2]), proof);
        if (contest == 0) revert T.InvalidRecord();
        _archive(x, 48, actor, expected, before_, abi.encode(r, proof, contest));
    }

    function cancel(D.CoordinatorContext memory x, address actor, uint256 id, bytes32 expected)
        public
    {
        T.Snapshot[7] memory before_ = _snapshots(x.suite, 49);
        RP.Record memory r = StreamArtistRepudiationFacts.requireLive(x.suite, id, expected, false);
        if (actor != r.signer) revert T.Unauthorized(actor);
        IStreamArtistRepudiationOwner(x.suite.owners[4])
            .cancelRepudiation(T.ActionContext(49, actor, before_[4]), r);
        IStreamArtistRepudiationIdentityOwner(x.suite.owners[2])
            .noteRepudiationCancellation(T.ActionContext(49, actor, before_[2]), r);
        _archive(x, 49, actor, expected, before_, abi.encode(r));
    }

    function execute(D.CoordinatorContext memory x, address actor, uint256 id, bytes32 expected)
        public
    {
        T.Snapshot[7] memory before_ = _snapshots(x.suite, 50);
        RP.Record memory r = StreamArtistRepudiationFacts.requireLive(x.suite, id, expected, true);
        IStreamArtistRepudiationOwner(x.suite.owners[4])
            .executeRepudiation(T.ActionContext(50, actor, before_[4]), r);
        _archive(x, 50, actor, expected, before_, abi.encode(r));
    }

    function _snapshots(T.SuiteConfiguration memory s, uint16 op)
        private
        view
        returns (T.Snapshot[7] memory snapshots)
    {
        // Canonical read masks47=0x17,48/49=0x14,50=0x15;48/49 also commit the required Identity effects.
        uint256 mask = op == 47 ? 0x17 : op == 50 ? 0x15 : 0x14;
        for (uint256 i; i < 7; ++i) {
            if ((mask & (1 << i)) != 0) {
                snapshots[i] = IStreamArtistOwner(s.owners[i]).ownerStateSnapshotV2();
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
