// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable registered sale facts for artist sale-parameter consent.
/// @dev This read supplies no consent or execution authority. The artist facade independently
///      validates the actual adapter/Core/module identity before accepting these facts.
interface IStreamArtistSaleFacts {
    error SaleConsentFactsUnavailable(bytes32 saleId);

    /// @notice Exact two-word facts for a registered sale, including its complete config hash.
    /// @dev Missing records revert; zero hashes and caller-supplied configuration are unsupported.
    function saleConsentFacts(bytes32 saleId)
        external
        view
        returns (uint256 collectionId, bytes32 saleConfigHash);
}
