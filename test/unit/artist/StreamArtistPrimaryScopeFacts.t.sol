// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../helpers/RevenueResolverTestMocks.sol";
import "../../helpers/GovernedParameterTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";

interface PrimaryScopeVm {
    function prank(address) external;
    function expectRevert(bytes calldata) external;
}

/// @dev Actual resolver/factory/wallet/Safe; explicit Core identity and governance boundaries.
contract StreamArtistPrimaryScopeFactsTest is OfficialSafeFixture {
    PrimaryScopeVm private constant vm =
        PrimaryScopeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant PRIMARY = keccak256("PRIMARY_SALE");
    RevenueResolverCoreMock private core;
    RevenueResolverArtistMock private artist;
    MockGovernedParameterAuthority private authority;
    StreamRevenueResolver private provider;
    StreamSplitFactory private factory;
    bytes32 private profile;
    bytes32 private tokenHash;
    OfficialSafe private account;
    uint256[] private keys;

    function setUp() public {
        authority = new MockGovernedParameterAuthority(true);
        StreamAssetPolicyRegistry policy = new StreamAssetPolicyRegistry(address(authority));
        IStreamGasParameterHost.GasParameterConfig[3] memory configs;
        configs[0] =
            IStreamGasParameterHost.GasParameterConfig("ERC_1271_GAS_LIMIT", 400000, 350000, 2);
        configs[1] =
            IStreamGasParameterHost.GasParameterConfig("ASSET_POLICY_GAS_LIMIT", 30000, 15000, 2);
        configs[2] =
            IStreamGasParameterHost.GasParameterConfig("WALLET_DEPOSIT_GAS_LIMIT", 50000, 25000, 2);
        factory = new StreamSplitFactory(policy, address(authority), configs);
        core = new RevenueResolverCoreMock();
        artist = new RevenueResolverArtistMock(address(core));
        core.selectArtist(address(artist), address(artist).codehash);
        core.setToken(41, 7, false);
        provider = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(authority),
            artist,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200000, 50000, 2
            )
        );
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(address(0x1717), 1000000, keccak256("artist"));
        (profile,) = factory.createProfile(entries, keccak256("scoped primary facts"));
        vm.prank(address(authority));
        tokenHash = provider.setPrimaryProfileAssignment(PRIMARY, 2, 41, profile, bytes32(0));
        keys.push(0x1701);
        keys.push(0x1702);
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 17041);
    }

    function testPrimaryScopeFactsReadExactTokenKeyWithoutArtistRecursion() public {
        artist.setBinding(7, keccak256("binding"), address(account));
        artist.setReadFailure(true);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory actual =
            provider.primaryEconomicsFacts(7, 2, 41);
        require(
            actual.exists && actual.scope == 2 && actual.scopeId == 41 && actual.assignmentType == 1
                && actual.profileId == profile && actual.assignmentHash == tokenHash
                && !actual.frozen,
            "actual per-token key"
        );
        StreamArtistOnboardingTypes.AssignmentFact memory preview =
            provider.previewArtistPrimaryAssignmentForScope(7, 2, 41, profile, bytes32(0), false);
        require(
            preview.resolver == address(provider) && preview.revenueClass == PRIMARY
                && preview.scope == 2 && preview.scopeId == 41
                && preview.assignmentHash == tokenHash,
            "exact real setter result without artist admission recursion"
        );
        require(
            !provider.primaryEconomicsFacts(7, 1, 7).exists,
            "missing collection is not token fallback"
        );
        require(!provider.primaryEconomicsFacts(7, 0, 0).exists, "missing default is explicit");
    }

    function testPrimaryScopeFactsRejectMissingAndForeignMappingThenSameContextSucceeds() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryTokenIdentity.selector, 41, 8
            )
        );
        provider.primaryEconomicsFacts(8, 2, 41);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryTokenIdentity.selector, 42, 7
            )
        );
        provider.primaryEconomicsFacts(7, 2, 42);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidAssignmentScope.selector, uint8(1), 8
            )
        );
        provider.primaryEconomicsFacts(7, 1, 8);
        core.setToken(41, 7, true);
        require(
            provider.primaryEconomicsFacts(7, 2, 41).assignmentHash == tokenHash,
            "burned retained canonical mapping remains valid"
        );
        core.setToken(41, 0, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryTokenIdentity.selector, 41, 7
            )
        );
        provider.primaryEconomicsFacts(7, 2, 41);
        core.setToken(41, 7, false);
        require(
            provider.primaryEconomicsFacts(7, 2, 41).assignmentHash == tokenHash,
            "same actual key succeeds after restoring canonical mapping"
        );
    }

    function testPrimaryScopeClearPreviewUsesZeroAndActualPriorHash() public {
        (StreamArtistOnboardingTypes.AssignmentFact memory clear, bytes32 prior) =
            provider.previewArtistPrimaryClear(7, 2, 41);
        require(
            clear.resolver == address(provider) && clear.revenueClass == PRIMARY && clear.scope == 2
                && clear.scopeId == 41 && clear.assignmentHash == bytes32(0) && prior == tokenHash,
            "zero is cleared key, prior is separate evidence"
        );
        require(
            provider.primaryEconomicsFacts(7, 2, 41).assignmentHash == prior, "preview never clears"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidAssignmentScope.selector, uint8(0), 0
            )
        );
        provider.previewArtistPrimaryClear(7, 0, 0);
        vm.prank(address(authority));
        provider.freezePrimaryAssignment(PRIMARY, 2, 41);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryAssignmentFrozen.selector, PRIMARY, uint8(2), 41
            )
        );
        provider.previewArtistPrimaryClear(7, 2, 41);
    }

    function testPrimaryScopeAllThreeFactsExecuteThroughActualSafe() public {
        bytes[] memory calls = new bytes[](3);
        calls[0] =
            abi.encodeCall(IStreamArtistPrimaryScopeFacts.primaryEconomicsFacts, (7, uint8(2), 41));
        calls[1] = abi.encodeCall(
            IStreamArtistPrimaryScopeFacts.previewArtistPrimaryAssignmentForScope,
            (7, uint8(2), 41, profile, bytes32(0), false)
        );
        calls[2] = abi.encodeCall(
            IStreamArtistPrimaryScopeFacts.previewArtistPrimaryClear, (7, uint8(2), 41)
        );
        for (uint256 i; i < calls.length; ++i) {
            (bool ok, bytes memory before_) = address(provider).staticcall(calls[i]);
            require(ok, "healthy direct canonical read");
            uint256 nonce = account.nonce();
            require(
                executeSafe(account, keys, address(provider), 0, calls[i], 0),
                "actual Safe fact call"
            );
            (bool okAfter, bytes memory after_) = address(provider).staticcall(calls[i]);
            require(
                okAfter && keccak256(before_) == keccak256(after_) && account.nonce() == nonce + 1,
                "unchanged complete provider result after actual Safe execution"
            );
        }
        require(
            provider.supportsInterface(type(IStreamArtistPrimaryScopeFacts).interfaceId),
            "implemented facts interface advertised"
        );
    }
}
