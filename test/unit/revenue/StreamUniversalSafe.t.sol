// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/UniversalSettlementTestBase.sol";

contract StreamUniversalSafeTest is UniversalSettlementTestBase {
    OfficialSafe private safe;
    uint256[] private keys;
    event SafeSelectorObserved(address indexed target, bytes4 indexed selector, uint8 result);

    function _safe() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 765);
        token.mint(address(safe), 4000);
        _exec(address(token), abi.encodeCall(token.approve, (address(payment), uint256(4000))));
    }

    function testActualSafePayerDirectAndRelayedIntentRevocations() public {
        _safe();
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(address(safe), address(safe), address(safe), 1);
        _exec(
            address(payment),
            abi.encodeCall(
                IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleByPayer,
                (c, abi.encode(e))
            )
        );
        require(
            manager.ownerOf(1) == address(safe) && token.balanceOf(address(safe)) == 3000,
            "actual Safe direct payer and recipient"
        );
        (e, c) = _execution(address(safe), address(this), address(safe), 2);
        StreamPrimarySettlementTypes.PaymentIntent memory intent =
            StreamPrimarySettlementTypes.PaymentIntent(
                address(safe),
                address(token),
                1000,
                saleId,
                _primaryPolicy(),
                keccak256("safe intent"),
                uint64(block.timestamp + 1 hours)
            );
        bytes32 digest = payment.paymentIntentDigest(intent);
        bytes memory wrong = safeThresholdSignature(keys, digest);
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithIntent,
                    (c, intent, wrong, abi.encode(e))
                )
            );
        require(
            !ok && token.balanceOf(address(safe)) == 3000
                && !payment.isPaymentIntentNonceUsed(address(safe), intent.nonce),
            "raw Safe owner proof invalid"
        );
        bytes memory signature =
            safeThresholdSignature(keys, safeMessageDigest(safe, abi.encode(digest)));
        payment.settleERC20PrimarySaleWithIntent(c, intent, signature, abi.encode(e));
        require(
            manager.ownerOf(2) == address(safe) && token.balanceOf(address(safe)) == 2000
                && payment.isPaymentIntentNonceUsed(address(safe), intent.nonce),
            "real ERC1271 relayed payer intent"
        );
        bytes32 own = keccak256("safe revoke");
        _exec(
            address(payment),
            abi.encodeCall(IStreamERC20PrimarySettlementAdapter.revokePaymentIntent, (own))
        );
        StreamPrimarySettlementTypes.PaymentIntentRevocation memory r =
            StreamPrimarySettlementTypes.PaymentIntentRevocation(
                address(safe), keccak256("safe relayed revoke"), uint64(block.timestamp + 1 hours)
            );
        bytes memory revokeSignature = safeThresholdSignature(
            keys, safeMessageDigest(safe, abi.encode(payment.paymentIntentRevocationDigest(r)))
        );
        _exec(
            address(payment),
            abi.encodeCall(
                IStreamERC20PrimarySettlementAdapter.revokePaymentIntentWithSignature,
                (r, revokeSignature)
            )
        );
        require(
            payment.isPaymentIntentNonceUsed(address(safe), own)
                && payment.isPaymentIntentNonceUsed(address(safe), r.nonce),
            "both Safe revocation paths"
        );
        (ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.revokePaymentIntentWithSignature,
                    (r, revokeSignature)
                )
            );
        require(!ok, "Safe revocation replay");
        (e, c) = _execution(address(safe), address(safe), address(safe), 3);
        intent.nonce = keccak256("Safe executes its intent");
        signature = safeThresholdSignature(
            keys, safeMessageDigest(safe, abi.encode(payment.paymentIntentDigest(intent)))
        );
        _exec(
            address(payment),
            abi.encodeCall(
                IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithIntent,
                (c, intent, signature, abi.encode(e))
            )
        );
        require(
            token.balanceOf(address(safe)) == 1000 && manager.ownerOf(3) == address(safe),
            "actual Safe caller of intent entry"
        );
    }

    function testActualSafeOwnerAndProtocolOnlyCalls() public {
        _safe();
        sale.transferOwnership(address(safe));
        IStreamUniversalFixedPriceSaleAdapter.SaleConfig memory config =
        sale.saleRecord(saleId).config;
        _exec(
            address(sale),
            abi.encodeCall(IStreamUniversalFixedPriceSaleAdapter.registerSale, (config))
        );
        bytes32 second = sale.saleIdFor(1, PHASE, 2);
        require(sale.saleRecord(second).saleNonce == 2, "role-bearing Safe creates sale");
        _exec(
            address(sale),
            abi.encodeCall(IStreamUniversalFixedPriceSaleAdapter.cancelSale, (second))
        );
        _exec(
            address(sale), abi.encodeCall(IStreamUniversalFixedPriceSaleAdapter.setPaused, (true))
        );
        require(
            sale.paused() && sale.saleRecord(second).cancelled,
            "Safe owner mutates actual configuration"
        );
        _exec(
            address(sale), abi.encodeCall(IStreamUniversalFixedPriceSaleAdapter.setPaused, (false))
        );
        _exec(
            address(sale),
            abi.encodeCall(
                IStreamUniversalFixedPriceSaleAdapter.cancelAuthorization,
                (keccak256("Safe commercial cancellation"))
            )
        );
        require(
            sale.authorizationUsed(address(safe), keccak256("Safe commercial cancellation")),
            "caller remains Safe"
        );
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(address(safe), address(safe), address(safe), 1);
        _reject(
            address(payment),
            abi.encodeCall(
                IStreamERC20PrimarySettlementAdapter.fundERC20PrimarySale,
                (bytes32(uint256(1)), bytes32(uint256(2)), address(token), uint256(1000))
            ),
            abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.UnauthorizedFundingReturn.selector
            )
        );
        _reject(
            address(recorder),
            abi.encodeCall(
                IStreamPrimarySaleSettlement.settleERC20PrimarySaleFromAdapter,
                (address(payment), c)
            ),
            abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
        );
        _reject(
            address(sale),
            abi.encodeCall(
                IStreamERC20SaleExecution.executeERC20PreRevenueSingleStep, (c, abi.encode(e))
            ),
            abi.encodeWithSelector(
                IStreamUniversalFixedPriceSaleAdapter.UniversalCandidateMismatch.selector
            )
        );
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p =
            StreamPrimarySettlementTypes.EIP2612PermitAuthorization(
                block.timestamp + 1 hours, 27, bytes32(uint256(1)), bytes32(uint256(1))
            );
        // Linked library selectors are delegate-only, including for an actual Safe.
        _reject(
            address(StreamPermitExecution),
            abi.encodeWithSelector(
                StreamPermitExecution.permitEIP2612.selector,
                address(safe),
                address(token),
                uint256(1000),
                p,
                uint256(500_000)
            ),
            bytes("")
        );
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory permit =
            StreamPrimarySettlementTypes.Permit2TransferAuthorization(
                1, block.timestamp + 1 hours, bytes("")
            );
        _reject(
            address(StreamPermitExecution),
            abi.encodeWithSelector(
                StreamPermitExecution.pull.selector,
                address(safe),
                address(token),
                uint256(1000),
                address(permit2),
                uint8(1),
                permit,
                uint256(500_000)
            ),
            bytes("")
        );
        _reject(
            address(payment),
            abi.encodeCall(
                IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithEIP2612Permit,
                (c, p, abi.encode(e))
            ),
            abi.encodeWithSelector(
                StreamERC20PrimarySettlementAdapter.PaymentCallbackFailed.selector
            )
        );
        require(
            token.nonces(address(safe)) == 0 && token.balanceOf(address(safe)) == 4000,
            "EOA-only token permit intentionally cannot sign for Safe"
        );
        _exec(address(sale), abi.encodeWithSignature("transferOwnership(address)", address(this)));
        require(sale.owner() == address(this), "Safe transfer ownership");
        sale.transferOwnership(address(safe));
        _exec(address(sale), abi.encodeWithSignature("renounceOwnership()"));
        require(sale.owner() == address(0), "Safe renounce ownership");
    }

    function testActualSafeAllReadSelectors() public {
        _safe();
        _zeroArgumentReads();
        bytes32 key = recorder.settlementKey(address(sale), bytes32(uint256(1)));
        _read(
            address(recorder),
            abi.encodeCall(
                IStreamPrimarySaleSettlement.officialSettled,
                (CLASS, profile, wallet, address(token))
            )
        );
        _read(
            address(recorder),
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementConsumed, (key))
        );
        _read(
            address(recorder),
            abi.encodeCall(
                IStreamPrimarySaleSettlement.settlementKey, (address(sale), bytes32(uint256(1)))
            )
        );
        _read(
            address(recorder), abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (key))
        );
        _read(
            address(recorder),
            abi.encodeCall(IStreamPrimarySaleSettlement.totalOfficialSettled, (address(token)))
        );
        _read(
            address(recorder),
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(IStreamPrimarySaleSettlement).interfaceId
            )
        );
        StreamPrimarySettlementTypes.PaymentIntent memory intent =
            StreamPrimarySettlementTypes.PaymentIntent(
                address(safe),
                address(token),
                1000,
                saleId,
                _primaryPolicy(),
                bytes32(uint256(1)),
                uint64(block.timestamp + 1 hours)
            );
        StreamPrimarySettlementTypes.PaymentIntentRevocation memory r =
            StreamPrimarySettlementTypes.PaymentIntentRevocation(
                address(safe), bytes32(uint256(2)), uint64(block.timestamp + 1 hours)
            );
        _read(
            address(payment),
            abi.encodeCall(IStreamERC20PrimarySettlementAdapter.paymentIntentDigest, (intent))
        );
        _read(
            address(payment),
            abi.encodeCall(IStreamERC20PrimarySettlementAdapter.paymentIntentRevocationDigest, (r))
        );
        _read(
            address(payment),
            abi.encodeCall(
                IStreamERC20PrimarySettlementAdapter.isPaymentIntentNonceUsed,
                (address(safe), bytes32(uint256(1)))
            )
        );
        _read(
            address(payment),
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(IStreamERC20PrimarySettlementAdapter).interfaceId
            )
        );
        (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _execution(address(safe), address(safe), address(safe), 1);
        _read(
            address(sale),
            abi.encodeCall(
                IStreamUniversalFixedPriceSaleAdapter.authorizationDigest, (e.authorization)
            )
        );
        _read(
            address(sale),
            abi.encodeWithSignature(
                "authorizationUsed(address,bytes32)", artist, e.authorization.nonce
            )
        );
        _read(
            address(sale),
            abi.encodeWithSignature("executionIdByNonce(bytes32,uint256)", saleId, uint256(1))
        );
        _read(
            address(sale), abi.encodeWithSignature("executionStatus(bytes32)", bytes32(uint256(1)))
        );
        _read(
            address(sale),
            abi.encodeCall(IStreamUniversalFixedPriceSaleAdapter.previewExecution, (e))
        );
        _read(
            address(sale),
            abi.encodeCall(
                IStreamUniversalFixedPriceSaleAdapter.saleIdFor, (uint256(1), PHASE, uint256(1))
            )
        );
        _read(
            address(sale),
            abi.encodeCall(IStreamSaleLifecycleBinding.saleLifecycleBinding, (saleId))
        );
        _read(
            address(sale),
            abi.encodeCall(IStreamUniversalFixedPriceSaleAdapter.saleRecord, (saleId))
        );
        _read(
            address(sale),
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(IStreamERC20SaleExecution).interfaceId
            )
        );
    }

    function _exec(address target, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(
            executeSafe(safe, keys, target, 0, data, 0) && safe.nonce() == nonce + 1,
            "actual Safe execution and nonce"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++count;
        }
        require(count == 1, "actual Safe ExecutionSuccess");
        emit SafeSelectorObserved(target, bytes4(data), 1);
    }

    function _read(address target, bytes memory data) private {
        (bool ok, bytes memory expected) = target.staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory actual) = target.staticcall(data);
        require(ok && safeOk && keccak256(actual) == keccak256(expected), "Safe read value parity");
        _exec(target, data);
    }

    function _reject(address target, bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory reason) = target.call(data);
        require(!ok && keccak256(reason) == keccak256(expected), "exact protocol-only rejection");
        uint256 nonce = safe.nonce();
        (ok, reason) = address(this).call(abi.encodeCall(this.attemptSafe, (target, data)));
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && safe.nonce() == nonce,
            "actual Safe failure rollback"
        );
        emit SafeSelectorObserved(target, bytes4(data), 2);
    }

    function attemptSafe(address target, bytes calldata data) external {
        require(msg.sender == address(this), "test wrapper");
        require(executeSafe(safe, keys, target, 0, data, 0), "Safe returned false");
    }

    function _zeroArgumentReads() private {
        _read(address(recorder), abi.encodeWithSignature("assetPolicyRegistry()"));
        _read(address(recorder), abi.encodeWithSignature("assetRegistryCodeHash()"));
        _read(address(recorder), abi.encodeWithSignature("core()"));
        _read(address(recorder), abi.encodeWithSignature("coreCodeHash()"));
        _read(address(recorder), abi.encodeWithSignature("escrowCodeHash()"));
        _read(address(recorder), abi.encodeWithSignature("factoryCodeHash()"));
        _read(address(recorder), abi.encodeWithSignature("isStreamPrimarySaleSettlement()"));
        _read(address(recorder), abi.encodeWithSignature("moduleRegistry()"));
        _read(address(recorder), abi.encodeWithSignature("moduleRegistryCodeHash()"));
        _read(address(recorder), abi.encodeWithSignature("resolverCodeHash()"));
        _read(address(recorder), abi.encodeWithSignature("revenueEscrow()"));
        _read(address(recorder), abi.encodeWithSignature("revenueResolver()"));
        _read(address(recorder), abi.encodeWithSignature("splitFactory()"));
        _read(address(recorder), abi.encodeWithSignature("walletCodeHash()"));
        _read(address(payment), abi.encodeWithSignature("PAYMENT_INTENT_REVOCATION_TYPEHASH()"));
        _read(address(payment), abi.encodeWithSignature("PAYMENT_INTENT_TYPEHASH()"));
        _read(address(payment), abi.encodeWithSignature("assetPolicyRegistry()"));
        _read(address(payment), abi.encodeWithSignature("assetRegistryCodeHash()"));
        _read(address(payment), abi.encodeWithSignature("core()"));
        _read(address(payment), abi.encodeWithSignature("coreCodeHash()"));
        _read(address(payment), abi.encodeWithSignature("eip712Domain()"));
        _read(address(payment), abi.encodeWithSignature("factoryCodeHash()"));
        _read(address(payment), abi.encodeWithSignature("isStreamERC20PrimarySettlementAdapter()"));
        _read(address(payment), abi.encodeWithSignature("moduleRegistry()"));
        _read(address(payment), abi.encodeWithSignature("moduleRegistryCodeHash()"));
        _read(address(payment), abi.encodeWithSignature("permit2()"));
        _read(address(payment), abi.encodeWithSignature("permit2ChainId()"));
        _read(address(payment), abi.encodeWithSignature("permit2CodeHash()"));
        _read(address(payment), abi.encodeWithSignature("phase()"));
        _read(address(payment), abi.encodeWithSignature("primarySaleSettlement()"));
        _read(address(payment), abi.encodeWithSignature("resolverCodeHash()"));
        _read(address(payment), abi.encodeWithSignature("revenueResolver()"));
        _read(address(payment), abi.encodeWithSignature("settlementCodeHash()"));
        _read(address(payment), abi.encodeWithSignature("splitFactory()"));
        _read(address(sale), abi.encodeWithSignature("SALE_AUTHORIZATION_TYPEHASH()"));
        _read(address(sale), abi.encodeWithSignature("artistRegistry()"));
        _read(address(sale), abi.encodeWithSignature("artistRegistryCodeHash()"));
        _read(address(sale), abi.encodeWithSignature("assetPolicyRegistry()"));
        _read(address(sale), abi.encodeWithSignature("assetRegistryCodeHash()"));
        _read(address(sale), abi.encodeWithSignature("core()"));
        _read(address(sale), abi.encodeWithSignature("coreCodeHash()"));
        _read(address(sale), abi.encodeWithSignature("factoryCodeHash()"));
        _read(address(sale), abi.encodeWithSignature("mintManager()"));
        _read(address(sale), abi.encodeWithSignature("mintManagerCodeHash()"));
        _read(address(sale), abi.encodeWithSignature("moduleRegistry()"));
        _read(address(sale), abi.encodeWithSignature("moduleRegistryCodeHash()"));
        _read(address(sale), abi.encodeWithSignature("nextSaleNonce()"));
        _read(address(sale), abi.encodeWithSignature("owner()"));
        _read(address(sale), abi.encodeWithSignature("paused()"));
        _read(address(sale), abi.encodeWithSignature("platformSigner()"));
        _read(address(sale), abi.encodeWithSignature("primarySaleSettlement()"));
        _read(address(sale), abi.encodeWithSignature("resolverCodeHash()"));
        _read(address(sale), abi.encodeWithSignature("revenueResolver()"));
        _read(address(sale), abi.encodeWithSignature("settlementCodeHash()"));
        _read(address(sale), abi.encodeWithSignature("splitFactory()"));
    }
}
