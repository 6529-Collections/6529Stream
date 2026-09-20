// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import {
    StreamFullV1StaticRendererPlan
} from "../../script/current/StreamFullV1StaticRendererPlan.sol";
import {
    StreamRendererRegistryModule
} from "../../smart-contracts/domains/metadata/StreamRendererRegistryModule.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import {
    IStreamRenderer as Render
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as Versions
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamStaticMetadataRouter as StaticRouter
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamStaticMetadataSource as StaticSource
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataSource.sol";
import {
    IStreamStaticEntropySource
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import { IStreamCoreMint } from "../../smart-contracts/interfaces/stream/core/IStreamCoreMint.sol";
import {
    StreamStaticRenderEncoding
} from "../../smart-contracts/domains/metadata/StreamStaticRenderEncoding.sol";

/// @notice Original current renderer/attribution/registry constructors and Safe activation.
/// @dev Analysis/schema/manifest documents below are explicitly synthetic fixture evidence,
/// retained by the real SchemaRegistry. The partial direct-read inventory and self-derived
/// empty-source golden test joins/refusals only: no performed opcode/transitive-read review,
/// complete normative golden inventory, current-token render, or executed acceptance claim.
/// Inherited upstream entropy is the sole service double; governance and all hosts are real.
contract StreamCurrentStaticGenesisTest is StreamCurrentStackFixture, OfficialSafeFixture {
    StreamFullV1StaticRendererPlan.Configuration private configuration;
    StreamFullV1StaticRendererPlan.Products private rendering;
    Versions.Registration private registration;
    Versions.Read[] private declaredReads;
    OfficialSafe private governor;
    OfficialSafe private otherSafe;
    uint256[] private keys;
    bytes32 private versionKey;

    function setUp() public {
        keys.push(0x652901);
        keys.push(0x652902);
        SafeComponents memory safe = deploySafeComponents("1.4.1");
        governor = createOfficialSafe(safe, safeOwnerAddresses(keys), 2, 3723);
        otherSafe = createOfficialSafe(safe, safeOwnerAddresses(keys), 2, 3724);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _installGovernor();
        _constructOriginalRenderer();
        _extendCatalog();
        _registerModules();
        _fixtureDocuments();
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](2);
        rows[0] = _policy(address(assemblySchemas), assemblySchemas.registerDocument.selector);
        rows[1] = _policy(address(assemblyMetadata), assemblyMetadata.setFamilyWriter.selector);
    }

    function testOriginalConstructorBindingsAndRetainedFixtureEvidence() public view {
        StreamFullV1StaticRendererPlan.validate(configuration, rendering);
        require(
            rendering.attribution.artist() == address(artists)
                && rendering.attribution.originalFinality() == address(assemblyFinality),
            "original artist and finality sources"
        );
        require(
            rendering.versions.schemaRegistry() == address(assemblySchemas),
            "original schema registry"
        );
        require(rendering.versions.versionCount() == 0, "construction is not admission");
        require(
            keccak256(assemblySchemas.documentBytes(registration.manifestDocument))
                == configuration.rendererManifest.manifestHash,
            "retained manifest bytes"
        );
        require(
            keccak256(assemblySchemas.documentBytes(registration.schemaDocument))
                == configuration.rendererManifest.schemaHash,
            "retained schema bytes"
        );
        StreamModuleRegistration[] memory rows =
            StreamFullV1StaticRendererPlan.registrations(configuration, rendering, 500000);
        for (uint256 i; i < rows.length; ++i) {
            StreamModuleRecord memory row = registry.moduleRecord(rows[i].module);
            require(
                row.status == ModuleRegistryStatus.ACTIVE && row.interfaceId == rows[i].interfaceId
                    && row.runtimeCodeHash == rows[i].expectedRuntimeCodeHash,
                "original module admission"
            );
        }
    }

    function testActualSafeSchedulesOriginalRegistryAndGoldenRead() public {
        _expectSafeFailure(
            governor,
            address(rendering.versions),
            abi.encodeCall(rendering.versions.registerRenderer, (registration, declaredReads))
        );
        _admit(registration);
        Versions.Version memory version = rendering.versions.version(versionKey);
        require(
            version.exists && !version.deprecated
                && version.renderer == address(rendering.renderer),
            "actual original version"
        );
        require(
            version.actionId != 0 && version.runtimeHash == address(rendering.renderer).codehash,
            "executed action and original runtime"
        );
        Versions.GoldenVector[] memory vectors = abi.decode(
            assemblySchemas.documentBytes(registration.goldenDocument), (Versions.GoldenVector[])
        );
        require(
            keccak256(bytes(rendering.renderer.tokenURI(vectors[0].request)))
                == vectors[0].outputHash,
            "actual retained fixture golden executed"
        );
    }

    function testSafeDefaultAndFreshCollectionActivationUseExplicitMetadataWriter() public {
        _admit(registration);
        StaticRouter.ConfigInput memory input = _input();
        _expectSafeFailure(
            governor, address(router), abi.encodeCall(router.setDefaultMetadataConfig, (input))
        );
        _grantWriter();
        _expectSafeFailure(
            otherSafe, address(router), abi.encodeCall(router.setDefaultMetadataConfig, (input))
        );
        require(
            executeSafe(
                governor,
                keys,
                address(router),
                0,
                abi.encodeCall(router.setDefaultMetadataConfig, (input)),
                0
            ),
            "explicit Safe default writer"
        );
        StaticRouter.ConfigRecord memory initial = router.defaultMetadataConfig();
        require(
            initial.recordHash != 0 && initial.selection.registry == address(rendering.versions)
                && initial.selection.renderer == address(rendering.renderer),
            "original selection retained"
        );
        (GovernanceCall memory operation, bytes memory data) =
            StreamCurrentStackPlan.createCollectionCall(core, 2, 5);
        _executeStage(_single(operation, data), keccak256("new pre-ratification collection"));
        _expectSafeFailure(
            governor,
            address(router),
            abi.encodeCall(router.activateStaticMetadata, (uint256(1), initial.recordHash))
        );
        require(
            executeSafe(
                governor,
                keys,
                address(router),
                0,
                abi.encodeCall(router.activateStaticMetadata, (uint256(2), initial.recordHash)),
                0
            ),
            "fresh actual Core scope activated"
        );
        (bytes32 activated, uint64 revision,) = router.staticMetadataActivation(2);
        require(
            activated == initial.recordHash && revision == initial.revision,
            "activation retains original default"
        );
        StaticRouter.ConfigRecord memory selected = router.collectionMetadataConfig(2);
        StaticRouter.Authorization memory authorization =
            router.metadataConfigAuthorization(selected.recordHash);
        require(
            authorization.actor == address(governor) && authorization.authorityClass == 8
                && authorization.metadata == address(assemblyMetadata),
            "actual Safe and original writer proof"
        );
        input.config.mode = Render.MetadataMode.HYBRID;
        input.config.baseURI = "https://fixture.invalid/changed-default/";
        require(
            executeSafe(
                governor,
                keys,
                address(router),
                0,
                abi.encodeCall(router.setDefaultMetadataConfig, (input)),
                0
            ),
            "new default for future scopes"
        );
        require(
            router.collectionMetadataConfig(2).recordHash == selected.recordHash,
            "later defaults preserve activated collection"
        );
    }

    function testWrongGoldenRollsBackAdmissionThenOriginalDocumentsRetry() public {
        Versions.GoldenVector[] memory vectors = abi.decode(
            assemblySchemas.documentBytes(registration.goldenDocument), (Versions.GoldenVector[])
        );
        vectors[0].outputHash = keccak256("wrong fixture bytes");
        Versions.Registration memory changed = registration;
        changed.goldenDocument = _document(
            "GENESIS_WRONG_GOLDEN_FIXTURE_V1", Schema.DocumentKind.CATALOG, abi.encode(vectors)
        );
        vm.expectRevert();
        this.admit(changed);
        require(
            rendering.versions.versionCount() == 0
                && !rendering.versions.version(versionKey).exists,
            "failed golden leaves no registration"
        );
        _admit(registration);
        require(rendering.versions.version(versionKey).exists, "original retained documents retry");
    }

    function testPlannerRejectsMissingDirectTargetAndChangedDeploymentFacts() public {
        Versions.Target[] memory targets = _targets();
        for (uint256 i; i < targets.length; ++i) {
            if (targets[i].target == address(core)) {
                targets[i].role = keccak256("METADATA_COMPANION");
            }
        }
        StreamFullV1StaticRendererPlan.Products memory beforeRegistry = rendering;
        beforeRegistry.versions = StreamRendererRegistryModule(address(0));
        beforeRegistry.registryCodeHash = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFullV1StaticRendererPlan.MissingStaticReadTarget.selector, address(core)
            )
        );
        this.deployRegistry(beforeRegistry, targets);
        StreamFullV1StaticRendererPlan.Products memory changed = rendering;
        changed.rendererCodeHash = keccak256("wrong runtime observation");
        vm.expectRevert(
            abi.encodeWithSelector(StreamFullV1StaticRendererPlan.InvalidStaticComposition.selector)
        );
        this.validate(changed);
        StreamFullV1StaticRendererPlan.validate(configuration, rendering);
    }

    function testOriginalSourceRuntimeDriftFailsValidation() public {
        vm.etch(address(core), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(StreamFullV1StaticRendererPlan.InvalidStaticComposition.selector)
        );
        this.validate(rendering);
    }

    function _constructOriginalRenderer() private {
        configuration.core = address(core);
        configuration.executor = address(executor);
        configuration.router = address(router);
        configuration.metadata = address(assemblyMetadata);
        configuration.schemas = address(assemblySchemas);
        configuration.entropy = address(entropy);
        configuration.artist = address(artists);
        configuration.finality = address(assemblyFinality);
        configuration.deploymentHash = DEPLOYMENT_HASH;
        configuration.registryManifestURI = "urn:fixture:original-renderer-registry";
        configuration.registryManifestHash = keccak256("fixture renderer registry manifest");
        configuration.rendererManifest = Render.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256(_schema()),
            "urn:fixture:renderer-output-schema",
            "urn:fixture:renderer-manifest",
            keccak256(_manifestDocument()),
            16777216,
            16777216,
            false
        );
        configuration.readGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        configuration.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        configuration.goldenGas = IStreamGasParameterHost.GasParameterConfig(
            "RENDERER_GOLDEN_VECTOR_GAS", 20000000, 100000, 2
        );
        rendering = StreamFullV1StaticRendererPlan.deployRenderer(configuration);
        rendering =
            StreamFullV1StaticRendererPlan.deployRegistry(configuration, rendering, _targets());
        versionKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_VERSION_V1"),
                configuration.rendererManifest.rendererId,
                configuration.rendererManifest.rendererVersion
            )
        );
        _directReads();
    }

    /// @dev Partial direct fixture inventory, deliberately not a transitive analysis report.
    function _targets() private view returns (Versions.Target[] memory targets) {
        (address encoding,) = rendering.renderer.encodingBinding();
        targets = new Versions.Target[](6);
        targets[0] = Versions.Target(address(core), address(core).codehash, keccak256("CORE"));
        targets[1] = Versions.Target(
            address(assemblyMetadata),
            address(assemblyMetadata).codehash,
            keccak256("COLLECTION_METADATA")
        );
        targets[2] = Versions.Target(
            address(router), address(router).codehash, keccak256("METADATA_COMPANION")
        );
        targets[3] = Versions.Target(
            address(entropy), address(entropy).codehash, keccak256("ENTROPY_COORDINATOR")
        );
        targets[4] = Versions.Target(
            address(rendering.attribution),
            address(rendering.attribution).codehash,
            keccak256("METADATA_COMPANION")
        );
        targets[5] = Versions.Target(encoding, encoding.codehash, keccak256("METADATA_COMPANION"));
        for (uint256 i = 1; i < targets.length; ++i) {
            for (uint256 j = i; j > 0 && targets[j - 1].target > targets[j].target; --j) {
                (targets[j - 1], targets[j]) = (targets[j], targets[j - 1]);
            }
        }
    }

    function _directReads() private {
        Versions.Target[] memory targets = _targets();
        for (uint16 i; i < targets.length; ++i) {
            address target = targets[i].target;
            if (target == address(core)) {
                declaredReads.push(
                    Versions.Read(i, IStreamCoreMint.tokenData.selector, 16448, false)
                );
            } else if (target == address(assemblyMetadata)) {
                declaredReads.push(Versions.Read(i, StaticSource.staticBundle.selector, 384, true));
                declaredReads.push(
                    Versions.Read(i, StaticSource.staticBundleChunk.selector, 128, true)
                );
                declaredReads.push(
                    Versions.Read(i, StaticSource.staticScriptManifest.selector, 9504, false)
                );
            } else if (target == address(router)) {
                declaredReads.push(
                    Versions.Read(
                        i, StaticRouter.staticRenderSourceForConfig.selector, 20736, false
                    )
                );
            } else if (target == address(entropy)) {
                declaredReads.push(
                    Versions.Read(
                        i, IStreamStaticEntropySource.staticTokenRenderFacts.selector, 96, true
                    )
                );
            } else if (target == address(rendering.attribution)) {
                declaredReads.push(
                    Versions.Read(i, rendering.attribution.attribution.selector, 32832, false)
                );
            } else {
                declaredReads.push(
                    Versions.Read(i, StreamStaticRenderEncoding.render.selector, 16777216, false)
                );
            }
        }
        for (uint256 i = 1; i < declaredReads.length; ++i) {
            for (
                uint256 j = i;
                j > 0 && _readOrder(declaredReads[j - 1]) > _readOrder(declaredReads[j]);
                --j
            ) {
                Versions.Read memory previous = declaredReads[j - 1];
                declaredReads[j - 1] = declaredReads[j];
                declaredReads[j] = previous;
            }
        }
    }

    function _readOrder(Versions.Read memory read) private pure returns (uint256) {
        return (uint256(read.targetIndex) << 32) | uint32(read.selector);
    }

    function _fixtureDocuments() private {
        if (!assemblySchemas.document(assemblySchemas.RAW_BYTES()).exists) {
            _document(
                "RAW_BYTES",
                Schema.DocumentKind.CANONICALIZATION,
                bytes(assemblySchemas.RAW_BYTES_DEFINITION())
            );
        }
        registration.renderer = address(rendering.renderer);
        registration.manifest = configuration.rendererManifest;
        registration.schemaDocument =
            _document("GENESIS_RENDERER_SCHEMA_FIXTURE_V1", Schema.DocumentKind.SCHEMA, _schema());
        registration.contextDocument = _document(
            "STREAM_CONTEXT_V1",
            Schema.DocumentKind.SCHEMA,
            bytes("{\"fixture\":true,\"name\":\"STREAM_CONTEXT_V1\"}")
        );
        registration.manifestDocument = _document(
            "GENESIS_RENDERER_MANIFEST_FIXTURE_V1", Schema.DocumentKind.CATALOG, _manifestDocument()
        );
        Versions.Analysis memory analysis = Versions.Analysis(
            rendering.versions.ANALYSIS_PROFILE(),
            address(rendering.renderer),
            address(rendering.renderer).codehash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                    rendering.versions.targetSetHash(),
                    declaredReads
                )
            ),
            registration.manifest.rendererVersion,
            registration.manifest.contextVersion,
            registration.manifest.schemaHash,
            keccak256("SYNTHETIC FIXTURE: no analysis tool executed"),
            keccak256("SYNTHETIC FIXTURE: partial direct reads, not a conformance report"),
            true
        );
        registration.analysisDocument = _document(
            "GENESIS_ANALYSIS_JOIN_FIXTURE_V1", Schema.DocumentKind.CATALOG, abi.encode(analysis)
        );
        Versions.GoldenVector[] memory vectors = new Versions.GoldenVector[](1);
        vectors[0].request.core = address(core);
        vectors[0].request.mode = Render.MetadataMode.ONCHAIN;
        vectors[0].outputHash = keccak256(bytes(rendering.renderer.tokenURI(vectors[0].request)));
        registration.goldenDocument = _document(
            "GENESIS_EMPTY_GOLDEN_FIXTURE_V1", Schema.DocumentKind.CATALOG, abi.encode(vectors)
        );
    }

    function _schema() private pure returns (bytes memory) {
        return bytes(
            "{\"fixture\":true,\"type\":\"object\",\"purpose\":\"current renderer admission join\"}"
        );
    }

    function _manifestDocument() private pure returns (bytes memory) {
        return bytes(
            "{\"fixture\":true,\"renderer\":\"6529STREAM_STATIC_RENDERER_V1\",\"reviewed\":false}"
        );
    }

    function _document(string memory name, Schema.DocumentKind kind, bytes memory payload)
        private
        returns (bytes32 id)
    {
        (bytes32 hash,) = assemblyStore.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        Schema.DocumentSpec memory spec = Schema.DocumentSpec(
            name, kind, hash, assemblySchemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblySchemas.registrationTransition(spec, chunks);
        bytes memory data = abi.encodeCall(assemblySchemas.registerDocument, (spec, chunks));
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(address(assemblySchemas), data, scope, previous, next),
                data
            ),
            keccak256(bytes(name))
        );
        id = keccak256(bytes(name));
        require(
            keccak256(assemblySchemas.documentBytes(id)) == hash, "exact original document bytes"
        );
    }

    function _admit(Versions.Registration memory item) private {
        (GovernanceCall memory operation, bytes memory data) =
            StreamFullV1StaticRendererPlan.admission(configuration, rendering, item, declaredReads);
        _executeStage(
            _single(operation, data),
            keccak256(abi.encode("fixture original renderer admission", item.goldenDocument))
        );
    }

    function _grantWriter() private {
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1");
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblyMetadata.familyWriterTransition(0, family, 8, address(governor), true);
        bytes memory data = abi.encodeCall(
            assemblyMetadata.setFamilyWriter,
            (uint256(0), family, uint8(8), address(governor), true)
        );
        _executeStage(
            _single(
                StreamCurrentStackPlan.call(address(assemblyMetadata), data, scope, previous, next),
                data
            ),
            keccak256("explicit Safe static default writer")
        );
    }

    function _input() private view returns (StaticRouter.ConfigInput memory) {
        return StaticRouter.ConfigInput(
            address(rendering.versions),
            versionKey,
            Render.MetadataConfig(
                Render.MetadataMode.ONCHAIN,
                address(rendering.renderer),
                "",
                "",
                Render.OffchainURIIdMode.TOKEN_ID,
                false
            )
        );
    }

    function _extendCatalog() private {
        GovernanceActionPolicyEntry[] memory rows =
            StreamFullV1StaticRendererPlan.operatingPolicies(configuration, rendering);
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(executor, rows);
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("renderer policies");
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            manifest,
            payload,
            update
        );
        _executeStage(batch, keccak256("original renderer catalog"));
        require(count == rows.length, "complete bounded policy addition");
    }

    function _registerModules() private {
        (GovernanceCall[] memory calls, bytes[] memory datas) = StreamCurrentStackPlan.registrationCalls(
            registry, StreamFullV1StaticRendererPlan.registrations(configuration, rendering, 500000)
        );
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](calls.length + 1);
        batch.callDatas = new bytes[](calls.length + 1);
        for (uint256 i; i < calls.length; ++i) {
            batch.calls[i] = calls[i];
            batch.callDatas[i] = datas[i];
        }
        (address payload, StreamSystemManifestUpdate memory update) =
            _publication("original renderer hosts");
        (batch.calls[calls.length], batch.callDatas[calls.length]) =
            StreamGenesisManifestPlan.publicationCall(
                manifest, payload, update, StreamGenesisManifestPlan.readAggregate(manifest).modules
            );
        _executeStage(batch, keccak256("original renderer module rows"));
    }

    function _publication(string memory purpose)
        private
        returns (address payload, StreamSystemManifestUpdate memory update)
    {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        bytes32 hash;
        (payload, hash) = StreamGenesisManifestPlan.writePayload(
            bytes(string.concat("{\"fixture\":true,\"purpose\":\"", purpose, "\"}"))
        );
        update = StreamSystemManifestUpdate(
            hash,
            "urn:fixture:static-genesis",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
    }

    function _single(GovernanceCall memory operation, bytes memory data)
        private
        pure
        returns (GenesisBatch memory batch)
    {
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] = operation;
        batch.callDatas[0] = data;
    }

    function _policy(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1, target, selector, target.codehash, DEPLOYMENT_HASH, 1, 0, 0, bytes32(0)
        );
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }

    function _expectSafeFailure(OfficialSafe account, address target, bytes memory data) private {
        uint256 nonce = account.nonce();
        vm.expectRevert();
        this.safeCall(account, target, data);
        require(account.nonce() == nonce, "Safe nonce rolls back");
    }

    function safeCall(OfficialSafe account, address target, bytes memory data)
        external
        returns (bool)
    {
        return executeSafe(account, keys, target, 0, data, 0);
    }

    function admit(Versions.Registration memory item) external {
        _admit(item);
    }

    function validate(StreamFullV1StaticRendererPlan.Products memory products) external view {
        StreamFullV1StaticRendererPlan.validate(configuration, products);
    }

    function deployRegistry(
        StreamFullV1StaticRendererPlan.Products memory products,
        Versions.Target[] memory targets
    ) external {
        StreamFullV1StaticRendererPlan.deployRegistry(configuration, products, targets);
    }

    function _installGovernor() private {
        (address prior, bytes32 hash, uint64 revision) = executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(governor), address(governor).codehash)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(3));
        GovernanceActionRequest memory request = GovernanceActionRequest(
            3,
            address(executor),
            0,
            executor.rotateGovernanceRoot.selector,
            data,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"),
                    block.chainid,
                    address(executor)
                )
            ),
            _rootState(prior, hash, revision),
            _rootState(address(governor), address(governor).codehash, revision + 1),
            ready,
            ready + 7 days,
            keccak256("full-v1 actual Safe root"),
            "urn:6529stream:genesis:Safe-root",
            DEPLOYMENT_HASH
        );
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(ready);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
    }

    function _rootState(address root, bytes32 hash, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_STATE_V1"),
                block.chainid,
                address(executor),
                root,
                hash,
                revision
            )
        );
    }

    function _executeStage(GenesisBatch memory batch, bytes32 stage) private {
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(batch.actionClass));
        StreamGovernanceStagePlan.Plan memory plan = StreamGovernanceStagePlan.build(
            executor,
            stage,
            batch,
            ready,
            ready + 7 days,
            stage,
            "urn:6529stream:genesis:composed-stage",
            DEPLOYMENT_HASH
        );
        bytes32 saved = StreamGovernanceStagePlan.planHash(plan);
        executor.publishGovernanceCallData(batch.callDatas);
        StreamGovernanceStagePlan.NextCall memory next =
            StreamGovernanceStagePlan.scheduling(plan, saved);
        vm.recordLogs();
        require(
            executeSafe(governor, keys, next.target, next.value, next.data, 0),
            "real Safe schedules"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        bytes32 action;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(action == 0, "one observed action");
                action = logs[i].topics[1];
            }
        }
        require(action != 0, "actual receipt action ID");
        if (ready > block.timestamp) {
            (bool early,) =
                address(this).call(abi.encodeCall(this.executeSaved, (plan, action, saved)));
            require(!early, "execution before delay rejected");
            vm.warp(ready);
        }
        require(
            StreamGovernanceStagePlan.execute(plan, action, saved),
            "permissionless delayed execution"
        );
    }

    function executeSaved(StreamGovernanceStagePlan.Plan memory plan, bytes32 action, bytes32 saved)
        external
        returns (bool)
    {
        return StreamGovernanceStagePlan.execute(plan, action, saved);
    }
}
