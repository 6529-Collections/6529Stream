// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract StreamNativeClearingSelectorsTest is ClearingSaleTestBase {
    OfficialSafe private safe;
    uint256[] private keys;

    function _safe() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9991);
    }

    function _exec(OfficialSafe account, address target, bytes memory data) private {
        uint256 nonce = account.nonce();
        vm.recordLogs();
        require(executeSafe(account, keys, target, 0, data, 0), "Safe success");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(account)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++count;
        }
        require(count == 1 && account.nonce() == nonce + 1, "actual Safe success and nonce");
    }

    function _read(address target, bytes memory data) private {
        (bool ok, bytes memory ordinary) = target.staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory actual) = target.staticcall(data);
        require(ok && safeOk && keccak256(ordinary) == keccak256(actual), "exact Safe read parity");
        _exec(safe, target, data);
    }

    function attempt(address target, bytes calldata data) external {
        require(msg.sender == address(this));
        require(executeSafe(safe, keys, target, 0, data, 0));
    }

    function _reject(address target, bytes memory data, bytes memory error) private {
        vm.prank(address(safe));
        (bool ok, bytes memory actual) = target.call(data);
        require(!ok && keccak256(actual) == keccak256(error), "exact target reason");
        uint256 nonce = safe.nonce();
        (ok, actual) = address(this).call(abi.encodeCall(this.attempt, (target, data)));
        require(
            !ok && keccak256(actual) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && safe.nonce() == nonce,
            "Safe failure/nonce rollback"
        );
    }

    function testEveryConsumerReadUsesActualSafeAndDeferredRecorderResidualsStayRejected()
        external
    {
        _safe();
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1020 }(d);
        string[35] memory names = [
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
            "eip712Domain()",
            "entropyCodeHash()",
            "entropyCoordinator()",
            "factoryCodeHash()",
            "gasParameterIds()",
            "governanceAuthority()",
            "mintManager()",
            "mintManagerCodeHash()",
            "moduleRegistry()",
            "moduleRegistryCodeHash()",
            "nextSaleNonce()",
            "owner()",
            "paused()",
            "platformSigner()",
            "primarySaleSettlement()",
            "resolverCodeHash()",
            "revenueResolver()",
            "roleRegistry()",
            "roleRegistryCodeHash()",
            "settlementCodeHash()",
            "splitFactory()",
            "streamModuleInterfaceId()",
            "streamModuleType()",
            "totalBuyerLiabilities()"
        ];
        for (uint256 i; i < names.length; ++i) {
            _read(address(clearingSale), abi.encodeWithSignature(names[i]));
        }
        _read(
            address(clearingSale),
            abi.encodeCall(clearingSale.authorizationDigest, (d.authorization))
        );
        _read(
            address(clearingSale),
            abi.encodeCall(clearingSale.authorizationUsed, (artist, bytes32(uint256(1))))
        );
        _read(
            address(clearingSale),
            abi.encodeCall(clearingSale.executionIdByNonce, (clearingId, uint256(1)))
        );
        _read(address(clearingSale), abi.encodeCall(clearingSale.executionStatus, (p.executionId)));
        _read(address(clearingSale), abi.encodeCall(clearingSale.currentPrice, (clearingId)));
        _read(address(clearingSale), abi.encodeCall(clearingSale.financialSale, (clearingId)));
        _read(address(clearingSale), abi.encodeCall(clearingSale.saleRecord, (clearingId)));
        _read(address(clearingSale), abi.encodeCall(clearingSale.purchaseRecord, (p.purchaseId)));
        _read(address(clearingSale), abi.encodeCall(clearingSale.salePaused, (clearingId)));
        _read(address(clearingSale), abi.encodeCall(clearingSale.saleDeadlines, (clearingId)));
        _read(address(clearingSale), abi.encodeCall(clearingSale.saleConsentFacts, (clearingId)));
        _read(
            address(clearingSale),
            abi.encodeCall(clearingSale.nativeSaleLifecycleBinding, (clearingId))
        );
        _read(
            address(clearingSale),
            abi.encodeCall(clearingSale.nextPurchaseNonce, (clearingId, payer))
        );
        _read(
            address(clearingSale),
            abi.encodeCall(clearingSale.refundableBalance, (clearingId, payer))
        );
        _read(
            address(clearingSale),
            abi.encodeCall(clearingSale.saleIdFor, (uint256(1), PHASE, uint256(1)))
        );
        _read(
            address(clearingSale),
            abi.encodeCall(clearingSale.purchaseIdFor, (clearingId, payer, uint256(1)))
        );
        _read(
            address(clearingSale),
            abi.encodeCall(clearingSale.clearingPurchaseFacts, (p.purchaseId))
        );
        _read(
            address(clearingSale),
            abi.encodeCall(clearingSale.activeNativeSupplementalSettlement, (p.purchaseId))
        );
        bytes32 cap = keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
        _read(address(clearingSale), abi.encodeCall(IStreamGasParameterHost.gasParameter, (cap)));
        _read(
            address(clearingSale), abi.encodeCall(IStreamGasParameterHost.gasParameterInfo, (cap))
        );
        _read(
            address(clearingSale),
            abi.encodeCall(IERC165.supportsInterface, (type(IStreamNativeClearingSale).interfaceId))
        );
        bytes32 key = recorder.deferredPurchaseKey(address(clearingSale), p.purchaseId);
        _read(
            address(recorder),
            abi.encodeCall(recorder.deferredPurchaseKey, (address(clearingSale), p.purchaseId))
        );
        _read(address(recorder), abi.encodeCall(recorder.deferredPurchaseConsumed, (key)));
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory empty;
        _reject(
            address(recorder),
            abi.encodeCall(
                IStreamDeferredNativePrimarySaleSettlement.settleDeferredNativePrimarySaleFromAdapter,
                (empty)
            ),
            abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
        );
        require(
            !recorder.deferredPurchaseConsumed(key) && clearingManager.nonce() == 1
                && wallet.balance == 100,
            "all reads/direct protocol rejection preserve floor"
        );
    }

    function testCorrectSafeOwnerGuardianSeparateUnpauserAndPermissionlessTerminalPaths() external {
        _safe();
        bytes32 cap = keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
        _reject(
            address(clearingSale),
            abi.encodeCall(clearingSale.closeSale, (clearingId)),
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        _reject(
            address(clearingSale),
            abi.encodeCall(clearingSale.pauseAdapter, (bytes32(uint256(1)))),
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchRoleNotAuthorized.selector,
                keccak256("ROLE_PAUSE_GUARDIAN"),
                address(safe)
            )
        );
        _reject(
            address(clearingSale),
            abi.encodeCall(IStreamGasParameterHost.raiseGasParameter, (cap, uint256(400000))),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(safe)
            )
        );
        OfficialSafe resume =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9992);
        _grantRefundRole(keccak256("ROLE_PAUSE_GUARDIAN"), address(safe));
        _grantRefundRole(keccak256("ROLE_UNPAUSE"), address(resume));
        _exec(
            safe,
            address(clearingSale),
            abi.encodeCall(clearingSale.pauseAdapter, (bytes32(uint256(1))))
        );
        _reject(
            address(clearingSale),
            abi.encodeCall(clearingSale.unpauseAdapter, (bytes32(uint256(2)))),
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchRoleNotAuthorized.selector,
                keccak256("ROLE_UNPAUSE"),
                address(safe)
            )
        );
        _exec(
            resume,
            address(clearingSale),
            abi.encodeCall(clearingSale.unpauseAdapter, (bytes32(uint256(2))))
        );
        _exec(
            safe,
            address(clearingSale),
            abi.encodeCall(clearingSale.pauseSale, (clearingId, bytes32(uint256(3))))
        );
        _exec(
            resume,
            address(clearingSale),
            abi.encodeCall(clearingSale.unpauseSale, (clearingId, bytes32(uint256(4))))
        );
        clearingSale.transferOwnership(address(safe));
        address signer = vm.addr(keys[0]);
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        vm.prank(signer);
        clearingSale.closeSale(clearingId);
        _exec(
            safe,
            address(clearingSale),
            abi.encodeCall(clearingSale.registerClearingSale, (_clearingConfig()))
        );
        _buy(1, 1020);
        _exec(safe, address(clearingSale), abi.encodeCall(clearingSale.closeSale, (clearingId)));
        vm.warp(1501);
        _exec(
            safe,
            address(clearingSale),
            abi.encodeCall(clearingSale.unlockRefunds, (clearingId, uint8(0)))
        );
        require(
            clearingSale.refundableBalance(clearingId, payer) == 900, "permissionless Safe escape"
        );
        _exec(
            safe,
            address(clearingSale),
            abi.encodeCall(clearingSale.transferOwnership, (address(this)))
        );
        clearingSale.transferOwnership(address(safe));
        _exec(safe, address(clearingSale), abi.encodeCall(clearingSale.renounceOwnership, ()));
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(
            clearingSale.owner() == address(0) && clearingSale.totalBuyerLiabilities() == 0,
            "ownership cannot erase credit"
        );
    }
}
