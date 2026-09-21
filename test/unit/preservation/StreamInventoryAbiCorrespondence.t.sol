// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamInventoryAbiCorrespondence as Correspondence
} from "../../../smart-contracts/domains/preservation/StreamInventoryAbiCorrespondence.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @dev Exact source vocabulary tests. These do not replace publication/profile authentication
/// or actual archive admission; StreamCanonicalArchiveProducedPayloads covers that composition.
contract StreamInventoryAbiCorrespondenceTest {
    function _row(string memory role, string memory schema, string memory canon)
        private
        pure
        returns (T.Item memory item)
    {
        item.kind = T.Kind.ORIGINAL_PAYLOAD;
        item.algorithm = 1;
        item.byteSize = 32;
        item.role = keccak256(bytes(role));
        item.schemaId = keccak256(bytes(schema));
        item.canonicalizationId = keccak256(bytes(canon));
    }

    function _rows() private pure returns (T.Item[] memory rows) {
        rows = new T.Item[](18);
        rows[0] =
            _row("REFERENCE_MANIFEST", "STREAM_REFERENCE_MODE_ABI_V1", "STREAM_SOLIDITY_ABI_V1");
        rows[1] = _row(
            "CURATED_CONDITION_ORIGINAL_PAYLOAD",
            "STREAM_REFERENCE_CURATED_CONDITION_ABI_V1",
            "STREAM_SOLIDITY_ABI_V1"
        );
        rows[2] = _row(
            "SCOPED_SNAPSHOT_MANIFEST",
            "STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1",
            "STREAM_SOLIDITY_ABI_V1"
        );
        rows[3] = _row(
            "SCOPED_REFERENCE_MANIFEST",
            "STREAM_SCOPED_REFERENCE_RENDER_ABI_V1",
            "STREAM_SOLIDITY_ABI_V1"
        );
        rows[4] = _row(
            "POLICY_SNAPSHOT_MANIFEST_V2",
            "STREAM_POLICY_COLLECTION_SNAPSHOT_ABI_V2",
            "STREAM_ABI_POLICY_COLLECTION_SNAPSHOT_V2"
        );
        rows[5] = _row(
            "REFERENCE_MANIFEST",
            "STREAM_POLICY_COLLECTION_REFERENCE_ABI_V2",
            "STREAM_ABI_POLICY_COLLECTION_REFERENCE_V2"
        );
        rows[6] = _row(
            "SCOPED_POLICY_SNAPSHOT_MANIFEST_V2",
            "STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2",
            "STREAM_ABI_SCOPED_POLICY_SNAPSHOT_V2"
        );
        rows[7] = _row(
            "SCOPED_POLICY_REFERENCE_MANIFEST",
            "STREAM_SCOPED_POLICY_REFERENCE_ABI_V2",
            "STREAM_ABI_SCOPED_POLICY_REFERENCE_V2"
        );
        rows[8] = _row(
            "POLICY_SNAPSHOT_MANIFEST_V2",
            "STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V1",
            "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V1"
        );
        rows[9] = _row(
            "REFERENCE_MANIFEST",
            "STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V1",
            "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V1"
        );
        rows[10] = _row(
            "SCOPED_POLICY_SNAPSHOT_MANIFEST_V2",
            "STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V1",
            "STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1"
        );
        rows[11] = _row(
            "SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST",
            "STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V1",
            "STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V1"
        );
        rows[12] = _row(
            "COMPLETE_SIGNIFICANT_PROPERTIES",
            "STREAM_REFERENCE_SIGNIFICANT_PROPERTIES_ABI_V1",
            "STREAM_SOLIDITY_ABI_V1"
        );
        rows[12].kind = T.Kind.NATIVE_BYTES;
        rows[13] = _row(
            "METRIC_SUPPLEMENT_PAYLOAD",
            "STREAM_REFERENCE_METRIC_SUPPLEMENT_ABI_V1",
            "STREAM_SOLIDITY_ABI_V1"
        );
        rows[13].kind = T.Kind.NATIVE_BYTES;
        // These four fixed-family tuples are emitted by the collection/scoped
        // preservation producers after their separate V2 publication checks.
        rows[14] = _row(
            "POLICY_SNAPSHOT_MANIFEST_V2",
            "STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V2",
            "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V2"
        );
        rows[15] = _row(
            "REFERENCE_MANIFEST",
            "STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V2",
            "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V2"
        );
        rows[16] = _row(
            "SCOPED_POLICY_SNAPSHOT_MANIFEST_V2",
            "STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V2",
            "STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2"
        );
        rows[17] = _row(
            "SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST",
            "STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V2",
            "STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V2"
        );
    }

    function testEverySourceQualifiedNativeAbiTupleIsSupported() public pure {
        T.Item[] memory rows = _rows();
        for (uint256 i; i < rows.length; ++i) {
            require(Correspondence.supported(rows[i]));
        }
    }

    function _known(T.Item[] memory rows, T.Item memory candidate) private pure returns (bool) {
        for (uint256 i; i < rows.length; ++i) {
            if (
                candidate.kind == rows[i].kind && candidate.role == rows[i].role
                    && candidate.schemaId == rows[i].schemaId
                    && candidate.canonicalizationId == rows[i].canonicalizationId
            ) return true;
        }
        return false;
    }

    function testKnownSchemasRolesAndCanonsCannotBeMixedAcrossProfiles() public pure {
        T.Item[] memory rows = _rows();
        for (uint256 i; i < rows.length; ++i) {
            for (uint256 j; j < rows.length; ++j) {
                // Decode creates independent memory; no mutation of the reference inventory.
                T.Item memory candidate = abi.decode(abi.encode(rows[i]), (T.Item));
                candidate.role = rows[j].role;
                require(Correspondence.supported(candidate) == _known(rows, candidate));
                candidate.role = rows[i].role;
                candidate.schemaId = rows[j].schemaId;
                require(Correspondence.supported(candidate) == _known(rows, candidate));
                candidate.schemaId = rows[i].schemaId;
                candidate.canonicalizationId = rows[j].canonicalizationId;
                require(Correspondence.supported(candidate) == _known(rows, candidate));
            }
        }
    }

    function testNativeTuplesRejectOtherKindsAlgorithmsAndUnknownSizes() public pure {
        T.Item[] memory rows = _rows();
        for (uint256 i; i < rows.length; ++i) {
            T.Kind original = rows[i].kind;
            for (uint256 kind; kind <= uint256(T.Kind.EMPTY_PACKAGE_MEMBER); ++kind) {
                rows[i].kind = T.Kind(kind);
                require(Correspondence.supported(rows[i]) == (rows[i].kind == original));
            }
            rows[i].kind = original;
            rows[i].algorithm = 2;
            require(!Correspondence.supported(rows[i]), "native bytes must use original Keccak");
            rows[i].algorithm = 0;
            require(!Correspondence.supported(rows[i]));
            rows[i].algorithm = type(uint16).max;
            require(!Correspondence.supported(rows[i]));
            rows[i].algorithm = 1;
            rows[i].byteSize = 0;
            require(!Correspondence.supported(rows[i]), "native size is known");
        }
    }

    function testFuzzUnknownRoleSchemaOrCanonCannotUseKnownAbiProfile(bytes32 value) public pure {
        T.Item[] memory rows = _rows();
        for (uint256 i; i < rows.length; ++i) {
            T.Item memory candidate = abi.decode(abi.encode(rows[i]), (T.Item));
            candidate.role = value;
            require(Correspondence.supported(candidate) == _known(rows, candidate));
            candidate.role = rows[i].role;
            candidate.schemaId = value;
            require(Correspondence.supported(candidate) == _known(rows, candidate));
            candidate.schemaId = rows[i].schemaId;
            candidate.canonicalizationId = value;
            require(Correspondence.supported(candidate) == _known(rows, candidate));
        }
    }

    function testSignificantPropertiesReferenceKeepsDistinctUnknownSizeAndHashAlgorithms()
        public
        pure
    {
        T.Item memory row;
        row.kind = T.Kind.EXTERNAL_REFERENCE;
        row.role = keccak256("SIGNIFICANT_PROPERTIES");
        row.sourceIndex = 8;
        row.canonicalizationId = keccak256("STREAM_SOLIDITY_ABI_V1");
        row.algorithm = 1;
        require(Correspondence.supported(row));
        row.algorithm = 2;
        require(Correspondence.supported(row));
        row.algorithm = 3;
        require(!Correspondence.supported(row));
        row.algorithm = 1;
        row.sourceIndex = 7;
        require(!Correspondence.supported(row));
        row.sourceIndex = 8;
        row.byteSize = 1;
        require(!Correspondence.supported(row));
        row.byteSize = 0;
        row.schemaId = keccak256("STREAM_REFERENCE_SIGNIFICANT_PROPERTIES_ABI_V1");
        require(!Correspondence.supported(row), "external source supplies no schema");
        row.schemaId = 0;
        row.role = keccak256("CURATED_EXAMINER_CREDENTIALS");
        require(!Correspondence.supported(row), "no general ABI external-reference permission");
    }

    function testRawJcsAndTypedObjectsRemainOutsideTheNativeAbiException() public pure {
        T.Item memory row = _rows()[6];
        row.canonicalizationId = keccak256("RAW_BYTES");
        require(!Correspondence.supported(row));
        row.canonicalizationId = keccak256("RFC8785_JCS");
        require(!Correspondence.supported(row));
        row.canonicalizationId = keccak256("STREAM_ABI_VIEW_POLICY_OUTPUT_MANIFEST_V2");
        row.kind = T.Kind.ONCHAIN_OBJECT;
        require(!Correspondence.supported(row));
        row.kind = T.Kind.EXTERNAL_OBJECT;
        require(!Correspondence.supported(row));
    }
}
