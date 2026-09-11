// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/UniversalSettlementTestBase.sol";

contract StreamUniversalSettlementTest is UniversalSettlementTestBase {
    function testRealGraphDirectMoneyAndExactContextEvent() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, address(0xBEEF), 1);
        token.mint(address(payment), 17);
        token.mint(address(recorder), 23);
        vm.recordLogs();
        vm.prank(payer);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        require(
            token.balanceOf(payer) == 9000 && token.balanceOf(wallet) == 1000,
            "actual payer and wallet"
        );
        require(
            token.balanceOf(address(payment)) == 17 && token.balanceOf(address(recorder)) == 23,
            "passive surplus preserved"
        );
        require(
            manager.ownerOf(1) == address(0xBEEF)
                && sale.executionStatus(c.executionBinding.executionId) == 2,
            "mint and execution complete"
        );
        require(
            recorder.totalOfficialSettled(address(token)) == 1000
                && recorder.officialSettled(CLASS, profile, wallet, address(token)) == 1000,
            "official exact once"
        );
        require(!r.escrowed && recorder.settlementConsumed(r.settlementKey), "direct recorded");
        _contextLog(vm.getRecordedLogs(), c, r);
        IStreamSplitWallet(wallet).release(address(token), artist, payable(artist));
        require(token.balanceOf(artist) == 1000, "real split release");
    }

    function _contextLog(
        Vm.Log[] memory logs,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r
    ) private view {
        bytes32 topic = keccak256(
            "PrimaryRevenueSettlementContext(bytes32,bytes32,bytes32,uint16,address,bytes32,uint8,uint256,uint256,bytes32,bytes32,uint256,address,address,bytes32)"
        );
        bytes memory expected = abi.encode(
            uint16(1),
            address(sale),
            saleId,
            uint8(0),
            uint256(1),
            uint256(0),
            c.operationIdentityCommitment,
            c.operationId,
            uint256(1),
            address(0),
            c.sale.beneficiary,
            bytes32(0)
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(recorder) || logs[i].topics[0] != topic) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == r.settlementKey
                    && logs[i].topics[2] == CLASS && logs[i].topics[3] == profile,
                "exact context topics"
            );
            require(
                keccak256(logs[i].data) == keccak256(expected), "independent twelve word context"
            );
            ++count;
        }
        require(count == 1, "one canonical context");
        _event(
            logs,
            keccak256(
                "PrimaryRevenueSettled(bytes32,bytes32,bytes32,uint16,address,address,address,uint256,bytes32,bool,uint8)"
            ),
            r.settlementKey,
            CLASS,
            profile,
            abi.encode(
                uint16(1),
                wallet,
                address(token),
                payer,
                uint256(1000),
                keccak256(abi.encode(c.sale)),
                false,
                uint8(1)
            )
        );
        _event(
            logs,
            keccak256(
                "PrimaryRevenueSettlementPolicy(bytes32,bytes32,bytes32,uint16,bytes32,bytes32,bytes32,bytes32)"
            ),
            r.settlementKey,
            CLASS,
            profile,
            abi.encode(
                uint16(1),
                c.sale.expectedPrimaryPolicyHash,
                c.sale.expectedPrimaryPolicyHash,
                c.rights.assignmentHash,
                bytes32(0)
            )
        );
        _event(
            logs,
            keccak256(
                "PrimaryRevenueExecutionBound(bytes32,address,bytes32,uint16,address,address,bytes32,bytes32,bytes32)"
            ),
            r.settlementKey,
            bytes32(uint256(uint160(address(sale)))),
            c.executionBinding.executionId,
            abi.encode(
                uint16(1),
                payer,
                address(payment),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2"),
                        block.chainid,
                        address(payment),
                        address(recorder),
                        c
                    )
                ),
                c.currentPolicyHash,
                c.boundPolicyHash
            )
        );
    }

    function _event(
        Vm.Log[] memory logs,
        bytes32 signature,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes memory data
    ) private view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(recorder) || logs[i].topics[0] != signature) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == a && logs[i].topics[2] == b
                    && logs[i].topics[3] == c,
                "exact official event topics"
            );
            require(
                keccak256(logs[i].data) == keccak256(data),
                "independent exact official event payload"
            );
            ++count;
        }
        require(count == 1, "one event per official transition");
    }

    function testRevertedWalletFrameUsesExactEscrowAndFlush() public {
        token.configure(wallet, 1);
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        vm.prank(payer);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r =
            payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        require(
            r.escrowed && token.balanceOf(wallet) == 0
                && escrow.escrowOwed(CLASS, profile, wallet, address(token)) == 1000,
            "failed frame becomes exact owed"
        );
        require(
            token.allowance(address(recorder), address(escrow)) == 0
                && token.balanceOf(address(escrow)) == 1000,
            "producer approval consumed and cleared"
        );
        token.configure(address(0), 0);
        escrow.flushEscrow(CLASS, profile, wallet, address(token));
        IStreamSplitWallet(wallet).release(address(token), artist, payable(artist));
        require(
            token.balanceOf(artist) == 1000 && escrow.totalOwed(address(token)) == 0,
            "exact eventual payout"
        );
    }

    function testFuzzSuccessfulInvalidWalletResponseAlwaysRollsBack(uint8 value) public {
        uint8 fault = uint8(2 + value % 5);
        token.configure(wallet, fault);
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        _failedPayer(e, c);
        _unspent(c);
    }

    function testLateMintFailureRollsBackDirectAndEscrowAndRetriesExactBytes() public {
        for (uint256 i; i < 2; ++i) {
            token.configure(wallet, uint8(i));
            (
                IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
                StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
            ) = _execution(payer, payer, payer, i + 1);
            uint256 beforePayer = token.balanceOf(payer);
            manager.configure(1);
            _failedPayer(e, c);
            require(
                token.balanceOf(payer) == beforePayer
                    && !recorder.settlementConsumed(
                        recorder.settlementKey(address(sale), c.executionBinding.executionId)
                    ),
                "late failure rolls back payment"
            );
            manager.configure(0);
            vm.prank(payer);
            payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        }
        require(
            token.balanceOf(payer) == 8000 && recorder.totalOfficialSettled(address(token)) == 2000,
            "both exact retries succeed"
        );
    }

    function testRelayerIntentExactDomainAndReplayRollback() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, address(this), payer, 1);
        StreamPrimarySettlementTypes.PaymentIntent memory intent =
            StreamPrimarySettlementTypes.PaymentIntent(
                payer,
                address(token),
                1000,
                saleId,
                _primaryPolicy(),
                keccak256("intent"),
                uint64(block.timestamp + 1 hours)
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
        bytes32 digest = keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "StreamPaymentIntent(address payer,address asset,uint256 maxAmount,bytes32 saleRef,bytes32 expectedPrimaryPolicyHash,bytes32 nonce,uint64 deadline)"
                        ),
                        intent
                    )
                )
            )
        );
        require(digest == payment.paymentIntentDigest(intent), "independent actual puller domain");
        bytes memory sig = _sign(PAYER_KEY, digest);
        manager.configure(1);
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithIntent,
                    (c, intent, sig, abi.encode(e))
                )
            );
        require(
            !ok && !payment.isPaymentIntentNonceUsed(payer, intent.nonce),
            "late failure restores intent"
        );
        _unspent(c);
        manager.configure(0);
        payment.settleERC20PrimarySaleWithIntent(c, intent, sig, abi.encode(e));
        require(
            payment.isPaymentIntentNonceUsed(payer, intent.nonce) && token.balanceOf(payer) == 9000,
            "relayed exact amount"
        );
        (ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleWithIntent,
                    (c, intent, sig, abi.encode(e))
                )
            );
        require(!ok && token.balanceOf(payer) == 9000, "replay cannot pay twice");
    }

    function testSameAuthenticatedExecutionNonceWithNewCommercialContextRejects() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        bytes32 firstId = sale.executionIdByNonce(saleId, 1);
        e.authorization.nonce = keccak256("different valid commercial nonce");
        e.authorization.recipient = address(0xABCD);
        bytes32 digest = sale.authorizationDigest(e.authorization);
        e.platformSignature = _sign(PLATFORM_KEY, digest);
        e.artistSignature = _sign(ARTIST_KEY, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamUniversalFixedPriceSaleAdapter.UniversalExecutionUsed.selector,
                saleId,
                uint256(1)
            )
        );
        sale.previewExecution(e);
        require(
            firstId == c.executionBinding.executionId && token.balanceOf(payer) == 9000
                && !sale.authorizationUsed(artist, e.authorization.nonce),
            "immutable lane survives new valid consent"
        );
    }

    function testBothModulesDeprecatedGrandfatherExistingSaleButIncidentRevokedRejects() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        vm.warp(block.timestamp + 1);
        _status(address(sale), ModuleRegistryStatus.DEPRECATED);
        _status(address(payment), ModuleRegistryStatus.DEPRECATED);
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        (e, c) = _execution(payer, payer, payer, 2);
        _status(address(payment), ModuleRegistryStatus.INCIDENT_REVOKED);
        _failedPayer(e, c);
        require(token.balanceOf(payer) == 9000, "incident stops additional payments");
    }

    function testSameTimestampDeprecationCannotGrandfatherSale() public {
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        _status(address(sale), ModuleRegistryStatus.DEPRECATED);
        _failedPayer(e, c);
        _unspent(c);
    }

    function testTokenCallbackCannotReenterFundingOrRevoke() public {
        token.setCallback(
            address(payment),
            abi.encodeCall(
                IStreamERC20PrimarySettlementAdapter.revokePaymentIntent, (bytes32(uint256(99)))
            )
        );
        (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        ) = _execution(payer, payer, payer, 1);
        vm.prank(payer);
        payment.settleERC20PrimarySaleByPayer(c, abi.encode(e));
        require(
            !token.callbackSuccess()
                && token.callbackResultHash()
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamERC20PrimarySettlementAdapter.PaymentOperationActive.selector
                        )
                    ),
            "callback sees locked phase"
        );
        require(
            !payment.isPaymentIntentNonceUsed(address(token), bytes32(uint256(99))),
            "callback cannot mutate revocations"
        );
    }

    function _failedPayer(
        IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) internal {
        vm.prank(payer);
        (bool ok,) = address(payment)
            .call(
                abi.encodeCall(
                    IStreamERC20PrimarySettlementAdapter.settleERC20PrimarySaleByPayer,
                    (c, abi.encode(e))
                )
            );
        require(!ok, "expected complete sale failure");
    }

    function _unspent(StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
        internal
        view
    {
        require(
            token.balanceOf(payer) == 10_000 && token.balanceOf(wallet) == 0
                && token.balanceOf(address(payment)) == 0 && token.balanceOf(address(recorder)) == 0
                && token.balanceOf(address(escrow)) == 0,
            "all balances rolled back"
        );
        require(
            token.allowance(payer, address(payment)) == 10_000
                && escrow.totalOwed(address(token)) == 0
                && recorder.totalOfficialSettled(address(token)) == 0 && manager.nonce() == 0,
            "allowance accounting and mint rolled back"
        );
        require(
            !sale.authorizationUsed(artist, bytes32(uint256(1)))
                && sale.executionIdByNonce(saleId, 1) == 0
                && !recorder.settlementConsumed(
                    recorder.settlementKey(address(sale), c.executionBinding.executionId)
                ) && payment.phase() == StreamERC20PrimarySettlementAdapter.Phase.IDLE,
            "all latches rolled back"
        );
    }
}
