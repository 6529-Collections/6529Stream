// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract StreamNativeClearingSafeTest is ClearingSaleTestBase {
    OfficialSafe private account;
    uint256[] private keys;

    function _safe() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        account = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9951
        );
    }

    function _exec(uint256 value, bytes memory data) private {
        uint256 nonce = account.nonce();
        vm.recordLogs();
        require(
            executeSafe(account, keys, address(clearingSale), value, data, 0),
            "actual Safe returned success"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 successes;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(account)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++successes;
        }
        require(
            successes == 1 && account.nonce() == nonce + 1, "actual Safe success event and nonce"
        );
    }

    function _read(bytes memory data) private {
        (bool ok, bytes memory expected) = address(clearingSale).staticcall(data);
        vm.prank(address(account));
        (bool safeOk, bytes memory actual) = address(clearingSale).staticcall(data);
        require(
            ok && safeOk && keccak256(expected) == keccak256(actual),
            "exact Safe-address read parity"
        );
        _exec(0, data);
    }

    function testActualSafeThresholdAuthorityPayerCustodyRebateKeeperAndNativePayout() external {
        _safe();
        artists.accept(address(account));
        vm.deal(address(account), 1027);
        IStreamNativeClearingSale.ClearingPurchaseData memory d =
            _clearingData(1, address(account), address(account));
        d.authorization.artist = address(account);
        bytes32 digest = clearingSale.authorizationDigest(d.authorization);
        d.platformSignature = _sign(PLATFORM_KEY, digest);
        d.artistSignature = safeThresholdSignature(keys, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingSignatureInvalid.selector, address(account)
            )
        );
        vm.prank(address(account));
        clearingSale.purchase{ value: 1027 }(d);
        require(
            clearingManager.nonce() == 0 && account.nonce() == 0 && wallet.balance == 0,
            "plain Stream signature rejected"
        );
        d.artistSignature =
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest)));
        _exec(1027, abi.encodeCall(clearingSale.purchase, (d)));
        bytes32 purchaseId = clearingSale.purchaseIdFor(clearingId, address(account), 1);
        require(
            clearingManager.ownerOf(1) == address(account) && wallet.balance == 100,
            "Safe paid and received actual mock NFT"
        );
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        _exec(0, abi.encodeCall(clearingSale.fixClearingPrice, (clearingId)));
        require(
            clearingSale.refundableBalance(clearingId, address(account)) == 367,
            "Safe rebate available"
        );
        _exec(0, abi.encodeCall(clearingSale.claimRefund, (clearingId, address(account))));
        require(address(account).balance == 367, "native pull payment reaches real Safe");
        _exec(0, abi.encodeCall(clearingSale.settlePurchaseSupplement, (purchaseId)));
        require(
            wallet.balance == 640 && clearingSale.totalBuyerLiabilities() == 0
                && clearingManager.nonce() == 1,
            "Safe keeper financial only"
        );
        _read(abi.encodeCall(clearingSale.eip712Domain, ()));
        _read(abi.encodeCall(clearingSale.clearingPurchaseFacts, (purchaseId)));
        _read(abi.encodeCall(clearingSale.activeNativeSupplementalSettlement, (purchaseId)));
        _read(abi.encodeCall(clearingSale.saleDeadlines, (clearingId)));
        _exec(0, abi.encodeCall(clearingSale.synchronizeRebate, (clearingId, address(account))));
        _exec(0, abi.encodeCall(clearingSale.synchronizeSaleDeadline, (clearingId)));
        _exec(0, abi.encodeCall(clearingSale.cancelAuthorization, (bytes32(uint256(999)))));
        require(
            clearingSale.authorizationUsed(address(account), bytes32(uint256(999))),
            "Safe caller owns cancellation"
        );
    }
}
