// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistPrimaryCollaboratorFixture.sol";
import {
    StreamArtistRecoveredHydrationSource as CHProvenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationSource.sol";
import {
    StreamArtistCompleteHistoryCatalogue as CHCatalogue
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistCompleteHistoryBindingSource as CHBindings
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryBindingSource.sol";
import {
    StreamArtistCompleteHistoryBindingProof as CHBindingProof
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryBindingProof.sol";
import {
    StreamArtistCompleteHistoryCollaborators as CHCollaborators
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCollaborators.sol";
import {
    StreamArtistCompleteHistoryClocks as CHClocks
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryClocks.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as PCClocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistCompleteHistoryAcceptance as CHAcceptance
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAcceptance.sol";
import {
    StreamArtistCompleteHistoryPlatformSource as CHPlatform
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryPlatformSource.sol";
import {
    StreamArtistRecoveredPlatformTypes as CHP
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as CHA
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as CHH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";

/// @notice Real original owners, Archive and threshold Safes produce each latest head.
/// @dev These source-family scenarios retain inherited Core/governance unit boundaries.
/// They do not claim operation60 integration or execution until the combined suite runs.
abstract contract ArtistCompleteHistoryChronologyFixture is ArtistPrimaryCollaboratorFixture {
    struct Observed {
        M.State scope;
        RH.Provenance provenance;
        PC.BindingInventory bindings;
        PC.Inventory archive;
        CHP.Platform[] platforms;
        PCClocks.Result clocks;
        CHA.AcceptanceBundle[] accepted;
    }

    function _pendingSource(uint8 mode) internal {
        _pcIdentity();
        C.BindingAcceptance memory row = _pcPropose();
        if (mode == 1 || mode == 4) _pcPrimaryAccept();
        if (mode == 2 || mode == 3) _pcAccept(row, false);
        if (mode == 3) _pcRefuse();
        if (mode == 4) {
            T.Binding memory b = Binding(suite.owners[0]).binding(2);
            ingress.withdrawArtistBinding(
                L.Termination(
                    2,
                    b.generation,
                    b.bindingHash,
                    keccak256("original latest withdrawal"),
                    "urn:complete-history:withdrawal"
                )
            );
            _rhCandidate(
                0,
                "binding_lifecycle.replay.proposal_terminal_transition_key",
                keccak256(abi.encode(uint256(2), b.generation))
            );
        }
        _rhBaseline();
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(rhRecovery).postWindowEndsAt);
        multiRecovery = [rhRecovery, rhRecovery];
        multiCollectionArtists = [artistId, artistId];
        multiArtists = new bytes32[](2);
        multiArtists[0] = artistId < collaboratorId ? artistId : collaboratorId;
        multiArtists[1] = artistId < collaboratorId ? collaboratorId : artistId;
    }

    function _observe() internal view returns (Observed memory x) {
        RH.Request memory r = _rhRequest();
        x.provenance =
            CHProvenance.collect(suite, address(coordinator), r.records.authority.replayOrigins);
        x.scope.artists = new AH.Query[](multiArtists.length);
        for (uint256 i; i < multiArtists.length; ++i) {
            x.scope.artists[i].artistId = multiArtists[i];
        }
        x.scope.collections = new AH.Query[](2);
        for (uint256 k; k < 2; ++k) {
            T.Binding memory b = Binding(suite.owners[0]).binding(k + 1);
            x.scope.collections[k].collectionId = k + 1;
            x.scope.collections[k].artistId = b.artistId;
            x.scope.collections[k].bindingHash = b.bindingHash;
        }
        x.bindings =
            CHBindings.collect(suite.owners[0], x.scope, RH.ownerProvenance(x.provenance, 0));
        (x.archive.catalogues, x.archive.operations) = CHCatalogue.collect(x.provenance);
        x.archive =
            CHCollaborators.collect(x.provenance, x.archive.catalogues, x.archive.operations);
        x.platforms = CHPlatform.collect(
            suite.owners[4],
            x.scope,
            RH.ownerProvenance(x.provenance, 4),
            x.archive.catalogues,
            x.archive.operations
        );
        x.clocks = CHClocks.validate(x.scope, x.provenance, x.bindings, x.archive, x.platforms);
        CHBindingProof.validate(
            x.scope, RH.ownerProvenance(x.provenance, 0), x.bindings, x.archive, x.clocks
        );
        x.accepted = CHAcceptance.collect(
            suite.owners[3], x.scope, x.provenance, x.bindings, x.archive, x.clocks
        );
    }
}
