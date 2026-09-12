// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAttributionPolicy.sol";
import "./StreamArtistHashes.sol";
import "./StreamArtistAuthorityPolicy.sol";

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
import "../../interfaces/stream/artist/IStreamArtistRoyaltyScopeFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryScopeFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPrimaryTemplateFacts.sol";
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
        return _acceptedBinding(collectionId, false);
    }

    function defensiveBinding(uint256 collectionId) public view returns (T.Binding memory b) {
        return _acceptedBinding(collectionId, true);
    }

    function _acceptedBinding(uint256 collectionId, bool defensive)
        private
        view
        returns (T.Binding memory b)
    {
        b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(_suite.owners[4]).attributionState(collectionId);
        (address authority, uint8 authorityClass, uint8 identityStatus,) =
            IStreamArtistIdentityOwner(_suite.owners[2]).authorityState(b.artistId);
        if (
            !b.accepted
                || (!StreamArtistAttributionPolicy.acceptedOrSanctioned(state)
                    && !(defensive && state == 4)) || generation != b.generation
                || !StreamArtistAuthorityPolicy.ordinary(authorityClass, identityStatus, defensive)
                || authority == address(0)
        ) {
            revert T.InvalidAttribution(collectionId);
        }
    }

    /// @notice Canonical payout selection composes Payout records with actual Identity transition facts.
    function artistPayoutAccount(bytes32 artistId) public view returns (address, bytes32) {
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

    function collectionArtistBeneficiary(uint256 collectionId)
        external
        view
        returns (bytes32 artistId, address payoutAccount, bytes32 designationRecordHash)
    {
        _requireSelected(keccak256("ARTIST_REGISTRY"), _suite.registry);
        T.Binding memory b = acceptedBinding(collectionId);
        artistId = b.artistId;
        (payoutAccount, designationRecordHash) = artistPayoutAccount(artistId);
        if (payoutAccount == address(0) || designationRecordHash == bytes32(0)) {
            revert T.InvalidRecord();
        }
    }

    function collaboratorAt(uint256 collectionId, uint64 generation, uint256 index)
        public
        view
        returns (C.Row memory)
    {
        T.Binding memory b =
            IStreamArtistBindingOwner(_suite.owners[0]).bindingAt(collectionId, generation);
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

    function collaboratorPayoutAccount(bytes32 artistId, address account)
        public
        view
        returns (address, bytes32)
    {
        if (!IStreamArtistCollaboratorRecordsOwner(_suite.owners[1])
                .identityLinked(artistId, account)) return (address(0), bytes32(0));
        return artistPayoutAccount(artistId);
    }

    function consentMode(uint256 collectionId) external view returns (uint8) {
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        return b.accepted ? b.consentMode : 0;
    }

    function acceptedArtist(uint256 collectionId) external view returns (address) {
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        (uint8 state,) =
            IStreamArtistAttributionOwner(_suite.owners[4]).attributionState(collectionId);
        if (!b.accepted || !StreamArtistAttributionPolicy.acceptedOrSanctioned(state)) {
            return address(0);
        }
        (address authority,,,) =
            IStreamArtistIdentityOwner(_suite.owners[2]).authorityState(b.artistId);
        return authority;
    }

    /// @notice Acceptance hash/time describe the primary's recorded acceptance, even before set completion.
    /// @dev identityHash is the binding's ratified document version, never the current identity tip.
    ///      The artist field remains zero until all required rows complete; timestamps are not readiness flags.
    function attribution(uint256 collectionId)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory result)
    {
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        (address authority,,,) =
            IStreamArtistIdentityOwner(_suite.owners[2]).authorityState(b.artistId);
        IStreamArtistAcceptanceOwner acceptance = IStreamArtistAcceptanceOwner(_suite.owners[3]);
        result = IStreamCollectionArtistRegistry.Attribution(
            b.artistAddress,
            b.accepted ? authority : address(0),
            b.identityRecordHash,
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
            !p.exists
                || !((p.scope == 1 && p.scopeId == collectionId)
                    || (p.scope == 0 && p.scopeId == 0 && p.assignmentType == 1))
                || !((p.assignmentType == 1 && p.profileId != bytes32(0))
                    || (p.assignmentType == 2
                        && p.profileId == bytes32(0)
                        && p.templateId != bytes32(0)
                        && p.policyHash == bytes32(0)
                        && _suite.primaryRevenueClass == keccak256("PRIMARY_SALE")))
        ) {
            revert T.UnsupportedProfile();
        }
        primary = T.AssignmentFact(
            _suite.primaryResolver, _suite.primaryRevenueClass, p.scope, p.scopeId, p.assignmentHash
        );
        (royalty,) = _rawSelectedCollectionRoyalty(collectionId);
        if (royalty.assignmentHash == bytes32(0)) revert T.InvalidRecord();
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
        (fact,) = _requireProspectiveEconomics(p, candidate, payout);
    }

    function requireProspectiveEconomicsWithEvidence(
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        address payout
    ) external view returns (T.AssignmentFact memory fact, bytes32 previousHash) {
        return _requireProspectiveEconomics(p, candidate, payout);
    }

    function _requireProspectiveEconomics(
        T.EconomicsConsent memory p,
        T.FixedEconomicsCandidate memory candidate,
        address payout
    ) private view returns (T.AssignmentFact memory fact, bytes32 previousHash) {
        if (
            (p.resolver == _suite.primaryResolver || p.resolver == _suite.royaltyResolver)
                && p.assignmentHash == bytes32(0)
        ) {
            if (
                p.revenueClass
                        != (p.resolver == _suite.primaryResolver
                                ? _suite.primaryRevenueClass
                                : keccak256("ROYALTY_ERC2981"))
                    || candidate.profileHash != bytes32(0) || candidate.policyHash != bytes32(0)
                    || candidate.royaltyBps != 0 || candidate.frozen
            ) revert T.UnsupportedProfile();
            if (p.resolver == _suite.primaryResolver) {
                (fact, previousHash) = IStreamArtistPrimaryScopeFacts(p.resolver)
                    .previewArtistPrimaryClear(p.collectionId, p.scope, p.scopeId);
            } else {
                _requireSelected(keccak256("ROYALTY_RESOLVER"), p.resolver);
                (fact, previousHash) = IStreamArtistRoyaltyScopeFacts(p.resolver)
                    .previewArtistRoyaltyClear(p.collectionId, p.scope, p.scopeId);
            }
            if (
                fact.resolver != p.resolver || fact.revenueClass != p.revenueClass
                    || fact.scope != p.scope || fact.scopeId != p.scopeId
                    || fact.assignmentHash != bytes32(0) || previousHash == bytes32(0)
            ) {
                revert T.InvalidRecord();
            }
            _requireCollaboratorDesignations(p.collectionId, payout);
            return (fact, previousHash);
        }
        if (
            candidate.policyHash != bytes32(0) || (p.scope != 1 && p.scope != 2)
                || (p.scope == 1 && p.scopeId != p.collectionId)
        ) revert T.UnsupportedProfile();
        if (p.resolver == _suite.primaryResolver) {
            if (
                candidate.profileHash == bytes32(0) || candidate.royaltyBps != 0
                    || p.revenueClass != _suite.primaryRevenueClass
            ) {
                revert T.UnsupportedProfile();
            }
            fact = IStreamArtistPrimaryScopeFacts(p.resolver)
                .previewArtistPrimaryAssignmentForScope(
                    p.collectionId,
                    p.scope,
                    p.scopeId,
                    candidate.profileHash,
                    candidate.policyHash,
                    candidate.frozen
                );
        } else if (p.resolver == _suite.royaltyResolver) {
            _requireSelected(keccak256("ROYALTY_RESOLVER"), p.resolver);
            if (p.revenueClass != keccak256("ROYALTY_ERC2981")) {
                revert T.UnsupportedProfile();
            }
            fact = IStreamArtistRoyaltyScopeFacts(p.resolver)
                .previewArtistRoyaltyAssignmentForScope(
                    p.collectionId,
                    p.scope,
                    p.scopeId,
                    candidate.profileHash,
                    candidate.royaltyBps,
                    candidate.frozen
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
        if (p.resolver == _suite.royaltyResolver && candidate.profileHash == bytes32(0)) {
            _requireCollaboratorDesignations(p.collectionId, payout);
            return (fact, previousHash);
        }
        // Both admitted resolvers expose the same splitFactory() ABI. Read this
        // resolver's actual factory, never substitute the primary factory for royalty.
        _requireProfilePayout(
            p.collectionId,
            p.resolver,
            IStreamRevenueResolver(p.resolver).splitFactory(),
            candidate.profileHash,
            payout
        );
    }

    function _requireCollaboratorDesignations(uint256 collectionId, address payout) private view {
        if (payout == address(0)) revert T.MissingMintPrerequisite(keccak256("payout"));
        T.Binding memory b = acceptedBinding(collectionId);
        uint32 count =
            IStreamArtistCollaboratorBindingOwner(_suite.owners[0])
        .bindingTerms(collectionId, b.generation)
        .count;
        for (uint256 i; i < count; ++i) {
            C.Row memory row = collaboratorAt(collectionId, b.generation, i);
            if (!row.accepted) revert T.InvalidAttribution(collectionId);
            if (row.shareLabelId == bytes32(0)) continue;
            (address account, bytes32 designation) =
                collaboratorPayoutAccount(row.collaboratorArtistId, row.account);
            if (account == address(0) || designation == bytes32(0)) {
                revert T.MissingMintPrerequisite(keccak256("collaborator_payout"));
            }
        }
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
        T.Binding memory b = defensiveBinding(collectionId);
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
        (address payout, bytes32 designation) = artistPayoutAccount(b.artistId);
        if (payout == address(0) || designation == bytes32(0)) {
            revert T.MissingMintPrerequisite(keccak256("payout"));
        }
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            currentAssignments(collectionId);
        _requireEconomics(b, collectionId, primary);
        _requireEconomics(b, collectionId, royalty);
        (address metadata, bytes32 content) = currentContent(collectionId);
        T.RatificationRecord memory r = consents.firstReleaseRatification(collectionId);
        bool validContent = r.recordHash != bytes32(0) && r.metadataContract == metadata;
        if (validContent && r.contentStateHash != content) {
            (bytes32 ratification, bytes32 resultingContent) =
                IStreamArtistContentMutationFacts(metadata).artistContentEvolution(collectionId);
            validContent = ratification == r.recordHash && resultingContent == content;
        }
        if (!validContent) {
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
                || personhood.subjectStateHash
                    != IStreamArtistIdentityRevisionReads(_suite.owners[2])
                        .operativeIdentityRecord(b.artistId)
                || (personhood.schemaId != keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
                    && personhood.schemaId != keccak256("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1"))
        ) {
            revert T.MissingMintPrerequisite(keccak256("personhood-attestation"));
        }
    }

    function requireEconomicsConsent(T.EconomicsConsent calldata p) external view {
        T.Binding memory b = acceptedBinding(p.collectionId);
        if (_economicsForBinding(p, b) == bytes32(0)) {
            revert T.MissingMintPrerequisite(keccak256("economics"));
        }
    }

    /// @notice Validates current economics and returns supplemental immutable template evidence, if applicable.
    /// @dev This is a read over an already-installed assignment, never a prospective template authorization.
    function requireCurrentArtistEconomics(uint256 collectionId, address resolver, address payout)
        external
        view
        returns (bytes memory)
    {
        if (resolver != _suite.primaryResolver) {
            requireStaticArtistPayout(collectionId, resolver, payout);
            return "";
        }
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory current =
            _rawSelectedCollectionPrimary(collectionId);
        return _requireCurrentPrimary(collectionId, current, payout);
    }

    /// @notice Exact-key facts for recording, without invoking the resolver's consent-consuming resolution.
    function requireCurrentEconomics(T.EconomicsConsent calldata p, address payout)
        external
        view
        returns (bytes memory)
    {
        if (p.resolver == _suite.primaryResolver) {
            if (p.revenueClass != _suite.primaryRevenueClass || p.assignmentHash == bytes32(0)) {
                revert T.InvalidRecord();
            }
            IStreamRevenueResolver.ResolvedPrimaryAssignment memory current = IStreamArtistPrimaryScopeFacts(
                    p.resolver
                ).primaryEconomicsFacts(p.collectionId, p.scope, p.scopeId);
            if (
                !current.exists || current.scope != p.scope || current.scopeId != p.scopeId
                    || current.assignmentHash != p.assignmentHash
            ) revert T.InvalidRecord();
            return _requireCurrentPrimary(p.collectionId, current, payout);
        }
        if (p.resolver != _suite.royaltyResolver || p.revenueClass != keccak256("ROYALTY_ERC2981"))
        {
            revert T.InvalidRecord();
        }
        (T.AssignmentFact memory expected, IStreamRoyaltyResolver.RoyaltyConfig memory config) =
            _royaltyFacts(p.collectionId, p.scope, p.scopeId);
        if (
            p.resolver != expected.resolver || p.revenueClass != expected.revenueClass
                || p.scope != expected.scope || p.scopeId != expected.scopeId
                || p.assignmentHash == bytes32(0) || p.assignmentHash != expected.assignmentHash
        ) revert T.InvalidRecord();
        return _requireCurrentRoyalty(p.collectionId, expected, config, payout);
    }

    function _royaltyFacts(uint256 collectionId, uint8 scope, uint256 scopeId)
        private
        view
        returns (T.AssignmentFact memory fact, IStreamRoyaltyResolver.RoyaltyConfig memory config)
    {
        _requireSelected(keccak256("ROYALTY_RESOLVER"), _suite.royaltyResolver);
        (fact, config) = IStreamArtistRoyaltyScopeFacts(_suite.royaltyResolver)
            .royaltyEconomicsFacts(collectionId, scope, scopeId);
        if (
            fact.resolver != _suite.royaltyResolver
                || fact.revenueClass != keccak256("ROYALTY_ERC2981") || fact.scope != scope
                || fact.scopeId != scopeId
                || (config.configured == (fact.assignmentHash == bytes32(0)))
        ) revert T.InvalidRecord();
    }

    function _rawSelectedCollectionRoyalty(uint256 collectionId)
        private
        view
        returns (T.AssignmentFact memory fact, IStreamRoyaltyResolver.RoyaltyConfig memory config)
    {
        (fact, config) = _royaltyFacts(collectionId, 1, collectionId);
        if (!config.configured) (fact, config) = _royaltyFacts(collectionId, 0, 0);
    }

    function _requireCurrentRoyalty(
        uint256 collectionId,
        T.AssignmentFact memory fact,
        IStreamRoyaltyResolver.RoyaltyConfig memory config,
        address payout
    ) private view returns (bytes memory) {
        if (!config.configured || fact.assignmentHash == bytes32(0)) {
            revert T.InvalidRecord();
        }
        T.AssignmentFact memory rebuilt = IStreamArtistRoyaltyScopeFacts(_suite.royaltyResolver)
            .previewArtistRoyaltyAssignmentForScope(
                collectionId,
                fact.scope,
                fact.scopeId,
                config.profileId,
                config.royaltyBps,
                config.frozen
            );
        if (keccak256(abi.encode(rebuilt)) != keccak256(abi.encode(fact))) {
            revert T.InvalidRecord();
        }
        if (config.profileId == bytes32(0)) {
            if (config.wallet != address(0) || config.royaltyBps != 0) revert T.InvalidRecord();
            _requireCollaboratorDesignations(collectionId, payout);
        } else {
            address factory = IStreamRevenueResolver(_suite.royaltyResolver).splitFactory();
            if (IStreamSplitFactory(factory).walletFor(config.profileId) != config.wallet) {
                revert T.InvalidRecord();
            }
            _requireProfilePayout(
                collectionId, _suite.royaltyResolver, factory, config.profileId, payout
            );
        }
        return
            abi.encode(keccak256("6529STREAM_CURRENT_ROYALTY_ECONOMICS_EVIDENCE_V1"), fact, config);
    }

    function _rawSelectedCollectionPrimary(uint256 collectionId)
        private
        view
        returns (IStreamRevenueResolver.ResolvedPrimaryAssignment memory current)
    {
        IStreamArtistPrimaryScopeFacts provider =
            IStreamArtistPrimaryScopeFacts(_suite.primaryResolver);
        current = provider.primaryEconomicsFacts(collectionId, 1, collectionId);
        if (!current.exists) current = provider.primaryEconomicsFacts(collectionId, 0, 0);
    }

    function _requireCurrentPrimary(
        uint256 collectionId,
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory current,
        address payout
    ) private view returns (bytes memory) {
        address resolver = _suite.primaryResolver;
        if (current.assignmentType != 2) {
            if (
                !current.exists || current.assignmentType != 1 || current.profileId == bytes32(0)
                    || current.policyHash != bytes32(0)
            ) revert T.UnsupportedProfile();
            T.AssignmentFact memory fact = IStreamArtistPrimaryScopeFacts(resolver)
                .previewArtistPrimaryAssignmentForScope(
                    collectionId,
                    current.scope,
                    current.scopeId,
                    current.profileId,
                    current.policyHash,
                    current.frozen
                );
            if (
                fact.resolver != resolver || fact.revenueClass != _suite.primaryRevenueClass
                    || fact.scope != current.scope || fact.scopeId != current.scopeId
                    || fact.assignmentHash != current.assignmentHash
            ) revert T.InvalidRecord();
            _requireProfilePayout(
                collectionId,
                resolver,
                IStreamRevenueResolver(resolver).splitFactory(),
                current.profileId,
                payout
            );
            return "";
        }
        if (
            !current.exists || current.scope != 1 || current.scopeId != collectionId
                || current.profileId != bytes32(0) || current.templateId == bytes32(0)
                || current.policyHash != bytes32(0)
                || _suite.primaryRevenueClass != keccak256("PRIMARY_SALE")
        ) revert T.UnsupportedProfile();
        T.Binding memory binding_ = acceptedBinding(collectionId);
        (address operative, bytes32 designation) = artistPayoutAccount(binding_.artistId);
        if (payout == address(0) || payout != operative || designation == bytes32(0)) {
            revert T.MissingMintPrerequisite(keccak256("payout"));
        }
        IStreamArtistPrimaryTemplateFacts provider = IStreamArtistPrimaryTemplateFacts(resolver);
        (bytes32 entriesHash, bytes32 metadataURIHash, uint32 artistShare) =
            provider.primaryTemplateEconomicsFacts(current.templateId);
        T.AssignmentFact memory preview = provider.previewArtistPrimaryTemplateAssignment(
            collectionId, current.templateId, current.policyHash, current.frozen
        );
        if (
            entriesHash == bytes32(0) || artistShare < 500_000 || preview.resolver != resolver
                || preview.revenueClass != _suite.primaryRevenueClass || preview.scope != 1
                || preview.scopeId != collectionId
                || preview.assignmentHash != current.assignmentHash
        ) revert T.InvalidRecord();
        uint32 count =
            IStreamArtistCollaboratorBindingOwner(_suite.owners[0])
        .bindingTerms(collectionId, binding_.generation)
        .count;
        for (uint256 i; i < count; ++i) {
            C.Row memory row = collaboratorAt(collectionId, binding_.generation, i);
            if (!row.accepted) revert T.InvalidAttribution(collectionId);
            // This first template profile represents only the primary artist dynamically.
            // A paid collaborator must never disappear behind an unrelated static entry.
            if (row.shareLabelId != bytes32(0)) revert T.UnsupportedProfile();
        }
        return abi.encode(
            keccak256("6529STREAM_CURRENT_PRIMARY_TEMPLATE_ECONOMICS_EVIDENCE_V1"),
            current.templateId,
            entriesHash,
            metadataURIHash,
            artistShare
        );
    }

    /// @notice Verifies that actual static profile artist entries pay the operative designation.
    /// @dev Uses raw collection/default selection to avoid consent recursion. Dynamic templates
    ///      require their separate accepted materialization path and are rejected here.
    function requireStaticArtistPayout(uint256 collectionId, address resolver, address payout)
        public
        view
    {
        bytes32 profileId;
        address factory;
        if (resolver == _suite.primaryResolver) {
            IStreamRevenueResolver.ResolvedPrimaryAssignment memory p =
                _rawSelectedCollectionPrimary(collectionId);
            if (!p.exists || p.assignmentType != 1) {
                revert T.UnsupportedProfile();
            }
            profileId = p.profileId;
            factory = IStreamRevenueResolver(resolver).splitFactory();
        } else if (resolver == _suite.royaltyResolver) {
            (T.AssignmentFact memory fact, IStreamRoyaltyResolver.RoyaltyConfig memory config) =
                _rawSelectedCollectionRoyalty(collectionId);
            _requireCurrentRoyalty(collectionId, fact, config, payout);
            return;
        } else {
            revert T.UnsupportedProfile();
        }
        _requireProfilePayout(collectionId, resolver, factory, profileId, payout);
    }

    function _requireProfilePayout(
        uint256 collectionId,
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
        T.Binding memory b = IStreamArtistBindingOwner(_suite.owners[0]).binding(collectionId);
        uint32 required =
            IStreamArtistCollaboratorBindingOwner(_suite.owners[0])
        .bindingTerms(collectionId, b.generation)
        .count;
        for (uint256 i; i < required; ++i) {
            C.Row memory row = collaboratorAt(collectionId, b.generation, i);
            if (!row.accepted) revert T.InvalidAttribution(collectionId);
            if (row.shareLabelId == bytes32(0)) continue;
            (address collaboratorPayout, bytes32 designation) =
                collaboratorPayoutAccount(row.collaboratorArtistId, row.account);
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

    function _requireEconomics(T.Binding memory b, uint256 collectionId, T.AssignmentFact memory a)
        private
        view
    {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            collectionId, a.resolver, a.revenueClass, a.scope, a.scopeId, a.assignmentHash
        );
        if (_economicsForBinding(p, b) == bytes32(0)) {
            revert T.MissingMintPrerequisite(a.revenueClass);
        }
    }

    function _economicsForBinding(T.EconomicsConsent memory p, T.Binding memory b)
        private
        view
        returns (bytes32)
    {
        return IStreamArtistEconomicsEvidence(_suite.owners[6])
            .economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash);
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
