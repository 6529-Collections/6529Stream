// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeInventorySale.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Native secondary inventory payment, same original per-sale pull-credit state.
library StreamNativeInventoryPayment {
    event InventoryPurchased(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );
    event ConsignmentSettled(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price,
        uint256 royaltyAmount,
        address royaltyReceiver,
        address consignor
    );
    event PrivateSaleNftDelivery(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address indexed receiver,
        bool delivered
    );
    event ConsignmentRoyaltyDelivery(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed receiver,
        uint256 amount,
        bool delivered
    );

    function purchase(
        StreamNativeInventoryState.State storage self,
        StreamPrivateSaleAccounting.State storage money,
        StreamPrivateSaleSupport.Context memory context,
        bytes32 id,
        uint256 tokenId,
        bytes32 expectedConfigHash
    ) public {
        // Same current host-owned parameters, captured before the original admission/effects phase.
        uint256 royaltyGas = IStreamGasParameterHost(address(this))
            .gasParameter(keccak256("6529STREAM_GGP_SALE_ROYALTY_DELIVERY_GAS_LIMIT"));
        uint256 nftGas = IStreamGasParameterHost(address(this))
            .gasParameter(keccak256("6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT"));
        I.Inventory storage sale = StreamNativeInventorySale.known(self, id);
        P.Sale storage item = StreamNativeInventorySale.token(self, id, tokenId);
        if (
            sale.status != 2 || item.status != 2 || block.timestamp < sale.config.startTime
                || block.timestamp > sale.config.deadline || expectedConfigHash != sale.configHash
                || msg.sender == address(this)
        ) revert I.InventoryTokenUnavailable(id, tokenId);
        if (
            sale.config.perBuyerCap != 0
                && self.purchases[id][msg.sender] >= sale.config.perBuyerCap
        ) {
            revert I.InventoryBuyerCap(id, msg.sender);
        }
        if (msg.value < sale.config.unitPrice) {
            revert P.PrivateSalePaymentTooSmall(sale.config.unitPrice, msg.value);
        }
        if (address(this).balance - msg.value < money.totalLiabilities) {
            revert P.PrivateSaleBalanceMismatch();
        }
        StreamPrivateSaleSupport.requireGas(royaltyGas);
        StreamPrivateSaleSupport.requireGas(nftGas);
        StreamPrivateSaleSupport.requireAdmission(context, sale.createdAt, sale.registryRevision);
        StreamPrivateSaleSupport.requireToken(context, sale.config.collectionId, tokenId);
        if (StreamPrivateSaleSupport.ownerOf(context, tokenId) != address(this)) {
            revert P.CustodyGrantInvalid();
        }
        uint256 oldSurplus = address(this).balance - msg.value - money.totalLiabilities;
        // These effects precede even the read-only royalty quote and all delivery callbacks.
        ++self.purchases[id][msg.sender];
        item.status = 3;
        item.config.buyer = msg.sender;
        item.nftClaim = 1;
        StreamPrivateSaleAccounting.settleRoyalty(money, context, item, id, royaltyGas);
        StreamPrivateSaleSupport.requireAdmission(context, sale.createdAt, sale.registryRevision);
        bool delivered = StreamPrivateSaleSupport.deliverNft(context, tokenId, msg.sender, nftGas);
        if (delivered) item.nftClaim = 0;
        emit PrivateSaleNftDelivery(1, id, tokenId, msg.sender, delivered);
        StreamPrivateSaleSupport.requireAdmission(context, sale.createdAt, sale.registryRevision);
        if (address(this).balance != money.totalLiabilities + oldSurplus) {
            revert P.PrivateSaleBalanceMismatch();
        }
        emit ConsignmentSettled(
            1,
            id,
            tokenId,
            msg.sender,
            sale.config.unitPrice,
            item.royaltyAmount,
            item.royaltyReceiver,
            sale.config.consignor
        );
        emit InventoryPurchased(1, id, tokenId, msg.sender, sale.config.unitPrice);
    }

    function quote(
        StreamNativeInventoryState.State storage self,
        StreamPrivateSaleSupport.Context memory context,
        bytes32 id,
        uint256 tokenId
    ) public view returns (address, uint256, bool, bool) {
        P.Sale storage item = StreamNativeInventorySale.token(self, id, tokenId);
        if (item.status == 3) return (item.royaltyReceiver, item.royaltyAmount, true, true);
        (address receiver, uint256 amount) =
            StreamPrivateSaleSupport.royalty(context, tokenId, item.config.price);
        return (receiver, amount, true, true);
    }

    function retryRoyalty(
        StreamNativeInventoryState.State storage self,
        StreamPrivateSaleAccounting.State storage money,
        bytes32 id,
        address receiver,
        uint256 cap
    ) public returns (bool delivered) {
        StreamNativeInventorySale.known(self, id);
        uint256 amount = money.credits[id][receiver].royalty;
        if (amount == 0) revert P.PrivateSaleClaimUnavailable();
        money.credits[id][receiver].royalty = 0;
        money.totalLiabilities -= amount;
        delivered = StreamPrivateSaleSupport.deliverRoyalty(receiver, amount, cap);
        if (!delivered) {
            money.credits[id][receiver].royalty = amount;
            money.totalLiabilities += amount;
        }
        emit ConsignmentRoyaltyDelivery(1, id, receiver, amount, delivered);
    }
}
