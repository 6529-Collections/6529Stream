// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistEntropyFindingHydrationOwner
} from "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    IStreamArtistUnavailabilityOwner
} from "../../interfaces/stream/artist/IStreamArtistUnavailability.sol";
import {
    IStreamArtistEntropyUnavailabilityOwner,
    StreamArtistEntropyUnavailabilityTypes as EU
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";
import {
    StreamArtistRecoveryTypes as Finding
} from "../../interfaces/stream/artist/StreamArtistRecoveryTypes.sol";
import {
    StreamArtistUnavailabilityTypes as U
} from "../../interfaces/stream/artist/StreamArtistUnavailabilityTypes.sol";

/// @notice Original complete Identity findings getter comparisons.
library StreamArtistRecoveredIdentityRecordFindings {
    function validate(address owner, IH.Bundle calldata b) public view {
        for (uint256 i; i < b.findings.length; ++i) {
            IH.FindingRow calldata r = b.findings[i];
            if (r.record.terms.artistId != b.artistId) {
                revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            }
            (Finding.FindingRecord memory record, U.Admission memory admission) = IStreamArtistUnavailabilityOwner(
                    owner
                ).unavailabilityFindingRecord(r.record.recordHash);
            _same(
                abi.encode(r.record, r.admission),
                abi.encode(record, admission),
                r.record.recordHash
            );
            (Finding.FindingRecord memory entropyRecord, EU.Admission memory entropyAdmission) = IStreamArtistEntropyUnavailabilityOwner(
                    owner
                ).entropyUnavailabilityFindingRecord(r.record.recordHash);
            _same(
                abi.encode(r.record, r.entropyAdmission),
                abi.encode(entropyRecord, entropyAdmission),
                r.record.recordHash
            );
            if (
                r.entropyOrigin
                    != IStreamArtistEntropyFindingHydrationOwner(owner)
                        .entropyUnavailabilityFindingOrigin(r.record.recordHash)
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
            if (
                r.latestForCollection
                    != IStreamArtistUnavailabilityOwner(owner)
                        .latestUnavailabilityFinding(b.artistId, r.record.terms.collectionId)
            ) revert IH.InvalidRecoveredIdentity(r.record.recordHash);
        }
    }

    function _same(bytes memory a, bytes memory b, bytes32 key) private pure {
        if (keccak256(a) != keccak256(b)) revert IH.InvalidRecoveredIdentity(key);
    }
}
