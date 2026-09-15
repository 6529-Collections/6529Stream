// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./UniversalSettlementTestBase.sol";
import "./RefundWindowTestMocks.sol";
import "../../smart-contracts/domains/mint/StreamNativeDutchSale.sol";
import "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";

/// @dev Actual registry, role registry, split wallets, official recorder and Safe contracts.
///      Core, artist, Manager, fee endpoint and target-side governance are explicit domain doubles.
abstract contract DutchSaleTestBase is UniversalSettlementTestBase {
    StreamNativeDutchSale internal dutchSale;
    RefundRuntimeCore internal refundCore;
    RefundRuntimeManager internal refundManager;
    RefundRuntimeArtist internal refundArtist;
    RefundRuntimeEntropy internal refundEntropy;
    StreamRoleRegistry internal refundRoles;
    bytes32 internal dutchId;
    address internal guardian = address(0xA11);
    address internal unpauser = address(0xB22);

    function setUp() public virtual override {
        revenueAuthority = new RefundRuntimeAuthority();
        super.setUp();
        refundCore = new RefundRuntimeCore();
        core = UniversalCoreMock(address(refundCore));
        refundArtist = new DutchRuntimeArtist(address(core));
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
        dutchSale = new StreamNativeDutchSale(_deployment());
        _register(
            address(dutchSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId
        );
        dutchId = dutchSale.registerDutchSale(_dutchConfig());
        vm.deal(payer, 10 ether);
    }

    function _refundArtistFacade(RefundRuntimeArtist target) internal virtual returns (address) {
        return address(target);
    }

    function _deployment() internal returns (StreamNativeDutchSale.DeploymentConfig memory d) {
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

    function _dutchConfig() internal view returns (IStreamNativeDutchSale.DutchSaleConfig memory) {
        return IStreamNativeDutchSale.DutchSaleConfig(
            1,
            PHASE,
            IStreamDutchPriceSchedule.DutchPriceSchedule(1000, 100, 1000, 1010, 0, 0, 0),
            100,
            10000,
            false,
            refundManager.currentPolicy()
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

    function _dutchData(uint256 number, address buyer, address recipient)
        internal
        returns (IStreamNativeDutchSale.DutchPurchaseData memory d)
    {
        d.tokenData = abi.encode("Dutch artwork", number);
        d.authorization = IStreamNativeDutchSale.DutchAuthorization(
            dutchId,
            dutchSale.saleRecord(dutchId).configHash,
            buyer,
            buyer,
            recipient,
            artist,
            keccak256(d.tokenData),
            keccak256(abi.encode("Dutch mint", number)),
            number,
            bytes32(number),
            uint64(block.timestamp + 1 hours),
            StreamSaleTemplate.policyHash(
                resolver, 1, StreamNativeSettlementSupport.rights(resolver, 1)
            ),
            1000
        );
        _signDutch(d);
    }

    function _signDutch(IStreamNativeDutchSale.DutchPurchaseData memory d) internal {
        bytes32 digest = dutchSale.authorizationDigest(d.authorization);
        d.platformSignature = _sign(PLATFORM_KEY, digest);
        d.artistSignature = _sign(ARTIST_KEY, digest);
    }
}

/// @dev Current consent evidence seam only; actual op16 provenance remains integration-owned.
contract DutchRuntimeArtist is RefundRuntimeArtist {
    constructor(address c) RefundRuntimeArtist(c) { }

    function saleConsentScope(uint256) external view returns (uint8) {
        return saleConsentRequired ? 1 : 0;
    }

    function isSaleConsented(uint256 collection, bytes32 id, bytes32 hash)
        external
        view
        returns (bool, bytes32)
    {
        bytes32 key = keccak256(abi.encode(msg.sender, collection, id, hash));
        bool allowed = saleConsents[key];
        return (allowed, allowed ? keccak256(abi.encode("Dutch consent", key)) : bytes32(0));
    }
}
