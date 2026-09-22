// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAggregateSanctionRows as Rows
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionRows.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Synthetic assignment/conservation regressions for the aggregate original12/13 join.
/// @dev These vectors exercise the pure join after source authentication. They do not simulate
/// an original signature, Archive, Finality execution, complete provenance, or operation60.
contract StreamArtistRecoveredAggregateSanctionRowsTest {
    function assigned(
        AH.Query[] memory queries,
        CB.Bundle[] memory bindings,
        uint256 collectionId,
        T.Binding memory binding_
    ) external pure returns (uint256) {
        return Rows.collectionIndex(queries, bindings, collectionId, binding_);
    }

    function journal(RH.Provenance memory p, H.SanctionRow[] memory rows) external pure {
        Rows.validateJournal(p, rows);
    }

    function confirmationKeys(H.ConfirmationRow[] memory rows) external pure {
        Rows.validateConfirmationKeys(rows);
    }

    function testAggregateSanctionsAssignTwoCollectionsAtGenerationOne() external pure {
        (AH.Query[] memory q, CB.Bundle[] memory b) = _bindings();
        require(Rows.collectionIndex(q, b, 101, b[0].bindings.rows[0].item) == 0, "first");
        require(Rows.collectionIndex(q, b, 202, b[1].bindings.rows[0].item) == 1, "second");
    }

    function testAggregateSanctionsRetainHistoricalArtistAfterCurrentHeadCorrection()
        external
        pure
    {
        (AH.Query[] memory q, CB.Bundle[] memory b) = _bindings();
        T.Binding memory oldBinding = _copy(b[0].bindings.rows[0].item);
        T.Binding memory current = _copy(oldBinding);
        current.artistId = keccak256("current corrected Artist");
        current.generation = 2;
        current.bindingHash = keccak256("current corrected binding");
        b[0].bindings.rows = new G.Row[](2);
        b[0].bindings.rows[0].item = oldBinding;
        b[0].bindings.rows[1].item = current;
        b[0].bindings.current = current;
        b[0].bindings.artistId = current.artistId;
        b[0].bindings.bindingHash = current.bindingHash;
        q[0].artistId = current.artistId;
        q[0].bindingHash = current.bindingHash;
        require(oldBinding.artistId != q[0].artistId, "actual prior Artist vector");
        require(Rows.collectionIndex(q, b, 101, oldBinding) == 0, "retained original tuple");
        require(Rows.collectionIndex(q, b, 101, current) == 0, "current tuple independently");
    }

    function testAggregateSanctionsSameArtistDoesNotCollapseCollectionAssignment() external pure {
        (AH.Query[] memory q, CB.Bundle[] memory b) = _bindings();
        b[1].bindings.rows[0].item.artistId = q[0].artistId;
        require(Rows.collectionIndex(q, b, 202, b[1].bindings.rows[0].item) == 1, "collection");
    }

    function testAggregateSanctionsRejectWrongCollectionAndAmbiguousSelectors() external {
        (AH.Query[] memory q, CB.Bundle[] memory b) = _bindings();
        T.Binding memory original = _copy(b[0].bindings.rows[0].item);
        _reject(abi.encodeCall(this.assigned, (q, b, 303, original)));
        _reject(abi.encodeCall(this.assigned, (q, b, 202, original)));
        q[1] = q[0];
        b[1] = b[0];
        _reject(abi.encodeCall(this.assigned, (q, b, 101, original)));
    }

    function testAggregateSanctionsRejectChangedOriginalBindingAndArtist() external {
        (AH.Query[] memory q, CB.Bundle[] memory b) = _bindings();
        T.Binding memory original = _copy(b[0].bindings.rows[0].item);
        original.bindingHash = bytes32(uint256(999));
        _reject(abi.encodeCall(this.assigned, (q, b, 101, original)));
        original = _copy(b[0].bindings.rows[0].item);
        original.artistId = q[1].artistId;
        _reject(abi.encodeCall(this.assigned, (q, b, 101, original)));
        b[0].bindings.collectionId = 303;
        _reject(abi.encodeCall(this.assigned, (q, b, 101, b[0].bindings.rows[0].item)));
    }

    function testAggregateSanctionsRejectUnacceptedOrUnknownOriginalGeneration() external {
        (AH.Query[] memory q, CB.Bundle[] memory b) = _bindings();
        T.Binding memory original = _copy(b[0].bindings.rows[0].item);
        original.accepted = false;
        _reject(abi.encodeCall(this.assigned, (q, b, 101, original)));
        original = _copy(b[0].bindings.rows[0].item);
        original.generation = 0;
        _reject(abi.encodeCall(this.assigned, (q, b, 101, original)));
        original.generation = 2;
        _reject(abi.encodeCall(this.assigned, (q, b, 101, original)));
    }

    function testAggregateSanctionsPreserveInterleavedWholeOwnerJournal() external pure {
        (RH.Provenance memory p, H.SanctionRow[] memory rows) = _journal();
        Rows.validateJournal(p, rows);
        require(p.journals[6].length == 3 && p.journals[6][1].receipt.operation == 14, "whole");
        require(p.journals[6][2].position.nativeIndex == 2, "original position");
        require(rows[1].point.ownerRevision == 9, "unrenumbered original revision");
    }

    function testAggregateSanctionsRejectMissingAndReorderedOriginalOccurrences() external {
        (RH.Provenance memory p, H.SanctionRow[] memory rows) = _journal();
        H.SanctionRow[] memory omitted = new H.SanctionRow[](1);
        omitted[0] = rows[0];
        _reject(abi.encodeCall(this.journal, (p, omitted)));
        H.SanctionRow memory first = rows[0];
        rows[0] = rows[1];
        rows[1] = first;
        _reject(abi.encodeCall(this.journal, (p, rows)));
    }

    function testAggregateSanctionsRejectForeignJournalIdentityHashAndClock() external {
        (RH.Provenance memory p, H.SanctionRow[] memory rows) = _journal();
        p.journals[6][2].receipt.artistId = rows[0].record.artistId;
        _reject(abi.encodeCall(this.journal, (p, rows)));
        (p, rows) = _journal();
        p.journals[6][2].receipt.collectionId = 101;
        _reject(abi.encodeCall(this.journal, (p, rows)));
        (p, rows) = _journal();
        p.journals[6][2].receipt.recordHash = bytes32(uint256(77));
        _reject(abi.encodeCall(this.journal, (p, rows)));
        (p, rows) = _journal();
        p.journals[6][2].position.point.ownerIndex = 4;
        _reject(abi.encodeCall(this.journal, (p, rows)));
        (p, rows) = _journal();
        p.journals[6][2].position.point.ownerRevision = 8;
        _reject(abi.encodeCall(this.journal, (p, rows)));
    }

    function testAggregateSanctionsRejectDuplicatedOriginalRecordEvenWithMatchingRows() external {
        (RH.Provenance memory p, H.SanctionRow[] memory rows) = _journal();
        rows[1].record.recordHash = rows[0].record.recordHash;
        p.journals[6][2].receipt.recordHash = rows[0].record.recordHash;
        _reject(abi.encodeCall(this.journal, (p, rows)));
    }

    function testAggregateSanctionsAllowIndependentGenerationOneConfirmations() external pure {
        H.ConfirmationRow[] memory rows = _confirmations();
        Rows.validateConfirmationKeys(rows);
        require(rows[0].transition.bindingGeneration == rows[1].transition.bindingGeneration, "one");
        rows[1].transition.artistId = rows[0].transition.artistId;
        Rows.validateConfirmationKeys(rows);
    }

    function testAggregateSanctionsRejectDuplicateConfirmationForSameCollectionGeneration()
        external
    {
        H.ConfirmationRow[] memory rows = _confirmations();
        rows[1].transition.collectionId = rows[0].transition.collectionId;
        rows[1].transition.artistId = rows[0].transition.artistId;
        rows[1].transition.sanctionRecordHash = bytes32(uint256(98));
        rows[1].transition.finalityRecordHash = bytes32(uint256(99));
        _reject(abi.encodeCall(this.confirmationKeys, (rows)));
    }

    function testAggregateSanctionsAllowIndependentCorrectedGenerationConfirmation() external pure {
        H.ConfirmationRow[] memory rows = _confirmations();
        rows[1].transition.collectionId = rows[0].transition.collectionId;
        rows[1].transition.artistId = rows[0].transition.artistId;
        rows[1].transition.bindingGeneration = 2;
        Rows.validateConfirmationKeys(rows);
    }

    function _bindings() private pure returns (AH.Query[] memory q, CB.Bundle[] memory b) {
        q = new AH.Query[](2);
        b = new CB.Bundle[](2);
        for (uint256 i; i < 2; ++i) {
            q[i].artistId = keccak256(abi.encode("original Artist", i));
            q[i].collectionId = (i + 1) * 101;
            q[i].bindingHash = keccak256(abi.encode("original binding", i));
            b[i].bindings.artistId = q[i].artistId;
            b[i].bindings.collectionId = q[i].collectionId;
            b[i].bindings.bindingHash = q[i].bindingHash;
            b[i].bindings.rows = new G.Row[](1);
            T.Binding memory item;
            item.artistId = q[i].artistId;
            item.bindingHash = q[i].bindingHash;
            item.generation = 1;
            item.accepted = true;
            b[i].bindings.rows[0].item = item;
            b[i].bindings.current = _copy(item);
        }
    }

    function _journal() private pure returns (RH.Provenance memory p, H.SanctionRow[] memory rows) {
        rows = new H.SanctionRow[](2);
        p.journals[6] = new RH.JournalEntry[](3);
        bytes32 origin = keccak256("original environment, synthetic vector");
        for (uint256 i; i < 2; ++i) {
            rows[i].record.artistId = keccak256(abi.encode("original Artist", i));
            rows[i].record.recordHash = keccak256(abi.encode("original sanction", i));
            rows[i].record.terms.collectionId = (i + 1) * 101;
            rows[i].point = RH.Point(origin, 6, uint64(7 + i * 2));
            RH.JournalEntry memory entry;
            entry.position.point = RH.Point(origin, 6, uint64(7 + i * 2));
            entry.position.nativeIndex = i * 2;
            entry.receipt.operation = 12;
            entry.receipt.artistId = rows[i].record.artistId;
            entry.receipt.collectionId = rows[i].record.terms.collectionId;
            entry.receipt.recordHash = rows[i].record.recordHash;
            p.journals[6][i * 2] = entry;
        }
        p.journals[6][1].position.point = RH.Point(origin, 6, 8);
        p.journals[6][1].position.nativeIndex = 1;
        p.journals[6][1].receipt.operation = 14;
    }

    function _confirmations() private pure returns (H.ConfirmationRow[] memory rows) {
        rows = new H.ConfirmationRow[](2);
        for (uint256 i; i < 2; ++i) {
            rows[i].transition.collectionId = (i + 1) * 101;
            rows[i].transition.artistId = keccak256(abi.encode("original Artist", i));
            rows[i].transition.bindingGeneration = 1;
            rows[i].transition.sanctionRecordHash = keccak256(abi.encode("original sanction", i));
            rows[i].transition.finalityRecordHash = keccak256(abi.encode("original finality", i));
        }
    }

    function _copy(T.Binding memory value) private pure returns (T.Binding memory) {
        return abi.decode(abi.encode(value), (T.Binding));
    }

    function _reject(bytes memory callData) private view {
        (bool ok, bytes memory result) = address(this).staticcall(callData);
        require(!ok, "invalid join accepted");
        require(
            keccak256(result)
                == keccak256(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)),
            "exact invalid-profile error"
        );
    }
}
