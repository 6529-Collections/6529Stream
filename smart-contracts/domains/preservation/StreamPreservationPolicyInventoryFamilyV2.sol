// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Output
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";

/// @notice Closed family joins for contexts already admitted by the inventory host's current guard.
library StreamPreservationPolicyInventoryFamilyV2 {
    function valid(bytes32 family) internal pure returns (bool) {
        return family == Profiles.ORIGINAL_PROFILE || family == Profiles.FAMILY_PROFILE;
    }

    function allows(bytes32 family, bytes32 producer) internal pure returns (bool) {
        return family == Profiles.ORIGINAL_PROFILE
            ? producer == Profiles.ORIGINAL_PROFILE
            : family == Profiles.FAMILY_PROFILE && Profiles.isSupported(producer);
    }

    /// @dev V1 retains its original reads. V2 additionally rebinds the entire saved plan to the
    /// pinned checkpoint and manifest before interpreting the row's distinct producer marker.
    function requirePlan(
        S.Dependencies memory d,
        address checkpoint,
        bytes32 checkpointCodeHash,
        bytes32 checkpointHash,
        Content.Plan memory p,
        Output.Manifest memory m,
        bool scoped
    ) internal view returns (bytes32 family) {
        family = p.preservationProfile;
        if (family == Profiles.ORIGINAL_PROFILE) return family;
        if (
            family != Profiles.FAMILY_PROFILE || m.preservationProfile != family
                || checkpointHash == 0 || m.checkpointHash != checkpointHash
                || m.checkpointStateHash != keccak256(abi.encode(p)) || p.tokenCount == 0
                || p.nextIndex != p.tokenCount || p.tokenCount != m.tokenCount || p.contentRoot == 0
                || p.contentRoot != m.contentRoot || p.outputRoot == 0
                || p.outputRoot != m.outputRoot || m.metadataRouter != d.targets[4]
                || p.inventoryHash != m.inventoryHash || p.policyChainHash != m.policyChainHash
                || keccak256(abi.encode(p.scope)) != keccak256(abi.encode(m.scope))
        ) revert T.InventorySourceChanged();
        IO.pin(checkpoint, checkpointCodeHash);
        bytes memory raw = IO.fixedRead(
            checkpoint, abi.encodeCall(Content.checkpoint, (checkpointHash)), 448, d.readGas
        );
        if (keccak256(raw) != keccak256(abi.encode(p))) revert T.InventorySourceChanged();
        if (
            IO.word(checkpoint, abi.encodeCall(Content.preservationPolicyProfile, ()), d.readGas)
                    != (scoped
                            ? Profiles.SCOPED_CHECKPOINT_PROFILE
                            : Profiles.COLLECTION_CHECKPOINT_PROFILE)
                || IO.word(
                        checkpoint, abi.encodeCall(Content.preservationOutputProfile, ()), d.readGas
                    ) != family
        ) revert T.InventorySourceChanged();
    }
}
