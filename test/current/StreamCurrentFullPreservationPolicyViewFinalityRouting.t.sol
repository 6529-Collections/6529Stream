// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentFullPreservationPolicyViewCompleteFixture.sol";
import {
    IStreamFinalityProfileSources as RoutingProfiles
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamFinalityPreparedScopeEvidence as RoutingPrepared
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityPreparedScopeEvidence.sol";
import {
    IStreamFinalityPreparedSanctionReview as RoutingPreparedReview
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityPreparedSanctionReview.sol";
import {
    IStreamViewPreservationEvidenceBindingV1 as RoutingSnapshotBinding
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as RoutingBasicBinding
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    StreamFinalityNativeEvidenceProvider as RoutingNativeHost
} from "../../smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol";
import {
    StreamFinalityNativeProviderReads as RoutingNative
} from "../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationConfigurationV1 as RoutingView
} from "../../smart-contracts/domains/finality/StreamFinalityViewPreservationConfigurationV1.sol";
import {
    StreamMetadataSubjects as RoutingSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope as RoutingScope,
    StreamFinalityScopeType as RoutingScopeType,
    StreamFinalityComponentExpectation as RoutingComponent
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface ViewFinalityRoutingVm {
    function expectRevert(bytes calldata) external;
    function prank(address) external;
    function etch(address, bytes calldata) external;
}

/// @notice Actual same-provider VIEW catalogue and original prepared-caller routing guards.
/// @dev Catalogue selection proves identities before future evidence exists. The only caller
/// substitution below probes the original Registry authorization guard after runtime drift;
/// it does not fabricate component validation, evidence, a browser observation or finality.
/// This graph retains the complete fixture's diagnostic caps; transaction fit remains unproved.
contract StreamCurrentFullPreservationPolicyViewFinalityRoutingTest is
    StreamCurrentFullPreservationPolicyViewCompleteFixture
{
    ViewFinalityRoutingVm private constant routingVm =
        ViewFinalityRoutingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private routingSourceConfigurationBefore;
    RoutingProfiles.Profile[2] private routingOriginalProfiles;

    function testActualViewCataloguePrecedesFuturePublicationsAndBindsCompleteReceipt() public {
        _constructFullPolicyPublication();
        _requireRoutingCatalogue(_futureRoutingView());
        require(
            fullPolicyViewAdoption == 0 && viewPublicationCheckpoint == 0
                && viewPublicationOutputManifest == 0 && assemblyViewSnapshotRecord == 0
                && assemblyViewOriginalContentRoot == 0 && assemblyViewReferenceRecord == 0
                && viewRenderInventoryPlan == 0,
            "catalogue selection requires no future evidence or manufactured current record"
        );
        require(
            RoutingProfiles(address(assemblyProvider)).finalitySourceConfigurationHash()
                == routingSourceConfigurationBefore,
            "the separate complete VIEW receipt does not rewrite original source configuration"
        );
    }

    function testActualViewCatalogueRejectsEachMalformedScopeBeforeSourceResolution() public {
        _constructFullPolicyPublication();
        RoutingProfiles provider = RoutingProfiles(address(assemblyProvider));
        _requireRoutingCatalogue(_futureRoutingView());
        for (uint256 i; i < 3; ++i) {
            RoutingScope memory malformed = _futureRoutingView();
            if (i == 0) malformed.collectionId = 0;
            else if (i == 1) malformed.tokenId = 1;
            else malformed.scopeId = 0;
            routingVm.expectRevert(
                abi.encodeWithSelector(RoutingSubjects.InvalidMetadataScope.selector)
            );
            provider.finalitySourcesForScope(malformed);
        }
        _requireRoutingCatalogue(_futureRoutingView());
    }

    function testActualOperativeSnapshotGettersNeedOriginalSourceBudgetAndRetainHistoryOnDrift()
        public
    {
        _constructFullPolicyPublication();
        address provider = address(assemblyProvider);
        RoutingNative.Config memory original = RoutingNativeHost(provider).nativeConfiguration();
        require(original.readGas < original.sourceGas, "unchanged distinct original budgets");
        bytes[3] memory calls;
        calls[0] = abi.encodeCall(RoutingSnapshotBinding.viewPreservationSnapshotHost, ());
        calls[1] = abi.encodeCall(RoutingSnapshotBinding.viewPreservationSnapshotCodeHash, ());
        calls[2] = abi.encodeCall(RoutingSnapshotBinding.viewPreservationSnapshotValidationGas, ());
        bytes[3] memory expected;
        expected[0] = abi.encode(viewCompleteConfiguration.snapshotHost);
        expected[1] = abi.encode(viewCompleteConfiguration.snapshotCodeHash);
        expected[2] = abi.encode(viewCompleteConfiguration.validationGas);
        for (uint256 i; i < 3; ++i) {
            // Each genuine getter internally reserves original.readGas for dependency reads.
            // Reusing that same cap outside the getter cannot satisfy nested forwarding.
            (bool small,) = provider.staticcall{ gas: original.readGas }(calls[i]);
            require(!small, "operative getter cannot run inside the original scalar read cap");
            (bool enough, bytes memory returned) =
                provider.staticcall{ gas: original.sourceGas }(calls[i]);
            require(
                enough && returned.length == 32 && keccak256(returned) == keccak256(expected[i]),
                "existing source budget returns the exact canonical bound typed word"
            );
        }
        // The real catalogue invokes Configuration.resolve using the repaired getter caps.
        _requireRoutingCatalogue(_futureRoutingView());
        bytes32 basicBefore =
            keccak256(abi.encode(RoutingBasicBinding(provider).viewPreservationBindingReceipt()));
        address snapshot = viewCompleteConfiguration.snapshotHost;
        bytes memory savedRuntime = snapshot.code;
        require(snapshot.codehash == viewCompleteConfiguration.snapshotCodeHash);
        bytes memory catalogueCall =
            abi.encodeCall(RoutingProfiles.finalitySourcesForScope, (_futureRoutingView()));
        routingVm.etch(snapshot, hex"00");
        (bool driftAccepted,) = provider.staticcall(catalogueCall);
        require(!driftAccepted, "actual bound runtime drift rejects the previously valid catalogue");
        require(
            keccak256(abi.encode(RoutingBasicBinding(provider).viewPreservationBindingReceipt()))
                    == basicBefore
                && RoutingBasicBinding(provider).viewPreservationBindingStatus() == 1
                && RoutingProfiles(provider).finalitySourceConfigurationHash()
                    == routingSourceConfigurationBefore,
            "runtime drift preserves basic admission and original source configuration"
        );
        _requireCompleteRoutingHistory();
        routingVm.etch(snapshot, savedRuntime);
        require(snapshot.codehash == viewCompleteConfiguration.snapshotCodeHash);
        _requireRoutingCatalogue(_futureRoutingView());
        _requireCompleteRoutingHistory();
    }

    function testActualPreparedViewMethodsRejectDirectCallerBeforeAnyViewWork() public {
        _constructFullPolicyPublication();
        RoutingNative.Config memory original =
            RoutingNativeHost(address(assemblyProvider)).nativeConfiguration();
        require(
            original.targets[12] == address(assemblyFinality)
                && address(this) != original.targets[12]
        );
        RoutingPrepared prepared = RoutingPrepared(address(assemblyProvider));
        RoutingPreparedReview review = RoutingPreparedReview(address(assemblyProvider));
        RoutingComponent[] memory absentComponents = new RoutingComponent[](0);
        bytes memory expected =
            abi.encodeWithSelector(RoutingNativeHost.NativeProviderOriginalRegistryOnly.selector);
        for (uint256 i; i < 2; ++i) {
            RoutingScope memory scope = _futureRoutingView();
            if (i == 1) scope.collectionId = 0;
            routingVm.expectRevert(expected);
            prepared.requirePreparedFinalityScopeInputs(scope, 0, absentComponents);
            routingVm.expectRevert(expected);
            review.requirePreparedFinalityScopeInputsAndReview(scope, 0, absentComponents);
        }
        require(viewRenderInventoryPlan == 0 && assemblyViewReferenceRecord == 0);
        _requireCompleteRoutingHistory();
    }

    function testActualPreparedViewMethodsRejectOriginalRegistryRuntimeDriftBeforeDispatch()
        public
    {
        _constructFullPolicyPublication();
        RoutingNative.Config memory original =
            RoutingNativeHost(address(assemblyProvider)).nativeConfiguration();
        address registry = original.targets[12];
        require(
            registry == address(assemblyFinality) && registry.codehash == original.codeHashes[12]
        );
        _requireRoutingCatalogue(_futureRoutingView());
        bytes memory savedRuntime = registry.code;
        RoutingPrepared prepared = RoutingPrepared(address(assemblyProvider));
        RoutingPreparedReview review = RoutingPreparedReview(address(assemblyProvider));
        RoutingComponent[] memory absentComponents = new RoutingComponent[](0);
        RoutingScope memory malformed = _futureRoutingView();
        malformed.collectionId = 0;
        bytes memory expected =
            abi.encodeWithSelector(RoutingNativeHost.NativeProviderOriginalRegistryOnly.selector);
        routingVm.etch(registry, hex"00");
        routingVm.expectRevert(expected);
        routingVm.prank(registry);
        prepared.requirePreparedFinalityScopeInputs(malformed, 0, absentComponents);
        routingVm.expectRevert(expected);
        routingVm.prank(registry);
        review.requirePreparedFinalityScopeInputsAndReview(malformed, 0, absentComponents);
        routingVm.etch(registry, savedRuntime);
        require(registry.codehash == original.codeHashes[12]);
        _requireRoutingCatalogue(_futureRoutingView());
        _requireCompleteRoutingHistory();
    }

    function testActualCompleteViewKeepsOriginalCollectionAndScopedStaticCatalogues() public {
        _constructFullPolicyPublication();
        RoutingProfiles provider = RoutingProfiles(address(assemblyProvider));
        for (uint8 i; i < 2; ++i) {
            require(
                keccak256(abi.encode(provider.finalitySourceProfile(i)))
                    == keccak256(abi.encode(routingOriginalProfiles[i])),
                "both original fixed catalogue entries remain exact after complete VIEW binding"
            );
        }
        RoutingScope memory collection = RoutingScope(RoutingScopeType.COLLECTION, 1, 0, 0);
        RoutingProfiles.Sources memory selected = provider.finalitySourcesForScope(collection);
        require(
            keccak256(abi.encode(selected.scope)) == keccak256(abi.encode(collection))
                && keccak256(abi.encode(selected.profile))
                    == keccak256(abi.encode(routingOriginalProfiles[0])),
            "the actual original collection keeps its original catalogue selection"
        );
        _configureFullPolicyStatic();
        // Genuine STATIC activation on collection1 is sufficient for this original catalogue
        // lookup. The unopened RELEASE scope does not claim membership or accepted evidence.
        RoutingScope memory release = RoutingScope(
            RoutingScopeType.RELEASE, 1, 0, keccak256("unopened release catalogue regression")
        );
        selected = provider.finalitySourcesForScope(release);
        require(
            fullPolicyStaticConfig != 0
                && keccak256(abi.encode(selected.scope)) == keccak256(abi.encode(release))
                && keccak256(abi.encode(selected.profile))
                    == keccak256(abi.encode(routingOriginalProfiles[1])),
            "actual STATIC activation retains original scoped sources"
        );
        require(provider.finalitySourceConfigurationHash() == routingSourceConfigurationBefore);
        _requireRoutingCatalogue(_futureRoutingView());
    }

    function _viewBeforeCompleteBind() internal override {
        RoutingProfiles provider = RoutingProfiles(address(assemblyProvider));
        routingSourceConfigurationBefore = provider.finalitySourceConfigurationHash();
        require(routingSourceConfigurationBefore != 0);
        for (uint8 i; i < 2; ++i) {
            routingOriginalProfiles[i] = provider.finalitySourceProfile(i);
        }
    }

    function _requireRoutingCatalogue(RoutingScope memory scope) private view {
        RoutingNative.Config memory original =
            RoutingNativeHost(address(assemblyProvider)).nativeConfiguration();
        RoutingProfiles.Sources memory selected =
            RoutingProfiles(address(assemblyProvider)).finalitySourcesForScope(scope);
        CompleteSources.Receipt memory receipt =
            CompleteSources(address(assemblyProvider)).viewFinalitySourcesReceipt();
        require(
            receipt.recordHash == viewCompleteBindingReceipt.recordHash
                && RoutingView.PROFILE == keccak256("6529STREAM_VIEW_PRESERVATION_FINALITY_V1")
                && selected.profile.profileHash == RoutingView.PROFILE
                && keccak256(abi.encode(selected.scope)) == keccak256(abi.encode(scope))
                && selected.profile.referenceRender == address(viewReference)
                && selected.profile.referenceRenderCodeHash == address(viewReference).codehash
                && selected.profile.snapshots == address(assemblyViewPreservationSnapshot)
                && selected.profile.snapshotsCodeHash
                    == address(assemblyViewPreservationSnapshot).codehash
                && selected.profile.entropyFactory == address(fullPolicyScopedSources)
                && selected.profile.entropyFactoryCodeHash
                    == address(fullPolicyScopedSources).codehash,
            "complete VIEW catalogue uses the actual bound snapshot/reference and original scoped factory"
        );
        bytes32 literalConfiguration = keccak256(
            abi.encode(
                RoutingView.PROFILE,
                original.chainId,
                address(assemblyProvider),
                keccak256(abi.encode(original)),
                receipt.recordHash
            )
        );
        require(selected.profile.configurationHash == literalConfiguration);
    }

    function _requireCompleteRoutingHistory() private view {
        require(
            keccak256(
                abi.encode(CompleteSources(address(assemblyProvider)).viewFinalitySourcesReceipt())
            ) == keccak256(abi.encode(viewCompleteBindingReceipt)),
            "authorization probes cannot change complete admission history"
        );
    }

    function _futureRoutingView() private pure returns (RoutingScope memory) {
        return RoutingScope(
            RoutingScopeType.VIEW, 1, 0, keccak256("future canonical VIEW catalogue scope")
        );
    }
}
