// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./RecoveryGovernanceIntegrationFixture.sol";
import "./RecoveryCoreMintBoundaries.sol";
import "../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import "../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import "../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";

/// @dev Entropy authorization is a boundary; actual Core authenticates and transports this callback.
contract ScopeMembershipEntropyBoundary {
    address public immutable core;
    uint256 public callbacks;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamEntropyCoordinator).interfaceId;
    }

    function onTokenMinted(uint256 cid, uint256 id, address recipient, bytes32 commitment)
        external
    {
        require(
            msg.sender == core && (cid == 1 || cid == 2) && id == callbacks + 1
                && recipient == address(0xbeef) && commitment != 0
        );
        ++callbacks;
    }
}

/// @notice Actual Core, Metadata, Schema, native Store, Inventory, ModuleRegistry, Executor and Safe.
/// @dev Mint/entropy/artist authority and original finality remain the explicit inherited boundaries.
abstract contract ScopeMembershipCoreFixture is RecoveryGovernanceIntegrationFixture {
    StreamCollectionMetadataV1 internal scopeMetadata;
    StreamSchemaRegistry internal scopeSchemas;
    StreamSchemaDocumentStore internal scopeStore;
    StreamCollectionTokenInventory internal scopeInventory;
    StreamFinalityScopeMembership internal scopeMembership;
    RecoveryCoreMintBoundary internal scopeManager;
    ScopeMembershipEntropyBoundary internal scopeEntropy;
    bytes32 internal constant MEMBERSHIP_RECORD = keccak256("SCOPE_MEMBERSHIP");

    function _initializeScope() internal {
        _initialize();
        scopeSchemas = new StreamSchemaRegistry(address(configuration.executor));
        scopeStore = StreamSchemaDocumentStore(scopeSchemas.chunkStore());
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(configuration.core);
        c.executor = address(configuration.executor);
        c.schemas = address(scopeSchemas);
        c.artistRegistry = fixture.artistTarget();
        c.deploymentManifestHash = configuration.deploymentHash;
        c.manifestHash = keccak256("actual scope metadata");
        c.manifestURI = "ipfs://scope/metadata";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        scopeMetadata = new StreamCollectionMetadataV1(c);
        scopeManager = new RecoveryCoreMintBoundary();
        scopeEntropy = new ScopeMembershipEntropyBoundary(address(configuration.core));
        _scopePolicy();
        _scopeRegister(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(scopeSchemas.RAW_BYTES_DEFINITION())
        );
        _scopeRegister(
            "STREAM_SCOPE_MEMBERSHIP_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("docs/schemas/finality/scope-membership-v1.schema.json"))
        );
        _scopeRegister(
            "STREAM_SCOPE_MEMBERSHIP_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("docs/schemas/finality/scope-membership-abi-v1.json"))
        );
        _scopeInstall();
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        (calls[0], data[0]) = StreamCurrentStackPlan.createCollectionCall(configuration.core, 1, 3);
        (calls[1], data[1]) = StreamCurrentStackPlan.createCollectionCall(configuration.core, 2, 2);
        _runBatch(1, calls, data);
        (bytes32 s, bytes32 o, bytes32 n) =
            scopeMetadata.recordTypeTransition(
                MEMBERSHIP_RECORD, StreamRecordFamilies.IDENTITY, 384
            );
        _scopeRun(
            address(scopeMetadata),
            abi.encodeCall(
                scopeMetadata.admitRecordType,
                (MEMBERSHIP_RECORD, StreamRecordFamilies.IDENTITY, 384)
            ),
            s,
            o,
            n
        );
        _scopeGrant(address(this), true);
        scopeInventory = new StreamCollectionTokenInventory(
            address(configuration.core),
            address(configuration.executor),
            IStreamGasParameterHost.GasParameterConfig(
                "TOKEN_INVENTORY_CORE_READ_GAS", 100000, 50000, 1
            )
        );
        scopeMembership = new StreamFinalityScopeMembership(
            address(configuration.core),
            address(scopeMetadata),
            address(scopeInventory),
            address(configuration.executor),
            IStreamGasParameterHost.GasParameterConfig(
                "SCOPE_MEMBERSHIP_READ_GAS", 500000, 50000, 1
            )
        );
    }

    function _scopePolicy() private {
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](3);
        additions[0] =
            _entry(1, address(scopeSchemas), IStreamSchemaRegistry.registerDocument.selector);
        additions[1] =
            _entry(1, address(scopeMetadata), IStreamCollectionMetadataV1.admitRecordType.selector);
        additions[2] =
            _entry(1, address(scopeMetadata), IStreamCollectionMetadataV1.setFamilyWriter.selector);
        for (uint256 i = 1; i < additions.length; ++i) {
            for (
                uint256 j = i;
                j > 0 && uint256(_key(additions[j])) < uint256(_key(additions[j - 1]));
                --j
            ) {
                (additions[j], additions[j - 1]) = (additions[j - 1], additions[j]);
            }
        }
        (bytes32 candidate, bytes32 catalog, uint256 count, uint64 revision) =
            configuration.executor.governanceActionPolicyState();
        (bytes32 next, bytes32 s, bytes32 o, bytes32 n) = StreamGovernanceActionPolicy.extensionTransition(
            address(configuration.executor), candidate, catalog, count, revision, additions
        );
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(
            configuration.executor.extendGovernanceActionPolicy,
            (revision, catalog, next, additions)
        );
        calls[0] = StreamCurrentStackPlan.call(address(configuration.executor), data[0], s, o, n);
        (calls[1], data[1]) = _publication(
            StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules, next
        );
        _runBatch(3, calls, data);
    }

    function _scopeRegister(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        (bytes32 hash,) = scopeStore.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, scopeSchemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = scopeSchemas.registrationTransition(spec, chunks);
        _scopeRun(
            address(scopeSchemas),
            abi.encodeCall(scopeSchemas.registerDocument, (spec, chunks)),
            s,
            o,
            n
        );
        require(keccak256(scopeSchemas.documentBytes(keccak256(bytes(name)))) == hash);
    }

    function _scopeInstall() private {
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](3);
        registrations[0] = StreamModuleRegistration(
            address(scopeMetadata),
            scopeMetadata.streamModuleType(),
            scopeMetadata.streamModuleVersion(),
            scopeMetadata.streamModuleInterfaceId(),
            500000,
            address(scopeMetadata).codehash,
            configuration.deploymentHash,
            keccak256("actual scope metadata"),
            "ipfs://scope/metadata"
        );
        registrations[1] = StreamModuleRegistration(
            address(scopeManager),
            keccak256("MINT_MANAGER"),
            keccak256("scope mint boundary"),
            type(IStreamMintManager).interfaceId,
            500000,
            address(scopeManager).codehash,
            configuration.deploymentHash,
            keccak256("scope mint manifest"),
            "ipfs://scope/mint"
        );
        registrations[2] = StreamModuleRegistration(
            address(scopeEntropy),
            keccak256("ENTROPY_COORDINATOR"),
            keccak256("scope entropy boundary"),
            type(IStreamEntropyCoordinator).interfaceId,
            500000,
            address(scopeEntropy).codehash,
            configuration.deploymentHash,
            keccak256("scope entropy manifest"),
            "ipfs://scope/entropy"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(configuration.registry, registrations);
        _runBatch(1, calls, data);
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = keccak256("COLLECTION_METADATA");
        keys[1] = keccak256("MINT_MANAGER");
        keys[2] = keccak256("ENTROPY_COORDINATOR");
        (GovernanceCall[] memory ptrs, bytes[] memory ptrdata) = StreamCurrentStackPlan.pointerCalls(
            configuration.core, configuration.registry, keys, registrations
        );
        calls = new GovernanceCall[](4);
        data = new bytes[](4);
        for (uint256 i; i < 3; ++i) {
            calls[i] = ptrs[i];
            data[i] = ptrdata[i];
        }
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules;
        modules.collectionMetadata = address(scopeMetadata);
        modules.mintManager = address(scopeManager);
        modules.entropyCoordinator = address(scopeEntropy);
        (calls[3], data[3]) = _publication(modules, keccak256("actual scope host installation"));
        _runBatch(3, calls, data);
    }

    function _scopeRun(address target, bytes memory payload, bytes32 s, bytes32 o, bytes32 n)
        internal
    {
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        bytes[] memory data = new bytes[](1);
        data[0] = payload;
        calls[0] = StreamCurrentStackPlan.call(target, payload, s, o, n);
        _runBatch(1, calls, data);
    }

    function _scopeGrant(address writer, bool enabled) internal {
        (bytes32 s, bytes32 o, bytes32 n) =
            scopeMetadata.familyWriterTransition(
                1, StreamRecordFamilies.IDENTITY, 7, writer, enabled
            );
        _scopeRun(
            address(scopeMetadata),
            abi.encodeCall(
                scopeMetadata.setFamilyWriter,
                (1, StreamRecordFamilies.IDENTITY, 7, writer, enabled)
            ),
            s,
            o,
            n
        );
    }

    function _scopePublish(uint8 family, uint256[] memory ids, string memory uri)
        internal
        returns (bytes32 hash, StreamFinalityScope memory s)
    {
        bytes memory list = new bytes(ids.length * 32);
        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];
            assembly { mstore(add(add(list, 32), mul(i, 32)), id) }
        }
        (bytes32 part,) = scopeStore.publishChunk(list);
        bytes32[] memory parts = new bytes32[](1);
        parts[0] = part;
        StreamScopeMembershipManifest memory m = StreamScopeMembershipManifest(
            1,
            block.chainid,
            address(configuration.core),
            1,
            family,
            ids.length,
            keccak256(list),
            parts
        );
        bytes memory payload = StreamScopeMembershipEncoding.encode(m);
        IStreamPreservationRecords.CollectionRecord memory r;
        r.recordType = MEMBERSHIP_RECORD;
        r.subjectId = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(configuration.core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        r.schemaId = keccak256("STREAM_SCOPE_MEMBERSHIP_V1");
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), keccak256("STREAM_SCOPE_MEMBERSHIP_ABI_V1")
        );
        r.uri = uri;
        r.effectiveAt = uint64(block.timestamp);
        hash = scopeMetadata.recordCollectionRecordWithPayload(1, r, payload);
        s = scopeMembership.beginScopeMembership(hash);
    }
}
