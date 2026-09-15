// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamWorkRecordTypes as W
} from "../../interfaces/stream/metadata/StreamWorkRecordTypes.sol";
import {
    StreamRightsRecordTypes as R
} from "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import {
    StreamConservationRecordTypes as C
} from "../../interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import "../records/StreamWorkRecordJson.sol";
import "../records/StreamRightsRecordJson.sol";
import "../records/StreamArtistIntentJson.sol";
import "../records/StreamArtistIntentWaiverJson.sol";
import "../records/StreamArtistInterviewJson.sol";
import "../records/StreamConservationFormatJson.sol";

/// @notice Complete ordered reference walks of the exact supported typed original payloads.
/// @dev The fixed producer supplies the authenticated payload hash and source record. This pure
/// library cannot authenticate either. All six hash algorithms survive unchanged; coverage must
/// separately establish correspondence, and must reject unsupported nonempty references.
library StreamPreservationTypedReferences {
    bytes32 private constant RAW = keccak256("RAW_BYTES");
    bytes32 private constant JCS = keccak256("RFC8785_JCS");

    function work(address source, bytes32 record, bytes32 payloadHash, W.Description memory value)
        public
        pure
        returns (T.Item[] memory items)
    {
        _payload(StreamWorkRecordJson.serialize(value), payloadHash);
        if (value.form != W.Form.FULL || value.full.format.kind != W.FormatKind.CATALOG) {
            return new T.Item[](0);
        }
        W.Catalog memory catalog = value.full.format.catalog;
        uint256 count = 1;
        for (uint256 i; i < catalog.entries.length; ++i) {
            if (catalog.entries[i].kind == W.MappingKind.SPECIFICATION) ++count;
        }
        items = new T.Item[](count);
        bytes memory document = StreamWorkFormatJson.catalogDocument(catalog);
        items[0] = _catalog(source, record, 0, catalog.name, document);
        uint256 next = 1;
        for (uint256 i; i < catalog.entries.length; ++i) {
            W.CatalogEntry memory entry = catalog.entries[i];
            if (entry.kind == W.MappingKind.SPECIFICATION) {
                items[next++] = _reference(
                    source,
                    record,
                    i,
                    keccak256("WORK_FORMAT_SPECIFICATION"),
                    C.Reference(
                        1,
                        RAW,
                        abi.encodePacked(entry.specification.digest),
                        entry.specification.uri
                    )
                );
            }
        }
    }

    function rights(address source, bytes32 record, bytes32 payloadHash, R.Statement memory value)
        public
        pure
        returns (T.Item[] memory items)
    {
        _payload(StreamRightsRecordJson.serialize(value), payloadHash);
        R.Grant[6] memory grants = [
            value.grants.aiTraining,
            value.grants.derivative,
            value.grants.exhibition,
            value.grants.print,
            value.grants.publication,
            value.grants.reproduction
        ];
        uint256 count = value.instrument.exists ? 1 : 0;
        for (uint256 i; i < 6; ++i) {
            if (grants[i].conditions.kind == R.ConditionKind.DOCUMENT) ++count;
        }
        items = new T.Item[](count);
        uint256 next;
        if (value.instrument.exists) {
            items[next++] = _rightsDocument(
                source, record, 0, keccak256("RIGHTS_INSTRUMENT"), value.instrument
            );
        }
        for (uint256 i; i < 6; ++i) {
            if (grants[i].conditions.kind == R.ConditionKind.DOCUMENT) {
                items[next++] = _rightsDocument(
                    source,
                    record,
                    i,
                    keccak256("RIGHTS_USE_CONDITION"),
                    grants[i].conditions.document
                );
            }
        }
    }

    function intent(address source, bytes32 record, bytes32 payloadHash, C.Intent memory value)
        public
        pure
        returns (T.Item[] memory items)
    {
        _payload(StreamArtistIntentJson.serialize(value), payloadHash);
        items = new T.Item[](10);
        C.Reference[9] memory refs = [
            value.display.scale,
            value.display.timing,
            value.display.color,
            value.display.interaction,
            value.display.motion,
            value.display.frameRate,
            value.variabilityTolerances,
            value.dependencyAging,
            value.significantProperties
        ];
        bytes32[9] memory roles = [
            keccak256("DISPLAY_SCALE"),
            keccak256("DISPLAY_TIMING"),
            keccak256("DISPLAY_COLOR"),
            keccak256("DISPLAY_INTERACTION"),
            keccak256("DISPLAY_MOTION"),
            keccak256("DISPLAY_FRAME_RATE"),
            keccak256("VARIABILITY_TOLERANCES"),
            keccak256("DEPENDENCY_AGING"),
            keccak256("SIGNIFICANT_PROPERTIES")
        ];
        for (uint256 i; i < refs.length; ++i) {
            items[i] = _reference(source, record, i, roles[i], refs[i]);
        }
        items[9] = _interviewEntry(source, record, value.interview);
    }

    function waiver(
        address source,
        bytes32 record,
        bytes32 payloadHash,
        C.IntentWaiver memory value
    ) public pure returns (T.Item[] memory items) {
        _payload(StreamArtistIntentWaiverJson.serialize(value), payloadHash);
        items = new T.Item[](2);
        items[0] =
            _reference(source, record, 0, keccak256("ARTIST_INTENT_WAIVER"), value.waiverStatement);
        items[1] = _interviewEntry(source, record, value.interview);
    }

    function interview(
        address source,
        bytes32 record,
        bytes32 payloadHash,
        C.Interview memory value
    ) public pure returns (T.Item[] memory items) {
        _payload(StreamArtistInterviewJson.serialize(value), payloadHash);
        uint256 count = 2 + value.participants.length + value.captures.length
            + _formatCount(value.transcript.format);
        for (uint256 i; i < value.captures.length; ++i) {
            count += _formatCount(value.captures[i].payload.format);
        }
        items = new T.Item[](count);
        uint256 next;
        items[next++] = _reference(
            source, record, 0, keccak256("INTERVIEW_INSTRUMENT"), value.instrument.document
        );
        for (uint256 i; i < value.participants.length; ++i) {
            T.Item memory row = _reference(
                source,
                record,
                i,
                keccak256("INTERVIEW_PARTICIPANT"),
                value.participants[i].identity
            );
            row.provenanceHash =
                keccak256(abi.encode(value.participants[i].role, value.participants[i].otherRole));
            items[next++] = row;
        }
        items[next++] =
            _formatted(source, record, 0, keccak256("INTERVIEW_TRANSCRIPT"), value.transcript);
        next = _format(items, next, source, record, 0, value.transcript.format);
        for (uint256 i; i < value.captures.length; ++i) {
            C.Capture memory capture = value.captures[i];
            T.Item memory row =
                _formatted(source, record, i, keccak256("INTERVIEW_CAPTURE"), capture.payload);
            row.provenanceHash = keccak256(abi.encode(capture.kind));
            items[next++] = row;
            next = _format(items, next, source, record, i + 1, capture.payload.format);
        }
        if (next != count) revert T.InvalidInventoryItem();
    }

    function _formatCount(C.Format memory format) private pure returns (uint256 count) {
        if (format.kind != C.FormatKind.CATALOG) return 0;
        count = 1;
        for (uint256 i; i < format.catalog.entries.length; ++i) {
            if (format.catalog.entries[i].kind == C.MappingKind.SPECIFICATION) ++count;
        }
    }

    function _format(
        T.Item[] memory items,
        uint256 next,
        address source,
        bytes32 record,
        uint256 formatIndex,
        C.Format memory format
    ) private pure returns (uint256) {
        if (format.kind != C.FormatKind.CATALOG) return next;
        bytes memory document = StreamConservationFormatJson.catalogDocument(format.catalog);
        items[next++] = _catalog(source, record, formatIndex, format.catalog.name, document);
        for (uint256 i; i < format.catalog.entries.length; ++i) {
            C.CatalogEntry memory entry = format.catalog.entries[i];
            if (entry.kind == C.MappingKind.SPECIFICATION) {
                T.Item memory row = _reference(
                    source,
                    record,
                    i,
                    keccak256("INTERVIEW_FORMAT_SPECIFICATION"),
                    entry.specification
                );
                row.provenanceHash = keccak256(abi.encode(formatIndex, entry.entryId));
                items[next++] = row;
            }
        }
        return next;
    }

    function _formatted(
        address source,
        bytes32 record,
        uint256 index,
        bytes32 role,
        C.Payload memory payload
    ) private pure returns (T.Item memory row) {
        row = _reference(source, record, index, role, payload.content);
        row.formatId = payload.format.formatId;
        if (payload.format.kind == C.FormatKind.CATALOG) {
            row.catalogId = keccak256(bytes(payload.format.catalog.name));
            row.catalogHash =
                keccak256(StreamConservationFormatJson.catalogDocument(payload.format.catalog));
        }
    }

    function _interviewEntry(address source, bytes32 record, C.InterviewEntry memory entry)
        private
        pure
        returns (T.Item memory row)
    {
        bool present = entry.status == C.InterviewStatus.PRESENT;
        row = _reference(
            source,
            record,
            0,
            present ? keccak256("PRESENT_INTERVIEW_PAYLOAD") : keccak256("INTERVIEW_WAIVER"),
            present ? entry.record.payload : entry.waiverStatement
        );
        if (present) {
            row.schemaId = entry.record.schemaId;
            // The original parent commits a concrete record locator as well as a payload ref.
            row.provenanceHash = keccak256(
                abi.encode(
                    entry.record.chainId,
                    entry.record.core,
                    entry.record.host,
                    entry.record.recordHash,
                    entry.record.profileHash
                )
            );
        }
    }

    function _rightsDocument(
        address source,
        bytes32 record,
        uint256 index,
        bytes32 role,
        R.Document memory doc
    ) private pure returns (T.Item memory) {
        return _reference(
            source, record, index, role, C.Reference(1, RAW, abi.encodePacked(doc.digest), doc.uri)
        );
    }

    function _catalog(
        address source,
        bytes32 record,
        uint256 index,
        string memory name,
        bytes memory document
    ) private pure returns (T.Item memory row) {
        row = _reference(
            source,
            record,
            index,
            keccak256("REGISTERED_FORMAT_CATALOG"),
            C.Reference(1, JCS, abi.encodePacked(keccak256(document)), "")
        );
        row.kind = T.Kind.REGISTERED_DOCUMENT;
        row.byteSize = uint64(document.length);
        row.catalogId = keccak256(bytes(name));
        row.catalogHash = keccak256(document);
    }

    function _reference(
        address source,
        bytes32 record,
        uint256 index,
        bytes32 role,
        C.Reference memory ref
    ) private pure returns (T.Item memory row) {
        row.kind = T.Kind.EXTERNAL_REFERENCE;
        row.source = source;
        row.sourceRecord = record;
        row.sourceIndex = index;
        row.role = role;
        row.algorithm = ref.algorithm;
        row.canonicalizationId = ref.canonicalizationId;
        row.digest = ref.digest;
        row.uri = ref.uri;
    }

    function _payload(bytes memory exact, bytes32 expected) private pure {
        if (expected == 0 || keccak256(exact) != expected) revert T.InvalidInventoryItem();
    }
}
