// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamCollectionArtistRegistry.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../modules/StreamModuleBase.sol";
import "../mint/StreamSaleSignatures.sol";

/// @notice A collection's nominated artist accepts its attribution before the first mint.
/// @dev Acceptance is immutable. Each sale/auction separately authenticates the artist's exact
/// transaction terms; this registry does not claim collaborator, recovery, or estate capabilities.
contract StreamCollectionArtistRegistry is
    StreamModuleBase,
    ReentrancyGuard,
    IStreamCollectionArtistRegistry
{
    bytes32 public constant ACCEPTANCE_TYPEHASH = keccak256(
        "CollectionArtistAcceptance(address core,uint256 collectionId,bytes32 nominationHash,uint256 nonce,uint64 deadline)"
    );
    bytes32 private constant _DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant _NOMINATION_DOMAIN =
        keccak256("6529STREAM_COLLECTION_ARTIST_NOMINATION_V1");
    address public immutable override core;
    address public immutable authority;
    mapping(uint256 => Attribution) private _attributions;
    mapping(address => uint256) public override acceptanceNonces;

    constructor(
        address core_,
        address authority_,
        bytes32 deploymentManifestHash,
        string memory manifestURI,
        bytes32 manifestHash
    )
        StreamModuleBase(
            keccak256("6529stream.collection-artist.schema.v1"),
            address(0),
            deploymentManifestHash,
            manifestURI,
            manifestHash
        )
    {
        if (
            core_.code.length == 0 || authority_ == address(0) || deploymentManifestHash == 0
                || manifestHash == 0 || !IERC165(core_).supportsInterface(0x80ac58cd)
        ) {
            revert ArtistRegistryInvalidConfiguration();
        }
        core = core_;
        authority = authority_;
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("ARTIST_REGISTRY");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.collection-artist.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamCollectionArtistRegistry).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamCollectionArtistRegistry).interfaceId
            || super.supportsInterface(id);
    }

    function nominateArtist(uint256 collectionId, address artist, bytes32 identityHash)
        external
        override
        nonReentrant
    {
        if (msg.sender != authority) revert ArtistRegistryUnauthorized(msg.sender);
        _requireUnstarted(collectionId);
        if (artist == address(0) || identityHash == 0) {
            revert ArtistRegistryInvalidNomination(collectionId);
        }
        Attribution storage item = _attributions[collectionId];
        if (item.artist != address(0)) revert ArtistRegistryAttributionImmutable(collectionId);
        ++item.nominationRevision;
        item.nominatedArtist = artist;
        item.identityHash = identityHash;
        item.nominationHash = keccak256(
            abi.encode(
                _NOMINATION_DOMAIN,
                block.chainid,
                address(this),
                core,
                collectionId,
                artist,
                identityHash,
                item.nominationRevision
            )
        );
        emit CollectionArtistNominated(
            1, collectionId, artist, item.nominationHash, identityHash, item.nominationRevision
        );
    }

    function acceptedArtist(uint256 collectionId) external view override returns (address) {
        return _attributions[collectionId].artist;
    }

    function attribution(uint256 collectionId) external view override returns (Attribution memory) {
        return _attributions[collectionId];
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                _DOMAIN_TYPEHASH,
                keccak256("6529StreamCollectionArtist"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function acceptanceDigest(
        uint256 collectionId,
        bytes32 nominationHash,
        uint256 nonce,
        uint64 deadline
    ) public view override returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                hex"1901",
                domainSeparator(),
                keccak256(
                    abi.encode(
                        ACCEPTANCE_TYPEHASH, core, collectionId, nominationHash, nonce, deadline
                    )
                )
            )
        );
    }

    /// @notice Anyone can relay an EOA/ERC1271 signature; the artist needs no funded transaction.
    /// @dev An artist may also accept directly with an empty signature. A nominated address is
    /// never presented as accepted, and a replaced nomination invalidates its previous signatures.
    function acceptArtist(
        uint256 collectionId,
        bytes32 nominationHash,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external override nonReentrant {
        _requireUnstarted(collectionId);
        Attribution storage item = _attributions[collectionId];
        if (item.artist != address(0)) revert ArtistRegistryAttributionImmutable(collectionId);
        address artist = item.nominatedArtist;
        if (
            artist == address(0) || nominationHash == 0 || nominationHash != item.nominationHash
                || nonce != acceptanceNonces[artist]
        ) revert ArtistRegistryInvalidAcceptance();
        if (block.timestamp > deadline) revert ArtistRegistryAcceptanceExpired(deadline);
        bytes32 digest = acceptanceDigest(collectionId, nominationHash, nonce, deadline);
        if (
            !(msg.sender == artist && signature.length == 0)
                && !StreamSaleSignatures.isValid(artist, digest, signature)
        ) {
            revert ArtistRegistryInvalidSignature(artist);
        }
        acceptanceNonces[artist] = nonce + 1;
        item.artist = artist;
        item.acceptanceHash = digest;
        item.acceptedAt = uint64(block.timestamp);
        emit CollectionArtistAccepted(1, collectionId, artist, digest, nominationHash, nonce);
    }

    function invalidateAcceptanceNonce(uint256 newNonce) external override nonReentrant {
        uint256 oldNonce = acceptanceNonces[msg.sender];
        if (newNonce <= oldNonce) revert ArtistRegistryInvalidAcceptance();
        acceptanceNonces[msg.sender] = newNonce;
        emit ArtistAcceptanceNonceInvalidated(1, msg.sender, oldNonce, newNonce);
    }

    function requireArtist(uint256 collectionId, address artist) external view override {
        address accepted = _attributions[collectionId].artist;
        if (accepted == address(0) || artist != accepted) {
            revert ArtistRegistryArtistMismatch(collectionId, accepted, artist);
        }
    }

    function _requireUnstarted(uint256 collectionId) private view {
        IStreamCore source = IStreamCore(core);
        if (!source.collectionExists(collectionId)) {
            revert ArtistRegistryInvalidNomination(collectionId);
        }
        if (
            source.collectionMintedEver(collectionId) != 0
                || source.collectionFreezeStatus(collectionId)
        ) {
            revert ArtistRegistryCollectionStarted(collectionId);
        }
    }
}
