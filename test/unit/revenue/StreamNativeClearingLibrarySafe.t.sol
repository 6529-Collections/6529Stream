// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract StreamNativeClearingLibrarySafeTest is ClearingSaleTestBase {
    OfficialSafe private safe;
    uint256[] private keys;

    function _safe() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9993);
    }

    function _exec(address target, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(executeSafe(safe, keys, target, 0, data, 0));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++count;
        }
        require(count == 1 && safe.nonce() == nonce + 1, "Safe direct call success");
    }

    function _read(address target, bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory actual) = target.staticcall(data);
        require(
            ok && keccak256(actual) == keccak256(expected), "independent complete library result"
        );
        _exec(target, data);
    }

    function attempt(address target, bytes calldata data) external {
        require(msg.sender == address(this));
        require(executeSafe(safe, keys, target, 0, data, 0));
    }

    function _reject(address target, bytes memory data, bytes memory error) private {
        vm.prank(address(safe));
        (bool ok, bytes memory out) = target.call(data);
        require(!ok && keccak256(out) == keccak256(error), "exact library CALL rejection");
        uint256 nonce = safe.nonce();
        (ok, out) = address(this).call(abi.encodeCall(this.attempt, (target, data)));
        require(
            !ok && keccak256(out) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
                && safe.nonce() == nonce,
            "actual Safe rejected and nonce restored"
        );
    }

    function _x() private returns (StreamClearingSaleState.Context memory x) {
        x.support = StreamDutchSaleSupport.Context(
            address(core),
            IStreamMintManager(address(clearingManager)),
            resolver,
            vm.addr(PLATFORM_KEY),
            artists,
            address(artists).codehash,
            refundEntropy,
            address(refundEntropy).codehash,
            400000,
            200000
        );
        x.factory = factory;
        x.registry = address(registry);
        x.recorder = address(recorder);
        x.coreHash = address(core).codehash;
        x.registryHash = address(registry).codehash;
        x.resolverHash = address(resolver).codehash;
        x.factoryHash = address(factory).codehash;
        x.managerHash = address(clearingManager).codehash;
        x.recorderHash = address(recorder).codehash;
        x.revealCap = 200000;
    }

    function testMutableLinkedLibraryCallSelectorsRejectActualSafeAndConsumerControlSucceeds()
        external
    {
        _safe();
        StreamClearingSaleState.Context memory x = _x();
        _read(
            address(StreamClearingUnlock),
            abi.encodeWithSelector(
                StreamClearingUnlock.requireRecorderNotIncident.selector,
                address(registry),
                address(recorder)
            ),
            ""
        );
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        StreamClearingSaleBook.PurchaseInput memory input = StreamClearingSaleBook.PurchaseInput(
            clearingId, bytes32(uint256(1)), payer, 1, 1000, 1000, false, 0, 0
        );
        _reject(
            address(StreamClearingSaleExecution),
            abi.encodeWithSelector(StreamClearingSaleExecution.purchase.selector, uint256(0), x, d),
            ""
        );
        _reject(
            address(StreamClearingSaleExecution),
            abi.encodeWithSelector(
                StreamClearingSaleExecution.registerClearingSale.selector,
                uint256(0),
                x,
                _clearingConfig(),
                uint256(2)
            ),
            ""
        );
        _reject(
            address(StreamClearingSaleExecution),
            abi.encodeWithSelector(
                StreamClearingSaleExecution.settlePurchaseSupplement.selector,
                uint256(0),
                x,
                bytes32(uint256(1))
            ),
            ""
        );
        _reject(
            address(StreamClearingSaleExecution),
            abi.encodeWithSelector(
                StreamClearingSaleExecution.claimRefund.selector, uint256(0), clearingId, payer
            ),
            ""
        );
        _reject(
            address(StreamClearingSaleExecution),
            abi.encodeWithSelector(
                StreamClearingSaleExecution.announceRebate.selector, uint256(0), clearingId, payer
            ),
            ""
        );
        _reject(
            address(StreamClearingSaleBook),
            abi.encodeWithSelector(
                StreamClearingSaleBook.configure.selector,
                uint256(0),
                clearingId,
                uint96(1000),
                uint96(100),
                uint64(10)
            ),
            ""
        );
        _reject(
            address(StreamClearingSaleBook),
            abi.encodeWithSelector(StreamClearingSaleBook.record.selector, uint256(0), input),
            ""
        );
        _reject(
            address(StreamClearingSaleBook),
            abi.encodeWithSelector(
                StreamClearingSaleBook.fixPrice.selector, uint256(0), clearingId, uint256(640)
            ),
            ""
        );
        _reject(
            address(StreamClearingSaleBook),
            abi.encodeWithSelector(
                StreamClearingSaleBook.beginSupplement.selector, uint256(0), bytes32(uint256(1))
            ),
            ""
        );
        _reject(
            address(StreamClearingSaleBook),
            abi.encodeWithSelector(
                StreamClearingSaleBook.finishSupplement.selector, uint256(0), bytes32(uint256(1))
            ),
            ""
        );
        _reject(
            address(StreamClearingSaleBook),
            abi.encodeWithSelector(StreamClearingSaleBook.unlock.selector, uint256(0), clearingId),
            ""
        );
        _reject(
            address(StreamClearingSaleBook),
            abi.encodeWithSelector(
                StreamClearingSaleBook.debitClaim.selector,
                uint256(0),
                clearingId,
                payer,
                uint256(1)
            ),
            ""
        );
        _reject(
            address(StreamClearingSaleBook),
            abi.encodeWithSelector(
                StreamClearingSaleBook.announceRebate.selector, uint256(0), clearingId, payer
            ),
            ""
        );
        _reject(
            address(StreamClearingClock),
            abi.encodeWithSelector(StreamClearingClock.setGlobal.selector, uint256(0), true),
            ""
        );
        _reject(
            address(StreamClearingClock),
            abi.encodeWithSelector(
                StreamClearingClock.setLocal.selector, uint256(0), clearingId, true
            ),
            ""
        );
        _reject(
            address(StreamClearingSaleState),
            abi.encodeWithSelector(
                StreamClearingSaleState.freezeTerminalClock.selector, uint256(0), clearingId
            ),
            ""
        );
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c;
        _reject(
            address(StreamClearingSaleSupport),
            abi.encodeWithSelector(
                StreamClearingSaleSupport.settleSupplement.selector, address(recorder), c
            ),
            ""
        );
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1020 }(d);
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        _exec(address(clearingSale), abi.encodeCall(clearingSale.fixClearingPrice, (clearingId)));
        _exec(
            address(clearingSale),
            abi.encodeCall(clearingSale.settlePurchaseSupplement, (p.purchaseId))
        );
        require(
            wallet.balance == 640 && clearingManager.nonce() == 1
                && clearingSale.refundableBalance(clearingId, payer) == 360,
            "actual guarded linked purchase/financial control"
        );
    }

    function testNineSupplementalReadSelectorsHaveDirectSafeResultOrExactContextRejection()
        external
    {
        _safe();
        IStreamNativeClearingSale.ClearingPurchaseResult memory p = _buy(1, 1020);
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        StreamPrimarySettlementRights.Context memory rights = StreamPrimarySettlementRights.Context(
            resolver, factory, factory.splitWalletRuntimeCodeHash()
        );
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c;
        c.originalFloor = clearingSale.purchaseRecord(p.purchaseId).originalFloor;
        c.purchaseId = p.purchaseId;
        c.executor = address(safe);
        c.purchase = clearingSale.clearingPurchaseFacts(p.purchaseId);
        (c.currentRights, c.currentPrimaryPolicyHash) =
            StreamClearingSaleSupport.currentSupplementalRights(rights, 1, p.tokenId);
        StreamSaleTemplate.Selection memory selected = StreamSaleTemplate.Selection(
            c.currentRights.profileId,
            c.currentRights.wallet,
            c.currentRights.templateId,
            c.currentRights.assignmentHash,
            c.currentRights.entriesHash
        );
        _read(
            address(StreamNativeSupplementalRights),
            abi.encodeWithSelector(
                StreamNativeSupplementalRights.resolve.selector,
                rights,
                uint256(1),
                p.tokenId,
                c.currentRights,
                c.currentPrimaryPolicyHash
            ),
            abi.encode(selected)
        );
        _read(
            address(StreamNativeSupplementalRights),
            abi.encodeWithSelector(
                StreamNativeSupplementalRights.requireCurrent.selector,
                rights,
                uint256(1),
                p.tokenId,
                selected
            ),
            ""
        );
        StreamDeferredNativeSettlementValidation.Bindings memory b =
            StreamDeferredNativeSettlementValidation.Bindings(
                address(core), address(registry), address(resolver), address(escrow)
            );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory floor =
            recorder.settlementResult(p.settlementKey);
        _reject(
            address(StreamNativeSupplementalValidation),
            abi.encodeWithSelector(
                StreamNativeSupplementalValidation.validate.selector, b, c, floor
            ),
            abi.encodeWithSelector(
                    IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement.selector
                )
        );
        _reject(
            address(StreamNativeSupplementalValidation),
            abi.encodeWithSelector(
                StreamNativeSupplementalValidation.requireCurrent.selector, b, c
            ),
            abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
        );
        StreamPrimarySettlementValidation.Bindings memory base =
            StreamPrimarySettlementValidation.Bindings(
                address(core), address(registry), address(resolver), address(escrow)
            );
        _reject(
            address(StreamPrimarySettlementValidation),
            abi.encodeWithSelector(
                StreamPrimarySettlementValidation.nativeFields.selector, base, c.originalFloor
            ),
            abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
        );
        _reject(
            address(StreamPrimarySettlementValidation),
            abi.encodeWithSelector(
                StreamPrimarySettlementValidation.nativeBindings.selector, base, c.originalFloor
            ),
            abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
        );
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory token;
        _reject(
            address(StreamPrimarySettlementValidation),
            abi.encodeWithSelector(
                StreamPrimarySettlementValidation.erc20Fields.selector,
                base,
                address(clearingSale),
                token
            ),
            abi.encodeWithSelector(IStreamPrimarySaleSettlement.InvalidPrimarySale.selector)
        );
        _reject(
            address(StreamPrimarySettlementValidation),
            abi.encodeWithSelector(
                StreamPrimarySettlementValidation.erc20Bindings.selector,
                base,
                address(clearingSale),
                token
            ),
            abi.encodeWithSelector(
                IStreamPrimarySaleSettlement.PrimarySettlementPaymentBindingInvalid.selector,
                address(clearingSale)
            )
        );
        _exec(
            address(clearingSale),
            abi.encodeCall(clearingSale.settlePurchaseSupplement, (p.purchaseId))
        );
        // Return the stored result through the terminal consumer view of the same completed call.
        StreamNativeSupplementalTypes.NativeSupplementalResult memory result =
            clearingSale.settlePurchaseSupplement(p.purchaseId);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory expected =
            StreamPrimarySettlementTypes.PrimarySettlementResult(
                result.candidateCommitment,
                result.settlementKey,
                result.profileId,
                result.wallet,
                address(0),
                result.amount,
                result.executor,
                result.executionId,
                result.escrowed,
                result.originalOperationRoot,
                c.originalFloor.currentPolicyHash,
                c.originalFloor.boundPolicyHash
            );
        _read(
            address(StreamNativeSupplementalExecution),
            abi.encodeWithSelector(
                StreamNativeSupplementalExecution.commonResult.selector, c, result
            ),
            abi.encode(expected)
        );
        require(
            wallet.balance == 640 && clearingManager.nonce() == 1,
            "Safe delegatecall success is separate from direct preparation authority"
        );
    }

    function testNewLibraryReadSelectorsUseExplicitEmptyLibraryStorageOrActualImmutableFacts()
        external
    {
        _safe();
        StreamClearingSaleState.Context memory x = _x();
        _read(
            address(StreamClearingClock),
            abi.encodeWithSelector(StreamClearingClock.now64.selector),
            abi.encode(uint64(1000))
        );
        _read(
            address(StreamClearingClock),
            abi.encodeWithSelector(StreamClearingClock.globalPaused.selector, uint256(0)),
            abi.encode(false)
        );
        _read(
            address(StreamClearingClock),
            abi.encodeWithSelector(
                StreamClearingClock.localPaused.selector, uint256(0), clearingId
            ),
            abi.encode(false)
        );
        _read(
            address(StreamClearingClock),
            abi.encodeWithSelector(
                StreamClearingClock.globalTotalAt.selector, uint256(0), uint64(1000)
            ),
            abi.encode(uint64(0))
        );
        _read(
            address(StreamClearingClock),
            abi.encodeWithSelector(
                StreamClearingClock.unionTotalAt.selector, uint256(0), clearingId, uint64(1000)
            ),
            abi.encode(uint64(0))
        );
        _read(
            address(StreamClearingClock),
            abi.encodeWithSelector(
                StreamClearingClock.tollSince.selector, uint256(0), clearingId, uint64(1000)
            ),
            abi.encode(uint64(0))
        );
        _read(
            address(StreamClearingSaleState),
            abi.encodeWithSelector(
                StreamClearingSaleState.isPaused.selector, uint256(0), clearingId
            ),
            abi.encode(false)
        );
        _reject(
            address(StreamClearingSaleState),
            abi.encodeWithSelector(
                StreamClearingSaleState.deadlines.selector, uint256(0), clearingId
            ),
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingSaleUnavailable.selector, clearingId
            )
        );
        _reject(
            address(StreamClearingSaleState),
            abi.encodeWithSelector(
                StreamClearingSaleState.purchaseFacts.selector, uint256(0), bytes32(uint256(1))
            ),
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingPurchaseUnavailable.selector, bytes32(uint256(1))
            )
        );
        _read(
            address(StreamClearingSaleBook),
            abi.encodeWithSelector(
                StreamClearingSaleBook.refundableBalance.selector, uint256(0), clearingId, payer
            ),
            abi.encode(uint256(0))
        );
        _reject(
            address(StreamClearingSaleBook),
            abi.encodeWithSelector(
                StreamClearingSaleBook.uniformPrice.selector, uint256(0), bytes32(uint256(1))
            ),
            abi.encodeWithSelector(
                StreamClearingSaleBook.ClearingBookPurchaseUnavailable.selector, bytes32(uint256(1))
            )
        );
        IStreamNativeClearingSale.ClearingSaleRecord memory sale =
            clearingSale.saleRecord(clearingId);
        _read(
            address(StreamClearingSaleSupport),
            abi.encodeWithSelector(
                StreamClearingSaleSupport.windowPolicyHash.selector, sale.config
            ),
            abi.encode(sale.windowPolicyHash)
        );
        _read(
            address(StreamClearingSaleSupport),
            abi.encodeWithSelector(
                StreamClearingSaleSupport.validateConfig.selector, x.support, sale.config
            ),
            abi.encode(sale.expectedPrimaryPolicyHash)
        );
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeClearingSale"),
                keccak256("1"),
                block.chainid,
                address(StreamClearingSaleSupport)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "ClearingAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 purchaseNonce,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice,bool hasPriceOverride,uint256 priceOverride,bytes32 windowPolicyHash,uint64 maximumNominalFinalizeBy,uint64 absoluteEscapeDeadline)"
                ),
                d.authorization
            )
        );
        bytes32 libraryDigest = keccak256(abi.encodePacked(hex"1901", domain, body));
        _read(
            address(StreamClearingSaleSupport),
            abi.encodeWithSelector(
                StreamClearingSaleSupport.authorizationDigest.selector, d.authorization
            ),
            abi.encode(libraryDigest)
        );
        require(
            libraryDigest != clearingSale.authorizationDigest(d.authorization),
            "direct library context is not consumer authorization"
        );
        _reject(
            address(StreamClearingSaleSupport),
            abi.encodeWithSelector(
                StreamClearingSaleSupport.prepare.selector,
                x.support,
                sale,
                clearingSale.financialSale(clearingId),
                d
            ),
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingSignatureInvalid.selector, vm.addr(PLATFORM_KEY)
            )
        );
        _read(
            address(StreamClearingUnlock),
            abi.encodeWithSelector(
                StreamClearingUnlock.reasonHash.selector,
                x.support,
                address(registry),
                address(registry).codehash,
                address(recorder),
                sale,
                uint8(0)
            ),
            abi.encode(bytes32(0))
        );
        IStreamNativeClearingSale.ClearingPurchaseResult memory p = _buy(1, 1020);
        StreamSaleTemplate.Selection memory selected =
            StreamNativeSettlementSupport.rights(resolver, 1);
        StreamPrimarySettlementTypes.PrimaryRights memory rights =
            StreamPrimarySettlementTypes.PrimaryRights(
                selected.profileId,
                selected.wallet,
                selected.templateId,
                selected.assignmentHash,
                selected.entriesHash
            );
        bytes32 policyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                CLASS,
                uint256(1),
                p.tokenId,
                selected.templateId,
                selected.profileId,
                selected.wallet,
                selected.assignmentHash
            )
        );
        _read(
            address(StreamClearingSaleSupport),
            abi.encodeWithSelector(
                StreamClearingSaleSupport.currentSupplementalRights.selector,
                StreamPrimarySettlementRights.Context(
                    resolver, factory, factory.splitWalletRuntimeCodeHash()
                ),
                uint256(1),
                p.tokenId
            ),
            abi.encode(rights, policyHash)
        );
        require(
            wallet.balance == 100 && clearingManager.nonce() == 1,
            "direct read controls do not mutate consumer"
        );
    }
}
