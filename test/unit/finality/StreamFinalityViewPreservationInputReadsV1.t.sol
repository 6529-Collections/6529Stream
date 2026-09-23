// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationInputReadsV1.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";

/// @dev Explicit governance action-context boundary; this is not the actual Executor.
contract ViewInputManifestGovernanceBoundary {
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
contract ViewInputManifestGraphBoundary {
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
contract ViewInputManifestConsumerBoundary {
    StreamFinalityViewPreservationInputReadsV1.Dependencies private d;

    constructor(address[5] memory targets) {
        d.targets = targets;
        d.chainId = block.chainid;
        d.readGas = 500000;
        for (uint256 i; i < 5; ++i) {
            d.codeHashes[i] = targets[i].codehash;
        }
    }

    function encoded(StreamFinalityViewPreservationInputTypesV1.Statement memory s)
        external
        view
        returns (bytes memory)
    {
        return StreamFinalityViewPreservationInputReadsV1.encode(d, s);
    }

    function checked(StreamFinalityViewPreservationInputTypesV1.Statement memory s, bytes32 hash)
        external
        view
        returns (bytes32, bytes32)
    {
        return StreamFinalityViewPreservationInputReadsV1.requireCurrent(d, s, hash);
    }

    function inputsHash(StreamFinalityViewPreservationInputTypesV1.Statement memory s)
        external
        view
        returns (bytes32)
    {
        return StreamFinalityViewPreservationInputReadsV1.scopeInputsHash(d, s);
    }
}

contract StreamFinalityViewPreservationInputReadsV1Test is
    CharacterizationTestBase,
    OfficialSafeFixture
{
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    ViewInputManifestGovernanceBoundary private governance;
    ViewInputManifestGraphBoundary private core;
    ViewInputManifestGraphBoundary private metadata;
    ViewInputManifestGraphBoundary private registry;
    ViewInputManifestConsumerBoundary private consumer;
    StreamFinalityViewPreservationInputTypesV1.Statement private statement;
    bytes32 private manifestHash;
    uint256 private originalChainId;
    bytes32 private constant SCHEMA = keccak256("STREAM_VIEW_PRESERVATION_FINALITY_INPUT_V1");
    bytes32 private constant CANON = keccak256("STREAM_VIEW_PRESERVATION_FINALITY_INPUT_ABI_V1");

    function setUp() public {
        originalChainId = block.chainid;
        governance = new ViewInputManifestGovernanceBoundary();
        schemas = new StreamSchemaRegistry(address(governance));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        core = new ViewInputManifestGraphBoundary();
        metadata = new ViewInputManifestGraphBoundary();
        registry = new ViewInputManifestGraphBoundary();
        metadata.configure(address(core), address(schemas), address(metadata));
        registry.configure(address(core), address(schemas), address(metadata));
        consumer = new ViewInputManifestConsumerBoundary(
            [address(core), address(metadata), address(schemas), address(store), address(registry)]
        );
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "STREAM_VIEW_PRESERVATION_FINALITY_INPUT_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamFinalityViewPreservationInputSchemasV1.document(SCHEMA)
        );
        _register(
            "STREAM_VIEW_PRESERVATION_FINALITY_INPUT_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            StreamFinalityViewPreservationInputSchemasV1.document(CANON)
        );
        statement.scope = StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 1, 0, keccak256("actual sealed membership")
        );
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
        statement.entropy = StreamFinalityViewPreservationInputTypesV1.Entropy(
            address(0x1234),
            keccak256("sourceSet runtime"),
            keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"),
            keccak256("complete plan"),
            keccak256("complete inventory"),
            keccak256("full ordered policy chain"),
            2,
            SnapshotDefinitions.PROFILE_HASH,
            ReferenceDefinitions.PROFILE_HASH
        );
        statement.completeBindingRecordHash = keccak256("actual complete binding");
        statement.adoptionRecordHash = keccak256("actual tagged adoption");
        statement.adoptionProfile = keccak256("6529STREAM_STATIC_ADOPTED_POLICY_VIEW_V2");
        statement.outputProfile = keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1");
        statement.membershipHash = keccak256("complete membership");
        statement.rootBindingHash = keccak256("full28-word root binding");
        statement.viewId = keccak256("separate declared view");
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
        StreamFinalityViewPreservationInputTypesV1.Statement memory s,
        bytes32 hash
    ) private view {
        (bool ok,) = address(consumer).staticcall(abi.encodeCall(consumer.checked, (s, hash)));
        require(!ok, "must reject");
    }

    function _shapeFails(StreamFinalityViewPreservationInputTypesV1.Statement memory s) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityViewPreservationInputReadsV1.InvalidInputManifest.selector
            )
        );
        consumer.encoded(s);
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
        StreamFinalityViewPreservationInputTypesV1.Statement memory s = statement;
        s.coreFactsHash = keccak256("new actual supply facts");
        bytes memory payload = consumer.encoded(s);
        (bytes32 hash,) = store.publishChunk(payload);
        _checkFails(s, hash);
        registry.stageFinalityManifest(payload);
        consumer.checked(s, hash);
    }

    function testOriginalRegistryStagingDoesNotSubstituteForStoreRetention() public {
        StreamFinalityViewPreservationInputTypesV1.Statement memory s = statement;
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

    function testMissingOrWrongDefinitionCannotUseSameNamedProfile() public {
        StreamSchemaRegistry alternate = new StreamSchemaRegistry(address(governance));
        StreamSchemaRegistry oldSchemas = schemas;
        StreamSchemaDocumentStore oldStore = store;
        schemas = alternate;
        store = StreamSchemaDocumentStore(alternate.chunkStore());
        metadata.configure(address(core), address(alternate), address(metadata));
        consumer = new ViewInputManifestConsumerBoundary(
            [
                address(core),
                address(metadata),
                address(alternate),
                address(store),
                address(registry)
            ]
        );
        bytes memory payload = consumer.encoded(statement);
        store.publishChunk(payload);
        _checkFails(statement, manifestHash);
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            "STREAM_VIEW_PRESERVATION_FINALITY_INPUT_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes("different meaning")
        );
        _register(
            "STREAM_VIEW_PRESERVATION_FINALITY_INPUT_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            StreamFinalityViewPreservationInputSchemasV1.document(CANON)
        );
        _checkFails(statement, manifestHash);
        schemas = oldSchemas;
        store = oldStore;
    }

    function testMissingDuplicateUnsortedOrSanctionComponentRejects() public {
        StreamFinalityViewPreservationInputTypesV1.Statement memory s = statement;
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

    function testIncompleteInputsWaiverAndUnsupportedPoliciesReject() public {
        StreamFinalityViewPreservationInputTypesV1.Statement memory s = statement;
        s.inputs.bundleCoverageHash = 0;
        _shapeFails(s);
        s = statement;
        s.inputs.renderCriticalEvidenceHash = 0;
        _shapeFails(s);
        s = statement;
        s.inputs.intentWaiverRecordHash = bytes32(uint256(9));
        _shapeFails(s);
        s = statement;
        s.inputs.intentRecordHash = 0;
        _shapeFails(s);
        s = statement;
        s.inputs.interviewEvidenceHash = 0;
        _shapeFails(s);
        s = statement;
        s.entropy.sourceSetProfile = bytes32(uint256(2));
        _shapeFails(s);
        s = statement;
        s.postFreezePolicy = 2;
        _shapeFails(s);
        s = statement;
        s.sanctionPolicy = 2;
        _shapeFails(s);
    }

    function testExplicitIntentWaiverAdmitsWithoutInventingAnInterviewRecord() public {
        StreamFinalityViewPreservationInputTypesV1.Statement memory s = statement;
        s.inputs.intentRecordHash = 0;
        s.inputs.intentWaiverRecordHash = keccak256("actual signed waiver");
        bytes memory payload = consumer.encoded(s);
        (bytes32 hash,) = store.publishChunk(payload);
        registry.stageFinalityManifest(payload);
        consumer.checked(s, hash);
        require(
            s.inputs.interviewEvidenceHash == statement.inputs.interviewEvidenceHash,
            "retained parent-bound status"
        );
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

    function testChangedChainReciprocalGraphOrRuntimeRejectAndRestore() public {
        bytes memory original = address(store).code;
        vm.etch(address(store), hex"00");
        _checkFails(statement, manifestHash);
        vm.etch(address(store), original);
        consumer.checked(statement, manifestHash);
        registry.configure(address(core), address(schemas), address(core));
        _checkFails(statement, manifestHash);
        registry.configure(address(core), address(schemas), address(metadata));
        consumer.checked(statement, manifestHash);
        vm.chainId(originalChainId + 1);
        _checkFails(statement, manifestHash);
        vm.chainId(originalChainId);
        require(block.chainid == originalChainId, "chain restored from storage");
        consumer.checked(statement, manifestHash);
    }

    function testFuzzChangedIndependentInputCannotReuseRetainedManifest(bytes32 replacement)
        public
    {
        StreamFinalityViewPreservationInputTypesV1.Statement memory s = statement;
        if (replacement == s.inputs.workDescriptionRecordHash || replacement == 0) return;
        s.inputs.workDescriptionRecordHash = replacement;
        _checkFails(s, manifestHash);
        bytes memory payload = consumer.encoded(s);
        (bytes32 hash,) = store.publishChunk(payload);
        registry.stageFinalityManifest(payload);
        consumer.checked(s, hash);
        require(hash != manifestHash, "changed independent evidence");
    }

    function testSafeCanRetainEncodeAndValidateExactDocument() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x111;
        keys[1] = 0x222;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 123);
        bytes memory payload = consumer.encoded(statement);
        require(
            executeSafe(
                account, keys, address(store), 0, abi.encodeCall(store.publishChunk, (payload)), 0
            ),
            "Safe Store retention"
        );
        require(
            executeSafe(
                account,
                keys,
                address(registry),
                0,
                abi.encodeCall(registry.stageFinalityManifest, (payload)),
                0
            ),
            "Safe fixture staging"
        );
        require(
            executeSafe(
                account,
                keys,
                address(consumer),
                0,
                abi.encodeCall(consumer.encoded, (statement)),
                0
            ),
            "Safe encoding"
        );
        require(
            executeSafe(
                account,
                keys,
                address(consumer),
                0,
                abi.encodeCall(consumer.checked, (statement, manifestHash)),
                0
            ),
            "Safe validated read"
        );
        require(
            executeSafe(
                account,
                keys,
                address(consumer),
                0,
                abi.encodeCall(consumer.inputsHash, (statement)),
                0
            ),
            "Safe permanent hash read"
        );
        consumer.checked(statement, manifestHash);
    }

    function testPortableDefinitionsAreExactRegisteredBytes() public view {
        require(
            keccak256(
                bytes(
                    vm.readFile("docs/schemas/finality/view-preservation-input-v1.definition.json")
                )
            ) == keccak256(schemas.documentBytes(SCHEMA)),
            "portable schema exact"
        );
        require(
            keccak256(
                bytes(
                    vm.readFile(
                        "docs/schemas/finality/view-preservation-input-abi-v1.definition.json"
                    )
                )
            ) == keccak256(schemas.documentBytes(CANON)),
            "portable ABI exact"
        );
    }

    function testFullPrecisionNumbersAndCanonicalViewScope() public {
        StreamFinalityViewPreservationInputTypesV1.Statement memory s = statement;
        s.scope.collectionId = type(uint256).max;
        s.leafCount = type(uint64).max;
        bytes memory payload = consumer.encoded(s);
        require(uint256(_word(payload, 8)) == type(uint256).max, "exact uint256 collection ID");
        require(uint256(_word(payload, 13)) == type(uint64).max, "exact uint64 count");
        (bytes32 hash,) = store.publishChunk(payload);
        registry.stageFinalityManifest(payload);
        consumer.checked(s, hash);
        s.scope.scopeType = StreamFinalityScopeType.TOKEN;
        s.scope.tokenId = 1;
        _shapeFails(s);
        s = statement;
        s.scope.tokenId = 1;
        _shapeFails(s);
    }

    function testInsufficientParentGasRejectsThenExactRetrySucceeds() public {
        bytes memory data = abi.encodeCall(consumer.checked, (statement, manifestHash));
        (bool ok,) = address(consumer).staticcall{ gas: 100000 }(data);
        require(!ok, "insufficient parent rejected");
        (ok,) = address(consumer).staticcall{ gas: 6000000 }(data);
        require(ok, "exact funded retry");
    }

    function testNewProfileAndAllBindingCoordinatesCannotBorrowRetainedBytes() public {
        StreamFinalityViewPreservationInputTypesV1.Statement memory s;
        for (uint256 i; i < 9; ++i) {
            s = statement;
            if (i == 0) s.completeBindingRecordHash = keccak256("different complete binding");
            else if (i == 1) s.adoptionRecordHash = keccak256("different adoption");
            else if (i == 2) s.membershipHash = keccak256("different membership");
            else if (i == 3) s.rootBindingHash = keccak256("different complete root binding");
            else if (i == 4) s.viewId = keccak256("different declared view");
            else if (i == 5) s.entropy.policyChainHash = keccak256("different H chain");
            else if (i == 6) s.scope.scopeId = keccak256("different same-view scope");
            else if (i == 7) s.adoptionProfile = keccak256("unversioned or old adopted profile");
            else s.outputProfile = keccak256("public live output is not preservation bytes");
            if (i >= 7) _shapeFails(s);
            else _checkFails(s, manifestHash);
            consumer.checked(statement, manifestHash);
        }
    }

    function testLiteralCompleteStatementAndOriginalInputCommitment() public view {
        bytes memory expected = abi.encode(
            keccak256("STREAM_VIEW_PRESERVATION_FINALITY_INPUT_V1"),
            keccak256("STREAM_VIEW_PRESERVATION_FINALITY_INPUT_ABI_V1"),
            originalChainId,
            address(core),
            address(metadata),
            address(registry),
            statement
        );
        require(
            keccak256(expected) == manifestHash
                && keccak256(expected) == keccak256(store.readChunk(manifestHash)),
            "literal complete original ABI preimage"
        );
        require(
            statement.scope.scopeId != statement.viewId,
            "declaration identity does not replace membership"
        );
    }
}
