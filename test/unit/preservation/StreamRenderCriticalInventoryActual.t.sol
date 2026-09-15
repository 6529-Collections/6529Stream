// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PreservationReferenceInventoryOracle } from "./PreservationReferenceInventoryOracle.sol";
import "./PreservationActualInventoryFixture.sol";
import {
    StreamPreservationInventoryChains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamRenderCriticalSourceReads
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalSourceReads.sol";
import {
    StreamRenderCriticalDefinitionStages
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalDefinitionStages.sol";
import {
    StreamFinalityDescriptionReads
} from "../../../smart-contracts/domains/finality/StreamFinalityDescriptionReads.sol";
import {
    StreamFinalityConservationReads
} from "../../../smart-contracts/domains/finality/StreamFinalityConservationReads.sol";
import {
    StreamReferenceInventoryReads
} from "../../../smart-contracts/domains/preservation/StreamReferenceInventoryReads.sol";
import {
    IStreamMetadataServingFacts
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";

interface PreservationInventoryLogVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract PreservationInventorySafeEnvelopeProbe {
    function execute(address safe, bytes memory transaction, uint256 available)
        external
        returns (uint256 used)
    {
        require(gasleft() > available + available / 63 + 10000, "envelope forwarding reserve");
        uint256 before_ = gasleft();
        (bool ok, bytes memory result) = safe.call{ gas: available }(transaction);
        used = before_ - gasleft();
        require(ok && result.length == 32 && abi.decode(result, (bool)), "actual Safe success");
        require(used <= available, "CALL overhead inside envelope");
    }
}

contract StreamRenderCriticalInventoryActualTest is PreservationActualInventoryFixture {
    function testCompleteActualOriginalInventoryAndIndependentEvidencePreimage() public {
        bytes32 id = _complete();
        InventoryT.Evidence memory e = renderInventory.requireCurrent(1);
        require(
            e.planId == id && e.originals.rootRecordHash == rootRecord
                && e.originals.snapshotRecordHash == terms.snapshotRecordHash,
            "actual source originals"
        );
        require(
            e.originals.referenceRenderRecordHash == referenceHost.currentReference(1).recordHash,
            "actual reference original"
        );
        require(
            e.originals.workDescriptionRecordHash == workRecord
                && e.originals.rightsStatementRecordHash == rightsRecord,
            "actual generic originals"
        );
        require(
            e.originals.intentRecordHash == 0 && e.originals.intentWaiverRecordHash == waiverRecord
                && e.originals.interviewEvidenceHash != 0,
            "independent explicit waiver semantics"
        );
        IStreamConservationRecordSelection.Selection memory original =
            conservationSelector.currentConservation(
                1, _subject(), StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
            );
        address[5] memory conservationTargets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(conservationSelector)
        ];
        bytes32 declaration = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_WAIVED_INTERVIEW_V1"),
                block.chainid,
                conservationTargets,
                _scope(),
                _subject(),
                original,
                StreamConservationDefinitions.INTERVIEW_SCHEMA_ID,
                StreamConservationDefinitions.INTERVIEW_PROFILE_HASH
            )
        );
        require(
            e.originals.interviewEvidenceHash == declaration && declaration != waiverRecord
                && declaration != rootRecord,
            "exact parent-payload-bound waived interview commitment"
        );
        require(
            terms.environment.packageFiles.length == 364
                && terms.environment.platformPrerequisites.length == 108
                && terms.captures.length == 2,
            "complete actual package fixture"
        );
        // 18 native + 479 reference + 2 WORK + 2 RIGHTS + 5 waiver + 1 waived
        // original + 1 root authorization + 31 documents + 8 token occurrences.
        require(
            e.tokenCount == 2 && e.segmentCount == 40 && e.itemCount == 547,
            "exact complete source occurrence count"
        );
        bytes32 recorded = e.renderCriticalEvidenceHash;
        e.renderCriticalEvidenceHash = 0;
        require(
            recorded
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_RENDER_CRITICAL_EVIDENCE_V1"),
                        block.chainid,
                        address(renderInventory),
                        renderInventory.dependencyHash(),
                        e
                    )
                ),
            "flat independent evidence preimage"
        );
        bytes32 chain;
        uint64 count;
        for (uint64 i; i < e.segmentCount; ++i) {
            InventoryT.Segment memory s = renderInventory.inventorySegment(id, i);
            chain =
                keccak256(abi.encode(keccak256("6529STREAM_PRESERVATION_SEGMENT_V1"), chain, i, s));
            count += s.itemCount;
        }
        require(
            chain == e.segmentChainHash && count == e.itemCount,
            "complete ordered segment and count join"
        );
        renderInventory.requireFullDefinitionBytes(id);
    }

    function testStageFailureRetryAndCanonicalTypedWitnessCannotBeSubstituted() public {
        bytes32 id = renderInventory.beginInventory(1);
        (bool ok,) =
            address(renderInventory).call(abi.encodeCall(renderInventory.appendReference, (id)));
        require(
            !ok && renderInventory.plan(id).completedStages == 0, "stage order cannot skip source"
        );
        renderInventory.appendNative(id);
        renderInventory.appendReference(id);
        bytes32 before_ = keccak256(abi.encode(renderInventory.plan(id)));
        StreamWorkRecordTypes.Description memory wrong = selectedWork;
        wrong.full.title = "A substituted source";
        (ok,) = address(renderInventory)
            .call(abi.encodeCall(renderInventory.appendWork, (id, wrong, address(0))));
        require(
            !ok && keccak256(abi.encode(renderInventory.plan(id))) == before_,
            "late typed mismatch rolls back stage"
        );
        renderInventory.appendWork(id, selectedWork, address(0));
        renderInventory.appendRights(id, selectedRights);
        (ok,) = address(renderInventory)
            .call(
                abi.encodeCall(
                    renderInventory.appendIntentWaiver, (id, selectedWaiver, address(0xdead))
                )
            );
        require(
            !ok && renderInventory.plan(id).completedStages == 4,
            "untrusted actor cannot locate another original envelope"
        );
        renderInventory.appendIntentWaiver(id, selectedWaiver, address(this));
        renderInventory.appendInterviewWaiver(id);
        (ok,) = address(renderInventory)
            .call(
                abi.encodeCall(
                    renderInventory.appendRootAuthorization, (id, address(this), uint64(999))
                )
            );
        require(
            !ok && renderInventory.plan(id).completedStages == 6,
            "signed deadline is not original observation time"
        );
        renderInventory.appendRootAuthorization(id, address(this), 1000);
        require(renderInventory.plan(id).completedStages == 7, "exact unchanged proof retry");
    }

    function testEveryClaimedDefinitionRemainsCurrentIncludingUnselectedIntent() public {
        bytes32 id = _complete();
        InventoryT.Evidence memory original = renderInventory.inventoryEvidence(id);
        bytes32 unused = StreamConservationDefinitions.INTENT_SCHEMA_ID;
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(unused, IStreamSchemaRegistry.DocumentStatus.ARCHIVED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (unused, IStreamSchemaRegistry.DocumentStatus.ARCHIVED)
            ),
            s,
            o,
            n
        );
        (bool ok,) =
            address(renderInventory).staticcall(abi.encodeCall(renderInventory.requireCurrent, (1)));
        require(!ok, "unselected but claimed definition is current bound");
        require(
            keccak256(abi.encode(renderInventory.inventoryEvidence(id)))
                == keccak256(abi.encode(original)),
            "original evidence remains readable"
        );
    }

    function testActualSafePermissionlessMaterializationPreservesOriginalAuthors() public {
        require(
            executeSafe(
                archiveAgentSafe,
                archiveAgentKeys,
                address(renderInventory),
                0,
                abi.encodeCall(renderInventory.beginInventory, (1)),
                0
            ),
            "ordinary Safe CALL begins actual sources"
        );
        bytes32 id = renderInventory.beginInventory(1);
        require(
            executeSafe(
                archiveAgentSafe,
                archiveAgentKeys,
                address(renderInventory),
                0,
                abi.encodeCall(renderInventory.appendNative, (id)),
                0
            ),
            "ordinary Safe CALL materializes native segment"
        );
        require(renderInventory.plan(id).completedStages == 1, "Safe stage committed");
        SourcesT.Context memory c = renderInventory.sourceContext(id);
        require(
            c.conservation.record.recorder == address(this)
                && c.conservation.record.publication.signer == address(this),
            "Safe materializer is not original artist"
        );
        require(
            c.referenceRender.recorder == address(this) && c.snapshot.publisher == address(this),
            "original curator and snapshot attribution retained"
        );
    }

    function testCompleteCurrentInventoryFitsNamedColdSixteenMillionRead() public {
        bytes32 id = _complete();
        InventoryT.Evidence memory expected = renderInventory.inventoryEvidence(id);
        bytes memory input = abi.encodeCall(renderInventory.requireCurrent, (uint256(1)));
        for (uint256 i; i < 12; ++i) {
            safeVm.cool(inventoryDependencies.targets[i]);
        }
        for (uint256 i; i < 5; ++i) {
            safeVm.cool(inventoryDependencies.artistTargets[i]);
        }
        safeVm.cool(inventoryDependencies.artistContentOwner);
        safeVm.cool(address(renderInventory));
        safeVm.cool(address(StreamRenderCriticalSourceReads));
        safeVm.cool(address(StreamRenderCriticalDefinitionStages));
        safeVm.cool(address(StreamFinalityReferenceReads));
        safeVm.cool(address(StreamFinalitySnapshotReads));
        safeVm.cool(address(StreamFinalityDescriptionReads));
        safeVm.cool(address(StreamFinalityConservationReads));
        uint256 before_ = gasleft();
        (bool ok, bytes memory raw) = address(renderInventory).staticcall{ gas: 16000000 }(input);
        uint256 used = before_ - gasleft();
        emit log_named_uint("completeInventoryNamed25ColdCurrent", used);
        if (!ok) assembly ("memory-safe") { revert(add(raw, 32), mload(raw)) }
        require(
            raw.length == 608 && keccak256(raw) == keccak256(abi.encode(expected)),
            "actual complete current nineteen words"
        );
    }

    function testFullOriginalAssociationPreservesDifferentHistoricalSigner() public {
        bytes32 id = _complete();
        SourcesT.Context memory c = renderInventory.sourceContext(id);
        IStreamMetadataServingFacts.ArtistPresentation memory presented =
            router.artistPresentation(1);
        require(
            presented.nominatedArtist == address(0xA11CE)
                && c.conservation.record.publication.signer == address(this)
                && presented.nominatedArtist != c.conservation.record.publication.signer,
            "original nominee and original record signer remain distinct"
        );
        this.requireAssociationForTest(presented, c.conservation.association);
        require(renderInventory.requireCurrent(1).planId == id, "complete current association");
    }

    function testFuzzFullAssociationRejectsChangedOriginalField(uint8 field, bytes32 delta) public {
        IStreamMetadataServingFacts.ArtistPresentation memory presented =
            router.artistPresentation(1);
        IStreamConservationRecordSelection.Selection memory selected =
            conservationSelector.currentConservation(
                1, _subject(), StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
            );
        this.requireAssociationForTest(presented, selected.association);
        if (delta == 0) delta = bytes32(uint256(1));
        uint256 which = field % 6;
        if (which == 0) presented.registry = address(uint160(presented.registry) ^ uint160(1));
        else if (which == 1) presented.registryCodeHash ^= delta;
        else if (which == 2) selected.association.artistId ^= delta;
        else if (which == 3) selected.association.generation += 1;
        else if (which == 4) selected.association.bindingHash ^= delta;
        else selected.association.identityRecordHash ^= delta;
        (bool ok, bytes memory reason) = address(this)
            .staticcall(
                abi.encodeCall(this.requireAssociationForTest, (presented, selected.association))
            );
        require(
            !ok && reason.length == 4
                && bytes4(reason) == InventoryT.InventorySourceChanged.selector,
            "one changed original association field must fail"
        );
    }

    /// @dev Pure cross-producer predicate tested with actual separately admitted fixture facts;
    /// the full inventory current path is the authority-bearing caller of the same predicate.
    function requireAssociationForTest(
        IStreamMetadataServingFacts.ArtistPresentation memory presented,
        IStreamConservationRecordSelection.Association memory association
    ) external view {
        StreamRenderCriticalSourceReads.requireSameArtistAssociation(
            inventoryDependencies.artistTargets[0],
            inventoryDependencies.artistCodeHashes[0],
            presented,
            association
        );
    }

    function testReferenceStageRetainsEveryOriginalItemEventAndFailureRetry() public {
        bytes32 id = renderInventory.beginInventory(1);
        renderInventory.appendNative(id);
        SourcesT.Context memory originalContext = renderInventory.sourceContext(id);
        InventoryT.Item[] memory originalRows =
            PreservationReferenceInventoryOracle.items(inventoryDependencies, originalContext);
        require(originalRows.length == 479, "every original reference occurrence");
        bytes32 key = keccak256(
            abi.encode(keccak256("6529STREAM_RENDER_CRITICAL_SEGMENT_V1"), id, uint64(1))
        );
        InventoryT.Segment memory originalSegment = StreamPreservationInventoryChains.segment(
            key, originalContext.referenceRender.payloadHash, originalRows
        );
        InventoryT.Plan memory before_ = renderInventory.plan(id);
        (bool ok,) = address(renderInventory).call{ gas: 1000000 }(
            abi.encodeCall(renderInventory.appendReference, (id))
        );
        require(
            !ok
                && keccak256(abi.encode(renderInventory.plan(id)))
                    == keccak256(abi.encode(before_)),
            "failed original read leaves every plan field unchanged"
        );
        PreservationInventoryLogVm logsVm =
            PreservationInventoryLogVm(address(uint160(uint256(keccak256("hevm cheat code")))));
        logsVm.recordLogs();
        renderInventory.appendReference(id);
        PreservationInventoryLogVm.Log[] memory logs = logsVm.getRecordedLogs();
        require(
            logs.length == 1 && logs[0].emitter == address(renderInventory), "original host event"
        );
        require(
            logs[0].topics.length == 3 && logs[0].topics[1] == id
                && logs[0].topics[2] == bytes32(uint256(1)),
            "exact original indexed fields"
        );
        require(
            logs[0].topics[0]
                == keccak256(
                    "InventorySegmentRecorded(bytes32,uint64,(bytes32,uint64,bytes32,bytes32),(uint8,bytes32,address,bytes32,uint256,uint16,bytes32,bytes,string,uint64,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)[])"
                ),
            "exact original event signature"
        );
        require(
            keccak256(logs[0].data) == keccak256(abi.encode(originalSegment, originalRows)),
            "exact full original event ABI"
        );
        require(
            keccak256(abi.encode(renderInventory.inventorySegment(id, 1)))
                == keccak256(abi.encode(originalSegment)),
            "exact original stored segment"
        );
        InventoryT.Plan memory after_ = renderInventory.plan(id);
        require(
            after_.segmentCount == 2 && after_.completedStages == 2
                && after_.itemCount == before_.itemCount + 479,
            "atomic complete stage"
        );
        require(
            after_.segmentChainHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_SEGMENT_V1"),
                        before_.segmentChainHash,
                        uint64(1),
                        originalSegment
                    )
                ),
            "exact original segment chain"
        );
    }

    function testCompleteReferenceStageFitsExactSafeTransactionEnvelope() public {
        bytes32 id = renderInventory.beginInventory(1);
        renderInventory.appendNative(id);
        uint256 nonce = archiveAgentSafe.nonce();
        bytes memory data = abi.encodeCall(renderInventory.appendReference, (id));
        bytes32 digest = archiveAgentSafe.getTransactionHash(
            address(renderInventory), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory transaction = abi.encodeCall(
            archiveAgentSafe.execTransaction,
            (
                address(renderInventory),
                0,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(archiveAgentKeys, digest)
            )
        );
        uint256 zero;
        for (uint256 i; i < transaction.length; ++i) {
            if (transaction[i] == 0) ++zero;
        }
        uint256 tokens = zero + 4 * (transaction.length - zero);
        uint256 intrinsic = 21000 + 4 * tokens;
        uint256 floor = 21000 + 10 * tokens;
        uint256 maximum = 16777216;
        require(floor <= maximum && intrinsic < maximum);
        uint256 available = maximum - intrinsic;
        PreservationInventorySafeEnvelopeProbe probe = new PreservationInventorySafeEnvelopeProbe();
        for (uint256 i; i < 12; ++i) {
            safeVm.cool(inventoryDependencies.targets[i]);
        }
        for (uint256 i; i < 5; ++i) {
            safeVm.cool(inventoryDependencies.artistTargets[i]);
        }
        safeVm.cool(inventoryDependencies.artistContentOwner);
        safeVm.cool(address(renderInventory));
        safeVm.cool(address(StreamReferenceInventoryReads));
        safeVm.cool(address(StreamRenderCriticalSourceReads));
        safeVm.cool(address(archiveAgentSafe));
        uint256 used = probe.execute(address(archiveAgentSafe), transaction, available);
        require(archiveAgentSafe.nonce() == nonce + 1, "original Safe nonce committed once");
        InventoryT.Plan memory p = renderInventory.plan(id);
        require(p.completedStages == 2 && p.segmentCount == 2, "complete stage committed");
        require(renderInventory.inventorySegment(id, 1).itemCount == 479, "all original roles");
        require(
            renderInventory.sourceContext(id).referenceRender.recorder == address(this),
            "materializer never replaces original curator"
        );
        uint256 envelope = intrinsic + used;
        if (envelope < floor) envelope = floor;
        require(envelope <= maximum);
        cheat.createDir("preservation-safe-envelope", true);
        cheat.writeFile("preservation-safe-envelope/calldata.hex", fixtureVm.toString(transaction));
        emit log_named_uint("referenceStageSafeTransactionBytes", transaction.length);
        emit log_named_uint("referenceStageSafeTransactionZeroBytes", zero);
        emit log_named_uint("referenceStageSafeTransactionIntrinsic", intrinsic);
        emit log_named_uint("referenceStageSafeTransactionFloor", floor);
        emit log_named_uint("referenceStageSafeExecutionGas", used);
        emit log_named_uint("referenceStageSafeWholeTransactionEnvelope", envelope);
    }

    function _complete() private returns (bytes32 id) {
        id = renderInventory.beginInventory(1);
        renderInventory.appendNative(id);
        renderInventory.appendReference(id);
        renderInventory.appendWork(id, selectedWork, address(0));
        renderInventory.appendRights(id, selectedRights);
        renderInventory.appendIntentWaiver(id, selectedWaiver, address(this));
        renderInventory.appendInterviewWaiver(id);
        renderInventory.appendRootAuthorization(id, address(this), 1000);
        for (uint256 i; i < 31; ++i) {
            renderInventory.appendDefinition(id);
        }
        renderInventory.appendToken(id, _originalTokenPayload(1));
        renderInventory.appendToken(id, _originalTokenPayload(2));
        renderInventory.sealInventory(id);
    }
}
