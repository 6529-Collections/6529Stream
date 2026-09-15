// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamNativeSaleCredits as C
} from "../../interfaces/stream/mint/IStreamNativeSaleCredits.sol";
import { StreamNativeSaleCreditIndex as Index } from "./StreamNativeSaleCreditIndex.sol";
import { StreamClearingSaleBook as Clearing } from "./StreamClearingSaleBook.sol";
import { StreamClearingCeilingBook as Ceiling } from "./StreamClearingCeilingBook.sol";
import { StreamRefundWindowBookStore as Window } from "./StreamRefundWindowBookStore.sol";
import { StreamPrivateSaleAccounting as Private } from "./StreamPrivateSaleAccounting.sol";
import {
    StreamNativeEnglishAuctionState as Auction
} from "../auctions/StreamNativeEnglishAuctionState.sol";
import {
    IStreamNativeEnglishAuction as A
} from "../../interfaces/stream/auctions/IStreamNativeEnglishAuction.sol";
import {
    IStreamNativeRefundWindowSale as W
} from "../../interfaces/stream/mint/IStreamNativeRefundWindowSale.sol";

/// @notice Original-ledger reads only. Fixed delegatecalls preserve host storage/address and never read providers.
library StreamNativeSaleCreditReads {
    using Ceiling for Ceiling.Tree;

    function fixedRead(
        mapping(bytes32 => mapping(address => uint256)) storage credits,
        bytes32[] storage sales,
        address[] storage accounts,
        uint256 liabilities,
        bytes calldata data
    ) public view returns (bytes memory) {
        if (_state(data)) return _summary(accounts.length, liabilities);
        (uint256 index, uint256 cursor,) = _args(data);
        if (cursor != 0 || index >= accounts.length || sales.length != accounts.length) {
            revert C.NativeSaleCreditPageInvalid();
        }
        C.CreditPage memory p;
        p.saleId = sales[index];
        p.account = accounts[index];
        p.owed = credits[p.saleId][p.account];
        p.claimable = p.owed;
        return abi.encode(p);
    }

    function dutchRead(
        mapping(bytes32 => mapping(address => uint256)) storage credits,
        uint256 liabilities,
        bytes calldata data
    ) public view returns (bytes memory) {
        if (_state(data)) return _summary(Index.count(), liabilities);
        C.CreditPage memory p = _single(data);
        p.owed = credits[p.saleId][p.account];
        p.claimable = p.owed;
        return abi.encode(p);
    }

    function privateRead(Private.State storage book, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        if (_state(data)) return _summary(Index.count(), book.totalLiabilities);
        C.CreditPage memory p = _single(data);
        p.owed = Private.balance(book, p.saleId, p.account);
        p.claimable = p.owed;
        return abi.encode(p);
    }

    function auctionRead(Auction.State storage book, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        if (_state(data)) return _summary(Index.count(), book.liabilities);
        C.CreditPage memory p = _single(data);
        p.claimable = book.credits[p.saleId][p.account];
        p.owed = p.claimable;
        A.Auction storage sale = book.auctions[book.auctionBySale[p.saleId]];
        if (sale.status == 1 && sale.winner.payer == p.account) {
            p.owed += sale.winner.amount + sale.winner.revealFee;
        }
        return abi.encode(p);
    }

    function clearingRead(Clearing.State storage book, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        if (_state(data)) return _summary(Index.count(), book.totalBuyerLiability);
        C.CreditPage memory p = _single(data);
        Clearing.Buyer storage buyer = book.buyers[p.saleId][p.account];
        // Includes still-locked supplemental funding; the existing getter intentionally exposes only claims.
        p.owed = buyer.excessCredit + buyer.paidSum - buyer.ceilings.count()
            * book.sales[p.saleId].floorPrice - buyer.settledSupplement - buyer.claimedEntitlement;
        p.claimable = Clearing.refundableBalance(book, p.saleId, p.account);
        return abi.encode(p);
    }

    function windowRead(Window.State storage book, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        if (_state(data)) return _summary(Index.count(), book.totalBuyerLiabilities);
        (uint256 index, uint256 cursor, uint256 limit) = _args(data);
        C.CreditPage memory p;
        (p.saleId, p.account) = Index.key(index);
        uint256 count = book.lastPurchaseNonce[p.saleId][p.account];
        if (cursor >= count && cursor != 0) revert C.NativeSaleCreditPageInvalid();
        if (cursor == 0) {
            p.claimable = book.saleRefundCredit[p.saleId][p.account];
            p.owed = p.claimable;
        }
        uint256 end = count - cursor > limit ? cursor + limit : count;
        for (uint256 n = cursor; n < end;) {
            ++n;
            bytes32 id = keccak256(
                abi.encode(
                    keccak256("6529STREAM_SALE_PURCHASE_V1"),
                    block.chainid,
                    address(this),
                    p.saleId,
                    p.account,
                    n
                )
            );
            W.RefundPurchaseRecord storage purchase = book._purchases[id];
            if (
                purchase.status == 0 || purchase.authorization.saleId != p.saleId
                    || purchase.authorization.payer != p.account
                    || purchase.authorization.purchaseNonce != n
            ) revert C.NativeSaleCreditPageInvalid();
            if (purchase.status == 1) p.owed += purchase.authorization.price
            + purchase.savedRevealFee;
        }
        if (end < count) p.nextCursor = end;
        return abi.encode(p);
    }

    function _summary(uint256 count, uint256 liabilities) private view returns (bytes memory) {
        return abi.encode(C.CreditState(count, liabilities, address(this).balance));
    }

    function _state(bytes calldata data) private pure returns (bool) {
        return bytes4(data) == C.nativeSaleCreditState.selector;
    }

    function _args(bytes calldata data)
        private
        pure
        returns (uint256 index, uint256 cursor, uint256 limit)
    {
        if (bytes4(data) != C.nativeSaleCreditPage.selector) {
            revert C.NativeSaleCreditPageInvalid();
        }
        (index, cursor, limit) = abi.decode(data[4:], (uint256, uint256, uint256));
        if (limit == 0 || limit > 64) revert C.NativeSaleCreditPageInvalid();
    }

    function _single(bytes calldata data) private view returns (C.CreditPage memory p) {
        (uint256 index, uint256 cursor,) = _args(data);
        if (cursor != 0) revert C.NativeSaleCreditPageInvalid();
        (p.saleId, p.account) = Index.key(index);
    }
}
