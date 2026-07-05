// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Narrow consumer seam over the collection-metadata satellite surfaces the finality
///         registry (and its preview tooling) reads.
/// @dev Shapes follow docs/collection-metadata-contract.md: [CMC-CONTENT-ROOT] rule 4 for the
///      content-root read, [CMC-LOCKS] for lock state, snapshot publication for the assembled
///      snapshot hash, [CMC-FACADE-BINDING] for the identity binding record, and the scoped
///      finality model for scope manifest publication. The satellite additionally serves the
///      generic component read (`finalityState`/`finalityStateForScope`) as one of the
///      submitted finality components; that surface lives in
///      IStreamArtworkFinalityComponents.sol.
interface IStreamFinalityMetadataReads {
    /// @notice Recorded token content root for a [CMC-SUBJECT-ID] scope subject.
    function tokenContentRoot(uint256 collectionId, bytes32 scopeSubject)
        external
        view
        returns (bytes32 contentRoot, uint64 leafCount, bytes32 schemaId);

    /// @notice Latest assembled snapshot manifest hash ([CMC-FINALITY-INPUTS] rule 3 input).
    function latestCollectionSnapshotHash(uint256 collectionId) external view returns (bytes32);

    /// @notice Explicit lock state for one record-type key ([CMC-LOCKS]).
    function collectionRecordTypeLocked(uint256 collectionId, bytes32 recordType)
        external
        view
        returns (bool);

    /// @notice Accepted IDENTITY_FACADE_BINDING record ([CMC-FACADE-BINDING]); at most one per
    ///         collection, absent by construction for CORE_NATIVE collections.
    function facadeIdentityBindingRecord(uint256 collectionId)
        external
        view
        returns (bool recorded, address facadeAddress, bytes32 recordHash);

    /// @notice Published scope manifest for RELEASE/SEASON/VIEW scope IDs
    ///         (Scoped Finality For Open Series, scope rule 3).
    function scopeManifest(uint256 collectionId, bytes32 scopeId)
        external
        view
        returns (bool published, bytes32 manifestHash);
}
