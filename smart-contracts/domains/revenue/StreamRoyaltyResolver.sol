// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyPreview.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../../interfaces/stream/revenue/IStreamRoyaltyFreeze.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../vendor/openzeppelin/Ownable.sol";

/// @notice Governance-owned live collection royalties with exact, permanent collection freezes.
/// @dev Default/collection terms are independent of primary-sale profiles. This resolver does
///      not implement token overrides or mint-time snapshots. ERC-2981 discloses royalties;
///      it does not restrict transfers or require a marketplace to pay them.
contract StreamRoyaltyResolver is
    IStreamRoyaltyResolver,
    IStreamArtistRoyaltyFacts,
    IStreamArtistRoyaltyPreview,
    IStreamRoyaltyFreeze,
    ERC165,
    Ownable
{
    uint16 public constant MAX_ROYALTY_BPS = 1_000;
    IStreamCore public immutable boundCore;
    IStreamSplitFactory public immutable splitFactory;
    IStreamArtistAttribution public immutable artistRegistry;
    bytes32 public immutable artistRegistryCodeHash;

    RoyaltyConfig private _defaultRoyalty;
    mapping(uint256 => RoyaltyConfig) private _collectionRoyalties;
    error ArtistEconomicsAuthorizationRequired(uint256 collectionId);
    error InvalidArtistRegistryBinding(address selected);

    /// @dev Pin the deployed facade before committed genesis installs the Core pointer.
    ///      Runtime admission still requires Core to select this exact deployed identity.
    constructor(
        IStreamCore core_,
        IStreamSplitFactory splitFactory_,
        address governanceExecutor_,
        IStreamArtistAttribution artistRegistry_
    ) {
        if (
            address(core_).code.length == 0 || address(splitFactory_).code.length == 0
                || governanceExecutor_.code.length == 0
        ) revert InvalidRoyaltyConfiguration();
        boundCore = core_;
        splitFactory = splitFactory_;
        address artist = address(artistRegistry_);
        if (
            artist.code.length == 0 || artistRegistry_.core() != address(core_)
                || !IERC165(artist).supportsInterface(type(IStreamArtistAttribution).interfaceId)
                || IERC165(artist).supportsInterface(0xffffffff)
        ) {
            revert InvalidArtistRegistryBinding(artist);
        }
        artistRegistry = artistRegistry_;
        artistRegistryCodeHash = artist.codehash;
        _transferOwnership(governanceExecutor_);
    }

    function supportsInterface(bytes4 id) public view override(ERC165, IERC165) returns (bool) {
        return id == type(IStreamRoyaltyResolver).interfaceId
            || id == type(IStreamArtistRoyaltyFacts).interfaceId
            || id == type(IStreamArtistRoyaltyPreview).interfaceId
            || id == type(IStreamRoyaltyFreeze).interfaceId || super.supportsInterface(id);
    }

    /// @inheritdoc IStreamArtistRoyaltyPreview
    function previewArtistRoyaltyAssignment(
        uint256 collectionId,
        bytes32 profileHash,
        uint16 royaltyBps,
        bool frozen
    ) external view override returns (StreamArtistOnboardingTypes.AssignmentFact memory fact) {
        _requireCollection(collectionId);
        _requireSelectedArtistRegistry();
        // Zero-profile disablement is not part of the current prospective artist profile.
        if (profileHash == bytes32(0)) revert InvalidRoyaltySplitProfile(profileHash);
        RoyaltyConfig memory candidate = _candidate(profileHash, royaltyBps);
        candidate.frozen = frozen;
        fact = StreamArtistOnboardingTypes.AssignmentFact(
            address(this),
            keccak256("ROYALTY_ERC2981"),
            1,
            collectionId,
            _assignmentHash(candidate, 1, collectionId)
        );
    }

    /// @notice Live per-key RSR commitment, including bps, for artist economics consent.
    /// @dev Initial artist onboarding requires an explicitly configured collection profile.
    ///      Missing assignments return a zero hash; explicit disabled royalties are committed.
    function currentArtistRoyaltyAssignment(uint256 collectionId)
        external
        view
        override
        returns (StreamArtistOnboardingTypes.AssignmentFact memory fact)
    {
        _requireCollection(collectionId);
        _requireSelectedArtistRegistry();
        RoyaltyConfig storage item = _collectionRoyalties[collectionId];
        bool collectionConfigured = item.configured;
        uint8 scope = collectionConfigured ? 1 : 0;
        uint256 scopeId = collectionConfigured ? collectionId : 0;
        fact = StreamArtistOnboardingTypes.AssignmentFact(
            address(this), keccak256("ROYALTY_ERC2981"), scope, scopeId, bytes32(0)
        );
        if (collectionConfigured) {
            fact.assignmentHash = _assignmentHash(item, scope, scopeId);
        } else if (_defaultRoyalty.configured) {
            fact.assignmentHash = _assignmentHash(_defaultRoyalty, scope, scopeId);
        }
    }

    function _assignmentHash(RoyaltyConfig memory item, uint8 scope, uint256 scopeId)
        private
        view
        returns (bytes32)
    {
        bytes32 resolverContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1"),
                address(this),
                address(splitFactory),
                address(splitFactory.assetPolicyRegistry()),
                splitFactory.splitWalletRuntimeCodeHash()
            )
        );
        bytes32 scopeContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1"),
                keccak256("ROYALTY_ERC2981"),
                scope,
                scopeId,
                uint8(1)
            )
        );
        bytes32 entriesHash = item.profileId == bytes32(0)
            ? bytes32(0)
            : splitFactory.profileEntriesHash(item.profileId);
        bytes32 metadataHash = item.profileId == bytes32(0)
            ? bytes32(0)
            : splitFactory.profileMetadataURIHash(item.profileId);
        // PROFILE type always has a profile context, including an explicitly disabled zero profile.
        bytes32 profileContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1"),
                item.wallet,
                entriesHash,
                metadataHash
            )
        );
        bytes32 pointerContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROYALTY_ASSIGNMENT_POINTER_CONTEXT_V1"),
                item.profileId,
                profileContext,
                item.royaltyBps
            )
        );
        // This resolver advertises no loosening: the canonical assignment-policy input is zero.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_V1"),
                block.chainid,
                resolverContext,
                scopeContext,
                pointerContext,
                bytes32(0),
                item.frozen
            )
        );
    }

    function royaltyReceiverAndBps(
        address core_,
        uint256,
        uint256,
        uint256 mappedCollectionId,
        bool hasMappedCollection
    ) external view override returns (address receiver, uint16 royaltyBps) {
        if (core_ != address(boundCore)) return (address(0), 0);
        if (hasMappedCollection) {
            RoyaltyConfig storage collection = _collectionRoyalties[mappedCollectionId];
            if (collection.configured) return (collection.wallet, collection.royaltyBps);
        }
        return (_defaultRoyalty.wallet, _defaultRoyalty.royaltyBps);
    }

    /// @notice Profile zero and bps zero explicitly disable royalties for the scope.
    function configureDefaultRoyalty(bytes32 profileId, uint16 royaltyBps)
        external
        override
        onlyOwner
    {
        _configure(_defaultRoyalty, 0, profileId, royaltyBps);
    }

    function configureCollectionRoyalty(uint256 collectionId, bytes32 profileId, uint16 royaltyBps)
        external
        override
        onlyOwner
    {
        _requireCollection(collectionId);
        _requireSelectedArtistRegistry();
        RoyaltyConfig memory candidate = _candidate(profileId, royaltyBps);
        _requireArtistEconomics(collectionId, candidate);
        _configure(_collectionRoyalties[collectionId], collectionId, profileId, royaltyBps);
    }

    function _requireArtistEconomics(uint256 collectionId, RoyaltyConfig memory candidate)
        private
        view
    {
        if (artistRegistry.attribution(collectionId).nominationHash != bytes32(0)) {
            if (
                candidate.profileId == bytes32(0)
                    || !IERC165(address(artistRegistry))
                        .supportsInterface(type(IStreamArtistEconomicsAuthority).interfaceId)
            ) {
                revert ArtistEconomicsAuthorizationRequired(collectionId);
            }
            IStreamArtistEconomicsAuthority(address(artistRegistry))
                .requireEconomicsConsent(
                    collectionId,
                    keccak256("ROYALTY_ERC2981"),
                    1,
                    collectionId,
                    _assignmentHash(candidate, 1, collectionId)
                );
        }
    }

    function _requireSelectedArtistRegistry() private view {
        (address selected, bytes32 codeHash,,,,,,,,) = IStreamCorePointers(address(boundCore))
            .getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (
            selected != address(artistRegistry) || selected.code.length == 0
                || codeHash != artistRegistryCodeHash || selected.codehash != artistRegistryCodeHash
        ) {
            revert InvalidArtistRegistryBinding(selected);
        }
    }

    function freezeDefaultRoyalty() external override onlyOwner {
        _freeze(_defaultRoyalty, 0);
    }

    /// @notice Materializes inherited defaults before freezing, including an inherited zero rate.
    function freezeCollectionRoyalty(uint256 collectionId) external override onlyOwner {
        _requireCollection(collectionId);
        _requireSelectedArtistRegistry();
        RoyaltyConfig storage item = _collectionRoyalties[collectionId];
        RoyaltyConfig memory candidate = item.configured ? item : _defaultRoyalty;
        candidate.frozen = true;
        _requireArtistEconomics(collectionId, candidate);
        if (!item.configured) {
            item.wallet = _defaultRoyalty.wallet;
            item.royaltyBps = _defaultRoyalty.royaltyBps;
            item.profileId = _defaultRoyalty.profileId;
        }
        _freeze(item, collectionId);
    }

    /// @inheritdoc IStreamRoyaltyFreeze
    function applyArtistRoyaltyFreeze(uint256 collectionId, bytes32 expectedAssignmentHash)
        external
        override
    {
        _requireCollection(collectionId);
        _requireSelectedArtistRegistry();
        RoyaltyConfig storage item = _collectionRoyalties[collectionId];
        bytes32 currentHash = item.configured ? _assignmentHash(item, 1, collectionId) : bytes32(0);
        if (expectedAssignmentHash == bytes32(0) || expectedAssignmentHash != currentHash) {
            revert ArtistRoyaltyAssignmentChanged(collectionId, expectedAssignmentHash, currentHash);
        }
        if (item.frozen) revert RoyaltyConfigurationFrozen(collectionId);
        if (
            !IERC165(address(artistRegistry))
                    .supportsInterface(type(IStreamArtistEconomicsAuthority).interfaceId)
                || !IStreamArtistEconomicsAuthority(address(artistRegistry))
                    .isRoyaltyFreezeAuthorized(collectionId, currentHash)
        ) revert ArtistRoyaltyFreezeNotAuthorized(collectionId, currentHash);
        _freeze(item, collectionId);
    }

    function defaultRoyalty() external view override returns (RoyaltyConfig memory) {
        return _defaultRoyalty;
    }

    function collectionRoyalty(uint256 collectionId)
        external
        view
        override
        returns (RoyaltyConfig memory)
    {
        return _collectionRoyalties[collectionId];
    }

    function _configure(
        RoyaltyConfig storage item,
        uint256 collectionId,
        bytes32 profileId,
        uint16 royaltyBps
    ) private {
        if (item.frozen) revert RoyaltyConfigurationFrozen(collectionId);
        RoyaltyConfig memory candidate = _candidate(profileId, royaltyBps);
        item.wallet = candidate.wallet;
        item.royaltyBps = royaltyBps;
        item.profileId = profileId;
        item.configured = true;
        item.revision += 1;
        emit RoyaltyConfigured(collectionId, profileId, candidate.wallet, royaltyBps, item.revision);
    }

    function _candidate(bytes32 profileId, uint16 royaltyBps)
        private
        view
        returns (RoyaltyConfig memory candidate)
    {
        if (royaltyBps > MAX_ROYALTY_BPS || (royaltyBps == 0) != (profileId == bytes32(0))) {
            revert InvalidRoyaltyConfiguration();
        }
        address wallet;
        if (royaltyBps != 0) {
            if (!splitFactory.splitWalletExists(profileId)) {
                revert InvalidRoyaltySplitProfile(profileId);
            }
            wallet = splitFactory.walletFor(profileId);
        }
        candidate.wallet = wallet;
        candidate.royaltyBps = royaltyBps;
        candidate.profileId = profileId;
        candidate.configured = true;
    }

    function _freeze(RoyaltyConfig storage item, uint256 collectionId) private {
        if (item.frozen) revert RoyaltyConfigurationFrozen(collectionId);
        item.configured = true;
        item.frozen = true;
        item.revision += 1;
        emit RoyaltyFrozen(
            collectionId, item.profileId, item.wallet, item.royaltyBps, item.revision
        );
    }

    function _requireCollection(uint256 collectionId) private view {
        if (collectionId == 0 || !boundCore.collectionExists(collectionId)) {
            revert InvalidRoyaltyCollection(collectionId);
        }
    }
}
