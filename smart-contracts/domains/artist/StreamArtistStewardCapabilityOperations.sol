// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistStewardGrantWitness.sol";
import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";

/// @notice Additive operation59 in the same immutable Coordinator/owner/Archive model.
library StreamArtistStewardCapabilityOperations {
    function grant(D.CoordinatorContext memory x, address actor, SC.Grant memory p)
        public
        returns (bytes32 record)
    {
        IStreamArtistStewardCapabilitiesOwner owner =
            IStreamArtistStewardCapabilitiesOwner(x.suite.owners[2]);
        address executor = IStreamArtistIdentityContestOwner(address(owner)).artistWindowAuthority();
        if (actor != executor) revert T.Unauthorized(actor);
        T.Snapshot[7] memory before_;
        before_[2] = IStreamArtistOwner(address(owner)).ownerStateSnapshotV2();
        SC.Context memory context = owner.stewardCapabilityGrantContext(p);
        SC.Witness memory witness =
            StreamArtistStewardGrantWitness.read(executor, x.suite.registry, p, context);
        record = owner.grantStewardCapabilities(T.ActionContext(59, actor, before_[2]), p, witness);
        SC.Record memory saved = owner.stewardCapabilityGrantRecord(record);
        T.Snapshot[7] memory after_;
        after_[2] = IStreamArtistOwner(address(owner)).ownerStateSnapshotV2();
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(59),
                actor,
                record
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1),
            x.configurationHash,
            uint16(59),
            actor,
            record,
            before_,
            after_,
            abi.encode(p, context, witness, saved)
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(key, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
