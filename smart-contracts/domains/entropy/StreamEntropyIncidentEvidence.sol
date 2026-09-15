// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/entropy/IStreamEntropyIncidents.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";

/// @notice Fixed worker for exact bounded negative-result evidence and retained incident records.
/// @dev Host storage and original caller are retained through the linked-library call.
library StreamEntropyIncidentEvidence {
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_INCIDENT_EVIDENCE_STORAGE_V1");

    struct Store {
        mapping(bytes32 => IStreamEntropyIncidents.Incident) records;
    }

    function _store() private pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function incident(bytes32 key) public view returns (IStreamEntropyIncidents.Incident memory) {
        return _store().records[key];
    }

    function record(
        bytes32 key,
        address provider,
        bytes32 pinnedCodeHash,
        uint256 requestId,
        uint256 cap,
        string calldata reasonURI,
        bytes32 evidenceHash
    ) public {
        if (evidenceHash == 0 || bytes(reasonURI).length == 0 || bytes(reasonURI).length > 2048) {
            revert IStreamEntropyIncidents.InvalidIncidentEvidence();
        }
        if (key == 0 || _store().records[key].declarer != address(0)) {
            revert IStreamEntropyIncidents.IncidentRequestMismatch();
        }
        requireNegative(key, provider, pinnedCodeHash, requestId, cap);
        if (block.number > type(uint64).max) {
            revert IStreamEntropyIncidents.InvalidIncidentEvidence();
        }
        _store().records[key] = IStreamEntropyIncidents.Incident(
            msg.sender, uint64(block.number), evidenceHash, reasonURI
        );
    }

    /// @notice Repeat the identical bounded negative-result proof without creating an incident.
    function requireNegative(
        bytes32 key,
        address provider,
        bytes32 pinnedCodeHash,
        uint256 requestId,
        uint256 cap
    ) public view {
        if (provider.code.length == 0 || provider.codehash != pinnedCodeHash) {
            revert IStreamEntropyIncidents.IncidentProviderProbeFailed();
        }
        bytes memory input =
            abi.encodeCall(IStreamEntropyProvider.providerResultStatus, (requestId));
        bytes memory output = new bytes(160);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, provider, add(input, 32), mload(input), add(output, 32), 160)
            size := returndatasize()
        }
        if (!ok || size != 160) revert IStreamEntropyIncidents.IncidentProviderProbeFailed();
        // Decode as integers first: malformed enum/bool words must never become negative evidence.
        (uint256 status, bytes32 boundKey, bytes32 rawHash, uint256 received, uint256 delivered) =
            abi.decode(output, (uint256, bytes32, bytes32, uint256, uint256));
        if (
            boundKey != key || rawHash != 0 || received != 0 || delivered != 0
                || (status != uint256(StreamProviderResultStatus.REQUESTED)
                    && status != uint256(StreamProviderResultStatus.TERMINAL_STALE)
                    && status != uint256(StreamProviderResultStatus.TERMINAL_FAILED))
        ) {
            revert IStreamEntropyIncidents.IncidentProviderProbeFailed();
        }
    }
}
