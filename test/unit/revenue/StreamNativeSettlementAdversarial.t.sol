// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeSettlementTestBase.sol";

interface NativeReadFaultVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCall(address target, uint256 value, bytes calldata input, bytes calldata output)
        external;
    function clearMockedCalls() external;
}

/// @dev Isolates the linked helper's gas admission; it is not an official sale producer.
contract NativeBudgetHarness {
    function fund(
        IStreamRevenueEscrow escrow,
        StreamSaleTemplate.Selection memory selected,
        uint256 cap
    ) external payable {
        require(
            !StreamNativeSettlementSupport.fundNative(
                escrow, address(escrow).codehash, selected, msg.value, cap
            ),
            "expected direct wallet"
        );
    }
}

/// @dev Enough of the former recorder's immutable ABI to demonstrate constructor rejection.
contract NativeOldRecorderBinding {
    IStreamRevenueResolver public revenueResolver;
    address public moduleRegistry;
    address public core;

    constructor(IStreamRevenueResolver r, address m) {
        revenueResolver = r;
        moduleRegistry = m;
        core = r.core();
    }

    function isStreamPrimarySaleSettlement() external pure returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamPrimarySaleSettlement).interfaceId;
    }
}

contract StreamNativeSettlementAdversarialTest is NativeSettlementTestBase {
    NativeReadFaultVm private constant faults = NativeReadFaultVm(address(vm));

    function testConstructorRejectsFormerERC20OnlyRecorderCapability() public {
        NativeOldRecorderBinding old = new NativeOldRecorderBinding(resolver, address(registry));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeFixedPriceSaleAdapter.InvalidNativeSale.selector)
        );
        new StreamNativeFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)),
            IStreamPrimarySaleSettlement(address(old)),
            vm.addr(PLATFORM_KEY),
            artists
        );
    }

    function testNativeRoleCannotRegisterAsERC20OrEnterItsRecorderBoundary() public {
        StreamNativeFixedPriceSaleAdapter wrong = new StreamNativeFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), recorder, vm.addr(PLATFORM_KEY), artists
        );
        _register(
            address(wrong),
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId
        );
        IStreamNativeFixedPriceSaleAdapter.SaleConfig memory config =
        nativeSale.saleRecord(nativeId).config;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSettlementAdmission.SettlementModuleNotAdmitted.selector, address(wrong)
            )
        );
        wrong.registerSale(config);
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory n
        ) = _nativeExecution(payer, payer, 1);
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c =
            StreamNativeSettlementHash.accountingContext(n);
        c.asset = address(token);
        c.lifecycleBinding = sale.saleLifecycleBinding(saleId);
        c.executionBinding.executionId = StreamPrimarySettlementHash.executionId(c);
        vm.prank(address(nativeSale));
        (bool ok, bytes memory reason) = address(recorder)
            .call(
                abi.encodeCall(
                    IStreamPrimarySaleSettlement.settleERC20PrimarySaleFromAdapter,
                    (address(payment), c)
                )
            );
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamSettlementAdmission.SettlementModuleNotAdmitted.selector,
                            address(nativeSale)
                        )
                    ),
            "native role never admits ERC20 entry"
        );
        _buy(e);
        require(wallet.balance == 1000, "same candidate legitimate native control");
    }

    function testExactLifecycleGetterAndPriorRevisionRequired() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        bytes memory callData =
            abi.encodeCall(IStreamNativeSaleBinding.nativeSaleLifecycleBinding, (nativeId));
        for (uint256 i; i < 6; ++i) {
            bytes memory response = i == 0
                ? abi.encode(uint256(1000))
                : i == 1
                    ? abi.encode(uint256(1000), uint256(1), uint256(0))
                    : abi.encode(
                        i == 2 ? uint256(1) << 64 : i == 3 ? 0 : 1000, i == 4 ? 0 : i == 5 ? 2 : 1
                    );
            faults.mockCall(address(nativeSale), callData, response);
            vm.prank(payer);
            (bool ok,) =
                address(nativeSale).call{ value: 1000 }(abi.encodeCall(nativeSale.purchase, (e)));
            require(!ok, "short/long/noncanonical/zero/future lifecycle rejected");
            _unchanged(c, 10 ether);
            faults.clearMockedCalls();
        }
        _buy(e);
        require(wallet.balance == 1000, "unmodified lifecycle succeeds");
    }

    function testDeprecationAtCreationSecondFailsButStrictlyEarlierSurvives() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        _status(address(nativeSale), ModuleRegistryStatus.DEPRECATED);
        vm.prank(payer);
        (bool ok,) =
            address(nativeSale).call{ value: 1000 }(abi.encodeCall(nativeSale.purchase, (e)));
        require(!ok, "same-second creation not grandfathered");
        _unchanged(c, 10 ether);
        _status(address(nativeSale), ModuleRegistryStatus.ACTIVE);
        vm.warp(1001);
        _status(address(nativeSale), ModuleRegistryStatus.DEPRECATED);
        _buy(e);
        require(wallet.balance == 1000, "strictly prior time and revision admitted");
    }

    function testAllNativeResultWordsAndReturndataLengthsAreBounded() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            StreamPrimarySettlementTypes.PrimarySettlementResult(
                StreamNativeSettlementHash.candidateCommitment(address(recorder), c),
                recorder.settlementKey(address(nativeSale), c.executionBinding.executionId),
                profile,
                wallet,
                address(0),
                1000,
                payer,
                c.executionBinding.executionId,
                false,
                c.operationIdentityCommitment,
                c.currentPolicyHash,
                c.boundPolicyHash
            );
        bytes memory input = abi.encodeCall(
            IStreamNativePrimarySaleSettlement.settleNativePrimarySaleFromAdapter, (c)
        );
        for (uint256 i; i < 15; ++i) {
            bytes memory response = abi.encode(r);
            if (i < 12) {
                assembly ("memory-safe") {
                    let p := add(add(response, 32), mul(i, 32))
                    mstore(p, xor(mload(p), 1))
                }
            } else if (i == 12) {
                response = new bytes(383);
            } else if (i == 13) {
                response = new bytes(416);
            } else {
                response = new bytes(65536);
            }
            faults.mockCall(address(recorder), input, response);
            vm.prank(payer);
            (bool ok,) =
                address(nativeSale).call{ value: 1000 }(abi.encodeCall(nativeSale.purchase, (e)));
            require(
                !ok && wallet.balance == 0 && address(escrow).balance == 0,
                "every malformed native result atomic"
            );
            _unchanged(c, 10 ether);
            faults.clearMockedCalls();
        }
        _buy(e);
        require(wallet.balance == 1000, "actual recorder result positive control");
    }

    function testEscrowCreditAndTemplateRegistrationRollbackOnRejectedRecipient() public {
        _template(artist);
        NativeSettlementReceiver recipient = new NativeSettlementReceiver();
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, address(recipient), 1);
        recipient.configure(true, address(0), "", c.rights.wallet);
        uint256 count = factory.profileCount();
        vm.prank(payer);
        (bool ok,) =
            address(nativeSale).call{ value: 1000 }(abi.encodeCall(nativeSale.purchase, (e)));
        require(
            !ok && factory.profileCount() == count && !factory.profileExists(c.rights.profileId)
                && escrow.totalOwed(address(0)) == 0 && address(escrow).balance == 0,
            "rejected mint rolls back registration and owed"
        );
        _unchanged(c, 10 ether);
        recipient.configure(false, address(0), "", c.rights.wallet);
        _buy(e);
        require(
            factory.profileExists(c.rights.profileId)
                && escrow.escrowOwed(CLASS, c.rights.profileId, c.rights.wallet, address(0))
                    == 1000,
            "identical authorization retries exact credit"
        );
    }

    function testFuzzNativeSignedRecipientAndPolicyCannotDrift(uint256 salt) public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        e.authorization.expectedPrimaryPolicyHash =
            bytes32(uint256(e.authorization.expectedPrimaryPolicyHash) ^ (salt | 1));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector,
                vm.addr(PLATFORM_KEY)
            )
        );
        nativeSale.previewExecution(e);
        _nativeSign(e);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeFixedPriceSaleAdapter.InvalidNativeSale.selector)
        );
        nativeSale.previewExecution(e);
        _unchanged(c, 10 ether);
    }

    function testNativeHelperRejectsUnderforwardingAndAdmitsFullConfiguredBudget() public {
        NativeBudgetHarness harness = new NativeBudgetHarness();
        StreamSaleTemplate.Selection memory selected =
            StreamNativeSettlementSupport.rights(resolver, 1);
        bytes memory data = abi.encodeCall(harness.fund, (escrow, selected, uint256(500_000)));
        vm.deal(address(this), 2000);
        (bool ok, bytes memory reason) = address(harness).call{ value: 1000, gas: 500_000 }(data);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamNativeSettlementSupport.InsufficientSettlementCallGas.selector,
                            uint256(500_000)
                        )
                    ),
            "exact full-cap admission before wallet call"
        );
        require(
            wallet.balance == 0 && address(harness).balance == 0 && address(this).balance == 2000,
            "underfunded frame atomic"
        );
        (ok,) = address(harness).call{ value: 1000, gas: 800_000 }(data);
        require(
            ok && wallet.balance == 1000 && address(harness).balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "adequate helper budget real money; not official sale accounting"
        );
    }

    function testSuccessfulNonemptyWalletReturnNeverFallsBack() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        for (uint256 i; i < 2; ++i) {
            faults.mockCall(wallet, 1000, "", i == 0 ? abi.encode(uint256(1)) : new bytes(65536));
            vm.prank(payer);
            (bool ok,) =
                address(nativeSale).call{ value: 1000 }(abi.encodeCall(nativeSale.purchase, (e)));
            require(
                !ok && wallet.balance == 0 && escrow.totalOwed(address(0)) == 0
                    && address(escrow).balance == 0,
                "successful injected nonempty native return cannot escrow"
            );
            _unchanged(c, 10 ether);
            faults.clearMockedCalls();
        }
        _buy(e);
        require(wallet.balance == 1000, "ordinary real wallet control");
    }

    function testFuzzNativePriceIsExactDebitDepositAndOfficialCredit(uint96 value) public {
        uint256 price = 1 + uint256(value) % 1 ether;
        IStreamNativeFixedPriceSaleAdapter.SaleConfig memory config =
        nativeSale.saleRecord(nativeId).config;
        config.price = price;
        nativeId = nativeSale.registerSale(config);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        vm.prank(payer);
        (StreamPrimarySettlementTypes.PrimarySettlementResult memory r,) =
            nativeSale.purchase{ value: price }(e);
        require(
            r.amount == price && wallet.balance == price && payer.balance == 10 ether - price
                && recorder.totalOfficialSettled(address(0)) == price
                && manager.ownerOf(1) == payer,
            "arbitrary bounded price exact all the way through"
        );
    }
}
