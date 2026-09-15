// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import "../../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../helpers/RevenueV1TestBase.sol";

/// @dev Only Core/artist boundaries are doubles. These tests do not prove a current-Core mint.
contract ArtistProviderCoreBoundary {
    bool public frozen;
    address public artistTarget;
    bytes32 public artistHash;

    function setArtist(address target, bytes32 codeHash) external {
        artistTarget = target;
        artistHash = codeHash;
    }

    function getSatellitePointer(bytes32)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        return (
            artistTarget,
            artistHash,
            false,
            bytes32(0),
            bytes4(0),
            address(0),
            0,
            bytes32(0),
            bytes32(0),
            0
        );
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1 || id == 2;
    }

    function collectionFreezeStatus(uint256) external view returns (bool) {
        return frozen;
    }

    function setFrozen(bool value) external {
        frozen = value;
    }
}

contract ArtistProviderRatificationBoundary is
    IStreamArtistAttribution,
    IStreamArtistContentRatification
{
    address public immutable core;
    bool public ratified;
    bool public unavailable;
    bool public bound;

    function setBound(bool value) external {
        bound = value;
    }

    constructor(address core_) {
        core = core_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId || id == 0x01ffc9a7;
    }

    function acceptedArtist(uint256) external pure returns (address) {
        return address(0xA11CE);
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        a.artist = address(0xA11CE);
        if (bound) a.nominationHash = keccak256("binding");
    }

    function firstReleaseRatification(uint256) external view returns (bool, bytes32, bytes32) {
        require(!unavailable, "unavailable artist");
        return (ratified, bytes32(uint256(1)), bytes32(uint256(2)));
    }

    function configure(bool value, bool failed) external {
        ratified = value;
        unavailable = failed;
    }
}

contract StreamArtistLiveProvidersTest is RevenueV1TestBase {
    ArtistProviderCoreBoundary private core;
    ArtistProviderRatificationBoundary private artist;
    StreamMetadataRouter private metadata;
    StreamRoyaltyResolver private royalty;
    StreamSplitFactory private factory;
    bytes32 private profile;

    function setUp() public {
        core = new ArtistProviderCoreBoundary();
        artist = new ArtistProviderRatificationBoundary(address(core));
        core.setArtist(address(artist), address(artist).codehash);
        metadata = new StreamMetadataRouter(
            address(core),
            address(this),
            keccak256("deployment"),
            "ipfs://manifest",
            keccak256("manifest"),
            artist
        );
        factory = new StreamSplitFactory(
            new StreamAssetPolicyRegistry(address(_revenueAuthority())),
            address(_revenueAuthority()),
            _walletGasConfigs()
        );
        royalty =
            new StreamRoyaltyResolver(IStreamCore(address(core)), factory, address(this), artist);
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(address(0xA11CE), 1_000_000, keccak256("ARTIST"));
        (profile,) = factory.createProfile(entries, keccak256("profile document"));
    }

    function testRealMetadataContentHashMatchesExplicitProfileAndSeparatesDescription() public {
        _configureContent(1);
        (address host, bytes32 state) = metadata.currentArtistContentState(1);
        bytes32 context = keccak256(
            abi.encode(
                block.chainid,
                address(core),
                uint256(1),
                address(metadata),
                address(metadata).codehash,
                address(StreamMetadataRenderer),
                address(StreamMetadataRenderer).codehash
            )
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_ONCHAIN_CONTENT_V1"),
                context,
                keccak256(bytes("ipfs://image")),
                keccak256(bytes("ipfs://animation/")),
                keccak256(bytes("document.body.textContent=tokenHash;"))
            )
        );
        require(host == address(metadata) && state == expected, "content commitment");
        artist.configure(true, false);
        metadata.setCollectionMetadata(
            1, "Corrected title", "Corrected description", "ipfs://image", "ipfs://animation/"
        );
        (, bytes32 afterDescription) = metadata.currentArtistContentState(1);
        require(afterDescription == state, "description changes artwork commitment");
    }

    function testRoyaltyCanDeployBeforeGenesisButCannotConfigureBeforeArtistSelection() public {
        core.setArtist(address(0), bytes32(0));
        StreamRoyaltyResolver pending =
            new StreamRoyaltyResolver(IStreamCore(address(core)), factory, address(this), artist);
        require(pending.artistRegistryCodeHash() == address(artist).codehash, "constructor pin");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRoyaltyResolver.InvalidArtistRegistryBinding.selector, address(0)
            )
        );
        pending.configureCollectionRoyalty(1, profile, 500);
        core.setArtist(address(artist), address(artist).codehash);
        pending.configureCollectionRoyalty(1, profile, 500);
        require(pending.collectionRoyalty(1).royaltyBps == 500, "selected artist rejected");
    }

    function testRoyaltyConstructorRejectsWrongCoreArtistAndChangedRuntime() public {
        ArtistProviderRatificationBoundary wrong =
            new ArtistProviderRatificationBoundary(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRoyaltyResolver.InvalidArtistRegistryBinding.selector, address(wrong)
            )
        );
        new StreamRoyaltyResolver(IStreamCore(address(core)), factory, address(this), wrong);
        vm.etch(address(artist), hex"60006000f3");
        core.setArtist(address(artist), address(artist).codehash);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRoyaltyResolver.InvalidArtistRegistryBinding.selector, address(artist)
            )
        );
        royalty.currentArtistRoyaltyAssignment(1);
    }

    function testUnconfiguredOrOffchainOnlyContentCannotSatisfyOnchainRatification() public {
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.UnconfiguredOnchainContent.selector, 1)
        );
        metadata.currentArtistContentState(1);
        metadata.setCollectionMetadata(
            1, "Title", "Description", "ipfs://image", "ipfs://animation/"
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.UnconfiguredOnchainContent.selector, 1)
        );
        metadata.currentArtistContentState(1);
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRouter.InvalidCollection.selector, 3));
        metadata.currentArtistContentState(3);
    }

    function testRatificationStopsEveryChangedContentSurfaceAndCannotBeClearedByEmptyScript()
        public
    {
        _configureContent(1);
        (, bytes32 beforeState) = metadata.currentArtistContentState(1);
        artist.configure(true, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, 1
            )
        );
        metadata.setCollectionScript(1, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, 1
            )
        );
        metadata.setCollectionScript(1, "alert(1)");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, 1
            )
        );
        metadata.setCollectionMetadata(
            1, "Title", "Description", "ipfs://changed", "ipfs://animation/"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, 1
            )
        );
        metadata.setCollectionMetadata(1, "Title", "Description", "ipfs://image", "ipfs://changed/");
        (, bytes32 afterState) = metadata.currentArtistContentState(1);
        require(beforeState == afterState, "failed mutation altered content");
    }

    function testAuthorityFailureFreezeAndUnavailableArtistCannotPermitContentChanges() public {
        _configureContent(1);
        vm.prank(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.Unauthorized.selector, address(0xBAD))
        );
        metadata.setCollectionScript(1, "alert(1)");
        artist.configure(false, true);
        vm.expectRevert(bytes("unavailable artist"));
        metadata.setCollectionScript(1, "alert(1)");
        core.setFrozen(true);
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRouter.CollectionFrozen.selector, 1));
        metadata.setCollectionMetadata(
            1, "Title", "Description", "ipfs://image", "ipfs://animation/"
        );
    }

    function testContextAndPreRatificationMutationsChangeContentHash() public {
        _configureContent(1);
        _configureContent(2);
        (, bytes32 first) = metadata.currentArtistContentState(1);
        (, bytes32 second) = metadata.currentArtistContentState(2);
        require(first != second, "collection replay");
        metadata.setCollectionScript(1, "document.body.textContent=tokenId;");
        (, bytes32 changed) = metadata.currentArtistContentState(1);
        require(first != changed, "script not committed");
        vm.chainId(block.chainid + 1);
        (, bytes32 otherChain) = metadata.currentArtistContentState(1);
        require(changed != otherChain, "chain replay");
    }

    function testRealRoyaltyPerKeyHashMatchesCanonicalRSRPreimage() public {
        royalty.configureCollectionRoyalty(1, profile, 690);
        StreamArtistOnboardingTypes.AssignmentFact memory fact =
            royalty.currentArtistRoyaltyAssignment(1);
        require(
            fact.resolver == address(royalty) && fact.revenueClass == keccak256("ROYALTY_ERC2981")
                && fact.scope == 1 && fact.scopeId == 1,
            "wrong assignment identity"
        );
        require(
            fact.assignmentHash == _expectedRoyalty(1, 1, profile, 690, false),
            "RSR preimage mismatch"
        );
    }

    function testRoyaltyMissingDefaultExplicitZeroFreezeAndBpsOnlyChanges() public {
        require(
            royalty.currentArtistRoyaltyAssignment(1).assignmentHash == bytes32(0),
            "fabricated assignment"
        );
        royalty.configureDefaultRoyalty(profile, 500);
        StreamArtistOnboardingTypes.AssignmentFact memory inherited =
            royalty.currentArtistRoyaltyAssignment(1);
        require(
            inherited.scope == 0 && inherited.scopeId == 0
                && inherited.assignmentHash == _expectedRoyalty(0, 0, profile, 500, false),
            "default context"
        );
        royalty.configureCollectionRoyalty(1, profile, 500);
        bytes32 beforeBps = royalty.currentArtistRoyaltyAssignment(1).assignmentHash;
        royalty.configureCollectionRoyalty(1, profile, 501);
        require(
            beforeBps != royalty.currentArtistRoyaltyAssignment(1).assignmentHash, "bps-only drift"
        );
        royalty.configureCollectionRoyalty(1, bytes32(0), 0);
        require(
            royalty.currentArtistRoyaltyAssignment(1).assignmentHash
                == _expectedRoyalty(1, 1, bytes32(0), 0, false),
            "explicit zero"
        );
        royalty.freezeCollectionRoyalty(1);
        require(
            royalty.currentArtistRoyaltyAssignment(1).assignmentHash
                == _expectedRoyalty(1, 1, bytes32(0), 0, true),
            "freeze omitted"
        );
    }

    function testFuzzRoyaltyRateCommitment(uint16 rawBps) public {
        uint16 bps = uint16(uint256(rawBps) % 1000 + 1);
        royalty.configureCollectionRoyalty(1, profile, bps);
        require(
            royalty.currentArtistRoyaltyAssignment(1).assignmentHash
                == _expectedRoyalty(1, 1, profile, bps, false),
            "rate commitment"
        );
    }

    function testChangedArtistPointerCannotBypassMetadataOrRoyaltyClosures() public {
        _configureContent(1);
        royalty.configureCollectionRoyalty(1, profile, 500);
        ArtistProviderRatificationBoundary replacement =
            new ArtistProviderRatificationBoundary(address(core));
        core.setArtist(address(replacement), address(replacement).codehash);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistRegistryBindingChanged.selector, address(replacement)
            )
        );
        metadata.currentArtistContentState(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistRegistryBindingChanged.selector, address(replacement)
            )
        );
        metadata.setCollectionScript(1, "alert(1)");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRoyaltyResolver.InvalidArtistRegistryBinding.selector, address(replacement)
            )
        );
        royalty.configureCollectionRoyalty(1, profile, 501);
        core.setArtist(address(0), bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRoyaltyResolver.InvalidArtistRegistryBinding.selector, address(0)
            )
        );
        royalty.configureCollectionRoyalty(1, profile, 501);
        core.setArtist(address(artist), bytes32(uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistRegistryBindingChanged.selector, address(artist)
            )
        );
        metadata.currentArtistContentState(1);
    }

    function testBoundArtistRoyaltyChangesAndGovernedFreezeRequireEconomicsConsent() public {
        royalty.configureCollectionRoyalty(1, profile, 500);
        artist.setBound(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRoyaltyResolver.ArtistEconomicsAuthorizationRequired.selector, 1
            )
        );
        royalty.configureCollectionRoyalty(1, profile, 501);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRoyaltyResolver.ArtistEconomicsAuthorizationRequired.selector, 1
            )
        );
        royalty.configureCollectionRoyalty(1, bytes32(0), 0);
        require(royalty.collectionRoyalty(1).royaltyBps == 500, "bound terms changed");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRoyaltyResolver.ArtistEconomicsAuthorizationRequired.selector, 1
            )
        );
        royalty.freezeCollectionRoyalty(1);
        require(!royalty.collectionRoyalty(1).frozen, "governed freeze lacked consent");
    }

    function _configureContent(uint256 id) private {
        metadata.setCollectionMetadata(
            id, "Title", "Description", "ipfs://image", "ipfs://animation/"
        );
        metadata.setCollectionScript(id, "document.body.textContent=tokenHash;");
    }

    function _expectedRoyalty(uint8 scope, uint256 id, bytes32 profileId, uint16 bps, bool frozen)
        private
        view
        returns (bytes32)
    {
        bytes32 resolverContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1"),
                address(royalty),
                address(factory),
                address(factory.assetPolicyRegistry()),
                factory.splitWalletRuntimeCodeHash()
            )
        );
        bytes32 scopeContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1"),
                keccak256("ROYALTY_ERC2981"),
                scope,
                id,
                uint8(1)
            )
        );
        bytes32 profileContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1"),
                profileId == bytes32(0) ? address(0) : factory.walletFor(profileId),
                profileId == bytes32(0) ? bytes32(0) : factory.profileEntriesHash(profileId),
                profileId == bytes32(0) ? bytes32(0) : factory.profileMetadataURIHash(profileId)
            )
        );
        bytes32 pointerContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROYALTY_ASSIGNMENT_POINTER_CONTEXT_V1"),
                profileId,
                profileContext,
                bps
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_V1"),
                block.chainid,
                resolverContext,
                scopeContext,
                pointerContext,
                bytes32(0),
                frozen
            )
        );
    }
}
