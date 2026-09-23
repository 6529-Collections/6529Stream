// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewPreservationReferenceFixtureV1.sol";
import {
    StreamRenderCriticalSourceTypes as InventorySources
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as InventoryView
} from "../../../smart-contracts/interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as InventoryTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamViewPreservationRenderCriticalTokenReadsV1 as InventoryTokens
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalTokenReadsV1.sol";
import {
    StreamViewPreservationRenderCriticalArtworkReadsV1 as InventoryArtwork
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalArtworkReadsV1.sol";
import {
    IStreamCollectionViews as OriginalViews
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamPreservationRecords as OriginalRecords
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";

import {
    StreamViewPreservationRenderCriticalNativeReadsV1 as InventoryNative
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalNativeReadsV1.sol";
import {
    StreamViewPreservationReferenceInventoryReadsV1 as InventoryReference
} from "../../../smart-contracts/domains/preservation/StreamViewPreservationReferenceInventoryReadsV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as SnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import {
    StreamViewPreservationReferenceDefinitionsV1 as ReferenceDefinitions
} from "../../../smart-contracts/domains/records/StreamViewPreservationReferenceDefinitionsV1.sol";

contract ViewInventoryOutputProbe {
    function nativePayload(InventorySources.Dependencies memory d, InventoryView.Context memory c)
        external
        view
        returns (InventoryTypes.Item memory row)
    {
        (InventoryTypes.Item[] memory rows,) = InventoryNative.items(d, c, 1, 1);
        return rows[0];
    }

    function referencePayload(
        InventorySources.Dependencies memory d,
        InventoryView.Context memory c
    ) external view returns (InventoryTypes.Item memory row) {
        (InventoryTypes.Item[] memory rows,) = InventoryReference.items(d, c, 0, 1);
        return rows[0];
    }

    function source(
        InventorySources.Dependencies memory d,
        InventoryView.Context memory c,
        uint64 index
    ) external view returns (InventoryTokens.Original memory) {
        return InventoryTokens.sourceAt(d, c, index);
    }

    function tokens(
        InventorySources.Dependencies memory d,
        InventoryView.Context memory c,
        uint64 index
    ) external view returns (InventoryTypes.Item[] memory) {
        return InventoryTokens.items(d, c, index);
    }

    function artwork(InventorySources.Dependencies memory d, InventoryView.Context memory c)
        external
        view
        returns (InventoryTypes.Item[] memory)
    {
        return InventoryArtwork.items(d, c);
    }
}

/// @notice Actual Reference/Snapshot/checkpoint/Store/Renderer bytes, with original fixture's typed
/// governance, Router root and archive boundaries. This isolates fixed inventory projection;
/// host-stage authorization, complete inventory sealing and actual op17 remain separate.
contract StreamViewPreservationInventoryOutputsV1Test is ViewPreservationReferenceFixtureV1 {
    InventorySources.Dependencies private inventoryDeps;
    InventoryView.Context private inventoryContext;
    ViewInventoryOutputProbe private inventoryProbe;
    bytes32 private referenceHash;

    function _inventoryInit() private {
        _referenceInit();
        referenceHash = _publishReference();
        Ref.SourceFacts memory f = referenceHost.referenceSource(referenceHash);
        (, Ref.Receipt memory receipt) = referenceHost.referenceRecord(referenceHash);
        referenceHost.requireCurrent(scope, referenceHash, receipt.observation.revision);
        uint256[7] memory positions = [uint256(0), 1, 2, 3, 4, 5, 11];
        Ref.Dependencies memory rd = referenceHost.dependencies();
        for (uint256 i; i < 7; ++i) {
            inventoryDeps.targets[positions[i]] = rd.targets[i];
            inventoryDeps.codeHashes[positions[i]] = rd.codeHashes[i];
        }
        inventoryDeps.targets[6] = address(referenceHost);
        inventoryDeps.codeHashes[6] = address(referenceHost).codehash;
        inventoryDeps.targets[10] = deps.targets[8];
        inventoryDeps.codeHashes[10] = deps.codeHashes[8];
        inventoryDeps.chainId = savedChain;
        inventoryDeps.readGas = 1000000;
        inventoryDeps.sourceGas = 16000000;
        inventoryDeps.referenceGas = 16000000;
        inventoryDeps.snapshotGas = 16000000;
        inventoryContext.scope = scope;
        inventoryContext.subject = f.scopeSubject;
        inventoryContext.snapshot = f.snapshot;
        inventoryContext.referenceRender = receipt;
        inventoryContext.nativeHash = keccak256(abi.encode(f.snapshotSource));
        inventoryContext.rootRecordHash = f.contentRootRecordHash;
        inventoryContext.checkpointHash = f.snapshotSource.outputs.header.checkpointId;
        inventoryContext.adoptionRecord = f.snapshotSource.adoption.adoption.recordHash;
        inventoryContext.sourceContextHash = f.snapshotSource.adoption.contextHash;
        inventoryContext.viewId = f.snapshotSource.adoption.adoption.input.viewId;
        inventoryContext.payloadHash = f.snapshotSource.adoption.adoption.source.payloadHash;
        inventoryContext.tokenCount = uint64(f.snapshotSource.membership.tokenCount);
        inventoryProbe = new ViewInventoryOutputProbe();
    }

    function _item(
        InventoryTypes.Item memory r,
        InventoryTypes.Kind kind,
        bytes32 role,
        address source,
        bytes32 record,
        uint256 index,
        bytes memory full
    ) private pure {
        require(
            r.kind == kind && r.role == role && r.source == source && r.sourceRecord == record
                && r.sourceIndex == index,
            "original source coordinates"
        );
        require(
            r.algorithm == 1 && r.canonicalizationId == keccak256("RAW_BYTES")
                && r.byteSize == full.length,
            "complete byte length/profile"
        );
        require(
            keccak256(r.digest) == keccak256(abi.encodePacked(keccak256(full))),
            "literal whole-byte commitment"
        );
        require(
            bytes(r.uri).length == 0 && r.objectHash == 0 && r.originalCoverageHash == 0,
            "projection is not archive evidence"
        );
    }

    function testEveryOrderedMemberItemCommitsLiteralFullOriginalBytes() public {
        _inventoryInit();
        InventoryTypes.Item[] memory rows =
            inventoryProbe.tokens(inventoryDeps, inventoryContext, 0);
        require(rows.length == 6, "all six original obligations");
        CT.Output memory saved = checkpointHost.outputAt(inventoryContext.checkpointHash, 0);
        (, string memory json) = serving.preservationViewJSON(scope, 11);
        (, string memory html) = serving.preservationViewHTML(scope, 11);
        require(
            saved.tokenId == 11 && saved.collectionSerial == 7 && saved.lifecycle == 2
                && !saved.burned,
            "actual identity distinct from ordinal"
        );
        _item(
            rows[0],
            InventoryTypes.Kind.NATIVE_BYTES,
            keccak256("VIEW_MEMBER_PERMANENT_IDENTITY"),
            address(core),
            adopted,
            0,
            abi.encode(uint256(11), uint256(1), uint256(7), false, uint8(2), uint64(0))
        );
        _item(
            rows[1],
            InventoryTypes.Kind.NATIVE_BYTES,
            keccak256("VIEW_TOKEN_DATA"),
            address(core),
            adopted,
            11,
            hex"00f1ff00"
        );
        _item(
            rows[2],
            InventoryTypes.Kind.NATIVE_BYTES,
            keccak256("VIEW_FULL_POLICY_OUTPUT_ROW"),
            address(serving),
            inventoryContext.checkpointHash,
            0,
            abi.encode(saved)
        );
        _item(
            rows[3],
            InventoryTypes.Kind.NATIVE_BYTES,
            keccak256("VIEW_FULL_PRESERVATION_JSON"),
            address(serving),
            adopted,
            11,
            bytes(json)
        );
        _item(
            rows[4],
            InventoryTypes.Kind.NATIVE_BYTES,
            keccak256("VIEW_FULL_PRESERVATION_HTML"),
            address(serving),
            adopted,
            11,
            bytes(html)
        );
        require(
            rows[3].byteSize > 32 && rows[4].byteSize > 32, "full outputs not their digest bytes"
        );
        require(
            rows[5].kind == InventoryTypes.Kind.CONTRACT_RUNTIME
                && rows[5].source == address(coordinator)
                && rows[5].byteSize == address(coordinator).code.length,
            "actual original-at-mint runtime"
        );
        require(
            keccak256(rows[5].digest) == keccak256(abi.encodePacked(address(coordinator).codehash)),
            "literal runtime hash"
        );
    }

    function testRetainedSourceAndFullScopeSubstitutionsRefuseThenRestore() public {
        _inventoryInit();
        bytes32 expected =
            keccak256(abi.encode(inventoryProbe.tokens(inventoryDeps, inventoryContext, 0)));
        for (uint256 i; i < 7; ++i) {
            InventoryView.Context memory c =
                abi.decode(abi.encode(inventoryContext), (InventoryView.Context));
            if (i == 0) c.nativeHash = keccak256("foreign source");
            if (i == 1) c.snapshot.revision += 1;
            if (i == 2) c.rootRecordHash = keccak256("foreign root");
            if (i == 3) c.subject = keccak256("foreign subject");
            if (i == 4) c.scope.scopeType = StreamFinalityScopeType.RELEASE;
            if (i == 5) c.adoptionRecord = keccak256("foreign adoption");
            if (i == 6) c.sourceContextHash = keccak256("foreign complete source");
            vm.expectRevert(abi.encodeWithSelector(InventoryTypes.InventorySourceChanged.selector));
            inventoryProbe.tokens(inventoryDeps, c, 0);
        }
        require(
            keccak256(abi.encode(inventoryProbe.tokens(inventoryDeps, inventoryContext, 0)))
                == expected,
            "same originals restore"
        );
    }

    function testCompleteTokenDataAndNonSanctionOutputDriftCannotReuseCheckpoint() public {
        _inventoryInit();
        bytes32 oldPayload = keccak256(referenceHost.referencePayload(referenceHash));
        bytes32 expected =
            keccak256(abi.encode(inventoryProbe.tokens(inventoryDeps, inventoryContext, 0)));
        _answer(core, "tokenData(uint256)", abi.encode(uint256(11)), abi.encode(hex"00f1ff01"));
        vm.expectRevert(abi.encodeWithSelector(InventoryTypes.InventorySourceChanged.selector));
        inventoryProbe.tokens(inventoryDeps, inventoryContext, 0);
        _answer(core, "tokenData(uint256)", abi.encode(uint256(11)), abi.encode(hex"00f1ff00"));
        (bool ok, bytes memory original) = address(preservation)
            .staticcall(
                abi.encodeWithSignature(
                    "preservationAttribution(uint256,uint256)", uint256(1), uint256(11)
                )
            );
        require(ok, "actual positive attribution");
        _answer(
            preservation,
            "preservationAttribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            abi.encode(bytes('{"changed":true}'))
        );
        vm.expectRevert(abi.encodeWithSelector(InventoryTypes.InventorySourceChanged.selector));
        inventoryProbe.tokens(inventoryDeps, inventoryContext, 0);
        _answer(
            preservation,
            "preservationAttribution(uint256,uint256)",
            abi.encode(uint256(1), uint256(11)),
            original
        );
        require(
            keccak256(abi.encode(inventoryProbe.tokens(inventoryDeps, inventoryContext, 0)))
                == expected,
            "identical retry"
        );
        require(
            keccak256(referenceHost.referencePayload(referenceHash)) == oldPayload,
            "historical bytes retained"
        );
    }

    function testOrdinalBoundsAndStoredFullRowSubstitutionRefuse() public {
        _inventoryInit();
        vm.expectRevert(abi.encodeWithSelector(InventoryTypes.InvalidInventoryItem.selector));
        inventoryProbe.tokens(inventoryDeps, inventoryContext, 1);
        CT.Output memory saved = checkpointHost.outputAt(inventoryContext.checkpointHash, 0);
        CT.Output memory wrong = abi.decode(abi.encode(saved), (CT.Output));
        wrong.collectionSerial += 1;
        bytes memory input = abi.encodeWithSignature(
            "outputAt(bytes32,uint64)", inventoryContext.checkpointHash, uint64(0)
        );
        ViewReferenceSnapshotVm(address(vm))
            .mockCall(address(checkpointHost), input, abi.encode(wrong));
        vm.expectRevert(abi.encodeWithSelector(InventoryTypes.InventorySourceChanged.selector));
        inventoryProbe.tokens(inventoryDeps, inventoryContext, 0);
        ViewReferenceSnapshotVm(address(vm))
            .mockCall(address(checkpointHost), input, abi.encode(saved));
        require(
            inventoryProbe.source(inventoryDeps, inventoryContext, 0).output.collectionSerial == 7,
            "exact stored row restore"
        );
    }

    function testArtworkUsesWholeAdoptedPayloadScriptAndExplicitAbsentMedia() public {
        _inventoryInit();
        InventoryTypes.Item[] memory rows = inventoryProbe.artwork(inventoryDeps, inventoryContext);
        Ref.SourceFacts memory f = referenceHost.referenceSource(referenceHash);
        bytes32 declaredRecord = f.snapshotSource.adoption.adoption.input.viewRecordHash;
        address declarationHost = f.snapshotSource.adoption.adoption.source.route.binding.views;
        (bool ok, bytes memory record) =
            declarationHost.staticcall(abi.encodeCall(OriginalViews.viewRecord, (declaredRecord)));
        require(ok, "actual declared view");
        (
            OriginalViews.CollectionViewManifest memory m,
            OriginalViews.ViewReceipt memory r,
            OriginalRecords.CollectionRecord memory original
        ) = abi.decode(
            record,
            (
                OriginalViews.CollectionViewManifest,
                OriginalViews.ViewReceipt,
                OriginalRecords.CollectionRecord
            )
        );
        original;
        bytes memory script = bytes("window.done=stream.entropy.terminal;");
        bytes memory payload =
            abi.encode(V.Payload(ViewPolicy.CONTEXT, "policy view", "full source", "", script));
        require(rows.length == 7 && m.contentHash == keccak256(payload), "exact original payload");
        _item(
            rows[0],
            InventoryTypes.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_VIEW_DECLARATION_RECORD"),
            declarationHost,
            declaredRecord,
            0,
            record
        );
        _item(
            rows[1],
            InventoryTypes.Kind.ORIGINAL_PAYLOAD,
            keccak256("ORIGINAL_VIEW_DECLARATION_MANIFEST"),
            declarationHost,
            declaredRecord,
            0,
            abi.encode(uint256(1), r.revision, r.previousRecordHash, m)
        );
        _item(
            rows[2],
            InventoryTypes.Kind.ORIGINAL_PAYLOAD,
            keccak256("COMPLETE_ADOPTED_VIEW_PAYLOAD"),
            declarationHost,
            declaredRecord,
            0,
            payload
        );
        _item(
            rows[3],
            InventoryTypes.Kind.NATIVE_BYTES,
            keccak256("COMPLETE_ADOPTED_VIEW_SCRIPT"),
            declarationHost,
            declaredRecord,
            0,
            script
        );
        _item(
            rows[4],
            InventoryTypes.Kind.EMPTY_BYTES,
            keccak256("EXACT_ADOPTED_VIEW_IMAGE_URI"),
            declarationHost,
            declaredRecord,
            0,
            bytes("")
        );
        require(
            rows[5].kind == InventoryTypes.Kind.ABSENT
                && rows[6].kind == InventoryTypes.Kind.ABSENT,
            "no invented media or library"
        );
    }

    function testArtworkCarrierCorruptionAndDeclarationReceiptRefuseThenRetry() public {
        _inventoryInit();
        bytes32 expected =
            keccak256(abi.encode(inventoryProbe.artwork(inventoryDeps, inventoryContext)));
        Ref.SourceFacts memory f = referenceHost.referenceSource(referenceHash);
        V.Source memory s = f.snapshotSource.adoption.adoption.source;
        bytes memory saved = s.payloadPointers[0].code;
        bytes memory wrong = bytes.concat(saved);
        wrong[wrong.length - 1] = bytes1(uint8(wrong[wrong.length - 1]) ^ 1);
        vm.etch(s.payloadPointers[0], wrong);
        vm.expectRevert();
        inventoryProbe.artwork(inventoryDeps, inventoryContext);
        vm.etch(s.payloadPointers[0], saved);
        address h = s.route.binding.views;
        bytes32 key = f.snapshotSource.adoption.adoption.input.viewRecordHash;
        (bool ok, bytes memory raw) = h.staticcall(abi.encodeCall(OriginalViews.viewRecord, (key)));
        require(ok, "positive declaration");
        (
            OriginalViews.CollectionViewManifest memory m,
            OriginalViews.ViewReceipt memory r,
            OriginalRecords.CollectionRecord memory record
        ) = abi.decode(
            raw,
            (
                OriginalViews.CollectionViewManifest,
                OriginalViews.ViewReceipt,
                OriginalRecords.CollectionRecord
            )
        );
        r.revision += 1;
        _answer(core, "viewRecord(bytes32)", abi.encode(key), abi.encode(m, r, record));
        vm.expectRevert(abi.encodeWithSelector(InventoryTypes.InventorySourceChanged.selector));
        inventoryProbe.artwork(inventoryDeps, inventoryContext);
        _answer(core, "viewRecord(bytes32)", abi.encode(key), raw);
        require(
            keccak256(abi.encode(inventoryProbe.artwork(inventoryDeps, inventoryContext)))
                == expected,
            "exact payload/declaration retry"
        );
    }

    function testOriginalPayloadCorrespondenceIsWholeRawBytesWithOriginalSchemaAndReceipt() public {
        _inventoryInit();
        InventoryTypes.Item memory snap =
            inventoryProbe.nativePayload(inventoryDeps, inventoryContext);
        InventoryTypes.Item memory ref =
            inventoryProbe.referencePayload(inventoryDeps, inventoryContext);
        bytes memory snapshotBytes = snapshots.snapshotPayload(inventoryContext.snapshot.recordHash);
        bytes memory referenceBytes = referenceHost.referencePayload(referenceHash);
        _item(
            snap,
            InventoryTypes.Kind.ORIGINAL_PAYLOAD,
            keccak256("VIEW_PRESERVATION_SNAPSHOT_MANIFEST"),
            address(snapshots),
            inventoryContext.snapshot.recordHash,
            0,
            snapshotBytes
        );
        _item(
            ref,
            InventoryTypes.Kind.ORIGINAL_PAYLOAD,
            keccak256("VIEW_PRESERVATION_REFERENCE_MANIFEST"),
            address(referenceHost),
            referenceHash,
            0,
            referenceBytes
        );
        require(
            snap.schemaId == SnapshotDefinitions.SCHEMA_ID
                && ref.schemaId == ReferenceDefinitions.SCHEMA_ID,
            "original interpretation schemas retained"
        );
        require(
            inventoryContext.snapshot.canonicalizationHash == SnapshotDefinitions.CANON_HASH,
            "snapshot receipt canonicalization unchanged"
        );
        require(
            inventoryContext.referenceRender.observation.canonicalizationHash
                == ReferenceDefinitions.CANON_HASH,
            "reference receipt canonicalization unchanged"
        );
    }
}
