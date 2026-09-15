// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPlatformReads.sol";
import "./StreamArtistAttributionPolicy.sol";
import "./StreamArtistHashes.sol";
import "./StreamArtistAuthorityPolicy.sol";
import "./StreamArtistTemplateEconomicsReads.sol";

import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import "../../interfaces/stream/artist/IStreamArtistContentFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistContentMutationFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyFacts.sol";
import { StreamArtistRoyaltyModeReads } from "./StreamArtistRoyaltyModeReads.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyScopeFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryScopeFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateConsentFacts.sol";
import "../../vendor/openzeppelin/IERC165.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyPreview.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed original payout/profile validation over the constructor-bound suite.
library StreamArtistProfilePayoutReads {
    function artistPayoutAccount(T.SuiteConfiguration memory _suite, bytes32 artistId)
        public
        view
        returns (address, bytes32)
    {
        (
            T.Payout memory stable,
            T.Payout memory candidate,
            R.ProvisionalAssociation memory association
        ) = IStreamArtistPayoutTransitionOwner(_suite.owners[5]).payoutCandidates(artistId);
        if (
            candidate.recordHash != bytes32(0)
                && IStreamArtistRotationOwner(_suite.owners[2])
                    .provisionalRecordEligible(artistId, association)
        ) {
            return (candidate.account, candidate.recordHash);
        }
        return (stable.account, stable.recordHash);
    }

    function collaboratorAt(
        T.SuiteConfiguration memory _suite,
        uint256 collectionId,
        uint64 generation,
        uint256 index
    ) public view returns (C.Row memory) {
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0])
            .bindingAt(collectionId, generation);
        T.CollaboratorRecord memory p = IStreamArtistCollaboratorBindingOwner(_suite.owners[0])
            .collaboratorTerm(collectionId, generation, index);
        C.Join memory j = IStreamArtistCollaboratorRecordsOwner(_suite.owners[1])
            .acceptedRow(b.bindingHash, p.account, p.role, p.shareLabelId);
        return C.Row(
            p.account,
            p.role,
            p.shareLabelId,
            j.artistId,
            j.acceptanceRecordHash,
            j.artistId != bytes32(0)
        );
    }

    function collaboratorPayoutAccount(
        T.SuiteConfiguration memory _suite,
        bytes32 artistId,
        address account
    ) public view returns (address, bytes32) {
        if (!IStreamArtistCollaboratorRecordsOwner(_suite.owners[1])
                .identityLinked(artistId, account)) return (address(0), bytes32(0));
        return artistPayoutAccount(_suite, artistId);
    }

    function _requireProfilePayout(
        T.SuiteConfiguration memory _suite,
        uint256 collectionId,
        address resolver,
        address factory,
        bytes32 profileId,
        address payout
    ) public view {
        if (payout == address(0)) {
            revert T.MissingMintPrerequisite(keccak256("payout"));
        }
        IStreamSplitFactory splits = IStreamSplitFactory(factory);
        uint256 count = splits.profileEntryCount(profileId);
        if (count == 0 || count > 64 || !splits.splitWalletExists(profileId)) {
            revert T.InvalidRecord();
        }
        uint256 artistShare;
        for (uint256 i; i < count; ++i) {
            (address account, uint32 share, bytes32 label) = splits.profileEntry(profileId, i);
            if (label == keccak256("artist")) {
                if (account != payout) revert T.InvalidRecord();
                artistShare += share;
            }
        }
        if (artistShare == 0 || (resolver == _suite.primaryResolver && artistShare < 500_000)) {
            revert T.InvalidRecord();
        }
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        uint32 required =
            IStreamArtistCollaboratorBindingOwner(_suite.owners[0])
        .bindingTerms(collectionId, b.generation)
        .count;
        for (uint256 i; i < required; ++i) {
            C.Row memory row = collaboratorAt(_suite, collectionId, b.generation, i);
            if (!row.accepted) revert T.InvalidAttribution(collectionId);
            if (row.shareLabelId == bytes32(0)) continue;
            (address collaboratorPayout, bytes32 designation) =
                collaboratorPayoutAccount(_suite, row.collaboratorArtistId, row.account);
            if (collaboratorPayout == address(0) || designation == bytes32(0)) {
                revert T.MissingMintPrerequisite(keccak256("collaborator_payout"));
            }
            uint256 collaboratorShare;
            for (uint256 j; j < count; ++j) {
                (address account, uint32 share, bytes32 label) = splits.profileEntry(profileId, j);
                if (label == row.shareLabelId) {
                    if (account != collaboratorPayout) revert T.InvalidRecord();
                    collaboratorShare += share;
                }
            }
            if (collaboratorShare == 0) revert T.InvalidRecord();
        }
    }
}
