// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import { IStreamEntropyEpochs as E } from "./IStreamEntropyEpochs.sol";

/// @notice Provider requests through their ultimate policy origin, with immutable successor routes.
/// @dev Additive interface. Original request keys, provider identity,
/// context, snapshots, and seed derivation are retained; relayId is a separate route identity.
interface IStreamEntropyOriginRelay is IERC165 {
    /// @dev The origin recomputes the existing context; arbitrary context bytes are not accepted.
    struct RelayInput {
        bytes32 importHash;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 scopeId;
        bytes32 successorRequestKey;
        E.RequestPolicySnapshot policy;
    }

    /// @dev Fixed asynchronous evidence. rawReceived distinguishes a valid zero raw value from no
    /// result. lastOutcome alone is not evidence of delivery; read delivered and terminalStale.
    /// A synchronous INSTANT relay stores no result, subject, or cash on the origin.
    struct RelayResult {
        address successor;
        bytes32 successorCodeHash;
        bytes32 importHash;
        uint256 collectionId;
        bytes32 successorRequestKey;
        address provider;
        bytes32 providerCodeHash;
        bytes32 providerConfigHash;
        uint256 providerRequestId;
        bytes32 relayId;
        bytes32 contextHash;
        bool submitted;
        bool rawReceived;
        bool delivered;
        bool terminalStale;
        bytes32 raw;
        uint8 lastOutcome;
    }

    error InvalidEntropyRelay();
    error EntropyRelayUnauthorized(address caller);
    error EntropyRelayDependency(address target);
    error EntropyRelayAdmissionConflict(uint256 collectionId, address successor);
    error EntropyRelayAdmissionReplay(bytes32 actionId);
    error EntropyRelayWitnessMismatch(bytes32 successorRequestKey);
    error EntropyRelayRequestCollision(bytes32 successorRequestKey);
    error EntropyRelayProviderIdCollision(address provider, uint256 providerRequestId);
    error EntropyRelayFeeMismatch(uint256 supplied, uint256 required);
    error EntropyRelayResultUnavailable(bytes32 relayId);
    error EntropyRelayRawMismatch(bytes32 relayId);
    error EntropyRelayReadFailed(address target);

    event EntropyRelayAdmitted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed successor,
        bytes32 indexed importHash,
        bytes32 successorCodeHash,
        bytes32 policyHash,
        bytes32 actionId
    );
    event EntropyRelaySubmitted(
        uint16 schemaVersion,
        bytes32 indexed relayId,
        bytes32 indexed successorRequestKey,
        address indexed successor,
        uint256 collectionId,
        address provider,
        uint256 providerRequestId,
        bytes32 contextHash
    );
    event EntropyRelayRawReceived(
        uint16 schemaVersion,
        bytes32 indexed relayId,
        bytes32 indexed successorRequestKey,
        bytes32 rawRandomness
    );
    event EntropyRelayDelivery(
        uint16 schemaVersion,
        bytes32 indexed relayId,
        address indexed successor,
        bool delivered,
        bool terminalStale,
        uint8 outcome
    );

    /// @notice Exact class-1 admission permanently pins the successor/runtime/import/collection/H.
    function admitEntropyRelay(uint256 collectionId, address successor, bytes32 importHash) external;
    function entropyRelayAdmissionTransition(
        uint256 collectionId,
        address successor,
        bytes32 importHash
    ) external view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function entropyRelayAdmission(uint256 collectionId, address successor)
        external
        view
        returns (bytes32 successorCodeHash, bytes32 importHash, bytes32 policyHash);

    /// @notice Requires the admitted caller, ACTIVE import, and a complete prewritten witness.
    /// @dev Forwards exactly the live provider quote; creates no origin escrow or requester credit.
    function relayEntropyRequest(RelayInput calldata input)
        external
        payable
        returns (uint256 providerRequestId);
    /// @notice Recomputes and forwards the exact INSTANT context; successor derives the final seed.
    /// @dev Authentication reads and the outer INSTANT relay use separate governed envelopes,
    /// distinct from the origin's provider read cap. Nested calls require full EIP-150 availability
    /// and reserves. This interface sets no gas parameter identifier, floor, or default.
    function relayInstantEntropy(RelayInput calldata input)
        external
        view
        returns (bytes32 rawRandomness, bytes32 provenanceHash);
    /// @notice Direct local evidence exists only after request, snapshot, and route are prewritten.
    function relayRequestWitness(bytes32 successorRequestKey)
        external
        view
        returns (bytes32 witnessHash);
    /// @notice Successor delivery authenticates the recorded origin/runtime/relayId before finality.
    function fulfillRelayedEntropy(
        bytes32 successorRequestKey,
        bytes32 relayId,
        bytes32 rawRandomness
    ) external returns (uint8 outcome);
    /// @notice Retries captured output without a new provider call or latest Core pointer check.
    /// @dev Outcome 2, outcomes 4/5, failed calls, and malformed responses remain retryable.
    /// Outcomes 1/3 close only with authenticated evidence for the exact recorded request and seed
    /// context; unrelated later finalization is insufficient. terminalStale requires authenticated
    /// terminal evidence. ENTROPY_RELAY_DELIVERY_GAS_LIMIT is a proposed class-1 envelope; measured
    /// floor/default and bounded canonical uint8 decoding are implementation-owned.
    function retryEntropyRelay(bytes32 relayId) external returns (bool delivered, uint8 outcome);
    function entropyRelayResult(bytes32 relayId) external view returns (RelayResult memory);
}
