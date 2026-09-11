// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/NativeSettlementTestBase.sol";

contract NativeReentryObserver {
    bytes public reason;
    bool public succeeded;

    function attempt(address target, bytes calldata data) external {
        (succeeded, reason) = target.call(data);
    }
}

contract StreamNativeSettlementTest is NativeSettlementTestBase {
    function testNativeFixedMoneyOfficialIdentityAndIndependentReplay() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        vm.deal(address(recorder), 37);
        vm.deal(address(nativeSale), 19);
        (StreamPrimarySettlementTypes.PrimarySettlementResult memory r, uint256 id) = _buy(e);
        require(
            id == 1 && manager.ownerOf(id) == payer && wallet.balance == 1000
                && payer.balance == 10 ether - 1000,
            "actual mint and native money"
        );
        require(
            address(recorder).balance == 37 && address(nativeSale).balance == 19,
            "passive surplus retained"
        );
        require(
            r.asset == address(0) && r.amount == 1000 && r.profileId == profile
                && r.wallet == wallet && !r.escrowed,
            "exact native result"
        );
        require(
            r.candidateCommitment
                    == StreamNativeSettlementHash.candidateCommitment(address(recorder), c)
                && r.operationIdentityCommitment == c.operationIdentityCommitment
                && r.executionId == c.executionBinding.executionId,
            "exact execution binding"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 1000
                && recorder.officialSettled(CLASS, profile, wallet, address(0)) == 1000
                && recorder.settlementConsumed(r.settlementKey),
            "official native credit"
        );
        require(
            IStreamSplitWallet(wallet).release(address(0), artist, payable(artist)) == 1000
                && artist.balance == 1000,
            "real split payout"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeAuthorizationUsed.selector,
                artist,
                bytes32(uint256(1))
            )
        );
        nativeSale.previewExecution(e);
        e.authorization.nonce = bytes32(uint256(999));
        _nativeSign(e);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeExecutionUsed.selector,
                nativeId,
                uint256(1)
            )
        );
        nativeSale.previewExecution(e);
    }

    function testExactValueAndPayerRequiredNoRelayerOrOverpayment() public {
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        for (uint256 i; i < 3; ++i) {
            vm.deal(address(this), 1000);
            vm.prank(i == 2 ? address(this) : payer);
            (bool ok,) = address(nativeSale).call{ value: i == 0 ? 999 : i == 1 ? 1001 : 1000 }(
                abi.encodeCall(nativeSale.purchase, (e))
            );
            require(!ok, "wrong payer or value rejects");
            _unchanged(c, 10 ether);
        }
    }

    function testMintRootIdAndReceiverFailuresRollbackFundingAndRetry() public {
        NativeSettlementReceiver recipient = new NativeSettlementReceiver();
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, address(recipient), 1);
        for (uint256 i = 1; i <= 4; ++i) {
            manager.configure(i == 4 ? 0 : i);
            recipient.configure(i == 4, address(0), "", wallet);
            vm.prank(payer);
            (bool ok,) =
                address(nativeSale).call{ value: 1000 }(abi.encodeCall(nativeSale.purchase, (e)));
            require(!ok && wallet.balance == 0, "mint/recipient failure reverts payment");
            _unchanged(c, 10 ether);
        }
        NativeReentryObserver observer = new NativeReentryObserver();
        recipient.configure(
            false,
            address(observer),
            abi.encodeCall(
                observer.attempt, (address(nativeSale), abi.encodeCall(nativeSale.purchase, (e)))
            ),
            wallet
        );
        _buy(e);
        require(
            recipient.observedBalance() == 1000 && recipient.callbackSucceeded()
                && !observer.succeeded()
                && keccak256(observer.reason())
                    == keccak256(
                        abi.encodeWithSelector(
                            ReentrancyGuard.ReentrancyGuardReentrantCall.selector
                        )
                    ) && manager.ownerOf(1) == address(recipient),
            "funded before mint and nested call rejected"
        );
    }

    function testRevertedWalletCallEscrowsThenFlushesOriginalRights() public {
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                wallet,
                1000,
                "",
                abi.encodeWithSignature("Error(string)", "injected wallet failure")
            );
        (StreamPrimarySettlementTypes.PrimarySettlementResult memory r,) = _buy(e);
        require(
            r.escrowed && wallet.balance == 0 && address(escrow).balance == 1000,
            "fault-injected rollback routes exact owed"
        );
        SaleFundingFaultVm(address(vm)).clearMockedCalls();
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(wallet.balance == 1000 && address(escrow).balance == 0, "real wallet flush");
    }

    function testProducerRevocationOnlyBlocksNeededFallback() public {
        _producer(false);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        _buy(e);
        (e,) = _nativeExecution(payer, payer, 2);
        SaleFundingFaultVm(address(vm)).mockCallRevert(wallet, 1000, "", "");
        vm.prank(payer);
        (bool ok,) =
            address(nativeSale).call{ value: 1000 }(abi.encodeCall(nativeSale.purchase, (e)));
        require(
            !ok && wallet.balance == 1000 && manager.nonce() == 1
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "revoked fallback cannot create owed"
        );
    }

    function testNativeDoesNotDependOnTokenAssetPolicyReads() public {
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        vm.etch(address(policy), hex"60006000fd");
        _buy(e);
        require(wallet.balance == 1000, "native skips token policy runtime");
    }

    function testDeprecationGrandfathersOnlyPriorProgramAndIncidentBlocks() public {
        vm.warp(1001);
        _status(address(nativeSale), ModuleRegistryStatus.DEPRECATED);
        (IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,) =
            _nativeExecution(payer, payer, 1);
        _buy(e);
        (bool ok,) = address(nativeSale)
            .call(abi.encodeCall(nativeSale.registerSale, (nativeSale.saleRecord(nativeId).config)));
        require(!ok, "no new deprecated program");
        _status(address(nativeSale), ModuleRegistryStatus.INCIDENT_REVOKED);
        e.authorization.executionNonce = 2;
        e.authorization.nonce = bytes32(uint256(2));
        _nativeSign(e);
        vm.prank(payer);
        (ok,) = address(nativeSale).call{ value: 1000 }(abi.encodeCall(nativeSale.purchase, (e)));
        require(
            !ok && manager.nonce() == 1 && wallet.balance == 1000,
            "incident blocks retained program"
        );
    }

    function testTemplateMaterializesOnceToEscrowThenPayoutRevisionPreservesPriorWallet() public {
        _template(artist);
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, payer, 1);
        uint256 beforeCount = factory.profileCount();
        require(
            c.rights.wallet.code.length == 0 && !factory.profileExists(c.rights.profileId),
            "preview does not register"
        );
        (StreamPrimarySettlementTypes.PrimarySettlementResult memory r,) = _buy(e);
        require(
            r.escrowed && factory.profileCount() == beforeCount + 1 && r.wallet.code.length == 0
                && address(escrow).balance == 1000,
            "one registration no hidden deployment"
        );
        templateArtist.changePayout(address(0xD00D));
        escrow.flushEscrow(CLASS, r.profileId, r.wallet, address(0));
        require(
            IStreamSplitWallet(r.wallet).release(address(0), artist, payable(artist)) == 900,
            "old artist rights remain payable"
        );
        (e, c) = _nativeExecution(payer, payer, 2);
        require(
            c.rights.profileId != r.profileId && c.rights.wallet != r.wallet,
            "new designation new concrete profile"
        );
        _buy(e);
        escrow.flushEscrow(CLASS, c.rights.profileId, c.rights.wallet, address(0));
        require(
            IStreamSplitWallet(c.rights.wallet)
                .release(address(0), address(0xD00D), payable(address(0xD00D))) == 900,
            "new explicit payout"
        );
    }

    function testTemplateCallbackRetainsMaterializationMomentAndEarlierDriftRejects() public {
        _template(artist);
        NativeSettlementReceiver recipient = new NativeSettlementReceiver();
        (
            IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c
        ) = _nativeExecution(payer, address(recipient), 1);
        recipient.configure(
            false,
            address(templateArtist),
            abi.encodeCall(templateArtist.changePayout, (address(0xD00D))),
            c.rights.wallet
        );
        (StreamPrimarySettlementTypes.PrimarySettlementResult memory r,) = _buy(e);
        require(
            r.profileId == c.rights.profileId && recipient.callbackSucceeded()
                && templateArtist.payout() == address(0xD00D),
            "callback cannot redirect retained materialization"
        );
        (e, c) = _nativeExecution(payer, payer, 2);
        templateArtist.changePayout(address(0xBEEF));
        uint256 count = factory.profileCount();
        vm.prank(payer);
        (bool ok,) =
            address(nativeSale).call{ value: 1000 }(abi.encodeCall(nativeSale.purchase, (e)));
        require(
            !ok && factory.profileCount() == count && manager.nonce() == 1
                && !factory.profileExists(c.rights.profileId),
            "pre-materialization drift rejects without registration"
        );
    }
}
