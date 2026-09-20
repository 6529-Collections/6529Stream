// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./IStreamCollectionAttestations.sol";
import "./StreamOwnerNoticeTypes.sol";

/// @notice Append-only general claims. Signatures prove account authorization, not personhood.
/// @dev GENERAL_SIGNER_CLAIM never grants Artist/op24, renderer, floor or protocol authority.
interface IStreamGeneralAttestations is IERC165 {
    enum VerificationClass {
        NONE,
        SIGNER_VERIFIED,
        OPERATOR_ASSERTED
    }
    enum AuthorityQualification {
        NONE,
        GENERAL_SIGNER_CLAIM,
        CONFIGURED_OPERATOR_CLAIM,
        NATIVE_ARTIST_HISTORY
    }

    struct Request {
        address attester;
        uint256 collectionId;
        bytes32 subjectId;
        bytes32 attestationType;
        string attesterDID;
        bytes32 schemaId;
        bytes32 canonicalizationId;
        string statementURI;
        bytes payload;
        bytes32 supersedes;
        bytes32 artistAuthorizationRecordHash;
        uint64 effectiveAt;
        uint256 nonce;
        uint64 deadline;
    }

    struct Attestation {
        address attester;
        uint256 collectionId;
        bytes32 subjectId;
        bytes32 attestationType;
        string attesterDID;
        bytes32 schemaId;
        bytes32 canonicalizationId;
        string statementURI;
        bytes32 statementHash;
        bytes32 supersedes;
        bytes32 artistAuthorizationRecordHash;
        uint64 effectiveAt;
    }

    struct Notarization {
        bytes32 artistId;
        bytes32 operativeIdentityRecordHash;
        StreamOwnerNoticeTypes.Reference legalPersonRef;
        StreamOwnerNoticeTypes.Reference instrumentRef;
        StreamOwnerNoticeTypes.Reference officiatingAuthorityIdentityRef;
        StreamOwnerNoticeTypes.Reference verifyingInstitutionIdentityRef;
    }

    struct ArtistWitness {
        uint8 subjectKind;
        uint256 nonce;
        uint256 nativeReceiptIndex;
    }

    struct Receipt {
        address recorder;
        VerificationClass verificationClass;
        AuthorityQualification authorityQualification;
        uint64 recordedAt;
        uint64 recordIndex;
        bytes32 recordChainHash;
        bytes32 authorizationDigest;
        uint256 nonce;
        uint64 deadline;
        bytes32 signatureScheme;
        bytes32 signatureBundleHash;
        bytes32 schemaDefinitionHash;
        bytes32 canonicalizationDefinitionHash;
        bytes32 profileDefinitionHash;
        bytes32 authorityFamily;
        uint8 authorizationClass;
        uint256 grantCollectionId;
        uint64 grantRevision;
        address identityRegistry;
        bytes32 identityRegistryCodeHash;
        bytes32 artistId;
        bytes32 operativeIdentityRecordHash;
        bytes32 nativeArtistEvidenceHash;
        uint8 nativeArtistAuthorityClass;
    }

    error InvalidGeneralConfiguration();
    error InvalidGeneralAttestation();
    error GeneralAuthorityRequired();
    error GeneralNonceUsed(address attester, uint256 nonce);
    error GeneralDeadlineExpired(uint64 deadline);
    error InvalidGeneralSignature(address attester);
    error GeneralParentGas(uint256 available, uint256 required);
    error GeneralDependencyChanged(address target);
    error GeneralReadFailed(address target);
    error GeneralDefinitionUnavailable(bytes32 id);
    error GeneralRecordUnknown(bytes32 hash);
    error GeneralRecordExists(bytes32 hash);
    error GeneralSupersessionMismatch(bytes32 expected, bytes32 supplied);

    event GeneralAttestationRecorded(
        uint256 indexed collectionId,
        bytes32 indexed attestationType,
        bytes32 indexed subjectId,
        bytes32 recordHash,
        address attester,
        VerificationClass verificationClass,
        AuthorityQualification authorityQualification,
        bytes32 supersedes,
        bytes32 recordChainHash,
        uint16 schemaVersion
    );
    event GeneralAttesterNonceRevoked(
        address indexed attester, uint256 indexed nonce, uint16 schemaVersion
    );

    function core() external view returns (address);
    function schemaRegistry() external view returns (address);
    function chunkStore() external view returns (address);
    function metadataAuthority() external view returns (address);
    function artistRegistry() external view returns (address);
    function verificationClass(bytes32 attestationType) external pure returns (VerificationClass);
    function operatorPolicy(bytes32 attestationType)
        external
        pure
        returns (bytes32 family, uint16 classMask);
    function deriveSubject(IStreamCollectionAttestations.Subject calldata subject)
        external
        view
        returns (bytes32);
    function attestationDigest(Request calldata request) external view returns (bytes32);
    function notarizationPayload(Notarization calldata notarization)
        external
        pure
        returns (bytes memory);
    function recordSignedAttestation(
        IStreamCollectionAttestations.Subject calldata subject,
        Request calldata request,
        bytes calldata signature
    ) external returns (bytes32);
    function recordArtistStatement(
        Request calldata request,
        ArtistWitness calldata witness,
        bytes calldata signature
    ) external returns (bytes32);
    function recordIdentityNotarization(
        IStreamCollectionAttestations.Subject calldata subject,
        Request calldata request,
        Notarization calldata notarization,
        bytes calldata signature
    ) external returns (bytes32);
    function recordOperatorAttestation(
        IStreamCollectionAttestations.Subject calldata subject,
        Request calldata request
    ) external returns (bytes32);
    function revokeAttesterNonce(uint256 nonce) external;
    function isAttesterNonceUsed(address attester, uint256 nonce) external view returns (bool);
    function attestation(bytes32 recordHash)
        external
        view
        returns (Attestation memory, Receipt memory);
    function recordArtistEvidence(bytes32 recordHash) external view returns (bytes memory);
    function recordSubject(bytes32 recordHash)
        external
        view
        returns (IStreamCollectionAttestations.Subject memory);
    function recordPayload(bytes32 recordHash)
        external
        view
        returns (address pointer, bytes memory payload);
    function recordSignatureBundle(bytes32 recordHash)
        external
        view
        returns (address pointer, bytes memory bundle);
    function latestAttestationHashFor(
        uint256 collectionId,
        bytes32 attestationType,
        bytes32 subjectId,
        address attester
    ) external view returns (bytes32);
    function recordChainHash(uint256 collectionId, bytes32 attestationType)
        external
        view
        returns (bytes32, uint64);
    function recordHashAt(uint256 collectionId, bytes32 attestationType, uint256 index)
        external
        view
        returns (bytes32);
    function payloadPointerCount(uint256 collectionId) external view returns (uint256);
    function payloadPointerAt(uint256 collectionId, uint256 index)
        external
        view
        returns (address, bytes32, bytes32);
}
