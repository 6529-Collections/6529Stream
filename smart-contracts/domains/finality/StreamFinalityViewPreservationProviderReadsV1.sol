// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import "./StreamFinalityHashes.sol";
import "../metadata/StreamMetadataSubjects.sol";

import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";

import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads as Scoped
} from "./StreamFinalityScopedProviderReads.sol";
import {
    StreamFinalityViewPreservationConfigurationV1 as Configuration
} from "./StreamFinalityViewPreservationConfigurationV1.sol";
import {
    StreamFinalityViewPreservationMetadataV1 as Metadata
} from "./StreamFinalityViewPreservationMetadataV1.sol";
import {
    StreamFinalityViewPreservationInputTypesV1 as T
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationInputTypesV1.sol";
import {
    StreamFinalityViewPreservationInputReadsV1 as Manifest
} from "./StreamFinalityViewPreservationInputReadsV1.sol";
import {
    IStreamViewPreservationRenderCriticalInventoryV1 as Inventory
} from "../../interfaces/stream/preservation/IStreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    IStreamViewPreservationBundleArchiveCoverageV1 as Bundle
} from "../../interfaces/stream/preservation/IStreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as V
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as Items
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../preservation/StreamPreservationInventoryIO.sol";
import {
    StreamViewPreservationRenderCriticalRetainedReadsV1 as Retained
} from "../preservation/StreamViewPreservationRenderCriticalRetainedReadsV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as Reference
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    IStreamFinalityCurrentEntropyRoute,
    StreamFinalityCurrentComponentRoute
} from "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    IStreamFinalityEntropySourceFactory as Factory
} from "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    StreamViewPreservationOutputSchemasV1 as Outputs
} from "./StreamViewPreservationOutputSchemasV1.sol";

library StreamFinalityViewPreservationProviderReadsV1 {
    error InvalidViewFinalityInputs();

    function statement(
        Native.Config memory original,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] memory components
    ) public view returns (T.Statement memory s) {
        Configuration.requireScope(original, scope);
        Configuration.Context memory x = Configuration.resolve(original);
        Native.Config memory c = x.effective;
        bytes memory raw = IO.fixedRead(
            c.targets[18], abi.encodeCall(Inventory.requireCurrent, (scope)), 736, c.sourceGas
        );
        V.Evidence memory full = abi.decode(raw, (V.Evidence));
        IO.canonical(c.targets[18], raw, abi.encode(full));
        Items.Evidence memory e = full.inventory;
        if (
            keccak256(abi.encode(full.scope)) != keccak256(abi.encode(scope)) || e.planId == 0
                || e.collectionId != scope.collectionId
                || e.scopeSubject
                    != StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], scope)
                || e.artistId == 0 || e.sourceContextHash == 0 || e.tokenInventoryHash == 0
                || e.tokenCount == 0 || e.segmentCount == 0 || e.itemCount == 0
                || e.segmentChainHash == 0 || e.renderCriticalEvidenceHash == 0
        ) {
            revert InvalidViewFinalityInputs();
        }
        raw = IO.read(
            c.targets[18], abi.encodeCall(Inventory.sourceContext, (e.planId)), 16384, c.readGas
        );
        V.Context memory context = abi.decode(raw, (V.Context));
        IO.canonical(c.targets[18], raw, abi.encode(context));
        if (
            keccak256(
                        abi.encode(
                            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_PLAN_V1"),
                            c.chainId,
                            c.targets[18],
                            c.inventoryDependencyHash,
                            context
                        )
                    ) != e.planId || context.scope.scopeType != StreamFinalityScopeType.VIEW
                || keccak256(abi.encode(context.scope)) != keccak256(abi.encode(scope))
                || context.subject != e.scopeSubject || context.tokenCount != e.tokenCount
        ) revert InvalidViewFinalityInputs();
        Reference.SourceFacts memory f = Retained.sourceFacts(x.inventory, context);
        if (
            f.contentRootRecordHash != e.originals.rootRecordHash
                || f.snapshot.recordHash != e.originals.snapshotRecordHash
                || context.referenceRender.observation.recordHash
                    != e.originals.referenceRenderRecordHash
        ) revert InvalidViewFinalityInputs();
        raw = IO.fixedRead(
            c.targets[19],
            abi.encodeCall(Bundle.requireCoverage, (scope, e.planId, e.renderCriticalEvidenceHash)),
            288,
            c.sourceGas
        );
        V.BundleEvidence memory b = abi.decode(raw, (V.BundleEvidence));
        IO.canonical(c.targets[19], raw, abi.encode(b));
        if (
            keccak256(abi.encode(b.scope)) != keccak256(abi.encode(scope))
                || b.coverage.inventoryPlan != e.planId
                || b.coverage.renderCriticalEvidenceHash != e.renderCriticalEvidenceHash
                || b.coverage.itemCount != e.itemCount || b.coverage.evidenceChainHash == 0
                || b.coverage.bundleCoverageHash == 0
        ) revert InvalidViewFinalityInputs();
        Items.OriginalInputs memory o = e.originals;
        s.scope = scope;
        s.inputs = StreamFinalityScopeInputs(
            o.rootRecordHash,
            o.snapshotRecordHash,
            o.referenceRenderRecordHash,
            o.intentRecordHash,
            o.intentWaiverRecordHash,
            o.interviewEvidenceHash,
            o.rightsStatementRecordHash,
            o.workDescriptionRecordHash,
            e.renderCriticalEvidenceHash,
            b.coverage.bundleCoverageHash
        );
        s.nonSanctionComponents = components;
        s.postFreezePolicy = 1;
        s.sanctionPolicy = 1;
        s.contentRoot = f.contentRoot.contentRoot;
        s.leafCount = f.contentRoot.leafCount;
        s.contentRootSchemaId = Outputs.LEAF;
        s.snapshotManifestHash = f.snapshot.manifestHash;
        s.referenceRenderManifestHash = context.referenceRender.observation.payloadHash;
        s.completeBindingRecordHash = x.receipt.recordHash;
        s.adoptionRecordHash = context.adoptionRecord;
        s.adoptionProfile = f.contentBinding.adoptionProfile;
        s.outputProfile = f.contentBinding.outputProfile;
        s.membershipHash = context.tokenInventoryHash;
        s.rootBindingHash = keccak256(abi.encode(f.contentBinding));
        s.viewId = context.viewId;
        _entropy(c, scope, f, s);
        StreamCoreFinalityScopeQuery memory query = StreamCoreFinalityScopeQuery(
            uint8(scope.scopeType), scope.collectionId, scope.tokenId, scope.scopeId
        );
        raw = IO.fixedRead(
            c.targets[14],
            abi.encodeCall(IStreamCoreFinalityAdapter.scopedCoreFinalityFacts, (query)),
            416,
            c.sourceGas
        );
        StreamScopedCoreFinalityFacts memory core = abi.decode(raw, (StreamScopedCoreFinalityFacts));
        IO.canonical(c.targets[14], raw, abi.encode(core));
        if (
            !core.scopeExists || core.scopeType != uint8(scope.scopeType)
                || core.collectionId != scope.collectionId || core.tokenId != 0
                || core.scopeId != scope.scopeId
                || core.scopeManifestHash != f.snapshotSource.membership.scopeManifestHash
                || core.scopeManifestHash == 0
                || core.collectionStatus > StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED
                || core.collectionSupplyMode
                    > StreamFinalityDomains.CORE_COLLECTION_SUPPLY_MODE_UNCAPPED_OPEN
        ) revert InvalidViewFinalityInputs();
        s.coreFactsHash = StreamFinalityHashes.scopedCoreFactsHash(c.targets[0], scope, core);
    }

    function _entropy(
        Native.Config memory c,
        StreamFinalityScope memory scope,
        Reference.SourceFacts memory f,
        T.Statement memory s
    ) private view {
        StreamViewPolicyTypesV2.Binding memory p = f.snapshotSource.adoption.policy;
        if (
            p.factory != c.targets[10] || p.factoryCodeHash != c.codeHashes[10]
                || p.core != c.targets[0] || p.coreCodeHash != c.codeHashes[0]
                || p.chainId != c.chainId
                || keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))
                || !f.snapshotSource.entropy.allFrozen
                || p.inventoryPlan != f.snapshotSource.entropy.planId
                || p.inventoryHash != f.snapshotSource.entropy.inventoryHash
                || p.policyChainHash != f.snapshotSource.entropy.policyChainHash
                || p.policyCount != f.snapshotSource.entropy.policyCount
        ) {
            revert InvalidViewFinalityInputs();
        }
        bytes memory raw = IO.fixedRead(
            c.targets[10], abi.encodeCall(Factory.currentInventoryPlan, (scope)), 32, c.sourceGas
        );
        if (abi.decode(raw, (bytes32)) != p.inventoryPlan) revert InvalidViewFinalityInputs();
        raw = IO.fixedRead(
            c.targets[10],
            abi.encodeCall(Factory.sourceSetForPlan, (p.inventoryPlan)),
            64,
            c.readGas
        );
        if (keccak256(raw) != keccak256(abi.encode(p.sourceSet, p.sourceSetCodeHash))) {
            revert InvalidViewFinalityInputs();
        }
        raw = IO.fixedRead(
            c.targets[10],
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (scope)),
            128,
            c.sourceGas
        );
        StreamFinalityCurrentComponentRoute memory route =
            abi.decode(raw, (StreamFinalityCurrentComponentRoute));
        IO.canonical(c.targets[10], raw, abi.encode(route));
        if (
            route.component != p.sourceSet || route.codeHash != p.sourceSetCodeHash
                || route.componentType != StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR
                || route.interfaceId != type(IStreamArtworkScopedFinalityComponent).interfaceId
        ) revert InvalidViewFinalityInputs();
        IO.pin(p.sourceSet, p.sourceSetCodeHash);
        s.entropy = T.Entropy(
            p.sourceSet,
            p.sourceSetCodeHash,
            keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"),
            p.inventoryPlan,
            p.inventoryHash,
            p.policyChainHash,
            p.policyCount,
            f.snapshot.profileHash,
            StreamViewPreservationReferenceDefinitionsV1.PROFILE_HASH
        );
    }

    function manifestDependencies(Native.Config memory c)
        public
        pure
        returns (Manifest.Dependencies memory d)
    {
        uint256[5] memory roles = [uint256(0), 1, 4, 5, 12];
        for (uint256 i; i < 5; ++i) {
            d.targets[i] = c.targets[roles[i]];
            d.codeHashes[i] = c.codeHashes[roles[i]];
        }
        d.chainId = c.chainId;
        d.readGas = c.readGas;
    }

    function currentComponents(Native.Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (StreamFinalityComponentExpectation[] memory)
    {
        Scoped.Config memory s = abi.decode(abi.encode(c), (Scoped.Config));
        return Scoped.currentComponents(s, scope);
    }
}
import { StreamViewPolicyTypesV2 } from "../metadata/StreamViewPolicyTypesV2.sol";
import {
    StreamViewPreservationReferenceDefinitionsV1
} from "../records/StreamViewPreservationReferenceDefinitionsV1.sol";
