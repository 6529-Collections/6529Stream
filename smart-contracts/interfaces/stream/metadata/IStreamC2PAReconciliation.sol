// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Explicit verifier profile. A report is evidence from that verifier, not a proof of
/// arbitrary C2PA cryptography, trust-anchor quality, human identity or media retrieval.
interface IStreamC2PAReconciliation {
    enum ValidationStatus {
        UNEVALUATED,
        VALID,
        INVALID
    }
    enum AuthorshipStatus {
        UNEVALUATED,
        CONSISTENT,
        DIVERGENT
    }

    /// @dev Canonical abi.encode(Report), retained by the original Metadata receipt. Hashes
    /// are Keccak-256 exact-byte commitments except signerFingerprint (SHA-256 SPKI/DER)
    /// and signerKeyFingerprint (SHA-256 SPKI).
    struct Report {
        uint16 version;
        bytes32 profile;
        uint256 collectionId;
        bytes32 subjectId;
        bytes32 artistId;
        bytes32 bindingHash;
        uint64 generation;
        bytes32 identityRecordHash;
        bytes32 credentialRecordHash;
        bytes32 identityDocumentHash;
        bytes32 publicKeyHistoryHash;
        bytes32 credentialEnumerationHash;
        bytes32 selectedMediaManifestHash;
        uint8 mediaSlot; // 1 image, 2 animation, 3 content
        bytes32 mediaHash;
        bytes32 claimAssetHash;
        bytes32 manifestHash;
        bytes32 claimHash;
        bytes32 claimSignatureHash;
        uint8 signerKind; // 1 SHA-256 SPKI, 2 SHA-256 certificate; others unevaluated
        bytes32 signerFingerprint;
        bytes32 signerKeyFingerprint; // SHA-256 SPKI established by the selected verifier
        bytes32 keyId;
        uint64 signedAt;
        ValidationStatus validation;
        AuthorshipStatus authorship;
        bool assertsAuthorship;
        bytes32 validatorIdentityHash;
        bytes32 softwareVersionHash;
        bytes32 validationReportHash;
        bytes32 trustAnchorsHash;
        string reportURI;
    }

    struct Selection {
        bytes32 recordHash;
        bytes32 previousSelection;
        bytes32 selectionHash;
        uint64 revision;
        uint64 recordIndex;
        uint8 authorizationClass;
        Report report;
    }

    struct Display {
        bytes32 recordHash;
        bytes32 selectionHash;
        ValidationStatus validation;
        AuthorshipStatus authorship;
        bool current;
        bool assertsAuthorship;
    }

    error InvalidC2PAConfiguration();
    error C2PADependencyChanged(address target);
    error C2PAReadFailed(address target);
    error InvalidC2PAReport();
    error C2PASelectionConflict();
    event C2PAReconciliationSelected(
        uint256 indexed collectionId,
        bytes32 indexed subjectId,
        bytes32 indexed recordHash,
        Selection selection
    );
    event C2PAAttributionDivergence(
        uint256 indexed collectionId,
        bytes32 indexed subjectId,
        bytes32 indexed recordHash,
        bytes32 previousSelection,
        bytes32 selectionHash
    );

    function core() external view returns (address);
    function metadata() external view returns (address);
    function artist() external view returns (address);
    function verifier() external view returns (address);
    function adopt(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedSelection,
        uint64 expectedRevision
    ) external returns (bytes32);
    function currentSelection(uint256 collectionId, bytes32 subjectId)
        external
        view
        returns (Selection memory);
    function selectionAt(uint256 collectionId, bytes32 subjectId, uint64 revision)
        external
        view
        returns (Selection memory);
    /// @notice Stale pins or unavailable source return UNEVALUATED; immutable history stays readable.
    function display(uint256 collectionId, bytes32 subjectId) external view returns (Display memory);
}
