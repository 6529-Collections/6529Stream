// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeRightsAuctionFixture.sol";

interface RightsFaultVM {
    function expectCall(address target, uint256 value, bytes calldata data) external;
}

/// @notice Current Core/Manager/Recorder collection-TEMPLATE prepared settlement.
/// @dev Artist/governance/entropy boundaries are explicitly typed in the inherited fixture.
contract StreamCurrentNativeRightsAuctionTest is NativeRightsAuctionFixture {
    RightsFaultVM private constant faults =
        RightsFaultVM(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant RECEIPT = keccak256(
        "PreparedNativeRightsRevenueRecorded(bytes32,bytes32,bytes32,((address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,bytes32)),((uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32),(uint8,bytes32,bytes32)),bytes32)"
    );

    function _receipt(bytes32 id, bytes32 key, Vm.Log[] memory logs)
        private
        view
        returns (
            StreamPreparedNativeRightsTypes.Facts memory facts,
            StreamPreparedNativeRightsTypes.Intent memory original,
            bytes32 currentPolicy
        )
    {
        uint256 count;
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        for (uint256 n; n < logs.length; ++n) {
            if (
                logs[n].emitter != address(recorder) || logs[n].topics.length != 4
                    || logs[n].topics[0] != RECEIPT
            ) continue;
            ++count;
            require(logs[n].data.length == 1376, "full 43-word receipt");
            (facts, original, currentPolicy) = abi.decode(
                logs[n].data,
                (
                    StreamPreparedNativeRightsTypes.Facts,
                    StreamPreparedNativeRightsTypes.Intent,
                    bytes32
                )
            );
            bytes32 expected = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_FACTS_V1"), block.chainid, facts
                )
            );
            bytes32 saleKey = recorder.preparedNativeSaleKey(address(house), a.saleId, a.saleNonce);
            require(
                logs[n].topics[1] == key && logs[n].topics[2] == saleKey
                    && logs[n].topics[3] == expected,
                "complete indexed original receipt"
            );
            require(
                recorder.preparedNativeRightsFactsHash(key) == expected
                    && recorder.preparedNativeSaleConsumed(saleKey),
                "official stored facts and shared sale consumption"
            );
            require(
                keccak256(abi.encode(original.original))
                        == keccak256(abi.encode(house.originalAuctionRights(id)))
                    && keccak256(abi.encode(facts.original))
                        == keccak256(abi.encode(original.original)),
                "original rights retained"
            );
            require(
                original.sale.saleId == a.saleId && original.sale.saleNonce == a.saleNonce
                    && original.sale.originalPrimaryPolicyHash == a.config.expectedPrimaryPolicyHash
                    && original.sale.contentSelectionHash == a.config.artworkCommitment,
                "original signed policy and work"
            );
            require(
                facts.mint.tokenId == a.tokenId && facts.mint.collectionSerial == a.tokenId
                    && facts.mint.saleAdapter == address(house)
                    && facts.mint.mintManager == address(manager)
                    && facts.mint.recorder == address(recorder)
                    && facts.mint.tokenDataHash == keccak256("rights artwork"),
                "actual prepared token and owners"
            );
            require(
                ledger.isManagerOperationRootUsed(address(manager), facts.mint.operationRoot),
                "actual original root consumed"
            );
            require(
                recorder.settlementResult(key).operationIdentityCommitment
                    == facts.mint.operationRoot,
                "full result original operation"
            );
        }
        require(count == 1, "one exact rights receipt");
    }

    function testActualTemplateMaterializesWithPreparedTokenPolicyAndTwoSuccesses() public {
        StreamSaleTemplate.Selection memory selected = _selected();
        require(
            !factory.profileExists(selected.profileId) && selected.wallet.code.length == 0,
            "unmaterialized preview is valid"
        );
        for (uint256 n; n < 2; ++n) {
            bytes32 id = _createRights(_rightsConfig());
            _rightsBid(id, payer);
            _endRights(id);
            vm.recordLogs();
            (uint256 token, bytes32 key) = house.settle(id);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            (
                StreamPreparedNativeRightsTypes.Facts memory f,
                StreamPreparedNativeRightsTypes.Intent memory o,
                bytes32 policyHash
            ) = _receipt(id, key, logs);
            require(
                token == n + 1 && core.ownerOf(token) == payer
                    && policyHash == _policy(token, selected) && policyHash != _policy(0, selected),
                "actual token policy never token-zero alias"
            );
            require(factory.profileExists(selected.profileId), "actual profile materialized");
            if (n == 0) {
                require(
                    !factory.splitWalletExists(selected.profileId)
                        && selected.wallet.code.length == 0 && selected.wallet.balance == 0
                        && recorder.settlementResult(key).escrowed
                        && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                        == 1000 && escrow.totalOwed(address(0)) == 1000,
                    "first template funding retains exact undeployed-wallet credit"
                );
                escrow.flushEscrow(CLASS, selected.profileId, selected.wallet, address(0));
            } else {
                require(!recorder.settlementResult(key).escrowed, "deployed wallet funded directly");
            }
            require(
                factory.splitWalletExists(selected.profileId)
                    && selected.wallet.balance == 1000 * (n + 1)
                    && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                        == 0 && escrow.totalOwed(address(0)) == 0,
                "actual wallet payment and cleared escrow"
            );
            require(
                recorder.settlementResult(key).profileId == selected.profileId
                    && recorder.settlementResult(key).wallet == selected.wallet,
                "actual resolver wallet retained"
            );
            require(
                manager.activePreparedNativeRights().mint.operationRoot == 0
                    && manager.activePreparedNativeMint().operationRoot == 0
                    && core.pendingPreparedMintTokenId() == 0,
                "all active fields cleared after success"
            );
            (uint256 same, bytes32 sameKey) = house.settle(id);
            require(
                same == token && sameKey == key
                    && recorder.totalOfficialSettled(address(0)) == 1000 * (n + 1),
                "terminal settle never pays again"
            );
            vm.deal(address(house), 1000);
            vm.prank(address(house));
            (bool ok,) = address(recorder).call{ value: 1000 }(
                abi.encodeCall(recorder.settlePreparedNativeRightsSale, (f, o))
            );
            require(!ok, "retained receipt cannot replay outside active Manager operation");
            vm.prank(address(house));
            (ok,) = address(recorder).call{ value: 1000 }(
                abi.encodeCall(recorder.settlePreparedNativePrimarySale, (f.mint, o.sale))
            );
            require(!ok, "new receipt cannot cross into original prepared entry");
            vm.deal(address(house), 0);
        }
        require(
            manager.nextOperationNonce() == 2 && core.collectionNextSerial(1) == 3
                && house.totalBuyerLiabilities() == 0,
            "success releases all operation guards"
        );
    }

    function testAllowCurrentAssignmentAndPayoutDriftRetainsOriginalAuthorization() public {
        StreamSaleTemplate.Selection memory before_ = _selected();
        bytes32 id = _createRights(_rightsConfig());
        _rightsBid(id, payer);
        bytes32 opening = house.auction(id).config.expectedPrimaryPolicyHash;
        _selectTemplate(800000, keccak256("later assignment"));
        rightsArtist.setPayout(address(0xB0B));
        StreamSaleTemplate.Selection memory after_ = _selected();
        require(
            after_.assignmentHash != before_.assignmentHash
                && after_.profileId != before_.profileId,
            "distinct selected assignment and payout"
        );
        _endRights(id);
        vm.recordLogs();
        (uint256 token, bytes32 key) = house.settle(id);
        (
            StreamPreparedNativeRightsTypes.Facts memory f,
            StreamPreparedNativeRightsTypes.Intent memory o,
            bytes32 policyHash
        ) = _receipt(id, key, vm.getRecordedLogs());
        require(
            o.original.assignmentHash == before_.assignmentHash
                && f.original.templateId == before_.templateId
                && o.sale.originalPrimaryPolicyHash == opening,
            "opening remains signed original"
        );
        require(
            policyHash == _policy(token, after_) && factory.profileExists(after_.profileId)
                && after_.wallet.code.length == 0 && after_.wallet.balance == 0
                && recorder.settlementResult(key).escrowed
                && escrow.escrowOwed(CLASS, after_.profileId, after_.wallet, address(0)) == 1000
                && escrow.escrowOwed(CLASS, before_.profileId, before_.wallet, address(0)) == 0
                && before_.wallet.balance == 0,
            "ALLOW_CURRENT materializes and credits only fresh selection"
        );
        escrow.flushEscrow(CLASS, after_.profileId, after_.wallet, address(0));
        require(
            factory.splitWalletExists(after_.profileId) && after_.wallet.balance == 1000
                && before_.wallet.balance == 0 && escrow.totalOwed(address(0)) == 0
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "fresh selection paid once through actual escrow"
        );
    }

    function testSafeFundingPayoutDriftRollsBackAndIdenticalSignedRetrySucceeds() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE741;
        keys[1] = 0x5AFE742;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 741);
        bytes32 id = _createRights(_rightsConfig());
        _rightsBid(id, address(safe));
        _endRights(id);
        StreamSaleTemplate.Selection memory selected = _selected();
        require(
            address(escrow).balance == 0 && escrow.totalOwed(address(0)) == 0
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 0,
            "late-funding trigger starts at exact zero"
        );
        rightsArtist.changeAfterFunding(address(escrow), address(0xBAD));
        bytes memory data = abi.encodeCall(house.settle, (id));
        uint256 nonce = safe.nonce();
        bytes32 digest = safe.getTransactionHash(
            address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory callData = abi.encodeCall(
            safe.execTransaction,
            (
                address(house),
                0,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
        faults.expectCall(
            address(escrow),
            1000,
            abi.encodeCall(escrow.creditNative, (CLASS, selected.profileId, selected.wallet, true))
        );
        (bool ok,) = address(safe).call(callData);
        require(
            !ok && safe.nonce() == nonce && safe.getThreshold() == 2
                && house.auction(id).status == 1,
            "Safe exact nonce and auction retained"
        );
        require(
            !factory.profileExists(selected.profileId) && selected.wallet.code.length == 0
                && recorder.totalOfficialSettled(address(0)) == 0 && address(escrow).balance == 0
                && escrow.totalOwed(address(0)) == 0
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 0,
            "actual funding and materialization rolled back"
        );
        require(
            core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && core.pendingPreparedMintTokenId() == 0 && manager.nextOperationNonce() == 0
                && manager.activePreparedNativeRights().mint.operationRoot == 0,
            "prepare and all rights state rolled back"
        );
        require(
            house.totalBuyerLiabilities() == 1100 && address(house).balance == 1100,
            "whole winning deposit preserved"
        );
        rightsArtist.changeAfterFunding(address(0), address(0));
        bytes memory returned;
        (ok, returned) = address(safe).call(callData);
        require(
            ok && returned.length == 32 && abi.decode(returned, (bool)) && safe.nonce() == nonce + 1
                && core.ownerOf(1) == address(safe),
            "identical signed settlement retries after true late fault"
        );
        require(
            selected.wallet.code.length == 0 && selected.wallet.balance == 0
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 1000
                && escrow.totalOwed(address(0)) == 1000
                && recorder.totalOfficialSettled(address(0)) == 1000
                && house.totalBuyerLiabilities() == 0,
            "identical retry records exactly one template credit"
        );
        escrow.flushEscrow(CLASS, selected.profileId, selected.wallet, address(0));
        require(
            factory.splitWalletExists(selected.profileId) && selected.wallet.balance == 1000
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 0
                && escrow.totalOwed(address(0)) == 0
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "one final payment through actual escrow"
        );
    }

    function testOpeningMutationRejectsAndOriginalSignedRequestRemainsUsable() public {
        IStreamNativeEnglishAuction.Configuration memory c = _rightsConfig();
        StreamPreparedNativeRightsTypes.OriginalPolicy memory o = _original();
        IStreamNativeEnglishAuction.CreationAuthorization memory a =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.rightsConfigurationHash(c, o),
                vm.addr(SIGNER_KEY),
                bytes32(uint256(777)),
                2000
            );
        bytes32 digest = house.creationAuthorizationDigest(a);
        bytes memory platform = _proof(AUCTION_PLATFORM_KEY, digest);
        bytes memory artistSig = _proof(SIGNER_KEY, digest);
        bytes32 old = o.assignmentHash;
        o.assignmentHash = keccak256("substitute original");
        (bool ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.registerRightsAuction,
                    (c, o, bytes("rights artwork"), a, platform, artistSig)
                )
            );
        require(!ok, "signed original assignment cannot change");
        o.assignmentHash = old;
        o.mode = 2;
        (ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.registerRightsAuction,
                    (c, o, bytes("rights artwork"), a, platform, artistSig)
                )
            );
        require(!ok, "unimplemented mode cannot alias profile");
        o.mode = 1;
        bytes32 id =
            house.registerRightsAuction(c, o, bytes("rights artwork"), a, platform, artistSig);
        (ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.registerRightsAuction,
                    (c, o, bytes("rights artwork"), a, platform, artistSig)
                )
            );
        require(
            !ok && house.auction(id).status == 1 && core.lastAllocatedTokenId() == 0,
            "original successful authorization consumed once without reserving token"
        );
    }

    function testProfileAndDefaultCannotSubstituteAndActualTokenOverrideRejected() public {
        bytes32 id = _createRights(_rightsConfig());
        _rightsBid(id, payer);
        _endRights(id);
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        (bool ok,) = address(house).call(abi.encodeCall(house.settle, (id)));
        require(
            !ok && core.lastAllocatedTokenId() == 0 && house.totalBuyerLiabilities() == 1100,
            "PROFILE is not collection TEMPLATE"
        );
        artists.accept(address(0));
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
        resolver.setPrimaryProfileAssignment(CLASS, 0, 0, profile, 0);
        artists.accept(vm.addr(SIGNER_KEY));
        (ok,) = address(house).call(abi.encodeCall(house.settle, (id)));
        require(!ok && manager.nextOperationNonce() == 0, "default does not silently substitute");
        template = _selectTemplate(900000, keccak256("restored template"));
        (uint256 token,) = house.settle(id);
        resolver.setPrimaryProfileAssignment(CLASS, 2, token, profile, 0);
        (ok,) = address(this).staticcall(abi.encodeCall(this.projectToken, (token)));
        require(
            !ok && core.ownerOf(token) == payer,
            "actual token override rejected by first mode projector"
        );
    }

    function projectToken(uint256 token) external view returns (bytes32) {
        (, bytes32 p) = StreamPreparedNativeRightsProjection.preparedTemplate(resolver, 1, token);
        return p;
    }

    function testNonTransientCounterUnlockUsesRightsContextAndNeverOldContextAlias() public {
        bytes32 phase = keccak256("rights context phase");
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONTEXT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            keccak256("rights context cap")
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            phase,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            gate,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, phase, address(house), true);
        IStreamNativeEnglishAuction.Configuration memory c = _rightsConfig();
        c.phaseId = phase;
        c.mintPolicyHash = manager.phasePolicyHash(1, phase);
        bytes32 id = _createRights(c);
        _rightsBid(id, payer);
        _endRights(id);
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        StreamPreparedNativeSettlementTypes.Intent memory sale =
            StreamNativeEnglishAuctionSupport.intent(a);
        // The public linked intent helper observes its calling host. Reconstruct
        // this host-dependent word independently with the actual auction address.
        sale.saleExecutionHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_ENGLISH_AUCTION_EXECUTION_V1"),
                block.chainid,
                address(house),
                a.configHash,
                a.creationDigest,
                a.saleId,
                a.winner
            )
        );
        StreamPreparedNativeRightsTypes.Intent memory original =
            StreamPreparedNativeRightsTypes.Intent(sale, house.originalAuctionRights(id));
        bytes32 context = keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_MINT_CONTEXT_V1"),
                block.chainid,
                address(manager),
                address(house),
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_INTENT_V1"),
                        block.chainid,
                        address(house),
                        address(recorder),
                        original
                    )
                )
            )
        );
        bytes32 oldContext = StreamPreparedNativeSettlementHash.mintContext(
            address(manager),
            address(house),
            StreamPreparedNativeSettlementHash.intentHash(address(house), address(recorder), sale)
        );
        require(context != oldContext, "explicit new domain");
        (bool ok,) = address(house).call(abi.encodeCall(house.unlockNoMint, (id, uint8(2))));
        require(!ok, "unexhausted actual counter not terminal evidence");
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONTEXT,
            1,
            phase,
            COUNTER,
            payer,
            payer,
            address(house),
            address(0),
            context
        );
        bytes32 key = manager.previewCounterValueKey(1, phase, COUNTER, subject);
        IStreamMintLedger.CounterConsumption[] memory uses =
            new IStreamMintLedger.CounterConsumption[](1);
        uses[0] = IStreamMintLedger.CounterConsumption(
            key,
            1,
            phase,
            COUNTER,
            subject,
            payer,
            payer,
            address(0),
            address(house),
            1,
            1,
            context,
            0
        );
        bytes32[] memory nullifiers = new bytes32[](0);
        // Seed through the real Ledger's original authorized-writer boundary. This
        // isolates the terminal reader's key, not a second production mint pathway.
        vm.prank(address(manager));
        ledger.consume(
            1,
            phase,
            uses,
            keccak256("seed authorization"),
            nullifiers,
            c.mintPolicyHash,
            keccak256("seed operation")
        );
        bytes32 oldSubject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.CONTEXT,
            1,
            phase,
            COUNTER,
            payer,
            payer,
            address(house),
            address(0),
            oldContext
        );
        require(
            ledger.counterValue(key) == 1
                && ledger.counterValue(
                        manager.previewCounterValueKey(1, phase, COUNTER, oldSubject)
                    ) == 0,
            "only exact rights context exhausted"
        );
        house.unlockNoMint(id, 2);
        require(
            house.auction(id).status == 6 && house.refundableBalance(a.saleId, payer) == 1100
                && core.lastAllocatedTokenId() == 0,
            "non-transient full original refund from exact new key"
        );
    }

    function testTemplateNoBidCancellationAndExpiredClaimsKeepTerminalExemptions() public {
        bytes32 cancelId = _createRights(_rightsConfig());
        house.cancel(cancelId, keccak256("poster"));
        require(house.auction(cancelId).status == 4, "new profile cancellation");
        bytes32 noBid = _createRights(_rightsConfig());
        _endRights(noBid);
        (uint256 token, bytes32 key) = house.settle(noBid);
        require(token == 0 && key == 0 && house.auction(noBid).status == 5, "NO_BIDS no free mint");
        bytes32 id = _createRights(_rightsConfig());
        _rightsBid(id, payer);
        (, uint64 deadline,,) = house.auctionDeadlines(id);
        vm.warp(uint256(deadline) + 1);
        vm.etch(address(recorder), hex"60006000fd");
        vm.etch(address(artists), hex"60006000fd");
        house.unlockNoMint(id, 0);
        bytes32 saleId = house.auction(id).saleId;
        uint256 before_ = payer.balance;
        vm.prank(payer);
        house.claimRefund(saleId, payable(payer));
        require(
            payer.balance == before_ + 1100 && house.totalBuyerLiabilities() == 0
                && core.lastAllocatedTokenId() == 0,
            "escape and own claim ignore failed current pins"
        );
    }
}
