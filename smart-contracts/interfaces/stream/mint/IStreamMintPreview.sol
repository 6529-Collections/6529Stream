// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintManager.sol";
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Advisory eligibility and counter diagnostics at the actual Manager address.
/// @dev This capability does not change the permanent Manager interface or authorize execution.
interface IStreamMintPreview is IERC165 {
    struct CounterPreview {
        bytes32 counterId;
        bytes32 subjectKey;
        bytes32 valueKey;
        uint64 current;
        uint64 increment;
        uint64 projected;
        uint64 cap;
        bool allowed;
        bytes32 resolutionHash;
    }

    struct MintPreview {
        bool allowed;
        bytes4 reason;
        bytes32 policyHash;
        bytes32 gateHash;
        uint256 quantity;
        CounterPreview[] counters;
    }

    /// @notice The bounded diagnostic evaluation could not return a usable result.
    error MintPreviewUnavailable();

    /// @notice Checks current mint eligibility for an explicit prospective executor.
    /// @dev Successful policyHash is the current policy, even when the request binds valid grace.
    /// Each projected value includes every increment for that valueKey in the whole batch.
    /// A cap denial retains all rows; uint64 overflow returns its error selector and no rows.
    /// Other evaluation failures return their selector and no rows. No state is changed.
    /// This checks shared eligibility, not downstream Core, payment, callbacks or path-specific
    /// royalty snapshot execution. Only the caller-sensitive operation preview supplies identity.
    function canMint(
        IStreamMintManager.MintBatch calldata batch,
        address executor,
        bytes calldata gateData
    ) external view returns (MintPreview memory);
}
