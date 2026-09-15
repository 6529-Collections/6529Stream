// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScriptBundles as B
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";

import { StreamCollectionMetadataV1 } from "./StreamCollectionMetadataV1.sol";
import { StreamMetadataGovernance } from "./StreamMetadataGovernance.sol";
import { StreamRecordFamilies } from "../records/StreamRecordFamilies.sol";
import { StreamScriptBundles } from "./StreamScriptBundles.sol";
import { StreamCollectionManifests } from "./StreamCollectionManifests.sol";
import { StreamSchemaDocumentStore } from "./StreamSchemaDocumentStore.sol";
import { StreamRecordDocumentReads } from "../records/StreamRecordDocumentReads.sol";
import {
    IStreamCollectionMetadataV1 as V
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamCollectionManifestWriter as W,
    IStreamMetadataManifestSelection
} from "../../interfaces/stream/metadata/IStreamCollectionManifestWriter.sol";
import {
    IStreamCollectionManifestReads as R
} from "../../interfaces/stream/metadata/IStreamCollectionManifestReads.sol";
import {
    IStreamMetadataServingFacts
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamCoreCollectionView
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

interface IStreamRecordedCollectionManifests {
    function recordedScriptManifest(bytes32 hash) external view returns (M.ScriptManifest memory);
    function recordedMediaManifest(bytes32 hash) external view returns (M.MediaManifest memory);
}

/// @notice Fixed manifest execution in the original MetadataV1 caller/storage context.
/// @dev Host selectors keep their original ABI; raw encoded returns avoid duplicated dynamic codecs.
library StreamCollectionManifestExecution {
    using StreamRecordFamilies for bytes32;

    struct Context {
        address core;
        bytes32 coreCodeHash;
        address chunkStore;
        bytes32 chunkStoreCodeHash;
    }
    bytes32 private constant _TYPE = keccak256("COLLECTION_METADATA");
    bytes32 private constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 private constant ARTIST_READ_GAS = keccak256("6529STREAM_GGP_METADATA_ARTIST_READ_GAS");
    event CollectionManifestStored(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed kind,
        bytes32 indexed manifestHash,
        address router,
        bytes32 servingSourceHash
    );

    function recordTypeTransition(
        mapping(bytes32 => V.RecordPolicy) storage _policies,
        address authority,
        bytes32 authorityCodeHash,
        bytes32 recordType,
        bytes32 family,
        uint16 mask
    ) public view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        uint16 allowed = family.allowed();
        // WORK_DESCRIPTION shares curatorial storage, with a separate artist op-24 path.
        if (recordType == keccak256("WORK_DESCRIPTION") && family == StreamRecordFamilies.CURATOR) {
            allowed |= StreamRecordFamilies.bit(1);
        }
        if (
            recordType == 0 || _policies[recordType].admitted || mask == 0 || allowed == 0
                || (mask & ~allowed) != 0
                || (recordType == keccak256("WORK_DESCRIPTION")
                    && family != StreamRecordFamilies.CURATOR)
        ) revert V.InvalidMetadataRecord();
        // These families have dedicated permanent hosts or typed intersection rules.
        if (
            family == StreamRecordFamilies.SNAPSHOT || family == StreamRecordFamilies.INDEPENDENT
                || family == StreamRecordFamilies.OWNER
        ) revert V.InvalidMetadataRecord();
        scope = StreamMetadataGovernance.configurationScope(
            authority,
            authorityCodeHash,
            IStreamGasParameterHost(address(this)).gasParameter(DEPENDENCY_READ_GAS),
            recordType
        );
        oldHash = keccak256(abi.encode(false));
        newHash = keccak256(abi.encode(V.RecordPolicy(family, mask, true)));
    }

    function familyWriterTransition(
        mapping(bytes32 => StreamCollectionMetadataV1.Grant) storage _grants,
        Context memory x,
        address authority,
        bytes32 authorityCodeHash,
        uint256 collectionId,
        bytes32 family,
        uint8 authClass,
        address account,
        bool enabled
    ) public view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        if (
            account == address(0) || authClass < 3 || authClass > 8 || authClass == 5
                || (family.allowed() & StreamRecordFamilies.bit(authClass)) == 0
        ) revert V.MetadataAuthorityRequired();
        if (collectionId != 0) _requireCollection(x, collectionId);
        bytes32 key = _grantKey(collectionId, family, authClass, account);
        StreamCollectionMetadataV1.Grant memory g = _grants[key];
        if (g.enabled == enabled || g.revision == type(uint64).max) {
            revert V.InvalidMetadataRecord();
        }
        scope = StreamMetadataGovernance.configurationScope(
            authority,
            authorityCodeHash,
            IStreamGasParameterHost(address(this)).gasParameter(DEPENDENCY_READ_GAS),
            key
        );
        oldHash = keccak256(abi.encode(g));
        newHash = keccak256(abi.encode(StreamCollectionMetadataV1.Grant(enabled, g.revision + 1)));
    }

    function _grantKey(uint256 collectionId, bytes32 family, uint8 authClass, address account)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(collectionId, family, authClass, account));
    }

    /// @dev This type-only host dependency preserves the original storage struct definition.
    function receipt(StreamCollectionMetadataV1.StoredRecord storage s)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.receipt);
    }

    function payload(
        StreamCollectionMetadataV1.StoredRecord storage s,
        address store,
        bytes32 storeCodeHash,
        uint256 cap
    ) public view returns (address pointer, bytes memory value) {
        bytes32 contentHash = bytes32(s.record.contentHash.digest);
        (pointer,) = StreamSchemaDocumentStore(store).chunk(contentHash);
        // Preserve original pointer lookup before the original code/read guard.
        if (store.code.length == 0 || store.codehash != storeCodeHash) {
            revert V.MetadataDependencyChanged(store);
        }
        value = StreamRecordDocumentReads.chunk(store, contentHash, cap);
    }

    function record(StreamCollectionMetadataV1.StoredRecord storage s)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(s.record, s.receipt);
    }

    function read(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        bytes calldata data
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(data);
        if (selector == W.previewScriptManifest.selector) {
            (uint256 id, M.ScriptManifest memory value) =
                abi.decode(data[4:], (uint256, M.ScriptManifest));
            return abi.encode(previewScriptManifest(_manifests, x, id, value));
        }
        if (selector == W.previewMediaManifest.selector) {
            (uint256 id, M.MediaManifest memory value) =
                abi.decode(data[4:], (uint256, M.MediaManifest));
            return abi.encode(previewMediaManifest(x, id, value));
        }
        if (selector == B.scriptChunkCount.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            return abi.encode(scriptManifest(_manifests, x, id).chunkCount);
        }
        if (selector == R.scriptManifestHash.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            return abi.encode(scriptManifestHash(_manifests, x, id));
        }
        if (selector == R.mediaManifestHash.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            return abi.encode(mediaManifestHash(_manifests, x, id));
        }
        if (selector == R.scriptManifest.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            return abi.encode(scriptManifest(_manifests, x, id));
        }
        if (selector == R.mediaManifest.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            return abi.encode(mediaManifest(_manifests, x, id));
        }
        if (selector == R.scriptChunk.selector) {
            (uint256 id, uint256 index) = abi.decode(data[4:], (uint256, uint256));
            return abi.encode(scriptChunk(_manifests, x, id, index));
        }
        if (selector == IStreamRecordedCollectionManifests.recordedScriptManifest.selector) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return abi.encode(recordedScriptManifest(_manifests, hash));
        }
        if (selector == IStreamRecordedCollectionManifests.recordedMediaManifest.selector) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return abi.encode(recordedMediaManifest(_manifests, hash));
        }
        return StreamScriptBundles.read(_manifests.bundles, data);
    }

    function write(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        bytes calldata data
    ) public returns (bytes memory) {
        bytes4 selector = bytes4(data);
        if (selector == W.storeScriptManifest.selector) {
            (uint256 id, M.ScriptManifest memory value) =
                abi.decode(data[4:], (uint256, M.ScriptManifest));
            return abi.encode(storeScriptManifest(_manifests, x, id, value));
        }
        if (selector == W.storeMediaManifest.selector) {
            (uint256 id, M.MediaManifest memory value) =
                abi.decode(data[4:], (uint256, M.MediaManifest));
            return abi.encode(storeMediaManifest(_manifests, x, id, value));
        }
        return StreamScriptBundles.write(_manifests.bundles, data);
    }

    function previewScriptManifest(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        uint256 collectionId,
        M.ScriptManifest memory value
    ) private view returns (bytes32 hash) {
        address router = _manifestRouter(x, collectionId);
        if (value.rendererCompatibility == StreamScriptBundles.PROFILE) {
            (hash,) = StreamScriptBundles.manifest(
                _manifests.bundles, x.core, router, collectionId, value
            );
            return hash;
        }
        (hash,) = StreamCollectionManifests.script(
            x.core, router, collectionId, value, _manifestSource(x, router, collectionId)
        );
    }

    function previewMediaManifest(
        Context memory x,
        uint256 collectionId,
        M.MediaManifest memory value
    ) private view returns (bytes32 hash) {
        address router = _manifestRouter(x, collectionId);
        (hash,) = StreamCollectionManifests.media(
            x.core, router, collectionId, value, _manifestSource(x, router, collectionId)
        );
    }

    function storeScriptManifest(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        uint256 collectionId,
        M.ScriptManifest memory value
    ) private returns (bytes32 hash) {
        address router = _manifestRouter(x, collectionId);
        if (msg.sender != router) revert V.MetadataAuthorityRequired();
        if (value.rendererCompatibility == StreamScriptBundles.PROFILE) {
            bytes32 bundle;
            (hash, bundle) = StreamScriptBundles.manifest(
                _manifests.bundles, x.core, router, collectionId, value
            );
            if (_manifests.entries[hash].router == address(0)) {
                _manifests.scripts[hash] = value;
                _manifests.bundles.manifests[hash] = bundle;
                _manifests.entries[hash] =
                    StreamCollectionManifests.Entry(collectionId, router, value.scriptHash, 2);
                emit CollectionManifestStored(1, collectionId, 2, hash, router, value.scriptHash);
            }
            return hash;
        }
        IStreamMetadataServingFacts.ServingSource memory source =
            _manifestSource(x, router, collectionId);
        bytes32 sourceHash;
        (hash, sourceHash) =
            StreamCollectionManifests.script(x.core, router, collectionId, value, source);
        if (_manifests.entries[hash].router == address(0)) {
            StreamSchemaDocumentStore(x.chunkStore).publishChunk(bytes(source.script));
            _manifests.scripts[hash] = value;
            _manifests.entries[hash] =
                StreamCollectionManifests.Entry(collectionId, router, sourceHash, 2);
            emit CollectionManifestStored(1, collectionId, 2, hash, router, sourceHash);
        }
    }

    function storeMediaManifest(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        uint256 collectionId,
        M.MediaManifest memory value
    ) private returns (bytes32 hash) {
        address router = _manifestRouter(x, collectionId);
        if (msg.sender != router) revert V.MetadataAuthorityRequired();
        bytes32 sourceHash;
        (hash, sourceHash) = StreamCollectionManifests.media(
            x.core, router, collectionId, value, _manifestSource(x, router, collectionId)
        );
        if (_manifests.entries[hash].router == address(0)) {
            _manifests.media[hash] = value;
            _manifests.entries[hash] =
                StreamCollectionManifests.Entry(collectionId, router, sourceHash, 3);
            emit CollectionManifestStored(1, collectionId, 3, hash, router, sourceHash);
        }
    }

    function scriptManifestHash(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        uint256 collectionId
    ) private view returns (bytes32) {
        return _selectedManifest(_manifests, x, collectionId, 2);
    }

    function mediaManifestHash(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        uint256 collectionId
    ) private view returns (bytes32) {
        return _selectedManifest(_manifests, x, collectionId, 3);
    }

    function scriptManifest(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        uint256 collectionId
    ) private view returns (M.ScriptManifest memory) {
        return _manifests.scripts[_selectedManifest(_manifests, x, collectionId, 2)];
    }

    function mediaManifest(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        uint256 collectionId
    ) private view returns (M.MediaManifest memory) {
        return _manifests.media[_selectedManifest(_manifests, x, collectionId, 3)];
    }

    function scriptChunk(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        uint256 collectionId,
        uint256 index
    ) private view returns (bytes memory) {
        bytes32 hash = _selectedManifest(_manifests, x, collectionId, 2);
        if (hash == 0) revert W.UnknownCollectionManifest(hash);
        bytes32 bundle = _manifests.bundles.manifests[hash];
        if (bundle != 0) return StreamScriptBundles.chunk(_manifests.bundles, bundle, index);
        if (index != 0) revert W.UnknownCollectionManifest(hash);
        return _chunk(x, _manifests.scripts[hash].scriptHash);
    }

    function recordedScriptManifest(
        StreamCollectionManifests.State storage _manifests,
        bytes32 hash
    ) private view returns (M.ScriptManifest memory) {
        if (_manifests.entries[hash].kind != 2) {
            revert W.UnknownCollectionManifest(hash);
        }
        return _manifests.scripts[hash];
    }

    function recordedMediaManifest(StreamCollectionManifests.State storage _manifests, bytes32 hash)
        private
        view
        returns (M.MediaManifest memory)
    {
        if (_manifests.entries[hash].kind != 3) revert W.UnknownCollectionManifest(hash);
        return _manifests.media[hash];
    }

    function _selectedManifest(
        StreamCollectionManifests.State storage _manifests,
        Context memory x,
        uint256 collectionId,
        uint8 kind
    ) private view returns (bytes32 hash) {
        address router = _manifestRouter(x, collectionId);
        M.Selection memory selected = abi.decode(
            _read(
                router,
                abi.encodeCall(
                    IStreamMetadataManifestSelection.selectedCollectionManifest,
                    (collectionId, kind)
                ),
                96,
                false
            ),
            (M.Selection)
        );
        hash = selected.manifestHash;
        if (hash == 0) {
            if (selected.host != address(0) || selected.codeHash != 0) {
                revert W.InvalidCollectionManifest();
            }
            return 0;
        }
        if (
            selected.host != address(this) || selected.codeHash != address(this).codehash
                || _manifests.entries[hash].collectionId != collectionId
                || _manifests.entries[hash].router != router
                || _manifests.entries[hash].kind != kind
        ) {
            revert W.InvalidCollectionManifest();
        }
    }

    function _manifestRouter(Context memory x, uint256 collectionId)
        private
        view
        returns (address target)
    {
        _requireCollection(x, collectionId);
        _requireSelected(x, _TYPE, address(this), address(this).codehash);
        bytes32 hash;
        uint8 status;
        uint64 revision;
        (target, hash,,,,, status,,, revision) = abi.decode(
            _read(
                x.core,
                abi.encodeCall(
                    IStreamCorePointers.getSatellitePointer, (keccak256("METADATA_ROUTER"))
                ),
                320,
                false
            ),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        _requireCode(target, hash);
        if (
            status != 1 || revision == 0
                || abi.decode(
                        _read(target, abi.encodeWithSignature("core()"), 32, false), (address)
                    ) != x.core
        ) {
            revert V.MetadataHostNotSelected();
        }
    }

    function _manifestSource(Context memory x, address router, uint256 collectionId)
        private
        view
        returns (IStreamMetadataServingFacts.ServingSource memory source)
    {
        _requireCode(x.chunkStore, x.chunkStoreCodeHash);
        bytes memory profile =
            _read(router, abi.encodeWithSignature("renderingProfile()"), 96, false);
        if (
            keccak256(profile)
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1"),
                        keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1"),
                        keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")
                    )
                )
        ) {
            revert W.UnsupportedCollectionManifest();
        }
        bytes memory raw = _read(
            router,
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingSource, (collectionId)),
            16384,
            false
        );
        source = abi.decode(raw, (IStreamMetadataServingFacts.ServingSource));
        if (keccak256(raw) != keccak256(abi.encode(source))) revert W.InvalidCollectionManifest();
    }

    function _chunk(Context memory x, bytes32 hash) private view returns (bytes memory) {
        _requireCode(x.chunkStore, x.chunkStoreCodeHash);
        return StreamRecordDocumentReads.chunk(
            x.chunkStore,
            hash,
            IStreamGasParameterHost(address(this)).gasParameter(DEPENDENCY_READ_GAS)
        );
    }

    function _requireCollection(Context memory x, uint256 collectionId) private view {
        _requireCode(x.core, x.coreCodeHash);
        if (
            collectionId == 0
                || !abi.decode(
                    _read(
                        x.core,
                        abi.encodeCall(IStreamCoreCollectionView.collectionExists, (collectionId)),
                        32,
                        false
                    ),
                    (bool)
                )
        ) revert V.InvalidMetadataRecord();
    }

    function _requireSelected(
        Context memory x,
        bytes32 pointerType,
        address expected,
        bytes32 expectedCodeHash
    ) private view {
        _requireCode(x.core, x.coreCodeHash);
        _requireCode(expected, expectedCodeHash);
        bytes memory data = _read(
            x.core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (pointerType)),
            320,
            false
        );
        (address target, bytes32 hash,,,,,,,,) = abi.decode(
            data,
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (target != expected || hash != expectedCodeHash) revert V.MetadataHostNotSelected();
    }

    function _requireCode(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert V.MetadataDependencyChanged(target);
        }
    }

    function _read(address target, bytes memory input, uint256 maximum, bool artist)
        private
        view
        returns (bytes memory data)
    {
        uint256 cap = IStreamGasParameterHost(address(this))
            .gasParameter(artist ? ARTIST_READ_GAS : DEPENDENCY_READ_GAS);
        if (gasleft() <= cap + cap / 63 + 10000) revert V.MetadataReadFailed(target);
        data = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum || (maximum <= 320 && size != maximum)) {
            revert V.MetadataReadFailed(target);
        }
        assembly ("memory-safe") { mstore(data, size) }
    }
}
