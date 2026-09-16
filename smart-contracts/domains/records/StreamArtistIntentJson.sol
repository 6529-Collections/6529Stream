// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationRecordFields.sol";

/// @notice Complete pure intent interpretation; claimed artist origin is not authority evidence.
library StreamArtistIntentJson {
    function serialize(StreamConservationRecordTypes.Intent memory v)
        public
        pure
        returns (bytes memory)
    {
        StreamConservationRecordFields.requireHeader(
            v.subjectId, v.profileHash, StreamConservationDefinitions.INTENT_PROFILE_HASH
        );
        string memory a = string.concat(
            '{"artist":',
            StreamConservationRecordFields.artistJSON(v.artist),
            ',"dependencyAging":',
            StreamConservationRecordFields.referenceJSON(v.dependencyAging),
            ',"display":',
            _display(v.display),
            ',"interview":',
            StreamConservationRecordFields.interviewJSON(v.interview)
        );
        string memory b = string.concat(
            ',"predecessor":',
            v.predecessor == 0 ? "null" : StreamRecordJson.hexValue(v.predecessor),
            ',"profileHash":',
            StreamRecordJson.hexValue(v.profileHash),
            ',"significantProperties":',
            StreamConservationRecordFields.referenceJSON(v.significantProperties),
            ',"subjectId":',
            StreamRecordJson.hexValue(v.subjectId),
            ',"variabilityTolerances":',
            StreamConservationRecordFields.referenceJSON(v.variabilityTolerances),
            ',"version":1}'
        );
        return StreamConservationRecordFields.requirePayloadSize(bytes(string.concat(a, b)));
    }

    function requireExact(StreamConservationRecordTypes.Intent memory v, bytes memory stored)
        public
        pure
        returns (bytes32)
    {
        return StreamRecordJson.requirePayload(serialize(v), stored);
    }

    function _display(StreamConservationRecordTypes.Display memory d)
        private
        pure
        returns (string memory)
    {
        string memory a = string.concat(
            '{"color":',
            StreamConservationRecordFields.referenceJSON(d.color),
            ',"frameRate":',
            StreamConservationRecordFields.referenceJSON(d.frameRate),
            ',"interaction":',
            StreamConservationRecordFields.referenceJSON(d.interaction)
        );
        return string.concat(
            a,
            ',"motion":',
            StreamConservationRecordFields.referenceJSON(d.motion),
            ',"scale":',
            StreamConservationRecordFields.referenceJSON(d.scale),
            ',"timing":',
            StreamConservationRecordFields.referenceJSON(d.timing),
            "}"
        );
    }
}
