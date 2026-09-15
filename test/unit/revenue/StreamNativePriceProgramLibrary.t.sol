// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativePricePrograms.t.sol";

contract StreamNativePriceProgramLibraryTest is NativePriceProgramTestBase {
    OfficialSafe private safe;
    uint256[] private keys;

    function testCanonicalFactorySignatureParameterIdForBothFixedAndPrograms() public {
        bytes32 parameter = keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT");
        require(factory.gasParameter(parameter) > 0, "actual registered cap");
        bytes32 wrong = keccak256("ERC_1271_GAS_LIMIT");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterUnknown.selector, wrong)
        );
        factory.gasParameter(wrong);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory fixedExecution,) =
            _nativeExecution(payer, payer, 1);
        bytes32 id = _program(12, 0, 0, 3);
        IStreamNativePricePrograms.PriceProgramExecution memory free = _execution(id, 2, 0, 0);
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                address(factory),
                0,
                abi.encodeCall(IStreamGasParameterHost.gasParameter, (parameter)),
                hex"cafe"
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSettlementSupport.NativeSettlementBindingInvalid.selector,
                address(factory)
            )
        );
        nativeSale.previewExecution(fixedExecution);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSettlementSupport.NativeSettlementBindingInvalid.selector,
                address(factory)
            )
        );
        nativeSale.previewPriceProgram(free);
        SaleFundingFaultVm(address(vm)).clearMockedCalls();
        _buy(fixedExecution);
        _execute(free);
        require(
            manager.nonce() == 2 && recorder.totalOfficialSettled(address(0)) == 1000,
            "same-context legacy and free controls"
        );
    }

    function testDirectMutableLibraryCallsRejectForEOAAndActualSafe() public {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1008);
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        IStreamNativePricePrograms.PriceProgramResult memory r;
        bytes memory settlement =
            abi.encodeWithSelector(StreamNativePriceProgram.settle.selector, address(recorder), c);
        bytes memory completion = abi.encodeWithSelector(
            StreamNativePriceProgram.emitCompletion.selector, nativeId, c, r, uint64(1)
        );
        vm.recordLogs();
        _reject(settlement);
        _reject(completion);
        require(
            vm.getRecordedLogs().length == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && manager.nonce() == 0,
            "no spoofed completion or official effects"
        );
        _buy(e);
        require(
            recorder.totalOfficialSettled(address(0)) == 1000,
            "actual consumer delegatecall control"
        );
    }

    function _reject(bytes memory data) private {
        (bool ok, bytes memory reason) = address(StreamNativePriceProgram).call(data);
        require(!ok && reason.length == 0, "Solidity library CALL guard");
        uint256 nonce = safe.nonce();
        (ok, reason) = address(this).call(abi.encodeCall(this.attemptSafe, (data)));
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && safe.nonce() == nonce,
            "actual Safe library rejection"
        );
    }

    function attemptSafe(bytes calldata data) external {
        require(msg.sender == address(this), "test wrapper");
        require(
            executeSafe(safe, keys, address(StreamNativePriceProgram), 0, data, 0), "Safe result"
        );
    }
}
