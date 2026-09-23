// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistCompleteHistorySanctionCurrent as Current
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistorySanctionCurrent.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import { StreamArtistRecoveredBindingGenerations as BG } from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";

interface CompleteHistorySanctionVm {
    function expectRevert(bytes4) external;
}

/// @notice Isolated chronology vectors; original Archive/source authentication is a caller prerequisite.
contract StreamArtistCompleteHistorySanctionCurrentTest {
    CompleteHistorySanctionVm private constant vm =
        CompleteHistorySanctionVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Fixture {
        H.Inventory inventory;
        D.Bundle[] histories;
        PC.BindingInventory bindings;
        Clocks.Result clocks;
        RH.OwnerProvenance owner4;
    }

    function testFormerConfirmedArtistDoesNotPromotePendingNewArtist() external pure {
        Fixture memory f = _fixture();
        _validate(f);
    }

    function testConfirmationCannotBeRelabeledWithCurrentArtist() external {
        Fixture memory f = _fixture();
        f.inventory.confirmations[0].transition.artistId = bytes32(uint256(2));
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        _validate(f);
    }

    function testOldConfirmationCannotClaimNewGenerationConfirmed() external {
        Fixture memory f = _fixture();
        f.histories[0].current.state = 3;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        _validate(f);
    }

    function testConfirmationMustFollowAuthenticCompletionAndPrecedeNextProposal() external {
        Fixture memory f = _fixture();
        f.inventory.confirmations[0].attributionPoint.ownerRevision = 2;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        _validate(f);
        f.inventory.confirmations[0].attributionPoint.ownerRevision = 9;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        _validate(f);
    }

    function testConfirmedRestorationDependsOnOpeningClock() external {
        Fixture memory f = _fixture();
        f.histories[0].disputes = new D.DisputeRow[](1);
        D.DisputeRow memory row;
        row.record.terms.bindingGeneration = 1;
        row.record.terms.disputeAction = 1;
        row.record.recordHash = bytes32(uint256(55));
        row.point = _point(f, 5);
        f.histories[0].disputes[0] = row;
        f.histories[0].heads[0].disputeRecordHash = row.record.recordHash;
        f.histories[0].heads[0].restoreState = 3;
        _validate(f);
        f.histories[0].heads[0].restoreState = 2;
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        _validate(f);
    }

    function testConfirmationCannotOccurDuringEarlierLiveOpening() external {
        Fixture memory f = _fixture();
        f.histories[0].disputes = new D.DisputeRow[](1);
        f.histories[0].disputes[0].record.terms.bindingGeneration = 1;
        f.histories[0].disputes[0].record.terms.disputeAction = 1;
        f.histories[0].disputes[0].point = _point(f, 3);
        vm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        _validate(f);
    }

    function _validate(Fixture memory f) private pure {
        Current.validate(f.inventory, f.histories, f.bindings, f.clocks, f.owner4);
    }

    function _point(Fixture memory f, uint64 revision) private pure returns (RH.Point memory) {
        return RH.Point(f.owner4.eras[0].originHash, 4, revision);
    }

    function _fixture() private pure returns (Fixture memory f) {
        f.owner4.origins = new RH.OriginEnvironment[](1);
        f.owner4.origins[0].owners[4] = address(0x400);
        f.owner4.origins[0].ownerCodeHashes[4] = bytes32(uint256(4));
        f.owner4.eras = new RH.OwnerEra[](1);
        f.owner4.eras[0].originHash = RH.originHash(f.owner4.origins[0]);
        f.owner4.eras[0].checkpoint.schema = RH.CHECKPOINT;
        f.owner4.eras[0].checkpoint.ownerState.domainId = RH.ownerDomain(4);
        f.owner4.eras[0].checkpoint.ownerState.revision = 10;
        f.histories = new D.Bundle[](1);
        f.histories[0].artistId = bytes32(uint256(2));
        f.histories[0].collectionId = 20;
        f.histories[0].generations = new A.Generation[](2);
        f.histories[0].generations[0].accepted = true;
        f.histories[0].heads = new AD.Head[](2);
        f.histories[0].current.state = 1;
        f.histories[0].current.generation = 2;
        f.bindings.bindings = new CB.Bundle[](1);
        f.bindings.bindings[0].bindings.collectionId = 20;
        f.bindings.bindings[0].bindings.rows = new BG.Row[](2);
        f.bindings.bindings[0].bindings.rows[0].item.artistId = bytes32(uint256(1));
        f.bindings.bindings[0].bindings.rows[0].item.accepted = true;
        f.bindings.bindings[0].bindings.rows[1].item.artistId = bytes32(uint256(2));
        f.clocks.clocks.collections = new G.Timeline[](1);
        f.clocks.clocks.collections[0].attributionProposals = new RH.Point[](2);
        f.clocks.clocks.collections[0].attributionCompletions = new RH.Point[](2);
        f.clocks.clocks.collections[0].attributionProposals[0] = _point(f, 1);
        f.clocks.clocks.collections[0].attributionProposals[1] = _point(f, 9);
        f.clocks.clocks.collections[0].attributionCompletions[0] = _point(f, 2);
        f.inventory.confirmations = new H.ConfirmationRow[](1);
        f.inventory.confirmations[0].transition.artistId = bytes32(uint256(1));
        f.inventory.confirmations[0].transition.collectionId = 20;
        f.inventory.confirmations[0].transition.bindingGeneration = 1;
        f.inventory.confirmations[0].attributionPoint = _point(f, 4);
    }
}
