// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentFullPreservationPolicyPreparationFixture.sol";
import {
    StreamViewAdoptionTypes as VA
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    StreamViewPolicyTypesV2 as VP
} from "../../smart-contracts/domains/metadata/StreamViewPolicyTypesV2.sol";
import {
    StreamViewPayloadV2 as VPayload
} from "../../smart-contracts/domains/metadata/StreamViewPayloadV2.sol";
import {
    StreamViewRendererFormatV2 as VFormat
} from "../../smart-contracts/domains/metadata/StreamViewRendererFormatV2.sol";
import {
    StreamViewRendererEncodingV2 as VEncoding
} from "../../smart-contracts/domains/metadata/StreamViewRendererEncodingV2.sol";
import {
    StreamViewRendererV2
} from "../../smart-contracts/domains/metadata/StreamViewRendererV2.sol";
import {
    StreamRendererRegistryModule
} from "../../smart-contracts/domains/metadata/StreamRendererRegistryModule.sol";
import {
    IStreamViewAdoptionPolicyRouterV2 as VPolicyRouter
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewAdoptionPolicyRouterV2.sol";
import {
    IStreamViewAdoptionRouter as VRouter
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import {
    IStreamViewRendererV2 as VRenderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewRendererV2.sol";
import {
    IStreamViewPreservationRendererV1 as VPreservation
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    IStreamPreservationRegistryV1 as VPreservationRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamCollectionViews as VDeclarations
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamRendererRegistry as VRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamRenderer as VRender
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamFinalityEntropySourceFactory as VSourceFactory
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as VSourceSet
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamScopeMembershipManifest,
    StreamScopeMembershipFacts
} from "../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamScopeMembershipEncoding as VMembership
} from "../../smart-contracts/domains/finality/StreamScopeMembershipEncoding.sol";
import {
    StreamMetadataSubjects as VSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";

/// @notice Original VIEW declaration and Safe/Artist adoption before STATIC/Core freezing.
/// @dev Actual original membership, inventory, policy source set, renderer, late Registry and
/// op17 producers. Analysis/context documents are explicitly fixture assertions, not opcode
/// conformance evidence. No browser, publication/finality or transaction-budget acceptance.
abstract contract StreamCurrentFullPreservationPolicyViewAdoptionFixture is
    StreamCurrentFullPreservationPolicyPreparationFixture
{
    StreamFinalityScope internal fullPolicyViewScope;
    bytes32 internal fullPolicyViewId;
    bytes32 internal fullPolicyViewDeclaration;
    bytes32 internal fullPolicyViewAdoption;
    StreamRendererRegistryModule internal fullPolicyViewRegistry;
    StreamViewRendererV2 internal fullPolicyViewRenderer;
    address internal fullPolicyViewSourceSet;
    bytes32 internal fullPolicyViewInventoryPlan;
    bytes32 internal fullPolicyViewVersionKey;
    bytes32 internal fullPolicyViewConsent;
    bytes internal fullPolicyViewPayload;
    VA.Input internal fullPolicyViewInput;
    VA.Record internal fullPolicyViewOriginal;
    bytes32 internal fullPolicyViewPreservationKey;
    VPreservationRegistry.PreservationRecord internal fullPolicyViewPreservationRegistration;
    VRegistry.Read[] internal fullPolicyViewReads;
    bool internal fullPolicyViewProbeMissingConsent;
    bool internal fullPolicyViewProbeBadSource;
    bytes32 internal fullPolicyViewRetryCalldataHash;
    uint256 internal fullPolicyViewAdoptionSafeNonce;

    function _prepareFullPolicyViewBeforeFreeze() internal virtual override {
        require(fullPolicyViewAdoption == 0 && !core.collectionFreezeStatus(1));
        _fullPolicyViewMembership();
        _fullPolicyViewSources();
        _fullPolicyViewDeclare();
        _fullPolicyViewDeployRenderer();
        _fullPolicyViewRegisterRenderer();
        _fullPolicyViewAdopt();
        _publishFullPolicyViewBeforeFreeze();
    }

    /// @dev Parent continuation may admit preservation, checkpoint and adopt its root here.
    /// SNAPSHOT grants and archive registration remain owned by that continuation.
    function _publishFullPolicyViewBeforeFreeze() internal virtual { }

    function _fullPolicyViewMembership() internal {
        // Original membership admission joins each token to the actual serial index.
        assemblyTokens.scanCollectionTokens(1, 256);
        _assemblyRegisterDocument(
            "STREAM_SCOPE_MEMBERSHIP_V1",
            Schema.DocumentKind.SCHEMA,
            bytes(assemblyVm.readFile("docs/schemas/finality/scope-membership-v1.schema.json")),
            assemblySchemas.RAW_BYTES()
        );
        _assemblyRegisterDocument(
            "STREAM_SCOPE_MEMBERSHIP_ABI_V1",
            Schema.DocumentKind.CANONICALIZATION,
            bytes(assemblyVm.readFile("docs/schemas/finality/scope-membership-abi-v1.json")),
            assemblySchemas.RAW_BYTES()
        );
        bytes32 kind = keccak256("SCOPE_MEMBERSHIP");
        (bytes32 s, bytes32 a, bytes32 b) =
            assemblyMetadata.recordTypeTransition(kind, StreamRecordFamilies.IDENTITY, 384);
        _assemblyGovernanceCall(
            1,
            address(assemblyMetadata),
            abi.encodeCall(
                assemblyMetadata.admitRecordType, (kind, StreamRecordFamilies.IDENTITY, uint16(384))
            ),
            s,
            a,
            b
        );
        // Preparation already admitted this exact writer; do not mutate its grant revision.
        (bool enabled, uint64 revision) =
            assemblyMetadata.familyWriter(1, StreamRecordFamilies.IDENTITY, 7, address(this));
        require(enabled && revision != 0, "original identity writer");
        require(fullPolicyTokens[0] < fullPolicyTokens[1], "actual ordered originals");
        bytes memory tokenBytes = abi.encode(fullPolicyTokens[0], fullPolicyTokens[1]);
        (bytes32 chunk, address pointer) = assemblyStore.publishChunk(tokenBytes);
        require(chunk == keccak256(tokenBytes) && pointer.code.length == tokenBytes.length + 1);
        bytes32[] memory parts = new bytes32[](1);
        parts[0] = chunk;
        StreamScopeMembershipManifest memory m = StreamScopeMembershipManifest(
            1, block.chainid, address(core), 1, uint8(StreamFinalityScopeType.VIEW), 2, chunk, parts
        );
        bytes memory raw = VMembership.encode(m);
        IStreamPreservationRecords.CollectionRecord memory r;
        r.recordType = kind;
        r.subjectId = VSubjects.scopeSubject(block.chainid, address(core), _collectionScope());
        r.schemaId = keccak256("STREAM_SCOPE_MEMBERSHIP_V1");
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(raw)), keccak256("STREAM_SCOPE_MEMBERSHIP_ABI_V1")
        );
        r.uri = "urn:fixture:full-preservation:view-membership";
        r.effectiveAt = uint64(block.timestamp);
        bytes32 saved = assemblyMetadata.recordCollectionRecordWithPayload(1, r, raw);
        fullPolicyViewScope = assemblyMembership.beginScopeMembership(saved);
        assemblyMembership.continueScopeMembership(fullPolicyViewScope, 1);
        StreamScopeMembershipFacts memory f =
            assemblyMembership.requireScopeMembership(fullPolicyViewScope);
        require(f.tokenCount == 2 && f.sourceRecordHash == saved && f.tokenListHash == chunk);
        require(
            fullPolicyViewScope.scopeType == StreamFinalityScopeType.VIEW
                && fullPolicyViewScope.collectionId == 1 && fullPolicyViewScope.tokenId == 0
                && fullPolicyViewScope.scopeId
                    == VMembership.scopeId(
                        block.chainid, address(core), 1, uint8(StreamFinalityScopeType.VIEW), saved
                    )
        );
        for (uint256 i; i < 2; ++i) {
            require(assemblyMembership.scopeTokenAt(fullPolicyViewScope, i) == fullPolicyTokens[i]);
        }
    }

    function _fullPolicyViewSources() internal {
        fullPolicyViewInventoryPlan = assemblyCoordinators.beginInventory(fullPolicyViewScope);
        assemblyCoordinators.appendInventory(fullPolicyViewInventoryPlan, 2);
        require(
            assemblyCoordinators.requireCompleteInventory(fullPolicyViewInventoryPlan).tokenCount
                == 2
        );
        VSourceFactory f = VSourceFactory(address(fullPolicyScopedSources));
        require(f.currentInventoryPlan(fullPolicyViewScope) == fullPolicyViewInventoryPlan);
        fullPolicyViewSourceSet = f.prepareSourceSet(fullPolicyViewScope);
        (address set, bytes32 pin) = f.sourceSetForPlan(fullPolicyViewInventoryPlan);
        require(set == fullPolicyViewSourceSet && pin == set.codehash);
        VSourceSet(set).requireCurrentSourceSet();
        require(VSourceSet(set).sourceCount() == 1 && VSourceSet(set).sourcePolicyAt(0).frozen);
    }

    /// @dev Existing recipes retain the exact absent-image payload.
    function _fullPolicyViewImageURI() internal pure virtual returns (string memory) {
        return "";
    }

    function _fullPolicyViewDeclare() internal {
        _document(
            "STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2",
            Schema.DocumentKind.SCHEMA,
            bytes(VPayload.DEFINITION)
        );
        fullPolicyViewId = keccak256("actual full preservation alternate view");
        fullPolicyViewPayload = abi.encode(
            VA.Payload(
                VP.CONTEXT,
                "Actual alternate view",
                "Original two-token VIEW with complete admitted entropy policy.",
                _fullPolicyViewImageURI(),
                bytes(FULL_POLICY_SCRIPT)
            )
        );
        VDeclarations.CollectionViewManifest memory m = VDeclarations.CollectionViewManifest(
            fullPolicyViewId,
            VPayload.SCHEMA_ID,
            "urn:fixture:full-preservation:view-payload",
            keccak256(fullPolicyViewPayload),
            "application/octet-stream",
            true
        );
        fullPolicyViewDeclaration = assemblyViewDeclarations.setCollectionViewManifestWithPayload(
            1, fullPolicyViewId, m, fullPolicyViewPayload, 0
        );
        require(
            executeSafe(
                assemblyRoot,
                assemblyRootKeys,
                address(assemblyViewDeclarations),
                0,
                abi.encodeCall(assemblyViewDeclarations.lockCollectionView, (1, fullPolicyViewId)),
                0
            ),
            "original class8 declaration lock"
        );
        (bytes32 selected, bool locked) =
            assemblyViewDeclarations.selectedViewRecord(1, fullPolicyViewId);
        require(selected == fullPolicyViewDeclaration && locked, "original declaration lock");
        (, bytes memory retained) = assemblyViewDeclarations.viewPayload(selected);
        require(keccak256(retained) == keccak256(fullPolicyViewPayload));
    }

    function _fullPolicyViewDeployRenderer() internal {
        bytes memory doc =
            bytes("{\"fixture\":true,\"renderer\":\"original policy VIEW V2\",\"reviewed\":false}");
        VRender.RendererManifest memory m = VRender.RendererManifest(
            VFormat.ID,
            VFormat.VERSION,
            VP.CONTEXT,
            keccak256("STATIC"),
            VFormat.schemaHash(),
            "urn:fixture:view-output",
            "urn:fixture:view-renderer",
            keccak256(doc),
            262144,
            262144,
            false
        );
        address[4] memory targets = [
            address(core),
            address(router),
            fullPolicyViewSourceSet,
            address(products.rendering.attribution)
        ];
        IStreamGasParameterHost.GasParameterConfig memory readGas =
            IStreamGasParameterHost.GasParameterConfig(
                "METADATA_DEPENDENCY_READ_GAS", 100000, 50000, 2
            );
        IStreamGasParameterHost.GasParameterConfig memory attributionGas =
            IStreamGasParameterHost.GasParameterConfig(
                "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 2
            );
        bytes memory args = abi.encode(
            targets,
            address(fullPolicyScopedSources),
            fullPolicyViewScope,
            uint32(4000000),
            address(executor),
            readGas,
            attributionGas,
            m
        );
        require(
            type(StreamViewRendererV2).creationCode.length + args.length <= 49152,
            "VIEW renderer initcode cap"
        );
        fullPolicyViewRenderer = new StreamViewRendererV2(
            targets,
            address(fullPolicyScopedSources),
            fullPolicyViewScope,
            4000000,
            address(executor),
            readGas,
            attributionGas,
            m
        );
        require(address(fullPolicyViewRenderer).code.length <= 24576, "VIEW renderer runtime cap");
        VRegistry.Target[] memory roster = _fullPolicyViewTargets();
        // This new Registry's preservation golden validation calls the actual C binding,
        // whose strict inner reads retain Router's original 2m cap. A 4m outer ceiling
        // avoids the impossible equal-cap forwarding. Checkpoint serving remains 9m;
        // this constructor choice is not a measured transaction-fit or cap waiver.
        IStreamGasParameterHost.GasParameterConfig memory registryRead =
            IStreamGasParameterHost.GasParameterConfig(
                "METADATA_DEPENDENCY_READ_GAS", 4000000, 100000, 2
            );
        IStreamGasParameterHost.GasParameterConfig memory golden =
            IStreamGasParameterHost.GasParameterConfig(
                "RENDERER_GOLDEN_VECTOR_GAS", 20000000, 100000, 2
            );
        StreamRendererRegistryModule.Deployment memory d = StreamRendererRegistryModule.Deployment(
            address(executor),
            address(assemblySchemas),
            roster,
            registryRead,
            golden,
            DEPLOYMENT_HASH,
            "urn:fixture:late-view-registry",
            keccak256(doc)
        );
        require(
            type(StreamRendererRegistryModule).creationCode.length + abi.encode(d).length <= 49152,
            "late Registry initcode cap"
        );
        fullPolicyViewRegistry = new StreamRendererRegistryModule(d);
        require(address(fullPolicyViewRegistry).code.length <= 24576, "late Registry runtime cap");
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](1);
        registrations[0] = StreamModuleRegistration(
            address(fullPolicyViewRegistry),
            keccak256("RENDERER_REGISTRY"),
            fullPolicyViewRegistry.streamModuleVersion(),
            type(VRegistry).interfaceId,
            2000000,
            address(fullPolicyViewRegistry).codehash,
            DEPLOYMENT_HASH,
            keccak256(doc),
            "urn:fixture:late-view-registry"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(assemblyModules, registrations);
        _assemblyGovernanceCall(
            1,
            calls[0].target,
            data[0],
            calls[0].scopeHash,
            calls[0].oldValueHash,
            calls[0].newValueHash
        );
        require(
            assemblyModules.isModuleEligible(
                address(fullPolicyViewRegistry),
                keccak256("RENDERER_REGISTRY"),
                type(VRegistry).interfaceId
            )
        );
    }

    function _fullPolicyViewTargets() internal view returns (VRegistry.Target[] memory a) {
        a = new VRegistry.Target[](10);
        a[0] = VRegistry.Target(address(core), address(core).codehash, keccak256("CORE"));
        a[1] = VRegistry.Target(
            address(router), address(router).codehash, keccak256("METADATA_COMPANION")
        );
        a[2] = VRegistry.Target(
            fullPolicyViewSourceSet,
            fullPolicyViewSourceSet.codehash,
            keccak256("METADATA_COMPANION")
        );
        a[3] = VRegistry.Target(
            address(products.rendering.attribution),
            address(products.rendering.attribution).codehash,
            keccak256("ARTIST_STATIC_DISPLAY")
        );
        a[4] = VRegistry.Target(
            address(VEncoding), address(VEncoding).codehash, keccak256("METADATA_COMPANION")
        );
        a[5] = VRegistry.Target(
            address(entropy), address(entropy).codehash, keccak256("ENTROPY_COORDINATOR")
        );
        a[6] = VRegistry.Target(
            address(assemblyMembership),
            address(assemblyMembership).codehash,
            keccak256("METADATA_COMPANION")
        );
        a[7] = VRegistry.Target(
            address(assemblyViewPreservationRenderer),
            address(assemblyViewPreservationRenderer).codehash,
            keccak256("PRESERVATION_RENDERER")
        );
        a[8] = VRegistry.Target(
            address(assemblyPreservationAttribution),
            address(assemblyPreservationAttribution).codehash,
            keccak256("PRESERVATION_ATTRIBUTION")
        );
        a[9] = VRegistry.Target(
            address(fullPolicyViewRenderer),
            address(fullPolicyViewRenderer).codehash,
            keccak256("METADATA_COMPANION")
        );
        for (uint256 i = 1; i < a.length; ++i) {
            for (uint256 j = i; j != 0 && a[j - 1].target > a[j].target; --j) {
                (a[j - 1], a[j]) = (a[j], a[j - 1]);
            }
        }
    }

    function _fullPolicyViewRegisterRenderer() internal {
        VRegistry.Target[] memory targets = _fullPolicyViewTargets();
        // Complete finite direct roster of original renderer/encoding source reads. The
        // admitted analysis still explicitly does not prove transitive opcode conformance.
        for (uint16 i; i < targets.length; ++i) {
            address t = targets[i].target;
            if (t == address(core)) {
                _viewRead(i, "tokenCollectionIdentity(uint256)", 128, true);
                _viewRead(i, "collectionFreezeStatus(uint256)", 32, true);
                _viewRead(i, "tokenLifecycle(uint256)", 32, true);
                _viewRead(i, "coordinatorAtMint(uint256)", 32, true);
                _viewRead(i, "collectionSupplyMode(uint256)", 32, true);
                _viewRead(i, "collectionStatus(uint256)", 32, true);
                _viewRead(i, "tokenData(uint256)", 16480, false);
            } else if (t == address(router)) {
                _viewRead(i, "viewAdoptionCarrier(bytes32)", 96, true);
                _viewRead(i, "viewAdoptionProfile(bytes32)", 32, true);
            } else if (t == address(assemblyMembership)) {
                _viewRead(i, "scopeCoversToken((uint8,uint256,uint256,bytes32),uint256)", 32, true);
            } else if (t == address(products.rendering.attribution)) {
                _viewRead(i, "attribution(uint256,uint256)", 32864, false);
            } else if (t == address(entropy)) {
                _viewRead(i, "staticTokenRenderFacts(uint256)", 96, true);
                _viewRead(i, "core()", 32, true);
                _viewRead(i, "supportsInterface(bytes4)", 32, true);
                _viewRead(i, "staticTerminalEntropyFacts(uint256)", 512, true);
            } else if (t == address(VEncoding)) {
                fullPolicyViewReads.push(VRegistry.Read(i, VEncoding.html.selector, 262240, false));
                fullPolicyViewReads.push(
                    VRegistry.Read(i, VEncoding.output.selector, 262240, false)
                );
            }
        }
        for (uint256 i = 1; i < fullPolicyViewReads.length; ++i) {
            for (
                uint256 j = i;
                j != 0
                    && _readOrder(fullPolicyViewReads[j - 1]) > _readOrder(fullPolicyViewReads[j]);
                --j
            ) {
                (fullPolicyViewReads[j - 1], fullPolicyViewReads[j]) =
                (fullPolicyViewReads[j], fullPolicyViewReads[j - 1]);
            }
        }
        VRegistry.Registration memory r;
        r.renderer = address(fullPolicyViewRenderer);
        r.manifest = fullPolicyViewRenderer.rendererManifest();
        r.schemaDocument = _document(
            "FULL_VIEW_OUTPUT_SCHEMA_FIXTURE_V2", Schema.DocumentKind.SCHEMA, bytes(VFormat.SCHEMA)
        );
        r.contextDocument = _document(
            "STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2",
            Schema.DocumentKind.SCHEMA,
            bytes("{\"fixture\":true,\"context\":\"original complete policy VIEW context\"}")
        );
        r.manifestDocument = _document(
            "FULL_VIEW_RENDERER_MANIFEST_FIXTURE_V2",
            Schema.DocumentKind.CATALOG,
            bytes("{\"fixture\":true,\"renderer\":\"original policy VIEW V2\",\"reviewed\":false}")
        );
        VRegistry.Analysis memory report = VRegistry.Analysis(
            fullPolicyViewRegistry.ANALYSIS_PROFILE(),
            r.renderer,
            r.renderer.codehash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                    fullPolicyViewRegistry.targetSetHash(),
                    fullPolicyViewReads
                )
            ),
            r.manifest.rendererVersion,
            r.manifest.contextVersion,
            r.manifest.schemaHash,
            keccak256("SYNTHETIC FIXTURE: no VIEW opcode analysis executed"),
            keccak256("SYNTHETIC FIXTURE: exact declared direct reads, not transitive conformance"),
            true
        );
        r.analysisDocument = _document(
            "FULL_VIEW_ANALYSIS_FIXTURE_V2", Schema.DocumentKind.CATALOG, abi.encode(report)
        );
        VRegistry.GoldenVector[] memory golden = new VRegistry.GoldenVector[](1);
        golden[0].request.core = address(core);
        golden[0].request.mode = VRender.MetadataMode.ONCHAIN;
        golden[0].outputHash = keccak256(
            bytes("data:application/json;base64,eyJzdGF0ZSI6InVuY29uZmlndXJlZF92aWV3In0=")
        );
        require(
            keccak256(bytes(fullPolicyViewRenderer.tokenURI(golden[0].request)))
                == golden[0].outputHash,
            "literal original registration-only vector"
        );
        r.goldenDocument = _document(
            "FULL_VIEW_UNCONFIGURED_GOLDEN_FIXTURE_V2",
            Schema.DocumentKind.CATALOG,
            abi.encode(golden)
        );
        (bytes32 s, bytes32 a, bytes32 b) =
            fullPolicyViewRegistry.registrationTransition(r, fullPolicyViewReads);
        _assemblyGovernanceCall(
            1,
            address(fullPolicyViewRegistry),
            abi.encodeCall(fullPolicyViewRegistry.registerRenderer, (r, fullPolicyViewReads)),
            s,
            a,
            b
        );
        fullPolicyViewVersionKey = keccak256(
            abi.encode(keccak256("6529STREAM_RENDERER_VERSION_V1"), VFormat.ID, VFormat.VERSION)
        );
        require(fullPolicyViewRegistry.version(fullPolicyViewVersionKey).exists);
    }

    function _viewRead(uint16 index, string memory signature, uint32 size, bool exact) private {
        fullPolicyViewReads.push(
            VRegistry.Read(index, bytes4(keccak256(bytes(signature))), size, exact)
        );
    }

    function _fullPolicyViewAdopt() internal {
        VA.Input memory p = VA.Input(
            fullPolicyViewScope,
            fullPolicyViewId,
            fullPolicyViewDeclaration,
            0,
            address(fullPolicyViewRegistry),
            fullPolicyViewVersionKey,
            0
        );
        VPolicyRouter host = VPolicyRouter(address(router));
        (bytes32 family, bytes32 source) = host.previewPolicyViewAdoption(p, address(assemblyRoot));
        require(family != 0 && source != 0, "actual preflight before any negative");
        p.expectedSourceHash = source;
        if (fullPolicyViewProbeBadSource) {
            VA.Input memory bad = abi.decode(abi.encode(p), (VA.Input));
            bad.expectedSourceHash = bytes32(uint256(source) ^ 1);
            (bool ok, bytes memory error) = address(host)
                .staticcall(
                    abi.encodeCall(host.previewPolicyViewAdoption, (bad, address(assemblyRoot)))
                );
            require(
                !ok
                    && keccak256(error)
                        == keccak256(abi.encodeWithSelector(VA.InvalidViewAdoption.selector)),
                "exact source mismatch"
            );
            require(VRouter(address(router)).viewAdoptionHead(fullPolicyViewScope) == 0);
        }
        fullPolicyViewInput = p;
        bytes memory callData = abi.encodeCall(host.adoptPolicyView, (p));
        fullPolicyViewAdoptionSafeNonce = assemblyRoot.nonce();
        bytes memory transaction = _fullPolicyViewSafeTransaction(callData);
        fullPolicyViewRetryCalldataHash = keccak256(transaction);
        bytes32 aggregate = keccak256(abi.encode(VRouter(address(router)).viewAdoptionAggregate(1)));
        if (fullPolicyViewProbeMissingConsent) {
            (bool ok, bytes memory error) = address(assemblyRoot).call(transaction);
            require(
                !ok
                    && keccak256(error)
                        == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
                "Safe original missing-consent failure"
            );
            require(
                assemblyRoot.nonce() == fullPolicyViewAdoptionSafeNonce
                    && VRouter(address(router)).viewAdoptionHead(fullPolicyViewScope) == 0
                    && keccak256(abi.encode(VRouter(address(router)).viewAdoptionAggregate(1)))
                        == aggregate,
                "failed Safe call leaves nonce/head/aggregate empty"
            );
        }
        AssemblyContent.Consent memory consent =
            AssemblyContent.Consent(1, address(router), keccak256("RENDERER_CONFIG"), family);
        T.Authorization memory a = _assemblyAuthorization(false);
        a.signature = _assemblyArtistProof(artists.contentConsentDigest(consent, a));
        fullPolicyViewConsent = artists.recordContentConsent(consent, a);
        require(
            fullPolicyViewConsent != 0
                && !router.consumedArtistContentConsent(fullPolicyViewConsent)
                && keccak256(transaction) == fullPolicyViewRetryCalldataHash
        );
        (bool success, bytes memory result) = address(assemblyRoot).call(transaction);
        require(success && abi.decode(result, (bool)), "identical signed Safe adoption");
        require(assemblyRoot.nonce() == fullPolicyViewAdoptionSafeNonce + 1);
        require(
            router.consumedArtistContentConsent(fullPolicyViewConsent), "original op17 consumed"
        );
        fullPolicyViewAdoption = VRouter(address(router)).viewAdoptionHead(fullPolicyViewScope);
        fullPolicyViewOriginal = abi.decode(
            VRouter(address(router)).viewAdoptionEncoded(fullPolicyViewAdoption), (VA.Record)
        );
        _assertFullPolicyViewAdoption();
    }

    function _fullPolicyViewSafeTransaction(bytes memory data) internal returns (bytes memory) {
        bytes32 digest = assemblyRoot.getTransactionHash(
            address(router), 0, data, 0, 0, 0, 0, address(0), address(0), assemblyRoot.nonce()
        );
        return abi.encodeCall(
            assemblyRoot.execTransaction,
            (
                address(router),
                0,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(assemblyRootKeys, digest)
            )
        );
    }

    function _assertFullPolicyViewAdoption() internal view {
        VA.Record memory r = abi.decode(
            VRouter(address(router)).viewAdoptionEncoded(fullPolicyViewAdoption), (VA.Record)
        );
        require(
            r.recordHash != 0 && r.recordHash == fullPolicyViewAdoption && r.revision == 1
                && r.artistConsent == fullPolicyViewConsent && r.actor == address(assemblyRoot)
                && r.authorizationClass == 7 && r.grantRevision != 0 && r.aggregate.revision == 1
        );
        require(
            keccak256(abi.encode(r.input)) == keccak256(abi.encode(fullPolicyViewInput))
                && keccak256(abi.encode(r.source.membership))
                    == keccak256(
                        abi.encode(assemblyMembership.requireScopeMembership(fullPolicyViewScope))
                    )
        );
        require(
            r.sourceHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_VIEW_ADOPTION_SOURCE_V2"),
                        VP.PROFILE,
                        block.chainid,
                        address(router),
                        r.input.scope,
                        r.input.viewId,
                        r.input.viewRecordHash,
                        r.source,
                        fullPolicyViewRenderer.policyViewBinding()
                    )
                ),
            "literal original source commitment"
        );
        r.recordHash = 0;
        require(
            fullPolicyViewAdoption
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"),
                        VP.PROFILE,
                        block.chainid,
                        address(router),
                        address(core),
                        r
                    )
                ),
            "literal original adoption commitment"
        );
        require(
            VPolicyRouter(address(router)).viewAdoptionProfile(fullPolicyViewAdoption) == VP.PROFILE
        );
    }

    /// @dev Called by the publication continuation, once, after the actual original adoption.
    function _admitFullPolicyViewPreservation() internal {
        require(fullPolicyViewAdoption != 0 && fullPolicyViewPreservationKey == 0);
        VPreservationRegistry api = VPreservationRegistry(address(fullPolicyViewRegistry));
        VPreservationRegistry.PreservationRegistration memory r;
        r.versionKey = fullPolicyViewVersionKey;
        r.binding = VPreservationRegistry.ProducerBinding(
            address(assemblyViewPreservationRenderer),
            address(assemblyViewPreservationRenderer).codehash,
            keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1"),
            address(core),
            address(router),
            address(fullPolicyViewRenderer),
            address(fullPolicyViewRenderer).codehash,
            address(assemblyPreservationAttribution),
            address(assemblyPreservationAttribution).codehash
        );
        VRegistry.Read[] memory reads = _fullPolicyViewPreservationReads();
        bytes memory schema = bytes(
            "{\"fixture\":true,\"output\":\"original adopted VIEW JSON/HTML, only sanction projection omitted\"}"
        );
        r.schemaDocument = _document(
            "FULL_VIEW_PRESERVATION_SCHEMA_FIXTURE_V1", Schema.DocumentKind.SCHEMA, schema
        );
        r.analysisDocument = _document(
            "FULL_VIEW_PRESERVATION_ANALYSIS_FIXTURE_V1",
            Schema.DocumentKind.CATALOG,
            abi.encode(
                VPreservationRegistry.PreservationAnalysis(
                    keccak256("6529STREAM_PRESERVATION_ANALYSIS_ABI_V1"),
                    r.binding,
                    fullPolicyViewRegistry.version(fullPolicyViewVersionKey).registrationHash,
                    keccak256(schema),
                    keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                            fullPolicyViewRegistry.targetSetHash(),
                            reads
                        )
                    ),
                    keccak256("SYNTHETIC FIXTURE: no VIEW preservation opcode analysis"),
                    keccak256(
                        "SYNTHETIC FIXTURE: fixed original roster with required preservation sources, not transitive analysis"
                    ),
                    true
                )
            )
        );
        VPreservationRegistry.PreservationGoldenVector[] memory vectors =
            new VPreservationRegistry.PreservationGoldenVector[](8);
        for (uint256 i; i < 2; ++i) {
            uint256 token = fullPolicyTokens[i];
            (bytes32 jsonRecord, string memory json) =
                assemblyViewPreservationRenderer.preservationViewJSON(fullPolicyViewScope, token);
            (bytes32 htmlRecord, string memory html) =
                assemblyViewPreservationRenderer.preservationViewHTML(fullPolicyViewScope, token);
            (StreamFinalityScope memory js, string memory oldJSON) = assemblyViewPreservationRenderer.historicalPreservationViewJSON(
                fullPolicyViewAdoption, token
            );
            (StreamFinalityScope memory hs, string memory oldHTML) = assemblyViewPreservationRenderer.historicalPreservationViewHTML(
                fullPolicyViewAdoption, token
            );
            require(
                jsonRecord == fullPolicyViewAdoption && htmlRecord == fullPolicyViewAdoption
                    && keccak256(abi.encode(js)) == keccak256(abi.encode(fullPolicyViewScope))
                    && keccak256(abi.encode(hs)) == keccak256(abi.encode(js))
                    && keccak256(bytes(json)) == keccak256(bytes(oldJSON))
                    && keccak256(bytes(html)) == keccak256(bytes(oldHTML))
            );
            for (uint8 mode = 2; mode <= 5; ++mode) {
                vectors[4 * i + mode - 2] = VPreservationRegistry.PreservationGoldenVector(
                    fullPolicyViewScope,
                    token,
                    fullPolicyViewAdoption,
                    mode,
                    keccak256(bytes(mode % 2 == 0 ? json : html))
                );
            }
        }
        r.goldenDocument = _document(
            "FULL_VIEW_PRESERVATION_GOLDEN_FIXTURE_V1",
            Schema.DocumentKind.CATALOG,
            abi.encode(vectors)
        );
        (bytes32 s, bytes32 a, bytes32 b) = api.preservationTransition(r, reads);
        _assemblyGovernanceCall(
            1, address(api), abi.encodeCall(api.registerPreservation, (r, reads)), s, a, b
        );
        fullPolicyViewPreservationKey =
            api.preservationKey(r.versionKey, r.binding.producer, r.binding.profile);
        fullPolicyViewPreservationRegistration =
            api.preservationRecord(fullPolicyViewPreservationKey);
        require(
            fullPolicyViewPreservationRegistration.registrationHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_REGISTRATION_V1"),
                        block.chainid,
                        address(api),
                        address(assemblySchemas),
                        address(assemblySchemas).codehash,
                        fullPolicyViewRegistry.targetSetHash(),
                        fullPolicyViewRegistry.version(r.versionKey).registrationHash,
                        r,
                        reads
                    )
                ),
            "literal genuine admission"
        );
        (
            VPreservationRegistry.ProducerBinding memory binding,
            VPreservationRegistry.Admission memory admitted
        ) = api.requirePreservation(r.versionKey, r.binding.producer, r.binding.profile);
        require(
            keccak256(abi.encode(binding)) == keccak256(abi.encode(r.binding))
                && admitted.registrationHash
                    == fullPolicyViewPreservationRegistration.registrationHash
                && admitted.registry == address(api)
                && admitted.versionKey == fullPolicyViewVersionKey
        );
    }

    function _fullPolicyViewPreservationReads()
        internal
        view
        returns (VRegistry.Read[] memory reads)
    {
        reads = new VRegistry.Read[](fullPolicyViewReads.length + 9);
        uint256 next;
        for (; next < fullPolicyViewReads.length; ++next) {
            reads[next] = fullPolicyViewReads[next];
        }
        VRegistry.Target[] memory targets = _fullPolicyViewTargets();
        for (uint16 i; i < targets.length; ++i) {
            if (targets[i].target == address(assemblyViewPreservationRenderer)) {
                reads[next++] =
                    VRegistry.Read(i, VPreservation.preservationProfile.selector, 32, true);
                reads[next++] = VRegistry.Read(i, VPreservation.configuration.selector, 288, true);
                reads[next++] =
                    VRegistry.Read(i, VPreservation.preservationViewBinding.selector, 192, true);
                reads[next++] =
                    VRegistry.Read(i, VPreservation.preservationViewJSON.selector, 262336, false);
                reads[next++] =
                    VRegistry.Read(i, VPreservation.preservationViewHTML.selector, 262336, false);
                reads[next++] = VRegistry.Read(
                    i, VPreservation.historicalPreservationViewJSON.selector, 262336, false
                );
                reads[next++] = VRegistry.Read(
                    i, VPreservation.historicalPreservationViewHTML.selector, 262336, false
                );
                reads[next++] =
                    VRegistry.Read(i, VPreservation.configurationHash.selector, 32, true);
            } else if (targets[i].target == address(assemblyPreservationAttribution)) {
                reads[next++] = VRegistry.Read(
                    i, bytes4(keccak256("preservationAttribution(uint256,uint256)")), 32832, false
                );
            }
        }
        require(next == reads.length);
        for (uint256 i = 1; i < reads.length; ++i) {
            for (uint256 j = i; j != 0 && _readOrder(reads[j - 1]) > _readOrder(reads[j]); --j) {
                (reads[j - 1], reads[j]) = (reads[j], reads[j - 1]);
            }
        }
    }
}
