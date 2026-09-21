// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicySnapshotSourceReadsV1 as Collection
} from "../../../smart-contracts/domains/records/StreamPreservationPolicySnapshotSourceReadsV1.sol";
import {
    StreamScopedPreservationPolicySnapshotSourceReadsV1 as Scoped
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotSourceReadsV1.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as C
} from "../../../smart-contracts/interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopeMembershipFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    IStreamMetadataServingFacts as Serving
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamCollectionMetadataV1 as Metadata
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamMetadataRouter as Router
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    IStreamContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamPreservationPolicyContentRootPublicationV1 as RootProfile
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamFinalityScopeMembership as Membership
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Entropy
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropySourceFactory as FactoryBase
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityCurrentEntropyRoute,
    StreamFinalityCurrentComponentRoute
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    IStreamArtworkScopedFinalityComponent
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    IStreamFinalityCoordinatorInventory as Inventory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCoordinatorInventory.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamFinalityCoordinatorPolicyV2
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import {
    StreamEntropyPolicyConsumerTypes as Policy
} from "../../../smart-contracts/interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import {
    StreamMetadataRecoveryRoutes as Routes
} from "../../../smart-contracts/domains/metadata/StreamMetadataRecoveryRoutes.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicyContentRootSchemasV1 as R1
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationPolicyContentRootSchemasV2 as R2
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as O1
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as O2
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV2.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

interface SourceWorkerVm {
    function expectRevert(bytes calldata) external;
    function expectCall(address, bytes calldata, uint64) external;
}

/// @dev Exact typed read boundary. It produces no admission, policy or Artist authority.
/// Every successful source read must retain the original calling host and explicit gas cap.
contract SnapshotSourceWorkerReadTable {
    struct Answer {
        bytes data;
        bool known;
        bool fail;
        uint256 minimumGas;
        uint256 maximumGas;
    }
    mapping(bytes32 => Answer) private _answers;
    address private _caller;

    constructor(address caller) {
        _caller = caller;
    }

    function set(bytes memory input, bytes memory output) external {
        Answer storage a = _answers[keccak256(input)];
        a.data = output;
        a.known = true;
    }

    function fail(bytes memory input, bool value) external {
        _answers[keccak256(input)].fail = value;
    }

    function gasWindow(bytes memory input, uint256 minimum, uint256 maximum) external {
        Answer storage a = _answers[keccak256(input)];
        a.minimumGas = minimum;
        a.maximumGas = maximum;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        uint256 available = gasleft();
        require(msg.sender == _caller, "source worker changed caller");
        Answer storage a = _answers[keccak256(input)];
        require(a.known && !a.fail, "unavailable typed source");
        require(
            a.maximumGas == 0 || (available >= a.minimumGas && available <= a.maximumGas),
            "changed read cap"
        );
        return a.data;
    }
}

/// @notice Executes both actual facade overloads and their fixed workers over explicit source
/// boundaries. Full returned tuples and literal source/root preimages are independent oracles.
/// This is not a producer, publication/op17, governance, archival or current-stack acceptance test.
contract StreamPreservationSnapshotSourceWorkersTest {
    SourceWorkerVm private constant vm =
        SourceWorkerVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant READ_GAS = 400000;
    uint256 private constant SOURCE_GAS = 3000000;
    uint256 private constant INVENTORY_GAS = 5000000;

    struct Fixture {
        C.Dependencies d;
        C.Publication p;
        C.Source expected;
        S.Publication scopedPublication;
        S.Source scopedExpected;
        bytes32 family;
        address factory;
        Policies.Dependencies factoryDependencies;
    }

    function _table(address target) private pure returns (SnapshotSourceWorkerReadTable) {
        return SnapshotSourceWorkerReadTable(target);
    }

    function _set(address target, bytes memory input, bytes memory output) private {
        _table(target).set(input, output);
    }

    function _word(address target, string memory signature, bytes32 value) private {
        _set(target, abi.encodeWithSignature(signature), abi.encode(value));
    }

    function _address(address target, string memory signature, address value) private {
        _word(target, signature, bytes32(uint256(uint160(value))));
    }

    function _interfaces(address target, bytes4 capability) private {
        _set(target, abi.encodeCall(IERC165.supportsInterface, (capability)), abi.encode(true));
        _set(
            target,
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
            abi.encode(true)
        );
        _set(
            target,
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
            abi.encode(false)
        );
    }

    function _module(Fixture memory f, uint256 at, bytes32 kind, bytes4 capability, address modules)
        private
    {
        Routes.Pointer memory pointer = Routes.Pointer(
            f.d.targets[at],
            f.d.codeHashes[at],
            false,
            kind,
            capability,
            modules,
            1,
            keccak256(abi.encode(kind, "module")),
            keccak256(abi.encode(kind, "deployment")),
            7
        );
        _set(
            f.d.targets[0],
            abi.encodeWithSignature("getSatellitePointer(bytes32)", kind),
            abi.encode(pointer)
        );
        _interfaces(f.d.targets[at], capability);
        _word(f.d.targets[at], "streamModuleType()", kind);
        _set(
            f.d.targets[at],
            abi.encodeWithSignature("streamModuleInterfaceId()"),
            abi.encode(capability)
        );
        _set(
            modules,
            abi.encodeWithSignature(
                "isModuleEligible(address,bytes32,bytes4)", f.d.targets[at], kind, capability
            ),
            abi.encode(true)
        );
    }

    function _fixture(bool scoped, bool v2, StreamFinalityScopeType kind)
        private
        returns (Fixture memory f)
    {
        f.family = v2 ? Profiles.FAMILY_PROFILE : Profiles.ORIGINAL_PROFILE;
        for (uint256 i; i < 11; ++i) {
            f.d.targets[i] = address(new SnapshotSourceWorkerReadTable(address(this)));
            f.d.codeHashes[i] = f.d.targets[i].codehash;
        }
        f.d.chainId = block.chainid;
        f.d.readGas = READ_GAS;
        f.d.sourceGas = SOURCE_GAS;
        f.d.inventoryGas = INVENTORY_GAS;
        address modules = address(new SnapshotSourceWorkerReadTable(address(this)));
        Routes.Pointer memory registry;
        registry.target = modules;
        registry.codeHash = modules.codehash;
        _set(
            f.d.targets[0],
            abi.encodeWithSignature("getSatellitePointer(bytes32)", keccak256("MODULE_REGISTRY")),
            abi.encode(registry)
        );
        _module(f, 1, keccak256("COLLECTION_METADATA"), type(Metadata).interfaceId, modules);
        _module(f, 4, keccak256("METADATA_ROUTER"), type(Router).interfaceId, modules);
        for (uint256 i = 1; i < 11; ++i) {
            _address(f.d.targets[i], "core()", f.d.targets[0]);
        }
        _address(f.d.targets[1], "schemaRegistry()", f.d.targets[2]);
        _address(f.d.targets[1], "chunkStore()", f.d.targets[3]);
        _address(f.d.targets[2], "chunkStore()", f.d.targets[3]);
        _address(f.d.targets[5], "metadataHost()", f.d.targets[1]);
        _address(f.d.targets[6], "metadataHost()", f.d.targets[1]);
        _address(f.d.targets[6], "metadataRouter()", f.d.targets[4]);
        _address(f.d.targets[6], "scopeMembership()", f.d.targets[5]);
        _address(f.d.targets[7], "metadataRouter()", f.d.targets[4]);
        _address(f.d.targets[7], "selectionCheckpoint()", f.d.targets[6]);
        _address(f.d.targets[7], "entropySourceSet()", f.d.targets[10]);
        _address(f.d.targets[8], "contentCheckpoint()", f.d.targets[7]);
        _address(f.d.targets[8], "artifactCoverage()", f.d.targets[9]);
        _address(f.d.targets[8], "schemaRegistry()", f.d.targets[2]);
        _address(f.d.targets[9], "schemaRegistry()", f.d.targets[2]);
        _address(f.d.targets[9], "chunkStore()", f.d.targets[3]);
        _word(f.d.targets[1], "coreCodeHash()", f.d.codeHashes[0]);
        _word(f.d.targets[1], "schemaRegistryCodeHash()", f.d.codeHashes[2]);
        _word(f.d.targets[1], "chunkStoreCodeHash()", f.d.codeHashes[3]);
        _word(f.d.targets[10], "coreCodeHash()", f.d.codeHashes[0]);
        _word(f.d.targets[7], "entropySourceSetCodeHash()", f.d.codeHashes[10]);
        _interfaces(f.d.targets[7], type(Content).interfaceId);
        _interfaces(f.d.targets[8], type(Outputs).interfaceId);
        _interfaces(f.d.targets[10], type(Entropy).interfaceId);
        bytes32 checkpointProfile = scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1");
        _word(
            f.d.targets[7],
            "preservationPolicyProfile()",
            v2
                ? (scoped
                        ? Profiles.SCOPED_CHECKPOINT_PROFILE
                        : Profiles.COLLECTION_CHECKPOINT_PROFILE)
                : checkpointProfile
        );
        _word(
            f.d.targets[8],
            "outputProfile()",
            v2 ? Profiles.OUTPUT_MANIFEST_PROFILE : checkpointProfile
        );
        _word(f.d.targets[7], "preservationOutputProfile()", f.family);
        _word(
            f.d.targets[10],
            "SOURCE_SET_PROFILE()",
            keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
        );

        f.p.scope = StreamFinalityScope(
            kind,
            41,
            kind == StreamFinalityScopeType.TOKEN ? 83 : 0,
            kind == StreamFinalityScopeType.RELEASE || kind == StreamFinalityScopeType.SEASON
                ? keccak256(abi.encode(kind, "scope"))
                : bytes32(0)
        );
        f.p.snapshotId = keccak256("snapshot id");
        f.p.expectedHead = keccak256("prior snapshot");
        f.p.expectedRevision = 9;
        f.p.outputManifestRecord = keccak256("output receipt");
        f.p.coordinatorInventoryPlan = keccak256("current inventory plan");
        f.p.expectedSourceHash = keccak256("not used to invent source facts");
        f.p.manifestURI = "ipfs://snapshot-independent-source-fixture";
        f.p.effectiveAt = 401;
        f.p.reasonHash = keccak256("reason");
        f.expected.scope = f.p.scope;
        uint64 count = kind == StreamFinalityScopeType.TOKEN ? 1 : 3;
        bytes32 subject = _subject(f.d, f.p.scope);
        f.expected.membership = StreamScopeMembershipFacts(
            subject,
            scoped && count != 1 ? keccak256("scope manifest") : bytes32(0),
            scoped && count != 1 ? keccak256("source membership record") : bytes32(0),
            count,
            scoped ? keccak256("member list") : bytes32(0),
            keccak256("complete membership"),
            scoped ? 0 : count,
            scoped ? bytes32(0) : keccak256("inventory prefix")
        );
        f.expected.artist = Serving.ArtistPresentation(
            true,
            address(0xA771),
            keccak256("artist runtime"),
            keccak256("artist id"),
            17,
            keccak256("artist binding"),
            address(0xA11CE),
            keccak256("identity receipt"),
            keccak256("acceptance receipt"),
            311,
            313,
            keccak256("artist snapshot")
        );
        f.expected.selection = Selection.Plan(
            f.p.scope,
            f.expected.membership.membershipHash,
            keccak256("collection state"),
            count,
            count,
            keccak256("selection root")
        );
        f.expected.entropy.planId = f.p.coordinatorInventoryPlan;
        f.expected.entropy.inventoryHash = keccak256("original inventory");
        f.expected.entropy.policyChainHash = keccak256("original policy chain");
        f.expected.entropy.policyCount = count == 1 ? 1 : 2;
        f.expected.entropy.allFrozen = true;
        f.expected.entropy.policies =
            new StreamFinalityCoordinatorPolicyV2[](f.expected.entropy.policyCount);
        for (uint256 i; i < f.expected.entropy.policyCount; ++i) {
            bytes32 tag = keccak256(abi.encode("distinct policy", i));
            f.expected.entropy.policies[i] = StreamFinalityCoordinatorPolicyV2(
                address(uint160(0xC001 + i)),
                keccak256(abi.encode(tag, "runtime")),
                i,
                true,
                tag,
                keccak256(abi.encode(tag, "manifest")),
                keccak256(abi.encode(tag, "schema")),
                keccak256(abi.encode(tag, "deployment")),
                keccak256(abi.encode(tag, "policy")),
                address(uint160(0xD001 + i)),
                uint32(31 + i),
                keccak256(abi.encode(tag, "salt")),
                keccak256(abi.encode(tag, "component")),
                true,
                Policy.Policy(
                    true,
                    true,
                    true,
                    uint8(1 + i),
                    uint8(2 + i),
                    uint8(3 + i),
                    uint64(71 + i),
                    uint32(91 + i),
                    keccak256(abi.encode(tag, "native policy")),
                    keccak256(abi.encode(tag, "content")),
                    keccak256(abi.encode(tag, "action")),
                    keccak256(abi.encode(tag, "consent"))
                )
            );
        }
        f.expected.content = Content.Plan(
            keccak256("selection id"),
            keccak256(abi.encode(f.expected.selection)),
            f.expected.entropy.inventoryHash,
            f.expected.entropy.policyChainHash,
            f.p.scope,
            count,
            count,
            keccak256("leaf chain"),
            keccak256("content root"),
            keccak256("output root"),
            f.family
        );
        f.expected.outputs = Outputs.Manifest(
            keccak256("checkpoint hash"),
            keccak256(abi.encode(f.expected.content)),
            f.d.targets[10],
            f.expected.entropy.inventoryHash,
            f.expected.entropy.policyChainHash,
            f.d.targets[4],
            f.family,
            keccak256("archive artifact"),
            keccak256("coverage receipt"),
            f.expected.artist.artistId,
            f.expected.content.contentRoot,
            f.expected.content.outputRoot,
            keccak256("manifest bytes"),
            f.p.scope,
            count,
            1831
        );
        _saveCommon(f);
        if (scoped) _factory(f);
        else _root(f, v2);
    }

    function _subject(C.Dependencies memory d, StreamFinalityScope memory scope)
        private
        pure
        returns (bytes32)
    {
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_SUBJECT_COLLECTION_V1"),
                    d.chainId,
                    d.targets[0],
                    scope.collectionId
                )
            );
        }
        if (scope.scopeType == StreamFinalityScopeType.TOKEN) {
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_SUBJECT_TOKEN_V1"), d.chainId, d.targets[0], scope.tokenId
                )
            );
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_SCOPE_V1"),
                d.chainId,
                d.targets[0],
                scope.collectionId,
                uint8(scope.scopeType),
                scope.scopeId
            )
        );
    }

    function _saveCommon(Fixture memory f) private {
        _set(
            f.d.targets[5],
            abi.encodeCall(Membership.requireScopeMembership, (f.p.scope)),
            abi.encode(f.expected.membership)
        );
        _set(
            f.d.targets[4],
            abi.encodeCall(Serving.artistPresentation, (f.p.scope.collectionId)),
            abi.encode(f.expected.artist)
        );
        _set(
            f.d.targets[8],
            abi.encodeCall(
                Outputs.requireCurrentManifest,
                (f.p.outputManifestRecord, f.expected.artist.artistId)
            ),
            abi.encode(f.expected.outputs)
        );
        _set(
            f.d.targets[7],
            abi.encodeCall(Content.checkpoint, (f.expected.outputs.checkpointHash)),
            abi.encode(f.expected.content)
        );
        _set(
            f.d.targets[6],
            abi.encodeCall(Selection.checkpoint, (f.expected.content.selectionId)),
            abi.encode(f.expected.selection)
        );
        _set(f.d.targets[10], abi.encodeCall(Entropy.requireCurrentSourceSet, ()), "");
        _set(f.d.targets[10], abi.encodeCall(Entropy.sourceScope, ()), abi.encode(f.p.scope));
        _set(
            f.d.targets[10],
            abi.encodeCall(Entropy.scopeMembershipFacts, ()),
            abi.encode(f.expected.membership)
        );
        _word(f.d.targets[10], "inventoryPlan()", f.expected.entropy.planId);
        _word(f.d.targets[10], "originalInventoryHash()", f.expected.entropy.inventoryHash);
        _word(f.d.targets[10], "originalPolicyChainHash()", f.expected.entropy.policyChainHash);
        _word(f.d.targets[10], "sourceCount()", bytes32(f.expected.entropy.policyCount));
        for (uint256 i; i < f.expected.entropy.policyCount; ++i) {
            _set(
                f.d.targets[10],
                abi.encodeCall(Entropy.sourcePolicyAt, (i)),
                abi.encode(f.expected.entropy.policies[i])
            );
        }
    }

    function _root(Fixture memory f, bool v2) private {
        f.expected.root = Root.Record(
            Root.Publication(
                f.p.scope.collectionId,
                keccak256("root predecessor"),
                f.p.outputManifestRecord,
                "ipfs://complete-root-manifest/nonempty/dynamic-tail"
            ),
            f.expected.outputs.contentRoot,
            f.expected.outputs.tokenCount,
            f.expected.outputs.manifestHash,
            f.expected.artist.artistId,
            f.expected.artist.bindingGeneration,
            f.expected.artist.bindingHash,
            address(0xF001),
            8,
            23,
            keccak256("root route"),
            keccak256("root state"),
            keccak256("original artist consent"),
            337
        );
        f.expected.rootBinding = RootProfile.Binding(
            v2 ? R2.PROFILE : R1.PROFILE,
            f.d.targets[8],
            f.d.codeHashes[8],
            f.d.targets[7],
            f.d.codeHashes[7],
            f.expected.outputs.checkpointHash,
            f.expected.outputs.checkpointStateHash,
            f.d.targets[10],
            f.d.codeHashes[10],
            f.expected.entropy.inventoryHash,
            f.expected.entropy.policyChainHash,
            f.expected.outputs.outputRoot,
            v2 ? R2.definitionHash(O2.SCHEMA) : R1.definitionHash(O1.SCHEMA),
            v2 ? R2.definitionHash(O2.CANON) : R1.definitionHash(O1.CANON),
            v2 ? R2.definitionHash(O2.LEAF_SCHEMA) : R1.definitionHash(O1.LEAF_SCHEMA),
            v2 ? R2.definitionHash(R2.ROOT_SCHEMA) : R1.definitionHash(R1.ROOT_SCHEMA),
            v2 ? R2.definitionHash(R2.ROOT_CANON) : R1.definitionHash(R1.ROOT_CANON),
            f.d.targets[4],
            f.family
        );
        f.p.contentRootRecord = keccak256(
            abi.encode(
                v2
                    ? keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2")
                    : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"),
                f.d.chainId,
                f.d.targets[4],
                f.expected.root,
                f.expected.rootBinding
            )
        );
        _set(
            f.d.targets[4],
            abi.encodeCall(Root.collectionContentRootHead, (f.p.scope.collectionId)),
            abi.encode(f.p.contentRootRecord)
        );
        _set(
            f.d.targets[4],
            abi.encodeCall(Root.contentRootRecord, (f.p.contentRootRecord)),
            abi.encode(f.expected.root)
        );
        _set(
            f.d.targets[4],
            abi.encodeCall(
                RootProfile.preservationPolicyContentRootBinding, (f.p.contentRootRecord)
            ),
            abi.encode(f.expected.rootBinding)
        );
    }

    function _factory(Fixture memory f) private {
        f.factory = address(new SnapshotSourceWorkerReadTable(address(this)));
        address inventory = address(new SnapshotSourceWorkerReadTable(address(this)));
        f.factoryDependencies = Policies.Dependencies(
            [f.d.targets[0], f.d.targets[1], f.d.targets[5], inventory],
            [f.d.codeHashes[0], f.d.codeHashes[1], f.d.codeHashes[5], inventory.codehash],
            f.d.chainId,
            uint32(READ_GAS),
            uint32(INVENTORY_GAS)
        );
        _interfaces(f.d.targets[0], 0x80ac58cd);
        _interfaces(f.d.targets[5], type(Membership).interfaceId);
        _interfaces(inventory, type(Inventory).interfaceId);
        _address(inventory, "core()", f.d.targets[0]);
        _address(inventory, "scopeMembershipHost()", f.d.targets[5]);
        _word(inventory, "deploymentChainId()", bytes32(f.d.chainId));
        _word(inventory, "coreCodeHash()", f.d.codeHashes[0]);
        _word(inventory, "scopeMembershipCodeHash()", f.d.codeHashes[5]);
        _address(f.d.targets[10], "factory()", f.factory);
        _address(f.d.targets[7], "sourceFactory()", f.factory);
        _word(f.d.targets[7], "sourceFactoryCodeHash()", f.factory.codehash);
        _word(
            f.d.targets[7],
            "factoryDependenciesHash()",
            keccak256(abi.encode(f.factoryDependencies))
        );
        _interfaces(f.factory, type(Factory).interfaceId);
        _interfaces(f.factory, type(IStreamFinalityCurrentEntropyRoute).interfaceId);
        _word(
            f.factory,
            "scopedPolicyFactoryProfile()",
            keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        );
        _set(f.factory, abi.encodeCall(Factory.dependencies, ()), abi.encode(f.factoryDependencies));
        _address(f.factory, "core()", f.d.targets[0]);
        _address(f.factory, "metadataHost()", f.d.targets[1]);
        _address(f.factory, "scopeMembershipHost()", f.d.targets[5]);
        _address(f.factory, "coordinatorInventory()", inventory);
        _set(
            f.factory,
            abi.encodeCall(FactoryBase.currentInventoryPlan, (f.p.scope)),
            abi.encode(f.p.coordinatorInventoryPlan)
        );
        _set(
            f.factory,
            abi.encodeCall(FactoryBase.sourceSetForPlan, (f.p.coordinatorInventoryPlan)),
            abi.encode(f.d.targets[10], f.d.codeHashes[10])
        );
        _set(
            f.factory,
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (f.p.scope)),
            abi.encode(
                StreamFinalityCurrentComponentRoute(
                    StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR,
                    f.d.targets[10],
                    type(IStreamArtworkScopedFinalityComponent).interfaceId,
                    f.d.codeHashes[10]
                )
            )
        );
        f.scopedPublication = S.Publication(
            f.p.scope,
            f.p.snapshotId,
            f.p.expectedHead,
            f.p.expectedRevision,
            f.p.outputManifestRecord,
            f.p.coordinatorInventoryPlan,
            f.p.expectedSourceHash,
            f.p.manifestURI,
            f.p.effectiveAt,
            f.p.reasonHash
        );
        f.scopedExpected = S.Source(
            f.expected.scope,
            f.expected.membership,
            f.expected.artist,
            f.expected.selection,
            f.expected.content,
            f.expected.outputs,
            f.factory,
            f.factory.codehash,
            keccak256(abi.encode(f.factoryDependencies)),
            f.expected.entropy
        );
    }

    function _sd(Fixture memory f) private pure returns (S.Dependencies memory) {
        return abi.decode(abi.encode(f.d), (S.Dependencies));
    }

    function _goodCollection(Fixture memory f) private view {
        C.Source memory actual = Collection.current(f.d, f.p, f.family);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(f.expected)),
            "complete collection Source"
        );
        require(
            Collection.sourceHash(f.d, actual, f.family)
                == keccak256(
                    abi.encode(
                        f.family == Profiles.FAMILY_PROFILE
                            ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2")
                            : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1"),
                        f.d.chainId,
                        address(this),
                        f.d.targets,
                        f.d.codeHashes,
                        f.expected
                    )
                ),
            "literal collection source domain"
        );
    }

    function _goodScoped(Fixture memory f) private view {
        S.Source memory actual = Scoped.current(_sd(f), f.scopedPublication, f.family);
        require(
            keccak256(abi.encode(actual)) == keccak256(abi.encode(f.scopedExpected)),
            "complete scoped Source"
        );
        require(
            Scoped.sourceHash(_sd(f), actual, f.family)
                == keccak256(
                    abi.encode(
                        f.family == Profiles.FAMILY_PROFILE
                            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2")
                            : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1"),
                        f.d.chainId,
                        address(this),
                        f.d.targets,
                        f.d.codeHashes,
                        f.scopedExpected
                    )
                ),
            "literal scoped source domain"
        );
    }

    function testCollectionOriginalAndFamilyReturnEveryRootAndEntropyField() public {
        for (uint256 i; i < 2; ++i) {
            Fixture memory f = _fixture(false, i == 1, StreamFinalityScopeType.COLLECTION);
            require(
                f.expected.entropy.policies.length == 2
                    && f.expected.entropy.policies[0].policyHash
                        != f.expected.entropy.policies[1].policyHash
            );
            require(
                bytes(f.expected.root.publication.manifestURI).length > 32
                    && abi.encode(f.expected.rootBinding).length == 608
            );
            _goodCollection(f);
        }
    }

    function testScopedBothFamiliesTokenReleaseSeasonReturnEverySourceField() public {
        StreamFinalityScopeType[3] memory kinds = [
            StreamFinalityScopeType.TOKEN,
            StreamFinalityScopeType.RELEASE,
            StreamFinalityScopeType.SEASON
        ];
        for (uint256 family; family < 2; ++family) {
            for (uint256 i; i < 3; ++i) {
                Fixture memory f = _fixture(true, family == 1, kinds[i]);
                vm.expectCall(f.factory, abi.encodeCall(Factory.dependencies, ()), uint64(2));
                _goodScoped(f);
            }
        }
    }

    function testDefaultAndExplicitOriginalOverloadsHaveIdenticalCompleteResults() public {
        Fixture memory c = _fixture(false, false, StreamFinalityScopeType.COLLECTION);
        Collection.bindings(c.d);
        Collection.bindings(c.d, Profiles.ORIGINAL_PROFILE);
        require(
            keccak256(abi.encode(Collection.current(c.d, c.p))) == keccak256(abi.encode(c.expected))
        );
        _goodCollection(c);
        Fixture memory s = _fixture(true, false, StreamFinalityScopeType.SEASON);
        Scoped.bindings(_sd(s));
        Scoped.bindings(_sd(s), Profiles.ORIGINAL_PROFILE);
        require(
            keccak256(abi.encode(Scoped.current(_sd(s), s.scopedPublication)))
                == keccak256(abi.encode(s.scopedExpected))
        );
        _goodScoped(s);
    }

    function testFamilyThenGasThenDependencyThenScopeRefusalsRestore() public {
        for (uint256 scoped; scoped < 2; ++scoped) {
            Fixture memory f = _fixture(
                scoped == 1,
                true,
                scoped == 1 ? StreamFinalityScopeType.TOKEN : StreamFinalityScopeType.COLLECTION
            );
            C.Dependencies memory original = abi.decode(abi.encode(f.d), (C.Dependencies));
            f.d.codeHashes[0] = 0;
            // Allocate new scope tuples; mutating an aliased nested memory member would
            // corrupt the independent expected Source and mask restoration failures.
            f.p.scope = StreamFinalityScope(
                StreamFinalityScopeType.VIEW, 41, 0, keccak256("unsupported view")
            );
            f.scopedPublication.scope = StreamFinalityScope(
                StreamFinalityScopeType.VIEW, 41, 0, keccak256("unsupported view")
            );
            vm.expectRevert(
                abi.encodeWithSelector(
                    scoped == 1
                        ? S.InvalidScopedPolicySnapshot.selector
                        : C.InvalidPolicySnapshot.selector
                )
            );
            if (scoped == 1) {
                Scoped.current(_sd(f), f.scopedPublication, keccak256("unknown family"));
            } else {
                Collection.current(f.d, f.p, keccak256("unknown family"));
            }
            f.d.readGas = 49999;
            _reject(
                f,
                scoped == 1,
                abi.encodeWithSelector(
                    scoped == 1
                        ? S.InvalidScopedPolicySnapshot.selector
                        : C.InvalidPolicySnapshot.selector
                )
            );
            f.d.readGas = READ_GAS;
            _reject(
                f,
                scoped == 1,
                abi.encodeWithSelector(
                    scoped == 1
                        ? S.ScopedPolicySnapshotDependency.selector
                        : C.PolicySnapshotDependency.selector,
                    f.d.targets[0]
                )
            );
            f.d = original;
            _reject(
                f,
                scoped == 1,
                abi.encodeWithSelector(
                    scoped == 1
                        ? S.InvalidScopedPolicySnapshot.selector
                        : C.InvalidPolicySnapshot.selector
                )
            );
            f.p.scope = f.expected.scope;
            f.scopedPublication.scope = f.expected.scope;
            if (scoped == 1) _goodScoped(f);
            else _goodCollection(f);
        }
    }

    function _reject(Fixture memory f, bool scoped, bytes memory error) private {
        vm.expectRevert(error);
        if (scoped) Scoped.current(_sd(f), f.scopedPublication, f.family);
        else Collection.current(f.d, f.p, f.family);
    }

    function testConfiguredCapsAreForwardedWithoutChangingCaller() public {
        for (uint256 scoped; scoped < 2; ++scoped) {
            Fixture memory f = _fixture(
                scoped == 1,
                true,
                scoped == 1 ? StreamFinalityScopeType.RELEASE : StreamFinalityScopeType.COLLECTION
            );
            _window(
                f.d.targets[5],
                abi.encodeCall(Membership.requireScopeMembership, (f.p.scope)),
                INVENTORY_GAS
            );
            _window(
                f.d.targets[8],
                abi.encodeCall(
                    Outputs.requireCurrentManifest,
                    (f.p.outputManifestRecord, f.expected.artist.artistId)
                ),
                SOURCE_GAS
            );
            _window(
                f.d.targets[10], abi.encodeCall(Entropy.requireCurrentSourceSet, ()), INVENTORY_GAS
            );
            _window(f.d.targets[10], abi.encodeCall(Entropy.sourcePolicyAt, (uint256(1))), READ_GAS);
            if (scoped == 1) {
                _window(f.factory, abi.encodeCall(Factory.dependencies, ()), READ_GAS);
                _window(
                    f.factory,
                    abi.encodeCall(
                        IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (f.p.scope)
                    ),
                    INVENTORY_GAS
                );
                _goodScoped(f);
            } else {
                _window(
                    f.d.targets[4],
                    abi.encodeCall(Root.contentRootRecord, (f.p.contentRootRecord)),
                    READ_GAS
                );
                _goodCollection(f);
            }
        }
    }

    function _window(address target, bytes memory input, uint256 cap) private {
        // Gas is sampled at fallback entry, before cold storage reads. This is a forwarding
        // regression bound, not a workload benchmark or a larger production allowance.
        _table(target).gasWindow(input, cap - 2000, cap);
    }

    function testAllGasConfigurationBoundsRejectBeforeDependencyReads() public {
        for (uint256 scoped; scoped < 2; ++scoped) {
            Fixture memory f = _fixture(
                scoped == 1,
                false,
                scoped == 1 ? StreamFinalityScopeType.SEASON : StreamFinalityScopeType.COLLECTION
            );
            C.Dependencies memory original = abi.decode(abi.encode(f.d), (C.Dependencies));
            for (uint256 variant; variant < 7; ++variant) {
                f.d = abi.decode(abi.encode(original), (C.Dependencies));
                f.d.codeHashes[0] = 0;
                if (variant == 0) f.d.chainId += 1;
                else if (variant == 1) f.d.readGas = 49999;
                else if (variant == 2) f.d.sourceGas = READ_GAS - 1;
                else if (variant == 3) f.d.inventoryGas = READ_GAS - 1;
                else if (variant == 4) f.d.readGas = uint256(type(uint32).max) + 1;
                else if (variant == 5) f.d.sourceGas = uint256(type(uint32).max) + 1;
                else f.d.inventoryGas = uint256(type(uint32).max) + 1;
                _reject(
                    f,
                    scoped == 1,
                    abi.encodeWithSelector(
                        scoped == 1
                            ? S.InvalidScopedPolicySnapshot.selector
                            : C.InvalidPolicySnapshot.selector
                    )
                );
            }
            f.d = original;
            if (scoped == 1) _goodScoped(f);
            else _goodCollection(f);
        }
    }

    function testLateSecondEntropyPolicyAndInventoryDriftRefuseThenRepair() public {
        for (uint256 scoped; scoped < 2; ++scoped) {
            for (uint256 family; family < 2; ++family) {
                Fixture memory f = _fixture(
                    scoped == 1,
                    family == 1,
                    scoped == 1
                        ? StreamFinalityScopeType.SEASON
                        : StreamFinalityScopeType.COLLECTION
                );
                bytes memory input = abi.encodeCall(Entropy.sourcePolicyAt, (uint256(1)));
                bytes memory good = abi.encode(f.expected.entropy.policies[1]);
                StreamFinalityCoordinatorPolicyV2 memory bad =
                    abi.decode(good, (StreamFinalityCoordinatorPolicyV2));
                bad.componentDataHash = 0;
                _set(f.d.targets[10], input, abi.encode(bad));
                _reject(
                    f,
                    scoped == 1,
                    abi.encodeWithSelector(
                        scoped == 1
                            ? S.InvalidScopedPolicySnapshot.selector
                            : C.InvalidPolicySnapshot.selector
                    )
                );
                _set(f.d.targets[10], input, bytes.concat(good, bytes32(0)));
                _reject(
                    f,
                    scoped == 1,
                    abi.encodeWithSelector(
                        Reads.RouterEvidenceRead.selector,
                        f.d.targets[10],
                        Entropy.sourcePolicyAt.selector
                    )
                );
                _set(f.d.targets[10], input, good);
                _word(
                    f.d.targets[10],
                    "originalInventoryHash()",
                    keccak256("changed original inventory")
                );
                _reject(
                    f,
                    scoped == 1,
                    abi.encodeWithSelector(
                        scoped == 1
                            ? S.InvalidScopedPolicySnapshot.selector
                            : C.InvalidPolicySnapshot.selector
                    )
                );
                _word(f.d.targets[10], "originalInventoryHash()", f.expected.entropy.inventoryHash);
                if (scoped == 1) _goodScoped(f);
                else _goodCollection(f);
            }
        }
    }

    function testCanonicalOutputAndRootTransportsRefuseWithoutTruncation() public {
        for (uint256 family; family < 2; ++family) {
            Fixture memory f = _fixture(false, family == 1, StreamFinalityScopeType.COLLECTION);
            bytes memory outputCall = abi.encodeCall(
                Outputs.requireCurrentManifest,
                (f.p.outputManifestRecord, f.expected.artist.artistId)
            );
            _set(
                f.d.targets[8], outputCall, bytes.concat(abi.encode(f.expected.outputs), bytes32(0))
            );
            _reject(
                f,
                false,
                abi.encodeWithSelector(
                    Reads.RouterEvidenceRead.selector,
                    f.d.targets[8],
                    Outputs.requireCurrentManifest.selector
                )
            );
            _set(f.d.targets[8], outputCall, abi.encode(f.expected.outputs));
            bytes memory rootCall = abi.encodeCall(Root.contentRootRecord, (f.p.contentRootRecord));
            _set(f.d.targets[4], rootCall, bytes.concat(abi.encode(f.expected.root), bytes32(0)));
            _reject(f, false, abi.encodeWithSelector(C.InvalidPolicySnapshot.selector));
            _set(f.d.targets[4], rootCall, new bytes(4097));
            _reject(
                f,
                false,
                abi.encodeWithSelector(
                    Reads.RouterEvidenceRead.selector,
                    f.d.targets[4],
                    Root.contentRootRecord.selector
                )
            );
            _set(f.d.targets[4], rootCall, abi.encode(f.expected.root));
            bytes memory bindingCall = abi.encodeCall(
                RootProfile.preservationPolicyContentRootBinding, (f.p.contentRootRecord)
            );
            _set(
                f.d.targets[4],
                bindingCall,
                bytes.concat(abi.encode(f.expected.rootBinding), bytes32(0))
            );
            _reject(
                f,
                false,
                abi.encodeWithSelector(
                    Reads.RouterEvidenceRead.selector,
                    f.d.targets[4],
                    RootProfile.preservationPolicyContentRootBinding.selector
                )
            );
            _set(f.d.targets[4], bindingCall, abi.encode(f.expected.rootBinding));
            _goodCollection(f);
        }
    }

    function testLateRootBindingThenOriginalRecordIdentityGuardsAndRepair() public {
        for (uint256 family; family < 2; ++family) {
            Fixture memory f = _fixture(false, family == 1, StreamFinalityScopeType.COLLECTION);
            bytes memory bindingCall = abi.encodeCall(
                RootProfile.preservationPolicyContentRootBinding, (f.p.contentRootRecord)
            );
            RootProfile.Binding memory bad =
                abi.decode(abi.encode(f.expected.rootBinding), (RootProfile.Binding));
            bad.inventoryHash = keccak256("foreign entropy inventory");
            bytes32 originalRoot = f.p.contentRootRecord;
            f.p.contentRootRecord = keccak256(
                abi.encode(
                    family == 1
                        ? keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2")
                        : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"),
                    f.d.chainId,
                    f.d.targets[4],
                    f.expected.root,
                    bad
                )
            );
            _set(
                f.d.targets[4],
                abi.encodeCall(Root.collectionContentRootHead, (f.p.scope.collectionId)),
                abi.encode(f.p.contentRootRecord)
            );
            _set(
                f.d.targets[4],
                abi.encodeCall(Root.contentRootRecord, (f.p.contentRootRecord)),
                abi.encode(f.expected.root)
            );
            _set(
                f.d.targets[4],
                abi.encodeCall(
                    RootProfile.preservationPolicyContentRootBinding, (f.p.contentRootRecord)
                ),
                abi.encode(bad)
            );
            _reject(f, false, abi.encodeWithSelector(C.InvalidPolicySnapshot.selector));
            f.p.contentRootRecord = originalRoot;
            _set(
                f.d.targets[4],
                abi.encodeCall(Root.collectionContentRootHead, (f.p.scope.collectionId)),
                abi.encode(originalRoot)
            );
            _set(f.d.targets[4], bindingCall, abi.encode(f.expected.rootBinding));
            bytes memory rootCall = abi.encodeCall(Root.contentRootRecord, (f.p.contentRootRecord));
            Root.Record memory altered = abi.decode(abi.encode(f.expected.root), (Root.Record));
            // stateHash is otherwise unconstrained: the original full-record hash must catch it.
            altered.stateHash = keccak256("altered original root state");
            _set(f.d.targets[4], rootCall, abi.encode(altered));
            _reject(f, false, abi.encodeWithSelector(C.InvalidPolicySnapshot.selector));
            _set(f.d.targets[4], rootCall, abi.encode(f.expected.root));
            _goodCollection(f);
        }
    }

    function testScopedFactoryGuardsAndLateRouteKeepBothValidations() public {
        for (uint256 family; family < 2; ++family) {
            Fixture memory f = _fixture(true, family == 1, StreamFinalityScopeType.RELEASE);
            bytes memory dependencyCall = abi.encodeCall(Factory.dependencies, ());
            _word(f.factory, "scopedPolicyFactoryProfile()", keccak256("foreign factory profile"));
            _reject(
                f,
                true,
                abi.encodeWithSelector(S.ScopedPolicySnapshotDependency.selector, f.factory)
            );
            _word(
                f.factory,
                "scopedPolicyFactoryProfile()",
                keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
            );
            _set(
                f.factory,
                dependencyCall,
                bytes.concat(abi.encode(f.factoryDependencies), bytes32(0))
            );
            _reject(
                f,
                true,
                abi.encodeWithSelector(
                    Reads.RouterEvidenceRead.selector, f.factory, Factory.dependencies.selector
                )
            );
            _set(f.factory, dependencyCall, abi.encode(f.factoryDependencies));
            bytes memory planCall = abi.encodeCall(FactoryBase.currentInventoryPlan, (f.p.scope));
            _set(f.factory, planCall, abi.encode(keccak256("wrong current factory plan")));
            // Two validations per current read: failed plan, healthy retry, failed route,
            // healthy retry. Foundry counts calls even when the containing read reverts.
            vm.expectCall(f.factory, dependencyCall, uint64(8));
            _reject(f, true, abi.encodeWithSelector(S.InvalidScopedPolicySnapshot.selector));
            _set(f.factory, planCall, abi.encode(f.p.coordinatorInventoryPlan));
            _goodScoped(f);
            bytes memory routeCall =
                abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (f.p.scope));
            StreamFinalityCurrentComponentRoute memory route = StreamFinalityCurrentComponentRoute(
                StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR,
                f.d.targets[10],
                type(IStreamArtworkScopedFinalityComponent).interfaceId,
                keccak256("wrong current route runtime")
            );
            _set(f.factory, routeCall, abi.encode(route));
            _reject(f, true, abi.encodeWithSelector(S.InvalidScopedPolicySnapshot.selector));
            route.codeHash = f.d.codeHashes[10];
            _set(f.factory, routeCall, abi.encode(route));
            _goodScoped(f);
        }
    }

    function testReadOrderRejectsSelectionBeforeEntropyAndEntropyBeforeRoot() public {
        Fixture memory f = _fixture(false, true, StreamFinalityScopeType.COLLECTION);
        bytes memory selectionCall =
            abi.encodeCall(Selection.checkpoint, (f.expected.content.selectionId));
        bytes memory entropyCall = abi.encodeCall(Entropy.requireCurrentSourceSet, ());
        bytes memory rootCall =
            abi.encodeCall(Root.collectionContentRootHead, (f.p.scope.collectionId));
        _table(f.d.targets[6]).fail(selectionCall, true);
        _table(f.d.targets[10]).fail(entropyCall, true);
        _table(f.d.targets[4]).fail(rootCall, true);
        _reject(
            f,
            false,
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector, f.d.targets[6], Selection.checkpoint.selector
            )
        );
        _table(f.d.targets[6]).fail(selectionCall, false);
        _reject(
            f,
            false,
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                f.d.targets[10],
                Entropy.requireCurrentSourceSet.selector
            )
        );
        _table(f.d.targets[10]).fail(entropyCall, false);
        _reject(
            f,
            false,
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                f.d.targets[4],
                Root.collectionContentRootHead.selector
            )
        );
        _table(f.d.targets[4]).fail(rootCall, false);
        _goodCollection(f);
    }
}
