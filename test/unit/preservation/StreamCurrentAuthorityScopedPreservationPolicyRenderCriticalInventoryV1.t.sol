// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 as Host
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1 as State
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalTokenStagesV1 as Stages
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalTokenStagesV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTokenReadsV1 as Tokens
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalTokenReadsV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalCitationReadsV1 as Citations
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalCitationReadsV1.sol";
import {
    StreamPreservationPolicyAdmissionInventoryV1 as Preservation
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyAdmissionInventoryV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 as IHost
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    IStreamCurrentAuthorityInventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    IStreamArtistArchiveOriginInventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";
import {
    StreamCurrentAuthorityInventorySelection as Selection
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityInventorySelection.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamMultiOriginInventoryState as Origins
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginInventoryState.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamPreservationInventoryItems as Items
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol";
import {
    IStreamArtistCurrentAuthorityResolver as Resolver
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";
import {
    IStreamRecordCurrentAuthority as Selector
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRecordCurrentAuthority.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface ScopedPreservationAuthorityVm {
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function etch(address, bytes calldata) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
}

contract ScopedPreservationAuthorityRuntimeFixture {
    function value() external pure returns (uint256) {
        return 1;
    }
}

/// @dev Synthetic fixed resolver boundary. No Metadata ancestry or op55/60 claim.
contract ScopedPreservationAuthorityResolverFixture {
    C.Anchors private _anchors;
    C.Selection private _selection;

    function set(C.Anchors memory a, O.Origin memory o, bytes32 completion) external {
        _anchors = a;
        _selection = C.Selection(o, completion, C.hashSelection(a, o, completion));
    }

    function currentAuthorityProfile() external pure returns (bytes32) {
        return C.PROFILE;
    }

    function anchors() external view returns (C.Anchors memory) {
        return _anchors;
    }

    function currentSelection() external view returns (C.Selection memory) {
        return _selection;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(Resolver).interfaceId;
    }
}

/// @dev Real canonical typed getters with synthetic selected facts; no selector history admission.
contract ScopedPreservationAuthoritySelectorFixture {
    bytes32 private _profile;
    address[5] private _targets;
    bytes32[5] private _hashes;

    function set(bytes32 profile, O.Origin memory o) external {
        _profile = profile;
        _targets = [
            o.environment.registry,
            o.environment.coordinator,
            o.environment.owners[2],
            o.environment.owners[0],
            o.environment.owners[4]
        ];
        _hashes = [
            o.registryCodeHash,
            o.coordinatorCodeHash,
            o.environment.ownerCodeHashes[2],
            o.environment.ownerCodeHashes[0],
            o.environment.ownerCodeHashes[4]
        ];
    }

    function currentAuthorityProfile() external view returns (bytes32) {
        return _profile;
    }

    function currentArtistContext() external view returns (address[5] memory, bytes32[5] memory) {
        return (_targets, _hashes);
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(Selector).interfaceId;
    }
}

/// @dev Actual new State/TokenStages against explicit typed source boundaries. Seeding an
/// earlier completed stage does not prove those stages, ancestry, admission or the full pipeline.
contract ScopedPreservationAuthorityStageHarness {
    mapping(bytes32 => State.State) private _states;

    function seed(
        Selection.Config memory config,
        O.Dependencies memory od,
        Scoped.Context memory c,
        bytes32 lineage,
        uint16 completedStages,
        uint8 phase
    ) external returns (bytes32 id) {
        D.Capture memory captured = Selection.resolve(config);
        bytes32 dh = D.dependencyHash(
            D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
            config.originalAnchor,
            od,
            config.authority
        );
        id = State.idFor(dh, captured, c, lineage);
        State.State storage s = _states[id];
        Selection.remember(s.authority, config, captured);
        s.dependencies = captured.dependencies;
        s.dependencyHash = dh;
        s.origins.dependencies = od;
        Origins.initialize(
            s.origins, id, captured.selection.origin, captured.selection.origin, lineage
        );
        s.contexts[id] = c;
        s.plans[id].scope = c.scope;
        T.Plan storage p = s.plans[id].progress;
        p.collectionId = c.scope.collectionId;
        p.subject = c.subject;
        p.artistId = c.artistId;
        p.tokenCount = c.tokenCount;
        p.sourceContextHash = D.contextHash(captured, keccak256(abi.encode(c)), lineage);
        p.completedStages = completedStages;
        s.tokenProgress[id].phase = phase;
    }

    function citation(bytes32 id) external {
        Stages.appendCitation(_states[id], id);
    }

    function preservation(bytes32 id) external {
        Stages.appendPreservation(_states[id], id);
    }

    function current(bytes32 id) external view {
        State.requireCurrent(_states[id], id);
    }

    function progress(bytes32 id)
        external
        view
        returns (Scoped.Plan memory, Scoped.TokenProgress memory)
    {
        return (_states[id].plans[id], _states[id].tokenProgress[id]);
    }

    function segment(bytes32 id, uint64 index) external view returns (T.Segment memory) {
        return _states[id].segments[id][index];
    }

    function captured(bytes32 id) external view returns (D.Capture memory) {
        return _states[id].authority.capture;
    }

    function document(bytes32 id, bytes32 key) external view returns (bytes32, uint256) {
        return
            (_states[id].selectedDocumentFacts[id][key], _states[id].selectedDocuments[id].length);
    }
}

/// @notice Real new host/capture/phase-state regression cases with mocked full source and row readers.
/// @dev No source publication, op60, genuine producer admission, complete inventory, archive or finality claim.
/// The separately authored root companion cases authenticate the original op17 codec/Archive boundary.
contract StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1Test {
    ScopedPreservationAuthorityVm private constant vm =
        ScopedPreservationAuthorityVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant WORK = keccak256("6529STREAM_CURRENT_AUTHORITY_WORK_SELECTION_V1");
    bytes32 private constant CONSERVATION =
        keccak256("6529STREAM_CURRENT_AUTHORITY_CONSERVATION_SELECTION_V1");
    bytes32 private constant LINEAGE = keccak256("typed lineage boundary A to B");
    ScopedPreservationAuthorityResolverFixture private resolver;
    ScopedPreservationAuthoritySelectorFixture private work;
    ScopedPreservationAuthoritySelectorFixture private conservation;
    ScopedPreservationAuthorityStageHarness private stages;
    Selection.Config private config;
    O.Dependencies private od;
    C.Anchors private anchors_;
    O.Origin private original;
    O.Origin private selected;
    Scoped.Context private context_;
    D.Capture private captured_;
    Tokens.Original private token_;

    function setUp() public {
        stages = new ScopedPreservationAuthorityStageHarness();
        resolver = new ScopedPreservationAuthorityResolverFixture();
        work = new ScopedPreservationAuthoritySelectorFixture();
        conservation = new ScopedPreservationAuthoritySelectorFixture();
        S.Dependencies memory d;
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = _runtime();
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.targets[7] = address(work);
        d.codeHashes[7] = address(work).codehash;
        d.targets[9] = address(conservation);
        d.codeHashes[9] = address(conservation).codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 4000000;
        d.selectionGas = 4000000;
        d.snapshotGas = 4000000;
        d.referenceGas = 4000000;
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
        address provider = _runtime();
        anchors_ = C.Anchors(
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
        config = Selection.Config(
            d, D.Dependencies(address(resolver), address(resolver).codehash, 4000000)
        );
        address worker = _runtime();
        od = O.Dependencies(worker, worker.codehash, 4000000, O.PROFILE);
        context_.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 91, 101, 0);
        context_.subject = keccak256("exact scope subject");
        context_.artistId = keccak256("Artist");
        context_.rootRecordHash = keccak256("original preservation root");
        context_.checkpointHash = keccak256("preservation checkpoint");
        context_.selectionHash = keccak256("frozen original selection");
        context_.tokenCount = 1;
        context_.snapshotSource.content.preservationProfile =
            keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
        context_.snapshotSource.outputs.preservationProfile =
        context_.snapshotSource.content.preservationProfile;
        _select(selected, keccak256("complete B"));
        token_.selection.tokenId = 101;
        token_.output.leaf.tokenId = 101;
        _source(context_, LINEAGE);
    }

    function testConstructionOnlyPinsAnchorsAndAdvertisesDistinctFullInterfaces() public {
        vm.mockCallRevert(
            address(resolver),
            abi.encodeCall(Resolver.currentSelection, ()),
            abi.encodeWithSignature("PendingSelection()")
        );
        Host host = new Host(config.originalAnchor, od, config.authority);
        require(
            host.scopedPreservationPolicyInventoryProfile()
                == D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
            "profile"
        );
        require(
            host.originProfile() == D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE, "origin profile"
        );
        require(
            host.supportsInterface(type(IHost).interfaceId)
                && host.supportsInterface(type(IStreamCurrentAuthorityInventory).interfaceId)
                && host.supportsInterface(type(IStreamArtistArchiveOriginInventory).interfaceId)
                && host.supportsInterface(0x01ffc9a7) && !host.supportsInterface(0xffffffff),
            "interfaces"
        );
        require(
            keccak256(abi.encode(host.originalAnchor()))
                == keccak256(abi.encode(config.originalAnchor)),
            "anchor"
        );
        require(
            host.dependencyHash()
                == D.dependencyHash(
                    D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                    config.originalAnchor,
                    od,
                    config.authority
                ),
            "full dependency hash"
        );
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(resolver)));
        host.beginInventory(context_.scope);
    }

    function testBeginStoresFullCaptureAndDistinctTypedPlanWithIdempotentHistory() public {
        Host host = new Host(config.originalAnchor, od, config.authority);
        bytes32 id = host.beginInventory(context_.scope);
        require(id == host.beginInventory(context_.scope), "idempotence");
        bytes32 ch = D.contextHash(captured_, keccak256(abi.encode(context_)), LINEAGE);
        require(
            id
                == keccak256(
                    abi.encode(
                        D.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE,
                        block.chainid,
                        address(host),
                        host.dependencyHash(),
                        ch
                    )
                ),
            "actual plan domain"
        );
        require(
            host.plan(id).progress.sourceContextHash == ch
                && host.plan(id).progress.tokenCount == 1,
            "progress"
        );
        require(
            keccak256(abi.encode(host.authoritySelection(id))) == keccak256(abi.encode(captured_)),
            "capture"
        );
        require(
            keccak256(abi.encode(host.sourceContext(id))) == keccak256(abi.encode(context_)),
            "typed context"
        );
        require(host.originCount(id) == 2 && host.originSetHash(id) == 0, "origins unsealed");
        require(
            host.dependencies().artistTargets[0] == original.environment.registry,
            "original remains fixed"
        );
        vm.expectRevert(T.InventoryIncomplete.selector);
        host.sealInventory(id);
        vm.expectRevert(T.InventoryIncomplete.selector);
        host.appendTokenPreservation(id);
        vm.expectRevert(T.InventoryIncomplete.selector);
        host.appendOriginRuntime(id);
    }

    function testUnpredictedSuccessorStalesWritesButRetainsAllHistoricalCoordinates() public {
        Host host = new Host(config.originalAnchor, od, config.authority);
        bytes32 beforeId = host.beginInventory(context_.scope);
        bytes32 old = keccak256(
            abi.encode(
                host.plan(beforeId),
                host.sourceContext(beforeId),
                host.authoritySelection(beforeId),
                host.originAt(beforeId, 0),
                host.originAt(beforeId, 1)
            )
        );
        _select(_origin(config.originalAnchor.targets[0]), keccak256("new complete C"));
        vm.expectRevert(C.CurrentAuthorityChanged.selector);
        host.appendNative(beforeId, 1);
        _source(context_, LINEAGE);
        bytes32 afterId = host.beginInventory(context_.scope);
        require(afterId != beforeId, "new capture id");
        require(
            old
                == keccak256(
                    abi.encode(
                        host.plan(beforeId),
                        host.sourceContext(beforeId),
                        host.authoritySelection(beforeId),
                        host.originAt(beforeId, 0),
                        host.originAt(beforeId, 1)
                    )
                ),
            "historical coordinates"
        );
        vm.expectRevert(C.CurrentAuthorityChanged.selector);
        host.appendNative(beforeId, 1);
    }

    function testFullTypedContextAndLineageChangesRefuseStageWithoutMutation() public {
        bytes32 id = _seed(8, 5);
        bytes32 before_ = _progressHash(id);
        Scoped.Context memory altered = context_;
        altered.snapshotSource.content.preservationProfile = keccak256("other profile");
        _source(altered, LINEAGE);
        vm.expectRevert(T.InventorySourceChanged.selector);
        stages.preservation(id);
        require(_progressHash(id) == before_, "typed context rollback");
        _source(context_, keccak256("other lineage"));
        vm.expectRevert(T.InventorySourceChanged.selector);
        stages.preservation(id);
        require(_progressHash(id) == before_, "lineage rollback");
        _source(context_, LINEAGE);
        stages.current(id);
    }

    function testEveryEarlierGlobalStageAndTokenPhaseRejectsPreservation() public {
        for (uint16 i; i < 8; ++i) {
            stages = new ScopedPreservationAuthorityStageHarness();
            bytes32 id = _seed(i, 5);
            bytes32 before_ = _progressHash(id);
            vm.expectRevert(T.InventoryIncomplete.selector);
            stages.preservation(id);
            require(_progressHash(id) == before_, "earlier global stage");
        }
        for (uint8 i; i < 5; ++i) {
            stages = new ScopedPreservationAuthorityStageHarness();
            bytes32 id = _seed(8, i);
            bytes32 before_ = _progressHash(id);
            vm.expectRevert(T.InventoryIncomplete.selector);
            stages.preservation(id);
            require(_progressHash(id) == before_, "earlier token phase");
        }
    }

    function testCitationCompletionDoesNotAdvanceTokenAndAllPreservationRowsAreRequired() public {
        bytes32 id = _seed(8, 4);
        T.Item memory row = Items.absent(
            keccak256("citation applicability"),
            config.originalAnchor.targets[4],
            context_.checkpointHash,
            101
        );
        vm.mockCall(
            address(Citations),
            abi.encodeWithSelector(
                Citations.item.selector, captured_.dependencies, context_, uint64(0), uint64(0)
            ),
            abi.encode(row, uint64(1))
        );
        stages.citation(id);
        (Scoped.Plan memory p, Scoped.TokenProgress memory token) = stages.progress(id);
        require(
            p.progress.nextToken == 0 && token.phase == 5 && token.row == 0 && token.count == 0,
            "sixth stage required"
        );
        _tokenSource(0);
        for (uint64 i; i < 3; ++i) {
            row = _item(i);
            _preservationRow(i, row, 3);
            stages.preservation(id);
            (p, token) = stages.progress(id);
            require(
                p.progress.nextToken == (i == 2 ? 1 : 0), "only final preservation row advances"
            );
            require(
                token.phase == (i == 2 ? 0 : 5) && token.row == (i == 2 ? 0 : i + 1)
                    && token.count == (i == 2 ? 0 : 3),
                "phase cursor"
            );
            T.Item[] memory rows = new T.Item[](1);
            rows[0] = row;
            bytes32 witness = keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_TOKEN_INVENTORY_SOURCE_V1"),
                    context_.checkpointHash,
                    context_.selectionHash,
                    uint64(0),
                    uint8(5),
                    i,
                    uint64(3)
                )
            );
            T.Segment memory expected = Chains.segment(
                keccak256(
                    abi.encode(
                        keccak256(
                            "6529STREAM_SCOPED_PRESERVATION_POLICY_RENDER_CRITICAL_SEGMENT_V1"
                        ),
                        id,
                        uint64(i + 1)
                    )
                ),
                witness,
                rows
            );
            require(
                keccak256(abi.encode(stages.segment(id, i + 1))) == keccak256(abi.encode(expected)),
                "exact preservation segment"
            );
        }
        vm.expectRevert(T.InventoryIncomplete.selector);
        stages.preservation(id);
    }

    function testChangingPreservationCountRollsBackAndIdenticalExactRetryWorks() public {
        bytes32 id = _seed(8, 5);
        _tokenSource(0);
        _preservationRow(0, _item(0), 2);
        stages.preservation(id);
        bytes32 before_ = _progressHash(id);
        _preservationRow(1, _item(1), 3);
        vm.expectRevert(T.InventorySourceChanged.selector);
        stages.preservation(id);
        require(_progressHash(id) == before_ && stages.segment(id, 1).key == 0, "rollback");
        _preservationRow(1, _item(1), 2);
        stages.preservation(id);
        (Scoped.Plan memory p, Scoped.TokenProgress memory token) = stages.progress(id);
        require(
            p.progress.nextToken == 1 && token.phase == 0 && p.progress.segmentCount == 2, "retry"
        );
    }

    function testZeroPreservationCountAndMissingDocumentFactsRejectBeforeAppend() public {
        bytes32 id = _seed(8, 5);
        _tokenSource(0);
        bytes32 before_ = _progressHash(id);
        T.Item memory row = _item(0);
        _preservationRow(0, row, 0);
        vm.expectRevert(T.InventorySourceChanged.selector);
        stages.preservation(id);
        row.kind = T.Kind.REGISTERED_DOCUMENT;
        row.catalogId = keccak256("schema");
        _preservationRow(0, row, 1);
        vm.expectRevert(T.InventorySourceChanged.selector);
        stages.preservation(id);
        row.provenanceHash = keccak256("facts");
        row.catalogId = 0;
        _preservationRow(0, row, 1);
        vm.expectRevert(T.InventorySourceChanged.selector);
        stages.preservation(id);
        require(_progressHash(id) == before_, "no partial mutation");
    }

    function testSelectedPreservationDocumentFactsDeduplicateAndConflictRollsBack() public {
        bytes32 id = _seed(8, 5);
        _tokenSource(0);
        T.Item memory row = _item(0);
        row.kind = T.Kind.REGISTERED_DOCUMENT;
        row.catalogId = keccak256("schema");
        row.provenanceHash = keccak256("exact facts");
        _preservationRow(0, row, 3);
        stages.preservation(id);
        _preservationRow(1, row, 3);
        stages.preservation(id);
        (bytes32 pin, uint256 count) = stages.document(id, row.catalogId);
        require(pin == row.provenanceHash && count == 1, "one exact document");
        bytes32 before_ = _progressHash(id);
        row.provenanceHash = keccak256("changed facts");
        _preservationRow(2, row, 3);
        vm.expectRevert(T.InventorySourceChanged.selector);
        stages.preservation(id);
        require(_progressHash(id) == before_, "late conflict rollback");
        row.provenanceHash = pin;
        _preservationRow(2, row, 3);
        stages.preservation(id);
        (pin, count) = stages.document(id, row.catalogId);
        require(count == 1 && pin == row.provenanceHash, "exact retry");
    }

    function testStaleCapturedAuthorityRejectsSixthPhaseAndPreservesOldSegments() public {
        bytes32 id = _seed(8, 5);
        _tokenSource(0);
        _preservationRow(0, _item(0), 2);
        stages.preservation(id);
        bytes32 before_ = _progressHash(id);
        bytes32 segmentHash = keccak256(abi.encode(stages.segment(id, 0)));
        bytes32 capturedHash = keccak256(abi.encode(stages.captured(id)));
        O.Origin memory next = _origin(config.originalAnchor.targets[0]);
        _select(next, keccak256("complete unpredicted C"));
        vm.expectRevert(C.CurrentAuthorityChanged.selector);
        stages.preservation(id);
        require(
            _progressHash(id) == before_
                && keccak256(abi.encode(stages.segment(id, 0))) == segmentHash
                && keccak256(abi.encode(stages.captured(id))) == capturedHash,
            "preserved history"
        );
    }

    function _seed(uint16 stage, uint8 phase) private returns (bytes32) {
        return stages.seed(config, od, context_, LINEAGE, stage, phase);
    }

    function _source(Scoped.Context memory c, bytes32 lineage) private {
        vm.mockCall(
            address(Sources),
            abi.encodeWithSelector(
                Sources.current.selector, captured_.dependencies, od, context_.scope
            ),
            abi.encode(c, captured_.selection.origin, original, lineage)
        );
    }

    function _tokenSource(uint64 index) private {
        vm.mockCall(
            address(Tokens),
            abi.encodeWithSelector(
                Tokens.sourceAt.selector, captured_.dependencies, context_, index
            ),
            abi.encode(uint256(101), token_)
        );
    }

    function _preservationRow(uint64 index, T.Item memory item, uint64 count) private {
        vm.mockCall(
            address(Preservation),
            abi.encodeWithSelector(
                Preservation.itemForPlan.selector,
                captured_.dependencies,
                context_.snapshotSource.content,
                token_.selection,
                token_.output,
                index
            ),
            abi.encode(item, count)
        );
    }

    function _item(uint64 index) private view returns (T.Item memory) {
        return Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("preservation source row"),
            config.originalAnchor.targets[4],
            context_.checkpointHash,
            index,
            abi.encode(index)
        );
    }

    function _progressHash(bytes32 id) private view returns (bytes32) {
        (Scoped.Plan memory p, Scoped.TokenProgress memory token) = stages.progress(id);
        return keccak256(abi.encode(p, token));
    }

    function _select(O.Origin memory o, bytes32 completion) private {
        resolver.set(anchors_, o, completion);
        work.set(WORK, o);
        conservation.set(CONSERVATION, o);
        captured_ = Selection.resolve(config);
    }

    function _runtime() private returns (address) {
        return address(new ScopedPreservationAuthorityRuntimeFixture());
    }

    function _origin(address core) private returns (O.Origin memory o) {
        o.environment.chainId = block.chainid;
        o.environment.core = core;
        o.environment.registry = _runtime();
        o.environment.coordinator = _runtime();
        o.environment.archive = _runtime();
        o.environment.manager = address(0xCAFE);
        o.environment.suiteConfigurationHash = keccak256("typed suite boundary");
        o.registryCodeHash = o.environment.registry.codehash;
        o.coordinatorCodeHash = o.environment.coordinator.codehash;
        o.archiveCodeHash = o.environment.archive.codehash;
        for (uint256 i; i < 7; ++i) {
            o.environment.owners[i] = _runtime();
            o.environment.ownerCodeHashes[i] = o.environment.owners[i].codehash;
        }
    }
}
