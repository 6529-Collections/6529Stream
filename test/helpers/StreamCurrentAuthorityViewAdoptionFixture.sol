// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

import {
    StreamCurrentAuthorityViewCompleteBindingFixture
} from "./StreamCurrentAuthorityViewCompleteBindingFixture.sol";
import {
    StreamCurrentAuthorityPreservationStaticPrefixFixture
} from "./StreamCurrentAuthorityPreservationStaticPrefixFixture.sol";
import { StreamCurrentStackPlan } from "../../script/current/StreamCurrentStackPlan.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import {
    GovernanceCall
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    StreamModuleRegistration
} from "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamPreservationRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    StreamRecordFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamArtistContentTypes as AssemblyContent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Actual original-A VIEW declaration and adoption on the current-authority graph.
/// @dev One shared Assembly supplies Core, Safe, Artist and the immutable full S/O/D original
/// inventory seed. The original VIEW attribution pair remains distinct from the current-Artist
/// token preservation prefix. Registry analysis is labelled synthetic fixture evidence, not
/// transitive opcode conformance. No browser, archive observation or gas acceptance is claimed.
abstract contract StreamCurrentAuthorityViewAdoptionFixture is
    StreamCurrentAuthorityViewCompleteBindingFixture,
    StreamCurrentAuthorityPreservationStaticPrefixFixture
{
    struct AuthorityViewAdoption {
        StreamFinalityScope scope;
        uint256[2] tokens;
        bytes32 membershipRecord;
        bytes membershipPayload;
        bytes32 inventoryPlan;
        address sourceSet;
        bytes32 viewId;
        bytes32 declarationRecord;
        bytes declarationPayload;
        StreamViewRendererV2 liveRenderer;
        StreamRendererRegistryModule registry;
        bytes32 rendererVersionKey;
        bytes32 rendererConsent;
        uint256 rendererConsentNonce;
        VA.Input input;
        VA.Record original;
        bytes32 adoptionRecord;
    }
    AuthorityViewAdoption internal authorityViewAdoption;
    VRegistry.Read[] internal authorityViewReads;
    bool internal authorityViewArtworkPrepared;
    bool internal authorityViewProbeMissingConsent;
    bool internal authorityViewMissingConsentObserved;
    bytes32 internal authorityViewAdoptionTransactionHash;

    function _authorityPrepareViewArtwork() internal {
        require(
            !authorityViewArtworkPrepared && address(avRenderer) == address(0), "one VIEW graph"
        );
        _authorityConstructViewBindingSources();
        _authorityBindCompleteView();
        _activateAssemblyArtwork();
        authorityViewAdoption.tokens = [uint256(1), uint256(2)];
        _assemblyPrepareDescriptionDefinitions();
        _assemblySelectDescriptionsAndWaiver();
        _authorityLockViewPresentation();
        require(!assemblyCore.collectionFreezeStatus(1), "VIEW window remains open");
        _authorityRequireCompleteView();
        authorityViewArtworkPrepared = true;
    }

    function _authorityDeclareAndAdoptView() internal {
        require(
            authorityViewArtworkPrepared && authorityViewAdoption.adoptionRecord == 0,
            "prepared original A, one VIEW adoption"
        );
        require(!assemblyCore.collectionFreezeStatus(1), "adoption precedes Core freeze");
        _authorityRequireCompleteView();
        _authorityViewMembership();
        _authorityViewSources();
        _assemblyGrantFamily(StreamRecordFamilies.IDENTITY, 8, address(assemblyRoot));
        _assemblyGrantFamily(StreamRecordFamilies.IDENTITY, 7, address(assemblyRoot));
        _authorityViewDeclare();
        _authorityViewDeployRenderer();
        _authorityViewRegisterRenderer();
        _authorityViewAdopt();
        _authorityRequireViewAdoption();
        _authorityRequireViewServing();
    }

    function _authorityViewAdopt() private {
        VA.Input memory p = VA.Input(
            authorityViewAdoption.scope,
            authorityViewAdoption.viewId,
            authorityViewAdoption.declarationRecord,
            0,
            address(authorityViewAdoption.registry),
            authorityViewAdoption.rendererVersionKey,
            0
        );
        VPolicyRouter host = VPolicyRouter(address(assemblyRouter));
        (bytes32 family, bytes32 source) = host.previewPolicyViewAdoption(p, address(assemblyRoot));
        require(family != 0 && source != 0, "actual original adoption preflight");
        p.expectedSourceHash = source;
        authorityViewAdoption.input = p;
        bytes memory transaction =
            _authorityViewSafeTransaction(abi.encodeCall(host.adoptPolicyView, (p)));
        authorityViewAdoptionTransactionHash = keccak256(transaction);
        uint256 beforeNonce = assemblyRoot.nonce();
        bytes32 beforeAggregate =
            keccak256(abi.encode(VRouter(address(assemblyRouter)).viewAdoptionAggregate(1)));
        if (authorityViewProbeMissingConsent) {
            (bool accepted, bytes memory failure) = address(assemblyRoot).call(transaction);
            require(
                !accepted
                    && keccak256(failure)
                        == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
                "actual Safe rejects adoption without its original op17 consent"
            );
            require(
                assemblyRoot.nonce() == beforeNonce
                    && VRouter(address(assemblyRouter)).viewAdoptionHead(p.scope) == 0
                    && keccak256(
                        abi.encode(VRouter(address(assemblyRouter)).viewAdoptionAggregate(1))
                    ) == beforeAggregate,
                "failed adoption preserves Safe nonce, head and aggregate"
            );
            authorityViewMissingConsentObserved = true;
        }
        AssemblyContent.Consent memory consent = AssemblyContent.Consent(
            1, address(assemblyRouter), keccak256("RENDERER_CONFIG"), family
        );
        T.Authorization memory a = _assemblyAuthorization(false);
        a.signature =
            _assemblyArtistProof(assemblyArtists.contentConsentDigest(consent, a), a.nonce);
        authorityViewAdoption.rendererConsentNonce = a.nonce;
        authorityViewAdoption.rendererConsent = assemblyArtists.recordContentConsent(consent, a);
        _authorityContentConsent(consent, authorityViewAdoption.rendererConsent);
        require(
            authorityViewAdoption.rendererConsent != 0
                && !assemblyRouter.consumedArtistContentConsent(
                    authorityViewAdoption.rendererConsent
                )
        );
        require(keccak256(transaction) == authorityViewAdoptionTransactionHash);
        (bool success, bytes memory result) = address(assemblyRoot).call(transaction);
        require(success && abi.decode(result, (bool)), "identical signed Safe VIEW adoption");
        require(
            assemblyRoot.nonce() == beforeNonce + 1
                && assemblyRouter.consumedArtistContentConsent(
                    authorityViewAdoption.rendererConsent
                )
        );
        authorityViewAdoption.adoptionRecord =
            VRouter(address(assemblyRouter)).viewAdoptionHead(p.scope);
        authorityViewAdoption.original = abi.decode(
            VRouter(address(assemblyRouter))
                .viewAdoptionEncoded(authorityViewAdoption.adoptionRecord),
            (VA.Record)
        );
    }

    function _authorityViewSafeTransaction(bytes memory data) private returns (bytes memory) {
        bytes32 digest = assemblyRoot.getTransactionHash(
            address(assemblyRouter),
            0,
            data,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            assemblyRoot.nonce()
        );
        return abi.encodeCall(
            assemblyRoot.execTransaction,
            (
                address(assemblyRouter),
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

    function _authorityViewDocument(string memory name, Schema.DocumentKind kind, bytes memory raw)
        internal
        returns (bytes32 id)
    {
        id = keccak256(bytes(name));
        Schema.DocumentView memory saved = assemblySchemas.document(id);
        if (!saved.exists) {
            return _assemblyRegisterDocument(name, kind, raw, assemblySchemas.RAW_BYTES());
        }
        require(
            saved.status == Schema.DocumentStatus.ACTIVE && saved.specification.kind == kind
                && saved.specification.canonicalizationId == assemblySchemas.RAW_BYTES()
                && saved.specification.contentHash == keccak256(raw)
                && saved.specification.totalBytes == raw.length
                && keccak256(assemblySchemas.documentBytes(id)) == keccak256(raw),
            "exact existing fixture definition"
        );
    }

    function _authorityViewReadOrder(VRegistry.Read memory r) internal pure returns (uint256) {
        return (uint256(r.targetIndex) << 32) | uint32(r.selector);
    }

    function _authorityViewMembership() internal {
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
        require(
            authorityViewAdoption.tokens[0] < authorityViewAdoption.tokens[1],
            "actual ordered originals"
        );
        bytes memory tokenBytes =
            abi.encode(authorityViewAdoption.tokens[0], authorityViewAdoption.tokens[1]);
        (bytes32 chunk, address pointer) = assemblyStore.publishChunk(tokenBytes);
        require(chunk == keccak256(tokenBytes) && pointer.code.length == tokenBytes.length + 1);
        bytes32[] memory parts = new bytes32[](1);
        parts[0] = chunk;
        StreamScopeMembershipManifest memory m = StreamScopeMembershipManifest(
            1,
            block.chainid,
            address(assemblyCore),
            1,
            uint8(StreamFinalityScopeType.VIEW),
            2,
            chunk,
            parts
        );
        bytes memory raw = VMembership.encode(m);
        IStreamPreservationRecords.CollectionRecord memory r;
        r.recordType = kind;
        r.subjectId = VSubjects.scopeSubject(block.chainid, address(assemblyCore), _assemblyScope());
        r.schemaId = keccak256("STREAM_SCOPE_MEMBERSHIP_V1");
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(raw)), keccak256("STREAM_SCOPE_MEMBERSHIP_ABI_V1")
        );
        r.uri = "urn:fixture:authority-view:view-membership";
        r.effectiveAt = uint64(block.timestamp);
        bytes32 saved = assemblyMetadata.recordCollectionRecordWithPayload(1, r, raw);
        authorityViewAdoption.membershipRecord = saved;
        authorityViewAdoption.membershipPayload = raw;
        authorityViewAdoption.scope = assemblyMembership.beginScopeMembership(saved);
        assemblyMembership.continueScopeMembership(authorityViewAdoption.scope, 1);
        StreamScopeMembershipFacts memory f =
            assemblyMembership.requireScopeMembership(authorityViewAdoption.scope);
        require(f.tokenCount == 2 && f.sourceRecordHash == saved && f.tokenListHash == chunk);
        require(
            authorityViewAdoption.scope.scopeType == StreamFinalityScopeType.VIEW
                && authorityViewAdoption.scope.collectionId == 1
                && authorityViewAdoption.scope.tokenId == 0
                && authorityViewAdoption.scope.scopeId
                    == VMembership.scopeId(
                        block.chainid,
                        address(assemblyCore),
                        1,
                        uint8(StreamFinalityScopeType.VIEW),
                        saved
                    )
        );
        for (uint256 i; i < 2; ++i) {
            require(
                assemblyMembership.scopeTokenAt(authorityViewAdoption.scope, i)
                    == authorityViewAdoption.tokens[i]
            );
        }
    }

    function _authorityViewSources() internal {
        authorityViewAdoption.inventoryPlan =
            assemblyCoordinators.beginInventory(authorityViewAdoption.scope);
        assemblyCoordinators.appendInventory(authorityViewAdoption.inventoryPlan, 2);
        require(
            assemblyCoordinators.requireCompleteInventory(authorityViewAdoption.inventoryPlan)
            .tokenCount == 2
        );
        VSourceFactory f = VSourceFactory(address(sourceScopedPolicyEntropyFactory));
        require(
            f.currentInventoryPlan(authorityViewAdoption.scope)
                == authorityViewAdoption.inventoryPlan
        );
        authorityViewAdoption.sourceSet = f.prepareSourceSet(authorityViewAdoption.scope);
        (address set, bytes32 pin) = f.sourceSetForPlan(authorityViewAdoption.inventoryPlan);
        require(set == authorityViewAdoption.sourceSet && pin == set.codehash);
        VSourceSet(set).requireCurrentSourceSet();
        require(VSourceSet(set).sourceCount() == 1 && VSourceSet(set).sourcePolicyAt(0).frozen);
    }

    function _authorityViewDeclare() internal {
        _authorityViewDocument(
            "STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2",
            Schema.DocumentKind.SCHEMA,
            bytes(VPayload.DEFINITION)
        );
        authorityViewAdoption.viewId =
            keccak256("actual current-authority original A alternate view");
        authorityViewAdoption.declarationPayload = abi.encode(
            VA.Payload(
                VP.CONTEXT,
                "Actual alternate view",
                "Original two-token VIEW with complete admitted assemblyEntropy policy.",
                "",
                bytes(ASSEMBLY_SCRIPT)
            )
        );
        VDeclarations.CollectionViewManifest memory m = VDeclarations.CollectionViewManifest(
            authorityViewAdoption.viewId,
            VPayload.SCHEMA_ID,
            "urn:fixture:authority-view:view-payload",
            keccak256(authorityViewAdoption.declarationPayload),
            "application/octet-stream",
            true
        );
        authorityViewAdoption.declarationRecord = avViews.setCollectionViewManifestWithPayload(
            1, authorityViewAdoption.viewId, m, authorityViewAdoption.declarationPayload, 0
        );
        require(
            executeSafe(
                assemblyRoot,
                assemblyRootKeys,
                address(avViews),
                0,
                abi.encodeCall(avViews.lockCollectionView, (1, authorityViewAdoption.viewId)),
                0
            ),
            "original class8 declaration lock"
        );
        (bytes32 selected, bool locked) =
            avViews.selectedViewRecord(1, authorityViewAdoption.viewId);
        require(
            selected == authorityViewAdoption.declarationRecord && locked,
            "original declaration lock"
        );
        (, bytes memory retained) = avViews.viewPayload(selected);
        require(keccak256(retained) == keccak256(authorityViewAdoption.declarationPayload));
    }

    function _authorityViewDeployRenderer() internal {
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
            address(assemblyCore),
            address(assemblyRouter),
            authorityViewAdoption.sourceSet,
            address(avOriginalAttribution)
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
            address(sourceScopedPolicyEntropyFactory),
            authorityViewAdoption.scope,
            uint32(4000000),
            address(assemblyExecutor),
            readGas,
            attributionGas,
            m
        );
        require(
            type(StreamViewRendererV2).creationCode.length + args.length <= 49152,
            "VIEW renderer initcode cap"
        );
        authorityViewAdoption.liveRenderer = new StreamViewRendererV2(
            targets,
            address(sourceScopedPolicyEntropyFactory),
            authorityViewAdoption.scope,
            4000000,
            address(assemblyExecutor),
            readGas,
            attributionGas,
            m
        );
        require(
            address(authorityViewAdoption.liveRenderer).code.length <= 24576,
            "VIEW renderer runtime cap"
        );
        VRegistry.Target[] memory roster = _authorityViewTargets();
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
            address(assemblyExecutor),
            address(assemblySchemas),
            roster,
            registryRead,
            golden,
            ASSEMBLY_DEPLOYMENT,
            "urn:fixture:late-view-registry",
            keccak256(doc)
        );
        require(
            type(StreamRendererRegistryModule).creationCode.length + abi.encode(d).length <= 49152,
            "late Registry initcode cap"
        );
        authorityViewAdoption.registry = new StreamRendererRegistryModule(d);
        require(
            address(authorityViewAdoption.registry).code.length <= 24576,
            "late Registry runtime cap"
        );
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](1);
        registrations[0] = StreamModuleRegistration(
            address(authorityViewAdoption.registry),
            keccak256("RENDERER_REGISTRY"),
            authorityViewAdoption.registry.streamModuleVersion(),
            type(VRegistry).interfaceId,
            2000000,
            address(authorityViewAdoption.registry).codehash,
            ASSEMBLY_DEPLOYMENT,
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
                address(authorityViewAdoption.registry),
                keccak256("RENDERER_REGISTRY"),
                type(VRegistry).interfaceId
            )
        );
    }

    function _authorityViewTargets() internal view returns (VRegistry.Target[] memory a) {
        a = new VRegistry.Target[](10);
        a[0] = VRegistry.Target(
            address(assemblyCore), address(assemblyCore).codehash, keccak256("CORE")
        );
        a[1] = VRegistry.Target(
            address(assemblyRouter),
            address(assemblyRouter).codehash,
            keccak256("METADATA_COMPANION")
        );
        a[2] = VRegistry.Target(
            authorityViewAdoption.sourceSet,
            authorityViewAdoption.sourceSet.codehash,
            keccak256("METADATA_COMPANION")
        );
        a[3] = VRegistry.Target(
            address(avOriginalAttribution),
            address(avOriginalAttribution).codehash,
            keccak256("ARTIST_STATIC_DISPLAY")
        );
        a[4] = VRegistry.Target(
            address(VEncoding), address(VEncoding).codehash, keccak256("METADATA_COMPANION")
        );
        a[5] = VRegistry.Target(
            address(assemblyEntropy),
            address(assemblyEntropy).codehash,
            keccak256("ENTROPY_COORDINATOR")
        );
        a[6] = VRegistry.Target(
            address(assemblyMembership),
            address(assemblyMembership).codehash,
            keccak256("METADATA_COMPANION")
        );
        a[7] = VRegistry.Target(
            address(avRenderer), address(avRenderer).codehash, keccak256("PRESERVATION_RENDERER")
        );
        a[8] = VRegistry.Target(
            address(avAttribution),
            address(avAttribution).codehash,
            keccak256("PRESERVATION_ATTRIBUTION")
        );
        a[9] = VRegistry.Target(
            address(authorityViewAdoption.liveRenderer),
            address(authorityViewAdoption.liveRenderer).codehash,
            keccak256("METADATA_COMPANION")
        );
        for (uint256 i = 1; i < a.length; ++i) {
            for (uint256 j = i; j != 0 && a[j - 1].target > a[j].target; --j) {
                (a[j - 1], a[j]) = (a[j], a[j - 1]);
            }
        }
    }

    function _authorityViewRegisterRenderer() internal {
        VRegistry.Target[] memory targets = _authorityViewTargets();
        // Complete finite direct roster of original renderer/encoding source reads. The
        // admitted analysis still explicitly does not prove transitive opcode conformance.
        for (uint16 i; i < targets.length; ++i) {
            address t = targets[i].target;
            if (t == address(assemblyCore)) {
                _authorityViewRead(i, "tokenCollectionIdentity(uint256)", 128, true);
                _authorityViewRead(i, "collectionFreezeStatus(uint256)", 32, true);
                _authorityViewRead(i, "tokenLifecycle(uint256)", 32, true);
                _authorityViewRead(i, "coordinatorAtMint(uint256)", 32, true);
                _authorityViewRead(i, "collectionSupplyMode(uint256)", 32, true);
                _authorityViewRead(i, "collectionStatus(uint256)", 32, true);
                _authorityViewRead(i, "tokenData(uint256)", 16480, false);
            } else if (t == address(assemblyRouter)) {
                _authorityViewRead(i, "viewAdoptionCarrier(bytes32)", 96, true);
                _authorityViewRead(i, "viewAdoptionProfile(bytes32)", 32, true);
            } else if (t == address(assemblyMembership)) {
                _authorityViewRead(
                    i, "scopeCoversToken((uint8,uint256,uint256,bytes32),uint256)", 32, true
                );
            } else if (t == address(avOriginalAttribution)) {
                _authorityViewRead(i, "attribution(uint256,uint256)", 32864, false);
            } else if (t == address(assemblyEntropy)) {
                _authorityViewRead(i, "staticTokenRenderFacts(uint256)", 96, true);
                _authorityViewRead(i, "core()", 32, true);
                _authorityViewRead(i, "supportsInterface(bytes4)", 32, true);
                _authorityViewRead(i, "staticTerminalEntropyFacts(uint256)", 512, true);
            } else if (t == address(VEncoding)) {
                authorityViewReads.push(VRegistry.Read(i, VEncoding.html.selector, 262240, false));
                authorityViewReads.push(VRegistry.Read(i, VEncoding.output.selector, 262240, false));
            }
        }
        for (uint256 i = 1; i < authorityViewReads.length; ++i) {
            for (
                uint256 j = i;
                j != 0
                    && _authorityViewReadOrder(authorityViewReads[j - 1])
                        > _authorityViewReadOrder(authorityViewReads[j]);
                --j
            ) {
                (authorityViewReads[j - 1], authorityViewReads[j]) =
                (authorityViewReads[j], authorityViewReads[j - 1]);
            }
        }
        VRegistry.Registration memory r;
        r.renderer = address(authorityViewAdoption.liveRenderer);
        r.manifest = authorityViewAdoption.liveRenderer.rendererManifest();
        r.schemaDocument = _authorityViewDocument(
            "AUTHORITY_VIEW_OUTPUT_SCHEMA_FIXTURE_V2",
            Schema.DocumentKind.SCHEMA,
            bytes(VFormat.SCHEMA)
        );
        r.contextDocument = _authorityViewDocument(
            "STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2",
            Schema.DocumentKind.SCHEMA,
            bytes("{\"fixture\":true,\"context\":\"original complete policy VIEW context\"}")
        );
        r.manifestDocument = _authorityViewDocument(
            "AUTHORITY_VIEW_RENDERER_MANIFEST_FIXTURE_V2",
            Schema.DocumentKind.CATALOG,
            bytes("{\"fixture\":true,\"renderer\":\"original policy VIEW V2\",\"reviewed\":false}")
        );
        VRegistry.Analysis memory report = VRegistry.Analysis(
            authorityViewAdoption.registry.ANALYSIS_PROFILE(),
            r.renderer,
            r.renderer.codehash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                    authorityViewAdoption.registry.targetSetHash(),
                    authorityViewReads
                )
            ),
            r.manifest.rendererVersion,
            r.manifest.contextVersion,
            r.manifest.schemaHash,
            keccak256("SYNTHETIC FIXTURE: no VIEW opcode analysis executed"),
            keccak256("SYNTHETIC FIXTURE: exact declared direct reads, not transitive conformance"),
            true
        );
        r.analysisDocument = _authorityViewDocument(
            "AUTHORITY_VIEW_ANALYSIS_FIXTURE_V2", Schema.DocumentKind.CATALOG, abi.encode(report)
        );
        VRegistry.GoldenVector[] memory golden = new VRegistry.GoldenVector[](1);
        golden[0].request.core = address(assemblyCore);
        golden[0].request.mode = VRender.MetadataMode.ONCHAIN;
        golden[0].outputHash = keccak256(
            bytes("data:application/json;base64,eyJzdGF0ZSI6InVuY29uZmlndXJlZF92aWV3In0=")
        );
        require(
            keccak256(bytes(authorityViewAdoption.liveRenderer.tokenURI(golden[0].request)))
                == golden[0].outputHash,
            "literal original registration-only vector"
        );
        r.goldenDocument = _authorityViewDocument(
            "AUTHORITY_VIEW_UNCONFIGURED_GOLDEN_FIXTURE_V2",
            Schema.DocumentKind.CATALOG,
            abi.encode(golden)
        );
        (bytes32 s, bytes32 a, bytes32 b) =
            authorityViewAdoption.registry.registrationTransition(r, authorityViewReads);
        _assemblyGovernanceCall(
            1,
            address(authorityViewAdoption.registry),
            abi.encodeCall(
                authorityViewAdoption.registry.registerRenderer, (r, authorityViewReads)
            ),
            s,
            a,
            b
        );
        authorityViewAdoption.rendererVersionKey = keccak256(
            abi.encode(keccak256("6529STREAM_RENDERER_VERSION_V1"), VFormat.ID, VFormat.VERSION)
        );
        require(
            authorityViewAdoption.registry.version(authorityViewAdoption.rendererVersionKey).exists
        );
    }

    function _authorityViewRead(uint16 index, string memory signature, uint32 size, bool exact)
        private
    {
        authorityViewReads.push(
            VRegistry.Read(index, bytes4(keccak256(bytes(signature))), size, exact)
        );
    }

    function _authorityRequireViewAdoption() internal view {
        _authorityRequireCompleteView();
        _requireCurrentGraphSelections();
        require(
            address(assemblyArtists) == assemblyInventory.dependencies().artistTargets[0],
            "original A remains selected"
        );
        VA.Record memory r = abi.decode(
            VRouter(address(assemblyRouter))
                .viewAdoptionEncoded(authorityViewAdoption.adoptionRecord),
            (VA.Record)
        );
        require(
            r.recordHash != 0 && r.recordHash == authorityViewAdoption.adoptionRecord
                && r.revision == 1 && r.artistConsent == authorityViewAdoption.rendererConsent
                && r.actor == address(assemblyRoot) && r.authorizationClass == 7
                && r.grantRevision != 0 && r.aggregate.revision == 1
        );
        require(
            keccak256(abi.encode(r)) == keccak256(abi.encode(authorityViewAdoption.original)),
            "complete immutable original adoption retained"
        );
        require(
            keccak256(abi.encode(r.input)) == keccak256(abi.encode(authorityViewAdoption.input))
                && keccak256(abi.encode(r.source.membership))
                    == keccak256(
                        abi.encode(
                            assemblyMembership.requireScopeMembership(authorityViewAdoption.scope)
                        )
                    )
        );
        require(
            r.sourceHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_VIEW_ADOPTION_SOURCE_V2"),
                        VP.PROFILE,
                        block.chainid,
                        address(assemblyRouter),
                        r.input.scope,
                        r.input.viewId,
                        r.input.viewRecordHash,
                        r.source,
                        authorityViewAdoption.liveRenderer.policyViewBinding()
                    )
                ),
            "literal original source commitment"
        );
        r.recordHash = 0;
        require(
            authorityViewAdoption.adoptionRecord
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"),
                        VP.PROFILE,
                        block.chainid,
                        address(assemblyRouter),
                        address(assemblyCore),
                        r
                    )
                ),
            "literal original adoption commitment"
        );
        require(
            VPolicyRouter(address(assemblyRouter))
                .viewAdoptionProfile(authorityViewAdoption.adoptionRecord) == VP.PROFILE
        );
    }

    function _authorityRequireViewServing() internal view {
        VRouter host = VRouter(address(assemblyRouter));
        for (uint256 i; i < authorityViewAdoption.tokens.length; ++i) {
            uint256 token = authorityViewAdoption.tokens[i];
            string memory json = host.tokenJSONForView(token, authorityViewAdoption.scope.scopeId);
            string memory html = host.tokenHTMLForView(token, authorityViewAdoption.scope.scopeId);
            require(
                bytes(json).length != 0 && bytes(html).length != 0
                    && keccak256(bytes(json))
                        == keccak256(
                            bytes(
                                host.historicalTokenJSONForView(
                                    token, authorityViewAdoption.adoptionRecord
                                )
                            )
                        )
                    && keccak256(bytes(html))
                        == keccak256(
                            bytes(
                                host.historicalTokenHTMLForView(
                                    token, authorityViewAdoption.adoptionRecord
                                )
                            )
                        ),
                "actual current and original VIEW endpoints agree"
            );
        }
    }

    function _authorityLockViewPresentation() private {
        GenesisBatch memory locks;
        locks.actionClass = 1;
        locks.calls = new GovernanceCall[](2);
        locks.callDatas = new bytes[](2);
        locks.callDatas[0] = abi.encodeCall(assemblyRouter.lockDisplayMetadata, (1));
        locks.callDatas[1] = abi.encodeCall(assemblyRouter.lockArtistIdentity, (1));
        for (uint256 i; i < 2; ++i) {
            locks.calls[i] = StreamCurrentStackPlan.call(
                address(assemblyRouter),
                locks.callDatas[i],
                keccak256(abi.encode(address(assemblyRouter), locks.callDatas[i])),
                bytes32(0),
                keccak256(locks.callDatas[i])
            );
        }
        _admitAssemblyBatch(locks);
        _assemblyGovernance(
            locks, "https://fixtures.example.invalid/native-assembly/original-presentation-locks"
        );
    }
}
