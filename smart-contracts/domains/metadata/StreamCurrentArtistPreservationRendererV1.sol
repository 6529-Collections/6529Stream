// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamStaticMetadataSource as Raw
} from "../../interfaces/stream/metadata/IStreamStaticMetadataSource.sol";
import {
    IStreamScriptBundles as B
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import { IStreamCoreMint as Mint } from "../../interfaces/stream/core/IStreamCoreMint.sol";
import {
    IStreamStaticEntropySource as StaticEntropy
} from "../../interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";
import { StreamRenderContextV1 as Context } from "./StreamRenderContextV1.sol";
import { StreamStaticText as Text } from "./StreamStaticText.sol";
import {
    StreamStaticAttributionCompanion as Attribution
} from "./StreamStaticAttributionCompanion.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";
import { StreamStaticRenderEncoding as Encoding } from "./StreamStaticRenderEncoding.sol";
import {
    StreamTerminalEntropyEncoding as TerminalEncoding
} from "./StreamTerminalEntropyEncoding.sol";
import {
    StreamTerminalEntropyValidation as TerminalValidation
} from "./StreamTerminalEntropyValidation.sol";
import {
    StreamEntropyPolicyConsumerTypes as EntropyTypes
} from "../../interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import {
    IStreamTerminalEntropyRenderer as Terminal
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRenderer.sol";
import {
    IStreamCurrentCitationRenderer as Current
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    IStreamStaticC2PAAttribution as C2PAAttribution
} from "../../interfaces/stream/metadata/IStreamStaticC2PAAttribution.sol";
import {
    IStreamC2PAReconciliation as C2PA
} from "../../interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import {
    IStreamC2PAConflicts as Conflicts,
    IStreamStaticC2PAConflicts
} from "../../interfaces/stream/metadata/IStreamC2PAConflicts.sol";

import {
    IStreamPreservationRendererV1 as Preservation
} from "../../interfaces/stream/metadata/IStreamPreservationRendererV1.sol";
import {
    IStreamPreservationAttributionV1 as PA
} from "../../interfaces/stream/metadata/IStreamPreservationAttributionV1.sol";
import {
    IStreamRendererRegistry as Registry
} from "../../interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamCurrentCitationRegistry as CitationRegistry
} from "../../interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamTerminalEntropyRegistry as TerminalRegistry
} from "../../interfaces/stream/metadata/IStreamTerminalEntropyRegistry.sol";
import { IStreamCoreIdentity as CI } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamCoreCollectionView as CV
} from "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import { StreamRendererV1 as Live } from "./StreamRendererV1.sol";
import "./StreamMetadataSubjects.sol";

/// @notice Explicit current-Artist full MARKETPLACE preservation output.
/// @dev Same full original token renderer; only the admitted attribution profile differs.
/// @dev Only sanction-derived attribution is excluded. This producer is not a finality or
/// admission assertion. A consumer must admit this profile and its complete read roster.
contract StreamCurrentArtistPreservationRendererV1 is Preservation, StreamGasParameterHost {
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 public constant ATTRIBUTION_GAS = keccak256("6529STREAM_GGP_STATIC_ATTRIBUTION_GAS");
    uint256 public constant MAX_FULL_BYTES = 16777216;
    address public immutable liveRenderer;
    bytes32 public immutable liveRendererCodeHash;
    address public immutable preservationAttribution;
    bytes32 public immutable preservationAttributionCodeHash;
    uint256 public immutable sourceChainId;
    Live.Sources private _sources;
    bytes32[6] private _codeHashes;
    bytes32 private immutable _encodingCodeHash;
    bytes32 private immutable _terminalEncodingCodeHash;
    bytes32 private immutable _terminalValidationCodeHash;
    bool public immutable c2paAttributionEnabled;
    bool public immutable c2paConflictsEnabled;
    address private immutable _reconciliation;
    bytes32 private immutable _reconciliationCodeHash;
    error InvalidStaticRender();

    constructor(
        address live_,
        address attribution_,
        address executor,
        GasParameterConfig memory readGas,
        GasParameterConfig memory attributionGas
    ) StreamGasParameterHost(executor) {
        if (
            live_.code.length == 0 || attribution_.code.length == 0 || readGas.failureClass != 2
                || attributionGas.failureClass != 1 || _registerGasParameter(readGas) != READ_GAS
                || _registerGasParameter(attributionGas) != ATTRIBUTION_GAS
        ) revert InvalidStaticRender();
        liveRenderer = live_;
        liveRendererCodeHash = live_.codehash;
        preservationAttribution = attribution_;
        preservationAttributionCodeHash = attribution_.codehash;
        sourceChainId = block.chainid;
        (_sources, _codeHashes) = abi.decode(
            _read(live_, abi.encodeCall(Live.sourceBindings, ()), 384, true),
            (Live.Sources, bytes32[6])
        );
        address[6] memory targets = [
            _sources.core,
            _sources.router,
            _sources.metadata,
            _sources.entropy,
            _sources.dependencyRegistry,
            _sources.attribution
        ];
        for (uint256 i; i < 6; ++i) {
            if (i == 4 && targets[i] == address(0)) continue;
            _pin(i, targets[i]);
        }
        if (
            abi.decode(
                        _read(
                            attribution_,
                            abi.encodeCall(PA.preservationAttributionProfile, ()),
                            32,
                            true
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_CURRENT_ARTIST_NON_SANCTION_ATTRIBUTION_V1")
                || abi.decode(_read(attribution_, abi.encodeCall(PA.core, ()), 32, true), (address))
                    != _sources.core
                || abi.decode(
                        _read(attribution_, abi.encodeCall(PA.router, ()), 32, true), (address)
                    ) != _sources.router
                || abi.decode(
                        _read(attribution_, abi.encodeCall(PA.liveAttribution, ()), 32, true),
                        (address)
                    ) != _sources.attribution
                || abi.decode(
                        _read(
                            attribution_, abi.encodeCall(PA.liveAttributionCodeHash, ()), 32, true
                        ),
                        (bytes32)
                    ) != _codeHashes[5]
        ) {
            revert InvalidStaticRender();
        }
        _encodingCodeHash =
            _encoding(live_, abi.encodeCall(Live.encodingBinding, ()), address(Encoding));
        _terminalEncodingCodeHash = _encoding(
            live_, abi.encodeCall(Live.terminalEncodingBinding, ()), address(TerminalEncoding)
        );
        _terminalValidationCodeHash = _encoding(
            live_, abi.encodeCall(Live.terminalValidationBinding, ()), address(TerminalValidation)
        );
        c2paAttributionEnabled = abi.decode(
            _read(live_, abi.encodeWithSignature("c2paAttributionEnabled()"), 32, true), (bool)
        );
        c2paConflictsEnabled = abi.decode(
            _read(live_, abi.encodeWithSignature("c2paConflictsEnabled()"), 32, true), (bool)
        );
        address reconciliation_;
        bytes32 reconciliationHash_;
        if (c2paAttributionEnabled) {
            reconciliation_ = abi.decode(
                _read(_sources.attribution, abi.encodeWithSignature("reconciliation()"), 32, true),
                (address)
            );
            reconciliationHash_ = abi.decode(
                _read(
                    _sources.attribution,
                    abi.encodeWithSignature("reconciliationCodeHash()"),
                    32,
                    true
                ),
                (bytes32)
            );
            if (reconciliation_.code.length == 0 || reconciliation_.codehash != reconciliationHash_)
            {
                revert InvalidStaticRender();
            }
        } else if (c2paConflictsEnabled) {
            revert InvalidStaticRender();
        }
        _reconciliation = reconciliation_;
        _reconciliationCodeHash = reconciliationHash_;
    }

    function preservationProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1");
    }

    function preservationBinding()
        external
        view
        returns (address, address, address, bytes32, address, bytes32)
    {
        return (
            _sources.core,
            _sources.router,
            liveRenderer,
            liveRendererCodeHash,
            preservationAttribution,
            preservationAttributionCodeHash
        );
    }

    function sourceBindings() external view returns (Live.Sources memory, bytes32[6] memory) {
        return (_sources, _codeHashes);
    }

    function encodingBindings()
        external
        view
        returns (address, bytes32, address, bytes32, address, bytes32)
    {
        return (
            address(Encoding),
            _encodingCodeHash,
            address(TerminalEncoding),
            _terminalEncodingCodeHash,
            address(TerminalValidation),
            _terminalValidationCodeHash
        );
    }

    function preservationTokenJSON(uint256 token) external view returns (string memory) {
        return _serve(token, 2);
    }

    function preservationTokenHTML(uint256 token) external view returns (string memory) {
        return _serve(token, 3);
    }

    function _encoding(address live_, bytes memory input, address expected)
        private
        view
        returns (bytes32 hash)
    {
        (address target, bytes32 runtime) =
            abi.decode(_read(live_, input, 64, true), (address, bytes32));
        if (target != expected || target.code.length == 0 || target.codehash != runtime) {
            revert InvalidStaticRender();
        }
        return runtime;
    }

    function _request(uint256 token)
        private
        view
        returns (R.RenderRequest memory r, bool terminal)
    {
        if (
            block.chainid != sourceChainId || token == 0
                || liveRenderer.codehash != liveRendererCodeHash
                || preservationAttribution.codehash != preservationAttributionCodeHash
        ) revert InvalidStaticRender();
        _pin(0, _sources.core);
        _pin(1, _sources.router);
        (bool exists, uint256 id, uint256 serial, bool burned) = abi.decode(
            _read(_sources.core, abi.encodeCall(CI.tokenCollectionIdentity, (token)), 128, true),
            (bool, uint256, uint256, bool)
        );
        if (
            !exists || id == 0 || serial == 0
                || abi.decode(
                        _read(_sources.core, abi.encodeCall(CI.tokenLifecycle, (token)), 32, true),
                        (uint8)
                    ) != (burned ? 3 : 2)
        ) revert InvalidStaticRender();
        bytes memory raw =
            _read(_sources.router, abi.encodeCall(S.resolvedMetadataConfig, (token)), 8192, false);
        S.ConfigRecord memory c = abi.decode(raw, (S.ConfigRecord));
        if (
            keccak256(raw) != keccak256(abi.encode(c)) || c.recordHash == 0 || c.collectionId != id
                || (c.tokenId != 0 && c.tokenId != token) || c.config.renderer != liveRenderer
        ) revert InvalidStaticRender();
        S.Selection memory s = c.selection;
        if (
            s.renderer != liveRenderer || s.rendererCodeHash != liveRendererCodeHash
                || s.registry.code.length == 0 || s.registry.codehash != s.registryCodeHash
        ) revert InvalidStaticRender();
        // Serving authenticates the real Router selection. Governed preservation admission
        // is joined separately by the consumer at this exact selected registry/version.
        // Calling the Registry here would require a circular self-pin in its target catalogue.
        if (s.versionKey == 0 || s.registrationHash == 0 || s.readSetHash == 0) {
            revert InvalidStaticRender();
        }
        if (
            abi.decode(
                    _read(_sources.core, abi.encodeCall(CI.coordinatorAtMint, (token)), 32, true),
                    (address)
                ) != _sources.entropy
        ) revert InvalidStaticRender();
        _pin(3, _sources.entropy);
        (uint8 status, bytes32 seed,) = abi.decode(
            _read(
                _sources.entropy,
                abi.encodeCall(StaticEntropy.staticTokenRenderFacts, (token)),
                96,
                true
            ),
            (uint8, bytes32, address)
        );
        terminal = status == 1 || status == 2;
        if (status != 5 && !terminal) revert InvalidStaticRender();
        bool frozen = c.config.frozen
            || abi.decode(
                _read(_sources.core, abi.encodeCall(CV.collectionFreezeStatus, (id)), 32, true),
                (bool)
            );
        r = R.RenderRequest(
            _sources.core,
            token,
            id,
            serial,
            status == 5 ? seed : bytes32(0),
            burned
                ? R.TokenRenderState.BURNED
                : frozen ? R.TokenRenderState.FROZEN : R.TokenRenderState.ACTIVE,
            c.config.mode,
            abi.decode(
                _read(_sources.core, abi.encodeCall(CV.collectionSupplyMode, (id)), 32, true),
                (uint8)
            ),
            abi.decode(
                _read(_sources.core, abi.encodeCall(CV.collectionStatus, (id)), 32, true), (uint8)
            ),
            0,
            0,
            c.recordHash
        );
    }

    function _serve(uint256 token, uint8 mode) private view returns (string memory) {
        (R.RenderRequest memory r, bool terminal) = _request(token);
        Encoding.Prepared memory p = _prepare(r);
        if (p.source.chainId != block.chainid) revert InvalidStaticRender();
        EntropyTypes.Terminal memory policy;
        if (terminal) {
            if (address(TerminalValidation).codehash != _terminalValidationCodeHash) {
                revert InvalidStaticRender();
            }
            policy = abi.decode(
                Calls.fixedCode(
                    address(TerminalValidation),
                    abi.encodeWithSelector(
                        TerminalValidation.validate.selector,
                        r,
                        _sources.entropy,
                        _codeHashes[3],
                        p.config.frozen,
                        _gasParameterValue(READ_GAS)
                    ),
                    480,
                    gasleft()
                ),
                (EntropyTypes.Terminal)
            );
            if (p.facts.entropyStatus != policy.status || p.config.mode != R.MetadataMode.ONCHAIN) {
                revert InvalidStaticRender();
            }
        } else if (p.facts.entropyStatus != 5) {
            revert InvalidStaticRender();
        }
        string memory script = p.source.script;
        if (p.bundle != 0) {
            script = string(_payload(p.bundle, p.bundleFacts));
            if (p.bundleFacts.libraryBundle != 0) {
                B.Facts memory libraryFacts = _bundleFacts(p.bundleFacts.libraryBundle);
                if (!libraryFacts.libraryOnly || libraryFacts.libraryBundle != 0) {
                    revert InvalidStaticRender();
                }
                p.facts.dependencyScript =
                    string(_payload(p.bundleFacts.libraryBundle, libraryFacts));
            }
        }
        address encoder = terminal ? address(TerminalEncoding) : address(Encoding);
        if (
            encoder.code.length == 0
                || encoder.codehash != (terminal ? _terminalEncodingCodeHash : _encodingCodeHash)
        ) revert InvalidStaticRender();
        bytes memory input = terminal
            ? abi.encodeWithSelector(
                TerminalEncoding.render.selector, r, p, policy, script, _sources.router, mode
            )
            : abi.encodeWithSelector(
                Encoding.renderCurrent.selector, r, p, script, _sources.router, mode
            );
        return Calls.stringResult(
            Calls.fixedCode(encoder, input, 64 + MAX_FULL_BYTES, gasleft()), MAX_FULL_BYTES
        );
    }

    function _preservationArtist(uint256 id, uint256 token)
        private
        view
        returns (bytes memory value)
    {
        _pin(5, _sources.attribution);
        if (preservationAttribution.codehash != preservationAttributionCodeHash) {
            revert InvalidStaticRender();
        }
        bytes memory raw = Calls.read(
            preservationAttribution,
            abi.encodeCall(PA.preservationAttribution, (id, token)),
            Calls.ReadOptions(32832, false),
            _gasParameterValue(ATTRIBUTION_GAS)
        );
        value = abi.decode(raw, (bytes));
        if (
            value.length == 0 || value.length > 32768
                || keccak256(raw) != keccak256(abi.encode(value))
        ) {
            revert InvalidStaticRender();
        }
    }

    function _c2paFacts(uint256 id, uint256 token)
        private
        view
        returns (C2PA.Display memory facts, bytes32 subject)
    {
        if (_reconciliation.codehash != _reconciliationCodeHash) revert InvalidStaticRender();
        subject = StreamMetadataSubjects.scopeSubject(
            sourceChainId,
            _sources.core,
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, id, token, 0)
        );
        facts = _report(id, subject);
        if (facts.recordHash == 0) {
            subject = StreamMetadataSubjects.scopeSubject(
                sourceChainId,
                _sources.core,
                StreamFinalityScope(StreamFinalityScopeType.COLLECTION, id, 0, 0)
            );
            facts = _report(id, subject);
        }
    }

    function _report(uint256 id, bytes32 subject) private view returns (C2PA.Display memory d) {
        bytes memory raw =
            _read(_reconciliation, abi.encodeCall(C2PA.display, (id, subject)), 192, true);
        d = abi.decode(raw, (C2PA.Display));
        if (
            keccak256(raw) != keccak256(abi.encode(d))
                || (!d.current
                    && (d.validation != C2PA.ValidationStatus.UNEVALUATED
                        || d.authorship != C2PA.AuthorshipStatus.UNEVALUATED))
                || ((d.validation != C2PA.ValidationStatus.VALID || !d.assertsAuthorship)
                    && d.authorship != C2PA.AuthorshipStatus.UNEVALUATED)
                || (d.recordHash == 0 && (d.selectionHash != 0 || d.current || d.assertsAuthorship))
                || (d.recordHash != 0 && (d.selectionHash == 0 || subject == 0))
        ) revert InvalidStaticRender();
    }

    function _strictConflicts(uint256 id, uint256 token)
        private
        view
        returns (Conflicts.Standing memory t, Conflicts.Standing memory c)
    {
        bytes memory raw = Calls.read(
            _sources.attribution,
            abi.encodeCall(IStreamStaticC2PAConflicts.attributionC2PAConflicts, (id, token)),
            Calls.ReadOptions(384, true),
            _gasParameterValue(ATTRIBUTION_GAS)
        );
        (t, c) = abi.decode(raw, (Conflicts.Standing, Conflicts.Standing));
        if (
            keccak256(raw) != keccak256(abi.encode(t, c)) || t.unresolvedCount > t.revision
                || c.unresolvedCount > c.revision || !_validConflict(t) || !_validConflict(c)
        ) revert InvalidStaticRender();
    }

    function _prepare(R.RenderRequest memory r) private view returns (Encoding.Prepared memory p) {
        _pin(0, _sources.core);
        _pin(1, _sources.router);
        bytes memory raw = _read(
            _sources.router,
            abi.encodeCall(S.staticRenderSourceForConfig, (r.collectionId, r.metadataSnapshotHash)),
            20736,
            false
        );
        (p.source, p.config) = abi.decode(raw, (S.RawSource, R.MetadataConfig));
        if (
            keccak256(raw) != keccak256(abi.encode(p.source, p.config)) || p.config.mode != r.mode
                || (r.metadataSnapshotHash != 0 && p.config.renderer != liveRenderer)
        ) revert InvalidStaticRender();
        if (!p.source.configured && (r.metadataSnapshotHash != 0 || r.tokenId != 0)) {
            revert InvalidStaticRender();
        }
        p.facts.chainId = p.source.chainId;
        p.facts.viewName = "MARKETPLACE";
        if (r.tokenId != 0) {
            bytes memory tokenRaw =
                _read(_sources.core, abi.encodeCall(Mint.tokenData, (r.tokenId)), 16448, false);
            p.facts.tokenData = abi.decode(tokenRaw, (bytes));
            if (
                p.facts.tokenData.length > 16384
                    || keccak256(tokenRaw) != keccak256(abi.encode(p.facts.tokenData))
            ) revert InvalidStaticRender();
            _pin(3, _sources.entropy);
            (uint8 status,, address provider) = abi.decode(
                _read(
                    _sources.entropy,
                    abi.encodeCall(StaticEntropy.staticTokenRenderFacts, (r.tokenId)),
                    96,
                    true
                ),
                (uint8, bytes32, address)
            );
            if (status > 7) revert InvalidStaticRender();
            p.facts.entropyStatus = status;
            p.facts.entropyProvider = provider;
        }
        p.facts.scriptHash = keccak256(bytes(p.source.script));
        M.Selection memory selected = p.source.scriptManifest;
        if (selected.manifestHash != 0) {
            _manifestPin(selected);
            bytes memory manifestRaw = _read(
                selected.host,
                abi.encodeCall(Raw.staticScriptManifest, (selected.manifestHash)),
                9504,
                false
            );
            M.ScriptManifest memory m;
            uint256 collectionId;
            address router;
            (m, p.bundle, collectionId, router) =
                abi.decode(manifestRaw, (M.ScriptManifest, bytes32, uint256, address));
            if (
                keccak256(manifestRaw) != keccak256(abi.encode(m, p.bundle, collectionId, router))
                    || collectionId != r.collectionId || router != _sources.router
            ) revert InvalidStaticRender();
            if (
                !m.executable || keccak256(bytes(m.mimeType)) != keccak256("application/javascript")
            ) revert InvalidStaticRender();
            if (p.bundle != 0) {
                p.bundleFacts = _bundleFacts(p.bundle);
                if (
                    p.bundleFacts.libraryOnly || p.bundleFacts.payloadHash != m.scriptHash
                        || p.bundleFacts.chunkCount != m.chunkCount
                ) revert InvalidStaticRender();
                p.facts.scriptHash = p.bundleFacts.payloadHash;
                if (p.bundleFacts.libraryBundle != 0) {
                    B.Facts memory libraryFacts = _bundleFacts(p.bundleFacts.libraryBundle);
                    if (!libraryFacts.libraryOnly || libraryFacts.libraryBundle != 0) {
                        revert InvalidStaticRender();
                    }
                    p.facts.dependencyHash = libraryFacts.payloadHash;
                }
            } else if (
                m.scriptHash != p.facts.scriptHash || m.chunkCount != 1
                    || m.sourceType != M.PayloadSourceType.INLINE_CHUNKS
            ) {
                revert InvalidStaticRender();
            }
        }
        selected = p.source.mediaManifest;
        if (selected.manifestHash != 0) {
            _manifestPin(selected);
            p.facts.mediaManifestHash = selected.manifestHash;
        }
        p.artist = _preservationArtist(r.collectionId, r.tokenId);
        if (c2paAttributionEnabled) {
            (p.c2pa, p.c2paSubject) = _c2paFacts(r.collectionId, r.tokenId);
            if (c2paConflictsEnabled) {
                p.c2paConflictsEnabled = true;
                (p.c2paTokenConflict, p.c2paCollectionConflict) =
                    _strictConflicts(r.collectionId, r.tokenId);
            }
        }
    }

    function _bundleFacts(bytes32 id) private view returns (B.Facts memory f) {
        _pin(2, _sources.metadata);
        (f,) = abi.decode(
            _read(_sources.metadata, abi.encodeCall(Raw.staticBundle, (id)), 384, true),
            (B.Facts, B.RegistrySource)
        );
        if (
            !f.finalized || f.chunkCount == 0 || f.chunkCount > 32 || f.totalBytes == 0
                || f.totalBytes > 786432 || f.payloadHash == 0
                || (f.sourceType != M.PayloadSourceType.INLINE_CHUNKS
                    && f.sourceType != M.PayloadSourceType.SSTORE2
                    && !(f.libraryOnly && f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY))
        ) revert InvalidStaticRender();
    }

    function _chunkPayload(
        B.Facts memory f,
        B.RegistrySource memory source,
        Raw.Chunk memory c,
        uint256 index
    ) private view returns (bytes memory part) {
        if (f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
            if (c.first != address(0) || c.tail != address(0)) revert InvalidStaticRender();
            bytes memory raw = _read(
                source.registry,
                abi.encodeWithSignature(
                    "getDependencyScriptAtVersion(bytes32,uint256,uint256)",
                    source.dependencyId,
                    source.version,
                    index
                ),
                8256,
                false
            );
            string memory value = abi.decode(raw, (string));
            if (keccak256(raw) != keccak256(abi.encode(value))) revert InvalidStaticRender();
            return bytes(value);
        }
        uint256 firstLength = c.length > 24575 ? 24575 : c.length;
        if (
            c.first.code.length != firstLength + 1
                || (c.length > 24575 ? c.tail.code.length != 2 : c.tail != address(0))
        ) revert InvalidStaticRender();
        part = new bytes(c.length);
        address first = c.first;
        address tail = c.tail;
        assembly ("memory-safe") { extcodecopy(first, add(part, 32), 1, firstLength) }
        if (tail != address(0)) {
            assembly ("memory-safe") { extcodecopy(tail, add(add(part, 32), firstLength), 1, 1) }
        }
    }

    function _payload(bytes32 id, B.Facts memory f) private view returns (bytes memory out) {
        B.RegistrySource memory source;
        if (f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
            (, source) = abi.decode(
                _read(_sources.metadata, abi.encodeCall(Raw.staticBundle, (id)), 384, true),
                (B.Facts, B.RegistrySource)
            );
            if (source.registry != _sources.dependencyRegistry || source.codeHash != _codeHashes[4])
            {
                revert InvalidStaticRender();
            }
            _pin(4, source.registry);
        }
        out = new bytes(f.totalBytes);
        uint256 offset;
        bytes32 sequence;
        uint256 maximum = f.sourceType == M.PayloadSourceType.SSTORE2 ? 24576 : 8192;
        for (uint256 i; i < f.chunkCount; ++i) {
            Raw.Chunk memory c = abi.decode(
                _read(_sources.metadata, abi.encodeCall(Raw.staticBundleChunk, (id, i)), 128, true),
                (Raw.Chunk)
            );
            if (
                c.length == 0 || c.length > maximum || c.hash == 0 || c.length > out.length - offset
            ) {
                revert InvalidStaticRender();
            }
            bytes memory part = _chunkPayload(f, source, c, i);
            if (f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
                bytes32 typed = keccak256(
                    abi.encode(
                        keccak256(
                            "6529StreamDependencyScriptChunk(uint256 index,bytes32 chunkHash,uint256 byteLength)"
                        ),
                        i,
                        c.hash,
                        uint256(c.length)
                    )
                );
                sequence = keccak256(abi.encode(sequence, typed));
            }
            if (part.length != c.length || keccak256(part) != c.hash) revert InvalidStaticRender();
            uint256 words = part.length & ~uint256(31);
            assembly ("memory-safe") {
                for { let j := 0 } lt(j, words) { j := add(j, 32) } {
                    mstore(add(add(out, 32), add(offset, j)), mload(add(add(part, 32), j)))
                }
            }
            for (uint256 j = words; j < part.length; ++j) {
                out[offset + j] = part[j];
            }
            offset += part.length;
        }
        if (source.registry != address(0)) {
            bytes32 content = keccak256(
                abi.encode(
                    keccak256(
                        "6529StreamDependencyScript(bytes32 dependencyNameAndVersion,uint256 chunkCount,bytes32 chunksHash)"
                    ),
                    source.dependencyId,
                    uint256(f.chunkCount),
                    sequence
                )
            );
            if (
                content != source.contentHash
                    || abi.decode(
                            _read(
                                source.registry,
                                abi.encodeWithSignature(
                                    "getDependencyScriptContentHashAtVersion(bytes32,uint256)",
                                    source.dependencyId,
                                    source.version
                                ),
                                32,
                                true
                            ),
                            (bytes32)
                        ) != content
            ) revert InvalidStaticRender();
        }
        if (
            offset != out.length || keccak256(out) != f.payloadHash
                || !Text.isValidUtf8(string(out))
        ) {
            revert InvalidStaticRender();
        }
    }

    function _validConflict(Conflicts.Standing memory v) private pure returns (bool) {
        if ((v.revision == 0) != (v.chainHash == 0)) return false;
        if (v.unresolvedCount == 0) {
            return v.conflictId == 0 && v.recordHash == 0 && v.selectionHash == 0;
        }
        return v.conflictId != 0 && v.recordHash != 0 && v.selectionHash != 0;
    }

    function _manifestPin(M.Selection memory s) private view {
        if (s.host != _sources.metadata || s.codeHash != _codeHashes[2]) {
            revert InvalidStaticRender();
        }
        _pin(2, s.host);
    }

    function _pin(uint256 i, address a) private view {
        if (a.code.length == 0 || a.codehash != _codeHashes[i]) revert InvalidStaticRender();
    }

    function _read(address a, bytes memory input, uint256 maximum, bool exact)
        private
        view
        returns (bytes memory)
    {
        return Calls.read(a, input, Calls.ReadOptions(maximum, exact), _gasParameterValue(READ_GAS));
    }
}
