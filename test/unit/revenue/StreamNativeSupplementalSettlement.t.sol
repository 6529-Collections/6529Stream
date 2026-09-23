// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/NativeSupplementalTestBase.sol";

contract StreamNativeSupplementalSettlementTest is NativeSupplementalTestBase {
    function testActualFloorMintThenFinancialSupplementAndRealWalletRelease() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        require(
            wallet.balance == 1000 && supplementalManager.nonce() == 1
                && supplementalManager.ownerOf(1) == payer,
            "floor and mint"
        );
        uint256 payerBefore = payer.balance;
        uint256 keeperBefore = address(this).balance;
        StreamNativeSupplementalTypes.NativeSupplementalResult memory r = _submit(c);
        require(
            r.amount == 2000 && r.tokenId == 1
                && r.originalFloorSettlementKey == c.purchase.floorSettlementKey,
            "result"
        );
        require(
            r.originalOperationRoot == c.originalFloor.operationIdentityCommitment
                && r.originalOperationId == c.originalFloor.operationId,
            "original identity"
        );
        require(
            r.policyDrift
                && r.originalExpectedPrimaryPolicyHash
                    == c.originalFloor.sale.expectedPrimaryPolicyHash,
            "token context policy drift"
        );
        require(
            wallet.balance == 3000 && recorder.totalOfficialSettled(address(0)) == 3000
                && supplementalManager.nonce() == 1,
            "financial only"
        );
        require(
            payer.balance == payerBefore && address(this).balance == keeperBefore - 2000,
            "caller funding"
        );
        require(
            recorder.officialSettled(CLASS, profile, wallet, address(0)) == 3000, "profile total"
        );
        require(
            keccak256(abi.encode(recorder.nativeSupplementalResult(r.settlementKey)))
                == keccak256(abi.encode(r)),
            "stored result"
        );
        uint256 artistBefore = artist.balance;
        IStreamSplitWallet(wallet).release(address(0), artist, payable(artist));
        require(artist.balance == artistBefore + 3000 && wallet.balance == 0, "real release");
    }

    function testCompletedMintRequiredAndBurnedIdentityRetained() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        supplementalCore.setIncomplete(1, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement.selector
            )
        );
        _submit(c);
        _unchanged(c, 0, 1000);
        supplementalCore.setIncomplete(1, false);
        supplementalCore.setIdentity(1, 1, true);
        _submit(c);
        require(wallet.balance == 3000, "same candidate burned token control");
    }

    function testStableFloorLaneRejectsNewPurchaseIdAndFreshFloorSucceeds() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        _submit(c);
        c.purchase.purchaseNonce = 2;
        c.purchaseId = StreamNativeSupplementalHash.purchaseId(c);
        clearing.replaceFacts(c.purchaseId, c.purchase);
        bytes32 floorKey = recorder.supplementalFloorKey(c.purchase.floorSettlementKey);
        require(!recorder.settlementConsumed(_key(c)), "changed official key is fresh");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeSupplementalSettlement.SupplementalFloorAlreadyConsumed.selector,
                floorKey
            )
        );
        _submit(c);
        require(
            recorder.totalOfficialSettled(address(0)) == 3000 && wallet.balance == 3000,
            "replay unchanged"
        );
        c = _floor(3);
        _submit(c);
        require(recorder.totalOfficialSettled(address(0)) == 6000, "independent floor");
    }

    function testCurrentTokenOverrideAndFreezeSelectNewWalletWithoutNewMint() external {
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c = _floor(1);
        (bytes32 p, address w) = _newProfile(address(0xBEEF), keccak256("new token rights"));
        resolver.setPrimaryProfileAssignment(CLASS, 2, 1, p, 0);
        resolver.freezePrimaryAssignment(CLASS, 2, 1);
        _freshRights(c);
        _submit(c);
        require(
            wallet.balance == 1000 && w.balance == 2000 && supplementalManager.nonce() == 1,
            "token current and floor historical"
        );
    }
}
