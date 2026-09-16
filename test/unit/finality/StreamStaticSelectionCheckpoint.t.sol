// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    StreamStaticSelectionCheckpoint
} from "../../../smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol";
import {
    IStreamStaticSelectionCheckpoint as C
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamCorePointers
} from "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import "../../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";

interface StaticCheckpointVm {
    function etch(address, bytes calldata) external;
}

contract StaticLegacyEvidenceProbe {
    function facts(address core, address router, bytes32 family, StreamFinalityScope calldata scope)
        external
        view
        returns (bool, bytes32)
    {
        return StreamFinalityRouterEvidence.facts(
            StreamFinalityRouterEvidence.Config(core, router, block.chainid, 2000000, 2000000),
            family,
            scope
        );
    }
}

/// @notice Actual Router/Renderer/Metadata/schema/store/inventory/membership and threshold Safe.
/// @dev Core, Artist permits, renderer admission and governance remain explicit typed boundaries.
/// Authored cases do not establish current-stack or transitive STATIC opcode acceptance.
contract StreamStaticSelectionCheckpointTest is StaticMetadataRoutingFixture {
    StreamCollectionTokenInventory private inventory;
    StreamFinalityScopeMembership private membership;
    StreamStaticSelectionCheckpoint private checkpoints;

    function setUp() public override {
        super.setUp();
        inventory = new StreamCollectionTokenInventory(
            address(core),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "TOKEN_INVENTORY_CORE_READ_GAS", 100000, 50000, 1
            )
        );
        membership = new StreamFinalityScopeMembership(
            address(core),
            address(metadata),
            address(inventory),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "SCOPE_MEMBERSHIP_READ_GAS", 500000, 50000, 1
            )
        );
        checkpoints = new StreamStaticSelectionCheckpoint(
            address(core),
            address(router),
            address(membership),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_CHECKPOINT_READ_GAS", 2000000, 500000, 1
            )
        );
        // Exact Core pointer ABI boundary; other genuine hosts are not mocked.
        StaticRouteVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("METADATA_ROUTER"))
                ),
                abi.encode(
                    address(router),
                    address(router).codehash,
                    false,
                    keccak256("METADATA_ROUTER"),
                    type(IStreamMetadataRouter).interfaceId,
                    address(modules),
                    uint8(1),
                    keccak256("manifest"),
                    keccak256("deployment"),
                    uint64(1)
                )
            );
    }

    function testCompleteOrderedSelectionsIncludeDifferentFrozenTokenOverride() public {
        _two();
        _freeze(2, R.MetadataMode.OFFCHAIN);
        S.ConfigInput memory collection = _input(R.MetadataMode.ONCHAIN, true);
        _approve(0, collection, keccak256("collection freeze"));
        router.setCollectionMetadataConfig(1, collection);
        vm.recordLogs();
        bytes32 id = checkpoints.begin(_collection());
        checkpoints.append(id, 1);
        vm.expectRevert();
        checkpoints.requireCurrentCheckpoint(id);
        C.TokenSelection memory a = checkpoints.selectionAt(id, 0);
        require(
            a.tokenId == 1 && a.configRecordHash == router.collectionMetadataConfig(1).recordHash
        );
        checkpoints.append(id, 16);
        C.TokenSelection memory b = checkpoints.selectionAt(id, 1);
        require(
            b.tokenId == 2 && b.configRecordHash == router.resolvedMetadataConfig(2).recordHash
                && a.configRecordHash != b.configRecordHash
        );
        bytes32 chain =
            keccak256(abi.encode(checkpoints.CHAIN_DOMAIN(), bytes32(0), uint256(0), _row(a)));
        chain = keccak256(abi.encode(checkpoints.CHAIN_DOMAIN(), chain, uint256(1), _row(b)));
        C.Plan memory done = checkpoints.requireCurrentCheckpoint(id);
        require(
            done.nextIndex == 2 && done.selectionRoot == chain
                && checkpoints.begin(_collection()) == id
        );
        _assertEvents(id, a, b, chain);
        core.setToken(2, address(this), 3);
        require(
            checkpoints.requireCurrentCheckpoint(id).selectionRoot == chain,
            "burn does not erase original selection"
        );
        vm.expectRevert();
        checkpoints.selectionAt(id, 2);
    }

    function testActualInventoryGrowthInvalidatesCurrentCandidateButRetainsRows() public {
        _two();
        _freeze(1, R.MetadataMode.ONCHAIN);
        _freeze(2, R.MetadataMode.ONCHAIN);
        bytes32 id = checkpoints.begin(_collection());
        checkpoints.append(id, 2);
        bytes32 old = checkpoints.selectionAt(id, 0).configRecordHash;
        core.setToken(3, address(this), 2);
        core.setMinted(3);
        vm.expectRevert();
        checkpoints.requireCurrentCheckpoint(id);
        uint256[] memory next = new uint256[](1);
        next[0] = 3;
        inventory.appendCollectionTokens(1, next);
        require(
            checkpoints.begin(_collection()) != id
                && checkpoints.selectionAt(id, 0).configRecordHash == old
        );
    }

    function testLateMutableRowRollsBackEntireAppendAndCannotSkipMember() public {
        _two();
        _freeze(1, R.MetadataMode.ONCHAIN);
        bytes32 id = checkpoints.begin(_collection());
        vm.expectRevert();
        checkpoints.append(id, 2);
        require(
            checkpoints.checkpoint(id).nextIndex == 0
                && checkpoints.checkpoint(id).selectionRoot == 0
        );
        vm.expectRevert();
        checkpoints.selectionAt(id, 0);
        _freeze(2, R.MetadataMode.ONCHAIN);
        vm.expectRevert();
        checkpoints.append(id, 1);
        bytes32 fresh = checkpoints.begin(_collection());
        checkpoints.append(fresh, 2);
        require(checkpoints.requireCurrentCheckpoint(fresh).nextIndex == 2);
    }

    function testCollectionSourceChangeInvalidatesCandidateNotOriginalFrozenRows() public {
        _two();
        _freeze(1, R.MetadataMode.ONCHAIN);
        _freeze(2, R.MetadataMode.ONCHAIN);
        bytes32 id = checkpoints.begin(_collection());
        checkpoints.append(id, 2);
        C.TokenSelection memory before_ = checkpoints.selectionAt(id, 0);
        _admin(
            abi.encodeCall(
                router.setCollectionMetadata, (1, "Later name", "Exact source", "ipfs://image", "")
            )
        );
        vm.expectRevert();
        checkpoints.requireCurrentCheckpoint(id);
        bytes32 fresh = checkpoints.begin(_collection());
        checkpoints.append(fresh, 2);
        require(
            checkpoints.selectionAt(fresh, 0).rawSourceHash == before_.rawSourceHash,
            "frozen source is retained literally"
        );
        require(
            checkpoints.checkpoint(fresh).selectionRoot == checkpoints.checkpoint(id).selectionRoot
                && fresh != id
        );
    }

    function testRetainedDeprecationAllowedButRecordedRuntimeDriftIsTerminal() public {
        _two();
        _freeze(1, R.MetadataMode.ONCHAIN);
        _freeze(2, R.MetadataMode.ONCHAIN);
        bytes32 id = checkpoints.begin(_collection());
        versions.deprecate();
        checkpoints.append(id, 2);
        bytes memory code = address(renderer).code;
        StaticCheckpointVm(address(vm)).etch(address(renderer), hex"fe");
        vm.expectRevert();
        checkpoints.requireCurrentCheckpoint(id);
        StaticCheckpointVm(address(vm)).etch(address(renderer), code);
        require(checkpoints.requireCurrentCheckpoint(id).nextIndex == 2);
    }

    function testTokenScopeUsesActualMemberAndOriginalCoordinator() public {
        _two();
        _freeze(2, R.MetadataMode.ONCHAIN);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 2, 0);
        bytes32 id = checkpoints.begin(scope);
        core.setEntropy(address(metadata));
        vm.expectRevert();
        checkpoints.append(id, 1);
        require(checkpoints.checkpoint(id).nextIndex == 0);
        core.setEntropy(address(entropy));
        checkpoints.append(id, 1);
        require(
            checkpoints.selectionAt(id, 0).tokenId == 2
                && checkpoints.requireCurrentCheckpoint(id).tokenCount == 1
        );
    }

    function testActualPublishedSubsetEnumeratesOnlyItsCompleteRecordedMembers() public {
        _two();
        _freeze(2, R.MetadataMode.ONCHAIN);
        StreamFinalityScope memory scope = _publishedSubset();
        bytes32 id = checkpoints.begin(scope);
        checkpoints.append(id, 16);
        require(
            checkpoints.selectionAt(id, 0).tokenId == 2
                && checkpoints.requireCurrentCheckpoint(id).tokenCount == 1
        );
        core.setToken(3, address(this), 2);
        core.setMinted(3);
        require(
            checkpoints.requireCurrentCheckpoint(id).tokenCount == 1,
            "later parent mint does not change published subset"
        );
    }

    function testActualSafeLateAppendFailureHasByteIdenticalRetry() public {
        _two();
        _freeze(1, R.MetadataMode.ONCHAIN);
        _freeze(2, R.MetadataMode.ONCHAIN);
        bytes32 id = checkpoints.begin(_collection());
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0x6530;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 997);
        bytes memory callData = abi.encodeCall(checkpoints.append, (id, uint256(2)));
        uint256 nonce = account.nonce();
        bytes32 digest = account.getTransactionHash(
            address(checkpoints), 0, callData, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        StaticRouteVm(address(vm))
            .mockCallRevert(
                address(router), abi.encodeCall(S.resolvedMetadataConfig, (uint256(2))), hex"abcd"
            );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(checkpoints),
            0,
            callData,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signatures
        );
        require(
            account.nonce() == nonce && checkpoints.checkpoint(id).nextIndex == 0
                && checkpoints.checkpoint(id).selectionRoot == 0
        );
        // Clear only test mocks, then restore the explicit Core pointer boundary; original target/call/signatures remain byte-identical.
        StaticRouteVm(address(vm)).clearMockedCalls();
        _pointer();
        require(
            account.execTransaction(
                address(checkpoints),
                0,
                callData,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
        require(
            account.nonce() == nonce + 1 && checkpoints.requireCurrentCheckpoint(id).nextIndex == 2
        );
    }

    function testLegacyContextAndDependencyEvidenceRejectActivatedStaticProfile() public {
        StaticLegacyEvidenceProbe probe = new StaticLegacyEvidenceProbe();
        bytes32 context = StreamFinalityDomains.COMPONENT_RENDER_CONTEXT;
        bytes32 dependency = StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE;
        (bool frozen, bytes32 before_) =
            probe.facts(address(core), address(router), context, _collection());
        require(frozen && before_ != 0);
        _activate();
        vm.expectRevert();
        probe.facts(address(core), address(router), context, _collection());
        vm.expectRevert();
        probe.facts(address(core), address(router), dependency, _collection());
    }

    function _assertEvents(
        bytes32 id,
        C.TokenSelection memory a,
        C.TokenSelection memory b,
        bytes32 root
    ) private {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 4);
        for (uint256 i; i < 4; ++i) {
            require(logs[i].emitter == address(checkpoints) && logs[i].topics[1] == id);
        }
        (uint16 version, C.Plan memory started) = abi.decode(logs[0].data, (uint16, C.Plan));
        require(
            version == 1 && started.tokenCount == 2 && started.nextIndex == 0
                && started.selectionRoot == 0
        );
        for (uint256 i; i < 2; ++i) {
            (uint16 schema, C.TokenSelection memory row, bytes32 rowHash) =
                abi.decode(logs[i + 1].data, (uint16, C.TokenSelection, bytes32));
            require(schema == 1 && uint256(logs[i + 1].topics[2]) == i && rowHash == _row(row));
            require(keccak256(abi.encode(row)) == keccak256(abi.encode(i == 0 ? a : b)));
        }
        (uint16 completedVersion, bytes32 completedRoot, uint64 count) =
            abi.decode(logs[3].data, (uint16, bytes32, uint64));
        require(completedVersion == 1 && completedRoot == root && count == 2);
    }

    function _two() private {
        _activate();
        core.setToken(1, address(this), 2);
        core.setToken(2, address(this), 2);
        core.setMinted(2);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        inventory.appendCollectionTokens(1, ids);
    }

    function _freeze(uint256 token, R.MetadataMode mode) private {
        S.ConfigInput memory input = _input(mode, true);
        _approve(token, input, keccak256(abi.encode("freeze", token, mode)));
        router.setTokenMetadataConfig(token, input);
    }

    function _collection() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _row(C.TokenSelection memory row) private view returns (bytes32) {
        return keccak256(
            abi.encode(checkpoints.ROW_DOMAIN(), block.chainid, address(core), address(router), row)
        );
    }

    function _pointer() private {
        StaticRouteVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("METADATA_ROUTER"))
                ),
                abi.encode(
                    address(router),
                    address(router).codehash,
                    false,
                    keccak256("METADATA_ROUTER"),
                    type(IStreamMetadataRouter).interfaceId,
                    address(modules),
                    uint8(1),
                    keccak256("manifest"),
                    keccak256("deployment"),
                    uint64(1)
                )
            );
    }

    function _publishedSubset() private returns (StreamFinalityScope memory) {
        StreamSchemaDocumentStore store = StreamSchemaDocumentStore(schemas.chunkStore());
        _registerScope(
            store,
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _registerScope(
            store,
            "STREAM_SCOPE_MEMBERSHIP_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("docs/schemas/finality/scope-membership-v1.schema.json"))
        );
        _registerScope(
            store,
            "STREAM_SCOPE_MEMBERSHIP_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("docs/schemas/finality/scope-membership-abi-v1.json"))
        );
        (bytes32 s, bytes32 o, bytes32 n) = metadata.recordTypeTransition(
            keccak256("SCOPE_MEMBERSHIP"), StreamRecordFamilies.IDENTITY, 384
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.admitRecordType,
                (keccak256("SCOPE_MEMBERSHIP"), StreamRecordFamilies.IDENTITY, uint16(384))
            ),
            s,
            o,
            n
        );
        (s, o, n) = metadata.familyWriterTransition(
            1, StreamRecordFamilies.IDENTITY, 7, address(this), true
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter,
                (uint256(1), StreamRecordFamilies.IDENTITY, uint8(7), address(this), true)
            ),
            s,
            o,
            n
        );
        bytes32[] memory chunks = new bytes32[](1);
        (chunks[0],) = store.publishChunk(abi.encode(uint256(2)));
        StreamScopeMembershipManifest memory manifest = StreamScopeMembershipManifest(
            1, block.chainid, address(core), 1, 2, 1, keccak256(abi.encode(uint256(2))), chunks
        );
        bytes memory payload = StreamScopeMembershipEncoding.encode(manifest);
        IStreamPreservationRecords.CollectionRecord memory record;
        record.recordType = keccak256("SCOPE_MEMBERSHIP");
        record.subjectId =
            StreamMetadataSubjects.scopeSubject(block.chainid, address(core), _collection());
        record.schemaId = keccak256("STREAM_SCOPE_MEMBERSHIP_V1");
        record.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), keccak256("STREAM_SCOPE_MEMBERSHIP_ABI_V1")
        );
        record.uri = "ipfs://actual-static-subset";
        record.effectiveAt = uint64(block.timestamp);
        StreamFinalityScope memory scope = membership.beginScopeMembership(
            metadata.recordCollectionRecordWithPayload(1, record, payload)
        );
        membership.continueScopeMembership(scope, 1);
        return scope;
    }

    function _registerScope(
        StreamSchemaDocumentStore store,
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, schemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas), abi.encodeCall(schemas.registerDocument, (spec, chunks)), s, o, n
        );
    }
}
