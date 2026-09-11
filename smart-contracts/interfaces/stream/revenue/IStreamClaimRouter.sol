// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Stateless aggregation of split-wallet releases to each entitled account itself.
interface IStreamClaimRouter {
    /// @notice One wallet entitlement; account is also the only permitted recipient.
    struct ClaimCall {
        address wallet;
        address asset;
        address account;
    }

    /// @notice The selected wallet has no executable code.
    error ClaimTargetHasNoCode(address wallet);
    /// @notice A successful wallet call did not return exactly one ABI uint256 word.
    error InvalidClaimReturnData(uint256 returnDataSize);
    /// @notice Atomic mode aborts at the first failed wallet operation.
    /// @dev reason is at most 256 bytes; returnDataSize is the original wallet response length.
    error ClaimCallFailed(
        uint256 claimIndex, address wallet, bytes4 operation, uint256 returnDataSize, bytes reason
    );

    /// @notice Continue mode skipped a failed item; zero in the result alone is ambiguous.
    /// @dev reason is a maximum 256-byte revert prefix or a local validation error. The original
    /// wallet response length is returnDataSize. A preceding successful sync is not rolled back.
    event ClaimFailed(
        address indexed wallet,
        address indexed asset,
        address indexed account,
        uint16 schemaVersion,
        uint256 claimIndex,
        bytes4 operation,
        uint256 returnDataSize,
        bytes reason
    );

    /// @notice Calls release(asset, account, account) for each item, in order.
    /// @dev Returns wallet-reported amounts, not independent proof of payment. A failed item is
    /// zero in continue mode; a successful wallet may also report zero. Inspect ClaimFailed.
    function claimMany(ClaimCall[] calldata claims, bool continueOnFailure)
        external
        returns (uint256[] memory releasedAmounts);

    /// @notice Calls syncAsset(asset), then release(asset, account, account), for each item.
    /// @dev A failed sync skips release. Continue mode retains successful earlier calls, including
    /// a sync whose subsequent release fails. Atomic mode rolls back the complete batch.
    function syncAndClaimMany(ClaimCall[] calldata claims, bool continueOnFailure)
        external
        returns (uint256[] memory releasedAmounts);
}
