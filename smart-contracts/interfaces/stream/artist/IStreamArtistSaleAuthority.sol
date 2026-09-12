// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistSaleTypes as Sale } from "./StreamArtistSaleTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Canonical current-profile sale-parameter consent, separate from mint policy and economics.
interface IStreamArtistSaleAuthority {
    function recordSaleConsent(Sale.Consent calldata p, T.Authorization calldata a)
        external
        returns (bytes32);
    function saleConsentDigest(Sale.Consent calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
    function saleConsentScope(uint256 collectionId) external view returns (uint8);
    /// @notice Historical recorded evidence; true is not a current adapter authorization result.
    function isSaleConsented(uint256 collectionId, bytes32 saleId, bytes32 saleConfigHash)
        external
        view
        returns (bool consented, bytes32 consentRecordHash);
    /// @notice Checks the calling adapter over its exact current stored configuration when elected.
    function requireSaleConsent(uint256 collectionId, bytes32 saleId, bytes32 saleConfigHash)
        external
        view;
    function saleConsentRecord(bytes32 recordHash) external view returns (Sale.Record memory);
}

interface IStreamArtistSaleCoordinator {
    function coordinateRecordSaleConsent(
        address actor,
        Sale.Consent calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
}
