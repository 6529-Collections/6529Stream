// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityCoordinatorPolicyV2
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import {
    StreamEntropyPolicyConsumerTypes
} from "../../smart-contracts/interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import {
    IStreamContentRootPublication
} from "../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamPolicyContentRootPublicationV2
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    StreamPolicyContentRootSchemasV2 as RootDocuments
} from "../../smart-contracts/domains/finality/StreamPolicyContentRootSchemasV2.sol";
import {
    StreamPolicyOutputSchemasV2 as OutputDocuments
} from "../../smart-contracts/domains/finality/StreamPolicyOutputSchemasV2.sol";
import "./ScopeMembershipPublicationFixture.sol";
import "./OfficialSafeFixture.sol";
import "../../smart-contracts/domains/metadata/StreamPolicySnapshotPublicationV2.sol";
import "../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    StreamPolicySnapshotTypesV2 as Scoped
} from "../../smart-contracts/interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamPolicyContentCheckpointV2 as Content
} from "../../smart-contracts/interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamPolicyOutputManifestV2 as Outputs
} from "../../smart-contracts/interfaces/stream/finality/IStreamPolicyOutputManifestV2.sol";

interface PolicySnapshotVmV2 {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @dev Explicit Core/Artist/Router root/output and source-set boundaries. Membership, inventories,
/// Metadata grants, schemas, Store, publication and threshold Safe remain actual contracts.
contract PolicySnapshotReadBoundaryV2 {
    mapping(bytes4 => bytes) internal _returns;
    bool private _current = true;

    function setCurrent(bool value) external {
        _current = value;
    }

    function requireCurrentSourceSet() external view {
        require(_current, "stale source set");
    }

    function set(string calldata selector, bytes calldata value) external {
        _returns[bytes4(keccak256(bytes(selector)))] = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id != 0xffffffff;
    }

    fallback() external {
        bytes memory value = _returns[msg.sig];
        require(value.length != 0, "unconfigured typed read");
        assembly ("memory-safe") { return(add(value, 32), mload(value)) }
    }
}

abstract contract PolicySnapshotFixtureV2 is
    ScopeMembershipPublicationFixture,
    OfficialSafeFixture
{
    PolicySnapshotVmV2 internal constant svm =
        PolicySnapshotVmV2(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamPolicySnapshotPublicationV2 internal host;
    StreamFinalityCoordinatorPolicyV2 internal policyRow;
    IStreamContentRootPublication.Record internal canonicalRoot;
    IStreamPolicyContentRootPublicationV2.Binding internal rootBinding;
    PolicySnapshotReadBoundaryV2 internal route;
    PolicySnapshotReadBoundaryV2 internal selected;
    PolicySnapshotReadBoundaryV2 internal content;
    PolicySnapshotReadBoundaryV2 internal outputs;
    PolicySnapshotReadBoundaryV2 internal coverage;
    PolicySnapshotReadBoundaryV2 internal entropy;
    Scoped.Publication internal publication;
    Content.Plan internal contentPlan;
    Selection.Plan internal selectionPlan;
    Outputs.Manifest internal outputManifest;

    function _initializePolicySnapshot() internal {
        uint256[] memory tokens = _tokens(3);
        _index(tokens, 0, tokens.length);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        route = new PolicySnapshotReadBoundaryV2();
        selected = new PolicySnapshotReadBoundaryV2();
        content = new PolicySnapshotReadBoundaryV2();
        outputs = new PolicySnapshotReadBoundaryV2();
        coverage = new PolicySnapshotReadBoundaryV2();
        entropy = new PolicySnapshotReadBoundaryV2();
        _setAddress(route, "core()", address(core));
        route.set("streamModuleType()", abi.encode(keccak256("METADATA_ROUTER")));
        route.set("streamModuleInterfaceId()", abi.encode(type(IStreamMetadataRouter).interfaceId));
        core.setPointer(keccak256("METADATA_ROUTER"), address(route));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(core));
        svm.mockCall(
            address(core),
            abi.encodeWithSignature("isModuleEligible(address,bytes32,bytes4)"),
            abi.encode(true)
        );
        svm.mockCall(
            address(core),
            abi.encodeWithSignature("getSatellitePointer(bytes32)", keccak256("METADATA_ROUTER")),
            abi.encode(
                address(route),
                address(route).codehash,
                false,
                keccak256("METADATA_ROUTER"),
                type(IStreamMetadataRouter).interfaceId,
                address(core),
                uint8(1),
                bytes32(uint256(1)),
                bytes32(uint256(2)),
                uint64(1)
            )
        );
        _setAddress(entropy, "core()", address(core));
        entropy.set("coreCodeHash()", abi.encode(address(core).codehash));
        bytes32 inventoryPlan = keccak256("complete original inventory");
        entropy.set("inventoryPlan()", abi.encode(inventoryPlan));
        entropy.set("originalInventoryHash()", abi.encode(keccak256("inventory")));
        entropy.set("originalPolicyChainHash()", abi.encode(keccak256("policy chain")));
        entropy.set("sourceCount()", abi.encode(uint256(1)));
        entropy.set("sourceScope()", abi.encode(scope));
        entropy.set("scopeMembershipFacts()", abi.encode(membership.requireScopeMembership(scope)));
        policyRow.coordinator = address(entropy);
        policyRow.indexedCodeHash = address(entropy).codehash;
        policyRow.frozen = true;
        policyRow.policyHash = keccak256("full policy");
        policyRow.componentDataHash = keccak256("component");
        policyRow.explicitPolicy = true;
        policyRow.collectionPolicy = StreamEntropyPolicyConsumerTypes.Policy(
            true,
            true,
            true,
            0,
            0,
            1,
            1,
            0,
            policyRow.policyHash,
            keccak256("content"),
            keccak256("action"),
            keccak256("consent")
        );
        entropy.set("sourcePolicyAt(uint256)", abi.encode(policyRow));
        _setAddress(selected, "core()", address(core));
        _setAddress(selected, "metadataHost()", address(metadata));
        _setAddress(selected, "metadataRouter()", address(route));
        _setAddress(selected, "scopeMembership()", address(membership));
        _setAddress(content, "core()", address(core));
        _setAddress(content, "metadataRouter()", address(route));
        _setAddress(content, "selectionCheckpoint()", address(selected));
        _setAddress(content, "entropySourceSet()", address(entropy));
        _setAddress(outputs, "core()", address(core));
        _setAddress(outputs, "contentCheckpoint()", address(content));
        _setAddress(outputs, "artifactCoverage()", address(coverage));
        _setAddress(outputs, "schemaRegistry()", address(schemas));
        _setAddress(coverage, "core()", address(core));
        _setAddress(coverage, "schemaRegistry()", address(schemas));
        _setAddress(coverage, "chunkStore()", address(store));
        IStreamMetadataServingFacts.ArtistPresentation memory artistFacts;
        artistFacts.locked = true;
        artistFacts.registry = address(artist);
        artistFacts.registryCodeHash = address(artist).codehash;
        artistFacts.artistId = keccak256("artist");
        artistFacts.bindingGeneration = 1;
        artistFacts.bindingHash = keccak256("binding");
        artistFacts.nominatedArtist = address(0x1234);
        artistFacts.identityRecordHash = keccak256("identity");
        artistFacts.acceptanceRecordHash = keccak256("acceptance");
        artistFacts.acceptedAt = 900;
        artistFacts.lockedAt = 950;
        artistFacts.snapshotHash = keccak256("locked presentation");
        route.set("artistPresentation(uint256)", abi.encode(artistFacts));
        StreamScopeMembershipFacts memory member = membership.requireScopeMembership(scope);
        selectionPlan = Selection.Plan(
            scope,
            member.membershipHash,
            keccak256("collection state"),
            uint64(member.tokenCount),
            uint64(member.tokenCount),
            keccak256("selection root")
        );
        contentPlan = Content.Plan(
            keccak256("selection"),
            keccak256(abi.encode(selectionPlan)),
            keccak256("inventory"),
            keccak256("policy chain"),
            scope,
            uint64(member.tokenCount),
            uint64(member.tokenCount),
            keccak256("leaves"),
            keccak256("content root"),
            keccak256("outputs")
        );
        outputManifest = Outputs.Manifest(
            keccak256("checkpoint"),
            keccak256(abi.encode(contentPlan)),
            address(entropy),
            keccak256("inventory"),
            keccak256("policy chain"),
            keccak256("artifact"),
            keccak256("coverage"),
            artistFacts.artistId,
            contentPlan.contentRoot,
            contentPlan.outputRoot,
            keccak256("manifest"),
            scope,
            uint64(member.tokenCount),
            1344
        );
        _refreshPlans();
        _grant(1, StreamRecordFamilies.SNAPSHOT, 7, address(this), true);
        string[3] memory names = [
            "STREAM_POLICY_COLLECTION_SNAPSHOT_ABI_V2",
            "STREAM_POLICY_COLLECTION_SNAPSHOT_PROFILE_V2",
            "STREAM_ABI_POLICY_COLLECTION_SNAPSHOT_V2"
        ];
        string[3] memory paths = [
            "docs/schemas/preservation/policy-collection-snapshot-v2.schema.json",
            "docs/schemas/preservation/policy-collection-snapshot-v2.profile.json",
            "docs/schemas/preservation/policy-collection-snapshot-v2.abi.json"
        ];
        for (uint256 i; i < 3; ++i) {
            _register(
                names[i],
                i == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : i == 1
                        ? IStreamSchemaRegistry.DocumentKind.CATALOG
                        : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                bytes(vm.readFile(paths[i]))
            );
        }
        _register(
            "STREAM_POLICY_CONTENT_ROOT_RECORD_V2",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            RootDocuments.document(RootDocuments.ROOT_SCHEMA)
        );
        _register(
            "STREAM_ABI_POLICY_CONTENT_ROOT_RECORD_V2",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            RootDocuments.document(RootDocuments.ROOT_CANON)
        );
        Scoped.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(route),
            address(membership),
            address(selected),
            address(content),
            address(outputs),
            address(coverage),
            address(entropy)
        ];
        for (uint256 i; i < 11; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        IStreamGasParameterHost.GasParameterConfig[3] memory gasConfigs;
        gasConfigs[0] = IStreamGasParameterHost.GasParameterConfig(
            "POLICY_SNAPSHOT_READ_GAS", 500000, 50000, 2
        );
        gasConfigs[1] = IStreamGasParameterHost.GasParameterConfig(
            "POLICY_SNAPSHOT_SOURCE_GAS", 1000000, 50000, 2
        );
        gasConfigs[2] = IStreamGasParameterHost.GasParameterConfig(
            "POLICY_SNAPSHOT_INVENTORY_GAS", 3000000, 50000, 2
        );
        host = new StreamPolicySnapshotPublicationV2(d, address(executor), gasConfigs);
        publication = Scoped.Publication(
            scope,
            keccak256("snapshot"),
            0,
            0,
            keccak256("verified output"),
            bytes32(0),
            inventoryPlan,
            0,
            "",
            1000,
            keccak256("reason")
        );
        canonicalRoot.publication =
            IStreamContentRootPublication.Publication(1, 0, publication.outputManifestRecord, "");
        canonicalRoot.contentRoot = outputManifest.contentRoot;
        canonicalRoot.leafCount = outputManifest.tokenCount;
        canonicalRoot.manifestHash = outputManifest.manifestHash;
        canonicalRoot.artistId = artistFacts.artistId;
        canonicalRoot.bindingGeneration = artistFacts.bindingGeneration;
        canonicalRoot.bindingHash = artistFacts.bindingHash;
        canonicalRoot.publisher = address(this);
        canonicalRoot.authorizationClass = 7;
        canonicalRoot.grantRevision = 1;
        canonicalRoot.routeHash = keccak256("route");
        canonicalRoot.stateHash = keccak256("approved state");
        canonicalRoot.artistConsent = keccak256("original op17 receipt");
        canonicalRoot.publishedAt = 1000;
        rootBinding = IStreamPolicyContentRootPublicationV2.Binding(
            keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2"),
            address(outputs),
            address(outputs).codehash,
            address(content),
            address(content).codehash,
            outputManifest.checkpointHash,
            outputManifest.checkpointStateHash,
            address(entropy),
            address(entropy).codehash,
            outputManifest.inventoryHash,
            outputManifest.policyChainHash,
            outputManifest.outputRoot,
            RootDocuments.definitionHash(OutputDocuments.SCHEMA),
            RootDocuments.definitionHash(OutputDocuments.CANON),
            RootDocuments.definitionHash(OutputDocuments.LEAF_SCHEMA),
            RootDocuments.definitionHash(RootDocuments.ROOT_SCHEMA),
            RootDocuments.definitionHash(RootDocuments.ROOT_CANON)
        );
        _refreshRoot();
    }

    function _refreshRoot() internal {
        publication.contentRootRecord = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_CONTENT_ROOT_RECORD_V2"),
                block.chainid,
                address(route),
                canonicalRoot,
                rootBinding
            )
        );
        route.set("collectionContentRootHead(uint256)", abi.encode(publication.contentRootRecord));
        route.set("contentRootRecord(bytes32)", abi.encode(canonicalRoot));
        route.set("policyContentRootBinding(bytes32)", abi.encode(rootBinding));
    }

    function _refreshPlans() internal {
        selected.set("checkpoint(bytes32)", abi.encode(selectionPlan));
        content.set("checkpoint(bytes32)", abi.encode(contentPlan));
        outputs.set("requireCurrentManifest(bytes32,bytes32)", abi.encode(outputManifest));
    }

    function _setAddress(PolicySnapshotReadBoundaryV2 target, string memory selector, address value)
        internal
    {
        target.set(selector, abi.encode(value));
    }

    function _bytes(address publisher) internal returns (bytes memory canonical) {
        (bytes32 hash, bytes memory raw) = host.previewSnapshot(publication, publisher);
        publication.expectedSourceHash = hash;
        return raw;
    }

    function _uploadSnapshot(bytes memory raw, bool omitLast) internal {
        uint256 count = (raw.length + 8191) / 8192;
        for (uint256 i; i < count - (omitLast ? 1 : 0); ++i) {
            uint256 size = raw.length - i * 8192;
            if (size > 8192) size = 8192;
            bytes memory chunk = new bytes(size);
            for (uint256 j; j < size; ++j) {
                chunk[j] = raw[i * 8192 + j];
            }
            store.publishChunk(chunk);
        }
    }

    function _publishSnapshot() internal returns (bytes32 hash) {
        _uploadSnapshot(_bytes(address(this)), false);
        return host.publishSnapshot(publication);
    }
}
