// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Exact AA-DOMAINS preimages shared by typed artist owners and their coordinator.
library StreamArtistHashes {
    struct Environment {
        uint256 chainId;
        address registry;
        address core;
        address manager;
    }

    function emptyCollaborators() internal pure returns (bytes32) {
        StreamArtistOnboardingTypes.CollaboratorRecord[] memory items =
            new StreamArtistOnboardingTypes.CollaboratorRecord[](0);
        return keccak256(abi.encode(keccak256("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), items));
    }

    function emptyCapabilities() internal pure returns (bytes32) {
        StreamArtistOnboardingTypes.CapabilityPolicyOverride[] memory items =
            new StreamArtistOnboardingTypes.CapabilityPolicyOverride[](0);
        return keccak256(abi.encode(keccak256("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), items));
    }

    function identity(Environment memory e, address artist, bytes32 document, uint256 nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ID_V1"), e.chainId, e.registry, artist, document, nonce
            )
        );
    }

    function binding(
        Environment memory e,
        uint256 collectionId,
        StreamArtistOnboardingTypes.Binding memory b
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_BINDING_V1"),
                e.chainId,
                e.registry,
                e.core,
                collectionId,
                b.generation,
                b.artistId,
                b.artistAddress,
                b.identityRecordHash,
                b.consentMode,
                b.saleConsentScope,
                b.registryImmutabilityElection,
                uint8(0),
                uint32(0),
                emptyCollaborators(),
                emptyCapabilities()
            )
        );
    }

    function typed(Environment memory e, bytes32 structHash) internal pure returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                e.chainId,
                e.registry
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domain, structHash));
    }

    function acceptanceDigest(
        Environment memory e,
        uint256 collectionId,
        StreamArtistOnboardingTypes.Binding memory b,
        StreamArtistOnboardingTypes.Authorization memory a
    ) internal pure returns (bytes32) {
        return typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)"
                    ),
                    e.core,
                    collectionId,
                    b.generation,
                    b.bindingHash,
                    b.identityRecordHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function acceptanceRecord(
        Environment memory e,
        uint256 collectionId,
        StreamArtistOnboardingTypes.Binding memory b,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"),
                e.chainId,
                e.registry,
                e.core,
                collectionId,
                b.generation,
                b.bindingHash,
                uint8(1),
                signer,
                uint8(1),
                nonce,
                signedAt
            )
        );
    }

    function acceptanceRecordForAuthority(
        Environment memory e,
        uint256 collectionId,
        StreamArtistOnboardingTypes.Binding memory b,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"),
                e.chainId,
                e.registry,
                e.core,
                collectionId,
                b.generation,
                b.bindingHash,
                uint8(1),
                signer,
                authorityClass,
                nonce,
                signedAt
            )
        );
    }

    function policyDigest(
        Environment memory e,
        StreamArtistOnboardingTypes.PolicyConsent memory p,
        StreamArtistOnboardingTypes.Authorization memory a
    ) internal pure returns (bytes32) {
        return typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistPolicyConsent(address core,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 policyHash,uint256 nonce,uint64 deadline)"
                    ),
                    e.core,
                    e.manager,
                    p.collectionId,
                    p.phaseId,
                    p.policyHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function policyRecord(
        Environment memory e,
        StreamArtistOnboardingTypes.PolicyConsent memory p,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_POLICY_CONSENT_RECORD_V1"),
                e.chainId,
                e.registry,
                e.manager,
                p.collectionId,
                p.phaseId,
                p.policyHash,
                artistId,
                signer,
                uint8(1),
                nonce,
                signedAt
            )
        );
    }

    function policyRecordForAuthority(
        Environment memory e,
        StreamArtistOnboardingTypes.PolicyConsent memory p,
        bytes32 artistId,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_POLICY_CONSENT_RECORD_V1"),
                e.chainId,
                e.registry,
                e.manager,
                p.collectionId,
                p.phaseId,
                p.policyHash,
                artistId,
                signer,
                authorityClass,
                nonce,
                signedAt
            )
        );
    }

    function economicsDigest(
        Environment memory e,
        StreamArtistOnboardingTypes.EconomicsConsent memory p,
        StreamArtistOnboardingTypes.Authorization memory a
    ) internal pure returns (bytes32) {
        return typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistEconomicsConsent(address core,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash,uint256 nonce,uint64 deadline)"
                    ),
                    e.core,
                    p.resolver,
                    p.revenueClass,
                    p.scope,
                    p.scopeId,
                    p.assignmentHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function economicsRecord(
        Environment memory e,
        StreamArtistOnboardingTypes.EconomicsConsent memory p,
        bytes32 designation,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ECONOMICS_CONSENT_RECORD_V1"),
                e.chainId,
                e.registry,
                p.resolver,
                p.revenueClass,
                p.scope,
                p.scopeId,
                p.assignmentHash,
                designation,
                artistId,
                signer,
                uint8(1),
                nonce,
                signedAt
            )
        );
    }

    function payoutDigest(
        Environment memory e,
        StreamArtistOnboardingTypes.PayoutDesignation memory p,
        StreamArtistOnboardingTypes.Authorization memory a
    ) internal pure returns (bytes32) {
        return typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistPayoutDesignation(bytes32 artistId,address payoutAccount,bytes32 previousDesignationRecordHash,uint256 nonce,uint64 signedAt)"
                    ),
                    p.artistId,
                    p.payoutAccount,
                    p.previousDesignationRecordHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function royaltyFreezeDigest(
        Environment memory e,
        StreamArtistOnboardingTypes.RoyaltyFreeze memory p,
        StreamArtistOnboardingTypes.Authorization memory a
    ) internal pure returns (bytes32) {
        return typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistRoyaltyFreeze(address core,address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash,uint256 nonce,uint64 deadline)"
                    ),
                    e.core,
                    p.resolver,
                    p.collectionId,
                    p.revenueClass,
                    p.expectedAssignmentHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function royaltyFreezeRecord(
        Environment memory e,
        StreamArtistOnboardingTypes.RoyaltyFreeze memory p,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                e.chainId,
                e.registry,
                p.resolver,
                p.collectionId,
                p.revenueClass,
                p.expectedAssignmentHash,
                artistId,
                signer,
                uint8(1),
                nonce,
                signedAt
            )
        );
    }

    function payoutRecord(
        Environment memory e,
        StreamArtistOnboardingTypes.PayoutDesignation memory p,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_PAYOUT_DESIGNATION_RECORD_V1"),
                e.chainId,
                e.registry,
                p.artistId,
                p.payoutAccount,
                p.previousDesignationRecordHash,
                signer,
                uint8(1),
                nonce,
                signedAt
            )
        );
    }

    function payoutRecordForAuthority(
        Environment memory e,
        StreamArtistOnboardingTypes.PayoutDesignation memory p,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_PAYOUT_DESIGNATION_RECORD_V1"),
                e.chainId,
                e.registry,
                p.artistId,
                p.payoutAccount,
                p.previousDesignationRecordHash,
                signer,
                authorityClass,
                nonce,
                signedAt
            )
        );
    }

    function attestationDigest(
        Environment memory e,
        StreamArtistOnboardingTypes.Attestation memory p,
        StreamArtistOnboardingTypes.Authorization memory a
    ) internal pure returns (bytes32) {
        return typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistAttestation(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt)"
                    ),
                    e.core,
                    p.collectionId,
                    p.subjectKind,
                    p.subjectId,
                    p.subjectStateHash,
                    p.schemaId,
                    p.statementHash,
                    keccak256(bytes(p.statementURI)),
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function attestationRecord(
        Environment memory e,
        StreamArtistOnboardingTypes.Attestation memory p,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                e.chainId,
                e.registry,
                e.core,
                p.collectionId,
                p.subjectKind,
                p.subjectId,
                p.subjectStateHash,
                p.schemaId,
                p.statementHash,
                keccak256(bytes(p.statementURI)),
                artistId,
                signer,
                uint8(1),
                nonce,
                signedAt
            )
        );
    }

    function attestationRecordForAuthority(
        Environment memory e,
        StreamArtistOnboardingTypes.Attestation memory p,
        bytes32 artistId,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                e.chainId,
                e.registry,
                e.core,
                p.collectionId,
                p.subjectKind,
                p.subjectId,
                p.subjectStateHash,
                p.schemaId,
                p.statementHash,
                keccak256(bytes(p.statementURI)),
                artistId,
                signer,
                authorityClass,
                nonce,
                signedAt
            )
        );
    }

    function ratificationDigest(
        Environment memory e,
        StreamArtistOnboardingTypes.Ratification memory p,
        StreamArtistOnboardingTypes.Authorization memory a
    ) internal pure returns (bytes32) {
        return typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistContentRatification(address core,address metadataContract,uint256 collectionId,bytes32 contentStateHash,uint256 nonce,uint64 deadline)"
                    ),
                    e.core,
                    p.metadataContract,
                    p.collectionId,
                    p.contentStateHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function ratificationRecord(
        Environment memory e,
        StreamArtistOnboardingTypes.Ratification memory p,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_RATIFICATION_RECORD_V1"),
                e.chainId,
                e.registry,
                p.metadataContract,
                e.core,
                p.collectionId,
                p.contentStateHash,
                artistId,
                signer,
                uint8(1),
                nonce,
                signedAt
            )
        );
    }

    function ratificationRecordForAuthority(
        Environment memory e,
        StreamArtistOnboardingTypes.Ratification memory p,
        bytes32 artistId,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CONTENT_RATIFICATION_RECORD_V1"),
                e.chainId,
                e.registry,
                p.metadataContract,
                e.core,
                p.collectionId,
                p.contentStateHash,
                artistId,
                signer,
                authorityClass,
                nonce,
                signedAt
            )
        );
    }

    function deploymentFacts(
        Environment memory e,
        uint256 collectionId,
        StreamArtistOnboardingTypes.Binding memory b
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DEPLOYMENT_FACTS_V1"),
                e.chainId,
                e.core,
                collectionId,
                b.artistId,
                b.generation,
                b.bindingHash
            )
        );
    }
}
