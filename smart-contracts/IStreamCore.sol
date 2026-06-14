// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IStreamCore {
    function retrievewereDataAdded(uint256 _collectionID) external view returns (bool);

    function viewTokensIndexMin(uint256 _collectionID) external view returns (uint256);

    function viewTokensIndexMax(uint256 _collectionID) external view returns (uint256);

    function viewCirSupply(uint256 _collectionID) external view returns (uint256);

    function mint(
        uint256 mintIndex,
        address _recipient,
        string memory _tokenData,
        uint256 _saltfun_o,
        uint256 _collectionID
    ) external;

    function collectionFreezeStatus(uint256 _collectionID) external view returns (bool);

    function collectionFreezeManifestHash(uint256 _collectionID) external view returns (bytes32);

    function previewCollectionFreezeManifestHash(uint256 _collectionID)
        external
        view
        returns (bytes32);

    function previewArtistApprovalHash(uint256 _collectionID) external view returns (bytes32);

    function artistApprovalHashes(uint256 _collectionID) external view returns (bytes32);

    function collectionDependencyVersionState(uint256 _collectionID)
        external
        view
        returns (bytes32, uint256, bytes32, address);

    function viewMaxAllowance(uint256 _collectionID) external view returns (uint256);

    function viewColIDforTokenID(uint256 _tokenid) external view returns (uint256);

    function isTokenBurned(uint256 tokenId) external view returns (bool);

    function viewCollectionRandomizerContract(uint256 _collectionID) external view returns (address);

    function viewRandomizerEpoch(uint256 _collectionID) external view returns (uint256);

    function retrieveArtistAddress(uint256 _collectionID) external view returns (address);

    function setTokenHash(uint256 _collectionID, uint256 _mintIndex, bytes32 _hash) external;

    function retrieveTokenHash(uint256 _tokenid) external view returns (bytes32);
}
