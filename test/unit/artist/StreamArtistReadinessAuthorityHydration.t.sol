// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistReadinessAuthorityHydration as ReadyHydrate,
    IStreamArtistReadinessAttributionOwner as ReadyAttr,
    IStreamArtistReadinessConsentOwner as ReadyConsent,
    StreamArtistReadinessHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import "../../../smart-contracts/domains/artist/StreamArtistAttestationHydration.sol";
import "../../../smart-contracts/domains/artist/StreamArtistContentHydration.sol";
import {
    IStreamArtistEconomicsAuthorityHydration as EconHydrate,
    IStreamArtistEconomicsAuthorityHydrationOwner as EconExport,
    StreamArtistEconomicsHydrationTypes as EH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import "../../../smart-contracts/domains/artist/StreamArtistEconomicsHydration.sol";
import "./ArtistOnboardingFixture.sol";
import {
    IStreamArtistPayoutAuthorityHydration as PayoutHydrate,
    StreamArtistPayoutHydrationTypes as PH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydration as Hydrate,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistHistory as History,
    IStreamArtistHistoryOwner as HistoryOwner,
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as HT
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import "../../../smart-contracts/core/StreamCoreExternalReads.sol";
import "../../../smart-contracts/domains/artist/StreamArtistHistoryState.sol";

/// @notice Actual two-registry/owner/Archive/Safe round-trip; Core and governance remain typed unit boundaries.
/// @dev Original Safe/Registry/seven-owner/Archive baseline; typed unit Core/governance, no commerce claim.
contract StreamArtistReadinessAuthorityHydrationTest is ArtistOnboardingFixture {
    bytes32 private constant CHAIN =
        0x2eac9cfc5ca84fbeed56ef1741255e2ec7e45f48bc5c5ceda94397aa23d2f23e;
    bytes32 private constant LEAF =
        0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d;
    bytes32 private constant POINTER = keccak256("ARTIST_REGISTRY");

    struct Next {
        StreamArtistOnboardingRegistry registry;
        StreamArtistArchiveV2 archive;
        StreamArtistOnboardingCoordinator coordinator;
        address identity;
    }

    AH.Origin[][7] private candidates;
    bytes32 private savedPolicy;
    bytes private savedPolicySignature;
    bytes32 private revokedDigest;

    T.EconomicsConsent[] private selectedEconomics;
    bytes32[] private selectedRecords;
    bytes private firstEconomicsSignature;

    function _economicHistory() private {
        _baseline();
        T.PayoutDesignation memory payout = T.PayoutDesignation(artistId, address(artist), 0);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.payoutDesignationDigest(payout, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (payout, a)));
        _candidate(5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(artistId)));
        (T.AssignmentFact memory first, T.AssignmentFact memory second) =
            coordinator.reads().currentAssignments(1);
        _approveEconomics(first);
        _approveEconomics(second);
    }

    function _approveEconomics(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.economicsConsentDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        if (selectedEconomics.length == 0) firstEconomicsSignature = a.signature;
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a)));
        _candidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(p)));
        selectedEconomics.push(p);
        selectedRecords.push(IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p));
    }

    function _economicsRequest() private view returns (EH.Request memory p) {
        p.authority = _request();
        p.economics = selectedEconomics;
    }

    function _assertEconomics(Next memory n) private {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        T.Binding memory binding_ = IStreamArtistBindingOwner(s.owners[0]).binding(1);
        for (uint256 j; j < selectedEconomics.length; ++j) {
            T.EconomicsConsent memory p = selectedEconomics[j];
            bytes32 record = selectedRecords[j];
            require(
                IStreamArtistConsentOwner(s.owners[6]).economicsRecord(p) == record,
                "original payload lookup"
            );
            require(
                IStreamArtistEconomicsEvidence(s.owners[6])
                    .economicsRecordForBinding(p, artistId, 1, binding_.bindingHash) == record,
                "exact carried current association"
            );
            require(
                keccak256(
                    abi.encode(
                        IStreamArtistEconomicsEvidence(s.owners[6])
                            .economicsRecordAssociation(record)
                    )
                )
                == keccak256(
                    abi.encode(
                        IStreamArtistEconomicsEvidence(suite.owners[6])
                            .economicsRecordAssociation(record)
                    )
                ),
                "whole original association retained"
            );
            vm.prank(p.resolver);
            n.registry
                .requireEconomicsConsent(1, p.revenueClass, p.scope, p.scopeId, p.assignmentHash);
            require(
                IStreamArtistEconomicsEvidence(s.owners[6])
                    .economicsRecordForBinding(p, artistId, 2, binding_.bindingHash) == 0,
                "no correction-generation authority invented"
            );
        }
        require(
            keccak256(IStreamArtistIdentityOwner(n.identity).signatureBundle(selectedRecords[0]))
                == keccak256(firstEconomicsSignature),
            "exact old domain signature bytes"
        );
    }

    RH.AttestationInput[] private originalAttestations;
    bytes32[] private originalAttestationRecords;
    bytes32 private originalRatification;
    Content.Consent private pendingContent;
    bytes32 private pendingContentRecord;

    /// @dev Initialize the original suite already pinned by the actual resolvers.
    /// This bounded inline Archive profile does not replace the selected source registry.
    function _initialBindingProposal()
        internal
        view
        override
        returns (T.BindingProposal memory proposal)
    {
        proposal = super._initialBindingProposal();
        proposal.identityRecordURI = "urn:readiness-source:identity";
    }

    /// @dev Regression guard: preparing history must retain both actual resolver pins.
    function _compactSource() private view {
        require(
            primary.artistRegistry() == address(ingress)
                && address(royalty.artistRegistry()) == address(ingress),
            "compact source is the original resolver-bound suite"
        );
    }

    function _readinessHistory() private {
        _compactSource();
        _economicHistory();
        _recordRatification();
        pendingContent = _contentProposal(keccak256("next admitted source content"));
        pendingContentRecord = _recordContent(pendingContent);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        _recordHistoricalAttestation(
            9,
            bytes32(uint256(uint160(suite.core))),
            StreamArtistHashes.deploymentFacts(
                StreamArtistHashes.Environment(
                    block.chainid, address(ingress), suite.core, suite.mintManager
                ),
                1,
                b
            ),
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _recordHistoricalAttestation(
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
    }

    function _recordRatification() private returns (bytes32 record) {
        (, bytes32 state) = metadata.currentArtistContentState(1);
        T.Ratification memory p = T.Ratification(1, address(metadata), state);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentRatificationDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordContentRatification, (p, a)));
        record = IStreamArtistConsentOwner(suite.owners[6]).firstReleaseRatification(1).recordHash;
        _candidate(
            6, "consent_finality.replay.ratification_key", keccak256(abi.encode(uint256(1), record))
        );
        if (originalRatification == 0) originalRatification = record;
    }

    function _recordContent(Content.Consent memory p) private returns (bytes32 record) {
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentConsentDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        record = ingress.recordContentConsent(p, a);
        _candidate(
            6,
            "consent_finality.replay.content_consent_key",
            keccak256(abi.encode(keccak256(abi.encode(p, uint64(1))), record))
        );
    }

    function _recordHistoricalAttestation(
        uint8 kind,
        bytes32 subject,
        bytes32 state,
        bytes32 schema
    ) private {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            1, kind, subject, state, schema, keccak256(statement), "urn:retained:source"
        );
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.attestationDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
        );
        originalAttestations.push(RH.AttestationInput(p, a.nonce));
        bytes32 record =
            IStreamArtistAttributionOwner(suite.owners[4]).attestation(1, kind, subject).recordHash;
        originalAttestationRecords.push(record);
        // Original op24 consumes this record-scoped guard in addition to digest and nonce.
        _candidate(2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record)));
    }

    function _readyRequest() private view returns (RH.Request memory p) {
        p.economics = _economicsRequest();
        p.attestations = originalAttestations;
    }

    function _freshDeployment(Next memory n) private returns (bytes32 record) {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        T.Binding memory b = IStreamArtistBindingOwner(s.owners[0]).binding(1);
        bytes32 state = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(n.registry), suite.core, suite.mintManager
            ),
            1,
            b
        );
        bytes memory statement = abi.encode("new actual successor deployment", state);
        T.Attestation memory p = T.Attestation(
            1,
            9,
            bytes32(uint256(uint160(suite.core))),
            state,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1"),
            keccak256(statement),
            "urn:successor:approval"
        );
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        require(
            this.executeTargetSafe(
                address(n.registry),
                abi.encodeCall(IStreamArtistOnboarding.recordArtistAttestation, (p, a, statement))
            ),
            "real Safe approves changed successor deployment"
        );
        record =
        IStreamArtistAttributionOwner(s.owners[4]).attestation(1, 9, p.subjectId).recordHash;
    }

    function _assertHistorical(Next memory n) private view {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        for (uint256 j; j < originalAttestationRecords.length; ++j) {
            bytes32 record = originalAttestationRecords[j];
            T.AttestationRecord memory r =
                IStreamArtistAttributionOwner(s.owners[4]).attestationRecord(record);
            require(
                keccak256(abi.encode(r))
                    == keccak256(
                        abi.encode(
                            IStreamArtistAttributionOwner(suite.owners[4]).attestationRecord(record)
                        )
                    ),
                "exact original historical attestation"
            );
            require(
                ReadyAttr(s.owners[4]).attestationAuthorityClass(record) == 1,
                "exact recorded signing class"
            );
            require(
                keccak256(
                        IStreamArtistAttributionOwner(s.owners[4]).statementBytes(r.statementHash)
                    )
                    == keccak256(
                        IStreamArtistAttributionOwner(suite.owners[4])
                            .statementBytes(r.statementHash)
                    ),
                "complete original statement bytes"
            );
            require(
                keccak256(IStreamArtistIdentityOwner(n.identity).signatureBundle(record))
                    == keccak256(
                        IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(record)
                    ),
                "original signature bytes without resigning"
            );
        }
        require(
            IStreamArtistConsentOwner(s.owners[6])
                .ratificationRecord(originalRatification)
                .recordHash == originalRatification,
            "original ratification history"
        );
    }

    function testReadinessHydrationRequiresFreshDeploymentThenRealFacadeMintConsent() external {
        _readinessHistory();
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        require(
            ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(p) != 0,
            "complete readiness dependency import"
        );
        _assertHistorical(n);
        vm.expectRevert(
            abi.encodeWithSelector(
                T.MissingMintPrerequisite.selector, keccak256("deployment-attestation")
            )
        );
        n.registry.requireMintConsent(1, PHASE, POLICY);
        require(
            _freshDeployment(n) != originalAttestationRecords[0],
            "old deployment cannot become new approval"
        );
        n.registry.requireMintConsent(1, PHASE, POLICY);
        require(
            n.registry
                    .contentConsentEvidence(1, pendingContent.familyId, pendingContent.newStateHash)
                == pendingContentRecord,
            "original pending content approval still readable"
        );
        _assertHistorical(n);
    }

    function testReadinessHydrationRetainsSupersededHeadsAndOriginalConsumedHostGuard() external {
        _readinessHistory();
        bytes32 originalContentRecord = pendingContentRecord;
        pendingContentRecord = _recordContent(pendingContent);
        metadata.configureArtist(address(ingress));
        metadata.applyContent(1, keccak256("next admitted source content"));
        bytes32 finalRatification = _recordRatification();
        Next memory n = _cutover(true, true);
        require(
            ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(_readyRequest())
                != 0,
            "complete changed heads imported"
        );
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        require(
            IStreamArtistConsentOwner(s.owners[6]).firstReleaseRatification(1).recordHash
                    == finalRatification && finalRatification != originalRatification,
            "latest actual ratification, original retained"
        );
        require(
            IStreamArtistContentRecordsOwner(s.owners[6])
                .contentConsentRecord(originalContentRecord)
                .recordHash == originalContentRecord
                && IStreamArtistContentRecordsOwner(s.owners[6])
                .contentConsentAt(pendingContent, 1)
                .recordHash == pendingContentRecord,
            "full content records and latest exact key"
        );
        metadata.configureArtist(address(n.registry));
        vm.expectRevert(bytes("unit consent consumed"));
        metadata.applyContent(1, keccak256("next admitted source content"));
        _freshDeployment(n);
        n.registry.requireMintConsent(1, PHASE, POLICY);
        _assertHistorical(n);
    }

    function testReadinessHydrationCarriesActualGenericEconomicsSubjectAssociation() external {
        _readinessHistory();
        T.EconomicsConsent memory economic = selectedEconomics[0];
        _recordHistoricalAttestation(
            6,
            bytes32(uint256(uint160(economic.resolver))),
            economic.assignmentHash,
            keccak256("audited economics statement")
        );
        Next memory n = _cutover(true, true);
        require(
            ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(_readyRequest())
                != 0,
            "generic admitted owner facts imported"
        );
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        bytes32 record = originalAttestationRecords[2];
        require(
            keccak256(
                abi.encode(
                    IStreamArtistAuthenticatedAttestationOwner(s.owners[4])
                        .attestationAssociation(record)
                )
            )
            == keccak256(
                abi.encode(
                    IStreamArtistAuthenticatedAttestationOwner(suite.owners[4])
                        .attestationAssociation(record)
                )
            ),
            "exact historical provider/code/subject fact"
        );
        _assertHistorical(n);
    }

    function testReadinessHydrationRejectsIncompleteInputsAndForgedOriginalPreimages() external {
        _readinessHistory();
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        avm.expectRevert(T.UnsupportedProfile.selector);
        EconHydrate(address(n.registry)).hydrateArtistAuthorityWithEconomics(p.economics);
        _notHydrated(n);
        p.attestations = new RH.AttestationInput[](1);
        p.attestations[0] = originalAttestations[0];
        avm.expectRevert(T.InvalidRecord.selector);
        ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(p);
        _notHydrated(n);
        p = _readyRequest();
        p.attestations[0].nonce += 1;
        avm.expectRevert(T.InvalidRecord.selector);
        ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(p);
        _notHydrated(n);
        p = _readyRequest();
        p.attestations[0].terms.statementURI = "urn:forged:unretained-uri";
        avm.expectRevert(T.InvalidRecord.selector);
        ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(p);
        _notHydrated(n);
        require(
            ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(_readyRequest())
                != 0,
            "exact original preimages restore the same profile"
        );
    }

    function testReadinessHydrationRejectsUnknownClassChangedOriginalHeadAndStatement() external {
        _readinessHistory();
        Next memory n = _cutover(true, true);
        RH.Request memory p = _readyRequest();
        bytes32 record = originalAttestationRecords[0];
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(ReadyAttr.attestationAuthorityClass, (record)),
            abi.encode(uint8(0))
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(p);
        _notHydrated(n);
        avm.clearMockedCalls();
        T.AttestationRecord memory r =
            IStreamArtistAttributionOwner(suite.owners[4]).attestationRecord(record);
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(IStreamArtistAttributionOwner.statementBytes, (r.statementHash)),
            abi.encode(bytes("altered original statement"))
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(p);
        _notHydrated(n);
        avm.clearMockedCalls();
        T.RatificationRecord memory bad =
            IStreamArtistConsentOwner(suite.owners[6]).firstReleaseRatification(1);
        bad.recordHash = keccak256("foreign current ratification");
        avm.mockCall(
            suite.owners[6],
            abi.encodeCall(IStreamArtistConsentOwner.firstReleaseRatification, (1)),
            abi.encode(bad)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(p);
        _notHydrated(n);
        avm.clearMockedCalls();
        require(
            ReadyHydrate(address(n.registry)).hydrateArtistAuthorityWithReadiness(p) != 0,
            "exact source restored"
        );
    }

    function testReadinessHydrationLateArchiveRollbackAndByteIdenticalSafeRetry() external {
        _readinessHistory();
        Next memory n = _cutover(true, true);
        bytes memory data =
            abi.encodeCall(ReadyHydrate.hydrateArtistAuthorityWithReadiness, (_readyRequest()));
        bytes32 roots = _allRoots(n.coordinator);
        uint256 nonce = artist.nonce();
        uint256 payloads = n.archive.storedPayloadCount();
        avm.mockCallRevert(
            address(n.archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSignature("Error(string)", "readiness hydration archive")
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(n.registry), data);
        _notHydrated(n);
        require(
            _allRoots(n.coordinator) == roots && artist.nonce() == nonce
                && n.archive.storedPayloadCount() == payloads,
            "no partial authority/payload/Safe advance"
        );
        avm.clearMockedCalls();
        require(
            this.executeTargetSafe(address(n.registry), data), "byte-identical Safe hydration retry"
        );
        require(
            n.archive.storedPayloadCount() > payloads,
            "original statement/signature carriers registered only after success"
        );
        _assertHistorical(n);
        _freshDeployment(n);
        n.registry.requireMintConsent(1, PHASE, POLICY);
    }

    function _candidate(uint256 owner, string memory surface, bytes32 scope) private {
        candidates[owner].push(AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _authOrigins(bytes32 digest, uint256 nonce) private {
        _candidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _candidate(
            2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(artistId, nonce))
        );
    }

    function _baseline() private {
        _candidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _candidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(1, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (1, a)));
        _candidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(1), uint8(1), address(artist)))
        );
        T.PolicyConsent memory p = T.PolicyConsent(1, PHASE, POLICY);
        a = _authorization(false);
        digest = ingress.policyConsentDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        savedPolicySignature = a.signature;
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.recordPolicyConsent, (p, a)));
        savedPolicy = IStreamArtistConsentOwner(suite.owners[6]).policyRecord(1, PHASE, POLICY);
        _candidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(uint256(1), PHASE, POLICY))
        );
        _candidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
    }

    function _revoke(StreamArtistAuthorizationTypes.Revocation memory p) private {
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.authorizationRevocationDigest(p, a);
        _authOrigins(digest, a.nonce);
        a.signature = _signature(digest);
        ingress.revokeArtistAuthorization(p, a);
        _candidate(
            2,
            "identity_authority.replay.target_authorization_revocation",
            keccak256(abi.encode(artistId, p.revokedDigest, p.revokedNonce))
        );
        if (p.revokedDigest == 0) {
            _candidate(
                2,
                "identity_authority.replay.nonce_allocator",
                keccak256(abi.encode(artistId, p.revokedNonce))
            );
        } else {
            _candidate(
                2,
                "identity_authority.replay.digest_revocation",
                keccak256(abi.encode(artistId, p.revokedDigest))
            );
        }
    }

    function _sourceKey(uint256 owner, AH.Origin memory o) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[owner],
                IStreamArtistOwner(suite.owners[owner]).domainId(),
                o.surface,
                o.scope
            )
        );
    }

    function _request() private view returns (AH.Request memory p) {
        p.artistId = artistId;
        p.collectionId = 1;
        p.policies = new AH.PolicyKey[](1);
        p.policies[0] = AH.PolicyKey(PHASE, POLICY);
        for (uint256 owner; owner < 7; ++owner) {
            p.expectedSource[owner] = CP(suite.owners[owner]).authorityCheckpoint();
            p.replayOrigins[owner] = new AH.Origin[](p.expectedSource[owner].replayCount);
            for (uint256 j; j < p.expectedSource[owner].replayCount; ++j) {
                (bytes32 key,) = CP(suite.owners[owner]).authorityReplayAt(j);
                bool found;
                for (uint256 k; k < candidates[owner].length; ++k) {
                    if (_sourceKey(owner, candidates[owner][k]) == key) {
                        p.replayOrigins[owner][j] = candidates[owner][k];
                        found = true;
                        break;
                    }
                }
                require(found, "independent preimage exists for every actual source guard");
            }
        }
    }

    function _cutover(bool seal, bool latchCollection) private returns (Next memory n) {
        n = _next();
        HT.Leaf[] memory rows = _leaves(History(address(ingress)));
        (bytes32 root,) = _proof(address(ingress), rows, 0);
        _commit(n, root, keccak256("complete baseline manifest"));
        core.set(POINTER, address(n.registry), false);
        if (seal) History(address(ingress)).observeRegistryCutover();
        (, uint64 count) = History(address(ingress)).artistHistoryLane(1, artistId);
        (, bytes32[] memory proof) = _proof(address(ingress), rows, count - 1);
        History(address(n.registry)).verifyImportedLaneTip(0, rows[count - 1], proof);
        if (latchCollection) {
            (, proof) = _proof(address(ingress), rows, rows.length - 1);
            History(address(n.registry)).verifyImportedLaneTip(0, rows[rows.length - 1], proof);
        }
    }

    function _allRoots(StreamArtistOnboardingCoordinator c) private view returns (bytes32) {
        T.SuiteConfiguration memory s = c.suiteConfiguration();
        T.Snapshot[7] memory snapshots;
        for (uint256 j; j < 7; ++j) {
            snapshots[j] = IStreamArtistOwner(s.owners[j]).ownerStateSnapshotV2();
        }
        return keccak256(abi.encode(snapshots));
    }

    function _notHydrated(Next memory n) private view {
        T.SuiteConfiguration memory s = n.coordinator.suiteConfiguration();
        for (uint256 j; j < 7; ++j) {
            require(
                HydrationOwner(s.owners[j]).authorityHydrationCommitment() == 0,
                "no partial owner activation"
            );
        }
        require(
            IStreamArtistIdentityOwner(n.identity).identity(artistId).authorityAddress
                == address(0),
            "no living default authority"
        );
    }

    function _leaves(History h) private view returns (HT.Leaf[] memory rows) {
        (, uint64 a) = h.artistHistoryLane(1, artistId);
        (, uint64 b) = h.artistHistoryLane(2, bytes32(uint256(1)));
        rows = new HT.Leaf[](uint256(a) + b);
        for (uint64 i; i < a; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(1, artistId, i);
            rows[i] = HT.Leaf(1, artistId, i, r, c);
        }
        for (uint64 i; i < b; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(2, bytes32(uint256(1)), i);
            rows[uint256(a) + i] = HT.Leaf(2, bytes32(uint256(1)), i, r, c);
        }
    }

    function _leaf(address predecessor, HT.Leaf memory p) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        LEAF,
                        block.chainid,
                        predecessor,
                        p.laneKind,
                        p.laneKey,
                        p.sequence,
                        p.recordHash,
                        p.recordChainHash
                    )
                )
            )
        );
    }

    function _proof(address predecessor, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            layer[i] = _leaf(predecessor, leaves[i]);
        }
        while (n > 1) {
            if ((index ^ 1) < n) proof[used++] = layer[index ^ 1];
            uint256 nextN = (n + 1) / 2;
            for (uint256 i; i < nextN; ++i) {
                uint256 j = i * 2;
                if (j + 1 == n) {
                    layer[i] = layer[j];
                } else {
                    bytes32 a = layer[j];
                    bytes32 b = layer[j + 1];
                    layer[i] = a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
                }
            }
            index /= 2;
            n = nextN;
        }
        root = layer[0];
        assembly ("memory-safe") { mstore(proof, used) }
    }

    function _commitData(Next memory n, bytes32 root, bytes32 manifest, uint8 cls, bool wrong)
        private
        view
        returns (bytes memory)
    {
        HT.Context memory x = History(address(n.registry))
            .artistHistoryImportContext(address(ingress), uint64(block.number), root, manifest);
        return abi.encodeCall(
            ArtistUnitGovernance.executeModuleContext,
            (
                address(n.registry),
                abi.encodeCall(
                    History.commitArtistHistoryImportRoot,
                    (address(ingress), uint64(block.number), root, manifest)
                ),
                cls,
                x.scopeHash,
                wrong ? keccak256("wrong import state") : x.oldValueHash,
                x.newValueHash
            )
        );
    }

    function _commit(Next memory n, bytes32 root, bytes32 manifest) private {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), manifest, "urn:history"
        );
        bytes memory data = _commitData(n, root, manifest, 1, false);
        vm.recordLogs();
        require(
            this.executeTargetSafe(address(authority), data),
            "actual threshold Safe executes typed governance context"
        );
        _historyEvent(
            vm.getRecordedLogs(),
            n.identity,
            keccak256(
                "ArtistHistoryImportRootCommitted(uint16,address,bytes32,uint64,bytes32,bytes32)"
            ),
            bytes32(uint256(uint160(address(ingress)))),
            root,
            abi.encode(
                uint16(1), uint64(block.number), manifest, keccak256("unit authority gas raise")
            )
        );
    }

    function _historyEvent(
        Vm.Log[] memory logs,
        address emitter,
        bytes32 topic,
        bytes32 first,
        bytes32 second,
        bytes memory expected
    ) private pure {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory entry = logs[i];
            if (entry.emitter != emitter || entry.topics.length == 0 || entry.topics[0] != topic) {
                continue;
            }
            ++found;
            require(
                entry.topics.length == (second == 0 ? 2 : 3) && entry.topics[1] == first,
                "exact original event emitter/topics"
            );
            if (second != 0) require(entry.topics[2] == second, "exact second indexed word");
            require(
                keccak256(entry.data) == keccak256(expected),
                "independent complete normative event data"
            );
        }
        require(found == 1, "one original normative import event");
    }

    function _next() private returns (Next memory n) {
        T.SuiteConfiguration memory s = suite;
        address governance = manager.governanceAuthority();
        ArtistSanctionFinalityFixture finalityFixture = new ArtistSanctionFinalityFixture();
        uint256 nonce = avm.getNonce(address(this));
        address registry_ = avm.computeCreateAddress(address(this), nonce);
        address archive_ = avm.computeCreateAddress(address(this), nonce + 1);
        address coordinator_ = avm.computeCreateAddress(address(this), nonce + 9);
        address identity_ = avm.computeCreateAddress(address(this), nonce + 4);
        address[3] memory facade;
        address[3] memory identity;
        for (uint8 i; i < 3; ++i) {
            facade[i] = artistExtensionFactory.deployRegistry(i + 4, registry_, coordinator_);
        }
        for (uint8 i; i < 3; ++i) {
            identity[i] = artistExtensionFactory.deployIdentity(
                i + 1, [identity_, registry_, coordinator_, archive_, s.core, s.mintManager]
            );
        }
        n.registry = StreamArtistOnboardingRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry",
                    abi.encode(
                        s.core,
                        s.mintManager,
                        coordinator_,
                        governance,
                        address(estateCoverageProvider),
                        keccak256("successor deployment"),
                        "urn:successor",
                        keccak256("successor manifest"),
                        address(artistExtensionFactory),
                        facade
                    )
                ))
        );
        n.archive = StreamArtistArchiveV2(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2",
                    abi.encode(registry_, coordinator_)
                ))
        );
        s.registry = registry_;
        s.archive = archive_;
        s.owners[0] = address(
            StreamArtistBindingLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[1] = address(
            StreamArtistCollaboratorLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[2] = address(
            StreamArtistIdentityAuthority(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority",
                        abi.encode(
                            registry_,
                            coordinator_,
                            archive_,
                            s.core,
                            s.mintManager,
                            address(artistExtensionFactory),
                            identity
                        )
                    ))
            )
        );
        s.owners[3] = address(
            StreamArtistAcceptanceLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[4] = address(
            StreamArtistAttributionLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[5] = address(
            StreamArtistPayoutLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        s.owners[6] = address(
            StreamArtistConsentFinalityLifecycle(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle",
                        abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager)
                    ))
            )
        );
        ArtistUnitGovernance(governance)
            .configureContestReads(
                s.roleRegistry, address(artist), keccak256("successor finality"), "urn:successor"
            );
        address finality = finalityFixture.deploy(s.core, s.metadata, registry_, governance);
        n.coordinator = StreamArtistOnboardingCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator",
                    abi.encode(s, finality)
                ))
        );
        n.identity = s.owners[2];
        require(
            address(n.registry) == registry_ && address(n.archive) == archive_
                && address(n.coordinator) == coordinator_ && n.identity == identity_,
            "actual successor pins"
        );
    }
}
