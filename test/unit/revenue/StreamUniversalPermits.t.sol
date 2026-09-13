// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/UniversalSettlementTestBase.sol";

contract StreamUniversalPermitsTest is UniversalSettlementTestBase {
    function testEIP2612ExactPermitConsumesAllowanceAndMoney() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p = _eipPermit();
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithEIP2612Permit(c, p, abi.encode(e));
        require(
            token.nonces(payer) == 1 && token.allowance(payer, address(payment)) == 0
                && token.balanceOf(payer) == 9000 && token.balanceOf(wallet) == 1000,
            "exact permit then first pull"
        );
    }

    function testEIP2612LaterFailureRestoresPermitNonceApprovalMoneyAndRetry() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p = _eipPermit();
        manager.configure(1);
        vm.prank(payer);
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithEIP2612Permit,
                    (c, p, abi.encode(e))
                )
            );
        require(
            !ok && token.nonces(payer) == 0 && token.allowance(payer, address(payment)) == 10_000
                && token.balanceOf(payer) == 10_000
                && recorder.totalOfficialSettled(address(token)) == 0
                && sale.executionIdByNonce(saleId, 1) == 0,
            "permit and entire graph rollback"
        );
        manager.configure(0);
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithEIP2612Permit(c, p, abi.encode(e));
        require(token.nonces(payer) == 1, "same signature retry");
    }

    function testEIP2612NoFrontRunOrMissingCapabilityFallback() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p = _eipPermit();
        token.permit(payer, address(payment), 1000, p.deadline, p.v, p.r, p.s);
        vm.prank(payer);
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithEIP2612Permit,
                    (c, p, abi.encode(e))
                )
            );
        require(
            !ok && token.balanceOf(payer) == 10_000 && token.nonces(payer) == 1
                && token.allowance(payer, address(payment)) == 1000,
            "stale permit never becomes allowance path"
        );
        p = _eipPermit();
        _permitPolicy(2, 1);
        vm.prank(payer);
        (ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithEIP2612Permit,
                    (c, p, abi.encode(e))
                )
            );
        require(
            !ok && token.nonces(payer) == 1 && token.balanceOf(payer) == 10_000,
            "capability required"
        );
    }

    function testOfficialPermit2EOAExactFiniteAndMaxPreservedModes() public {
        for (uint256 i; i < 2; ++i) {
            if (i == 1) {
                token.setPreserveMax(true);
                _permitPolicy(3, 2);
            }
            uint256 approval = i == 0 ? 4000 : type(uint256).max;
            vm.prank(payer);
            token.approve(permit2, approval);
            (
                IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
                StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
            ) = _execution(payer, payer, payer, i + 1);
            StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p =
                _permit2Authorization(PAYER_KEY, i + 1);
            vm.prank(payer);
            payment.settleERC20PrimarySaleWithPermit2(c, p, abi.encode(e));
            require(
                IStreamPinnedPermit2(permit2).nonceBitmap(payer, 0) & (1 << p.nonce) != 0,
                "official nonce consumed"
            );
            require(
                token.allowance(payer, permit2) == (i == 0 ? 3000 : type(uint256).max),
                "attested allowance semantics"
            );
        }
        require(
            token.balanceOf(payer) == 8000 && token.balanceOf(wallet) == 2000,
            "both actual Permit2 pulls"
        );
    }

    function testOfficialPermit2LaterMintFailureRestoresBitmapAllowanceMoney() public {
        vm.prank(payer);
        token.approve(permit2, 4000);
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p =
            _permit2Authorization(PAYER_KEY, 255);
        manager.configure(1);
        vm.prank(payer);
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithPermit2,
                    (c, p, abi.encode(e))
                )
            );
        require(
            !ok && IStreamPinnedPermit2(permit2).nonceBitmap(payer, 0) == 0
                && token.allowance(payer, permit2) == 4000 && token.balanceOf(payer) == 10_000
                && token.balanceOf(wallet) == 0
                && recorder.totalOfficialSettled(address(token)) == 0,
            "official nonce and all payment rollback"
        );
        manager.configure(0);
        vm.prank(payer);
        payment.settleERC20PrimarySaleWithPermit2(c, p, abi.encode(e));
        require(
            IStreamPinnedPermit2(permit2).nonceBitmap(payer, 0) == 1 << 255,
            "identical permit succeeds exactly once"
        );
    }

    function testPermitIsAllowanceAuthorizationNotRelayerPurchaseConsent() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, address(this), payer, 1);
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p = _eipPermit();
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithEIP2612Permit,
                    (c, p, abi.encode(e))
                )
            );
        require(!ok && token.nonces(payer) == 0, "ordinary permit not Stream consent");
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p2 =
            _permit2Authorization(PAYER_KEY, 1);
        (ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithPermit2,
                    (c, p2, abi.encode(e))
                )
            );
        require(
            !ok && IStreamPinnedPermit2(permit2).nonceBitmap(payer, 0) == 0
                && token.balanceOf(payer) == 10_000,
            "Permit2 approval not relayed purchase consent"
        );
    }

    function testPermitCapabilityStaleAfterAssetRevisionAndCodeDriftRejects() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p = _eipPermit();
        _setAssetPolicy(policy, address(token), 1, keccak256("reviewed revision"), 0);
        vm.prank(payer);
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithEIP2612Permit,
                    (c, p, abi.encode(e))
                )
            );
        require(!ok && token.nonces(payer) == 0, "stale attestation rejected");
        _permitPolicy(3, 1);
        vm.etch(permit2, hex"60006000fd");
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p2 =
            _permit2Authorization(PAYER_KEY, 1);
        vm.prank(payer);
        (ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithPermit2,
                    (c, p2, abi.encode(e))
                )
            );
        require(!ok && token.balanceOf(payer) == 10_000, "immutable third-party runtime pin");
    }

    function _eipPermit()
        internal
        returns (StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p)
    {
        p.deadline = block.timestamp + 1 hours;
        (p.v, p.r, p.s) =
            vm.sign(PAYER_KEY, token.permitDigest(payer, address(payment), 1000, p.deadline));
    }

    function _permit2Digest(uint256 nonce, uint256 deadline) internal view returns (bytes32) {
        bytes32 tokenHash = keccak256(
            abi.encode(
                keccak256("TokenPermissions(address token,uint256 amount)"),
                address(token),
                uint256(1000)
            )
        );
        bytes32 permitHash = keccak256(
            abi.encode(
                keccak256(
                    "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
                ),
                tokenHash,
                address(payment),
                nonce,
                deadline
            )
        );
        return keccak256(abi.encodePacked(hex"1901", permit2Domain(permit2), permitHash));
    }

    function _permit2Authorization(uint256 key, uint256 nonce)
        internal
        returns (StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p)
    {
        p.nonce = nonce;
        p.deadline = block.timestamp + 1 hours;
        p.signature = _sign(key, _permit2Digest(nonce, p.deadline));
    }
}

contract StreamUniversalSafePermitsTest is UniversalSettlementTestBase {
    event Permit2GovernedBudgetObserved(uint256 insufficient, uint256 sufficient);

    function _depositBudget() internal pure override returns (uint256) {
        return 50_000;
    }

    function testActualThresholdSafePermit2InsufficientThenGovernedBudgetAndAtomicRetry() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        uint256[] memory owners = new uint256[](3);
        owners[0] = keys[0];
        owners[1] = keys[1];
        owners[2] = 0xCAFE;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 1234);
        token.mint(address(safe), 4000);
        require(
            executeSafe(
                safe,
                keys,
                address(token),
                0,
                abi.encodeCall(token.approve, (permit2, uint256(4000))),
                0
            ),
            "Safe approves official Permit2"
        );
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(address(safe), address(safe), address(safe), 1);
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p;
        p.nonce = 1;
        p.deadline = block.timestamp + 1 hours;
        bytes32 tokenHash = keccak256(
            abi.encode(
                keccak256("TokenPermissions(address token,uint256 amount)"),
                address(token),
                uint256(1000)
            )
        );
        bytes32 permitHash = keccak256(
            abi.encode(
                keccak256(
                    "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
                ),
                tokenHash,
                address(payment),
                p.nonce,
                p.deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", permit2Domain(permit2), permitHash));
        p.signature = safeThresholdSignature(keys, safeMessageDigest(safe, abi.encode(digest)));
        bytes memory data = abi.encodeCall(
            IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithPermit2,
            (c, p, abi.encode(e))
        );
        (bool ok, bytes memory reason) =
            address(this).call(abi.encodeCall(this.attemptSafe, (safe, keys, data)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "actual Safe reports insufficient whole-call budget"
        );
        require(
            safe.nonce() == 1 && token.balanceOf(address(safe)) == 4000
                && token.allowance(address(safe), permit2) == 4000
                && IStreamPinnedPermit2(permit2).nonceBitmap(address(safe), 0) == 0
                && sale.executionIdByNonce(saleId, 1) == 0,
            "failed Safe Permit2 leaves every state unchanged"
        );
        _raiseDeposit(100_000);
        _raiseDeposit(200_000);
        _raiseDeposit(400_000);
        // Wrong raw Stream-style owner proof is not accepted by the actual Safe fallback handler.
        p.signature = safeThresholdSignature(keys, digest);
        bytes memory wrong = abi.encodeCall(
            IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithPermit2,
            (c, p, abi.encode(e))
        );
        (ok,) = address(this).call(abi.encodeCall(this.attemptSafe, (safe, keys, wrong)));
        require(!ok && safe.nonce() == 1, "raw owner proof rejected");
        // The original exact Safe-wrapped Permit2 bytes now execute under the governed whole-call cap.
        require(executeSafe(safe, keys, address(payment), 0, data, 0), "real Safe Permit2 purchase");
        require(
            safe.nonce() == 2 && token.balanceOf(address(safe)) == 3000
                && token.allowance(address(safe), permit2) == 3000
                && IStreamPinnedPermit2(permit2).nonceBitmap(address(safe), 0) == 2
                && manager.ownerOf(1) == address(safe) && token.balanceOf(wallet) == 1000,
            "Safe operation and payment both succeeded"
        );
        emit Permit2GovernedBudgetObserved(50_000, 400_000);
    }

    function attemptSafe(OfficialSafe safe, uint256[] calldata keys, bytes calldata data) external {
        require(msg.sender == address(this), "test wrapper");
        require(executeSafe(safe, keys, address(payment), 0, data, 0), "Safe execution success");
    }

    function _raiseDeposit(uint256 next) internal {
        bytes32 id = keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT");
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
