// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentMintPolicyGraceFixture.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";

/// @notice Original mode2 Artist records produced by a distinct threshold-two delegate Safe.
/// @dev All inherited mint, Ledger, Artist, governance and Safe contracts remain actual products.
abstract contract CurrentDelegatedMintGraceFixture is CurrentMintPolicyGraceFixture {
    OfficialSafe internal delegatedConsentSafe;
    bytes32 internal graceConsentGrant;
    uint256 internal graceConsentNonce;
    mapping(bytes32 => bytes32) internal delegatedPolicyRecords;

    function _delegatedPolicyAuthorization(bytes32 policy)
        internal
        returns (T.Authorization memory a)
    {
        a = T.Authorization(graceConsentNonce++, type(uint64).max, "");
        bytes32 digest = artists.policyConsentDigest(T.PolicyConsent(1, GRACE_PHASE, policy), a);
        a.signature = safeThresholdSignature(
            graceKeys, safeMessageDigest(delegatedConsentSafe, abi.encode(digest))
        );
    }

    function _recordGracePolicy(bytes32 policy) internal override {
        T.Authorization memory a = _delegatedPolicyAuthorization(policy);
        bytes32 record = IStreamArtistDelegatedConsent(address(artists))
            .recordDelegatedPolicyConsent(
                T.PolicyConsent(1, GRACE_PHASE, policy), graceConsentGrant, a
            );
        delegatedPolicyRecords[policy] = record;
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_POLICY_CONSENT_RECORD_V1"),
                        block.chainid,
                        address(artists),
                        address(manager),
                        uint256(1),
                        GRACE_PHASE,
                        policy,
                        fixtureArtistId,
                        address(delegatedConsentSafe),
                        uint8(2),
                        a.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "independently reconstructed original record and delegate identity"
        );
        (bool consented, bytes32 evidence) = artists.isPolicyConsented(1, GRACE_PHASE, policy);
        require(
            consented && record != 0 && evidence == record, "original exact delegated policy record"
        );
        require(artists.recordDelegation(record) == graceConsentGrant, "original grant association");
    }

    function _revokeGraceGrant() internal {
        D.Revocation memory p = D.Revocation(
            fixtureArtistId,
            address(delegatedConsentSafe),
            graceConsentGrant,
            keccak256("stop future delegated grace consents")
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.delegationRevocationDigest(p, a));
        artists.revokeArtistDelegation(p, a);
        require(
            artists.delegationRecord(graceConsentGrant).revoked, "actual principal revokes grant"
        );
    }

    function _onboardFixtureArtist(address artist_) internal override {
        bytes memory document = bytes("current-stack artist identity");
        T.BindingProposal memory p;
        p.artistAddress = artist_;
        p.identityRecordHash = keccak256(document);
        p.identityRecordURI = "urn:6529stream:fixture:artist-identity";
        p.consentMode = 2;
        p.saleConsentScope = 0;
        p.collaborators = new T.CollaboratorRecord[](0);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
        (fixtureArtistId,) = artists.proposeArtistBinding(1, p, document, "Stream Artist");
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.acceptanceDigest(1, a));
        artists.acceptArtistBinding(1, a);
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(fixtureArtistId, artist_, bytes32(0));
        a = _artistAuthorization(true);
        a.signature = _artistProof(artists.payoutDesignationDigest(payout, a));
        artists.recordPayoutDesignation(payout, a);
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            artistCoordinator.reads().currentAssignments(1);
        _recordModeTwoEconomics(primary);
        _recordModeTwoEconomics(royalty);
        (, bytes32 contentState) = router.currentArtistContentState(1);
        T.Ratification memory ratification = T.Ratification(1, address(router), contentState);
        a = _artistAuthorization(false);
        a.signature = _artistProof(artists.contentRatificationDigest(ratification, a));
        artists.recordContentRatification(ratification, a);
        T.Binding memory binding_ = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1);
        bytes32 facts = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(artists), artistSuite.core, artistSuite.mintManager
            ),
            1,
            binding_
        );
        _recordModeTwoAttestation(
            9,
            bytes32(uint256(uint160(artistSuite.core))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _recordModeTwoAttestation(
            10,
            fixtureArtistId,
            binding_.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
        SafeComponents memory components = deploySafeComponents("1.4.1");
        delegatedConsentSafe = createOfficialSafe(components, safeOwnerAddresses(graceKeys), 2, 942);
        D.Grant memory permission = D.Grant(
            fixtureArtistId,
            address(delegatedConsentSafe),
            1,
            D.POLICY_CONSENT,
            uint64(block.timestamp),
            uint64(block.timestamp + 400 days),
            8,
            keccak256("mode2 grace policy permission")
        );
        a = _artistAuthorization(false);
        a.time = 0;
        a.signature = _artistProof(artists.delegationGrantDigest(permission, a));
        graceConsentGrant = artists.grantArtistDelegation(permission, a);
    }

    function _recordModeTwoEconomics(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.economicsConsentDigest(p, a));
        artists.recordEconomicsConsent(p, a);
    }

    function _recordModeTwoAttestation(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema)
        private
    {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            1,
            kind,
            subject,
            state,
            schema,
            keccak256(statement),
            "urn:6529stream:fixture:statement"
        );
        T.Authorization memory a = _artistAuthorization(true);
        a.signature = _artistProof(artists.attestationDigest(p, a));
        artists.recordArtistAttestation(p, a, statement);
    }
}
