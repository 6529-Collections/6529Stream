// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/RouterOriginalCompositionFixture.sol";

interface RouterRunVm {
    function etch(address target, bytes calldata code) external;
    function expectRevert() external;
}

contract StreamRouterOriginalCompositionTest {
    RouterRunVm private constant vm =
        RouterRunVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RouterOriginalCompositionFixture private fixture;

    function setUp() public {
        fixture = new RouterOriginalCompositionFixture();
        fixture.initialize();
    }

    function testActualOriginalRegistryCompanionAndRouterServeExactStoredCollectionRoute()
        public
        view
    {
        StreamMetadataRouter router = fixture.router();
        StreamArtworkFinalityRegistry original = fixture.original();
        StreamArtworkFinalityRecovery recovery = fixture.recovery();
        bytes32 hash = fixture.originalHash();
        require(
            original.collectionFinalityRecord(1).finalized
                && original.collectionFinalityRecord(1).finalityRecordHash == hash,
            "actual stored original"
        );
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 91, 0);
        (bool pinned, address target, bytes32 routeHash, bytes32 originalHash, bytes32 recoveryId) =
            recovery.resolvedFinalityRoute(keccak256("METADATA_ROUTER"), scope);
        require(
            pinned && target.code.length != 0 && routeHash != 0 && originalHash == hash
                && recoveryId == 0,
            "actual inherited original route"
        );
        (bool statusPinned, bool current, bytes32 statusHash, bytes32 statusId) =
            recovery.finalityRecoveryRouteStatus(keccak256("METADATA_ROUTER"), scope);
        require(
            statusPinned && current && statusHash == routeHash && statusId == 0,
            "actual status parity"
        );
        require(
            keccak256(bytes(router.tokenMetadataJSON(fixture.coreAddress(), 91)))
                == fixture.beforeJSON(),
            "actual frozen render parity"
        );
        require(
            address(router).code.length <= 24576 && address(original).code.length <= 24576
                && address(recovery).code.length <= 24576,
            "actual three runtimes fit"
        );
    }

    function testActualFrozenRouterRejectsMissingCompanionAndIgnoresReplacedCurrentOriginal()
        public
    {
        StreamMetadataRouter router = fixture.router();
        address core = fixture.coreAddress();
        bytes32 before_ = keccak256(bytes(router.tokenMetadataJSON(core, 91)));
        fixture.clearRecoverySelection();
        vm.expectRevert();
        router.tokenMetadataJSON(core, 91);
        vm.expectRevert();
        router.contractURIForCollection(core, 1);
        fixture.restoreRecoverySelection();
        require(
            keccak256(bytes(router.tokenMetadataJSON(core, 91))) == before_,
            "exact companion restoration"
        );
        MetadataRecoveryOriginalBoundary empty =
            new MetadataRecoveryOriginalBoundary(core, address(1), address(2));
        fixture.replaceCurrentOriginal(address(empty));
        require(
            keccak256(bytes(router.tokenMetadataJSON(core, 91))) == before_,
            "actual original record survives current key cutover"
        );
        bytes memory originalCode = address(fixture.original()).code;
        address original = address(fixture.original());
        vm.etch(original, hex"00");
        vm.expectRevert();
        router.tokenMetadataJSON(core, 91);
        vm.etch(original, originalCode);
        require(
            keccak256(bytes(router.tokenMetadataJSON(core, 91))) == before_,
            "original runtime restore"
        );
    }

    function testActualOriginalFrozenServingSurvivesOwnerHostLoss() public {
        StreamArtworkFinalityRecovery recovery = fixture.recovery();
        address owner = recovery.ownerEvidence();
        bytes memory code = owner.code;
        bytes32 before_ = _historicalServingHash(bytes32(0));
        _changeOwnerAnswers(owner);
        require(
            _historicalServingHash(bytes32(0)) == before_, "original ignores later owner answers"
        );
        vm.etch(owner, hex"");
        require(_historicalServingHash(bytes32(0)) == before_, "original survives owner code loss");
        vm.etch(owner, code);
        require(_historicalServingHash(bytes32(0)) == before_, "original owner restore parity");
    }

    function testActualRecoveredServingSurvivesOwnerLossWhileNewRecoveryRejects() public {
        MetadataRecoveryRendererBoundary renderer = new MetadataRecoveryRendererBoundary();
        bytes32 action = fixture.recoverRenderer(address(renderer));
        StreamArtworkFinalityRecovery recovery = fixture.recovery();
        StreamFinalityRecoveryRequest memory next = fixture.prepareRendererSuccessor(action);
        IStreamArtistRecoveryIntent.Facts memory facts = recovery.requireArtistRecoveryIntent(
            next.scope, next.expectedOriginalFinalityRecordHash, next.recoveryManifest.contentHash
        );
        bytes32 before_ = _historicalServingHash(action);
        address owner = recovery.ownerEvidence();
        bytes memory code = owner.code;
        _changeOwnerAnswers(owner);
        require(_historicalServingHash(action) == before_, "recovered ignores later owner answers");
        vm.etch(owner, hex"");
        require(_historicalServingHash(action) == before_, "recovered survives owner code loss");
        bytes32 nextAction = keccak256("successor recovery context boundary");
        (bool ok, bytes memory output) = fixture.actionHost()
            .run(
                address(recovery),
                abi.encodeCall(recovery.executeFinalityRecovery, (next)),
                [nextAction, facts.scopeHash, facts.oldValueHash, facts.newValueHash],
                2
            );
        require(
            !ok
                && keccak256(output)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamFinalityRecoveryBindings.FinalityRecoveryBindingChanged.selector,
                            owner
                        )
                    ),
            "new execution rejects exact missing owner pin"
        );
        require(
            !recovery.finalityRecoveryRecord(nextAction).executed, "failed successor not appended"
        );
        require(_historicalServingHash(action) == before_, "failed admission preserves history");
        vm.etch(owner, code);
        IStreamArtistRecoveryIntent.Facts memory restored = recovery.requireArtistRecoveryIntent(
            next.scope, next.expectedOriginalFinalityRecordHash, next.recoveryManifest.contentHash
        );
        require(
            keccak256(abi.encode(restored)) == keccak256(abi.encode(facts)),
            "exact current preparation restored"
        );
        (ok, output) = fixture.actionHost()
            .run(
                address(recovery),
                abi.encodeCall(recovery.executeFinalityRecovery, (next)),
                [nextAction, facts.scopeHash, facts.oldValueHash, facts.newValueHash],
                2
            );
        if (!ok) assembly ("memory-safe") { revert(add(output, 32), mload(output)) }
        require(
            recovery.finalityRecoveryRecord(nextAction).executed,
            "same successor executes after owner restore"
        );
        require(
            recovery.finalityRecoveryRecord(nextAction).predecessorRecoveryId == action,
            "exact append lineage"
        );
    }

    function testActualOriginalFrozenServingSurvivesExecutorHostLoss() public {
        address executor = address(fixture.actionHost());
        bytes memory code = executor.code;
        bytes32 before_ = _historicalServingHash(bytes32(0));
        vm.etch(executor, hex"");
        require(
            _historicalServingHash(bytes32(0)) == before_, "original survives Executor code loss"
        );
        vm.etch(executor, code);
        require(_historicalServingHash(bytes32(0)) == before_, "original Executor restore parity");
    }

    function testActualRecoveredServingSurvivesExecutorLossWhileNewPreparationRejects() public {
        MetadataRecoveryRendererBoundary renderer = new MetadataRecoveryRendererBoundary();
        bytes32 action = fixture.recoverRenderer(address(renderer));
        StreamArtworkFinalityRecovery recovery = fixture.recovery();
        StreamFinalityRecoveryRequest memory next = fixture.prepareRendererSuccessor(action);
        IStreamArtistRecoveryIntent.Facts memory facts = recovery.requireArtistRecoveryIntent(
            next.scope, next.expectedOriginalFinalityRecordHash, next.recoveryManifest.contentHash
        );
        bytes32 before_ = _historicalServingHash(action);
        address executor = address(fixture.actionHost());
        bytes memory code = executor.code;
        vm.etch(executor, hex"");
        require(_historicalServingHash(action) == before_, "recovered survives Executor code loss");
        (bool ok, bytes memory output) = address(recovery)
            .staticcall(
                abi.encodeCall(
                    recovery.requireArtistRecoveryIntent,
                    (
                        next.scope,
                        next.expectedOriginalFinalityRecordHash,
                        next.recoveryManifest.contentHash
                    )
                )
            );
        require(
            !ok
                && keccak256(output)
                    == keccak256(
                        abi.encodeWithSelector(
                            StreamFinalityRecoveryBindings.FinalityRecoveryBindingChanged.selector,
                            executor
                        )
                    ),
            "new preparation rejects exact missing Executor pin"
        );
        bytes32 nextAction = keccak256("successor recovery context boundary");
        require(
            !recovery.finalityRecoveryRecord(nextAction).executed,
            "unadmitted successor not appended"
        );
        require(_historicalServingHash(action) == before_, "failed preparation preserves history");
        vm.etch(executor, code);
        IStreamArtistRecoveryIntent.Facts memory restored = recovery.requireArtistRecoveryIntent(
            next.scope, next.expectedOriginalFinalityRecordHash, next.recoveryManifest.contentHash
        );
        require(
            keccak256(abi.encode(restored)) == keccak256(abi.encode(facts)),
            "exact Executor preparation restored"
        );
        (ok, output) = fixture.actionHost()
            .run(
                address(recovery),
                abi.encodeCall(recovery.executeFinalityRecovery, (next)),
                [nextAction, facts.scopeHash, facts.oldValueHash, facts.newValueHash],
                2
            );
        if (!ok) assembly ("memory-safe") { revert(add(output, 32), mload(output)) }
        require(
            recovery.finalityRecoveryRecord(nextAction).executed,
            "same request executes after Executor restore"
        );
        require(
            recovery.finalityRecoveryRecord(nextAction).predecessorRecoveryId == action,
            "Executor restore exact lineage"
        );
    }

    function _changeOwnerAnswers(address owner) private {
        CompanionDependencyBoundary(owner)
            .answer(
                abi.encodeCall(IStreamFinalityRecoveryOwnerBindings.core, ()),
                abi.encode(address(1))
            );
        CompanionDependencyBoundary(owner)
            .answer(
                abi.encodeCall(IStreamFinalityRecoveryOwnerBindings.governanceAuthority, ()),
                abi.encode(address(2))
            );
    }

    function _historicalServingHash(bytes32 action) private view returns (bytes32) {
        StreamArtworkFinalityRecovery recovery = fixture.recovery();
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 91, 0);
        (bool routeOk, bytes memory route) = address(recovery)
            .staticcall(
                abi.encodeCall(recovery.resolvedFinalityRoute, (keccak256("RENDERER"), scope))
            );
        (bool statusOk, bytes memory status) = address(recovery)
            .staticcall(
                abi.encodeCall(recovery.finalityRecoveryRouteStatus, (keccak256("RENDERER"), scope))
            );
        require(routeOk && statusOk, "actual canonical historical route reads");
        return keccak256(
            abi.encode(
                route,
                status,
                recovery.finalityRecoveryRecord(action),
                fixture.original().collectionFinalityRecord(1),
                fixture.router().tokenMetadataJSON(fixture.coreAddress(), 91),
                fixture.router().contractURIForCollection(fixture.coreAddress(), 1)
            )
        );
    }

    function testActualRendererRecoveryAfterOldCodeLossUsesNewRendererAndOriginalSourceFamilies()
        public
    {
        StreamMetadataRouter router = fixture.router();
        address core = fixture.coreAddress();
        address renderer = fixture.originalRenderer();
        vm.etch(renderer, hex"00");
        vm.expectRevert();
        router.tokenMetadataJSON(core, 91);
        MetadataRecoveryRendererBoundary replacement = new MetadataRecoveryRendererBoundary();
        bytes32 action = fixture.recoverRenderer(address(replacement));
        bytes memory output = bytes(router.tokenMetadataJSON(core, 91));
        bytes memory prefix = abi.encodePacked(
            "RECOVERED:Actual original:ipfs://image:return 6529;:", hex"1234", ":"
        );
        require(output.length > prefix.length, "actual replacement returned artist suffix");
        for (uint256 i; i < prefix.length; ++i) {
            require(output[i] == prefix[i], "selected renderer consumes unchanged family bytes");
        }
        StreamArtworkFinalityRecovery recovery = fixture.recovery();
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 91, 0);
        (bool pinned,, bytes32 routeHash, bytes32 original, bytes32 id) =
            recovery.resolvedFinalityRoute(keccak256("RENDERER"), scope);
        require(
            pinned && routeHash != 0 && original == fixture.originalHash() && id == action,
            "actual inherited recovered renderer"
        );
        (,,, bytes32 mediaOriginal, bytes32 mediaRecovery) =
            recovery.resolvedFinalityRoute(keccak256("MEDIA_MANIFEST"), scope);
        require(mediaOriginal == original && mediaRecovery == 0, "media original route retained");
        require(
            recovery.finalityRecoveryRecord(action).executed
                && fixture.original().collectionFinalityRecord(1).finalityRecordHash == original,
            "append preserves immutable original"
        );
    }
}
