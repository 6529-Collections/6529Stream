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
import "./StreamArtistHydrationSourceState.sol";
import "./StreamArtistHydrationSourceInventory.sol";
import "./StreamArtistHydrationSourceGuards.sol";
import "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";
import {
    StreamArtistEntropyFindingHydrationTypes as FH
} from "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";

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
        return _prepare(x, p, includePayout, economics, attestations, false, false);
    }

    function prepareWithPublications(
        D.CoordinatorContext memory x,
        AH.Request memory p,
        T.EconomicsConsent[] memory economics,
        RH.AttestationInput[] memory attestations
    ) public view returns (StreamArtistHydrationPrepared.Bundle memory) {
        return _prepare(x, p, true, economics, attestations, true, false);
    }

    function prepareWithEntropyFindings(D.CoordinatorContext memory x, FH.Request memory p)
        public
        view
        returns (StreamArtistHydrationPrepared.Bundle memory)
    {
        return _prepare(
            x, p.authority, p.includePayout, p.economics, p.attestations, p.publications, true
        );
    }

    function _prepare(
        D.CoordinatorContext memory x,
        AH.Request memory p,
        bool includePayout,
        T.EconomicsConsent[] memory economics,
        RH.AttestationInput[] memory attestations,
        bool publications,
        bool findings
    ) private view returns (StreamArtistHydrationPrepared.Bundle memory) {
        bool readiness = attestations.length != 0;
        bytes32 profile = findings
            ? FH.PROFILE
            : publications
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
        (
            AH.Query memory q,
            T.Snapshot[7] memory before_,
            uint256 artistCount,
            uint256 collectionCount
        ) = StreamArtistHydrationSourceInventory.collect(
            x.suite, source, p, includePayout, economics.length, attestations.length, findings
        );
        AH.OwnerData[7] memory data;
        data = StreamArtistHydrationSourceState.collect(
            source, sourceCoordinator, p, q, economics, attestations, publications, findings
        );
        (, uint64 ac) = IStreamArtistHistory(prior).artistHistoryLane(1, p.artistId);
        (, uint64 cc) = IStreamArtistHistory(prior).artistHistoryLane(2, bytes32(p.collectionId));
        if (ac != artistCount || cc != collectionCount) revert T.InvalidRecord();
        return StreamArtistHydrationPrepared.Bundle(
            profile, prior, sourceCoordinator, source, q, data, before_
        );
    }
}
