// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityInventorySelection.sol";
import {
    StreamCurrentAuthorityPreservationPolicyInventoryGuardV1 as Guard
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPreservationPolicyInventoryGuardV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyRenderCriticalCurrentV1 as Current
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPreservationPolicyRenderCriticalCurrentV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyRenderCriticalSourceReadsV1 as Source
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalSourceReadsV1 as OriginalSource
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalStateV1 as State
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationPolicyRenderCriticalTokenStagesV1 as Stages
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalTokenStagesV1.sol";
import {
    StreamPreservationPolicyRenderCriticalTokenReadsV1 as Tokens
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalTokenReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalScriptReadsV1 as Scripts
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalScriptReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalRendererReadsV1 as Renderers
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalRendererReadsV1.sol";
import {
    StreamPreservationPolicyRenderCriticalProfileReadsV1 as Profiles
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalProfileReadsV1.sol";
import {
    StreamPreservationPolicyAdmissionInventoryV1 as Preservation
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyAdmissionInventoryV1.sol";
import {
    StreamPreservationPolicyRenderCriticalDefinitionStagesV1 as Definitions
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalDefinitionStagesV1.sol";
import {
    StreamMultiOriginInventoryState as Origins
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginInventoryState.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as C
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as Ref
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    CurrentInventoryRuntimeFixture as Runtime,
    CurrentInventoryResolverFixture as Resolver,
    CurrentInventorySelectorFixture as Selector
} from "./StreamCurrentAuthorityInventorySelection.t.sol";

import {
    StreamCurrentAuthorityPreservationPolicyInventoryViewsV1 as Views
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPreservationPolicyInventoryViewsV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1 as Host
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2 as ScopedHost
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2.sol";
import {
    StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2 as ScopedSource
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginScopedPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as Publication
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as ScopedPublication
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamCurrentAuthorityPreservationPolicyPublicationInventoryDeploymentV1 as Deployment
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyPublicationInventoryDeploymentV1.sol";
import {
    StreamCurrentAuthorityScopedPolicyPublicationInventoryDeploymentV2 as ScopedDeployment
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyPublicationInventoryDeploymentV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface PreservationAuthorityInventoryVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function expectRevert(bytes4) external;
    function getNonce(address) external view returns (uint64);
    function computeCreateAddress(address, uint256) external pure returns (address);
}

/// @dev Explicitly seeds the preceding source/record/definition admission boundary. Real
/// capture, full current guard, six token state transitions, origin runtime, chains and seal
/// execute here. Typed token/source/definition readers below are mocks, not a full ceremony.
contract PreservationAuthorityInventoryHarness {
    mapping(bytes32 => State.State) private _states;
    mapping(bytes32 => Authority.State) private _authorities;
    Origins.State private _origins;
    Authority.Config private _viewConfig;
    bytes32 public constant DEPENDENCIES = keccak256("test-only dependency identity");
    bytes32 public constant LINEAGE = keccak256("explicit lineage boundary");

    function seed(Authority.Config memory config, O.Origin memory presented, C.Context memory c)
        external
        returns (bytes32 id)
    {
        _viewConfig = config;
        D.Capture memory captured = Authority.resolve(config);
        id = Guard.planId(DEPENDENCIES, captured, c, LINEAGE);
        Authority.remember(_authorities[id], config, captured);
        State.State storage s = _states[id];
        s.records.dependencies = captured.dependencies;
        s.records.dependencyHash = DEPENDENCIES;
        s.contexts[id] = c;
        s.records.contexts[id] = c.records;
        T.Plan storage p = s.records.plans[id];
        p.collectionId = c.records.collectionId;
        p.subject = c.records.subject;
        p.artistId = c.records.artistId;
        p.sourceContextHash = D.contextHash(captured, keccak256(abi.encode(c)), LINEAGE);
        p.tokenCount = c.records.tokenCount;
        p.completedStages = 8;
        Origins.initialize(_origins, id, captured.selection.origin, presented, LINEAGE);
    }

    function append(bytes32 id, uint8 phase) external {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        if (phase == 0) {
            Content.Payload memory p;
            Stages.appendOutput(_states[id], id, p);
        } else if (phase == 1 || phase == 2) {
            Stages.appendScript(_states[id], id, phase == 2);
        } else if (phase == 3) {
            Stages.appendRenderer(_states[id], id);
        } else if (phase == 4) {
            Stages.appendProfile(_states[id], id);
        } else {
            require(phase == 5);
            Stages.appendPreservation(_states[id], id, true);
        }
    }

    function runtime(bytes32 id) external {
        State.stage(_states[id], id, 8);
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
        T.Plan storage p = _states[id].records.plans[id];
        State.Progress storage token = _states[id].progress[id];
        if (p.nextToken != p.tokenCount || token.phase != 0 || token.row != 0 || token.count != 0) {
            revert T.InventoryIncomplete();
        }
        (T.Item[] memory rows, bytes32 witness) = Origins.runtimeItems(_origins, id);
        State.append(_states[id], id, rows, witness);
    }

    function seal(bytes32 id) external returns (T.Evidence memory) {
        return Current.sealInventory(_states[id], _origins, _authorities[id], id);
    }

    function requireCurrent(bytes32 id) external view {
        Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
    }

    function returnedCurrent(bytes32 id) external view returns (C.Context memory) {
        return Guard.requireCurrent(_states[id], _origins, _authorities[id], id);
    }

    function checkCurrent(bytes32 id) external view {
        Guard.checkCurrent(_states[id], _origins, _authorities[id], id);
    }

    function currentEvidence(uint256 collectionId) external view returns (T.Evidence memory) {
        bytes memory encoded = Views.requireCurrent(
            _states, _authorities, _viewConfig, DEPENDENCIES, _origins, collectionId
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function capture(bytes32 id) external view returns (D.Capture memory) {
        return _authorities[id].capture;
    }

    function plan(bytes32 id) external view returns (T.Plan memory) {
        return _states[id].records.plans[id];
    }

    function progress(bytes32 id) external view returns (State.Progress memory) {
        return _states[id].progress[id];
    }

    function history(bytes32 id) external view returns (T.Evidence memory) {
        return _states[id].records.completed[id];
    }

    function originRoot(bytes32 id) external view returns (bytes32) {
        return _origins.sealedRoot[id];
    }

    function cursor(bytes32 id) external view returns (uint256) {
        return _origins.runtimeCursor[id];
    }
}

/// @notice State-kernel regressions only. Real current capture/guards/seal and immutable runtime
/// rows, with typed synthetic resolver/selector/source facts and token/definition read boundaries.
/// No real op55/60, source admission, preservation registration or browser coverage is claimed.
contract StreamCurrentAuthorityPreservationPolicyInventoryV1Test {
    PreservationAuthorityInventoryVm private constant vm =
        PreservationAuthorityInventoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant WORK = keccak256("6529STREAM_CURRENT_AUTHORITY_WORK_SELECTION_V1");
    bytes32 private constant CONSERVATION =
        keccak256("6529STREAM_CURRENT_AUTHORITY_CONSERVATION_SELECTION_V1");
    PreservationAuthorityInventoryHarness private h;
    Resolver private resolver;
    Selector private work;
    Selector private conservation;
    Authority.Config private config;
    A.Anchors private anchors_;
    O.Origin private original;
    O.Origin private selected;
    C.Context private context;
    bytes32 private id;

    function setUp() public {
        h = new PreservationAuthorityInventoryHarness();
        resolver = new Resolver();
        work = new Selector();
        conservation = new Selector();
        S.Dependencies memory d;
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(new Runtime());
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.targets[7] = address(work);
        d.codeHashes[7] = address(work).codehash;
        d.targets[9] = address(conservation);
        d.codeHashes[9] = address(conservation).codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 500000;
        d.selectionGas = 500000;
        d.snapshotGas = 500000;
        d.referenceGas = 500000;
        original = _origin(d.targets[0]);
        selected = _origin(d.targets[0]);
        O.Origin memory o = original;
        d.artistTargets = [
            o.environment.registry,
            o.environment.coordinator,
            o.environment.owners[2],
            o.environment.owners[4],
            o.environment.archive
        ];
        d.artistCodeHashes = [
            o.registryCodeHash,
            o.coordinatorCodeHash,
            o.environment.ownerCodeHashes[2],
            o.environment.ownerCodeHashes[4],
            o.archiveCodeHash
        ];
        d.artistContentOwner = o.environment.owners[6];
        d.artistContentOwnerCodeHash = o.environment.ownerCodeHashes[6];
        address provider = address(new Runtime());
        anchors_ = A.Anchors(
            [d.targets[0], d.targets[1], d.targets[4], o.environment.registry, provider],
            [
                d.codeHashes[0],
                d.codeHashes[1],
                d.codeHashes[4],
                o.registryCodeHash,
                provider.codehash
            ],
            address(0xFA),
            block.chainid,
            500000
        );
        config = Authority.Config(
            d, D.Dependencies(address(resolver), address(resolver).codehash, 500000)
        );
        _select(selected, keccak256("complete B"));
        context.records.collectionId = 77;
        context.records.artistId = keccak256("artist");
        context.records.subject = keccak256("subject");
        context.records.tokenCount = 1;
        context.source.content.preservationProfile =
            keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
        context.source.outputs.preservationProfile = context.source.content.preservationProfile;
        context.records.rootRecordHash = keccak256("original preservation root");
        context.records.checkpointHash = keccak256("preservation checkpoint");
        context.records.tokenInventoryHash = keccak256("one actual ordinal boundary");
        context.source.content.selectionHash = keccak256("preservation selection");
        id = h.seed(config, original, context);
        _source(context);
        Snap.Dependencies memory sd;
        Ref.Dependencies memory rd;
        vm.mockCall(
            address(OriginalSource),
            abi.encodeWithSelector(OriginalSource.bindings.selector),
            abi.encode(sd, rd)
        );
        vm.mockCall(
            address(Definitions),
            abi.encodeWithSelector(Definitions.requireDefinitions.selector),
            bytes("")
        );
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = _row();
        vm.mockCall(
            address(Tokens), abi.encodeWithSelector(Tokens.tokenItems.selector), abi.encode(rows)
        );
        vm.mockCall(
            address(Scripts), abi.encodeWithSelector(Scripts.items.selector), abi.encode(rows)
        );
        vm.mockCall(
            address(Renderers),
            abi.encodeWithSelector(Renderers.item.selector),
            abi.encode(rows[0], uint64(1))
        );
        vm.mockCall(
            address(Profiles),
            abi.encodeWithSelector(Profiles.item.selector),
            abi.encode(rows[0], uint64(1))
        );
        Tokens.Original memory token;
        vm.mockCall(
            address(Tokens),
            abi.encodeWithSelector(Tokens.sourceAt.selector),
            abi.encode(uint256(9), token)
        );
        _preservationCount(11); // ten fixed preservation rows and one declared target.
    }

    function testAllSixStagesAndAllPreservationRowsAreRequiredBeforeSeal() public {
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.append(id, 5);
        for (uint8 phase; phase < 5; ++phase) {
            h.append(id, phase);
        }
        require(h.plan(id).nextToken == 0 && h.progress(id).phase == 5);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.seal(id);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.runtime(id);
        for (uint8 i; i < 10; ++i) {
            h.append(id, 5);
        }
        require(h.progress(id).row == 10 && h.progress(id).count == 11 && h.plan(id).nextToken == 0);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.seal(id);
        h.append(id, 5);
        require(
            h.plan(id).nextToken == 1 && h.progress(id).phase == 0 && h.progress(id).row == 0
                && h.progress(id).count == 0
        );
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.seal(id);
        h.runtime(id);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.seal(id);
        h.runtime(id);
        T.Evidence memory e = h.seal(id);
        require(e.tokenCount == 1 && e.segmentCount == 18 && e.itemCount == 36);
        require(
            e.originals.rootRecordHash == context.records.rootRecordHash
                && e.renderCriticalEvidenceHash != 0
        );
        bytes32 got = e.renderCriticalEvidenceHash;
        e.renderCriticalEvidenceHash = 0;
        require(
            got
                == keccak256(
                    abi.encode(
                        D.PRESERVATION_POLICY_INVENTORY_PROFILE,
                        block.chainid,
                        address(h),
                        h.DEPENDENCIES(),
                        h.capture(id).selection.selectionHash,
                        e,
                        h.originRoot(id),
                        uint256(2)
                    )
                )
        );
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.append(id, 0);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.seal(id);
    }

    function testPreservationRowCountChangeRejectsWithoutAdvancingState() public {
        for (uint8 phase; phase < 5; ++phase) {
            h.append(id, phase);
        }
        h.append(id, 5);
        bytes32 before_ = keccak256(abi.encode(h.plan(id), h.progress(id)));
        _preservationCount(12);
        vm.expectRevert(T.InventorySourceChanged.selector);
        h.append(id, 5);
        require(before_ == keccak256(abi.encode(h.plan(id), h.progress(id))));
        _preservationCount(11);
        h.append(id, 5);
        require(h.progress(id).row == 2);
    }

    function testUnpredictedCStalesEveryTokenPhaseAndSealWithoutLosingBHistory() public {
        _complete();
        T.Evidence memory saved = h.seal(id);
        bytes32 captureHash = keccak256(abi.encode(h.capture(id)));
        O.Origin memory next = _origin(config.originalAnchor.targets[0]);
        _select(next, keccak256("complete unpredicted C"));
        for (uint8 phase; phase < 6; ++phase) {
            vm.expectRevert(A.CurrentAuthorityChanged.selector);
            h.append(id, phase);
        }
        vm.expectRevert(A.CurrentAuthorityChanged.selector);
        h.requireCurrent(id);
        require(keccak256(abi.encode(h.history(id))) == keccak256(abi.encode(saved)));
        require(keccak256(abi.encode(h.capture(id))) == captureHash && h.cursor(id) == 2);
        bytes32 nextId = h.seed(config, original, context);
        require(
            nextId != id
                && h.capture(nextId).selection.origin.environment.registry
                    == next.environment.registry
        );
        _source(context);
        h.append(nextId, 0);
        vm.expectRevert(A.CurrentAuthorityChanged.selector);
        h.append(id, 0);
    }

    function testStaleOpenPlanCannotSealAndRestoredSelectionRetriesIdentically() public {
        _complete();
        bytes32 before_ = keccak256(abi.encode(h.plan(id), h.capture(id)));
        _select(_origin(config.originalAnchor.targets[0]), keccak256("complete C"));
        vm.expectRevert(A.CurrentAuthorityChanged.selector);
        h.seal(id);
        require(h.originRoot(id) == 0 && h.history(id).renderCriticalEvidenceHash == 0);
        require(before_ == keccak256(abi.encode(h.plan(id), h.capture(id))));
        _select(selected, keccak256("complete B"));
        require(h.seal(id).renderCriticalEvidenceHash != 0);
    }

    function testCompleteTypedPreservationContextIsBoundByGuard() public {
        C.Context memory changed = context;
        changed.source.rootBinding.preservationOutputProfile = keccak256("different typed output");
        _source(changed);
        vm.expectRevert(T.InventorySourceChanged.selector);
        h.append(id, 0);
        require(h.plan(id).segmentCount == 0);
        _source(context);
        h.append(id, 0);
        require(h.progress(id).phase == 1);
    }

    function testVoidGuardPreservesCompleteContextValidationAndMalformedReturnRefusal() public {
        bytes32 before_ = keccak256(abi.encode(h.plan(id), h.capture(id), h.history(id)));
        (bool ok, bytes memory raw) = address(h)
            .staticcall(abi.encodeCall(PreservationAuthorityInventoryHarness.returnedCurrent, (id)));
        require(ok && keccak256(raw) == keccak256(abi.encode(context)), "original full context");
        (ok, raw) = address(h)
            .staticcall(abi.encodeCall(PreservationAuthorityInventoryHarness.checkCurrent, (id)));
        require(ok && raw.length == 0, "void guard returns no context envelope");
        C.Context memory changed = context;
        changed.source.rootBinding.preservationOutputProfile = keccak256("different unused field");
        _source(changed);
        _sameGuardFailure(abi.encodeWithSelector(T.InventorySourceChanged.selector));
        vm.mockCall(address(Source), abi.encodeWithSelector(Source.current.selector), hex"01");
        (bool returnedOk, bytes memory returnedError) = address(h)
            .staticcall(abi.encodeCall(PreservationAuthorityInventoryHarness.returnedCurrent, (id)));
        (bool voidOk, bytes memory voidError) = address(h)
            .staticcall(abi.encodeCall(PreservationAuthorityInventoryHarness.checkCurrent, (id)));
        require(
            !returnedOk && !voidOk && keccak256(returnedError) == keccak256(voidError),
            "void guard still performs full malformed source decoding"
        );
        _source(context);
        h.checkCurrent(id);
        require(
            before_ == keccak256(abi.encode(h.plan(id), h.capture(id), h.history(id))),
            "success and refusals are read-only"
        );
    }

    function testVoidGuardKeepsAuthorityBeforeSourceAndExactLineageChecks() public {
        vm.mockCall(
            address(Source),
            abi.encodeWithSelector(Source.current.selector),
            abi.encode(context, selected, original, keccak256("wrong lineage"))
        );
        _sameGuardFailure(abi.encodeWithSelector(T.InventorySourceChanged.selector));
        _select(_origin(config.originalAnchor.targets[0]), keccak256("complete C"));
        // Both authority and source are now stale: the original authority error must win.
        _sameGuardFailure(abi.encodeWithSelector(A.CurrentAuthorityChanged.selector));
        _select(selected, keccak256("complete B"));
        _source(context);
        h.checkCurrent(id);
        require(
            keccak256(abi.encode(h.returnedCurrent(id))) == keccak256(abi.encode(context)),
            "restored original source and authority"
        );
    }

    function testCompletedLinkedViewReturnsExactTypedEvidenceAndRejectsStaleAuthority() public {
        _complete();
        T.Evidence memory expected = h.seal(id);
        (bool ok, bytes memory raw) = address(h)
            .staticcall(
                abi.encodeCall(PreservationAuthorityInventoryHarness.currentEvidence, (uint256(77)))
            );
        require(ok && keccak256(raw) == keccak256(abi.encode(expected)), "raw evidence tuple");
        require(
            keccak256(abi.encode(h.currentEvidence(77))) == keccak256(raw),
            "typed evidence has no extra bytes wrapper"
        );
        _select(_origin(config.originalAnchor.targets[0]), keccak256("complete C"));
        (ok, raw) = address(h)
            .staticcall(
                abi.encodeCall(PreservationAuthorityInventoryHarness.currentEvidence, (uint256(77)))
            );
        require(
            !ok
                && keccak256(raw)
                    == keccak256(abi.encodeWithSelector(T.InventoryIncomplete.selector)),
            "new authority cannot return old completion"
        );
        require(
            keccak256(abi.encode(h.history(id))) == keccak256(abi.encode(expected)),
            "history retained"
        );
        _select(selected, keccak256("complete B"));
        require(
            keccak256(abi.encode(h.currentEvidence(77))) == keccak256(abi.encode(expected)),
            "restore"
        );
    }

    /// @dev Real linked CREATE and host storage with the fixture's explicit typed source boundary.
    function testPreservationPublicationCreatePreservesArgumentsHostDomainAndRawReads() public {
        Publication.Recipe memory recipe;
        recipe.inventory = config.originalAnchor;
        Publication.Graph memory graph;
        graph.children[3] = config.originalAnchor.targets[2];
        graph.codeHashes[3] = config.originalAnchor.codeHashes[2];
        graph.children[4] = config.originalAnchor.targets[3];
        graph.codeHashes[4] = config.originalAnchor.codeHashes[3];
        S.Dependencies memory expected = config.originalAnchor;
        expected.targets[5] = graph.children[3];
        expected.codeHashes[5] = graph.codeHashes[3];
        expected.targets[6] = graph.children[4];
        expected.codeHashes[6] = graph.codeHashes[4];
        O.Dependencies memory od = _constructorOrigin();
        bytes32 recipeBefore = keccak256(abi.encode(recipe));
        uint64 nonce = vm.getNonce(address(this));
        Host first = Host(Deployment.deploy(recipe, graph, od, config.authority));
        Host second = Host(Deployment.deploy(recipe, graph, od, config.authority));
        _twoCreates(address(first), address(second), nonce);
        require(
            keccak256(
                    abi.encode(
                        first.dependencies(),
                        first.originDependencies(),
                        first.authorityDependencies()
                    )
                ) == keccak256(abi.encode(expected, od, config.authority))
                && first.dependencyHash()
                    == keccak256(
                        abi.encode(
                            D.PRESERVATION_POLICY_INVENTORY_PROFILE, expected, od, config.authority
                        )
                    ) && second.dependencyHash() == first.dependencyHash()
                && keccak256(abi.encode(recipe)) == recipeBefore,
            "exact projected constructor arguments"
        );
        bytes32 firstId = first.beginInventory(77);
        bytes32 secondId = second.beginInventory(77);
        require(
            firstId
                    == keccak256(
                        abi.encode(
                            D.PRESERVATION_POLICY_INVENTORY_PROFILE,
                            block.chainid,
                            address(first),
                            first.dependencyHash(),
                            D.contextHash(
                                first.authoritySelection(firstId),
                                keccak256(abi.encode(context)),
                                h.LINEAGE()
                            )
                        )
                    ) && firstId != secondId && first.plan(secondId).collectionId == 0
                && second.plan(firstId).collectionId == 0,
            "original host domain and isolated storage"
        );
        bytes32 before_ = keccak256(abi.encode(first.plan(firstId), first.sourceContext(firstId)));
        require(first.beginInventory(77) == firstId, "duplicate begin");
        require(
            before_ == keccak256(abi.encode(first.plan(firstId), first.sourceContext(firstId))),
            "no reset"
        );
        _rawRead(
            address(first), abi.encodeCall(Host.sourceContext, (firstId)), abi.encode(context), true
        );
        _rawRead(
            address(first),
            abi.encodeCall(Host.sourceContext, (bytes32(0))),
            abi.encodeWithSelector(T.InventoryIncomplete.selector),
            false
        );
        _rawRead(
            address(first),
            abi.encodeCall(Host.requireCurrent, (uint256(77))),
            abi.encodeWithSelector(T.InventoryIncomplete.selector),
            false
        );
    }

    function testScopedPublicationCreatePreservesArgumentsHostDomainAndRawReads() public {
        ScopedPublication.Recipe memory recipe;
        recipe.inventory = config.originalAnchor;
        ScopedPublication.Graph memory graph;
        graph.children[3] = config.originalAnchor.targets[2];
        graph.codeHashes[3] = config.originalAnchor.codeHashes[2];
        graph.children[4] = config.originalAnchor.targets[3];
        graph.codeHashes[4] = config.originalAnchor.codeHashes[3];
        S.Dependencies memory expected = config.originalAnchor;
        expected.targets[5] = graph.children[3];
        expected.codeHashes[5] = graph.codeHashes[3];
        expected.targets[6] = graph.children[4];
        expected.codeHashes[6] = graph.codeHashes[4];
        O.Dependencies memory od = _constructorOrigin();
        Scoped.Context memory c;
        c.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 77, 9, 0);
        c.subject = context.records.subject;
        c.artistId = context.records.artistId;
        c.rootRecordHash = context.records.rootRecordHash;
        c.checkpointHash = context.records.checkpointHash;
        c.selectionHash = context.source.content.selectionHash;
        c.tokenCount = 1;
        vm.mockCall(
            address(ScopedSource),
            abi.encodeWithSelector(ScopedSource.current.selector),
            abi.encode(c, selected, original, h.LINEAGE())
        );
        bytes32 recipeBefore = keccak256(abi.encode(recipe));
        uint64 nonce = vm.getNonce(address(this));
        ScopedHost first = ScopedHost(ScopedDeployment.deploy(recipe, graph, od, config.authority));
        ScopedHost second = ScopedHost(ScopedDeployment.deploy(recipe, graph, od, config.authority));
        _twoCreates(address(first), address(second), nonce);
        require(
            keccak256(
                    abi.encode(
                        first.dependencies(),
                        first.originDependencies(),
                        first.authorityDependencies()
                    )
                ) == keccak256(abi.encode(expected, od, config.authority))
                && first.dependencyHash()
                    == keccak256(
                        abi.encode(
                            D.SCOPED_POLICY_INVENTORY_PROFILE, expected, od, config.authority
                        )
                    ) && second.dependencyHash() == first.dependencyHash()
                && keccak256(abi.encode(recipe)) == recipeBefore,
            "exact scoped projected constructor arguments"
        );
        bytes32 firstId = first.beginInventory(c.scope);
        bytes32 secondId = second.beginInventory(c.scope);
        require(
            firstId
                    == keccak256(
                        abi.encode(
                            D.SCOPED_POLICY_INVENTORY_PROFILE,
                            block.chainid,
                            address(first),
                            first.dependencyHash(),
                            D.contextHash(
                                first.authoritySelection(firstId),
                                keccak256(abi.encode(c)),
                                h.LINEAGE()
                            )
                        )
                    ) && firstId != secondId && first.plan(secondId).progress.collectionId == 0
                && second.plan(firstId).progress.collectionId == 0,
            "scoped original host domain and isolated storage"
        );
        bytes32 before_ = keccak256(abi.encode(first.plan(firstId), first.sourceContext(firstId)));
        require(first.beginInventory(c.scope) == firstId, "duplicate scoped begin");
        require(
            before_ == keccak256(abi.encode(first.plan(firstId), first.sourceContext(firstId))),
            "no scoped reset"
        );
        _rawRead(
            address(first), abi.encodeCall(ScopedHost.sourceContext, (firstId)), abi.encode(c), true
        );
        _rawRead(
            address(first),
            abi.encodeCall(ScopedHost.sourceContext, (bytes32(0))),
            abi.encodeWithSelector(T.InventoryIncomplete.selector),
            false
        );
        _rawRead(
            address(first),
            abi.encodeCall(ScopedHost.requireCurrent, (c.scope)),
            abi.encodeWithSelector(T.InventoryIncomplete.selector),
            false
        );
    }

    function testCurrentPublicationConstructorRefusalsRetainNonceAndExactErrors() public {
        Publication.Recipe memory recipe;
        recipe.inventory = config.originalAnchor;
        Publication.Graph memory graph;
        graph.children[3] = recipe.inventory.targets[5];
        graph.codeHashes[3] = recipe.inventory.codeHashes[5];
        graph.children[4] = recipe.inventory.targets[6];
        graph.codeHashes[4] = recipe.inventory.codeHashes[6];
        ScopedPublication.Recipe memory scopedRecipe;
        scopedRecipe.inventory = config.originalAnchor;
        ScopedPublication.Graph memory scopedGraph;
        scopedGraph.children[3] = graph.children[3];
        scopedGraph.codeHashes[3] = graph.codeHashes[3];
        scopedGraph.children[4] = graph.children[4];
        scopedGraph.codeHashes[4] = graph.codeHashes[4];
        O.Dependencies memory od = _constructorOrigin();
        uint64 nonce = vm.getNonce(address(this));
        od.profile = keccak256("not the original archive origin profile");
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        Deployment.deploy(recipe, graph, od, config.authority);
        require(vm.getNonce(address(this)) == nonce, "V1 failed CREATE rollback");
        vm.expectRevert(O.InvalidArchiveOrigin.selector);
        ScopedDeployment.deploy(scopedRecipe, scopedGraph, od, config.authority);
        require(vm.getNonce(address(this)) == nonce, "V2 failed CREATE rollback");
        od.profile = O.PROFILE;
        address first = Deployment.deploy(recipe, graph, od, config.authority);
        address second = ScopedDeployment.deploy(scopedRecipe, scopedGraph, od, config.authority);
        _twoCreates(first, second, nonce);
    }

    function _sameGuardFailure(bytes memory expected) private view {
        (bool returnedOk, bytes memory returnedError) = address(h)
            .staticcall(abi.encodeCall(PreservationAuthorityInventoryHarness.returnedCurrent, (id)));
        (bool voidOk, bytes memory voidError) = address(h)
            .staticcall(abi.encodeCall(PreservationAuthorityInventoryHarness.checkCurrent, (id)));
        require(
            !returnedOk && !voidOk && keccak256(returnedError) == keccak256(expected)
                && keccak256(voidError) == keccak256(expected),
            "exact original and void guard errors"
        );
    }

    function _constructorOrigin() private returns (O.Dependencies memory) {
        address worker = address(new Runtime());
        return O.Dependencies(worker, worker.codehash, 500000, O.PROFILE);
    }

    function _twoCreates(address first, address second, uint64 nonce) private view {
        require(
            first == vm.computeCreateAddress(address(this), nonce)
                && second == vm.computeCreateAddress(address(this), uint256(nonce) + 1)
                && first != second && vm.getNonce(address(this)) == nonce + 2,
            "original caller, one CREATE each, original order"
        );
    }

    function _rawRead(address target, bytes memory input, bytes memory expected, bool success)
        private
        view
    {
        (bool ok, bytes memory raw) = target.staticcall(input);
        require(
            ok == success && keccak256(raw) == keccak256(expected),
            "exact raw return or revert bytes"
        );
    }

    function _complete() private {
        for (uint8 phase; phase < 5; ++phase) {
            h.append(id, phase);
        }
        for (uint8 i; i < 11; ++i) {
            h.append(id, 5);
        }
        h.runtime(id);
        h.runtime(id);
    }

    function _source(C.Context memory c) private {
        vm.mockCall(
            address(Source),
            abi.encodeWithSelector(Source.current.selector),
            abi.encode(c, selected, original, h.LINEAGE())
        );
    }

    function _preservationCount(uint64 count) private {
        vm.mockCall(
            address(Preservation),
            abi.encodeWithSelector(Preservation.itemForPlan.selector),
            abi.encode(_row(), count)
        );
    }

    function _row() private view returns (T.Item memory row) {
        row.kind = T.Kind.NATIVE_BYTES;
        row.role = keccak256("explicit typed reader boundary");
        row.source = address(h);
        row.sourceRecord = keccak256("boundary record");
        row.algorithm = 1;
        row.canonicalizationId = keccak256("RAW_BYTES");
        row.digest = abi.encodePacked(keccak256("one byte"));
        row.byteSize = 1;
    }

    function _select(O.Origin memory o, bytes32 completion) private {
        resolver.set(anchors_, o, completion);
        work.set(WORK, o);
        conservation.set(CONSERVATION, o);
    }

    function _origin(address core) private returns (O.Origin memory o) {
        o.environment.chainId = block.chainid;
        o.environment.core = core;
        o.environment.manager = address(0xCAFE);
        o.environment.suiteConfigurationHash = keccak256("synthetic suite");
        o.environment.registry = address(new Runtime());
        o.registryCodeHash = o.environment.registry.codehash;
        o.environment.coordinator = address(new Runtime());
        o.coordinatorCodeHash = o.environment.coordinator.codehash;
        o.environment.archive = address(new Runtime());
        o.archiveCodeHash = o.environment.archive.codehash;
        for (uint256 i; i < 7; ++i) {
            o.environment.owners[i] = address(new Runtime());
            o.environment.ownerCodeHashes[i] = o.environment.owners[i].codehash;
        }
    }
}
