// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/MetadataRecoveryServingBoundaries.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @notice Serving mechanism with explicit Core/registry/original/companion/host boundaries.
contract StreamMetadataRecoveryServingTest is CharacterizationTestBase {
    MetadataRecoveryCoreBoundary private core;
    MetadataRecoveryRegistryBoundary private registry;
    MetadataRecoveryArtistBoundary private artist;
    MetadataRecoveryOriginalBoundary private original;
    MetadataRecoveryOwnerBoundary private owner;
    MetadataRecoveryCompanionBoundary private companion;
    MetadataRecoverySourceBoundary private source;
    MetadataRecoveryServingHarness private harness;
    bytes32 private constant ROUTER = keccak256("METADATA_ROUTER");

    function setUp() public {
        core = new MetadataRecoveryCoreBoundary();
        registry = new MetadataRecoveryRegistryBoundary();
        artist = new MetadataRecoveryArtistBoundary(address(core));
        original =
            new MetadataRecoveryOriginalBoundary(address(core), address(artist), address(this));
        artist.bind(address(original));
        owner = new MetadataRecoveryOwnerBoundary(address(core), address(this));
        companion = new MetadataRecoveryCompanionBoundary(
            address(core), address(this), address(original), address(artist), address(owner)
        );
        source = new MetadataRecoverySourceBoundary(
            address(core), address(StreamMetadataTokenRenderer), "original"
        );
        harness = new MetadataRecoveryServingHarness(address(artist));
        _install();
        original.setCount(7);
        bytes32[7] memory kinds = [
            ROUTER,
            keccak256("MEDIA_MANIFEST"),
            keccak256("RENDERER"),
            keccak256("RENDER_CONTEXT"),
            keccak256("SCRIPT_SOURCE"),
            keccak256("DEPENDENCY_SOURCE"),
            keccak256("ENTROPY_COORDINATOR")
        ];
        for (uint256 i; i < 7; ++i) {
            _route(kinds[i], source, 0);
        }
    }

    function _install() private {
        core.setPointer(
            keccak256("MODULE_REGISTRY"),
            StreamMetadataRecoveryRoutes.Pointer(
                address(registry),
                address(registry).codehash,
                false,
                keccak256("MODULE_REGISTRY"),
                0,
                address(registry),
                1,
                bytes32(uint256(1)),
                bytes32(uint256(2)),
                1
            )
        );
        core.setPointer(
            keccak256("ARTWORK_FINALITY_RECOVERY"),
            StreamMetadataRecoveryRoutes.Pointer(
                address(companion),
                address(companion).codehash,
                false,
                keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
                type(IStreamArtworkFinalityRecovery).interfaceId,
                address(registry),
                1,
                bytes32(uint256(1)),
                bytes32(uint256(2)),
                1
            )
        );
    }

    function _route(bytes32 kind, MetadataRecoverySourceBoundary host, bytes32 id) private {
        companion.setRoute(
            kind,
            address(new MetadataRecoveryAdapterBoundary(address(core), address(host), kind)),
            id
        );
    }

    function _read() private view returns (string memory text) {
        (bool pin, string memory output) =
            harness.token(address(core), address(artist), false, false);
        require(pin, "pinned");
        return output;
    }

    function testFrozenOriginalUsesActualPureRendererStaticCall() public {
        string memory json = _read();
        require(_contains(json, '"name":"original #9"'), "name source");
        require(_contains(json, '"image":"ipfs://original"'), "media source");
        require(_contains(json, '"metadata_state":"final"'), "selected terminal entropy");
        (bool pin, string memory uri) = harness.token(address(core), address(artist), false, true);
        require(
            pin && _contains(uri, "data:application/json;base64,"), "actual renderer URI selector"
        );
    }

    function testRendererOnlyRecoveryConsumesReplacementWithStableContextAndDependencies() public {
        MetadataRecoveryRendererBoundary renderer = new MetadataRecoveryRendererBoundary();
        MetadataRecoverySourceBoundary replacement =
            new MetadataRecoverySourceBoundary(address(core), address(renderer), "unused-display");
        _route(keccak256("RENDERER"), replacement, keccak256("renderer recovery"));
        string memory result = _read();
        require(
            _contains(result, "RECOVERED:original:ipfs://original:return 1;"),
            "replacement renderer, original independent sources"
        );
    }

    function testIndependentMediaAndScriptRecoveriesConsumeSelectedBytes() public {
        MetadataRecoveryRendererBoundary renderer = new MetadataRecoveryRendererBoundary();
        MetadataRecoverySourceBoundary replacement =
            new MetadataRecoverySourceBoundary(address(core), address(renderer), "unused");
        _route(keccak256("RENDERER"), replacement, keccak256("renderer"));
        MetadataRecoverySourceBoundary media = new MetadataRecoverySourceBoundary(
            address(core), address(StreamMetadataTokenRenderer), "new-media"
        );
        MetadataRecoverySourceBoundary script = new MetadataRecoverySourceBoundary(
            address(core), address(StreamMetadataTokenRenderer), "unused-script-name"
        );
        script.setScript("replacement-script");
        _route(keccak256("MEDIA_MANIFEST"), media, keccak256("media"));
        _route(keccak256("SCRIPT_SOURCE"), script, keccak256("script"));
        require(
            _contains(_read(), "RECOVERED:original:ipfs://new-media:replacement-script"),
            "independent selected bytes"
        );
    }

    function testMalformedAndInconsistentFrozenRoutesFailWithoutLocalFallback() public {
        for (uint8 i = 1; i <= 5; ++i) {
            companion.setFault(i);
            (bool ok,) = address(harness)
                .staticcall(
                    abi.encodeCall(harness.token, (address(core), address(artist), false, false))
                );
            require(!ok, "bad route rejected");
        }
        companion.setFault(0);
        _read();
        companion.clearRoute(ROUTER);
        (bool ok,) = address(harness)
            .staticcall(
                abi.encodeCall(harness.token, (address(core), address(artist), false, false))
            );
        require(!ok, "missing frozen route rejected");
        _route(ROUTER, source, 0);
        _read();
    }

    function testCurrentEligibilityAndOriginalRuntimeDriftRejectThenRestore() public {
        registry.setEligible(false);
        (bool ok,) = address(harness)
            .staticcall(
                abi.encodeCall(harness.token, (address(core), address(artist), false, false))
            );
        require(!ok, "live eligibility");
        registry.setEligible(true);
        _read();
        bytes memory code = address(original).code;
        vm.etch(address(original), hex"00");
        (ok,) = address(harness)
            .staticcall(
                abi.encodeCall(harness.token, (address(core), address(artist), false, false))
            );
        require(!ok, "pinned original runtime");
        vm.etch(address(original), code);
        _read();
    }

    function testUnfinalizedInstalledCompanionFitsExistingReadCapAndZeroAnchorFails() public {
        original.setCount(0);
        companion.setFault(1);
        (bool ok, bytes memory raw) = address(harness).staticcall{ gas: 500000 }(
            abi.encodeCall(harness.token, (address(core), address(artist), false, false))
        );
        require(ok, "cheap unfinalized classification at500k");
        (bool pin, string memory value) = abi.decode(raw, (bool, string));
        require(!pin && bytes(value).length == 0, "only authoritative absence allows local");
        artist.bind(address(0));
        (ok,) = address(harness)
            .staticcall(
                abi.encodeCall(harness.token, (address(core), address(artist), false, false))
            );
        require(!ok, "no zero anchor fallback");
    }

    function testCurrentOriginalPointerReplacementDoesNotRewriteHistoryAndBurnedRouteIsExplicit()
        public
    {
        core.setPointer(
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            StreamMetadataRecoveryRoutes.Pointer(
                address(
                    new MetadataRecoveryOriginalBoundary(
                        address(core), address(artist), address(this)
                    )
                ),
                bytes32(uint256(1)),
                false,
                keccak256("ARTWORK_FINALITY_REGISTRY"),
                type(IStreamArtworkFinalityRegistry).interfaceId,
                address(registry),
                1,
                bytes32(uint256(1)),
                bytes32(uint256(1)),
                2
            )
        );
        bytes32 beforeHash = keccak256(bytes(_read()));
        core.setLifecycle(3);
        (bool ok,) = address(harness)
            .staticcall(
                abi.encodeCall(harness.token, (address(core), address(artist), false, false))
            );
        require(!ok, "ERC721 burned exclusion");
        (bool pin, string memory historical) =
            harness.token(address(core), address(artist), true, false);
        require(
            pin && keccak256(bytes(historical)) == beforeHash, "burned exact recovered presentation"
        );
    }

    function testExactSourceTupleWidthsAndMixedProfilesRejectThenRestore() public {
        bytes memory raw = abi.encode(source.collectionServingFacts(1));
        require(raw.length == 512, "sixteen static words");
        for (uint8 i = 1; i <= 4; ++i) {
            source.setSourceFault(i);
            (bool ok,) = address(harness)
                .staticcall(
                    abi.encodeCall(harness.token, (address(core), address(artist), false, false))
                );
            require(!ok, "wrong tuple or context/dependency profile");
        }
        source.setSourceFault(0);
        _read();
    }

    function testFixedArtistRuntimeAnchorRejectsReplacedHistoryClassifier() public {
        bytes memory code = address(artist).code;
        vm.etch(address(artist), hex"00");
        (bool ok,) = address(harness)
            .staticcall(
                abi.encodeCall(harness.token, (address(core), address(artist), false, false))
            );
        require(!ok, "classifier runtime pinned");
        vm.etch(address(artist), code);
        _read();
    }

    function testRendererRecoveryServesAfterOriginalRendererRuntimeLoss() public {
        address oldRenderer = address(StreamMetadataTokenRenderer);
        MetadataRecoveryRendererBoundary renderer = new MetadataRecoveryRendererBoundary();
        MetadataRecoverySourceBoundary replacement =
            new MetadataRecoverySourceBoundary(address(core), address(renderer), "unused");
        vm.etch(oldRenderer, hex"00");
        (bool ok,) = address(harness)
            .staticcall(
                abi.encodeCall(harness.token, (address(core), address(artist), false, false))
            );
        require(!ok, "failed original renderer");
        _route(keccak256("RENDERER"), replacement, keccak256("post-failure recovery"));
        require(
            _contains(_read(), "RECOVERED:original:ipfs://original:return 1;"),
            "old source families survive failed renderer"
        );
    }

    function _contains(string memory value, string memory part) private pure returns (bool) {
        bytes memory a = bytes(value);
        bytes memory b = bytes(part);
        if (b.length > a.length) return false;
        for (uint256 i; i <= a.length - b.length; ++i) {
            bool found = true;
            for (uint256 j; j < b.length; ++j) {
                if (a[i + j] != b[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
