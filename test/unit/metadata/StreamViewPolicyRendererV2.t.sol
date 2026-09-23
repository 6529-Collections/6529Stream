// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamViewPolicyStateV2.t.sol";
import {
    StreamViewAdoptionPolicyTransportV2 as Transport
} from "../../../smart-contracts/domains/metadata/StreamViewAdoptionPolicyTransportV2.sol";
import {
    StreamViewAdoptionRoutingV2 as PolicyRouting
} from "../../../smart-contracts/domains/metadata/StreamViewAdoptionRoutingV2.sol";
import {
    StreamViewAdoptionRouting as LegacyRouting
} from "../../../smart-contracts/domains/metadata/StreamViewAdoptionRouting.sol";
import {
    StreamMetadataDisplayParameters as Parameters
} from "../../../smart-contracts/domains/metadata/StreamMetadataDisplayParameters.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamViewRendererV2 as Renderer
} from "../../../smart-contracts/domains/metadata/StreamViewRendererV2.sol";
import {
    StreamViewRendererFormatV2 as Format
} from "../../../smart-contracts/domains/metadata/StreamViewRendererFormatV2.sol";
import {
    StreamViewPolicySourceV2 as Source
} from "../../../smart-contracts/domains/metadata/StreamViewPolicySourceV2.sol";
import {
    StreamViewPolicyContextV2 as Context
} from "../../../smart-contracts/domains/metadata/StreamViewPolicyContextV2.sol";
import {
    StreamViewPayloadBytes as PayloadBytes
} from "../../../smart-contracts/domains/metadata/StreamViewPayloadBytes.sol";
import {
    IStreamRenderer as R
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamFinalityCoordinatorPolicyV2 as Rule
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import {
    StreamEntropyPolicyConsumerTypes as E
} from "../../../smart-contracts/interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Set
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";
import { Strings } from "../../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @dev Explicit typed source boundary. No factory, coordinator, Core or governed Registry claim.
contract PolicyViewWire {
    mapping(bytes32 => bytes) private responses;
    mapping(bytes32 => bool) private known;

    function answer(bytes memory query, bytes memory value) external {
        responses[keccak256(query)] = value;
        known[keccak256(query)] = true;
    }

    fallback() external {
        require(known[keccak256(msg.data)], "unconfigured source");
        bytes memory value = responses[keccak256(msg.data)];
        assembly ("memory-safe") { return(add(value, 32), mload(value)) }
    }
}

contract PolicyViewRecordProbe is TaggedViewStateProbe {
    Store public immutable store;

    constructor(address c, Store s) TaggedViewStateProbe(c) {
        store = s;
        Parameters.initialize(address(this));
    }

    function payload(bytes memory raw) external returns (V.Source memory s) {
        for (uint256 offset; offset < raw.length; offset += 8192) {
            uint256 size = raw.length - offset;
            if (size > 8192) size = 8192;
            bytes memory part = new bytes(size);
            for (uint256 j; j < size; ++j) {
                part[j] = raw[offset + j];
            }
            store.publishChunk(part);
        }
        PayloadBytes.capture(address(store), raw, s);
    }

    function viewAdoptionCarrier(bytes32 key) external view returns (address, bytes32, uint32) {
        Original.Carrier storage c = Original.state().records[key];
        return (c.pointer, c.hash, c.size);
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

    function tokenHTMLForView(uint256, bytes32) external view returns (string memory) {
        _serve();
    }

    function _serve() private view {
        bytes memory raw = Transport.serve(
            core, address(LegacyRouting).codehash, address(PolicyRouting).codehash, msg.data
        );
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function viewAdoptionProfile(bytes32 key) external view returns (bytes32) {
        return Policy.profile(key);
    }
}

contract PolicyViewTokenProbe {
    function token(address core, uint256 id, uint256 cid, Rule memory rule)
        external
        view
        returns (T.Entropy memory)
    {
        return Source.token(core, id, cid, rule, 1000000);
    }

    function context(T.Entropy memory facts) external pure returns (string memory) {
        return Context.encode(facts);
    }
}

/// @notice Actual V2 renderer, internal STATIC helpers and original Store/State carriers.
/// @dev Complete source/factory/Core/entropy/Artist replies are typed boundaries. No actual
/// Source.prepare, governed renderer admission, Artist op17 or combined finality ceremony.
contract StreamViewPolicyRendererV2Test is CharacterizationTestBase {
    PolicyViewWire private core;
    PolicyViewWire private factory;
    PolicyViewWire private sourceSet;
    PolicyViewWire private coordinator;
    PolicyViewWire private attribution;
    PolicyViewRecordProbe private records;
    PolicyViewTokenProbe private probe;
    Store private store;
    StreamFinalityScope private scope;
    StreamScopeMembershipFacts private membership;
    Rule private rule;
    bytes32 private constant PLAN = keccak256("typed complete inventory plan");
    bytes32 private constant VIEW_ID = keccak256("declared view identity distinct from membership");
    bytes32 private constant VIEW_RECORD = keccak256("typed declared view receipt");

    function setUp() public {
        vm.warp(2000000000);
        core = new PolicyViewWire();
        factory = new PolicyViewWire();
        sourceSet = new PolicyViewWire();
        coordinator = new PolicyViewWire();
        attribution = new PolicyViewWire();
        store = new Store();
        records = new PolicyViewRecordProbe(address(core), store);
        probe = new PolicyViewTokenProbe();
        scope = StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 1, 0, keccak256("sealed membership identity")
        );
        membership.scopeSubject = keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_SCOPE_V1"),
                block.chainid,
                address(core),
                uint256(1),
                uint8(4),
                scope.scopeId
            )
        );
        membership.scopeManifestHash = keccak256("scope manifest");
        membership.sourceRecordHash = keccak256("membership record");
        membership.membershipHash = keccak256("whole membership");
        membership.tokenListHash = keccak256(abi.encode(uint256(11)));
        membership.tokenCount = 1;
        _answer(
            factory,
            "supportsInterface(bytes4)",
            abi.encode(type(Factory).interfaceId),
            abi.encode(true)
        );
        _answer(
            factory,
            "scopedPolicyFactoryProfile()",
            "",
            abi.encode(keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2"))
        );
        _answer(factory, "core()", "", abi.encode(address(core)));
        _answer(
            factory,
            "sourceSetForPlan(bytes32)",
            abi.encode(PLAN),
            abi.encode(address(sourceSet), address(sourceSet).codehash)
        );
        _answer(
            factory,
            "currentInventoryPlan((uint8,uint256,uint256,bytes32))",
            abi.encode(scope),
            abi.encode(PLAN)
        );
        _answer(
            sourceSet,
            "supportsInterface(bytes4)",
            abi.encode(type(Set).interfaceId),
            abi.encode(true)
        );
        _answer(
            sourceSet,
            "SOURCE_SET_PROFILE()",
            "",
            abi.encode(keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"))
        );
        _answer(sourceSet, "factory()", "", abi.encode(address(factory)));
        _answer(sourceSet, "core()", "", abi.encode(address(core)));
        _answer(sourceSet, "sourceScope()", "", abi.encode(scope));
        _answer(sourceSet, "inventoryPlan()", "", abi.encode(PLAN));
        _answer(
            sourceSet, "originalInventoryHash()", "", abi.encode(keccak256("complete inventory"))
        );
        _answer(
            sourceSet,
            "originalPolicyChainHash()",
            "",
            abi.encode(keccak256("complete policy roster"))
        );
        _answer(sourceSet, "requireCurrentSelection()", "", "");
        _answer(sourceSet, "scopeMembershipFacts()", "", abi.encode(membership));
        _answer(sourceSet, "sourceCount()", "", abi.encode(uint256(1)));
        _identity(2, false, 7);
        _answer(
            core,
            "coordinatorAtMint(uint256)",
            abi.encode(uint256(11)),
            abi.encode(address(coordinator))
        );
        _answer(core, "collectionFreezeStatus(uint256)", abi.encode(uint256(1)), abi.encode(false));
        _answer(core, "collectionSupplyMode(uint256)", abi.encode(uint256(1)), abi.encode(uint8(0)));
        _answer(core, "collectionStatus(uint256)", abi.encode(uint256(1)), abi.encode(uint8(0)));
        _answer(core, "tokenData(uint256)", abi.encode(uint256(11)), abi.encode(hex"00f1ff00"));
        _answer(
            core,
            "scopeCoversToken((uint8,uint256,uint256,bytes32),uint256)",
            abi.encode(scope, uint256(11)),
            abi.encode(true)
        );
        _answer(coordinator, "core()", "", abi.encode(address(core)));
        _answer(
            coordinator,
            "supportsInterface(bytes4)",
            abi.encode(E.STATIC_CAPABILITY),
            abi.encode(true)
        );
        _answer(attribution, "core()", "", abi.encode(address(core)));
        _answer(attribution, "router()", "", abi.encode(address(records)));
        _answer(
            attribution,
            "attribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            abi.encode(bytes('{"state":"typed_live"}'))
        );
        rule.coordinator = address(coordinator);
        rule.indexedCodeHash = address(coordinator).codehash;
        rule.moduleVersion = keccak256("version");
        rule.moduleManifestHash = keccak256("manifest");
        rule.moduleSchemaHash = keccak256("schema");
        rule.deploymentManifestHash = keccak256("deployment");
        rule.policyHash = keccak256("full H");
        rule.componentDataHash = keccak256("component");
        rule.frozen = true;
        _policy(0, 1, true);
        _facts(1, 0, 0);
    }

    function _answer(
        PolicyViewWire target,
        string memory signature,
        bytes memory args,
        bytes memory response
    ) private {
        target.answer(bytes.concat(bytes4(keccak256(bytes(signature))), args), response);
    }

    function _identity(uint8 lifecycle, bool burned, uint256 serial) private {
        _answer(
            core,
            "tokenCollectionIdentity(uint256)",
            abi.encode(uint256(11)),
            abi.encode(true, uint256(1), serial, burned)
        );
        _answer(core, "tokenLifecycle(uint256)", abi.encode(uint256(11)), abi.encode(lifecycle));
    }

    function _policy(uint8 mode, uint8 requirement, bool explicit_) private {
        rule.explicitPolicy = explicit_;
        E.Policy memory h;
        if (explicit_) {
            h = E.Policy(
                true,
                true,
                true,
                mode,
                1,
                requirement,
                3,
                4,
                rule.policyHash,
                keccak256(abi.encode(E.FAMILY, rule.policyHash, true)),
                keccak256("action"),
                keccak256("Artist consent")
            );
            rule.provider = address(0);
            rule.epoch = 0;
            rule.salt = 0;
        } else {
            rule.provider = address(0x991);
            rule.epoch = 2;
            rule.salt = keccak256("legacy salt");
        }
        rule.collectionPolicy = h;
        _answer(sourceSet, "sourcePolicyAt(uint256)", abi.encode(uint256(0)), abi.encode(rule));
    }

    function _facts(uint8 status, bytes32 seed, bytes32 request) private {
        _answer(
            coordinator,
            "staticTerminalEntropyFacts(uint256)",
            abi.encode(uint256(11)),
            abi.encode(uint256(1), rule.collectionPolicy, status, seed, request)
        );
        _answer(
            coordinator,
            "staticTokenRenderFacts(uint256)",
            abi.encode(uint256(11)),
            abi.encode(status, seed, address(0x992))
        );
    }

    function _renderer() private returns (Renderer renderer, bytes32 key) {
        R.RendererManifest memory m = R.RendererManifest(
            Format.ID,
            Format.VERSION,
            T.CONTEXT,
            keccak256("STATIC"),
            Format.schemaHash(),
            "",
            "",
            keccak256("typed manifest"),
            262144,
            262144,
            false
        );
        renderer = new Renderer(
            [address(core), address(records), address(sourceSet), address(attribution)],
            address(factory),
            scope,
            2000000,
            address(0),
            G.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 1000000, 50000, 2),
            G.GasParameterConfig("STATIC_ATTRIBUTION_GAS", 1000000, 50000, 2),
            m
        );
        V.Record memory r;
        r.input.scope = scope;
        r.input.viewId = VIEW_ID;
        r.input.viewRecordHash = VIEW_RECORD;
        r.input.expectedPrevious = records.head(scope);
        r.source = records.payload(
            abi.encode(
                V.Payload(
                    T.CONTEXT,
                    "policy view",
                    "full source",
                    "",
                    bytes("window.done=stream.entropy.terminal;")
                )
            )
        );
        r.source.route.core = address(core);
        r.source.route.coreCodeHash = address(core).codehash;
        r.source.route.router = address(records);
        r.source.route.routerCodeHash = address(records).codehash;
        r.source.route.store = address(store);
        r.source.route.storeCodeHash = address(store).codehash;
        r.source.route.binding.membership = address(core);
        r.source.route.binding.membershipCodeHash = address(core).codehash;
        r.source.membership = membership;
        r.source.renderer.renderer = address(renderer);
        r.source.renderer.rendererCodeHash = address(renderer).codehash;
        r.source.renderer.contextVersion = T.CONTEXT;
        r.source.renderer.registry = address(core);
        r.source.renderer.registryCodeHash = address(core).codehash;
        r.source.renderer.versionKey =
            keccak256(abi.encode("typed retained Registry version", address(renderer)));
        _answer(
            core,
            "requireRetained(bytes32)",
            abi.encode(r.source.renderer.versionKey),
            abi.encode(address(renderer), address(renderer).codehash)
        );
        r.sourceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_ADOPTION_SOURCE_V2"),
                T.PROFILE,
                block.chainid,
                address(records),
                r.input.scope,
                r.input.viewId,
                r.input.viewRecordHash,
                r.source,
                renderer.policyViewBinding()
            )
        );
        r.input.expectedSourceHash = r.sourceHash;
        r.actor = address(this);
        r.authorizationClass = 7;
        r.grantRevision = 1;
        key = records.write(r, keccak256("typed op17 consent"), true);
    }

    function _request(bytes32 key, bytes32 seed, bool burned)
        private
        view
        returns (R.RenderRequest memory)
    {
        return R.RenderRequest(
            address(core),
            11,
            1,
            7,
            seed,
            burned ? R.TokenRenderState.BURNED : R.TokenRenderState.ACTIVE,
            R.MetadataMode.ONCHAIN,
            0,
            0,
            VIEW_ID,
            VIEW_RECORD,
            key
        );
    }

    function _contains(string memory text, string memory part) private pure returns (bool) {
        bytes memory a = bytes(text);
        bytes memory b = bytes(part);
        if (b.length > a.length) return false;
        for (uint256 i; i <= a.length - b.length; ++i) {
            bool yes = true;
            for (uint256 j; j < b.length; ++j) {
                if (a[i + j] != b[j]) {
                    yes = false;
                    break;
                }
            }
            if (yes) return true;
        }
        return false;
    }

    function _fails(Renderer r, R.RenderRequest memory q) private view {
        (bool ok,) = address(r).staticcall(abi.encodeCall(r.renderPolicyView, (q, uint8(3))));
        require(!ok, "source mismatch must refuse");
    }

    function testActualRendererTerminalContextKeepsOriginalTokenSerialAndFullH() public {
        (Renderer r, bytes32 key) = _renderer();
        string memory html = r.renderPolicyView(_request(key, 0, false), 3);
        require(_contains(html, '"tokenId":"11","collectionSerial":"7"'));
        require(_contains(html, '"tokenData":"0x00f1ff00"'));
        require(_contains(html, '"kind":"EXPLICIT_POLICY_V2"'));
        require(_contains(html, '"status":1'));
        require(_contains(html, '"finalized":false,"terminal":true'));
        require(
            _contains(
                html,
                '"mode":0,"securityClass":1,"renderRequirement":1,"revision":"3","providerEpoch":"4"'
            )
        );
        require(
            _contains(
                html,
                string.concat(
                    '"artistConsentRecord":"',
                    Strings.toHexString(uint256(keccak256("Artist consent")), 32),
                    '"'
                )
            )
        );
        require(
            _contains(
                r.renderPolicyView(_request(key, 0, false), 2),
                '"artist_attribution":{"state":"typed_live"}'
            )
        );
    }

    function testOptionalTerminalAndFinalizedEntropyAreSeparateActualBranches() public {
        _policy(2, 1, true);
        _facts(2, 0, 0);
        (Renderer r, bytes32 key) = _renderer();
        require(_contains(r.renderPolicyView(_request(key, 0, false), 3), '"status":2'));
        _policy(2, 0, true);
        bytes32 seed = keccak256("actual typed finalized seed");
        _facts(5, seed, keccak256("request"));
        (Renderer r2, bytes32 key2) = _renderer();
        string memory html = r2.renderPolicyView(_request(key2, seed, false), 3);
        require(_contains(html, '"finalized":true,"terminal":false'));
        _facts(3, 0, keccak256("request"));
        _fails(r2, _request(key2, 0, false));
        _facts(5, seed, keccak256("request"));
        r2.renderPolicyView(_request(key2, seed, false), 3);
    }

    function testPreparedIdentityRefusesAndBurnedHistoricalRenderingUsesSameRealIdentity() public {
        (Renderer r, bytes32 key) = _renderer();
        _identity(1, false, 7);
        _fails(r, _request(key, 0, false));
        _identity(3, true, 7);
        require(_contains(r.renderPolicyView(_request(key, 0, true), 3), '"collectionSerial":"7"'));
        _fails(r, _request(key, 0, false));
        _identity(2, false, 8);
        _fails(r, _request(key, 0, false));
        _identity(2, false, 7);
        r.renderPolicyView(_request(key, 0, false), 3);
    }

    function testEveryFullPolicyWordMismatchRefusesAndRestoresExactOutput() public {
        (Renderer r, bytes32 key) = _renderer();
        R.RenderRequest memory q = _request(key, 0, false);
        bytes32 original = keccak256(bytes(r.renderPolicyView(q, 3)));
        for (uint256 i; i < 12; ++i) {
            bytes memory encoded = abi.encode(rule.collectionPolicy);
            assembly ("memory-safe") {
                let at := add(add(encoded, 32), mul(i, 32))
                mstore(at, xor(mload(at), 1))
            }
            E.Policy memory bad = abi.decode(encoded, (E.Policy));
            _answer(
                coordinator,
                "staticTerminalEntropyFacts(uint256)",
                abi.encode(uint256(11)),
                abi.encode(uint256(1), bad, uint8(1), bytes32(0), bytes32(0))
            );
            _fails(r, q);
        }
        _facts(1, 0, 0);
        require(keccak256(bytes(r.renderPolicyView(q, 3))) == original);
    }

    function testTerminalSeedRequestAndOriginalAtMintCoordinatorCannotBeSubstituted() public {
        (Renderer r, bytes32 key) = _renderer();
        R.RenderRequest memory q = _request(key, 0, false);
        _facts(1, bytes32(uint256(1)), 0);
        _fails(r, q);
        _facts(1, 0, bytes32(uint256(1)));
        _fails(r, q);
        _facts(1, 0, 0);
        _answer(
            core,
            "coordinatorAtMint(uint256)",
            abi.encode(uint256(11)),
            abi.encode(address(attribution))
        );
        _fails(r, q);
        _answer(
            core,
            "coordinatorAtMint(uint256)",
            abi.encode(uint256(11)),
            abi.encode(address(coordinator))
        );
        r.renderPolicyView(q, 3);
    }

    function testLegacyFinalizedBranchDoesNotInventExplicitPolicyOrSelectedProviderEquality()
        public
    {
        _policy(0, 0, false);
        bytes32 seed = keccak256("legacy genuine typed seed");
        _facts(5, seed, 0);
        (Renderer r, bytes32 key) = _renderer();
        string memory html = r.renderPolicyView(_request(key, seed, false), 3);
        require(_contains(html, '"kind":"LEGACY_FINALIZED_V1"'));
        require(_contains(html, '"policy":null'));
        _facts(2, 0, 0);
        _fails(r, _request(key, 0, false));
        _facts(5, seed, 0);
        r.renderPolicyView(_request(key, seed, false), 3);
    }

    function testClosedTagAndActualPayloadCarrierCorruptionRefuseWithStableHistory() public {
        (Renderer r, bytes32 key) = _renderer();
        R.RenderRequest memory q = _request(key, 0, false);
        bytes32 before = keccak256(bytes(r.renderPolicyView(q, 3)));
        records.forceTag(key, 0);
        _fails(r, q);
        records.forceTag(key, T.PROFILE);
        V.Record memory saved = abi.decode(records.encoded(key), (V.Record));
        address pointer = saved.source.payloadPointers[0];
        bytes memory code = pointer.code;
        vm.etch(pointer, hex"00");
        _fails(r, q);
        vm.etch(pointer, code);
        require(keccak256(bytes(r.renderPolicyView(q, 3))) == before);
        require(keccak256(records.encoded(key)) == keccak256(abi.encode(saved)));
    }

    function testConstructorCannotAcceptDifferentScopeFactoryOrIncompleteCurrentPlan() public {
        _answer(
            factory,
            "sourceSetForPlan(bytes32)",
            abi.encode(PLAN),
            abi.encode(address(sourceSet), bytes32(uint256(1)))
        );
        vm.expectRevert();
        this.deployRenderer();
        _answer(
            factory,
            "sourceSetForPlan(bytes32)",
            abi.encode(PLAN),
            abi.encode(address(sourceSet), address(sourceSet).codehash)
        );
        StreamFinalityScope memory other = scope;
        other.scopeType = StreamFinalityScopeType.RELEASE;
        _answer(sourceSet, "sourceScope()", "", abi.encode(other));
        vm.expectRevert();
        this.deployRenderer();
        _answer(sourceSet, "sourceScope()", "", abi.encode(scope));
        _answer(
            factory,
            "currentInventoryPlan((uint8,uint256,uint256,bytes32))",
            abi.encode(scope),
            abi.encode(bytes32(uint256(1)))
        );
        vm.expectRevert();
        this.deployRenderer();
        _answer(
            factory,
            "currentInventoryPlan((uint8,uint256,uint256,bytes32))",
            abi.encode(scope),
            abi.encode(PLAN)
        );
        this.deployRenderer();
    }

    function testActualFixedHistoricalDispatchMatchesDirectOutputAndRejectsCrossTag() public {
        (Renderer renderer, bytes32 key) = _renderer();
        R.RenderRequest memory q = _request(key, 0, false);
        bytes32 expected = keccak256(bytes(renderer.renderPolicyView(q, 3)));
        require(keccak256(bytes(records.historicalTokenHTMLForView(11, key))) == expected);
        require(
            keccak256(bytes(records.historicalTokenJSONForView(11, key)))
                == keccak256(bytes(renderer.renderPolicyView(q, 2)))
        );
        records.forceTag(key, 0);
        (bool ok,) = address(records)
            .staticcall(abi.encodeCall(records.historicalTokenHTMLForView, (uint256(11), key)));
        require(!ok, "V2 cannot be decoded through V1 dispatch");
        records.forceTag(key, T.PROFILE);
        require(keccak256(bytes(records.historicalTokenHTMLForView(11, key))) == expected);
    }

    function testActualDispatcherRefusesBurnedCurrentButPreservesHistoricalIdentity() public {
        (Renderer renderer, bytes32 key) = _renderer();
        _identity(3, true, 7);
        (bool ok, bytes memory failure) = address(records)
            .staticcall(abi.encodeCall(records.tokenHTMLForView, (uint256(11), scope.scopeId)));
        require(
            !ok
                && keccak256(failure)
                    == keccak256(abi.encodeWithSelector(V.InvalidViewAdoption.selector)),
            "exact early burned refusal"
        );
        require(
            keccak256(bytes(records.historicalTokenHTMLForView(11, key)))
                == keccak256(bytes(renderer.renderPolicyView(_request(key, 0, true), 3)))
        );
        _identity(2, false, 7);
        records.historicalTokenHTMLForView(11, key);
    }

    function testFixedEncodingRuntimePinRefusesMutationThenExactRestore() public {
        (Renderer renderer, bytes32 key) = _renderer();
        (address encoding, bytes32 pin) = renderer.encodingBinding();
        require(encoding.code.length != 0 && encoding.codehash == pin);
        R.RenderRequest memory q = _request(key, 0, false);
        bytes32 expected = keccak256(bytes(renderer.renderPolicyView(q, 3)));
        bytes memory code = encoding.code;
        vm.etch(encoding, hex"00");
        vm.expectRevert(abi.encodeWithSelector(V.ViewAdoptionDependency.selector, encoding));
        renderer.renderPolicyView(q, 3);
        vm.etch(encoding, code);
        require(keccak256(bytes(renderer.renderPolicyView(q, 3))) == expected);
    }

    function deployRenderer() external returns (address) {
        (Renderer r,) = _renderer();
        return address(r);
    }
}
