// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPlatformOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";

/// @notice Original operation10, with the original caller and canonical covered claim documents.
library StreamArtistAttributionClaimOperations {
    function file(
        D.CoordinatorContext memory x,
        address actor,
        uint256 id,
        bytes32 evidence,
        bytes32 reason,
        string memory uri
    ) public returns (bytes32 record) {
        if (id == 0 || !IStreamCoreCollectionView(x.suite.core).collectionExists(id)) {
            revert StreamArtistAttributionClaimTypes.InvalidAttributionClaim(id);
        }
        T.Snapshot[7] memory prior;
        prior[4] = IStreamArtistOwner(x.suite.owners[4]).ownerStateSnapshotV2();
        (PW.Evidence memory e, bytes32 ep) =
            StreamArtistPlatformEvidence.read(x.suite, id, evidence);
        (PW.Evidence memory r, bytes32 rp) = StreamArtistPlatformEvidence.read(x.suite, id, reason);
        if (
            e.claimRecordHash != 0 || r.claimRecordHash != 0 || e.proposedArtist != r.proposedArtist
        ) {
            revert PW.InvalidPlatformEvidence(evidence);
        }
        // No attribution-state, Artist signature, incumbent approval or arbiter-standing gate.
        record = IStreamArtistAttributionClaimsOwner(x.suite.owners[4])
            .fileAttributionClaim(
                T.ActionContext(10, actor, prior[4]), id, evidence, reason, uri, e.proposedArtist
            );
        T.Snapshot[7] memory after_;
        after_[4] = IStreamArtistOwner(x.suite.owners[4]).ownerStateSnapshotV2();
        bytes32 evidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(10),
                actor,
                record
            )
        );
        bytes memory payload = abi.encode(
            uint16(1),
            x.configurationHash,
            uint16(10),
            actor,
            record,
            prior,
            after_,
            abi.encode(id, evidence, reason, uri, e, r, ep, rp)
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(evidenceId, 1, payload);
        if (!appended || hash != keccak256(payload)) revert T.InvalidRecord();
    }
}
