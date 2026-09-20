// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentTerminalEntropyFixture.sol";
import "../helpers/StreamCurrentAssetPolicy.sol";
import "../mocks/MockStreamPaymentToken.sol";
import "../../smart-contracts/domains/revenue/StreamClaimRouter.sol";

interface CurrentRevenueClaimVm {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

contract CurrentRevenueRejectingRecipient {
    bool private accepting;
    uint256 public received;
    function accept() external { accepting = true; }
    receive() external payable {
        require(accepting, "claim recipient rejects");
        received += msg.value;
    }
}

/// @notice Official Safe withdrawals preserve actual current sale and conservation receipts.
/// @dev Native1000 is earned through the original paid mint. ERC20s in these cases are explicitly
///      passive receipts of a real governed ACTIVE test asset, not additional official token sales.
contract StreamCurrentRevenueSafeClaimsTest is CurrentTerminalEntropyFixture {
    address private constant ALTERNATE = address(0xC1A1);
    bytes32 private constant CLAIM_FAILED =
        keccak256("ClaimFailed(address,address,address,uint16,uint256,bytes4,uint256,bytes)");
    StreamClaimRouter private claimsRouter;
    MockStreamPaymentToken private claimToken;
    IStreamSplitWallet private earned;
    bytes32 private originalKey;
    bytes32 private originalResult;
    bytes32 private originalFloor;

    function setUp() public {
        _constructTerminal();
        _legacyRequiredControl();
        claimsRouter = new StreamClaimRouter();
        _assertDeployableProductionInstance(address(claimsRouter));
        claimToken = new MockStreamPaymentToken();
        GovernanceActionRequest memory request = StreamCurrentAssetPolicy.activationRequest(
            assetPolicy, address(claimToken), keccak256("passive claim test token"), DEPLOYMENT_HASH
        );
        bytes32 action = _scheduleAsGovernor(request);
        vm.expectRevert(abi.encodeWithSelector(
            IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector, action, request.notBefore
        ));
        executor.executeGovernanceAction(action, request.callData);
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(action, request.callData);
        require(assetPolicy.assetStatus(address(claimToken)) == 1, "actual delayed token admission");
        earned = IStreamSplitWallet(wallet);
        require(earned.initialized() && earned.factory() == address(factory)
            && earned.assetPolicyRegistry() == address(assetPolicy) && earned.profileId() == profile
            && wallet == factory.walletFor(profile) && wallet.codehash == factory.splitWalletRuntimeCodeHash()
            && earned.aggregateSharePpm(address(terminalArtist)) == 900_000
            && earned.aggregateSharePpm(address(terminalPayer)) == 0
            && address(terminalArtist) != address(terminalPayer)
            && keccak256(abi.encode(terminalArtist.getOwners())) == keccak256(abi.encode(terminalPayer.getOwners()))
            && terminalArtist.getThreshold() == 2 && terminalPayer.getThreshold() == 2,
            "actual initialized clone and distinct same-owner Safe principals");
        originalKey = recorder.settlementKey(address(nativeSale), nativeSale.executionIdByNonce(saleId, 1));
        originalResult = keccak256(abi.encode(recorder.settlementResult(originalKey)));
        originalFloor = commerceFloor.settlementReceipt(originalKey).receiptHash;
        vm.deal(address(this), 10 ether);
        require(wallet.balance == PRICE && address(terminalArtist).balance == 0,
            "original paid revenue remains available before withdrawals");
        _assertOriginalReceipts();
    }

    function testCurrentSafeSyncAndDirectRecipientAuthorityPreserveEarnedRevenue() public {
        claimToken.mint(wallet, 1000);
        bytes memory redirect = abi.encodeCall(IStreamSplitWallet.release,
            (address(claimToken), address(terminalArtist), payable(ALTERNATE)));
        _rejectEnvelope(terminalPayer, _claimEnvelope(terminalPayer, wallet, redirect));
        require(claimToken.rawBalance(wallet) == 1000 && claimToken.rawBalance(ALTERNATE) == 0
            && earned.accountReleased(address(claimToken), address(terminalArtist)) == 0,
            "same owners do not let a different Safe redirect the artist entitlement");
        _safe(terminalArtist, wallet, 0, abi.encodeCall(IStreamSplitWallet.syncAsset, (address(claimToken))));
        require(earned.assetObservationInitialized(address(claimToken))
            && earned.lastObservedReceived(address(claimToken)) == 1000, "actual Safe sync");
        _safe(terminalArtist, wallet, 0, redirect);
        require(claimToken.rawBalance(ALTERNATE) == 900 && claimToken.rawBalance(wallet) == 100
            && earned.accountReleased(address(claimToken), address(terminalArtist)) == 900
            && earned.totalReleased(address(claimToken)) == 900
            && earned.observedReceived(address(claimToken)) == 1000 && wallet.balance == PRICE,
            "entitled Safe alone redirects its exact token share; native revenue remains");
        _assertOriginalReceipts();
    }

    function testCurrentSafeSignedNativeReleaseRejectsRecipientThenRetriesIdenticalEnvelope() public {
        CurrentRevenueRejectingRecipient recipient = new CurrentRevenueRejectingRecipient();
        IStreamSplitWallet.ReleaseAuthorization memory a = _claimAuthorization(address(0), address(recipient), 11);
        bytes memory proof = _claimProof(a);
        bytes memory input = abi.encodeCall(IStreamSplitWallet.releaseWithAuthorization, (a, proof));
        bytes memory envelope = _claimEnvelope(terminalOperator, wallet, input);
        uint256 artistNonce = terminalArtist.nonce();
        CurrentRevenueClaimVm(address(vm)).expectCall(address(recipient), 900, bytes(""), 3);
        vm.expectRevert(abi.encodeWithSelector(IStreamSplitWallet.NativeTransferFailed.selector,
            address(recipient), uint256(900)));
        earned.releaseWithAuthorization(a, proof);
        _rejectEnvelope(terminalOperator, envelope);
        require(wallet.balance == PRICE && recipient.received() == 0
            && !earned.isReleaseAuthorizationNonceUsed(address(terminalArtist), a.nonce)
            && earned.accountReleased(address(0), address(terminalArtist)) == 0
            && earned.totalReleased(address(0)) == 0 && !earned.assetObservationInitialized(address(0)),
            "failed signed withdrawal restores consent, observation and earned money");
        _assertOriginalReceipts();
        recipient.accept();
        _runEnvelope(terminalOperator, envelope);
        require(recipient.received() == 900 && wallet.balance == 100
            && earned.isReleaseAuthorizationNonceUsed(address(terminalArtist), a.nonce)
            && earned.accountReleased(address(0), address(terminalArtist)) == 900
            && earned.totalReleased(address(0)) == 900 && earned.lastObservedReceived(address(0)) == PRICE
            && terminalArtist.nonce() == artistNonce,
            "original threshold proof pays signed recipient; only submitting Safe nonce advances");
        _assertOriginalReceipts();
    }

    function testCurrentSafeSignedTokenReleaseRestoresNonceAndObservationOnTransferFailure() public {
        claimToken.mint(wallet, 1000);
        IStreamSplitWallet.ReleaseAuthorization memory a = _claimAuthorization(address(claimToken), ALTERNATE, 12);
        bytes memory proof = _claimProof(a);
        bytes memory input = abi.encodeCall(IStreamSplitWallet.releaseWithAuthorization, (a, proof));
        bytes memory envelope = _claimEnvelope(terminalOperator, wallet, input);
        uint256 artistNonce = terminalArtist.nonce();
        claimToken.configure(1, 2);
        vm.expectRevert(abi.encodeWithSelector(IStreamSplitWallet.ERC20TransferFailed.selector,
            address(claimToken), ALTERNATE, uint256(900)));
        earned.releaseWithAuthorization(a, proof);
        _rejectEnvelope(terminalOperator, envelope);
        require(claimToken.rawBalance(wallet) == 1000 && claimToken.rawBalance(ALTERNATE) == 0
            && !earned.isReleaseAuthorizationNonceUsed(address(terminalArtist), a.nonce)
            && !earned.assetObservationInitialized(address(claimToken))
            && earned.totalReleased(address(claimToken)) == 0,
            "failed token leg restores original Safe consent and observation");
        claimToken.configure(0, 0);
        _runEnvelope(terminalOperator, envelope);
        require(claimToken.rawBalance(ALTERNATE) == 900 && claimToken.rawBalance(wallet) == 100
            && earned.isReleaseAuthorizationNonceUsed(address(terminalArtist), a.nonce)
            && earned.totalReleased(address(claimToken)) == 900
            && earned.lastObservedReceived(address(claimToken)) == 1000
            && terminalArtist.nonce() == artistNonce && wallet.balance == PRICE,
            "identical Safe and release proof succeeds after token repair only");
        _assertOriginalReceipts();
    }

    function testCurrentSafeDirectAndSignedRevocationsBindEarnedAccountAcrossSameOwners() public {
        IStreamSplitWallet.ReleaseAuthorization memory a = _claimAuthorization(address(0), ALTERNATE, 21);
        bytes memory proof = _claimProof(a);
        _safe(terminalPayer, wallet, 0, abi.encodeCall(IStreamSplitWallet.revokeReleaseAuthorization, (a.nonce)));
        require(earned.isReleaseAuthorizationNonceUsed(address(terminalPayer), a.nonce)
            && !earned.isReleaseAuthorizationNonceUsed(address(terminalArtist), a.nonce),
            "same-owner payer Safe revokes only its own nonce namespace");
        _safe(terminalArtist, wallet, 0, abi.encodeCall(IStreamSplitWallet.revokeReleaseAuthorization, (a.nonce)));
        vm.expectRevert(abi.encodeWithSelector(IStreamSplitWallet.ReleaseAuthorizationNonceUsed.selector,
            address(terminalArtist), a.nonce));
        earned.releaseWithAuthorization(a, proof);
        a.nonce = bytes32(uint256(22));
        proof = _claimProof(a);
        bytes32 digest = earned.releaseRevocationDigest(address(terminalArtist), a.nonce, a.deadline);
        bytes memory wrong = safeThresholdSignature(terminalKeys,
            safeMessageDigest(terminalPayer, abi.encode(digest)));
        vm.expectRevert(abi.encodeWithSelector(IStreamSplitWallet.InvalidReleaseSignature.selector,
            address(terminalArtist)));
        earned.revokeReleaseAuthorizationBySignature(address(terminalArtist), a.nonce, a.deadline, wrong);
        require(!earned.isReleaseAuthorizationNonceUsed(address(terminalArtist), a.nonce),
            "wrong Safe domain cannot revoke earned account consent");
        bytes memory revocation = safeThresholdSignature(terminalKeys,
            safeMessageDigest(terminalArtist, abi.encode(digest)));
        _safe(terminalOperator, wallet, 0, abi.encodeCall(IStreamSplitWallet.revokeReleaseAuthorizationBySignature,
            (address(terminalArtist), a.nonce, a.deadline, revocation)));
        vm.expectRevert(abi.encodeWithSelector(IStreamSplitWallet.ReleaseAuthorizationNonceUsed.selector,
            address(terminalArtist), a.nonce));
        earned.releaseWithAuthorization(a, proof);
        require(!earned.isReleaseAuthorizationNonceUsed(address(terminalPayer), a.nonce)
            && !earned.isReleaseAuthorizationNonceUsed(vm.addr(terminalKeys[0]), a.nonce)
            && earned.releasable(address(0), address(terminalArtist)) == 900 && wallet.balance == PRICE,
            "revocation neither spends nor freezes original entitlement or aliases the owner EOA");
        _safe(terminalArtist, wallet, 0, abi.encodeCall(IStreamSplitWallet.release,
            (address(0), address(terminalArtist), payable(ALTERNATE))));
        require(ALTERNATE.balance == 900 && wallet.balance == 100, "direct account payout remains available");
        _assertOriginalReceipts();
    }

    function testCurrentSafeClaimManyAtomicFailureRetriesSameEnvelopeAfterRealCloneFunding() public {
        IStreamSplitWallet second = _additionalClaimWallet(address(terminalArtist), 31);
        IStreamClaimRouter.ClaimCall[] memory calls = new IStreamClaimRouter.ClaimCall[](2);
        calls[0] = IStreamClaimRouter.ClaimCall(wallet, address(0), address(terminalArtist));
        calls[1] = IStreamClaimRouter.ClaimCall(address(second), address(0), address(terminalArtist));
        bytes memory input = abi.encodeCall(IStreamClaimRouter.claimMany, (calls, false));
        bytes memory envelope = _claimEnvelope(terminalArtist, address(claimsRouter), input);
        _assertAtomicRouterFailure(input, address(second), _noFunds(address(0), address(terminalArtist)));
        _rejectEnvelope(terminalArtist, envelope);
        require(wallet.balance == PRICE && address(terminalArtist).balance == 0
            && earned.totalReleased(address(0)) == 0 && !earned.assetObservationInitialized(address(0))
            && second.totalReleased(address(0)) == 0,
            "later empty real clone restores earlier official-revenue payout and Safe nonce");
        _assertOriginalReceipts();
        _passiveNative(address(second), 200);
        _runEnvelope(terminalArtist, envelope);
        require(address(terminalArtist).balance == 1100 && wallet.balance == 100
            && address(second).balance == 0 && earned.accountReleased(address(0), address(terminalArtist)) == 900
            && second.accountReleased(address(0), address(terminalArtist)) == 200,
            "same signed batch pays earned900 plus separately funded200 to entitled Safe");
        _assertOriginalReceipts();
    }

    function testCurrentSafeClaimManyContinueAttributesDuplicateAndPaysEachNamedAccount() public {
        IStreamSplitWallet second = _additionalClaimWallet(address(terminalPayer), 32);
        _passiveNative(address(second), 200);
        uint256 beforePayer = address(terminalPayer).balance;
        IStreamClaimRouter.ClaimCall[] memory calls = new IStreamClaimRouter.ClaimCall[](3);
        calls[0] = IStreamClaimRouter.ClaimCall(wallet, address(0), address(terminalArtist));
        calls[1] = calls[0];
        calls[2] = IStreamClaimRouter.ClaimCall(address(second), address(0), address(terminalPayer));
        vm.recordLogs();
        _safe(terminalArtist, address(claimsRouter), 0,
            abi.encodeCall(IStreamClaimRouter.claimMany, (calls, true)));
        _assertOnlyClaimFailure(vm.getRecordedLogs(), wallet, address(0), address(terminalArtist), 1,
            IStreamSplitWallet.release.selector, _noFunds(address(0), address(terminalArtist)));
        require(address(terminalArtist).balance == 900 && address(terminalPayer).balance == beforePayer + 200
            && wallet.balance == 100 && address(second).balance == 0
            && earned.totalReleased(address(0)) == 900 && second.totalReleased(address(0)) == 200,
            "partial batch retains success, reports duplicate, pays named account instead of executor");
        _assertOriginalReceipts();
    }

    function testCurrentSafeSyncAndClaimAtomicRestoresEarlierNativeAndLaterTokenObservation() public {
        IStreamSplitWallet second = _additionalClaimWallet(address(terminalArtist), 33);
        claimToken.mint(address(second), 400);
        IStreamClaimRouter.ClaimCall[] memory calls = new IStreamClaimRouter.ClaimCall[](2);
        calls[0] = IStreamClaimRouter.ClaimCall(wallet, address(0), address(terminalArtist));
        calls[1] = IStreamClaimRouter.ClaimCall(address(second), address(claimToken), address(terminalArtist));
        bytes memory input = abi.encodeCall(IStreamClaimRouter.syncAndClaimMany, (calls, false));
        bytes memory envelope = _claimEnvelope(terminalArtist, address(claimsRouter), input);
        claimToken.configure(1, 2);
        _assertAtomicRouterFailure(input, address(second), abi.encodeWithSelector(
            IStreamSplitWallet.ERC20TransferFailed.selector, address(claimToken), address(terminalArtist), uint256(400)
        ));
        _rejectEnvelope(terminalArtist, envelope);
        require(wallet.balance == PRICE && address(terminalArtist).balance == 0
            && earned.totalReleased(address(0)) == 0 && !earned.assetObservationInitialized(address(0))
            && !second.assetObservationInitialized(address(claimToken))
            && second.totalReleased(address(claimToken)) == 0
            && claimToken.rawBalance(address(second)) == 400 && claimToken.rawBalance(address(terminalArtist)) == 0,
            "late failed token transfer rolls back prior native payout and both successful syncs");
        claimToken.configure(0, 0);
        _runEnvelope(terminalArtist, envelope);
        require(address(terminalArtist).balance == 900 && wallet.balance == 100
            && claimToken.rawBalance(address(terminalArtist)) == 400 && claimToken.rawBalance(address(second)) == 0
            && earned.lastObservedReceived(address(0)) == PRICE
            && second.lastObservedReceived(address(claimToken)) == 400
            && second.totalReleased(address(claimToken)) == 400,
            "identical atomic Safe batch settles both assets after external token repair");
        _assertOriginalReceipts();
    }

    function testCurrentSafeSyncAndClaimContinueRetainsSyncForNonentitledSameOwnerSafe() public {
        claimToken.mint(wallet, 1000);
        IStreamClaimRouter.ClaimCall[] memory calls = new IStreamClaimRouter.ClaimCall[](2);
        calls[0] = IStreamClaimRouter.ClaimCall(wallet, address(claimToken), address(terminalPayer));
        calls[1] = IStreamClaimRouter.ClaimCall(wallet, address(0), address(terminalArtist));
        vm.recordLogs();
        _safe(terminalArtist, address(claimsRouter), 0,
            abi.encodeCall(IStreamClaimRouter.syncAndClaimMany, (calls, true)));
        _assertOnlyClaimFailure(vm.getRecordedLogs(), wallet, address(claimToken), address(terminalPayer), 0,
            IStreamSplitWallet.release.selector, _noFunds(address(claimToken), address(terminalPayer)));
        require(earned.assetObservationInitialized(address(claimToken))
            && earned.lastObservedReceived(address(claimToken)) == 1000
            && earned.totalReleased(address(claimToken)) == 0 && claimToken.rawBalance(wallet) == 1000
            && claimToken.rawBalance(address(terminalPayer)) == 0
            && address(terminalArtist).balance == 900 && wallet.balance == 100,
            "successful token sync persists after account failure while later native claim succeeds");
        calls = new IStreamClaimRouter.ClaimCall[](1);
        calls[0] = IStreamClaimRouter.ClaimCall(wallet, address(claimToken), address(terminalArtist));
        _safe(terminalArtist, address(claimsRouter), 0, abi.encodeCall(IStreamClaimRouter.claimMany, (calls, false)));
        require(claimToken.rawBalance(address(terminalArtist)) == 900 && claimToken.rawBalance(wallet) == 100,
            "original entitled Safe can claim the retained token observation");
        _assertOriginalReceipts();
    }

    function _claimAuthorization(address asset, address recipient, uint256 nonce)
        private view returns (IStreamSplitWallet.ReleaseAuthorization memory)
    {
        uint256 amount = earned.releasable(asset, address(terminalArtist));
        require(amount == 900, "exact earned or passive share snapshot");
        return IStreamSplitWallet.ReleaseAuthorization(asset, address(terminalArtist), recipient,
            amount, bytes32(nonce), uint64(block.timestamp + 1 days));
    }

    function _claimProof(IStreamSplitWallet.ReleaseAuthorization memory a) private returns (bytes memory) {
        return safeThresholdSignature(terminalKeys,
            safeMessageDigest(terminalArtist, abi.encode(earned.releaseAuthorizationDigest(a))));
    }

    function _claimEnvelope(OfficialSafe account, address target, bytes memory input)
        private returns (bytes memory)
    {
        bytes32 digest = account.getTransactionHash(target, 0, input, 0, 0, 0, 0,
            address(0), address(0), account.nonce());
        return abi.encodeCall(OfficialSafe.execTransaction,
            (target, uint256(0), input, uint8(0), uint256(0), uint256(0), uint256(0),
                address(0), payable(address(0)), safeThresholdSignature(terminalKeys, digest)));
    }

    function _rejectEnvelope(OfficialSafe account, bytes memory envelope) private {
        uint256 nonce = account.nonce();
        (bool ok, bytes memory reason) = address(account).call(envelope);
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
            && account.nonce() == nonce, "original Safe target failure restores CALL nonce");
    }

    function _runEnvelope(OfficialSafe account, bytes memory envelope) private {
        uint256 nonce = account.nonce();
        (bool ok, bytes memory result) = address(account).call(envelope);
        require(ok && result.length == 32 && abi.decode(result, (bool)) && account.nonce() == nonce + 1,
            "complete original threshold-signed Safe envelope succeeds once");
    }

    function _additionalClaimWallet(address account, uint256 salt) private returns (IStreamSplitWallet target) {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(account, 1_000_000, keccak256("additional claim"));
        (bytes32 id, address clone) = factory.createProfile(entries, bytes32(salt));
        target = IStreamSplitWallet(clone);
        require(target.initialized() && target.profileId() == id && target.factory() == address(factory)
            && clone == factory.walletFor(id) && clone.codehash == factory.splitWalletRuntimeCodeHash(),
            "second original Factory-initialized clone");
    }

    function _passiveNative(address target, uint256 amount) private {
        (bool ok,) = target.call{ value: amount }("");
        require(ok, "explicit passive native funding");
    }

    function _noFunds(address asset, address account) private pure returns (bytes memory) {
        return abi.encodeWithSelector(IStreamSplitWallet.NoReleasableFunds.selector, asset, account);
    }

    function _assertAtomicRouterFailure(bytes memory input, address target, bytes memory reason) private {
        (bool ok, bytes memory result) = address(claimsRouter).call(input);
        require(!ok && keccak256(result) == keccak256(abi.encodeWithSelector(
            IStreamClaimRouter.ClaimCallFailed.selector, uint256(1), target,
            IStreamSplitWallet.release.selector, reason.length, reason
        )), "exact second-item release failure through original router before Safe rollback check");
    }

    function _assertOnlyClaimFailure(Vm.Log[] memory logs, address target, address asset, address account,
        uint256 index, bytes4 operation, bytes memory reason) private view
    {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(claimsRouter) || logs[i].topics.length == 0
                || logs[i].topics[0] != CLAIM_FAILED) continue;
            require(logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(uint160(target)))
                && logs[i].topics[2] == bytes32(uint256(uint160(asset)))
                && logs[i].topics[3] == bytes32(uint256(uint160(account)))
                && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), index, operation, reason.length, reason)),
                "exact partial failure wallet asset account index stage and bounded reason");
            ++count;
        }
        require(count == 1, "exactly one attributed partial claim failure");
    }

    function _assertOriginalReceipts() private view {
        _assertWaivedCommerceReceipt(address(recorder), originalKey);
        require(recorder.settlementConsumed(originalKey)
            && keccak256(abi.encode(recorder.settlementResult(originalKey))) == originalResult
            && commerceFloor.settlementReceipt(originalKey).receiptHash == originalFloor
            && recorder.totalOfficialSettled(address(0)) == PRICE
            && recorder.officialSettled(PRIMARY_REVENUE_CLASS, profile, wallet, address(0)) == PRICE
            && recorder.totalOfficialSettled(address(claimToken)) == 0
            && core.ownerOf(1) == address(terminalPayer) && manager.nextOperationNonce() == 1
            && entropy.tokenEntropyStatus(1) == StreamEntropyStatus.FINALIZED
            && address(recorder).balance == 0 && address(claimsRouter).balance == 0
            && claimToken.rawBalance(address(claimsRouter)) == 0,
            "withdrawal cannot rewrite original paid mint, floor, lifetime revenue or give router custody");
    }
}
