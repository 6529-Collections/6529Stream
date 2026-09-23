// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeSettlementTestBase.sol";
import {
    IStreamBurnMintNativeExecutor,
    IStreamBurnMintNativeSale
} from "../../../smart-contracts/interfaces/stream/mint/IStreamBurnMintNativeSale.sol";

/// @dev Explicit Manager seam for hostile gate-callback tests, not a burn or Ledger simulation claim.
contract NativeBurnManagerBoundary is UniversalManagerMock {
    address public gate;
    constructor(address c, address r) UniversalManagerMock(c, r) { }

    function setGate(address target) external {
        gate = target;
    }

    function phaseGate(uint256, bytes32)
        external
        view
        returns (IStreamMintManager.MintGateConfig memory g)
    {
        g.gate = gate;
        g.gateCodehash = gate.codehash;
        g.gateConfigHash = keccak256("callback test config");
    }
}

/// @dev Deliberately adversarial typed consumer; actual burning is covered by StreamBurnMintGateTest/current joins.
contract NativeBurnCallbackBoundary is IStreamBurnMintNativeExecutor {
    uint8 public mode;
    bool public secondCallbackSucceeded;
    bool public reentrySucceeded;

    function setMode(uint8 value) external {
        mode = value;
    }

    function executeNativeBurn(
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData calldata original,
        address buyer,
        uint256 value,
        uint256[] calldata originalSources
    )
        external
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result, uint256 token)
    {
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e = original;
        uint256[] memory sources = originalSources;
        if (mode == 1) buyer = address(0x1234);
        if (mode == 2) ++value;
        if (mode == 3) sources[0] += 1;
        if (mode == 4) e.tokenData = bytes("different payload");
        if (mode == 5) return (result, 0); // A non-callback gate cannot leave an accepted public purchase.
        if (mode == 7) {
            (reentrySucceeded,) = msg.sender
                .call(abi.encodeCall(IStreamBurnMintNativeSale.purchaseWithBurn, (e, sources)));
        }
        (result, token) =
            IStreamBurnMintNativeSale(msg.sender).executeBurnPurchase(e, buyer, value, sources);
        if (mode == 6) ++token; // Returning a substituted result rolls back even a completed inner purchase.
        if (mode == 8) {
            (secondCallbackSucceeded,) = msg.sender
                .call(
                    abi.encodeCall(
                        IStreamBurnMintNativeSale.executeBurnPurchase, (e, buyer, value, sources)
                    )
                );
        }
    }
}

/// @notice Real native adapter/recorder/Resolver/factory/escrow/Safe; typed Manager/Core/Artist and hostile gate seams.
contract StreamNativeBurnCallbackTest is NativeSettlementTestBase {
    NativeBurnCallbackBoundary private burn;

    function setUp() public override {
        super.setUp();
        manager = UniversalManagerMock(
            address(new NativeBurnManagerBoundary(address(core), address(registry)))
        );
        _nativeSale();
        burn = new NativeBurnCallbackBoundary();
        NativeBurnManagerBoundary(address(manager)).setGate(address(burn));
    }

    function _sources() private pure returns (uint256[] memory ids) {
        ids = new uint256[](1);
        ids[0] = 6529;
    }

    function _execute(IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e, uint256 value)
        private
    {
        vm.prank(e.authorization.payer);
        nativeSale.purchaseWithBurn{ value: value }(e, _sources());
    }

    function testOriginalDirectPurchaseStillSettlesExactPrice() public {
        uint256 saleNonce = nativeSale.saleRecord(nativeId).saleNonce;
        bytes32 expectedId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(nativeSale),
                uint8(0),
                uint256(1),
                PHASE,
                saleNonce
            )
        );
        require(
            nativeSale.saleIdFor(1, PHASE, saleNonce) == expectedId && nativeId == expectedId,
            "fixed sale reader preserves canonical ID domain"
        );
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        _buy(e);
        require(
            manager.ownerOf(1) == payer && recorder.totalOfficialSettled(address(0)) == 1000,
            "original purchase unchanged"
        );
    }

    function testNativeBurnCallbackRetainsPayerAndExcessRefundOwner() public {
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        uint256 balance = payer.balance;
        _execute(e, 1250);
        require(
            manager.ownerOf(1) == payer && recorder.totalOfficialSettled(address(0)) == 1000,
            "native official settlement and mint"
        );
        require(
            nativeSale.refundableBalance(nativeId, payer) == 250
                && nativeSale.refundableBalance(nativeId, address(burn)) == 0,
            "original payer credit"
        );
        vm.prank(payer);
        nativeSale.claimRefund(nativeId, payer);
        require(payer.balance == balance - 1000, "exact net payer charge");
    }

    function testWrongBuyerValueSourcesPayloadMissingAndSubstitutedCallbacksRollback() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        uint256 balance = payer.balance;
        for (uint8 mode = 1; mode <= 6; ++mode) {
            burn.setMode(mode);
            vm.expectRevert();
            _execute(e, 1000);
            _unchanged(c, balance);
        }
        burn.setMode(0);
        _execute(e, 1000);
        require(manager.ownerOf(1) == payer, "unchanged execution retries");
    }

    function testCallbackCannotBeReplayedOutsidePublicEntry() public {
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        uint256[] memory ids = _sources();
        vm.expectRevert();
        vm.prank(address(burn));
        nativeSale.executeBurnPurchase(e, payer, 1000, ids);
        burn.setMode(8);
        _execute(e, 1000);
        require(!burn.secondCallbackSucceeded(), "callback consumed before effects");
        vm.expectRevert();
        vm.prank(address(burn));
        nativeSale.executeBurnPurchase(e, payer, 1000, ids);
    }

    function testGateCannotReenterPublicPurchase() public {
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        burn.setMode(7);
        _execute(e, 1000);
        require(!burn.reentrySucceeded(), "public guard spans callback");
    }

    function testNativeSettlementFailureRollsBackCallbackContextAndSameRequestRetries() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        uint256 balance = payer.balance;
        // The direct wallet route does not consult escrow producer admission. Inject the
        // failure at the actual recorder payment call, then remove it for the same retry.
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                address(recorder),
                1000,
                abi.encodeWithSelector(
                    IStreamNativePrimarySaleSettlement.settleNativePrimarySaleFromAdapter.selector
                ),
                abi.encodeWithSignature("Error(string)", "injected native settlement failure")
            );
        vm.expectRevert();
        _execute(e, 1000);
        _unchanged(c, balance);
        SaleFundingFaultVm(address(vm)).clearMockedCalls();
        _execute(e, 1000);
        require(manager.ownerOf(1) == payer, "retry restored original callback context");
    }

    function testActualSafeByteIdenticalNativeCallbackRetryAndReceiverReentry() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 201);
        vm.deal(address(safe), 1 ether);
        NativeSettlementReceiver receiver = new NativeSettlementReceiver();
        receiver.configure(true, address(0), "", address(0));
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(address(safe), address(receiver), 1);
        bytes memory data = abi.encodeCall(nativeSale.purchaseWithBurn, (e, _sources()));
        bytes32 digest = safe.getTransactionHash(
            address(nativeSale), 1250, data, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        bytes memory signedCall = abi.encodeCall(
            safe.execTransaction,
            (
                address(nativeSale),
                1250,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
        (bool ok,) = address(safe).call(signedCall);
        require(!ok && safe.nonce() == 0 && manager.nonce() == 0, "full Safe rollback");
        receiver.configure(
            false,
            address(nativeSale),
            abi.encodeCall(
                nativeSale.executeBurnPurchase, (e, address(safe), uint256(1250), _sources())
            ),
            address(0)
        );
        (ok,) = address(safe).call(signedCall);
        require(
            ok && !receiver.callbackSucceeded(),
            "identical signed Safe retry blocks receiver callback"
        );
        require(
            nativeSale.refundableBalance(nativeId, address(safe)) == 250
                && manager.ownerOf(1) == address(receiver),
            "Safe payer and distinct recipient"
        );
    }
}
