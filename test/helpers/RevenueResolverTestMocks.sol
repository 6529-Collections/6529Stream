// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../smart-contracts/vendor/openzeppelin/IERC165.sol";

/// @dev Target-side identity fixture only. Real Core pointer governance is integration coverage.
contract RevenueResolverCoreMock {
    address public selectedArtist;
    bytes32 public selectedCodeHash;
    mapping(uint256 => uint256) private _tokenCollection;
    mapping(uint256 => bool) private _burned;

    function selectArtist(address artist, bytes32 codeHash) external {
        selectedArtist = artist;
        selectedCodeHash = codeHash;
    }

    function setToken(uint256 tokenId, uint256 collectionId, bool burned) external {
        _tokenCollection[tokenId] = collectionId;
        _burned[tokenId] = burned;
    }

    function collectionExists(uint256 collectionId) external pure returns (bool) {
        return collectionId != 0 && collectionId <= 1000;
    }

    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (bool exists, uint256 collectionId, uint256 serial, bool burned)
    {
        collectionId = _tokenCollection[tokenId];
        return (collectionId != 0, collectionId, 1, _burned[tokenId]);
    }

    function getSatellitePointer(bytes32 pointerType)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        require(pointerType == keccak256("ARTIST_REGISTRY"), "unexpected pointer");
        return (
            selectedArtist,
            selectedCodeHash,
            false,
            pointerType,
            type(IStreamArtistAttribution).interfaceId,
            address(1),
            1,
            bytes32(0),
            bytes32(0),
            1
        );
    }
}

contract RevenueResolverArtistMock is IStreamArtistAttribution, IERC165 {
    address public immutable override core;
    mapping(uint256 => IStreamCollectionArtistRegistry.Attribution) private _attributions;
    bool public readFailure;

    constructor(address core_) {
        core = core_;
    }

    function setBinding(uint256 collectionId, bytes32 nomination, address accepted) external {
        _attributions[collectionId].nominationHash = nomination;
        _attributions[collectionId].artist = accepted;
    }

    function setReadFailure(bool failed) external {
        readFailure = failed;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId || id == type(IERC165).interfaceId;
    }

    function acceptedArtist(uint256 collectionId) external view returns (address) {
        return _attributions[collectionId].artist;
    }

    function attribution(uint256 collectionId)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory)
    {
        require(!readFailure, "artist facts unavailable");
        return _attributions[collectionId];
    }
}
