// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./UniversalSettlementTestBase.sol";
import "./RefundWindowTestMocks.sol";
import "../../smart-contracts/domains/mint/StreamNativeRefundWindowSale.sol";
import "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";

/// @dev Actual registry, role registry, split wallets, official recorder and Safe contracts.
///      Core, artist, Manager, fee endpoint and target-side governance are explicit domain doubles.
abstract contract RefundWindowTestBase is UniversalSettlementTestBase {
    StreamNativeRefundWindowSale internal refundSale;
    RefundRuntimeCore internal refundCore;
    RefundRuntimeManager internal refundManager;
    RefundRuntimeArtist internal refundArtist;
    RefundRuntimeEntropy internal refundEntropy;
    StreamRoleRegistry internal refundRoles;
    bytes32 internal refundId;
    address internal guardian = address(0xA11);
    address internal unpauser = address(0xB22);

    function setUp() public virtual override {
        revenueAuthority = new RefundRuntimeAuthority();
        super.setUp();
        refundCore = new RefundRuntimeCore();
        core = UniversalCoreMock(address(refundCore));
        refundArtist = new RefundRuntimeArtist(address(core));
        artists = SaleFundingArtistMock(_refundArtistFacade(refundArtist));
        refundEntropy = new RefundRuntimeEntropy(address(core));
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(artists));
        refundCore.setPointer(keccak256("MODULE_REGISTRY"), address(registry));
        refundCore.setPointer(keccak256("ENTROPY_COORDINATOR"), address(refundEntropy));
        refundManager = new RefundRuntimeManager(address(core), address(registry));
        manager = UniversalManagerMock(address(refundManager));
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
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        artists.accept(artist);
        refundArtist.setPayout(artist);
        recorder = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        _producer(true);
        refundRoles = new StreamRoleRegistry(address(revenueAuthority));
        RefundRuntimeAuthority(address(revenueAuthority)).setRoleRegistry(address(refundRoles));
        _grantRefundRole(keccak256("ROLE_PAUSE_GUARDIAN"), guardian);
        _grantRefundRole(keccak256("ROLE_UNPAUSE"), unpauser);
        refundSale = new StreamNativeRefundWindowSale(_deployment());
        _register(
            address(refundSale),
            keccak256("NATIVE_REFUND_WINDOW_SALE_ADAPTER"),
            type(IStreamDeferredNativeSaleBinding).interfaceId
        );
        refundId = refundSale.registerRefundSale(_refundConfig());
        vm.deal(payer, 10 ether);
    }

    function _refundArtistFacade(RefundRuntimeArtist target) internal virtual returns (address) {
        return address(target);
    }

    function _deployment()
        internal
        returns (StreamNativeRefundWindowSale.DeploymentConfig memory d)
    {
        d.manager = IStreamMintManager(address(refundManager));
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

    function _refundConfig()
        internal
        view
        returns (IStreamNativeRefundWindowSale.RefundSaleConfig memory)
    {
        return IStreamNativeRefundWindowSale.RefundSaleConfig(
            1, PHASE, 1000, 100, 0, 10_000, 3600, 86400, 1, refundManager.currentPolicy()
        );
    }

    function _grantRefundRole(bytes32 role, address holder) internal {
        (bytes32 r, uint64 rn) = refundRoles.roleMutationState(role);
        (bytes32 g, uint64 gn) = refundRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(refundRoles),
                role,
                holder
            )
        );
        bytes32 nextR = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                r,
                block.chainid,
                address(refundRoles),
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
                address(refundRoles),
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
        refundRoles.grantRole(role, holder);
        _clearContext();
        require(refundRoles.hasRole(role, holder), "actual role grant");
    }

    function _roleState(bytes32 scope, bool granted, bytes32 r, uint64 rn, bytes32 g, uint64 gn)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(refundRoles),
                scope,
                granted,
                r,
                rn,
                g,
                gn
            )
        );
    }

    function _purchaseData(uint256 number, address buyer, address recipient)
        internal
        returns (IStreamNativeRefundWindowSale.RefundPurchaseData memory d)
    {
        IStreamNativeRefundWindowSale.RefundSaleRecord memory s =
            refundSale.refundSaleRecord(refundId);
        d.tokenData = abi.encode("refund artwork", number);
        d.authorization = IStreamNativeRefundWindowSale.RefundPurchaseAuthorization(
            refundId,
            s.configHash,
            buyer,
            recipient,
            artist,
            keccak256(d.tokenData),
            keccak256(abi.encode("refund mint", number)),
            refundSale.nextPurchaseNonce(refundId, buyer),
            bytes32(number),
            1000,
            uint64(block.timestamp + 1 hours),
            s.windowPolicyHash,
            uint64(block.timestamp + 90_000),
            uint64(block.timestamp + 100_000),
            StreamSaleTemplate.policyHash(
                resolver, 1, StreamNativeSettlementSupport.rights(resolver, 1)
            )
        );
        _signPurchase(d);
    }

    function _signPurchase(IStreamNativeRefundWindowSale.RefundPurchaseData memory d) internal {
        bytes32 digest = refundSale.refundPurchaseAuthorizationDigest(d.authorization);
        d.platformSignature = _sign(PLATFORM_KEY, digest);
        d.artistSignature = _sign(ARTIST_KEY, digest);
    }

    function _purchase(uint256 number, uint256 value) internal returns (bytes32 id) {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d =
            _purchaseData(number, payer, payer);
        vm.prank(payer);
        id = refundSale.purchaseRefundWindow{ value: value }(d);
    }

    function _atRefundEnd(bytes32 id) internal {
        (uint64 deadline,,) = refundSale.purchaseDeadlines(id);
        vm.warp(deadline);
    }

    function _pauseGlobal(bool paused) internal {
        vm.prank(paused ? guardian : unpauser);
        if (paused) refundSale.pauseAdapter(keccak256("test pause"));
        else refundSale.unpauseAdapter(keccak256("test unpause"));
    }

    function _pauseLocal(bool paused) internal {
        vm.prank(paused ? guardian : unpauser);
        if (paused) refundSale.pauseRefundSale(refundId, keccak256("test local pause"));
        else refundSale.unpauseRefundSale(refundId, keccak256("test local unpause"));
    }

    function _pending(bytes32 id, uint256 balance, uint256 credit) internal view {
        require(
            refundSale.refundPurchaseRecord(id).status == 1
                && refundSale.totalPendingDeposits() == 1100
                && refundSale.totalBuyerLiabilities() == 1100 + credit,
            "pending liabilities"
        );
        require(
            address(refundSale).balance == balance && refundSale.refundCredit(payer) == credit,
            "pending funds"
        );
        require(
            refundManager.nonce() == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && wallet.balance == 0 && refundEntropy.revealFeeEscrow(1) == 0,
            "no mint/official funding/fee yet"
        );
    }
}
