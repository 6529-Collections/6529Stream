// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistSanctionTypes as S } from "./StreamArtistSanctionTypes.sol";
import { StreamFinalityScope } from "../finality/IStreamArtworkFinalityComponents.sol";

/// @notice Additive AA-DISPLAY reads; the caller supplies its authentic live subject hash.
interface IStreamArtistDisplayFacts {
    /// @notice Raw proposed/current binding in every attribution state; no acceptance claim.
    function displayBinding(uint256 collectionId) external view returns (T.Binding memory);
    function artistAttestationStatus(
        uint256 collectionId,
        uint8 subjectKind,
        bytes32 subjectId,
        bytes32 currentSubjectStateHash
    )
        external
        view
        returns (
            uint8 status,
            bytes32 attestationRecordHash,
            bytes32 attestedSubjectStateHash,
            uint8 authorityClass,
            uint64 signedAt
        );
    /// @notice Exact current binding-associated sanction, independent of saved finality components.
    function displaySanction(StreamFinalityScope calldata scope)
        external
        view
        returns (S.Record memory);
    /// @notice Total op9/op10 claims and actual last committed claim, including after correction.
    function attributionClaims(uint256 collectionId)
        external
        view
        returns (uint256 claimCount, bytes32 latestClaimRecordHash);
    /// @notice Latest historical deployment reference; status/freshness is a separate comparison.
    function deploymentAttestation(uint256 collectionId)
        external
        view
        returns (bytes32 recordHash, uint8 authorityClass, uint64 signedAt);
    /// @notice Zero means absent/unknown, never an inferred living-Artist authority.
    function attestationAuthorityClass(bytes32 recordHash) external view returns (uint8);
}
