// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintManager.sol";
import "./StreamERC20OfferMintTypes.sol";
import "../revenue/StreamPrimarySettlementTypes.sol";

/// @notice Positive ERC20 PROFILE offers, original order-one settlement, and zero native fees.
interface IStreamERC20OfferMint {
    function previewERC20OfferMintOperation(
        IStreamMintManager.MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData calldata offerData
    ) external view returns (bytes32 operationRoot, bytes32[] memory operationIds);

    /// @dev Requires the selected official recorder's exact receipt before consuming the offer ticket.
    function executeERC20OfferMint(
        IStreamMintManager.MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData calldata offerData,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate
    )
        external
        returns (uint256[] memory tokenIds, bytes32 operationRoot, bytes32[] memory operationIds);
}

/// @notice Seller membership and live delegation reads; no native-refund capability is implied.
interface IStreamERC20OfferSale {
    /// @notice Immutable settlement facts from the same retained record as seller membership.
    function primaryOfferSettlementBinding(bytes32 saleId)
        external
        view
        returns (uint256 saleNonce, address poster, bytes32 saleConfigHash);

    function primaryOfferAuthorizationBinding(bytes32 saleId)
        external
        view
        returns (
            uint256 collectionId,
            bytes32 phaseId,
            address signer,
            uint8 signerKind,
            bytes32 saleConfigHash
        );

    function offerDelegationConfiguration()
        external
        view
        returns (IStreamNativeRefundDelegatedClaims.DelegationConfiguration memory);
}
