// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyTokenOriginalReadsV1 as OriginalReads
} from "./StreamPreservationPolicyTokenOriginalReadsV1.sol";
import {
    StreamPreservationPolicyInventoryFamilyV2 as FamilyRead
} from "./StreamPreservationPolicyInventoryFamilyV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "./StreamPreservationPolicyRenderCriticalSourceReadsV1.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamStaticMetadataRouter as Router
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamPreservationRegistryV1 as Registry
} from "../../interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    StreamPreservationPolicyOutputBindingV1 as Binding
} from "../finality/StreamPreservationPolicyOutputBindingV1.sol";
import { IStreamCoreIdentity as Core } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import { IStreamCoreMint } from "../../interfaces/stream/core/IStreamCoreMint.sol";
import {
    IStreamStaticEntropySource as Entropy
} from "../../interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import { IStreamRenderer as Renderer } from "../../interfaces/stream/metadata/IStreamRenderer.sol";

import {
    IStreamFinalityEntropyPolicySourceSet as Policy
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamTerminalEntropyReadiness as Terminal
} from "../../interfaces/stream/finality/IStreamTerminalEntropyReadiness.sol";
import { StreamPolicyContentBytesV2 } from "../finality/StreamPolicyContentBytesV2.sol";
import { StreamOnchainContentBytes } from "../finality/StreamOnchainContentBytes.sol";

/// @notice Exact preservation output and original source rows for each authoritative scope ordinal.
/// @dev This finite output segment is not a complete script/dependency/definition inventory.
/// The host must require the full current source context before appending and before sealing.
/// This profile shares the scoped reference bounds: JSON 65,536, HTML 40,960 and image
/// 2,048 bytes. Larger Renderer outputs need a separately measured segmented profile.
library StreamPreservationPolicyRenderCriticalTokenReadsV1 {
    // Keep the original error ABI for failures propagated by the fixed linked worker.
    error InvalidPreservationBinding();
    error InventorySourceChanged();
    error PreservationDependencyChanged(address target);
    error PreservationParentGas(uint256 available, uint256 required);
    error PreservationReadFailed(address target, bytes4 selector);

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
        (Snapshot.Dependencies memory sd,) = Sources.bindings(d);
        if (index >= c.records.tokenCount) revert T.InvalidInventoryItem();
        token = uint256(
            IO.word(
                sd.targets[5],
                abi.encodeCall(Membership.scopeTokenAt, (c.source.scope, index)),
                d.readGas
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
        (Snapshot.Dependencies memory sd,) = Sources.bindings(d);
        if (
            index >= c.records.tokenCount || supplied.tokenId == 0
                || supplied.tokenId
                    != uint256(
                        IO.word(
                            sd.targets[5],
                            abi.encodeCall(Membership.scopeTokenAt, (c.source.scope, index)),
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
        // Observe the saved independently admitted producer, not the live display projection.
        if (supplied.producer != o.output.preservation.producer) revert T.InvalidInventoryItem();
        bytes memory json = _bytes(
            o.output.preservation.producer,
            abi.encodeWithSignature("preservationTokenJSON(uint256)", supplied.tokenId),
            65536,
            d.sourceGas
        );
        bytes memory html = _bytes(
            o.output.preservation.producer,
            abi.encodeWithSignature("preservationTokenHTML(uint256)", supplied.tokenId),
            40960,
            d.sourceGas
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
        if (o.output.entropy.terminal
                ? !StreamPolicyContentBytesV2.matches(json, html, data)
                : !StreamOnchainContentBytes.matchesAnimation(json, html)) revert T.InvalidInventoryItem();
        rows = new T.Item[](10);
        bytes32 record = c.records.checkpointHash;
        uint256 token = supplied.tokenId;
        rows[0] = Items.bytesItem(
            T.Kind.NATIVE_BYTES, keccak256("TOKEN_DATA"), d.targets[0], record, token, data
        );
        rows[1] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("PRESERVATION_TOKEN_METADATA_JSON"),
            o.output.preservation.producer,
            record,
            token,
            json
        );
        rows[2] = supplied.image.length == 0
            ? Items.absent(
                keccak256("PRESERVATION_TOKEN_IMAGE"), o.output.preservation.producer, record, token
            )
            : Items.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("PRESERVATION_TOKEN_IMAGE"),
                o.output.preservation.producer,
                record,
                token,
                supplied.image
            );
        rows[3] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("PRESERVATION_TOKEN_ANIMATION_HTML"),
            o.output.preservation.producer,
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
            c.source.content.selectionId,
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
        return OriginalReads.original(d, c, sd, index, token);
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
