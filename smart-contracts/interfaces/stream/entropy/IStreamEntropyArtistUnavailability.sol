// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamEntropyFreshRecovery.sol";

/// @notice Exact current redraw intent for original Artist unavailability admission.
/// @dev No Finality record or governance recovery action is manufactured for entropy.
interface IStreamEntropyArtistUnavailability {
    struct Intent {
        uint256 collectionId;
        uint256 tokenId;
        bytes32 scopeId;
        bytes32 oldRequestKey;
        bytes32 newRequestKey;
        bytes32 priorJournalHead;
        bytes32 journalHead;
        bytes32 currentContentStateHash;
        bytes32 contentStateHash;
        bytes32 requestPolicyHash;
        bytes32 incidentEvidenceHash;
        bytes32 providerEvidenceHash;
        bytes32 reasonHash;
    }
    event EntropyUnavailabilityEvidence(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        bytes32 indexed findingRecordHash,
        bytes32 intentHash,
        uint64 noticeEndsAt
    );
    function artistEntropyRecoveryIntent(IStreamEntropyFreshRecovery.RecoveryInput calldata input)
        external
        view
        returns (Intent memory);
    /// @notice Only irreversible completion/output/supersession of the original request is terminal.
    function entropyRecoveryIntentTerminal(bytes32 oldRequestKey) external view returns (bool);
    function requestFreshEntropyWithUnavailability(
        IStreamEntropyFreshRecovery.RecoveryInput calldata input,
        bytes32 findingRecordHash
    ) external payable returns (bytes32 requestKey, uint256 providerRequestId);
    /// @notice Original receipt stays unchanged; this identifies its supplemental finding evidence.
    function entropyUnavailabilityEvidence(bytes32 requestKey)
        external
        view
        returns (bytes32 findingRecordHash, bytes32 intentHash, uint64 noticeEndsAt);
}
