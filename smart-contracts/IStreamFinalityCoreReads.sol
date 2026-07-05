// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";

/// @notice Narrow consumer seam over the StreamCore surfaces the finality registry reads.
/// @dev The Core sides are specified at [LTA-FINALITY] (CoreCollectionFinalityFacts, scoped
///      Core facts), [CMC-BURN] rule 6 (one-way burn block plus activation height), and
///      [PV1-FACADE-READINESS]/[PV1-IDENTITY-MODE] (identity mode, transfer controller).
///      Those Core surfaces are built in a parallel worktree; this file pins only the shapes
///      this registry consumes so the integration wave binds one address that satisfies them.
interface IStreamFinalityCoreReads {
    /// @notice Typed collection facts hashed into the collection finality record.
    function coreCollectionFinalityFacts(uint256 collectionId)
        external
        view
        returns (StreamCoreCollectionFinalityFacts memory);

    /// @notice Typed scoped facts hashed into scoped finality records.
    function scopedCoreFinalityFacts(StreamFinalityScope calldata scope)
        external
        view
        returns (StreamScopedCoreFinalityFacts memory);

    /// @notice One-way burn block state ([CMC-BURN] rule 6); the finality-registry surface.
    function collectionBurnsBlocked(uint256 collectionId) external view returns (bool);

    /// @notice Burn-block activation height; zero until the burn block executes.
    function collectionBurnsBlockedAtBlock(uint256 collectionId) external view returns (uint64);

    /// @notice Collection identity mode ID ([PV1-IDENTITY-MODE]): keccak256("CORE_NATIVE") by
    ///         default, keccak256("EXTERNAL_FACADE") after a facade declaration.
    function collectionIdentityMode(uint256 collectionId) external view returns (bytes32);

    /// @notice Registered transfer controller (facade); zero address for CORE_NATIVE.
    function collectionTransferController(uint256 collectionId) external view returns (address);
}
