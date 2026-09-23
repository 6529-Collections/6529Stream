// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredSanctionHistoryFixture.sol";
import {
    StreamArtistCompleteHistorySanctionSource as CHSanctions
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistorySanctionSource.sol";
import {
    StreamArtistCompleteHistorySource as CHSource
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistorySource.sol";
import {
    StreamArtistCompleteHistoryScope as CHScope
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistCompleteHistoryTypes as CT
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationSource as CHProvenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationSource.sol";
import {
    StreamArtistRecoveredMultipleTypes as CHM
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistMultipleHydrationTypes as CHMH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";

/// @notice Actual original op12/13 and Archive inventories feed the complete-history adapter.
/// @dev Inherits the explicit documentary/Finality response boundary; these tests do not execute
/// a Finality governance transaction or a CompleteHistory operation60 import.
contract StreamArtistCompleteHistorySanctionSourceActualTest is
    ArtistRecoveredSanctionHistoryFixture
{
    function testCompleteSanctionSourceProvesEmptyFamilyFromOriginalWholeArchive() external {
        _baseline();
        (CHM.State memory scope, CT.Inventory memory inventory) = _observe();
        SH.Inventory memory sanctions = CHSanctions.collect(scope, inventory);
        require(inventory.archive.operations.length >= 2, "original binding/acceptance retained");
        require(
            sanctions.sanctions.length == 0 && sanctions.confirmations.length == 0
                && sanctions.operations.length == 0 && sanctions.catalogues.length == 0,
            "explicit empty sanction family"
        );
        // A native12 claim cannot be ignored merely because the original Archive has none.
        RH.JournalEntry[] memory nativeRows = new RH.JournalEntry[](1);
        nativeRows[0].receipt.operation = 12;
        nativeRows[0].receipt.artistId = artistId;
        nativeRows[0].receipt.collectionId = 1;
        nativeRows[0].receipt.recordHash = keccak256("unbacked native sanction");
        inventory.provenance.journals[6] = nativeRows;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHSanctions.collect(scope, inventory);
    }

    function testCompleteSanctionSourceRetainsIndependentCatalogueAndOrderedOriginalEvidence()
        external
    {
        _baseline();
        _basePolicy();
        bytes32 first = _sanction();
        _confirm(first);
        _signedDispute(1, keccak256("interleaved confirmed opening"), false);
        _signedDispute(2, keccak256("interleaved confirmed withdrawal"), false);
        bytes32 second = _sanction();
        (CHM.State memory scope, CT.Inventory memory inventory) = _observe();
        SH.Inventory memory sanctions = CHSanctions.collect(scope, inventory);
        require(
            sanctions.sanctions.length == 2 && sanctions.confirmations.length == 1
                && sanctions.operations.length == 3,
            "whole original sanction family"
        );
        require(
            sanctions.sanctions[0].record.recordHash == first
                && sanctions.sanctions[1].record.recordHash == second
                && sanctions.confirmations[0].transition.sanctionRecordHash == first,
            "later association head preserves original confirmation"
        );
        require(
            sanctions.operations[0].operation == 12 && sanctions.operations[1].operation == 13
                && sanctions.operations[2].operation == 12,
            "original ordered projection"
        );
        require(
            sanctions.confirmations[0].attributionPoint.ownerRevision
                != sanctions.confirmations[0].consentPoint.ownerRevision,
            "independent original owner clocks"
        );
        require(
            sanctions.catalogues[0].rowsHash != inventory.archive.catalogues[0].rowsHash
                && sanctions.catalogues[0].count == inventory.archive.catalogues[0].count,
            "same original catalogue with independent domain commitments"
        );
        _rejectIncomplete(scope, inventory, sanctions);
        SH.Inventory memory repeated = CHSanctions.collect(scope, inventory);
        require(
            keccak256(abi.encode(repeated)) == keccak256(abi.encode(sanctions)),
            "original source and Archive unchanged after rejected witnesses"
        );
    }

    function _rejectIncomplete(
        CHM.State memory scope,
        CT.Inventory memory inventory,
        SH.Inventory memory sanctions
    ) private {
        SH.OperationEvidence[] memory original = inventory.archive.operations;
        SH.OperationEvidence[] memory omitted = new SH.OperationEvidence[](original.length - 1);
        uint256 removed = type(uint256).max;
        uint256 cursor;
        for (uint256 i; i < original.length; ++i) {
            if (removed == type(uint256).max && original[i].operation == 13) {
                removed = i;
                continue;
            }
            omitted[cursor++] = original[i];
        }
        require(removed != type(uint256).max, "authentic original confirmation present");
        inventory.archive.operations = omitted;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHSanctions.collect(scope, inventory);
        inventory.archive.operations = abi.decode(abi.encode(original), (SH.OperationEvidence[]));
        (inventory.archive.operations[0], inventory.archive.operations[removed]) =
        (inventory.archive.operations[removed], inventory.archive.operations[0]);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHSanctions.collect(scope, inventory);
        inventory.archive.operations = original;

        bytes32 commonHash = inventory.archive.catalogues[0].rowsHash;
        inventory.archive.catalogues[0].rowsHash = sanctions.catalogues[0].rowsHash;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHSanctions.collect(scope, inventory);
        inventory.archive.catalogues[0].rowsHash = commonHash;

        RH.JournalEntry[] memory nativeRows = inventory.provenance.journals[6];
        inventory.provenance.journals[6] = new RH.JournalEntry[](0);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHSanctions.collect(scope, inventory);
        inventory.provenance.journals[6] = nativeRows;
    }

    function _observe()
        private
        view
        returns (CHM.State memory scope, CT.Inventory memory inventory)
    {
        RH.Request memory request = _rhRequest();
        RH.Provenance memory provenance = CHProvenance.collect(
            suite, address(coordinator), request.records.authority.replayOrigins
        );
        CHMH.Request memory selected;
        selected.artistIds = new bytes32[](1);
        selected.artistIds[0] = artistId;
        selected.collections = new CHMH.Collection[](1);
        T.Binding[] memory heads = new T.Binding[](1);
        heads[0] = Binding(suite.owners[0]).binding(1);
        selected.collections[0] = CHMH.Collection(artistId, 1, new AH.PolicyKey[](0));
        scope = CHScope.partition(selected, heads, provenance);
        (inventory,) = CHSource.collect(scope, provenance);
    }
}
