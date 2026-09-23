// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamImmediateSaleReveal as Reveal
} from "../../../smart-contracts/domains/mint/StreamImmediateSaleReveal.sol";
import {
    StreamImmediateSaleEntropyPolicy as Reads
} from "../../../smart-contracts/domains/mint/StreamImmediateSaleEntropyPolicy.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamImmediateSaleReveal as R
} from "../../../smart-contracts/interfaces/stream/mint/IStreamImmediateSaleReveal.sol";
import {
    IStreamRevealFeeEscrow as F
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";

/// @dev Typed Core/Coordinator boundaries only; no claim of genuine mint or governance execution.
contract TerminalSaleCoreFixture {
    address public selected;
    address public original;
    uint256 public lifecycle = 2;
    uint256 public collection = 7;

    function set(address value) external {
        selected = value;
        original = value;
    }

    function setOriginal(address value) external {
        original = value;
    }

    function setLifecycle(uint256 value) external {
        lifecycle = value;
    }

    function setCollection(uint256 value) external {
        collection = value;
    }

    function getSatellitePointer(bytes32) external view returns (uint256[10] memory a) {
        a[0] = uint256(uint160(selected));
        a[1] = uint256(selected.codehash);
        a[6] = 1;
        a[9] = 1;
    }

    function tokenCollectionIdentity(uint256) external view returns (bool, uint256, uint256, bool) {
        return (true, collection, 13, lifecycle == 3);
    }

    function tokenLifecycle(uint256) external view returns (uint256) {
        return lifecycle;
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return original;
    }
}

contract TerminalSaleCoordinatorFixture {
    address public immutable core;
    bool public capability = true;
    uint8 public fault;
    P.PolicyRecord private _p;
    F.CollectionRevealPolicy private _reveal;
    mapping(uint256 => uint256) public revealFeeEscrow;
    uint256 public requests;

    constructor(address value) {
        core = value;
        configure(0, 0);
    }

    function configure(uint8 kind, uint256 fee) public {
        // 0 DISABLED; 1 ASYNC NOT_REQUIRED; 2 legacy ASYNC REQUIRED; 3/4 INSTANT REQUIRED/NOT_REQUIRED.
        _p = P.PolicyRecord(
            true,
            kind != 2,
            true,
            kind == 0 ? P.Mode.DISABLED : kind >= 3 ? P.Mode.INSTANT : P.Mode.ASYNC,
            kind >= 3 ? P.SecurityClass.LOW_SECURITY : P.SecurityClass.HIGH_ASSURANCE,
            kind == 2 || kind == 3
                ? P.RenderRequirement.REQUIRED
                : P.RenderRequirement.NOT_REQUIRED,
            kind == 2 ? 0 : 1,
            3,
            bytes32(uint256(91)),
            0,
            bytes32(uint256(92)),
            bytes32(uint256(93))
        );
        _p.contentStateHash = keccak256(
            abi.encode(keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), _p.policyHash, true)
        );
        _reveal = kind == 0 || kind >= 3
            ? F.CollectionRevealPolicy(false, 0, 0, 0, 0)
            : F.CollectionRevealPolicy(true, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, fee);
    }

    function setReveal(F.CollectionRevealPolicy calldata value) external {
        _reveal = value;
    }

    function setCapability(bool value) external {
        capability = value;
    }

    function setFault(uint8 value) external {
        fault = value;
    }

    function setPolicy(P.PolicyRecord calldata value) external {
        _p = value;
    }

    function collectionEntropyPolicy(uint256) external view returns (P.PolicyRecord memory) {
        return _p;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        if (fault == 10) {
            assembly ("memory-safe") {
                mstore(0, 2)
                return(0, 32)
            }
        }
        return capability && id == type(P).interfaceId;
    }

    function collectionRevealPolicy(uint256)
        external
        view
        returns (F.CollectionRevealPolicy memory)
    {
        return _reveal;
    }

    function tokenEntropy(uint256) external view returns (uint256[8] memory a) {
        a[0] = _p.mode == P.Mode.DISABLED
            ? 1
            : _p.renderRequirement == P.RenderRequirement.REQUIRED ? 3 : 2;
        a[2] = _p.mode == P.Mode.DISABLED ? 0 : 0x1234;
        a[3] = _p.providerEpoch;
        a[4] = _p.mode == P.Mode.DISABLED ? 0 : 123;
        if (fault == 1) a[1] = 1;
        if (fault == 2) a[5] = 1;
        if (fault == 3) a[6] = 1;
        if (fault == 4) a[7] = 1;
        if (fault == 5) a[0] = 5;
        if (fault == 8) a[3]++;
        if (fault == 9) a[2] = 1;
    }

    function tokenSeed(uint256) external view returns (bytes32, bool) {
        return (0, fault == 6);
    }

    function tokenEntropyStatus(uint256) external view returns (uint256) {
        return fault == 7
            ? 5
            : (_p.mode == P.Mode.DISABLED
                    ? 1
                    : _p.renderRequirement == P.RenderRequirement.REQUIRED ? 3 : 2);
    }

    function fundRevealFeeEscrow(uint256 id) external payable {
        revealFeeEscrow[id] += msg.value;
    }

    function requestEntropy(uint256 token) external returns (bytes32, uint256) {
        ++requests;
        return (bytes32(token), requests);
    }
}

contract TerminalSaleHarness {
    address public immutable core;
    uint256 public credits;
    uint256 public executions;

    constructor(address value) {
        core = value;
    }

    function quote() external view returns (R.RevealQuote memory) {
        return Reveal.quote(core, 7);
    }

    function execute(uint256 cap) external payable {
        R.RevealQuote memory q = Reveal.quote(core, 7);
        credits += Reveal.preflight(q, msg.value, cap);
        ++executions;
        Reveal.fundAndAttempt(core, 7, 42, q, cap);
    }

    function finishCaptured(R.RevealQuote calldata q, uint256 cap) external {
        Reveal.fundAndAttempt(core, 7, 42, q, cap);
    }
}

contract StreamImmediateSaleEntropyPolicyTest is CharacterizationTestBase {
    TerminalSaleCoreFixture private core;
    TerminalSaleCoordinatorFixture private entropy;
    TerminalSaleHarness private sale;

    function setUp() public {
        core = new TerminalSaleCoreFixture();
        entropy = new TerminalSaleCoordinatorFixture(address(core));
        core.set(address(entropy));
        sale = new TerminalSaleHarness(address(core));
        vm.deal(address(this), 100 ether);
    }

    function testDisabledUsesCanonicalEmptyQuoteNoFeeOrInventedAttempt() public {
        R.RevealQuote memory q = sale.quote();
        require(!q.policy.declared && q.policy.revealFeePerTokenWei == 0);
        vm.recordLogs();
        sale.execute{ value: 19 }(type(uint256).max);
        require(
            sale.credits() == 19 && sale.executions() == 1 && entropy.requests() == 0
                && entropy.revealFeeEscrow(7) == 0
        );
        require(vm.getRecordedLogs().length == 0, "no fabricated request event");
    }

    function testAsyncNotRequiredRetainsFeeEscrowWithoutTokenRequest() public {
        entropy.configure(1, 9);
        vm.recordLogs();
        sale.execute{ value: 12 }(100000);
        require(entropy.revealFeeEscrow(7) == 9 && sale.credits() == 3 && entropy.requests() == 0);
        require(vm.getRecordedLogs().length == 0, "terminal token never attempted");
    }

    function testLegacyRequiredAsyncStillFundsAndRequests() public {
        entropy.configure(2, 9);
        entropy.setCapability(false);
        sale.execute{ value: 12 }(100000);
        require(entropy.revealFeeEscrow(7) == 9 && sale.credits() == 3 && entropy.requests() == 1);
    }

    function testCapabilityAwareLegacyRequiredAsyncStillRequests() public {
        entropy.configure(2, 9);
        sale.execute{ value: 12 }(100000);
        require(entropy.requests() == 1);
    }

    function testUndeclaredWithoutExplicitCapabilityCannotBecomeExemption() public {
        entropy.setCapability(false);
        vm.expectRevert();
        sale.execute(100000);
        require(sale.executions() == 0 && sale.credits() == 0);
    }

    function testTerminalCannotCarrySeedRequestFinalizedOrForeignEpoch() public {
        for (uint8 f = 1; f <= 9; ++f) {
            entropy.setFault(f);
            vm.expectRevert();
            sale.execute{ value: 19 }(100000);
            require(
                sale.executions() == 0 && sale.credits() == 0 && entropy.revealFeeEscrow(7) == 0
            );
        }
        entropy.setFault(0);
        sale.execute{ value: 19 }(100000);
        require(sale.executions() == 1 && sale.credits() == 19);
    }

    function testOriginalCoordinatorCollectionAndCompletedIdentityAreMandatory() public {
        core.setOriginal(address(123));
        vm.expectRevert();
        sale.execute(100000);
        core.setOriginal(address(entropy));
        core.setCollection(8);
        vm.expectRevert();
        sale.execute(100000);
        core.setCollection(7);
        core.setLifecycle(1);
        vm.expectRevert();
        sale.execute(100000);
        core.setLifecycle(2);
        sale.execute(100000);
        require(sale.executions() == 1);
    }

    function testAlreadyBurnedTokenKeepsOriginalTerminalIdentityAndDoesNotRequest() public {
        core.setLifecycle(3);
        sale.execute(100000);
        require(sale.executions() == 1 && entropy.requests() == 0);
    }

    function testExplicitPolicyRequiresConsentFullHashAndFrozenMintState() public {
        P.PolicyRecord memory p = entropy.collectionEntropyPolicy(7);
        P.PolicyRecord memory changed = abi.decode(abi.encode(p), (P.PolicyRecord));
        changed.artistConsentRecord = 0;
        entropy.setPolicy(changed);
        vm.expectRevert();
        sale.execute(100000);
        changed = abi.decode(abi.encode(p), (P.PolicyRecord));
        changed.policyHash = bytes32(uint256(43));
        entropy.setPolicy(changed);
        vm.expectRevert();
        sale.execute(100000);
        changed = abi.decode(abi.encode(p), (P.PolicyRecord));
        changed.frozen = false;
        changed.contentStateHash = keccak256(
            abi.encode(keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), p.policyHash, false)
        );
        entropy.setPolicy(changed);
        vm.expectRevert();
        sale.execute(100000);
        entropy.setPolicy(p);
        sale.execute(100000);
        require(sale.executions() == 1);
    }

    function testMalformedAdvertisedCapabilityCannotFallBackToLegacy() public {
        entropy.configure(2, 0);
        entropy.setFault(10);
        vm.expectRevert();
        sale.execute(100000);
    }

    function testCapturedDisabledQuoteCannotSkipNewRequiredPolicy() public {
        R.RevealQuote memory q = sale.quote();
        entropy.configure(2, 0);
        vm.expectRevert();
        sale.finishCaptured(q, 100000);
    }

    function testNotRequiredStillHonorsInsufficientAllowanceAtomicRetry() public {
        entropy.configure(1, 9);
        vm.expectRevert(
            abi.encodeWithSelector(R.SaleRevealFeeBelowRequired.selector, uint256(8), uint256(9))
        );
        sale.execute{ value: 8 }(100000);
        require(sale.executions() == 0 && entropy.revealFeeEscrow(7) == 0);
        sale.execute{ value: 9 }(100000);
        require(
            sale.executions() == 1 && entropy.revealFeeEscrow(7) == 9 && entropy.requests() == 0
        );
    }

    function testInstantRequiredMintKeepsRegisteredStateAndCreditsAllAllowance() public {
        entropy.configure(3, 0);
        require(!Reads.requireTerminalToken(address(core), address(entropy), 7, 42));
        R.RevealQuote memory q = sale.quote();
        require(!q.policy.declared && q.policy.revealFeePerTokenWei == 0);
        vm.recordLogs();
        sale.execute{ value: 23 }(type(uint256).max);
        require(sale.credits() == 23 && entropy.requests() == 0 && entropy.revealFeeEscrow(7) == 0);
        require(entropy.tokenEntropyStatus(42) == 3, "registered, never fabricated finality");
        require(vm.getRecordedLogs().length == 0, "no same-block instant attempt");
    }

    function testInstantNotRequiredKeepsTerminalStatusWithoutRequest() public {
        entropy.configure(4, 0);
        require(Reads.requireTerminalToken(address(core), address(entropy), 7, 42));
        sale.execute{ value: 17 }(type(uint256).max);
        require(
            sale.credits() == 17 && entropy.requests() == 0 && entropy.tokenEntropyStatus(42) == 2
        );
    }

    function testInstantRequestSeedAndEpochFaultsRollbackBeforeCredit() public {
        entropy.configure(3, 0);
        for (uint8 f = 1; f <= 8; ++f) {
            entropy.setFault(f);
            vm.expectRevert();
            sale.execute{ value: 11 }(type(uint256).max);
            require(sale.credits() == 0 && sale.executions() == 0);
        }
        entropy.setFault(0);
        sale.execute{ value: 11 }(type(uint256).max);
        require(sale.credits() == 11 && sale.executions() == 1);
    }

    function testInstantCannotInventRevealFeeOrClaimHighAssurance() public {
        entropy.configure(3, 0);
        entropy.setReveal(F.CollectionRevealPolicy(true, 0, 0, 0, 1));
        vm.expectRevert();
        sale.quote();
        entropy.configure(3, 0);
        P.PolicyRecord memory p = entropy.collectionEntropyPolicy(7);
        p.securityClass = P.SecurityClass.HIGH_ASSURANCE;
        entropy.setPolicy(p);
        vm.expectRevert();
        sale.quote();
        entropy.configure(3, 0);
        require(!sale.quote().policy.declared);
    }

    function testCapturedInstantZeroQuoteCannotSkipAsyncFeeOrRequest() public {
        entropy.configure(3, 0);
        R.RevealQuote memory q = sale.quote();
        entropy.configure(1, 7);
        vm.expectRevert();
        sale.finishCaptured(q, 100000);
        require(entropy.requests() == 0 && entropy.revealFeeEscrow(7) == 0);
    }

    function testFuzzTerminalAsyncFeeAndRefundConservation(uint96 fee, uint96 excess) public {
        uint256 total = uint256(fee) + uint256(excess);
        vm.deal(address(this), total);
        entropy.configure(1, fee);
        sale.execute{ value: total }(100000);
        require(
            entropy.revealFeeEscrow(7) == fee && sale.credits() == excess
                && address(sale).balance == excess && entropy.requests() == 0
        );
    }
}
