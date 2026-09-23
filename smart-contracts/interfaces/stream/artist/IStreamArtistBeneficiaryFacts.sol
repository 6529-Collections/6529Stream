// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Actual accepted collection artist and its current explicit payout designation.
/// @dev Reverts when attribution or designation is not operative; never substitutes the signing address.
interface IStreamArtistBeneficiaryFacts {
    function collectionArtistBeneficiary(uint256 collectionId)
        external
        view
        returns (bytes32 artistId, address payoutAccount, bytes32 designationRecordHash);
}
