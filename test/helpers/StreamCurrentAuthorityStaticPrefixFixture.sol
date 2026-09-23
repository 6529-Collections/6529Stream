// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityRecordPublicationFixture
} from "./StreamCurrentAuthorityRecordPublicationFixture.sol";
import {
    StreamFullV1StaticRendererPlan as StaticPlan
} from "../../script/current/StreamFullV1StaticRendererPlan.sol";
import {
    StreamCurrentStackPlan as StaticStackPlan
} from "../../script/current/StreamCurrentStackPlan.sol";
import {
    StreamGenesisManifestPlan as StaticManifestPlan
} from "../../script/current/StreamGenesisManifestPlan.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import {
    GovernanceCall
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    IStreamRenderer as StaticRender
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as StaticVersions
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamSchemaRegistry as StaticSchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamStaticMetadataRouter as StaticRouterAPI
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamStaticMetadataSource as StaticSourceAPI
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticMetadataSource.sol";
import {
    IStreamStaticEntropySource as StaticEntropyAPI
} from "../../smart-contracts/interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import {
    IStreamCoreMint as StaticMintAPI
} from "../../smart-contracts/interfaces/stream/core/IStreamCoreMint.sol";
import {
    IStreamCoreIdentity as StaticIdentityAPI
} from "../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamCoreCollectionView as StaticCollectionAPI
} from "../../smart-contracts/interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    IStreamGasParameterHost as StaticGas
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamCurrentCitationRegistry as StaticCitation
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamCurrentCitationRenderer as StaticCitationRenderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    StreamStaticRenderEncoding as StaticEncoding
} from "../../smart-contracts/domains/metadata/StreamStaticRenderEncoding.sol";
import {
    StreamOnchainContentBytes as StaticContentBytes
} from "../../smart-contracts/domains/finality/StreamOnchainContentBytes.sol";
import { Strings as StaticStrings } from "../../smart-contracts/vendor/openzeppelin/Strings.sol";
import { Base64 as StaticBase64 } from "../../smart-contracts/vendor/openzeppelin/Base64.sol";

/// @notice Actual renderer/registry and frozen STATIC activation before original Artist onboarding.
/// @dev Inherits only the genuine current-authority assembly, including its real Safe governance,
/// Artist, Core, mint and entropy paths. Admission schema/manifest/analysis and the pre-mint golden
/// below are explicit synthetic fixture evidence, not transitive opcode or renderer conformance.
/// CurrentCitation is separately admitted against a genuine paid/finalized token and literal JSON
/// insertion, before the original Core serving assertion. Runtime/gas/size remain unexecuted.
/// This helper does not change the already-pinned native reference catalog or claim scoped roots.
abstract contract StreamCurrentAuthorityStaticPrefixFixture is
    StreamCurrentAuthorityRecordPublicationFixture
{
    StaticPlan.Configuration internal assemblyStaticConfiguration;
    StaticPlan.Products internal assemblyStaticProducts;
    StaticVersions.Registration internal assemblyStaticRegistration;
    StaticVersions.Read[] internal assemblyStaticReads;
    bytes32 internal assemblyStaticVersion;
    bytes32 internal assemblyStaticDefault;
    StaticRouterAPI.ConfigRecord internal assemblyStaticCollection;
    bytes32 internal assemblyStaticCitation;

    function _beforeAssemblyArtistOnboarding() internal virtual override {
        super._beforeAssemblyArtistOnboarding();
        require(assemblyCore.collectionMintedEver(1) == 0, "STATIC activation precedes first mint");
        (bool ratified,,) = assemblyArtists.firstReleaseRatification(1);
        require(!ratified, "STATIC activation precedes first ratification");
        _staticPrefixDeploy();
        _staticPrefixRegisterModules();
        _staticPrefixDocuments();
        (GovernanceCall memory operation, bytes memory data) = StaticPlan.admission(
            assemblyStaticConfiguration,
            assemblyStaticProducts,
            assemblyStaticRegistration,
            assemblyStaticReads
        );
        _staticPrefixGovern(operation, data);
        (address admitted, bytes32 runtime) =
            assemblyStaticProducts.versions.requireAssignable(assemblyStaticVersion);
        require(
            admitted == address(assemblyStaticProducts.renderer)
                && runtime == assemblyStaticProducts.rendererCodeHash,
            "actual retained renderer admission"
        );
        _staticPrefixActivate();
        // Explicit ordinary 2x governed raises, matching the existing STATIC fixture frames.
        // These are source-authored budgets, not measured execution envelopes.
        _staticPrefixDoubleGas(
            address(assemblyRouter), keccak256("6529STREAM_GGP_ROUTER_BUNDLE_RENDER_GAS"), 8000000
        );
        _staticPrefixDoubleGas(
            address(assemblyCore),
            0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93,
            12000000
        );
    }

    function _afterAssemblyTokenFinalized(uint256 tokenId) internal virtual override {
        super._afterAssemblyTokenFinalized(tokenId);
        if (assemblyStaticCitation == 0) {
            require(
                tokenId == 1 && assemblyCore.totalSupply() == 1,
                "first genuine finalized paid token"
            );
            _staticPrefixAdmitCitation(tokenId);
        }
        _assemblyStaticRequireServing(tokenId);
    }

    function _staticPrefixDeploy() private {
        StaticPlan.Configuration memory c;
        c.core = address(assemblyCore);
        c.executor = address(assemblyExecutor);
        c.router = address(assemblyRouter);
        c.metadata = address(assemblyMetadata);
        c.schemas = address(assemblySchemas);
        c.entropy = address(assemblyEntropy);
        c.artist = address(assemblyArtists);
        c.finality = address(assemblyFinality);
        c.deploymentHash = ASSEMBLY_DEPLOYMENT;
        c.registryManifestURI = "urn:fixture:current-authority-static-registry";
        c.registryManifestHash = keccak256("SYNTHETIC FIXTURE: renderer registry manifest");
        c.rendererManifest = StaticRender.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256(_staticPrefixSchema()),
            "urn:fixture:current-authority-renderer-schema",
            "urn:fixture:current-authority-renderer-manifest",
            keccak256(_staticPrefixManifest()),
            16777216,
            16777216,
            false
        );
        c.readGas = StaticGas.GasParameterConfig("METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2);
        c.attributionGas =
            StaticGas.GasParameterConfig("STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1);
        c.goldenGas =
            StaticGas.GasParameterConfig("RENDERER_GOLDEN_VECTOR_GAS", 20000000, 100000, 2);
        assemblyStaticConfiguration = c;
        assemblyStaticProducts = StaticPlan.deployRenderer(c);
        assemblyStaticProducts =
            StaticPlan.deployRegistry(c, assemblyStaticProducts, _staticPrefixTargets());
        assemblyStaticVersion = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_VERSION_V1"),
                c.rendererManifest.rendererId,
                c.rendererManifest.rendererVersion
            )
        );
        _staticPrefixDirectReads();
    }

    function _staticPrefixRegisterModules() private {
        (GovernanceCall[] memory calls, bytes[] memory data) = StaticStackPlan.registrationCalls(
            assemblyModules,
            StaticPlan.registrations(assemblyStaticConfiguration, assemblyStaticProducts, 500000)
        );
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](calls.length + 1);
        batch.callDatas = new bytes[](calls.length + 1);
        for (uint256 i; i < calls.length; ++i) {
            batch.calls[i] = calls[i];
            batch.callDatas[i] = data[i];
        }
        (batch.calls[calls.length], batch.callDatas[calls.length]) = _assemblyPublication(
            StaticManifestPlan.readAggregate(assemblyManifest).modules,
            keccak256(abi.encode("actual STATIC renderer modules", assemblyStaticVersion))
        );
        _admitAssemblyBatch(batch);
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/current-authority/static-modules"
        );
    }

    function _staticPrefixActivate() private {
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1");
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblyMetadata.familyWriterTransition(0, family, 8, address(this), true);
        _assemblyGovernanceCall(
            1,
            address(assemblyMetadata),
            abi.encodeCall(
                assemblyMetadata.setFamilyWriter,
                (uint256(0), family, uint8(8), address(this), true)
            ),
            scope,
            previous,
            next
        );
        StaticRouterAPI.ConfigInput memory input = StaticRouterAPI.ConfigInput(
            address(assemblyStaticProducts.versions),
            assemblyStaticVersion,
            StaticRender.MetadataConfig(
                StaticRender.MetadataMode.ONCHAIN,
                address(assemblyStaticProducts.renderer),
                "",
                "",
                StaticRender.OffchainURIIdMode.TOKEN_ID,
                true
            )
        );
        assemblyStaticDefault = assemblyRouter.setDefaultMetadataConfig(input);
        assemblyRouter.activateStaticMetadata(1, assemblyStaticDefault);
        assemblyStaticCollection = assemblyRouter.collectionMetadataConfig(1);
        require(
            assemblyStaticCollection.previous == assemblyStaticDefault
                && assemblyStaticCollection.collectionId == 1
                && assemblyStaticCollection.tokenId == 0 && assemblyStaticCollection.revision == 1
                && assemblyStaticCollection.defaultRevision == 1
                && assemblyStaticCollection.level == 3 && assemblyStaticCollection.config.frozen
                && assemblyStaticCollection.sourceSnapshotHash != 0
                && keccak256(abi.encode(assemblyStaticCollection.config))
                    == keccak256(abi.encode(input.config)),
            "actual frozen collection wrapper before first ratification"
        );
        (StaticRouterAPI.RawSource memory source,) =
            assemblyRouter.staticRenderSourceForConfig(1, assemblyStaticCollection.recordHash);
        require(
            source.configured
                && keccak256(bytes(source.script)) == keccak256(bytes(ASSEMBLY_SCRIPT))
                && assemblyStaticCollection.sourceSnapshotHash
                    == keccak256(
                        abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), source)
                    ),
            "frozen actual original source"
        );
    }

    function _staticPrefixDocuments() private {
        if (!assemblySchemas.document(assemblySchemas.RAW_BYTES()).exists) {
            _staticPrefixDocument(
                "RAW_BYTES",
                StaticSchema.DocumentKind.CANONICALIZATION,
                bytes(assemblySchemas.RAW_BYTES_DEFINITION())
            );
        }
        StaticVersions.Registration memory r;
        r.renderer = address(assemblyStaticProducts.renderer);
        r.manifest = assemblyStaticConfiguration.rendererManifest;
        r.schemaDocument = _staticPrefixDocument(
            "CURRENT_AUTHORITY_RENDERER_SCHEMA_FIXTURE_V1",
            StaticSchema.DocumentKind.SCHEMA,
            _staticPrefixSchema()
        );
        r.contextDocument = _staticPrefixDocument(
            "STREAM_CONTEXT_V1",
            StaticSchema.DocumentKind.SCHEMA,
            bytes('{"fixture":true,"name":"STREAM_CONTEXT_V1"}')
        );
        r.manifestDocument = _staticPrefixDocument(
            "CURRENT_AUTHORITY_RENDERER_MANIFEST_FIXTURE_V1",
            StaticSchema.DocumentKind.CATALOG,
            _staticPrefixManifest()
        );
        StaticVersions.Analysis memory analysis = StaticVersions.Analysis(
            assemblyStaticProducts.versions.ANALYSIS_PROFILE(),
            r.renderer,
            r.renderer.codehash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                    assemblyStaticProducts.versions.targetSetHash(),
                    assemblyStaticReads
                )
            ),
            r.manifest.rendererVersion,
            r.manifest.contextVersion,
            r.manifest.schemaHash,
            keccak256("SYNTHETIC FIXTURE: no analysis tool executed"),
            keccak256("SYNTHETIC FIXTURE: partial direct reads, not conformance"),
            true
        );
        r.analysisDocument = _staticPrefixDocument(
            "CURRENT_AUTHORITY_ANALYSIS_JOIN_FIXTURE_V1",
            StaticSchema.DocumentKind.CATALOG,
            abi.encode(analysis)
        );
        StaticVersions.GoldenVector[] memory vectors = new StaticVersions.GoldenVector[](1);
        // Collection 1 is genuinely configured, but this is an explicit pre-mint token-zero vector.
        // No actual token identity, seed, payment or renderer conformance is claimed by it.
        vectors[0].request.core = address(assemblyCore);
        vectors[0].request.collectionId = 1;
        vectors[0].request.mode = StaticRender.MetadataMode.ONCHAIN;
        vectors[0].request.state = StaticRender.TokenRenderState.PENDING_RANDOMNESS;
        vectors[0].outputHash =
            keccak256(bytes(assemblyStaticProducts.renderer.tokenURI(vectors[0].request)));
        r.goldenDocument = _staticPrefixDocument(
            "CURRENT_AUTHORITY_PREMINT_GOLDEN_FIXTURE_V1",
            StaticSchema.DocumentKind.CATALOG,
            abi.encode(vectors)
        );
        assemblyStaticRegistration = r;
    }

    function _staticPrefixSchema() private pure returns (bytes memory) {
        return bytes('{"fixture":true,"type":"object","purpose":"renderer admission join only"}');
    }

    function _staticPrefixManifest() private pure returns (bytes memory) {
        return bytes('{"fixture":true,"renderer":"6529STREAM_STATIC_RENDERER_V1","reviewed":false}');
    }

    function _staticPrefixDocument(
        string memory name,
        StaticSchema.DocumentKind kind,
        bytes memory data
    ) private returns (bytes32 id) {
        id = _assemblyRegisterDocument(name, kind, data, assemblySchemas.RAW_BYTES());
        require(
            keccak256(assemblySchemas.documentBytes(id)) == keccak256(data),
            "retained exact fixture document"
        );
    }

    function _staticPrefixGovern(GovernanceCall memory operation, bytes memory data) private {
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] = operation;
        batch.callDatas[0] = data;
        _admitAssemblyBatch(batch);
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/current-authority/static-admission"
        );
    }

    function _staticPrefixDoubleGas(address target, bytes32 id, uint256 expected) private {
        StaticGas host = StaticGas(target);
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = host.gasParameterInfo(id);
        require(value == expected, "exact original render frame");
        bytes32 scope = keccak256(
            abi.encode(keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, target, id)
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        _assemblyGovernanceCall(
            1,
            target,
            abi.encodeCall(host.raiseGasParameter, (id, value * 2)),
            scope,
            keccak256(abi.encode(domain, scope, value, floor, failure, revision)),
            keccak256(abi.encode(domain, scope, value * 2, floor, failure, revision + 1))
        );
        (uint256 saved, uint256 savedFloor, uint8 savedFailure, uint64 savedRevision) =
            host.gasParameterInfo(id);
        require(
            saved == value * 2 && savedFloor == floor && savedFailure == failure
                && savedRevision == revision + 1,
            "actual governed render frame readback"
        );
    }

    function _staticPrefixTargets() internal view returns (StaticVersions.Target[] memory targets) {
        (address encoding,) = assemblyStaticProducts.renderer.encodingBinding();
        targets = new StaticVersions.Target[](6);
        targets[0] = StaticVersions.Target(
            address(assemblyCore), address(assemblyCore).codehash, keccak256("CORE")
        );
        targets[1] = StaticVersions.Target(
            address(assemblyMetadata),
            address(assemblyMetadata).codehash,
            keccak256("COLLECTION_METADATA")
        );
        targets[2] = StaticVersions.Target(
            address(assemblyRouter),
            address(assemblyRouter).codehash,
            keccak256("METADATA_COMPANION")
        );
        targets[3] = StaticVersions.Target(
            address(assemblyEntropy),
            address(assemblyEntropy).codehash,
            keccak256("ENTROPY_COORDINATOR")
        );
        targets[4] = StaticVersions.Target(
            address(assemblyStaticProducts.attribution),
            address(assemblyStaticProducts.attribution).codehash,
            keccak256("METADATA_COMPANION")
        );
        targets[5] =
            StaticVersions.Target(encoding, encoding.codehash, keccak256("METADATA_COMPANION"));
        for (uint256 i = 1; i < targets.length; ++i) {
            for (uint256 j = i; j > 0 && targets[j - 1].target > targets[j].target; --j) {
                (targets[j - 1], targets[j]) = (targets[j], targets[j - 1]);
            }
        }
    }

    function _staticPrefixDirectReads() internal {
        StaticVersions.Target[] memory targets = _staticPrefixTargets();
        for (uint16 i; i < targets.length; ++i) {
            address target = targets[i].target;
            if (target == address(assemblyCore)) {
                assemblyStaticReads.push(
                    StaticVersions.Read(i, StaticMintAPI.tokenData.selector, 16448, false)
                );
            } else if (target == address(assemblyMetadata)) {
                assemblyStaticReads.push(
                    StaticVersions.Read(i, StaticSourceAPI.staticBundle.selector, 384, true)
                );
                assemblyStaticReads.push(
                    StaticVersions.Read(i, StaticSourceAPI.staticBundleChunk.selector, 128, true)
                );
                assemblyStaticReads.push(
                    StaticVersions.Read(
                        i, StaticSourceAPI.staticScriptManifest.selector, 9504, false
                    )
                );
            } else if (target == address(assemblyRouter)) {
                assemblyStaticReads.push(
                    StaticVersions.Read(
                        i, StaticRouterAPI.staticRenderSourceForConfig.selector, 20736, false
                    )
                );
            } else if (target == address(assemblyEntropy)) {
                assemblyStaticReads.push(
                    StaticVersions.Read(
                        i, StaticEntropyAPI.staticTokenRenderFacts.selector, 96, true
                    )
                );
            } else if (target == address(assemblyStaticProducts.attribution)) {
                assemblyStaticReads.push(
                    StaticVersions.Read(
                        i, assemblyStaticProducts.attribution.attribution.selector, 32832, false
                    )
                );
            } else {
                assemblyStaticReads.push(
                    StaticVersions.Read(i, StaticEncoding.render.selector, 16777216, false)
                );
            }
        }
        for (uint256 i = 1; i < assemblyStaticReads.length; ++i) {
            for (
                uint256 j = i;
                j > 0
                    && _staticPrefixReadOrder(assemblyStaticReads[j - 1])
                        > _staticPrefixReadOrder(assemblyStaticReads[j]);
                --j
            ) {
                StaticVersions.Read memory previous = assemblyStaticReads[j - 1];
                assemblyStaticReads[j - 1] = assemblyStaticReads[j];
                assemblyStaticReads[j] = previous;
            }
        }
    }

    function _staticPrefixReadOrder(StaticVersions.Read memory read)
        internal
        pure
        returns (uint256)
    {
        return (uint256(read.targetIndex) << 32) | uint32(read.selector);
    }

    /// @dev Exact request assembled from real original identity/seed and the captured frozen config.
    function _assemblyStaticRequest(uint256 tokenId)
        internal
        view
        returns (StaticRender.RenderRequest memory r)
    {
        (bool exists, uint256 collectionId, uint256 serial, bool burned) =
            StaticIdentityAPI(address(assemblyCore)).tokenCollectionIdentity(tokenId);
        (bytes32 seed, bool finalized) = assemblyEntropy.tokenSeed(tokenId);
        require(
            exists && !burned && collectionId == 1 && finalized && seed != 0,
            "actual live original finalized token"
        );
        StaticRouterAPI.ConfigRecord memory record = assemblyRouter.resolvedMetadataConfig(tokenId);
        require(
            record.recordHash == assemblyStaticCollection.recordHash && record.config.frozen,
            "original frozen STATIC selection"
        );
        r = StaticRender.RenderRequest(
            address(assemblyCore),
            tokenId,
            collectionId,
            serial,
            seed,
            StaticRender.TokenRenderState.FROZEN,
            record.config.mode,
            StaticCollectionAPI(address(assemblyCore)).collectionSupplyMode(collectionId),
            StaticCollectionAPI(address(assemblyCore)).collectionStatus(collectionId),
            0,
            0,
            record.recordHash
        );
    }

    function _assemblyHTML(uint256 tokenId)
        internal
        view
        virtual
        override
        returns (bytes memory html)
    {
        html = bytes(assemblyStaticProducts.renderer.renderView(_assemblyStaticRequest(tokenId), 3));
        require(
            StaticContentBytes.matchesAnimation(
                bytes(assemblyRouter.historicalTokenMetadataJSON(address(assemblyCore), tokenId)),
                html
            ),
            "exact actual historical STATIC animation bytes"
        );
    }

    function _assemblyStaticRequireServing(uint256 tokenId) internal view {
        StaticRender.RenderRequest memory request = _assemblyStaticRequest(tokenId);
        require(assemblyStaticCitation != 0, "current output requires genuine separate admission");
        require(
            keccak256(bytes(assemblyStaticProducts.renderer.renderView(request, 0)))
                == keccak256(
                    bytes(
                        assemblyRouter.historicalTokenMetadataJSON(address(assemblyCore), tokenId)
                    )
                ),
            "actual historical compact path"
        );
        require(
            keccak256(bytes(assemblyStaticProducts.renderer.renderView(request, 2)))
                == keccak256(
                    bytes(
                        assemblyRouter.historicalFullTokenMetadataJSON(
                            address(assemblyCore), tokenId
                        )
                    )
                ),
            "actual historical full path"
        );
        require(
            keccak256(_assemblyHTML(tokenId))
                == keccak256(bytes(assemblyRouter.tokenHTML(tokenId))),
            "citation preserves the exact executable HTML"
        );
        require(
            keccak256(bytes(assemblyRouter.tokenJSON(tokenId)))
                == keccak256(
                    bytes(
                        _staticPrefixInsertCitation(
                            assemblyStaticProducts.renderer.renderView(request, 2), tokenId
                        )
                    )
                ),
            "actual current full path has the literal work citation"
        );
    }

    /// @dev Genuine target-side golden validation. Expected current JSON is a test-only byte
    /// insertion into historical output, never a call to renderCurrent or production Citation.
    /// Analysis remains an explicitly synthetic assertion of a partial read roster.
    function _staticPrefixAdmitCitation(uint256 tokenId) private {
        StaticCitation.CurrentRegistration memory r;
        r.versionKey = assemblyStaticVersion;
        r.profile = keccak256("6529STREAM_CURRENT_BASE_CITATION_V1");
        r.selector = StaticCitationRenderer.renderCurrent.selector;
        (r.encoding, r.encodingRuntimeHash) = assemblyStaticProducts.renderer.encodingBinding();
        StaticVersions.Read[] memory reads =
            new StaticVersions.Read[](assemblyStaticReads.length + 1);
        for (uint256 i; i < assemblyStaticReads.length; ++i) {
            reads[i] = assemblyStaticReads[i];
        }
        StaticVersions.Target[] memory targets = _staticPrefixTargets();
        uint16 encoder;
        bool found;
        for (uint16 i; i < targets.length; ++i) {
            if (targets[i].target == r.encoding) {
                require(!found, "one exact encoder target");
                found = true;
                encoder = i;
            }
        }
        require(found, "current selector extends the original encoder roster");
        reads[assemblyStaticReads.length] =
            StaticVersions.Read(encoder, StaticEncoding.renderCurrent.selector, 16777216, false);
        for (uint256 i = 1; i < reads.length; ++i) {
            for (
                uint256 j = i;
                j > 0 && _staticPrefixReadOrder(reads[j - 1]) > _staticPrefixReadOrder(reads[j]);
                --j
            ) {
                (reads[j - 1], reads[j]) = (reads[j], reads[j - 1]);
            }
        }
        bytes32 oldVersion =
            keccak256(abi.encode(assemblyStaticProducts.versions.version(assemblyStaticVersion)));
        bytes32 oldGolden =
            assemblyStaticProducts.versions.registration(assemblyStaticVersion).goldenDocument;
        bytes32 oldGoldenHash = keccak256(assemblySchemas.documentBytes(oldGolden));
        bytes32 readHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                assemblyStaticProducts.versions.targetSetHash(),
                reads
            )
        );
        StaticCitation.CurrentAnalysis memory analysis = StaticCitation.CurrentAnalysis(
            keccak256("6529STREAM_CURRENT_BASE_CITATION_ANALYSIS_ABI_V1"),
            r.profile,
            r.selector,
            address(assemblyStaticProducts.renderer),
            assemblyStaticProducts.rendererCodeHash,
            r.encoding,
            r.encodingRuntimeHash,
            readHash,
            assemblyStaticProducts.versions.version(assemblyStaticVersion).registrationHash,
            keccak256("SYNTHETIC FIXTURE: no transitive opcode analysis executed"),
            keccak256("SYNTHETIC FIXTURE: partial original roster plus current encoding"),
            true
        );
        r.analysisDocument = _staticPrefixDocument(
            "CURRENT_AUTHORITY_CITATION_ANALYSIS_FIXTURE_V1",
            StaticSchema.DocumentKind.CATALOG,
            abi.encode(analysis)
        );
        StaticRender.RenderRequest memory request = _assemblyStaticRequest(tokenId);
        string memory historical = assemblyStaticProducts.renderer.renderView(request, 0);
        string memory historicalFull = assemblyStaticProducts.renderer.renderView(request, 2);
        string memory current = _staticPrefixInsertCitation(historical, tokenId);
        StaticCitation.CurrentGoldenVector[] memory vectors =
            new StaticCitation.CurrentGoldenVector[](3);
        vectors[0] = StaticCitation.CurrentGoldenVector(request, 0, keccak256(bytes(current)));
        vectors[1] = StaticCitation.CurrentGoldenVector(
            request,
            1,
            keccak256(
                bytes(
                    string.concat(
                        "data:application/json;base64,", StaticBase64.encode(bytes(current))
                    )
                )
            )
        );
        vectors[2] = StaticCitation.CurrentGoldenVector(
            request, 2, keccak256(bytes(_staticPrefixInsertCitation(historicalFull, tokenId)))
        );
        r.goldenDocument = _staticPrefixDocument(
            "CURRENT_AUTHORITY_PAID_CITATION_GOLDEN_FIXTURE_V1",
            StaticSchema.DocumentKind.CATALOG,
            abi.encode(vectors)
        );
        require(
            r.goldenDocument != oldGolden && request.tokenId == 1 && request.collectionSerial == 1
                && request.metadataSnapshotHash == assemblyStaticCollection.recordHash
                && assemblyCore.ownerOf(tokenId) == ASSEMBLY_BUYER
                && assemblyCore.coordinatorAtMint(tokenId) == address(assemblyEntropy),
            "new current evidence binds the real first paid token"
        );
        (bytes32 scope, bytes32 previous, bytes32 next) =
            assemblyStaticProducts.versions.currentCitationTransition(r, reads);
        _assemblyGovernanceCall(
            1,
            address(assemblyStaticProducts.versions),
            abi.encodeCall(StaticCitation.registerCurrentCitation, (r, reads)),
            scope,
            previous,
            next
        );
        StaticCitation.CurrentRecord memory saved =
            assemblyStaticProducts.versions.currentCitationRecord(assemblyStaticVersion);
        bytes32 expectedRegistration = keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_CITATION_REGISTRATION_V1"),
                block.chainid,
                address(assemblyStaticProducts.versions),
                address(assemblySchemas),
                address(assemblySchemas).codehash,
                assemblyStaticProducts.versions.targetSetHash(),
                assemblyStaticProducts.versions.version(assemblyStaticVersion).registrationHash,
                r,
                reads
            )
        );
        require(
            saved.registrationHash == expectedRegistration && saved.actionId != 0
                && saved.readSetHash == readHash
                && saved.analysisHash == keccak256(abi.encode(analysis))
                && saved.goldenHash == keccak256(abi.encode(vectors))
                && keccak256(abi.encode(saved.registration)) == keccak256(abi.encode(r))
                && keccak256(
                    abi.encode(
                        assemblyStaticProducts.versions.currentCitationReads(assemblyStaticVersion)
                    )
                ) == keccak256(abi.encode(reads)),
            "exact actual current citation receipt"
        );
        (address renderer, bytes32 runtime, bytes32 profile, bytes4 selector) =
            assemblyStaticProducts.versions.requireCurrentCitation(assemblyStaticVersion);
        require(
            renderer == address(assemblyStaticProducts.renderer) && runtime == renderer.codehash
                && profile == r.profile && selector == r.selector,
            "exact retained current route"
        );
        require(
            oldVersion
                    == keccak256(
                        abi.encode(assemblyStaticProducts.versions.version(assemblyStaticVersion))
                    )
                && oldGolden
                    == assemblyStaticProducts.versions
                    .registration(assemblyStaticVersion)
                    .goldenDocument
                && oldGoldenHash == keccak256(assemblySchemas.documentBytes(oldGolden))
                && keccak256(bytes(historical))
                    == keccak256(bytes(assemblyStaticProducts.renderer.renderView(request, 0)))
                && keccak256(bytes(historicalFull))
                    == keccak256(bytes(assemblyStaticProducts.renderer.renderView(request, 2))),
            "original admission and historical rendering remain exact"
        );
        assemblyStaticCitation = saved.registrationHash;
    }

    /// @dev Exact fixture JSON surgery at the unique stream/provenance boundary. Escaped strings
    /// cannot match this unescaped syntax. It deliberately does not parse or modify animation HTML.
    function _staticPrefixInsertCitation(string memory historical, uint256 tokenId)
        private
        view
        returns (string memory)
    {
        bytes memory source = bytes(historical);
        bytes memory needle = bytes('},"provenance":');
        uint256 at;
        uint256 matches;
        for (uint256 i; i + needle.length <= source.length; ++i) {
            bool same = true;
            for (uint256 j; j < needle.length; ++j) {
                if (source[i + j] != needle[j]) {
                    same = false;
                    break;
                }
            }
            if (same) {
                at = i;
                ++matches;
            }
        }
        require(matches == 1, "one exact historical stream object boundary");
        bytes memory insert = abi.encodePacked(
            ',"citation":"eip155:',
            StaticStrings.toString(block.chainid),
            "/erc721:",
            StaticStrings.toHexString(uint160(address(assemblyCore)), 20),
            "/",
            StaticStrings.toString(tokenId),
            '"'
        );
        bytes memory result = new bytes(source.length + insert.length);
        for (uint256 i; i < at; ++i) {
            result[i] = source[i];
        }
        for (uint256 i; i < insert.length; ++i) {
            result[at + i] = insert[i];
        }
        for (uint256 i = at; i < source.length; ++i) {
            result[insert.length + i] = source[i];
        }
        return string(result);
    }
}
