// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamMintLedgerImport.sol";

/// @notice Owner-operated proof import; the fixed batch schema is encoded to preserve Manager headroom.
interface IStreamMintManagerImport {
    struct ImportBatch {
        bytes32 importRoot;
        IStreamMintLedgerImport.CounterImportLeaf[] counters;
        bytes32[][] counterProofs;
        bytes32[] nullifiers;
        bytes32[][] nullifierProofs;
    }
    /// @notice encodedBatch is abi.encode(ImportBatch); at most 32 counter/nullifier leaves combined.
    function importMintState(bytes calldata encodedBatch) external;
}
