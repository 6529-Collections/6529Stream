// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamOwnerNoticeFields.sol";

/// @notice Complete notice-only designation meaning; owner authority and supersession are external.
library StreamStewardDesignationJson {
    function serialize(StreamOwnerNoticeTypes.Designation memory d)
        public
        pure
        returns (bytes memory)
    {
        if (d.subjectId == 0 || d.profileHash == 0) {
            revert StreamOwnerNoticeFields.InvalidNoticeWitness();
        }
        string memory out = string.concat(
            '{"contactEndpoints":',
            StreamOwnerNoticeFields.contacts(d.contactEndpoints),
            ',"predecessor":',
            d.predecessor == 0 ? "null" : StreamRecordJson.hexValue(d.predecessor),
            ',"profileHash":',
            StreamRecordJson.hexValue(d.profileHash)
        );
        out = string.concat(
            out,
            ',"steward":{"identity":',
            StreamOwnerNoticeFields.referenceJSON(d.identity),
            ',"kind":',
            d.kind == StreamOwnerNoticeTypes.StewardKind.INSTITUTION
                ? '"institution"'
                : '"registrar_contact"',
            ',"name":',
            StreamRecordJson.quote(d.name, 512, false),
            '},"subjectId":',
            StreamRecordJson.hexValue(d.subjectId),
            ',"version":1}'
        );
        if (bytes(out).length > 8192) revert StreamOwnerNoticeFields.InvalidNoticeWitness();
        return bytes(out);
    }

    function requireExact(StreamOwnerNoticeTypes.Designation memory d, bytes memory stored)
        public
        pure
        returns (bytes32)
    {
        return StreamRecordJson.requirePayload(serialize(d), stored);
    }
}
