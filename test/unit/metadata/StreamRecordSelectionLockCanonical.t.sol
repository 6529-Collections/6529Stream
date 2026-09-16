// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/StreamGovernanceBootstrapHarness.sol";
import "../../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import {
    StreamRecordSelectionLocks as Locks
} from "../../../smart-contracts/domains/metadata/StreamRecordSelectionLocks.sol";
import {
    IStreamRecordSelectionLock as L
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRecordSelectionLock.sol";

/// @dev Explicit Core pointer boundary; the pointed-to ModuleRegistry is actual production code.
contract SelectionSealCoreBoundary {
    address private immutable registry;

    constructor(address registry_) {
        registry = registry_;
    }

    function getSatellitePointer(bytes32 kind) external view returns (Locks.Pointer memory p) {
        require(kind == keccak256("MODULE_REGISTRY"), "module pointer only");
        p = Locks.Pointer(
            registry,
            registry.codehash,
            false,
            kind,
            type(IStreamModuleRegistry).interfaceId,
            registry,
            1,
            keccak256("actual registry manifest"),
            keccak256("fixture deployment manifest"),
            1
        );
    }
}

contract SelectionSealMetadataBoundary {
    address public immutable governanceAuthority;
    bytes32 public immutable executorCodeHash;

    constructor(address executor) {
        governanceAuthority = executor;
        executorCodeHash = executor.codehash;
    }
}

/// @dev Hosts the exact linked guard. Original Metadata/selection admission is tested separately.
contract SelectionSealGuardHost {
    address private immutable core;
    address private immutable metadata;
    bytes32 private immutable coreHash;
    bytes32 private immutable metadataHash;
    uint256 private immutable chain;
    mapping(bytes32 => L.SelectionLock) private seals;

    constructor(address core_, address metadata_) {
        core = core_;
        metadata = metadata_;
        coreHash = core_.codehash;
        metadataHash = metadata_.codehash;
        chain = block.chainid;
    }

    function _environment() private view returns (Locks.Environment memory) {
        return
            Locks.Environment(
                core, metadata, coreHash, metadataHash, chain, 150000, keccak256("WORK")
            );
    }

    function _head() private pure returns (Locks.Head memory) {
        return Locks.Head(
            1,
            keccak256("subject"),
            keccak256("original record"),
            1,
            keccak256("original selection")
        );
    }

    function transition() external view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        L.SelectionLock memory item = Locks.context(_environment(), _head());
        return (item.scopeHash, item.oldValueHash, item.newValueHash);
    }

    function lock() external {
        Locks.lock(seals, _environment(), _head());
    }

    function selectionLock() external view returns (L.SelectionLock memory) {
        return seals[keccak256(abi.encode(uint256(1), keccak256("subject")))];
    }
}

contract SelectionSealTailBoundary {
    bool public fail;
    uint256 public writes;
    error DeliberateLateFailure();

    function setFailure(bool value) external {
        fail = value;
    }

    function write() external {
        if (fail) revert DeliberateLateFailure();
        ++writes;
    }
}

/// @dev Actual sealed Executor, RoleRegistry and ModuleRegistry; bootstrap inventory/Core,
/// Metadata identity and the selected head remain explicit boundaries. Separate selector tests
/// cover actual Metadata/Schema/Store and Safe calls. No combined deployment or capacity claim.
contract StreamRecordSelectionLockCanonicalTest is StreamGovernanceBootstrapHarness {
    BootstrapArtifacts private b;
    SelectionSealGuardHost private host;
    StreamGovernanceBootstrapTriggerMock private first;
    SelectionSealTailBoundary private last;
    StreamModuleRegistry private modules;

    function _additionalActionPolicies(BootstrapArtifacts memory a)
        internal
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        modules = new StreamModuleRegistry(
            a.executor, keccak256("actual registry manifest"), "ipfs://selection-seal-modules"
        );
        SelectionSealCoreBoundary core = new SelectionSealCoreBoundary(address(modules));
        SelectionSealMetadataBoundary metadata =
            new SelectionSealMetadataBoundary(address(a.executor));
        host = new SelectionSealGuardHost(address(core), address(metadata));
        first = new StreamGovernanceBootstrapTriggerMock();
        last = new SelectionSealTailBoundary();
        rows = new GovernanceActionPolicyEntry[](3);
        rows[0] =
            _zeroPolicy(2, address(host), host.lock.selector, keccak256("selection terminal seal"));
        rows[1] = _zeroPolicy(
            2, address(first), first.bootstrapWrite.selector, keccak256("selection prefix")
        );
        rows[2] = _zeroPolicy(2, address(last), last.write.selector, keccak256("selection tail"));
    }

    function setUp() public {
        vm.warp(1000);
        b = _deploySealedExecutor(address(this));
        require(
            address(b.executor.roleRegistry()) == address(b.roleRegistry), "actual role binding"
        );
        require(b.roleRegistry.owner() == address(b.executor), "actual role owner");
        require(
            address(modules.governanceExecutor()) == address(b.executor), "actual module executor"
        );
        require(b.executor.minimumDelay(2) == 72 hours, "actual terminal floor");
    }

    function nowTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function _call(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private pure returns (GovernanceCall memory) {
        return GovernanceCall(target, 0, bytes4(data), keccak256(data), scope, oldHash, newHash);
    }

    function _hashes(GovernanceCall[] memory calls)
        private
        pure
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        bytes32 callHash = keccak256(abi.encode(GOVERNANCE_CALLS_V2, calls));
        bytes32[] memory scopes = new bytes32[](calls.length);
        bytes32[] memory oldValues = new bytes32[](calls.length);
        bytes32[] memory newValues = new bytes32[](calls.length);
        for (uint256 i; i < calls.length; ++i) {
            scopes[i] = calls[i].scopeHash;
            oldValues[i] = calls[i].oldValueHash;
            newValues[i] = calls[i].newValueHash;
        }
        return (
            keccak256(abi.encode(BATCH_SCOPE_V2, callHash, scopes)),
            keccak256(abi.encode(BATCH_OLD_STATE_V2, callHash, oldValues)),
            keccak256(abi.encode(BATCH_NEW_STATE_V2, callHash, newValues))
        );
    }

    function _schedule(
        uint8 actionClass,
        address proposer,
        GovernanceCall[] memory calls,
        bytes[] memory data,
        string memory uri
    ) private returns (bytes32 id, uint64 at) {
        b.executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = _hashes(calls);
        at = uint64(this.nowTimestamp() + b.executor.minimumDelay(actionClass));
        bytes32 manifest = b.manifestHash;
        StreamGovernanceExecutor executor = b.executor;
        vm.prank(proposer);
        id = executor.scheduleGovernanceBatch(
            actionClass,
            calls,
            scope,
            oldHash,
            newHash,
            at,
            at + 7 days,
            keccak256(bytes(uri)),
            uri,
            manifest
        );
    }

    function _batch(bool includeTail)
        private
        view
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        calls = new GovernanceCall[](includeTail ? 3 : 2);
        data = new bytes[](calls.length);
        data[0] = abi.encodeCall(first.bootstrapWrite, (99));
        calls[0] = _call(
            address(first),
            data[0],
            keccak256("prefix scope"),
            keccak256("prefix old"),
            keccak256("prefix new")
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = host.transition();
        data[1] = abi.encodeCall(host.lock, ());
        calls[1] = _call(address(host), data[1], scope, oldHash, newHash);
        if (includeTail) {
            data[2] = abi.encodeCall(last.write, ());
            calls[2] = _call(
                address(last),
                data[2],
                keccak256("tail scope"),
                keccak256("tail old"),
                keccak256("tail new")
            );
        }
    }

    function _executeLow(bytes32 id, GovernanceCall[] memory calls, bytes[] memory data)
        private
        returns (bool ok, bytes memory reason)
    {
        return address(b.executor)
            .call(abi.encodeCall(b.executor.executeGovernanceBatch, (id, calls, data)));
    }

    function _has(bytes memory reason, bytes memory needle) private pure returns (bool) {
        for (uint256 i; i + needle.length <= reason.length; ++i) {
            bool matches = true;
            for (uint256 j; j < needle.length; ++j) {
                if (reason[i + j] != needle[j]) {
                    matches = false;
                    break;
                }
            }
            if (matches) return true;
        }
        return false;
    }

    function _registration(address proposer) private {
        bytes32 kind = keccak256("6529STREAM_GOVERNANCE_CONFIG_PROPOSER");
        (bool enabled, uint64 rev, bytes32 oldHash) = b.executor.proposerConfig(proposer);
        require(!enabled && rev == 0, "new proposer");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"),
                block.chainid,
                address(b.executor),
                kind,
                proposer
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"),
                block.chainid,
                address(b.executor),
                kind,
                proposer,
                true,
                uint64(1)
            )
        );
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(b.executor.registerProposer, (proposer, true));
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = _call(address(b.executor), data[0], scope, oldHash, newHash);
        (bytes32 id, uint64 at) =
            _schedule(1, address(this), calls, data, "ipfs://selection-proposer");
        vm.warp(at);
        b.executor.executeGovernanceBatch(id, calls, data);
        require(b.executor.isProposer(proposer), "actual delayed proposer admission");
    }

    function testActualTerminalSealSecondCallWaitsAndRetainsLongReasonAction() public {
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(false);
        bytes memory uri = new bytes(2000);
        for (uint256 i; i < uri.length; ++i) {
            uri[i] = 0x61;
        }
        bytes memory prefix = bytes("ipfs://");
        for (uint256 i; i < prefix.length; ++i) {
            uri[i] = prefix[i];
        }
        (bytes32 id, uint64 at) = _schedule(2, address(this), calls, data, string(uri));
        GovernanceAction memory action = b.executor.governanceAction(id);
        require(
            action.target == address(first) && action.selector == first.bootstrapWrite.selector,
            "first header distinct from seal"
        );
        vm.warp(at - 1);
        (bool early,) = _executeLow(id, calls, data);
        require(
            !early && !host.selectionLock().locked && first.value() == 0, "actual delay enforced"
        );
        vm.warp(at);
        b.executor.executeGovernanceBatch(id, calls, data);
        L.SelectionLock memory item = host.selectionLock();
        require(
            item.locked && item.actionId == id && item.lockedAt == at && first.value() == 99,
            "exact second-call seal"
        );
        require(
            item.executor == address(b.executor) && item.moduleRegistry == address(modules)
                && item.governanceRoot == address(this) && item.governanceRootRevision == 1,
            "actual governance evidence"
        );
        action = b.executor.governanceAction(id);
        require(
            action.status == GovernanceActionStatus.EXECUTED && action.actionClass == 2
                && keccak256(bytes(action.reasonURI)) == keccak256(uri),
            "full original action retained"
        );
    }

    function testActualTerminalGuardianVetoPermanentlyBlocksThatSealAction() public {
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(false);
        (bytes32 id, uint64 at) = _schedule(2, address(this), calls, data, "ipfs://selection-veto");
        address guardian = b.initialGuardians[0];
        vm.prank(guardian);
        b.executor.vetoTerminalFreeze(id, keccak256("review veto"));
        vm.warp(at);
        (bool ok,) = _executeLow(id, calls, data);
        require(
            !ok && !host.selectionLock().locked && first.value() == 0,
            "veto prevents every batch write"
        );
        GovernanceAction memory action = b.executor.governanceAction(id);
        require(
            action.status == GovernanceActionStatus.VETOED && action.vetoer == guardian,
            "actual permanent veto"
        );
        (bytes32 next, uint64 nextAt) =
            _schedule(2, address(this), calls, data, "ipfs://selection-veto-successor");
        require(next != id, "different authorized action");
        vm.warp(nextAt);
        b.executor.executeGovernanceBatch(next, calls, data);
        require(host.selectionLock().actionId == next, "fresh action may seal");
        require(
            b.executor.governanceAction(id).status == GovernanceActionStatus.VETOED,
            "old veto unchanged"
        );
    }

    function testActualLateBatchFailureRollsBackSealAndSameActionRetries() public {
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(true);
        last.setFailure(true);
        (bytes32 id, uint64 at) =
            _schedule(2, address(this), calls, data, "ipfs://selection-late-failure");
        vm.warp(at);
        (bool ok, bytes memory reason) = _executeLow(id, calls, data);
        require(
            !ok
                && _has(
                    reason,
                    abi.encodeWithSelector(SelectionSealTailBoundary.DeliberateLateFailure.selector)
                ),
            "exact failure after seal"
        );
        require(
            !host.selectionLock().locked && host.selectionLock().lockHash == 0 && first.value() == 0
                && last.writes() == 0,
            "seal and earlier batch writes roll back"
        );
        require(
            b.executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "action remains retryable"
        );
        last.setFailure(false);
        b.executor.executeGovernanceBatch(id, calls, data);
        require(
            host.selectionLock().actionId == id && first.value() == 99 && last.writes() == 1,
            "identical action and bytes succeed"
        );
    }

    function testActualRegisteredNonrootCannotSealAndRootSamePayloadSucceeds() public {
        address proposer = address(0xCAFE);
        _registration(proposer);
        (GovernanceCall[] memory calls, bytes[] memory data) = _batch(false);
        (bytes32 id, uint64 at) = _schedule(2, proposer, calls, data, "ipfs://selection-nonroot");
        require(b.executor.governanceAction(id).proposer == proposer, "actual registered proposer");
        vm.warp(at);
        (bool ok, bytes memory reason) = _executeLow(id, calls, data);
        require(
            !ok
                && _has(
                    reason, abi.encodeWithSelector(L.RecordSelectionLockAuthorityRequired.selector)
                ),
            "stored root proposer required"
        );
        require(!host.selectionLock().locked && first.value() == 0, "no unauthorized writes");
        (bytes32 rootId, uint64 rootAt) =
            _schedule(2, address(this), calls, data, "ipfs://selection-root");
        vm.warp(rootAt);
        b.executor.executeGovernanceBatch(rootId, calls, data);
        require(host.selectionLock().actionId == rootId, "same payload root action succeeds");
    }

    function testActualDirectRootCannotSubstituteForExecutor() public {
        (bool ok, bytes memory reason) = address(host).call(abi.encodeCall(host.lock, ()));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(L.RecordSelectionLockAuthorityRequired.selector)
                    ),
            "exact direct root rejection"
        );
        require(!host.selectionLock().locked, "unsealed");
    }
}
