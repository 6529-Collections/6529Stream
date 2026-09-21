// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityViewReferenceFixture
} from "../helpers/StreamCurrentAuthorityViewReferenceFixture.sol";
import {
    StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1 as Discovery
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyDiscoveryV1.sol";
import {
    StreamFinalityViewPreservationDiscoveryV1 as ViewDiscovery
} from "../../smart-contracts/domains/finality/StreamFinalityViewPreservationDiscoveryV1.sol";
import {
    StreamFinalityDiscoveryTypes as D
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamArtworkScopedFinalityComponent as Component
} from "../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    IStreamFinalityCurrentComponentRoutes as Routes,
    StreamFinalityCurrentComponentRoute
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityComponentState,
    StreamFinalityComponentExpectation
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamArtistOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistBindingOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistSanctionOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistSanctionOwner.sol";
import {
    StreamArtistOnboardingTypes as Artist
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamMetadataServingFacts as Serving
} from "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamViewPreservationReferenceTypesV1 as Reference
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";

interface CurrentViewDiscoveryVm {
    function etch(address, bytes calldata) external;
}

/// @notice Actual complete-bound current-authority original-A VIEW discovery composition.
/// @dev No provider, component, current-source or receipt mocks are installed here. Inherited
/// randomness, synthetic partial Registry analysis and explicitly synthetic PNG/ZIP observations
/// retain their stated fixture boundaries. The tests require all nine real components; they do
/// not skip or turn an incomplete graph into a passing positive. Native execution and nested-call
/// gas compatibility remain pending. No sanction, archive bundle or terminal Finality is asserted.
contract StreamCurrentAuthorityViewDiscoveryTest is StreamCurrentAuthorityViewReferenceFixture {
    CurrentViewDiscoveryVm private constant dvm =
        CurrentViewDiscoveryVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testActualBoundViewCatalogueAndNineComponentsAgreeAfterReferenceLock() public {
        _prepareWithoutReference();
        _requireCatalogue();
        require(authorityViewReferenceRecord == 0, "reference is actually absent");
        (bool hasReferenceState, bytes memory referenceState) = address(avReference)
            .staticcall(
                abi.encodeCall(Component.finalityStateForScope, (authorityViewAdoption.scope))
            );
        if (hasReferenceState) {
            require(
                !abi.decode(referenceState, (StreamFinalityComponentState)).frozen,
                "unpublished reference cannot be frozen"
            );
        }
        // Complete source binding and a locked root/snapshot are not reference evidence.
        _rejectFacts(authorityViewAdoption.scope);
        _authorityPublishViewReference();
        bytes32 beforeReads = _retainedState();
        _requireCatalogue();
        require(_requireNine() != 0, "real nine-component hash");
        _requireOriginalAnchors();
        require(_retainedState() == beforeReads, "discovery creates no sanction or Registry state");
    }

    function testActualProviderRuntimeDriftRejectsAndRestoredDiscoveryRetriesExactly() public {
        _prepareCompleteReference();
        bytes32 beforeHash = _requireNine();
        bytes32 beforeState = _retainedState();
        bytes memory originalRuntime = address(assemblyProvider).code;
        bytes memory expected = abi.encodeWithSelector(
            Discovery.DiscoveryDependency.selector, address(assemblyProvider)
        );
        dvm.etch(address(assemblyProvider), hex"00");
        (bool ok, bytes memory errorData) = address(assemblyDiscovery)
            .staticcall(
                abi.encodeCall(
                    assemblyDiscovery.nonSanctionDiscoveryFacts, (authorityViewAdoption.scope)
                )
            );
        require(
            !ok && keccak256(errorData) == keccak256(expected), "host pins provider before facts"
        );
        (ok, errorData) = address(assemblyDiscovery)
            .staticcall(
                abi.encodeCall(
                    assemblyDiscovery.nonSanctionComponentAt,
                    (authorityViewAdoption.scope, uint256(0))
                )
            );
        require(
            !ok && keccak256(errorData) == keccak256(expected), "host pins provider before a slot"
        );
        dvm.etch(address(assemblyProvider), originalRuntime);
        _requireCatalogue();
        require(
            _requireNine() == beforeHash, "same exact original scope and ordered expectations retry"
        );
        _requireOriginalAnchors();
        require(
            _retainedState() == beforeState,
            "failed reads and exact runtime restore preserve history"
        );
    }

    function testActualWrongViewScopesAndOutOfRangeIndexDoNotChangeValidDiscovery() public {
        _prepareCompleteReference();
        bytes32 beforeHash = _requireNine();
        bytes32 beforeState = _retainedState();
        StreamFinalityScope memory wrong =
            abi.decode(abi.encode(authorityViewAdoption.scope), (StreamFinalityScope));
        wrong.scopeId = keccak256("this VIEW was never declared or admitted");
        require(wrong.scopeId != authorityViewAdoption.scope.scopeId, "distinct scope negative");
        _rejectFacts(wrong);
        wrong = abi.decode(abi.encode(authorityViewAdoption.scope), (StreamFinalityScope));
        wrong.tokenId = authorityViewAdoption.tokens[0];
        _rejectFacts(wrong);
        (bool ok, bytes memory errorData) = address(assemblyDiscovery)
            .staticcall(
                abi.encodeCall(
                    assemblyDiscovery.nonSanctionComponentAt,
                    (authorityViewAdoption.scope, uint256(9))
                )
            );
        require(
            !ok
                && keccak256(errorData)
                    == keccak256(
                        abi.encodeWithSelector(Discovery.DiscoveryIndex.selector, uint256(9))
                    ),
            "nine entries have no tenth placeholder"
        );
        require(
            _requireNine() == beforeHash, "original scope remains byte-identical after negatives"
        );
        _requireCatalogue();
        _requireOriginalAnchors();
        require(
            _retainedState() == beforeState, "scope failures preserve publication and owner records"
        );
    }

    function _prepareWithoutReference() private {
        _authorityPrepareViewArtwork();
        _authorityDeclareAndAdoptView();
        _authorityPublishViewPreservation();
        _authorityFreezeViewArtwork();
        _requireOriginalAnchors();
    }

    function _prepareCompleteReference() private {
        _prepareWithoutReference();
        _authorityPublishViewReference();
        require(
            authorityViewReferenceRecord != 0
                && authorityViewReferenceReceipt.observation.recordHash
                    == authorityViewReferenceRecord,
            "actual reference publication"
        );
        _requireCatalogue();
    }

    function _requireCatalogue() private view {
        D.Configuration memory c = Discovery(address(assemblyDiscovery)).configuration();
        Profiles.Sources memory actual = Profiles(address(assemblyProvider))
            .finalitySourcesForScope(authorityViewAdoption.scope);
        Profiles.Profile memory reconstructed =
            ViewDiscovery.profile(c, authorityViewAdoption.scope);
        require(
            keccak256(abi.encode(actual.scope))
                    == keccak256(abi.encode(authorityViewAdoption.scope))
                && keccak256(abi.encode(actual.profile)) == keccak256(abi.encode(reconstructed)),
            "real provider catalogue equals fixed bound-source reconstruction"
        );
        require(
            actual.profile.profileHash == keccak256("6529STREAM_VIEW_PRESERVATION_FINALITY_V1")
                && actual.profile.referenceRender == address(avReference)
                && actual.profile.referenceRenderCodeHash == address(avReference).codehash
                && actual.profile.snapshots == address(avSnapshot)
                && actual.profile.snapshotsCodeHash == address(avSnapshot).codehash
                && actual.profile.entropyFactory == sourceScopedPolicyEntropyFactory
                && actual.profile.entropyFactoryCodeHash
                    == sourceScopedPolicyEntropyFactory.codehash,
            "exact independently deployed VIEW sources"
        );
        require(
            Discovery(address(assemblyDiscovery)).sourceConfigurationHash() == avOriginalSourceHash
                && Profiles(address(assemblyProvider)).finalitySourceConfigurationHash()
                    == avOriginalSourceHash && c.provider == address(assemblyProvider),
            "constructor source configuration remains original"
        );
    }

    function _requireNine() private view returns (bytes32 hash) {
        StreamFinalityScope memory scope = authorityViewAdoption.scope;
        (uint256 count, bytes32 reported) = assemblyDiscovery.nonSanctionDiscoveryFacts(scope);
        require(count == 9, "all nine actual non-sanction families");
        (bytes32[9] memory families, address[9] memory targets) = _expectedRoutes();
        StreamFinalityComponentExpectation[] memory expected =
            new StreamFinalityComponentExpectation[](9);
        StreamFinalityCurrentComponentRoute[] memory routes =
            Routes(address(assemblyDiscovery)).requireCurrentRoutes(scope, false);
        require(routes.length == 9, "same complete route roster");
        for (uint256 i; i < 9; ++i) {
            StreamFinalityComponentState memory live =
                Component(targets[i]).finalityStateForScope(scope);
            require(
                live.frozen && live.componentType == families[i] && live.component == targets[i]
                    && live.interfaceId == type(Component).interfaceId
                    && live.codeHash == targets[i].codehash && live.moduleVersion != 0
                    && live.manifestHash != 0 && live.dataHash != 0,
                "actual frozen full component state"
            );
            expected[i] = StreamFinalityComponentExpectation(
                live.componentType,
                live.component,
                live.interfaceId,
                live.codeHash,
                live.moduleVersion,
                live.manifestHash,
                live.dataHash
            );
            StreamFinalityComponentExpectation memory discovered =
                assemblyDiscovery.nonSanctionComponentAt(scope, i);
            require(
                keccak256(abi.encode(discovered)) == keccak256(abi.encode(expected[i])),
                "each of seven expectation words matches its real producer"
            );
            require(
                routes[i].componentType == families[i] && routes[i].component == targets[i]
                    && routes[i].interfaceId == live.interfaceId
                    && routes[i].codeHash == live.codeHash,
                "route identity matches full-state projection"
            );
            require(
                families[i] != keccak256("ARTIST_SANCTION")
                    && families[i] != keccak256("PLATFORM_WORKS_DECLARATION")
                    && (i == 0 || families[i - 1] < families[i]),
                "strict original non-sanction family order"
            );
        }
        hash = keccak256(abi.encode(keccak256("6529STREAM_FINALITY_COMPONENTS_V1"), expected));
        require(
            hash == reported && assemblyFinality.computeComponentsHash(expected) == hash,
            "literal and original Registry component hash agree"
        );
    }

    function _expectedRoutes()
        private
        view
        returns (bytes32[9] memory families, address[9] memory targets)
    {
        D.Configuration memory c = Discovery(address(assemblyDiscovery)).configuration();
        families = [
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
        for (uint256 i; i < 6; ++i) {
            targets[i] = c.routerAdapters[i];
        }
        targets[6] = c.metadataAdapter;
        targets[7] = authorityViewAdoption.sourceSet;
        targets[8] = address(avReference);
        for (uint256 i = 1; i < 9; ++i) {
            for (uint256 j = i; j != 0 && families[j] < families[j - 1]; --j) {
                (families[j], families[j - 1]) = (families[j - 1], families[j]);
                (targets[j], targets[j - 1]) = (targets[j - 1], targets[j]);
            }
        }
    }

    function _requireOriginalAnchors() private view {
        (address registry, bytes32 runtime) = assemblyRouter.originalFinalityAnchor(1);
        Serving.ArtistPresentation memory original = assemblyRouter.artistPresentation(1);
        require(
            registry == address(assemblyFinality) && runtime == address(assemblyFinality).codehash
                && address(assemblyFinality.sanctionReads()) == assemblySuite.registry
                && assemblyFinality.scopeEvidenceProvider() == address(assemblyProvider)
                && assemblyFinality.finalityDiscovery() == address(assemblyDiscovery)
                && original.registry == assemblySuite.registry
                && original.registryCodeHash == assemblySuite.registry.codehash,
            "unchanged original Artist, Router, provider and Registry anchors"
        );
        require(
            _scopeSanction(authorityViewAdoption.scope) == 0
                && _scopeSanction(StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0))
                    == 0,
            "no VIEW or collection sanction synthesized"
        );
        require(
            !assemblyFinality.artworkScopeFinalityRecord(authorityViewAdoption.scope).finalized
                && !assemblyFinality.collectionFinalityRecord(1).finalized,
            "discovery is not finalization"
        );
        require(
            _authorityOriginalRosterHash() == avOriginalRosterHash,
            "original S/O/D inventory and owner graph retained"
        );
    }

    function _scopeSanction(StreamFinalityScope memory scope) private view returns (bytes32) {
        Artist.Binding memory binding_ =
            IStreamArtistBindingOwner(assemblySuite.owners[0]).binding(1);
        return IStreamArtistSanctionOwner(assemblySuite.owners[6])
            .sanctionForAssociation(
                binding_.artistId,
                binding_.generation,
                binding_.bindingHash,
                uint8(scope.scopeType),
                scope.collectionId,
                scope.tokenId,
                scope.scopeId
            );
    }

    function _retainedState() private view returns (bytes32) {
        bytes32[7] memory ownerSnapshots;
        for (uint256 i; i < 7; ++i) {
            ownerSnapshots[i] = keccak256(
                abi.encode(IStreamArtistOwner(assemblySuite.owners[i]).ownerStateSnapshotV2())
            );
        }
        return keccak256(
            abi.encode(
                ownerSnapshots,
                _authorityOriginalRosterHash(),
                _authorityViewCollectionRecordsHash(),
                authorityViewAdoption.original,
                authorityViewPublication,
                _referenceHistoryHash(),
                assemblyRouter.artistPresentation(1),
                assemblyFinality.artworkScopeFinalityRecord(authorityViewAdoption.scope),
                assemblyFinality.collectionFinalityRecord(1),
                _scopeSanction(authorityViewAdoption.scope),
                _scopeSanction(StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0))
            )
        );
    }

    function _referenceHistoryHash() private view returns (bytes32) {
        (Reference.Publication memory publication, Reference.Receipt memory receipt) =
            avReference.referenceRecord(authorityViewReferenceRecord);
        require(
            keccak256(abi.encode(publication))
                    == keccak256(abi.encode(authorityViewReferencePublication))
                && keccak256(abi.encode(receipt))
                    == keccak256(abi.encode(authorityViewReferenceReceipt)),
            "real original reference fields remain exact"
        );
        return keccak256(
            abi.encode(
                authorityViewReferenceRecord,
                publication,
                receipt,
                avReference.referencePayload(authorityViewReferenceRecord),
                avReference.referenceLock(authorityViewAdoption.scope),
                avReference.referenceCount(authorityViewAdoption.scope)
            )
        );
    }

    function _rejectFacts(StreamFinalityScope memory scope) private view {
        (bool ok,) = address(assemblyDiscovery)
            .staticcall(abi.encodeCall(assemblyDiscovery.nonSanctionDiscoveryFacts, (scope)));
        require(!ok, "incomplete or wrong VIEW cannot return non-sanction facts");
    }
}
