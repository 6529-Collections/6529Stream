// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPreservationPolicyReferenceFixture
} from "./StreamCurrentAuthorityScopedPreservationPolicyReferenceFixture.sol";
import {
    StreamCurrentAuthorityInventoryTypes as ActualAuthority
} from "../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 as ActualInventoryInterface
} from "../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import { CurrentAuthorityAssemblyVm } from "./StreamCurrentAuthorityNativeAssemblyFixture.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1 as ActualScopedInventory
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as ActualScopedInventoryTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as ActualItems
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamArtistArchiveOriginTypes as ActualOrigins
} from "../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRightsRecordTypes as ActualRights
} from "../../smart-contracts/interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import {
    IStreamScopedContentRootPublication as ActualScopedRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

/// @notice Complete six-phase preservation inventory after actual scoped reference/record publication.
/// @dev Segment events are checked against stored commitments. This materializes source inventory;
/// it does not assert that the individual byte objects or complete bundle have archive coverage.
abstract contract StreamCurrentAuthorityScopedPreservationPolicyInventoryFixture is
    StreamCurrentAuthorityScopedPreservationPolicyReferenceFixture
{
    struct AuthorityScopedInventory {
        address host;
        bytes32 planId;
        ActualScopedInventoryTypes.Evidence evidence;
        ActualItems.Item[][] rows;
        bytes32 authorityCaptureHash;
    }

    function _authorityMaterializeScopedInventory(
        AuthorityScopedPublication memory publication,
        AuthorityScopedReference memory referenceResult,
        ScopedRecordSet memory records,
        ActualRights.Statement memory rights
    ) internal returns (AuthorityScopedInventory memory result) {
        require(
            referenceResult.recordHash != 0 && publication.consentRecord != 0
                && keccak256(abi.encode(records.scope)) == keccak256(abi.encode(publication.scope))
                && records.subject == rights.subjectId,
            "actual scope-specific records and referenceResult precede source inventory"
        );
        ActualScopedInventory inventory = ActualScopedInventory(publication.graph.children[5]);
        require(
            publication.graph.children[5].code.length != 0
                && publication.graph.children[5].codehash == publication.graph.codeHashes[5]
                && inventory.scopedPreservationPolicyInventoryProfile()
                    == ActualAuthority.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE
                && inventory.originProfile()
                    == ActualAuthority.SCOPED_PRESERVATION_POLICY_INVENTORY_PROFILE
                && inventory.supportsInterface(type(ActualInventoryInterface).interfaceId),
            "actual current-authority preservation inventory child"
        );
        bytes32 id = inventory.beginInventory(publication.scope);
        result.host = address(inventory);
        result.planId = id;
        result.authorityCaptureHash = keccak256(abi.encode(inventory.authoritySelection(id)));
        assemblyVm.recordLogs();
        while (inventory.plan(id).progress.completedStages == 0) {
            ActualScopedInventoryTypes.Plan memory before_ = inventory.plan(id);
            inventory.appendNative(id, 16);
            ActualScopedInventoryTypes.Plan memory after_ = inventory.plan(id);
            require(
                after_.nativeCursor > before_.nativeCursor || after_.progress.completedStages == 1
            );
        }
        while (inventory.plan(id).progress.completedStages == 1) {
            ActualScopedInventoryTypes.Plan memory before_ = inventory.plan(id);
            inventory.appendReference(id, 16);
            ActualScopedInventoryTypes.Plan memory after_ = inventory.plan(id);
            require(
                after_.referenceCursor > before_.referenceCursor
                    || after_.progress.completedStages == 2
            );
        }
        inventory.appendWork(
            id,
            records.work.description,
            address(this),
            _assemblyReceiptWitnessFor(
                address(inventory), id, 4, 24, records.workPublication.authorizationHash
            )
        );
        inventory.appendRights(id, rights);
        inventory.appendIntent(
            id,
            records.intent.intent,
            address(this),
            _assemblyReceiptWitnessFor(
                address(inventory), id, 4, 24, records.intentPublication.authorizationHash
            )
        );
        inventory.appendInterview(
            id,
            records.intent.interview.interview,
            address(this),
            _assemblyReceiptWitnessFor(
                address(inventory), id, 4, 24, records.interviewPublication.authorizationHash
            )
        );
        ActualOrigins.ReceiptWitness memory rootReceipt =
            _assemblyReceiptWitnessFor(address(inventory), id, 6, 17, publication.consentRecord);
        // The immutable per-root aggregate is required even if newer scopes have been published.
        ActualScopedInventoryTypes.Plan memory beforeRoot = inventory.plan(id);
        ActualScopedRoot.Aggregate memory wrongAggregate =
            abi.decode(abi.encode(publication.aggregate), (ActualScopedRoot.Aggregate));
        wrongAggregate.transitionChain = keccak256("wrong scoped root historical aggregate");
        (bool accepted,) = address(inventory)
            .call(
                abi.encodeCall(
                    inventory.appendRootAuthorization,
                    (
                        id,
                        publication.actor,
                        publication.observedAt,
                        wrongAggregate,
                        publication.legacyFamily,
                        rootReceipt
                    )
                )
            );
        require(
            !accepted
                && keccak256(abi.encode(inventory.plan(id))) == keccak256(abi.encode(beforeRoot)),
            "wrong signed family cannot advance source inventory"
        );
        inventory.appendRootAuthorization(
            id,
            publication.actor,
            publication.observedAt,
            publication.aggregate,
            publication.legacyFamily,
            rootReceipt
        );
        while (inventory.plan(id).progress.completedStages == 7) {
            uint64 before_ = inventory.plan(id).progress.segmentCount;
            inventory.appendDefinition(id);
            require(inventory.plan(id).progress.segmentCount == before_ + 1);
        }
        require(inventory.plan(id).progress.completedStages == 8);
        require(publication.payloads.length == inventory.plan(id).progress.tokenCount);
        for (uint256 i; i < publication.payloads.length; ++i) {
            require(inventory.plan(id).progress.nextToken == i);
            inventory.appendTokenOutput(id, publication.payloads[i]);
            inventory.appendTokenScript(id);
            inventory.appendTokenLibrary(id);
            while (inventory.tokenProgress(id).phase == 3) inventory.appendTokenRenderer(id);
            while (inventory.tokenProgress(id).phase == 4) inventory.appendTokenCitation(id);
            require(
                inventory.tokenProgress(id).phase == 5
                    && inventory.plan(id).progress.nextToken == i,
                "preservation producer closure is the mandatory sixth token phase"
            );
            while (inventory.tokenProgress(id).phase == 5) inventory.appendTokenPreservation(id);
            require(inventory.plan(id).progress.nextToken == i + 1);
            require(
                keccak256(abi.encode(inventory.tokenProgress(id)))
                    == keccak256(abi.encode(ActualScopedInventoryTypes.TokenProgress(0, 0, 0)))
            );
        }
        uint256 origins = inventory.originCount(id);
        require(origins != 0 && origins <= ActualOrigins.MAX_ORIGINS);
        for (uint256 i; i < origins; ++i) {
            inventory.appendOriginRuntime(id);
        }
        require(inventory.originRuntimeCursor(id) == origins);
        ActualItems.Plan memory completed = inventory.plan(id).progress;
        result.rows = _actualScopedInventoryRows(inventory, id, completed.segmentCount);
        result.evidence = inventory.sealInventory(id);
        uint256 itemCount;
        for (uint256 i; i < result.rows.length; ++i) {
            itemCount += result.rows[i].length;
        }
        ActualItems.Evidence memory evidence = result.evidence.inventory;
        require(
            evidence.planId == id && evidence.segmentCount == result.rows.length
                && evidence.itemCount == itemCount
                && evidence.tokenCount == publication.payloads.length
        );
        require(
            evidence.originals.rootRecordHash == publication.rootHash
                && evidence.originals.snapshotRecordHash == publication.snapshot.recordHash
                && evidence.originals.referenceRenderRecordHash == referenceResult.recordHash
                && evidence.originals.workDescriptionRecordHash
                    == records.workPublication.recordHash
                && evidence.originals.intentRecordHash == records.intentPublication.recordHash
                && evidence.originals.intentWaiverRecordHash == 0
                && evidence.originals.interviewEvidenceHash != 0
        );
        require(
            result.authorityCaptureHash == keccak256(abi.encode(inventory.authoritySelection(id)))
        );
        require(
            keccak256(abi.encode(inventory.requireCurrent(publication.scope)))
                == keccak256(abi.encode(result.evidence))
        );
    }

    function _actualScopedInventoryRows(ActualScopedInventory inventory, bytes32 id, uint64 count)
        private
        returns (ActualItems.Item[][] memory rows)
    {
        CurrentAuthorityAssemblyVm.Log[] memory logs = assemblyVm.getRecordedLogs();
        rows = new ActualItems.Item[][](count);
        uint256 index;
        bytes32 signature = keccak256(
            "ScopedInventorySegmentRecorded(uint16,bytes32,uint64,(bytes32,uint64,bytes32,bytes32),(uint8,bytes32,address,bytes32,uint256,uint16,bytes32,bytes,string,uint64,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)[])"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(inventory)) continue;
            require(
                index < rows.length && logs[i].topics.length == 3 && logs[i].topics[0] == signature
                    && logs[i].topics[1] == id && uint256(logs[i].topics[2]) == index
            );
            (uint16 version, ActualItems.Segment memory segment, ActualItems.Item[] memory items) =
                abi.decode(logs[i].data, (uint16, ActualItems.Segment, ActualItems.Item[]));
            require(version == 1, "actual scoped preservation segment version");
            require(
                items.length == segment.itemCount
                    && keccak256(abi.encode(segment))
                        == keccak256(abi.encode(inventory.inventorySegment(id, uint64(index))))
            );
            rows[index++] = items;
        }
        require(index == rows.length, "every dynamic scoped segment is retained in order");
    }
}
