// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";

contract RefundWindowReceiver is IERC721Receiver {
    bool public reject;
    address public target;
    bytes public data;
    bool public success;
    bytes public returned;
    address public wallet;
    uint256 public observedFunds;

    function configure(bool r, address t, bytes calldata d, address w) external {
        reject = r;
        target = t;
        data = d;
        wallet = w;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        observedFunds = wallet.balance;
        if (target != address(0)) (success, returned) = target.call(data);
        require(!reject, "refund recipient rejected");
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
        require(!reject, "refund payee rejected");
    }
}

contract StreamRefundWindowCallbacksTest is RefundWindowTestBase {
    function _association(uint8 mode) private {
        refundArtist.setAssociation(
            mode == 4 ? 4 : 2,
            mode == 1 ? 2 : 1,
            mode == 2 ? keccak256("other identity") : keccak256("refund artist identity"),
            1,
            mode == 3 ? keccak256("other binding") : keccak256("refund artist binding")
        );
    }

    function testSavedAssociationRejectsGenerationIdentityBindingAndStateDriftBeforeFunding()
        public
    {
        bytes32 id = _purchase(1, 1100);
        _atRefundEnd(id);
        for (uint8 mode = 1; mode <= 4; ++mode) {
            _association(mode);
            vm.expectRevert(
                abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
            );
            refundSale.finalizeRefundWindow(id);
            _pending(id, 1100, 0);
            require(
                !recorder.deferredPurchaseConsumed(
                    recorder.deferredPurchaseKey(address(refundSale), id)
                ),
                "official purchase lane not consumed"
            );
        }
        _association(0);
        // A lawful authority-address rotation within the same association never revalidates
        // the old commercial signature. Actual rotation authorization is artist integration.
        artists.accept(address(0xAABB));
        refundSale.finalizeRefundWindow(id);
        require(
            wallet.balance == 1000 && refundManager.nonce() == 1,
            "original signed purchase survives same-binding authority rotation"
        );
    }

    function testReceiverAssociationSwapRollsBackFundsMintAndCallbackThenExactRetry() public {
        RefundWindowReceiver receiver = new RefundWindowReceiver();
        receiver.configure(
            false,
            address(refundArtist),
            abi.encodeCall(
                RefundRuntimeArtist.setAssociation,
                (
                    uint8(2),
                    uint64(2),
                    keccak256("refund artist identity"),
                    uint8(1),
                    keccak256("refund artist binding")
                )
            ),
            wallet
        );
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d =
            _purchaseData(1, payer, address(receiver));
        vm.prank(payer);
        bytes32 id = refundSale.purchaseRefundWindow{ value: 1100 }(d);
        _atRefundEnd(id);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
        );
        refundSale.finalizeRefundWindow(id);
        _pending(id, 1100, 0);
        require(
            refundArtist.generation() == 1 && receiver.observedFunds() == 0,
            "callback and observation reverted"
        );
        receiver.configure(false, address(0), "", wallet);
        refundSale.finalizeRefundWindow(id);
        require(
            receiver.observedFunds() == 1000 && refundManager.ownerOf(1) == address(receiver),
            "same purchase funded before custody callback"
        );
    }

    function testFeeCallbackAssociationSwapRollsBackOfficialSettlementFeeAndMint() public {
        bytes32 id = _purchase(1, 1100);
        _atRefundEnd(id);
        refundEntropy.setCallback(
            address(refundArtist),
            abi.encodeCall(
                RefundRuntimeArtist.setAssociation,
                (
                    uint8(2),
                    uint64(1),
                    keccak256("other identity"),
                    uint8(1),
                    keccak256("refund artist binding")
                )
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
        );
        refundSale.finalizeRefundWindow(id);
        _pending(id, 1100, 0);
        require(
            refundArtist.identity() == keccak256("refund artist identity"),
            "fee callback rolled back"
        );
        refundEntropy.setCallback(address(0), "");
        refundSale.finalizeRefundWindow(id);
        require(
            refundEntropy.revealFeeEscrow(1) == 100 && wallet.balance == 1000, "same purchase retry"
        );
    }

    function testRecipientRejectionAndReentryAreDistinctExactOracles() public {
        RefundWindowReceiver receiver = new RefundWindowReceiver();
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d =
            _purchaseData(1, payer, address(receiver));
        vm.prank(payer);
        bytes32 id = refundSale.purchaseRefundWindow{ value: 1100 }(d);
        receiver.configure(true, address(0), "", wallet);
        _atRefundEnd(id);
        vm.expectRevert(bytes("refund recipient rejected"));
        refundSale.finalizeRefundWindow(id);
        _pending(id, 1100, 0);
        receiver.configure(
            false,
            address(refundSale),
            abi.encodeCall(IStreamNativeRefundWindowSale.finalizeRefundWindow, (id)),
            wallet
        );
        refundSale.finalizeRefundWindow(id);
        require(
            !receiver.success()
                && keccak256(receiver.returned())
                    == keccak256(
                        abi.encodeWithSelector(
                            ReentrancyGuard.ReentrancyGuardReentrantCall.selector
                        )
                    ),
            "exact guard before terminal-result shortcut"
        );
        require(
            receiver.observedFunds() == 1000 && refundManager.nonce() == 1,
            "outer finalization completes once"
        );
    }
}
