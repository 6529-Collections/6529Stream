// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistUnboundPlatformFixture.sol";
import {
    StreamArtistCompleteHistoryComposition as CHComposition
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryComposition.sol";
import {
    StreamArtistCompleteHistoryPreparationPrincipals as CHPrincipals
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryPreparationPrincipals.sol";
import {
    StreamArtistCompleteHistoryWitnesses as CHWitnesses
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryWitnesses.sol";
import {
    StreamArtistCompleteHistoryAdmission as CHAdmission
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAdmission.sol";
import {
    StreamArtistRecoveredHydrationAdmission as CHAdmissionType
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistCompleteHistoryTypes as CHType
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as CHMD
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeTypes.sol";

/// @notice Genuine original allegation10 and governed lane admission with no declaration or Artist.
/// @dev Authored full source-composition case; execution awaits the combined native cohort.
contract StreamArtistCompleteHistoryCompositionEmptyActualTest is ArtistUnboundPlatformFixture {
    function testCompleteCompositionActualAllUnboundAllegationWithoutDeclaration() external {
        bytes32 claim = _hpClaim(true);
        require(
            ingress.platformWorksState(upCollection).declaration.recordHash == 0,
            "no original declaration"
        );
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        Successor memory next = _upCutover();
        RH.Request memory request = _upRequest();
        CHAdmissionType.Certificate memory c =
            CHAdmission.collect(next.coordinator.suiteConfiguration(), request);
        CHPrincipals.Result memory principals = CHPrincipals.collect(c);
        M.State memory scope;
        scope.artists = c.artists;
        scope.collections = c.collections;
        CHWitnesses.Plan memory witnesses = CHWitnesses.collect(
            c.source, c.provenance, scope, request.records.witnesses, new T.RoyaltyFreeze[](0)
        );
        CHComposition.Result memory result = CHComposition.collect(
            CHComposition.Context(c, principals.principals, witnesses, principals.features)
        );
        require(
            c.artists.length == 0 && principals.principals.identities.length == 0
                && principals.principals.payouts.length == 0,
            "genuinely empty principal union"
        );
        require(
            principals.emptyIdentity.length != 0 && result.inventory.accounts.length == 0,
            "authentic empty certificate and nonce union"
        );
        require(
            result.inventory.bindings.generations[0].length == 0
                && result.inventory.accepted[0].rows.length == 0,
            "no invented binding generation or acceptance"
        );
        require(
            result.inventory.platforms[0].allegations.length == 1
                && result.inventory.platforms[0].allegations[0].record.recordHash == claim,
            "original allegation retained"
        );
        CHMD.Attribution memory row = abi.decode(result.attribution[0], (CHMD.Attribution));
        require(
            row.history.generations.length == 0 && row.history.current.generation == 0
                && row.history.current.state == 0 && row.records.records.length == 0,
            "all empty bound-family rows remain explicit"
        );
        require(
            result.features == (CHType.FEATURE | RH.HISTORY_PLATFORM),
            "only actual source family features"
        );
    }
}
