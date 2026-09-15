// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistHydrationSource.sol";
import "./StreamArtistHydrationRecordFacts.sol";
import "./StreamArtistHydrationCommit.sol";
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

/// @notice Operation60: complete sealed-source baseline, then seven atomic owner commits.
/// @dev Current cells authenticate against a fixed owner's complete inventory; rolling roots
///      are source history commitments, not recomputed from current cells.
library StreamArtistAuthorityHydrationOperations {
    // Original library ABI entries; the fixed workers preserve these reverts.
    error BoundExceeded(uint256 actual, uint256 maximum);
    error InvalidBinding();
    error InvalidRecord();
    bytes32 private constant PROFILE = keccak256("6529STREAM_ARTIST_LIVING_BASELINE_HYDRATION_V1");
    bytes32 private constant PAYOUT_PROFILE =
        keccak256("6529STREAM_ARTIST_LIVING_PAYOUT_HYDRATION_V1");
    bytes32 private constant ECONOMICS_PROFILE =
        keccak256("6529STREAM_ARTIST_LIVING_ECONOMICS_HYDRATION_V1");
    bytes32 private constant READINESS_PROFILE =
        keccak256("6529STREAM_ARTIST_LIVING_READINESS_HYDRATION_V1");
    bytes32 private constant CHECKPOINT = keccak256("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1");
    event ArtistAuthorityHydrated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        uint256 indexed collectionId,
        address indexed predecessorRegistry,
        bytes32 profile,
        bytes32 commitment
    );

    function hydrate(D.CoordinatorContext memory x, address actor, AH.Request memory p)
        public
        returns (bytes32 value)
    {
        return _hydrate(
            x, actor, p, false, new T.EconomicsConsent[](0), new RH.AttestationInput[](0)
        );
    }

    function hydrateWithPayout(D.CoordinatorContext memory x, address actor, AH.Request memory p)
        public
        returns (bytes32)
    {
        return
            _hydrate(x, actor, p, true, new T.EconomicsConsent[](0), new RH.AttestationInput[](0));
    }

    function hydrateWithEconomics(D.CoordinatorContext memory x, address actor, EH.Request memory p)
        public
        returns (bytes32)
    {
        if (p.economics.length == 0 || p.economics.length > 128) revert T.UnsupportedProfile();
        return _hydrate(x, actor, p.authority, true, p.economics, new RH.AttestationInput[](0));
    }

    function hydrateWithReadiness(D.CoordinatorContext memory x, address actor, RH.Request memory p)
        public
        returns (bytes32)
    {
        if (
            p.attestations.length == 0 || p.attestations.length > 128
                || p.economics.economics.length == 0 || p.economics.economics.length > 128
        ) revert T.UnsupportedProfile();
        return
            _hydrate(x, actor, p.economics.authority, true, p.economics.economics, p.attestations);
    }

    function _hydrate(
        D.CoordinatorContext memory x,
        address actor,
        AH.Request memory p,
        bool includePayout,
        T.EconomicsConsent[] memory economics,
        RH.AttestationInput[] memory attestations
    ) private returns (bytes32 value) {
        StreamArtistHydrationPrepared.Bundle memory h =
            StreamArtistHydrationSource.prepare(x, p, includePayout, economics, attestations);
        StreamArtistHydrationRecordFacts.check(
            h.q, h.data, h.source, includePayout, economics, attestations
        );
        return StreamArtistHydrationCommit.execute(x, actor, p, h);
    }
}
