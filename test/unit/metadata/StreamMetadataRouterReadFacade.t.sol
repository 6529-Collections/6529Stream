// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import {
    StreamMetadataRouterReadFacade as Facade
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouterReadFacade.sol";
import {
    StreamMetadataRouterRendering
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouterRendering.sol";
import {
    StreamMetadataFinalityServing
} from "../../../smart-contracts/domains/metadata/StreamMetadataFinalityServing.sol";
import {
    StreamMetadataRecoveryRoutes
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveryRoutes.sol";
import {
    StreamMetadataDisplayParameters
} from "../../../smart-contracts/domains/metadata/StreamMetadataDisplayParameters.sol";
import {
    StreamMetadataRenderPreparation
} from "../../../smart-contracts/domains/metadata/StreamMetadataRenderPreparation.sol";
import {
    StreamMetadataStaticState as StaticState
} from "../../../smart-contracts/domains/metadata/StreamMetadataStaticState.sol";
import {
    StreamMetadataStaticRouting as StaticRouting
} from "../../../smart-contracts/domains/metadata/StreamMetadataStaticRouting.sol";
import {
    StreamRendererCalls as StaticCalls
} from "../../../smart-contracts/domains/metadata/StreamRendererCalls.sol";
import {
    IStreamCoreIdentity
} from "../../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamMetadataServingFacts as F
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import { Base64 } from "../../../smart-contracts/vendor/openzeppelin/Base64.sol";

import {
    IStreamStaticMetadataRouter as S
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import { StreamRendererV1 } from "../../../smart-contracts/domains/metadata/StreamRendererV1.sol";

interface FacadeVm {
    function etch(address target, bytes calldata code) external;
}

contract FacadeCoreBoundary {
    bytes private identity = abi.encode(true, uint256(7), uint256(13), false);
    bool public known = true;
    address private coordinator;

    function setCoordinator(address value) external {
        coordinator = value;
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return coordinator;
    }

    function tokenLifecycle(uint256) external pure returns (uint8) {
        return 2;
    }

    function collectionFreezeStatus(uint256) external pure returns (bool) {
        return false;
    }

    function collectionSupplyMode(uint256) external pure returns (uint8) {
        return 1;
    }

    function collectionStatus(uint256) external pure returns (uint8) {
        return 2;
    }

    function configure(bytes memory raw, bool exists) external {
        identity = raw;
        known = exists;
    }

    function tokenCollectionIdentity(uint256) external view returns (bool, uint256, uint256, bool) {
        bytes memory raw = identity;
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function collectionExists(uint256) external view returns (bool) {
        return known;
    }
}

/// @dev Typed selected renderer/Registry/Coordinator boundary for the real internal STATIC route.
contract FacadeStaticBoundary {
    address private immutable core;
    address private immutable router;

    constructor(address c, address r) {
        core = c;
        router = r;
    }

    function requireRetained(bytes32) external view returns (address, bytes32) {
        return (address(this), address(this).codehash);
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }

    function sourceBindings()
        external
        view
        returns (StreamRendererV1.Sources memory sources, bytes32[6] memory pins)
    {
        sources = StreamRendererV1.Sources(
            core, router, address(this), address(this), address(0), address(0)
        );
        pins[0] = core.codehash;
        pins[1] = router.codehash;
        pins[2] = address(this).codehash;
        pins[3] = address(this).codehash;
    }

    function staticTokenRenderFacts(uint256) external view returns (uint8, bytes32, address) {
        return (5, keccak256("static seed"), address(this));
    }

    function tokenURI(R.RenderRequest calldata request) external view returns (string memory) {
        require(msg.sender == router, "actual Router caller");
        return string(abi.encode(request, uint8(1)));
    }

    function renderView(R.RenderRequest calldata request, uint8 mode)
        external
        view
        returns (string memory)
    {
        require(msg.sender == router, "actual Router caller");
        return string(abi.encode(request, mode));
    }
}

/// @dev Typed host roots; legacy bodies below are frozen from the pre-extraction Router.
/// This harness proves the orchestration transport, not the complete live Router graph.
contract FacadeReadHarness {
    mapping(uint256 => StreamMetadataRouter.PreparedMetadata) private _prepared;
    mapping(uint256 => StreamMetadataRouter.CollectionMetadata) private _collections;
    mapping(uint256 => F.ArtistPresentation) private _artistPresentation;
    mapping(uint256 => StreamMetadataRecoveryRoutes.OriginalAnchor) private originalFinalityAnchor;
    mapping(uint256 => mapping(uint8 => M.Selection)) private _selectedManifests;
    FacadeCoreBoundary public immutable core;
    address private artistRegistry;
    bytes32 private _artistRegistryCodeHash;
    bool private _originalFinalityAnchorInitialized;
    StreamMetadataRecoveryRoutes.OriginalAnchor private servingOriginalFinalityAnchor;
    error OriginalFinalityAnchorUninitialized();
    error InvalidCore(address supplied);
    error InvalidCollection(uint256 collectionId);

    constructor(FacadeCoreBoundary c) {
        core = c;
        artistRegistry = address(0xA7157);
        _artistRegistryCodeHash = keccak256("original artist pin");
        _prepared[7] =
            StreamMetadataRouter.PreparedMetadata("name", "description", "ipfs://image", "", "");
        _collections[7].configured = true;
        originalFinalityAnchor[7] = StreamMetadataRecoveryRoutes.OriginalAnchor(
            address(0xB00), keccak256("per-collection")
        );
        StreamMetadataDisplayParameters.initialize(address(this));
    }

    function anchor(bool initialized) external {
        _originalFinalityAnchorInitialized = initialized;
        servingOriginalFinalityAnchor = StreamMetadataRecoveryRoutes.OriginalAnchor(
            address(0xF1A1), keccak256("durable anchor")
        );
    }

    function activate(bool enabled) external {
        StaticState.state().collections[7] = StaticState.Collection(
            enabled ? bytes32(uint256(71)) : bytes32(0), 0, 0, enabled ? 1 : 0
        );
    }

    function staticSelection(address target) external {
        S.ConfigRecord storage record = StaticState.state().records[bytes32(uint256(71))];
        record.recordHash = bytes32(uint256(71));
        record.collectionId = 7;
        record.revision = 1;
        record.selection.registry = target;
        record.selection.registryCodeHash = target.codehash;
        record.selection.renderer = target;
        record.selection.rendererCodeHash = target.codehash;
        record.selection.versionKey = keccak256("retained test version");
    }

    function fingerprint() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                _prepared[7],
                _collections[7],
                _artistPresentation[7],
                originalFinalityAnchor[7],
                _selectedManifests[7][2],
                _originalFinalityAnchorInitialized,
                servingOriginalFinalityAnchor,
                StaticState.state().collections[7],
                StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.READ_GAS)
            )
        );
    }

    function liveAttributionObject(uint256 cid, uint256 token)
        external
        view
        returns (bytes memory)
    {
        require(msg.sender == address(this) && cid == 7 && token == 0, "live caller/context");
        return bytes('{"probe":true}');
    }

    function _readContext() private view returns (Facade.Context memory) {
        return Facade.Context(
            address(core),
            artistRegistry,
            _artistRegistryCodeHash,
            _originalFinalityAnchorInitialized,
            servingOriginalFinalityAnchor
        );
    }

    function _servingAnchor()
        private
        view
        returns (StreamMetadataRecoveryRoutes.OriginalAnchor memory)
    {
        if (!_originalFinalityAnchorInitialized) revert OriginalFinalityAnchorUninitialized();
        return servingOriginalFinalityAnchor;
    }

    function _requireCore(address supplied) private view {
        if (supplied != address(core)) revert InvalidCore(supplied);
    }

    function _requireCollection(uint256 cid) private view {
        if (!core.collectionExists(cid)) revert InvalidCollection(cid);
    }

    function _liveAttribution(uint256 cid, uint256 token) private view returns (bytes memory) {
        return StreamMetadataRouterRendering.live(cid, token);
    }

    function readToken(bool old, address supplied, uint256 token, bool burned, uint8 mode)
        external
        view
        returns (string memory)
    {
        _requireCore(supplied);
        StreamMetadataRouter.TokenViewOptions memory o =
            StreamMetadataRouter.TokenViewOptions(burned, mode);
        if (old) return _legacyToken(token, o);
        return Facade.token(
            _prepared,
            _collections,
            _artistPresentation,
            originalFinalityAnchor,
            _selectedManifests,
            _readContext(),
            token,
            o
        );
    }

    function readCollection(bool old, address supplied, uint256 cid)
        external
        view
        returns (string memory)
    {
        if (old) return _legacyCollection(supplied, cid);
        _requireCore(supplied);
        _requireCollection(cid);
        return Facade.collection(
            _prepared, _artistPresentation, originalFinalityAnchor, _readContext(), cid
        );
    }

    function _legacyToken(uint256 tokenId, StreamMetadataRouter.TokenViewOptions memory options)
        private
        view
        returns (string memory)
    {
        bool allowBurned = options.allowBurned;
        uint8 mode = options.mode;
        // Probe only dispatch identity. Unknown tokens retain the original legacy finality/
        // identity error path; the strict new config reads still use _staticCollection.
        bytes memory identity = StaticCalls.read(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId)),
            StaticCalls.ReadOptions(128, true),
            StreamMetadataDisplayParameters.value(StreamMetadataDisplayParameters.READ_GAS)
        );
        (bool exists, uint256 staticCollection,,) =
            abi.decode(identity, (bool, uint256, uint256, bool));
        if (exists && StaticState.activated(staticCollection)) {
            return StaticRouting.serve(address(core), tokenId, allowBurned, mode);
        }
        return StreamMetadataRouterRendering.serve(
            _prepared,
            _collections,
            _artistPresentation,
            originalFinalityAnchor,
            _selectedManifests,
            StreamMetadataRouterRendering.Context(
                address(core), address(artistRegistry), _artistRegistryCodeHash, _servingAnchor()
            ),
            tokenId,
            allowBurned,
            mode
        );
    }

    function _legacyCollection(address core_, uint256 collectionId)
        private
        view
        returns (string memory)
    {
        _requireCore(core_);
        _requireCollection(collectionId);
        (bool frozen, string memory resolved) = StreamMetadataFinalityServing.collection(
            _artistPresentation,
            originalFinalityAnchor,
            StreamMetadataRecoveryRoutes.Environment(
                address(core), address(artistRegistry), _artistRegistryCodeHash
            ),
            _servingAnchor(),
            collectionId
        );
        if (frozen) return resolved;
        StreamMetadataRouter.PreparedMetadata storage metadata = _prepared[collectionId];
        return StreamMetadataRenderPreparation.attributedCollectionURI(
            metadata.name, metadata.description, metadata.image, _liveAttribution(collectionId, 0)
        );
    }
}

/// @dev Exact full calldata + delegate host/caller echo at an unchanged dependency boundary.
contract FacadeTokenEcho {
    address private immutable host;
    address private immutable caller;

    constructor(address h, address c) {
        host = h;
        caller = c;
    }

    fallback() external {
        require(address(this) == host && msg.sender == caller, "delegate identity");
        bytes memory raw =
            abi.encode(string(abi.encode(address(this), msg.sender, keccak256(msg.data))));
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }
}

contract FacadeCollectionEcho {
    address private immutable host;
    address private immutable caller;
    bool private immutable frozen;

    constructor(address h, address c, bool f) {
        host = h;
        caller = c;
        frozen = f;
    }

    fallback() external {
        require(address(this) == host && msg.sender == caller, "collection delegate identity");
        bytes memory raw =
            abi.encode(frozen, string(abi.encode(address(this), msg.sender, keccak256(msg.data))));
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }
}

contract StreamMetadataRouterReadFacadeTest {
    FacadeVm private constant vm =
        FacadeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    FacadeCoreBoundary private core;
    FacadeReadHarness private host;

    function setUp() public {
        core = new FacadeCoreBoundary();
        host = new FacadeReadHarness(core);
    }

    function _echo(address target) private {
        FacadeTokenEcho p = new FacadeTokenEcho(address(host), address(this));
        vm.etch(target, address(p).code);
    }

    function _collection(bool frozen) private {
        FacadeCollectionEcho p = new FacadeCollectionEcho(address(host), address(this), frozen);
        vm.etch(address(StreamMetadataFinalityServing), address(p).code);
    }

    function _same(bytes memory a, bytes memory b) private pure {
        require(keccak256(a) == keccak256(b), "exact bytes");
    }

    function _tokenFailure(bytes memory expected) private view {
        for (uint256 i; i < 2; ++i) {
            (bool ok, bytes memory raw) = address(host)
                .staticcall(
                    abi.encodeCall(host.readToken, (i == 0, address(core), 99, false, uint8(0)))
                );
            require(!ok, "token refused");
            _same(raw, expected);
        }
    }

    function _collectionFailure(address supplied, bytes memory expected) private view {
        for (uint256 i; i < 2; ++i) {
            (bool ok, bytes memory raw) =
                address(host).staticcall(abi.encodeCall(host.readCollection, (i == 0, supplied, 7)));
            require(!ok, "collection refused");
            _same(raw, expected);
        }
    }

    function testStaticDispatchPrecedesUninitializedAnchorAndRetainsAllModeArguments() public {
        FacadeStaticBoundary graph = new FacadeStaticBoundary(address(core), address(host));
        core.setCoordinator(address(graph));
        host.staticSelection(address(graph));
        host.activate(true);
        bytes32 before_ = host.fingerprint();
        R.RenderRequest memory expected = R.RenderRequest(
            address(core),
            99,
            7,
            13,
            keccak256("static seed"),
            R.TokenRenderState.ACTIVE,
            R.MetadataMode.OFFCHAIN,
            1,
            2,
            0,
            0,
            bytes32(uint256(71))
        );
        for (uint8 mode; mode < 5; ++mode) {
            for (uint8 burned; burned < 2; ++burned) {
                bytes memory old = bytes(host.readToken(true, address(core), 99, burned == 1, mode));
                _same(old, bytes(host.readToken(false, address(core), 99, burned == 1, mode)));
                _same(old, abi.encode(expected, mode == 4 ? uint8(2) : mode));
            }
        }
        require(before_ == host.fingerprint(), "read-only roots");
    }

    function testLegacyDispatchExactFiveRootsContextAndOptions() public {
        host.anchor(true);
        _echo(address(StreamMetadataRouterRendering));
        bytes32 before_ = host.fingerprint();
        bytes32 prior;
        for (uint8 mode; mode < 5; ++mode) {
            bytes memory old = bytes(host.readToken(true, address(core), 99, mode % 2 == 1, mode));
            _same(old, bytes(host.readToken(false, address(core), 99, mode % 2 == 1, mode)));
            require(keccak256(old) != prior, "legacy options");
            prior = keccak256(old);
        }
        require(before_ == host.fingerprint(), "legacy roots");
    }

    function testIdentityReadFailurePrecedesAnchorAndRestores() public {
        core.configure(hex"01", true);
        _tokenFailure(
            abi.encodeWithSelector(
                StaticCalls.RendererReadFailed.selector,
                address(core),
                IStreamCoreIdentity.tokenCollectionIdentity.selector
            )
        );
        core.configure(abi.encode(true, uint256(7), uint256(13), false), true);
        _tokenFailure(
            abi.encodeWithSelector(FacadeReadHarness.OriginalFinalityAnchorUninitialized.selector)
        );
        host.anchor(true);
        _echo(address(StreamMetadataRouterRendering));
        _same(
            bytes(host.readToken(true, address(core), 99, false, 0)),
            bytes(host.readToken(false, address(core), 99, false, 0))
        );
    }

    function testUnknownIdentityRetainsLazyLegacyAnchorRefusal() public {
        host.activate(true);
        core.configure(abi.encode(false, uint256(7), uint256(13), false), true);
        _tokenFailure(
            abi.encodeWithSelector(FacadeReadHarness.OriginalFinalityAnchorUninitialized.selector)
        );
    }

    function testCollectionOriginalGuardsPrecedeAnchorAndFrozenArgumentsMatch() public {
        _collectionFailure(
            address(0xBAD),
            abi.encodeWithSelector(FacadeReadHarness.InvalidCore.selector, address(0xBAD))
        );
        core.configure(abi.encode(true, uint256(7), uint256(13), false), false);
        _collectionFailure(
            address(core),
            abi.encodeWithSelector(FacadeReadHarness.InvalidCollection.selector, uint256(7))
        );
        core.configure(abi.encode(true, uint256(7), uint256(13), false), true);
        _collectionFailure(
            address(core),
            abi.encodeWithSelector(FacadeReadHarness.OriginalFinalityAnchorUninitialized.selector)
        );
        host.anchor(true);
        _collection(true);
        bytes32 before_ = host.fingerprint();
        _same(
            bytes(host.readCollection(true, address(core), 7)),
            bytes(host.readCollection(false, address(core), 7))
        );
        require(before_ == host.fingerprint(), "collection roots");
    }

    function testCollectionLiveAttributionAndLiteralOriginalJSON() public {
        host.anchor(true);
        _collection(false);
        string memory expected = string.concat(
            "data:application/json;base64,",
            Base64.encode(
                bytes(
                    '{"name":"name","description":"description","image":"ipfs://image","properties":{"provenance":{"attribution":{"probe":true}}}}'
                )
            )
        );
        _same(bytes(host.readCollection(true, address(core), 7)), bytes(expected));
        _same(bytes(host.readCollection(false, address(core), 7)), bytes(expected));
    }

    function testFuzzFrozenTokenTransport(uint256 token, bool burned, uint8 mode) public {
        host.anchor(true);
        _echo(address(StreamMetadataRouterRendering));
        _same(
            bytes(host.readToken(true, address(core), token, burned, mode)),
            bytes(host.readToken(false, address(core), token, burned, mode))
        );
    }
}
