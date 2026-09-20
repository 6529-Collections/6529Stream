// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable historical signer and namespace for a canonical immediate sale.
/// @dev Reads must not depend on live signer membership, sale/phase availability or module admission.
interface IStreamImmediateSaleAuthorizationBinding {
    function immediateSaleAuthorizationBinding(bytes32 saleId)
        external
        view
        returns (
            uint256 collectionId,
            bytes32 phaseId,
            uint8 saleKind,
            uint8 authorityMode,
            bytes32 configHash,
            address authorizer,
            uint8 authorizerKind
        );
}
