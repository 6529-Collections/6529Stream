// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamRendererV1 } from "../../smart-contracts/domains/metadata/StreamRendererV1.sol";
import {
    IStreamCurrentCitationRegistry as TypedCitationRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamCurrentCitationRenderer as TypedCitationRenderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamStaticMetadataSource as Raw
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataSource.sol";
import {
    IStreamRenderer as R
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as V
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamScriptBundles as B
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScriptBundles.sol";
import { ManifestArtistBoundary } from "../unit/metadata/StreamCollectionManifests.t.sol";
import "../unit/metadata/StreamCollectionMetadataV1.t.sol";
import {
    StreamMetadataRouter
} from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";

interface StaticRouteVm {
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract StaticRouteCore is MetadataCoreBoundary {
    address public entropy;
    bool public frozen;
    uint256 public minted;

    function setEntropy(address a) external {
        entropy = a;
    }

    function setFrozen(bool value) external {
        frozen = value;
    }

    function setMinted(uint256 value) external {
        minted = value;
    }

    function collectionFreezeStatus(uint256) external view returns (bool) {
        return frozen;
    }

    function collectionMintedEver(uint256) external view returns (uint256) {
        return minted;
    }

    function collectionSupplyMode(uint256) external pure returns (uint8) {
        return 0;
    }

    function collectionStatus(uint256) external pure returns (uint8) {
        return 0;
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return entropy;
    }

    function tokenData(uint256) external pure returns (bytes memory) {
        return hex"00ff6529";
    }
}

contract StaticRouteEntropy {
    bool public finalized = true;

    function setFinalized(bool value) external {
        finalized = value;
    }

    function staticTokenRenderFacts(uint256) external view returns (uint8, bytes32, address) {
        return (
            finalized ? 5 : 4,
            finalized ? keccak256("real boundary seed") : bytes32(0),
            address(this)
        );
    }

    function tokenSeed(uint256) external view returns (bytes32, bool) {
        return (keccak256("real boundary seed"), finalized);
    }

    function tokenEntropy(uint256)
        external
        view
        returns (uint8, bytes32, address, uint32, bytes32, bytes32, uint256, uint16)
    {
        return (
            finalized ? 5 : 4,
            finalized ? keccak256("real boundary seed") : bytes32(0),
            address(this),
            1,
            0,
            0,
            0,
            0
        );
    }
}

/// @dev Explicit source-role boundary; the genuine full AA-DISPLAY transport is a separate source suite.
contract StaticRouteAttribution {
    address public core;
    address public router;
    bool public fail;
    string public state = "disputed";

    constructor(address c, address r) {
        core = c;
        router = r;
    }

    function setFail(bool value) external {
        fail = value;
    }

    function attribution(uint256, uint256) external view returns (bytes memory) {
        require(!fail);
        return abi.encodePacked('{"state":"', state, '"}');
    }
}

/// @dev Explicit typed admission boundary, never a real Registry/analysis/golden proof.
/// Original admission is constructor-bound; current callers must opt in separately.
contract StaticRouteVersions {
    address private immutable boundaryController = msg.sender;
    address public governanceAuthority;
    address public schemaRegistry;
    V.Registration private registered;
    V.Version private saved;
    bytes32 public key;
    bool public currentCitationBoundaryEnabled;
    address private currentEncoding;
    bytes32 private currentEncodingHash;

    constructor(address executor, address schemas, address renderer) {
        governanceAuthority = executor;
        schemaRegistry = schemas;
        registered.renderer = renderer;
        registered.manifest = R(renderer).rendererManifest();
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_VERSION_V1"),
                registered.manifest.rendererId,
                registered.manifest.rendererVersion
            )
        );
        saved = V.Version(
            true,
            false,
            renderer,
            renderer.codehash,
            keccak256("registered original"),
            keccak256("declared reads"),
            keccak256("analysis"),
            keccak256("golden"),
            keccak256("action")
        );
    }

    function version(bytes32 k) external view returns (V.Version memory) {
        require(k == key);
        return saved;
    }

    function registration(bytes32 k) external view returns (V.Registration memory) {
        require(k == key);
        return registered;
    }

    function requireAssignable(bytes32 k) external view returns (address, bytes32) {
        require(k == key && !saved.deprecated);
        return (saved.renderer, saved.runtimeHash);
    }

    function requireRetained(bytes32 k) external view returns (address, bytes32) {
        require(k == key);
        return (saved.renderer, saved.runtimeHash);
    }

    function optInCurrentCitationBoundary(bytes32 profile, bytes4 selector, bytes32 runtime)
        external
    {
        require(
            msg.sender == boundaryController && !currentCitationBoundaryEnabled,
            "explicit one-time fixture opt-in"
        );
        if (
            profile != keccak256("6529STREAM_CURRENT_BASE_CITATION_V1")
                || selector != TypedCitationRenderer.renderCurrent.selector
                || runtime != saved.runtimeHash || runtime != saved.renderer.codehash
                || !StreamRendererV1(saved.renderer)
                    .supportsInterface(type(TypedCitationRenderer).interfaceId)
                || TypedCitationRenderer(saved.renderer).currentCitationProfile() != profile
        ) revert TypedCitationRegistry.InvalidCurrentCitation();
        (currentEncoding, currentEncodingHash) =
            TypedCitationRenderer(saved.renderer).encodingBinding();
        require(
            currentEncoding.code.length != 0 && currentEncoding.codehash == currentEncodingHash,
            "exact fixed encoder boundary"
        );
        currentCitationBoundaryEnabled = true;
    }

    function requireCurrentCitation(bytes32 k)
        external
        view
        virtual
        returns (address, bytes32, bytes32, bytes4)
    {
        if (
            k != key || !currentCitationBoundaryEnabled
                || saved.renderer.codehash != saved.runtimeHash
                || currentEncoding.codehash != currentEncodingHash
        ) revert TypedCitationRegistry.CurrentCitationUnavailable(k);
        return (
            saved.renderer,
            saved.runtimeHash,
            keccak256("6529STREAM_CURRENT_BASE_CITATION_V1"),
            TypedCitationRenderer.renderCurrent.selector
        );
    }

    function deprecate() external {
        saved.deprecated = true;
    }
}

contract StaticRouteModules {
    address public metadata;
    address public versions;
    bool public enabled = true;

    constructor(address m, address v) {
        metadata = m;
        versions = v;
    }

    function setEnabled(bool value) external {
        enabled = value;
    }

    function isModuleEligible(address a, bytes32 kind, bytes4 id) external view returns (bool) {
        return enabled
            && ((a == metadata
                    && kind == keccak256("COLLECTION_METADATA")
                    && id == type(IStreamCollectionMetadataV1).interfaceId)
                || (a == versions
                    && kind == keccak256("RENDERER_REGISTRY")
                    && id == type(V).interfaceId));
    }
}

/// @notice Actual Router/Renderer/Metadata/Schema/SSTORE2 and threshold Safe; typed source boundaries named above.
/// @dev Authored only until executed. These cases are not current-Core mint, true Artist, registry static-analysis,
/// finality, or transitive source conformance acceptance. The actual registry mechanics have a separate suite.
abstract contract StaticMetadataRoutingFixture is CharacterizationTestBase, OfficialSafeFixture {
    StaticRouteCore internal core;
    StaticRouteEntropy internal entropy;
    ManifestArtistBoundary internal artist;
    MetadataExecutorBoundary internal executor;
    StreamSchemaRegistry internal schemas;
    StreamCollectionMetadataV1 internal metadata;
    StreamMetadataRouter internal router;
    StreamRendererV1 internal renderer;
    StaticRouteAttribution internal attribution;
    StaticRouteVersions internal versions;
    StaticRouteModules internal modules;
    bytes32 internal constant FAMILY = keccak256("RENDERER_CONFIG");

    function setUp() public virtual {
        core = new StaticRouteCore();
        entropy = new StaticRouteEntropy();
        core.setEntropy(address(entropy));
        executor = new MetadataExecutorBoundary();
        artist = new ManifestArtistBoundary(address(core));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(artist));
        router = new StreamMetadataRouter(
            address(core),
            address(executor),
            keccak256("deployment"),
            "ipfs://router",
            keccak256("manifest"),
            IStreamArtistAttribution(address(artist))
        );
        artist.setRouter(address(router));
        core.setPointer(keccak256("METADATA_ROUTER"), address(router));
        schemas = new StreamSchemaRegistry(address(executor));
        StreamCollectionMetadataV1.Configuration memory mc;
        mc.core = address(core);
        mc.executor = address(executor);
        mc.schemas = address(schemas);
        mc.artistRegistry = address(artist);
        mc.deploymentManifestHash = keccak256("deployment");
        mc.manifestHash = keccak256("metadata");
        mc.manifestURI = "ipfs://metadata";
        mc.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        mc.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(mc);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        _admin(
            abi.encodeCall(
                router.setCollectionMetadata, (1, "Static work", "Exact source", "ipfs://image", "")
            )
        );
        _admin(
            abi.encodeCall(router.setCollectionScript, (1, "document.body.textContent = tokenId;"))
        );
        attribution = new StaticRouteAttribution(address(core), address(router));
        StreamRendererV1.Deployment memory d;
        d.executor = address(executor);
        d.sources = StreamRendererV1.Sources(
            address(core),
            address(router),
            address(metadata),
            address(entropy),
            address(0),
            address(attribution)
        );
        d.readGas = mc.dependencyReadGas;
        d.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        d.manifest = R.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256("schema"),
            "ipfs://schema",
            "ipfs://renderer",
            keccak256("manifest"),
            16777216,
            16777216,
            false
        );
        renderer = new StreamRendererV1(d);
        versions = new StaticRouteVersions(address(executor), address(schemas), address(renderer));
        modules = new StaticRouteModules(address(metadata), address(versions));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(modules));
        _grant(address(this), 8);
    }

    function _activate() internal {
        bytes32 key = router.setDefaultMetadataConfig(_input(R.MetadataMode.ONCHAIN, false));
        router.activateStaticMetadata(1, key);
    }

    /// @dev Opt in only in tests intentionally using current output. No registry evidence is fabricated.
    function _optInCurrentCitationAdmissionBoundary() internal {
        versions.optInCurrentCitationBoundary(
            keccak256("6529STREAM_CURRENT_BASE_CITATION_V1"),
            TypedCitationRenderer.renderCurrent.selector,
            address(renderer).codehash
        );
    }

    function _mint() internal {
        core.setToken(91, address(this), 2);
        core.setMinted(1);
    }

    function _input(R.MetadataMode mode, bool frozen)
        internal
        view
        returns (S.ConfigInput memory input)
    {
        input.registry = address(versions);
        input.versionKey = versions.key();
        input.config = R.MetadataConfig(
            mode,
            address(renderer),
            mode == R.MetadataMode.ONCHAIN ? "" : "https://example.test/",
            "",
            R.OffchainURIIdMode.TOKEN_ID,
            frozen
        );
    }

    function _approve(uint256 token, S.ConfigInput memory input, bytes32 evidence) internal {
        artist.approve(1, FAMILY, router.previewStaticMetadataConfig(1, token, input), evidence);
    }

    function _admin(bytes memory data) internal {
        executor.execute(address(router), data, 0, 0, 0);
    }

    function _grant(address who, uint8 kind) internal {
        (bytes32 scope, bytes32 oldHash, bytes32 next) = metadata.familyWriterTransition(
            0, keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1"), kind, who, true
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter,
                (0, keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1"), kind, who, true)
            ),
            scope,
            oldHash,
            next
        );
    }

    function _has(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i; i <= h.length - n.length; ++i) {
            bool match_ = true;
            for (uint256 j; j < n.length; ++j) {
                if (h[i + j] != n[j]) {
                    match_ = false;
                    break;
                }
            }
            if (match_) return true;
        }
        return false;
    }
}
