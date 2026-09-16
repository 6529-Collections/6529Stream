// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPrivateSaleTypes.sol";

/// @notice Full original primary SaleAuthorization, using the actual Manager/Ledger ticket locus.
interface IStreamMintSaleAuthorizationRevocation {
    function mintSaleAuthorizationId(
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization
    ) external view returns (bytes32);

    /// @dev Direct historical configured signer, or MintTicketRevocation under the original Sales domain.
    function voidMintSaleAuthorization(
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        bytes calldata revocationSignature
    ) external returns (bytes32);
}
