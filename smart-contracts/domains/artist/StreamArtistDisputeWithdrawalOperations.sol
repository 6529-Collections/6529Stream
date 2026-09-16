// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeWithdrawalAdmission.sol";
import "../../interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";

library StreamArtistDisputeWithdrawalOperations {
    function applyEncoded(D.CoordinatorContext memory x, bytes calldata data)
        public
        returns (bytes32 record)
    {
        (address actor, AD.Filing memory p, AD.Standing memory standing, T.Authorization memory a) =
            abi.decode(data[4:], (address, AD.Filing, AD.Standing, T.Authorization));
        T.Snapshot[7] memory before_ = snapshots(x.suite);
        (AD.Admission memory admission, AD.Head memory head) =
            StreamArtistDisputeWithdrawalAdmission.admit(x.suite, p, standing);
        admission.digest = StreamArtistDisputeHashes.digest(
            StreamArtistHashes.Environment(
                block.chainid, x.suite.registry, x.suite.core, x.suite.mintManager
            ),
            p,
            a
        );
        T.SignerApproval memory proof = StreamArtistDisputeAdmission.verify(
            x.suite, actor, admission.signer, admission.digest, a
        );
        bytes32 ep = StreamArtistDisputeAdmission.evidence(
            x.suite, admission.binding_, p.collectionId, head.disputeRecordHash, p.evidenceHash
        );
        bytes32 rp = StreamArtistDisputeAdmission.evidence(
            x.suite, admission.binding_, p.collectionId, head.disputeRecordHash, p.reasonHash
        );
        record = IStreamArtistDisputeIdentityOwner(x.suite.owners[2])
            .consumeAttributionDispute(
                T.ActionContext(61, actor, before_[2]), p, admission.binding_, standing, a, proof
            );
        bytes32 actual = IStreamArtistDisputeWithdrawalOwner(x.suite.owners[4])
            .applyDisputeWithdrawal(T.ActionContext(61, actor, before_[4]), p, admission, a.nonce);
        if (record != actual) revert T.InvalidRecord();
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(61),
                actor,
                record
            )
        );
        bytes memory payload = abi.encode(
            uint16(1),
            x.configurationHash,
            uint16(61),
            actor,
            record,
            before_,
            snapshots(x.suite),
            abi.encode(p, standing, a, admission, proof, head, ep, rp)
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, payload);
        if (!appended || hash != keccak256(payload)) revert T.InvalidRecord();
    }

    function snapshots(T.SuiteConfiguration memory s)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        for (uint256 i; i < 7; ++i) {
            if ((uint256(0x15) & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(s.owners[i]).ownerStateSnapshotV2();
            }
        }
    }
}
