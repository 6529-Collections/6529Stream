// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamDutchPriceSchedule.sol";

/// @notice Deterministic arithmetic and commitment for immutable Dutch schedules.
/// @dev The consumer validates before storing a schedule. A pre-start quote is
/// the starting price; purchase time admission is a separate consumer check.
library StreamDutchPricing {
    bytes32 private constant DOMAIN = keccak256("6529STREAM_DUTCH_SCHEDULE_V1");

    function validate(IStreamDutchPriceSchedule.DutchPriceSchedule memory s, bool declaredFree)
        internal
        pure
    {
        if (
            s.startPrice == 0 || s.startPrice < s.restingPrice || s.endTime <= s.startTime
                || (s.restingPrice == 0 && !declaredFree) || s.decayKind > 1
                || (s.decayKind == 0 && (s.stepSeconds != 0 || s.stepAmount != 0))
                || (s.decayKind == 1 && (s.stepSeconds == 0 || s.stepAmount == 0))
        ) revert IStreamDutchPriceSchedule.DutchScheduleInvalid();
    }

    function scheduleHash(
        IStreamDutchPriceSchedule.DutchPriceSchedule memory s,
        uint256 chainId,
        address adapter,
        bytes32 saleId
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN,
                chainId,
                adapter,
                saleId,
                s.startPrice,
                s.restingPrice,
                s.startTime,
                s.endTime,
                s.decayKind,
                s.stepSeconds,
                s.stepAmount
            )
        );
    }

    /// @dev Requires a schedule accepted by validate. The linear charge rounds
    /// upward, so a declared zero cannot appear before the schedule end.
    /// A stepped schedule reaches rest at end even after a partial last step.
    function price(IStreamDutchPriceSchedule.DutchPriceSchedule memory s, uint256 timestamp)
        internal
        pure
        returns (uint256)
    {
        if (timestamp <= s.startTime) return s.startPrice;
        if (timestamp >= s.endTime) return s.restingPrice;
        uint256 elapsed = timestamp - s.startTime;
        uint256 delta = uint256(s.startPrice) - s.restingPrice;
        if (s.decayKind == 0) {
            return uint256(s.startPrice) - delta * elapsed / (s.endTime - s.startTime);
        }
        // The 96-bit amount times at most a 64-bit interval count fits uint256.
        uint256 reduction = (elapsed / s.stepSeconds) * uint256(s.stepAmount);
        return reduction >= delta ? s.restingPrice : uint256(s.startPrice) - reduction;
    }
}
