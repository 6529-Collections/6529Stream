// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

interface ClearingResultCheats {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

contract StreamNativeClearingResultsTest is ClearingSaleTestBase {
    ClearingResultCheats private constant cheats =
        ClearingResultCheats(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _fixed() private returns (bytes32) {
        IStreamNativeClearingSale.ClearingPurchaseResult memory p = _buy(1, 1027);
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        return p.purchaseId;
    }

    function _pending(bytes32 id) private view {
        require(
            wallet.balance == 100 && recorder.totalOfficialSettled(address(0)) == 100
                && clearingSale.totalBuyerLiabilities() == 540
                && address(clearingSale).balance == 540
                && clearingSale.financialSale(clearingId).settledSupplement == 0
                && clearingSale.activeNativeSupplementalSettlement(id) == 0
                && !recorder.supplementalPurchaseConsumed(
                    recorder.supplementalPurchaseKey(address(clearingSale), id)
                ),
            "whole leg and official lanes restored"
        );
    }

    function testBoundedEmptyShortOversizedAndEveryResultFieldRejectWithExactHealthyRetry()
        external
    {
        bytes32 id = _fixed();
        uint256 snapshot = vm.snapshotState();
        StreamNativeSupplementalTypes.NativeSupplementalResult memory healthy =
            clearingSale.settlePurchaseSupplement(id);
        require(
            healthy.amount == 540 && wallet.balance == 640,
            "same context actual recorder success control"
        );
        require(vm.revertToState(snapshot), "restore actual successful leg");
        bytes memory selector = abi.encodePacked(
            IStreamNativeSupplementalSettlement.settleNativeSupplementalRevenueFromAdapter.selector
        );
        for (uint256 i; i < 19; ++i) {
            bytes memory bad;
            if (i < 3) {
                bad = new bytes(i == 0 ? 0 : i == 1 ? 32 : 65536);
            } else {
                bad = abi.encode(healthy);
                uint256 slot = i - 3;
                // bool words escrowed/policyDrift are flipped, every other fixed word changes by1.
                assembly ("memory-safe") {
                    let p := add(add(bad, 32), mul(slot, 32))
                    mstore(p, xor(mload(p), 1))
                }
            }
            cheats.mockCall(address(recorder), selector, bad);
            // Readback is the actual successful receipt; the escrowed flag also cannot drift.
            cheats.mockCall(
                address(recorder),
                abi.encodeCall(
                    IStreamNativeSupplementalSettlement.nativeSupplementalResult,
                    (healthy.settlementKey)
                ),
                abi.encode(healthy)
            );
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamNativeClearingSale.ClearingSettlementResultInvalid.selector
                )
            );
            clearingSale.settlePurchaseSupplement(id);
            _pending(id);
            cheats.clearMockedCalls();
        }
        StreamNativeSupplementalTypes.NativeSupplementalResult memory actual =
            clearingSale.settlePurchaseSupplement(id);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(healthy))
                && wallet.balance == 640,
            "identical leg after every injected result fault"
        );
    }

    function testRevertingNativeDepositFallsBackToOriginalOwedWalletThenFlushes() external {
        bytes32 id = _fixed();
        // Explicit branch fault injection on a canonical wallet, not its ordinary receive behavior.
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(wallet, 540, "", abi.encodeWithSignature("Error(string)", "injected"));
        StreamNativeSupplementalTypes.NativeSupplementalResult memory r =
            clearingSale.settlePurchaseSupplement(id);
        require(
            r.escrowed && wallet.balance == 100
                && escrow.escrowOwed(CLASS, profile, wallet, address(0)) == 540
                && recorder.totalOfficialSettled(address(0)) == 640
                && clearingSale.totalBuyerLiabilities() == 0,
            "exact deferred credit original wallet"
        );
        SaleFundingFaultVm(address(vm)).clearMockedCalls();
        escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(0));
        require(
            wallet.balance == 640 && escrow.escrowOwed(CLASS, profile, wallet, address(0)) == 0,
            "actual flush after injected fault clears"
        );
    }
}
