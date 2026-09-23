// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/StreamGovernanceBootstrapHarness.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamConditionSources.sol";

/// @dev Typed record-host boundary; record publication/selection is tested by its producer lanes.
contract ConditionSourceHostBoundary {
    address public core;
    bytes4 private immutable _kind;

    constructor(address core_, bytes4 kind_) {
        core = core_;
        _kind = kind_;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return id == _kind || id == 0x01ffc9a7;
    }
}

contract ConditionSourceMalformedBoundary {
    fallback() external {
        assembly {
            mstore(0, 1)
            return(0, 64)
        }
    }
}

/// @notice Real sealed Executor/RoleRegistry and actual Safe, with explicit typed Core/source hosts.
/// @dev These tests prove source membership/authority. They do not claim record publication,
///      receipt-history replay, canonical packet selection or the pending Core catalog binding.
contract StreamConditionSourcesTest is StreamGovernanceBootstrapHarness, OfficialSafeFixture {
    StreamConditionSources private catalog;
    BootstrapArtifacts private b;
    StreamGovernanceBootstrapTriggerMock private prefix;
    OfficialSafe private governor;
    uint256[] private governorKeys;

    event ConditionSourceAdded(
        uint64 indexed sourceId,
        address indexed host,
        IStreamConditionSources.Lane indexed lane,
        bytes32 codeHash,
        uint64 replacesSourceId,
        bytes32 previousHead,
        bytes32 nextHead,
        bytes32 actionId,
        uint16 schemaVersion
    );

    function _additionalActionPolicies(BootstrapArtifacts memory a)
        internal
        override
        returns (GovernanceActionPolicyEntry[] memory entries)
    {
        catalog = new StreamConditionSources(address(a.core), address(a.executor));
        prefix = new StreamGovernanceBootstrapTriggerMock();
        entries = new GovernanceActionPolicyEntry[](2);
        entries[0] = _zeroPolicy(
            1, address(catalog), catalog.appendSource.selector, keccak256("condition sources")
        );
        entries[1] = _zeroPolicy(
            1, address(prefix), prefix.bootstrapWrite.selector, keccak256("condition prefix")
        );
    }

    function _setup(bool withSafe) private {
        vm.warp(1000);
        address root = address(this);
        if (withSafe) {
            uint256[] memory keys = new uint256[](3);
            keys[0] = 661;
            keys[1] = 662;
            keys[2] = 663;
            governor = createOfficialSafe(
                deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 6601
            );
            governorKeys.push(keys[0]);
            governorKeys.push(keys[1]);
            root = address(governor);
        }
        b = _deploySealedExecutor(root);
    }

    function _host(IStreamConditionSources.Lane lane) private returns (address) {
        return address(
            new ConditionSourceHostBoundary(
                address(b.core),
                lane == IStreamConditionSources.Lane.OWNER
                    ? type(IStreamOwnerRecords).interfaceId
                    : type(IStreamCollectionAttestations).interfaceId
            )
        );
    }

    function _batch(
        address host,
        IStreamConditionSources.Lane lane,
        uint64 predecessor,
        bool withPrefix
    ) private view returns (GovernanceCall[] memory calls, bytes[] memory data) {
        uint256 i = withPrefix ? 1 : 0;
        calls = new GovernanceCall[](i + 1);
        data = new bytes[](i + 1);
        if (withPrefix) {
            data[0] = abi.encodeCall(prefix.bootstrapWrite, (uint256(99)));
            calls[0] = GovernanceCall(
                address(prefix),
                0,
                prefix.bootstrapWrite.selector,
                keccak256(data[0]),
                keccak256("prefix"),
                keccak256("old"),
                keccak256("new")
            );
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            catalog.sourceTransition(host, lane, predecessor);
        data[i] = abi.encodeCall(catalog.appendSource, (host, lane, predecessor));
        calls[i] = GovernanceCall(
            address(catalog),
            0,
            catalog.appendSource.selector,
            keccak256(data[i]),
            scope,
            oldHash,
            newHash
        );
    }

    function _schedule(GovernanceCall[] memory calls, bytes[] memory data)
        private
        returns (bytes32 id, uint64 ready)
    {
        b.executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        ready = uint64(block.timestamp + b.executor.minimumDelay(1));
        bytes memory callData = abi.encodeCall(
            b.executor.scheduleGovernanceBatch,
            (
                uint8(1),
                calls,
                scope,
                oldHash,
                newHash,
                ready,
                ready + 7 days,
                keccak256("condition source admission"),
                "urn:stream:test:condition-sources",
                b.manifestHash
            )
        );
        if (address(governor) == address(0)) {
            (bool ok, bytes memory result) = address(b.executor).call(callData);
            require(ok, "real root scheduling");
            id = abi.decode(result, (bytes32));
        } else {
            vm.recordLogs();
            require(
                executeSafe(governor, governorKeys, address(b.executor), 0, callData, 0),
                "threshold Safe scheduling"
            );
            Vm.Log[] memory logs = vm.getRecordedLogs();
            bytes32 topic = keccak256(
                "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
            );
            for (uint256 i; i < logs.length; ++i) {
                if (logs[i].emitter == address(b.executor) && logs[i].topics[0] == topic) {
                    id = logs[i].topics[1];
                }
            }
            require(id != 0, "actual scheduling event");
        }
    }

    function _append(address host, IStreamConditionSources.Lane lane, uint64 predecessor)
        private
        returns (bytes32 id)
    {
        (GovernanceCall[] memory calls, bytes[] memory data) =
            _batch(host, lane, predecessor, false);
        uint64 ready;
        (id, ready) = _schedule(calls, data);
        vm.warp(ready);
        b.executor.executeGovernanceBatch(id, calls, data);
    }

    function testActualGovernanceRecordsExactEventAndState() public {
        _setup(false);
        address host = _host(IStreamConditionSources.Lane.OWNER);
        (GovernanceCall[] memory calls, bytes[] memory data) =
            _batch(host, IStreamConditionSources.Lane.OWNER, 0, false);
        (bytes32 id, uint64 ready) = _schedule(calls, data);
        (bool early,) = address(b.executor)
            .call(abi.encodeCall(b.executor.executeGovernanceBatch, (id, calls, data)));
        require(!early && catalog.sourceCount() == 0, "actual delay retains empty source set");
        bytes32 previous = catalog.sourceSetHashAt(0);
        bytes32 next = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONDITION_SOURCE_SET_V1"),
                previous,
                uint64(1),
                host,
                host.codehash,
                IStreamConditionSources.Lane.OWNER,
                uint64(0)
            )
        );
        vm.warp(ready);
        vm.expectEmit(true, true, true, true);
        emit ConditionSourceAdded(
            1, host, IStreamConditionSources.Lane.OWNER, host.codehash, 0, previous, next, id, 1
        );
        b.executor.executeGovernanceBatch(id, calls, data);
        IStreamConditionSources.Source memory s = catalog.sourceAt(1);
        require(
            s.host == host && s.codeHash == host.codehash && s.admittedAt == ready
                && s.actionId == id,
            "exact durable receipt"
        );
        require(
            catalog.sourceId(host, IStreamConditionSources.Lane.OWNER) == 1
                && catalog.sourceSetHashAt(1) == next,
            "exact index and accumulator"
        );
        require(
            catalog.coreCodeHash() == address(b.core).codehash
                && catalog.executorCodeHash() == address(b.executor).codehash
                && catalog.deploymentChainId() == block.chainid,
            "immutable dependency pins"
        );
    }

    function testReplacementRetainsEveryUnregisteredCompatibleHost() public {
        _setup(false);
        address first = _host(IStreamConditionSources.Lane.OWNER);
        address second = _host(IStreamConditionSources.Lane.OWNER);
        address third = _host(IStreamConditionSources.Lane.INDEPENDENT);
        _append(first, IStreamConditionSources.Lane.OWNER, 0);
        bytes32 oldHead = catalog.sourceSetHashAt(1);
        _append(second, IStreamConditionSources.Lane.OWNER, 1);
        _append(third, IStreamConditionSources.Lane.INDEPENDENT, 0);
        require(
            catalog.sourceCount() == 3 && catalog.sourceAt(1).host == first
                && catalog.sourceAt(2).replacesSourceId == 1 && catalog.sourceAt(3).host == third
                && catalog.sourceSetHashAt(1) == oldHead,
            "append-only complete membership"
        );
        require(
            catalog.sourceId(first, IStreamConditionSources.Lane.OWNER) == 1,
            "predecessor never removed"
        );
    }

    function testMissingLatestSourceOrForeignCatalogCannotClaimCompleteSet() public {
        _setup(false);
        _append(_host(IStreamConditionSources.Lane.OWNER), IStreamConditionSources.Lane.OWNER, 0);
        (uint64 oldCount, bytes32 oldHead) = catalog.sourceSetHead();
        _append(
            _host(IStreamConditionSources.Lane.INDEPENDENT),
            IStreamConditionSources.Lane.INDEPENDENT,
            0
        );
        (uint64 count, bytes32 head) = catalog.sourceSetHead();
        catalog.requireSourceSet(count, head);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConditionSources.ConditionSourceSetChanged.selector, count, head
            )
        );
        catalog.requireSourceSet(oldCount, oldHead);
        StreamConditionSources foreign =
            new StreamConditionSources(address(b.core), address(b.executor));
        bytes32 foreignHead = foreign.sourceSetHashAt(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConditionSources.ConditionSourceSetChanged.selector, count, head
            )
        );
        catalog.requireSourceSet(count, foreignHead);
    }

    function testDirectRootAndOutsiderCannotAppend() public {
        _setup(false);
        address host = _host(IStreamConditionSources.Lane.OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        catalog.appendSource(host, IStreamConditionSources.Lane.OWNER, 0);
        vm.prank(address(0xBEEF));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        catalog.appendSource(host, IStreamConditionSources.Lane.OWNER, 0);
        require(catalog.sourceCount() == 0, "no unauthorized source");
    }

    function testDuplicateAndCrossLaneOrUnknownReplacementReject() public {
        _setup(false);
        address first = _host(IStreamConditionSources.Lane.OWNER);
        _append(first, IStreamConditionSources.Lane.OWNER, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConditionSources.ConditionSourceAlreadyAdmitted.selector,
                first,
                IStreamConditionSources.Lane.OWNER
            )
        );
        catalog.sourceTransition(first, IStreamConditionSources.Lane.OWNER, 0);
        address next = _host(IStreamConditionSources.Lane.INDEPENDENT);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConditionSources.InvalidConditionSourcePredecessor.selector, uint64(1)
            )
        );
        catalog.sourceTransition(next, IStreamConditionSources.Lane.INDEPENDENT, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConditionSources.InvalidConditionSourcePredecessor.selector, uint64(2)
            )
        );
        catalog.sourceTransition(next, IStreamConditionSources.Lane.INDEPENDENT, 2);
    }

    function testWrongCoreKindAndMalformedReadReject() public {
        _setup(false);
        address wrong = address(
            new ConditionSourceHostBoundary(address(0xBAD), type(IStreamOwnerRecords).interfaceId)
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamConditionSources.InvalidConditionSource.selector, wrong)
        );
        catalog.sourceTransition(wrong, IStreamConditionSources.Lane.OWNER, 0);
        address wrongKind = _host(IStreamConditionSources.Lane.INDEPENDENT);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConditionSources.InvalidConditionSource.selector, wrongKind
            )
        );
        catalog.sourceTransition(wrongKind, IStreamConditionSources.Lane.OWNER, 0);
        address malformed = address(new ConditionSourceMalformedBoundary());
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConditionSources.ConditionSourceReadFailed.selector, malformed
            )
        );
        catalog.sourceTransition(malformed, IStreamConditionSources.Lane.OWNER, 0);
    }

    function testStaleDenominatorRollsBackWholeBatchAndFreshRetrySucceeds() public {
        _setup(false);
        address next = _host(IStreamConditionSources.Lane.OWNER);
        (GovernanceCall[] memory calls, bytes[] memory data) =
            _batch(next, IStreamConditionSources.Lane.OWNER, 0, true);
        (bytes32 id,) = _schedule(calls, data);
        _append(
            _host(IStreamConditionSources.Lane.INDEPENDENT),
            IStreamConditionSources.Lane.INDEPENDENT,
            0
        );
        (bool ok,) = address(b.executor)
            .call(abi.encodeCall(b.executor.executeGovernanceBatch, (id, calls, data)));
        require(
            !ok && prefix.value() == 0 && catalog.sourceCount() == 1, "stale root atomic rollback"
        );
        require(
            b.executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "execution receipt rolls back"
        );
        _append(next, IStreamConditionSources.Lane.OWNER, 0);
        require(
            catalog.sourceCount() == 2 && catalog.sourceAt(2).host == next,
            "fresh exact transition succeeds"
        );
    }

    function testHostCodeChangedAfterSchedulingCannotEnterSet() public {
        _setup(false);
        address next = _host(IStreamConditionSources.Lane.OWNER);
        (GovernanceCall[] memory calls, bytes[] memory data) =
            _batch(next, IStreamConditionSources.Lane.OWNER, 0, true);
        (bytes32 id, uint64 ready) = _schedule(calls, data);
        vm.etch(next, hex"60006000fd");
        vm.warp(ready);
        (bool ok,) = address(b.executor)
            .call(abi.encodeCall(b.executor.executeGovernanceBatch, (id, calls, data)));
        require(
            !ok && prefix.value() == 0 && catalog.sourceCount() == 0,
            "code change and preceding writes rollback"
        );
    }

    function testActualSafeGovernanceAndReadAccess() public {
        _setup(true);
        address next = _host(IStreamConditionSources.Lane.OWNER);
        bytes32 id = _append(next, IStreamConditionSources.Lane.OWNER, 0);
        require(
            b.executor.governanceAction(id).proposer == address(governor),
            "actual threshold Safe proposer"
        );
        (uint64 count, bytes32 head) = catalog.sourceSetHead();
        require(
            executeSafe(
                governor,
                governorKeys,
                address(catalog),
                0,
                abi.encodeCall(catalog.requireSourceSet, (count, head)),
                0
            ),
            "actual Safe complete-set read"
        );
        require(
            executeSafe(
                governor,
                governorKeys,
                address(catalog),
                0,
                abi.encodeCall(catalog.sourceAt, (uint64(1))),
                0
            ),
            "actual Safe source read"
        );
    }

    function executeDirectSafeAdmission(address host) external {
        require(msg.sender == address(this), "test wrapper");
        executeSafe(
            governor,
            governorKeys,
            address(catalog),
            0,
            abi.encodeCall(
                catalog.appendSource, (host, IStreamConditionSources.Lane.OWNER, uint64(0))
            ),
            0
        );
    }

    function testActualSafeDirectAdmissionRejectsWithoutNonceConsumption() public {
        _setup(true);
        address next = _host(IStreamConditionSources.Lane.OWNER);
        uint256 nonce = governor.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeDirectSafeAdmission(next);
        require(governor.nonce() == nonce && catalog.sourceCount() == 0, "actual Safe rollback");
    }

    function testChangedChainRejectsMutationAndRetainsHistoricalReads() public {
        _setup(false);
        address first = _host(IStreamConditionSources.Lane.OWNER);
        _append(first, IStreamConditionSources.Lane.OWNER, 0);
        (uint64 count, bytes32 head) = catalog.sourceSetHead();
        uint256 original = catalog.deploymentChainId();
        vm.chainId(original + 1);
        address next = _host(IStreamConditionSources.Lane.OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConditionSources.ConditionSourceChainChanged.selector, original, original + 1
            )
        );
        catalog.sourceTransition(next, IStreamConditionSources.Lane.OWNER, 1);
        require(
            catalog.sourceAt(1).host == first && catalog.sourceSetHashAt(count) == head,
            "historical source facts remain readable"
        );
        catalog.requireSourceSet(count, head);
    }

    function testFuzzOnlyExactDenominatorPasses(uint64 count, bytes32 head) public {
        _setup(false);
        (uint64 actualCount, bytes32 actualHead) = catalog.sourceSetHead();
        if (count == actualCount && head == actualHead) {
            catalog.requireSourceSet(count, head);
            return;
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConditionSources.ConditionSourceSetChanged.selector, actualCount, actualHead
            )
        );
        catalog.requireSourceSet(count, head);
    }
}
