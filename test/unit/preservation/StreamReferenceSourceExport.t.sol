// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../metadata/StreamContentRootPublication.t.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../helpers/EntropyFinalityEvidenceFixture.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import {
    StreamCollectionSnapshots
} from "../../../smart-contracts/domains/metadata/StreamCollectionSnapshots.sol";
import {
    StreamSnapshotTypes
} from "../../../smart-contracts/interfaces/stream/metadata/StreamSnapshotTypes.sol";
import {
    StreamFinalitySnapshotReads
} from "../../../smart-contracts/domains/finality/StreamFinalitySnapshotReads.sol";
import {
    StreamFinalitySnapshotEvidence
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalitySnapshotTypes.sol";
import {
    StreamSnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamSnapshotDefinitions.sol";
import { StreamRecordJson } from "../../../smart-contracts/domains/records/StreamRecordJson.sol";
import {
    StreamSnapshotManifestJson
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestJson.sol";
import {
    StreamSnapshotManifestBytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import "../../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import "../../../smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol";
import "../../../smart-contracts/domains/finality/StreamContentLeafManifest.sol";

interface ReferenceSourceVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function writeFile(string calldata, string calldata) external;
    function createDir(string calldata, bool) external;
}

contract ReferenceSourceSnapshotConsumer {
    StreamFinalitySnapshotReads.Dependencies internal dependencies;

    constructor(StreamFinalitySnapshotReads.Dependencies memory d) {
        dependencies = d;
    }

    function read(StreamFinalityScope memory scope, bytes32 record, uint64 revision)
        external
        view
        returns (StreamFinalitySnapshotEvidence memory)
    {
        return StreamFinalitySnapshotReads.requireCurrent(dependencies, scope, record, revision);
    }

    function locked(StreamFinalityScope memory scope, bytes32 record, uint64 revision)
        external
        view
        returns (StreamFinalitySnapshotEvidence memory)
    {
        return StreamFinalitySnapshotReads.requireLocked(dependencies, scope, record, revision);
    }
}

contract ReferenceSourceManifestHarness {
    StreamSnapshotManifestBytes.Manifest internal saved;

    function retain(address store, bytes memory raw) external {
        StreamSnapshotManifestBytes.retain(saved, store, raw);
    }

    function read() external view returns (bytes memory) {
        return StreamSnapshotManifestBytes.read(saved);
    }

    function count() external view returns (uint256) {
        return saved.pointers.length;
    }
}

/// @dev Explicit archival-family receipt boundary. Actual immutable bytes, checkpoint and
///      complete ordered leaf verification are exercised by the actual producers below.
contract ReferenceSourceArchiveBoundary {
    address public immutable core;
    address public immutable schemaRegistry;
    F.Coverage internal row;
    address internal pointer;
    bool public current = true;

    constructor(address c, address s) {
        core = c;
        schemaRegistry = s;
    }

    function configure(bytes memory raw, address p) external {
        pointer = p;
        row = F.Coverage(
            keccak256("coverage"),
            keccak256("artifact"),
            keccak256("artist"),
            keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            keccak256("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            keccak256(raw),
            uint64(raw.length),
            1,
            keccak256("family A"),
            keccak256("family B"),
            1,
            keccak256("coverage evidence")
        );
    }

    function setCurrent(bool value) external {
        current = value;
    }

    function requireArtifactCoverage(bytes32 hash, bytes32 artist, bytes32 artifact)
        external
        view
        returns (F.Coverage memory)
    {
        require(
            current && hash == row.completionHash && artist == row.artistId
                && artifact == row.artifactHash,
            "archive boundary"
        );
        return row;
    }

    function artifactChunk(bytes32 artifact, uint32 index)
        external
        view
        returns (address, bytes32)
    {
        require(artifact == row.artifactHash && index == 0);
        return (pointer, pointer.codehash);
    }
}

/// @notice Actual Snapshot/Metadata/Schema/Store/Router, token and original-source inventories,
///      native Coordinator policies, checkpoint and complete stored leaf-manifest verification.
/// @dev Core/Executor, artist authorization, seed production and archive-family receipts are
///      explicit boundaries. Safe publication uses real upstream threshold signatures.
abstract contract ReferenceSourceExportFixture is
    ContentRootPublicationFixture,
    EntropyTimeAuthorityFixture
{
    event log_named_uint(string key, uint256 value);
    ReferenceSourceVm internal constant cheat =
        ReferenceSourceVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamCollectionSnapshots internal snapshots;
    StreamCollectionTokenInventory internal inventory;
    StreamFinalityScopeMembership internal membership;
    StreamFinalityCoordinatorInventory internal coordinators;
    StreamOnchainContentCheckpoint internal checkpoint;
    StreamContentLeafManifest internal leaves;
    ReferenceSourceArchiveBoundary internal archive;
    StreamEntropyCoordinator internal first;
    StreamEntropyCoordinator internal second;
    MockEntropyRoleRegistry public roleRegistry;
    bytes32 internal inventoryPlan;
    bytes32 internal rootRecord;
    bool internal maximum;
    bytes internal imageBytes;

    function setUp() public virtual override {
        super.setUp();
        core.setMinted(0);
        router.setCollectionScript(
            1,
            "document.body.style.margin='0';const c=document.createElement('canvas');c.width=64;c.height=64;document.body.appendChild(c);const x=c.getContext('2d');x.fillStyle='#123456';x.fillRect(0,0,64,64);x.fillStyle=tokenId===1?'#ff0000':'#00ff00';x.fillRect(8,8,16,16);"
        );
        if (maximum) {
            core.setMinted(0);
            imageBytes = new bytes(1518);
            bytes memory signature = hex"89504e470d0a1a0a";
            for (uint256 i; i < signature.length; ++i) {
                imageBytes[i] = signature[i];
            }
            router.setCollectionMetadata(
                1,
                _repeat(256),
                _repeat(2048),
                string.concat("data:image/png;base64,", Base64.encode(imageBytes)),
                string.concat("ipfs://", _repeat(2041))
            );
            router.setCollectionScript(1, _repeat(8192));
        }
        // Accepted-at and registry eligibility are explicit fixture additions, not production edits.
        IStreamCollectionArtistRegistry.Attribution memory a = artist.attribution(1);
        a.acceptedAt = 999;
        cheat.mockCall(address(artist), abi.encodeCall(artist.attribution, (1)), abi.encode(a));
        _displayGrant(address(this), true);
        _documents(schemas.RAW_BYTES());
        _snapshotDocument(
            "STREAM_NATIVE_ONCHAIN_SNAPSHOT_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_NATIVE_ONCHAIN_SNAPSHOT_V1.json"))
        );
        _snapshotDocument(
            "STREAM_NATIVE_ONCHAIN_SNAPSHOT_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(
                vm.readFile("schemas/records/STREAM_NATIVE_ONCHAIN_SNAPSHOT_JSON_PROFILE_V1.json")
            )
        );
        _snapshotDocument(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        first = _native();
        second = _native();
        for (uint256 i; i < 2; ++i) {
            bytes32 kind = i == 0 ? keccak256("COLLECTION_METADATA") : keccak256("METADATA_ROUTER");
            StreamCorePointerState memory selected = core.getSatellitePointer(kind);
            selected.registry = core.selected(keccak256("MODULE_REGISTRY"));
            cheat.mockCall(
                address(core),
                abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)),
                abi.encode(selected)
            );
        }
        core.setMinted(2);
        uint256[2] memory sourceIds = _sourceTokenIds();
        for (uint256 i; i < 2; ++i) {
            uint256 id = sourceIds[i];
            core.setToken(id, address(this), 2);
            address c = i == 0 ? address(first) : address(second);
            cheat.mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (id)),
                abi.encode(c)
            );
            cheat.mockCall(
                c,
                abi.encodeCall(IStreamEntropyView.tokenSeed, (id)),
                abi.encode(bytes32(uint256(77)), true)
            );
            cheat.mockCall(
                c, abi.encodeCall(IStreamEntropyView.tokenEntropyStatus, (id)), abi.encode(uint8(5))
            );
        }
        inventory = new StreamCollectionTokenInventory(
            address(core), address(executor), _gas("TOKEN_INVENTORY_CORE_READ_GAS", 100000, 1)
        );
        uint256[] memory ids = new uint256[](2);
        ids[0] = sourceIds[0];
        ids[1] = sourceIds[1];
        if (ids[0] == 1 && ids[1] == 2) inventory.appendCollectionTokens(1, ids);
        else inventory.scanCollectionTokens(1, ids[1]);
        membership = new StreamFinalityScopeMembership(
            address(core),
            address(metadata),
            address(inventory),
            address(executor),
            _gas("SCOPE_MEMBERSHIP_READ_GAS", 500000, 1)
        );
        coordinators = new StreamFinalityCoordinatorInventory(
            address(core), address(membership), 150000, 2000000
        );
        inventoryPlan = coordinators.beginInventory(_scope());
        coordinators.appendInventory(inventoryPlan, 2);
        router.lockDisplayMetadata(1);
        bytes32[] memory locks = new bytes32[](3);
        locks[0] = keccak256("SCRIPT");
        locks[1] = keccak256("MEDIA_MANIFEST");
        locks[2] = keccak256("BASE_URI");
        for (uint256 i; i < locks.length; ++i) {
            for (uint256 j = i + 1; j < locks.length; ++j) {
                if (locks[j] < locks[i]) (locks[i], locks[j]) = (locks[j], locks[i]);
            }
        }
        artist.setFreeze(router.artistContentFreezeState(1), locks);
        router.applyArtistContentFreeze(1, keccak256("freeze"));
        checkpoint = new StreamOnchainContentCheckpoint(
            address(core),
            address(router),
            address(inventory),
            address(executor),
            _gas("CONTENT_CHECKPOINT_READ_GAS", 500000, 1),
            _gas("CONTENT_CHECKPOINT_RENDER_GAS", 3000000, 1)
        );
        archive = new ReferenceSourceArchiveBoundary(address(core), address(schemas));
        leaves = new StreamContentLeafManifest(
            address(core),
            address(checkpoint),
            address(archive),
            address(executor),
            _gas("CONTENT_LEAF_MANIFEST_READ_GAS", 500000, 2)
        );
        provider =
            address(new RootProviderBoundary(address(metadata), address(schemas), address(leaves)));
        finality = new RootFinalityBoundary(
            address(core), address(artist), address(metadata), provider, address(archive)
        );
        finality.setReadGas(8000000);
        artist.configure(address(router), address(finality));
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(finality));
        router.lockArtistIdentity(1);
        // Historical Router rendering's original-finality absence is a precise read boundary.
        cheat.mockCall(
            address(finality),
            abi.encodeWithSignature(
                "finalityComponentCountForScope((uint8,uint256,uint256,bytes32))", _scope()
            ),
            abi.encode(uint256(0))
        );
        cheat.mockCall(
            address(finality),
            abi.encodeWithSignature("finalityComponentCount(uint256)", 1),
            abi.encode(uint256(0))
        );
        for (uint256 i; i < 2; ++i) {
            StreamFinalityScope memory tokenScope =
                StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, sourceIds[i], 0);
            cheat.mockCall(
                address(finality),
                abi.encodeWithSignature(
                    "finalityComponentCountForScope((uint8,uint256,uint256,bytes32))", tokenScope
                ),
                abi.encode(uint256(0))
            );
        }
        _root();
        snapshots = new StreamCollectionSnapshots(_dependencies(), address(executor), _configs());
    }

    function _native() internal returns (StreamEntropyCoordinator c) {
        if (address(roleRegistry) == address(0)) {
            roleRegistry = new MockEntropyRoleRegistry(address(this));
        }
        core.setPointer(
            keccak256("MODULE_REGISTRY"), address(new EntropyFinalityModuleBoundary(address(this)))
        );
        c = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                keccak256("entropy deployment"),
                "ipfs://native-policy",
                keccak256("native manifest")
            )
        );
        c.configureCollection(
            1, address(new MockStreamEntropyProvider(address(c))), keccak256("salt"), true, 10
        );
        c.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        c.registerEntropyScope(1, 1, keccak256("scope"));
    }

    function _root() internal {
        bytes32 cp = checkpoint.beginCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payloads =
            new IStreamOnchainContentCheckpoint.TokenPayload[](2);
        for (uint256 i; i < 2; ++i) {
            uint256 id = _sourceTokenIds()[i];
            bytes memory html = abi.encodePacked(
                "<html><head></head><body><script>const tokenId=",
                Strings.toString(id),
                ";const tokenHash='",
                Strings.toHexString(uint256(77), 32),
                "';const tokenDataBase64='AP8=';",
                maximum
                    ? _repeat(8192)
                    : "document.body.style.margin='0';const c=document.createElement('canvas');c.width=64;c.height=64;document.body.appendChild(c);const x=c.getContext('2d');x.fillStyle='#123456';x.fillRect(0,0,64,64);x.fillStyle=tokenId===1?'#ff0000':'#00ff00';x.fillRect(8,8,16,16);",
                "</script></body></html>"
            );
            payloads[i] = IStreamOnchainContentCheckpoint.TokenPayload(id, imageBytes, html);
        }
        checkpoint.appendCheckpointTokens(cp, payloads);
        IStreamOnchainContentCheckpoint.Plan memory plan = checkpoint.requireCurrentCheckpoint(cp);
        StreamTokenContentLeaf[] memory rows = new StreamTokenContentLeaf[](2);
        rows[0] = checkpoint.checkpointLeaf(cp, 0);
        rows[1] = checkpoint.checkpointLeaf(cp, 1);
        bytes memory raw = abi.encode(
            StreamContentRootSchemas.LEAF_SCHEMA,
            block.chainid,
            address(core),
            address(checkpoint),
            cp,
            uint256(1),
            plan.contentRoot,
            plan.tokenCount,
            rows
        );
        (, address pointer) = store.publishChunk(raw);
        archive.configure(raw, pointer);
        bytes32 lp = leaves.beginManifest(
            cp, keccak256("artifact"), keccak256("coverage"), keccak256("artist")
        );
        bytes32 lm = leaves.verifyNextLeaves(lp, 2);
        IStreamContentRootPublication.Publication memory p =
            IStreamContentRootPublication.Publication(1, 0, lm, "ipfs://actual-leaf-manifest");
        _approve(p, address(this), keccak256("snapshot-root-consent"));
        rootRecord = router.publishVerifiedTokenContentRoot(p);
    }

    function _scope() internal pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    /// @dev Sparse cohorts override retained identities without changing completed supply.
    function _sourceTokenIds() internal pure virtual returns (uint256[2] memory) {
        return [uint256(1), uint256(2)];
    }

    function _gas(string memory name, uint256 cap, uint8 failure)
        internal
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(name, cap, 50000, failure);
    }

    function _configs()
        internal
        pure
        returns (IStreamGasParameterHost.GasParameterConfig[4] memory c)
    {
        c[0] = _gas("SNAPSHOT_READ_GAS", 500000, 1);
        c[1] = _gas("SNAPSHOT_SOURCE_GAS", 2000000, 1);
        c[2] = _gas("SNAPSHOT_EVIDENCE_GAS", 2000000, 1);
        c[3] = _gas("SNAPSHOT_INVENTORY_GAS", 3000000, 1);
    }

    function _dependencies() internal view returns (StreamSnapshotTypes.Dependencies memory d) {
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(router),
            address(leaves),
            address(checkpoint),
            address(membership),
            address(coordinators)
        ];
        for (uint256 i; i < 9; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 2000000;
        d.evidenceGas = 2000000;
        d.inventoryGas = 3000000;
    }

    function _snapshotDocument(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw
    ) internal {
        bytes32[] memory chunks = _upload(raw);
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, keccak256(raw), schemas.RAW_BYTES(), 0, "", uint32(raw.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas), abi.encodeCall(schemas.registerDocument, (spec, chunks)), s, o, n
        );
    }

    function _upload(bytes memory raw) internal returns (bytes32[] memory chunks) {
        chunks = new bytes32[]((raw.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 length = raw.length - i * 8192;
            if (length > 8192) length = 8192;
            bytes memory part = new bytes(length);
            for (uint256 j; j < length; ++j) {
                part[j] = raw[i * 8192 + j];
            }
            (chunks[i],) = store.publishChunk(part);
        }
    }

    function _displayGrant(address account, bool enabled) internal {
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.familyWriterTransition(1, StreamRecordFamilies.IDENTITY, 7, account, enabled);
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter, (1, StreamRecordFamilies.IDENTITY, 7, account, enabled)
            ),
            s,
            o,
            n
        );
    }

    function _p() internal view returns (StreamSnapshotTypes.Publication memory p) {
        StreamSnapshotTypes.Receipt memory r = snapshots.currentSnapshot(1);
        p = StreamSnapshotTypes.Publication(
            1,
            keccak256(abi.encode("snapshot", r.revision)),
            r.recordHash,
            r.revision,
            0,
            inventoryPlan,
            "ipfs://snapshot-manifest",
            1000,
            keccak256("capture stable artwork")
        );
    }

    function _repeat(uint256 count) internal pure returns (string memory) {
        bytes memory out = new bytes(count);
        for (uint256 i; i < count; ++i) {
            out[i] = "x";
        }
        return string(out);
    }

    function _consumer() internal returns (ReferenceSourceSnapshotConsumer) {
        return new ReferenceSourceSnapshotConsumer(
            StreamFinalitySnapshotReads.Dependencies(
                address(core),
                address(metadata),
                address(snapshots),
                address(core).codehash,
                address(metadata).codehash,
                address(snapshots).codehash,
                block.chainid,
                500000,
                16000000
            )
        );
    }

    function _lock(bytes32 lockId) internal {
        (bytes32 s, bytes32 o, bytes32 n) = snapshots.lockTransition(1, lockId);
        cheat.mockCall(
            address(executor),
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
            abi.encode(true, keccak256(abi.encode("snapshot lock", lockId)), uint8(2), s, o, n)
        );
        vm.prank(address(executor));
        snapshots.lockSnapshots(1, lockId);
    }

    function _cool() internal {
        StreamSnapshotTypes.Dependencies memory d = _dependencies();
        for (uint256 i; i < 9; ++i) {
            safeVm.cool(d.targets[i]);
        }
        safeVm.cool(address(snapshots));
        safeVm.cool(address(first));
        safeVm.cool(address(second));
        safeVm.cool(address(archive));
        safeVm.cool(address(StreamRecordJson));
        safeVm.cool(address(StreamMetadataRenderer));
        safeVm.cool(address(StreamFinalitySnapshotReads));
    }

    function _publish(address publisher) internal returns (bytes32 hash, bytes memory canonical) {
        StreamSnapshotTypes.Publication memory p = _p();
        (p.expectedSourceHash, canonical) = snapshots.previewSnapshot(p, publisher);
        _upload(canonical);
        vm.prank(publisher);
        hash = snapshots.publishSnapshot(p);
    }
}

contract ReferenceSourceExportTest is ReferenceSourceExportFixture {
    /// @dev Actual Router output and actual complete native snapshot; Core/artist/seed/old archive remain explicit fixture boundaries.
    function testExportOriginalFirstAndLastRouterMetadataWithAuthenticatedSnapshot() public {
        (bytes32 hash, bytes memory canonical) = _publish(address(this));
        StreamFinalitySnapshotEvidence memory evidence =
            _consumer().read(_scope(), hash, snapshots.currentSnapshot(1).revision);
        require(evidence.recordHash == hash && evidence.sourceHash != 0);
        require(core.collectionMintedEver(1) == 2);
        cheat.createDir("reference-export", true);
        cheat.writeFile("reference-export/snapshot.json", string(canonical));
        cheat.writeFile(
            "reference-export/token-1.json", router.historicalTokenMetadataJSON(address(core), 1)
        );
        cheat.writeFile(
            "reference-export/token-2.json", router.historicalTokenMetadataJSON(address(core), 2)
        );
        cheat.writeFile(
            "reference-export/original-record.json",
            string.concat(
                '{"recordHash":',
                StreamSnapshotManifestJson.hashJSON(hash),
                ',"sourceHash":',
                StreamSnapshotManifestJson.hashJSON(evidence.sourceHash),
                ',"manifestHash":',
                StreamSnapshotManifestJson.hashJSON(evidence.manifestHash),
                ',"publisher":',
                StreamSnapshotManifestJson.accountJSON(address(this)),
                ',"collectionId":"1","firstSerial":"1","lastSerial":"2"}'
            )
        );
    }
}
