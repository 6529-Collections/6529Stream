// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationRecordFields.sol";
import "../../interfaces/stream/metadata/StreamMediaMasterTypes.sol";

/// @notice Exact bytes of the existing STREAM_MASTER_WAIVER_V1 and new association schema.
/// @dev Serialization is never an authority or archive proof. The consuming selector authenticates
/// original op24 publication, exact registered definitions and current manifest/artist association.
library StreamMasterWaiverJson {
    function artistJSON(StreamMediaMasterTypes.Artist memory a) public pure returns (string memory) {
        if (a.artistId == 0 || a.bindingGeneration == 0 || a.bindingHash == 0) {
            revert StreamMediaMasterTypes.InvalidMasterWitness();
        }
        return string.concat(
            '{"artistId":', StreamRecordJson.hexValue(a.artistId),
            ',"bindingGeneration":', StreamRecordJson.unsigned(a.bindingGeneration),
            ',"bindingHash":', StreamRecordJson.hexValue(a.bindingHash), "}"
        );
    }

    function roleJSON(StreamMediaMasterTypes.Role role) public pure returns (string memory) {
        return role == StreamMediaMasterTypes.Role.SOURCE_MASTER ? '"SOURCE_MASTER"' : '"PRINT_MASTER"';
    }

    function mediaClassJSON(StreamMediaMasterTypes.MediaClass value)
        public pure returns (string memory)
    {
        if (value == StreamMediaMasterTypes.MediaClass.STILL_IMAGE) return '"still_image"';
        if (value == StreamMediaMasterTypes.MediaClass.PRINT_DESTINED) return '"print_destined"';
        if (value == StreamMediaMasterTypes.MediaClass.AUDIO) return '"audio"';
        if (value == StreamMediaMasterTypes.MediaClass.VIDEO) return '"video"';
        return '"interactive_capture"';
    }

    function waiver(StreamMediaMasterTypes.Waiver memory v) public pure returns (bytes memory) {
        if (v.subjectId == 0 || v.scopeSubjectId != v.subjectId
            || v.mediaObjects.length == 0 || v.mediaObjects.length > 512) {
            revert StreamMediaMasterTypes.InvalidMasterWitness();
        }
        bytes[] memory rows = new bytes[](v.mediaObjects.length);
        for (uint256 i; i < rows.length; ++i) {
            StreamMediaMasterTypes.WaivedObject memory row = v.mediaObjects[i];
            if (row.objectId == 0 || row.masterRoles.length == 0 || row.masterRoles.length > 2
                || (row.masterRoles.length == 2 && row.masterRoles[0] == row.masterRoles[1])) {
                revert StreamMediaMasterTypes.InvalidMasterWitness();
            }
            // Duplicate object IDs would create ambiguous scope; this narrower profile rejects them.
            for (uint256 j; j < i; ++j) {
                if (v.mediaObjects[j].objectId == row.objectId) {
                    revert StreamMediaMasterTypes.InvalidMasterWitness();
                }
            }
            string memory roles = string.concat("[", roleJSON(row.masterRoles[0]));
            if (row.masterRoles.length == 2) roles = string.concat(roles, ",", roleJSON(row.masterRoles[1]));
            rows[i] = bytes(string.concat(
                '{"masterRoles":', roles, '],"mediaClass":', mediaClassJSON(row.mediaClass),
                ',"objectId":', StreamRecordJson.hexValue(row.objectId), "}"
            ));
        }
        return StreamConservationRecordFields.requirePayloadSize(bytes(string.concat(
            '{"artist":', artistJSON(v.artist),
            ',"predecessor":', v.predecessor == 0 ? "null" : StreamRecordJson.hexValue(v.predecessor),
            ',"reason":', StreamRecordJson.quote(v.reason, 16384, false),
            ',"scope":{"mediaObjects":', StreamConservationRecordFields.arrayJSON(rows),
            ',"subjectId":', StreamRecordJson.hexValue(v.scopeSubjectId), '},"subjectId":',
            StreamRecordJson.hexValue(v.subjectId), ',"version":1,"waiverStatement":',
            StreamConservationRecordFields.referenceJSON(v.waiverStatement), "}"
        )));
    }

    function master(StreamMediaMasterTypes.Master memory v) public pure returns (bytes memory) {
        if (v.subjectId == 0 || v.selectedMediaManifestHash == 0 || v.mediaSlot == 0
            || v.mediaSlot > 3 || v.displayHash == 0 || v.masterObjectHash == 0 || v.coverageHash == 0) {
            revert StreamMediaMasterTypes.InvalidMasterWitness();
        }
        return StreamConservationRecordFields.requirePayloadSize(bytes(string.concat(
            '{"coverageHash":', StreamRecordJson.hexValue(v.coverageHash),
            ',"displayHash":', StreamRecordJson.hexValue(v.displayHash),
            ',"masterObjectHash":', StreamRecordJson.hexValue(v.masterObjectHash),
            ',"masterRole":', roleJSON(v.masterRole), ',"mediaSlot":',
            string(abi.encodePacked(bytes1(uint8(48 + v.mediaSlot)))),
            ',"predecessor":', v.predecessor == 0 ? "null" : StreamRecordJson.hexValue(v.predecessor),
            ',"selectedMediaManifestHash":', StreamRecordJson.hexValue(v.selectedMediaManifestHash),
            ',"subjectId":', StreamRecordJson.hexValue(v.subjectId), ',"version":1}'
        )));
    }
}
