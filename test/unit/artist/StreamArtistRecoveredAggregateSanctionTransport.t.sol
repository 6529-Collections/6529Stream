// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAggregateSanctionConsentTransport as Consent
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionConsentTransport.sol";
import {
    StreamArtistRecoveredAggregateSanctionAttributionTransport as Attribution
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionAttributionTransport.sol";
import {
    StreamArtistAggregateConsentSupplementTypes as Supplement
} from "../../../smart-contracts/domains/artist/StreamArtistAggregateConsentSupplementTypes.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Rows
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistAggregateSanctionConsentTypes as F
} from "../../../smart-contracts/domains/artist/StreamArtistAggregateSanctionConsentTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Literal carrier and feature oracles around the fixed linked transport workers.
/// @dev The synthetic Inventory is structurally nonempty, not authenticated Archive evidence.
/// These tests make no claim about original signatures, authority, chronology or operation60.
contract StreamArtistRecoveredAggregateSanctionTransportTest {
    bytes32 private constant SUPPLEMENT =
        keccak256("6529STREAM_ARTIST_AGGREGATE_CONSENT_SUPPLEMENT_V1");
    bytes32 private constant ATTRIBUTION =
        keccak256("6529STREAM_ARTIST_AGGREGATE_SANCTION_ATTRIBUTION_V1");

    function decodeConsent(bytes[] memory rows, bool ratified, bool sanctioned)
        external
        pure
        returns (
            G.Consents[] memory original,
            T.RatificationRecord[][] memory ratifications,
            H.Inventory memory history
        )
    {
        return Consent.decode(rows, ratified, sanctioned);
    }

    function encodeConsent(bytes[] memory rows, H.Inventory memory history)
        external
        pure
        returns (bytes[] memory)
    {
        return Consent.encode(rows, history);
    }

    function decodeAttribution(M.State memory scope, bytes memory outer)
        external
        pure
        returns (M.State memory original, H.Inventory memory history)
    {
        Attribution.requireFeature(scope.rows, outer);
        return Attribution.decode(scope);
    }

    function encodeAttribution(bytes[] memory rows, H.Inventory memory history)
        external
        pure
        returns (bytes[] memory)
    {
        return Attribution.encode(rows, history);
    }

    function decodeRatificationOnly(bytes memory row) external pure {
        Rows.decode(row);
    }

    function testLegacyAndRatificationRowsKeepExactOriginalCanonicalBytes() external view {
        bytes[] memory rows = _consents();
        (
            G.Consents[] memory original,
            T.RatificationRecord[][] memory records,
            H.Inventory memory history
        ) = this.decodeConsent(rows, false, false);
        require(history.sanctions.length == 0 && records[0].length == 0, "empty families");
        for (uint256 i; i < rows.length; ++i) {
            require(
                keccak256(rows[i]) == keccak256(abi.encode(original[i])), "literal legacy bytes"
            );
            require(
                keccak256(Rows.encode(original[i], new T.RatificationRecord[](0)))
                    == keccak256(rows[i]),
                "empty does not wrap"
            );
        }
        Supplement.Bundle memory supplement = _supplement(rows[1], true);
        rows[1] = abi.encode(SUPPLEMENT, uint16(1), supplement);
        (, records, history) = this.decodeConsent(rows, true, false);
        require(
            records[1].length == 1 && records[1][0].recordHash == bytes32(uint256(701)),
            "retained ratification"
        );
        require(history.sanctions.length == 0, "ratification is not sanction");
    }

    function testCombinedSupplementCarriesOneGlobalInventoryAndLeavesOtherRowsExact()
        external
        view
    {
        bytes[] memory rows = _consents();
        Supplement.Bundle memory first = _supplement(rows[0], true);
        rows[0] = abi.encode(SUPPLEMENT, uint16(1), first);
        bytes32 untouched = keccak256(rows[1]);
        H.Inventory memory history = _history();
        bytes[] memory encoded = this.encodeConsent(rows, history);
        first.sanctionInventory = abi.encode(history);
        require(
            keccak256(encoded[0]) == keccak256(abi.encode(SUPPLEMENT, uint16(1), first)),
            "literal combined wrapper"
        );
        require(keccak256(encoded[1]) == untouched, "second row unchanged");
        (
            G.Consents[] memory original,
            T.RatificationRecord[][] memory records,
            H.Inventory memory returned
        ) = this.decodeConsent(encoded, true, true);
        require(
            keccak256(abi.encode(original[0])) == keccak256(abi.encode(first.original)),
            "full original tuple"
        );
        require(
            keccak256(abi.encode(records[0])) == keccak256(abi.encode(first.ratifications)),
            "full ratification tuple"
        );
        require(
            keccak256(abi.encode(returned)) == keccak256(abi.encode(history)),
            "full global inventory"
        );
        _bad(abi.encodeCall(this.decodeRatificationOnly, (encoded[0])));
    }

    function testSanctionInventoryCannotBeOmittedDuplicatedMovedOrRewrapped() external view {
        bytes[] memory source = _consents();
        H.Inventory memory history = _history();
        _bad(abi.encodeCall(this.decodeConsent, (source, false, true)));
        bytes[] memory good = this.encodeConsent(source, history);
        bytes memory saved = abi.encode(good);
        bytes[] memory rows = abi.decode(saved, (bytes[]));
        Supplement.Bundle memory extra = _supplement(rows[1], false);
        extra.sanctionInventory = abi.encode(history);
        rows[1] = abi.encode(SUPPLEMENT, uint16(1), extra);
        _bad(abi.encodeCall(this.decodeConsent, (rows, false, true)));
        rows[0] = _consents()[0];
        _bad(abi.encodeCall(this.decodeConsent, (rows, false, true)));
        _bad(abi.encodeCall(this.encodeConsent, (abi.decode(saved, (bytes[])), history)));
        this.decodeConsent(abi.decode(saved, (bytes[])), false, true);
    }

    function testConsentFeatureFlagsMustExactlyMatchBothActualFamilies() external view {
        bytes[] memory rows = _consents();
        Supplement.Bundle memory first = _supplement(rows[0], true);
        first.sanctionInventory = abi.encode(_history());
        rows[0] = abi.encode(SUPPLEMENT, uint16(1), first);
        _bad(abi.encodeCall(this.decodeConsent, (rows, false, true)));
        _bad(abi.encodeCall(this.decodeConsent, (rows, true, false)));
        _bad(abi.encodeCall(this.decodeConsent, (rows, false, false)));
        this.decodeConsent(rows, true, true);
        _bad(abi.encodeCall(this.decodeConsent, (_consents(), true, false)));
    }

    function testCanonicalSupplementRejectsTrailingBytesWrongVersionAndIncompleteInventory()
        external
        view
    {
        bytes[] memory rows = _consents();
        Supplement.Bundle memory first = _supplement(rows[0], false);
        H.Inventory memory history = _history();
        first.sanctionInventory = bytes.concat(abi.encode(history), hex"00");
        rows[0] = abi.encode(SUPPLEMENT, uint16(1), first);
        _bad(abi.encodeCall(this.decodeConsent, (rows, false, true)));
        first.sanctionInventory = abi.encode(history);
        rows[0] = abi.encode(SUPPLEMENT, uint16(2), first);
        _bad(abi.encodeCall(this.decodeConsent, (rows, false, true)));
        rows[0] = bytes.concat(abi.encode(SUPPLEMENT, uint16(1), first), hex"00");
        _bad(abi.encodeCall(this.decodeConsent, (rows, false, true)));
        history.operations = new H.OperationEvidence[](0);
        first.sanctionInventory = abi.encode(history);
        rows[0] = abi.encode(SUPPLEMENT, uint16(1), first);
        _bad(abi.encodeCall(this.decodeConsent, (rows, false, true)));
        rows[0] = abi.encode(SUPPLEMENT, uint16(1), _supplement(_consents()[0], false));
        _bad(abi.encodeCall(this.decodeConsent, (rows, false, false)));
    }

    function testFactsProjectionRetainsEveryOriginalPointRecordAndConfirmation() external pure {
        H.Inventory memory history = _history();
        F.Facts memory projected = Consent.facts(history);
        require(projected.sanctions.length == history.sanctions.length, "all records");
        require(
            keccak256(abi.encode(projected.sanctions[0].point))
                == keccak256(abi.encode(history.sanctions[0].point)),
            "original point"
        );
        require(
            keccak256(abi.encode(projected.sanctions[0].record))
                == keccak256(abi.encode(history.sanctions[0].record)),
            "all permanent fields"
        );
        require(
            keccak256(abi.encode(projected.confirmations))
                == keccak256(abi.encode(history.confirmations)),
            "both original clocks and evidence"
        );
    }

    function testAttributionLiteralWrapperPreservesWholeScopeAndOriginalRows() external view {
        M.State memory scope = _attribution();
        bytes memory first = scope.rows[0];
        bytes memory second = scope.rows[1];
        H.Inventory memory history = _history();
        scope.rows = this.encodeAttribution(scope.rows, history);
        require(
            keccak256(scope.rows[0])
                == keccak256(abi.encode(ATTRIBUTION, uint16(1), first, history)),
            "literal owner4 wrapper"
        );
        require(keccak256(scope.rows[1]) == keccak256(second), "other original row exact");
        bytes32 inputBefore = keccak256(abi.encode(scope));
        (M.State memory original, H.Inventory memory returned) =
            this.decodeAttribution(scope, _outer(true));
        require(
            keccak256(original.rows[0]) == keccak256(first)
                && keccak256(original.rows[1]) == keccak256(second),
            "full row restoration"
        );
        require(
            keccak256(abi.encode(original.artists, original.collections))
                == keccak256(abi.encode(scope.artists, scope.collections)),
            "scope exact"
        );
        require(
            keccak256(abi.encode(returned)) == keccak256(abi.encode(history)), "all global history"
        );
        require(keccak256(abi.encode(scope)) == inputBefore, "no input alias rewrite");
        this.decodeAttribution(_attribution(), _outer(false));
    }

    function testAttributionFeaturePlacementAndNestedCarrierRefuse() external view {
        M.State memory scope = _attribution();
        _bad(abi.encodeCall(this.decodeAttribution, (scope, _outer(true))));
        H.Inventory memory history = _history();
        scope.rows = this.encodeAttribution(scope.rows, history);
        _bad(abi.encodeCall(this.decodeAttribution, (scope, _outer(false))));
        _bad(abi.encodeCall(this.encodeAttribution, (scope.rows, history)));
        bytes memory saved = abi.encode(scope);
        scope.rows[1] = scope.rows[0];
        _bad(abi.encodeCall(this.decodeAttribution, (scope, _outer(true))));
        scope = abi.decode(saved, (M.State));
        scope.rows[0] = abi.encode(ATTRIBUTION, uint16(1), scope.rows[0], history);
        _bad(abi.encodeCall(this.decodeAttribution, (scope, _outer(true))));
        scope = abi.decode(saved, (M.State));
        scope.rows[0] = bytes.concat(scope.rows[0], hex"00");
        _bad(abi.encodeCall(this.decodeAttribution, (scope, _outer(true))));
        this.decodeAttribution(abi.decode(saved, (M.State)), _outer(true));
    }

    function _bad(bytes memory data) private view {
        (bool ok, bytes memory reason) = address(this).staticcall(data);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)
                    ),
            "exact transport refusal"
        );
    }

    function _consents() private pure returns (bytes[] memory rows) {
        rows = new bytes[](2);
        for (uint256 k; k < rows.length; ++k) {
            G.Consents memory original;
            original.bindings = new T.Binding[](1);
            original.bindings[0].artistId = bytes32(81 + k);
            original.bindings[0].bindingHash = bytes32(301 + k);
            original.bindings[0].generation = 1;
            original.bindings[0].accepted = true;
            original.rows.original.artistId = bytes32(81 + k);
            original.rows.original.collectionId = 101 + k;
            original.rows.original.bindingHash = bytes32(301 + k);
            rows[k] = abi.encode(original);
        }
    }

    function _supplement(bytes memory original, bool ratified)
        private
        pure
        returns (Supplement.Bundle memory s)
    {
        s.original = abi.decode(original, (G.Consents));
        s.ratifications = new T.RatificationRecord[](ratified ? 1 : 0);
        if (ratified) {
            s.ratifications[0] =
                T.RatificationRecord(bytes32(uint256(701)), bytes32(uint256(702)), address(0x703));
        }
    }

    function _history() private pure returns (H.Inventory memory history) {
        history.catalogues = new H.Catalogue[](1);
        history.catalogues[0].originHash = bytes32(uint256(501));
        history.catalogues[0].rowsHash = bytes32(uint256(502));
        history.operations = new H.OperationEvidence[](1);
        history.operations[0].originHash = bytes32(uint256(501));
        history.operations[0].operation = 12;
        history.operations[0].evidence =
            H.Evidence(7, address(0xF007), bytes32(uint256(508)), bytes32(uint256(509)));
        history.sanctions = new H.SanctionRow[](1);
        history.sanctions[0].point = RH.Point(bytes32(uint256(501)), 6, 1);
        history.sanctions[0].record.recordHash = bytes32(uint256(201));
        history.sanctions[0].record.artistId = bytes32(uint256(81));
        history.sanctions[0].record.terms.collectionId = 101;
        history.sanctions[0].archiveBytes = hex"001122ff";
        history.sanctions[0].evidence = history.operations[0].evidence;
        history.confirmations = new H.ConfirmationRow[](1);
        history.confirmations[0].attributionPoint = RH.Point(bytes32(uint256(501)), 4, 101);
        history.confirmations[0].consentPoint = RH.Point(bytes32(uint256(501)), 6, 2);
        history.confirmations[0].evidence =
            H.Evidence(8, address(0xF008), bytes32(uint256(518)), bytes32(uint256(519)));
        history.confirmations[0].transition.collectionId = 101;
        history.confirmations[0].transition.artistId = bytes32(uint256(81));
        history.confirmations[0].transition.bindingGeneration = 1;
        history.confirmations[0].transition.sanctionRecordHash = bytes32(uint256(201));
    }

    function _attribution() private pure returns (M.State memory scope) {
        scope.artists = new AH.Query[](1);
        scope.artists[0].artistId = bytes32(uint256(81));
        scope.collections = new AH.Query[](2);
        scope.collections[0].collectionId = 101;
        scope.collections[1].collectionId = 102;
        scope.rows = new bytes[](2);
        // Opaque original G/MD/PC row bytes are deliberately preserved, not decoded by this worker.
        scope.rows[0] = abi.encode(bytes32(uint256(601)), hex"001122");
        scope.rows[1] = abi.encode(bytes32(uint256(602)), hex"0011223344ff");
    }

    function _outer(bool sanctioned) private pure returns (bytes memory) {
        RH.Envelope memory e;
        e.header = RH.ExportHeader(
            RH.PROFILE,
            uint16(1),
            uint8(4),
            bytes32(uint256(501)),
            0,
            bytes32(uint256(601)),
            bytes32(uint256(602)),
            bytes32(uint256(603)),
            sanctioned ? RH.SANCTION_HISTORY : 0,
            0,
            0,
            1
        );
        return abi.encode(RH.ownerTag(4), uint16(1), e);
    }
}
