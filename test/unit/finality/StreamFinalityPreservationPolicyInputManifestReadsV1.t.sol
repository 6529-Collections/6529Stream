// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityPreservationPolicyInputManifestReadsV1.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";

import {
    StreamFinalityScopedPreservationPolicyInputManifestReadsV1 as ScopedReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyInputManifestReadsV1.sol";
import {
    StreamFinalityScopedPreservationPolicyInputManifestTypesV1 as ScopedTypes
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityScopedPreservationPolicyInputManifestTypesV1.sol";
import {
    StreamFinalityScopedPreservationPolicyInputManifestSchemasV1 as ScopedDocs
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyInputManifestSchemasV1.sol";

/// @dev Explicit governance action-context boundary; this is not the actual Executor.
contract PreservationInputManifestGovernanceBoundaryV1 {
    bool private active;
    bytes32 private scope;
    bytes32 private oldHash;
    bytes32 private newHash;

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (active, keccak256("fixture action"), 1, scope, oldHash, newHash);
    }

    function run(address target, bytes memory data, bytes32 s, bytes32 o, bytes32 n) external {
        scope = s;
        oldHash = o;
        newHash = n;
        active = true;
        (bool ok, bytes memory result) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        active = false;
    }
}

/// @dev Typed Core/Metadata/original-Registry boundary. Actual original Registry assembly is separate.
contract PreservationInputManifestGraphBoundaryV1 {
    address public core;
    address public schemaRegistry;
    address public coreReads;
    address public metadataReads;
    mapping(bytes32 => bytes) private staged;

    function configure(address c, address s, address m) external {
        core = c;
        coreReads = c;
        schemaRegistry = s;
        metadataReads = m;
    }

    function stageFinalityManifest(bytes memory value) external returns (bytes32 hash) {
        hash = keccak256(value);
        staged[hash] = value;
    }

    function finalityManifestBytes(bytes32 hash) external view returns (bytes memory) {
        return staged[hash];
    }
}

/// @dev Test-only caller-filled facts. Production provider must derive these from actual sources.
contract PreservationInputManifestConsumerBoundaryV1 {
    StreamFinalityPreservationPolicyInputManifestReadsV1.Dependencies private d;

    constructor(address[5] memory targets) {
        d.targets = targets;
        d.chainId = block.chainid;
        d.readGas = 500000;
        for (uint256 i; i < 5; ++i) {
            d.codeHashes[i] = targets[i].codehash;
        }
    }

    function encoded(StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s)
        external
        view
        returns (bytes memory)
    {
        return StreamFinalityPreservationPolicyInputManifestReadsV1.encode(d, s);
    }

    function checked(
        StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s,
        bytes32 hash
    ) external view returns (bytes32, bytes32) {
        return StreamFinalityPreservationPolicyInputManifestReadsV1.requireCurrent(d, s, hash);
    }

    function inputsHash(StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s)
        external
        view
        returns (bytes32)
    {
        return StreamFinalityPreservationPolicyInputManifestReadsV1.scopeInputsHash(d, s);
    }

    // Test-only family transport. Production selects the fixed family in its provider.
    function encodedFamily(
        StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s,
        bytes32 family
    ) external view returns (bytes memory) {
        return StreamFinalityPreservationPolicyInputManifestReadsV1.encode(d, s, family);
    }

    function checkedFamily(
        StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s,
        bytes32 hash,
        bytes32 family
    ) external view returns (bytes32, bytes32) {
        return StreamFinalityPreservationPolicyInputManifestReadsV1.requireCurrent(
            d, s, hash, family
        );
    }

    function encodedScoped(ScopedTypes.Statement memory s) external view returns (bytes memory) {
        return ScopedReads.encode(_scopedDependencies(), s);
    }

    function checkedScoped(ScopedTypes.Statement memory s, bytes32 hash)
        external
        view
        returns (bytes32, bytes32)
    {
        return ScopedReads.requireCurrent(_scopedDependencies(), s, hash);
    }

    function scopedInputsHash(ScopedTypes.Statement memory s) external view returns (bytes32) {
        return ScopedReads.scopeInputsHash(_scopedDependencies(), s);
    }

    function _scopedDependencies() private view returns (ScopedReads.Dependencies memory v) {
        v.targets = d.targets;
        v.codeHashes = d.codeHashes;
        v.chainId = d.chainId;
        v.readGas = d.readGas;
    }
}

/// @notice Real Schema/Store with typed independent source facts and original Registry staging boundary.
/// @dev These read/encoding controls do not establish source authority or a complete finality ceremony.
contract StreamFinalityPreservationPolicyInputManifestReadsV1Test is CharacterizationTestBase {
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    PreservationInputManifestGovernanceBoundaryV1 private governance;
    PreservationInputManifestGraphBoundaryV1 private core;
    PreservationInputManifestGraphBoundaryV1 private metadata;
    PreservationInputManifestGraphBoundaryV1 private registry;
    PreservationInputManifestConsumerBoundaryV1 private consumer;
    StreamFinalityPreservationPolicyInputManifestTypesV1.Statement private statement;
    bytes32 private manifestHash;
    bytes32 private constant SCHEMA =
        keccak256("6529STREAM_FINALITY_PRESERVATION_POLICY_INPUT_MANIFEST_V1");
    bytes32 private constant CANON =
        keccak256("6529STREAM_FINALITY_PRESERVATION_POLICY_INPUT_MANIFEST_ABI_V1");

    function setUp() public {
        governance = new PreservationInputManifestGovernanceBoundaryV1();
        schemas = new StreamSchemaRegistry(address(governance));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        core = new PreservationInputManifestGraphBoundaryV1();
        metadata = new PreservationInputManifestGraphBoundaryV1();
        registry = new PreservationInputManifestGraphBoundaryV1();
        metadata.configure(address(core), address(schemas), address(metadata));
        registry.configure(address(core), address(schemas), address(metadata));
        consumer = new PreservationInputManifestConsumerBoundaryV1(
            [address(core), address(metadata), address(schemas), address(store), address(registry)]
        );
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "6529STREAM_FINALITY_PRESERVATION_POLICY_INPUT_MANIFEST_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamFinalityPreservationPolicyInputManifestSchemasV1.document(SCHEMA)
        );
        _register(
            "6529STREAM_FINALITY_PRESERVATION_POLICY_INPUT_MANIFEST_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            StreamFinalityPreservationPolicyInputManifestSchemasV1.document(CANON)
        );
        _register(
            "6529STREAM_SCOPED_PRESERVATION_POLICY_FINALITY_INPUT_MANIFEST_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            ScopedDocs.document(ScopedDocs.SCHEMA_ID)
        );
        _register(
            "6529STREAM_SCOPED_PRESERVATION_POLICY_FINALITY_INPUT_MANIFEST_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            ScopedDocs.document(ScopedDocs.CANON_ID)
        );
        statement.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        statement.coreFactsHash = bytes32(uint256(100));
        statement.contentRoot = bytes32(uint256(101));
        statement.leafCount = 2;
        statement.contentRootSchemaId = bytes32(uint256(102));
        statement.snapshotManifestHash = bytes32(uint256(103));
        statement.referenceRenderManifestHash = bytes32(uint256(104));
        statement.inputs = StreamFinalityScopeInputs(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            bytes32(uint256(3)),
            bytes32(uint256(4)),
            0,
            bytes32(uint256(6)),
            bytes32(uint256(7)),
            bytes32(uint256(8)),
            bytes32(uint256(9)),
            bytes32(uint256(10))
        );
        bytes32[9] memory families = [
            keccak256("METADATA_ROUTER"),
            keccak256("RENDERER"),
            keccak256("RENDER_CONTEXT"),
            keccak256("MEDIA_MANIFEST"),
            keccak256("SCRIPT_SOURCE"),
            keccak256("DEPENDENCY_SOURCE"),
            keccak256("COLLECTION_METADATA"),
            keccak256("ENTROPY_COORDINATOR"),
            keccak256("REFERENCE_RENDER")
        ];
        for (uint256 i = 1; i < 9; ++i) {
            for (uint256 j = i; j > 0 && families[j] < families[j - 1]; --j) {
                (families[j], families[j - 1]) = (families[j - 1], families[j]);
            }
        }
        for (uint256 i; i < 9; ++i) {
            statement.nonSanctionComponents
                .push(
                    StreamFinalityComponentExpectation(
                        families[i],
                        address(uint160(i + 1)),
                        bytes4(0x11223344),
                        bytes32(uint256(i + 10)),
                        bytes32(uint256(i + 20)),
                        bytes32(uint256(i + 30)),
                        bytes32(uint256(i + 40))
                    )
                );
        }
        statement.entropy = StreamFinalityPreservationPolicyInputManifestTypesV1.Entropy(
            address(0x1234),
            bytes32(uint256(901)),
            keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"),
            bytes32(uint256(902)),
            bytes32(uint256(903)),
            bytes32(uint256(904)),
            3,
            SnapshotDefinitions.PROFILE_HASH,
            ReferenceDefinitions.PROFILE_HASH
        );
        statement.postFreezePolicy = 1;
        statement.sanctionPolicy = 1;
        bytes memory payload = consumer.encoded(statement);
        (manifestHash,) = store.publishChunk(payload);
        registry.stageFinalityManifest(payload);
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory value
    ) private {
        (bytes32 hash,) = store.publishChunk(value);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory p = IStreamSchemaRegistry.DocumentSpec(
            name,
            kind,
            hash,
            keccak256("RAW_BYTES"),
            0,
            "ipfs://stream/definition",
            uint32(value.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(p, chunks);
        governance.run(
            address(schemas), abi.encodeCall(schemas.registerDocument, (p, chunks)), s, o, n
        );
    }

    function _retire(bytes32 id) private {
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        governance.run(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            s,
            o,
            n
        );
    }

    function _checkFails(
        StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s,
        bytes32 hash
    ) private view {
        (bool ok,) = address(consumer).staticcall(abi.encodeCall(consumer.checked, (s, hash)));
        require(!ok, "must reject");
    }

    function _shapeFails(StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s)
        private
        view
    {
        (bool ok,) = address(consumer).staticcall(abi.encodeCall(consumer.encoded, (s)));
        require(!ok, "invalid shape fails without relying on an old manifest hash");
    }

    function _word(bytes memory raw, uint256 index) private pure returns (bytes32 result) {
        require((index + 1) * 32 <= raw.length, "word bounds");
        assembly ("memory-safe") { result := mload(add(add(raw, 32), mul(index, 32))) }
    }

    function testActualRegisteredDefinitionsAndBothRetainedCopiesMatch() public view {
        (bytes32 schema, bytes32 canon) = consumer.checked(statement, manifestHash);
        require(schema == SCHEMA && canon == CANON, "actual profile identities");
        bytes memory payload = store.readChunk(manifestHash);
        require(
            keccak256(payload) == keccak256(registry.finalityManifestBytes(manifestHash)),
            "two exact copies"
        );
        require(_word(payload, 0) == SCHEMA && _word(payload, 1) == CANON, "literal envelope IDs");
        require(uint256(_word(payload, 2)) == block.chainid, "chain");
        require(uint256(_word(payload, 3)) == uint256(uint160(address(core))), "actual Core");
        require(
            uint256(_word(payload, 4)) == uint256(uint160(address(metadata))),
            "actual generic metadata"
        );
        require(
            uint256(_word(payload, 5)) == uint256(uint160(address(registry))), "original Registry"
        );
        require(uint256(_word(payload, 6)) == 224, "single canonical tuple offset");
        require(
            consumer.inputsHash(statement)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_SCOPE_INPUTS_V1"),
                        block.chainid,
                        address(core),
                        address(metadata),
                        statement.scope,
                        statement.inputs
                    )
                ),
            "permanent preimage home"
        );
    }

    function testStoreRetentionDoesNotSubstituteForOriginalRegistryStaging() public {
        StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s = statement;
        s.coreFactsHash = keccak256("new actual supply facts");
        bytes memory payload = consumer.encoded(s);
        (bytes32 hash,) = store.publishChunk(payload);
        _checkFails(s, hash);
        registry.stageFinalityManifest(payload);
        consumer.checked(s, hash);
    }

    function testOriginalRegistryStagingDoesNotSubstituteForStoreRetention() public {
        StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s = statement;
        s.coreFactsHash = keccak256("other actual supply facts");
        bytes memory payload = consumer.encoded(s);
        bytes32 hash = registry.stageFinalityManifest(payload);
        _checkFails(s, hash);
        store.publishChunk(payload);
        consumer.checked(s, hash);
    }

    function testRetiredInterpretationRemainsReadableButCannotAdmitCurrentCandidate() public {
        _retire(CANON);
        require(schemas.documentBytes(CANON).length != 0, "history retained");
        _checkFails(statement, manifestHash);
    }

    function testMissingDuplicateUnsortedOrSanctionComponentRejects() public {
        StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s = statement;
        s.nonSanctionComponents[0].componentType = keccak256("ARTIST_SANCTION");
        _shapeFails(s);
        s = statement;
        s.nonSanctionComponents[1] = s.nonSanctionComponents[0];
        _shapeFails(s);
        s = statement;
        (s.nonSanctionComponents[0], s.nonSanctionComponents[1]) =
        (s.nonSanctionComponents[1], s.nonSanctionComponents[0]);
        _shapeFails(s);
        s = statement;
        s.nonSanctionComponents = new StreamFinalityComponentExpectation[](8);
        _shapeFails(s);
    }

    function testAlternateOffsetsAndTrailingBytesCannotBeRelabeled() public {
        bytes memory payload = consumer.encoded(statement);
        bytes memory padded = bytes.concat(payload, bytes32(0));
        (bytes32 hash,) = store.publishChunk(padded);
        registry.stageFinalityManifest(padded);
        _checkFails(statement, hash);
        // An ABI-readable extra gap before the dynamic statement is still not canonical bytes.
        bytes memory shifted = new bytes(payload.length + 32);
        for (uint256 i; i < 224; ++i) {
            shifted[i] = payload[i];
        }
        assembly ("memory-safe") { mstore(add(shifted, 224), 256) }
        for (uint256 i = 224; i < payload.length; ++i) {
            shifted[i + 32] = payload[i];
        }
        (hash,) = store.publishChunk(shifted);
        registry.stageFinalityManifest(shifted);
        _checkFails(statement, hash);
    }

    function testPortableDefinitionsAreExactRegisteredBytes() public view {
        require(
            keccak256(
                bytes(
                    vm.readFile(
                        "docs/schemas/preservation/finality-preservation-policy-input-manifest-v1.schema.json"
                    )
                )
            ) == keccak256(schemas.documentBytes(SCHEMA)),
            "portable schema exact"
        );
        require(
            keccak256(
                bytes(
                    vm.readFile(
                        "docs/schemas/preservation/finality-preservation-policy-input-manifest-v1.abi.json"
                    )
                )
            ) == keccak256(schemas.documentBytes(CANON)),
            "portable ABI exact"
        );
    }

    function testEveryFullPolicyIdentityChangesExactDocumentWithoutChangingRegistryInputDomain()
        public
    {
        bytes32 originalInputs = consumer.inputsHash(statement);
        for (uint256 i; i < 9; ++i) {
            StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s = statement;
            if (i == 0) {
                s.entropy.sourceSet = address(0x9876);
            } else if (i == 1) {
                s.entropy.sourceSetCodeHash = keccak256("new code");
            } else if (i == 2) {
                s.entropy.inventoryPlan = keccak256("new complete plan");
            } else if (i == 3) {
                s.entropy.inventoryHash = keccak256("new original inventory");
            } else if (i == 4) {
                s.entropy.policyChainHash = keccak256("new full twelve-word policy chain");
            } else if (i == 5) {
                s.entropy.policyCount = 4;
            } else if (i == 6) {
                s.entropy.sourceSetProfile = bytes32(uint256(1));
            } else if (i == 7) {
                s.entropy.snapshotProfileHash = bytes32(uint256(2));
            } else {
                s.entropy.referenceProfileHash = bytes32(uint256(3));
            }
            _checkFails(s, manifestHash);
            if (i >= 6) _shapeFails(s);
            require(consumer.inputsHash(s) == originalInputs, "original Registry domain unchanged");
            if (i < 6) {
                bytes memory payload = consumer.encoded(s);
                require(keccak256(payload) != manifestHash, "full policy commitment changed");
                (bytes32 hash,) = store.publishChunk(payload);
                registry.stageFinalityManifest(payload);
                consumer.checked(s, hash);
            }
        }
        consumer.checked(statement, manifestHash);
    }

    function testLiteralPreservationEncodingDoesNotRelabelOriginalPolicySchema() public view {
        bytes memory literal = abi.encode(
            keccak256("6529STREAM_FINALITY_PRESERVATION_POLICY_INPUT_MANIFEST_V1"),
            keccak256("6529STREAM_FINALITY_PRESERVATION_POLICY_INPUT_MANIFEST_ABI_V1"),
            block.chainid,
            address(core),
            address(metadata),
            address(registry),
            statement
        );
        require(keccak256(literal) == manifestHash && literal.length <= 8192);
        // 32 words in Statement before its 9-row dynamic component tail; entropy is static.
        require(uint256(_word(literal, 7 + 20)) == 32 * 32, "exact component offset");
        require(_word(literal, 7 + 21) == bytes32(uint256(uint160(statement.entropy.sourceSet))));
        require(_word(literal, 7 + 26) == statement.entropy.policyChainHash);
        require(uint256(_word(literal, 7 + 27)) == statement.entropy.policyCount);
        require(keccak256(literal) != keccak256(abi.encode(statement.inputs, uint8(1))));
    }

    function _scoped(uint8 kind) private view returns (ScopedTypes.Statement memory s) {
        s.scope = StreamFinalityScope(
            StreamFinalityScopeType(kind),
            1,
            kind == 1 ? 91 : 0,
            kind == 1 ? bytes32(0) : keccak256("actual scope coordinate boundary")
        );
        s.coreFactsHash = statement.coreFactsHash;
        s.contentRoot = statement.contentRoot;
        s.leafCount = kind == 1 ? 1 : statement.leafCount;
        s.contentRootSchemaId = statement.contentRootSchemaId;
        s.snapshotManifestHash = statement.snapshotManifestHash;
        s.referenceRenderManifestHash = statement.referenceRenderManifestHash;
        s.inputs = statement.inputs;
        s.nonSanctionComponents = statement.nonSanctionComponents;
        s.entropyPolicy = 1;
        s.postFreezePolicy = 1;
        s.sanctionPolicy = 1;
    }

    function _scopedFails(ScopedTypes.Statement memory s, bytes32 hash) private view {
        (bool ok,) = address(consumer).staticcall(abi.encodeCall(consumer.checkedScoped, (s, hash)));
        require(!ok, "scoped altered source rejected");
    }

    function _scopedShapeFails(ScopedTypes.Statement memory s) private view {
        (bool ok,) = address(consumer).staticcall(abi.encodeCall(consumer.encodedScoped, (s)));
        require(!ok, "scoped invalid shape cannot be rehashed into a valid envelope");
    }

    function testScopedLiteralEnvelopeAllSupportedScopesAndOriginalInputDomain() public {
        for (uint8 kind = 1; kind <= 3; ++kind) {
            ScopedTypes.Statement memory s = _scoped(kind);
            bytes memory raw = consumer.encodedScoped(s);
            require(
                keccak256(raw)
                    == keccak256(
                        abi.encode(
                            ScopedDocs.SCHEMA_ID,
                            ScopedDocs.CANON_ID,
                            block.chainid,
                            address(core),
                            address(metadata),
                            address(registry),
                            s
                        )
                    )
            );
            (bytes32 hash,) = store.publishChunk(raw);
            registry.stageFinalityManifest(raw);
            (bytes32 schema, bytes32 canon) = consumer.checkedScoped(s, hash);
            require(schema == ScopedDocs.SCHEMA_ID && canon == ScopedDocs.CANON_ID);
            require(
                consumer.scopedInputsHash(s)
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_FINALITY_SCOPE_INPUTS_V1"),
                            block.chainid,
                            address(core),
                            address(metadata),
                            s.scope,
                            s.inputs
                        )
                    )
            );
            require(keccak256(raw) != manifestHash, "separate collection and scoped interpretation");
        }
        require(
            keccak256(
                bytes(
                    vm.readFile(
                        "docs/schemas/preservation/scoped-finality-preservation-policy-input-manifest-v1.schema.json"
                    )
                )
            ) == keccak256(schemas.documentBytes(ScopedDocs.SCHEMA_ID))
        );
        require(
            keccak256(
                bytes(
                    vm.readFile(
                        "docs/schemas/preservation/scoped-finality-preservation-policy-input-manifest-v1.abi.json"
                    )
                )
            ) == keccak256(schemas.documentBytes(ScopedDocs.CANON_ID))
        );
    }

    function testScopedFullTuplePoliciesAndExactBothCopiesCannotBeBypassed() public {
        ScopedTypes.Statement memory s = _scoped(1);
        bytes memory raw = consumer.encodedScoped(s);
        (bytes32 hash,) = store.publishChunk(raw);
        _scopedFails(s, hash);
        registry.stageFinalityManifest(raw);
        consumer.checkedScoped(s, hash);
        ScopedTypes.Statement memory bad = abi.decode(abi.encode(s), (ScopedTypes.Statement));
        bad.scope.collectionId = 2;
        _scopedFails(bad, hash);
        bad = abi.decode(abi.encode(s), (ScopedTypes.Statement));
        bad.scope.scopeId = bytes32(uint256(1));
        _scopedShapeFails(bad);
        bad = abi.decode(abi.encode(s), (ScopedTypes.Statement));
        bad.scope.scopeType = StreamFinalityScopeType.COLLECTION;
        bad.scope.tokenId = 0;
        _scopedShapeFails(bad);
        for (uint256 i; i < 3; ++i) {
            bad = abi.decode(abi.encode(s), (ScopedTypes.Statement));
            if (i == 0) bad.entropyPolicy = 0;
            else if (i == 1) bad.postFreezePolicy = 2;
            else bad.sanctionPolicy = 0;
            _scopedShapeFails(bad);
        }
        bytes memory trailing = bytes.concat(raw, bytes32(0));
        (bytes32 alternate,) = store.publishChunk(trailing);
        registry.stageFinalityManifest(trailing);
        _scopedFails(s, alternate);
        consumer.checkedScoped(s, hash);
        _retire(ScopedDocs.CANON_ID);
        _scopedFails(s, hash);
        consumer.checked(statement, manifestHash);
    }

    function testV2FamilyRetainsNeutralEnvelopeAndOriginalRegistryInputDomain() public {
        StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s = statement;
        s.entropy.snapshotProfileHash = SnapshotDefinitionsV2.PROFILE_HASH;
        s.entropy.referenceProfileHash = ReferenceDefinitionsV2.PROFILE_HASH;
        bytes memory raw = consumer.encodedFamily(s, Families.V2);
        require(keccak256(raw) != manifestHash, "actual V2 profile hashes change bytes");
        require(_word(raw, 0) == SCHEMA && _word(raw, 1) == CANON, "neutral envelope retained");
        require(
            consumer.inputsHash(s) == consumer.inputsHash(statement), "Registry domain retained"
        );
        (bytes32 hash,) = store.publishChunk(raw);
        (bool ok,) = address(consumer)
            .staticcall(abi.encodeCall(consumer.checkedFamily, (s, hash, Families.V2)));
        require(!ok, "V2 still requires original Registry staging");
        registry.stageFinalityManifest(raw);
        (bytes32 schema, bytes32 canon) = consumer.checkedFamily(s, hash, Families.V2);
        require(schema == SCHEMA && canon == CANON, "same registered interpretation");
        _checkFails(s, hash);
        consumer.checked(statement, manifestHash);
    }

    function testV2FamilyRequiresBothExactProfileHashesAndRejectsUnknownFamilies() public view {
        StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s = statement;
        for (uint256 i; i < 5; ++i) {
            s = statement;
            bytes32 family = Families.V2;
            if (i == 1) s.entropy.snapshotProfileHash = SnapshotDefinitionsV2.PROFILE_HASH;
            if (i == 2) s.entropy.referenceProfileHash = ReferenceDefinitionsV2.PROFILE_HASH;
            if (i >= 3) {
                s.entropy.snapshotProfileHash = SnapshotDefinitionsV2.PROFILE_HASH;
                s.entropy.referenceProfileHash = ReferenceDefinitionsV2.PROFILE_HASH;
                family = i == 3 ? bytes32(0) : keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_V1");
            }
            (bool ok,) =
                address(consumer).staticcall(abi.encodeCall(consumer.encodedFamily, (s, family)));
            require(!ok, "mixed or unknown family rejected before hashing");
        }
        s = statement;
        s.entropy.snapshotProfileHash = SnapshotDefinitionsV2.PROFILE_HASH;
        s.entropy.referenceProfileHash = ReferenceDefinitionsV2.PROFILE_HASH;
        _shapeFails(s);
        consumer.encodedFamily(s, Families.V2);
        require(keccak256(consumer.encodedFamily(statement, Families.V1)) == manifestHash);
    }

    function testV2FamilyCannotBypassRetiredDefinitionsOrCanonicalBytes() public {
        StreamFinalityPreservationPolicyInputManifestTypesV1.Statement memory s = statement;
        s.entropy.snapshotProfileHash = SnapshotDefinitionsV2.PROFILE_HASH;
        s.entropy.referenceProfileHash = ReferenceDefinitionsV2.PROFILE_HASH;
        bytes memory raw = consumer.encodedFamily(s, Families.V2);
        bytes memory trailing = bytes.concat(raw, bytes32(0));
        (bytes32 bad,) = store.publishChunk(trailing);
        registry.stageFinalityManifest(trailing);
        (bool ok,) = address(consumer)
            .staticcall(abi.encodeCall(consumer.checkedFamily, (s, bad, Families.V2)));
        require(!ok, "canonical V2 envelope only");
        (bytes32 hash,) = store.publishChunk(raw);
        registry.stageFinalityManifest(raw);
        consumer.checkedFamily(s, hash, Families.V2);
        _retire(CANON);
        (ok,) = address(consumer)
            .staticcall(abi.encodeCall(consumer.checkedFamily, (s, hash, Families.V2)));
        require(!ok, "V2 respects actual registered definition status");
    }

    function testOriginalPolicySchemasCannotBeRelabeledAsPreservationEvidence() public {
        bytes memory oldCollection = abi.encode(
            keccak256("6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_V2"),
            keccak256("6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_ABI_V2"),
            block.chainid,
            address(core),
            address(metadata),
            address(registry),
            statement
        );
        (bytes32 oldHash,) = store.publishChunk(oldCollection);
        registry.stageFinalityManifest(oldCollection);
        _checkFails(statement, oldHash);
        consumer.checked(statement, manifestHash);
        ScopedTypes.Statement memory s = _scoped(2);
        bytes memory raw = consumer.encodedScoped(s);
        (bytes32 hash,) = store.publishChunk(raw);
        registry.stageFinalityManifest(raw);
        consumer.checkedScoped(s, hash);
        bytes memory oldScoped = abi.encode(
            keccak256("6529STREAM_SCOPED_POLICY_FINALITY_INPUT_MANIFEST_V2"),
            keccak256("6529STREAM_SCOPED_POLICY_FINALITY_INPUT_MANIFEST_ABI_V2"),
            block.chainid,
            address(core),
            address(metadata),
            address(registry),
            s
        );
        (oldHash,) = store.publishChunk(oldScoped);
        registry.stageFinalityManifest(oldScoped);
        _scopedFails(s, oldHash);
        consumer.checkedScoped(s, hash);
    }
}
