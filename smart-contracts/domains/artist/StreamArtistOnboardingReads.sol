// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistHashes.sol";

import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistContentFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistRoyaltyPreview.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/revenue/IStreamRevenueResolver.sol";
import "../../interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Stateless composition of authoritative artist records with the live selected modules.
/// @dev Owns no semantic records or readiness state. Each floor is recomputed from actual records.
contract StreamArtistOnboardingReads {
    T.SuiteConfiguration private _suite;
    uint256 private immutable _chainId;

    constructor(T.SuiteConfiguration memory suite) {
        _suite = suite;
        _chainId = block.chainid;
    }

    function acceptedBinding(uint256 collectionId) public view returns (T.Binding memory b) {
        b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(_suite.owners[4]).attributionState(collectionId);
        (address authority, uint8 authorityClass, uint8 identityStatus, bytes32 identityHash) =
            IStreamArtistIdentityOwner(_suite.owners[2]).authorityState(b.artistId);
        if (
            !b.accepted || state != 2 || generation != b.generation || identityStatus != 1
                || authorityClass != 1 || authority != b.artistAddress
                || identityHash != b.identityRecordHash
        ) {
            revert T.InvalidAttribution(collectionId);
        }
    }

    function consentMode(uint256 collectionId) external view returns (uint8) {
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        return b.accepted ? b.consentMode : 0;
    }

    function acceptedArtist(uint256 collectionId) external view returns (address) {
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        (uint8 state,) =
            IStreamArtistAttributionOwner(_suite.owners[4]).attributionState(collectionId);
        if (!b.accepted || state != 2) return address(0);
        (address authority,,,) =
            IStreamArtistIdentityOwner(_suite.owners[2]).authorityState(b.artistId);
        return authority;
    }

    function attribution(uint256 collectionId)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory result)
    {
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        (address authority,,, bytes32 identityHash) =
            IStreamArtistIdentityOwner(_suite.owners[2]).authorityState(b.artistId);
        IStreamArtistAcceptanceOwner acceptance = IStreamArtistAcceptanceOwner(_suite.owners[3]);
        result = IStreamCollectionArtistRegistry.Attribution(
            b.artistAddress,
            b.accepted ? authority : address(0),
            identityHash,
            b.bindingHash,
            acceptance.acceptanceRecord(b.bindingHash),
            b.generation,
            acceptance.acceptedAt(b.bindingHash)
        );
    }

    function isPolicyConsented(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        external
        view
        returns (bool, bytes32)
    {
        bytes32 record = IStreamArtistConsentOwner(_suite.owners[6])
            .policyRecord(collectionId, phaseId, policyHash);
        return (record != bytes32(0), record);
    }

    function currentContent(uint256 collectionId)
        public
        view
        returns (address target, bytes32 state)
    {
        _requireSelected(keccak256("METADATA_ROUTER"), _suite.metadata);
        (target, state) =
            IStreamArtistContentFacts(_suite.metadata).currentArtistContentState(collectionId);
        if (target != _suite.metadata || state == bytes32(0)) revert T.InvalidRecord();
    }

    function currentAssignments(uint256 collectionId)
        public
        view
        returns (T.AssignmentFact memory primary, T.AssignmentFact memory royalty)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory p = IStreamRevenueResolver(
                _suite.primaryResolver
            ).resolvePrimaryAssignment(collectionId, 0, _suite.primaryRevenueClass);
        if (
            !p.exists || p.scope != 1 || p.scopeId != collectionId || p.assignmentType != 1
                || p.profileId == bytes32(0)
        ) {
            revert T.UnsupportedProfile();
        }
        primary = T.AssignmentFact(
            _suite.primaryResolver, _suite.primaryRevenueClass, p.scope, p.scopeId, p.assignmentHash
        );
        royalty = currentRoyaltyAssignment(collectionId);
    }

    /// @notice Reads royalty independently of primary or mint floors for defensive artist rights.
    function currentRoyaltyAssignment(uint256 collectionId)
        public
        view
        returns (T.AssignmentFact memory royalty)
    {
        _requireSelected(keccak256("ROYALTY_RESOLVER"), _suite.royaltyResolver);
        royalty = IStreamArtistRoyaltyFacts(_suite.royaltyResolver)
            .currentArtistRoyaltyAssignment(collectionId);
        if (
            royalty.resolver != _suite.royaltyResolver
                || royalty.revenueClass != keccak256("ROYALTY_ERC2981") || royalty.scope != 1
                || royalty.scopeId != collectionId || royalty.assignmentHash == bytes32(0)
        ) revert T.InvalidRecord();
    }

    /// @notice Checks the exact immutable provider's real prospective profile against current payout rights.
    function requireProspectiveEconomics(
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        address payout
    ) external view returns (T.AssignmentFact memory fact) {
        if (
            candidate.profileHash == bytes32(0) || candidate.policyHash != bytes32(0)
                || p.scope != 1 || p.scopeId != p.collectionId
        ) revert T.UnsupportedProfile();
        if (p.resolver == _suite.primaryResolver) {
            if (candidate.royaltyBps != 0 || p.revenueClass != _suite.primaryRevenueClass) {
                revert T.UnsupportedProfile();
            }
            fact = IStreamArtistPrimaryFacts(p.resolver)
                .previewArtistPrimaryAssignment(
                    p.collectionId, candidate.profileHash, candidate.policyHash, candidate.frozen
                );
        } else if (p.resolver == _suite.royaltyResolver) {
            _requireSelected(keccak256("ROYALTY_RESOLVER"), p.resolver);
            if (p.revenueClass != keccak256("ROYALTY_ERC2981")) revert T.UnsupportedProfile();
            fact = IStreamArtistRoyaltyPreview(p.resolver)
                .previewArtistRoyaltyAssignment(
                    p.collectionId, candidate.profileHash, candidate.royaltyBps, candidate.frozen
                );
        } else {
            revert T.UnsupportedProfile();
        }
        if (
            fact.resolver != p.resolver || fact.revenueClass != p.revenueClass
                || fact.scope != p.scope || fact.scopeId != p.scopeId
                || fact.assignmentHash == bytes32(0) || fact.assignmentHash != p.assignmentHash
        ) {
            revert T.InvalidRecord();
        }
        // Both admitted resolvers expose the same splitFactory() ABI. Read this
        // resolver's actual factory, never substitute the primary factory for royalty.
        _requireProfilePayout(
            p.resolver,
            IStreamRevenueResolver(p.resolver).splitFactory(),
            candidate.profileHash,
            payout
        );
    }

    function requireRoyaltyFreezeProposal(T.RoyaltyFreeze calldata p) external view {
        T.AssignmentFact memory fact = currentRoyaltyAssignment(p.collectionId);
        if (
            p.resolver != fact.resolver || p.revenueClass != fact.revenueClass
                || p.expectedAssignmentHash != fact.assignmentHash
                || IStreamRoyaltyResolver(p.resolver).collectionRoyalty(p.collectionId).frozen
        ) {
            revert T.InvalidRecord();
        }
    }

    function isRoyaltyFreezeAuthorized(uint256 collectionId, bytes32 expectedAssignmentHash)
        external
        view
        returns (bool)
    {
        if (block.chainid != _chainId) revert T.InvalidBinding();
        _requireSelected(keccak256("ARTIST_REGISTRY"), _suite.registry);
        _requireSelected(keccak256("ROYALTY_RESOLVER"), _suite.royaltyResolver);
        T.Binding memory b = acceptedBinding(collectionId);
        T.RoyaltyFreeze memory p = T.RoyaltyFreeze(
            _suite.royaltyResolver,
            collectionId,
            keccak256("ROYALTY_ERC2981"),
            expectedAssignmentHash
        );
        T.RoyaltyFreezeRecord memory r = IStreamArtistConsentOwner(_suite.owners[6])
            .royaltyFreezeRecord(p, b.artistId, b.generation);
        return r.recordHash != bytes32(0) && r.artistId == b.artistId
            && r.bindingGeneration == b.generation;
    }

    function requireMintConsent(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        external
        view
    {
        if (block.chainid != _chainId) revert T.InvalidBinding();
        bool registryFrozen = _requireSelected(keccak256("ARTIST_REGISTRY"), _suite.registry);
        T.Binding memory b = acceptedBinding(collectionId);
        if (b.registryImmutabilityElection == 1 && !registryFrozen) {
            revert T.MissingMintPrerequisite(keccak256("registry-freeze"));
        }
        IStreamArtistConsentOwner consents = IStreamArtistConsentOwner(_suite.owners[6]);
        if (consents.policyRecord(collectionId, phaseId, policyHash) == bytes32(0)) {
            revert T.MissingMintPrerequisite(keccak256("policy"));
        }
        (address payout, bytes32 designation) =
            IStreamArtistPayoutOwner(_suite.owners[5]).artistPayoutAccount(b.artistId);
        if (payout == address(0) || designation == bytes32(0)) {
            revert T.MissingMintPrerequisite(keccak256("payout"));
        }
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            currentAssignments(collectionId);
        _requireEconomics(consents, collectionId, primary);
        _requireEconomics(consents, collectionId, royalty);
        (address metadata, bytes32 content) = currentContent(collectionId);
        T.RatificationRecord memory r = consents.firstReleaseRatification(collectionId);
        if (
            r.recordHash == bytes32(0) || r.metadataContract != metadata
                || r.contentStateHash != content
        ) {
            revert T.MissingMintPrerequisite(keccak256("content-ratification"));
        }
        IStreamArtistAttributionOwner attribution_ = IStreamArtistAttributionOwner(_suite.owners[4]);
        T.AttestationRecord memory deployment =
            attribution_.attestation(collectionId, 9, bytes32(uint256(uint160(_suite.core))));
        bytes32 expected = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                _chainId, _suite.registry, _suite.core, _suite.mintManager
            ),
            collectionId,
            b
        );
        if (
            deployment.recordHash == bytes32(0) || deployment.generation != b.generation
                || deployment.subjectStateHash != expected
                || deployment.schemaId != keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        ) {
            revert T.MissingMintPrerequisite(keccak256("deployment-attestation"));
        }
        T.AttestationRecord memory personhood =
            attribution_.attestation(collectionId, 10, b.artistId);
        if (
            personhood.recordHash == bytes32(0) || personhood.generation != b.generation
                || personhood.subjectStateHash != b.identityRecordHash
                || (personhood.schemaId != keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
                    && personhood.schemaId != keccak256("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1"))
        ) {
            revert T.MissingMintPrerequisite(keccak256("personhood-attestation"));
        }
    }

    function requireEconomicsConsent(T.EconomicsConsent calldata p) external view {
        acceptedBinding(p.collectionId);
        if (IStreamArtistConsentOwner(_suite.owners[6]).economicsRecord(p) == bytes32(0)) {
            revert T.MissingMintPrerequisite(keccak256("economics"));
        }
    }

    /// @notice Verifies that actual static profile artist entries pay the operative designation.
    /// @dev The initial profile supports fixed collection assignments only. Dynamic templates
    ///      require their separate accepted materialization path and are rejected here.
    function requireStaticArtistPayout(uint256 collectionId, address resolver, address payout)
        external
        view
    {
        bytes32 profileId;
        address factory;
        if (resolver == _suite.primaryResolver) {
            IStreamRevenueResolver.ResolvedPrimaryAssignment memory p = IStreamRevenueResolver(
                    resolver
                ).resolvePrimaryAssignment(collectionId, 0, _suite.primaryRevenueClass);
            if (!p.exists || p.assignmentType != 1 || p.scope != 1 || p.scopeId != collectionId) {
                revert T.UnsupportedProfile();
            }
            profileId = p.profileId;
            factory = IStreamRevenueResolver(resolver).splitFactory();
        } else if (resolver == _suite.royaltyResolver) {
            IStreamRoyaltyResolver.RoyaltyConfig memory p =
                IStreamRoyaltyResolver(resolver).collectionRoyalty(collectionId);
            if (!p.configured || p.profileId == bytes32(0)) revert T.UnsupportedProfile();
            profileId = p.profileId;
            factory = IStreamRevenueResolver(resolver).splitFactory();
            if (IStreamSplitFactory(factory).walletFor(profileId) != p.wallet) {
                revert T.InvalidRecord();
            }
        } else {
            revert T.UnsupportedProfile();
        }
        _requireProfilePayout(resolver, factory, profileId, payout);
    }

    function _requireProfilePayout(
        address resolver,
        address factory,
        bytes32 profileId,
        address payout
    ) private view {
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
    }

    function _requireEconomics(
        IStreamArtistConsentOwner consents,
        uint256 collectionId,
        T.AssignmentFact memory a
    ) private view {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            collectionId, a.resolver, a.revenueClass, a.scope, a.scopeId, a.assignmentHash
        );
        if (consents.economicsRecord(p) == bytes32(0)) {
            revert T.MissingMintPrerequisite(a.revenueClass);
        }
    }

    function _requireSelected(bytes32 kind, address expected) private view returns (bool frozen) {
        (address target, bytes32 hash, bool frozen_,,,,,,,) =
            IStreamCorePointers(_suite.core).getSatellitePointer(kind);
        if (target != expected || hash != target.codehash || target.code.length == 0) {
            revert T.ComponentChanged(target);
        }
        return frozen_;
    }
}
