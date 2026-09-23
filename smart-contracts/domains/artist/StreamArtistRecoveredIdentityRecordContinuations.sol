// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";

/// @notice Original complete Identity continuations getter comparisons.
library StreamArtistRecoveredIdentityRecordContinuations {
    function validate(address owner, IH.Bundle calldata b) public view {
        for (uint256 i; i < b.originalContinuations.length; ++i) {
            bytes32 key = b.originalContinuations[i].continuation.continuationHash;
            _same(
                abi.encode(b.originalContinuations[i].continuation),
                abi.encode(
                    IStreamArtistIdentityDismissalOwner(owner).identityRevisionContinuation(key)
                ),
                key
            );
        }
        for (uint256 i; i < b.revisionContinuations.length; ++i) {
            bytes32 key = b.revisionContinuations[i].continuation.continuationHash;
            _same(
                abi.encode(b.revisionContinuations[i].continuation),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryRevisionContinuationV3(key)
                ),
                key
            );
        }
        for (uint256 i; i < b.standingContinuations.length; ++i) {
            bytes32 key = b.standingContinuations[i].continuation.continuationHash;
            _same(
                abi.encode(b.standingContinuations[i].continuation),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwnerV3(owner).recoveryStandingContinuationV3(key)
                ),
                key
            );
        }
        for (uint256 i; i < b.capabilityContinuations.length; ++i) {
            bytes32 key = b.capabilityContinuations[i].continuation.recoveryRecordHash;
            _same(
                abi.encode(b.capabilityContinuations[i].continuation),
                abi.encode(
                    IStreamArtistIdentityRecoveryOwnerV3(owner)
                        .recoveryCapabilityContinuationV3(key)
                ),
                key
            );
        }
    }

    function _same(bytes memory a, bytes memory b, bytes32 key) private pure {
        if (keccak256(a) != keccak256(b)) revert IH.InvalidRecoveredIdentity(key);
    }
}
