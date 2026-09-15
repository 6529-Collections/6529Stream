// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./DutchSaleTestBase.sol";
import "./ClearingSaleTestMocks.sol";
import "../../smart-contracts/domains/mint/StreamNativeClearingSale.sol";

/// @dev Real recorder/registry/factory/wallet/escrow/Safe; explicit Core/Manager/artist/fee/governance seams.
abstract contract ClearingSaleTestBase is DutchSaleTestBase {
    StreamNativeClearingSale internal clearingSale;
    ClearingRuntimeCore internal clearingCore;
    ClearingRuntimeManager internal clearingManager;
    bytes32 internal clearingId;

    function setUp() public virtual override {
        vm.warp(1000);
        payer = vm.addr(PAYER_KEY);
        artist = vm.addr(ARTIST_KEY);
        revenueAuthority = new RefundRuntimeAuthority();
        policy = new StreamAssetPolicyRegistry(address(revenueAuthority));
        IStreamGasParameterHost.GasParameterConfig[3] memory cfg = _walletGasConfigs();
        cfg[2].genesisValue = 500_000;
        factory = new StreamSplitFactory(policy, address(revenueAuthority), cfg);
        registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(revenueAuthority)),
            keccak256("registry"),
            "ipfs://registry"
        );
        clearingCore = new ClearingRuntimeCore();
        refundCore = RefundRuntimeCore(address(clearingCore));
        core = UniversalCoreMock(address(clearingCore));
        refundArtist = new DutchRuntimeArtist(address(core));
        artists = SaleFundingArtistMock(address(refundArtist));
        refundEntropy = new RefundRuntimeEntropy(address(core));
        refundEntropy.setPolicy(true, 1, 20);
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(artists));
        refundCore.setPointer(keccak256("MODULE_REGISTRY"), address(registry));
        refundCore.setPointer(keccak256("ENTROPY_COORDINATOR"), address(refundEntropy));
        clearingManager = new ClearingRuntimeManager(address(core), address(registry));
        refundManager = RefundRuntimeManager(address(clearingManager));
        manager = UniversalManagerMock(address(clearingManager));
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
        (profile, wallet) = factory.createProfile(entries, keccak256("clearing original"));
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        artists.accept(artist);
        refundArtist.setPayout(artist);
        escrow = new StreamRevenueEscrow(
            factory,
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
        );
        recorder = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        _producer(true);
        refundRoles = new StreamRoleRegistry(address(revenueAuthority));
        RefundRuntimeAuthority(address(revenueAuthority)).setRoleRegistry(address(refundRoles));
        _grantRefundRole(keccak256("ROLE_PAUSE_GUARDIAN"), guardian);
        _grantRefundRole(keccak256("ROLE_UNPAUSE"), unpauser);
        clearingSale = new StreamNativeClearingSale(_clearingDeployment());
        _register(
            address(clearingSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId
        );
        clearingId = clearingSale.registerClearingSale(_clearingConfig());
        vm.deal(payer, 10 ether);
        vm.deal(address(this), 10 ether);
    }

    function _clearingDeployment()
        internal
        returns (StreamNativeClearingSale.DeploymentConfig memory d)
    {
        d.manager = IStreamMintManager(address(clearingManager));
        d.recorder = recorder;
        d.platform = vm.addr(PLATFORM_KEY);
        d.artists = artists;
        d.entropy = refundEntropy;
        d.roles = refundRoles;
        d.authority = address(revenueAuthority);
        d.parameters[0] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ERC1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ARTIST_AUTHORITY_GAS_LIMIT", 200_000, 50_000, 2
        );
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig(
            "REVEAL_ATTEMPT_GAS_LIMIT", 200_000, 50_000, 2
        );
    }

    function _clearingConfig()
        internal
        view
        returns (IStreamNativeClearingSale.ClearingSaleConfig memory)
    {
        return IStreamNativeClearingSale.ClearingSaleConfig(
            1,
            PHASE,
            IStreamDutchPriceSchedule.DutchPriceSchedule(1000, 100, 1000, 1100, 0, 0, 0),
            10,
            1100,
            100,
            1500,
            1,
            clearingManager.currentPolicy()
        );
    }

    function _clearingData(uint256 number, address buyer, address recipient)
        internal
        returns (IStreamNativeClearingSale.ClearingPurchaseData memory d)
    {
        IStreamNativeClearingSale.ClearingSaleRecord memory record =
            clearingSale.saleRecord(clearingId);
        d.tokenData = abi.encode("clearing artwork", number);
        d.authorization = IStreamNativeClearingSale.ClearingAuthorization(
            clearingId,
            record.configHash,
            buyer,
            buyer,
            recipient,
            artist,
            keccak256(d.tokenData),
            bytes32(number),
            clearingSale.nextPurchaseNonce(clearingId, buyer),
            number,
            bytes32(number),
            uint64(block.timestamp + 1000),
            _primaryPolicy(),
            1000,
            false,
            0,
            record.windowPolicyHash,
            1200,
            1500
        );
        _signClearing(d);
    }

    function _signClearing(IStreamNativeClearingSale.ClearingPurchaseData memory d) internal {
        bytes32 digest = clearingSale.authorizationDigest(d.authorization);
        d.platformSignature = _sign(PLATFORM_KEY, digest);
        d.artistSignature = _sign(ARTIST_KEY, digest);
    }

    function _buy(uint256 number, uint256 value)
        internal
        returns (IStreamNativeClearingSale.ClearingPurchaseResult memory r)
    {
        IStreamNativeClearingSale.ClearingPurchaseData memory d =
            _clearingData(number, payer, payer);
        vm.prank(payer);
        r = clearingSale.purchase{ value: value }(d);
    }
}
