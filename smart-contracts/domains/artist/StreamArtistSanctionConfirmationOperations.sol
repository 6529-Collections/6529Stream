// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSanctionConfirmationReads.sol";
import "../../interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";

/// @notice Permissionless consumption of the original registry's immutable executed history.
library StreamArtistSanctionConfirmationOperations {
    function confirm(
        D.CoordinatorContext memory x,
        StreamArtistSanctionConfirmationReads.Pins memory pins,
        address actor,
        uint256 collectionId
    ) public {
        T.Snapshot[7] memory prior = _snapshots(x.suite);
        Confirmation.Observation memory first =
            StreamArtistSanctionConfirmationReads.observe(x.suite, pins, collectionId);
        Confirmation.Observation memory second =
            StreamArtistSanctionConfirmationReads.observe(x.suite, pins, collectionId);
        if (
            keccak256(abi.encode(first)) != keccak256(abi.encode(second))
                || keccak256(abi.encode(prior)) != keccak256(abi.encode(_snapshots(x.suite)))
        ) revert Confirmation.InvalidSanctionConfirmation();
        Confirmation.Transition memory p = Confirmation.Transition(
            collectionId,
            first.binding_.artistId,
            first.binding_.generation,
            first.sanction.recordHash,
            first.finalityRecord.finalityRecordHash,
            first.priorAttributionState
        );
        bytes32 replayKey = IStreamArtistConsentConfirmationOwner(x.suite.owners[6])
            .consumeSanctionFinalization(T.ActionContext(13, actor, prior[6]), first.binding_, p);
        IStreamArtistAttributionConfirmationOwner(x.suite.owners[4])
            .confirmSanctionFinalized(
                T.ActionContext(13, actor, prior[4]),
                first.binding_,
                p,
                first.sanction.signer,
                first.sanction.authorityClass
            );
        _archive(x, pins, actor, prior, first, p, replayKey);
    }

    function _archive(
        D.CoordinatorContext memory x,
        StreamArtistSanctionConfirmationReads.Pins memory pins,
        address actor,
        T.Snapshot[7] memory prior,
        Confirmation.Observation memory o,
        Confirmation.Transition memory p,
        bytes32 replayKey
    ) private {
        StreamCollectionFinalityRecord memory r = o.finalityRecord;
        Confirmation.FinalityRecordEvidence memory record = Confirmation.FinalityRecordEvidence(
            r.finalityRecordHash,
            r.manifestContentHash,
            r.manifestURIHash,
            r.componentsHash,
            r.manifestPointer,
            r.finalizedAt,
            keccak256(abi.encode(r))
        );
        bytes memory payload = abi.encode(
            o.binding_,
            p,
            o.sanction,
            pins.finalityRegistry,
            pins.finalityCodeHash,
            record,
            o.components,
            o.executionWitness,
            o.archiveWitness,
            o.rawReadHash,
            replayKey
        );
        _append(x, actor, prior, Confirmation.scope(p), payload);
    }

    function _append(
        D.CoordinatorContext memory x,
        address actor,
        T.Snapshot[7] memory prior,
        bytes32 transitionHash,
        bytes memory payload
    ) private {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(13),
                actor,
                transitionHash
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1),
            x.configurationHash,
            uint16(13),
            actor,
            transitionHash,
            prior,
            _snapshots(x.suite),
            payload
        );
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }

    function _snapshots(T.SuiteConfiguration memory suite)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        for (uint256 i; i < 7; ++i) {
            if ((uint256(0x51) & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }
}
