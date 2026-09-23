// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamBurnMintGate.t.sol";
import {
    IStreamImmediateSaleReveal as Reveal
} from "../../../smart-contracts/interfaces/stream/mint/IStreamImmediateSaleReveal.sol";
import {
    IStreamNativeSaleCredits as Credits
} from "../../../smart-contracts/interfaces/stream/mint/IStreamNativeSaleCredits.sol";
import {
    IStreamNativeSurplus as Surplus
} from "../../../smart-contracts/interfaces/stream/mint/IStreamNativeSurplus.sol";

interface BurnCreditsVm {
    function prank(address) external;
    function deal(address, uint256) external;
    function warp(uint256) external;
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function expectEmit(bool, bool, bool, bool, address) external;
}

/// @dev A credited contract caller can reject refunds or attempt a different guarded operation.
contract BurnCreditsReceiver is IERC721Receiver {
    StreamBurnMintGate private immutable gate;
    bool public reject;
    bool public callbackAttempted;
    bool public callbackSucceeded;
    address private callback;
    bytes private callbackData;

    constructor(StreamBurnMintGate gate_) {
        gate = gate_;
    }

    function configure(bool reject_, address target, bytes calldata data) external {
        reject = reject_;
        callback = target;
        callbackData = data;
        callbackAttempted = false;
        callbackSucceeded = false;
    }

    function redeem(IStreamMintManager.MintBatch calldata batch, uint256[] calldata sources)
        external
        payable
    {
        gate.burnAndMint{ value: msg.value }(batch, sources);
    }

    function claim(bytes32 key, address recipient) external {
        Reveal(address(gate)).claimRefund(key, recipient);
    }

    receive() external payable {
        _callback();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        _callback();
        return IERC721Receiver.onERC721Received.selector;
    }

    function _callback() private {
        if (callback != address(0)) {
            callbackAttempted = true;
            (callbackSucceeded,) = callback.call(callbackData);
        }
        require(!reject, "credit receiver rejected");
    }
}

contract BurnCreditsForcedNative {
    constructor() payable { }

    function force(address payable target) external {
        selfdestruct(target);
    }
}

/// @notice Inherits the actual Manager/Ledger burn fixture; external entropy/Core remain typed seams.
contract StreamBurnMintCreditsTest is StreamBurnMintGateTest {
    BurnCreditsVm private constant creditsVm =
        BurnCreditsVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    event SalePaymentExcessCredited(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed payer, uint256 amount
    );
    event SaleRefundClaimed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed payer,
        address indexed recipient,
        uint256 amount
    );
    event NativeSaleCreditAccountIndexed(
        uint16 schemaVersion, uint256 indexed index, bytes32 indexed saleId, address indexed account
    );

    function testCreditsFeeDriftsDownFromQuoteAndExcessRemainsCallerOwned() public {
        bytes32 key = _key(2);
        entropy.setFee(20);
        require(_reveal().saleRevealQuote(key).policy.revealFeePerTokenWei == 20, "initial quote");
        entropy.setFee(7);
        creditsVm.deal(HOLDER, 100);
        IStreamMintManager.MintBatch memory batch = _batch(2, RECIPIENT, 1);
        uint256[] memory sources = _sources();
        creditsVm.expectEmit(true, true, false, true, address(gate));
        emit SalePaymentExcessCredited(1, key, HOLDER, 23);
        creditsVm.prank(HOLDER);
        gate.burnAndMint{ value: 30 }(batch, sources);
        require(entropy.revealFeeEscrow(2) == 7 && entropy.requests() == 1, "live lower fee");
        require(_reveal().refundableBalance(key, HOLDER) == 23, "unused maximum retained");
        require(_reveal().refundableBalance(key, RECIPIENT) == 0, "beneficiary has no fee credit");
        require(HOLDER.balance == 70 && address(gate).balance == 23, "no push refund");
        _assertState(1, 23, 23);
    }

    function testCreditsFeeDriftsUpWithinMaximumAllowance() public {
        bytes32 key = _key(2);
        entropy.setFee(7);
        require(_reveal().saleRevealQuote(key).policy.revealFeePerTokenWei == 7, "initial quote");
        entropy.setFee(20);
        creditsVm.deal(HOLDER, 100);
        _mintCredit(HOLDER, 2, RECIPIENT, _sources(), 30, keccak256("higher fee"));
        require(entropy.revealFeeEscrow(2) == 20, "live higher fee funded");
        require(_reveal().refundableBalance(key, HOLDER) == 10, "remaining allowance");
        _assertState(1, 10, 10);
    }

    function testCreditsWholeBatchFeeExceedsAllowanceBeforeBurn() public {
        entropy.setFee(11);
        _moreSources(3, 4);
        creditsVm.deal(HOLDER, 100);
        IStreamMintManager.MintBatch memory batch = _batch(2, RECIPIENT, 2);
        uint256[] memory sources = _range(1, 4);
        creditsVm.expectRevert(
            abi.encodeWithSelector(Reveal.SaleRevealFeeBelowRequired.selector, 20, 22)
        );
        creditsVm.prank(HOLDER);
        gate.burnAndMint{ value: 20 }(batch, sources);
        _unchanged();
        require(core.ownerOf(3) == HOLDER && core.ownerOf(4) == HOLDER, "entire source set intact");
        require(entropy.revealFeeEscrow(2) == 0 && HOLDER.balance == 100, "no funding or spend");
        _assertState(0, 0, 0);
    }

    function testCreditsQuantityFeeAndApprovedOperatorOwnsExcess() public {
        entropy.setFee(7);
        _moreSources(3, 4);
        creditsVm.prank(HOLDER);
        core.setApprovalForAll(address(this), true);
        bytes32 key = _key(2);
        _mintCredit(address(this), 2, RECIPIENT, _range(1, 4), 20, keccak256("operator batch"));
        require(core.ownerOf(101) == RECIPIENT && core.ownerOf(102) == RECIPIENT, "both minted");
        require(entropy.revealFeeEscrow(2) == 14 && entropy.requests() == 2, "fee per minted token");
        require(_reveal().refundableBalance(key, address(this)) == 6, "actual operator pays");
        require(_reveal().refundableBalance(key, HOLDER) == 0, "source owner has no credit");
        require(_reveal().refundableBalance(key, RECIPIENT) == 0, "beneficiary has no credit");
        _assertState(1, 6, 6);
    }

    function testCreditsCapturedFeeSurvivesReceiverChangingLiveFee() public {
        entropy.setFee(10);
        BurnCreditsReceiver receiver = new BurnCreditsReceiver(gate);
        receiver.configure(false, address(entropy), abi.encodeCall(entropy.setFee, (99)));
        creditsVm.deal(HOLDER, 100);
        _mintCredit(HOLDER, 2, address(receiver), _sources(), 30, keccak256("captured fee"));
        require(receiver.callbackSucceeded() && entropy.fee() == 99, "receiver changed live policy");
        require(entropy.revealFeeEscrow(2) == 10, "captured fee funded");
        require(_reveal().refundableBalance(_key(2), HOLDER) == 20, "captured allowance remainder");
        require(_reveal().saleRevealQuote(_key(2)).policy.revealFeePerTokenWei == 99, "new quote");
    }

    function testCreditsFundingFailureAndReceiverRejectionLeaveNoPhantomCredit() public {
        entropy.setFee(10);
        entropy.fail(true, false);
        creditsVm.deal(HOLDER, 100);
        BurnCreditsReceiver receiver = new BurnCreditsReceiver(gate);
        IStreamMintManager.MintBatch memory batch = _batch(2, address(receiver), 1);
        uint256[] memory sources = _sources();
        creditsVm.expectRevert();
        creditsVm.prank(HOLDER);
        gate.burnAndMint{ value: 30 }(batch, sources);
        _unchanged();
        _assertState(0, 0, 0);
        require(HOLDER.balance == 100 && entropy.revealFeeEscrow(2) == 0, "funding rolled back");
        entropy.fail(false, false);
        receiver.configure(true, address(0), "");
        creditsVm.expectRevert();
        creditsVm.prank(HOLDER);
        gate.burnAndMint{ value: 30 }(batch, sources);
        _unchanged();
        _assertState(0, 0, 0);
        receiver.configure(false, address(0), "");
        creditsVm.prank(HOLDER);
        gate.burnAndMint{ value: 30 }(batch, sources);
        require(_reveal().refundableBalance(_key(2), HOLDER) == 20, "identical request retry");
        require(entropy.revealFeeEscrow(2) == 10, "fee funded once");
    }

    function testCreditsClaimsRemainOwnerOnlyAfterExpiryRevocationAndPointerReplacement() public {
        creditsVm.deal(HOLDER, 100);
        _mintCredit(HOLDER, 2, RECIPIENT, _sources(), 30, keccak256("perpetual claim"));
        bytes32 key = _key(2);
        Reveal reveal = _reveal();
        creditsVm.warp(2001);
        registry.revoke(address(gate));
        core.configure(address(0xD1), address(0xD2), address(0xD3), address(0xD4));
        creditsVm.expectRevert(
            abi.encodeWithSelector(Reveal.SaleRefundEmpty.selector, key, RECIPIENT)
        );
        creditsVm.prank(RECIPIENT);
        reveal.claimRefund(key, RECIPIENT);
        creditsVm.expectRevert(
            abi.encodeWithSelector(Reveal.SaleRefundEmpty.selector, key, address(this))
        );
        reveal.claimRefund(key, address(this));
        uint256 recipientBefore = RECIPIENT.balance;
        creditsVm.expectEmit(true, true, true, true, address(gate));
        emit SaleRefundClaimed(1, key, HOLDER, RECIPIENT, 30);
        creditsVm.prank(HOLDER);
        reveal.claimRefund(key, RECIPIENT);
        require(RECIPIENT.balance == recipientBefore + 30, "owner chooses destination");
        _assertState(1, 0, 0);
        _assertPage(0, key, HOLDER, 0);
        creditsVm.expectRevert(abi.encodeWithSelector(Reveal.SaleRefundEmpty.selector, key, HOLDER));
        creditsVm.prank(HOLDER);
        reveal.claimRefund(key, RECIPIENT);
    }

    function testCreditsProviderFailurePreservesMintFundingAndExcess() public {
        entropy.setFee(10);
        entropy.fail(false, true);
        creditsVm.deal(HOLDER, 100);
        _mintCredit(HOLDER, 2, RECIPIENT, _sources(), 30, keccak256("provider unavailable"));
        require(
            core.ownerOf(101) == RECIPIENT && manager.nextOperationNonce() == 1, "mint retained"
        );
        require(
            entropy.revealFeeEscrow(2) == 10 && entropy.requests() == 0, "funded retry available"
        );
        require(_reveal().refundableBalance(_key(2), HOLDER) == 20, "unused fee still refundable");
        _assertState(1, 20, 20);
    }

    function testCreditsInvalidRefundDestinationsPreserveClaim() public {
        creditsVm.deal(HOLDER, 100);
        _mintCredit(HOLDER, 2, RECIPIENT, _sources(), 30, keccak256("invalid recipient"));
        Reveal reveal = _reveal();
        bytes32 key = _key(2);
        creditsVm.expectRevert(
            abi.encodeWithSelector(Reveal.SaleRefundTransferFailed.selector, address(0))
        );
        creditsVm.prank(HOLDER);
        reveal.claimRefund(key, address(0));
        creditsVm.expectRevert(
            abi.encodeWithSelector(Reveal.SaleRefundTransferFailed.selector, address(gate))
        );
        creditsVm.prank(HOLDER);
        reveal.claimRefund(key, address(gate));
        require(
            reveal.refundableBalance(key, HOLDER) == 30, "invalid destination cannot clear credit"
        );
        _assertState(1, 30, 30);
    }

    function testCreditsRejectedRefundRollsBackAndSameOwnerRetries() public {
        creditsVm.deal(HOLDER, 100);
        _mintCredit(HOLDER, 2, RECIPIENT, _sources(), 30, keccak256("refund failure"));
        bytes32 key = _key(2);
        Reveal reveal = _reveal();
        BurnCreditsReceiver receiver = new BurnCreditsReceiver(gate);
        receiver.configure(true, address(0), "");
        creditsVm.expectRevert(
            abi.encodeWithSelector(Reveal.SaleRefundTransferFailed.selector, address(receiver))
        );
        creditsVm.prank(HOLDER);
        reveal.claimRefund(key, address(receiver));
        require(reveal.refundableBalance(key, HOLDER) == 30, "failed claim retains balance");
        _assertState(1, 30, 30);
        receiver.configure(false, address(0), "");
        creditsVm.prank(HOLDER);
        reveal.claimRefund(key, address(receiver));
        require(address(receiver).balance == 30, "retry receives exact credit");
        _assertState(1, 0, 0);
    }

    function testCreditsRefundReceiverCannotReenterBurnWithFreshApprovedSources() public {
        BurnCreditsReceiver caller = _approvedCaller();
        _moreSources(3, 4);
        caller.redeem{ value: 30 }(_batch(2, RECIPIENT, 1), _sources());
        IStreamMintManager.MintBatch memory fresh = _batch(2, RECIPIENT, 1);
        fresh.authorizationId = keccak256("refund reentry request");
        caller.configure(
            false, address(gate), abi.encodeCall(gate.burnAndMint, (fresh, _range(3, 2)))
        );
        caller.claim(_key(2), address(caller));
        require(
            caller.callbackAttempted() && !caller.callbackSucceeded(), "shared guard blocks burn"
        );
        require(core.ownerOf(3) == HOLDER && core.ownerOf(4) == HOLDER, "fresh sources untouched");
        require(manager.nextOperationNonce() == 1, "only initial mint");
        _assertState(1, 0, 0);
        caller.configure(false, address(0), "");
        caller.redeem(fresh, _range(3, 2));
        require(core.ownerOf(102) == RECIPIENT, "guard clears after refund");
    }

    function testCreditsMintReceiverCannotClaimItsExistingCreditDuringBurn() public {
        BurnCreditsReceiver caller = _approvedCaller();
        _moreSources(3, 4);
        caller.redeem{ value: 30 }(_batch(2, RECIPIENT, 1), _sources());
        bytes32 key = _key(2);
        caller.configure(
            false, address(gate), abi.encodeCall(Reveal.claimRefund, (key, address(caller)))
        );
        IStreamMintManager.MintBatch memory fresh = _batch(2, address(caller), 1);
        fresh.authorizationId = keccak256("mint reentry request");
        caller.redeem(fresh, _range(3, 2));
        require(
            caller.callbackAttempted() && !caller.callbackSucceeded(), "shared guard blocks claim"
        );
        require(_reveal().refundableBalance(key, address(caller)) == 30, "prior credit retained");
        caller.configure(false, address(0), "");
        caller.claim(key, address(caller));
        require(address(caller).balance == 30, "claim available after mint");
        _assertState(1, 0, 0);
    }

    function testCreditsAppendOnlyEnumerationAggregatesKeysAndValidatesPages() public {
        _configure(3, 2, false, 5);
        _moreSources(3, 8);
        creditsVm.deal(HOLDER, 100);
        creditsVm.prank(HOLDER);
        core.setApprovalForAll(address(this), true);
        bytes32 first = _key(2);
        bytes32 second = _key(3);
        creditsVm.expectEmit(true, true, true, true, address(gate));
        emit NativeSaleCreditAccountIndexed(1, 0, first, HOLDER);
        _mintCredit(HOLDER, 2, RECIPIENT, _sources(), 9, keccak256("credit 1"));
        _mintCredit(HOLDER, 2, RECIPIENT, _range(3, 2), 11, keccak256("credit 2"));
        _mintCredit(address(this), 3, RECIPIENT, _range(5, 2), 13, keccak256("credit 3"));
        _mintCredit(address(this), 2, RECIPIENT, _range(7, 2), 17, keccak256("credit 4"));
        _assertState(3, 50, 50);
        _assertPage(0, first, HOLDER, 20);
        _assertPage(1, second, address(this), 13);
        _assertPage(2, first, address(this), 17);
        Credits credits = Credits(address(gate));
        creditsVm.expectRevert(abi.encodeWithSelector(Credits.NativeSaleCreditPageInvalid.selector));
        credits.nativeSaleCreditPage(0, 0, 0);
        creditsVm.expectRevert(abi.encodeWithSelector(Credits.NativeSaleCreditPageInvalid.selector));
        credits.nativeSaleCreditPage(0, 0, 65);
        creditsVm.expectRevert(abi.encodeWithSelector(Credits.NativeSaleCreditPageInvalid.selector));
        credits.nativeSaleCreditPage(0, 1, 1);
        creditsVm.expectRevert(abi.encodeWithSelector(Credits.NativeSaleCreditPageInvalid.selector));
        credits.nativeSaleCreditPage(3, 0, 1);
        Reveal reveal = _reveal();
        creditsVm.prank(HOLDER);
        reveal.claimRefund(first, HOLDER);
        _assertState(3, 30, 30);
        _assertPage(0, first, HOLDER, 0);
        _assertPage(1, second, address(this), 13);
    }

    function testCreditsForcedNativeSurplusSnapshotExcludesRefundLiability() public {
        entropy.setFee(10);
        creditsVm.deal(HOLDER, 100);
        _mintCredit(HOLDER, 2, RECIPIENT, _sources(), 30, keccak256("forced surplus"));
        BurnCreditsForcedNative forced = new BurnCreditsForcedNative{ value: 7 }();
        forced.force(payable(address(gate)));
        Surplus.NativeSurplusState memory snapshot = Surplus(address(gate)).nativeSurplusState();
        require(
            snapshot.balance == 27 && snapshot.liabilities == 20 && snapshot.available == 7,
            "surplus excludes credits"
        );
        require(
            snapshot.revision == 0 && snapshot.cumulativeSwept == 0 && snapshot.lastActionId == 0,
            "donation is not a sweep"
        );
        _assertState(1, 20, 27);
        Reveal reveal = _reveal();
        bytes32 key = _key(2);
        creditsVm.prank(HOLDER);
        reveal.claimRefund(key, HOLDER);
        snapshot = Surplus(address(gate)).nativeSurplusState();
        require(
            snapshot.balance == 7 && snapshot.liabilities == 0 && snapshot.available == 7,
            "claim preserves forced surplus"
        );
        _assertState(1, 0, 7);
    }

    function _approvedCaller() private returns (BurnCreditsReceiver caller) {
        caller = new BurnCreditsReceiver(gate);
        creditsVm.prank(HOLDER);
        core.setApprovalForAll(address(caller), true);
    }

    function _mintCredit(
        address caller,
        uint256 target,
        address recipient,
        uint256[] memory sources,
        uint256 allowance,
        bytes32 request
    ) private {
        IStreamMintManager.MintBatch memory batch = _batch(target, recipient, sources.length / 2);
        batch.authorizationId = request;
        creditsVm.prank(caller);
        gate.burnAndMint{ value: allowance }(batch, sources);
    }

    function _moreSources(uint256 first, uint256 last) private {
        for (uint256 id = first; id <= last; ++id) {
            core.mintSource(HOLDER, id, 1);
        }
    }

    function _range(uint256 first, uint256 count) private pure returns (uint256[] memory sources) {
        sources = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            sources[i] = first + i;
        }
    }

    function _key(uint256 target) private view returns (bytes32) {
        return gate.program(target).configHash;
    }

    function _reveal() private view returns (Reveal) {
        return Reveal(address(gate));
    }

    function _assertState(uint256 count, uint256 liabilities, uint256 balance) private view {
        Credits.CreditState memory state = Credits(address(gate)).nativeSaleCreditState();
        require(
            state.accountCount == count && state.totalLiabilities == liabilities
                && state.balance == balance,
            "credit snapshot"
        );
        require(
            _reveal().refundAccountCount() == count && _reveal().refundLiability() == liabilities,
            "same authoritative accounting"
        );
    }

    function _assertPage(uint256 index, bytes32 key, address account, uint256 owed) private view {
        Credits.CreditPage memory page = Credits(address(gate)).nativeSaleCreditPage(index, 0, 64);
        require(
            page.saleId == key && page.account == account && page.owed == owed
                && page.claimable == owed && page.nextCursor == 0,
            "terminal original ledger page"
        );
        (bytes32 indexedKey, address indexedAccount) = _reveal().refundAccountAt(index);
        require(indexedKey == key && indexedAccount == account, "stable append-only key");
        require(_reveal().refundableBalance(key, account) == owed, "claim agrees with enumeration");
    }
}
