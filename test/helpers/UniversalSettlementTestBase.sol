// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./RevenueV1TestBase.sol";
import "./UniversalSettlementTestMocks.sol";
import "./OfficialPermit2Fixture.sol";
import "./OfficialSafeFixture.sol";
import "../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol";
import "../../smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol";
import "../../smart-contracts/domains/mint/StreamUniversalFixedPriceSaleAdapter.sol";

abstract contract UniversalSettlementTestBase is
    RevenueV1TestBase,
    OfficialPermit2Fixture,
    OfficialSafeFixture
{
    uint256 internal constant PAYER_KEY = 0x111;
    uint256 internal constant ARTIST_KEY = 0x222;
    uint256 internal constant PLATFORM_KEY = 0x333;
    bytes32 internal constant CLASS = keccak256("PRIMARY_SALE");
    bytes32 internal constant PHASE = keccak256("universal phase");
    address internal payer;
    address internal artist;
    StreamAssetPolicyRegistry internal policy;
    StreamSplitFactory internal factory;
    StreamRevenueResolver internal resolver;
    StreamRevenueEscrow internal escrow;
    StreamModuleRegistry internal registry;
    UniversalCoreMock internal core;
    SaleFundingArtistMock internal artists;
    UniversalManagerMock internal manager;
    UniversalPermitToken internal token;
    StreamPrimarySaleSettlement internal recorder;
    StreamERC20PrimarySettlementAdapter internal payment;
    StreamUniversalFixedPriceSaleAdapter internal sale;
    address internal permit2;
    bytes32 internal profile;
    address internal wallet;
    bytes32 internal saleId;
    uint256 internal actionNonce = 1000;

    function setUp() public virtual {
        vm.warp(1000);
        payer = vm.addr(PAYER_KEY);
        artist = vm.addr(ARTIST_KEY);
        policy = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        IStreamGasParameterHost.GasParameterConfig[3] memory configs = _walletGasConfigs();
        configs[2].genesisValue = _depositBudget();
        configs[2].floor = 25_000;
        factory = new StreamSplitFactory(policy, address(revenueAuthority), configs);
        registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(revenueAuthority)),
            keccak256("registry"),
            "ipfs://registry"
        );
        core = new UniversalCoreMock();
        artists = new SaleFundingArtistMock(address(core));
        core.configure(address(artists), address(registry));
        manager = new UniversalManagerMock(address(core), address(registry));
        resolver = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        resolver.transferOwnership(address(this));
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 1_000_000, keccak256("artist"));
        (profile, wallet) = factory.createProfile(entries, keccak256("universal"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        artists.accept(artist);
        escrow = new StreamRevenueEscrow(
            factory,
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
        );
        permit2 = deployOfficialPermit2();
        recorder = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        payment = new StreamERC20PrimarySettlementAdapter(recorder, permit2, permit2.codehash);
        sale = new StreamUniversalFixedPriceSaleAdapter(
            IStreamMintManager(address(manager)), recorder, vm.addr(PLATFORM_KEY), artists
        );
        _register(
            address(payment),
            keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER"),
            type(IStreamERC20PrimarySettlementAdapter).interfaceId
        );
        _register(
            address(sale),
            keccak256("FIXED_PRICE_SALE_ADAPTER"),
            type(IStreamERC20SaleExecution).interfaceId
        );
        _producer(true);
        token = new UniversalPermitToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("exact permit token"), 0);
        _permitPolicy(3, 1);
        saleId = sale.registerSale(
            IStreamUniversalFixedPriceSaleAdapter.SaleConfig(
                address(payment),
                1,
                PHASE,
                address(token),
                1000,
                0,
                10_000,
                manager.POLICY(),
                _primaryPolicy()
            )
        );
        token.mint(payer, 10_000);
        vm.prank(payer);
        token.approve(address(payment), 10_000);
    }

    function _primaryPolicy() internal view returns (bytes32) {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(1, 0, CLASS);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                CLASS,
                uint256(1),
                uint256(0),
                bytes32(0),
                profile,
                wallet,
                a.assignmentHash
            )
        );
    }

    function _depositBudget() internal pure virtual returns (uint256) {
        return 500_000;
    }

    function _execution(address who, address executor, address recipient, uint256 number)
        internal
        returns (
            IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e,
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
        )
    {
        e.tokenData = abi.encode("universal artwork", number);
        e.authorization = IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization(
            saleId,
            sale.saleRecord(saleId).configHash,
            who,
            executor,
            recipient,
            artist,
            keccak256(e.tokenData),
            keccak256(abi.encode("mint", number)),
            number,
            bytes32(number),
            uint64(block.timestamp + 1 hours)
        );
        bytes32 digest = sale.authorizationDigest(e.authorization);
        e.platformSignature = _sign(PLATFORM_KEY, digest);
        e.artistSignature = _sign(ARTIST_KEY, digest);
        c = sale.previewExecution(e);
    }

    function _sign(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _producer(bool enabled) internal {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            escrow.creditProducerTransitionHashes(address(recorder), enabled);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        escrow.setCreditProducer(address(recorder), enabled);
        _clearContext();
    }

    function _permitPolicy(uint8 bits, uint8 mode) internal {
        address target = bits & 2 != 0 ? permit2 : address(0);
        bytes32 hash = target == address(0) ? bytes32(0) : target.codehash;
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            policy.assetPermitPolicyTransitionHashes(address(token), bits, mode, target, hash);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        policy.setAssetPermitPolicy(address(token), bits, mode, target, hash);
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

    function _register(address module, bytes32 role, bytes4 capability) internal {
        StreamModuleRegistration memory r = StreamModuleRegistration(
            module,
            role,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            capability,
            0,
            module.codehash,
            keccak256("deployment"),
            keccak256("module"),
            "ipfs://module"
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(r);
        _context(scope, oldState, newState, 1);
        vm.prank(address(revenueAuthority));
        registry.registerModule(r);
        _clearContext();
    }

    function _status(address module, ModuleRegistryStatus status) internal {
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _statusTransition(module, status);
        uint8 actionClass = uint8(status) > uint8(registry.moduleRecord(module).status) ? 0 : 1;
        _context(scope, oldState, newState, actionClass);
        vm.prank(address(revenueAuthority));
        registry.setModuleStatus(module, status, keccak256("test transition"), "ipfs://reason");
        _clearContext();
    }

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
