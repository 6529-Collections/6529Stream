// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamRefundWindowBook.sol";

interface RefundBookVm {
    function warp(uint256 timestamp) external;
    function deal(address account, uint256 amount) external;
    function prank(address caller) external;
    function expectRevert(bytes calldata reason) external;
}

/// @dev Bookkeeping harness only. No signature, registry, role, mint or official settlement proof.
contract RefundBookHarness is StreamRefundWindowBook {
    uint256 public fee = 5;
    address payable private constant SINK = payable(address(0xF00D));

    function configureViaLibrary(RefundSaleConfig calldata c) external returns (bytes32) {
        return StreamRefundWindowBookStore.configure(
            _book,
            c,
            StreamNativeSettlementTypes.SaleLifecycleBinding(1000, 1),
            2,
            bytes32(uint256(99)),
            bytes32(uint256(100))
        );
    }

    function globalPauseViaLibrary(bool paused) external {
        StreamRefundWindowBookStore.setGlobalPause(_book, paused, bytes32(uint256(9)));
    }

    function setFee(uint256 value) external {
        fee = value;
    }

    function registerRefundSale(RefundSaleConfig calldata c)
        external
        override
        returns (bytes32 id)
    {
        id = keccak256(abi.encode(c));
        _book._refundSales[id].config = c;
        _book._refundSales[id].saleNonce = 1;
        _book._refundSales[id].configHash = id;
    }

    function refundPurchaseAuthorizationDigest(RefundPurchaseAuthorization calldata a)
        external
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encode(a));
    }

    function eip712Domain()
        external
        pure
        override
        returns (bytes1, string memory, string memory, uint256, address, bytes32, uint256[] memory)
    {
        revert("book-only harness has no signature domain");
    }

    function purchaseRefundWindow(RefundPurchaseData calldata d)
        external
        payable
        override
        nonReentrant
        returns (bytes32)
    {
        require(
            msg.sender == d.authorization.payer && !_isPaused(d.authorization.saleId),
            "harness entry"
        );
        return _capturePurchase(
            d,
            keccak256(abi.encode(d.authorization)),
            PurchaseCapture(fee, bytes32(uint256(1)), 1, bytes32(uint256(2)), address(0))
        );
    }

    function finalizeRefundWindow(bytes32 id)
        external
        override
        nonReentrant
        returns (RefundFinalizationResult memory r)
    {
        RefundPurchaseRecord storage p = _requirePurchase(id);
        if (p.status == 2) return _book._finalizationResults[id];
        if (p.status != 1) revert RefundWindowPurchaseTerminal(id);
        (uint64 refundDeadline, uint64 finalizationDeadline,) = purchaseDeadlines(id);
        if (_isPaused(p.authorization.saleId)) revert SaleEntryPaused();
        if (block.timestamp < refundDeadline) revert RefundWindowStillOpen(id, refundDeadline);
        if (block.timestamp > finalizationDeadline) {
            revert SaleFinalizeByExpired(finalizationDeadline);
        }
        _beginFinalization(id, p);
        r.amount = p.authorization.price;
        r.revealFeeForwarded = fee < p.savedRevealFee ? fee : p.savedRevealFee;
        r.revealFeeRefunded = p.savedRevealFee - r.revealFeeForwarded;
        SINK.transfer(r.amount + r.revealFeeForwarded);
        _creditFeeRemainder(p, r.revealFeeRefunded);
        _requireSolvent();
        _book._finalizationResults[id] = r;
    }

    function unlockRefund(bytes32 id, uint8 reason) external override nonReentrant {
        RefundPurchaseRecord storage p = _requirePurchase(id);
        if (p.status == 4) return;
        if (p.status != 1) revert RefundWindowPurchaseTerminal(id);
        if (reason != 0 || !_timeUnlockable(id, p)) revert RefundUnlockNotAvailable(id, reason);
        _closeToRefund(id, p, 4);
    }

    function pauseAdapter(bytes32) external override {
        StreamRefundClock.setGlobal(_book._globalPause, true);
    }

    function unpauseAdapter(bytes32) external override {
        StreamRefundClock.setGlobal(_book._globalPause, false);
    }

    function pauseRefundSale(bytes32 id, bytes32) external override {
        StreamRefundClock.setSale(_book._globalPause, _book._salePause[id], true);
    }

    function unpauseRefundSale(bytes32 id, bytes32) external override {
        StreamRefundClock.setSale(_book._globalPause, _book._salePause[id], false);
    }
}

contract RefundBookRejector {
    receive() external payable {
        revert("reject");
    }
}

contract StreamRefundWindowBookTest {
    RefundBookVm private constant vm =
        RefundBookVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RefundBookHarness private book;
    address private constant PAYER = address(0xABCD);
    address payable private constant RECIPIENT = payable(address(0xCAFE));
    bytes32 private sale;

    function setUp() public {
        vm.warp(1000);
        vm.deal(PAYER, 1 ether);
        book = new RefundBookHarness();
        sale = book.registerRefundSale(
            IStreamNativeRefundWindowSale.RefundSaleConfig(
                1, bytes32(uint256(1)), 100, 10, 0, 2000, 3600, 86400, 1, bytes32(uint256(2))
            )
        );
    }

    function _buy(uint256 nonce, uint64 escape) private returns (bytes32 id) {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d;
        d.authorization = IStreamNativeRefundWindowSale.RefundPurchaseAuthorization(
            sale,
            sale,
            PAYER,
            PAYER,
            address(0xAA),
            0,
            bytes32(uint256(4)),
            nonce,
            bytes32(nonce),
            100,
            2000,
            0,
            200000,
            escape,
            bytes32(uint256(5))
        );
        vm.prank(PAYER);
        id = book.purchaseRefundWindow{ value: 112 }(d);
    }

    function testMutableLibraryDirectCallsRejectWithSameArgumentConsumerControls() public {
        bytes memory pauseCall = abi.encodeWithSelector(
            bytes4(
                keccak256("setGlobalPause(StreamRefundWindowBookStore.State storage,bool,bytes32)")
            ),
            uint256(1),
            true,
            bytes32(uint256(9))
        );
        (bool ok, bytes memory result) = address(StreamRefundWindowBookStore).call(pauseCall);
        require(!ok && result.length == 0, "direct library mutation rejected");
        book.globalPauseViaLibrary(true);
        vm.expectRevert(abi.encodeWithSelector(StreamRefundClock.RefundPauseUnchanged.selector));
        book.globalPauseViaLibrary(true);
        book.globalPauseViaLibrary(false);
        IStreamNativeRefundWindowSale.RefundSaleConfig memory c = book.refundSaleRecord(sale).config;
        bytes memory configureCall = abi.encodeWithSelector(
            bytes4(
                keccak256(
                    "configure(StreamRefundWindowBookStore.State storage,IStreamNativeRefundWindowSale.RefundSaleConfig,StreamNativeSettlementTypes.SaleLifecycleBinding,uint256,bytes32,bytes32)"
                )
            ),
            uint256(1),
            c,
            StreamNativeSettlementTypes.SaleLifecycleBinding(1000, 1),
            uint256(2),
            bytes32(uint256(99)),
            bytes32(uint256(100))
        );
        (ok, result) = address(StreamRefundWindowBookStore).call(configureCall);
        require(!ok && result.length == 0, "direct library config rejected");
        bytes32 id = book.configureViaLibrary(c);
        require(
            id
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SALE_V1"),
                        block.chainid,
                        address(book),
                        uint8(7),
                        c.collectionId,
                        c.phaseId,
                        uint256(2)
                    )
                ),
            "consumer config identity"
        );
        require(book.refundSaleRecord(id).saleNonce == 2, "consumer configuration succeeds");
    }

    function testRefundKeepsFullPrincipalFeeExcessAndSurplusWithRejectingRecipient() public {
        vm.deal(address(book), 13);
        bytes32 id = _buy(1, 200000);
        require(
            book.totalBuyerLiabilities() == 112 && book.totalPendingDeposits() == 105
                && book.refundCredit(PAYER) == 7,
            "initial exact liabilities"
        );
        vm.prank(PAYER);
        book.refundPurchase(id);
        require(
            book.totalPendingDeposits() == 0 && book.totalBuyerLiabilities() == 112
                && book.refundCredit(PAYER) == 112,
            "conversion preserves full deposit"
        );
        RefundBookRejector rejector = new RefundBookRejector();
        vm.prank(PAYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundTransferFailed.selector, address(rejector)
            )
        );
        book.claimRefund(sale, payable(address(rejector)));
        require(
            book.refundCredit(PAYER) == 112 && address(book).balance == 125,
            "rejected pull preserves credit"
        );
        vm.prank(PAYER);
        book.claimRefund(sale, RECIPIENT);
        require(
            RECIPIENT.balance == 112 && address(book).balance == 13
                && book.totalBuyerLiabilities() == 0,
            "exact pull and forced surplus"
        );
        vm.prank(PAYER);
        book.refundPurchase(id);
        require(book.refundCredit(PAYER) == 0, "repeat cannot recreate claimed credit");
    }

    function testPausedEscapeEqualityUnlockAndTerminalTollNeverChanges() public {
        bytes32 id = _buy(1, 91000);
        vm.warp(4600);
        book.pauseAdapter(0);
        vm.warp(90999);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundUnlockNotAvailable.selector, id, uint8(0)
            )
        );
        book.unlockRefund(id, 0);
        vm.warp(91000);
        book.unlockRefund(id, 0);
        (uint64 refundDeadline, uint64 finalizationDeadline, uint64 toll) =
            book.purchaseDeadlines(id);
        require(
            book.refundCredit(PAYER) == 112 && book.refundPurchaseRecord(id).status == 4,
            "paused equality exits"
        );
        vm.warp(300000);
        book.unpauseAdapter(0);
        (uint64 r, uint64 f, uint64 t) = book.purchaseDeadlines(id);
        require(
            r == refundDeadline && f == finalizationDeadline && t == toll,
            "terminal history immutable"
        );
        book.unlockRefund(id, 0);
        require(book.refundCredit(PAYER) == 112, "idempotent unlock");
    }

    function testUnpausedEqualityFinalizesSavedFeeMinimumAndStoredResult() public {
        bytes32 id = _buy(1, 91000);
        book.setFee(3);
        vm.warp(91000);
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory result =
            book.finalizeRefundWindow(id);
        require(
            result.amount == 100 && result.revealFeeForwarded == 3 && result.revealFeeRefunded == 2,
            "saved/live fee minimum"
        );
        require(
            book.totalPendingDeposits() == 0 && book.totalBuyerLiabilities() == 9
                && book.refundCredit(PAYER) == 9,
            "excess and remainder only"
        );
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory repeated =
            book.finalizeRefundWindow(id);
        require(
            keccak256(abi.encode(result)) == keccak256(abi.encode(repeated))
                && book.refundCredit(PAYER) == 9,
            "stored result no second payment"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundWindowPurchaseTerminal.selector, id
            )
        );
        book.unlockRefund(id, 0);
    }
}
