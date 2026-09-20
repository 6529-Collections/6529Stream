// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredExternalGuards as External
} from "./StreamArtistRecoveredExternalGuards.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "./StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner,
    IStreamArtistAuthorityHydrationCoordinator
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM,
    IStreamArtistRecoveredTimingInventory
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import { IStreamArtistArchiveV2 } from "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationEvidence as Evidence
} from "./StreamArtistRecoveredHydrationEvidence.sol";
import {
    StreamArtistRecoveredHydrationCommitEncoding as Encoding
} from "./StreamArtistRecoveredHydrationCommitEncoding.sol";

/// @notice Atomic seven-owner recovered authority import and lossless paged operation60 evidence.
/// @dev Only called after the fixed profile collector has authenticated every typed bundle.
library StreamArtistRecoveredHydrationCommit {
    struct Prepared {
        Admission.Certificate admission;
        AH.Query query;
        AH.OwnerData[7] data;
        TM.Checkpoint timing;
        External.Snapshot externalGuards;
    }

    event RecoveredArtistAuthorityHydrated(
        uint16 schemaVersion,
        address indexed predecessorRegistry,
        bytes32 indexed commitment,
        bytes32 indexed semanticInventory,
        bytes32 evidencePayloadHash
    );

    function execute(
        T.SuiteConfiguration memory destination,
        bytes32 configurationHash,
        address actor,
        RH.Request memory request,
        Prepared memory prepared
    ) public returns (bytes32 value) {
        // The actual Coordinator supplies its original tagged deployment configuration hash.
        // It is deliberately not the plain suite hash used by provenance origin tables.
        if (actor == address(0) || configurationHash == 0) {
            revert T.InvalidBinding();
        }
        Admission.Certificate memory c = prepared.admission;
        bytes memory profileBytes;
        Evidence.Descriptor memory descriptor;
        bytes memory carrier;
        bytes memory probe;
        (value, profileBytes, descriptor, carrier, probe) = Encoding.prepare(
            block.chainid,
            destination.registry,
            address(this),
            configurationHash,
            actor,
            request,
            Encoding.Inputs(
                c.prior,
                c.sourceCoordinator,
                c.artists,
                c.collections,
                prepared.query,
                prepared.data,
                prepared.timing,
                prepared.externalGuards,
                c.before_
            )
        );
        IStreamArtistArchiveV2 archive = IStreamArtistArchiveV2(destination.archive);
        if (probe.length > archive.artistArchiveMaxEvidenceBytesV2()) {
            revert T.BoundExceeded(probe.length, archive.artistArchiveMaxEvidenceBytesV2());
        }
        for (uint8 i; i < 7; ++i) {
            IStreamArtistAuthorityHydrationOwner(destination.owners[i])
                .applyArtistAuthorityHydration(
                    T.ActionContext(60, actor, c.before_[i]),
                    prepared.query,
                    prepared.data[i],
                    value
                );
        }
        // Exact immutable prefix, native suffix, key/cell inventory and all source checkpoints
        // are checked again after writes. Separate timing mutations have their own checkpoint.
        Provenance.validateSource(c.provenance, c.sourceCoordinator);
        External.requireCurrent(prepared.externalGuards);
        for (uint8 i; i < 7; ++i) {
            (, Payload.Payload memory payload) = Payload.decode(prepared.data[i].typedState, i);
            Publications.requireSource(c.source.owners[i], i, payload.publications);
        }
        if (
            keccak256(abi.encode(c.source))
                    != keccak256(
                        abi.encode(
                            IStreamArtistAuthorityHydrationCoordinator(c.sourceCoordinator)
                                .authorityHydrationSuite()
                        )
                    )
                || keccak256(abi.encode(prepared.timing))
                    != keccak256(
                        abi.encode(
                            IStreamArtistRecoveredTimingInventory(c.source.owners[2])
                                .recoveredTimingCheckpoint()
                        )
                    )
        ) revert RH.InvalidRecoveredHydrationProvenance();
        T.Snapshot[7] memory after_;
        for (uint8 i; i < 7; ++i) {
            after_[i] = IStreamArtistOwner(destination.owners[i]).ownerStateSnapshotV2();
            if (
                after_[i].domainId != c.before_[i].domainId
                    || after_[i].revision != c.before_[i].revision + 1
                    || after_[i].recordChainTip != c.before_[i].recordChainTip
                    || IStreamArtistAuthorityHydrationOwner(destination.owners[i])
                            .authorityHydrationCommitment() != value
            ) revert RH.InvalidRecoveredHydrationProvenance();
        }
        Evidence.Descriptor memory appended =
            Evidence.append(destination.archive, destination.registry, value, profileBytes);
        if (keccak256(abi.encode(appended)) != keccak256(abi.encode(descriptor))) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        (bytes32 id, bytes memory evidence) = Encoding.evidence(
            block.chainid,
            destination.registry,
            address(this),
            configurationHash,
            actor,
            value,
            c.before_,
            after_,
            carrier
        );
        (bytes32 hash,, bool added) = archive.appendArtistEvidenceV2(id, 1, evidence);
        if (!added || hash != keccak256(evidence)) revert T.InvalidRecord();
        emit RecoveredArtistAuthorityHydrated(
            RH.VERSION, c.prior, value, request.expectedSemanticInventory, descriptor.payloadHash
        );
    }
}
