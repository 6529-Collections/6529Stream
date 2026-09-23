// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as View
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as R
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import { IStreamCoreMint as Mint } from "../../interfaces/stream/core/IStreamCoreMint.sol";
import {
    StreamViewPreservationCheckpointTokenV1 as Tokens
} from "../finality/StreamViewPreservationCheckpointTokenV1.sol";
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

/// @notice Actual ordered identity and complete JSON/HTML bytes for every VIEW member.
/// @dev The host authenticates current full context before this fixed projection. No samples replace rows.
library StreamViewPreservationRenderCriticalTokenReadsV1 {
    struct Original {
        C.Configuration config;
        C.Source source;
        C.Output output;
        bytes json;
        bytes html;
        bytes tokenData;
    }

    function sourceAt(S.Dependencies memory d, View.Context memory c, uint64 index)
        public
        view
        returns (Original memory o)
    {
        if (index >= c.tokenCount) revert T.InvalidInventoryItem();
        Snapshot.Dependencies memory sd = Sources.snapshotBindings(d);
        R.SourceFacts memory f = Retained.sourceFacts(d, c);
        o.source = f.snapshotSource.adoption;
        bytes memory raw = IO.fixedRead(
            sd.targets[6], abi.encodeCall(Checkpoint.configuration, ()), 384, d.readGas
        );
        o.config = abi.decode(raw, (C.Configuration));
        IO.canonical(sd.targets[6], raw, abi.encode(o.config));
        if (
            o.config.core != d.targets[0] || o.config.coreCodeHash != d.codeHashes[0]
                || o.config.router != d.targets[4] || o.config.routerCodeHash != d.codeHashes[4]
                || o.config.chainId != d.chainId || o.source.contextHash != c.sourceContextHash
                || o.source.adoption.recordHash != c.adoptionRecord
                || keccak256(abi.encode(o.source.adoption.input.scope))
                    != keccak256(abi.encode(c.scope))
        ) revert T.InventorySourceChanged();
        raw = IO.fixedRead(
            sd.targets[6],
            abi.encodeCall(Checkpoint.outputAt, (c.checkpointHash, index)),
            992,
            d.readGas
        );
        C.Output memory saved = abi.decode(raw, (C.Output));
        IO.canonical(sd.targets[6], raw, abi.encode(saved));
        (o.output, o.json, o.html) = Tokens.observe(o.config, o.source, index);
        if (
            keccak256(abi.encode(o.output)) != keccak256(abi.encode(saved)) || saved.index != index
                || saved.jsonHash != keccak256(o.json) || saved.htmlHash != keccak256(o.html)
                || saved.jsonBytes != o.json.length || saved.htmlBytes != o.html.length
        ) revert T.InventorySourceChanged();
        raw = IO.read(
            d.targets[0], abi.encodeCall(Mint.tokenData, (saved.tokenId)), 16480, d.readGas
        );
        o.tokenData = abi.decode(raw, (bytes));
        IO.canonical(d.targets[0], raw, abi.encode(o.tokenData));
        if (o.tokenData.length > 16384 || keccak256(o.tokenData) != saved.tokenDataHash) {
            revert T.InventorySourceChanged();
        }
    }

    function items(S.Dependencies memory d, View.Context memory c, uint64 index)
        public
        view
        returns (T.Item[] memory rows)
    {
        Original memory o = sourceAt(d, c, index);
        uint256 token = o.output.tokenId;
        rows = new T.Item[](6);
        rows[0] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("VIEW_MEMBER_PERMANENT_IDENTITY"),
            d.targets[0],
            c.adoptionRecord,
            index,
            abi.encode(
                token,
                c.scope.collectionId,
                o.output.collectionSerial,
                o.output.burned,
                o.output.lifecycle,
                index
            )
        );
        rows[1] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("VIEW_TOKEN_DATA"),
            d.targets[0],
            c.adoptionRecord,
            token,
            o.tokenData
        );
        rows[2] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("VIEW_FULL_POLICY_OUTPUT_ROW"),
            o.config.serving,
            c.checkpointHash,
            index,
            abi.encode(o.output)
        );
        rows[3] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("VIEW_FULL_PRESERVATION_JSON"),
            o.config.serving,
            c.adoptionRecord,
            token,
            o.json
        );
        rows[4] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("VIEW_FULL_PRESERVATION_HTML"),
            o.config.serving,
            c.adoptionRecord,
            token,
            o.html
        );
        rows[5] = Items.runtime(
            keccak256("VIEW_ORIGINAL_AT_MINT_COORDINATOR"),
            o.output.entropy.coordinator,
            c.adoptionRecord,
            token
        );
    }
}
