// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as View
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as Reference
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import {
    IStreamCollectionViews as Declaration
} from "../../interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamPreservationRecords as Records
} from "../../interfaces/stream/preservation/IStreamPreservationRecords.sol";
import { StreamViewPayloadBytes as Bytes } from "../metadata/StreamViewPayloadBytes.sol";
import { StreamViewPayloadV2 as Payload } from "../metadata/StreamViewPayloadV2.sol";
import {
    StreamViewPreservationMediaCorrespondenceV1 as Media
} from "./StreamViewPreservationMediaCorrespondenceV1.sol";
import {
    StreamViewPreservationRenderCriticalSourceReadsV1 as Sources
} from "./StreamViewPreservationRenderCriticalSourceReadsV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";

import {
    StreamViewPreservationRenderCriticalRetainedReadsV1 as Retained
} from "./StreamViewPreservationRenderCriticalRetainedReadsV1.sol";

import {
    StreamViewRetrievalWitnessTypesV1 as Retrieval
} from "../../interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamViewRetrievalObligationV1 as RetrievalObligation
} from "./StreamViewRetrievalObligationV1.sol";

/// @notice The complete actually adopted declaration, immutable payload, script and image obligation.
/// @dev Called after the host's current source proof; the retained source is independently rehashed.
library StreamViewPreservationRenderCriticalArtworkReadsV1 {
    function items(S.Dependencies memory d, View.Context memory c)
        public
        view
        returns (T.Item[] memory rows)
    {
        Reference.SourceFacts memory f = Retained.sourceFacts(d, c);
        V.Record memory adopted = f.snapshotSource.adoption.adoption;
        address host = adopted.source.route.binding.views;
        IO.pin(host, adopted.source.route.binding.viewsCodeHash);
        bytes32 key = adopted.input.viewRecordHash;
        bytes memory encoded =
            IO.read(host, abi.encodeCall(Declaration.viewRecord, (key)), 16384, d.sourceGas);
        (
            Declaration.CollectionViewManifest memory declaration,
            Declaration.ViewReceipt memory receipt,
            Records.CollectionRecord memory record
        ) = abi.decode(
            encoded,
            (Declaration.CollectionViewManifest, Declaration.ViewReceipt, Records.CollectionRecord)
        );
        IO.canonical(host, encoded, abi.encode(declaration, receipt, record));
        if (
            keccak256(abi.encode(receipt)) != adopted.source.viewReceiptHash
                || receipt.collectionId != c.scope.collectionId || receipt.viewId != c.viewId
                || declaration.viewId != c.viewId || declaration.contentHash != c.payloadHash
                || declaration.schemaId != Payload.SCHEMA_ID
        ) revert T.InventorySourceChanged();
        bytes memory payload = Bytes.read(adopted.source);
        V.Payload memory p = Payload.decode(payload);
        if (keccak256(payload) != c.payloadHash) revert T.InventorySourceChanged();
        bytes memory manifest = abi.encode(
            c.scope.collectionId, receipt.revision, receipt.previousRecordHash, declaration
        );
        if (keccak256(manifest) != adopted.source.manifestPayloadHash) {
            revert T.InventorySourceChanged();
        }
        rows = new T.Item[](7);
        rows[0] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_VIEW_DECLARATION_RECORD"),
            host,
            key,
            0,
            encoded
        );
        rows[1] = Items.bytesItem(
            T.Kind.ORIGINAL_PAYLOAD,
            keccak256("ORIGINAL_VIEW_DECLARATION_MANIFEST"),
            host,
            key,
            0,
            manifest
        );
        rows[2] = Items.bytesItem(
            T.Kind.ORIGINAL_PAYLOAD,
            keccak256("COMPLETE_ADOPTED_VIEW_PAYLOAD"),
            host,
            key,
            0,
            payload
        );
        rows[2].schemaId = Payload.SCHEMA_ID;
        rows[3] = Items.bytesItem(
            T.Kind.NATIVE_BYTES, keccak256("COMPLETE_ADOPTED_VIEW_SCRIPT"), host, key, 0, p.script
        );
        rows[4] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("EXACT_ADOPTED_VIEW_IMAGE_URI"),
            host,
            key,
            0,
            bytes(p.imageURI)
        );
        Retrieval.Source memory retrieval = Retrieval.Source(
            c.scope,
            adopted.source.route.core,
            adopted.source.route.router,
            adopted.recordHash,
            adopted.sourceHash,
            host,
            key,
            adopted.source.payloadHash,
            f.snapshotSource.adoption.contextHash,
            p.imageURI,
            f.snapshotSource.artist.artistId,
            keccak256(abi.encode(f.snapshotSource.artist))
        );
        rows[5] = RetrievalObligation.item(retrieval);
        // The admitted V2 payload grammar has no library bundle or external animation field.
        rows[6] = Items.absent(keccak256("VIEW_EXTERNAL_LIBRARY_BUNDLE"), host, key, 0);
    }
}
