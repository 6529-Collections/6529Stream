// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScopedPreservationPolicyReferenceOriginalV1 as Original
} from "./StreamFinalityScopedPreservationPolicyReferenceOriginalV1.sol";
import {
    StreamPreservationPolicyReferenceFamiliesV2 as F
} from "../preservation/StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

import {
    StreamScopedPreservationPolicyReferenceTypesV1 as T
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    IStreamScopedPreservationPolicyReferencePublicationV1 as P
} from "../../interfaces/stream/preservation/IStreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    StreamScopedPreservationPolicyReferenceDefinitionsV1 as D
} from "../records/StreamScopedPreservationPolicyReferenceDefinitionsV1.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains,
    StreamFinalityComponentState,
    IStreamArtworkScopedFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";

/// @notice Exact scoped original reference records and current terminal lock for fixed providers.
/// @dev Caller supplies its constructor-pinned dependency configuration, never a per-request host.
/// These observations do not replace the complete scoped render-critical inventory or archive.
library StreamFinalityScopedPreservationPolicyReferenceReadsV1 {
    struct Dependencies {
        // Core, selected Metadata, Router, scoped snapshots, scoped reference publisher.
        address[5] targets;
        bytes32[5] codeHashes;
        uint256 chainId;
        uint256 readGas;
        uint256 sourceGas;
    }
    // Preserve the original scope validator error in this public library ABI.
    error InvalidMetadataScope();
    error InvalidScopedPreservationPolicyReferenceEvidence();
    error ScopedPreservationPolicyReferenceDependency(address source);

    function requireBindings(Dependencies memory d) public view {
        requireBindings(d, Profiles.ORIGINAL_PROFILE);
    }

    function requireBindings(Dependencies memory d, bytes32 family) public view {
        Original.requireBindings(d, family);
    }

    function original(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (T.Publication memory p, T.Receipt memory receipt) {
        return original(d, scope, hash, revision, Profiles.ORIGINAL_PROFILE);
    }

    function original(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision,
        bytes32 family
    ) public view returns (T.Publication memory p, T.Receipt memory receipt) {
        return Original.original(d, scope, hash, revision, family);
    }

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (T.Receipt memory receipt) {
        return requireCurrent(d, scope, hash, revision, Profiles.ORIGINAL_PROFILE);
    }

    function requireCurrent(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision,
        bytes32 family
    ) public view returns (T.Receipt memory receipt) {
        (, receipt) = original(d, scope, hash, revision, family);
        bytes memory raw = Reads.read(
            d.targets[4],
            abi.encodeCall(P.requireCurrent, (scope, hash, revision)),
            672,
            d.sourceGas
        );
        T.Receipt memory current = abi.decode(raw, (T.Receipt));
        _canonical(d.targets[4], raw, abi.encode(current));
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(receipt))) {
            revert InvalidScopedPreservationPolicyReferenceEvidence();
        }
    }

    function requireLocked(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (T.Receipt memory receipt, R.Lock memory locked) {
        return requireLocked(d, scope, hash, revision, Profiles.ORIGINAL_PROFILE);
    }

    function requireLocked(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision,
        bytes32 family
    ) public view returns (T.Receipt memory receipt, R.Lock memory locked) {
        receipt = requireCurrent(d, scope, hash, revision, family);
        bytes memory raw =
            Reads.read(d.targets[4], abi.encodeCall(P.referenceLock, (scope)), 128, d.readGas);
        locked = abi.decode(raw, (R.Lock));
        _canonical(d.targets[4], raw, abi.encode(locked));
        if (
            locked.actionId == 0 || locked.recordHash != hash || locked.revision != revision
                || locked.lockedAt < receipt.observation.recordedAt
                || locked.lockedAt > block.timestamp
        ) {
            revert InvalidScopedPreservationPolicyReferenceEvidence();
        }
    }

    function component(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) public view returns (StreamFinalityComponentState memory state) {
        return component(d, scope, hash, revision, Profiles.ORIGINAL_PROFILE);
    }

    function component(
        Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision,
        bytes32 family
    ) public view returns (StreamFinalityComponentState memory state) {
        F.Definition memory definition = F.definition(family, true);
        (T.Receipt memory receipt, R.Lock memory locked) =
            requireLocked(d, scope, hash, revision, family);
        bytes memory raw = Reads.read(
            d.targets[4],
            abi.encodeCall(IStreamArtworkScopedFinalityComponent.finalityStateForScope, (scope)),
            256,
            d.sourceGas
        );
        state = abi.decode(raw, (StreamFinalityComponentState));
        _canonical(d.targets[4], raw, abi.encode(state));
        if (
            !state.frozen || state.componentType != StreamFinalityDomains.COMPONENT_REFERENCE_RENDER
                || state.component != d.targets[4] || state.codeHash != d.codeHashes[4]
                || state.interfaceId != type(IStreamArtworkScopedFinalityComponent).interfaceId
                || state.moduleVersion != F.moduleVersion(family, true)
                || state.manifestHash != definition.profileHash
                || state.dataHash
                    != keccak256(
                        abi.encode(
                            F.componentDomain(family, true),
                            d.chainId,
                            d.targets[4],
                            d.targets[0],
                            scope,
                            receipt,
                            locked
                        )
                    )
        ) revert InvalidScopedPreservationPolicyReferenceEvidence();
    }

    function _canonical(address source, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) {
            revert ScopedPreservationPolicyReferenceDependency(source);
        }
    }
}
