// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativePlatformCustodyFixture.sol";

interface PlatformTemplateCustodyCalls {
    function expectCall(address, uint256, bytes calldata, uint64) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract StreamCurrentPlatformTemplateCustodyTest is NativePlatformCustodyFixture {
    bytes32 private constant RECORDED =
        0x5c1363e44341557049de1408c1e68be67103614d6f776a23f4da8ec147e24536;

    PlatformTemplateCustodyCalls private constant calls =
        PlatformTemplateCustodyCalls(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testCollectionAndDefaultStaticPosterTemplatesMaterializeAndPayOriginalCustodyTokens()
        public
    {
        uint256 token;
        for (uint8 mode = 8; mode <= 9; ++mode) {
            for (uint8 poster; poster < 2; ++poster) {
                _template(mode, poster == 1);
                Plan memory p = _plan(mode, address(this), 150);
                StreamSaleTemplate.Selection memory selected = _selected(mode);
                require(
                    !factory.profileExists(selected.profileId),
                    "only a predicted template profile before payment"
                );
                bytes32 id = _acquire(p);
                ++token;
                IStreamRoyaltySnapshot.Snapshot memory snapshot = royalty.royaltySnapshot(token);
                StreamNativeCustodySettlementTypes.Origin memory origin = house.custodyOrigin(id);
                require(
                    origin.tokenId == token && snapshot.exists
                        && snapshot.operationRoot == origin.operationRoot
                        && core.ownerOf(token) == address(house)
                        && !factory.profileExists(selected.profileId),
                    "unpaid acquisition snapshots once and does not materialize primary receipts"
                );
                _custodyBid(id, payer);
                _end(id);
                IStreamNativeEnglishAuction.Auction memory a = house.auction(id);
                a.status = 2;
                StreamNativeCustodySettlementTypes.Facts memory f =
                    StreamNativeCustodySettlementTypes.Facts(id, a, origin);
                IStreamRevenueResolver.ResolvedPrimaryAssignment memory current =
                    resolver.resolvePrimaryAssignment(2, token, CLASS);
                bytes32 witness = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_PRIMARY_TEMPLATE_WITNESS_V1"),
                        block.chainid,
                        address(resolver),
                        uint256(2),
                        token,
                        mode,
                        p.auth.declarationHash,
                        address(this),
                        current,
                        selected
                    )
                );
                bytes32 factsHash = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_CUSTODY_FACTS_V1"),
                        block.chainid,
                        address(recorder),
                        address(house),
                        f,
                        p.auth.declarationHash,
                        p.original
                    )
                );
                vm.recordLogs();
                (, bytes32 key) = house.settle(id);
                Vm.Log[] memory logs = vm.getRecordedLogs();
                StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
                    recorder.settlementResult(key);
                require(
                    result.escrowed && result.amount == 1000
                        && result.profileId == selected.profileId
                        && factory.profileExists(selected.profileId)
                        && !factory.splitWalletExists(selected.profileId)
                        && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                        == 1000 && core.ownerOf(token) == payer
                        && manager.nextOperationNonce() == token && _counter() == token
                        && keccak256(abi.encode(royalty.royaltySnapshot(token)))
                            == keccak256(abi.encode(snapshot)),
                    "actual template escrow payment with no new allocation or snapshot"
                );
                _receipt(logs, key, factsHash, p, f, selected, witness, result);
                uint256 represented;
                for (uint256 j; j < factory.profileEntryCount(selected.profileId); ++j) {
                    (address account, uint32 share, bytes32 label) =
                        factory.profileEntry(selected.profileId, j);
                    if (label == keccak256("platform creator")) {
                        require(
                            account == (poster == 1 ? address(this) : address(0xA111))
                                && share == 900000,
                            "original symbolic poster or exact static recipient"
                        );
                        ++represented;
                    }
                }
                require(represented == 1, "one exact platform creator entry");
                factory.deployWallet(selected.profileId);
                escrow.flushEscrow(CLASS, selected.profileId, selected.wallet, address(0));
                require(
                    selected.wallet.balance == 1000
                        && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0))
                            == 0,
                    "actual deterministic wallet deployment and escrow flush"
                );
            }
        }
    }

    function _receipt(
        Vm.Log[] memory logs,
        bytes32 key,
        bytes32 factsHash,
        Plan memory p,
        StreamNativeCustodySettlementTypes.Facts memory f,
        StreamSaleTemplate.Selection memory selected,
        bytes32 witness,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result
    ) private view {
        IStreamNativeEnglishAuction.Auction memory a = f.auction;
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c;
        c.saleAdapter = address(house);
        c.executor = a.winner.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            a.saleId,
            CLASS,
            1,
            2,
            a.tokenId,
            a.saleNonce,
            a.winner.payer,
            a.config.poster,
            a.winner.deliverTo,
            1000,
            _policy(a.tokenId, selected)
        );
        c.lifecycleBinding.saleCreatedAt = a.lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision = a.lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PLATFORM_CUSTODY_EXECUTION_V1"),
                    block.chainid,
                    address(recorder),
                    address(house),
                    f,
                    p.auth.declarationHash,
                    p.original,
                    witness
                )
            ),
            a.winner.bidIndex,
            a.winner.signed ? 1 : 2,
            a.winner.authorizationDigest
        );
        c.orchestrationOrder = 3;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            selected.profileId,
            selected.wallet,
            selected.templateId,
            selected.assignmentHash,
            selected.entriesHash
        );
        c.saleExecutionHash = factsHash;
        require(
            result.candidateCommitment
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PLATFORM_CUSTODY_CANDIDATE_V1"),
                            block.chainid,
                            address(recorder),
                            address(house),
                            f,
                            p.auth.declarationHash,
                            p.original,
                            c,
                            witness
                        )
                    ) && result.executionId == c.executionBinding.executionId
                && recorder.nativeCustodyFactsHash(key) == factsHash,
            "full nonzero-template candidate and canonical actual-token policy"
        );
        bytes32 saleKey = recorder.preparedNativeSaleKey(address(house), a.saleId, a.saleNonce);
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(recorder) && logs[i].topics.length == 4
                    && logs[i].topics[0] == RECORDED
            ) {
                require(
                    logs[i].topics[1] == key && logs[i].topics[2] == saleKey
                        && logs[i].topics[3] == factsHash
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    p.auth.declarationHash,
                                    p.original,
                                    f,
                                    witness,
                                    result
                                )
                            ),
                    "entire declaration/origin/template payment receipt"
                );
                ++count;
            }
        }
        require(
            count == 1 && recorder.preparedNativeSaleConsumed(saleKey)
                && recorder.settlementConsumed(key),
            "one original sale and canonical settlement identity"
        );
    }

    function testOriginalPosterSurvivesDifferentAcquisitionAndSettlementExecutor() public {
        _template(8, true);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xCA31;
        keys[1] = 0xCA32;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 202);
        vm.deal(address(safe), 1 ether);
        Plan memory p = _plan(8, address(safe), 150);
        require(executeSafe(safe, keys, address(house), 150, _call(p), 0));
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_AUCTION_V1"),
                block.chainid,
                address(house),
                uint256(2),
                uint256(1),
                uint256(1),
                false
            )
        );
        _custodyBid(id, payer);
        _end(id);
        require(executeSafe(safe, keys, address(house), 0, abi.encodeCall(house.settle, (id)), 0));
        StreamSaleTemplate.Selection memory selected = _selected(8);
        uint256 creator;
        for (uint256 i; i < factory.profileEntryCount(selected.profileId); ++i) {
            (address recipient, uint32 share, bytes32 label) =
                factory.profileEntry(selected.profileId, i);
            if (label == keccak256("platform creator")) {
                require(
                    recipient == address(this) && recipient != address(safe) && recipient != payer
                        && share == 900000,
                    "SALE_POSTER is the signed original poster, never an executor or payer"
                );
                ++creator;
            }
        }
        require(
            creator == 1 && house.custodyOrigin(id).fundingAccount == address(safe)
                && house.refundableBalance(house.auction(id).saleId, address(safe)) == 50
                && _counter() == 1,
            "operator fee credit remains separate from template beneficiary"
        );
    }

    function testProfileOnlyRecorderAndActualOverridesCannotAdmitDefaultTemplateCustody() public {
        bytes32 template = _template(9, true);
        Plan memory p = _plan(9, address(this), 150);
        bytes memory original = _call(p);
        calls.mockCall(
            address(recorder),
            abi.encodeCall(
                IERC165.supportsInterface,
                (type(IStreamPlatformTemplateCustodySettlement).interfaceId)
            ),
            abi.encode(false)
        );
        (bool ok,) = address(house).call{ value: 150 }(original);
        require(
            !ok && core.lastAllocatedTokenId() == 0 && _counter() == 0,
            "profile-only recorder cannot promise templates"
        );
        calls.clearMockedCalls();
        bytes memory out;
        (ok, out) = address(house).call{ value: 150 }(original);
        require(ok, "same original opening after capability repair");
        bytes32 id = abi.decode(out, (bytes32));
        resolver.setPrimaryTemplateAssignment(CLASS, 2, 1, template, 0);
        vm.deal(payer, 1 ether);
        vm.prank(payer);
        (ok,) = address(house).call{ value: 1000 }(abi.encodeCall(house.bid, (id, payer)));
        require(
            !ok && house.auction(id).winner.amount == 0,
            "exact token TEMPLATE override is not skipped"
        );
        resolver.clearPrimaryAssignment(CLASS, 2, 1);
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 2, template, 0);
        vm.prank(payer);
        (ok,) = address(house).call{ value: 1000 }(abi.encodeCall(house.bid, (id, payer)));
        require(
            !ok && house.auction(id).winner.amount == 0,
            "collection override cannot be skipped for scope0"
        );
        resolver.clearPrimaryAssignment(CLASS, 1, 2);
        _custodyBid(id, payer);
        _end(id);
        house.settle(id);
        require(
            core.ownerOf(1) == payer && _counter() == 1,
            "actual default precedence restored without new mint"
        );
    }

    function testCurrentTemplateDriftStaysInsideSignedFamilyAndOriginalEvidenceRemains() public {
        bytes32 old = _template(9, true);
        bytes32 id = _acquire(_plan(9, address(this), 150));
        _custodyBid(id, payer);
        _end(id);
        _fixed(11, address(0xDC51));
        (bool ok,) = address(house).call(abi.encodeCall(house.settle, (id)));
        require(
            !ok && recorder.totalOfficialSettled(address(0)) == 0
                && core.ownerOf(1) == address(house),
            "PROFILE replacement cannot masquerade as signed TEMPLATE family"
        );
        bytes32 current = _template(9, false);
        StreamSaleTemplate.Selection memory selected = _selected(9);
        (, bytes32 key) = house.settle(id);
        require(
            current != old && house.originalAuctionRights(id).templateId == old
                && recorder.settlementResult(key).profileId == selected.profileId
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 1000
                && _counter() == 1 && royalty.royaltySnapshot(1).exists,
            "ALLOW_CURRENT admits current template with original declaration and custody evidence"
        );
    }

    function testPostEscrowContestRollsBackMaterializationAndExactSafeRetryKeepsOriginalSnapshot()
        public
    {
        _template(8, true);
        StreamSaleTemplate.Selection memory selected = _selected(8);
        bytes32 id = _acquire(_plan(8, address(this), 150));
        bytes32 snapshot = keccak256(abi.encode(royalty.royaltySnapshot(1)));
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xCA41;
        keys[1] = 0xCA42;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 203);
        vm.deal(address(safe), 1 ether);
        require(
            executeSafe(
                safe, keys, address(house), 1000, abi.encodeCall(house.bid, (id, address(safe))), 0
            )
        );
        _end(id);
        uint256 nonce = safe.nonce();
        bytes memory original = _safeCall(safe, keys, 0, abi.encodeCall(house.settle, (id)));
        uint256 count = factory.profileCount();
        require(
            address(escrow).balance == 0 && !factory.profileExists(selected.profileId)
                && _counter() == 1,
            "exact pre-payment materialization and escrow baseline"
        );
        platform.failAfterFunding(address(escrow));
        calls.expectCall(
            address(escrow),
            1000,
            abi.encodeCall(escrow.creditNative, (CLASS, selected.profileId, selected.wallet, true)),
            2
        );
        (bool ok,) = address(safe).call(original);
        require(
            !ok && safe.nonce() == nonce && house.auction(id).status == 1
                && core.ownerOf(1) == address(house) && factory.profileCount() == count
                && !factory.profileExists(selected.profileId)
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 0
                && address(escrow).balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && manager.nextOperationNonce() == 1 && _counter() == 1,
            "real late escrow failure rolls back materialization, payment and replay without undoing original mint"
        );
        platform.failAfterFunding(address(0));
        bytes memory out;
        (ok, out) = address(safe).call(original);
        require(
            ok && abi.decode(out, (bool)) && safe.nonce() == nonce + 1
                && core.ownerOf(1) == address(safe) && factory.profileCount() == count + 1
                && factory.profileExists(selected.profileId)
                && escrow.escrowOwed(CLASS, selected.profileId, selected.wallet, address(0)) == 1000
                && recorder.totalOfficialSettled(address(0)) == 1000 && _counter() == 1
                && manager.nextOperationNonce() == 1
                && keccak256(abi.encode(royalty.royaltySnapshot(1))) == snapshot,
            "byte-identical Safe retry materializes and pays once, original snapshot unchanged"
        );
    }
}
