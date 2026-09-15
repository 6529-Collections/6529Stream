// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistReadinessHydrationFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
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

/// @notice Collects the complete immutable source profile before any destination mutation.
library StreamArtistHydrationSource {
    bytes32 private constant PROFILE = keccak256("6529STREAM_ARTIST_LIVING_BASELINE_HYDRATION_V1");
    bytes32 private constant PAYOUT_PROFILE =
        keccak256("6529STREAM_ARTIST_LIVING_PAYOUT_HYDRATION_V1");
    bytes32 private constant ECONOMICS_PROFILE =
        keccak256("6529STREAM_ARTIST_LIVING_ECONOMICS_HYDRATION_V1");
    bytes32 private constant READINESS_PROFILE =
        keccak256("6529STREAM_ARTIST_LIVING_READINESS_HYDRATION_V1");
    bytes32 private constant CHECKPOINT = keccak256("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1");

    function prepare(
        D.CoordinatorContext memory x,
        AH.Request memory p,
        bool includePayout,
        T.EconomicsConsent[] memory economics,
        RH.AttestationInput[] memory attestations
    ) public view returns (StreamArtistHydrationPrepared.Bundle memory) {
        return _prepare(x, p, includePayout, economics, attestations, false);
    }

    function prepareWithPublications(
        D.CoordinatorContext memory x,
        AH.Request memory p,
        T.EconomicsConsent[] memory economics,
        RH.AttestationInput[] memory attestations
    ) public view returns (StreamArtistHydrationPrepared.Bundle memory) {
        return _prepare(x, p, true, economics, attestations, true);
    }

    function _prepare(
        D.CoordinatorContext memory x,
        AH.Request memory p,
        bool includePayout,
        T.EconomicsConsent[] memory economics,
        RH.AttestationInput[] memory attestations,
        bool publications
    ) private view returns (StreamArtistHydrationPrepared.Bundle memory) {
        bool readiness = attestations.length != 0;
        bytes32 profile = publications
            ? keccak256("6529STREAM_ARTIST_LIVING_PUBLICATION_HYDRATION_V1")
            : readiness
                ? READINESS_PROFILE
                : economics.length != 0
                    ? ECONOMICS_PROFILE
                    : includePayout ? PAYOUT_PROFILE : PROFILE;
        if (
            p.artistId == 0 || p.collectionId == 0 || p.bindingIndex != 0 || p.policies.length > 128
        ) revert T.UnsupportedProfile();
        IStreamArtistHistory history = IStreamArtistHistory(x.suite.owners[2]);
        if (history.importedHistoryBindingCount() != 1) revert T.InvalidBinding();
        (address prior,,,) = history.importedHistoryBinding(0);
        (, bytes32 pin,) = history.artistHistoryPredecessorBinding(prior);
        StreamArtistHistoryProof.predecessor(
            x.suite.core,
            x.suite.registry,
            prior,
            pin,
            StreamArtistHistoryProof.cap(x.suite.registry)
        );
        (bool sourceSealed, address successor,) =
            IStreamArtistHistory(prior).artistRegistryCutover();
        if (
            !sourceSealed || successor != x.suite.registry
                || IStreamArtistHistory(prior).importedHistoryBindingCount() != 0
        ) revert T.InvalidBinding();
        StreamArtistHydrationSourceGuards._lane(history, prior, 1, p.artistId);
        StreamArtistHydrationSourceGuards._lane(history, prior, 2, bytes32(p.collectionId));
        address sourceCoordinator = IStreamArtistIngressBinding(prior).operationCoordinator();
        T.SuiteConfiguration memory source =
            IStreamArtistAuthorityHydrationCoordinator(sourceCoordinator).authorityHydrationSuite();
        StreamArtistHydrationSourceGuards._suite(x.suite, source, prior, sourceCoordinator);
        AH.Query memory q;
        q.artistId = p.artistId;
        q.collectionId = p.collectionId;
        q.policies = p.policies;
        AH.OwnerData[7] memory data;
        T.Snapshot[7] memory before_;
        uint256 total;
        uint256 revocations;
        uint256 payoutCount;
        uint256 contentCount;
        for (uint256 i; i < 7; ++i) {
            before_[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
            if (
                before_[i].revision != (i == 2 ? 3 : 0)
                    || IStreamArtistNativeReceipts(x.suite.owners[i]).artistNativeReceiptCount()
                        != 0
                    || IStreamArtistAuthorityHydrationOwner(x.suite.owners[i])
                            .authorityHydrationCommitment() != 0
            ) revert T.InvalidRecord();
            StreamArtistHydrationSourceGuards._header(source.owners[i], p.expectedSource[i]);
            uint256 count = IStreamArtistNativeReceipts(source.owners[i]).artistNativeReceiptCount();
            if (count > 128) revert T.UnsupportedProfile();
            total += count;
            if (i == 0) {
                if (count != 1) revert T.UnsupportedProfile();
                q.bindingHash =
                IStreamArtistNativeReceipts(source.owners[i]).artistNativeReceiptAt(0).recordHash;
            } else if (i == 2) {
                if (count == 0) revert T.UnsupportedProfile();
                revocations = count - 1;
            } else if (i == 3) {
                if (count != 1) revert T.UnsupportedProfile();
            } else if (i == 4 && readiness) {
                if (count != attestations.length) revert T.InvalidRecord();
            } else if (i == 5 && includePayout) {
                if (count == 0) revert T.UnsupportedProfile();
                payoutCount = count;
            } else if (i == 6) {
                if (readiness) {
                    if (count <= p.policies.length + economics.length) revert T.InvalidRecord();
                    contentCount = count - p.policies.length - economics.length;
                } else if (count != p.policies.length + economics.length) {
                    revert T.InvalidRecord();
                }
            } else if (count != 0) {
                revert T.UnsupportedProfile();
            }
        }
        q.records = new bytes32[](total);
        uint256 used;
        uint256 artistCount;
        uint256 collectionCount;
        for (uint256 i; i < 7; ++i) {
            uint256 count = IStreamArtistNativeReceipts(source.owners[i]).artistNativeReceiptCount();
            for (uint256 j; j < count; ++j) {
                H.Receipt memory r =
                    IStreamArtistNativeReceipts(source.owners[i]).artistNativeReceiptAt(j);
                uint16 op = i == 0 ? 1 : i == 2 ? (j == 0 ? 1 : 54) : i == 3 ? 2 : i == 5 ? 18 : 14;
                if (i == 6 && economics.length != 0 && r.operation == 15) op = 15;
                if (readiness && i == 4) op = 24;
                if (readiness && i == 6 && (r.operation == 52 || r.operation == 17)) {
                    op = r.operation;
                }
                if (
                    r.operation != op || r.artistId != p.artistId
                        || r.collectionId != (i == 2 || i == 5 ? 0 : p.collectionId)
                        || r.recordHash == 0 || (i == 2 && j == 0 && r.recordHash != p.artistId)
                ) revert T.UnsupportedProfile();
                q.records[used++] = r.recordHash;
                ++artistCount;
                if (r.collectionId != 0) ++collectionCount;
            }
            uint64 expectedRevision = i == 0
                ? 2
                : i == 2
                    ? uint64(
                        3 + p.policies.length + economics.length + revocations + payoutCount
                            + contentCount + attestations.length
                    )
                    : i == 3
                        ? 1
                        : i == 4
                            ? uint64(2 + attestations.length)
                            : i == 5
                                ? uint64(payoutCount)
                                : i == 6
                                    ? uint64(p.policies.length + economics.length + contentCount)
                                    : 0;
            if (p.expectedSource[i].ownerState.revision != expectedRevision) {
                revert T.UnsupportedProfile();
            }
        }
        for (uint256 i; i < 7; ++i) {
            data[i] = StreamArtistHydrationSourceGuards._guards(source, sourceCoordinator, i, p);
            data[i].typedState = publications && i == 4
                ? IStreamArtistPublicationHydrationOwner(source.owners[i])
                    .authorityPublicationHydrationState(q, attestations)
                : readiness && i == 4
                    ? IStreamArtistReadinessAttributionOwner(source.owners[i])
                        .authorityAttestationHydrationState(q, attestations)
                    : readiness && i == 6
                        ? IStreamArtistReadinessConsentOwner(source.owners[i])
                            .authorityReadinessHydrationState(q, economics)
                        : i == 6 && economics.length != 0
                            ? IStreamArtistEconomicsAuthorityHydrationOwner(source.owners[i])
                                .authorityEconomicsHydrationState(q, economics)
                            : IStreamArtistAuthorityHydrationOwner(source.owners[i])
                                .authorityHydrationState(q);
        }
        (, uint64 ac) = IStreamArtistHistory(prior).artistHistoryLane(1, p.artistId);
        (, uint64 cc) = IStreamArtistHistory(prior).artistHistoryLane(2, bytes32(p.collectionId));
        if (ac != artistCount || cc != collectionCount) revert T.InvalidRecord();
        return StreamArtistHydrationPrepared.Bundle(
            profile, prior, sourceCoordinator, source, q, data, before_
        );
    }
}
