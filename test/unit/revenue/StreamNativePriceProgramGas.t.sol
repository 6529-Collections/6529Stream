// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativePricePrograms.t.sol";

/// @dev Gas-admission witness, not a Safe or general-purpose authorization implementation.
contract PriceProgramSignatureBudgetWitness {
    mapping(bytes32 => bool) public allowed;

    function allow(bytes32 digest) external {
        allowed[digest] = true;
    }

    function isValidSignature(bytes32 digest, bytes calldata) external view returns (bytes4) {
        return allowed[digest] && gasleft() >= 600_000 ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

contract StreamNativePriceProgramGasTest is NativePriceProgramTestBase {
    function testActualFactoryGovernedRaiseChangesBothFixedAndFreeSignatureBudgets() public {
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory fixedExecution,) =
            _nativeExecution(payer, payer, 1);
        IStreamNativeFixedPriceSaleAdapter.SaleConfig memory cfg =
        nativeSale.saleRecord(nativeId).config;
        PriceProgramSignatureBudgetWitness witness = new PriceProgramSignatureBudgetWitness();
        nativeSale = new StreamNativeFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), recorder, address(witness), artists
        );
        _register(
            address(nativeSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId
        );
        nativeId = nativeSale.registerSale(cfg);
        fixedExecution.authorization.saleId = nativeId;
        fixedExecution.authorization.saleConfigHash = nativeSale.saleRecord(nativeId).configHash;
        _nativeSign(fixedExecution);
        bytes32 fixedDigest = nativeSale.authorizationDigest(fixedExecution.authorization);
        witness.allow(fixedDigest);
        bytes32 id = _program(12, 0, 0, 2);
        IStreamNativePricePrograms.PriceProgramExecution memory free = _execution(id, 2, 0, 0);
        witness.allow(nativeSale.priceProgramAuthorizationDigest(free.authorization));
        bytes32 parameter = keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT");
        require(factory.gasParameter(parameter) == 400_000, "starting actual configured cap");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector,
                address(witness)
            )
        );
        nativeSale.previewExecution(fixedExecution);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeSaleSignatureInvalid.selector,
                address(witness)
            )
        );
        nativeSale.previewPriceProgram(free);
        _raiseSignature(parameter, 800_000);
        require(factory.gasParameter(parameter) == 800_000, "actual stored governed cap changed");
        _buy(fixedExecution);
        _execute(free);
        require(
            manager.nonce() == 2 && recorder.totalOfficialSettled(address(0)) == 1000,
            "both use new cap, only fixed funds"
        );
        require(
            nativeSale.authorizationUsed(artist, bytes32(uint256(1)))
                && nativeSale.authorizationUsed(artist, bytes32(uint256(2))),
            "both exact executions consumed"
        );
    }

    function _raiseSignature(bytes32 id, uint256 next) private {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            factory.gasParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(factory),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        _context(
            scope,
            keccak256(abi.encode(domain, scope, value, floor, failureClass, revision)),
            keccak256(abi.encode(domain, scope, next, floor, failureClass, revision + 1)),
            1
        );
        vm.prank(address(revenueAuthority));
        factory.raiseGasParameter(id, next);
        _clearContext();
    }
}
