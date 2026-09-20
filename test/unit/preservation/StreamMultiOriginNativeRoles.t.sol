// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamMultiOriginNativeRoles as Roles
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginNativeRoles.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @dev Pure role-label controls, not source or finality admission.
contract StreamMultiOriginNativeRolesTest {
    function testOnlyConfiguredArtistRuntimeRolesChangeAndEveryOtherFieldSurvives() public pure {
        T.Item[] memory rows = new T.Item[](9);
        bytes32[] memory expected = new bytes32[](9);
        for (uint256 i; i < 9; ++i) {
            rows[i] = _item(i);
        }
        rows[0].role = keccak256("ORIGINAL_ARTIST_DEPENDENCY_RUNTIME");
        expected[0] = keccak256("CURRENT_ARTIST_DEPENDENCY_RUNTIME");
        rows[1].role = keccak256("ORIGINAL_ARTIST_CONTENT_OWNER_RUNTIME");
        expected[1] = keccak256("CURRENT_ARTIST_CONTENT_OWNER_RUNTIME");
        rows[2].role = keccak256("ORIGINAL_ARTIST_CONTENT_OWNER");
        expected[2] = keccak256("CURRENT_ARTIST_CONTENT_OWNER");
        for (uint256 i; i < 5; ++i) {
            rows[3 + i].role = keccak256(abi.encode("ORIGINAL_ARTIST_DEPENDENCY_V2", i));
            expected[3 + i] = keccak256(abi.encode("CURRENT_ARTIST_DEPENDENCY_V2", i));
        }
        rows[8].role = keccak256("ORIGINAL_COORDINATOR_RUNTIME");
        expected[8] = rows[8].role;
        bytes memory before_ = abi.encode(rows);
        Roles.relabel(rows);
        T.Item[] memory originals = abi.decode(before_, (T.Item[]));
        for (uint256 i; i < rows.length; ++i) {
            require(rows[i].role == expected[i], "exact role at same index");
            originals[i].role = expected[i];
        }
        require(
            keccak256(abi.encode(rows)) == keccak256(abi.encode(originals)),
            "all other item fields unchanged"
        );
        bytes32 once = keccak256(abi.encode(rows));
        Roles.relabel(rows);
        require(keccak256(abi.encode(rows)) == once, "idempotent");
    }

    function testNeverRelabelsNonRuntimeOrAuthenticatedOriginRuntime() public pure {
        T.Item[] memory rows = new T.Item[](2);
        rows[0] = _item(0);
        rows[0].kind = T.Kind.STATE_BUNDLE;
        rows[0].role = keccak256("ORIGINAL_ARTIST_CONTENT_OWNER");
        rows[1] = _item(1);
        rows[1].role = keccak256("ARTIST_ORIGIN_ARCHIVE_RUNTIME");
        bytes32 before_ = keccak256(abi.encode(rows));
        Roles.relabel(rows);
        require(keccak256(abi.encode(rows)) == before_, "no unrelated relabel");
    }

    function _item(uint256 index) private pure returns (T.Item memory item) {
        item.kind = T.Kind.CONTRACT_RUNTIME;
        item.role = keccak256(abi.encode(index));
        item.source = address(uint160(index + 1));
        item.sourceRecord = keccak256("original receipt");
        item.sourceIndex = index;
        item.algorithm = 1;
        item.canonicalizationId = keccak256("RAW");
        item.digest = abi.encodePacked(index);
        item.uri = "fixture:all-fields";
        item.byteSize = 123;
        item.schemaId = keccak256("schema");
        item.formatId = keccak256("format");
        item.catalogId = keccak256("catalog");
        item.catalogHash = keccak256("catalog-hash");
        item.objectHash = keccak256("object");
        item.originalCoverageHash = keccak256("coverage");
        item.provenanceHash = keccak256("provenance");
    }
}
