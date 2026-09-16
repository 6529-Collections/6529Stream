// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Evidence-bearing terminal incident declarations; never authorizes another draw.
interface IStreamEntropyIncidents is IERC165 {
    struct Incident {
        address declarer;
        uint64 declaredAtBlock;
        bytes32 evidenceHash;
        string reasonURI;
    }
    error InvalidIncidentEvidence();
    error IncidentRequestMismatch();
    error IncidentProviderProbeFailed();
    event EntropyRequestFailed(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        address indexed provider,
        bytes32 requestKey,
        uint32 providerEpoch,
        uint16 requestAttempt,
        string reasonURI,
        bytes32 evidenceHash
    );
    event EntropyScopeRequestFailed(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeId,
        address indexed provider,
        bytes32 requestKey,
        uint32 providerEpoch,
        uint16 requestAttempt,
        string reasonURI,
        bytes32 evidenceHash
    );
    /// @notice Requires the live incident role, timeout (or revocation), no result, and evidence.
    function markEntropyRequestUnrecoverable(
        uint256 tokenId,
        string calldata reasonURI,
        bytes32 evidenceHash
    ) external;
    /// @notice Same incident requirements for an original registered scope.
    function markEntropyScopeRequestUnrecoverable(
        bytes32 scopeId,
        string calldata reasonURI,
        bytes32 evidenceHash
    ) external;
    /// @notice Immutable incident evidence, keyed by original request. Unknown keys return zeros.
    function entropyIncident(bytes32 requestKey) external view returns (Incident memory);
}
