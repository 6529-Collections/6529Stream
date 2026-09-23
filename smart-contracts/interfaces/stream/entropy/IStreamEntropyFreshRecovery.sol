// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Ordered incident recovery under a policy frozen before registration.
interface IStreamEntropyFreshRecovery is IERC165 {
    struct RecoveryInput {
        bytes32 oldRequestKey;
        string reasonURI;
        bytes32 providerEvidenceHash;
    }

    struct RecoveryReceipt {
        bytes32 previousRequestKey;
        bytes32 artistRecordHash;
        bytes32 providerEvidenceHash;
        bytes32 incidentEvidenceHash;
        bytes32 evidenceHash;
        bytes32 contentStateHash;
        bytes32 journalHead;
        uint64 requestedAtBlock;
        bool acceptLateOriginalFulfillment;
    }
    error FreshRecoveryUnavailable(bytes32 requestKey);
    error FreshRecoveryTooEarly(uint256 eligibleAfterBlock);
    error FreshRecoveryArtistEvidenceUnavailable();
    error FreshRecoveryEvidenceConsumed(bytes32 recordHash);
    event EntropyRecoveryRequested(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        address indexed oldProvider,
        address newProvider,
        bytes32 oldRequestKey,
        bytes32 newRequestKey,
        uint32 oldProviderEpoch,
        uint32 newProviderEpoch,
        string reasonURI,
        bytes32 evidenceHash
    );
    event EntropyRecoveryEvidence(
        uint16 schemaVersion,
        bytes32 indexed newRequestKey,
        bytes32 indexed scopeId,
        bytes32 artistRecordHash,
        bytes32 providerEvidenceHash,
        bytes32 incidentEvidenceHash,
        bytes32 contentStateHash,
        bytes32 journalHead
    );
    event StaleEntropyFulfillment(
        uint16 schemaVersion,
        uint256 indexed tokenId,
        address indexed provider,
        bytes32 requestKey,
        uint32 providerEpoch,
        string reason
    );
    event EntropyRecoverySuperseded(
        uint16 schemaVersion,
        bytes32 indexed acceptedRequestKey,
        bytes32 indexed displacedRequestKey
    );
    function requestFreshEntropy(RecoveryInput calldata input)
        external
        payable
        returns (bytes32 requestKey, uint256 providerRequestId);
    function freshRecoveryTransition(RecoveryInput calldata input)
        external
        view
        returns (bytes32 requestKey, bytes32 contentStateHash, uint256 providerFee);
    function freshRecoveryReceipt(bytes32 requestKey) external view returns (RecoveryReceipt memory);
    function artistContentFamilyState(uint256 collectionId, bytes32 familyId)
        external
        view
        returns (bool supported, bytes32 currentStateHash);
}
