// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Content classification and state derived from the actual admitted metadata host.
interface IStreamArtistContentMutationFacts {
    /// @notice Unknown families return supported=false; supported state commits actual stored content.
    function artistContentFamilyState(uint256 collectionId, bytes32 familyId)
        external
        view
        returns (bool supported, bytes32 currentStateHash);

    function artistContentLockState(uint256 collectionId, bytes32 lockClass)
        external
        view
        returns (bool supported, bool locked);

    /// @notice Current collection commitment without requiring mint-ready or nonempty artwork.
    /// @dev Defensive freezes must remain available before first-release ratification.
    function artistContentFreezeState(uint256 collectionId)
        external
        view
        returns (bytes32 currentContentStateHash);

    /// @notice Witness recorded only by a successful consented content mutation in this host.
    function artistContentEvolution(uint256 collectionId)
        external
        view
        returns (bytes32 operativeRatificationRecordHash, bytes32 resultingContentStateHash);
}
