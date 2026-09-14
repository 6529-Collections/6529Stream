// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/RevenueV1TestBase.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../unit/revenue/PreparedNativeSaleFixture.sol";
import "../../smart-contracts/core/StreamCore.sol";
import "../../smart-contracts/core/StreamCoreExternalReads.sol";
import "../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol";

/// @dev Explicit semantic Artist boundary. Real op15 authority is independent integration work.
contract PreparedNativeArtistFixture is IStreamArtistAttribution {
    address public immutable override core;
    address public immutable mintManager;
    address public artist;
    bool public consent = true;
    constructor(address source, address manager) { core = source; mintManager = manager; }
    function accept(address value) external { artist = value; }
    function setConsent(bool value) external { consent = value; }
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamArtistAttribution).interfaceId || id == 0x606af4b9
            || id == type(IStreamArtistEconomicsAuthority).interfaceId || id == type(IStreamArtistMintConsent).interfaceId;
    }
    function acceptedArtist(uint256) external view returns (address) { return artist; }
    function attribution(uint256) external view returns (IStreamCollectionArtistRegistry.Attribution memory a) {
        if (artist != address(0)) { a.artist = artist; a.nominationHash = keccak256("nomination"); a.acceptanceHash = keccak256("acceptance"); }
    }
    function requireEconomicsConsent(uint256, bytes32, uint8, uint256, bytes32) external view { require(consent, "actual consent boundary"); }
    function consentMode(uint256) external pure returns (uint8) { return 1; }
    function isPolicyConsented(uint256, bytes32, bytes32 hash) external view returns (bool, bytes32) { return (artist != address(0), keccak256(abi.encode("fixture policy", hash))); }
    function requireMintConsent(uint256, bytes32, bytes32) external view { require(artist != address(0), "artist mint boundary"); }
    function requireSaleConsent(uint256, bytes32, bytes32) external view { require(consent, "artist sale boundary"); }
}

/// @dev Real Core callback observes old immediate-recorder funding, then optionally rejects.
contract NativeRecordingRegressionReceiver is IERC721Receiver {
    address public immutable wallet;
    bool public rejecting = true;
    uint256 public observedPayment;
    constructor(address wallet_) { wallet = wallet_; }
    function accept() external { rejecting = false; }
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        observedPayment = wallet.balance;
        require(!rejecting, "legacy receiver rejected");
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @dev Entropy completion boundary only; no seed/oracle/full coordinator claim.
contract PreparedNativeEntropyFixture {
    address public core;
    function setCore(address value) external { require(core == address(0), "once"); core = value; }
    function collectionRevealPolicy(uint256) external pure returns (IStreamRevealFeeEscrow.CollectionRevealPolicy memory) {
        return IStreamRevealFeeEscrow.CollectionRevealPolicy(true, 1, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, 0);
    }
    bool public rejecting;
    uint256 public calls;
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamEntropyCoordinator).interfaceId;
    }
    function setRejecting(bool value) external { rejecting = value; }
    function onTokenMinted(uint256, uint256, address, bytes32) external { require(!rejecting, "entropy failed"); ++calls; }
}

/// @notice Actual current Core, Manager, Ledger, Registry, resolver, wallet, escrow and 9.
/// @dev Target-side typed Executor/Artist/entropy seams are explicit. This is not the full
/// governance/Artist ceremony or the later auction, and does not reuse LegacyStreamCore.
contract StreamCurrentPreparedNativeSettlementTest is RevenueV1TestBase, OfficialSafeFixture {
    bytes32 private constant PHASE = keccak256("actual paid prepared phase");
    bytes32 private constant COUNTER = keccak256("prepared payer counter");
    bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant MANIFEST = keccak256("prepared fixture manifest");
    uint256 private constant SIGNER_KEY = 0x6529035;
    uint256 private constant PAYER_KEY = 0x6529036;
    StreamCore private core;
    StreamMintLedger private ledger;
    StreamMintManager private manager;
    StreamModuleRegistry private registry;
    StreamAssetPolicyRegistry private policy;
    StreamSplitFactory private factory;
    StreamRevenueResolver private resolver;
    StreamRevenueEscrow private escrow;
    StreamPrimarySaleSettlement private recorder;
    PreparedNativeSaleFixture private sale;
    PreparedNativeArtistFixture private artists;
    PreparedNativeEntropyFixture private entropy;
    bytes32 private profile;
    address private wallet;
    address private payer;
    uint256 private actionNonce;

    function setUp() public {
        vm.warp(1000);
        payer = vm.addr(PAYER_KEY);
        _revenueAuthority();
        registry = new StreamModuleRegistry(IStreamGovernanceExecutor(address(revenueAuthority)), MANIFEST, "urn:prepared:registry");
        StreamCore.GasParameterGenesisConfig[] memory gasRows = new StreamCore.GasParameterGenesisConfig[](4);
        gasRows[0] = StreamCore.GasParameterGenesisConfig(keccak256("6529STREAM_GGP_ROYALTY_RESOLVER_GAS_LIMIT"), 50000, 25000, 1);
        gasRows[1] = StreamCore.GasParameterGenesisConfig(keccak256("6529STREAM_GGP_ROYALTY_RETURN_GAS_BUFFER"), 2910000, 1460000, 1);
        gasRows[2] = StreamCore.GasParameterGenesisConfig(keccak256("6529STREAM_GGP_METADATA_ROUTER_GAS_LIMIT"), 500000, 250000, 1);
        gasRows[3] = StreamCore.GasParameterGenesisConfig(keccak256("6529STREAM_GGP_ENTROPY_REGISTRATION_GAS_LIMIT"), 120000, 120000, 2);
        core = new StreamCore("Prepared Current", "PPC", address(revenueAuthority), StreamCore.GenesisModuleRegistryConfig(address(registry), address(registry).codehash, MANIFEST, MANIFEST), gasRows);
        ledger = new StreamMintLedger();
        manager = new StreamMintManager(core, ledger, IERC165(address(registry)));
        ledger.setLedgerWriter(address(manager), true);
        _register(address(registry), keccak256("MODULE_REGISTRY"), type(IStreamModuleRegistry).interfaceId, MANIFEST);
        _register(address(manager), keccak256("MINT_MANAGER"), type(IStreamMintManager).interfaceId, MANIFEST);
        _pointer(keccak256("MINT_MANAGER"), address(manager));
        artists = new PreparedNativeArtistFixture(address(core), address(manager));
        _register(address(artists), keccak256("ARTIST_REGISTRY"), type(IStreamArtistMintConsent).interfaceId, MANIFEST);
        _pointer(keccak256("ARTIST_REGISTRY"), address(artists));
        entropy = new PreparedNativeEntropyFixture();
        entropy.setCore(address(core));
        _register(address(entropy), keccak256("ENTROPY_COORDINATOR"), type(IStreamEntropyCoordinator).interfaceId, MANIFEST);
        _pointer(keccak256("ENTROPY_COORDINATOR"), address(entropy));
        _collection();
        policy = new StreamAssetPolicyRegistry(address(revenueAuthority));
        IStreamGasParameterHost.GasParameterConfig[3] memory config = _walletGasConfigs();
        config[2].genesisValue = 500000;
        factory = new StreamSplitFactory(policy, address(revenueAuthority), config);
        resolver = new StreamRevenueResolver(core, factory, address(revenueAuthority), artists,
            IStreamGasParameterHost.GasParameterConfig("ARTIST_BENEFICIARY_READ_GAS", 200000, 50000, 2));
        vm.prank(address(revenueAuthority)); resolver.transferOwnership(address(this));
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(vm.addr(SIGNER_KEY), 1000000, keccak256("artist"));
        (profile, wallet) = factory.createProfile(entries, keccak256("prepared rights"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        artists.accept(vm.addr(SIGNER_KEY));
        escrow = new StreamRevenueEscrow(factory, address(revenueAuthority), IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12000000, 12000000, 3));
        recorder = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        _register(address(recorder), keccak256("PRIMARY_SALE_SETTLEMENT"), type(IStreamPreparedNativePrimarySaleSettlement).interfaceId, keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1"));
        (bytes32 scope, bytes32 oldState, bytes32 newState) = escrow.creditProducerTransitionHashes(address(recorder), true);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority)); escrow.setCreditProducer(address(recorder), true);
        _clearContext();
        sale = new PreparedNativeSaleFixture(manager, recorder, vm.addr(SIGNER_KEY));
        _register(address(sale), keccak256("NATIVE_PREPARED_SALE_ADAPTER"), type(IStreamPreparedNativeSaleBinding).interfaceId, keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1"));
        sale.open();
        bytes32[] memory ids = new bytes32[](1); ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters = new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(true, IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.STATIC, IStreamMintLedger.CounterDeltaMode.STATIC, 10, 1, keccak256("counter"));
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(1, PHASE, IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST), gate, ids, counters);
        manager.setPhaseExecutor(1, PHASE, address(sale), true);
        require(address(core).code.length <= 24576 && address(manager).code.length <= 24576 && address(recorder).code.length <= 24576, "actual production EIP170");
        // Manager operation nonces are zero-based; retained collection serials are one-based.
        require(manager.nextOperationNonce() == 0 && core.collectionNextSerial(1) == 1, "original counter baselines");
        vm.deal(payer, 1 ether);
    }

    function testActualPreparedPaymentCompletesAndRecordsExactIdentity() public {
        manager.bindPreparedNativeRecorder(address(recorder));
        (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline, bytes memory sig) = _intent(payer, 1);
        (bytes32 expectedRoot, bytes32[] memory expectedIds) = sale.preview(intent, data);
        vm.recordLogs();
        vm.prank(payer);
        (uint256 tokenId, bytes32 root, bytes32 operationId, StreamPrimarySettlementTypes.PrimarySettlementResult memory result) = sale.execute{value: 1000}(intent, data, deadline, sig);
        require(tokenId == 1 && root == expectedRoot && operationId == expectedIds[0], "original prepared transcript");
        require(core.ownerOf(1) == address(sale) && core.tokenLifecycle(1) == 2 && core.pendingPreparedMintTokenId() == 0, "completed custody");
        require(core.collectionNextSerial(1) == 2 && core.collectionMintedEver(1) == 1 && ledger.isManagerOperationRootUsed(address(manager), root), "actual counters");
        require(manager.nextOperationNonce() == 1 && ledger.counterValue(_counter(payer)) == 1 && entropy.calls() == 1, "one consumption");
        require(wallet.balance == 1000 && address(sale).balance == 0 && address(recorder).balance == 0 && sale.receiverSawOfficialPayment(), "9 paid before receiver");
        require(result.amount == 1000 && result.asset == address(0) && result.profileId == profile && result.wallet == wallet && result.operationIdentityCommitment == root, "full official result");
        require(keccak256(abi.encode(recorder.settlementResult(result.settlementKey))) == keccak256(abi.encode(result)), "original 9 readback");
        StreamPreparedNativeSettlementTypes.Facts memory f = sale.lastFacts();
        bytes32 expectedFacts = keccak256(abi.encode(keccak256("6529STREAM_PREPARED_NATIVE_FACTS_V1"), block.chainid, f));
        Vm.Log[] memory logs = vm.getRecordedLogs(); uint256 originals;
        bytes32 eventSignature = keccak256("PreparedNativeRevenueRecorded(bytes32,bytes32,bytes32,(address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32))");
        for (uint256 j; j < logs.length; ++j) {
            if (logs[j].emitter == address(recorder) && logs[j].topics[0] == eventSignature) {
                ++originals; require(logs[j].topics.length == 4 && logs[j].topics[1] == result.settlementKey && logs[j].topics[2] == recorder.preparedNativeSaleKey(address(sale), intent.saleId, intent.saleNonce)
                    && logs[j].topics[3] == expectedFacts && keccak256(logs[j].data) == keccak256(abi.encode(f, intent)), "original exact indexed event and full payload");
            }
        }
        require(originals == 1, "exactly one original prepared revenue event");
        require(recorder.preparedNativeFactsHash(result.settlementKey) == expectedFacts && f.operationRoot == root && f.tokenId == 1 && f.collectionSerial == 1, "full original facts");
        require(manager.activePreparedNativeMint().operationRoot == 0, "active cleared");
        vm.prank(payer); (bool ok,) = address(sale).call{value: 1000}(abi.encodeCall(sale.execute, (intent, data, deadline, sig)));
        require(!ok && wallet.balance == 1000 && manager.nextOperationNonce() == 1, "exact replay");
    }

    function testTwoSuccessfulPaidOperationsReleaseRecorderGuardAndReturnExactABI() public {
        manager.bindPreparedNativeRecorder(address(recorder));
        sale.configureFault(7);
        bytes32 previousKey;
        for (uint256 j = 1; j <= 2; ++j) {
            (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline,) = _intent(payer, j);
            intent.saleNonce = j;
            intent.saleAuthorizationDigest = sale.authorizationDigest(intent, deadline);
            intent.saleExecutionHash = keccak256(abi.encode(intent.saleAuthorizationDigest, intent.executionNonce));
            (uint8 v, bytes32 r, bytes32 s_) = vm.sign(SIGNER_KEY, intent.saleAuthorizationDigest);
            bytes memory sig = abi.encodePacked(r, s_, v);
            vm.recordLogs();
            vm.prank(payer);
            (uint256 tokenId, bytes32 root, bytes32 operationId, StreamPrimarySettlementTypes.PrimarySettlementResult memory result) = sale.execute{value: 1000}(intent, data, deadline, sig);
            bytes memory raw = sale.lastRecorderReturn();
            require(raw.length == 384 && keccak256(raw) == keccak256(abi.encode(result)), "raw success is exact12 words");
            require(keccak256(raw) == keccak256(abi.encode(recorder.settlementResult(result.settlementKey))), "raw original record parity");
            require(tokenId == j && root != 0 && operationId != 0 && result.settlementKey != previousKey && result.operationIdentityCommitment == root, "distinct successful operations");
            require(core.ownerOf(tokenId) == address(sale) && core.tokenLifecycle(tokenId) == 2 && sale.receiverSawOfficialPayment(), "same recorder succeeds again before delivery");
            StreamPreparedNativeSettlementTypes.Facts memory facts = sale.lastFacts();
            Vm.Log[] memory logs = vm.getRecordedLogs(); uint256 originals;
            bytes32 eventSignature = keccak256("PreparedNativeRevenueRecorded(bytes32,bytes32,bytes32,(address,address,address,bytes32,uint256,bytes32,bytes32,bytes32,bytes32,uint256,uint256,address,address,address,bytes32,bytes32,bytes32,bytes32),(uint256,bytes32,bytes32,uint256,address,address,address,address,uint256,uint8,bytes32,uint256,uint8,bytes32,bytes32,bytes32,bytes32,bytes32))");
            for (uint256 k; k < logs.length; ++k) {
                if (logs[k].emitter == address(recorder) && logs[k].topics[0] == eventSignature) {
                    ++originals;
                    require(logs[k].topics.length == 4 && logs[k].topics[1] == result.settlementKey
                        && logs[k].topics[2] == recorder.preparedNativeSaleKey(address(sale), intent.saleId, intent.saleNonce)
                        && logs[k].topics[3] == StreamPreparedNativeSettlementHash.factsHash(facts)
                        && keccak256(logs[k].data) == keccak256(abi.encode(facts, intent)), "unchanged complete event");
                }
            }
            require(originals == 1, "one event per distinct paid operation");
            previousKey = result.settlementKey;
        }
        require(recorder.totalOfficialSettled(address(0)) == 2000 && wallet.balance == 2000, "both payments exact");
        require(manager.nextOperationNonce() == 2 && ledger.counterValue(_counter(payer)) == 2 && entropy.calls() == 2, "both independent nonce and counter consumptions");
        require(core.pendingPreparedMintTokenId() == 0 && manager.activePreparedNativeMint().operationRoot == 0, "all preparation cleared");
    }

    function testCallbackFalseResultMagicAndReceiverFailuresRollbackThenIdenticalRetry() public {
        manager.bindPreparedNativeRecorder(address(recorder));
        (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline, bytes memory sig) = _intent(payer, 1);
        (bytes32 root,) = sale.preview(intent, data);
        for (uint256 fault = 1; fault <= 6; ++fault) {
            if (fault == 4) continue;
            sale.configureFault(fault);
            vm.prank(payer); (bool ok,) = address(sale).call{value: 1000}(abi.encodeCall(sale.execute, (intent, data, deadline, sig)));
            require(!ok, "hostile stage rejects");
            _unchanged(intent, root, payer, 1 ether);
        }
        sale.configureFault(0);
        entropy.setRejecting(true);
        vm.prank(payer); (bool ok,) = address(sale).call{value: 1000}(abi.encodeCall(sale.execute, (intent, data, deadline, sig)));
        require(!ok, "late entropy rejects"); _unchanged(intent, root, payer, 1 ether);
        entropy.setRejecting(false);
        vm.prank(payer); sale.execute{value: 1000}(intent, data, deadline, sig);
        require(core.ownerOf(1) == address(sale) && wallet.balance == 1000, "identical signed retry");
    }

    function testReentryIsRejectedDuringCallbackAndReceiverAndInactiveCallsFail() public {
        manager.bindPreparedNativeRecorder(address(recorder));
        (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline, bytes memory sig) = _intent(payer, 1);
        sale.configureFault(4);
        vm.prank(payer); sale.execute{value: 1000}(intent, data, deadline, sig);
        require(sale.callbackReentryRejected() && sale.receiverReentryRejected(), "both windows");
        StreamPreparedNativeSettlementTypes.Facts memory f = sale.lastFacts();
        (bool ok,) = address(sale).call(abi.encodeCall(sale.onPreparedNativeMint, (f)));
        require(!ok, "no direct callback");
        vm.deal(address(sale), 1000); vm.prank(address(sale));
        (ok,) = address(recorder).call{value: 1000}(abi.encodeCall(recorder.settlePreparedNativePrimarySale, (f, intent)));
        require(!ok && recorder.totalOfficialSettled(address(0)) == 1000, "no inactive recorder use");
    }

    function testOriginalSaleReplayIndependentOfNewAuthorizationAndNativeRoot() public {
        manager.bindPreparedNativeRecorder(address(recorder));
        (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline, bytes memory sig) = _intent(payer, 1);
        vm.prank(payer); sale.execute{value: 1000}(intent, data, deadline, sig);
        (intent, data, deadline, sig) = _intent(payer, 2);
        (bytes32 newRoot,) = sale.preview(intent, data);
        vm.prank(payer); (bool ok,) = address(sale).call{value: 1000}(abi.encodeCall(sale.execute, (intent, data, deadline, sig)));
        require(!ok && !ledger.isManagerOperationRootUsed(address(manager), newRoot) && !sale.used(intent.saleAuthorizationDigest), "same sale independent replay");
        require(core.lastAllocatedTokenId() == 1 && manager.nextOperationNonce() == 1 && wallet.balance == 1000, "all new state rolled back");
    }

    function testConsentAndRuntimeInvalidationRejectBeforeFundingAndRetry() public {
        manager.bindPreparedNativeRecorder(address(recorder));
        (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline, bytes memory sig) = _intent(payer, 1);
        (bytes32 root,) = sale.preview(intent, data);
        artists.setConsent(false);
        vm.prank(payer); (bool ok,) = address(sale).call{value: 1000}(abi.encodeCall(sale.execute, (intent, data, deadline, sig)));
        require(!ok, "actual resolver consent"); _unchanged(intent, root, payer, 1 ether);
        artists.setConsent(true);
        bytes memory oldCode = address(recorder).code;
        vm.etch(address(recorder), hex"60006000fd");
        vm.prank(payer); (ok,) = address(sale).call{value: 1000}(abi.encodeCall(sale.execute, (intent, data, deadline, sig)));
        require(!ok, "pinned recorder");
        vm.etch(address(recorder), oldCode); _unchanged(intent, root, payer, 1 ether);
        vm.prank(payer); sale.execute{value: 1000}(intent, data, deadline, sig);
    }

    function testSafePaymentFailureRollsBackNonceAndSameSignedTransactionSucceeds() public {
        manager.bindPreparedNativeRecorder(address(recorder));
        uint256[] memory keys = new uint256[](2); keys[0] = 0x5AFE71; keys[1] = 0x5AFE72;
        OfficialSafe account = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 714);
        vm.deal(address(account), 1 ether);
        (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline, bytes memory sig) = _intent(address(account), 1);
        (bytes32 root,) = sale.preview(intent, data);
        bytes memory callData = abi.encodeCall(sale.execute, (intent, data, deadline, sig));
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(address(sale), 1000, callData, 0, 0, 0, 0, address(0), address(0), nonce);
        bytes memory proof = safeThresholdSignature(keys, digest);
        bytes memory transaction = abi.encodeCall(account.execTransaction, (address(sale), 1000, callData, 0, 0, 0, 0, address(0), payable(address(0)), proof));
        sale.configureFault(6);
        (bool ok,) = address(account).call(transaction);
        require(!ok && account.nonce() == nonce, "Safe failure rolls nonce back");
        _unchanged(intent, root, address(account), 1 ether);
        sale.configureFault(0);
        bytes memory result;
        (ok, result) = address(account).call(transaction);
        require(ok && result.length == 32 && abi.decode(result, (bool)), "same exact Safe bytes succeed");
        require(account.nonce() == nonce + 1 && account.getThreshold() == 2 && keccak256(abi.encode(account.getOwners())) == keccak256(abi.encode(safeOwnerAddresses(keys))), "Safe authority retained");
        require(core.ownerOf(1) == address(sale) && wallet.balance == 1000 && address(account).balance == 1 ether - 1000, "actual Safe paid prepared mint");
    }

    function testFuzzEveryPreparedFactWordRejectsSubstitution(uint8 field) public {
        manager.bindPreparedNativeRecorder(address(recorder));
        (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline, bytes memory sig) = _intent(payer, 1);
        (bytes32 root,) = sale.preview(intent, data);
        sale.configureFault(100 + uint256(field % 18));
        vm.prank(payer); (bool ok,) = address(sale).call{value: 1000}(abi.encodeCall(sale.execute, (intent, data, deadline, sig)));
        require(!ok, "full original facts substitution"); _unchanged(intent, root, payer, 1 ether);
    }

    function testDefaultRightsAreExplicitlyUnsupportedInFirstProfile() public {
        manager.bindPreparedNativeRecorder(address(recorder));
        // The fixture clears only its typed Artist boundary to authorize the real resolver
        // mutation. Actual signed op15 administration is outside this bounded cohort.
        artists.accept(address(0));
        // Token 1 does not yet exist, so an actual token override cannot be installed early.
        // A default profile is a distinct supported resolver branch but outside this seam.
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
        resolver.setPrimaryProfileAssignment(CLASS, 0, 0, profile, 0);
        artists.accept(vm.addr(SIGNER_KEY));
        (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline, bytes memory sig) = _intent(payer, 1);
        (bytes32 root,) = sale.preview(intent, data);
        vm.prank(payer); (bool ok,) = address(sale).call{value: 1000}(abi.encodeCall(sale.execute, (intent, data, deadline, sig)));
        require(!ok, "default is not collection PROFILE"); _unchanged(intent, root, payer, 1 ether);
    }

    function testOfficialRecorderMustBeBoundByOwnerOnceAndCannotBeSubstituted() public {
        (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline, bytes memory sig) = _intent(payer, 1);
        (bytes32 root,) = sale.preview(intent, data);
        vm.prank(payer); (bool ok,) = address(sale).call{value: 1000}(abi.encodeCall(sale.execute, (intent, data, deadline, sig)));
        require(!ok, "unbound Manager rejects"); _unchanged(intent, root, payer, 1 ether);
        vm.prank(payer); (ok,) = address(manager).call(abi.encodeCall(manager.bindPreparedNativeRecorder, (address(recorder))));
        require(!ok, "only original owner binds");
        (ok,) = address(manager).call(abi.encodeCall(manager.bindPreparedNativeRecorder, (address(sale))));
        require(!ok, "wrong admitted role rejected");
        manager.bindPreparedNativeRecorder(address(recorder));
        (address selected, bytes32 hash, uint64 at, uint64 revision) = manager.preparedNativeRecorder();
        require(selected == address(recorder) && hash == address(recorder).codehash && at == 1000 && revision == 1, "exact independent pin");
        (ok,) = address(manager).call(abi.encodeCall(manager.bindPreparedNativeRecorder, (address(recorder))));
        require(!ok, "no rebinding");
        StreamPrimarySaleSettlement substitute = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        _register(address(substitute), keccak256("PRIMARY_SALE_SETTLEMENT"), type(IStreamPreparedNativePrimarySaleSettlement).interfaceId, keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1"));
        // Even another genuine admitted recorder with the same graph is not the selected 9.
        sale = new PreparedNativeSaleFixture(manager, substitute, vm.addr(SIGNER_KEY));
        _register(address(sale), keccak256("NATIVE_PREPARED_SALE_ADAPTER"), type(IStreamPreparedNativeSaleBinding).interfaceId, keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1"));
        sale.open(); manager.setPhaseExecutor(1, PHASE, address(sale), true);
        (intent, data, deadline, sig) = _intent(payer, 1);
        vm.prank(payer); (ok,) = address(sale).call{value: 1000}(abi.encodeCall(sale.execute, (intent, data, deadline, sig)));
        require(!ok && substitute.totalOfficialSettled(address(0)) == 0 && core.lastAllocatedTokenId() == 0 && wallet.balance == 0, "substitution cannot become official");
    }

    function testOfficialRecorderIncidentRevocationInvalidatesPinAndRestoredRetry() public {
        manager.bindPreparedNativeRecorder(address(recorder));
        (StreamPreparedNativeSettlementTypes.Intent memory intent, bytes memory data, uint64 deadline, bytes memory sig) = _intent(payer, 1);
        (bytes32 root,) = sale.preview(intent, data);
        // Keep the exact signed bytes across the timestamp cheatcode.
        bytes memory originalCall = abi.encodeCall(sale.execute, (intent, data, deadline, sig));
        _status(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.prank(payer); (bool ok,) = address(sale).call{value: 1000}(originalCall);
        require(!ok, "incident pin does not bypass status"); _unchanged(intent, root, payer, 1 ether);
        _status(address(recorder), ModuleRegistryStatus.ACTIVE);
        vm.warp(1001); _status(address(recorder), ModuleRegistryStatus.DEPRECATED);
        vm.prank(payer); (ok,) = address(sale).call{value: 1000}(originalCall);
        require(ok && core.ownerOf(1) == address(sale) && wallet.balance == 1000, "retained pre-deprecation binding and same signed retry");
    }

    function testOriginalSingleStepTranscriptMatchesIndependentIdentityAfterExtraction() public { _legacyPath(false); }
    function testOriginalUnpaidPreparedTranscriptMatchesIndependentIdentityAfterExtraction() public { _legacyPath(true); }

    function testOriginalNativeFixedSaleActualCoreRollsBackThenSameSignedPaymentRetries() public {
        StreamNativeFixedPriceSaleAdapter nativeSale = new StreamNativeFixedPriceSaleAdapter(
            manager,
            recorder,
            vm.addr(SIGNER_KEY),
            artists,
            IStreamGasParameterHost.GasParameterConfig("REVEAL_ATTEMPT_GAS_LIMIT", 2_000_000, 50_000, 2)
        );
        require(address(nativeSale).code.length <= 24576, "original native adapter fits");
        _register(address(nativeSale), keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId, keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"));
        manager.setPhaseExecutor(1, PHASE, address(nativeSale), true);
        bytes32 primary = resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash;
        bytes32 saleId = nativeSale.registerSale(IStreamNativeFixedPriceSaleAdapter.SaleConfig(
            1, PHASE, 1000, 0, uint64(block.timestamp + 10000), manager.phasePolicyHash(1, PHASE), primary
        ));
        NativeRecordingRegressionReceiver recipient = new NativeRecordingRegressionReceiver(wallet);
        IStreamNativeFixedPriceSaleAdapter.SaleExecutionData memory e;
        e.tokenData = bytes("original native exact artwork");
        e.authorization = IStreamNativeFixedPriceSaleAdapter.SaleAuthorization(
            saleId, nativeSale.saleRecord(saleId).configHash, payer, payer, address(recipient),
            vm.addr(SIGNER_KEY), keccak256(e.tokenData), keccak256("original native commitment"),
            1, bytes32(uint256(1)), uint64(block.timestamp + 1000),
            StreamSaleTemplate.policyHash(resolver, 1, StreamNativeSettlementSupport.rights(resolver, 1))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, nativeSale.authorizationDigest(e.authorization));
        e.platformSignature = abi.encodePacked(r, s, v);
        e.artistSignature = e.platformSignature;
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c = nativeSale.previewExecution(e);
        bytes32 key = recorder.settlementKey(address(nativeSale), c.executionBinding.executionId);
        uint256 beforeBalance = payer.balance;
        uint256 beforeNonce = manager.nextOperationNonce();
        vm.deal(address(recorder), 37);
        vm.prank(payer);
        (bool ok,) = address(nativeSale).call{value: 1000}(abi.encodeCall(nativeSale.purchase, (e)));
        require(!ok && core.collectionMintedEver(1) == 0 && manager.nextOperationNonce() == beforeNonce
            && ledger.counterValue(_counter(payer)) == 0 && payer.balance == beforeBalance
            && !nativeSale.authorizationUsed(vm.addr(SIGNER_KEY), e.authorization.nonce)
            && nativeSale.executionIdByNonce(saleId, 1) == 0 && !recorder.settlementConsumed(key)
            && recorder.totalOfficialSettled(address(0)) == 0 && wallet.balance == 0
            && address(recorder).balance == 37, "late real Core receiver rolls back whole legacy payment");
        recipient.accept();
        vm.prank(payer);
        (StreamPrimarySettlementTypes.PrimarySettlementResult memory result, uint256 tokenId) =
            nativeSale.purchase{value: 1000}(e);
        require(tokenId == 1 && core.ownerOf(tokenId) == address(recipient)
            && keccak256(core.tokenData(tokenId)) == keccak256(e.tokenData)
            && recipient.observedPayment() == 1000 && wallet.balance == 1000
            && payer.balance == beforeBalance - 1000 && address(recorder).balance == 37
            && recorder.officialSettled(CLASS, profile, wallet, address(0)) == 1000
            && recorder.totalOfficialSettled(address(0)) == 1000 && recorder.settlementConsumed(key)
            && manager.nextOperationNonce() == beforeNonce + 1 && ledger.counterValue(_counter(payer)) == 1,
            "same signed legacy request funds before actual mint and preserves passive balance");
        require(result.candidateCommitment == StreamNativeSettlementHash.candidateCommitment(address(recorder), c)
            && result.settlementKey == key && result.operationIdentityCommitment == c.operationIdentityCommitment
            && keccak256(abi.encode(result)) == keccak256(abi.encode(recorder.settlementResult(key))),
            "full original result retained through fixed linked recorder");
        vm.prank(payer);
        (ok,) = address(nativeSale).call{value: 1000}(abi.encodeCall(nativeSale.purchase, (e)));
        require(!ok && core.collectionMintedEver(1) == 1 && wallet.balance == 1000
            && recorder.totalOfficialSettled(address(0)) == 1000, "original authorization cannot replay");
    }

    function _legacyPath(bool prepared) private {
        manager.setPhaseExecutor(1, PHASE, address(this), true);
        IStreamMintManager.MintBatch memory b;
        b.collectionId = 1; b.phaseId = PHASE; b.payer = payer;
        b.initialRecipients = new address[](1); b.initialRecipients[0] = payer;
        b.beneficiaries = new address[](1); b.beneficiaries[0] = payer;
        b.tokenData = new bytes[](1); b.tokenData[0] = bytes("original unpaid path");
        b.mintCommitments = new bytes32[](1); b.mintCommitments[0] = keccak256("original mint");
        b.expectedPolicyHash = manager.phasePolicyHash(1, PHASE); b.authorizationId = keccak256(abi.encode("original authorization", prepared)); b.contextHash = keccak256("original context");
        bytes32[] memory counterIds = new bytes32[](1); counterIds[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory configs = new IStreamMintManager.MintCounterConfig[](1); configs[0] = manager.counterConfig(1, PHASE, COUNTER);
        IStreamMintLedger.CounterConsumption[] memory consumptions = StreamMintOperationIdentity.deriveCounterConsumptions(b, 1, counterIds, configs,
            StreamMintOperationIdentity.CounterContext(block.chainid, address(manager), address(ledger), address(this), address(0)));
        StreamMintOperationIdentity.MintAuthorization memory authority = StreamMintOperationIdentity.MintAuthorization(b.authorizationId, new bytes32[](0), address(0), IStreamMintManager.AuthorizerKind.NONE, 0, 0);
        bytes32 path = prepared ? keccak256("6529STREAM_MINT_EXECUTION_PATH_PREPARED_V1") : keccak256("6529STREAM_MINT_EXECUTION_PATH_SINGLE_STEP_V1");
        (bytes32 expected, bytes32[] memory expectedIds) = StreamMintOperationIdentity.derive(b, authority, consumptions,
            StreamMintOperationIdentity.TranscriptContext(block.chainid, address(manager), address(core), address(ledger), address(0), address(this), path, b.expectedPolicyHash, b.expectedPolicyHash, 0, 1));
        bytes32 preview; bytes32[] memory previewIds;
        if (prepared) (preview, previewIds) = manager.previewPreparedNativeMintOperation(b, "");
        else (preview, previewIds) = manager.previewSingleStepMintOperation(b, "");
        require(preview == expected && keccak256(abi.encode(previewIds)) == keccak256(abi.encode(expectedIds)), "full explicit original transcript preimage");
        uint256[] memory tokens; bytes32 root; bytes32[] memory ids;
        if (prepared) (tokens, root, ids) = manager.executePreparedMint(b, "");
        else (tokens, root, ids) = manager.executeSingleStepMint(b, "");
        require(tokens.length == 1 && tokens[0] == 1 && root == expected && ids[0] == expectedIds[0] && core.ownerOf(1) == payer, "original current execution matches independent derivation");
        require(manager.nextOperationNonce() == 1 && ledger.isManagerOperationRootUsed(address(manager), root) && recorder.totalOfficialSettled(address(0)) == 0 && core.pendingPreparedMintTokenId() == 0, "original consumption and unpaid semantics");
    }

    function _intent(address who, uint256 execution) private returns (StreamPreparedNativeSettlementTypes.Intent memory i, bytes memory data, uint64 deadline, bytes memory sig) {
        data = abi.encode("actual prepared artwork", execution);
        i.collectionId = 1; i.phaseId = PHASE; i.saleId = keccak256("prepared fixture sale"); i.saleNonce = 1;
        i.executor = who; i.payer = who; i.poster = vm.addr(SIGNER_KEY); i.beneficiary = who; i.amount = 1000;
        i.primaryPolicyMode = 1; i.executionNonce = execution; i.authorityMode = 1;
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a = resolver.resolvePrimaryAssignment(1, 0, CLASS);
        i.originalPrimaryPolicyHash = keccak256(abi.encode(keccak256("6529STREAM_PRIMARY_POLICY_V1"), block.chainid, address(resolver), CLASS, uint256(1), uint256(0), bytes32(0), profile, wallet, a.assignmentHash));
        i.contentSelectionHash = keccak256(data); i.mintCommitment = keccak256(abi.encode("prepared commitment", execution));
        i.boundMintPolicyHash = manager.phasePolicyHash(1, PHASE);
        deadline = uint64(block.timestamp + 1 days);
        i.saleAuthorizationDigest = sale.authorizationDigest(i, deadline);
        i.saleExecutionHash = keccak256(abi.encode(i.saleAuthorizationDigest, execution));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, i.saleAuthorizationDigest); sig = abi.encodePacked(r, s, v);
    }

    function _counter(address who) private view returns (bytes32) {
        bytes32 subject = manager.previewSubjectKey(IStreamMintManager.CounterKeyMode.PAYER, 1, PHASE, COUNTER, who, who, address(sale), address(0), 0);
        return ledger.deriveCounterValueKey(address(manager), 1, PHASE, COUNTER, subject);
    }

    function _unchanged(StreamPreparedNativeSettlementTypes.Intent memory i, bytes32 root, address who, uint256 balance) private view {
        (, bytes32 hash) = sale.batch(i, "");
        require(who.balance == balance && wallet.balance == 0 && address(sale).balance == 0 && recorder.totalOfficialSettled(address(0)) == 0, "money rollback");
        require(!sale.used(i.saleAuthorizationDigest) && !ledger.isManagerAuthorizationUsed(address(manager), hash) && !ledger.isManagerOperationRootUsed(address(manager), root), "replay rollback");
        require(core.pendingPreparedMintTokenId() == 0 && core.lastAllocatedTokenId() == 0 && core.collectionNextSerial(1) == 1 && core.collectionMintedEver(1) == 0, "Core rollback");
        require(manager.nextOperationNonce() == 0 && ledger.counterValue(_counter(who)) == 0 && manager.activePreparedNativeMint().operationRoot == 0 && entropy.calls() == 0, "Manager and hook rollback");
        require(!recorder.preparedNativeSaleConsumed(recorder.preparedNativeSaleKey(address(sale), i.saleId, i.saleNonce)), "9 original sale rollback");
    }

    function _pointer(bytes32 pointerType, address target) private {
        (bool ok, bytes memory raw) = address(core).staticcall(abi.encodeCall(core.getSatellitePointer, (pointerType))); require(ok);
        StreamCorePointerState memory oldPointer = abi.decode(raw, (StreamCorePointerState));
        StreamModuleRecord memory r = registry.moduleRecord(target);
        StreamCorePointerState memory next = StreamCorePointerState(target, target.codehash, false, r.moduleType, r.interfaceId, address(registry), uint8(r.status), r.moduleManifestHash, r.deploymentManifestHash, oldPointer.revision + 1);
        bytes32 scope = keccak256(abi.encode(bytes32(0xf4a381d3d4c51db07c19830799ea01c544326118ea1db1fb59d54af5f637bdbb), block.chainid, address(core), pointerType));
        _context(scope, StreamCoreExternalReads.pointerStateHash(scope, oldPointer, oldPointer.revision), StreamCoreExternalReads.pointerStateHash(scope, next, next.revision), 3);
        vm.prank(address(revenueAuthority)); core.updateSatellitePointer(pointerType, target); _clearContext();
    }

    function _collection() private {
        bytes32 scope = keccak256(abi.encode(bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16), block.chainid, address(core), uint256(1)));
        bytes32 d = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        _context(scope, keccak256(abi.encode(d, scope, false, uint8(0), uint8(0), false, uint256(0))), keccak256(abi.encode(d, scope, true, uint8(2), uint8(0), false, uint256(0))), 1);
        vm.prank(address(revenueAuthority)); core.createCollection(2, false, 0, 0); _clearContext();
    }

    function _context(bytes32 scope, bytes32 oldState, bytes32 newState, uint8 actionClass) private {
        revenueAuthority.setCurrentAction(true, bytes32(++actionNonce), actionClass, scope, oldState, newState);
    }
    function _clearContext() private { revenueAuthority.setCurrentAction(false, 0, 0, 0, 0, 0); }
    function _register(address module, bytes32 role, bytes4 capability, bytes32 version) private {
        StreamModuleRegistration memory r = StreamModuleRegistration(module, role, version, capability, 0, module.codehash, MANIFEST, MANIFEST, "urn:prepared:module");
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(r);
        _context(scope, oldState, newState, 1); vm.prank(address(revenueAuthority)); registry.registerModule(r); _clearContext();
    }
    function _status(address module, ModuleRegistryStatus status) private {
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _statusTransition(module, status);
        _context(scope, oldState, newState, uint8(status) > uint8(registry.moduleRecord(module).status) ? 0 : 1);
        vm.prank(address(revenueAuthority)); registry.setModuleStatus(module, status, keccak256("prepared fixture status"), "urn:prepared:status"); _clearContext();
    }

    // Literal registration preimages copied from UniversalSettlementTestBase; actual Registry checks them.
    function _expectedChainHash(
        bytes32 previousChainHash,
        StreamModuleRegistration memory registration,
        bytes32 runtimeCodeHash,
        uint64 recordIndex
    ) internal view returns (bytes32) {
        bytes32 recordHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_RECORD_V1(),
                registration.module,
                registration.moduleType,
                registration.interfaceId,
                registration.moduleVersion,
                runtimeCodeHash,
                registration.deploymentManifestHash,
                registration.moduleManifestHash
            )
        );
        return keccak256(
            abi.encode(
                registry.STREAM_RECORD_CHAIN_V1(),
                uint256(block.chainid),
                address(registry),
                uint256(0),
                keccak256("MODULE_REGISTRATION"),
                previousChainHash,
                recordHash,
                recordIndex
            )
        );
    }

    function _recordFactsHash(
        ModuleRegistryStatus status,
        StreamModuleRegistration memory registration,
        bytes32 runtimeCodeHash,
        uint64 revision
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                registration.moduleType,
                registration.moduleVersion,
                registration.interfaceId,
                registration.moduleGasLimit,
                runtimeCodeHash,
                registration.deploymentManifestHash,
                registration.moduleManifestHash,
                keccak256(bytes(registration.moduleManifestURI)),
                revision
            )
        );
    }

    function _emptyRecordFactsHash() internal pure returns (bytes32) {
        StreamModuleRegistration memory empty;
        return _recordFactsHash(ModuleRegistryStatus.UNKNOWN, empty, bytes32(0), 0);
    }

    function _registrationTransition(StreamModuleRegistration memory registration)
        private
        view
        returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)
    {
        uint256 count = registry.moduleCount();
        (bytes32 chainHash, uint64 recordCount) = registry.registrationChainHash();
        uint64 index = uint64(count);
        bytes32 newChainHash =
            _expectedChainHash(chainHash, registration, registration.module.codehash, index);
        scopeHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_SCOPE_V1(),
                uint256(block.chainid),
                address(registry),
                registration.module
            )
        );
        oldValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scopeHash,
                false,
                _emptyRecordFactsHash(),
                count,
                chainHash,
                recordCount,
                address(0)
            )
        );
        newValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scopeHash,
                true,
                _recordFactsHash(
                    ModuleRegistryStatus.ACTIVE, registration, registration.module.codehash, 1
                ),
                count + 1,
                newChainHash,
                recordCount + 1,
                registration.module
            )
        );
    }

    function _storedRecordFactsHash(
        StreamModuleRecord memory record,
        ModuleRegistryStatus status,
        uint64 revision
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                record.moduleType,
                record.moduleVersion,
                record.interfaceId,
                record.moduleGasLimit,
                record.runtimeCodeHash,
                record.deploymentManifestHash,
                record.moduleManifestHash,
                keccak256(bytes(record.moduleManifestURI)),
                revision
            )
        );
    }

    function _statusTransition(address moduleAddress, ModuleRegistryStatus newStatus)
        private
        view
        returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)
    {
        StreamModuleRecord memory record = registry.moduleRecord(moduleAddress);
        (bytes32 chainHash, uint64 recordCount) = registry.registrationChainHash();
        scopeHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_SCOPE_V1(),
                uint256(block.chainid),
                address(registry),
                moduleAddress
            )
        );
        oldValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scopeHash,
                _storedRecordFactsHash(record, record.status, record.revision),
                registry.moduleCount(),
                chainHash,
                recordCount
            )
        );
        newValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scopeHash,
                _storedRecordFactsHash(record, newStatus, record.revision + 1),
                registry.moduleCount(),
                chainHash,
                recordCount
            )
        );
    }
}
