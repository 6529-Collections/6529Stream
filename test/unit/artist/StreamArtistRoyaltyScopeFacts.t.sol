// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../helpers/RevenueResolverTestMocks.sol";
import "../../helpers/GovernedParameterTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";

interface RoyaltyScopeVm {
    function prank(address) external;
    function expectRevert(bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

/// @dev Real resolver/factory/wallet and owner Safe, with explicit unbound artist/Core boundary.
///      This tests owner CALL mechanics, not canonical Executor staging or artist consent.
contract StreamArtistRoyaltyScopeFactsTest is OfficialSafeFixture {
    RoyaltyScopeVm private constant vm =
        RoyaltyScopeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RevenueResolverCoreMock private core;
    RevenueResolverArtistMock private artist;
    StreamRoyaltyResolver private provider;
    StreamSplitFactory private factory;
    OfficialSafe private account;
    uint256[] private keys;
    bytes32 private profile;

    function setUp() public {
        keys.push(0x1801);
        keys.push(0x1802);
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 18041);
        MockGovernedParameterAuthority authority = new MockGovernedParameterAuthority(true);
        IStreamGasParameterHost.GasParameterConfig[3] memory configs;
        configs[0] =
            IStreamGasParameterHost.GasParameterConfig("ERC_1271_GAS_LIMIT", 400000, 350000, 2);
        configs[1] =
            IStreamGasParameterHost.GasParameterConfig("ASSET_POLICY_GAS_LIMIT", 30000, 15000, 2);
        configs[2] =
            IStreamGasParameterHost.GasParameterConfig("WALLET_DEPOSIT_GAS_LIMIT", 50000, 25000, 2);
        factory = new StreamSplitFactory(
            new StreamAssetPolicyRegistry(address(authority)), address(authority), configs
        );
        core = new RevenueResolverCoreMock();
        artist = new RevenueResolverArtistMock(address(core));
        core.selectArtist(address(artist), address(artist).codehash);
        core.setToken(41, 7, false);
        provider = new StreamRoyaltyResolver(
            IStreamCore(address(core)), factory, address(account), artist
        );
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(address(account), 1000000, keccak256("artist"));
        (profile,) = factory.createProfile(entries, keccak256("royalty scope facts"));
        this.executeOwner(abi.encodeCall(provider.configureDefaultRoyalty, (profile, uint16(100))));
        this.executeOwner(
            abi.encodeCall(provider.configureCollectionRoyalty, (uint256(7), profile, uint16(200)))
        );
    }

    function executeOwner(bytes calldata data) external {
        require(executeSafe(account, keys, address(provider), 0, data, 0), "actual owner Safe CALL");
    }

    function _read(bytes memory data, bytes memory expected) private {
        (bool ok, bytes memory before_) = address(provider).staticcall(data);
        require(ok && keccak256(before_) == keccak256(expected), "exact static result");
        uint256 nonce = account.nonce();
        this.executeOwner(data);
        (ok, before_) = address(provider).staticcall(data);
        require(
            ok && keccak256(before_) == keccak256(expected) && account.nonce() == nonce + 1,
            "actual Safe read preserves all returndata"
        );
    }

    function testRoyaltyScopeEveryNewSelectorThroughActualSafe() public {
        StreamArtistOnboardingTypes.AssignmentFact memory preview =
            provider.previewArtistRoyaltyAssignmentForScope(7, 2, 41, profile, 350, false);
        _read(
            abi.encodeCall(
                provider.previewArtistRoyaltyAssignmentForScope,
                (uint256(7), uint8(2), uint256(41), profile, uint16(350), false)
            ),
            abi.encode(preview)
        );
        this.executeOwner(
            abi.encodeCall(provider.configureTokenRoyalty, (uint256(41), profile, uint16(350)))
        );
        (
            StreamArtistOnboardingTypes.AssignmentFact memory fact,
            IStreamRoyaltyResolver.RoyaltyConfig memory config
        ) = provider.royaltyEconomicsFacts(7, 2, 41);
        require(
            fact.assignmentHash == preview.assignmentHash && config.configured,
            "actual governed token key"
        );
        _read(
            abi.encodeCall(provider.royaltyEconomicsFacts, (uint256(7), uint8(2), uint256(41))),
            abi.encode(fact, config)
        );
        _read(abi.encodeCall(provider.tokenRoyalty, (uint256(41))), abi.encode(config));
        bytes32 policy;
        (fact, config, policy) = provider.resolveRoyaltyAssignment(7, 41);
        _read(
            abi.encodeCall(provider.resolveRoyaltyAssignment, (uint256(7), uint256(41))),
            abi.encode(fact, config, policy)
        );
        (StreamArtistOnboardingTypes.AssignmentFact memory clear, bytes32 previous) =
            provider.previewArtistRoyaltyClear(7, 2, 41);
        _read(
            abi.encodeCall(provider.previewArtistRoyaltyClear, (uint256(7), uint8(2), uint256(41))),
            abi.encode(clear, previous)
        );
        require(
            clear.assignmentHash == 0 && previous == fact.assignmentHash,
            "clear result and prior key"
        );
        this.executeOwner(abi.encodeCall(provider.clearTokenRoyalty, (uint256(41))));
        this.executeOwner(abi.encodeCall(provider.clearCollectionRoyalty, (uint256(7))));
        (fact, config,) = provider.resolveRoyaltyAssignment(7, 41);
        require(fact.scope == 0 && config.royaltyBps == 100, "both clears expose actual default");
        this.executeOwner(abi.encodeCall(provider.freezeTokenRoyalty, (uint256(41))));
        config = provider.tokenRoyalty(41);
        require(
            config.frozen && config.configured && config.royaltyBps == 100,
            "freeze materializes actual default into token key"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeOwner(abi.encodeCall(provider.clearTokenRoyalty, (uint256(41))));
    }

    function testRoyaltyStorageOnlyDisclosureSurvivesAllDependencyFailures() public {
        this.executeOwner(
            abi.encodeCall(provider.configureTokenRoyalty, (uint256(41), profile, uint16(350)))
        );
        address wallet = factory.walletFor(profile);
        vm.mockCallRevert(address(core), bytes(""), bytes("core unavailable"));
        vm.mockCallRevert(address(artist), bytes(""), bytes("artist unavailable"));
        vm.mockCallRevert(address(factory), bytes(""), bytes("factory unavailable"));
        (address receiver, uint16 bps) =
            provider.royaltyReceiverAndBps{ gas: 20000 }(address(core), 41, 10000, 7, true);
        require(receiver == wallet && bps == 350, "token disclosure makes no dependency call");
        (receiver, bps) =
            provider.royaltyReceiverAndBps{ gas: 20000 }(address(core), 42, 10000, 7, true);
        require(receiver == wallet && bps == 200, "collection disclosure makes no dependency call");
        (receiver, bps) =
            provider.royaltyReceiverAndBps{ gas: 20000 }(address(core), 41, 10000, 7, false);
        require(
            receiver == wallet && bps == 100, "unmapped Core input never selects token override"
        );
        (receiver, bps) =
            provider.royaltyReceiverAndBps{ gas: 20000 }(address(0xBAD), 41, 10000, 7, true);
        require(receiver == address(0) && bps == 0, "foreign Core remains soft zero");
        vm.clearMockedCalls();
        this.executeOwner(
            abi.encodeCall(provider.configureTokenRoyalty, (uint256(41), bytes32(0), uint16(0)))
        );
        (receiver, bps) = provider.royaltyReceiverAndBps(address(core), 41, 10000, 7, true);
        require(
            receiver == address(0) && bps == 0, "disabled token suppresses inherited positive rate"
        );
    }

    function testRoyaltyClearKeepsRevisionSequenceAndDistinctInheritedHash() public {
        this.executeOwner(
            abi.encodeCall(provider.configureTokenRoyalty, (uint256(41), profile, uint16(350)))
        );
        IStreamRoyaltyResolver.RoyaltyConfig memory before_ = provider.tokenRoyalty(41);
        (StreamArtistOnboardingTypes.AssignmentFact memory clear, bytes32 previousHash) =
            provider.previewArtistRoyaltyClear(7, 2, 41);
        (StreamArtistOnboardingTypes.AssignmentFact memory prior,) =
            provider.royaltyEconomicsFacts(7, 2, 41);
        require(
            before_.revision == 1 && previousHash == prior.assignmentHash
                && clear.assignmentHash == 0,
            "first key and exact clear preview"
        );
        this.executeOwner(abi.encodeCall(provider.clearTokenRoyalty, (uint256(41))));
        (
            StreamArtistOnboardingTypes.AssignmentFact memory empty,
            IStreamRoyaltyResolver.RoyaltyConfig memory cleared
        ) = provider.royaltyEconomicsFacts(7, 2, 41);
        require(
            empty.assignmentHash == 0 && !cleared.configured && cleared.profileId == 0
                && cleared.wallet == address(0) && cleared.royaltyBps == 0 && !cleared.frozen
                && cleared.revision == 2,
            "semantic absence retains incremented counter"
        );
        (
            StreamArtistOnboardingTypes.AssignmentFact memory inherited,
            IStreamRoyaltyResolver.RoyaltyConfig memory ancestor,
            bytes32 policy
        ) = provider.resolveRoyaltyAssignment(7, 41);
        require(
            inherited.scope == 1 && inherited.assignmentHash != 0 && ancestor.royaltyBps == 200
                && policy != 0,
            "clear counter does not alter ancestor fallback"
        );
        this.executeOwner(
            abi.encodeCall(provider.configureTokenRoyalty, (uint256(41), profile, uint16(350)))
        );
        (prior, before_) = provider.royaltyEconomicsFacts(7, 2, 41);
        require(
            before_.revision == 3 && prior.assignmentHash == previousHash,
            "reconfigure advances revision while exact economics hash can recur"
        );
    }

    function testRoyaltyFactsRetainedBurnedMappingAndExactInvalidControl() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTokenRoyaltyResolver.InvalidRoyaltyToken.selector, uint256(41)
            )
        );
        provider.royaltyEconomicsFacts(8, 2, 41);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTokenRoyaltyResolver.InvalidRoyaltyToken.selector, uint256(999)
            )
        );
        provider.royaltyEconomicsFacts(7, 2, 999);
        core.setToken(41, 7, true);
        this.executeOwner(
            abi.encodeCall(provider.configureTokenRoyalty, (uint256(41), profile, uint16(450)))
        );
        (
            StreamArtistOnboardingTypes.AssignmentFact memory fact,
            IStreamRoyaltyResolver.RoyaltyConfig memory config,
        ) = provider.resolveRoyaltyAssignment(7, 41);
        require(
            fact.scope == 2 && config.royaltyBps == 450,
            "retained burned mapping remains assignment identity"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamTokenRoyaltyResolver.InvalidRoyaltyScope.selector, uint8(0), uint256(1)
            )
        );
        provider.royaltyEconomicsFacts(7, 0, 1);
        (fact, config) = provider.royaltyEconomicsFacts(7, 2, 41);
        _read(
            abi.encodeCall(provider.royaltyEconomicsFacts, (uint256(7), uint8(2), uint256(41))),
            abi.encode(fact, config)
        );
        uint256 nonce = account.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeOwner(
            abi.encodeCall(provider.configureTokenRoyalty, (uint256(999), profile, uint16(450)))
        );
        require(account.nonce() == nonce, "invalid mapping reverts actual Safe envelope");
        this.executeOwner(
            abi.encodeCall(provider.configureTokenRoyalty, (uint256(41), profile, uint16(451)))
        );
    }
}
