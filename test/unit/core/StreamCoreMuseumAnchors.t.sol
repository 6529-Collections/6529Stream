// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCorePermanentTarget.t.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamConditionSources.sol";

/// @dev Typed governance context surrounding an actual production Core.
contract CoreMuseumGovernanceBoundary is PermanentTargetGovernanceExecutor {
    function executeThenReject(address target, bytes calldata data) external {
        (bool ok, bytes memory reason) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        revert("downstream batch rejected");
    }
}

/// @dev Selected metadata facade and entropy callback, without simulated Core storage.
contract CoreMuseumFacadeBoundary {
    bool public callbackEnabled;
    bool public bubbleCallback;
    bool public callbackSucceeded;
    bytes4 public callbackError;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamCollectionMetadataV1).interfaceId
            || id == type(IStreamEntropyCoordinator).interfaceId || id == 0x01ffc9a7;
    }

    function declare(StreamCore target, uint256 collectionId, bytes32 tier) external {
        target.recordConservationTier(collectionId, tier);
    }

    function setCallback(bool enabled, bool bubble) external {
        callbackEnabled = enabled;
        bubbleCallback = bubble;
    }

    function onTokenMinted(uint256 collectionId, uint256, address, bytes32) external {
        if (!callbackEnabled) return;
        (bool ok, bytes memory reason) = msg.sender
            .call(
                abi.encodeCall(
                    IStreamCoreConservationTier.recordConservationTier,
                    (collectionId, keccak256("MUSEUM_GRADE"))
                )
            );
        callbackSucceeded = ok;
        if (reason.length >= 4) callbackError = bytes4(reason);
        if (bubbleCallback) require(ok, "callback declaration rejected");
    }
}

/// @dev Configurable fixed-width source handshake; no catalog completeness claim.
contract CoreMuseumSourcesBoundary {
    mapping(bytes4 => uint256) private _words;
    bytes4 private _badSelector;
    uint8 private _badShape;
    uint256 public headCount;
    bytes32 public head = keccak256("typed nonempty source-set commitment");

    constructor(address core_, address executor_) {
        _words[IStreamConditionSources.core.selector] = uint160(core_);
        _words[IStreamConditionSources.coreCodeHash.selector] = uint256(core_.codehash);
        _words[IStreamGasParameterHost.governanceAuthority.selector] = uint160(executor_);
        _words[IStreamConditionSources.executorCodeHash.selector] = uint256(executor_.codehash);
        _words[IStreamConditionSources.deploymentChainId.selector] = block.chainid;
        _words[IERC165.supportsInterface.selector] = 1;
    }

    function change(bytes4 selector, uint256 value) external {
        _words[selector] = value;
    }

    function malformed(bytes4 selector, uint8 shape) external {
        _badSelector = selector;
        _badShape = shape;
    }

    function configureHead(uint256 count, bytes32 hash) external {
        headCount = count;
        head = hash;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return _word() == 1 && (id == type(IStreamConditionSources).interfaceId || id == 0x01ffc9a7);
    }

    function core() external view returns (address) {
        return address(uint160(_word()));
    }

    function coreCodeHash() external view returns (bytes32) {
        return bytes32(_word());
    }

    function governanceAuthority() external view returns (address) {
        return address(uint160(_word()));
    }

    function executorCodeHash() external view returns (bytes32) {
        return bytes32(_word());
    }

    function deploymentChainId() external view returns (uint256) {
        return _word();
    }

    function sourceSetHead() external view returns (uint256, bytes32) {
        _shape();
        return (headCount, head);
    }

    function _word() private view returns (uint256) {
        _shape();
        return _words[msg.sig];
    }

    function _shape() private view {
        if (msg.sig != _badSelector || _badShape == 0) return;
        uint8 shape = _badShape;
        if (shape == 1) revert("typed source unavailable");
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 1)
            mstore(add(ptr, 32), 1)
            switch shape
            case 2 { return(ptr, 31) }
            case 3 { return(ptr, 96) }
            default { return(ptr, 0) }
        }
    }
}

/// @notice Actual Core declarations, original mint lifecycle and one-time catalog storage.
/// @dev Governance/registry, metadata, manager, entropy and source-handshake boundaries are typed.
///      No vm.store modifies Core storage. Actual canonical governance/Safe is covered separately.
contract StreamCoreMuseumAnchorsTest is CharacterizationTestBase {
    PermanentTargetCoreHarness private target;
    CoreMuseumGovernanceBoundary private authority;
    PermanentTargetModuleRegistry private modules;
    PermanentTargetMintManager private manager;
    CoreMuseumFacadeBoundary private facade;
    bytes32 private constant METADATA = keccak256("COLLECTION_METADATA");
    bytes32 private constant MANAGER = keccak256("MINT_MANAGER");
    bytes32 private constant ENTROPY = keccak256("ENTROPY_COORDINATOR");
    bytes32 private constant MANIFEST = keccak256("museum core module manifest");
    bytes32 private constant DEPLOYMENT = keccak256("museum core deployment manifest");
    bytes32 private constant FULL = keccak256("MUSEUM_GRADE");
    bytes32 private constant LITE = keccak256("MUSEUM_GRADE_LITE");
    bytes32 private constant WAIVED = keccak256("CONSERVATION_WAIVED");

    event ConservationTierRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed tier,
        address indexed metadataHost
    );
    event ConditionSourcesBound(
        uint16 schemaVersion,
        address indexed catalog,
        bytes32 runtimeCodeHash,
        bytes32 indexed actionId
    );

    function setUp() public {
        authority = new CoreMuseumGovernanceBoundary();
        modules = new PermanentTargetModuleRegistry();
        modules.setGovernanceExecutor(address(authority));
        StreamCore.GasParameterGenesisConfig[] memory gasRows =
            new StreamCore.GasParameterGenesisConfig[](4);
        gasRows[0] = StreamCore.GasParameterGenesisConfig(
            0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda, 50000, 25000, 1
        );
        gasRows[1] = StreamCore.GasParameterGenesisConfig(
            0x0af6f5a1a5059e398191fa0af185be12fee6d609933826603244c7f247793be7, 2910000, 1460000, 1
        );
        gasRows[2] = StreamCore.GasParameterGenesisConfig(
            0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93, 500000, 250000, 1
        );
        gasRows[3] = StreamCore.GasParameterGenesisConfig(
            0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17, 120000, 120000, 2
        );
        target = new PermanentTargetCoreHarness(
            "Museum Core",
            "MUSEUM",
            address(authority),
            StreamCore.GenesisModuleRegistryConfig(
                address(modules), address(modules).codehash, MANIFEST, DEPLOYMENT
            ),
            gasRows
        );
        modules.setRecord(
            address(modules),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            MANIFEST,
            DEPLOYMENT
        );
        facade = new CoreMuseumFacadeBoundary();
        manager = new PermanentTargetMintManager();
        _pointer(METADATA, address(facade), type(IStreamCollectionMetadataV1).interfaceId);
        _pointer(MANAGER, address(manager), type(IStreamMintManager).interfaceId);
        _pointer(ENTROPY, address(facade), type(IStreamEntropyCoordinator).interfaceId);
        _createCollection();
    }

    function _pointer(bytes32 kind, address candidate, bytes4 interfaceId) private {
        modules.setRecord(candidate, kind, interfaceId, MANIFEST, DEPLOYMENT);
        StreamCorePointerState memory oldState = target.pointerState(kind);
        StreamCorePointerState memory newState = StreamCorePointerState(
            candidate,
            candidate.codehash,
            false,
            kind,
            interfaceId,
            address(modules),
            uint8(ModuleRegistryStatus.ACTIVE),
            MANIFEST,
            DEPLOYMENT,
            oldState.revision + 1
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.pointerTransitionHashes(kind, oldState, newState);
        authority.setAction(3, scope, oldHash, newHash);
        authority.execute(
            address(target), abi.encodeCall(target.updateSatellitePointer, (kind, candidate))
        );
    }

    function _createCollection() private {
        uint256 id = target.lastAllocatedCollectionId() + 1;
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                block.chainid,
                address(target),
                id
            )
        );
        bytes32 domain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        authority.setAction(
            1,
            scope,
            keccak256(abi.encode(domain, scope, false, uint8(0), uint8(0), false, uint256(0))),
            keccak256(abi.encode(domain, scope, true, uint8(2), uint8(0), false, uint256(0)))
        );
        authority.execute(
            address(target),
            abi.encodeCall(target.createCollection, (uint8(2), false, uint256(0), uint8(0)))
        );
    }

    function _sources() private returns (CoreMuseumSourcesBoundary) {
        return new CoreMuseumSourcesBoundary(address(target), address(authority));
    }

    function _plan(address candidate) private returns (bytes32 actionId) {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.conditionSourcesTransition(candidate);
        authority.setAction(1, scope, oldHash, newHash);
        (, actionId,,,,) = authority.currentAction();
    }

    function _bind(address candidate) private {
        authority.execute(address(target), abi.encodeCall(target.bindConditionSources, (candidate)));
    }

    function testSelectedFacadeRecordsOriginalTierAndEvent() public {
        vm.expectEmit(true, true, true, true);
        emit ConservationTierRecorded(1, 1, FULL, address(facade));
        facade.declare(target, 1, FULL);
        require(
            target.declaredConservationTier(1) == FULL && target.collectionMintedEver(1) == 0,
            "original Core choice"
        );
        require(
            target.supportsInterface(type(IStreamCoreConservationTier).interfaceId)
                && target.supportsInterface(type(IStreamCoreConditionSources).interfaceId),
            "new typed interfaces"
        );
    }

    function testForeignCallerCannotRecordEvenKnownTier() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAuthorityRequired.selector
            )
        );
        target.recordConservationTier(1, FULL);
        CoreMuseumFacadeBoundary foreign = new CoreMuseumFacadeBoundary();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAuthorityRequired.selector
            )
        );
        foreign.declare(target, 1, FULL);
        require(target.declaredConservationTier(1) == 0, "foreign no choice");
    }

    function testSelectedFacadeRuntimeChangeRejectsItsSender() public {
        vm.etch(address(facade), abi.encodePacked(address(facade).code, hex"00"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAuthorityRequired.selector
            )
        );
        facade.declare(target, 1, LITE);
        require(target.declaredConservationTier(1) == 0, "codepin enforced");
    }

    function testFacadeReplacementCannotEraseOrRewriteOriginalChoice() public {
        facade.declare(target, 1, WAIVED);
        CoreMuseumFacadeBoundary previous = facade;
        facade = new CoreMuseumFacadeBoundary();
        _pointer(METADATA, address(facade), type(IStreamCollectionMetadataV1).interfaceId);
        require(
            target.declaredConservationTier(1) == WAIVED,
            "replacement retains exact explicit choice"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAlreadyDeclared.selector, uint256(1)
            )
        );
        facade.declare(target, 1, FULL);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAuthorityRequired.selector
            )
        );
        previous.declare(target, 1, FULL);
        _createCollection();
        facade.declare(target, 2, LITE);
        require(
            target.declaredConservationTier(2) == LITE, "current facade retains write authority"
        );
    }

    function testUnknownCollectionUnknownTierAndRepeatReject() public {
        vm.expectRevert(abi.encodeWithSelector(StreamCore.CollectionUnknown.selector, uint256(999)));
        facade.declare(target, 999, FULL);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.InvalidConservationTier.selector, bytes32(0)
            )
        );
        facade.declare(target, 1, 0);
        facade.declare(target, 1, LITE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAlreadyDeclared.selector, uint256(1)
            )
        );
        facade.declare(target, 1, LITE);
    }

    function testCompletedFirstMintAndBurnCannotResetTierDeadline() public {
        (uint256 token,) = manager.mint(target, 1, address(0xBEEF), "", keccak256("completed"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAfterFirstMint.selector, uint256(1)
            )
        );
        facade.declare(target, 1, LITE);
        vm.prank(address(0xBEEF));
        target.burn(token);
        require(
            target.totalSupplyOfCollection(1) == 0 && target.collectionMintedEver(1) == 1,
            "burn retains completed history"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAfterFirstMint.selector, uint256(1)
            )
        );
        facade.declare(target, 1, WAIVED);
        require(target.declaredConservationTier(1) == 0, "absence remains original absence");
    }

    function testPreparedAllocationAllowsDeclarationBeforeCompletedMint() public {
        bytes32 operation = keccak256("pending museum mint");
        (uint256 token,) = manager.prepare(target, 1, "", operation);
        require(
            target.collectionMintedEver(1) == 0 && target.pendingPreparedMintTokenId() == token,
            "allocated not completed"
        );
        facade.declare(target, 1, FULL);
        manager.complete(target, token, address(0xBEEF), operation, keccak256("complete pending"));
        require(
            target.collectionMintedEver(1) == 1 && target.declaredConservationTier(1) == FULL,
            "completion keeps original tier"
        );
    }

    function testCompletionCallbackCannotDeclareBeforeMintedEverIncrement() public {
        facade.setCallback(true, false);
        manager.mint(target, 1, address(0xBEEF), "", keccak256("callback"));
        require(
            !facade.callbackSucceeded()
                && facade.callbackError() == StreamCore.MintExecutionInProgress.selector,
            "callback denied even before completed counter"
        );
        require(
            target.collectionMintedEver(1) == 1 && target.declaredConservationTier(1) == 0,
            "mint completes without illicit tier"
        );
    }

    function testFailedCompletionRollsBackAllocationAndLeavesDeclarationAvailable() public {
        facade.setCallback(true, true);
        vm.expectRevert(abi.encodeWithSelector(StreamCore.EntropyRegistrationFailed.selector));
        manager.mint(target, 1, address(0xBEEF), "", keccak256("failed callback"));
        require(
            target.lastAllocatedTokenId() == 0 && target.collectionMintedEver(1) == 0,
            "mint and allocation rolled back"
        );
        facade.declare(target, 1, LITE);
        require(
            target.declaredConservationTier(1) == LITE,
            "failed mint did not consume declaration window"
        );
    }

    function testConditionBindingExactHashEventAndReplayDenial() public {
        CoreMuseumSourcesBoundary candidate = _sources();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.conditionSourcesTransition(address(candidate));
        bytes32 expectedScope = keccak256(
            abi.encode(
                keccak256("6529STREAM_CORE_CONDITION_SOURCES_SCOPE_V1"),
                block.chainid,
                address(target)
            )
        );
        bytes32 domain = keccak256("6529STREAM_CORE_CONDITION_SOURCES_STATE_V1");
        require(
            scope == expectedScope
                && oldHash == keccak256(abi.encode(domain, scope, address(0), bytes32(0)))
                && newHash
                    == keccak256(
                        abi.encode(domain, scope, address(candidate), address(candidate).codehash)
                    ),
            "independent exact hash recipe"
        );
        bytes32 id = _plan(address(candidate));
        vm.expectEmit(true, true, false, true);
        emit ConditionSourcesBound(1, address(candidate), address(candidate).codehash, id);
        _bind(address(candidate));
        (address bound, bytes32 pinned) = target.conditionSources();
        require(
            bound == address(candidate) && pinned == address(candidate).codehash,
            "actual durable binding"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConditionSources.ConditionSourcesAlreadyBound.selector
            )
        );
        _bind(address(candidate));
        address alternative = address(_sources());
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConditionSources.ConditionSourcesAlreadyBound.selector
            )
        );
        target.conditionSourcesTransition(alternative);
    }

    function testConditionBindingRejectsForeignCallerAndWrongClassOrCommitment() public {
        address candidate = address(_sources());
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.UnauthorizedGovernanceExecutor.selector, address(this)
            )
        );
        target.bindConditionSources(candidate);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.conditionSourcesTransition(candidate);
        authority.setAction(3, scope, oldHash, newHash);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.GovernanceActionClassMismatch.selector, uint8(1), uint8(3)
            )
        );
        _bind(candidate);
        authority.setAction(1, scope, oldHash, bytes32(uint256(newHash) ^ 1));
        vm.expectRevert(abi.encodeWithSelector(StreamCore.GovernanceTransitionMismatch.selector));
        _bind(candidate);
        (address bound,) = target.conditionSources();
        require(bound == address(0), "all rejected bindings leave empty anchor");
    }

    function testConditionHandshakeRejectsForeignCoreExecutorChainAndPins() public {
        bytes4[6] memory selectors = [
            IStreamConditionSources.core.selector,
            IStreamConditionSources.coreCodeHash.selector,
            IStreamGasParameterHost.governanceAuthority.selector,
            IStreamConditionSources.executorCodeHash.selector,
            IStreamConditionSources.deploymentChainId.selector,
            IERC165.supportsInterface.selector
        ];
        for (uint256 i; i < selectors.length; ++i) {
            CoreMuseumSourcesBoundary candidate = _sources();
            candidate.change(selectors[i], 0);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamCoreConditionSources.InvalidConditionSources.selector, address(candidate)
                )
            );
            target.conditionSourcesTransition(address(candidate));
        }
    }

    function testConditionHandshakeRejectsMalformedFixedReadsAndHead() public {
        bytes4[7] memory selectors = [
            IStreamConditionSources.core.selector,
            IStreamConditionSources.coreCodeHash.selector,
            IStreamGasParameterHost.governanceAuthority.selector,
            IStreamConditionSources.executorCodeHash.selector,
            IStreamConditionSources.deploymentChainId.selector,
            IERC165.supportsInterface.selector,
            IStreamConditionSources.sourceSetHead.selector
        ];
        CoreMuseumSourcesBoundary candidate = _sources();
        for (uint256 i; i < selectors.length; ++i) {
            for (uint8 shape = 1; shape <= 4; ++shape) {
                candidate.malformed(selectors[i], shape);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IStreamCoreConditionSources.InvalidConditionSources.selector,
                        address(candidate)
                    )
                );
                target.conditionSourcesTransition(address(candidate));
            }
        }
        candidate.malformed(bytes4(0), 0);
        candidate.configureHead(uint256(type(uint64).max) + 1, keccak256("head"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConditionSources.InvalidConditionSources.selector, address(candidate)
            )
        );
        target.conditionSourcesTransition(address(candidate));
        candidate.configureHead(0, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConditionSources.InvalidConditionSources.selector, address(candidate)
            )
        );
        target.conditionSourcesTransition(address(candidate));
    }

    function testConditionRuntimeChangeInvalidatesScheduledCommitment() public {
        address candidate = address(_sources());
        _plan(candidate);
        vm.etch(candidate, abi.encodePacked(candidate.code, hex"00"));
        vm.expectRevert(abi.encodeWithSelector(StreamCore.GovernanceTransitionMismatch.selector));
        _bind(candidate);
        (address bound,) = target.conditionSources();
        require(bound == address(0), "changed runtime not admitted");
        _plan(candidate);
        _bind(candidate);
        (, bytes32 pinned) = target.conditionSources();
        vm.etch(candidate, abi.encodePacked(candidate.code, hex"00"));
        (, bytes32 retained) = target.conditionSources();
        require(
            retained == pinned && retained != candidate.codehash,
            "anchor never follows a changed runtime"
        );
    }

    function testConditionBindingAtomicRollbackAllowsIdenticalRetry() public {
        address candidate = address(_sources());
        _plan(candidate);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "downstream batch rejected"));
        authority.executeThenReject(
            address(target), abi.encodeCall(target.bindConditionSources, (candidate))
        );
        (address bound,) = target.conditionSources();
        require(bound == address(0), "downstream failure rolls back anchor");
        _bind(candidate);
        (bound,) = target.conditionSources();
        require(bound == candidate, "identical action retry after rollback");
    }

    function testConditionBindingCannotRunDuringPreparedMint() public {
        address candidate = address(_sources());
        _plan(candidate);
        manager.prepare(target, 1, "", keccak256("pending"));
        vm.expectRevert(abi.encodeWithSelector(StreamCore.PreparedMintAlreadyPending.selector));
        _bind(candidate);
        (address bound,) = target.conditionSources();
        require(bound == address(0), "pending lifecycle preserved");
    }

    function testFuzzOnlyRecognizedTierCanBeRecorded(bytes32 tier) public {
        if (tier != FULL && tier != LITE && tier != WAIVED) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamCoreConservationTier.InvalidConservationTier.selector, tier
                )
            );
            facade.declare(target, 1, tier);
            require(target.declaredConservationTier(1) == 0, "unknown tier not stored");
        } else {
            facade.declare(target, 1, tier);
            require(target.declaredConservationTier(1) == tier, "exact accepted tier");
        }
    }

    function testFuzzConditionBindingRequiresExactNewCommitment(bytes32 suppliedHash) public {
        address candidate = address(_sources());
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.conditionSourcesTransition(candidate);
        authority.setAction(1, scope, oldHash, suppliedHash);
        if (suppliedHash != newHash) {
            vm.expectRevert(
                abi.encodeWithSelector(StreamCore.GovernanceTransitionMismatch.selector)
            );
            _bind(candidate);
            (address bound,) = target.conditionSources();
            require(bound == address(0), "wrong commitment no mutation");
        } else {
            _bind(candidate);
        }
    }
}
