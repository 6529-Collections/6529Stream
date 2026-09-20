// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGeneralAttestationDefinitions.sol";
import "../records/StreamOwnerNoticeFields.sol";
import {
    IStreamGeneralAttestations as A
} from "../../interfaces/stream/metadata/IStreamGeneralAttestations.sol";

library StreamGeneralAttestationJSON {
    function notarization(A.Notarization calldata n) public pure returns (bytes memory payload) {
        if (n.artistId == 0 || n.operativeIdentityRecordHash == 0) {
            revert A.InvalidGeneralAttestation();
        }
        payload = bytes(
            string.concat(
                '{"artistId":',
                StreamRecordJson.hexValue(n.artistId),
                ',"instrumentRef":',
                StreamOwnerNoticeFields.referenceJSON(n.instrumentRef),
                ',"legalPersonRef":',
                StreamOwnerNoticeFields.referenceJSON(n.legalPersonRef),
                ',"officiatingAuthorityIdentityRef":',
                StreamOwnerNoticeFields.referenceJSON(n.officiatingAuthorityIdentityRef),
                ',"operativeIdentityRecordHash":',
                StreamRecordJson.hexValue(n.operativeIdentityRecordHash),
                ',"profileHash":',
                StreamRecordJson.hexValue(StreamGeneralAttestationDefinitions.PROFILE_HASH),
                ',"verifyingInstitutionIdentityRef":',
                StreamOwnerNoticeFields.referenceJSON(n.verifyingInstitutionIdentityRef),
                ',"version":1}'
            )
        );
        if (payload.length > 8192) revert A.InvalidGeneralAttestation();
    }
}
