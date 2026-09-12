// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyPreview.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyScopeFacts.sol";
import "../../interfaces/stream/revenue/IStreamTokenRoyaltyResolver.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../../interfaces/stream/revenue/IStreamRoyaltyFreeze.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../vendor/openzeppelin/Ownable.sol";

/// @notice Governance-owned live token, collection, and default royalties with exact freezes.
/// @dev Default/collection terms are independent of primary-sale profiles. This resolver does
///      not implement mint-time snapshots. ERC-2981 discloses royalties;
///      it does not restrict transfers or require a marketplace to pay them.
contract StreamRoyaltyResolver is
    IStreamRoyaltyResolver,
    IStreamArtistRoyaltyFacts,
    IStreamArtistRoyaltyPreview,
    IStreamArtistRoyaltyScopeFacts,
    IStreamTokenRoyaltyResolver,
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
    mapping(uint256 => RoyaltyConfig) private _tokenRoyalties;
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
            || id == type(IStreamArtistRoyaltyScopeFacts).interfaceId
            || id == type(IStreamTokenRoyaltyResolver).interfaceId
            || id == type(IStreamRoyaltyFreeze).interfaceId || super.supportsInterface(id);
    }

    function royaltyEconomicsFacts(uint256 collectionId, uint8 scope, uint256 scopeId)
        external
        view
        override
        returns (
            StreamArtistOnboardingTypes.AssignmentFact memory fact,
            RoyaltyConfig memory config
        )
    {
        _requireScopeContext(collectionId, scope, scopeId);
        config = _key(scope, scopeId);
        fact = _fact(scope, scopeId, config);
    }

    function previewArtistRoyaltyAssignmentForScope(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 profileHash,
        uint16 royaltyBps,
        bool frozen
    ) external view override returns (StreamArtistOnboardingTypes.AssignmentFact memory fact) {
        _requireScopeContext(collectionId, scope, scopeId);
        RoyaltyConfig memory candidate = _candidate(profileHash, royaltyBps);
        candidate.frozen = frozen;
        return _fact(scope, scopeId, candidate);
    }

    function previewArtistRoyaltyClear(uint256 collectionId, uint8 scope, uint256 scopeId)
        external
        view
        override
        returns (
            StreamArtistOnboardingTypes.AssignmentFact memory fact,
            bytes32 previousAssignmentHash
        )
    {
        _requireScopeContext(collectionId, scope, scopeId);
        if (scope == 0) revert InvalidRoyaltyScope(scope, scopeId);
        RoyaltyConfig memory item = _key(scope, scopeId);
        if (!item.configured) revert RoyaltyAssignmentMissing(scope, scopeId);
        if (item.frozen) revert RoyaltyAssignmentFrozen(scope, scopeId);
        previousAssignmentHash = _assignmentHash(item, scope, scopeId);
        fact = StreamArtistOnboardingTypes.AssignmentFact(
            address(this), keccak256("ROYALTY_ERC2981"), scope, scopeId, bytes32(0)
        );
    }

    function resolveRoyaltyAssignment(uint256 collectionId, uint256 tokenId)
        external
        view
        override
        returns (
            StreamArtistOnboardingTypes.AssignmentFact memory fact,
            RoyaltyConfig memory config,
            bytes32 royaltyPolicyHash
        )
    {
        _requireSelectedArtistRegistry();
        if (tokenId != 0) {
            uint256 mapped = _tokenCollection(tokenId);
            if (collectionId != 0 && mapped != collectionId) revert InvalidRoyaltyToken(tokenId);
            collectionId = mapped;
        } else if (collectionId != 0) {
            _requireCollection(collectionId);
        }
        uint8 scope;
        uint256 scopeId;
        (scope, scopeId, config) = _selected(collectionId, tokenId);
        fact = _fact(scope, scopeId, config);
        royaltyPolicyHash = _policyHash(collectionId, scope, scopeId, config, fact.assignmentHash);
    }

    function _fact(uint8 scope, uint256 scopeId, RoyaltyConfig memory item)
        private
        view
        returns (StreamArtistOnboardingTypes.AssignmentFact memory)
    {
        return StreamArtistOnboardingTypes.AssignmentFact(
            address(this),
            keccak256("ROYALTY_ERC2981"),
            scope,
            scopeId,
            item.configured ? _assignmentHash(item, scope, scopeId) : bytes32(0)
        );
    }

    function _key(uint8 scope, uint256 scopeId) private view returns (RoyaltyConfig storage item) {
        if (scope == 0) return _defaultRoyalty;
        if (scope == 1) return _collectionRoyalties[scopeId];
        return _tokenRoyalties[scopeId];
    }

    function _selected(uint256 collectionId, uint256 tokenId)
        private
        view
        returns (uint8 scope, uint256 scopeId, RoyaltyConfig memory item)
    {
        if (tokenId != 0 && _tokenRoyalties[tokenId].configured) {
            return (2, tokenId, _tokenRoyalties[tokenId]);
        }
        if (collectionId != 0 && _collectionRoyalties[collectionId].configured) {
            return (1, collectionId, _collectionRoyalties[collectionId]);
        }
        return (0, 0, _defaultRoyalty);
    }

    function _policyHash(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        RoyaltyConfig memory item,
        bytes32 assignmentHash
    ) private view returns (bytes32) {
        if (!item.configured) return bytes32(0);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROYALTY_POLICY_V1"),
                block.chainid,
                address(this),
                scope == 0 ? uint256(0) : collectionId,
                scope == 2 ? scopeId : uint256(0),
                item.profileId,
                item.wallet,
                item.royaltyBps,
                assignmentHash
            )
        );
    }

    function _requireScopeContext(uint256 collectionId, uint8 scope, uint256 scopeId) private view {
        _requireSelectedArtistRegistry();
        _requireCollection(collectionId);
        if (
            scope > 2 || (scope == 0 && scopeId != 0) || (scope == 1 && scopeId != collectionId)
                || (scope == 2 && scopeId == 0)
        ) revert InvalidRoyaltyScope(scope, scopeId);
        if (scope == 2 && _tokenCollection(scopeId) != collectionId) {
            revert InvalidRoyaltyToken(scopeId);
        }
    }

    function _tokenCollection(uint256 tokenId) private view returns (uint256 collectionId) {
        (bool exists, uint256 mapped,,) = boundCore.tokenCollectionIdentity(tokenId);
        if (tokenId == 0 || !exists || mapped == 0) revert InvalidRoyaltyToken(tokenId);
        _requireCollection(mapped);
        return mapped;
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
        // The legacy collection-only preview retains its nonzero-profile contract.
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

    /// @notice Collection/default RSR fact, including bps and the selected scope.
    /// @dev The artist's defensive collection-freeze caller separately requires collection scope.
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
        uint256 tokenId,
        uint256,
        uint256 mappedCollectionId,
        bool hasMappedCollection
    ) external view override returns (address receiver, uint16 royaltyBps) {
        if (core_ != address(boundCore)) return (address(0), 0);
        if (hasMappedCollection) {
            RoyaltyConfig storage token = _tokenRoyalties[tokenId];
            if (token.configured) return (token.wallet, token.royaltyBps);
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
            _requireBoundArtistEconomicsHash(
                collectionId, 1, collectionId, _assignmentHash(candidate, 1, collectionId)
            );
        }
    }

    function _requireArtistEconomicsHash(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 assignmentHash
    ) private view {
        if (artistRegistry.attribution(collectionId).nominationHash != bytes32(0)) {
            _requireBoundArtistEconomicsHash(collectionId, scope, scopeId, assignmentHash);
        }
    }

    function _requireBoundArtistEconomicsHash(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        bytes32 assignmentHash
    ) private view {
        if (!IERC165(address(artistRegistry))
                .supportsInterface(type(IStreamArtistEconomicsAuthority).interfaceId)) {
            revert ArtistEconomicsAuthorizationRequired(collectionId);
        }
        IStreamArtistEconomicsAuthority(address(artistRegistry))
            .requireEconomicsConsent(
                collectionId, keccak256("ROYALTY_ERC2981"), scope, scopeId, assignmentHash
            );
    }

    function configureTokenRoyalty(uint256 tokenId, bytes32 profileId, uint16 royaltyBps)
        external
        override
        onlyOwner
    {
        uint256 collectionId = _tokenCollection(tokenId);
        _requireSelectedArtistRegistry();
        RoyaltyConfig memory previous = _tokenRoyalties[tokenId];
        if (previous.frozen) revert RoyaltyAssignmentFrozen(2, tokenId);
        RoyaltyConfig memory candidate = _candidate(profileId, royaltyBps);
        bytes32 nextHash = _assignmentHash(candidate, 2, tokenId);
        _requireArtistEconomicsHash(collectionId, 2, tokenId, nextHash);
        candidate.revision = previous.revision + 1;
        _tokenRoyalties[tokenId] = candidate;
        emit RevenueAssignmentSet(
            keccak256("ROYALTY_ERC2981"),
            2,
            tokenId,
            1,
            msg.sender,
            previous.profileId,
            previous.wallet,
            previous.royaltyBps,
            candidate.profileId,
            candidate.wallet,
            candidate.royaltyBps,
            false,
            false,
            bytes32(0)
        );
        _emitContext(collectionId, 2, tokenId, previous, candidate);
    }

    function clearTokenRoyalty(uint256 tokenId) external override onlyOwner {
        _clearRoyalty(_tokenCollection(tokenId), 2, tokenId);
    }

    function clearCollectionRoyalty(uint256 collectionId) external override onlyOwner {
        _requireCollection(collectionId);
        _clearRoyalty(collectionId, 1, collectionId);
    }

    function _clearRoyalty(uint256 collectionId, uint8 scope, uint256 scopeId) private {
        _requireSelectedArtistRegistry();
        RoyaltyConfig memory previous = _key(scope, scopeId);
        if (!previous.configured) revert RoyaltyAssignmentMissing(scope, scopeId);
        if (previous.frozen) revert RoyaltyAssignmentFrozen(scope, scopeId);
        _requireArtistEconomicsHash(collectionId, scope, scopeId, bytes32(0));
        RoyaltyConfig memory empty;
        empty.revision = previous.revision + 1;
        if (scope == 1) _collectionRoyalties[scopeId] = empty;
        else _tokenRoyalties[scopeId] = empty;
        emit RevenueAssignmentCleared(
            keccak256("ROYALTY_ERC2981"),
            scope,
            scopeId,
            1,
            msg.sender,
            previous.profileId,
            previous.wallet,
            previous.royaltyBps,
            false
        );
        _emitContext(collectionId, scope, scopeId, previous, empty);
    }

    function freezeTokenRoyalty(uint256 tokenId) external override onlyOwner {
        uint256 collectionId = _tokenCollection(tokenId);
        _requireSelectedArtistRegistry();
        RoyaltyConfig memory previous = _tokenRoyalties[tokenId];
        if (previous.frozen) revert RoyaltyAssignmentFrozen(2, tokenId);
        (,, RoyaltyConfig memory candidate) = _selected(collectionId, tokenId);
        if (!candidate.configured) revert RoyaltyAssignmentMissing(2, tokenId);
        candidate.frozen = true;
        candidate.revision = previous.revision + 1;
        _requireArtistEconomicsHash(
            collectionId, 2, tokenId, _assignmentHash(candidate, 2, tokenId)
        );
        _tokenRoyalties[tokenId] = candidate;
        if (!previous.configured) {
            emit RevenueAssignmentSet(
                keccak256("ROYALTY_ERC2981"),
                2,
                tokenId,
                1,
                msg.sender,
                bytes32(0),
                address(0),
                0,
                candidate.profileId,
                candidate.wallet,
                candidate.royaltyBps,
                false,
                false,
                bytes32(0)
            );
        }
        emit RevenueAssignmentFrozen(keccak256("ROYALTY_ERC2981"), 2, tokenId, 1, true, 1);
        _emitContext(collectionId, 2, tokenId, previous, candidate);
    }

    function tokenRoyalty(uint256 tokenId) external view override returns (RoyaltyConfig memory) {
        return _tokenRoyalties[tokenId];
    }

    function _emitContext(
        uint256 collectionId,
        uint8 scope,
        uint256 scopeId,
        RoyaltyConfig memory previous,
        RoyaltyConfig memory next
    ) private {
        bytes32 nextHash = next.configured ? _assignmentHash(next, scope, scopeId) : bytes32(0);
        emit RoyaltyAssignmentContext(
            1,
            collectionId,
            scope == 2 ? scopeId : 0,
            nextHash,
            scope,
            scopeId,
            previous.configured ? _assignmentHash(previous, scope, scopeId) : bytes32(0),
            _policyHash(collectionId, scope, scopeId, next, nextHash),
            msg.sender
        );
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
