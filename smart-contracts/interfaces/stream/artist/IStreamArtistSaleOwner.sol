// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistSaleTypes as Sale } from "./StreamArtistSaleTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";

interface IStreamArtistSaleIdentityOwner {
    function consumeSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
}

interface IStreamArtistSaleConsentOwner {
    function recordSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32);
    function saleConsentRecord(bytes32 recordHash) external view returns (Sale.Record memory);
    function saleConsentAt(uint256 collectionId, bytes32 saleId, bytes32 saleConfigHash)
        external
        view
        returns (bytes32);
}
