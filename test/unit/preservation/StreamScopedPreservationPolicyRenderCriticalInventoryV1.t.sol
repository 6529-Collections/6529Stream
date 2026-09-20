// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    ScopedPreservationReferenceFixtureV1
} from "./StreamScopedPreservationPolicyReferencePublicationV1.t.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as C
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as I
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as Ref
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalNativeReadsV1 as Native
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalNativeReadsV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTokenReadsV1 as Tokens
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalTokenReadsV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";

import {
    StreamScopedPreservationPolicyRenderCriticalStateV1 as StageState
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTokenStagesV1 as StageTokens
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalTokenStagesV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalInventoryV1 as InventoryHost
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalInventoryV1.sol";

/// @dev Isolates only the outer original-stage gate. No current context or completed-stage claim.
contract PreservationInventoryPriorStageProbe {
    StageState.State private state;
    bytes32 private constant KEY = keccak256("isolated incomplete stage");

    function seedIncomplete(uint16 stage) external {
        require(stage < 8);
        state.plans[KEY].progress.collectionId = 1;
        state.plans[KEY].progress.completedStages = stage;
    }

    function preserve() external {
        StageTokens.appendPreservation(state, KEY);
    }

    function progress() external view returns (C.Plan memory, C.TokenProgress memory) {
        return (state.plans[KEY], state.tokenProgress[KEY]);
    }
}

/// @notice Genuine mixed policy factory, checkpoint/output, snapshot and reference originals feed inventory readers.
/// @dev Inherits explicit Core/Artist/producer/admission and external capture boundaries. These finite
/// output/native-source tests do not claim all-stage inventory, governed admission, finality or gas acceptance.
contract StreamScopedPreservationPolicyRenderCriticalInventoryV1Test is
    ScopedPreservationReferenceFixtureV1
{
    D.Dependencies internal inventoryD;
    C.Context internal inventoryC;
    Ref.SourceFacts internal inventoryF;

    function _inventory(uint8 terminalStatus, uint8 scopeKind) internal {
        _reference(terminalStatus, scopeKind);
        _publishReference();
        _inventoryContext();
    }

    function _inventoryContext() internal {
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
        Ref.Receipt memory r = referenceHost.currentReference(publication.scope);
        inventoryF = referenceHost.referenceSource(r.observation.recordHash);
        inventoryC.scope = publication.scope;
        inventoryC.subject = inventoryF.scopeSubject;
        inventoryC.artistId = inventoryF.snapshotSource.artist.artistId;
        inventoryC.snapshot = inventoryF.snapshot;
        inventoryC.snapshotSource = inventoryF.snapshotSource;
        inventoryC.referenceRender = r;
        inventoryC.nativeHash = keccak256(abi.encode(inventoryF.snapshotSource));
        inventoryC.rootRecordHash = inventoryF.contentRootRecordHash;
        inventoryC.tokenInventoryHash = inventoryF.snapshotSource.membership.membershipHash;
        inventoryC.checkpointHash = inventoryF.snapshotSource.outputs.checkpointHash;
        inventoryC.outputManifestRecord = publication.outputManifestRecord;
        inventoryC.selectionId = inventoryF.snapshotSource.content.selectionId;
        inventoryC.selectionHash = inventoryF.snapshotSource.content.selectionHash;
        inventoryC.tokenCount = uint64(inventoryF.snapshotSource.membership.tokenCount);
    }

    function _digest(I.Item memory row, bytes memory original) internal pure {
        require(
            row.byteSize == original.length
                && keccak256(row.digest) == keccak256(abi.encodePacked(keccak256(original))),
            "exact original bytes"
        );
    }

    function testScopedPreservationInventoryNativeRowsRetainExactRootFactoryAndCompletePolicies()
        public
    {
        _inventory(1, 2);
        (I.Item[] memory rows, uint64 total) = Native.items(inventoryD, inventoryC, 0, 64);
        require(
            total == 44 + 2 * inventoryF.snapshotSource.entropy.policies.length
                && rows.length == total,
            "complete finite native source"
        );
        _digest(rows[0], abi.encode(publication, inventoryF.snapshot));
        _digest(rows[1], snapshotHost.snapshotPayload(adoptedSnapshot));
        _digest(rows[2], abi.encode(inventoryF.snapshotSource));
        _digest(rows[3], abi.encode(inventoryF.contentRoot, inventoryF.contentRootBinding));
        require(
            rows[3].role == keccak256("ORIGINAL_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1")
                && abi.encode(inventoryF.contentRootBinding).length == 800,
            "25-word preservation root binding"
        );
        _digest(rows[8], abi.encode(inventoryF.snapshotSource.entropy));
        require(
            rows[38].source == inventoryF.snapshotSource.sourceFactory
                && rows[38].kind == I.Kind.CONTRACT_RUNTIME,
            "actual source factory runtime"
        );
        _digest(rows[39], abi.encode(scopedFactory.dependencies()));
        require(rows[39].byteSize == 352, "exact original factory tuple");
        for (uint256 i; i < inventoryF.snapshotSource.entropy.policies.length; ++i) {
            require(
                rows[44 + 2 * i].source
                    == inventoryF.snapshotSource.entropy.policies[i].coordinator,
                "ordered actual coordinator"
            );
            _digest(rows[45 + 2 * i], abi.encode(inventoryF.snapshotSource.entropy.policies[i]));
        }
        (I.Item[] memory first,) = Native.items(inventoryD, inventoryC, 0, 17);
        (I.Item[] memory rest,) = Native.items(inventoryD, inventoryC, 17, 64);
        for (uint256 i; i < first.length; ++i) {
            require(keccak256(abi.encode(first[i])) == keccak256(abi.encode(rows[i])));
        }
        for (uint256 i; i < rest.length; ++i) {
            require(keccak256(abi.encode(rest[i])) == keccak256(abi.encode(rows[17 + i])));
        }
    }

    function testScopedPreservationInventoryLiteralDynamicProducerPreimageTerminalAndFinalized()
        public
    {
        _inventory(1, 2);
        for (uint64 i; i < inventoryC.tokenCount; ++i) {
            (uint256 token, Tokens.Original memory o) = Tokens.sourceAt(inventoryD, inventoryC, i);
            require(
                token == 91 + i && abi.encode(o.output).length == 1152 && o.entropy.length == 320
            );
            bytes memory literal = abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1"),
                inventoryC.snapshotSource.content.preservationProfile,
                o.output.preservation,
                o.output.preservationAdmission,
                o.selection.configHash,
                o.selection.rawSourceHash,
                o.selection.sources[3],
                o.entropy,
                snapshotHost.dependencies().targets[10],
                snapshotHost.dependencies().codeHashes[10],
                inventoryC.snapshotSource.content.inventoryHash,
                inventoryC.snapshotSource.content.policyChainHash,
                o.readiness,
                o.readiness.codehash,
                o.output.terminalAdmissionHash
            );
            require(
                literal.length == 40 * 32 && keccak256(literal) == o.output.sourceFactsHash,
                "actual scoped producer dynamic bytes preimage"
            );
            bytes32 incompatible = keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1"),
                    inventoryC.snapshotSource.content.preservationProfile,
                    o.output.preservation,
                    o.output.preservationAdmission,
                    o.selection.configHash,
                    o.selection.rawSourceHash,
                    o.selection.sources[3],
                    o.output.entropy,
                    snapshotHost.dependencies().targets[10],
                    snapshotHost.dependencies().codeHashes[10],
                    inventoryC.snapshotSource.content.inventoryHash,
                    inventoryC.snapshotSource.content.policyChainHash,
                    o.readiness,
                    o.readiness.codehash,
                    o.output.terminalAdmissionHash
                )
            );
            require(
                incompatible != o.output.sourceFactsHash,
                "collection static-tuple encoding is distinct"
            );
            Content.Output memory changedOutput = abi.decode(abi.encode(o.output), (Content.Output));
            changedOutput.sourceFactsHash = incompatible;
            snapshotVm.mockCall(
                address(snapshotContent),
                abi.encodeCall(Content.outputAt, (inventoryC.checkpointHash, i)),
                abi.encode(changedOutput)
            );
            vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
            Tokens.sourceAt(inventoryD, inventoryC, i);
            snapshotVm.mockCall(
                address(snapshotContent),
                abi.encodeCall(Content.outputAt, (inventoryC.checkpointHash, i)),
                abi.encode(o.output)
            );
            I.Item[] memory rows =
                Tokens.tokenItems(inventoryD, inventoryC, i, _payload(snapshotCapture)[i]);
            require(
                rows.length == 12 && rows[6].sourceIndex == i && rows[7].byteSize == 1152
                    && rows[10].source == o.readiness
            );
            _digest(rows[5], o.entropy);
            _digest(rows[7], abi.encode(o.output));
            if (i == 0) {
                require(
                    o.output.entropy.terminal && !o.output.entropy.finalized
                        && o.output.entropy.status == 1 && o.output.entropy.seed == 0
                        && rows[11].byteSize == 608
                );
                _digest(rows[11], o.terminalAdmission);
            } else {
                require(
                    o.output.entropy.finalized && !o.output.entropy.terminal
                        && rows[11].kind == I.Kind.ABSENT && o.terminalAdmission.length == 0
                );
            }
        }
    }

    function testScopedPreservationInventoryExpiredTerminalIsNotFabricatedFinalization() public {
        _inventory(2, 1);
        (, Tokens.Original memory o) = Tokens.sourceAt(inventoryD, inventoryC, 0);
        require(
            o.output.entropy.status == 2 && o.output.entropy.mode == 2 && o.output.entropy.terminal
                && !o.output.entropy.finalized && o.output.entropy.seed == 0
        );
        I.Item[] memory rows =
            Tokens.tokenItems(inventoryD, inventoryC, 0, _payload(snapshotCapture)[0]);
        require(
            rows[11].role == keccak256("ORIGINAL_TERMINAL_RENDER_ADMISSION")
                && rows[11].byteSize == 608
        );
        _digest(rows[11], o.terminalAdmission);
    }

    function testScopedPreservationInventoryWrongOrdinalScopeAndPayloadFailBeforeRetry() public {
        _inventory(1, 2);
        I.Item[] memory original =
            Tokens.tokenItems(inventoryD, inventoryC, 0, _payload(snapshotCapture)[0]);
        Content.Payload memory wrong = _payload(snapshotCapture)[1];
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        Tokens.tokenItems(inventoryD, inventoryC, 0, wrong);
        wrong = _payload(snapshotCapture)[0];
        wrong.animation = bytes("replacement");
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        Tokens.tokenItems(inventoryD, inventoryC, 0, wrong);
        C.Context memory changed = abi.decode(abi.encode(inventoryC), (C.Context));
        changed.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 92, 0);
        Content.Payload memory exactPayload = _payload(snapshotCapture)[0];
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        Tokens.tokenItems(inventoryD, changed, 0, exactPayload);
        require(
            keccak256(
                abi.encode(
                    Tokens.tokenItems(inventoryD, inventoryC, 0, _payload(snapshotCapture)[0])
                )
            ) == keccak256(abi.encode(original)),
            "identical original retry"
        );
    }

    function testScopedPreservationInventoryFactoryPinAndSavedSourceMutationRestoreExactly()
        public
    {
        _inventory(1, 1);
        (I.Item[] memory before_,) = Native.items(inventoryD, inventoryC, 0, 64);
        C.Context memory changed = abi.decode(abi.encode(inventoryC), (C.Context));
        changed.snapshotSource.factoryDependenciesHash =
            keccak256("different immutable factory tuple");
        vm.expectRevert(abi.encodeWithSelector(I.InventorySourceChanged.selector));
        Native.items(inventoryD, changed, 0, 64);
        bytes memory original = address(scopedFactory).code;
        vm.etch(address(scopedFactory), hex"00");
        vm.expectRevert(abi.encodeWithSelector(I.InventoryRead.selector, address(scopedFactory)));
        Native.items(inventoryD, inventoryC, 0, 64);
        vm.etch(address(scopedFactory), original);
        (I.Item[] memory after_,) = Native.items(inventoryD, inventoryC, 0, 64);
        require(keccak256(abi.encode(before_)) == keccak256(abi.encode(after_)));
    }

    function testPreservationSourceIgnoresLiveBytesButRequiresSavedProducerAndExactPayload()
        public
    {
        _inventory(1, 2);
        Content.Payload memory payload = _payload(snapshotCapture)[1];
        I.Item[] memory original = Tokens.tokenItems(inventoryD, inventoryC, 1, payload);
        require(original[1].source == payload.producer && original[3].source == payload.producer);
        require(
            original[1].role == keccak256("PRESERVATION_TOKEN_METADATA_JSON")
                && original[3].role == keccak256("PRESERVATION_TOKEN_ANIMATION_HTML")
        );
        _digest(
            original[1], bytes(snapshotCapture.producers[1].preservationTokenJSON(payload.tokenId))
        );
        _digest(original[3], payload.animation);
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenJSON(uint256)", payload.tokenId),
            abi.encode("different live projection")
        );
        snapshotVm.mockCall(
            address(router),
            abi.encodeWithSignature("tokenHTML(uint256)", payload.tokenId),
            abi.encode("different live HTML")
        );
        require(
            keccak256(abi.encode(Tokens.tokenItems(inventoryD, inventoryC, 1, payload)))
                == keccak256(abi.encode(original))
        );
        payload.producer = address(snapshotCapture.producers[0]);
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        Tokens.tokenItems(inventoryD, inventoryC, 1, payload);
        payload.producer = address(snapshotCapture.producers[1]);
        string memory json = snapshotCapture.producers[1].preservationTokenJSON(payload.tokenId);
        string memory html = snapshotCapture.producers[1].preservationTokenHTML(payload.tokenId);
        snapshotCapture.producers[1].setBytes(payload.tokenId, string.concat(json, " "), html);
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        Tokens.tokenItems(inventoryD, inventoryC, 1, payload);
        snapshotCapture.producers[1].setBytes(payload.tokenId, json, html);
        require(
            keccak256(abi.encode(Tokens.tokenItems(inventoryD, inventoryC, 1, payload)))
                == keccak256(abi.encode(original))
        );
    }

    function testEverySavedAdmissionWordAndOtherMembersProducerAreIndependentlyJoined() public {
        _inventory(1, 2);
        Content.Output memory original = snapshotContent.outputAt(snapshotCapture.id, 1);
        bytes memory input = abi.encodeCall(Content.outputAt, (snapshotCapture.id, uint256(1)));
        for (uint256 i; i < 7; ++i) {
            bytes memory words = abi.encode(original.preservationAdmission);
            words[i * 32 + 31] ^= 0x01;
            Content.Output memory bad = abi.decode(abi.encode(original), (Content.Output));
            bad.preservationAdmission = abi.decode(words, (P.Admission));
            snapshotVm.mockCall(address(snapshotContent), input, abi.encode(bad));
            vm.expectRevert();
            Tokens.sourceAt(inventoryD, inventoryC, 1);
        }
        Content.Output memory substituted = abi.decode(abi.encode(original), (Content.Output));
        substituted.preservation = snapshotContent.outputAt(snapshotCapture.id, 0).preservation;
        snapshotVm.mockCall(address(snapshotContent), input, abi.encode(substituted));
        vm.expectRevert(abi.encodeWithSelector(P.InvalidPreservationBinding.selector));
        Tokens.sourceAt(inventoryD, inventoryC, 1);
        snapshotVm.mockCall(address(snapshotContent), input, abi.encode(original));
        (, Tokens.Original memory restored) = Tokens.sourceAt(inventoryD, inventoryC, 1);
        require(keccak256(abi.encode(restored.output)) == keccak256(abi.encode(original)));
    }

    function testPreservationPhaseCannotSkipAnyOfTheEightOriginalStages() public {
        PreservationInventoryPriorStageProbe probe = new PreservationInventoryPriorStageProbe();
        for (uint16 i; i < 8; ++i) {
            probe.seedIncomplete(i);
            (C.Plan memory before_, C.TokenProgress memory tokenBefore) = probe.progress();
            vm.expectRevert(abi.encodeWithSelector(I.InventoryIncomplete.selector));
            probe.preserve();
            (C.Plan memory after_, C.TokenProgress memory tokenAfter) = probe.progress();
            require(
                keccak256(abi.encode(before_, tokenBefore))
                    == keccak256(abi.encode(after_, tokenAfter))
            );
        }
    }

    function testUnstartedRealHostCannotAppendPreservationOrSeal() public {
        _inventory(1, 1);
        InventoryHost host = new InventoryHost(inventoryD);
        bytes32 absent = keccak256("never began source inventory");
        vm.expectRevert(abi.encodeWithSelector(I.InventoryIncomplete.selector));
        host.appendTokenPreservation(absent);
        vm.expectRevert(abi.encodeWithSelector(I.InventoryIncomplete.selector));
        host.sealInventory(absent);
        require(
            host.plan(absent).progress.collectionId == 0 && host.tokenProgress(absent).phase == 0
        );
    }
}
