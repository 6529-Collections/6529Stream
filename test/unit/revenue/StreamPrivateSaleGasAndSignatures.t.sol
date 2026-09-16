// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PrivateSaleTestBase.sol";

contract PrivateSaleSignatureWitness {
    uint256 public mode;

    function setMode(uint256 value) external {
        mode = value;
    }

    function isValidSignature(bytes32, bytes calldata) external view returns (bytes4) {
        uint256 m = mode;
        if (m == 1) revert("signature unavailable");
        if (m == 2) assembly ("memory-safe") {
            mstore(0, shl(224, 0x1626ba7e))
            return(0, 31)
        }
        if (m == 3) {
            assembly ("memory-safe") {
                let p := mload(0x40)
                mstore(p, shl(224, 0x1626ba7e))
                return(p, 65536)
            }
        }
        if (m == 4) assembly ("memory-safe") {
            mstore(0, or(shl(224, 0x1626ba7e), 1))
            return(0, 32)
        }
        if (m == 5 && gasleft() < 600000) return 0xffffffff;
        if (m == 6) while (true) { }
        return 0x1626ba7e;
    }
}

contract PrivateSaleRoyaltyWitness {
    uint256 public mode;

    function setMode(uint256 value) external {
        mode = value;
    }

    receive() external payable {
        uint256 m = mode;
        if (m == 1) assembly ("memory-safe") {
            let p := mload(0x40)
            revert(p, 65536)
        }
        if (m == 2) assembly ("memory-safe") {
            let p := mload(0x40)
            return(p, 65536)
        }
        if (m == 3) while (true) { }
    }
}

contract StreamPrivateSaleGasAndSignaturesTest is PrivateSaleTestBase {
    function testExplicitEoaKindUsesOwnKeyEvenWithDelegationDesignatorCode() external {
        // Paris execution profile: proves code-presence-independent recovery, not delegated execution.
        vm.etch(platform, abi.encodePacked(hex"ef0100", address(royalty)));
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        _purchase(id, 1000);
        require(core.ownerOf(1) == buyer && platform.code.length == 23);
    }

    function testNonmemberMagicAndWrongExplicitKindCannotAuthorizeSale() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory bad =
            IStreamPrivateSaleAdapter.Signature(address(royalty), 2, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleAuthorityInvalid.selector, address(royalty)
            )
        );
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, bad);
        bad = _platformProof(a);
        bad.kind = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleAuthorityInvalid.selector, platform
            )
        );
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, bad);
        _purchase(id, 1000);
        require(core.ownerOf(1) == buyer);
    }

    function testMalformedAndFailed1271ReturnsRejectThenIdenticalProofSucceeds() external {
        PrivateSaleSignatureWitness witness = new PrivateSaleSignatureWitness();
        sale = _newSale(address(witness), address(this));
        _register();
        sale.configureCollectionSigner(1, keccak256("explicit collection signer authority"), true);
        vm.prank(consignor);
        core.setApprovalForAll(address(sale), true);
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof =
            IStreamPrivateSaleAdapter.Signature(address(witness), 2, "");
        for (uint256 mode = 1; mode <= 6; ++mode) {
            witness.setMode(mode);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamPrivateSaleAdapter.PrivateSaleAuthorityInvalid.selector, address(witness)
                )
            );
            vm.prank(buyer);
            sale.purchasePrivate{ value: 1000 }(a, proof);
            require(
                !sale.digestConsumed(sale.authorizationDigest(a))
                    && sale.saleDetails(id).status == 2
            );
        }
        witness.setMode(0);
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(core.ownerOf(1) == buyer);
    }

    function testActualGovernedSignatureRaiseChangesTheForwardedCanonicalCap() external {
        PrivateSaleSignatureWitness witness = new PrivateSaleSignatureWitness();
        witness.setMode(5);
        sale = _newSale(address(witness), address(this));
        _register();
        sale.configureCollectionSigner(1, keccak256("explicit collection signer authority"), true);
        vm.prank(consignor);
        core.setApprovalForAll(address(sale), true);
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof =
            IStreamPrivateSaleAdapter.Signature(address(witness), 2, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrivateSaleAdapter.PrivateSaleAuthorityInvalid.selector, address(witness)
            )
        );
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        bytes32 cap = keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT");
        _raiseGas(cap, 800000);
        require(sale.gasParameter(cap) == 800000);
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(core.ownerOf(1) == buyer);
    }

    function testUnderfundedParentRollsBackAndExactSameAuthorizationRetries() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        vm.prank(buyer);
        (bool ok, bytes memory result) = address(sale).call{ gas: 180000, value: 1000 }(
            abi.encodeCall(sale.purchasePrivate, (a, proof))
        );
        require(
            !ok && result.length == 68
                && bytes4(result) == IStreamPrivateSaleAdapter.PrivateSaleInsufficientGas.selector
        );
        require(
            sale.saleDetails(id).status == 2 && !sale.digestConsumed(sale.authorizationDigest(a))
        );
        require(
            address(royalty).balance == 0 && address(sale).balance == 0
                && core.ownerOf(1) == address(sale)
        );
        vm.prank(buyer);
        sale.purchasePrivate{ value: 1000 }(a, proof);
        require(core.ownerOf(1) == buyer);
    }

    function testBoundedRoyaltyRevertBombAndOutOfGasCreateOnlyExactOwedBucket() external {
        PrivateSaleRoyaltyWitness witness = new PrivateSaleRoyaltyWitness();
        core.setRoyalty(address(witness), 1000, false);
        for (uint256 i; i < 3; ++i) {
            if (i != 0) core.mint(consignor, i + 1);
            bytes32 id = sale.registerSale(_config(5, i + 1, buyer, 0));
            _deposit(id);
            witness.setMode(i + 1);
            _purchase(id, 1000);
            require(core.ownerOf(i + 1) == buyer && sale.saleDetails(id).status == 3);
            if (i == 1) {
                require(sale.refundableBalance(id, address(witness)) == 0);
            } else {
                require(sale.refundableBalance(id, address(witness)) == 100);
                witness.setMode(0);
                require(sale.retryRoyalty(id));
                require(sale.refundableBalance(id, address(witness)) == 0);
            }
            require(sale.refundableBalance(id, consignor) == 900);
        }
        require(address(witness).balance == 300 && sale.totalLiabilities() == 2700);
    }
}
