// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamOwnerNoticeFields.sol";

/// @notice Complete response meaning shared by owner and independent authenticated carriers.
/// @dev No payload field proves owner standing, a scheduled recovery, timeliness or a veto.
library StreamRecoveryResponseJson {
    function serialize(StreamOwnerNoticeTypes.Response memory r)
        public
        pure
        returns (bytes memory)
    {
        if (
            r.subjectId == 0 || r.profileHash == 0 || r.recoveryId == 0
                || r.recoveryManifestHash == 0
        ) revert StreamOwnerNoticeFields.InvalidNoticeWitness();
        string memory out = string.concat(
            '{"evidenceReferences":',
            StreamOwnerNoticeFields.references(r.evidenceReferences),
            ',"grounds":',
            StreamRecordJson.quote(r.grounds, 2048, false),
            ',"profileHash":',
            StreamRecordJson.hexValue(r.profileHash),
            ',"recoveryId":',
            StreamRecordJson.hexValue(r.recoveryId)
        );
        out = string.concat(
            out,
            ',"recoveryManifestHash":',
            StreamRecordJson.hexValue(r.recoveryManifestHash),
            ',"response":',
            r.response == StreamOwnerNoticeTypes.ResponseClass.ACKNOWLEDGED
                ? '"acknowledged"'
                : '"objected"',
            ',"subjectId":',
            StreamRecordJson.hexValue(r.subjectId),
            ',"version":1}'
        );
        if (bytes(out).length > 8192) revert StreamOwnerNoticeFields.InvalidNoticeWitness();
        return bytes(out);
    }

    function requireExact(StreamOwnerNoticeTypes.Response memory r, bytes memory stored)
        public
        pure
        returns (bytes32)
    {
        return StreamRecordJson.requirePayload(serialize(r), stored);
    }
}
