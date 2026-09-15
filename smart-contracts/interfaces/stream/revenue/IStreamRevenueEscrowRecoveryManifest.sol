// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamEscrowRecoveryTypes.sol";
import "./IStreamSplitWallet.sol";

/// @notice Retained canonical recovery documents and their separately governed terminal route.
/// @dev Credit-event citations and Artist notice evidence are governance/operations assertions.
///      Entries and the affected-recipient set are independently verified by the contract.
interface IStreamRevenueEscrowRecoveryManifest {
    struct RecipientNotice {
        address account;
        bytes32 evidenceHash;
        uint64 noticedAt;
    }

    struct CollectionNotice {
        address core;
        uint256 collectionId;
        bool artistBound;
        address artistAuthority;
        bytes32 evidenceHash;
        uint64 noticedAt;
    }

    struct SourceCredit {
        address producer;
        bytes32 transactionHash;
        bytes32 blockHash;
        uint64 blockNumber;
        uint32 logIndex;
        uint32 collectionIndex;
    }

    struct ManifestDocument {
        StreamEscrowRecoveryTypes.EscrowCreditKey creditKey;
        address successorFactory;
        address successorWallet;
        bytes32 successorProfileId;
        bytes32 successorRuntimeCodeHash;
        uint256 expectedAmount;
        // 0 = identical entries; 1 = current affected-recipient consent; 2 = terminal notice route.
        uint8 route;
        IStreamSplitWallet.SplitEntry[] oldEntries;
        bytes32 oldMetadataURIHash;
        IStreamSplitWallet.SplitEntry[] successorEntries;
        RecipientNotice[] recipientNotices;
        CollectionNotice[] collectionNotices;
        SourceCredit[] sourceCredits;
        bytes32 incidentEvidenceHash;
        bytes32 coverageStatementHash;
    }

    event EscrowRecoveryManifestPublished(
        uint16 schemaVersion,
        bytes32 indexed contentHash,
        address indexed publisher,
        bytes32 indexed creditKeyHash,
        bytes32 oldEntriesHash,
        bytes32 successorEntriesHash,
        bytes32 affectedAccountsHash,
        uint8 route,
        uint64 publishedAt,
        bytes canonicalDocument
    );
    event EscrowRecoveryTerminalAuthorized(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        bytes32 indexed actionId,
        bytes32 indexed manifestContentHash,
        uint64 authorizedAt
    );

    function publishEscrowRecoveryManifest(
        ManifestDocument calldata document,
        StreamEscrowRecoveryTypes.EscrowRecoveryManifestRef calldata manifest
    ) external returns (bytes32 contentHash);

    function escrowRecoveryManifest(bytes32 contentHash)
        external
        view
        returns (bytes memory canonicalDocument, uint64 publishedAt);

    function escrowRecoveryAffectedAccountCount(bytes32 contentHash) external view returns (uint256);
    function escrowRecoveryAffectedAccountAt(bytes32 contentHash, uint256 index)
        external
        view
        returns (address);
    function escrowRecoveryTransitionHashes(
        StreamEscrowRecoveryTypes.EscrowCreditKey calldata creditKey,
        address successorWallet,
        bytes32 successorProfileId,
        bytes32 successorRuntimeCodeHash,
        uint256 expectedAmount,
        StreamEscrowRecoveryTypes.EscrowRecoveryManifestRef calldata recoveryManifest,
        uint64 executeAfter,
        bytes32 reasonHash,
        string calldata reasonURI
    )
        external
        view
        returns (bytes32 recoveryId, bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash);

    function escrowRecoveryCancellationHashes(
        bytes32 recoveryId,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external view returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash);

    function escrowRecoveryTerminalHashes(bytes32 recoveryId)
        external
        view
        returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash);
    function authorizeTerminalEscrowRecovery(bytes32 recoveryId) external;
}
