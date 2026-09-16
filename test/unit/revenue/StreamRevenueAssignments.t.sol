// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../helpers/Assertions.sol";
import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/RevenueResolverTestMocks.sol";

/// @notice Resolver/factory assignment regressions independent of settlement generations.
/// @dev Core identity, artist reads and governance authority use the explicit domain boundaries.
contract StreamRevenueAssignmentsTest is RevenueV1TestBase {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;

    address private constant ARTIST = address(0xA001);
    address private constant PROTOCOL = address(0xB002);
    address private constant ESTATE = address(0xC003);
    bytes32 private constant LABEL_ARTIST = keccak256("artist");
    bytes32 private constant LABEL_PROTOCOL = keccak256("protocol");
    bytes32 private constant LABEL_ESTATE = keccak256("estate");
    bytes32 private constant REVENUE_PRIMARY = keccak256("primary");
    bytes32 private constant PROFILE_METADATA = keccak256("ipfs://primary-split");
    bytes32 private constant TEMPLATE_METADATA = keccak256("ipfs://primary-template");
    bytes32 private constant POLICY_EVIDENCE = bytes32(0);
    bytes32 private constant MISSING_PROFILE = keccak256("missing-profile");

    StreamAssetPolicyRegistry private assetPolicyRegistry;
    StreamSplitFactory private factory;
    StreamRevenueResolver private resolver;

    function setUp() public {
        assetPolicyRegistry = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        factory = new StreamSplitFactory(
            assetPolicyRegistry, address(revenueAuthority), _walletGasConfigs()
        );
        RevenueResolverCoreMock core = new RevenueResolverCoreMock();
        RevenueResolverArtistMock artists = new RevenueResolverArtistMock(address(core));
        core.selectArtist(address(artists), address(artists).codehash);
        core.setToken(9001, 42, false);
        core.setToken(77, 9, false);
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
    }

    function testResolverPrecedenceFreezeAndVerifiedProfileRequirement() public {
        (bytes32 defaultProfile,,) = _createProfile(ARTIST, 1_000_000, LABEL_ARTIST);
        (bytes32 collectionProfile,,) = _createProfile(PROTOCOL, 1_000_000, LABEL_PROTOCOL);
        (bytes32 tokenProfile,,) = _createProfile(ESTATE, 1_000_000, LABEL_ESTATE);

        bytes32 defaultHash = resolver.setPrimaryProfileAssignment(
            REVENUE_PRIMARY, resolver.SCOPE_DEFAULT(), 0, defaultProfile, POLICY_EVIDENCE
        );
        defaultHash.assertEq(
            resolver.primaryAssignmentHash(
                REVENUE_PRIMARY,
                resolver.SCOPE_DEFAULT(),
                0,
                resolver.ASSIGNMENT_TYPE_PROFILE(),
                defaultProfile,
                bytes32(0),
                POLICY_EVIDENCE,
                false
            ),
            "profile assignment hash binds resolver context"
        );
        bytes32 collectionHash = resolver.setPrimaryProfileAssignment(
            REVENUE_PRIMARY, resolver.SCOPE_COLLECTION(), 42, collectionProfile, POLICY_EVIDENCE
        );
        bytes32 tokenHash = resolver.setPrimaryProfileAssignment(
            REVENUE_PRIMARY, resolver.SCOPE_TOKEN(), 9001, tokenProfile, POLICY_EVIDENCE
        );

        IStreamRevenueResolver.ResolvedPrimaryAssignment memory tokenResolved =
            resolver.resolvePrimaryAssignment(42, 9001, REVENUE_PRIMARY);
        tokenResolved.profileId.assertEq(tokenProfile, "token profile wins");
        tokenResolved.assignmentHash.assertEq(tokenHash, "token hash wins");
        uint256(tokenResolved.scope).assertEq(resolver.SCOPE_TOKEN(), "token scope");

        IStreamRevenueResolver.ResolvedPrimaryAssignment memory collectionResolved =
            resolver.resolvePrimaryAssignment(42, 0, REVENUE_PRIMARY);
        collectionResolved.profileId.assertEq(collectionProfile, "collection profile wins");
        collectionResolved.assignmentHash.assertEq(collectionHash, "collection hash wins");
        uint256(collectionResolved.scope).assertEq(resolver.SCOPE_COLLECTION(), "collection scope");

        IStreamRevenueResolver.ResolvedPrimaryAssignment memory defaultResolved =
            resolver.resolvePrimaryAssignment(777, 0, REVENUE_PRIMARY);
        defaultResolved.profileId.assertEq(defaultProfile, "default fallback");
        defaultResolved.assignmentHash.assertEq(defaultHash, "default hash");
        uint256(defaultResolved.scope).assertEq(resolver.SCOPE_DEFAULT(), "default scope");

        IStreamRevenueResolver.ResolvedPrimaryAssignment memory zeroContextResolved =
            resolver.resolvePrimaryAssignment(0, 0, REVENUE_PRIMARY);
        zeroContextResolved.profileId.assertEq(defaultProfile, "zero context uses default");
        uint256(zeroContextResolved.scope).assertEq(resolver.SCOPE_DEFAULT(), "zero context scope");

        bytes32 frozenHash =
            resolver.freezePrimaryAssignment(REVENUE_PRIMARY, resolver.SCOPE_COLLECTION(), 42);
        require(frozenHash != collectionHash, "freeze must change assignment hash");
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory frozenResolved =
            resolver.resolvePrimaryAssignment(42, 0, REVENUE_PRIMARY);
        frozenResolved.frozen.assertTrue("assignment frozen");
        frozenResolved.assignmentHash.assertEq(frozenHash, "frozen hash resolved");

        uint8 collectionScope = resolver.SCOPE_COLLECTION();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryAssignmentFrozen.selector,
                REVENUE_PRIMARY,
                collectionScope,
                42
            )
        );
        resolver.clearPrimaryAssignment(REVENUE_PRIMARY, collectionScope, 42);

        _expectZeroScopeProfileRevert(collectionScope, defaultProfile);

        uint8 tokenScope = resolver.SCOPE_TOKEN();
        _expectZeroScopeProfileRevert(tokenScope, tokenProfile);

        uint8 defaultScope = resolver.SCOPE_DEFAULT();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.UnverifiedSplitProfile.selector, MISSING_PROFILE
            )
        );
        resolver.setPrimaryProfileAssignment(
            REVENUE_PRIMARY, defaultScope, 0, MISSING_PROFILE, POLICY_EVIDENCE
        );
    }

    function testFrozenAssignmentRejectsProfileAndTemplateOverwrite() public {
        (bytes32 profileId,,) = _createProfile(ARTIST, 1_000_000, LABEL_ARTIST);
        bytes32 profileAssignmentHash = resolver.setPrimaryProfileAssignment(
            REVENUE_PRIMARY, resolver.SCOPE_COLLECTION(), 64, profileId, POLICY_EVIDENCE
        );
        bytes32 frozenHash =
            resolver.freezePrimaryAssignment(REVENUE_PRIMARY, resolver.SCOPE_COLLECTION(), 64);
        require(frozenHash != profileAssignmentHash, "frozen hash changed");

        (bytes32 replacementProfile,,) = _createProfile(PROTOCOL, 1_000_000, LABEL_PROTOCOL);
        uint8 collectionScope = resolver.SCOPE_COLLECTION();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryAssignmentFrozen.selector,
                REVENUE_PRIMARY,
                collectionScope,
                64
            )
        );
        resolver.setPrimaryProfileAssignment(
            REVENUE_PRIMARY, collectionScope, 64, replacementProfile, POLICY_EVIDENCE
        );

        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry({
            account: PROTOCOL,
            accountSource: bytes32(0),
            sharePpm: 1_000_000,
            labelId: LABEL_PROTOCOL
        });
        bytes32 templateId = resolver.createPrimaryTemplate(entries, TEMPLATE_METADATA);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryAssignmentFrozen.selector,
                REVENUE_PRIMARY,
                collectionScope,
                64
            )
        );
        resolver.setPrimaryTemplateAssignment(
            REVENUE_PRIMARY, collectionScope, 64, templateId, POLICY_EVIDENCE
        );
    }

    function testClearPrimaryAssignmentFallsThroughAndRejectsMissing() public {
        (bytes32 defaultProfile,,) = _createProfile(ARTIST, 1_000_000, LABEL_ARTIST);
        (bytes32 collectionProfile,,) = _createProfile(PROTOCOL, 1_000_000, LABEL_PROTOCOL);
        (bytes32 tokenProfile,,) = _createProfile(ESTATE, 1_000_000, LABEL_ESTATE);
        resolver.setPrimaryProfileAssignment(
            REVENUE_PRIMARY, resolver.SCOPE_DEFAULT(), 0, defaultProfile, POLICY_EVIDENCE
        );
        bytes32 collectionHash = resolver.setPrimaryProfileAssignment(
            REVENUE_PRIMARY, resolver.SCOPE_COLLECTION(), 42, collectionProfile, POLICY_EVIDENCE
        );
        resolver.setPrimaryProfileAssignment(
            REVENUE_PRIMARY, resolver.SCOPE_TOKEN(), 9001, tokenProfile, POLICY_EVIDENCE
        );

        uint8 tokenScope = resolver.SCOPE_TOKEN();
        resolver.clearPrimaryAssignment(REVENUE_PRIMARY, tokenScope, 9001);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory clearedTokenResolved =
            resolver.resolvePrimaryAssignment(42, 9001, REVENUE_PRIMARY);
        clearedTokenResolved.profileId.assertEq(collectionProfile, "cleared token falls through");
        clearedTokenResolved.assignmentHash
            .assertEq(collectionHash, "cleared token collection hash");
        uint256(clearedTokenResolved.scope)
            .assertEq(resolver.SCOPE_COLLECTION(), "cleared token collection scope");

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryAssignmentMissing.selector,
                REVENUE_PRIMARY,
                tokenScope,
                9001
            )
        );
        resolver.clearPrimaryAssignment(REVENUE_PRIMARY, tokenScope, 9001);
    }

    function testSplitWalletExistsRejectsMissingEmptyAndWrongCode() public {
        factory.splitWalletExists(MISSING_PROFILE).assertFalse("missing profile");

        (bytes32 profileId, address wallet,) = _createProfile(ARTIST, 1_000_000, LABEL_ARTIST);
        vm.etch(wallet, hex"");
        factory.splitWalletExists(profileId).assertFalse("undeployed wallet rejected");

        (bytes32 wrongCodeProfile, address wrongCodeWallet,) =
            _createProfile(PROTOCOL, 1_000_000, LABEL_PROTOCOL);
        vm.etch(wrongCodeWallet, hex"60006000");
        factory.splitWalletExists(wrongCodeProfile).assertFalse("wrong runtime rejected");
    }

    /// @dev The legacy SALE_POSTER materializer remains a public resolver convenience;
    ///      this does not imply that the current paid-mint consumer supports that template.
    function testSalePosterMaterializationAggregatesIsPublicAndRejectsZeroBeforeRegistration()
        public
    {
        address poster = address(0xE005);
        bytes32 source = resolver.ACCOUNT_SOURCE_SALE_POSTER();
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](3);
        entries[0] =
            IStreamRevenueResolver.PrimaryTemplateEntry(address(0), source, 600_000, LABEL_ARTIST);
        entries[1] =
            IStreamRevenueResolver.PrimaryTemplateEntry(poster, bytes32(0), 100_000, LABEL_ARTIST);
        entries[2] = IStreamRevenueResolver.PrimaryTemplateEntry(
            PROTOCOL, bytes32(0), 300_000, LABEL_PROTOCOL
        );
        bytes32 templateId = resolver.createPrimaryTemplate(entries, TEMPLATE_METADATA);
        uint256 profilesBefore = factory.profileCount();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidMaterializedAccount.selector, source
            )
        );
        resolver.materializePrimaryProfile(templateId, address(0));
        factory.profileCount().assertEq(profilesBefore, "zero poster registers nothing");

        vm.prank(address(0xABCD));
        (bytes32 profileId, address wallet,) =
            resolver.materializePrimaryProfile(templateId, poster);
        factory.splitWalletExists(profileId).assertTrue("public verified materialization");
        wallet.assertEq(factory.walletFor(profileId), "canonical wallet");
        factory.profileCount().assertEq(profilesBefore + 1, "one registered profile");
        factory.profileEntryCount(profileId).assertEq(2, "same poster and label aggregate");
        uint256(IStreamSplitWallet(wallet).aggregateSharePpm(poster))
            .assertEq(700_000, "poster share");
        uint256(IStreamSplitWallet(wallet).aggregateSharePpm(PROTOCOL))
            .assertEq(300_000, "protocol share");
        vm.prank(address(0xDCBA));
        (bytes32 repeatedId, address repeatedWallet,) =
            resolver.materializePrimaryProfile(templateId, poster);
        repeatedId.assertEq(profileId, "caller independent profile");
        repeatedWallet.assertEq(wallet, "idempotent wallet");
        factory.profileCount().assertEq(profilesBefore + 1, "retry registers nothing");

        (bytes32 otherId, address otherWallet,) =
            resolver.materializePrimaryProfile(templateId, address(0xE099));
        require(
            otherId != profileId && otherWallet != wallet, "different poster has different rights"
        );
        factory.profileEntryCount(otherId).assertEq(3, "different poster keeps static recipient");
    }

    function _expectZeroScopeProfileRevert(uint8 scope, bytes32 profileId) private {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.InvalidAssignmentScope.selector, scope, 0)
        );
        resolver.setPrimaryProfileAssignment(REVENUE_PRIMARY, scope, 0, profileId, POLICY_EVIDENCE);
    }

    function _createProfile(address account, uint32 sharePpm, bytes32 labelId)
        private
        returns (bytes32 profileId, address wallet, bytes32 entriesHash)
    {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(account, sharePpm, labelId);
        entriesHash = keccak256(abi.encode(entries));
        (profileId, wallet) = factory.createProfile(entries, PROFILE_METADATA);
        factory.splitWalletExists(profileId).assertTrue("verified split wallet");
    }
}
