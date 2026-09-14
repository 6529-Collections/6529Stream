// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArchivalTypes as A } from "./StreamArchivalTypes.sol";

/// @notice Collection subjects have no fabricated Artist ID. Their envelope binds the collection.
interface IStreamCollectionArchivalCoverage {
    event CollectionArchivalEnvelopeRecorded(
        uint256 indexed collectionId, bytes32 indexed envelopeHash, bytes32 indexed evidenceHash
    );
    function recordCollectionEnvelope(
        uint256 collectionId,
        A.Envelope calldata envelope,
        bytes calldata payload
    ) external returns (bytes32);
    function collectionEnvelopeSubject(bytes32 envelopeHash) external view returns (uint256);
    function selectCollectionCoverage(bytes32 recordHash) external;
    function requireCollectionCoverage(
        bytes32 recordHash,
        uint256 collectionId,
        bytes32 evidenceHash
    ) external view returns (A.CoverageFacts memory);
    function requireCollectionEvidence(uint256 collectionId, bytes32 evidenceHash)
        external
        view
        returns (A.CoverageFacts memory);
}
