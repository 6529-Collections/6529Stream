// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/RevenueV1TestBase.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../unit/revenue/PreparedNativeSaleFixture.sol";
import "./NativeEnglishAuctionMocks.sol";
import "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import "../../smart-contracts/core/StreamCore.sol";
import "../../smart-contracts/core/StreamCoreExternalReads.sol";
import "../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";

/// @notice Real Core/Manager/Ledger/Registry/9, wallet/escrow, roles and Safe.
/// @dev Setup/registry helpers copied from native-first6 with explicit house and semantic
/// Artist/entropy additions. The Executor is a target-side context fixture, not full governance.
abstract contract NativeEnglishAuctionFixture is RevenueV1TestBase, OfficialSafeFixture {
    bytes32 internal constant PHASE = keccak256("actual paid prepared phase");
    bytes32 internal constant COUNTER = keccak256("prepared payer counter");
    bytes32 internal constant CLASS = keccak256("PRIMARY_SALE");
    bytes32 internal constant MANIFEST = keccak256("prepared fixture manifest");
    uint256 internal constant SIGNER_KEY = 0x6529035;
    uint256 internal constant PAYER_KEY = 0x6529036;
    uint256 internal constant AUCTION_PLATFORM_KEY = 0x6529088;
    StreamCore internal core;
    StreamMintLedger internal ledger;
    StreamMintManager internal manager;
    StreamModuleRegistry internal registry;
    StreamAssetPolicyRegistry internal policy;
    StreamSplitFactory internal factory;
    StreamRevenueResolver internal resolver;
    StreamRevenueEscrow internal escrow;
    StreamPrimarySaleSettlement internal recorder;
    StreamNativeEnglishAuction internal house;
    StreamRoleRegistry internal auctionRoles;
    NativeAuctionArtist internal artists;
    NativeAuctionEntropy internal entropy;
    bytes32 internal profile;
    address internal wallet;
    address internal payer;
    uint256 internal actionNonce;

    function setUp() public virtual {
        vm.warp(1000);
        payer = vm.addr(PAYER_KEY);
        revenueAuthority = new NativeAuctionAuthority();
        registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(revenueAuthority)), MANIFEST, "urn:prepared:registry"
        );
        StreamCore.GasParameterGenesisConfig[] memory gasRows =
            new StreamCore.GasParameterGenesisConfig[](4);
        gasRows[0] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ROYALTY_RESOLVER_GAS_LIMIT"), 50000, 25000, 1
        );
        gasRows[1] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ROYALTY_RETURN_GAS_BUFFER"), 2910000, 1460000, 1
        );
        gasRows[2] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_METADATA_ROUTER_GAS_LIMIT"), 500000, 250000, 1
        );
        gasRows[3] = StreamCore.GasParameterGenesisConfig(
            keccak256("6529STREAM_GGP_ENTROPY_REGISTRATION_GAS_LIMIT"), 120000, 120000, 2
        );
        core = new StreamCore(
            "Prepared Current",
            "PPC",
            address(revenueAuthority),
            StreamCore.GenesisModuleRegistryConfig(
                address(registry), address(registry).codehash, MANIFEST, MANIFEST
            ),
            gasRows
        );
        ledger = new StreamMintLedger();
        manager = new StreamMintManager(core, ledger, IERC165(address(registry)));
        ledger.setLedgerWriter(address(manager), true);
        _register(
            address(registry),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            MANIFEST
        );
        _register(
            address(manager),
            keccak256("MINT_MANAGER"),
            type(IStreamMintManager).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("MINT_MANAGER"), address(manager));
        artists = new NativeAuctionArtist(address(core), address(manager));
        _register(
            address(artists),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("ARTIST_REGISTRY"), address(artists));
        entropy = new NativeAuctionEntropy(address(core));
        _register(
            address(entropy),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId,
            MANIFEST
        );
        _pointer(keccak256("ENTROPY_COORDINATOR"), address(entropy));
        _collection();
        policy = new StreamAssetPolicyRegistry(address(revenueAuthority));
        IStreamGasParameterHost.GasParameterConfig[3] memory config = _walletGasConfigs();
        config[2].genesisValue = 500000;
        factory = new StreamSplitFactory(policy, address(revenueAuthority), config);
        resolver = new StreamRevenueResolver(
            core,
            factory,
            address(revenueAuthority),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200000, 50000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        resolver.transferOwnership(address(this));
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] =
            IStreamSplitWallet.SplitEntry(vm.addr(SIGNER_KEY), 1000000, keccak256("artist"));
        (profile, wallet) = factory.createProfile(entries, keccak256("prepared rights"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        artists.accept(vm.addr(SIGNER_KEY));
        escrow = new StreamRevenueEscrow(
            factory,
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12000000, 12000000, 3)
        );
        recorder = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        _register(
            address(recorder),
            keccak256("PRIMARY_SALE_SETTLEMENT"),
            type(IStreamPreparedNativePrimarySaleSettlement).interfaceId,
            keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1")
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            escrow.creditProducerTransitionHashes(address(recorder), true);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        escrow.setCreditProducer(address(recorder), true);
        _clearContext();
        auctionRoles = new StreamRoleRegistry(address(revenueAuthority));
        NativeAuctionAuthority(address(revenueAuthority)).setRoleRegistry(address(auctionRoles));
        _grantAuctionRole(keccak256("ROLE_PAUSE_GUARDIAN"), address(0xA11));
        _grantAuctionRole(keccak256("ROLE_UNPAUSE"), address(0xB22));
        StreamNativeEnglishAuction.DeploymentConfig memory d;
        d.manager = manager;
        d.recorder = recorder;
        d.platform = vm.addr(AUCTION_PLATFORM_KEY);
        d.artists = artists;
        d.entropy = entropy;
        d.roles = auctionRoles;
        d.authority = address(revenueAuthority);
        d.parameters[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 300000, 50000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200000, 50000, 2
        );
        d.parameters[3] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300000, 100000, 2
        );
        _prepareHouseConfiguration(d);
        house = new StreamNativeEnglishAuction(d);
        _register(
            address(house),
            keccak256("NATIVE_PREPARED_SALE_ADAPTER"),
            type(IStreamPreparedNativeSaleBinding).interfaceId,
            keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1")
        );
        _bindPreparedRecorder();
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = COUNTER;
        IStreamMintManager.MintCounterConfig[] memory counters =
            new IStreamMintManager.MintCounterConfig[](1);
        counters[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            PHASE,
            IStreamMintManager.MintPhaseConfig(false, 0, 0, 1, MANIFEST, MANIFEST),
            gate,
            ids,
            counters
        );
        manager.setPhaseExecutor(1, PHASE, address(house), true);
        require(address(house).code.length <= 24576, "actual house EIP170");
        require(
            address(core).code.length <= 24576 && address(manager).code.length <= 24576
                && address(recorder).code.length <= 24576,
            "actual production EIP170"
        );
        vm.deal(payer, 1 ether);
    }

    /// @dev Deployment tests exercise the separate post-admission binding stage.
    function _bindPreparedRecorder() internal virtual {
        manager.bindPreparedNativeRecorder(address(recorder));
    }

    /// @dev Optional independently tested declaration profile; default fixture remains self-only.
    function _prepareHouseConfiguration(StreamNativeEnglishAuction.DeploymentConfig memory)
        internal
        virtual { }

    function _moduleManifest(address) internal view virtual returns (bytes32) {
        return MANIFEST;
    }

    function _pointer(bytes32 pointerType, address target) internal {
        (bool ok, bytes memory raw) =
            address(core).staticcall(abi.encodeCall(core.getSatellitePointer, (pointerType)));
        require(ok);
        StreamCorePointerState memory oldPointer = abi.decode(raw, (StreamCorePointerState));
        StreamModuleRecord memory r = registry.moduleRecord(target);
        StreamCorePointerState memory next = StreamCorePointerState(
            target,
            target.codehash,
            false,
            r.moduleType,
            r.interfaceId,
            address(registry),
            uint8(r.status),
            r.moduleManifestHash,
            r.deploymentManifestHash,
            oldPointer.revision + 1
        );
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0xf4a381d3d4c51db07c19830799ea01c544326118ea1db1fb59d54af5f637bdbb),
                block.chainid,
                address(core),
                pointerType
            )
        );
        _context(
            scope,
            StreamCoreExternalReads.pointerStateHash(scope, oldPointer, oldPointer.revision),
            StreamCoreExternalReads.pointerStateHash(scope, next, next.revision),
            3
        );
        vm.prank(address(revenueAuthority));
        core.updateSatellitePointer(pointerType, target);
        _clearContext();
    }

    function _collection() internal {
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                block.chainid,
                address(core),
                uint256(1)
            )
        );
        bytes32 d = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        _context(
            scope,
            keccak256(abi.encode(d, scope, false, uint8(0), uint8(0), false, uint256(0))),
            keccak256(abi.encode(d, scope, true, uint8(2), uint8(0), false, uint256(0))),
            1
        );
        vm.prank(address(revenueAuthority));
        core.createCollection(2, false, 0, 0);
        _clearContext();
    }

    function _context(bytes32 scope, bytes32 oldState, bytes32 newState, uint8 actionClass)
        internal
    {
        revenueAuthority.setCurrentAction(
            true, bytes32(++actionNonce), actionClass, scope, oldState, newState
        );
    }

    function _clearContext() internal {
        revenueAuthority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _register(address module, bytes32 role, bytes4 capability, bytes32 version) internal {
        StreamModuleRegistration memory r = StreamModuleRegistration(
            module,
            role,
            version,
            capability,
            0,
            module.codehash,
            MANIFEST,
            _moduleManifest(module),
            "urn:prepared:module"
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(r);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        registry.registerModule(r);
        _clearContext();
    }

    function _status(address module, ModuleRegistryStatus status) internal {
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _statusTransition(module, status);
        _context(
            scope,
            oldState,
            newState,
            uint8(status) > uint8(registry.moduleRecord(module).status) ? 0 : 1
        );
        vm.prank(address(revenueAuthority));
        registry.setModuleStatus(
            module, status, keccak256("prepared fixture status"), "urn:prepared:status"
        );
        _clearContext();
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
        internal
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
        internal
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

    function _grantAuctionRole(bytes32 role, address holder) internal {
        (bytes32 r, uint64 rn) = auctionRoles.roleMutationState(role);
        (bytes32 g, uint64 gn) = auctionRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(auctionRoles),
                role,
                holder
            )
        );
        bytes32 nextR = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                r,
                block.chainid,
                address(auctionRoles),
                role,
                holder,
                true,
                rn + 1
            )
        );
        bytes32 nextG = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                g,
                block.chainid,
                address(auctionRoles),
                role,
                holder,
                true,
                gn + 1
            )
        );
        _context(
            scope,
            _roleState(scope, false, r, rn, g, gn),
            _roleState(scope, true, nextR, rn + 1, nextG, gn + 1),
            1
        );
        vm.prank(address(revenueAuthority));
        auctionRoles.grantRole(role, holder);
        _clearContext();
        require(auctionRoles.hasRole(role, holder), "actual role grant");
    }

    function _roleState(bytes32 scope, bool granted, bytes32 r, uint64 rn, bytes32 g, uint64 gn)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(auctionRoles),
                scope,
                granted,
                r,
                rn,
                g,
                gn
            )
        );
    }
}
