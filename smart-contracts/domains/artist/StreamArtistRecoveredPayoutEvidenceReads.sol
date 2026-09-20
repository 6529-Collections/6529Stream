// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistRecoveryRewindEvidence,
    IStreamArtistRecoveryRewindEvidenceBinding
} from "../../interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";

/// @notice Fixed original-evidence read for recovered Payout collection.
/// @dev Preserves the original runtime, environment and complete record checks.
library StreamArtistRecoveredPayoutEvidenceReads {
    function original(W.EnvironmentV3 memory e, bytes32 record)
        public
        view
        returns (W.PayoutOriginalV3 memory original, bytes32 evidenceHash)
    {
        (address target, bytes32 pin) = IStreamArtistRecoveryRewindEvidenceBinding(e.identityOwner)
            .recoveryRewindEvidenceBinding();
        if (pin == 0 || target.code.length == 0 || target.codehash != pin) {
            revert P.InvalidRecoveredPayout(record);
        }
        IStreamArtistRecoveryRewindEvidence publisher = IStreamArtistRecoveryRewindEvidence(target);
        if (
            publisher.owner() != e.identityOwner || publisher.payoutOwner() != e.payoutOwner
                || publisher.artistRegistry() != e.registry
                || publisher.deploymentChainId() != e.chainId
                || publisher.coordinator() != e.coordinator || publisher.archive() != e.archive
                || publisher.core() != e.core || publisher.mintManager() != e.manager
        ) {
            revert P.InvalidRecoveredPayout(record);
        }
        bytes32 identityPin;
        bytes32 payoutPin;
        (original, evidenceHash, identityPin, payoutPin) = publisher.payoutOriginalV3(record);
        if (
            identityPin != e.identityCodeHash || payoutPin != e.payoutCodeHash
                || original.recordHash != record
                || evidenceHash != W.payoutOriginalHash(e, original)
        ) {
            revert P.InvalidRecoveredPayout(record);
        }
    }
}
