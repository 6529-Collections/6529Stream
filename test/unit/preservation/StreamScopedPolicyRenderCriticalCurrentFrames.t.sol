// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPolicyRenderCriticalSourceReadsV2 as Sources
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalCurrentReadsV2 as Current
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalCurrentReadsV2.sol";
import {
    StreamRenderCriticalSourceReads as Original
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalSourceReads.sol";
import {
    StreamScopedPolicyReferenceSourceReadsV2 as ScopedOriginal
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyReferenceSourceReadsV2.sol";
import {
    StreamFinalityScopedPolicyReferenceReadsV2 as References
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicyReferenceReadsV2.sol";
import {
    StreamFinalityDescriptionReads as Descriptions
} from "../../../smart-contracts/domains/finality/StreamFinalityDescriptionReads.sol";
import {
    StreamFinalityConservationReads as Conservation
} from "../../../smart-contracts/domains/finality/StreamFinalityConservationReads.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamRenderCriticalSourceTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as C
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as S
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedPolicyReferencePublicationV2 as Reference
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as Snapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityDescriptionEvidence
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityDescriptionTypes.sol";
import {
    StreamFinalityConservationEvidence
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityConservationTypes.sol";
import {
    StreamFinalityCoordinatorPolicyV2
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";

interface ScopedCurrentFramesVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
    function expectRevert(bytes4 selector) external;
    function expectRevert(bytes calldata reason) external;
}

/// @dev The two original record boundaries enforce exact calldata and the actual delegate host.
contract ScopedCurrentFramesReply {
    address private expectedCaller;
    mapping(bytes32 => bytes) private replies;
    mapping(bytes32 => bool) private configured;

    function expect(address caller) external {
        expectedCaller = caller;
    }

    function reply(bytes memory input, bytes memory output) external {
        replies[keccak256(input)] = output;
        configured[keccak256(input)] = true;
    }

    fallback() external {
        require(msg.sender == expectedCaller, "delegate host");
        require(configured[keccak256(msg.data)], "exact original read");
        bytes memory output = replies[keccak256(msg.data)];
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }
}

contract ScopedCurrentFramesHost {
    function current(D.Dependencies memory d, StreamFinalityScope memory scope)
        external
        view
        returns (C.Context memory)
    {
        return Sources.current(d, scope);
    }
}

/// @dev Tests the extracted current orchestration, joins and complete memory return.
/// Original pin/reference admission and description/conservation readers are explicit typed
/// mocked boundaries. This does not claim an actual complete inventory or publication ceremony.
contract StreamScopedPolicyRenderCriticalCurrentFramesTest {
    ScopedCurrentFramesVm private constant vm =
        ScopedCurrentFramesVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    D.Dependencies private d;
    StreamFinalityScope private scope;
    R.Dependencies private rd;
    R.Receipt private referenceReceipt;
    R.SourceFacts private facts;
    S.Publication private publication;
    StreamFinalityDescriptionEvidence private descriptions;
    StreamFinalityConservationEvidence private conservation;
    ScopedCurrentFramesReply private referenceHost;
    ScopedCurrentFramesReply private snapshotHost;

    function setUp() public {
        referenceHost = new ScopedCurrentFramesReply();
        snapshotHost = new ScopedCurrentFramesReply();
        referenceHost.expect(address(this));
        snapshotHost.expect(address(this));
        d.chainId = block.chainid;
        d.readGas = 200000;
        d.sourceGas = 1000000;
        d.referenceGas = 1000000;
        d.selectionGas = 1000000;
        d.snapshotGas = 1000000;
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(uint160(0x100 + i));
            d.codeHashes[i] = keccak256(abi.encode("pinned source", i));
        }
        d.targets[5] = address(snapshotHost);
        d.targets[6] = address(referenceHost);
        d.codeHashes[5] = address(snapshotHost).codehash;
        d.codeHashes[6] = address(referenceHost).codehash;
        d.artistTargets[0] = address(0x200);
        d.artistCodeHashes[0] = keccak256("artist runtime");
        scope = StreamFinalityScope(StreamFinalityScopeType.RELEASE, 71, 0, keccak256("release"));
        bytes32 subject = StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
        rd.chainId = block.chainid;
        rd.readGas = d.readGas;
        rd.sourceGas = d.sourceGas;
        rd.snapshotGas = d.snapshotGas;
        rd.archiveGas = d.readGas;
        uint256[7] memory roles = [uint256(0), 1, 2, 3, 4, 5, 11];
        for (uint256 i; i < 7; ++i) {
            rd.targets[i] = d.targets[roles[i]];
            rd.codeHashes[i] = d.codeHashes[roles[i]];
        }
        referenceHost.reply(abi.encodeCall(Reference.dependencies, ()), abi.encode(rd));
        S.Dependencies memory sd;
        sd.targets[9] = d.targets[10];
        sd.codeHashes[9] = d.codeHashes[10];
        vm.mockCall(address(Original), abi.encodeWithSelector(Original.bindings.selector, d), hex"");
        vm.mockCall(
            address(ScopedOriginal),
            abi.encodeWithSelector(ScopedOriginal.bindings.selector, rd),
            abi.encode(sd)
        );
        facts.scopeSubject = subject;
        facts.snapshot.recordHash = keccak256("snapshot record");
        facts.snapshot.scopeSubject = subject;
        facts.snapshot.revision = 9;
        facts.snapshot.manifestHash = keccak256("complete payload");
        facts.snapshot.manifestBytes = 8192;
        facts.snapshotSource.scope = scope;
        facts.snapshotSource.membership.scopeSubject = subject;
        facts.snapshotSource.membership.membershipHash = keccak256("both actual tokens");
        facts.snapshotSource.membership.tokenCount = 2;
        facts.snapshotSource.artist.registry = d.artistTargets[0];
        facts.snapshotSource.artist.registryCodeHash = d.artistCodeHashes[0];
        facts.snapshotSource.artist.artistId = keccak256("artist");
        facts.snapshotSource.artist.bindingGeneration = 3;
        facts.snapshotSource.artist.bindingHash = keccak256("artist binding");
        facts.snapshotSource.artist.identityRecordHash = keccak256("artist identity");
        facts.snapshotSource.content.tokenCount = 2;
        facts.snapshotSource.content.selectionId = keccak256("selection id");
        facts.snapshotSource.content.selectionHash = keccak256("selection hash");
        facts.snapshotSource.selection.tokenCount = 2;
        facts.snapshotSource.outputs.tokenCount = 2;
        facts.snapshotSource.outputs.checkpointHash = keccak256("checkpoint");
        facts.snapshotSource.entropy.policyCount = 2;
        for (uint256 i; i < 2; ++i) {
            StreamFinalityCoordinatorPolicyV2 memory row;
            row.coordinator = address(uint160(0x300 + i));
            row.policyHash = keccak256(abi.encode("policy", i));
            row.salt = keccak256(abi.encode("salt", i));
            row.collectionPolicy.revision = uint64(i + 1);
            facts.snapshotSource.entropy.policies.push(row);
        }
        facts.contentRootRecordHash = keccak256("original root");
        facts.contentRoot.publication.manifestURI = "ipfs://complete-original-root";
        for (uint256 i; i < 2; ++i) {
            R.Sample memory sample;
            sample.membershipIndex = uint64(i);
            sample.observation.tokenId = 100 + i;
            sample.observation.htmlHash = keccak256(abi.encode("complete sample", i));
            facts.samples.push(sample);
        }
        referenceReceipt.scopeSubject = subject;
        referenceReceipt.observation.recordHash = keccak256("reference record");
        referenceReceipt.observation.revision = 4;
        referenceReceipt.observation.snapshotRecordHash = facts.snapshot.recordHash;
        referenceReceipt.observation.snapshotRevision = facts.snapshot.revision;
        referenceReceipt.observation.payloadHash = keccak256("all reference bytes");
        publication.scope = scope;
        publication.outputManifestRecord = keccak256("output original");
        publication.manifestURI = "ipfs://complete-snapshot-uri";
        descriptions = StreamFinalityDescriptionEvidence(
            subject,
            keccak256("work"),
            keccak256("rights"),
            keccak256("work payload"),
            keccak256("rights payload"),
            keccak256("work selection"),
            keccak256("rights selection"),
            7,
            8
        );
        conservation.scopeSubject = subject;
        conservation.interviewEvidenceHash = keccak256("interview evidence");
        conservation.selected.association.artistId = facts.snapshotSource.artist.artistId;
        conservation.selected.association.generation = facts.snapshotSource.artist.bindingGeneration;
        conservation.selected.association.bindingHash = facts.snapshotSource.artist.bindingHash;
        conservation.selected.association.identityRecordHash =
        facts.snapshotSource.artist.identityRecordHash;
        conservation.selected.record.recordHash = keccak256("original intent");
        conservation.selected.record.publication.publicationHash =
            keccak256("full original publication");
        conservation.selected.interviewArchiveReferenceHash = keccak256("all archive fields");
        conservation.selected.selectionHash = keccak256("conservation selection");
        conservation.selected.revision = 6;
        _selections();
        _sync();
    }

    function _selections() private {
        vm.mockCall(
            address(Descriptions),
            abi.encodeWithSelector(
                Descriptions.requireCurrent.selector, Sources.descriptionDependencies(d), scope
            ),
            abi.encode(descriptions)
        );
        vm.mockCall(
            address(Conservation),
            abi.encodeWithSelector(
                Conservation.requireCurrent.selector, Sources.conservationDependencies(d), scope
            ),
            abi.encode(conservation)
        );
    }

    function _sync() private {
        referenceReceipt.observation.sourcesHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_SOURCES_V2"),
                d.chainId,
                d.targets[6],
                rd.targets,
                rd.codeHashes,
                facts
            )
        );
        referenceHost.reply(
            abi.encodeCall(Reference.currentReference, (scope)), abi.encode(referenceReceipt)
        );
        referenceHost.reply(
            abi.encodeCall(Reference.referenceSource, (referenceReceipt.observation.recordHash)),
            abi.encode(facts)
        );
        snapshotHost.reply(
            abi.encodeCall(Snapshot.snapshotRecord, (facts.snapshot.recordHash)),
            abi.encode(publication, facts.snapshot)
        );
        vm.mockCall(
            address(References),
            abi.encodeWithSelector(
                References.requireCurrent.selector,
                Sources.referenceDependencies(d),
                scope,
                referenceReceipt.observation.recordHash,
                referenceReceipt.observation.revision
            ),
            abi.encode(referenceReceipt)
        );
    }

    function _expected() private view returns (C.Context memory c) {
        c.scope = scope;
        c.subject = facts.scopeSubject;
        c.artistId = facts.snapshotSource.artist.artistId;
        c.snapshot = facts.snapshot;
        c.snapshotSource = facts.snapshotSource;
        c.referenceRender = referenceReceipt;
        c.descriptions = descriptions;
        c.conservation = conservation.selected;
        c.interviewEvidenceHash = conservation.interviewEvidenceHash;
        c.nativeHash = keccak256(abi.encode(facts.snapshotSource));
        c.rootRecordHash = facts.contentRootRecordHash;
        c.tokenInventoryHash = facts.snapshotSource.membership.membershipHash;
        c.checkpointHash = facts.snapshotSource.outputs.checkpointHash;
        c.outputManifestRecord = publication.outputManifestRecord;
        c.selectionId = facts.snapshotSource.content.selectionId;
        c.selectionHash = facts.snapshotSource.content.selectionHash;
        c.tokenCount = 2;
    }

    function readCurrent() external view returns (C.Context memory) {
        return Sources.current(d, scope);
    }

    function testFullCurrentContextAndCallerArgumentsSurviveWorkerFrame() public {
        D.Dependencies memory input = d;
        StreamFinalityScope memory selected = scope;
        bytes32 before = keccak256(abi.encode(input, selected));
        C.Context memory actual = Sources.current(input, selected);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(_expected())), "complete context"
        );
        require(actual.snapshotSource.entropy.policies.length == 2, "all policy rows");
        require(keccak256(abi.encode(input, selected)) == before, "caller arguments");
        require(
            keccak256(abi.encode(Current.current(input, selected)))
                == keccak256(abi.encode(actual)),
            "fixed worker path"
        );
    }

    function testActualRecordCallsKeepAlternateDelegateHost() public {
        ScopedCurrentFramesHost other = new ScopedCurrentFramesHost();
        referenceHost.expect(address(other));
        snapshotHost.expect(address(other));
        require(
            keccak256(abi.encode(other.current(d, scope))) == keccak256(abi.encode(_expected())),
            "alternate host context"
        );
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(referenceHost)));
        this.readCurrent();
        referenceHost.expect(address(this));
        snapshotHost.expect(address(this));
        this.readCurrent();
    }

    function testScopeGuardPrecedesOriginalBindingRead() public {
        vm.clearMockedCalls();
        vm.mockCallRevert(
            address(Original), abi.encodeWithSelector(Original.bindings.selector, d), hex"deadbeef"
        );
        StreamFinalityScope memory invalid = scope;
        invalid.scopeType = StreamFinalityScopeType.COLLECTION;
        vm.expectRevert(T.InventorySourceChanged.selector);
        Sources.current(d, invalid);
        vm.expectRevert(bytes4(0xdeadbeef));
        this.readCurrent();
    }

    function testCompleteSourceHashAndCanonicalEnvelopeRefuseThenRestore() public {
        facts.snapshotSource.entropy.policies[1].salt ^= bytes32(uint256(1));
        referenceHost.reply(
            abi.encodeCall(Reference.referenceSource, (referenceReceipt.observation.recordHash)),
            abi.encode(facts)
        );
        vm.expectRevert(T.InventorySourceChanged.selector);
        this.readCurrent();
        facts.snapshotSource.entropy.policies[1].salt ^= bytes32(uint256(1));
        referenceHost.reply(
            abi.encodeCall(Reference.referenceSource, (referenceReceipt.observation.recordHash)),
            bytes.concat(abi.encode(facts), bytes32(0))
        );
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(referenceHost)));
        this.readCurrent();
        _sync();
        require(
            keccak256(abi.encode(this.readCurrent())) == keccak256(abi.encode(_expected())),
            "restored full source"
        );
    }

    function testSnapshotTupleAndOutputIdentityPrecedeSelections() public {
        S.Receipt memory wrong = facts.snapshot;
        wrong.revision++;
        snapshotHost.reply(
            abi.encodeCall(Snapshot.snapshotRecord, (facts.snapshot.recordHash)),
            abi.encode(publication, wrong)
        );
        vm.expectRevert(T.InventorySourceChanged.selector);
        this.readCurrent();
        publication.outputManifestRecord = 0;
        _sync();
        vm.mockCallRevert(
            address(Descriptions),
            abi.encodeWithSelector(
                Descriptions.requireCurrent.selector, Sources.descriptionDependencies(d), scope
            ),
            hex"deadbeef"
        );
        vm.expectRevert(T.InventorySourceChanged.selector);
        this.readCurrent();
        publication.outputManifestRecord = keccak256("output original");
        _sync();
        vm.expectRevert(bytes4(0xdeadbeef));
        this.readCurrent();
    }

    function testFinalCountAndOriginalArtistAssociationRefuseThenRestore() public {
        facts.snapshotSource.content.tokenCount = 3;
        _sync();
        vm.expectRevert(T.InventorySourceChanged.selector);
        this.readCurrent();
        facts.snapshotSource.content.tokenCount = 2;
        _sync();
        conservation.selected.association.generation++;
        _selections();
        vm.expectRevert(T.InventorySourceChanged.selector);
        this.readCurrent();
        conservation.selected.association.generation--;
        _selections();
        require(
            keccak256(abi.encode(this.readCurrent())) == keccak256(abi.encode(_expected())),
            "restored association and count"
        );
    }
}
