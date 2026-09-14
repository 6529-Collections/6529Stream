// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamNativeEnglishAuction.sol";

/// @notice Retained-row NFTDelegation profile for auction delivery and account-owned claims.
/// @dev Witnesses locate an original live registry row; they convey no caller-authored authority.
interface IStreamNativeAuctionDelegatedDelivery {
    struct DelegationWitness {
        bool walletWide;
        uint256 index;
    }

    function delegateRegistry() external view returns (address);
    function delegateRegistryCodeHash() external view returns (bytes32);
    function delegationUsecase() external view returns (uint256);
    function delegationManifest() external view returns (bytes memory);
    function bidDelivery(bytes32 auctionId, address bidder) external view returns (address);

    function bidForVault(bytes32 auctionId, address vault, DelegationWitness calldata witness)
        external
        payable;
    function bidSignedForVault(
        IStreamNativeEnglishAuction.BidAuthorization calldata authorization,
        bytes calldata signature,
        DelegationWitness calldata witness
    ) external payable;

    /// @notice Trigger only the named account's complete credit, paid to that same account.
    function claimRefundFor(bytes32 saleId, address account, DelegationWitness calldata witness)
        external
        returns (uint256 amount);
    /// @notice Trigger only the named original NFT claimant's delivery to itself.
    function claimNFTFor(bytes32 auctionId, address account, DelegationWitness calldata witness)
        external;
}
