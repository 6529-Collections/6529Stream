// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ScopeMembershipPublicationFixture.sol";
import "./OfficialSafeFixture.sol";
import "../../smart-contracts/domains/metadata/StreamScopedSnapshotPublication.sol";
import "../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    StreamScopedSnapshotTypes as Scoped
} from "../../smart-contracts/interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import {
    IStreamStaticContentCheckpoint as Content
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamStaticOutputManifest as Outputs
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticOutputManifest.sol";

interface ScopedSnapshotVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @dev Copied original snapshot fixture setup, with visibility only for derived scoped reference tests.
/// Explicit renderer/output/archive and entropy-policy boundary. Membership, inventories,
/// Metadata grants, schemas, Store, publication and threshold Safe remain actual contracts.
contract ScopedReferenceReadBoundary {
    mapping(bytes4 => bytes) internal _returns;

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

abstract contract ScopedReferenceSnapshotFixture is
    ScopeMembershipPublicationFixture,
    OfficialSafeFixture
{
    ScopedSnapshotVm internal constant svm =
        ScopedSnapshotVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamScopedSnapshotPublication internal host;
    StreamFinalityCoordinatorInventory internal coordinators;
    ScopedReferenceReadBoundary internal route;
    ScopedReferenceReadBoundary internal selected;
    ScopedReferenceReadBoundary internal content;
    ScopedReferenceReadBoundary internal outputs;
    ScopedReferenceReadBoundary internal coverage;
    ScopedReferenceReadBoundary internal entropy;
    Scoped.Publication internal publication;
    Content.Plan internal contentPlan;
    Selection.Plan internal selectionPlan;
    Outputs.Manifest internal outputManifest;

    function _initialize(uint8 kind) internal {
        uint256[] memory tokens = _tokens(3);
        _index(tokens, 0, tokens.length);
        StreamFinalityScope memory scope = kind == 1
            ? StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, tokens[1], 0)
            : _seal(kind, tokens, "");
        route = new ScopedReferenceReadBoundary();
        selected = new ScopedReferenceReadBoundary();
        content = new ScopedReferenceReadBoundary();
        outputs = new ScopedReferenceReadBoundary();
        coverage = new ScopedReferenceReadBoundary();
        entropy = new ScopedReferenceReadBoundary();
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
        svm.mockCall(
            address(core),
            abi.encodeWithSignature("coordinatorAtMint(uint256)"),
            abi.encode(address(entropy))
        );
        _setAddress(entropy, "core()", address(core));
        entropy.set("streamModuleType()", abi.encode(keccak256("ENTROPY_COORDINATOR")));
        entropy.set(
            "streamModuleInterfaceId()", abi.encode(type(IStreamEntropyCoordinator).interfaceId)
        );
        entropy.set("streamModuleCodeHash()", abi.encode(address(entropy).codehash));
        entropy.set("streamModuleVersion()", abi.encode(keccak256("version")));
        entropy.set("streamModuleManifestHash()", abi.encode(keccak256("manifest")));
        entropy.set("streamModuleSchemaHash()", abi.encode(keccak256("schema")));
        entropy.set("streamModuleDeploymentManifestHash()", abi.encode(keccak256("deployment")));
        entropy.set(
            "entropyPolicyFrozen(uint256)",
            abi.encode(true, keccak256("policy"), address(0x123), uint32(1), keccak256("salt"))
        );
        coordinators = new StreamFinalityCoordinatorInventory(
            address(core), address(membership), 150000, 2000000
        );
        bytes32 inventoryPlan = coordinators.beginInventory(scope);
        coordinators.appendInventory(inventoryPlan, 3);
        _setAddress(selected, "core()", address(core));
        _setAddress(selected, "metadataHost()", address(metadata));
        _setAddress(selected, "metadataRouter()", address(route));
        _setAddress(selected, "scopeMembership()", address(membership));
        _setAddress(content, "core()", address(core));
        _setAddress(content, "metadataRouter()", address(route));
        _setAddress(content, "selectionCheckpoint()", address(selected));
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
            "STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1",
            "STREAM_SCOPED_STATIC_SNAPSHOT_PROFILE_V1",
            "STREAM_SOLIDITY_ABI_V1"
        ];
        for (uint256 i; i < names.length; ++i) {
            _register(
                names[i],
                i == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : i == 1
                        ? IStreamSchemaRegistry.DocumentKind.CATALOG
                        : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                bytes(vm.readFile(string.concat("schemas/records/", names[i], ".json")))
            );
        }
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
            address(coordinators)
        ];
        for (uint256 i; i < 11; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        IStreamGasParameterHost.GasParameterConfig[3] memory gasConfigs;
        gasConfigs[0] = IStreamGasParameterHost.GasParameterConfig(
            "SCOPED_SNAPSHOT_READ_GAS", 500000, 50000, 2
        );
        gasConfigs[1] = IStreamGasParameterHost.GasParameterConfig(
            "SCOPED_SNAPSHOT_SOURCE_GAS", 1000000, 50000, 2
        );
        gasConfigs[2] = IStreamGasParameterHost.GasParameterConfig(
            "SCOPED_SNAPSHOT_INVENTORY_GAS", 3000000, 50000, 2
        );
        host = new StreamScopedSnapshotPublication(d, address(executor), gasConfigs);
        publication = Scoped.Publication(
            scope,
            keccak256("snapshot"),
            0,
            0,
            keccak256("verified output"),
            inventoryPlan,
            0,
            "",
            1000,
            keccak256("reason")
        );
    }

    function _refreshPlans() internal {
        selected.set("checkpoint(bytes32)", abi.encode(selectionPlan));
        content.set("checkpoint(bytes32)", abi.encode(contentPlan));
        outputs.set("requireCurrentManifest(bytes32,bytes32)", abi.encode(outputManifest));
    }

    function _setAddress(ScopedReferenceReadBoundary target, string memory selector, address value)
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
