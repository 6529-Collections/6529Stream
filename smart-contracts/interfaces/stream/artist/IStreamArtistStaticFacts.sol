// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistPlatformTypes as PW } from "./StreamArtistPlatformTypes.sol";
import { StreamArtistSanctionTypes as S } from "./StreamArtistSanctionTypes.sol";

/// @notice Fixed-owner direct storage facts for the additive STATIC display path.
/// @dev No write, slot, target or caller-authority input is accepted. Original reads remain intact.
interface IStreamArtistStaticFacts {
    struct Attestation {
        bytes32 recordHash;
        uint64 generation;
        bytes32 subjectStateHash;
        uint8 authorityClass;
        uint64 signedAt;
    }
    function staticAuthorityState(bytes32 artistId)
        external
        view
        returns (address, uint8, uint8, bytes32);
    function staticIdentityMetadata(bytes32 artistId) external view returns (string memory, bytes32);
    function staticAttributionState(uint256 id) external view returns (uint8, uint64);
    function staticPlatformWorksState(uint256 id) external view returns (PW.State memory);
    function staticAttributionClaims(uint256 id) external view returns (uint256, bytes32);
    function staticAttestation(uint256 id, uint8 kind, bytes32 subject)
        external
        view
        returns (Attestation memory);
    function staticSanctionRecord(bytes32 associationKey)
        external
        view
        returns (bytes32, S.Record memory);
}
