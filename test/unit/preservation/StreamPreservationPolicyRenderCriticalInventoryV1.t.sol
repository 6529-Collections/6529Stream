// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    PreservationReferenceFixtureV1
} from "./StreamPreservationPolicyReferencePublicationV1.t.sol";
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as C
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as I
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as Ref
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    StreamPreservationPolicyRenderCriticalTokenReadsV1 as Tokens
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalTokenReadsV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamPreservationPolicyRenderCriticalStateV1 as StageState
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamPreservationPolicyRenderCriticalTokenStagesV1 as StageTokens
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyRenderCriticalTokenStagesV1.sol";

/// @dev Only the outer stage gate is isolated; earlier current-context stages are not certified.
contract CollectionPreservationInventoryPriorStageProbe {
    StageState.State private state;
    bytes32 private constant KEY = keccak256("isolated incomplete Collection stage");

    function seedIncomplete(uint16 stage) external {
        require(stage < 8);
        state.records.plans[KEY].collectionId = 1;
        state.records.plans[KEY].completedStages = stage;
    }

    function preserve() external {
        StageTokens.appendPreservation(state, KEY);
    }

    function progress() external view returns (I.Plan memory, StageState.Progress memory) {
        return (state.records.plans[KEY], state.progress[KEY]);
    }
}

/// @notice Genuine COLLECTION checkpoint/output/snapshot/reference feed preservation token inventory reads.
/// @dev Retains the inherited explicit pre-snapshot Router root, Artist, producer/admission and
/// capture boundaries. These finite source tests do not claim complete inventory/finality or gas acceptance.
contract StreamPreservationPolicyRenderCriticalInventoryV1Test is PreservationReferenceFixtureV1 {
    D.Dependencies private inventoryD;
    C.Context private inventoryC;

    function _inventory() private {
        _reference();
        _publishReference();
        inventoryD.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(snapshotStore),
            address(router),
            address(snapshotHost),
            address(referenceHost),
            address(artist),
            address(artist),
            address(artist),
            address(snapshotCoverage),
            address(externalArchive)
        ];
        for (uint256 i; i < 12; ++i) {
            inventoryD.codeHashes[i] = inventoryD.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            inventoryD.artistTargets[i] = address(artist);
            inventoryD.artistCodeHashes[i] = address(artist).codehash;
        }
        inventoryD.artistContentOwner = address(artist);
        inventoryD.artistContentOwnerCodeHash = address(artist).codehash;
        inventoryD.chainId = block.chainid;
        inventoryD.readGas = 2000000;
        inventoryD.sourceGas = 16000000;
        inventoryD.selectionGas = 16000000;
        inventoryD.snapshotGas = 256000000;
        inventoryD.referenceGas = 512000000;
        inventoryC.referenceRender = referenceHost.currentReference(publication.scope);
        Ref.SourceFacts memory f =
            referenceHost.referenceSource(inventoryC.referenceRender.observation.recordHash);
        inventoryC.snapshot = f.snapshot;
        inventoryC.source = f.snapshotSource;
        inventoryC.records.collectionId = publication.scope.collectionId;
        inventoryC.records.subject = f.scopeSubject;
        inventoryC.records.artistId = f.snapshotSource.artist.artistId;
        inventoryC.records.nativeHash = keccak256(abi.encode(f.snapshotSource));
        inventoryC.records.rootRecordHash = f.contentRootRecordHash;
        inventoryC.records.tokenInventoryHash = f.snapshotSource.content.inventoryHash;
        inventoryC.records.checkpointHash = f.snapshotSource.outputs.checkpointHash;
        inventoryC.records.tokenCount = f.snapshotSource.content.tokenCount;
    }

    function testCollectionLiteralDynamicCheckpointPreimageRejectsStaticTupleForBothPolicies()
        public
    {
        _inventory();
        for (uint64 i; i < inventoryC.records.tokenCount; ++i) {
            (, Tokens.Original memory o) = Tokens.sourceAt(inventoryD, inventoryC, i);
            address readiness = snapshotContent.terminalReadiness();
            bytes memory literal = abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"),
                inventoryC.source.content.preservationProfile,
                o.output.preservation,
                o.output.preservationAdmission,
                o.selection.configHash,
                o.selection.rawSourceHash,
                o.selection.sources[3],
                o.entropy,
                snapshotHost.dependencies().targets[10],
                snapshotHost.dependencies().codeHashes[10],
                inventoryC.source.content.inventoryHash,
                inventoryC.source.content.policyChainHash,
                readiness,
                readiness.codehash,
                o.output.terminalAdmissionHash
            );
            require(
                literal.length == 40 * 32 && keccak256(literal) == o.output.sourceFactsHash
                    && abi.encode(o.output).length == 1152
            );
            bytes32 incompatible = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"),
                    inventoryC.source.content.preservationProfile,
                    o.output.preservation,
                    o.output.preservationAdmission,
                    o.selection.configHash,
                    o.selection.rawSourceHash,
                    o.selection.sources[3],
                    o.output.entropy,
                    snapshotHost.dependencies().targets[10],
                    snapshotHost.dependencies().codeHashes[10],
                    inventoryC.source.content.inventoryHash,
                    inventoryC.source.content.policyChainHash,
                    readiness,
                    readiness.codehash,
                    o.output.terminalAdmissionHash
                )
            );
            require(incompatible != o.output.sourceFactsHash);
            Content.Output memory bad = abi.decode(abi.encode(o.output), (Content.Output));
            bad.sourceFactsHash = incompatible;
            bytes memory input =
                abi.encodeCall(Content.outputAt, (inventoryC.records.checkpointHash, i));
            snapshotVm.mockCall(address(snapshotContent), input, abi.encode(bad));
            vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
            Tokens.sourceAt(inventoryD, inventoryC, i);
            snapshotVm.mockCall(address(snapshotContent), input, abi.encode(o.output));
            I.Item[] memory rows =
                Tokens.tokenItems(inventoryD, inventoryC, i, _payload(snapshotCapture)[i]);
            require(
                rows.length == 10 && rows[7].byteSize == 1152
                    && keccak256(rows[5].digest)
                        == keccak256(abi.encodePacked(keccak256(o.entropy)))
            );
            require(
                i == 0
                    ? o.output.entropy.terminal && !o.output.entropy.finalized
                        && o.output.entropy.seed == 0
                    : !o.output.entropy.terminal && o.output.entropy.finalized
                        && o.output.entropy.seed == scopedFinalizedSeed
            );
        }
    }

    function testCollectionInventoryUsesSavedMixedProducerBytesAndRejectsSubstitutedProducer()
        public
    {
        _inventory();
        Content.Payload memory payload = _payload(snapshotCapture)[1];
        I.Item[] memory original = Tokens.tokenItems(inventoryD, inventoryC, 1, payload);
        require(
            original[1].source == payload.producer && original[3].source == payload.producer
                && payload.producer != address(snapshotCapture.producers[0])
        );
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenJSON(uint256)", payload.tokenId),
            abi.encode("independent live presentation")
        );
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenHTML(uint256)", payload.tokenId),
            abi.encode("independent live HTML")
        );
        require(
            keccak256(abi.encode(Tokens.tokenItems(inventoryD, inventoryC, 1, payload)))
                == keccak256(abi.encode(original))
        );
        payload.producer = address(snapshotCapture.producers[0]);
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        Tokens.tokenItems(inventoryD, inventoryC, 1, payload);
        payload.producer = address(snapshotCapture.producers[1]);
        require(
            keccak256(abi.encode(Tokens.tokenItems(inventoryD, inventoryC, 1, payload)))
                == keccak256(abi.encode(original))
        );
    }

    function testCollectionPreservationPhaseCannotSkipAnyOriginalStage() public {
        CollectionPreservationInventoryPriorStageProbe probe =
            new CollectionPreservationInventoryPriorStageProbe();
        for (uint16 i; i < 8; ++i) {
            probe.seedIncomplete(i);
            (I.Plan memory before_, StageState.Progress memory tokenBefore) = probe.progress();
            vm.expectRevert(abi.encodeWithSelector(I.InventoryIncomplete.selector));
            probe.preserve();
            (I.Plan memory after_, StageState.Progress memory tokenAfter) = probe.progress();
            require(
                keccak256(abi.encode(before_, tokenBefore))
                    == keccak256(abi.encode(after_, tokenAfter))
            );
        }
    }
}
