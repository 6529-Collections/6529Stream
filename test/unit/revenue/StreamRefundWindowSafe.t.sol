// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";

contract StreamRefundWindowSafeTest is RefundWindowTestBase {
    OfficialSafe private safe;
    OfficialSafe private other;
    uint256[] private keys;

    function _safes() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        SafeComponents memory c = deploySafeComponents("1.4.1");
        safe = createOfficialSafe(c, safeOwnerAddresses(keys), 2, 901);
        other = createOfficialSafe(c, safeOwnerAddresses(keys), 2, 902);
    }

    function _exec(OfficialSafe account, address target, uint256 value, bytes memory data) private {
        uint256 nonce = account.nonce();
        vm.recordLogs();
        require(
            executeSafe(account, keys, target, value, data, 0), "actual threshold Safe execution"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 successes;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(account)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++successes;
        }
        require(successes == 1 && account.nonce() == nonce + 1, "actual Safe event and nonce");
    }

    function attemptSafe(OfficialSafe account, address target, bytes calldata data) external {
        require(msg.sender == address(this), "test wrapper");
        require(executeSafe(account, keys, target, 0, data, 0), "Safe execution");
    }

    function _reject(OfficialSafe account, address target, bytes memory data, bytes memory expected)
        private
    {
        vm.prank(address(account));
        (bool ok, bytes memory reason) = target.call(data);
        require(!ok && keccak256(reason) == keccak256(expected), "exact target-side Safe rejection");
        uint256 nonce = account.nonce();
        (ok, reason) = address(this).call(abi.encodeCall(this.attemptSafe, (account, target, data)));
        require(
            !ok && keccak256(reason) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && account.nonce() == nonce,
            "real Safe failure and unchanged nonce"
        );
    }

    function _safePurchase(uint256 number) private returns (bytes32 id) {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d =
            _purchaseData(number, address(safe), address(safe));
        d.authorization.artist = address(safe);
        bytes32 digest = refundSale.refundPurchaseAuthorizationDigest(d.authorization);
        d.platformSignature = _sign(PLATFORM_KEY, digest);
        d.artistSignature =
            safeThresholdSignature(keys, safeMessageDigest(safe, abi.encode(digest)));
        _exec(
            safe,
            address(refundSale),
            1100,
            abi.encodeCall(IStreamNativeRefundWindowSale.purchaseRefundWindow, (d))
        );
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(refundSale),
                refundId,
                address(safe),
                number
            )
        );
        require(
            refundSale.refundPurchaseRecord(id).authorization.artist == address(safe),
            "actual Safe commercial signer"
        );
    }

    function testActualSafeThresholdAuthorizationNativeCustodyRefundClaimAndFinalization() public {
        _safes();
        artists.accept(address(safe));
        vm.deal(address(safe), 2200);
        IStreamNativeRefundWindowSale.RefundPurchaseData memory bad =
            _purchaseData(1, address(safe), address(safe));
        bad.authorization.artist = address(safe);
        bytes32 digest = refundSale.refundPurchaseAuthorizationDigest(bad.authorization);
        bad.platformSignature = _sign(PLATFORM_KEY, digest);
        bad.artistSignature = safeThresholdSignature(keys, digest);
        vm.prank(address(safe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundPurchaseSignatureInvalid.selector, address(safe)
            )
        );
        refundSale.purchaseRefundWindow{ value: 1100 }(bad);
        bytes32 first = _safePurchase(1);
        _exec(
            safe,
            address(refundSale),
            0,
            abi.encodeCall(IStreamNativeRefundWindowSale.refundPurchase, (first))
        );
        _exec(
            safe,
            address(refundSale),
            0,
            abi.encodeCall(
                IStreamNativeRefundWindowSale.claimRefund, (refundId, payable(address(safe)))
            )
        );
        require(
            address(safe).balance == 2200 && refundSale.refundCredit(address(safe)) == 0,
            "native pull payout into actual Safe"
        );
        bytes32 second = _safePurchase(2);
        _atRefundEnd(second);
        _exec(
            other,
            address(refundSale),
            0,
            abi.encodeCall(IStreamNativeRefundWindowSale.finalizeRefundWindow, (second))
        );
        require(
            refundManager.ownerOf(1) == address(safe) && wallet.balance == 1000
                && refundEntropy.revealFeeEscrow(1) == 100,
            "Safe custody and exact principal/fee"
        );
        _exec(
            other,
            address(refundSale),
            0,
            abi.encodeCall(IStreamNativeRefundWindowSale.finalizeRefundWindow, (second))
        );
        require(
            refundManager.nonce() == 1 && recorder.totalOfficialSettled(address(0)) == 1000,
            "permissionless Safe terminal readback does not repay"
        );
    }

    function testActualSafeOwnerRolesAndPermissionlessEscapesPreserveAuthority() public {
        _safes();
        _grantRefundRole(keccak256("ROLE_PAUSE_GUARDIAN"), address(safe));
        _grantRefundRole(keccak256("ROLE_UNPAUSE"), address(other));
        refundSale.transferOwnership(address(safe));
        uint256 next = refundSale.nextSaleNonce();
        _exec(
            safe,
            address(refundSale),
            0,
            abi.encodeCall(IStreamNativeRefundWindowSale.registerRefundSale, (_refundConfig()))
        );
        require(refundSale.nextSaleNonce() == next + 1, "Safe owner registered an inert sale");
        _exec(
            safe,
            address(refundSale),
            0,
            abi.encodeCall(IStreamNativeRefundWindowSale.pauseAdapter, (keccak256("Safe pause")))
        );
        _reject(
            safe,
            address(refundSale),
            abi.encodeCall(IStreamNativeRefundWindowSale.unpauseAdapter, (bytes32(0))),
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundRoleNotAuthorized.selector,
                keccak256("ROLE_UNPAUSE"),
                address(safe)
            )
        );
        _exec(
            other,
            address(refundSale),
            0,
            abi.encodeCall(IStreamNativeRefundWindowSale.unpauseAdapter, (bytes32(0)))
        );
        _exec(
            safe,
            address(refundSale),
            0,
            abi.encodeCall(IStreamNativeRefundWindowSale.pauseRefundSale, (refundId, bytes32(0)))
        );
        _exec(
            other,
            address(refundSale),
            0,
            abi.encodeCall(IStreamNativeRefundWindowSale.unpauseRefundSale, (refundId, bytes32(0)))
        );
        bytes32 id = _purchase(1, 1100);
        _exec(
            other,
            address(refundSale),
            0,
            abi.encodeCall(IStreamNativeRefundWindowSale.synchronizePurchaseWindow, (id))
        );
        uint64 escape = refundSale.refundPurchaseRecord(id).authorization.absoluteEscapeDeadline;
        vm.warp(escape + 1);
        _exec(
            other,
            address(refundSale),
            0,
            abi.encodeCall(IStreamNativeRefundWindowSale.unlockRefund, (id, uint8(0)))
        );
        require(
            refundSale.refundCredit(payer) == 1100,
            "permissionless Safe unlock preserves payer credit"
        );
        _reject(
            safe,
            address(refundSale),
            abi.encodeCall(
                IStreamGasParameterHost.raiseGasParameter,
                (keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT"), uint256(400_000))
            ),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(safe)
            )
        );
        _exec(
            safe,
            address(refundSale),
            0,
            abi.encodeCall(StreamNativeRefundWindowSale.transferOwnership, (address(other)))
        );
        _exec(
            other,
            address(refundSale),
            0,
            abi.encodeCall(StreamNativeRefundWindowSale.renounceOwnership, ())
        );
        require(
            refundSale.owner() == address(0) && refundSale.refundCredit(payer) == 1100,
            "ownership changes cannot erase buyer liabilities"
        );
    }

    function testActualSafeAllPublicReadsAndActivePhaseRejection() public {
        _safes();
        bytes32 id = _purchase(1, 1100);
        string[30] memory getters = [
            "FAILURE_CLASS_FAIL_CLOSED_PRECHECK()",
            "FAILURE_CLASS_FORWARDING_CAP()",
            "FAILURE_CLASS_MIN_GAS_GATE()",
            "FAILURE_CLASS_NONE()",
            "GAS_PARAMETER_SCHEMA_VERSION()",
            "artistRegistry()",
            "artistRegistryCodeHash()",
            "assetPolicyRegistry()",
            "assetRegistryCodeHash()",
            "core()",
            "coreCodeHash()",
            "entropyCodeHash()",
            "entropyCoordinator()",
            "factoryCodeHash()",
            "governanceAuthority()",
            "mintManager()",
            "mintManagerCodeHash()",
            "moduleRegistry()",
            "moduleRegistryCodeHash()",
            "nextSaleNonce()",
            "owner()",
            "platformSigner()",
            "primarySaleSettlement()",
            "resolverCodeHash()",
            "revenueResolver()",
            "roleRegistry()",
            "roleRegistryCodeHash()",
            "settlementCodeHash()",
            "splitFactory()",
            "streamModuleType()"
        ];
        for (uint256 i; i < getters.length; ++i) {
            _read(abi.encodeWithSignature(getters[i]));
        }
        _read(abi.encodeWithSignature("streamModuleInterfaceId()"));
        _read(abi.encodeCall(IStreamNativeRefundWindowSale.eip712Domain, ()));
        _read(abi.encodeWithSignature("gasParameterIds()"));
        _read(abi.encodeWithSignature("totalBuyerLiabilities()"));
        _read(abi.encodeWithSignature("totalPendingDeposits()"));
        bytes32 parameter = keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT");
        _read(abi.encodeCall(IStreamGasParameterHost.gasParameter, (parameter)));
        _read(abi.encodeCall(IStreamGasParameterHost.gasParameterInfo, (parameter)));
        _read(abi.encodeCall(IStreamNativeRefundWindowSale.refundSaleRecord, (refundId)));
        _read(abi.encodeCall(IStreamNativeRefundWindowSale.refundPurchaseRecord, (id)));
        _read(abi.encodeCall(IStreamNativeRefundWindowSale.refundCredit, (payer)));
        _read(abi.encodeCall(IStreamNativeRefundWindowSale.refundableBalance, (refundId, payer)));
        _read(abi.encodeCall(IStreamNativeRefundWindowSale.nextPurchaseNonce, (refundId, payer)));
        _read(abi.encodeCall(IStreamNativeRefundWindowSale.purchaseDeadlines, (id)));
        _read(
            abi.encodeCall(
                StreamRefundWindowBook.purchaseAuthorizationUsed, (artist, bytes32(uint256(1)))
            )
        );
        _read(
            abi.encodeCall(
                IStreamNativeRefundWindowSale.refundPurchaseAuthorizationDigest,
                (refundSale.refundPurchaseRecord(id).authorization)
            )
        );
        _read(abi.encodeCall(IStreamArtistSaleFacts.saleConsentFacts, (refundId)));
        _read(abi.encodeCall(IStreamNativeSaleBinding.nativeSaleLifecycleBinding, (refundId)));
        _read(
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamNativeRefundWindowSale).interfaceId)
            )
        );
        _reject(
            safe,
            address(refundSale),
            abi.encodeCall(IStreamDeferredNativeSaleBinding.activeDeferredNativeSettlement, (id)),
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundPurchaseUnavailable.selector, id
            )
        );
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory empty;
        _reject(
            safe,
            address(recorder),
            abi.encodeCall(
                IStreamDeferredNativePrimarySaleSettlement.settleDeferredNativePrimarySaleFromAdapter,
                (empty)
            ),
            abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
        );
        require(
            refundManager.nonce() == 0 && refundSale.refundPurchaseRecord(id).status == 1,
            "all reads/rejections preserve pending state"
        );
    }

    function _read(bytes memory data) private {
        (bool ok, bytes memory ordinary) = address(refundSale).staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory actual) = address(refundSale).staticcall(data);
        require(
            ok && safeOk && ordinary.length != 0 && keccak256(actual) == keccak256(ordinary),
            "actual Safe caller read parity"
        );
        _exec(safe, address(refundSale), 0, data);
    }
}
