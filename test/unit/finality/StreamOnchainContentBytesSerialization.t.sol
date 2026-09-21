// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamOnchainContentBytes as Matcher
} from "../../../smart-contracts/domains/finality/StreamOnchainContentBytes.sol";
import {
    StreamMetadataTokenRenderer as Renderer
} from "../../../smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol";
import {
    StreamMetadataBundleRenderer as Bundle
} from "../../../smart-contracts/domains/metadata/StreamMetadataBundleRenderer.sol";
import {
    StreamMetadataDisplayParameters as DisplayGas
} from "../../../smart-contracts/domains/metadata/StreamMetadataDisplayParameters.sol";
import {
    StreamArtistDisplayJSON as DisplayJSON
} from "../../../smart-contracts/domains/metadata/StreamArtistDisplayJSON.sol";
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import {
    StreamMetadataRenderTypes as T
} from "../../../smart-contracts/interfaces/stream/metadata/StreamMetadataRenderTypes.sol";
import {
    IStreamMetadataServingFacts as F
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamScriptBundles as B
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamArtistAttribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    StreamMetadataRouterRendering as Serving
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouterRendering.sol";
import {
    StreamMetadataRecoveryRoutes as Recovery
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveryRoutes.sol";
import { Base64 } from "../../../smart-contracts/vendor/openzeppelin/Base64.sol";
import { Strings } from "../../../smart-contracts/vendor/openzeppelin/Strings.sol";
import {
    CharacterizationTestBase
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    PresentationCoreBoundary,
    PresentationArtistBoundary,
    PresentationEntropyBoundary
} from "../metadata/StreamMetadataServing.t.sol";

/// @dev Typed immutable two-chunk read boundary. Bundle reconstruction/serialization is production.
/// This does not claim actual Metadata record admission or chunk-storage acceptance.
contract ContentMatcherTwoChunkSource {
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(B).interfaceId || id == 0x01ffc9a7;
    }

    function recordedScriptBundle(bytes32 manifest) external pure returns (bytes32) {
        require(manifest == bytes32(uint256(2)), "fixture manifest");
        return bytes32(uint256(1));
    }

    function scriptBundle(bytes32 id) external pure returns (B.Facts memory) {
        require(id == bytes32(uint256(1)), "fixture bundle");
        return B.Facts(
            keccak256("window.art=1;"), 0, 13, 2, M.PayloadSourceType.INLINE_CHUNKS, false, true
        );
    }

    function scriptBundleChunk(bytes32 id, uint256 index) external pure returns (bytes memory) {
        require(id == bytes32(uint256(1)) && index < 2, "fixture chunk");
        return index == 0 ? bytes("window.") : bytes("art=1;");
    }
}

/// @dev Explicit storage/selection/live-frame boundary calling the actual Router serving library.
/// No Router configuration authority or Metadata record admission is claimed by these assignments.
contract ContentMatcherHistoricalBundleServing {
    mapping(uint256 => StreamMetadataRouter.PreparedMetadata) private prepared;
    mapping(uint256 => StreamMetadataRouter.CollectionMetadata) private collections;
    mapping(uint256 => F.ArtistPresentation) private presentations;
    mapping(uint256 => Recovery.OriginalAnchor) private anchors;
    mapping(uint256 => mapping(uint8 => M.Selection)) private selections;
    Serving.Context private context;

    constructor(
        address core,
        PresentationArtistBoundary artist,
        ContentMatcherTwoChunkSource source
    ) {
        DisplayGas.initialize(msg.sender);
        F.ServingSource memory metadata = Renderer.prepareMetadata(
            "Matcher", 'Quoted "animation_url":"decoy","properties":{}', "", ""
        );
        prepared[1] = StreamMetadataRouter.PreparedMetadata(
            metadata.name, metadata.description, metadata.imageURI, metadata.animationBaseURI, ""
        );
        collections[1].configured = true;
        selections[1][2] =
            M.Selection(address(source), address(source).codehash, bytes32(uint256(2)));
        address original = artist.finalityRegistry();
        context = Serving.Context(
            core,
            address(artist),
            address(artist).codehash,
            Recovery.OriginalAnchor(original, original.codehash)
        );
    }

    function historicalFullJSON() external view returns (string memory) {
        return Serving.serve(
            prepared, collections, presentations, anchors, selections, context, 91, true, 4
        );
    }

    function currentFullJSON() external view returns (string memory) {
        return Serving.serve(
            prepared, collections, presentations, anchors, selections, context, 91, true, 2
        );
    }

    function liveAttributionObject(uint256 collection, uint256 token)
        external
        pure
        returns (bytes memory)
    {
        require(collection == 1 && token == 91, "typed live attribution scope");
        return DisplayJSON.unavailable();
    }

    function setSelectionCodeHash(bytes32 codeHash) external {
        selections[1][2].codeHash = codeHash;
    }
}

/// @notice Historical Router serialization remains compatible with the original content matchers.
/// @dev Current citation output is a distinct profile. The unchanged suffix matcher is not a JSON
/// parser and makes no claim to reject duplicate fields in the preceding JSON prefix.
/// Core/Artist/entropy and bundle source are explicit typed boundaries, not a current-stack flow.
/// All positive JSON comes from real renderers; expected HTML is independent of their output.
/// Authored against the historical-dispatch repair; compilation and runtime remain pending.
contract StreamOnchainContentBytesSerializationTest is CharacterizationTestBase {
    using Strings for uint256;

    address private constant ORIGINAL_CORE = address(0xC0DE);
    uint256 private constant ORIGINAL_CHAIN = 31337;

    struct Sample {
        bytes json;
        bytes html;
        bool full;
    }

    function testLockedHistoricalCompactPreservesLegacyWhileCurrentTokenURIKeepsCitation() public {
        (StreamMetadataRouter router, PresentationCoreBoundary core) = _router(true);
        bytes memory historical = bytes(router.historicalTokenMetadataJSON(address(core), 91));
        _assertOriginal(historical, false, true);
        bytes memory current = bytes(router.tokenMetadataJSON(address(core), 91));
        require(
            keccak256(bytes(router.tokenURI(address(core), 91)))
                == keccak256(
                    abi.encodePacked("data:application/json;base64,", Base64.encode(current))
                ),
            "actual current tokenURI contains exact current JSON"
        );
        _assertFinalCitation(current, block.chainid, address(core));
        _assertAnimationValue(current, _html());
        require(
            keccak256(current) != keccak256(historical),
            "current and original profiles remain distinct"
        );
        require(
            !Matcher.matchesAnimation(current, _html()),
            "original matcher does not silently accept current citation tail"
        );
    }

    function testLiveHistoricalCompactUsesOriginalNestedArtistWrapper() public {
        (StreamMetadataRouter router, PresentationCoreBoundary core) = _router(false);
        bytes memory historical = bytes(router.historicalTokenMetadataJSON(address(core), 91));
        _assertOriginal(historical, false, false);
        require(
            keccak256(
                bytes(
                    abi.decode(
                        vm.parseJson(
                            string(historical), ".properties.provenance.attribution.state"
                        ),
                        (string)
                    )
                )
            ) == keccak256("attribution_unavailable"),
            "actual bounded live diagnostic retains original nested wrapper"
        );
        _assertFinalCitation(
            bytes(router.tokenMetadataJSON(address(core), 91)), block.chainid, address(core)
        );
    }

    function testLockedHistoricalFullPreservesOriginalDataAndCurrentFullKeepsCitation() public {
        (StreamMetadataRouter router, PresentationCoreBoundary core) = _router(true);
        bytes memory historical = bytes(router.historicalFullTokenMetadataJSON(address(core), 91));
        _assertOriginal(historical, true, true);
        bytes memory current = bytes(router.tokenJSON(91));
        _assertFinalCitation(current, block.chainid, address(core));
        _assertAnimationValue(current, _html());
        require(
            keccak256(current) != keccak256(historical),
            "current full citation is additive only to current profile"
        );
        require(
            !Matcher.matchesFullAnimation(current, _html(), hex"00ff6529"),
            "original full matcher retains exact historical suffix"
        );
    }

    function testLiveHistoricalFullUsesExactOriginalWrapperAndFinalitySelector() public {
        (StreamMetadataRouter router, PresentationCoreBoundary core) = _router(false);
        bytes memory historical = bytes(router.historicalFullTokenMetadataJSON(address(core), 91));
        _assertOriginal(historical, true, false);
        (T.Token memory token, F.ServingSource memory source) = _input();
        bytes memory artist = DisplayJSON.nested(DisplayJSON.unavailable());
        require(
            keccak256(historical)
                == keccak256(
                    bytes(Renderer.fullViewForFinality(false, abi.encode(token, source, artist)))
                ),
            "actual historical full JSON equals unchanged original finality serializer"
        );
        // The original full serializer adds its final render-state properties after the
        // original nested Artist wrapper. Exact bytes, not a generic duplicate-key rule, own this profile.
        _assertFinalCitation(bytes(router.tokenJSON(91)), block.chainid, address(core));
    }

    function testTwoChunkOriginalFullAndCurrentCitationFormatsRemainDistinct() public {
        DisplayGas.initialize(address(this));
        ContentMatcherTwoChunkSource host = new ContentMatcherTwoChunkSource();
        B.Selection memory selection = B.Selection(
            address(host), address(host).codehash, bytes32(uint256(1)), bytes32(uint256(2))
        );
        (T.Token memory token, F.ServingSource memory source) = _input();
        source.script = "";
        bytes memory artist = DisplayJSON.nested(DisplayJSON.unavailable());
        bytes memory original = bytes(
            Bundle.render(2, token, source, artist, selection, address(this), ORIGINAL_CHAIN)
        );
        bytes memory archived = bytes(
            Bundle.renderBundleForFinality(
                2,
                abi.encode(
                    token,
                    source,
                    artist,
                    selection,
                    address(this),
                    ORIGINAL_CHAIN,
                    uint256(2000000)
                )
            )
        );
        require(
            keccak256(original) == keccak256(archived),
            "unchanged original bundle finality selector"
        );
        _assertOriginal(original, true, false);
        _assertHistoricalBundleDispatch(host, original);
        bytes memory current = bytes(
            Bundle.renderCurrent(
                2,
                token,
                source,
                DisplayJSON.unavailable(),
                true,
                selection,
                address(this),
                ORIGINAL_CHAIN,
                ORIGINAL_CORE
            )
        );
        _assertFinalCitation(current, ORIGINAL_CHAIN, ORIGINAL_CORE);
        _assertAnimationValue(current, _html());
        require(
            !Matcher.matchesFullAnimation(current, _html(), token.tokenData),
            "current bundle citation is a separate profile"
        );
        bytes memory compact = bytes(
            Bundle.render(0, token, source, artist, selection, address(this), ORIGINAL_CHAIN)
        );
        require(
            !Matcher.matchesAnimation(compact, _html()),
            "compact bundle reference has no inline animation field"
        );
        bytes memory explicitFullHTML = bytes(
            Bundle.render(3, token, source, artist, selection, address(this), ORIGINAL_CHAIN)
        );
        require(
            keccak256(explicitFullHTML) != keccak256(_html()),
            "explicit full HTML carries a render-state marker"
        );
        require(
            !Matcher.matchesFullAnimation(original, explicitFullHTML, token.tokenData),
            "original suffix binds embedded animation bytes"
        );
    }

    function testCorruptedTruncatedAndExtendedHTMLFailHistoricalCompactAndFull() public {
        Sample[] memory samples = _historicalSamples();
        for (uint256 i; i < samples.length; ++i) {
            Sample memory s = samples[i];
            require(_matches(s), "healthy historical profile before corruption");
            bytes memory original = s.html;
            s.html = _corrupt(original);
            require(!_matches(s), "same-length corrupted HTML");
            s.html = _slice(original, 0, original.length - 1);
            require(!_matches(s), "truncated HTML");
            s.html = bytes.concat(original, hex"00");
            require(!_matches(s), "extended HTML");
            s.html = original;
            require(_matches(s), "same original HTML remains accepted");
        }
    }

    function testHistoricalFullRequiresExactTokenDataForLockedAndLiveArtist() public {
        Sample[] memory samples = _historicalSamples();
        for (uint256 i; i < samples.length; ++i) {
            if (!samples[i].full) continue;
            Sample memory s = samples[i];
            require(_matches(s), "healthy historical full before token mutation");
            require(
                !Matcher.matchesFullAnimation(s.json, s.html, hex"01ff6529"),
                "same-length wrong token data"
            );
            require(
                !Matcher.matchesFullAnimation(s.json, s.html, hex"00ff65"), "truncated token data"
            );
            require(
                !Matcher.matchesFullAnimation(s.json, s.html, hex"00ff652900"),
                "extended token data"
            );
            require(!Matcher.matchesFullAnimation(s.json, s.html, ""), "empty token data");
            require(_matches(s), "original token data still accepted");
        }
    }

    function testFieldsOrBytesAfterHistoricalTailAreNotOriginalSerialization() public {
        Sample[] memory samples = _historicalSamples();
        for (uint256 i; i < samples.length; ++i) {
            Sample memory s = samples[i];
            require(_matches(s), "healthy historical profile before tail mutation");
            bytes memory original = s.json;
            s.json = bytes.concat(_slice(original, 0, original.length - 1), bytes(',"extra":true}'));
            require(!_matches(s), "field after canonical suffix");
            s.json = bytes.concat(original, bytes(" "));
            require(!_matches(s), "trailing whitespace changes exact suffix");
            s.json = bytes.concat(original, bytes("{}"));
            require(!_matches(s), "trailing JSON object");
            s.json = bytes.concat(original, hex"00");
            require(!_matches(s), "trailing zero byte");
            s.json = _slice(original, 0, original.length - 1);
            require(!_matches(s), "truncated closing brace");
            s.json = original;
            require(_matches(s), "original survives tail checks");
        }
    }

    function _assertHistoricalBundleDispatch(
        ContentMatcherTwoChunkSource source,
        bytes memory original
    ) private {
        PresentationCoreBoundary core = new PresentationCoreBoundary();
        PresentationArtistBoundary artist = new PresentationArtistBoundary(address(core));
        PresentationEntropyBoundary entropy = new PresentationEntropyBoundary();
        core.configure(address(artist), address(entropy));
        ContentMatcherHistoricalBundleServing serving =
            new ContentMatcherHistoricalBundleServing(address(core), artist, source);
        Recovery.Pointer memory pointer;
        pointer.target = address(source);
        pointer.codeHash = address(source).codehash;
        pointer.status = 1;
        pointer.revision = 1;
        core.setRecoveryPointer(keccak256("COLLECTION_METADATA"), pointer);
        pointer.target = address(serving);
        pointer.codeHash = address(serving).codehash;
        core.setRecoveryPointer(keccak256("METADATA_ROUTER"), pointer);
        bytes memory actual = bytes(serving.historicalFullJSON());
        require(
            keccak256(actual) == keccak256(original),
            "changed historical bundle dispatch uses original serializer"
        );
        _assertOriginal(actual, true, false);
        bytes memory current = bytes(serving.currentFullJSON());
        _assertFinalCitation(current, block.chainid, address(core));
        require(
            !Matcher.matchesFullAnimation(current, _html(), hex"00ff6529"),
            "same serving library preserves distinct current bundle profile"
        );

        serving.setSelectionCodeHash(bytes32(uint256(1)));
        vm.expectRevert(abi.encodeWithSelector(Bundle.InvalidBundleRendering.selector));
        serving.historicalFullJSON();
        serving.setSelectionCodeHash(address(source).codehash);
        require(
            keccak256(bytes(serving.historicalFullJSON())) == keccak256(original),
            "saved source codehash repair restores same output"
        );

        pointer.target = address(source);
        pointer.codeHash = bytes32(uint256(1));
        core.setRecoveryPointer(keccak256("COLLECTION_METADATA"), pointer);
        vm.expectRevert(abi.encodeWithSelector(Bundle.InvalidBundleRendering.selector));
        serving.historicalFullJSON();
        pointer.codeHash = address(source).codehash;
        core.setRecoveryPointer(keccak256("COLLECTION_METADATA"), pointer);
        require(
            keccak256(bytes(serving.historicalFullJSON())) == keccak256(original),
            "current Metadata pointer repair restores same output"
        );

        pointer.target = address(this);
        pointer.codeHash = address(this).codehash;
        core.setRecoveryPointer(keccak256("METADATA_ROUTER"), pointer);
        vm.expectRevert(abi.encodeWithSelector(Bundle.InvalidBundleRendering.selector));
        serving.historicalFullJSON();
        pointer.target = address(serving);
        pointer.codeHash = address(serving).codehash;
        core.setRecoveryPointer(keccak256("METADATA_ROUTER"), pointer);
        require(
            keccak256(bytes(serving.historicalFullJSON())) == keccak256(original),
            "current Router pointer repair restores same output"
        );
    }

    function _router(bool locked)
        private
        returns (StreamMetadataRouter router, PresentationCoreBoundary core)
    {
        core = new PresentationCoreBoundary();
        PresentationArtistBoundary artist = new PresentationArtistBoundary(address(core));
        PresentationEntropyBoundary entropy = new PresentationEntropyBoundary();
        core.configure(address(artist), address(entropy));
        router = new StreamMetadataRouter(
            address(core),
            address(this),
            keccak256("matcher deployment"),
            "urn:matcher-router",
            keccak256("matcher manifest"),
            IStreamArtistAttribution(address(artist))
        );
        router.initializeOriginalFinalityAnchor();
        router.setCollectionMetadata(
            1, "Matcher", 'Quoted "animation_url":"decoy","properties":{}', "", ""
        );
        router.setCollectionScript(1, "window.art=1;");
        if (locked) router.lockArtistIdentity(1);
    }

    function _historicalSamples() private returns (Sample[] memory samples) {
        (StreamMetadataRouter router, PresentationCoreBoundary core) = _router(false);
        bytes memory html = _html();
        samples = new Sample[](4);
        samples[0] =
            Sample(bytes(router.historicalTokenMetadataJSON(address(core), 91)), html, false);
        samples[1] =
            Sample(bytes(router.historicalFullTokenMetadataJSON(address(core), 91)), html, true);
        router.lockArtistIdentity(1);
        samples[2] =
            Sample(bytes(router.historicalTokenMetadataJSON(address(core), 91)), html, false);
        samples[3] =
            Sample(bytes(router.historicalFullTokenMetadataJSON(address(core), 91)), html, true);
        _assertOriginal(samples[0].json, false, false);
        _assertOriginal(samples[1].json, true, false);
        _assertOriginal(samples[2].json, false, true);
        _assertOriginal(samples[3].json, true, true);
    }

    function _input() private pure returns (T.Token memory token, F.ServingSource memory source) {
        token = T.Token(91, 1, 7, keccak256("seed"), true, "final", hex"00ff6529", true);
        source = Renderer.prepareMetadata(
            "Matcher", 'Quoted "animation_url":"decoy","properties":{}', "", ""
        );
        source.script = "window.art=1;";
    }

    function _assertOriginal(bytes memory json, bool full, bool locked) private pure {
        (T.Token memory token, F.ServingSource memory source) = _input();
        bytes memory artist = locked
            ? Renderer.artistFields(
                address(0xA11CE), keccak256("identity"), keccak256("acceptance")
            )
            : DisplayJSON.nested(DisplayJSON.unavailable());
        bytes memory expected = bytes(
            full ? Renderer.fullJSON(token, source, artist) : Renderer.render(token, source, artist)
        );
        require(keccak256(json) == keccak256(expected), "exact original production serialization");
        require(
            !_contains(json, bytes('"citation":')), "historical output adds no current citation"
        );
        // Do not apply generic JSON map semantics to original full bytes with two properties members.
        if (!full || locked) _assertAnimationValue(json, _html());
        require(
            _matches(Sample(json, _html(), full)), "original matcher accepts real historical output"
        );
    }

    function _html() private pure returns (bytes memory) {
        return abi.encodePacked(
            "<html><head></head><body><script>const tokenId=91;const tokenHash='",
            uint256(keccak256("seed")).toHexString(32),
            "';const tokenDataBase64='AP9lKQ==';window.art=1;</script></body></html>"
        );
    }

    function _assertAnimationValue(bytes memory json, bytes memory html) private pure {
        require(
            keccak256(bytes(abi.decode(vm.parseJson(string(json), ".animation_url"), (string))))
                == keccak256(abi.encodePacked("data:text/html;base64,", Base64.encode(html))),
            "actual animation equals independently built HTML"
        );
    }

    function _assertFinalCitation(bytes memory json, uint256 chainId, address core) private pure {
        require(
            keccak256(
                bytes(
                    abi.decode(vm.parseJson(string(json), ".properties.stream.citation"), (string))
                )
            )
            == keccak256(
                abi.encodePacked(
                    "eip155:",
                    chainId.toString(),
                    "/erc721:",
                    uint256(uint160(core)).toHexString(20),
                    "/91"
                )
            ),
            "current output retains original chain Core and global token"
        );
        require(
            keccak256(
                bytes(
                    abi.decode(
                        vm.parseJson(string(json), ".properties.stream.render_state"), (string)
                    )
                )
            ) == keccak256("final"),
            "current final state"
        );
    }

    function _matches(Sample memory s) private pure returns (bool) {
        return s.full
            ? Matcher.matchesFullAnimation(s.json, s.html, hex"00ff6529")
            : Matcher.matchesAnimation(s.json, s.html);
    }

    function _corrupt(bytes memory value) private pure returns (bytes memory changed) {
        require(value.length != 0, "nonempty mutation input");
        changed = bytes.concat(value);
        changed[changed.length - 1] = changed[changed.length - 1] ^ bytes1(uint8(1));
    }

    function _slice(bytes memory value, uint256 start, uint256 end)
        private
        pure
        returns (bytes memory out)
    {
        require(start <= end && end <= value.length, "bounded slice");
        out = new bytes(end - start);
        for (uint256 i; i < out.length; ++i) {
            out[i] = value[start + i];
        }
    }

    function _contains(bytes memory value, bytes memory part) private pure returns (bool) {
        if (part.length > value.length) return false;
        for (uint256 i; i <= value.length - part.length; ++i) {
            bool same = true;
            for (uint256 j; j < part.length; ++j) {
                if (value[i + j] != part[j]) {
                    same = false;
                    break;
                }
            }
            if (same) return true;
        }
        return false;
    }
}
