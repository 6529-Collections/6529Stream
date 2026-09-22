// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamScopedPreservationPolicyContentRootEvidenceBindingV1 as RootProvider
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyContentRootEvidenceBindingV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as SnapshotInterface
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamFinalityScope
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamExternalArtifactCurrentPair
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";

contract PreservationSnapshotRootProviderBoundary is RootProvider {
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

    function scopedPreservationPolicySnapshotProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1");
    }

    function scopedPreservationPolicySnapshotHost(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (address)
    {
        require(keccak256(abi.encode(scope)) == selectedScope);
        return snapshots;
    }

    function scopedPreservationPolicySnapshotCodeHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        require(keccak256(abi.encode(scope)) == selectedScope);
        return snapshotRuntime;
    }

    function scopedPreservationPolicySnapshotValidationGas(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        require(keccak256(abi.encode(scope)) == selectedScope);
        return 128000000;
    }
}

/// @dev Explicit external ZIP/PNG identity, archival pair and repeated-capture observation boundary.
contract ScopedPreservationReferenceExternalBoundary {
    address public immutable core;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamExternalArtifactCurrentPair).interfaceId;
    }
}
