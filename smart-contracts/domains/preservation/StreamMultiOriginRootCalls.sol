// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamArtistArchiveOriginReads as Reads
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginReads.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamMultiOriginInventoryCalls as Calls } from "./StreamMultiOriginInventoryCalls.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as Policy
} from "../../interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as ScopedPolicy
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";

library StreamMultiOriginRootCalls {
    function scopedContentItem(
        S.Dependencies memory d,
        O.Dependencies memory od,
        Scoped.Context memory c,
        address actor,
        uint64 observedAt,
        Root.Aggregate memory aggregate,
        bytes32 legacyFamily,
        bytes32 contextHash,
        O.ReceiptWitness memory witness
    ) public view returns (T.Item memory item, O.RecordOrigin memory original) {
        Calls.pin(od);
        bytes memory raw = IO.read(
            od.worker,
            abi.encodeCall(
                Reads.scopedContentItem,
                (d, c, actor, observedAt, aggregate, legacyFamily, contextHash, witness)
            ),
            16384,
            od.originGas
        );
        (item, original) = abi.decode(raw, (T.Item, O.RecordOrigin));
        IO.canonical(od.worker, raw, abi.encode(item, original));
    }

    function policyContentItem(
        S.Dependencies memory d,
        O.Dependencies memory od,
        Policy.Context memory c,
        address actor,
        uint64 observedAt,
        Root.Aggregate memory aggregate,
        bytes32 contextHash,
        O.ReceiptWitness memory witness
    ) public view returns (T.Item memory item, O.RecordOrigin memory original) {
        Calls.pin(od);
        bytes memory raw = IO.read(
            od.worker,
            abi.encodeCall(
                Reads.policyContentItem, (d, c, actor, observedAt, aggregate, contextHash, witness)
            ),
            16384,
            od.originGas
        );
        (item, original) = abi.decode(raw, (T.Item, O.RecordOrigin));
        IO.canonical(od.worker, raw, abi.encode(item, original));
    }

    function scopedPolicyContentItem(
        S.Dependencies memory d,
        O.Dependencies memory od,
        ScopedPolicy.Context memory c,
        address actor,
        uint64 observedAt,
        Root.Aggregate memory aggregate,
        bytes32 legacyFamily,
        bytes32 contextHash,
        O.ReceiptWitness memory witness
    ) public view returns (T.Item memory item, O.RecordOrigin memory original) {
        Calls.pin(od);
        bytes memory raw = IO.read(
            od.worker,
            abi.encodeCall(
                Reads.scopedPolicyContentItem,
                (d, c, actor, observedAt, aggregate, legacyFamily, contextHash, witness)
            ),
            16384,
            od.originGas
        );
        (item, original) = abi.decode(raw, (T.Item, O.RecordOrigin));
        IO.canonical(od.worker, raw, abi.encode(item, original));
    }
}
