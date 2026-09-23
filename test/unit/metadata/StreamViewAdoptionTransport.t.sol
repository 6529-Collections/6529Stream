// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewAdoptionTypes as V
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamViewAdoptionState as State
} from "../../../smart-contracts/domains/metadata/StreamViewAdoptionState.sol";
import {
    StreamMetadataStaticState as Static
} from "../../../smart-contracts/domains/metadata/StreamMetadataStaticState.sol";
import {
    StreamViewPayloadBytes as Bytes
} from "../../../smart-contracts/domains/metadata/StreamViewPayloadBytes.sol";
import {
    StreamViewPayloadV1 as Payload
} from "../../../smart-contracts/domains/metadata/StreamViewPayloadV1.sol";
import {
    StreamViewRendererV1 as Renderer
} from "../../../smart-contracts/domains/metadata/StreamViewRendererV1.sol";
import {
    StreamViewRendererFormat as Format
} from "../../../smart-contracts/domains/metadata/StreamViewRendererFormat.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamSchemaDocumentStore as Store
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    StreamMetadataContentAuthorization as Auth
} from "../../../smart-contracts/domains/metadata/StreamMetadataContentAuthorization.sol";
import {
    IStreamCollectionArtistRegistry as Artist
} from "../../../smart-contracts/interfaces/stream/artist/IStreamCollectionArtistRegistry.sol";

import {
    StreamViewAdoptionTransport as Transport
} from "../../../smart-contracts/domains/metadata/StreamViewAdoptionTransport.sol";
import {
    StreamViewAdoptionRouting as Routing
} from "../../../smart-contracts/domains/metadata/StreamViewAdoptionRouting.sol";
import {
    StreamMetadataDisplayParameters as Parameters
} from "../../../smart-contracts/domains/metadata/StreamMetadataDisplayParameters.sol";

interface ViewVm {
    function warp(uint256) external;
    function etch(address, bytes calldata) external;
}

contract ViewOriginalAuthorityProbe {
    uint256 public minted;
    address public nominee;
    bool public ratified;
    bytes32 public ratifiedState;
    bytes32 public ratification;
    bytes32 public consent;

    function configure(uint256 m, address n, bool r, bytes32 state, bytes32 record, bytes32 c)
        external
    {
        minted = m;
        nominee = n;
        ratified = r;
        ratifiedState = state;
        ratification = record;
        consent = c;
    }

    function collectionMintedEver(uint256) external view returns (uint256) {
        return minted;
    }

    function attribution(uint256) external view returns (Artist.Attribution memory a) {
        a.nominatedArtist = nominee;
    }

    function firstReleaseRatification(uint256) external view returns (bool, bytes32, bytes32) {
        return (ratified, ratifiedState, ratification);
    }

    function contentConsentEvidence(uint256, bytes32, bytes32) external view returns (bytes32) {
        return consent;
    }
}

contract ViewOriginalAuthorizationHarness {
    mapping(bytes32 => bool) public consumed;
    mapping(uint256 => bytes32) public ratification;
    mapping(uint256 => bytes32) public evolution;

    function authorize(address probe, bool required, bytes32 current)
        external
        returns (bytes32 c, bytes32 r)
    {
        Auth.Context memory ctx = Auth.Context(probe, probe, 1, current);
        if (required) {
            return Auth.authorizeRequired(
                consumed,
                ratification,
                evolution,
                ctx,
                keccak256("RENDERER_CONFIG"),
                keccak256("next")
            );
        }
        return Auth.authorize(
            consumed, ratification, evolution, ctx, keccak256("RENDERER_CONFIG"), keccak256("next")
        );
    }

    function recordApplication(bytes32 c, bytes32 r, bytes32 state) external {
        Auth.recordApplication(
            ratification, evolution, 1, keccak256("RENDERER_CONFIG"), c, r, state
        );
    }
}

contract ViewRecordHarness {
    address public immutable core;
    Store public immutable store;

    constructor(address c, Store s) {
        core = c;
        store = s;
        Parameters.initialize(address(this));
        Static.state().collections[1] = Static.Collection(bytes32(uint256(1)), 0, 0, 1);
    }

    function payload(bytes memory raw) external returns (V.Source memory s) {
        Payload.requireAdmissible(raw);
        for (uint256 i; i < raw.length; i += 8192) {
            uint256 n = raw.length - i;
            if (n > 8192) n = 8192;
            bytes memory part = new bytes(n);
            for (uint256 j; j < n; ++j) {
                part[j] = raw[i + j];
            }
            store.publishChunk(part);
        }
        Bytes.capture(address(store), raw, s);
    }

    function commit(V.Record memory r, bytes32 consent) external returns (bytes32) {
        return State.commit(core, r, consent);
    }

    function viewAdoptionEncoded(bytes32 key) external view returns (bytes memory) {
        bytes memory raw = Transport.encoded(key);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function viewAdoptionCarrier(bytes32 key) external view returns (address, bytes32, uint32) {
        State.Carrier storage c = State.state().records[key];
        return (c.pointer, c.hash, c.size);
    }

    function viewAdoptionHead(StreamFinalityScope calldata scope) external view returns (bytes32) {
        return State.state().heads[State.subject(core, scope)];
    }

    function viewAdoptionAggregate(uint256 cid) external view returns (V.Aggregate memory) {
        return State.state().aggregates[cid];
    }

    function gasParameter(bytes32 id) external view returns (uint256) {
        return Parameters.value(id);
    }

    function historicalTokenJSONForView(uint256, bytes32) external view returns (string memory) {
        _serve();
    }

    function historicalTokenHTMLForView(uint256, bytes32) external view returns (string memory) {
        _serve();
    }

    function _serve() private view {
        bytes memory raw = Transport.serve(address(Routing).codehash, msg.data);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function payloadBytes(V.Source memory s) external view returns (bytes memory) {
        return Bytes.read(s);
    }

    function family() external view returns (bytes32) {
        return Static.family(core, 1);
    }

    function staticChange(bytes32 config) external {
        Static.state().collections[1].collectionOverride = config;
    }

    function legacy() external view returns (bytes32) {
        return Static.legacyFamilyOf(core, 1, Static.state().collections[1]);
    }
}

contract ViewTokenSourceProbe {
    address public renderer;

    function setRenderer(address value) external {
        renderer = value;
    }

    function requireRetained(bytes32) external view returns (address, bytes32) {
        return (renderer, renderer.codehash);
    }
    address public router;
    uint256 public serial = 7;
    uint8 public status = 5;
    bytes32 public seed = keccak256("actual typed original seed");
    bool public burned;
    bool public covered = true;
    bytes public artist = '{"state":"active"}';

    function configure(address r, uint256 s, uint8 e, bool b, bool c) external {
        router = r;
        serial = s;
        status = e;
        burned = b;
        covered = c;
    }

    function core() external view returns (address) {
        return address(this);
    }

    function tokenCollectionIdentity(uint256 token)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (token == 11, 1, serial, burned);
    }

    function tokenLifecycle(uint256) external view returns (uint8) {
        return burned ? 3 : 2;
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return address(this);
    }

    function staticTokenRenderFacts(uint256) external view returns (uint8, bytes32, address) {
        return (status, seed, address(this));
    }

    function collectionFreezeStatus(uint256) external pure returns (bool) {
        return false;
    }

    function collectionSupplyMode(uint256) external pure returns (uint8) {
        return 0;
    }

    function collectionStatus(uint256) external pure returns (uint8) {
        return 0;
    }

    function scopeCoversToken(StreamFinalityScope calldata, uint256 t)
        external
        view
        returns (bool)
    {
        return t == 11 && covered;
    }

    function tokenData(uint256) external pure returns (bytes memory) {
        return hex"112200ff";
    }

    function attribution(uint256, uint256) external view returns (bytes memory) {
        return artist;
    }

    function changeAttribution(bytes calldata value) external {
        artist = value;
    }
}

/// @notice Actual new immutable record/payload/renderer and original consent worker, typed source
/// boundary. These do not substitute for actual Source.prepare/Registry/Artist op17 admission.
contract StreamViewAdoptionTransportTest {
    ViewVm private constant vm = ViewVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Store private store;
    ViewRecordHarness private records;
    ViewTokenSourceProbe private graph;
    Renderer private renderer;
    ViewOriginalAuthorityProbe private authority;
    ViewOriginalAuthorizationHarness private auth;

    function setUp() public {
        vm.warp(2000000000);
        store = new Store();
        graph = new ViewTokenSourceProbe();
        records = new ViewRecordHarness(address(graph), store);
        graph.configure(address(records), 7, 5, false, true);
        authority = new ViewOriginalAuthorityProbe();
        auth = new ViewOriginalAuthorizationHarness();
        R.RendererManifest memory m = R.RendererManifest(
            Format.ID,
            Format.VERSION,
            V.CONTEXT,
            keccak256("STATIC"),
            Format.schemaHash(),
            "",
            "",
            keccak256("typed manifest"),
            262144,
            262144,
            false
        );
        Gas.GasParameterConfig memory read =
            Gas.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 1000000, 50000, 2);
        Gas.GasParameterConfig memory attribution =
            Gas.GasParameterConfig("STATIC_ATTRIBUTION_GAS", 1000000, 50000, 2);
        renderer = new Renderer(
            [address(graph), address(records), address(graph), address(graph)],
            address(0),
            read,
            attribution,
            m
        );
        graph.setRenderer(address(renderer));
    }

    function _record(bytes32 scope, bytes32 previous) private returns (V.Record memory r) {
        r.input.scope = StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, scope);
        r.input.viewId = keccak256("alternate view");
        r.input.viewRecordHash = keccak256("original view declaration");
        r.input.expectedPrevious = previous;
        r.source = records.payload(
            abi.encode(
                V.Payload(
                    V.CONTEXT,
                    "name < x",
                    "description",
                    "",
                    bytes('const a="</ScRiPtX>";window.view=tokenId;')
                )
            )
        );
        r.source.route.core = address(graph);
        r.source.route.coreCodeHash = address(graph).codehash;
        r.source.route.router = address(records);
        r.source.route.routerCodeHash = address(records).codehash;
        r.source.route.store = address(store);
        r.source.route.storeCodeHash = address(store).codehash;
        r.source.route.binding.membership = address(graph);
        r.source.route.binding.membershipCodeHash = address(graph).codehash;
        r.source.renderer.registry = address(graph);
        r.source.renderer.registryCodeHash = address(graph).codehash;
        r.source.renderer.renderer = address(renderer);
        r.source.renderer.rendererCodeHash = address(renderer).codehash;
        r.sourceHash = keccak256(abi.encode("typed source", scope));
        r.input.expectedSourceHash = r.sourceHash;
        r.actor = address(this);
        r.authorizationClass = 7;
        r.grantCollectionId = 1;
        r.grantRevision = 2;
    }

    function _request(bytes32 key) private view returns (R.RenderRequest memory r) {
        r = R.RenderRequest(
            address(graph),
            11,
            1,
            7,
            graph.seed(),
            R.TokenRenderState.ACTIVE,
            R.MetadataMode.ONCHAIN,
            0,
            0,
            keccak256("alternate view"),
            keccak256("original view declaration"),
            key
        );
    }

    function _mustFail(address target, bytes memory input, bytes4 selector) private {
        (bool ok, bytes memory out) = target.call(input);
        require(!ok && out.length >= 4 && bytes4(out) == selector, "exact refusal");
    }

    function testOriginalPremintBypassAndRequiredConsentAreSeparate() public {
        authority.configure(0, address(0), false, 0, 0, 0);
        (bytes32 c,) = auth.authorize(address(authority), false, 0);
        require(c == 0, "original bypass");
        _mustFail(
            address(auth),
            abi.encodeCall(auth.authorize, (address(authority), true, bytes32(0))),
            Auth.ArtistContentAuthorizationRequired.selector
        );
        authority.configure(0, address(0), false, 0, 0, keccak256("consent"));
        (c,) = auth.authorize(address(authority), true, 0);
        require(c == keccak256("consent") && auth.consumed(c), "required consumes original book");
        _mustFail(
            address(auth),
            abi.encodeCall(auth.authorize, (address(authority), true, bytes32(0))),
            Auth.ArtistContentConsentConsumed.selector
        );
    }

    function testRequiredRatificationAndEvolutionRetainOriginalChecks() public {
        authority.configure(
            1,
            address(this),
            true,
            keccak256("old"),
            keccak256("ratification"),
            keccak256("consent")
        );
        _mustFail(
            address(auth),
            abi.encodeCall(auth.authorize, (address(authority), true, keccak256("wrong"))),
            Auth.ArtistContentEvolutionBroken.selector
        );
        (bytes32 c, bytes32 r) = auth.authorize(address(authority), true, keccak256("old"));
        auth.recordApplication(c, r, keccak256("new"));
        authority.configure(1, address(this), true, keccak256("old"), r, keccak256("second"));
        auth.authorize(address(authority), true, keccak256("new"));
    }

    function testRevisionZeroExactLegacyAndTwoScopesRemainInStaticFamily() public {
        require(records.family() == records.legacy(), "zero revision old bytes");
        bytes32 old = records.family();
        V.Record memory a = _record(keccak256("scopeA"), 0);
        bytes32 first = records.commit(a, keccak256("consentA"));
        bytes32 one = records.family();
        require(one != old, "first fold");
        V.Record memory b = _record(keccak256("scopeB"), 0);
        records.commit(b, keccak256("consentB"));
        V.Aggregate memory aggregate = records.viewAdoptionAggregate(1);
        require(aggregate.revision == 2 && records.family() != one, "second scope fold");
        require(records.viewAdoptionHead(a.input.scope) == first, "first scope retained");
        records.staticChange(keccak256("later static config"));
        require(
            records.family()
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_RENDERER_CONFIG_WITH_VIEWS_V1"),
                        block.chainid,
                        address(records),
                        address(graph),
                        uint256(1),
                        records.legacy(),
                        aggregate
                    )
                ),
            "same aggregate after static write"
        );
    }

    function testOriginalRecordLiteralAndHistoricalBytesSurviveLaterHead() public {
        V.Record memory r = _record(keccak256("scope"), 0);
        bytes32 key = records.commit(r, keccak256("consent"));
        bytes memory original = records.viewAdoptionEncoded(key);
        V.Record memory saved = abi.decode(original, (V.Record));
        bytes32 actual = saved.recordHash;
        saved.recordHash = 0;
        require(
            actual
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_ADOPTION_RECORD_V1"),
                        block.chainid,
                        address(records),
                        address(graph),
                        saved
                    )
                ),
            "literal host/domain/full record"
        );
        r = _record(r.input.scope.scopeId, key);
        records.commit(r, keccak256("second"));
        require(
            keccak256(original) == keccak256(records.viewAdoptionEncoded(key)),
            "immutable historical bytes"
        );
    }

    function testZeroConsentWrongScopeAndStaleHeadRefuseWithoutWrites() public {
        V.Record memory r = _record(keccak256("scope"), 0);
        _mustFail(
            address(records),
            abi.encodeCall(records.commit, (r, bytes32(0))),
            V.InvalidViewAdoption.selector
        );
        bytes32 key = records.commit(r, keccak256("consent"));
        _mustFail(
            address(records),
            abi.encodeCall(records.commit, (r, keccak256("another"))),
            V.ViewAdoptionLineage.selector
        );
        r.input.scope.scopeType = StreamFinalityScopeType.RELEASE;
        _mustFail(
            address(records),
            abi.encodeCall(records.commit, (r, keccak256("third"))),
            V.InvalidViewAdoption.selector
        );
        r.input.scope.scopeType = StreamFinalityScopeType.VIEW;
        require(records.viewAdoptionHead(r.input.scope) == key, "no partial head");
    }

    function testActualViewRendererFullContextAndEndTagEscaping() public {
        bytes32 key = records.commit(_record(keccak256("scope"), 0), keccak256("consent"));
        R.RenderRequest memory r = _request(key);
        string memory html = renderer.renderView(r, 3);
        string memory json = renderer.renderView(r, 2);
        require(
            _has(bytes(html), bytes('"collectionSerial":"7"'))
                && _has(bytes(html), bytes('"tokenData":"0x112200ff"'))
                && _has(bytes(html), bytes("<\\/ScRiPtX>")),
            "full original facts/end tag"
        );
        require(
            _has(bytes(json), bytes('"artist_attribution":{"state":"active"}'))
                && _has(bytes(json), bytes("data:text/html;base64,")),
            "actual JSON/AA"
        );
    }

    function testIdentityMembershipAndTerminalStatusRefuseRestore() public {
        bytes32 key = records.commit(_record(keccak256("scope"), 0), keccak256("consent"));
        R.RenderRequest memory r = _request(key);
        graph.configure(address(records), 8, 5, false, true);
        _mustFail(
            address(renderer),
            abi.encodeCall(renderer.renderView, (r, uint8(2))),
            V.InvalidViewAdoption.selector
        );
        graph.configure(address(records), 7, 2, false, true);
        _mustFail(
            address(renderer),
            abi.encodeCall(renderer.renderView, (r, uint8(3))),
            V.InvalidViewAdoption.selector
        );
        graph.configure(address(records), 7, 5, false, false);
        _mustFail(
            address(renderer),
            abi.encodeCall(renderer.renderView, (r, uint8(2))),
            V.InvalidViewAdoption.selector
        );
        graph.configure(address(records), 7, 5, false, true);
        require(bytes(renderer.renderView(r, 3)).length > 0, "exact restore");
    }

    function testBurnedIdentityRetainedOnlyWithActualBurnedRequest() public {
        bytes32 key = records.commit(_record(keccak256("scope"), 0), keccak256("consent"));
        R.RenderRequest memory r = _request(key);
        graph.configure(address(records), 7, 5, true, true);
        _mustFail(
            address(renderer),
            abi.encodeCall(renderer.renderView, (r, uint8(2))),
            V.InvalidViewAdoption.selector
        );
        r.state = R.TokenRenderState.BURNED;
        require(bytes(renderer.renderView(r, 3)).length > 0, "original burned member");
    }

    function testLiveAttributionChangesJSONWithoutChangingRetainedPayload() public {
        bytes32 key = records.commit(_record(keccak256("scope"), 0), keccak256("consent"));
        R.RenderRequest memory r = _request(key);
        bytes32 old = keccak256(bytes(renderer.renderView(r, 2)));
        bytes32 saved = keccak256(records.viewAdoptionEncoded(key));
        graph.changeAttribution('{"state":"standing_conflict"}');
        require(
            keccak256(bytes(renderer.renderView(r, 2))) != old
                && saved == keccak256(records.viewAdoptionEncoded(key)),
            "live annotation, same history"
        );
    }

    function testPayloadCorruptionRefusesAndExactRestore() public {
        V.Record memory r = _record(keccak256("scope"), 0);
        bytes32 key = records.commit(r, keccak256("consent"));
        address pointer = r.source.payloadPointers[0];
        bytes memory code = pointer.code;
        vm.etch(pointer, hex"0001");
        _mustFail(
            address(renderer),
            abi.encodeCall(renderer.renderView, (_request(key), uint8(3))),
            V.ViewAdoptionChunk.selector
        );
        vm.etch(pointer, code);
        require(bytes(renderer.renderView(_request(key), 3)).length > 0, "restored exact carrier");
    }

    function testPayloadSchemaCanonicalAndURIControls() public {
        bytes memory good = abi.encode(V.Payload(V.CONTEXT, "name", "", "", bytes("1")));
        records.payload(good);
        _mustFail(
            address(records),
            abi.encodeCall(records.payload, (bytes.concat(good, bytes32(0)))),
            V.InvalidViewAdoption.selector
        );
        _mustFail(
            address(records),
            abi.encodeCall(
                records.payload, (abi.encode(V.Payload(bytes32(0), "name", "", "", bytes("1"))))
            ),
            V.InvalidViewAdoption.selector
        );
        (bool ok,) = address(records)
            .call(
                abi.encodeCall(
                    records.payload,
                    (abi.encode(
                            V.Payload(V.CONTEXT, "name", "", "javascript:alert(1)", bytes("1"))
                        ))
                )
            );
        require(!ok, "original URI safety");
    }

    function testFuzzRecordDomainFullScopeAndHost(bytes32 scopeId, bytes32 consent) public {
        if (scopeId == 0 || consent == 0) return;
        V.Record memory r = _record(scopeId, 0);
        bytes32 key = records.commit(r, consent);
        V.Record memory saved = abi.decode(records.viewAdoptionEncoded(key), (V.Record));
        saved.recordHash = 0;
        require(
            key
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_ADOPTION_RECORD_V1"),
                        block.chainid,
                        address(records),
                        address(graph),
                        saved
                    )
                ),
            "literal exact record"
        );
        require(
            key
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_ADOPTION_RECORD_V1"),
                        block.chainid,
                        address(this),
                        address(graph),
                        saved
                    )
                ),
            "actual host domain"
        );
    }

    function testFixedHistoricalForwarderPreservesCanonicalRendererBytes() public {
        bytes32 key = records.commit(_record(keccak256("scope"), 0), keccak256("consent"));
        R.RenderRequest memory r = _request(key);
        require(
            keccak256(bytes(records.historicalTokenJSONForView(11, key)))
                == keccak256(bytes(renderer.renderView(r, 2))),
            "exact fixed JSON transport"
        );
        require(
            keccak256(bytes(records.historicalTokenHTMLForView(11, key)))
                == keccak256(bytes(renderer.renderView(r, 3))),
            "exact fixed HTML transport"
        );
        graph.configure(address(records), 7, 5, true, true);
        r.state = R.TokenRenderState.BURNED;
        require(
            keccak256(bytes(records.historicalTokenHTMLForView(11, key)))
                == keccak256(bytes(renderer.renderView(r, 3))),
            "same burned record transport"
        );
    }

    function testFixedDispatcherUnknownSelectorAndMalformedCarrierRefuse() public {
        (bool ok, bytes memory failure) = address(Routing)
            .staticcall(
                abi.encodeWithSelector(
                    Routing.serveEncoded.selector,
                    abi.encodeWithSignature(
                        "unrecognized(uint256,bytes32)", uint256(11), bytes32(0)
                    )
                )
            );
        require(
            !ok && failure.length >= 4 && bytes4(failure) == V.InvalidViewAdoption.selector,
            "closed selectors"
        );
        bytes32 key = records.commit(_record(keccak256("scope"), 0), keccak256("consent"));
        (address pointer, bytes32 digest, uint32 size) = records.viewAdoptionCarrier(key);
        bytes memory encoded = records.viewAdoptionEncoded(key);
        require(
            keccak256(encoded) == digest && encoded.length == size, "direct descriptor/full bytes"
        );
        bytes memory original = pointer.code;
        vm.etch(pointer, hex"0001");
        _mustFail(
            address(records),
            abi.encodeCall(records.viewAdoptionEncoded, (key)),
            V.ViewAdoptionChunk.selector
        );
        _mustFail(
            address(renderer),
            abi.encodeCall(renderer.renderView, (_request(key), uint8(3))),
            V.ViewAdoptionChunk.selector
        );
        vm.etch(pointer, original);
        require(keccak256(records.viewAdoptionEncoded(key)) == digest, "same immutable restoration");
    }

    function _has(bytes memory haystack, bytes memory needle) private pure returns (bool) {
        if (needle.length > haystack.length) return false;
        for (uint256 i; i <= haystack.length - needle.length; ++i) {
            bool same = true;
            for (uint256 j; j < needle.length; ++j) {
                if (haystack[i + j] != needle[j]) {
                    same = false;
                    break;
                }
            }
            if (same) return true;
        }
        return false;
    }
}
