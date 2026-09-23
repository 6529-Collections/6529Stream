// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCoreMuseumAnchors.t.sol";
import "../../helpers/StreamGovernanceBootstrapHarness.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamConservationFloor.sol";

/// @dev Exact additive caller ABI while the independently owned production Core join lands.
interface CoreConservationFloorTestApi {
    error ConservationFloorAlreadyBound();
    error InvalidConservationFloor(address candidate);
    function conservationFloor() external view returns (address, bytes32);
    function conservationFloorTransition(address candidate)
        external
        view
        returns (bytes32, bytes32, bytes32);
    function bindConservationFloor(address candidate) external;
}

/// @dev The original typed identity/head fixture, with the dedicated floor interface beacon.
contract CoreFloorCandidateBoundary {
    CoreMuseumSourcesBoundary public immutable backing;

    constructor(address core_, address executor_) {
        backing = new CoreMuseumSourcesBoundary(core_, executor_);
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        (bool ok, bytes memory output) = address(backing)
            .staticcall(
                abi.encodeCall(
                    IERC165.supportsInterface, (type(IStreamConditionSources).interfaceId)
                )
            );
        if (!ok) assembly ("memory-safe") { revert(add(output, 32), mload(output)) }
        // Preserve malformed replies for Core's exact-size check. A typed bool call would
        // accept an overlong backing reply and silently re-encode it as canonical 32 bytes.
        if (output.length != 32) {
            assembly ("memory-safe") { return(add(output, 32), mload(output)) }
        }
        return abi.decode(output, (bool))
            && (id == type(IStreamConservationFloor).interfaceId || id == 0x01ffc9a7);
    }

    fallback() external {
        (bool ok, bytes memory output) = address(backing).staticcall(msg.data);
        if (!ok) assembly ("memory-safe") { revert(add(output, 32), mload(output)) }
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }
}

/// @dev Attempts a real scheduled Executor batch during actual Core mint completion.
contract CoreFloorMintCallbackBoundary {
    address private immutable _executor;
    bytes private _execution;
    bool public attempted;
    bool public succeeded;
    bool public observedMintGuard;

    constructor(address executor_) {
        _executor = executor_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamEntropyCoordinator).interfaceId || id == 0x01ffc9a7;
    }

    function configure(bytes calldata execution) external {
        _execution = execution;
    }

    function onTokenMinted(uint256, uint256, address, bytes32) external {
        if (_execution.length == 0) return;
        attempted = true;
        bytes memory reason;
        (succeeded, reason) = _executor.call(_execution);
        bytes4 expected = StreamCore.MintExecutionInProgress.selector;
        for (uint256 i; i + 4 <= reason.length; ++i) {
            bytes4 actual;
            assembly ("memory-safe") { actual := mload(add(add(reason, 32), i)) }
            if (actual == expected) {
                observedMintGuard = true;
                break;
            }
        }
    }
}

contract CoreFloorLateFailureBoundary {
    bool public reject = true;
    uint256 public calls;

    function setReject(bool value) external {
        reject = value;
    }

    function perform() external {
        require(!reject, "late floor batch rejection");
        ++calls;
    }
}

/// @notice Actual production Core governed by a sealed real Executor and RoleRegistry.
/// @dev Bootstrap inventory, module registry, floor identity and mint/entropy are typed boundaries.
///      Official Safe cases use threshold signatures. No frozen51 source, fixture or capture is edited.
contract StreamCoreConservationFloorTest is StreamGovernanceBootstrapHarness, OfficialSafeFixture {
    PermanentTargetCoreHarness private target;
    CoreConservationFloorTestApi private anchor;
    PermanentTargetModuleRegistry private modules;
    StreamGovernanceBootstrapTriggerMock private prefix;
    CoreFloorLateFailureBoundary private lateFailure;
    BootstrapArtifacts private b;
    OfficialSafe private governor;
    uint256[] private governorKeys;
    bytes32 private constant MANIFEST = keccak256("floor anchor module manifest");
    bytes32 private constant DEPLOYMENT = keccak256("floor anchor deployment manifest");

    event ConservationFloorBound(
        uint16 schemaVersion,
        address indexed floor,
        bytes32 runtimeCodeHash,
        bytes32 indexed actionId
    );

    function _additionalActionPolicies(BootstrapArtifacts memory a)
        internal
        override
        returns (GovernanceActionPolicyEntry[] memory entries)
    {
        modules = new PermanentTargetModuleRegistry();
        modules.setGovernanceExecutor(address(a.executor));
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
        // Typed callback executes a genuine governance batch; this is its explicit genesis budget.
        gasRows[3] = StreamCore.GasParameterGenesisConfig(
            0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17, 2000000, 120000, 2
        );
        target = new PermanentTargetCoreHarness(
            "Floor Anchor Core",
            "FLOOR",
            address(a.executor),
            StreamCore.GenesisModuleRegistryConfig(
                address(modules), address(modules).codehash, MANIFEST, DEPLOYMENT
            ),
            gasRows
        );
        anchor = CoreConservationFloorTestApi(address(target));
        modules.setRecord(
            address(modules),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            MANIFEST,
            DEPLOYMENT
        );
        prefix = new StreamGovernanceBootstrapTriggerMock();
        lateFailure = new CoreFloorLateFailureBoundary();
        entries = new GovernanceActionPolicyEntry[](8);
        entries[0] = _zeroPolicy(
            1, address(target), anchor.bindConservationFloor.selector, keccak256("floor anchor")
        );
        entries[1] = _zeroPolicy(
            2,
            address(target),
            anchor.bindConservationFloor.selector,
            keccak256("floor anchor wrong class")
        );
        entries[2] = _zeroPolicy(
            3,
            address(target),
            anchor.bindConservationFloor.selector,
            keccak256("floor anchor wrong class")
        );
        entries[3] = _zeroPolicy(
            1, address(prefix), prefix.bootstrapWrite.selector, keccak256("floor prefix")
        );
        entries[4] = _zeroPolicy(
            1, address(target), target.createCollection.selector, keccak256("floor collection")
        );
        entries[5] = _zeroPolicy(
            3,
            address(target),
            target.updateSatellitePointer.selector,
            keccak256("floor fixture pointers")
        );
        entries[6] = _zeroPolicy(
            1,
            address(target),
            target.bindConditionSources.selector,
            keccak256("separate condition anchor")
        );
        entries[7] = _zeroPolicy(
            1,
            address(lateFailure),
            lateFailure.perform.selector,
            keccak256("floor late failure boundary")
        );
    }

    function _setup(bool safeRoot) private {
        vm.warp(1000);
        address root = address(this);
        if (safeRoot) {
            uint256[] memory owners = new uint256[](3);
            owners[0] = 811;
            owners[1] = 812;
            owners[2] = 813;
            governor = createOfficialSafe(
                deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 8119
            );
            governorKeys.push(owners[0]);
            governorKeys.push(owners[1]);
            root = address(governor);
        }
        b = _deploySealedExecutor(root);
    }

    function _candidate() private returns (CoreFloorCandidateBoundary) {
        return new CoreFloorCandidateBoundary(address(target), address(b.executor));
    }

    function _call(
        address receiver,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private pure returns (GovernanceCall memory) {
        return GovernanceCall(receiver, 0, bytes4(data), keccak256(data), scope, oldHash, newHash);
    }

    function _batch(address candidate, bool withPrefix)
        private
        view
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        uint256 index = withPrefix ? 1 : 0;
        calls = new GovernanceCall[](index + 1);
        data = new bytes[](index + 1);
        if (withPrefix) {
            data[0] = abi.encodeCall(prefix.bootstrapWrite, (uint256(99)));
            calls[0] = _call(
                address(prefix),
                data[0],
                keccak256("prefix scope"),
                keccak256("prefix old"),
                keccak256("prefix new")
            );
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            anchor.conservationFloorTransition(candidate);
        data[index] = abi.encodeCall(anchor.bindConservationFloor, (candidate));
        calls[index] = _call(address(target), data[index], scope, oldHash, newHash);
    }

    function _schedule(uint8 actionClass, GovernanceCall[] memory calls, bytes[] memory data)
        private
        returns (bytes32 id, uint64 ready)
    {
        b.executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        ready = uint64(block.timestamp + b.executor.minimumDelay(actionClass));
        bytes memory input = abi.encodeCall(
            b.executor.scheduleGovernanceBatch,
            (
                actionClass,
                calls,
                scope,
                oldHash,
                newHash,
                ready,
                ready + 7 days,
                keccak256("floor anchor acceptance"),
                "urn:stream:test:floor-anchor",
                b.manifestHash
            )
        );
        if (address(governor) == address(0)) {
            (bool ok, bytes memory output) = address(b.executor).call(input);
            require(ok, "actual root schedules");
            id = abi.decode(output, (bytes32));
        } else {
            vm.recordLogs();
            require(
                executeSafe(governor, governorKeys, address(b.executor), 0, input, 0),
                "actual threshold Safe schedules"
            );
            Vm.Log[] memory logs = vm.getRecordedLogs();
            bytes32 topic = keccak256(
                "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
            );
            for (uint256 i; i < logs.length; ++i) {
                if (
                    logs[i].emitter == address(b.executor) && logs[i].topics.length == 4
                        && logs[i].topics[0] == topic
                ) id = logs[i].topics[1];
            }
            require(id != 0, "original schedule event");
        }
    }

    function _execute(bytes32 id, GovernanceCall[] memory calls, bytes[] memory data)
        private
        returns (bool, bytes memory)
    {
        return address(b.executor)
            .call(abi.encodeCall(b.executor.executeGovernanceBatch, (id, calls, data)));
    }

    function _governOne(uint8 actionClass, GovernanceCall memory item, bytes memory input) private {
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = item;
        bytes[] memory data = new bytes[](1);
        data[0] = input;
        (bytes32 id, uint64 ready) = _schedule(actionClass, calls, data);
        vm.warp(ready);
        b.executor.executeGovernanceBatch(id, calls, data);
    }

    function _assertUnbound() private view {
        (address actual, bytes32 hash) = anchor.conservationFloor();
        require(actual == address(0) && hash == 0, "unbound floor anchor");
    }

    function _contains(bytes memory data, bytes4 expected) private pure returns (bool) {
        for (uint256 i; i + 4 <= data.length; ++i) {
            bytes4 actual;
            assembly ("memory-safe") { actual := mload(add(add(data, 32), i)) }
            if (actual == expected) return true;
        }
        return false;
    }

    function testFloorAnchorActualGovernanceExactHashesEventEmptyHeadAndReplay() public {
        _setup(false);
        address candidate = address(_candidate());
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            anchor.conservationFloorTransition(candidate);
        bytes32 expectedScope = keccak256(
            abi.encode(
                keccak256("6529STREAM_CORE_CONSERVATION_FLOOR_SCOPE_V1"),
                block.chainid,
                address(target)
            )
        );
        bytes32 domain = keccak256("6529STREAM_CORE_CONSERVATION_FLOOR_STATE_V1");
        require(
            scope == expectedScope
                && oldHash == keccak256(abi.encode(domain, scope, address(0), bytes32(0)))
                && newHash == keccak256(abi.encode(domain, scope, candidate, candidate.codehash)),
            "independent exact floor hash recipe"
        );
        (uint64 count, bytes32 head) = IStreamConservationFloor(candidate).sourceSetHead();
        require(count == 0 && head != 0, "well-formed empty source denominator may be bound");
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(candidate, false);
        (bytes32 id, uint64 ready) = _schedule(1, calls, data);
        (bool early,) = _execute(id, calls, data);
        require(!early, "actual delayed action");
        _assertUnbound();
        vm.warp(ready);
        vm.expectEmit(true, true, false, true);
        emit ConservationFloorBound(1, candidate, candidate.codehash, id);
        b.executor.executeGovernanceBatch(id, calls, data);
        (address actual, bytes32 hash) = anchor.conservationFloor();
        require(actual == candidate && hash == candidate.codehash, "exact one-time anchor");
        require(
            target.supportsInterface(type(CoreConservationFloorTestApi).interfaceId),
            "additive Core discovery"
        );
        (bool replay,) = _execute(id, calls, data);
        require(!replay, "real Executor replay refused");
        vm.expectRevert(
            abi.encodeWithSelector(
                CoreConservationFloorTestApi.ConservationFloorAlreadyBound.selector
            )
        );
        anchor.conservationFloorTransition(candidate);
    }

    function testFloorAnchorForeignCallerAndWrongActualGovernanceClassesReject() public {
        _setup(false);
        address candidate = address(_candidate());
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.UnauthorizedGovernanceExecutor.selector, address(this)
            )
        );
        anchor.bindConservationFloor(candidate);
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(candidate, false);
        for (uint8 actionClass = 2; actionClass <= 3; ++actionClass) {
            (bytes32 id, uint64 ready) = _schedule(actionClass, calls, data);
            vm.warp(ready);
            (bool ok, bytes memory reason) = _execute(id, calls, data);
            require(
                !ok && _contains(reason, StreamCore.GovernanceActionClassMismatch.selector),
                "actual target exact class check"
            );
            require(
                b.executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
                "failed execution receipt rollback"
            );
            _assertUnbound();
        }
    }

    function testFloorAnchorWrongExactScopeOldAndNewCommitmentsReject() public {
        _setup(false);
        address candidate = address(_candidate());
        for (uint256 field; field < 3; ++field) {
            (GovernanceCall[] memory calls, bytes[] memory data) = _batch(candidate, false);
            if (field == 0) calls[0].scopeHash = keccak256("wrong scope");
            if (field == 1) calls[0].oldValueHash = keccak256("wrong old state");
            if (field == 2) calls[0].newValueHash = keccak256("wrong new state");
            (bytes32 id, uint64 ready) = _schedule(1, calls, data);
            vm.warp(ready);
            (bool ok, bytes memory reason) = _execute(id, calls, data);
            require(
                !ok && _contains(reason, StreamCore.GovernanceTransitionMismatch.selector),
                "actual target exact transition check"
            );
            _assertUnbound();
        }
    }

    function testFloorAnchorRejectsEveryIdentityPinAndConditionOnlyInterface() public {
        _setup(false);
        bytes4[6] memory selectors = [
            IStreamConservationFloor.core.selector,
            IStreamConservationFloor.coreCodeHash.selector,
            IStreamGasParameterHost.governanceAuthority.selector,
            IStreamConservationFloor.executorCodeHash.selector,
            IStreamConservationFloor.deploymentChainId.selector,
            IERC165.supportsInterface.selector
        ];
        for (uint256 i; i < selectors.length; ++i) {
            CoreFloorCandidateBoundary candidate = _candidate();
            candidate.backing().change(selectors[i], 0);
            vm.expectRevert(
                abi.encodeWithSelector(
                    CoreConservationFloorTestApi.InvalidConservationFloor.selector,
                    address(candidate)
                )
            );
            anchor.conservationFloorTransition(address(candidate));
        }
        address wrongInterface =
            address(new CoreMuseumSourcesBoundary(address(target), address(b.executor)));
        vm.expectRevert(
            abi.encodeWithSelector(
                CoreConservationFloorTestApi.InvalidConservationFloor.selector, wrongInterface
            )
        );
        anchor.conservationFloorTransition(wrongInterface);
        vm.expectRevert(
            abi.encodeWithSelector(
                CoreConservationFloorTestApi.InvalidConservationFloor.selector, address(0x123)
            )
        );
        anchor.conservationFloorTransition(address(0x123));
    }

    function testFloorAnchorMalformedIdentityAndHeadReadsReject() public {
        _setup(false);
        CoreFloorCandidateBoundary candidate = _candidate();
        bytes4[7] memory selectors = [
            IStreamConservationFloor.core.selector,
            IStreamConservationFloor.coreCodeHash.selector,
            IStreamGasParameterHost.governanceAuthority.selector,
            IStreamConservationFloor.executorCodeHash.selector,
            IStreamConservationFloor.deploymentChainId.selector,
            IERC165.supportsInterface.selector,
            IStreamConservationFloor.sourceSetHead.selector
        ];
        for (uint256 i; i < selectors.length; ++i) {
            for (uint8 shape = 1; shape <= 4; ++shape) {
                candidate.backing().malformed(selectors[i], shape);
                vm.expectRevert(
                    abi.encodeWithSelector(
                        CoreConservationFloorTestApi.InvalidConservationFloor.selector,
                        address(candidate)
                    )
                );
                anchor.conservationFloorTransition(address(candidate));
            }
        }
        candidate.backing().malformed(bytes4(0), 0);
        candidate.backing().configureHead(uint256(type(uint64).max) + 1, keccak256("head"));
        vm.expectRevert(
            abi.encodeWithSelector(
                CoreConservationFloorTestApi.InvalidConservationFloor.selector, address(candidate)
            )
        );
        anchor.conservationFloorTransition(address(candidate));
        candidate.backing().configureHead(0, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                CoreConservationFloorTestApi.InvalidConservationFloor.selector, address(candidate)
            )
        );
        anchor.conservationFloorTransition(address(candidate));
        _assertUnbound();
    }

    function testFloorAnchorRejectsDelegatedEOACandidate() public {
        _setup(false);
        address delegated = address(0xA110);
        vm.etch(delegated, abi.encodePacked(hex"ef0100", address(_candidate())));
        vm.expectRevert(
            abi.encodeWithSelector(
                CoreConservationFloorTestApi.InvalidConservationFloor.selector, delegated
            )
        );
        anchor.conservationFloorTransition(delegated);
    }

    function testFloorAnchorCodeDriftInvalidatesScheduleAndNeverRewritesStoredPin() public {
        _setup(false);
        address candidate = address(_candidate());
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(candidate, false);
        (bytes32 id, uint64 ready) = _schedule(1, calls, data);
        bytes memory originalCode = candidate.code;
        vm.etch(candidate, abi.encodePacked(originalCode, hex"00"));
        vm.warp(ready);
        (bool ok, bytes memory reason) = _execute(id, calls, data);
        require(
            !ok && _contains(reason, StreamCore.GovernanceTransitionMismatch.selector),
            "candidate runtime included in scheduled state"
        );
        _assertUnbound();
        vm.etch(candidate, originalCode);
        b.executor.executeGovernanceBatch(id, calls, data);
        (, bytes32 pinned) = anchor.conservationFloor();
        vm.etch(candidate, abi.encodePacked(originalCode, hex"00"));
        (address retained, bytes32 retainedHash) = anchor.conservationFloor();
        require(
            retained == candidate && retainedHash == pinned && retainedHash != candidate.codehash,
            "permanent anchor never follows changed runtime"
        );
    }

    function testFloorAnchorActualBatchLateFailureRollsBackPrefixAndIdenticalRetryWorks() public {
        _setup(false);
        CoreFloorCandidateBoundary candidate = _candidate();
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(address(candidate), true);
        (bytes32 id, uint64 ready) = _schedule(1, calls, data);
        candidate.backing().change(IStreamConservationFloor.core.selector, uint160(address(0xBAD)));
        vm.warp(ready);
        (bool ok, bytes memory reason) = _execute(id, calls, data);
        require(
            !ok
                && _contains(
                    reason, CoreConservationFloorTestApi.InvalidConservationFloor.selector
                ),
            "late candidate admission rejected"
        );
        require(
            prefix.value() == 0
                && b.executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "real prefix and execution receipt rolled back"
        );
        _assertUnbound();
        candidate.backing().change(IStreamConservationFloor.core.selector, uint160(address(target)));
        b.executor.executeGovernanceBatch(id, calls, data);
        (address bound,) = anchor.conservationFloor();
        require(
            bound == address(candidate) && prefix.value() == 99,
            "same original payload/action succeeds after healthy retry"
        );
    }

    function testFloorAnchorSuccessfulBindingRollsBackWhenLaterBatchCallFails() public {
        _setup(false);
        address candidate = address(_candidate());
        (GovernanceCall[] memory firstCalls, bytes[] memory firstData) = _batch(candidate, false);
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        calls[0] = firstCalls[0];
        data[0] = firstData[0];
        data[1] = abi.encodeCall(lateFailure.perform, ());
        calls[1] = _call(
            address(lateFailure),
            data[1],
            keccak256("late scope"),
            keccak256("late before"),
            keccak256("late after")
        );
        (bytes32 id, uint64 ready) = _schedule(1, calls, data);
        vm.warp(ready);
        (bool ok,) = _execute(id, calls, data);
        require(
            !ok && lateFailure.calls() == 0
                && b.executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "later failure rolls back actual execution receipt"
        );
        _assertUnbound();
        lateFailure.setReject(false);
        b.executor.executeGovernanceBatch(id, calls, data);
        (address bound,) = anchor.conservationFloor();
        require(
            bound == candidate && lateFailure.calls() == 1,
            "same action and bytes retry after Core write was rolled back"
        );
    }

    function testFloorAnchorConditionAndFloorStorageRemainIndependent() public {
        _setup(false);
        address conditions =
            address(new CoreMuseumSourcesBoundary(address(target), address(b.executor)));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.conditionSourcesTransition(conditions);
        bytes memory input = abi.encodeCall(target.bindConditionSources, (conditions));
        _governOne(1, _call(address(target), input, scope, oldHash, newHash), input);
        _assertUnbound();
        address candidate = address(_candidate());
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(candidate, false);
        (bytes32 id, uint64 ready) = _schedule(1, calls, data);
        vm.warp(ready);
        b.executor.executeGovernanceBatch(id, calls, data);
        (address storedConditions,) = target.conditionSources();
        (address storedFloor,) = anchor.conservationFloor();
        require(
            storedConditions == conditions && storedFloor == candidate && conditions != candidate,
            "separate immutable source catalog and sale-floor anchors"
        );
    }

    function _mintSetup()
        private
        returns (PermanentTargetMintManager manager, CoreFloorMintCallbackBoundary entropy)
    {
        bytes32
            scope = keccak256(
            abi.encode(
                bytes32(0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16),
                block.chainid,
                address(target),
                uint256(1)
            )
        );
        bytes32 domain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        bytes memory input =
            abi.encodeCall(target.createCollection, (uint8(2), false, uint256(0), uint8(0)));
        _governOne(
            1,
            _call(
                address(target),
                input,
                scope,
                keccak256(abi.encode(domain, scope, false, uint8(0), uint8(0), false, uint256(0))),
                keccak256(abi.encode(domain, scope, true, uint8(2), uint8(0), false, uint256(0)))
            ),
            input
        );
        manager = new PermanentTargetMintManager();
        entropy = new CoreFloorMintCallbackBoundary(address(b.executor));
        _pointer(keccak256("MINT_MANAGER"), address(manager), type(IStreamMintManager).interfaceId);
        _pointer(
            keccak256("ENTROPY_COORDINATOR"),
            address(entropy),
            type(IStreamEntropyCoordinator).interfaceId
        );
    }

    function _pointer(bytes32 kind, address candidate, bytes4 interfaceId) private {
        modules.setRecord(candidate, kind, interfaceId, MANIFEST, DEPLOYMENT);
        StreamCorePointerState memory previous = target.pointerState(kind);
        StreamCorePointerState memory next = StreamCorePointerState(
            candidate,
            candidate.codehash,
            false,
            kind,
            interfaceId,
            address(modules),
            uint8(ModuleRegistryStatus.ACTIVE),
            MANIFEST,
            DEPLOYMENT,
            previous.revision + 1
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.pointerTransitionHashes(kind, previous, next);
        bytes memory input = abi.encodeCall(target.updateSatellitePointer, (kind, candidate));
        _governOne(3, _call(address(target), input, scope, oldHash, newHash), input);
    }

    function testFloorAnchorPreparedMintExclusionAndPostCompletionRetry() public {
        _setup(false);
        (PermanentTargetMintManager manager,) = _mintSetup();
        address candidate = address(_candidate());
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(candidate, false);
        (bytes32 id, uint64 ready) = _schedule(1, calls, data);
        bytes32 operation = keccak256("prepared floor test");
        (uint256 token,) = manager.prepare(target, 1, "", operation);
        vm.warp(ready);
        (bool ok, bytes memory reason) = _execute(id, calls, data);
        require(
            !ok && _contains(reason, StreamCore.PreparedMintAlreadyPending.selector),
            "prepared mint blocks anchor mutation"
        );
        _assertUnbound();
        manager.complete(
            target, token, address(0xBEEF), operation, keccak256("completed floor test")
        );
        b.executor.executeGovernanceBatch(id, calls, data);
        (address bound,) = anchor.conservationFloor();
        require(bound == candidate, "original scheduled action retries after mint");
    }

    function testFloorAnchorCompletionCallbackUsesActualGovernanceAndCannotBind() public {
        _setup(false);
        (PermanentTargetMintManager manager, CoreFloorMintCallbackBoundary entropy) = _mintSetup();
        address candidate = address(_candidate());
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(candidate, false);
        (bytes32 id, uint64 ready) = _schedule(1, calls, data);
        entropy.configure(abi.encodeCall(b.executor.executeGovernanceBatch, (id, calls, data)));
        vm.warp(ready);
        manager.mint(target, 1, address(0xBEEF), "", keccak256("completion callback floor"));
        require(
            entropy.attempted() && !entropy.succeeded() && entropy.observedMintGuard(),
            "actual completion guard reached through Executor"
        );
        require(
            target.collectionMintedEver(1) == 1
                && b.executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "mint succeeds and failed nested governance receipt rolls back"
        );
        _assertUnbound();
        b.executor.executeGovernanceBatch(id, calls, data);
        (address bound,) = anchor.conservationFloor();
        require(bound == candidate, "same action succeeds outside completion callback");
    }

    function executeFloorSafe(address receiver, bytes calldata data) external {
        require(msg.sender == address(this), "test wrapper");
        require(executeSafe(governor, governorKeys, receiver, 0, data, 0), "threshold Safe call");
    }

    function testFloorAnchorActualSafeSchedulesExecutesReadsAndDirectWriteRollsBack() public {
        _setup(true);
        address candidate = address(_candidate());
        uint256 nonce = governor.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeFloorSafe(
            address(target), abi.encodeCall(anchor.bindConservationFloor, (candidate))
        );
        require(governor.nonce() == nonce, "direct Safe is not the Executor and nonce rolls back");
        _assertUnbound();
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(candidate, false);
        (bytes32 id, uint64 ready) = _schedule(1, calls, data);
        require(
            b.executor.governanceAction(id).proposer == address(governor),
            "original actual Safe proposer"
        );
        vm.warp(ready);
        this.executeFloorSafe(
            address(b.executor),
            abi.encodeCall(b.executor.executeGovernanceBatch, (id, calls, data))
        );
        this.executeFloorSafe(address(target), abi.encodeCall(anchor.conservationFloor, ()));
        (address bound,) = anchor.conservationFloor();
        require(
            bound == candidate && governor.nonce() == nonce + 3,
            "schedule execute read each use threshold CALL"
        );
    }

    function testFloorAnchorFuzzOnlyExactCommitmentCanExecute(bytes32 suppliedHash) public {
        _setup(false);
        address candidate = address(_candidate());
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(candidate, false);
        bytes32 expected = calls[0].newValueHash;
        calls[0].newValueHash = suppliedHash;
        (bytes32 id, uint64 ready) = _schedule(1, calls, data);
        vm.warp(ready);
        (bool ok, bytes memory reason) = _execute(id, calls, data);
        if (suppliedHash == expected) {
            require(ok, "exact committed transition");
        } else {
            require(
                !ok && _contains(reason, StreamCore.GovernanceTransitionMismatch.selector),
                "inexact commitment rejected"
            );
            _assertUnbound();
        }
    }
}
