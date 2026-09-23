// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamDeferredNativeSettlementTypes.sol";

/// @notice Official settlement of an authenticated retained native buyer deposit.
interface IStreamDeferredNativePrimarySaleSettlement {
    function settleDeferredNativePrimarySaleFromAdapter(
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate calldata candidate
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
