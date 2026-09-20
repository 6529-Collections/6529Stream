// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryRewindTypes as W } from "./StreamArtistRecoveryRewindTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

interface IStreamArtistRecoveryPayoutOwnerV3 {
    function payoutDesignationRecoveryContinuationV3(bytes32 recordHash)
        external
        view
        returns (bytes32);
    function payoutRecoveryContinuationV3(bytes32 continuationHash)
        external
        view
        returns (W.PayoutContinuationV3 memory);
    function payoutRewindInventoryV3(bytes32 artistId)
        external
        view
        returns (W.PayoutInventoryV3 memory);
    function payoutRecoveryRecordStatusV3(bytes32 recordHash)
        external
        view
        returns (W.StatusV3 memory);
    function applyRecoveryRewindV3(T.ActionContext calldata context, W.PayoutApplyV3 calldata plan)
        external
        returns (bytes32 mutationCommitment);
}
