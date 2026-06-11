// SPDX-License-Identifier: MIT

/**
 *
 *  @title: Modified version of NextGen 6529 - Core Contract to support 6529 Stream
 *  @date: 27-June-2024
 *  @version: 10.31
 *  @author: 6529 team
 */

pragma solidity ^0.8.19;

import "./ERC721Enumerable.sol";
import "./Strings.sol";
import "./Base64.sol";
import "./IRandomizer.sol";
import "./IRandomizerLifecycle.sol";
import "./IStreamAdmins.sol";
import "./IStreamMinter.sol";
import "./ERC2981.sol";
import "./Ownable.sol";
import "./IDependencyRegistry.sol";
import "./IERC4906.sol";
import "./StreamPauseDomains.sol";

contract StreamCore is ERC721Enumerable, ERC2981, Ownable, IERC4906 {
    using Strings for uint256;

    bytes4 private constant _INTERFACE_ID_ERC4906 = 0x49064906;
    string public constant METADATA_SCHEMA_VERSION = "6529stream-v1";
    bytes32 public constant METADATA_FREEZE_MANIFEST_TYPEHASH = keccak256(
        "6529StreamMetadataFreezeManifest(uint256 collectionId,bytes32 schemaVersionHash,bytes32 collectionStateHash,bytes32 supplyStateHash,bytes32 liveTokenMetadataHash,bytes32 integrationStateHash,address core,uint256 chainId)"
    );
    bytes32 private constant _FREEZE_COLLECTION_STATE_TYPEHASH = keccak256(
        "6529StreamFreezeCollectionState(bool onchainMetadata,bytes32 collectionInfoHash,bytes32 dependencyKey,uint256 dependencyVersion,bytes32 dependencyContentHash,bytes32 collectionScriptHash)"
    );
    bytes32 private constant _FREEZE_SUPPLY_STATE_TYPEHASH = keccak256(
        "6529StreamFreezeSupplyState(uint256 finalSupply,uint256 mintedEver,uint256 burnCount)"
    );
    bytes32 private constant _FREEZE_INTEGRATION_STATE_TYPEHASH = keccak256(
        "6529StreamFreezeIntegrationState(uint256 randomizerEpoch,address randomizer,address dependencyRegistry)"
    );
    bytes32 private constant _COLLECTION_INFO_TYPEHASH = keccak256(
        "6529StreamCollectionInfo(bytes32 nameHash,bytes32 artistHash,bytes32 descriptionHash,bytes32 websiteHash,bytes32 licenseHash,bytes32 baseURIHash,bytes32 libraryHash)"
    );
    bytes32 private constant _COLLECTION_SCRIPT_TYPEHASH =
        keccak256("6529StreamCollectionScript(uint256 chunkCount,bytes32 chunksHash)");
    bytes32 private constant _COLLECTION_SCRIPT_CHUNK_TYPEHASH = keccak256(
        "6529StreamCollectionScriptChunk(uint256 index,bytes32 chunkHash,uint256 byteLength)"
    );
    bytes32 private constant _TOKEN_METADATA_RECORD_TYPEHASH = keccak256(
        "6529StreamTokenMetadataRecord(uint256 tokenId,bytes32 tokenDataHash,bytes32 tokenImageHash,bytes32 tokenAttributesHash,bytes32 tokenHash)"
    );
    bytes32 private constant _LIVE_TOKEN_METADATA_AGGREGATE_TYPEHASH =
        keccak256("6529StreamLiveTokenMetadataAggregate(bytes32 accumulator,uint256 liveSupply)");
    string private constant _METADATA_STATE_PENDING = "pending";
    string private constant _METADATA_STATE_FINAL = "final";
    uint256 private constant _COLLECTION_TOKEN_RANGE = 10 ** 10;
    uint256 private constant _FULL_COLLECTION_UPDATE_INDEX = 10 ** 6;
    uint256 private constant _BASE_URI_UPDATE_INDEX = _FULL_COLLECTION_UPDATE_INDEX - 1;

    error CollectionAlreadyFrozen(uint256 collectionId);
    error CollectionDataMissing(uint256 collectionId);
    error CollectionFinalSupplyWindowActive(
        uint256 collectionId, uint256 currentTimestamp, uint256 finalSupplyTimestamp
    );
    error CollectionHasPendingTokenMetadata(uint256 collectionId, uint256 pendingCount);
    error CollectionMintWindowActive(
        uint256 collectionId, uint256 currentTimestamp, uint256 endTime
    );
    error CollectionNotCreated(uint256 collectionId);
    error FrozenCollectionDependencyRegistry();
    error MetadataFrozen(uint256 collectionId);
    error UnknownDependency(bytes32 dependencyNameAndVersion);

    error PendingRandomnessRequests(
        uint256 collectionId, address randomizer, uint256 pendingRequests
    );

    // declare variables
    uint256 public newCollectionIndex;

    // struct that holds a collection's info
    struct collectionInfoStructure {
        string collectionName;
        string collectionArtist;
        string collectionDescription;
        string collectionWebsite;
        string collectionLicense;
        string collectionBaseURI;
        string collectionLibrary;
        bytes32 collectionDependencyScript;
        string[] collectionScript;
    }

    // mapping of collectionInfo struct
    mapping(uint256 => collectionInfoStructure) private collectionInfo;

    // dependency version and content hash pinned for each collection
    mapping(uint256 => uint256) private collectionDependencyVersions;
    mapping(uint256 => bytes32) private collectionDependencyContentHashes;

    // struct that holds a collection's additional data
    struct collectionAdditonalDataStructure {
        address collectionArtistAddress;
        uint256 maxCollectionPurchases;
        uint256 collectionCirculationSupply;
        uint256 collectionTotalSupply;
        uint256 reservedMinTokensIndex;
        uint256 reservedMaxTokensIndex;
        uint256 setFinalSupplyTimeAfterMint;
        address randomizerContract;
        IRandomizer randomizer;
    }

    // mapping of collectionAdditionalData struct
    mapping(uint256 => collectionAdditonalDataStructure) private collectionAdditionalData;

    // monotonic version for randomizer provider changes per collection
    mapping(uint256 => uint256) private collectionRandomizerEpoch;

    // checks if a collection was created
    mapping(uint256 => bool) private isCollectionCreated;

    // checks if data on a collection were added
    mapping(uint256 => bool) private wereDataAdded;

    // maps tokends ids with collectionsids
    mapping(uint256 => uint256) private tokenIdsToCollectionIds;

    // stores the token hash generated by randomizer contracts
    mapping(uint256 => bytes32) private tokenToHash;

    // amount of tokens airdropped per address per collection
    mapping(uint256 => mapping(address => uint256)) private tokensAirdropPerAddress;

    // amount of burnt tokens per collection
    mapping(uint256 => uint256) public burnAmount;

    // metadata view (offchain/onchain)
    mapping(uint256 => bool) public onchainMetadata;

    // artist signature per collection
    mapping(uint256 => string) public artistsSignatures;

    // additional metadata per token
    mapping(uint256 => string) public tokenData;

    // on-chain image URI and attributes per token
    mapping(uint256 => string[2]) private tokenImageAndAttributes;

    // collection lock status (status cannot revert)
    mapping(uint256 => bool) private collectionFreeze;

    // immutable manifest hash recorded when a collection is frozen
    mapping(uint256 => bytes32) private collectionFreezeManifestHashes;

    // live-token metadata aggregate state used by freeze eligibility and manifests
    mapping(uint256 => uint256) private collectionPendingMetadataCounts;
    mapping(uint256 => uint256) private collectionLiveTokenMetadataAccumulators;
    mapping(uint256 => bytes32) private tokenFreezeMetadataRecordHashes;

    // count of frozen collections; used to block global dependency registry swaps
    uint256 private frozenCollectionCount;

    // checks if an artist signed its collection
    mapping(uint256 => bool) public artistSigned;

    // external contracts declaration
    IStreamAdmins private adminsContract;
    IDependencyRegistry private dependencyRegistry;
    address public minterContract;

    // events
    event CollectionCreated(uint256 indexed _collectionID);
    event CollectionRandomizerUpdated(
        uint256 indexed _collectionID,
        address indexed oldRandomizer,
        address indexed newRandomizer,
        uint256 randomizerEpoch
    );
    event CollectionFrozen(
        uint256 indexed _collectionID,
        bytes32 indexed manifestHash,
        string schemaVersion,
        address indexed admin
    );
    event DependencyVersionPinned(
        uint256 indexed _collectionID,
        bytes32 indexed dependencyNameAndVersion,
        uint256 indexed version,
        bytes32 contentHash
    );

    // constructor
    constructor(
        string memory name,
        string memory symbol,
        address _adminsContract,
        address _dependencyRegistry
    ) ERC721(name, symbol) {
        adminsContract = IStreamAdmins(_adminsContract);
        dependencyRegistry = IDependencyRegistry(_dependencyRegistry);
        newCollectionIndex = newCollectionIndex + 1;
        _setDefaultRoyalty(0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377, 690);
    }

    // certain functions can only be called by a global or function admin
    modifier FunctionAdminRequired(bytes4 _selector) {
        require(
            adminsContract.retrieveFunctionAdmin(msg.sender, address(this), _selector) == true
                || adminsContract.retrieveGlobalAdmin(msg.sender) == true,
            "Not allowed"
        );
        _;
    }

    // function to create a Collection
    function createCollection(
        string memory _collectionName,
        string memory _collectionArtist,
        string memory _collectionDescription,
        string memory _collectionWebsite,
        string memory _collectionLicense,
        string memory _collectionBaseURI,
        string memory _collectionLibrary,
        bytes32 _collectionDependencyScript,
        string[] memory _collectionScript
    ) public FunctionAdminRequired(this.createCollection.selector) {
        _requireMetadataMutationNotPaused();
        collectionInfo[newCollectionIndex].collectionName = _collectionName;
        collectionInfo[newCollectionIndex].collectionArtist = _collectionArtist;
        collectionInfo[newCollectionIndex].collectionDescription = _collectionDescription;
        collectionInfo[newCollectionIndex].collectionWebsite = _collectionWebsite;
        collectionInfo[newCollectionIndex].collectionLicense = _collectionLicense;
        collectionInfo[newCollectionIndex].collectionBaseURI = _collectionBaseURI;
        collectionInfo[newCollectionIndex].collectionLibrary = _collectionLibrary;
        collectionInfo[newCollectionIndex].collectionDependencyScript = _collectionDependencyScript;
        collectionInfo[newCollectionIndex].collectionScript = _collectionScript;
        isCollectionCreated[newCollectionIndex] = true;
        _pinCollectionDependency(newCollectionIndex, _collectionDependencyScript);
        emit CollectionCreated(newCollectionIndex);
        newCollectionIndex = newCollectionIndex + 1;
    }

    // function to add/modify the additional data of a collection
    // once a collection is created and total supply is set it cannot change
    function setCollectionData(
        uint256 _collectionID,
        address _collectionArtistAddress,
        uint256 _maxCollectionPurchases,
        uint256 _collectionTotalSupply,
        uint256 _setFinalSupplyTimeAfterMint
    ) public FunctionAdminRequired(this.setCollectionData.selector) {
        _requireMetadataMutationNotPaused();
        require(
            (isCollectionCreated[_collectionID] == true)
                && (collectionFreeze[_collectionID] == false)
                && (_collectionTotalSupply <= _COLLECTION_TOKEN_RANGE),
            "err/freezed"
        );
        if (collectionAdditionalData[_collectionID].collectionTotalSupply == 0) {
            collectionAdditionalData[_collectionID].collectionArtistAddress =
            _collectionArtistAddress;
            collectionAdditionalData[_collectionID].maxCollectionPurchases = _maxCollectionPurchases;
            collectionAdditionalData[_collectionID].collectionCirculationSupply = 0;
            collectionAdditionalData[_collectionID].collectionTotalSupply = _collectionTotalSupply;
            collectionAdditionalData[_collectionID].setFinalSupplyTimeAfterMint =
            _setFinalSupplyTimeAfterMint;
            collectionAdditionalData[_collectionID].reservedMinTokensIndex =
            (_collectionID * _COLLECTION_TOKEN_RANGE);
            collectionAdditionalData[_collectionID].reservedMaxTokensIndex =
                (_collectionID * _COLLECTION_TOKEN_RANGE) + _collectionTotalSupply - 1;
            wereDataAdded[_collectionID] = true;
        } else if (artistSigned[_collectionID] == false) {
            collectionAdditionalData[_collectionID].collectionArtistAddress =
            _collectionArtistAddress;
            collectionAdditionalData[_collectionID].maxCollectionPurchases = _maxCollectionPurchases;
            collectionAdditionalData[_collectionID].setFinalSupplyTimeAfterMint =
            _setFinalSupplyTimeAfterMint;
        } else {
            collectionAdditionalData[_collectionID].maxCollectionPurchases = _maxCollectionPurchases;
            collectionAdditionalData[_collectionID].setFinalSupplyTimeAfterMint =
            _setFinalSupplyTimeAfterMint;
        }
    }

    // set a randomizer contract on a collection
    function addRandomizer(uint256 _collectionID, address _randomizerContract)
        public
        FunctionAdminRequired(this.addRandomizer.selector)
    {
        require(
            IRandomizer(_randomizerContract).isRandomizerContract() == true,
            "Contract is not Randomizer"
        );
        _requireCollectionNotFrozen(_collectionID);
        address oldRandomizer = collectionAdditionalData[_collectionID].randomizerContract;
        _requireNoPendingRandomnessRequests(_collectionID, oldRandomizer);
        collectionRandomizerEpoch[_collectionID] = collectionRandomizerEpoch[_collectionID] + 1;
        collectionAdditionalData[_collectionID].randomizerContract = _randomizerContract;
        collectionAdditionalData[_collectionID].randomizer = IRandomizer(_randomizerContract);
        emit CollectionRandomizerUpdated(
            _collectionID,
            oldRandomizer,
            _randomizerContract,
            collectionRandomizerEpoch[_collectionID]
        );
    }

    // mint function - NextGenCore airdrop function (function is called from minter contract)
    function mint(
        uint256 mintIndex,
        address _recipient,
        string memory _tokenData,
        uint256 _saltfun_o,
        uint256 _collectionID
    ) external {
        require(msg.sender == minterContract, "Caller is not the Minter Contract");
        _requireCollectionNotFrozen(_collectionID);
        collectionAdditionalData[_collectionID].collectionCirculationSupply =
            collectionAdditionalData[_collectionID].collectionCirculationSupply + 1;
        if (
            collectionAdditionalData[_collectionID].collectionTotalSupply
                >= collectionAdditionalData[_collectionID].collectionCirculationSupply
        ) {
            tokensAirdropPerAddress[_collectionID][_recipient] =
                tokensAirdropPerAddress[_collectionID][_recipient] + 1;
            _mintProcessing(mintIndex, _recipient, _tokenData, _collectionID, _saltfun_o);
        } else {
            revert("Supply reached");
        }
    }

    // burn function
    function burn(uint256 _collectionID, uint256 _tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _requireCollectionNotFrozen(_collectionID);
        require(
            (_tokenId >= collectionAdditionalData[_collectionID].reservedMinTokensIndex)
                && (_tokenId <= collectionAdditionalData[_collectionID].reservedMaxTokensIndex),
            "id err"
        );
        _removeLiveTokenMetadataRecord(_collectionID, _tokenId);
        _burn(_tokenId);
        burnAmount[_collectionID] = burnAmount[_collectionID] + 1;
    }

    // mint processing
    function _mintProcessing(
        uint256 _mintIndex,
        address _recipient,
        string memory _tokenData,
        uint256 _collectionID,
        uint256 _saltfun_o
    ) internal {
        tokenData[_mintIndex] = _tokenData;
        tokenIdsToCollectionIds[_mintIndex] = _collectionID;
        _addLiveTokenMetadataRecord(_collectionID, _mintIndex);
        _safeMint(_recipient, _mintIndex);
        collectionAdditionalData[_collectionID].randomizer
            .calculateTokenHash(_collectionID, _mintIndex, _saltfun_o);
    }

    // Additional setter functions

    // function to update a collection's info
    function updateCollectionInfo(
        uint256 _collectionID,
        string memory _newCollectionName,
        string memory _newCollectionArtist,
        string memory _newCollectionDescription,
        string memory _newCollectionWebsite,
        string memory _newCollectionLicense,
        string memory _newCollectionBaseURI,
        string memory _newCollectionLibrary,
        bytes32 _newCollectionDependencyScript,
        uint256 _index,
        string[] memory _newCollectionScript
    ) public FunctionAdminRequired(this.updateCollectionInfo.selector) {
        _requireMetadataMutationNotPaused();
        require(
            (isCollectionCreated[_collectionID] == true)
                && (collectionFreeze[_collectionID] == false),
            "Not allowed"
        );
        if (_index == _FULL_COLLECTION_UPDATE_INDEX) {
            collectionInfo[_collectionID].collectionName = _newCollectionName;
            collectionInfo[_collectionID].collectionArtist = _newCollectionArtist;
            collectionInfo[_collectionID].collectionDescription = _newCollectionDescription;
            collectionInfo[_collectionID].collectionWebsite = _newCollectionWebsite;
            collectionInfo[_collectionID].collectionLicense = _newCollectionLicense;
            collectionInfo[_collectionID].collectionLibrary = _newCollectionLibrary;
            collectionInfo[_collectionID].collectionDependencyScript =
            _newCollectionDependencyScript;
            collectionInfo[_collectionID].collectionScript = _newCollectionScript;
            _pinCollectionDependency(_collectionID, _newCollectionDependencyScript);
        } else if (_index == _BASE_URI_UPDATE_INDEX) {
            collectionInfo[_collectionID].collectionBaseURI = _newCollectionBaseURI;
        } else {
            collectionInfo[_collectionID].collectionScript[_index] = _newCollectionScript[0];
        }
        _emitCollectionMetadataUpdate(_collectionID);
    }

    // function that is used by artists for signing
    function artistSignature(uint256 _collectionID, string memory _signature) public {
        _requireMetadataMutationNotPaused();
        _requireCollectionNotFrozen(_collectionID);
        require(
            msg.sender == collectionAdditionalData[_collectionID].collectionArtistAddress
                && artistSigned[_collectionID] == false,
            "Not artist/Signed"
        );
        artistsSignatures[_collectionID] = _signature;
        artistSigned[_collectionID] = true;
    }

    // function to change the metadata view of a collection
    function changeMetadataView(uint256 _collectionID, bool _status)
        public
        FunctionAdminRequired(this.changeMetadataView.selector)
    {
        _requireMetadataMutationNotPaused();
        require(
            (isCollectionCreated[_collectionID] == true)
                && (collectionFreeze[_collectionID] == false),
            "Not allowed"
        );
        onchainMetadata[_collectionID] = _status;
        _emitCollectionMetadataUpdate(_collectionID);
    }

    // function to change the token data of a token
    function changeTokenData(uint256 _tokenId, string memory newData)
        public
        FunctionAdminRequired(this.changeTokenData.selector)
    {
        _requireMetadataMutationNotPaused();
        uint256 collectionId = tokenIdsToCollectionIds[_tokenId];
        require(collectionFreeze[collectionId] == false, "Data frozen");
        _requireMinted(_tokenId);
        tokenData[_tokenId] = newData;
        _refreshLiveTokenMetadataRecord(collectionId, _tokenId);
        emit MetadataUpdate(_tokenId);
    }

    // function to store onchain an imageURI and attributes for a token
    function updateImagesAndAttributes(
        uint256[] memory _tokenId,
        string[] memory _images,
        string[] memory _attributes
    ) public FunctionAdminRequired(this.updateImagesAndAttributes.selector) {
        _requireMetadataMutationNotPaused();
        require(
            (_tokenId.length == _images.length) && (_images.length == _attributes.length), "inv len"
        );
        for (uint256 x; x < _tokenId.length; x++) {
            uint256 collectionId = tokenIdsToCollectionIds[_tokenId[x]];
            require(collectionFreeze[collectionId] == false, "Data frozen");
            _requireMinted(_tokenId[x]);
            tokenImageAndAttributes[_tokenId[x]][0] = _images[x];
            tokenImageAndAttributes[_tokenId[x]][1] = _attributes[x];
            _refreshLiveTokenMetadataRecord(collectionId, _tokenId[x]);
            emit MetadataUpdate(_tokenId[x]);
        }
    }

    // function to lock collection, this action connot be reverted
    function freezeCollection(uint256 _collectionID)
        public
        FunctionAdminRequired(this.freezeCollection.selector)
    {
        _requireMetadataMutationNotPaused();
        _requireFreezeEligible(_collectionID);
        _finalizeCollectionSupply(_collectionID);
        bytes32 manifestHash = _collectionFreezeManifestHash(_collectionID);
        collectionFreeze[_collectionID] = true;
        collectionFreezeManifestHashes[_collectionID] = manifestHash;
        frozenCollectionCount = frozenCollectionCount + 1;
        emit CollectionFrozen(_collectionID, manifestHash, METADATA_SCHEMA_VERSION, msg.sender);
    }

    // function to set the tokenHash (this function is called only from randomizer contracts)
    function setTokenHash(uint256 _collectionID, uint256 _mintIndex, bytes32 _hash) external {
        require(msg.sender == collectionAdditionalData[_collectionID].randomizerContract);
        _requireCollectionNotFrozen(_collectionID);
        require(_hash != bytes32(0), "Zero token hash");
        require(
            (_mintIndex >= collectionAdditionalData[_collectionID].reservedMinTokensIndex)
                && (_mintIndex <= collectionAdditionalData[_collectionID].reservedMaxTokensIndex),
            "Wrong collection"
        );
        require(tokenToHash[_mintIndex] == bytes32(0));
        bool liveToken = _exists(_mintIndex);
        if (liveToken) {
            require(tokenIdsToCollectionIds[_mintIndex] == _collectionID, "Wrong collection");
        }
        tokenToHash[_mintIndex] = _hash;
        // Record pre-mint callbacks, but only live tokens announce metadata changes.
        if (liveToken) {
            _markLiveTokenMetadataFinal(_collectionID, _mintIndex);
            _refreshLiveTokenMetadataRecord(_collectionID, _mintIndex);
            emit MetadataUpdate(_mintIndex);
        }
    }

    // function to set final supply, this applies only for unminted collections and will adjust totalSupply = circulatingSupply
    function setFinalSupply(uint256 _collectionID)
        public
        FunctionAdminRequired(this.setFinalSupply.selector)
    {
        _requireCollectionNotFrozen(_collectionID);
        require(
            block.timestamp
                > IStreamMinter(minterContract).getEndTime(_collectionID)
                    + collectionAdditionalData[_collectionID].setFinalSupplyTimeAfterMint,
            "Time has not passed"
        );
        _finalizeCollectionSupply(_collectionID);
    }

    // function to update the admin, minter or dependency contract
    // 1. admin contract 2. minter contract 3. dependency registry contract
    function updateContracts(uint8 _opt, address _newContract)
        public
        FunctionAdminRequired(this.updateContracts.selector)
    {
        if (_opt == 1) {
            require(IStreamAdmins(_newContract).isAdminContract() == true, "Not Admin");
            adminsContract = IStreamAdmins(_newContract);
        } else if (_opt == 2) {
            require(IStreamMinter(_newContract).isMinterContract() == true, "Not Minter");
            minterContract = _newContract;
        } else if (_opt == 3) {
            if (frozenCollectionCount != 0) {
                revert FrozenCollectionDependencyRegistry();
            }
            dependencyRegistry = IDependencyRegistry(_newContract);
        }
    }

    function _pinCollectionDependency(uint256 _collectionID, bytes32 dependencyNameAndVersion)
        private
    {
        uint256 version = 0;
        bytes32 contentHash;
        if (dependencyNameAndVersion == bytes32(0)) {
            contentHash =
                dependencyRegistry.getDependencyScriptContentHashAtVersion(bytes32(0), version);
        } else {
            version = dependencyRegistry.latestDependencyVersion(dependencyNameAndVersion);
            if (version == 0) {
                revert UnknownDependency(dependencyNameAndVersion);
            }
            contentHash = dependencyRegistry.getDependencyScriptContentHashAtVersion(
                dependencyNameAndVersion, version
            );
        }
        collectionDependencyVersions[_collectionID] = version;
        collectionDependencyContentHashes[_collectionID] = contentHash;
        emit DependencyVersionPinned(_collectionID, dependencyNameAndVersion, version, contentHash);
    }

    function _requireMetadataMutationNotPaused() private view {
        require(
            adminsContract.isPaused(StreamPauseDomains.METADATA_MUTATION) == false,
            "Metadata paused"
        );
    }

    // Retrieve Functions

    // function that overrides supportInterface
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return interfaceId == _INTERFACE_ID_ERC4906 || super.supportsInterface(interfaceId);
    }

    function _emitCollectionMetadataUpdate(uint256 _collectionID) private {
        // Circulation supply is a minted-ever counter; burns are represented by ERC-721 events.
        uint256 mintedCount = collectionAdditionalData[_collectionID].collectionCirculationSupply;
        if (mintedCount == 0) {
            return;
        }
        uint256 firstTokenId = collectionAdditionalData[_collectionID].reservedMinTokensIndex;
        emit BatchMetadataUpdate(firstTokenId, firstTokenId + mintedCount - 1);
    }

    function _requireNoPendingRandomnessRequests(uint256 _collectionID, address oldRandomizer)
        private
        view
    {
        if (oldRandomizer == address(0)) {
            return;
        }

        try IRandomizerLifecycle(oldRandomizer).supportsRandomizerLifecycle() returns (
            bool supported
        ) {
            if (!supported) {
                return;
            }
        } catch {
            return;
        }

        uint256 pendingRequests =
            IRandomizerLifecycle(oldRandomizer).pendingRandomnessRequests(_collectionID);
        if (pendingRequests != 0) {
            revert PendingRandomnessRequests(_collectionID, oldRandomizer, pendingRequests);
        }
    }

    // function that return the tokenURI
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        uint256 collectionId = tokenIdsToCollectionIds[tokenId];
        bool finalMetadata = _isTokenMetadataFinal(tokenId);

        if (!onchainMetadata[collectionId]) {
            string memory baseURI = collectionInfo[collectionId].collectionBaseURI;
            if (bytes(baseURI).length == 0) {
                return "";
            }
            return finalMetadata
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : string(abi.encodePacked(baseURI, _METADATA_STATE_PENDING));
        }

        return _onchainTokenURI(tokenId, collectionId, finalMetadata);
    }

    /// @notice Returns the active on-chain metadata schema version.
    function metadataSchemaVersion() public pure returns (string memory) {
        return METADATA_SCHEMA_VERSION;
    }

    /// @notice Returns the token's public metadata state under the active schema.
    function tokenMetadataState(uint256 tokenId) public view returns (string memory) {
        _requireMinted(tokenId);
        return _isTokenMetadataFinal(tokenId) ? _METADATA_STATE_FINAL : _METADATA_STATE_PENDING;
    }

    function _isTokenMetadataFinal(uint256 tokenId) private view returns (bool) {
        return tokenToHash[tokenId] != bytes32(0);
    }

    function _onchainTokenURI(uint256 tokenId, uint256 collectionId, bool finalMetadata)
        private
        view
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(_onchainMetadataJson(tokenId, collectionId, finalMetadata)))
            )
        );
    }

    function _onchainMetadataJson(uint256 tokenId, uint256 collectionId, bool finalMetadata)
        private
        view
        returns (string memory)
    {
        string memory animationField = "";
        if (finalMetadata) {
            animationField = string(
                abi.encodePacked(
                    ",\"animation_url\":\"", _onchainAnimationURI(tokenId, collectionId), "\""
                )
            );
        }

        return string(
            abi.encodePacked(
                "{\"metadata_schema_version\":\"",
                METADATA_SCHEMA_VERSION,
                "\",\"metadata_state\":\"",
                finalMetadata ? _METADATA_STATE_FINAL : _METADATA_STATE_PENDING,
                "\",\"name\":\"",
                getTokenName(tokenId),
                "\",\"description\":\"",
                collectionInfo[collectionId].collectionDescription,
                "\",\"image\":\"",
                tokenImageAndAttributes[tokenId][0],
                "\",\"attributes\":[",
                tokenImageAndAttributes[tokenId][1],
                "]",
                animationField,
                "}"
            )
        );
    }

    function _onchainAnimationURI(uint256 tokenId, uint256 collectionId)
        private
        view
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                "data:text/html;base64,",
                Base64.encode(
                    abi.encodePacked(
                        "<html><head></head><body><script src=\"",
                        collectionInfo[collectionId].collectionLibrary,
                        "\"></script><script>",
                        retrieveGenerativeScript(tokenId),
                        "</script></body></html>"
                    )
                )
            )
        );
    }

    // function to retrieve the name attribute
    function getTokenName(uint256 tokenId) private view returns (string memory) {
        uint256 tok = tokenId
            - collectionAdditionalData[tokenIdsToCollectionIds[tokenId]].reservedMinTokensIndex;
        return string(
            abi.encodePacked(
                collectionInfo[viewColIDforTokenID(tokenId)].collectionName, " #", tok.toString()
            )
        );
    }

    // function to retrieve the collection freeze status
    function collectionFreezeStatus(uint256 _collectionID) public view returns (bool) {
        return collectionFreeze[_collectionID];
    }

    /// @notice Returns the manifest hash stored when a collection was frozen.
    /// @dev Returns zero for collections that have not been frozen.
    function collectionFreezeManifestHash(uint256 _collectionID) public view returns (bytes32) {
        return collectionFreezeManifestHashes[_collectionID];
    }

    /// @notice Computes the freeze manifest hash for the collection's current state.
    function previewCollectionFreezeManifestHash(uint256 _collectionID)
        public
        view
        returns (bytes32)
    {
        return _collectionFreezeManifestHash(_collectionID);
    }

    function collectionDependencyVersionState(uint256 _collectionID)
        public
        view
        returns (bytes32, uint256, bytes32, address)
    {
        return (
            collectionInfo[_collectionID].collectionDependencyScript,
            collectionDependencyVersions[_collectionID],
            collectionDependencyContentHashes[_collectionID],
            address(dependencyRegistry)
        );
    }

    // function to return the collection id given a token id
    function viewColIDforTokenID(uint256 _tokenid) public view returns (uint256) {
        return (tokenIdsToCollectionIds[_tokenid]);
    }

    // function to return the current randomizer contract for a collection
    function viewCollectionRandomizerContract(uint256 _collectionID) public view returns (address) {
        return collectionAdditionalData[_collectionID].randomizerContract;
    }

    // function to return the current randomizer epoch for a collection
    function viewRandomizerEpoch(uint256 _collectionID) public view returns (uint256) {
        return collectionRandomizerEpoch[_collectionID];
    }

    // function to retrieve if data were added on a collection
    function retrievewereDataAdded(uint256 _collectionID) external view returns (bool) {
        return wereDataAdded[_collectionID];
    }

    // function to return the min index id of a collection
    function viewTokensIndexMin(uint256 _collectionID) external view returns (uint256) {
        return (collectionAdditionalData[_collectionID].reservedMinTokensIndex);
    }

    // function to return the max index id of a collection
    function viewTokensIndexMax(uint256 _collectionID) external view returns (uint256) {
        return (collectionAdditionalData[_collectionID].reservedMaxTokensIndex);
    }

    // function to return the circ supply of a collection
    function viewCirSupply(uint256 _collectionID) external view returns (uint256) {
        return (collectionAdditionalData[_collectionID].collectionCirculationSupply);
    }

    // function to return max allowance per address during public sale
    function viewMaxAllowance(uint256 _collectionID) external view returns (uint256) {
        return (collectionAdditionalData[_collectionID].maxCollectionPurchases);
    }

    // function to retrieve the airdropped tokens per address
    function retrieveTokensAirdroppedPerAddress(uint256 _collectionID, address _address)
        public
        view
        returns (uint256)
    {
        return (tokensAirdropPerAddress[_collectionID][_address]);
    }

    // function to return the artist's address
    function retrieveArtistAddress(uint256 _collectionID) external view returns (address) {
        return (collectionAdditionalData[_collectionID].collectionArtistAddress);
    }

    // function to retrieve a collection's info
    function retrieveCollectionInfo(uint256 _collectionID)
        public
        view
        returns (
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory
        )
    {
        return (
            collectionInfo[_collectionID].collectionName,
            collectionInfo[_collectionID].collectionArtist,
            collectionInfo[_collectionID].collectionDescription,
            collectionInfo[_collectionID].collectionWebsite,
            collectionInfo[_collectionID].collectionLicense,
            collectionInfo[_collectionID].collectionBaseURI
        );
    }

    // function to retrieve the library and script of a collection
    function retrieveCollectionLibraryAndScript(uint256 _collectionID)
        public
        view
        returns (string memory, bytes32, string[] memory)
    {
        return (
            collectionInfo[_collectionID].collectionLibrary,
            collectionInfo[_collectionID].collectionDependencyScript,
            collectionInfo[_collectionID].collectionScript
        );
    }

    // function to retrieve the additional data of a Collection
    function retrieveCollectionAdditionalData(uint256 _collectionID)
        public
        view
        returns (address, uint256, uint256, uint256, uint256, address)
    {
        return (
            collectionAdditionalData[_collectionID].collectionArtistAddress,
            collectionAdditionalData[_collectionID].maxCollectionPurchases,
            collectionAdditionalData[_collectionID].collectionCirculationSupply,
            collectionAdditionalData[_collectionID].collectionTotalSupply,
            collectionAdditionalData[_collectionID].setFinalSupplyTimeAfterMint,
            collectionAdditionalData[_collectionID].randomizerContract
        );
    }

    // function to retrieve the token hash
    function retrieveTokenHash(uint256 _tokenid) public view returns (bytes32) {
        return (tokenToHash[_tokenid]);
    }

    // function to retrieve the generative script of a token

    function retrieveGenerativeScript(uint256 tokenId) public view returns (string memory) {
        _requireMinted(tokenId);
        string memory scripttext = "";
        for (
            uint256 i = 0;
            i < collectionInfo[tokenIdsToCollectionIds[tokenId]].collectionScript.length;
            i++
        ) {
            scripttext = string(
                abi.encodePacked(
                    scripttext, collectionInfo[tokenIdsToCollectionIds[tokenId]].collectionScript[i]
                )
            );
        }
        return string(
            abi.encodePacked(
                "let hash='",
                Strings.toHexString(uint256(tokenToHash[tokenId]), 32),
                "';let tokenId=",
                tokenId.toString(),
                ";let tokenData=[",
                tokenData[tokenId],
                "]",
                ";let dependencyScript='",
                retrieveDependencyScript(tokenId),
                "';",
                scripttext
            )
        );
    }

    // function to retrieve on-chain dependency script
    function retrieveDependencyScript(uint256 tokenId) private view returns (string memory) {
        uint256 collectionId = tokenIdsToCollectionIds[tokenId];
        bytes32 dependencyNameAndVersion = collectionInfo[collectionId].collectionDependencyScript;
        uint256 version = collectionDependencyVersions[collectionId];
        string memory scripttext = "";
        for (
            uint256 i = 0;
            i
                < dependencyRegistry.getDependencyScriptCountAtVersion(
                    dependencyNameAndVersion, version
                );
            i++
        ) {
            scripttext = string.concat(
                scripttext,
                dependencyRegistry.getDependencyScriptAtVersion(
                    dependencyNameAndVersion, version, i
                )
            );
        }
        return scripttext;
    }

    /// @notice Returns the typed dependency script content hash pinned for a minted token.
    /// @dev Later registry versions do not change this hash until collection metadata is updated.
    /// @param tokenId Minted token whose collection dependency key should be resolved.
    /// @return The dependency script content hash pinned to the token's collection.
    function retrieveDependencyScriptContentHash(uint256 tokenId) public view returns (bytes32) {
        _requireMinted(tokenId);
        uint256 collectionId = tokenIdsToCollectionIds[tokenId];
        return collectionDependencyContentHashes[collectionId];
    }

    function _requireCollectionNotFrozen(uint256 _collectionID) private view {
        if (collectionFreeze[_collectionID]) {
            revert MetadataFrozen(_collectionID);
        }
    }

    function _requireFreezeEligible(uint256 _collectionID) private view {
        if (collectionFreeze[_collectionID]) {
            revert CollectionAlreadyFrozen(_collectionID);
        }
        if (!isCollectionCreated[_collectionID]) {
            revert CollectionNotCreated(_collectionID);
        }
        if (!wereDataAdded[_collectionID]) {
            revert CollectionDataMissing(_collectionID);
        }

        uint256 endTime = IStreamMinter(minterContract).getEndTime(_collectionID);
        if (endTime == 0 || block.timestamp <= endTime) {
            revert CollectionMintWindowActive(_collectionID, block.timestamp, endTime);
        }

        uint256 finalSupplyTimestamp =
            endTime + collectionAdditionalData[_collectionID].setFinalSupplyTimeAfterMint;
        if (block.timestamp <= finalSupplyTimestamp) {
            revert CollectionFinalSupplyWindowActive(
                _collectionID, block.timestamp, finalSupplyTimestamp
            );
        }

        _requireLiveTokenMetadataFinal(_collectionID);
    }

    function _requireLiveTokenMetadataFinal(uint256 _collectionID) private view {
        uint256 pendingCount = collectionPendingMetadataCounts[_collectionID];
        if (pendingCount != 0) {
            revert CollectionHasPendingTokenMetadata(_collectionID, pendingCount);
        }
    }

    function _addLiveTokenMetadataRecord(uint256 _collectionID, uint256 tokenId) private {
        bytes32 recordHash = _tokenMetadataRecordHash(tokenId);
        tokenFreezeMetadataRecordHashes[tokenId] = recordHash;
        collectionLiveTokenMetadataAccumulators[_collectionID] =
            collectionLiveTokenMetadataAccumulators[_collectionID] ^ uint256(recordHash);

        if (tokenToHash[tokenId] == bytes32(0)) {
            collectionPendingMetadataCounts[_collectionID] =
                collectionPendingMetadataCounts[_collectionID] + 1;
        }
    }

    function _removeLiveTokenMetadataRecord(uint256 _collectionID, uint256 tokenId) private {
        bytes32 recordHash = tokenFreezeMetadataRecordHashes[tokenId];
        collectionLiveTokenMetadataAccumulators[_collectionID] =
            collectionLiveTokenMetadataAccumulators[_collectionID] ^ uint256(recordHash);
        delete tokenFreezeMetadataRecordHashes[tokenId];

        if (
            tokenToHash[tokenId] == bytes32(0)
                && collectionPendingMetadataCounts[_collectionID] != 0
        ) {
            collectionPendingMetadataCounts[_collectionID] =
                collectionPendingMetadataCounts[_collectionID] - 1;
        }
    }

    function _markLiveTokenMetadataFinal(uint256 _collectionID, uint256 tokenId) private {
        if (
            tokenToHash[tokenId] != bytes32(0)
                && collectionPendingMetadataCounts[_collectionID] != 0
        ) {
            collectionPendingMetadataCounts[_collectionID] =
                collectionPendingMetadataCounts[_collectionID] - 1;
        }
    }

    function _refreshLiveTokenMetadataRecord(uint256 _collectionID, uint256 tokenId) private {
        if (!_exists(tokenId)) {
            return;
        }

        bytes32 previousRecordHash = tokenFreezeMetadataRecordHashes[tokenId];
        bytes32 nextRecordHash = _tokenMetadataRecordHash(tokenId);
        if (previousRecordHash == nextRecordHash) {
            return;
        }

        collectionLiveTokenMetadataAccumulators[_collectionID] =
            collectionLiveTokenMetadataAccumulators[_collectionID] ^ uint256(previousRecordHash)
                ^ uint256(nextRecordHash);
        tokenFreezeMetadataRecordHashes[tokenId] = nextRecordHash;
    }

    function _finalizeCollectionSupply(uint256 _collectionID) private {
        uint256 finalSupply = collectionAdditionalData[_collectionID].collectionCirculationSupply;
        uint256 reservedMin = collectionAdditionalData[_collectionID].reservedMinTokensIndex;
        collectionAdditionalData[_collectionID].collectionTotalSupply = finalSupply;
        collectionAdditionalData[_collectionID].reservedMaxTokensIndex =
            finalSupply == 0 ? reservedMin - 1 : reservedMin + finalSupply - 1;
    }

    function _collectionFreezeManifestHash(uint256 _collectionID) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                METADATA_FREEZE_MANIFEST_TYPEHASH,
                _collectionID,
                keccak256(bytes(METADATA_SCHEMA_VERSION)),
                _freezeCollectionStateHash(_collectionID),
                _freezeSupplyStateHash(_collectionID),
                _liveTokenMetadataHash(_collectionID),
                _freezeIntegrationStateHash(_collectionID),
                address(this),
                block.chainid
            )
        );
    }

    function _freezeCollectionStateHash(uint256 _collectionID) private view returns (bytes32) {
        bytes32 dependencyKey = collectionInfo[_collectionID].collectionDependencyScript;
        return keccak256(
            abi.encode(
                _FREEZE_COLLECTION_STATE_TYPEHASH,
                onchainMetadata[_collectionID],
                _collectionInfoHash(_collectionID),
                dependencyKey,
                collectionDependencyVersions[_collectionID],
                collectionDependencyContentHashes[_collectionID],
                _collectionScriptHash(_collectionID)
            )
        );
    }

    function _freezeSupplyStateHash(uint256 _collectionID) private view returns (bytes32) {
        uint256 finalSupply = collectionAdditionalData[_collectionID].collectionCirculationSupply;
        return keccak256(
            abi.encode(
                _FREEZE_SUPPLY_STATE_TYPEHASH,
                finalSupply,
                collectionAdditionalData[_collectionID].collectionCirculationSupply,
                burnAmount[_collectionID]
            )
        );
    }

    function _freezeIntegrationStateHash(uint256 _collectionID) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _FREEZE_INTEGRATION_STATE_TYPEHASH,
                collectionRandomizerEpoch[_collectionID],
                collectionAdditionalData[_collectionID].randomizerContract,
                address(dependencyRegistry)
            )
        );
    }

    function _collectionInfoHash(uint256 _collectionID) private view returns (bytes32) {
        collectionInfoStructure storage info = collectionInfo[_collectionID];
        return keccak256(
            abi.encode(
                _COLLECTION_INFO_TYPEHASH,
                keccak256(bytes(info.collectionName)),
                keccak256(bytes(info.collectionArtist)),
                keccak256(bytes(info.collectionDescription)),
                keccak256(bytes(info.collectionWebsite)),
                keccak256(bytes(info.collectionLicense)),
                keccak256(bytes(info.collectionBaseURI)),
                keccak256(bytes(info.collectionLibrary))
            )
        );
    }

    function _collectionScriptHash(uint256 _collectionID) private view returns (bytes32) {
        string[] storage script = collectionInfo[_collectionID].collectionScript;
        bytes32 chunksHash = bytes32(0);

        for (uint256 i = 0; i < script.length; i++) {
            bytes memory chunk = bytes(script[i]);
            bytes32 chunkHash = keccak256(
                abi.encode(_COLLECTION_SCRIPT_CHUNK_TYPEHASH, i, keccak256(chunk), chunk.length)
            );
            chunksHash = keccak256(abi.encode(chunksHash, chunkHash));
        }

        return keccak256(abi.encode(_COLLECTION_SCRIPT_TYPEHASH, script.length, chunksHash));
    }

    function _liveTokenMetadataHash(uint256 _collectionID) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _LIVE_TOKEN_METADATA_AGGREGATE_TYPEHASH,
                bytes32(collectionLiveTokenMetadataAccumulators[_collectionID]),
                totalSupplyOfCollection(_collectionID)
            )
        );
    }

    function _tokenMetadataRecordHash(uint256 tokenId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                _TOKEN_METADATA_RECORD_TYPEHASH,
                tokenId,
                keccak256(bytes(tokenData[tokenId])),
                keccak256(bytes(tokenImageAndAttributes[tokenId][0])),
                keccak256(bytes(tokenImageAndAttributes[tokenId][1])),
                tokenToHash[tokenId]
            )
        );
    }

    // function to retrieve the supply of a collection
    function totalSupplyOfCollection(uint256 _collectionID) public view returns (uint256) {
        return (collectionAdditionalData[_collectionID].collectionCirculationSupply
                - burnAmount[_collectionID]);
    }

    // function to retrieve the token image uri and the attributes stored on-chain for a token id.
    function retrievetokenImageAndAttributes(uint256 _tokenId)
        public
        view
        returns (string memory, string memory)
    {
        return (tokenImageAndAttributes[_tokenId][0], tokenImageAndAttributes[_tokenId][1]);
    }
}
