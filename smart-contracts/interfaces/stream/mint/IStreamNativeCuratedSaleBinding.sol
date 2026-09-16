// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable historical signer membership; reads never depend on live sale admission.
interface IStreamNativeCuratedSaleBinding {
    function curatedSaleAuthorizationBinding(bytes32 saleId)
        external
        view
        returns (
            uint256 collectionId,
            bytes32 phaseId,
            address signer,
            uint8 signerKind,
            bytes32 saleConfigHash
        );
}
