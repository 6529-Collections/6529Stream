// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/artist/IStreamCollectionArtistRegistry.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/artist/IStreamArtistContentFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../interfaces/stream/artist/IStreamArtistContentMutationFacts.sol";
import {
    IStreamArtistContentAuthority
} from "../../interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    StreamArtistContentTypes
} from "../../interfaces/stream/artist/StreamArtistContentTypes.sol";
import "../../vendor/openzeppelin/Strings.sol";
import "../../vendor/openzeppelin/Base64.sol";
import "../modules/StreamModuleBase.sol";
import "./StreamMetadataRenderer.sol";

/// @notice Serves current-Core identities and their original coordinator's canonical entropy.
contract StreamMetadataRouter is
    StreamModuleBase,
    IStreamMetadataRouter,
    IStreamArtistContentFacts,
    IStreamArtistContentMutationFacts
{
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

    struct ContentApplication {
        bytes32 consent;
        bytes32 ratification;
    }
    IStreamCore public immutable core;
    address public immutable authority;
    IStreamArtistAttribution public immutable artistRegistry;
    mapping(uint256 => CollectionMetadata) private _collections;
    mapping(uint256 => PreparedMetadata) private _prepared;
    string private _contractMetadataURI;
    mapping(uint256 => mapping(bytes32 => bool)) private _artistContentLocks;
    mapping(uint256 => bytes32) private _evolutionRatification;
    mapping(uint256 => bytes32) private _evolutionContent;
    mapping(bytes32 => bool) public consumedArtistContentConsent;

    bytes32 public constant CONTENT_SCRIPT = keccak256("SCRIPT");
    bytes32 public constant CONTENT_MEDIA = keccak256("MEDIA_MANIFEST");
    bytes32 public constant LOCK_BASE_URI = keccak256("BASE_URI");
    bytes32 public constant LOCK_DEPENDENCIES = keccak256("DEPENDENCIES");

    error Unauthorized(address caller);
    error InvalidCore(address supplied);
    error InvalidManifest();
    error InvalidCollection(uint256 collectionId);
    error CollectionFrozen(uint256 collectionId);
    error InvalidToken(uint256 tokenId);
    error MetadataJSONLimitExceeded(uint256 escapedBytes, uint256 maximumBytes);
    error ArtistContentAuthorizationRequired(uint256 collectionId);
    error UnconfiguredOnchainContent(uint256 collectionId);
    error ArtistRegistryBindingChanged(address selected);
    error ArtistContentLocked(uint256 collectionId, bytes32 lockClass);
    error InvalidArtistContentFreeze(bytes32 recordHash);
    error ArtistContentConsentConsumed(bytes32 recordHash);
    error ArtistContentEvolutionBroken(uint256 collectionId);
    event CollectionMetadataConfigured(uint256 indexed collectionId, bytes32 metadataHash);
    event CollectionScriptConfigured(uint256 indexed collectionId, bytes32 scriptHash);
    event ContractMetadataConfigured(bytes32 uriHash);
    event ArtistContentConsentApplied(
        uint256 indexed collectionId,
        bytes32 indexed familyId,
        bytes32 indexed consentRecordHash,
        bytes32 resultingContentStateHash,
        uint16 schemaVersion
    );
    event CollectionMetadataLocked(
        uint256 indexed collectionId,
        bytes32 indexed lockId,
        address actor,
        uint8 authorityClass,
        bytes32 freezeAuthorizationHash,
        uint16 schemaVersion
    );

    constructor(
        address core_,
        address authority_,
        bytes32 deploymentManifestHash,
        string memory manifestURI,
        bytes32 manifestHash,
        IStreamArtistAttribution artistRegistry_
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
                || !IERC165(address(artistRegistry_))
                    .supportsInterface(type(IStreamArtistAttribution).interfaceId)
                || !IERC165(address(artistRegistry_))
                    .supportsInterface(type(IStreamArtistContentRatification).interfaceId)
                || IERC165(address(artistRegistry_)).supportsInterface(0xffffffff)
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
        return id == type(IStreamMetadataRouter).interfaceId
            || id == type(IStreamArtistContentFacts).interfaceId
            || id == type(IStreamArtistContentMutationFacts).interfaceId
            || super.supportsInterface(id);
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
        ContentApplication memory application =
            _authorizeMediaWrite(collectionId, image, animationBaseURI);
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
        _recordContentApplication(
            collectionId, CONTENT_MEDIA, application.consent, application.ratification
        );
    }

    /// @notice Optional onchain generative script. It receives tokenId, tokenHash and tokenDataBase64.
    /// @dev A stored script takes precedence over the external animation base URI after reveal.
    function setCollectionScript(uint256 collectionId, string calldata script) external {
        _requireMutable(collectionId);
        StreamMetadataRenderer.requireValidUtf8Bytes("animationScript", script, 8192);
        bytes32 consent;
        bytes32 ratification;
        if (
            keccak256(bytes(_collections[collectionId].animationScript)) != keccak256(bytes(script))
        ) {
            _requireContentUnlocked(collectionId, CONTENT_SCRIPT);
            (consent, ratification) = _authorizeContentWrite(
                collectionId, CONTENT_SCRIPT, _scriptState(collectionId, script)
            );
        }
        _collections[collectionId].animationScript = script;
        _prepared[collectionId].animationScript = _prepareScript(script);
        emit CollectionScriptConfigured(collectionId, keccak256(bytes(script)));
        _recordContentApplication(collectionId, CONTENT_SCRIPT, consent, ratification);
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

    /// @notice Exact current-router ONCHAIN content profile for first-release ratification.
    /// @dev Includes the actual linked renderer and content fields, not descriptive records.
    ///      Future content-freeze authorization must use this same versioned state commitment.
    function currentArtistContentState(uint256 collectionId)
        external
        view
        override
        returns (address metadataContract, bytes32 contentStateHash)
    {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        _requireSelectedArtistRegistry();
        CollectionMetadata storage metadata = _collections[collectionId];
        if (!metadata.configured || bytes(metadata.animationScript).length == 0) {
            revert UnconfiguredOnchainContent(collectionId);
        }
        return (address(this), _contentState(collectionId));
    }

    function artistContentFamilyState(uint256 collectionId, bytes32 familyId)
        external
        view
        override
        returns (bool supported, bytes32 currentStateHash)
    {
        _requireContentCollection(collectionId);
        CollectionMetadata storage metadata = _collections[collectionId];
        if (familyId == CONTENT_SCRIPT) {
            return (true, _scriptState(collectionId, metadata.animationScript));
        }
        if (familyId == CONTENT_MEDIA) {
            return (true, _mediaState(collectionId, metadata.image, metadata.animationBaseURI));
        }
        return (false, bytes32(0));
    }

    function artistContentLockState(uint256 collectionId, bytes32 lockClass)
        external
        view
        override
        returns (bool supported, bool locked)
    {
        _requireContentCollection(collectionId);
        // This router has no dependency assignment mutation: its renderer is linked into code.
        if (lockClass == LOCK_DEPENDENCIES) return (true, true);
        supported =
            lockClass == CONTENT_SCRIPT || lockClass == CONTENT_MEDIA || lockClass == LOCK_BASE_URI;
        return (supported, supported && _artistContentLocks[collectionId][lockClass]);
    }

    function artistContentFreezeState(uint256 collectionId)
        external
        view
        override
        returns (bytes32)
    {
        _requireContentCollection(collectionId);
        return _contentState(collectionId);
    }

    function artistContentEvolution(uint256 collectionId)
        external
        view
        override
        returns (bytes32, bytes32)
    {
        _requireContentCollection(collectionId);
        return (_evolutionRatification[collectionId], _evolutionContent[collectionId]);
    }

    /// @notice Exact resulting SCRIPT family commitment for artist consent tooling.
    function previewArtistScriptState(uint256 collectionId, string calldata script)
        external
        view
        returns (bytes32)
    {
        _requireContentCollection(collectionId);
        return _scriptState(collectionId, script);
    }

    /// @notice MEDIA_MANIFEST binds both render-affecting fields changed by setCollectionMetadata.
    function previewArtistMediaState(
        uint256 collectionId,
        string calldata image,
        string calldata animationBaseURI
    ) external view returns (bytes32) {
        _requireContentCollection(collectionId);
        return _mediaState(collectionId, image, animationBaseURI);
    }

    function _requireContentCollection(uint256 collectionId) private view {
        if (!core.collectionExists(collectionId)) revert InvalidCollection(collectionId);
        _requireSelectedArtistRegistry();
    }

    function _contentHostContext(uint256 collectionId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                block.chainid,
                address(core),
                collectionId,
                address(this),
                address(this).codehash,
                address(StreamMetadataRenderer),
                address(StreamMetadataRenderer).codehash
            )
        );
    }

    function _contentState(uint256 collectionId) private view returns (bytes32) {
        CollectionMetadata storage metadata = _collections[collectionId];
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_ONCHAIN_CONTENT_V1"),
                _contentHostContext(collectionId),
                keccak256(bytes(metadata.image)),
                keccak256(bytes(metadata.animationBaseURI)),
                keccak256(bytes(metadata.animationScript))
            )
        );
    }

    function _scriptState(uint256 collectionId, string memory script)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_FAMILY_V1"),
                _contentHostContext(collectionId),
                CONTENT_SCRIPT,
                keccak256(bytes(script))
            )
        );
    }

    function _mediaState(uint256 collectionId, string memory image, string memory baseURI)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_FAMILY_V1"),
                _contentHostContext(collectionId),
                CONTENT_MEDIA,
                keccak256(bytes(image)),
                keccak256(bytes(baseURI))
            )
        );
    }

    /// @notice Anyone may apply the artist's exact, current defensive freeze without editing content.
    function applyArtistContentFreeze(uint256 collectionId, bytes32 freezeRecordHash) external {
        _requireContentCollection(collectionId);
        IStreamArtistContentAuthority authority_ =
            IStreamArtistContentAuthority(address(artistRegistry));
        StreamArtistContentTypes.FreezeRecord memory record =
            authority_.contentFreezeAuthorization(freezeRecordHash);
        if (
            freezeRecordHash == bytes32(0) || record.recordHash != freezeRecordHash
                || record.artistId == bytes32(0) || record.metadataContract != address(this)
                || record.authorityClass == 0 || record.lockClasses.length == 0
                || record.lockClasses.length > 16
                || record.expectedStateHash != _contentState(collectionId)
        ) revert InvalidArtistContentFreeze(freezeRecordHash);
        bytes32 previous;
        for (uint256 i; i < record.lockClasses.length; ++i) {
            bytes32 lockClass = record.lockClasses[i];
            if (
                lockClass <= previous
                    || (lockClass != CONTENT_SCRIPT
                        && lockClass != CONTENT_MEDIA
                        && lockClass != LOCK_BASE_URI
                        && lockClass != LOCK_DEPENDENCIES)
            ) revert InvalidArtistContentFreeze(freezeRecordHash);
            (bool authorized, bytes32 operative) =
                authority_.isContentFreezeAuthorized(collectionId, lockClass);
            if (!authorized || operative != freezeRecordHash) {
                revert InvalidArtistContentFreeze(freezeRecordHash);
            }
            previous = lockClass;
        }
        for (uint256 i; i < record.lockClasses.length; ++i) {
            bytes32 lockClass = record.lockClasses[i];
            if (_artistContentLocks[collectionId][lockClass]) continue;
            _artistContentLocks[collectionId][lockClass] = true;
            emit CollectionMetadataLocked(
                collectionId, lockClass, msg.sender, record.authorityClass, freezeRecordHash, 1
            );
        }
    }

    function _requireContentUnlocked(uint256 collectionId, bytes32 lockClass) private view {
        if (_artistContentLocks[collectionId][lockClass]) {
            revert ArtistContentLocked(collectionId, lockClass);
        }
    }

    function _authorizeMediaWrite(uint256 collectionId, string memory image, string memory baseURI)
        private
        returns (ContentApplication memory application)
    {
        CollectionMetadata storage metadata = _collections[collectionId];
        bool uriChanged = keccak256(bytes(metadata.animationBaseURI)) != keccak256(bytes(baseURI));
        if (keccak256(bytes(metadata.image)) != keccak256(bytes(image)) || uriChanged) {
            _requireContentUnlocked(collectionId, CONTENT_MEDIA);
            if (uriChanged) _requireContentUnlocked(collectionId, LOCK_BASE_URI);
            (application.consent, application.ratification) = _authorizeContentWrite(
                collectionId, CONTENT_MEDIA, _mediaState(collectionId, image, baseURI)
            );
        }
    }

    function _authorizeContentWrite(uint256 collectionId, bytes32 familyId, bytes32 newStateHash)
        private
        returns (bytes32 consent, bytes32 ratification)
    {
        _requireSelectedArtistRegistry();
        (bool ratified, bytes32 ratifiedState, bytes32 record) = IStreamArtistContentRatification(
                address(artistRegistry)
            ).firstReleaseRatification(collectionId);
        if (!ratified) {
            if (
                core.collectionMintedEver(collectionId) == 0
                    || artistRegistry.attribution(collectionId).nominatedArtist == address(0)
            ) return (0, 0);
        } else {
            bytes32 current = _contentState(collectionId);
            if (
                record == bytes32(0)
                    || (current != ratifiedState
                        && (_evolutionRatification[collectionId] != record
                            || _evolutionContent[collectionId] != current))
            ) {
                revert ArtistContentEvolutionBroken(collectionId);
            }
            ratification = record;
        }
        try IStreamArtistContentAuthority(address(artistRegistry))
            .contentConsentEvidence(collectionId, familyId, newStateHash) returns (
            bytes32 evidence
        ) {
            consent = evidence;
        } catch {
            revert ArtistContentAuthorizationRequired(collectionId);
        }
        if (consent == bytes32(0)) revert ArtistContentAuthorizationRequired(collectionId);
        if (consumedArtistContentConsent[consent]) revert ArtistContentConsentConsumed(consent);
        consumedArtistContentConsent[consent] = true;
    }

    function _recordContentApplication(
        uint256 collectionId,
        bytes32 familyId,
        bytes32 consent,
        bytes32 ratification
    ) private {
        if (consent == bytes32(0)) return;
        bytes32 current = _contentState(collectionId);
        if (ratification != bytes32(0)) {
            _evolutionRatification[collectionId] = ratification;
            _evolutionContent[collectionId] = current;
        }
        emit ArtistContentConsentApplied(collectionId, familyId, consent, current, 1);
    }

    function _requireSelectedArtistRegistry() private view {
        (address selected, bytes32 codeHash,,,,,,,,) =
            IStreamCorePointers(address(core)).getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        if (
            selected != address(artistRegistry) || selected.code.length == 0
                || codeHash != selected.codehash
        ) {
            revert ArtistRegistryBindingChanged(selected);
        }
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
