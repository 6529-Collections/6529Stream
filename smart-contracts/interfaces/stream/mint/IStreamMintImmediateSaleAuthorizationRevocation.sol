// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrivateSaleTypes.sol";

/// @notice Historical canonical FIXED_PRICE/OPEN_EDITION Sales-v1 authorization revocation.
interface IStreamMintImmediateSaleAuthorizationRevocation {
    /// @dev Requires the immutable SIGNED sale binding to the claimed signer and kind (1/2).
    ///      The signer may call directly, or supply MintTicketRevocation under the original Sales
    ///      domain. Expiry and current sale/phase/authority/module state do not condition revocation.
    ///      Uses the existing mintSaleAuthorizationId digest and manager-scoped Ledger void map.
    function voidMintImmediateSaleAuthorization(
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        address claimedAuthorizer,
        uint8 authorizerKind,
        bytes calldata revocationSignature
    ) external returns (bytes32 authorizationId);
}
