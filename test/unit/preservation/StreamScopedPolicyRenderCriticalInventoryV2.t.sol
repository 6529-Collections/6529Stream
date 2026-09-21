// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ScopedPolicyReferenceFixtureV2 } from "./StreamScopedPolicyReferencePublicationV2.t.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as C
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamRenderCriticalSourceTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as I
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as Ref
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    StreamScopedPolicyRenderCriticalSourceReadsV2 as Sources
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalNativeReadsV2 as Native
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalNativeReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalTokenReadsV2 as Tokens
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalTokenReadsV2.sol";
import {
    StreamScopedPolicyReferenceInventoryReadsV2 as References
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyReferenceInventoryReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalStateV2 as State
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamScopedPolicyRenderCriticalInventoryV2 as Inventory
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalInventoryV2.sol";
import {
    IStreamScopedPolicyRenderCriticalInventoryV2 as InventoryInterface
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyRenderCriticalInventoryV2.sol";
import {
    IStreamScopedRenderCriticalInventory as InventoryV1
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedRenderCriticalInventory.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyReferencePublicationV2 as ReferenceInterface
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopedPolicyRenderCriticalRootAuthorizationV2 as RootAuth
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalRootAuthorizationV2.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as RootV2
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    StreamArtistArchiveV2 as ArtistArchive
} from "../../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import {
    StreamArtistOnboardingTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistContentTypes as AC
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    StreamArtistHashes as ArtistHash
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistContentHashes as ContentHash
} from "../../../smart-contracts/domains/artist/StreamArtistContentHashes.sol";
import {
    ConservationSelectionCoordinatorBoundary,
    ConservationSelectionOwnerBoundary
} from "../metadata/StreamConservationSelectionFixture.sol";

/// @dev Explicit original op17 owner observation. Authorization transport and immutable Archive
/// append are exercised; this boundary makes no actual Artist signature/nonce execution claim.
contract ScopedPolicyRootConsentOwnerBoundaryV2 {
    ContentOwner.ConsentRecord private original;

    function save(ContentOwner.ConsentRecord memory value) external {
        original = value;
    }

    function contentConsentRecord(bytes32 hash)
        external
        view
        returns (ContentOwner.ConsentRecord memory)
    {
        require(hash == original.recordHash);
        return original;
    }
}

/// @dev Only the compiler-owned segment writer is isolated. This probe cannot seal an inventory
/// or assert that WORK/RIGHTS/INTENT, renderer admission, or Archive coverage are complete.
contract ScopedPolicyInventorySegmentProbeV2 {
    State.State private state;

    function id(D.Dependencies memory d, C.Context memory c) external view returns (bytes32) {
        return State.idFor(keccak256(abi.encode(d)), c);
    }

    function append(bytes32 key, I.Item[] memory rows, bytes32 witness, bool failAfter) external {
        State.append(state, key, rows, witness);
        require(!failAfter, "late segment consumer");
    }

    function progress(bytes32 key) external view returns (C.Plan memory) {
        return state.plans[key];
    }

    function segment(bytes32 key, uint64 index) external view returns (I.Segment memory) {
        return state.segments[key][index];
    }
}

/// @notice Actual scoped policy factory, complete output checkpoint, Snapshot, Router root,
/// Reference and immutable Store feed the NEW inventory workers. No old receipt is projected.
/// @dev Core/Artist/renderer admission/governance and external capture coverage are the named
/// inherited boundaries. These are source and segment tests, not a complete all-stage inventory
/// or finality/transaction-gas acceptance claim. Archive authorization is tested separately below.
contract StreamScopedPolicyRenderCriticalInventoryV2Test is ScopedPolicyReferenceFixtureV2 {
    D.Dependencies internal inventoryD;
    C.Context internal inventoryC;
    Ref.SourceFacts internal inventoryF;
    ScopedPolicyInventorySegmentProbeV2 internal segmentProbe;
    ArtistArchive private rootArchive;
    bytes32 private rootEvidenceId;
    bytes private rootEnvelope;
    Root.Aggregate private originalAggregate;
    bytes32 private originalLegacy;

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
        segmentProbe = new ScopedPolicyInventorySegmentProbeV2();
    }

    function _digest(I.Item memory row, bytes memory original) internal pure {
        require(
            row.byteSize == original.length
                && keccak256(row.digest) == keccak256(abi.encodePacked(keccak256(original))),
            "exact original bytes"
        );
    }

    function _payload(uint64 ordinal) internal view returns (Content.Payload memory p) {
        uint256 token = scopedMembership.scopeTokenAt(inventoryC.scope, ordinal);
        p = Content.Payload(token, hex"89504e470d0a1a0a", bytes(router.tokenHTML(token)));
    }

    function testScopedPolicyInventoryNativeRowsRetainExactRootFactoryAndCompletePolicies() public {
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
            rows[3].role == keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_V2")
                && abi.encode(inventoryF.contentRootBinding).length == 736,
            "23-word new root binding"
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

    function testScopedPolicyInventoryLiteralDynamicProducerPreimageTerminalAndFinalized() public {
        _inventory(1, 2);
        for (uint64 i; i < inventoryC.tokenCount; ++i) {
            (uint256 token, Tokens.Original memory o) = Tokens.sourceAt(inventoryD, inventoryC, i);
            require(
                token == 91 + i && abi.encode(o.output).length == 640 && o.entropy.length == 320
            );
            bytes memory literal = abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2"),
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
                literal.length == 23 * 32 && keccak256(literal) == o.output.sourceFactsHash,
                "actual scoped producer dynamic bytes preimage"
            );
            bytes32 incompatible = keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2"),
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
            I.Item[] memory rows = Tokens.tokenItems(inventoryD, inventoryC, i, _payload(i));
            require(
                rows.length == 12 && rows[6].sourceIndex == i && rows[7].byteSize == 640
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

    function testScopedPolicyInventoryExpiredTerminalIsNotFabricatedFinalization() public {
        _inventory(2, 1);
        (, Tokens.Original memory o) = Tokens.sourceAt(inventoryD, inventoryC, 0);
        require(
            o.output.entropy.status == 2 && o.output.entropy.mode == 2 && o.output.entropy.terminal
                && !o.output.entropy.finalized && o.output.entropy.seed == 0
        );
        I.Item[] memory rows = Tokens.tokenItems(inventoryD, inventoryC, 0, _payload(0));
        require(
            rows[11].role == keccak256("ORIGINAL_TERMINAL_RENDER_ADMISSION")
                && rows[11].byteSize == 608
        );
        _digest(rows[11], o.terminalAdmission);
    }

    function testScopedPolicyInventoryWrongOrdinalScopeAndPayloadFailBeforeRetry() public {
        _inventory(1, 2);
        I.Item[] memory original = Tokens.tokenItems(inventoryD, inventoryC, 0, _payload(0));
        Content.Payload memory wrong = _payload(1);
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        Tokens.tokenItems(inventoryD, inventoryC, 0, wrong);
        wrong = _payload(0);
        wrong.animation = bytes("replacement");
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        Tokens.tokenItems(inventoryD, inventoryC, 0, wrong);
        C.Context memory changed = abi.decode(abi.encode(inventoryC), (C.Context));
        changed.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 92, 0);
        Content.Payload memory exactPayload = _payload(0);
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        Tokens.tokenItems(inventoryD, changed, 0, exactPayload);
        require(
            keccak256(abi.encode(Tokens.tokenItems(inventoryD, inventoryC, 0, _payload(0))))
                == keccak256(abi.encode(original)),
            "identical original retry"
        );
    }

    function testScopedPolicyInventoryFactoryPinAndSavedSourceMutationRestoreExactly() public {
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

    function testScopedPolicyInventoryReferenceRowsUseNewCapabilityAndExactScope() public {
        _inventory(1, 2);
        References.Context memory c = References.Context(
            inventoryC.scope,
            inventoryC.subject,
            inventoryC.artistId,
            inventoryC.snapshot,
            inventoryC.referenceRender
        );
        (I.Item[] memory rows, uint64 total) = References.items(inventoryD, c, 0, 64);
        require(
            rows.length == total
                && total
                    == 3 + referenceInput.observation.environment.packageFiles.length
                        + referenceInput.observation.environment.platformPrerequisites.length
                        + referenceInput.observation.captures.length * 2
        );
        _digest(rows[0], referenceHost.referencePayload(c.referenceRender.observation.recordHash));
        c.scope.scopeType = StreamFinalityScopeType.SEASON;
        vm.expectRevert(abi.encodeWithSelector(I.InventorySourceChanged.selector));
        References.items(inventoryD, c, 0, 64);
        c.scope = inventoryC.scope;
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeCall(ReferenceInterface.scopedPolicyReferenceProfile, ()),
            abi.encode(keccak256("old profile"))
        );
        vm.expectRevert(abi.encodeWithSelector(I.InventorySourceChanged.selector));
        References.items(inventoryD, c, 0, 64);
        snapshotVm.mockCall(
            address(referenceHost),
            abi.encodeCall(ReferenceInterface.scopedPolicyReferenceProfile, ()),
            abi.encode(keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_V2"))
        );
        (I.Item[] memory retry,) = References.items(inventoryD, c, 0, 64);
        require(keccak256(abi.encode(retry)) == keccak256(abi.encode(rows)));
    }

    function testScopedPolicyInventorySegmentOrderRepeatedOccurrencesAndLateRollback() public {
        _inventory(1, 1);
        bytes32 id = segmentProbe.id(inventoryD, inventoryC);
        I.Item[] memory rows = Tokens.tokenItems(inventoryD, inventoryC, 0, _payload(0));
        bytes32 witness = keccak256("exact typed worker witness");
        segmentProbe.append(id, rows, witness, false);
        bytes32 saved =
            keccak256(abi.encode(segmentProbe.progress(id), segmentProbe.segment(id, 0)));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "late segment consumer"));
        segmentProbe.append(id, rows, witness, true);
        require(
            keccak256(abi.encode(segmentProbe.progress(id), segmentProbe.segment(id, 0))) == saved
                && segmentProbe.segment(id, 1).key == 0
        );
        segmentProbe.append(id, rows, witness, false);
        I.Segment memory a = segmentProbe.segment(id, 0);
        I.Segment memory b = segmentProbe.segment(id, 1);
        require(
            a.key
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_SEGMENT_V2"),
                            id,
                            uint64(0)
                        )
                    ) && a.key != b.key && a.firstLink != b.firstLink
        );
        require(
            segmentProbe.progress(id).progress.itemCount == 24
                && segmentProbe.progress(id).progress.segmentChainHash
                    == Chains.append(Chains.append(bytes32(0), 0, a), 1, b)
        );
        Inventory host = new Inventory(inventoryD);
        require(
            host.scopedPolicyInventoryProfile() == C.PROFILE
                && host.supportsInterface(type(InventoryInterface).interfaceId)
                && !host.supportsInterface(type(InventoryV1).interfaceId)
        );
        C.Context memory changed = abi.decode(abi.encode(inventoryC), (C.Context));
        changed.scope.collectionId = 2;
        require(segmentProbe.id(inventoryD, changed) != id, "full scope enters new plan domain");
    }

    function testScopedPolicyReadWorkerNativeSegmentGuardPrecedesSourceReads() public {
        D.Dependencies memory absent;
        C.Context memory context;
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventorySegment.selector));
        Native.items(absent, context, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventorySegment.selector));
        Native.items(absent, context, 0, 65);
    }

    function testScopedPolicyReadWorkerNativeFactoryPolicyBoundaryAndFinalRow() public {
        _inventory(1, 2);
        (I.Item[] memory boundary, uint64 total) = Native.items(inventoryD, inventoryC, 43, 2);
        require(boundary.length == 2 && total == 44 + 2 * inventoryF.snapshotSource.entropy.policies.length);
        require(
            boundary[0].role == keccak256("SCOPED_POLICY_FACTORY_DEPENDENCY_RUNTIME_V2")
                && boundary[0].source == scopedFactory.dependencies().targets[3]
                && boundary[0].sourceIndex == 3
                && boundary[1].role == keccak256("ORIGINAL_COORDINATOR_RUNTIME")
                && boundary[1].source == inventoryF.snapshotSource.entropy.policies[0].coordinator
                && boundary[1].sourceIndex == 0,
            "factory-to-policy segment preserves both original roles"
        );
        (I.Item[] memory last, uint64 repeatedTotal) = Native.items(inventoryD, inventoryC, total - 1, 64);
        uint256 finalIndex = inventoryF.snapshotSource.entropy.policies.length - 1;
        require(last.length == 1 && repeatedTotal == total && last[0].sourceIndex == finalIndex);
        require(last[0].role == keccak256("ORIGINAL_COORDINATOR_POLICY_V2"));
        _digest(last[0], abi.encode(inventoryF.snapshotSource.entropy.policies[finalIndex]));
        vm.expectRevert(abi.encodeWithSelector(I.InventorySourceChanged.selector));
        Native.items(inventoryD, inventoryC, total, 1);
    }

    function testScopedPolicyReadWorkerReturnsCompleteOriginalAuthorizationProvenance() public {
        _archivedRoot();
        I.Item memory row = RootAuth.contentItem(
            inventoryD, inventoryC, address(this), 1000, originalAggregate, originalLegacy
        );
        RootV2.Binding memory binding = router.scopedPolicyContentRootBinding(adoptedRoot);
        (bytes32 hash, address pointer, uint32 size, uint64 appendedAt) =
            rootArchive.artistEvidenceMetadataV2(rootEvidenceId, 1);
        bytes32 retained = keccak256(
            abi.encode(rootEvidenceId, hash, pointer, pointer.codehash, size, appendedAt)
        );
        bytes32 family = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                block.chainid, address(router), address(core), inventoryC.scope.collectionId,
                originalLegacy, originalAggregate
            )
        );
        require(
            row.provenanceHash == keccak256(
                abi.encode(
                    adoptedRoot, binding, originalAggregate, originalLegacy, family,
                    address(this), uint64(1000), retained, keccak256(abi.encode(inventoryD))
                )
            ),
            "all historical provenance words survive the worker return"
        );
        require(row.source == address(rootArchive) && row.sourceRecord == rootEvidenceId && row.sourceIndex == 1);
        _digest(row, rootEnvelope);
    }

    function _archivedRoot() private {
        _reference(1, 1);
        ConservationSelectionCoordinatorBoundary coordinator =
            new ConservationSelectionCoordinatorBoundary();
        ConservationSelectionOwnerBoundary identity = new ConservationSelectionOwnerBoundary();
        ScopedPolicyRootConsentOwnerBoundaryV2 owner = new ScopedPolicyRootConsentOwnerBoundaryV2();
        identity.configure(address(core), address(artist), address(coordinator));
        rootArchive = new ArtistArchive(address(artist), address(coordinator));
        A.SuiteConfiguration memory suite;
        suite.registry = address(artist);
        suite.core = address(core);
        suite.metadata = address(router);
        suite.mintManager = address(this);
        suite.archive = address(rootArchive);
        suite.owners[2] = address(identity);
        suite.owners[4] = address(identity);
        suite.owners[6] = address(owner);
        coordinator.setSuite(suite);
        snapshotVm.mockCall(
            address(artist), abi.encodeWithSignature("core()"), abi.encode(address(core))
        );
        snapshotVm.mockCall(
            address(artist),
            abi.encodeWithSignature("operationCoordinator()"),
            abi.encode(address(coordinator))
        );
        snapshotVm.mockCall(
            address(coordinator),
            abi.encodeWithSignature("configurationHash()"),
            abi.encode(keccak256(abi.encode(suite)))
        );
        Root.Publication memory p = Root.Publication(
            publication.scope, adoptedRoot, adoptedSnapshot, 1, "ipfs://exact-op17-root"
        );
        bytes32 family = router.previewScopedPolicyContentRootPublication(p, address(this));
        A.Binding memory b = A.Binding(
            lockedArtistBoundary.artistId,
            lockedArtistBoundary.nominatedArtist,
            lockedArtistBoundary.identityRecordHash,
            lockedArtistBoundary.bindingHash,
            lockedArtistBoundary.bindingGeneration,
            1,
            0,
            0,
            address(this),
            true
        );
        A.Authorization memory authorization =
            A.Authorization(77, uint64(block.timestamp + 1000), "");
        AC.Consent memory terms = AC.Consent(1, address(router), keccak256("CONTENT_ROOT"), family);
        ArtistHash.Environment memory env =
            ArtistHash.Environment(block.chainid, address(artist), address(core), address(this));
        A.SignerApproval memory approval = A.SignerApproval(
            address(this), ContentHash.consentDigest(env, terms, authorization), true
        );
        bytes32 consent = ContentHash.consentRecord(
            env, terms, b.artistId, address(this), 1, authorization.nonce, uint64(block.timestamp)
        );
        owner.save(ContentOwner.ConsentRecord(consent, b.artistId, b.generation, terms, 1));
        A.Snapshot[7] memory before_;
        A.Snapshot[7] memory after_;
        rootEnvelope = abi.encode(
            uint16(1),
            keccak256(abi.encode(suite)),
            uint16(17),
            address(this),
            consent,
            before_,
            after_,
            abi.encode(b, terms, authorization, approval, keccak256("original prior family"))
        );
        rootEvidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(artist),
                address(coordinator),
                uint16(17),
                address(this),
                consent
            )
        );
        vm.prank(address(coordinator));
        rootArchive.appendArtistEvidenceV2(rootEvidenceId, 1, rootEnvelope);
        artist.approve(1, keccak256("CONTENT_ROOT"), family, consent);
        adoptedRoot = router.publishScopedPolicyContentRootPublication(p);
        originalAggregate = router.scopedContentRootAggregate(1);
        originalLegacy = keccak256(
            abi.encode(
                keccak256("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"),
                block.chainid,
                address(router),
                address(core),
                uint256(1)
            )
        );
        require(
            family
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                        block.chainid,
                        address(router),
                        address(core),
                        uint256(1),
                        originalLegacy,
                        originalAggregate
                    )
                ),
            "original signed family preimage"
        );
        _publishReference();
        _inventoryContext();
        inventoryD.artistTargets = [
            address(artist),
            address(coordinator),
            address(identity),
            address(identity),
            address(rootArchive)
        ];
        for (uint256 i; i < 5; ++i) {
            inventoryD.artistCodeHashes[i] = inventoryD.artistTargets[i].codehash;
        }
        inventoryD.artistContentOwner = address(owner);
        inventoryD.artistContentOwnerCodeHash = address(owner).codehash;
    }

    function testScopedPolicyInventoryOriginalOp17BindsHistoricalAggregateAndFullV2Binding()
        public
    {
        _archivedRoot();
        Root.Record memory r = router.scopedContentRootRecord(adoptedRoot);
        RootV2.Binding memory binding = router.scopedPolicyContentRootBinding(adoptedRoot);
        require(
            abi.encode(binding).length == 736
                && adoptedRoot
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"),
                            block.chainid,
                            address(router),
                            address(core),
                            r,
                            binding,
                            originalAggregate
                        )
                    )
        );
        I.Item memory row = RootAuth.contentItem(
            inventoryD, inventoryC, address(this), 1000, originalAggregate, originalLegacy
        );
        require(
            row.kind == I.Kind.STATE_BUNDLE && row.source == address(rootArchive)
                && row.sourceRecord == rootEvidenceId && row.sourceIndex == 1
        );
        _digest(row, rootEnvelope);
        bytes32 later = _adopt(adoptedSnapshot, 1);
        require(
            later != adoptedRoot
                && router.scopedContentRootAggregate(1).revision == originalAggregate.revision + 1
        );
        require(
            keccak256(
                abi.encode(
                    RootAuth.contentItem(
                        inventoryD,
                        inventoryC,
                        address(this),
                        1000,
                        originalAggregate,
                        originalLegacy
                    )
                )
            ) == keccak256(abi.encode(row)),
            "later aggregate never rewrites original authority"
        );
        Root.Aggregate memory current = router.scopedContentRootAggregate(1);
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        RootAuth.contentItem(inventoryD, inventoryC, address(this), 1000, current, originalLegacy);
    }

    function testScopedPolicyInventoryRootBindingObservedTimeAndArchiveBytesExactRetry() public {
        _archivedRoot();
        I.Item memory row = RootAuth.contentItem(
            inventoryD, inventoryC, address(this), 1000, originalAggregate, originalLegacy
        );
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        RootAuth.contentItem(
            inventoryD, inventoryC, address(this), 999, originalAggregate, originalLegacy
        );
        RootV2.Binding memory binding = router.scopedPolicyContentRootBinding(adoptedRoot);
        RootV2.Binding memory wrong = abi.decode(abi.encode(binding), (RootV2.Binding));
        wrong.policyChainHash = keccak256("substituted policy chain");
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(RootV2.scopedPolicyContentRootBinding, (adoptedRoot)),
            abi.encode(wrong)
        );
        vm.expectRevert(abi.encodeWithSelector(I.InvalidInventoryItem.selector));
        RootAuth.contentItem(
            inventoryD, inventoryC, address(this), 1000, originalAggregate, originalLegacy
        );
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(RootV2.scopedPolicyContentRootBinding, (adoptedRoot)),
            abi.encode(binding)
        );
        (, address pointer,,) = rootArchive.artistEvidenceMetadataV2(rootEvidenceId, 1);
        bytes memory saved = pointer.code;
        vm.etch(pointer, hex"00");
        vm.expectRevert(abi.encodeWithSelector(I.InventoryRead.selector, address(rootArchive)));
        RootAuth.contentItem(
            inventoryD, inventoryC, address(this), 1000, originalAggregate, originalLegacy
        );
        vm.etch(pointer, saved);
        require(
            keccak256(
                abi.encode(
                    RootAuth.contentItem(
                        inventoryD,
                        inventoryC,
                        address(this),
                        1000,
                        originalAggregate,
                        originalLegacy
                    )
                )
            ) == keccak256(abi.encode(row)),
            "exact immutable Archive bytes retry"
        );
    }
}
