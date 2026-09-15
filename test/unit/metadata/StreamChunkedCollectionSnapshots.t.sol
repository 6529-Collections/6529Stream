// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamCollectionSnapshots.t.sol";
import {
    StreamChunkedCollectionSnapshots
} from "../../../smart-contracts/domains/metadata/StreamChunkedCollectionSnapshots.sol";
import {
    IStreamScriptBundles as B
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../../smart-contracts/interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    StreamChunkedSnapshotDefinitions as D
} from "../../../smart-contracts/domains/records/StreamChunkedSnapshotDefinitions.sol";
import {
    StreamMetadataTokenRenderer
} from "../../../smart-contracts/domains/metadata/StreamMetadataTokenRenderer.sol";

/// @notice Actual bundle admission/selection, snapshot, frozen policies, full checkpoint/leaf/root and Safe publication.
/// @dev Core/Executor/Artist/archive are the original explicit fixture boundaries; source cases await native execution.
contract StreamChunkedCollectionSnapshotsTest is CollectionSnapshotsFixture {
    bytes internal fullScript;
    bytes internal fullLibrary;
    bytes32 internal scriptId;
    bytes32 internal libraryId;

    function _bundle(bytes memory payload, bool isLibrary, bytes32 library_)
        internal
        returns (bytes32 id)
    {
        B.Plan memory p;
        p.payloadHash = keccak256(payload);
        p.sourceType = M.PayloadSourceType.SSTORE2;
        p.libraryOnly = isLibrary;
        p.libraryBundle = library_;
        p.chunkHashes = new bytes32[](2);
        p.chunkLengths = new uint32[](2);
        uint256 mid = payload.length / 2;
        bytes memory a = new bytes(mid);
        bytes memory b = new bytes(payload.length - mid);
        for (uint256 i; i < mid; ++i) {
            a[i] = payload[i];
        }
        for (uint256 i = mid; i < payload.length; ++i) {
            b[i - mid] = payload[i];
        }
        p.chunkHashes[0] = keccak256(a);
        p.chunkHashes[1] = keccak256(b);
        p.chunkLengths[0] = uint32(a.length);
        p.chunkLengths[1] = uint32(b.length);
        id = metadata.beginScriptBundle(p);
        metadata.appendScriptBundle(id, 0, a);
        metadata.appendScriptBundle(id, 1, b);
        metadata.finalizeScriptBundle(id);
    }

    function _profileSetup() internal override {
        _snapshotDocument(
            "STREAM_CHUNKED_ONCHAIN_SNAPSHOT_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_CHUNKED_ONCHAIN_SNAPSHOT_V1.json"))
        );
        _snapshotDocument(
            "STREAM_CHUNKED_ONCHAIN_SNAPSHOT_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(
                vm.readFile("schemas/records/STREAM_CHUNKED_ONCHAIN_SNAPSHOT_JSON_PROFILE_V1.json")
            )
        );
        fullScript = new bytes(9000);
        for (uint256 i; i < fullScript.length; ++i) {
            fullScript[i] = 0x20;
        }
        fullScript[0] = 0x2f;
        fullScript[1] = 0x2f;
        fullLibrary = bytes("const libraryValue=7;");
        libraryId = _bundle(fullLibrary, true, 0);
        scriptId = _bundle(fullScript, false, libraryId);
        B.Facts memory f = metadata.scriptBundle(scriptId);
        M.ScriptManifest memory m;
        m.scriptHash = f.payloadHash;
        m.rendererCompatibility = keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1");
        m.sourceType = f.sourceType;
        m.sourcePointer = Strings.toHexString(uint256(scriptId), 32);
        m.mimeType = "application/javascript";
        m.chunkCount = f.chunkCount;
        m.executable = true;
        m.scriptURI = "ipfs://mirror";
        // Actual pre-mint bootstrap is used only for selecting this test collection's payload.
        core.setMinted(0);
        router.setCollectionScriptManifest(1, m);
        core.setMinted(1);
    }

    function _profileLocks() internal pure override returns (bytes32[] memory locks) {
        locks = new bytes32[](4);
        locks[0] = keccak256("SCRIPT");
        locks[1] = keccak256("MEDIA_MANIFEST");
        locks[2] = keccak256("BASE_URI");
        locks[3] = keccak256("DEPENDENCIES");
    }

    function _checkpointRenderGas() internal pure override returns (uint256) {
        return 80000000;
    }

    function _beginCheckpoint() internal override returns (bytes32) {
        return checkpoint.beginChunkedCollectionCheckpoint(1);
    }

    function _createSnapshotHost() internal override returns (StreamCollectionSnapshots) {
        IStreamGasParameterHost.GasParameterConfig[4] memory c = _configs();
        c[1].genesisValue = 20000000;
        c[2].genesisValue = 80000000;
        return new StreamChunkedCollectionSnapshots(_dependencies(), address(executor), c);
    }

    function _checkpointHTML(uint256 id) internal view override returns (bytes memory) {
        return abi.encodePacked(
            "<html><head></head><body><script>const tokenId=",
            Strings.toString(id),
            ";const tokenHash='",
            Strings.toHexString(uint256(77), 32),
            "';const tokenDataBase64='AP8=';",
            StreamMetadataTokenRenderer.prepareScript(
                string(bytes.concat(fullLibrary, bytes("\n;\n"), fullScript))
            ),
            "</script></body></html>"
        );
    }

    function testChunkedSnapshotEmbedsBothPayloadsAndDistinctLiteralRecord() public {
        (bytes32 hash, bytes memory raw) = _publish(address(this));
        StreamSnapshotTypes.Receipt memory r = snapshots.requireCurrent(1, hash, 1);
        require(r.schemaDefinitionHash == D.SCHEMA_HASH && r.manifestHash == keccak256(raw));
        require(abi.decode(vm.parseJson(string(raw), ".version"), (uint256)) == 2);
        require(
            keccak256(bytes(abi.decode(vm.parseJson(string(raw), ".script.chunkCount"), (string))))
                == keccak256("2")
        );
        require(
            keccak256(
                bytes(
                    abi.decode(
                        vm.parseJson(string(raw), ".script.chunks[0].contentBase64"), (string)
                    )
                )
            ) == keccak256(bytes(Base64.encode(metadata.scriptBundleChunk(scriptId, 0))))
        );
        require(
            keccak256(
                bytes(
                    abi.decode(
                        vm.parseJson(string(raw), ".library.chunks[1].contentBase64"), (string)
                    )
                )
            ) == keccak256(bytes(Base64.encode(metadata.scriptBundleChunk(libraryId, 1))))
        );
        (StreamSnapshotTypes.Publication memory p, StreamSnapshotTypes.Receipt memory saved) =
            snapshots.snapshotRecord(hash);
        saved.recordHash = 0;
        saved.recordChainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CHUNKED_SNAPSHOT_RECORD_V1"),
                        block.chainid,
                        address(snapshots),
                        address(core),
                        address(metadata),
                        p,
                        saved
                    )
                )
        );
        require(keccak256(snapshots.snapshotManifestBytes(hash)) == keccak256(raw));
        StreamFinalitySnapshotReads.Dependencies memory d = StreamFinalitySnapshotReads.Dependencies(
            address(core),
            address(metadata),
            address(snapshots),
            address(core).codehash,
            address(metadata).codehash,
            address(snapshots).codehash,
            block.chainid,
            500000,
            100000000
        );
        StreamFinalitySnapshotEvidence memory e =
            StreamFinalitySnapshotReads.requireCurrentChunked(d, _scope(), hash, 1);
        require(
            e.recordHash == hash && e.manifestHash == keccak256(raw)
                && e.schemaHash == D.SCHEMA_HASH && !e.locked
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamFinalitySnapshotReads.InvalidSnapshotEvidence.selector)
        );
        StreamFinalitySnapshotReads.requireCurrent(d, _scope(), hash, 1);
        cheat.writeFile("chunked-snapshot-example.json", string(raw));
    }

    function testChunkedSnapshotChangedLogicalBytesRejectThenIdenticalPublicationRetries() public {
        StreamSnapshotTypes.Publication memory p = _p();
        bytes memory raw;
        (p.expectedSourceHash, raw) = snapshots.previewSnapshot(p, address(this));
        _upload(raw);
        bytes memory original = metadata.scriptBundleChunk(scriptId, 0);
        cheat.mockCall(
            address(metadata),
            abi.encodeCall(B.scriptBundleChunk, (scriptId, 0)),
            abi.encode(bytes("wrong bytes"))
        );
        vm.expectRevert();
        snapshots.publishSnapshot(p);
        require(snapshots.snapshotCount(1) == 0);
        cheat.mockCall(
            address(metadata),
            abi.encodeCall(B.scriptBundleChunk, (scriptId, 0)),
            abi.encode(original)
        );
        bytes32 hash = snapshots.publishSnapshot(p);
        require(
            snapshots.latestSnapshotHash(1) == keccak256(raw)
                && snapshots.requireCurrent(1, hash, 1).recordHash == hash
        );
    }

    function testChunkedSnapshotStrictInlineHostAndWrongSourceNeverAdvance() public {
        StreamCollectionSnapshots inlineHost =
            new StreamCollectionSnapshots(_dependencies(), address(executor), _configs());
        StreamSnapshotTypes.Publication memory p = _p();
        vm.expectRevert();
        inlineHost.previewSnapshot(p, address(this));
        (p.expectedSourceHash,) = snapshots.previewSnapshot(p, address(this));
        p.expectedSourceHash = keccak256(abi.encode(p.expectedSourceHash));
        vm.expectRevert();
        snapshots.publishSnapshot(p);
        require(snapshots.snapshotCount(1) == 0 && inlineHost.snapshotCount(1) == 0);
    }

    function testChunkedSnapshotSavedBytesRemainButMetadataOwnerDriftBlocksCurrent() public {
        (bytes32 hash, bytes memory raw) = _publish(address(this));
        bytes memory original = address(metadata).code;
        vm.etch(address(metadata), hex"00");
        require(keccak256(snapshots.snapshotManifestBytes(hash)) == keccak256(raw));
        vm.expectRevert();
        snapshots.requireCurrent(1, hash, 1);
        vm.etch(address(metadata), original);
        require(snapshots.requireCurrent(1, hash, 1).recordHash == hash);
    }

    function executeChunkedSafe(OfficialSafe safe, uint256[] memory keys, bytes memory data)
        external
        returns (bool)
    {
        require(msg.sender == address(this));
        return executeSafe(safe, keys, address(snapshots), 0, data, 0);
    }

    function testChunkedSnapshotActualSafeMissingChunkRollsBackAndExactSignedRetry() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 3311;
        keys[1] = 3312;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 3313);
        _grant(0, 8, address(safe), true);
        _displayGrant(address(safe), true);
        StreamSnapshotTypes.Publication memory p = _p();
        bytes memory raw;
        (p.expectedSourceHash, raw) = snapshots.previewSnapshot(p, address(safe));
        bytes memory call_ = abi.encodeCall(snapshots.publishSnapshot, (p));
        uint256 nonce = safe.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeChunkedSafe(safe, keys, call_);
        require(safe.nonce() == nonce && snapshots.snapshotCount(1) == 0);
        _upload(raw);
        require(this.executeChunkedSafe(safe, keys, call_));
        StreamSnapshotTypes.Receipt memory r = snapshots.currentSnapshot(1);
        require(
            r.publisher == address(safe) && r.authorizationClass == 8
                && r.displayAuthorizationClass == 7 && r.manifestHash == keccak256(raw)
        );
    }

    function testChunkedSnapshotNewRevisionRetainsOriginalBytesAndCurrentSource() public {
        (bytes32 oldHash, bytes memory oldRaw) = _publish(address(this));
        (bytes32 hash,) = _publish(address(this));
        require(
            hash != oldHash
                && keccak256(snapshots.snapshotManifestBytes(oldHash)) == keccak256(oldRaw)
        );
        vm.expectRevert();
        snapshots.requireCurrent(1, oldHash, 1);
        require(snapshots.requireCurrent(1, hash, 2).predecessor == oldHash);
    }
}
