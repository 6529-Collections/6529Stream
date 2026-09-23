// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ScopeMembershipPublicationFixture.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamScopedSnapshotPublication.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    StreamScopedSnapshotTypes as Scoped
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import {
    IStreamStaticContentCheckpoint as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamStaticOutputManifest as Outputs
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticOutputManifest.sol";

interface ScopedSnapshotVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

/// @dev Explicit renderer/output/archive and entropy-policy boundary. Membership, inventories,
/// Metadata grants, schemas, Store, publication and threshold Safe remain actual contracts.
contract ScopedSnapshotReadBoundary {
    mapping(bytes4 => bytes) private _returns;

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

contract StreamScopedSnapshotPublicationTest is
    ScopeMembershipPublicationFixture,
    OfficialSafeFixture
{
    ScopedSnapshotVm private constant svm =
        ScopedSnapshotVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamScopedSnapshotPublication private host;
    StreamFinalityCoordinatorInventory private coordinators;
    ScopedSnapshotReadBoundary private route;
    ScopedSnapshotReadBoundary private selected;
    ScopedSnapshotReadBoundary private content;
    ScopedSnapshotReadBoundary private outputs;
    ScopedSnapshotReadBoundary private coverage;
    ScopedSnapshotReadBoundary private entropy;
    Scoped.Publication private publication;
    Content.Plan private contentPlan;
    Selection.Plan private selectionPlan;
    Outputs.Manifest private outputManifest;

    function _initialize(uint8 kind) private {
        uint256[] memory tokens = _tokens(3);
        _index(tokens, 0, tokens.length);
        StreamFinalityScope memory scope = kind == 1
            ? StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, tokens[1], 0)
            : _seal(kind, tokens, "");
        route = new ScopedSnapshotReadBoundary();
        selected = new ScopedSnapshotReadBoundary();
        content = new ScopedSnapshotReadBoundary();
        outputs = new ScopedSnapshotReadBoundary();
        coverage = new ScopedSnapshotReadBoundary();
        entropy = new ScopedSnapshotReadBoundary();
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

    function _refreshPlans() private {
        selected.set("checkpoint(bytes32)", abi.encode(selectionPlan));
        content.set("checkpoint(bytes32)", abi.encode(contentPlan));
        outputs.set("requireCurrentManifest(bytes32,bytes32)", abi.encode(outputManifest));
    }

    function _setAddress(ScopedSnapshotReadBoundary target, string memory selector, address value)
        private
    {
        target.set(selector, abi.encode(value));
    }

    function _bytes(address publisher) private returns (bytes memory canonical) {
        (bytes32 hash, bytes memory raw) = host.previewSnapshot(publication, publisher);
        publication.expectedSourceHash = hash;
        return raw;
    }

    function _uploadSnapshot(bytes memory raw, bool omitLast) private {
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

    function _publishSnapshot() private returns (bytes32 hash) {
        _uploadSnapshot(_bytes(address(this)), false);
        return host.publishSnapshot(publication);
    }

    function testTokenActualMembershipAndExactReceiptPayload() public {
        _initialize(1);
        bytes memory expected = _bytes(address(this));
        bytes32 hash = _publishSnapshot();
        require(keccak256(host.snapshotPayload(hash)) == keccak256(expected));
        Scoped.Receipt memory r = host.requireCurrent(publication.scope, hash, 1);
        require(
            r.recordHash == hash && r.authorizationClass == 7 && r.displayAuthorizationClass == 7
        );
        require(
            host.snapshotCount(publication.scope) == 1
                && host.snapshotAt(publication.scope, 0) == hash
        );
    }

    function testReleaseSourceChangesRefuseCurrentAndPreserveHistory() public {
        _initialize(2);
        bytes32 hash = _publishSnapshot();
        bytes32 originalBytes = keccak256(host.snapshotPayload(hash));
        selectionPlan.collectionStateHash = keccak256("changed");
        _refreshPlans();
        vm.expectRevert();
        host.requireCurrent(publication.scope, hash, 1);
        require(keccak256(host.snapshotPayload(hash)) == originalBytes);
    }

    function testSeasonParentMintsDoNotRewriteSealedSubset() public {
        _initialize(3);
        bytes32 hash = _publishSnapshot();
        core.setToken(12, 1, 4, 2);
        uint256[] memory more = new uint256[](1);
        more[0] = 12;
        inventory.appendCollectionTokens(1, more);
        require(host.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }

    function testWrongScopeOrIncompletePlanAndViewRefuse() public {
        _initialize(2);
        contentPlan.nextIndex = 1;
        outputManifest.checkpointStateHash = keccak256(abi.encode(contentPlan));
        _refreshPlans();
        vm.expectRevert();
        host.previewSnapshot(publication, address(this));
        publication.scope.scopeType = StreamFinalityScopeType.VIEW;
        vm.expectRevert(abi.encodeWithSelector(Scoped.InvalidScopedSnapshot.selector));
        host.previewSnapshot(publication, address(this));
    }

    function testBothWriterGrantsAndStaleRevisionRemainRequired() public {
        _initialize(1);
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(this), false);
        vm.expectRevert();
        host.previewSnapshot(publication, address(this));
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(this), true);
        bytes32 hash = _publishSnapshot();
        publication.snapshotId = keccak256("next snapshot");
        vm.expectRevert();
        host.previewSnapshot(publication, address(this));
        publication.expectedHead = hash;
        publication.expectedRevision = 1;
        require(_publishSnapshot() != hash && host.snapshotCount(publication.scope) == 2);
    }

    function testOfficialSafeMissingBytesRollsBackAndIdenticalRetry() public {
        _initialize(2);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x818121;
        keys[1] = 0x818122;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 902);
        _grant(1, StreamRecordFamilies.SNAPSHOT, 7, address(account), true);
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(account), true);
        bytes memory raw = _bytes(address(account));
        _uploadSnapshot(raw, true);
        bytes memory input = abi.encodeCall(host.publishSnapshot, (publication));
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(host), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(host), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(account.nonce() == nonce && host.snapshotCount(publication.scope) == 0);
        _uploadSnapshot(raw, false);
        require(
            account.execTransaction(
                address(host), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            )
        );
        require(
            account.nonce() == nonce + 1
                && host.currentSnapshot(publication.scope).publisher == address(account)
        );
    }

    function testGlobalGrantsAndExactSourceCommitment() public {
        _initialize(1);
        _grant(1, StreamRecordFamilies.SNAPSHOT, 7, address(this), false);
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(this), false);
        _grant(0, StreamRecordFamilies.SNAPSHOT, 8, address(this), true);
        _grant(0, StreamRecordFamilies.IDENTITY, 8, address(this), true);
        bytes memory raw = _bytes(address(this));
        _uploadSnapshot(raw, false);
        bytes32 expected = publication.expectedSourceHash;
        publication.expectedSourceHash = keccak256("substituted source");
        vm.expectRevert(abi.encodeWithSelector(Scoped.InvalidScopedSnapshot.selector));
        host.publishSnapshot(publication);
        require(host.snapshotCount(publication.scope) == 0);
        publication.expectedSourceHash = expected;
        bytes32 hash = host.publishSnapshot(publication);
        Scoped.Receipt memory r = host.requireCurrent(publication.scope, hash, 1);
        require(r.authorizationClass == 8 && r.displayAuthorizationClass == 8);
    }

    function testUnfrozenOriginalPolicyAndInvalidTokenLifecycleRefuse() public {
        _initialize(1);
        entropy.set(
            "entropyPolicyFrozen(uint256)",
            abi.encode(false, keccak256("policy"), address(0x123), uint32(1), keccak256("salt"))
        );
        vm.expectRevert(abi.encodeWithSelector(Scoped.InvalidScopedSnapshot.selector));
        host.previewSnapshot(publication, address(this));
        entropy.set(
            "entropyPolicyFrozen(uint256)",
            abi.encode(true, keccak256("policy"), address(0x123), uint32(1), keccak256("salt"))
        );
        bytes32 hash = _publishSnapshot();
        bytes32 original = keccak256(host.snapshotPayload(hash));
        // Membership deliberately includes burned tokens. An invalid pending lifecycle is
        // refused by the actual membership host; this is not a renderer burn-output oracle.
        core.setToken(publication.scope.tokenId, 1, 2, 1);
        vm.expectRevert();
        host.requireCurrent(publication.scope, hash, 1);
        require(keccak256(host.snapshotPayload(hash)) == original);
    }

    function testExactClassTwoLockAndPublicationReplay() public {
        _initialize(1);
        bytes32 hash = _publishSnapshot();
        (bytes32 scope, bytes32 oldState, bytes32 newState) = host.lockTransition(publication.scope);
        vm.expectRevert();
        host.lockSnapshot(publication.scope);
        svm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("lock"), uint8(2), scope, oldState, keccak256("wrong next"))
        );
        vm.expectRevert(
            abi.encodeWithSelector(Scoped.ScopedSnapshotAuthority.selector, address(executor))
        );
        vm.prank(address(executor));
        host.lockSnapshot(publication.scope);
        require(host.snapshotLock(publication.scope).actionId == 0);
        svm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("lock"), uint8(2), scope, oldState, newState)
        );
        vm.prank(address(executor));
        host.lockSnapshot(publication.scope);
        require(host.snapshotLock(publication.scope).recordHash == hash);
        vm.expectRevert();
        host.publishSnapshot(publication);
        require(host.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }
}
