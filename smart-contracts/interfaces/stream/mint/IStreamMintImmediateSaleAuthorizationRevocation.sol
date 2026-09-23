// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrivateSaleTypes.sol";

/// @notice Historical canonical Sales-v1 revocation for immediate kinds 0, 1, 3, 12 and 13.
/// @dev FIXED_PRICE, OPEN_EDITION, DUTCH_AUCTION, ZERO_PRICE_CLAIM and PAY_WHAT_YOU_WANT.
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
