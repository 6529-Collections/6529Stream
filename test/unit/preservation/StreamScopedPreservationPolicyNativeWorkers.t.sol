// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyOutputSchemasV2 as OutputV2
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV2.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as DefinitionsV2
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamPreservationPolicyInventoryFamilyV2 as FamilyRead
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyInventoryFamilyV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalStateV1 as State
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamPreservationInventoryItems as Items
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryIO.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as Definitions
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputSchemas
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV1.sol";

import {
    StreamScopedPreservationPolicyRenderCriticalNativeReadsV1 as Candidate
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalNativeReadsV1.sol";
import {
    IStreamScopedPreservationPolicyReferencePublicationV1 as Reference
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityCoordinatorPolicyV2
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

import {
    StreamScopedPreservationPolicyNativeSegmentV1 as SegmentWorker
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyNativeSegmentV1.sol";

/// @dev Exact-calldata synthetic boundary. Every read requires the same consuming host.
/// No claim of original publication, Artist authority, real source admission or finality.
contract ScopedNativeWorkerReadTable {
    address private immutable reader;
    mapping(bytes32 => bytes) private answers;
    mapping(bytes32 => bool) private present;
    mapping(bytes32 => bool) private failures;

    constructor(address reader_) {
        reader = reader_;
    }

    function set(bytes memory input, bytes memory output, bool failure) external {
        bytes32 key = keccak256(input);
        answers[key] = output;
        present[key] = true;
        failures[key] = failure;
    }

    fallback(bytes calldata input) external returns (bytes memory output) {
        require(msg.sender == reader, "reader caller changed");
        bytes32 key = keccak256(input);
        if (!present[key] && bytes4(input) == IERC165.supportsInterface.selector) {
            bytes4 id = abi.decode(input[4:], (bytes4));
            return abi.encode(id != bytes4(0xffffffff));
        }
        require(present[key], "unconfigured exact read");
        output = answers[key];
        if (failures[key]) {
            assembly ("memory-safe") { revert(add(output, 32), mload(output)) }
        }
    }
}

contract ScopedNativeWorkerSameHost {
    // Separated compiler-owned State roots and nonzero sentinels catch a misrouted append boundary.
    uint256 private beforeState = 0x1234;
    State.State private actualState;
    uint256 private betweenStates = 0x5678;
    State.State private originalState;
    uint256 private afterState = 0x9abc;

    function segment(
        S.Dependencies memory d,
        Scoped.Context memory c,
        uint64 start,
        uint64 maximum,
        bytes32 family
    ) external view returns (T.Item[] memory, uint64) {
        return SegmentWorker.items(d, c, start, maximum, family);
    }

    function seedAppend(S.Dependencies memory d, Scoped.Context memory c, bytes32 id, uint8 fault)
        external
    {
        Scoped.Plan memory p;
        p.scope = c.scope;
        p.nativeCursor = 5;
        p.nativeCount = 48;
        p.referenceCursor = 7;
        p.referenceCount = 9;
        p.progress = T.Plan({
            collectionId: fault == 0 ? 0 : c.scope.collectionId,
            subject: c.subject,
            artistId: c.artistId,
            sourceContextHash: keccak256("untouched source context"),
            tokenCount: 11,
            nextToken: 3,
            segmentCount: 1,
            itemCount: 17,
            segmentChainHash: keccak256("untouched segment chain"),
            completedStages: fault == 1 ? 1 : 0,
            renderCriticalEvidenceHash: fault == 2 ? keccak256("already completed") : bytes32(0)
        });
        T.Segment memory prior = T.Segment(
            keccak256("prior key"), 17, keccak256("prior first link"), keccak256("prior witness")
        );
        actualState.dependencies = d;
        originalState.dependencies = d;
        actualState.dependencyHash = keccak256("untouched dependencies");
        originalState.dependencyHash = actualState.dependencyHash;
        actualState.contexts[id] = c;
        originalState.contexts[id] = c;
        actualState.plans[id] = p;
        originalState.plans[id] = p;
        actualState.segments[id][0] = prior;
        originalState.segments[id][0] = prior;
    }

    function appendActual(bytes32 id, uint64 maximum) external {
        Candidate.appendNative(actualState, id, maximum);
    }

    function appendOriginal(bytes32 id, uint64 maximum) external {
        FrozenScopedNativeEa4.appendNative(originalState, id, maximum);
    }

    function appendStateHashes(bytes32 id) external view returns (bytes32, bytes32) {
        bytes32 canaries = keccak256(abi.encode(beforeState, betweenStates, afterState));
        return (
            _appendStateHash(actualState, id, canaries),
            _appendStateHash(originalState, id, canaries)
        );
    }

    function _appendStateHash(State.State storage state, bytes32 id, bytes32 canaries)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                canaries,
                state.dependencies,
                state.dependencyHash,
                state.contexts[id],
                state.plans[id],
                state.segments[id][0],
                state.segments[id][1]
            )
        );
    }

    function actual(
        S.Dependencies memory d,
        Scoped.Context memory c,
        uint64 start,
        uint64 maximum,
        bytes32 family
    ) external view returns (T.Item[] memory, uint64) {
        return Candidate.items(d, c, start, maximum, family);
    }

    function original(
        S.Dependencies memory d,
        Scoped.Context memory c,
        uint64 start,
        uint64 maximum,
        bytes32 family
    ) external view returns (T.Item[] memory, uint64) {
        return FrozenScopedNativeEa4.items(d, c, start, maximum, family);
    }

    function defaultOriginal(
        S.Dependencies memory d,
        Scoped.Context memory c,
        uint64 start,
        uint64 maximum
    ) external view returns (T.Item[] memory, uint64) {
        return Candidate.items(d, c, start, maximum);
    }
}

/// @notice Differential tests against literal ea4 native-item bodies in the same caller host.
/// @dev Runs the real facade, linked workers, Sources bindings/hash checks and factory validator
/// against typed synthetic read tables. It does not establish publication/Artist admission,
/// full inventory staging, transaction gas, deployment capacity or complete current-stack execution.
contract StreamScopedPreservationPolicyNativeWorkersTest {
    struct Fixture {
        S.Dependencies d;
        Scoped.Context c;
        Snapshot.Dependencies sd;
        R.Dependencies rd;
        R.SourceFacts f;
        Policies.Dependencies factory;
        Snapshot.Publication publication;
        bytes payload;
        ScopedNativeWorkerSameHost host;
    }

    function _table(address host) private returns (address) {
        return address(new ScopedNativeWorkerReadTable(host));
    }

    function _set(address target, bytes memory input, bytes memory output) private {
        ScopedNativeWorkerReadTable(target).set(input, output, false);
    }

    function _setup(bytes32 family, uint8 scope, uint256 count) private returns (Fixture memory x) {
        x.host = new ScopedNativeWorkerSameHost();
        for (uint256 i; i < 12; ++i) {
            x.d.targets[i] = _table(address(x.host));
            x.d.codeHashes[i] = x.d.targets[i].codehash;
        }
        for (uint256 i; i < 5; ++i) {
            x.d.artistTargets[i] = _table(address(x.host));
            x.d.artistCodeHashes[i] = x.d.artistTargets[i].codehash;
        }
        x.d.artistContentOwner = _table(address(x.host));
        x.d.artistContentOwnerCodeHash = x.d.artistContentOwner.codehash;
        x.d.chainId = block.chainid;
        // Original finite inventory fixture caps, without a gas-limit or source-cap increase.
        x.d.readGas = 2000000;
        x.d.sourceGas = 16000000;
        x.d.selectionGas = 16000000;
        x.d.snapshotGas = 256000000;
        x.d.referenceGas = 512000000;
        uint256[7] memory roles = [uint256(0), 1, 2, 3, 4, 5, 11];
        for (uint256 i; i < 7; ++i) {
            x.rd.targets[i] = x.d.targets[roles[i]];
            x.rd.codeHashes[i] = x.d.codeHashes[roles[i]];
        }
        x.rd.chainId = block.chainid;
        x.rd.readGas = x.d.readGas;
        x.rd.sourceGas = x.d.sourceGas;
        x.rd.snapshotGas = x.d.snapshotGas;
        x.rd.archiveGas = x.d.readGas;
        for (uint256 i; i < 11; ++i) {
            x.sd.targets[i] = i < 5 ? x.d.targets[i] : _table(address(x.host));
            x.sd.codeHashes[i] = x.sd.targets[i].codehash;
        }
        x.sd.targets[9] = x.d.targets[10];
        x.sd.codeHashes[9] = x.d.codeHashes[10];
        x.sd.chainId = block.chainid;
        x.sd.readGas = x.d.readGas;
        x.sd.sourceGas = x.d.sourceGas;
        x.sd.inventoryGas = x.d.sourceGas;
        _set(x.d.targets[6], abi.encodeCall(Reference.dependencies, ()), abi.encode(x.rd));
        _set(x.d.targets[5], abi.encodeCall(Snap.dependencies, ()), abi.encode(x.sd));
        _set(
            x.d.targets[5],
            abi.encodeCall(Snap.scopedPreservationPolicySnapshotProfile, ()),
            abi.encode(
                family == Family.FAMILY_PROFILE
                    ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2")
                    : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1")
            )
        );
        _set(x.d.targets[11], abi.encodeWithSignature("core()"), abi.encode(x.d.targets[0]));
        x.factory.targets = [x.d.targets[0], x.d.targets[1], x.sd.targets[5], x.sd.targets[10]];
        for (uint256 i; i < 4; ++i) {
            x.factory.codeHashes[i] = x.factory.targets[i].codehash;
            if (i != 0) {
                _set(
                    x.factory.targets[i],
                    abi.encodeWithSignature("core()"),
                    abi.encode(x.d.targets[0])
                );
            }
        }
        x.factory.chainId = block.chainid;
        x.factory.readGas = uint32(x.d.readGas);
        x.factory.inventoryGas = uint32(x.d.sourceGas);
        _set(
            x.factory.targets[2],
            abi.encodeWithSignature("metadataHost()"),
            abi.encode(x.factory.targets[1])
        );
        _set(
            x.factory.targets[3],
            abi.encodeWithSignature("scopeMembershipHost()"),
            abi.encode(x.factory.targets[2])
        );
        _set(
            x.factory.targets[3],
            abi.encodeWithSignature("deploymentChainId()"),
            abi.encode(block.chainid)
        );
        _set(
            x.factory.targets[3],
            abi.encodeWithSignature("coreCodeHash()"),
            abi.encode(x.factory.codeHashes[0])
        );
        _set(
            x.factory.targets[3],
            abi.encodeWithSignature("scopeMembershipCodeHash()"),
            abi.encode(x.factory.codeHashes[2])
        );
        x.f.snapshotSource.sourceFactory = _table(address(x.host));
        x.f.snapshotSource.sourceFactoryCodeHash = x.f.snapshotSource.sourceFactory.codehash;
        x.f.snapshotSource.factoryDependenciesHash = keccak256(abi.encode(x.factory));
        _set(
            x.f.snapshotSource.sourceFactory,
            abi.encodeCall(Factory.dependencies, ()),
            abi.encode(x.factory)
        );
        x.c.scope =
            StreamFinalityScope(StreamFinalityScopeType(scope), 71, 81, bytes32(uint256(91)));
        x.c.subject = bytes32(uint256(101));
        x.c.rootRecordHash = bytes32(uint256(102));
        x.c.selectionId = bytes32(uint256(103));
        x.c.checkpointHash = bytes32(uint256(104));
        x.c.outputManifestRecord = bytes32(uint256(105));
        x.c.referenceRender.observation.recordHash = bytes32(uint256(106));
        x.payload = hex"00010203040506070809aabbccddeeff";
        x.f.snapshot = Snapshot.Receipt(
            bytes32(uint256(111)),
            x.c.subject,
            bytes32(uint256(113)),
            4,
            bytes32(uint256(115)),
            keccak256(x.payload),
            uint32(x.payload.length),
            bytes32(uint256(118)),
            address(0x119),
            7,
            121,
            8,
            123,
            124,
            bytes32(uint256(125)),
            bytes32(uint256(126)),
            bytes32(uint256(127))
        );
        x.publication.scope = x.c.scope;
        x.publication.snapshotId = bytes32(uint256(131));
        x.publication.expectedHead = bytes32(uint256(132));
        x.publication.expectedRevision = 3;
        x.publication.outputManifestRecord = x.c.outputManifestRecord;
        x.publication.coordinatorInventoryPlan = bytes32(uint256(135));
        x.publication.expectedSourceHash = bytes32(uint256(136));
        x.publication.manifestURI =
        "ipfs://literal-scoped-native-manifest/longer-than-thirty-two-bytes";
        x.publication.effectiveAt = 138;
        x.publication.reasonHash = bytes32(uint256(139));
        _fillSource(x, family, count);
        x.f.contentRootRecordHash = x.c.rootRecordHash;
        x.f.scopeSubject = x.c.subject;
        x.f.contentRoot.publication.scope = x.c.scope;
        x.f.contentRoot.publication.manifestURI = "ipfs://original-root/dynamic-exact-tuple";
        x.f.contentRoot.publication.expectedPredecessor = bytes32(uint256(401));
        x.f.contentRoot.publication.snapshotRecordHash = x.f.snapshot.recordHash;
        x.f.contentRoot.publication.snapshotRevision = 4;
        x.f.contentRoot.snapshotHost = x.d.targets[5];
        x.f.contentRoot.snapshotCodeHash = x.d.codeHashes[5];
        x.f.contentRoot.snapshotManifestHash = bytes32(uint256(402));
        x.f.contentRoot.snapshotSourceHash = bytes32(uint256(403));
        x.f.contentRoot.contentRoot = bytes32(uint256(404));
        x.f.contentRoot.leafCount = 405;
        x.f.contentRoot.outputManifestHash = bytes32(uint256(406));
        x.f.contentRoot.artistId = bytes32(uint256(407));
        x.f.contentRoot.bindingGeneration = 408;
        x.f.contentRoot.bindingHash = bytes32(uint256(409));
        x.f.contentRoot.publisher = address(0x410);
        x.f.contentRoot.authorizationClass = 7;
        x.f.contentRoot.grantRevision = 412;
        x.f.contentRoot.routeHash = bytes32(uint256(413));
        x.f.contentRoot.stateHash = bytes32(uint256(414));
        x.f.contentRoot.artistConsent = bytes32(uint256(415));
        x.f.contentRoot.publishedAt = 416;
        x.f.contentRootBinding.profileId = bytes32(uint256(421));
        x.f.contentRootBinding.outputManifest = x.sd.targets[8];
        x.f.contentRootBinding.outputManifestCodeHash = x.sd.codeHashes[8];
        x.f.contentRootBinding.checkpoint = x.sd.targets[7];
        x.f.contentRootBinding.checkpointCodeHash = x.sd.codeHashes[7];
        x.f.contentRootBinding.checkpointHash = bytes32(uint256(426));
        x.f.contentRootBinding.checkpointStateHash = bytes32(uint256(427));
        x.f.contentRootBinding.entropySourceSet = x.sd.targets[10];
        x.f.contentRootBinding.entropySourceSetCodeHash = x.sd.codeHashes[10];
        x.f.contentRootBinding.inventoryHash = bytes32(uint256(430));
        x.f.contentRootBinding.policyChainHash = bytes32(uint256(431));
        x.f.contentRootBinding.outputRoot = bytes32(uint256(432));
        x.f.contentRootBinding.outputSchemaHash = bytes32(uint256(433));
        x.f.contentRootBinding.outputCanonicalizationHash = bytes32(uint256(434));
        x.f.contentRootBinding.leafSchemaHash = bytes32(uint256(435));
        x.f.contentRootBinding.rootSchemaHash = bytes32(uint256(436));
        x.f.contentRootBinding.rootCanonicalizationHash = bytes32(uint256(437));
        x.f.contentRootBinding.sourceFactory = x.f.snapshotSource.sourceFactory;
        x.f.contentRootBinding.sourceFactoryCodeHash = x.f.snapshotSource.sourceFactoryCodeHash;
        x.f.contentRootBinding.factoryDependenciesHash = x.f.snapshotSource.factoryDependenciesHash;
        x.f.contentRootBinding.snapshotSchemaHash = bytes32(uint256(441));
        x.f.contentRootBinding.snapshotProfileHash = bytes32(uint256(442));
        x.f.contentRootBinding.snapshotCanonicalizationHash = bytes32(uint256(443));
        x.f.contentRootBinding.metadataRouter = x.d.targets[4];
        x.f.contentRootBinding.preservationOutputProfile = family;
        x.f.samples = new R.Sample[](1);
        x.f.samples[0].membershipIndex = 17;
        x.f.samples[0].selection.tokenId = 919;
        _sync(x, family);
        _set(
            x.d.targets[5],
            abi.encodeCall(Snap.snapshotRecord, (x.c.snapshot.recordHash)),
            abi.encode(x.publication, x.f.snapshot)
        );
        _set(
            x.d.targets[5],
            abi.encodeCall(Snap.snapshotPayload, (x.c.snapshot.recordHash)),
            abi.encode(x.payload)
        );
    }

    function _fillSource(Fixture memory x, bytes32 family, uint256 count) private {
        Snapshot.Source memory n = x.f.snapshotSource;
        n.scope = x.c.scope;
        n.membership.scopeSubject = x.c.subject;
        n.membership.scopeManifestHash = bytes32(uint256(201));
        n.membership.sourceRecordHash = bytes32(uint256(202));
        n.membership.tokenCount = 203;
        n.membership.tokenListHash = bytes32(uint256(204));
        n.membership.membershipHash = bytes32(uint256(205));
        n.membership.inventoryCount = 206;
        n.membership.inventoryPrefixHash = bytes32(uint256(207));
        n.artist.locked = true;
        n.artist.registry = x.d.artistTargets[0];
        n.artist.registryCodeHash = x.d.artistCodeHashes[0];
        n.artist.artistId = bytes32(uint256(214));
        n.artist.bindingGeneration = 215;
        n.artist.bindingHash = bytes32(uint256(216));
        n.artist.nominatedArtist = address(0x217);
        n.artist.identityRecordHash = bytes32(uint256(218));
        n.artist.acceptanceRecordHash = bytes32(uint256(219));
        n.artist.acceptedAt = 220;
        n.artist.lockedAt = 221;
        n.artist.snapshotHash = bytes32(uint256(222));
        n.selection.scope = x.c.scope;
        n.selection.membershipHash = bytes32(uint256(231));
        n.selection.collectionStateHash = bytes32(uint256(232));
        n.selection.tokenCount = 233;
        n.selection.nextIndex = 234;
        n.selection.selectionRoot = bytes32(uint256(235));
        n.content.selectionId = bytes32(uint256(241));
        n.content.selectionHash = bytes32(uint256(242));
        n.content.inventoryHash = bytes32(uint256(243));
        n.content.policyChainHash = bytes32(uint256(244));
        n.content.scope = x.c.scope;
        n.content.tokenCount = 246;
        n.content.nextIndex = 247;
        n.content.leafChainHash = bytes32(uint256(248));
        n.content.contentRoot = bytes32(uint256(249));
        n.content.outputRoot = bytes32(uint256(250));
        n.content.preservationProfile = family;
        n.outputs.checkpointHash = bytes32(uint256(261));
        n.outputs.checkpointStateHash = bytes32(uint256(262));
        n.outputs.entropySourceSet = x.sd.targets[10];
        n.outputs.inventoryHash = bytes32(uint256(264));
        n.outputs.policyChainHash = bytes32(uint256(265));
        n.outputs.metadataRouter = x.d.targets[4];
        n.outputs.preservationProfile = family;
        n.outputs.artifactHash = bytes32(uint256(268));
        n.outputs.coverageHash = bytes32(uint256(269));
        n.outputs.artistId = bytes32(uint256(270));
        n.outputs.contentRoot = bytes32(uint256(271));
        n.outputs.outputRoot = bytes32(uint256(272));
        n.outputs.manifestHash = bytes32(uint256(273));
        n.outputs.scope = x.c.scope;
        n.outputs.tokenCount = 275;
        n.outputs.byteLength = 276;
        n.entropy.planId = bytes32(uint256(281));
        n.entropy.inventoryHash = bytes32(uint256(282));
        n.entropy.policyChainHash = bytes32(uint256(283));
        n.entropy.policyCount = count;
        n.entropy.allFrozen = true;
        n.entropy.policies = new StreamFinalityCoordinatorPolicyV2[](count);
        for (uint256 i; i < count; ++i) {
            StreamFinalityCoordinatorPolicyV2 memory p = n.entropy.policies[i];
            p.coordinator = x.d.artistTargets[i % 5];
            p.indexedCodeHash = p.coordinator.codehash;
            p.firstTokenIndex = 301 + i;
            p.frozen = true;
            p.moduleVersion = bytes32(302 + i);
            p.moduleManifestHash = bytes32(303 + i);
            p.moduleSchemaHash = bytes32(304 + i);
            p.deploymentManifestHash = bytes32(305 + i);
            p.policyHash = bytes32(306 + i);
            p.provider = address(uint160(307 + i));
            p.epoch = uint32(308 + i);
            p.salt = bytes32(309 + i);
            p.componentDataHash = bytes32(310 + i);
            p.explicitPolicy = i % 2 == 0;
            p.collectionPolicy.configured = true;
            p.collectionPolicy.explicitPolicy = p.explicitPolicy;
            p.collectionPolicy.frozen = true;
            p.collectionPolicy.mode = uint8(1 + i);
            p.collectionPolicy.securityClass = uint8(4 + i);
            p.collectionPolicy.renderRequirement = uint8(7 + i);
            p.collectionPolicy.revision = uint64(311 + i);
            p.collectionPolicy.providerEpoch = uint32(312 + i);
            p.collectionPolicy.policyHash = bytes32(313 + i);
            p.collectionPolicy.contentStateHash = bytes32(314 + i);
            p.collectionPolicy.lastActionId = bytes32(315 + i);
            p.collectionPolicy.artistConsentRecord = bytes32(316 + i);
        }
    }

    function _sync(Fixture memory x, bytes32 family) private {
        x.c.snapshot = x.f.snapshot;
        x.c.snapshotSource = x.f.snapshotSource;
        x.c.nativeHash = keccak256(abi.encode(x.f.snapshotSource));
        x.c.referenceRender.observation.sourcesHash = keccak256(
            abi.encode(
                family == Family.FAMILY_PROFILE
                    ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V2")
                    : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V1"),
                x.d.chainId,
                x.d.targets[6],
                x.rd.targets,
                x.rd.codeHashes,
                x.f
            )
        );
        _set(
            x.d.targets[6],
            abi.encodeCall(Reference.referenceSource, (x.c.referenceRender.observation.recordHash)),
            abi.encode(x.f)
        );
    }

    function _pair(Fixture memory x, uint64 start, uint64 maximum, bytes32 family)
        private
        view
        returns (bool ok, bytes memory actual)
    {
        (ok, actual) = address(x.host)
            .staticcall(abi.encodeCall(x.host.actual, (x.d, x.c, start, maximum, family)));
        (bool originalOk, bytes memory original) = address(x.host)
            .staticcall(abi.encodeCall(x.host.original, (x.d, x.c, start, maximum, family)));
        require(
            ok == originalOk && keccak256(actual) == keccak256(original),
            "complete return/revert parity"
        );
    }

    function _good(Fixture memory x, uint64 start, uint64 maximum, bytes32 family)
        private
        view
        returns (T.Item[] memory rows, uint64 total)
    {
        (bool ok, bytes memory raw) = _pair(x, start, maximum, family);
        require(ok, "both readers must succeed");
        return abi.decode(raw, (T.Item[], uint64));
    }

    function _bad(
        Fixture memory x,
        uint64 start,
        uint64 maximum,
        bytes32 family,
        bytes memory reason
    ) private view {
        (bool ok, bytes memory raw) = _pair(x, start, maximum, family);
        require(!ok && keccak256(raw) == keccak256(reason), "exact original failure");
    }

    function _digest(T.Item memory item, bytes memory bytes_) private pure {
        require(
            item.byteSize == bytes_.length
                && keccak256(item.digest) == keccak256(abi.encodePacked(keccak256(bytes_))),
            "literal complete byte preimage"
        );
    }

    function testOriginalScopeRowsDefaultAndEverySegmentBoundary() public {
        for (uint8 scope = 1; scope <= 3; ++scope) {
            Fixture memory x = _setup(Family.ORIGINAL_PROFILE, scope, scope - 1);
            (T.Item[] memory all, uint64 total) = _good(x, 0, 64, Family.ORIGINAL_PROFILE);
            require(total == 44 + 2 * (scope - 1) && all.length == total);
            (T.Item[] memory defaultRows, uint64 defaultTotal) =
                x.host.defaultOriginal(x.d, x.c, 0, 64);
            require(
                defaultTotal == total
                    && keccak256(abi.encode(defaultRows)) == keccak256(abi.encode(all))
            );
            for (uint64 at; at < total; ++at) {
                (T.Item[] memory one, uint64 oneTotal) = _good(x, at, 1, Family.ORIGINAL_PROFILE);
                require(
                    one.length == 1 && oneTotal == total
                        && keccak256(abi.encode(one[0])) == keccak256(abi.encode(all[at]))
                );
            }
            _digest(all[0], abi.encode(x.publication, x.f.snapshot));
            _digest(all[1], x.payload);
            _digest(all[2], abi.encode(x.f.snapshotSource));
            _digest(all[3], abi.encode(x.f.contentRoot, x.f.contentRootBinding));
            _digest(all[8], abi.encode(x.f.snapshotSource.entropy));
            _digest(all[39], abi.encode(x.factory));
            require(
                all[1].schemaId == keccak256("STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V1")
            );
        }
    }

    function testFamilyScopeRowsKeepFullSourceAndDistinctManifestDomains() public {
        for (uint8 scope = 1; scope <= 3; ++scope) {
            Fixture memory x = _setup(Family.FAMILY_PROFILE, scope, 3);
            (T.Item[] memory rows, uint64 total) = _good(x, 0, 64, Family.FAMILY_PROFILE);
            require(total == 50 && rows.length == 50);
            _digest(rows[2], abi.encode(x.f.snapshotSource));
            _digest(rows[3], abi.encode(x.f.contentRoot, x.f.contentRootBinding));
            require(
                rows[1].schemaId == DefinitionsV2.SCHEMA_ID
                    && rows[1].schemaId != Definitions.SCHEMA_ID
            );
            require(
                rows[7].schemaId == OutputV2.SCHEMA && rows[7].canonicalizationId == OutputV2.CANON
            );
            require(
                rows[7].objectHash == x.f.snapshotSource.outputs.artifactHash
                    && rows[7].originalCoverageHash == x.f.snapshotSource.outputs.coverageHash
            );
            for (uint256 i; i < 3; ++i) {
                require(
                    rows[44 + 2 * i].source == x.f.snapshotSource.entropy.policies[i].coordinator
                );
                _digest(rows[45 + 2 * i], abi.encode(x.f.snapshotSource.entropy.policies[i]));
            }
        }
    }

    function testGuardOrderMaximumThenFamilyThenSourcesThenFactoryThenCount() public {
        Fixture memory x = _setup(Family.ORIGINAL_PROFILE, 2, 1);
        _bad(
            x,
            0,
            0,
            bytes32(uint256(999)),
            abi.encodeWithSelector(T.InvalidInventorySegment.selector)
        );
        _bad(
            x,
            0,
            65,
            bytes32(uint256(999)),
            abi.encodeWithSelector(T.InvalidInventorySegment.selector)
        );
        _bad(
            x,
            0,
            1,
            bytes32(uint256(999)),
            abi.encodeWithSelector(T.InventorySourceChanged.selector)
        );
        bytes memory sourceCall =
            abi.encodeCall(Reference.referenceSource, (x.c.referenceRender.observation.recordHash));
        bytes memory factoryCall = abi.encodeCall(Factory.dependencies, ());
        ScopedNativeWorkerReadTable(x.d.targets[6]).set(sourceCall, hex"1234", true);
        ScopedNativeWorkerReadTable(x.f.snapshotSource.sourceFactory)
            .set(factoryCall, hex"5678", true);
        _bad(
            x,
            100,
            1,
            Family.ORIGINAL_PROFILE,
            abi.encodeWithSelector(T.InventoryRead.selector, x.d.targets[6])
        );
        _set(x.d.targets[6], sourceCall, abi.encode(x.f));
        _bad(
            x,
            100,
            1,
            Family.ORIGINAL_PROFILE,
            abi.encodeWithSelector(T.InventoryRead.selector, x.f.snapshotSource.sourceFactory)
        );
        _set(x.f.snapshotSource.sourceFactory, factoryCall, abi.encode(x.factory));
        _bad(
            x,
            46,
            1,
            Family.ORIGINAL_PROFILE,
            abi.encodeWithSelector(T.InventorySourceChanged.selector)
        );
        _good(x, 0, 64, Family.ORIGINAL_PROFILE);
    }

    function testFullSourceAuthenticatedBeforeProjectionAndFrozenCountRefusalsRetry() public {
        Fixture memory x = _setup(Family.ORIGINAL_PROFILE, 3, 2);
        R.SourceFacts memory changed = abi.decode(abi.encode(x.f), (R.SourceFacts));
        changed.samples[0].membershipIndex += 1;
        _set(
            x.d.targets[6],
            abi.encodeCall(Reference.referenceSource, (x.c.referenceRender.observation.recordHash)),
            abi.encode(changed)
        );
        _bad(
            x,
            9,
            1,
            Family.ORIGINAL_PROFILE,
            abi.encodeWithSelector(T.InventorySourceChanged.selector)
        );
        _sync(x, Family.ORIGINAL_PROFILE);
        _good(x, 9, 1, Family.ORIGINAL_PROFILE);
        x.f.snapshotSource.entropy.allFrozen = false;
        _sync(x, Family.ORIGINAL_PROFILE);
        _bad(
            x,
            9,
            1,
            Family.ORIGINAL_PROFILE,
            abi.encodeWithSelector(T.InventorySourceChanged.selector)
        );
        x.f.snapshotSource.entropy.allFrozen = true;
        x.f.snapshotSource.entropy.policyCount = 3;
        _sync(x, Family.ORIGINAL_PROFILE);
        _bad(
            x,
            9,
            1,
            Family.ORIGINAL_PROFILE,
            abi.encodeWithSelector(T.InventorySourceChanged.selector)
        );
        x.f.snapshotSource.entropy.policyCount = 2;
        _sync(x, Family.ORIGINAL_PROFILE);
        _good(x, 0, 64, Family.ORIGINAL_PROFILE);
    }

    function testOriginalRecordPayloadCanonicalityAndCommitmentRefusalsRetry() public {
        Fixture memory x = _setup(Family.FAMILY_PROFILE, 1, 1);
        bytes memory call_ = abi.encodeCall(Snap.snapshotRecord, (x.c.snapshot.recordHash));
        bytes memory good = abi.encode(x.publication, x.f.snapshot);
        _set(x.d.targets[5], call_, bytes.concat(good, hex"00"));
        _bad(
            x,
            0,
            1,
            Family.FAMILY_PROFILE,
            abi.encodeWithSelector(T.InventoryRead.selector, x.d.targets[5])
        );
        Snapshot.Publication memory wrong =
            abi.decode(abi.encode(x.publication), (Snapshot.Publication));
        wrong.scope.scopeId = bytes32(uint256(998));
        _set(x.d.targets[5], call_, abi.encode(wrong, x.f.snapshot));
        _bad(
            x,
            0,
            1,
            Family.FAMILY_PROFILE,
            abi.encodeWithSelector(T.InventorySourceChanged.selector)
        );
        _set(x.d.targets[5], call_, good);
        _good(x, 0, 1, Family.FAMILY_PROFILE);
        call_ = abi.encodeCall(Snap.snapshotPayload, (x.c.snapshot.recordHash));
        _set(x.d.targets[5], call_, bytes.concat(abi.encode(x.payload), hex"00"));
        _bad(
            x,
            1,
            1,
            Family.FAMILY_PROFILE,
            abi.encodeWithSelector(T.InventoryRead.selector, x.d.targets[5])
        );
        _set(x.d.targets[5], call_, abi.encode(bytes("different retained payload")));
        _bad(
            x,
            1,
            1,
            Family.FAMILY_PROFILE,
            abi.encodeWithSelector(T.InventorySourceChanged.selector)
        );
        _set(x.d.targets[5], call_, abi.encode(x.payload));
        _good(x, 0, 64, Family.FAMILY_PROFILE);
    }

    function testFactoryAndLateRuntimePinsRejectWithoutChangingEarlierRowOrder() public {
        Fixture memory x = _setup(Family.ORIGINAL_PROFILE, 2, 2);
        bytes memory call_ = abi.encodeCall(Factory.dependencies, ());
        _set(x.f.snapshotSource.sourceFactory, call_, bytes.concat(abi.encode(x.factory), hex"00"));
        _bad(
            x,
            2,
            1,
            Family.ORIGINAL_PROFILE,
            abi.encodeWithSelector(T.InventoryRead.selector, x.f.snapshotSource.sourceFactory)
        );
        _set(x.f.snapshotSource.sourceFactory, call_, abi.encode(x.factory));
        bytes32 originalHash = x.f.snapshotSource.factoryDependenciesHash;
        x.f.snapshotSource.factoryDependenciesHash = bytes32(uint256(999));
        _sync(x, Family.ORIGINAL_PROFILE);
        _bad(
            x,
            2,
            1,
            Family.ORIGINAL_PROFILE,
            abi.encodeWithSelector(T.InventorySourceChanged.selector)
        );
        x.f.snapshotSource.factoryDependenciesHash = originalHash;
        _sync(x, Family.ORIGINAL_PROFILE);
        x.f.snapshotSource.entropy.policies[1].indexedCodeHash = bytes32(uint256(999));
        _sync(x, Family.ORIGINAL_PROFILE);
        _good(x, 44, 2, Family.ORIGINAL_PROFILE);
        _bad(
            x,
            46,
            1,
            Family.ORIGINAL_PROFILE,
            abi.encodeWithSelector(
                T.InventoryRead.selector, x.f.snapshotSource.entropy.policies[1].coordinator
            )
        );
        x.f.snapshotSource.entropy.policies[1].indexedCodeHash =
        x.f.snapshotSource.entropy.policies[1].coordinator.codehash;
        _sync(x, Family.ORIGINAL_PROFILE);
        bytes32 originalPin = x.sd.codeHashes[6];
        x.sd.codeHashes[6] = bytes32(uint256(999));
        _set(x.d.targets[5], abi.encodeCall(Snap.dependencies, ()), abi.encode(x.sd));
        _good(x, 21, 6, Family.ORIGINAL_PROFILE);
        _bad(
            x,
            27,
            1,
            Family.ORIGINAL_PROFILE,
            abi.encodeWithSelector(T.InventoryRead.selector, x.sd.targets[6])
        );
        x.sd.codeHashes[6] = originalPin;
        _set(x.d.targets[5], abi.encodeCall(Snap.dependencies, ()), abi.encode(x.sd));
        _good(x, 0, 64, Family.ORIGINAL_PROFILE);
    }

    function testSegmentBoundaryKeepsFullFacadeAndFrozenBytesAcrossFamilies() public {
        for (uint8 mode; mode < 2; ++mode) {
            bytes32 family = mode == 0 ? Family.ORIGINAL_PROFILE : Family.FAMILY_PROFILE;
            for (uint8 scope = 1; scope <= 3; ++scope) {
                Fixture memory x = _setup(family, scope, 2);
                (bool ok, bytes memory original) = _pair(x, 0, 64, family);
                (bool segmentOk, bytes memory segment) = address(x.host)
                    .staticcall(
                        abi.encodeCall(x.host.segment, (x.d, x.c, uint64(0), uint64(64), family))
                    );
                require(
                    ok && segmentOk && keccak256(segment) == keccak256(original),
                    "full segment boundary"
                );
                (T.Item[] memory rows, uint64 total) = abi.decode(segment, (T.Item[], uint64));
                require(total == 48 && rows.length == total);
                _digest(rows[2], abi.encode(x.f.snapshotSource));
                _digest(rows[3], abi.encode(x.f.contentRoot, x.f.contentRootBinding));
                // A late consumed-source pin still fails after the full source has been authenticated.
                bytes32 saved = x.f.snapshotSource.factoryDependenciesHash;
                x.f.snapshotSource.factoryDependenciesHash ^= bytes32(uint256(1));
                _sync(x, family);
                (ok, original) = _pair(x, 2, 1, family);
                (segmentOk, segment) = address(x.host)
                    .staticcall(
                        abi.encodeCall(x.host.segment, (x.d, x.c, uint64(2), uint64(1), family))
                    );
                require(
                    !ok && !segmentOk && keccak256(segment) == keccak256(original),
                    "segment refusal parity"
                );
                require(
                    keccak256(segment)
                        == keccak256(abi.encodeWithSelector(T.InventorySourceChanged.selector))
                );
                x.f.snapshotSource.factoryDependenciesHash = saved;
                _sync(x, family);
                _good(x, 0, 64, family);
                (rows, total) = x.host.segment(x.d, x.c, 0, 64, family);
                require(total == 48 && rows.length == total);
            }
        }
    }

    function testAppendBoundaryKeepsStageBeforeItemsAndRefusalsLeaveBothRootsUntouched() public {
        // These are early-stage refusals only. They do not admit a synthetic current context
        // or claim a full successful append ceremony; all original current reads remain real.
        for (uint8 fault; fault < 4; ++fault) {
            Fixture memory x = _setup(Family.ORIGINAL_PROFILE, 2, 2);
            if (fault == 3) {
                // Valid stage reaches Sources.current, whose original scope guard must precede
                // dependency reads and the requested invalid maximum in the later segment.
                x.c.scope.scopeType = StreamFinalityScopeType.COLLECTION;
                x.d.codeHashes[0] = bytes32(0);
            }
            bytes32 id = keccak256(abi.encode("append original stage", fault));
            x.host.seedAppend(x.d, x.c, id, fault);
            (bytes32 beforeActual, bytes32 beforeOriginal) = x.host.appendStateHashes(id);
            require(beforeActual == beforeOriginal);
            (bool ok, bytes memory actual) =
                address(x.host).call(abi.encodeCall(x.host.appendActual, (id, uint64(0))));
            (bool originalOk, bytes memory original) =
                address(x.host).call(abi.encodeCall(x.host.appendOriginal, (id, uint64(0))));
            bytes memory expected = fault == 3
                ? abi.encodeWithSelector(T.InventorySourceChanged.selector)
                : abi.encodeWithSelector(T.InventoryIncomplete.selector);
            require(!ok && !originalOk && keccak256(actual) == keccak256(original));
            require(keccak256(actual) == keccak256(expected), "stage before segment and pins");
            (bytes32 afterActual, bytes32 afterOriginal) = x.host.appendStateHashes(id);
            require(
                afterActual == beforeActual && afterOriginal == beforeOriginal,
                "both storage roots unchanged"
            );
        }
    }
}

/// @dev Literal ea4 five-argument items/_factory bodies, same host; only public becomes internal.
library FrozenScopedNativeEa4 {
    function appendNative(State.State storage state, bytes32 id, uint64 maximum) internal {
        State.stage(state, id, 0);
        Scoped.Plan storage p = state.plans[id];
        (T.Item[] memory rows, uint64 total) =
            items(state.dependencies, state.contexts[id], p.nativeCursor, maximum);
        if (p.nativeCursor != 0 && p.nativeCount != total) revert T.InventorySourceChanged();
        p.nativeCount = total;
        State.append(
            state,
            id,
            rows,
            keccak256(abi.encode(p.progress.sourceContextHash, p.nativeCursor, total))
        );
        p.nativeCursor += uint64(rows.length);
        if (p.nativeCursor == total) p.progress.completedStages = 1;
    }

    function items(S.Dependencies memory d, Scoped.Context memory c, uint64 start, uint64 maximum)
        internal
        view
        returns (T.Item[] memory rows, uint64 total)
    {
        return items(d, c, start, maximum, Family.ORIGINAL_PROFILE);
    }

    function items(
        S.Dependencies memory d,
        Scoped.Context memory c,
        uint64 start,
        uint64 maximum,
        bytes32 family
    ) internal view returns (T.Item[] memory rows, uint64 total) {
        if (maximum == 0 || maximum > 64) revert T.InvalidInventorySegment();
        Snapshot.Dependencies memory sd = Sources.snapshotBindings(d, family);
        R.SourceFacts memory f = Sources.sourceFacts(d, c, family);
        // Preserve the actual factory tuple and all four constructor targets, in addition
        // to the original inventory/snapshot/Artist roster and complete policy occurrences.
        Policies.Dependencies memory factory = _factory(d, f);
        uint256 count = 44 + f.snapshotSource.entropy.policies.length * 2;
        if (
            count > type(uint64).max || start >= count || !f.snapshotSource.entropy.allFrozen
                || f.snapshotSource.entropy.policyCount != f.snapshotSource.entropy.policies.length
        ) revert T.InventorySourceChanged();
        total = uint64(count);
        uint256 length = count - start;
        if (length > maximum) length = maximum;
        rows = new T.Item[](length);
        bytes32 original = c.snapshot.recordHash;
        for (uint256 i; i < length; ++i) {
            uint256 at = start + i;
            if (at == 0) {
                bytes memory raw = IO.read(
                    d.targets[5],
                    abi.encodeCall(Snap.snapshotRecord, (original)),
                    16384,
                    d.sourceGas
                );
                (Snapshot.Publication memory p, Snapshot.Receipt memory saved) =
                    abi.decode(raw, (Snapshot.Publication, Snapshot.Receipt));
                IO.canonical(d.targets[5], raw, abi.encode(p, saved));
                if (
                    keccak256(abi.encode(saved)) != keccak256(abi.encode(c.snapshot))
                        || keccak256(abi.encode(p.scope)) != keccak256(abi.encode(c.scope))
                ) revert T.InventorySourceChanged();
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V1"),
                    d.targets[5],
                    original,
                    0,
                    raw
                );
            } else if (at == 1) {
                bytes memory raw = IO.read(
                    d.targets[5],
                    abi.encodeCall(Snap.snapshotPayload, (original)),
                    524352,
                    d.sourceGas
                );
                bytes memory payload = abi.decode(raw, (bytes));
                IO.canonical(d.targets[5], raw, abi.encode(payload));
                if (
                    payload.length != c.snapshot.manifestBytes
                        || keccak256(payload) != c.snapshot.manifestHash
                ) revert T.InventorySourceChanged();
                rows[i] = Items.bytesItem(
                    T.Kind.ORIGINAL_PAYLOAD,
                    keccak256("SCOPED_POLICY_SNAPSHOT_MANIFEST_V2"),
                    d.targets[5],
                    original,
                    0,
                    payload
                );
                rows[i].schemaId =
                (family == Family.FAMILY_PROFILE ? DefinitionsV2.SCHEMA_ID : Definitions.SCHEMA_ID);
                rows[i].canonicalizationId =
                (family == Family.FAMILY_PROFILE ? DefinitionsV2.CANON_ID : Definitions.CANON_ID);
            } else if (at == 2) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("SCOPED_POLICY_NATIVE_SOURCE_FACTS_V2"),
                    d.targets[5],
                    original,
                    0,
                    abi.encode(f.snapshotSource)
                );
            } else if (at == 3) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1"),
                    d.targets[4],
                    c.rootRecordHash,
                    0,
                    abi.encode(f.contentRoot, f.contentRootBinding)
                );
            } else if (at == 4) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("STATIC_SELECTION_PLAN"),
                    sd.targets[6],
                    c.selectionId,
                    0,
                    abi.encode(f.snapshotSource.selection)
                );
            } else if (at == 5) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("SCOPED_POLICY_CONTENT_PLAN_V2"),
                    sd.targets[7],
                    c.checkpointHash,
                    0,
                    abi.encode(f.snapshotSource.content)
                );
            } else if (at == 6) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("SCOPED_POLICY_OUTPUT_MANIFEST_V2"),
                    sd.targets[8],
                    c.outputManifestRecord,
                    0,
                    abi.encode(f.snapshotSource.outputs)
                );
            } else if (at == 7) {
                rows[i].kind = T.Kind.ONCHAIN_OBJECT;
                rows[i].role = keccak256("COMPLETE_SCOPED_POLICY_OUTPUT_HASH_ROWS_V2");
                rows[i].source = sd.targets[8];
                rows[i].sourceRecord = c.outputManifestRecord;
                rows[i].algorithm = 1;
                rows[i].canonicalizationId =
                (family == Family.FAMILY_PROFILE ? OutputV2.CANON : OutputSchemas.CANON);
                rows[i].digest = abi.encodePacked(f.snapshotSource.outputs.manifestHash);
                rows[i].byteSize = f.snapshotSource.outputs.byteLength;
                rows[i].schemaId =
                (family == Family.FAMILY_PROFILE ? OutputV2.SCHEMA : OutputSchemas.SCHEMA);
                rows[i].objectHash = f.snapshotSource.outputs.artifactHash;
                rows[i].originalCoverageHash = f.snapshotSource.outputs.coverageHash;
            } else if (at == 8) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_COMPLETE_COORDINATOR_POLICIES_V2"),
                    sd.targets[10],
                    original,
                    0,
                    abi.encode(f.snapshotSource.entropy)
                );
            } else if (at < 21) {
                rows[i] = Items.runtime(
                    keccak256("SCOPED_INVENTORY_DEPENDENCY_RUNTIME"),
                    d.targets[at - 9],
                    original,
                    at - 9
                );
            } else if (at < 32) {
                IO.pin(sd.targets[at - 21], sd.codeHashes[at - 21]);
                rows[i] = Items.runtime(
                    keccak256("SCOPED_SNAPSHOT_DEPENDENCY_RUNTIME"),
                    sd.targets[at - 21],
                    original,
                    at - 21
                );
            } else if (at < 37) {
                rows[i] = Items.runtime(
                    keccak256("ORIGINAL_ARTIST_DEPENDENCY_RUNTIME"),
                    d.artistTargets[at - 32],
                    original,
                    at - 32
                );
            } else if (at == 37) {
                rows[i] = Items.runtime(
                    keccak256("ORIGINAL_ARTIST_CONTENT_OWNER_RUNTIME"),
                    d.artistContentOwner,
                    original,
                    0
                );
            } else if (at == 38) {
                rows[i] = Items.runtime(
                    keccak256("SCOPED_POLICY_SOURCE_FACTORY_RUNTIME_V2"),
                    f.snapshotSource.sourceFactory,
                    original,
                    0
                );
            } else if (at == 39) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("SCOPED_POLICY_SOURCE_FACTORY_DEPENDENCIES_V2"),
                    f.snapshotSource.sourceFactory,
                    original,
                    0,
                    abi.encode(factory)
                );
            } else if (at < 44) {
                rows[i] = Items.runtime(
                    keccak256("SCOPED_POLICY_FACTORY_DEPENDENCY_RUNTIME_V2"),
                    factory.targets[at - 40],
                    original,
                    at - 40
                );
            } else {
                uint256 index = (at - 44) / 2;
                address coordinator = f.snapshotSource.entropy.policies[index].coordinator;
                IO.pin(coordinator, f.snapshotSource.entropy.policies[index].indexedCodeHash);
                if ((at - 44) % 2 == 0) {
                    rows[i] = Items.runtime(
                        keccak256("ORIGINAL_COORDINATOR_RUNTIME"), coordinator, original, index
                    );
                } else {
                    rows[i] = Items.bytesItem(
                        T.Kind.NATIVE_BYTES,
                        keccak256("ORIGINAL_COORDINATOR_POLICY_V2"),
                        coordinator,
                        original,
                        index,
                        abi.encode(f.snapshotSource.entropy.policies[index])
                    );
                }
            }
        }
    }

    function _factory(S.Dependencies memory d, R.SourceFacts memory f)
        private
        view
        returns (Policies.Dependencies memory saved)
    {
        address factory = f.snapshotSource.sourceFactory;
        IO.pin(factory, f.snapshotSource.sourceFactoryCodeHash);
        bytes memory raw =
            IO.fixedRead(factory, abi.encodeCall(Factory.dependencies, ()), 352, d.readGas);
        saved = abi.decode(raw, (Policies.Dependencies));
        IO.canonical(factory, raw, abi.encode(saved));
        if (keccak256(raw) != f.snapshotSource.factoryDependenciesHash) {
            revert T.InventorySourceChanged();
        }
        Policies.validateDependencies(saved);
    }
}
