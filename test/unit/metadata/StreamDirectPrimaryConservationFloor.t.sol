// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationFloor.t.sol";
import {
    StreamDirectPrimarySaleTypes as D
} from "../../../smart-contracts/interfaces/stream/revenue/StreamDirectPrimarySaleTypes.sol";
import {
    StreamDirectPrimaryConservationTypes as DF
} from "../../../smart-contracts/interfaces/stream/metadata/StreamDirectPrimaryConservationTypes.sol";

contract DirectFloorRegistryBoundary {
    mapping(address => StreamModuleRecord) private _rows;

    function register(address target, bool direct) external {
        _rows[target] = StreamModuleRecord(
            ModuleRegistryStatus.ACTIVE,
            direct ? D.MODULE_TYPE : keccak256("PRIMARY_SALE_SETTLEMENT"),
            direct ? D.MODULE_VERSION : keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            direct
                ? type(IStreamDirectPrimarySaleReceipt).interfaceId
                : type(IStreamPrimarySaleSettlement).interfaceId,
            0,
            target.codehash,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            "ipfs://typed-boundary",
            1,
            1,
            1
        );
    }

    function moduleRecord(address target) external view returns (StreamModuleRecord memory) {
        return _rows[target];
    }

    function setRecord(address target, StreamModuleRecord calldata row) external {
        _rows[target] = row;
    }
}

contract DirectFloorManagerBoundary is FloorManagerBoundary {
    bool private _authorizationUsed = true;

    constructor(address c) FloorManagerBoundary(c) { }

    function setAuthorizationUsed(bool used_) external {
        _authorizationUsed = used_;
    }

    function isAuthorizationUsed(bytes32) external view returns (bool) {
        return _authorizationUsed;
    }
}

/// @dev Explicit mutable test boundary for a code-admitted DIRECT producer. This fixture does not
/// prove an actual adapter's signature, payment, mint-vector or immutable-storage implementation.
contract DirectFloorAdapterBoundary is IStreamDirectPrimarySaleReceipt {
    D.Bindings private _bindings;
    mapping(bytes32 => D.Receipt) private _receipts;
    bool public badHash;
    bool public badIdentity;
    uint8 public badRead;

    constructor(address core_, address manager, bytes32 kind) {
        _bindings =
            D.Bindings(core_, core_.codehash, manager, manager.codehash, block.chainid, kind);
    }

    // Original products expose ERC165 and the receipt interface, without optional IStreamModule
    // self-report getters. Registry admission supplies their exact role/version/runtime identity.
    function supportsInterface(bytes4 id) external view override returns (bool) {
        if (badIdentity) return false;
        return id == 0x01ffc9a7 || id == type(IStreamDirectPrimarySaleReceipt).interfaceId;
    }

    function setBindings(D.Bindings calldata value) external {
        _bindings = value;
    }

    function setFaults(bool hash_, bool identity_, uint8 read_) external {
        badHash = hash_;
        badIdentity = identity_;
        badRead = read_;
    }

    function directPrimaryBindings() external view override returns (D.Bindings memory) {
        if (badRead == 1) assembly { return(0, 160) }
        if (badRead == 6) {
            bytes memory raw = abi.encode(_bindings);
            assembly {
                mstore(add(raw, 32), shl(160, 1))
                return(add(raw, 32), 192)
            }
        }
        if (badRead == 7) assembly { return(0, 224) }
        return _bindings;
    }

    function directPrimarySaleReceipt(bytes32 id)
        external
        view
        override
        returns (D.Receipt memory)
    {
        if (badRead == 2) assembly { return(0, 480) }
        if (badRead == 3) assembly { return(0, 544) }
        if (badRead == 4 || badRead == 5) {
            bytes memory raw = abi.encode(_receipts[id]);
            if (badRead == 4) {
                assembly { mstore(add(raw, 352), 2) }
            } else {
                assembly { mstore(add(raw, 288), shl(160, 1)) }
            }
            assembly { return(add(raw, 32), 512) }
        }
        return _receipts[id];
    }

    function directPrimarySaleReceiptHash(bytes32 id) external view override returns (bytes32) {
        if (badHash) return bytes32(uint256(1));
        if (_receipts[id].amount == 0) return bytes32(0);
        return StreamDirectPrimarySaleHash.receiptHash(_bindings, address(this), id, _receipts[id]);
    }

    function save(bytes32 id, D.Receipt calldata value) external {
        _receipts[id] = value;
    }

    function record(StreamConservationFloor floor, bytes32 id, D.Receipt calldata value)
        external
        returns (bytes32)
    {
        _receipts[id] = value;
        return floor.recordDirectPrimarySale(id);
    }

    function invoke(StreamConservationFloor floor, bytes32 id) external returns (bytes32) {
        return floor.recordDirectPrimarySale(id);
    }

    function recordThenFail(StreamConservationFloor floor, bytes32 id, D.Receipt calldata value)
        external
    {
        _receipts[id] = value;
        floor.recordDirectPrimarySale(id);
        revert("later callback failed");
    }
}

/// @dev Genuine ledger persistence/authentication with typed Core/Manager/registry/source boundaries.
/// Actual native/ERC20/auction product integration is a separate adapter-owner test cohort.
contract StreamDirectPrimaryConservationFloorTest is CharacterizationTestBase {
    FloorCoreBoundary private core;
    MetadataExecutorBoundary private executor;
    DirectFloorRegistryBoundary private registry;
    DirectFloorManagerBoundary private manager;
    FloorMetadataBoundary private metadata;
    FloorProviderBoundary private provider;
    FloorRecorderBoundary private universal;
    StreamConservationFloor private floor;
    DirectFloorAdapterBoundary private nativeAdapter;
    DirectFloorAdapterBoundary private erc20Adapter;
    DirectFloorAdapterBoundary private auctionAdapter;
    bytes32 private constant LITE = keccak256("MUSEUM_GRADE_LITE");
    bytes32 private constant FULL = keccak256("MUSEUM_GRADE");
    bytes32 private constant WAIVED = keccak256("CONSERVATION_WAIVED");

    function setUp() public {
        vm.warp(1000);
        core = new FloorCoreBoundary();
        executor = new MetadataExecutorBoundary();
        registry = new DirectFloorRegistryBoundary();
        manager = new DirectFloorManagerBoundary(address(core));
        metadata = new FloorMetadataBoundary();
        provider = new FloorProviderBoundary(address(core), address(metadata));
        universal = new FloorRecorderBoundary(address(core), address(registry));
        nativeAdapter =
            new DirectFloorAdapterBoundary(address(core), address(manager), D.NATIVE_FIXED_PRICE);
        erc20Adapter =
            new DirectFloorAdapterBoundary(address(core), address(manager), D.ERC20_FIXED_PRICE);
        auctionAdapter =
            new DirectFloorAdapterBoundary(address(core), address(manager), D.ENGLISH_AUCTION);
        registry.register(address(universal), false);
        registry.register(address(nativeAdapter), true);
        registry.register(address(erc20Adapter), true);
        registry.register(address(auctionAdapter), true);
        core.setPointer(keccak256("MODULE_REGISTRY"), address(registry));
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        core.setToken(10, address(this), 2);
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

    function testNativeDirectReceiptAndEventRetainExactOriginalTypedOutcome() public {
        bytes4[5] memory unsupported = [
            bytes4(keccak256("streamModuleType()")),
            bytes4(keccak256("streamModuleVersion()")),
            bytes4(keccak256("streamModuleInterfaceId()")),
            bytes4(keccak256("streamModuleCodeHash()")),
            bytes4(keccak256("streamModuleDeploymentManifestHash()"))
        ];
        for (uint256 i; i < unsupported.length; ++i) {
            (bool ok,) = address(nativeAdapter).staticcall(abi.encodeWithSelector(unsupported[i]));
            require(!ok, "original product has no optional module self-report API");
        }
        D.Receipt memory sale = _sale();
        bytes32 id = bytes32(uint256(1));
        vm.recordLogs();
        bytes32 hash = nativeAdapter.record(floor, id, sale);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        DF.Receipt memory r = floor.directPrimarySaleFloorReceipt(_key(nativeAdapter, id));
        require(hash != 0 && hash == r.receiptHash, "paid typed receipt");
        require(
            r.adapter == address(nativeAdapter)
                && r.adapterCodeHash == address(nativeAdapter).codehash,
            "original caller"
        );
        require(keccak256(abi.encode(r.sale)) == keccak256(abi.encode(sale)), "exact sixteen words");
        require(
            keccak256(abi.encode(r.bindings))
                == keccak256(abi.encode(nativeAdapter.directPrimaryBindings())),
            "exact six words"
        );
        require(
            r.authorizationId == id
                && r.originalReceiptHash == nativeAdapter.directPrimarySaleReceiptHash(id),
            "original hash domain"
        );
        require(
            r.recordedAt == 1000 && r.effectiveTier == LITE
                && core.declaredConservationTier(1) == 0,
            "prospective lite"
        );
        require(
            r.firstSaleReceiptHash == floor.firstSale(1).receiptHash && r.releaseReceiptHash != 0,
            "floor links"
        );
        require(
            floor.firstSale(1).settlementKey == r.directKey
                && floor.firstSale(1).recorder == address(nativeAdapter),
            "direct first winner"
        );
        require(
            logs.length == 3 && logs[2].topics[1] == r.directKey && logs[2].topics[2] == hash,
            "direct event identity"
        );
        (DF.Receipt memory emitted, uint16 schema) = abi.decode(logs[2].data, (DF.Receipt, uint16));
        require(
            schema == 1 && keccak256(abi.encode(emitted)) == keccak256(abi.encode(r)),
            "complete original event"
        );
        r.receiptHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"),
                        block.chainid,
                        address(core),
                        address(floor),
                        r
                    )
                ),
            "independent permanent hash"
        );
    }

    function testERC20EscrowAndNativeHaveDistinctTypedKeys() public {
        D.Receipt memory sale = _sale();
        bytes32 id = bytes32(uint256(1));
        nativeAdapter.record(floor, id, sale);
        sale.asset = address(metadata);
        sale.escrowed = true;
        erc20Adapter.record(floor, id, sale);
        DF.Receipt memory r = floor.directPrimarySaleFloorReceipt(_key(erc20Adapter, id));
        require(r.sale.asset == address(metadata) && r.sale.escrowed, "actual asset and escrow");
        require(r.directKey != _key(nativeAdapter, id), "product domain");
        require(r.firstSaleReceiptHash == floor.firstSale(1).receiptHash, "shared original first");
    }

    function testDirectAndUniversalGettersAreIsolatedAndSupplementalRejectsDirect() public {
        bytes32 directKey = _record(nativeAdapter, 1);
        require(floor.settlementReceipt(directKey).receiptHash == 0, "no fake universal receipt");
        require(
            floor.directPrimarySaleFloorReceipt(bytes32(uint256(999))).receiptHash == 0,
            "unknown direct empty"
        );
        bytes32 universalKey = _recordUniversal(2);
        require(
            floor.directPrimarySaleFloorReceipt(universalKey).receiptHash == 0,
            "universal is not direct"
        );
        S.NativeSupplementalCandidate memory c;
        S.NativeSupplementalResult memory r;
        c.purchase.floorSettlementKey = directKey;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationFloor.ConservationFloorOriginalReceiptMissing.selector, directKey
            )
        );
        universal.supplement(floor, c, r);
    }

    function testUnknownAndReplayCannotCreateNewPaidLinks() public {
        vm.expectRevert();
        nativeAdapter.invoke(floor, bytes32(uint256(99)));
        bytes32 key = _record(nativeAdapter, 1);
        bytes32 beforeHash = floor.directPrimarySaleFloorReceipt(key).receiptHash;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationFloor.ConservationFloorAlreadyRecorded.selector, key
            )
        );
        nativeAdapter.invoke(floor, bytes32(uint256(1)));
        require(
            floor.directPrimarySaleFloorReceipt(key).receiptHash == beforeHash,
            "immutable paid link"
        );
    }

    function testEOAAndUnregisteredActualCallerAreDenied() public {
        vm.expectRevert();
        floor.recordDirectPrimarySale(bytes32(uint256(1)));
        DirectFloorAdapterBoundary unregistered =
            new DirectFloorAdapterBoundary(address(core), address(manager), D.NATIVE_FIXED_PRICE);
        vm.expectRevert();
        unregistered.record(floor, bytes32(uint256(1)), _sale());
        require(floor.firstSale(1).receiptHash == 0, "no first on denial");
    }

    function testWrongModuleRoleVersionInterfaceAndRuntimeAreDenied() public {
        StreamModuleRecord memory good = registry.moduleRecord(address(nativeAdapter));
        for (uint256 i; i < 4; ++i) {
            StreamModuleRecord memory bad = abi.decode(abi.encode(good), (StreamModuleRecord));
            if (i == 0) bad.moduleType = keccak256("PRIMARY_SALE_SETTLEMENT");
            if (i == 1) bad.moduleVersion = keccak256("unknown version");
            if (i == 2) bad.interfaceId = type(IStreamPrimarySaleSettlement).interfaceId;
            if (i == 3) bad.runtimeCodeHash = bytes32(uint256(999));
            registry.setRecord(address(nativeAdapter), bad);
            vm.expectRevert();
            nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
        }
    }

    function testOriginalAdapterHashAndLiveERC165MustMatch() public {
        nativeAdapter.setFaults(true, false, 0);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
        nativeAdapter.setFaults(false, true, 0);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
    }

    function testMalformedFixedLengthBindingsAndReceiptReadsFailClosed() public {
        for (uint8 i = 1; i <= 7; ++i) {
            nativeAdapter.setFaults(false, false, i);
            vm.expectRevert();
            nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
        }
        require(floor.firstSale(1).receiptHash == 0, "no malformed paid proof");
    }

    function testWrongCoreChainManagerCodeAndProductBindingsAreDenied() public {
        D.Bindings memory good = nativeAdapter.directPrimaryBindings();
        for (uint256 i; i < 6; ++i) {
            D.Bindings memory bad = abi.decode(abi.encode(good), (D.Bindings));
            if (i == 0) bad.core = address(metadata);
            if (i == 1) bad.coreCodeHash = bytes32(uint256(123));
            if (i == 2) ++bad.deploymentChainId;
            if (i == 3) bad.mintManagerCodeHash = bytes32(uint256(123));
            if (i == 4) bad.productKind = keccak256("unknown product");
            if (i == 5) {
                FloorManagerBoundary wrong = new FloorManagerBoundary(address(metadata));
                bad.mintManager = address(wrong);
                bad.mintManagerCodeHash = address(wrong).codehash;
            }
            nativeAdapter.setBindings(bad);
            vm.expectRevert();
            nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
        }
    }

    function testUnusedOriginalOperationAndUncompletedOrWrongCollectionTokenFail() public {
        manager.setUsed(false);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
        manager.setUsed(true);
        for (uint8 lifecycle; lifecycle < 2; ++lifecycle) {
            core.setToken(10, address(this), lifecycle);
            vm.expectRevert();
            nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
        }
        core.setToken(10, address(this), 2);
        D.Receipt memory wrong = _sale();
        wrong.collectionId = 2;
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), wrong);
    }

    function testOriginalAuthorizationMustBeConsumedIndependentlyOfUsedRoot() public {
        manager.setAuthorizationUsed(false);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
        require(
            floor.firstSale(1).receiptHash == 0, "used root cannot replace consumed authorization"
        );
        manager.setAuthorizationUsed(true);
        _record(nativeAdapter, 1);
    }

    function testCompletedBurnedTokenRetainsAuthenticatedCollectionIdentity() public {
        core.setToken(10, address(this), 3);
        bytes32 key = _record(nativeAdapter, 1);
        require(
            floor.directPrimarySaleFloorReceipt(key).sale.tokenId == 10,
            "completed burned identity retained"
        );
    }

    function testPositivePaymentAndNativeVersusERC20AssetAreRequired() public {
        D.Receipt memory sale = _sale();
        sale.amount = 0;
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), sale);
        sale = _sale();
        sale.asset = address(metadata);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), sale);
        sale = _sale();
        vm.expectRevert();
        erc20Adapter.record(floor, bytes32(uint256(1)), sale);
        sale.asset = address(0xcafe);
        vm.expectRevert();
        erc20Adapter.record(floor, bytes32(uint256(1)), sale);
    }

    function testImmediateDeprecatedAndIncidentRevokedCannotRecord() public {
        _status(nativeAdapter, ModuleRegistryStatus.DEPRECATED, 900, 2);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
        _status(erc20Adapter, ModuleRegistryStatus.DEPRECATED, 900, 2);
        D.Receipt memory erc20 = _sale();
        erc20.asset = address(metadata);
        vm.expectRevert();
        erc20Adapter.record(floor, bytes32(uint256(1)), erc20);
        _status(auctionAdapter, ModuleRegistryStatus.INCIDENT_REVOKED, 900, 2);
        vm.expectRevert();
        auctionAdapter.record(floor, bytes32(uint256(1)), _sale());
    }

    function testDeprecatedAuctionRequiresBothOriginalPreDeprecationAnchors() public {
        _status(auctionAdapter, ModuleRegistryStatus.DEPRECATED, 900, 2);
        bytes32 key = _record(auctionAdapter, 1);
        require(
            floor.directPrimarySaleFloorReceipt(key).sale.createdAt == 100,
            "original creation retained"
        );
        D.Receipt memory sale = _sale();
        sale.createdAt = 900;
        vm.expectRevert();
        auctionAdapter.record(floor, bytes32(uint256(2)), sale);
        sale = _sale();
        sale.registryRevision = 2;
        vm.expectRevert();
        auctionAdapter.record(floor, bytes32(uint256(2)), sale);
    }

    function testFutureOrPreRegistrationOriginalLifecycleCannotRecord() public {
        D.Receipt memory sale = _sale();
        sale.createdAt = 1001;
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), sale);
        sale = _sale();
        sale.registryRevision = 2;
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), sale);
        StreamModuleRecord memory row = registry.moduleRecord(address(nativeAdapter));
        row.registeredAt = 200;
        row.statusUpdatedAt = 200;
        registry.setRecord(address(nativeAdapter), row);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
    }

    function testDirectFirstAndReleaseAreReusableByUniversalWithoutRecheckingFirstProof() public {
        bytes32 directKey = _record(nativeAdapter, 1);
        DF.Receipt memory original = floor.directPrimarySaleFloorReceipt(directKey);
        provider.setUnavailable(true, true, false);
        bytes32 universalKey = _recordUniversal(2);
        F.SettlementReceipt memory reused = floor.settlementReceipt(universalKey);
        require(
            reused.firstSaleReceiptHash == original.firstSaleReceiptHash
                && reused.releaseReceiptHash == original.releaseReceiptHash,
            "same original direct floor"
        );
        require(floor.firstSale(1).settlementKey == directKey, "direct remains first");
    }

    function testUniversalFirstAndReleaseAreReusableByDirectWithoutRecheckingFirstProof() public {
        bytes32 universalKey = _recordUniversal(1);
        F.SettlementReceipt memory original = floor.settlementReceipt(universalKey);
        provider.setUnavailable(true, true, false);
        DF.Receipt memory reused = floor.directPrimarySaleFloorReceipt(_record(nativeAdapter, 2));
        require(
            reused.firstSaleReceiptHash == original.firstSaleReceiptHash
                && reused.releaseReceiptHash == original.releaseReceiptHash,
            "same original universal floor"
        );
        require(floor.firstSale(1).settlementKey == universalKey, "universal remains first");
    }

    function testCurrentMappingStillRequiredAndNewMediaRequiresNewProof() public {
        bytes32 key = _record(nativeAdapter, 1);
        bytes32 oldHash = floor.directPrimarySaleFloorReceipt(key).receiptHash;
        provider.setUnavailable(true, true, true);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(2)), _sale());
        (F.ReleaseContext memory context, F.ReleaseFacts memory facts) = provider.releaseFacts();
        context.mediaInventoryHash = keccak256("new actual media");
        provider.setRelease(context, facts);
        provider.setUnavailable(true, true, false);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(2)), _sale());
        provider.setUnavailable(true, false, false);
        bytes32 newKey = _record(nativeAdapter, 2);
        require(
            floor.directPrimarySaleFloorReceipt(newKey).releaseReceiptHash
                != floor.directPrimarySaleFloorReceipt(key).releaseReceiptHash,
            "new paid release"
        );
        require(
            floor.directPrimarySaleFloorReceipt(key).receiptHash == oldHash, "original retained"
        );
    }

    function testFullScriptNeedsReferenceForFirstAndNewRelease() public {
        core.setTier(1, FULL);
        (F.ReleaseContext memory context, F.ReleaseFacts memory facts) = provider.releaseFacts();
        context.scriptWork = true;
        context.scriptSourceHash = keccak256("script and renderer");
        provider.setRelease(context, facts);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), _sale());
        facts.referenceEvidenceHash = keccak256("typed actual reference boundary");
        provider.setRelease(context, facts);
        _record(nativeAdapter, 1);
        context.scriptSourceHash = keccak256("material renderer change");
        facts.referenceEvidenceHash = 0;
        provider.setRelease(context, facts);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(2)), _sale());
    }

    function testWaivedNeedsNoSourceButStillAuthenticatesActualPayment() public {
        core.setTier(1, WAIVED);
        provider.setUnavailable(true, true, true);
        DF.Receipt memory r = floor.directPrimarySaleFloorReceipt(_record(nativeAdapter, 1));
        require(r.effectiveTier == WAIVED && r.releaseReceiptHash == 0, "explicit waived");
        manager.setUsed(false);
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(2)), _sale());
    }

    function testSourceReplacementRetainsOriginalPaidHistoryAfterAllOldCodeDisappears() public {
        bytes32 key = _record(nativeAdapter, 1);
        DF.Receipt memory original = floor.directPrimarySaleFloorReceipt(key);
        F.FirstSaleReceipt memory first = floor.firstSale(1);
        (F.ReleaseContext memory context, F.ReleaseFacts memory facts) = provider.releaseFacts();
        bytes32 releaseKey = _releaseKey(context);
        F.ReleaseFloorReceipt memory release = floor.releaseFloorReceipt(releaseKey);
        FloorMetadataBoundary nextMetadata = new FloorMetadataBoundary();
        FloorProviderBoundary nextProvider =
            new FloorProviderBoundary(address(core), address(nextMetadata));
        context.sourceContextHash = keccak256("benign serving replacement");
        facts.sourceContextHash = context.sourceContextHash;
        nextProvider.setRelease(context, facts);
        nextProvider.setUnavailable(true, true, false);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(nextMetadata));
        _append(address(nextMetadata), address(nextProvider));
        DF.Receipt memory later = floor.directPrimarySaleFloorReceipt(_record(auctionAdapter, 2));
        require(
            later.firstSaleReceiptHash == original.firstSaleReceiptHash
                && later.releaseReceiptHash == original.releaseReceiptHash,
            "same semantic evidence"
        );
        vm.etch(address(nativeAdapter), hex"");
        vm.etch(address(manager), hex"");
        vm.etch(address(provider), hex"");
        vm.etch(address(metadata), hex"");
        vm.expectRevert();
        auctionAdapter.record(floor, bytes32(uint256(3)), _sale());
        require(
            keccak256(abi.encode(floor.directPrimarySaleFloorReceipt(key)))
                == keccak256(abi.encode(original)),
            "local full direct history"
        );
        require(
            keccak256(abi.encode(floor.firstSale(1))) == keccak256(abi.encode(first)),
            "local original first history"
        );
        require(
            keccak256(abi.encode(floor.releaseFloorReceipt(releaseKey)))
                == keccak256(abi.encode(release)),
            "local original release history"
        );
    }

    function testLateFailureRollsBackInlineEvidenceLinksAndAdapterReceipt() public {
        bytes32 id = bytes32(uint256(1));
        bytes32 key = _key(nativeAdapter, id);
        (F.ReleaseContext memory context,) = provider.releaseFacts();
        vm.expectRevert(bytes("later callback failed"));
        nativeAdapter.recordThenFail(floor, id, _sale());
        require(
            nativeAdapter.directPrimarySaleReceipt(id).amount == 0, "adapter receipt rolled back"
        );
        require(
            floor.directPrimarySaleFloorReceipt(key).receiptHash == 0
                && floor.firstSale(1).receiptHash == 0,
            "paid links rolled back"
        );
        require(
            floor.releaseFloorReceipt(_releaseKey(context)).receiptHash == 0,
            "release link rolled back"
        );
        provider.setUnavailable(true, true, false);
        vm.expectRevert();
        nativeAdapter.record(floor, id, _sale());
        provider.setUnavailable(false, false, false);
        vm.warp(1001);
        _record(nativeAdapter, 1);
        require(floor.firstSale(1).recordedAt == 1001, "fresh paid time after rollback");
    }

    function testSourceFailureRollsBackAdapterAndPreservesOldPaidHistory() public {
        bytes32 firstKey = _record(nativeAdapter, 1);
        bytes32 beforeHash = floor.directPrimarySaleFloorReceipt(firstKey).receiptHash;
        provider.setConfiguration(keccak256("unadmitted changed configuration"));
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(2)), _sale());
        require(
            nativeAdapter.directPrimarySaleReceipt(bytes32(uint256(2))).amount == 0,
            "new caller receipt rolled back"
        );
        require(
            floor.directPrimarySaleFloorReceipt(firstKey).receiptHash == beforeHash,
            "old paid history immutable"
        );
    }

    function testFuzzZeroRequiredReceiptWordCannotPass(uint8 field) public {
        D.Receipt memory sale = _sale();
        uint256[13] memory required = [uint256(0), 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13];
        uint256 offset = required[uint256(field) % required.length] * 32;
        assembly ("memory-safe") { mstore(add(sale, offset), 0) }
        vm.expectRevert();
        nativeAdapter.record(floor, bytes32(uint256(1)), sale);
        require(floor.firstSale(1).receiptHash == 0, "no zero-field first receipt");
    }

    function _sale() private pure returns (D.Receipt memory) {
        return D.Receipt(
            keccak256("original product authorization digest"),
            1,
            10,
            keccak256("original operation root"),
            keccak256("original operation id"),
            keccak256("bound mint policy"),
            keccak256("expected primary policy"),
            keccak256("profile"),
            address(0xbeef),
            100,
            false,
            address(0xcafe),
            1,
            address(0xbabe),
            address(0),
            10
        );
    }

    function _key(DirectFloorAdapterBoundary adapter, bytes32 id) private view returns (bytes32) {
        return StreamDirectPrimarySaleHash.settlementKey(
            adapter.directPrimaryBindings(), address(adapter), id
        );
    }

    function _record(DirectFloorAdapterBoundary adapter, uint256 nonce)
        private
        returns (bytes32 key)
    {
        bytes32 id = bytes32(nonce);
        adapter.record(floor, id, _sale());
        return _key(adapter, id);
    }

    function _status(
        DirectFloorAdapterBoundary adapter,
        ModuleRegistryStatus status,
        uint64 time,
        uint64 revision
    ) private {
        StreamModuleRecord memory row = registry.moduleRecord(address(adapter));
        row.status = status;
        row.statusUpdatedAt = time;
        row.revision = revision;
        registry.setRecord(address(adapter), row);
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

    function _releaseKey(F.ReleaseContext memory c) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_RELEASE_V1"),
                block.chainid,
                address(core),
                uint256(1),
                c.scopeSubject,
                c.membershipHash,
                c.mediaInventoryHash,
                c.scriptSourceHash,
                c.scriptWork
            )
        );
    }

    function _recordUniversal(uint256 nonce) private returns (bytes32) {
        T.ERC20SettlementCandidate memory c;
        c.sale = T.PrimarySale(
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
        c.saleAdapter = address(nativeAdapter);
        c.executor = address(this);
        c.executionBinding.executionId = keccak256(abi.encode("universal execution", nonce));
        c.saleExecutionHash = bytes32(uint256(57));
        c.orchestrationOrder = 1;
        c.mintManager = address(manager);
        c.operationIdentityCommitment = keccak256(abi.encode("universal root", nonce));
        c.operationId = keccak256(abi.encode("universal operation", nonce));
        c.currentPolicyHash = bytes32(uint256(58));
        c.boundPolicyHash = bytes32(uint256(59));
        c.rights = T.PrimaryRights(
            bytes32(uint256(60)), address(0xbeef), 0, bytes32(uint256(61)), bytes32(uint256(62))
        );
        T.PrimarySettlementResult memory r = T.PrimarySettlementResult(
            keccak256(abi.encode("original universal candidate boundary", c)),
            StreamPrimarySettlementHash.settlementKey(
                address(universal), c.saleAdapter, c.executionBinding.executionId
            ),
            c.rights.profileId,
            c.rights.wallet,
            address(0),
            c.sale.amount,
            c.executor,
            c.executionBinding.executionId,
            false,
            c.operationIdentityCommitment,
            c.currentPolicyHash,
            c.boundPolicyHash
        );
        universal.record(floor, c, r);
        return r.settlementKey;
    }
}
