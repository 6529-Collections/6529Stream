// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamStaticMetadataRouter as S
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as V
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamCollectionMetadataV1 as M
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import { IStreamCorePointers as P } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamCoreCollectionView as CV
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import { IStreamCoreIdentity as CI } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamModuleRegistry as MR
} from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamArtistContentRatification as A
} from "../../interfaces/stream/artist/IStreamArtistContentRatification.sol";
import {
    IStreamGasParameterHost as G
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamMetadataStaticState as State } from "./StreamMetadataStaticState.sol";
import { StreamMetadataRouterContent as Content } from "./StreamMetadataRouterContent.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";
import { StreamMetadataRenderer as Text } from "./StreamMetadataRenderer.sol";
import { StreamMetadataDisplayParameters as Gas } from "./StreamMetadataDisplayParameters.sol";

/// @notice Fixed mutation worker. Original op17 authorization/consumption stays in Router storage.
/// @dev Global changes apply only to later explicit activations. Activation is before the first
/// release ratification and mint; later overrides use the ordinary artist content transition.
library StreamMetadataStaticConfiguration {
    struct LockRoot {
        mapping(uint256 => mapping(bytes32 => bool)) values;
    }

    struct Prepared {
        S.ConfigRecord record;
        State.Collection collection;
        S.RawSource snapshot;
    }
    event MetadataConfigAuthorization(
        bytes32 indexed recordHash, address indexed actor, S.Authorization authorization
    );
    event MetadataDefaultConfigured(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        uint64 indexed revision,
        S.ConfigRecord record
    );
    event MetadataStaticActivated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed defaultRecord,
        bytes32 familyStateHash
    );
    event MetadataConfigRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bytes32 indexed recordHash,
        S.ConfigRecord record
    );

    function set(
        Content.Layout memory l,
        Content.Context memory e,
        uint256 id,
        uint256 token,
        S.ConfigInput memory input
    ) public returns (bytes32) {
        S.Authorization memory authorization = _authority(e, id, id == 0);
        if (id != 0) _mutable(l, e, id, token);
        Prepared memory p = _prepare(e, id, token, input);
        State.State storage s = State.state();
        bytes32 consent;
        bytes32 ratification;
        if (id != 0) {
            (consent, ratification) =
                Content.authorize(l, e, id, State.FAMILY, State.familyOf(e.core, id, p.collection));
        }
        s.records[p.record.recordHash] = p.record;
        s.authorizations[p.record.recordHash] = authorization;
        emit MetadataConfigAuthorization(p.record.recordHash, msg.sender, authorization);
        if (p.record.sourceSnapshotHash != 0) s.frozenSources[p.record.recordHash] = p.snapshot;
        if (id == 0) {
            s.defaultHead = p.record.recordHash;
            s.defaultRevision = p.record.revision;
            emit MetadataDefaultConfigured(1, p.record.recordHash, p.record.revision, p.record);
        } else {
            s.collections[id] = p.collection;
            if (token != 0) s.tokenOverrides[token] = p.record.recordHash;
            Content.recordApplication(l, e, id, State.FAMILY, consent, ratification);
            emit MetadataConfigRecorded(1, id, token, p.record.recordHash, p.record);
        }
        return p.record.recordHash;
    }

    function activate(
        Content.Layout memory l,
        Content.Context memory e,
        uint256 id,
        bytes32 expected
    ) public {
        S.Authorization memory authorization = _authority(e, id, false);
        _unlocked(l, id);
        Prepared memory p = _activation(e, id, expected);
        State.State storage s = State.state();
        s.records[p.record.recordHash] = p.record;
        s.authorizations[p.record.recordHash] = authorization;
        emit MetadataConfigAuthorization(p.record.recordHash, msg.sender, authorization);
        if (p.record.sourceSnapshotHash != 0) s.frozenSources[p.record.recordHash] = p.snapshot;
        s.collections[id] = p.collection;
        emit MetadataConfigRecorded(1, id, 0, p.record.recordHash, p.record);
        emit MetadataStaticActivated(1, id, expected, State.family(e.core, id));
    }

    function preview(
        Content.Context memory e,
        uint256 id,
        uint256 token,
        S.ConfigInput memory input
    ) public view returns (bytes32) {
        Prepared memory p = _prepare(e, id, token, input);
        return id == 0 ? p.record.recordHash : State.familyOf(e.core, id, p.collection);
    }

    function previewActivation(Content.Context memory e, uint256 id, bytes32 expected)
        public
        view
        returns (bytes32)
    {
        return State.familyOf(e.core, id, _activation(e, id, expected).collection);
    }

    function _activation(Content.Context memory e, uint256 id, bytes32 expected)
        private
        view
        returns (Prepared memory p)
    {
        State.State storage s = State.state();
        if (id == 0 || expected == 0 || s.defaultHead != expected) {
            revert S.InvalidStaticMetadataConfig();
        }
        if (s.collections[id].activationDefault != 0) revert S.StaticMetadataAlreadyActivated(id);
        _collection(e.core, id);
        (bool ratified,,) = abi.decode(
            _read(e.artist, abi.encodeCall(A.firstReleaseRatification, (id)), 96),
            (bool, bytes32, bytes32)
        );
        if (
            ratified
                || abi.decode(
                        _read(e.core, abi.encodeCall(CV.collectionMintedEver, (id)), 32), (uint256)
                    ) != 0
        ) revert S.InvalidStaticMetadataConfig();
        p.record = s.records[expected];
        // This is a new, collection-specific wrapper of the exact retained global default.
        // Its previous link identifies that default; no historical source is fabricated.
        S.Selection memory currentSelection = _selection(
            e,
            S.ConfigInput(
                p.record.selection.registry, p.record.selection.versionKey, p.record.config
            )
        );
        if (keccak256(abi.encode(currentSelection)) != keccak256(abi.encode(p.record.selection))) {
            revert S.InvalidStaticMetadataConfig();
        }
        p.record.recordHash = 0;
        p.record.previous = expected;
        p.record.collectionId = id;
        p.record.revision = 1;
        p.record.level = 3;
        _snapshot(p, id);
        p.record.recordHash = State.recordHash(e.core, p.record);
        p.collection = State.Collection(p.record.recordHash, 0, 0, 1);
    }

    function _prepare(
        Content.Context memory e,
        uint256 id,
        uint256 token,
        S.ConfigInput memory input
    ) private view returns (Prepared memory p) {
        State.State storage s = State.state();
        if (id == 0 && token != 0) revert S.InvalidStaticMetadataConfig();
        if (id == 0 && s.defaultHead != 0 && s.records[s.defaultHead].config.frozen) {
            revert S.StaticMetadataLocked(0, 0);
        }
        _validate(input.config);
        p.record.selection = _selection(e, input);
        p.record.config = input.config;
        p.record.collectionId = id;
        p.record.tokenId = token;
        if (id == 0) {
            p.record.previous = s.defaultHead;
            p.record.revision = s.defaultRevision + 1;
            p.record.defaultRevision = p.record.revision;
        } else {
            p.collection = s.collections[id];
            if (p.collection.activationDefault == 0) revert S.StaticMetadataNotActivated(id);
            if (token != 0) _token(e.core, id, token);
            p.record.previous =
                token == 0 ? p.collection.collectionOverride : s.tokenOverrides[token];
            p.record.revision = p.collection.revision + 1;
            p.record.defaultRevision = s.records[p.collection.activationDefault].defaultRevision;
            p.record.level = token == 0 ? 1 : 2;
        }
        bytes32 prior = p.record.previous;
        // A collection/token override may intentionally equal its inherited config. A repeated
        // write to that exact override slot is a no-op and does not consume artist consent.
        if (
            prior != 0
                && keccak256(abi.encode(s.records[prior].config, s.records[prior].selection))
                    == keccak256(abi.encode(p.record.config, p.record.selection))
        ) revert S.InvalidStaticMetadataConfig();
        if (id != 0) _snapshot(p, id);
        p.record.recordHash = State.recordHash(e.core, p.record);
        if (id != 0) {
            p.collection.revision = p.record.revision;
            if (token == 0) p.collection.collectionOverride = p.record.recordHash;
            p.collection.overridesHead = keccak256(
                abi.encode(
                    keccak256("6529STREAM_STATIC_METADATA_OVERRIDES_V1"),
                    p.collection.overridesHead,
                    id,
                    token,
                    p.record.recordHash,
                    p.record.revision
                )
            );
        }
    }

    function _snapshot(Prepared memory p, uint256 id) private view {
        if (!p.record.config.frozen) return;
        bytes memory raw = Calls.read(
            address(this),
            abi.encodeCall(S.staticRenderSource, (id)),
            Calls.ReadOptions(16000, false),
            _cap()
        );
        p.snapshot = abi.decode(raw, (S.RawSource));
        if (keccak256(raw) != keccak256(abi.encode(p.snapshot)) || !p.snapshot.configured) {
            revert S.InvalidStaticMetadataConfig();
        }
        p.record.sourceSnapshotHash =
            keccak256(abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), p.snapshot));
    }

    function _validate(R.MetadataConfig memory c) private view {
        if (c.renderer.code.length == 0) revert S.InvalidStaticMetadataConfig();
        Text.requireValidUtf8ContentUri(
            "baseURI", c.baseURI, 2048, c.mode == R.MetadataMode.ONCHAIN
        );
        Text.requireValidUtf8ContentUri("pendingURI", c.pendingURI, 2048, true);
        if (c.mode == R.MetadataMode.ONCHAIN && bytes(c.baseURI).length != 0) {
            revert S.InvalidStaticMetadataConfig();
        }
    }

    function _selection(Content.Context memory e, S.ConfigInput memory input)
        private
        view
        returns (S.Selection memory selected)
    {
        if (input.registry.code.length == 0 || input.versionKey == 0) {
            revert S.InvalidStaticMetadataConfig();
        }
        (address modules, bytes32 hash) = _pointer(e.core, keccak256("MODULE_REGISTRY"));
        _code(modules, hash);
        if (!abi.decode(
                _read(
                    modules,
                    abi.encodeCall(
                        MR.isModuleEligible,
                        (input.registry, keccak256("RENDERER_REGISTRY"), type(V).interfaceId)
                    ),
                    32
                ),
                (bool)
            )) revert S.InvalidStaticMetadataConfig();
        (address metadata, bytes32 mh) = _pointer(e.core, keccak256("COLLECTION_METADATA"));
        _code(metadata, mh);
        if (
            abi.decode(
                        _read(input.registry, abi.encodeWithSignature("governanceAuthority()"), 32),
                        (address)
                    ) != e.authority
                || abi.decode(
                        _read(input.registry, abi.encodeWithSignature("schemaRegistry()"), 32),
                        (address)
                    )
                    != abi.decode(
                        _read(metadata, abi.encodeCall(M.schemaRegistry, ()), 32), (address)
                    )
        ) revert S.InvalidStaticMetadataConfig();
        V.Version memory v = abi.decode(
            _read(input.registry, abi.encodeCall(V.version, (input.versionKey)), 288), (V.Version)
        );
        if (
            !v.exists || v.deprecated || v.renderer != input.config.renderer || v.readSetHash == 0
                || v.registrationHash == 0
        ) revert S.InvalidStaticMetadataConfig();
        _code(v.renderer, v.runtimeHash);
        bytes memory raw = Calls.read(
            v.renderer,
            abi.encodeCall(R.rendererManifest, ()),
            Calls.ReadOptions(4576, false),
            _cap()
        );
        R.RendererManifest memory m = abi.decode(raw, (R.RendererManifest));
        if (
            keccak256(raw) != keccak256(abi.encode(m)) || m.rendererClass != keccak256("STATIC")
                || m.deprecated
                || input.versionKey
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDERER_VERSION_V1"),
                            m.rendererId,
                            m.rendererVersion
                        )
                    )
        ) revert S.InvalidStaticMetadataConfig();
        bytes memory registeredRaw = Calls.read(
            input.registry,
            abi.encodeCall(V.registration, (input.versionKey)),
            Calls.ReadOptions(9216, false),
            _cap()
        );
        V.Registration memory registered = abi.decode(registeredRaw, (V.Registration));
        if (
            keccak256(registeredRaw) != keccak256(abi.encode(registered))
                || registered.renderer != v.renderer
                || keccak256(abi.encode(registered.manifest)) != keccak256(abi.encode(m))
        ) revert S.InvalidStaticMetadataConfig();
        selected = S.Selection(
            input.registry,
            input.registry.codehash,
            input.versionKey,
            v.renderer,
            v.runtimeHash,
            m.rendererId,
            m.rendererVersion,
            m.contextVersion,
            m.schemaHash,
            v.readSetHash,
            v.registrationHash
        );
        _assignable(selected);
    }

    function _assignable(S.Selection memory s) private view {
        _code(s.registry, s.registryCodeHash);
        _code(s.renderer, s.rendererCodeHash);
        (address renderer, bytes32 hash) = abi.decode(
            _read(s.registry, abi.encodeCall(V.requireAssignable, (s.versionKey)), 64),
            (address, bytes32)
        );
        if (renderer != s.renderer || hash != s.rendererCodeHash) {
            revert S.InvalidStaticMetadataConfig();
        }
    }

    function _authority(Content.Context memory e, uint256 id, bool globalOnly)
        private
        view
        returns (S.Authorization memory)
    {
        (address router, bytes32 rh) = _pointer(e.core, keccak256("METADATA_ROUTER"));
        if (router != address(this) || rh != address(this).codehash) {
            revert S.InvalidStaticMetadataConfig();
        }
        (address metadata, bytes32 mh) = _pointer(e.core, keccak256("COLLECTION_METADATA"));
        _code(metadata, mh);
        (address modules, bytes32 h) = _pointer(e.core, keccak256("MODULE_REGISTRY"));
        _code(modules, h);
        if (
            !abi.decode(
                    _read(
                        modules,
                        abi.encodeCall(
                            MR.isModuleEligible,
                            (metadata, keccak256("COLLECTION_METADATA"), type(M).interfaceId)
                        ),
                        32
                    ),
                    (bool)
                )
                || abi.decode(
                        _read(metadata, abi.encodeCall(G.governanceAuthority, ()), 32), (address)
                    ) != e.authority
        ) revert S.InvalidStaticMetadataConfig();
        for (uint8 k = globalOnly ? 8 : 7; k <= 8; ++k) {
            for (uint256 i; i < 2; ++i) {
                (bool enabled, uint64 revision) = abi.decode(
                    _read(
                        metadata,
                        abi.encodeCall(
                            M.familyWriter,
                            (
                                i == 0 ? id : 0,
                                keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1"),
                                k,
                                msg.sender
                            )
                        ),
                        64
                    ),
                    (bool, uint64)
                );
                if (enabled && revision != 0) {
                    return S.Authorization(metadata, mh, msg.sender, k, i == 0 ? id : 0, revision);
                }
            }
        }
        revert S.InvalidStaticMetadataConfig();
    }

    function _mutable(Content.Layout memory l, Content.Context memory e, uint256 id, uint256 token)
        private
        view
    {
        _collection(e.core, id);
        _unlocked(l, id);
        if (State.resolved(id, 0).config.frozen || State.resolved(id, token).config.frozen) {
            revert S.StaticMetadataLocked(id, token);
        }
        if (token != 0) _token(e.core, id, token);
    }

    function _unlocked(Content.Layout memory l, uint256 id) private view {
        LockRoot storage locks;
        uint256 slot = l._artistContentLocks;
        assembly ("memory-safe") { locks.slot := slot }
        if (locks.values[id][State.FAMILY]) revert S.StaticMetadataLocked(id, 0);
    }

    function _collection(address core, uint256 id) private view {
        if (
            id == 0
                || !abi.decode(_read(core, abi.encodeCall(CV.collectionExists, (id)), 32), (bool))
        ) {
            revert S.InvalidStaticMetadataConfig();
        }
        if (abi.decode(_read(core, abi.encodeCall(CV.collectionFreezeStatus, (id)), 32), (bool))) {
            revert S.StaticMetadataLocked(id, 0);
        }
    }

    function _token(address core, uint256 id, uint256 token) private view {
        (bool exists, uint256 actual,, bool burned) = abi.decode(
            _read(core, abi.encodeCall(CI.tokenCollectionIdentity, (token)), 128),
            (bool, uint256, uint256, bool)
        );
        if (!exists || actual != id || burned) revert S.InvalidStaticMetadataConfig();
    }

    function _pointer(address core, bytes32 kind) private view returns (address a, bytes32 hash) {
        bytes memory raw = _read(core, abi.encodeCall(P.getSatellitePointer, (kind)), 320);
        uint8 status;
        uint64 revision;
        (a, hash,,,,, status,,, revision) = abi.decode(
            raw, (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (status != 1 || revision == 0) revert S.InvalidStaticMetadataConfig();
    }

    function _read(address a, bytes memory data, uint256 size) private view returns (bytes memory) {
        return Calls.read(a, data, Calls.ReadOptions(size, true), _cap());
    }

    function _cap() private view returns (uint256) {
        return Gas.value(Gas.BUNDLE_READ_GAS);
    }

    function _code(address a, bytes32 h) private view {
        if (a.code.length == 0 || a.codehash != h) revert S.StaticMetadataSourceChanged(a);
    }
}
