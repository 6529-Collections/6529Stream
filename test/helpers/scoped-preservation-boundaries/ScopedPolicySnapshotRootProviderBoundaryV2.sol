// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamScopedPolicyContentRootEvidenceBindingV2 as RootProvider
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentRootEvidenceBindingV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as SnapshotInterface
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamFinalityScope
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Explicit selected-provider discovery boundary. The immutable snapshot is the genuine
/// producer below; this boundary computes no payload, receipt, currentness or policy evidence.

contract ScopedPolicySnapshotRootProviderBoundaryV2 is RootProvider {
    address public immutable metadataHost;
    address private immutable snapshots;
    bytes32 private immutable snapshotRuntime;
    bytes32 private immutable selectedScope;

    constructor(address host, StreamFinalityScope memory scope) {
        snapshots = host;
        snapshotRuntime = host.codehash;
        metadataHost = SnapshotInterface(host).metadataHost();
        selectedScope = keccak256(abi.encode(scope));
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(RootProvider).interfaceId;
    }

    function scopedPolicySnapshotProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2");
    }

    function scopedPolicySnapshotHost(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (address)
    {
        require(keccak256(abi.encode(scope)) == selectedScope);
        return snapshots;
    }

    function scopedPolicySnapshotCodeHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        require(keccak256(abi.encode(scope)) == selectedScope);
        return snapshotRuntime;
    }

    function scopedPolicySnapshotValidationGas(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        require(keccak256(abi.encode(scope)) == selectedScope);
        return 128000000;
    }
}
