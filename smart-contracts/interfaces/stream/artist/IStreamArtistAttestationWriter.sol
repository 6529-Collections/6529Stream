// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistOnboardingTypes.sol";
import "./StreamArtistRotationTypes.sol";

/// @notice Additive subject routing; none of these fields replace the original signed op24 payload.
library StreamArtistAttestationTypes {
    struct Subject {
        uint8 scopeType;
        uint256 tokenId;
        bytes32 scopeId;
        address resolver;
    }

    struct Fact {
        address owner;
        bytes32 ownerCodeHash;
        bytes32 subjectId;
        bytes32 stateHash;
    }

    struct Admission {
        StreamArtistRotationTypes.AuthorityFact authority;
        address signer;
        uint256 nonce;
        uint64 signedAt;
        bytes32 delegation;
        bytes32 operativeIdentity;
        Fact fact;
    }

    struct Association {
        bytes32 artistId;
        bytes32 bindingHash;
        uint64 generation;
        bytes32 delegation;
        Fact fact;
    }
}

interface IStreamArtistAttestationWriter {
    function recordArtistScopedAttestation(
        StreamArtistOnboardingTypes.Attestation calldata p,
        StreamArtistAttestationTypes.Subject calldata subject,
        StreamArtistOnboardingTypes.Authorization calldata a,
        bytes calldata statement
    ) external returns (bytes32);
    function recordDelegatedArtistAttestation(
        StreamArtistOnboardingTypes.Attestation calldata p,
        bytes32 grant,
        StreamArtistOnboardingTypes.Authorization calldata a,
        bytes calldata statement
    ) external returns (bytes32);
    function recordDelegatedArtistScopedAttestation(
        StreamArtistOnboardingTypes.Attestation calldata p,
        StreamArtistAttestationTypes.Subject calldata subject,
        bytes32 grant,
        StreamArtistOnboardingTypes.Authorization calldata a,
        bytes calldata statement
    ) external returns (bytes32);
    function attestationAssociation(bytes32 record)
        external
        view
        returns (StreamArtistAttestationTypes.Association memory);
}

interface IStreamArtistAttestationCoordinator {
    function coordinateSubjectAttestation(
        address actor,
        StreamArtistOnboardingTypes.Attestation calldata p,
        StreamArtistAttestationTypes.Subject calldata subject,
        bool scoped,
        bytes32 grant,
        StreamArtistOnboardingTypes.Authorization calldata a,
        bytes calldata statement
    ) external returns (bytes32);
}

interface IStreamArtistAttestationIdentityOwner {
    function consumeDelegatedAttestation(
        StreamArtistOnboardingTypes.ActionContext calldata c,
        StreamArtistOnboardingTypes.Binding calldata b,
        StreamArtistOnboardingTypes.Attestation calldata p,
        bytes32 grant,
        StreamArtistOnboardingTypes.Authorization calldata a,
        StreamArtistOnboardingTypes.SignerApproval calldata proof
    ) external returns (bytes32);
}

interface IStreamArtistAuthenticatedAttestationOwner {
    function recordAuthenticatedAttestation(
        StreamArtistOnboardingTypes.ActionContext calldata c,
        StreamArtistOnboardingTypes.Binding calldata b,
        StreamArtistOnboardingTypes.Attestation calldata p,
        StreamArtistAttestationTypes.Admission calldata admission,
        bytes calldata statement
    ) external returns (bytes32);
    function attestationAssociation(bytes32 record)
        external
        view
        returns (StreamArtistAttestationTypes.Association memory);
}
