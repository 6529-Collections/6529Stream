// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistMultipleDelegationHydrationTypes as MD
} from "../../interfaces/stream/artist/StreamArtistMultipleDelegationHydrationTypes.sol";
import {
    StreamArtistDelegationHydrationTypes as DH
} from "../../interfaces/stream/artist/IStreamArtistDelegationAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import "./StreamArtistReadinessHydrationFacts.sol";
import {
    StreamArtistReadinessHydrationTypes as RH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import "./StreamArtistEconomicsHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    StreamArtistRotationTypes as HydrationRotation
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import {
    StreamArtistPayoutHydrationTypes as PH
} from "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import "./StreamArtistHistoryOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

import "./StreamArtistHydrationPrepared.sol";
import "./StreamArtistHydrationSourceGuards.sol";

/// @notice Original all-owner apply, source recheck and single Archive append, in Coordinator context.
library StreamArtistHydrationCommit {
    event ArtistAuthorityHydrated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        uint256 indexed collectionId,
        address indexed predecessorRegistry,
        bytes32 profile,
        bytes32 commitment
    );

    function execute(
        D.CoordinatorContext memory x,
        address actor,
        AH.Request memory p,
        StreamArtistHydrationPrepared.Bundle memory h
    ) public returns (bytes32 value) {
        bytes32 profile = h.profile;
        address prior = h.prior;
        address sourceCoordinator = h.sourceCoordinator;
        T.SuiteConfiguration memory source = h.source;
        AH.Query memory q = h.q;
        AH.OwnerData[7] memory data = h.data;
        T.Snapshot[7] memory before_ = h.before_;
        value = keccak256(
            abi.encode(
                profile,
                block.chainid,
                x.suite.registry,
                address(this),
                prior,
                sourceCoordinator,
                p,
                q,
                data
            )
        );
        // Request fields are losslessly reconstructible from the fixed profile (index0),
        // source headers, query and each owner's original surface/scope list.
        bytes memory profileBytes =
            abi.encode(profile, prior, sourceCoordinator, p.expectedSource, q, data);
        // Original Archive has a finite SSTORE2 carrier. Reject an overlarge baseline
        // before mutation; larger profiles need a distinct paged evidence recipe.
        bytes memory sizeProbe = abi.encode(
            uint16(1), x.configurationHash, uint16(60), actor, value, before_, before_, profileBytes
        );
        if (
            sizeProbe.length
                > IStreamArtistArchiveV2(x.suite.archive).artistArchiveMaxEvidenceBytesV2()
        ) {
            revert T.BoundExceeded(
                sizeProbe.length,
                IStreamArtistArchiveV2(x.suite.archive).artistArchiveMaxEvidenceBytesV2()
            );
        }
        // No destination owner is called until the full profile has been independently collected.
        for (uint256 i; i < 7; ++i) {
            IStreamArtistAuthorityHydrationOwner(x.suite.owners[i])
                .applyArtistAuthorityHydration(
                    T.ActionContext(60, actor, before_[i]), q, data[i], value
                );
        }
        for (uint256 i; i < 7; ++i) {
            if (
                profile == MH.PROFILE || profile == DH.PROFILE || profile == MD.PROFILE
                    || profile == MR.PROFILE
            ) {
                StreamArtistHydrationSourceGuards._multipleHeader(
                    source.owners[i], p.expectedSource[i]
                );
            } else {
                StreamArtistHydrationSourceGuards._header(source.owners[i], p.expectedSource[i]);
            }
        }
        // Recheck the selected source graph after every mutation, before the one atomic Archive append.
        if (
            keccak256(abi.encode(source))
                != keccak256(
                    abi.encode(
                        IStreamArtistAuthorityHydrationCoordinator(sourceCoordinator)
                            .authorityHydrationSuite()
                    )
                )
        ) revert T.InvalidBinding();
        T.Snapshot[7] memory after_;
        for (uint256 i; i < 7; ++i) {
            after_[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
        }
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                uint16(60),
                actor,
                value
            )
        );
        bytes memory evidence = abi.encode(
            uint16(1), x.configurationHash, uint16(60), actor, value, before_, after_, profileBytes
        );
        (bytes32 hash,, bool added) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!added || hash != keccak256(evidence)) revert T.InvalidRecord();
        emit ArtistAuthorityHydrated(1, p.artistId, p.collectionId, prior, profile, value);
    }
}
