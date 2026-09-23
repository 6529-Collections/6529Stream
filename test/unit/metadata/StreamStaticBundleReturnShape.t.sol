// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    DependencyRegistry
} from "../../../smart-contracts/domains/dependencies/DependencyRegistry.sol";
import {
    StreamRendererCalls
} from "../../../smart-contracts/domains/metadata/StreamRendererCalls.sol";
import {
    StreamMetadataBundleRenderer
} from "../../../smart-contracts/domains/metadata/StreamMetadataBundleRenderer.sol";
import {
    StreamMetadataDisplayParameters
} from "../../../smart-contracts/domains/metadata/StreamMetadataDisplayParameters.sol";

/// @dev Both projections run under the original initialized gas namespace, just like the Router.
contract BundleSelectionProjectionProbe {
    constructor(address authority) {
        StreamMetadataDisplayParameters.initialize(authority);
    }

    function compare(M.Selection memory selected)
        external
        view
        returns (bytes32 scalar, bytes32 full)
    {
        return (
            StreamMetadataBundleRenderer.selectedBundleId(selected),
            StreamMetadataBundleRenderer.selection(selected).bundleId
        );
    }
}

contract StaticBundleDependencyAdmin {
    function retrieveFunctionAdmin(address, address, bytes4) external pure returns (bool) {
        return true;
    }

    function retrieveGlobalAdmin(address) external pure returns (bool) {
        return true;
    }
}

/// @notice Actual Metadata/bundle store/DependencyRegistry/Renderer. The inherited Core, Artist,
/// version admission and governance boundaries remain explicit; this is not current-stack acceptance.
contract StreamStaticBundleReturnShapeTest is StaticMetadataRoutingFixture {
    function setUp() public override {
        super.setUp();
        _optInCurrentCitationAdmissionBoundary();
    }

    DependencyRegistry private dependency;
    bytes32 private constant KEY = keccak256("static bundle return-shape library");

    function testActualMetadataHasTwelveWordsAndRendererPreservesEveryFact() public {
        bytes memory script = bytes("/* actual immutable script */");
        bytes32 id = _script(script, 0);
        bytes memory data = _raw(id);
        require(data.length == 12 * 32, "seven facts plus five registry fields");
        (B.Facts memory facts, B.RegistrySource memory source) =
            abi.decode(data, (B.Facts, B.RegistrySource));
        require(keccak256(data) == keccak256(abi.encode(facts, source)));
        require(keccak256(abi.encode(facts)) == keccak256(abi.encode(metadata.scriptBundle(id))));
        require(
            keccak256(abi.encode(source))
                == keccak256(abi.encode(metadata.scriptBundleRegistry(id)))
        );
        require(
            keccak256(abi.encode(renderer.scriptBundleFacts(id))) == keccak256(abi.encode(facts))
        );
        require(keccak256(renderer.scriptBundleChunk(id, 0)) == keccak256(script));
    }

    function testActualRegistryPageUsesCompletePinnedTwelveWordSource() public {
        bytes32 lib = _library();
        bytes memory data = _raw(lib);
        require(data.length == 384);
        (B.Facts memory facts, B.RegistrySource memory source) =
            abi.decode(data, (B.Facts, B.RegistrySource));
        require(facts.libraryOnly && facts.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY);
        require(
            source.registry == address(dependency)
                && source.codeHash == address(dependency).codehash
        );
        require(source.dependencyId == KEY && source.version == 1);
        require(source.contentHash == dependency.getDependencyScriptContentHashAtVersion(KEY, 1));
        require(keccak256(renderer.scriptBundleChunk(lib, 0)) == keccak256("const libraryValue="));
        require(keccak256(renderer.scriptBundleChunk(lib, 1)) == keccak256("7;"));
        dependency.addDependencyScriptIndex(KEY, 1, "999;");
        require(keccak256(renderer.scriptBundleChunk(lib, 1)) == keccak256("7;"));
        vm.etch(address(dependency), hex"00");
        vm.expectRevert(abi.encodeWithSelector(StreamRendererV1.InvalidStaticRender.selector));
        renderer.scriptBundleChunk(lib, 0);
    }

    function testActualRegistryLibraryFullRenderUsesOriginalSelectedBytes() public {
        bytes32 lib = _library();
        bytes memory script = bytes("document.body.textContent=libraryValue;");
        bytes32 id = _script(script, lib);
        M.ScriptManifest memory manifest = M.ScriptManifest(
            keccak256(script),
            keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1"),
            M.PayloadSourceType.INLINE_CHUNKS,
            "",
            "ipfs://mirror",
            Strings.toHexString(uint256(id), 32),
            "application/javascript",
            1,
            true
        );
        _admin(abi.encodeCall(router.setCollectionScriptManifest, (1, manifest)));
        M.Selection memory selected = router.selectedCollectionManifest(1, 2);
        BundleSelectionProjectionProbe probe = new BundleSelectionProjectionProbe(address(executor));
        (bytes32 scalar, bytes32 full) = probe.compare(selected);
        require(
            scalar == id && full == id && router.collectionScriptBundle(1).bundleId == id,
            "original checked scalar projection"
        );
        selected.codeHash = keccak256("wrong bundle host runtime");
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataBundleRenderer.InvalidBundleRendering.selector)
        );
        probe.compare(selected);
        _activate();
        _mint();
        string memory html = router.tokenHTML(91);
        require(_has(html, "const libraryValue=7;") && _has(html, string(script)));
        require(_has(router.tokenJSON(91), '"render_mode":"full"'));
        dependency.addDependencyScriptIndex(KEY, 1, "999;");
        require(keccak256(bytes(router.tokenHTML(91))) == keccak256(bytes(html)));
        vm.etch(address(dependency), hex"00");
        vm.expectRevert();
        router.tokenHTML(91);
    }

    function testMalformedShortAndExtraWordBundleReturnsRemainTerminal() public {
        bytes32 id = _script(bytes("/* shape rejection */"), 0);
        bytes memory data = _raw(id);
        bytes memory shortData = new bytes(data.length - 32);
        for (uint256 i; i < shortData.length; ++i) {
            shortData[i] = data[i];
        }
        _rejectShape(id, shortData);
        _rejectShape(id, bytes.concat(data, bytes32(0)));
        StaticRouteVm(address(vm)).clearMockedCalls();
        require(renderer.scriptBundleFacts(id).finalized);
    }

    function _rejectShape(bytes32 id, bytes memory bad) private {
        StaticRouteVm(address(vm))
            .mockCall(address(metadata), abi.encodeCall(Raw.staticBundle, (id)), bad);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRendererCalls.RendererReadFailed.selector,
                address(metadata),
                Raw.staticBundle.selector
            )
        );
        renderer.scriptBundleFacts(id);
    }

    function _raw(bytes32 id) private view returns (bytes memory data) {
        bool ok;
        (ok, data) = address(metadata).staticcall(abi.encodeCall(Raw.staticBundle, (id)));
        require(ok);
    }

    function _script(bytes memory script, bytes32 lib) private returns (bytes32 id) {
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256(script);
        uint32[] memory lengths = new uint32[](1);
        lengths[0] = uint32(script.length);
        id = metadata.beginScriptBundle(
            B.Plan(hashes[0], M.PayloadSourceType.INLINE_CHUNKS, hashes, lengths, lib, false)
        );
        metadata.appendScriptBundle(id, 0, script);
        metadata.finalizeScriptBundle(id);
    }

    function _library() private returns (bytes32 id) {
        dependency = new DependencyRegistry(address(new StaticBundleDependencyAdmin()));
        // Bind the actual dependency runtime at construction, before activating any renderer config.
        StreamRendererV1.Deployment memory d;
        (d.sources,) = renderer.sourceBindings();
        d.sources.dependencyRegistry = address(dependency);
        d.executor = address(executor);
        d.manifest = renderer.rendererManifest();
        d.readGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        d.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        renderer = new StreamRendererV1(d);
        versions = new StaticRouteVersions(address(executor), address(schemas), address(renderer));
        _optInCurrentCitationAdmissionBoundary();
        modules = new StaticRouteModules(address(metadata), address(versions));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(modules));
        string[] memory chunks = new string[](2);
        chunks[0] = "const libraryValue=";
        chunks[1] = "7;";
        dependency.addDependency(KEY, chunks);
        bytes32[] memory hashes = new bytes32[](2);
        uint32[] memory lengths = new uint32[](2);
        for (uint256 i; i < 2; ++i) {
            hashes[i] = keccak256(bytes(chunks[i]));
            lengths[i] = uint32(bytes(chunks[i]).length);
        }
        B.Plan memory plan = B.Plan(
            keccak256("const libraryValue=7;"),
            M.PayloadSourceType.DEPENDENCY_REGISTRY,
            hashes,
            lengths,
            0,
            true
        );
        B.RegistrySource memory source = B.RegistrySource(
            address(dependency),
            address(dependency).codehash,
            KEY,
            1,
            dependency.getDependencyScriptContentHashAtVersion(KEY, 1)
        );
        id = metadata.beginRegistryLibrary(plan, source);
        metadata.appendScriptBundle(id, 0, bytes(chunks[0]));
        metadata.appendScriptBundle(id, 1, bytes(chunks[1]));
        metadata.finalizeScriptBundle(id);
    }
}
