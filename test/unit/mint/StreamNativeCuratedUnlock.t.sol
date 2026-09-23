// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamNativeCuratedUnlock.sol";
import "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamRevenueResolver.sol";
import {
    IStreamNativeRefundWindowSale
} from "../../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundWindowSale.sol";
import {
    ModuleRegistryStatus,
    StreamModuleRecord
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";

interface CuratedUnlockVm {
    function warp(uint256 timestamp) external;
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function mockCallRevert(address target, bytes calldata data, bytes calldata result) external;
    function expectRevert(bytes4 selector) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert() external;
}

contract CuratedUnlockReadTarget {
    fallback() external {
        revert("unconfigured typed read");
    }
}

contract CuratedUnlockHarness {
    function verify(
        StreamNativeCuratedUnlock.Context memory x,
        bytes32 id,
        Curated.SaleRecord memory sale,
        address buyer,
        bytes32 commitment,
        Curated.Selection memory chosen,
        bytes32 salt,
        uint8 reason
    ) external view returns (bytes32) {
        return StreamNativeCuratedUnlock.verifiedReason(
            x, id, sale, buyer, commitment, chosen, salt, reason
        );
    }
}

/// @dev Real linked unlock and selection/hash libraries; external Core/Manager/Ledger/Artist/
/// Registry reads are exact-selector fixtures. No escrow mutation or end-to-end mint is claimed.
contract StreamNativeCuratedUnlockTest {
    CuratedUnlockVm private constant vm =
        CuratedUnlockVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant SALE = keccak256("known sale");
    bytes32 private constant PHASE = keccak256("phase");
    bytes32 private constant POLICY = keccak256("original policy");
    bytes32 private constant COUNTER = keccak256("content counter");
    bytes32 private constant DEFINITION = keccak256("original definition");
    bytes32 private constant SUBJECT = keccak256("actual ledger subject");
    bytes32 private constant KEY = keccak256("actual ledger key");
    bytes32 private constant SALT = keccak256("hidden salt");
    address private constant BUYER = address(0xB0B);
    CuratedUnlockHarness private h;
    address private core;
    address private manager;
    address private ledger;
    address private artists;
    address private registry;
    address private gate;

    function setUp() external {
        vm.warp(1000);
        h = new CuratedUnlockHarness();
        core = address(new CuratedUnlockReadTarget());
        manager = address(new CuratedUnlockReadTarget());
        ledger = address(new CuratedUnlockReadTarget());
        artists = address(new CuratedUnlockReadTarget());
        registry = address(new CuratedUnlockReadTarget());
        gate = address(new CuratedUnlockReadTarget());
        vm.mockCall(
            core,
            abi.encodeCall(IStreamCoreCollectionView.collectionHasMaxSupply, (1)),
            abi.encode(false)
        );
        _phase(true, 2000);
        _policy(POLICY, 0, 0);
        _ids(COUNTER);
        _counter(COUNTER, _contextCounter());
        vm.mockCall(manager, abi.encodeCall(IStreamMintReads.mintLedger, ()), abi.encode(ledger));
        _keys(COUNTER, IStreamMintManager.CounterKeyMode.CONTEXT, _contentContext());
        _value(0);
        vm.mockCall(
            core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("ARTIST_REGISTRY"))),
            abi.encode(
                artists,
                artists.codehash,
                false,
                bytes32(0),
                bytes4(0),
                registry,
                uint8(1),
                bytes32(0),
                bytes32(0),
                uint64(1)
            )
        );
        _artist(2, 1, keccak256("artist"), 1, keccak256("binding"));
        _module(address(h), 1);
        _module(manager, 1);
        _module(gate, 1);
    }

    function _context() private view returns (StreamNativeCuratedUnlock.Context memory x) {
        x.support = StreamNativeCuratedSaleSupport.Context(
            core,
            registry,
            IStreamMintManager(manager),
            IStreamRevenueResolver(address(0)),
            IStreamArtistAttribution(artists),
            artists.codehash,
            200000
        );
        x.coreHash = core.codehash;
        x.managerHash = manager.codehash;
        x.registryHash = registry.codehash;
    }

    function _sale() private view returns (Curated.SaleRecord memory s) {
        s.config.collectionId = 1;
        s.config.phaseId = PHASE;
        s.config.price = 1000;
        s.config.mintPolicyHash = POLICY;
        s.config.contentManifestRoot = _leaf();
        s.saleNonce = 1;
        s.saleKind = 0;
        s.configHash = keccak256("configuration");
        s.artistId = keccak256("artist");
        s.bindingGeneration = 1;
        s.bindingHash = keccak256("binding");
        s.gate = gate;
        s.gateCodeHash = gate.codehash;
        s.contentCounterId = COUNTER;
        s.contentCounterConfigHash = DEFINITION;
        s.status = 1;
    }

    function _chosen() private pure returns (Curated.Selection memory c) {
        c.content.contentId = bytes32(uint256(1));
        c.content.tokenDataHash = keccak256("original artwork");
        c.content.proof = new bytes32[](0);
        c.tokenData = "original artwork";
        c.mintCommitment = keccak256("mint");
        c.recipient = BUYER;
        c.purchaseNonce = 1;
    }

    function _leaf() private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_LEAF_V1"),
                        block.chainid,
                        address(h),
                        SALE,
                        bytes32(uint256(1)),
                        keccak256("original artwork")
                    )
                )
            )
        );
    }

    function _contentContext() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                block.chainid,
                address(h),
                SALE,
                bytes32(uint256(1))
            )
        );
    }

    function _commitment() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_COMMIT_V1"),
                block.chainid,
                address(h),
                SALE,
                BUYER,
                _leaf(),
                SALT
            )
        );
    }

    function _reason(uint8 code) private view returns (bytes32) {
        return h.verify(_context(), SALE, _sale(), BUYER, _commitment(), _chosen(), SALT, code);
    }

    function _phase(bool exists, uint64 end) private {
        IStreamMintManager.MintPhaseConfig memory p =
            IStreamMintManager.MintPhaseConfig(false, 0, end, 1, keccak256("phase config"), 0);
        vm.mockCall(
            manager, abi.encodeCall(IStreamMintReads.phase, (1, PHASE)), abi.encode(exists, p)
        );
    }

    function _policy(bytes32 current, bytes32 prior, uint64 until) private {
        vm.mockCall(
            manager,
            abi.encodeCall(IStreamMintReads.phasePolicyHash, (1, PHASE)),
            abi.encode(current)
        );
        vm.mockCall(
            manager,
            abi.encodeCall(IStreamMintReads.phasePolicyGrace, (1, PHASE)),
            abi.encode(prior, until)
        );
    }

    function _ids(bytes32 id) private {
        bytes32[] memory ids = new bytes32[](id == 0 ? 0 : 1);
        if (id != 0) ids[0] = id;
        vm.mockCall(
            manager, abi.encodeCall(IStreamMintReads.phaseCounterIds, (1, PHASE)), abi.encode(ids)
        );
    }

    function _contextCounter() private pure returns (IStreamMintManager.MintCounterConfig memory) {
        return IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONTEXT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            DEFINITION
        );
    }

    function _counter(bytes32 id, IStreamMintManager.MintCounterConfig memory c) private {
        vm.mockCall(
            manager, abi.encodeCall(IStreamMintReads.counterConfig, (1, PHASE, id)), abi.encode(c)
        );
    }

    function _keys(bytes32 id, IStreamMintManager.CounterKeyMode mode, bytes32 contextHash)
        private
    {
        vm.mockCall(
            manager,
            abi.encodeCall(
                IStreamMintReads.previewSubjectKey,
                (mode, 1, PHASE, id, BUYER, BUYER, address(h), address(0), contextHash)
            ),
            abi.encode(SUBJECT)
        );
        vm.mockCall(
            manager,
            abi.encodeCall(IStreamMintReads.previewCounterValueKey, (1, PHASE, id, SUBJECT)),
            abi.encode(KEY)
        );
    }

    function _value(uint64 value) private {
        vm.mockCall(
            ledger, abi.encodeCall(IStreamMintLedger.counterValue, (KEY)), abi.encode(value)
        );
    }

    function _artist(uint8 state, uint64 generation, bytes32 id, uint8 authority, bytes32 binding)
        private
    {
        vm.mockCall(
            artists,
            abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (1)),
            abi.encode(state, generation, id, authority, binding)
        );
    }

    function _module(address target, uint8 status) private {
        StreamModuleRecord memory r = StreamModuleRecord(
            ModuleRegistryStatus(status),
            keccak256("type"),
            keccak256("version"),
            bytes4(0x12345678),
            100000,
            target.codehash,
            keccak256("deployment"),
            keccak256("manifest"),
            "urn:module",
            500,
            900,
            1
        );
        vm.mockCall(
            registry, abi.encodeCall(IStreamModuleRegistry.moduleRecord, (target)), abi.encode(r)
        );
    }

    function testPhaseEndStrictBoundaryKnownPhaseAndInfiniteWindow() external {
        _phase(true, 1000);
        require(_reason(1) == 0, "end equality still admitted");
        vm.warp(1001);
        require(_reason(1) == keccak256("REFUND_PHASE_ENDED"), "strictly expired");
        _phase(false, 1000);
        require(_reason(1) == 0, "unknown phase not ended evidence");
        _phase(true, 0);
        require(_reason(1) == 0, "no finite end");
    }

    function testCoreLifetimeSupplyExhaustionNeedsNoChosenLeafOrManager() external {
        vm.mockCall(
            core,
            abi.encodeCall(IStreamCoreCollectionView.collectionHasMaxSupply, (1)),
            abi.encode(true)
        );
        vm.mockCall(
            core,
            abi.encodeCall(IStreamCoreCollectionView.collectionMaxSupply, (1)),
            abi.encode(uint256(5))
        );
        vm.mockCall(
            core,
            abi.encodeCall(IStreamCoreCollectionView.collectionMintedEver, (1)),
            abi.encode(uint256(5))
        );
        Curated.Selection memory empty;
        StreamNativeCuratedUnlock.Context memory x = _context();
        x.managerHash = 0;
        require(
            h.verify(x, SALE, _sale(), BUYER, _commitment(), empty, 0, 2)
                == keccak256("REFUND_SUPPLY_EXHAUSTED"),
            "lifetime cap independently sufficient"
        );
        vm.mockCall(
            core,
            abi.encodeCall(IStreamCoreCollectionView.collectionMintedEver, (1)),
            abi.encode(uint256(4))
        );
        require(_reason(2) == 0, "one remaining token");
    }

    function testOriginalConstantCounterCapExhaustionNeedsNoLeaf() external {
        IStreamMintManager.MintCounterConfig memory c = _contextCounter();
        c.keyMode = IStreamMintManager.CounterKeyMode.CONSTANT;
        c.staticCap = 5;
        c.staticIncrement = 2;
        _counter(COUNTER, c);
        _keys(COUNTER, c.keyMode, 0);
        _value(3);
        Curated.Selection memory empty;
        require(
            h.verify(_context(), SALE, _sale(), BUYER, _commitment(), empty, 0, 2) == 0,
            "equal cap admitted"
        );
        _value(4);
        require(
            h.verify(_context(), SALE, _sale(), BUYER, _commitment(), empty, 0, 2)
                == keccak256("REFUND_COUNTER_EXHAUSTED"),
            "quantity-one static increment"
        );
        _policy(keccak256("new policy"), POLICY, 1100);
        require(_reason(2) == 0, "changed generic counter definition not inferred");
    }

    function testExactCommittedContextCapOneIsVerifiedAgainstActualKeyReads() external {
        require(_reason(2) == 0, "unspent content");
        _value(1);
        require(_reason(2) == keccak256("REFUND_COUNTER_EXHAUSTED"), "same leaf consumed");
        _policy(keccak256("unrelated new policy"), POLICY, 1100);
        require(
            _reason(2) == keccak256("REFUND_COUNTER_EXHAUSTED"),
            "saved definition proves same key despite unrelated policy change"
        );
    }

    function testContentProofSaltBuyerAndCommitmentTamperingNeverBecomeExhaustion() external {
        _value(1);
        for (uint256 n; n < 7; ++n) {
            Curated.Selection memory c = _chosen();
            bytes32 salt = SALT;
            address buyer = BUYER;
            bytes32 commitment = _commitment();
            if (n == 0) {
                c.content.contentId = bytes32(uint256(2));
            } else if (n == 1) {
                c.content.tokenDataHash = keccak256("different");
            } else if (n == 2) {
                c.tokenData = "different";
            } else if (n == 3) {
                c.content.proof = new bytes32[](1);
                c.content.proof[0] = keccak256("bad sibling");
            } else if (n == 4) {
                salt = keccak256("different salt");
            } else if (n == 5) {
                buyer = address(0xBAD);
            } else {
                commitment = keccak256("different saved commitment");
            }
            vm.expectRevert();
            h.verify(_context(), SALE, _sale(), buyer, commitment, c, salt, 2);
        }
        require(_reason(2) != 0, "valid proof remains usable");
    }

    function testMissingDisabledChangedOrResolverCountersAreNotExhaustion() external {
        _value(1);
        for (uint256 n; n < 8; ++n) {
            IStreamMintManager.MintCounterConfig memory c = _contextCounter();
            if (n == 0) c.enabled = false;
            else if (n == 1) c.keyMode = IStreamMintManager.CounterKeyMode.RECIPIENT;
            else if (n == 2) c.capMode = IStreamMintLedger.CounterCapMode.MERKLE_STATIC;
            else if (n == 3) c.deltaMode = IStreamMintLedger.CounterDeltaMode.RESOLVER;
            else if (n == 4) c.staticCap = 2;
            else if (n == 5) c.staticIncrement = 2;
            else if (n == 6) c.counterConfigHash = keccak256("different definition");
            else c.staticIncrement = 0;
            _counter(COUNTER, c);
            require(_reason(2) == 0, "inadmissible counter never proves cap");
        }
        _counter(COUNTER, _contextCounter());
        _ids(0);
        require(_reason(2) == 0, "missing counter");
        _ids(COUNTER);
        _phase(false, 2000);
        require(_reason(2) == 0, "missing phase");
    }

    function testMintPolicyCurrentAndGraceEqualityAreNotUnlock() external {
        require(_reason(3) == 0, "original policy");
        _policy(keccak256("new"), POLICY, 1000);
        require(_reason(3) == 0, "grace equality");
        vm.warp(1001);
        require(_reason(3) == keccak256("REFUND_MINT_POLICY_UNMATCHABLE"), "strictly beyond grace");
        _policy(keccak256("new"), keccak256("different predecessor"), 2000);
        require(_reason(3) != 0, "not the retained predecessor");
    }

    function testOnlyMatchingSavedAttributionDisputeOrRevocationQualifies() external {
        _artist(2, 1, keccak256("artist"), 4, keccak256("binding"));
        require(_reason(4) == 0, "authority contest is not attribution dispute");
        _artist(4, 1, keccak256("artist"), 1, keccak256("binding"));
        require(_reason(4) == keccak256("REFUND_BOUND_ATTRIBUTION_STOPPED"), "saved dispute");
        _artist(5, 1, keccak256("artist"), 1, keccak256("binding"));
        require(_reason(4) != 0, "saved revocation");
        _artist(4, 2, keccak256("artist"), 1, keccak256("binding"));
        require(_reason(4) == 0, "generation changed");
        _artist(4, 1, keccak256("other artist"), 1, keccak256("binding"));
        require(_reason(4) == 0, "artist changed");
        _artist(4, 1, keccak256("artist"), 1, keccak256("other binding"));
        require(_reason(4) == 0, "binding changed");
    }

    function testIncidentOnlyForOriginalHostManagerOrGateAndNotDeprecation() external {
        require(_reason(5) == 0, "active");
        _module(address(h), 2);
        require(_reason(5) == 0, "deprecation not incident");
        _module(address(h), 3);
        require(
            _reason(5) == keccak256("REFUND_REFERENCED_MODULE_INCIDENT_REVOKED"), "host incident"
        );
        _module(address(h), 1);
        _module(manager, 3);
        require(_reason(5) != 0, "manager incident");
        _module(manager, 1);
        _module(gate, 3);
        require(_reason(5) != 0, "saved gate incident");
        _module(gate, 1);
        _module(address(0xBAD), 3);
        require(_reason(5) == 0, "unreferenced module ignored");
    }

    function testProviderRevertsShortLongAndDirtyReadsCannotProveExhaustion() external {
        bytes memory data = abi.encodeCall(IStreamCoreCollectionView.collectionHasMaxSupply, (1));
        vm.mockCallRevert(core, data, hex"deadbeef");
        _expectReadFailure(core, IStreamCoreCollectionView.collectionHasMaxSupply.selector, 4);
        _reason(2);
        vm.mockCall(core, data, hex"01");
        _expectReadFailure(core, IStreamCoreCollectionView.collectionHasMaxSupply.selector, 1);
        _reason(2);
        vm.mockCall(core, data, abi.encode(uint256(1), uint256(0)));
        _expectReadFailure(core, IStreamCoreCollectionView.collectionHasMaxSupply.selector, 64);
        _reason(2);
        vm.mockCall(core, data, abi.encode(uint256(2)));
        _expectReadFailure(core, IStreamCoreCollectionView.collectionHasMaxSupply.selector, 32);
        _reason(2);
    }

    function testCounterListBoundMalformedConfigAndLedgerWidthFailClosed() external {
        bytes32[] memory ids = new bytes32[](17);
        vm.mockCall(
            manager, abi.encodeCall(IStreamMintReads.phaseCounterIds, (1, PHASE)), abi.encode(ids)
        );
        _expectReadFailure(manager, IStreamMintReads.phaseCounterIds.selector, 608);
        _reason(2);
        _ids(COUNTER);
        vm.mockCall(
            manager,
            abi.encodeCall(IStreamMintReads.counterConfig, (1, PHASE, COUNTER)),
            abi.encode(
                uint256(2), uint256(6), uint256(1), uint256(0), uint256(1), uint256(1), DEFINITION
            )
        );
        _expectReadFailure(manager, IStreamMintReads.counterConfig.selector, 224);
        _reason(2);
        _counter(COUNTER, _contextCounter());
        vm.mockCall(
            ledger,
            abi.encodeCall(IStreamMintLedger.counterValue, (KEY)),
            abi.encode(uint256(type(uint64).max) + 1)
        );
        _expectReadFailure(ledger, IStreamMintLedger.counterValue.selector, 32);
        _reason(2);
    }

    function testMalformedRegistryAndArtistReadsDoNotBecomeTypedReasons() external {
        vm.mockCall(
            registry,
            abi.encodeCall(IStreamModuleRegistry.moduleRecord, (address(h))),
            abi.encode(uint256(3))
        );
        _expectReadFailure(registry, IStreamModuleRegistry.moduleRecord.selector, 32);
        _reason(5);
        vm.mockCall(
            artists,
            abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (1)),
            abi.encode(uint256(4))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundDependencyReadMalformed.selector, artists, 32
            )
        );
        _reason(4);
    }

    function testUnknownRecordCodePinsAndUnsupportedReasonFailClosed() external {
        Curated.SaleRecord memory sale = _sale();
        sale.saleNonce = 0;
        vm.expectRevert(StreamNativeCuratedUnlock.CuratedUnlockInputInvalid.selector);
        h.verify(_context(), SALE, sale, BUYER, _commitment(), _chosen(), SALT, 1);
        StreamNativeCuratedUnlock.Context memory x = _context();
        x.managerHash = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeCuratedUnlock.CuratedUnlockDependencyInvalid.selector, manager
            )
        );
        h.verify(x, SALE, _sale(), BUYER, _commitment(), _chosen(), SALT, 1);
        require(_reason(0) == 0 && _reason(6) == 0, "clock and unknown reason not classified");
    }

    function _expectReadFailure(address target, bytes4 selector, uint256 size) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeCuratedUnlock.CuratedUnlockReadFailed.selector, target, selector, size
            )
        );
    }
}
