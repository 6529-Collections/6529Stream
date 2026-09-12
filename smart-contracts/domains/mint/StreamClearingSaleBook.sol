// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamClearingCeilingBook.sol";

/// @notice Clearing custody accounting; authorization, money calls and clocks belong to the consumer.
/// @dev A purchase is recorded atomically with its floor mint. Failed external settlement or claim
/// reverts the entire caller frame, including these accounting changes. No global buyer loop exists.
library StreamClearingSaleBook {
    using StreamClearingCeilingBook for StreamClearingCeilingBook.Tree;

    uint8 internal constant OPEN = 1;
    uint8 internal constant PRICE_FIXED = 2;
    uint8 internal constant ALL_FINANCIAL_TERMINAL = 3;
    uint8 internal constant REFUND_UNLOCKED = 4;

    struct Sale {
        uint8 status;
        uint96 startPrice;
        uint96 floorPrice;
        uint64 maximumQuantity;
        uint64 purchasedQuantity;
        uint64 floorCeilingQuantity;
        uint64 positiveLegs;
        uint64 settledLegs;
        uint256 lowestAcceptedSchedule;
        uint256 clearingPrice;
        uint256 buyerLiability;
        uint256 scheduledSupplement;
        uint256 settledSupplement;
    }

    struct Buyer {
        StreamClearingCeilingBook.Tree ceilings;
        uint256 lastPurchaseNonce;
        uint256 paidSum;
        uint256 settledSupplement;
        uint256 claimedEntitlement;
        uint256 excessCredit;
        uint256 announcedRebate;
    }

    struct Purchase {
        bytes32 saleId;
        address buyer;
        uint256 nonce;
        uint96 paidPrice;
        uint96 normalizedCeiling;
        bool inFlight;
        bool supplementalSettled;
    }

    struct State {
        mapping(bytes32 => Sale) sales;
        mapping(bytes32 => StreamClearingCeilingBook.Tree) saleCeilings;
        mapping(bytes32 => mapping(address => Buyer)) buyers;
        mapping(bytes32 => Purchase) purchases;
        uint256 totalBuyerLiability;
        bytes32 activePurchase;
    }

    struct PurchaseInput {
        bytes32 saleId;
        bytes32 purchaseId;
        address buyer;
        uint256 nonce;
        uint256 schedulePrice;
        uint256 paidPrice;
        bool hasPriceOverride;
        uint256 priceOverride;
        uint256 excess;
    }

    error ClearingBookInvalid();
    error ClearingBookSaleUnavailable(bytes32 saleId);
    error ClearingBookPurchaseUnavailable(bytes32 purchaseId);
    error ClearingBookNonceInvalid(uint256 expected, uint256 supplied);
    error ClearingBookNoSupplement(bytes32 purchaseId);
    error ClearingBookCreditExceeded(uint256 available, uint256 requested);

    function configure(State storage book, bytes32 id, uint96 start, uint96 floor, uint64 maximum)
        public
    {
        if (id == 0 || floor == 0 || start < floor || maximum == 0 || book.sales[id].status != 0) {
            revert ClearingBookInvalid();
        }
        Sale storage sale = book.sales[id];
        sale.status = OPEN;
        sale.startPrice = start;
        sale.floorPrice = floor;
        sale.maximumQuantity = maximum;
        sale.lowestAcceptedSchedule = start;
    }

    function record(State storage book, PurchaseInput memory p) public {
        Sale storage sale = book.sales[p.saleId];
        if (sale.status != OPEN || sale.purchasedQuantity == sale.maximumQuantity) {
            revert ClearingBookSaleUnavailable(p.saleId);
        }
        if (
            p.purchaseId == 0 || p.buyer == address(0)
                || book.purchases[p.purchaseId].buyer != address(0)
                || p.schedulePrice < sale.floorPrice || p.schedulePrice > sale.startPrice
                || p.schedulePrice > sale.lowestAcceptedSchedule
                || (!p.hasPriceOverride && p.priceOverride != 0)
        ) revert ClearingBookInvalid();
        uint256 ceiling = StreamClearingCeilingBook.normalize(
            sale.startPrice, p.hasPriceOverride, p.priceOverride
        );
        uint256 charge = p.schedulePrice < ceiling ? p.schedulePrice : ceiling;
        if (ceiling < sale.floorPrice || p.paidPrice != charge) revert ClearingBookInvalid();
        Buyer storage buyer = book.buyers[p.saleId][p.buyer];
        uint256 next = buyer.lastPurchaseNonce + 1;
        if (p.nonce != next) revert ClearingBookNonceInvalid(next, p.nonce);
        buyer.ceilings.record(ceiling, sale.maximumQuantity);
        book.saleCeilings[p.saleId].record(ceiling, sale.maximumQuantity);
        buyer.lastPurchaseNonce = next;
        buyer.paidSum += charge;
        buyer.excessCredit += p.excess;
        ++sale.purchasedQuantity;
        if (ceiling == sale.floorPrice) ++sale.floorCeilingQuantity;
        sale.lowestAcceptedSchedule = p.schedulePrice;
        uint256 liability = charge - sale.floorPrice + p.excess;
        sale.buyerLiability += liability;
        book.totalBuyerLiability += liability;
        book.purchases[p.purchaseId] =
            Purchase(p.saleId, p.buyer, p.nonce, uint96(charge), uint96(ceiling), false, false);
    }

    function fixPrice(State storage book, bytes32 id, uint256 clearing) public {
        Sale storage sale = book.sales[id];
        if (sale.status != OPEN) revert ClearingBookSaleUnavailable(id);
        if (clearing < sale.floorPrice || clearing > sale.lowestAcceptedSchedule) {
            revert ClearingBookInvalid();
        }
        sale.clearingPrice = clearing;
        sale.scheduledSupplement = book.saleCeilings[id].uniformSum(clearing)
            - uint256(sale.purchasedQuantity) * sale.floorPrice;
        sale.positiveLegs =
            clearing == sale.floorPrice ? 0 : sale.purchasedQuantity - sale.floorCeilingQuantity;
        sale.status = sale.positiveLegs == 0 ? ALL_FINANCIAL_TERMINAL : PRICE_FIXED;
    }

    function uniformPrice(State storage book, bytes32 purchaseId) public view returns (uint256) {
        Purchase storage p = book.purchases[purchaseId];
        if (p.buyer == address(0)) revert ClearingBookPurchaseUnavailable(purchaseId);
        Sale storage sale = book.sales[p.saleId];
        if (sale.clearingPrice == 0) revert ClearingBookSaleUnavailable(p.saleId);
        return sale.clearingPrice < p.normalizedCeiling ? sale.clearingPrice : p.normalizedCeiling;
    }

    function beginSupplement(State storage book, bytes32 purchaseId)
        public
        returns (uint256 amount)
    {
        Purchase storage p = book.purchases[purchaseId];
        if (
            p.buyer == address(0) || p.supplementalSettled || p.inFlight || book.activePurchase != 0
        ) {
            revert ClearingBookPurchaseUnavailable(purchaseId);
        }
        Sale storage sale = book.sales[p.saleId];
        if (sale.status != PRICE_FIXED) revert ClearingBookSaleUnavailable(p.saleId);
        amount = uniformPrice(book, purchaseId) - sale.floorPrice;
        if (amount == 0) revert ClearingBookNoSupplement(purchaseId);
        p.inFlight = true;
        book.activePurchase = purchaseId;
        book.buyers[p.saleId][p.buyer].settledSupplement += amount;
        sale.settledSupplement += amount;
        ++sale.settledLegs;
        sale.buyerLiability -= amount;
        book.totalBuyerLiability -= amount;
    }

    function finishSupplement(State storage book, bytes32 purchaseId) public {
        Purchase storage p = book.purchases[purchaseId];
        if (!p.inFlight || book.activePurchase != purchaseId) {
            revert ClearingBookPurchaseUnavailable(purchaseId);
        }
        p.inFlight = false;
        p.supplementalSettled = true;
        book.activePurchase = 0;
        Sale storage sale = book.sales[p.saleId];
        if (sale.settledLegs == sale.positiveLegs) sale.status = ALL_FINANCIAL_TERMINAL;
    }

    /// @dev The consumer proves a permitted time/permanent reason first. This only changes credits.
    function unlock(State storage book, bytes32 id) public {
        Sale storage sale = book.sales[id];
        if ((sale.status != OPEN && sale.status != PRICE_FIXED) || book.activePurchase != 0) {
            revert ClearingBookSaleUnavailable(id);
        }
        sale.status = REFUND_UNLOCKED;
    }

    function refundableBalance(State storage book, bytes32 id, address account)
        public
        view
        returns (uint256)
    {
        Sale storage sale = book.sales[id];
        Buyer storage buyer = book.buyers[id][account];
        uint256 entitlement;
        if (sale.status == REFUND_UNLOCKED) {
            entitlement =
                buyer.paidSum - buyer.ceilings.count() * sale.floorPrice - buyer.settledSupplement;
        } else if (sale.status == PRICE_FIXED || sale.status == ALL_FINANCIAL_TERMINAL) {
            entitlement = buyer.paidSum - buyer.ceilings.uniformSum(sale.clearingPrice);
        }
        return buyer.excessCredit + entitlement - buyer.claimedEntitlement;
    }

    function debitClaim(State storage book, bytes32 id, address account, uint256 amount) public {
        uint256 available = refundableBalance(book, id, account);
        if (amount == 0 || amount > available) {
            revert ClearingBookCreditExceeded(available, amount);
        }
        Buyer storage buyer = book.buyers[id][account];
        uint256 excess = amount < buyer.excessCredit ? amount : buyer.excessCredit;
        buyer.excessCredit -= excess;
        buyer.claimedEntitlement += amount - excess;
        book.sales[id].buyerLiability -= amount;
        book.totalBuyerLiability -= amount;
    }

    /// @dev Entitlement and claims never depend on this idempotent event-accounting seam.
    function announceRebate(State storage book, bytes32 id, address account)
        public
        returns (uint256 newlyAnnounced)
    {
        Sale storage sale = book.sales[id];
        if (sale.clearingPrice == 0) return 0;
        Buyer storage buyer = book.buyers[id][account];
        uint256 rebate = buyer.paidSum - buyer.ceilings.uniformSum(sale.clearingPrice);
        newlyAnnounced = rebate - buyer.announcedRebate;
        buyer.announcedRebate = rebate;
    }
}
