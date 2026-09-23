// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewPreservationCheckpointFixtureV1.sol";
import {
    StreamViewPreservationSnapshotPublicationV1 as SnapshotHost
} from "../../../smart-contracts/domains/metadata/StreamViewPreservationSnapshotPublicationV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as SS
} from "../../../smart-contracts/interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as SD
} from "../../../smart-contracts/domains/records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import {
    StreamFinalityViewPreservationSnapshotReadsV1 as Reader
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationSnapshotReadsV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as MT
} from "../../../smart-contracts/interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    IStreamViewPreservationOutputManifestV1 as ManifestAPI
} from "../../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationOutputManifestV1.sol";
import {
    IStreamMetadataServingFacts as Artist
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamMetadataRouter as RouterAPI
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    StreamSnapshotManifestBytes as Stored
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";

interface SnapshotTestVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
}

contract ViewSnapshotReaderProbe {
    function current(
        Reader.Dependencies memory d,
        StreamFinalityScope memory scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (Reader.Evidence memory) {
        return Reader.requireCurrent(d, scope, hash, revision);
    }
}

/// @notice Actual new Snapshot/Store/current reader/checkpoint/Renderer; explicit typed Metadata,
/// Schema, Artist, membership, manifest/coverage and governance boundaries. No real op17/finality.
contract StreamViewPreservationSnapshotPublicationV1Test is ViewPreservationCheckpointFixtureV1 {
    SnapshotHost private snapshots;
    ViewSnapshotReaderProbe private reader;
    PolicyViewWire private manifests;
    SS.Dependencies private deps;
    SS.Publication private publication;
    MT.Plan private manifest;
    Artist.ArtistPresentation private artist;
    uint256 private savedChain;

    function _init() private {
        _build(1, 0);
        savedChain = block.chainid;
        bytes32 id = checkpointHost.begin(scope, keccak256("root-free snapshot output"));
        _append(id, 11, false);
        checkpointHost.seal(id);
        CT.Plan memory cp = checkpointHost.checkpoint(id);
        manifests = new PolicyViewWire();
        manifest.header = MT.Header(
            id,
            keccak256(abi.encode(cp)),
            scope,
            adopted,
            cp.sourceContextHash,
            cp.membershipHash,
            cp.policyChainHash,
            cp.tokenCount,
            cp.outputRoot,
            cp.contentRoot
        );
        artist = Artist.ArtistPresentation(
            true,
            address(core),
            address(core).codehash,
            keccak256("typed locked Artist"),
            1,
            keccak256("binding"),
            address(0xA),
            keccak256("identity"),
            keccak256("acceptance"),
            100,
            200,
            keccak256("locked Artist snapshot")
        );
        SnapshotTestVm(address(vm))
            .mockCall(
                address(records),
                abi.encodeCall(Artist.artistPresentation, (uint256(1))),
                abi.encode(artist)
            );
        manifest.carrier = MT.Carrier(
            keccak256("actual artifact at boundary"),
            keccak256("coverage"),
            artist.artistId,
            keccak256("complete covered index"),
            960
        );
        manifest.partCount = 1;
        manifest.nextPart = 1;
        manifest.nextRow = 1;
        manifest.previousToken = 11;
        manifest.partChain = keccak256("complete parts");
        manifest.recordHash = keccak256("covered manifest record");
        MT.Configuration memory mc = MT.Configuration(
            address(core),
            address(core).codehash,
            address(checkpointHost),
            address(checkpointHost).codehash,
            checkpointHost.configurationHash(),
            address(core),
            address(core).codehash,
            address(core),
            address(core).codehash,
            block.chainid,
            1000000,
            14000000
        );
        _answer(manifests, "configuration()", "", abi.encode(mc));
        _answer(manifests, "outputProfile()", "", abi.encode(MT.PROFILE));
        _answer(
            manifests,
            "supportsInterface(bytes4)",
            abi.encode(type(ManifestAPI).interfaceId),
            abi.encode(true)
        );
        _manifest(manifest);
        _module(address(core), "COLLECTION_METADATA", type(Metadata).interfaceId);
        _module(address(records), "METADATA_ROUTER", type(RouterAPI).interfaceId);
        string[4] memory hashes = [
            "coreCodeHash()",
            "schemaRegistryCodeHash()",
            "executorCodeHash()",
            "metadataHostCodeHash()"
        ];
        for (uint256 i; i < 4; ++i) {
            _answer(core, hashes[i], "", abi.encode(address(core).codehash));
        }
        _answer(core, "chunkStoreCodeHash()", "", abi.encode(address(store).codehash));
        _answer(core, "isStreamGovernedParameterAuthority()", "", abi.encode(true));
        _action(false, 0, 0, 0, 0, 0);
        _definitionChunks(
            SD.SCHEMA_ID,
            Schema.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/metadata/view-preservation-snapshot-v1/schema.json"))
        );
        _definitionChunks(
            SD.PROFILE_ID,
            Schema.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/metadata/view-preservation-snapshot-v1/profile.json"))
        );
        _definitionChunks(
            SD.CANON_ID,
            Schema.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/metadata/view-preservation-snapshot-v1/canon.json"))
        );
        for (uint256 i; i < 10; ++i) {
            deps.targets[i] = address(core);
        }
        deps.targets[3] = address(store);
        deps.targets[4] = address(records);
        deps.targets[6] = address(checkpointHost);
        deps.targets[7] = address(manifests);
        for (uint256 i; i < 10; ++i) {
            deps.codeHashes[i] = deps.targets[i].codehash;
        }
        deps.chainId = block.chainid;
        deps.readGas = 1000000;
        deps.sourceGas = 16000000;
        deps.inventoryGas = 2000000;
        G.GasParameterConfig[3] memory gas;
        gas[0] = G.GasParameterConfig("VIEW_PRESERVATION_SNAPSHOT_READ_GAS", deps.readGas, 50000, 2);
        gas[1] =
            G.GasParameterConfig("VIEW_PRESERVATION_SNAPSHOT_SOURCE_GAS", deps.sourceGas, 50000, 2);
        gas[2] = G.GasParameterConfig(
            "VIEW_PRESERVATION_SNAPSHOT_INVENTORY_GAS", deps.inventoryGas, 50000, 2
        );
        snapshots = new SnapshotHost(deps, address(core), gas);
        reader = new ViewSnapshotReaderProbe();
        publication = SS.Publication(
            scope,
            keccak256("snapshot one"),
            0,
            0,
            manifest.recordHash,
            adopted,
            0,
            "ipfs://complete-view-snapshot",
            100,
            keccak256("publication reason")
        );
        _grants(address(this), true, true);
    }

    function _module(address target, string memory role, bytes4 id) private {
        bytes32 kind = keccak256(bytes(role));
        _answer(
            core,
            "getSatellitePointer(bytes32)",
            abi.encode(kind),
            abi.encode(
                target,
                target.codehash,
                false,
                kind,
                id,
                address(core),
                uint8(1),
                keccak256("module manifest"),
                keccak256("deployment"),
                uint64(1)
            )
        );
        bytes memory support = abi.encodeWithSignature("supportsInterface(bytes4)", id);
        if (target == address(core)) {
            _answer(core, "supportsInterface(bytes4)", abi.encode(id), abi.encode(true));
            _answer(core, "streamModuleType()", "", abi.encode(kind));
            _answer(core, "streamModuleInterfaceId()", "", abi.encode(id));
        } else {
            SnapshotTestVm(address(vm)).mockCall(target, support, abi.encode(true));
            SnapshotTestVm(address(vm))
                .mockCall(target, abi.encodeWithSignature("streamModuleType()"), abi.encode(kind));
            SnapshotTestVm(address(vm))
                .mockCall(
                    target, abi.encodeWithSignature("streamModuleInterfaceId()"), abi.encode(id)
                );
        }
        _answer(
            core,
            "isModuleEligible(address,bytes32,bytes4)",
            abi.encode(target, kind, id),
            abi.encode(true)
        );
    }

    function _action(
        bool executing,
        bytes32 id,
        uint8 cls,
        bytes32 scope_,
        bytes32 old_,
        bytes32 next
    ) private {
        _answer(core, "currentAction()", "", abi.encode(executing, id, cls, scope_, old_, next));
    }

    function _manifest(MT.Plan memory value) private {
        _answer(
            manifests,
            "requireCurrentManifest(bytes32,bytes32)",
            abi.encode(manifest.recordHash, artist.artistId),
            abi.encode(value)
        );
    }

    function _grants(address actor, bool local, bool global_) private {
        bytes32[2] memory families = [keccak256("SNAPSHOT"), keccak256("IDENTITY")];
        for (uint256 i; i < 2; ++i) {
            _answer(
                core,
                "familyWriter(uint256,bytes32,uint8,address)",
                abi.encode(uint256(1), families[i], uint8(7), actor),
                abi.encode(local, uint64(7))
            );
            _answer(
                core,
                "familyWriter(uint256,bytes32,uint8,address)",
                abi.encode(uint256(0), families[i], uint8(8), actor),
                abi.encode(global_, uint64(9))
            );
        }
    }

    function _definitionChunks(bytes32 id, Schema.DocumentKind kind, bytes memory body) private {
        uint256 count = (body.length + 8191) / 8192;
        _answer(
            core,
            "documentFacts(bytes32)",
            abi.encode(id),
            abi.encode(
                Facts.DocumentFacts(
                    true,
                    kind,
                    Schema.DocumentStatus.ACTIVE,
                    keccak256(body),
                    keccak256("RAW_BYTES"),
                    0,
                    uint32(body.length),
                    uint16(count),
                    keccak256("typed declaration")
                )
            )
        );
        for (uint256 i; i < count; ++i) {
            bytes memory part = _part(body, i * 8192);
            (bytes32 hash,) = store.publishChunk(part);
            _answer(
                core, "documentChunkHashAt(bytes32,uint256)", abi.encode(id, i), abi.encode(hash)
            );
        }
    }

    function _part(bytes memory body, uint256 offset) private pure returns (bytes memory part) {
        uint256 n = body.length - offset;
        if (n > 8192) n = 8192;
        part = new bytes(n);
        for (uint256 i; i < n; ++i) {
            part[i] = body[offset + i];
        }
    }

    function _prepare() private returns (bytes memory canonical) {
        (publication.expectedSourceHash, canonical) =
            snapshots.previewSnapshot(publication, address(this));
        for (uint256 i; i < canonical.length; i += 8192) {
            store.publishChunk(_part(canonical, i));
        }
    }

    function _reader() private view returns (Reader.Dependencies memory) {
        return Reader.Dependencies(
            address(core),
            address(core),
            address(snapshots),
            address(core).codehash,
            address(core).codehash,
            address(snapshots).codehash,
            savedChain,
            1000000,
            16000000
        );
    }

    function testActualRootFreePublicationLiteralRecordPayloadAndFullCurrentReader() public {
        _init();
        bytes memory canonical = _prepare();
        bytes32 key = snapshots.publishSnapshot(publication);
        (SS.Publication memory p, SS.Receipt memory r) = snapshots.snapshotRecord(key);
        require(
            keccak256(abi.encode(p)) == keccak256(abi.encode(publication))
                && keccak256(snapshots.snapshotPayload(key)) == keccak256(canonical),
            "exact full input and payload"
        );
        bytes32 chain = r.chainHash;
        r.recordHash = 0;
        r.chainHash = 0;
        require(
            key
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_SNAPSHOT_RECORD_V1"),
                        savedChain,
                        address(snapshots),
                        address(core),
                        address(core),
                        p,
                        r
                    )
                ),
            "literal original snapshot record"
        );
        require(
            chain
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_SNAPSHOT_CHAIN_V1"),
                        savedChain,
                        address(snapshots),
                        address(core),
                        scope,
                        bytes32(0),
                        uint64(1),
                        key
                    )
                ),
            "literal chain"
        );
        Reader.Evidence memory e = reader.current(_reader(), scope, key, 1);
        require(
            e.receipt.recordHash == key && e.source.adoption.adoption.recordHash == adopted
                && e.source.entropy.policies.length == 1 && !e.locked,
            "full typed root-free current source"
        );
        require(
            e.source.checkpoint.contentRoot == manifest.header.contentRoot
                && e.source.outputs.recordHash == manifest.recordHash,
            "complete outputs remain independent of future root"
        );
    }

    function testBothGrantsPreferCollectionAndGlobalFallbackUsesNewRevision() public {
        _init();
        _prepare();
        bytes32 first = snapshots.publishSnapshot(publication);
        require(snapshots.currentSnapshot(scope).authorizationClass == 7, "collection priority");
        _grants(address(this), false, true);
        publication.expectedHead = first;
        publication.expectedRevision = 1;
        publication.snapshotId = keccak256("second");
        _prepare();
        snapshots.publishSnapshot(publication);
        SS.Receipt memory r = snapshots.currentSnapshot(scope);
        require(
            r.authorizationClass == 8 && r.displayAuthorizationClass == 8 && r.grantRevision == 9
                && r.revision == 2,
            "global actual publish"
        );
    }

    function testMissingLastPayloadChunkRollsBackThenExactRetry() public {
        _init();
        bytes memory canonical;
        (publication.expectedSourceHash, canonical) =
            snapshots.previewSnapshot(publication, address(this));
        uint256 chunks = (canonical.length + 8191) / 8192;
        require(chunks > 1, "multi-chunk canonical source");
        for (uint256 i; i + 1 < chunks; ++i) {
            store.publishChunk(_part(canonical, i * 8192));
        }
        bytes32 last = keccak256(_part(canonical, (chunks - 1) * 8192));
        vm.expectRevert(abi.encodeWithSelector(Stored.SnapshotChunkUnavailable.selector, last));
        snapshots.publishSnapshot(publication);
        require(
            snapshots.snapshotCount(scope) == 0 && snapshots.currentSnapshot(scope).recordHash == 0,
            "no head/ID on late failure"
        );
        store.publishChunk(_part(canonical, (chunks - 1) * 8192));
        bytes32 key = snapshots.publishSnapshot(publication);
        require(key != 0 && snapshots.snapshotCount(scope) == 1, "same input retry");
    }

    function testCurrentDriftRefusesButHistoricalBytesRestoreExactly() public {
        _init();
        bytes memory bytes_ = _prepare();
        bytes32 key = snapshots.publishSnapshot(publication);
        MT.Plan memory changed = abi.decode(abi.encode(manifest), (MT.Plan));
        changed.partChain = keccak256("different covered index parts");
        _manifest(changed);
        (bool ok,) = address(snapshots)
            .staticcall(abi.encodeCall(snapshots.requireCurrent, (scope, key, uint64(1))));
        require(!ok, "current source drift");
        require(keccak256(snapshots.snapshotPayload(key)) == keccak256(bytes_), "historical intact");
        _manifest(manifest);
        require(snapshots.requireCurrent(scope, key, 1).recordHash == key, "exact restore");
    }

    function testActualStoredCarrierTamperRefusalAndRestore() public {
        _init();
        _prepare();
        bytes32 key = snapshots.publishSnapshot(publication);
        (address pointer,,) = snapshots.snapshotChunkAt(key, 0);
        bytes memory original = pointer.code;
        vm.etch(pointer, hex"0001");
        vm.expectRevert(abi.encodeWithSelector(Stored.SnapshotChunkChanged.selector, pointer));
        snapshots.snapshotPayload(key);
        vm.etch(pointer, original);
        require(
            reader.current(_reader(), scope, key, 1).receipt.recordHash == key,
            "restored complete current read"
        );
    }

    function testLockRequiresOriginalClassTwoContextAndCurrentSource() public {
        _init();
        _prepare();
        bytes32 key = snapshots.publishSnapshot(publication);
        (bytes32 scope_, bytes32 old_, bytes32 next) = snapshots.lockTransition(scope);
        _action(true, keccak256("action"), 1, scope_, old_, next);
        vm.prank(address(core));
        vm.expectRevert(
            abi.encodeWithSelector(SS.ViewPreservationSnapshotAuthority.selector, address(core))
        );
        snapshots.lockSnapshot(scope);
        _action(true, keccak256("action"), 2, scope_, old_, next);
        vm.prank(address(core));
        snapshots.lockSnapshot(scope);
        require(reader.current(_reader(), scope, key, 1).locked, "actual class2 terminal lock");
        vm.expectRevert(
            abi.encodeWithSelector(
                SS.ViewPreservationSnapshotLocked.selector, membership.scopeSubject
            )
        );
        snapshots.publishSnapshot(publication);
    }

    function testAuthorityScopeAndChainDoNotAlias() public {
        _init();
        _grants(address(this), false, false);
        vm.expectRevert(
            abi.encodeWithSelector(SS.ViewPreservationSnapshotAuthority.selector, address(this))
        );
        snapshots.previewSnapshot(publication, address(this));
        _grants(address(this), true, true);
        SS.Publication memory wrong = publication;
        wrong.scope = StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, scope.scopeId);
        vm.expectRevert(abi.encodeWithSelector(SS.InvalidViewPreservationSnapshot.selector));
        snapshots.previewSnapshot(wrong, address(this));
        _prepare();
        bytes32 key = snapshots.publishSnapshot(publication);
        vm.chainId(savedChain + 1);
        (bool ok,) = address(reader)
            .staticcall(abi.encodeCall(reader.current, (_reader(), scope, key, uint64(1))));
        require(!ok, "chain bound");
        vm.chainId(savedChain);
        require(snapshots.requireCurrent(scope, key, 1).recordHash == key, "restore");
    }
}
