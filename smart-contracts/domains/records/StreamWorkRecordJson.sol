// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamWorkRecordFields.sol";

/// @notice Complete WORK_DESCRIPTION fixed-key canonical JSON, never an authority decision.
/// @dev Subject/profile/lineage, original author, actual artist association and complete catalog
///      registration must be checked independently against authenticated record evidence.
library StreamWorkRecordJson {
    error InvalidWorkWitness();

    function serialize(StreamWorkRecordTypes.Description memory d)
        public
        pure
        returns (bytes memory)
    {
        if (d.subjectId == 0 || d.profileHash == 0) revert InvalidWorkWitness();
        string memory out;
        if (d.form == StreamWorkRecordTypes.Form.DESCRIPTION_ABSENT) {
            StreamWorkRecordFields.requireEmptyFull(d.full);
            out = string.concat(
                '{"absence":{"date":',
                StreamRecordJson.date(d.absence.date),
                ',"reason":',
                StreamRecordJson.quote(d.absence.reason, 1024, false),
                '},"form":"description_absent"'
            );
        } else {
            if (bytes(d.absence.reason).length != 0 || d.absence.date != 0) {
                revert InvalidWorkWitness();
            }
            out = _full(d.full);
        }
        out = string.concat(
            out,
            ',"predecessor":',
            d.predecessor == 0 ? "null" : StreamRecordJson.hexValue(d.predecessor),
            ',"profileHash":',
            StreamRecordJson.hexValue(d.profileHash),
            ',"subjectId":',
            StreamRecordJson.hexValue(d.subjectId)
        );
        if (d.form == StreamWorkRecordTypes.Form.FULL) {
            out = string.concat(out, ',"title":', StreamRecordJson.quote(d.full.title, 512, false));
        }
        out = string.concat(out, ',"version":1}');
        if (bytes(out).length > 8192) revert InvalidWorkWitness();
        return bytes(out);
    }

    function requireExact(StreamWorkRecordTypes.Description memory witness, bytes memory stored)
        public
        pure
        returns (bytes32)
    {
        return StreamRecordJson.requirePayload(serialize(witness), stored);
    }

    function _full(StreamWorkRecordTypes.FullDescription memory f)
        private
        pure
        returns (string memory)
    {
        string memory out = string.concat(
            '{"alternateTitles":',
            StreamWorkRecordFields.alternateTitles(f.alternateTitles),
            ',"authorityReferences":',
            StreamWorkRecordFields.authorityReferences(f.authorityReferences)
        );
        out = string.concat(
            out,
            ',"creation":',
            StreamWorkRecordFields.creation(f.creation),
            ',"creator":',
            StreamWorkRecordFields.creator(f.creator),
            ',"creditLine":',
            StreamRecordJson.quote(f.creditLine, 2048, false)
        );
        out = string.concat(
            out,
            ',"edition":',
            StreamWorkRecordFields.edition(f.edition),
            ',"form":"full","format":',
            StreamWorkFormatJson.serialize(f.format)
        );
        if (f.hasInscription) {
            out = string.concat(
                out, ',"inscription":', StreamRecordJson.quote(f.inscription, 1024, false)
            );
        } else if (bytes(f.inscription).length != 0) {
            revert InvalidWorkWitness();
        }
        return string.concat(
            out,
            ',"languageVariants":',
            StreamWorkRecordFields.languageVariants(f),
            ',"measurements":',
            StreamWorkRecordFields.measurements(f.measurements),
            ',"medium":',
            StreamRecordJson.quote(f.medium, 1024, false)
        );
    }
}
