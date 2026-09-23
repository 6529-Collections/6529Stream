// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import "./StreamArtistGovernanceWitness.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import "../../interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import "../../interfaces/stream/governance/IStreamGovernanceReads.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";

/// @notice Fixed operation-33 recipe in the authenticated, locked Coordinator context.
library StreamArtistIdentityContestOperations {
    // Preserve the published ABI of errors propagated from the shared witness.
    error InvalidContestGovernance();
    error Unauthorized(address caller);

    function file(D.CoordinatorContext memory x, address actor, Contest.Request memory p)
        public
        returns (bytes32 record)
    {
        IStreamArtistIdentityContestOwner owner =
            IStreamArtistIdentityContestOwner(x.suite.owners[2]);
        T.Snapshot[7] memory before_;
        before_[2] = IStreamArtistOwner(address(owner)).ownerStateSnapshotV2();
        Contest.GovernanceWitness memory governance;
        if (actor == owner.artistWindowAuthority()) {
            governance = _governance(x, actor, p, owner);
        }
        record = owner.contestIdentity(T.ActionContext(33, actor, before_[2]), p, governance);
        T.Snapshot[7] memory after_;
        after_[2] = IStreamArtistOwner(address(owner)).ownerStateSnapshotV2();
        bytes memory payload = abi.encode(
            p,
            governance,
            owner.identityContestRecord(record),
            IStreamArtistSuccessionOwner(address(owner)).operativeSuccessorRecord(p.artistId),
            IStreamArtistIdentityDismissalOwner(address(owner))
                .currentIdentityContestCause(p.artistId)
        );
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(33),
                actor,
                record
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, uint16(33), actor, record, before_, after_, payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }

    function _governance(
        D.CoordinatorContext memory x,
        address authority,
        Contest.Request memory p,
        IStreamArtistIdentityContestOwner owner
    ) private view returns (Contest.GovernanceWitness memory) {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = owner.identityContestContext(p);
        return
            StreamArtistGovernanceWitness.read(x, authority, p.reasonHash, scope, oldHash, newHash);
    }
}
