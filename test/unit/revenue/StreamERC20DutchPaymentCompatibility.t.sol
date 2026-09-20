// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/UniversalSettlementTestBase.sol";
import {
    StreamERC20PaymentRead as Read
} from "../../../smart-contracts/domains/revenue/StreamERC20PaymentRead.sol";

/// @notice Four unchanged fixed entrypoints against the newly factored Payment, actual original
/// recorder/Universal/Registry/Floor/wallet/Permit2. Core/Artist/Manager/governance remain typed.
/// This finite compatibility cohort does not stand for the prior complete93 source graph.
contract StreamERC20DutchPaymentCompatibilityTest is UniversalSettlementTestBase {
    function testOriginalPayerEntryPreservesExactReceiptAndPassiveSurplus() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        token.mint(address(payment), 17);
        token.mint(address(recorder), 23);
        vm.prank(payer);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        _exact(r, c);
        require(
            token.balanceOf(address(payment)) == 17 && token.balanceOf(address(recorder)) == 23,
            "old passive balances preserved"
        );
    }

    function testOriginalIntentEntryRestoresNonceOnLateFailureThenSameSignatureRetries() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, address(this), payer, 1);
        StreamPrimarySettlementTypes.PaymentIntent memory intent =
            StreamPrimarySettlementTypes.PaymentIntent(
                payer, address(token), 1000, saleId, _primaryPolicy(), bytes32(uint256(1)), 3000
            );
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamPaymentIntentVerifier"),
                keccak256("1"),
                block.chainid,
                address(payment)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)"
                ),
                intent
            )
        );
        bytes memory signature =
            _sign(PAYER_KEY, keccak256(abi.encodePacked(hex"1901", domain, body)));
        manager.configure(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector
            )
        );
        payment.settleERC20PrimarySaleWithIntent(c, intent, signature, abi.encode(e));
        require(
            !payment.isPaymentIntentNonceUsed(payer, intent.nonce)
                && token.balanceOf(payer) == 10000,
            "original nonce and balance rollback"
        );
        manager.configure(0);
        _exact(payment.settleERC20PrimarySaleWithIntent(c, intent, signature, abi.encode(e)), c);
        require(payment.isPaymentIntentNonceUsed(payer, intent.nonce));
    }

    function testOriginalEIP2612ExactAmountEntryRemainsExact() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(PAYER_KEY, token.permitDigest(payer, address(payment), 1000, 3000));
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p =
            StreamPrimarySettlementTypes.EIP2612PermitAuthorization(3000, v, r, s);
        vm.prank(payer);
        _exact(payment.settleERC20PrimarySaleWithEIP2612Permit(c, p, abi.encode(e)), c);
        require(
            token.nonces(payer) == 1 && token.allowance(payer, address(payment)) == 0,
            "old exact permit amount"
        );
    }

    function testOriginalPermit2ExactPermissionAndPullRemainEqual() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        bytes32 th = keccak256(
            abi.encode(
                keccak256("TokenPermissions(address token,uint256 amount)"),
                address(token),
                uint256(1000)
            )
        );
        bytes32 ph = keccak256(
            abi.encode(
                keccak256(
                    "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
                ),
                th,
                address(payment),
                uint256(255),
                uint256(3000)
            )
        );
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p =
            StreamPrimarySettlementTypes.Permit2TransferAuthorization(
                255,
                3000,
                _sign(PAYER_KEY, keccak256(abi.encodePacked(hex"1901", permit2Domain(permit2), ph)))
            );
        vm.prank(payer);
        token.approve(permit2, 2000);
        vm.prank(payer);
        _exact(payment.settleERC20PrimarySaleWithPermit2(c, p, abi.encode(e)), c);
        require(
            IStreamPinnedPermit2(permit2).nonceBitmap(payer, 0) == uint256(1) << 255
                && token.allowance(payer, permit2) == 1000,
            "original exact upstream permission"
        );
    }

    function testFixedReadTransportRetainsAllFourOriginalShapes() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        bytes memory data = abi.encode(e);
        StreamPrimarySettlementTypes.PaymentIntent memory i =
            StreamPrimarySettlementTypes.PaymentIntent(
                payer, address(token), 1000, saleId, _primaryPolicy(), bytes32(uint256(7)), 3000
            );
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory ep =
            StreamPrimarySettlementTypes.EIP2612PermitAuthorization(
                3000, 27, bytes32(uint256(8)), bytes32(uint256(9))
            );
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p2 =
            StreamPrimarySettlementTypes.Permit2TransferAuthorization(255, 3000, hex"0102030405");
        bytes[] memory inputs = new bytes[](4);
        inputs[0] = abi.encodeCall(payment.settleERC20PrimarySaleByPayer, (c, data));
        inputs[1] = abi.encodeCall(
            payment.settleERC20PrimarySaleWithIntent, (c, i, hex"010203", data)
        );
        inputs[2] = abi.encodeCall(payment.settleERC20PrimarySaleWithEIP2612Permit, (c, ep, data));
        inputs[3] = abi.encodeCall(payment.settleERC20PrimarySaleWithPermit2, (c, p2, data));
        for (uint8 n; n < 4; ++n) {
            Read.FixedPlan memory p = Read.prepareFixed(inputs[n]);
            require(
                p.mode == n && keccak256(abi.encode(p.candidate)) == keccak256(abi.encode(c))
                    && keccak256(p.executionData) == keccak256(data),
                "fixed candidate and bytes"
            );
            if (n == 1) {
                require(
                    keccak256(abi.encode(p.intent)) == keccak256(abi.encode(i))
                        && keccak256(p.signature) == keccak256(hex"010203")
                );
            }
            if (n >= 2) {
                require(
                    p.deadline == 3000
                        && keccak256(p.permitInput)
                            == (n == 2 ? keccak256(abi.encode(ep)) : keccak256(abi.encode(p2)))
                );
            }
        }
    }

    function _exact(
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) private view {
        require(
            r.amount == 1000 && r.asset == address(token) && r.executor == c.executor
                && r.executionId == c.executionBinding.executionId,
            "original receipt identity"
        );
        require(
            keccak256(abi.encode(recorder.settlementResult(r.settlementKey)))
                == keccak256(abi.encode(r)),
            "all12 receipt words"
        );
        require(
            token.balanceOf(payer) == 9000 && token.balanceOf(wallet) == 1000
                && sale.executionStatus(r.executionId) == 2 && manager.ownerOf(1) == payer,
            "actual original flow"
        );
    }
}
