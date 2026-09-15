// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/UniversalSettlementTestBase.sol";

interface UniversalFaultVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
}

/// @dev Explicitly admitted malicious sale for payment-boundary negative tests. It is not
///      the supported commercial consumer and cannot prove an actual mint by itself.
contract UniversalCallbackAdversary is
    IStreamERC20SaleExecution,
    IStreamSaleLifecycleBinding,
    ERC165
{
    address public immutable core;
    address public immutable mintManager;
    address public immutable primarySaleSettlement;
    StreamPrimarySettlementTypes.SaleLifecycleBinding private _binding;
    uint256 public mode;

    constructor(address c, address manager, address recorder) {
        core = c;
        mintManager = manager;
        primarySaleSettlement = recorder;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamERC20SaleExecution).interfaceId
            || id == type(IStreamSaleLifecycleBinding).interfaceId || super.supportsInterface(id);
    }

    function configure(
        StreamPrimarySettlementTypes.SaleLifecycleBinding calldata binding,
        uint256 mode_
    ) external {
        _binding = binding;
        mode = mode_;
    }

    function saleLifecycleBinding(bytes32)
        external
        view
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory)
    {
        return _binding;
    }

    function executeERC20PreRevenueSingleStep(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata c,
        bytes calldata
    )
        external
        returns (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        if (mode == 1) {
            return (IStreamERC20SaleExecution.executeERC20PreRevenueSingleStep.selector, result);
        }
        result = IStreamPrimarySaleSettlement(primarySaleSettlement)
            .settleERC20PrimarySaleFromAdapter(msg.sender, c);
        if (mode == 2) {
            IStreamPrimarySaleSettlement(primarySaleSettlement)
                .settleERC20PrimarySaleFromAdapter(msg.sender, c);
        }
        if (mode >= 10 && mode < 22) {
            uint256 index = mode - 10;
            // Every field stays ABI-canonical, including addresses and the escrow bool.
            assembly ("memory-safe") {
                let ptr := add(result, mul(index, 32))
                mstore(ptr, xor(mload(ptr), 1))
            }
        }
        if (mode == 30) assembly ("memory-safe") { return(0, 0) }
        if (mode == 31) assembly ("memory-safe") { revert(mload(0x40), 65536) }
        if (mode == 32) {
            assembly ("memory-safe") {
                let start := mload(0x40)
                mstore(start, 0)
                return(start, 65536)
            }
        }
        return (IStreamERC20SaleExecution.executeERC20PreRevenueSingleStep.selector, result);
    }
}

contract StreamUniversalSettlementAdversarialTest is UniversalSettlementTestBase {
    UniversalFaultVm private constant faultVm = UniversalFaultVm(address(vm));

    function testMissingFundingDuplicateSettlementAndAllTwelveResultDriftsRevertWholeGraph()
        public
    {
        UniversalCallbackAdversary hostile = new UniversalCallbackAdversary(
            address(core), address(manager), address(recorder)
        );
        _register(
            address(hostile),
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId
        );
        (, StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c) =
            _execution(payer, payer, payer, 1);
        c.saleAdapter = address(hostile);
        c.saleExecutionHash = keccak256(bytes("hostile callback"));
        c.executionBinding.executionId = StreamPrimarySettlementHash.executionId(c);
        for (uint256 i; i < 17; ++i) {
            uint256 mode = i < 2 ? i + 1 : i < 14 ? i + 8 : i + 16;
            hostile.configure(c.lifecycleBinding, mode);
            vm.prank(payer);
            (bool ok,) = address(payment)
                .call(
                    abi.encodeCall(
                        IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleByPayer,
                        (c, bytes("hostile callback"))
                    )
                );
            require(!ok, "hostile result must fail");
            require(
                token.balanceOf(payer) == 10_000
                    && token.allowance(payer, address(payment)) == 10_000
                    && token.balanceOf(wallet) == 0
                    && recorder.totalOfficialSettled(address(token)) == 0
                    && escrow.totalOwed(address(token)) == 0
                    && payment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
                "all hostile callback movement/latches rollback"
            );
        }
        hostile.configure(c.lifecycleBinding, 0);
        vm.prank(payer);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory control =
            payment.settleERC20PrimarySaleByPayer(c, bytes("hostile callback"));
        require(
            token.balanceOf(payer) == 9000 && token.balanceOf(wallet) == 1000
                && recorder.totalOfficialSettled(address(token)) == 1000
                && recorder.settlementConsumed(control.settlementKey) && manager.nonce() == 0,
            "same admitted context funds normally; hostile module is not a real mint proof"
        );
    }

    function testUnauthorizedFundingAndLegacyRecorderSelectorCannotPull() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.UnauthorizedFundingReturn.selector
            )
        );
        payment.fundERC20PrimarySale(bytes32(uint256(1)), bytes32(uint256(2)), address(token), 1000);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.UnauthorizedFundingReturn.selector
            )
        );
        vm.prank(address(recorder));
        payment.fundERC20PrimarySale(bytes32(uint256(1)), bytes32(uint256(2)), address(token), 1000);
        // Old selector no longer dispatches, even when the caller grants the recorder an allowance.
        vm.prank(payer);
        token.approve(address(recorder), 1000);
        vm.prank(payer);
        (bool ok,) =
            address(recorder).call(abi.encodePacked(bytes4(0x9e6dc442), new bytes(32 * 32)));
        require(
            !ok && token.balanceOf(payer) == 10_000
                && token.allowance(payer, address(recorder)) == 1000,
            "no legacy payer route"
        );
    }

    function testConsumedExecutionCannotReopenRecorderWithAnotherActiveAsset() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        vm.prank(payer);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        bytes32 retained = keccak256(abi.encode(recorder.settlementResult(r.settlementKey)));
        UniversalPermitToken other = new UniversalPermitToken();
        other.mint(payer, 2000);
        vm.prank(payer);
        other.approve(address(payment), 2000);
        _setAssetPolicy(policy, address(other), 1, keccak256("other active asset"), 0);
        c.asset = address(other);
        require(
            StreamPrimarySettlementHash.executionId(c) == r.executionId
                && recorder.settlementKey(c.saleAdapter, c.executionBinding.executionId)
                    == r.settlementKey,
            "asset cannot change the authenticated execution key"
        );
        // Exact recorder boundary: an admitted caller cannot reuse its completed execution.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrimarySaleSettlement.SettlementAlreadyConsumed.selector, r.settlementKey
            )
        );
        vm.prank(address(sale));
        recorder.settleERC20PrimarySaleFromAdapter(address(payment), c);
        require(
            keccak256(abi.encode(recorder.settlementResult(r.settlementKey))) == retained
                && recorder.totalOfficialSettled(address(token)) == 1000
                && recorder.totalOfficialSettled(address(other)) == 0
                && other.balanceOf(payer) == 2000 && other.balanceOf(wallet) == 0
                && other.allowance(payer, address(payment)) == 2000
                && escrow.totalOwed(address(other)) == 0 && token.balanceOf(wallet) == 1000
                && manager.nonce() == 1,
            "cross-asset replay preserves every recorded right and balance"
        );
    }

    function testWalletGasBurnAndRevertBombRemainBoundedAndCreditExactlyOnce() public {
        for (uint256 i; i < 2; ++i) {
            token.configure(wallet, uint8(7 + i));
            (
                IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
                StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
            ) = _execution(payer, payer, payer, i + 1);
            vm.prank(payer);
            StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
                payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
            require(
                r.escrowed && token.balanceOf(wallet) == 0
                    && escrow.escrowOwed(CLASS, profile, wallet, address(token)) == (i + 1) * 1000
                    && token.balanceOf(address(escrow)) == (i + 1) * 1000,
                "failed bounded frame yields one exact credit"
            );
        }
        require(
            token.balanceOf(payer) == 8000 && recorder.totalOfficialSettled(address(token)) == 2000
                && token.allowance(address(recorder), address(escrow)) == 0,
            "no duplicate funding or residual approval"
        );
    }

    function testPayerAndRecorderHopFaultsNeverFallbackOrLeavePartialMoney() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        for (uint256 hop; hop < 2; ++hop) {
            for (uint8 fault = 1; fault <= 8; ++fault) {
                token.configure(hop == 0 ? address(payment) : address(recorder), fault);
                _rejected(e, c);
                require(
                    token.balanceOf(payer) == 10_000
                        && token.allowance(payer, address(payment)) == 10_000
                        && token.balanceOf(address(payment)) == 0
                        && token.balanceOf(address(recorder)) == 0 && token.balanceOf(wallet) == 0
                        && token.balanceOf(address(escrow)) == 0
                        && recorder.totalOfficialSettled(address(token)) == 0
                        && escrow.totalOwed(address(token)) == 0,
                    "first and second hop faults are atomic, never escrow fallback"
                );
            }
        }
        token.configure(address(0), 0);
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        require(
            token.balanceOf(wallet) == 1000, "same context succeeds with exact transfer semantics"
        );
    }

    function testRevertingBalanceReadAndInactiveDeprecatedAssetsRejectWithoutSpending() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        token.setBalanceFailure(true);
        _rejected(e, c);
        token.setBalanceFailure(false);
        require(
            token.balanceOf(payer) == 10_000 && token.allowance(payer, address(payment)) == 10_000,
            "balance failure before spending"
        );
        _setAssetPolicy(policy, address(token), 2, keccak256("inactive"), 0);
        _rejected(e, c);
        _setAssetPolicy(
            policy, address(token), 3, keccak256("deprecated"), uint64(block.timestamp + 181 days)
        );
        _rejected(e, c);
        require(
            token.balanceOf(payer) == 10_000 && token.balanceOf(wallet) == 0
                && registry.moduleRecord(address(payment)).status == ModuleRegistryStatus.ACTIVE
                && registry.moduleRecord(address(sale)).status == ModuleRegistryStatus.ACTIVE,
            "asset admission differs from module grandfathering"
        );
    }

    function testCanonicalRegistryHeaderAndCreationBindingMalformedWordsReject() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        bytes memory encoded = abi.encode(registry.moduleRecord(address(sale)));
        uint256[9] memory indexes = [uint256(0), 1, 4, 5, 9, 10, 11, 12, 13];
        uint256[9] memory values = [
            uint256(64),
            256,
            uint256(1),
            uint256(1) << 32,
            416,
            uint256(1) << 64,
            uint256(1) << 64,
            uint256(1) << 64,
            type(uint256).max
        ];
        for (uint256 i; i < indexes.length; ++i) {
            bytes memory corrupt = abi.encode(registry.moduleRecord(address(sale)));
            uint256 offset = indexes[i];
            uint256 word = values[i];
            assembly ("memory-safe") { mstore(add(add(corrupt, 32), mul(offset, 32)), word) }
            faultVm.mockCall(
                address(registry),
                abi.encodeCall(IStreamModuleRegistry.moduleRecord, (address(sale))),
                corrupt
            );
            _rejected(e, c);
            faultVm.clearMockedCalls();
        }
        require(encoded.length == 480, "exact canonical URI return shape");
        bytes memory lifecycle = abi.encode(c.lifecycleBinding);
        for (uint256 i; i < 4; ++i) {
            bytes memory corrupt = abi.encode(c.lifecycleBinding);
            uint256 word = uint256(1) << (i == 0 ? 160 : 64);
            assembly ("memory-safe") { mstore(add(add(corrupt, 32), mul(i, 32)), word) }
            faultVm.mockCall(
                address(sale),
                abi.encodeCall(IStreamSaleLifecycleBinding.saleLifecycleBinding, (saleId)),
                corrupt
            );
            _rejected(e, c);
            faultVm.clearMockedCalls();
        }
        require(
            lifecycle.length == 128 && token.balanceOf(payer) == 10_000,
            "malformed reads cannot fund"
        );
    }

    function testCoreRegistryPointerReplacementAndBothModuleRuntimeDriftReject() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        core.configure(address(artists), address(0xBAD));
        _rejected(e, c);
        core.configure(address(artists), address(registry));
        bytes memory old = address(sale).code;
        vm.etch(address(sale), abi.encodePacked(hex"ef0100", address(0xBEEF)));
        _rejected(e, c);
        vm.etch(address(sale), old);
        StreamModuleRecord memory p = registry.moduleRecord(address(payment));
        p.runtimeCodeHash = keccak256("different admitted runtime");
        faultVm.mockCall(
            address(registry),
            abi.encodeCall(IStreamModuleRegistry.moduleRecord, (address(payment))),
            abi.encode(p)
        );
        _rejected(e, c);
        faultVm.clearMockedCalls();
        require(token.balanceOf(payer) == 10_000, "all admission changes pre-funding");
    }

    function testCallbackAssetTighteningRevertsPaymentAndGovernanceStateTogether() public {
        token.setCallback(address(this), abi.encodeCall(this.tightenAssetFromToken, ()));
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        uint64 revision = policy.assetPolicyRevision(address(token));
        _rejected(e, c);
        require(
            policy.assetStatus(address(token)) == 1
                && policy.assetPolicyRevision(address(token)) == revision
                && token.balanceOf(payer) == 10_000
                && token.allowance(payer, address(payment)) == 10_000
                && recorder.totalOfficialSettled(address(token)) == 0,
            "post-callback ACTIVE check rolls entire transaction back"
        );
    }

    function tightenAssetFromToken() external {
        require(msg.sender == address(token), "test callback only");
        // Exact target-side authority context fault injection, not a timelock execution proof.
        _setAssetPolicy(policy, address(token), 2, keccak256("callback tightening"), 0);
    }

    function _rejected(
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private {
        vm.prank(payer);
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleByPayer,
                    (c, abi.encode(e))
                )
            );
        require(
            !ok && payment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
            "malformed admission rejects and unlocks"
        );
    }
}
