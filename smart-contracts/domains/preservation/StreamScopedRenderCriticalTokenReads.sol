// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamScopedSnapshotTypes as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedRenderCriticalSourceReads as Sources
} from "./StreamScopedRenderCriticalSourceReads.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamStaticContentCheckpoint as Content
} from "../../interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamStaticMetadataRouter as Router
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamMetadataFullViews as Full
} from "../../interfaces/stream/metadata/IStreamMetadataFullViews.sol";
import { IStreamCoreIdentity as Core } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamCoreMint } from "../../interfaces/stream/core/IStreamCoreMint.sol";
import {
    IStreamStaticEntropySource as Entropy
} from "../../interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import { IStreamRenderer as Renderer } from "../../interfaces/stream/metadata/IStreamRenderer.sol";

/// @notice Exact full output and original source rows for each authoritative scope ordinal.
/// @dev This finite output segment is not a complete script/dependency/definition inventory.
/// The host must require the full current source context before appending and before sealing.
/// This profile shares the scoped reference bounds: JSON 65,536, HTML 40,960 and image
/// 2,048 bytes. Larger Renderer outputs need a separately measured segmented profile.
library StreamScopedRenderCriticalTokenReads {
    struct Original {
        Selection.TokenSelection selection;
        Content.Output output;
        bytes identity;
        bytes entropy;
        bytes config;
        bytes source;
    }

    /// @dev Authenticated source coordinate shared by the finite per-token inventory workers.
    function sourceAt(S.Dependencies memory d, Scoped.Context memory c, uint64 index)
        public
        view
        returns (uint256 token, Original memory original)
    {
        Snapshot.Dependencies memory sd = Sources.snapshotBindings(d);
        if (index >= c.tokenCount) revert T.InvalidInventoryItem();
        token = uint256(
            IO.word(
                sd.targets[5], abi.encodeCall(Membership.scopeTokenAt, (c.scope, index)), d.readGas
            )
        );
        if (token == 0) revert T.InvalidInventoryItem();
        original = _original(d, c, sd, index, token);
    }

    function tokenItems(
        S.Dependencies memory d,
        Scoped.Context memory c,
        uint64 index,
        Content.Payload memory supplied
    ) public view returns (T.Item[] memory rows) {
        Snapshot.Dependencies memory sd = Sources.snapshotBindings(d);
        if (
            index >= c.tokenCount || supplied.tokenId == 0
                || supplied.tokenId
                    != uint256(
                        IO.word(
                            sd.targets[5],
                            abi.encodeCall(Membership.scopeTokenAt, (c.scope, index)),
                            d.readGas
                        )
                    )
        ) revert T.InvalidInventoryItem();
        Original memory o = _original(d, c, sd, index, supplied.tokenId);
        bytes memory data = _bytes(
            d.targets[0],
            abi.encodeCall(IStreamCoreMint.tokenData, (supplied.tokenId)),
            16384,
            d.sourceGas
        );
        // Match the exact producer selectors. Compact/historical JSON cannot fill a full-output leaf.
        bytes memory json = _bytes(
            d.targets[4], abi.encodeCall(Full.tokenJSON, (supplied.tokenId)), 65536, d.sourceGas
        );
        bytes memory html = _bytes(
            d.targets[4], abi.encodeCall(Full.tokenHTML, (supplied.tokenId)), 40960, d.sourceGas
        );
        if (
            keccak256(data) != o.output.leaf.tokenDataHash || json.length == 0
                || keccak256(json) != o.output.leaf.metadataHash || html.length == 0
                || keccak256(html) != o.output.leaf.animationHash
                || o.output.htmlHash != keccak256(html)
                || keccak256(supplied.animation) != keccak256(html) || supplied.image.length > 2048
                || o.output.leaf.contentHash != 0
                || (supplied.image.length == 0
                        ? o.output.leaf.imageHash != 0
                        : keccak256(supplied.image) != o.output.leaf.imageHash)
        ) {
            revert T.InvalidInventoryItem();
        }
        rows = new T.Item[](10);
        bytes32 record = c.checkpointHash;
        uint256 token = supplied.tokenId;
        rows[0] = Items.bytesItem(
            T.Kind.NATIVE_BYTES, keccak256("TOKEN_DATA"), d.targets[0], record, token, data
        );
        rows[1] = Items.bytesItem(
            T.Kind.NATIVE_BYTES, keccak256("TOKEN_METADATA_JSON"), d.targets[4], record, token, json
        );
        rows[2] = supplied.image.length == 0
            ? Items.absent(keccak256("TOKEN_IMAGE"), d.targets[4], record, token)
            : Items.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("TOKEN_IMAGE"),
                d.targets[4],
                record,
                token,
                supplied.image
            );
        rows[3] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("TOKEN_ANIMATION_HTML"),
            d.targets[4],
            record,
            token,
            html
        );
        rows[4] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_TOKEN_IDENTITY_LIFECYCLE"),
            d.targets[0],
            record,
            token,
            o.identity
        );
        rows[5] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_TOKEN_ENTROPY"),
            o.selection.sources[3],
            record,
            token,
            o.entropy
        );
        rows[6] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("STATIC_SELECTION_ROW"),
            sd.targets[6],
            c.selectionId,
            index,
            abi.encode(o.selection)
        );
        rows[7] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("STATIC_OUTPUT_ROW"),
            sd.targets[7],
            record,
            index,
            abi.encode(o.output)
        );
        rows[8] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_STATIC_CONFIG"),
            d.targets[4],
            o.selection.configRecordHash,
            token,
            o.config
        );
        rows[9] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_STATIC_RAW_SOURCE"),
            d.targets[4],
            o.selection.configRecordHash,
            token,
            o.source
        );
    }

    function _original(
        S.Dependencies memory d,
        Scoped.Context memory c,
        Snapshot.Dependencies memory sd,
        uint64 index,
        uint256 token
    ) private view returns (Original memory o) {
        bytes memory raw = IO.fixedRead(
            sd.targets[6],
            abi.encodeCall(Selection.selectionAt, (c.selectionId, index)),
            896,
            d.readGas
        );
        o.selection = abi.decode(raw, (Selection.TokenSelection));
        IO.canonical(sd.targets[6], raw, abi.encode(o.selection));
        raw = IO.fixedRead(
            sd.targets[7],
            abi.encodeCall(Content.outputAt, (c.checkpointHash, index)),
            288,
            d.readGas
        );
        o.output = abi.decode(raw, (Content.Output));
        IO.canonical(sd.targets[7], raw, abi.encode(o.output));
        if (
            o.selection.tokenId != token || o.output.leaf.tokenId != token
                || o.output.selectionRowHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                            d.chainId,
                            d.targets[0],
                            d.targets[4],
                            o.selection
                        )
                    )
        ) revert T.InvalidInventoryItem();
        raw = IO.fixedRead(
            d.targets[0], abi.encodeCall(Core.tokenCollectionIdentity, (token)), 128, d.readGas
        );
        (bool exists, uint256 cid, uint256 serial, bool burned) =
            abi.decode(raw, (bool, uint256, uint256, bool));
        IO.canonical(d.targets[0], raw, abi.encode(exists, cid, serial, burned));
        uint256 lifecycle =
            uint256(IO.word(d.targets[0], abi.encodeCall(Core.tokenLifecycle, (token)), d.readGas));
        if (!exists || cid != c.scope.collectionId || serial == 0 || lifecycle != (burned ? 3 : 2))
        {
            revert T.InvalidInventoryItem();
        }
        // The permanent serial comes from Core; an ordinal is never converted to serial+1.
        o.identity = abi.encode(token, cid, serial, burned, uint8(lifecycle), index);
        address coordinator = IO.addressWord(
            d.targets[0], abi.encodeCall(Core.coordinatorAtMint, (token)), d.readGas
        );
        if (coordinator != o.selection.sources[3]) revert T.InventorySourceChanged();
        IO.pin(coordinator, o.selection.sourceCodeHashes[3]);
        o.entropy = IO.fixedRead(
            coordinator, abi.encodeCall(Entropy.staticTokenRenderFacts, (token)), 96, d.sourceGas
        );
        (uint8 status, bytes32 seed, address provider) =
            abi.decode(o.entropy, (uint8, bytes32, address));
        IO.canonical(coordinator, o.entropy, abi.encode(status, seed, provider));
        if (
            status != 5
                || o.output.sourceFactsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_STATIC_CURRENT_FULL_CONTENT_V1"),
                            o.selection.configHash,
                            o.selection.rawSourceHash,
                            coordinator,
                            o.entropy
                        )
                    )
        ) revert T.InvalidInventoryItem();
        o.config = IO.read(
            d.targets[4],
            abi.encodeCall(Router.metadataConfigRecord, (o.selection.configRecordHash)),
            8192,
            d.sourceGas
        );
        Router.ConfigRecord memory config = abi.decode(o.config, (Router.ConfigRecord));
        IO.canonical(d.targets[4], o.config, abi.encode(config));
        if (
            keccak256(o.config) != o.selection.configHash
                || config.recordHash != o.selection.configRecordHash || config.collectionId != cid
                || (config.tokenId != 0 && config.tokenId != token) || !config.config.frozen
                || config.sourceSnapshotHash != o.selection.sourceSnapshotHash
                || keccak256(abi.encode(config.selection))
                    != keccak256(abi.encode(o.selection.selection))
        ) revert T.InvalidInventoryItem();
        config.recordHash = 0;
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1"),
                        d.targets[0],
                        d.targets[4],
                        config
                    )
                ) != o.selection.configRecordHash
        ) revert T.InvalidInventoryItem();
        o.source = IO.read(
            d.targets[4],
            abi.encodeCall(Router.staticRenderSourceForConfig, (cid, o.selection.configRecordHash)),
            24000,
            d.sourceGas
        );
        (Router.RawSource memory source, Renderer.MetadataConfig memory cfg) =
            abi.decode(o.source, (Router.RawSource, Renderer.MetadataConfig));
        IO.canonical(d.targets[4], o.source, abi.encode(source, cfg));
        if (
            !source.configured || source.chainId != d.chainId
                || keccak256(abi.encode(cfg)) != keccak256(abi.encode(config.config))
                || keccak256(abi.encode(source)) != o.selection.rawSourceHash
                || keccak256(abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), source))
                    != o.selection.sourceSnapshotHash
        ) {
            revert T.InvalidInventoryItem();
        }
    }

    function _bytes(address target, bytes memory input, uint256 maximum, uint256 cap)
        private
        view
        returns (bytes memory value)
    {
        bytes memory raw = IO.read(target, input, maximum + 64, cap);
        value = abi.decode(raw, (bytes));
        IO.canonical(target, raw, abi.encode(value));
        if (value.length > maximum) revert T.InventoryRead(target);
    }
}
