// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistPayoutRecoveryState as S } from "./StreamArtistPayoutRecoveryState.sol";
import { StreamArtistPayoutRecovery as Recovery } from "./StreamArtistPayoutRecovery.sol";
import {
    IStreamArtistPayoutOwner
} from "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    IStreamArtistPayoutTransitionOwner
} from "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";

/// @notice Fixed ABI encoding for the Payout owner's original six structured reads.
/// @dev All storage references come from the concrete owner; no mutation or caller-selected code.
library StreamArtistPayoutReadEncoding {
    error UnknownPayoutReadSelector(bytes4 selector);

    function read(
        mapping(bytes32 => T.Payout) storage payouts,
        mapping(bytes32 => T.Payout) storage pending,
        mapping(bytes32 => T.PayoutDesignation) storage records,
        mapping(bytes32 => R.ProvisionalAssociation) storage associations,
        S.State storage recovery,
        bytes calldata data
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);
        bytes32 key = abi.decode(data[4:], (bytes32));
        if (selector == IStreamArtistPayoutOwner.designationRecord.selector) {
            return abi.encode(records[key]);
        }
        if (
            selector
                == IStreamArtistPayoutTransitionOwner.payoutDesignationProvisionalAssociation
                .selector
        ) {
            return abi.encode(associations[key]);
        }
        if (selector == IStreamArtistPayoutTransitionOwner.payoutCandidates.selector) {
            T.Payout memory stable = payouts[key];
            T.Payout memory candidate = pending[key];
            return abi.encode(stable, candidate, associations[candidate.recordHash]);
        }
        if (selector == IStreamArtistRecoveryPayoutOwnerV3.payoutRewindInventoryV3.selector) {
            return abi.encode(Recovery.inventory(recovery, payouts, pending, key));
        }
        if (selector == IStreamArtistRecoveryPayoutOwnerV3.payoutRecoveryRecordStatusV3.selector) {
            return abi.encode(recovery.statuses[key]);
        }
        if (selector == IStreamArtistRecoveryPayoutOwnerV3.payoutRecoveryContinuationV3.selector) {
            return abi.encode(recovery.continuations[key]);
        }
        revert UnknownPayoutReadSelector(selector);
    }
}
