// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Authenticated bulk continuity from a permanently retired predecessor writer.
interface IStreamMintLedgerImport is IERC165 {
    struct CounterImportLeaf {
        uint256 collectionId;
        bytes32 phaseId;
        bytes32 counterId;
        uint8 keyMode;
        bytes32 subjectBasis;
        bytes32 predecessorSubjectKey;
        uint64 value;
    }

    struct ImportCommitment {
        address predecessorLedger;
        address predecessorManager;
        address successorManager;
        uint64 snapshotBlock;
        bytes32 manifestHash;
        uint64 importedCounters;
        uint64 importedNullifiers;
        bool complete;
    }

    error MintImportInvalid();
    error MintImportNotReady(address manager);
    error MintImportProofInvalid(bytes32 leaf);
    error MintImportLeafAlreadyUsed(bytes32 leaf);
    error MintImportGovernanceInvalid();

    event MintLedgerWriterRetired(address indexed writer, uint64 blockNumber);
    event MintLedgerImportRootCommitted(
        uint16 schemaVersion,
        bytes32 indexed importRoot,
        address indexed predecessorManager,
        address indexed successorManager,
        address predecessorLedger,
        uint64 snapshotBlock,
        bytes32 manifestHash
    );
    event MintLedgerCounterImported(
        uint16 schemaVersion,
        bytes32 indexed importRoot,
        bytes32 indexed valueKey,
        bytes32 indexed subjectKey,
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        uint64 importedValue,
        uint64 resultingValue
    );
    event MintLedgerNullifierImported(
        uint16 schemaVersion,
        bytes32 indexed importRoot,
        bytes32 indexed nullifier,
        address indexed successorManager
    );
    event MintLedgerImportAction(bytes32 indexed importRoot, bytes32 indexed actionId);
    event MintLedgerImportProfileCopied(
        bytes32 indexed importRoot, bytes32 indexed definitionHash, bool defined
    );
    event MintLedgerImportCompleted(
        bytes32 indexed importRoot,
        address indexed successorManager,
        uint64 counterLeaves,
        uint64 nullifierLeaves
    );

    function retireLedgerWriter(address writer) external;
    function ledgerWriterRetiredAt(address writer) external view returns (uint64);
    function commitCounterImportRoot(
        address predecessorLedger,
        address predecessorManager,
        address successorManager,
        uint64 snapshotBlock,
        bytes32 importRoot,
        bytes32 manifestHash
    ) external;
    function importCounterValue(
        bytes32 importRoot,
        CounterImportLeaf calldata leaf,
        bytes32 successorSubjectKey,
        bytes32[] calldata proof
    ) external;
    function importNullifier(bytes32 importRoot, bytes32 nullifier, bytes32[] calldata proof)
        external;
    /// @notice Copies at most 32 exact profiles from the permanently retired predecessor.
    function importCounterDefinitions(bytes32 importRoot, uint256 maxCount) external;
    function mintImportDefinitionProgress(bytes32 importRoot)
        external
        view
        returns (uint256 imported, uint256 required);
    /// @notice Seals only after every leaf counted by the committed descriptor has been imported.
    function completeCounterImport(
        bytes32 importRoot,
        uint64 counterLeaves,
        uint64 nullifierLeaves,
        bytes32[] calldata descriptorProof
    ) external;
    function mintImportCommitment(bytes32 importRoot)
        external
        view
        returns (ImportCommitment memory);
    function isMintSuccessorReady(
        address predecessorLedger,
        address predecessorManager,
        address successorManager
    ) external view returns (bool);
}
