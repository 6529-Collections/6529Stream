// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/StreamGovernanceBootstrapHarness.sol";
import "../smart-contracts/interfaces/stream/IStreamGovernanceCatalog.sol";

contract CatalogControlledTarget {
    IStreamGovernanceExecutor public immutable executor;
    uint256 public value;

    constructor(IStreamGovernanceExecutor executor_) {
        executor = executor_;
    }

    function configure(uint256 next) external {
        require(msg.sender == address(executor), "executor only");
        (bool executing,, uint8 actionClass, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            executor.currentAction();
        require(executing && actionClass == 1, "ordinary configuration class");
        require(
            scope == keccak256("catalog-target") && oldHash == keccak256(abi.encode(value))
                && newHash == keccak256(abi.encode(next)),
            "exact transition"
        );
        value = next;
    }
}

contract StreamGovernanceCatalogTest is StreamGovernanceBootstrapHarness {
    BootstrapArtifacts private a;
    CatalogControlledTarget private original;
    CatalogControlledTarget private replacement;

    struct Proposal {
        GovernanceCall[] calls;
        bytes[] data;
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        uint64 notBefore;
    }

    function _additionalActionPolicies(BootstrapArtifacts memory artifacts)
        internal
        override
        returns (GovernanceActionPolicyEntry[] memory entries)
    {
        original = new CatalogControlledTarget(artifacts.executor);
        entries = new GovernanceActionPolicyEntry[](2);
        entries[0] = _zeroPolicy(
            3,
            address(artifacts.executor),
            IStreamGovernanceCatalog.extendGovernanceActionPolicy.selector,
            keccak256("EXECUTOR")
        );
        entries[1] =
            _zeroPolicy(1, address(original), original.configure.selector, keccak256("ORIGINAL"));
    }

    function setUp() public {
        a = _deployBoundBootstrap(address(this));
        _sealBootstrap(a, address(this));
        replacement = new CatalogControlledTarget(a.executor);
    }

    function _additions() private view returns (GovernanceActionPolicyEntry[] memory entries) {
        entries = new GovernanceActionPolicyEntry[](1);
        entries[0] = _zeroPolicy(
            1, address(replacement), replacement.configure.selector, keccak256("REPLACEMENT")
        );
    }

    function _call(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private pure returns (GovernanceCall memory) {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 0x20)) }
        return GovernanceCall(target, 0, selector, keccak256(data), scope, oldHash, newHash);
    }

    function _extension(GovernanceActionPolicyEntry[] memory entries)
        private
        view
        returns (Proposal memory p)
    {
        (bytes32 candidate, bytes32 oldCatalog, uint256 count, uint64 revision) =
            a.executor.governanceActionPolicyState();
        (bytes32 nextCatalog, bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceActionPolicy.extensionTransition(
            address(a.executor), candidate, oldCatalog, count, revision, entries
        );
        (p.calls, p.data) = _bootstrapSealCalls(a);
        p.data[0] = abi.encodeCall(
            a.executor.extendGovernanceActionPolicy, (revision, oldCatalog, nextCatalog, entries)
        );
        p.calls[0] = _call(address(a.executor), p.data[0], scope, oldHash, newHash);
    }

    function _configuration(CatalogControlledTarget target, uint256 next)
        private
        view
        returns (Proposal memory p)
    {
        p.calls = new GovernanceCall[](1);
        p.data = new bytes[](1);
        p.data[0] = abi.encodeCall(target.configure, (next));
        p.calls[0] = _call(
            address(target),
            p.data[0],
            keccak256("catalog-target"),
            keccak256(abi.encode(target.value())),
            keccak256(abi.encode(next))
        );
    }

    function _publish(Proposal memory p) private returns (Proposal memory) {
        a.executor.publishGovernanceCallData(p.data);
        bytes32 callsHash = StreamGovernanceBootstrap.governanceCallsHash(p.calls);
        (p.scope, p.oldHash, p.newHash) =
            StreamGovernanceBootstrap.deriveBatchTransitionHashes(p.calls, callsHash);
        p.notBefore = uint64(block.timestamp + 48 hours);
        return p;
    }

    function _schedule(Proposal memory p, uint8 actionClass) private returns (bytes32) {
        return a.executor
            .scheduleGovernanceBatch(
                actionClass,
                p.calls,
                p.scope,
                p.oldHash,
                p.newHash,
                p.notBefore,
                p.notBefore + 7 days,
                keccak256("catalog-extension"),
                "ipfs://catalog-extension",
                a.manifestHash
            );
    }

    function _execute(Proposal memory p, uint8 actionClass) private returns (bytes32 id) {
        p = _publish(p);
        id = _schedule(p, actionClass);
        vm.warp(p.notBefore);
        a.executor.executeGovernanceBatch(id, p.calls, p.data);
    }

    function testNewTargetRequiresExtensionThenUsesNormalDelayedAuthority() public {
        Proposal memory config = _publish(_configuration(replacement, 42));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionPolicyUnknown.selector,
                0,
                1,
                address(replacement),
                replacement.configure.selector
            )
        );
        _schedule(config, 1);
        (, bytes32 initialRoot, uint256 initialCount, uint64 revision) =
            a.executor.governanceActionPolicyState();
        require(revision == 0, "genesis revision");
        vm.recordLogs();
        _execute(_extension(_additions()), 3);
        (, bytes32 nextRoot, uint256 nextCount, uint64 nextRevision) =
            a.executor.governanceActionPolicyState();
        require(
            nextRoot != initialRoot && nextRevision == 1 && nextCount == initialCount + 1,
            "append-only revision"
        );
        (,, bytes32 manifestRoot, uint256 manifestCount) = _actionPolicyBootstrapState(a.executor);
        require(manifestRoot == nextRoot && manifestCount == nextCount, "mirrored live policy");
        require(a.manifest.streamSystemManifestPointerCount() == 2, "atomic publication");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool sawExtension;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(a.executor)
                    && logs[i].topics[0]
                        == keccak256(
                            "GovernanceActionPolicyExtended(uint64,bytes32,bytes32,uint256,uint256)"
                        )
            ) {
                sawExtension = true;
                require(
                    logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == initialRoot
                        && logs[i].topics[3] == nextRoot,
                    "revision event roots"
                );
            }
        }
        require(sawExtension, "extension event");
        _execute(_configuration(replacement, 42), 1);
        require(replacement.value() == 42, "new target configured by actual executor");
        _execute(_configuration(original, 7), 1);
        require(original.value() == 7, "old entry remains usable");
    }

    function testCatalogExtensionStillRequiresFull48HourDelay() public {
        Proposal memory p = _publish(_extension(_additions()));
        p.notBefore = uint64(block.timestamp + 48 hours - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.DelayBelowClassMinimum.selector,
                uint8(3),
                p.notBefore,
                uint64(block.timestamp + 48 hours)
            )
        );
        _schedule(p, 3);
        p.notBefore += 1;
        bytes32 id = _schedule(p, 3);
        vm.expectRevert();
        a.executor.executeGovernanceBatch(id, p.calls, p.data);
        vm.warp(p.notBefore);
        a.executor.executeGovernanceBatch(id, p.calls, p.data);
    }

    function testDirectAndNonRootExtensionRejected() public {
        GovernanceActionPolicyEntry[] memory entries = _additions();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceSelfCallContextRequired.selector
            )
        );
        a.executor.extendGovernanceActionPolicy(0, bytes32(0), bytes32(0), entries);
        Proposal memory p = _publish(_extension(entries));
        vm.expectRevert();
        vm.prank(address(0xbad));
        _schedule(p, 3);
    }

    function testRegisteredProposerCannotExtendCatalog() public {
        address proposer = address(0xbeef);
        bytes32 kind = keccak256("6529STREAM_GOVERNANCE_CONFIG_PROPOSER");
        (,, bytes32 oldHash) = a.executor.proposerConfig(proposer);
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"),
                block.chainid,
                address(a.executor),
                kind,
                proposer
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"),
                block.chainid,
                address(a.executor),
                kind,
                proposer,
                true,
                uint64(1)
            )
        );
        Proposal memory registration;
        registration.calls = new GovernanceCall[](1);
        registration.data = new bytes[](1);
        registration.data[0] = abi.encodeCall(a.executor.registerProposer, (proposer, true));
        registration.calls[0] =
            _call(address(a.executor), registration.data[0], scope, oldHash, newHash);
        _execute(registration, 1);
        require(a.executor.isProposer(proposer), "ordinary proposer enabled");
        Proposal memory p = _publish(_extension(_additions()));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceRootProposerRequired.selector,
                proposer,
                address(this),
                address(a.executor),
                a.executor.extendGovernanceActionPolicy.selector
            )
        );
        vm.prank(proposer);
        _schedule(p, 3);
    }

    function testExtensionBoundsAndSortingAreEnforced() public {
        GovernanceActionPolicyEntry[] memory entries = new GovernanceActionPolicyEntry[](65);
        (, bytes32 root, uint256 count,) = a.executor.governanceActionPolicyState();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceCatalog.GovernanceCatalogExtensionSize.selector,
                uint256(65),
                count + 65
            )
        );
        StreamGovernanceActionPolicy.extensionTransition(
            address(a.executor), bytes32(0), root, count, 0, entries
        );
        entries = new GovernanceActionPolicyEntry[](2);
        entries[0] = _additions()[0];
        entries[1] = _zeroPolicy(
            1,
            address(new CatalogControlledTarget(a.executor)),
            replacement.configure.selector,
            keccak256("SECOND")
        );
        _sortActionPolicies(entries);
        (entries[0], entries[1]) = (entries[1], entries[0]);
        Proposal memory p = _publish(_extension(entries));
        bytes32 id = _schedule(p, 3);
        vm.warp(p.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionPolicyEntriesNotSorted.selector,
                uint256(1)
            )
        );
        a.executor.executeGovernanceBatch(id, p.calls, p.data);
    }

    function testSuccessiveExtensionsRetainOriginalAndAddedAuthority() public {
        _execute(_extension(_additions()), 3);
        CatalogControlledTarget second = new CatalogControlledTarget(a.executor);
        GovernanceActionPolicyEntry[] memory entries = new GovernanceActionPolicyEntry[](1);
        entries[0] = _zeroPolicy(1, address(second), second.configure.selector, keccak256("SECOND"));
        _execute(_extension(entries), 3);
        (,,, uint64 revision) = a.executor.governanceActionPolicyState();
        require(revision == 2, "second extension retained control authority");
        _execute(_configuration(replacement, 5), 1);
        _execute(_configuration(second, 8), 1);
        require(replacement.value() == 5 && second.value() == 8, "both additions usable");
    }

    function testMaximumExtensionAndManifestURIFitPublicationEnvelope() public {
        GovernanceActionPolicyEntry[] memory entries = new GovernanceActionPolicyEntry[](64);
        for (uint256 i; i < entries.length; ++i) {
            entries[i] = _zeroPolicy(
                1, address(replacement), bytes4(uint32(0x80000000 + i)), keccak256("EXACT_ROW")
            );
        }
        _sortActionPolicies(entries);
        Proposal memory p = _extension(entries);
        bytes memory uri = new bytes(2_048);
        for (uint256 i; i < uri.length; ++i) {
            uri[i] = 0x61;
        }
        StreamGovernanceBootstrapManifestMock.StreamSystemManifestUpdate memory update =
            StreamGovernanceBootstrapManifestMock.StreamSystemManifestUpdate({
                manifestHash: a.manifestHash,
                manifestURI: string(uri),
                eventCatalogHash: keccak256("events"),
                compatibilityMatrixHash: keccak256("compatibility"),
                numericIdCatalogHash: keccak256("ids"),
                schemaCatalogHash: keccak256("schema"),
                canonicalizationCatalogHash: keccak256("canonical"),
                specBundleHash: keccak256("spec"),
                reconstructionClientHash: keccak256("client")
            });
        p.data[1] = abi.encodeCall(a.manifest.publishStreamSystemManifest, (a.payloadRoot, update));
        p.calls[1].callDataHash = keccak256(p.data[1]);
        require(abi.encode(p.data).length <= 24_575, "full maximum-size batch fits SSTORE2");
        (,, uint256 beforeCount,) = a.executor.governanceActionPolicyState();
        _execute(p, 3);
        (,, uint256 afterCount, uint64 revision) = a.executor.governanceActionPolicyState();
        require(afterCount == beforeCount + 64 && revision == 1, "maximum extension admitted");
    }

    function testRequiresFinalManifestAndRejectsWrongClass() public {
        Proposal memory p = _extension(_additions());
        GovernanceCall[] memory oneCall = new GovernanceCall[](1);
        bytes[] memory oneData = new bytes[](1);
        oneCall[0] = p.calls[0];
        oneData[0] = p.data[0];
        p.calls = oneCall;
        p.data = oneData;
        p = _publish(p);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceCatalog.GovernanceCatalogExtensionComposition.selector
            )
        );
        _schedule(p, 3);
        p = _publish(_extension(_additions()));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceCatalog.GovernanceCatalogExtensionComposition.selector
            )
        );
        _schedule(p, 1);
    }

    function testPublicationFailureRollsBackCatalogRevisionAndAdmission() public {
        Proposal memory p = _publish(_extension(_additions()));
        bytes32 id = _schedule(p, 3);
        (, bytes32 oldRoot, uint256 oldCount,) = a.executor.governanceActionPolicyState();
        a.manifest.setFailPublication(true);
        vm.warp(p.notBefore);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "publication failed"));
        a.executor.executeGovernanceBatch(id, p.calls, p.data);
        (, bytes32 root, uint256 count, uint64 revision) = a.executor.governanceActionPolicyState();
        require(root == oldRoot && count == oldCount && revision == 0, "catalog atomic rollback");
        require(
            a.executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "action remains pending"
        );
        require(a.manifest.streamSystemManifestPointerCount() == 1, "no partial publication");
        a.manifest.setFailPublication(false);
        a.executor.executeGovernanceBatch(id, p.calls, p.data);
        _execute(_configuration(replacement, 3), 1);
    }

    function testScheduledOldCatalogCannotExecuteAfterExtension() public {
        Proposal memory old = _publish(_configuration(original, 9));
        bytes32 oldId = _schedule(old, 1);
        (, bytes32 oldRoot,,) = a.executor.governanceActionPolicyState();
        _execute(_extension(_additions()), 3);
        (, bytes32 newRoot,,) = a.executor.governanceActionPolicyState();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionPolicySnapshotMismatch.selector,
                oldId,
                oldRoot,
                newRoot
            )
        );
        a.executor.executeGovernanceBatch(oldId, old.calls, old.data);
        require(original.value() == 0, "stale action made no write");
        _execute(_configuration(original, 9), 1);
    }

    function testDuplicateEntryCannotChangeExistingAuthority() public {
        GovernanceActionPolicyEntry[] memory entries = new GovernanceActionPolicyEntry[](1);
        entries[0] = _zeroPolicy(
            1, address(original), original.configure.selector, keccak256("DIFFERENT_PROFILE")
        );
        Proposal memory p = _publish(_extension(entries));
        bytes32 id = _schedule(p, 3);
        vm.warp(p.notBefore);
        bytes32 key =
            keccak256(abi.encode(uint8(1), address(original), original.configure.selector));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceCatalog.GovernanceCatalogDuplicateEntry.selector, key
            )
        );
        a.executor.executeGovernanceBatch(id, p.calls, p.data);
    }

    function testRejectsTargetCodeDriftDuringDelay() public {
        Proposal memory p = _publish(_extension(_additions()));
        bytes32 id = _schedule(p, 3);
        vm.etch(address(replacement), hex"60006000fd");
        vm.warp(p.notBefore);
        vm.expectRevert();
        a.executor.executeGovernanceBatch(id, p.calls, p.data);
        (,,, uint64 revision) = a.executor.governanceActionPolicyState();
        require(revision == 0, "drift did not admit target");
    }

    function testRequiresExactTransitionAndRevisionCommitments() public {
        Proposal memory p = _extension(_additions());
        p.calls[0].newValueHash = keccak256("wrong");
        p = _publish(p);
        bytes32 id = _schedule(p, 3);
        vm.warp(p.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceTransitionContextMismatch.selector
            )
        );
        a.executor.executeGovernanceBatch(id, p.calls, p.data);
        p = _extension(_additions());
        (, bytes32 oldRoot,,) = a.executor.governanceActionPolicyState();
        p.data[0] = abi.encodeCall(
            a.executor.extendGovernanceActionPolicy, (uint64(1), oldRoot, bytes32(0), _additions())
        );
        p.calls[0].callDataHash = keccak256(p.data[0]);
        p = _publish(p);
        id = _schedule(p, 3);
        vm.warp(p.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceCatalog.GovernanceCatalogRevisionMismatch.selector,
                uint64(1),
                uint64(0)
            )
        );
        a.executor.executeGovernanceBatch(id, p.calls, p.data);
    }
}
