// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/DutchSaleTestBase.sol";

contract DutchClaimReentryBuyer {
    StreamNativeDutchSale public immutable sale;
    bytes32 public claimSale;
    bool public callback;
    bytes public reason;

    constructor(StreamNativeDutchSale target) {
        sale = target;
    }

    function configure(bytes32 id, bool enabled) external {
        claimSale = id;
        callback = enabled;
    }

    function buy(IStreamNativeDutchSale.DutchPurchaseData calldata data, uint256 value) external {
        sale.purchase{ value: value }(data);
    }

    function claim() external {
        sale.claimRefund(claimSale, address(this));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (callback) {
            (bool ok, bytes memory out) = address(sale)
                .call(
                    abi.encodeCall(IStreamNativeDutchSale.claimRefund, (claimSale, address(this)))
                );
            require(!ok, "claim reentered");
            reason = out;
        }
        return 0x150b7a02;
    }
    receive() external payable { }
}

contract StreamNativeDutchReentryTest is DutchSaleTestBase {
    function testRealPriorCreditCannotReenterDuringNFTCallbackAndRemainsClaimableAfterward()
        public
    {
        DutchClaimReentryBuyer buyer = new DutchClaimReentryBuyer(dutchSale);
        vm.deal(address(buyer), 2300);
        IStreamNativeDutchSale.DutchPurchaseData memory first = _dutchData(1, address(buyer), payer);
        buyer.buy(first, 1200);
        require(
            dutchSale.refundableBalance(dutchId, address(buyer)) == 100, "real prior credit exists"
        );
        buyer.configure(dutchId, true);
        IStreamNativeDutchSale.DutchPurchaseData memory second =
            _dutchData(2, address(buyer), address(buyer));
        buyer.buy(second, 1100);
        require(
            keccak256(buyer.reason())
                == keccak256(
                    abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
                ),
            "exact guard, not absent credit or wrong caller"
        );
        require(
            dutchSale.refundableBalance(dutchId, address(buyer)) == 100
                && refundManager.ownerOf(2) == address(buyer) && wallet.balance == 2000
                && dutchSale.refundLiability() == 100,
            "outer mint and prior credit persist"
        );
        buyer.claim();
        require(
            address(buyer).balance == 100 && dutchSale.refundLiability() == 0,
            "identical rightful claim succeeds outside callback"
        );
    }
}
