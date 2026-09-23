// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationFloor.t.sol";

/// @notice Actual Floor persistence and literal receipt/preparation oracles.
/// @dev The unchanged typed Core/Recorder/Registry/provider boundaries authenticate the original
/// paths but do not claim native documentary evidence, collector gas or full commerce acceptance.
contract StreamConservationFloorPersistenceTest is CharacterizationTestBase {
    event PersistenceGas(bytes32 indexed path, uint256 gasUsed);
    FloorCoreBoundary private core;
    MetadataExecutorBoundary private executor;
    FloorRegistryBoundary private registry;
    FloorManagerBoundary private manager;
    FloorMetadataBoundary private metadata;
    FloorProviderBoundary private provider;
    FloorRecorderBoundary private recorder;
    FloorClearingBoundary private sale;
    StreamConservationFloor private floor;
    bytes32 private constant LITE = keccak256("MUSEUM_GRADE_LITE");
    bytes32 private constant FULL = keccak256("MUSEUM_GRADE");
    bytes32 private constant WAIVED = keccak256("CONSERVATION_WAIVED");

    function setUp() public {
        vm.warp(1000);
        core = new FloorCoreBoundary();
        executor = new MetadataExecutorBoundary();
        registry = new FloorRegistryBoundary();
        manager = new FloorManagerBoundary(address(core));
        metadata = new FloorMetadataBoundary();
        provider = new FloorProviderBoundary(address(core), address(metadata));
        recorder = new FloorRecorderBoundary(address(core), address(registry));
        sale = new FloorClearingBoundary(address(core), address(manager), address(recorder));
        registry.register(address(recorder), false);
        registry.register(address(sale), true);
        core.setPointer(keccak256("MODULE_REGISTRY"), address(registry));
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        floor = new StreamConservationFloor(
            address(core),
            address(executor),
            _gas("CONSERVATION_FLOOR_READ_GAS", 300000),
            _gas("CONSERVATION_FLOOR_PRODUCER_GAS", 1000000),
            _gas("CONSERVATION_FLOOR_CALL_GAS", 6000000)
        );
        core.setFloor(address(floor));
        _append(address(metadata), address(provider));
    }

    function testFreshWaivedInlineReceiptMatchesLiteralOriginalWordsAndEvents() public {
        core.setTier(1, WAIVED);
        (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(1);
        (bytes32 key, F.FirstSaleReceipt memory first, F.SettlementReceipt memory expected) =
            _expected(c, r, WAIVED);
        vm.recordLogs();
        uint256 beforeGas = gasleft();
        bytes32 actual = recorder.record(floor, c, r);
        uint256 used = beforeGas - gasleft();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertExact(key, first, expected, actual);
        require(logs.length == 3, "prepared, first and settlement events");
        require(
            logs[0].topics[1] == key && logs[0].topics[3] == r.settlementKey,
            "exact original preparation identity"
        );
        require(
            logs[1].topics[1] == bytes32(uint256(1)) && logs[1].topics[2] == first.receiptHash,
            "exact first identity"
        );
        require(
            keccak256(logs[1].data) == keccak256(abi.encode(first, uint16(1))),
            "literal complete first event"
        );
        require(
            logs[2].topics[1] == r.settlementKey && logs[2].topics[2] == expected.receiptHash,
            "exact settlement identity"
        );
        require(
            keccak256(logs[2].data) == keccak256(abi.encode(expected, uint16(1))),
            "literal complete settlement event"
        );
        for (uint256 i; i < logs.length; ++i) {
            require(logs[i].emitter == address(floor));
        }
        emit PersistenceGas(keccak256("WAIVED_INLINE_FIRST"), used);
    }

    function testWaivedPreparationIsIdempotentAndDoesNotCreatePaidHistory() public {
        core.setTier(1, WAIVED);
        (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(2);
        (bytes32 key, F.FirstSaleReceipt memory first, F.SettlementReceipt memory expected) =
            _expected(c, r, WAIVED);
        uint256 beforeGas = gasleft();
        require(floor.preparePrimarySale(address(recorder), c, r) == key);
        uint256 used = beforeGas - gasleft();
        require(floor.primarySalePrepared(key) && floor.firstSale(1).receiptHash == 0);
        require(
            !recorder.settlementConsumed(r.settlementKey)
                && floor.settlementReceipt(r.settlementKey).receiptHash == 0
        );
        vm.recordLogs();
        require(floor.preparePrimarySale(address(recorder), c, r) == key);
        require(vm.getRecordedLogs().length == 0, "existing immutable key is not rewritten");
        _assertExact(key, first, expected, recorder.record(floor, c, r));
        emit PersistenceGas(keccak256("WAIVED_PREPARATION"), used);
    }

    function testNonWaivedAllocatedTokenRetainsFullSourceAndReleaseFields() public {
        (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(3);
        c.orchestrationOrder = 2;
        c.sale.tokenId = 10;
        core.setToken(10, address(this), 1);
        (bytes32 key, F.FirstSaleReceipt memory first, F.SettlementReceipt memory expected) =
            _expected(c, r, LITE);
        require(floor.preparePrimarySale(address(recorder), c, r) == key);
        _assertExact(key, first, expected, recorder.record(floor, c, r));
        require(
            first.sourceId == 1 && first.facts.artistId != 0 && expected.tokenId == 10
                && expected.releaseReceiptHash != 0,
            "populated optional fields exercised"
        );
    }

    function testLateFailureRestoresFreshPreparationAndIdenticalPaidRequestRetries() public {
        core.setTier(1, WAIVED);
        (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(4);
        (bytes32 key, F.FirstSaleReceipt memory first, F.SettlementReceipt memory expected) =
            _expected(c, r, WAIVED);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "downstream mint failed"));
        recorder.recordThenFail(floor, c, r);
        require(!floor.primarySalePrepared(key) && !recorder.settlementConsumed(r.settlementKey));
        require(
            floor.firstSale(1).receiptHash == 0
                && floor.settlementReceipt(r.settlementKey).receiptHash == 0
        );
        _assertExact(key, first, expected, recorder.record(floor, c, r));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationFloor.ConservationFloorAlreadyRecorded.selector, r.settlementKey
            )
        );
        recorder.record(floor, c, r);
        _assertExact(key, first, expected, expected.receiptHash);
    }

    function testRetainedWaivedHistorySurvivesNewAuthenticatedSourceHead() public {
        core.setTier(1, WAIVED);
        (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) = _pair(5);
        (bytes32 key, F.FirstSaleReceipt memory first, F.SettlementReceipt memory expected) =
            _expected(c, r, WAIVED);
        _assertExact(key, first, expected, recorder.record(floor, c, r));
        FloorMetadataBoundary nextMetadata = new FloorMetadataBoundary();
        FloorProviderBoundary nextProvider =
            new FloorProviderBoundary(address(core), address(nextMetadata));
        core.setPointer(keccak256("COLLECTION_METADATA"), address(nextMetadata));
        _append(address(nextMetadata), address(nextProvider));
        (T.ERC20SettlementCandidate memory c2, T.PrimarySettlementResult memory r2) = _pair(6);
        recorder.record(floor, c2, r2);
        _assertExact(key, first, expected, expected.receiptHash);
        require(
            floor.sourceCount() == 2
                && floor.settlementReceipt(r2.settlementKey).firstSaleReceiptHash
                    == first.receiptHash,
            "new source cannot rewrite the first evidence denominator"
        );
    }

    function testFuzzWaivedOptionalTokenHasExactOriginalSeed(uint32 nonce, uint64 token) public {
        core.setTier(1, WAIVED);
        (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r) =
            _pair(uint256(nonce) + 1);
        if (token != 0) {
            c.orchestrationOrder = 2;
            c.sale.tokenId = token;
            core.setToken(token, address(this), 1);
        }
        (bytes32 key, F.FirstSaleReceipt memory first, F.SettlementReceipt memory expected) =
            _expected(c, r, WAIVED);
        _assertExact(key, first, expected, recorder.record(floor, c, r));
    }

    function _assertExact(
        bytes32 key,
        F.FirstSaleReceipt memory first,
        F.SettlementReceipt memory expected,
        bytes32 actual
    ) private view {
        require(floor.primarySalePrepared(key), "literal original preparation key");
        require(
            keccak256(abi.encode(floor.firstSale(1))) == keccak256(abi.encode(first)),
            "every original first-sale word"
        );
        require(
            actual == expected.receiptHash
                && keccak256(abi.encode(floor.settlementReceipt(expected.settlementKey)))
                    == keccak256(abi.encode(expected)),
            "every original settlement word including defaults"
        );
    }

    function _expected(
        T.ERC20SettlementCandidate memory c,
        T.PrimarySettlementResult memory r,
        bytes32 tier
    )
        private
        view
        returns (bytes32 key, F.FirstSaleReceipt memory first, F.SettlementReceipt memory receipt)
    {
        StreamConservationFloor.CollectionPreparation memory collection;
        collection.exists = true;
        collection.collectionId = c.sale.collectionId;
        collection.tier = tier;
        (uint64 sourceId, bytes32 sourceHead) = floor.sourceSetHead();
        collection.sourceSetHash = sourceHead;
        StreamConservationFloor.ReleasePreparation memory release;
        F.ReleaseFloorReceipt memory releaseReceipt;
        if (tier != WAIVED) {
            collection.sourceId = sourceId;
            collection.facts = provider.collectionFacts();
            release.exists = true;
            release.collectionId = c.sale.collectionId;
            release.tier = tier;
            release.sourceId = sourceId;
            release.sourceSetHash = sourceHead;
            (release.context, release.facts) = provider.releaseFacts();
            release.releaseKey = keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONSERVATION_RELEASE_V1"),
                    block.chainid,
                    address(core),
                    c.sale.collectionId,
                    release.context.scopeSubject,
                    release.context.membershipHash,
                    release.context.mediaInventoryHash,
                    release.context.scriptSourceHash,
                    release.context.scriptWork
                )
            );
            releaseReceipt = F.ReleaseFloorReceipt(
                0,
                release.releaseKey,
                c.sale.collectionId,
                tier,
                address(recorder),
                r.settlementKey,
                1000,
                sourceId,
                sourceHead,
                release.context,
                release.facts
            );
            releaseReceipt.receiptHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONSERVATION_RELEASE_RECEIPT_V1"),
                    block.chainid,
                    address(core),
                    address(floor),
                    releaseReceipt
                )
            );
        }
        first = F.FirstSaleReceipt(
            0,
            c.sale.collectionId,
            tier,
            address(recorder),
            r.settlementKey,
            1000,
            collection.sourceId,
            sourceHead,
            collection.facts
        );
        first.receiptHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_FIRST_SALE_V1"),
                block.chainid,
                address(core),
                address(floor),
                first
            )
        );
        StreamConservationFloor.SalePreparation memory p;
        p.exists = true;
        p.seed = F.SettlementReceipt(
            0,
            address(recorder),
            address(recorder).codehash,
            r.settlementKey,
            keccak256(abi.encode(c)),
            r.candidateCommitment,
            keccak256(abi.encode(r)),
            c.sale.collectionId,
            c.sale.tokenId,
            tier,
            0,
            0,
            0
        );
        p.collectionEvidence = keccak256(abi.encode(collection));
        p.releaseEvidence = release.exists ? keccak256(abi.encode(release)) : bytes32(0);
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_PREPARED_SALE_V1"),
                block.chainid,
                address(core),
                address(floor),
                p
            )
        );
        // Allocate independently: assigning p.seed and mutating it would change the oracle input.
        receipt = abi.decode(abi.encode(p.seed), (F.SettlementReceipt));
        receipt.recordedAt = 1000;
        receipt.firstSaleReceiptHash = first.receiptHash;
        receipt.releaseReceiptHash = releaseReceipt.receiptHash;
        receipt.receiptHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_SETTLEMENT_RECEIPT_V1"),
                block.chainid,
                address(core),
                address(floor),
                receipt
            )
        );
    }

    function _gas(string memory name, uint256 value)
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(name, value, value, 2);
    }

    function _append(address m, address p) private {
        uint64 predecessor = floor.sourceCount();
        (bytes32 s, bytes32 o, bytes32 n) = floor.sourceTransition(m, p, predecessor);
        executor.execute(
            address(floor), abi.encodeCall(floor.appendSource, (m, p, predecessor)), s, o, n
        );
    }

    function _pair(uint256 nonce)
        private
        view
        returns (T.ERC20SettlementCandidate memory c, T.PrimarySettlementResult memory r)
    {
        N.NativeSettlementCandidate memory n = _native(nonce);
        return (StreamNativeSettlementHash.accountingContext(n), _result(n));
    }

    function _native(uint256 nonce) private view returns (N.NativeSettlementCandidate memory n) {
        n.saleAdapter = address(sale);
        n.executor = address(this);
        n.sale = T.PrimarySale(
            bytes32(uint256(55)),
            keccak256("PRIMARY_SALE"),
            0,
            1,
            0,
            nonce,
            address(this),
            address(this),
            address(0xcafe),
            10,
            bytes32(uint256(56))
        );
        n.lifecycleBinding = N.SaleLifecycleBinding(1, 1);
        n.executionBinding = T.SaleExecutionBinding(0, nonce, 1, bytes32(uint256(57)));
        n.orchestrationOrder = 1;
        n.mintManager = address(manager);
        n.operationIdentityCommitment = keccak256(abi.encode("root", nonce));
        n.operationId = keccak256(abi.encode("operation", nonce));
        n.currentPolicyHash = bytes32(uint256(58));
        n.boundPolicyHash = bytes32(uint256(59));
        n.rights = T.PrimaryRights(
            bytes32(uint256(60)), address(0xbeef), 0, bytes32(uint256(61)), bytes32(uint256(62))
        );
        n.saleExecutionHash = bytes32(uint256(63));
        n.executionBinding.executionId = StreamNativeSettlementHash.executionId(n);
    }

    function _result(N.NativeSettlementCandidate memory n)
        private
        view
        returns (T.PrimarySettlementResult memory r)
    {
        r = T.PrimarySettlementResult(
            StreamNativeSettlementHash.candidateCommitment(address(recorder), n),
            StreamPrimarySettlementHash.settlementKey(
                address(recorder), n.saleAdapter, n.executionBinding.executionId
            ),
            n.rights.profileId,
            n.rights.wallet,
            address(0),
            n.sale.amount,
            n.executor,
            n.executionBinding.executionId,
            false,
            n.operationIdentityCommitment,
            n.currentPolicyHash,
            n.boundPolicyHash
        );
    }
}
