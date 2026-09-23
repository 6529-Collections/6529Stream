// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistRecordPublicationTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamArtistArchiveOriginReads as Reads
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginReads.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";

/// @dev One constructor-pinned, finite, canonical fixed reader. Callers cannot select a target.
library StreamMultiOriginInventoryCalls {
    function pin(O.Dependencies memory d) internal view {
        if (d.profile != O.PROFILE || d.originGas < 50000 || d.originGas > type(uint64).max) {
            revert O.InvalidArchiveOrigin();
        }
        IO.pin(d.worker, d.workerCodeHash);
    }

    function lineage(
        S.Dependencies memory d,
        O.Dependencies memory od,
        uint256 cid,
        IStreamMetadataServingFacts.ArtistPresentation memory presented,
        IStreamConservationRecordSelection.Association memory association
    ) public view returns (O.Origin memory current, O.Origin memory original, bytes32 lineageHash) {
        pin(od);
        bytes memory raw = IO.fixedRead(
            od.worker,
            abi.encodeCall(Reads.lineage, (d, cid, presented, association)),
            1568,
            od.originGas
        );
        (current, original, lineageHash) = abi.decode(raw, (O.Origin, O.Origin, bytes32));
        IO.canonical(od.worker, raw, abi.encode(current, original, lineageHash));
        if (lineageHash == 0) revert O.InvalidArchiveOrigin();
    }

    function publication(
        S.Dependencies memory d,
        O.Dependencies memory od,
        P.Evidence memory expected,
        bytes32 record,
        address actor,
        bytes32 contextHash,
        O.ReceiptWitness memory witness
    ) public view returns (T.Item memory item, O.RecordOrigin memory original) {
        pin(od);
        bytes memory raw = IO.read(
            od.worker,
            abi.encodeCall(
                Reads.publicationItem, (d, expected, record, actor, contextHash, witness)
            ),
            16384,
            od.originGas
        );
        (item, original) = abi.decode(raw, (T.Item, O.RecordOrigin));
        IO.canonical(od.worker, raw, abi.encode(item, original));
    }

    function content(
        S.Dependencies memory d,
        O.Dependencies memory od,
        S.Context memory c,
        address actor,
        uint64 observedAt,
        bytes32 contextHash,
        O.ReceiptWitness memory witness
    ) public view returns (T.Item memory item, O.RecordOrigin memory original) {
        pin(od);
        bytes memory raw = IO.read(
            od.worker,
            abi.encodeCall(Reads.contentItem, (d, c, actor, observedAt, contextHash, witness)),
            16384,
            od.originGas
        );
        (item, original) = abi.decode(raw, (T.Item, O.RecordOrigin));
        IO.canonical(od.worker, raw, abi.encode(item, original));
    }
}
