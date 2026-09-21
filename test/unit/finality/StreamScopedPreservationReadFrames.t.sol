// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicySnapshotFamiliesV2 as SnapshotFamilies
} from "../../../smart-contracts/domains/records/StreamPreservationPolicySnapshotFamiliesV2.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";

interface ScopedReadVm {
    function warp(uint256) external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
}
import {
    StreamFinalityScopedPreservationPolicyProviderMetadataV1 as M
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyProviderMetadataV1.sol";
import {
    StreamFinalityScopedPreservationPolicyMetadataPayloadV1 as Payload
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyMetadataPayloadV1.sol";
import {
    StreamFinalityScopedPreservationPolicyMetadataRootV1 as RootRead
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyMetadataRootV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as R
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderPinsV1 as Pins
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyProviderPinsV1.sol";
import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as SnapshotReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as PR
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Checkpoint
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Set
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamScopedPreservationPolicyReferencePublicationV1 as Reference
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as RefTypes
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    IStreamScopedPreservationPolicyRenderCriticalInventoryV1 as Inventory
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    IStreamScopedPreservationPolicyBundleArchiveCoverageV1 as Coverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyBundleArchiveCoverageV1.sol";
import {
    StreamRenderCriticalSourceTypes as Critical
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes as Archive
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamFinalityRouterEvidence as Evidence
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as Output1
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as Output2
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV2.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as Root1
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV2 as Root2
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

/// @dev Explicit typed dependency boundary. Every successful call authenticates the exact
/// calldata and delegate host; it does not model actual governance or publication authority.
contract ScopedReadReply {
    address public expectedCaller;
    mapping(bytes32 => bytes) private replies;
    mapping(bytes32 => bool) private present;

    function expect(address caller) external {
        expectedCaller = caller;
    }

    function reply(bytes memory input, bytes memory output) external {
        replies[keccak256(input)] = output;
        present[keccak256(input)] = true;
    }

    fallback() external {
        require(msg.sender == expectedCaller, "delegate caller");
        require(present[keccak256(msg.data)], "unconfigured read");
        bytes memory output = replies[keccak256(msg.data)];
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }
}

contract ScopedPinsFrame {
    function check(R.Config memory c) external view {
        R.requirePins(c);
    }
}

contract StreamScopedPreservationReadFramesTest {
    ScopedReadVm private constant vm =
        ScopedReadVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(bytes memory a, bytes memory b) private pure {
        require(keccak256(a) == keccak256(b), "full bytes");
    }

    function assertEq(bytes32 a, bytes32 b) private pure {
        require(a == b, "word");
    }
    bytes32 private constant V1 = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    bytes32 private constant V2 = keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
    M.Config private config;
    S.Dependencies private dependencies;
    S.Publication private publication;
    S.Receipt private receipt;
    S.Source private source;
    ScopedReadReply private snapshot;
    ScopedReadReply private router;
    ScopedReadReply private outputs;

    function setUp() public {
        vm.warp(1000);
        snapshot = new ScopedReadReply();
        router = new ScopedReadReply();
        outputs = new ScopedReadReply();
        snapshot.expect(address(this));
        router.expect(address(this));
        outputs.expect(address(this));
        config.snapshots = SnapshotReads.Dependencies(
            address(0x101),
            address(0x102),
            address(router),
            address(snapshot),
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            address(router).codehash,
            address(snapshot).codehash,
            block.chainid,
            250000,
            2000000
        );
        config.membership = address(0x103);
        config.membershipCodeHash = bytes32(uint256(3));
        dependencies.chainId = block.chainid;
        for (uint256 i; i < 11; ++i) {
            dependencies.targets[i] = address(uint160(0x200 + i));
            dependencies.codeHashes[i] = bytes32(i + 200);
        }
        dependencies.targets[4] = address(router);
        dependencies.targets[8] = address(outputs);
        dependencies.codeHashes[4] = address(router).codehash;
        dependencies.codeHashes[8] = address(outputs).codehash;
        publication.scope =
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 71, 0, keccak256("release"));
        publication.snapshotId = keccak256("snapshot");
        publication.expectedRevision = 4;
        publication.expectedSourceHash = keccak256("caller sentinel");
        publication.outputManifestRecord = keccak256("output record");
        publication.manifestURI = "ipfs://full-dynamic-snapshot";
        publication.effectiveAt = 800;
        source.scope = publication.scope;
        source.membership.tokenCount = 17;
        source.artist.artistId = keccak256("artist");
        source.artist.bindingGeneration = 9;
        source.artist.bindingHash = keccak256("artist binding");
        source.outputs.metadataRouter = address(router);
        source.outputs.contentRoot = keccak256("full content");
        source.outputs.manifestHash = keccak256("output manifest");
        source.outputs.outputRoot = keccak256("all output bytes");
        source.outputs.checkpointHash = keccak256("checkpoint");
        source.outputs.checkpointStateHash = keccak256("checkpoint state");
        source.outputs.inventoryHash = keccak256("inventory");
        source.outputs.policyChainHash = keccak256("full H");
        source.sourceFactory = address(0x401);
        source.sourceFactoryCodeHash = keccak256("factory code");
        source.factoryDependenciesHash = keccak256("factory deps");
        receipt.recordHash = keccak256("snapshot record");
        receipt.scopeSubject = keccak256("scope");
        receipt.revision = 4;
        receipt.chainHash = keccak256("snapshot chain");
        receipt.publisher = address(0x501);
        receipt.authorizationClass = 7;
        receipt.grantRevision = 2;
        receipt.displayAuthorizationClass = 8;
        receipt.displayGrantRevision = 6;
        receipt.recordedAt = 900;
        receipt.schemaHash = keccak256("schema");
        receipt.profileHash = keccak256("profile bytes");
        receipt.canonicalizationHash = keccak256("canon bytes");
    }

    function _payload(bytes32 family) private returns (bytes memory raw) {
        source.outputs.preservationProfile = family;
        source.content.preservationProfile = family;
        S.Source memory value = source;
        S.Publication memory p = publication;
        S.Receipt memory fields = receipt;
        bytes32 domain = family == V1
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1")
            : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2");
        bytes32 sourceDomain = family == V1
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1")
            : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2");
        fields.sourceHash = keccak256(
            abi.encode(
                sourceDomain,
                block.chainid,
                address(snapshot),
                dependencies.targets,
                dependencies.codeHashes,
                value
            )
        );
        receipt.sourceHash = fields.sourceHash;
        p.expectedSourceHash = 0;
        fields.recordHash = 0;
        fields.chainHash = 0;
        fields.manifestHash = 0;
        fields.manifestBytes = 0;
        fields.recordedAt = 0;
        raw = abi.encode(
            domain,
            block.chainid,
            address(snapshot),
            dependencies.targets,
            dependencies.codeHashes,
            p,
            fields,
            value
        );
        receipt.manifestHash = keccak256(raw);
        receipt.manifestBytes = uint32(raw.length);
        snapshot.reply(
            abi.encodeCall(Snapshot.snapshotPayload, (receipt.recordHash)), abi.encode(raw)
        );
    }

    function readPayload() external view returns (S.Source memory) {
        return Payload.read(
            config, dependencies, publication, receipt, source.outputs.preservationProfile
        );
    }

    function testFullPayloadBothFamiliesAndCallerMemoryRemainExact() public {
        for (uint256 i; i < 2; ++i) {
            bytes32 family = i == 0 ? V1 : V2;
            _payload(family);
            S.Publication memory p = publication;
            S.Receipt memory r = receipt;
            bytes32 before = keccak256(abi.encode(p, r));
            S.Source memory actual = Payload.read(config, dependencies, p, r, family);
            assertEq(abi.encode(actual), abi.encode(source));
            assertEq(keccak256(abi.encode(p, r)), before);
            vm.expectRevert(M.InvalidScopedProviderMetadata.selector);
            Payload.read(config, dependencies, p, r, family == V1 ? V2 : V1);
        }
    }

    function testPayloadHashCanonicalEnvelopeAndSourceFailuresRestore() public {
        bytes memory raw = _payload(V1);
        bytes32 hash = receipt.manifestHash;
        receipt.manifestHash = keccak256("wrong");
        vm.expectRevert(M.InvalidScopedProviderMetadata.selector);
        this.readPayload();
        receipt.manifestHash = hash;
        snapshot.reply(
            abi.encodeCall(Snapshot.snapshotPayload, (receipt.recordHash)),
            bytes.concat(abi.encode(raw), bytes32(0))
        );
        vm.expectRevert(M.InvalidScopedProviderMetadata.selector);
        this.readPayload();
        snapshot.reply(
            abi.encodeCall(Snapshot.snapshotPayload, (receipt.recordHash)), abi.encode(raw)
        );
        dependencies.codeHashes[10] ^= bytes32(uint256(1));
        vm.expectRevert(M.InvalidScopedProviderMetadata.selector);
        this.readPayload();
        dependencies.codeHashes[10] ^= bytes32(uint256(1));
        publication.manifestURI = "different full bytes";
        vm.expectRevert(M.InvalidScopedProviderMetadata.selector);
        this.readPayload();
        publication.manifestURI = "ipfs://full-dynamic-snapshot";
        assertEq(abi.encode(this.readPayload()), abi.encode(source));
    }

    function _binding(bytes32 family) private view returns (PR.Binding memory b) {
        b.profileId = family == V1 ? Root1.PROFILE : Root2.PROFILE;
        b.outputManifest = dependencies.targets[8];
        b.outputManifestCodeHash = dependencies.codeHashes[8];
        b.checkpoint = dependencies.targets[7];
        b.checkpointCodeHash = dependencies.codeHashes[7];
        b.checkpointHash = source.outputs.checkpointHash;
        b.checkpointStateHash = source.outputs.checkpointStateHash;
        b.entropySourceSet = dependencies.targets[10];
        b.entropySourceSetCodeHash = dependencies.codeHashes[10];
        b.inventoryHash = source.outputs.inventoryHash;
        b.policyChainHash = source.outputs.policyChainHash;
        b.outputRoot = source.outputs.outputRoot;
        if (family == V1) {
            b.outputSchemaHash = keccak256(Root1.document(Output1.SCHEMA));
            b.outputCanonicalizationHash = keccak256(Root1.document(Output1.CANON));
            b.leafSchemaHash = keccak256(Root1.document(Output1.LEAF_SCHEMA));
            b.rootSchemaHash = keccak256(Root1.document(Root1.ROOT_SCHEMA));
            b.rootCanonicalizationHash = keccak256(Root1.document(Root1.ROOT_CANON));
        } else {
            b.outputSchemaHash = keccak256(Root2.document(Output2.SCHEMA));
            b.outputCanonicalizationHash = keccak256(Root2.document(Output2.CANON));
            b.leafSchemaHash = keccak256(Root2.document(Output1.LEAF_SCHEMA));
            b.rootSchemaHash = keccak256(Root2.document(Root2.ROOT_SCHEMA));
            b.rootCanonicalizationHash = keccak256(Root2.document(Root2.ROOT_CANON));
        }
        b.sourceFactory = source.sourceFactory;
        b.sourceFactoryCodeHash = source.sourceFactoryCodeHash;
        b.factoryDependenciesHash = source.factoryDependenciesHash;
        b.snapshotSchemaHash = receipt.schemaHash;
        b.snapshotProfileHash = receipt.profileHash;
        b.snapshotCanonicalizationHash = receipt.canonicalizationHash;
        b.metadataRouter = address(router);
        b.preservationOutputProfile = family;
    }

    function _root(bytes32 family) private returns (Root.Record memory r, PR.Binding memory b) {
        _payload(family);
        b = _binding(family);
        r.publication = Root.Publication(
            publication.scope,
            bytes32(uint256(11)),
            receipt.recordHash,
            receipt.revision,
            "ipfs://root/full-bytes"
        );
        r.snapshotHost = address(snapshot);
        r.snapshotCodeHash = address(snapshot).codehash;
        r.snapshotManifestHash = receipt.manifestHash;
        r.snapshotSourceHash = receipt.sourceHash;
        r.contentRoot = source.outputs.contentRoot;
        r.leafCount = uint64(source.membership.tokenCount);
        r.outputManifestHash = source.outputs.manifestHash;
        r.artistId = source.artist.artistId;
        r.bindingGeneration = source.artist.bindingGeneration;
        r.bindingHash = source.artist.bindingHash;
        r.publisher = address(0x601);
        r.authorizationClass = 8;
        r.grantRevision = 4;
        r.routeHash = keccak256("route");
        bytes32 domain = family == V1
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V1")
            : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V2");
        r.stateHash = keccak256(
            abi.encode(domain, block.chainid, address(router), config.snapshots.core, r, b)
        );
        r.artistConsent = keccak256("original consumed consent");
        r.publishedAt = 950;
        router.reply(
            abi.encodeCall(Root.scopedContentRootHead, (publication.scope)),
            abi.encode(keccak256("root record"))
        );
        router.reply(
            abi.encodeCall(Root.scopedContentRootRecord, (keccak256("root record"))), abi.encode(r)
        );
        router.reply(
            abi.encodeCall(
                PR.scopedPreservationPolicyContentRootBinding, (keccak256("root record"))
            ),
            abi.encode(b)
        );
        router.reply(
            abi.encodeCall(Root.scopedTokenContentRoot, (publication.scope)),
            abi.encode(r.contentRoot, r.leafCount, Output1.LEAF_SCHEMA)
        );
        outputs.reply(
            abi.encodeCall(Outputs.manifestRecord, (publication.outputManifestRecord)),
            abi.encode(source.outputs)
        );
    }

    function readRoot() external view returns (bytes32, Root.Record memory, PR.Binding memory) {
        M.RootFacts memory f;
        f.snapshot = receipt;
        f.source = source;
        f.dependencies = dependencies;
        return RootRead.read(
            config,
            publication.scope,
            publication.outputManifestRecord,
            f,
            source.outputs.preservationProfile
        );
    }

    function testFullRootBindingAndIndependentStateHashBothFamilies() public {
        for (uint256 i; i < 2; ++i) {
            (Root.Record memory r, PR.Binding memory b) = _root(i == 0 ? V1 : V2);
            (bytes32 hash, Root.Record memory actual, PR.Binding memory binding_) = this.readRoot();
            assertEq(hash, keccak256("root record"));
            assertEq(abi.encode(actual, binding_), abi.encode(r, b));
        }
    }

    function testRootBindingAllWordsAndFutureTimeRefuseThenRestore() public {
        (Root.Record memory r, PR.Binding memory b) = _root(V1);
        bytes memory raw = abi.encode(b);
        for (uint256 i; i < 25; ++i) {
            bytes memory bad = abi.encode(b);
            assembly ("memory-safe") {
                let at := add(add(bad, 32), mul(i, 32))
                mstore(at, xor(mload(at), 1))
            }
            router.reply(
                abi.encodeCall(
                    PR.scopedPreservationPolicyContentRootBinding, (keccak256("root record"))
                ),
                bad
            );
            vm.expectRevert(M.InvalidScopedProviderMetadata.selector);
            this.readRoot();
        }
        router.reply(
            abi.encodeCall(
                PR.scopedPreservationPolicyContentRootBinding, (keccak256("root record"))
            ),
            raw
        );
        r.publishedAt = 1001;
        router.reply(
            abi.encodeCall(Root.scopedContentRootRecord, (keccak256("root record"))), abi.encode(r)
        );
        vm.expectRevert(M.InvalidScopedProviderMetadata.selector);
        this.readRoot();
        r.publishedAt = 950;
        router.reply(
            abi.encodeCall(Root.scopedContentRootRecord, (keccak256("root record"))), abi.encode(r)
        );
        (, Root.Record memory actual,) = this.readRoot();
        assertEq(abi.encode(actual), abi.encode(r));
    }

    function _reply(R.Config memory c, uint256 i, string memory selector, bytes memory value)
        private
    {
        ScopedReadReply(c.targets[i]).reply(abi.encodeWithSignature(selector), value);
    }

    function _pins(address caller) private returns (R.Config memory c) {
        c.chainId = block.chainid;
        c.readGas = 250000;
        c.componentSourceGas = 500000;
        c.sourceGas = 1000000;
        for (uint256 i; i < 22; ++i) {
            ScopedReadReply t = new ScopedReadReply();
            t.expect(caller);
            c.targets[i] = address(t);
            c.codeHashes[i] = address(t).codehash;
        }
        uint256[7] memory ids = [uint256(6), 7, 8, 9, 10, 18, 19];
        bytes4[7] memory faces = [
            type(Outputs).interfaceId,
            type(Checkpoint).interfaceId,
            type(Snapshot).interfaceId,
            type(Reference).interfaceId,
            type(Factory).interfaceId,
            type(Inventory).interfaceId,
            type(Coverage).interfaceId
        ];
        string[7] memory selectors = [
            "outputProfile()",
            "preservationPolicyProfile()",
            "scopedPreservationPolicySnapshotProfile()",
            "scopedPreservationPolicyReferenceProfile()",
            "scopedPolicyFactoryProfile()",
            "scopedPreservationPolicyInventoryProfile()",
            "scopedPreservationPolicyBundleArchiveProfile()"
        ];
        bytes32 content = keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1");
        bytes32[7] memory profiles = [
            content,
            content,
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1"),
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V1"),
            keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2"),
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_RENDER_CRITICAL_V1"),
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1")
        ];
        for (uint256 i; i < 7; ++i) {
            ScopedReadReply(c.targets[ids[i]])
                .reply(abi.encodeCall(IERC165.supportsInterface, (faces[i])), abi.encode(true));
            _reply(c, ids[i], selectors[i], abi.encode(profiles[i]));
        }
        uint256[29] memory from = [
            uint256(6),
            6,
            6,
            7,
            7,
            7,
            18,
            18,
            18,
            18,
            18,
            18,
            18,
            19,
            19,
            19,
            19,
            19,
            14,
            14,
            12,
            12,
            12,
            13,
            13,
            12,
            13,
            14,
            7
        ];
        string[29] memory methods = [
            "core()",
            "contentCheckpoint()",
            "artifactCoverage()",
            "core()",
            "metadataRouter()",
            "sourceFactory()",
            "core()",
            "metadataHost()",
            "metadataRouter()",
            "snapshots()",
            "referencePublisher()",
            "artifactCoverage()",
            "externalCoverage()",
            "core()",
            "metadataHost()",
            "renderCriticalInventory()",
            "artifactCoverage()",
            "externalCoverage()",
            "core()",
            "collectionMetadata()",
            "coreReads()",
            "metadataReads()",
            "coreFinalityAdapter()",
            "core()",
            "metadataHost()",
            "scopeEvidenceProvider()",
            "scopeEvidenceProvider()",
            "evidenceProvider()",
            "sourceFactoryCodeHash()"
        ];
        uint256[25] memory to = [
            uint256(0),
            7,
            20,
            0,
            2,
            10,
            0,
            1,
            2,
            8,
            9,
            20,
            21,
            0,
            1,
            18,
            20,
            21,
            0,
            1,
            0,
            1,
            14,
            0,
            1
        ];
        for (uint256 i; i < 25; ++i) {
            _reply(c, from[i], methods[i], abi.encode(c.targets[to[i]]));
        }
        for (uint256 i = 25; i < 28; ++i) {
            _reply(c, from[i], methods[i], abi.encode(caller));
        }
        _reply(c, 7, methods[28], abi.encode(c.codeHashes[10]));
        Critical.Dependencies memory inv;
        inv.chainId = block.chainid;
        inv.artistTargets[0] = c.targets[11];
        inv.artistCodeHashes[0] = c.codeHashes[11];
        inv.artistTargets[4] = c.targets[11];
        inv.artistCodeHashes[4] = c.codeHashes[11];
        uint256[12] memory invMap = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            inv.targets[i] = c.targets[invMap[i]];
            inv.codeHashes[i] = c.codeHashes[invMap[i]];
        }
        c.inventoryDependencyHash = keccak256(abi.encode(inv));
        _reply(c, 18, "dependencies()", abi.encode(inv));
        _reply(c, 18, "dependencyHash()", abi.encode(c.inventoryDependencyHash));
        Archive.Dependencies memory archive;
        archive.chainId = block.chainid;
        uint256[6] memory archiveMap = [uint256(0), 1, 18, 20, 21, 11];
        for (uint256 i; i < 6; ++i) {
            archive.targets[i] = c.targets[archiveMap[i]];
            archive.codeHashes[i] = c.codeHashes[archiveMap[i]];
        }
        _reply(c, 19, "dependencies()", abi.encode(archive));
        _reply(c, 19, "dependencyHash()", abi.encode(keccak256(abi.encode(archive))));
        S.Dependencies memory snaps;
        snaps.chainId = block.chainid;
        uint256[9] memory sf = [uint256(0), 1, 2, 3, 4, 5, 7, 8, 9];
        uint256[9] memory st = [uint256(0), 1, 4, 5, 2, 3, 7, 6, 20];
        for (uint256 i; i < 9; ++i) {
            snaps.targets[sf[i]] = c.targets[st[i]];
            snaps.codeHashes[sf[i]] = c.codeHashes[st[i]];
        }
        ScopedReadReply selection = new ScopedReadReply();
        ScopedReadReply set = new ScopedReadReply();
        selection.expect(caller);
        set.expect(caller);
        snaps.targets[6] = address(selection);
        snaps.codeHashes[6] = address(selection).codehash;
        snaps.targets[10] = address(set);
        snaps.codeHashes[10] = address(set).codehash;
        _reply(c, 8, "dependencies()", abi.encode(snaps));
        _reply(c, 7, "selectionCheckpoint()", abi.encode(address(selection)));
        _reply(c, 7, "entropySourceSet()", abi.encode(address(set)));
        set.reply(
            abi.encodeCall(IERC165.supportsInterface, (type(Set).interfaceId)), abi.encode(true)
        );
        set.reply(
            abi.encodeWithSignature("SOURCE_SET_PROFILE()"),
            abi.encode(keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"))
        );
        set.reply(abi.encodeWithSignature("factory()"), abi.encode(c.targets[10]));
        set.reply(abi.encodeWithSignature("core()"), abi.encode(c.targets[0]));
        Policies.Dependencies memory policies;
        policies.chainId = block.chainid;
        uint256[4] memory pm = [uint256(0), 1, 3, 20];
        for (uint256 i; i < 4; ++i) {
            policies.targets[i] = c.targets[pm[i]];
            policies.codeHashes[i] = c.codeHashes[pm[i]];
        }
        _reply(c, 10, "dependencies()", abi.encode(policies));
        _reply(c, 7, "factoryDependenciesHash()", abi.encode(keccak256(abi.encode(policies))));
        RefTypes.Dependencies memory refs;
        refs.chainId = block.chainid;
        uint256[7] memory rm = [uint256(0), 1, 4, 5, 2, 8, 21];
        for (uint256 i; i < 7; ++i) {
            refs.targets[i] = c.targets[rm[i]];
            refs.codeHashes[i] = c.codeHashes[rm[i]];
        }
        _reply(c, 9, "dependencies()", abi.encode(refs));
    }

    function testPinsCompleteTypedGraphAndDelegateHostIdentity() public {
        R.Config memory c = _pins(address(this));
        bytes32 hash = keccak256(abi.encode(c));
        Pins.requirePins(c);
        R.requirePins(c);
        assertEq(keccak256(abi.encode(c)), hash);
        ScopedPinsFrame other = new ScopedPinsFrame();
        R.Config memory d = _pins(address(other));
        other.check(d);
        _reply(d, 14, "evidenceProvider()", abi.encode(address(this)));
        vm.expectRevert(abi.encodeWithSelector(R.NativeProviderDependency.selector, d.targets[14]));
        other.check(d);
        _reply(d, 14, "evidenceProvider()", abi.encode(address(other)));
        other.check(d);
    }

    function testPinsConfigurationRuntimeProfileAndReserveOrder() public {
        R.Config memory c = _pins(address(this));
        uint256 chain = c.chainId;
        c.chainId++;
        c.codeHashes[0] = 0;
        vm.expectRevert(R.NativeProviderConfiguration.selector);
        R.requirePins(c);
        c.chainId = chain;
        vm.expectRevert(abi.encodeWithSelector(R.NativeProviderDependency.selector, c.targets[0]));
        R.requirePins(c);
        c.codeHashes[0] = c.targets[0].codehash;
        _reply(c, 6, "outputProfile()", abi.encode(bytes32(0)));
        vm.expectRevert(abi.encodeWithSelector(R.NativeProviderDependency.selector, c.targets[6]));
        R.requirePins(c);
        _reply(
            c,
            6,
            "outputProfile()",
            abi.encode(keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1"))
        );
        R.requirePins(c);
        c.sourceGas = c.componentSourceGas + c.componentSourceGas / 63 + 100000;
        vm.expectRevert(R.NativeProviderConfiguration.selector);
        R.requirePins(c);
        c.sourceGas++;
        R.requirePins(c);
    }

    function _graph(bytes32 family) private returns (M.RootFacts memory expected) {
        for (uint256 i; i < 11; ++i) {
            ScopedReadReply t = new ScopedReadReply();
            t.expect(address(this));
            dependencies.targets[i] = address(t);
            dependencies.codeHashes[i] = address(t).codehash;
        }
        dependencies.targets[4] = address(router);
        dependencies.codeHashes[4] = address(router).codehash;
        dependencies.targets[8] = address(outputs);
        dependencies.codeHashes[8] = address(outputs).codehash;
        config.snapshots.core = dependencies.targets[0];
        config.snapshots.coreCodeHash = dependencies.codeHashes[0];
        config.snapshots.metadata = dependencies.targets[1];
        config.snapshots.metadataCodeHash = dependencies.codeHashes[1];
        config.membership = dependencies.targets[5];
        config.membershipCodeHash = dependencies.codeHashes[5];
        ScopedReadReply membership = ScopedReadReply(config.membership);
        membership.reply(abi.encodeWithSignature("core()"), abi.encode(config.snapshots.core));
        membership.reply(
            abi.encodeWithSignature("metadataHost()"), abi.encode(config.snapshots.metadata)
        );
        router.reply(
            abi.encodeCall(IERC165.supportsInterface, (type(PR).interfaceId)), abi.encode(true)
        );
        snapshot.reply(
            abi.encodeCall(IERC165.supportsInterface, (type(Snapshot).interfaceId)),
            abi.encode(true)
        );
        snapshot.reply(abi.encodeCall(Snapshot.core, ()), abi.encode(config.snapshots.core));
        snapshot.reply(
            abi.encodeCall(Snapshot.metadataHost, ()), abi.encode(config.snapshots.metadata)
        );
        snapshot.reply(
            abi.encodeCall(Snapshot.scopedPreservationPolicySnapshotProfile, ()),
            abi.encode(
                family == V1
                    ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1")
                    : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2")
            )
        );
        snapshot.reply(abi.encodeCall(Snapshot.dependencies, ()), abi.encode(dependencies));
        ScopedReadReply factory = new ScopedReadReply();
        factory.expect(address(this));
        source.sourceFactory = address(factory);
        source.sourceFactoryCodeHash = address(factory).codehash;
        Policies.Dependencies memory policies;
        policies.chainId = block.chainid;
        policies.targets = [
            config.snapshots.core,
            config.snapshots.metadata,
            config.membership,
            dependencies.targets[9]
        ];
        policies.codeHashes = [
            config.snapshots.coreCodeHash,
            config.snapshots.metadataCodeHash,
            config.membershipCodeHash,
            dependencies.codeHashes[9]
        ];
        source.factoryDependenciesHash = keccak256(abi.encode(policies));
        factory.reply(
            abi.encodeCall(IERC165.supportsInterface, (type(Factory).interfaceId)), abi.encode(true)
        );
        factory.reply(
            abi.encodeCall(Factory.scopedPolicyFactoryProfile, ()),
            abi.encode(keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2"))
        );
        factory.reply(abi.encodeCall(Factory.dependencies, ()), abi.encode(policies));
        ScopedReadReply(dependencies.targets[10])
            .reply(abi.encodeWithSignature("factory()"), abi.encode(address(factory)));
        ScopedReadReply(dependencies.targets[7])
            .reply(abi.encodeWithSignature("sourceFactory()"), abi.encode(address(factory)));
        ScopedReadReply(dependencies.targets[7])
            .reply(
                abi.encodeWithSignature("factoryDependenciesHash()"),
                abi.encode(source.factoryDependenciesHash)
            );
        receipt.revision = 1;
        publication.expectedRevision = 0;
        publication.expectedHead = 0;
        receipt.predecessor = 0;
        receipt.scopeSubject = StreamMetadataSubjects.scopeSubject(
            block.chainid, config.snapshots.core, publication.scope
        );
        publication.coordinatorInventoryPlan = keccak256("coordinator plan");
        publication.reasonHash = keccak256("reason");
        bytes32[3] memory hashes = SnapshotFamilies.hashes(family, true);
        receipt.schemaHash = hashes[0];
        receipt.profileHash = hashes[1];
        receipt.canonicalizationHash = hashes[2];
        _payload(family);
        publication.expectedSourceHash = receipt.sourceHash;
        S.Receipt memory committed = receipt;
        committed.recordHash = 0;
        committed.chainHash = 0;
        bytes32 domain = family == V1
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V1")
            : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V2");
        receipt.recordHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(snapshot),
                config.snapshots.core,
                config.snapshots.metadata,
                publication,
                committed
            )
        );
        (Root.Record memory record_, PR.Binding memory binding_) = _root(family);
        snapshot.reply(
            abi.encodeCall(Snapshot.currentSnapshot, (publication.scope)), abi.encode(receipt)
        );
        snapshot.reply(
            abi.encodeCall(Snapshot.snapshotRecord, (receipt.recordHash)),
            abi.encode(publication, receipt)
        );
        expected =
            M.RootFacts(keccak256("root record"), record_, binding_, receipt, source, dependencies);
    }

    function testOriginalMetadataEntryReturnsAllFactsAndKeepsCurrentBranch() public {
        for (uint256 i; i < 2; ++i) {
            bytes32 family = i == 0 ? V1 : V2;
            M.RootFacts memory expected = _graph(family);
            M.RootFacts memory historical = M.rootFacts(config, publication.scope, false, family);
            assertEq(abi.encode(historical), abi.encode(expected));
            vm.expectRevert(
                abi.encodeWithSelector(
                    Evidence.RouterEvidenceRead.selector,
                    address(snapshot),
                    Snapshot.requireCurrent.selector
                )
            );
            M.rootFacts(config, publication.scope, true, family);
            snapshot.reply(
                abi.encodeCall(
                    Snapshot.requireCurrent,
                    (publication.scope, receipt.recordHash, receipt.revision)
                ),
                abi.encode(receipt)
            );
            S.Lock memory unlocked;
            snapshot.reply(
                abi.encodeCall(Snapshot.snapshotLock, (publication.scope)), abi.encode(unlocked)
            );
            M.RootFacts memory current = M.rootFacts(config, publication.scope, true, family);
            assertEq(abi.encode(current), abi.encode(expected));
            (bytes32 value, uint64 count, bytes32 schema) =
                M.root(config, publication.scope, family);
            assertEq(
                abi.encode(value, count, schema),
                abi.encode(
                    expected.record.contentRoot, expected.record.leafCount, Output1.LEAF_SCHEMA
                )
            );
        }
    }
}
