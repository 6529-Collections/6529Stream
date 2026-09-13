// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationFormatJson.sol";
import "./StreamConservationLanguage.sol";

/// @notice Complete interview bytes; language grammar does not establish dated registry validity.
library StreamArtistInterviewJson {
    error InvalidConservationInterview();

    function serialize(StreamConservationRecordTypes.Interview memory v)
        public
        pure
        returns (bytes memory)
    {
        StreamConservationRecordFields.requireHeader(
            v.subjectId, v.profileHash, StreamConservationDefinitions.INTERVIEW_PROFILE_HASH
        );
        string memory a = string.concat(
            '{"captures":',
            _captures(v.captures),
            ',"instrument":',
            _instrument(v.instrument),
            ',"interviewDate":',
            StreamRecordJson.date(v.interviewDate),
            ',"languages":',
            StreamConservationLanguage.arrayJSON(v.languages),
            ',"participants":',
            _participants(v.participants)
        );
        return StreamConservationRecordFields.requirePayloadSize(
            bytes(
                string.concat(
                    a,
                    ',"predecessor":',
                    v.predecessor == 0 ? "null" : StreamRecordJson.hexValue(v.predecessor),
                    ',"profileHash":',
                    StreamRecordJson.hexValue(v.profileHash),
                    ',"subjectId":',
                    StreamRecordJson.hexValue(v.subjectId),
                    ',"transcript":',
                    _payload(v.transcript),
                    ',"version":1}'
                )
            )
        );
    }

    function requireExact(StreamConservationRecordTypes.Interview memory v, bytes memory stored)
        public
        pure
        returns (bytes32)
    {
        return StreamRecordJson.requirePayload(serialize(v), stored);
    }

    function _instrument(StreamConservationRecordTypes.Instrument memory v)
        private
        pure
        returns (string memory)
    {
        string memory document = StreamConservationRecordFields.referenceJSON(v.document);
        if (v.kind == StreamConservationRecordTypes.InstrumentKind.VARIABLE_MEDIA_QUESTIONNAIRE) {
            if (bytes(v.name).length != 0) revert InvalidConservationInterview();
            return
                string.concat('{"document":', document, ',"kind":"variable_media_questionnaire"}');
        }
        return string.concat(
            '{"document":',
            document,
            ',"kind":"named_derivative","name":',
            StreamRecordJson.quote(v.name, 512, false),
            "}"
        );
    }

    function _participants(StreamConservationRecordTypes.Participant[] memory values)
        private
        pure
        returns (string memory)
    {
        if (values.length == 0) revert InvalidConservationInterview();
        bytes[] memory rows = new bytes[](values.length);
        for (uint256 i; i < values.length; ++i) {
            StreamConservationRecordTypes.Participant memory v = values[i];
            string memory identity = StreamConservationRecordFields.referenceJSON(v.identity);
            if (v.role == StreamConservationRecordTypes.ParticipantRole.OTHER) {
                rows[i] = bytes(
                    string.concat(
                        '{"identity":',
                        identity,
                        ',"role":"other","roleLabel":',
                        StreamRecordJson.quote(v.otherRole, 128, false),
                        "}"
                    )
                );
            } else {
                if (bytes(v.otherRole).length != 0) revert InvalidConservationInterview();
                rows[i] = bytes(
                    string.concat(
                        '{"identity":',
                        identity,
                        ',"role":',
                        v.role == StreamConservationRecordTypes.ParticipantRole.ARTIST
                            ? '"artist"'
                            : '"interviewer"',
                        "}"
                    )
                );
            }
        }
        return StreamConservationRecordFields.arrayJSON(rows);
    }

    function _captures(StreamConservationRecordTypes.Capture[] memory values)
        private
        pure
        returns (string memory)
    {
        bytes[] memory rows = new bytes[](values.length);
        for (uint256 i; i < values.length; ++i) {
            rows[i] = bytes(
                string.concat(
                    '{"kind":',
                    values[i].kind == StreamConservationRecordTypes.CaptureKind.AUDIO
                        ? '"audio"'
                        : '"video"',
                    ',"payload":',
                    _payload(values[i].payload),
                    "}"
                )
            );
        }
        return StreamConservationRecordFields.arrayJSON(rows);
    }

    function _payload(StreamConservationRecordTypes.Payload memory v)
        private
        pure
        returns (string memory)
    {
        return string.concat(
            '{"content":',
            StreamConservationRecordFields.referenceJSON(v.content),
            ',"format":',
            StreamConservationFormatJson.serialize(v.format),
            "}"
        );
    }
}
