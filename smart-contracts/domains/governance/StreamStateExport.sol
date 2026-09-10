// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/governance/IStreamStateExportPublisher.sol";
import "../../interfaces/stream/governance/IStreamStateExportOperations.sol";
import "../../interfaces/stream/governance/IStreamStateExportHistory.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../metadata/StreamMetadataRenderer.sol";
import "./StreamGovernanceManifest.sol";

/// @notice Linked append-only publication logic, executing in the Executor's address context.
/// @dev A dedicated hash namespace leaves all existing governance storage slots intact.
///      The immutable linked code has no standalone authority or useful standalone state.
library StreamStateExport {
    bytes32 private constant STORAGE_SLOT = keccak256("6529Stream.stateExport.storage.v1");
    bytes32 private constant POINTER_TYPE = keccak256("STATE_EXPORT_PUBLISHER");
    uint256 private constant MAX_URI_BYTES = 2_048;

    // Solidity 0.8.19 libraries cannot inherit interface events. Keep these exact
    // copies of the pinned publisher schema; receipt tests assert all topics/data.
    event StateExportPublished(
        uint16 schemaVersion,
        uint256 indexed blockNumber,
        bytes32 indexed exportHash,
        bytes32 indexed manifestHash,
        bytes32 blockHash,
        string manifestURI
    );
    event StateExportChallenged(
        uint16 schemaVersion,
        bytes32 indexed exportHash,
        bytes32 indexed challengeHash,
        address indexed challenger,
        string challengeURI
    );
    event StateExportSuperseded(
        uint16 schemaVersion,
        bytes32 indexed oldExportHash,
        bytes32 indexed newExportHash,
        bytes32 indexed reasonHash,
        string reasonURI
    );

    struct State {
        bytes32[] hashes;
        mapping(bytes32 => StreamStateExportRecord) records;
        mapping(bytes32 => bytes32) supersededBy;
        mapping(bytes32 => mapping(bytes32 => bool)) challenges;
    }

    /// @notice Dispatch exact writer calldata through one small Executor forwarding path.
    function write(
        StreamGovernanceManifest.LifecycleState storage manifest,
        bool executing,
        bytes calldata input
    ) public {
        if (executing) {
            revert IStreamStateExportOperations.StateExportDuringGovernanceExecution();
        }
        _requireActivePublisher(manifest);
        bytes4 selector = bytes4(input[:4]);
        State storage state = _state();
        if (selector == IStreamStateExportOperations.challengeStateExport.selector) {
            (bytes32 exportHash, bytes32 challengeHash, string memory uri) =
                abi.decode(input[4:], (bytes32, bytes32, string));
            _challenge(state, exportHash, challengeHash, uri);
            return;
        }
        StreamGovernanceManifest.requireBoundRoleRegistry(manifest);
        if (!manifest.roleRegistry.hasRole(StreamRoles.ROLE_EXPORT_PUBLISHER, msg.sender)) {
            revert IStreamStateExportOperations.StateExportPublisherUnauthorized(msg.sender);
        }
        if (selector == IStreamStateExportOperations.publishStateExport.selector) {
            (
                uint256 number,
                bytes32 anchor,
                bytes32 exportHash,
                bytes32 manifestHash,
                string memory uri
            ) = abi.decode(input[4:], (uint256, bytes32, bytes32, bytes32, string));
            _publish(state, number, anchor, exportHash, manifestHash, uri);
        } else if (selector == IStreamStateExportOperations.supersedeStateExport.selector) {
            (bytes32 oldHash, bytes32 newHash, bytes32 reasonHash, string memory uri) =
                abi.decode(input[4:], (bytes32, bytes32, bytes32, string));
            _supersede(state, oldHash, newHash, reasonHash, uri);
        } else {
            revert IStreamStateExportOperations.StateExportPublisherInactive();
        }
    }

    function encodeLatest() public view returns (bytes memory) {
        State storage state = _state();
        bytes32 exportHash =
            state.hashes.length == 0 ? bytes32(0) : state.hashes[state.hashes.length - 1];
        StreamStateExportRecord storage record = state.records[exportHash];
        return abi.encode(
            record.blockNumber,
            record.blockHash,
            record.exportHash,
            record.manifestHash,
            record.manifestURI
        );
    }

    function encodeRecord(bytes32 exportHash) public view returns (bytes memory) {
        State storage state = _state();
        return abi.encode(state.records[exportHash], state.supersededBy[exportHash]);
    }

    function count() public view returns (uint256) {
        return _state().hashes.length;
    }

    function hashAt(uint256 index) public view returns (bytes32) {
        State storage state = _state();
        if (index >= state.hashes.length) {
            revert IStreamStateExportOperations.StateExportIndexOutOfBounds(index);
        }
        return state.hashes[index];
    }

    function challengeExists(bytes32 exportHash, bytes32 challengeHash) public view returns (bool) {
        return _state().challenges[exportHash][challengeHash];
    }

    function _requireActivePublisher(StreamGovernanceManifest.LifecycleState storage manifest)
        private
        view
    {
        if (
            !manifest.bound || manifest.core == address(0)
                || manifest.core.codehash != manifest.coreCodeHash
        ) {
            revert IStreamStateExportOperations.StateExportPublisherInactive();
        }
        (address target, bytes32 codeHash,, bytes32 moduleType, bytes4 interfaceId,,,,,) =
            IStreamCorePointers(manifest.core).getSatellitePointer(POINTER_TYPE);
        if (
            target != address(this) || codeHash != address(this).codehash
                || moduleType != keccak256("GOVERNANCE_LAYER")
                || interfaceId != type(IStreamStateExportPublisher).interfaceId
        ) {
            revert IStreamStateExportOperations.StateExportPublisherInactive();
        }
    }

    function _publish(
        State storage state,
        uint256 number,
        bytes32 anchor,
        bytes32 exportHash,
        bytes32 manifestHash,
        string memory uri
    ) private {
        if (exportHash == bytes32(0) || manifestHash == bytes32(0)) {
            revert IStreamStateExportOperations.StateExportInvalidHash();
        }
        if (state.records[exportHash].sequence != 0) {
            revert IStreamStateExportOperations.StateExportAlreadyPublished(exportHash);
        }
        if (
            number == 0 || number >= block.number || block.number - number > 256
                || anchor == bytes32(0) || blockhash(number) != anchor
        ) {
            revert IStreamStateExportOperations.StateExportInvalidAnchor(number, anchor);
        }
        uint256 length = state.hashes.length;
        if (length != 0) {
            StreamStateExportRecord storage previous = state.records[state.hashes[length - 1]];
            if (
                number < previous.blockNumber
                    || (number == previous.blockNumber && anchor == previous.blockHash)
            ) {
                revert IStreamStateExportOperations.StateExportAnchorNotIncreasing(
                    previous.blockNumber, number
                );
            }
        }
        _validateURI(uri);
        state.hashes.push(exportHash);
        state.records[exportHash] =
            StreamStateExportRecord(number, anchor, exportHash, manifestHash, uri, length + 1);
        emit StateExportPublished(1, number, exportHash, manifestHash, anchor, uri);
    }

    function _challenge(
        State storage state,
        bytes32 exportHash,
        bytes32 challengeHash,
        string memory uri
    ) private {
        if (state.records[exportHash].sequence == 0) {
            revert IStreamStateExportOperations.StateExportUnknown(exportHash);
        }
        if (challengeHash == bytes32(0)) {
            revert IStreamStateExportOperations.StateExportInvalidHash();
        }
        if (state.challenges[exportHash][challengeHash]) {
            revert IStreamStateExportOperations.StateExportChallengeAlreadyRecorded(
                exportHash, challengeHash
            );
        }
        _validateURI(uri);
        state.challenges[exportHash][challengeHash] = true;
        emit StateExportChallenged(1, exportHash, challengeHash, msg.sender, uri);
    }

    function _supersede(
        State storage state,
        bytes32 oldHash,
        bytes32 newHash,
        bytes32 reasonHash,
        string memory uri
    ) private {
        if (state.records[oldHash].sequence == 0) {
            revert IStreamStateExportOperations.StateExportUnknown(oldHash);
        }
        if (state.records[newHash].sequence == 0) {
            revert IStreamStateExportOperations.StateExportUnknown(newHash);
        }
        if (
            state.supersededBy[oldHash] != bytes32(0)
                || state.records[newHash].sequence <= state.records[oldHash].sequence
        ) {
            revert IStreamStateExportOperations.StateExportInvalidSupersession(oldHash, newHash);
        }
        if (reasonHash == bytes32(0)) revert IStreamStateExportOperations.StateExportInvalidHash();
        _validateURI(uri);
        state.supersededBy[oldHash] = newHash;
        emit StateExportSuperseded(1, oldHash, newHash, reasonHash, uri);
    }

    function _validateURI(string memory uri) private pure {
        if (
            bytes(uri).length == 0 || bytes(uri).length > MAX_URI_BYTES
                || !StreamMetadataRenderer.isValidUtf8(uri)
        ) {
            revert IStreamStateExportOperations.StateExportInvalidURI();
        }
    }

    function _state() private pure returns (State storage state) {
        bytes32 slot = STORAGE_SLOT;
        assembly ("memory-safe") { state.slot := slot }
    }
}
