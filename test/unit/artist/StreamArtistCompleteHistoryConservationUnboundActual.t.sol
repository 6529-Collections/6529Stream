// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistUnboundPlatformFixture.sol";
import {
    StreamArtistCompleteHistoryConservation as CHConservation
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryConservation.sol";
import {
    StreamArtistCompleteHistorySource as CHSource
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistorySource.sol";
import {
    StreamArtistCompleteHistoryScope as CHScope
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistCompleteHistoryDisputeSource as CHDisputes
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryDisputeSource.sol";
import {
    StreamArtistCompleteHistoryAttestationSource as CHAttestations
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAttestationSource.sol";
import {
    StreamArtistRecoveredHydrationSource as CHProvenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationSource.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as CHClocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as CHG
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as CHRecords
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as CHReadiness
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";

/// @notice Actual Platform producers retain state0/generation0 until a real binding is proposed.
/// @dev Source collectors read the true empty bound families; inherited Core/governance
/// boundaries remain explicit. This proves conservation input behavior, not operation60 apply.
contract StreamArtistCompleteHistoryConservationUnboundActualTest is ArtistUnboundPlatformFixture {
    function testCompleteConservationGenuineUnboundDeclarationAndApprovedCorrectionRemainEmpty()
        external
    {
        _upSource(false);
        _checkEmptySources();
        bytes32 claim = _hpClaim(false);
        _hpClaim(true);
        _hpContest(1, claim, false);
        _hpContest(3, claim, false);
        _hpContest(3, claim, true);
        _checkEmptySources();
        PW.State memory platform = IStreamArtistPlatformOwner(suite.owners[4]).platformWorksState(1);
        require(
            platform.correction.recordHash != 0 && platform.correction.correctiveGeneration == 0,
            "actual approved-unused correction"
        );
    }

    function _checkEmptySources() private view {
        (uint8 state, uint64 generation) = Attribution(suite.owners[4]).attributionState(1);
        require(state == 0 && generation == 0, "actual bound Attribution remains empty");
        RH.Request memory request = _upRequest();
        RH.Provenance memory provenance = CHProvenance.collect(
            suite, address(coordinator), request.records.authority.replayOrigins
        );
        CHConservation.Context memory x;
        T.Binding[] memory heads = new T.Binding[](1);
        heads[0] = Binding(suite.owners[0]).binding(1);
        x.scope = CHScope.partition(request.records.authority, heads, provenance);
        CHClocks.Result memory clocks;
        (x.inventory, clocks) = CHSource.collect(x.scope, provenance);
        x.histories = CHDisputes.collect(
            suite.owners[4], x.scope, provenance, x.inventory.bindings, x.inventory.archive, clocks
        );
        CHReadiness.AttestationInput[][] memory inputs = new CHReadiness.AttestationInput[][](1);
        x.attestations =
            CHAttestations.collect(suite.owners[4], x.scope, x.inventory, clocks, inputs);
        x.consents = new CHG.Consents[](1);
        x.consents[0].rows.original.collectionId = 1;
        x.consents[0].rows.original.provenance =
            RH.ownerProvenanceHash(RH.ownerProvenance(provenance, 6), 6);
        CHRecords.Bundle memory records = abi.decode(x.attestations[0], (CHRecords.Bundle));
        require(
            x.scope.artists.length == 0 && provenance.journals[2].length == 0
                && provenance.journals[6].length == 0 && x.histories[0].current.state == 0
                && x.histories[0].current.generation == 0 && records.item.state == 0
                && records.item.generation == 0,
            "authentic empty Identity, Consent and bound Attribution families"
        );
        CHConservation.validate(x);
    }
}
