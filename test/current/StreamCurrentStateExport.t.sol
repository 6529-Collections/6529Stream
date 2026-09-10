// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";

interface StateExportVm {
    function setBlockhash(uint256 number, bytes32 hash) external;
}

contract StateExportExecutionProbe {
    StreamGovernanceExecutor private immutable executor;
    bytes4[3] public errors;

    constructor(StreamGovernanceExecutor executor_) {
        executor = executor_;
    }

    function run() external {
        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(
            executor.publishStateExport,
            (1, bytes32(uint256(1)), bytes32(uint256(2)), bytes32(uint256(3)), "uri")
        );
        data[1] = abi.encodeCall(
            executor.challengeStateExport, (bytes32(uint256(2)), bytes32(uint256(3)), "uri")
        );
        data[2] = abi.encodeCall(
            executor.supersedeStateExport,
            (bytes32(uint256(2)), bytes32(uint256(3)), bytes32(uint256(4)), "uri")
        );
        for (uint256 i; i < 3; ++i) {
            (bool success, bytes memory result) = address(executor).call(data[i]);
            require(!success && result.length == 4, "writer escaped execution guard");
            errors[i] = bytes4(result);
        }
    }
}

/// @dev Replacement has the real locked discovery ABI; it owns no governance authority.
contract ReplacementStateExportPublisher is IStreamStateExportPublisher, IERC165 {
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return
            id == type(IStreamStateExportPublisher).interfaceId || id == type(IERC165).interfaceId;
    }

    function latestStateExport()
        external
        pure
        returns (uint256, bytes32, bytes32, bytes32, string memory)
    {
        return (0, bytes32(0), bytes32(0), bytes32(0), "");
    }
}

/// @notice Publisher behavior on the actual Core, ModuleRegistry, RoleRegistry and Executor.
contract StreamCurrentStateExportTest is StreamCurrentStackFixture {
    bytes32 private constant EXPORT_A = keccak256("export A");
    bytes32 private constant EXPORT_B = keccak256("export B");
    bytes32 private constant MANIFEST = keccak256("export manifest");
    bytes32 private constant CHALLENGE = keccak256("challenge");
    bytes32 private constant ROLE = keccak256("ROLE_EXPORT_PUBLISHER");
    bytes32 private constant POINTER = keccak256("STATE_EXPORT_PUBLISHER");
    StateExportExecutionProbe private probe;

    function setUp() public {
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _publisherRole(BUYER, true);
        vm.roll(1_000);
        _anchor(999, keccak256("block 999"));
    }

    function _configureAdditionalProducts() internal override {
        probe = new StateExportExecutionProbe(executor);
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            address(probe),
            probe.run.selector,
            address(probe).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(probe))),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function testCanonicalRegistrationReadInterfaceAndEmptyHistory() public view {
        require(type(IStreamStateExportPublisher).interfaceId == 0x77faad4f, "locked read ID");
        require(
            IStreamStateExportOperations.publishStateExport.selector == 0x10e32cee,
            "publish selector"
        );
        require(
            IStreamStateExportOperations.challengeStateExport.selector == 0x23ebf4a4,
            "challenge selector"
        );
        require(
            IStreamStateExportOperations.supersedeStateExport.selector == 0xc1aff4f1,
            "supersede selector"
        );
        require(
            executor.supportsInterface(0x77faad4f) && executor.supportsInterface(0x01ffc9a7),
            "ERC165 positive"
        );
        require(
            !executor.supportsInterface(0xffffffff) && !executor.supportsInterface(0x00000000),
            "ERC165 negative"
        );
        StreamCorePointerState memory pointer = StreamCurrentStackPlan.readPointer(core, POINTER);
        require(
            pointer.target == address(executor)
                && pointer.moduleType == keccak256("GOVERNANCE_LAYER"),
            "actual Core binding"
        );
        require(
            pointer.interfaceId == 0x77faad4f && pointer.codeHash == address(executor).codehash,
            "registry probe and codehash"
        );
        (uint256 number, bytes32 anchor, bytes32 hash, bytes32 manifestHash, string memory uri) =
            executor.latestStateExport();
        require(
            number == 0 && anchor == 0 && hash == 0 && manifestHash == 0 && bytes(uri).length == 0,
            "empty latest"
        );
        require(executor.stateExportCount() == 0, "empty count");
    }

    function testPublishChallengeSupersedeExactReceiptsAndImmutableHistory() public {
        vm.recordLogs();
        _publish(999, EXPORT_A, "ipfs://export-A");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _event(
            logs,
            0x4b64ff5d268568999197a07e66632a3d1cf86adfb499394383bfa5e02577f045,
            bytes32(uint256(999)),
            EXPORT_A,
            MANIFEST,
            abi.encode(uint16(1), keccak256("block 999"), "ipfs://export-A")
        );
        vm.recordLogs();
        vm.prank(SECOND_OWNER);
        executor.challengeStateExport(EXPORT_A, CHALLENGE, "ipfs://challenge");
        logs = vm.getRecordedLogs();
        _event(
            logs,
            0x7dcf7c00a2fcd9a11d7b2a1a1c7f49b2ddffe3bb28e97a0efd2e53d2e183a68c,
            EXPORT_A,
            CHALLENGE,
            bytes32(uint256(uint160(SECOND_OWNER))),
            abi.encode(uint16(1), "ipfs://challenge")
        );
        _latest(EXPORT_A);
        vm.roll(1_001);
        _anchor(1_000, keccak256("block 1000"));
        _publish(1_000, EXPORT_B, "ipfs://export-B");
        vm.recordLogs();
        vm.prank(BUYER);
        executor.supersedeStateExport(EXPORT_A, EXPORT_B, CHALLENGE, "ipfs://reason");
        logs = vm.getRecordedLogs();
        _event(
            logs,
            0xd38e3f1ed11d4a002ed59a6ac2242bb16b6681891fbdbbbf55077edf92bfdc4a,
            EXPORT_A,
            EXPORT_B,
            CHALLENGE,
            abi.encode(uint16(1), "ipfs://reason")
        );
        _latest(EXPORT_B);
        (StreamStateExportRecord memory record, bytes32 successor) = executor.stateExport(EXPORT_A);
        require(
            record.sequence == 1 && record.blockNumber == 999 && record.exportHash == EXPORT_A,
            "immutable identity"
        );
        require(
            record.blockHash == keccak256("block 999") && record.manifestHash == MANIFEST,
            "immutable commitments"
        );
        require(
            keccak256(bytes(record.manifestURI)) == keccak256("ipfs://export-A")
                && successor == EXPORT_B,
            "history and link"
        );
        require(
            executor.stateExportCount() == 2 && executor.stateExportHashAt(1) == EXPORT_B,
            "append enumeration"
        );
        require(executor.stateExportChallengeExists(EXPORT_A, CHALLENGE), "challenge recorded");
    }

    function testLiveRoleRemovalRegrantAndNoImplicitGovernanceAuthority() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportPublisherUnauthorized.selector,
                address(this)
            )
        );
        executor.publishStateExport(999, keccak256("block 999"), EXPORT_A, MANIFEST, "uri");
        bytes memory data = abi.encodeCall(
            executor.publishStateExport, (999, keccak256("block 999"), EXPORT_A, MANIFEST, "uri")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportPublisherUnauthorized.selector,
                address(governanceRoot)
            )
        );
        governanceRoot.execute(address(executor), 0, data);
        _publisherRole(BUYER, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportPublisherUnauthorized.selector, BUYER
            )
        );
        _publish(999, EXPORT_A, "uri");
        _publisherRole(BUYER, true);
        _publish(999, EXPORT_A, "uri");
        _latest(EXPORT_A);
    }

    function testAllWritersRejectDuringRealGovernanceBatch() public {
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(probe.run, ());
        calls[0] = StreamCurrentStackPlan.call(
            address(probe), data[0], keccak256("probe"), 0, keccak256(data[0])
        );
        _execute(calls, data, 1);
        for (uint256 i; i < 3; ++i) {
            require(
                probe.errors(i)
                    == IStreamStateExportOperations.StateExportDuringGovernanceExecution.selector,
                "execution guard error"
            );
        }
        require(executor.stateExportCount() == 0, "no writes during batch");
    }

    function testAnchorBoundariesAndEqualHeightReorg() public {
        _anchor(744, keccak256("oldest valid"));
        _publish(744, EXPORT_A, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportInvalidAnchor.selector,
                uint256(743),
                bytes32(0)
            )
        );
        _publish(743, EXPORT_B, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportInvalidAnchor.selector,
                uint256(1000),
                bytes32(0)
            )
        );
        _publish(1_000, EXPORT_B, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportInvalidAnchor.selector,
                uint256(1001),
                bytes32(0)
            )
        );
        _publish(1_001, EXPORT_B, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportInvalidAnchor.selector,
                uint256(0),
                bytes32(0)
            )
        );
        _publish(0, EXPORT_B, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportInvalidAnchor.selector,
                uint256(999),
                keccak256("incorrect hash")
            )
        );
        vm.prank(BUYER);
        executor.publishStateExport(999, keccak256("incorrect hash"), EXPORT_B, MANIFEST, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportAnchorNotIncreasing.selector,
                uint256(744),
                uint256(744)
            )
        );
        _publish(744, EXPORT_B, "uri");
        _anchor(744, keccak256("reorg canonical"));
        _publish(744, EXPORT_B, "uri");
        _latest(EXPORT_B);
        (StreamStateExportRecord memory old,) = executor.stateExport(EXPORT_A);
        require(old.blockHash == keccak256("oldest valid"), "old fork retained");
    }

    function testInvalidHashesURIsAndDuplicateIdentitiesRollback() public {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamStateExportOperations.StateExportInvalidHash.selector)
        );
        _publish(999, bytes32(0), "uri");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamStateExportOperations.StateExportInvalidHash.selector)
        );
        vm.prank(BUYER);
        executor.publishStateExport(999, keccak256("block 999"), EXPORT_A, 0, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamStateExportOperations.StateExportInvalidURI.selector)
        );
        _publish(999, EXPORT_A, "");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamStateExportOperations.StateExportInvalidURI.selector)
        );
        _publish(999, EXPORT_A, string(abi.encodePacked(hex"c080")));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamStateExportOperations.StateExportInvalidURI.selector)
        );
        _publish(999, EXPORT_A, string(abi.encodePacked(hex"eda080")));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamStateExportOperations.StateExportInvalidURI.selector)
        );
        _publish(999, EXPORT_A, string(abi.encodePacked(hex"f4908080")));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamStateExportOperations.StateExportInvalidURI.selector)
        );
        _publish(999, EXPORT_A, string(new bytes(2_049)));
        require(executor.stateExportCount() == 0, "invalid publication rollback");
        bytes memory longURI = new bytes(2_048);
        for (uint256 i; i < longURI.length; ++i) {
            longURI[i] = 0x61;
        }
        _publish(999, EXPORT_A, string(longURI));
        vm.roll(1_001);
        _anchor(1_000, keccak256("next"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportAlreadyPublished.selector, EXPORT_A
            )
        );
        _publish(1_000, EXPORT_A, "uri");
        require(executor.stateExportCount() == 1, "duplicate rollback");
    }

    function testChallengeAndSupersessionCannotRewriteOrCycle() public {
        _publish(999, EXPORT_A, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportUnknown.selector, EXPORT_B
            )
        );
        executor.challengeStateExport(EXPORT_B, CHALLENGE, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamStateExportOperations.StateExportInvalidHash.selector)
        );
        executor.challengeStateExport(EXPORT_A, 0, "uri");
        executor.challengeStateExport(EXPORT_A, CHALLENGE, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportChallengeAlreadyRecorded.selector,
                EXPORT_A,
                CHALLENGE
            )
        );
        vm.prank(SECOND_OWNER);
        executor.challengeStateExport(EXPORT_A, CHALLENGE, "other");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportUnknown.selector, EXPORT_B
            )
        );
        vm.prank(BUYER);
        executor.supersedeStateExport(EXPORT_A, EXPORT_B, CHALLENGE, "uri");
        vm.roll(1_001);
        _anchor(1_000, keccak256("next"));
        _publish(1_000, EXPORT_B, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportInvalidSupersession.selector,
                EXPORT_B,
                EXPORT_A
            )
        );
        vm.prank(BUYER);
        executor.supersedeStateExport(EXPORT_B, EXPORT_A, CHALLENGE, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportInvalidSupersession.selector,
                EXPORT_A,
                EXPORT_A
            )
        );
        vm.prank(BUYER);
        executor.supersedeStateExport(EXPORT_A, EXPORT_A, CHALLENGE, "uri");
        vm.prank(BUYER);
        executor.supersedeStateExport(EXPORT_A, EXPORT_B, CHALLENGE, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportInvalidSupersession.selector,
                EXPORT_A,
                EXPORT_B
            )
        );
        vm.prank(BUYER);
        executor.supersedeStateExport(EXPORT_A, EXPORT_B, CHALLENGE, "different");
        _latest(EXPORT_B);
    }

    function testPointerReplacementDisablesAllOldWritesAndPreservesHistory() public {
        _publish(999, EXPORT_A, "uri");
        ReplacementStateExportPublisher replacement = new ReplacementStateExportPublisher();
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(replacement),
            POINTER,
            keccak256("v2"),
            type(IStreamStateExportPublisher).interfaceId,
            500_000,
            address(replacement).codehash,
            DEPLOYMENT_HASH,
            keccak256("replacement publisher"),
            "urn:replacement"
        );
        (GovernanceCall[] memory registration, bytes[] memory registrationData) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        _execute(registration, registrationData, 1);
        bytes32[] memory pointerTypes = new bytes32[](1);
        pointerTypes[0] = POINTER;
        (GovernanceCall[] memory update, bytes[] memory updateData) =
            StreamCurrentStackPlan.pointerCalls(core, registry, pointerTypes, records);
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        calls[0] = update[0];
        data[0] = updateData[0];
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        current.modules.stateExportPublisher = address(replacement);
        (address payload, bytes32 payloadHash) =
            StreamGenesisManifestPlan.writePayload(bytes("{\"publisher\":\"replacement\"}"));
        StreamSystemManifestUpdate memory discovery = StreamSystemManifestUpdate(
            payloadHash,
            "urn:replacement",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (calls[1], data[1]) = StreamGenesisManifestPlan.publicationCall(
            manifest, payload, discovery, current.modules
        );
        _execute(calls, data, 3);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportPublisherInactive.selector
            )
        );
        _publish(999, EXPORT_B, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportPublisherInactive.selector
            )
        );
        executor.challengeStateExport(EXPORT_A, CHALLENGE, "uri");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportPublisherInactive.selector
            )
        );
        vm.prank(BUYER);
        executor.supersedeStateExport(EXPORT_A, EXPORT_B, CHALLENGE, "uri");
        _latest(EXPORT_A);
        require(executor.stateExportHashAt(0) == EXPORT_A, "old history discoverable");
    }

    function testBoundCoreAndRoleRegistryCodeDriftRejectPublication() public {
        bytes memory roleCode = address(roles).code;
        vm.etch(address(roles), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.RoleRegistryCodeHashMismatch.selector,
                keccak256(roleCode),
                keccak256(hex"00")
            )
        );
        _publish(999, EXPORT_A, "uri");
        vm.etch(address(roles), roleCode);
        vm.etch(address(core), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamStateExportOperations.StateExportPublisherInactive.selector
            )
        );
        _publish(999, EXPORT_A, "uri");
    }

    function testFuzzForwardLineageNeverChangesHistoricalClaims(uint8 countSeed) public {
        uint256 count = uint256(countSeed % 12) + 2;
        bytes32 previous;
        for (uint256 i; i < count; ++i) {
            uint256 number = 1_000 + i;
            vm.roll(number + 1);
            _anchor(number, keccak256(abi.encode(number)));
            bytes32 hash = keccak256(abi.encode("export", i));
            _publish(number, hash, "uri");
            if (i != 0) {
                vm.prank(BUYER);
                executor.supersedeStateExport(previous, hash, CHALLENGE, "uri");
                (StreamStateExportRecord memory record, bytes32 successor) =
                    executor.stateExport(previous);
                require(
                    record.sequence == i && record.blockNumber == number - 1 && successor == hash,
                    "forward immutable lineage"
                );
            }
            previous = hash;
        }
        _latest(previous);
        require(executor.stateExportCount() == count, "append count");
    }

    function _publish(uint256 number, bytes32 hash, string memory uri) private {
        bytes32 anchor = blockhash(number);
        vm.prank(BUYER);
        executor.publishStateExport(number, anchor, hash, MANIFEST, uri);
    }

    function _anchor(uint256 number, bytes32 hash) private {
        StateExportVm(address(vm)).setBlockhash(number, hash);
    }

    function _latest(bytes32 expected) private view {
        (,, bytes32 hash,,) = executor.latestStateExport();
        require(hash == expected, "latest identity");
    }

    function _event(
        Vm.Log[] memory logs,
        bytes32 topic,
        bytes32 first,
        bytes32 second,
        bytes32 third,
        bytes memory data
    ) private view {
        require(logs.length == 1 && logs[0].emitter == address(executor), "Executor emitter");
        require(logs[0].topics.length == 4 && logs[0].topics[0] == topic, "event signature");
        require(
            logs[0].topics[1] == first && logs[0].topics[2] == second && logs[0].topics[3] == third,
            "indexed fields"
        );
        require(keccak256(logs[0].data) == keccak256(data), "canonical event data");
    }

    function _publisherRole(address holder, bool grant) private {
        (bytes32 roleChain, uint64 roleRevision) = roles.roleMutationState(ROLE);
        (bytes32 globalChain, uint64 globalRevision) = roles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(roles),
                ROLE,
                holder
            )
        );
        bytes32 oldState =
            _roleState(scope, !grant, roleChain, roleRevision, globalChain, globalRevision);
        bytes32 nextRole = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                roleChain,
                block.chainid,
                address(roles),
                ROLE,
                holder,
                grant,
                roleRevision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(roles),
                ROLE,
                holder,
                grant,
                globalRevision + 1
            )
        );
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] = grant
            ? abi.encodeCall(roles.grantRole, (ROLE, holder))
            : abi.encodeCall(roles.revokeRole, (ROLE, holder));
        calls[0] = StreamCurrentStackPlan.call(
            address(roles),
            data[0],
            scope,
            oldState,
            _roleState(scope, grant, nextRole, roleRevision + 1, nextGlobal, globalRevision + 1)
        );
        _execute(calls, data, 1);
    }

    function _roleState(
        bytes32 scope,
        bool granted,
        bytes32 roleChain,
        uint64 roleRevision,
        bytes32 globalChain,
        uint64 globalRevision
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(roles),
                scope,
                granted,
                roleChain,
                roleRevision,
                globalChain,
                globalRevision
            )
        );
    }

    function _execute(GovernanceCall[] memory calls, bytes[] memory data, uint8 actionClass)
        private
    {
        executor.publishGovernanceCallData(data);
        bytes32 callsHash = StreamGovernanceBootstrap.governanceCallsHash(calls);
        (bytes32 scope, bytes32 oldState, bytes32 nextState) =
            StreamGovernanceBootstrap.deriveBatchTransitionHashes(calls, callsHash);
        uint64 notBefore = uint64(block.timestamp + 48 hours);
        bytes memory request = abi.encodeCall(
            executor.scheduleGovernanceBatch,
            (
                actionClass,
                calls,
                scope,
                oldState,
                nextState,
                notBefore,
                notBefore + 7 days,
                keccak256("publisher test action"),
                "urn:publisher-test",
                StreamGenesisManifestPlan.readAggregate(manifest).manifestHash
            )
        );
        bytes32 id = abi.decode(governanceRoot.execute(address(executor), 0, request), (bytes32));
        vm.warp(notBefore);
        executor.executeGovernanceBatch(id, calls, data);
    }
}
