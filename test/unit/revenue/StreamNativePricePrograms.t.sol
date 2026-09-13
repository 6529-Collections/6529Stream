// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/NativeSettlementTestBase.sol";

contract PriceProgramReentryObserver {
    address public target;
    bytes public data;
    bytes public reason;

    function configure(address t, bytes calldata d) external {
        target = t;
        data = d;
    }

    function probe() external {
        (bool ok, bytes memory r) = target.call(data);
        require(!ok, "reentered");
        reason = r;
    }
}

abstract contract NativePriceProgramTestBase is NativeSettlementTestBase {
    function _config(uint8 kind, uint256 minimum, uint256 maximum, uint64 limit)
        internal
        view
        returns (IStreamNativePricePrograms.PriceProgramConfig memory c)
    {
        c = IStreamNativePricePrograms.PriceProgramConfig(
            1, PHASE, kind, minimum, maximum, limit, 0, 10_000, 1, manager.POLICY(), bytes32(0)
        );
        if (kind != 12) {
            c.primaryAssignmentHash = resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash;
        }
    }

    function _program(uint8 kind, uint256 minimum, uint256 maximum, uint64 limit)
        internal
        returns (bytes32)
    {
        return nativeSale.registerPriceProgram(_config(kind, minimum, maximum, limit));
    }

    function _execution(bytes32 id, uint256 number, uint256 chosen, uint256 signedPrice)
        internal
        returns (IStreamNativePricePrograms.PriceProgramExecution memory e)
    {
        e.chosenUnitPrice = chosen;
        e.tokenData = abi.encode("price artwork", number);
        bytes32 primary;
        if (nativeSale.priceProgramRecord(id).config.kind != 12) {
            primary = StreamSaleTemplate.policyHash(
                resolver, 1, StreamNativeSettlementSupport.rights(resolver, 1)
            );
        }
        e.authorization = IStreamNativePricePrograms.PriceProgramAuthorization(
            id,
            nativeSale.priceProgramRecord(id).configHash,
            payer,
            payer,
            payer,
            artist,
            keccak256(e.tokenData),
            keccak256(abi.encode("price mint", number)),
            number,
            bytes32(number),
            uint64(block.timestamp + 1 hours),
            primary,
            signedPrice
        );
        _programSign(e);
    }

    function _programSign(IStreamNativePricePrograms.PriceProgramExecution memory e) internal {
        bytes32 digest = nativeSale.priceProgramAuthorizationDigest(e.authorization);
        e.platformSignature = _sign(PLATFORM_KEY, digest);
        e.artistSignature = _sign(ARTIST_KEY, digest);
    }

    function _execute(IStreamNativePricePrograms.PriceProgramExecution memory e)
        internal
        returns (IStreamNativePricePrograms.PriceProgramResult memory)
    {
        vm.prank(e.authorization.payer);
        return nativeSale.executePriceProgram{ value: e.chosenUnitPrice }(e);
    }
}

contract StreamNativePriceProgramsTest is NativePriceProgramTestBase {
    function testZeroIsDeclaredAndCannotBeAnAbsentOrPaidConfiguration() public {
        IStreamNativePricePrograms.PriceProgramConfig memory c = _config(12, 0, 0, 3);
        c.primaryAssignmentHash = bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativePricePrograms.InvalidNativePriceProgram.selector)
        );
        nativeSale.registerPriceProgram(c);
        c = _config(0, 0, 0, 3);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativePricePrograms.InvalidNativePriceProgram.selector)
        );
        nativeSale.registerPriceProgram(c);
        bytes32 id = _program(12, 0, 0, 3);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 0, 0);
        e.authorization.saleId = bytes32(uint256(88));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceProgramUnavailable.selector,
                bytes32(uint256(88))
            )
        );
        nativeSale.previewPriceProgram(e);
        e.authorization.saleId = id;
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativePricePrograms.InvalidNativePriceProgram.selector)
        );
        nativeSale.executePriceProgram{ value: 1 }(e);
        _execute(e);
        require(
            manager.ownerOf(1) == payer && recorder.totalOfficialSettled(address(0)) == 0,
            "declared free mint"
        );
    }

    function testFreeNeverReadsPayoutOrCreatesProfileEscrowOrOfficialEvents() public {
        _template(payer);
        bytes32 id = _program(13, 0, 1000, 3);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 0, 0);
        vm.deal(address(nativeSale), 17);
        vm.deal(address(recorder), 23);
        vm.deal(address(escrow), 29);
        uint256 profiles = factory.profileCount();
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                address(resolver),
                0,
                abi.encodeCall(
                    IStreamRevenueResolver.resolvePrimaryAssignment, (uint256(1), uint256(0), CLASS)
                ),
                hex"cafe"
            );
        SaleFundingFaultVm(address(vm))
            .mockCallRevert(
                address(templateArtist),
                0,
                abi.encodeCall(
                    IStreamArtistBeneficiaryFacts.collectionArtistBeneficiary, (uint256(1))
                ),
                hex"babe"
            );
        e.chosenUnitPrice = 100;
        vm.expectRevert(hex"cafe");
        nativeSale.previewPriceProgram(e);
        e.chosenUnitPrice = 0;
        IStreamNativePricePrograms.PriceProgramResult memory q = nativeSale.previewPriceProgram(e);
        bytes32 key = recorder.settlementKey(address(nativeSale), q.executionId);
        vm.recordLogs();
        IStreamNativePricePrograms.PriceProgramResult memory r = _execute(e);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            r.revenueOutcome == 1 && r.tokenId == 1 && r.chargedAmount == 0 && r.settlementKey == 0
                && !r.escrowed,
            "typed free result"
        );
        require(
            !recorder.settlementConsumed(key) && recorder.totalOfficialSettled(address(0)) == 0
                && factory.profileCount() == profiles && address(escrow).balance == 29
                && address(nativeSale).balance == 17 && address(recorder).balance == 23,
            "no official/payment/materialization state"
        );
        uint256 found;
        bytes32 topic = keccak256(
            "NativePriceProgramFreeMint(bytes32,bytes32,bytes32,uint16,bytes32,uint256,address,address,uint64)"
        );
        for (uint256 i; i < logs.length; ++i) {
            require(
                logs[i].emitter != address(recorder) && logs[i].emitter != address(escrow)
                    && logs[i].emitter != address(factory),
                "no revenue events"
            );
            if (logs[i].emitter == address(nativeSale) && logs[i].topics[0] == topic) {
                require(
                    logs[i].topics[1] == id && logs[i].topics[2] == r.executionId
                        && logs[i].topics[3] == r.operationRoot,
                    "free topics"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1), r.operationId, uint256(1), payer, payer, uint64(1)
                            )
                        ),
                    "free event exact"
                );
                ++found;
            }
        }
        require(found == 1, "one explicit free event");
    }

    function testPWYWBandSignedMinimumAndExactFullTipRevenue() public {
        bytes32 id = _program(13, 100, 1000, 4);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 599, 600);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceOutsideBand.selector,
                uint256(599),
                uint256(600),
                uint256(1000)
            )
        );
        nativeSale.previewPriceProgram(e);
        e.chosenUnitPrice = 1001;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceOutsideBand.selector,
                uint256(1001),
                uint256(600),
                uint256(1000)
            )
        );
        nativeSale.previewPriceProgram(e);
        e.chosenUnitPrice = 777;
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativePricePrograms.InvalidNativePriceProgram.selector)
        );
        nativeSale.executePriceProgram{ value: 778 }(e);
        uint256 before = payer.balance;
        IStreamNativePricePrograms.PriceProgramResult memory r = _execute(e);
        require(
            r.revenueOutcome == 2 && r.chargedAmount == 777 && r.settlementKey != 0 && !r.escrowed,
            "paid result"
        );
        require(
            payer.balance == before - 777 && factory.walletFor(profile).balance == 777
                && recorder.totalOfficialSettled(address(0)) == 777,
            "entire choice official"
        );
        e.chosenUnitPrice = 888;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeAuthorizationUsed.selector,
                artist,
                bytes32(uint256(1))
            )
        );
        nativeSale.previewPriceProgram(e);
    }

    function testPWYWZeroThenPaidCannotReuseAuthenticatedExecutionLane() public {
        bytes32 id = _program(13, 0, 1000, 4);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 0, 0);
        IStreamNativePricePrograms.PriceProgramResult memory r = _execute(e);
        require(
            r.revenueOutcome == 1 && recorder.totalOfficialSettled(address(0)) == 0,
            "zero choice free"
        );
        e.chosenUnitPrice = 100;
        e.authorization.nonce = bytes32(uint256(999));
        _programSign(e);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeFixedPriceSaleAdapter.NativeExecutionUsed.selector, id, uint256(1)
            )
        );
        nativeSale.previewPriceProgram(e);
        e = _execution(id, 2, 100, 0);
        r = _execute(e);
        require(
            r.revenueOutcome == 2 && recorder.totalOfficialSettled(address(0)) == 100,
            "new execution pays"
        );
    }

    function testPerSaleCapTerminalManualCloseAndTimedOpenEdition() public {
        bytes32 bounded = _program(0, 100, 100, 1);
        _execute(_execution(bounded, 1, 100, 100));
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(bounded, 2, 100, 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceProgramUnavailable.selector, bounded
            )
        );
        nativeSale.previewPriceProgram(e);
        IStreamNativePricePrograms.PriceProgramConfig memory c = _config(1, 100, 100, 0);
        c.closeRule = 2;
        c.endsAt = 0;
        bytes32 manual = nativeSale.registerPriceProgram(c);
        _execute(_execution(manual, 3, 100, 100));
        _execute(_execution(manual, 4, 100, 100));
        nativeSale.closePriceProgram(manual);
        require(
            nativeSale.priceProgramRecord(manual).mintedQuantity == 2
                && nativeSale.priceProgramRecord(manual).closed,
            "terminal close"
        );
        e = _execution(manual, 5, 100, 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceProgramUnavailable.selector, manual
            )
        );
        nativeSale.previewPriceProgram(e);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceProgramUnavailable.selector, manual
            )
        );
        nativeSale.closePriceProgram(manual);
        c = _config(1, 100, 100, 0);
        c.endsAt = uint64(block.timestamp + 10);
        bytes32 timed = nativeSale.registerPriceProgram(c);
        e = _execution(timed, 6, 100, 100);
        vm.warp(c.endsAt);
        _execute(e);
        e = _execution(timed, 7, 100, 100);
        vm.warp(uint256(c.endsAt) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativePricePrograms.NativePriceProgramUnavailable.selector, timed
            )
        );
        nativeSale.previewPriceProgram(e);
    }

    function testConfigurationKindBandCapAndCloseRulesRejectAmbiguity() public {
        for (uint256 i; i < 8; ++i) {
            IStreamNativePricePrograms.PriceProgramConfig memory c = _config(13, 0, 100, 4);
            if (i == 0) c.kind = 2;
            if (i == 1) c.maxUnitPrice = 0;
            if (i == 2) c.minUnitPrice = 101;
            if (i == 3) c.maxSaleQuantity = 0;
            if (i == 4) c.closeRule = 0;
            if (i == 5) c.endsAt = 0;
            if (i == 6) c.closeRule = 2;
            if (i == 7) {
                c.kind = 1;
                c.minUnitPrice = 100;
            }
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamNativePricePrograms.InvalidNativePriceProgram.selector
                )
            );
            nativeSale.registerPriceProgram(c);
        }
        bytes32 id = _program(13, 0, 100, 4);
        require(
            nativeSale.priceProgramRecord(id).saleNonce != 0, "same constructor healthy control"
        );
    }

    function testReceiverFailureRollsBackFreeReplaySupplyAndPaidTemplateFundingThenRetries()
        public
    {
        _template(payer);
        NativeSettlementReceiver receiver = new NativeSettlementReceiver();
        receiver.configure(true, address(0), "", address(0));
        bytes32 id = _program(13, 0, 1000, 2);
        for (uint256 i; i < 2; ++i) {
            IStreamNativePricePrograms.PriceProgramExecution memory e =
                _execution(id, i + 1, i == 0 ? 0 : 777, 0);
            e.authorization.recipient = address(receiver);
            _programSign(e);
            uint256 profiles = factory.profileCount();
            uint256 before = payer.balance;
            vm.prank(payer);
            vm.expectRevert();
            nativeSale.executePriceProgram{ value: e.chosenUnitPrice }(e);
            require(
                nativeSale.priceProgramRecord(id).mintedQuantity == i && payer.balance == before
                    && factory.profileCount() == profiles,
                "rollback count/money/registration"
            );
            require(
                !nativeSale.authorizationUsed(artist, e.authorization.nonce)
                    && nativeSale.executionIdByNonce(id, i + 1) == 0,
                "rollback replay"
            );
            receiver.configure(false, address(0), "", address(0));
            IStreamNativePricePrograms.PriceProgramResult memory r = _execute(e);
            require(r.tokenId == i + 1 && r.revenueOutcome == (i == 0 ? 1 : 2), "exact retry");
            receiver.configure(true, address(0), "", address(0));
        }
        require(
            recorder.totalOfficialSettled(address(0)) == 777 && address(escrow).balance == 777,
            "only positive official escrow"
        );
    }

    function testFreeReceiverReentryPinsExactGuardAndPreservesOuterMint() public {
        bytes32 id = _program(12, 0, 0, 3);
        NativeSettlementReceiver receiver = new NativeSettlementReceiver();
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 0, 0);
        e.authorization.recipient = address(receiver);
        _programSign(e);
        PriceProgramReentryObserver observer = new PriceProgramReentryObserver();
        observer.configure(address(nativeSale), abi.encodeCall(nativeSale.executePriceProgram, (e)));
        receiver.configure(false, address(observer), abi.encodeCall(observer.probe, ()), address(0));
        _execute(e);
        require(
            keccak256(observer.reason())
                == keccak256(
                    abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
                ),
            "exact guard"
        );
        require(
            manager.ownerOf(1) == address(receiver)
                && nativeSale.priceProgramRecord(id).mintedQuantity == 1,
            "outer free succeeds"
        );
    }

    function testFuzzPWYWChosenPriceAllPaidOrExplicitZero(uint96 value) public {
        uint256 amount = uint256(value) % 1 ether;
        bytes32 id = _program(13, 0, 1 ether, 1);
        IStreamNativePricePrograms.PriceProgramResult memory r =
            _execute(_execution(id, 1, amount, 0));
        require(
            r.chargedAmount == amount && recorder.totalOfficialSettled(address(0)) == amount,
            "exact full amount"
        );
        require(
            r.revenueOutcome == (amount == 0 ? 1 : 2)
                && nativeSale.priceProgramRecord(id).mintedQuantity == 1,
            "explicit outcome"
        );
    }

    function testZeroChoiceSkipsUnusedStalePolicyButPositiveChoiceRejects() public {
        bytes32 id = _program(13, 0, 1000, 3);
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 100, 0);
        e.authorization.expectedPrimaryPolicyHash = keccak256("unused stale policy");
        _programSign(e);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativePricePrograms.InvalidNativePriceProgram.selector)
        );
        nativeSale.previewPriceProgram(e);
        e.chosenUnitPrice = 0;
        _execute(e);
        require(recorder.totalOfficialSettled(address(0)) == 0, "free ignores unused payout quote");
    }

    function testExactConfigPaidEventsAndIndependentFullDigestManagerIdentity() public {
        IStreamNativePricePrograms.PriceProgramConfig memory cfg = _config(13, 1, 1000, 3);
        uint256 nonce = nativeSale.nextSaleNonce();
        bytes32 id = nativeSale.priceProgramIdFor(1, PHASE, 13, nonce);
        bytes32 expectedId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(nativeSale),
                uint8(13),
                uint256(1),
                PHASE,
                nonce
            )
        );
        require(id == expectedId, "canonical sale ID includes actual kind");
        vm.recordLogs();
        nativeSale.registerPriceProgram(cfg);
        Vm.Log[] memory configLogs = vm.getRecordedLogs();
        IStreamNativePricePrograms.PriceProgramRecord memory rec = nativeSale.priceProgramRecord(id);
        bytes32 cfgHash =
            keccak256(abi.encode(keccak256("6529STREAM_NATIVE_PRICE_PROGRAM_CONFIG_V1"), id, cfg));
        require(rec.configHash == cfgHash, "independent config commitment");
        bytes32 cfgTopic = keccak256(
            "NativePriceProgramConfigured(bytes32,uint16,uint256,bytes32,(uint256,bytes32,uint8,uint256,uint256,uint64,uint64,uint64,uint8,bytes32,bytes32),uint64,uint64)"
        );
        uint256 count;
        for (uint256 i; i < configLogs.length; ++i) {
            if (configLogs[i].emitter == address(nativeSale) && configLogs[i].topics[0] == cfgTopic)
            {
                require(
                    configLogs[i].topics.length == 2 && configLogs[i].topics[1] == id,
                    "config topics"
                );
                require(
                    keccak256(configLogs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                nonce,
                                cfgHash,
                                cfg,
                                rec.lifecycle.saleCreatedAt,
                                rec.lifecycle.saleAdapterRegistryRevision
                            )
                        ),
                    "all configuration terms reconstruct"
                );
                ++count;
            }
        }
        require(count == 1, "one config event");
        IStreamNativePricePrograms.PriceProgramExecution memory e = _execution(id, 1, 777, 300);
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativePricePrograms"),
                keccak256("1"),
                block.chainid,
                address(nativeSale)
            )
        );
        bytes32 typeHash = keccak256(
            "NativePriceProgramAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash,uint256 unitPrice)"
        );
        bytes32 digest = keccak256(
            abi.encodePacked(hex"1901", domain, keccak256(abi.encode(typeHash, e.authorization)))
        );
        require(
            digest == nativeSale.priceProgramAuthorizationDigest(e.authorization),
            "independent full EIP712"
        );
        IStreamMintManager.MintBatch memory b;
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = payer;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = payer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = e.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = e.authorization.mintCommitment;
        b.expectedPolicyHash = manager.POLICY();
        b.contextHash = digest;
        b.authorizationId =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
        IStreamNativePricePrograms.PriceProgramResult memory q = nativeSale.previewPriceProgram(e);
        require(
            q.operationRoot == keccak256(abi.encode(b, address(nativeSale), uint256(0))),
            "full digest manager ID"
        );
        vm.recordLogs();
        IStreamNativePricePrograms.PriceProgramResult memory r = _execute(e);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        count = 0;
        uint256 official;
        bytes32 paidTopic = keccak256(
            "NativePriceProgramPaidMint(bytes32,bytes32,bytes32,uint16,bytes32,uint256,address,address,uint256,bytes32,bool,uint64)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(recorder)) ++official;
            if (logs[i].emitter == address(nativeSale) && logs[i].topics[0] == paidTopic) {
                require(
                    logs[i].topics[1] == id && logs[i].topics[2] == r.executionId
                        && logs[i].topics[3] == r.operationRoot,
                    "paid topics"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                r.operationId,
                                r.tokenId,
                                payer,
                                payer,
                                uint256(777),
                                r.settlementKey,
                                r.escrowed,
                                uint64(1)
                            )
                        ),
                    "paid transcript exact"
                );
                ++count;
            }
        }
        require(
            count == 1 && official == 4, "one paid completion and four canonical official events"
        );
        require(
            recorder.settlementResult(r.settlementKey).operationIdentityCommitment
                == q.operationRoot,
            "official binds same manager root"
        );
    }
}
