// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeConsentedRightsAuctionFixture.sol";

interface ConsentedRightsFaultVM {
    function expectCall(address target, uint256 value, bytes calldata data) external;
}

/// @notice Actual Core/Manager/Resolver/Factory/recorder payment with explicit positive-share mode2.
/// @dev Artist consent and governance/entropy remain typed boundaries; actual operation15 is separate.
contract StreamCurrentConsentedNativeRightsAuctionTest is NativeConsentedRightsAuctionFixture {
    ConsentedRightsFaultVM private constant faults =
        ConsentedRightsFaultVM(address(uint160(uint256(keccak256("hevm cheat code")))));
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

    function testConsentedOnePpmPaysTwoPreparedTokensWithOriginalReceiptAndNoReplay() public {
        StreamSaleTemplate.Selection memory selected = _selected();
        (,, uint32 share) = resolver.primaryTemplateConsentFacts(selected.templateId);
        require(
            share == 1 && !factory.profileExists(selected.profileId), "positive one ppm preview"
        );
        for (uint256 n; n < 2; ++n) {
            bytes32 id = _createRights(_rightsConfig());
            _rightsBid(id, payer);
            _endRights(id);
            vm.recordLogs();
            (uint256 token, bytes32 key) = house.settle(id);
            (
                StreamPreparedNativeRightsTypes.Facts memory f,
                StreamPreparedNativeRightsTypes.Intent memory o,
                bytes32 policy
            ) = _receipt(id, key, vm.getRecordedLogs());
            require(
                f.original.mode == 2 && o.original.mode == 2 && token == n + 1
                    && core.ownerOf(token) == payer && policy == _policy(token, selected)
                    && policy != _policy(0, selected),
                "mode and actual token policy remain distinct"
            );
            require(
                recorder.settlementResult(key).profileId == selected.profileId
                    && recorder.settlementResult(key).wallet == selected.wallet,
                "official current concrete payout"
            );
            if (n == 0) {
                require(
                    recorder.settlementResult(key).escrowed && selected.wallet.code.length == 0
                        && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                            == 1000,
                    "actual initial template credit"
                );
                escrow.flushEscrow(CLASS, selected.profileId, selected.wallet, address(0));
            } else {
                require(!recorder.settlementResult(key).escrowed, "second actual direct payment");
            }
            require(
                selected.wallet.balance == 1000 * (n + 1) && escrow.totalOwed(address(0)) == 0
                    && manager.activePreparedNativeRights().mint.operationRoot == 0
                    && core.pendingPreparedMintTokenId() == 0,
                "funding and active-state cleanup"
            );
            (uint256 same, bytes32 sameKey) = house.settle(id);
            require(
                same == token && sameKey == key
                    && recorder.totalOfficialSettled(address(0)) == 1000 * (n + 1),
                "terminal no double payment"
            );
            bytes memory rightsReplay =
                abi.encodeCall(recorder.settlePreparedNativeRightsSale, (f, o));
            bytes memory oldReplay =
                abi.encodeCall(recorder.settlePreparedNativePrimarySale, (f.mint, o.sale));
            vm.deal(address(house), 1000);
            vm.prank(address(house));
            (bool ok,) = address(recorder).call{ value: 1000 }(rightsReplay);
            require(!ok, "same original rights sale cannot replay");
            vm.prank(address(house));
            (ok,) = address(recorder).call{ value: 1000 }(oldReplay);
            require(!ok, "mode2 facts cannot cross into original prepared entry");
            vm.deal(address(house), 0);
        }
        require(
            manager.nextOperationNonce() == 2 && core.collectionNextSerial(1) == 3
                && house.totalBuyerLiabilities() == 0,
            "two original operations completed once"
        );
    }

    function testConsentedModeIsSignedAndStrictInitialModeKeepsItsFloor() public {
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.strictSelection, ()));
        require(!ok, "old bounded template projection retains its original floor");
        IStreamNativeEnglishAuction.Configuration memory c = _rightsConfig();
        StreamPreparedNativeRightsTypes.OriginalPolicy memory o = _original();
        IStreamNativeEnglishAuction.CreationAuthorization memory a =
            IStreamNativeEnglishAuction.CreationAuthorization(
                house.rightsConfigurationHash(c, o),
                vm.addr(SIGNER_KEY),
                bytes32(uint256(888)),
                this.rightsFixtureTime() + 1000
            );
        bytes32 digest = house.creationAuthorizationDigest(a);
        bytes memory platform = _proof(AUCTION_PLATFORM_KEY, digest);
        bytes memory artistSig = _proof(SIGNER_KEY, digest);
        bytes memory originalCall = abi.encodeCall(
            house.registerRightsAuction, (c, o, bytes("rights artwork"), a, platform, artistSig)
        );
        o.mode = 1;
        (ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.registerRightsAuction,
                    (c, o, bytes("rights artwork"), a, platform, artistSig)
                )
            );
        require(!ok, "mode cannot change under original signatures");
        a.configHash = house.rightsConfigurationHash(c, o);
        digest = house.creationAuthorizationDigest(a);
        (ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.registerRightsAuction,
                    (
                        c,
                        o,
                        bytes("rights artwork"),
                        a,
                        _proof(AUCTION_PLATFORM_KEY, digest),
                        _proof(SIGNER_KEY, digest)
                    )
                )
            );
        require(!ok, "even signed mode1 cannot loosen strict template floor");
        bytes memory raw;
        (ok, raw) = address(house).call(originalCall);
        require(ok && raw.length == 32, "unchanged original mode2 request remains usable");
        bytes32 id = abi.decode(raw, (bytes32));
        require(
            house.originalAuctionRights(id).mode == 2 && house.auction(id).status == 1
                && core.lastAllocatedTokenId() == 0,
            "opening binds mode without reserving a token"
        );
        (ok,) = address(house).call(originalCall);
        require(!ok, "original creation request is consumed once");
    }

    function strictSelection() external view returns (StreamSaleTemplate.Selection memory) {
        return StreamPreparedNativeRightsProjection.collectionTemplate(resolver, 1);
    }

    function testCurrentExactConsentBlocksBidAndSettlementUntilOriginalKeyReapproved() public {
        StreamSaleTemplate.Selection memory selected = _selected();
        bytes32 id = _createRights(_rightsConfig());
        consentArtist.approve(address(resolver), selected.assignmentHash, false);
        uint256 value = 1000 + entropy.fee();
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        (bool ok,) =
            address(house).call{ value: value }(abi.encodeCall(house.bid, (id, address(0))));
        require(
            !ok && house.auction(id).winner.payer == address(0)
                && house.totalBuyerLiabilities() == 0,
            "fresh bid requires exact current consent"
        );
        consentArtist.approve(address(resolver), selected.assignmentHash, true);
        _rightsBid(id, payer);
        _endRights(id);
        bytes memory originalCall = abi.encodeCall(house.settle, (id));
        consentArtist.nextBinding();
        (ok,) = address(house).call(originalCall);
        require(!ok, "prior binding consent cannot pay current binding");
        consentArtist.approve(address(resolver), bytes32(uint256(1234)), true);
        (ok,) = address(house).call(originalCall);
        require(
            !ok && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0
                && !factory.profileExists(selected.profileId) && escrow.totalOwed(address(0)) == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && house.totalBuyerLiabilities() == value,
            "wrong key has no mint or payment effect and preserves winning liability"
        );
        consentArtist.approve(address(resolver), selected.assignmentHash, true);
        (ok,) = address(house).call(originalCall);
        require(
            ok && core.ownerOf(1) == payer && manager.nextOperationNonce() == 1
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                    == 1000,
            "same original settlement succeeds with current exact key"
        );
    }

    function testAllowCurrentConsentedLowTakeAssignmentAndPayoutDriftKeepsOpening() public {
        StreamSaleTemplate.Selection memory original = _selected();
        bytes32 id = _createRights(_rightsConfig());
        _rightsBid(id, payer);
        template = _approveTemplate(250000, keccak256("later approved low take"));
        rightsArtist.setPayout(address(0xB0B));
        StreamSaleTemplate.Selection memory current = _selected();
        require(
            current.assignmentHash != original.assignmentHash
                && current.profileId != original.profileId,
            "different approved terms and payout"
        );
        _endRights(id);
        vm.recordLogs();
        (uint256 token, bytes32 key) = house.settle(id);
        (
            StreamPreparedNativeRightsTypes.Facts memory f,
            StreamPreparedNativeRightsTypes.Intent memory o,
            bytes32 policy
        ) = _receipt(id, key, vm.getRecordedLogs());
        require(
            o.original.mode == 2 && f.original.assignmentHash == original.assignmentHash
                && o.sale.originalPrimaryPolicyHash == _policy(0, original)
                && policy == _policy(token, current) && policy != _policy(token, original),
            "ALLOW_CURRENT preserves signed original and records fresh actual-token economics"
        );
        require(
            escrow.escrowOwed(CLASS, current.profileId, current.wallet, address(0)) == 1000
                && escrow.escrowOwed(CLASS, original.profileId, original.wallet, address(0)) == 0,
            "only fresh approved concrete wallet credited"
        );
        escrow.flushEscrow(CLASS, current.profileId, current.wallet, address(0));
        require(
            current.wallet.balance == 1000 && original.wallet.balance == 0
                && escrow.totalOwed(address(0)) == 0,
            "actual payout rotation funded once"
        );
    }

    function testSafeConsentLossAfterActualFundingRollsBackAndIdenticalRetryPays() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE941;
        keys[1] = 0x5AFE942;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 941);
        StreamSaleTemplate.Selection memory selected = _selected();
        bytes32 id = _createRights(_rightsConfig());
        _rightsBid(id, address(safe));
        _endRights(id);
        require(
            address(escrow).balance == 0 && escrow.totalOwed(address(0)) == 0
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 0,
            "funding trigger exact zero baseline"
        );
        consentArtist.failConsentAfterFunding(address(escrow));
        bytes memory data = abi.encodeCall(house.settle, (id));
        uint256 nonce = safe.nonce();
        bytes32 digest = safe.getTransactionHash(
            address(house), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory originalCall = abi.encodeCall(
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
        (bool ok,) = address(safe).call(originalCall);
        require(
            !ok && safe.nonce() == nonce && safe.getThreshold() == 2
                && house.auction(id).status == 1,
            "actual Safe keeps nonce and authority on late failure"
        );
        require(
            !factory.profileExists(selected.profileId) && selected.wallet.code.length == 0
                && escrow.totalOwed(address(0)) == 0 && address(escrow).balance == 0
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "actual materialization and credit rolled back"
        );
        require(
            core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1
                && core.pendingPreparedMintTokenId() == 0 && manager.nextOperationNonce() == 0
                && manager.activePreparedNativeRights().mint.operationRoot == 0
                && house.totalBuyerLiabilities() == 1100 && address(house).balance == 1100,
            "whole prepared operation and winning deposit retained"
        );
        consentArtist.failConsentAfterFunding(address(0));
        vm.recordLogs();
        bytes memory returned;
        (ok, returned) = address(safe).call(originalCall);
        require(
            ok && returned.length == 32 && abi.decode(returned, (bool)) && safe.nonce() == nonce + 1
                && core.ownerOf(1) == address(safe),
            "identical signed call succeeds after funding fault removal"
        );
        IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
        _receipt(id, a.settlementKey, vm.getRecordedLogs());
        require(
            escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 1000
                && recorder.totalOfficialSettled(address(0)) == 1000
                && house.totalBuyerLiabilities() == 0,
            "one accepted original payment"
        );
        escrow.flushEscrow(CLASS, selected.profileId, selected.wallet, address(0));
        require(
            selected.wallet.balance == 1000 && escrow.totalOwed(address(0)) == 0,
            "exact original wallet ultimately funded"
        );
    }
}
