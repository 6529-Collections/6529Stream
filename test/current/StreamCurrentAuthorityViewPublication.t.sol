// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityViewPublicationFixture
} from "../helpers/StreamCurrentAuthorityViewPublicationFixture.sol";
import {
    IStreamViewAdoptionRouter as ViewRouter
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";
import {
    IStreamScopedContentRootPublication as ScopedRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Genuine original-A current-authority graph through VIEW publication.
/// @dev Only the inherited external randomness provider is a double. Registry analysis and
/// locally signed archive observations remain fixture assertions. No browser, reference,
/// render inventory, archive bundle, sanction or terminal-Finality completion is claimed.
contract StreamCurrentAuthorityViewPublicationTest is StreamCurrentAuthorityViewPublicationFixture {
    function testCurrentAuthorityViewAdoptionRetriesIdenticalSafeCallAfterActualConsent() public {
        _authorityPrepareViewArtwork();
        bytes32 originalRoster = _authorityOriginalRosterHash();
        require(
            assemblyCore.totalSupply() == 2 && assemblyCore.collectionMintedEver(1) == 2
                && assemblyInventory.dependencyHash()
                    != keccak256(abi.encode(assemblyInventory.dependencies())),
            "actual two paid tokens and original composite S/O/D commitment"
        );
        _requireOriginalViewAttribution();
        authorityViewProbeMissingConsent = true;
        _authorityDeclareAndAdoptView();
        require(
            authorityViewMissingConsentObserved && authorityViewAdoptionTransactionHash != 0
                && authorityViewAdoption.original.artistConsent
                    == authorityViewAdoption.rendererConsent
                && assemblyRouter.consumedArtistContentConsent(
                    authorityViewAdoption.rendererConsent
                ),
            "missing-consent rollback followed by identical signed Safe retry"
        );
        require(
            authorityViewAdoption.scope.scopeType == StreamFinalityScopeType.VIEW
                && authorityViewAdoption.scope.collectionId == 1
                && authorityViewAdoption.scope.tokenId == 0
                && authorityViewAdoption.scope.scopeId != 0
                && assemblyMembership.requireScopeMembership(authorityViewAdoption.scope).tokenCount
                == 2
                && ViewRouter(address(assemblyRouter)).viewAdoptionHead(authorityViewAdoption.scope)
                == authorityViewAdoption.adoptionRecord,
            "completed actual membership and original adopted head"
        );
        require(
            _authorityOriginalRosterHash() == originalRoster
                && !assemblyCore.collectionFreezeStatus(1)
                && authorityViewPublication.rootRecord == 0,
            "original identity retained and publication window still open"
        );
        _authorityRequireViewAdoption();
        _authorityRequireViewServing();
    }

    function testCurrentAuthorityViewPublicationPreservesCollectionAndOriginalRootWitness() public {
        _authorityPrepareViewArtwork();
        _authorityDeclareAndAdoptView();
        bytes32 originals = _authorityViewCollectionRecordsHash();
        bytes32 roster = _authorityOriginalRosterHash();
        _authorityPublishViewPreservation();
        require(
            authorityViewRecords.workPublication.authorizationHash != 0
                && authorityViewRecords.waiverPublication.authorizationHash != 0
                && authorityViewRecords.workPublication.nonce
                    != authorityViewRecords.waiverPublication.nonce
                && authorityViewRecords.rightsRecord != 0,
            "actual Work/waiver op24 and separately authorized Rights record"
        );
        require(
            authorityViewPublication.rootConsent != authorityViewAdoption.rendererConsent
                && authorityViewPublication.rootConsentNonce
                    != authorityViewAdoption.rendererConsentNonce
                && authorityViewPublication.rootConsentInput.familyId == keccak256("CONTENT_ROOT")
                && authorityViewPublication.beforeRootAggregate.revision == 0
                && authorityViewPublication.rootAggregate.revision == 1
                && authorityViewPublication.legacyFamilyHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"),
                            block.chainid,
                            address(assemblyRouter),
                            address(assemblyCore),
                            uint256(1)
                        )
                    ),
            "distinct op17 root with original canonical-empty legacy preimage"
        );
        require(
            authorityViewPublication.preservationRegistration.registrationHash != 0
                && authorityViewPublication.snapshotReceipt.authorizationClass == 7
                && authorityViewPublication.snapshotReceipt.displayAuthorizationClass == 7
                && ScopedRoot(address(assemblyRouter))
                    .scopedContentRootHead(authorityViewAdoption.scope)
                == authorityViewPublication.rootRecord
                && assemblyRouter.collectionContentRootHead(1) == 0,
            "real admitted producer, granted snapshot and VIEW-only root"
        );
        bytes32 publication = keccak256(abi.encode(authorityViewPublication));
        _authorityFreezeViewArtwork();
        require(
            assemblyCore.collectionFreezeStatus(1) && assemblyCore.collectionBurnsBlocked(1)
                && assemblyCore.collectionStatus(1) == 2
                && keccak256(abi.encode(authorityViewPublication)) == publication
                && _authorityOriginalRosterHash() == roster
                && _authorityViewCollectionRecordsHash() == originals,
            "actual final freezes retain original publication, S/O/D and COLLECTION state"
        );
        _requireOriginalViewAttribution();
        _authorityRequireViewPublication();
    }

    function _requireOriginalViewAttribution() private view {
        require(
            avAttribution.preservationAttributionProfile()
                    == keccak256("6529STREAM_NON_SANCTION_ATTRIBUTION_V1")
                && avRenderer.configuration().preservationAttribution == address(avAttribution)
                && address(avAttribution) != address(assemblyPreservationProjection)
                && address(avRenderer) != assemblyPreservationProducer,
            "VIEW retains its original projection and distinct preservation producer"
        );
    }
}
