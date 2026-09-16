// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Enumerable authenticated Manager ancestry, separate from the retained import interface.
/// @dev Historical ancestry remains readable after retirement. A live descendant assertion additionally
///      requires the exact successor's completed import and current Ledger-writer authorization.
interface IStreamMintLedgerContinuity is IERC165 {
    struct MintManagerIdentity {
        address ledger;
        address manager;
    }

    event MintLedgerAncestorImported(
        bytes32 indexed importRoot,
        address indexed successorManager,
        address indexed ancestorLedger,
        address ancestorManager
    );

    function mintAncestorCount(address manager) external view returns (uint256);
    function mintAncestorAt(address manager, uint256 index)
        external
        view
        returns (address ledger, address ancestorManager);
    /// @notice Copies at most 32 frozen ancestor pairs from the committed predecessor.
    function importMintAncestors(bytes32 importRoot, uint256 maxCount) external;
    function mintImportAncestryProgress(bytes32 importRoot)
        external
        view
        returns (uint256 imported, uint256 required);
    function isCompletedMintDescendant(
        address ancestorLedger,
        address ancestorManager,
        address successorManager
    ) external view returns (bool);
}
