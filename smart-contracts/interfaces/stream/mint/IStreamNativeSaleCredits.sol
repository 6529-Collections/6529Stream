// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Complete producer-owned historical native liability keys; these reads grant no claims.
interface IStreamNativeSaleCredits {
    struct CreditState {
        uint256 accountCount;
        uint256 totalLiabilities;
        uint256 balance;
    }

    /// @dev Sum disjoint pages at one block. nextCursor=0 is terminal; claimable is a subset of owed.
    struct CreditPage {
        bytes32 saleId;
        address account;
        uint256 owed;
        uint256 claimable;
        uint256 nextCursor;
    }
    error NativeSaleCreditPageInvalid();
    event NativeSaleCreditAccountIndexed(
        uint16 schemaVersion, uint256 indexed index, bytes32 indexed saleId, address indexed account
    );
    function nativeSaleCreditState() external view returns (CreditState memory);
    /// @param limit Maximum original purchase records inspected, 1..64. Start at cursor=0.
    function nativeSaleCreditPage(uint256 index, uint256 cursor, uint256 limit)
        external
        view
        returns (CreditPage memory);
}
