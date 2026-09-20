// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityStaticComponentFacts as Static
} from "./StreamFinalityStaticComponentFacts.sol";
import {
    StreamFinalityPreservationPolicyStaticSourceV1 as Source
} from "./StreamFinalityPreservationPolicyStaticSourceV1.sol";
import {
    StreamFinalityPreservationPolicySnapshotReadsV1 as Snapshots
} from "./StreamFinalityPreservationPolicySnapshotReadsV1.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Fixed COLLECTION V2 adapter into the shared ordered STATIC component algorithm.
/// @dev Dependencies originate only in the selected combined provider's constructor. The fresh
/// V2 source worker authenticates the complete original receipt/payload/source and snapshot lock
/// shape before this local projection. No V1/scoped receipt is cast and no reference/inventory
/// or component callback is introduced. Current output evidence remains separately required.
library StreamFinalityPreservationPolicyStaticComponentsV1 {
    error PolicyStaticSnapshotUnlocked();

    function facts(
        Snapshots.Dependencies memory d,
        address router,
        bytes32 routerCodeHash,
        StreamFinalityScope memory scope,
        bytes32 family
    ) public view returns (bool frozen, bytes32 dataHash) {
        Source.Projection memory source = Source.current(d, router, routerCodeHash, scope);
        // Source.current has just validated this same immutable host's current original lock
        // against the complete receipt. Require its action here: current alone is not frozen.
        bytes memory raw = Reads.read(
            d.snapshots, abi.encodeCall(Snapshot.snapshotLock, (scope)), 128, d.readGas
        );
        S.Lock memory locked = abi.decode(raw, (S.Lock));
        if (
            keccak256(raw) != keccak256(abi.encode(locked)) || locked.actionId == 0
                || locked.recordHash != source.snapshotRecordHash || locked.revision == 0
                || locked.lockedAt == 0 || locked.lockedAt > block.timestamp
        ) {
            revert PolicyStaticSnapshotUnlocked();
        }
        Static.Config memory config = Static.Config(
            d.core,
            d.metadata,
            router,
            source.selection,
            d.coreCodeHash,
            d.metadataCodeHash,
            routerCodeHash,
            source.selectionCodeHash,
            d.chainId,
            d.readGas,
            d.validationGas
        );
        Static.AuthenticatedSelection memory selected = Static.AuthenticatedSelection(
            source.scope,
            source.sourceProfile,
            source.selectionId,
            source.membershipHash,
            source.selectionRoot,
            source.tokenCount,
            source.lockedArtistSnapshotHash
        );
        return Static.facts(config, selected, family);
    }
}
