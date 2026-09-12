// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPrivateSaleSupport.sol";

/// @notice Per-sale native consignor, buyer-excess and royalty liabilities.
/// @dev Mutable functions execute in the guarded consumer through compiler links. Direct CALL rejects.
library StreamPrivateSaleAccounting {
    struct State {
        uint256 totalLiabilities;
        mapping(bytes32 => mapping(address => P.Credits)) credits;
    }

    event PrivateSaleCreditClaimed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed account,
        address indexed receiver,
        address asset,
        uint256 amount
    );
    event ConsignmentRoyaltyDelivery(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed receiver,
        uint256 amount,
        bool delivered
    );

    function balance(State storage self, bytes32 id, address account)
        internal
        view
        returns (uint256)
    {
        P.Credits storage c = self.credits[id][account];
        return c.excess + c.consignorProceeds + c.royalty;
    }

    function settleRoyalty(
        State storage self,
        StreamPrivateSaleSupport.Context memory context,
        P.Sale storage sale,
        bytes32 id,
        uint256 royaltyGas
    ) public {
        (address receiver, uint256 amount) = StreamPrivateSaleSupport.royalty(
            context, sale.config.tokenId, sale.config.price
        );
        sale.royaltyReceiver = receiver;
        sale.royaltyAmount = amount;
        uint256 proceeds = sale.config.price - amount;
        uint256 excess = msg.value - sale.config.price;
        self.credits[id][sale.config.consignor].consignorProceeds += proceeds;
        self.credits[id][sale.config.buyer].excess += excess;
        self.totalLiabilities += proceeds + excess;
        if (amount != 0) {
            bool delivered = StreamPrivateSaleSupport.deliverRoyalty(receiver, amount, royaltyGas);
            if (!delivered) {
                self.credits[id][receiver].royalty += amount;
                self.totalLiabilities += amount;
            }
            emit ConsignmentRoyaltyDelivery(1, id, receiver, amount, delivered);
        }
    }

    function claim(State storage self, bytes32 id, address receiver) public {
        if (receiver == address(0)) revert P.PrivateSaleClaimUnavailable();
        uint256 amount = balance(self, id, msg.sender);
        if (amount == 0) revert P.PrivateSaleClaimUnavailable();
        delete self.credits[id][msg.sender];
        self.totalLiabilities -= amount;
        uint256 beforeBalance = address(this).balance;
        bool ok;
        assembly ("memory-safe") { ok := call(gas(), receiver, amount, 0, 0, 0, 0) }
        if (!ok) revert P.PrivateSaleClaimFailed();
        if (address(this).balance != beforeBalance - amount) revert P.PrivateSaleBalanceMismatch();
        emit PrivateSaleCreditClaimed(1, id, msg.sender, receiver, address(0), amount);
    }

    function retryRoyalty(State storage self, P.Sale storage sale, bytes32 id, uint256 cap)
        public
        returns (bool delivered)
    {
        address receiver = sale.royaltyReceiver;
        uint256 amount = self.credits[id][receiver].royalty;
        if (sale.status != 3 || amount == 0) revert P.PrivateSaleClaimUnavailable();
        self.credits[id][receiver].royalty = 0;
        self.totalLiabilities -= amount;
        delivered = StreamPrivateSaleSupport.deliverRoyalty(receiver, amount, cap);
        if (!delivered) {
            self.credits[id][receiver].royalty = amount;
            self.totalLiabilities += amount;
        }
        emit ConsignmentRoyaltyDelivery(1, id, receiver, amount, delivered);
    }
}
