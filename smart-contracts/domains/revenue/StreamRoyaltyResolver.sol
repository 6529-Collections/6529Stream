// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../../vendor/openzeppelin/Ownable.sol";

/// @notice Governance-owned live collection royalties with exact, permanent collection freezes.
/// @dev Default/collection terms are independent of primary-sale profiles. This resolver does
///      not implement token overrides or mint-time snapshots. ERC-2981 discloses royalties;
///      it does not restrict transfers or require a marketplace to pay them.
contract StreamRoyaltyResolver is IStreamRoyaltyResolver, ERC165, Ownable {
    uint16 public constant MAX_ROYALTY_BPS = 1_000;
    IStreamCore public immutable boundCore;
    IStreamSplitFactory public immutable splitFactory;

    RoyaltyConfig private _defaultRoyalty;
    mapping(uint256 => RoyaltyConfig) private _collectionRoyalties;

    constructor(IStreamCore core_, IStreamSplitFactory splitFactory_, address governanceExecutor_) {
        if (
            address(core_).code.length == 0 || address(splitFactory_).code.length == 0
                || governanceExecutor_.code.length == 0
        ) revert InvalidRoyaltyConfiguration();
        boundCore = core_;
        splitFactory = splitFactory_;
        _transferOwnership(governanceExecutor_);
    }

    function supportsInterface(bytes4 id) public view override(ERC165, IERC165) returns (bool) {
        return id == type(IStreamRoyaltyResolver).interfaceId || super.supportsInterface(id);
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
        _configure(_collectionRoyalties[collectionId], collectionId, profileId, royaltyBps);
    }

    function freezeDefaultRoyalty() external override onlyOwner {
        _freeze(_defaultRoyalty, 0);
    }

    /// @notice Materializes inherited defaults before freezing, including an inherited zero rate.
    function freezeCollectionRoyalty(uint256 collectionId) external override onlyOwner {
        _requireCollection(collectionId);
        RoyaltyConfig storage item = _collectionRoyalties[collectionId];
        if (!item.configured) {
            item.wallet = _defaultRoyalty.wallet;
            item.royaltyBps = _defaultRoyalty.royaltyBps;
            item.profileId = _defaultRoyalty.profileId;
        }
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
        item.wallet = wallet;
        item.royaltyBps = royaltyBps;
        item.profileId = profileId;
        item.configured = true;
        item.revision += 1;
        emit RoyaltyConfigured(collectionId, profileId, wallet, royaltyBps, item.revision);
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
