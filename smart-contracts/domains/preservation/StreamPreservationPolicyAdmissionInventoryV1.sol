// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationRegistryV1 as Registry
} from "../../interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    StreamPreservationPolicyOutputBindingV1 as Binding
} from "../finality/StreamPreservationPolicyOutputBindingV1.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";

/// @notice Complete independently admitted preservation producer declaration and source inventory.
/// @dev The host authenticates selection/output against its complete current checkpoint first.
/// This additional stage does not replace original renderer, terminal, citation or artwork stages.
library StreamPreservationPolicyAdmissionInventoryV1 {
    struct Original {
        bytes32 key;
        Registry.PreservationRecord record;
        V.Read[] reads;
        V.Target[] targets;
    }

    function item(
        S.Dependencies memory d,
        Selection.TokenSelection memory selected,
        Content.Output memory output,
        uint64 index
    ) public view returns (T.Item memory row, uint64 count) {
        return _item(d, selected, output, index, Family.ORIGINAL_PROFILE);
    }

    /// @dev The host supplied this complete Plan from its authenticated stored Context;
    /// TokenReads has rebound it to the actual pinned checkpoint before this call.
    function itemForPlan(
        S.Dependencies memory d,
        Content.Plan memory plan,
        Selection.TokenSelection memory selected,
        Content.Output memory output,
        uint64 index
    ) public view returns (T.Item memory row, uint64 count) {
        if (
            plan.preservationProfile != Family.FAMILY_PROFILE || plan.tokenCount == 0
                || plan.nextIndex != plan.tokenCount || plan.contentRoot == 0
                || plan.outputRoot == 0 || selected.tokenId != output.leaf.tokenId
                || output.selectionRowHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                            d.chainId,
                            d.targets[0],
                            d.targets[4],
                            selected
                        )
                    )
        ) revert T.InventorySourceChanged();
        return _item(d, selected, output, index, plan.preservationProfile);
    }

    function _item(
        S.Dependencies memory d,
        Selection.TokenSelection memory selected,
        Content.Output memory output,
        uint64 index,
        bytes32 family
    ) private view returns (T.Item memory row, uint64 count) {
        Original memory o = _load(d, selected, output, family);
        count = uint64(10 + o.targets.length);
        if (index >= count) revert T.InvalidInventoryItem();
        address registry = selected.selection.registry;
        uint256 token = selected.tokenId;
        if (index == 0) {
            return (
                _bytes(
                    "PRESERVATION_PRODUCER_BINDING",
                    output.preservation.producer,
                    o.key,
                    token,
                    abi.encode(output.preservation)
                ),
                count
            );
        }
        if (index == 1) {
            return (
                _bytes(
                    "PRESERVATION_ADMISSION",
                    registry,
                    o.key,
                    token,
                    abi.encode(output.preservationAdmission)
                ),
                count
            );
        }
        if (index == 2) {
            return (
                _bytes("PRESERVATION_REGISTRATION", registry, o.key, token, abi.encode(o.record)),
                count
            );
        }
        if (index == 3) {
            return (
                _bytes("PRESERVATION_DECLARED_READS", registry, o.key, token, abi.encode(o.reads)),
                count
            );
        }
        if (index == 4) {
            return (
                _bytes(
                    "PRESERVATION_COMPLETE_TARGETS", registry, o.key, token, abi.encode(o.targets)
                ),
                count
            );
        }
        if (index == 5) {
            return (
                Items.runtime(
                    keccak256("PRESERVATION_PRODUCER_RUNTIME"),
                    output.preservation.producer,
                    o.key,
                    token
                ),
                count
            );
        }
        if (index == 6) {
            return (
                Items.runtime(
                    keccak256("PRESERVATION_ATTRIBUTION_RUNTIME"),
                    output.preservation.attribution,
                    o.key,
                    token
                ),
                count
            );
        }
        if (index == 7) return (Documents.item(d, o.record.registration.schemaDocument, 0), count);
        if (index == 8) {
            return (
                Documents.item(d, o.record.registration.analysisDocument, o.record.analysisHash),
                count
            );
        }
        if (index == 9) {
            return
                (
                    Documents.item(d, o.record.registration.goldenDocument, o.record.goldenHash),
                    count
                );
        }
        V.Target memory target = o.targets[index - 10];
        row = Items.runtime(target.role, target.target, o.key, index - 10);
        row.provenanceHash = keccak256(abi.encode(registry, o.key, target));
    }

    function _load(
        S.Dependencies memory d,
        Selection.TokenSelection memory selected,
        Content.Output memory output,
        bytes32 family
    ) private view returns (Original memory o) {
        address registry = selected.selection.registry;
        if (
            d.chainId != block.chainid || selected.tokenId == 0
                || output.leaf.tokenId != selected.tokenId
                || output.preservation.core != d.targets[0]
                || output.preservation.metadataRouter != d.targets[4]
                || !FamilyRead.allows(family, output.preservation.profile)
                || output.preservationAdmission.registry != registry
                || output.preservationAdmission.registryCodeHash
                    != selected.selection.registryCodeHash
                || output.preservationAdmission.versionKey != selected.selection.versionKey
        ) revert T.InventorySourceChanged();
        IO.pin(registry, selected.selection.registryCodeHash);
        Binding.requireCurrent(output.preservation, selected, d.readGas);
        if (
            IO.addressWord(registry, abi.encodeWithSignature("schemaRegistry()"), d.readGas)
                    != d.targets[2]
                || IO.word(registry, abi.encodeWithSignature("schemaRegistryCodeHash()"), d.readGas)
                    != d.codeHashes[2]
                || uint256(
                        IO.word(registry, abi.encodeWithSignature("deploymentChainId()"), d.readGas)
                    ) != d.chainId
        ) {
            revert T.InventorySourceChanged();
        }
        bytes memory raw = IO.fixedRead(
            registry,
            abi.encodeCall(
                Registry.requirePreservation,
                (
                    selected.selection.versionKey,
                    output.preservation.producer,
                    output.preservation.profile
                )
            ),
            512,
            d.sourceGas
        );
        IO.canonical(registry, raw, abi.encode(output.preservation, output.preservationAdmission));
        o.key = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_KEY_V1"),
                selected.selection.versionKey,
                output.preservation.producer,
                output.preservation.profile
            )
        );
        raw = IO.fixedRead(
            registry, abi.encodeCall(Registry.preservationRecord, (o.key)), 576, d.readGas
        );
        o.record = abi.decode(raw, (Registry.PreservationRecord));
        IO.canonical(registry, raw, abi.encode(o.record));
        if (
            o.record.registration.versionKey != selected.selection.versionKey
                || keccak256(abi.encode(o.record.registration.binding))
                    != keccak256(abi.encode(output.preservation)) || o.record.registrationHash == 0
                || o.record.registrationHash != output.preservationAdmission.registrationHash
                || o.record.readSetHash == 0
                || o.record.readSetHash != output.preservationAdmission.readSetHash
                || o.record.analysisHash == 0
                || o.record.analysisHash != output.preservationAdmission.analysisHash
                || o.record.goldenHash == 0
                || o.record.goldenHash != output.preservationAdmission.goldenHash
                || o.record.actionId == 0
        ) revert T.InventorySourceChanged();
        raw = IO.read(
            registry, abi.encodeCall(Registry.preservationReads, (o.key)), 16448, d.readGas
        );
        o.reads = abi.decode(raw, (V.Read[]));
        IO.canonical(registry, raw, abi.encode(o.reads));
        uint256 n = uint256(IO.word(registry, abi.encodeCall(V.targetCount, ()), d.readGas));
        if (n == 0 || n > 64 || o.reads.length == 0 || o.reads.length > 128) {
            revert T.InvalidInventoryItem();
        }
        o.targets = new V.Target[](n);
        for (uint256 i; i < n; ++i) {
            raw = IO.fixedRead(registry, abi.encodeCall(V.targetAt, (i)), 96, d.readGas);
            o.targets[i] = abi.decode(raw, (V.Target));
            IO.canonical(registry, raw, abi.encode(o.targets[i]));
            if (i != 0 && o.targets[i].target <= o.targets[i - 1].target) {
                revert T.InvalidInventoryItem();
            }
            IO.pin(o.targets[i].target, o.targets[i].codeHash);
        }
        uint256 previous;
        for (uint256 i; i < o.reads.length; ++i) {
            V.Read memory r = o.reads[i];
            uint256 order = (uint256(r.targetIndex) << 32) | uint32(r.selector);
            if (
                r.targetIndex >= n || r.selector == 0 || (i != 0 && order <= previous)
                    || r.maxReturnBytes == 0 || r.maxReturnBytes > 16777216
                    || (r.exact && r.maxReturnBytes % 32 != 0)
            ) revert T.InvalidInventoryItem();
            previous = order;
        }
        bytes32 targetsHash = keccak256(abi.encode(o.targets));
        if (
            targetsHash != IO.word(registry, abi.encodeWithSignature("targetSetHash()"), d.readGas)
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDERER_READ_SET_V1"), targetsHash, o.reads
                        )
                    ) != o.record.readSetHash
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PRESERVATION_REGISTRATION_V1"),
                            d.chainId,
                            registry,
                            d.targets[2],
                            d.codeHashes[2],
                            targetsHash,
                            selected.selection.registrationHash,
                            o.record.registration,
                            o.reads
                        )
                    ) != o.record.registrationHash
        ) revert T.InventorySourceChanged();
    }

    function _bytes(
        string memory role,
        address source,
        bytes32 record,
        uint256 token,
        bytes memory value
    ) private pure returns (T.Item memory) {
        return Items.bytesItem(
            T.Kind.NATIVE_BYTES, keccak256(bytes(role)), source, record, token, value
        );
    }
}
