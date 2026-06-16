// SPDX-License-Identifier: MIT

/**
 *
 *  @title Modified version of NextGen 6529 - Core Contract to support 6529 Stream
 *  @custom:date 27-June-2024
 *  @custom:version 10.31
 *  @author 6529 team
 */

pragma solidity ^0.8.19;

import "./ERC721.sol";
import "./IRandomizer.sol";
import "./IStreamAdmins.sol";
import "./IStreamMinter.sol";
import "./IERC2981.sol";
import "./Ownable.sol";
import "./IDependencyRegistry.sol";
import "./IERC4906.sol";
import "./StreamArtistApprovals.sol";
import "./StreamMetadataRenderer.sol";
import "./StreamPauseDomains.sol";

contract StreamCore is ERC721, Ownable, IERC4906, IERC2981 {
    bytes4 private constant _INTERFACE_ID_ERC4906 = 0x49064906;
    address private constant _DEFAULT_ROYALTY_RECEIVER = 0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377;
    uint256 private constant _DEFAULT_ROYALTY_BPS = 690;
    uint256 private constant _ROYALTY_DENOMINATOR = 10_000;
    string public constant METADATA_SCHEMA_VERSION = "6529stream-v1";
    bytes32 private constant _METADATA_SCHEMA_VERSION_HASH =
        0x799ec490674d02b8b6dad75c62eb7bb1673c149887babd257c0c7788841458cd;
    bytes32 public constant METADATA_FREEZE_MANIFEST_TYPEHASH =
        0x152aa4f60074551e7d2a83b144f8cd36ca188861504de0b0852f198e7b2f27ab;
    bytes32 private constant _FREEZE_COLLECTION_STATE_TYPEHASH =
        0xaf81123abfcde0fa006161b3b2dea728514427c0056a84db2147051ed18cb355;
    bytes32 private constant _FREEZE_SUPPLY_STATE_TYPEHASH =
        0xda1e2a648f3fbb2930c575dd0618b9344379ccb4330fd3e46bf418313e2f2c9a;
    bytes32 private constant _FREEZE_INTEGRATION_STATE_TYPEHASH =
        0xb5d297568f5a12c37ca52c3a7336e412123ab86fc93e097596a1f1f6acd075b3;
    bytes32 private constant _COLLECTION_INFO_TYPEHASH =
        0xfee829cb9364f5ed51b7754feab34175a6f70cc276ce81fd31f74fe27e1aac16;
    bytes32 private constant _LIVE_TOKEN_METADATA_AGGREGATE_TYPEHASH =
        0x5c44b5ec16963f52f7b2e846dd70b46242c923fb633a9480bac7ff66698b3dd7;
    string private constant _METADATA_STATE_PENDING = "pending";
    string private constant _METADATA_STATE_STALE = "stale";
    string private constant _METADATA_STATE_FAILED = "failed";
    string private constant _METADATA_STATE_FINAL = "final";
    uint256 private constant _COLLECTION_TOKEN_RANGE = 10 ** 10;
    uint256 private constant _FULL_COLLECTION_UPDATE_INDEX = 10 ** 6;
    uint256 private constant _BASE_URI_UPDATE_INDEX = _FULL_COLLECTION_UPDATE_INDEX - 1;
    uint256 public constant MAX_COLLECTION_TEXT_BYTES = 2_048;
    uint256 public constant MAX_TOKEN_DATA_BYTES = 4_096;
    uint256 public constant MAX_TOKEN_IMAGE_BYTES = 2_048;
    uint256 public constant MAX_TOKEN_ATTRIBUTES_BYTES = 8_192;
    uint256 public constant MAX_COLLECTION_SCRIPT_CHUNK_BYTES = 8_192;
    uint256 public constant MAX_COLLECTION_SCRIPT_CHUNKS = 32;
    uint256 public constant MAX_GENERATED_TOKEN_URI_BYTES = 65_536;

    error CollectionAlreadyFrozen(uint256 collectionId);
    error CollectionDataMissing(uint256 collectionId);
    error CollectionSupplyReached();
    error CollectionSupplyTooLarge();
    error CollectionFinalSupplyWindowActive(
        uint256 collectionId, uint256 currentTimestamp, uint256 finalSupplyTimestamp
    );
    error CollectionHasPendingTokenMetadata(uint256 collectionId, uint256 pendingCount);
    error CollectionMintWindowActive(
        uint256 collectionId, uint256 currentTimestamp, uint256 endTime
    );
    error CollectionNotCreated(uint256 collectionId);
    error ArtistSignatureUnauthorized();
    error BurnedTokenRemintNotAllowed(uint256 tokenId);
    error FunctionAdminUnauthorized();
    error InvalidAdminContract();
    error InvalidDependencyRegistryContract();
    error InvalidMinterContract();
    error InvalidRandomizerContract();
    error InvalidTokenMetadataInput();
    error MetadataMutationPaused();
    error FinalSupplyTimeNotPassed();
    error FrozenCollectionDependencyRegistry();
    error MetadataFieldTooLarge(bytes32 field, uint256 actual, uint256 maximum);
    error MetadataFieldInvalidUTF8(bytes32 field);
    error MetadataFrozen(uint256 collectionId);
    error NotMinterContract();
    error TokenNotMinted();
    error TokenOutsideCollectionRange();
    error UnsafeMetadataURI();
    error UnsafeRawAttributes(uint256 tokenId);
    error UnknownDependency(bytes32 dependencyNameAndVersion);
    error ZeroTokenHash();
    error ERC2981InvalidDefaultRoyalty(uint256 numerator, uint256 denominator);
    error ERC2981InvalidDefaultRoyaltyReceiver(address receiver);
    error ERC2981InvalidTokenRoyalty(uint256 tokenId, uint256 numerator, uint256 denominator);
    error ERC2981InvalidTokenRoyaltyReceiver(uint256 tokenId, address receiver);

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
    mapping(uint256 => IDependencyRegistry) private collectionDependencyRegistries;
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

    // canonical collection state hash approved by the artist signature
    mapping(uint256 => bytes32) public artistApprovalHashes;

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

    struct BurnedTokenAudit {
        bool burned;
        uint256 collectionId;
        address owner;
        address operator;
        uint256 burnedBlock;
        uint256 burnedTimestamp;
        bytes32 postBurnRandomnessHash;
        uint256 postBurnRandomnessBlock;
        uint256 postBurnRandomnessTimestamp;
    }

    // Retained audit state for burned tokens. tokenURI remains unavailable.
    mapping(uint256 => BurnedTokenAudit) private burnedTokenAuditRecords;

    uint256 private _liveTokenSupply;

    // count of frozen collections; used to block global dependency registry swaps
    uint256 private frozenCollectionCount;

    // checks if an artist signed its collection
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
        bytes32 contentHash,
        address registry
    );
    event TokenBurned(
        uint256 indexed _collectionID,
        uint256 indexed _tokenId,
        address indexed operator,
        address owner
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
    }

    // certain functions can only be called by a global or function admin
    modifier FunctionAdminRequired(bytes4 _selector) {
        if (
            !adminsContract.retrieveFunctionAdmin(msg.sender, address(this), _selector)
                && !adminsContract.retrieveGlobalAdmin(msg.sender)
        ) {
            revert FunctionAdminUnauthorized();
        }
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
        StreamMetadataRenderer.requireCollectionInfoLimits(
            _collectionName,
            _collectionArtist,
            _collectionDescription,
            _collectionWebsite,
            _collectionLicense,
            _collectionBaseURI,
            _collectionLibrary,
            _collectionScript
        );
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
        _requireExistingMutableCollection(_collectionID);
        if (_collectionTotalSupply > _COLLECTION_TOKEN_RANGE) {
            revert CollectionSupplyTooLarge();
        }
        collectionAdditonalDataStructure storage collectionData =
            collectionAdditionalData[_collectionID];
        if (collectionData.collectionTotalSupply == 0) {
            if (_collectionTotalSupply == 0) {
                revert CollectionSupplyTooLarge();
            }
            collectionData.collectionArtistAddress = _collectionArtistAddress;
            collectionData.maxCollectionPurchases = _maxCollectionPurchases;
            collectionData.collectionCirculationSupply = 0;
            collectionData.collectionTotalSupply = _collectionTotalSupply;
            collectionData.setFinalSupplyTimeAfterMint = _setFinalSupplyTimeAfterMint;
            collectionData.reservedMinTokensIndex = (_collectionID * _COLLECTION_TOKEN_RANGE);
            collectionData.reservedMaxTokensIndex =
                (_collectionID * _COLLECTION_TOKEN_RANGE) + _collectionTotalSupply - 1;
            wereDataAdded[_collectionID] = true;
        } else {
            collectionData.collectionArtistAddress = _collectionArtistAddress;
            collectionData.maxCollectionPurchases = _maxCollectionPurchases;
            collectionData.setFinalSupplyTimeAfterMint = _setFinalSupplyTimeAfterMint;
        }
    }

    // set a randomizer contract on a collection
    function addRandomizer(uint256 _collectionID, address _randomizerContract)
        public
        FunctionAdminRequired(this.addRandomizer.selector)
    {
        StreamMetadataRenderer.requireContractMarker(
            _randomizerContract,
            IRandomizer.isRandomizerContract.selector,
            InvalidRandomizerContract.selector
        );
        _requireCollectionNotFrozen(_collectionID);
        address oldRandomizer = collectionAdditionalData[_collectionID].randomizerContract;
        if (oldRandomizer != address(0)) {
            uint256 pendingRequests =
                StreamMetadataRenderer.pendingRandomnessRequests(oldRandomizer, _collectionID);
            if (pendingRequests != 0) {
                revert PendingRandomnessRequests(_collectionID, oldRandomizer, pendingRequests);
            }
        }
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
        if (msg.sender != minterContract) {
            revert NotMinterContract();
        }
        _requireCollectionNotFrozen(_collectionID);
        StreamMetadataRenderer.requireTokenData(_tokenData);
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
            revert CollectionSupplyReached();
        }
    }

    // burn function
    function burn(uint256 _collectionID, uint256 _tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _requireCollectionNotFrozen(_collectionID);
        if (
            _tokenId < collectionAdditionalData[_collectionID].reservedMinTokensIndex
                || _tokenId > collectionAdditionalData[_collectionID].reservedMaxTokensIndex
        ) {
            revert TokenOutsideCollectionRange();
        }
        address tokenOwner = ownerOf(_tokenId);
        _removeLiveTokenMetadataRecord(_collectionID, _tokenId);
        burnedTokenAuditRecords[_tokenId] = BurnedTokenAudit({
            burned: true,
            collectionId: _collectionID,
            owner: tokenOwner,
            operator: _msgSender(),
            burnedBlock: block.number,
            burnedTimestamp: block.timestamp,
            postBurnRandomnessHash: bytes32(0),
            postBurnRandomnessBlock: 0,
            postBurnRandomnessTimestamp: 0
        });
        _burn(_tokenId);
        _liveTokenSupply = _liveTokenSupply - 1;
        burnAmount[_collectionID] = burnAmount[_collectionID] + 1;
        emit TokenBurned(_collectionID, _tokenId, _msgSender(), tokenOwner);
    }

    // mint processing
    function _mintProcessing(
        uint256 _mintIndex,
        address _recipient,
        string memory _tokenData,
        uint256 _collectionID,
        uint256 _saltfun_o
    ) internal {
        if (burnedTokenAuditRecords[_mintIndex].burned) {
            revert BurnedTokenRemintNotAllowed(_mintIndex);
        }
        tokenData[_mintIndex] = _tokenData;
        tokenIdsToCollectionIds[_mintIndex] = _collectionID;
        _addLiveTokenMetadataRecord(_collectionID, _mintIndex);
        _liveTokenSupply = _liveTokenSupply + 1;
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
        _requireExistingMutableCollection(_collectionID);
        if (_index == _FULL_COLLECTION_UPDATE_INDEX) {
            StreamMetadataRenderer.requireCollectionInfoLimits(
                _newCollectionName,
                _newCollectionArtist,
                _newCollectionDescription,
                _newCollectionWebsite,
                _newCollectionLicense,
                _newCollectionBaseURI,
                _newCollectionLibrary,
                _newCollectionScript
            );
            collectionInfo[_collectionID].collectionName = _newCollectionName;
            collectionInfo[_collectionID].collectionArtist = _newCollectionArtist;
            collectionInfo[_collectionID].collectionDescription = _newCollectionDescription;
            collectionInfo[_collectionID].collectionWebsite = _newCollectionWebsite;
            collectionInfo[_collectionID].collectionLicense = _newCollectionLicense;
            collectionInfo[_collectionID].collectionBaseURI = _newCollectionBaseURI;
            collectionInfo[_collectionID].collectionLibrary = _newCollectionLibrary;
            collectionInfo[_collectionID].collectionDependencyScript =
            _newCollectionDependencyScript;
            collectionInfo[_collectionID].collectionScript = _newCollectionScript;
            _pinCollectionDependency(_collectionID, _newCollectionDependencyScript);
        } else if (_index == _BASE_URI_UPDATE_INDEX) {
            StreamMetadataRenderer.requireCollectionBaseURI(_newCollectionBaseURI);
            collectionInfo[_collectionID].collectionBaseURI = _newCollectionBaseURI;
        } else {
            StreamMetadataRenderer.requireCollectionScriptChunk(_newCollectionScript[0]);
            collectionInfo[_collectionID].collectionScript[_index] = _newCollectionScript[0];
        }
        _emitCollectionMetadataUpdate(_collectionID);
    }

    // function that is used by artists for signing
    function artistSignature(uint256 _collectionID, string memory _signature) public {
        _recordArtistApproval(
            _collectionID, msg.sender, _signature, _hashArtistApproval(_collectionID)
        );
    }

    // function that records an EIP-712 artist approval signed off-chain
    function artistSignature(
        uint256 _collectionID,
        string memory _signature,
        bytes calldata _artistSignature
    ) public {
        address artist = collectionAdditionalData[_collectionID].collectionArtistAddress;
        bytes32 approvalHash = _hashArtistApproval(_collectionID);
        StreamArtistApprovals.validateSignature(artist, approvalHash, _artistSignature);
        _recordArtistApproval(_collectionID, artist, _signature, approvalHash);
    }

    function _recordArtistApproval(
        uint256 _collectionID,
        address _artist,
        string memory _signature,
        bytes32 _approvalHash
    ) private {
        _requireMetadataMutationNotPaused();
        _requireCollectionNotFrozen(_collectionID);
        if (_artist != collectionAdditionalData[_collectionID].collectionArtistAddress) {
            revert ArtistSignatureUnauthorized();
        }
        if (artistApprovalHashes[_collectionID] == _approvalHash) {
            revert ArtistSignatureUnauthorized();
        }
        artistsSignatures[_collectionID] = _signature;
        artistApprovalHashes[_collectionID] = _approvalHash;
    }

    // function to change the metadata view of a collection
    function changeMetadataView(uint256 _collectionID, bool _status)
        public
        FunctionAdminRequired(this.changeMetadataView.selector)
    {
        _requireMetadataMutationNotPaused();
        _requireExistingMutableCollection(_collectionID);
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
        _requireCollectionNotFrozen(collectionId);
        _requireMinted(_tokenId);
        StreamMetadataRenderer.requireTokenData(newData);
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
        if (_tokenId.length != _images.length || _images.length != _attributes.length) {
            revert InvalidTokenMetadataInput();
        }
        for (uint256 x; x < _tokenId.length; x++) {
            uint256 collectionId = tokenIdsToCollectionIds[_tokenId[x]];
            _requireCollectionNotFrozen(collectionId);
            _requireMinted(_tokenId[x]);
            StreamMetadataRenderer.requireTokenImage(_images[x]);
            StreamMetadataRenderer.requireTokenAttributes(_tokenId[x], _attributes[x]);
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
    // Post-burn timestamps are audit evidence only; they do not gate protocol behavior.
    // slither-disable-start timestamp
    function setTokenHash(uint256 _collectionID, uint256 _mintIndex, bytes32 _hash) external {
        require(msg.sender == collectionAdditionalData[_collectionID].randomizerContract);
        bool burnedToken = _isTokenBurned(_mintIndex);
        if (!burnedToken) {
            _requireCollectionNotFrozen(_collectionID);
        }
        if (_hash == bytes32(0)) {
            revert ZeroTokenHash();
        }
        if (
            _mintIndex < collectionAdditionalData[_collectionID].reservedMinTokensIndex
                || _mintIndex > collectionAdditionalData[_collectionID].reservedMaxTokensIndex
        ) {
            revert TokenOutsideCollectionRange();
        }
        require(tokenToHash[_mintIndex] == bytes32(0));
        bool liveToken = _exists(_mintIndex);
        if (liveToken) {
            if (tokenIdsToCollectionIds[_mintIndex] != _collectionID) {
                revert TokenOutsideCollectionRange();
            }
        } else if (burnedToken) {
            BurnedTokenAudit storage audit = burnedTokenAuditRecords[_mintIndex];
            if (audit.collectionId != _collectionID) {
                revert TokenOutsideCollectionRange();
            }
        }
        tokenToHash[_mintIndex] = _hash;
        // Record pre-mint callbacks, but only live tokens announce metadata changes.
        if (liveToken) {
            _markLiveTokenMetadataFinal(_collectionID, _mintIndex);
            _refreshLiveTokenMetadataRecord(_collectionID, _mintIndex);
            emit MetadataUpdate(_mintIndex);
        } else if (burnedToken) {
            BurnedTokenAudit storage audit = burnedTokenAuditRecords[_mintIndex];
            audit.postBurnRandomnessHash = _hash;
            audit.postBurnRandomnessBlock = block.number;
            audit.postBurnRandomnessTimestamp = block.timestamp;
        }
    }

    // slither-disable-end timestamp

    // function to set final supply, this applies only for unminted collections and will adjust totalSupply = circulatingSupply
    function setFinalSupply(uint256 _collectionID)
        public
        FunctionAdminRequired(this.setFinalSupply.selector)
    {
        _requireExistingMutableCollection(_collectionID);
        if (!wereDataAdded[_collectionID]) {
            revert CollectionDataMissing(_collectionID);
        }
        if (
            block.timestamp
                <= IStreamMinter(minterContract).getEndTime(_collectionID)
                    + collectionAdditionalData[_collectionID].setFinalSupplyTimeAfterMint
        ) {
            revert FinalSupplyTimeNotPassed();
        }
        _finalizeCollectionSupply(_collectionID);
    }

    // function to update the admin, minter or dependency contract
    // 1. admin contract 2. minter contract 3. dependency registry contract
    function updateContracts(uint8 _opt, address _newContract)
        public
        FunctionAdminRequired(this.updateContracts.selector)
    {
        if (_opt == 1) {
            StreamMetadataRenderer.requireContractMarker(
                _newContract, IStreamAdmins.isAdminContract.selector, InvalidAdminContract.selector
            );
            adminsContract = IStreamAdmins(_newContract);
        } else if (_opt == 2) {
            StreamMetadataRenderer.requireContractMarker(
                _newContract,
                IStreamMinter.isMinterContract.selector,
                InvalidMinterContract.selector
            );
            minterContract = _newContract;
        } else if (_opt == 3) {
            if (frozenCollectionCount != 0) {
                revert FrozenCollectionDependencyRegistry();
            }
            if (_newContract.code.length == 0) {
                revert InvalidDependencyRegistryContract();
            }
            dependencyRegistry = IDependencyRegistry(_newContract);
        }
    }

    function _pinCollectionDependency(uint256 _collectionID, bytes32 dependencyNameAndVersion)
        private
    {
        IDependencyRegistry registry = dependencyRegistry;
        uint256 version = 0;
        bytes32 contentHash;
        if (dependencyNameAndVersion == bytes32(0)) {
            contentHash = registry.getDependencyScriptContentHashAtVersion(bytes32(0), version);
        } else {
            version = registry.latestDependencyVersion(dependencyNameAndVersion);
            if (version == 0) {
                revert UnknownDependency(dependencyNameAndVersion);
            }
            contentHash =
                registry.getDependencyScriptContentHashAtVersion(dependencyNameAndVersion, version);
        }
        collectionDependencyRegistries[_collectionID] = registry;
        collectionDependencyVersions[_collectionID] = version;
        collectionDependencyContentHashes[_collectionID] = contentHash;
        emit DependencyVersionPinned(
            _collectionID, dependencyNameAndVersion, version, contentHash, address(registry)
        );
    }

    function _requireMetadataMutationNotPaused() private view {
        StreamMetadataRenderer.requireNotPaused(
            address(adminsContract),
            StreamPauseDomains.METADATA_MUTATION,
            MetadataMutationPaused.selector
        );
    }

    // Retrieve Functions

    // function that overrides supportInterface
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, IERC165)
        returns (bool)
    {
        assembly ("memory-safe") {
            let id := shr(224, interfaceId)
            mstore(
                0x00,
                or(
                    or(eq(id, 0x49064906), eq(id, 0x2a55205a)),
                    or(or(eq(id, 0x80ac58cd), eq(id, 0x5b5e139f)), eq(id, 0x01ffc9a7))
                )
            )
            return(0x00, 0x20)
        }
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        public
        view
        returns (address, uint256)
    {
        assembly ("memory-safe") {
            let numerator := mul(salePrice, 690)
            if and(salePrice, iszero(eq(div(numerator, salePrice), 690))) {
                mstore(0x00, 0x4e487b71)
                mstore(0x20, 0x11)
                revert(0x1c, 0x24)
            }
            mstore(0x00, _DEFAULT_ROYALTY_RECEIVER)
            mstore(0x20, div(numerator, 10000))
            return(0x00, 0x40)
        }
    }

    function totalSupply() public view returns (uint256) {
        return _liveTokenSupply;
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

    // function that return the tokenURI
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        uint256 collectionId = tokenIdsToCollectionIds[tokenId];
        bool finalMetadata = tokenToHash[tokenId] != bytes32(0);

        if (!onchainMetadata[collectionId]) {
            string memory baseURI = collectionInfo[collectionId].collectionBaseURI;
            if (bytes(baseURI).length == 0) {
                return "";
            }
            return StreamMetadataRenderer.offchainTokenURI(
                baseURI, tokenId, _pendingTokenMetadataState(tokenId, collectionId), finalMetadata
            );
        }

        string memory metadataState = finalMetadata
            ? _METADATA_STATE_FINAL
            : _pendingTokenMetadataState(tokenId, collectionId);
        return _onchainTokenURI(tokenId, collectionId, metadataState, finalMetadata);
    }

    /// @notice Returns the active on-chain metadata schema version.
    function metadataSchemaVersion() public pure returns (string memory) {
        return METADATA_SCHEMA_VERSION;
    }

    /// @notice Returns the token's public metadata state under the active schema.
    function tokenMetadataState(uint256 tokenId) public view returns (string memory) {
        _requireMinted(tokenId);
        return tokenToHash[tokenId] != bytes32(0)
            ? _METADATA_STATE_FINAL
            : _pendingTokenMetadataState(tokenId, tokenIdsToCollectionIds[tokenId]);
    }

    function _pendingTokenMetadataState(uint256 tokenId, uint256 collectionId)
        private
        view
        returns (string memory)
    {
        return StreamMetadataRenderer.pendingTokenMetadataState(
            collectionAdditionalData[collectionId].randomizerContract, tokenId
        );
    }

    function _onchainTokenURI(
        uint256 tokenId,
        uint256 collectionId,
        string memory metadataState,
        bool finalMetadata
    ) private view returns (string memory) {
        string memory animationScript = "";
        if (finalMetadata) {
            animationScript = retrieveGenerativeScript(tokenId);
        }

        return StreamMetadataRenderer.onchainTokenURIWithDefaultLimit(
            METADATA_SCHEMA_VERSION,
            metadataState,
            getTokenName(tokenId, collectionId),
            collectionInfo[collectionId].collectionDescription,
            tokenImageAndAttributes[tokenId][0],
            tokenImageAndAttributes[tokenId][1],
            collectionInfo[collectionId].collectionLibrary,
            animationScript,
            finalMetadata
        );
    }

    function _requireMinted(uint256 tokenId) internal view override {
        if (!_exists(tokenId)) revert TokenNotMinted();
    }

    // function to retrieve the name attribute
    function getTokenName(uint256 tokenId, uint256 collectionId)
        private
        view
        returns (string memory)
    {
        return StreamMetadataRenderer.tokenName(
            collectionInfo[collectionId].collectionName,
            tokenId,
            collectionAdditionalData[collectionId].reservedMinTokensIndex
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

    function artistSigned(uint256) external view returns (bool) {
        uint256 collectionID;
        assembly ("memory-safe") {
            collectionID := calldataload(4)
        }
        bytes32 approvalHash = artistApprovalHashes[collectionID];
        bytes32 currentHash = _hashArtistApproval(collectionID);
        assembly ("memory-safe") {
            mstore(0x00, eq(approvalHash, currentHash))
            return(0x00, 0x20)
        }
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
            address(collectionDependencyRegistries[_collectionID])
        );
    }

    // function to return the collection id given a token id
    function viewColIDforTokenID(uint256 _tokenid) public view returns (uint256) {
        return (tokenIdsToCollectionIds[_tokenid]);
    }

    /// @notice Returns true when the token has been burned by this core contract.
    function isTokenBurned(uint256 tokenId) public view returns (bool) {
        return _isTokenBurned(tokenId);
    }

    /// @notice Returns retained audit state for a burned token.
    /// @dev `tokenHash` is the current stored hash and may be recorded before or after burn.
    function burnedTokenAuditState(uint256 tokenId)
        public
        view
        returns (
            bool burned,
            uint256 collectionId,
            address tokenOwner,
            address operator,
            uint256 burnedBlock,
            uint256 burnedTimestamp,
            bytes32 tokenHash,
            bytes32 postBurnRandomnessHash,
            uint256 postBurnRandomnessBlock,
            uint256 postBurnRandomnessTimestamp
        )
    {
        BurnedTokenAudit storage audit = burnedTokenAuditRecords[tokenId];
        burned = audit.burned;
        collectionId = audit.collectionId;
        tokenOwner = audit.owner;
        operator = audit.operator;
        burnedBlock = audit.burnedBlock;
        burnedTimestamp = audit.burnedTimestamp;
        tokenHash = tokenToHash[tokenId];
        postBurnRandomnessHash = audit.postBurnRandomnessHash;
        postBurnRandomnessBlock = audit.postBurnRandomnessBlock;
        postBurnRandomnessTimestamp = audit.postBurnRandomnessTimestamp;
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
        uint256 collectionId = tokenIdsToCollectionIds[tokenId];
        return StreamMetadataRenderer.generativeScriptFromSources(
            tokenToHash[tokenId],
            tokenId,
            tokenData[tokenId],
            collectionDependencyRegistries[collectionId],
            collectionInfo[collectionId].collectionDependencyScript,
            collectionDependencyVersions[collectionId],
            collectionInfo[collectionId].collectionScript
        );
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

    function _requireExistingMutableCollection(uint256 _collectionID) private view {
        if (!isCollectionCreated[_collectionID]) {
            revert CollectionNotCreated(_collectionID);
        }
        _requireCollectionNotFrozen(_collectionID);
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

    function _isTokenBurned(uint256 tokenId) private view returns (bool) {
        return burnedTokenAuditRecords[tokenId].burned;
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
        uint256 reservedMax;
        unchecked {
            reservedMax = finalSupply == 0 ? reservedMin - 1 : reservedMin + finalSupply - 1;
        }
        collectionAdditionalData[_collectionID].collectionTotalSupply = finalSupply;
        collectionAdditionalData[_collectionID].reservedMaxTokensIndex = reservedMax;
    }

    function _collectionFreezeManifestHash(uint256 _collectionID) private view returns (bytes32) {
        bytes32 collectionStateHash = _freezeCollectionStateHash(_collectionID);
        bytes32 supplyStateHash = _freezeSupplyStateHash(_collectionID);
        bytes32 liveTokenMetadataHash = _liveTokenMetadataHash(_collectionID);
        bytes32 integrationStateHash = _freezeIntegrationStateHash(_collectionID);
        bytes32 manifestHash;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, METADATA_FREEZE_MANIFEST_TYPEHASH)
            mstore(add(ptr, 0x20), _collectionID)
            mstore(add(ptr, 0x40), _METADATA_SCHEMA_VERSION_HASH)
            mstore(add(ptr, 0x60), collectionStateHash)
            mstore(add(ptr, 0x80), supplyStateHash)
            mstore(add(ptr, 0xa0), liveTokenMetadataHash)
            mstore(add(ptr, 0xc0), integrationStateHash)
            mstore(add(ptr, 0xe0), address())
            mstore(add(ptr, 0x100), chainid())
            manifestHash := keccak256(ptr, 0x120)
        }
        return manifestHash;
    }

    function _freezeCollectionStateHash(uint256 _collectionID) private view returns (bytes32) {
        bytes32 dependencyKey = collectionInfo[_collectionID].collectionDependencyScript;
        bytes32 typehash = _FREEZE_COLLECTION_STATE_TYPEHASH;
        bool onchain = onchainMetadata[_collectionID];
        bytes32 infoHash = _collectionInfoHash(_collectionID);
        uint256 dependencyVersion = collectionDependencyVersions[_collectionID];
        bytes32 dependencyContentHash = collectionDependencyContentHashes[_collectionID];
        bytes32 scriptHash = StreamMetadataRenderer.collectionScriptHash(
            collectionInfo[_collectionID].collectionScript
        );
        bytes32 stateHash;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, typehash)
            mstore(add(ptr, 0x20), onchain)
            mstore(add(ptr, 0x40), infoHash)
            mstore(add(ptr, 0x60), dependencyKey)
            mstore(add(ptr, 0x80), dependencyVersion)
            mstore(add(ptr, 0xa0), dependencyContentHash)
            mstore(add(ptr, 0xc0), scriptHash)
            stateHash := keccak256(ptr, 0xe0)
        }
        return stateHash;
    }

    function _freezeSupplyStateHash(uint256 _collectionID) private view returns (bytes32) {
        uint256 finalSupply = collectionAdditionalData[_collectionID].collectionCirculationSupply;
        bytes32 typehash = _FREEZE_SUPPLY_STATE_TYPEHASH;
        uint256 burnCount = burnAmount[_collectionID];
        bytes32 stateHash;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, typehash)
            mstore(add(ptr, 0x20), finalSupply)
            mstore(add(ptr, 0x40), finalSupply)
            mstore(add(ptr, 0x60), burnCount)
            stateHash := keccak256(ptr, 0x80)
        }
        return stateHash;
    }

    function _freezeIntegrationStateHash(uint256 _collectionID) private view returns (bytes32) {
        bytes32 typehash = _FREEZE_INTEGRATION_STATE_TYPEHASH;
        uint256 randomizerEpoch = collectionRandomizerEpoch[_collectionID];
        address randomizer = collectionAdditionalData[_collectionID].randomizerContract;
        address dependencyRegistryAddress = address(collectionDependencyRegistries[_collectionID]);
        bytes32 stateHash;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, typehash)
            mstore(add(ptr, 0x20), randomizerEpoch)
            mstore(add(ptr, 0x40), randomizer)
            mstore(add(ptr, 0x60), dependencyRegistryAddress)
            stateHash := keccak256(ptr, 0x80)
        }
        return stateHash;
    }

    function _collectionInfoHash(uint256 _collectionID) private view returns (bytes32) {
        collectionInfoStructure storage info = collectionInfo[_collectionID];
        bytes32 typehash = _COLLECTION_INFO_TYPEHASH;
        bytes32 nameHash = keccak256(bytes(info.collectionName));
        bytes32 artistHash = keccak256(bytes(info.collectionArtist));
        bytes32 descriptionHash = keccak256(bytes(info.collectionDescription));
        bytes32 websiteHash = keccak256(bytes(info.collectionWebsite));
        bytes32 licenseHash = keccak256(bytes(info.collectionLicense));
        bytes32 baseURIHash = keccak256(bytes(info.collectionBaseURI));
        bytes32 libraryHash = keccak256(bytes(info.collectionLibrary));
        bytes32 infoHash;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, typehash)
            mstore(add(ptr, 0x20), nameHash)
            mstore(add(ptr, 0x40), artistHash)
            mstore(add(ptr, 0x60), descriptionHash)
            mstore(add(ptr, 0x80), websiteHash)
            mstore(add(ptr, 0xa0), licenseHash)
            mstore(add(ptr, 0xc0), baseURIHash)
            mstore(add(ptr, 0xe0), libraryHash)
            infoHash := keccak256(ptr, 0x100)
        }
        return infoHash;
    }

    function _liveTokenMetadataHash(uint256 _collectionID) private view returns (bytes32) {
        bytes32 typehash = _LIVE_TOKEN_METADATA_AGGREGATE_TYPEHASH;
        bytes32 accumulator = bytes32(collectionLiveTokenMetadataAccumulators[_collectionID]);
        uint256 liveSupply = collectionAdditionalData[_collectionID].collectionCirculationSupply
            - burnAmount[_collectionID];
        bytes32 stateHash;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, typehash)
            mstore(add(ptr, 0x20), accumulator)
            mstore(add(ptr, 0x40), liveSupply)
            stateHash := keccak256(ptr, 0x60)
        }
        return stateHash;
    }

    function _hashArtistApproval(uint256 _collectionID) private view returns (bytes32) {
        collectionAdditonalDataStructure storage data = collectionAdditionalData[_collectionID];
        return StreamArtistApprovals.hashApprovalDigestForCurrentContract(
            data.collectionArtistAddress,
            _collectionFreezeManifestHash(_collectionID),
            data.maxCollectionPurchases,
            data.collectionTotalSupply,
            data.setFinalSupplyTimeAfterMint
        );
    }

    function _tokenMetadataRecordHash(uint256 tokenId) private view returns (bytes32) {
        return StreamMetadataRenderer.tokenMetadataRecordHash(
            tokenId,
            tokenData[tokenId],
            tokenImageAndAttributes[tokenId][0],
            tokenImageAndAttributes[tokenId][1],
            tokenToHash[tokenId]
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
