// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamNativeCuratedCommitments as C
} from "../../../smart-contracts/interfaces/stream/mint/IStreamNativeCuratedCommitments.sol";
import {
    StreamNativeCuratedCommitments as Book
} from "../../../smart-contracts/domains/mint/StreamNativeCuratedCommitments.sol";
import {
    StreamNativeCuratedClock as Clock
} from "../../../smart-contracts/domains/mint/StreamNativeCuratedClock.sol";
import { ReentrancyGuard } from "../../../smart-contracts/vendor/openzeppelin/ReentrancyGuard.sol";

interface CuratedCommitmentVm {
    function warp(uint256 timestamp) external;
    function roll(uint256 number) external;
    function chainId(uint256 id) external;
    function deal(address account, uint256 amount) external;
    function prank(address caller) external;
    function startPrank(address caller) external;
    function stopPrank() external;
    function expectRevert(bytes calldata reason) external;
    function expectRevert(bytes4 selector) external;
    function expectEmit(bool topic1, bool topic2, bool topic3, bool data, address emitter) external;
}

contract CuratedCommitmentFeeProvider {
    uint256 public value;
    bool public broken;
    error ProviderUnavailable();

    function configure(uint256 fee, bool fails) external {
        value = fee;
        broken = fails;
    }

    function fee() external view returns (uint256) {
        if (broken) revert ProviderUnavailable();
        return value;
    }
}

/// @dev Book boundary fixture only: no claim of Manager, proof-tree or official recorder integration.
///      The supplied leaf represents the host's already-verified canonical content leaf.
contract CuratedCommitmentHost is ReentrancyGuard {
    Book.State private _book;
    mapping(bytes32 => C.Admission) private _admission;
    mapping(address => mapping(address => bool)) private _refundDelegates;
    mapping(bytes32 => uint256) public price;
    CuratedCommitmentFeeProvider public immutable provider;
    address public settlementRecipient;
    address public immutable feeRecipient;
    bool public lateFailure;
    uint256 public settled;
    uint256 public minted;

    error LateFailure();
    error FeeMismatch();
    error TransferFailed();
    error SurplusUnavailable();
    error DelegateNotAuthorized(address buyer, address caller);

    constructor(CuratedCommitmentFeeProvider p, address settlement, address fees) {
        provider = p;
        settlementRecipient = settlement;
        feeRecipient = fees;
    }

    function configure(bytes32 saleId, uint256 amount, C.Admission memory admission) external {
        Book.validateWindows(admission.windows);
        price[saleId] = amount;
        _admission[saleId] = admission;
    }

    /// @dev Deliberately permits malformed host inputs to test the book's independent bounds checks.
    function setAdmission(bytes32 saleId, C.Admission memory admission) external {
        _admission[saleId] = admission;
    }

    function setSettlementRecipient(address recipient) external {
        settlementRecipient = recipient;
    }

    function setLateFailure(bool value) external {
        lateFailure = value;
    }

    /// @dev Account-owned test grant, not a claim of production registry integration.
    function grantRefundDelegate(address delegate, bool enabled) external {
        _refundDelegates[msg.sender][delegate] = enabled;
    }

    function commitmentHash(bytes32 saleId, address buyer, bytes32 leaf, bytes32 salt)
        external
        view
        returns (bytes32)
    {
        return Book.commitmentHash(saleId, buyer, leaf, salt);
    }

    function commit(bytes32 saleId, address buyer, bytes32 commitment)
        external
        payable
        nonReentrant
    {
        Book.commit(_book, saleId, buyer, commitment, price[saleId], _admission[saleId]);
    }

    function reveal(bytes32 saleId, address buyer, bytes32 commitment, bytes32 leaf, bytes32 salt)
        external
        payable
        nonReentrant
        returns (uint256 amount)
    {
        // Only this simulated mint path reads the live fee provider; commit/refund paths never do.
        uint256 liveFee = provider.fee();
        if (msg.value != liveFee) revert FeeMismatch();
        amount = Book.consumeForReveal(
            _book, saleId, buyer, commitment, leaf, salt, _admission[saleId]
        );
        (bool ok,) = settlementRecipient.call{ value: amount }("");
        if (!ok) revert TransferFailed();
        if (liveFee != 0) {
            (ok,) = feeRecipient.call{ value: liveFee }("");
            if (!ok) revert TransferFailed();
        }
        if (lateFailure) revert LateFailure();
        settled += amount;
        ++minted;
        Book.requireSolvent(_book);
    }

    function unlock(bytes32 saleId, address buyer, bytes32 commitment)
        external
        nonReentrant
        returns (bool newlyCredited, uint256 amount)
    {
        return Book.unlockRefund(_book, saleId, buyer, commitment, _admission[saleId]);
    }

    function claim(bytes32 saleId, address buyer, address recipient)
        external
        nonReentrant
        returns (uint256 amount)
    {
        amount = Book.debitRefund(_book, saleId, buyer, recipient);
        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert TransferFailed();
        Book.requireSolvent(_book);
    }

    function claimFor(bytes32 saleId, address buyer)
        external
        nonReentrant
        returns (uint256 amount)
    {
        if (!_refundDelegates[buyer][msg.sender]) {
            revert DelegateNotAuthorized(buyer, msg.sender);
        }
        amount = Book.debitDelegatedRefund(_book, saleId, buyer);
        (bool ok,) = buyer.call{ value: amount }("");
        if (!ok) revert TransferFailed();
        Book.requireSolvent(_book);
    }

    function record(bytes32 saleId, address buyer, bytes32 commitment)
        external
        view
        returns (C.CommitRecord memory)
    {
        return Book.record(_book, saleId, buyer, commitment);
    }

    function refundableBalance(bytes32 saleId, address buyer) external view returns (uint256) {
        return Book.refundableBalance(_book, saleId, buyer);
    }

    function liabilities() external view returns (uint256, uint256, uint256) {
        return Book.liabilities(_book);
    }

    function sweepSurplus(address recipient, uint256 amount) external nonReentrant {
        Book.requireSolvent(_book);
        (,, uint256 total) = Book.liabilities(_book);
        if (amount > address(this).balance - total) revert SurplusUnavailable();
        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert TransferFailed();
        Book.requireSolvent(_book);
    }
}

/// @dev Real local clock composition, with the fixture supplying its already-authorized stop edge.
contract CuratedCommitmentClockSource {
    Clock.History private _history;

    function stop() external {
        Clock.setGlobal(_history, true);
    }

    function admission(bytes32 saleId, Clock.Schedule memory schedule)
        external
        view
        returns (C.Admission memory a)
    {
        Clock.View memory v = Clock.snapshot(_history, saleId, 1, schedule);
        a.windows = C.Windows(v.commitOpen, v.commitClose, v.revealOpen, v.revealClose);
        a.stopped = v.globalPaused || v.localPaused || v.collectionStopped;
        a.refundMatured = v.matured || v.escapeReached;
    }
}

contract CuratedClaimReceiver {
    CuratedCommitmentHost public host;
    bytes32 public saleId;
    bool public rejectPayment;
    bool public attemptReentry;
    bool public reentrySucceeded;
    bytes public reentryResult;
    uint256 public observedCredit;
    uint256 public received;

    function configure(CuratedCommitmentHost target, bytes32 sale, bool reject, bool reenter)
        external
    {
        host = target;
        saleId = sale;
        rejectPayment = reject;
        attemptReentry = reenter;
    }

    receive() external payable {
        if (rejectPayment) revert("receiver rejects");
        observedCredit = host.refundableBalance(saleId, address(this));
        received += msg.value;
        if (attemptReentry) {
            (reentrySucceeded, reentryResult) = address(host)
                .call(abi.encodeCall(host.claim, (saleId, address(this), address(this))));
        }
    }
}

contract CuratedSettlementReceiver {
    CuratedCommitmentHost public host;
    bytes32 public saleId;
    address public buyer;
    bytes32 public commitment;
    C.Status public observedStatus;
    uint256 public observedPending;
    uint256 public received;

    function configure(CuratedCommitmentHost h, bytes32 sale, address account, bytes32 value)
        external
    {
        host = h;
        saleId = sale;
        buyer = account;
        commitment = value;
    }

    receive() external payable {
        observedStatus = host.record(saleId, buyer, commitment).status;
        (observedPending,,) = host.liabilities();
        received += msg.value;
    }
}

contract CuratedForcedValue {
    constructor(address payable target) payable {
        selfdestruct(target);
    }
}

contract StreamNativeCuratedCommitmentsTest {
    CuratedCommitmentVm private constant vm =
        CuratedCommitmentVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant SALE = keccak256("curated sale");
    bytes32 private constant OTHER_SALE = keccak256("other curated sale");
    bytes32 private constant LEAF = keccak256("already verified canonical content leaf");
    bytes32 private constant SALT = keccak256("private salt");
    uint256 private constant PRICE = 1000;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant SELLER = address(0x5E11);
    address private constant FEES = address(0xFEE);
    CuratedCommitmentFeeProvider private provider;
    CuratedCommitmentHost private host;
    uint256 private originalChainId;

    error UintMismatch(uint256 actual, uint256 expected);
    error BytesMismatch(bytes actual, bytes expected);
    error HashMismatch(bytes32 actual, bytes32 expected);

    function assertEq(uint256 actual, uint256 expected) private pure {
        if (actual != expected) revert UintMismatch(actual, expected);
    }

    function assertEq(bytes32 actual, bytes32 expected) private pure {
        if (actual != expected) revert HashMismatch(actual, expected);
    }

    function assertEq(bytes memory actual, bytes memory expected) private pure {
        if (keccak256(actual) != keccak256(expected)) revert BytesMismatch(actual, expected);
    }

    function assertNotEq(bytes32 actual, bytes32 unexpected) private pure {
        require(actual != unexpected, "unexpected hash equality");
    }

    function assertTrue(bool value) private pure {
        require(value, "expected true");
    }

    function assertFalse(bool value) private pure {
        require(!value, "expected false");
    }

    event ContentSelectionCommitted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 selectionCommitment,
        uint256 amount
    );
    event ContentSelectionConsumed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 indexed selectionCommitment,
        uint256 amount
    );
    event ContentSelectionRefundCredited(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 indexed selectionCommitment,
        uint256 amount
    );
    event ContentRefundDebited(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        address indexed recipient,
        uint256 amount
    );

    function setUp() public {
        vm.warp(1000);
        vm.roll(10);
        vm.deal(ALICE, 100_000);
        vm.deal(BOB, 100_000);
        vm.deal(address(this), 100_000);
        provider = new CuratedCommitmentFeeProvider();
        host = new CuratedCommitmentHost(provider, SELLER, FEES);
        host.configure(SALE, PRICE, _admission());
        host.configure(OTHER_SALE, 2 * PRICE, _admission());
    }

    function _admission() private pure returns (C.Admission memory a) {
        a.windows = C.Windows(1000, 1100, 1200, 1400);
    }

    function _hash(bytes32 saleId, address buyer, bytes32 salt) private view returns (bytes32) {
        return host.commitmentHash(saleId, buyer, LEAF, salt);
    }

    function _commit(bytes32 saleId, address buyer, bytes32 salt) private returns (bytes32 value) {
        value = _hash(saleId, buyer, salt);
        uint256 amount = host.price(saleId);
        vm.prank(buyer);
        host.commit{ value: amount }(saleId, buyer, value);
    }

    function _revealTime() private {
        vm.warp(1200);
        vm.roll(11);
    }

    function _assertLiabilities(uint256 pending, uint256 refund) private view {
        (uint256 p, uint256 r, uint256 total) = host.liabilities();
        assertEq(p, pending);
        assertEq(r, refund);
        assertEq(total, pending + refund);
    }

    function testCanonicalCommitmentBindsEveryDomainAndPreimageField() public {
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_COMMIT_V1"),
                block.chainid,
                address(host),
                SALE,
                ALICE,
                LEAF,
                SALT
            )
        );
        assertEq(_hash(SALE, ALICE, SALT), expected);
        assertNotEq(_hash(OTHER_SALE, ALICE, SALT), expected);
        assertNotEq(_hash(SALE, BOB, SALT), expected);
        assertNotEq(_hash(SALE, ALICE, bytes32(uint256(1))), expected);
        assertNotEq(host.commitmentHash(SALE, ALICE, bytes32(uint256(2)), SALT), expected);
        CuratedCommitmentHost other = new CuratedCommitmentHost(provider, SELLER, FEES);
        assertNotEq(other.commitmentHash(SALE, ALICE, LEAF, SALT), expected);
        vm.chainId(block.chainid + 1);
        assertNotEq(_hash(SALE, ALICE, SALT), expected);
    }

    function testExactPriceDepositRecordsBuyerBlockStatusAndCanonicalEvent() public {
        bytes32 value = _hash(SALE, ALICE, SALT);
        vm.expectEmit(true, true, false, true, address(host));
        emit ContentSelectionCommitted(1, SALE, ALICE, value, PRICE);
        vm.prank(ALICE);
        host.commit{ value: PRICE }(SALE, ALICE, value);
        C.CommitRecord memory r = host.record(SALE, ALICE, value);
        assertEq(r.amount, PRICE);
        assertEq(r.committedBlock, 10);
        assertEq(uint256(r.status), uint256(C.Status.PENDING));
        assertEq(uint256(host.record(SALE, BOB, value).status), uint256(C.Status.NONE));
        assertEq(address(host).balance, PRICE);
        assertEq(SELLER.balance, 0);
        assertEq(FEES.balance, 0);
        _assertLiabilities(PRICE, 0);
    }

    function testCommitRejectsMissingPriceAndFeeAllowanceAtCommit() public {
        bytes32 value = _hash(SALE, ALICE, SALT);
        vm.expectRevert(abi.encodeWithSelector(C.ContentPaymentMismatch.selector, PRICE, PRICE - 1));
        vm.prank(ALICE);
        host.commit{ value: PRICE - 1 }(SALE, ALICE, value);
        vm.expectRevert(
            abi.encodeWithSelector(C.ContentPaymentMismatch.selector, PRICE, PRICE + 100)
        );
        vm.prank(ALICE);
        host.commit{ value: PRICE + 100 }(SALE, ALICE, value);
        host.configure(SALE, 0, _admission());
        vm.expectRevert(abi.encodeWithSelector(C.ContentPriceInvalid.selector, 0));
        vm.prank(ALICE);
        host.commit(SALE, ALICE, value);
        assertEq(uint256(host.record(SALE, ALICE, value).status), uint256(C.Status.NONE));
        assertEq(address(host).balance, 0);
        _assertLiabilities(0, 0);
    }

    function testCommitBoundariesAreHalfOpenAndStoppedOrMaturedEntriesFail() public {
        bytes32 value = _hash(SALE, ALICE, SALT);
        vm.warp(999);
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitWindowInvalid.selector, SALE));
        vm.prank(ALICE);
        host.commit{ value: PRICE }(SALE, ALICE, value);
        vm.warp(1100);
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitWindowInvalid.selector, SALE));
        vm.prank(ALICE);
        host.commit{ value: PRICE }(SALE, ALICE, value);
        vm.warp(1000);
        C.Admission memory a = _admission();
        a.stopped = true;
        host.setAdmission(SALE, a);
        vm.expectRevert(C.SaleEntryPaused.selector);
        vm.prank(ALICE);
        host.commit{ value: PRICE }(SALE, ALICE, value);
        a.stopped = false;
        a.refundMatured = true;
        host.setAdmission(SALE, a);
        vm.expectRevert(abi.encodeWithSelector(C.ContentRefundMatured.selector, SALE));
        vm.prank(ALICE);
        host.commit{ value: PRICE }(SALE, ALICE, value);
        host.setAdmission(SALE, _admission());
        _commit(SALE, ALICE, SALT);
        vm.warp(1099);
        _commit(SALE, BOB, SALT);
        _assertLiabilities(2 * PRICE, 0);
    }

    function testMalformedWindowsFailCommitRevealAndRefundIndependently() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        for (uint256 i; i < 3; ++i) {
            C.Admission memory a = _admission();
            if (i == 0) a.windows.commitClose = a.windows.commitOpen;
            if (i == 1) a.windows.commitClose = a.windows.revealOpen + 1;
            if (i == 2) a.windows.revealOpen = a.windows.revealClose;
            host.setAdmission(SALE, a);
            vm.expectRevert(C.ContentWindowsInvalid.selector);
            vm.prank(BOB);
            host.commit{ value: PRICE }(SALE, BOB, bytes32(i + 1));
            vm.expectRevert(C.ContentWindowsInvalid.selector);
            vm.prank(ALICE);
            host.reveal(SALE, ALICE, value, LEAF, SALT);
            vm.expectRevert(C.ContentWindowsInvalid.selector);
            host.unlock(SALE, ALICE, value);
        }
        _assertLiabilities(PRICE, 0);
        assertEq(uint256(host.record(SALE, ALICE, value).status), uint256(C.Status.PENDING));
    }

    function testBuyerMustBeCallerAtCommitAndReveal() public {
        bytes32 value = _hash(SALE, ALICE, SALT);
        vm.expectRevert(abi.encodeWithSelector(C.ContentBuyerInvalid.selector, ALICE, BOB));
        vm.prank(BOB);
        host.commit{ value: PRICE }(SALE, ALICE, value);
        _commit(SALE, ALICE, SALT);
        _revealTime();
        vm.expectRevert(abi.encodeWithSelector(C.ContentBuyerInvalid.selector, ALICE, BOB));
        vm.prank(BOB);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        _assertLiabilities(PRICE, 0);
    }

    function testCopiedCommitmentCannotSquatBuyerKeyOrRevealVictimsPreimage() public {
        bytes32 value = _hash(SALE, ALICE, SALT);
        vm.prank(BOB);
        host.commit{ value: PRICE }(SALE, BOB, value);
        _commit(SALE, ALICE, SALT);
        _revealTime();
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentInvalid.selector, value));
        vm.prank(BOB);
        host.reveal(SALE, BOB, value, LEAF, SALT);
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        assertEq(SELLER.balance, PRICE);
        _assertLiabilities(PRICE, 0);
        vm.warp(1400);
        host.unlock(SALE, BOB, value);
        assertEq(host.refundableBalance(SALE, BOB), PRICE);
        assertEq(host.refundableBalance(SALE, ALICE), 0);
    }

    function testSameBuyerCannotOverwriteOrRedepositCommitment() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        vm.roll(20);
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentAlreadyExists.selector, value));
        vm.prank(ALICE);
        host.commit{ value: PRICE }(SALE, ALICE, value);
        assertEq(host.record(SALE, ALICE, value).committedBlock, 10);
        assertEq(address(host).balance, PRICE);
        C.Admission memory a = _admission();
        a.refundMatured = true;
        host.setAdmission(SALE, a);
        host.unlock(SALE, ALICE, value);
        host.setAdmission(SALE, _admission());
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentAlreadyExists.selector, value));
        vm.prank(ALICE);
        host.commit{ value: PRICE }(SALE, ALICE, value);
        _assertLiabilities(0, PRICE);
    }

    function testWrongLeafSaltSaleAndChainCannotConsumeDeposit() public {
        // Store across calls: the optimizer assumes CHAINID stays constant within a transaction,
        // whereas the test cheatcode deliberately changes it mid-transaction.
        originalChainId = block.chainid;
        bytes32 value = _commit(SALE, ALICE, SALT);
        _revealTime();
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentInvalid.selector, value));
        host.reveal(SALE, ALICE, value, bytes32(uint256(1)), SALT);
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentInvalid.selector, value));
        host.reveal(SALE, ALICE, value, LEAF, bytes32(uint256(2)));
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentInvalid.selector, value));
        host.reveal(OTHER_SALE, ALICE, value, LEAF, SALT);
        vm.chainId(originalChainId + 1);
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentInvalid.selector, value));
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        vm.chainId(originalChainId);
        vm.stopPrank();
        _assertLiabilities(PRICE, 0);
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
    }

    function testRevealRequiresStrictlyLaterBlockEvenWhenTimestampAdvances() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        vm.warp(1200);
        vm.expectRevert(abi.encodeWithSelector(C.ContentRevealSameBlock.selector, 10, 10));
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        vm.roll(11);
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
    }

    function testCommitmentCopiedToAnotherAdapterCannotConsumeThere() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        CuratedCommitmentHost other = new CuratedCommitmentHost(provider, SELLER, FEES);
        other.configure(SALE, PRICE, _admission());
        vm.prank(ALICE);
        other.commit{ value: PRICE }(SALE, ALICE, value);
        _revealTime();
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentInvalid.selector, value));
        vm.prank(ALICE);
        other.reveal(SALE, ALICE, value, LEAF, SALT);
        assertEq(uint256(other.record(SALE, ALICE, value).status), uint256(C.Status.PENDING));
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        vm.warp(1400);
        other.unlock(SALE, ALICE, value);
        vm.prank(ALICE);
        other.claim(SALE, ALICE, ALICE);
        assertEq(address(other).balance, 0);
    }

    function testRevealWindowIsHalfOpenAndPauseLeavesDepositPending() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        vm.roll(11);
        vm.warp(1199);
        vm.expectRevert(abi.encodeWithSelector(C.ContentRevealWindowInvalid.selector, value));
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        vm.warp(1400);
        vm.expectRevert(abi.encodeWithSelector(C.ContentRevealWindowInvalid.selector, value));
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        vm.warp(1200);
        C.Admission memory a = _admission();
        a.stopped = true;
        host.setAdmission(SALE, a);
        vm.expectRevert(C.SaleEntryPaused.selector);
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        _assertLiabilities(PRICE, 0);
    }

    function testEffectiveHostWindowsAreUsedWithoutChangingCommitmentIdentity() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        C.Admission memory a = _admission();
        a.windows = C.Windows(1000, 1150, 1250, 1450);
        host.setAdmission(SALE, a);
        vm.roll(11);
        vm.warp(1200);
        vm.expectRevert(abi.encodeWithSelector(C.ContentRevealWindowInvalid.selector, value));
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        vm.warp(1400);
        vm.expectRevert(abi.encodeWithSelector(C.ContentRefundNotReady.selector, value));
        host.unlock(SALE, ALICE, value);
        assertEq(_hash(SALE, ALICE, SALT), value);
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
    }

    function testConsumeEffectsPrecedeSettlementAndEmitExactDeposit() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        CuratedSettlementReceiver receiver = new CuratedSettlementReceiver();
        receiver.configure(host, SALE, ALICE, value);
        host.setSettlementRecipient(address(receiver));
        _revealTime();
        vm.expectEmit(true, true, true, true, address(host));
        emit ContentSelectionConsumed(1, SALE, ALICE, value, PRICE);
        vm.prank(ALICE);
        uint256 amount = host.reveal(SALE, ALICE, value, LEAF, SALT);
        assertEq(amount, PRICE);
        assertEq(uint256(receiver.observedStatus()), uint256(C.Status.CONSUMED));
        assertEq(receiver.observedPending(), 0);
        assertEq(receiver.received(), PRICE);
        assertEq(host.minted(), 1);
        assertEq(address(host).balance, 0);
        _assertLiabilities(0, 0);
    }

    function testLateFailureRollsBackSettlementFeeConsumptionAndAllowsExactRetry() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        provider.configure(100, false);
        host.setLateFailure(true);
        _revealTime();
        uint256 buyerBalance = ALICE.balance;
        vm.expectRevert(CuratedCommitmentHost.LateFailure.selector);
        vm.prank(ALICE);
        host.reveal{ value: 100 }(SALE, ALICE, value, LEAF, SALT);
        assertEq(ALICE.balance, buyerBalance);
        assertEq(SELLER.balance, 0);
        assertEq(FEES.balance, 0);
        assertEq(host.minted(), 0);
        assertEq(host.settled(), 0);
        assertEq(address(host).balance, PRICE);
        assertEq(uint256(host.record(SALE, ALICE, value).status), uint256(C.Status.PENDING));
        _assertLiabilities(PRICE, 0);
        host.setLateFailure(false);
        vm.prank(ALICE);
        host.reveal{ value: 100 }(SALE, ALICE, value, LEAF, SALT);
        assertEq(SELLER.balance, PRICE);
        assertEq(FEES.balance, 100);
        assertEq(host.minted(), 1);
        _assertLiabilities(0, 0);
    }

    function testFeeIsReadOnlyAtRevealAndNeverDeductedFromSavedPrice() public {
        provider.configure(100, true);
        bytes32 value = _commit(SALE, ALICE, SALT);
        _revealTime();
        vm.expectRevert(CuratedCommitmentFeeProvider.ProviderUnavailable.selector);
        vm.prank(ALICE);
        host.reveal{ value: 100 }(SALE, ALICE, value, LEAF, SALT);
        provider.configure(200, false);
        vm.expectRevert(CuratedCommitmentHost.FeeMismatch.selector);
        vm.prank(ALICE);
        host.reveal{ value: 100 }(SALE, ALICE, value, LEAF, SALT);
        assertEq(host.record(SALE, ALICE, value).amount, PRICE);
        vm.prank(ALICE);
        host.reveal{ value: 200 }(SALE, ALICE, value, LEAF, SALT);
        assertEq(SELLER.balance, PRICE);
        assertEq(FEES.balance, 200);
        _assertLiabilities(0, 0);
    }

    function testMatureConversionIsPermissionlessFullEventedAndIdempotent() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        vm.warp(1399);
        vm.expectRevert(abi.encodeWithSelector(C.ContentRefundNotReady.selector, value));
        host.unlock(SALE, ALICE, value);
        vm.warp(1400);
        vm.expectEmit(true, true, true, true, address(host));
        emit ContentSelectionRefundCredited(1, SALE, ALICE, value, PRICE);
        vm.prank(BOB);
        (bool changed, uint256 amount) = host.unlock(SALE, ALICE, value);
        assertTrue(changed);
        assertEq(amount, PRICE);
        (changed, amount) = host.unlock(SALE, ALICE, value);
        assertFalse(changed);
        assertEq(amount, 0);
        assertEq(host.refundableBalance(SALE, ALICE), PRICE);
        assertEq(host.refundableBalance(SALE, BOB), 0);
        _assertLiabilities(0, PRICE);
    }

    function testRefundAndDirectedClaimIgnorePauseAndBrokenProvider() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        C.Admission memory a = _admission();
        a.stopped = true;
        host.setAdmission(SALE, a);
        provider.configure(100, true);
        vm.expectRevert(CuratedCommitmentFeeProvider.ProviderUnavailable.selector);
        provider.fee();
        vm.warp(1400);
        host.unlock(SALE, ALICE, value);
        uint256 recipientBalance = BOB.balance;
        vm.expectEmit(true, true, true, true, address(host));
        emit ContentRefundDebited(1, SALE, ALICE, BOB, PRICE);
        vm.prank(ALICE);
        assertEq(host.claim(SALE, ALICE, BOB), PRICE);
        assertEq(BOB.balance, recipientBalance + PRICE);
        assertEq(host.refundableBalance(SALE, ALICE), 0);
        _assertLiabilities(0, 0);
        vm.expectRevert(abi.encodeWithSelector(C.ContentRefundEmpty.selector, SALE, ALICE));
        vm.prank(ALICE);
        host.claim(SALE, ALICE, BOB);
    }

    function testTrustedTerminalAdmissionUnlocksBeforeCloseAndStopsReveal() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        _revealTime();
        C.Admission memory a = _admission();
        a.refundMatured = true;
        host.setAdmission(SALE, a);
        vm.expectRevert(abi.encodeWithSelector(C.ContentRefundMatured.selector, SALE));
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        a.stopped = true;
        host.setAdmission(SALE, a);
        host.unlock(SALE, ALICE, value);
        assertEq(host.refundableBalance(SALE, ALICE), PRICE);
        _assertLiabilities(0, PRICE);
    }

    function testTerminalRecordsCannotRevealOrRefundAgain() public {
        bytes32 consumed = _commit(SALE, ALICE, SALT);
        bytes32 refunded = _commit(SALE, BOB, SALT);
        _revealTime();
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, consumed, LEAF, SALT);
        vm.expectRevert(
            abi.encodeWithSelector(
                C.ContentCommitmentTerminal.selector, consumed, C.Status.CONSUMED
            )
        );
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, consumed, LEAF, SALT);
        vm.warp(1400);
        vm.expectRevert(
            abi.encodeWithSelector(
                C.ContentCommitmentTerminal.selector, consumed, C.Status.CONSUMED
            )
        );
        host.unlock(SALE, ALICE, consumed);
        host.unlock(SALE, BOB, refunded);
        // Even a hostile host clock rewind cannot revive a credited commitment.
        vm.warp(1250);
        vm.expectRevert(
            abi.encodeWithSelector(
                C.ContentCommitmentTerminal.selector, refunded, C.Status.REFUND_CREDITED
            )
        );
        vm.prank(BOB);
        host.reveal(SALE, BOB, refunded, LEAF, SALT);
    }

    function testCreditsAggregatePerBuyerAndRemainIsolatedBySale() public {
        bytes32 first = _commit(SALE, ALICE, SALT);
        bytes32 second = _commit(SALE, ALICE, bytes32(uint256(99)));
        bytes32 other = _commit(OTHER_SALE, ALICE, SALT);
        vm.warp(1400);
        host.unlock(SALE, ALICE, first);
        host.unlock(SALE, ALICE, second);
        host.unlock(OTHER_SALE, ALICE, other);
        assertEq(host.refundableBalance(SALE, ALICE), 2 * PRICE);
        assertEq(host.refundableBalance(OTHER_SALE, ALICE), 2 * PRICE);
        _assertLiabilities(0, 4 * PRICE);
        vm.prank(ALICE);
        host.claim(SALE, ALICE, ALICE);
        assertEq(host.refundableBalance(OTHER_SALE, ALICE), 2 * PRICE);
        assertEq(address(host).balance, 2 * PRICE);
        _assertLiabilities(0, 2 * PRICE);
    }

    function testClaimRejectsWrongBuyerAndInvalidDestinationsWithoutDebiting() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        vm.warp(1400);
        host.unlock(SALE, ALICE, value);
        vm.expectRevert(abi.encodeWithSelector(C.ContentBuyerInvalid.selector, ALICE, BOB));
        vm.prank(BOB);
        host.claim(SALE, ALICE, BOB);
        vm.startPrank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(C.ContentRefundRecipientInvalid.selector, address(0))
        );
        host.claim(SALE, ALICE, address(0));
        vm.expectRevert(
            abi.encodeWithSelector(C.ContentRefundRecipientInvalid.selector, address(host))
        );
        host.claim(SALE, ALICE, address(host));
        vm.stopPrank();
        assertEq(host.refundableBalance(SALE, ALICE), PRICE);
        _assertLiabilities(0, PRICE);
    }

    function testReceiverSeesZeroCreditAndSharedGuardRejectsClaimReentry() public {
        CuratedClaimReceiver receiver = new CuratedClaimReceiver();
        receiver.configure(host, SALE, false, true);
        vm.deal(address(receiver), PRICE);
        bytes32 value = _commit(SALE, address(receiver), SALT);
        vm.warp(1400);
        host.unlock(SALE, address(receiver), value);
        vm.prank(address(receiver));
        host.claim(SALE, address(receiver), address(receiver));
        assertEq(receiver.observedCredit(), 0);
        assertEq(receiver.received(), PRICE);
        assertFalse(receiver.reentrySucceeded());
        assertEq(
            receiver.reentryResult(),
            abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
        );
        _assertLiabilities(0, 0);
    }

    function testRevertingReceiverRestoresCreditAndBuyerCanRedirectExactClaim() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        CuratedClaimReceiver receiver = new CuratedClaimReceiver();
        receiver.configure(host, SALE, true, false);
        vm.warp(1400);
        host.unlock(SALE, ALICE, value);
        vm.expectRevert(CuratedCommitmentHost.TransferFailed.selector);
        vm.prank(ALICE);
        host.claim(SALE, ALICE, address(receiver));
        assertEq(host.refundableBalance(SALE, ALICE), PRICE);
        assertEq(address(host).balance, PRICE);
        _assertLiabilities(0, PRICE);
        vm.prank(ALICE);
        host.claim(SALE, ALICE, ALICE);
        _assertLiabilities(0, 0);
    }

    function testDelegatedClaimRequiresLiveBuyerGrantAndCannotRedirect() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        vm.warp(1400);
        host.unlock(SALE, ALICE, value);
        vm.expectRevert(
            abi.encodeWithSelector(CuratedCommitmentHost.DelegateNotAuthorized.selector, ALICE, BOB)
        );
        vm.prank(BOB);
        host.claimFor(SALE, ALICE);
        vm.prank(ALICE);
        host.grantRefundDelegate(BOB, true);
        // A delegate still cannot use the direct surface's caller-chosen destination.
        vm.expectRevert(abi.encodeWithSelector(C.ContentBuyerInvalid.selector, ALICE, BOB));
        vm.prank(BOB);
        host.claim(SALE, ALICE, BOB);
        vm.prank(ALICE);
        host.grantRefundDelegate(BOB, false);
        vm.expectRevert(
            abi.encodeWithSelector(CuratedCommitmentHost.DelegateNotAuthorized.selector, ALICE, BOB)
        );
        vm.prank(BOB);
        host.claimFor(SALE, ALICE);
        assertEq(host.refundableBalance(SALE, ALICE), PRICE);
        vm.prank(ALICE);
        host.grantRefundDelegate(BOB, true);
        provider.configure(100, true);
        uint256 buyerBalance = ALICE.balance;
        uint256 delegateBalance = BOB.balance;
        vm.expectEmit(true, true, true, true, address(host));
        emit ContentRefundDebited(1, SALE, ALICE, ALICE, PRICE);
        vm.prank(BOB);
        assertEq(host.claimFor(SALE, ALICE), PRICE);
        assertEq(ALICE.balance, buyerBalance + PRICE);
        assertEq(BOB.balance, delegateBalance);
        assertEq(host.refundableBalance(SALE, ALICE), 0);
        _assertLiabilities(0, 0);
    }

    function testDelegatedReceiverSeesDebitAndCannotReenterSharedGuard() public {
        CuratedClaimReceiver receiver = new CuratedClaimReceiver();
        receiver.configure(host, SALE, false, true);
        vm.deal(address(receiver), PRICE);
        bytes32 value = _commit(SALE, address(receiver), SALT);
        vm.prank(address(receiver));
        host.grantRefundDelegate(BOB, true);
        vm.warp(1400);
        host.unlock(SALE, address(receiver), value);
        vm.prank(BOB);
        host.claimFor(SALE, address(receiver));
        assertEq(receiver.observedCredit(), 0);
        assertEq(receiver.received(), PRICE);
        assertFalse(receiver.reentrySucceeded());
        assertEq(
            receiver.reentryResult(),
            abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
        );
        _assertLiabilities(0, 0);
    }

    function testRejectedDelegatedTransferPreservesBuyerDirectedClaim() public {
        CuratedClaimReceiver receiver = new CuratedClaimReceiver();
        receiver.configure(host, SALE, true, false);
        vm.deal(address(receiver), PRICE);
        bytes32 value = _commit(SALE, address(receiver), SALT);
        vm.prank(address(receiver));
        host.grantRefundDelegate(BOB, true);
        vm.warp(1400);
        host.unlock(SALE, address(receiver), value);
        vm.expectRevert(CuratedCommitmentHost.TransferFailed.selector);
        vm.prank(BOB);
        host.claimFor(SALE, address(receiver));
        assertEq(host.refundableBalance(SALE, address(receiver)), PRICE);
        _assertLiabilities(0, PRICE);
        provider.configure(100, true);
        uint256 destinationBalance = ALICE.balance;
        vm.prank(address(receiver));
        host.claim(SALE, address(receiver), ALICE);
        assertEq(ALICE.balance, destinationBalance + PRICE);
        _assertLiabilities(0, 0);
    }

    function testActualClockEscapeCollapsesWindowsButRefundRemainsLive() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        CuratedCommitmentClockSource clockSource = new CuratedCommitmentClockSource();
        Clock.Schedule memory schedule = Clock.Schedule(1000, 1100, 1200, 1400, 1500);
        vm.warp(1050);
        clockSource.stop();
        vm.warp(1499);
        C.Admission memory a = clockSource.admission(SALE, schedule);
        assertEq(a.windows.commitClose, 1500);
        assertEq(a.windows.revealOpen, 1500);
        assertEq(a.windows.revealClose, 1500);
        assertFalse(a.refundMatured);
        host.setAdmission(SALE, a);
        vm.expectRevert(C.ContentWindowsInvalid.selector);
        host.unlock(SALE, ALICE, value);
        vm.warp(1500);
        a = clockSource.admission(SALE, schedule);
        assertTrue(a.stopped);
        assertTrue(a.refundMatured);
        host.setAdmission(SALE, a);
        // Terminal refund admission does not weaken either entry primitive's strict windows.
        vm.expectRevert(C.ContentWindowsInvalid.selector);
        vm.prank(BOB);
        host.commit{ value: PRICE }(SALE, BOB, value);
        vm.roll(11);
        vm.expectRevert(C.ContentWindowsInvalid.selector);
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        provider.configure(100, true);
        (bool changed, uint256 amount) = host.unlock(SALE, ALICE, value);
        assertTrue(changed);
        assertEq(amount, PRICE);
        vm.prank(ALICE);
        host.claim(SALE, ALICE, ALICE);
        assertEq(address(host).balance, 0);
        _assertLiabilities(0, 0);
    }

    function testForcedSurplusCannotReplaceOrConsumeTrackedDepositsAndCredits() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        new CuratedForcedValue{ value: 77 }(payable(address(host)));
        assertEq(address(host).balance, PRICE + 77);
        _assertLiabilities(PRICE, 0);
        vm.expectRevert(CuratedCommitmentHost.SurplusUnavailable.selector);
        host.sweepSurplus(BOB, 78);
        host.sweepSurplus(BOB, 77);
        vm.warp(1400);
        host.unlock(SALE, ALICE, value);
        vm.expectRevert(CuratedCommitmentHost.SurplusUnavailable.selector);
        host.sweepSurplus(BOB, 1);
        vm.prank(ALICE);
        host.claim(SALE, ALICE, ALICE);
        assertEq(address(host).balance, 0);
        _assertLiabilities(0, 0);
    }

    function testInsolventBookCannotUseNewBuyerDepositOrRevealFeeToHideDeficit() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        vm.deal(address(host), PRICE - 1);
        bytes32 other = _hash(SALE, BOB, SALT);
        vm.expectRevert(abi.encodeWithSelector(C.ContentEscrowInsolvent.selector, PRICE - 1, PRICE));
        vm.prank(BOB);
        host.commit{ value: PRICE }(SALE, BOB, other);
        provider.configure(100, false);
        _revealTime();
        vm.expectRevert(abi.encodeWithSelector(C.ContentEscrowInsolvent.selector, PRICE - 1, PRICE));
        vm.prank(ALICE);
        host.reveal{ value: 100 }(SALE, ALICE, value, LEAF, SALT);
        _assertLiabilities(PRICE, 0);
        assertEq(uint256(host.record(SALE, BOB, other).status), uint256(C.Status.NONE));
    }

    function testInsolvencyRefusesConversionAndClaimWithoutReducingCredit() public {
        bytes32 value = _commit(SALE, ALICE, SALT);
        vm.warp(1400);
        vm.deal(address(host), PRICE - 1);
        vm.expectRevert(abi.encodeWithSelector(C.ContentEscrowInsolvent.selector, PRICE - 1, PRICE));
        host.unlock(SALE, ALICE, value);
        _assertLiabilities(PRICE, 0);
        vm.deal(address(host), PRICE);
        host.unlock(SALE, ALICE, value);
        vm.deal(address(host), PRICE - 1);
        vm.expectRevert(abi.encodeWithSelector(C.ContentEscrowInsolvent.selector, PRICE - 1, PRICE));
        vm.prank(ALICE);
        host.claim(SALE, ALICE, ALICE);
        assertEq(host.refundableBalance(SALE, ALICE), PRICE);
        _assertLiabilities(0, PRICE);
    }

    function testUnknownAndZeroCommitmentsCannotCreateFalseRecords() public {
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentInvalid.selector, bytes32(0)));
        vm.prank(ALICE);
        host.commit{ value: PRICE }(SALE, ALICE, bytes32(0));
        bytes32 value = _hash(SALE, ALICE, SALT);
        _revealTime();
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentInvalid.selector, value));
        vm.prank(ALICE);
        host.reveal(SALE, ALICE, value, LEAF, SALT);
        vm.warp(1400);
        vm.expectRevert(abi.encodeWithSelector(C.ContentCommitmentInvalid.selector, value));
        host.unlock(SALE, ALICE, value);
        _assertLiabilities(0, 0);
    }

    function testFullWidthPriceSurvivesDepositConversionAndClaim() public {
        uint256 amount = (uint256(1) << 200) + 123;
        host.configure(SALE, amount, _admission());
        vm.deal(ALICE, amount);
        bytes32 value = _commit(SALE, ALICE, SALT);
        assertEq(host.record(SALE, ALICE, value).amount, amount);
        vm.warp(1400);
        host.unlock(SALE, ALICE, value);
        vm.prank(ALICE);
        host.claim(SALE, ALICE, ALICE);
        assertEq(ALICE.balance, amount);
        assertEq(address(host).balance, 0);
        _assertLiabilities(0, 0);
    }

    function testFuzzRefundConservesBothDepositsAndForcedSurplus(
        uint96 priceSeed,
        uint96 surplusSeed
    ) public {
        uint256 amount = priceSeed == 0 ? 1 : uint256(priceSeed);
        uint256 surplus = uint256(surplusSeed);
        host.configure(SALE, amount, _admission());
        vm.deal(ALICE, amount);
        vm.deal(BOB, amount);
        vm.deal(address(this), surplus);
        bytes32 first = _commit(SALE, ALICE, SALT);
        bytes32 second = _commit(SALE, BOB, SALT);
        new CuratedForcedValue{ value: surplus }(payable(address(host)));
        vm.warp(1400);
        host.unlock(SALE, ALICE, first);
        host.unlock(SALE, BOB, second);
        vm.prank(ALICE);
        host.claim(SALE, ALICE, ALICE);
        vm.prank(BOB);
        host.claim(SALE, BOB, BOB);
        assertEq(ALICE.balance, amount);
        assertEq(BOB.balance, amount);
        assertEq(address(host).balance, surplus);
        _assertLiabilities(0, 0);
    }
}
