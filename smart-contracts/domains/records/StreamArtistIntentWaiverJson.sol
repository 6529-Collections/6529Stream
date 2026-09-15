// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationRecordFields.sol";

/// @notice Explicit intent waiver still requires an independent explicit interview entry.
library StreamArtistIntentWaiverJson {
    function serialize(StreamConservationRecordTypes.IntentWaiver memory v)
        public
        pure
        returns (bytes memory)
    {
        StreamConservationRecordFields.requireHeader(
            v.subjectId, v.profileHash, StreamConservationDefinitions.WAIVER_PROFILE_HASH
        );
        string memory a = string.concat(
            '{"artist":',
            StreamConservationRecordFields.artistJSON(v.artist),
            ',"interview":',
            StreamConservationRecordFields.interviewJSON(v.interview),
            ',"predecessor":',
            v.predecessor == 0 ? "null" : StreamRecordJson.hexValue(v.predecessor)
        );
        return StreamConservationRecordFields.requirePayloadSize(
            bytes(
                string.concat(
                    a,
                    ',"profileHash":',
                    StreamRecordJson.hexValue(v.profileHash),
                    ',"subjectId":',
                    StreamRecordJson.hexValue(v.subjectId),
                    ',"version":1,"waiverStatement":',
                    StreamConservationRecordFields.referenceJSON(v.waiverStatement),
                    "}"
                )
            )
        );
    }

    function requireExact(StreamConservationRecordTypes.IntentWaiver memory v, bytes memory stored)
        public
        pure
        returns (bytes32)
    {
        return StreamRecordJson.requirePayload(serialize(v), stored);
    }
}
