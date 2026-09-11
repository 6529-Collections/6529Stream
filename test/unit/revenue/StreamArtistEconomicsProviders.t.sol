// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/RevenueResolverTestMocks.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";

/// @dev Controlled authority facts only. Actual artist signatures/records are tested by the
///      artist suites and current topology; these cases isolate resolver consumption and order.
contract EconomicsProviderAuthorityBoundary is IStreamArtistAttribution {
    address public immutable core;
    bool public bound;
    bool public unavailable;
    mapping(bytes32 => bool) private _consent;
    mapping(bytes32 => bool) private _freeze;
    mapping(address => bytes32) private _expectedPrior;

    constructor(address core_) {
        core = core_;
    }

    function configure(bool bound_, bool unavailable_) external {
        bound = bound_;
        unavailable = unavailable_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistEconomicsAuthority).interfaceId;
    }

    function acceptedArtist(uint256) external view returns (address) {
        return bound ? address(0xA11CE) : address(0);
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        require(!unavailable, "authority unavailable");
        if (bound) {
            a.artist = address(0xA11CE);
            a.nominationHash = keccak256("binding");
            a.acceptanceHash = keccak256("acceptance");
        }
    }

    function consent(StreamArtistOnboardingTypes.AssignmentFact calldata fact, bytes32 prior)
        external
    {
        _consent[
            keccak256(
                abi.encode(
                    fact.resolver,
                    fact.scopeId,
                    fact.revenueClass,
                    fact.scope,
                    fact.scopeId,
                    fact.assignmentHash
                )
            )
        ] = true;
        _expectedPrior[fact.resolver] = prior;
    }

    function authorizeFreeze(address resolver, uint256 collectionId, bytes32 hash) external {
        _freeze[keccak256(abi.encode(resolver, collectionId, hash))] = true;
    }

    function requireEconomicsConsent(
        uint256 collectionId,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 hash
    ) external view {
        require(!unavailable && bound, "authority unavailable");
        require(
            _consent[keccak256(
                    abi.encode(msg.sender, collectionId, revenueClass, scope, scopeId, hash)
                )],
            "missing exact consent"
        );
        bytes32 current = revenueClass == keccak256("PRIMARY_SALE")
            ? IStreamRevenueResolver(msg.sender)
            .resolvePrimaryAssignment(collectionId, 0, revenueClass)
            .assignmentHash
            : IStreamArtistRoyaltyFacts(msg.sender)
            .currentArtistRoyaltyAssignment(collectionId)
            .assignmentHash;
        require(current == _expectedPrior[msg.sender], "resolver wrote before consent");
    }

    function isRoyaltyFreezeAuthorized(uint256 collectionId, bytes32 hash)
        external
        view
        returns (bool)
    {
        require(!unavailable, "authority unavailable");
        return bound && _freeze[keccak256(abi.encode(msg.sender, collectionId, hash))];
    }
}

contract StreamArtistEconomicsProvidersTest is RevenueV1TestBase {
    bytes32 private constant PRIMARY = keccak256("PRIMARY_SALE");
    RevenueResolverCoreMock private core;
    EconomicsProviderAuthorityBoundary private artists;
    StreamSplitFactory private factory;
    StreamRevenueResolver private primary;
    StreamRoyaltyResolver private royalty;
    bytes32 private first;
    bytes32 private second;

    function setUp() public {
        core = new RevenueResolverCoreMock();
        artists = new EconomicsProviderAuthorityBoundary(address(core));
        core.selectArtist(address(artists), address(artists).codehash);
        factory = new StreamSplitFactory(
            new StreamAssetPolicyRegistry(address(_revenueAuthority())),
            address(_revenueAuthority()),
            _walletGasConfigs()
        );
        primary =
            new StreamRevenueResolver(IStreamCore(address(core)), factory, address(this), artists);
        royalty =
            new StreamRoyaltyResolver(IStreamCore(address(core)), factory, address(this), artists);
        first = _profile(address(0xA11CE));
        second = _profile(address(0xB0B));
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, first, bytes32(0));
        royalty.configureCollectionRoyalty(1, first, 500);
        artists.configure(true, false);
    }

    function testPreviewMatchesExactCommittedHashAndReadsBeforePrimaryWrite() public {
        bytes32 prior = _primaryHash();
        StreamArtistOnboardingTypes.AssignmentFact memory fact =
            primary.previewArtistPrimaryAssignment(1, second, bytes32(0), false);
        require(
            fact.resolver == address(primary) && fact.revenueClass == PRIMARY && fact.scope == 1
                && fact.scopeId == 1,
            "wrong candidate identity"
        );
        require(
            fact.assignmentHash
                == primary.primaryAssignmentHash(
                    PRIMARY, 1, 1, 1, second, bytes32(0), bytes32(0), false
                ),
            "noncanonical preview"
        );
        artists.consent(fact, prior);
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, second, bytes32(0));
        require(
            _primaryHash() == fact.assignmentHash && _primaryHash() != prior,
            "candidate not committed"
        );
    }

    function testPrimaryRequiresExactHashOwnerAndLiveAuthority() public {
        bytes32 prior = _primaryHash();
        StreamArtistOnboardingTypes.AssignmentFact memory wrong =
            primary.previewArtistPrimaryAssignment(1, second, bytes32(0), true);
        artists.consent(wrong, prior);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "missing exact consent"));
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, second, bytes32(0));
        require(_primaryHash() == prior, "failed candidate changed state");
        artists.consent(primary.previewArtistPrimaryAssignment(1, second, bytes32(0), false), prior);
        vm.prank(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner")
        );
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, second, bytes32(0));
        artists.configure(true, true);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "authority unavailable"));
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, second, bytes32(0));
    }

    function testPrimaryFreezeNeedsResultingHashAndCannotBeUndone() public {
        StreamArtistOnboardingTypes.AssignmentFact memory fact =
            primary.previewArtistPrimaryAssignment(1, first, bytes32(0), true);
        artists.consent(fact, _primaryHash());
        require(
            primary.freezePrimaryAssignment(PRIMARY, 1, 1) == fact.assignmentHash,
            "wrong frozen hash"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.PrimaryAssignmentFrozen.selector,
                PRIMARY,
                uint8(1),
                uint256(1)
            )
        );
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, second, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1)
        );
        primary.clearPrimaryAssignment(PRIMARY, 1, 1);
    }

    function testUnsupportedPrimaryCandidateInputsRemainClosed() public {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.InvalidPrimaryPolicyHash.selector)
        );
        primary.previewArtistPrimaryAssignment(1, first, keccak256("loosening"), false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.UnverifiedSplitProfile.selector, bytes32(0)
            )
        );
        primary.previewArtistPrimaryAssignment(1, bytes32(0), bytes32(0), false);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1)
        );
        primary.setPrimaryProfileAssignment(keccak256("OTHER_CLASS"), 1, 1, second, bytes32(0));
    }

    function testRoyaltyPreviewAndPreWriteConsentBindProfileRateAndFrozenBit() public {
        bytes32 prior = _royaltyHash();
        StreamArtistOnboardingTypes.AssignmentFact memory fact =
            royalty.previewArtistRoyaltyAssignment(1, second, 600, false);
        artists.consent(fact, prior);
        royalty.configureCollectionRoyalty(1, second, 600);
        require(_royaltyHash() == fact.assignmentHash, "royalty preview diverged");
        fact = royalty.previewArtistRoyaltyAssignment(1, second, 600, true);
        artists.consent(fact, _royaltyHash());
        royalty.freezeCollectionRoyalty(1);
        require(_royaltyHash() == fact.assignmentHash, "freeze preview diverged");
    }

    function testRoyaltyChangedRateAndGovernedFreezeRequireSeparateConsent() public {
        bytes32 prior = _royaltyHash();
        artists.consent(royalty.previewArtistRoyaltyAssignment(1, second, 600, false), prior);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "missing exact consent"));
        royalty.configureCollectionRoyalty(1, second, 601);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "missing exact consent"));
        royalty.freezeCollectionRoyalty(1);
        require(_royaltyHash() == prior, "rejected royalty changed state");
    }

    function testArtistFreezeIsPermissionlessExactAndPreservesTerms() public {
        bytes32 prior = _royaltyHash();
        IStreamRoyaltyResolver.RoyaltyConfig memory before_ = royalty.collectionRoyalty(1);
        artists.authorizeFreeze(address(royalty), 1, prior);
        vm.prank(address(0xCA11));
        royalty.applyArtistRoyaltyFreeze(1, prior);
        IStreamRoyaltyResolver.RoyaltyConfig memory after_ = royalty.collectionRoyalty(1);
        require(
            after_.frozen && after_.profileId == before_.profileId
                && after_.wallet == before_.wallet && after_.royaltyBps == before_.royaltyBps
                && after_.revision == before_.revision + 1,
            "defensive freeze changed terms"
        );
        require(_royaltyHash() != prior, "frozen bit missing from hash");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoyaltyFreeze.ArtistRoyaltyAssignmentChanged.selector,
                1,
                prior,
                _royaltyHash()
            )
        );
        royalty.applyArtistRoyaltyFreeze(1, prior);
    }

    function testArtistFreezeRejectsMissingStaleAndOtherResolverAuthority() public {
        bytes32 prior = _royaltyHash();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoyaltyFreeze.ArtistRoyaltyFreezeNotAuthorized.selector, 1, prior
            )
        );
        royalty.applyArtistRoyaltyFreeze(1, prior);
        artists.authorizeFreeze(address(primary), 1, prior);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoyaltyFreeze.ArtistRoyaltyFreezeNotAuthorized.selector, 1, prior
            )
        );
        royalty.applyArtistRoyaltyFreeze(1, prior);
        artists.authorizeFreeze(address(royalty), 1, prior);
        artists.consent(royalty.previewArtistRoyaltyAssignment(1, second, 500, false), prior);
        royalty.configureCollectionRoyalty(1, second, 500);
        bytes32 current = _royaltyHash();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoyaltyFreeze.ArtistRoyaltyAssignmentChanged.selector, 1, prior, current
            )
        );
        royalty.applyArtistRoyaltyFreeze(1, prior);
        require(!royalty.collectionRoyalty(1).frozen, "stale authority froze replacement");
    }

    function testRoyaltyPreviewUsesItsOwnFactoryAndRequiresAnExistingProfile() public {
        StreamSplitFactory other = new StreamSplitFactory(
            new StreamAssetPolicyRegistry(address(_revenueAuthority())),
            address(_revenueAuthority()),
            _walletGasConfigs()
        );
        StreamRoyaltyResolver separate =
            new StreamRoyaltyResolver(IStreamCore(address(core)), other, address(this), artists);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoyaltyResolver.InvalidRoyaltySplitProfile.selector, first
            )
        );
        separate.previewArtistRoyaltyAssignment(1, first, 500, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoyaltyResolver.InvalidRoyaltySplitProfile.selector, bytes32(0)
            )
        );
        royalty.previewArtistRoyaltyAssignment(1, bytes32(0), 0, false);
    }

    function testFuzzRoyaltyProspectiveRateUsesExactResult(uint16 rawBps) public {
        uint16 bps = uint16(uint256(rawBps) % 1000 + 1);
        StreamArtistOnboardingTypes.AssignmentFact memory fact =
            royalty.previewArtistRoyaltyAssignment(1, second, bps, false);
        artists.consent(fact, _royaltyHash());
        royalty.configureCollectionRoyalty(1, second, bps);
        require(
            _royaltyHash() == fact.assignmentHash && royalty.collectionRoyalty(1).royaltyBps == bps,
            "rate commitment mismatch"
        );
    }

    function _profile(address account) private returns (bytes32 id) {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(account, 1_000_000, keccak256("ARTIST"));
        (id,) = factory.createProfile(entries, keccak256(abi.encode(account)));
    }

    function _primaryHash() private view returns (bytes32) {
        return primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash;
    }

    function _royaltyHash() private view returns (bytes32) {
        return royalty.currentArtistRoyaltyAssignment(1).assignmentHash;
    }
}
