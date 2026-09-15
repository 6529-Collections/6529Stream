// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamArtistContentTypes
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";

/// @dev Explicit absence-only original Finality for metadata-domain tests, never executed finality.
contract MetadataUnfinalizedOriginalBoundary {
    address public immutable coreReads;

    constructor(address core_) { coreReads = core_; }

    function finalityComponentCount(uint256) external pure returns (uint256) { return 0; }

    function finalityComponentCountForScope(StreamFinalityScope calldata)
        external pure returns (uint256)
    { return 0; }
}

/// @dev Metadata-domain boundary: supplies explicit attribution, ratification and content authorization.
///      Every mint-consent operation rejects; this fixture cannot prove artist eligibility.
contract StreamMetadataArtistBoundary is
    IStreamArtistAttribution,
    IStreamArtistContentRatification,
    IStreamArtistMintConsent,
    IStreamArtistAttributionState,
    IStreamArtistFinalityBinding,
    IERC165
{
    address public immutable override(IStreamArtistAttribution, IStreamArtistMintConsent) core;
    address public immutable mintManager;
    address public immutable override finalityRegistry;
    bytes32 public immutable override finalityRegistryCodeHash;
    address private immutable fixtureOwner;
    IStreamCollectionArtistRegistry.Attribution private record;
    bytes32 private ratifiedContent;
    mapping(bytes32 => bytes32) private contentConsents;
    mapping(bytes32 => StreamArtistContentTypes.FreezeRecord) private freezes;
    mapping(uint256 => mapping(bytes32 => bytes32)) private operativeFreezes;

    error MintConsentOutsideMetadataFixture();

    constructor(address core_, address manager_, address artist_) {
        core = core_;
        mintManager = manager_;
        fixtureOwner = msg.sender;
        finalityRegistry = address(new MetadataUnfinalizedOriginalBoundary(core_));
        finalityRegistryCodeHash = finalityRegistry.codehash;
        record = IStreamCollectionArtistRegistry.Attribution({
            nominatedArtist: artist_,
            artist: artist_,
            identityHash: keccak256("metadata fixture identity"),
            nominationHash: keccak256("metadata fixture binding"),
            acceptanceHash: keccak256("metadata fixture acceptance"),
            nominationRevision: 1,
            acceptedAt: uint64(block.timestamp)
        });
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId
            || id == type(IStreamArtistMintConsent).interfaceId
            || id == type(IStreamArtistAttributionState).interfaceId
            || id == type(IStreamArtistFinalityBinding).interfaceId || id == type(IERC165).interfaceId;
    }

    function acceptedArtist(uint256 collectionId) external view returns (address) {
        return collectionId == 1 ? record.artist : address(0);
    }

    function collectionArtistState(uint256 collectionId)
        external view returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        if (collectionId != 1) return (0, 0, 0, 0, 0);
        return (2, record.nominationRevision, keccak256("metadata fixture artist"), 1, record.nominationHash);
    }

    function attribution(uint256 collectionId)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory value)
    {
        if (collectionId == 1) value = record;
    }

    function setRatification(bytes32 contentHash) external {
        require(msg.sender == fixtureOwner && contentHash != 0, "fixture ratification");
        ratifiedContent = contentHash;
    }

    function firstReleaseRatification(uint256 collectionId)
        external
        view
        returns (bool ratified, bytes32 contentHash, bytes32 recordHash)
    {
        if (collectionId == 1 && ratifiedContent != 0) {
            return (
                true,
                ratifiedContent,
                keccak256(abi.encode("metadata fixture ratification", ratifiedContent))
            );
        }
    }

    /// @dev Explicit metadata-domain authorization boundary; no artist signature validation is claimed.
    function setContentConsent(
        uint256 collectionId,
        bytes32 family,
        bytes32 state,
        bytes32 recordHash
    ) external {
        require(msg.sender == fixtureOwner, "fixture owner");
        contentConsents[keccak256(abi.encode(collectionId, family, state))] = recordHash;
    }

    function contentConsentEvidence(uint256 collectionId, bytes32 family, bytes32 state)
        external
        view
        returns (bytes32)
    {
        bytes32 evidence = contentConsents[keccak256(abi.encode(collectionId, family, state))];
        require(evidence != bytes32(0), "missing fixture consent");
        return evidence;
    }

    function setContentFreeze(
        uint256 collectionId,
        StreamArtistContentTypes.FreezeRecord calldata value
    ) external {
        require(msg.sender == fixtureOwner, "fixture owner");
        freezes[value.recordHash] = value;
        for (uint256 i; i < value.lockClasses.length; ++i) {
            operativeFreezes[collectionId][value.lockClasses[i]] = value.recordHash;
        }
    }

    function contentFreezeAuthorization(bytes32 recordHash)
        external
        view
        returns (StreamArtistContentTypes.FreezeRecord memory)
    {
        return freezes[recordHash];
    }

    function isContentFreezeAuthorized(uint256 collectionId, bytes32 lockClass)
        external
        view
        returns (bool, bytes32)
    {
        bytes32 value = operativeFreezes[collectionId][lockClass];
        return (value != bytes32(0), value);
    }

    function consentMode(uint256) external pure returns (uint8) {
        revert MintConsentOutsideMetadataFixture();
    }

    function isPolicyConsented(uint256, bytes32, bytes32) external pure returns (bool, bytes32) {
        revert MintConsentOutsideMetadataFixture();
    }

    function requireMintConsent(uint256, bytes32, bytes32) external pure {
        revert MintConsentOutsideMetadataFixture();
    }
}
