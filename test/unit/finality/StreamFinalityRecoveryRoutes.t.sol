// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamFinalityRecoveryRoutes.sol";
import "../../helpers/RecoveryOriginalRecordFixture.sol";

interface RecoveryRoutesVm {
    function etch(address target, bytes calldata code) external;
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
}

contract RecoveryRouteMarker {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

contract RecoveryRoutesHost {
    StreamFinalityRecoveryState.State private state;
    StreamFinalityRecoveryBindings.Bound private bindings;

    constructor(StreamFinalityRecoveryBindings.Bound memory b) {
        bindings = b;
    }

    function resolve(bytes32 kind, StreamFinalityScope calldata scope)
        external
        view
        returns (StreamFinalityRecoveryRoutes.Selection memory)
    {
        return StreamFinalityRecoveryRoutes.resolve(state, bindings, kind, scope);
    }

    function append(
        StreamFinalityRecoveryRequest calldata request,
        StreamFinalityRecoveryState.Admission calldata a
    ) external {
        StreamFinalityRecoveryEvidenceSnapshot memory e;
        StreamFinalityRecoveryState.append(state, request, e, a);
    }

    function replacement(
        StreamFinalityComponentExpectation calldata r,
        StreamFinalityScope calldata s,
        bytes32 kind
    ) external view {
        StreamFinalityRecoveryRoutes.requireReplacement(r, s, kind, 2000000);
    }

    function matches(StreamFinalityComponentExpectation calldata r, StreamFinalityScope calldata s)
        external
        view
        returns (bool)
    {
        return StreamFinalityRecoveryRoutes.matches(r, s, 2000000);
    }
}

/// @dev Route composition with mutable historical-return and state-admission boundaries; no authority execution.
contract StreamFinalityRecoveryRoutesTest {
    RecoveryRoutesVm private constant vm =
        RecoveryRoutesVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ROUTE = bytes32(uint256(1));
    address private core;
    address private artist;
    address private coordinator;
    RecoveryOriginalRecordFixture private original;
    RecoveryRoutesHost private host;
    StreamFinalityComponentExpectation private route;

    function setUp() public {
        core = address(new RecoveryRouteMarker());
        artist = address(new RecoveryRouteMarker());
        coordinator = address(new RecoveryRouteMarker());
        original = new RecoveryOriginalRecordFixture(core, artist);
        StreamFinalityRecoveryBindings.Bound memory b;
        b.inputs = StreamFinalityRecoveryBindings.Inputs(
            core, coordinator, address(original), artist, coordinator, 2000000
        );
        b.coordinator = coordinator;
        b.suite.core = core;
        b.suite.registry = artist;
        b.suite.mintManager = address(0x44);
        b.suite.owners[6] = address(original);
        b.chainId = block.chainid;
        b.codeHashes = [
            core.codehash,
            artist.codehash,
            coordinator.codehash,
            address(original).codehash,
            address(original).codehash,
            coordinator.codehash,
            coordinator.codehash
        ];
        host = new RecoveryRoutesHost(b);
        address component = address(new RecoveryRouteMarker());
        route = StreamFinalityComponentExpectation(
            ROUTE,
            component,
            type(IStreamArtworkFinalityComponent).interfaceId,
            component.codehash,
            keccak256("version"),
            keccak256("manifest"),
            keccak256("data")
        );
    }

    function _scope(uint8 kind) private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(
            StreamFinalityScopeType(kind),
            7,
            kind == 1 ? 99 : 0,
            kind > 1 ? bytes32(uint256(88)) : bytes32(0)
        );
    }

    function _record(uint8 kind, bool duplicate, bool wrongSanctionInterface)
        private
        returns (bytes32 hash)
    {
        StreamFinalityScope memory scope = _scope(kind);
        S.Record memory sanction = S.Record(
            0,
            keccak256("saved artist"),
            address(0xA11CE),
            1,
            S.Terms(
                kind,
                7,
                scope.tokenId,
                scope.scopeId,
                keccak256("sanction subject"),
                keccak256("ceremony")
            ),
            1,
            1000,
            2000,
            3,
            keccak256("binding"),
            keccak256("digest")
        );
        sanction.recordHash = StreamArtistSanctionHashes.record(
            StreamArtistHashes.Environment(block.chainid, artist, core, address(0x44)), sanction
        );
        StreamFinalityComponentExpectation[] memory items =
            new StreamFinalityComponentExpectation[](duplicate ? 3 : 2);
        StreamFinalityComponentExpectation memory r = route;
        r.interfaceId = kind == 0
            ? type(IStreamArtworkFinalityComponent).interfaceId
            : type(IStreamArtworkScopedFinalityComponent).interfaceId;
        items[0] = abi.decode(abi.encode(r), (StreamFinalityComponentExpectation));
        if (duplicate) {
            r.dataHash = bytes32(uint256(r.dataHash) + 1);
            items[1] = r;
        }
        items[items.length - 1] = StreamFinalityComponentExpectation(
            keccak256("ARTIST_SANCTION"),
            artist,
            wrongSanctionInterface
                ? bytes4(0x11223344)
                : (kind == 0
                        ? type(IStreamArtworkFinalityComponent).interfaceId
                        : type(IStreamArtworkScopedFinalityComponent).interfaceId),
            artist.codehash,
            keccak256("artist version"),
            keccak256("artist manifest"),
            sanction.recordHash
        );
        hash = keccak256(abi.encode("original", kind, duplicate, wrongSanctionInterface));
        original.set(scope, hash, sanction, items);
    }

    function _token(bool exists, uint256 cid, bool burned) private {
        vm.mockCall(
            core,
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (99)),
            abi.encode(exists, cid, uint256(1), burned)
        );
        vm.mockCall(
            core,
            abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (99)),
            abi.encode(uint8(burned ? 3 : 2))
        );
    }

    function _append(
        StreamFinalityScope memory scope,
        StreamFinalityRecoveryRoutes.Selection memory selected,
        bytes32 id,
        bytes32 data
    ) private {
        StreamFinalityRecoveryRequest memory r;
        r.scope = scope;
        r.expectedOriginalFinalityRecordHash = selected.originalFinalityRecordHash;
        r.expectedPredecessorRecoveryId = selected.exactHead;
        r.expectedOldRouteHash = keccak256(abi.encode(selected.route));
        r.replacementRoute = route;
        r.replacementRoute.dataHash = data;
        r.replacementRoute.interfaceId = scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? type(IStreamArtworkFinalityComponent).interfaceId
            : type(IStreamArtworkScopedFinalityComponent).interfaceId;
        r.recoveryManifest = StreamFinalityManifestRef(
            "urn:recovery",
            keccak256("urn:recovery"),
            keccak256(abi.encode(id)),
            keccak256("schema"),
            keccak256("canonical")
        );
        r.reasonHash = keccak256("reason");
        host.append(
            r,
            StreamFinalityRecoveryState.Admission(
                id, selected.originalScope, r.expectedOldRouteHash, 100
            )
        );
    }

    function _reject(bytes memory input, bytes memory error) private {
        (bool ok, bytes memory result) = address(host).call(input);
        require(!ok && keccak256(result) == keccak256(error), "exact negative");
    }

    function testRecoveryRoutesExactOriginalAllFiveScopesAndMissingType() public {
        for (uint8 kind; kind < 5; ++kind) {
            bytes32 hash = _record(kind, false, false);
            StreamFinalityRecoveryRoutes.Selection memory s = host.resolve(ROUTE, _scope(kind));
            require(
                s.pinned && s.originalFinalityRecordHash == hash && s.recoveryId == 0
                    && s.exactHead == 0 && s.artistId == keccak256("saved artist"),
                "exact record"
            );
            require(
                keccak256(abi.encode(s.routeScope)) == keccak256(abi.encode(_scope(kind))),
                "exact health scope"
            );
        }
        StreamFinalityRecoveryRoutes.Selection memory absent =
            host.resolve(bytes32(uint256(999)), _scope(1));
        require(
            !absent.pinned && absent.originalFinalityRecordHash != 0,
            "missing route retains exact base"
        );
    }

    function testRecoveryRoutesCollectionInheritanceExactRecoveryAndPermanentPrecedence() public {
        bytes32 base = _record(0, false, false);
        _token(true, 7, true);
        StreamFinalityRecoveryRoutes.Selection memory c = host.resolve(ROUTE, _scope(0));
        _append(_scope(0), c, bytes32(uint256(1)), keccak256("collection replacement"));
        StreamFinalityRecoveryRoutes.Selection memory t = host.resolve(ROUTE, _scope(1));
        require(
            t.originalFinalityRecordHash == base && t.recoveryId == bytes32(uint256(1))
                && t.exactHead == 0 && t.exactGeneration == 0
                && t.routeScope.scopeType == StreamFinalityScopeType.COLLECTION,
            "inherited route and zero exact predecessor"
        );
        bytes32 exact = _record(1, false, false);
        t = host.resolve(ROUTE, _scope(1));
        require(
            t.originalFinalityRecordHash == exact && t.recoveryId == 0,
            "exact permanent suppresses collection recovery"
        );
        _append(_scope(1), t, bytes32(uint256(2)), keccak256("exact token replacement"));
        t = host.resolve(ROUTE, _scope(1));
        require(
            t.recoveryId == bytes32(uint256(2)) && t.exactHead == bytes32(uint256(2))
                && t.exactGeneration == 1
                && t.routeScope.scopeType == StreamFinalityScopeType.TOKEN,
            "exact replacement"
        );
    }

    function testRecoveryRoutesInheritedChainNeverRebasesToLaterExactRecord() public {
        bytes32 base = _record(0, false, false);
        _token(true, 7, false);
        StreamFinalityRecoveryRoutes.Selection memory t = host.resolve(ROUTE, _scope(1));
        _append(_scope(1), t, bytes32(uint256(3)), keccak256("token inherited replacement"));
        _record(1, false, false);
        t = host.resolve(ROUTE, _scope(1));
        require(
            t.originalFinalityRecordHash == base
                && t.originalScope.scopeType == StreamFinalityScopeType.COLLECTION
                && t.recoveryId == bytes32(uint256(3)),
            "captured collection lineage survives later exact finality"
        );
        StreamFinalityRecoveryRoutes.Selection memory c = host.resolve(ROUTE, _scope(0));
        _append(_scope(0), c, bytes32(uint256(4)), keccak256("later collection replacement"));
        t = host.resolve(ROUTE, _scope(1));
        require(
            t.recoveryId == bytes32(uint256(3))
                && t.route.dataHash == keccak256("token inherited replacement"),
            "later broad head cannot supersede exact"
        );
    }

    function testRecoveryRoutesInheritedMembershipAndUnsupportedFamiliesReject() public {
        _record(0, false, false);
        _token(true, 8, false);
        _reject(
            abi.encodeCall(host.resolve, (ROUTE, _scope(1))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryRoutes.FinalityRecoveryScopeMembershipInvalid.selector
            )
        );
        _token(false, 7, false);
        _reject(
            abi.encodeCall(host.resolve, (ROUTE, _scope(1))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryRoutes.FinalityRecoveryScopeMembershipInvalid.selector
            )
        );
        _token(true, 7, true);
        require(host.resolve(ROUTE, _scope(1)).pinned, "retained burned identity");
        for (uint8 kind = 2; kind < 5; ++kind) {
            _reject(
                abi.encodeCall(host.resolve, (ROUTE, _scope(kind))),
                abi.encodeWithSelector(
                    StreamFinalityRecoveryRoutes.FinalityRecoveryInheritedScopeUnsupported.selector,
                    kind
                )
            );
        }
    }

    function testRecoveryRoutesDuplicateTypeAndRehashedWrongSanctionInterfaceReject() public {
        _record(0, true, false);
        _reject(
            abi.encodeCall(host.resolve, (ROUTE, _scope(0))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryRoutes.FinalityRecoveryRouteAmbiguous.selector, ROUTE
            )
        );
        _record(0, false, true);
        _reject(
            abi.encodeCall(host.resolve, (ROUTE, _scope(0))),
            abi.encodeWithSelector(
                StreamArtistRecoveryOriginalReads.RecoveryOriginalInvalid.selector
            )
        );
        _record(0, false, false);
        require(host.resolve(ROUTE, _scope(0)).pinned, "healthy exact rehashed restoration");
    }

    function testRecoveryRoutesHistoricalPinSurvivesComponentDriftWhileHealthRejects() public {
        _record(0, false, false);
        StreamFinalityRecoveryRoutes.Selection memory s = host.resolve(ROUTE, _scope(0));
        bytes memory callData = abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (7));
        StreamFinalityComponentState memory live = StreamFinalityComponentState(
            true,
            route.componentType,
            route.component,
            route.interfaceId,
            route.codeHash,
            route.moduleVersion,
            route.manifestHash,
            route.dataHash
        );
        vm.mockCall(route.component, callData, abi.encode(live));
        host.replacement(route, _scope(0), ROUTE);
        require(host.matches(route, _scope(0)), "healthy live equality");
        live.frozen = false;
        vm.mockCall(route.component, callData, abi.encode(live));
        require(!host.matches(route, _scope(0)), "unfrozen false");
        _reject(
            abi.encodeCall(host.replacement, (route, _scope(0), ROUTE)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryRoutes.FinalityRecoveryReplacementUnreadable.selector,
                ROUTE,
                route.component
            )
        );
        bytes memory code = route.component.code;
        vm.etch(route.component, hex"00");
        StreamFinalityRecoveryRoutes.Selection memory after_ = host.resolve(ROUTE, _scope(0));
        require(
            after_.pinned && keccak256(abi.encode(s)) == keccak256(abi.encode(after_)),
            "historical selected bytes exact after drift"
        );
        require(!host.matches(route, _scope(0)), "drift health false");
        vm.etch(route.component, code);
        live.frozen = true;
        vm.mockCall(route.component, callData, abi.encode(live));
        host.replacement(route, _scope(0), ROUTE);
    }

    function testRecoveryRoutesPreparedIncompleteAndNoncanonicalLifecycleReject() public {
        _record(0, false, false);
        _token(true, 7, false);
        bytes memory query = abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (99));
        vm.mockCall(core, query, abi.encode(uint8(1)));
        _reject(
            abi.encodeCall(host.resolve, (ROUTE, _scope(1))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryRoutes.FinalityRecoveryScopeMembershipInvalid.selector
            )
        );
        vm.mockCall(core, query, abi.encode(uint256(258)));
        _reject(
            abi.encodeCall(host.resolve, (ROUTE, _scope(1))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryRoutes.FinalityRecoveryScopeMembershipInvalid.selector
            )
        );
        vm.mockCall(core, query, abi.encode(uint8(3)));
        _reject(
            abi.encodeCall(host.resolve, (ROUTE, _scope(1))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryRoutes.FinalityRecoveryScopeMembershipInvalid.selector
            )
        );
        _token(true, 7, false);
        require(host.resolve(ROUTE, _scope(1)).pinned, "completed minted identity");
        _token(true, 7, true);
        require(host.resolve(ROUTE, _scope(1)).pinned, "completed burned identity");
    }
}
