// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/NativeCuratedAuctionFixture.sol";

contract StreamCurrentNativeCuratedAuctionTest is NativeCuratedAuctionFixture {
    function testTwoDisjointSelectedWorksCompleteWithSequentialTokensAndClearedAdmission() public {
        Plan memory one = _plan(true, 1);
        bytes32 first = _open(one);
        Plan memory two = _plan(false, 1);
        bytes32 second = _open(two);
        require(
            one.selection.contentId != two.selection.contentId && one.saleId != two.saleId
                && core.lastAllocatedTokenId() == 0,
            "disjoint original pieces without token reservations"
        );
        _bidCurated(first, payer);
        _bidCurated(second, payer);
        _endCurated(first);
        (uint256 a, bytes32 keyA) = house.settle(first);
        require(
            manager.preparedNativeContentAdmission() == 0
                && manager.activePreparedNativeContent().operationRoot == 0,
            "first admission completely cleared"
        );
        (uint256 b, bytes32 keyB) = house.settle(second);
        require(
            a == 1 && b == 2 && keyA != keyB && core.collectionNextSerial(1) == 3
                && manager.nextOperationNonce() == 2 && ledger.counterValue(_counterKey(one)) == 1
                && ledger.counterValue(_counterKey(two)) == 1 && core.tokenData(a).length == 0
                && keccak256(core.tokenData(b)) == two.selection.tokenDataHash
                && wallet.balance == 2000 && recorder.totalOfficialSettled(address(0)) == 2000,
            "two paid content operations and sequential identity"
        );
    }

    function testActiveClaimedManifestWithoutExactRetainedRowsCannotOpen() public {
        Plan memory p = _unconfiguredPlan(false);
        FalseCuratedManifest liar =
            new FalseCuratedManifest(p.gate.publication(), p.gate.gateConfigHash());
        p.gate = StreamNativeAuctionContentGate(address(liar));
        p = _configure(p, 1);
        (bool ok,) = address(house).call(_opening(p));
        require(
            !ok && registry.moduleRecord(address(liar)).status == ModuleRegistryStatus.ACTIVE
                && manager.nextOperationNonce() == 0 && core.lastAllocatedTokenId() == 0,
            "ACTIVE interface claims do not replace full published bytes"
        );
    }

    function testActualSignedPayerSettlesAfterBidDeadlineWithOriginalExecutor() public {
        Plan memory p = _plan(false, 1);
        bytes32 id = _open(p);
        IStreamNativeEnglishAuction.BidAuthorization memory a =
            IStreamNativeEnglishAuction.BidAuthorization(
                id,
                house.auction(id).configHash,
                payer,
                address(this),
                payer,
                1000,
                100,
                keccak256("curated signed payer"),
                2000,
                91000
            );
        bytes memory signed = _sig(PAYER_KEY, house.bidAuthorizationDigest(a));
        vm.deal(address(this), 1100);
        house.bidSigned{ value: 1100 }(a, signed);
        _endCurated(id);
        vm.prank(address(0xAB17));
        (uint256 token, bytes32 key) = house.settle(id);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            recorder.settlementResult(key);
        require(
            token == 1 && core.ownerOf(token) == payer
                && keccak256(core.tokenData(token)) == p.selection.tokenDataHash
                && result.executor == address(this) && result.amount == 1000
                && ledger.counterValue(_counterKey(p)) == 1,
            "permissionless actual content settlement preserves signed winner executor"
        );
    }

    function testActualFullManifestZeroIdEmptyWorkAndOriginalContentReceipt() public {
        Plan memory p = _plan(true, 1);
        bytes32 id = _open(p);
        require(
            core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1,
            "publication does not reserve token identity"
        );
        require(
            house.auction(id).saleId == p.saleId
                && keccak256(abi.encode(house.curatedSelection(id)))
                    == keccak256(abi.encode(p.selection)),
            "original selected proof"
        );
        _bidCurated(id, payer);
        _endCurated(id);
        vm.recordLogs();
        (uint256 token, bytes32 key) = house.settle(id);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 contentFound;
        uint256 originalFound;
        bytes32 originalEvent = keccak256(
            "PreparedNativeRevenueRecorded(bytes32,bytes32,bytes32,(address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32))"
        );
        bytes32 contentEvent = keccak256(
            "PreparedNativeContentRecorded(bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32))"
        );
        for (uint256 n; n < logs.length; ++n) {
            if (logs[n].emitter != address(recorder)) continue;
            if (logs[n].topics.length == 3 && logs[n].topics[0] == contentEvent) {
                StreamPreparedNativeContentTypes.Facts memory c =
                    abi.decode(logs[n].data, (StreamPreparedNativeContentTypes.Facts));
                require(
                    c.operationRoot != 0 && c.gate == address(p.gate)
                        && c.gateCodeHash == address(p.gate).codehash
                        && c.gateConfigHash == p.gate.gateConfigHash()
                        && c.manifestRoot == p.config.contentManifestRoot
                        && c.manifestHash == keccak256(p.gate.manifestBytes())
                        && c.counterId == p.counter && c.contentId == 0
                        && c.tokenDataHash == keccak256("")
                        && c.contentLeaf == p.config.artworkCommitment
                        && c.contextHash == _contextOf(p),
                    "complete independently attributed content facts"
                );
                bytes32 hash = keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_FACTS_V1"), block.chainid, c
                    )
                );
                require(
                    logs[n].topics[1] == key && logs[n].topics[2] == hash
                        && recorder.preparedNativeContentHash(key) == hash,
                    "full original content record"
                );
                ++contentFound;
            }
            if (
                logs[n].topics.length == 4 && logs[n].topics[0] == originalEvent
                    && logs[n].topics[1] == key
            ) {
                require(logs[n].data.length == 1152, "exact original record width");
                (
                    StreamPreparedNativeSettlementTypes.Facts memory f,
                    StreamPreparedNativeSettlementTypes.Intent memory i
                ) = abi.decode(
                    logs[n].data,
                    (
                        StreamPreparedNativeSettlementTypes.Facts,
                        StreamPreparedNativeSettlementTypes.Intent
                    )
                );
                require(
                    f.tokenId == token && f.tokenDataHash == keccak256("")
                        && i.contentSelectionHash == p.config.artworkCommitment
                        && i.contentSelectionHash != f.tokenDataHash
                        && f.intentHash
                            == keccak256(
                                abi.encode(
                                    keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_INTENT_V1"),
                                    block.chainid,
                                    address(house),
                                    address(recorder),
                                    i
                                )
                            ),
                    "bytes hash and original leaf stay distinct"
                );
                ++originalFound;
            }
        }
        require(
            contentFound == 1 && originalFound == 1 && token == 1 && core.ownerOf(token) == payer
                && core.tokenData(token).length == 0 && ledger.counterValue(_counterKey(p)) == 1,
            "actual prepared empty work and cap1"
        );
        require(
            wallet.balance == 1000 && recorder.totalOfficialSettled(address(0)) == 1000
                && house.totalBuyerLiabilities() == 0
                && manager.activePreparedNativeContent().operationRoot == 0
                && manager.preparedNativeContentAdmission() == 0,
            "accounting and cleared content admission"
        );
        (uint256 again, bytes32 same) = house.settle(id);
        require(
            again == token && same == key && manager.nextOperationNonce() == 1
                && ledger.counterValue(_counterKey(p)) == 1,
            "terminal replay has no second mint"
        );
    }

    function testFuzzWrongSelectedBytesOrProofPreservesExactSignedOpening(uint8 field) public {
        Plan memory p = _plan(false, 1);
        (
            IStreamNativeEnglishAuction.CreationAuthorization memory a,
            bytes memory platform,
            bytes memory artist
        ) = _approval(p);
        bytes memory original = abi.encodeCall(
            house.registerCuratedAuction,
            (p.config, p.artwork, p.selection, p.nonce, a, platform, artist)
        );
        if (field % 3 == 0) p.artwork = bytes("changed work");
        else if (field % 3 == 1) p.selection.contentId = bytes32(uint256(2));
        else p.selection.proof[0] = bytes32(uint256(99));
        (bool ok,) = address(house)
            .call(
                abi.encodeCall(
                    house.registerCuratedAuction,
                    (p.config, p.artwork, p.selection, p.nonce, a, platform, artist)
                )
            );
        require(!ok && core.lastAllocatedTokenId() == 0, "invalid bytes/proof never admitted");
        (ok,) = address(house).call(original);
        require(ok, "original signed opening retries unchanged");
        require(manager.nextOperationNonce() == 0, "opening only never consumes mint nonce");
    }

    function testWrongActualCapAndChangedNextSaleCannotAdmitPublishedRoot() public {
        Plan memory bad = _plan(false, 2);
        (bool ok,) = address(house).call(_opening(bad));
        require(!ok, "actual counter cap2 rejected");
        Plan memory p = _plan(false, 1);
        bytes memory stale = _opening(p);
        Plan memory other = _plan(true, 1);
        bytes32 id = _open(other);
        house.cancel(id, keccak256("unsold"));
        (ok,) = address(house).call(stale);
        require(
            !ok && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0,
            "no sale nonce reservation or root rebinding"
        );
    }

    function testOrdinaryManagerEntriesCannotBypassContentAdmission() public {
        Plan memory p = _plan(false, 1);
        bytes32 id = _open(p);
        (IStreamMintManager.MintBatch memory b, bytes memory g) =
            _batchFor(p, keccak256("unpaid attempt"));
        bytes memory data = abi.encodeCall(manager.executeSingleStepMint, (b, g));
        vm.prank(address(house));
        (bool ok,) = address(manager).call(data);
        require(!ok, "ordinary immediate path lacks admission");
        data = abi.encodeCall(manager.executePreparedMint, (b, g));
        vm.prank(address(house));
        (ok,) = address(manager).call(data);
        require(!ok, "ordinary prepared path lacks admission");
        data = abi.encodeCall(manager.executePreparedNativeMint, (b, g, b.authorizationId));
        vm.prank(address(house));
        (ok,) = address(manager).call(data);
        require(!ok, "exact-data paid path lacks admission");
        require(
            core.lastAllocatedTokenId() == 0 && ledger.counterValue(_counterKey(p)) == 0
                && manager.nextOperationNonce() == 0,
            "all bypass attempts rollback"
        );
        _bidCurated(id, payer);
        _endCurated(id);
        house.settle(id);
        require(
            core.ownerOf(1) == payer && ledger.counterValue(_counterKey(p)) == 1,
            "actual new path still succeeds"
        );
    }

    function testGateIncidentIsOriginalNonTransientUnlockAndTransientReadFailureIsNot() public {
        Plan memory p = _plan(false, 1);
        bytes32 id = _open(p);
        _bidCurated(id, payer);
        _endCurated(id);
        (bool ok,) = address(house).call(abi.encodeCall(house.unlockNoMint, (id, uint8(5))));
        require(!ok, "active gate not an incident");
        bytes memory originalCode = address(p.gate).code;
        vm.etch(address(p.gate), hex"60006000fd");
        (ok,) = address(house).call(abi.encodeCall(house.settle, (id)));
        require(!ok, "runtime/read failure blocks settlement");
        (ok,) = address(house).call(abi.encodeCall(house.unlockNoMint, (id, uint8(5))));
        require(!ok, "runtime/read failure is not positive incident evidence");
        vm.etch(address(p.gate), originalCode);
        _status(address(p.gate), ModuleRegistryStatus.INCIDENT_REVOKED);
        (ok,) = address(house).call(abi.encodeCall(house.settle, (id)));
        require(
            !ok && wallet.balance == 0 && manager.nextOperationNonce() == 0,
            "actual current gate revoked"
        );
        house.unlockNoMint(id, 5);
        require(
            house.refundableBalance(p.saleId, payer) == 1100 && house.auction(id).status == 6
                && ledger.counterValue(_counterKey(p)) == 0,
            "full original bid and fee credit"
        );
        vm.prank(payer);
        house.claimRefund(p.saleId, payable(payer));
        require(house.totalBuyerLiabilities() == 0, "credit escape remains available");
    }

    function testSafeContentCompletionRollsBackCounterPaymentAndIdenticalTransactionRetries()
        public
    {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE81;
        keys[1] = 0x5AFE82;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 881);
        Plan memory p = _plan(false, 1);
        bytes32 id = _open(p);
        vm.deal(address(safe), 1 ether);
        bytes memory bidData = abi.encodeCall(house.bid, (id, address(0)));
        bytes32 bidHash = safe.getTransactionHash(
            address(house), 1100, bidData, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );
        require(
            safe.execTransaction(
                address(house),
                1100,
                bidData,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, bidHash)
            ),
            "actual Safe content bid"
        );
        _endCurated(id);
        uint256 nonce = safe.nonce();
        bytes memory settleData = abi.encodeCall(house.settle, (id));
        bytes32 hash = safe.getTransactionHash(
            address(house), 0, settleData, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory exact = abi.encodeCall(
            safe.execTransaction,
            (
                address(house),
                0,
                settleData,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, hash)
            )
        );
        entropy.configure(100, 1, true, false);
        (bool ok,) = address(safe).call(exact);
        require(
            !ok && safe.nonce() == nonce && house.auction(id).status == 1
                && house.totalBuyerLiabilities() == 1100 && core.collectionNextSerial(1) == 1
                && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0
                && ledger.counterValue(_counterKey(p)) == 0 && wallet.balance == 0
                && recorder.totalOfficialSettled(address(0)) == 0
                && manager.activePreparedNativeContent().operationRoot == 0
                && manager.preparedNativeContentAdmission() == 0,
            "full paid content rollback"
        );
        entropy.configure(100, 1, false, false);
        bytes memory raw;
        (ok, raw) = address(safe).call(exact);
        require(
            ok && raw.length == 32 && abi.decode(raw, (bool)) && safe.nonce() == nonce + 1
                && safe.getThreshold() == 2 && core.ownerOf(1) == address(safe)
                && ledger.counterValue(_counterKey(p)) == 1 && wallet.balance == 1000
                && manager.preparedNativeContentAdmission() == 0,
            "same signed Safe retry and normal guard cleanup"
        );
    }
}

/// @dev Adversarial registered publisher: all fixed claims are correct, retained bytes are not.
contract FalseCuratedManifest is IStreamNativeAuctionContentGate {
    StreamPreparedNativeContentTypes.Publication private _p;
    bytes32 public override gateConfigHash;

    constructor(StreamPreparedNativeContentTypes.Publication memory p, bytes32 config) {
        _p = p;
        gateConfigHash = config;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamMintGate).interfaceId
            || id == type(IStreamNativeAuctionContentGate).interfaceId;
    }

    function publication()
        external
        view
        override
        returns (StreamPreparedNativeContentTypes.Publication memory)
    {
        return _p;
    }

    function itemCount() external pure override returns (uint256) {
        return 3;
    }

    function manifestBytes() external pure override returns (bytes memory) {
        return abi.encode(new StreamPreparedNativeContentTypes.Row[](0));
    }

    function validateMint(
        address,
        address,
        uint256,
        bytes32,
        address,
        address,
        address[] calldata,
        address[] calldata,
        bytes32,
        bytes32,
        bytes calldata
    ) external pure override returns (GateResult memory r) {
        r.maxQuantity = 1;
        r.gateHash = bytes32(uint256(1));
        r.nullifiers = new bytes32[](0);
    }
}
