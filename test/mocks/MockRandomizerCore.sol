// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockRandomizerCore {
    mapping(uint256 => uint256) private randomizerEpochs;
    mapping(uint256 => address) private randomizerContracts;
    mapping(uint256 => uint256) private tokenCollections;

    function setRandomizer(uint256 collectionId, address randomizer, uint256 epoch) external {
        randomizerContracts[collectionId] = randomizer;
        randomizerEpochs[collectionId] = epoch;
    }

    function setTokenCollection(uint256 tokenId, uint256 collectionId) external {
        tokenCollections[tokenId] = collectionId;
    }

    function viewColIDforTokenID(uint256 tokenId) external view returns (uint256) {
        return tokenCollections[tokenId];
    }

    function viewCollectionRandomizerContract(uint256 collectionId)
        external
        view
        returns (address)
    {
        return randomizerContracts[collectionId];
    }

    function viewRandomizerEpoch(uint256 collectionId) external view returns (uint256) {
        return randomizerEpochs[collectionId];
    }
}
