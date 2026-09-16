// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleTypes } from "./StreamNativeCuratedSaleTypes.sol";
import { StreamPrivateSaleTypes } from "./StreamPrivateSaleTypes.sol";
import { IStreamPrivateSaleAdapter } from "./IStreamPrivateSaleAdapter.sol";
import { IStreamNativeRefundDelegatedClaims } from "./IStreamNativeRefundDelegatedClaims.sol";
import { IERC5267 } from "../../standards/IERC5267.sol";

/// @notice Buyer-bound positive native primary sale of one prepublished selected work.
/// @dev Uses the original SSA PRIVATE_SALE authorization family. Offers are a separate flow.
interface IStreamNativeCuratedPrivateSale is IERC5267 {
    function configureCollectionSigner(
        uint256 collectionId,
        address signer,
        uint8 signerKind,
        bytes32 evidenceHash,
        bool enabled
    ) external;
    function collectionSigner(uint256 collectionId, address signer, uint8 signerKind)
        external
        view
        returns (StreamNativeCuratedSaleTypes.CollectionSigner memory);
    function privateConfigurationHash(
        StreamNativeCuratedSaleTypes.PrivateConfiguration calldata config
    ) external view returns (bytes32);
    function registerCuratedPrivateSale(
        StreamNativeCuratedSaleTypes.PrivateConfiguration calldata config,
        bytes32[] calldata selectedProof
    ) external returns (bytes32 saleId);
    function privateSaleConfiguration(bytes32 saleId)
        external
        view
        returns (StreamNativeCuratedSaleTypes.PrivateConfiguration memory);
    function purchasePrivateContent(
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata signature,
        StreamNativeCuratedSaleTypes.Selection calldata selection,
        IStreamNativeRefundDelegatedClaims.DelegationWitness calldata witness
    ) external payable returns (StreamNativeCuratedSaleTypes.ExecutionRecord memory);
    function expirePrivateSale(bytes32 saleId) external;
}
