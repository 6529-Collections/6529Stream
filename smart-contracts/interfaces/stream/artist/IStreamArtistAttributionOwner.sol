// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistOwner.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Typed AttributionLifecycle owner boundary for the seven-operation onboarding profile.
/// @dev Mutations require the immutable coordinator and exact pre-operation owner snapshot.
interface IStreamArtistAttributionOwner is IStreamArtistOwner {
    function attributionState(uint256 collectionId) external view returns (uint8, uint64);

    function attestation(uint256 collectionId, uint8 kind, bytes32 subjectId)
        external
        view
        returns (T.AttestationRecord memory);

    function attestationRecord(bytes32 record) external view returns (T.AttestationRecord memory);

    function statementBytes(bytes32 hash) external view returns (bytes memory);

    function claim(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external;

    function accept(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 record
    ) external;

    function recordAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) external returns (bytes32 record);
}
