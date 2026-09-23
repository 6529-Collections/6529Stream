// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewCheckpointFixtureV2.sol";
import {
    StreamViewPreservationRendererV1 as Adapter
} from "../../../smart-contracts/domains/metadata/StreamViewPreservationRendererV1.sol";
import {
    IStreamViewPreservationRendererV1 as API
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";

import {
    StreamFinalityViewPolicySourceReadsV2 as OriginalCurrent
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPolicySourceReadsV2.sol";

contract PreservationRetainedProbe {
    function retained(API.Configuration memory c, bytes32 key)
        external
        view
        returns (V.Record memory)
    {
        OriginalCurrent.Dependencies memory d;
        d.targets[0] = c.core;
        d.targets[1] = c.router;
        d.codeHashes[0] = c.coreCodeHash;
        d.codeHashes[1] = c.routerCodeHash;
        d.chainId = c.chainId;
        d.readGas = 1000000;
        return OriginalCurrent.retained(d, key);
    }
}

contract PreservationWriteProbe {
    uint256 public writes;

    fallback() external {
        ++writes;
        (,, bytes32 viewScope,,,) =
            abi.decode(msg.data[4:], (API.Configuration, uint256, bytes32, bool, uint8, uint256));
        // Valid successful output is essential: CALL/DELEGATECALL must not fail later decoding.
        bytes memory out = abi.encode(
            keccak256("malicious successful record"),
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, viewScope),
            string("{}")
        );
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }
}

/// @dev Actual original Renderer/State/Store/formatter, typed preservation attribution and surrounding
/// source/Registry/Artist/Core. No actual sanction, original op17 or finality ceremony is claimed.
contract StreamViewPreservationRendererV1Test is ViewCheckpointFixtureV2 {
    PolicyViewWire private preservation;

    function _adapter() private returns (Adapter a) {
        preservation = new PolicyViewWire();
        _answer(preservation, "core()", "", abi.encode(address(core)));
        _answer(preservation, "router()", "", abi.encode(address(records)));
        _answer(preservation, "liveAttribution()", "", abi.encode(address(attribution)));
        _answer(
            preservation, "liveAttributionCodeHash()", "", abi.encode(address(attribution).codehash)
        );
        _answer(
            preservation,
            "preservationAttributionProfile()",
            "",
            abi.encode(keccak256("6529STREAM_NON_SANCTION_ATTRIBUTION_V1"))
        );
        _preserved(bytes('{"state":"typed_live"}'));
        a = new Adapter(
            API.Configuration(
                address(core),
                address(core).codehash,
                address(records),
                address(records).codehash,
                address(preservation),
                address(preservation).codehash,
                block.chainid,
                8000000,
                1000000
            )
        );
    }

    function _preserved(bytes memory value) private {
        _answer(
            preservation,
            "preservationAttribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            abi.encode(value)
        );
    }

    function _live(bytes memory value) private {
        _answer(
            attribution,
            "attribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            abi.encode(value)
        );
    }

    function _eq(string memory a, string memory b) private pure {
        require(keccak256(bytes(a)) == keccak256(bytes(b)), "literal complete output");
    }

    function _refuses(Adapter a) private view {
        (bool ok,) = address(a).staticcall(abi.encodeCall(a.preservationViewJSON, (scope, 11)));
        require(!ok, "required refusal");
    }

    function testStableConstructorBeforePerPlanRendererAndExactFourOutputs() public {
        _pointer("METADATA_ROUTER", address(records));
        Adapter a = _adapter();
        (Renderer r, bytes32 key) = _view();
        (bytes32 actual, string memory json) = a.preservationViewJSON(scope, 11);
        require(actual == key);
        _eq(json, r.renderPolicyView(_request(key, 0, false), 2));
        (, string memory html) = a.preservationViewHTML(scope, 11);
        _eq(html, r.renderPolicyView(_request(key, 0, false), 3));
        (StreamFinalityScope memory observed, string memory old) =
            a.historicalPreservationViewJSON(key, 11);
        require(keccak256(abi.encode(observed)) == keccak256(abi.encode(scope)));
        _eq(json, old);
        (, old) = a.historicalPreservationViewHTML(key, 11);
        _eq(html, old);
        API.Binding memory b = a.preservationViewBinding(key);
        require(
            keccak256(abi.encode(b))
                == keccak256(
                    abi.encode(
                        address(core),
                        address(records),
                        address(r),
                        address(r).codehash,
                        address(preservation),
                        address(preservation).codehash
                    )
                )
        );
        (address worker, bytes32 workerHash) = a.workerBinding();
        (address encoder, bytes32 encoderHash) = a.encodingBinding();
        require(
            a.configurationHash()
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1"),
                        block.chainid,
                        address(a),
                        a.configuration(),
                        worker,
                        workerHash,
                        encoder,
                        encoderHash
                    )
                )
        );
    }

    function testTypedSanctionProjectionOnlyAndOtherFactsRemainLive() public {
        (Renderer r, bytes32 key) = _view();
        Adapter a = _adapter();
        (, string memory before_) = a.preservationViewJSON(scope, 11);
        _live(bytes('{"state":"artist_sanctioned","sanction":"typed sanction"}'));
        (, string memory after_) = a.preservationViewJSON(scope, 11);
        _eq(before_, after_);
        require(
            keccak256(bytes(after_))
                != keccak256(bytes(r.renderPolicyView(_request(key, 0, false), 2)))
        );
        bytes memory changed =
            bytes('{"state":"typed_live","standing_conflict":"retained adverse fact"}');
        _preserved(changed);
        _live(changed);
        (, after_) = a.preservationViewJSON(scope, 11);
        require(keccak256(bytes(after_)) != keccak256(bytes(before_)));
        _eq(after_, r.renderPolicyView(_request(key, 0, false), 2));
        require(_contains(after_, "retained adverse fact"));
    }

    function testOriginalTokenDataAndHTMLChangesStillChangePreservation() public {
        (Renderer r, bytes32 key) = _view();
        Adapter a = _adapter();
        (, string memory before_) = a.preservationViewJSON(scope, 11);
        _answer(
            core,
            "tokenData(uint256)",
            abi.encode(uint256(11)),
            abi.encode(bytes("changed complete token data"))
        );
        (, string memory changed) = a.preservationViewJSON(scope, 11);
        require(keccak256(bytes(before_)) != keccak256(bytes(changed)));
        _eq(changed, r.renderPolicyView(_request(key, 0, false), 2));
        (, string memory html) = a.preservationViewHTML(scope, 11);
        _eq(html, r.renderPolicyView(_request(key, 0, false), 3));
    }

    function testAttributionBindingProfileAndFailedBytesNeverFallback() public {
        _view();
        Adapter a = _adapter();
        a.preservationViewJSON(scope, 11);
        _answer(preservation, "liveAttribution()", "", abi.encode(address(core)));
        _refuses(a);
        _answer(preservation, "liveAttribution()", "", abi.encode(address(attribution)));
        _answer(
            preservation, "preservationAttributionProfile()", "", abi.encode(bytes32(uint256(9)))
        );
        _refuses(a);
        _answer(
            preservation,
            "preservationAttributionProfile()",
            "",
            abi.encode(keccak256("6529STREAM_NON_SANCTION_ATTRIBUTION_V1"))
        );
        _preserved("");
        _refuses(a);
        _answer(
            preservation,
            "preservationAttribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            hex"1234"
        );
        _refuses(a);
        _preserved(bytes('{"state":"typed_live"}'));
        a.preservationViewJSON(scope, 11);
        bytes memory code = address(preservation).code;
        vm.etch(address(preservation), hex"00");
        _refuses(a);
        vm.etch(address(preservation), code);
        a.preservationViewJSON(scope, 11);
    }

    function testCurrentBurnedExactRefusalAndRetainedCompletedIdentity() public {
        (Renderer r, bytes32 key) = _view();
        Adapter a = _adapter();
        a.preservationViewJSON(scope, 11);
        _identity(3, true, 7);
        (bool ok, bytes memory reason) =
            address(a).staticcall(abi.encodeCall(a.preservationViewJSON, (scope, 11)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(V.InvalidViewAdoption.selector))
        );
        (, string memory old) = a.historicalPreservationViewJSON(key, 11);
        _eq(old, r.renderPolicyView(_request(key, 0, true), 2));
        _identity(2, false, 7);
        a.preservationViewJSON(scope, 11);
    }

    function testClosedTagHeadScopeAndSourceDriftRestore() public {
        (, bytes32 key) = _view();
        Adapter a = _adapter();
        a.preservationViewJSON(scope, 11);
        records.forceTag(key, 0);
        _refuses(a);
        records.forceTag(key, T.PROFILE);
        _answer(
            core,
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), VIEW_ID),
            abi.encode(bytes32(uint256(9)), false)
        );
        _refuses(a);
        a.historicalPreservationViewJSON(key, 11);
        _answer(
            core,
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), VIEW_ID),
            abi.encode(VIEW_RECORD, false)
        );
        a.preservationViewJSON(scope, 11);
        StreamFinalityScope memory wrong =
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, scope.scopeId);
        (bool ok,) = address(a).staticcall(abi.encodeCall(a.preservationViewJSON, (wrong, 11)));
        require(!ok);
        _pointer("ARTWORK_FINALITY_REGISTRY", address(sourceSet));
        _refuses(a);
        _pointer("ARTWORK_FINALITY_REGISTRY", address(core));
        a.preservationViewJSON(scope, 11);
    }

    function testTerminalOptionalFinalizedLegacyRemainExact() public {
        for (uint8 i; i < 3; ++i) {
            if (i == 0) {
                _policy(2, 1, true);
                _facts(2, 0, 0);
            } else if (i == 1) {
                _policy(2, 0, true);
                _facts(5, keccak256("seed"), keccak256("request"));
            } else {
                _policy(0, 0, false);
                _facts(5, keccak256("seed"), 0);
            }
            (Renderer r, bytes32 key) = _view();
            Adapter a = _adapter();
            (, string memory actual) = a.preservationViewJSON(scope, 11);
            _eq(
                actual,
                r.renderPolicyView(_request(key, i == 0 ? bytes32(0) : keccak256("seed"), false), 2)
            );
        }
    }

    function testConstructorDomainAndFixedWorkerRestoration() public {
        _view();
        Adapter a = _adapter();
        API.Configuration memory c = a.configuration();
        c.routerCodeHash = keccak256("wrong");
        vm.expectRevert(abi.encodeWithSelector(V.ViewAdoptionDependency.selector, address(records)));
        new Adapter(c);
        c = a.configuration();
        vm.chainId(c.chainId + 1);
        _refuses(a);
        vm.chainId(c.chainId);
        (address worker,) = a.workerBinding();
        bytes memory code = worker.code;
        vm.etch(worker, hex"00");
        _refuses(a);
        vm.etch(worker, code);
        a.preservationViewJSON(scope, 11);
        (address encoder,) = a.encodingBinding();
        code = encoder.code;
        vm.etch(encoder, hex"00");
        _refuses(a);
        vm.etch(encoder, code);
        a.preservationViewJSON(scope, 11);
    }

    function testProducerDoesNotRecursivelyReadAdmittingRegistry() public {
        (Renderer renderer, bytes32 key) = _view();
        Adapter a = _adapter();
        V.Record memory saved = abi.decode(records.encoded(key), (V.Record));
        _answer(
            core,
            "requireRetained(bytes32)",
            abi.encode(saved.source.renderer.versionKey),
            hex"1234"
        );
        (, string memory value) = a.preservationViewJSON(scope, 11);
        _eq(value, renderer.renderPolicyView(_request(key, 0, false), 2));
        // Producer success is deliberately not admission. The old live dispatcher still enforces its Registry.
        (bool ok,) = address(records)
            .staticcall(
                abi.encodeWithSignature(
                    "tokenJSONForView(uint256,bytes32)", uint256(11), scope.scopeId
                )
            );
        require(!ok, "original live Registry refusal preserved");
    }

    function testIdentityBindingHasNoTimeEligibilityAndOriginalCurrentStillChecksTime() public {
        vm.warp(100);
        (, bytes32 key) = _view();
        Adapter a = _adapter();
        PreservationRetainedProbe original = new PreservationRetainedProbe();
        original.retained(a.configuration(), key);
        API.Binding memory before_ = a.preservationViewBinding(key);
        vm.warp(99);
        require(
            keccak256(abi.encode(before_)) == keccak256(abi.encode(a.preservationViewBinding(key)))
        );
        API.Configuration memory c = a.configuration();
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        original.retained(c, key);
        vm.warp(100);
        original.retained(c, key);
    }

    function testFixedHostWorkerCannotWriteEvenFromOrdinaryCall() public {
        _view();
        Adapter genuine = _adapter();
        (address worker,) = genuine.workerBinding();
        bytes memory original = worker.code;
        PreservationWriteProbe malicious = new PreservationWriteProbe();
        bytes memory validInput = abi.encodePacked(
            bytes4(keccak256("typed test worker control")),
            abi.encode(
                genuine.configuration(),
                uint256(11),
                scope.scopeId,
                false,
                uint8(2),
                uint256(1000000)
            )
        );
        (bool controlOK, bytes memory control) = address(malicious).call(validInput);
        (
            bytes32 returnedRecord,
            StreamFinalityScope memory returnedScope,
            string memory returnedOutput
        ) = abi.decode(control, (bytes32, StreamFinalityScope, string));
        require(controlOK && malicious.writes() == 1, "nonstatic control writes and returns");
        require(
            returnedRecord != 0
                && keccak256(abi.encode(returnedScope)) == keccak256(abi.encode(scope))
                && keccak256(bytes(returnedOutput)) == keccak256("{}"),
            "control passes host decoding"
        );
        vm.etch(worker, address(malicious).code);
        // A new test-only host records that altered runtime; production admission is not claimed.
        Adapter testHost = _adapter();
        (bool ok,) = address(testHost).call{ gas: 3000000 }(
            abi.encodeCall(testHost.preservationViewJSON, (scope, 11))
        );
        require(!ok && PreservationWriteProbe(worker).writes() == 0, "fixed worker is STATIC");
        vm.etch(worker, original);
        genuine.preservationViewJSON(scope, 11);
    }

    function _view() internal returns (Renderer renderer, bytes32 key) {
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
        r.source.route.finality = address(core);
        r.source.route.finalityCodeHash = address(core).codehash;
        r.source.route.metadata = address(core);
        r.source.route.metadataCodeHash = address(core).codehash;
        r.source.route.artist = address(core);
        r.source.route.artistCodeHash = address(core).codehash;
        r.source.route.provider = address(core);
        r.source.route.providerCodeHash = address(core).codehash;
        r.source.route.binding.views = address(core);
        r.source.route.binding.viewsCodeHash = address(core).codehash;
        r.source.route.binding.readGas = 1000000;
        r.source.route.binding.sourceGas = 2000000;
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
        r.input.rendererVersionKey = r.source.renderer.versionKey;
        _answer(
            core,
            "requireRetained(bytes32)",
            abi.encode(r.source.renderer.versionKey),
            abi.encode(address(renderer), address(renderer).codehash)
        );
        _pointer("METADATA_ROUTER", address(records));
        _pointer("COLLECTION_METADATA", address(core));
        _pointer("ARTIST_REGISTRY", address(core));
        _pointer("ARTWORK_FINALITY_REGISTRY", address(core));
        _answer(core, "scopeEvidenceProvider()", "", abi.encode(address(core)));
        _answer(core, "scopeEvidenceProviderCodeHash()", "", abi.encode(address(core).codehash));
        _answer(core, "viewSourceBinding()", "", abi.encode(r.source.route.binding));
        _answer(
            core,
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), VIEW_ID),
            abi.encode(VIEW_RECORD, false)
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
}
