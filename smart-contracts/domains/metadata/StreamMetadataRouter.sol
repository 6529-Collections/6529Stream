// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/artist/IStreamCollectionArtistRegistry.sol";
import "../../vendor/openzeppelin/Strings.sol";
import "../../vendor/openzeppelin/Base64.sol";
import "../modules/StreamModuleBase.sol";
import "./StreamMetadataRenderer.sol";

/// @notice Serves current-Core identities and their original coordinator's canonical entropy.
contract StreamMetadataRouter is StreamModuleBase, IStreamMetadataRouter {
    using Strings for uint256;

    struct CollectionMetadata {
        string name;
        string description;
        string image;
        string animationBaseURI;
        string animationScript;
        bool configured;
    }

    struct TokenFacts {
        uint256 tokenId;
        uint256 collectionId;
        uint256 serial;
        bytes32 seed;
        bool finalized;
        string state;
    }

    struct PreparedMetadata {
        string name;
        string description;
        string image;
        string animationBaseURI;
        string animationScript;
    }
    IStreamCore public immutable core;
    address public immutable authority;
    IStreamCollectionArtistRegistry public immutable artistRegistry;
    mapping(uint256 => CollectionMetadata) private _collections;
    mapping(uint256 => PreparedMetadata) private _prepared;
    string private _contractMetadataURI;

    error Unauthorized(address caller);
    error InvalidCore(address supplied);
    error InvalidManifest();
    error InvalidCollection(uint256 collectionId);
    error CollectionFrozen(uint256 collectionId);
    error InvalidToken(uint256 tokenId);
    error MetadataJSONLimitExceeded(uint256 escapedBytes, uint256 maximumBytes);
    event CollectionMetadataConfigured(uint256 indexed collectionId, bytes32 metadataHash);
    event CollectionScriptConfigured(uint256 indexed collectionId, bytes32 scriptHash);
    event ContractMetadataConfigured(bytes32 uriHash);

    constructor(
        address core_,
        address authority_,
        bytes32 deploymentManifestHash,
        string memory manifestURI,
        bytes32 manifestHash,
        IStreamCollectionArtistRegistry artistRegistry_
    )
        StreamModuleBase(
            keccak256("6529stream.metadata-router.schema.v1"),
            address(0),
            deploymentManifestHash,
            manifestURI,
            manifestHash
        )
    {
        if (core_.code.length == 0 || !IERC165(core_).supportsInterface(0x80ac58cd)) revert InvalidCore(core_);
        if (authority_ == address(0) || deploymentManifestHash == 0 || manifestHash == 0) {
            revert InvalidManifest();
        }
        core = IStreamCore(core_);
        authority = authority_;
        if (
            address(artistRegistry_).code.length == 0 || artistRegistry_.core() != core_
                || !artistRegistry_.supportsInterface(
                    type(IStreamCollectionArtistRegistry).interfaceId
                ) || artistRegistry_.supportsInterface(0xffffffff)
        ) revert InvalidManifest();
        artistRegistry = artistRegistry_;
    }

    function streamModuleType() public pure override returns (bytes32) {
        return 0x7024d3e2544fc48a261933c43d901dca0ee3fc26ea2b857748ab0c295a16f20a;
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.metadata-router.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamMetadataRouter).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamMetadataRouter).interfaceId || super.supportsInterface(id);
    }

    function setCollectionMetadata(
        uint256 collectionId,
        string calldata name,
        string calldata description,
        string calldata image,
        string calldata animationBaseURI
    ) external {
        _requireMutable(collectionId);
        StreamMetadataRenderer.requireValidUtf8Bytes("name", name, 256);
        StreamMetadataRenderer.requireValidUtf8Bytes("description", description, 2048);
        StreamMetadataRenderer.requireValidUtf8ContentUri("image", image, 2048, true);
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "animationBaseURI", animationBaseURI, 2048, true
        );
        _prepareCollectionMetadata(collectionId, name, description, image, animationBaseURI);
        CollectionMetadata storage metadata = _collections[collectionId];
        metadata.name = name;
        metadata.description = description;
        metadata.image = image;
        metadata.animationBaseURI = animationBaseURI;
        metadata.configured = true;
        emit CollectionMetadataConfigured(
            collectionId, keccak256(abi.encode(name, description, image, animationBaseURI))
        );
    }

    /// @notice Optional onchain generative script. It receives tokenId, tokenHash and tokenDataBase64.
    /// @dev A stored script takes precedence over the external animation base URI after reveal.
    function setCollectionScript(uint256 collectionId, string calldata script) external {
        _requireMutable(collectionId);
        StreamMetadataRenderer.requireValidUtf8Bytes("animationScript", script, 8192);
        _collections[collectionId].animationScript = script;
        _prepared[collectionId].animationScript = _prepareScript(script);
        emit CollectionScriptConfigured(collectionId, keccak256(bytes(script)));
    }

    function setContractMetadataURI(string calldata uri) external {
        if (msg.sender != authority) revert Unauthorized(msg.sender);
        StreamMetadataRenderer.requireValidUtf8ContentUri("contractURI", uri, 2048, false);
        _contractMetadataURI = uri;
        emit ContractMetadataConfigured(keccak256(bytes(uri)));
        // Configuration can precede Core installation; Core remains the ERC-7572 event source.
        try core.emitContractURIUpdated() { } catch { }
    }

    function collectionMetadata(uint256 collectionId)
        external
        view
        returns (CollectionMetadata memory)
    {
        return _collections[collectionId];
    }

    function tokenURI(address core_, uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        return _dataURI(tokenMetadataJSON(core_, tokenId));
    }

    function tokenMetadataJSON(address core_, uint256 tokenId) public view returns (string memory) {
        _requireCore(core_);
        TokenFacts memory facts = _tokenFacts(tokenId);
        PreparedMetadata storage metadata = _prepared[facts.collectionId];
        bool onchainAnimation = facts.finalized && bytes(metadata.animationScript).length != 0;
        string memory animation = facts.finalized ? _animation(metadata, tokenId, facts.seed) : "";
        bytes memory animationField = bytes(animation).length == 0
            ? bytes("")
            : abi.encodePacked(',"animation_url":"', animation, '"');
        return string(
            abi.encodePacked(
                "{",
                _identityJSON(metadata, facts.collectionId, facts.serial),
                _propertiesJSON(facts, onchainAnimation),
                _artistJSON(facts.collectionId),
                animationField,
                "}"
            )
        );
    }

    function _tokenFacts(uint256 tokenId) private view returns (TokenFacts memory facts) {
        (bool exists, uint256 collectionId, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(tokenId);
        if (!exists || burned || core.tokenLifecycle(tokenId) != uint8(StreamTokenLifecycle.MINTED))
        {
            revert InvalidToken(tokenId);
        }
        address coordinator = core.coordinatorAtMint(tokenId);
        (bytes32 seed, bool finalized) = IStreamEntropyView(coordinator).tokenSeed(tokenId);
        StreamEntropyStatus entropyStatus =
            IStreamEntropyView(coordinator).tokenEntropyStatus(tokenId);
        string memory state = finalized
            ? "final"
            : entropyStatus == StreamEntropyStatus.STALE
                ? "stale"
                : entropyStatus == StreamEntropyStatus.FAILED ? "failed" : "pending";
        return TokenFacts(tokenId, collectionId, serial, seed, finalized, state);
    }

    function _artistJSON(uint256 collectionId) private view returns (bytes memory) {
        IStreamCollectionArtistRegistry.Attribution memory record =
            artistRegistry.attribution(collectionId);
        if (record.artist == address(0)) return ',"artist_attribution":"unaccepted"';
        return abi.encodePacked(
            ',"artist":"',
            uint256(uint160(record.artist)).toHexString(20),
            '","artist_identity_hash":"',
            uint256(record.identityHash).toHexString(32),
            '","artist_acceptance_hash":"',
            uint256(record.acceptanceHash).toHexString(32),
            '"'
        );
    }

    function _identityJSON(PreparedMetadata storage metadata, uint256 collectionId, uint256 serial)
        private
        view
        returns (bytes memory)
    {
        string memory name = _collections[collectionId].configured ? metadata.name : "6529 Stream";
        return abi.encodePacked(
            '"name":"',
            name,
            " #",
            serial.toString(),
            '","description":"',
            metadata.description,
            '","image":"',
            metadata.image,
            '"'
        );
    }

    function _propertiesJSON(TokenFacts memory facts, bool onchainAnimation)
        private
        view
        returns (bytes memory)
    {
        // Final onchain HTML already carries the complete token data. Duplicating its Base64
        // in JSON would exceed Core's bounded response for a valid 16 KiB token payload.
        bytes memory tokenDataField = onchainAnimation
            ? bytes(',"token_data_location":"animation_url:tokenDataBase64"')
            : abi.encodePacked(
                ',"token_data_base64":"', Base64.encode(core.tokenData(facts.tokenId)), '"'
            );
        return abi.encodePacked(
            ',"metadata_schema_version":"6529stream-v1","metadata_state":"',
            facts.state,
            '","token_id":',
            facts.tokenId.toString(),
            ',"collection_id":',
            facts.collectionId.toString(),
            ',"collection_serial":',
            facts.serial.toString(),
            ',"hash":"',
            uint256(facts.seed).toHexString(32),
            '"',
            tokenDataField,
            ',"attributes":[]'
        );
    }

    function _animation(PreparedMetadata storage metadata, uint256 tokenId, bytes32 seed)
        private
        view
        returns (string memory)
    {
        if (bytes(metadata.animationScript).length != 0) {
            string memory script = string(
                abi.encodePacked(
                    "const tokenId=",
                    tokenId.toString(),
                    ";const tokenHash='",
                    uint256(seed).toHexString(32),
                    "';const tokenDataBase64='",
                    Base64.encode(core.tokenData(tokenId)),
                    "';",
                    metadata.animationScript
                )
            );
            // All dynamic values are decimal/hex/Base64 or pre-escaped script. The resulting
            // Base64 data URI has no JSON-sensitive characters and needs no second escape pass.
            return string(
                abi.encodePacked(
                    "data:text/html;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            "<html><head></head><body><script>", script, "</script></body></html>"
                        )
                    )
                )
            );
        }
        if (bytes(metadata.animationBaseURI).length == 0) return "";
        return string(abi.encodePacked(metadata.animationBaseURI, tokenId.toString()));
    }

    function contractURIForCore(address core_) external view override returns (string memory) {
        _requireCore(core_);
        if (bytes(_contractMetadataURI).length != 0) return _contractMetadataURI;
        return _dataURI('{"name":"6529 Stream","description":"6529 Stream NFT collections."}');
    }

    function contractURIForCollection(address core_, uint256 collectionId)
        external
        view
        override
        returns (string memory)
    {
        _requireCore(core_);
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        PreparedMetadata storage metadata = _prepared[collectionId];
        return _dataURI(
            string(
                abi.encodePacked(
                    '{"name":"',
                    metadata.name,
                    '","description":"',
                    metadata.description,
                    '","image":"',
                    metadata.image,
                    '"}'
                )
            )
        );
    }

    function _requireMutable(uint256 collectionId) private view {
        if (msg.sender != authority) revert Unauthorized(msg.sender);
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        if (core.collectionFreezeStatus(collectionId)) revert CollectionFrozen(collectionId);
    }

    function _requireCore(address supplied) private view {
        if (supplied != address(core)) revert InvalidCore(supplied);
    }

    function _dataURI(string memory json) private pure returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function _prepareCollectionMetadata(
        uint256 collectionId,
        string memory name,
        string memory description,
        string memory image,
        string memory animationBaseURI
    ) private {
        // Escape once during configuration. Bounded Core reads must not repeat expensive
        // byte-by-byte escaping; the aggregate cap also preserves Core's 64 KiB return limit.
        name = StreamMetadataRenderer.escapeJsonString(name);
        description = StreamMetadataRenderer.escapeJsonString(description);
        image = StreamMetadataRenderer.escapeJsonString(image);
        uint256 identityBytes = bytes(name).length + bytes(description).length + bytes(image).length;
        if (identityBytes > 5120) revert MetadataJSONLimitExceeded(identityBytes, 5120);
        PreparedMetadata storage prepared = _prepared[collectionId];
        prepared.name = name;
        prepared.description = description;
        prepared.image = image;
        prepared.animationBaseURI = StreamMetadataRenderer.escapeJsonString(animationBaseURI);
    }

    /// @dev Escape the slash of every case-insensitive </script prefix. This preserves the
    /// JavaScript source while preventing an embedded string/comment from ending the HTML tag.
    /// Each disjoint eight-byte match adds one byte; resizing the allocation avoids a copy loop.
    function _prepareScript(string memory raw) internal pure returns (string memory result) {
        bytes memory source = bytes(raw);
        result = new string(source.length + source.length / 8);
        assembly ("memory-safe") {
            let cursor := add(source, 0x20)
            let end := add(cursor, mload(source))
            let output := add(result, 0x20)
            let start := output
            for { } lt(cursor, end) { cursor := add(cursor, 1) } {
                let character := byte(0, mload(cursor))
                if and(
                    iszero(gt(add(cursor, 8), end)),
                    eq(or(shr(192, mload(cursor)), 0x0000202020202020), 0x3c2f736372697074)
                ) {
                    mstore8(output, 0x3c)
                    mstore8(add(output, 1), 0x5c)
                    output := add(output, 2)
                    cursor := add(cursor, 1)
                    character := 0x2f
                }
                mstore8(output, character)
                output := add(output, 1)
            }
            mstore(result, sub(output, start))
        }
    }
}
