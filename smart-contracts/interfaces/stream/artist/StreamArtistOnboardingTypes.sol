// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Typed records for the first seven implemented artist-authority operations.
/// @dev Numeric values and record payloads follow AA-IDENTITY/BINDING/CONSENT. This is
///      a supported subset, not the complete 57-operation artist-authority interface.
library StreamArtistOnboardingTypes {
    struct Snapshot {
        bytes32 domainId;
        uint64 revision;
        bytes32 stateRoot;
        bytes32 recordChainTip;
    }

    struct ActionContext {
        uint16 operationId;
        address actor;
        Snapshot expected;
    }

    struct ReplayCell {
        bytes32 commitment;
        uint64 touchedRevision;
        uint8 kind;
        uint8 status;
    }

    struct CollaboratorRecord {
        address account;
        bytes32 role;
        bytes32 shareLabelId;
    }

    struct CapabilityPolicyOverride {
        uint32 capabilityMask;
        uint8 mode;
        uint32 threshold;
    }

    struct BindingProposal {
        bytes32 artistId;
        address artistAddress;
        bytes32 identityRecordHash;
        string identityRecordURI;
        uint8 consentMode;
        uint8 saleConsentScope;
        uint8 registryImmutabilityElection;
        uint8 collabPolicyMode;
        uint32 collabThreshold;
        CollaboratorRecord[] collaborators;
        CapabilityPolicyOverride[] capabilityPolicyOverrides;
        bytes32 reasonHash;
        string reasonURI;
    }

    struct Identity {
        address authorityAddress;
        uint8 authorityClass;
        uint8 status;
        uint64 registeredAt;
        uint64 lastAuthorityActionAt;
        bytes32 identityRecordHash;
        string identityRecordURI;
        string displayName;
        uint256 nonceHint;
    }

    struct Binding {
        bytes32 artistId;
        address artistAddress;
        bytes32 identityRecordHash;
        bytes32 bindingHash;
        uint64 generation;
        uint8 consentMode;
        uint8 saleConsentScope;
        uint8 registryImmutabilityElection;
        address proposer;
        bool accepted;
    }

    /// @dev time is deadline for acceptance/policy/economics/ratification, signedAt
    ///      for payout/attestation. Direct payout/attestation may use zero to request
    ///      the observed inclusion timestamp; relayed signed payloads cannot use that sentinel.
    struct Authorization {
        uint256 nonce;
        uint64 time;
        bytes signature;
    }

    /// @dev Created by the immutable coordinator only after stateless verification.
    struct SignerApproval {
        address signer;
        bytes32 digest;
        bool direct;
    }

    struct PolicyConsent {
        uint256 collectionId;
        bytes32 phaseId;
        bytes32 policyHash;
    }

    struct EconomicsConsent {
        uint256 collectionId;
        address resolver;
        bytes32 revenueClass;
        uint8 scope;
        uint256 scopeId;
        bytes32 assignmentHash;
    }

    struct PayoutDesignation {
        bytes32 artistId;
        address payoutAccount;
        bytes32 previousDesignationRecordHash;
    }

    struct Payout {
        address account;
        bytes32 recordHash;
    }

    struct Attestation {
        uint256 collectionId;
        uint8 subjectKind;
        bytes32 subjectId;
        bytes32 subjectStateHash;
        bytes32 schemaId;
        bytes32 statementHash;
        string statementURI;
    }

    struct AttestationRecord {
        bytes32 recordHash;
        bytes32 subjectStateHash;
        bytes32 schemaId;
        bytes32 statementHash;
        uint64 generation;
        uint64 signedAt;
        address signer;
    }

    struct Ratification {
        uint256 collectionId;
        address metadataContract;
        bytes32 contentStateHash;
    }

    struct RatificationRecord {
        bytes32 recordHash;
        bytes32 contentStateHash;
        address metadataContract;
    }

    struct AssignmentFact {
        address resolver;
        bytes32 revenueClass;
        uint8 scope;
        uint256 scopeId;
        bytes32 assignmentHash;
    }

    /// @notice Actual factory profile and assignment settings covered by prospective economics consent.
    /// @dev The supported collection profile requires policyHash zero; primary also requires royaltyBps zero.
    struct FixedEconomicsCandidate {
        bytes32 profileHash;
        bytes32 policyHash;
        uint16 royaltyBps;
        bool frozen;
    }

    /// @notice Exact current royalty assignment that the artist authorizes to become permanently frozen.
    struct RoyaltyFreeze {
        address resolver;
        uint256 collectionId;
        bytes32 revenueClass;
        bytes32 expectedAssignmentHash;
    }

    /// @notice Durable authorization with its operative artist identity and binding-generation admission.
    struct RoyaltyFreezeRecord {
        bytes32 recordHash;
        bytes32 artistId;
        uint64 bindingGeneration;
    }

    /// @notice Constructor-fixed target set; owners use the ADR0023 domain order.
    struct SuiteConfiguration {
        address registry;
        address archive;
        address[7] owners;
        address core;
        address mintManager;
        address roleRegistry;
        address metadata;
        address primaryResolver;
        address royaltyResolver;
        bytes32 primaryRevenueClass;
        address validator;
    }

    error Unauthorized(address caller);
    error InvalidBinding();
    error UnsupportedProfile();
    error InvalidRecord();
    error InvalidIdentity(bytes32 artistId);
    error AddressAlreadyRegistered(address authority);
    error InvalidAttribution(uint256 collectionId);
    error StaleOwnerSnapshot(bytes32 domainId);
    error InvalidOperation(uint16 operationId);
    error Replay(bytes32 replayKey);
    error InvalidSignature();
    error ExpiredAuthorization(uint64 deadline);
    error InvalidTimestamp(uint64 timestamp);
    error BoundExceeded(uint256 actual, uint256 maximum);
    error MissingMintPrerequisite(bytes32 prerequisite);
    error ReentrantOperation();
    error ComponentChanged(address component);
}
